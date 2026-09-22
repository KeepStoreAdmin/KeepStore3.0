Option Strict On
Option Explicit On

Imports System

Module PayPalProductionSafetyHarness
    Private _checks As Integer

    Private Sub AssertCheck(ByVal condition As Boolean, ByVal code As String)
        If Not condition Then Throw New InvalidOperationException(code)
        _checks += 1
        Console.Out.WriteLine("PASS " & code)
    End Sub

    Public Function Main() As Integer
        AssertCheck(Not PayPalProductionSafetyPolicy.IsApiCallAllowed("sandbox", True, False, False),
                    "01_PUBLIC_SANDBOX_BLOCKED")
        AssertCheck(Not PayPalProductionSafetyPolicy.IsApiCallAllowed("live", True, False, False),
                    "02_PUBLIC_LIVE_ALLOW_FALSE_BLOCKED")
        AssertCheck(Not PayPalProductionSafetyPolicy.IsApiCallAllowed("live", False, True, False),
                    "03_PUBLIC_LIVE_INCOMPLETE_BLOCKED")
        AssertCheck(PayPalProductionSafetyPolicy.IsApiCallAllowed("live", True, True, False),
                    "04_PUBLIC_LIVE_COMPLETE_ALLOWED")
        AssertCheck(PayPalProductionSafetyPolicy.IsApiCallAllowed("sandbox", True, False, True),
                    "05_LOCAL_SANDBOX_ALLOWED")
        AssertCheck(Not PayPalProductionSafetyPolicy.IsApiCallAllowed("sandbox", False, False, True),
                    "06_LOCAL_SANDBOX_INCOMPLETE_BLOCKED")
        AssertCheck(Not PayPalProductionSafetyPolicy.IsApiCallAllowed("unknown", True, True, True),
                    "07_UNKNOWN_ENVIRONMENT_BLOCKED")
        Console.Out.WriteLine("PAYPAL_PRODUCTION_SAFETY_PASS checks=" & _checks.ToString())
        Return 0
    End Function
End Module
