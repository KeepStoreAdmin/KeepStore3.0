Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Xml
Imports MySql.Data.MySqlClient

' BANCASELLA-CALLBACK-AUTH-1A: regole uniche per le due chiamate di ritorno della banca (server-to-server e browser).
' - Il negozio che parla deve essere configurato, e deve essere un negozio dell'azienda del documento: altrimenti nessuna scrittura.
' - Un pagamento riuscito segna "pagato" una volta sola; un esito negativo non torna mai indietro su un documento pagato; un esito non definitivo non scrive.
' - Ogni incasso autentico lascia la sua riga (documento, codice di autorizzazione), anche su un documento gia pagato: serve per un eventuale rimborso.
' - Importo, valuta, numero dell'ordine e metodo diversi dall'atteso sono solo AVVISI: un falso rifiuto lascerebbe non pagato un ordine pagato davvero
'   (l'importo inviato non e conservato e il gestionale modifica i documenti dopo il pagamento). La correlazione dei tentativi e un task successivo.
' Il modulo non usa sessione, contesto web ne configurazione: la stringa di connessione arriva da chi chiama. Nessun dato del cliente nel registro.

Public NotInheritable Class BancaSellaDecrypted
    Public Property TransactionResult As String = String.Empty
    Public Property ShopTransactionId As String = String.Empty
    Public Property AuthorizationCode As String = String.Empty
    Public Property BankTransactionId As String = String.Empty
    Public Property Currency As String = String.Empty
    Public Property Amount As String = String.Empty
    Public Property ErrorCode As String = String.Empty
    Public Property ErrorDescription As String = String.Empty
    Public Property CustomInfo As String = String.Empty
End Class

Public NotInheritable Class BancaSellaDocumentFacts
    Public Property Exists As Boolean
    Public Property DocumentId As Integer
    Public Property AziendeId As Integer
    Public Property Pagato As Integer
    Public Property PaymentOnline As Integer
    Public Property DocumentNumber As Long
    Public Property DocumentYear As Integer
    Public Property TotalDocument As Decimal
End Class

Public Enum BancaSellaCallbackAction
    Rejected = 0
    MarkPaid = 1
    RecordOnlyAlreadyPaid = 2
    MarkFailed = 3
    NoChange = 4
End Enum

Public NotInheritable Class BancaSellaCallbackDecision
    Public Property Action As BancaSellaCallbackAction = BancaSellaCallbackAction.Rejected
    Public Property Reason As String = String.Empty
    Public Property DocumentId As Integer
    Public ReadOnly Warnings As New List(Of String)()
End Class

