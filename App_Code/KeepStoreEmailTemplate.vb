Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Text
Imports System.Web

Public Class KeepStoreEmailBrandInfo
    Public Property CompanyName As String
    Public Property SupportEmail As String
    Public Property Phone As String
    Public Property SiteUrl As String
    Public Property LogoWeb As String
    Public Property Iban As String
    Public Property SwiftCode As String
    Public Property BankName As String
    Public Property Beneficiary As String
    Public Property AddressLine As String
    Public Property CityLine As String
    Public Property VatNumber As String
    Public Property FiscalCode As String
    Public Property Pec As String
    Public Property Sdi As String
End Class

Public Class KeepStoreEmailRecipientInfo
    Public Property DisplayName As String
    Public Property Email As String
End Class

Public Class KeepStoreEmailActionLink
    Public Property Text As String
    Public Property Url As String
End Class

Public Class KeepStoreEmailInfoItem
    Public Property Label As String
    Public Property Value As String
End Class

Public Class KeepStoreEmailInfoBlock
    Public Sub New()
        Items = New List(Of KeepStoreEmailInfoItem)()
    End Sub

    Public Property Title As String
    Public Property Body As String
    Public Property Items As List(Of KeepStoreEmailInfoItem)
End Class

Public Class KeepStoreEmailProductLine
    Public Property ImageUrl As String
    Public Property ImageAlt As String
    Public Property Code As String
    Public Property Ean As String
    Public Property Description As String
    Public Property Quantity As String
    Public Property UnitPrice As String
    Public Property LineTotal As String
End Class

Public Class KeepStoreEmailMessageModel
    Public Sub New()
        Brand = New KeepStoreEmailBrandInfo()
        Recipient = New KeepStoreEmailRecipientInfo()
        BodyLines = New List(Of String)()
        InfoBlocks = New List(Of KeepStoreEmailInfoBlock)()
        HighlightItems = New List(Of KeepStoreEmailInfoItem)()
        ProductLines = New List(Of KeepStoreEmailProductLine)()
    End Sub

    Public Property Brand As KeepStoreEmailBrandInfo
    Public Property Recipient As KeepStoreEmailRecipientInfo
    Public Property Preheader As String
    Public Property Title As String
    Public Property Intro As String
    Public Property BodyLines As List(Of String)
    Public Property StatusBadge As String
    Public Property HighlightItems As List(Of KeepStoreEmailInfoItem)
    Public Property ProductTableCaption As String
    Public Property ProductLines As List(Of KeepStoreEmailProductLine)
    Public Property InfoBlocks As List(Of KeepStoreEmailInfoBlock)
    Public Property ActionLink As KeepStoreEmailActionLink
    Public Property SecondaryActionLink As KeepStoreEmailActionLink
    Public Property ActionIntro As String
    Public Property LegalTitle As String
    Public Property LegalText As String
    Public Property FooterNote As String
End Class

Public Class KeepStoreEmailRenderResult
    Public Property HtmlBody As String
    Public Property PlainTextBody As String
End Class

