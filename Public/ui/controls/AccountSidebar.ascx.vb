Imports System
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

        SetActiveMenuCss(currentKey, currentPage)
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

        Return pageName
    End Function

    Private Sub SetActiveMenuCss(currentKey As String, currentPage As String)
        For Each li As Control In ulMenu.Controls
            Dim anchor As HtmlAnchor = TryCast(FindAnchor(li), HtmlAnchor)
            If anchor Is Nothing Then Continue For

            Dim activeKey As String = (anchor.Attributes("data-ks-active") & "").ToLowerInvariant().Trim()
            If String.IsNullOrEmpty(activeKey) Then Continue For

            Dim isActive As Boolean

            ' se data-ks-active contiene querystring, confronta con currentKey
            If activeKey.Contains("?") Then
                isActive = (activeKey = currentKey)
            Else
                ' fallback: confronto solo pagina
                isActive = (activeKey = currentPage)
            End If

            If isActive Then
                If Not anchor.Attributes("class").Contains("active") Then
                    anchor.Attributes("class") = (anchor.Attributes("class") & " active").Trim()
                End If
                anchor.Attributes("aria-current") = "page"
            Else
                ' rimuovi active se presente
                Dim cls As String = (anchor.Attributes("class") & "").Replace(" active", "").Replace("active", "").Trim()
                anchor.Attributes("class") = cls
                anchor.Attributes.Remove("aria-current")
            End If
        Next
    End Sub

    Private Function FindAnchor(parent As Control) As Control
        If parent Is Nothing Then Return Nothing

        ' In alcuni casi ulMenu contiene LiteralControls per whitespace
        For Each c As Control In parent.Controls
            Dim a As HtmlAnchor = TryCast(c, HtmlAnchor)
            If a IsNot Nothing Then Return a

            Dim nested As Control = FindAnchor(c)
            If nested IsNot Nothing Then Return nested
        Next

        Return Nothing
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
