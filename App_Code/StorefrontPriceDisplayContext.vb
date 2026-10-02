Option Strict On
Option Explicit On

Imports System

Public Enum StorefrontVatDisplayMode
    VatExcluded = 1
    VatIncluded = 2
End Enum

' Browsing preference only. Product VAT, reverse charge and carrier VAT remain
' distinct commercial facts; this object never computes a tax or a price.
Public NotInheritable Class StorefrontPriceDisplayContext
    Private ReadOnly _companyId As Integer
    Private ReadOnly _priceListId As Integer
    Private ReadOnly _isAuthenticated As Boolean
    Private ReadOnly _displayMode As StorefrontVatDisplayMode
    Private ReadOnly _vatOverride As Nullable(Of Decimal)
    Private ReadOnly _exemptionId As Integer
    Private ReadOnly _exemptionDescription As String
    Private ReadOnly _reverseChargeEnabled As Boolean

    Public Sub New(ByVal companyId As Integer,
                   ByVal priceListId As Integer,
                   ByVal isAuthenticated As Boolean,
                   ByVal displayMode As StorefrontVatDisplayMode,
                   ByVal vatOverride As Nullable(Of Decimal),
                   ByVal exemptionId As Integer,
                   ByVal exemptionDescription As String,
                   ByVal reverseChargeEnabled As Boolean)
        If companyId <= 0 Then Throw New ArgumentOutOfRangeException("companyId")
        If priceListId <= 0 Then Throw New ArgumentOutOfRangeException("priceListId")
        If displayMode <> StorefrontVatDisplayMode.VatExcluded AndAlso
           displayMode <> StorefrontVatDisplayMode.VatIncluded Then
            Throw New ArgumentOutOfRangeException("displayMode")
        End If
        If vatOverride.HasValue AndAlso vatOverride.Value < 0D Then
            Throw New ArgumentOutOfRangeException("vatOverride")
        End If
        _companyId = companyId
        _priceListId = priceListId
        _isAuthenticated = isAuthenticated
        _displayMode = displayMode
        _vatOverride = If(isAuthenticated, vatOverride, Nothing)
        _exemptionId = If(isAuthenticated, exemptionId, -1)
        _exemptionDescription = If(isAuthenticated, If(exemptionDescription, String.Empty), String.Empty)
        _reverseChargeEnabled = isAuthenticated AndAlso reverseChargeEnabled
    End Sub

    Public ReadOnly Property CompanyId As Integer
        Get
            Return _companyId
        End Get
    End Property

    Public ReadOnly Property PriceListId As Integer
        Get
            Return _priceListId
        End Get
    End Property

    Public ReadOnly Property IsAuthenticated As Boolean
        Get
            Return _isAuthenticated
        End Get
    End Property

    Public ReadOnly Property DisplayMode As StorefrontVatDisplayMode
        Get
            Return _displayMode
        End Get
    End Property

    Public ReadOnly Property VatOverride As Nullable(Of Decimal)
        Get
            Return _vatOverride
        End Get
    End Property

    Public ReadOnly Property ExemptionId As Integer
        Get
            Return _exemptionId
        End Get
    End Property

    Public ReadOnly Property ExemptionDescription As String
        Get
            Return _exemptionDescription
        End Get
    End Property

    Public ReadOnly Property ReverseChargeEnabled As Boolean
        Get
            Return _reverseChargeEnabled
        End Get
    End Property

    Public ReadOnly Property IsVatIncluded As Boolean
        Get
            Return _displayMode = StorefrontVatDisplayMode.VatIncluded
        End Get
    End Property

    Public ReadOnly Property IsVatExcluded As Boolean
        Get
            Return _displayMode = StorefrontVatDisplayMode.VatExcluded
        End Get
    End Property

    Public ReadOnly Property DisplayLabel As String
        Get
            Return If(IsVatIncluded, "Prezzi visualizzati IVA inclusa", "Prezzi visualizzati IVA esclusa")
        End Get
    End Property

    ' A missing/non-positive selected product price stays unavailable. Never
    ' substitute the opposite VAT mode or reconstruct gross from an override.
    Public Function SelectPrice(ByVal netValue As Nullable(Of Decimal),
                                ByVal grossValue As Nullable(Of Decimal)) As Nullable(Of Decimal)
        Dim selected As Nullable(Of Decimal) = If(IsVatIncluded, grossValue, netValue)
        If Not selected.HasValue OrElse selected.Value <= 0D Then Return Nothing
        Return selected
    End Function

    Public Function SelectPromoPrice(ByVal netValue As Nullable(Of Decimal),
                                     ByVal grossValue As Nullable(Of Decimal)) As Nullable(Of Decimal)
        Return SelectPrice(netValue, grossValue)
    End Function
End Class
