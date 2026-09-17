Imports System
Imports System.Web
Imports System.Web.UI

''' <summary>
''' Routes the public extension-based SEO endpoints through the ASP.NET pages that
''' build tenant-aware responses.  IIS otherwise treats .txt and .xml as static
''' resources and never reaches Global.asax on installations that use
''' managedHandler-only modules.
''' </summary>
Public NotInheritable Class StorefrontSeoEndpointHandler
    Implements IHttpHandler

    Public ReadOnly Property IsReusable As Boolean Implements IHttpHandler.IsReusable
        Get
            Return False
        End Get
    End Property

    Public Sub ProcessRequest(context As HttpContext) Implements IHttpHandler.ProcessRequest
        If context Is Nothing OrElse context.Request Is Nothing Then
            Throw New HttpException(400, "Richiesta non valida.")
        End If

        Dim requestedPath As String = Convert.ToString(context.Request.AppRelativeCurrentExecutionFilePath)
        Dim targetPath As String

        If requestedPath.EndsWith("robots.txt", StringComparison.OrdinalIgnoreCase) OrElse
           requestedPath.EndsWith("robots.aspx", StringComparison.OrdinalIgnoreCase) Then
            targetPath = "~/robots.aspx"
        ElseIf requestedPath.EndsWith("sitemap.xml", StringComparison.OrdinalIgnoreCase) OrElse
               requestedPath.EndsWith("sitemap.aspx", StringComparison.OrdinalIgnoreCase) Then
            targetPath = "~/sitemap.aspx"
        Else
            Throw New HttpException(404, "Risorsa non trovata.")
        End If

        context.RewritePath(targetPath)
        Dim pageHandler As IHttpHandler = PageParser.GetCompiledPageInstance(
            targetPath,
            context.Server.MapPath(targetPath),
            context)
        pageHandler.ProcessRequest(context)
    End Sub
End Class
