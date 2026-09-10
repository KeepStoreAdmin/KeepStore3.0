Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports System.Web.SessionState
Imports System.Collections

Public Enum CartMutationIntentDecision
    Accepted = 0
    Pending = 1
    Processing = 2
    Completed = 3
    Collision = 4
    Invalid = 5
    CapacityExceeded = 6
    Indeterminate = 7
End Enum

Public NotInheritable Class CartMutationIdempotencyService
    Public Const MaxStandardBatchItems As Integer = 96
    Private Const RegistrySessionKey As String = "KeepStore:CartMutation:Intents"
    Private Const ProgressiveSlotSessionKey As String = "KeepStore:CartMutation:ProgressiveSlots"
    Private Const ActiveIntentItemKey As String = "KeepStore:CartMutation:ActiveIntent"
    Private Const MaxEntries As Integer = 64
    Private Shared ReadOnly EntryTtl As TimeSpan = TimeSpan.FromMinutes(15)
    Private Shared ReadOnly ProcessingLease As TimeSpan = TimeSpan.FromMinutes(2)

    Private NotInheritable Class IntentEntry
        Public Property Fingerprint As String
        Public Property OperationType As String
        Public Property State As String
        Public Property UpdatedUtc As DateTime
    End Class

    Private Sub New()
    End Sub

    Public Shared Function NormalizeRequestId(ByVal requestId As String, ByRef normalized As String) As Boolean
        normalized = String.Empty
        Dim parsed As Guid
        If Not Guid.TryParse(If(requestId, String.Empty).Trim(), parsed) Then Return False
        normalized = parsed.ToString("N")
        Return True
    End Function

    Public Shared Function BuildSessionPayload(ByVal session As HttpSessionState) As String
        If session Is Nothing Then Return String.Empty
        Dim multi As ArrayList = TryCast(session("Carrello_SelezioneMultipla"), ArrayList)
        If multi IsNot Nothing AndAlso multi.Count > 0 Then
            Return BuildMultiPayload(multi)
        End If

        Dim rawArticleIds As String = Convert.ToString(session("Carrello_ArticoloId")).Trim()
        Dim articleValues As New ArrayList()
        If rawArticleIds = "0" Then
            Dim legacyList As ArrayList = TryCast(session("Carrello_ListaArticoloId"), ArrayList)
            If legacyList Is Nothing OrElse legacyList.Count = 0 Then Return String.Empty
            articleValues.AddRange(legacyList)
        ElseIf rawArticleIds <> String.Empty Then
            articleValues.AddRange(rawArticleIds.Split(","c))
        Else
            Return String.Empty
        End If
        If articleValues.Count = 0 OrElse articleValues.Count > MaxStandardBatchItems Then Return String.Empty

        Dim tcValues As New ArrayList()
        Dim rawTCIds As String = Convert.ToString(session("Carrello_TCId")).Trim()
        If rawTCIds <> String.Empty Then tcValues.AddRange(rawTCIds.Split(","c))
        If tcValues.Count > articleValues.Count Then Return String.Empty
        While tcValues.Count < articleValues.Count
            tcValues.Add("-1")
        End While

        Dim quantity As Decimal = 0D
        If Not Decimal.TryParse(Convert.ToString(session("Carrello_Quantita")), NumberStyles.Number,
                                CultureInfo.InvariantCulture, quantity) OrElse quantity = 0D Then Return String.Empty

        Dim requests As New List(Of CartStandardBatchMutationRequest)()
        For index As Integer = 0 To articleValues.Count - 1
            Dim articleId As Integer = 0
            Dim tcId As Integer = -1
            If Not Integer.TryParse(Convert.ToString(articleValues(index)), NumberStyles.Integer,
                                    CultureInfo.InvariantCulture, articleId) OrElse articleId <= 0 OrElse
               Not Integer.TryParse(Convert.ToString(tcValues(index)), NumberStyles.Integer,
                                    CultureInfo.InvariantCulture, tcId) Then Return String.Empty
            requests.Add(New CartStandardBatchMutationRequest With {
                .ArticleId = articleId,
                .RequestedTCId = NormalizeTCId(tcId),
                .QuantityDelta = quantity
            })
        Next

        If requests.Count = 1 Then
            Return BuildStandardPayload(requests(0).ArticleId, requests(0).RequestedTCId, requests(0).QuantityDelta)
        End If
        Dim normalized As List(Of CartStandardBatchMutationRequest) = Nothing
        Dim payload As String = String.Empty
        If Not TryNormalizeStandardBatchItems(requests, MaxStandardBatchItems, normalized, payload) Then Return String.Empty
        Return payload
    End Function

    Public Shared Function BuildMultiPayload(ByVal itemsSource As IEnumerable) As String
        If itemsSource Is Nothing Then Return String.Empty
        Dim requests As New List(Of CartStandardBatchMutationRequest)()
        For Each raw As Object In itemsSource
            Dim request As CartStandardBatchMutationRequest = Nothing
            If Not TryParseMultiItem(Convert.ToString(raw), request) Then Return String.Empty
            requests.Add(request)
        Next
        Dim normalized As List(Of CartStandardBatchMutationRequest) = Nothing
        Dim payload As String = String.Empty
        If Not TryNormalizeStandardBatchItems(requests, MaxStandardBatchItems, normalized, payload) Then
            Return String.Empty
        End If
        Return payload
    End Function

    Public Shared Function TryNormalizeStandardBatchItems(
        ByVal items As IList(Of CartStandardBatchMutationRequest),
        ByVal maxItems As Integer,
        ByRef normalizedItems As List(Of CartStandardBatchMutationRequest),
        ByRef payload As String) As Boolean

        normalizedItems = New List(Of CartStandardBatchMutationRequest)()
        payload = String.Empty
        If items Is Nothing OrElse maxItems <= 0 OrElse items.Count = 0 OrElse items.Count > maxItems Then
            Return False
        End If

        Dim byKey As New Dictionary(Of String, CartStandardBatchMutationRequest)(StringComparer.Ordinal)
        Try
            For Each item As CartStandardBatchMutationRequest In items
                If item Is Nothing OrElse item.ArticleId <= 0 OrElse item.QuantityDelta = 0D OrElse
                   Not HasSupportedQuantityScale(item.QuantityDelta) OrElse
                   item.QuantityDelta < -9999999.99999999D OrElse
                   item.QuantityDelta > 9999999.99999999D Then Return False

                Dim tcId As Integer = NormalizeTCId(item.RequestedTCId)
                Dim key As String = item.ArticleId.ToString(CultureInfo.InvariantCulture) & ":" &
                                    tcId.ToString(CultureInfo.InvariantCulture)
                Dim canonical As CartStandardBatchMutationRequest = Nothing
                If byKey.TryGetValue(key, canonical) Then
                    canonical.QuantityDelta = Decimal.Add(canonical.QuantityDelta, item.QuantityDelta)
                Else
                    byKey(key) = New CartStandardBatchMutationRequest With {
                        .ArticleId = item.ArticleId,
                        .RequestedTCId = tcId,
                        .QuantityDelta = item.QuantityDelta
                    }
                End If
            Next
        Catch ex As OverflowException
            Return False
        End Try

        For Each item As CartStandardBatchMutationRequest In byKey.Values
            If Not HasSupportedQuantityScale(item.QuantityDelta) OrElse
               item.QuantityDelta < -9999999.99999999D OrElse
               item.QuantityDelta > 9999999.99999999D Then Return False
            If item.QuantityDelta <> 0D Then normalizedItems.Add(item)
        Next
        normalizedItems.Sort(AddressOf CompareBatchItems)
        If normalizedItems.Count = 0 OrElse normalizedItems.Count > maxItems Then Return False

        Dim parts As New List(Of String)()
        For Each item As CartStandardBatchMutationRequest In normalizedItems
            parts.Add(item.ArticleId.ToString(CultureInfo.InvariantCulture) & "," &
                      NormalizeTCId(item.RequestedTCId).ToString(CultureInfo.InvariantCulture) & "," &
                      item.QuantityDelta.ToString("0.########", CultureInfo.InvariantCulture))
        Next
        payload = "multi|" & String.Join(";", parts.ToArray())
        Return True
    End Function

    Public Shared Function BuildStandardPayload(ByVal articleId As Integer,
                                                ByVal tcId As Integer,
                                                ByVal quantityDelta As Decimal) As String
        Return "single|" & articleId.ToString(CultureInfo.InvariantCulture) & "|" &
               NormalizeTCId(tcId).ToString(CultureInfo.InvariantCulture) & "|" &
               quantityDelta.ToString("0.####", CultureInfo.InvariantCulture)
    End Function

    Public Shared Function BuildSetQuantityPayload(ByVal articleId As Integer,
                                                   ByVal tcId As Integer,
                                                   ByVal desiredQuantity As Decimal) As String
        Return "target|" & articleId.ToString(CultureInfo.InvariantCulture) & "|" &
               NormalizeTCId(tcId).ToString(CultureInfo.InvariantCulture) & "|" &
               desiredQuantity.ToString("0.####", CultureInfo.InvariantCulture)
    End Function

    Public Shared Function BuildRemoveRowPayload(ByVal cartRowId As Integer) As String
        Return "remove-row|" & cartRowId.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function BuildClearCartPayload() As String
        Return "clear|owner-cart"
    End Function

    Public Shared Function CreateRequestId() As String
        Return Guid.NewGuid().ToString("N")
    End Function

    Public Shared Function GetOrCreateProgressiveRequestId(ByVal context As HttpContext,
                                                           ByVal slotName As String,
                                                           ByVal operationType As String,
                                                           ByVal payload As String) As String
        If Not IsUsableContext(context) OrElse String.IsNullOrWhiteSpace(slotName) OrElse
           String.IsNullOrWhiteSpace(operationType) OrElse String.IsNullOrWhiteSpace(payload) Then Return String.Empty

        Dim slots As Dictionary(Of String, String) = TryCast(context.Session(ProgressiveSlotSessionKey), Dictionary(Of String, String))
        If slots Is Nothing Then slots = New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
        Dim fingerprint As String = BuildFingerprint(context, operationType, payload)
        Dim stored As String = Nothing
        If slots.TryGetValue(slotName.Trim(), stored) Then
            Dim separator As Integer = If(stored, String.Empty).LastIndexOf("|"c)
            If separator > 0 AndAlso FixedTimeEquals(stored.Substring(0, separator), fingerprint) Then
                Dim normalized As String = String.Empty
                If NormalizeRequestId(stored.Substring(separator + 1), normalized) Then Return normalized
            End If
        End If

        Dim requestId As String = CreateRequestId()
        slots(slotName.Trim()) = fingerprint & "|" & requestId
        context.Session(ProgressiveSlotSessionKey) = slots
        Return requestId
    End Function

    Public Shared Sub ClearProgressiveRequestId(ByVal context As HttpContext, ByVal slotName As String)
        If Not IsUsableContext(context) OrElse String.IsNullOrWhiteSpace(slotName) Then Return
        Dim slots As Dictionary(Of String, String) = TryCast(context.Session(ProgressiveSlotSessionKey), Dictionary(Of String, String))
        If slots Is Nothing Then Return
        slots.Remove(slotName.Trim())
        context.Session(ProgressiveSlotSessionKey) = slots
    End Sub

    Public Shared Sub ClearProgressiveRequestIds(ByVal context As HttpContext, ByVal slotPrefix As String)
        If Not IsUsableContext(context) OrElse String.IsNullOrWhiteSpace(slotPrefix) Then Return
        Dim slots As Dictionary(Of String, String) = TryCast(context.Session(ProgressiveSlotSessionKey), Dictionary(Of String, String))
        If slots Is Nothing Then Return
        Dim keys As New List(Of String)(slots.Keys)
        For Each key As String In keys
            If key.StartsWith(slotPrefix, StringComparison.OrdinalIgnoreCase) Then slots.Remove(key)
        Next
        context.Session(ProgressiveSlotSessionKey) = slots
    End Sub

    Public Shared Function BuildNativeActionValue(ByVal articleId As Integer,
                                                  ByVal tcId As Integer,
                                                  ByVal quantityDelta As Decimal,
                                                  ByVal requestId As String) As String
        Return "id=" & articleId.ToString(CultureInfo.InvariantCulture) &
               "&tcid=" & NormalizeTCId(tcId).ToString(CultureInfo.InvariantCulture) &
               "&qty=" & quantityDelta.ToString("0.####", CultureInfo.InvariantCulture) &
               "&requestId=" & HttpUtility.UrlEncode(requestId) &
               "&operation=cart-add"
    End Function

    Public Shared Function BuildNativeSetActionValue(ByVal articleId As Integer,
                                                     ByVal tcId As Integer,
                                                     ByVal quantityFieldName As String,
                                                     ByVal requestId As String) As String
        Return "id=" & articleId.ToString(CultureInfo.InvariantCulture) &
               "&tcid=" & NormalizeTCId(tcId).ToString(CultureInfo.InvariantCulture) &
               "&qtyField=" & HttpUtility.UrlEncode(If(quantityFieldName, String.Empty)) &
               "&requestId=" & HttpUtility.UrlEncode(requestId) &
               "&operation=cart-set"
    End Function

    Public Shared Function BuildNativeRemoveRowActionValue(ByVal cartRowId As Integer,
                                                           ByVal requestId As String) As String
        Return "rowId=" & cartRowId.ToString(CultureInfo.InvariantCulture) &
               "&requestId=" & HttpUtility.UrlEncode(requestId) &
               "&operation=cart-remove-row"
    End Function

    Public Shared Function BuildNativeClearCartActionValue(ByVal requestId As String) As String
        Return "requestId=" & HttpUtility.UrlEncode(requestId) &
               "&operation=cart-clear"
    End Function

    Public Shared Function BuildNativeBundleActionValue(ByVal itemsSource As IEnumerable,
                                                        ByVal requestId As String) As String
        Dim payload As String = BuildMultiPayload(itemsSource)
        If Not payload.StartsWith("multi|", StringComparison.Ordinal) Then Return String.Empty
        Return "items=" & HttpUtility.UrlEncode(payload.Substring("multi|".Length)) &
               "&requestId=" & HttpUtility.UrlEncode(requestId) &
               "&operation=pdp-bundle"
    End Function

    Public Shared Function RegisterIntent(ByVal context As HttpContext,
                                          ByVal requestId As String,
                                          ByVal operationType As String,
                                          ByVal payload As String) As CartMutationIntentDecision
        Dim normalized As String = String.Empty
        If Not IsUsableContext(context) OrElse
           Not NormalizeRequestId(requestId, normalized) OrElse
           String.IsNullOrWhiteSpace(operationType) OrElse
           String.IsNullOrWhiteSpace(payload) Then Return CartMutationIntentDecision.Invalid

        Dim registry As Dictionary(Of String, IntentEntry) = GetRegistry(context.Session, True)
        Prune(registry)
        Dim fingerprint As String = BuildFingerprint(context, operationType, payload)
        Dim existing As IntentEntry = Nothing
        If registry.TryGetValue(normalized, existing) Then
            If Not FixedTimeEquals(existing.Fingerprint, fingerprint) Then Return CartMutationIntentDecision.Collision
            Select Case existing.State
                Case "completed" : Return CartMutationIntentDecision.Completed
                Case "processing" : Return CartMutationIntentDecision.Processing
                Case "indeterminate" : Return CartMutationIntentDecision.Indeterminate
                Case Else : Return CartMutationIntentDecision.Pending
            End Select
        End If

        If Not EnsureCapacity(registry) Then Return CartMutationIntentDecision.CapacityExceeded
        registry(normalized) = New IntentEntry With {
            .Fingerprint = fingerprint,
            .OperationType = operationType.Trim().ToLowerInvariant(),
            .State = "pending",
            .UpdatedUtc = DateTime.UtcNow
        }
        context.Session(RegistrySessionKey) = registry
        Return CartMutationIntentDecision.Accepted
    End Function

    Public Shared Function BeginIntent(ByVal context As HttpContext,
                                       ByVal requestId As String,
                                       ByVal operationType As String,
                                       ByVal payload As String) As CartMutationIntentDecision
        Dim normalized As String = String.Empty
        If Not IsUsableContext(context) OrElse Not NormalizeRequestId(requestId, normalized) Then
            Return CartMutationIntentDecision.Invalid
        End If

        Dim registry As Dictionary(Of String, IntentEntry) = GetRegistry(context.Session, False)
        If registry Is Nothing Then Return CartMutationIntentDecision.Invalid
        Prune(registry)
        Dim existing As IntentEntry = Nothing
        If Not registry.TryGetValue(normalized, existing) Then Return CartMutationIntentDecision.Invalid
        If Not String.Equals(existing.OperationType, If(operationType, String.Empty).Trim(), StringComparison.OrdinalIgnoreCase) Then
            Return CartMutationIntentDecision.Collision
        End If
        If Not String.IsNullOrWhiteSpace(payload) AndAlso
           Not FixedTimeEquals(existing.Fingerprint, BuildFingerprint(context, operationType, payload)) Then
            Return CartMutationIntentDecision.Collision
        End If
        If existing.State = "completed" Then Return CartMutationIntentDecision.Completed
        If existing.State = "processing" Then Return CartMutationIntentDecision.Processing
        If existing.State = "indeterminate" Then Return CartMutationIntentDecision.Indeterminate

        existing.State = "processing"
        existing.UpdatedUtc = DateTime.UtcNow
        context.Session(RegistrySessionKey) = registry
        context.Items(ActiveIntentItemKey) = normalized
        Return CartMutationIntentDecision.Accepted
    End Function

    Public Shared Sub CompleteIntent(ByVal context As HttpContext, ByVal requestId As String)
        SetState(context, requestId, "completed", False)
        ClearActiveIntent(context, requestId)
    End Sub

    Public Shared Sub AbandonIntent(ByVal context As HttpContext, ByVal requestId As String)
        SetState(context, requestId, "pending", False, True)
        ClearActiveIntent(context, requestId)
    End Sub

    Public Shared Function GetCurrentRequestId(ByVal context As HttpContext) As String
        If context Is Nothing OrElse context.Items Is Nothing Then Return String.Empty
        Dim normalized As String = String.Empty
        If NormalizeRequestId(Convert.ToString(context.Items(ActiveIntentItemKey)), normalized) Then Return normalized
        Return String.Empty
    End Function

    Public Shared Sub MarkCurrentIntentIndeterminate(ByVal context As HttpContext)
        Dim requestId As String = GetCurrentRequestId(context)
        If requestId = String.Empty Then Return
        SetState(context, requestId, "indeterminate", False)
    End Sub

    Private Shared Function BuildFingerprint(ByVal context As HttpContext,
                                             ByVal operationType As String,
                                             ByVal payload As String) As String
        Dim loginId As Integer = SessionInt(context.Session, "LoginID", SessionInt(context.Session, "LoginId", 0))
        Dim owner As String = If(loginId > 0,
                                 "login:" & loginId.ToString(CultureInfo.InvariantCulture),
                                 "session:" & context.Session.SessionID)
        Dim canonical As String = owner & "|" & operationType.Trim().ToLowerInvariant() & "|" & payload
        Using sha As SHA256 = SHA256.Create()
            Return Convert.ToBase64String(sha.ComputeHash(Encoding.UTF8.GetBytes(canonical)))
        End Using
    End Function

    Private Shared Sub SetState(ByVal context As HttpContext,
                                ByVal requestId As String,
                                ByVal state As String,
                                ByVal remove As Boolean,
                                Optional ByVal preserveTerminalState As Boolean = False)
        Dim normalized As String = String.Empty
        If Not IsUsableContext(context) OrElse Not NormalizeRequestId(requestId, normalized) Then Return
        Dim registry As Dictionary(Of String, IntentEntry) = GetRegistry(context.Session, False)
        If registry Is Nothing Then Return
        Dim existing As IntentEntry = Nothing
        If Not registry.TryGetValue(normalized, existing) Then Return
        If remove Then
            registry.Remove(normalized)
        Else
            If preserveTerminalState AndAlso
               (String.Equals(existing.State, "completed", StringComparison.OrdinalIgnoreCase) OrElse
                String.Equals(existing.State, "indeterminate", StringComparison.OrdinalIgnoreCase)) Then Return
            existing.State = state
            existing.UpdatedUtc = DateTime.UtcNow
        End If
        context.Session(RegistrySessionKey) = registry
    End Sub

    Private Shared Sub ClearActiveIntent(ByVal context As HttpContext, ByVal requestId As String)
        If context Is Nothing OrElse context.Items Is Nothing Then Return
        Dim normalized As String = String.Empty
        If Not NormalizeRequestId(requestId, normalized) Then Return
        Dim active As String = String.Empty
        If NormalizeRequestId(Convert.ToString(context.Items(ActiveIntentItemKey)), active) AndAlso
           String.Equals(active, normalized, StringComparison.Ordinal) Then
            context.Items.Remove(ActiveIntentItemKey)
        End If
    End Sub

    Private Shared Sub Prune(ByVal registry As Dictionary(Of String, IntentEntry))
        If registry Is Nothing Then Return
        Dim nowUtc As DateTime = DateTime.UtcNow
        Dim cutoff As DateTime = nowUtc.Subtract(EntryTtl)
        Dim processingCutoff As DateTime = nowUtc.Subtract(ProcessingLease)
        Dim expired As New List(Of String)()
        For Each pair As KeyValuePair(Of String, IntentEntry) In registry
            If pair.Value Is Nothing Then
                expired.Add(pair.Key)
            ElseIf String.Equals(pair.Value.State, "processing", StringComparison.OrdinalIgnoreCase) AndAlso
                   pair.Value.UpdatedUtc < processingCutoff Then
                pair.Value.State = "indeterminate"
                pair.Value.UpdatedUtc = nowUtc
            ElseIf pair.Value.UpdatedUtc < cutoff AndAlso
                   (String.Equals(pair.Value.State, "completed", StringComparison.OrdinalIgnoreCase) OrElse
                    String.Equals(pair.Value.State, "pending", StringComparison.OrdinalIgnoreCase) OrElse
                    String.Equals(pair.Value.State, "indeterminate", StringComparison.OrdinalIgnoreCase)) Then
                expired.Add(pair.Key)
            End If
        Next
        For Each key As String In expired
            registry.Remove(key)
        Next
    End Sub

    Private Shared Function EnsureCapacity(ByVal registry As Dictionary(Of String, IntentEntry)) As Boolean
        Prune(registry)
        While registry.Count >= MaxEntries
            Dim oldestKey As String = FindOldestEvictableKey(registry, "completed", DateTime.MaxValue)
            If String.IsNullOrEmpty(oldestKey) Then Return False
            registry.Remove(oldestKey)
        End While
        Return True
    End Function

    Private Shared Function FindOldestEvictableKey(ByVal registry As Dictionary(Of String, IntentEntry),
                                                   ByVal state As String,
                                                   ByVal updatedBefore As DateTime) As String
        Dim oldestKey As String = Nothing
        Dim oldestUtc As DateTime = DateTime.MaxValue
        For Each pair As KeyValuePair(Of String, IntentEntry) In registry
            Dim entry As IntentEntry = pair.Value
            If entry Is Nothing Then Return pair.Key
            If String.Equals(entry.State, state, StringComparison.OrdinalIgnoreCase) AndAlso
               entry.UpdatedUtc < updatedBefore AndAlso entry.UpdatedUtc < oldestUtc Then
                oldestKey = pair.Key
                oldestUtc = entry.UpdatedUtc
            End If
        Next
        Return oldestKey
    End Function

    Private Shared Function GetRegistry(ByVal session As HttpSessionState,
                                        ByVal createIfMissing As Boolean) As Dictionary(Of String, IntentEntry)
        Dim registry As Dictionary(Of String, IntentEntry) = TryCast(session(RegistrySessionKey), Dictionary(Of String, IntentEntry))
        If registry Is Nothing AndAlso createIfMissing Then
            registry = New Dictionary(Of String, IntentEntry)(StringComparer.Ordinal)
            session(RegistrySessionKey) = registry
        End If
        Return registry
    End Function

    Private Shared Function IsUsableContext(ByVal context As HttpContext) As Boolean
        Return context IsNot Nothing AndAlso context.Session IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(context.Session.SessionID)
    End Function

    Private Shared Function SessionInt(ByVal session As HttpSessionState,
                                       ByVal key As String,
                                       ByVal fallback As Integer) As Integer
        Dim parsed As Integer
        If session IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(session(key)), parsed) Then Return parsed
        Return fallback
    End Function

    Private Shared Function NormalizeInteger(ByVal value As Object, ByVal fallback As Integer) As Integer
        Dim parsed As Integer
        If Integer.TryParse(Convert.ToString(value), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed) Then
            Return parsed
        End If
        Return fallback
    End Function

    Private Shared Function NormalizeDecimal(ByVal value As Object, ByVal fallback As Decimal) As Decimal
        Dim parsed As Decimal
        If Decimal.TryParse(Convert.ToString(value), NumberStyles.Number, CultureInfo.InvariantCulture, parsed) Then
            Return parsed
        End If
        Return fallback
    End Function

    Private Shared Function TryParseMultiItem(ByVal rawValue As String,
                                              ByRef request As CartStandardBatchMutationRequest) As Boolean
        request = Nothing
        Dim parts As String() = If(rawValue, String.Empty).Split(","c)
        If parts.Length < 2 OrElse parts.Length > 4 Then Return False

        Dim articleId As Integer = 0
        If Not Integer.TryParse(parts(0), NumberStyles.Integer, CultureInfo.InvariantCulture, articleId) OrElse articleId <= 0 Then
            Return False
        End If

        Dim tcId As Integer = -1
        Dim quantityIndex As Integer = 1
        If parts.Length >= 3 Then
            If Not Integer.TryParse(parts(1), NumberStyles.Integer, CultureInfo.InvariantCulture, tcId) Then Return False
            quantityIndex = 2
        End If

        Dim quantity As Decimal = 0D
        If Not Decimal.TryParse(parts(quantityIndex), NumberStyles.Number, CultureInfo.InvariantCulture, quantity) Then
            Return False
        End If

        request = New CartStandardBatchMutationRequest With {
            .ArticleId = articleId,
            .RequestedTCId = NormalizeTCId(tcId),
            .QuantityDelta = quantity
        }
        Return True
    End Function

    Private Shared Function CompareBatchItems(ByVal left As CartStandardBatchMutationRequest,
                                               ByVal right As CartStandardBatchMutationRequest) As Integer
        Dim articleCompare As Integer = left.ArticleId.CompareTo(right.ArticleId)
        If articleCompare <> 0 Then Return articleCompare
        Return NormalizeTCId(left.RequestedTCId).CompareTo(NormalizeTCId(right.RequestedTCId))
    End Function

    Private Shared Function HasSupportedQuantityScale(ByVal quantity As Decimal) As Boolean
        Return Decimal.Round(quantity, 8, MidpointRounding.ToEven) = quantity
    End Function

    Private Shared Function NormalizeTCId(ByVal tcId As Integer) As Integer
        Return If(tcId > 0, tcId, -1)
    End Function

    Private Shared Function FixedTimeEquals(ByVal expected As String, ByVal supplied As String) As Boolean
        If String.IsNullOrEmpty(expected) OrElse String.IsNullOrEmpty(supplied) Then Return False
        Dim difference As Integer = expected.Length Xor supplied.Length
        Dim maxLength As Integer = Math.Max(expected.Length, supplied.Length)
        For index As Integer = 0 To maxLength - 1
            Dim expectedChar As Integer = If(index < expected.Length, AscW(expected(index)), 0)
            Dim suppliedChar As Integer = If(index < supplied.Length, AscW(supplied(index)), 0)
            difference = difference Or (expectedChar Xor suppliedChar)
        Next
        Return difference = 0
    End Function
End Class
