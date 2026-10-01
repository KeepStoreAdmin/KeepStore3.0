Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.IO
Imports System.Reflection
Imports System.Web
Imports MySql.Data.MySqlClient

' Console-only sink: no HttpContext, raw exception, owner token or personal data.
' The Website compilation does not include Tools; runtime uses its existing logger.
Public NotInheritable Class KeepStoreLog
    Public Shared Sub Info(ByVal area As String, ByVal message As String, Optional ByVal context As HttpContext = Nothing)
        If area = "persistent-cart-cleanup" Then
            Select Case message
                Case "CLEANUP_PREFLIGHT_FAILED", "CLEANUP_OWNER_ANOMALY_PRESERVED", "CLEANUP_OWNER_FAILED_OR_INDETERMINATE"
                    Console.Error.WriteLine(message)
            End Select
        ElseIf area = "cart-transaction-retry" AndAlso message.IndexOf("decision=retry-planned", StringComparison.Ordinal) >= 0 Then
            Console.Error.WriteLine("CLEANUP_TRANSIENT_RETRY")
        End If
    End Sub
End Class

Public Module PersistentCartCleanupRunner
    Public Function Main(ByVal args As String()) As Integer
        AddHandler AppDomain.CurrentDomain.AssemblyResolve, Function(sender, request)
            Dim name = New AssemblyName(request.Name).Name
            If Not System.Text.RegularExpressions.Regex.IsMatch(name, "\A[A-Za-z0-9_.-]+\z") Then Return Nothing
            Dim file = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, name & ".dll")
            Return If(IO.File.Exists(file), Assembly.LoadFrom(file), Nothing)
        End Function
        Dim connectionString As String = Nothing
        Try
            Dim company As Integer, batch As Integer
            If args.Length <> 2 OrElse Not Integer.TryParse(args(0), NumberStyles.None, CultureInfo.InvariantCulture, company) OrElse
               Not Integer.TryParse(args(1), NumberStyles.None, CultureInfo.InvariantCulture, batch) Then
                Throw New ArgumentException("CLEANUP_INPUT_INVALID")
            End If
            ' Secret-bearing configuration is supplied only through stdin, never argv or a copied file.
            connectionString = Console.ReadLine()
            Dim builder As New MySqlConnectionStringBuilder(connectionString)
            If String.IsNullOrWhiteSpace(builder.Database) Then Throw New ArgumentException("CLEANUP_DATABASE_REQUIRED")
            Dim result = PersistentAnonymousCartCleanupService.RunBatch(builder.ConnectionString, company, batch)
            Console.WriteLine("ActiveExpiredProcessed=" & result.ActiveExpiredProcessed.ToString(CultureInfo.InvariantCulture))
            Console.WriteLine("ActiveCartRowsDeleted=" & result.ActiveCartRowsDeleted.ToString(CultureInfo.InvariantCulture))
            Console.WriteLine("ConsumedDeleted=" & result.ConsumedDeleted.ToString(CultureInfo.InvariantCulture))
            Console.WriteLine("RevokedDeleted=" & result.RevokedDeleted.ToString(CultureInfo.InvariantCulture))
            Console.WriteLine("Anomalies=" & result.Anomalies.ToString(CultureInfo.InvariantCulture))
            Console.WriteLine("Errors=" & result.Errors.ToString(CultureInfo.InvariantCulture))
            Console.WriteLine("CandidatesExamined=" & result.CandidatesExamined.ToString(CultureInfo.InvariantCulture))
            Return If(result.Errors > 0 OrElse result.Anomalies > 0, 1, 0)
        Catch
            Console.Error.WriteLine("CLEANUP_RUNNER_FAILED")
            Return 2
        Finally
            connectionString = Nothing
        End Try
    End Function
End Module
