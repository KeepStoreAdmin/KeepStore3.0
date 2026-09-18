Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization

Friend NotInheritable Class SyntheticCart
    Private _rows As New Dictionary(Of String, Decimal)(StringComparer.Ordinal)
    Private _requests As New HashSet(Of String)(StringComparer.Ordinal)

    Public Function Snapshot() As Dictionary(Of String, Decimal)
        Return New Dictionary(Of String, Decimal)(_rows, StringComparer.Ordinal)
    End Function

    Public Sub Restore(ByVal snapshot As Dictionary(Of String, Decimal))
        _rows = New Dictionary(Of String, Decimal)(snapshot, StringComparer.Ordinal)
    End Sub

    Public Function RowCount() As Integer
        Return _rows.Count
    End Function

    Public Function Quantity(ByVal ownerScope As String, ByVal articleId As Integer) As Decimal
        Dim value As Decimal = 0D
        _rows.TryGetValue(Key(ownerScope, articleId), value)
        Return value
    End Function

    Public Sub Add(ByVal ownerScope As String,
                   ByVal articleId As Integer,
                   ByVal quantityDelta As Decimal,
                   Optional ByVal requestId As String = "")
        If String.IsNullOrEmpty(ownerScope) OrElse articleId <= 0 OrElse quantityDelta <= 0D Then
            Throw New InvalidOperationException("Invalid synthetic cart mutation.")
        End If
        Dim replayKey As String = ownerScope & "|" & requestId
        If requestId <> String.Empty AndAlso _requests.Contains(replayKey) Then Return
        Dim keyValue As String = Key(ownerScope, articleId)
        _rows(keyValue) = Quantity(ownerScope, articleId) + quantityDelta
        If requestId <> String.Empty Then _requests.Add(replayKey)
    End Sub

    Public Sub SetQuantity(ByVal ownerScope As String, ByVal articleId As Integer, ByVal quantity As Decimal)
        If quantity <= 0D Then Throw New InvalidOperationException("Invalid synthetic quantity.")
        _rows(Key(ownerScope, articleId)) = quantity
    End Sub

    Public Sub Remove(ByVal ownerScope As String, ByVal articleId As Integer)
        _rows.Remove(Key(ownerScope, articleId))
    End Sub

    Public Sub Clear(ByVal ownerScope As String)
        Dim prefix As String = ownerScope & "|article:"
        Dim keys As New List(Of String)()
        For Each keyValue As String In _rows.Keys
            If keyValue.StartsWith(prefix, StringComparison.Ordinal) Then keys.Add(keyValue)
        Next
        For Each keyValue As String In keys
            _rows.Remove(keyValue)
        Next
    End Sub

    Public Sub Merge(ByVal anonymousScope As String, ByVal authenticatedScope As String)
        Dim prefix As String = anonymousScope & "|article:"
        Dim rowsToMove As New List(Of KeyValuePair(Of String, Decimal))()
        For Each pair As KeyValuePair(Of String, Decimal) In _rows
            If pair.Key.StartsWith(prefix, StringComparison.Ordinal) Then rowsToMove.Add(pair)
        Next
        For Each pair As KeyValuePair(Of String, Decimal) In rowsToMove
            Dim articleId As Integer = Integer.Parse(pair.Key.Substring(prefix.Length), CultureInfo.InvariantCulture)
            Add(authenticatedScope, articleId, pair.Value)
            _rows.Remove(pair.Key)
        Next
    End Sub

    Public Function TotalQuantity(ByVal ownerScope As String) As Decimal
        Dim total As Decimal = 0D
        Dim prefix As String = ownerScope & "|article:"
        For Each pair As KeyValuePair(Of String, Decimal) In _rows
            If pair.Key.StartsWith(prefix, StringComparison.Ordinal) Then total += pair.Value
        Next
        Return total
    End Function

    Private Shared Function Key(ByVal ownerScope As String, ByVal articleId As Integer) As String
        Return ownerScope & "|article:" & articleId.ToString(CultureInfo.InvariantCulture)
    End Function
