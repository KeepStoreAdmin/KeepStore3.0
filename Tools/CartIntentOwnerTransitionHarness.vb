Option Strict On
Option Explicit On

Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.IO
Imports System.Reflection
Imports System.Security.Cryptography
Imports System.Web
Imports System.Web.SessionState

' Synthetic owner resolver: the production resolver is not loaded and no DB is reachable.
Public NotInheritable Class CartStorefrontOwnerScope
    Public Property DatabaseScopeKey As String
    Public Property CompanyId As Integer
    Public Property LoginId As Integer
    Public Property SessionId As String
    Public Property OwnerScopeKey As String
End Class

Public NotInheritable Class CartStorefrontOwnerContext
    Public Shared Function ResolveForMutation(context As HttpContext) As CartStorefrontOwnerScope
        If context Is Nothing Then Return Nothing
        Return TryCast(context.Items("SyntheticOwner"), CartStorefrontOwnerScope)
    End Function
End Class

Public Class CartStandardBatchMutationRequest
    Public Property ArticleId As Integer
    Public Property RequestedTCId As Integer
    Public Property QuantityDelta As Decimal
End Class

Public Class CartQuantityMutationRequest
    Public Property CartRowId As Integer
    Public Property Quantity As Decimal
End Class

Module CartIntentOwnerTransitionHarness
    Private Const Operation As String = "cart-add"
    Private Const Payload As String = "single|17|-1|1"
    Private ReadOnly SourceToken As String = CartStorefrontScopePolicy.BuildAnonymousOwnerToken("synthetic-db", 1, "session-a")
    Private ReadOnly TargetTokenA As String = Token("A")
    Private ReadOnly TargetTokenB As String = Token("B")
    Private _passed As Integer

    Private Function Token(seed As String) As String
        Using sha As SHA256 = SHA256.Create()
            Dim bytes As Byte() = sha.ComputeHash(System.Text.Encoding.UTF8.GetBytes(seed))
            Return "ksc2_" & Convert.ToBase64String(bytes).TrimEnd("="c).Replace("+", "-").Replace("/", "_")
        End Using
    End Function

    Private Function Scope(databaseName As String, companyId As Integer, loginId As Integer, tokenValue As String) As CartStorefrontOwnerScope
        Return New CartStorefrontOwnerScope With {
            .DatabaseScopeKey = databaseName,
            .CompanyId = companyId,
            .LoginId = loginId,
            .SessionId = tokenValue,
            .OwnerScopeKey = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseName, companyId, loginId, tokenValue)
        }
    End Function

    Private Function NewContext() As HttpContext
        Dim context As New HttpContext(New HttpRequest("", "http://localhost/", ""),
                                       New HttpResponse(New StringWriter()))
        Dim container As New HttpSessionStateContainer("synthetic-session",
            New SessionStateItemCollection(), New HttpStaticObjectsCollection(), 20, True,
            HttpCookieMode.UseCookies, SessionStateMode.InProc, False)
        SessionStateUtility.AddHttpSessionStateToContext(context, container)
        context.Items("SyntheticOwner") = Scope("synthetic-db", 1, 0, SourceToken)
        HttpContext.Current = context
        Return context
    End Function

    Private Function Register(context As HttpContext, requestId As String,
                              Optional payloadValue As String = Payload) As CartMutationIntentDecision
        Return CartMutationIdempotencyService.RegisterIntent(context, requestId, Operation, payloadValue)
    End Function

    Private Function Begin(context As HttpContext, requestId As String,
                           Optional payloadValue As String = Payload) As CartMutationIntentDecision
        Return CartMutationIdempotencyService.BeginIntent(context, requestId, Operation, payloadValue)
    End Function

    Private Function Authorize(context As HttpContext,
                               Optional target As CartStorefrontOwnerScope = Nothing) As Boolean
        If target Is Nothing Then target = Scope("synthetic-db", 1, 0, TargetTokenA)
        Return CartMutationIdempotencyService.AuthorizeAnonymousOwnerTransitionForCurrentIntent(
            context, Operation, Payload, target)
    End Function

    Private Sub SwitchOwner(context As HttpContext, tokenValue As String)
        context.Items("SyntheticOwner") = Scope("synthetic-db", 1, 0, tokenValue)
    End Sub

    Private Function Entry(context As HttpContext, requestId As String) As Object
        Dim registry As IDictionary = DirectCast(context.Session("KeepStore:CartMutation:Intents"), IDictionary)
        Return registry(requestId)
    End Function

    Private Function Field(entryValue As Object, name As String) As String
        Return Convert.ToString(entryValue.GetType().GetProperty(name, BindingFlags.Public Or BindingFlags.Instance).GetValue(entryValue, Nothing))
    End Function

    Private Sub SetField(entryValue As Object, name As String, value As String)
        entryValue.GetType().GetProperty(name, BindingFlags.Public Or BindingFlags.Instance).SetValue(entryValue, value, Nothing)
    End Sub

    Private Sub Check(name As String, passed As Boolean)
        If Not passed Then Throw New InvalidOperationException("FAIL " & name)
        _passed += 1
        Console.WriteLine("PASS " & name)
    End Sub

    Sub Main()
        Dim requestId As String
        Dim context As HttpContext

        Dim one As New List(Of CartQuantityMutationRequest) From {
            New CartQuantityMutationRequest With {.CartRowId = 7, .Quantity = 2D}}
        Dim two As New List(Of CartQuantityMutationRequest) From {
            New CartQuantityMutationRequest With {.CartRowId = 9, .Quantity = 1.25D},
            New CartQuantityMutationRequest With {.CartRowId = 7, .Quantity = 2D}}
        Dim reversed As New List(Of CartQuantityMutationRequest) From {two(1), two(0)}
        Check("BATCH_PAYLOAD_SINGLE", CartMutationIdempotencyService.BuildSetRowsQuantityPayload(one) = "rows-target-v1|7:2")
        Check("BATCH_PAYLOAD_MULTI_SORTED", CartMutationIdempotencyService.BuildSetRowsQuantityPayload(two) = "rows-target-v1|7:2;9:1.25")
        Check("BATCH_PAYLOAD_ORDER_INDEPENDENT", CartMutationIdempotencyService.BuildSetRowsQuantityPayload(two) =
              CartMutationIdempotencyService.BuildSetRowsQuantityPayload(reversed))
        Check("BATCH_PAYLOAD_DUPLICATE_REJECTED", String.IsNullOrEmpty(
              CartMutationIdempotencyService.BuildSetRowsQuantityPayload(New List(Of CartQuantityMutationRequest) From {one(0), one(0)})))
        Check("BATCH_PAYLOAD_INVALID_QUANTITY_REJECTED", String.IsNullOrEmpty(
              CartMutationIdempotencyService.BuildSetRowsQuantityPayload(New List(Of CartQuantityMutationRequest) From {
                  New CartQuantityMutationRequest With {.CartRowId = 7, .Quantity = 0D}})))
        Check("BATCH_PAYLOAD_INVALID_SCALE_REJECTED", String.IsNullOrEmpty(
              CartMutationIdempotencyService.BuildSetRowsQuantityPayload(New List(Of CartQuantityMutationRequest) From {
                  New CartQuantityMutationRequest With {.CartRowId = 7, .Quantity = 1.123456789D}})))
        Check("BATCH_PAYLOAD_INVARIANT_DECIMAL", CartMutationIdempotencyService.BuildSetRowsQuantityPayload(two).Contains("9:1.25"))
        Check("ASYNC_ROW_PAYLOAD_UNCHANGED", CartMutationIdempotencyService.BuildSetRowQuantityPayload(7, 2D) = "row-target|7|2")

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        Dim batchPayload As String = CartMutationIdempotencyService.BuildSetRowsQuantityPayload(two)
        Check("TRADITIONAL_REGISTER", CartMutationIdempotencyService.RegisterIntent(context, requestId, "cart-set-batch", batchPayload) =
              CartMutationIntentDecision.Accepted)
        Dim descriptorOperation As String = Nothing
        Dim descriptorPayload As String = Nothing
        Check("DESCRIPTOR_NOT_PENDING", Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(
              context, descriptorOperation, descriptorPayload))
        Check("TRADITIONAL_BEGIN", CartMutationIdempotencyService.BeginIntent(context, requestId, "cart-set-batch", batchPayload) =
              CartMutationIntentDecision.Accepted)
        Check("DESCRIPTOR_PROCESSING", CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(
              context, descriptorOperation, descriptorPayload))
        Check("DESCRIPTOR_EXACT_OPERATION", descriptorOperation = "cart-set-batch")
        Check("DESCRIPTOR_EXACT_PAYLOAD", descriptorPayload = batchPayload)
        CartMutationIdempotencyService.CompleteIntent(context, requestId)
        Check("DESCRIPTOR_CLEARED_COMPLETE", Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(
              context, descriptorOperation, descriptorPayload))
        Check("TRADITIONAL_REPLAY_COMPLETED", CartMutationIdempotencyService.RegisterIntent(
              context, requestId, "cart-set-batch", batchPayload) = CartMutationIntentDecision.Completed)
        Check("TRADITIONAL_COLLISION", CartMutationIdempotencyService.RegisterIntent(
              context, requestId, "cart-set-batch", "rows-target-v1|7:3;9:1.25") = CartMutationIntentDecision.Collision)

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        CartMutationIdempotencyService.RegisterIntent(context, requestId, "cart-set-batch", batchPayload)
        CartMutationIdempotencyService.BeginIntent(context, requestId, "cart-set-batch", batchPayload)
        context.Items("KeepStore:CartMutation:ActiveIntentDescriptor") = "tampered"
        Check("DESCRIPTOR_TAMPER_REJECTED", Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(
              context, descriptorOperation, descriptorPayload))

        Dim descriptorType As Type = GetType(CartMutationIdempotencyService).GetNestedType(
            "ActiveIntentDescriptor", BindingFlags.NonPublic)
        Dim descriptorConstructor As ConstructorInfo = descriptorType.GetConstructor(
            BindingFlags.Instance Or BindingFlags.Public Or BindingFlags.NonPublic, Nothing,
            New Type() {GetType(String), GetType(String), GetType(String)}, Nothing)
        context.Items("KeepStore:CartMutation:ActiveIntentDescriptor") = descriptorConstructor.Invoke(
            New Object() {requestId, "cart-set-batch", "rows-target-v1|7:99"})
        Check("DESCRIPTOR_PAYLOAD_MISMATCH_REJECTED", Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(
              context, descriptorOperation, descriptorPayload))
        context.Items("KeepStore:CartMutation:ActiveIntentDescriptor") = descriptorConstructor.Invoke(
            New Object() {requestId, "cart-remove", batchPayload})
        Check("DESCRIPTOR_OPERATION_MISMATCH_REJECTED", Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(
              context, descriptorOperation, descriptorPayload))

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        CartMutationIdempotencyService.RegisterIntent(context, requestId, "cart-set-batch", batchPayload)
        CartMutationIdempotencyService.BeginIntent(context, requestId, "cart-set-batch", batchPayload)
        CartMutationIdempotencyService.AbandonIntent(context, requestId)
        Check("DESCRIPTOR_CLEARED_ABANDON", Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(
              context, descriptorOperation, descriptorPayload))
        Check("BUSINESS_ABORT_RETRY_PENDING", CartMutationIdempotencyService.RegisterIntent(
              context, requestId, "cart-set-batch", batchPayload) = CartMutationIntentDecision.Pending)

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        CartMutationIdempotencyService.RegisterIntent(context, requestId, "cart-set-batch", batchPayload)
        CartMutationIdempotencyService.BeginIntent(context, requestId, "cart-set-batch", batchPayload)
        CartMutationIdempotencyService.MarkCurrentIntentIndeterminate(context)
        Check("DESCRIPTOR_CLEARED_INDETERMINATE", Not CartMutationIdempotencyService.TryGetCurrentIntentDescriptor(
              context, descriptorOperation, descriptorPayload))
        Check("INDETERMINATE_REPLAY_BLOCKED", CartMutationIdempotencyService.RegisterIntent(
              context, requestId, "cart-set-batch", batchPayload) = CartMutationIntentDecision.Indeterminate)

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        Check("REGISTER_NEW", Register(context, requestId) = CartMutationIntentDecision.Accepted)
        Check("BEGIN_SAME_OWNER", Begin(context, requestId) = CartMutationIntentDecision.Accepted)
        CartMutationIdempotencyService.CompleteIntent(context, requestId)
        Check("SAME_OWNER_COMPLETED", Register(context, requestId) = CartMutationIntentDecision.Completed)
        Check("SAME_OWNER_DIFFERENT_PAYLOAD", Register(context, requestId, "single|17|-1|2") = CartMutationIntentDecision.Collision)
        SwitchOwner(context, TargetTokenA)
        Check("KSC2_UNAUTHORIZED_COLLISION", Register(context, requestId) = CartMutationIntentDecision.Collision)
        Check("BEGIN_UNAUTHORIZED_COLLISION", Begin(context, requestId) = CartMutationIntentDecision.Collision)

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        Register(context, requestId)
        Check("AUTHORIZE_PENDING_REFUSED", Not Authorize(context))
        Begin(context, requestId)
        Check("AUTHORIZE_PROCESSING", Authorize(context))
        Check("TARGET_HASH_ONLY", Field(Entry(context, requestId), "TransitionOwnerScopeHash").Length = 44)
        Check("ORIGINAL_FINGERPRINT_UNCHANGED", Field(Entry(context, requestId), "Fingerprint").Length = 44)
        Check("SECOND_TARGET_REFUSED", Not Authorize(context, Scope("synthetic-db", 1, 0, TargetTokenB)))
        SwitchOwner(context, TargetTokenA)
        Check("BEGIN_AUTHORIZED_PROCESSING", Begin(context, requestId) = CartMutationIntentDecision.Processing)
        SwitchOwner(context, SourceToken)
        CartMutationIdempotencyService.CompleteIntent(context, requestId)
        Check("COMPLETE_PRESERVES_TRANSITION", Field(Entry(context, requestId), "TransitionOwnerScopeHash").Length = 44)
        SwitchOwner(context, TargetTokenA)
        Check("AUTHORIZED_EXACT_COMPLETED", Register(context, requestId) = CartMutationIntentDecision.Completed)
        Check("BEGIN_AUTHORIZED_COMPLETED", Begin(context, requestId) = CartMutationIntentDecision.Completed)
        Check("AUTHORIZED_CHANGED_PAYLOAD", Register(context, requestId, "single|17|-1|2") = CartMutationIntentDecision.Collision)
        SwitchOwner(context, TargetTokenB)
        Check("OTHER_KSC2_COLLISION", Register(context, requestId) = CartMutationIntentDecision.Collision)

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        Register(context, requestId) : Begin(context, requestId)
        Check("CROSS_COMPANY_REFUSED", Not Authorize(context, Scope("synthetic-db", 2, 0, TargetTokenA)))
        Check("CROSS_DATABASE_REFUSED", Not Authorize(context, Scope("other-db", 1, 0, TargetTokenA)))
        Check("LOGIN_TARGET_REFUSED", Not Authorize(context, Scope("synthetic-db", 1, 7, TargetTokenA)))
        Check("KSC1_TARGET_REFUSED", Not Authorize(context, Scope("synthetic-db", 1, 0, SourceToken)))
        context.Items("SyntheticOwner") = Scope("synthetic-db", 1, 7, Nothing)
        Check("LOGIN_SOURCE_REFUSED", Not Authorize(context))
        SwitchOwner(context, TargetTokenA)
        Check("KSC2_SOURCE_REFUSED", Not Authorize(context))

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        Register(context, requestId)
        SetField(Entry(context, requestId), "PayloadFingerprint", Nothing)
        Begin(context, requestId)
        Check("LEGACY_TRANSITION_REFUSED", Not Authorize(context))
        CartMutationIdempotencyService.CompleteIntent(context, requestId)
        Check("LEGACY_SAME_OWNER_COMPLETED", Register(context, requestId) = CartMutationIntentDecision.Completed)

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        Register(context, requestId) : Begin(context, requestId)
        Check("AUTHORIZE_BEFORE_ABANDON", Authorize(context))
        CartMutationIdempotencyService.AbandonIntent(context, requestId)
        Check("ABANDON_CLEARS_TRANSITION", String.IsNullOrEmpty(Field(Entry(context, requestId), "TransitionOwnerScopeHash")))
        SwitchOwner(context, TargetTokenA)
        Check("ABANDONED_KSC2_COLLISION", Register(context, requestId) = CartMutationIntentDecision.Collision)

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        Register(context, requestId) : Begin(context, requestId)
        CartMutationIdempotencyService.MarkCurrentIntentIndeterminate(context)
        Check("INDETERMINATE_NO_AUTH", String.IsNullOrEmpty(Field(Entry(context, requestId), "TransitionOwnerScopeHash")))
        Check("INDETERMINATE_SAME_OWNER", Register(context, requestId) = CartMutationIntentDecision.Indeterminate)
        Check("INDETERMINATE_AUTH_REFUSED", Not Authorize(context))

        context = NewContext() : requestId = Guid.NewGuid().ToString("N")
        Register(context, requestId)
        Check("BEGIN_EMPTY_PAYLOAD_INVALID", Begin(context, requestId, "") = CartMutationIntentDecision.Invalid)
        Console.WriteLine("TOTAL_PASS=" & _passed.ToString())
    End Sub
End Module
