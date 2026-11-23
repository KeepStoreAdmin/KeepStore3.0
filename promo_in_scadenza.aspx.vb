Imports System
Imports System.Web

' Ponte di compatibilita (LEGACY-PROMO-PAGES-RETIRE-1A): la vecchia pagina non mostra piu nulla e rimanda alla vetrina delle offerte del catalogo.
' Il rinvio avviene in PreInit, prima di vista di stato, master e controlli: nessun accesso a database o sessione, nessun cookie.
Partial Class promo_in_scadenza
    Inherits Page

    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As EventArgs) Handles Me.PreInit
        Me.EnableViewState = False
        Dim destination As String = LegacyPromotionRoutePolicy.BuildModernPath(Nothing, Request.ApplicationPath)
        ' La vecchia pagina "in scadenza" filtrava per categoria (ct) e per finestra di scadenza: nessuna delle due e riproducibile
        ' in modo equivalente nel catalogo, quindi qualsiasi query string porta alla destinazione non valida (fail chiuso).
        If Request.QueryString.Count > 0 Then destination = destination & "&pid=invalid"

        Dim method As String = Convert.ToString(Request.HttpMethod)
        Dim permanentNavigation As Boolean =
            String.Equals(method, "GET", StringComparison.OrdinalIgnoreCase) OrElse
            String.Equals(method, "HEAD", StringComparison.OrdinalIgnoreCase)

        Response.Clear()
        Response.StatusCode = If(permanentNavigation, 301, 303)
        Response.RedirectLocation = destination
        Response.TrySkipIisCustomErrors = True
        Response.SuppressContent = True
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