Public NotInheritable Class KeepStoreEmailLogo
    Public Const LogoBasePath As String = "/Public/assets/images/logo/"
    Public Const DefaultLogoFile As String = "logo.svg"

    Private Sub New()
    End Sub

    Public Shared Function BuildLogoPath(ByVal logoWeb As String) As String
        Return LogoBasePath & SafeLogoFileName(logoWeb)
    End Function

    Public Shared Function BuildLogoUrl(ByVal siteUrl As String, ByVal logoWeb As String) As String
        Return CombineHttpsBaseUrl(siteUrl, BuildLogoPath(logoWeb))
    End Function

    Public Shared Function SafeLogoFileName(ByVal logoWeb As String) As String
        If String.IsNullOrWhiteSpace(logoWeb) Then
            Return DefaultLogoFile
        End If

        Dim raw As String = logoWeb.Trim()
        Dim lowered As String = raw.ToLowerInvariant()

        If lowered.StartsWith("http://") OrElse lowered.StartsWith("https://") OrElse lowered.StartsWith("//") Then
            Return DefaultLogoFile
        End If

        If lowered.Contains("../") OrElse lowered.Contains("..\") OrElse lowered.Contains("%2f") OrElse lowered.Contains("%5c") Then
            Return DefaultLogoFile
        End If

        If raw.IndexOfAny(New Char() {"/"c, "\"c, ":"c, "?"c, "#"c, "&"c}) >= 0 Then
            Return DefaultLogoFile
        End If

        Dim fileName As String = Path.GetFileName(raw)
        If String.IsNullOrWhiteSpace(fileName) OrElse Not String.Equals(fileName, raw, StringComparison.Ordinal) Then
            Return DefaultLogoFile
        End If

        Dim extension As String = Path.GetExtension(fileName).ToLowerInvariant()
        If extension <> ".svg" AndAlso extension <> ".png" AndAlso extension <> ".jpg" AndAlso extension <> ".jpeg" AndAlso extension <> ".gif" AndAlso extension <> ".webp" Then
            Return DefaultLogoFile
        End If

        For Each c As Char In fileName
            If Not (Char.IsLetterOrDigit(c) OrElse c = "."c OrElse c = "-"c OrElse c = "_"c) Then
                Return DefaultLogoFile
            End If
        Next

        Return fileName
    End Function

    Private Shared Function CombineHttpsBaseUrl(ByVal siteUrl As String, ByVal path As String) As String
        Dim baseUrl As String = If(siteUrl, "").Trim()
        If baseUrl = "" Then
            baseUrl = "https://www.taikun.it"
        End If

        If baseUrl.StartsWith("//", StringComparison.Ordinal) OrElse
           baseUrl.StartsWith("data:", StringComparison.OrdinalIgnoreCase) OrElse
           baseUrl.StartsWith("javascript:", StringComparison.OrdinalIgnoreCase) Then
            baseUrl = "https://www.taikun.it"
        End If

        If baseUrl.StartsWith("http://", StringComparison.OrdinalIgnoreCase) Then
            baseUrl = "https://" & baseUrl.Substring(7)
        ElseIf Not baseUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            baseUrl = "https://" & baseUrl
        End If

        Return baseUrl.TrimEnd("/"c) & "/" & If(path, "").TrimStart("/"c)
    End Function
End Class

Public NotInheritable Class KeepStoreEmailSubjects
    Private Sub New()
    End Sub

    Public Shared Function Registration(ByVal companyName As String) As String
        Return "Registrazione account " & Company(companyName)
    End Function

    Public Shared Function AccountProfileUpdated(ByVal companyName As String) As String
        Return "Aggiornamento dati account " & Company(companyName)
    End Function

    Public Shared Function PasswordReset(ByVal companyName As String) As String
        Return Company(companyName) & " - Reimposta la password"
    End Function

    Public Shared Function PasswordChanged(ByVal companyName As String) As String
        Return Company(companyName) & " - Password aggiornata"
    End Function

    Public Shared Function OrderConfirmation(ByVal companyName As String, ByVal orderNumber As String) As String
        Return Company(companyName) & " - Conferma ordine " & SafeSuffix(orderNumber)
    End Function

    Public Shared Function OrderConfirmation(ByVal companyName As String, ByVal orderNumber As String, ByVal documentDate As String) As String
        Return "Conferma ordine " & Company(companyName) & DocumentNumberDateSuffix(orderNumber, documentDate)
    End Function

    Public Shared Function OrderBankTransfer(ByVal companyName As String, ByVal orderNumber As String) As String
        Return Company(companyName) & " - Istruzioni bonifico ordine " & SafeSuffix(orderNumber)
    End Function

    Public Shared Function OrderBankTransfer(ByVal companyName As String, ByVal orderNumber As String, ByVal documentDate As String) As String
        Return "Ordine " & Company(companyName) & DocumentNumberDateSuffix(orderNumber, documentDate) & " in attesa di bonifico"
    End Function

    Public Shared Function QuoteConfirmation(ByVal companyName As String, ByVal documentNumber As String, ByVal documentDate As String) As String
        Return "Preventivo " & Company(companyName) & DocumentNumberDateSuffix(documentNumber, documentDate)
    End Function

    Public Shared Function OrderOnlinePayment(ByVal companyName As String, ByVal orderNumber As String) As String
        Return Company(companyName) & " - Pagamento ordine " & SafeSuffix(orderNumber)
    End Function

    Public Shared Function OrderCashOnDelivery(ByVal companyName As String, ByVal orderNumber As String) As String
        Return Company(companyName) & " - Contrassegno ordine " & SafeSuffix(orderNumber)
    End Function

    Public Shared Function OrderStatusUpdate(ByVal companyName As String, ByVal orderNumber As String) As String
        Return Company(companyName) & " - Aggiornamento ordine " & SafeSuffix(orderNumber)
    End Function

    Public Shared Function OrderShippingTracking(ByVal companyName As String, ByVal orderNumber As String) As String
        Return Company(companyName) & " - Spedizione ordine " & SafeSuffix(orderNumber)
    End Function

    Private Shared Function Company(ByVal companyName As String) As String
        If String.IsNullOrWhiteSpace(companyName) Then
            Return "KeepStore"
        End If

        Return companyName.Trim()
    End Function

    Private Shared Function SafeSuffix(ByVal value As String) As String
        If String.IsNullOrWhiteSpace(value) Then
            Return ""
        End If

        Return value.Trim()
    End Function

    Private Shared Function DocumentNumberDateSuffix(ByVal number As String, ByVal documentDate As String) As String
        Dim suffix As String = ""
        If Not String.IsNullOrWhiteSpace(number) Then
            suffix &= " n. " & number.Trim()
        End If
        If Not String.IsNullOrWhiteSpace(documentDate) Then
            suffix &= " del " & documentDate.Trim()
        End If
        Return suffix
    End Function
End Class

Public Class KeepStoreAccountEmailProfile
    Public Property DisplayName As String
    Public Property Username As String
    Public Property Email As String
    Public Property BillingName As String
    Public Property BillingCompany As String
    Public Property FiscalCode As String
    Public Property VatNumber As String
    Public Property BillingAddress As String
    Public Property BillingCityLine As String
    Public Property Phone As String
    Public Property MobilePhone As String
    Public Property ShippingName As String
    Public Property ShippingCompany As String
    Public Property ShippingAddress As String
    Public Property ShippingCityLine As String
    Public Property ShippingPhone As String
End Class

Public NotInheritable Class KeepStoreAccountEmailMessages
    Private Sub New()
    End Sub

    Public Shared Function RenderRegistration(ByVal brand As KeepStoreEmailBrandInfo,
                                              ByVal profile As KeepStoreAccountEmailProfile) As KeepStoreEmailRenderResult
        Return RenderAccountEmail(brand,
                                  profile,
                                  "Registrazione account completata",
                                  "Registrazione completata",
                                  "La registrazione al sito e stata completata.",
                                  "Di seguito trovi il riepilogo dei dati forniti. Puoi modificarli in seguito dalla tua area account.",
                                  "Questa email conferma la creazione dell'account e non contiene password.")
    End Function

    Public Shared Function RenderProfileUpdated(ByVal brand As KeepStoreEmailBrandInfo,
                                                ByVal profile As KeepStoreAccountEmailProfile) As KeepStoreEmailRenderResult
        Return RenderAccountEmail(brand,
                                  profile,
                                  "Dati account aggiornati",
                                  "Profilo aggiornato",
                                  "I dati del tuo account sono stati aggiornati.",
                                  "Di seguito trovi il riepilogo dei dati salvati. Puoi modificarli nuovamente dalla tua area account.",
                                  "Questa email conferma l'aggiornamento del profilo e non contiene password.")
    End Function

    Private Shared Function RenderAccountEmail(ByVal brand As KeepStoreEmailBrandInfo,
                                               ByVal profile As KeepStoreAccountEmailProfile,
                                               ByVal title As String,
                                               ByVal statusBadge As String,
                                               ByVal intro As String,
                                               ByVal bodyLine As String,
                                               ByVal footerNote As String) As KeepStoreEmailRenderResult
        If brand Is Nothing Then
            brand = New KeepStoreEmailBrandInfo()
        End If
        If profile Is Nothing Then
            profile = New KeepStoreAccountEmailProfile()
        End If

        Dim model As New KeepStoreEmailMessageModel()
        model.Brand = brand
        model.Recipient.DisplayName = profile.DisplayName
        model.Recipient.Email = profile.Email
        model.Title = title
        model.StatusBadge = statusBadge
        model.Preheader = title
        model.Intro = "Gentile " & FirstNonEmpty(profile.DisplayName, "cliente") & ", " & intro
        model.BodyLines.Add(bodyLine)
        model.FooterNote = footerNote

        Dim accessBlock As New KeepStoreEmailInfoBlock()
        accessBlock.Title = "Dati accesso"
        AddInfoItem(accessBlock, "Username", profile.Username)
        AddInfoItem(accessBlock, "Email", profile.Email)
        model.InfoBlocks.Add(accessBlock)

        Dim billingBlock As New KeepStoreEmailInfoBlock()
        billingBlock.Title = "Dati fatturazione"
        AddInfoItem(billingBlock, "Nome", profile.BillingName)
        AddInfoItem(billingBlock, "Cognome/Ragione sociale", profile.BillingCompany)
        AddInfoItem(billingBlock, "Codice fiscale", profile.FiscalCode)
        AddInfoItem(billingBlock, "Partita IVA", profile.VatNumber)
        AddInfoItem(billingBlock, "Indirizzo", profile.BillingAddress)
        AddInfoItem(billingBlock, "Localita", profile.BillingCityLine)
        AddInfoItem(billingBlock, "Telefono", profile.Phone)
        AddInfoItem(billingBlock, "Cellulare", profile.MobilePhone)
        model.InfoBlocks.Add(billingBlock)

        Dim shippingBlock As New KeepStoreEmailInfoBlock()
        shippingBlock.Title = "Dati spedizione"
        AddInfoItem(shippingBlock, "Nome", profile.ShippingName)
        AddInfoItem(shippingBlock, "Cognome/Ragione sociale", profile.ShippingCompany)
        AddInfoItem(shippingBlock, "Indirizzo", profile.ShippingAddress)
        AddInfoItem(shippingBlock, "Localita", profile.ShippingCityLine)
        AddInfoItem(shippingBlock, "Telefono", profile.ShippingPhone)
        model.InfoBlocks.Add(shippingBlock)

        model.LegalTitle = "Comunicazione di servizio"
        model.LegalText = "La comunicazione e destinata al titolare dell'account. Se hai ricevuto questa email per errore, contatta l'assistenza senza inoltrare dati sensibili."

        Return KeepStoreEmailRenderer.Render(model)
    End Function

    Private Shared Sub AddInfoItem(ByVal block As KeepStoreEmailInfoBlock, ByVal label As String, ByVal value As String)
        If block Is Nothing OrElse String.IsNullOrWhiteSpace(value) Then
            Return
        End If

        Dim item As New KeepStoreEmailInfoItem()
        item.Label = label
        item.Value = value.Trim()
        block.Items.Add(item)
    End Sub

    Private Shared Function FirstNonEmpty(ParamArray values() As String) As String
        If values Is Nothing Then
            Return ""
        End If

        For Each value As String In values
            If Not String.IsNullOrWhiteSpace(value) Then
                Return value.Trim()
            End If
        Next

        Return ""
    End Function
End Class

Public Class KeepStoreEmailPaymentInfo
    Public Property Description As String
    Public Property Information As String
    Public Property IsBankTransfer As Boolean
    Public Property IsCashOnDelivery As Boolean
    Public Property IsOnline As Boolean
    Public Property IsGatewayConfirmed As Boolean
    Public Property OrderNumber As String
    Public Property Iban As String
    Public Property SwiftCode As String
    Public Property BankName As String
    Public Property Beneficiary As String
    Public Property AmountDue As String
    Public Property RecommendedCause As String
End Class

Public Class KeepStoreEmailShippingInfo
    Public Property CarrierName As String
    Public Property MethodDescription As String
    Public Property TrackingCode As String
    Public Property TrackingUrl As String
End Class

Public NotInheritable Class KeepStoreEmailPaymentMicrocopy
    Private Sub New()
    End Sub

    Public Shared Function BuildPaymentCopy(ByVal payment As KeepStoreEmailPaymentInfo) As List(Of String)
        Dim lines As New List(Of String)()
        If payment Is Nothing Then
            Return lines
        End If

        If Not String.IsNullOrWhiteSpace(payment.Description) Then
            lines.Add("Metodo di pagamento: " & payment.Description.Trim())
        End If

        If payment.IsBankTransfer Then
            lines.Add("Il pagamento tramite bonifico sara verificato dopo l'accredito.")
            If Not String.IsNullOrWhiteSpace(payment.AmountDue) Then
                lines.Add("Importo da pagare: " & payment.AmountDue.Trim())
            End If
            If Not String.IsNullOrWhiteSpace(payment.Beneficiary) Then
                lines.Add("Beneficiario: " & payment.Beneficiary.Trim())
            End If
            If Not String.IsNullOrWhiteSpace(payment.Iban) Then
                lines.Add("IBAN: " & payment.Iban.Trim())
            End If
            If Not String.IsNullOrWhiteSpace(payment.BankName) Then
                lines.Add("Banca: " & payment.BankName.Trim())
            End If
            If Not String.IsNullOrWhiteSpace(payment.SwiftCode) Then
                lines.Add("SWIFT/BIC: " & payment.SwiftCode.Trim())
            End If
            If Not String.IsNullOrWhiteSpace(payment.RecommendedCause) Then
                lines.Add("Causale consigliata: " & payment.RecommendedCause.Trim())
            ElseIf Not String.IsNullOrWhiteSpace(payment.OrderNumber) Then
                lines.Add("Causale consigliata: Pagamento ordine n. " & payment.OrderNumber.Trim())
            End If
        ElseIf payment.IsCashOnDelivery Then
            lines.Add("Il pagamento e previsto alla consegna secondo le condizioni dell'ordine.")
        ElseIf payment.IsOnline Then
            If payment.IsGatewayConfirmed Then
                lines.Add("Pagamento online ricevuto.")
            Else
                lines.Add("Pagamento online in verifica.")
            End If
        End If

        If Not payment.IsBankTransfer AndAlso Not String.IsNullOrWhiteSpace(payment.Information) Then
            lines.Add(payment.Information.Trim())
        End If

        Return lines
    End Function
End Class

Public NotInheritable Class KeepStoreEmailShippingMicrocopy
    Private Sub New()
    End Sub

    Public Shared Function BuildShippingCopy(ByVal shipping As KeepStoreEmailShippingInfo) As List(Of String)
        Dim lines As New List(Of String)()
        If shipping Is Nothing Then
            Return lines
        End If

        If Not String.IsNullOrWhiteSpace(shipping.MethodDescription) Then
            lines.Add("Metodo di spedizione: " & shipping.MethodDescription.Trim())
        End If

        If Not String.IsNullOrWhiteSpace(shipping.CarrierName) Then
            lines.Add("Corriere: " & shipping.CarrierName.Trim())
        End If

        If Not String.IsNullOrWhiteSpace(shipping.TrackingCode) Then
            lines.Add("Tracking: " & shipping.TrackingCode.Trim())
        End If

        If Not String.IsNullOrWhiteSpace(shipping.TrackingUrl) Then
            lines.Add("Link tracking: " & shipping.TrackingUrl.Trim())
        End If

        Return lines
    End Function
End Class

Public NotInheritable Class KeepStoreEmailRenderer
    Private Sub New()
    End Sub

    Public Shared Function Render(ByVal model As KeepStoreEmailMessageModel) As KeepStoreEmailRenderResult
        Dim result As New KeepStoreEmailRenderResult()
        result.HtmlBody = RenderHtml(model)
        result.PlainTextBody = RenderPlainText(model)
        Return result
    End Function

    Public Shared Function RenderHtml(ByVal model As KeepStoreEmailMessageModel) As String
        If model Is Nothing Then
            model = New KeepStoreEmailMessageModel()
        End If

        Dim brand As KeepStoreEmailBrandInfo = EnsureBrand(model)
        Dim sb As New StringBuilder()
        Dim title As String = If(String.IsNullOrWhiteSpace(model.Title), "Aggiornamento KeepStore", model.Title.Trim())
        Dim companyName As String = If(String.IsNullOrWhiteSpace(brand.CompanyName), "KeepStore", brand.CompanyName.Trim())
        Dim logoPath As String = KeepStoreEmailLogo.BuildLogoUrl(brand.SiteUrl, brand.LogoWeb)

        sb.Append("<!doctype html><html><head><meta charset=""utf-8""><meta name=""viewport"" content=""width=device-width, initial-scale=1"">")
        sb.Append("<title>").Append(Html(title)).Append("</title></head>")
        sb.Append("<body style=""margin:0;padding:0;background:#f5f7f9;color:#17212b;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:24px;"">")
        sb.Append("<span style=""display:none!important;visibility:hidden;mso-hide:all;opacity:0;color:transparent;height:0;width:0;overflow:hidden;"">")
        sb.Append(Html(model.Preheader)).Append("</span>")
        sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""background:#f5f7f9;margin:0;padding:24px 0;""><tr><td align=""center"">")
        sb.Append("<table role=""presentation"" width=""640"" cellspacing=""0"" cellpadding=""0"" style=""width:100%;max-width:640px;background:#ffffff;border:1px solid #dde5ec;border-radius:8px;overflow:hidden;"">")
        sb.Append("<tr><td style=""padding:24px 32px;border-bottom:1px solid #e7ebef;background:#ffffff;"">")
        sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0""><tr>")
        sb.Append("<td align=""left"" style=""vertical-align:middle;""><img src=""").Append(Attr(logoPath)).Append(""" alt=""").Append(Attr(companyName)).Append(""" style=""display:block;max-width:190px;max-height:78px;height:auto;border:0;outline:none;text-decoration:none;""></td>")
        If Not String.IsNullOrWhiteSpace(model.StatusBadge) Then
            sb.Append("<td align=""right"" style=""vertical-align:middle;""><span style=""display:inline-block;padding:7px 11px;border-radius:999px;background:#eef5ff;color:#175aa6;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.3px;"">").Append(Html(model.StatusBadge)).Append("</span></td>")
        End If
        sb.Append("</tr></table>")
        sb.Append("</td></tr>")
        sb.Append("<tr><td style=""padding:30px 32px 14px 32px;background:#fbfcfd;"">")
        sb.Append("<h1 style=""margin:0 0 16px 0;font-size:24px;line-height:32px;font-weight:700;color:#17212b;"">").Append(Html(title)).Append("</h1>")

        AppendParagraph(sb, model.Intro)

        If model.BodyLines IsNot Nothing Then
            For Each line As String In model.BodyLines
                AppendParagraph(sb, line)
            Next
        End If

        If model.HighlightItems IsNot Nothing AndAlso model.HighlightItems.Count > 0 Then
            sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""margin:22px 0;border:1px solid #dbe4ed;background:#ffffff;"">")
            For Each item As KeepStoreEmailInfoItem In model.HighlightItems
                If item IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(item.Value) Then
                    Dim isTotal As Boolean = String.Equals(item.Label, "Totale", StringComparison.OrdinalIgnoreCase)
                    Dim valueColor As String = If(isTotal, "#17212b", "#243244")
                    Dim weight As String = If(isTotal, "800", "700")
                    sb.Append("<tr>")
                    sb.Append("<td style=""width:132px;padding:11px 14px;border-top:1px solid #eef2f6;vertical-align:top;font-size:12px;line-height:18px;color:#5b6673;font-weight:700;word-break:normal;overflow-wrap:normal;white-space:normal;"">")
                    If Not String.IsNullOrWhiteSpace(item.Label) Then
                        sb.Append(Html(item.Label)).Append(":")
                    End If
                    sb.Append("</td>")
                    sb.Append("<td style=""padding:11px 14px;border-top:1px solid #eef2f6;vertical-align:top;font-size:15px;line-height:22px;color:").Append(valueColor).Append(";font-weight:").Append(weight).Append(";word-break:normal;overflow-wrap:normal;white-space:normal;"">")
                    If isTotal Then
                        sb.Append("<span style=""white-space:nowrap;"">").Append(Html(item.Value)).Append("</span>")
                    Else
                        sb.Append(Html(item.Value))
                    End If
                    sb.Append("</td>")
                    sb.Append("</tr>")
                End If
            Next
            sb.Append("</table>")
        End If

        AppendProductTable(sb, model)

        If model.InfoBlocks IsNot Nothing Then
            For Each block As KeepStoreEmailInfoBlock In model.InfoBlocks
                AppendInfoBlock(sb, block)
            Next
        End If

        If Not String.IsNullOrWhiteSpace(model.ActionIntro) Then
            sb.Append("<p style=""margin:24px 0 14px 0;font-size:15px;line-height:23px;color:#354052;"">").Append(Html(model.ActionIntro)).Append("</p>")
        End If

        If model.ActionLink IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(model.ActionLink.Text) Then
            sb.Append("<table role=""presentation"" cellspacing=""0"" cellpadding=""0"" style=""margin:24px 0 4px 0;""><tr><td>")
            sb.Append("<a href=""").Append(Attr(SafeHref(model.ActionLink.Url))).Append(""" style=""display:inline-block;background:#17212b;color:#ffffff;text-decoration:none;padding:13px 20px;font-size:15px;line-height:21px;font-weight:700;"">")
            sb.Append(Html(model.ActionLink.Text)).Append("</a>")
            sb.Append("</td></tr></table>")
        End If
        If model.SecondaryActionLink IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(model.SecondaryActionLink.Text) Then
            sb.Append("<p style=""margin:12px 0 0 0;font-size:15px;line-height:23px;""><a href=""").Append(Attr(SafeHref(model.SecondaryActionLink.Url))).Append(""" style=""color:#175aa6;text-decoration:underline;"">")
            sb.Append(Html(model.SecondaryActionLink.Text)).Append("</a></p>")
        End If

        If Not String.IsNullOrWhiteSpace(model.LegalText) Then
            Dim legalTitle As String = If(String.IsNullOrWhiteSpace(model.LegalTitle), "Informazioni sul documento di vendita", model.LegalTitle.Trim())
            sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""margin:22px 0 0 0;border:1px solid #e3e8ee;background:#ffffff;"">")
            sb.Append("<tr><td style=""padding:14px 18px;"">")
            sb.Append("<h2 style=""margin:0 0 8px 0;font-size:15px;line-height:22px;color:#17212b;"">").Append(Html(legalTitle)).Append("</h2>")
            sb.Append("<p style=""margin:0;font-size:12px;line-height:18px;color:#5b6673;"">").Append(Html(model.LegalText)).Append("</p>")
            sb.Append("</td></tr></table>")
        End If

        sb.Append("</td></tr>")
        sb.Append("<tr><td style=""padding:20px 32px 28px 32px;background:#f9fafb;border-top:1px solid #e7ebef;color:#5b6673;font-size:13px;line-height:20px;"">")
        sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0""><tr>")
        sb.Append("<td style=""width:50%;vertical-align:top;padding-right:14px;"">")
        AppendFooterLine(sb, companyName, "Azienda")
        AppendFooterLine(sb, brand.AddressLine, "Indirizzo")
        AppendFooterLine(sb, brand.CityLine, "Sede")
        sb.Append("</td><td style=""width:50%;vertical-align:top;padding-left:14px;"">")
        AppendFooterLine(sb, brand.SupportEmail, "Email")
        AppendFooterLine(sb, brand.Phone, "Telefono")
        AppendFooterLine(sb, brand.SiteUrl, "Sito")
        AppendFooterLine(sb, brand.VatNumber, "P.IVA")
        AppendFooterLine(sb, brand.FiscalCode, "C.F.")
        AppendFooterLine(sb, brand.Pec, "PEC")
        AppendFooterLine(sb, brand.Sdi, "SDI")
        sb.Append("</td></tr></table>")
        AppendParagraph(sb, model.FooterNote)
        sb.Append("</td></tr>")
        sb.Append("</table></td></tr></table></body></html>")
        Return sb.ToString()
    End Function

    Public Shared Function RenderPlainText(ByVal model As KeepStoreEmailMessageModel) As String
        If model Is Nothing Then
            model = New KeepStoreEmailMessageModel()
        End If

        Dim brand As KeepStoreEmailBrandInfo = EnsureBrand(model)
        Dim sb As New StringBuilder()

        AppendPlainLine(sb, If(String.IsNullOrWhiteSpace(model.Title), "Aggiornamento KeepStore", model.Title.Trim()))
        AppendPlainLine(sb, "")
        AppendPlainLine(sb, model.Intro)

        If model.BodyLines IsNot Nothing Then
            For Each line As String In model.BodyLines
                AppendPlainLine(sb, line)
            Next
        End If

        If model.ProductLines IsNot Nothing AndAlso model.ProductLines.Count > 0 Then
            AppendPlainLine(sb, "")
            AppendPlainLine(sb, "Prodotti")
            AppendPlainLine(sb, model.ProductTableCaption)
            For Each product As KeepStoreEmailProductLine In model.ProductLines
                If product IsNot Nothing Then
                    Dim parts As New List(Of String)()
                    AddPlainPart(parts, "Codice", product.Code)
                    AddPlainPart(parts, "EAN", product.Ean)
                    AddPlainPart(parts, "Descrizione", product.Description)
                    AddPlainPart(parts, "Q.ta", product.Quantity)
                    AddPlainPart(parts, "Prezzo unit.", product.UnitPrice)
                    AddPlainPart(parts, "Totale", product.LineTotal)
                    AppendPlainLine(sb, String.Join(" | ", parts.ToArray()))
                End If
            Next
        End If

        If model.InfoBlocks IsNot Nothing Then
            For Each block As KeepStoreEmailInfoBlock In model.InfoBlocks
                If block IsNot Nothing Then
                    AppendPlainLine(sb, "")
                    AppendPlainLine(sb, block.Title)
                    AppendPlainLine(sb, block.Body)
                    If block.Items IsNot Nothing Then
                        For Each item As KeepStoreEmailInfoItem In block.Items
                            If item IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(item.Value) Then
                                AppendPlainLine(sb, CleanText(item.Label) & ": " & CleanText(item.Value))
                            End If
                        Next
                    End If
                End If
            Next
        End If

        If Not String.IsNullOrWhiteSpace(model.ActionIntro) Then
            AppendPlainLine(sb, "")
            AppendPlainLine(sb, model.ActionIntro)
        End If

        If model.ActionLink IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(model.ActionLink.Text) Then
            AppendPlainLine(sb, "")
            AppendPlainLine(sb, CleanText(model.ActionLink.Text) & ": " & SafeHref(model.ActionLink.Url))
        End If
        If model.SecondaryActionLink IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(model.SecondaryActionLink.Text) Then
            AppendPlainLine(sb, CleanText(model.SecondaryActionLink.Text) & ": " & SafeHref(model.SecondaryActionLink.Url))
        End If

        If Not String.IsNullOrWhiteSpace(model.LegalText) Then
            AppendPlainLine(sb, "")
            AppendPlainLine(sb, If(String.IsNullOrWhiteSpace(model.LegalTitle), "Informazioni sul documento di vendita", model.LegalTitle.Trim()))
            AppendPlainLine(sb, model.LegalText)
        End If

        AppendPlainLine(sb, "")
        AppendPlainLine(sb, If(String.IsNullOrWhiteSpace(brand.CompanyName), "KeepStore", brand.CompanyName.Trim()))
        AppendPlainLine(sb, model.FooterNote)
        AppendPlainLine(sb, brand.AddressLine)
        AppendPlainLine(sb, brand.CityLine)
        AppendPlainLine(sb, brand.SupportEmail)
        AppendPlainLine(sb, brand.Phone)
        AppendPlainLine(sb, brand.SiteUrl)
        AppendPlainLine(sb, JoinFooterPlain("P.IVA", brand.VatNumber))
        AppendPlainLine(sb, JoinFooterPlain("C.F.", brand.FiscalCode))
        AppendPlainLine(sb, JoinFooterPlain("PEC", brand.Pec))
        AppendPlainLine(sb, JoinFooterPlain("SDI", brand.Sdi))

        Return sb.ToString().Trim()
    End Function

    Private Shared Function EnsureBrand(ByVal model As KeepStoreEmailMessageModel) As KeepStoreEmailBrandInfo
        If model.Brand Is Nothing Then
            model.Brand = New KeepStoreEmailBrandInfo()
        End If

        Return model.Brand
    End Function

    Private Shared Sub AppendInfoBlock(ByVal sb As StringBuilder, ByVal block As KeepStoreEmailInfoBlock)
        If block Is Nothing Then
            Return
        End If

        If String.Equals(block.Title, "Riepilogo ordine", StringComparison.OrdinalIgnoreCase) Then
            AppendSummaryBlock(sb, block)
            Return
        End If

        sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""margin:20px 0;border:1px solid #e3e8ee;background:#fbfcfd;"">")
        sb.Append("<tr><td style=""padding:16px 18px;"">")
        If Not String.IsNullOrWhiteSpace(block.Title) Then
            sb.Append("<h2 style=""margin:0 0 10px 0;font-size:17px;line-height:24px;color:#17212b;"">").Append(Html(block.Title)).Append("</h2>")
        End If
        AppendParagraph(sb, block.Body)

        If block.Items IsNot Nothing Then
            For Each item As KeepStoreEmailInfoItem In block.Items
                If item IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(item.Value) Then
                    sb.Append("<p style=""margin:8px 0;font-size:14px;line-height:21px;color:#354052;"">")
                    If Not String.IsNullOrWhiteSpace(item.Label) Then
                        sb.Append("<strong>").Append(Html(item.Label)).Append(":</strong> ")
                    End If
                    sb.Append(Html(item.Value)).Append("</p>")
                End If
            Next
        End If

        sb.Append("</td></tr></table>")
    End Sub

    Private Shared Sub AppendSummaryBlock(ByVal sb As StringBuilder, ByVal block As KeepStoreEmailInfoBlock)
        sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""margin:22px 0;border:1px solid #dbe4ed;background:#ffffff;"">")
        sb.Append("<tr><td style=""padding:18px 20px;background:#fbfcfd;border-bottom:1px solid #e7ebef;"">")
        sb.Append("<h2 style=""margin:0;font-size:18px;line-height:26px;color:#17212b;"">").Append(Html(block.Title)).Append("</h2>")
        sb.Append("</td></tr>")

        If block.Items IsNot Nothing Then
            For Each item As KeepStoreEmailInfoItem In block.Items
                If item Is Nothing OrElse String.IsNullOrWhiteSpace(item.Value) Then Continue For

                Dim isTotal As Boolean = String.Equals(item.Label, "Totale", StringComparison.OrdinalIgnoreCase)
                Dim valueColor As String = If(isTotal, "#17212b", "#243244")
                Dim weight As String = If(isTotal, "800", "700")
                sb.Append("<tr>")
                sb.Append("<td style=""width:150px;padding:12px 18px;border-top:1px solid #eef2f6;vertical-align:top;font-size:13px;line-height:19px;color:#5b6673;font-weight:700;word-break:normal;overflow-wrap:normal;white-space:normal;"">")
                If Not String.IsNullOrWhiteSpace(item.Label) Then
                    sb.Append(Html(item.Label)).Append(":")
                End If
                sb.Append("</td>")
                sb.Append("<td style=""padding:12px 18px;border-top:1px solid #eef2f6;vertical-align:top;font-size:15px;line-height:22px;color:").Append(valueColor).Append(";font-weight:").Append(weight).Append(";word-break:normal;overflow-wrap:normal;white-space:normal;"">")
                If isTotal Then
                    sb.Append("<span style=""white-space:nowrap;"">").Append(Html(item.Value)).Append("</span>")
                Else
                    sb.Append(Html(item.Value))
                End If
                sb.Append("</td>")
                sb.Append("</tr>")
            Next
        End If

        sb.Append("</table>")
    End Sub

    Private Shared Sub AppendProductTable(ByVal sb As StringBuilder, ByVal model As KeepStoreEmailMessageModel)
        If model Is Nothing OrElse model.ProductLines Is Nothing OrElse model.ProductLines.Count = 0 Then
            Return
        End If

        sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""margin:22px 0;border:1px solid #e3e8ee;background:#ffffff;"">")
        sb.Append("<tr><td style=""padding:16px 18px;background:#fbfcfd;"">")
        sb.Append("<h2 style=""margin:0 0 6px 0;font-size:17px;line-height:24px;color:#17212b;"">Prodotti</h2>")
        If Not String.IsNullOrWhiteSpace(model.ProductTableCaption) Then
            sb.Append("<p style=""margin:0;font-size:13px;line-height:19px;color:#697586;"">").Append(Html(model.ProductTableCaption)).Append("</p>")
        End If
        sb.Append("</td></tr>")

        For Each product As KeepStoreEmailProductLine In model.ProductLines
            If product Is Nothing Then Continue For
            sb.Append("<tr>")
            sb.Append("<td style=""padding:0;border-top:1px solid #e7ebef;"">")
            sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""width:100%;background:#ffffff;"">")
            sb.Append("<tr>")
            sb.Append("<td width=""80"" style=""width:80px;padding:14px 0 14px 14px;vertical-align:top;"">")
            If Not String.IsNullOrWhiteSpace(product.ImageUrl) Then
                sb.Append("<img src=""").Append(Attr(product.ImageUrl)).Append(""" width=""64"" height=""64"" alt=""").Append(Attr(product.ImageAlt)).Append(""" style=""display:block;border:0;outline:none;text-decoration:none;width:64px;height:auto;max-width:64px;"">")
            Else
                sb.Append("<div style=""width:64px;min-height:44px;padding-top:20px;background:#f1f5f9;color:#5b6673;text-align:center;font-size:10px;line-height:12px;"">Foto non disponibile</div>")
            End If
            sb.Append("</td>")
            sb.Append("<td style=""padding:14px 14px 14px 14px;vertical-align:top;"">")
            If Not String.IsNullOrWhiteSpace(product.Description) Then
                sb.Append("<div style=""margin:0 0 8px 0;font-size:15px;line-height:22px;color:#17212b;font-weight:700;word-break:normal;overflow-wrap:normal;white-space:normal;"">").Append(Html(product.Description)).Append("</div>")
            End If
            sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""width:100%;"">")
            AppendProductDetailRow(sb, "Descrizione", product.Description, False, False)
            AppendProductDetailRow(sb, "Codice", product.Code, False, False)
            If Not String.IsNullOrWhiteSpace(product.Ean) Then
                AppendProductDetailRow(sb, "EAN", product.Ean, False, False)
            End If
            AppendProductDetailRow(sb, "Q.ta", product.Quantity, False, True)
            AppendProductDetailRow(sb, "Prezzo unitario", product.UnitPrice, False, True)
            AppendProductDetailRow(sb, "Totale riga", product.LineTotal, True, True)
            sb.Append("</table>")
            sb.Append("</td>")
            sb.Append("</tr>")
            sb.Append("</table>")
            sb.Append("</td>")
            sb.Append("</tr>")
        Next

        sb.Append("</table>")
    End Sub

    Private Shared Sub AppendProductDetailRow(ByVal sb As StringBuilder, ByVal label As String, ByVal value As String, ByVal highlight As Boolean, ByVal noWrapValue As Boolean)
        If String.IsNullOrWhiteSpace(value) Then
            Return
        End If

        Dim valueColor As String = If(highlight, "#17212b", "#354052")
        Dim weight As String = If(highlight, "800", "400")
        sb.Append("<tr>")
        sb.Append("<td style=""width:118px;padding:2px 10px 2px 0;vertical-align:top;font-size:13px;line-height:20px;color:#697586;font-weight:700;word-break:normal;overflow-wrap:normal;white-space:normal;"">")
        sb.Append(Html(label)).Append(":")
        sb.Append("</td>")
        sb.Append("<td style=""padding:2px 0;vertical-align:top;font-size:13px;line-height:20px;color:").Append(valueColor).Append(";font-weight:").Append(weight).Append(";word-break:normal;overflow-wrap:normal")
        If noWrapValue Then
            sb.Append(";white-space:nowrap")
        Else
            sb.Append(";white-space:normal")
        End If
        sb.Append(";"">").Append(Html(value)).Append("</td>")
        sb.Append("</tr>")
    End Sub

    Private Shared Sub AppendParagraph(ByVal sb As StringBuilder, ByVal text As String)
        If String.IsNullOrWhiteSpace(text) Then
            Return
        End If

        sb.Append("<p style=""margin:0 0 14px 0;font-size:15px;line-height:23px;color:#354052;"">").Append(Html(text)).Append("</p>")
    End Sub

    Private Shared Sub AppendFooterLine(ByVal sb As StringBuilder, ByVal value As String, ByVal label As String)
        If String.IsNullOrWhiteSpace(value) Then
            Return
        End If

        sb.Append("<p style=""margin:0 0 6px 0;""><strong>").Append(Html(label)).Append(":</strong> ").Append(Html(value)).Append("</p>")
    End Sub

    Private Shared Sub AppendPlainLine(ByVal sb As StringBuilder, ByVal value As String)
        If value Is Nothing Then
            Return
        End If

        sb.AppendLine(CleanText(value))
    End Sub

    Private Shared Sub AddPlainPart(ByVal parts As List(Of String), ByVal label As String, ByVal value As String)
        If parts Is Nothing OrElse String.IsNullOrWhiteSpace(value) Then
            Return
        End If
        parts.Add(CleanText(label) & ": " & CleanText(value))
    End Sub

    Private Shared Function JoinFooterPlain(ByVal label As String, ByVal value As String) As String
        If String.IsNullOrWhiteSpace(value) Then
            Return ""
        End If
        Return CleanText(label) & ": " & CleanText(value)
    End Function

    Private Shared Function Html(ByVal value As String) As String
        If value Is Nothing Then
            Return ""
        End If

        Return HttpUtility.HtmlEncode(value)
    End Function

    Private Shared Function Attr(ByVal value As String) As String
        If value Is Nothing Then
            Return ""
        End If

        Return HttpUtility.HtmlAttributeEncode(value)
    End Function

    Private Shared Function CleanText(ByVal value As String) As String
        If value Is Nothing Then
            Return ""
        End If

        Return value.Replace(ControlChars.Cr, " ").Replace(ControlChars.Lf, " ").Trim()
    End Function

    Private Shared Function SafeHref(ByVal value As String) As String
        If String.IsNullOrWhiteSpace(value) Then
            Return "#"
        End If

        Dim href As String = value.Trim()
        Dim lowered As String = href.ToLowerInvariant()

        If lowered.StartsWith("javascript:") OrElse lowered.StartsWith("data:") OrElse lowered.StartsWith("//") Then
            Return "#"
        End If

        If href.Contains(ControlChars.Cr) OrElse href.Contains(ControlChars.Lf) Then
            Return "#"
        End If

        Return href
    End Function
End Class
