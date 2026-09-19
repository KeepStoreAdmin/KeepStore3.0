Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Threading

Friend Enum SyntheticClaimState
    Missing = 0
    Pending = 1
    RetryRequired = 2
    Completed = 3
End Enum

Friend Enum SyntheticFailurePoint
    None = 0
    BeforeClaim = 1
    AfterClaimBeforeCommit = 2
    AfterCommit = 3
End Enum

Friend Enum SyntheticCheckoutOutcome
    Confirmation = 0
    FailurePrg = 1
    LoginRequired = 2
    StockFailure = 3
    RetiredRequest = 4
    OwnerCollision = 5
    PendingCollision = 6
End Enum

Friend Enum SyntheticCheckoutFailureReason
    AuthenticationExpired = 0
    AddressInvalid = 1
    ShippingInvalid = 2
    PaymentInvalid = 3
    TermsNotAccepted = 4
    CartChanged = 5
    CommercialTermsChanged = 6
    StockInsufficient = 7
    Collision = 8
    TransientTechnical = 9
    AlreadyCompleted = 10
End Enum

Friend NotInheritable Class SyntheticTenant
    Public DatabaseScope As String
    Public CompanyId As Integer
    Public LoginId As Long
    Public Brand As String

    Public Function OwnerKey() As String
        Return DatabaseScope & "|" &
            CompanyId.ToString(CultureInfo.InvariantCulture) & "|" &
            LoginId.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Function CompanyKey() As String
        Return DatabaseScope & "|" & CompanyId.ToString(CultureInfo.InvariantCulture)
    End Function
End Class

Friend NotInheritable Class SyntheticCheckoutContext
    Public Tenant As SyntheticTenant
    Public IsAuthenticated As Boolean
End Class

Friend NotInheritable Class SyntheticCheckoutSelection
    Public AddressId As Integer
    Public ShippingId As Integer
    Public PaymentId As Integer
    Public TermsAccepted As Boolean

    Public Shared Function Valid() As SyntheticCheckoutSelection
        Return New SyntheticCheckoutSelection() With {
            .AddressId = 101,
            .ShippingId = 201,
            .PaymentId = 301,
            .TermsAccepted = True
        }
    End Function
End Class

Friend NotInheritable Class SyntheticCheckoutPage
    Public RequestId As String
    Public Token As String
    Public Fingerprint As String
    Public DatabaseScope As String
    Public CompanyId As Integer
    Public LoginId As Long
End Class

Friend NotInheritable Class SyntheticClaim
    Public RequestId As String
    Public Fingerprint As String
    Public DatabaseScope As String
    Public CompanyId As Integer
    Public LoginId As Long
    Public State As SyntheticClaimState
    Public DocumentId As Integer
End Class

Friend NotInheritable Class SyntheticDocument
    Public Id As Integer
    Public DatabaseScope As String
    Public CompanyId As Integer
    Public LoginId As Long
    Public Quantity As Integer
End Class

Friend NotInheritable Class SyntheticEmailIntent
    Public DocumentId As Integer
    Public PersistedCompanyId As Integer
    Public Brand As String
End Class

Friend NotInheritable Class SyntheticFailureEnvelope
    Public Reason As SyntheticCheckoutFailureReason
    Public Message As String
    Public CorrelationId As String
    Public RequestId As String
End Class

Friend NotInheritable Class SyntheticFailureRedirect
    Public HttpStatus As Integer
    Public Target As String
    Public CorrelationId As String
End Class

Friend NotInheritable Class SyntheticCheckoutFailureRecoveryService
    Private ReadOnly _retired As New HashSet(Of String)(StringComparer.Ordinal)
    Private _pendingFailure As SyntheticFailureEnvelope
    Private _correlationSequence As Integer

    Public Function RetireAndDispatch(ByVal requestId As String,
                                      ByVal reason As SyntheticCheckoutFailureReason,
                                      ByVal target As String) As SyntheticFailureRedirect
        RetireRequest(requestId)
        Dim correlationId As String = GetCorrelationId()
        _pendingFailure = New SyntheticFailureEnvelope() With {
            .Reason = reason,
            .Message = MessageFor(reason, correlationId),
            .CorrelationId = correlationId,
            .RequestId = requestId
        }
        Return New SyntheticFailureRedirect() With {
            .HttpStatus = 303,
            .Target = target,
            .CorrelationId = correlationId
        }
    End Function

    Public Sub RetireRequest(ByVal requestId As String)
        If Not String.IsNullOrWhiteSpace(requestId) Then _retired.Add(requestId)
    End Sub

    Public Function IsRetiredRequest(ByVal requestId As String) As Boolean
        Return Not String.IsNullOrWhiteSpace(requestId) AndAlso _retired.Contains(requestId)
    End Function

    Public Function TryConsumeFailure(ByRef failure As SyntheticFailureEnvelope) As Boolean
        failure = _pendingFailure
        _pendingFailure = Nothing
        Return failure IsNot Nothing
    End Function

    Public Function GetCorrelationId() As String
        _correlationSequence += 1
        Return "C" & _correlationSequence.ToString("D6", CultureInfo.InvariantCulture)
    End Function

    Public Shared Sub TracePhase(ByVal trace As List(Of String), ByVal phase As String)
        If trace IsNot Nothing Then trace.Add(phase)
    End Sub

    Private Shared Function MessageFor(ByVal reason As SyntheticCheckoutFailureReason,
                                       ByVal correlationId As String) As String
        Select Case reason
            Case SyntheticCheckoutFailureReason.AuthenticationExpired
                Return "Accedi nuovamente per continuare con l'ordine."
            Case SyntheticCheckoutFailureReason.AddressInvalid
                Return "Seleziona un indirizzo di spedizione valido."
            Case SyntheticCheckoutFailureReason.ShippingInvalid
                Return "Seleziona un metodo di spedizione valido."
            Case SyntheticCheckoutFailureReason.PaymentInvalid
                Return "Seleziona un metodo di pagamento valido."
            Case SyntheticCheckoutFailureReason.TermsNotAccepted
                Return "Accetta le condizioni di vendita per continuare."
            Case SyntheticCheckoutFailureReason.CartChanged
                Return "Il carrello è cambiato. Rivedi il riepilogo e riprova."
            Case SyntheticCheckoutFailureReason.CommercialTermsChanged
                Return "Prezzo o promozione sono cambiati. Rivedi il carrello."
            Case SyntheticCheckoutFailureReason.StockInsufficient
                Return "La quantità richiesta non è disponibile."
            Case SyntheticCheckoutFailureReason.Collision
                Return "La richiesta non può essere riutilizzata."
            Case SyntheticCheckoutFailureReason.AlreadyCompleted
                Return "L'ordine è già stato completato."
            Case Else
                Return "Non è stato possibile inviare l'ordine. Riferimento " & correlationId & "."
        End Select
    End Function
