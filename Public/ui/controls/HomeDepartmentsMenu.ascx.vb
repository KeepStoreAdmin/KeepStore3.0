Imports System
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls

Partial Public Class UI_HomeDepartmentsMenu
    Inherits UserControl

    ''' <summary>
    ''' Encodes a value for safe HTML output.
    ''' </summary>
    ''' <param name="value">The value to encode.</param>
    ''' <returns>A HTML-encoded string.</returns>
    Protected Function SafeText(ByVal value As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    ''' <summary>
    ''' Builds a URL to the articles page for a given sector (settore).
    ''' </summary>
    ''' <param name="settoreId">The sector ID.</param>
    ''' <returns>A URL string.</returns>
    Protected Function BuildSettoreUrl(ByVal settoreId As Object) As String
        Return "articoli.aspx?st=" & Convert.ToString(settoreId)
    End Function

    ''' <summary>
    ''' Returns the low-resolution image URL for a sector.  If no image is provided,
    ''' a default banner is used.  This version prepends an underscore to the
    ''' filename to indicate the smaller size.
    ''' </summary>
    Protected Function GetSettoreImageLowUrl(ByVal value As Object) As String
        Dim fileName As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return ResolveUrl("~/Public/assets/images/banner/banner-2.jpg")
        End If
        fileName = fileName.Replace("\", "/")
        fileName = System.IO.Path.GetFileName(fileName)
        Return ResolveUrl("~/Public/assets/images/articoli/_" & fileName)
    End Function

    ''' <summary>
    ''' Returns the normal (high-resolution) image URL for a sector.  If no image is
    ''' provided, a default banner is used.
    ''' </summary>
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