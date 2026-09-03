Imports System
Imports System.Configuration
Imports System.Data
Imports System.Net
Imports System.Web
Imports MySql.Data.MySqlClient

Public NotInheritable Class LoginAccessAuditRecorder
    Private Const RecordedLoginIdSessionKey As String = "KeepStore:LoginAccessAudit:RecordedLoginId"

    Private Sub New()
    End Sub

    Public Shared Function NormalizeClientIp(ByVal rawAddress As String) As String
        Dim parsedAddress As IPAddress = Nothing
        If String.IsNullOrWhiteSpace(rawAddress) OrElse Not IPAddress.TryParse(rawAddress.Trim(), parsedAddress) Then
            Return Nothing
        End If

        Return parsedAddress.ToString()
    End Function

    Public Shared Sub ClearAuthenticationMarker(ByVal context As HttpContext)
        If context Is Nothing OrElse context.Session Is Nothing Then Return
        context.Session.Remove(RecordedLoginIdSessionKey)
    End Sub

    Public Shared Function TryRecordSuccessfulLogin(ByVal context As HttpContext, ByVal loginId As Integer) As Boolean
        If context Is Nothing OrElse context.Request Is Nothing OrElse loginId <= 0 Then
            LogFailure(context, "invalid recorder input", Nothing)
            Return False
        End If

        If WasAlreadyRecorded(context, loginId) Then Return True

        Dim normalizedIp As String = NormalizeClientIp(context.Request.UserHostAddress)

        Try
            Dim settings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then
                Throw New ConfigurationErrorsException("Login audit connection is unavailable.")
            End If

            Using connection As New MySqlConnection(settings.ConnectionString)
                connection.Open()

                Using command As New MySqlCommand(
                    "UPDATE login " &
                    "SET UltimoAccesso = NOW(), " &
                    "UltimoIp = @UltimoIp, " &
                    "NumeroAccessi = COALESCE(NumeroAccessi, 0) + 1 " &
                    "WHERE id = @LoginId", connection)

                    command.CommandType = CommandType.Text
                    command.Parameters.Add("@UltimoIp", MySqlDbType.VarChar, 45).Value =
                        If(String.IsNullOrEmpty(normalizedIp), CType(DBNull.Value, Object), normalizedIp)
                    command.Parameters.Add("@LoginId", MySqlDbType.Int32).Value = loginId

                    Dim affectedRows As Integer = command.ExecuteNonQuery()
                    If affectedRows <> 1 Then
                        Throw New InvalidOperationException("Login audit did not update exactly one row.")
                    End If
                End Using
            End Using

            MarkRecorded(context, loginId)
            Return True
        Catch ex As Exception
            LogFailure(context, "database update failed", ex)
            Return False
        End Try
    End Function

    Private Shared Function WasAlreadyRecorded(ByVal context As HttpContext, ByVal loginId As Integer) As Boolean
        If context.Session Is Nothing Then Return False

        Dim recordedLoginId As Integer = 0
        Return Integer.TryParse(Convert.ToString(context.Session(RecordedLoginIdSessionKey)), recordedLoginId) AndAlso
            recordedLoginId = loginId
    End Function

    Private Shared Sub MarkRecorded(ByVal context As HttpContext, ByVal loginId As Integer)
        If context.Session IsNot Nothing Then
            context.Session(RecordedLoginIdSessionKey) = loginId
        End If
    End Sub

    Private Shared Sub LogFailure(ByVal context As HttpContext, ByVal stage As String, ByVal ex As Exception)
        Dim errorType As String = If(ex Is Nothing, "none", ex.GetType().Name)
        KeepStoreLog.Error(
            "login-access-audit",
            "Login access audit " & stage & ". Error type: " & errorType & ".",
            Nothing,
            context)
    End Sub
End Class
