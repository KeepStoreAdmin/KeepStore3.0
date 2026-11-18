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

    ' PDP-REVIEW-STARS-1A. Cinque stelle: quelle ottenute nel colore delle stelle del tema, le altre grigie (prima erano invertite).
    ' La media si arrotonda alla stella intera piu vicina (4,5 = cinque); valori fuori scala restano fra 0 e 5.
    Private Const StarOn As String = "<li><i class=""icon-star""></i></li>"
    Private Const StarOff As String = "<li><i class=""icon-star text-main-4""></i></li>"

    Public Function ReviewStarsHtml(ByVal rating As Decimal) As String
        Dim full As Integer = CInt(Math.Round(Math.Max(0D, Math.Min(5D, rating)), MidpointRounding.AwayFromZero))
        Dim sb As New StringBuilder()
        For i As Integer = 1 To 5
            sb.Append(If(i <= full, StarOn, StarOff))
        Next
        Return sb.ToString()
    End Function

    ' Conteggio delle recensioni: dice «acquisto verificato» solo per quelle che il dato segna come verificate.
    Public Function ReviewCountText(ByVal total As Integer, ByVal verified As Integer) As String
        If total <= 0 Then Return "Ancora nessuna valutazione."
        Dim text As String = If(total = 1, "1 recensione", total.ToString(Globalization.CultureInfo.InvariantCulture) & " recensioni")
        Dim shown As Integer = Math.Min(verified, total)
        If shown <= 0 Then Return text
        If total = 1 Then Return text & ", con acquisto verificato"
        Return text & ", " & shown.ToString(Globalization.CultureInfo.InvariantCulture) & " con acquisto verificato"
    End Function

    Private Function Clean(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Return value.Trim()
    End Function

    Private Function Enc(ByVal value As String) As String
        Return WebUtility.HtmlEncode(If(value, ""))
    End Function
End Module
