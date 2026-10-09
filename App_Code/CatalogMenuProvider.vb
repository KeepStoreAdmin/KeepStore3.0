Imports System
Imports System.Collections.Concurrent
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports System.Web.Caching
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
    Public Property Children As List(Of CatalogMenuNode)

    Public Sub New()
        Children = New List(Of CatalogMenuNode)()
    End Sub
End Class

Public Module CatalogMenuProvider

    Private ReadOnly ColumnCache As New ConcurrentDictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
    Private ReadOnly MenuCacheLock As New Object()
    Private Const MenuCachePrefix As String = "KeepStore:CatalogMenuProvider:Menu:v2:"

    Public Function LoadCatalogMenuCached(Optional ByVal cacheSeconds As Integer = 600) As List(Of CatalogMenuSector)
        Dim connectionString As String = CatalogConnectionString()
        Return LoadMenuForScope(DatabaseCacheIdentity(connectionString), cacheSeconds,
                                Function() LoadCatalogMenu(connectionString))
    End Function

    Private Function CatalogConnectionString() As String
        Try
            Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        Catch
            Return String.Empty
        End Try
    End Function

    Private Function DatabaseCacheIdentity(ByVal connectionString As String) As String
        Try
            Dim builder As New MySqlConnectionStringBuilder(connectionString)
            Dim server As String = builder.Server.Trim().TrimEnd("."c).ToLowerInvariant()
            Dim database As String = builder.Database.Trim().ToLowerInvariant()
            If server.Length = 0 OrElse database.Length = 0 OrElse builder.Port = 0 Then Return String.Empty

            ' Length-delimited database coordinates only; never credentials or request/tenant identity.
            Dim identity As String = server.Length.ToString(CultureInfo.InvariantCulture) & ":" & server & "|" &
                                     builder.Port.ToString(CultureInfo.InvariantCulture) & "|" &
                                     database.Length.ToString(CultureInfo.InvariantCulture) & ":" & database
            Using digest As SHA256 = SHA256.Create()
                Return BitConverter.ToString(digest.ComputeHash(Encoding.UTF8.GetBytes(identity))).Replace("-", String.Empty)
            End Using
        Catch
            Return String.Empty
        End Try
    End Function

    Private Function LoadMenuForScope(ByVal databaseIdentity As String, ByVal cacheSeconds As Integer,
                                      ByVal loader As Func(Of List(Of CatalogMenuSector))) As List(Of CatalogMenuSector)
        If String.IsNullOrEmpty(databaseIdentity) Then Return loader()

        Dim cacheKey As String = MenuCachePrefix & databaseIdentity
        Dim cached As List(Of CatalogMenuSector) = TryCast(HttpRuntime.Cache(cacheKey), List(Of CatalogMenuSector))
        If cached IsNot Nothing AndAlso cached.Count > 0 Then Return cached

        ' Recheck after the lock so simultaneous cold consumers do not reload the same taxonomy.
        SyncLock MenuCacheLock
            cached = TryCast(HttpRuntime.Cache(cacheKey), List(Of CatalogMenuSector))
            If cached IsNot Nothing AndAlso cached.Count > 0 Then Return cached

            Dim sectors As List(Of CatalogMenuSector) = loader()
            ' LoadCatalogMenu returns an empty tree on failure: never persist it as absence.
            If sectors IsNot Nothing AndAlso sectors.Count > 0 Then
                Try
                    If cacheSeconds < 60 Then cacheSeconds = 60
                    HttpRuntime.Cache.Insert(cacheKey, sectors, Nothing, DateTime.Now.AddSeconds(cacheSeconds), Cache.NoSlidingExpiration)
                Catch
                End Try
            End If
            Return sectors
        End SyncLock
    End Function

    Public Function LoadCatalogMenu() As List(Of CatalogMenuSector)
        Return LoadCatalogMenu(CatalogConnectionString())
    End Function

    Private Function LoadCatalogMenu(ByVal connectionString As String) As List(Of CatalogMenuSector)
        Dim sectors As New List(Of CatalogMenuSector)()

        Try
            Using conn As New MySqlConnection(connectionString)
                conn.Open()

                Dim categorySectorColumn As String = ResolveColumnName(conn, "categorie", "SettoriId", "Id_settore")
                Dim tipologiaCategoryColumn As String = ResolveColumnName(conn, "tipologie", "CategorieId", "Id_categoria")

                Dim sectorsMap As New Dictionary(Of Integer, CatalogMenuSector)()
                Using cmd As New MySqlCommand("SELECT id, Descrizione, Img FROM settori WHERE COALESCE(Abilitato,0)=1 ORDER BY COALESCE(Predefinito,0) DESC, COALESCE(Ordinamento,999999) ASC, Descrizione ASC", conn)
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
            Return String.Empty
        End If

        fileName = fileName.Replace("\", "/")

        If fileName.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           fileName.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return fileName
        End If

        fileName = Path.GetFileName(fileName)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return String.Empty
        End If

        Return "/Public/assets/images/settori/" & fileName
    End Function

    Private Function ResolveColumnName(ByVal conn As MySqlConnection, ByVal tableName As String, ParamArray ByVal candidates() As String) As String
        If conn Is Nothing OrElse String.IsNullOrWhiteSpace(tableName) OrElse candidates Is Nothing OrElse candidates.Length = 0 Then
            Return String.Empty
        End If

        Return LoadColumnForScope(DatabaseCacheIdentity(conn.ConnectionString), tableName, candidates,
                                  Function() ResolveColumnNameUncached(conn, tableName, candidates))
    End Function

    Private Function LoadColumnForScope(ByVal databaseIdentity As String, ByVal tableName As String,
                                        ByVal candidates() As String, ByVal loader As Func(Of String)) As String
        If String.IsNullOrEmpty(databaseIdentity) Then Return loader()
        Dim cacheKey As String = databaseIdentity & ":" & tableName & ":" & String.Join("|", candidates)
        Return ColumnCache.GetOrAdd(cacheKey, Function(ignoredKey) loader())
    End Function

    Private Function ResolveColumnNameUncached(ByVal conn As MySqlConnection, ByVal tableName As String,
                                              ByVal candidates() As String) As String
        Dim found As String = String.Empty

        Using cmd As New MySqlCommand("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND LOWER(TABLE_NAME) = LOWER(@tableName)", conn)
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
