' EXPORT-AMAZON-CLOSE-1A. Pagina chiusa (decisione del PO 2026-11-25): il vecchio scambio con Amazon non e piu in servizio.
' Risponde SEMPRE 410 con un testo fisso, per qualunque metodo e parametro: nessun accesso al database, nessuna lettura della
' configurazione ne della richiesta, nessuna eco. Si sovrascrive ProcessRequest e NON si chiama MyBase: cosi non parte il ciclo
' della pagina (ViewState, validazione della richiesta, eventi). Non aggiungere codice qui: Tools\Test-ExportAmazonClosed.ps1
' fissa l'elenco chiuso delle righe. Un eventuale nuovo scambio con Amazon va progettato da zero, con autenticazione.
Partial Class export_amazon
    Inherits System.Web.UI.Page

    Public Overrides Sub ProcessRequest(ByVal context As System.Web.HttpContext)
        Dim r As System.Web.HttpResponse = context.Response
        r.Clear()
        r.StatusCode = 410
        r.StatusDescription = "Gone"
        r.TrySkipIisCustomErrors = True
        r.Cache.SetCacheability(System.Web.HttpCacheability.NoCache)
        r.Cache.SetNoStore()
        r.ContentType = "text/plain"
        r.Charset = "utf-8"
        r.Write("Servizio non disponibile")
    End Sub
End Class
