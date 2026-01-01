<%@ Application Language="VB" %>

<script runat="server">

    Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
        Try
            Dim ex As Exception = Server.GetLastError()
            If ex Is Nothing Then Exit Sub

            Dim path As String = Server.MapPath("~/App_Data/last_error.txt")
            Dim msg As String = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") & Environment.NewLine &
                                "URL: " & (If(HttpContext.Current IsNot Nothing AndAlso HttpContext.Current.Request IsNot Nothing, HttpContext.Current.Request.Url.ToString(), "")) & Environment.NewLine &
                                ex.ToString() & Environment.NewLine &
                                "------------------------------------------------------------" & Environment.NewLine

            System.IO.File.AppendAllText(path, msg, System.Text.Encoding.UTF8)
        Catch
            ' mai bloccare l'app per un errore di logging
        End Try
    End Sub

</script>
