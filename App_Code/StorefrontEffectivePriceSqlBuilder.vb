Option Strict On
Option Explicit On

Imports System
Imports System.Text.RegularExpressions

' SQL adapter for StorefrontEffectivePriceResolver; no session, values or rounding.
Public NotInheritable Class StorefrontEffectivePriceSqlBuilder
    Private Sub New()
    End Sub

    Public Shared Function BuildEffectiveGrossExpression(ByVal netExpression As String,
                                                         ByVal standardGrossExpression As String,
                                                         ByVal reverseChargeIdExpression As String,
                                                         ByVal reverseChargeRateExpression As String,
                                                         ByVal reverseChargeEnabledParameter As String,
                                                         ByVal hasVatOverrideParameter As String,
                                                         ByVal vatOverrideParameter As String) As String
        ' Operands are identifiers (optionally qualified) or named parameters,
        ' never arbitrary SQL supplied by a caller/client.
        ValidateOperand(netExpression)
        ValidateOperand(standardGrossExpression)
        ValidateOperand(reverseChargeIdExpression)
        ValidateOperand(reverseChargeRateExpression)
        ValidateParameter(reverseChargeEnabledParameter)
        ValidateParameter(hasVatOverrideParameter)
        ValidateParameter(vatOverrideParameter)

        ' Multiplication by exact DECIMAL 0.01 avoids MySQL division-scale
        ' truncation of fractional rates before promotion resolution.
        Return "(CASE WHEN " & hasVatOverrideParameter & "=1 AND (" & vatOverrideParameter &
               " IS NULL OR " & vatOverrideParameter & "<0) THEN NULL " &
               "WHEN " & reverseChargeEnabledParameter & "=1 AND " & reverseChargeIdExpression &
               ">=0 AND " & reverseChargeRateExpression & ">=0 THEN " &
               "CASE WHEN " & netExpression & ">0 THEN " & netExpression &
               "*(1+" & reverseChargeRateExpression & "*0.01) ELSE NULL END " &
               "WHEN " & hasVatOverrideParameter & "=1 THEN CASE WHEN " & netExpression &
               ">0 THEN " & netExpression & "*(1+" & vatOverrideParameter & "*0.01) ELSE NULL END " &
               "WHEN " & standardGrossExpression & ">0 THEN " & standardGrossExpression & " ELSE NULL END)"
    End Function

    Private Shared Sub ValidateOperand(ByVal value As String)
        If value Is Nothing OrElse Not Regex.IsMatch(value,
            "\A(?:[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?|[@?][A-Za-z_][A-Za-z0-9_]*)\z") Then
            Throw New ArgumentException("Expected a SQL identifier or named parameter.", "value")
        End If
    End Sub

    Private Shared Sub ValidateParameter(ByVal value As String)
        If value Is Nothing OrElse Not Regex.IsMatch(value, "\A[@?][A-Za-z_][A-Za-z0-9_]*\z") Then
            Throw New ArgumentException("Expected a named SQL parameter.", "value")
        End If
    End Sub
End Class
