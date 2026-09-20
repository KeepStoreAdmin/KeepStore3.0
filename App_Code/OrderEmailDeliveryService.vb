Option Strict On
Option Explicit On

Imports System
Imports System.Net
Imports System.Net.Mail
Imports System.Net.Sockets
Imports System.Security.Authentication
Imports System.Text.RegularExpressions

Public NotInheritable Class OrderEmailTransportSettings
    Public Property Host As String
    Public Property UserName As String
    Public Property Password As String

    Public Sub Validate()
        If String.IsNullOrWhiteSpace(Host) Then
            Throw New InvalidOperationException("SMTP_HOST_REQUIRED")
        End If
    End Sub
End Class

Public Interface IOrderEmailTransport
    Sub Send(ByVal message As MailMessage, ByVal settings As OrderEmailTransportSettings)
End Interface

Public NotInheritable Class NetworkOrderEmailTransport
    Implements IOrderEmailTransport

    Public Sub Send(ByVal message As MailMessage,
                    ByVal settings As OrderEmailTransportSettings) Implements IOrderEmailTransport.Send
        If message Is Nothing Then Throw New ArgumentNullException("message")
        If settings Is Nothing Then Throw New ArgumentNullException("settings")
        settings.Validate()

        Using client As New SmtpClient(settings.Host)
            client.DeliveryMethod = SmtpDeliveryMethod.Network
            client.UseDefaultCredentials = False
            client.Credentials = New NetworkCredential(settings.UserName, settings.Password)
            client.Send(message)
        End Using
    End Sub
End Class

Public NotInheritable Class OrderEmailDeliveryDiagnostics
    Private Shared ReadOnly ReplyCodePattern As New Regex("(?<![0-9])([245][0-9]{2})(?![0-9])", RegexOptions.CultureInvariant)
    Private Shared ReadOnly SafePhasePattern As New Regex("^[a-z0-9-]{1,48}$", RegexOptions.CultureInvariant)

    Private Sub New()
    End Sub

    Public Shared Function BuildFailureLog(ByVal phase As String, ByVal failure As Exception) As String
        Dim safePhase As String = NormalizePhase(phase)
        Dim smtpFailure As SmtpException = FindSmtpException(failure)
        Dim deepest As Exception = FindDeepestException(failure)
        Dim effective As Exception = If(DirectCast(smtpFailure, Exception), failure)
        Dim exceptionType As String = SafeTypeName(effective)
        Dim innerType As String = SafeTypeName(deepest)
        Dim smtpStatus As String = If(smtpFailure Is Nothing, "N/A", smtpFailure.StatusCode.ToString())
        Dim replyCode As String = ExtractReplyCode(failure)
        Dim internalCode As String = Classify(failure, smtpFailure, replyCode)

        Return "result=failed phase=" & safePhase &
               " type=" & exceptionType &
               " innerType=" & innerType &
               " smtpStatus=" & smtpStatus &
               " smtpReply=" & replyCode &
               " code=" & internalCode
    End Function

    Public Shared Function BuildSuccessLog(ByVal aziendaId As Integer, ByVal documentId As Integer) As String
        Return "result=sent phase=transport-send code=SMTP_SENT" &
               " aziendaId=" & Math.Max(aziendaId, 0).ToString(Globalization.CultureInfo.InvariantCulture) &
               " documentId=" & Math.Max(documentId, 0).ToString(Globalization.CultureInfo.InvariantCulture)
    End Function

    Private Shared Function NormalizePhase(ByVal phase As String) As String
        Dim value As String = If(phase, String.Empty).Trim().ToLowerInvariant()
        If Not SafePhasePattern.IsMatch(value) Then Return "unknown"
        Return value
    End Function

    Private Shared Function FindSmtpException(ByVal failure As Exception) As SmtpException
        Dim current As Exception = failure
        While current IsNot Nothing
            Dim smtpFailure As SmtpException = TryCast(current, SmtpException)
            If smtpFailure IsNot Nothing Then Return smtpFailure
            current = current.InnerException
        End While
        Return Nothing
    End Function

    Private Shared Function FindDeepestException(ByVal failure As Exception) As Exception
        Dim current As Exception = failure
        If current Is Nothing Then Return Nothing
        While current.InnerException IsNot Nothing
            current = current.InnerException
        End While
        Return current
    End Function

    Private Shared Function SafeTypeName(ByVal failure As Exception) As String
        If failure Is Nothing Then Return "N/A"
        Return failure.GetType().Name
    End Function

    Private Shared Function ExtractReplyCode(ByVal failure As Exception) As String
        Dim current As Exception = failure
        While current IsNot Nothing
            Dim match As Match = ReplyCodePattern.Match(If(current.Message, String.Empty))
            If match.Success Then Return match.Groups(1).Value
            current = current.InnerException
        End While
        Return "N/A"
    End Function

    Private Shared Function Classify(ByVal failure As Exception,
                                     ByVal smtpFailure As SmtpException,
                                     ByVal replyCode As String) As String
        Select Case replyCode
            Case "534", "535"
                Return "SMTP_AUTH_REJECTED"
            Case "530"
                Return "SMTP_AUTH_OR_TLS_REQUIRED"
            Case "550", "551", "552", "553"
                Return "SMTP_ADDRESS_OR_POLICY_REJECTED"
            Case "421", "450", "451", "452"
                Return "SMTP_TRANSIENT_FAILURE"
        End Select

        Dim deepest As Exception = FindDeepestException(failure)
        If TypeOf deepest Is AuthenticationException Then Return "SMTP_TLS_FAILURE"
        If TypeOf deepest Is TimeoutException Then Return "SMTP_TIMEOUT"
        If TypeOf deepest Is SocketException Then Return "SMTP_TRANSPORT_FAILURE"
        If TypeOf deepest Is FormatException Then Return "MESSAGE_ADDRESS_INVALID"
        If smtpFailure IsNot Nothing Then Return "SMTP_FAILURE"
        If TypeOf failure Is InvalidOperationException Then Return "EMAIL_CONFIGURATION_INVALID"
        Return "EMAIL_DELIVERY_FAILURE"
    End Function
End Class