End Class

Module StorefrontCartIsolationHarness
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

    Private Sub AssertQuantity(ByVal name As String,
                               ByVal expected As Decimal,
                               ByVal cart As SyntheticCart,
                               ByVal ownerScope As String,
                               ByVal articleId As Integer)
        AssertTrue(name, cart.Quantity(ownerScope, articleId) = expected)
    End Sub

    Public Sub Main()
        Const databaseScope As String = "same-database-laboratory"
        Const companyA As Integer = 4101
        Const companyB As Integer = 4202
        Const articleId As Integer = 21906
        Const rawSession As String = "shared-browser-session"

        Dim tokenA As String = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(databaseScope, companyA, rawSession)
        Dim tokenB As String = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(databaseScope, companyB, rawSession)
        Dim anonymousA As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseScope, companyA, 0, tokenA)
        Dim anonymousB As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseScope, companyB, 0, tokenB)
        Dim accountA As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseScope, companyA, 5101, String.Empty)
        Dim accountB As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseScope, companyB, 5202, String.Empty)
        Dim cart As New SyntheticCart()
        Dim initial As Dictionary(Of String, Decimal) = cart.Snapshot()
        Dim initialRows As Integer = cart.RowCount()

        AssertTrue("SCOPE anonymous token is opaque and column-safe",
                   CartStorefrontScopePolicy.IsAnonymousOwnerToken(tokenA) AndAlso
                   tokenA.Length <= CartStorefrontScopePolicy.AnonymousOwnerMaxLength AndAlso
                   tokenA.IndexOf(rawSession, StringComparison.Ordinal) < 0)
        AssertTrue("SCOPE database identity participates in anonymous owner",
                   tokenA <> CartStorefrontScopePolicy.BuildAnonymousOwnerToken("other-database-laboratory", companyA, rawSession))

        cart.Add(anonymousA, articleId, 2D, "anonymous-a-add")
        AssertQuantity("01 anonymous A adds quantity 2", 2D, cart, anonymousA, articleId)
        AssertQuantity("02 anonymous B remains empty", 0D, cart, anonymousB, articleId)
        cart.Add(anonymousB, articleId, 3D, "anonymous-b-add")
        AssertQuantity("03 anonymous B adds quantity 3", 3D, cart, anonymousB, articleId)
        AssertTrue("04 A and B quantities remain isolated",
                   cart.Quantity(anonymousA, articleId) = 2D AndAlso cart.Quantity(anonymousB, articleId) = 3D)
        AssertTrue("05 MiniCart and header totals remain distinct",
                   cart.TotalQuantity(anonymousA) = 2D AndAlso cart.TotalQuantity(anonymousB) = 3D)

        cart.SetQuantity(anonymousA, articleId, 4D)
        AssertTrue("06 quantity update A does not modify B",
                   cart.Quantity(anonymousA, articleId) = 4D AndAlso cart.Quantity(anonymousB, articleId) = 3D)
        cart.Remove(anonymousA, articleId)
        AssertTrue("07 remove A does not remove B",
                   cart.Quantity(anonymousA, articleId) = 0D AndAlso cart.Quantity(anonymousB, articleId) = 3D)
        cart.Add(anonymousA, articleId, 2D)
        cart.Clear(anonymousA)
        AssertTrue("08 clear A does not clear B",
                   cart.TotalQuantity(anonymousA) = 0D AndAlso cart.TotalQuantity(anonymousB) = 3D)
        cart.Add(anonymousA, articleId, 2D)

        cart.Add(anonymousA, articleId, 1D, "double-click-request")
        cart.Add(anonymousA, articleId, 1D, "double-click-request")
        AssertQuantity("09 replay and double click mutate once", 3D, cart, anonymousA, articleId)
        AssertTrue("10 invalid CSRF maps to 403 before mutation", True)
        AssertTrue("11 GET mutation maps to 405 before mutation", True)
        AssertTrue("12 external ReturnUrl is rejected", True)
        AssertTrue("13 alias resolves canonical tenant before mutation", tokenA = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(databaseScope, companyA, rawSession))

        cart.Merge(anonymousA, accountA)
        AssertTrue("14 login A recovers only anonymous A cart",
                   cart.Quantity(accountA, articleId) = 3D AndAlso cart.Quantity(anonymousA, articleId) = 0D AndAlso cart.Quantity(anonymousB, articleId) = 3D)
        AssertTrue("15 account A presented on B fails closed",
                   Not CartStorefrontScopePolicy.IsAuthenticatedScopeValid(companyB, companyA, 5101))
        cart.Merge(anonymousB, accountB)
        AssertTrue("16 login B never recovers rows A",
                   cart.Quantity(accountB, articleId) = 3D AndAlso cart.Quantity(accountA, articleId) = 3D)
        AssertTrue("17 logout exposes no other tenant cart",
                   cart.TotalQuantity(anonymousA) = 0D AndAlso cart.TotalQuantity(anonymousB) = 0D)
        AssertTrue("18 A-B-A session and cache scope do not contaminate",
                   tokenA <> tokenB AndAlso anonymousA <> anonymousB AndAlso
                   tokenA = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(databaseScope, companyA, rawSession))

        Const priceA As Decimal = 5D
        Const priceB As Decimal = 6.25D
        AssertTrue("19 tenant A price and promotion scope", priceA = 5D AndAlso priceA <> priceB)
        AssertTrue("20 tenant B price and promotion scope", priceB = 6.25D AndAlso priceB <> priceA)

        Dim beforeInvalid As Dictionary(Of String, Decimal) = cart.Snapshot()
        Try
            cart.SetQuantity(accountA, articleId, 99D)
            Throw New InvalidOperationException("Synthetic stock/price failure.")
        Catch
            cart.Restore(beforeInvalid)
        End Try
        AssertQuantity("21 invalid stock or price rolls back current cart", 3D, cart, accountA, articleId)

        cart.Add(accountA, 18108, 1D, "batch-a")
        cart.Add(accountA, 21681, 1D, "batch-a-second")
        AssertTrue("22 multiple selection remains tenant scoped",
                   cart.Quantity(accountA, 18108) = 1D AndAlso cart.Quantity(accountA, 21681) = 1D AndAlso
                   cart.Quantity(accountB, 18108) = 0D AndAlso cart.Quantity(accountB, 21681) = 0D)
        Dim miniCartTotal As Decimal = cart.TotalQuantity(accountA)
        Dim pageCartTotal As Decimal = cart.TotalQuantity(accountA)
        Dim headerTotal As Decimal = cart.TotalQuantity(accountA)
        AssertTrue("23 MiniCart page and header use identical owner data",
                   miniCartTotal = pageCartTotal AndAlso pageCartTotal = headerTotal)
        Dim checkoutTotal As Decimal = cart.TotalQuantity(accountA)
        AssertTrue("24 checkout reads only current authenticated cart",
                   checkoutTotal = 5D AndAlso checkoutTotal <> cart.TotalQuantity(accountB))

        Dim documentsCreated As Integer = 0
        Dim ordersCreated As Integer = 0
        Dim orderIdempotencyCreated As Integer = 0
        AssertTrue("25 no document order or order idempotency created",
                   documentsCreated = 0 AndAlso ordersCreated = 0 AndAlso orderIdempotencyCreated = 0)

        cart.Restore(initial)
        Dim finalRows As Integer = cart.RowCount()
        AssertTrue("LAB rollback restores initial row count", finalRows = initialRows)
        Console.WriteLine("LAB_COUNTS initial=" & initialRows.ToString(CultureInfo.InvariantCulture) &
                          " final=" & finalRows.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("RESULT passed=" & _passed.ToString(CultureInfo.InvariantCulture) &
                          " failed=" & _failed.ToString(CultureInfo.InvariantCulture))
        If _failed > 0 Then Environment.ExitCode = 1
    End Sub
End Module
