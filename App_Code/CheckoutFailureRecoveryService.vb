Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web

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
    OrderNotesInvalid = 9
End Enum

Public NotInheritable Class CheckoutFailureFlash
    Public Property Reason As CheckoutFailureReason
    Public Property CorrelationId As String
    Public Property Message As String
End Class

''' <summary>
''' Server-side, one-shot recovery for failed checkout attempts. Retired request
''' identifiers are never emitted to logs or rendered output. The query string
''' selects only the cart destination; the message itself remains in Session.
''' </summary>
Public NotInheritable Class CheckoutFailureRecoveryService
    Public Const FailureQueryName As String = "checkoutfailed"
    Public Const FailureQueryValue As String = "1"

    Private Const FlashReasonSessionKey As String = "KeepStore:CheckoutFailure:Reason"
    Private Const FlashCorrelationSessionKey As String = "KeepStore:CheckoutFailure:Correlation"
    Private Const RetiredRequestIdsSessionKey As String = "KeepStore:CheckoutFailure:RetiredRequestIds"

    Private Sub New()
    End Sub

    Public Shared Function RetireAndDispatch(ByVal context As HttpContext,
                                             ByVal requestId As String,
                                             ByVal reason As CheckoutFailureReason,
                                             ByVal phase As String,
                                             Optional ByVal failure As Exception = Nothing) As Boolean
        If context Is Nothing OrElse context.Session Is Nothing Then Return False

        RetireRequest(context, requestId)
        Dim correlationId As String = GetCorrelationId(requestId)
        context.Session(FlashReasonSessionKey) = CInt(reason)
        context.Session(FlashCorrelationSessionKey) = correlationId
        TracePhase(context, requestId, phase, "failure", failure)
        Return CheckoutTerminalOutcomeDispatcher.Dispatch(
            context,
            CheckoutTerminalOutcome.CheckoutFailure)
    End Function

    Public Shared Sub RetireRequest(ByVal context As HttpContext, ByVal requestId As String)
        If context Is Nothing OrElse context.Session Is Nothing Then Return

        Dim normalized As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizeRequestId(requestId, normalized) Then Return

        Dim ids As List(Of String) = ReadRetiredRequestIds(
            Convert.ToString(context.Session(RetiredRequestIdsSessionKey), CultureInfo.InvariantCulture))
        For i As Integer = ids.Count - 1 To 0 Step -1
            If String.Equals(ids(i), normalized, StringComparison.Ordinal) Then ids.RemoveAt(i)
        Next
        ids.Add(normalized)
        context.Session(RetiredRequestIdsSessionKey) = String.Join("|", ids.ToArray())
    End Sub

    Public Shared Function IsRetiredRequest(ByVal context As HttpContext, ByVal requestId As String) As Boolean
        If context Is Nothing OrElse context.Session Is Nothing Then Return False

        Dim normalized As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizeRequestId(requestId, normalized) Then Return False
        Dim ids As List(Of String) = ReadRetiredRequestIds(
            Convert.ToString(context.Session(RetiredRequestIdsSessionKey), CultureInfo.InvariantCulture))
        For Each current As String In ids
            If String.Equals(current, normalized, StringComparison.Ordinal) Then Return True
        Next
        Return False
    End Function

    Public Shared Function TryConsumeFailure(ByVal context As HttpContext,
                                             ByRef result As CheckoutFailureFlash) As Boolean
        result = Nothing
        If context Is Nothing OrElse context.Session Is Nothing Then Return False

        Dim reasonValue As Object = context.Session(FlashReasonSessionKey)
        Dim correlationValue As Object = context.Session(FlashCorrelationSessionKey)
        context.Session.Remove(FlashReasonSessionKey)
        context.Session.Remove(FlashCorrelationSessionKey)
        If reasonValue Is Nothing Then Return False

        Dim rawReason As Integer = -1
        If Not Integer.TryParse(Convert.ToString(reasonValue, CultureInfo.InvariantCulture), rawReason) OrElse
           Not [Enum].IsDefined(GetType(CheckoutFailureReason), rawReason) Then Return False

        Dim reason As CheckoutFailureReason = CType(rawReason, CheckoutFailureReason)
        Dim correlationId As String = NormalizeCorrelationId(
            Convert.ToString(correlationValue, CultureInfo.InvariantCulture))
        result = New CheckoutFailureFlash() With {
            .Reason = reason,
            .CorrelationId = correlationId,
            .Message = BuildUserMessage(reason, correlationId)
        }
        Return True
    End Function

    Public Shared Function BuildUserMessage(ByVal reason As CheckoutFailureReason,
                                            ByVal correlationId As String) As String
        Select Case reason
            Case CheckoutFailureReason.ShippingAddressInvalid
                Return "Seleziona un indirizzo di spedizione valido e rivedi l'ordine."
            Case CheckoutFailureReason.ShippingMethodMissing
                Return "Seleziona un metodo di spedizione prima di confermare l'ordine."
            Case CheckoutFailureReason.PaymentMethodMissing
                Return "Seleziona un metodo di pagamento prima di confermare l'ordine."
            Case CheckoutFailureReason.TermsNotAccepted
                Return "Accetta le Condizioni Generali di Vendita prima di confermare l'ordine."
            Case CheckoutFailureReason.CartChanged
                Return "Il carrello è cambiato. Controlla articoli, quantità e prezzi, quindi conferma nuovamente l'ordine."
            Case CheckoutFailureReason.Collision
                Return "La richiesta di conferma non è più utilizzabile. Rivedi il carrello e invia nuovamente l'ordine."
            Case CheckoutFailureReason.RetryRequired
                Return "Il tentativo precedente non è stato completato. Il carrello è rimasto invariato: rivedilo e conferma nuovamente l'ordine."
            Case CheckoutFailureReason.CartInvalid
                Return "Controlla le quantità nel carrello, premi Aggiorna carrello e conferma nuovamente l'ordine."
            Case CheckoutFailureReason.OrderNotesInvalid
                Return "Le note dell'ordine superano il limite massimo di 255 caratteri. Riduci il testo e riprova."
            Case Else
                Dim safeCorrelation As String = NormalizeCorrelationId(correlationId)
                Dim suffix As String = If(String.IsNullOrEmpty(safeCorrelation), String.Empty,
                    " Riferimento assistenza: " & safeCorrelation & ".")
                Return "Non è stato possibile inviare l'ordine. Il carrello è rimasto invariato. Riprova tra qualche istante; se il problema continua, contatta l'assistenza." & suffix
        End Select
    End Function

    Public Shared Function GetCorrelationId(ByVal requestId As String) As String
        Dim normalized As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizeRequestId(requestId, normalized) Then
            Return Guid.NewGuid().ToString("N", CultureInfo.InvariantCulture).Substring(0, 8).ToUpperInvariant()
        End If

        Dim bytes() As Byte = Encoding.ASCII.GetBytes(normalized)
        Dim digest() As Byte = Nothing
        Try
            Using sha As SHA256 = SHA256.Create()
                digest = sha.ComputeHash(bytes)
            End Using
            Dim builder As New StringBuilder(8)
            For i As Integer = 0 To 3
                builder.Append(digest(i).ToString("X2", CultureInfo.InvariantCulture))
            Next
            Return builder.ToString()
        Finally
            Array.Clear(bytes, 0, bytes.Length)
            If digest IsNot Nothing Then Array.Clear(digest, 0, digest.Length)
        End Try
    End Function

    Public Shared Sub TracePhase(ByVal context As HttpContext,
                                 ByVal requestId As String,
                                 ByVal phase As String,
                                 ByVal outcome As String,
                                 Optional ByVal failure As Exception = Nothing)
        Try
            Dim effective As Exception = failure
            While effective IsNot Nothing AndAlso effective.InnerException IsNot Nothing
                effective = effective.InnerException
            End While
            Dim errorType As String = If(effective Is Nothing, "none", effective.GetType().Name)
            KeepStoreLog.Info(
                "checkout-flow",
                "correlation=" & GetCorrelationId(requestId) &
                "; phase=" & SafeLogToken(phase, "unknown") &
                "; outcome=" & SafeLogToken(outcome, "unknown") &
                "; errorType=" & SafeLogToken(errorType, "Exception") & ".",
                context)
        Catch
        End Try
    End Sub

    Private Shared Function ReadRetiredRequestIds(ByVal value As String) As List(Of String)
        Dim result As New List(Of String)()
        If String.IsNullOrWhiteSpace(value) Then Return result
        For Each candidate As String In value.Split("|"c)
            Dim normalized As String = String.Empty
            If OrderDurableIdempotencyService.TryNormalizeRequestId(candidate, normalized) AndAlso
               Not result.Contains(normalized) Then result.Add(normalized)
        Next
        Return result
    End Function

    Private Shared Function NormalizeCorrelationId(ByVal value As String) As String
        If String.IsNullOrWhiteSpace(value) OrElse value.Length <> 8 Then Return String.Empty
        Dim normalized As String = value.ToUpperInvariant()
        For Each current As Char In normalized
            If Not ((current >= "0"c AndAlso current <= "9"c) OrElse
                    (current >= "A"c AndAlso current <= "F"c)) Then Return String.Empty
        Next
        Return normalized
    End Function

    Private Shared Function SafeLogToken(ByVal value As String, ByVal fallback As String) As String
        If String.IsNullOrWhiteSpace(value) Then Return fallback
        Dim builder As New StringBuilder()
        For Each current As Char In value.Trim()
            If (current >= "a"c AndAlso current <= "z"c) OrElse
               (current >= "A"c AndAlso current <= "Z"c) OrElse
               (current >= "0"c AndAlso current <= "9"c) OrElse
               current = "-"c OrElse current = "_"c Then builder.Append(current)
            If builder.Length >= 48 Then Exit For
        Next
        If builder.Length = 0 Then Return fallback
        Return builder.ToString()
    End Function
End Class
