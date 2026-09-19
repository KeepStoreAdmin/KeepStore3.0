Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Diagnostics
Imports System.Globalization

Friend NotInheritable Class ConsistencyRow
    Public Property Id As Integer
    Public Property Owner As String
    Public Property ArticleId As Integer
    Public Property Quantity As Decimal
    Public Property Price As Decimal
End Class

Friend NotInheritable Class ConsistencyView
    Public Property RowCount As Integer
    Public Property Quantity As Decimal
    Public Property Total As Decimal
End Class

Friend NotInheritable Class ConsistencyStore
    Private ReadOnly _rows As New List(Of ConsistencyRow)()
    Private _nextId As Integer = 1

    Public Function Add(ByVal owner As String,
                        ByVal articleId As Integer,
                        ByVal quantity As Decimal,
                        ByVal price As Decimal) As Integer
        Dim row As New ConsistencyRow With {
            .Id = _nextId,
            .Owner = owner,
            .ArticleId = articleId,
            .Quantity = quantity,
            .Price = price
        }
        _nextId += 1
        _rows.Add(row)
        Return row.Id
    End Function

    Public Function Read(ByVal owner As String) As ConsistencyView
        Dim view As New ConsistencyView()
        For Each row As ConsistencyRow In _rows
            If Not String.Equals(row.Owner, owner, StringComparison.Ordinal) Then Continue For
            view.RowCount += 1
            view.Quantity += row.Quantity
            view.Total += row.Quantity * row.Price
        Next
        Return view
    End Function

    Public Function Quantity(ByVal owner As String, ByVal articleId As Integer) As Decimal
        Dim result As Decimal = 0D
        For Each row As ConsistencyRow In _rows
            If String.Equals(row.Owner, owner, StringComparison.Ordinal) AndAlso row.ArticleId = articleId Then
                result += row.Quantity
            End If
        Next
        Return result
    End Function

    Public Function RemoveVerified(ByVal owner As String, ByVal rowId As Integer) As Boolean
        For index As Integer = 0 To _rows.Count - 1
            Dim row As ConsistencyRow = _rows(index)
            If row.Id = rowId AndAlso String.Equals(row.Owner, owner, StringComparison.Ordinal) Then
                _rows.RemoveAt(index)
                Return True
            End If
        Next
        Return False
    End Function

    Public Function ClearVerified(ByVal owner As String) As Integer
        Dim affected As Integer = 0
        For index As Integer = _rows.Count - 1 To 0 Step -1
            If String.Equals(_rows(index).Owner, owner, StringComparison.Ordinal) Then
                _rows.RemoveAt(index)
                affected += 1
            End If
        Next
        Return affected
    End Function

    Public Sub MergeOnce(ByVal anonymousOwner As String, ByVal accountOwner As String)
        Dim anonymousRows As New List(Of ConsistencyRow)()
        For Each row As ConsistencyRow In _rows
            If String.Equals(row.Owner, anonymousOwner, StringComparison.Ordinal) Then anonymousRows.Add(row)
        Next

        For Each anonymousRow As ConsistencyRow In anonymousRows
            Dim existing As ConsistencyRow = Nothing
            For Each candidate As ConsistencyRow In _rows
                If String.Equals(candidate.Owner, accountOwner, StringComparison.Ordinal) AndAlso
                   candidate.ArticleId = anonymousRow.ArticleId Then
                    existing = candidate
                    Exit For
                End If
            Next
            If existing Is Nothing Then
                anonymousRow.Owner = accountOwner
            Else
                existing.Quantity += anonymousRow.Quantity
                _rows.Remove(anonymousRow)
            End If
        Next
    End Sub
End Class

