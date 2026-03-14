Imports System
Imports System.IO
Imports System.Web
Imports System.Web.UI

Partial Class UI_HomeDepartmentsMenu
    Inherits System.Web.UI.UserControl

    Protected Function SafeText(value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return String.Empty
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function

    Protected Function GetSettoreImageUrl(value As Object) As String
        Dim fileName As String = CleanFileName(value)
        Dim fallback As String = ResolveUrl("~/Public/assets/images/item/camera-3.webp")
        If String.IsNullOrWhiteSpace(fileName) Then Return fallback

        Dim lowFile As String = If(fileName.StartsWith("_", StringComparison.Ordinal), fileName, "_" & fileName)
        Dim lowVirtual As String = "~/Public/assets/images/settori/" & HttpUtility.UrlPathEncode(lowFile)
        Dim lowPhysical As String = SafeMapPath(lowVirtual)
        If Not String.IsNullOrWhiteSpace(lowPhysical) AndAlso File.Exists(lowPhysical) Then
            Return ResolveUrl(lowVirtual)
        End If

        Dim originalVirtual As String = "~/Public/assets/images/settori/" & HttpUtility.UrlPathEncode(fileName)
        Dim originalPhysical As String = SafeMapPath(originalVirtual)
        If Not String.IsNullOrWhiteSpace(originalPhysical) AndAlso File.Exists(originalPhysical) Then
            Return ResolveUrl(originalVirtual)
        End If

        Return fallback
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

    Private Function SafeMapPath(virtualPath As String) As String
        Try
            Return Server.MapPath(virtualPath)
        Catch
            Return String.Empty
        End Try
    End Function
End Class
