Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Diagnostics
Imports System.Globalization
Imports System.IO
Imports System.Net
Imports System.Security.Cryptography
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Script.Serialization

' Server-controlled diagnostics only. Never reads a query/header activation flag.
Public NotInheritable Class HomeServerStageTiming
    Private Const MaximumEntries As Integer = 192
    Private Const MaximumLogBytes As Long = 4194304
    Private Const MaximumRecoveryLogBytes As Long = 262144
    Private Const MaximumRecoveryEntries As Integer = 8
    Private Shared ReadOnly LogGate As New Object()
    Private ReadOnly _started As Long = Stopwatch.GetTimestamp()
    Private ReadOnly _requestId As String = Guid.NewGuid().ToString("N")
    Private ReadOnly _entries As New List(Of Dictionary(Of String, Object))()
    Private ReadOnly _logPath As String
    Private ReadOnly _recoveryPath As String
    Private ReadOnly _applicationFingerprint As String
    Private _recoveryEntries As Integer
    Private _companyId As Integer
    Private _depth As Integer
    Private _dropped As Integer
    Private _finished As Boolean

    Private Sub New(ByVal logPath As String, ByVal recoveryPath As String, ByVal applicationFingerprint As String)
        _logPath = logPath
        _recoveryPath = recoveryPath
        _applicationFingerprint = applicationFingerprint
    End Sub

    Public Shared Function TryStart(ByVal context As HttpContext) As HomeServerStageTiming
        Dim timing As HomeServerStageTiming = Nothing
        Try
            Dim enabled As Boolean = False
            Boolean.TryParse(ConfigurationManager.AppSettings("KeepStore.Diagnostics.HomeStageTiming.Enabled"), enabled)
            If Not enabled OrElse context Is Nothing OrElse context.Request Is Nothing Then Return Nothing
            Dim environmentName As String = ConfigurationManager.AppSettings("KeepStore.Diagnostics.Environment")
            If Not String.Equals(environmentName, "Integration", StringComparison.OrdinalIgnoreCase) Then Return Nothing
            Dim request As HttpRequest = context.Request
            Dim address As IPAddress = Nothing
            Dim loopback As Boolean = request.IsLocal AndAlso
                IPAddress.TryParse(request.UserHostAddress, address) AndAlso IPAddress.IsLoopback(address)
            ' Do not produce even recovery records for an external/insecure peer.
            If Not loopback OrElse Not request.IsSecureConnection Then Return Nothing
            Dim applicationRoot As String = HttpRuntime.AppDomainAppPath
            timing = New HomeServerStageTiming(Path.Combine(applicationRoot, "App_Data", "Logs", "home-stage-timing.log"),
                Path.Combine(applicationRoot, "App_Data", "home-stage-timing-status.log"), FingerprintApplicationPath(applicationRoot))
            timing.WriteRecoveryStatus("activation_entered")
            Dim gateCode As String = ActivationCode(enabled, environmentName, loopback,
                request.IsSecureConnection, request.HttpMethod, request.AppRelativeCurrentExecutionFilePath)
            If gateCode <> "enabled" Then
                timing.WriteRecoveryStatus(gateCode)
                Return Nothing
            End If
            Dim mappedLogPath As String
            Try
                mappedLogPath = context.Server.MapPath("~/App_Data/Logs/home-stage-timing.log")
            Catch
                timing.WriteRecoveryStatus("log_mapping_failed")
                Return Nothing
            End Try
            If Not String.Equals(Path.GetFullPath(mappedLogPath), Path.GetFullPath(timing._logPath), StringComparison.OrdinalIgnoreCase) Then
                timing.WriteRecoveryStatus("log_mapping_mismatch")
                Return Nothing
            End If
            context.AddOnRequestCompleted(Sub(completedContext As HttpContext) timing.ObserveRequestCompleted())
            timing.WriteRecoveryStatus("activation_passed")
            Return timing
        Catch
            If timing IsNot Nothing Then timing.WriteRecoveryStatus("activation_failed")
            Return Nothing
        End Try
    End Function

    Friend Shared Function CanEnable(ByVal enabled As Boolean, ByVal environment As String,
                                      ByVal loopback As Boolean, ByVal https As Boolean,
                                      ByVal method As String, ByVal executionPath As String) As Boolean
        Return ActivationCode(enabled, environment, loopback, https, method, executionPath) = "enabled"
    End Function

    Friend Shared Function ActivationCode(ByVal enabled As Boolean, ByVal environment As String,
                                          ByVal loopback As Boolean, ByVal https As Boolean,
                                          ByVal method As String, ByVal executionPath As String) As String
        If Not enabled Then Return "gate_disabled"
        If Not String.Equals(environment, "Integration", StringComparison.OrdinalIgnoreCase) Then Return "gate_environment"
        If Not loopback Then Return "gate_peer"
        If Not https Then Return "gate_https"
        If Not String.Equals(method, "GET", StringComparison.OrdinalIgnoreCase) Then Return "gate_method"
        If Not String.Equals(executionPath, "~/Default.aspx", StringComparison.OrdinalIgnoreCase) Then Return "gate_home_path"
        Return "enabled"
    End Function

    Private Shared Function FingerprintApplicationPath(ByVal applicationRoot As String) As String
        Dim normalized As String = Path.GetFullPath(applicationRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar).ToUpperInvariant()
        Using hash As SHA256 = SHA256.Create()
            Return BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(normalized))).Replace("-", "").ToLowerInvariant()
        End Using
    End Function

    Private Sub WriteRecoveryStatus(ByVal code As String)
        Try
            If _recoveryEntries >= MaximumRecoveryEntries Then Return
            _recoveryEntries += 1
            Dim payload As New Dictionary(Of String, Object) From {
                {"schema", "home-stage-status-v1"}, {"revision", "recovery-v1"}, {"requestId", _requestId},
                {"utc", DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture)},
                {"code", code}, {"companyId", _companyId}, {"applicationPathFingerprint", _applicationFingerprint}}
            Dim encoding As New UTF8Encoding(False)
            Dim record As String = New JavaScriptSerializer().Serialize(payload) & Environment.NewLine
            SyncLock LogGate
                Dim currentLength As Long = If(File.Exists(_recoveryPath), New FileInfo(_recoveryPath).Length, 0L)
                If currentLength + encoding.GetByteCount(record) > MaximumRecoveryLogBytes Then Return
                Directory.CreateDirectory(Path.GetDirectoryName(_recoveryPath))
                File.AppendAllText(_recoveryPath, record, encoding)
            End SyncLock
        Catch
            ' No exception messages, physical paths, URL or HTTP diagnostic output.
            ' A failure of both private sinks cannot be attributed from their absence.
        End Try
    End Sub

    Private Sub ObserveRequestCompleted()
        Try
            If Not _finished Then
                _finished = True
                WriteRecoveryStatus("completion_not_reached")
            End If
        Catch
        End Try
    End Sub

    Public Sub SetCompany(ByVal companyId As Integer)
        If companyId > 0 AndAlso _companyId = 0 Then
            _companyId = companyId
            WriteRecoveryStatus("tenant_validated")
        End If
    End Sub

    Public Shared Function Measure(ByVal timing As HomeServerStageTiming, ByVal stage As String) As IDisposable
        If timing Is Nothing OrElse timing._finished Then Return Nothing
        Try
            If Not IsSafeStage(stage) Then Return Nothing
            If timing._entries.Count >= MaximumEntries Then
                timing._dropped += 1
                Return Nothing
            End If
            Return New StageScope(timing, stage)
        Catch
            Return Nothing
        End Try
    End Function

    Public Shared Sub Mark(ByVal timing As HomeServerStageTiming, ByVal stage As String)
        If timing Is Nothing OrElse timing._finished Then Return
        Try
            If Not IsSafeStage(stage) Then Return
            If timing._entries.Count >= MaximumEntries Then
                timing._dropped += 1
                Return
            End If
            timing._entries.Add(New Dictionary(Of String, Object) From {
                {"stage", stage}, {"kind", "mark"}, {"offsetMs", Milliseconds(Stopwatch.GetTimestamp() - timing._started)}})
        Catch
            ' Diagnostics must never alter the page outcome.
        End Try
    End Sub

    Private Shared Function IsSafeStage(ByVal stage As String) As Boolean
        Return stage IsNot Nothing AndAlso stage.Length <= 80 AndAlso
            Regex.IsMatch(stage, "^[a-zA-Z][a-zA-Z0-9_.-]*$")
    End Function

    Private Shared Function Milliseconds(ByVal ticks As Long) As Double
        Return Math.Round(CDbl(ticks) * 1000.0R / CDbl(Stopwatch.Frequency), 3)
    End Function

    Public Sub Complete(ByVal statusCode As Integer)
        If _finished Then Return
        _finished = True
        WriteRecoveryStatus("completion_entered")
        If _companyId <= 0 Then
            WriteRecoveryStatus("tenant_not_validated")
            Return
        End If
        Dim record As String
        Try
            Dim payload As New Dictionary(Of String, Object) From {
                {"schema", "home-stage-timing-v1"}, {"requestId", _requestId},
                {"utc", DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture)},
                {"companyId", _companyId}, {"httpStatus", statusCode},
                {"clockFrequency", Stopwatch.Frequency}, {"highResolution", Stopwatch.IsHighResolution},
                {"pageObservedMs", Milliseconds(Stopwatch.GetTimestamp() - _started)},
                {"spansAreInclusive", True}, {"droppedEntries", _dropped}, {"entries", _entries}}
            Dim line As String = New JavaScriptSerializer().Serialize(payload)
            record = line & Environment.NewLine
        Catch
            WriteRecoveryStatus("trace_serialization_failed")
            Return
        End Try
        Try
            Dim encoding As New UTF8Encoding(False)
            ' No raw URL, SQL, parameters, errors, user, session or cookie data.
            SyncLock LogGate
                Dim currentLength As Long = If(File.Exists(_logPath), New FileInfo(_logPath).Length, 0L)
                If currentLength + encoding.GetByteCount(record) > MaximumLogBytes Then
                    WriteRecoveryStatus("trace_log_budget_exceeded")
                    Return
                End If
                Directory.CreateDirectory(Path.GetDirectoryName(_logPath))
                File.AppendAllText(_logPath, record, encoding)
            End SyncLock
            WriteRecoveryStatus("trace_written")
        Catch
            WriteRecoveryStatus("trace_write_failed")
            ' Includes unavailable log directory/ACL/full log; do not change HTTP.
        End Try
    End Sub

    Private NotInheritable Class StageScope
        Implements IDisposable
        Private ReadOnly _owner As HomeServerStageTiming
        Private ReadOnly _entry As Dictionary(Of String, Object)
        Private ReadOnly _start As Long
        Private _disposed As Boolean

        Public Sub New(ByVal owner As HomeServerStageTiming, ByVal stage As String)
            _owner = owner
            _start = Stopwatch.GetTimestamp()
            _entry = New Dictionary(Of String, Object) From {
                {"stage", stage}, {"kind", "span"}, {"depth", owner._depth},
                {"offsetMs", Milliseconds(_start - owner._started)}}
            owner._depth += 1
            owner._entries.Add(_entry)
        End Sub

        Public Sub Dispose() Implements IDisposable.Dispose
            If _disposed Then Return
            _disposed = True
            Try
                _entry("durationMs") = Milliseconds(Stopwatch.GetTimestamp() - _start)
                _owner._depth = Math.Max(0, _owner._depth - 1)
            Catch
            End Try
        End Sub
    End Class
End Class
