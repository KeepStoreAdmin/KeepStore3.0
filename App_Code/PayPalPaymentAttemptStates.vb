Option Strict On
Option Explicit On

Imports System

' PAYPAL-ATTEMPTS-TABLE-1A (fase P2 del pay-first): macchina a stati PURA dei tentativi di pagamento PayPal (nessun accesso al database, nessuna rete).
' E l'unica autorita sulle transizioni consentite: il repository (PayPalPaymentAttempts) non scrive mai uno stato che questa classe non ammette.
' Tabella completa e regole di recupero: docs/PAYPAL_PAY_FIRST_ATTEMPTS_TABLE.md.
Public NotInheritable Class PayPalPaymentAttemptStates
    Private Sub New()
    End Sub

    Public Const Creating As String = "CREATING"
    Public Const Created As String = "CREATED"
    Public Const Authorized As String = "AUTHORIZED"
    Public Const Voiding As String = "VOIDING"
    Public Const DocCommitted As String = "DOC_COMMITTED"
    Public Const Capturing As String = "CAPTURING"
    Public Const Completed As String = "COMPLETED"
    Public Const CaptureRefused As String = "CAPTURE_REFUSED"
    Public Const Voided As String = "VOIDED"
    Public Const Failed As String = "FAILED"
    Public Const Canceled As String = "CANCELED"
    Public Const CapturedOrphan As String = "CAPTURED_ORPHAN"
    Public Const Unknown As String = "UNKNOWN"

    Public Shared Function All() As String()
        Return New String() {Creating, Created, Authorized, Voiding, DocCommitted, Capturing, Completed, CaptureRefused, Voided, Failed, Canceled, CapturedOrphan, Unknown}
    End Function

    Public Shared Function IsKnown(ByVal state As String) As Boolean
        Return Array.IndexOf(All(), state) >= 0
    End Function

    ' Transizione DIRETTA consentita. Da UNKNOWN non esce nulla da qui: si usa CanResolveUnknown con lo stato precedente.
    Public Shared Function CanTransition(ByVal fromState As String, ByVal toState As String) As Boolean
        If fromState Is Nothing OrElse toState Is Nothing OrElse Not IsKnown(toState) Then Return False
        Select Case fromState
            Case Creating
                Return IsAnyOf(toState, Created, Failed, Unknown)
            Case Created
                Return IsAnyOf(toState, Authorized, Canceled, Failed, Unknown)
            Case Authorized
                Return IsAnyOf(toState, DocCommitted, Voiding, Failed, CapturedOrphan, Unknown)
            Case Voiding
                Return IsAnyOf(toState, Voided, CapturedOrphan, Unknown)
            Case DocCommitted
                Return IsAnyOf(toState, Capturing, Completed, Voiding, Unknown)
            Case Capturing
                Return IsAnyOf(toState, Completed, CaptureRefused, Unknown)
            Case CaptureRefused
                Return IsAnyOf(toState, Completed, Voiding)
            Case Voided, Failed, Canceled
                Return toState = CapturedOrphan
        End Select
        Return False
    End Function

    ' UNKNOWN(precedente) si risolve nel precedente (non e successo nulla) o in un suo successore diretto, mai in DOC_COMMITTED (solo BindDocument nella
    ' transazione del documento), mai in UNKNOWN, e mai in FAILED da AUTHORIZED (serve la prova remota: RecordAuthorizationLost).
    Public Shared Function CanResolveUnknown(ByVal previousState As String, ByVal target As String) As Boolean
        If previousState Is Nothing OrElse target Is Nothing Then Return False
        If Not IsAnyOf(previousState, Creating, Created, Authorized, Voiding, DocCommitted, Capturing) Then Return False
        If target = Unknown OrElse Not IsKnown(target) Then Return False
        If target = previousState Then Return True
        If target = DocCommitted Then Return False
        If previousState = Authorized AndAlso target = Failed Then Return False
        Return CanTransition(previousState, target)
    End Function

    ' Stati che liberano lo slot "un solo tentativo vivo per bozza" (il tentativo puo essere sostituito da uno nuovo).
    Public Shared Function ReleasesSlot(ByVal state As String) As Boolean
        Return IsAnyOf(state, Failed, Canceled, Voided, CapturedOrphan)
    End Function

    ' Nessuna uscita: COMPLETED (pagato) e CAPTURED_ORPHAN (incasso senza ordine, da riconciliare a mano).
    Public Shared Function HasNoExit(ByVal state As String) As Boolean
        Return IsAnyOf(state, Completed, CapturedOrphan)
    End Function

    ' Che cosa deve fare il recupero (P3) per un tentativo fermo. Solo una classificazione: nessuna azione qui.
    Public Shared Function RecommendedAction(ByVal state As String, ByVal ageMinutes As Integer, ByVal hasOrderId As Boolean, ByVal draftExpired As Boolean) As String
        Select Case state
            Case Creating
                If ageMinutes >= 10 Then Return If(hasOrderId, "READ_ORDER_THEN_DECIDE", "FAIL_NO_ORDER")
            Case Created
                If ageMinutes >= 30 Then Return "READ_ORDER_THEN_DECIDE"
            Case Authorized
                If draftExpired Then Return "VOID_EXPIRED_DRAFT"
            Case Voiding
                If ageMinutes >= 2 Then Return "RETRY_VOID"
            Case DocCommitted
                If ageMinutes >= 2 Then Return "BEGIN_CAPTURE"
            Case Capturing
                If ageMinutes >= 2 Then Return "READ_PAYPAL_RETRY_CAPTURE"
            Case Unknown
                Return "READ_PAYPAL_RESOLVE"
            Case CaptureRefused, CapturedOrphan
                Return "MANUAL_RECONCILE"
        End Select
        Return "NONE"
    End Function

    Private Shared Function IsAnyOf(ByVal value As String, ByVal ParamArray candidates() As String) As Boolean
        If value Is Nothing Then Return False
        For Each candidate As String In candidates
            If String.Equals(value, candidate, StringComparison.Ordinal) Then Return True
        Next
        Return False
    End Function
End Class
