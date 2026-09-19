Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports System.Web.Hosting

Public Enum CheckoutTelemetryPhase
    Unknown = 0
    ConfirmGet = 1
    ConfirmPost = 2
    ValidateDraft = 3
    ValidateAddress = 4
    ValidateDelivery = 5
    ValidatePayment = 6
    ValidateCart = 7
    ValidateFingerprint = 8
    VerifyAccount = 9
    TryClaim = 10
    ValidateInventory = 11
    ExecuteProcedure = 12
    CompleteIdempotency = 13
    Commit = 14
    ReceiptRedirect = 15
    PostCommitEmail = 16
    BuildOrderToken = 17
    ProtectOrderToken = 18
    EncodeOrderToken = 19
    DispatchOrderProcessing = 20
End Enum

''' <summary>
''' Bounded, sanitized checkout telemetry. It never writes exception messages,
''' request ids, addresses, account names, cookies or SQL. Primary and fallback
''' sinks are explicit, append-only and fail-open to checkout execution.
''' </summary>
Public NotInheritable Class CheckoutDurableTelemetry
    Private Const FileName As String = "checkout-durable.log"
    Private Const MaxFileBytes As Long = 2L * 1024L * 1024L
    Private Const MaxArchives As Integer = 3
    Private Shared ReadOnly WriteLock As New Object()

    Private Sub New()
    End Sub

    Public Shared Function Write(ByVal context As HttpContext,
                                 ByVal requestId As String,
                                 ByVal phase As String,
                                 ByVal outcome As String,
                                 ByVal failure As Exception,
                                 Optional ByVal idempotencyState As String = "unknown",
                                 Optional ByVal transactionState As String = "none",
                                 Optional ByVal lastCheckpoint As String = "none") As Boolean
        Try
            Dim primary As String = String.Empty
            If context IsNot Nothing Then
                Try
                    primary = context.Server.MapPath("~/App_Data/Logs")
                Catch
                End Try
            End If
            If String.IsNullOrEmpty(primary) Then
                Try
                    primary = HostingEnvironment.MapPath("~/App_Data/Logs")
                Catch
                End Try
            End If
            Dim fallback As String = Path.Combine(Path.GetTempPath(), "KeepStoreLogs")
            Return WriteToPaths(primary, fallback, context, requestId, phase, outcome,
                                failure, idempotencyState, transactionState, lastCheckpoint)
        Catch
            Return False
        End Try
    End Function

    Friend Shared Function WriteToPaths(ByVal primaryDirectory As String,
                                        ByVal fallbackDirectory As String,
                                        ByVal context As HttpContext,
                                        ByVal requestId As String,
                                        ByVal phase As String,
                                        ByVal outcome As String,
                                        ByVal failure As Exception,
                                        ByVal idempotencyState As String,
                                        ByVal transactionState As String,
                                        ByVal lastCheckpoint As String) As Boolean
        Try
            Dim effective As Exception = Innermost(failure)
            Dim exceptionType As String = If(effective Is Nothing, "none", effective.GetType().Name)
            Dim errorFingerprint As String = BuildErrorFingerprint(effective)
            Dim correlation As String = CheckoutFailureRecoveryService.GetCorrelationId(requestId)
            Dim requestMask As String = BuildRequestMask(requestId)
            Dim companyId As Integer = SessionInt(context, "AuthenticatedAziendaID", SessionInt(context, "AziendaID", 0))
            Dim mappedPhase As CheckoutTelemetryPhase = MapPhase(phase)
            Dim body As String =
                "utc=" & DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture) &
                ";correlation=" & SafeToken(correlation, "unknown", 8) &
                ";tenant=company-" & Math.Max(0, companyId).ToString(CultureInfo.InvariantCulture) &
                ";company=" & Math.Max(0, companyId).ToString(CultureInfo.InvariantCulture) &
                ";phase=" & mappedPhase.ToString() &
                ";outcome=" & SafeToken(outcome, "unknown", 32) &
                ";exception=" & SafeToken(exceptionType, "Exception", 64) &
                ";error=" & errorFingerprint &
                ";request=" & requestMask &
                ";idempotency=" & SafeToken(idempotencyState, "unknown", 32) &
                ";transaction=" & SafeToken(transactionState, "none", 32) &
                ";checkpoint=" & SafeToken(lastCheckpoint, "none", 48)

            If TryAppend(primaryDirectory, body, "primary") Then Return True
            If TryAppend(fallbackDirectory, body, "fallback") Then Return True
        Catch
        End Try
        Return False
    End Function

    Friend Shared Function ContainsCorrelation(ByVal directory As String,
                                               ByVal correlationId As String,
                                               ByVal phase As CheckoutTelemetryPhase,
                                               ByVal exceptionType As String) As Boolean
        Try
            Dim path As String = System.IO.Path.Combine(directory, FileName)
            If Not File.Exists(path) Then Return False
            Dim expectedCorrelation As String = "correlation=" & SafeToken(correlationId, "unknown", 8)
            Dim expectedPhase As String = "phase=" & phase.ToString()
            Dim expectedException As String = "exception=" & SafeToken(exceptionType, "Exception", 64)
            Using stream As New FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)
                Using reader As New StreamReader(stream, Encoding.UTF8, True)
                    While Not reader.EndOfStream
                        Dim line As String = reader.ReadLine()
                        If line IsNot Nothing AndAlso line.Contains(expectedCorrelation) AndAlso
                           line.Contains(expectedPhase) AndAlso line.Contains(expectedException) Then Return True
                    End While
                End Using
            End Using
        Catch
        End Try
        Return False
    End Function

    Public Shared Function MapPhase(ByVal phase As String) As CheckoutTelemetryPhase
        Dim value As String = If(phase, String.Empty).Trim().ToLowerInvariant()
        If value.Contains("order-token-payload") Then Return CheckoutTelemetryPhase.BuildOrderToken
        If value.Contains("order-token-protect") OrElse value.Contains("token-protection") Then
            Return CheckoutTelemetryPhase.ProtectOrderToken
        End If
        If value.Contains("order-token-encode") Then Return CheckoutTelemetryPhase.EncodeOrderToken
        If value.Contains("processing-redirect") Then Return CheckoutTelemetryPhase.DispatchOrderProcessing
        If value.Contains("confirm-get") OrElse value.Contains("confirmget") Then Return CheckoutTelemetryPhase.ConfirmGet
        If value.Contains("final-click") OrElse value.Contains("confirm-post") OrElse
           value.Contains("confirmpost") Then Return CheckoutTelemetryPhase.ConfirmPost
        If value.Contains("draft") Then Return CheckoutTelemetryPhase.ValidateDraft
        If value.Contains("address") Then Return CheckoutTelemetryPhase.ValidateAddress
        If value.Contains("shipping") OrElse value.Contains("delivery") Then Return CheckoutTelemetryPhase.ValidateDelivery
        If value.Contains("payment") Then Return CheckoutTelemetryPhase.ValidatePayment
        If value.Contains("cart") OrElse value.Contains("commercial-revalidation") Then Return CheckoutTelemetryPhase.ValidateCart
        If value.Contains("fingerprint") OrElse value.Contains("payload") Then Return CheckoutTelemetryPhase.ValidateFingerprint
        If value.Contains("account") OrElse value.Contains("storefront-context") Then Return CheckoutTelemetryPhase.VerifyAccount
        If value.Contains("claim") OrElse value.Contains("idempotency-claim") Then Return CheckoutTelemetryPhase.TryClaim
        If value.Contains("inventory") OrElse value.Contains("stock") Then Return CheckoutTelemetryPhase.ValidateInventory
        If value.Contains("procedure") Then Return CheckoutTelemetryPhase.ExecuteProcedure
        If value.Contains("complete") AndAlso Not value.Contains("reconcile") Then Return CheckoutTelemetryPhase.CompleteIdempotency
        If value.Contains("commit") OrElse value.Contains("transaction") Then Return CheckoutTelemetryPhase.Commit
        If value.Contains("receipt") OrElse value.Contains("confirmation-redirect") Then Return CheckoutTelemetryPhase.ReceiptRedirect
        If value.Contains("email") OrElse value.Contains("post-commit") Then Return CheckoutTelemetryPhase.PostCommitEmail
        Return CheckoutTelemetryPhase.Unknown
    End Function

    Private Shared Function TryAppend(ByVal directory As String,
                                      ByVal body As String,
                                      ByVal sink As String) As Boolean
        Try
            If String.IsNullOrWhiteSpace(directory) Then Return False
            System.IO.Directory.CreateDirectory(directory)
            Dim path As String = System.IO.Path.Combine(directory, FileName)
            SyncLock WriteLock
                RotateIfRequired(path)
                Using stream As New FileStream(path, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)
                    Using writer As New StreamWriter(stream, New UTF8Encoding(False))
                        writer.WriteLine(body & ";sink=" & sink)
                    End Using
                End Using
            End SyncLock
            Return True
        Catch
            Return False
        End Try
    End Function

    Private Shared Sub RotateIfRequired(ByVal path As String)
        If Not File.Exists(path) OrElse New FileInfo(path).Length < MaxFileBytes Then Return
        For index As Integer = MaxArchives To 1 Step -1
            Dim current As String = path & "." & index.ToString(CultureInfo.InvariantCulture)
            If index = MaxArchives AndAlso File.Exists(current) Then File.Delete(current)
            If index > 1 Then
                Dim previous As String = path & "." & (index - 1).ToString(CultureInfo.InvariantCulture)
                If File.Exists(previous) Then File.Move(previous, current)
            End If
        Next
        File.Move(path, path & ".1")
    End Sub

    Private Shared Function Innermost(ByVal failure As Exception) As Exception
        Dim current As Exception = failure
        While current IsNot Nothing AndAlso current.InnerException IsNot Nothing
            current = current.InnerException
        End While
        Return current
    End Function

    Private Shared Function BuildErrorFingerprint(ByVal failure As Exception) As String
        If failure Is Nothing Then Return "none"
        Dim value As String = failure.GetType().FullName & "|" & failure.HResult.ToString(CultureInfo.InvariantCulture)
        Return Hash(value).Substring(0, 16)
    End Function

    Private Shared Function BuildRequestMask(ByVal requestId As String) As String
        Dim normalized As String = String.Empty
        If Not OrderDurableIdempotencyService.TryNormalizeRequestId(requestId, normalized) Then Return "unknown"
        Return Hash(normalized).Substring(0, 12)
    End Function

    Private Shared Function Hash(ByVal value As String) As String
        Dim bytes() As Byte = Encoding.UTF8.GetBytes(If(value, String.Empty))
        Try
            Using hasher As SHA256 = SHA256.Create()
                Dim digest() As Byte = hasher.ComputeHash(bytes)
                Dim builder As New StringBuilder(digest.Length * 2)
                For Each current As Byte In digest
                    builder.Append(current.ToString("x2", CultureInfo.InvariantCulture))
                Next
                Array.Clear(digest, 0, digest.Length)
                Return builder.ToString()
            End Using
        Finally
            Array.Clear(bytes, 0, bytes.Length)
        End Try
    End Function

    Private Shared Function SafeToken(ByVal value As String, ByVal fallback As String, ByVal maxLength As Integer) As String
        If String.IsNullOrWhiteSpace(value) Then Return fallback
        Dim builder As New StringBuilder()
        For Each current As Char In value.Trim()
            If Char.IsLetterOrDigit(current) OrElse current = "-"c OrElse current = "_"c Then builder.Append(current)
            If builder.Length >= maxLength Then Exit For
        Next
        Return If(builder.Length = 0, fallback, builder.ToString())
    End Function

    Private Shared Function SessionInt(ByVal context As HttpContext,
                                       ByVal key As String,
                                       ByVal fallback As Integer) As Integer
        Try
            Dim parsed As Integer
            If context IsNot Nothing AndAlso context.Session IsNot Nothing AndAlso
               Integer.TryParse(Convert.ToString(context.Session(key)), parsed) Then Return parsed
        Catch
        End Try
        Return fallback
    End Function
End Class
