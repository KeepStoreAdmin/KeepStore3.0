Imports System
Imports System.Configuration

Public Class PayPalCheckoutConfig
    Public Property ConfigId As Integer
    Public Property AziendeId As Integer
    Public Property PagamentiTipoId As Integer
    Public Property Source As String
    Public Property EnvironmentName As String
    Public Property ApiUsername As String
    Public Property ApiPassword As String
    Public Property ApiSignature As String
    Public Property BusinessAccount As String
    Public Property Version As String
    Public Property CurrencyCode As String
    Public Property AllowLive As Boolean

    Public ReadOnly Property IsSandbox As Boolean
        Get
            Return String.Equals(EnvironmentName, "sandbox", StringComparison.OrdinalIgnoreCase)
        End Get
    End Property

    Public ReadOnly Property IsLive As Boolean
        Get
            Return String.Equals(EnvironmentName, "live", StringComparison.OrdinalIgnoreCase)
        End Get
    End Property

    Public ReadOnly Property IsExpressConfigured As Boolean
        Get
            Return Not String.IsNullOrWhiteSpace(ApiUsername) AndAlso
                   Not String.IsNullOrWhiteSpace(ApiPassword) AndAlso
                   Not String.IsNullOrWhiteSpace(ApiSignature) AndAlso
                   Not String.IsNullOrWhiteSpace(CurrencyCode) AndAlso
                   (IsSandbox OrElse IsLive)
        End Get
    End Property

    Public ReadOnly Property CanCallApi As Boolean
        Get
            If Not IsExpressConfigured Then Return False
            If IsLive AndAlso Not AllowLive Then Return False
            Return True
        End Get
    End Property

    Public ReadOnly Property ApiEndpoint As String
        Get
            If IsLive Then Return "https://api-3t.paypal.com/nvp"
            Return "https://api-3t.sandbox.paypal.com/nvp"
        End Get
    End Property

    Public ReadOnly Property RedirectBaseUrl As String
        Get
            If IsLive Then Return "https://www.paypal.com/cgi-bin/webscr"
            Return "https://www.sandbox.paypal.com/cgi-bin/webscr"
        End Get
    End Property

    Public Shared Function Load() As PayPalCheckoutConfig
        Dim cfg As New PayPalCheckoutConfig()
        cfg.Source = "environment"
        cfg.EnvironmentName = ReadSetting("PAYPAL_EXPRESS_ENVIRONMENT")
        If String.IsNullOrWhiteSpace(cfg.EnvironmentName) Then cfg.EnvironmentName = "sandbox"
        cfg.EnvironmentName = cfg.EnvironmentName.Trim()

        cfg.ApiUsername = ReadSetting("PAYPAL_EXPRESS_API_USERNAME")
        cfg.ApiPassword = ReadSetting("PAYPAL_EXPRESS_API_PASSWORD")
        cfg.ApiSignature = ReadSetting("PAYPAL_EXPRESS_API_SIGNATURE")
        cfg.BusinessAccount = ReadSetting("PAYPAL_EXPRESS_BUSINESS_ACCOUNT")

        cfg.Version = ReadSetting("PAYPAL_EXPRESS_VERSION")
        If String.IsNullOrWhiteSpace(cfg.Version) Then cfg.Version = "204.0"

        cfg.CurrencyCode = ReadSetting("PAYPAL_EXPRESS_CURRENCY")
        If String.IsNullOrWhiteSpace(cfg.CurrencyCode) Then cfg.CurrencyCode = "EUR"
        cfg.CurrencyCode = cfg.CurrencyCode.Trim().ToUpperInvariant()

        cfg.AllowLive = String.Equals(ReadSetting("PAYPAL_EXPRESS_ALLOW_LIVE"), "true", StringComparison.OrdinalIgnoreCase)

        Return cfg
    End Function

    Public Shared Function LoadForDocument(ByVal documentId As Integer) As PayPalCheckoutConfig
        If documentId > 0 Then
            Dim dbConfig As PayPalCheckoutConfig = PayPalExpressRepository.LoadConfigForDocument(documentId)
            If dbConfig IsNot Nothing Then Return dbConfig
        End If

        Return Load()
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
