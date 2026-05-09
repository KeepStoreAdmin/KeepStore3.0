Imports System
Imports System.Globalization
Imports System.Web

Partial Class Public_ui_controls_ProductDetailView
    Inherits System.Web.UI.UserControl

    Public Property ProductName As String
    Public Property ProductCode As String
    Public Property PriceHtml As String
    Public Property AvailabilityHtml As String
    Public Property TCId As Integer
    Public Property ShortDescriptionHtml As String

    Protected Overrides Sub OnPreRender(ByVal e As EventArgs)
        MyBase.OnPreRender(e)

        litProductName.Text = HttpUtility.HtmlEncode(If(ProductName, String.Empty))
        litProductCode.Text = HttpUtility.HtmlEncode(If(ProductCode, String.Empty))
        litPrice.Text = If(PriceHtml, String.Empty)
        litAvailability.Text = If(AvailabilityHtml, String.Empty)
        litTCId.Text = HttpUtility.HtmlEncode(TCId.ToString(CultureInfo.InvariantCulture))
        litShortDescription.Text = If(ShortDescriptionHtml, String.Empty)
    End Sub
End Class
