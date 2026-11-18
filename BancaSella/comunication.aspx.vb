Imports System.Data
Imports System.Xml
Imports it.sella.ecomms2s

' Chiamata server-to-server della banca: l'unica che scrive lo stato del pagamento. Le regole stanno in App_Code/BancaSellaCallback.vb
' (BANCASELLA-CALLBACK-AUTH-1A): negozio configurato e dell'azienda del documento, una sola transazione, mai un passo indietro.
Partial Class BancaSella_comunication
    Inherits System.Web.UI.Page

    Private Sub form1_Load(sender As Object, e As EventArgs) Handles form1.Load
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        Dim ipClient As String = Request.UserHostAddress
        Try
            Dim shopLogin As String = Request.QueryString("a")
            Dim encrypted As String = Request.QueryString("b")
            If String.IsNullOrWhiteSpace(shopLogin) OrElse String.IsNullOrWhiteSpace(encrypted) Then Exit Sub
            shopLogin = shopLogin.Trim()

            ' Il servizio della banca si chiama solo per un negozio configurato: nessuna decifratura per conto di altri.
            If Not BancaSellaCallback.IsKnownLogin(connectionString, shopLogin) Then
                BancaSellaCallback.WriteLog(connectionString, ipClient, "BancaSella S2S rifiutato: negozio non configurato")
                Exit Sub
            End If

            Dim objCrypt As New WSCryptDecrypt()
            Dim decryptedData As XmlNode = objCrypt.Decrypt(shopLogin, encrypted)
            Dim fields As BancaSellaDecrypted = BancaSellaCallback.ReadFields(decryptedData)
            Dim decision As BancaSellaCallbackDecision = BancaSellaCallback.ProcessServerCallback(connectionString, shopLogin, fields)
            BancaSellaCallback.WriteLog(connectionString, ipClient, BancaSellaCallback.DescribeForLog("S2S", decision, fields))
        Catch ex As Exception
            ' Solo il tipo e il messaggio dell'errore, mai lo stack ne i dati della richiesta.
            BancaSellaCallback.WriteLog(connectionString, ipClient, "Errore comunication -> " & ex.GetType().Name & ": " & BancaSellaCallback.SanitizeOutcome(ex.Message))
        End Try
    End Sub

End Class
