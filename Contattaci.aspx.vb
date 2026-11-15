Option Strict On
Option Explicit On

Imports System
Imports System.Web

' Pagina Contattaci. I dati dell'azienda (nome, telefono, e-mail, logo, indirizzo) arrivano SOLO dall'identita dell'host gia in cache
' (StorefrontSeoTenantContext): nessuna lettura di sessione e nessuna connessione al database. Il profilo legale si usa solo se porta lo
' stesso CompanyId dell'host. Cio che manca si omette o resta "-": mai un valore inventato.
Partial Class Contattaci
    Inherits System.Web.UI.Page

    ' A ogni richiesta, anche sui POST: i dati si rileggono dall'identita dell'host e non dipendono dal ViewState della prima visita.
    ' Il master risponde 421 a un host non configurato: in quel caso niente dati e niente invii.
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Response.StatusCode = 421 Then Return
        Me.Title = "Contattaci"
        Dim tenant As StorefrontSeoTenantIdentity = ResolveContactTenant()
        LoadCompanyInfo(tenant)
        ApplySeoBasics(tenant)
    End Sub

    Private Function ResolveContactTenant() As StorefrontSeoTenantIdentity
        Try
            Return StorefrontSeoTenantContext.Resolve(HttpContext.Current)
        Catch
            Return Nothing
        End Try
    End Function

    Private Sub ApplySeoBasics(ByVal tenant As StorefrontSeoTenantIdentity)
        Try
            Dim canonical As String = StorefrontSeoTenantContext.BuildCanonicalUrl(HttpContext.Current, "/Contattaci.aspx")
            SeoBuilder.SetCanonical(Me, canonical)

            If tenant IsNot Nothing AndAlso tenant.CompanyId > 0 AndAlso Not String.IsNullOrWhiteSpace(tenant.CompanyName) Then
                SeoBuilder.AddOrReplaceNameMeta(Me, "description", "Contatta " & tenant.CompanyName.Trim() & " per informazioni, preventivi e assistenza.")
            End If
        Catch
            ' fail-open
        End Try
    End Sub

    Private Sub LoadCompanyInfo(ByVal tenant As StorefrontSeoTenantIdentity)
        Dim view As ContactView = BuildContactView(tenant)
        Try
            litAddress.Text = view.AddressHtml
            litPhone.Text = view.PhoneHtml
            litEmail.Text = view.EmailHtml
            lnkMap.HRef = view.MapUrl
            iframeMap.Attributes("src") = view.MapEmbedUrl
            lnkPhone.HRef = view.TelHref
            lnkEmail.HRef = view.MailHref
        Catch
            ' fail-open
        End Try
    End Sub

