<%@ Application Language="VB" %>
<script runat="server">
    Imports System
    Imports System.IO
    Imports System.Text

    Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
        Try
            Dim ex As Exception = Server.GetLastError()
            If ex Is Nothing Then Exit Sub

            Dim sb As New StringBuilder()
            sb.AppendLine("=== KEEPSTORE ERROR LOG ===")
            sb.AppendLine("UTC: " & DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"))
            sb.AppendLine("URL: " & If(HttpContext.Current IsNot Nothing AndAlso HttpContext.Current.Request IsNot Nothing,
                                       HttpContext.Current.Request.Url.ToString(), "N/A"))
            sb.AppendLine("IP: " & If(HttpContext.Current IsNot Nothing AndAlso HttpContext.Current.Request IsNot Nothing,
                                      HttpContext.Current.Request.UserHostAddress, "N/A"))
            sb.AppendLine("MESSAGE: " & ex.Message)
            sb.AppendLine("TYPE: " & ex.GetType().FullName)
            sb.AppendLine("STACK: " & ex.StackTrace)

            If ex.InnerException IsNot Nothing Then
                sb.AppendLine("--- INNER EXCEPTION ---")
                sb.AppendLine("MESSAGE: " & ex.InnerException.Message)
                sb.AppendLine("TYPE: " & ex.InnerException.GetType().FullName)
                sb.AppendLine("STACK: " & ex.InnerException.StackTrace)
            End If

            sb.AppendLine("==========================")

            Dim path As String = Server.MapPath("~/App_Data/last_error.txt")
            File.WriteAllText(path, sb.ToString(), Encoding.UTF8)

        Catch
            ' Se non riesce a scrivere, non deve rompere ulteriormente il sito
        End Try
    End Sub
</script>
