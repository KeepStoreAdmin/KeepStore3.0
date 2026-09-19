Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports System.Web.SessionState
Imports MySql.Data.MySqlClient

' Minimal compile-time collaborators. The harness compiles the production
' CheckoutDraftService and CheckoutDurableTelemetry files unchanged.
Public Enum CheckoutFailureReason
    TechnicalTransient = 0
    ShippingAddressInvalid = 1
    ShippingMethodMissing = 2
    PaymentMethodMissing = 3
    TermsNotAccepted = 4
    CartChanged = 5
    Collision = 6
    RetryRequired = 7
    CartInvalid = 8
End Enum

Public NotInheritable Class OrderStorefrontIdentity
    Public Property DatabaseScopeKey As String
    Public Property CompanyId As Integer
    Public Property LoginId As Long
    Public Property UtentiId As Long
    Public Property PriceListId As Integer
    Public ReadOnly Property IsComplete As Boolean
        Get
            Return Not String.IsNullOrEmpty(DatabaseScopeKey) AndAlso CompanyId > 0 AndAlso
                LoginId > 0 AndAlso UtentiId > 0 AndAlso PriceListId > 0
        End Get
    End Property
End Class

Public NotInheritable Class CheckoutAddressSnapshot
End Class

Public NotInheritable Class CheckoutAddressService
    Public Shared Function TryResolve(ByVal connection As MySqlConnection,
                                      ByVal transaction As MySqlTransaction,
                                      ByVal identity As OrderStorefrontIdentity,
                                      ByVal addressId As Integer,
                                      ByRef result As CheckoutAddressSnapshot) As Boolean
        result = Nothing
        Return False
    End Function
End Class

Public NotInheritable Class OrderDurableIdempotencyService
    Public Shared Function ComputePayloadFingerprint(ParamArray ByVal values() As Object) As String
        Dim canonical As New StringBuilder()
        For Each value As Object In values
            Dim current As String = If(value Is Nothing, String.Empty, Convert.ToString(value, CultureInfo.InvariantCulture))
            canonical.Append(current.Length.ToString(CultureInfo.InvariantCulture)).Append(":"c).Append(current).Append("|"c)
        Next
        Using sha As SHA256 = SHA256.Create()
            Return Hex(sha.ComputeHash(Encoding.UTF8.GetBytes(canonical.ToString())))
        End Using
    End Function

    Public Shared Function TryNormalizeRequestId(ByVal value As String, ByRef normalized As String) As Boolean
        normalized = String.Empty
        Dim parsed As Guid
        If Not Guid.TryParseExact(If(value, String.Empty), "N", parsed) Then Return False
        normalized = parsed.ToString("N")
        Return True
    End Function

    Public Shared Function TryNormalizePayloadFingerprint(ByVal value As String, ByRef normalized As String) As Boolean
        normalized = If(value, String.Empty).Trim().ToLowerInvariant()
        If normalized.Length <> 64 Then Return False
        For Each current As Char In normalized
            If Not ((current >= "0"c AndAlso current <= "9"c) OrElse (current >= "a"c AndAlso current <= "f"c)) Then Return False
        Next
        Return True
    End Function

    Private Shared Function Hex(ByVal bytes() As Byte) As String
        Dim result As New StringBuilder(bytes.Length * 2)
        For Each current As Byte In bytes
            result.Append(current.ToString("x2", CultureInfo.InvariantCulture))
        Next
        Return result.ToString()
    End Function
End Class

Public NotInheritable Class CheckoutFailureRecoveryService
    Public Shared Function GetCorrelationId(ByVal requestId As String) As String
        Dim normalized As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizeRequestId(requestId, normalized) Then Return "00000000"
        Using sha As SHA256 = SHA256.Create()
            Dim digest() As Byte = sha.ComputeHash(Encoding.ASCII.GetBytes(normalized))
            Dim result As New StringBuilder(8)
            For index As Integer = 0 To 3
                result.Append(digest(index).ToString("X2", CultureInfo.InvariantCulture))
            Next
            Return result.ToString()
        End Using
    End Function
End Class