#Region "ContactPure"
    ' Funzioni pure (nessun accesso a sessione, database o richiesta): provate compilando questo stesso testo (Tools/Test-ContactHostIdentity.ps1).
    Friend NotInheritable Class ContactView
        Public AddressHtml As String = String.Empty
        Public PhoneHtml As String = "-"
        Public EmailHtml As String = "-"
        Public MapUrl As String = String.Empty
        Public MapEmbedUrl As String = String.Empty
        Public TelHref As String = String.Empty
        Public MailHref As String = String.Empty
    End Class

    Friend Shared Function TrimToLen(ByVal value As String, ByVal maxLen As Integer) As String
        If value Is Nothing Then Return ""
        Dim s As String = value.Trim()
        If s.Length > maxLen Then s = s.Substring(0, maxLen)
        Return s
    End Function

    ' Stesso formato di prima (indirizzo, "-" per telefono ed e-mail vuoti, ripiego sulla ragione sociale, mappa, tel:/mailto:), ma con i dati
    ' dell'azienda dell'host. Senza identita con azienda valida la vista e neutra; il profilo legale vale solo se e della stessa azienda.
    ' Il collegamento "-" di un telefono o di un'e-mail vuoti punta alla mappa: difetto noto di sempre, conservato.
    Friend Shared Function BuildContactView(ByVal tenant As StorefrontSeoTenantIdentity) As ContactView
        Dim ragione As String = String.Empty
        Dim indirizzo As String = String.Empty
        Dim cap As String = String.Empty
        Dim citta As String = String.Empty
        Dim prov As String = String.Empty
        Dim telefono As String = String.Empty
        Dim mail As String = String.Empty

        If tenant IsNot Nothing AndAlso tenant.CompanyId > 0 Then
            ragione = If(tenant.CompanyName, String.Empty).Trim()
            telefono = If(tenant.SupportPhone, String.Empty).Trim()
            mail = If(tenant.SupportEmail, String.Empty).Trim()
            Dim legal As StorefrontCompanyLegalProfile = tenant.LegalProfile
            If legal IsNot Nothing AndAlso legal.CompanyId = tenant.CompanyId Then
                If legal.LegalName.Length > 0 Then ragione = legal.LegalName
                indirizzo = legal.OperationalAddress
                cap = legal.OperationalPostalCode
                citta = legal.OperationalCity
                prov = legal.OperationalProvince
            End If
        End If

        Dim line1 As String = TrimToLen(indirizzo, 200)
        Dim cityLine As String = (cap & " " & citta).Trim()
        If prov <> "" Then cityLine = (cityLine & " (" & prov & ")").Trim()

        Dim htmlAddress As String = ""
        If line1 <> "" Then htmlAddress = HttpUtility.HtmlEncode(line1)
        If cityLine <> "" Then
            If htmlAddress <> "" Then
                htmlAddress &= "<br />" & HttpUtility.HtmlEncode(cityLine)
            Else
                htmlAddress = HttpUtility.HtmlEncode(cityLine)
            End If
        End If
        If String.IsNullOrWhiteSpace(htmlAddress) Then htmlAddress = HttpUtility.HtmlEncode(ragione)

        Dim view As New ContactView()
        view.AddressHtml = htmlAddress
        view.PhoneHtml = HttpUtility.HtmlEncode(If(String.IsNullOrWhiteSpace(telefono), "-", telefono))
        view.EmailHtml = HttpUtility.HtmlEncode(If(String.IsNullOrWhiteSpace(mail), "-", mail))

        Dim addrForMap As String = (indirizzo & " " & cap & " " & citta & " " & prov).Trim()
        If addrForMap = "" Then addrForMap = ragione
        Dim mapQ As String = HttpUtility.UrlEncode(addrForMap)
        view.MapUrl = "https://www.google.com/maps?q=" & mapQ
        view.MapEmbedUrl = "https://www.google.com/maps?q=" & mapQ & "&output=embed"

        Dim telClean As String = telefono.Trim().Replace(" ", "").Replace(".", "").Replace("-", "")
        If telClean <> "" Then
            view.TelHref = "tel:" & telClean
        Else
            view.TelHref = view.MapUrl
        End If

        If mail.Trim() <> "" AndAlso mail <> "-" Then
            view.MailHref = "mailto:" & mail.Trim()
        Else
            view.MailHref = view.MapUrl
        End If
        Return view
    End Function

    ' Marchio dell'e-mail di contatto, tutto dall'identita dell'host. Il logo e il NOME FILE grezzo (LogoWeb): un percorso con "/" viene sempre
    ' rifiutato da SafeLogoFileName e darebbe il logo predefinito (difetto di prima, dalla sessione). Se il file non esiste sul server: predefinito.
    Friend Shared Function BuildContactBrand(ByVal tenant As StorefrontSeoTenantIdentity, ByVal siteUrl As String, ByVal logoExists As Boolean) As KeepStoreEmailBrandInfo
        Dim brand As New KeepStoreEmailBrandInfo()
        brand.CompanyName = tenant.CompanyName
        brand.SupportEmail = tenant.SupportEmail
        brand.SiteUrl = siteUrl
        brand.LogoWeb = If(logoExists, KeepStoreEmailLogo.SafeLogoFileName(tenant.LogoFileName), KeepStoreEmailLogo.SafeLogoFileName(String.Empty))
        Return brand
    End Function
