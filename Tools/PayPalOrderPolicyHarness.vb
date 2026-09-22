Option Strict On
Option Explicit On

Imports System

Module PayPalOrderPolicyHarness
    Private count As Integer

    Private Sub Check(ByVal name As String, ByVal actual As Boolean, ByVal expected As Boolean)
        If actual <> expected Then Throw New InvalidOperationException("PAYPAL_REV2_FAIL " & name)
        count += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Private Function Eligible(ByVal origin As String, Optional ByVal owner As Boolean = True,
                              Optional ByVal tenant As Boolean = True, Optional ByVal orderType As Boolean = True,
                              Optional ByVal paid As Integer = 0, Optional ByVal documentState As Integer = 1,
                              Optional ByVal paymentState As Integer = 0, Optional ByVal online As Integer = 2,
                              Optional ByVal later As Integer = 1, Optional ByVal authorized As Boolean = False,
                              Optional ByVal total As Decimal = 10D) As Boolean
        Return InternalOrderRemotePaymentPolicy.CanPayNow(origin, owner, tenant, orderType, paid,
            documentState, paymentState, online, later, authorized, total)
    End Function

    Sub Main()
        Check("WEB PayPal unpaid", Eligible("WEB"), False)
        Check("WEB Sella unpaid", Eligible("WEB", online:=3), False)
        Check("INTERNO PayPal", Eligible("INTERNO"), True)
        Check("INTERNO Sella", Eligible("INTERNO", online:=3), True)
        Check("paid", Eligible("INTERNO", paid:=1), False)
        Check("other owner", Eligible("INTERNO", owner:=False), False)
        Check("other tenant", Eligible("INTERNO", tenant:=False), False)
        Check("unknown", Eligible("UNKNOWN"), False)
        Check("null", Eligible(Nothing), False)
        Check("imported Amazon", Eligible("AMAZON"), False)
        Check("imported Ebay", Eligible("EBAY"), False)
        Check("invalid order type", Eligible("INTERNO", orderType:=False), False)
        Check("canceled document", Eligible("INTERNO", documentState:=3), False)
        Check("zero total", Eligible("INTERNO", total:=0D), False)
        Check("offline payment", Eligible("INTERNO", online:=0), False)
        Check("other online", Eligible("INTERNO", online:=1), False)
        Check("later disabled", Eligible("INTERNO", later:=0), False)
        Check("gateway authorized", Eligible("INTERNO", authorized:=True), False)
        Check("payment completed", Eligible("INTERNO", paymentState:=2), False)
        Check("payment pending can reconcile", Eligible("INTERNO", paymentState:=1), True)
        Check("cancel then CREATED", PayPalAttemptPolicy.MaySupersede("INTERNO", "CANCELED", "CREATED", ""), True)
        Check("failed then VOIDED", PayPalAttemptPolicy.MaySupersede("INTERNO", "FAILED", "VOIDED", ""), True)
        Check("voided", PayPalAttemptPolicy.MaySupersede("INTERNO", "CREATED", "VOIDED", ""), True)
        Check("web cannot retry", PayPalAttemptPolicy.MaySupersede("WEB", "CANCELED", "CREATED", ""), False)
        Check("approved cannot retry", PayPalAttemptPolicy.MaySupersede("INTERNO", "CANCELED", "APPROVED", ""), False)
        Check("pending cannot retry", PayPalAttemptPolicy.MaySupersede("INTERNO", "FAILED", "PENDING", ""), False)
        Check("completed cannot retry", PayPalAttemptPolicy.MaySupersede("INTERNO", "FAILED", "COMPLETED", "COMPLETED"), False)
        Check("ambiguous capture cannot retry", PayPalAttemptPolicy.MaySupersede("INTERNO", "CANCELED", "CREATED", "PENDING"), False)
        Check("not terminal cannot retry", PayPalAttemptPolicy.MaySupersede("INTERNO", "CREATED", "CREATED", ""), False)
        Check("capture in flight cannot retry", PayPalAttemptPolicy.MaySupersede("INTERNO", "CAPTURING", "VOIDED", ""), False)
        Console.WriteLine("PAYPAL_REV2_POLICY_TOTAL=" & count)
    End Sub
End Module
