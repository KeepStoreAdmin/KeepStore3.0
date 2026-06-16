Partial Class resetpassword
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not IsPostBack Then
            LoadResetState()
        End If
    End Sub

    Protected Sub btnReset_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnReset.Click
        lblMessage.Text = ""
        lblSuccess.Text = ""

        Page.Validate()
        If Not Page.IsValid Then
            ShowForm()
            Exit Sub
        End If

        Dim message As String = ""
        If PasswordResetTokenService.CompleteReset(CurrentToken(), Convert.ToString(tbPasswordNuova.Text), Convert.ToString(tbPasswordConferma.Text), message) Then
            tbPasswordNuova.Text = ""
            tbPasswordConferma.Text = ""
            pnlResetForm.Visible = False
            pnlInvalid.Visible = False
            pnlSuccess.Visible = True
            lblSuccess.Text = message
        Else
            If IsInvalidTokenMessage(message) Then
                ShowInvalid()
            Else
                ShowForm()
                lblMessage.Text = message
            End If
        End If
    End Sub

    Private Sub LoadResetState()
        Dim token As String = CurrentToken()
        If String.IsNullOrWhiteSpace(token) Then
            ShowInvalid()
            Exit Sub
        End If

        Dim info As PasswordResetTokenInfo = Nothing
        If PasswordResetTokenService.TryValidateToken(token, info) Then
            ShowForm()
        Else
            ShowInvalid()
        End If
    End Sub

    Private Function CurrentToken() As String
        Dim rawToken As String = Nothing
        If Request IsNot Nothing AndAlso Request.QueryString IsNot Nothing Then
            rawToken = Request.QueryString("token")
        End If

        If String.IsNullOrWhiteSpace(rawToken) Then Return ""
        Return rawToken.Trim()
    End Function

    Private Sub ShowForm()
        pnlInvalid.Visible = False
        pnlSuccess.Visible = False
        pnlResetForm.Visible = True
    End Sub

    Private Sub ShowInvalid()
        pnlResetForm.Visible = False
        pnlSuccess.Visible = False
        pnlInvalid.Visible = True
    End Sub

    Private Function IsInvalidTokenMessage(ByVal message As String) As Boolean
        Return Convert.ToString(message).IndexOf("link di reset", StringComparison.OrdinalIgnoreCase) >= 0
    End Function
End Class
