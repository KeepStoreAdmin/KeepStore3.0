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
    Private _message As String = "Non e' stato possibile aggiornare il carrello. Riprova."
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
        Dim freeProduct As Integer = 0
        If Not TryReadParameters(_articleId, _tcId, quantity, freeProduct, _requestId) Then
            Reject(400, "Parametri carrello non validi.")
            Return
        End If

        Dim fingerprint As String = CatalogAsyncCartSupport.BuildFingerprint(_articleId, _tcId, quantity, freeProduct)
        Dim processedFingerprint As String = String.Empty
        If CatalogAsyncCartSupport.TryGetProcessedFingerprint(Session, _requestId, processedFingerprint) Then
            If Not String.Equals(processedFingerprint, fingerprint, StringComparison.Ordinal) Then
                Reject(409, "Identificativo richiesta non valido.")
                Return
            End If

            _duplicate = True
            _success = True
            _statusCode = 200
            _message = "Carrello gia' aggiornato."
            Return
        End If

        Try
            Session("Carrello_ArticoloId") = _articleId.ToString(CultureInfo.InvariantCulture)
            Session("Carrello_TCId") = _tcId.ToString(CultureInfo.InvariantCulture)
            Session("Carrello_Quantita") = quantity.ToString(CultureInfo.InvariantCulture)
            Session("ProdottoGratis") = freeProduct.ToString(CultureInfo.InvariantCulture)
            Dim cartReturnUrl As String = StorefrontReturnUrlPolicy.NormalizeShoppingReturnUrl(HttpContext.Current, Request.UrlReferrer.AbsoluteUri)
            Session("Carrello_Pagina") = If(cartReturnUrl <> String.Empty, cartReturnUrl, "/articoli.aspx")
            Session("Carrello_SelezioneMultipla") = Nothing

            CatalogAsyncCartSupport.BeginExecution(HttpContext.Current, _articleId, _tcId)
            Dim discardedOutput As New StringBuilder()
            Using capture As New StringWriter(discardedOutput, CultureInfo.InvariantCulture)
                Dim executionUrl As String = "aggiungi.aspx?id=" & _articleId.ToString(CultureInfo.InvariantCulture) &
                                             "&TCid=" & _tcId.ToString(CultureInfo.InvariantCulture) &
                                             "&qty=" & quantity.ToString(CultureInfo.InvariantCulture)
                If freeProduct <> 0 Then executionUrl &= "&pg=" & freeProduct.ToString(CultureInfo.InvariantCulture)
                Server.Execute(executionUrl, capture, False)
            End Using

            Dim execution As CatalogAsyncCartExecutionResult = CatalogAsyncCartSupport.GetExecutionResult(HttpContext.Current)
            If execution Is Nothing OrElse Not execution.IsComplete OrElse Not execution.Success Then
                Reject(422, "Il prodotto non e' stato aggiunto. Verifica disponibilita' e prezzo.")
                Return
            End If

            _articleId = execution.ArticleId
            _tcId = execution.TCId
            CatalogAsyncCartSupport.MarkProcessed(Session, _requestId, fingerprint)
            _success = True
            _statusCode = 200
            _message = "Prodotto aggiunto al carrello."
        Catch ex As Exception
            Try
                KeepStoreLog.Error("catalog_cart_async.aspx", "Errore aggiornamento asincrono carrello ArticoloId=" & _articleId.ToString(CultureInfo.InvariantCulture) & " TCId=" & _tcId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
            Catch
            End Try
            Reject(500, "Non e' stato possibile aggiornare il carrello. Riprova.")
        Finally
            CatalogAsyncCartSupport.EndExecution(HttpContext.Current)
            ClearTemporaryCartSession()
        End Try
    End Sub

    Protected Overrides Sub Render(ByVal writer As HtmlTextWriter)
        Dim payload As New Dictionary(Of String, Object) From {
            {"ok", _success},
            {"message", _message},
            {"requestId", _requestId},
            {"duplicate", _duplicate}
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
                                       ByRef freeProduct As Integer,
                                       ByRef requestId As String) As Boolean
        If Not Integer.TryParse(Convert.ToString(Request.Form("id")), articleId) OrElse articleId <= 0 Then Return False

        tcId = -1
        Integer.TryParse(Convert.ToString(Request.Form("tcid")), tcId)
        tcId = CatalogAsyncCartSupport.NormalizeTCId(tcId)

        Dim quantityRaw As String = Convert.ToString(Request.Form("qty"))
        If Not Decimal.TryParse(quantityRaw, NumberStyles.Any, CultureInfo.InvariantCulture, quantity) Then Return False
        If quantity <= 0D OrElse quantity > 9999D OrElse Decimal.Truncate(quantity) <> quantity Then Return False

        freeProduct = 0
        If Not String.IsNullOrWhiteSpace(Request.Form("pg")) AndAlso
           (Not Integer.TryParse(Request.Form("pg"), freeProduct) OrElse (freeProduct <> 0 AndAlso freeProduct <> 1)) Then
            Return False
        End If

        Dim requestGuid As Guid
        requestId = Convert.ToString(Request.Form("requestId")).Trim()
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
        If Not String.Equals(referrerFile, "articoli.aspx", StringComparison.OrdinalIgnoreCase) Then Return False

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

    Private Sub Reject(ByVal statusCode As Integer, ByVal message As String)
        _success = False
        _statusCode = statusCode
        _message = message
    End Sub

    Private Sub ClearTemporaryCartSession()
        Session("Carrello_ArticoloId") = Nothing
        Session("Carrello_ListaArticoloId") = Nothing
        Session("Carrello_Quantita") = Nothing
        Session("Carrello_SelezioneMultipla") = Nothing
        Session("ProdottoGratis") = Nothing
    End Sub
End Class
