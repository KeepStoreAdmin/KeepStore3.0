Imports System
Imports System.Collections
Imports System.Collections.Specialized
Imports System.Globalization
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Collections.Generic

Partial Class cart_add
    Inherits AntiCsrfPage

    Private Const IndeterminateMessage As String = "Non è stato possibile confermare l'aggiornamento. Aggiorna il carrello e riprova."

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Not String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then
            Response.StatusCode = 405
            Response.TrySkipIisCustomErrors = True
            Response.Headers("Allow") = "POST"
            Response.ContentType = "text/plain"
            Response.Write("Metodo non consentito.")
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        If Not IsSameOriginRequest() OrElse
           Not CatalogAsyncCartSupport.ValidateCsrfToken(HttpContext.Current, Request.Form("csrfToken")) Then
            Reject(403, "Richiesta non autorizzata.")
            Return
        End If

        Dim actionValues As NameValueCollection = Nothing
        Dim packedAction As String = Convert.ToString(Request.Form("ksCartAction"))
        If Not String.IsNullOrWhiteSpace(packedAction) Then actionValues = HttpUtility.ParseQueryString(packedAction)

        Dim requestId As String = String.Empty
        If Not CartMutationIdempotencyService.NormalizeRequestId(ReadActionValue(actionValues, "requestId"), requestId) Then
            Reject(400, "Identificativo richiesta non valido.")
            Return
        End If

        Dim operation As String = ReadActionValue(actionValues, "operation").Trim().ToLowerInvariant()
        If operation = String.Empty Then operation = "cart-add"

        Dim cartReturnUrl As String = StorefrontReturnUrlPolicy.FirstValidShoppingReturnUrl(
            HttpContext.Current,
            Convert.ToString(Request.Form("ReturnUrl")),
            If(Request.UrlReferrer IsNot Nothing, Request.UrlReferrer.AbsoluteUri, String.Empty),
            Convert.ToString(Session("Carrello_Pagina")))
        If cartReturnUrl = String.Empty Then cartReturnUrl = "/articoli.aspx"
        Session("Carrello_Pagina") = cartReturnUrl

        Select Case operation
            Case "cart-add"
                HandleStandardAction(actionValues, requestId, cartReturnUrl, False)
            Case "cart-set"
                HandleStandardAction(actionValues, requestId, cartReturnUrl, True)
            Case "pdp-bundle"
                HandleBundleAction(actionValues, requestId, cartReturnUrl)
            Case "cart-remove-row"
                HandleRemovalAction(actionValues, requestId, cartReturnUrl, False)
            Case "cart-clear"
                HandleRemovalAction(actionValues, requestId, cartReturnUrl, True)
            Case Else
                Reject(400, "Operazione carrello non valida.")
        End Select
    End Sub

    Private Sub HandleRemovalAction(ByVal actionValues As NameValueCollection,
                                    ByVal requestId As String,
                                    ByVal cartReturnUrl As String,
                                    ByVal clearAll As Boolean)
        Dim cartRowId As Integer = 0
        If Not clearAll AndAlso
           (Not Integer.TryParse(ReadActionValue(actionValues, "rowId"), cartRowId) OrElse cartRowId <= 0) Then
            Reject(400, "Parametri carrello non validi.")
            Return
        End If

        Dim operationType As String = If(clearAll, "cart-clear", "cart-remove-row")
        Dim payload As String = If(clearAll,
                                   CartMutationIdempotencyService.BuildClearCartPayload(),
                                   CartMutationIdempotencyService.BuildRemoveRowPayload(cartRowId))
        If Not TryAcquireIntent(requestId, operationType, payload, cartReturnUrl) Then Return

        Dim result As CartOwnerRemovalResult = If(clearAll,
            CartMutationService.ClearCartForCurrentOwner(HttpContext.Current),
            CartMutationService.RemoveCartRowForCurrentOwner(HttpContext.Current, cartRowId))
        If result Is Nothing OrElse Not result.Succeeded Then
            If result IsNot Nothing AndAlso result.IsIndeterminate Then
                Reject(409, IndeterminateMessage)
            Else
                CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, requestId)
                Reject(422, "Non è stato possibile aggiornare il carrello. Riprova.")
            End If
            Return
        End If

        CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, requestId)
        CartMutationIdempotencyService.ClearProgressiveRequestIds(
            HttpContext.Current, If(clearAll, "cart-clear:", "cart-remove:"))
        Session(CartPriceRevalidationHelper.SessionMessageKey) = "Il carrello è stato aggiornato."
        Session(CartPriceRevalidationHelper.SessionChangedKey) = 1
        RedirectAfterPost(cartReturnUrl)
    End Sub

    Private Sub HandleStandardAction(ByVal actionValues As NameValueCollection,
                                     ByVal requestId As String,
                                     ByVal cartReturnUrl As String,
                                     ByVal setAbsoluteQuantity As Boolean)
        Dim articleId As Integer = 0
        If Not Integer.TryParse(ReadActionValue(actionValues, "id"), articleId) OrElse articleId <= 0 Then
            Reject(400, "Parametri carrello non validi.")
            Return
        End If

        Dim tcId As Integer = -1
        Integer.TryParse(ReadActionValue(actionValues, "tcid"), tcId)
        If tcId <= 0 Then tcId = -1

        Dim quantityRaw As String
        If setAbsoluteQuantity Then
            Dim quantityFieldName As String = ReadActionValue(actionValues, "qtyField")
            If Not IsSafeQuantityFieldName(quantityFieldName) Then
                Reject(400, "Parametri carrello non validi.")
                Return
            End If
            quantityRaw = Convert.ToString(Request.Form(quantityFieldName))
        Else
            quantityRaw = ReadActionValue(actionValues, "qty")
        End If

        Dim quantity As Decimal = 0D
        If Not TryParseQuantity(quantityRaw, quantity) OrElse
           (setAbsoluteQuantity AndAlso quantity <= 0D) Then
            Reject(400, "Parametri carrello non validi.")
            Return
        End If

        Dim operationType As String = If(setAbsoluteQuantity, "cart-set", "cart-add")
        Dim payload As String = If(setAbsoluteQuantity,
                                   CartMutationIdempotencyService.BuildSetQuantityPayload(articleId, tcId, quantity),
                                   CartMutationIdempotencyService.BuildStandardPayload(articleId, tcId, quantity))
        If Not TryAcquireIntent(requestId, operationType, payload, cartReturnUrl) Then Return

        If Not setAbsoluteQuantity AndAlso quantity = 0D Then
            CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, requestId)
            RedirectAfterPost(cartReturnUrl)
            Return
        End If

        Dim result As CartStandardMutationResult
        If setAbsoluteQuantity Then
            result = CartMutationService.SetStandardProductQuantityForCurrentOwner(
                HttpContext.Current, articleId, tcId, quantity)
        Else
            result = CartMutationService.AddStandardProductForCurrentOwner(
                HttpContext.Current, articleId, tcId, quantity)
        End If

        If result Is Nothing OrElse Not result.Succeeded Then
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, requestId)
            Reject(422, "Il prodotto non è stato aggiunto. Verifica disponibilità e prezzo.")
            Return
        End If

        CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, requestId)
        StoreSingleFeedback(result)
        RedirectAfterPost(cartReturnUrl)
    End Sub

    Private Sub HandleBundleAction(ByVal actionValues As NameValueCollection,
                                   ByVal requestId As String,
                                   ByVal cartReturnUrl As String)
        Dim bundleItems As List(Of CartStandardBatchMutationRequest) = Nothing
        If Not TryParseBundleItems(ReadActionValue(actionValues, "items"), bundleItems) Then
            Reject(400, "Parametri carrello non validi.")
            Return
        End If

        Dim normalizedItems As List(Of CartStandardBatchMutationRequest) = Nothing
        Dim payload As String = String.Empty
        If Not CartMutationIdempotencyService.TryNormalizeStandardBatchItems(
            bundleItems, 20, normalizedItems, payload) Then
            Reject(400, "Parametri carrello non validi.")
            Return
        End If
        If Not TryAcquireIntent(requestId, "pdp-bundle", payload, cartReturnUrl) Then Return

        Dim batchResult As CartStandardBatchMutationResult = Nothing
        Try
            batchResult = CartMutationService.AddStandardProductsBatchForCurrentOwner(
                HttpContext.Current, bundleItems)
        Catch ex As Exception
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, requestId)
            Try
                KeepStoreLog.Error("cart_add.aspx", "Errore aggiunta bundle PDP.", ex, HttpContext.Current)
            Catch logError As Exception
                System.Diagnostics.Trace.TraceError("cart_add bundle logging failed. Error type: " & logError.GetType().Name & ".")
            End Try
            Reject(500, "Non è stato possibile aggiornare il carrello. Riprova.")
            Return
        End Try

        If batchResult Is Nothing OrElse Not batchResult.Succeeded OrElse batchResult.Items.Count = 0 Then
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, requestId)
            Reject(422, "I prodotti selezionati non sono stati aggiunti. Verifica disponibilità e prezzo.")
            Return
        End If

        CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, requestId)
        Session("ks_cart_feedback_kind") = "multi"
        Session("ks_cart_feedback_product_name") = ""
        Session("ks_cart_feedback_article_id") = 0
        Session("ks_cart_feedback_tcid") = -1
        Session("ks_cart_feedback_count") = batchResult.Items.Count
        Session("ks_cart_feedback_created_utc") = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture)
        RedirectAfterPost(cartReturnUrl)
    End Sub

    Private Function TryAcquireIntent(ByVal requestId As String,
                                      ByVal operationType As String,
                                      ByVal payload As String,
                                      ByVal cartReturnUrl As String) As Boolean
        Dim decision As CartMutationIntentDecision = CartMutationIdempotencyService.RegisterIntent(
            HttpContext.Current, requestId, operationType, payload)
        If decision = CartMutationIntentDecision.Completed Then
            RedirectAfterPost(cartReturnUrl)
            Return False
        End If
        If decision = CartMutationIntentDecision.Indeterminate Then
            Reject(409, IndeterminateMessage)
            Return False
        End If
        If decision = CartMutationIntentDecision.Collision Then
            Try
                KeepStoreLog.Info("cart_add.aspx", "Richiesta carrello rifiutata per collisione idempotente.", HttpContext.Current)
            Catch
            End Try
            Reject(409, "Identificativo richiesta non valido.")
            Return False
        End If
        If decision = CartMutationIntentDecision.Invalid Then
            Reject(400, "Richiesta carrello non valida.")
            Return False
        End If
        If decision = CartMutationIntentDecision.Processing OrElse decision = CartMutationIntentDecision.CapacityExceeded Then
            Response.Headers("Retry-After") = "1"
            Reject(503, "Aggiornamento carrello in corso. Riprova tra poco.")
            Return False
        End If

        Dim beginDecision As CartMutationIntentDecision = CartMutationIdempotencyService.BeginIntent(
            HttpContext.Current, requestId, operationType, payload)
        If beginDecision = CartMutationIntentDecision.Completed Then
            RedirectAfterPost(cartReturnUrl)
            Return False
        End If
        If beginDecision = CartMutationIntentDecision.Indeterminate Then
            Reject(409, IndeterminateMessage)
            Return False
        End If
        If beginDecision <> CartMutationIntentDecision.Accepted Then
            If beginDecision = CartMutationIntentDecision.Processing OrElse
               beginDecision = CartMutationIntentDecision.CapacityExceeded Then Response.Headers("Retry-After") = "1"
            Reject(If(beginDecision = CartMutationIntentDecision.Collision, 409, 503), "Aggiornamento carrello non disponibile. Riprova.")
            Return False
        End If
        Return True
    End Function

    Private Function TryParseBundleItems(
        ByVal rawItems As String,
        ByRef items As List(Of CartStandardBatchMutationRequest)) As Boolean

        items = New List(Of CartStandardBatchMutationRequest)()
        Dim values As String() = If(rawItems, String.Empty).Split(";"c)
        If values.Length = 0 OrElse values.Length > 20 Then Return False

        For Each rawItem As String In values
            Dim parts As String() = rawItem.Split(","c)
            If parts.Length <> 3 Then Return False

            Dim articleId As Integer = 0
            Dim tcId As Integer = -1
            Dim quantity As Decimal = 0D
            If Not Integer.TryParse(parts(0), NumberStyles.Integer, CultureInfo.InvariantCulture, articleId) OrElse articleId <= 0 Then Return False
            Integer.TryParse(parts(1), NumberStyles.Integer, CultureInfo.InvariantCulture, tcId)
            If tcId <= 0 Then tcId = -1
            If Not TryParseQuantity(parts(2), quantity) OrElse quantity <= 0D Then Return False

            items.Add(New CartStandardBatchMutationRequest With {
                .ArticleId = articleId,
                .RequestedTCId = tcId,
                .QuantityDelta = quantity
            })
        Next

        Return items.Count > 0
    End Function

    Private Function TryParseQuantity(ByVal rawValue As String, ByRef quantity As Decimal) As Boolean
        quantity = 0D
        If Not Decimal.TryParse(rawValue, NumberStyles.Any, CultureInfo.InvariantCulture, quantity) AndAlso
           Not Decimal.TryParse(rawValue, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), quantity) Then Return False
        Return quantity >= -9999D AndAlso quantity <= 9999D AndAlso Decimal.Truncate(quantity) = quantity
    End Function

    Private Function IsSafeQuantityFieldName(ByVal fieldName As String) As Boolean
        Return Not String.IsNullOrWhiteSpace(fieldName) AndAlso fieldName.Length <= 128 AndAlso
               Regex.IsMatch(fieldName, "^[A-Za-z0-9_$:-]+$", RegexOptions.CultureInvariant)
    End Function

    Private Sub StoreSingleFeedback(ByVal result As CartStandardMutationResult)
        Session("ks_cart_feedback_kind") = "single"
        Session("ks_cart_feedback_product_name") = result.ProductName
        Session("ks_cart_feedback_article_id") = result.ArticleId
        Session("ks_cart_feedback_tcid") = result.TCId
        Session("ks_cart_feedback_count") = 1
        Session("ks_cart_feedback_created_utc") = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture)
    End Sub

    Private Function ReadActionValue(ByVal actionValues As NameValueCollection,
                                     ByVal key As String) As String
        Dim directValue As String = Convert.ToString(Request.Form(key))
        If directValue <> String.Empty Then Return directValue
        If actionValues Is Nothing Then Return String.Empty
        Return Convert.ToString(actionValues(key))
    End Function

    Private Function IsSameOriginRequest() As Boolean
        Dim requestUri As Uri = Request.Url
        If requestUri Is Nothing Then Return False

        Dim originHeader As String = If(Request.Headers("Origin"), String.Empty).Trim()
        If originHeader <> String.Empty Then
            Dim originUri As Uri = Nothing
            Return Uri.TryCreate(originHeader, UriKind.Absolute, originUri) AndAlso SameOrigin(requestUri, originUri)
        End If

        Dim referrerUri As Uri = Request.UrlReferrer
        Return referrerUri IsNot Nothing AndAlso referrerUri.IsAbsoluteUri AndAlso SameOrigin(requestUri, referrerUri)
    End Function

    Private Function SameOrigin(ByVal first As Uri, ByVal second As Uri) As Boolean
        Return first IsNot Nothing AndAlso second IsNot Nothing AndAlso
               String.Equals(first.Scheme, second.Scheme, StringComparison.OrdinalIgnoreCase) AndAlso
               String.Equals(first.Host, second.Host, StringComparison.OrdinalIgnoreCase) AndAlso
               first.Port = second.Port
    End Function

    Private Sub RedirectAfterPost(ByVal returnUrl As String)
        Response.Clear()
        Response.StatusCode = 303
        Response.TrySkipIisCustomErrors = True
        Response.RedirectLocation = If(returnUrl <> String.Empty, returnUrl, "/articoli.aspx")
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Sub Reject(ByVal statusCode As Integer, ByVal message As String)
        Response.StatusCode = statusCode
        Response.TrySkipIisCustomErrors = True
        Response.ContentType = "text/plain"
        Response.Write(message)
        Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
