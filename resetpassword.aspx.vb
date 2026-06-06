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
        Dim info As PasswordResetTokenInfo = Nothing
        If PasswordResetTokenService.TryValidateToken(CurrentToken(), info) Then
            ShowForm()
        Else
            ShowInvalid()
        End If
    End Sub

    Private Function CurrentToken() As String
        Return Convert.ToString(Request.QueryString("token")).Trim()
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
