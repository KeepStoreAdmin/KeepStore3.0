<%@ WebHandler Language="VB" Class="codebar" %>

Imports System
Imports System.Web
Imports iTextSharp.text
Imports iTextSharp.text.pdf

Public Class codebar : Implements IHttpHandler
    
    Public Sub ProcessRequest(ByVal context As HttpContext) Implements IHttpHandler.ProcessRequest
        Dim Request = context.Request
        Dim barcode As String = Request.QueryString("barcode")
        If barcode Is Nothing Then
            barcode = "39"
        End If
        Dim bc39 As New Barcode39()
        bc39.Code = barcode
        Dim bc As System.Drawing.Image = bc39.CreateDrawingImage( _
          System.Drawing.Color.Black, System.Drawing.Color.White _
        )
        bc.Save(context.Response.OutputStream, System.Drawing.Imaging.ImageFormat.Gif)
    End Sub
 
    Public ReadOnly Property IsReusable() As Boolean Implements IHttpHandler.IsReusable
        Get
            Return False
        End Get
    End Property

End Class