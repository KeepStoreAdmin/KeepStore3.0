Option Strict On
Option Explicit On

Imports System

' Fiscal precedence shared with cart revalidation, without session or rounding.
Public NotInheritable Class StorefrontEffectivePriceResolver
    Private Sub New()
    End Sub

    Public Shared Function ResolveEffectiveGross(ByVal baseNet As Nullable(Of Decimal),
                                                 ByVal baseGross As Nullable(Of Decimal),
                                                 ByVal reverseChargeEnabled As Boolean,
                                                 ByVal vatOverride As Nullable(Of Decimal),
                                                 ByVal productReverseChargeVatId As Integer,
                                                 ByVal productReverseChargeVatValue As Nullable(Of Decimal)) As Nullable(Of Decimal)
        If vatOverride.HasValue AndAlso vatOverride.Value < 0D Then Return Nothing
        If reverseChargeEnabled AndAlso productReverseChargeVatId >= 0 AndAlso
           productReverseChargeVatValue.HasValue AndAlso productReverseChargeVatValue.Value >= 0D Then
            If Not baseNet.HasValue OrElse baseNet.Value <= 0D Then Return Nothing
            Return baseNet.Value * (1D + productReverseChargeVatValue.Value / 100D)
        End If
        If vatOverride.HasValue Then
            If Not baseNet.HasValue OrElse baseNet.Value <= 0D Then Return Nothing
            Return baseNet.Value * (1D + vatOverride.Value / 100D)
        End If
        If Not baseGross.HasValue OrElse baseGross.Value <= 0D Then Return Nothing
        Return baseGross
    End Function
End Class
