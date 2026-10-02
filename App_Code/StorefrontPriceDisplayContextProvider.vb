Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Web

Public NotInheritable Class StorefrontPriceDisplayContextProvider
    Private Const ContextKey As String = "KeepStore.PriceDisplay.Context"
    Private Const TenantKey As String = "KeepStore.PriceDisplay.ValidatedTenant"

    Private NotInheritable Class TenantDefaults
        Public ReadOnly CompanyId As Integer
        Public ReadOnly PriceListId As Integer
        Public ReadOnly DisplayMode As StorefrontVatDisplayMode

        Public Sub New(ByVal companyId As Integer, ByVal priceListId As Integer,
                       ByVal displayMode As StorefrontVatDisplayMode)
            Me.CompanyId = companyId
            Me.PriceListId = priceListId
            Me.DisplayMode = displayMode
        End Sub
    End Class

    Private Sub New()
    End Sub

    ' Called by the master with its host-validated tenant configuration only.
    ' No database access here and no context object is stored in Session.
    Public Shared Sub SetTenantDefaults(ByVal context As HttpContext,
                                        ByVal companyId As Integer,
                                        ByVal defaultPriceListId As Integer,
                                        ByVal tenantMode As Object)
        If context Is Nothing Then Throw New ArgumentNullException("context")
        If companyId <= 0 Then Throw New ArgumentOutOfRangeException("companyId")
        If defaultPriceListId <= 0 Then Throw New ArgumentOutOfRangeException("defaultPriceListId")
        context.Items(TenantKey) = New TenantDefaults(companyId, defaultPriceListId,
            NormalizeTenantDisplayMode(tenantMode, context))
        Invalidate(context)
    End Sub

    Public Shared Sub Invalidate(ByVal context As HttpContext)
        If context IsNot Nothing Then context.Items.Remove(ContextKey)
    End Sub

    Public Shared Function GetCurrent(ByVal context As HttpContext) As StorefrontPriceDisplayContext
        If context Is Nothing OrElse context.Session Is Nothing Then Return Nothing
        Dim cached As StorefrontPriceDisplayContext = TryCast(context.Items(ContextKey), StorefrontPriceDisplayContext)
        If cached IsNot Nothing Then Return cached

        Dim tenant As TenantDefaults = TryCast(context.Items(TenantKey), TenantDefaults)
        If tenant Is Nothing OrElse
           StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session("AziendaID")) <> tenant.CompanyId Then Return Nothing

        Dim priceListId As Integer = StorefrontCommercialIsolationPolicy.ResolveSessionPriceList(
            context.Session("Listino"), context.Session("listino"))
        If priceListId <= 0 Then Return Nothing
        Dim loginId As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session("LoginId"))
        If loginId <= 0 Then loginId = StorefrontCommercialIsolationPolicy.PositiveInteger(context.Session("LoginID"))
        Dim authenticatedCompanyId As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(
            context.Session("AuthenticatedAziendaID"))
        Dim isAuthenticated As Boolean = loginId > 0 AndAlso authenticatedCompanyId = tenant.CompanyId
        ' Inconsistent authentication is not silently converted into another
        ' owner's price scope. The master must clear and restore it first.
        If Not isAuthenticated AndAlso (loginId > 0 OrElse authenticatedCompanyId > 0 OrElse
                                        priceListId <> tenant.PriceListId) Then Return Nothing

        Dim mode As StorefrontVatDisplayMode = tenant.DisplayMode
        Dim vatOverride As Nullable(Of Decimal) = Nothing
        Dim exemptionId As Integer = -1
        Dim exemptionDescription As String = String.Empty
        Dim reverseChargeEnabled As Boolean = False
        If isAuthenticated Then
            mode = ResolveDisplayMode(context.Session("IvaTipo"), tenant.DisplayMode)
            vatOverride = NormalizeVatOverride(context.Session("Iva_Utente"))
            exemptionId = NormalizeExemptionId(context.Session("IdEsenzioneIva"))
            exemptionDescription = Convert.ToString(context.Session("DescrizioneEsenzioneIva"), CultureInfo.InvariantCulture)
            reverseChargeEnabled = ParseInteger(context.Session("AbilitatoIvaReverseCharge"), 0) = 1
        End If
        Dim result As New StorefrontPriceDisplayContext(tenant.CompanyId, priceListId, isAuthenticated,
            mode, vatOverride, exemptionId, exemptionDescription, reverseChargeEnabled)
        context.Items(ContextKey) = result
        Return result
    End Function

    Public Shared Function NormalizeTenantDisplayMode(ByVal value As Object,
                                                       Optional ByVal context As HttpContext = Nothing) As StorefrontVatDisplayMode
        Dim parsed As Integer = ParseInteger(value, 0)
        If parsed = 1 Then Return StorefrontVatDisplayMode.VatExcluded
        If parsed = 2 Then Return StorefrontVatDisplayMode.VatIncluded
        KeepStoreLog.Error("storefront-price-display", "Invalid tenant display mode; VAT-included safe default applied.", Nothing, context)
        Return StorefrontVatDisplayMode.VatIncluded
    End Function

    Public Shared Function ResolveDisplayMode(ByVal accountMode As Object,
                                              ByVal tenantMode As StorefrontVatDisplayMode) As StorefrontVatDisplayMode
        Dim parsed As Integer = ParseInteger(accountMode, 0)
        If parsed = 1 Then Return StorefrontVatDisplayMode.VatExcluded
        If parsed = 2 Then Return StorefrontVatDisplayMode.VatIncluded
        If tenantMode = StorefrontVatDisplayMode.VatExcluded Then Return tenantMode
        Return StorefrontVatDisplayMode.VatIncluded
    End Function

    ' Legacy -1 is absence; 0 and fractional percentages remain real overrides.
    ' Strings accept a decimal comma or point, never ambiguous group separators.
    Public Shared Function NormalizeVatOverride(ByVal value As Object) As Nullable(Of Decimal)
        If value Is Nothing OrElse Convert.IsDBNull(value) Then Return Nothing
        Dim parsed As Decimal
        If TypeOf value Is String Then
            Dim text As String = DirectCast(value, String).Trim().Replace(",", ".")
            If Not Decimal.TryParse(text, NumberStyles.AllowLeadingSign Or NumberStyles.AllowDecimalPoint,
                                    CultureInfo.InvariantCulture, parsed) Then Return Nothing
        Else
            Select Case Type.GetTypeCode(value.GetType())
                Case TypeCode.Decimal, TypeCode.Double, TypeCode.Single, TypeCode.Byte, TypeCode.SByte,
                     TypeCode.Int16, TypeCode.UInt16, TypeCode.Int32, TypeCode.UInt32, TypeCode.Int64, TypeCode.UInt64
                    Try
                        parsed = Convert.ToDecimal(value, CultureInfo.InvariantCulture)
                    Catch ex As Exception When TypeOf ex Is OverflowException OrElse TypeOf ex Is InvalidCastException
                        Return Nothing
                    End Try
                Case Else
                    Return Nothing
            End Select
        End If
        If parsed < 0D Then Return Nothing
        Return parsed
    End Function

    Public Shared Function NormalizeExemptionId(ByVal value As Object) As Integer
        Dim parsed As Integer = ParseInteger(value, -1)
        Return If(parsed >= 0, parsed, -1)
    End Function

    Private Shared Function ParseInteger(ByVal value As Object, ByVal fallback As Integer) As Integer
        If value Is Nothing OrElse Convert.IsDBNull(value) Then Return fallback
        Dim parsed As Integer
        If Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture),
                            NumberStyles.Integer, CultureInfo.InvariantCulture, parsed) Then Return parsed
        Return fallback
    End Function
End Class
