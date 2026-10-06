Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web.Script.Serialization

Module CatalogTaxonomyResolverHarness
    Private tests As Integer
    Private failures As Integer
    Private Sub Check(name As String, condition As Boolean)
        tests += 1
        If condition Then Return
        failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub
    Private Function Tree(prefix As String) As IList(Of CatalogMenuSector)
        Dim s1 As New CatalogMenuSector With {.Id = 1, .Descrizione = prefix & " Settore"}
        Dim s2 As New CatalogMenuSector With {.Id = 2, .Descrizione = prefix & " Altro settore"}
        Dim c1 As New CatalogMenuCategory With {.Id = 10, .SettoriId = 1, .Descrizione = prefix & " Categoria"}
        Dim c2 As New CatalogMenuCategory With {.Id = 11, .SettoriId = 1, .Descrizione = prefix & " Altra categoria"}
        Dim c3 As New CatalogMenuCategory With {.Id = 20, .SettoriId = 2, .Descrizione = prefix & " Categoria distinta"}
        c1.Children.Add(New CatalogMenuNode With {.Id = 100, .ParentId = 10, .Descrizione = prefix & " Tipologia"})
        c1.Children.Add(New CatalogMenuNode With {.Id = 101, .ParentId = 10, .Descrizione = prefix & " Tipologia sorella"})
        c2.Children.Add(New CatalogMenuNode With {.Id = 110, .ParentId = 11, .Descrizione = prefix & " Altro leaf"})
        c3.Children.Add(New CatalogMenuNode With {.Id = 200, .ParentId = 20, .Descrizione = prefix & " Leaf distinto"})
        s1.Categories.Add(c1)
        s1.Categories.Add(c2)
        s2.Categories.Add(c3)
        Return New List(Of CatalogMenuSector) From {s1, s2}
    End Function
    Private Sub Expect(name As String, ctx As CatalogTaxonomyContext, s As Integer, c As Integer, t As Integer, normalize As Boolean)
        Check(name & " sector", ctx.SectorId = s)
        Check(name & " category", ctx.CategoryId = c)
        Check(name & " tipology", ctx.TipologyId = t)
        Check(name & " normalization", ctx.CanNormalizeParents = normalize)
    End Sub
    Sub Main()
        Dim source = Tree("Tessuti")
        Expect("empty", CatalogTaxonomyResolver.Resolve(source, 0, 0, ""), 0, 0, 0, False)
        Expect("sector", CatalogTaxonomyResolver.Resolve(source, 1, 0, ""), 1, 0, 0, False)
        Expect("category", CatalogTaxonomyResolver.Resolve(source, 0, 10, ""), 1, 10, 0, True)
        Expect("tipology", CatalogTaxonomyResolver.Resolve(source, 0, 0, "100"), 1, 10, 100, True)
        Expect("wrong sector", CatalogTaxonomyResolver.Resolve(source, 2, 10, ""), 1, 10, 0, True)
        Dim mismatch = CatalogTaxonomyResolver.Resolve(source, 2, 20, "100")
        Expect("wrong parents", mismatch, 1, 10, 100, True)
        Check("mismatch recorded", Not mismatch.IsCoherent)
        Dim badTip = CatalogTaxonomyResolver.Resolve(source, 1, 10, "999")
        Expect("invalid child independent parents", badTip, 1, 10, 0, False)
        Check("invalid child recorded", Not badTip.IsCoherent)
        Expect("invalid child alone", CatalogTaxonomyResolver.Resolve(source, 0, 0, "999"), 0, 0, 0, False)
        Expect("invalid category", CatalogTaxonomyResolver.Resolve(source, 0, 999, ""), 0, 0, 0, False)
        Dim multi = CatalogTaxonomyResolver.Resolve(source, 0, 0, "100|101")
        Expect("same category multi", multi, 1, 10, 0, False)
        Check("multi has no leaf", multi.IsMultiTipology AndAlso Not multi.IsSingleTipology AndAlso Not multi.HasTipology)
        Check("display only parents", multi.RequestedSectorId = 0 AndAlso multi.RequestedCategoryId = 0)
        Expect("same sector multi", CatalogTaxonomyResolver.Resolve(source, 0, 0, "100|110"), 1, 0, 0, False)
        Expect("cross sector multi", CatalogTaxonomyResolver.Resolve(source, 0, 0, "100|200"), 0, 0, 0, False)
        Expect("invalid member multi", CatalogTaxonomyResolver.Resolve(source, 0, 0, "100|999"), 0, 0, 0, False)
        Expect("invalid member explicit category", CatalogTaxonomyResolver.Resolve(source, 1, 10, "100|999"), 1, 10, 0, False)
        Expect("malformed member", CatalogTaxonomyResolver.Resolve(source, 0, 0, "100|bad"), 0, 0, 0, False)
        Expect("empty member", CatalogTaxonomyResolver.Resolve(source, 0, 0, "100|"), 0, 0, 0, False)
        Expect("invalid category not inferred from multi", CatalogTaxonomyResolver.Resolve(source, 0, 999, "100|101"), 0, 0, 0, False)
        Expect("absent tree", CatalogTaxonomyResolver.Resolve(Nothing, 1, 10, "100"), 0, 0, 0, False)
        Dim valid = CatalogTaxonomyResolver.Resolve(source, 1, 10, "100")
        Check("coherent chain", valid.IsCoherent AndAlso valid.IsSingleTipology)
        Check("most specific name", valid.MostSpecificName = "Tessuti Tipologia")
        Check("structural url", valid.MostSpecificUrl = "~/articoli.aspx?st=1&ct=10&tp=100")
        Check("base trail", CatalogTaxonomyResolver.Resolve(source, 0, 0, "").BreadcrumbItems().Count = 2)
        Check("sector trail", CatalogTaxonomyResolver.Resolve(source, 1, 0, "").BreadcrumbItems().Count = 2)
        Check("category trail", CatalogTaxonomyResolver.Resolve(source, 0, 10, "").BreadcrumbItems().Count = 3)
        Check("tipology trail", valid.BreadcrumbItems().Count = 4)
        Dim pdp = valid.BreadcrumbItems("Prodotto", "https://one.example/articolo.aspx?id=42")
        Check("PDP trail", pdp.Count = 5 AndAlso pdp(4).Name = "Prodotto")
        Dim absolute = StorefrontBreadcrumbItem.ToAbsolute(pdp, "https://one.example/")
        Check("same authority breadcrumb", StorefrontBreadcrumbItem.BuildListElements(absolute, "https://one.example/articolo.aspx?id=42") IsNot Nothing)
        Check("cross tenant rejected", StorefrontBreadcrumbItem.BuildListElements(absolute, "https://two.example/articolo.aspx?id=42") Is Nothing)
        Dim other = CatalogTaxonomyResolver.Resolve(Tree("Alimenti"), 0, 0, "100")
        Check("multimerch same IDs", other.MostSpecificName = "Alimenti Tipologia" AndAlso Not other.MostSpecificName.Contains("Tessuti"))
        Check("multimerch same URLs", other.MostSpecificUrl = valid.MostSpecificUrl)
        Check("plain name", New StorefrontBreadcrumbItem("<b>A &amp; B</b>", "~/").Name = "A & B")
        Console.WriteLine("CATALOG_TAXONOMY_TESTS=" & tests.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("CATALOG_TAXONOMY_FAILURES=" & failures.ToString(CultureInfo.InvariantCulture))
        If failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
