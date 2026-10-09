Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Reflection
Imports System.Web
Imports System.Web.UI.WebControls

Module HeaderCurrentScopeHarness
    Private tests As Integer
    Private failures As Integer

    Private Sub Check(ByVal name As String, ByVal condition As Boolean)
        tests += 1
        If condition Then Return
        failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Private Function Tree() As List(Of CatalogMenuSector)
        Dim a As New CatalogMenuSector With {.Id = 2, .Descrizione = "Sector A", .DefaultUrl = "articoli.aspx?st=2"}
        Dim ac As New CatalogMenuCategory With {.Id = 35, .SettoriId = 2, .Descrizione = "Category A", .DefaultUrl = "articoli.aspx?st=2&ct=35"}
        ac.Children.Add(New CatalogMenuNode With {.Id = 249, .ParentId = 35, .Descrizione = "Type A", .DefaultUrl = "articoli.aspx?st=2&ct=35&tp=249"})
        a.Categories.Add(ac)
        Dim b As New CatalogMenuSector With {.Id = 1, .Descrizione = "Sector B", .DefaultUrl = "articoli.aspx?st=1"}
        Dim bc As New CatalogMenuCategory With {.Id = 44, .SettoriId = 1, .Descrizione = "Category B", .DefaultUrl = "articoli.aspx?st=1&ct=44"}
        bc.Children.Add(New CatalogMenuNode With {.Id = 301, .ParentId = 44, .Descrizione = "Type B", .DefaultUrl = "articoli.aspx?st=1&ct=44&tp=301"})
        b.Categories.Add(bc)
        Return New List(Of CatalogMenuSector) From {a, b}
    End Function

    Private Sub Expect(ByVal name As String, ByVal query As String, ByVal expected As String)
        Dim fixture As New HeaderCurrentScopeFixture()
        fixture.Request = New HttpRequest("", "https://store.example/articoli.aspx", query)
        Dim before As String = fixture.Request.Url.AbsoluteUri
        Dim rawQuery As String = fixture.Request.QueryString.ToString()
        GetType(HeaderCurrentScopeFixture).GetMethod("BindSearchCategories", BindingFlags.NonPublic Or BindingFlags.Instance).
            Invoke(fixture, New Object() {Tree()})
        Dim desktop As DropDownList = fixture.product_cat
        Dim mobile As DropDownList = fixture.product_cat_mobile
        Check(name & " desktop", desktop.SelectedValue = expected)
        Check(name & " mobile", mobile.SelectedValue = expected)
        Check(name & " parity", desktop.SelectedIndex = mobile.SelectedIndex)
        Dim selectedDesktop As Integer = 0
        Dim selectedMobile As Integer = 0
        Dim optionValues As New List(Of String)()
        For index As Integer = 0 To desktop.Items.Count - 1
            If desktop.Items(index).Selected Then selectedDesktop += 1
            If mobile.Items(index).Selected Then selectedMobile += 1
            optionValues.Add(desktop.Items(index).Value)
            Check(name & " option " & index.ToString(CultureInfo.InvariantCulture),
                  desktop.Items(index).Value = mobile.Items(index).Value AndAlso desktop.Items(index).Text = mobile.Items(index).Text)
        Next
        Check(name & " exactly one selection", selectedDesktop = 1 AndAlso selectedMobile = 1)
        Check(name & " original search URLs", String.Join("|", optionValues) = "|articoli.aspx?st=2|articoli.aspx?st=2&ct=35|articoli.aspx?st=1|articoli.aspx?st=1&ct=44")
        Check(name & " request unchanged", fixture.Request.Url.AbsoluteUri = before AndAlso fixture.Request.QueryString.ToString() = rawQuery)
    End Sub

    Sub Main()
        Expect("sector", "st=2", "articoli.aspx?st=2")
        Expect("coherent category", "st=2&ct=35", "articoli.aspx?st=2&ct=35")
        Expect("category-only", "ct=35", "articoli.aspx?st=2&ct=35")
        Expect("discordant category parent", "st=1&ct=35", "articoli.aspx?st=2&ct=35")
        Expect("type implicit parents", "tp=249", "articoli.aspx?st=2&ct=35")
        Expect("type coherent parents", "st=2&ct=35&tp=249", "articoli.aspx?st=2&ct=35")
        Expect("type discordant parents", "st=1&ct=44&tp=249", "articoli.aspx?st=2&ct=35")
        Expect("other type authoritative parents", "st=2&ct=35&tp=301", "articoli.aspx?st=1&ct=44")
        Expect("unknown type", "st=2&ct=35&tp=999", "")
        Expect("unknown sector", "st=999", "")
        Expect("unknown category with valid sector", "st=2&ct=999", "")
        Expect("unknown parent with valid type", "st=999&tp=249", "")
        Expect("unknown category with valid type", "ct=999&tp=249", "")
        Expect("duplicate sector", "st=2&st=2", "")
        Expect("duplicate category", "ct=35&ct=44", "")
        Expect("duplicate type", "tp=249&tp=249", "")
        Expect("case-insensitive duplicate", "st=2&ST=2", "")
        Expect("non-numeric", "st=two&ct=35", "")
        Expect("comma value", "ct=35%2C44", "")
        Expect("multi type ambiguous", "tp=249%7C301", "")
        Expect("empty sector", "st=&ct=35", "")
        Expect("empty type", "st=2&tp=", "")
        Expect("negative", "ct=-35", "")
        Expect("zero", "st=0&ct=35", "")
        Expect("overflow", "st=2147483648", "")
        Expect("decimal", "ct=35.0", "")
        Expect("encoded plus", "st=%2B2", "")
        Expect("whitespace valid", "st=%202%20", "articoli.aspx?st=2")
        Expect("HOME neutral", "", "")
        Expect("search without taxonomy neutral", "q=products", "")
        Expect("PDP without taxonomy neutral", "id=42", "")
        Console.WriteLine("HEADER_CURRENT_SCOPE_SCENARIOS=31")
        Console.WriteLine("HEADER_CURRENT_SCOPE_TESTS=" & tests.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("HEADER_CURRENT_SCOPE_FAILURES=" & failures.ToString(CultureInfo.InvariantCulture))
        If failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
