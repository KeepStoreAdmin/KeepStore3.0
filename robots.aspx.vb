Option Strict On
Option Explicit On

Imports System
Imports System.Text
Imports System.Web
Imports System.Web.UI

Public Class robots
    Inherits Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
        If tenant Is Nothing Then
            Response.Clear()
            Response.StatusCode = 404
            Response.TrySkipIisCustomErrors = True
            Response.SuppressContent = True
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        Dim body As String = StorefrontCanonicalHostPolicy.BuildRobotsText(tenant)
        Response.Clear()
        Response.StatusCode = 200
        Response.ContentType = "text/plain"
        Response.ContentEncoding = Encoding.UTF8
        Response.Cache.SetCacheability(HttpCacheability.Public)
        Response.Cache.SetMaxAge(TimeSpan.FromMinutes(10))
        Response.Cache.VaryByHeaders("Host") = True
        ' IIS suppresses the entity body for HEAD while retaining the same
        ' representation headers (including Content-Length) as GET.
        Response.Write(body)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