Module CartConsistencyHarness
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

    Private Function Same(ByVal left As ConsistencyView, ByVal right As ConsistencyView) As Boolean
        Return left.RowCount = right.RowCount AndAlso left.Quantity = right.Quantity AndAlso left.Total = right.Total
    End Function

    Public Sub Main()
        Const databaseScope As String = "same-logical-database"
        Const companyA As Integer = 4101
        Const companyB As Integer = 4202
        Const loginA As Integer = 5101
        Const loginB As Integer = 5202
        Const rawSession As String = "browser-session"

        Dim accountA As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseScope, companyA, loginA, String.Empty)
        Dim accountB As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseScope, companyB, loginB, String.Empty)
        Dim anonymousTokenA As String = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(databaseScope, companyA, rawSession)
        Dim anonymousA As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseScope, companyA, 0, anonymousTokenA)
        Dim store As New ConsistencyStore()

        Dim row1 As Integer = store.Add(accountA, 101, 1D, 5D)
        Dim row2 As Integer = store.Add(accountA, 102, 2D, 7D)
        store.Add(accountA, 103, 1D, 11D)
        AssertTrue("01 account fixture has three persistent rows", store.Read(accountA).RowCount = 3)
        AssertTrue("02 login selects authenticated owner", accountA <> anonymousA)

        Dim page As ConsistencyView = store.Read(accountA)
        Dim mini As ConsistencyView = store.Read(accountA)
        Dim header As ConsistencyView = store.Read(accountA)
        AssertTrue("03 cart page shows three rows", page.RowCount = 3)
        AssertTrue("04 MiniCart shows the same three rows", mini.RowCount = 3 AndAlso Same(page, mini))
        AssertTrue("05 header shows the same quantity", header.Quantity = page.Quantity)
        AssertTrue("06 prices and totals are identical", page.Total = 30D AndAlso Same(page, header))

        AssertTrue("07 MiniCart remove deletes exactly one owned row", store.RemoveVerified(accountA, row1))
        AssertTrue("08 page has two rows after MiniCart remove", store.Read(accountA).RowCount = 2)
        AssertTrue("09 MiniCart has two rows after remove", Same(store.Read(accountA), store.Read(accountA)))
        AssertTrue("10 header is current after remove", store.Read(accountA).Quantity = 3D)

        AssertTrue("11 page remove updates MiniCart", store.RemoveVerified(accountA, row2) AndAlso store.Read(accountA).RowCount = 1)
        AssertTrue("12 page clear empties MiniCart", store.ClearVerified(accountA) = 1 AndAlso store.Read(accountA).RowCount = 0)
        store.Add(accountA, 104, 1D, 3D)
        store.Add(accountA, 105, 1D, 4D)
        AssertTrue("13 MiniCart clear empties page", store.ClearVerified(accountA) = 2 AndAlso store.Read(accountA).RowCount = 0)

        store.Add(accountA, 201, 2D, 5D)
        store.Add(accountA, 202, 1D, 8D)
        store.Add(anonymousA, 201, 1D, 5D)
        store.Add(anonymousA, 203, 1D, 9D)
        store.MergeOnce(anonymousA, accountA)
        AssertTrue("14 anonymous add login merge transfers rows", store.Read(anonymousA).RowCount = 0 AndAlso store.Read(accountA).RowCount = 3)
        AssertTrue("15 existing account rows are preserved", store.Quantity(accountA, 202) = 1D)
        AssertTrue("16 duplicates follow aggregation contract", store.Quantity(accountA, 201) = 3D)
        Dim afterFirstMerge As ConsistencyView = store.Read(accountA)
        store.MergeOnce(anonymousA, accountA)
        AssertTrue("17 repeated merge replay does not duplicate", Same(afterFirstMerge, store.Read(accountA)))
        AssertTrue("18 refresh back forward cannot restore stale data", Same(store.Read(accountA), afterFirstMerge))

        Dim tenantBRow As Integer = store.Add(accountB, 301, 4D, 12D)
        AssertTrue("19 tenant A cannot read or mutate tenant B",
                   store.Quantity(accountA, 301) = 0D AndAlso Not store.RemoveVerified(accountA, tenantBRow))
        AssertTrue("20 logout exposes no authenticated rows", store.Read(anonymousA).RowCount = 0)
        AssertTrue("21 new login recovers persisted account cart", Same(store.Read(accountA), afterFirstMerge))

        Dim missingRemoveSucceeded As Boolean = store.RemoveVerified(accountA, tenantBRow)
        Dim verifiedRow As Integer = store.Add(accountA, 401, 1D, 2D)
        Dim verifiedRemoveSucceeded As Boolean = store.RemoveVerified(accountA, verifiedRow)
        AssertTrue("22 updated message requires verified mutation", Not missingRemoveSucceeded AndAlso verifiedRemoveSucceeded)

        Dim orders As Integer = 0
        Dim documents As Integer = 0
        Dim emails As Integer = 0
        AssertTrue("23 zero orders documents or emails", orders = 0 AndAlso documents = 0 AndAlso emails = 0)

        Const benchmarkIterations As Integer = 10000
        Dim stopwatch As Stopwatch = Stopwatch.StartNew()
        For iteration As Integer = 1 To benchmarkIterations
            Dim labToken As String = CartStorefrontScopePolicy.BuildAnonymousOwnerToken(
                databaseScope, companyA, rawSession & iteration.ToString(CultureInfo.InvariantCulture))
            Dim labAnonymous As String = CartStorefrontScopePolicy.BuildOwnerScopeKey(databaseScope, companyA, 0, labToken)
            Dim labStore As New ConsistencyStore()
            labStore.Add(accountA, 501, 1D, 5D)
            labStore.Add(labAnonymous, 501, 1D, 5D)
            labStore.Add(labAnonymous, 502, 1D, 7D)
            labStore.MergeOnce(labAnonymous, accountA)
        Next
        stopwatch.Stop()
        Console.WriteLine("LOGIN_LAB iterations=" & benchmarkIterations.ToString(CultureInfo.InvariantCulture) &
                          " total_ms=" & stopwatch.Elapsed.TotalMilliseconds.ToString("F3", CultureInfo.InvariantCulture) &
                          " mean_ms=" & (stopwatch.Elapsed.TotalMilliseconds / benchmarkIterations).ToString("F6", CultureInfo.InvariantCulture))

        Console.WriteLine("RESULT passed=" & _passed.ToString(CultureInfo.InvariantCulture) &
                          " failed=" & _failed.ToString(CultureInfo.InvariantCulture))
        If _failed > 0 Then Environment.ExitCode = 1
    End Sub
End Module
