Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization

Public NotInheritable Class CatalogTaxonomyContext
    Public Property RequestedSectorId As Integer
    Public Property RequestedCategoryId As Integer
    Public Property SectorId As Integer
    Public Property SectorName As String
    Public Property SectorUrl As String
    Public Property CategoryId As Integer
    Public Property CategoryName As String
    Public Property CategoryUrl As String
    Public Property TipologyId As Integer
    Public Property TipologyName As String
    Public Property TipologyUrl As String
    Public Property IsSingleTipology As Boolean
    Public Property IsMultiTipology As Boolean
    ' Describes the requested chain, not whether the resolved parents are usable.
    Public Property IsCoherent As Boolean
    Public Property CanNormalizeParents As Boolean

    Public ReadOnly Property HasSector As Boolean
        Get
            Return SectorId > 0
        End Get
    End Property
    Public ReadOnly Property HasCategory As Boolean
        Get
            Return CategoryId > 0
        End Get
    End Property
    Public ReadOnly Property HasTipology As Boolean
        Get
            Return TipologyId > 0
        End Get
    End Property
    Public ReadOnly Property MostSpecificName As String
        Get
            If HasTipology Then Return TipologyName
            If HasCategory Then Return CategoryName
            If HasSector Then Return SectorName
            Return "Catalogo"
        End Get
    End Property
    Public ReadOnly Property MostSpecificUrl As String
        Get
            If HasTipology Then Return TipologyUrl
            If HasCategory Then Return CategoryUrl
            If HasSector Then Return SectorUrl
            Return "~/articoli.aspx"
        End Get
    End Property

    Public Function BreadcrumbItems(Optional productName As String = Nothing,
                                    Optional productUrl As String = Nothing) As IList(Of StorefrontBreadcrumbItem)
        Dim result As New List(Of StorefrontBreadcrumbItem) From {
            New StorefrontBreadcrumbItem("Home", "~/")
        }
        If HasSector Then result.Add(New StorefrontBreadcrumbItem(SectorName, SectorUrl))
        If HasCategory Then result.Add(New StorefrontBreadcrumbItem(CategoryName, CategoryUrl))
        If HasTipology Then result.Add(New StorefrontBreadcrumbItem(TipologyName, TipologyUrl))
        If result.Count = 1 Then result.Add(New StorefrontBreadcrumbItem("Catalogo", "~/articoli.aspx"))
        If Not String.IsNullOrWhiteSpace(productName) Then result.Add(New StorefrontBreadcrumbItem(productName, productUrl))
        Return result
    End Function
End Class

