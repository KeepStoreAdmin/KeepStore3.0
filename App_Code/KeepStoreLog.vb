Imports System
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Hosting
Imports System.Diagnostics
Imports System.Security.Principal
Imports System.Collections.Generic

' KeepStoreLog
' Central logging helper:
' - Primary: ~/App_Data/Logs
' - Fallback: %TEMP%\KeepStoreLogs
' - Never throws (fail-open). When both fail, emits Trace.WriteLine.
'
' STEP31:
' - Adds lightweight log maintenance (retention + size cap) to prevent App_Data/Logs growth.

Public Module KeepStoreLog

    Private ReadOnly _lockObj As New Object()

    ' Maintenance guard (in-memory; resets on app recycle)
    Private ReadOnly _maintenanceLock As New Object()
    Private _lastMaintenanceUtc As DateTime = DateTime.MinValue

    ' Policy (tune if needed)
    Private Const LOG_KEEP_DAYS As Integer = 30
    Private Const LOG_MAX_TOTAL_MB As Integer = 300
    Private Const LOG_PROTECT_RECENT_DAYS As Integer = 2   ' never delete logs newer than this, even under size pressure

    Public Function GetPrimaryLogDirPhysical(Optional ByVal ctx As HttpContext = Nothing) As String
        Try
            If ctx IsNot Nothing Then
                Return ctx.Server.MapPath("~/App_Data/Logs")
            End If

            Dim p As String = HostingEnvironment.MapPath("~/App_Data/Logs")
            If Not String.IsNullOrEmpty(p) Then Return p
        Catch
        End Try

        Return ""
    End Function

    Public Function GetFallbackLogDirPhysical() As String
        Try
            Return Path.Combine(Path.GetTempPath(), "KeepStoreLogs")
        Catch
            Return ""
        End Try
    End Function

    Public Function GetProcessIdentity() As String
        Try
            Dim wi As WindowsIdentity = WindowsIdentity.GetCurrent()
            If wi IsNot Nothing AndAlso Not String.IsNullOrEmpty(wi.Name) Then
                Return wi.Name
            End If
        Catch
        End Try
        Return ""
    End Function

    Public Function TryAppendLine(ByVal fileName As String, ByVal line As String, Optional ByVal ctx As HttpContext = Nothing, Optional ByRef err As Exception = Nothing) As Boolean
        err = Nothing

        ' Best-effort maintenance (never throws)
        Try
            EnsureLogMaintenance(ctx)
        Catch
        End Try

        Dim e1 As Exception = Nothing
        Dim primary As String = GetPrimaryLogDirPhysical(ctx)
        If Not String.IsNullOrEmpty(primary) Then
            If TryAppendLineInDir(primary, fileName, line, e1) Then Return True
        End If

        Dim e2 As Exception = Nothing
        Dim fallback As String = GetFallbackLogDirPhysical()
        If Not String.IsNullOrEmpty(fallback) Then
            If TryAppendLineInDir(fallback, fileName, line, e2) Then Return True
        End If

        If e1 IsNot Nothing Then
            err = e1
        ElseIf e2 IsNot Nothing Then
            err = e2
        End If

        Try
            Trace.WriteLine("[KeepStoreLog] " & SafeFileName(fileName) & " | " & line)
        Catch
        End Try

        Return False
    End Function

    Public Sub Info(ByVal area As String, ByVal msg As String, Optional ByVal ctx As HttpContext = Nothing)
        Dim fn As String = SafeFileName(area) & ".log"
        Dim line As String = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") & " | INFO | " & msg
        Dim ex As Exception = Nothing
        TryAppendLine(fn, line, ctx, ex)
    End Sub

    Public Sub [Error](ByVal area As String, ByVal msg As String, ByVal ex As Exception, Optional ByVal ctx As HttpContext = Nothing)
        Dim fn As String = SafeFileName(area) & ".log"
        Dim line As String = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") & " | ERROR | " & msg
        If ex IsNot Nothing Then
            line &= " | " & ex.GetType().Name & " - " & ex.Message
        End If

        Dim e As Exception = Nothing
        TryAppendLine(fn, line, ctx, e)

        ' Extra trace with stack, but never throw.
        Try
            If ex IsNot Nothing Then Trace.WriteLine(ex.ToString())
        Catch
        End Try
    End Sub

    Private Function SafeFileName(ByVal s As String) As String
        Try
            If String.IsNullOrEmpty(s) Then Return "app"
            Dim name As String = s.Trim()
            name = name.Replace(" ", "-").Replace("/", "-").Replace("\\", "-")
            For Each c As Char In Path.GetInvalidFileNameChars()
                name = name.Replace(c, "-"c)
            Next
            If name.Length = 0 Then name = "app"
            If name.Length > 60 Then name = name.Substring(0, 60)
            Return name.ToLowerInvariant()
        Catch
            Return "app"
        End Try
    End Function

    Private Function TryAppendLineInDir(ByVal dir As String, ByVal fileName As String, ByVal line As String, ByRef err As Exception) As Boolean
        Try
            If String.IsNullOrEmpty(dir) Then Return False

            Dim fn As String = fileName
            If String.IsNullOrEmpty(fn) Then fn = "app.log"
            fn = fn.Trim()
            For Each c As Char In Path.GetInvalidFileNameChars()
                fn = fn.Replace(c, "-"c)
            Next

            Directory.CreateDirectory(dir)
            Dim fp As String = Path.Combine(dir, fn)

            SyncLock _lockObj
                Using fs As New FileStream(fp, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)
                    Using sw As New StreamWriter(fs, Encoding.UTF8)
                        sw.WriteLine(line)
                    End Using
                End Using
            End SyncLock

            Return True

        Catch ex As Exception
            err = ex
            Return False
        End Try
    End Function

    ' ------------------------------------------------------------
    ' STEP31 - Maintenance helpers (retention + size cap)
    ' ------------------------------------------------------------
    Private Sub EnsureLogMaintenance(Optional ByVal ctx As HttpContext = Nothing)
        Dim nowUtc As DateTime = DateTime.UtcNow

        ' Don’t run too frequently (cost: directory enumeration)
        If _lastMaintenanceUtc <> DateTime.MinValue AndAlso (nowUtc - _lastMaintenanceUtc).TotalHours < 12 Then
            Return
        End If

        SyncLock _maintenanceLock
            If _lastMaintenanceUtc <> DateTime.MinValue AndAlso (nowUtc - _lastMaintenanceUtc).TotalHours < 12 Then
                Return
            End If
            _lastMaintenanceUtc = nowUtc
        End SyncLock

        Dim dirs As New List(Of String)()

        Dim primary As String = GetPrimaryLogDirPhysical(ctx)
        If Not String.IsNullOrEmpty(primary) Then dirs.Add(primary)

        Dim fallback As String = GetFallbackLogDirPhysical()
        If Not String.IsNullOrEmpty(fallback) AndAlso (String.IsNullOrEmpty(primary) OrElse Not String.Equals(primary, fallback, StringComparison.OrdinalIgnoreCase)) Then
            dirs.Add(fallback)
        End If

        For Each d As String In dirs
            CleanupLogDirectory(d, LOG_KEEP_DAYS, LOG_MAX_TOTAL_MB, LOG_PROTECT_RECENT_DAYS)
        Next
    End Sub

    Private Sub CleanupLogDirectory(ByVal dir As String, ByVal keepDays As Integer, ByVal maxTotalMb As Integer, ByVal protectRecentDays As Integer)
        Try
            If String.IsNullOrEmpty(dir) Then Return
            If Not Directory.Exists(dir) Then Return

            Dim nowUtc As DateTime = DateTime.UtcNow
            Dim keepThresholdUtc As DateTime = nowUtc.AddDays(-Math.Max(1, keepDays))
            Dim protectThresholdUtc As DateTime = nowUtc.AddDays(-Math.Max(0, protectRecentDays))

            Dim files As String() = Nothing
            Try
                files = Directory.GetFiles(dir, "*.log", SearchOption.TopDirectoryOnly)
            Catch
                Return
            End Try

            If files Is Nothing OrElse files.Length = 0 Then Return

            ' 1) Retention by age
            For Each fp As String In files
                Try
                    Dim fi As New FileInfo(fp)
                    If fi.Exists AndAlso fi.LastWriteTimeUtc < keepThresholdUtc Then
                        TryDeleteFile(fi.FullName)
                    End If
                Catch
                End Try
            Next

            ' 2) Size cap (delete oldest first, but never touch very recent logs)
            Dim list As New List(Of FileInfo)()
            For Each fp As String In files
                Try
                    Dim fi As New FileInfo(fp)
                    If fi.Exists Then list.Add(fi)
                Catch
                End Try
            Next

            If list.Count = 0 Then Return

            Dim totalBytes As Long = 0
            For Each fi As FileInfo In list
                Try
                    totalBytes += fi.Length
                Catch
                End Try
            Next

            Dim maxBytes As Long = CLng(maxTotalMb) * 1024L * 1024L
            If maxBytes <= 0 Then Return
            If totalBytes <= maxBytes Then Return

            ' Delete from oldest to newest, but do not delete logs within protect window.
            list.Sort(Function(a As FileInfo, b As FileInfo) a.LastWriteTimeUtc.CompareTo(b.LastWriteTimeUtc))

            For Each fi As FileInfo In list
                If totalBytes <= maxBytes Then Exit For

                Try
                    If fi.Exists AndAlso fi.LastWriteTimeUtc < protectThresholdUtc Then
                        Dim len As Long = fi.Length
                        If TryDeleteFile(fi.FullName) Then
                            totalBytes -= len
                        End If
                    End If
                Catch
                End Try
            Next

        Catch
            ' Never throw
        End Try
    End Sub

    Private Function TryDeleteFile(ByVal fullPath As String) As Boolean
        Try
            If String.IsNullOrEmpty(fullPath) Then Return False
            If Not File.Exists(fullPath) Then Return False
            File.Delete(fullPath)
            Return True
        Catch
            Return False
        End Try
    End Function

End Module
