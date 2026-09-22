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
        If Not HasSafeLiveIngress(context) Then Return False

        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
        If tenant Is Nothing OrElse tenant.CompanyId <> cfg.AziendeId Then Return False
        Return StorefrontCanonicalHostPolicy.IsRequestHostAllowed(tenant, context.Request.Url.Host, False)
    End Function

    ' L'host del webhook puo appartenere all'altro storefront dello stesso
    ' account PayPal condiviso: si valida l'ingresso, non lo si uguaglia al tenant
    ' della transazione, che deriva solo dal mapping persistito.
    Public Shared Function CanUseLiveWebhook(ByVal context As HttpContext) As Boolean
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Request.Url Is Nothing Then Return False
        If Not HasSafeLiveIngress(context) Then Return False
        Dim ingressTenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
        Return CanUseLiveWebhookIngress(context.Request.Url.Scheme, context.Request.IsSecureConnection,
            context.Request.IsLocal, context.Request.Url.Host, context.Request.UserHostAddress,
            context.Request.ServerVariables("LOCAL_ADDR"), ingressTenant)
    End Function

    Public Shared Function CanUseLiveWebhookIngress(ByVal scheme As String, ByVal isSecure As Boolean,
                                                    ByVal isLocal As Boolean, ByVal host As String,
                                                    ByVal remoteAddress As String, ByVal localAddress As String,
                                                    ByVal ingressTenant As StorefrontSeoTenantIdentity) As Boolean
        Return IsLiveIngressAllowed(scheme, isSecure, isLocal, host, remoteAddress, localAddress) AndAlso
               ingressTenant IsNot Nothing AndAlso
               StorefrontCanonicalHostPolicy.IsRequestHostAllowed(ingressTenant, host, False)
    End Function

    Private Shared Function HasSafeLiveIngress(ByVal context As HttpContext) As Boolean
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Request.Url Is Nothing Then Return False
        Return IsLiveIngressAllowed(context.Request.Url.Scheme, context.Request.IsSecureConnection,
            context.Request.IsLocal, context.Request.Url.Host, context.Request.UserHostAddress,
            context.Request.ServerVariables("LOCAL_ADDR"))
    End Function

    Public Shared Function IsLiveIngressAllowed(ByVal scheme As String, ByVal isSecure As Boolean,
                                                ByVal isLocal As Boolean, ByVal host As String,
                                                ByVal remoteAddress As String, ByVal localAddress As String) As Boolean
        Return isSecure AndAlso String.Equals(scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) AndAlso
               Not isLocal AndAlso Not IsLoopback(host) AndAlso
               Not IsLoopback(remoteAddress) AndAlso Not IsLoopback(localAddress)
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
