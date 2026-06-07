Partial Class Remind
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        'Me.lblSito.Text = Session("AziendaNome")

        If IsResetRequestSent() Then
            ShowSentConfirmation()
            Return
        End If

        If Not IsPostBack Then
            ShowRequestForm()
        End If
    End Sub

    Protected Sub btInvia_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btInvia.Click
        Me.lblerror.Visible = False

        If IsResetRequestSent() Then
            ShowSentConfirmation()
            Return
        End If

        If Not Page.IsValid Then
            Exit Sub
        End If

        PasswordResetTokenService.RequestReset(Me.tbEmail.Text, Me.txtFiscalCodeOrVat.Text, Me)
        RedirectToSentPage()
        Return
    End Sub

    Private Function IsResetRequestSent() As Boolean
        Return String.Equals(Convert.ToString(Request.QueryString("sent")), "1", StringComparison.Ordinal)
    End Function

    Private Sub RedirectToSentPage()
        Response.Clear()
        Response.StatusCode = 303
        Response.RedirectLocation = ResolveUrl("~/remind.aspx?sent=1")
        Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache)
        Response.Cache.SetNoStore()
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Sub ShowRequestForm()
        Me.lblerror.Visible = False
        Me.lblOk.Visible = False
        Me.pnlLoading.Visible = False
        Me.pnlContent.Style("display") = "block"
        Me.pnlSentConfirmation.Visible = False
        Me.pnlRequestIntro.Visible = True
        Me.pnlRequestForm.Visible = True
        Me.pnlOperationProgress.Visible = True
    End Sub

    Private Sub ShowSentConfirmation()
        Me.lblerror.Visible = False
        Me.lblOk.Visible = False
        Me.tbEmail.Text = ""
        Me.txtFiscalCodeOrVat.Text = ""
        Me.pnlLoading.Visible = False
        Me.pnlContent.Style("display") = "block"
        Me.pnlSentConfirmation.Visible = True
        Me.pnlRequestIntro.Visible = False
        Me.pnlRequestForm.Visible = False
        Me.pnlOperationProgress.Visible = False
    End Sub

    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreInit
        Try
            If Request.UrlReferrer.AbsoluteUri.Contains("coupon") Then
                Page.MasterPageFile = "Coupon.master"
            Else
                Page.MasterPageFile = "Page.master"
            End If
        Catch
        End Try
    End Sub
End Class
