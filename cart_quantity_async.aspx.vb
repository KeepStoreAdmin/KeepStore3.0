Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.UI

Partial Class CartQuantityAsync
    Inherits Page

    Private Const OperationType As String = "cart-set-row"
    Private Shared ReadOnly MoneyCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Private _statusCode As Integer = 500
    Private _errorCode As String = "technical_unavailable"
    Private _message As String = "Non è stato possibile verificare il carrello. Aggiorna la pagina e riprova."
    Private _success As Boolean
    Private _duplicate As Boolean
    Private _reconcile As Boolean
    Private _commercialChanges As Boolean
    Private _requestId As String = String.Empty
    Private _requestedQuantity As Integer
    Private _cart As CartAuthoritativeReadModel
    Private _snapshot As CartStateSnapshotProvider
    Private _miniCart As Control

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

        Try
        If Not String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then
            Response.Headers("Allow") = "POST"
            Reject(405, "method_not_allowed", "Metodo non consentito.")
            Return
        End If
        If Request.QueryString.Count <> 0 Then
            Reject(400, "bad_request", "Richiesta carrello non valida.")
            Return
        End If
        If Not IsCartSameOriginRequest() OrElse
           Not String.Equals(Request.Headers("X-Requested-With"), "XMLHttpRequest", StringComparison.OrdinalIgnoreCase) Then
            Reject(403, "forbidden", "Richiesta non autorizzata.")
            Return
        End If
        If Not CatalogAsyncCartSupport.ValidateCsrfToken(HttpContext.Current, Request.Form("csrfToken")) Then
            Reject(403, "csrf_invalid", "Sessione non valida. Aggiorna la pagina e riprova.")
            Return
        End If
        If Not HasOnlyExpectedFormFields() Then
            Reject(400, "bad_request", "Richiesta carrello non valida.")
            Return
        End If

        Dim rowId As Integer
        If Not Integer.TryParse(Request.Form("rowId"), NumberStyles.None, CultureInfo.InvariantCulture, rowId) OrElse rowId <= 0 Then
            Reject(400, "bad_request", "Riga carrello non valida.")
            Return
        End If
        If Not Integer.TryParse(Request.Form("quantity"), NumberStyles.None, CultureInfo.InvariantCulture, _requestedQuantity) OrElse
           _requestedQuantity < 1 OrElse _requestedQuantity > 9999 Then
            Reject(422, "invalid_quantity", "Inserisci una quantità intera da 1 a 9999. Per rimuovere l'articolo usa Rimuovi.")
            Return
        End If
        If Not CartMutationIdempotencyService.NormalizeRequestId(Request.Form("requestId"), _requestId) Then
            Reject(400, "bad_request", "Identificativo richiesta non valido.")
            Return
        End If

        Dim owner As CartStorefrontOwnerScope = CartStorefrontOwnerContext.ResolveForMutation(HttpContext.Current)
        If owner Is Nothing Then
            Reject(403, "session_invalid", "Sessione carrello non valida. Aggiorna la pagina e riprova.")
            Return
        End If

        Dim payload As String = CartMutationIdempotencyService.BuildSetRowQuantityPayload(rowId, CDec(_requestedQuantity))
        Dim decision As CartMutationIntentDecision = CartMutationIdempotencyService.RegisterIntent(
            HttpContext.Current, _requestId, OperationType, payload)
        If HandleIntentDecision(decision) Then Return

        ' This check is owner-scoped, but the mutation transaction remains the final authority.
        Dim beforeCart As CartAuthoritativeReadModel = CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)
        If Not beforeCart.HasOwner OrElse Not beforeCart.LoadSucceeded Then
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, _requestId)
            Reject(503, "technical_unavailable", "Il carrello non è disponibile. Aggiorna la pagina e riprova.")
            Return
        End If
        If Not ContainsRow(beforeCart.GetAllItems(), rowId) Then
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, _requestId)
            Reject(404, "cart_row_unavailable", "La riga del carrello non è disponibile. Aggiorna la pagina e riprova.")
            Return
        End If

        decision = CartMutationIdempotencyService.BeginIntent(HttpContext.Current, _requestId, OperationType, payload)
        If HandleIntentDecision(decision) Then Return

        Dim mutationCommitted As Boolean = False
        Try
            Dim changes As CartPriceRevalidationResult = CartMutationService.UpdateStandardQuantities(
                HttpContext.Current, owner.LoginId, owner.SessionId, owner.Listino,
                New List(Of CartQuantityMutationRequest) From {
                    New CartQuantityMutationRequest With {.CartRowId = rowId, .Quantity = CDec(_requestedQuantity)}
                })

            If changes Is Nothing OrElse changes.HasTechnicalError Then
                If CartMutationIdempotencyService.RegisterIntent(HttpContext.Current, _requestId, OperationType, payload) =
                   CartMutationIntentDecision.Indeterminate Then
                    Reject(409, "indeterminate_state", "L'esito dell'aggiornamento non è certo. Ricarica il carrello prima di riprovare.", True)
                    Return
                End If
                CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, _requestId)
                Reject(503, "technical_unavailable", "Il carrello non è disponibile. Aggiorna la pagina e riprova.")
                Return
            End If
            If changes.HasBlockingError OrElse changes.HasCommercialRuleError Then
                CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, _requestId)
                Reject(422, "commercial_unavailable", "Non è stato possibile aggiornare la quantità alle condizioni attuali. Ricarica il carrello e riprova.")
                Return
            End If

            mutationCommitted = True
            CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, _requestId)
            _commercialChanges = changes.HasChanges
            PrepareAuthoritativeResponse(False)
        Catch ex As Exception
            If mutationCommitted Then
                CartMutationIdempotencyService.MarkCurrentIntentIndeterminate(HttpContext.Current)
            Else
                CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, _requestId)
            End If
            LogSafeFailure(ex)
            Reject(503, "technical_unavailable", "Il carrello potrebbe essere stato aggiornato. Verificalo prima di riprovare.", True)
        End Try
        Catch ex As Exception
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, _requestId)
            LogSafeFailure(ex)
            Reject(503, "technical_unavailable", "Il carrello non è disponibile. Aggiorna la pagina e riprova.", True)
        End Try
    End Sub

    Private Function HandleIntentDecision(ByVal decision As CartMutationIntentDecision) As Boolean
        Select Case decision
            Case CartMutationIntentDecision.Accepted, CartMutationIntentDecision.Pending
                Return False
            Case CartMutationIntentDecision.Completed
                PrepareAuthoritativeResponse(True)
            Case CartMutationIntentDecision.Collision
                Reject(409, "idempotency_collision", "Identificativo richiesta già utilizzato per un'altra modifica.")
            Case CartMutationIntentDecision.Indeterminate
                Reject(409, "indeterminate_state", "L'esito dell'aggiornamento non è certo. Ricarica il carrello prima di riprovare.", True)
            Case CartMutationIntentDecision.Processing, CartMutationIntentDecision.CapacityExceeded
                Response.Headers("Retry-After") = "1"
                Reject(503, "processing", "Aggiornamento carrello in corso. Riprova tra poco.")
            Case Else
                Reject(400, "bad_request", "Richiesta carrello non valida.")
        End Select
        Return True
    End Function

    Private Sub PrepareAuthoritativeResponse(ByVal duplicate As Boolean)
        _cart = CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)
        If Not _cart.HasOwner OrElse Not _cart.LoadSucceeded Then
            Reject(503, "technical_unavailable", "Il carrello potrebbe essere stato aggiornato. Verificalo prima di riprovare.", True)
            Return
        End If
        _snapshot = CartStateSnapshotProvider.GetCurrent(HttpContext.Current)
        _miniCart = LoadControl("~/Public/ui/controls/MiniCart.ascx")
        If Not ConfigureStatelessMiniCart(_miniCart) Then
            Reject(503, "technical_unavailable", "Il carrello potrebbe essere stato aggiornato. Verificalo prima di riprovare.", True)
            Return
        End If
        _miniCart.ID = "MiniCartQuantityReadBack"
        Controls.Add(_miniCart)
        _duplicate = duplicate
        _success = True
        _statusCode = 200
        _message = If(duplicate, "Carrello già aggiornato.",
                      If(_commercialChanges, "Il carrello è stato aggiornato con i prezzi e le condizioni attuali.",
                         "Quantità aggiornata."))
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
        Dim responsePayload As New Dictionary(Of String, Object) From {
            {"ok", False}, {"code", _errorCode}, {"message", _message},
            {"requestId", _requestId}, {"reconcile", _reconcile}
        }
        If _success Then
            Try
                If _cart Is Nothing OrElse Not _cart.HasOwner OrElse Not _cart.LoadSucceeded OrElse
                   _snapshot Is Nothing OrElse _miniCart Is Nothing Then Throw New InvalidOperationException("Cart read-back unavailable.")

                Dim items As New List(Of Dictionary(Of String, Object))()
                For Each item As CartStateSnapshotItem In _snapshot.Items
                    If item Is Nothing OrElse item.ArticleId <= 0 OrElse item.Quantity <= 0D Then Continue For
                    items.Add(New Dictionary(Of String, Object) From {
                        {"id", item.ArticleId.ToString(CultureInfo.InvariantCulture)},
                        {"tcid", item.TCId.ToString(CultureInfo.InvariantCulture)},
                        {"qty", item.Quantity}
                    })
                Next

                Dim freeRowIds As New HashSet(Of Integer)()
                For Each row As DataRow In _cart.GetFreeShippingItems().Rows
                    freeRowIds.Add(ReadPositiveId(row, "id"))
                Next
                Dim rows As New List(Of Dictionary(Of String, Object))()
                For Each row As DataRow In _cart.GetAllItems().Rows
                    Dim id As Integer = ReadPositiveId(row, "id")
                    Dim articleId As Integer = ReadPositiveId(row, "ArticoliId")
                    Dim tcId As Integer = If(row.IsNull("TCId"), -1,
                                             CartStateSnapshotProvider.NormalizeTCId(ReadInteger(row, "TCId")))
                    Dim quantity As Decimal = ReadPositiveDecimal(row, "Qnt")
                    rows.Add(New Dictionary(Of String, Object) From {
                        {"rowId", id}, {"articleId", articleId}, {"tcid", tcId}, {"qty", quantity},
                        {"priceNetText", FormatMoney(ReadNonnegativeDecimal(row, "Prezzo"))},
                        {"priceGrossText", FormatMoney(ReadNonnegativeDecimal(row, "PrezzoIvato"))},
                        {"rowTotalNetText", FormatMoney(ReadNonnegativeDecimal(row, "Importo"))},
                        {"rowTotalGrossText", FormatMoney(ReadNonnegativeDecimal(row, "ImportoIvato"))},
                        {"freeShipping", freeRowIds.Contains(id)}
                    })
                Next

                Dim html As New StringBuilder()
                Using stringWriter As New StringWriter(html, CultureInfo.InvariantCulture)
                    Using htmlWriter As New HtmlTextWriter(stringWriter)
                        _miniCart.RenderControl(htmlWriter)
                    End Using
                End Using
                If html.Length = 0 OrElse html.ToString().IndexOf("ks-mini-cart-content", StringComparison.Ordinal) < 0 Then
                    Throw New InvalidOperationException("MiniCart read-back unavailable.")
                End If

                responsePayload.Clear()
                responsePayload("ok") = True
                responsePayload("duplicate") = _duplicate
                responsePayload("requestId") = _requestId
                responsePayload("requestedQuantity") = _requestedQuantity
                responsePayload("cart") = New Dictionary(Of String, Object) From {
                    {"count", Decimal.Truncate(_cart.TotalQuantity)},
                    {"items", items},
                    {"subtotalNetText", FormatMoney(_cart.TotalNet)},
                    {"subtotalGrossText", FormatMoney(_cart.TotalGross)}
                }
                responsePayload("rows") = rows
                responsePayload("miniCartHtml") = html.ToString()
                responsePayload("commercialChanges") = _commercialChanges
                responsePayload("message") = _message
            Catch ex As Exception
                LogSafeFailure(ex)
                Reject(503, "technical_unavailable", "Il carrello potrebbe essere stato aggiornato. Verificalo prima di riprovare.", True)
                responsePayload.Clear()
                responsePayload("ok") = False
                responsePayload("code") = _errorCode
                responsePayload("message") = _message
                responsePayload("requestId") = _requestId
                responsePayload("reconcile") = True
            End Try
        End If

        Response.ClearContent()
        Response.StatusCode = _statusCode
        Response.ContentType = "application/json"
        Response.ContentEncoding = Encoding.UTF8
        Response.Charset = "utf-8"
        Dim serializer As New JavaScriptSerializer() With {.MaxJsonLength = 1048576}
        Try
            writer.Write(serializer.Serialize(responsePayload))
        Catch ex As Exception
            LogSafeFailure(ex)
            Response.ClearContent()
            Response.StatusCode = 503
            writer.Write("{""ok"":false,""code"":""technical_unavailable"",""message"":""Il carrello potrebbe essere stato aggiornato. Verificalo prima di riprovare."",""reconcile"":true}")
        End Try
    End Sub

    Public Overrides Sub VerifyRenderingInServerForm(ByVal control As Control)
        ' The MiniCart fragment is serialized in JSON, outside a WebForms server form.
    End Sub

    Private Sub Reject(ByVal statusCode As Integer, ByVal code As String, ByVal message As String,
                       Optional ByVal reconcile As Boolean = False)
        _success = False
        _statusCode = statusCode
        _errorCode = code
        _message = message
        _reconcile = reconcile
    End Sub

    Private Function HasOnlyExpectedFormFields() As Boolean
        If Request.Form.Count <> 4 Then Return False
        For Each key As String In Request.Form.AllKeys
            If key Is Nothing OrElse
               (Not String.Equals(key, "rowId", StringComparison.Ordinal) AndAlso
                Not String.Equals(key, "quantity", StringComparison.Ordinal) AndAlso
                Not String.Equals(key, "requestId", StringComparison.Ordinal) AndAlso
                Not String.Equals(key, "csrfToken", StringComparison.Ordinal)) Then Return False
            Dim values() As String = Request.Form.GetValues(key)
            If values Is Nothing OrElse values.Length <> 1 Then Return False
        Next
        Return True
    End Function

    Private Function IsCartSameOriginRequest() As Boolean
        Dim requestUri As Uri = Request.Url
        Dim referrerUri As Uri = Request.UrlReferrer
        If requestUri Is Nothing OrElse referrerUri Is Nothing OrElse Not referrerUri.IsAbsoluteUri OrElse
           Not SameOrigin(requestUri, referrerUri) Then Return False
        If Not String.Equals(VirtualPathUtility.GetFileName(referrerUri.AbsolutePath), "carrello.aspx", StringComparison.OrdinalIgnoreCase) Then
            Return False
        End If
        Dim fetchSite As String = If(Request.Headers("Sec-Fetch-Site"), String.Empty).Trim()
        If fetchSite <> String.Empty AndAlso Not String.Equals(fetchSite, "same-origin", StringComparison.OrdinalIgnoreCase) Then
            Return False
        End If
        Dim originHeader As String = If(Request.Headers("Origin"), String.Empty).Trim()
        If originHeader = String.Empty Then Return True
        Dim origin As Uri = Nothing
        Return Uri.TryCreate(originHeader, UriKind.Absolute, origin) AndAlso SameOrigin(requestUri, origin)
    End Function

    Private Shared Function SameOrigin(ByVal first As Uri, ByVal second As Uri) As Boolean
        Return first IsNot Nothing AndAlso second IsNot Nothing AndAlso
               String.Equals(first.Scheme, second.Scheme, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(first.Host, second.Host, StringComparison.OrdinalIgnoreCase) AndAlso
               first.Port = second.Port
    End Function

    Private Shared Function ContainsRow(ByVal rows As DataTable, ByVal rowId As Integer) As Boolean
        If rows Is Nothing Then Return False
        For Each row As DataRow In rows.Rows
            If row IsNot Nothing AndAlso row.Table.Columns.Contains("id") AndAlso
               Convert.ToInt32(row("id"), CultureInfo.InvariantCulture) = rowId Then Return True
        Next
        Return False
    End Function

    Private Shared Function ReadInteger(ByVal row As DataRow, ByVal name As String) As Integer
        If row Is Nothing OrElse Not row.Table.Columns.Contains(name) OrElse row.IsNull(name) Then
            Throw New InvalidOperationException("Cart row data unavailable.")
        End If
        Return Convert.ToInt32(row(name), CultureInfo.InvariantCulture)
    End Function

    Private Shared Function ReadPositiveId(ByVal row As DataRow, ByVal name As String) As Integer
        Dim value As Integer = ReadInteger(row, name)
        If value <= 0 Then Throw New InvalidOperationException("Cart row identity unavailable.")
        Return value
    End Function

    Private Shared Function ReadNonnegativeDecimal(ByVal row As DataRow, ByVal name As String) As Decimal
        If row Is Nothing OrElse Not row.Table.Columns.Contains(name) OrElse row.IsNull(name) Then
            Throw New InvalidOperationException("Cart row amount unavailable.")
        End If
        Dim value As Decimal = Convert.ToDecimal(row(name), CultureInfo.InvariantCulture)
        If value < 0D Then Throw New InvalidOperationException("Cart row amount invalid.")
        Return value
    End Function

    Private Shared Function ReadPositiveDecimal(ByVal row As DataRow, ByVal name As String) As Decimal
        Dim value As Decimal = ReadNonnegativeDecimal(row, name)
        If value <= 0D Then Throw New InvalidOperationException("Cart row quantity unavailable.")
        Return value
    End Function

    Private Shared Function FormatMoney(ByVal value As Decimal) As String
        Return value.ToString("N2", MoneyCulture) & " " & ChrW(8364)
    End Function

    Private Sub LogSafeFailure(ByVal ex As Exception)
        Try
            KeepStoreLog.Error("cart_quantity_async.aspx", "Cart quantity response failed. Error type: " & ex.GetType().Name & ".",
                               Nothing, HttpContext.Current)
        Catch
        End Try
    End Sub
End Class
