Imports System.Net.Mail
Imports System.Net.Mime
Imports System.Text
Imports System.Web

Partial Class main
    Inherits System.Web.UI.Page

    Protected Sub fvPage_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles fvPage.PreRender
        Try
            Dim lbl As Label
            lbl = Me.fvPage.FindControl("lblTitolo")
            Me.Title = Me.Title & " - " & lbl.Text

            If ((lbl.Text = "Contatti") Or (lbl.Text = "Contattaci") Or (lbl.Text = "Contact")) Then
                Me.Form_Contatti.Visible = True
            Else
                Me.Form_Contatti.Visible = False
            End If
        Catch
            Response.Redirect("default.aspx")
        End Try
    End Sub

    Protected Sub Button_Invia_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_Invia.Click
        Try
            Me.Label_esito.Visible = True

            Dim aziendaEmail As String = SessionText("AziendaEmail")
            Dim aziendaNome As String = SessionText("AziendaNome")
            Dim userName As String = ControlText(Me.TextBox_nome, 120)
            Dim userEmail As String = ControlText(Me.TextBox_email, 180)
            Dim reason As String = HeaderText(Me.DropDownList_subject.SelectedValue, 150)
            Dim messageText As String = ControlText(Me.TextBox_testo, 4000)

            If aziendaEmail = "" Then
                Throw New InvalidOperationException("Email azienda non configurata.")
            End If

            Dim oMsg As MailMessage = New MailMessage()
            oMsg.From = New MailAddress(aziendaEmail, FirstNonEmpty(aziendaNome, "KeepStore"))
            oMsg.To.Add(New MailAddress(aziendaEmail, FirstNonEmpty(aziendaNome, "KeepStore")))
            If userEmail <> "" Then
                oMsg.ReplyToList.Add(New MailAddress(userEmail, userName))
            End If
            oMsg.Subject = HeaderText(FirstNonEmpty(reason, "Richiesta dal sito"), 150)
            ConfigureContactEmailEncoding(oMsg)
            ApplyRenderedContactEmailMime(oMsg, RenderContactEmail(userName, userEmail, reason, messageText))

            Dim oSmtp As SmtpClient = New SmtpClient(Me.Session.Item("smtp"))
            oSmtp.DeliveryMethod = SmtpDeliveryMethod.Network

            Dim oCredential As System.Net.NetworkCredential = New System.Net.NetworkCredential(CType(Session.Item("User_smtp"), String), CType(Session.Item("Password_smtp"), String))
            oSmtp.UseDefaultCredentials = True
            oSmtp.Credentials = oCredential

            oSmtp.Send(oMsg)

            Me.Label_esito.Text = "Richiesta inoltrata"
        Catch ex As Exception
            Me.Label_esito.Visible = True
            KeepStoreLog.Error("main-contact", "Errore invio mail contatto legacy main", ex, HttpContext.Current)
            Me.Label_esito.Text = "Non e stato possibile inviare la richiesta. Riprova piu tardi o contattaci telefonicamente."
        End Try
    End Sub

    Private Function RenderContactEmail(ByVal userName As String,
                                        ByVal userEmail As String,
                                        ByVal reason As String,
                                        ByVal messageText As String) As KeepStoreEmailRenderResult
        Dim brand As New KeepStoreEmailBrandInfo()
        brand.CompanyName = SessionText("AziendaNome")
        brand.SupportEmail = SessionText("AziendaEmail")
        brand.SiteUrl = BuildSiteHomeUrl()
        brand.LogoWeb = KeepStoreEmailLogo.SafeLogoFileName(SessionText("AziendaLogo"))

        Return KeepStoreContactEmailMessages.RenderContactRequest(brand, userName, userEmail, reason, messageText)
    End Function

    Private Sub ConfigureContactEmailEncoding(ByVal message As MailMessage)
        message.SubjectEncoding = Encoding.UTF8
        message.BodyEncoding = Encoding.UTF8
        message.HeadersEncoding = Encoding.UTF8
    End Sub

    Private Sub ApplyRenderedContactEmailMime(ByVal message As MailMessage, ByVal renderedEmail As KeepStoreEmailRenderResult)
        message.AlternateViews.Clear()
        message.Body = ""
        message.IsBodyHtml = False

        Dim plainBody As String = renderedEmail.PlainTextBody
        If String.IsNullOrWhiteSpace(plainBody) Then
            plainBody = "Richiesta contatto disponibile in formato HTML."
        End If

        message.AlternateViews.Add(AlternateView.CreateAlternateViewFromString(plainBody, Encoding.UTF8, MediaTypeNames.Text.Plain))
        message.AlternateViews.Add(AlternateView.CreateAlternateViewFromString(renderedEmail.HtmlBody, Encoding.UTF8, MediaTypeNames.Text.Html))
    End Sub

    Private Function ControlText(ByVal control As TextBox, ByVal maxLength As Integer) As String
        If control Is Nothing OrElse control.Text Is Nothing Then
            Return ""
        End If

        Dim value As String = control.Text.Replace(ControlChars.NullChar, " "c).Trim()
        If maxLength > 0 AndAlso value.Length > maxLength Then
            value = value.Substring(0, maxLength)
        End If

        Return value
    End Function

    Private Function HeaderText(ByVal value As String, ByVal maxLength As Integer) As String
        If value Is Nothing Then
            Return ""
        End If

        Dim clean As String = value.Replace(ControlChars.Cr, " ").Replace(ControlChars.Lf, " ").Replace(ControlChars.NullChar, " "c).Trim()
        If maxLength > 0 AndAlso clean.Length > maxLength Then
            clean = clean.Substring(0, maxLength)
        End If

        Return clean
    End Function

    Private Function SessionText(ByVal key As String) As String
        If Session Is Nothing OrElse Session(key) Is Nothing Then
            Return ""
        End If

        Return Convert.ToString(Session(key)).Trim()
    End Function

    Private Function FirstNonEmpty(ParamArray values() As String) As String
        If values Is Nothing Then
            Return ""
        End If

        For Each value As String In values
            If Not String.IsNullOrWhiteSpace(value) Then
                Return value.Trim()
            End If
        Next

        Return ""
    End Function

    Private Function BuildSiteHomeUrl() As String
        Dim url As String = SessionText("AziendaUrl")
        If url = "" Then
            Return "https://www.taikun.it"
        End If

        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) Then
            Return "https://" & url.Substring(7)
        End If

        If url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return url
        End If

        Return "https://" & url
    End Function

    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreInit
        If (Not Request.UrlReferrer Is Nothing) AndAlso (Request.UrlReferrer.AbsoluteUri.Contains("coupon")) Then
            Page.MasterPageFile = "Coupon.master"
        Else
            Page.MasterPageFile = "Page.master"
        End If
    End Sub
End Class
