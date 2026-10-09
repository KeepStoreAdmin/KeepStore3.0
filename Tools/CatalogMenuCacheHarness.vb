Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Concurrent
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Reflection
Imports System.Text.RegularExpressions
Imports System.Threading
Imports System.Threading.Tasks
Imports System.Web
Imports MySql.Data.MySqlClient

Module CatalogMenuCacheHarness
    Private tests As Integer
    Private failures As Integer
    Private ReadOnly Flags As BindingFlags = BindingFlags.NonPublic Or BindingFlags.Static

    Private Sub Check(ByVal name As String, ByVal condition As Boolean)
        tests += 1
        If condition Then Return
        failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Private Function Identity(ByVal value As String) As String
        Return CStr(GetType(CatalogMenuProvider).GetMethod("DatabaseCacheIdentity", Flags).Invoke(Nothing, New Object() {value}))
    End Function

    Private Function Connection(ByVal server As String, ByVal database As String, Optional ByVal port As UInteger = 3306UI,
                                Optional ByVal username As String = "fixture-user-a", Optional ByVal password As String = "fixture-only-a") As String
        Dim builder As New MySqlConnectionStringBuilder()
        builder.Server = server
        builder.Database = database
        builder.Port = port
        builder.UserID = username
        builder.Password = password
        Return builder.ConnectionString
    End Function

    Private Function Menu(ByVal scope As String, ByVal loader As Func(Of List(Of CatalogMenuSector)),
                          Optional ByVal seconds As Integer = 600) As List(Of CatalogMenuSector)
        Return DirectCast(GetType(CatalogMenuProvider).GetMethod("LoadMenuForScope", Flags).
                          Invoke(Nothing, New Object() {scope, seconds, loader}), List(Of CatalogMenuSector))
    End Function

    Private Function Column(ByVal scope As String, ByVal table As String, ByVal candidates As String(),
                            ByVal loader As Func(Of String)) As String
        Return CStr(GetType(CatalogMenuProvider).GetMethod("LoadColumnForScope", Flags).
                    Invoke(Nothing, New Object() {scope, table, candidates, loader}))
    End Function

    Private Function Tree(ByVal label As String) As List(Of CatalogMenuSector)
        Dim sector As New CatalogMenuSector With {.Id = 2, .Descrizione = label, .Img = "sector.png",
            .ImgUrl = "/Public/assets/images/settori/sector.png", .DefaultUrl = "articoli.aspx?st=2"}
        Dim category As New CatalogMenuCategory With {.Id = 35, .SettoriId = 2, .Descrizione = label & " category",
            .DefaultUrl = "articoli.aspx?st=2&ct=35"}
        category.Children.Add(New CatalogMenuNode With {.Id = 249, .ParentId = 35, .Descrizione = label & " type",
            .DefaultUrl = "articoli.aspx?st=2&ct=35&tp=249"})
        sector.Categories.Add(category)
        Return New List(Of CatalogMenuSector) From {sector}
    End Function

    Sub Main()
        Dim a As String = Identity(Connection("DB.EXAMPLE.", "Catalog_A"))
        Dim b As String = Identity(Connection("db.example", "catalog_b"))
        Check("normalized coordinates", a = Identity(Connection(" db.example ", " catalog_a ")))
        Check("database isolation", a <> b)
        Check("server isolation", a <> Identity(Connection("other.example", "catalog_a")))
        Check("port isolation", a <> Identity(Connection("db.example", "catalog_a", 3307UI)))
        Check("credentials excluded", a = Identity(Connection("db.example", "catalog_a", 3306UI, "fixture-user-b", "fixture-only-b")))
        Check("opaque identity", Regex.IsMatch(a, "\A[A-F0-9]{64}\z"))
        Check("identity has no connection parts", Not a.Contains("db.example") AndAlso Not a.Contains("catalog_a") AndAlso Not a.Contains("fixture"))
        Dim oldCulture As CultureInfo = Thread.CurrentThread.CurrentCulture
        Try
            Thread.CurrentThread.CurrentCulture = CultureInfo.GetCultureInfo("ar-SA")
            Check("culture independent", a = Identity(Connection("db.example", "catalog_a")))
        Finally
            Thread.CurrentThread.CurrentCulture = oldCulture
        End Try
        Check("missing coordinates bypass", Identity("") = String.Empty)
        Check("missing database bypass", Identity(Connection("db.example", "")) = String.Empty)
        Check("missing server bypass", Identity(Connection("", "catalog_a")) = String.Empty)
        Check("malformed configuration bypass", Identity("not-a-connection") = String.Empty)
        Check("zero port bypass", Identity(Connection("db.example", "catalog_a", 0UI)) = String.Empty)
        Check("default TTL unchanged", CInt(GetType(CatalogMenuProvider).GetMethod("LoadCatalogMenuCached").GetParameters()(0).DefaultValue) = 600)

        Dim callsA As Integer = 0
        Dim treeA As List(Of CatalogMenuSector) = Tree("Catalog A")
        Dim loadA As Func(Of List(Of CatalogMenuSector)) = Function()
                                                            Interlocked.Increment(callsA)
                                                            Return treeA
                                                        End Function
        Dim first As List(Of CatalogMenuSector) = Menu(a, loadA)
        Dim second As List(Of CatalogMenuSector) = Menu(a, loadA)
        Dim third As List(Of CatalogMenuSector) = Menu(a, loadA)
        Check("three HOME consumers one load", callsA = 1)
        Check("three HOME consumers same tree", Object.ReferenceEquals(first, second) AndAlso Object.ReferenceEquals(second, third))
        Dim treeB As List(Of CatalogMenuSector) = Tree("Catalog B")
        Check("A B taxonomy isolation", Menu(b, Function() treeB)(0).Descrizione = "Catalog B")
        Check("A B A remains isolated", Menu(a, loadA)(0).Descrizione = "Catalog A" AndAlso callsA = 1)
        Check("hierarchy unchanged", first(0).Id = 2 AndAlso first(0).Categories(0).SettoriId = 2 AndAlso first(0).Categories(0).Children(0).ParentId = 35)
        Check("sector route unchanged", first(0).DefaultUrl = "articoli.aspx?st=2")
        Check("category route unchanged", first(0).Categories(0).DefaultUrl = "articoli.aspx?st=2&ct=35")
        Check("type route unchanged", first(0).Categories(0).Children(0).DefaultUrl = "articoli.aspx?st=2&ct=35&tp=249")
        Check("images unchanged", first(0).ImgUrl = treeA(0).ImgUrl AndAlso CatalogMenuProvider.ResolveSectorImageUrl("sector.png") = treeA(0).ImgUrl)

        Try
            HttpContext.Current = New HttpContext(New HttpRequest("", "https://store-a.example/", ""), New HttpResponse(New StringWriter()))
            Dim storefrontA As List(Of CatalogMenuSector) = Menu(a, loadA)
            HttpContext.Current = New HttpContext(New HttpRequest("", "https://store-b.example/", ""), New HttpResponse(New StringWriter()))
            Dim storefrontB As List(Of CatalogMenuSector) = Menu(a, loadA)
            Check("same DB storefront sharing", Object.ReferenceEquals(storefrontA, storefrontB) AndAlso callsA = 1)
            Check("tree contains no storefront identity", storefrontB(0).Descrizione = "Catalog A" AndAlso storefrontB(0).DefaultUrl = "articoli.aspx?st=2")
        Finally
            HttpContext.Current = Nothing
        End Try

        Dim globalKey As String = "KeepStore:CatalogMenuProvider:Menu"
        HttpRuntime.Cache.Insert(globalKey, Tree("wrong global taxonomy"))
        Dim bypassCalls As Integer = 0
        Dim bypassLoader As Func(Of List(Of CatalogMenuSector)) = Function()
                                                                     bypassCalls += 1
                                                                     Return Tree("uncached taxonomy")
                                                                 End Function
        For index As Integer = 1 To 3
            Check("missing identity never uses global " & index.ToString(CultureInfo.InvariantCulture), Menu("", bypassLoader)(0).Descrizione = "uncached taxonomy")
        Next
        Check("missing identity is uncached", bypassCalls = 3)
        Check("global key untouched", DirectCast(HttpRuntime.Cache(globalKey), List(Of CatalogMenuSector))(0).Descrizione = "wrong global taxonomy")
        HttpRuntime.Cache.Remove(globalKey)

        Dim recoveryScope As String = Identity(Connection("db.example", "empty_then_recover"))
        Dim emptyCalls As Integer = 0
        Dim emptyLoader As Func(Of List(Of CatalogMenuSector)) = Function()
                                                                    emptyCalls += 1
                                                                    Return New List(Of CatalogMenuSector)()
                                                                End Function
        Menu(recoveryScope, emptyLoader)
        Menu(recoveryScope, emptyLoader)
        Check("empty or caught failure not cached", emptyCalls = 2)
        Check("recovery after empty", Object.ReferenceEquals(Menu(recoveryScope, Function() treeA), treeA))
        Check("recovered tree cached", Object.ReferenceEquals(Menu(recoveryScope, emptyLoader), treeA) AndAlso emptyCalls = 2)
        Dim nullScope As String = Identity(Connection("db.example", "null_then_recover"))
        Check("null not cached", Menu(nullScope, Function() Nothing) Is Nothing AndAlso Menu(nullScope, Function() treeB)(0).Descrizione = "Catalog B")
        Dim failedScope As String = Identity(Connection("db.example", "exception_then_recover"))
        Try
            Menu(failedScope, Function() ThrowFailure())
            Check("loader exception raised", False)
        Catch ex As TargetInvocationException
            Check("loader exception not cached", TypeOf ex.InnerException Is InvalidOperationException)
        End Try
        Check("exception retry recovers", Menu(failedScope, Function() treeA)(0).Descrizione = "Catalog A")

        Dim categoryCandidates As String() = {"SettoriId", "Id_settore"}
        Dim typeCandidates As String() = {"CategorieId", "Id_categoria"}
        Check("column A modern", Column(a, "categorie", categoryCandidates, Function() "SettoriId") = "SettoriId")
        Check("column B legacy isolated", Column(b, "categorie", categoryCandidates, Function() "Id_settore") = "Id_settore")
        Check("column A remains modern", Column(a, "categorie", categoryCandidates, Function() "Id_settore") = "SettoriId")
        Check("type A modern", Column(a, "tipologie", typeCandidates, Function() "CategorieId") = "CategorieId")
        Check("type B legacy", Column(b, "tipologie", typeCandidates, Function() "Id_categoria") = "Id_categoria")
        Check("candidate precedence is key scoped", Column(a, "categorie", New String() {"Id_settore", "SettoriId"}, Function() "Id_settore") = "Id_settore")
        Dim noColumnScope As String = Identity(Connection("db.example", "no_columns"))
        Check("no column fail-safe", Column(noColumnScope, "categorie", categoryCandidates, Function() String.Empty) = String.Empty)
        Check("unidentified column uncached one", Column("", "categorie", categoryCandidates, Function() "SettoriId") = "SettoriId")
        Check("unidentified column uncached two", Column("", "categorie", categoryCandidates, Function() "Id_settore") = "Id_settore")
        Dim columnErrors As Integer = 0
        Parallel.For(0, 2000, Sub(index As Integer)
                                  Dim currentScope As String = If(index Mod 2 = 0, a, b)
                                  Dim expected As String = If(index Mod 2 = 0, "SettoriId", "Id_settore")
                                  If Column(currentScope, "categorie", categoryCandidates, Function() expected) <> expected Then Interlocked.Increment(columnErrors)
                                  Dim concurrentScope As String = Identity(Connection("db.example", "concurrent_" & (index Mod 20).ToString(CultureInfo.InvariantCulture)))
                                  If Column(concurrentScope, "categorie", categoryCandidates, Function() expected) <> expected Then Interlocked.Increment(columnErrors)
                              End Sub)
        Check("concurrent ColumnCache 4000 reads and writes", columnErrors = 0)
        Dim columnCache As Object = GetType(CatalogMenuProvider).GetField("ColumnCache", Flags).GetValue(Nothing)
        Check("column cache concurrent collection", TypeOf columnCache Is ConcurrentDictionary(Of String, String))

        Dim coldScope As String = Identity(Connection("db.example", "concurrent_cold_menu"))
        Dim coldCalls As Integer = 0
        Dim coldErrors As Integer = 0
        Dim coldLoader As Func(Of List(Of CatalogMenuSector)) = Function()
                                                                  Interlocked.Increment(coldCalls)
                                                                  Thread.Sleep(20)
                                                                  Return treeA
                                                              End Function
        Parallel.For(0, 32, Sub(index As Integer)
                               If Not Object.ReferenceEquals(Menu(coldScope, coldLoader, 1), treeA) Then Interlocked.Increment(coldErrors)
                           End Sub)
        Check("concurrent cold menu one load", coldCalls = 1 AndAlso coldErrors = 0)
        Dim prefix As String = CStr(GetType(CatalogMenuProvider).GetField("MenuCachePrefix", Flags).GetRawConstantValue())
        Check("only opaque scope in menu key", Regex.IsMatch(prefix & a, "\AKeepStore:CatalogMenuProvider:Menu:v2:[A-F0-9]{64}\z"))
        Console.WriteLine("CATALOG_MENU_CACHE_TESTS=" & tests.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("CATALOG_MENU_CACHE_FAILURES=" & failures.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("HOME_SYNTHETIC_CONSUMERS=3;TAXONOMY_LOADS=" & callsA.ToString(CultureInfo.InvariantCulture))
        If failures > 0 Then Environment.ExitCode = 1
    End Sub

    Private Function ThrowFailure() As List(Of CatalogMenuSector)
        Throw New InvalidOperationException("synthetic failure")
    End Function
End Module
