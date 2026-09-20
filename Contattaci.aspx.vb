Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Web
Imports MySql.Data.MySqlClient

Partial Class Contattaci
    Inherits System.Web.UI.Page

    Private Function S(ByVal key As String) As String
        Dim o As Object = Session(key)
        If o Is Nothing Then Return ""
        Return Convert.ToString(o)
    End Function

    Private Shared Function TrimToLen(ByVal value As String, ByVal maxLen As Integer) As String
        If value Is Nothing Then Return ""
        Dim s As String = value.Trim()
        If s.Length > maxLen Then s = s.Substring(0, maxLen)
        Return s
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Not IsPostBack Then
            Me.Title = "Contattaci"
            LoadCompanyInfo()
            ApplySeoBasics()
        End If
    End Sub

    Private Sub ApplySeoBasics()
        Try
            Dim canonical As String = StorefrontSeoTenantContext.BuildCanonicalUrl(HttpContext.Current, "/Contattaci.aspx")
            SeoBuilder.SetCanonical(Me, canonical)

            Dim azi As String = S("AziendaNome")
            If azi <> "" Then
                SeoBuilder.AddOrReplaceNameMeta(Me, "description", "Contatta " & azi & " per informazioni, preventivi e assistenza.")
            End If
        Catch
            ' fail-open
        End Try
    End Sub

    Private Sub LoadCompanyInfo()
        Dim ragione As String = S("AziendaNome")
        Dim indirizzo As String = ""
        Dim cap As String = ""
        Dim citta As String = ""
        Dim prov As String = ""
        Dim telefono As String = ""
        Dim email As String = S("AziendaEmail")

        Try
            Dim idAzienda As Integer
            If Integer.TryParse(S("AziendaID"), idAzienda) AndAlso idAzienda > 0 Then
                Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                Using cn As New MySqlConnection(cs)
                    cn.Open()
                    Using cmd As New MySqlCommand("SELECT RagioneSociale, Indirizzo, Cap, Citta, provincia, Telefono, Email FROM aziende WHERE Id=@id LIMIT 1", cn)
                        cmd.Parameters.AddWithValue("@id", idAzienda)
                        Using dr As MySqlDataReader = cmd.ExecuteReader()
                            If dr.Read() Then
                                ragione = Convert.ToString(dr("RagioneSociale"))
                                indirizzo = Convert.ToString(dr("Indirizzo"))
                                cap = Convert.ToString(dr("Cap"))
                                citta = Convert.ToString(dr("Citta"))
                                prov = Convert.ToString(dr("provincia"))
                                telefono = Convert.ToString(dr("Telefono"))
                                email = Convert.ToString(dr("Email"))
                            End If
                        End Using
                    End Using
                End Using
            End If
        Catch ex As Exception
            KeepStoreLog.Error("contattaci", "Errore caricamento dati azienda", ex, HttpContext.Current)
        End Try

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

        litAddress.Text = htmlAddress
        litPhone.Text = HttpUtility.HtmlEncode(If(String.IsNullOrWhiteSpace(telefono), "-", telefono))
        litEmail.Text = HttpUtility.HtmlEncode(If(String.IsNullOrWhiteSpace(email), "-", email))

        Try
            Dim addrForMap As String = (indirizzo & " " & cap & " " & citta & " " & prov).Trim()
            If addrForMap = "" Then addrForMap = ragione

            Dim mapQ As String = HttpUtility.UrlEncode(addrForMap)
            Dim mapUrl As String = "https://www.google.com/maps?q=" & mapQ
            Dim mapEmbed As String = "https://www.google.com/maps?q=" & mapQ & "&output=embed"

            lnkMap.HRef = mapUrl
            iframeMap.Attributes("src") = mapEmbed

            Dim telClean As String = telefono.Trim().Replace(" ", "").Replace(".", "").Replace("-", "")
            If telClean <> "" Then
                lnkPhone.HRef = "tel:" & telClean
            Else
                lnkPhone.HRef = mapUrl
            End If

            If email.Trim() <> "" AndAlso email <> "-" Then
                lnkEmail.HRef = "mailto:" & email.Trim()
            Else
                lnkEmail.HRef = mapUrl
            End If
        Catch
            ' fail-open
        End Try
    End Sub

    Protected Sub btnInvia_Click(ByVal sender As Object, ByVal e As EventArgs)
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

        Dim aziendaNome As String = S("AziendaNome")
        Dim aziendaEmail As String = S("AziendaEmail")
        If aziendaEmail = "" Then
            ShowAlert("In questo momento non è possibile inviare il messaggio. Contattaci via email/telefono indicati a destra.", True)
            Return
        End If

        Try
            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
            If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then
                ShowAlert("In questo momento non è possibile inviare il messaggio. Riprova più tardi o contattaci via email/telefono.", True)
                Return
            End If
            Dim aziendaId As Integer = tenant.CompanyId
            Dim rendered As KeepStoreEmailRenderResult = RenderContactEmail(aziendaNome, aziendaEmail, nome, fromEmailUser, oggetto, messaggio)
            Dim deliveryRequest As New TenantEmailDeliveryRequest() With {
                .AziendaId = aziendaId,
                .CorrelationId = "contact-" & Guid.NewGuid().ToString("N"),
                .Classification = TenantEmailMessageClassifications.ContactRequest,
                .Subject = "[Contatto sito] " & oggetto,
                .HtmlBody = rendered.HtmlBody,
                .PlainTextBody = rendered.PlainTextBody
            }
            deliveryRequest.ToRecipients.Add(New TenantEmailRecipient() With {.Address = aziendaEmail, .DisplayName = aziendaNome})
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

    Private Function RenderContactEmail(ByVal aziendaNome As String,
                                        ByVal aziendaEmail As String,
                                        ByVal nome As String,
                                        ByVal fromEmailUser As String,
                                        ByVal oggetto As String,
                                        ByVal messaggio As String) As KeepStoreEmailRenderResult
        Dim brand As New KeepStoreEmailBrandInfo()
        brand.CompanyName = aziendaNome
        brand.SupportEmail = aziendaEmail
        brand.SiteUrl = BuildSiteHomeUrl()
        brand.LogoWeb = KeepStoreEmailLogo.SafeLogoFileName(S("AziendaLogo"))

        Return KeepStoreContactEmailMessages.RenderContactRequest(brand, nome, fromEmailUser, oggetto, messaggio)
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
