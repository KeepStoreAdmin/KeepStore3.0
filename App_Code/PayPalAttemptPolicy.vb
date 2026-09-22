Option Strict On
Option Explicit On

Imports System

Public Module PayPalAttemptPolicy
    Public Function MaySupersede(ByVal orderOrigin As String, ByVal localState As String,
                                 ByVal remoteState As String, ByVal captureState As String) As Boolean
        If Not String.Equals(orderOrigin, "INTERNO", StringComparison.OrdinalIgnoreCase) Then Return False
        Dim previous As String = If(localState, String.Empty).Trim().ToUpperInvariant()
        Dim remote As String = If(remoteState, String.Empty).Trim().ToUpperInvariant()
        Dim capture As String = If(captureState, String.Empty).Trim().ToUpperInvariant()
        If previous = "CAPTURING" Then Return False
        If capture <> String.Empty AndAlso capture <> "DENIED" AndAlso capture <> "DECLINED" AndAlso capture <> "FAILED" Then Return False
        If remote = "COMPLETED" OrElse remote = "APPROVED" OrElse remote = "PENDING" Then Return False
        If remote = "VOIDED" Then Return True
        Return (previous = "CANCELED" OrElse previous = "FAILED" OrElse previous = "DENIED" OrElse
                previous = "DECLINED" OrElse previous = "VOIDED") AndAlso
               (remote = "CREATED" OrElse remote = "PAYER_ACTION_REQUIRED")
    End Function
End Module