#End Region

    Protected Sub btnInvia_Click(ByVal sender As Object, ByVal e As EventArgs)
        If Response.StatusCode = 421 Then Return
        pnlAlert.Visible = False
        lblAlert.Text = ""

        If Not Page.IsValid Then
            ShowAlert("Verifica i campi evidenziati.", True)
            Return
        End If

        Dim nome As String = TrimToLen(txtNome.Text, 120)
        Dim fromEmailUser As String = TrimToLen(txtEmail.Text, 180)
        Dim oggetto As String = TrimToLen(txtOggetto.Text, 150)
        Dim messaggio As String = TrimToLen(txtMessaggio.Text, 4000)

        If nome = "" OrElse fromEmailUser = "" OrElse oggetto = "" OrElse messaggio = "" Then
            ShowAlert("Compila tutti i campi obbligatori.", True)
            Return
        End If

        Try
            Dim tenant As StorefrontSeoTenantIdentity = ResolveContactTenant()
            If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then
                ShowAlert("In questo momento non è possibile inviare il messaggio. Riprova più tardi o contattaci via email/telefono.", True)
                Return
            End If
            Dim aziendaId As Integer = tenant.CompanyId
            Dim rendered As KeepStoreEmailRenderResult = RenderContactEmail(tenant, nome, fromEmailUser, oggetto, messaggio)
            Dim deliveryRequest As New TenantEmailDeliveryRequest() With {
                .AziendaId = aziendaId,
                .CorrelationId = "contact-" & Guid.NewGuid().ToString("N"),
                .Classification = TenantEmailMessageClassifications.ContactRequest,
                .Subject = "[Contatto sito] " & oggetto,
                .HtmlBody = rendered.HtmlBody,
                .PlainTextBody = rendered.PlainTextBody
            }
            deliveryRequest.ReplyToRecipients.Add(New TenantEmailRecipient() With {.Address = fromEmailUser, .DisplayName = nome})

            Dim deliveryResult As EmailDeliveryResult = New TenantEmailDeliveryService().Deliver(deliveryRequest)
            If deliveryResult Is Nothing OrElse deliveryResult.Status <> EmailTransportOperationStatus.Succeeded Then
                KeepStoreLog.Info("contattaci",
                                  "result=failed code=" & If(deliveryResult Is Nothing, "EMAIL_TRANSPORT_RESULT_NULL", deliveryResult.Code) &
                                  " correlation=" & deliveryRequest.CorrelationId,
                                  HttpContext.Current)
                ShowAlert("In questo momento non è possibile inviare il messaggio. Riprova più tardi o contattaci via email/telefono.", True)
                Return
            End If

            txtOggetto.Text = ""
            txtMessaggio.Text = ""
            ShowAlert("Messaggio inviato correttamente. Ti risponderemo il prima possibile.", False)

        Catch ex As Exception
            KeepStoreLog.Error("contattaci", "result=failed code=CONTACT_EMAIL_FAILURE type=" & ex.GetType().Name, Nothing, HttpContext.Current)
            ShowAlert("Errore durante l'invio del messaggio. Riprova più tardi o contattaci via email/telefono.", True)
        End Try
    End Sub

    Private Function RenderContactEmail(ByVal tenant As StorefrontSeoTenantIdentity,
                                        ByVal nome As String,
                                        ByVal fromEmailUser As String,
                                        ByVal oggetto As String,
                                        ByVal messaggio As String) As KeepStoreEmailRenderResult
        Dim brand As KeepStoreEmailBrandInfo = BuildContactBrand(tenant, BuildSiteHomeUrl(), EmailLogoFileExists(tenant))
        Return KeepStoreContactEmailMessages.RenderContactRequest(brand, nome, fromEmailUser, oggetto, messaggio)
    End Function

    ' Il file del logo deve esistere sul server (come controllano testata e piede): altrimenti l'e-mail avrebbe un'immagine rotta.
    Private Function EmailLogoFileExists(ByVal tenant As StorefrontSeoTenantIdentity) As Boolean
        Try
            Dim fileName As String = KeepStoreEmailLogo.SafeLogoFileName(tenant.LogoFileName)
            Dim physical As String = Server.MapPath("~" & KeepStoreEmailLogo.LogoBasePath & fileName)
            Return Not String.IsNullOrWhiteSpace(physical) AndAlso System.IO.File.Exists(physical)
        Catch
            Return False
        End Try
    End Function

    Private Function BuildSiteHomeUrl() As String
        Return StorefrontSeoTenantContext.BuildCanonicalUrl(HttpContext.Current, "/")
    End Function

    Private Sub ShowAlert(ByVal msg As String, ByVal isError As Boolean)
        pnlAlert.Visible = True
        pnlAlert.CssClass = If(isError, "alert alert-danger", "alert alert-success")
        lblAlert.Text = HttpUtility.HtmlEncode(msg)
    End Sub

End Class