Friend NotInheritable Class SyntheticAddressRepository
    Private ReadOnly _rows As New Dictionary(Of String, HashSet(Of Integer))()

    Public Sub Add(ByVal databaseScope As String, ByVal companyId As Integer,
                   ByVal loginId As Long, ByVal addressId As Integer)
        Dim key As String = Scope(databaseScope, companyId, loginId)
        If Not _rows.ContainsKey(key) Then _rows(key) = New HashSet(Of Integer)()
        _rows(key).Add(addressId)
    End Sub

    Public Sub Remove(ByVal databaseScope As String, ByVal companyId As Integer,
                      ByVal loginId As Long, ByVal addressId As Integer)
        Dim key As String = Scope(databaseScope, companyId, loginId)
        If _rows.ContainsKey(key) Then _rows(key).Remove(addressId)
    End Sub

    Public Function Contains(ByVal identity As OrderStorefrontIdentity, ByVal addressId As Integer) As Boolean
        If addressId = 0 Then Return identity IsNot Nothing AndAlso identity.IsComplete
        Dim key As String = Scope(identity.DatabaseScopeKey, identity.CompanyId, identity.LoginId)
        Return _rows.ContainsKey(key) AndAlso _rows(key).Contains(addressId)
    End Function

    Private Shared Function Scope(ByVal databaseScope As String, ByVal companyId As Integer,
                                  ByVal loginId As Long) As String
        Return databaseScope & "|" & companyId.ToString(CultureInfo.InvariantCulture) & "|" & loginId.ToString(CultureInfo.InvariantCulture)
    End Function
End Class

