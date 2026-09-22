Option Strict On
Option Explicit On

Imports System
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
            Return context.Request.IsLocal
        Catch
            Return False
        End Try
    End Function
End Class