End Class

Friend NotInheritable Class SyntheticSubmitResult
    Public Outcome As SyntheticCheckoutOutcome
    Public Reason As SyntheticCheckoutFailureReason
    Public HttpStatus As Integer
    Public RedirectTarget As String
    Public Message As String
    Public CorrelationId As String
    Public DocumentId As Integer
    Public IsReplay As Boolean
    Public ReadOnly Trace As New List(Of String)()
End Class

Friend NotInheritable Class SyntheticGetResult
    Public Page As SyntheticCheckoutPage
    Public FailureVisible As Boolean
    Public FailureMessage As String
    Public CorrelationId As String
End Class

Friend NotInheritable Class SyntheticCartSurfaces
    Public PageQuantity As Integer
    Public MiniCartQuantity As Integer
    Public HeaderQuantity As Integer
End Class

Friend NotInheritable Class SyntheticCheckoutEngine
    Private ReadOnly _gate As New Object()
    Private ReadOnly _carts As New Dictionary(Of String, Integer)(StringComparer.Ordinal)
    Private ReadOnly _claims As New Dictionary(Of String, SyntheticClaim)(StringComparer.Ordinal)
    Private ReadOnly _orders As New List(Of SyntheticDocument)()
    Private ReadOnly _emailIntents As New List(Of SyntheticEmailIntent)()
    Private ReadOnly _tenants As New Dictionary(Of String, SyntheticTenant)(StringComparer.Ordinal)
    Private ReadOnly _recovery As New SyntheticCheckoutFailureRecoveryService()
    Private _inventory As Integer = 20
    Private _requestSequence As Integer
    Private _documentSequence As Integer = 8000
    Private _externalEmailsSent As Integer

    Public ReadOnly Property Recovery As SyntheticCheckoutFailureRecoveryService
        Get
            Return _recovery
        End Get
    End Property

    Public ReadOnly Property Claims As Dictionary(Of String, SyntheticClaim)
        Get
            Return _claims
        End Get
    End Property

    Public ReadOnly Property Orders As List(Of SyntheticDocument)
        Get
            Return _orders
        End Get
    End Property

    Public ReadOnly Property EmailIntents As List(Of SyntheticEmailIntent)
        Get
            Return _emailIntents
        End Get
    End Property

    Public ReadOnly Property ExternalEmailsSent As Integer
        Get
            Return _externalEmailsSent
        End Get
    End Property

    Public Property Inventory As Integer
        Get
            Return _inventory
        End Get
        Set(ByVal value As Integer)
            _inventory = value
        End Set
    End Property

    Public Sub RegisterTenant(ByVal tenant As SyntheticTenant)
        If tenant Is Nothing Then Throw New ArgumentNullException("tenant")
        _tenants(tenant.CompanyKey()) = tenant
    End Sub

    Public Sub SetCart(ByVal context As SyntheticCheckoutContext, ByVal quantity As Integer)
        _carts(OwnerKey(context)) = quantity
    End Sub

    Public Function GetCart(ByVal context As SyntheticCheckoutContext) As Integer
        Return GetCartByOwner(OwnerKey(context))
    End Function

    Public Function NewPage(ByVal context As SyntheticCheckoutContext) As SyntheticCheckoutPage
        If context Is Nothing OrElse context.Tenant Is Nothing Then Throw New ArgumentNullException("context")
        _requestSequence += 1
        Dim requestId As String = "request-" & _requestSequence.ToString("D6", CultureInfo.InvariantCulture)
        Dim fingerprint As String = BuildFingerprint(context)
        Return New SyntheticCheckoutPage() With {
            .RequestId = requestId,
            .Token = "token|" & requestId & "|" & fingerprint,
            .Fingerprint = fingerprint,
            .DatabaseScope = context.Tenant.DatabaseScope,
            .CompanyId = context.Tenant.CompanyId,
            .LoginId = context.Tenant.LoginId
        }
    End Function

    Public Function FollowFailureRedirect(ByVal context As SyntheticCheckoutContext) As SyntheticGetResult
        Dim envelope As SyntheticFailureEnvelope = Nothing
        Dim visible As Boolean = _recovery.TryConsumeFailure(envelope)
        Return New SyntheticGetResult() With {
            .Page = NewPage(context),
            .FailureVisible = visible,
            .FailureMessage = If(envelope Is Nothing, String.Empty, envelope.Message),
            .CorrelationId = If(envelope Is Nothing, String.Empty, envelope.CorrelationId)
        }
    End Function

    Public Function GetReceipt(ByVal context As SyntheticCheckoutContext,
                               ByVal documentId As Integer) As Boolean
        Return CanReadDocument(context, documentId)
    End Function

    Public Function GetSurfaces(ByVal context As SyntheticCheckoutContext) As SyntheticCartSurfaces
        Dim quantity As Integer = GetCart(context)
        Return New SyntheticCartSurfaces() With {
            .PageQuantity = quantity,
            .MiniCartQuantity = quantity,
            .HeaderQuantity = quantity
        }
    End Function

    Public Function CanReadDocument(ByVal context As SyntheticCheckoutContext,
                                    ByVal documentId As Integer) As Boolean
        If context Is Nothing OrElse context.Tenant Is Nothing OrElse Not context.IsAuthenticated Then Return False
        For Each document As SyntheticDocument In _orders
            If document.Id = documentId Then
                Return String.Equals(document.DatabaseScope, context.Tenant.DatabaseScope, StringComparison.Ordinal) AndAlso
                    document.CompanyId = context.Tenant.CompanyId AndAlso
                    document.LoginId = context.Tenant.LoginId
            End If
        Next
        Return False
    End Function

    Public Function Submit(ByVal context As SyntheticCheckoutContext,
                           ByVal page As SyntheticCheckoutPage,
                           ByVal selection As SyntheticCheckoutSelection,
                           ByVal failurePoint As SyntheticFailurePoint) As SyntheticSubmitResult
        SyncLock _gate
            Dim trace As New List(Of String)()
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "CLICK")
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "PAGE_LIFECYCLE_POSTBACK")

            If context Is Nothing OrElse context.Tenant Is Nothing OrElse Not context.IsAuthenticated Then
                Return BuildFailure(page, SyntheticCheckoutFailureReason.AuthenticationExpired,
                                    SyntheticCheckoutOutcome.LoginRequired,
                                    "/carrello.aspx?loginrequired=1#ksCartLoginRequired", trace)
            End If
            If page Is Nothing OrElse Not PageBelongsToContext(page, context) Then
                Return SimpleResult(SyntheticCheckoutOutcome.OwnerCollision,
                                    SyntheticCheckoutFailureReason.Collision, 409, trace)
            End If
            If _recovery.IsRetiredRequest(page.RequestId) Then
                Return SimpleResult(SyntheticCheckoutOutcome.RetiredRequest,
                                    SyntheticCheckoutFailureReason.Collision, 409, trace)
            End If

            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "VALIDATORS")
            If selection Is Nothing OrElse selection.AddressId <= 0 Then
                Return BuildFailure(page, SyntheticCheckoutFailureReason.AddressInvalid,
                                    SyntheticCheckoutOutcome.FailurePrg,
                                    "/carrello.aspx?checkoutfailed=1#ksCheckoutSubmitError", trace)
            End If
            If selection.ShippingId <= 0 Then
                Return BuildFailure(page, SyntheticCheckoutFailureReason.ShippingInvalid,
                                    SyntheticCheckoutOutcome.FailurePrg,
                                    "/carrello.aspx?checkoutfailed=1#ksCheckoutSubmitError", trace)
            End If
            If selection.PaymentId <= 0 Then
                Return BuildFailure(page, SyntheticCheckoutFailureReason.PaymentInvalid,
                                    SyntheticCheckoutOutcome.FailurePrg,
                                    "/carrello.aspx?checkoutfailed=1#ksCheckoutSubmitError", trace)
            End If
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "TERMS")
            If Not selection.TermsAccepted Then
                Return BuildFailure(page, SyntheticCheckoutFailureReason.TermsNotAccepted,
                                    SyntheticCheckoutOutcome.FailurePrg,
                                    "/carrello.aspx?checkoutfailed=1#ksCheckoutSubmitError", trace)
            End If

            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "SELECTION")
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "CHECKOUT_TOKEN")
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "REQUEST_ID")
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "STOREFRONT_CONTEXT")
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "ACCOUNT_VERIFIED")

            Dim existing As SyntheticClaim = Nothing
            If _claims.TryGetValue(page.RequestId, existing) Then
                If Not ClaimBelongsToContext(existing, context) OrElse
                   Not String.Equals(existing.Fingerprint, page.Fingerprint, StringComparison.Ordinal) Then
                    Return SimpleResult(SyntheticCheckoutOutcome.OwnerCollision,
                                        SyntheticCheckoutFailureReason.Collision, 409, trace)
                End If
                If existing.State = SyntheticClaimState.Completed Then
                    SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "RECONCILE_COMPLETED")
                    SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "PRG_RECEIPT")
                    Return Confirmation(existing.DocumentId, True, trace)
                End If
                If existing.State = SyntheticClaimState.RetryRequired Then
                    _recovery.RetireRequest(page.RequestId)
                    Return SimpleResult(SyntheticCheckoutOutcome.RetiredRequest,
                                        SyntheticCheckoutFailureReason.Collision, 409, trace)
                End If
                Return SimpleResult(SyntheticCheckoutOutcome.PendingCollision,
                                    SyntheticCheckoutFailureReason.Collision, 409, trace)
            End If

            If Not String.Equals(page.Fingerprint, BuildFingerprint(context), StringComparison.Ordinal) Then
                Return BuildFailure(page, SyntheticCheckoutFailureReason.CartChanged,
                                    SyntheticCheckoutOutcome.FailurePrg,
                                    "/carrello.aspx?checkoutfailed=1#ksCheckoutSubmitError", trace)
            End If

            Dim quantity As Integer = GetCart(context)
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "STOCK_PRECHECK")
            If quantity <= 0 OrElse quantity > _inventory Then
                Return BuildFailure(page, SyntheticCheckoutFailureReason.StockInsufficient,
                                    SyntheticCheckoutOutcome.StockFailure,
                                    "/carrello.aspx?stockerror=1#ksCartStockError", trace)
            End If

            If failurePoint = SyntheticFailurePoint.BeforeClaim Then
                SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "PRECLAIM_EXCEPTION")
                Return BuildFailure(page, SyntheticCheckoutFailureReason.TransientTechnical,
                                    SyntheticCheckoutOutcome.FailurePrg,
                                    "/carrello.aspx?checkoutfailed=1#ksCheckoutSubmitError", trace)
            End If

            Dim claim As New SyntheticClaim() With {
                .RequestId = page.RequestId,
                .Fingerprint = page.Fingerprint,
                .DatabaseScope = context.Tenant.DatabaseScope,
                .CompanyId = context.Tenant.CompanyId,
                .LoginId = context.Tenant.LoginId,
                .State = SyntheticClaimState.Pending
            }
            _claims.Add(page.RequestId, claim)
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "CLAIM")
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "RECONCILE")
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "CART_REVALIDATION")
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "INVENTORY")

            If failurePoint = SyntheticFailurePoint.AfterClaimBeforeCommit Then
                claim.State = SyntheticClaimState.RetryRequired
                SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "ROLLBACK")
                Return BuildFailure(page, SyntheticCheckoutFailureReason.TransientTechnical,
                                    SyntheticCheckoutOutcome.FailurePrg,
                                    "/carrello.aspx?checkoutfailed=1#ksCheckoutSubmitError", trace)
            End If

            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "PROCEDURE")
            _documentSequence += 1
            Dim document As New SyntheticDocument() With {
                .Id = _documentSequence,
                .DatabaseScope = context.Tenant.DatabaseScope,
                .CompanyId = context.Tenant.CompanyId,
                .LoginId = context.Tenant.LoginId,
                .Quantity = quantity
            }
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "DOCUMENT")
            claim.DocumentId = document.Id
            claim.State = SyntheticClaimState.Completed
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "COMPLETE")

            _orders.Add(document)
            _inventory -= quantity
            _carts(OwnerKey(context)) = 0
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "COMMIT")
            QueueSyntheticEmailIntent(document)
            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "EMAIL_AFTER_COMMIT")

            If failurePoint = SyntheticFailurePoint.AfterCommit Then
                SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "POSTCOMMIT_EXCEPTION")
                SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "RECONCILE_COMPLETED")
            End If

            SyntheticCheckoutFailureRecoveryService.TracePhase(trace, "PRG_RECEIPT")
            Return Confirmation(document.Id, False, trace)
        End SyncLock
    End Function

    Private Sub QueueSyntheticEmailIntent(ByVal document As SyntheticDocument)
        For Each existing As SyntheticEmailIntent In _emailIntents
            If existing.DocumentId = document.Id Then Return
        Next
        Dim tenant As SyntheticTenant = Nothing
        If Not _tenants.TryGetValue(document.DatabaseScope & "|" & document.CompanyId.ToString(CultureInfo.InvariantCulture), tenant) Then
            Throw New InvalidOperationException("Synthetic persisted tenant is missing.")
        End If
        _emailIntents.Add(New SyntheticEmailIntent() With {
            .DocumentId = document.Id,
            .PersistedCompanyId = document.CompanyId,
            .Brand = tenant.Brand
        })
    End Sub

    Private Function BuildFailure(ByVal page As SyntheticCheckoutPage,
                                  ByVal reason As SyntheticCheckoutFailureReason,
                                  ByVal outcome As SyntheticCheckoutOutcome,
                                  ByVal target As String,
                                  ByVal trace As List(Of String)) As SyntheticSubmitResult
        Dim requestId As String = If(page Is Nothing, String.Empty, page.RequestId)
        Dim redirect As SyntheticFailureRedirect = _recovery.RetireAndDispatch(requestId, reason, target)
        Dim envelope As SyntheticFailureEnvelope = Nothing
        ' Peek through the same safe catalog without consuming the one-time envelope.
        Dim result As New SyntheticSubmitResult() With {
            .Outcome = outcome,
            .Reason = reason,
            .HttpStatus = redirect.HttpStatus,
            .RedirectTarget = redirect.Target,
            .CorrelationId = redirect.CorrelationId,
            .Message = String.Empty
        }
        CopyTrace(trace, result.Trace)
        Return result
    End Function

    Private Shared Function SimpleResult(ByVal outcome As SyntheticCheckoutOutcome,
                                         ByVal reason As SyntheticCheckoutFailureReason,
                                         ByVal httpStatus As Integer,
                                         ByVal trace As List(Of String)) As SyntheticSubmitResult
        Dim result As New SyntheticSubmitResult() With {
            .Outcome = outcome,
            .Reason = reason,
            .HttpStatus = httpStatus
        }
        CopyTrace(trace, result.Trace)
        Return result
    End Function

    Private Shared Function Confirmation(ByVal documentId As Integer,
                                         ByVal replay As Boolean,
                                         ByVal trace As List(Of String)) As SyntheticSubmitResult
        Dim result As New SyntheticSubmitResult() With {
            .Outcome = SyntheticCheckoutOutcome.Confirmation,
            .Reason = SyntheticCheckoutFailureReason.AlreadyCompleted,
            .HttpStatus = 303,
            .RedirectTarget = "/ordine.aspx?confirmation=protected",
            .DocumentId = documentId,
            .IsReplay = replay
        }
        CopyTrace(trace, result.Trace)
        Return result
    End Function

    Private Shared Sub CopyTrace(ByVal source As List(Of String), ByVal destination As List(Of String))
        For Each phase As String In source
            destination.Add(phase)
        Next
    End Sub

    Private Function BuildFingerprint(ByVal context As SyntheticCheckoutContext) As String
        Return context.Tenant.DatabaseScope & "|" &
            context.Tenant.CompanyId.ToString(CultureInfo.InvariantCulture) & "|" &
            context.Tenant.LoginId.ToString(CultureInfo.InvariantCulture) & "|" &
            GetCartByOwner(context.Tenant.OwnerKey()).ToString(CultureInfo.InvariantCulture)
    End Function

    Private Shared Function OwnerKey(ByVal context As SyntheticCheckoutContext) As String
        If context Is Nothing OrElse context.Tenant Is Nothing Then Return String.Empty
        Return context.Tenant.OwnerKey()
    End Function

    Private Function GetCartByOwner(ByVal ownerKey As String) As Integer
        Dim quantity As Integer = 0
        _carts.TryGetValue(ownerKey, quantity)
        Return quantity
    End Function

    Private Shared Function PageBelongsToContext(ByVal page As SyntheticCheckoutPage,
                                                 ByVal context As SyntheticCheckoutContext) As Boolean
        Return String.Equals(page.DatabaseScope, context.Tenant.DatabaseScope, StringComparison.Ordinal) AndAlso
            page.CompanyId = context.Tenant.CompanyId AndAlso
            page.LoginId = context.Tenant.LoginId
    End Function

    Private Shared Function ClaimBelongsToContext(ByVal claim As SyntheticClaim,
                                                  ByVal context As SyntheticCheckoutContext) As Boolean
        Return String.Equals(claim.DatabaseScope, context.Tenant.DatabaseScope, StringComparison.Ordinal) AndAlso
            claim.CompanyId = context.Tenant.CompanyId AndAlso
            claim.LoginId = context.Tenant.LoginId
    End Function
