' EXPORT-FEED-ENGINE-1A. Indirizzo pubblico dei feed: https://<dominio>/feed.aspx?c=<codice>. Nessun comparatore e nessun feed sono scritti qui: tutto sta in
' App_Code\KeepStoreFeedService.vb. Si sovrascrive ProcessRequest e NON si chiama MyBase: cosi non parte il ciclo della pagina (ViewState, validazione, eventi,
' sessione) e la risposta e solo il file pronto o un breve testo di stato. Il codice del link e validato dal servizio (48 caratteri esadecimali).
Partial Class feed
    Inherits System.Web.UI.Page

    Public Overrides Sub ProcessRequest(ByVal context As System.Web.HttpContext)
        Try
            KeepStoreFeedService.Serve(context)
        Catch
            Try
                Dim r As System.Web.HttpResponse = context.Response
                r.Clear()
                r.StatusCode = 503
                r.TrySkipIisCustomErrors = True
                r.Cache.SetCacheability(System.Web.HttpCacheability.NoCache)
                r.Cache.SetNoStore()
                r.AppendHeader("Retry-After", "30")
                r.ContentType = "text/plain"
                r.Charset = "utf-8"
                r.Write("Servizio non disponibile")
            Catch
            End Try
        End Try
    End Sub
End Class
