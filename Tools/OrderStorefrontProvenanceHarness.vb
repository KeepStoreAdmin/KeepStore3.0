Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Threading

Friend NotInheritable Class TenantFixture
    Public Id As Integer
    Public LoginId As Long
    Public Price As Decimal
    Public Promotion As String
    Public Brand As String
    Public Sender As String
    Public Admin As String
End Class

Friend NotInheritable Class OrderFixture
    Public Id As Integer
    Public Number As Integer
    Public TenantId As Integer
    Public LoginId As Long
    Public Price As Decimal
    Public Promotion As String
End Class

Friend NotInheritable Class ClaimFixture
    Public TenantId As Integer
    Public LoginId As Long
    Public Payload As String
    Public Order As OrderFixture
End Class

Friend NotInheritable Class EmailFixture
    Public TenantId As Integer
    Public Brand As String
    Public Sender As String
    Public Admin As String
    Public OrderId As Integer
End Class

Friend NotInheritable Class FakeEmailSink
    Public ReadOnly Sent As New List(Of EmailFixture)()
    Public FailNext As Boolean

    Public Sub Send(ByVal tenant As TenantFixture, ByVal order As OrderFixture)
        If FailNext Then
            FailNext = False
            Throw New InvalidOperationException("FAKE_EMAIL_FAILURE")
        End If
        Sent.Add(New EmailFixture() With {
            .TenantId = tenant.Id,
            .Brand = tenant.Brand,
            .Sender = tenant.Sender,
            .Admin = tenant.Admin,
            .OrderId = order.Id
        })
    End Sub
End Class

Friend NotInheritable Class SubmitResult
    Public Outcome As String
    Public Order As OrderFixture
    Public EmailFailed As Boolean
End Class

Friend NotInheritable Class AccountIdentityRow
    Public UtentiId As Long
    Public PriceListId As Integer
End Class

Friend NotInheritable Class SyntheticAccountIdentityResolver
    Private Sub New()
    End Sub

    Public Shared Function TryResolve(ByVal rows As IEnumerable(Of AccountIdentityRow),
                                      ByRef utentiId As Long,
                                      ByRef priceListId As Integer) As Boolean
        utentiId = 0
        priceListId = 0
        If rows Is Nothing Then Return False

        Dim found As Boolean = False
        For Each row As AccountIdentityRow In rows
            If row Is Nothing OrElse row.UtentiId <= 0 Then Return False
            If Not found Then
                utentiId = row.UtentiId
                priceListId = row.PriceListId
                found = True
            ElseIf row.UtentiId <> utentiId OrElse row.PriceListId <> priceListId Then
                Return False
            End If
        Next
        Return found
    End Function
End Class

Friend NotInheritable Class SyntheticOrderEngine
    Private ReadOnly _gate As New Object()
    Private _nextDocumentNumber As Integer = 700
    Private _nextDocumentId As Integer = 9000
    Public Inventory As Integer = 20
    Public ReadOnly Carts As New Dictionary(Of String, Integer)()
    Public ReadOnly Claims As New Dictionary(Of String, ClaimFixture)(StringComparer.Ordinal)
    Public ReadOnly Orders As New List(Of OrderFixture)()
    Public ReadOnly EmailSink As New FakeEmailSink()

    Public Function OwnerKey(ByVal tenant As TenantFixture) As String
        Return tenant.Id.ToString() & ":" & tenant.LoginId.ToString()
    End Function

    Public Function Submit(ByVal tenant As TenantFixture,
                           ByVal requestId As String,
                           ByVal payload As String,
                           ByVal forceRollback As Boolean,
                           ByVal forceDeadlock As Boolean) As SubmitResult
        Dim created As OrderFixture = Nothing
        SyncLock _gate
            If Claims.ContainsKey(requestId) Then
                Dim existing As ClaimFixture = Claims(requestId)
                If existing.TenantId <> tenant.Id OrElse existing.LoginId <> tenant.LoginId Then
                    Return New SubmitResult() With {.Outcome = "TENANT_COLLISION"}
                End If
                If Not String.Equals(existing.Payload, payload, StringComparison.Ordinal) Then
                    Return New SubmitResult() With {.Outcome = "PAYLOAD_COLLISION"}
                End If
                Return New SubmitResult() With {.Outcome = "REPLAY", .Order = existing.Order}
            End If
            If forceDeadlock Then Return New SubmitResult() With {.Outcome = "RETRY_REQUIRED"}
            If forceRollback Then Return New SubmitResult() With {.Outcome = "ROLLBACK"}

            Dim key As String = OwnerKey(tenant)
            Dim quantity As Integer = If(Carts.ContainsKey(key), Carts(key), 0)
            If quantity <= 0 Then Return New SubmitResult() With {.Outcome = "EMPTY"}
            If quantity > Inventory Then Return New SubmitResult() With {.Outcome = "STOCK"}

            _nextDocumentNumber += 1
            _nextDocumentId += 1
            created = New OrderFixture() With {
                .Id = _nextDocumentId,
                .Number = _nextDocumentNumber,
                .TenantId = tenant.Id,
                .LoginId = tenant.LoginId,
                .Price = tenant.Price,
                .Promotion = tenant.Promotion
            }
            Orders.Add(created)
            Inventory -= quantity
            Carts(key) = 0
            Claims.Add(requestId, New ClaimFixture() With {
                .TenantId = tenant.Id,
                .LoginId = tenant.LoginId,
                .Payload = payload,
                .Order = created
            })
        End SyncLock

        Dim failed As Boolean = False
        Try
            EmailSink.Send(tenant, created)
        Catch
            failed = True
        End Try
        Return New SubmitResult() With {.Outcome = "COMPLETED", .Order = created, .EmailFailed = failed}
    End Function

    Public Shared Function CanRead(ByVal tenant As TenantFixture, ByVal order As OrderFixture) As Boolean
        Return tenant IsNot Nothing AndAlso order IsNot Nothing AndAlso
               tenant.Id = order.TenantId AndAlso tenant.LoginId = order.LoginId
    End Function
