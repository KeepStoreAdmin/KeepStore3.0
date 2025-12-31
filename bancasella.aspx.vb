Imports System.Data
Imports MySql.Data.MySqlClient
Imports it.sella.ecomms2s
Imports System.Xml

Partial Class BancaSella
    Inherits System.Web.UI.Page

    ' Usato dalla pagina .aspx per mostrare messaggi di errore/esito
    Public result As String

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        '=========================================================
        ' 1) Controllo di base: AziendaId deve esistere in sessione
        '=========================================================
        If Session("AziendaId") Is Nothing OrElse _
           String.IsNullOrWhiteSpace(Session("AziendaId").ToString()) Then

            result = "Configurazione pagamento non disponibile (AziendaId mancante)."
            Exit Sub
        End If

        '=========================================================
        ' 2) Leggo la configurazione Banca Sella per l'azienda
        '    (tabella: bancasella_impostazioni_azienda)
        '=========================================================
        Dim params As New Dictionary(Of String, String)
        params.Add("@AziendaId", Session("AziendaId").ToString())

        Dim rows As List(Of Dictionary(Of String, Object)) = ExecuteQueryGetDataReader(
            "*",
            "bancasella_impostazioni_azienda",
            "WHERE aziendeid = @AziendaId",
            params
        )

        If rows Is Nothing OrElse rows.Count = 0 Then
            result = "Configurazione Banca Sella non trovata per l'azienda corrente."
            Exit Sub
        End If

        Dim cfg As Dictionary(Of String, Object) = rows(0)

        Try
            '=========================================================
            ' 3) shopLogin dal DB
            '=========================================================
            Dim shopLogin As String = ""

            If cfg.ContainsKey("shopLogin") AndAlso cfg("shopLogin") IsNot Nothing Then
                shopLogin = cfg("shopLogin").ToString().Trim()
            End If

            If String.IsNullOrWhiteSpace(shopLogin) Then
                result = "Configurazione Banca Sella non valida: shopLogin mancante."
                Exit Sub
            End If

            '=========================================================
            ' 4) Parametri dalla QueryString (come nella versione originale)
            '=========================================================
            Dim currency As String = (Request.QueryString("currency") & "").Trim()
            Dim amount As String = (Request.QueryString("amount") & "").Trim()
            Dim shopTransactionId As String = (Request.QueryString("shopTransactionId") & "").Trim()
            Dim iddocumento As String = (Request.QueryString("idDocumento") & "").Trim()
            Dim sitoWeb As String = (Request.QueryString("sitoWeb") & "").Trim()
            Dim buyername As String = (Request.QueryString("buyerName") & "").Trim()
            Dim buyeremail As String = (Request.QueryString("buyerEmail") & "").Trim()

            ' Info personalizzate: rimango fedele alla stringa che già usavi
            Dim customInfo As String = "iddocumento=" & iddocumento & "*P1*sito=" & sitoWeb

            '=========================================================
            ' 5) Oggetti GestPay (come in originale, solo più leggibile)
            '=========================================================
            Dim PaymentTDetail As New PaymentTypeDetail()
            Dim ShipDetails As New ShippingDetails()
            Dim RedBilling As New RedBillingInfo()
            Dim RedCustomerData As New RedCustomerData()
            Dim RedCustomerInfo As New RedCustomerInfo()
            Dim RedItem As New RedItems()
            Dim RedShipping As New RedShippingInfo()
            Dim ConselCustomer As New ConselCustomerInfo()
            Dim PaymentTypes = New String() {""}
            Dim RedCustomInfo = New String() {""}
            Dim OrderDetail As New EcommGestpayPaymentDetails()
            Dim objCrypt As New WSCryptDecrypt()

            '=========================================================
            ' 6) Chiamata al WS Encrypt di GestPay
            '    ATTENZIONE: qui Banca Sella verifica l'IP del server.
            '    L'errore 1142 "indirizzo IP non valido" arriva da qui
            '    se l'IP pubblico NON è autorizzato nel pannello Axerve.
            '=========================================================
            Dim xmlOut As String = objCrypt.Encrypt(
                shopLogin,
                currency,
                amount,
                shopTransactionId,
                "", "", "", "", "", "", "",
                customInfo,
                "", "",
                ShipDetails,
                PaymentTypes,
                PaymentTDetail,
                "",
                RedCustomerInfo,
                RedShipping,
                RedBilling,
                RedCustomerData,
                RedCustomInfo,
                RedItem,
                "",
                ConselCustomer,
                "",
                OrderDetail
            ).OuterXml

            '=========================================================
            ' 7) Parsing XML di risposta
            '=========================================================
            Dim xmlReturn As New XmlDocument()
            xmlReturn.LoadXml(xmlOut)

            Dim nodeError As XmlNode = xmlReturn.SelectSingleNode("/GestPayCryptDecrypt/ErrorCode")
            If nodeError Is Nothing Then
                result = "Risposta di Banca Sella non valida (ErrorCode mancante)."
                Exit Sub
            End If

            Dim errorCode As String = nodeError.InnerText.Trim()

            If errorCode = "0" Then
                ' -----------------------------------------------------
                ' OK: prendo la stringa criptata e redirect a pagam.aspx
                ' -----------------------------------------------------
                Dim nodeCrypt As XmlNode = xmlReturn.SelectSingleNode("/GestPayCryptDecrypt/CryptDecryptString")
                If nodeCrypt Is Nothing Then
                    result = "Risposta di Banca Sella non valida (CryptDecryptString mancante)."
                    Exit Sub
                End If

                Dim encryptedData As String = nodeCrypt.InnerText

                Dim urlPagamento As String =
                    "https://ecomm.sella.it/pagam/pagam.aspx?a=" &
                    shopLogin &
                    "&b=" &
                    HttpUtility.UrlEncode(encryptedData)

                ' Redirect "pulito": non solleviamo ThreadAbortException
                Response.Redirect(urlPagamento, False)
                Context.ApplicationInstance.CompleteRequest()
            Else
                ' -----------------------------------------------------
                ' Errore restituito da GestPay
                ' 1142 = Chiamata non accettata: indirizzo IP non valido
                ' (da sistemare lato backoffice Axerve, IP del server)
                ' -----------------------------------------------------
                Dim errDescNode As XmlNode = xmlReturn.SelectSingleNode("/GestPayCryptDecrypt/ErrorDescription")
                Dim errDesc As String = If(errDescNode IsNot Nothing, errDescNode.InnerText.Trim(), "")

                result = "Errore Banca Sella. Codice: " & errorCode &
                         If(errDesc <> "", " - " & errDesc, "")
            End If

        Catch ex As Exception
            '=========================================================
            ' 8) Qualsiasi eccezione lato .NET
            '=========================================================
            result = "Errore inatteso nella gestione del pagamento. " &
                     ex.GetType().Name & ": " & ex.Message
        End Try
    End Sub

    '=================================================================
    ' Helper DB: stessa logica di prima, ma con gestione risorse pulita
    '=================================================================
    Protected Function ExecuteQueryGetDataReader(ByVal fields As String,
                                                 ByVal table As String,
                                                 Optional ByVal wherePart As String = "",
                                                 Optional ByVal params As Dictionary(Of String, String) = Nothing) _
                                                 As List(Of Dictionary(Of String, Object))

        Dim sqlString As String = "SELECT " & fields & " FROM " & table & " " & wherePart

        Dim dr As MySqlDataReader = Nothing
        Dim resultList As New List(Of Dictionary(Of String, Object))()
        Dim conn As New MySqlConnection()

        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            If Not String.IsNullOrEmpty(connectionString) Then
                conn.ConnectionString = connectionString
                conn.Open()

                Dim cmd As New MySqlCommand() With {
                    .Connection = conn,
                    .CommandType = CommandType.Text,
                    .CommandText = sqlString
                }

                If params IsNot Nothing Then
                    For Each paramName As String In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If

                dr = cmd.ExecuteReader()

                While dr.Read()
                    Dim row As New Dictionary(Of String, Object)()

                    For i As Integer = 0 To dr.FieldCount - 1
                        Dim columnName As String = dr.GetName(i)
                        Dim value As Object = dr.GetValue(i)
                        row.Add(columnName, value)
                    Next

                    resultList.Add(row)
                End While
            End If

        Finally
            If dr IsNot Nothing Then
                dr.Close()
                dr.Dispose()
            End If

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try

        Return resultList
    End Function

End Class
