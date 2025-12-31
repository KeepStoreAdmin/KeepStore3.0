Imports System.Net.Mail

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

            Dim oMsg As MailMessage = New MailMessage()
            oMsg.From = New MailAddress(Me.TextBox_email.Text, Me.TextBox_nome.Text)
            oMsg.To.Add(New MailAddress(Session("AziendaEmail")))
            oMsg.Subject = Me.DropDownList_subject.SelectedValue
            oMsg.Body = Me.TextBox_testo.Text

            oMsg.IsBodyHtml = True

            Dim oSmtp As SmtpClient = New SmtpClient(Me.Session.Item("smtp"))
            oSmtp.DeliveryMethod = SmtpDeliveryMethod.Network

            Dim oCredential As System.Net.NetworkCredential = New System.Net.NetworkCredential(CType(Session.Item("User_smtp"), String), CType(Session.Item("Password_smtp"), String))
			oSmtp.UseDefaultCredentials = True
            oSmtp.Credentials = oCredential

            'ATTENZIONE
            oSmtp.Send(oMsg)

            Me.Label_esito.Text = "Richiesta inoltrata"
        Catch ex As Exception
            Me.Label_esito.Text = "Errore - " & ex.Message.ToString
        End Try
    End Sub

    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreInit
        If (Not Request.UrlReferrer Is Nothing) AndAlso (Request.UrlReferrer.AbsoluteUri.Contains("coupon")) Then
            Page.MasterPageFile = "Coupon.master"
        Else
            Page.MasterPageFile = "Page.master"
        End If
    End Sub
End Class
