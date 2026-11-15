Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Hosting

' Piede del sito. I dati dell'azienda (nome, logo, telefono, e-mail) arrivano SOLO dall'identita dell'host gia in cache
' (StorefrontSeoTenantContext): nessuna connessione al database e nessun ripiego sull'azienda della sessione. Senza identita valida
' (host sconosciuto, o sessione di un'altra azienda) il piede mostra solo il logo neutro, i link fissi e "Scrivici". Cio che manca si omette:
' mai un valore inventato.
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
        If tenant IsNot Nothing Then
            hostCompanyId = tenant.CompanyId
            companyName = tenant.CompanyName
            logoFileName = tenant.LogoFileName
            phone = tenant.SupportPhone
            email = tenant.SupportEmail
        End If

        ' Il link di Facebook vive nella sessione, scritta con l'azienda dell'host nella stessa lettura: BuildFooterData lo usa solo se coincidono.
        Dim facebookRaw As String = If(Session Is Nothing, String.Empty, Convert.ToString(Session("facebookLink")))
        Dim data As FooterData = BuildFooterData(hostCompanyId, SessionCompanyId(), companyName, logoFileName, phone, email, facebookRaw, DateTime.Now.Year)

        BindFooterLogo(data)
        BindFooterColumns()
        BindFooterSocial(data)
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

#Region "FooterPure"
    ' Funzioni pure (nessun accesso a sessione, database o richiesta): provate compilando questo stesso testo (Tools/Test-FooterTruth.ps1).
    Private Shared ReadOnly MailPattern As New Regex("^[A-Za-z0-9](?:[A-Za-z0-9._+\-]{0,62}[A-Za-z0-9])?@(?:[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,24}\z", RegexOptions.CultureInvariant)
    Private Shared ReadOnly CategoryUrlPattern As New Regex("^articoli\.aspx\?st=[0-9]{1,9}\z", RegexOptions.CultureInvariant)

    Friend NotInheritable Class FooterData
        Public LogoFileName As String = String.Empty
        Public CompanyName As String = String.Empty
        Public ContactsHtml As String = String.Empty
        Public CopyrightHtml As String = String.Empty
        Public FacebookUrl As String = String.Empty
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
                                           ByVal facebookRaw As String, ByVal year As Integer) As FooterData
        Dim data As New FooterData()
        If IsFooterTenantAllowed(hostCompanyId, sessionCompanyId) Then
            data.CompanyName = If(companyName, String.Empty).Trim()
            data.LogoFileName = If(logoFileName, String.Empty).Trim()
            data.ContactsHtml = BuildFooterContactsHtml(data.CompanyName, phone, email)
            data.FacebookUrl = ResolveFooterFacebookUrl(hostCompanyId, sessionCompanyId, facebookRaw)
        Else
            data.ContactsHtml = BuildFooterContactsHtml(String.Empty, String.Empty, String.Empty)
        End If
        data.CopyrightHtml = BuildCopyrightHtml(year, data.CompanyName)
        Return data
    End Function

    ' Solo cifre ASCII, separatori usuali (spazio . - parentesi) e un "+" iniziale; da 6 a 15 cifre, non tutte zero.
    ' Tutto il resto ("dalle 9 alle 18", due numeri separati da "/", lettere, cifre Unicode) non diventa mai un attributo href.
    Friend Shared Function BuildTelHref(ByVal phone As String) As String
        Dim raw As String = If(phone, String.Empty).Trim()
        If raw.Length = 0 OrElse raw.Length > 40 Then Return String.Empty
        If raw.StartsWith("+", StringComparison.Ordinal) AndAlso raw.Contains("(0)") Then Return String.Empty
        Dim digits As New StringBuilder()
        Dim nonZero As Boolean = False
        For i As Integer = 0 To raw.Length - 1
            Dim c As Char = raw(i)
            If c >= "0"c AndAlso c <= "9"c Then
                digits.Append(c)
                If c <> "0"c Then nonZero = True
            ElseIf c = "+"c Then
                If i <> 0 Then Return String.Empty
                digits.Append(c)
            ElseIf c = " "c OrElse c = "."c OrElse c = "-"c OrElse c = "("c OrElse c = ")"c Then
                ' separatore ignorato
            Else
                Return String.Empty
            End If
        Next
        Dim number As String = digits.ToString()
        Dim count As Integer = number.Length - If(number.StartsWith("+", StringComparison.Ordinal), 1, 0)
        If count < 6 OrElse count > 15 OrElse Not nonZero Then Return String.Empty
        Return "tel:" & number
    End Function

    ' Un solo indirizzo semplice (niente parametri, elenchi, spazi, a capo, percentuali, cancelletti, punti consecutivi).
    Friend Shared Function BuildMailtoHref(ByVal email As String) As String
        Dim raw As String = If(email, String.Empty).Trim()
        If raw.Length = 0 OrElse raw.Length > 254 Then Return String.Empty
        If Not MailPattern.IsMatch(raw) Then Return String.Empty
        If raw.Contains("..") Then Return String.Empty
        Return "mailto:" & raw
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
            Dim telHref As String = BuildTelHref(phoneText)
            If telHref.Length > 0 Then
                sb.Append("<li><a class=""link"" href=""").Append(HttpUtility.HtmlAttributeEncode(telHref)).Append(""">").Append(HttpUtility.HtmlEncode(phoneText)).Append("</a></li>")
            Else
                sb.Append("<li><span>").Append(HttpUtility.HtmlEncode(phoneText)).Append("</span></li>")
            End If
        End If

        Dim emailText As String = If(email, String.Empty).Trim()
        If emailText.Length > 0 Then
            Dim mailHref As String = BuildMailtoHref(emailText)
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
