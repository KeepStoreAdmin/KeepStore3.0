Imports System
Imports System.Collections.Generic
Imports System.IO
Imports System.Web

Public NotInheritable Class StorefrontReturnUrlPolicy
    Private Shared ReadOnly DisallowedShoppingPages As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "404.aspx",
        "accessonegato.aspx",
        "aggiungi.aspx",
        "amazon.aspx",
        "art_stampabile.aspx",
        "articolix.aspx",
        "bancasella.aspx",
        "cambiapassword.aspx",
        "carrello.aspx",
        "carrello_groupon.aspx",
        "cart_add.aspx",
        "catalog_cart_async.aspx",
        "click.aspx",
        "coupon_esito_acquisto.aspx",
        "coupon_stampa.aspx",
        "datiutente.aspx",
        "diagnostic.aspx",
        "documenti.aspx",
        "documentidettaglio.aspx",
        "ebay.aspx",
        "export.aspx",
        "export_amazon.aspx",
        "export_csv.aspx",
        "home_runtime_feed.aspx",
        "icecat.aspx",
        "icecat_consult.aspx",
        "ipn.aspx",
        "listini.aspx",
        "listino_personalizzato.aspx",
        "login.aspx",
        "logout.aspx",
        "main.aspx",
        "my-account-address.aspx",
        "my-account-edit.aspx",
        "myaccount.aspx",
        "ok_groupon.aspx",
        "ordine.aspx",
        "ordine_coupon.aspx",
        "pagamento.aspx",
        "password.aspx",
        "pay_your_orders.aspx",
        "paypalcheckout.aspx",
        "paypalrecheck.aspx",
        "paypalreturn.aspx",
        "registrazione.aspx",
        "registrazioneok.aspx",
        "remind.aspx",
        "resetpassword.aspx",
        "rettificamagazzino.aspx",
        "search_complete.aspx",
        "search_suggest.aspx",
        "setup_listino_personalizzato.aspx",
        "soundmp3.aspx",
        "test.aspx",
        "themetest.aspx",
        "track-your-order.aspx",
        "vers_stampabile.aspx",
        "wishlist_add.aspx",
        "xml_banner.aspx"
    }

    Private Sub New()
    End Sub

    Public Shared Function FirstValidShoppingReturnUrl(ByVal context As HttpContext, ParamArray candidates() As String) As String
        If candidates Is Nothing Then Return String.Empty

        For Each candidate As String In candidates
            Dim normalized As String = NormalizeShoppingReturnUrl(context, candidate)
            If normalized <> String.Empty Then Return normalized
        Next

        Return String.Empty
    End Function

    Public Shared Function NormalizeShoppingReturnUrl(ByVal context As HttpContext, ByVal rawValue As String) As String
        If context Is Nothing OrElse context.Request Is Nothing OrElse context.Request.Url Is Nothing Then Return String.Empty

        If String.IsNullOrWhiteSpace(rawValue) Then Return String.Empty
        Dim candidate As String = rawValue.Trim()
        If ContainsUnsafeCharacters(candidate) Then Return String.Empty

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
            Dim applicationPath As String = Convert.ToString(context.Request.ApplicationPath).TrimEnd("/"c)
            candidate = If(applicationPath = String.Empty, String.Empty, applicationPath) & "/" & candidate.Substring(2)
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
        If policyPath = "/" Then Return resolved.PathAndQuery
        If policyPath.IndexOf("/"c, 1) >= 0 Then Return String.Empty
        If Not String.Equals(Path.GetExtension(policyPath), ".aspx", StringComparison.OrdinalIgnoreCase) Then Return String.Empty

        Dim pageName As String = Path.GetFileName(policyPath)
        If pageName = String.Empty OrElse DisallowedShoppingPages.Contains(pageName) Then Return String.Empty

        Return resolved.PathAndQuery
    End Function

    Private Shared Function ToApplicationRelativePath(ByVal request As HttpRequest, ByVal absolutePath As String) As String
        Dim applicationPath As String = Convert.ToString(request.ApplicationPath).TrimEnd("/"c)
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

    Private Shared Function ContainsUnsafeEncodedPath(ByVal value As String) As Boolean
        Dim lowered As String = Convert.ToString(value).ToLowerInvariant()
        Return lowered.Contains("%0d") OrElse
               lowered.Contains("%0a") OrElse
               lowered.Contains("%00") OrElse
               lowered.Contains("%5c") OrElse
               lowered.Contains("%2f") OrElse
               lowered.Contains("%2e") OrElse
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
