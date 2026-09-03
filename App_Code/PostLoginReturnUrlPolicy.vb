Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Web

Public NotInheritable Class PostLoginReturnUrlPolicy
    Public Const ContextPathSessionKey As String = "KeepStore:PostLoginReturn:Path"
    Public Const ContextCreatedUtcSessionKey As String = "KeepStore:PostLoginReturn:CreatedUtc"

    Private Shared ReadOnly ContextLifetime As TimeSpan = TimeSpan.FromMinutes(15)

    Private Shared ReadOnly AllowedStorefrontPages As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "Default.aspx",
        "about.aspx",
        "articoli.aspx",
        "articolo.aspx",
        "carrello.aspx",
        "compare.aspx",
        "condizioni-vendita.aspx",
        "Contattaci.aspx",
        "coupon.aspx",
        "coupon_dettagli.aspx",
        "faq.aspx",
        "lastminute.aspx",
        "lista_coupon.aspx",
        "privacy.aspx",
        "promo.aspx",
        "promo_in_scadenza.aspx",
        "promozioni.aspx",
        "search.aspx",
        "settore_disabilitato.aspx",
        "sitemap.aspx",
        "track-your-order.aspx",
        "vetrina_interna.aspx",
        "wellcome.aspx"
    }

    Private Shared ReadOnly AllowedProtectedPages As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "datiutente.aspx",
        "documenti.aspx",
        "documentidettaglio.aspx",
        "my-account-address.aspx",
        "my-account-edit.aspx",
        "myaccount.aspx",
        "wishlist.aspx"
    }

    Private Shared ReadOnly CheckoutPages As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "checkout.aspx",
        "ordine.aspx",
        "ordine_coupon.aspx"
    }

    Private Sub New()
    End Sub

    Public Shared Function NormalizeReturnUrl(ByVal context As HttpContext, ByVal rawValue As Object) As String
        Return NormalizeInternal(context, ObjectToString(rawValue), True)
    End Function

    Public Shared Function NormalizeNavigableContext(ByVal context As HttpContext, ByVal rawValue As Object) As String
        Return NormalizeInternal(context, ObjectToString(rawValue), False)
    End Function

    Public Shared Function FirstValidReturnUrl(ByVal context As HttpContext, ParamArray candidates() As Object) As String
        If candidates Is Nothing Then Return String.Empty

        For Each candidate As Object In candidates
            Dim normalized As String = NormalizeReturnUrl(context, candidate)
            If normalized <> String.Empty Then Return normalized
        Next

        Return String.Empty
    End Function

    Public Shared Function ResolvePostLoginTarget(ByVal context As HttpContext,
                                                  ByVal explicitReturnUrl As Object,
                                                  ByVal legacyPage As Object,
                                                  ByVal legacyVisitedPage As Object) As String
        Dim normalized As String = NormalizeReturnUrl(context, explicitReturnUrl)
        If normalized <> String.Empty Then Return normalized

        normalized = PeekRememberedContext(context)
        If normalized <> String.Empty Then Return normalized

        normalized = NormalizeReturnUrl(context, legacyPage)
        If normalized <> String.Empty Then Return normalized

        normalized = NormalizeReturnUrl(context, legacyVisitedPage)
        If normalized <> String.Empty Then Return normalized

        Return ApplicationPagePath(context, "Default.aspx")
    End Function

    Public Shared Sub RememberContext(ByVal context As HttpContext, ByVal rawValue As Object)
        If context Is Nothing OrElse context.Session Is Nothing Then Return

        Dim normalized As String = NormalizeNavigableContext(context, rawValue)
        If normalized = String.Empty Then Return

        context.Session(ContextPathSessionKey) = normalized
        context.Session(ContextCreatedUtcSessionKey) = DateTime.UtcNow
    End Sub

    Public Shared Function PeekRememberedContext(ByVal context As HttpContext) As String
        If context Is Nothing OrElse context.Session Is Nothing Then Return String.Empty

        Try
            Dim rawPath As Object = context.Session(ContextPathSessionKey)
            Dim rawCreated As Object = context.Session(ContextCreatedUtcSessionKey)
            Dim createdUtc As DateTime

            If rawPath Is Nothing OrElse Not TryReadUtc(rawCreated, createdUtc) Then
                ClearRememberedContext(context)
                Return String.Empty
            End If

            Dim age As TimeSpan = DateTime.UtcNow.Subtract(createdUtc)
            If age < TimeSpan.FromMinutes(-1) OrElse age > ContextLifetime Then
                ClearRememberedContext(context)
                Return String.Empty
            End If

            Dim normalized As String = NormalizeReturnUrl(context, rawPath)
            If normalized = String.Empty Then
                ClearRememberedContext(context)
                Return String.Empty
            End If

            Return normalized
        Catch
            ClearRememberedContext(context)
            Return String.Empty
        End Try
    End Function

    Public Shared Sub ClearRememberedContext(ByVal context As HttpContext)
        If context Is Nothing OrElse context.Session Is Nothing Then Return

        context.Session.Remove(ContextPathSessionKey)
        context.Session.Remove(ContextCreatedUtcSessionKey)
    End Sub

    Public Shared Function BuildLoginUrl(ByVal context As HttpContext, ByVal rawReturnUrl As Object) As String
        Dim loginPath As String = ApplicationPagePath(context, "login.aspx")
        Dim normalized As String = NormalizeReturnUrl(context, rawReturnUrl)
        If normalized = String.Empty Then Return loginPath

        Return loginPath & "?ReturnUrl=" & HttpUtility.UrlEncode(normalized)
    End Function

    Public Shared Function IsProtectedDestination(ByVal context As HttpContext, ByVal rawValue As Object) As Boolean
        Dim normalized As String = NormalizeReturnUrl(context, rawValue)
        If normalized = String.Empty Then Return False

        Dim pageName As String = PageNameFromNormalized(context, normalized)
        Return pageName <> String.Empty AndAlso AllowedProtectedPages.Contains(pageName)
    End Function

    Private Shared Function NormalizeInternal(ByVal context As HttpContext,
                                              ByVal rawValue As String,
                                              ByVal downgradeCheckout As Boolean) As String
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Request.Url Is Nothing Then Return String.Empty
        If String.IsNullOrWhiteSpace(rawValue) Then Return String.Empty

        Dim candidate As String = rawValue.Trim()
        If ContainsUnsafeCharacters(candidate) OrElse ContainsAmbiguousEncoding(candidate) Then Return String.Empty

        Dim lowered As String = candidate.ToLowerInvariant()
        If candidate.StartsWith("//", StringComparison.Ordinal) OrElse
           candidate.StartsWith("\\", StringComparison.Ordinal) OrElse
           lowered.StartsWith("javascript:", StringComparison.Ordinal) OrElse
           lowered.StartsWith("data:", StringComparison.Ordinal) OrElse
           lowered.StartsWith("vbscript:", StringComparison.Ordinal) Then
            Return String.Empty
        End If

        Dim rawPath As String = PathPart(candidate)
        If ContainsUnsafeEncodedPath(rawPath) OrElse ContainsTraversal(rawPath) Then Return String.Empty

        If candidate.StartsWith("~/", StringComparison.Ordinal) Then
            candidate = ApplicationRoot(context) & candidate.Substring(2)
        End If

        Dim resolved As Uri = Nothing
        Dim absoluteCandidate As Uri = Nothing
        Dim rootedRelative As Boolean = candidate.StartsWith("/", StringComparison.Ordinal)
        If Not rootedRelative AndAlso Uri.TryCreate(candidate, UriKind.Absolute, absoluteCandidate) Then
            resolved = absoluteCandidate
        ElseIf Not Uri.TryCreate(context.Request.Url, candidate, resolved) Then
            Return String.Empty
        End If

        If resolved Is Nothing OrElse Not resolved.IsAbsoluteUri Then Return String.Empty
        If resolved.Scheme <> Uri.UriSchemeHttp AndAlso resolved.Scheme <> Uri.UriSchemeHttps Then Return String.Empty
        If Not String.Equals(resolved.Scheme, context.Request.Url.Scheme, StringComparison.OrdinalIgnoreCase) OrElse
           Not String.Equals(resolved.Host, context.Request.Url.Host, StringComparison.OrdinalIgnoreCase) OrElse
           resolved.Port <> context.Request.Url.Port OrElse
           resolved.UserInfo <> String.Empty Then
            Return String.Empty
        End If

        Dim decodedPath As String
        Try
            decodedPath = Uri.UnescapeDataString(resolved.AbsolutePath)
        Catch
            Return String.Empty
        End Try
        If ContainsUnsafeCharacters(decodedPath) OrElse ContainsTraversal(decodedPath) Then Return String.Empty

        Dim policyPath As String = ToApplicationRelativePath(context.Request, resolved.AbsolutePath)
        If policyPath = String.Empty Then Return String.Empty
        If policyPath = "/" Then Return ApplicationPagePath(context, "Default.aspx")
        If policyPath.IndexOf("/"c, 1) >= 0 Then Return String.Empty
        If Not String.Equals(Path.GetExtension(policyPath), ".aspx", StringComparison.OrdinalIgnoreCase) Then Return String.Empty

        Dim pageName As String = Path.GetFileName(policyPath)
        If pageName = String.Empty Then Return String.Empty

        If CheckoutPages.Contains(pageName) Then
            If downgradeCheckout Then Return ApplicationPagePath(context, "carrello.aspx")
            Return String.Empty
        End If

        If Not AllowedStorefrontPages.Contains(pageName) AndAlso Not AllowedProtectedPages.Contains(pageName) Then
            Return String.Empty
        End If

        If HasSensitiveOrNestedQuery(resolved.Query) Then Return String.Empty
        Return resolved.PathAndQuery
    End Function

    Private Shared Function ObjectToString(ByVal value As Object) As String
        If value Is Nothing Then Return String.Empty
        Dim uriValue As Uri = TryCast(value, Uri)
        If uriValue IsNot Nothing Then
            If uriValue.IsAbsoluteUri Then Return uriValue.AbsoluteUri
            Return uriValue.OriginalString
        End If
        Return Convert.ToString(value)
    End Function

    Private Shared Function TryReadUtc(ByVal value As Object, ByRef utcValue As DateTime) As Boolean
        If value Is Nothing Then Return False

        If TypeOf value Is DateTime Then
            utcValue = DirectCast(value, DateTime).ToUniversalTime()
            Return True
        End If

        Return DateTime.TryParse(Convert.ToString(value),
                                 CultureInfo.InvariantCulture,
                                 DateTimeStyles.AssumeUniversal Or DateTimeStyles.AdjustToUniversal,
                                 utcValue)
    End Function

    Private Shared Function HasSensitiveOrNestedQuery(ByVal query As String) As Boolean
        If String.IsNullOrEmpty(query) Then Return False

        Try
            Dim values As System.Collections.Specialized.NameValueCollection = HttpUtility.ParseQueryString(query.TrimStart("?"c))
            For Each rawKey As String In values.AllKeys
                If String.IsNullOrWhiteSpace(rawKey) Then Return True

                Dim key As String = rawKey.Trim().ToLowerInvariant()
                If key = "returnurl" OrElse
                   key = "redirect" OrElse
                   key = "redirect_uri" OrElse
                   key = "callback" OrElse
                   key = "code" OrElse
                   key = "state" OrElse
                   key = "payerid" OrElse
                   key = "paymentid" OrElse
                   key.Contains("token") Then
                    Return True
                End If
            Next
        Catch
            Return True
        End Try

        Return False
    End Function

    Private Shared Function PageNameFromNormalized(ByVal context As HttpContext, ByVal normalized As String) As String
        Dim resolved As Uri = Nothing
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Request.Url Is Nothing Then Return String.Empty
        If Not Uri.TryCreate(context.Request.Url, normalized, resolved) Then Return String.Empty

        Dim policyPath As String = ToApplicationRelativePath(context.Request, resolved.AbsolutePath)
        If policyPath = String.Empty Then Return String.Empty
        Return Path.GetFileName(policyPath)
    End Function

    Private Shared Function ApplicationRoot(ByVal context As HttpContext) As String
        Dim applicationPath As String = Convert.ToString(context.Request.ApplicationPath)
        If String.IsNullOrEmpty(applicationPath) Then applicationPath = "/"
        applicationPath = applicationPath.TrimEnd("/"c)
        If applicationPath = String.Empty OrElse applicationPath = "/" Then Return "/"
        Return applicationPath & "/"
    End Function

    Private Shared Function ApplicationPagePath(ByVal context As HttpContext, ByVal pageName As String) As String
        Return ApplicationRoot(context) & pageName.TrimStart("/"c)
    End Function

    Private Shared Function ToApplicationRelativePath(ByVal request As HttpRequest, ByVal absolutePath As String) As String
        If request Is Nothing OrElse String.IsNullOrEmpty(absolutePath) Then Return String.Empty

        Dim applicationPath As String = Convert.ToString(request.ApplicationPath)
        If String.IsNullOrEmpty(applicationPath) Then applicationPath = "/"
        applicationPath = applicationPath.TrimEnd("/"c)
        If applicationPath = String.Empty Then applicationPath = "/"

        If applicationPath = "/" Then Return absolutePath
        If String.Equals(absolutePath, applicationPath, StringComparison.OrdinalIgnoreCase) Then Return "/"
        If Not absolutePath.StartsWith(applicationPath & "/", StringComparison.OrdinalIgnoreCase) Then Return String.Empty
        Return absolutePath.Substring(applicationPath.Length)
    End Function

    Private Shared Function PathPart(ByVal value As String) As String
        Dim endIndex As Integer = value.Length
        Dim queryIndex As Integer = value.IndexOf("?"c)
        Dim fragmentIndex As Integer = value.IndexOf("#"c)
        If queryIndex >= 0 Then endIndex = Math.Min(endIndex, queryIndex)
        If fragmentIndex >= 0 Then endIndex = Math.Min(endIndex, fragmentIndex)
        Return value.Substring(0, endIndex)
    End Function

    Private Shared Function ContainsUnsafeCharacters(ByVal value As String) As Boolean
        Return value.IndexOfAny(New Char() {ControlChars.Cr, ControlChars.Lf, ControlChars.NullChar, "\"c}) >= 0
    End Function

    Private Shared Function ContainsAmbiguousEncoding(ByVal value As String) As Boolean
        Dim lowered As String = Convert.ToString(value).ToLowerInvariant()
        Return lowered.Contains("%00") OrElse
               lowered.Contains("%0d") OrElse
               lowered.Contains("%0a") OrElse
               lowered.Contains("%5c") OrElse
               lowered.Contains("%25")
    End Function

    Private Shared Function ContainsUnsafeEncodedPath(ByVal value As String) As Boolean
        Dim lowered As String = Convert.ToString(value).ToLowerInvariant()
        Return lowered.Contains("%2f") OrElse
               lowered.Contains("%2e") OrElse
               lowered.Contains("%5c") OrElse
               lowered.Contains("%25")
    End Function

    Private Shared Function ContainsTraversal(ByVal value As String) As Boolean
        Dim segments() As String = Convert.ToString(value).Replace("\"c, "/"c).Split("/"c)
        For Each segment As String In segments
            If segment = "." OrElse segment = ".." Then Return True
        Next
        Return False
    End Function
End Class
