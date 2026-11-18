Option Strict On
Option Explicit On

Imports System
Imports Microsoft.VisualBasic
Imports System.Net
Imports System.Text

' PDP-SECTIONS-RESTYLE-1A. Regole PURE (nessun accesso a database o sessione) della riga "Promozione" nel gruppo "Prezzi e promozione"
' di "Informazioni prodotto". Una riga per OGNI offerta gia risolta dal server: mai dati combinati fra offerte diverse. I valori arrivano
' gia calcolati (prezzo, sconto, validita) dallo stesso modello che alimenta il riquadro delle offerte; qui si compone e si codifica soltanto.
Public Module KeepStorePdpInfo
    Public Const ImmediateKind As String = "Promo immediata"
    Public Const QuantityKind As String = "Offerta quantit" & ChrW(&HE0)
    Public Const AppliedText As String = "gi" & ChrW(&HE0) & " applicata al prezzo"

    ' isImmediate: l'offerta vale gia per un pezzo. isApplied: e l'offerta che determina il prezzo principale mostrato (non si ripete il prezzo).
    ' priceText, discountText, validityText: testi gia formattati dal chiamante; vuoti = la parte non si mostra.
    Public Function PromoRowHtml(ByVal isImmediate As Boolean,
                                 ByVal isApplied As Boolean,
                                 ByVal label As String,
                                 ByVal discountText As String,
                                 ByVal priceText As String,
                                 ByVal validityText As String) As String
        Dim sb As New StringBuilder()
        sb.Append("<li class=""ks-pdp-info-promo"">")
        sb.Append("<p class=""name-feature"">Promozione</p>")
        sb.Append("<p class=""property ks-pdp-info-promo__value"">")
        sb.Append("<strong class=""ks-pdp-info-promo__kind"">").Append(Enc(If(isImmediate, ImmediateKind, QuantityKind))).Append("</strong>")
        If Clean(discountText) <> "" Then
            sb.Append("<span class=""ks-pdp-info-promo__discount"">").Append(Enc(Clean(discountText))).Append("</span>")
        End If
        If Clean(label) <> "" Then
            sb.Append("<span class=""ks-pdp-info-promo__label"">").Append(Enc(Clean(label))).Append("</span>")
        End If
        If isImmediate AndAlso isApplied Then
            sb.Append("<span class=""ks-pdp-info-promo__applied"">").Append(Enc(AppliedText)).Append("</span>")
        ElseIf Clean(priceText) <> "" Then
            sb.Append("<span class=""ks-pdp-info-promo__price"">").Append(If(isImmediate, "a ", "da ")).Append("<strong>").Append(Enc(Clean(priceText))).Append("</strong></span>")
        End If
        If Clean(validityText) <> "" Then
            sb.Append("<span class=""ks-pdp-info-promo__dates"">Validit").Append("&agrave;: ").Append(Enc(Clean(validityText))).Append("</span>")
        End If
        sb.Append("</p></li>")
        Return sb.ToString()
    End Function

    ' Sconto in percentuale: "-6%"; "" se non c'e sconto.
    Public Function DiscountText(ByVal percent As Decimal) As String
        If percent <= 0D Then Return ""
        Return "-" & percent.ToString("0.##", Globalization.CultureInfo.InvariantCulture) & "%"
    End Function

    Private Function Clean(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Return value.Trim()
    End Function

    Private Function Enc(ByVal value As String) As String
        Return WebUtility.HtmlEncode(If(value, ""))
    End Function
End Module
