Imports System.Data
Imports System.Xml
Imports it.sella.ecomms2s

' Ritorno del cliente dalla pagina della banca: non scrive mai lo stato del pagamento (lo fa solo la chiamata server-to-server), registra l'esito
' e riporta il cliente al dettaglio del suo ordine. Regole in App_Code/BancaSellaCallback.vb (BANCASELLA-CALLBACK-AUTH-1A): l'host indicato
' all'avvio vale solo se e un host dell'azienda del documento, altrimenti si resta sull'host corrente.
Partial Class BancaSella_responseClient
    Inherits System.Web.UI.Page
    Public shopTransactionID As String = ""
    Public errore As String = "Pagamento non completato. Puoi riprovare dall'ordine o contattare l'assistenza."

    Private Sub BancaSella_responseClientError_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        Dim ipClient As String = Request.UserHostAddress
        Dim documentId As Integer = 0
        Dim site As String = ""
        Dim isCoupon As Boolean = False
        Dim parsed As Boolean = False
        Dim paid As Boolean = False
        Dim controlCode As String = ""
        Try
            Dim shopLogin As String = Request.QueryString("a")
            Dim encrypted As String = Request.QueryString("b")
            If Not String.IsNullOrWhiteSpace(shopLogin) AndAlso Not String.IsNullOrWhiteSpace(encrypted) Then
                shopLogin = shopLogin.Trim()
                If BancaSellaCallback.IsKnownLogin(connectionString, shopLogin) Then
                    Dim objCrypt As New WSCryptDecrypt()
                    Dim decryptedData As XmlNode = objCrypt.Decrypt(shopLogin, encrypted)
                    Dim fields As BancaSellaDecrypted = BancaSellaCallback.ReadFields(decryptedData)
                    parsed = BancaSellaCallback.TryParseCustomInfo(fields.CustomInfo, documentId, site, isCoupon)
                    paid = String.Equals(fields.TransactionResult, "OK", StringComparison.OrdinalIgnoreCase)
                    controlCode = fields.ShopTransactionId
                    Dim decision As New BancaSellaCallbackDecision() With {.Action = BancaSellaCallbackAction.NoChange, .DocumentId = documentId}
                    BancaSellaCallback.WriteLog(connectionString, ipClient, BancaSellaCallback.DescribeForLog("ritorno del cliente", decision, fields))
                Else
                    BancaSellaCallback.WriteLog(connectionString, ipClient, "BancaSella ritorno del cliente rifiutato: negozio non configurato")
                End If
            End If
        Catch ex As Exception
            BancaSellaCallback.WriteLog(connectionString, ipClient, "Errore ResponseClient -> " & ex.GetType().Name & ": " & BancaSellaCallback.SanitizeOutcome(ex.Message))
            errore = "Non e' stato possibile completare la verifica del pagamento. Puoi riprovare dall'ordine o contattare l'assistenza."
            parsed = False
        End Try
        If Not parsed Then Return

        If isCoupon Then
            ' Flusso dei coupon (in standby): stessa destinazione di sempre, ma sull'host corrente.
            Response.Redirect("~/pagamento.aspx?cod_controllo=" & HttpUtility.UrlEncode(controlCode) & "&bancasella=true", False)
        Else
            Dim host As String = BancaSellaCallback.ChooseReturnHost(site, BancaSellaCallback.LoadCompanyHosts(connectionString, documentId))
            Response.Redirect(BancaSellaCallback.BuildReturnUrl(host, documentId, paid), False)
        End If
        Context.ApplicationInstance.CompleteRequest()
    End Sub

End Class
