Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Text.RegularExpressions

Public NotInheritable Class OrderEmailDeliveryDiagnostics
    Private Shared ReadOnly SafeTokenPattern As New Regex("^[A-Za-z0-9_.-]{1,80}$", RegexOptions.CultureInvariant Or RegexOptions.Compiled)

    Private Sub New()
    End Sub

    Public Shared Function BuildResultLog(ByVal aziendaId As Integer,
                                          ByVal documentId As Integer,
                                          ByVal result As EmailDeliveryResult) As String
        If result Is Nothing Then
            Return "result=failed phase=transport-send code=EMAIL_TRANSPORT_RESULT_NULL" & Scope(aziendaId, documentId)
        End If

        Return "result=" & If(result.Status = EmailTransportOperationStatus.Succeeded, "sent", "failed") &
               " phase=" & SafeToken(result.Phase, "unknown") &
               " status=" & result.Status.ToString() &
               " profileState=" & result.ProfileState.ToString() &
               " failure=" & result.FailureKind.ToString() &
               " code=" & SafeToken(result.Code, "EMAIL_DELIVERY_FAILURE") &
               " correlation=" & SafeToken(result.CorrelationId, "unknown") &
               Scope(aziendaId, documentId)
    End Function

    Private Shared Function Scope(ByVal aziendaId As Integer, ByVal documentId As Integer) As String
        Return " aziendaId=" & Math.Max(aziendaId, 0).ToString(CultureInfo.InvariantCulture) &
               " documentId=" & Math.Max(documentId, 0).ToString(CultureInfo.InvariantCulture)
    End Function

    Private Shared Function SafeToken(ByVal value As String, ByVal fallback As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If SafeTokenPattern.IsMatch(candidate) Then Return candidate
        Return fallback
    End Function
End Class
