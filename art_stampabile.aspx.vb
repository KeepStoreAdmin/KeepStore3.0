Partial Class art_stampabile
    Inherits System.Web.UI.Page

    ' ============================================================
    ' HOTFIX COMPILAZIONE + SICUREZZA (KEEPSTORE3)
    ' ------------------------------------------------------------
    ' La pagina "art_stampabile.aspx.vb" generava errore BC30451
    ' (ArticoliId non dichiarato) e bloccava la compilazione del sito.
    '
    ' Strategia: questa pagina diventa un alias/redirect verso
    ' "vers_stampabile.aspx" (che è già la scheda stampabile canonica).
    ' In questo modo:
    ' - si sblocca la compilazione,
    ' - si preserva la funzionalità (stampa prodotto),
    ' - si evita di mantenere duplicazioni di logica.
    ' ============================================================

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim qs As String = ""
        Try
            qs = Request.Url.Query
        Catch
            qs = ""
        End Try

        Response.Redirect("~/vers_stampabile.aspx" & qs, True)
    End Sub

End Class
