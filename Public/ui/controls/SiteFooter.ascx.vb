Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Hosting

' Piede del sito. I dati dell'azienda (nome, logo, telefono, e-mail, dati societari) arrivano SOLO dall'identita dell'host gia in cache
' (StorefrontSeoTenantContext): nessuna connessione al database e nessun ripiego sull'azienda della sessione. Senza identita valida
' (host sconosciuto, o sessione di un'altra azienda) il piede mostra solo il logo neutro, i link fissi e "Scrivici". Cio che manca si omette:
' mai un valore inventato. I dati societari si mostrano solo se il profilo porta lo stesso CompanyId dell'host.
Partial Class SiteFooter
    Inherits System.Web.UI.UserControl

    Private Const DefaultLogoVirtual As String = "~/Public/assets/images/logo/logo.svg"
    Private Const FooterCategoriesMax As Integer = 7

    ' Il piede si ricostruisce a ogni richiesta: nessun ViewState (come la testata).
    Protected Sub Page_Init(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Init
        Me.EnableViewState = False
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim tenant As StorefrontSeoTenantIdentity = ResolveFooterTenant()
        Dim hostCompanyId As Integer = 0
        Dim companyName As String = String.Empty
        Dim logoFileName As String = String.Empty
        Dim phone As String = String.Empty
        Dim email As String = String.Empty
        Dim legalProfile As StorefrontCompanyLegalProfile = Nothing
        Dim payments As IList(Of StorefrontPaymentMethod) = Nothing
        If tenant IsNot Nothing Then
            hostCompanyId = tenant.CompanyId
            companyName = tenant.CompanyName
            logoFileName = tenant.LogoFileName
            phone = tenant.SupportPhone
            email = tenant.SupportEmail
            legalProfile = tenant.LegalProfile
            payments = tenant.PaymentMethods
        End If

        ' Il link di Facebook vive nella sessione, scritta con l'azienda dell'host nella stessa lettura: BuildFooterData lo usa solo se coincidono.
        Dim facebookRaw As String = If(Session Is Nothing, String.Empty, Convert.ToString(Session("facebookLink")))
        Dim data As FooterData = BuildFooterData(hostCompanyId, SessionCompanyId(), companyName, logoFileName, phone, email, facebookRaw, legalProfile, payments, DateTime.Now.Year)

        BindFooterLogo(data)
        BindFooterColumns()
        BindFooterSocial(data)
        BindFooterLegal(data)
        BindFooterPayments(data)
        If litFooterContacts IsNot Nothing Then litFooterContacts.Text = data.ContactsHtml
        If litFooterCopyright IsNot Nothing Then litFooterCopyright.Text = data.CopyrightHtml
    End Sub

    Private Function ResolveFooterTenant() As StorefrontSeoTenantIdentity
        Try
            Return StorefrontSeoTenantContext.Resolve(HttpContext.Current)
        Catch
            Return Nothing
        End Try
    End Function

    Private Function SessionCompanyId() As Integer
        Dim value As Integer = 0
        If Session IsNot Nothing Then Integer.TryParse(Convert.ToString(Session("AziendaID"), CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, value)
        Return value
    End Function

    Private Sub BindFooterLogo(ByVal data As FooterData)
        If imgFooterLogo Is Nothing Then Return

        Dim logoUrl As String = BuildLogoAssetUrlFromFileName(data.LogoFileName)
        If String.IsNullOrWhiteSpace(logoUrl) OrElse Not LogoUrlExists(logoUrl) Then
            logoUrl = ResolveUrl(DefaultLogoVirtual)
            If Not LogoUrlExists(logoUrl) Then
                imgFooterLogo.Visible = False
                Return
            End If
        End If

        imgFooterLogo.ImageUrl = logoUrl
        imgFooterLogo.AlternateText = If(String.IsNullOrWhiteSpace(data.CompanyName), "KeepStore", data.CompanyName)
        imgFooterLogo.Attributes("decoding") = "async"
    End Sub

    ' Catalogo: i settori reali (gli stessi della barra reparti della testata). La lista in cache e condivisa: qui si legge soltanto, mai si modifica.
    ' Un caricamento fallito o vuoto non e "nessun settore": si omette la colonna.
    Private Sub BindFooterColumns()
        Dim html As String = String.Empty
        Try
            Dim sectors As List(Of CatalogMenuSector) = CatalogMenuProvider.LoadCatalogMenuCached()
            If sectors IsNot Nothing Then
                Dim items As New List(Of KeyValuePair(Of String, String))()
                For Each sector As CatalogMenuSector In sectors
                    If sector IsNot Nothing Then items.Add(New KeyValuePair(Of String, String)(sector.Descrizione, sector.DefaultUrl))
                Next
                html = BuildFooterCategoriesHtml(items, FooterCategoriesMax)
            End If
        Catch
            html = String.Empty
        End Try

        If phFooterCategories IsNot Nothing AndAlso litFooterCategories IsNot Nothing Then
            phFooterCategories.Visible = html.Length > 0
            litFooterCategories.Text = html
        End If
        If ulFooterColumns IsNot Nothing Then ulFooterColumns.Attributes("class") = FooterGridClass(If(html.Length > 0, 4, 3))
    End Sub

    Private Sub BindFooterSocial(ByVal data As FooterData)
        If liFooterFacebook Is Nothing OrElse lnkFooterFacebook Is Nothing Then Return
        Dim show As Boolean = data.FacebookUrl.Length > 0
        liFooterFacebook.Visible = show
        If ulFooterSocial IsNot Nothing Then ulFooterSocial.Visible = show
        If Not show Then Return

        lnkFooterFacebook.HRef = data.FacebookUrl
        lnkFooterFacebook.Attributes("aria-label") = "Facebook"
    End Sub

    ' Metodi di pagamento: il blocco (etichetta compresa) c'e solo se resta almeno un metodo; vuoto = nessun paragrafo nella pagina.
    Private Sub BindFooterPayments(ByVal data As FooterData)
        If phFooterPayments Is Nothing OrElse litFooterPayments Is Nothing Then Return
        phFooterPayments.Visible = data.PaymentsHtml.Length > 0
        litFooterPayments.Text = data.PaymentsHtml
    End Sub

    ' Dati societari: il blocco c'e solo se ha almeno una riga; vuoto = nessun paragrafo nella pagina.
    Private Sub BindFooterLegal(ByVal data As FooterData)
        If phFooterLegal Is Nothing OrElse litFooterLegal Is Nothing Then Return
        phFooterLegal.Visible = data.LegalHtml.Length > 0
        litFooterLegal.Text = data.LegalHtml
    End Sub

#Region "FooterPure"
    ' Funzioni pure (nessun accesso a sessione, database o richiesta): provate compilando questo stesso testo (Tools/Test-FooterTruth.ps1).
    Private Shared ReadOnly CategoryUrlPattern As New Regex("^articoli\.aspx\?st=[0-9]{1,9}\z", RegexOptions.CultureInvariant)
    Private Shared ReadOnly LegalFormatChars As New Regex("\p{Cf}+", RegexOptions.CultureInvariant)
    Private Shared ReadOnly LegalSpaces As New Regex("[\s\p{Cc}]+", RegexOptions.CultureInvariant)
    Private Shared ReadOnly LegalLetter As New Regex("\p{L}", RegexOptions.CultureInvariant)
    Private Shared ReadOnly VatPattern As New Regex("^[A-Z]{0,2}[0-9]{5,14}\z", RegexOptions.CultureInvariant)
    Private Shared ReadOnly PostalPattern As New Regex("^[0-9]{5}\z", RegexOptions.CultureInvariant)
    Private Shared ReadOnly ProvincePattern As New Regex("^[A-Za-z]{2}\z", RegexOptions.CultureInvariant)

    Friend NotInheritable Class FooterData
        Public LogoFileName As String = String.Empty
        Public CompanyName As String = String.Empty
        Public ContactsHtml As String = String.Empty
        Public CopyrightHtml As String = String.Empty
        Public FacebookUrl As String = String.Empty
        Public LegalHtml As String = String.Empty
        Public PaymentsHtml As String = String.Empty
    End Class

    ' La sessione puo non avere ancora l'azienda (0): vale l'host. Se ce l'ha ed e diversa da quella dell'host, nessun dato.
    Friend Shared Function IsFooterTenantAllowed(ByVal tenantCompanyId As Integer, ByVal sessionCompanyId As Integer) As Boolean
        If tenantCompanyId <= 0 Then Return False
        If sessionCompanyId > 0 AndAlso sessionCompanyId <> tenantCompanyId Then Return False
        Return True
    End Function

    ' Tutto cio che il piede mostra dell'azienda, in un solo punto: senza azienda dell'host valida (o con la sessione di un'altra azienda)
    ' resta solo il neutro. Il link di Facebook richiede in piu che la sessione appartenga all'azienda dell'host.
    Friend Shared Function BuildFooterData(ByVal hostCompanyId As Integer, ByVal sessionCompanyId As Integer, ByVal companyName As String,
                                           ByVal logoFileName As String, ByVal phone As String, ByVal email As String,
                                           ByVal facebookRaw As String, ByVal legal As StorefrontCompanyLegalProfile,
                                           ByVal payments As IList(Of StorefrontPaymentMethod), ByVal year As Integer) As FooterData
        Dim data As New FooterData()
        If IsFooterTenantAllowed(hostCompanyId, sessionCompanyId) Then
            data.CompanyName = If(companyName, String.Empty).Trim()
            data.LogoFileName = If(logoFileName, String.Empty).Trim()
            data.ContactsHtml = BuildFooterContactsHtml(data.CompanyName, phone, email)
            data.FacebookUrl = ResolveFooterFacebookUrl(hostCompanyId, sessionCompanyId, facebookRaw)
            ' i dati societari si mostrano solo se il profilo e della stessa azienda dell'host
            If legal IsNot Nothing AndAlso legal.CompanyId = hostCompanyId Then data.LegalHtml = BuildFooterLegalHtml(legal)
            data.PaymentsHtml = BuildFooterPaymentsHtml(payments, hostCompanyId)
        Else
            data.ContactsHtml = BuildFooterContactsHtml(String.Empty, String.Empty, String.Empty)
        End If
        data.CopyrightHtml = BuildCopyrightHtml(year, data.CompanyName)
        Return data
    End Function

    ' Il link di Facebook: https, uno dei soli host facebook.com, www., m. o fb.com (mai un sottodominio qualsiasi: l.facebook.com e un redirector), e solo se la sessione appartiene all'azienda dell'host.
    Friend Shared Function ResolveFooterFacebookUrl(ByVal tenantCompanyId As Integer, ByVal sessionCompanyId As Integer, ByVal raw As String) As String
        If tenantCompanyId <= 0 OrElse sessionCompanyId <> tenantCompanyId Then Return String.Empty
        Dim value As String = If(raw, String.Empty).Trim()
        If value.Length = 0 OrElse value.Length > 300 Then Return String.Empty
        For Each c As Char In value
            If c <= " "c OrElse c = """"c OrElse c = "<"c OrElse c = ">"c OrElse c = "'"c OrElse c = "\"c OrElse c > "~"c Then Return String.Empty
        Next
        Dim target As Uri = Nothing
        If Not Uri.TryCreate(value, UriKind.Absolute, target) OrElse target Is Nothing Then Return String.Empty
        If Not String.Equals(target.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) Then Return String.Empty
        If target.UserInfo.Length > 0 OrElse Not target.IsDefaultPort Then Return String.Empty
        Dim host As String = target.Host.ToLowerInvariant()
        If host = "facebook.com" OrElse host = "www.facebook.com" OrElse host = "m.facebook.com" OrElse host = "fb.com" OrElse host = "www.fb.com" Then Return value
        Return String.Empty
    End Function

    Friend Shared Function BuildCopyrightHtml(ByVal year As Integer, ByVal companyName As String) As String
        Dim name As String = If(companyName, String.Empty).Trim()
        Dim text As String = "&copy; " & year.ToString(CultureInfo.InvariantCulture)
        If name.Length > 0 Then text &= " " & HttpUtility.HtmlEncode(name)
        Return text
    End Function

    ' Elenco dei contatti dell'azienda: ogni voce compare solo se il dato esiste; il collegamento solo se il dato e valido (altrimenti resta il testo
    ' dell'azienda, codificato). Sempre presente: "Scrivici".
    Friend Shared Function BuildFooterContactsHtml(ByVal companyName As String, ByVal phone As String, ByVal email As String) As String
        Dim sb As New StringBuilder()
        Dim name As String = If(companyName, String.Empty).Trim()
        If name.Length > 0 Then
            sb.Append("<li><span class=""product-title"">").Append(HttpUtility.HtmlEncode(name)).Append("</span></li>")
        End If

        Dim phoneText As String = If(phone, String.Empty).Trim()
        If phoneText.Length > 0 Then
            Dim telHref As String = KeepStoreContactLinks.BuildTelHref(phoneText)
            If telHref.Length > 0 Then
                sb.Append("<li><a class=""link"" href=""").Append(HttpUtility.HtmlAttributeEncode(telHref)).Append(""">").Append(HttpUtility.HtmlEncode(phoneText)).Append("</a></li>")
            Else
                sb.Append("<li><span>").Append(HttpUtility.HtmlEncode(phoneText)).Append("</span></li>")
            End If
        End If

        Dim emailText As String = If(email, String.Empty).Trim()
        If emailText.Length > 0 Then
            Dim mailHref As String = KeepStoreContactLinks.BuildMailtoHref(emailText)
            If mailHref.Length > 0 Then
                sb.Append("<li><a class=""link"" href=""").Append(HttpUtility.HtmlAttributeEncode(mailHref)).Append(""">").Append(HttpUtility.HtmlEncode(emailText)).Append("</a></li>")
            Else
                sb.Append("<li><span>").Append(HttpUtility.HtmlEncode(emailText)).Append("</span></li>")
            End If
        End If

        sb.Append("<li><a class=""link"" href=""Contattaci.aspx"">Scrivici</a></li>")
        Return sb.ToString()
    End Function

    ' Catalogo: solo link nella forma esatta prodotta dal provider (articoli.aspx?st=NUMERO); testo codificato; al massimo maxItems voci.
    Friend Shared Function BuildFooterCategoriesHtml(ByVal items As IList(Of KeyValuePair(Of String, String)), ByVal maxItems As Integer) As String
        If items Is Nothing OrElse maxItems <= 0 Then Return String.Empty
        Dim sb As New StringBuilder()
        Dim count As Integer = 0
        For Each item As KeyValuePair(Of String, String) In items
            If count >= maxItems Then Exit For
            Dim text As String = If(item.Key, String.Empty).Trim()
            Dim url As String = If(item.Value, String.Empty)
            If text.Length = 0 OrElse Not CategoryUrlPattern.IsMatch(url) Then Continue For
            sb.Append("<li><a class=""link"" href=""").Append(HttpUtility.HtmlAttributeEncode(url)).Append(""">").Append(HttpUtility.HtmlEncode(text)).Append("</a></li>")
            count += 1
        Next
        Return sb.ToString()
    End Function

    ' Testo dei dati societari: caratteri di formato tolti, spazi e caratteri di controllo ridotti a un solo spazio; Nothing diventa vuoto.
    Friend Shared Function CleanLegalText(ByVal value As String) As String
        If value Is Nothing Then Return String.Empty
        Return LegalSpaces.Replace(LegalFormatChars.Replace(value, String.Empty), " ").Trim()
    End Function

    ' Partita IVA: eventuale prefisso di due lettere e da 5 a 14 cifre (separatori spazio . - ignorati), con almeno una cifra diversa da zero.
    ' Il controllo e sintattico: non prova che il numero sia vero; qualunque testo libero (es. "DA COMUNICARE") si omette.
    Friend Shared Function NormalizeVatNumber(ByVal value As String) As String
        Dim raw As String = CleanLegalText(value)
        If raw.Length = 0 OrElse raw.Length > 30 Then Return String.Empty
        Dim sb As New StringBuilder()
        Dim nonZeroDigit As Boolean = False
        For Each c As Char In raw
            If c = " "c OrElse c = "."c OrElse c = "-"c Then
                ' separatore ignorato
            ElseIf c >= "0"c AndAlso c <= "9"c Then
                sb.Append(c)
                If c <> "0"c Then nonZeroDigit = True
            ElseIf (c >= "A"c AndAlso c <= "Z"c) OrElse (c >= "a"c AndAlso c <= "z"c) Then
                sb.Append(Char.ToUpperInvariant(c))
            Else
                Return String.Empty
            End If
        Next
        Dim vat As String = sb.ToString()
        If Not nonZeroDigit OrElse Not VatPattern.IsMatch(vat) Then Return String.Empty
        Return vat
    End Function

    ' CAP: solo cinque cifre, non tutte zero (altrimenti si omette).
    Friend Shared Function NormalizePostalCode(ByVal value As String) As String
        Dim raw As String = CleanLegalText(value)
        If Not PostalPattern.IsMatch(raw) OrElse raw = "00000" Then Return String.Empty
        Return raw
    End Function

    ' Provincia: solo due lettere, in maiuscolo.
    Friend Shared Function NormalizeProvince(ByVal value As String) As String
        Dim raw As String = CleanLegalText(value)
        If Not ProvincePattern.IsMatch(raw) Then Return String.Empty
        Return raw.ToUpperInvariant()
    End Function

    ' Via: almeno una lettera, senza virgole, punti e punti e virgola finali.
    Friend Shared Function NormalizeStreet(ByVal value As String) As String
        Dim raw As String = CleanLegalText(value).TrimEnd(New Char() {" "c, ","c, ";"c, "."c})
        If Not LegalLetter.IsMatch(raw) Then Return String.Empty
        Return raw
    End Function

    ' Citta: almeno una lettera.
    Friend Shared Function NormalizeCity(ByVal value As String) As String
        Dim raw As String = CleanLegalText(value)
        If Not LegalLetter.IsMatch(raw) Then Return String.Empty
        Return raw
    End Function

    ' Un indirizzo esiste solo con via E citta; CAP e provincia si aggiungono se validi. Mai una riga a meta.
    Friend Shared Function BuildLegalAddressLine(ByVal street As String, ByVal postalCode As String, ByVal city As String, ByVal province As String) As String
        Dim streetText As String = NormalizeStreet(street)
        Dim cityText As String = NormalizeCity(city)
        If streetText.Length = 0 OrElse cityText.Length = 0 Then Return String.Empty
        Dim line As String = streetText & ", " & (NormalizePostalCode(postalCode) & " " & cityText).Trim()
        Dim prov As String = NormalizeProvince(province)
        If prov.Length > 0 Then line &= " (" & prov & ")"
        Return line
    End Function

    ' Due sedi sono la stessa solo se via, CAP, citta e provincia coincidono, campo per campo (confronto ordinale senza maiuscole).
    Friend Shared Function IsSameLegalPlace(ByVal street1 As String, ByVal postal1 As String, ByVal city1 As String, ByVal province1 As String,
                                            ByVal street2 As String, ByVal postal2 As String, ByVal city2 As String, ByVal province2 As String) As Boolean
        Return String.Equals(NormalizeStreet(street1), NormalizeStreet(street2), StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(NormalizePostalCode(postal1), NormalizePostalCode(postal2), StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(NormalizeCity(city1), NormalizeCity(city2), StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(NormalizeProvince(province1), NormalizeProvince(province2), StringComparison.OrdinalIgnoreCase)
    End Function

    ' Righe dei dati societari (testo codificato per pezzo, righe separate da <br />). Ogni parte compare solo se il dato esiste e ha la forma attesa.
    Friend Shared Function BuildFooterLegalHtml(ByVal legal As StorefrontCompanyLegalProfile) As String
        If legal Is Nothing Then Return String.Empty
        Dim lines As New List(Of String)()

        Dim head As String = HttpUtility.HtmlEncode(CleanLegalText(legal.LegalName))
        Dim vat As String = NormalizeVatNumber(legal.VatNumber)
        If vat.Length > 0 Then
            If head.Length > 0 Then head &= " - "
            head &= "P.IVA " & HttpUtility.HtmlEncode(vat)
        End If
        If head.Length > 0 Then lines.Add(head)

        Dim registered As String = BuildLegalAddressLine(legal.RegisteredAddress, legal.RegisteredPostalCode, legal.RegisteredCity, legal.RegisteredProvince)
        Dim operational As String = BuildLegalAddressLine(legal.OperationalAddress, legal.OperationalPostalCode, legal.OperationalCity, legal.OperationalProvince)
        If registered.Length > 0 AndAlso operational.Length > 0 Then
            If IsSameLegalPlace(legal.RegisteredAddress, legal.RegisteredPostalCode, legal.RegisteredCity, legal.RegisteredProvince,
                                legal.OperationalAddress, legal.OperationalPostalCode, legal.OperationalCity, legal.OperationalProvince) Then
                lines.Add("Sede legale e operativa: " & HttpUtility.HtmlEncode(registered))
            Else
                lines.Add("Sede legale: " & HttpUtility.HtmlEncode(registered))
                lines.Add("Sede operativa: " & HttpUtility.HtmlEncode(operational))
            End If
        ElseIf registered.Length > 0 Then
            lines.Add("Sede legale: " & HttpUtility.HtmlEncode(registered))
        ElseIf operational.Length > 0 Then
            lines.Add("Sede: " & HttpUtility.HtmlEncode(operational))
        End If
        Return String.Join("<br />", lines.ToArray())
    End Function

    Private Const PaymentMax As Integer = 8
    Private Const PaymentNameMax As Integer = 40
    Private Const PaymentDigitsMax As Integer = 5

    ' Metodi di pagamento: solo quelli dell'azienda dell'host, testo ripulito come i dati societari, scartati (mai troncati) i nomi che potrebbero portare dati personali o di conto
    ' (sei o piu cifre, @, indirizzi web) o piu lunghi del limite, senza duplicati (senza maiuscole), al massimo PaymentMax dopo pulizia e scarti, nell'ordine ricevuto (la policy li
    ' ordina). Vuoto = nessun blocco nel piede. Il testo e del cliente: sempre codificato.
    Friend Shared Function BuildFooterPaymentsHtml(ByVal methods As IList(Of StorefrontPaymentMethod), ByVal hostCompanyId As Integer) As String
        If methods Is Nothing OrElse hostCompanyId <= 0 Then Return String.Empty
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim names As New List(Of String)()
        For Each method As StorefrontPaymentMethod In methods
            If names.Count >= PaymentMax Then Exit For
            If method Is Nothing Then Continue For
            If method.CompanyId <> hostCompanyId Then Continue For
            Dim name As String = CleanPaymentName(method.Name)
            If name.Length = 0 OrElse Not seen.Add(name) Then Continue For
            names.Add(HttpUtility.HtmlEncode(name))
        Next
        Return String.Join(", ", names.ToArray())
    End Function

    ' Nome pulito di un metodo di pagamento, oppure vuoto se non si puo mostrare. Si tolgono solo spazi e trattini (anche en e em dash) iniziali e finali: la convenzione
    ' osservata nei dati di un'azienda ("-Bonifico Bancario"); ogni altra punteggiatura resta.
    Friend Shared Function CleanPaymentName(ByVal value As String) As String
        Dim trimChars As Char() = New Char() {" "c, "-"c, ChrW(8211), ChrW(8212)}
        Dim name As String = CleanLegalText(value).Trim(trimChars)
        If name.Length = 0 OrElse name.Length > PaymentNameMax Then Return String.Empty
        If name.IndexOf("@"c) >= 0 OrElse name.IndexOf("://", StringComparison.Ordinal) >= 0 OrElse name.IndexOf("www.", StringComparison.OrdinalIgnoreCase) >= 0 Then Return String.Empty
        Dim digits As Integer = 0
        For Each c As Char In name
            If c >= "0"c AndAlso c <= "9"c Then digits += 1
        Next
        If digits > PaymentDigitsMax Then Return String.Empty
        Return name
    End Function

    Friend Shared Function FooterGridClass(ByVal visibleColumns As Integer) As String
        Return "ft-link-wrap w-100 tf-grid-layout md-col-2 lg-col-" & If(visibleColumns >= 4, "4", "3")
    End Function
#End Region

    Private Function BuildLogoAssetUrlFromFileName(ByVal rawFileName As String) As String
        Dim fileName As String = SafeLogoFileName(rawFileName)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return String.Empty
        End If

        Return "/Public/assets/images/logo/" & fileName
    End Function

    Private Function SafeLogoFileName(ByVal rawFileName As String) As String
        Dim value As String = If(rawFileName, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(value) Then
            Return String.Empty
        End If
        If value.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           value.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
           value.StartsWith("//", StringComparison.OrdinalIgnoreCase) OrElse
           value.StartsWith("data:", StringComparison.OrdinalIgnoreCase) OrElse
           value.Contains("/") OrElse
           value.Contains("\") Then
            Return String.Empty
        End If

        Dim fileName As String = Path.GetFileName(value)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return String.Empty
        End If
        If fileName.Contains("..") OrElse fileName.Contains("/") OrElse fileName.Contains("\") Then
            Return String.Empty
        End If

        Return fileName
    End Function

    Private Function LogoUrlExists(ByVal url As String) As Boolean
        If String.IsNullOrWhiteSpace(url) OrElse url.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then
            Return True
        End If

        Try
            Dim pathOnly As String = url
            Dim queryIndex As Integer = pathOnly.IndexOf("?"c)
            If queryIndex >= 0 Then
                pathOnly = pathOnly.Substring(0, queryIndex)
            End If
            If pathOnly.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
                pathOnly = ResolveUrl(pathOnly)
            End If

            Dim physical As String = HostingEnvironment.MapPath(pathOnly)
            Return Not String.IsNullOrWhiteSpace(physical) AndAlso File.Exists(physical)
        Catch
            Return False
        End Try
    End Function
End Class
