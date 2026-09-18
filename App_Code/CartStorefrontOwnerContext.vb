Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Web

Public NotInheritable Class CartStorefrontOwnerScope
    Public Property DatabaseScopeKey As String
    Public Property CompanyId As Integer
    Public Property LoginId As Integer
    Public Property SessionId As String
    Public Property Listino As Integer
    Public Property OwnerScopeKey As String
    Public Property IsCanonicalMutationHost As Boolean

    Public ReadOnly Property IsAuthenticated As Boolean
        Get
            Return LoginId > 0
        End Get
    End Property
End Class

Public NotInheritable Class CartStorefrontOwnerContext
    Private Sub New()
    End Sub

    Public Shared Function Resolve(ByVal context As HttpContext) As CartStorefrontOwnerScope
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Session Is Nothing Then Return Nothing

        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
        Dim databaseScope As String = StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey()
        If tenant Is Nothing OrElse tenant.CompanyId <= 0 OrElse String.IsNullOrEmpty(databaseScope) Then Return Nothing

        Dim sessionCompanyId As Integer = SessionInteger(context, "AziendaID", 0)
        If sessionCompanyId <> tenant.CompanyId Then Return Nothing

        Dim loginId As Integer = SessionInteger(context, "LoginId",
            SessionInteger(context, "LoginID", SessionInteger(context, "LOGINID", 0)))
        Dim authenticatedCompanyId As Integer = SessionInteger(context, "AuthenticatedAziendaID", 0)
        Dim listino As Integer = SessionInteger(context, "Listino", SessionInteger(context, "listino", 0))
        If listino <= 0 Then listino = tenant.DefaultPriceListId
        If listino <= 0 Then Return Nothing

        Dim ownerSessionId As String = String.Empty
        If loginId > 0 Then
            If Not CartStorefrontScopePolicy.IsAuthenticatedScopeValid(
                   tenant.CompanyId, authenticatedCompanyId, loginId) Then Return Nothing
        Else
            ownerSessionId = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(
                databaseScope, tenant.CompanyId, Convert.ToString(context.Session.SessionID))
            If String.IsNullOrEmpty(ownerSessionId) Then Return Nothing
        End If

        Dim ownerScopeKey As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(
            databaseScope, tenant.CompanyId, loginId, ownerSessionId)
        If String.IsNullOrEmpty(ownerScopeKey) Then Return Nothing

        Dim canonicalRedirect As String = StorefrontCanonicalHostPolicy.BuildCanonicalRedirect(
            context.Request.Url, context.Request.IsLocal, tenant)
        Return New CartStorefrontOwnerScope() With {
            .DatabaseScopeKey = databaseScope,
            .CompanyId = tenant.CompanyId,
            .LoginId = loginId,
            .SessionId = ownerSessionId,
            .Listino = listino,
            .OwnerScopeKey = ownerScopeKey,
            .IsCanonicalMutationHost = String.IsNullOrEmpty(canonicalRedirect)
        }
    End Function

    Public Shared Function ResolveForMutation(ByVal context As HttpContext) As CartStorefrontOwnerScope
        Dim scope As CartStorefrontOwnerScope = Resolve(context)
        If scope Is Nothing OrElse Not scope.IsCanonicalMutationHost Then Return Nothing
        Return scope
    End Function

    Private Shared Function SessionInteger(ByVal context As HttpContext,
                                           ByVal key As String,
                                           ByVal fallback As Integer) As Integer
        Dim parsed As Integer
        If context IsNot Nothing AndAlso context.Session IsNot Nothing AndAlso
           Integer.TryParse(Convert.ToString(context.Session(key)), NumberStyles.Integer,
                            CultureInfo.InvariantCulture, parsed) Then Return parsed
        Return fallback
    End Function
End Class
