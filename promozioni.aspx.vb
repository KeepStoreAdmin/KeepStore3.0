Imports System
Imports System.Web

Partial Class promozioni
    Inherits Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim destination As String = LegacyPromotionRoutePolicy.BuildModernPath(
            Request.QueryString,
            Request.ApplicationPath)

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
