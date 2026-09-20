Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.IO
Imports System.Text.RegularExpressions
Imports MimeKit

Public NotInheritable Class TenantEmailMessageClassifications
    Public Const OrderConfirmation As String = "ORDER_CONFIRMATION"
    Public Const AccountRegistration As String = "ACCOUNT_REGISTRATION"
    Public Const AccountProfileUpdated As String = "ACCOUNT_PROFILE_UPDATED"
    Public Const PasswordReset As String = "PASSWORD_RESET"
    Public Const ContactRequest As String = "CONTACT_REQUEST"
    Public Const AdministrativeNotification As String = "ADMINISTRATIVE_NOTIFICATION"
    Public Const DocumentDelivery As String = "DOCUMENT_DELIVERY"

    Private Sub New()
    End Sub
End Class

Public NotInheritable Class TenantEmailRecipient
    Public Property Address As String
    Public Property DisplayName As String
End Class

Public NotInheritable Class TenantEmailAttachment
    Public Property FileName As String
    Public Property ContentType As String
    Public Property ContentBytes As Byte()
End Class

Public NotInheritable Class TenantEmailDeliveryRequest
    Public Sub New()
        ToRecipients = New List(Of TenantEmailRecipient)()
        CcRecipients = New List(Of TenantEmailRecipient)()
        BccRecipients = New List(Of TenantEmailRecipient)()
        ReplyToRecipients = New List(Of TenantEmailRecipient)()
        Attachments = New List(Of TenantEmailAttachment)()
    End Sub

    Public Property AziendaId As Integer
    Public Property CorrelationId As String
    Public Property Classification As String
    Public Property Subject As String
    Public Property HtmlBody As String
    Public Property PlainTextBody As String
    Public Property ToRecipients As IList(Of TenantEmailRecipient)
    Public Property CcRecipients As IList(Of TenantEmailRecipient)
    Public Property BccRecipients As IList(Of TenantEmailRecipient)
    Public Property ReplyToRecipients As IList(Of TenantEmailRecipient)
    Public Property Attachments As IList(Of TenantEmailAttachment)
End Class

Public Interface ITenantEmailDeliveryService
    Function Deliver(ByVal request As TenantEmailDeliveryRequest) As EmailDeliveryResult
End Interface

