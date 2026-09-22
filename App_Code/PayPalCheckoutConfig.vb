Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Text.RegularExpressions

Public Class PayPalCheckoutConfig
    Public Const LiveApiBaseUrl As String = "https://api-m.paypal.com"

    Public Property AccountId As Integer
    Public Property CompanyConfigId As Integer
    Public Property AziendeId As Integer
    Public Property PagamentiTipoId As Integer
    Public Property CredentialKey As String
    Public Property MerchantId As String
    Public Property PayeeEmail As String
    Public Property BrandName As String
    Public Property CurrencyCode As String
    Public Property ClientId As String
    Public Property ClientSecret As String
    Public Property WebhookId As String
    Public Property AccountActive As Boolean
    Public Property CompanyActive As Boolean

    Public ReadOnly Property IsConfigured As Boolean
        Get
            Return AccountId > 0 AndAlso CompanyConfigId > 0 AndAlso AziendeId > 0 AndAlso
                   PagamentiTipoId > 0 AndAlso AccountActive AndAlso CompanyActive AndAlso
                   IsCredentialKeyValid(CredentialKey) AndAlso
                   Not String.IsNullOrWhiteSpace(MerchantId) AndAlso
                   IsEmailValid(PayeeEmail) AndAlso
                   Not String.IsNullOrWhiteSpace(BrandName) AndAlso
                   IsCurrencyValid(CurrencyCode) AndAlso
                   Not String.IsNullOrWhiteSpace(ClientId) AndAlso
                   Not String.IsNullOrWhiteSpace(ClientSecret)
        End Get
    End Property

    Public ReadOnly Property IsWebhookConfigured As Boolean
        Get
            Return IsConfigured AndAlso Not String.IsNullOrWhiteSpace(WebhookId)
        End Get
    End Property

    Public Shared Function LoadForDocument(ByVal documentId As Integer) As PayPalCheckoutConfig
        Return PayPalCheckoutRepository.LoadConfigForDocument(documentId)
    End Function

    Public Shared Function LoadForCompanyPayment(ByVal companyId As Integer,
                                                 ByVal paymentMethodId As Integer) As PayPalCheckoutConfig
        Return PayPalCheckoutRepository.LoadConfigForCompanyPayment(companyId, paymentMethodId)
    End Function

    Public Shared Function HydrateServerCredentials(ByVal cfg As PayPalCheckoutConfig) As PayPalCheckoutConfig
        If cfg Is Nothing OrElse Not IsCredentialKeyValid(cfg.CredentialKey) Then Return Nothing
        Dim prefix As String = cfg.CredentialKey.Trim().ToUpperInvariant()
        cfg.ClientId = ReadServerSetting(prefix & "_CLIENT_ID")
        cfg.ClientSecret = ReadServerSetting(prefix & "_CLIENT_SECRET")
        cfg.WebhookId = ReadServerSetting(prefix & "_WEBHOOK_ID")
        Return cfg
    End Function

    Public Shared Function IsCredentialKeyValid(ByVal value As String) As Boolean
        Return Regex.IsMatch(Convert.ToString(value).Trim(), "^[A-Z][A-Z0-9_]{2,63}$", RegexOptions.CultureInvariant)
    End Function

    Public Shared Function IsCurrencyValid(ByVal value As String) As Boolean
        Return Regex.IsMatch(Convert.ToString(value).Trim(), "^[A-Z]{3}$", RegexOptions.CultureInvariant)
    End Function

    Public Shared Function IsEmailValid(ByVal value As String) As Boolean
        Dim candidate As String = Convert.ToString(value).Trim()
        Return candidate.Length <= 254 AndAlso Regex.IsMatch(candidate, "^[^\s@]+@[^\s@]+\.[^\s@]+$", RegexOptions.CultureInvariant)
    End Function

    Private Shared Function ReadServerSetting(ByVal key As String) As String
        If String.IsNullOrWhiteSpace(key) Then Return String.Empty
        Try
            Dim value As String = Environment.GetEnvironmentVariable(key, EnvironmentVariableTarget.Process)
            If Not String.IsNullOrWhiteSpace(value) Then Return value.Trim()
        Catch
        End Try
        Try
            Dim value As String = ConfigurationManager.AppSettings(key)
            If Not String.IsNullOrWhiteSpace(value) Then Return value.Trim()
        Catch
        End Try
        Return String.Empty
    End Function
End Class