End Class

Module CheckoutFailureRecoveryHarness
    Private _failures As Integer

    Private Sub AssertScenario(ByVal condition As Boolean, ByVal code As String)
        If condition Then
            Console.WriteLine("PASS " & code)
        Else
            _failures += 1
            Console.WriteLine("FAIL " & code)
        End If
    End Sub

    Private Function NewTenant(ByVal companyId As Integer,
                               ByVal loginId As Long,
                               ByVal brand As String) As SyntheticTenant
        Return New SyntheticTenant() With {
            .DatabaseScope = "synthetic-db",
            .CompanyId = companyId,
            .LoginId = loginId,
            .Brand = brand
        }
    End Function

    Private Function NewContext(ByVal tenant As SyntheticTenant,
                                Optional ByVal authenticated As Boolean = True) As SyntheticCheckoutContext
        Return New SyntheticCheckoutContext() With {.Tenant = tenant, .IsAuthenticated = authenticated}
    End Function

    Private Function NewEngine(ByVal tenant As SyntheticTenant,
                               ByVal context As SyntheticCheckoutContext,
                               Optional ByVal quantity As Integer = 2) As SyntheticCheckoutEngine
        Dim engine As New SyntheticCheckoutEngine()
        engine.RegisterTenant(tenant)
        engine.SetCart(context, quantity)
        Return engine
    End Function

    Private Function TraceHasOrdered(ByVal trace As List(Of String),
                                     ByVal required() As String) As Boolean
        Dim position As Integer = -1
        For Each phase As String In required
            Dim found As Integer = -1
            For index As Integer = position + 1 To trace.Count - 1
                If String.Equals(trace(index), phase, StringComparison.Ordinal) Then
                    found = index
                    Exit For
                End If
            Next
            If found < 0 Then Return False
            position = found
        Next
        Return True
    End Function

    Public Sub Main()
        Dim resolvedUserId As Long = 0
        Dim resolvedPriceList As Integer = 0
        Dim identicalRows As New List(Of OrderLogicalIdentityRow) From {
            New OrderLogicalIdentityRow() With {.UserId = 501, .PriceListId = 4},
            New OrderLogicalIdentityRow() With {.UserId = 501, .PriceListId = 4}
        }
        AssertScenario(
            OrderLogicalIdentityResolver.TryResolve(identicalRows, resolvedUserId, resolvedPriceList) AndAlso
            resolvedUserId = 501 AndAlso resolvedPriceList = 4,
            "01_IDENTICAL_VLOGIN_ROWS_ONE_LOGICAL_IDENTITY")

        Dim distinctRows As New List(Of OrderLogicalIdentityRow) From {
            New OrderLogicalIdentityRow() With {.UserId = 501, .PriceListId = 4},
            New OrderLogicalIdentityRow() With {.UserId = 501, .PriceListId = 5}
        }
        AssertScenario(
            Not OrderLogicalIdentityResolver.TryResolve(distinctRows, resolvedUserId, resolvedPriceList),
            "02_DIFFERENT_VLOGIN_LOGICAL_ROWS_FAIL_CLOSED")

        Dim tenant3 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context3 As SyntheticCheckoutContext = NewContext(tenant3)
        Dim engine3 As SyntheticCheckoutEngine = NewEngine(tenant3, context3)
        Dim page3 As SyntheticCheckoutPage = engine3.NewPage(context3)
        Dim result3 As SyntheticSubmitResult = engine3.Submit(context3, page3, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            result3.Outcome = SyntheticCheckoutOutcome.Confirmation AndAlso
            result3.HttpStatus = 303 AndAlso engine3.Orders.Count = 1 AndAlso
            engine3.Claims(page3.RequestId).State = SyntheticClaimState.Completed AndAlso
            engine3.Inventory = 18 AndAlso engine3.GetCart(context3) = 0 AndAlso
            TraceHasOrdered(result3.Trace, New String() {"CLAIM", "INVENTORY", "PROCEDURE", "COMPLETE", "COMMIT", "PRG_RECEIPT"}),
            "03_VALID_CHECKOUT_FULL_TRANSACTION_AND_RECEIPT")

        Dim tenant4 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context4 As SyntheticCheckoutContext = NewContext(tenant4)
        Dim engine4 As SyntheticCheckoutEngine = NewEngine(tenant4, context4)
        Dim page4 As SyntheticCheckoutPage = engine4.NewPage(context4)
        Dim selection4 As SyntheticCheckoutSelection = SyntheticCheckoutSelection.Valid()
        selection4.ShippingId = 0
        Dim result4 As SyntheticSubmitResult = engine4.Submit(context4, page4, selection4, SyntheticFailurePoint.None)
        Dim get4 As SyntheticGetResult = engine4.FollowFailureRedirect(context4)
        AssertScenario(
            result4.Reason = SyntheticCheckoutFailureReason.ShippingInvalid AndAlso
            result4.HttpStatus = 303 AndAlso get4.FailureVisible AndAlso
            get4.FailureMessage.IndexOf("spedizione", StringComparison.OrdinalIgnoreCase) >= 0 AndAlso
            engine4.Claims.Count = 0 AndAlso engine4.Orders.Count = 0 AndAlso engine4.GetCart(context4) = 2,
            "04_MISSING_SHIPPING_SPECIFIC_NO_CLAIM")

        Dim tenant5 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context5 As SyntheticCheckoutContext = NewContext(tenant5)
        Dim engine5 As SyntheticCheckoutEngine = NewEngine(tenant5, context5)
        Dim page5 As SyntheticCheckoutPage = engine5.NewPage(context5)
        Dim selection5 As SyntheticCheckoutSelection = SyntheticCheckoutSelection.Valid()
        selection5.PaymentId = 0
        Dim result5 As SyntheticSubmitResult = engine5.Submit(context5, page5, selection5, SyntheticFailurePoint.None)
        Dim get5 As SyntheticGetResult = engine5.FollowFailureRedirect(context5)
        AssertScenario(
            result5.Reason = SyntheticCheckoutFailureReason.PaymentInvalid AndAlso
            result5.HttpStatus = 303 AndAlso get5.FailureVisible AndAlso
            get5.FailureMessage.IndexOf("pagamento", StringComparison.OrdinalIgnoreCase) >= 0 AndAlso
            engine5.Claims.Count = 0 AndAlso engine5.Orders.Count = 0 AndAlso engine5.GetCart(context5) = 2,
            "05_MISSING_PAYMENT_SPECIFIC_NO_CLAIM")

        Dim tenant6 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context6 As SyntheticCheckoutContext = NewContext(tenant6)
        Dim engine6 As SyntheticCheckoutEngine = NewEngine(tenant6, context6)
        Dim page6 As SyntheticCheckoutPage = engine6.NewPage(context6)
        Dim failure6 As SyntheticSubmitResult = engine6.Submit(context6, page6, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.BeforeClaim)
        Dim recovery6 As SyntheticGetResult = engine6.FollowFailureRedirect(context6)
        Dim retry6 As SyntheticSubmitResult = engine6.Submit(context6, recovery6.Page, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            failure6.Outcome = SyntheticCheckoutOutcome.FailurePrg AndAlso
            engine6.Recovery.IsRetiredRequest(page6.RequestId) AndAlso
            recovery6.Page.RequestId <> page6.RequestId AndAlso
            retry6.Outcome = SyntheticCheckoutOutcome.Confirmation AndAlso
            engine6.Orders.Count = 1,
            "06_PRECLAIM_EXCEPTION_CART_PRESERVED_AND_RETRYABLE")

        Dim tenant7 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context7 As SyntheticCheckoutContext = NewContext(tenant7)
        Dim engine7 As SyntheticCheckoutEngine = NewEngine(tenant7, context7)
        Dim page7 As SyntheticCheckoutPage = engine7.NewPage(context7)
        Dim failure7 As SyntheticSubmitResult = engine7.Submit(context7, page7, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.AfterClaimBeforeCommit)
        Dim cartAfterRollback7 As Integer = engine7.GetCart(context7)
        Dim inventoryAfterRollback7 As Integer = engine7.Inventory
        Dim recovery7 As SyntheticGetResult = engine7.FollowFailureRedirect(context7)
        Dim retry7 As SyntheticSubmitResult = engine7.Submit(context7, recovery7.Page, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            failure7.Outcome = SyntheticCheckoutOutcome.FailurePrg AndAlso
            engine7.Claims(page7.RequestId).State = SyntheticClaimState.RetryRequired AndAlso
            cartAfterRollback7 = 2 AndAlso inventoryAfterRollback7 = 20 AndAlso
            recovery7.Page.RequestId <> page7.RequestId AndAlso
            retry7.Outcome = SyntheticCheckoutOutcome.Confirmation AndAlso engine7.Orders.Count = 1,
            "07_POSTCLAIM_PRECOMMIT_ROLLBACK_RETRY_REQUIRED")

        Dim tenant8 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context8 As SyntheticCheckoutContext = NewContext(tenant8)
        Dim engine8 As SyntheticCheckoutEngine = NewEngine(tenant8, context8)
        Dim page8 As SyntheticCheckoutPage = engine8.NewPage(context8)
        Dim result8 As SyntheticSubmitResult = engine8.Submit(context8, page8, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.AfterCommit)
        AssertScenario(
            result8.Outcome = SyntheticCheckoutOutcome.Confirmation AndAlso
            result8.RedirectTarget.IndexOf("ordine.aspx", StringComparison.OrdinalIgnoreCase) >= 0 AndAlso
            engine8.Orders.Count = 1 AndAlso engine8.Claims(page8.RequestId).State = SyntheticClaimState.Completed AndAlso
            result8.Trace.Contains("POSTCOMMIT_EXCEPTION") AndAlso result8.Trace.Contains("RECONCILE_COMPLETED"),
            "08_POSTCOMMIT_ERROR_RECONCILES_TO_CONFIRMATION")

        Dim tenant9 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context9 As SyntheticCheckoutContext = NewContext(tenant9)
        Dim engine9 As SyntheticCheckoutEngine = NewEngine(tenant9, context9)
        Dim page9 As SyntheticCheckoutPage = engine9.NewPage(context9)
        engine9.Submit(context9, page9, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.AfterClaimBeforeCommit)
        Dim recovery9 As SyntheticGetResult = engine9.FollowFailureRedirect(context9)
        AssertScenario(
            engine9.Claims(page9.RequestId).State = SyntheticClaimState.RetryRequired AndAlso
            recovery9.Page.RequestId <> page9.RequestId AndAlso recovery9.Page.Token <> page9.Token AndAlso
            recovery9.Page.Fingerprint = page9.Fingerprint,
            "09_RETRY_REQUIRED_ROTATES_REQUEST_AND_TOKEN")

        Dim tenant10 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context10 As SyntheticCheckoutContext = NewContext(tenant10)
        Dim engine10 As SyntheticCheckoutEngine = NewEngine(tenant10, context10)
        Dim page10 As SyntheticCheckoutPage = engine10.NewPage(context10)
        engine10.Submit(context10, page10, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.BeforeClaim)
        Dim recovery10 As SyntheticGetResult = engine10.FollowFailureRedirect(context10)
        Dim success10 As SyntheticSubmitResult = engine10.Submit(context10, recovery10.Page, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        Dim retired10 As SyntheticSubmitResult = engine10.Submit(context10, page10, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            success10.Outcome = SyntheticCheckoutOutcome.Confirmation AndAlso
            retired10.Outcome = SyntheticCheckoutOutcome.RetiredRequest AndAlso engine10.Orders.Count = 1,
            "10_RETIRED_REQUEST_CANNOT_BLOCK_OR_COMPLETE_NEW_REQUEST")

        Dim tenant11 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context11 As SyntheticCheckoutContext = NewContext(tenant11)
        Dim engine11 As SyntheticCheckoutEngine = NewEngine(tenant11, context11)
        Dim page11 As SyntheticCheckoutPage = engine11.NewPage(context11)
        engine11.Submit(context11, page11, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.BeforeClaim)
        Dim get11a As SyntheticGetResult = engine11.FollowFailureRedirect(context11)
        Dim get11b As SyntheticGetResult = engine11.FollowFailureRedirect(context11)
        AssertScenario(
            get11a.FailureVisible AndAlso Not get11b.FailureVisible AndAlso
            get11a.Page.RequestId <> get11b.Page.RequestId AndAlso
            engine11.Orders.Count = 0 AndAlso engine11.GetCart(context11) = 2,
            "11_PRG_F5_GET_DOES_NOT_REPEAT_POST")

        Dim tenant12 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context12 As SyntheticCheckoutContext = NewContext(tenant12)
        Dim engine12 As SyntheticCheckoutEngine = NewEngine(tenant12, context12)
        Dim page12 As SyntheticCheckoutPage = engine12.NewPage(context12)
        Dim first12 As SyntheticSubmitResult = engine12.Submit(context12, page12, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        Dim receipt12a As Boolean = engine12.GetReceipt(context12, first12.DocumentId)
        Dim receipt12b As Boolean = engine12.GetReceipt(context12, first12.DocumentId)
        Dim replay12 As SyntheticSubmitResult = engine12.Submit(context12, page12, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            receipt12a AndAlso receipt12b AndAlso replay12.IsReplay AndAlso
            replay12.DocumentId = first12.DocumentId AndAlso engine12.Orders.Count = 1,
            "12_BACK_FORWARD_AND_REPLAY_RETURN_SAME_DOCUMENT")

        Dim tenant13 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context13 As SyntheticCheckoutContext = NewContext(tenant13)
        Dim engine13 As SyntheticCheckoutEngine = NewEngine(tenant13, context13)
        Dim page13 As SyntheticCheckoutPage = engine13.NewPage(context13)
        Dim first13 As SyntheticSubmitResult = Nothing
        Dim second13 As SyntheticSubmitResult = Nothing
        Dim thread13a As New Thread(Sub() first13 = engine13.Submit(context13, page13, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None))
        Dim thread13b As New Thread(Sub() second13 = engine13.Submit(context13, page13, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None))
        thread13a.Start()
        thread13b.Start()
        thread13a.Join()
        thread13b.Join()
        AssertScenario(
            first13 IsNot Nothing AndAlso second13 IsNot Nothing AndAlso
            first13.Outcome = SyntheticCheckoutOutcome.Confirmation AndAlso
            second13.Outcome = SyntheticCheckoutOutcome.Confirmation AndAlso
            first13.DocumentId = second13.DocumentId AndAlso engine13.Orders.Count = 1,
            "13_DOUBLE_CLICK_CREATES_ONE_ORDER")

        Dim tenant14a As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim tenant14b As SyntheticTenant = NewTenant(22, 202, "Synthetic Brand B")
        Dim context14a As SyntheticCheckoutContext = NewContext(tenant14a)
        Dim context14b As SyntheticCheckoutContext = NewContext(tenant14b)
        Dim engine14 As SyntheticCheckoutEngine = NewEngine(tenant14a, context14a)
        engine14.RegisterTenant(tenant14b)
        engine14.SetCart(context14b, 3)
        Dim result14 As SyntheticSubmitResult = engine14.Submit(context14a, engine14.NewPage(context14a), SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            engine14.CanReadDocument(context14a, result14.DocumentId) AndAlso
            Not engine14.CanReadDocument(context14b, result14.DocumentId) AndAlso
            engine14.GetCart(context14a) = 0 AndAlso engine14.GetCart(context14b) = 3,
            "14_CART_DOCUMENT_RECEIPT_OWNER_TENANT_SCOPED")

        Dim tenant15a As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim tenant15b As SyntheticTenant = NewTenant(22, 202, "Synthetic Brand B")
        Dim context15a As SyntheticCheckoutContext = NewContext(tenant15a)
        Dim context15b As SyntheticCheckoutContext = NewContext(tenant15b)
        Dim engine15 As SyntheticCheckoutEngine = NewEngine(tenant15a, context15a)
        engine15.RegisterTenant(tenant15b)
        engine15.SetCart(context15b, 3)
        Dim stolenPage15 As SyntheticCheckoutPage = engine15.NewPage(context15a)
        Dim collision15 As SyntheticSubmitResult = engine15.Submit(context15b, stolenPage15, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            collision15.Outcome = SyntheticCheckoutOutcome.OwnerCollision AndAlso
            engine15.Orders.Count = 0 AndAlso engine15.GetCart(context15a) = 2 AndAlso engine15.GetCart(context15b) = 3,
            "15_CROSS_TENANT_REQUEST_HAS_ZERO_CONTAMINATION")

        Dim tenant16a As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim tenant16b As SyntheticTenant = NewTenant(22, 202, "Synthetic Brand B")
        Dim context16a As SyntheticCheckoutContext = NewContext(tenant16a)
        Dim engine16 As SyntheticCheckoutEngine = NewEngine(tenant16a, context16a)
        engine16.RegisterTenant(tenant16b)
        Dim result16 As SyntheticSubmitResult = engine16.Submit(context16a, engine16.NewPage(context16a), SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            engine16.EmailIntents.Count = 1 AndAlso
            engine16.EmailIntents(0).DocumentId = result16.DocumentId AndAlso
            engine16.EmailIntents(0).PersistedCompanyId = tenant16a.CompanyId AndAlso
            String.Equals(engine16.EmailIntents(0).Brand, tenant16a.Brand, StringComparison.Ordinal) AndAlso
            Not String.Equals(engine16.EmailIntents(0).Brand, tenant16b.Brand, StringComparison.Ordinal),
            "16_EMAIL_BRANDING_FROM_PERSISTED_COMPANY")

        Dim tenant17 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context17 As SyntheticCheckoutContext = NewContext(tenant17)
        Dim engine17 As SyntheticCheckoutEngine = NewEngine(tenant17, context17)
        Dim page17 As SyntheticCheckoutPage = engine17.NewPage(context17)
        engine17.Submit(context17, page17, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        engine17.Submit(context17, page17, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            engine17.ExternalEmailsSent = 0 AndAlso engine17.EmailIntents.Count = 1,
            "17_TESTS_USE_INTENTS_ONLY_AND_SEND_NO_EMAIL")

        Dim tenant18 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context18 As SyntheticCheckoutContext = NewContext(tenant18)
        Dim engine18 As SyntheticCheckoutEngine = NewEngine(tenant18, context18, 4)
        engine18.Inventory = 1
        Dim page18 As SyntheticCheckoutPage = engine18.NewPage(context18)
        Dim result18 As SyntheticSubmitResult = engine18.Submit(context18, page18, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            result18.Outcome = SyntheticCheckoutOutcome.StockFailure AndAlso
            result18.RedirectTarget = "/carrello.aspx?stockerror=1#ksCartStockError" AndAlso
            engine18.Orders.Count = 0 AndAlso engine18.Claims.Count = 0 AndAlso
            engine18.GetCart(context18) = 4 AndAlso engine18.Inventory = 1 AndAlso engine18.EmailIntents.Count = 0,
            "18_STOCK_FAILURE_PRESERVES_CART_WITHOUT_EFFECTS")

        Dim tenant19 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim context19 As SyntheticCheckoutContext = NewContext(tenant19)
        Dim engine19 As SyntheticCheckoutEngine = NewEngine(tenant19, context19, 3)
        Dim before19 As SyntheticCartSurfaces = engine19.GetSurfaces(context19)
        engine19.Submit(context19, engine19.NewPage(context19), SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.BeforeClaim)
        Dim after19 As SyntheticCartSurfaces = engine19.GetSurfaces(context19)
        AssertScenario(
            before19.PageQuantity = 3 AndAlso before19.MiniCartQuantity = 3 AndAlso before19.HeaderQuantity = 3 AndAlso
            after19.PageQuantity = 3 AndAlso after19.MiniCartQuantity = 3 AndAlso after19.HeaderQuantity = 3,
            "19_CART_PAGE_MINICART_HEADER_STAY_COHERENT")

        Dim tenant20 As SyntheticTenant = NewTenant(11, 101, "Synthetic Brand A")
        Dim authenticated20 As SyntheticCheckoutContext = NewContext(tenant20, True)
        Dim expired20 As SyntheticCheckoutContext = NewContext(tenant20, False)
        Dim engine20 As SyntheticCheckoutEngine = NewEngine(tenant20, authenticated20, 2)
        Dim page20 As SyntheticCheckoutPage = engine20.NewPage(authenticated20)
        Dim timeout20 As SyntheticSubmitResult = engine20.Submit(expired20, page20, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        Dim recovery20 As SyntheticGetResult = engine20.FollowFailureRedirect(authenticated20)
        Dim completed20 As SyntheticSubmitResult = engine20.Submit(authenticated20, recovery20.Page, SyntheticCheckoutSelection.Valid(), SyntheticFailurePoint.None)
        AssertScenario(
            timeout20.Outcome = SyntheticCheckoutOutcome.LoginRequired AndAlso
            timeout20.RedirectTarget = "/carrello.aspx?loginrequired=1#ksCartLoginRequired" AndAlso
            recovery20.Page.RequestId <> page20.RequestId AndAlso
            completed20.Outcome = SyntheticCheckoutOutcome.Confirmation AndAlso engine20.Orders.Count = 1,
            "20_LOGIN_TIMEOUT_PRESERVES_AND_RECOVERS_CART")

        Console.WriteLine("RESULT scenarios=20 failures=" & _failures.ToString(CultureInfo.InvariantCulture))
        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