Public NotInheritable Class TenantEmailDeliveryService
    Implements ITenantEmailDeliveryService

    Private Const TransactionalPurpose As String = "TRANSACTIONAL"
    Private Const MaxAttachmentBytes As Long = 25L * 1024L * 1024L
    Private Const MaxTotalAttachmentBytes As Long = 50L * 1024L * 1024L
    Private Shared ReadOnly SafeCorrelationPattern As New Regex("^[A-Za-z0-9-]{8,64}$", RegexOptions.CultureInvariant Or RegexOptions.Compiled)
    Private Shared ReadOnly SafeClassificationPattern As New Regex("^[A-Z0-9_]{3,48}$", RegexOptions.CultureInvariant Or RegexOptions.Compiled)

    Private ReadOnly _transport As IEmailTransport
    Private ReadOnly _connectionString As String

    Public Sub New()
        Me.New(New MailKitEmailTransport(), ResolveConnectionString())
    End Sub

    Public Sub New(ByVal transport As IEmailTransport, ByVal connectionString As String)
        If transport Is Nothing Then Throw New ArgumentNullException("transport")
        _transport = transport
        _connectionString = Convert.ToString(connectionString)
    End Sub

    Public Function Deliver(ByVal request As TenantEmailDeliveryRequest) As EmailDeliveryResult Implements ITenantEmailDeliveryService.Deliver
        Dim correlationId As String = NormalizeCorrelationId(If(request Is Nothing, Nothing, request.CorrelationId))
        Dim classification As String = NormalizeClassification(If(request Is Nothing, Nothing, request.Classification))

        If request Is Nothing OrElse request.AziendaId <= 0 OrElse String.IsNullOrWhiteSpace(_connectionString) Then
            Return Reject("EMAIL_FACADE_SCOPE_INVALID", correlationId, classification)
        End If
        If classification = String.Empty Then
            Return Reject("EMAIL_CLASSIFICATION_INVALID", correlationId, "UNCLASSIFIED")
        End If

        Dim cleanSubject As String = Convert.ToString(request.Subject).Trim()
        If cleanSubject = String.Empty OrElse cleanSubject.Length > 255 OrElse cleanSubject.IndexOf(ControlChars.Cr) >= 0 OrElse cleanSubject.IndexOf(ControlChars.Lf) >= 0 Then
            Return Reject("EMAIL_SUBJECT_INVALID", correlationId, classification)
        End If
        If String.IsNullOrWhiteSpace(request.HtmlBody) AndAlso String.IsNullOrWhiteSpace(request.PlainTextBody) Then
            Return Reject("EMAIL_BODY_REQUIRED", correlationId, classification)
        End If

        Try
            Using message As New MimeMessage()
                If Not AddAddresses(message.To, request.ToRecipients) OrElse message.To.Count = 0 Then
                    Return Reject("EMAIL_TO_INVALID", correlationId, classification)
                End If
                If Not AddAddresses(message.Cc, request.CcRecipients) Then
                    Return Reject("EMAIL_CC_INVALID", correlationId, classification)
                End If
                If Not AddAddresses(message.Bcc, request.BccRecipients) Then
                    Return Reject("EMAIL_BCC_INVALID", correlationId, classification)
                End If
                If Not AddAddresses(message.ReplyTo, request.ReplyToRecipients) Then
                    Return Reject("EMAIL_REPLY_TO_INVALID", correlationId, classification)
                End If

                message.Subject = cleanSubject
                Dim builder As New BodyBuilder() With {
                    .TextBody = Convert.ToString(request.PlainTextBody),
                    .HtmlBody = Convert.ToString(request.HtmlBody)
                }
                If Not AddAttachments(builder, request.Attachments) Then
                    Return Reject("EMAIL_ATTACHMENT_INVALID", correlationId, classification)
                End If
                message.Body = builder.ToMessageBody()

                Dim result As EmailDeliveryResult = _transport.Deliver(New EmailTransportRequest() With {
                    .ConnectionString = _connectionString,
                    .AziendaId = request.AziendaId,
                    .Purpose = TransactionalPurpose,
                    .Classification = classification,
                    .CorrelationId = correlationId,
                    .Message = message
                })
                If result Is Nothing Then
                    Return Reject("EMAIL_TRANSPORT_RESULT_NULL", correlationId, classification)
                End If
                RecordFacadeResult(result, classification)
                Return result
            End Using
        Catch
            Return Reject("EMAIL_FACADE_FAILURE", correlationId, classification)
        End Try
    End Function

    Private Shared Function AddAddresses(ByVal target As InternetAddressList,
                                         ByVal source As IList(Of TenantEmailRecipient)) As Boolean
        If target Is Nothing Then Return False
        If source Is Nothing Then Return True

        For Each recipient As TenantEmailRecipient In source
            If recipient Is Nothing Then Return False
            Dim address As String = Convert.ToString(recipient.Address).Trim()
            If address = String.Empty OrElse address.Length > 254 OrElse address.IndexOf(ControlChars.Cr) >= 0 OrElse address.IndexOf(ControlChars.Lf) >= 0 Then Return False

            Dim parsed As MailboxAddress = Nothing
            If Not MailboxAddress.TryParse(address, parsed) OrElse parsed Is Nothing OrElse Not String.Equals(parsed.Address, address, StringComparison.OrdinalIgnoreCase) Then Return False
            Dim displayName As String = Convert.ToString(recipient.DisplayName).Trim()
            If displayName.IndexOf(ControlChars.Cr) >= 0 OrElse displayName.IndexOf(ControlChars.Lf) >= 0 OrElse displayName.Length > 255 Then Return False
            target.Add(New MailboxAddress(displayName, parsed.Address))
        Next
        Return True
    End Function

    Private Shared Function AddAttachments(ByVal builder As BodyBuilder,
                                           ByVal attachments As IList(Of TenantEmailAttachment)) As Boolean
        If builder Is Nothing Then Return False
        If attachments Is Nothing Then Return True

        Dim totalBytes As Long = 0
        For Each attachment As TenantEmailAttachment In attachments
            If attachment Is Nothing OrElse attachment.ContentBytes Is Nothing OrElse attachment.ContentBytes.Length = 0 Then Return False
            If attachment.ContentBytes.LongLength > MaxAttachmentBytes Then Return False
            totalBytes += attachment.ContentBytes.LongLength
            If totalBytes > MaxTotalAttachmentBytes Then Return False

            Dim requestedName As String = Convert.ToString(attachment.FileName).Trim()
            Dim safeName As String = Path.GetFileName(requestedName)
            If safeName = String.Empty OrElse safeName.Length > 180 OrElse Not String.Equals(requestedName, safeName, StringComparison.Ordinal) Then Return False
            If safeName.IndexOf(ControlChars.Cr) >= 0 OrElse safeName.IndexOf(ControlChars.Lf) >= 0 Then Return False

            Dim contentType As ContentType = Nothing
            If Not ContentType.TryParse(Convert.ToString(attachment.ContentType).Trim(), contentType) OrElse contentType Is Nothing Then
                contentType = New ContentType("application", "octet-stream")
            End If
            builder.Attachments.Add(safeName, attachment.ContentBytes, contentType)
        Next
        Return True
    End Function

    Private Shared Function Reject(ByVal code As String,
                                   ByVal correlationId As String,
                                   ByVal classification As String) As EmailDeliveryResult
        Dim result As New EmailDeliveryResult() With {
            .Status = EmailTransportOperationStatus.Rejected,
            .ProfileState = TenantEmailTransportProfileState.TechnicalError,
            .FailureKind = EmailTransportFailureKind.InvalidRequest,
            .Phase = "facade-validation",
            .Code = code,
            .AuthenticationMode = "N/A",
            .SecurityMode = "N/A",
            .TimestampUtc = DateTime.UtcNow,
            .CorrelationId = correlationId
        }
        RecordFacadeResult(result, classification)
        Return result
    End Function

    Private Shared Sub RecordFacadeResult(ByVal result As EmailDeliveryResult, ByVal classification As String)
        If result Is Nothing Then Return
        KeepStoreLog.Info("email-delivery-facade",
                          "status=" & result.Status.ToString() &
                          " profileState=" & result.ProfileState.ToString() &
                          " failure=" & result.FailureKind.ToString() &
                          " phase=" & SafeToken(result.Phase) &
                          " code=" & SafeToken(result.Code) &
                          " classification=" & SafeToken(classification) &
                          " correlation=" & SafeToken(result.CorrelationId),
                          Nothing)
    End Sub

    Private Shared Function NormalizeCorrelationId(ByVal value As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If SafeCorrelationPattern.IsMatch(candidate) Then Return candidate
        Return Guid.NewGuid().ToString("N")
    End Function

    Private Shared Function NormalizeClassification(ByVal value As String) As String
        Dim candidate As String = Convert.ToString(value).Trim().ToUpperInvariant()
        If SafeClassificationPattern.IsMatch(candidate) Then Return candidate
        Return String.Empty
    End Function

    Private Shared Function SafeToken(ByVal value As String) As String
        Dim candidate As String = Convert.ToString(value).Trim()
        If candidate.Length > 80 Then candidate = candidate.Substring(0, 80)
        Return Regex.Replace(candidate, "[^A-Za-z0-9_.-]", "_")
    End Function

    Private Shared Function ResolveConnectionString() As String
        Try
            Dim setting As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If setting Is Nothing Then Return String.Empty
            Return Convert.ToString(setting.ConnectionString)
        Catch
            Return String.Empty
        End Try
    End Function
End Class
