Imports System

Public NotInheritable Class StorefrontCanonicalHostPolicy
    Private Const TaikunAliasHost As String = "taikun.it"
    Private Const TaikunCanonicalHost As String = "www.taikun.it"

    Private Sub New()
    End Sub

    Public Shared Function BuildCanonicalUrl(ByVal requestUrl As Uri,
                                             ByVal isLocalRequest As Boolean) As String
        If requestUrl Is Nothing OrElse isLocalRequest OrElse Not requestUrl.IsAbsoluteUri Then Return String.Empty

        Dim requestHost As String = NormalizeHost(requestUrl.DnsSafeHost)
        If Not String.Equals(requestHost, TaikunAliasHost, StringComparison.OrdinalIgnoreCase) Then Return String.Empty

        Dim builder As New UriBuilder(requestUrl)
        builder.Host = TaikunCanonicalHost
        ' Il canonical pubblico è sempre HTTPS, anche quando il proxy presenta
        ' internamente la richiesta come HTTP.
        builder.Scheme = Uri.UriSchemeHttps
        builder.Port = -1
        Return builder.Uri.AbsoluteUri
    End Function

    Private Shared Function NormalizeHost(ByVal value As String) As String
        Return Convert.ToString(value).Trim().TrimEnd("."c).ToLowerInvariant()
    End Function
End Class
