Imports System
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls

Partial Public Class UI_HomeDepartmentsMenu
    Inherits UserControl

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Not IsPostBack Then
            BindCatalogMenu()
        End If
    End Sub

    Private Sub BindCatalogMenu()
        Dim sectors = CatalogMenuProvider.LoadCatalogMenu()
        rptSettoriHome.DataSource = sectors
        rptSettoriHome.DataBind()
    End Sub

    Protected Sub rptSettoriHome_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e.Item Is Nothing OrElse (e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem) Then
            Return
        End If

        Dim sector As CatalogMenuSector = TryCast(e.Item.DataItem, CatalogMenuSector)
        Dim lit As Literal = TryCast(e.Item.FindControl("litDesktopSubmenu"), Literal)
        If sector Is Nothing OrElse lit Is Nothing Then
            Return
        End If

        lit.Text = BuildDesktopSubMenuHtml(sector)
    End Sub

    Private Function BuildDesktopSubMenuHtml(ByVal sector As CatalogMenuSector) As String
        Dim sb As New StringBuilder()

        If sector Is Nothing Then
            Return String.Empty
        End If

        If sector.Categories Is Nothing OrElse sector.Categories.Count = 0 Then
            sb.Append("<li class='sub-menu-item'><a href='")
            sb.Append(HttpUtility.HtmlAttributeEncode(sector.DefaultUrl))
            sb.Append("' class='body-md-2 link'>")
            sb.Append(HttpUtility.HtmlEncode(sector.Descrizione))
            sb.Append("</a></li>")
            Return sb.ToString()
        End If

        For Each category As CatalogMenuCategory In sector.Categories
            If category Is Nothing Then
                Continue For
            End If

            sb.Append("<li class='sub-menu-item ks-home-submenu-grouped'>")
            sb.Append("<div class='ks-home-submenu-card'>")
            sb.Append("<a href='")
            sb.Append(HttpUtility.HtmlAttributeEncode(category.DefaultUrl))
            sb.Append("' class='menu-heading body-small ks-home-submenu-category link'>")
            sb.Append(HttpUtility.HtmlEncode(category.Descrizione))
            sb.Append("</a>")

            If category.Children IsNot Nothing AndAlso category.Children.Count > 0 Then
                sb.Append("<ul class='ks-home-submenu-tipology-list menu-list'>")

                For Each tipologia As CatalogMenuNode In category.Children
                    If tipologia Is Nothing Then
                        Continue For
                    End If

                    sb.Append("<li class='ks-home-submenu-tipology'>")
                    sb.Append("<a href='")
                    sb.Append(HttpUtility.HtmlAttributeEncode(tipologia.DefaultUrl))
                    sb.Append("' class='ks-home-submenu-tipology-link link'>")
                    sb.Append(HttpUtility.HtmlEncode(tipologia.Descrizione))
                    sb.Append("</a>")
                    sb.Append("</li>")
                Next

                sb.Append("</ul>")
            Else
                sb.Append("<a href='")
                sb.Append(HttpUtility.HtmlAttributeEncode(category.DefaultUrl))
                sb.Append("' class='ks-home-submenu-tipology-link link'>Vedi la categoria</a>")
            End If

            sb.Append("</div></li>")
        Next

        Return sb.ToString()
    End Function

    Protected Function SafeText(ByVal value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function
End Class
