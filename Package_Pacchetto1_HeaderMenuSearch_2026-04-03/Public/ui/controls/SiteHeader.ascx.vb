Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Imports MySql.Data.MySqlClient

Partial Class SiteHeader
    Inherits System.Web.UI.UserControl

    Private Const HeaderCompanyId As Integer = 1
    Private Const DefaultLogoVirtual As String = "~/Public/assets/images/logo/logo.webp"
    Private Const DefaultMobileLogoVirtual As String = "~/Public/assets/images/logo/logo-mobile.webp"
    Private Const DefaultFaviconVirtual As String = "~/Public/assets/images/favicons/favicon.ico"
    Private Const DefaultAppleTouchIconVirtual As String = "~/Public/assets/images/favicons/apple-touch-icon.png"
    Private Const DefaultFavicon32Virtual As String = "~/Public/assets/images/favicons/favicon-32x32.png"
    Private Const DefaultFavicon16Virtual As String = "~/Public/assets/images/favicons/favicon-16x16.png"
    Private Const DefaultPhoneText As String = "+39 000 000 0000"
    Private Const DefaultEmailText As String = "support@keepstore.it"

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        BindLogo()
        BindAccountLinks()
        RegisterHeadIconsScript()

        If Not IsPostBack Then
            BindHeaderData()
        End If
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As EventArgs) Handles Me.PreRender
        BindAccountLinks()
    End Sub

    Private Sub BindHeaderData()
        Dim catalogMenu As List(Of CatalogMenuSector) = CatalogMenuProvider.LoadCatalogMenu()

        BindSearchCategories(catalogMenu)
        BindDesktopCatalog(catalogMenu)
        BindMobileCatalog(catalogMenu)
        BindCompanyContacts()
        BindFreeShippingPromo()
    End Sub

    Private Sub BindSearchCategories(ByVal sectors As List(Of CatalogMenuSector))
        If product_cat Is Nothing OrElse product_cat_mobile Is Nothing Then
            Return
        End If

        Dim selectedSectorId As Integer = 0
        Integer.TryParse(Convert.ToString(Request.QueryString("st")), selectedSectorId)

        product_cat.Items.Clear()
        product_cat_mobile.Items.Clear()

        product_cat.Items.Add(New ListItem("Tutti i settori", String.Empty))
        product_cat_mobile.Items.Add(New ListItem("Tutti i settori", String.Empty))

        If selectedSectorId > 0 Then
            product_cat.ClearSelection()
            product_cat_mobile.ClearSelection()
        End If

        For Each sector As CatalogMenuSector In sectors
            Dim text As String = If(String.IsNullOrWhiteSpace(sector.Descrizione), "Settore " & sector.Id.ToString(), sector.Descrizione.Trim())
            Dim value As String = sector.DefaultUrl

            Dim desktopItem As New ListItem(text, value)
            Dim mobileItem As New ListItem(text, value)
            If selectedSectorId > 0 AndAlso sector.Id = selectedSectorId Then
                desktopItem.Selected = True
                mobileItem.Selected = True
            End If

            product_cat.Items.Add(desktopItem)
            product_cat_mobile.Items.Add(mobileItem)
        Next
    End Sub

    Private Sub BindMobileCatalog(ByVal sectors As List(Of CatalogMenuSector))
        If rptNavSettoriMobile Is Nothing Then
            Return
        End If

        rptNavSettoriMobile.DataSource = sectors
        rptNavSettoriMobile.DataBind()
    End Sub

    Private Sub BindDesktopCatalog(ByVal sectors As List(Of CatalogMenuSector))
        If litDesktopCatalogMegaMenu Is Nothing Then
            Return
        End If

        litDesktopCatalogMegaMenu.Text = BuildDesktopCatalogMegaMenuHtml(sectors)
    End Sub

    Protected Sub rptNavSettoriMobile_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e.Item Is Nothing OrElse (e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem) Then
            Return
        End If

        Dim sector As CatalogMenuSector = TryCast(e.Item.DataItem, CatalogMenuSector)
        Dim rpt As Repeater = TryCast(e.Item.FindControl("rptNavCategorieMobile"), Repeater)
        If sector Is Nothing OrElse rpt Is Nothing Then
            Return
        End If

        rpt.DataSource = sector.Categories
        rpt.DataBind()
    End Sub

    Protected Sub rptNavCategorieMobile_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e.Item Is Nothing OrElse (e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem) Then
            Return
        End If

        Dim category As CatalogMenuCategory = TryCast(e.Item.DataItem, CatalogMenuCategory)
        Dim rpt As Repeater = TryCast(e.Item.FindControl("rptNavTipologieMobile"), Repeater)
        If category Is Nothing OrElse rpt Is Nothing Then
            Return
        End If

        rpt.DataSource = category.Children
        rpt.DataBind()
    End Sub

    Protected Sub rptNavTipologieMobile_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e.Item Is Nothing OrElse (e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem) Then
            Return
        End If

        Dim tipologia As CatalogMenuNode = TryCast(e.Item.DataItem, CatalogMenuNode)
        Dim rpt As Repeater = TryCast(e.Item.FindControl("rptNavGruppiMobile"), Repeater)
        If tipologia Is Nothing OrElse rpt Is Nothing Then
            Return
        End If

        rpt.DataSource = tipologia.Children
        rpt.DataBind()
    End Sub

    Private Sub BindCompanyContacts()
        Dim phone As String = DefaultPhoneText
        Dim email As String = DefaultEmailText

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT telefono, email FROM aziende WHERE id=@companyId LIMIT 1", conn)
                    cmd.Parameters.AddWithValue("@companyId", HeaderCompanyId)
                    Using reader As MySqlDataReader = cmd.ExecuteReader()
                        If reader.Read() Then
                            Dim dbPhone As String = SafeString(reader, "telefono")
                            Dim dbEmail As String = SafeString(reader, "email")

                            If Not String.IsNullOrWhiteSpace(dbPhone) Then
                                phone = dbPhone.Trim()
                            End If
                            If Not String.IsNullOrWhiteSpace(dbEmail) Then
                                email = dbEmail.Trim()
                            End If
                        End If
                    End Using
                End Using
            End Using
        Catch
        End Try

        SetPhoneLink(hlSupportPhoneTop, litSupportPhoneTop, phone)
        SetPhoneLink(hlSupportPhoneHeader, litSupportPhoneHeader, phone)
        SetMailLink(hlSupportEmailHeader, litSupportEmailHeader, email)
    End Sub

    Private Sub BindFreeShippingPromo()
        If phFreeShippingTop Is Nothing OrElse litFreeShippingTop Is Nothing Then
            Return
        End If

        Dim minAmount As Decimal = 0D
        Dim hasPromo As Boolean = False

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT MIN(COALESCE(CostoMinimo,0)) AS CostoMinimo FROM vettori WHERE COALESCE(Promo,0)=1 AND COALESCE(AziendeID,0)=@companyId", conn)
                    cmd.Parameters.AddWithValue("@companyId", HeaderCompanyId)
                    Dim raw As Object = cmd.ExecuteScalar()
                    If raw IsNot Nothing AndAlso raw IsNot DBNull.Value Then
                        Decimal.TryParse(Convert.ToString(raw), NumberStyles.Any, CultureInfo.InvariantCulture, minAmount)
                        If minAmount = 0D Then
                            Decimal.TryParse(Convert.ToString(raw), NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), minAmount)
                        End If
                        hasPromo = (minAmount >= 0D)
                    End If
                End Using
            End Using
        Catch
            hasPromo = False
        End Try

        phFreeShippingTop.Visible = hasPromo
        If hasPromo Then
            litFreeShippingTop.Text = "Spedizione gratuita per ordini oltre <span class=""fw-semibold text-main"">" &
                                     HttpUtility.HtmlEncode(minAmount.ToString("C0", CultureInfo.GetCultureInfo("it-IT"))) &
                                     "</span>"
        End If
    End Sub

    Private Sub SetPhoneLink(ByVal link As HyperLink, ByVal literal As Literal, ByVal phone As String)
        If link Is Nothing OrElse literal Is Nothing Then
            Return
        End If

        Dim cleanPhone As String = If(phone, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(cleanPhone) Then
            cleanPhone = DefaultPhoneText
        End If

        Dim telTarget As String = cleanPhone.Replace(" ", String.Empty)
        link.NavigateUrl = "tel:" & telTarget
        literal.Text = HttpUtility.HtmlEncode(cleanPhone)
    End Sub

    Private Sub SetMailLink(ByVal link As HyperLink, ByVal literal As Literal, ByVal email As String)
        If link Is Nothing OrElse literal Is Nothing Then
            Return
        End If

        Dim cleanEmail As String = If(email, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(cleanEmail) Then
            cleanEmail = DefaultEmailText
        End If

        link.NavigateUrl = "mailto:" & cleanEmail
        literal.Text = HttpUtility.HtmlEncode(cleanEmail)
    End Sub

    Private Sub BindAccountLinks()
        Dim isLogged As Boolean = False
        Dim loginIdVal As Integer = 0

        If Session("LoginId") IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(Session("LoginId")), loginIdVal) AndAlso loginIdVal > 0 Then
            isLogged = True
        ElseIf Session("LoginID") IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(Session("LoginID")), loginIdVal) AndAlso loginIdVal > 0 Then
            isLogged = True
        End If

        Dim accountUrl As String = If(isLogged, ResolveUrl("~/myaccount.aspx"), ResolveUrl("~/login.aspx"))

        If lnkAccount IsNot Nothing Then
            lnkAccount.HRef = accountUrl
            lnkAccount.Attributes("href") = accountUrl
        End If

        If lnkAccountMobile IsNot Nothing Then
            lnkAccountMobile.HRef = accountUrl
            lnkAccountMobile.Attributes("href") = accountUrl
        End If

        If lnkAccountMobileButton IsNot Nothing Then
            lnkAccountMobileButton.HRef = accountUrl
            lnkAccountMobileButton.Attributes("href") = accountUrl
        End If
    End Sub

    Private Sub BindLogo()
        Dim desktopLogo As String = TryCast(Session("AziendaLogo"), String)
        If String.IsNullOrWhiteSpace(desktopLogo) Then
            desktopLogo = TryCast(Session("LogoWeb"), String)
        End If
        If String.IsNullOrWhiteSpace(desktopLogo) Then
            desktopLogo = DefaultLogoVirtual
        End If

        Dim mobileLogo As String = TryCast(Session("AziendaLogoMobile"), String)
        If String.IsNullOrWhiteSpace(mobileLogo) Then
            mobileLogo = TryCast(Session("LogoWebMobile"), String)
        End If
        If String.IsNullOrWhiteSpace(mobileLogo) Then
            If FileExistsVirtual(DefaultMobileLogoVirtual) Then
                mobileLogo = DefaultMobileLogoVirtual
            Else
                mobileLogo = desktopLogo
            End If
        End If

        desktopLogo = NormalizeLogoUrl(desktopLogo)
        mobileLogo = NormalizeLogoUrl(mobileLogo)

        If imgLogo IsNot Nothing Then imgLogo.ImageUrl = desktopLogo
        If imgLogoMobile IsNot Nothing Then imgLogoMobile.ImageUrl = mobileLogo
        If imgLogoDrawer IsNot Nothing Then imgLogoDrawer.ImageUrl = mobileLogo
    End Sub

    Private Function NormalizeLogoUrl(ByVal url As String) As String
        Dim u As String = If(url, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(u) Then
            Return ResolveUrl(DefaultLogoVirtual)
        End If

        u = u.Replace("\", "/")

        If u.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           u.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
           u.StartsWith("//", StringComparison.OrdinalIgnoreCase) Then
            Return u
        End If

        Dim lower As String = u.ToLowerInvariant()

        If lower.Contains("/public/assets/images/favicons/") Then
            Dim logoFile As String = Path.GetFileName(u)
            If Not String.IsNullOrWhiteSpace(logoFile) Then
                u = "/Public/assets/images/logo/" & logoFile
            End If
            lower = u.ToLowerInvariant()
        End If
        If lower.Contains("/public/assets/images/logo/") Then
            u = ReplaceInsensitive(u, "/Public/assets/images/logo/", "/Public/assets/images/logo/")
            lower = u.ToLowerInvariant()
        End If
        If lower.Contains("/public/images/") Then
            u = ReplaceInsensitive(u, "/Public/images/", "/Public/assets/images/logo/")
            lower = u.ToLowerInvariant()
        End If
        If lower.StartsWith("images/logo/", StringComparison.OrdinalIgnoreCase) OrElse
           lower.StartsWith("logo/", StringComparison.OrdinalIgnoreCase) OrElse
           lower.StartsWith("images/favicons/", StringComparison.OrdinalIgnoreCase) OrElse
           lower.StartsWith("favicons/", StringComparison.OrdinalIgnoreCase) Then
            Dim logoFile As String = Path.GetFileName(u)
            If Not String.IsNullOrWhiteSpace(logoFile) Then
                u = "/Public/assets/images/logo/" & logoFile
            End If
        End If
        If lower.Contains("/public/assets/images/") AndAlso Not lower.Contains("/public/assets/images/logo/") AndAlso Not lower.Contains("/public/assets/images/favicons/") Then
            Dim fileName As String = Path.GetFileName(u)
            If Not String.IsNullOrWhiteSpace(fileName) Then
                u = "/Public/assets/images/logo/" & fileName
            End If
        End If

        If Not u.Contains("/") AndAlso Not u.Contains("~") Then
            u = "/Public/assets/images/logo/" & u.TrimStart("/"c)
        End If

        If u.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
            Return ResolveUrl(u)
        End If

        If Not u.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then
            u = "/" & u.TrimStart("/"c)
        End If

        Return u
    End Function

    Private Sub RegisterHeadIconsScript()
        If Page Is Nothing Then Return

        Dim script As String = BuildHeadIconsScript()
        If String.IsNullOrWhiteSpace(script) Then Return

        Dim sm As ScriptManager = ScriptManager.GetCurrent(Page)
        If sm IsNot Nothing Then
            ScriptManager.RegisterStartupScript(Page, Page.GetType(), "ksHeadIcons", script, True)
        Else
            Page.ClientScript.RegisterStartupScript(Page.GetType(), "ksHeadIcons", script, True)
        End If
    End Sub

    Private Function BuildHeadIconsScript() As String
        Dim links As New List(Of String)()

        links.Add(BuildHeadLinkScript("icon", ResolveUrl(DefaultFaviconVirtual), "", "image/x-icon"))
        links.Add(BuildHeadLinkScript("shortcut icon", ResolveUrl(DefaultFaviconVirtual), "", "image/x-icon"))

        If FileExistsVirtual(DefaultAppleTouchIconVirtual) Then
            links.Add(BuildHeadLinkScript("apple-touch-icon", ResolveUrl(DefaultAppleTouchIconVirtual), "", "image/png"))
        End If
        If FileExistsVirtual(DefaultFavicon32Virtual) Then
            links.Add(BuildHeadLinkScript("icon", ResolveUrl(DefaultFavicon32Virtual), "32x32", "image/png"))
        End If
        If FileExistsVirtual(DefaultFavicon16Virtual) Then
            links.Add(BuildHeadLinkScript("icon", ResolveUrl(DefaultFavicon16Virtual), "16x16", "image/png"))
        End If

        Dim sb As New StringBuilder()
        Dim hasCommands As Boolean = False
        sb.AppendLine("(function(){")
        sb.AppendLine("function ksUpsertHeadLink(rel, href, sizes, type){")
        sb.AppendLine("if(!href){return;}")
        sb.AppendLine("var head=document.head||document.getElementsByTagName('head')[0];")
        sb.AppendLine("if(!head){return;}")
        sb.AppendLine("var links=head.getElementsByTagName('link');")
        sb.AppendLine("var match=null;")
        sb.AppendLine("var desiredSizes=sizes||'';")
        sb.AppendLine("for(var i=0;i<links.length;i++){")
        sb.AppendLine("var current=links[i];")
        sb.AppendLine("var currentRel=(current.getAttribute('rel')||'').toLowerCase();")
        sb.AppendLine("var currentSizes=current.getAttribute('sizes')||'';")
        sb.AppendLine("if(currentRel===String(rel||'').toLowerCase() && currentSizes===desiredSizes){match=current;break;}")
        sb.AppendLine("}")
        sb.AppendLine("if(!match){match=document.createElement('link');head.appendChild(match);}")
        sb.AppendLine("match.setAttribute('rel', rel);")
        sb.AppendLine("match.setAttribute('href', href);")
        sb.AppendLine("if(desiredSizes){match.setAttribute('sizes', desiredSizes);}else{match.removeAttribute('sizes');}")
        sb.AppendLine("if(type){match.setAttribute('type', type);}else{match.removeAttribute('type');}")
        sb.AppendLine("}")
        For Each cmd As String In links
            If Not String.IsNullOrWhiteSpace(cmd) Then
                sb.AppendLine(cmd)
                hasCommands = True
            End If
        Next
        If Not hasCommands Then Return String.Empty
        sb.AppendLine("})();")
        Return sb.ToString()
    End Function

    Private Function BuildHeadLinkScript(ByVal rel As String, ByVal href As String, ByVal sizes As String, ByVal mimeType As String) As String
        If String.IsNullOrWhiteSpace(href) Then Return String.Empty
        Return "ksUpsertHeadLink('" & Js(rel) & "','" & Js(href) & "','" & Js(sizes) & "','" & Js(mimeType) & "');"
    End Function

    Private Function Js(ByVal value As String) As String
        Return HttpUtility.JavaScriptStringEncode(If(value, String.Empty))
    End Function

    Private Function FileExistsVirtual(ByVal virtualPath As String) As Boolean
        Try
            Dim physical As String = Server.MapPath(virtualPath)
            Return File.Exists(physical)
        Catch
            Return False
        End Try
    End Function

    Private Function ReplaceInsensitive(ByVal input As String, ByVal search As String, ByVal replacement As String) As String
        Dim idx As Integer = input.IndexOf(search, StringComparison.OrdinalIgnoreCase)
        If idx < 0 Then Return input
        Return input.Substring(0, idx) & replacement & input.Substring(idx + search.Length)
    End Function

    Private Function BuildDesktopCatalogMegaMenuHtml(ByVal sectors As List(Of CatalogMenuSector)) As String
        If sectors Is Nothing OrElse sectors.Count = 0 Then
            Return "<div class='ks-header-catalog-empty'>Nessun settore disponibile.</div>"
        End If

        Dim sb As New StringBuilder()

        For Each sector As CatalogMenuSector In sectors
            If sector Is Nothing Then
                Continue For
            End If

            sb.Append("<div class='mega-menu-item ks-header-catalog-column' data-sector-id='")
            sb.Append(sector.Id.ToString())
            sb.Append("'>")
            sb.Append("<div class='menu-heading body-small ks-header-catalog-heading'>")
            sb.Append("<a href='")
            sb.Append(HttpUtility.HtmlAttributeEncode(sector.DefaultUrl))
            sb.Append("' class='ks-header-catalog-sector-link'>")
            sb.Append("<span class='ks-header-catalog-media")
            If String.IsNullOrWhiteSpace(sector.ImgUrl) Then
                sb.Append(" is-empty")
            End If
            sb.Append("'>")
            If Not String.IsNullOrWhiteSpace(sector.ImgUrl) Then
                sb.Append("<img src='")
                sb.Append(HttpUtility.HtmlAttributeEncode(sector.ImgUrl))
                sb.Append("' alt='")
                sb.Append(HttpUtility.HtmlAttributeEncode(If(sector.Descrizione, String.Empty)))
                sb.Append("' onerror=""this.style.display='none';this.parentNode.classList.add('is-empty');"" />")
            End If
            sb.Append("</span>")
            sb.Append("<span>")
            sb.Append(HttpUtility.HtmlEncode(If(sector.Descrizione, String.Empty)))
            sb.Append("</span>")
            sb.Append("</a>")
            sb.Append("</div>")

            sb.Append("<div class='ks-header-catalog-menu-list'>")
            If sector.Categories IsNot Nothing AndAlso sector.Categories.Count > 0 Then
                For Each category As CatalogMenuCategory In sector.Categories
                    If category Is Nothing Then
                        Continue For
                    End If

                    sb.Append("<div class='ks-header-catalog-category-block'>")
                    sb.Append("<a href='")
                    sb.Append(HttpUtility.HtmlAttributeEncode(category.DefaultUrl))
                    sb.Append("' class='menu-heading body-small link ks-header-catalog-category-link'><span>")
                    sb.Append(HttpUtility.HtmlEncode(If(category.Descrizione, String.Empty)))
                    sb.Append("</span></a>")

                    If category.Children IsNot Nothing AndAlso category.Children.Count > 0 Then
                        sb.Append("<ul class='ks-header-catalog-tipology-list'>")
                        For Each tipologia As CatalogMenuNode In category.Children
                            If tipologia Is Nothing Then
                                Continue For
                            End If

                            sb.Append("<li class='ks-header-catalog-tipology'>")
                            sb.Append("<a href='")
                            sb.Append(HttpUtility.HtmlAttributeEncode(tipologia.DefaultUrl))
                            sb.Append("' class='body-md-2 link ks-header-catalog-tipology-link'><span>")
                            sb.Append(HttpUtility.HtmlEncode(If(tipologia.Descrizione, String.Empty)))
                            sb.Append("</span></a>")
                            sb.Append("</li>")
                        Next
                        sb.Append("</ul>")
                    Else
                        sb.Append("<a href='")
                        sb.Append(HttpUtility.HtmlAttributeEncode(category.DefaultUrl))
                        sb.Append("' class='body-md-2 link ks-header-catalog-empty-link'><span>Vedi la categoria</span></a>")
                    End If

                    sb.Append("</div>")
                Next
            Else
                sb.Append("<a href='")
                sb.Append(HttpUtility.HtmlAttributeEncode(sector.DefaultUrl))
                sb.Append("' class='body-md-2 link ks-header-catalog-empty-link'><span>Vedi il settore</span></a>")
            End If
            sb.Append("</div>")
            sb.Append("</div>")
        Next

        Return sb.ToString()
    End Function

    Private Function SafeString(ByVal reader As IDataRecord, ByVal fieldName As String) As String
        Try
            Dim ordinal As Integer = reader.GetOrdinal(fieldName)
            If reader.IsDBNull(ordinal) Then Return String.Empty
            Return Convert.ToString(reader.GetValue(ordinal))
        Catch
            Return String.Empty
        End Try
    End Function
End Class
