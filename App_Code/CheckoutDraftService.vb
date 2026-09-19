Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

<Serializable()>
Public NotInheritable Class CheckoutDraftState
    Public Property Version As Integer
    Public Property IssuedUtc As DateTime
    Public Property ExpiresUtc As DateTime
    Public Property DatabaseScopeKey As String
    Public Property CompanyId As Integer
    Public Property LoginId As Long
    Public Property UtentiId As Long
    Public Property BillingAddressId As Long
    Public Property ShippingAddressId As Integer
    Public Property TipoDocumentiId As Integer
    Public Property DeliveryMethodId As Integer
    Public Property PaymentMethodId As Integer
    Public Property PaymentOnline As Integer
    Public Property ConfirmBeforePayment As Integer
    Public Property AllowLaterPayment As Integer
    Public Property SendEmailBeforePayment As Integer
    Public Property InsuranceSelected As Boolean
    Public Property Notes As String
    Public Property CouponCode As String
    Public Property CouponDescription As String
    Public Property CouponTaxableTotal As Decimal
    Public Property CouponVatId As Integer
    Public Property CouponVatValue As Decimal
    Public Property CouponRounding As Decimal
    Public Property ReverseChargeVat As Decimal
    Public Property CarrierVat As Decimal
    Public Property CouponFingerprint As String
    Public Property CartFingerprint As String
    Public Property OptionsFingerprint As String
    Public Property PayloadFingerprint As String
    Public Property RequestId As String
    Public Property Subtotal As Decimal
    Public Property Vat As Decimal
    Public Property ShippingCost As Decimal
    Public Property InsuranceCost As Decimal
    Public Property PaymentCost As Decimal
    Public Property Discount As Decimal
    Public Property DiscountVat As Decimal
    Public Property Total As Decimal
    Public Property Fingerprint As String
End Class

