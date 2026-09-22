Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Text

Public NotInheritable Class StorefrontSeoTenantIdentity
    Public Property CompanyId As Integer
    Public Property CompanyName As String
    Public Property CompanyDescription As String
    Public Property CanonicalBaseUrl As String
    Public Property CanonicalHost As String
    Public Property SecondaryHost As String
    Public Property LogoFileName As String
    Public Property DefaultPriceListId As Integer

    Public Function AllowedHosts() As IList(Of String)
        Dim values As New List(Of String)()
        If Not String.IsNullOrWhiteSpace(CanonicalHost) Then values.Add(CanonicalHost)
        If Not String.IsNullOrWhiteSpace(SecondaryHost) AndAlso
           Not String.Equals(SecondaryHost, CanonicalHost, StringComparison.OrdinalIgnoreCase) Then
            values.Add(SecondaryHost)
        End If
        Return values
    End Function
End Class

Public NotInheritable Class StorefrontCanonicalHostPolicy
    Private Shared ReadOnly NonIndexablePages As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "accessonegato.aspx", "aggiungi.aspx", "cart_add.aspx", "catalog_cart_async.aspx",
        "carrello.aspx", "cambiapassword.aspx", "click.aspx", "compare.aspx", "confronta.aspx",
        "datiutente.aspx", "documenti.aspx", "documentidettaglio.aspx", "login.aspx", "logout.aspx",
        "myaccount.aspx", "ordine.aspx", "ordine_coupon.aspx", "pagamento.aspx", "password.aspx",
        "pay_your_orders.aspx", "paypalcheckout.aspx", "paypalrecheck.aspx", "paypalreturn.aspx", "paypalwebhook.aspx",
        "promozioni.aspx", "registrazione.aspx", "remind.aspx", "reset-password.aspx", "test.aspx",
        "wishlist.aspx"
    }

    Private Sub New()
    End Sub

    Public Shared Function CreateTenant(ByVal companyId As Integer,
                                        ByVal companyName As String,
                                        ByVal companyDescription As String,
                                        ByVal primaryUrl As String,
                                        ByVal secondaryUrl As String,
                                        ByVal logoFileName As String,
                                        ByVal defaultPriceListId As Integer) As StorefrontSeoTenantIdentity
        Dim primaryBase As String = NormalizeConfiguredBaseUrl(primaryUrl)
        Dim secondaryBase As String = NormalizeConfiguredBaseUrl(secondaryUrl)
        If String.IsNullOrEmpty(primaryBase) Then Return Nothing

        Dim primaryUri As Uri = Nothing
        If Not Uri.TryCreate(primaryBase, UriKind.Absolute, primaryUri) OrElse primaryUri Is Nothing Then Return Nothing

        Dim secondaryHost As String = String.Empty
        Dim secondaryUri As Uri = Nothing
        If Uri.TryCreate(secondaryBase, UriKind.Absolute, secondaryUri) AndAlso secondaryUri IsNot Nothing Then
            secondaryHost = NormalizeHost(secondaryUri.DnsSafeHost)
        End If

        Return New StorefrontSeoTenantIdentity() With {
            .CompanyId = companyId,
            .CompanyName = Convert.ToString(companyName).Trim(),
            .CompanyDescription = Convert.ToString(companyDescription).Trim(),
            .CanonicalBaseUrl = primaryBase,
            .CanonicalHost = NormalizeHost(primaryUri.DnsSafeHost),
            .SecondaryHost = secondaryHost,
            .LogoFileName = Convert.ToString(logoFileName).Trim(),
            .DefaultPriceListId = defaultPriceListId
        }
    End Function

    Public Shared Function BuildCanonicalUrl(ByVal tenant As StorefrontSeoTenantIdentity,
                                             ByVal relativePathAndQuery As String) As String
        If tenant Is Nothing OrElse String.IsNullOrWhiteSpace(tenant.CanonicalBaseUrl) Then Return String.Empty
        Dim relativeValue As String = Convert.ToString(relativePathAndQuery).Trim()
        If String.IsNullOrEmpty(relativeValue) Then relativeValue = "/"
        If relativeValue.StartsWith("//", StringComparison.Ordinal) Then Return String.Empty

        Dim absolute As Uri = Nothing
        If Uri.TryCreate(relativeValue, UriKind.Absolute, absolute) AndAlso absolute IsNot Nothing Then Return String.Empty

        Dim fragmentIndex As Integer = relativeValue.IndexOf("#"c)
        If fragmentIndex >= 0 Then relativeValue = relativeValue.Substring(0, fragmentIndex)
        If String.IsNullOrEmpty(relativeValue) Then relativeValue = "/"
        If Not relativeValue.StartsWith("/", StringComparison.Ordinal) Then relativeValue = "/" & relativeValue.TrimStart("/"c)
        Return tenant.CanonicalBaseUrl.TrimEnd("/"c) & relativeValue
    End Function

    Public Shared Function BuildCanonicalRedirect(ByVal requestUrl As Uri,
                                                  ByVal isLocalRequest As Boolean,
                                                  ByVal tenant As StorefrontSeoTenantIdentity) As String
        If requestUrl Is Nothing OrElse Not requestUrl.IsAbsoluteUri OrElse isLocalRequest OrElse tenant Is Nothing Then Return String.Empty
        If Not IsRequestHostAllowed(tenant, requestUrl.DnsSafeHost, False) Then Return String.Empty

        Dim requestHost As String = NormalizeHost(requestUrl.DnsSafeHost)
        If String.Equals(requestHost, tenant.CanonicalHost, StringComparison.OrdinalIgnoreCase) AndAlso
           String.Equals(requestUrl.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) AndAlso
           requestUrl.IsDefaultPort Then
            Return String.Empty
        End If
        Return BuildCanonicalUrl(tenant, requestUrl.PathAndQuery)
    End Function

    Public Shared Function IsRequestHostAllowed(ByVal tenant As StorefrontSeoTenantIdentity,
                                                ByVal requestHost As String,
                                                ByVal isLocalRequest As Boolean) As Boolean
        If tenant Is Nothing Then Return False
        Dim host As String = NormalizeHost(requestHost)
        If String.IsNullOrEmpty(host) Then Return False
        For Each allowedHost As String In tenant.AllowedHosts()
            If String.Equals(host, allowedHost, StringComparison.OrdinalIgnoreCase) Then Return True
        Next
        Return False
    End Function

    Public Shared Function SelectExactTenant(ByVal identities As IEnumerable(Of StorefrontSeoTenantIdentity),
                                             ByVal requestHost As String,
                                             ByVal allowSingleTenantLoopback As Boolean) As StorefrontSeoTenantIdentity
        If identities Is Nothing Then Return Nothing

        Dim host As String = NormalizeHost(requestHost)
        If String.IsNullOrEmpty(host) Then Return Nothing

        Dim selected As StorefrontSeoTenantIdentity = Nothing
        Dim validIdentityCount As Integer = 0

        For Each candidate As StorefrontSeoTenantIdentity In identities
            If candidate Is Nothing Then Continue For
            validIdentityCount += 1
            If Not IsRequestHostAllowed(candidate, host, False) Then Continue For
            If selected IsNot Nothing Then Return Nothing
            selected = candidate
        Next

        If selected IsNot Nothing Then Return selected
        If allowSingleTenantLoopback AndAlso IsLoopbackHost(host) AndAlso validIdentityCount = 1 Then
            For Each candidate As StorefrontSeoTenantIdentity In identities
                If candidate IsNot Nothing Then Return candidate
            Next
        End If
        Return Nothing
    End Function

    Public Shared Function IsNoIndexPath(ByVal absolutePath As String) As Boolean
        Dim path As String = Convert.ToString(absolutePath).Trim().Replace("\", "/")
        Dim queryIndex As Integer = path.IndexOf("?"c)
        If queryIndex >= 0 Then path = path.Substring(0, queryIndex)
        Dim slashIndex As Integer = path.LastIndexOf("/"c)
        Dim fileName As String = If(slashIndex >= 0, path.Substring(slashIndex + 1), path)

        If NonIndexablePages.Contains(fileName) Then Return True
        If fileName.StartsWith("coupon_", StringComparison.OrdinalIgnoreCase) Then Return True
        If fileName.StartsWith("export", StringComparison.OrdinalIgnoreCase) Then Return True
        If fileName.StartsWith("search_suggest", StringComparison.OrdinalIgnoreCase) OrElse
           fileName.StartsWith("search-suggest", StringComparison.OrdinalIgnoreCase) Then Return True
        If path.IndexOf("/my-account-", StringComparison.OrdinalIgnoreCase) >= 0 Then Return True
        Return False
    End Function

    Public Shared Function BuildRobotsText(ByVal tenant As StorefrontSeoTenantIdentity) As String
        If tenant Is Nothing Then Return String.Empty
        Dim sb As New StringBuilder()
        sb.AppendLine("# KeepStore storefront robots policy")
        sb.AppendLine("User-agent: *")
        sb.AppendLine("Allow: /")
        sb.AppendLine("Disallow: /*rimuovi=")
        sb.AppendLine("Disallow: /App_Code/")
        sb.AppendLine("Disallow: /App_Data/")
        sb.AppendLine("Disallow: /bin/")
        sb.AppendLine("Disallow: /carrello.aspx")
        sb.AppendLine("Disallow: /login.aspx")
        sb.AppendLine("Disallow: /registrazione.aspx")
        sb.AppendLine("Disallow: /myaccount.aspx")
        sb.AppendLine("Disallow: /my-account-")
        sb.AppendLine("Disallow: /wishlist.aspx")
        sb.AppendLine("Disallow: /documenti.aspx")
        sb.AppendLine("Disallow: /documentidettaglio.aspx")
        sb.AppendLine("Disallow: /ordine.aspx")
        sb.AppendLine("Disallow: /pagamento.aspx")
        sb.AppendLine("Disallow: /pay_your_orders.aspx")
        sb.AppendLine("Disallow: /paypal")
        sb.AppendLine("Disallow: /promozioni.aspx")
        sb.AppendLine("Sitemap: " & BuildCanonicalUrl(tenant, "/sitemap.xml"))
        Return sb.ToString()
    End Function

    Public Shared Function NormalizeConfiguredBaseUrl(ByVal rawValue As String) As String
        Dim value As String = Convert.ToString(rawValue).Trim()
        If String.IsNullOrEmpty(value) Then Return String.Empty
        If value.StartsWith("//", StringComparison.Ordinal) Then value = "https:" & value
        If Not value.StartsWith("http://", StringComparison.OrdinalIgnoreCase) AndAlso
           Not value.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then value = "https://" & value

        Dim configured As Uri = Nothing
        If Not Uri.TryCreate(value, UriKind.Absolute, configured) OrElse configured Is Nothing Then Return String.Empty
        If Not String.IsNullOrEmpty(configured.UserInfo) Then Return String.Empty
        Dim host As String = NormalizeHost(configured.DnsSafeHost)
        If String.IsNullOrEmpty(host) OrElse IsLoopbackHost(host) Then Return String.Empty
        If Uri.CheckHostName(host) <> UriHostNameType.Dns Then Return String.Empty
        Return "https://" & host
    End Function

    Public Shared Function NormalizeHost(ByVal value As String) As String
        Return Convert.ToString(value).Trim().TrimEnd("."c).ToLowerInvariant()
    End Function

    Public Shared Function IsLoopbackHost(ByVal value As String) As Boolean
        Dim host As String = NormalizeHost(value)
        Return String.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase) OrElse
               String.Equals(host, "127.0.0.1", StringComparison.OrdinalIgnoreCase) OrElse
               String.Equals(host, "::1", StringComparison.OrdinalIgnoreCase)
    End Function
End Class
