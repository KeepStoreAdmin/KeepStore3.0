Imports System

Partial Class pay_your_orders
    Inherits System.Web.UI.Page

    Protected Overrides Sub OnLoad(ByVal e As EventArgs)
        ' Hardening: no-store / no-cache
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()
        Response.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
        Response.Cache.SetExpires(DateTime.UtcNow.AddMinutes(-1))
        Response.Cache.SetMaxAge(TimeSpan.Zero)
        Response.Cache.AppendCacheExtension("must-revalidate, proxy-revalidate")

        ' Hardening: noindex
        Response.AddHeader("X-Robots-Tag", "noindex, nofollow")

        ' Alias -> pagina corretta
        Response.Redirect("/documenti.aspx?t=4", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
