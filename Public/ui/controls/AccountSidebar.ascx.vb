Imports System
Imports System.IO

Partial Class AccountSidebar
    Inherits System.Web.UI.UserControl

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Dim file As String = ""
        Try
            file = Path.GetFileName(Request.Path).ToLowerInvariant()
        Catch
            file = ""
        End Try

        ' Renderizza la sidebar solo nell'area account (evita overhead su tutte le pagine)
        Dim isAccountArea As Boolean =
            (file = "myaccount.aspx") OrElse
            (file = "datiutente.aspx") OrElse
            (file = "documenti.aspx") OrElse
            (file = "documentidettaglio.aspx") OrElse
            (file = "wishlist.aspx") OrElse
            (file = "password.aspx") OrElse
            (file = "cambiapassword.aspx") OrElse
            (file = "ordini.aspx") OrElse
            (file = "indirizzi.aspx")

        If Not isAccountArea Then
            Me.Visible = False
            Return
        End If

        Try
            NormalizeOptionalAliases()
            HighlightActive(file)
        Catch
            ' No-op: UI enhancement only
        End Try
    End Sub

    Private Sub NormalizeOptionalAliases()
        ' Password page: alcune installazioni usano password.aspx, altre cambiapassword.aspx
        Dim pwd As String = ResolveExistingPage("password.aspx", "cambiapassword.aspx")
        If Not String.IsNullOrEmpty(pwd) Then
            lnkChangePassword.HRef = pwd
        End If

        ' Recover access: remind.aspx oppure recuperoaccesso.aspx
        Dim rec As String = ResolveExistingPage("remind.aspx", "recuperoaccesso.aspx")
        If Not String.IsNullOrEmpty(rec) Then
            lnkRecoverAccess.HRef = rec
        End If

        ' Logout: se manca, fallback su login.aspx?logout=1 (se esiste)
        Dim lo As String = ResolveExistingPage("logout.aspx", Nothing)
        If String.IsNullOrEmpty(lo) Then
            Dim login As String = ResolveExistingPage("login.aspx", Nothing)
            If Not String.IsNullOrEmpty(login) Then
                lnkLogout.HRef = "login.aspx?logout=1"
            End If
        End If
    End Sub

    Private Function ResolveExistingPage(preferred As String, alternate As String) As String
        Try
            If Not String.IsNullOrEmpty(preferred) Then
                Dim p As String = Server.MapPath("~/" & preferred)
                If File.Exists(p) Then Return preferred
            End If

            If Not String.IsNullOrEmpty(alternate) Then
                Dim a As String = Server.MapPath("~/" & alternate)
                If File.Exists(a) Then Return alternate
            End If
        Catch
            ' ignore
        End Try

        Return preferred
    End Function

    Private Sub HighlightActive(file As String)
        Dim t As String = Convert.ToString(Request("t"))
        Dim tab As String = Convert.ToString(Request("tab"))
        Dim isAddr As Boolean = String.Equals(tab, "addr", StringComparison.OrdinalIgnoreCase)

        SetActive(lnkDashboard, String.Equals(file, "myaccount.aspx", StringComparison.OrdinalIgnoreCase))

        SetActive(lnkAccountDetails,
                  String.Equals(file, "datiutente.aspx", StringComparison.OrdinalIgnoreCase) AndAlso (Not isAddr))

        SetActive(lnkAddresses,
                  String.Equals(file, "datiutente.aspx", StringComparison.OrdinalIgnoreCase) AndAlso isAddr)

        SetActive(lnkOrders,
                  String.Equals(file, "documenti.aspx", StringComparison.OrdinalIgnoreCase) AndAlso String.Equals(t, "4", StringComparison.OrdinalIgnoreCase))

        SetActive(lnkInvoices,
                  String.Equals(file, "documenti.aspx", StringComparison.OrdinalIgnoreCase) AndAlso String.Equals(t, "2", StringComparison.OrdinalIgnoreCase))

        SetActive(lnkDdt,
                  String.Equals(file, "documenti.aspx", StringComparison.OrdinalIgnoreCase) AndAlso String.Equals(t, "1", StringComparison.OrdinalIgnoreCase))

        SetActive(lnkWishlist, String.Equals(file, "wishlist.aspx", StringComparison.OrdinalIgnoreCase))

        SetActive(lnkChangePassword,
                  String.Equals(file, "password.aspx", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(file, "cambiapassword.aspx", StringComparison.OrdinalIgnoreCase))

        SetActive(lnkRecoverAccess,
                  String.Equals(file, "remind.aspx", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(file, "recuperoaccesso.aspx", StringComparison.OrdinalIgnoreCase))

        SetActive(lnkLogout, String.Equals(file, "logout.aspx", StringComparison.OrdinalIgnoreCase))
    End Sub

    Private Sub SetActive(a As System.Web.UI.HtmlControls.HtmlAnchor, isActive As Boolean)
        If a Is Nothing Then Return
        If Not isActive Then Return

        Dim cls As String = Convert.ToString(a.Attributes("class"))
        If cls Is Nothing Then cls = String.Empty

        If cls.IndexOf("is-active", StringComparison.OrdinalIgnoreCase) = -1 Then
            a.Attributes("class") = (cls & " is-active").Trim()
        End If
    End Sub
End Class
