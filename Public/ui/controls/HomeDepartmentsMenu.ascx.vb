Imports System
Imports System.IO
Imports System.Web
Imports System.Web.UI

Partial Class UI_HomeDepartmentsMenu
    Inherits System.Web.UI.UserControl

    Private Const SettoriBaseVirtual As String = "~/Public/assets/images/settori/"
    Private Const SettoriFallbackVirtual As String = "~/Public/assets/images/item/camera-3.webp"

    Protected Function SafeText(value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return String.Empty
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Protected Function GetSettoreImageUrl(value As Object) As String
        Return GetSettoreImageLowUrl(value)
    End Function

    Protected Function GetSettoreImageLowUrl(value As Object) As String
        Dim fileName As String = CleanFileName(value)
        If String.IsNullOrWhiteSpace(fileName) Then Return ResolveUrl(SettoriFallbackVirtual)
        Dim lowFile As String = If(fileName.StartsWith("_", StringComparison.Ordinal), fileName, "_" & fileName)
        Return ResolveUrl(SettoriBaseVirtual & HttpUtility.UrlPathEncode(lowFile))
    End Function

    Protected Function GetSettoreImageNormalUrl(value As Object) As String
        Dim fileName As String = CleanFileName(value)
        If String.IsNullOrWhiteSpace(fileName) Then Return ResolveUrl(SettoriFallbackVirtual)
        Return ResolveUrl(SettoriBaseVirtual & HttpUtility.UrlPathEncode(fileName))
    End Function

    Private Function CleanFileName(value As Object) As String
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return String.Empty
        s = s.Trim().Replace("\", "/")
        Try
            s = Path.GetFileName(s)
        Catch
        End Try
        Return If(s, String.Empty).Trim()
    End Function
End Class
