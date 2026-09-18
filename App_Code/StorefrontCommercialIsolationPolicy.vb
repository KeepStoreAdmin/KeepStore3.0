Option Strict On
Option Explicit On

Imports System
Imports System.Globalization

Public NotInheritable Class StorefrontRegistrationAssignment
    Public Property CompanyId As Integer
    Public Property InitialPriceListId As Integer
End Class

Public NotInheritable Class StorefrontCommercialIsolationPolicy
    Private Sub New()
    End Sub

    Public Shared Function ResolveSessionPriceList(ByVal primaryValue As Object,
                                                   ByVal compatibilityValue As Object) As Integer
        Dim parsed As Integer = PositiveInteger(primaryValue)
        If parsed <= 0 Then parsed = PositiveInteger(compatibilityValue)
        Return parsed
    End Function

    Public Shared Function ResolveAnonymousPriceList(ByVal companyId As Integer,
                                                     ByVal defaultPriceListId As Integer) As Integer
        If companyId <= 0 OrElse defaultPriceListId <= 0 Then Return 0
        Return defaultPriceListId
    End Function

    Public Shared Function CreateRegistrationAssignment(ByVal companyId As Integer,
                                                        ByVal initialUserPriceListId As Integer) As StorefrontRegistrationAssignment
        If companyId <= 0 OrElse initialUserPriceListId <= 0 Then Return Nothing
        Return New StorefrontRegistrationAssignment() With {
            .CompanyId = companyId,
            .InitialPriceListId = initialUserPriceListId
        }
    End Function

    Public Shared Function ResolveAuthenticatedPriceList(ByVal storefrontCompanyId As Integer,
                                                         ByVal accountCompanyId As Integer,
                                                         ByVal persistedPriceListId As Integer) As Integer
        If storefrontCompanyId <= 0 OrElse
           accountCompanyId <> storefrontCompanyId OrElse
           persistedPriceListId <= 0 Then
            Return 0
        End If
        Return persistedPriceListId
    End Function

    Public Shared Function ShouldClearAuthentication(ByVal previousCompanyId As Integer,
                                                     ByVal currentCompanyId As Integer,
                                                     ByVal loginId As Integer,
                                                     ByVal authenticatedCompanyId As Integer) As Boolean
        If previousCompanyId <> currentCompanyId Then Return True
        If loginId <= 0 AndAlso authenticatedCompanyId <= 0 Then Return False
        If previousCompanyId <= 0 OrElse currentCompanyId <= 0 Then Return True
        Return authenticatedCompanyId > 0 AndAlso authenticatedCompanyId <> currentCompanyId
    End Function

    Public Shared Function BuildCommercialScope(ByVal databaseScopeKey As String,
                                                ByVal companyId As Integer,
                                                ByVal priceListId As Integer,
                                                ByVal isAuthenticated As Boolean,
                                                ByVal userId As Integer) As String
        Dim databaseScope As String = Convert.ToString(databaseScopeKey).Trim().ToLowerInvariant()
        If String.IsNullOrEmpty(databaseScope) Then databaseScope = "database-scope-unavailable"
        Return databaseScope & ":" &
               companyId.ToString(CultureInfo.InvariantCulture) & ":" &
               priceListId.ToString(CultureInfo.InvariantCulture) & ":" &
               If(isAuthenticated, "1", "0") & ":" &
               If(userId > 0, userId, 0).ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function PositiveInteger(ByVal value As Object) As Integer
        Dim parsed As Integer = 0
        Integer.TryParse(Convert.ToString(value), parsed)
        Return If(parsed > 0, parsed, 0)
    End Function
End Class
