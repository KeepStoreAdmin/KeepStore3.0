Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Text
Imports System.Web

' Catalogo dei marchi dei pagamenti (PAYMENT-LOGOS-1A). Qui stanno SOLO i dati fissi dei marchi: nome, file ufficiale e misure.
' Chi decide SE mostrarli e chi conosce i metodi dell'azienda dell'host (il piede di pagina): questo modulo non legge nulla.
' Decisione del PO del 2026-11-21: ogni azienda con la carta attiva sul sito accetta i due circuiti delle carte qui sotto.
' File in Public/assets/images/pagamenti/ (provenienza e regole d'uso: docs/PAYMENT_LOGOS_SOURCES.md): mai modificati, solo ridimensionati
' in proporzione. Le misure danno la stessa altezza del contenuto visibile (24 px): un file ha un margine trasparente proprio, per questo
' il suo riquadro e piu alto. Le regole globali del sito calcolano l'altezza dalla larghezza: le due misure rispettano le proporzioni del file.
Public Module KeepStorePaymentBrands
    Private Const Folder As String = "/Public/assets/images/pagamenti/"
    Private Const ListLabel As String = "Circuiti e servizi di pagamento accettati"

    Private Const CardBrandA As String = "Visa"
    Private Const CardBrandB As String = "Mastercard"
    Private Const WalletBrand As String = "PayPal"

    ' Elenco dei marchi da mostrare, oppure vuoto (mai un elenco senza voci).
    Public Function LogosHtml(ByVal showCards As Boolean, ByVal showWallet As Boolean) As String
        If Not showCards AndAlso Not showWallet Then Return String.Empty

        Dim sb As New StringBuilder()
        sb.Append("<ul class=""ks-payment-logos d-flex flex-wrap justify-content-center align-items-center gap-3 mb-0"" aria-label=""")
        sb.Append(HttpUtility.HtmlAttributeEncode(ListLabel)).Append(""">")
        If showCards Then
            AppendLogo(sb, CardBrandA, "visa.svg", 33, 24)
            AppendLogo(sb, CardBrandB, "mastercard.svg", 51, 36)
        End If
        If showWallet Then
            AppendLogo(sb, WalletBrand, "paypal-logo-2024.png", 71, 24)
        End If
        sb.Append("</ul>")
        Return sb.ToString()
    End Function

    Private Sub AppendLogo(ByVal sb As StringBuilder, ByVal brandName As String, ByVal fileName As String, ByVal width As Integer, ByVal height As Integer)
        Dim alt As String = HttpUtility.HtmlAttributeEncode(brandName)
        sb.Append("<li><img src=""").Append(Folder).Append(HttpUtility.HtmlAttributeEncode(fileName))
        sb.Append(""" alt=""").Append(alt)
        sb.Append(""" width=""").Append(width.ToString(CultureInfo.InvariantCulture))
        sb.Append(""" height=""").Append(height.ToString(CultureInfo.InvariantCulture))
        sb.Append(""" loading=""lazy"" decoding=""async"" /></li>")
    End Sub
End Module
