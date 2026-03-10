Imports System
Imports System.Web
Imports System.Web.UI

Partial Class UI_HomeDepartmentsMenu
    Inherits System.Web.UI.UserControl

    Protected Function SafeText(value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return String.Empty
        Return HttpUtility.HtmlEncode(Convert.ToString(value))
    End Function
End Class