Public NotInheritable Class CatalogTaxonomyResolver
    Private Sub New()
    End Sub

    Public Shared Function Resolve(sectorId As Integer, categoryId As Integer,
                                   tipologyValues As String) As CatalogTaxonomyContext
        Return Resolve(CatalogMenuProvider.LoadCatalogMenuCached(), sectorId, categoryId, tipologyValues)
    End Function

    ' Pure overload: tree is supplied by the existing provider or a synthetic harness.
    ' No SQL, second cache, client names or classification inferred from descriptions.
    Public Shared Function Resolve(tree As IList(Of CatalogMenuSector), sectorId As Integer,
                                   categoryId As Integer, tipologyValues As String) As CatalogTaxonomyContext
        Dim result As New CatalogTaxonomyContext With {
            .RequestedSectorId = Math.Max(0, sectorId),
            .RequestedCategoryId = Math.Max(0, categoryId),
            .IsCoherent = True
        }
        Dim raw As String = If(tipologyValues, String.Empty).Trim()
        Dim parts As String() = If(raw.Length = 0, New String() {}, raw.Split("|"c))
        result.IsSingleTipology = (parts.Length = 1)
        result.IsMultiTipology = (parts.Length > 1)

        Dim explicitSector As CatalogMenuSector = FindSector(tree, sectorId)
        Dim categorySector As CatalogMenuSector = Nothing
        Dim explicitCategory As CatalogMenuCategory = FindCategory(tree, categoryId, categorySector)
        result.IsCoherent = (sectorId <= 0 OrElse explicitSector IsNot Nothing) AndAlso
                            (categoryId <= 0 OrElse explicitCategory IsNot Nothing)

        If result.IsSingleTipology Then
            Dim tipId As Integer = 0
            Dim tipSector As CatalogMenuSector = Nothing
            Dim tipCategory As CatalogMenuCategory = Nothing
            Dim tip As CatalogMenuNode = Nothing
            If TryReadId(parts(0), tipId) Then tip = FindTipology(tree, tipId, tipSector, tipCategory)
            If tip IsNot Nothing Then
                SetCategory(result, tipSector, tipCategory)
                result.TipologyId = tip.Id
                result.TipologyName = StorefrontBreadcrumbItem.NormalizeName(tip.Descrizione)
                result.TipologyUrl = result.CategoryUrl & "&tp=" & IdText(tip.Id)
                result.CanNormalizeParents = True
                result.IsCoherent = (sectorId <= 0 OrElse sectorId = tipSector.Id) AndAlso
                                    (categoryId <= 0 OrElse categoryId = tipCategory.Id)
                Return result
            End If
            ' Keep invalid children in the query. Only independent valid parents may display.
            result.IsCoherent = False
        End If

        If explicitCategory IsNot Nothing Then
            SetCategory(result, categorySector, explicitCategory)
            result.IsCoherent = result.IsCoherent AndAlso (sectorId <= 0 OrElse sectorId = categorySector.Id)
            result.CanNormalizeParents = (parts.Length = 0)
        ElseIf explicitSector IsNot Nothing Then
            SetSector(result, explicitSector)
        End If

        If result.IsMultiTipology Then
            Dim commonSector As CatalogMenuSector = Nothing
            Dim commonCategory As CatalogMenuCategory = Nothing
            Dim allValid As Boolean = True
            Dim sameSector As Boolean = True
            Dim sameCategory As Boolean = True
            For Each part As String In parts
                Dim tipId As Integer = 0
                Dim tipSector As CatalogMenuSector = Nothing
                Dim tipCategory As CatalogMenuCategory = Nothing
                Dim tip As CatalogMenuNode = Nothing
                If TryReadId(part, tipId) Then tip = FindTipology(tree, tipId, tipSector, tipCategory)
                If tip Is Nothing Then
                    allValid = False
                    Exit For
                End If
                If commonSector Is Nothing Then
                    commonSector = tipSector
                    commonCategory = tipCategory
                Else
                    sameSector = sameSector AndAlso (commonSector.Id = tipSector.Id)
                    sameCategory = sameCategory AndAlso (commonCategory.Id = tipCategory.Id)
                End If
                result.IsCoherent = result.IsCoherent AndAlso
                    (sectorId <= 0 OrElse sectorId = tipSector.Id) AndAlso
                    (categoryId <= 0 OrElse categoryId = tipCategory.Id)
            Next
            result.IsCoherent = result.IsCoherent AndAlso allValid
            ' Inferred parents are display-only: never normalize a multi-selection.
            If allValid AndAlso categoryId <= 0 Then
                If sameSector AndAlso (sectorId <= 0 OrElse sectorId = commonSector.Id) Then
                    If sameCategory Then
                        SetCategory(result, commonSector, commonCategory)
                    ElseIf Not result.HasSector Then
                        SetSector(result, commonSector)
                    End If
                End If
            End If
        End If
        Return result
    End Function

    Private Shared Function TryReadId(raw As String, ByRef value As Integer) As Boolean
        Return Integer.TryParse(raw.Trim(), NumberStyles.None, CultureInfo.InvariantCulture, value) AndAlso value > 0
    End Function
    Private Shared Function IdText(value As Integer) As String
        Return value.ToString(CultureInfo.InvariantCulture)
    End Function
    Private Shared Sub SetSector(result As CatalogTaxonomyContext, sector As CatalogMenuSector)
        result.SectorId = sector.Id
        result.SectorName = StorefrontBreadcrumbItem.NormalizeName(sector.Descrizione)
        result.SectorUrl = "~/articoli.aspx?st=" & IdText(sector.Id)
    End Sub
    Private Shared Sub SetCategory(result As CatalogTaxonomyContext, sector As CatalogMenuSector, category As CatalogMenuCategory)
        SetSector(result, sector)
        result.CategoryId = category.Id
        result.CategoryName = StorefrontBreadcrumbItem.NormalizeName(category.Descrizione)
        result.CategoryUrl = result.SectorUrl & "&ct=" & IdText(category.Id)
    End Sub
    Private Shared Function FindSector(tree As IList(Of CatalogMenuSector), id As Integer) As CatalogMenuSector
        If tree Is Nothing OrElse id <= 0 Then Return Nothing
        For Each sector As CatalogMenuSector In tree
            If sector IsNot Nothing AndAlso sector.Id = id Then Return sector
        Next
        Return Nothing
    End Function
    Private Shared Function FindCategory(tree As IList(Of CatalogMenuSector), id As Integer,
                                        ByRef parent As CatalogMenuSector) As CatalogMenuCategory
        parent = Nothing
        If tree Is Nothing OrElse id <= 0 Then Return Nothing
        For Each sector As CatalogMenuSector In tree
            If sector Is Nothing OrElse sector.Id <= 0 OrElse sector.Categories Is Nothing Then Continue For
            For Each category As CatalogMenuCategory In sector.Categories
                If category IsNot Nothing AndAlso category.Id = id AndAlso category.SettoriId = sector.Id Then
                    parent = sector
                    Return category
                End If
            Next
        Next
        Return Nothing
    End Function
    Private Shared Function FindTipology(tree As IList(Of CatalogMenuSector), id As Integer,
                                        ByRef sectorParent As CatalogMenuSector,
                                        ByRef categoryParent As CatalogMenuCategory) As CatalogMenuNode
        sectorParent = Nothing
        categoryParent = Nothing
        If tree Is Nothing OrElse id <= 0 Then Return Nothing
        For Each sector As CatalogMenuSector In tree
            If sector Is Nothing OrElse sector.Id <= 0 OrElse sector.Categories Is Nothing Then Continue For
            For Each category As CatalogMenuCategory In sector.Categories
                If category Is Nothing OrElse category.Id <= 0 OrElse category.SettoriId <> sector.Id OrElse category.Children Is Nothing Then Continue For
                For Each tip As CatalogMenuNode In category.Children
                    If tip IsNot Nothing AndAlso tip.Id = id AndAlso tip.ParentId = category.Id Then
                        sectorParent = sector
                        categoryParent = category
                        Return tip
                    End If
                Next
            Next
        Next
        Return Nothing
    End Function
End Class
