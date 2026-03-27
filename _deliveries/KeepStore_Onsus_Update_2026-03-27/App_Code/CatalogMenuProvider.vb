Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.IO
Imports MySql.Data.MySqlClient

Public Class CatalogMenuSector
    Public Property Id As Integer
    Public Property Descrizione As String
    Public Property Img As String
    Public Property ImgUrl As String
    Public Property DefaultUrl As String
    Public Property Categories As List(Of CatalogMenuCategory)

    Public Sub New()
        Categories = New List(Of CatalogMenuCategory)()
    End Sub
End Class

Public Class CatalogMenuCategory
    Public Property Id As Integer
    Public Property SettoriId As Integer
    Public Property Descrizione As String
    Public Property DefaultUrl As String
    Public Property Children As List(Of CatalogMenuNode)

    Public Sub New()
        Children = New List(Of CatalogMenuNode)()
    End Sub
End Class

Public Class CatalogMenuNode
    Public Property Id As Integer
    Public Property ParentId As Integer
    Public Property Descrizione As String
    Public Property DefaultUrl As String
End Class

Public Module CatalogMenuProvider

    Private ReadOnly ColumnCache As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)

    Public Function LoadCatalogMenu() As List(Of CatalogMenuSector)
        Dim sectors As New List(Of CatalogMenuSector)()

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()

                Dim categorySectorColumn As String = ResolveColumnName(conn, "categorie", "SettoriId", "Id_settore")
                Dim tipologiaCategoryColumn As String = ResolveColumnName(conn, "tipologie", "CategorieId", "Id_categoria")

                Dim sectorsMap As New Dictionary(Of Integer, CatalogMenuSector)()
                Using cmd As New MySqlCommand("SELECT id, Descrizione, Img FROM settori WHERE COALESCE(Abilitato,0)=1 ORDER BY COALESCE(Predefinito,0) DESC, COALESCE(Ordinamento,0) ASC, Descrizione ASC", conn)
                    Using reader As MySqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            Dim sector As New CatalogMenuSector()
                            sector.Id = SafeInt(reader, "id")
                            sector.Descrizione = SafeString(reader, "Descrizione")
                            sector.Img = SafeString(reader, "Img")
                            sector.ImgUrl = ResolveSectorImageUrl(sector.Img)
                            sector.DefaultUrl = "articoli.aspx?st=" & sector.Id.ToString()

                            sectors.Add(sector)
                            sectorsMap(sector.Id) = sector
                        End While
                    End Using
                End Using

                If sectors.Count = 0 Then
                    Return sectors
                End If

                If Not String.IsNullOrWhiteSpace(categorySectorColumn) Then
                    Dim categoriesSql As String =
                        "SELECT id, " & categorySectorColumn & " AS SettoriId, Descrizione " &
                        "FROM categorie " &
                        "WHERE COALESCE(Abilitato,0)=1 " &
                        "ORDER BY COALESCE(Ordinamento,0) ASC, Descrizione ASC"

                    Dim categoriesMap As New Dictionary(Of Integer, CatalogMenuCategory)()
                    Using cmd As New MySqlCommand(categoriesSql, conn)
                        Using reader As MySqlDataReader = cmd.ExecuteReader()
                            While reader.Read()
                                Dim sectorId As Integer = SafeInt(reader, "SettoriId")
                                If Not sectorsMap.ContainsKey(sectorId) Then
                                    Continue While
                                End If

                                Dim category As New CatalogMenuCategory()
                                category.Id = SafeInt(reader, "id")
                                category.SettoriId = sectorId
                                category.Descrizione = SafeString(reader, "Descrizione")
                                category.DefaultUrl = "articoli.aspx?st=" & sectorId.ToString() & "&ct=" & category.Id.ToString()

                                sectorsMap(sectorId).Categories.Add(category)
                                categoriesMap(category.Id) = category
                            End While
                        End Using
                    End Using

                    If categoriesMap.Count > 0 AndAlso Not String.IsNullOrWhiteSpace(tipologiaCategoryColumn) Then
                        Dim tipologieSql As String =
                            "SELECT id, " & tipologiaCategoryColumn & " AS CategorieId, Descrizione " &
                            "FROM tipologie " &
                            "WHERE COALESCE(Abilitato,0)=1 " &
                            "ORDER BY COALESCE(Ordinamento,0) ASC, Descrizione ASC"

                        Using cmd As New MySqlCommand(tipologieSql, conn)
                            Using reader As MySqlDataReader = cmd.ExecuteReader()
                                While reader.Read()
                                    Dim categoryId As Integer = SafeInt(reader, "CategorieId")
                                    If Not categoriesMap.ContainsKey(categoryId) Then
                                        Continue While
                                    End If

                                    Dim node As New CatalogMenuNode()
                                    node.Id = SafeInt(reader, "id")
                                    node.ParentId = categoryId
                                    node.Descrizione = SafeString(reader, "Descrizione")
                                    node.DefaultUrl = "articoli.aspx?st=" & categoriesMap(categoryId).SettoriId.ToString() &
                                                      "&ct=" & categoryId.ToString() &
                                                      "&tp=" & node.Id.ToString()

                                    categoriesMap(categoryId).Children.Add(node)
                                End While
                            End Using
                        End Using
                    End If
                End If
            End Using
        Catch
            Return New List(Of CatalogMenuSector)()
        End Try

        Return sectors
    End Function

    Public Function ResolveSectorImageUrl(ByVal imgValue As Object) As String
        Dim fileName As String = Convert.ToString(imgValue).Trim()
        If String.IsNullOrWhiteSpace(fileName) Then
            Return "/Public/assets/images/banner/banner-2.jpg"
        End If

        fileName = fileName.Replace("\", "/")

        If fileName.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           fileName.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
           fileName.StartsWith("/", StringComparison.OrdinalIgnoreCase) Then
            Return fileName
        End If

        fileName = Path.GetFileName(fileName)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return "/Public/assets/images/banner/banner-2.jpg"
        End If

        Return "/Public/assets/images/settori/" & fileName
    End Function

    Private Function ResolveColumnName(ByVal conn As MySqlConnection, ByVal tableName As String, ParamArray ByVal candidates() As String) As String
        If conn Is Nothing OrElse String.IsNullOrWhiteSpace(tableName) OrElse candidates Is Nothing OrElse candidates.Length = 0 Then
            Return String.Empty
        End If

        Dim cacheKey As String = tableName & ":" & String.Join("|", candidates)
        If ColumnCache.ContainsKey(cacheKey) Then
            Return ColumnCache(cacheKey)
        End If

        Dim found As String = String.Empty

        Using cmd As New MySqlCommand("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = @tableName", conn)
            cmd.Parameters.AddWithValue("@tableName", tableName)
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                Dim available As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
                While reader.Read()
                    available.Add(SafeString(reader, "COLUMN_NAME"))
                End While

                For Each candidate As String In candidates
                    If available.Contains(candidate) Then
                        found = candidate
                        Exit For
                    End If
                Next
            End Using
        End Using

        ColumnCache(cacheKey) = found
        Return found
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

    Private Function SafeInt(ByVal reader As IDataRecord, ByVal fieldName As String) As Integer
        Dim value As String = SafeString(reader, fieldName)
        Dim parsed As Integer = 0
        Integer.TryParse(value, parsed)
        Return parsed
    End Function

End Module