Public NotInheritable Class BancaSellaCallback
    Private Sub New()
    End Sub

    Public Const CardOnlineValue As Integer = 3
    Public Const CurrencyEuro As String = "242"
    Public Const PaidOutcome As String = "BancaSella pagamento autorizzato"
    Private Const PartSeparator As String = "*P1*"

    ' ---------------------------------------------------------------- funzioni pure

    Public Shared Function ReadFields(ByVal decrypted As XmlNode) As BancaSellaDecrypted
        Dim fields As New BancaSellaDecrypted()
        If decrypted Is Nothing Then Return fields
        fields.TransactionResult = NodeText(decrypted, "TransactionResult")
        fields.ShopTransactionId = NodeText(decrypted, "ShopTransactionID")
        fields.AuthorizationCode = NodeText(decrypted, "AuthorizationCode")
        fields.BankTransactionId = NodeText(decrypted, "BankTransactionID")
        fields.Currency = NodeText(decrypted, "Currency")
        fields.Amount = NodeText(decrypted, "Amount")
        fields.ErrorCode = NodeText(decrypted, "ErrorCode")
        fields.ErrorDescription = NodeText(decrypted, "ErrorDescription")
        fields.CustomInfo = NodeText(decrypted, "CustomInfo")
        Return fields
    End Function

    Private Shared Function NodeText(ByVal parent As XmlNode, ByVal name As String) As String
        Try
            Dim node As XmlNode = parent.SelectSingleNode(name)
            If node Is Nothing OrElse node.InnerText Is Nothing Then Return String.Empty
            Return node.InnerText.Trim()
        Catch
            Return String.Empty
        End Try
    End Function

    ' CustomInfo = "iddocumento=<id>*P1*sito=<host>" (chiavi senza distinzione fra maiuscole e minuscole). L'id e fatto di sole cifre, senza zeri iniziali;
    ' "coupon-<cifre>" e il vecchio flusso dei coupon (isCoupon). Ogni altra forma = False.
    Public Shared Function TryParseCustomInfo(ByVal customInfo As String, ByRef documentId As Integer, ByRef site As String, ByRef isCoupon As Boolean) As Boolean
        documentId = 0
        site = String.Empty
        isCoupon = False
        If String.IsNullOrEmpty(customInfo) Then Return False
        Dim parts As String() = customInfo.Split(New String() {PartSeparator}, StringSplitOptions.None)
        If parts.Length < 1 OrElse parts.Length > 2 Then Return False
        Dim idValue As String = Nothing
        If Not TryReadPair(parts(0), "iddocumento", idValue) Then Return False
        If idValue.StartsWith("coupon-", StringComparison.OrdinalIgnoreCase) Then
            isCoupon = True
            idValue = idValue.Substring(7)
        End If
        If idValue.Length = 0 OrElse idValue.Length > 9 OrElse idValue.Chars(0) = "0"c Then Return False
        For Each ch As Char In idValue
            If ch < "0"c OrElse ch > "9"c Then Return False
        Next
        documentId = Integer.Parse(idValue, NumberStyles.None, CultureInfo.InvariantCulture)
        If parts.Length = 2 Then
            Dim siteValue As String = Nothing
            If TryReadPair(parts(1), "sito", siteValue) Then site = siteValue
        End If
        Return documentId > 0
    End Function

    Private Shared Function TryReadPair(ByVal text As String, ByVal key As String, ByRef value As String) As Boolean
        value = String.Empty
        If text Is Nothing Then Return False
        Dim index As Integer = text.IndexOf("="c)
        If index <= 0 Then Return False
        If Not String.Equals(text.Substring(0, index).Trim(), key, StringComparison.OrdinalIgnoreCase) Then Return False
        value = text.Substring(index + 1).Trim()
        Return True
    End Function

    Public Shared Function SameLogin(ByVal first As String, ByVal second As String) As Boolean
        Dim a As String = If(first, String.Empty).Trim()
        Dim b As String = If(second, String.Empty).Trim()
        Return a.Length > 0 AndAlso String.Equals(a, b, StringComparison.OrdinalIgnoreCase)
    End Function

    Public Shared Function ContainsLogin(ByVal logins As IEnumerable(Of String), ByVal login As String) As Boolean
        If logins Is Nothing Then Return False
        For Each current As String In logins
            If SameLogin(current, login) Then Return True
        Next
        Return False
    End Function

    ' Decisione sui fatti riletti dentro la transazione. loginKnown = il negozio e fra quelli configurati; loginOfDocumentCompany = e un negozio
    ' dell'azienda del documento. Solo questi due, l'esistenza del documento, l'esito e il codice di autorizzazione possono impedire una scrittura.
    Public Shared Function Decide(ByVal loginKnown As Boolean, ByVal loginOfDocumentCompany As Boolean, ByVal fields As BancaSellaDecrypted,
                                  ByVal facts As BancaSellaDocumentFacts) As BancaSellaCallbackDecision
        Dim decision As New BancaSellaCallbackDecision()
        If facts IsNot Nothing Then decision.DocumentId = facts.DocumentId
        If fields Is Nothing Then decision.Reason = "risposta assente" : Return decision
        If Not loginKnown Then decision.Reason = "negozio non configurato" : Return decision
        If facts Is Nothing OrElse Not facts.Exists Then decision.Reason = "documento inesistente" : Return decision
        If Not loginOfDocumentCompany Then decision.Reason = "negozio di un'altra azienda" : Return decision

        If facts.PaymentOnline <> CardOnlineValue Then decision.Warnings.Add("metodo del documento non carta")
        Dim expectedTransaction As String = facts.DocumentNumber.ToString(CultureInfo.InvariantCulture) & "/" & facts.DocumentYear.ToString(CultureInfo.InvariantCulture)
        If Not String.Equals(If(fields.ShopTransactionId, String.Empty).Trim(), expectedTransaction, StringComparison.Ordinal) Then decision.Warnings.Add("numero ordine diverso dal documento")
        Dim currency As String = If(fields.Currency, String.Empty).Trim()
        If currency.Length > 0 AndAlso Not String.Equals(currency, CurrencyEuro, StringComparison.Ordinal) Then decision.Warnings.Add("valuta diversa da euro")
        Dim amount As Decimal
        If Decimal.TryParse(If(fields.Amount, String.Empty).Trim(), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, amount) AndAlso
           amount <> Math.Round(facts.TotalDocument, 2, MidpointRounding.AwayFromZero) Then decision.Warnings.Add("importo diverso dal totale del documento")

        Select Case If(fields.TransactionResult, String.Empty).Trim().ToUpperInvariant()
            Case "OK"
                If If(fields.AuthorizationCode, String.Empty).Trim().Length = 0 Then
                    decision.Action = BancaSellaCallbackAction.NoChange
                    decision.Reason = "esito OK senza codice di autorizzazione"
                ElseIf facts.Pagato = 0 Then
                    decision.Action = BancaSellaCallbackAction.MarkPaid
                Else
                    decision.Action = BancaSellaCallbackAction.RecordOnlyAlreadyPaid
                    decision.Warnings.Add("incasso su documento gia pagato")
                End If
            Case "KO"
                If facts.Pagato = 0 Then
                    decision.Action = BancaSellaCallbackAction.MarkFailed
                Else
                    decision.Action = BancaSellaCallbackAction.NoChange
                    decision.Reason = "esito negativo su documento non in attesa"
                End If
            Case Else
                decision.Action = BancaSellaCallbackAction.NoChange
                decision.Reason = "esito non definitivo"
        End Select
        Return decision
    End Function

    Public Shared Function SanitizeOutcome(ByVal value As String) As String
        If value Is Nothing Then Return String.Empty
        Dim sanitized As String = value.Replace(Convert.ToChar(13), " "c).Replace(Convert.ToChar(10), " "c).Replace(Convert.ToChar(9), " "c).Trim()
        While sanitized.Contains("  ")
            sanitized = sanitized.Replace("  ", " ")
        End While
        If sanitized.Length > 255 Then sanitized = sanitized.Substring(0, 255)
        Return sanitized
    End Function

    Public Shared Function BuildFailedOutcome(ByVal errorCode As String, ByVal errorDescription As String) As String
        Dim outcome As String = "BancaSella pagamento non autorizzato"
        Dim code As String = SanitizeOutcome(errorCode)
        Dim description As String = SanitizeOutcome(errorDescription)
        If code.Length > 0 Then outcome &= " - Codice " & code
        If description.Length > 0 Then outcome &= " - " & description
        Return SanitizeOutcome(outcome)
    End Function

    ' Host di ritorno: quello indicato all'avvio vale solo se e uno degli host dell'azienda del documento; altrimenti stringa vuota (ritorno relativo).
    Public Shared Function ChooseReturnHost(ByVal site As String, ByVal companyHosts As IEnumerable(Of String)) As String
        Dim wanted As String = NormalizeHost(site)
        If wanted.Length = 0 OrElse companyHosts Is Nothing Then Return String.Empty
        For Each host As String In companyHosts
            If String.Equals(NormalizeHost(host), wanted, StringComparison.Ordinal) Then Return wanted
        Next
        Return String.Empty
    End Function

    Public Shared Function NormalizeHost(ByVal value As String) As String
        Dim host As String = If(value, String.Empty).Trim().ToLowerInvariant()
        If host.StartsWith("https://", StringComparison.Ordinal) Then host = host.Substring(8)
        If host.StartsWith("http://", StringComparison.Ordinal) Then host = host.Substring(7)
        host = host.TrimEnd("/"c)
        If host.Length = 0 OrElse host.Length > 253 Then Return String.Empty
        For Each ch As Char In host
            If Not ((ch >= "a"c AndAlso ch <= "z"c) OrElse (ch >= "0"c AndAlso ch <= "9"c) OrElse ch = "."c OrElse ch = "-"c OrElse ch = ":"c) Then Return String.Empty
        Next
        Return host
    End Function

    Public Shared Function BuildReturnUrl(ByVal host As String, ByVal documentId As Integer, ByVal paid As Boolean) As String
        Dim path As String = "documentidettaglio.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture) & "&payreturn=" & If(paid, "ok", "ko")
        If String.IsNullOrEmpty(host) Then Return "~/" & path
        Return "https://" & host & "/" & path
    End Function

    ' ---------------------------------------------------------------- accesso ai dati

    Public Shared Function LoadLogins(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction, ByVal companyId As Integer) As List(Of String)
        Dim logins As New List(Of String)()
        Dim sql As String = "SELECT shopLogin FROM bancasella_impostazioni_azienda WHERE COALESCE(TRIM(shopLogin),'')<>''"
        If companyId > 0 Then sql &= " AND AziendeId=?aziendaId"
        Using command As New MySqlCommand(sql, connection, transaction)
            If companyId > 0 Then command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = companyId
            Using reader As MySqlDataReader = command.ExecuteReader()
                While reader.Read()
                    logins.Add(Convert.ToString(reader(0), CultureInfo.InvariantCulture))
                End While
            End Using
        End Using
        Return logins
    End Function

    ' Prima di chiamare il servizio della banca: il negozio ricevuto deve essere uno di quelli configurati. Ogni errore = False.
    Public Shared Function IsKnownLogin(ByVal connectionString As String, ByVal login As String) As Boolean
        If String.IsNullOrWhiteSpace(connectionString) OrElse String.IsNullOrWhiteSpace(login) Then Return False
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Return ContainsLogin(LoadLogins(connection, Nothing, 0), login)
            End Using
        Catch
            Return False
        End Try
    End Function

    ' Blocca la riga del documento per chiave primaria e ne legge i fatti. I dati di contorno (metodo, totale) servono solo agli avvisi.
    Public Shared Function LoadFactsForUpdate(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction, ByVal documentId As Integer) As BancaSellaDocumentFacts
        Dim facts As New BancaSellaDocumentFacts() With {.DocumentId = documentId}
        Dim paymentTypeId As Integer = 0
        Using command As New MySqlCommand("SELECT COALESCE(AziendeId,0), COALESCE(Pagato,0), COALESCE(NDocumento,0), COALESCE(YEAR(DataDocumento),0), COALESCE(PagamentiTipoId,0) FROM documenti WHERE id=?id FOR UPDATE", connection, transaction)
            command.Parameters.Add("?id", MySqlDbType.Int32).Value = documentId
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() Then Return facts
                facts.Exists = True
                facts.AziendeId = Convert.ToInt32(reader(0), CultureInfo.InvariantCulture)
                facts.Pagato = Convert.ToInt32(reader(1), CultureInfo.InvariantCulture)
                facts.DocumentNumber = Convert.ToInt64(reader(2), CultureInfo.InvariantCulture)
                facts.DocumentYear = Convert.ToInt32(reader(3), CultureInfo.InvariantCulture)
                paymentTypeId = Convert.ToInt32(reader(4), CultureInfo.InvariantCulture)
            End Using
        End Using
        Using command As New MySqlCommand("SELECT COALESCE((SELECT MAX(COALESCE(OnLine,0)) FROM pagamentitipo WHERE id=?pagamento),0), COALESCE((SELECT MAX(TotaleDocumento) FROM documentipie WHERE DocumentiId=?id),0)", connection, transaction)
            command.Parameters.Add("?pagamento", MySqlDbType.Int32).Value = paymentTypeId
            command.Parameters.Add("?id", MySqlDbType.Int32).Value = documentId
            Using reader As MySqlDataReader = command.ExecuteReader()
                If reader.Read() Then
                    facts.PaymentOnline = Convert.ToInt32(reader(0), CultureInfo.InvariantCulture)
                    facts.TotalDocument = Convert.ToDecimal(reader(1), CultureInfo.InvariantCulture)
                End If
            End Using
        End Using
        Return facts
    End Function

    ' Chiamata server-to-server: l'unica che scrive. Una transazione: blocco del documento, decisione sui fatti riletti, riga dell'incasso e stato
    ' del documento insieme. Il servizio della banca e gia stato chiamato PRIMA (mai dentro la transazione). Le eccezioni escono a chi chiama.
    Public Shared Function ProcessServerCallback(ByVal connectionString As String, ByVal receivedLogin As String, ByVal fields As BancaSellaDecrypted) As BancaSellaCallbackDecision
        Dim documentId As Integer = 0
        Dim site As String = String.Empty
        Dim isCoupon As Boolean = False
        If fields Is Nothing OrElse Not TryParseCustomInfo(fields.CustomInfo, documentId, site, isCoupon) OrElse isCoupon Then
            Return New BancaSellaCallbackDecision() With {.Reason = "riferimento del documento non valido"}
        End If
        Using connection As New MySqlConnection(connectionString)
            connection.Open()
            Dim transaction As MySqlTransaction = connection.BeginTransaction()
            Try
                Dim facts As BancaSellaDocumentFacts = LoadFactsForUpdate(connection, transaction, documentId)
                Dim known As Boolean = ContainsLogin(LoadLogins(connection, transaction, 0), receivedLogin)
                Dim ofCompany As Boolean = facts.Exists AndAlso ContainsLogin(LoadLogins(connection, transaction, facts.AziendeId), receivedLogin)
                Dim decision As BancaSellaCallbackDecision = Decide(known, ofCompany, fields, facts)
                decision.DocumentId = documentId
                Select Case decision.Action
                    Case BancaSellaCallbackAction.MarkPaid
                        RecordPayment(connection, transaction, documentId, fields)
                        If UpdateDocument(connection, transaction, facts, "pagato=1, StatoPagamentoWeb=2", PaidOutcome) <> 1 Then
                            Throw New DataException("Banca Sella: il documento non e stato aggiornato.")
                        End If
                    Case BancaSellaCallbackAction.RecordOnlyAlreadyPaid
                        RecordPayment(connection, transaction, documentId, fields)
                    Case BancaSellaCallbackAction.MarkFailed
                        UpdateDocument(connection, transaction, facts, "StatoPagamentoWeb=3", BuildFailedOutcome(fields.ErrorCode, fields.ErrorDescription))
                End Select
                transaction.Commit()
                Return decision
            Catch
                Try
                    transaction.Rollback()
                Catch
                End Try
                Throw
            Finally
                transaction.Dispose()
            End Try
        End Using
    End Function

    ' Una riga per coppia (documento, codice di autorizzazione): la stessa conferma ripetuta non raddoppia, un incasso diverso si aggiunge.
    Private Shared Sub RecordPayment(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction, ByVal documentId As Integer, ByVal fields As BancaSellaDecrypted)
        Dim code As String = If(fields.AuthorizationCode, String.Empty).Trim()
        If code.Length > 50 Then code = code.Substring(0, 50)
        Dim number As String = If(fields.ShopTransactionId, String.Empty).Trim()
        If number.Length > 20 Then number = number.Substring(0, 20)
        Using check As New MySqlCommand("SELECT COUNT(*) FROM bancasella_ordini_pagati WHERE DocumentiId=?id AND codiceAutorizzazione=?codice", connection, transaction)
            check.Parameters.Add("?id", MySqlDbType.Int32).Value = documentId
            check.Parameters.Add("?codice", MySqlDbType.VarChar, 50).Value = code
            If Convert.ToInt64(check.ExecuteScalar(), CultureInfo.InvariantCulture) > 0L Then Return
        End Using
        Using insert As New MySqlCommand("INSERT INTO bancasella_ordini_pagati (DocumentiId,numeroDocumento,codiceAutorizzazione) VALUES (?id,?numero,?codice)", connection, transaction)
            insert.Parameters.Add("?id", MySqlDbType.Int32).Value = documentId
            insert.Parameters.Add("?numero", MySqlDbType.VarChar, 20).Value = number
            insert.Parameters.Add("?codice", MySqlDbType.VarChar, 50).Value = code
            insert.ExecuteNonQuery()
        End Using
    End Sub

    ' Lo stato cambia solo su un documento della stessa azienda ancora in attesa (Pagato = 0): mai un passo indietro.
    Private Shared Function UpdateDocument(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction, ByVal facts As BancaSellaDocumentFacts,
                                           ByVal assignments As String, ByVal outcome As String) As Integer
        Using update As New MySqlCommand("UPDATE documenti SET " & assignments & ", DataStatoPagamentoWeb=CURRENT_TIMESTAMP, UltimoEsitoPagamentoWeb=?esito " &
                                         "WHERE id=?id AND AziendeId=?aziendaId AND COALESCE(Pagato,0)=0", connection, transaction)
            update.Parameters.Add("?esito", MySqlDbType.VarChar, 255).Value = SanitizeOutcome(outcome)
            update.Parameters.Add("?id", MySqlDbType.Int32).Value = facts.DocumentId
            update.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = facts.AziendeId
            Return update.ExecuteNonQuery()
        End Using
    End Function

    ' Host dell'azienda del documento (canonico e alias). Ogni errore = lista vuota (ritorno relativo).
    Public Shared Function LoadCompanyHosts(ByVal connectionString As String, ByVal documentId As Integer) As List(Of String)
        Dim hosts As New List(Of String)()
        If String.IsNullOrWhiteSpace(connectionString) OrElse documentId <= 0 Then Return hosts
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Using command As New MySqlCommand("SELECT a.URL1, a.URL2 FROM documenti d INNER JOIN aziende a ON a.id=d.AziendeId WHERE d.id=?id", connection)
                    command.Parameters.Add("?id", MySqlDbType.Int32).Value = documentId
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        While reader.Read()
                            If Not reader.IsDBNull(0) Then hosts.Add(Convert.ToString(reader(0), CultureInfo.InvariantCulture))
                            If Not reader.IsDBNull(1) Then hosts.Add(Convert.ToString(reader(1), CultureInfo.InvariantCulture))
                        End While
                    End Using
                End Using
            End Using
        Catch
            hosts.Clear()
        End Try
        Return hosts
    End Function

    ' Riga di registro senza dati del cliente: esito della decisione, documento, esito e codici tecnici della banca, avvisi.
    Public Shared Function DescribeForLog(ByVal channel As String, ByVal decision As BancaSellaCallbackDecision, ByVal fields As BancaSellaDecrypted) As String
        Dim text As String = "BancaSella " & SanitizeOutcome(channel)
        If decision IsNot Nothing Then
            text &= " azione=" & decision.Action.ToString() & " documento=" & decision.DocumentId.ToString(CultureInfo.InvariantCulture)
            If decision.Reason.Length > 0 Then text &= " motivo=" & SanitizeOutcome(decision.Reason)
            If decision.Warnings.Count > 0 Then text &= " avvisi=" & SanitizeOutcome(String.Join("; ", decision.Warnings))
        End If
        If fields IsNot Nothing Then
            text &= " esito=" & SanitizeOutcome(fields.TransactionResult) & " ordine=" & SanitizeOutcome(fields.ShopTransactionId) &
                    " banca=" & SanitizeOutcome(fields.BankTransactionId) & " importo=" & SanitizeOutcome(fields.Amount) & " valuta=" & SanitizeOutcome(fields.Currency) &
                    " codice=" & If(If(fields.AuthorizationCode, String.Empty).Trim().Length > 0, "presente", "assente")
        End If
        If text.Length > 1000 Then text = text.Substring(0, 1000)
        Return text
    End Function

    ' Il registro usa una connessione propria, cosi resta anche se la transazione del pagamento viene annullata. Non interrompe mai il flusso.
    Public Shared Sub WriteLog(ByVal connectionString As String, ByVal ip As String, ByVal text As String)
        Try
            Dim safeIp As String = If(ip, String.Empty)
            If safeIp.Length > 20 Then safeIp = safeIp.Substring(0, 20)
            Dim safeText As String = If(text, String.Empty)
            If safeText.Length > 1000 Then safeText = safeText.Substring(0, 1000)
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Using command As New MySqlCommand("INSERT INTO bancasella_log (IP, Log, XML) VALUES (?ip, ?log, '')", connection)
                    command.Parameters.Add("?ip", MySqlDbType.VarChar, 20).Value = safeIp
                    command.Parameters.Add("?log", MySqlDbType.VarChar, 1000).Value = safeText
                    command.ExecuteNonQuery()
                End Using
            End Using
        Catch
        End Try
    End Sub
End Class
