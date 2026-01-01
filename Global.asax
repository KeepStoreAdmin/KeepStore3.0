<%@ Application Language="VB" %>
<script runat="server">

' -----------------------------------------------------------------------------
' Global.asax
' - Nessun redirect automatico (evita loop su 404.aspx)
' - Log minimale degli errori non gestiti (se App_Data è scrivibile)
' -----------------------------------------------------------------------------

Sub Application_Start(ByVal sender As Object, ByVal e As EventArgs)
End Sub

Sub Session_Start(ByVal sender As Object, ByVal e As EventArgs)
End Sub

Sub Application_BeginRequest(ByVal sender As Object, ByVal e As EventArgs)
End Sub

Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
    ' Log (best-effort) senza alterare la risposta
    Try
        Dim ex As Exception = Server.GetLastError()
        If ex Is Nothing Then Exit Sub

        Dim url As String = ""
        Try
            url = HttpContext.Current.Request.RawUrl
        Catch
        End Try

        Dim path As String = ""
        Try
            path = HttpContext.Current.Server.MapPath("~/App_Data/errors.log")
        Catch
        End Try

        If Not String.IsNullOrEmpty(path) Then
            Dim sep As String = Environment.NewLine & "------------------------------------------------------------" & Environment.NewLine
            Dim msg As String = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") & " | " & url & Environment.NewLine & ex.ToString() & sep
            System.IO.File.AppendAllText(path, msg)
        End If
    Catch
        ' non interrompere l'app
    End Try

    ' IMPORTANTISSIMO: qui NON fare Response.Redirect a pagine di errore
    ' (è la causa tipica dei loop ERR_TOO_MANY_REDIRECTS).
End Sub

Sub Application_End(ByVal sender As Object, ByVal e As EventArgs)
End Sub

</script>
