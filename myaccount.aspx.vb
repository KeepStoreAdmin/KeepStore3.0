'--- INIZIO myaccount.aspx.vb (versione aggiornata) ---

Partial Class myaccount
    Inherits System.Web.UI.Page

    '========================================================
    ' PAGE_LOAD
    ' - Se l'utente NON è loggato, lo mando ad accessonegato.aspx
    '   salvando prima la pagina richiesta in Session("Page")
    '========================================================
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Me.Session("LoginId") Is Nothing Then
            Me.Session("Page") = Me.Request.Url.ToString()
            Me.Response.Redirect("accessonegato.aspx", True)
        End If
    End Sub

    '========================================================
    ' PAGE_PRERENDER
    ' - Completo il title della pagina in modo coerente
    '========================================================
    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - My Account"
    End Sub

End Class

'--- FINE myaccount.aspx.vb ---
