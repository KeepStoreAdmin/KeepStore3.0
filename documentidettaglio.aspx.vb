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
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Richiede login
        If Session("LoginId") Is Nothing OrElse Convert.ToString(Session("LoginId")) = "" Then
            Response.Redirect("accessonegato.aspx")
            Return
        End If

        Dim idDocumento As Integer = GetRequestedDocumentId()
        If idDocumento <= 0 Then
            Response.Redirect("documenti.aspx?t=" & GetFallbackTipoDocumentoId().ToString(), True)
            Return
        End If

        If Not IsPostBack Then
            Dim tipoDocId As Integer = -1
            If Not DocumentoAppartieneAUtente(idDocumento, tipoDocId) Then
                Response.Redirect("documenti.aspx?t=" & GetFallbackTipoDocumentoId().ToString(), True)
                Return
            End If

            ' Breadcrumb: torna alla tipologia corretta
            If tipoDocId > 0 Then
                hlDocumenti.NavigateUrl = "documenti.aspx?t=" & tipoDocId.ToString()
            Else
                hlDocumenti.NavigateUrl = "documenti.aspx?t=" & GetFallbackTipoDocumentoId().ToString()
            End If

            ConfigurePayReturnMessage()

            ' Google Customer Reviews - Survey Opt-in (mostra solo al rientro dal checkout)
            TryRenderGoogleCustomerReviewsOptIn(idDocumento)

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
            litPayReturnMessage.Text = "Pagamento non completato. Puoi riprovare da questo ordine o scegliere un altro metodo, se disponibile."
            pnlPayReturnMessage.Visible = True
        End If
    End Sub

    Private Function DocumentoAppartieneAUtente(ByVal idDocumento As Integer, ByRef tipoDocId As Integer) As Boolean
        tipoDocId = -1
        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Using cmd As New MySqlCommand("SELECT TipoDocumentiId FROM vdocumenti WHERE Id=@id AND UtentiId=@uid LIMIT 1", c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = idDocumento
                    cmd.Parameters.Add("@uid", MySqlDbType.Int32).Value = Convert.ToInt32(Session("UtentiID"))
                    c.Open()
                    Dim o As Object = cmd.ExecuteScalar()
                    If o Is Nothing OrElse Convert.IsDBNull(o) Then Return False
                    Integer.TryParse(Convert.ToString(o), tipoDocId)
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
    Protected Function SeparaTracking(ByVal trackingObj As Object, ByVal linkTrackingObj As Object) As String
        Dim tracking As String = Convert.ToString(trackingObj)
        Dim linkTracking As String = Convert.ToString(linkTrackingObj)

        If String.IsNullOrEmpty(tracking) OrElse String.IsNullOrEmpty(linkTracking) Then
            Return String.Empty
        End If

        Dim parts() As String = tracking.Split(";"c)
        If parts Is Nothing OrElse parts.Length = 0 Then
            Return String.Empty
        End If

        Dim sb As New StringBuilder()
        For i As Integer = 0 To parts.Length - 1
            Dim code As String = Convert.ToString(parts(i)).Trim()
            If code = "" Then
                Continue For
            End If

            Dim url As String = linkTracking.Replace("#ID#", HttpUtility.UrlEncode(code))

            ' Permetti solo http/https; in caso contrario, mostra solo il testo.
            Dim urlTrim As String = url.Trim().ToLowerInvariant()
            Dim isHttp As Boolean = (urlTrim.StartsWith("http://") OrElse urlTrim.StartsWith("https://"))

            If isHttp Then
	                sb.Append("<a class=""link"" href=""")
                sb.Append(HttpUtility.HtmlAttributeEncode(url))
			    		    sb.Append(""" target=""_blank"" rel=""noopener noreferrer"">")
                sb.Append(HttpUtility.HtmlEncode(code))
                sb.Append("</a>")
            Else
                sb.Append(HttpUtility.HtmlEncode(code))
            End If

            If i < parts.Length - 1 Then
	                sb.Append(" <span class=""ks-muted"">;</span> ")
            End If
        Next

        Return sb.ToString()
    End Function

    Protected Function FormatOrderStatus(ByVal stato1Obj As Object, ByVal stato2Obj As Object) As String
        Dim stato1 As String = SafeStatusText(stato1Obj)
        Dim stato2 As String = SafeStatusText(stato2Obj)

        If stato1 = "" Then Return If(stato2 = "", "Non disponibile", stato2)
        If stato2 = "" Then Return stato1
        Return (stato1 & " " & stato2).Trim()
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
            Return "Abbiamo ricevuto il pagamento. Trovi qui riepilogo, indirizzi e prossimi passi."
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

    Protected Function GetTrackingMessage(ByVal trackingObj As Object, ByVal linkTrackingObj As Object) As String
        Dim tracking As String = SafeStatusText(trackingObj)
        If tracking = "" Then Return "Tracking non ancora disponibile."

        Dim rendered As String = SeparaTracking(trackingObj, linkTrackingObj)
        If rendered <> "" Then Return rendered

        Return HtmlText(tracking)
    End Function

    Protected Function GetTimelineStepCssClass(ByVal stepName As String, ByVal pagatoObj As Object, ByVal statoObj As Object, ByVal trackingObj As Object) As String
        Dim stepValue As String = Convert.ToString(stepName).Trim().ToLowerInvariant()

        If stepValue = "payment" Then
            If IsPaymentConfirmed(pagatoObj, statoObj) Then Return "is-complete"
            Return "is-current"
        End If

        If stepValue = "shipping" Then
            If SafeStatusText(trackingObj) <> "" Then Return "is-complete"
            Return ""
        End If

        Return ""
    End Function

    Protected Function GetTimelinePaymentText(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        If IsPaymentConfirmed(pagatoObj, statoObj) Then Return "Pagamento ricevuto"
        Return "Pagamento in verifica"
    End Function

    Protected Function GetTimelineShippingText(ByVal trackingObj As Object) As String
        If SafeStatusText(trackingObj) <> "" Then Return "Spedizione tracciata"
        Return "Tracking non ancora disponibile"
    End Function

    Private Function IsPaymentConfirmed(ByVal pagatoObj As Object, ByVal statoObj As Object) As Boolean
        Return SafeInt(pagatoObj, 0) = 1 OrElse SafeInt(statoObj, 0) = 2
    End Function

    Protected Function GetPaymentStatusLabel(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)

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
            Case Else
                Return "Non avviato"
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
        Dim esito As String = SafeStatusText(esitoObj)
        If esito <> "" Then Return esito

        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)

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
        ' Mostra i pulsanti di pagamento online solo quando la policy "Paga ora" lo consente.
        ' Logica volutamente conservativa per evitare regressioni: in dubbio, lascia nascosto.
        Try
            If FormView1 Is Nothing Then
                Return
            End If

            Dim hlSella As Control = FindFormViewControl("hlBancaSella")
            Dim hlPayPal As Control = FindFormViewControl("hlPayPalExpress")
            Dim btIw As Control = FindFormViewControl("btIwBank")
            Dim btPP As Control = FindFormViewControl("btPayPal")
            Dim pnlPayNow As Control = FindFormViewControl("pnlPayNowCard")

            ' Default: nascondi
            SetVisible(pnlPayNow, False)
            SetVisible(hlSella, False)
            SetVisible(hlPayPal, False)
            SetVisible(btIw, False)
            SetVisible(btPP, False)

            Dim documentId As Integer = GetRequestedDocumentId()
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
                ConfigurePayPalExpressPayNowLink(hlPayPal, info.DocumentId)
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

    Private Sub ConfigurePayPalExpressPayNowLink(ByVal hlPayPal As Control, ByVal documentId As Integer)
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
        Dim idDocumento As Integer = 0
        If Integer.TryParse(Convert.ToString(Request.QueryString("id")), idDocumento) AndAlso idDocumento > 0 Then
            Return idDocumento
        End If

        If IsPostBack Then
            Return GetPostedDocumentId()
        End If

        Return -1
    End Function

    Private Function GetPostedDocumentId() As Integer
        Try
            For Each key As String In Request.Form.AllKeys
                If key IsNot Nothing AndAlso key.EndsWith("$hfPayNowDocumentId", StringComparison.OrdinalIgnoreCase) Then
                    Dim postedId As Integer = 0
                    If Integer.TryParse(Convert.ToString(Request.Form(key)), postedId) AndAlso postedId > 0 Then
                        Return postedId
                    End If
                End If
            Next
        Catch
        End Try

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
        If documentId <= 0 Then Return Nothing

        Try
            Dim utentiId As Integer = SafeInt(Session("UtentiID"), 0)
            If utentiId <= 0 Then Return Nothing

            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Dim sql As String = ""
                sql &= "SELECT "
                sql &= "  d.id, d.NDocumento, d.DataDocumento, "
                sql &= "  COALESCE(d.Pagato,0) AS Pagato, "
                sql &= "  COALESCE(d.StatiId,0) AS StatiId, "
                sql &= "  COALESCE(d.StatoPagamentoWeb,0) AS StatoPagamentoWeb, "
                sql &= "  COALESCE(p.OnLine,0) AS PagamentiTipoOnline, "
                sql &= "  COALESCE(p.PermettiPagamentoSuccessivo,0) AS PermettiPagamentoSuccessivo, "
                sql &= "  COALESCE(p.Descrizione,'') AS PagamentiTipoDescrizione, "
                sql &= "  COALESCE(pie.TotaleDocumento,0) AS TotaleDocumento, "
                sql &= "  COALESCE(b.codiceAutorizzazione,'') AS CodiceAutorizzazione "
                sql &= "FROM documenti d "
                sql &= "LEFT JOIN pagamentitipo p ON p.id = d.PagamentiTipoId "
                sql &= "LEFT JOIN documentipie pie ON pie.DocumentiId = d.id "
                sql &= "LEFT JOIN bancasella_ordini_pagati b ON b.DocumentiId = d.id "
                sql &= "WHERE d.id=@id AND d.UtentiId=@uid "
                sql &= "LIMIT 1"

                Using cmd As New MySqlCommand(sql, c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    cmd.Parameters.Add("@uid", MySqlDbType.Int32).Value = utentiId
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
        If info Is Nothing Then Return False

        Return info.Pagato = 0 AndAlso
               info.PagamentiTipoOnline <> 0 AndAlso
               info.PermettiPagamentoSuccessivo = 1 AndAlso
               (info.StatoPagamentoWeb = 0 OrElse info.StatoPagamentoWeb = 3 OrElse info.StatoPagamentoWeb = 4 OrElse info.StatoPagamentoWeb = 5) AndAlso
               String.IsNullOrEmpty(info.CodiceAutorizzazione) AndAlso
               info.StatiId <> 0 AndAlso
               info.StatiId <> 3 AndAlso
               info.TotaleDocumento > 0D
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


    Private Sub TryRenderGoogleCustomerReviewsOptIn(ByVal idDocumento As Integer)
        ' Google Customer Reviews (Survey Opt-in)
        ' Mostra il popup SOLO subito dopo il checkout (gating tramite Session("GCR_ShowOptIn_DocId"))
        Try
            If Session Is Nothing OrElse Session("GCR_ShowOptIn_DocId") Is Nothing Then Return

            Dim sessionDocId As Integer = 0
            If Not Integer.TryParse(Convert.ToString(Session("GCR_ShowOptIn_DocId")), sessionDocId) Then Return
            If sessionDocId <= 0 OrElse sessionDocId <> idDocumento Then Return

            ' Clear early: evita ri-trigger su refresh/visite successive
            Session("GCR_ShowOptIn_DocId") = Nothing

            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Dim merchantId As String = ""
            Dim buyerEmail As String = ""
            Dim deliveryCountry As String = ""
            Dim baseDocDate As DateTime = DateTime.Today

            Dim sql As String = ""
            sql &= "SELECT "
            sql &= "  IFNULL(a.google_merchant_id,'') AS google_merchant_id, "
            sql &= "  IFNULL(u.email,'') AS buyer_email, "
            sql &= "  IFNULL(ui.NazioneA,'') AS nazione, "
            sql &= "  d.DataDocumento AS data_documento "
            sql &= "FROM documenti d "
            sql &= "LEFT JOIN aziende a ON a.id = d.AziendeId "
            sql &= "LEFT JOIN utenti u ON u.id = d.UtentiId "
            sql &= "LEFT JOIN utentiindirizzi ui ON ui.id = d.UtentiIndirizziId "
            sql &= "WHERE d.id=@id AND d.UtentiId=@uid "
            sql &= "LIMIT 1"

            Using c As New MySqlConnection(cs)
                c.Open()

                Using cmd As New MySqlCommand(sql, c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = idDocumento
                    cmd.Parameters.Add("@uid", MySqlDbType.Int32).Value = Convert.ToInt32(Session("UtentiID"))

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            merchantId = Convert.ToString(dr("google_merchant_id")).Trim()
                            buyerEmail = Convert.ToString(dr("buyer_email")).Trim()
                            deliveryCountry = Convert.ToString(dr("nazione")).Trim().ToUpperInvariant()

                            Try
                                Dim oDt As Object = dr("data_documento")
                                If oDt IsNot Nothing AndAlso oDt IsNot DBNull.Value Then
                                    baseDocDate = CType(oDt, DateTime)
                                End If
                            Catch
                            End Try
                        End If
                    End Using
                End Using
            End Using

            ' Parametri minimi richiesti da Google
            If String.IsNullOrWhiteSpace(merchantId) Then Return
            If String.IsNullOrWhiteSpace(buyerEmail) Then Return

            If String.IsNullOrWhiteSpace(deliveryCountry) OrElse deliveryCountry.Length <> 2 Then
                deliveryCountry = "IT"
            End If

            ' Strategia B: data stimata consegna deterministica (DataDocumento + N giorni)
            Const defaultDeliveryDays As Integer = 5
            Dim estimatedDelivery As DateTime = baseDocDate.AddDays(defaultDeliveryDays)
            Dim estimatedDeliveryStr As String = estimatedDelivery.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)

            Dim orderIdStr As String = idDocumento.ToString(CultureInfo.InvariantCulture)

            ' Output encoding (JS)
            Dim jsMerchantId As String = HttpUtility.JavaScriptStringEncode(merchantId)
            Dim jsOrderId As String = HttpUtility.JavaScriptStringEncode(orderIdStr)
            Dim jsEmail As String = HttpUtility.JavaScriptStringEncode(buyerEmail)
            Dim jsCountry As String = HttpUtility.JavaScriptStringEncode(deliveryCountry)
            Dim jsEdd As String = HttpUtility.JavaScriptStringEncode(estimatedDeliveryStr)

            Dim sb As New StringBuilder()
            sb.AppendLine("<script src=""https://apis.google.com/js/platform.js?onload=renderOptIn"" async defer></script>")
            sb.AppendLine("<script>")
            sb.AppendLine("window.renderOptIn = function() {")
            sb.AppendLine("  window.gapi.load('surveyoptin', function() {")
            sb.AppendLine("    window.gapi.surveyoptin.render({")
            sb.AppendLine("      ""merchant_id"": """ & jsMerchantId & """,")
            sb.AppendLine("      ""order_id"": """ & jsOrderId & """,")
            sb.AppendLine("      ""email"": """ & jsEmail & """,")
            sb.AppendLine("      ""delivery_country"": """ & jsCountry & """,")
            sb.AppendLine("      ""estimated_delivery_date"": """ & jsEdd & """")
            sb.AppendLine("    });")
            sb.AppendLine("  });")
            sb.AppendLine("};")
            sb.AppendLine("</script>")

            litGoogleSurveyOptIn.Text = sb.ToString()

        Catch
            ' Fail-closed: nessun impatto sul checkout
        End Try
    End Sub

    '==============================================================
    ' KeepStore: immagine prodotto sicura (fallback nofoto)
    '==============================================================
    Protected Function SafeImg(ByVal temp As Object) As String
        Dim imgname As String = ""
        Try
            If temp IsNot Nothing AndAlso Not Convert.IsDBNull(temp) Then
                imgname = Convert.ToString(temp)
            End If
        Catch
        End Try

        If imgname Is Nothing Then imgname = ""
        imgname = imgname.Trim()

        If imgname = "" Then
            Return ThemeManager.PlaceholderProductImageUrl()
        End If

        If imgname.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse imgname.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return imgname
        End If

        imgname = imgname.Replace("\\", "/").Replace("\", "/")
        imgname = IO.Path.GetFileName(imgname)
        If String.IsNullOrWhiteSpace(imgname) Then Return ThemeManager.PlaceholderProductImageUrl()
        Return ResolveUrl("~/Public/assets/images/articoli/" & imgname)
    End Function

End Class
