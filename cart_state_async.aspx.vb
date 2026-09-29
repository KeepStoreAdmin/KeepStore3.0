Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.UI

Partial Class CartStateAsync
    Inherits Page

    Private _statusCode As Integer = 500
    Private _miniCart As Control
    Private _snapshot As CartStateSnapshotProvider
    Private _cart As CartAuthoritativeReadModel

    Protected Overrides Sub OnPreInit(ByVal e As EventArgs)
        KeepStoreSecurity.AddSecurityHeaders(Response)
        KeepStoreSecurity.RequireHttps(Request, Response, enableHsts:=True)
        MyBase.OnPreInit(e)
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()
        Response.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
        Response.Cache.SetExpires(DateTime.UtcNow.AddMinutes(-1))
        Response.Headers("X-Content-Type-Options") = "nosniff"
        Response.TrySkipIisCustomErrors = True

        If Not String.Equals(Request.HttpMethod, "GET", StringComparison.OrdinalIgnoreCase) Then
            Response.Headers("Allow") = "GET"
            _statusCode = 405
            Return
        End If

        ' Client-selected owner or commercial parameters are never part of this contract.
        If Request.QueryString.Count <> 0 Then
            _statusCode = 400
            Return
        End If

        Dim fetchSite As String = Convert.ToString(Request.Headers("Sec-Fetch-Site"))
        If String.Equals(fetchSite, "cross-site", StringComparison.OrdinalIgnoreCase) OrElse
           String.Equals(fetchSite, "same-site", StringComparison.OrdinalIgnoreCase) Then
            _statusCode = 403
            Return
        End If

        _cart = CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)
        If Not _cart.HasOwner Then
            _statusCode = 403
            Return
        End If
        If Not _cart.LoadSucceeded Then
            _statusCode = 503
            Return
        End If

        _snapshot = CartStateSnapshotProvider.GetCurrent(HttpContext.Current)
        Try
            _miniCart = LoadControl("~/Public/ui/controls/MiniCart.ascx")
        Catch
            _statusCode = 503
            Return
        End Try
        If Not ConfigureStatelessMiniCart(_miniCart) Then
            _statusCode = 503
            Return
        End If
        _miniCart.ID = "MiniCartReadOnly"
        Controls.Add(_miniCart)
        _statusCode = 200
    End Sub

    Private Shared Function ConfigureStatelessMiniCart(ByVal control As Control) As Boolean
        If control Is Nothing Then Return False
        Try
            Dim setting As System.Reflection.PropertyInfo = control.GetType().GetProperty(
                "StatelessActionRequestIds",
                System.Reflection.BindingFlags.Public Or System.Reflection.BindingFlags.Instance)
            If setting Is Nothing OrElse Not setting.CanWrite OrElse setting.PropertyType IsNot GetType(Boolean) Then Return False
            setting.SetValue(control, True, Nothing)
            Return True
        Catch
            Return False
        End Try
    End Function

    Protected Overrides Sub Render(ByVal writer As HtmlTextWriter)
        Dim payload As New Dictionary(Of String, Object) From {{"ok", False}}
        If _statusCode = 200 Then
            Try
                If _cart Is Nothing OrElse Not _cart.HasOwner OrElse Not _cart.LoadSucceeded OrElse
                   _snapshot Is Nothing OrElse _miniCart Is Nothing Then Throw New InvalidOperationException("Cart state unavailable")

                Dim items As New List(Of Dictionary(Of String, Object))()
                For Each item As CartStateSnapshotItem In _snapshot.Items
                    If item Is Nothing OrElse item.ArticleId <= 0 OrElse item.Quantity <= 0D Then Continue For
                    items.Add(New Dictionary(Of String, Object) From {
                        {"id", item.ArticleId.ToString(CultureInfo.InvariantCulture)},
                        {"tcid", item.TCId.ToString(CultureInfo.InvariantCulture)},
                        {"qty", item.Quantity}
                    })
                Next

                Dim html As New StringBuilder()
                Using stringWriter As New StringWriter(html, CultureInfo.InvariantCulture)
                    Using htmlWriter As New HtmlTextWriter(stringWriter)
                        _miniCart.RenderControl(htmlWriter)
                    End Using
                End Using
                If html.Length = 0 Then Throw New InvalidOperationException("MiniCart unavailable")

                payload("ok") = True
                payload("cart") = New Dictionary(Of String, Object) From {
                    {"count", Decimal.Truncate(_cart.TotalQuantity)},
                    {"items", items}
                }
                payload("miniCartHtml") = html.ToString()
            Catch ex As Exception
                _statusCode = 503
                payload.Clear()
                payload("ok") = False
                Try
                    KeepStoreLog.Error("cart_state_async.aspx", "Cart state rendering failed: " & ex.GetType().Name, Nothing, HttpContext.Current)
                Catch
                End Try
            End Try
        End If

        Response.ClearContent()
        Response.StatusCode = _statusCode
        Response.ContentType = "application/json"
        Response.ContentEncoding = Encoding.UTF8
        Response.Charset = "utf-8"
        Dim serializer As New JavaScriptSerializer() With {.MaxJsonLength = 1048576}
        writer.Write(serializer.Serialize(payload))
    End Sub

    Public Overrides Sub VerifyRenderingInServerForm(ByVal control As Control)
        ' The MiniCart fragment is rendered as JSON, not inside a WebForms server form.
    End Sub
End Class
