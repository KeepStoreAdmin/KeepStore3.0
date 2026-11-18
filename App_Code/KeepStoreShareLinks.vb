Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Net
Imports System.Text
Imports Microsoft.VisualBasic

' PDP-TOOLS-1A. Collegamenti di condivisione e di contatto della scheda prodotto e del sito: modulo PURO (nessun HttpContext, nessun
' database), provato da Tools/Test-PdpTools.ps1. Regole:
' - ogni testo che entra in un indirizzo passa da Uri.EscapeDataString; ogni indirizzo che entra nell'HTML e codificato come attributo;
' - il numero WhatsApp vale solo in formato internazionale senza "+" (da 11 a 15 cifre, mai con lo zero iniziale): un numero nazionale
'   non si puo distinguere da un prefisso estero, quindi non diventa mai un collegamento;
' - un indirizzo esterno (sito del produttore, scheda tecnica) vale solo se e http/https assoluto verso un nome di dominio.
Public NotInheritable Class KeepStoreShareLinks

    Private Const MinWhatsAppDigits As Integer = 11
    Private Const MaxWhatsAppDigits As Integer = 15
    Private Const MaxExternalUrlLength As Integer = 255
    Private Const MaxNameLength As Integer = 160
    Private Const MaxCodeLength As Integer = 60
    Private Const MaxPriceLength As Integer = 40
    Private Const InfoRequest As String = "Buongiorno, vorrei informazioni su questo articolo:"
    Private Const AvailabilityRequest As String = "Buongiorno, vorrei essere avvisato quando questo articolo torna disponibile:"
    Private Const IncomingRequest As String = "Buongiorno, vorrei sapere quando arriva questo articolo:"

    Private Sub New()
    End Sub

    ' Solo cifre, separatori usuali e un "+" iniziale; "00" iniziale vale come "+". Tutto il resto = nessun numero.
    Public Shared Function NormalizeWhatsAppNumber(ByVal raw As String) As String
        Dim value As String = If(raw, "").Trim()
        If value.Length = 0 OrElse value.Length > 40 Then Return ""
        If value.Replace(" ", "").Contains("(0)") Then Return ""
        Dim sb As New StringBuilder()
        For i As Integer = 0 To value.Length - 1
            Dim ch As Char = value(i)
            If ch >= "0"c AndAlso ch <= "9"c Then
                sb.Append(ch)
            ElseIf ch = "+"c Then
                If i <> 0 Then Return ""
            ElseIf ch = " "c OrElse ch = "."c OrElse ch = "-"c OrElse ch = "("c OrElse ch = ")"c Then
                ' separatore ignorato
            Else
                Return ""
            End If
        Next
        Dim digits As String = sb.ToString()
        If Not value.StartsWith("+", StringComparison.Ordinal) AndAlso digits.StartsWith("00", StringComparison.Ordinal) Then digits = digits.Substring(2)
        If digits.StartsWith("0", StringComparison.Ordinal) Then Return ""
        If digits.Length < MinWhatsAppDigits OrElse digits.Length > MaxWhatsAppDigits Then Return ""
        Return digits
    End Function

    Private Shared Function NormalizeNewLines(ByVal value As String, ByVal lineBreak As String) As String
        Return If(value, "").Replace(vbCrLf, vbLf).Replace(vbCr, vbLf).Replace(vbLf, lineBreak)
    End Function

    Private Shared Function Enc(ByVal value As String, ByVal lineBreak As String) As String
        Return Uri.EscapeDataString(NormalizeNewLines(value, lineBreak))
    End Function

    ' Conversazione con il numero dell'azienda; senza numero valido nessun collegamento.
    Public Shared Function WhatsAppChatUrl(ByVal number As String, ByVal text As String) As String
        Dim digits As String = NormalizeWhatsAppNumber(number)
        If digits = "" Then Return ""
        If If(text, "").Trim() = "" Then Return "https://wa.me/" & digits
        Return "https://wa.me/" & digits & "?text=" & Enc(text, vbLf)
    End Function

    ' Condivisione: l'utente sceglie il contatto dentro WhatsApp.
    Public Shared Function WhatsAppShareUrl(ByVal text As String) As String
        Return "https://wa.me/?text=" & Enc(text, vbLf)
    End Function

    Public Shared Function TelegramShareUrl(ByVal url As String, ByVal text As String) As String
        Return "https://t.me/share/url?url=" & Enc(url, vbLf) & "&text=" & Enc(text, vbLf)
    End Function

    Public Shared Function FacebookShareUrl(ByVal url As String) As String
        Return "https://www.facebook.com/sharer/sharer.php?u=" & Enc(url, vbLf)
    End Function

    Public Shared Function XShareUrl(ByVal url As String, ByVal text As String) As String
        Return "https://x.com/intent/post?url=" & Enc(url, vbLf) & "&text=" & Enc(text, vbLf)
    End Function

    ' Destinatario vuoto = l'utente sceglie a chi scrivere; un destinatario dato deve superare il validatore condiviso.
    Public Shared Function MailShareHref(ByVal recipient As String, ByVal subject As String, ByVal body As String) As String
        Dim target As String = "mailto:"
        If If(recipient, "").Trim() <> "" Then
            target = KeepStoreContactLinks.BuildMailtoHref(recipient)
            If target = "" Then Return ""
        End If
        Return target & "?subject=" & Enc(subject, " ") & "&body=" & Enc(body, vbCrLf)
    End Function

    ' Indirizzo esterno ammesso: http/https assoluto, verso un nome di dominio con almeno un punto, senza credenziali ne caratteri di controllo.
    ' Restituisce l'indirizzo normalizzato (percento-codificato: nessuna virgoletta ne parentesi angolare) oppure "".
    Public Shared Function ExternalUrl(ByVal raw As String) As String
        Dim value As String = If(raw, "").Trim()
        If value.Length = 0 OrElse value.Length > MaxExternalUrlLength Then Return ""
        For Each ch As Char In value
            If Char.IsControl(ch) Then Return ""
        Next
        Dim parsed As Uri = Nothing
        If Not Uri.TryCreate(value, UriKind.Absolute, parsed) OrElse parsed Is Nothing Then Return ""
        If parsed.Scheme <> Uri.UriSchemeHttp AndAlso parsed.Scheme <> Uri.UriSchemeHttps Then Return ""
        If parsed.UserInfo <> "" Then Return ""
        If parsed.HostNameType <> UriHostNameType.Dns OrElse parsed.Host.IndexOf("."c) <= 0 Then Return ""
        Dim absolute As String = parsed.AbsoluteUri
        If absolute.IndexOf(""""c) >= 0 OrElse absolute.IndexOf("<"c) >= 0 OrElse absolute.IndexOf(">"c) >= 0 OrElse absolute.IndexOf("'"c) >= 0 Then Return ""
        Return absolute
    End Function

    Public Shared Function ExternalHost(ByVal url As String) As String
        Dim clean As String = ExternalUrl(url)
        If clean = "" Then Return ""
        Return New Uri(clean).Host.ToLowerInvariant()
    End Function

    ' Campo di un messaggio: una riga sola, senza i marcatori di formato di WhatsApp, tagliato alla lunghezza data.
    Private Shared Function CleanField(ByVal value As String, ByVal maxLength As Integer) As String
        Dim sb As New StringBuilder()
        Dim lastSpace As Boolean = True
        For Each ch As Char In If(value, "")
            If ch = "*"c OrElse ch = "~"c OrElse ch = "`"c Then Continue For
            If Char.IsWhiteSpace(ch) OrElse Char.IsControl(ch) Then
                If Not lastSpace Then sb.Append(" "c)
                lastSpace = True
            Else
                sb.Append(ch)
                lastSpace = False
            End If
        Next
        Dim text As String = sb.ToString().Trim()
        If text.Length > maxLength Then text = text.Substring(0, maxLength - 3).TrimEnd() & "..."
        Return text
    End Function

    Private Shared Function ProductLines(ByVal opening As String, ByVal name As String, ByVal code As String,
                                         ByVal priceText As String, ByVal priceLabel As String, ByVal url As String) As String
        Dim link As String = ExternalUrl(url)
        If link = "" Then Return ""
        Dim lines As New List(Of String)()
        lines.Add(opening)
        Dim cleanName As String = CleanField(name, MaxNameLength)
        If cleanName <> "" Then lines.Add("*" & cleanName & "*")
        Dim cleanCode As String = CleanField(code, MaxCodeLength)
        If cleanCode <> "" Then lines.Add("Codice: " & cleanCode)
        Dim cleanPrice As String = CleanField(priceText, MaxPriceLength)
        If cleanPrice <> "" Then
            Dim cleanLabel As String = CleanField(priceLabel, MaxPriceLength)
            lines.Add("Prezzo: " & cleanPrice & If(cleanLabel <> "", " (" & cleanLabel & ")", ""))
        End If
        lines.Add(link)
        Return String.Join(vbLf, lines.ToArray())
    End Function

    ' Messaggio «Richiedi informazioni»: il collegamento alla scheda in ultima riga fa comparire in WhatsApp titolo e foto dell'articolo.
    Public Shared Function ProductInfoMessage(ByVal name As String, ByVal code As String, ByVal priceText As String,
                                              ByVal priceLabel As String, ByVal url As String) As String
        Return ProductLines(InfoRequest, name, code, priceText, priceLabel, url)
    End Function

    ' Richiesta al negozio (non un'iscrizione): articolo esaurito oppure in arrivo.
    Public Shared Function ProductAvailabilityMessage(ByVal name As String, ByVal code As String, ByVal url As String, ByVal incoming As Boolean) As String
        Return ProductLines(If(incoming, IncomingRequest, AvailabilityRequest), name, code, "", "", url)
    End Function

    Public Shared Function SiteContactMessage(ByVal siteHost As String) As String
        Dim host As String = CleanField(siteHost, 80)
        If host = "" Then Return "Buongiorno, vi scrivo dal vostro sito"
        Return "Buongiorno, vi scrivo dal sito " & host
    End Function

    Private Shared Function ShareItem(ByVal href As String, ByVal label As String, ByVal key As String, ByVal external As Boolean) As String
        Return "<li><a class=""ks-pdp-share__link ks-pdp-share__link--" & key & """ href=""" & WebUtility.HtmlEncode(href) & """" &
               If(external, " target=""_blank"" rel=""noopener noreferrer""", "") & ">" & WebUtility.HtmlEncode(label) & "</a></li>"
    End Function

    ' Elenco dei collegamenti di condivisione (ripiego quando il dispositivo non ha la condivisione nativa). Senza un indirizzo valido: niente.
    Public Shared Function ShareLinksHtml(ByVal url As String, ByVal title As String) As String
        Dim link As String = ExternalUrl(url)
        If link = "" Then Return ""
        Dim cleanTitle As String = CleanField(title, MaxNameLength)
        Dim sb As New StringBuilder()
        sb.Append(ShareItem(WhatsAppShareUrl((cleanTitle & vbLf & link).Trim()), "WhatsApp", "whatsapp", True))
        sb.Append(ShareItem(TelegramShareUrl(link, cleanTitle), "Telegram", "telegram", True))
        sb.Append(ShareItem(FacebookShareUrl(link), "Facebook", "facebook", True))
        sb.Append(ShareItem(XShareUrl(link, cleanTitle), "X", "x", True))
        sb.Append(ShareItem(MailShareHref("", cleanTitle, cleanTitle & vbLf & link), "E-mail", "mail", False))
        Return sb.ToString()
    End Function
End Class

' Una riga della lettura dei pulsanti social dell'azienda (solo il pulsante WhatsApp abilitato e la regola del pulsante fisso).
Public NotInheritable Class ContactChannelRow
    Public ReadOnly Number As String
    Public ReadOnly WidgetEnabled As Integer
    Public ReadOnly CallToAction As String
    Public ReadOnly Position As String

    Public Sub New(ByVal number As String, ByVal widgetEnabled As Integer, ByVal callToAction As String, ByVal position As String)
        Me.Number = If(number, "")
        Me.WidgetEnabled = widgetEnabled
        Me.CallToAction = If(callToAction, "")
        Me.Position = If(position, "")
    End Sub
End Class

' Canale di contatto di un'azienda. None = nessun canale (esito valido, non un errore).
Public NotInheritable Class ContactChannel
    Public Shared ReadOnly None As New ContactChannel("", False, "", "right")

    Public ReadOnly WhatsAppNumber As String
    Public ReadOnly WidgetEnabled As Boolean
    Public ReadOnly CallToAction As String
    Public ReadOnly Position As String

    Public Sub New(ByVal whatsAppNumber As String, ByVal widgetEnabled As Boolean, ByVal callToAction As String, ByVal position As String)
        Me.WhatsAppNumber = If(whatsAppNumber, "")
        Me.WidgetEnabled = widgetEnabled
        Me.CallToAction = If(callToAction, "")
        Me.Position = If(position, "right")
    End Sub
End Class

Public NotInheritable Class ContactChannelPolicy
    Private Const MaxCallToActionLength As Integer = 80

    Private Sub New()
    End Sub

    ' Un canale solo se l'azienda ha ESATTAMENTE una riga WhatsApp abilitata con un numero valido: zero, piu righe o numero dubbio = nessun canale.
    Public Shared Function SelectChannel(ByVal rows As IList(Of ContactChannelRow)) As ContactChannel
        If rows Is Nothing OrElse rows.Count <> 1 Then Return ContactChannel.None
        Dim row As ContactChannelRow = rows(0)
        If row Is Nothing Then Return ContactChannel.None
        Dim number As String = KeepStoreShareLinks.NormalizeWhatsAppNumber(row.Number)
        If number = "" Then Return ContactChannel.None
        Dim callToAction As String = row.CallToAction.Replace(vbCr, " ").Replace(vbLf, " ").Trim()
        If callToAction.Length > MaxCallToActionLength Then callToAction = callToAction.Substring(0, MaxCallToActionLength).TrimEnd()
        Dim position As String = If(String.Equals(row.Position.Trim(), "left", StringComparison.OrdinalIgnoreCase), "left", "right")
        Return New ContactChannel(number, row.WidgetEnabled = 1, callToAction, position)
    End Function
End Class
