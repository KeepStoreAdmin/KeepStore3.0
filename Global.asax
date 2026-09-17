<%@ Application Language="VB" %>

<script runat="server">

' NOTE:
' - Questo Global.asax serve a forzare HTTPS senza dipendere da IIS URL Rewrite.
' - Non richiede modifiche a web.config oltre alla tua machineKey già impostata.
' - Per funzionare, IIS deve avere il binding HTTPS (certificato valido) sul sito.

Sub Application_BeginRequest(ByVal sender As Object, ByVal e As EventArgs)
    Try
        If Context Is Nothing OrElse Request Is Nothing OrElse Request.Url Is Nothing Then Exit Sub

        ' Gli endpoint SEO pubblici sono dinamici e tenant-aware. I nomi standard
        ' restano /robots.txt e /sitemap.xml, senza mantenere file statici paralleli.
        Dim requestPath As String = Convert.ToString(Request.Url.AbsolutePath)
        If requestPath.EndsWith("/robots.txt", StringComparison.OrdinalIgnoreCase) Then
            Context.RewritePath("~/robots.aspx", String.Empty, Request.Url.Query.TrimStart("?"c), False)
        ElseIf requestPath.EndsWith("/sitemap.xml", StringComparison.OrdinalIgnoreCase) Then
            Context.RewritePath("~/sitemap.aspx", String.Empty, Request.Url.Query.TrimStart("?"c), False)
        End If

        ' Evita redirect in locale
        If Request.IsLocal Then Exit Sub

        ' La canonical authority arriva esclusivamente dalla configurazione
        ' azienda (url1/url2), mai da Host o X-Forwarded-Host non validati.
        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(Context)
        If tenant Is Nothing Then
            Response.Clear()
            Response.StatusCode = 421
            Response.StatusDescription = "Misdirected Request"
            Response.TrySkipIisCustomErrors = True
            Response.SuppressContent = True
            Context.ApplicationInstance.CompleteRequest()
            Exit Sub
        End If

        Dim canonicalTarget As String = StorefrontCanonicalHostPolicy.BuildCanonicalRedirect(Request.Url, Request.IsLocal, tenant)
        If Not String.IsNullOrEmpty(canonicalTarget) Then
            Response.Clear()
            If String.Equals(Request.HttpMethod, "GET", StringComparison.OrdinalIgnoreCase) OrElse
               String.Equals(Request.HttpMethod, "HEAD", StringComparison.OrdinalIgnoreCase) Then
                Response.StatusCode = 301
                Response.StatusDescription = "Moved Permanently"
            Else
                Response.StatusCode = 307
                Response.StatusDescription = "Temporary Redirect"
            End If
            Response.RedirectLocation = canonicalTarget
            Response.Headers("Location") = canonicalTarget
            Response.SuppressContent = True
            Response.TrySkipIisCustomErrors = True
            Context.ApplicationInstance.CompleteRequest()
            Exit Sub
        End If

    Catch
        ' Non interrompere la request pipeline se qualcosa va storto.
    End Try
End Sub

Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
    Try
        If Context Is Nothing OrElse Request Is Nothing OrElse Response Is Nothing Then Exit Sub
        If Not String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then Exit Sub

        Dim ex As Exception = Server.GetLastError()
        If Not IsViewStateMacError(ex) Then Exit Sub

        Server.ClearError()
        Response.Clear()
        Response.StatusCode = 303
        Response.StatusDescription = "See Other"
        Response.RedirectLocation = Request.RawUrl
        Response.Headers("Location") = Request.RawUrl
        Response.SuppressContent = True
        Response.TrySkipIisCustomErrors = True
        Context.ApplicationInstance.CompleteRequest()
    Catch
    End Try
End Sub

Private Function IsViewStateMacError(ByVal ex As Exception) As Boolean
    Dim cur As Exception = ex
    While cur IsNot Nothing
        Dim typeName As String = cur.GetType().FullName
        Dim msg As String = If(cur.Message, String.Empty)

        If String.Equals(typeName, "System.Web.UI.ViewStateException", StringComparison.Ordinal) Then Return True
        If msg.IndexOf("viewstate", StringComparison.OrdinalIgnoreCase) >= 0 AndAlso msg.IndexOf("MAC", StringComparison.OrdinalIgnoreCase) >= 0 Then Return True
        If msg.IndexOf("Viewstate non valido", StringComparison.OrdinalIgnoreCase) >= 0 Then Return True

        cur = cur.InnerException
    End While

    Return False
End Function

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

        If Request IsNot Nothing Then
            Dim shouldNoIndex As Boolean = (Response.StatusCode >= 400) OrElse
                StorefrontCanonicalHostPolicy.IsNoIndexPath(Request.Url.AbsolutePath)
            If shouldNoIndex Then Response.Headers("X-Robots-Tag") = "noindex, nofollow"
        End If

    Catch
    End Try
End Sub

</script>
