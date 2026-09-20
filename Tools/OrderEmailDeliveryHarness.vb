Option Strict On
Option Explicit On

Imports System

Public Enum EmailTransportOperationStatus
    Succeeded = 0
    Rejected = 1
    Failed = 2
End Enum

Public Enum TenantEmailTransportProfileState
    Ready = 0
    Disabled = 1
End Enum

Public Enum EmailTransportFailureKind
    None = 0
    NotOperational = 1
End Enum

Public NotInheritable Class EmailDeliveryResult
    Public Property Status As EmailTransportOperationStatus
    Public Property ProfileState As TenantEmailTransportProfileState
    Public Property FailureKind As EmailTransportFailureKind
    Public Property Phase As String
    Public Property Code As String
    Public Property CorrelationId As String
End Class

Module OrderEmailDeliveryHarness
    Private _failures As Integer

    Private Sub Assert(ByVal condition As Boolean, ByVal code As String)
        If condition Then
            Console.WriteLine("PASS " & code)
        Else
            _failures += 1
            Console.WriteLine("FAIL " & code)
        End If
    End Sub

    Sub Main()
        Dim success As New EmailDeliveryResult() With {
            .Status = EmailTransportOperationStatus.Succeeded,
            .ProfileState = TenantEmailTransportProfileState.Ready,
            .FailureKind = EmailTransportFailureKind.None,
            .Phase = "send",
            .Code = "EMAIL_SENT",
            .CorrelationId = "order-correlation-0001"
        }
        Dim successLog As String = OrderEmailDeliveryDiagnostics.BuildResultLog(1, 10, success)
        Assert(successLog.Contains("result=sent") AndAlso successLog.Contains("aziendaId=1") AndAlso successLog.Contains("documentId=10"), "01_SUCCESS_SANITIZED")

        Dim rejected As New EmailDeliveryResult() With {
            .Status = EmailTransportOperationStatus.Rejected,
            .ProfileState = TenantEmailTransportProfileState.Disabled,
            .FailureKind = EmailTransportFailureKind.NotOperational,
            .Phase = "resolve",
            .Code = "PROFILE_DISABLED",
            .CorrelationId = "order-correlation-0002"
        }
        Dim rejectedLog As String = OrderEmailDeliveryDiagnostics.BuildResultLog(2, 20, rejected)
        Assert(rejectedLog.Contains("result=failed") AndAlso Not rejectedLog.Contains("result=sent"), "02_REJECTION_NEVER_SENT")
        Assert(rejectedLog.Contains("profileState=Disabled") AndAlso rejectedLog.Contains("code=PROFILE_DISABLED"), "03_FAIL_CLOSED_STATE_PRESERVED")

        Dim unsafe As New EmailDeliveryResult() With {
            .Status = EmailTransportOperationStatus.Failed,
            .ProfileState = TenantEmailTransportProfileState.Disabled,
            .FailureKind = EmailTransportFailureKind.NotOperational,
            .Phase = "unsafe phase identity@example.invalid",
            .Code = "unsafe code identity@example.invalid",
            .CorrelationId = "unsafe identity@example.invalid"
        }
        Dim unsafeLog As String = OrderEmailDeliveryDiagnostics.BuildResultLog(3, 30, unsafe)
        Assert(Not unsafeLog.Contains("identity@example.invalid") AndAlso unsafeLog.Contains("EMAIL_DELIVERY_FAILURE"), "04_UNSAFE_VALUES_REDACTED")
        Assert(OrderEmailDeliveryDiagnostics.BuildResultLog(1, 1, Nothing).Contains("EMAIL_TRANSPORT_RESULT_NULL"), "05_NULL_RESULT_SANITIZED")
        Assert(Not successLog.Contains("smtp") AndAlso Not rejectedLog.Contains("password"), "06_NO_LEGACY_SMTP_OR_SECRET")

        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
