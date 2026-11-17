Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Collections.ObjectModel
Imports System.Globalization
Imports System.Linq
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
    ' Contatti di assistenza dell'azienda (stessa lettura in cache dell'identita: l'intestazione non li rilegge dal database).
    Public Property SupportPhone As String = String.Empty
    Public Property SupportEmail As String = String.Empty
    ' Dati societari della stessa riga di aziende (lettura separata e facoltativa); Nothing se non disponibili o non agganciabili con certezza.
    Public Property LegalProfile As StorefrontCompanyLegalProfile
    ' Metodi di pagamento pubblici dell'azienda (lettura separata e facoltativa): Nothing se non disponibili o non agganciabili con certezza, vuoto se l'azienda non ne ha.
    ' L'elenco e di sola lettura (ReadOnlyCollection): l'identita sta in una cache condivisa tra le richieste.
    Public Property PaymentMethods As IList(Of StorefrontPaymentMethod)

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

' Dati societari di un'azienda: immutabili (nessuna proprieta si scrive dopo la creazione), con il proprio CompanyId perche chi li mostra possa verificare
' che appartengano all'azienda dell'host. Nothing diventa vuoto e i valori sono solo tagliati (Trim): la presentazione e di chi li mostra.
Public NotInheritable Class StorefrontCompanyLegalProfile
    Private ReadOnly _companyId As Integer
    Private ReadOnly _legalName As String
    Private ReadOnly _vatNumber As String
    Private ReadOnly _registeredAddress As String
    Private ReadOnly _registeredPostalCode As String
    Private ReadOnly _registeredCity As String
    Private ReadOnly _registeredProvince As String
    Private ReadOnly _operationalAddress As String
    Private ReadOnly _operationalPostalCode As String
    Private ReadOnly _operationalCity As String
    Private ReadOnly _operationalProvince As String

    Public Sub New(ByVal companyId As Integer, ByVal legalName As String, ByVal vatNumber As String,
                   ByVal registeredAddress As String, ByVal registeredPostalCode As String, ByVal registeredCity As String, ByVal registeredProvince As String,
                   ByVal operationalAddress As String, ByVal operationalPostalCode As String, ByVal operationalCity As String, ByVal operationalProvince As String)
        _companyId = companyId
        _legalName = Clean(legalName)
        _vatNumber = Clean(vatNumber)
        _registeredAddress = Clean(registeredAddress)
        _registeredPostalCode = Clean(registeredPostalCode)
        _registeredCity = Clean(registeredCity)
        _registeredProvince = Clean(registeredProvince)
        _operationalAddress = Clean(operationalAddress)
        _operationalPostalCode = Clean(operationalPostalCode)
        _operationalCity = Clean(operationalCity)
        _operationalProvince = Clean(operationalProvince)
    End Sub

    Private Shared Function Clean(ByVal value As String) As String
        If value Is Nothing Then Return String.Empty
        Return value.Trim()
    End Function

    Public ReadOnly Property CompanyId As Integer
        Get
            Return _companyId
        End Get
    End Property

    Public ReadOnly Property LegalName As String
        Get
            Return _legalName
        End Get
    End Property

    Public ReadOnly Property VatNumber As String
        Get
            Return _vatNumber
        End Get
    End Property

    Public ReadOnly Property RegisteredAddress As String
        Get
            Return _registeredAddress
        End Get
    End Property

    Public ReadOnly Property RegisteredPostalCode As String
        Get
            Return _registeredPostalCode
        End Get
    End Property

    Public ReadOnly Property RegisteredCity As String
        Get
            Return _registeredCity
        End Get
    End Property

    Public ReadOnly Property RegisteredProvince As String
        Get
            Return _registeredProvince
        End Get
    End Property

    Public ReadOnly Property OperationalAddress As String
        Get
            Return _operationalAddress
        End Get
    End Property

    Public ReadOnly Property OperationalPostalCode As String
        Get
            Return _operationalPostalCode
        End Get
    End Property

    Public ReadOnly Property OperationalCity As String
        Get
            Return _operationalCity
        End Get
    End Property

    Public ReadOnly Property OperationalProvince As String
        Get
            Return _operationalProvince
        End Get
    End Property
End Class

