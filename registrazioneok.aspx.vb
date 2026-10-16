
Partial Class registrazioneok
    Inherits System.Web.UI.Page

    Private _isCouponConfirmation As Boolean
    Private _confirmationTargetUrl As String = "Default.aspx"

    Protected ReadOnly Property ConfirmationTargetUrl As String
        Get
            Return _confirmationTargetUrl
        End Get
    End Property

    Protected ReadOnly Property ConfirmationActionText As String
        Get
            Return If(_isCouponConfirmation, "Vai al login", "Vai allo shop")
        End Get
    End Property

    Protected ReadOnly Property ConfirmationRedirectMessage As String
        Get
            Return If(_isCouponConfirmation,
                      "Tra pochi secondi verrai reindirizzato al login per accedere.",
                      "Tra pochi secondi verrai reindirizzato allo shop.")
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Page.master nests a placeholder in the title; Coupon.master uses plain text.
        For Each control As System.Web.UI.Control In Page.Header.Controls
            Dim title As System.Web.UI.HtmlControls.HtmlTitle = TryCast(control, System.Web.UI.HtmlControls.HtmlTitle)
            If title IsNot Nothing Then title.Controls.Clear()
        Next
        Page.Title = "Registrazione completata"

        If _isCouponConfirmation Then
            Dim safeReturnUrl As String = String.Empty
            Dim redirectValues() As String = Request.QueryString.GetValues("redirect")
            If redirectValues IsNot Nothing AndAlso redirectValues.Length = 1 AndAlso
               Request.QueryString.GetValues("ReturnUrl") Is Nothing Then
                safeReturnUrl = PostLoginReturnUrlPolicy.NormalizeReturnUrl(Context, redirectValues(0))
            End If

            _confirmationTargetUrl = PostLoginReturnUrlPolicy.BuildLoginUrl(Context, safeReturnUrl)
        Else
            _confirmationTargetUrl = ResolveUrl("~/Default.aspx")
        End If
    End Sub

    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreInit
        Dim stateValues() As String = Request.QueryString.GetValues("state")
        _isCouponConfirmation = stateValues IsNot Nothing AndAlso stateValues.Length = 1 AndAlso
                                String.Equals(stateValues(0), "coupon", StringComparison.OrdinalIgnoreCase)
        Page.MasterPageFile = If(_isCouponConfirmation, "~/Coupon.master", "~/Page.master")
    End Sub
End Class
