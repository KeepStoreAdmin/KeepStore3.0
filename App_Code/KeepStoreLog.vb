Imports System
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Hosting
Imports System.Diagnostics
Imports System.Security.Principal

' KeepStoreLog
' Central logging helper:
' - Primary: ~/App_Data/Logs
' - Fallback: %TEMP%\KeepStoreLogs
' - Never throws (fail-open). When both fail, emits Trace.WriteLine.

Public Module KeepStoreLog

    Private ReadOnly _lockObj As New Object()

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
            name = name.Replace(" ", "-").Replace("/", "-").Replace("\", "-")
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

End Module