End Class

Module OrderStorefrontProvenanceHarness
    Private _failures As Integer

    Private Sub Assert(ByVal condition As Boolean, ByVal code As String)
        If condition Then
            Console.WriteLine("PASS " & code)
        Else
            _failures += 1
            Console.WriteLine("FAIL " & code)
        End If
    End Sub

    Sub Main()
        Dim a As New TenantFixture() With {.Id = 11, .LoginId = 101, .Price = 8.5D, .Promotion = "A-TIER", .Brand = "Brand A", .Sender = "sender-a@example.invalid", .Admin = "admin-a@example.invalid"}
        Dim b As New TenantFixture() With {.Id = 22, .LoginId = 202, .Price = 9.75D, .Promotion = "B-TIER", .Brand = "Brand B", .Sender = "sender-b@example.invalid", .Admin = "admin-b@example.invalid"}
        Dim engine As New SyntheticOrderEngine()
        engine.Carts(engine.OwnerKey(a)) = 2
        engine.Carts(engine.OwnerKey(b)) = 3

        Dim a1 As SubmitResult = engine.Submit(a, "request-a-1", "db|11|101|4|cart-a", False, False)
        Assert(a1.Order IsNot Nothing AndAlso a1.Order.TenantId = a.Id, "01_ORDER_A_PROVENANCE")
        Dim b1 As SubmitResult = engine.Submit(b, "request-b-1", "db|22|202|4|cart-b", False, False)
        Assert(b1.Order IsNot Nothing AndAlso b1.Order.TenantId = b.Id, "02_ORDER_B_PROVENANCE")
        Assert(b1.Order.Number = a1.Order.Number + 1, "03_GLOBAL_NUMBERING_A_B")

        engine.Carts(engine.OwnerKey(a)) = 1
        Dim a2 As SubmitResult = engine.Submit(a, "request-a-2", "db|11|101|4|cart-a2", False, False)
        Assert(a2.Order.Number = b1.Order.Number + 1, "04_GLOBAL_NUMBERING_B_A")
        Assert(a1.Order.Price = a.Price AndAlso b1.Order.Price = b.Price, "05_TENANT_PRICING")
        Assert(a1.Order.Promotion = a.Promotion AndAlso b1.Order.Promotion = b.Promotion, "06_TENANT_PROMOTION")
        Assert(engine.Inventory = 14, "07_SHARED_INVENTORY_ONCE")
        Assert(engine.Carts(engine.OwnerKey(a)) = 0, "08_CART_A_ONLY_CLEARED")
        Assert(engine.Carts(engine.OwnerKey(b)) = 0, "09_CART_B_ONLY_CLEARED")
        Assert(engine.Submit(a, "request-a-1", "db|11|101|4|cart-a", False, False).Order.Id = a1.Order.Id, "10_REPLAY_A_SAME_DOCUMENT")
        Assert(engine.Submit(b, "request-b-1", "db|22|202|4|cart-b", False, False).Order.Id = b1.Order.Id, "11_REPLAY_B_SAME_DOCUMENT")
        Assert(engine.Submit(b, "request-a-1", "db|11|101|4|cart-a", False, False).Outcome = "TENANT_COLLISION", "12_CROSS_TENANT_REQUEST_FAIL_CLOSED")
        Assert(engine.Submit(a, "request-a-1", "different", False, False).Outcome = "PAYLOAD_COLLISION", "13_PAYLOAD_COLLISION")
        Assert(SyntheticOrderEngine.CanRead(a, a1.Order) AndAlso Not SyntheticOrderEngine.CanRead(b, a1.Order), "14_RECEIPT_ISOLATION")
        Assert(engine.Orders.FindAll(Function(o) o.TenantId = a.Id AndAlso o.LoginId = a.LoginId).Count = 2, "15_DOCUMENT_LIST_ISOLATION")
        Assert(Not SyntheticOrderEngine.CanRead(a, b1.Order), "16_DOCUMENT_DETAIL_ISOLATION")
        Assert(engine.EmailSink.Sent(0).TenantId = a.Id AndAlso engine.EmailSink.Sent(0).Brand = a.Brand AndAlso engine.EmailSink.Sent(0).Sender = a.Sender AndAlso engine.EmailSink.Sent(0).Admin = a.Admin, "17_EMAIL_A_IDENTITY")
        Assert(engine.EmailSink.Sent(1).TenantId = b.Id AndAlso engine.EmailSink.Sent(1).Brand = b.Brand AndAlso engine.EmailSink.Sent(1).Sender = b.Sender AndAlso engine.EmailSink.Sent(1).Admin = b.Admin, "18_EMAIL_B_IDENTITY")
        Assert(engine.EmailSink.Sent.Count = 3, "19_ONE_EMAIL_PER_ORDER")
        engine.Submit(a, "request-a-2", "db|11|101|4|cart-a2", False, False)
        Assert(engine.EmailSink.Sent.Count = 3, "20_REPLAY_NO_EMAIL")
        engine.Carts(engine.OwnerKey(a)) = 1
        engine.Submit(a, "request-rollback", "rollback", True, False)
        Assert(engine.EmailSink.Sent.Count = 3 AndAlso Not engine.Claims.ContainsKey("request-rollback"), "21_ROLLBACK_NO_EMAIL")
        engine.Carts(engine.OwnerKey(a)) = 99
        Dim stockBefore As Integer = engine.Orders.Count
        engine.Submit(a, "request-stock", "stock", False, False)
        Assert(engine.Orders.Count = stockBefore AndAlso Not engine.Claims.ContainsKey("request-stock") AndAlso engine.EmailSink.Sent.Count = 3, "22_STOCK_NO_DOCUMENT_CLAIM_EMAIL")
        engine.Carts(engine.OwnerKey(a)) = 1
        engine.EmailSink.FailNext = True
        Dim emailFailure As SubmitResult = engine.Submit(a, "request-email-fail", "email-fail", False, False)
        Dim emailFailureReplay As SubmitResult = engine.Submit(a, "request-email-fail", "email-fail", False, False)
        Assert(emailFailure.EmailFailed AndAlso emailFailureReplay.Order.Id = emailFailure.Order.Id, "23_EMAIL_FAILURE_POST_COMMIT_NO_DUPLICATE")
        engine.Carts(engine.OwnerKey(b)) = 1
        Dim beforeDeadlock As Integer = engine.Orders.Count
        Assert(engine.Submit(b, "request-deadlock", "deadlock", False, True).Outcome = "RETRY_REQUIRED" AndAlso engine.Orders.Count = beforeDeadlock, "24_DEADLOCK_RETRY_SAFE")
        Assert(engine.Inventory = 13 AndAlso engine.Orders.Count = 4, "25_COMMIT_ROLLBACK_ATOMICITY")
        Assert(Not a.Brand.Contains("@") AndAlso
               a.Sender.EndsWith(".invalid", StringComparison.Ordinal) AndAlso
               b.Admin.EndsWith(".invalid", StringComparison.Ordinal), "26_SYNTHETIC_FIXTURES_ONLY")

        Dim concurrent As New SyntheticOrderEngine()
        concurrent.Carts(concurrent.OwnerKey(a)) = 1
        concurrent.Carts(concurrent.OwnerKey(b)) = 1
        Dim ca As SubmitResult = Nothing
        Dim cb As SubmitResult = Nothing
        Dim t1 As New Thread(Sub() ca = concurrent.Submit(a, "concurrent-a", "a", False, False))
        Dim t2 As New Thread(Sub() cb = concurrent.Submit(b, "concurrent-b", "b", False, False))
        t1.Start()
        t2.Start()
        t1.Join()
        t2.Join()
        Dim low As Integer = Math.Min(ca.Order.Number, cb.Order.Number)
        Dim high As Integer = Math.Max(ca.Order.Number, cb.Order.Number)
        Assert(low + 1 = high AndAlso ca.Order.Id <> cb.Order.Id, "27_CONCURRENT_GLOBAL_NUMBERING_UNIQUE_CONTIGUOUS")

        Dim resolvedUtentiId As Long = 0
        Dim resolvedPriceListId As Integer = 0
        Dim duplicatePhysicalRows As New List(Of AccountIdentityRow) From {
            New AccountIdentityRow() With {.UtentiId = 501, .PriceListId = 4},
            New AccountIdentityRow() With {.UtentiId = 501, .PriceListId = 4}
        }
        Assert(SyntheticAccountIdentityResolver.TryResolve(duplicatePhysicalRows, resolvedUtentiId, resolvedPriceListId) AndAlso
               resolvedUtentiId = 501 AndAlso resolvedPriceListId = 4,
               "28_DUPLICATE_PHYSICAL_ACCOUNT_ROWS_ACCEPTED")

        Dim distinctLogicalRows As New List(Of AccountIdentityRow) From {
            New AccountIdentityRow() With {.UtentiId = 501, .PriceListId = 4},
            New AccountIdentityRow() With {.UtentiId = 501, .PriceListId = 5}
        }
        Assert(Not SyntheticAccountIdentityResolver.TryResolve(distinctLogicalRows, resolvedUtentiId, resolvedPriceListId),
               "29_DISTINCT_LOGICAL_ACCOUNT_TUPLES_REJECTED")

        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
