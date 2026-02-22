Imports System.Net
Imports System.IO
Imports System.Security.Authentication

	Partial Class test
		Inherits System.Web.UI.Page
		
		Const _Tls12 As SslProtocols = DirectCast(&HC00, SslProtocols)
		Const Tls12 As SecurityProtocolType = DirectCast(_Tls12, SecurityProtocolType)
		
'		Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
'			ServicePointManager.SecurityProtocol = Tls12
'			Dim inStream As StreamReader
'			Dim webRequest As WebRequest
'			Dim webresponse As WebResponse
'			webRequest = webRequest.Create("https://tlstest.paypal.com")
'			webresponse = webRequest.GetResponse()
'			inStream = New StreamReader(webresponse.GetResponseStream())
'			Dim Output As String = inStream.ReadToEnd()
'			Response.Write(Output)
'			Response.End()
'		End Sub

		Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
			ServicePointManager.SecurityProtocol = Tls12
			Dim inStream As StreamReader
			Dim webRequest As WebRequest
			Dim webresponse As WebResponse
			webRequest = webRequest.Create("https://www.taikun.it/amazon.aspx?action=import_orders")
			webresponse = webRequest.GetResponse()
			inStream = New StreamReader(webresponse.GetResponseStream())
			Dim Output As String = inStream.ReadToEnd()
			Response.Write(Output)
			Response.End()
		End Sub
	End Class