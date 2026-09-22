Option Strict On
Option Explicit On

Imports System
Imports System.Net
Imports System.Web

Public NotInheritable Class PayPalProductionSafetyPolicy
    Private Sub New()
    End Sub

    Public Shared Function IsApiCallAllowed(ByVal environmentName As String,
                                            ByVal isConfigurationComplete As Boolean,
                                            ByVal allowLive As Boolean,
                                            ByVal isLocalRequest As Boolean) As Boolean
        If Not isConfigurationComplete Then Return False

        Dim normalizedEnvironment As String = Convert.ToString(environmentName).Trim()
        If String.Equals(normalizedEnvironment, "sandbox", StringComparison.OrdinalIgnoreCase) Then
            Return isLocalRequest
        End If
        If String.Equals(normalizedEnvironment, "live", StringComparison.OrdinalIgnoreCase) Then
            Return allowLive
        End If
        Return False
    End Function

    Public Shared Function IsLocalTestRequest(ByVal context As HttpContext) As Boolean
        If context Is Nothing OrElse context.Request Is Nothing Then Return False
        Try
            Return IsLocalTestRequest(
                context.Request.IsLocal,
                context.Request.Url,
                context.Request.UserHostAddress)
        Catch
            Return False
        End Try
    End Function

    Public Shared Function IsLocalTestRequest(ByVal requestIsLocal As Boolean,
                                              ByVal requestUri As Uri,
                                              ByVal remoteAddress As String) As Boolean
        If Not requestIsLocal OrElse requestUri Is Nothing OrElse Not requestUri.IsAbsoluteUri Then Return False
        If Not IsLoopbackAddress(remoteAddress) Then Return False

        Dim host As String = Convert.ToString(requestUri.Host).Trim()
        If String.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase) Then
            Return requestUri.IsLoopback
        End If

        Return requestUri.IsLoopback AndAlso IsLoopbackAddress(host)
    End Function

    Public Shared Function IsEnvironmentFallbackAllowed(ByVal environmentName As String,
                                                        ByVal isLocalTestRequest As Boolean) As Boolean
        Return isLocalTestRequest AndAlso
               String.Equals(Convert.ToString(environmentName).Trim(),
                             "sandbox",
                             StringComparison.OrdinalIgnoreCase)
    End Function

    Private Shared Function IsLoopbackAddress(ByVal value As String) As Boolean
        Dim candidate As String = Convert.ToString(value).Trim()
        If candidate.Length >= 2 AndAlso candidate(0) = "["c AndAlso candidate(candidate.Length - 1) = "]"c Then
            candidate = candidate.Substring(1, candidate.Length - 2)
        End If

        Dim address As IPAddress = Nothing
        Return IPAddress.TryParse(candidate, address) AndAlso IPAddress.IsLoopback(address)
    End Function
End Class