' Un metodo di pagamento pubblico di un'azienda: immutabile, con il proprio CompanyId perche chi lo mostra possa verificare che appartenga all'azienda dell'host.
' OnLine e il tipo di gateway della colonna (0 = nessuno, 2 = PayPal, 3 = carta); GatewayReady dice soltanto che la configurazione del gateway e pronta secondo il
' carrello (mai pronto di default: lo assegna, con una copia, chi conosce la configurazione). Nessun dato di configurazione vive qui.
Public NotInheritable Class StorefrontPaymentMethod
    Private ReadOnly _companyId As Integer
    Private ReadOnly _methodId As Integer
    Private ReadOnly _name As String
    Private ReadOnly _order As Integer
    Private ReadOnly _onLine As Integer
    Private ReadOnly _gatewayReady As Boolean

    Public Sub New(ByVal companyId As Integer, ByVal methodId As Integer, ByVal name As String, ByVal order As Integer)
        Me.New(companyId, methodId, name, order, 0, False)
    End Sub

    Public Sub New(ByVal companyId As Integer, ByVal methodId As Integer, ByVal name As String, ByVal order As Integer,
                   ByVal onLine As Integer, ByVal gatewayReady As Boolean)
        _companyId = companyId
        _methodId = methodId
        If name Is Nothing Then _name = String.Empty Else _name = name.Trim()
        _order = order
        _onLine = onLine
        _gatewayReady = gatewayReady
    End Sub

    Public Function WithGatewayReady(ByVal ready As Boolean) As StorefrontPaymentMethod
        Return New StorefrontPaymentMethod(_companyId, _methodId, _name, _order, _onLine, ready)
    End Function

    Public ReadOnly Property OnLine As Integer
        Get
            Return _onLine
        End Get
    End Property

    Public ReadOnly Property GatewayReady As Boolean
        Get
            Return _gatewayReady
        End Get
    End Property

    Public ReadOnly Property CompanyId As Integer
        Get
            Return _companyId
        End Get
    End Property

    Public ReadOnly Property MethodId As Integer
        Get
            Return _methodId
        End Get
    End Property

    Public ReadOnly Property Name As String
        Get
            Return _name
        End Get
    End Property

    Public ReadOnly Property Order As Integer
        Get
            Return _order
        End Get
    End Property
End Class

