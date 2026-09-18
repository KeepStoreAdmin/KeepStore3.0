Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

Public NotInheritable Class StorefrontSeoTenantContext
    Private Const ContextItemKey As String = "KeepStore.StorefrontSeoTenant"
    Private Const TenantListCacheKeyPrefix As String = "KeepStore.StorefrontSeoTenant.All"

    Private Sub New()
    End Sub

    Public Shared Function Resolve(ByVal context As HttpContext) As StorefrontSeoTenantIdentity
        If context Is Nothing OrElse context.Request Is Nothing Then Return Nothing

        Dim cachedForRequest As StorefrontSeoTenantIdentity = TryCast(context.Items(ContextItemKey), StorefrontSeoTenantIdentity)
        If cachedForRequest IsNot Nothing Then Return cachedForRequest

        Dim identities As IList(Of StorefrontSeoTenantIdentity) = LoadConfiguredTenants()
        Dim requestHost As String = StorefrontCanonicalHostPolicy.NormalizeHost(context.Request.Url.DnsSafeHost)
        Dim selected As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.SelectExactTenant(
            identities,
            requestHost,
            context.Request.IsLocal)

        If selected IsNot Nothing Then context.Items(ContextItemKey) = selected
        Return selected
    End Function

    Public Shared Function BuildCanonicalUrl(ByVal context As HttpContext,
                                             ByVal relativePathAndQuery As String) As String
        Return StorefrontCanonicalHostPolicy.BuildCanonicalUrl(Resolve(context), relativePathAndQuery)
    End Function

    Public Shared Function BuildCanonicalUrl(ByVal page As System.Web.UI.Page,
                                             ByVal relativePathAndQuery As String) As String
        If page Is Nothing Then Return String.Empty
        Return BuildCanonicalUrl(HttpContext.Current, relativePathAndQuery)
    End Function

    Public Shared Function BrandName(ByVal context As HttpContext) As String
        Dim tenant As StorefrontSeoTenantIdentity = Resolve(context)
        If tenant Is Nothing OrElse String.IsNullOrWhiteSpace(tenant.CompanyName) Then Return "KeepStore"
        Return tenant.CompanyName.Trim()
    End Function

    Private Shared Function LoadConfiguredTenants() As IList(Of StorefrontSeoTenantIdentity)
        Dim result As New List(Of StorefrontSeoTenantIdentity)()
        Try
            Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return result

            Dim cacheKey As String = BuildTenantListCacheKey(settings.ConnectionString)
            Dim fromCache As IList(Of StorefrontSeoTenantIdentity) = TryCast(HttpRuntime.Cache(cacheKey), IList(Of StorefrontSeoTenantIdentity))
            If fromCache IsNot Nothing Then Return fromCache

            Const sql As String = "SELECT Id, Nome, Descrizione, url1, url2, LogoWeb, ListinoDefault FROM aziende ORDER BY Id"
            Using connection As New MySqlConnection(settings.ConnectionString)
                connection.Open()
                Using command As New MySqlCommand(sql, connection)
                    command.CommandType = CommandType.Text
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        While reader.Read()
                            Dim identity As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.CreateTenant(
                                SafeReaderInteger(reader, "Id"),
                                SafeReaderString(reader, "Nome"),
                                SafeReaderString(reader, "Descrizione"),
                                SafeReaderString(reader, "url1"),
                                SafeReaderString(reader, "url2"),
                                SafeReaderString(reader, "LogoWeb"),
                                SafeReaderInteger(reader, "ListinoDefault"))
                            If identity IsNot Nothing Then result.Add(identity)
                        End While
                    End Using
                End Using
            End Using
            HttpRuntime.Cache.Insert(cacheKey,
                                     CType(result, IList(Of StorefrontSeoTenantIdentity)),
                                     Nothing,
                                     DateTime.UtcNow.AddMinutes(10),
                                     System.Web.Caching.Cache.NoSlidingExpiration)
        Catch
            result.Clear()
        End Try
        Return result
    End Function

    Public Shared Function ConfiguredDatabaseScopeKey() As String
        Try
            Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return String.Empty
            Return BuildDatabaseScopeKey(settings.ConnectionString)
        Catch
            Return String.Empty
        End Try
    End Function

    Public Shared Function BuildDatabaseScopeKey(ByVal connectionString As String) As String
        If String.IsNullOrWhiteSpace(connectionString) Then Return String.Empty
        Dim builder As New MySqlConnectionStringBuilder(connectionString)
        Dim databaseIdentity As String = StorefrontCanonicalHostPolicy.NormalizeHost(builder.Server) & "|" &
                                         builder.Port.ToString() & "|" &
                                         Convert.ToString(builder.Database).Trim().ToLowerInvariant()
        Using digest As SHA256 = SHA256.Create()
            Dim hash As Byte() = digest.ComputeHash(Encoding.UTF8.GetBytes(databaseIdentity))
            Dim encoded As New StringBuilder(hash.Length * 2)
            For Each value As Byte In hash
                encoded.Append(value.ToString("x2"))
            Next
            Return encoded.ToString()
        End Using
    End Function

    Private Shared Function BuildTenantListCacheKey(ByVal connectionString As String) As String
        Return TenantListCacheKeyPrefix & "." & BuildDatabaseScopeKey(connectionString)
    End Function

    Private Shared Function SafeReaderString(ByVal reader As IDataRecord, ByVal name As String) As String
        Try
            Dim ordinal As Integer = reader.GetOrdinal(name)
            If reader.IsDBNull(ordinal) Then Return String.Empty
            Return Convert.ToString(reader.GetValue(ordinal)).Trim()
        Catch
            Return String.Empty
        End Try
    End Function

    Private Shared Function SafeReaderInteger(ByVal reader As IDataRecord, ByVal name As String) As Integer
        Return SafeInteger(SafeReaderString(reader, name))
    End Function

    Private Shared Function SafeInteger(ByVal value As Object) As Integer
        Dim parsed As Integer = 0
        Integer.TryParse(Convert.ToString(value), parsed)
        Return parsed
    End Function
End Class
