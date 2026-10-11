Option Strict On
Option Explicit On

Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.SessionState

Public NotInheritable Class CompareCommercialSnapshotHandler
    Implements IHttpHandler, IReadOnlySessionState

    Private Const MaximumRequestBytes As Integer = 8192
    ' These server-owned scalars are written only by PageMaster.LeggiAzienda.
    Private Const TenantCompanyKey As String = "KeepStore.PriceDisplay.TenantCompanyId"
    Private Const TenantListKey As String = "KeepStore.PriceDisplay.TenantPriceListId"
    Private Const TenantModeKey As String = "KeepStore.PriceDisplay.TenantMode"

    Public ReadOnly Property IsReusable As Boolean Implements IHttpHandler.IsReusable
        Get
            Return False
        End Get
    End Property

    Public Sub ProcessRequest(ByVal context As HttpContext) Implements IHttpHandler.ProcessRequest
        Try
            If Not String.Equals(context.Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then
                context.Response.AppendHeader("Allow", "POST")
                WriteError(context, 405, "method_not_allowed")
                Return
            End If
            If context.Request.QueryString.Count <> 0 Then
                WriteError(context, 400, "invalid_request")
                Return
            End If
            If Not context.Request.IsSecureConnection OrElse Not IsSameOrigin(context.Request) OrElse
               Not String.Equals(context.Request.Headers("X-Requested-With"), "XMLHttpRequest", StringComparison.OrdinalIgnoreCase) Then
                WriteError(context, 403, "forbidden")
                Return
            End If
            Dim token As String = context.Request.Headers("X-KeepStore-CSRF")
            If String.IsNullOrEmpty(token) OrElse token.Length > 256 OrElse
               Not CatalogAsyncCartSupport.ValidateCsrfToken(context, token) Then
                WriteError(context, 403, "csrf_invalid")
                Return
            End If
            Dim keys As List(Of CompareCommercialProductKey) = Nothing
            Dim inputStatus As Integer = 400
            If Not TryReadProducts(context.Request, keys, inputStatus) Then
                WriteError(context, inputStatus, If(inputStatus = 413, "request_too_large", "invalid_request"))
                Return
            End If

            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
            If tenant Is Nothing Then
                WriteError(context, 421, "unknown_storefront")
                Return
            End If
            Dim priceContext As StorefrontPriceDisplayContext = InitializePriceContext(context, tenant)
            If priceContext Is Nothing Then
                WriteError(context, 403, "storefront_context_required")
                Return
            End If
            Dim snapshot As CompareCommercialSnapshot = CompareCommercialSnapshotProvider.LoadCurrent(context, keys)
            Dim status As Integer = 503
            Select Case snapshot.Status
                Case CompareCommercialSnapshotStatus.Ready
                    status = 200
                Case CompareCommercialSnapshotStatus.InvalidInput
                    status = 400
                Case CompareCommercialSnapshotStatus.InvalidContext
                    status = 403
            End Select
            WriteJson(context, status, BuildPayload(snapshot, priceContext))
        Catch
            WriteError(context, 503, "technical_unavailable")
        End Try
    End Sub

    Private Shared Function InitializePriceContext(ByVal context As HttpContext,
                                                    ByVal tenant As StorefrontSeoTenantIdentity) As StorefrontPriceDisplayContext
        If context.Session Is Nothing OrElse tenant Is Nothing OrElse tenant.CompanyId <= 0 OrElse
           tenant.DefaultPriceListId <= 0 Then Return Nothing
        ' Reuse defaults already hydrated by the storefront page, never account
        ' IvaTipo as a tenant default. No Session writes or anonymous fallbacks.
        Dim company As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session(TenantCompanyKey))
        Dim priceList As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session(TenantListKey))
        Dim mode As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session(TenantModeKey))
        If company <> tenant.CompanyId OrElse priceList <> tenant.DefaultPriceListId OrElse
           (mode <> 1 AndAlso mode <> 2) OrElse
           StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session("AziendaID")) <> company Then Return Nothing
        StorefrontPriceDisplayContextProvider.SetTenantDefaults(context, company, priceList, mode)
        Dim result As StorefrontPriceDisplayContext = StorefrontPriceDisplayContextProvider.GetCurrent(context)
        If result Is Nothing OrElse (result.IsAuthenticated AndAlso
           StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session("UtentiId")) <= 0) Then Return Nothing
        Return result
    End Function

    Private Shared Function IsSameOrigin(ByVal request As HttpRequest) As Boolean
        Dim fetchSite As String = If(request.Headers("Sec-Fetch-Site"), String.Empty).Trim()
        If fetchSite <> String.Empty AndAlso Not String.Equals(fetchSite, "same-origin", StringComparison.OrdinalIgnoreCase) Then Return False
        Dim origin As String = If(request.Headers("Origin"), String.Empty).Trim()
        Dim referrer As String = If(request.Headers("Referer"), String.Empty).Trim()
        If origin = String.Empty AndAlso referrer = String.Empty Then Return False
        If origin <> String.Empty Then
            Dim originUri As Uri = Nothing
            If Not Uri.TryCreate(origin, UriKind.Absolute, originUri) OrElse originUri.AbsolutePath <> "/" OrElse
               originUri.Query <> String.Empty OrElse originUri.Fragment <> String.Empty Then Return False
        End If
        For Each supplied As String In New String() {origin, referrer}
            If supplied = String.Empty Then Continue For
            Dim uri As Uri = Nothing
            If Not Uri.TryCreate(supplied, UriKind.Absolute, uri) OrElse uri.UserInfo <> String.Empty OrElse
               Not String.Equals(uri.Scheme, request.Url.Scheme, StringComparison.OrdinalIgnoreCase) OrElse
               Not String.Equals(uri.Host, request.Url.Host, StringComparison.OrdinalIgnoreCase) OrElse uri.Port <> request.Url.Port Then Return False
        Next
        Return True
    End Function

    Private Shared Function TryReadProducts(ByVal request As HttpRequest,
                                            ByRef keys As List(Of CompareCommercialProductKey),
                                            ByRef status As Integer) As Boolean
        keys = New List(Of CompareCommercialProductKey)()
        status = 400
        If request.ContentLength > MaximumRequestBytes Then
            status = 413
            Return False
        End If
        If Not String.Equals(If(request.ContentType, String.Empty).Split(";"c)(0).Trim(), "application/json", StringComparison.OrdinalIgnoreCase) Then Return False
        Try
            Dim json As String
            Using buffer As New MemoryStream()
                Dim chunk(1023) As Byte
                While True
                    Dim count As Integer = request.InputStream.Read(chunk, 0, chunk.Length)
                    If count = 0 Then Exit While
                    If buffer.Length + count > MaximumRequestBytes Then
                        status = 413
                        Return False
                    End If
                    buffer.Write(chunk, 0, count)
                End While
                json = New UTF8Encoding(False, True).GetString(buffer.ToArray())
            End Using
            Dim serializer As New JavaScriptSerializer() With {.MaxJsonLength = MaximumRequestBytes, .RecursionLimit = 8}
            Dim root As IDictionary(Of String, Object) = TryCast(serializer.DeserializeObject(json), IDictionary(Of String, Object))
            If root Is Nothing OrElse root.Count <> 1 OrElse Not root.ContainsKey("products") Then Return False
            Dim products As IList = TryCast(root("products"), IList)
            If products Is Nothing OrElse products.Count > CompareCommercialSnapshotProvider.MaximumProducts Then Return False
            For Each product As Object In products
                Dim fields As IDictionary(Of String, Object) = TryCast(product, IDictionary(Of String, Object))
                If fields Is Nothing OrElse fields.Count <> 2 OrElse Not fields.ContainsKey("id") OrElse Not fields.ContainsKey("TCId") Then Return False
                Dim articleId As Integer
                Dim tcId As Integer
                If Not TryInteger(fields("id"), articleId) OrElse articleId <= 0 OrElse
                   Not TryInteger(fields("TCId"), tcId) OrElse tcId < -1 Then Return False
                keys.Add(New CompareCommercialProductKey(articleId, tcId))
            Next
            Return True
        Catch
            Return False
        End Try
    End Function

    Private Shared Function TryInteger(ByVal value As Object, ByRef result As Integer) As Boolean
        If Not TypeOf value Is Integer AndAlso Not TypeOf value Is Long AndAlso Not TypeOf value Is Decimal Then Return False
        Dim number As Decimal = Convert.ToDecimal(value, CultureInfo.InvariantCulture)
        If number < Integer.MinValue OrElse number > Integer.MaxValue OrElse Decimal.Truncate(number) <> number Then Return False
        result = CInt(number)
        Return True
    End Function

    Friend Shared Function BuildPayload(ByVal snapshot As CompareCommercialSnapshot,
                                        ByVal priceContext As StorefrontPriceDisplayContext) As Dictionary(Of String, Object)
        Dim items As New List(Of Dictionary(Of String, Object))()
        For Each item As CompareCommercialSnapshotItem In snapshot.Items
            Dim output As New Dictionary(Of String, Object) From {
                {"id", item.Key.ArticleId}, {"TCId", item.Key.TCId},
                {"verified", item.Status = CompareCommercialVerificationStatus.Verified}
            }
            If item.Status = CompareCommercialVerificationStatus.Verified Then
                output("price") = item.Price.Value
                output("availability") = New Dictionary(Of String, Object) From {
                    {"available", item.IsAvailable.Value}, {"text", item.AvailabilityText}
                }
            Else
                output("reason") = item.Failure.ToString()
            End If
            items.Add(output)
        Next
        Dim payload As New Dictionary(Of String, Object) From {
            {"ok", snapshot.Status = CompareCommercialSnapshotStatus.Ready},
            {"state", snapshot.Status.ToString()}, {"items", items}
        }
        If snapshot.Status = CompareCommercialSnapshotStatus.Ready Then
            payload("vat") = New Dictionary(Of String, Object) From {
                {"mode", CInt(priceContext.DisplayMode)}, {"label", priceContext.DisplayLabel}
            }
        End If
        Return payload
    End Function

    Private Shared Sub WriteError(ByVal context As HttpContext, ByVal status As Integer, ByVal code As String)
        WriteJson(context, status, New Dictionary(Of String, Object) From {
            {"ok", False}, {"state", code}, {"items", New Object() {}}
        })
    End Sub

    Private Shared Sub WriteJson(ByVal context As HttpContext, ByVal status As Integer, ByVal payload As Object)
        Dim response As HttpResponse = context.Response
        response.ClearContent()
        response.StatusCode = status
        response.TrySkipIisCustomErrors = True
        response.ContentType = "application/json"
        response.ContentEncoding = Encoding.UTF8
        response.Charset = "utf-8"
        response.Cache.SetCacheability(HttpCacheability.NoCache)
        response.Cache.SetNoStore()
        response.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
        response.Cache.SetExpires(DateTime.UtcNow.AddMinutes(-1))
        response.AppendHeader("Vary", "Cookie")
        response.AppendHeader("X-Content-Type-Options", "nosniff")
        response.Write(New JavaScriptSerializer() With {.MaxJsonLength = 32768, .RecursionLimit = 12}.Serialize(payload))
    End Sub
End Class
