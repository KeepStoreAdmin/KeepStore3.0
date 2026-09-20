Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Net.Mail
Imports System.Security.Authentication

Friend NotInheritable Class CapturingOrderEmailTransport
    Implements IOrderEmailTransport

    Public ReadOnly SentSubjects As New List(Of String)()
    Public Failure As Exception

    Public Sub Send(ByVal message As MailMessage,
                    ByVal settings As OrderEmailTransportSettings) Implements IOrderEmailTransport.Send
        settings.Validate()
        If Failure IsNot Nothing Then Throw Failure
        SentSubjects.Add(message.Subject)
    End Sub
End Class

Friend NotInheritable Class SyntheticReceiptDeliveryGate
    Private ReadOnly _delivered As New HashSet(Of String)(StringComparer.Ordinal)

    Public Function TryDeliver(ByVal documentKey As String,
                               ByVal message As MailMessage,
                               ByVal settings As OrderEmailTransportSettings,
                               ByVal transport As IOrderEmailTransport) As Boolean
        If _delivered.Contains(documentKey) Then Return False
        transport.Send(message, settings)
        _delivered.Add(documentKey)
        Return True
    End Function
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

    Private Function BuildMessage(ByVal tenantName As String,
                                  ByVal tenantUrl As String,
                                  ByVal sender As String,
                                  ByVal recipient As String,
                                  ByVal admin As String) As MailMessage
        Dim message As New MailMessage()
        message.From = New MailAddress(sender, tenantName)
        message.To.Add(New MailAddress(recipient, "Synthetic customer"))
        message.Bcc.Add(New MailAddress(admin, tenantName))
        message.ReplyToList.Add(New MailAddress(sender, tenantName))
        message.Subject = tenantName & " order confirmation"
        message.Body = "<html><body><a href=""" & tenantUrl & "/documenti.aspx"">" & tenantName & "</a></body></html>"
        message.IsBodyHtml = True
        Return message
    End Function

    Private Function Settings(ByVal suffix As String) As OrderEmailTransportSettings
        Return New OrderEmailTransportSettings() With {
            .Host = "smtp-" & suffix & ".example.invalid",
            .UserName = "sender-" & suffix & "@example.invalid",
            .Password = String.Empty
        }
    End Function

    Sub Main()
        Dim taikunTransport As New CapturingOrderEmailTransport()
        Using message As MailMessage = BuildMessage("Tenant A", "https://tenant-a.example.invalid", "sender-a@example.invalid", "customer-a@example.invalid", "admin-a@example.invalid")
            taikunTransport.Send(message, Settings("a"))
            Assert(taikunTransport.SentSubjects.Count = 1 AndAlso
                   message.Body.Contains("tenant-a.example.invalid") AndAlso
                   Not message.Body.Contains("tenant-b.example.invalid") AndAlso
                   message.To.Count = 1 AndAlso message.Bcc.Count = 1 AndAlso
                   message.Attachments.Count = 0 AndAlso message.IsBodyHtml,
                   "01_TENANT_A_MESSAGE_CAPTURED")
        End Using

        Dim webaffareTransport As New CapturingOrderEmailTransport()
        Using message As MailMessage = BuildMessage("Tenant B", "https://tenant-b.example.invalid", "sender-b@example.invalid", "customer-b@example.invalid", "admin-b@example.invalid")
            webaffareTransport.Send(message, Settings("b"))
            Assert(webaffareTransport.SentSubjects.Count = 1 AndAlso
                   message.Body.Contains("tenant-b.example.invalid") AndAlso
                   Not message.Body.Contains("tenant-a.example.invalid"),
                   "02_TENANT_B_MESSAGE_ISOLATED")
        End Using

        Dim missingConfigurationRejected As Boolean = False
        Try
            Dim missingSettings As New OrderEmailTransportSettings()
            missingSettings.Validate()
        Catch ex As InvalidOperationException
            missingConfigurationRejected = String.Equals(ex.Message, "SMTP_HOST_REQUIRED", StringComparison.Ordinal)
        End Try
        Assert(missingConfigurationRejected, "03_MISSING_SMTP_CONFIGURATION_REJECTED")

        Dim authFailure As New SmtpException(SmtpStatusCode.GeneralFailure, "535 synthetic authentication rejected")
        Dim authLog As String = OrderEmailDeliveryDiagnostics.BuildFailureLog("transport-send", authFailure)
        Assert(authLog.Contains("smtpReply=535") AndAlso authLog.Contains("code=SMTP_AUTH_REJECTED") AndAlso
               Not authLog.Contains("authentication rejected"),
               "04_AUTH_REJECTION_SANITIZED")

        Dim timeoutLog As String = OrderEmailDeliveryDiagnostics.BuildFailureLog("transport-send", New TimeoutException("synthetic timeout"))
        Assert(timeoutLog.Contains("code=SMTP_TIMEOUT") AndAlso Not timeoutLog.Contains("synthetic timeout"),
               "05_TIMEOUT_SANITIZED")

        Dim tlsFailure As New SmtpException("synthetic", New AuthenticationException("synthetic tls"))
        Dim tlsLog As String = OrderEmailDeliveryDiagnostics.BuildFailureLog("transport-send", tlsFailure)
        Assert(tlsLog.Contains("innerType=AuthenticationException") AndAlso tlsLog.Contains("code=SMTP_TLS_FAILURE") AndAlso
               Not tlsLog.Contains("synthetic tls"),
               "06_TLS_FAILURE_SANITIZED")

        Dim invalidRecipientRejected As Boolean = False
        Try
            Using invalidMessage As MailMessage = BuildMessage("Tenant A", "https://tenant-a.example.invalid", "sender-a@example.invalid", "not-an-email", "admin-a@example.invalid")
            End Using
        Catch ex As FormatException
            invalidRecipientRejected = True
        End Try
        Assert(invalidRecipientRejected, "07_INVALID_RECIPIENT_REJECTED")

        Dim templateTransport As New CapturingOrderEmailTransport()
        Dim templateFailed As Boolean = False
        Try
            Throw New InvalidOperationException("synthetic template failure")
        Catch
            templateFailed = True
        End Try
        Assert(templateFailed AndAlso templateTransport.SentSubjects.Count = 0,
               "08_TEMPLATE_FAILURE_NEVER_REACHES_TRANSPORT")

        Dim gate As New SyntheticReceiptDeliveryGate()
        Dim replayTransport As New CapturingOrderEmailTransport()
        Using message As MailMessage = BuildMessage("Tenant A", "https://tenant-a.example.invalid", "sender-a@example.invalid", "customer-a@example.invalid", "admin-a@example.invalid")
            Dim first As Boolean = gate.TryDeliver("db|1|document-1", message, Settings("a"), replayTransport)
            Dim retry As Boolean = gate.TryDeliver("db|1|document-1", message, Settings("a"), replayTransport)
            Assert(first AndAlso Not retry AndAlso replayTransport.SentSubjects.Count = 1,
                   "09_SAME_DOCUMENT_RETRY_NOT_DUPLICATED")
            Dim refresh As Boolean = gate.TryDeliver("db|1|document-1", message, Settings("a"), replayTransport)
            Dim backForward As Boolean = gate.TryDeliver("db|1|document-1", message, Settings("a"), replayTransport)
            Assert(Not refresh AndAlso Not backForward AndAlso replayTransport.SentSubjects.Count = 1,
                   "10_RECEIPT_REFRESH_BACK_FORWARD_NOT_DUPLICATED")
        End Using

        Assert(Not authLog.Contains("sender-") AndAlso Not tlsLog.Contains("sender-") AndAlso
               Not authLog.Contains("example.invalid") AndAlso Not tlsLog.Contains("example.invalid"),
               "11_DIAGNOSTICS_CONTAIN_NO_IDENTITIES")
        Assert(OrderEmailDeliveryDiagnostics.BuildSuccessLog(1, 10).Contains("result=sent") AndAlso
               Not OrderEmailDeliveryDiagnostics.BuildFailureLog("transport-send", authFailure).Contains("result=sent"),
               "12_FAILURE_NEVER_RECORDED_AS_SENT")

        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
