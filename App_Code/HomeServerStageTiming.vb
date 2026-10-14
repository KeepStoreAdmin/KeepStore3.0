Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Diagnostics
Imports System.Globalization
Imports System.IO
Imports System.Net
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Web.Script.Serialization

' Server-controlled diagnostics only. Never reads a query/header activation flag.
Public NotInheritable Class HomeServerStageTiming
    Private Const MaximumEntries As Integer = 192
    Private Const MaximumLogBytes As Long = 4194304
    Private Shared ReadOnly LogGate As New Object()
    Private ReadOnly _started As Long = Stopwatch.GetTimestamp()
    Private ReadOnly _requestId As String = Guid.NewGuid().ToString("N")
    Private ReadOnly _entries As New List(Of Dictionary(Of String, Object))()
    Private ReadOnly _logPath As String
    Private _companyId As Integer
    Private _depth As Integer
    Private _dropped As Integer
    Private _finished As Boolean

    Private Sub New(ByVal logPath As String)
        _logPath = logPath
    End Sub

    Public Shared Function TryStart(ByVal context As HttpContext) As HomeServerStageTiming
        Try
            Dim enabled As Boolean = False
            Boolean.TryParse(ConfigurationManager.AppSettings("KeepStore.Diagnostics.HomeStageTiming.Enabled"), enabled)
            If Not enabled OrElse context Is Nothing OrElse context.Request Is Nothing Then Return Nothing
            Dim request As HttpRequest = context.Request
            Dim address As IPAddress = Nothing
            Dim loopback As Boolean = request.IsLocal AndAlso
                IPAddress.TryParse(request.UserHostAddress, address) AndAlso IPAddress.IsLoopback(address)
            If Not CanEnable(enabled, ConfigurationManager.AppSettings("KeepStore.Diagnostics.Environment"),
                             loopback, request.IsSecureConnection, request.HttpMethod,
                             request.AppRelativeCurrentExecutionFilePath) Then Return Nothing
            Return New HomeServerStageTiming(Path.Combine(HttpRuntime.AppDomainAppPath,
                "App_Data", "Logs", "home-stage-timing.log"))
        Catch
            Return Nothing
        End Try
    End Function

    Friend Shared Function CanEnable(ByVal enabled As Boolean, ByVal environment As String,
                                      ByVal loopback As Boolean, ByVal https As Boolean,
                                      ByVal method As String, ByVal executionPath As String) As Boolean
        Return enabled AndAlso loopback AndAlso https AndAlso
            String.Equals(environment, "Integration", StringComparison.OrdinalIgnoreCase) AndAlso
            String.Equals(method, "GET", StringComparison.OrdinalIgnoreCase) AndAlso
            String.Equals(executionPath, "~/Default.aspx", StringComparison.OrdinalIgnoreCase)
    End Function

    Public Sub SetCompany(ByVal companyId As Integer)
        If companyId > 0 AndAlso _companyId = 0 Then _companyId = companyId
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
        Try
            If _companyId <= 0 Then Return
            Dim payload As New Dictionary(Of String, Object) From {
                {"schema", "home-stage-timing-v1"}, {"requestId", _requestId},
                {"utc", DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture)},
                {"companyId", _companyId}, {"httpStatus", statusCode},
                {"clockFrequency", Stopwatch.Frequency}, {"highResolution", Stopwatch.IsHighResolution},
                {"pageObservedMs", Milliseconds(Stopwatch.GetTimestamp() - _started)},
                {"spansAreInclusive", True}, {"droppedEntries", _dropped}, {"entries", _entries}}
            Dim line As String = New JavaScriptSerializer().Serialize(payload)
            Dim encoding As New UTF8Encoding(False)
            Dim record As String = line & Environment.NewLine
            ' No raw URL, SQL, parameters, errors, user, session or cookie data.
            SyncLock LogGate
                Dim currentLength As Long = If(File.Exists(_logPath), New FileInfo(_logPath).Length, 0L)
                If currentLength + encoding.GetByteCount(record) > MaximumLogBytes Then Return
                Directory.CreateDirectory(Path.GetDirectoryName(_logPath))
                File.AppendAllText(_logPath, record, encoding)
            End SyncLock
        Catch
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
