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

Public Class KeepStoreEmailMessageModel
    Public Sub New()
        Brand = New KeepStoreEmailBrandInfo()
        Recipient = New KeepStoreEmailRecipientInfo()
        BodyLines = New List(Of String)()
        InfoBlocks = New List(Of KeepStoreEmailInfoBlock)()
    End Sub

    Public Property Brand As KeepStoreEmailBrandInfo
    Public Property Recipient As KeepStoreEmailRecipientInfo
    Public Property Preheader As String
    Public Property Title As String
    Public Property Intro As String
    Public Property BodyLines As List(Of String)
    Public Property InfoBlocks As List(Of KeepStoreEmailInfoBlock)
    Public Property ActionLink As KeepStoreEmailActionLink
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
End Class

Public NotInheritable Class KeepStoreEmailSubjects
    Private Sub New()
    End Sub

    Public Shared Function Registration(ByVal companyName As String) As String
        Return Company(companyName) & " - Registrazione completata"
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

    Public Shared Function OrderBankTransfer(ByVal companyName As String, ByVal orderNumber As String) As String
        Return Company(companyName) & " - Istruzioni bonifico ordine " & SafeSuffix(orderNumber)
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
            If Not String.IsNullOrWhiteSpace(payment.Iban) Then
                lines.Add("IBAN: " & payment.Iban.Trim())
            End If
            If Not String.IsNullOrWhiteSpace(payment.BankName) Then
                lines.Add("Banca: " & payment.BankName.Trim())
            End If
            If Not String.IsNullOrWhiteSpace(payment.SwiftCode) Then
                lines.Add("SWIFT/BIC: " & payment.SwiftCode.Trim())
            End If
            If Not String.IsNullOrWhiteSpace(payment.OrderNumber) Then
                lines.Add("Causale consigliata: ordine " & payment.OrderNumber.Trim())
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

        If Not String.IsNullOrWhiteSpace(payment.Information) Then
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
        Dim logoPath As String = KeepStoreEmailLogo.BuildLogoPath(brand.LogoWeb)

        sb.Append("<!doctype html><html><head><meta charset=""utf-8""><meta name=""viewport"" content=""width=device-width, initial-scale=1"">")
        sb.Append("<title>").Append(Html(title)).Append("</title></head>")
        sb.Append("<body style=""margin:0;padding:0;background:#f5f7f9;color:#17212b;font-family:Arial,Helvetica,sans-serif;"">")
        sb.Append("<span style=""display:none!important;visibility:hidden;mso-hide:all;opacity:0;color:transparent;height:0;width:0;overflow:hidden;"">")
        sb.Append(Html(model.Preheader)).Append("</span>")
        sb.Append("<table role=""presentation"" width=""100%"" cellspacing=""0"" cellpadding=""0"" style=""background:#f5f7f9;margin:0;padding:24px 0;""><tr><td align=""center"">")
        sb.Append("<table role=""presentation"" width=""640"" cellspacing=""0"" cellpadding=""0"" style=""width:100%;max-width:640px;background:#ffffff;border:1px solid #e3e8ee;"">")
        sb.Append("<tr><td style=""padding:28px 32px 18px 32px;border-bottom:1px solid #e7ebef;"">")
        sb.Append("<img src=""").Append(Attr(logoPath)).Append(""" alt=""").Append(Attr(companyName)).Append(""" style=""display:block;max-width:180px;max-height:72px;height:auto;border:0;outline:none;text-decoration:none;"">")
        sb.Append("</td></tr>")
        sb.Append("<tr><td style=""padding:28px 32px 12px 32px;"">")
        sb.Append("<h1 style=""margin:0 0 16px 0;font-size:24px;line-height:32px;font-weight:700;color:#17212b;"">").Append(Html(title)).Append("</h1>")

        AppendParagraph(sb, model.Intro)

        If model.BodyLines IsNot Nothing Then
            For Each line As String In model.BodyLines
                AppendParagraph(sb, line)
            Next
        End If

        If model.InfoBlocks IsNot Nothing Then
            For Each block As KeepStoreEmailInfoBlock In model.InfoBlocks
                AppendInfoBlock(sb, block)
            Next
        End If

        If model.ActionLink IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(model.ActionLink.Text) Then
            sb.Append("<table role=""presentation"" cellspacing=""0"" cellpadding=""0"" style=""margin:24px 0 4px 0;""><tr><td>")
            sb.Append("<a href=""").Append(Attr(SafeHref(model.ActionLink.Url))).Append(""" style=""display:inline-block;background:#17212b;color:#ffffff;text-decoration:none;padding:12px 18px;font-size:15px;line-height:20px;font-weight:700;"">")
            sb.Append(Html(model.ActionLink.Text)).Append("</a>")
            sb.Append("</td></tr></table>")
        End If

        sb.Append("</td></tr>")
        sb.Append("<tr><td style=""padding:20px 32px 28px 32px;background:#f9fafb;border-top:1px solid #e7ebef;color:#5b6673;font-size:13px;line-height:20px;"">")
        AppendFooterLine(sb, brand.SupportEmail, "Email")
        AppendFooterLine(sb, brand.Phone, "Telefono")
        AppendFooterLine(sb, brand.SiteUrl, "Sito")
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

        If model.ActionLink IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(model.ActionLink.Text) Then
            AppendPlainLine(sb, "")
            AppendPlainLine(sb, CleanText(model.ActionLink.Text) & ": " & SafeHref(model.ActionLink.Url))
        End If

        AppendPlainLine(sb, "")
        AppendPlainLine(sb, If(String.IsNullOrWhiteSpace(brand.CompanyName), "KeepStore", brand.CompanyName.Trim()))
        AppendPlainLine(sb, model.FooterNote)
        AppendPlainLine(sb, brand.SupportEmail)
        AppendPlainLine(sb, brand.Phone)
        AppendPlainLine(sb, brand.SiteUrl)

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
