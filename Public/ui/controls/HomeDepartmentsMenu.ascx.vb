Imports System
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls

Partial Public Class UI_HomeDepartmentsMenu
    Inherits UserControl

    Protected Function SafeText(ByVal value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Protected Function BuildSettoreUrl(ByVal settoreId As Object) As String
        Return "articoli.aspx?st=" & Convert.ToString(settoreId)
    End Function

    Protected Function GetSettoreImageLowUrl(ByVal value As Object) As String
        Dim fileName As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return ResolveUrl("~/Public/assets/images/banner/banner-2.jpg")
        End If
        fileName = fileName.Replace("\", "/")
        fileName = System.IO.Path.GetFileName(fileName)
        Return ResolveUrl("~/Public/assets/images/articoli/_" & fileName)
    End Function

    Protected Function GetSettoreImageNormalUrl(ByVal value As Object) As String
        Dim fileName As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return ResolveUrl("~/Public/assets/images/banner/banner-2.jpg")
        End If
        fileName = fileName.Replace("\", "/")
        fileName = System.IO.Path.GetFileName(fileName)
        Return ResolveUrl("~/Public/assets/images/articoli/" & fileName)
    End Function
End Class
