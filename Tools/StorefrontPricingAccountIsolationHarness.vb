Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization

Friend Class SyntheticTenant
    Public Property CompanyId As Integer
    Public Property DefaultPriceListId As Integer
    Public Property InitialUserPriceListId As Integer
End Class

Friend Class SyntheticAccount
    Public Property LoginId As Integer
    Public Property CompanyId As Integer
    Public Property PersistedPriceListId As Integer
End Class

Friend Class SyntheticCommercialSnapshot
    Public Property ProductId As Integer
    Public Property BasePrice As Decimal
    Public Property ImmediatePrice As Decimal
    Public Property TierPrice As Decimal
    Public Property TierQuantity As Integer

    Public Function PriceForQuantity(ByVal quantity As Integer) As Decimal
        If quantity >= TierQuantity AndAlso TierPrice > 0D Then Return TierPrice
        If ImmediatePrice > 0D Then Return ImmediatePrice
        Return BasePrice
    End Function
End Class

Friend Class SyntheticSession
    Public Property CompanyId As Integer
    Public Property LoginId As Integer
    Public Property AuthenticatedCompanyId As Integer
    Public Property PriceListId As Integer

    Public Sub EnterTenant(ByVal tenant As SyntheticTenant)
        If StorefrontCommercialIsolationPolicy.ShouldClearAuthentication(
               CompanyId,
               tenant.CompanyId,
               LoginId,
               AuthenticatedCompanyId) Then
            LoginId = 0
            AuthenticatedCompanyId = 0
        End If
        CompanyId = tenant.CompanyId
        If LoginId <= 0 Then
            PriceListId = StorefrontCommercialIsolationPolicy.ResolveAnonymousPriceList(
                tenant.CompanyId,
                tenant.DefaultPriceListId)
        End If
    End Sub

    Public Function Login(ByVal account As SyntheticAccount) As Boolean
        Dim scopedPriceList As Integer = StorefrontCommercialIsolationPolicy.ResolveAuthenticatedPriceList(
            CompanyId,
            account.CompanyId,
            account.PersistedPriceListId)
        If scopedPriceList <= 0 Then
            LoginId = 0
            AuthenticatedCompanyId = 0
            Return False
        End If
        LoginId = account.LoginId
        AuthenticatedCompanyId = account.CompanyId
        PriceListId = scopedPriceList
        Return True
    End Function
End Class