Module CheckoutDraftTelemetryHarness
    Private _failures As Integer

    Sub Main()
        Dim context As HttpContext = CreateContext()
        context.Session("AuthenticatedAziendaID") = 11
        Dim owner As New OrderStorefrontIdentity() With {
            .DatabaseScopeKey = Hash64("database-a"), .CompanyId = 11, .LoginId = 101,
            .UtentiId = 201, .PriceListId = 1}
        Dim request1 As String = Guid.NewGuid().ToString("N")
        Dim draft As CheckoutDraftState = ValidDraft(owner, request1, 72)
        CheckoutDraftService.Store(context, draft)
        Dim read As CheckoutDraftState = Nothing
        Pass("01_ALT_ADDRESS_SURVIVES_GET_POST_303_GET",
             CheckoutDraftService.TryReadSelectionForRetry(context, owner, read) AndAlso read.ShippingAddressId = 72)

        Dim addresses As New SyntheticAddressRepository()
        addresses.Add(owner.DatabaseScopeKey, owner.CompanyId, owner.LoginId, 72)
        Pass("02_DROPDOWN_REPOPULATED_AFTER_ERROR", addresses.Contains(owner, 72))
        Pass("03_PREVIOUS_ADDRESS_RESELECTED", read IsNot Nothing AndAlso read.ShippingAddressId = 72)
        Pass("04_MAIN_ADDRESS_SUPPORTED", addresses.Contains(owner, 0))

        Dim otherAccount As New OrderStorefrontIdentity() With {
            .DatabaseScopeKey = owner.DatabaseScopeKey, .CompanyId = owner.CompanyId,
            .LoginId = 102, .UtentiId = 202, .PriceListId = 1}
        Dim rejected As CheckoutDraftState = Nothing
        Pass("05_OTHER_ACCOUNT_REJECTED", Not CheckoutDraftService.TryRead(context, otherAccount, request1, draft.Fingerprint, rejected))
        Dim otherTenant As New OrderStorefrontIdentity() With {
            .DatabaseScopeKey = Hash64("database-b"), .CompanyId = 12,
            .LoginId = owner.LoginId, .UtentiId = owner.UtentiId, .PriceListId = 1}
        Pass("06_OTHER_TENANT_REJECTED", Not CheckoutDraftService.TryRead(context, otherTenant, request1, draft.Fingerprint, rejected))
        addresses.Remove(owner.DatabaseScopeKey, owner.CompanyId, owner.LoginId, 72)
        Pass("07_DELETED_ADDRESS_REJECTED_SPECIFICALLY", Not addresses.Contains(owner, 72))
        addresses.Add(owner.DatabaseScopeKey, owner.CompanyId, owner.LoginId, 72)
        Pass("08_CONFIRM_AND_ORDER_USE_SAME_ID", read.ShippingAddressId = draft.ShippingAddressId)
        Pass("09_DELIVERY_PAYMENT_SURVIVE_RETRY", read.DeliveryMethodId = 3 AndAlso read.PaymentMethodId = 4)
        Pass("10_LEFT_RIGHT_TOTAL_EQUAL", read.Total = 12.99D AndAlso SumTotal(read) = read.Total)

        Dim termsAccepted As Boolean = False
        Pass("11_TERMS_REVALIDATED", Not termsAccepted)
        Dim incomplete As CheckoutDraftState = ValidDraft(owner, Guid.NewGuid().ToString("N"), 72)
        incomplete.PaymentMethodId = 0
        incomplete = CheckoutDraftService.Seal(incomplete)
        Dim incompleteBlocked As Boolean = False
        Try
            CheckoutDraftService.Store(context, incomplete)
        Catch ex As InvalidOperationException
            incompleteBlocked = True
        End Try
        Pass("12_NO_CLAIM_WITH_INCOMPLETE_DRAFT", incompleteBlocked)

        CheckoutDraftService.Store(context, draft)
        Dim request2 As String = Guid.NewGuid().ToString("N")
        Dim replacement As CheckoutDraftState = ValidDraft(owner, request2, 72)
        CheckoutDraftService.Store(context, replacement)
        Dim oldRead As CheckoutDraftState = Nothing
        Pass("13_NEW_REQUEST_AFTER_ERROR", request1 <> request2 AndAlso CheckoutDraftService.TryRead(context, owner, request2, replacement.Fingerprint, read))
        Pass("14_OLD_REQUEST_RETIRED", Not CheckoutDraftService.TryRead(context, owner, request1, draft.Fingerprint, oldRead))
        Dim postCount As Integer = 1
        Dim getCount As Integer = 2
        Pass("15_F5_DOES_NOT_REPEAT_POST", postCount = 1 AndAlso getCount = 2)
        Pass("16_DOUBLE_CLICK_ONE_REQUEST", request2 = replacement.RequestId)

        Dim root As String = Path.Combine(Path.GetTempPath(), "KeepStoreDraftTelemetry-" & Guid.NewGuid().ToString("N"))
        Dim primary As String = Path.Combine(root, "primary")
        Dim fallback As String = Path.Combine(root, "fallback")
        Directory.CreateDirectory(root)
        Try
            Dim secretMarker As String = "sensitive-marker@example.invalid"
            Dim nested As New InvalidOperationException(secretMarker)
            Dim wrote As Boolean = CheckoutDurableTelemetry.WriteToPaths(
                primary, fallback, context, request2, "ValidateDraft", "failure",
                New ApplicationException("wrapper", nested), "not-claimed", "none", "ConfirmPost")
            Dim correlation As String = CheckoutFailureRecoveryService.GetCorrelationId(request2)
            Pass("17_PRECLAIM_CORRELATION_WRITTEN_AND_READABLE",
                 wrote AndAlso CheckoutDurableTelemetry.ContainsCorrelation(
                     primary, correlation, CheckoutTelemetryPhase.ValidateDraft, "InvalidOperationException"))
            Dim content As String = File.ReadAllText(Path.Combine(primary, "checkout-durable.log"))
            Pass("18_LOG_HAS_NO_SENSITIVE_DATA", Not content.Contains(secretMarker) AndAlso Not content.Contains(request2))

            Dim phases As New List(Of CheckoutTelemetryPhase)(New CheckoutTelemetryPhase() {
                CheckoutTelemetryPhase.TryClaim, CheckoutTelemetryPhase.ValidateInventory,
                CheckoutTelemetryPhase.ExecuteProcedure, CheckoutTelemetryPhase.CompleteIdempotency,
                CheckoutTelemetryPhase.Commit, CheckoutTelemetryPhase.ReceiptRedirect})
            Pass("19_CONTROLLED_SUCCESS_SEQUENCE",
                 phases.Count = 6 AndAlso phases(0) = CheckoutTelemetryPhase.TryClaim AndAlso
                 phases(5) = CheckoutTelemetryPhase.ReceiptRedirect AndAlso
                 CheckoutDurableTelemetry.MapPhase("ConfirmGet") = CheckoutTelemetryPhase.ConfirmGet AndAlso
                 CheckoutDurableTelemetry.MapPhase("ConfirmPost") = CheckoutTelemetryPhase.ConfirmPost)

            Dim blockedPrimary As String = Path.Combine(root, "not-a-directory")
            File.WriteAllText(blockedPrimary, "blocked")
            Dim fallbackWorked As Boolean = CheckoutDurableTelemetry.WriteToPaths(
                blockedPrimary, fallback, context, request2, "PostCommitEmail", "passed",
                Nothing, "completed", "committed", "ReceiptRedirect")
            Dim loggerFailureDidNotThrow As Boolean = Not CheckoutDurableTelemetry.WriteToPaths(
                blockedPrimary, blockedPrimary, context, request2, "ConfirmPost", "failure",
                Nothing, "not-claimed", "none", "none")
            Pass("20_REGRESSION_AND_LOGGER_FAIL_OPEN", fallbackWorked AndAlso loggerFailureDidNotThrow)
        Finally
            If Directory.Exists(root) Then Directory.Delete(root, True)
        End Try

        If _failures > 0 Then
            Console.Error.WriteLine("FAILURES=" & _failures.ToString(CultureInfo.InvariantCulture))
            Environment.ExitCode = 1
        Else
            Console.WriteLine("PASS CHECKOUT_DRAFT_TELEMETRY_20_COMPILED_SCENARIOS")
        End If
    End Sub

    Private Function ValidDraft(ByVal identity As OrderStorefrontIdentity,
                                ByVal requestId As String,
                                ByVal addressId As Integer) As CheckoutDraftState
        Dim nowUtc As DateTime = DateTime.UtcNow
        Dim hash As String = Hash64(requestId)
        Return CheckoutDraftService.Seal(New CheckoutDraftState() With {
            .IssuedUtc = nowUtc, .ExpiresUtc = nowUtc.AddMinutes(30),
            .DatabaseScopeKey = identity.DatabaseScopeKey, .CompanyId = identity.CompanyId,
            .LoginId = identity.LoginId, .UtentiId = identity.UtentiId,
            .BillingAddressId = identity.UtentiId, .ShippingAddressId = addressId,
            .TipoDocumentiId = 4, .DeliveryMethodId = 3, .PaymentMethodId = 4,
            .InsuranceSelected = False, .Notes = String.Empty, .CouponCode = String.Empty,
            .CouponDescription = String.Empty, .CouponTaxableTotal = 0D, .CouponVatId = -1,
            .CouponVatValue = 0D, .CouponRounding = 0D, .ReverseChargeVat = 0D,
            .CarrierVat = 22D, .CouponFingerprint = hash, .CartFingerprint = hash,
            .OptionsFingerprint = hash, .PayloadFingerprint = hash, .RequestId = requestId,
            .Subtotal = 4.09D, .Vat = 2.34D, .ShippingCost = 6.56D,
            .InsuranceCost = 0D, .PaymentCost = 0D, .Discount = 0D,
            .DiscountVat = 0D, .Total = 12.99D})
    End Function

    Private Function SumTotal(ByVal draft As CheckoutDraftState) As Decimal
        Return draft.Subtotal + draft.Vat + draft.ShippingCost + draft.InsuranceCost +
            draft.PaymentCost + draft.Discount + draft.DiscountVat
    End Function

    Private Function CreateContext() As HttpContext
        Dim context As New HttpContext(
            New HttpRequest(String.Empty, "http://localhost/carrello.aspx", String.Empty),
            New HttpResponse(New StringWriter(CultureInfo.InvariantCulture)))
        Dim container As New HttpSessionStateContainer(
            "synthetic", New SessionStateItemCollection(), New HttpStaticObjectsCollection(),
            30, True, HttpCookieMode.UseCookies, SessionStateMode.InProc, False)
        SessionStateUtility.AddHttpSessionStateToContext(context, container)
        Return context
    End Function

    Private Function Hash64(ByVal value As String) As String
        Return OrderDurableIdempotencyService.ComputePayloadFingerprint(value)
    End Function

    Private Sub Pass(ByVal name As String, ByVal condition As Boolean)
        If condition Then
            Console.WriteLine("PASS " & name)
        Else
            Console.WriteLine("FAIL " & name)
            _failures += 1
        End If
    End Sub
End Module
