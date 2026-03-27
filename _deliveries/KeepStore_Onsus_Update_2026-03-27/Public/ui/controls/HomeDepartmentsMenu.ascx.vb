Imports System
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
        Dim rpt As Repeater = TryCast(e.Item.FindControl("rptCategorieHome"), Repeater)
        If sector Is Nothing OrElse rpt Is Nothing Then
            Return
        End If

        rpt.DataSource = sector.Categories
        rpt.DataBind()
    End Sub

    Protected Sub rptCategorieHome_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e.Item Is Nothing OrElse (e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem) Then
            Return
        End If

        Dim category As CatalogMenuCategory = TryCast(e.Item.DataItem, CatalogMenuCategory)
        Dim rpt As Repeater = TryCast(e.Item.FindControl("rptTipologieHome"), Repeater)
        If category Is Nothing OrElse rpt Is Nothing Then
            Return
        End If

        rpt.DataSource = category.Children
        rpt.DataBind()
    End Sub

    Protected Function SafeText(ByVal value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function
End Class