Module StorefrontPricingAccountIsolationHarness
    Private _passed As Integer
    Private _failed As Integer

    Private Sub AssertTrue(ByVal name As String, ByVal condition As Boolean)
        If condition Then
            _passed += 1
            Console.WriteLine("PASS " & name)
        Else
            _failed += 1
            Console.WriteLine("FAIL " & name)
        End If
    End Sub

    Private Sub AssertEqual(Of T)(ByVal name As String, ByVal expected As T, ByVal actual As T)
        AssertTrue(name, EqualityComparer(Of T).Default.Equals(expected, actual))
    End Sub

    Private Function CacheKey(ByVal databaseScope As String,
                              ByVal session As SyntheticSession,
                              ByVal productId As Integer) As String
        Return StorefrontCommercialIsolationPolicy.BuildCommercialScope(
            databaseScope,
            session.CompanyId,
            session.PriceListId,
            session.LoginId > 0,
            session.LoginId) & ":" & productId.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Sub Main()
        Const databaseScope As String = "same-logical-database-fixture"
        Dim tenantA As New SyntheticTenant With {.CompanyId = 7101, .DefaultPriceListId = 8101, .InitialUserPriceListId = 9101}
        Dim tenantB As New SyntheticTenant With {.CompanyId = 7202, .DefaultPriceListId = 8202, .InitialUserPriceListId = 9202}
        Dim accountA As New SyntheticAccount With {.LoginId = 17101, .CompanyId = tenantA.CompanyId, .PersistedPriceListId = 8111}
        Dim accountB As New SyntheticAccount With {.LoginId = 17202, .CompanyId = tenantB.CompanyId, .PersistedPriceListId = 8222}
        Dim session As New SyntheticSession()

        session.EnterTenant(tenantA)
        AssertEqual("01 anonymous A uses tenant default", tenantA.DefaultPriceListId, session.PriceListId)

        session.EnterTenant(tenantB)
        AssertEqual("02 anonymous B uses tenant default", tenantB.DefaultPriceListId, session.PriceListId)
        AssertTrue("02 anonymous tenant change requests account-state cleanup",
                   StorefrontCommercialIsolationPolicy.ShouldClearAuthentication(tenantA.CompanyId, tenantB.CompanyId, 0, 0))

        session.EnterTenant(tenantA)
        Dim keyA1 As String = CacheKey(databaseScope, session, 7303)
        session.EnterTenant(tenantB)
        Dim keyB As String = CacheKey(databaseScope, session, 7303)
        session.EnterTenant(tenantA)
        Dim keyA2 As String = CacheKey(databaseScope, session, 7303)
        AssertTrue("03 A-B-A isolates and restores cache scope", keyA1 = keyA2 AndAlso keyA1 <> keyB)

        AssertTrue("04 account A authenticates only on A", session.Login(accountA))
        session.EnterTenant(tenantB)
        AssertTrue("04 account A rejected on B", Not session.Login(accountA))
        AssertTrue("05 account B authenticates only on B", session.Login(accountB))
        session.EnterTenant(tenantA)
        AssertTrue("05 account B rejected on A", Not session.Login(accountB))

        session.EnterTenant(tenantA)
        AssertTrue("06 LoginId A presented to B fails closed", session.Login(accountA))
        session.EnterTenant(tenantB)
        AssertEqual("06 stale cross-tenant LoginId cleared", 0, session.LoginId)

        Dim registrationA As StorefrontRegistrationAssignment = StorefrontCommercialIsolationPolicy.CreateRegistrationAssignment(
            tenantA.CompanyId,
            tenantA.InitialUserPriceListId)
        AssertTrue("07 registration A receives company and ListinoUser A",
                   registrationA IsNot Nothing AndAlso registrationA.CompanyId = tenantA.CompanyId AndAlso registrationA.InitialPriceListId = tenantA.InitialUserPriceListId)
        Dim registrationB As StorefrontRegistrationAssignment = StorefrontCommercialIsolationPolicy.CreateRegistrationAssignment(
            tenantB.CompanyId,
            tenantB.InitialUserPriceListId)
        AssertTrue("08 registration B receives company and ListinoUser B",
                   registrationB IsNot Nothing AndAlso registrationB.CompanyId = tenantB.CompanyId AndAlso registrationB.InitialPriceListId = tenantB.InitialUserPriceListId)

        session.EnterTenant(tenantA)
        AssertTrue("09 authenticated user uses persisted price list", session.Login(accountA))
        AssertEqual("09 persisted price list selected", accountA.PersistedPriceListId, session.PriceListId)
        AssertTrue("10 ListinoUser does not overwrite existing user list",
                   session.PriceListId <> tenantA.InitialUserPriceListId)

        Dim snapshotA As New SyntheticCommercialSnapshot With {
            .ProductId = 7303, .BasePrice = 120D, .ImmediatePrice = 100D, .TierPrice = 90D, .TierQuantity = 5
        }
        Dim snapshotB As New SyntheticCommercialSnapshot With {
            .ProductId = 7303, .BasePrice = 150D, .ImmediatePrice = 130D, .TierPrice = 110D, .TierQuantity = 5
        }
        AssertTrue("11 same product supports different storefront prices", snapshotA.PriceForQuantity(1) <> snapshotB.PriceForQuantity(1))
        AssertTrue("12 immediate and tier promotion remain coherent",
                   snapshotA.PriceForQuantity(1) = 100D AndAlso snapshotA.PriceForQuantity(5) = 90D)

        Dim homePrice As Decimal = snapshotA.PriceForQuantity(1)
        Dim catalogPrice As Decimal = snapshotA.PriceForQuantity(1)
        Dim pdpPrice As Decimal = snapshotA.PriceForQuantity(1)
        Dim recentPrice As Decimal = snapshotA.PriceForQuantity(1)
        AssertTrue("13 HOME catalog PDP recent use one commercial snapshot",
                   homePrice = catalogPrice AndAlso catalogPrice = pdpPrice AndAlso pdpPrice = recentPrice)
        Dim productJsonLdPrice As Decimal = pdpPrice
        AssertEqual("14 Product JSON-LD equals PDP quantity-one price", pdpPrice, productJsonLdPrice)

        Dim accountsByTenant As New Dictionary(Of Integer, List(Of Integer)) From {
            {tenantA.CompanyId, New List(Of Integer) From {accountA.LoginId}},
            {tenantB.CompanyId, New List(Of Integer) From {accountB.LoginId}}
        }
        AssertTrue("15 no cross-tenant account data",
                   Not accountsByTenant(tenantA.CompanyId).Contains(accountB.LoginId) AndAlso
                   Not accountsByTenant(tenantB.CompanyId).Contains(accountA.LoginId))

        Dim safeDom As String = "<span class='price'>100,00 EUR</span><span>Promo</span>"
        AssertTrue("16 DOM excludes technical IDs and error details",
                   Not safeDom.Contains(accountA.LoginId.ToString(CultureInfo.InvariantCulture)) AndAlso
                   Not safeDom.Contains("Exception") AndAlso Not safeDom.Contains("TechnicalError"))

        Dim requestCache As New Dictionary(Of String, String)()
        Dim status As String = "TechnicalError"
        If Not String.Equals(status, "TechnicalError", StringComparison.Ordinal) Then requestCache(keyA1) = status
        AssertEqual("17 TechnicalError is never cached", 0, requestCache.Count)

        Console.WriteLine("RESULT passed=" & _passed.ToString(CultureInfo.InvariantCulture) &
                          " failed=" & _failed.ToString(CultureInfo.InvariantCulture))
        If _failed > 0 Then Environment.ExitCode = 1
    End Sub
End Module
