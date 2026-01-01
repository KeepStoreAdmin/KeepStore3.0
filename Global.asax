<%@ Application Language="VB" %>

<script runat="server">

    Sub Application_Start(ByVal sender As Object, ByVal e As EventArgs)
        ' Avvio applicazione
    End Sub

    Sub Session_Start(ByVal sender As Object, ByVal e As EventArgs)
        ' Avvio sessione
    End Sub

    Sub Application_BeginRequest(ByVal sender As Object, ByVal e As EventArgs)
        ' Inizio richiesta
    End Sub

    Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
        ' IMPORTANTE:
        ' Non fare Response.Redirect qui verso 404.aspx o pagine ASPX,
        ' altrimenti rischi loop se l’errore capita anche sulla pagina di errore.
        ' Lasciamo gestire a customErrors/httpErrors su pagine statiche .htm
    End Sub

    Sub Session_End(ByVal sender As Object, ByVal e As EventArgs)
        ' Fine sessione
    End Sub

    Sub Application_End(ByVal sender As Object, ByVal e As EventArgs)
        ' Fine applicazione
    End Sub

</script>
