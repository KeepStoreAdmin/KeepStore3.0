<%@ Application Language="VB" %>

<script runat="server">

' NOTE:
' - Questo Global.asax serve a forzare HTTPS senza dipendere da IIS URL Rewrite.
' - Non richiede modifiche a web.config oltre alla tua machineKey già impostata.
' - Per funzionare, IIS deve avere il binding HTTPS (certificato valido) sul sito.

Sub Application_BeginRequest(ByVal sender As Object, ByVal e As EventArgs)
    Try
        If Context Is Nothing OrElse Request Is Nothing OrElse Request.Url Is Nothing Then Exit Sub

        ' Evita redirect in locale
        If Request.IsLocal Then Exit Sub

        ' Determina se la richiesta è già HTTPS (o dietro proxy con header)
        Dim isHttps As Boolean = Request.IsSecureConnection
        Dim xfProto As String = Request.Headers("X-Forwarded-Proto")
        If (Not String.IsNullOrEmpty(xfProto)) AndAlso xfProto.Equals("https", StringComparison.OrdinalIgnoreCase) Then
            isHttps = True
        End If

        If Not isHttps Then
            Dim u As Uri = Request.Url
            Dim b As New UriBuilder(u)
            b.Scheme = Uri.UriSchemeHttps
            b.Port = -1 ' porta di default (443)

            Response.StatusCode = 301
            Response.RedirectLocation = b.Uri.ToString()
            Context.ApplicationInstance.CompleteRequest()
        End If

    Catch
        ' Non interrompere la request pipeline se qualcosa va storto.
    End Try
End Sub

Sub Application_PreSendRequestHeaders(ByVal sender As Object, ByVal e As EventArgs)
    Try
        If Context Is Nothing OrElse Response Is Nothing Then Exit Sub

        ' Hardening minimo (non distruttivo)
        If Response.Headers("X-Content-Type-Options") Is Nothing Then Response.Headers("X-Content-Type-Options") = "nosniff"
        If Response.Headers("X-Frame-Options") Is Nothing Then Response.Headers("X-Frame-Options") = "SAMEORIGIN"
        If Response.Headers("Referrer-Policy") Is Nothing Then Response.Headers("Referrer-Policy") = "strict-origin-when-cross-origin"

        ' HSTS solo se la richiesta è HTTPS (evita blocchi in caso di debug su HTTP)
        Dim isHttps As Boolean = False
        If Request IsNot Nothing Then
            isHttps = Request.IsSecureConnection
            Dim xfProto As String = Request.Headers("X-Forwarded-Proto")
            If (Not String.IsNullOrEmpty(xfProto)) AndAlso xfProto.Equals("https", StringComparison.OrdinalIgnoreCase) Then
                isHttps = True
            End If
        End If

        If isHttps Then
            If Response.Headers("Strict-Transport-Security") Is Nothing Then
                Response.Headers("Strict-Transport-Security") = "max-age=31536000; includeSubDomains"
            End If
        End If

    Catch
    End Try
End Sub

</script>
