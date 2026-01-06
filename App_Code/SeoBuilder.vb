Option Explicit On
Option Strict On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls
Imports MySql.Data.MySqlClient
Imports System.Data

' =============================================================================
' SeoBuilder.vb
' -----------------------------------------------------------------------------
' Centralized SEO helpers for ASP.NET Web Forms (VB.NET):
' - Canonical + Meta tags
' - JSON-LD injection in <head> (single @graph)
' - JSON string escaping (NO C#-style \" in VB literals)
'
' NOTE:
' - This file is intentionally self-contained and VB 2012 compatible.
' - Any code inside App_Code must compile even if not used: keep it strict & safe.
' =============================================================================
Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    Private Const Q As Char = ChrW(34)   ' "
    Private Const BS As Char = ChrW(92)  ' \

    ' ------------------------------------------------------------
    ' DTOs (nested to avoid name collisions in legacy projects)
    ' ------------------------------------------------------------
    Public Class CompanyInfo
        Public Property Name As String
        Public Property StreetAddress As String
        Public Property PostalCode As String
        Public Property City As String
        Public Property Region As String
        Public Property CountryCode As String
        Public Property Telephone As String
        Public Property Email As String
    End Class

    Public Class CategoryInfo
        Public Property Id As Integer
        Public Property Name As String
        Public Property Url As String
    End Class

    Public Class BreadcrumbItem
        Public Sub New()
        End Sub

        Public Sub New(ByVal position As Integer, ByVal name As String, ByVal url As String)
            Me.Position = position
            Me.Name = name
            Me.Url = url
        End Sub

        Public Property Position As Integer
        Public Property Name As String
        Public Property Url As String
    End Class

    ' ------------------------------------------------------------
    ' JSON escaping (string content only, WITHOUT surrounding quotes)
    ' ------------------------------------------------------------
    Public Shared Function JsonEscape(ByVal s As String) As String
        If s Is Nothing Then Return ""

        Dim sb As New StringBuilder(Math.Max(16, s.Length + 16))

        For i As Integer = 0 To s.Length - 1
            Dim ch As Char = s(i)

            Select Case ch
                Case """"c
                    ' \"  (backslash + quote)
                    sb.Append(BS).Append(Q)

                Case BS
                    ' \\  (backslash + backslash)
                    sb.Append(BS).Append(BS)

                Case ControlChars.Back
                    sb.Append(BS).Append("b"c)

                Case ControlChars.FormFeed
                    sb.Append(BS).Append("f"c)

                Case ControlChars.NewLine
                    sb.Append(BS).Append("n"c)

                Case ControlChars.Cr
                    sb.Append(BS).Append("r"c)

                Case ControlChars.Tab
                    sb.Append(BS).Append("t"c)

                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 Then
                        ' \u00XX
                        sb.Append(BS).Append("u"c)
                        sb.Append(code.ToString("x4", CultureInfo.InvariantCulture))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function

    ' ------------------------------------------------------------
    ' <head> helpers
    ' ------------------------------------------------------------
    Public Shared Sub AddOrReplaceCanonical(ByVal page As Page, ByVal href As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim toRemove As New List(Of Control)()

        For Each c As Control In page.Header.Controls
            Dim lnk As HtmlLink = TryCast(c, HtmlLink)
            If lnk IsNot Nothing Then
                Dim rel As String = Convert.ToString(lnk.Attributes("rel"))
                If Not String.IsNullOrEmpty(rel) AndAlso String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    toRemove.Add(c)
                End If
            End If
        Next

        For Each c As Control In toRemove
            page.Header.Controls.Remove(c)
        Next

        Dim hl As New HtmlLink()
        hl.Attributes("rel") = "canonical"
        hl.Href = href
        page.Header.Controls.Add(hl)
    End Sub

    Public Shared Sub AddOrReplaceMeta(ByVal page As Page, ByVal name As String, ByVal content As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        If String.IsNullOrEmpty(name) Then Exit Sub

        Dim toRemove As New List(Of Control)()

        For Each c As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(c, HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                toRemove.Add(c)
            End If
        Next

        For Each c As Control In toRemove
            page.Header.Controls.Remove(c)
        Next

        Dim meta As New HtmlMeta()
        meta.Name = name
        meta.Content = If(content, "")
        page.Header.Controls.Add(meta)
    End Sub

    Public Shared Sub AddOrReplaceJsonLd(ByVal page As Page, ByVal controlId As String, ByVal json As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        If String.IsNullOrEmpty(controlId) Then controlId = "ldjson"

        Dim lit As Literal = TryCast(page.Header.FindControl(controlId), Literal)
        If lit Is Nothing Then
            Dim existing As Control = page.Header.FindControl(controlId)
            If existing IsNot Nothing Then page.Header.Controls.Remove(existing)

            lit = New Literal()
            lit.ID = controlId
            lit.Mode = LiteralMode.PassThrough
            page.Header.Controls.Add(lit)
        End If

        Dim payload As String = If(json, "").Trim()
        If payload.Length = 0 Then
            lit.Text = ""
            Exit Sub
        End If

        ' Hardening: avoid accidental </script> termination.
        payload = payload.Replace("</", "<\/")

        lit.Text = "<script type=""application/ld+json"">" & payload & "</script>"
    End Sub

    ' ------------------------------------------------------------
    ' DB helpers (optional): load company data from Aziende table
    ' ------------------------------------------------------------
    Public Shared Function LoadCompanyFromDb(ByVal aziendaId As Integer) As CompanyInfo
        Dim info As New CompanyInfo()

        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Using cn As New MySqlConnection(cs)
                cn.Open()

                Dim sql As String =
                    "SELECT RagioneSociale, Indirizzo, Cap, Citta, Provincia, FE_IdPaese, Telefono, Email " &
                    "FROM aziende WHERE id=@id LIMIT 1"

                Using cmd As New MySqlCommand(sql, cn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.AddWithValue("@id", aziendaId)

                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        If r.Read() Then
                            info.Name = SafeDbString(r("RagioneSociale"))
                            info.StreetAddress = SafeDbString(r("Indirizzo"))
                            info.PostalCode = SafeDbString(r("Cap"))
                            info.City = SafeDbString(r("Citta"))
                            info.Region = SafeDbString(r("Provincia"))
                            info.CountryCode = SafeDbString(r("FE_IdPaese"))
                            info.Telephone = SafeDbString(r("Telefono"))
                            info.Email = SafeDbString(r("Email"))
                        End If
                    End Using
                End Using
            End Using

        Catch
            ' Never block page rendering on SEO data load.
        End Try

        Return info
    End Function

    Private Shared Function SafeDbString(ByVal o As Object) As String
        If o Is Nothing OrElse Convert.IsDBNull(o) Then Return ""
        Return Convert.ToString(o).Trim()
    End Function

    ' ------------------------------------------------------------
    ' JSON-LD graph builder (Home-centric, but reusable)
    ' ------------------------------------------------------------
    Public Shared Function BuildHomeGraphJson(ByVal baseUrl As String,
                                              ByVal siteName As String,
                                              ByVal searchUrlTemplate As String,
                                              ByVal company As CompanyInfo,
                                              ByVal categories As IList(Of CategoryInfo),
                                              ByVal pageUrl As String,
                                              ByVal pageTitle As String,
                                              ByVal pageDescription As String,
                                              ByVal logoUrl As String) As String

        If String.IsNullOrEmpty(baseUrl) Then baseUrl = ""
        If String.IsNullOrEmpty(siteName) Then siteName = "Taikun"
        If String.IsNullOrEmpty(pageUrl) Then pageUrl = baseUrl
        If String.IsNullOrEmpty(pageTitle) Then pageTitle = siteName
        If String.IsNullOrEmpty(pageDescription) Then pageDescription = siteName

        Dim siteId As String = NormalizeUrl(baseUrl) & "#website"
        Dim orgId As String = NormalizeUrl(baseUrl) & "#org"
        Dim logoId As String = NormalizeUrl(baseUrl) & "#logo"

        Dim nodes As New List(Of String)()

        If Not String.IsNullOrEmpty(logoUrl) Then
            nodes.Add(BuildImageObjectNode(logoId, logoUrl, siteName & " logo"))
        End If

        nodes.Add(BuildOrganizationNode(orgId, siteName, baseUrl, logoId, company))
        nodes.Add(BuildWebSiteNode(siteId, siteName, baseUrl, orgId, searchUrlTemplate))
        nodes.Add(BuildWebPageNode(NormalizeUrl(pageUrl) & "#webpage", pageTitle, pageUrl, siteId, pageDescription))

        ' Breadcrumb: Home only (can be expanded on other pages)
        Dim bc As New List(Of BreadcrumbItem)()
        bc.Add(New BreadcrumbItem(1, "Home", pageUrl))
        nodes.Add(BuildBreadcrumbListNode(NormalizeUrl(pageUrl) & "#breadcrumbs", bc))

        ' Categories ItemList (optional)
        If categories IsNot Nothing AndAlso categories.Count > 0 Then
            nodes.Add(BuildCategoryItemListNode(NormalizeUrl(pageUrl) & "#categories", "Categorie", categories))
        End If

        Return WrapGraph(nodes)
    End Function

    ' -------------------------
    ' Node builders
    ' -------------------------
    Private Shared Function BuildOrganizationNode(ByVal orgId As String,
                                                  ByVal siteName As String,
                                                  ByVal baseUrl As String,
                                                  ByVal logoId As String,
                                                  ByVal company As CompanyInfo) As String

        Dim sb As New StringBuilder(512)
        sb.Append("{")

        Dim first As Boolean = True
        AppendJsonStringProp(sb, first, "@type", "Organization")
        AppendJsonStringProp(sb, first, "@id", orgId)
        AppendJsonStringProp(sb, first, "name", siteName)
        AppendJsonStringProp(sb, first, "url", baseUrl)

        If Not String.IsNullOrEmpty(logoId) Then
            AppendJsonRawProp(sb, first, "logo", BuildIdRefObject(logoId))
        End If

        If company IsNot Nothing Then
            AppendJsonStringProp(sb, first, "email", company.Email)
            AppendJsonStringProp(sb, first, "telephone", company.Telephone)
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildImageObjectNode(ByVal id As String, ByVal url As String, ByVal caption As String) As String
        Dim sb As New StringBuilder(256)
        sb.Append("{")
        Dim first As Boolean = True
        AppendJsonStringProp(sb, first, "@type", "ImageObject")
        AppendJsonStringProp(sb, first, "@id", id)
        AppendJsonStringProp(sb, first, "url", url)
        AppendJsonStringProp(sb, first, "caption", caption)
        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildWebSiteNode(ByVal siteId As String,
                                             ByVal siteName As String,
                                             ByVal baseUrl As String,
                                             ByVal orgId As String,
                                             ByVal searchUrlTemplate As String) As String
        Dim sb As New StringBuilder(512)
        sb.Append("{")
        Dim first As Boolean = True

        AppendJsonStringProp(sb, first, "@type", "WebSite")
        AppendJsonStringProp(sb, first, "@id", siteId)
        AppendJsonStringProp(sb, first, "name", siteName)
        AppendJsonStringProp(sb, first, "url", baseUrl)
        AppendJsonRawProp(sb, first, "publisher", BuildIdRefObject(orgId))

        If Not String.IsNullOrEmpty(searchUrlTemplate) Then
            Dim pa As New StringBuilder(256)
            pa.Append("{")
            Dim firstPa As Boolean = True
            AppendJsonStringProp(pa, firstPa, "@type", "SearchAction")
            AppendJsonStringProp(pa, firstPa, "target", searchUrlTemplate)
            AppendJsonStringProp(pa, firstPa, "query-input", "required name=search_term_string")
            pa.Append("}")

            AppendJsonRawProp(sb, first, "potentialAction", pa.ToString())
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildWebPageNode(ByVal pageId As String,
                                             ByVal pageName As String,
                                             ByVal pageUrl As String,
                                             ByVal websiteId As String,
                                             ByVal pageDescription As String) As String
        Dim sb As New StringBuilder(512)
        sb.Append("{")
        Dim first As Boolean = True

        AppendJsonStringProp(sb, first, "@type", "WebPage")
        AppendJsonStringProp(sb, first, "@id", pageId)
        AppendJsonStringProp(sb, first, "name", pageName)
        AppendJsonStringProp(sb, first, "url", pageUrl)
        AppendJsonStringProp(sb, first, "description", pageDescription)
        AppendJsonRawProp(sb, first, "isPartOf", BuildIdRefObject(websiteId))

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildBreadcrumbListNode(ByVal id As String, ByVal items As IList(Of BreadcrumbItem)) As String
        Dim sb As New StringBuilder(1024)
        sb.Append("{")
        Dim first As Boolean = True

        AppendJsonStringProp(sb, first, "@type", "BreadcrumbList")
        AppendJsonStringProp(sb, first, "@id", id)

        If items IsNot Nothing AndAlso items.Count > 0 Then
            Dim arr As New StringBuilder(512)
            arr.Append("[")

            For i As Integer = 0 To items.Count - 1
                If i > 0 Then arr.Append(",")

                Dim it As BreadcrumbItem = items(i)
                arr.Append("{")

                Dim firstIt As Boolean = True
                AppendJsonStringProp(arr, firstIt, "@type", "ListItem")
                AppendJsonNumberProp(arr, firstIt, "position", it.Position)
                AppendJsonStringProp(arr, firstIt, "name", it.Name)
                AppendJsonStringProp(arr, firstIt, "item", it.Url)

                arr.Append("}")
            Next

            arr.Append("]")

            AppendJsonRawProp(sb, first, "itemListElement", arr.ToString())
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildCategoryItemListNode(ByVal id As String, ByVal name As String, ByVal categories As IList(Of CategoryInfo)) As String
        Dim sb As New StringBuilder(2048)
        sb.Append("{")
        Dim first As Boolean = True

        AppendJsonStringProp(sb, first, "@type", "ItemList")
        AppendJsonStringProp(sb, first, "@id", id)
        AppendJsonStringProp(sb, first, "name", name)

        Dim arr As New StringBuilder(1024)
        arr.Append("[")

        Dim pos As Integer = 1
        For Each c As CategoryInfo In categories
            If c Is Nothing Then Continue For
            If String.IsNullOrEmpty(c.Name) OrElse String.IsNullOrEmpty(c.Url) Then Continue For

            If pos > 1 Then arr.Append(",")

            arr.Append("{")
            Dim firstIt As Boolean = True
            AppendJsonStringProp(arr, firstIt, "@type", "ListItem")
            AppendJsonNumberProp(arr, firstIt, "position", pos)
            AppendJsonStringProp(arr, firstIt, "name", c.Name)
            AppendJsonStringProp(arr, firstIt, "item", c.Url)
            arr.Append("}")

            pos += 1
            If pos > 50 Then Exit For ' safeguard
        Next

        arr.Append("]")

        If pos > 1 Then
            AppendJsonRawProp(sb, first, "itemListElement", arr.ToString())
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    ' -------------------------
    ' JSON helpers
    ' -------------------------
    Private Shared Function WrapGraph(ByVal nodes As IList(Of String)) As String
        Dim sb As New StringBuilder(4096)
        sb.Append("{")
        sb.Append(Q).Append("@context").Append(Q).Append(":").Append(Q).Append("https://schema.org").Append(Q).Append(",")
        sb.Append(Q).Append("@graph").Append(Q).Append(":")

        sb.Append("[")
        If nodes IsNot Nothing Then
            For i As Integer = 0 To nodes.Count - 1
                If i > 0 Then sb.Append(",")
                sb.Append(nodes(i))
            Next
        End If
        sb.Append("]")

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function BuildIdRefObject(ByVal id As String) As String
        Dim sb As New StringBuilder(64)
        sb.Append("{").Append(Q).Append("@id").Append(Q).Append(":").Append(Q).Append(JsonEscape(id)).Append(Q).Append("}")
        Return sb.ToString()
    End Function

    Private Shared Sub AppendJsonStringProp(ByVal sb As StringBuilder, ByRef first As Boolean, ByVal propName As String, ByVal propValue As String)
        If String.IsNullOrEmpty(propName) Then Exit Sub
        If propValue Is Nothing Then propValue = ""

        If Not first Then sb.Append(",") Else first = False

        sb.Append(Q).Append(propName).Append(Q).Append(":").Append(Q).Append(JsonEscape(propValue)).Append(Q)
    End Sub

    Private Shared Sub AppendJsonNumberProp(ByVal sb As StringBuilder, ByRef first As Boolean, ByVal propName As String, ByVal propValue As Integer)
        If String.IsNullOrEmpty(propName) Then Exit Sub

        If Not first Then sb.Append(",") Else first = False

        sb.Append(Q).Append(propName).Append(Q).Append(":").Append(propValue.ToString(CultureInfo.InvariantCulture))
    End Sub

    Private Shared Sub AppendJsonRawProp(ByVal sb As StringBuilder, ByRef first As Boolean, ByVal propName As String, ByVal rawJson As String)
        If String.IsNullOrEmpty(propName) Then Exit Sub
        If String.IsNullOrEmpty(rawJson) Then Exit Sub

        If Not first Then sb.Append(",") Else first = False

        sb.Append(Q).Append(propName).Append(Q).Append(":").Append(rawJson)
    End Sub

    Private Shared Function NormalizeUrl(ByVal url As String) As String
        If url Is Nothing Then Return ""
        Dim u As String = url.Trim()
        If u.EndsWith("/") Then
            u = u.TrimEnd("/"c)
        End If
        Return u
    End Function

End Class