''' <summary>
''' Server-side authoritative checkout draft. The browser receives only the
''' existing opaque MachineKey token; addresses, notes and coupon values never
''' enter the query string. A draft is bound to database/company/login/user,
''' request id, cart/options fingerprints, version and expiry.
''' </summary>
Public NotInheritable Class CheckoutDraftService
    Public Const CurrentVersion As Integer = 4
    Public Shared ReadOnly Lifetime As TimeSpan = TimeSpan.FromMinutes(30)
    Private Const SessionKey As String = "KeepStore:CheckoutDraft:Current"

    Private Sub New()
    End Sub

    Public Shared Function Seal(ByVal draft As CheckoutDraftState) As CheckoutDraftState
        If draft Is Nothing Then Throw New ArgumentNullException("draft")
        draft.Version = CurrentVersion
        If draft.IssuedUtc.Kind <> DateTimeKind.Utc Then draft.IssuedUtc = draft.IssuedUtc.ToUniversalTime()
        If draft.ExpiresUtc.Kind <> DateTimeKind.Utc Then draft.ExpiresUtc = draft.ExpiresUtc.ToUniversalTime()
        draft.Fingerprint = ComputeFingerprint(draft)
        Return draft
    End Function

    Public Shared Sub Store(ByVal context As HttpContext, ByVal draft As CheckoutDraftState)
        If context Is Nothing OrElse context.Session Is Nothing Then Throw New InvalidOperationException("Checkout session is not available.")
        If Not IsStructurallyValid(draft, Nothing, String.Empty, String.Empty) Then
            Throw New InvalidOperationException("Checkout draft is not valid.")
        End If
        context.Session(SessionKey) = CloneDraft(draft)
    End Sub

    Public Shared Function TryRead(ByVal context As HttpContext,
                                   ByVal identity As OrderStorefrontIdentity,
                                   ByVal requestId As String,
                                   ByVal expectedFingerprint As String,
                                   ByRef result As CheckoutDraftState) As Boolean
        result = Nothing
        If context Is Nothing OrElse context.Session Is Nothing Then Return False
        Dim stored As CheckoutDraftState = TryCast(context.Session(SessionKey), CheckoutDraftState)
        If Not IsStructurallyValid(stored, identity, requestId, expectedFingerprint) Then Return False
        result = CloneDraft(stored)
        Return True
    End Function

    Public Shared Function TryReadSelectionForRetry(ByVal context As HttpContext,
                                                    ByVal identity As OrderStorefrontIdentity,
                                                    ByRef result As CheckoutDraftState) As Boolean
        result = Nothing
        If context Is Nothing OrElse context.Session Is Nothing Then Return False
        Dim stored As CheckoutDraftState = TryCast(context.Session(SessionKey), CheckoutDraftState)
        If Not IsStructurallyValid(stored, identity, String.Empty, String.Empty) Then Return False
        result = CloneDraft(stored)
        Return True
    End Function

    Public Shared Sub Clear(ByVal context As HttpContext)
        If context IsNot Nothing AndAlso context.Session IsNot Nothing Then context.Session.Remove(SessionKey)
    End Sub

    Public Shared Function ComputeFingerprint(ByVal draft As CheckoutDraftState) As String
        If draft Is Nothing Then Return String.Empty
        Return OrderDurableIdempotencyService.ComputePayloadFingerprint(
            "checkout-draft", draft.Version, draft.IssuedUtc.Ticks, draft.ExpiresUtc.Ticks,
            draft.DatabaseScopeKey, draft.CompanyId, draft.LoginId, draft.UtentiId,
            draft.BillingAddressId, draft.ShippingAddressId, draft.TipoDocumentiId, draft.DeliveryMethodId,
            draft.PaymentMethodId, draft.PaymentOnline, draft.ConfirmBeforePayment,
            draft.AllowLaterPayment, draft.SendEmailBeforePayment,
            draft.InsuranceSelected, draft.Notes, draft.CouponCode,
            draft.CouponDescription, draft.CouponTaxableTotal, draft.CouponVatId,
            draft.CouponVatValue, draft.CouponRounding, draft.ReverseChargeVat, draft.CarrierVat,
            draft.CouponFingerprint, draft.CartFingerprint, draft.OptionsFingerprint,
            draft.PayloadFingerprint, draft.RequestId, draft.Subtotal, draft.Vat,
            draft.ShippingCost, draft.InsuranceCost, draft.PaymentCost, draft.Discount,
            draft.DiscountVat, draft.Total)
    End Function

    Public Shared Function ValidateAuthoritativeSelections(ByVal connection As MySqlConnection,
                                                           ByVal transaction As MySqlTransaction,
                                                           ByVal identity As OrderStorefrontIdentity,
                                                           ByVal draft As CheckoutDraftState,
                                                           ByRef failureReason As CheckoutFailureReason) As Boolean
        failureReason = CheckoutFailureReason.CartInvalid
        If connection Is Nothing OrElse identity Is Nothing OrElse draft Is Nothing Then Return False
        Dim address As CheckoutAddressSnapshot = Nothing
        If Not CheckoutAddressService.TryResolve(connection, transaction, identity, draft.ShippingAddressId, address) Then
            failureReason = CheckoutFailureReason.ShippingAddressInvalid
            Return False
        End If
        Const deliverySql As String =
            "SELECT COUNT(DISTINCT id) FROM vettori " &
            "WHERE id=?id AND AziendeId=?aziendaId AND Abilitato=1 AND Web=1"
        Using command As New MySqlCommand(deliverySql, connection, transaction)
            command.Parameters.Add("?id", MySqlDbType.Int32).Value = draft.DeliveryMethodId
            command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = identity.CompanyId
            If Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture) <> 1 Then
                failureReason = CheckoutFailureReason.ShippingMethodMissing
                Return False
            End If
        End Using
        Const paymentSql As String =
            "SELECT COUNT(DISTINCT id) FROM vpagamentitipo " &
            "WHERE id=?id AND AziendeId=?aziendaId AND Abilitato=1 " &
            "AND CostoMassimo>=?total AND (Web=1 OR UtenteID=?utentiId)"
        Using command As New MySqlCommand(paymentSql, connection, transaction)
            command.Parameters.Add("?id", MySqlDbType.Int32).Value = draft.PaymentMethodId
            command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = identity.CompanyId
            command.Parameters.Add("?total", MySqlDbType.Decimal).Value = draft.Total
            command.Parameters.Add("?utentiId", MySqlDbType.Int64).Value = identity.UtentiId
            If Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture) <> 1 Then
                failureReason = CheckoutFailureReason.PaymentMethodMissing
                Return False
            End If
        End Using
        Return True
    End Function

    Private Shared Function IsStructurallyValid(ByVal draft As CheckoutDraftState,
                                                ByVal identity As OrderStorefrontIdentity,
                                                ByVal requestId As String,
                                                ByVal expectedFingerprint As String) As Boolean
        If draft Is Nothing OrElse draft.Version <> CurrentVersion Then Return False
        If draft.IssuedUtc = DateTime.MinValue OrElse draft.ExpiresUtc <= DateTime.UtcNow OrElse
           draft.ExpiresUtc <= draft.IssuedUtc OrElse draft.ExpiresUtc.Subtract(draft.IssuedUtc) > Lifetime.Add(TimeSpan.FromMinutes(1)) Then Return False
        Dim normalizedRequest As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizeRequestId(draft.RequestId, normalizedRequest) Then Return False
        If Not String.IsNullOrEmpty(requestId) Then
            Dim expectedRequest As String = String.Empty
            If Not OrderDurableIdempotencyService.TryNormalizeRequestId(requestId, expectedRequest) OrElse
               Not String.Equals(normalizedRequest, expectedRequest, StringComparison.Ordinal) Then Return False
        End If
        If draft.CompanyId <= 0 OrElse draft.LoginId <= 0 OrElse draft.UtentiId <= 0 OrElse
           draft.BillingAddressId <> draft.UtentiId OrElse draft.ShippingAddressId < 0 OrElse
           draft.TipoDocumentiId <= 0 OrElse draft.DeliveryMethodId = 0 OrElse draft.PaymentMethodId <= 0 OrElse
           String.IsNullOrEmpty(draft.DatabaseScopeKey) Then Return False
        Dim normalized As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizePayloadFingerprint(draft.CartFingerprint, normalized) Then Return False
        If Not OrderDurableIdempotencyService.TryNormalizePayloadFingerprint(draft.OptionsFingerprint, normalized) Then Return False
        If Not OrderDurableIdempotencyService.TryNormalizePayloadFingerprint(draft.PayloadFingerprint, normalized) Then Return False
        If Not OrderDurableIdempotencyService.TryNormalizePayloadFingerprint(draft.CouponFingerprint, normalized) Then Return False
        If identity IsNot Nothing Then
            If Not identity.IsComplete OrElse
               Not String.Equals(draft.DatabaseScopeKey, identity.DatabaseScopeKey, StringComparison.Ordinal) OrElse
               draft.CompanyId <> identity.CompanyId OrElse draft.LoginId <> identity.LoginId OrElse
               draft.UtentiId <> identity.UtentiId Then Return False
        End If
        Dim actualFingerprint As String = ComputeFingerprint(draft)
        If Not String.Equals(actualFingerprint, draft.Fingerprint, StringComparison.Ordinal) Then Return False
        If Not String.IsNullOrEmpty(expectedFingerprint) AndAlso
           Not String.Equals(actualFingerprint, expectedFingerprint, StringComparison.Ordinal) Then Return False
        Return True
    End Function

    Private Shared Function CloneDraft(ByVal source As CheckoutDraftState) As CheckoutDraftState
        If source Is Nothing Then Return Nothing
        Return New CheckoutDraftState() With {
            .Version = source.Version,
            .IssuedUtc = source.IssuedUtc,
            .ExpiresUtc = source.ExpiresUtc,
            .DatabaseScopeKey = source.DatabaseScopeKey,
            .CompanyId = source.CompanyId,
            .LoginId = source.LoginId,
            .UtentiId = source.UtentiId,
            .BillingAddressId = source.BillingAddressId,
            .ShippingAddressId = source.ShippingAddressId,
            .TipoDocumentiId = source.TipoDocumentiId,
            .DeliveryMethodId = source.DeliveryMethodId,
            .PaymentMethodId = source.PaymentMethodId,
            .PaymentOnline = source.PaymentOnline,
            .ConfirmBeforePayment = source.ConfirmBeforePayment,
            .AllowLaterPayment = source.AllowLaterPayment,
            .SendEmailBeforePayment = source.SendEmailBeforePayment,
            .InsuranceSelected = source.InsuranceSelected,
            .Notes = source.Notes,
            .CouponCode = source.CouponCode,
            .CouponDescription = source.CouponDescription,
            .CouponTaxableTotal = source.CouponTaxableTotal,
            .CouponVatId = source.CouponVatId,
            .CouponVatValue = source.CouponVatValue,
            .CouponRounding = source.CouponRounding,
            .ReverseChargeVat = source.ReverseChargeVat,
            .CarrierVat = source.CarrierVat,
            .CouponFingerprint = source.CouponFingerprint,
            .CartFingerprint = source.CartFingerprint,
            .OptionsFingerprint = source.OptionsFingerprint,
            .PayloadFingerprint = source.PayloadFingerprint,
            .RequestId = source.RequestId,
            .Subtotal = source.Subtotal,
            .Vat = source.Vat,
            .ShippingCost = source.ShippingCost,
            .InsuranceCost = source.InsuranceCost,
            .PaymentCost = source.PaymentCost,
            .Discount = source.Discount,
            .DiscountVat = source.DiscountVat,
            .Total = source.Total,
            .Fingerprint = source.Fingerprint
        }
    End Function
End Class
