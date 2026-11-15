<%@ Page Language="VB" AutoEventWireup="false" EnableViewState="false" %>
<script runat="server">
    ' KS-A04-SEARCH-COMPLETE-1A - la vecchia maschera "Ricerca Avanzata" non esiste piu: il catalogo ha gia tutti i suoi filtri
    ' (categoria, marca, tipologia, gruppo, sottogruppo, prezzo, disponibile, promozione, spedizione gratis, testo).
    ' Questa pagina resta soltanto come ingresso di compatibilita per segnalibri e vecchi collegamenti:
    '  - GET e HEAD: 301 permanente verso il catalogo;
    '  - ogni altro metodo (una vecchia scheda con il modulo ancora aperto): 303, il catalogo si apre in GET;
    '  - la destinazione e fissa, sullo stesso sito, e nessun valore della richiesta (query, modulo, referrer) viene letto o inoltrato.
    ' Nessuna master, nessun accesso ai dati, nessuna sessione: la pagina risponde senza caricare nulla della vetrina.
    Protected Overrides Sub OnPreInit(ByVal e As EventArgs)
        Dim target As String = ResolveUrl("~/articoli.aspx")
        If String.Equals(Request.HttpMethod, "GET", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(Request.HttpMethod, "HEAD", StringComparison.OrdinalIgnoreCase) Then
            Response.RedirectPermanent(target, True)
        Else
            Response.Clear()
            Response.StatusCode = 303
            Response.AddHeader("Location", target)
            Response.End()
        End If
    End Sub
</script>
