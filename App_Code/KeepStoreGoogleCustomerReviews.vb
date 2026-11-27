Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.SessionState
Imports MySql.Data.MySqlClient

' GCR-OPTIN-1A. Attivazione del sondaggio di Recensioni dei clienti su Google sulla conferma di un ordine.
' Il segnale "mostra l'attivazione" e un marcatore di SESSIONE scritto dal checkout subito dopo il commit di un ordine (tipo 4): insieme di
' "azienda:utente:documento", al massimo 20. Chi mostra lo snippet (ricevuta di ordine.aspx, ritorno gateway in documentidettaglio.aspx) lo
' consuma SOLO dopo aver costruito lo snippet: una ricarica non riapre la finestra e un errore non spreca l'occasione. L'ID Merchant e per
' azienda (aziende.google_merchant_id, nessun valore cliente nel codice); senza ID, e-mail valida o paese ISO a due lettere non si emette nulla.
Public NotInheritable Class KeepStoreGoogleCustomerReviews
    Private Sub New()
    End Sub

    Public Const PendingSessionKey As String = "KeepStore:GCR:Pending"
    Public Const MaxPending As Integer = 20
    Public Const OrderDocumentType As Integer = 4
    Public Const DefaultDeliveryDays As Integer = 5

    Private Shared ReadOnly MerchantRegex As New Regex("^[0-9]{1,20}\z", RegexOptions.Compiled Or RegexOptions.CultureInvariant)
    Private Shared ReadOnly CountryRegex As New Regex("^[A-Z]{2}\z", RegexOptions.Compiled Or RegexOptions.CultureInvariant)
    Private Shared ReadOnly EmailRegex As New Regex("^[^@\s<>""]+@[^@\s<>""]+\.[^@\s<>""]+\z", RegexOptions.Compiled Or RegexOptions.CultureInvariant)

    ' ---------- snippet ----------

    Public Shared Function EstimatedDeliveryDate(ByVal documentDate As DateTime) As DateTime
        Return documentDate.AddDays(DefaultDeliveryDays)
    End Function

    ' Lo snippet ufficiale di Google, oppure stringa vuota se un valore non e valido. I valori sono codificati per JavaScript (non per HTML: stanno dentro uno script).
    Public Shared Function BuildOptInScript(ByVal merchantId As String, ByVal documentId As Integer, ByVal email As String,
                                            ByVal country As String, ByVal estimatedDelivery As DateTime) As String
        If merchantId Is Nothing OrElse Not MerchantRegex.IsMatch(merchantId) Then Return String.Empty
        If documentId <= 0 Then Return String.Empty
        If email Is Nothing OrElse Not EmailRegex.IsMatch(email) Then Return String.Empty
        If country Is Nothing OrElse Not CountryRegex.IsMatch(country) OrElse country = "ZZ" Then Return String.Empty

        Dim inv As CultureInfo = CultureInfo.InvariantCulture
        Dim sb As New StringBuilder()
        sb.AppendLine("<script src=""https://apis.google.com/js/platform.js?onload=renderOptIn"" async defer></script>")
        sb.AppendLine("<script>")
        sb.AppendLine("window.renderOptIn = function() {")
        sb.AppendLine("  window.gapi.load('surveyoptin', function() {")
        sb.AppendLine("    window.gapi.surveyoptin.render({")
        sb.AppendLine("      ""merchant_id"": """ & HttpUtility.JavaScriptStringEncode(merchantId) & """,")
        sb.AppendLine("      ""order_id"": """ & HttpUtility.JavaScriptStringEncode(documentId.ToString(inv)) & """,")
        sb.AppendLine("      ""email"": """ & HttpUtility.JavaScriptStringEncode(email) & """,")
        sb.AppendLine("      ""delivery_country"": """ & HttpUtility.JavaScriptStringEncode(country) & """,")
        sb.AppendLine("      ""estimated_delivery_date"": """ & HttpUtility.JavaScriptStringEncode(estimatedDelivery.ToString("yyyy-MM-dd", inv)) & """")
        sb.AppendLine("    });")
        sb.AppendLine("  });")
        sb.AppendLine("};")
        sb.AppendLine("</script>")
        Return sb.ToString()
    End Function

    ' ---------- marcatore (funzioni pure sul testo) ----------

    Public Shared Function PendingKey(ByVal companyId As Integer, ByVal utentiId As Long, ByVal documentId As Integer) As String
        If companyId <= 0 OrElse utentiId <= 0 OrElse documentId <= 0 Then Return String.Empty
        Dim inv As CultureInfo = CultureInfo.InvariantCulture
        Return companyId.ToString(inv) & ":" & utentiId.ToString(inv) & ":" & documentId.ToString(inv)
    End Function

    Private Shared Function PendingList(ByVal current As String) As List(Of String)
        Dim list As New List(Of String)()
        If String.IsNullOrEmpty(current) Then Return list
        For Each part As String In current.Split(","c)
            If part.Length > 0 Then list.Add(part)
        Next
        Return list
    End Function

    Public Shared Function PendingContains(ByVal current As String, ByVal key As String) As Boolean
        If String.IsNullOrEmpty(key) Then Return False
        Return PendingList(current).Contains(key)
    End Function

    Public Shared Function PendingAdd(ByVal current As String, ByVal key As String) As String
        If String.IsNullOrEmpty(key) Then Return If(current, String.Empty)
        Dim list As List(Of String) = PendingList(current)
        list.Remove(key)
        list.Add(key)
        While list.Count > MaxPending
            list.RemoveAt(0)
        End While
        Return String.Join(",", list.ToArray())
    End Function

    Public Shared Function PendingRemove(ByVal current As String, ByVal key As String) As String
        If String.IsNullOrEmpty(key) Then Return If(current, String.Empty)
        Dim list As List(Of String) = PendingList(current)
        list.Remove(key)
        Return String.Join(",", list.ToArray())
    End Function

    ' ---------- marcatore (sessione) ----------

    Public Shared Sub MarkPending(ByVal session As HttpSessionState, ByVal companyId As Integer, ByVal utentiId As Long, ByVal documentId As Integer)
        Try
            Dim key As String = PendingKey(companyId, utentiId, documentId)
            If session Is Nothing OrElse key.Length = 0 Then Return
            session(PendingSessionKey) = PendingAdd(Convert.ToString(session(PendingSessionKey)), key)
        Catch
            ' Mai un impatto sul checkout.
        End Try
    End Sub

    Public Shared Function IsPending(ByVal session As HttpSessionState, ByVal companyId As Integer, ByVal utentiId As Long, ByVal documentId As Integer) As Boolean
        Try
            If session Is Nothing Then Return False
            Return PendingContains(Convert.ToString(session(PendingSessionKey)), PendingKey(companyId, utentiId, documentId))
        Catch
            Return False
        End Try
    End Function

    Public Shared Sub ClearPending(ByVal session As HttpSessionState, ByVal companyId As Integer, ByVal utentiId As Long, ByVal documentId As Integer)
        Try
            If session Is Nothing Then Return
            session(PendingSessionKey) = PendingRemove(Convert.ToString(session(PendingSessionKey)), PendingKey(companyId, utentiId, documentId))
        Catch
        End Try
    End Sub

    ' ---------- documento ----------

    ' Lo snippet per UN documento gia autorizzato dal chiamante (utente e azienda della richiesta), oppure stringa vuota. Non lancia mai.
    ' Senza marcatore di sessione, per un documento che non e un ordine, o senza ID Merchant / e-mail / paese validi non emette nulla.
    Public Shared Function TryBuildForDocument(ByVal conn As MySqlConnection, ByVal session As HttpSessionState, ByVal documentId As Integer,
                                               ByVal utentiId As Long, ByVal companyId As Integer) As String
        Try
            Dim key As String = PendingKey(companyId, utentiId, documentId)
            If key.Length = 0 OrElse conn Is Nothing Then Return String.Empty
            If Not IsPending(session, companyId, utentiId, documentId) Then Return String.Empty

            Dim merchantId As String = String.Empty
            Dim email As String = String.Empty
            Dim country As String = String.Empty
            Dim tipo As Integer = 0
            Dim documentDate As DateTime = DateTime.Today
            Using cmd As New MySqlCommand(
                "SELECT IFNULL(a.google_merchant_id,'') AS merchant, IFNULL(u.email,'') AS buyer_email, IFNULL(ui.NazioneA,'') AS nazione, d.TipoDocumentiId AS tipo, d.DataDocumento AS data_documento " &
                "FROM documenti d " &
                "LEFT JOIN aziende a ON a.id = d.AziendeId " &
                "LEFT JOIN utenti u ON u.id = d.UtentiId " &
                "LEFT JOIN utentiindirizzi ui ON ui.id = d.UtentiIndirizziId " &
                "WHERE d.id=?id AND d.UtentiId=?uid AND d.AziendeId=?aziendaId LIMIT 1", conn)
                cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = documentId
                cmd.Parameters.Add("?uid", MySqlDbType.Int64).Value = utentiId
                cmd.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = companyId
                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    If Not dr.Read() Then Return String.Empty
                    merchantId = Convert.ToString(dr("merchant"), CultureInfo.InvariantCulture).Trim()
                    email = Convert.ToString(dr("buyer_email"), CultureInfo.InvariantCulture).Trim()
                    country = Convert.ToString(dr("nazione"), CultureInfo.InvariantCulture).Trim().ToUpperInvariant()
                    tipo = Convert.ToInt32(dr("tipo"), CultureInfo.InvariantCulture)
                    Dim rawDate As Object = dr("data_documento")
                    If rawDate IsNot Nothing AndAlso rawDate IsNot DBNull.Value Then
                        Try
                            documentDate = Convert.ToDateTime(rawDate, CultureInfo.InvariantCulture)
                        Catch
                            documentDate = DateTime.Today
                        End Try
                    End If
                End Using
            End Using

            If tipo <> OrderDocumentType Then Return String.Empty
            Dim script As String = BuildOptInScript(merchantId, documentId, email, country, EstimatedDeliveryDate(documentDate))
            If script.Length = 0 Then Return String.Empty
            ClearPending(session, companyId, utentiId, documentId)
            Return script
        Catch
            Return String.Empty
        End Try
    End Function
End Class
