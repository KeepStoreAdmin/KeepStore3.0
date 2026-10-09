Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Linq
Imports System.Reflection
Imports System.Text
Imports System.Text.RegularExpressions
Imports HtmlAgilityPack

Module HeaderMenuMarkupHarness
    Private checks As Integer

    Private Sub Check(ByVal name As String, ByVal condition As Boolean)
        If Not condition Then Throw New InvalidOperationException(name)
        checks += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Private Function HasClass(ByVal node As HtmlNode, ByVal name As String) As Boolean
        Return (" " & node.GetAttributeValue("class", "") & " ").Contains(" " & name & " ")
    End Function

    Private Function Nodes(ByVal root As HtmlNode, ByVal xpath As String) As List(Of HtmlNode)
        Dim result As HtmlNodeCollection = root.SelectNodes(xpath)
        Return If(result Is Nothing, New List(Of HtmlNode)(), result.ToList())
    End Function

    Private Function Document(ByVal html As String) As HtmlDocument
        Dim result As New HtmlDocument()
        result.LoadHtml(html)
        Return result
    End Function

    Private Function Text(ByVal value As String) As String
        Return Regex.Replace(HtmlEntity.DeEntitize(value), "\s+", " ").Trim()
    End Function

    ' Ignore only the explicitly removed, attribute-free span inside tipology anchors.
    ' Everything else (tag, attributes, hierarchy, text and order) remains in the signature.
    Private Function Signature(ByVal node As HtmlNode) As String
        If node.NodeType = HtmlNodeType.Text Then Return Text(node.InnerText)
        If node.NodeType = HtmlNodeType.Comment Then Return ""
        Dim children As String = String.Join("", node.ChildNodes.Select(Function(child) Signature(child)))
        If node.Name = "span" AndAlso node.Attributes.Count = 0 AndAlso node.ParentNode IsNot Nothing AndAlso node.ParentNode.Name = "a" AndAlso
           (HasClass(node.ParentNode, "ks-header-catalog-tipology-link") OrElse
            (node.ParentNode.ParentNode IsNot Nothing AndAlso HasClass(node.ParentNode.ParentNode, "ks-mobile-tipology-item"))) Then Return children
        Dim attributes As String = String.Join("|", node.Attributes.OrderBy(Function(a) a.Name, StringComparer.Ordinal).Select(Function(a) a.Name & "=" & a.Value))
        Return "<" & node.Name & " " & attributes & ">" & children & "</" & node.Name & ">"
    End Function

    Private Function Render(ByVal fixture As Object, ByVal sectors As List(Of CatalogMenuSector)) As String
        Dim method As MethodInfo = fixture.GetType().GetMethod("BuildDesktopCatalogMegaMenuHtml", BindingFlags.NonPublic Or BindingFlags.Instance)
        Return DirectCast(method.Invoke(fixture, New Object() {sectors}), String)
    End Function

    Private Sub Compare(ByVal before As String, ByVal after As String, ByVal name As String, ByVal expectReduction As Boolean)
        Dim oldDoc As HtmlDocument = Document(before)
        Dim newDoc As HtmlDocument = Document(after)
        Check(name & "_TREE_TEXT_ATTRIBUTES_ORDER", Signature(oldDoc.DocumentNode) = Signature(newDoc.DocumentNode))
        Dim oldLinks As List(Of HtmlNode) = Nodes(oldDoc.DocumentNode, "//a")
        Dim newLinks As List(Of HtmlNode) = Nodes(newDoc.DocumentNode, "//a")
        Check(name & "_LINK_COUNT", oldLinks.Count = newLinks.Count)
        Check(name & "_LINK_URL_TEXT_ORDER", oldLinks.Select(Function(n) n.GetAttributeValue("href", "") & "|" & Text(n.InnerText)).SequenceEqual(newLinks.Select(Function(n) n.GetAttributeValue("href", "") & "|" & Text(n.InnerText))))
        Check(name & "_NO_NEW_PARSE_ERRORS", newDoc.ParseErrors.Count() <= oldDoc.ParseErrors.Count())
        Dim oldElements As Integer = Nodes(oldDoc.DocumentNode, "//*").Count
        Dim newElements As Integer = Nodes(newDoc.DocumentNode, "//*").Count
        Dim oldBytes As Integer = Encoding.UTF8.GetByteCount(before)
        Dim newBytes As Integer = Encoding.UTF8.GetByteCount(after)
        Check(name & "_REDUCTION", If(expectReduction, newElements < oldElements AndAlso newBytes < oldBytes, newElements = oldElements AndAlso newBytes = oldBytes))
        Console.WriteLine(name & " BYTES=" & oldBytes.ToString(CultureInfo.InvariantCulture) & "->" & newBytes.ToString(CultureInfo.InvariantCulture) &
                          " ELEMENTS=" & oldElements.ToString(CultureInfo.InvariantCulture) & "->" & newElements.ToString(CultureInfo.InvariantCulture))
    End Sub

    Private Sub CheckRuntime(ByVal beforePath As String, ByVal afterPath As String, ByVal name As String)
        Dim before As String = File.ReadAllText(beforePath)
        Dim after As String = File.ReadAllText(afterPath)
        Compare(before, after, name, True)
        Dim oldDoc As HtmlDocument = Document(before)
        Dim newDoc As HtmlDocument = Document(after)
        Dim root As HtmlNode = newDoc.DocumentNode.SelectSingleNode("//*[@id='ks-mobile-catalog-root']")
        Check(name & "_MOBILE_ROOT_SINGLE", Nodes(newDoc.DocumentNode, "//*[@id='ks-mobile-catalog-root']").Count = 1)
        For Each cssClass As String In New String() {"ks-mobile-sector-item", "ks-mobile-category-item", "ks-mobile-tipology-item"}
            Dim xpath As String = "//*[contains(concat(' ',normalize-space(@class),' '),' " & cssClass & " ')]"
            Check(name & "_COUNT_" & cssClass, Nodes(oldDoc.DocumentNode, xpath).Count = Nodes(newDoc.DocumentNode, xpath).Count)
            Console.WriteLine(name & " " & cssClass & "=" & Nodes(newDoc.DocumentNode, xpath).Count.ToString(CultureInfo.InvariantCulture))
        Next
        Dim oldRoot As HtmlNode = oldDoc.DocumentNode.SelectSingleNode("//*[@id='ks-mobile-catalog-root']")
        Dim oldUrls As List(Of String) = Nodes(oldRoot, ".//a").Select(Function(n) n.GetAttributeValue("href", "")).ToList()
        Dim newUrls As List(Of String) = Nodes(root, ".//a").Select(Function(n) n.GetAttributeValue("href", "")).ToList()
        Check(name & "_UNIQUE_DESTINATIONS", oldUrls.Distinct(StringComparer.Ordinal).SequenceEqual(newUrls.Distinct(StringComparer.Ordinal)))
        Check(name & "_NO_DUPLICATE_MOBILE_DESTINATIONS", newUrls.Count = newUrls.Distinct(StringComparer.Ordinal).Count())
        Console.WriteLine(name & " MOBILE_DESTINATIONS=" & newUrls.Count.ToString(CultureInfo.InvariantCulture))
        Dim ids As List(Of String) = Nodes(newDoc.DocumentNode, "//*[@id]").Select(Function(n) n.Id).ToList()
        Check(name & "_UNIQUE_IDS", ids.Count = ids.Distinct(StringComparer.Ordinal).Count())
        For Each button As HtmlNode In Nodes(root, ".//button")
            Dim target As String = button.GetAttributeValue("aria-controls", "")
            Check(name & "_COLLAPSE_TARGET", target <> "" AndAlso button.GetAttributeValue("type", "") = "button" AndAlso
                  button.GetAttributeValue("data-bs-toggle", "") = "collapse" AndAlso
                  button.GetAttributeValue("data-bs-target", "") = "#" & target AndAlso
                  newDoc.DocumentNode.SelectSingleNode("//*[@id='" & target & "']") IsNot Nothing)
        Next
        Check(name & "_TIPOLOGY_SPANS_REMOVED", Nodes(root, ".//li[contains(@class,'ks-mobile-tipology-item')]/a/span").Count = 0 AndAlso
              Nodes(newDoc.DocumentNode, "//a[contains(@class,'ks-header-catalog-tipology-link')]/span").Count = 0)
        Check(name & "_SEARCH_SELECTION_UNCHANGED", Signature(oldDoc.DocumentNode.SelectSingleNode("//select[1]")) = Signature(newDoc.DocumentNode.SelectSingleNode("//select[1]")))
        Console.WriteLine(name & " MOBILE_BYTES=" & Encoding.UTF8.GetByteCount(oldRoot.OuterHtml).ToString(CultureInfo.InvariantCulture) & "->" & Encoding.UTF8.GetByteCount(root.OuterHtml).ToString(CultureInfo.InvariantCulture))
        Console.WriteLine(name & " WHITESPACE_TEXT_NODES=" & Nodes(oldRoot, ".//text()").Where(Function(n) String.IsNullOrWhiteSpace(n.InnerText)).Count().ToString(CultureInfo.InvariantCulture) & "->" & Nodes(root, ".//text()").Where(Function(n) String.IsNullOrWhiteSpace(n.InnerText)).Count().ToString(CultureInfo.InvariantCulture))
    End Sub

    Sub Main(ByVal args As String())
        Try
            For Each tenant As Integer In New Integer() {1, 2}
                Dim sector As New CatalogMenuSector With {.Id = tenant, .Descrizione = "Sector <&> " & tenant.ToString(), .DefaultUrl = "articoli.aspx?st=" & tenant.ToString()}
                Dim category As New CatalogMenuCategory With {.Id = tenant * 10, .SettoriId = tenant, .Descrizione = "Category & special", .DefaultUrl = sector.DefaultUrl & "&ct=" & (tenant * 10).ToString()}
                category.Children.Add(New CatalogMenuNode With {.Id = tenant * 100, .ParentId = category.Id, .Descrizione = "Type <script> & ""quoted""", .DefaultUrl = category.DefaultUrl & "&tp=" & (tenant * 100).ToString()})
                category.Children.Add(New CatalogMenuNode With {.Id = tenant * 100 + 1, .ParentId = category.Id, .Descrizione = "Type  two", .DefaultUrl = category.DefaultUrl & "&tp=" & (tenant * 100 + 1).ToString()})
                sector.Categories.Add(category)
                Dim tree As New List(Of CatalogMenuSector) From {sector}
                Dim output As String = Render(New HeaderMenuMarkupFixture(), tree)
                Compare(Render(New HeaderMenuMarkupBaseline(), tree), output, "SYNTHETIC_" & tenant.ToString(), True)
                Check("SYNTHETIC_ENCODING_" & tenant.ToString(), Not output.Contains("<script>") AndAlso output.Contains("&lt;script&gt;"))
                category.Children.Clear()
                Compare(Render(New HeaderMenuMarkupBaseline(), tree), Render(New HeaderMenuMarkupFixture(), tree), "EMPTY_CATEGORY_" & tenant.ToString(), False)
                sector.Categories.Clear()
                Compare(Render(New HeaderMenuMarkupBaseline(), tree), Render(New HeaderMenuMarkupFixture(), tree), "EMPTY_SECTOR_" & tenant.ToString(), False)
            Next
            Check("NULL_TREE_FAIL_SAFE_UNCHANGED", Render(New HeaderMenuMarkupFixture(), Nothing) = Render(New HeaderMenuMarkupBaseline(), Nothing))
            ' Negative controls prove URL, hierarchy, labels and ARIA changes are not ignored.
            Dim sample As String = "<div id='sector'><a href='articoli.aspx?st=1' class='ks-header-catalog-tipology-link'><span>Type</span></a><button aria-controls='sector'>Open</button></div>"
            Dim compact As String = sample.Replace("<span>Type</span>", "Type")
            Check("NEGATIVE_URL", Signature(Document(sample).DocumentNode) <> Signature(Document(compact.Replace("st=1", "st=2")).DocumentNode))
            Check("NEGATIVE_TEXT", Signature(Document(sample).DocumentNode) <> Signature(Document(compact.Replace("Type", "Different")).DocumentNode))
            Check("NEGATIVE_ARIA", Signature(Document(sample).DocumentNode) <> Signature(Document(compact.Replace("aria-controls='sector'", "aria-controls='wrong'")).DocumentNode))
            Check("NEGATIVE_HIERARCHY", Signature(Document(sample).DocumentNode) <> Signature(Document(compact.Replace("<div id='sector'>", "<section id='sector'>").Replace("</div>", "</section>")).DocumentNode))
            If args.Length = 2 Then
                For Each route As String In New String() {"home", "catalog", "pdp"}
                    CheckRuntime(Path.Combine(args(0), route & ".html"), Path.Combine(args(1), route & ".html"), route.ToUpperInvariant())
                Next
            ElseIf args.Length <> 0 Then
                Throw New InvalidOperationException("EXPECTED_TWO_CAPTURE_DIRECTORIES")
            End If
            Console.WriteLine("HEADER_MENU_MARKUP_CHECKS=" & checks.ToString(CultureInfo.InvariantCulture) & ";RESULT=PASS;NO_BROWSER_COVERAGE")
        Catch ex As Exception
            Console.Error.WriteLine("HEADER_MENU_MARKUP_RESULT=FAIL;" & ex.Message)
            Environment.ExitCode = 1
        End Try
    End Sub
End Module
