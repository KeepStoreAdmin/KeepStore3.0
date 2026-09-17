Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Web
Imports MySql.Data.MySqlClient

Public NotInheritable Class StorefrontSeoTenantContext
    Private Const ContextItemKey As String = "KeepStore.StorefrontSeoTenant"
    Private Const TenantCacheKey As String = "KeepStore.StorefrontSeoTenant.All"

    Private Sub New()
    End Sub

    Public Shared Function Resolve(ByVal context As HttpContext) As StorefrontSeoTenantIdentity
        If context Is Nothing OrElse context.Request Is Nothing Then Return Nothing

        Dim cachedForRequest As StorefrontSeoTenantIdentity = TryCast(context.Items(ContextItemKey), StorefrontSeoTenantIdentity)
        If cachedForRequest IsNot Nothing Then Return cachedForRequest

        Dim fromSession As StorefrontSeoTenantIdentity = ResolveFromSession(context)
        If fromSession IsNot Nothing AndAlso
           StorefrontCanonicalHostPolicy.IsRequestHostAllowed(fromSession,
                                                               context.Request.Url.DnsSafeHost,
                                                               context.Request.IsLocal) Then
            context.Items(ContextItemKey) = fromSession
            Return fromSession
        End If

        Dim identities As IList(Of StorefrontSeoTenantIdentity) = LoadConfiguredTenants()
        Dim requestHost As String = StorefrontCanonicalHostPolicy.NormalizeHost(context.Request.Url.DnsSafeHost)
        Dim selected As StorefrontSeoTenantIdentity = Nothing

        For Each candidate As StorefrontSeoTenantIdentity In identities
            If candidate Is Nothing Then Continue For
            If StorefrontCanonicalHostPolicy.IsRequestHostAllowed(candidate, requestHost, False) Then
                selected = candidate
                Exit For
            End If
        Next

        If selected Is Nothing AndAlso
           (context.Request.IsLocal OrElse StorefrontCanonicalHostPolicy.IsLoopbackHost(requestHost)) AndAlso
           identities.Count = 1 Then
            selected = identities(0)
        End If

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

    Private Shared Function ResolveFromSession(ByVal context As HttpContext) As StorefrontSeoTenantIdentity
        Try
            If context.Session Is Nothing Then Return Nothing
            Dim companyId As Integer = SafeInteger(context.Session("AziendaID"))
            Dim defaultPriceListId As Integer = SafeInteger(context.Session("Listino"))
            Return StorefrontCanonicalHostPolicy.CreateTenant(companyId,
                                                               Convert.ToString(context.Session("AziendaNome")),
                                                               Convert.ToString(context.Session("AziendaDescrizione")),
                                                               Convert.ToString(context.Session("AziendaUrl")),
                                                               Convert.ToString(context.Session("AziendaUrl2")),
                                                               Convert.ToString(context.Session("AziendaLogo")),
                                                               defaultPriceListId)
        Catch
            Return Nothing
        End Try
    End Function

    Private Shared Function LoadConfiguredTenants() As IList(Of StorefrontSeoTenantIdentity)
        Dim fromCache As IList(Of StorefrontSeoTenantIdentity) = TryCast(HttpRuntime.Cache(TenantCacheKey), IList(Of StorefrontSeoTenantIdentity))
        If fromCache IsNot Nothing Then Return fromCache

        Dim result As New List(Of StorefrontSeoTenantIdentity)()
        Try
            Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return result

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
        Catch
            result.Clear()
        End Try

        HttpRuntime.Cache.Insert(TenantCacheKey,
                                 CType(result, IList(Of StorefrontSeoTenantIdentity)),
                                 Nothing,
                                 DateTime.UtcNow.AddMinutes(10),
                                 System.Web.Caching.Cache.NoSlidingExpiration)
        Return result
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
