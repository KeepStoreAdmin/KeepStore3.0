Option Strict On
Option Explicit On

Imports System

' Stato del prezzo mostrato al cliente, uguale su HOME, elenco e scheda prodotto (linea di stile, sezione 3.2).
' Uno sconto e "mostrato" (prezzo precedente barrato, bollino con la percentuale, prezzo rosso) solo se supera la regola unica
' StorefrontPromotionDisplayPolicy: almeno un centesimo e almeno l'1% sui prezzi stampati. La regola decide solo la presentazione:
' il prezzo da pagare resta sempre quello promozionale. La classe di stato va sul prezzo corrente; il colore sta in price-states.css.
Public NotInheritable Class StorefrontPriceState
    Public Const SaleClass As String = "ks-price-state--sale"
    Public Const NormalClass As String = "ks-price-state--normal"
    Public Const AskClass As String = "ks-price-state--ask"

    Private Sub New()
    End Sub

    Public Shared Function ShowsDiscount(ByVal basePrice As Nullable(Of Decimal), ByVal payablePrice As Nullable(Of Decimal)) As Boolean
        If Not basePrice.HasValue OrElse Not payablePrice.HasValue Then Return False
        Return StorefrontPromotionDisplayPolicy.Resolve(basePrice.Value, payablePrice.Value).HasDiscount
    End Function

    Public Shared Function CssClass(ByVal hasPrice As Boolean, ByVal showsDiscount As Boolean) As String
        If Not hasPrice Then Return AskClass
        Return If(showsDiscount, SaleClass, NormalClass)
    End Function
End Class
