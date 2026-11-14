Option Strict On
Option Explicit On

Imports System

' Cio che il cliente legge in una scheda con promozione: prezzo base, prezzo che paga, risparmio e percentuale, tutti calcolati sui valori
' GIA ARROTONDATI al centesimo (half-up, come la stampa), cosi il testo «Risparmi» e sempre la differenza fra i due prezzi stampati.
Public NotInheritable Class StorefrontPromotionDisplay
    Public ReadOnly BasePrice As Decimal
    Public ReadOnly PayablePrice As Decimal
    Public ReadOnly HasDiscount As Boolean
    Public ReadOnly Savings As Decimal
    Public ReadOnly Percent As Integer

    Public Sub New(ByVal basePrice As Decimal, ByVal payablePrice As Decimal,
                   ByVal hasDiscount As Boolean, ByVal savings As Decimal, ByVal percent As Integer)
        Me.BasePrice = basePrice
        Me.PayablePrice = payablePrice
        Me.HasDiscount = hasDiscount
        Me.Savings = If(hasDiscount, savings, 0D)
        Me.Percent = If(hasDiscount, percent, 0)
    End Sub
End Class

' Regola unica per decidere se una promozione e «significativa»: prezzo barrato, badge, «Risparmi» e qualifica per la sezione delle offerte
' compaiono solo se la differenza fra i due prezzi stampati e di almeno un centesimo E almeno l'1% del prezzo base. Il prezzo realmente
' pagabile resta sempre quello promozionale: la soglia decide solo la presentazione, mai il prezzo.
Public NotInheritable Class StorefrontPromotionDisplayPolicy
    Public Const MinimumSavings As Decimal = 0.01D
    Public Const MinimumPercent As Decimal = 1D

    Private Sub New()
    End Sub

    Public Shared Function RoundMoney(ByVal value As Decimal) As Decimal
        Return Math.Round(value, 2, MidpointRounding.AwayFromZero)
    End Function

    Public Shared Function Resolve(ByVal basePrice As Decimal, ByVal payablePrice As Decimal) As StorefrontPromotionDisplay
        Dim baseRounded As Decimal = RoundMoney(basePrice)
        Dim payableRounded As Decimal = RoundMoney(payablePrice)
        If baseRounded <= 0D OrElse payableRounded <= 0D OrElse payableRounded >= baseRounded Then
            Return New StorefrontPromotionDisplay(baseRounded, payableRounded, False, 0D, 0)
        End If

        Dim savings As Decimal = baseRounded - payableRounded
        Dim exactPercent As Decimal = (savings / baseRounded) * 100D
        If savings < MinimumSavings OrElse exactPercent < MinimumPercent Then
            Return New StorefrontPromotionDisplay(baseRounded, payableRounded, False, 0D, 0)
        End If

        ' Un prezzo pagabile positivo non puo essere presentato come sconto del 100%.
        Dim percent As Integer = Math.Min(99, Convert.ToInt32(Math.Round(exactPercent, 0, MidpointRounding.AwayFromZero)))
        Return New StorefrontPromotionDisplay(baseRounded, payableRounded, True, savings, percent)
    End Function
End Class
