Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.UI

Partial Class CatalogCartAsync
    Inherits Page

    Private _statusCode As Integer = 500
    Private _success As Boolean
    Private _duplicate As Boolean
    Private _refreshRequired As Boolean
    Private _message As String = "Non è stato possibile aggiornare il carrello. Riprova."
    Private _requestedDelta As Decimal
    Private _articleId As Integer
    Private _tcId As Integer = -1
    Private _requestId As String = String.Empty

    Protected Overrides Sub OnPreInit(ByVal e As EventArgs)
        KeepStoreSecurity.AddSecurityHeaders(Response)
        KeepStoreSecurity.RequireHttps(Request, Response, enableHsts:=True)
        MyBase.OnPreInit(e)
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()
        Response.TrySkipIisCustomErrors = True

        If Not String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then
            Response.Headers("Allow") = "POST"
            Reject(405, "Metodo non consentito.")
            Return
        End If

        If Not IsCatalogSameOriginRequest() OrElse
           Not String.Equals(Request.Headers("X-Requested-With"), "XMLHttpRequest", StringComparison.OrdinalIgnoreCase) Then
            Reject(403, "Richiesta non autorizzata.")
            Return
        End If

        If Not CatalogAsyncCartSupport.ValidateCsrfToken(HttpContext.Current, Request.Form("csrfToken")) Then
            Reject(403, "Sessione non valida. Aggiorna la pagina e riprova.")
            Return
        End If

        Dim quantity As Decimal = 0D
        If Not TryReadParameters(_articleId, _tcId, quantity, _requestId) Then
            Reject(400, "Parametri carrello non validi.")
            Return
        End If
        _requestedDelta = quantity

        Dim payload As String = CartMutationIdempotencyService.BuildStandardPayload(_articleId, _tcId, quantity)
        Dim decision As CartMutationIntentDecision = CartMutationIdempotencyService.RegisterIntent(
            HttpContext.Current, _requestId, "cart-add", payload)
        If decision = CartMutationIntentDecision.Completed Then
            _duplicate = True
            _success = True
            _statusCode = 200
            _message = "Carrello già aggiornato."
            Return
        End If
        If decision = CartMutationIntentDecision.Collision Then
            Reject(409, "Identificativo richiesta non valido.")
            Return
        End If
        If decision = CartMutationIntentDecision.Invalid Then
            Reject(400, "Richiesta carrello non valida.")
            Return
        End If
        If decision = CartMutationIntentDecision.Indeterminate Then
            Reject(409, "Non è stato possibile confermare l'aggiornamento. Aggiorna il carrello e riprova.", True)
            Return
        End If
        If decision = CartMutationIntentDecision.Processing OrElse decision = CartMutationIntentDecision.CapacityExceeded Then
            Response.Headers("Retry-After") = "1"
            Reject(503, "Aggiornamento carrello in corso. Riprova tra poco.")
            Return
        End If

        Dim beginDecision As CartMutationIntentDecision = CartMutationIdempotencyService.BeginIntent(
            HttpContext.Current, _requestId, "cart-add", payload)
        If beginDecision = CartMutationIntentDecision.Completed Then
            _duplicate = True
            _success = True
            _statusCode = 200
            _message = "Carrello già aggiornato."
            Return
        End If
        If beginDecision = CartMutationIntentDecision.Indeterminate Then
            Reject(409, "Non è stato possibile confermare l'aggiornamento. Aggiorna il carrello e riprova.", True)
            Return
        End If
        If beginDecision <> CartMutationIntentDecision.Accepted Then
            If beginDecision = CartMutationIntentDecision.Processing Then Response.Headers("Retry-After") = "1"
            Reject(If(beginDecision = CartMutationIntentDecision.Collision, 409, 503), "Aggiornamento carrello non disponibile. Riprova.")
            Return
        End If

        Dim mutationCommitted As Boolean = False
        Try
            Dim cartReturnUrl As String = StorefrontReturnUrlPolicy.NormalizeShoppingReturnUrl(HttpContext.Current, Request.UrlReferrer.AbsoluteUri)
            Session("Carrello_Pagina") = If(cartReturnUrl <> String.Empty, cartReturnUrl, "/articoli.aspx")

            Dim result As CartStandardMutationResult = CartMutationService.AddStandardProductForCurrentOwner(
                HttpContext.Current, _articleId, _tcId, quantity)
            If result Is Nothing OrElse Not result.Succeeded Then
                CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, _requestId)
                Reject(422, "Il prodotto non è stato aggiunto. Verifica disponibilità e prezzo.")
                Return
            End If

            _articleId = result.ArticleId
            _tcId = result.TCId
            mutationCommitted = True
            CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, _requestId)
            _success = True
            _statusCode = 200
            _message = "Prodotto aggiunto al carrello."
        Catch ex As Exception
            If Not mutationCommitted Then CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, _requestId)
            Try
                KeepStoreLog.Error("catalog_cart_async.aspx", "Errore aggiornamento asincrono carrello ArticoloId=" & _articleId.ToString(CultureInfo.InvariantCulture) & " TCId=" & _tcId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
            Catch
            End Try
            Reject(500, "Non e' stato possibile aggiornare il carrello. Riprova.")
        End Try
    End Sub

    Protected Overrides Sub Render(ByVal writer As HtmlTextWriter)
        Dim payload As New Dictionary(Of String, Object) From {
            {"ok", _success},
            {"message", _message},
            {"requestId", _requestId},
            {"duplicate", _duplicate},
            {"refreshRequired", _refreshRequired}
        }

        Try
            If _success Then
                Dim snapshot As CartStateSnapshotProvider = CartStateSnapshotProvider.GetCurrent(HttpContext.Current)
                Dim items As New List(Of Dictionary(Of String, Object))()
                Dim totalQuantity As Decimal = 0D

                For Each item As CartStateSnapshotItem In snapshot.Items
                    If item Is Nothing OrElse item.ArticleId <= 0 OrElse item.Quantity <= 0D Then Continue For
                    items.Add(New Dictionary(Of String, Object) From {
                        {"id", item.ArticleId.ToString(CultureInfo.InvariantCulture)},
                        {"tcid", item.TCId.ToString(CultureInfo.InvariantCulture)},
                        {"qty", item.Quantity}
                    })
                    totalQuantity += item.Quantity
                Next

                Dim productQuantity As Decimal = If(_tcId > 0,
                                                    snapshot.GetQuantity(_articleId, _tcId),
                                                    snapshot.GetArticleQuantity(_articleId))
                If Not _duplicate AndAlso _requestedDelta < 0D AndAlso productQuantity > 0D Then
                    Dim itemLabel As String = If(productQuantity = 1D, " pezzo", " pezzi")
                    _message = "Quantità aggiornata: " & FormatQuantity(productQuantity) & itemLabel & " nel carrello."
                    payload("message") = _message
                End If
                Dim cartTotal As Decimal = 0D
                Decimal.TryParse(Convert.ToString(Session("Carrello_Totale_Merce")), NumberStyles.Any, CultureInfo.InvariantCulture, cartTotal)

                payload("product") = New Dictionary(Of String, Object) From {
                    {"id", _articleId.ToString(CultureInfo.InvariantCulture)},
                    {"tcid", _tcId.ToString(CultureInfo.InvariantCulture)},
                    {"qty", productQuantity}
                }
                payload("cart") = New Dictionary(Of String, Object) From {
                    {"count", totalQuantity},
                    {"total", cartTotal},
                    {"items", items}
                }
                payload("miniCartHtml") = RenderMiniCart()
            End If
        Catch ex As Exception
            Try
                KeepStoreLog.Error("catalog_cart_async.aspx", "Errore rendering risposta asincrona carrello", ex, HttpContext.Current)
            Catch
            End Try
            Reject(500, "Il carrello potrebbe essere stato aggiornato. Verificalo prima di riprovare.")
            payload.Clear()
            payload("ok") = False
            payload("message") = _message
            payload("requestId") = _requestId
            payload("duplicate") = _duplicate
            payload("refreshRequired") = _refreshRequired
        End Try

        Response.Clear()
        Response.StatusCode = _statusCode
        Response.ContentType = "application/json"
        Response.ContentEncoding = Encoding.UTF8
        Response.Charset = "utf-8"

        Dim serializer As New JavaScriptSerializer() With {.MaxJsonLength = 1048576}
        writer.Write(serializer.Serialize(payload))
    End Sub

    Public Overrides Sub VerifyRenderingInServerForm(ByVal control As Control)
        ' The MiniCart is rendered into the JSON response after its normal page lifecycle.
    End Sub

    Private Function TryReadParameters(ByRef articleId As Integer,
                                       ByRef tcId As Integer,
                                       ByRef quantity As Decimal,
                                       ByRef requestId As String) As Boolean
        If Not Integer.TryParse(Convert.ToString(Request.Form("id")), articleId) OrElse articleId <= 0 Then Return False

        tcId = -1
        Integer.TryParse(Convert.ToString(Request.Form("tcid")), tcId)
        tcId = CatalogAsyncCartSupport.NormalizeTCId(tcId)

        Dim quantityRaw As String = Convert.ToString(Request.Form("qty"))
        If Not Decimal.TryParse(quantityRaw, NumberStyles.Any, CultureInfo.InvariantCulture, quantity) Then Return False
        If quantity = 0D OrElse quantity < -9999D OrElse quantity > 9999D OrElse Decimal.Truncate(quantity) <> quantity Then Return False

        Dim requestGuid As Guid
        requestId = If(Convert.ToString(Request.Form("requestId")), String.Empty).Trim()
        If Not Guid.TryParse(requestId, requestGuid) Then Return False
        requestId = requestGuid.ToString("N")
        Return True
    End Function

    Private Function IsCatalogSameOriginRequest() As Boolean
        Dim requestUri As Uri = Request.Url
        Dim referrerUri As Uri = Request.UrlReferrer
        If requestUri Is Nothing OrElse referrerUri Is Nothing OrElse Not referrerUri.IsAbsoluteUri Then Return False
        If Not SameOrigin(requestUri, referrerUri) Then Return False

        Dim referrerPath As String = If(referrerUri.AbsolutePath, String.Empty)
        Dim referrerFile As String = If(VirtualPathUtility.GetFileName(referrerPath), String.Empty)
        Dim isStorefrontCartCaller As Boolean =
            String.IsNullOrEmpty(referrerFile) OrElse
            String.Equals(referrerFile, "Default.aspx", StringComparison.OrdinalIgnoreCase) OrElse
            String.Equals(referrerFile, "articoli.aspx", StringComparison.OrdinalIgnoreCase) OrElse
            String.Equals(referrerFile, "articolo.aspx", StringComparison.OrdinalIgnoreCase) OrElse
            String.Equals(referrerPath, ResolveUrl("~/compare.aspx"), StringComparison.OrdinalIgnoreCase)
        If Not isStorefrontCartCaller Then Return False

        Dim fetchSite As String = If(Request.Headers("Sec-Fetch-Site"), String.Empty).Trim()
        If fetchSite <> "" AndAlso Not String.Equals(fetchSite, "same-origin", StringComparison.OrdinalIgnoreCase) Then Return False

        Dim originHeader As String = If(Request.Headers("Origin"), String.Empty).Trim()
        If originHeader = "" Then Return True

        Dim origin As Uri = Nothing
        Return Uri.TryCreate(originHeader, UriKind.Absolute, origin) AndAlso SameOrigin(requestUri, origin)
    End Function

    Private Function SameOrigin(ByVal first As Uri, ByVal second As Uri) As Boolean
        Return first IsNot Nothing AndAlso second IsNot Nothing AndAlso
               String.Equals(first.Scheme, second.Scheme, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(first.Host, second.Host, StringComparison.OrdinalIgnoreCase) AndAlso
               first.Port = second.Port
    End Function

    Private Function RenderMiniCart() As String
        Dim miniCart As Control = FindControlRecursive(Master, "MiniCart1")
        If miniCart Is Nothing Then Return String.Empty

        Dim output As New StringBuilder()
        Using stringWriter As New StringWriter(output, CultureInfo.InvariantCulture)
            Using htmlWriter As New HtmlTextWriter(stringWriter)
                miniCart.RenderControl(htmlWriter)
            End Using
        End Using
        Return output.ToString()
    End Function

    Private Function FindControlRecursive(ByVal root As Control, ByVal controlId As String) As Control
        If root Is Nothing Then Return Nothing
        Dim direct As Control = root.FindControl(controlId)
        If direct IsNot Nothing Then Return direct
        For Each child As Control In root.Controls
            Dim found As Control = FindControlRecursive(child, controlId)
            If found IsNot Nothing Then Return found
        Next
        Return Nothing
    End Function

    Private Sub Reject(ByVal statusCode As Integer, ByVal message As String, Optional ByVal refreshRequired As Boolean = False)
        _success = False
        _statusCode = statusCode
        _message = message
        _refreshRequired = refreshRequired
    End Sub

    Private Function FormatQuantity(ByVal quantity As Decimal) As String
        Dim culture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
        If Decimal.Truncate(quantity) = quantity Then Return quantity.ToString("0", culture)
        Return quantity.ToString("0.##", culture)
    End Function

End Class
