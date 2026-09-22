Option Strict On
Option Explicit On

Imports System
Imports System.Net
Imports System.Web

Public NotInheritable Class PayPalCheckoutSafetyPolicy
    Private Sub New()
    End Sub

    Public Shared Function CanUseLiveCheckout(ByVal context As HttpContext,
                                              ByVal cfg As PayPalCheckoutConfig) As Boolean
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Request.Url Is Nothing Then Return False
        If cfg Is Nothing OrElse Not cfg.IsConfigured Then Return False
        If Not context.Request.IsSecureConnection OrElse
           Not String.Equals(context.Request.Url.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) Then Return False
        If context.Request.IsLocal OrElse IsLoopback(context.Request.Url.Host) OrElse IsLoopback(context.Request.UserHostAddress) Then Return False

        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
        If tenant Is Nothing OrElse tenant.CompanyId <> cfg.AziendeId Then Return False
        Return StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenant, context.Request.Url.Host, False)
    End Function

    Public Shared Function IsTrustedApprovalUrl(ByVal value As String) As Boolean
        Dim target As Uri = Nothing
        If Not Uri.TryCreate(Convert.ToString(value).Trim(), UriKind.Absolute, target) OrElse target Is Nothing Then Return False
        If Not String.Equals(target.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) Then Return False
        If Not String.Equals(target.DnsSafeHost, "www.paypal.com", StringComparison.OrdinalIgnoreCase) Then Return False
        If target.UserInfo <> String.Empty Then Return False
        Return target.AbsolutePath.StartsWith("/checkoutnow", StringComparison.OrdinalIgnoreCase)
    End Function

    Private Shared Function IsLoopback(ByVal value As String) As Boolean
        Dim candidate As String = Convert.ToString(value).Trim().Trim("["c, "]"c)
        If String.Equals(candidate, "localhost", StringComparison.OrdinalIgnoreCase) Then Return True
        Dim address As IPAddress = Nothing
        Return IPAddress.TryParse(candidate, address) AndAlso IPAddress.IsLoopback(address)
    End Function
End Class
