Imports System
Imports System.Collections.Generic
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls

Partial Class Public_ui_controls_AccountSidebar
    Inherits System.Web.UI.UserControl

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        Dim currentKey As String = GetCurrentActiveKey()
        Dim currentPage As String = GetCurrentPageName()

        ' Se non siamo in un'area account, non mostriamo il menu (evita visualizzazioni fuori contesto)
        If Not IsAccountArea(currentPage) Then
            Me.Visible = False
            Return
        End If

        SetRootLinks()
        SetActiveMenuCss(currentKey)
    End Sub

    Private Sub SetRootLinks()
        lnkDashboard.HRef = ResolveUrl("~/myaccount.aspx")
        lnkDati.HRef = ResolveUrl("~/my-account-edit.aspx")
        lnkIndirizzi.HRef = ResolveUrl("~/my-account-address.aspx")
        lnkOrdini.HRef = ResolveUrl("~/documenti.aspx")
        lnkWishlist.HRef = ResolveUrl("~/wishlist.aspx")
        lnkPassword.HRef = ResolveUrl("~/password.aspx")
        lnkLogout.HRef = ResolveUrl("~/logout.aspx")
    End Sub

    Private Function GetCurrentPageName() As String
        Dim path As String = (Request.Url.AbsolutePath & "").ToLowerInvariant()
        Dim fileName As String = System.IO.Path.GetFileName(path)
        Return fileName
    End Function

    Private Function GetCurrentActiveKey() As String
        Dim pageName As String = GetCurrentPageName()

        If pageName = "datiutente.aspx" Then
            Dim tab As String = (Request.QueryString("tab") & "").ToLowerInvariant()
            If tab = "addr" OrElse tab = "addresses" OrElse tab = "indirizzi" Then
                Return "my-account-address.aspx"
            End If
            Return "my-account-edit.aspx"
        End If


        If pageName = "documentidettaglio.aspx" Then
            Return "documenti.aspx"
        End If

        If pageName = "cambiapassword.aspx" Then
            Return "password.aspx"
        End If

        Return pageName
    End Function

    Private Sub SetActiveMenuCss(currentKey As String)
        ClearActiveState(lnkDashboard)
        ClearActiveState(lnkDati)
        ClearActiveState(lnkIndirizzi)
        ClearActiveState(lnkOrdini)
        ClearActiveState(lnkWishlist)
        ClearActiveState(lnkPassword)
        ClearActiveState(lnkLogout)

        Select Case (currentKey & "").ToLowerInvariant()
            Case "myaccount.aspx"
                SetActiveState(lnkDashboard)
            Case "my-account-edit.aspx"
                SetActiveState(lnkDati)
            Case "my-account-address.aspx"
                SetActiveState(lnkIndirizzi)
            Case "documenti.aspx"
                SetActiveState(lnkOrdini)
            Case "wishlist.aspx"
                SetActiveState(lnkWishlist)
            Case "password.aspx"
                SetActiveState(lnkPassword)
            Case "logout.aspx"
                SetActiveState(lnkLogout)
        End Select
    End Sub

    Private Sub SetActiveState(anchor As HtmlAnchor)
        If anchor Is Nothing Then Return

        Dim cls As String = RemoveCssClass(anchor.Attributes("class"), "active")
        anchor.Attributes("class") = (cls & " active").Trim()
        anchor.Attributes("aria-current") = "page"
    End Sub

    Private Sub ClearActiveState(anchor As HtmlAnchor)
        If anchor Is Nothing Then Return

        anchor.Attributes("class") = RemoveCssClass(anchor.Attributes("class"), "active")
        anchor.Attributes.Remove("aria-current")
    End Sub

    Private Function RemoveCssClass(classValue As String, className As String) As String
        Dim parts As New List(Of String)()

        For Each part As String In (classValue & "").Split(New Char() {" "c}, StringSplitOptions.RemoveEmptyEntries)
            If Not String.Equals(part, className, StringComparison.OrdinalIgnoreCase) Then
                parts.Add(part)
            End If
        Next

        Return String.Join(" ", parts.ToArray())
    End Function

    Private Function IsAccountArea(pageName As String) As Boolean
        Select Case (pageName & "").ToLowerInvariant()
            Case "myaccount.aspx",
                 "datiutente.aspx",
                 "my-account-edit.aspx",
                 "my-account-address.aspx",
                 "documenti.aspx",
                 "wishlist.aspx",
                 "password.aspx",
                 "cambiapassword.aspx",
                 "remind.aspx",
                 "logout.aspx",
                 "login.aspx",
                 "registrazione.aspx",
                 "accessonegato.aspx",
                 "indirizzi.aspx"
                Return True
        End Select

        Return False
    End Function
End Class
