Imports System
Imports System.Configuration

Public Class PayPalCheckoutConfig
    Public Property EnvironmentName As String
    Public Property HasClientId As Boolean
    Public Property HasClientSecret As Boolean
    Public Property HasWebhookId As Boolean

    Public ReadOnly Property IsSandbox As Boolean
        Get
            Return String.Equals(EnvironmentName, "sandbox", StringComparison.OrdinalIgnoreCase)
        End Get
    End Property

    Public ReadOnly Property IsComplete As Boolean
        Get
            Return IsSandbox AndAlso HasClientId AndAlso HasClientSecret
        End Get
    End Property

    Public Shared Function Load() As PayPalCheckoutConfig
        Dim cfg As New PayPalCheckoutConfig()
        cfg.EnvironmentName = ReadSetting("PAYPAL_REST_ENVIRONMENT")
        If String.IsNullOrWhiteSpace(cfg.EnvironmentName) Then cfg.EnvironmentName = ""
        cfg.EnvironmentName = cfg.EnvironmentName.Trim()

        cfg.HasClientId = Not String.IsNullOrWhiteSpace(ReadSetting("PAYPAL_REST_CLIENT_ID"))
        cfg.HasClientSecret = Not String.IsNullOrWhiteSpace(ReadSetting("PAYPAL_REST_CLIENT_SECRET"))
        cfg.HasWebhookId = Not String.IsNullOrWhiteSpace(ReadSetting("PAYPAL_REST_WEBHOOK_ID"))

        Return cfg
    End Function

    Private Shared Function ReadSetting(ByVal key As String) As String
        If String.IsNullOrWhiteSpace(key) Then Return ""

        Try
            Dim value As String = ConfigurationManager.AppSettings(key)
            If Not String.IsNullOrWhiteSpace(value) Then Return value.Trim()
        Catch
        End Try

        Try
            Dim value As String = Environment.GetEnvironmentVariable(key)
            If Not String.IsNullOrWhiteSpace(value) Then Return value.Trim()
        Catch
        End Try

        Return ""
    End Function
End Class
