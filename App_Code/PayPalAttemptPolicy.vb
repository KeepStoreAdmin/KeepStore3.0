Option Strict On
Option Explicit On

Imports System

Public Module PayPalAttemptPolicy
    ' PAYPAL-EXPIRED-ORDER-RETRY-1A: minuti di inattivita (orologio del DATABASE) oltre i quali un tentativo locale CREATED, mai approvato, si puo sostituire.
    ' 180 = la durata minima documentata da PayPal per un ordine CREATED. Il denaro non dipende da questo valore: il sito cattura solo il tentativo corrente,
    ' sotto lock (TryBeginCapture), e l'ordine e CAPTURE senza cattura automatica: un vecchio ordine approvato dopo la sostituzione non muove denaro.
    Public Const ExpiryMinutes As Integer = 180

    Public Function MaySupersede(ByVal orderOrigin As String, ByVal localState As String,
                                 ByVal remoteState As String, ByVal captureState As String) As Boolean
        Return MaySupersede(orderOrigin, localState, remoteState, captureState, False)
    End Function

    Public Function MaySupersede(ByVal orderOrigin As String, ByVal localState As String,
                                 ByVal remoteState As String, ByVal captureState As String, ByVal expired As Boolean) As Boolean
        If Not String.Equals(orderOrigin, "INTERNO", StringComparison.OrdinalIgnoreCase) Then Return False
        Dim previous As String = If(localState, String.Empty).Trim().ToUpperInvariant()
        Dim remote As String = If(remoteState, String.Empty).Trim().ToUpperInvariant()
        Dim capture As String = If(captureState, String.Empty).Trim().ToUpperInvariant()
        If previous = "CAPTURING" Then Return False
        If capture <> String.Empty AndAlso capture <> "DENIED" AndAlso capture <> "DECLINED" AndAlso capture <> "FAILED" Then Return False
        If remote = "COMPLETED" OrElse remote = "APPROVED" OrElse remote = "PENDING" Then Return False
        If remote = "VOIDED" Then Return True
        If expired AndAlso previous = "CREATED" AndAlso (remote = "CREATED" OrElse remote = "PAYER_ACTION_REQUIRED") Then Return True 'EXPIRED_RULE
        Return (previous = "CANCELED" OrElse previous = "FAILED" OrElse previous = "DENIED" OrElse
                previous = "DECLINED" OrElse previous = "VOIDED") AndAlso
               (remote = "CREATED" OrElse remote = "PAYER_ACTION_REQUIRED")
    End Function
End Module
