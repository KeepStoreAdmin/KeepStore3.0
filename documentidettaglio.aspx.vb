Imports System.Data
Imports System
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient
Imports System.Configuration
Imports System.Globalization

Partial Class documentidettaglio
    Inherits System.Web.UI.Page

    Private _fallbackTipoDocumentoId As Integer = -1
    Private _orderIdentity As OrderStorefrontIdentity
    Private _authorizedIdentity As OrderStorefrontIdentity
    Private _authorizedDocumentId As Integer
    Private _authorizedDocumentTypeId As Integer
    Private _documentAuthorized As Boolean
    Private _documentBindingsComplete As Boolean
    Private _documentDenied As Boolean

    Private ReadOnly Property CurrentOrderIdentity As OrderStorefrontIdentity
        Get
            If _orderIdentity Is Nothing Then _orderIdentity = OrderStorefrontContext.Resolve(HttpContext.Current)
            Return _orderIdentity
        End Get
    End Property

    Private Class PayNowDocumentInfo
        Public DocumentId As Integer
        Public NDocumento As Integer
        Public DataDocumento As DateTime
        Public Pagato As Integer
        Public StatiId As Integer
        Public StatoPagamentoWeb As Integer
        Public PagamentiTipoOnline As Integer
        Public PermettiPagamentoSuccessivo As Integer
        Public TotaleDocumento As Decimal
        Public CodiceAutorizzazione As String = ""
        Public PagamentiTipoDescrizione As String = ""
        Public OrigineOrdine As String = ""
        Public ValidOrderType As Boolean
    End Class

    Protected Overrides Sub OnInit(ByVal e As EventArgs)
        MyBase.OnInit(e)
        ' The master has normalized the storefront. Authorize before restored
        ' control state, Load or postback events can use a requested document.
        If Not AuthorizeDocumentRequest() Then
            If IsOrderIdentityMissing() Then RequireSignInForDocument() Else DenyDocumentAccess()
        End If
    End Sub

    ' AUTH-SESSION-EXPIRED-NOTICE-1A: senza identita (mai entrato o sessione scaduta) il cliente va alla pagina che spiega e fa accedere, e dopo
    ' l'accesso torna a QUESTO ordine. Un solo esito per chi non e collegato, qualunque sia l'id: nessuna differenza fra ordine esistente e no.
    ' Per chi e collegato l'esito resta quello di DenyDocumentAccess.
    Private Function IsOrderIdentityMissing() As Boolean
        Return CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete
    End Function

    Private Sub RequireSignInForDocument()
        _documentDenied = True
        _documentAuthorized = False
        FormView1.Visible = False
        FormView2.Visible = False
        GridView1.Visible = False
        GridView2.Visible = False
        Lista_Articoli.Visible = False
        litGoogleSurveyOptIn.Text = String.Empty
        Response.Clear()
        Response.SuppressContent = True
        If GetRequestedDocumentId() > 0 Then Session("Page") = Me.Request.Url.ToString()
        Response.Redirect(ResolveUrl("~/accessonegato.aspx"), True)
    End Sub

    Private Function AuthorizeDocumentRequest() As Boolean
        Try
            Dim requestedId As Integer = GetRequestedDocumentId()
            If requestedId <= 0 OrElse CurrentOrderIdentity Is Nothing OrElse
               Not CurrentOrderIdentity.IsComplete Then Return False

            Dim tipoDocId As Integer = -1
            If Not DocumentoAppartieneAUtente(requestedId, tipoDocId) Then Return False
            _authorizedDocumentId = requestedId
            _authorizedDocumentTypeId = tipoDocId
            _documentAuthorized = True
            Return IsAuthorizedDocumentScopeCurrent()
        Catch
            Return False
        End Try
    End Function

    Private Function IsAuthorizedDocumentScopeCurrent() As Boolean
        If _documentDenied OrElse Not _documentAuthorized OrElse _authorizedIdentity Is Nothing OrElse
           Not _authorizedIdentity.IsComplete OrElse _authorizedDocumentId <= 0 Then Return False
        Try
            If GetRequestedDocumentId() <> _authorizedDocumentId Then Return False
            Dim current As OrderStorefrontIdentity = OrderStorefrontContext.Resolve(HttpContext.Current)
            Return current IsNot Nothing AndAlso current.IsComplete AndAlso
                   current.CompanyId = _authorizedIdentity.CompanyId AndAlso
                   current.LoginId = _authorizedIdentity.LoginId AndAlso
                   current.UtentiId = _authorizedIdentity.UtentiId AndAlso
                   current.PriceListId = _authorizedIdentity.PriceListId AndAlso
                   String.Equals(current.DatabaseScopeKey, _authorizedIdentity.DatabaseScopeKey, StringComparison.Ordinal)
        Catch
            Return False
        End Try
    End Function

    Protected Overrides Sub OnPreLoad(ByVal e As EventArgs)
        If Not IsAuthorizedDocumentScopeCurrent() Then DenyDocumentAccess()
        MyBase.OnPreLoad(e)
        ' ViewState may contain another document from this same page/session.
        ' Rebind only the five document consumers, after state restoration and
        ' before postback events. Leave page ViewState and financial events intact.
        litGoogleSurveyOptIn.Text = String.Empty
        Try
            FormView1.DataBind()
            FormView2.DataBind()
            GridView1.DataBind()
            GridView2.DataBind()
            Lista_Articoli.DataBind()
            _documentBindingsComplete = True
        Catch ex As System.Threading.ThreadAbortException
            Throw
        Catch
            DenyDocumentAccess()
        End Try
    End Sub

    Protected Overrides Sub Render(ByVal writer As System.Web.UI.HtmlTextWriter)
        If _documentDenied Then Return
        If Not _documentBindingsComplete OrElse Not IsAuthorizedDocumentScopeCurrent() Then
            DenyDocumentAccess()
            Return
        End If
        MyBase.Render(writer)
    End Sub

    Private Sub DenyDocumentAccess()
        _documentDenied = True
        _documentAuthorized = False
        FormView1.Visible = False
        FormView2.Visible = False
        GridView1.Visible = False
        GridView2.Visible = False
        Lista_Articoli.Visible = False
        litGoogleSurveyOptIn.Text = String.Empty
        Response.Clear()
        Response.SuppressContent = True
        ' One terminal outcome for missing, invalid, foreign and unverifiable IDs.
        Response.Redirect(ResolveUrl("~/documenti.aspx?t=4"), True)
    End Sub

    Protected Sub DocumentDataSource_Selecting(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.SqlDataSourceSelectingEventArgs)
        e.Cancel = True
        If Not IsAuthorizedDocumentScopeCurrent() OrElse e.Command Is Nothing OrElse
           Not e.Command.Parameters.Contains("DocumentId") OrElse
           Not e.Command.Parameters.Contains("UtentiId") OrElse
           Not e.Command.Parameters.Contains("AziendaId") Then
            DenyDocumentAccess()
            Return
        End If

        e.Command.Parameters("DocumentId").DbType = DbType.Int32
        e.Command.Parameters("DocumentId").Value = _authorizedDocumentId
        e.Command.Parameters("UtentiId").DbType = DbType.Int64
        e.Command.Parameters("UtentiId").Value = _authorizedIdentity.UtentiId
        e.Command.Parameters("AziendaId").DbType = DbType.Int32
        e.Command.Parameters("AziendaId").Value = _authorizedIdentity.CompanyId
        e.Cancel = False
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not _documentBindingsComplete OrElse Not IsAuthorizedDocumentScopeCurrent() Then
            DenyDocumentAccess()
            Return
        End If
        hlDocumenti.NavigateUrl = "documenti.aspx?t=" & If(_authorizedDocumentTypeId > 0,
            _authorizedDocumentTypeId, GetFallbackTipoDocumentoId()).ToString(CultureInfo.InvariantCulture)
        ConfigurePayReturnMessage()
        If Not IsPostBack Then
            TryRenderGoogleCustomerReviewsOptIn(_authorizedDocumentId)
        End If
    End Sub

    Private Sub ConfigurePayReturnMessage()
        If pnlPayReturnMessage Is Nothing OrElse litPayReturnMessage Is Nothing Then Return

        pnlPayReturnMessage.Visible = False
        litPayReturnMessage.Text = ""

        Dim rawPayReturn As String = Request.QueryString("payreturn")
        If String.IsNullOrWhiteSpace(rawPayReturn) Then Return

        Dim payReturn As String = rawPayReturn.Trim()
        If String.Equals(payReturn, "ok", StringComparison.OrdinalIgnoreCase) Then
            pnlPayReturnMessage.CssClass = "alert alert-info"
            litPayReturnMessage.Text = "Pagamento ricevuto dal gateway. Stiamo verificando la conferma automatica: lo stato dell'ordine verra' aggiornato a breve."
            pnlPayReturnMessage.Visible = True
        ElseIf String.Equals(payReturn, "ko", StringComparison.OrdinalIgnoreCase) Then
            pnlPayReturnMessage.CssClass = "alert alert-warning"
            litPayReturnMessage.Text = "Pagamento non completato. Controlla lo stato dell'ordine; se hai bisogno di assistenza, contattaci."
            pnlPayReturnMessage.Visible = True
        End If
    End Sub

    Private Function DocumentoAppartieneAUtente(ByVal idDocumento As Integer, ByRef tipoDocId As Integer) As Boolean
        tipoDocId = -1
        Try
            Dim identity As OrderStorefrontIdentity = CurrentOrderIdentity
            If identity Is Nothing OrElse Not identity.IsComplete Then Return False
            ' VerifyAccount may update its argument; never mutate the resolved
            ' identity or Session while validating this request-only snapshot.
            Dim verified As New OrderStorefrontIdentity() With {
                .DatabaseScopeKey = identity.DatabaseScopeKey, .CompanyId = identity.CompanyId,
                .LoginId = identity.LoginId, .UtentiId = identity.UtentiId, .PriceListId = identity.PriceListId
            }
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                c.Open()
                If Not OrderStorefrontContext.VerifyAccount(c, Nothing, verified) Then Return False
                Using cmd As New MySqlCommand("SELECT TipoDocumentiId FROM vdocumenti WHERE Id=@id AND UtentiId=@uid AND AziendeId=@aziendaId LIMIT 1", c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = idDocumento
                    cmd.Parameters.Add("@uid", MySqlDbType.Int64).Value = verified.UtentiId
                    cmd.Parameters.Add("@aziendaId", MySqlDbType.Int32).Value = verified.CompanyId
                    Dim o As Object = cmd.ExecuteScalar()
                    If o Is Nothing OrElse Convert.IsDBNull(o) Then Return False
                    Integer.TryParse(Convert.ToString(o), tipoDocId)
                    _authorizedIdentity = verified
                    Return True
                End Using
            End Using
        Catch
            Return False
        End Try
    End Function

    Private Function GetFallbackTipoDocumentoId() As Integer
        If _fallbackTipoDocumentoId > 0 Then Return _fallbackTipoDocumentoId

        If TipoDocumentoExists(4) Then
            _fallbackTipoDocumentoId = 4
            Return _fallbackTipoDocumentoId
        End If

        Dim first As Integer = GetFirstEnabledTipoDocumentoId()
        If first > 0 Then
            _fallbackTipoDocumentoId = first
            Return _fallbackTipoDocumentoId
        End If

        _fallbackTipoDocumentoId = 4
        Return _fallbackTipoDocumentoId
    End Function

    Private Function TipoDocumentoExists(ByVal tipoId As Integer) As Boolean
        If tipoId <= 0 Then Return False
        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Using cmd As New MySqlCommand("SELECT 1 FROM tipodocumenti WHERE id=@id AND Web=1 AND Abilitato=1 LIMIT 1", c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = tipoId
                    c.Open()
                    Dim o As Object = cmd.ExecuteScalar()
                    Return (o IsNot Nothing AndAlso Not Convert.IsDBNull(o))
                End Using
            End Using
        Catch
            Return False
        End Try
    End Function

    Private Function GetFirstEnabledTipoDocumentoId() As Integer
        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Using cmd As New MySqlCommand("SELECT id FROM tipodocumenti WHERE Web=1 AND Abilitato=1 ORDER BY Ordinamento, Descrizione LIMIT 1", c)
                    c.Open()
                    Dim o As Object = cmd.ExecuteScalar()
                    If o Is Nothing OrElse Convert.IsDBNull(o) Then Return -1
                    Dim id As Integer = 0
                    If Integer.TryParse(Convert.ToString(o), id) AndAlso id > 0 Then Return id
                End Using
            End Using
        Catch
            ' ignore
        End Try
        Return -1
    End Function


    ' Null-safe: limita testo a lunghezza massima.
    Protected Function AdattaTesto(ByVal testo As Object, ByVal lunghezza As Integer) As String
        Dim s As String = Convert.ToString(testo)
        If String.IsNullOrEmpty(s) Then
            Return String.Empty
        End If

        If lunghezza <= 0 Then
            Return String.Empty
        End If

        If s.Length > lunghezza Then
            Return Left(s, lunghezza) & " ..."
        End If

        Return s
    End Function

    ' Tracking: genera link multipli (separati da ";") applicando Link_Tracking (#ID#).
    ' Hardening: encoding HTML/attributo per evitare injection da input non previsto.
    Protected Function FormatOrderStatus(ByVal stato1Obj As Object, ByVal stato2Obj As Object) As String
        Dim stato1 As String = SafeStatusText(stato1Obj)
        Dim stato2 As String = SafeStatusText(stato2Obj)

        If stato1 = "" Then Return If(stato2 = "", "Non disponibile", stato2)
        If stato2 = "" Then Return stato1
        Return (stato1 & " " & stato2).Trim()
    End Function

    ' KS-MYACCOUNT-1A: avanzamento dell'ordine e tracking. Il passo dipende SOLO da StatiId (il tracking non prova la spedizione); nessuna data di spedizione (DataTrasporto non lo e);
    ' ogni testo del database e codificato; i collegamenti al corriere passano da KeepStoreOrderProgress (schema, userinfo, host, codifica).
    Protected Function IsOrderDocument(ByVal value As Object) As Boolean
        Return SafeInt(value, 0) = 1
    End Function

    Private Function ProgressOf(ByVal statiObj As Object) As OrderProgress
        Return KeepStoreOrderProgress.Resolve(SafeInt(statiObj, -1))
    End Function

    Protected Function ProgressShowBar(ByVal statiObj As Object) As Boolean
        Dim p As OrderProgress = ProgressOf(statiObj)
        Return p.Known AndAlso Not p.Cancelled
    End Function

    Protected Function ProgressIsCancelled(ByVal statiObj As Object) As Boolean
        Return ProgressOf(statiObj).Cancelled
    End Function

    Protected Function ProgressStepCss(ByVal statiObj As Object, ByVal stepNumber As Integer) As String
        Dim p As OrderProgress = ProgressOf(statiObj)
        If Not p.Known OrElse p.Cancelled Then Return "ks-order-progress__step"
        If stepNumber < p.StepNumber Then Return "ks-order-progress__step is-done"
        If stepNumber = p.StepNumber Then Return "ks-order-progress__step is-current"
        Return "ks-order-progress__step"
    End Function

    Protected Function ProgressAriaCurrent(ByVal statiObj As Object, ByVal stepNumber As Integer) As String
        Dim p As OrderProgress = ProgressOf(statiObj)
        If p.Known AndAlso Not p.Cancelled AndAlso stepNumber = p.StepNumber Then Return " aria-current=""step"""
        Return ""
    End Function

    Protected Function ProgressSrText(ByVal statiObj As Object, ByVal stepNumber As Integer) As String
        Dim p As OrderProgress = ProgressOf(statiObj)
        If Not p.Known OrElse p.Cancelled Then Return ""
        If stepNumber < p.StepNumber Then Return ", completato"
        If stepNumber = p.StepNumber Then Return ", stato attuale"
        Return ", da fare"
    End Function

    Protected Function ShowTrackingCard(ByVal orderObj As Object, ByVal trackingObj As Object) As Boolean
        Return IsOrderDocument(orderObj) OrElse KeepStoreOrderProgress.ParseTracking(Convert.ToString(trackingObj)).Count > 0
    End Function

    Private Function NoTrackingMessage(ByVal statiObj As Object) As String
        Select Case SafeInt(statiObj, -1)
            Case 1, 2, 6
                Return "Il numero di tracking comparira qui quando l'ordine sara affidato al corriere."
            Case 5
                Return "Pronto per la spedizione o il ritiro."
            Case 4
                Return "Spedito o consegnato secondo le modalita concordate. Il numero di tracking non e disponibile."
            Case Else
                Return "Nessun numero di tracking disponibile."
        End Select
    End Function

    Protected Function TrackingHtml(ByVal trackingObj As Object, ByVal linkTrackingObj As Object, ByVal statiObj As Object) As String
        If ProgressOf(statiObj).Cancelled Then Return ""
        Dim tokens As System.Collections.Generic.List(Of TrackingToken) = KeepStoreOrderProgress.ParseTracking(Convert.ToString(trackingObj))
        If tokens.Count = 0 Then
            Return "<p class=""ks-muted"">" & HttpUtility.HtmlEncode(NoTrackingMessage(statiObj)) & "</p>"
        End If
        Dim template As String = Convert.ToString(linkTrackingObj)
        Dim sb As New StringBuilder()
        Dim anyLink As Boolean = False
        sb.Append("<ul class=""ks-order-tracking__list"">")
        For Each token As TrackingToken In tokens
            sb.Append("<li><span class=""ks-order-tracking__code"">")
            sb.Append(HttpUtility.HtmlEncode(token.Text))
            sb.Append("</span>")
            Dim url As String = If(token.Linkable, KeepStoreOrderProgress.BuildTrackingUrl(template, token.Text), "")
            If url.Length > 0 Then
                anyLink = True
                sb.Append(" <a class=""tf-btn btn-small ks-order-tracking__btn"" href=""")
                sb.Append(HttpUtility.HtmlAttributeEncode(url))
                sb.Append(""" target=""_blank"" rel=""noopener noreferrer"">Segui la spedizione<span class=""ks-order-progress__sr""> numero ")
                sb.Append(HttpUtility.HtmlEncode(token.Text))
                sb.Append("</span></a>")
            End If
            sb.Append("</li>")
        Next
        sb.Append("</ul>")
        If anyLink Then sb.Append("<p class=""ks-muted"">Il corriere aggiorna lo stato sul proprio sito: il collegamento si apre in una nuova scheda.</p>")
        Return sb.ToString()
    End Function
    Protected Function GetOrderHeroBadge() As String
        If IsPostOrderContext() Then Return "Ordine confermato"
        Return "Riepilogo ordine"
    End Function

    Protected Function GetOrderHeroTitle() As String
        If IsPostOrderContext() Then Return "Grazie per il tuo ordine"
        Return "Dettaglio ordine"
    End Function

    Protected Function GetOrderHeroText(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        If IsPaymentConfirmed(pagatoObj, statoObj) Then
            Return "Abbiamo ricevuto il pagamento. Trovi qui riepilogo, indirizzi, stato e tracking."
        End If

        If IsPostOrderContext() Then
            Return "Il tuo ordine e stato registrato. Ti invieremo aggiornamenti appena disponibili."
        End If

        Return "Consulta i dettagli del documento, lo stato pagamento e le informazioni di spedizione."
    End Function

    Private Function IsPostOrderContext() As Boolean
        Dim ndoc As String = Convert.ToString(Request.QueryString("ndoc"))
        Dim payReturn As String = Convert.ToString(Request.QueryString("payreturn"))

        Return Not String.IsNullOrWhiteSpace(ndoc) OrElse
               String.Equals(payReturn, "ok", StringComparison.OrdinalIgnoreCase) OrElse
               String.Equals(payReturn, "ko", StringComparison.OrdinalIgnoreCase)
    End Function

    Protected Function FormatCustomerNumber(ByVal value As Object) As String
        Dim id As Integer = SafeInt(value, 0)
        If id <= 0 Then Return "Non disponibile"
        Return id.ToString(CultureInfo.InvariantCulture)
    End Function

    Protected Function HtmlText(ByVal value As Object) As String
        Return HttpUtility.HtmlEncode(SafeStatusText(value))
    End Function

    Protected Function HtmlAttr(ByVal value As Object) As String
        Return HttpUtility.HtmlAttributeEncode(SafeStatusText(value))
    End Function

    Protected Function FormatPhoneLine(ByVal telefonoObj As Object, ByVal cellulareObj As Object) As String
        Dim telefono As String = SafeStatusText(telefonoObj)
        Dim cellulare As String = SafeStatusText(cellulareObj)

        If telefono = "" AndAlso cellulare = "" Then Return ""
        If telefono <> "" AndAlso cellulare <> "" Then Return HtmlText(telefono & " - " & cellulare)
        If telefono <> "" Then Return HtmlText(telefono)
        Return HtmlText(cellulare)
    End Function

    Protected Function FormatShippingRecipient(ByVal destinazioneObj As Object, ByVal ragioneObj As Object, ByVal nomeObj As Object) As String
        Dim destinazione As String = SafeStatusText(destinazioneObj)
        Dim ragione As String = SafeStatusText(ragioneObj)
        Dim nome As String = SafeStatusText(nomeObj)

        If destinazione <> "" Then Return HtmlText(destinazione)
        If ragione <> "" Then Return HtmlText(ragione)
        If nome <> "" Then Return HtmlText(nome)
        Return "Destinatario non specificato"
    End Function

    Protected Function FormatShippingAddress(ByVal destinazioneObj As Object, ByVal indirizzoObj As Object) As String
        Dim destinazione As String = SafeStatusText(destinazioneObj)
        Dim indirizzo As String = SafeStatusText(indirizzoObj)

        If destinazione <> "" Then Return HtmlText(destinazione)
        If indirizzo <> "" Then Return HtmlText(indirizzo)
        Return "Indirizzo non disponibile"
    End Function

    Private Function IsPaymentConfirmed(ByVal pagatoObj As Object, ByVal statoObj As Object) As Boolean
        Return SafeInt(pagatoObj, 0) = 1 OrElse SafeInt(statoObj, 0) = 2
    End Function

    Protected Function GetPaymentStatusLabel(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, -1)

        If pagato = 1 OrElse stato = 2 Then Return "Pagato"

        Select Case stato
            Case 1
                Return "In verifica PayPal"
            Case 3
                Return "Non completato"
            Case 4
                Return "Annullato dall'utente"
            Case 5
                Return "In verifica"
            Case 0
                Return "Non avviato"
            Case Else
                Return "Non verificabile"
        End Select
    End Function

    Protected Function GetPaymentStatusCssClass(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)
        Dim baseClass As String = "ks-status-badge "

        If pagato = 1 OrElse stato = 2 Then Return baseClass & "is-success"

        Select Case stato
            Case 1, 5
                Return baseClass & "is-warning"
            Case 3
                Return baseClass & "is-danger"
            Case 4
                Return baseClass & "is-canceled"
            Case Else
                Return baseClass & "is-muted"
        End Select
    End Function

    Protected Function GetPaymentStatusDescription(ByVal pagatoObj As Object, ByVal statoObj As Object, ByVal esitoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, -1)
        If pagato <> 1 AndAlso (stato < 0 OrElse stato > 5) Then Return "Stato del pagamento non verificabile."

        Dim esito As String = SafeStatusText(esitoObj)
        If esito <> "" Then Return esito


        If pagato = 1 OrElse stato = 2 Then Return "Pagamento confermato."

        Select Case stato
            Case 1
                Return "Pagamento in attesa di conferma dal gateway."
            Case 3
                Return "Pagamento non completato."
            Case 4
                Return "Pagamento annullato dall'utente."
            Case 5
                Return "Pagamento in verifica."
            Case Else
                Return "Pagamento non ancora avviato."
        End Select
    End Function

    Protected Function IsPaymentPending(ByVal statoObj As Object) As Boolean
        Return SafeInt(statoObj, 0) = 1
    End Function

    Protected Function HasPaymentStateDate(ByVal value As Object) As Boolean
        Return SafeDate(value, DateTime.MinValue) <> DateTime.MinValue
    End Function

    Protected Function FormatPaymentStateDate(ByVal value As Object) As String
        Dim dt As DateTime = SafeDate(value, DateTime.MinValue)
        If dt = DateTime.MinValue Then Return ""
        Return dt.ToString("g", CultureInfo.GetCultureInfo("it-IT"))
    End Function

    Protected Sub FormView1_DataBound(sender As Object, e As EventArgs) Handles FormView1.DataBound
        If Not IsAuthorizedDocumentScopeCurrent() Then
            DenyDocumentAccess()
            Return
        End If
        ' Mostra i pulsanti di pagamento online solo quando la policy "Paga ora" lo consente.
        ' Logica volutamente conservativa per evitare regressioni: in dubbio, lascia nascosto.
        Try
            If FormView1 Is Nothing Then
                Return
            End If

            Dim hlSella As Control = FindFormViewControl("hlBancaSella")
            Dim hlPayPal As Control = FindFormViewControl("hlPayPalCheckout")
            Dim btIw As Control = FindFormViewControl("btIwBank")
            Dim btPP As Control = FindFormViewControl("btPayPal")
            Dim pnlPayNow As Control = FindFormViewControl("pnlPayNowCard")

            ' Default: nascondi
            SetVisible(pnlPayNow, False)
            SetVisible(hlSella, False)
            SetVisible(hlPayPal, False)
            SetVisible(btIw, False)
            SetVisible(btPP, False)

            Dim documentId As Integer = _authorizedDocumentId
            If documentId <= 0 Then
                Return
            End If

            Dim info As PayNowDocumentInfo = LoadPayNowDocumentInfo(documentId)
            If Not CanShowPayNow(info) Then
                Return
            End If

            If info.PagamentiTipoOnline = 3 Then
                Dim bancaSellaUrl As String = BuildBancaSellaPayNowUrl(info)
                If Not String.IsNullOrEmpty(bancaSellaUrl) Then
                    ConfigureBancaSellaPayNowLink(hlSella, bancaSellaUrl)
                    SetVisible(hlSella, True)
                    SetVisible(pnlPayNow, True)
                End If
            ElseIf info.PagamentiTipoOnline = 2 Then
                ConfigurePayPalCheckoutPayNowLink(hlPayPal, info.DocumentId)
                SetVisible(hlPayPal, True)
                SetVisible(pnlPayNow, True)
            End If

        Catch
            ' Fail-safe: non interrompere la pagina.
        End Try
    End Sub

    Private Sub ConfigureBancaSellaPayNowLink(ByVal hlSella As Control, ByVal navigateUrl As String)
        If hlSella Is Nothing OrElse String.IsNullOrEmpty(navigateUrl) Then Return

        Dim link As HyperLink = TryCast(hlSella, HyperLink)
        If link Is Nothing Then Return

        link.NavigateUrl = navigateUrl
    End Sub

    Private Sub ConfigurePayPalCheckoutPayNowLink(ByVal hlPayPal As Control, ByVal documentId As Integer)
        If hlPayPal Is Nothing OrElse documentId <= 0 Then Return

        Dim link As HyperLink = TryCast(hlPayPal, HyperLink)
        If link Is Nothing Then Return

        link.NavigateUrl = "paypalcheckout.aspx?id=" & documentId.ToString(CultureInfo.InvariantCulture)
    End Sub

    Private Function FindFormViewControl(ByVal controlId As String) As Control
        If FormView1 Is Nothing OrElse String.IsNullOrEmpty(controlId) Then Return Nothing

        Dim ctrl As Control = FormView1.FindControl(controlId)
        If ctrl IsNot Nothing Then Return ctrl

        Try
            If FormView1.Row IsNot Nothing Then
                Return FormView1.Row.FindControl(controlId)
            End If
        Catch
        End Try

        Return Nothing
    End Function

    Private Function GetRequestedDocumentId() As Integer
        Dim values() As String = Request.QueryString.GetValues("id")
        If values Is Nothing OrElse values.Length <> 1 OrElse String.IsNullOrEmpty(values(0)) Then Return -1
        Dim raw As String = values(0)
        If raw.Length > 10 Then Return -1
        For Each digit As Char In raw
            If digit < "0"c OrElse digit > "9"c Then Return -1
        Next
        Dim idDocumento As Integer = 0
        If Integer.TryParse(raw, NumberStyles.None, CultureInfo.InvariantCulture, idDocumento) AndAlso idDocumento > 0 Then
            Return idDocumento
        End If
        Return -1
    End Function

    Private Sub SetVisible(ByVal ctrl As Control, ByVal value As Boolean)
        If ctrl Is Nothing Then Return
        Try
            ctrl.Visible = value
        Catch
            ' ignore
        End Try
    End Sub

    Private Function LoadPayNowDocumentInfo(ByVal documentId As Integer) As PayNowDocumentInfo
        If documentId <> _authorizedDocumentId OrElse Not IsAuthorizedDocumentScopeCurrent() Then Return Nothing

        Try
            Dim utentiId As Long = _authorizedIdentity.UtentiId
            If utentiId <= 0 Then Return Nothing

            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Dim sql As String = ""
                sql &= "SELECT "
                sql &= "  d.id, d.NDocumento, d.DataDocumento, "
                sql &= "  COALESCE(d.OrigineOrdine,'') AS OrigineOrdine, "
                sql &= "  CASE WHEN td.Web=1 AND td.Abilitato=1 AND td.ImpegnaQnt=1 THEN 1 ELSE 0 END AS ValidOrderType, "
                sql &= "  COALESCE(d.Pagato,0) AS Pagato, "
                sql &= "  COALESCE(d.StatiId,0) AS StatiId, "
                sql &= "  COALESCE(d.StatoPagamentoWeb,0) AS StatoPagamentoWeb, "
                sql &= "  COALESCE(p.OnLine,0) AS PagamentiTipoOnline, "
                sql &= "  COALESCE(p.PermettiPagamentoSuccessivo,0) AS PermettiPagamentoSuccessivo, "
                sql &= "  COALESCE(p.Descrizione,'') AS PagamentiTipoDescrizione, "
                sql &= "  COALESCE(pie.TotaleDocumento,0) AS TotaleDocumento, "
                sql &= "  COALESCE(b.codiceAutorizzazione,'') AS CodiceAutorizzazione "
                sql &= "FROM documenti d "
                sql &= "LEFT JOIN tipodocumenti td ON td.id = d.TipoDocumentiId "
                sql &= "LEFT JOIN pagamentitipo p ON p.id = d.PagamentiTipoId "
                sql &= "LEFT JOIN documentipie pie ON pie.DocumentiId = d.id "
                sql &= "LEFT JOIN bancasella_ordini_pagati b ON b.DocumentiId = d.id "
                sql &= "WHERE d.id=@id AND d.UtentiId=@uid AND d.AziendeId=@aziendaId "
                sql &= "LIMIT 1"

                Using cmd As New MySqlCommand(sql, c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    cmd.Parameters.Add("@uid", MySqlDbType.Int64).Value = utentiId
                    cmd.Parameters.Add("@aziendaId", MySqlDbType.Int32).Value = _authorizedIdentity.CompanyId
                    c.Open()

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If Not dr.Read() Then Return Nothing

                        Dim info As New PayNowDocumentInfo()
                        info.DocumentId = SafeInt(dr("id"), 0)
                        info.NDocumento = SafeInt(dr("NDocumento"), 0)
                        info.DataDocumento = SafeDate(dr("DataDocumento"), DateTime.Today)
                        info.Pagato = SafeInt(dr("Pagato"), 0)
                        info.StatiId = SafeInt(dr("StatiId"), 0)
                        info.StatoPagamentoWeb = SafeInt(dr("StatoPagamentoWeb"), 0)
                        info.PagamentiTipoOnline = SafeInt(dr("PagamentiTipoOnline"), 0)
                        info.PermettiPagamentoSuccessivo = SafeInt(dr("PermettiPagamentoSuccessivo"), 0)
                        info.TotaleDocumento = SafeDecimal(dr("TotaleDocumento"), 0D)
                        info.CodiceAutorizzazione = Convert.ToString(dr("CodiceAutorizzazione")).Trim()
                        info.PagamentiTipoDescrizione = Convert.ToString(dr("PagamentiTipoDescrizione")).Trim()
                        info.OrigineOrdine = Convert.ToString(dr("OrigineOrdine")).Trim()
                        info.ValidOrderType = SafeInt(dr("ValidOrderType"), 0) = 1
                        Return info
                    End Using
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("documentidettaglio-paynow", "LoadPayNowDocumentInfo exception documentId=" & documentId.ToString(CultureInfo.InvariantCulture) & " " & GetPayNowSessionContext(), ex, HttpContext.Current)
            Return Nothing
        End Try
    End Function

    Private Function CanShowPayNow(ByVal info As PayNowDocumentInfo) As Boolean
        If info Is Nothing OrElse _authorizedIdentity Is Nothing OrElse Not _authorizedIdentity.IsComplete Then Return False

        ' ORDER-REMOTE-PAYMENT-1A: decisione completa sui fatti del documento (una sola query, owner e azienda dell'identita verificata).
        Return InternalOrderRemotePaymentPolicy.CanPayNow(
            KeepStoreRemotePaymentStore.LoadFacts(info.DocumentId, _authorizedIdentity.UtentiId, _authorizedIdentity.CompanyId), True, True)
    End Function

    Private Function GetPayNowSessionContext() As String
        Return "loginId=" & SafeLogValue(Session("LoginId")) &
               " utentiId=" & SafeLogValue(Session("UtentiID"))
    End Function

    Private Function SafeLogValue(ByVal value As Object) As String
        Try
            Dim s As String = Convert.ToString(value)
            If String.IsNullOrEmpty(s) Then Return ""
            s = s.Replace(vbCr, " ").Replace(vbLf, " ").Replace("|", "/").Trim()
            If s.Length > 80 Then s = s.Substring(0, 80)
            Return s
        Catch
            Return ""
        End Try
    End Function

    Private Function BuildBancaSellaPayNowUrl(ByVal info As PayNowDocumentInfo) As String
        If info Is Nothing OrElse info.DocumentId <= 0 OrElse info.NDocumento <= 0 OrElse info.TotaleDocumento <= 0D Then
            Return ""
        End If

        Dim baseUrl As String = Convert.ToString(Session("AziendaUrl")).Trim()
        If String.IsNullOrEmpty(baseUrl) Then
            baseUrl = Request.Url.GetLeftPart(UriPartial.Authority)
        End If

        Dim amount As String = HttpUtility.UrlEncode(info.TotaleDocumento.ToString("0.00", CultureInfo.InvariantCulture))
        Dim shopTransactionId As String = HttpUtility.UrlEncode(info.NDocumento.ToString() & "/" & info.DataDocumento.Year.ToString())
        Dim idDocumento As String = HttpUtility.UrlEncode(info.DocumentId.ToString())
        Dim sitoWeb As String = HttpUtility.UrlEncode(baseUrl)

        Return "/bancasella.aspx?currency=242" &
               "&amount=" & amount &
               "&shopTransactionId=" & shopTransactionId &
               "&idDocumento=" & idDocumento &
               "&sitoWeb=" & sitoWeb
    End Function

    Private Function SafeInt(ByVal value As Object, ByVal fallback As Integer) As Integer
        Try
            If value Is Nothing OrElse IsDBNull(value) Then Return fallback
            Dim parsed As Integer = fallback
            If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return fallback
    End Function

    Private Function SafeStatusText(ByVal value As Object) As String
        Try
            If value Is Nothing OrElse IsDBNull(value) Then Return ""
            Dim text As String = Convert.ToString(value).Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ").Trim()
            While text.Contains("  ")
                text = text.Replace("  ", " ")
            End While
            If text.Length > 255 Then text = text.Substring(0, 255)
            Return text
        Catch
            Return ""
        End Try
    End Function

    Private Function SafeDecimal(ByVal value As Object, ByVal fallback As Decimal) As Decimal
        Try
            If value Is Nothing OrElse IsDBNull(value) Then Return fallback
            Dim parsed As Decimal = fallback
            If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.InvariantCulture, parsed) Then Return parsed
            If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), parsed) Then Return parsed
        Catch
        End Try

        Return fallback
    End Function

    Private Function SafeDate(ByVal value As Object, ByVal fallback As DateTime) As DateTime
        Try
            If value Is Nothing OrElse IsDBNull(value) Then Return fallback
            If TypeOf value Is DateTime Then Return CType(value, DateTime)

            Dim parsed As DateTime = fallback
            If DateTime.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return fallback
    End Function


    ' GCR-OPTIN-1A: attivazione di Recensioni dei clienti su Google al ritorno da un pagamento online (PayPal, Banca Sella). Il ritorno con payreturn=ok NON basta: il
    ' cliente puo scrivere quel parametro su un ordine vecchio. Serve il marcatore di sessione scritto dal checkout subito dopo la creazione dell'ordine, per questo documento,
    ' questo utente e questa azienda; si consuma solo dopo aver costruito lo snippet. L'e-mail e nella pagina: mai in cache.
    Private Sub TryRenderGoogleCustomerReviewsOptIn(ByVal idDocumento As Integer)
        If idDocumento <> _authorizedDocumentId OrElse Not IsAuthorizedDocumentScopeCurrent() Then Return
        Try
            If Not String.Equals(Convert.ToString(Request.QueryString("payreturn")), "ok", StringComparison.OrdinalIgnoreCase) Then Return

            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Dim script As String = String.Empty
            Using c As New MySqlConnection(cs)
                c.Open()
                script = KeepStoreGoogleCustomerReviews.TryBuildForDocument(c, Session, idDocumento, _authorizedIdentity.UtentiId, _authorizedIdentity.CompanyId)
            End Using
            If script.Length = 0 Then Return

            litGoogleSurveyOptIn.Text = script
            KeepStoreSecurity.AllowGoogleCustomerReviews(Response)
            Response.Cache.SetCacheability(HttpCacheability.Private)
            Response.Cache.SetNoStore()
        Catch
            ' Fail-closed: nessun impatto sulla pagina del documento.
        End Try
    End Sub

    '==============================================================
    ' KeepStore: immagine prodotto sicura (fallback nofoto)
    '==============================================================
    Protected Function SafeImg(ByVal temp As Object) As String
        Return ThemeManager.ProductImageUrl(temp)
    End Function

End Class
