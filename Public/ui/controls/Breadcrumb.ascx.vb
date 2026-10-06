Imports System
Imports System.Collections.Generic
Imports System.Text
Imports System.Web

Partial Class Breadcrumb
    Inherits System.Web.UI.UserControl

    Public Property AdditionalCssClass As String

    Public Sub Bind(items As IList(Of StorefrontBreadcrumbItem))
        phBreadcrumb.Visible = False
        litCrumbs.Text = String.Empty
        If items Is Nothing OrElse items.Count = 0 Then Return
        Dim html As New StringBuilder()
        For index As Integer = 0 To items.Count - 1
            Dim item As StorefrontBreadcrumbItem = items(index)
            If item Is Nothing OrElse String.IsNullOrWhiteSpace(item.Name) Then Return
            If index > 0 Then html.Append("<li class=""d-flex align-items-center"" aria-hidden=""true""><i class=""icon icon-arrow-right""></i></li>")
            Dim name As String = HttpUtility.HtmlEncode(StorefrontBreadcrumbItem.NormalizeName(item.Name))
            If index = items.Count - 1 Then
                html.Append("<li aria-current=""page""><span class=""body-small"">").Append(name).Append("</span></li>")
            Else
                Dim localUrl As String = If(item.Url, String.Empty)
                If Not (localUrl.StartsWith("~/", StringComparison.Ordinal) OrElse localUrl.StartsWith("/", StringComparison.Ordinal)) OrElse
                   localUrl.StartsWith("//", StringComparison.Ordinal) OrElse localUrl.Contains("\") OrElse
                   localUrl.Contains(":") OrElse localUrl.IndexOfAny(New Char() {ChrW(10), ChrW(13)}) >= 0 Then Return
                html.Append("<li><a class=""body-small link"" href=""").Append(HttpUtility.HtmlAttributeEncode(ResolveUrl(localUrl))).Append(""">").Append(name).Append("</a></li>")
            End If
        Next
        litCrumbs.Text = html.ToString()
        phBreadcrumb.Visible = True
    End Sub
End Class
