Imports System
Imports System.Collections.Generic
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

Partial Public Class UI_HomeDepartmentsMenu
    Inherits UserControl

    Private Shared ReadOnly BlockedCreativeTokens As String() = {"welcome", "franchis", "onsus", "themesflat", "themeforest", "demo", "placeholder", "sample", "template", "default-banner", "spacer", "blank", "noimage", "no-image", "pixel", "tracking", "sprite"}
    Private Const MaxVisibleCategories As Integer = 8
    Private Const MaxVisibleTipologies As Integer = 10

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Not IsPostBack Then
            BindCatalogMenu()
        End If
    End Sub

    Private Sub BindCatalogMenu()
        Dim sectors As List(Of CatalogMenuSector) = CatalogMenuProvider.LoadCatalogMenu()
        If sectors Is Nothing Then
            sectors = New List(Of CatalogMenuSector)()
        End If

        rptSettoriHome.DataSource = sectors
        rptSettoriHome.DataBind()
    End Sub

    Protected Sub rptSettoriHome_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e.Item Is Nothing OrElse (e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem) Then
            Return
        End If

        Dim sector As CatalogMenuSector = TryCast(e.Item.DataItem, CatalogMenuSector)
        Dim lit As Literal = TryCast(e.Item.FindControl("litDesktopSubmenu"), Literal)
        Dim menuItem As HtmlGenericControl = TryCast(e.Item.FindControl("liMenuItem"), HtmlGenericControl)
        Dim arrowIcon As HtmlGenericControl = TryCast(e.Item.FindControl("arrowIcon"), HtmlGenericControl)
        Dim promoCard As HtmlGenericControl = TryCast(e.Item.FindControl("promoCard"), HtmlGenericControl)
        Dim subMenuContainer As HtmlGenericControl = TryCast(e.Item.FindControl("subMenuContainer"), HtmlGenericControl)
        Dim toggleButton As HtmlButton = TryCast(e.Item.FindControl("toggleButton"), HtmlButton)

        If sector Is Nothing OrElse lit Is Nothing Then
            Return
        End If

        Dim hasChildren As Boolean = HasVisibleCategories(sector)
        Dim promoImageUrl As String = ResolveSectorImageUrl(sector.ImgUrl)
        Dim hasPromoImage As Boolean = Not String.IsNullOrWhiteSpace(promoImageUrl)

        lit.Text = BuildDesktopSubMenuHtml(sector)

        If menuItem IsNot Nothing Then
            menuItem.Attributes("class") = "menu-item " & If(hasChildren, "ks-home-menu-item--branch", "ks-home-menu-item--leaf")
            menuItem.Attributes("data-ks-has-children") = If(hasChildren, "1", "0")
            menuItem.Attributes("data-ks-has-promo") = If(hasPromoImage, "1", "0")
            menuItem.Attributes("data-ks-submenu-mode") = If(hasChildren AndAlso hasPromoImage, "promo", "list")
            menuItem.Attributes("data-ks-open") = "0"
        End If

        If arrowIcon IsNot Nothing Then
            arrowIcon.Visible = hasChildren
        End If

        If toggleButton IsNot Nothing Then
            toggleButton.Visible = hasChildren
            toggleButton.Attributes("aria-expanded") = "false"
            toggleButton.Attributes("data-ks-toggle") = If(hasChildren, "1", "0")
        End If

        If promoCard IsNot Nothing Then
            promoCard.Visible = hasChildren AndAlso hasPromoImage
            promoCard.Attributes("data-ks-hidden") = If(promoCard.Visible, "0", "1")
            promoCard.Attributes("data-ks-layout") = "inline"
            If promoCard.Visible Then
                promoCard.Attributes("data-ks-promo-image") = promoImageUrl
            End If
        End If

        If subMenuContainer IsNot Nothing Then
            subMenuContainer.Visible = hasChildren
            subMenuContainer.Attributes("aria-hidden") = If(hasChildren, "true", "false")
            subMenuContainer.Attributes("data-ks-inline-state") = "closed"
            subMenuContainer.Attributes("data-ks-hidden") = "1"
            subMenuContainer.Attributes("hidden") = "hidden"
            subMenuContainer.Attributes("inert") = "inert"
            subMenuContainer.Attributes("style") = "display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;"
        End If
    End Sub

    Private Function BuildDesktopSubMenuHtml(ByVal sector As CatalogMenuSector) As String
        Dim sb As New StringBuilder()

        If sector Is Nothing Then
            Return String.Empty
        End If

        Dim sectorUrl As String = SafeUrl(sector.DefaultUrl)
        Dim renderedCategories As Integer = 0

        If sector.Categories IsNot Nothing AndAlso sector.Categories.Count > 0 Then
            For Each category As CatalogMenuCategory In sector.Categories
                If category Is Nothing Then
                    Continue For
                End If

                Dim categoryLabel As String = CleanMenuText(category.Descrizione)
                Dim categoryUrl As String = SafeUrl(category.DefaultUrl, sectorUrl)
                If String.IsNullOrWhiteSpace(categoryLabel) Then
                    Continue For
                End If

                Dim tipologyHtml As New StringBuilder()
                Dim validTipologies As Integer = 0

                If category.Children IsNot Nothing AndAlso category.Children.Count > 0 Then
                    For Each tipologia As CatalogMenuNode In category.Children
                        If tipologia Is Nothing Then
                            Continue For
                        End If

                        Dim tipologyLabel As String = CleanMenuText(tipologia.Descrizione)
                        If String.IsNullOrWhiteSpace(tipologyLabel) Then
                            Continue For
                        End If

                        tipologyHtml.Append("<li class='ks-home-submenu-tipology'>")
                        tipologyHtml.Append("<a href='")
                        tipologyHtml.Append(HttpUtility.HtmlAttributeEncode(SafeUrl(tipologia.DefaultUrl, categoryUrl)))
                        tipologyHtml.Append("' class='ks-home-submenu-tipology-link link'>")
                        tipologyHtml.Append(HttpUtility.HtmlEncode(tipologyLabel))
                        tipologyHtml.Append("</a>")
                        tipologyHtml.Append("</li>")
                        validTipologies += 1

                        If validTipologies >= MaxVisibleTipologies Then
                            Exit For
                        End If
                    Next
                End If

                sb.Append("<li class='sub-menu-item ks-home-submenu-grouped'>")
                sb.Append("<div class='ks-home-submenu-card'>")
                sb.Append("<a href='")
                sb.Append(HttpUtility.HtmlAttributeEncode(categoryUrl))
                sb.Append("' class='menu-heading body-small ks-home-submenu-category link'>")
                sb.Append(HttpUtility.HtmlEncode(categoryLabel))
                sb.Append("</a>")

                If validTipologies > 0 Then
                    sb.Append("<ul class='ks-home-submenu-tipology-list menu-list'>")
                    sb.Append(tipologyHtml.ToString())
                    sb.Append("</ul>")
                Else
                    sb.Append("<a href='")
                    sb.Append(HttpUtility.HtmlAttributeEncode(categoryUrl))
                    sb.Append("' class='ks-home-submenu-tipology-link link'>Vedi la categoria</a>")
                End If

                sb.Append("</div></li>")
                renderedCategories += 1

                If renderedCategories >= MaxVisibleCategories Then
                    Exit For
                End If
            Next
        End If

        If renderedCategories = 0 Then
            sb.Append("<li class='sub-menu-item'><a href='")
            sb.Append(HttpUtility.HtmlAttributeEncode(sectorUrl))
            sb.Append("' class='body-md-2 link'>Vedi il settore</a></li>")
        End If

        Return sb.ToString()
    End Function

    Private Function HasVisibleCategories(ByVal sector As CatalogMenuSector) As Boolean
        If sector Is Nothing OrElse sector.Categories Is Nothing OrElse sector.Categories.Count = 0 Then
            Return False
        End If

        For Each category As CatalogMenuCategory In sector.Categories
            If category Is Nothing Then
                Continue For
            End If

            If Not String.IsNullOrWhiteSpace(CleanMenuText(category.Descrizione)) Then
                Return True
            End If
        Next

        Return False
    End Function

    Private Function CleanMenuText(ByVal value As Object) As String
        Dim text As String = HttpUtility.HtmlDecode(Convert.ToString(value)).Trim()
        If String.IsNullOrWhiteSpace(text) Then
            Return String.Empty
        End If

        text = text.Replace(ChrW(160), " "c)
        text = text.Replace(ChrW(&H2013), "-"c)
        text = text.Replace(ChrW(&H2014), "-"c)
        text = text.Replace("|", " ")
        text = Regex.Replace(text, "\s+", " ").Trim()
        text = Regex.Replace(text, "^[\-,:;\s]+|[\-,:;\s]+$", "").Trim()
        Return text
    End Function

    Protected Function MenuSectorMediaClass(ByVal imgUrl As Object) As String
        Dim resolved As String = ResolveSectorImageUrl(imgUrl)
        If String.IsNullOrWhiteSpace(resolved) Then
            Return "ks-menu-media is-empty"
        End If
        Return "ks-menu-media has-image"
    End Function

    Protected Function RenderSectorMenuImage(ByVal imgUrl As Object, ByVal descrizione As Object) As String
        Dim resolved As String = ResolveSectorImageUrl(imgUrl)
        Dim fallbackText As String = MenuSectorFallbackText(descrizione)

        If String.IsNullOrWhiteSpace(resolved) Then
            Return "<span class='ks-menu-media-fallback' aria-hidden='true'>" & HttpUtility.HtmlEncode(fallbackText) & "</span>"
        End If

        Return "<img src='" & HttpUtility.HtmlAttributeEncode(resolved) &
               "' alt='" & HttpUtility.HtmlAttributeEncode(CleanMenuText(descrizione)) &
               "' loading='lazy' decoding='async' onload=""if((this.naturalWidth||0)<12||(this.naturalHeight||0)<12){this.style.display='none';this.parentNode.classList.add('is-empty');var fb=this.parentNode.querySelector('.ks-menu-media-fallback');if(fb){fb.style.display='inline-flex';}}else{this.parentNode.classList.remove('is-empty');}"" onerror=""this.style.display='none';this.parentNode.classList.add('is-empty');var fb=this.parentNode.querySelector('.ks-menu-media-fallback');if(fb){fb.style.display='inline-flex';}"" />" &
               "<span class='ks-menu-media-fallback' aria-hidden='true' style='display:none;'>" & HttpUtility.HtmlEncode(fallbackText) & "</span>"
    End Function


    Protected Function MenuSectorFallbackText(ByVal descrizione As Object) As String
        Dim clean As String = CleanMenuText(descrizione)
        If String.IsNullOrWhiteSpace(clean) Then
            Return "•"
        End If

        For Each ch As Char In clean
            If Char.IsLetterOrDigit(ch) Then
                Return Char.ToUpperInvariant(ch)
            End If
        Next

        Return "•"
    End Function

    Protected Function ResolveSectorPromoImage(ByVal imgUrl As Object) As String
        Return ResolveSectorImageUrl(imgUrl)
    End Function

    Private Function ResolveSectorImageUrl(ByVal value As Object) As String
        Dim raw As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(raw) Then
            Return String.Empty
        End If

        raw = raw.Replace("\", "/")
        If ContainsBlockedCreativeToken(raw) Then
            Return String.Empty
        End If

        If raw.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           raw.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
           raw.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then
            Return raw
        End If

        If raw.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
            Return ResolveUrl(raw)
        End If

        If raw.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then
            Return raw
        End If

        If Regex.IsMatch(raw, "(?i)(spacer|pixel|blank|placeholder|default|demo|sample|tracking|sprite)") Then
            Return String.Empty
        End If

        If raw.IndexOf("/"c) >= 0 Then
            Return "/" & raw.TrimStart("/"c)
        End If

        Return "/" & raw
    End Function

    Private Function ContainsBlockedCreativeToken(ByVal raw As String) As Boolean
        Dim value As String = Convert.ToString(raw).ToLowerInvariant()
        value = Regex.Replace(value, "[^a-z0-9]+", " ")
        For Each token As String In BlockedCreativeTokens
            If value.Contains(token) Then
                Return True
            End If
        Next
        Return False
    End Function

    Private Function SafeUrl(ByVal value As Object, Optional ByVal fallback As String = "articoli.aspx") As String
        Dim url As String = Convert.ToString(value).Trim()
        If String.IsNullOrWhiteSpace(url) Then
            url = fallback
        End If

        If String.IsNullOrWhiteSpace(url) Then
            url = "articoli.aspx"
        End If

        If url.StartsWith("javascript:", StringComparison.OrdinalIgnoreCase) Then
            url = fallback
        End If

        Return url
    End Function

    Protected Function SafeText(ByVal value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function
End Class