Public NotInheritable Class StorefrontCanonicalHostPolicy
    Private Shared ReadOnly NonIndexablePages As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "accessonegato.aspx", "aggiungi.aspx", "cart_add.aspx", "catalog_cart_async.aspx",
        "carrello.aspx", "cambiapassword.aspx", "click.aspx", "compare.aspx", "confronta.aspx",
        "datiutente.aspx", "documenti.aspx", "documentidettaglio.aspx", "login.aspx", "logout.aspx",
        "myaccount.aspx", "ordine.aspx", "ordine_coupon.aspx", "pagamento.aspx", "password.aspx",
        "pay_your_orders.aspx", "paypalcheckout.aspx", "paypalpay.aspx", "paypalrecheck.aspx", "paypalreturn.aspx", "paypalwebhook.aspx",
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

    ' Mappa le colonne di aziende nel profilo legale (sede legale = SL_*, sede operativa = Indirizzo, Cap, Citta, Provincia: come le stampe del gestionale).
    ' L'Id deve essere valido: un Id illeggibile (0) non produce un profilo.
    Public Shared Function CreateLegalProfile(ByVal companyId As Integer,
                                              ByVal column As Func(Of String, String)) As StorefrontCompanyLegalProfile
        If companyId <= 0 OrElse column Is Nothing Then Return Nothing
        Return New StorefrontCompanyLegalProfile(companyId,
                                                 column("RagioneSociale"), column("Piva"),
                                                 column("SL_Indirizzo"), column("SL_CAP"), column("SL_Citta"), column("SL_Provincia"),
                                                 column("Indirizzo"), column("Cap"), column("Citta"), column("Provincia"))
    End Function

    ' Associa il profilo all'identita con lo STESSO CompanyId, mai per posizione, e solo se quell'Id compare UNA volta tra le righe e UNA volta tra le
    ' identita (la chiave di aziende e (id, IvaTipo): l'id non e unico per schema). In ogni altro caso l'identita resta senza profilo.
    Public Shared Sub ApplyLegalProfiles(ByVal identities As IEnumerable(Of StorefrontSeoTenantIdentity),
                                         ByVal profiles As IEnumerable(Of StorefrontCompanyLegalProfile))
        If identities Is Nothing Then Return

        Dim profileCounts As New Dictionary(Of Integer, Integer)()
        Dim profileById As New Dictionary(Of Integer, StorefrontCompanyLegalProfile)()
        If profiles IsNot Nothing Then
            For Each profile As StorefrontCompanyLegalProfile In profiles
                If profile Is Nothing OrElse profile.CompanyId <= 0 Then Continue For
                Dim seenProfile As Integer = 0
                profileCounts.TryGetValue(profile.CompanyId, seenProfile)
                profileCounts(profile.CompanyId) = seenProfile + 1
                profileById(profile.CompanyId) = profile
            Next
        End If

        Dim identityCounts As New Dictionary(Of Integer, Integer)()
        For Each identity As StorefrontSeoTenantIdentity In identities
            If identity Is Nothing OrElse identity.CompanyId <= 0 Then Continue For
            Dim seenIdentity As Integer = 0
            identityCounts.TryGetValue(identity.CompanyId, seenIdentity)
            identityCounts(identity.CompanyId) = seenIdentity + 1
        Next

        For Each identity As StorefrontSeoTenantIdentity In identities
            If identity Is Nothing Then Continue For
            Dim attached As StorefrontCompanyLegalProfile = Nothing
            Dim companyId As Integer = identity.CompanyId
            If companyId > 0 AndAlso profileCounts.ContainsKey(companyId) AndAlso identityCounts.ContainsKey(companyId) Then
                If profileCounts(companyId) = 1 AndAlso identityCounts(companyId) = 1 Then attached = profileById(companyId)
            End If
            identity.LegalProfile = attached
        Next
    End Sub

    ' Mappa le colonne di pagamentitipo lette dal piede. Azienda o metodo illeggibili (0 o negativi) e nome vuoto non producono un metodo; l'ordine e il tipo di gateway
    ' (OnLine) illeggibili valgono 0. Il metodo nasce SEMPRE non pronto: la prontezza della configurazione non e una colonna di questa riga.
    Public Shared Function CreatePaymentMethod(ByVal column As Func(Of String, String)) As StorefrontPaymentMethod
        If column Is Nothing Then Return Nothing
        Dim companyId As Integer = ToInteger(column("AziendeID"))
        Dim methodId As Integer = ToInteger(column("id"))
        Dim name As String = column("Descrizione")
        If companyId <= 0 OrElse methodId <= 0 OrElse String.IsNullOrWhiteSpace(name) Then Return Nothing
        Return New StorefrontPaymentMethod(companyId, methodId, name, ToInteger(column("Ordinamento")), ToInteger(column("OnLine")), False)
    End Function

    Private Shared Function ToInteger(ByVal value As String) As Integer
        Dim parsed As Integer = 0
        Integer.TryParse(If(value, String.Empty).Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed)
        Return parsed
    End Function

    ' Associa a ogni identita i metodi della SUA azienda, mai per posizione, e solo se quell'Id compare UNA volta tra le identita (la chiave di aziende e (id, IvaTipo)).
    ' methods = Nothing (lettura fallita): nessuna identita riceve un elenco. Un'azienda senza righe riceve un elenco vuoto. L'elenco assegnato e di sola lettura e ordinato
    ' (Ordinamento, nome senza maiuscole, id): il limite del piede sceglie sempre gli stessi metodi.
    Public Shared Sub ApplyPaymentMethods(ByVal identities As IEnumerable(Of StorefrontSeoTenantIdentity),
                                          ByVal methods As IEnumerable(Of StorefrontPaymentMethod))
        If identities Is Nothing Then Return

        Dim byCompany As Dictionary(Of Integer, List(Of StorefrontPaymentMethod)) = Nothing
        If methods IsNot Nothing Then
            byCompany = New Dictionary(Of Integer, List(Of StorefrontPaymentMethod))()
            For Each method As StorefrontPaymentMethod In methods
                If method Is Nothing OrElse method.CompanyId <= 0 Then Continue For
                Dim bucket As List(Of StorefrontPaymentMethod) = Nothing
                If Not byCompany.TryGetValue(method.CompanyId, bucket) Then
                    bucket = New List(Of StorefrontPaymentMethod)()
                    byCompany(method.CompanyId) = bucket
                End If
                bucket.Add(method)
            Next
        End If

        Dim identityCounts As New Dictionary(Of Integer, Integer)()
        For Each identity As StorefrontSeoTenantIdentity In identities
            If identity Is Nothing OrElse identity.CompanyId <= 0 Then Continue For
            Dim seen As Integer = 0
            identityCounts.TryGetValue(identity.CompanyId, seen)
            identityCounts(identity.CompanyId) = seen + 1
        Next

        For Each identity As StorefrontSeoTenantIdentity In identities
            If identity Is Nothing Then Continue For
            Dim attached As IList(Of StorefrontPaymentMethod) = Nothing
            Dim companyId As Integer = identity.CompanyId
            If byCompany IsNot Nothing AndAlso companyId > 0 AndAlso identityCounts.ContainsKey(companyId) AndAlso identityCounts(companyId) = 1 Then
                Dim ordered As New List(Of StorefrontPaymentMethod)()
                Dim bucket As List(Of StorefrontPaymentMethod) = Nothing
                If byCompany.TryGetValue(companyId, bucket) Then
                    ordered.AddRange(bucket.OrderBy(Function(m) m.Order).ThenBy(Function(m) m.Name, StringComparer.OrdinalIgnoreCase).ThenBy(Function(m) m.MethodId))
                End If
                attached = New ReadOnlyCollection(Of StorefrontPaymentMethod)(ordered)
            End If
            identity.PaymentMethods = attached
        Next
    End Sub

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
