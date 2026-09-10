Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class CartQuantityMutationRequest
    Public Property CartRowId As Integer
    Public Property Quantity As Decimal
End Class

Public Class CartStandardMutationResult
    Public Property Succeeded As Boolean
    Public Property CartRowId As Integer
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property Quantity As Decimal
    Public Property QuantityDelta As Decimal
    Public Property ProductName As String
    Public Property Price As Decimal
    Public Property PriceIvato As Decimal
    Public Property OfferDetailId As Integer
    Public Property ErrorMessage As String
End Class

Public Class CartStandardBatchMutationRequest
    Public Property ArticleId As Integer
    Public Property RequestedTCId As Integer
    Public Property QuantityDelta As Decimal
End Class

Public Class CartStandardBatchMutationResult
    Public Sub New()
        Items = New List(Of CartStandardMutationResult)()
    End Sub

    Public Property Succeeded As Boolean
    Public Property Items As List(Of CartStandardMutationResult)
    Public Property ErrorMessage As String
End Class

Public Class CartOwnerRemovalResult
    Public Property Succeeded As Boolean
    Public Property AffectedRows As Integer
    Public Property WasNoOp As Boolean
    Public Property IsIndeterminate As Boolean
    Public Property ErrorMessage As String
End Class

Friend Class CartMutationExistingRow
    Public Property Id As Integer
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property Quantity As Decimal
End Class

Friend Class CartStandardBatchPlan
    Public Property Request As CartStandardBatchMutationRequest
    Public Property ExistingRows As List(Of CartMutationExistingRow)
    Public Property FinalQuantity As Decimal
    Public Property Resolved As CartResolvedPrice
    Public Property FreeShipping As Integer
    Public Property CartRowId As Integer
End Class

Friend Class CartMutationOwnerContext
    Public Property LoginId As Integer
    Public Property SessionId As String
    Public Property Listino As Integer
End Class

Public Module CartMutationService
    Private Const GenericMutationError As String = "Non è stato possibile aggiornare il carrello. Riprova."
    Private _testDeadlockFaultCount As Integer

    Public Function RemoveCartRowForCurrentOwner(ByVal ctx As HttpContext,
                                                 ByVal cartRowId As Integer) As CartOwnerRemovalResult
        If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse cartRowId <= 0 Then
            Return New CartOwnerRemovalResult With {.ErrorMessage = GenericMutationError}
        End If
        Return MutateOwnedCartRows(ctx, cartRowId, False)
    End Function

    Public Function ClearCartForCurrentOwner(ByVal ctx As HttpContext) As CartOwnerRemovalResult
        If ctx Is Nothing OrElse ctx.Session Is Nothing Then
            Return New CartOwnerRemovalResult With {.ErrorMessage = GenericMutationError}
        End If
        Return MutateOwnedCartRows(ctx, 0, True)
    End Function

    Private Function MutateOwnedCartRows(ByVal ctx As HttpContext,
                                         ByVal cartRowId As Integer,
                                         ByVal clearAll As Boolean) As CartOwnerRemovalResult
        Dim fallback As New CartOwnerRemovalResult With {.ErrorMessage = GenericMutationError}
        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return fallback

        Dim operationName As String = If(clearAll, "clear-cart", "remove-cart-row")
        Dim execution As CartTransactionExecutionResult(Of CartOwnerRemovalResult) =
            CartTransactionRetryPolicy.Execute(Of CartOwnerRemovalResult)(
                settings.ConnectionString,
                IsolationLevel.Serializable,
                operationName,
                CartMutationIdempotencyService.GetCurrentRequestId(ctx),
                Function(conn As MySqlConnection, transaction As MySqlTransaction) As CartTransactionWorkResult(Of CartOwnerRemovalResult)
            Dim owner As CartMutationOwnerContext = ResolveOwnerContext(ctx, 0, String.Empty, 1)
            If owner Is Nothing Then
                Return CartTransactionWorkResult(Of CartOwnerRemovalResult).Abort(
                    New CartOwnerRemovalResult With {.ErrorMessage = GenericMutationError})
            End If

            Dim ownedRowIds As List(Of Integer) = LoadOwnedRowIds(
                conn, transaction, owner.LoginId, owner.SessionId)
            Dim affected As Integer = 0

            ' TEST-ONLY 1213 fault hook; removed before final diff.
            If Threading.Interlocked.Increment(_testDeadlockFaultCount) = 1 Then
                Using fault As New MySqlCommand(
                    "SIGNAL SQLSTATE '40001' SET MYSQL_ERRNO=1213, MESSAGE_TEXT='test-only deadlock'",
                    conn,
                    transaction)
                    fault.ExecuteNonQuery()
                End Using
            End If

            If clearAll Then
                If ownedRowIds.Count > 0 Then
                    Using cmd As New MySqlCommand("DELETE FROM carrello WHERE " & OwnerWhere(owner.LoginId), conn, transaction)
                        AddOwnerParameter(cmd, owner.LoginId, owner.SessionId)
                        affected = cmd.ExecuteNonQuery()
                    End Using
                    If affected <> ownedRowIds.Count Then
                        Throw New InvalidOperationException("Owned cart clear affected an unexpected row count.")
                    End If
                End If
            ElseIf ownedRowIds.Contains(cartRowId) Then
                Using cmd As New MySqlCommand("DELETE FROM carrello WHERE ID=?id AND " & OwnerWhere(owner.LoginId), conn, transaction)
                    cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = cartRowId
                    AddOwnerParameter(cmd, owner.LoginId, owner.SessionId)
                    affected = cmd.ExecuteNonQuery()
                End Using
                If affected <> 1 Then
                    Throw New InvalidOperationException("Owned cart row removal affected an unexpected row count.")
                End If
            End If

            Dim remaining As Integer = CountOwnedRows(
                conn, transaction, owner.LoginId, owner.SessionId, If(clearAll, 0, cartRowId))
            If remaining <> 0 Then Throw New InvalidOperationException("Owned cart removal final verification failed.")

            Return CartTransactionWorkResult(Of CartOwnerRemovalResult).Commit(
                New CartOwnerRemovalResult With {
                    .Succeeded = True,
                    .AffectedRows = affected,
                    .WasNoOp = (affected = 0),
                    .ErrorMessage = String.Empty
                })
                End Function)

        If execution.IsIndeterminate Then
            CartMutationIdempotencyService.MarkCurrentIntentIndeterminate(ctx)
            Return New CartOwnerRemovalResult With {
                .IsIndeterminate = True,
                .ErrorMessage = GenericMutationError
            }
        End If
        If execution.Succeeded AndAlso execution.Value IsNot Nothing Then Return execution.Value
        Return fallback
    End Function

    Public Function AddStandardProductForCurrentOwner(ByVal ctx As HttpContext,
                                                       ByVal articleId As Integer,
                                                       ByVal requestedTCId As Integer,
                                                       ByVal quantityToAdd As Decimal) As CartStandardMutationResult
        If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return New CartStandardMutationResult With {.ErrorMessage = GenericMutationError}
        Return AddStandardProduct(ctx, 0, String.Empty, articleId, requestedTCId, quantityToAdd, 1)
    End Function

    Public Function AddStandardProductsBatchForCurrentOwner(
        ByVal ctx As HttpContext,
        ByVal items As IList(Of CartStandardBatchMutationRequest)) As CartStandardBatchMutationResult

        If ctx Is Nothing OrElse ctx.Session Is Nothing Then
            Return New CartStandardBatchMutationResult With {.ErrorMessage = GenericMutationError}
        End If

        Return MutateStandardProductsBatch(ctx, 0, String.Empty, 1, items)
    End Function

    Public Function SetStandardProductQuantityForCurrentOwner(ByVal ctx As HttpContext,
                                                              ByVal articleId As Integer,
                                                              ByVal requestedTCId As Integer,
                                                              ByVal desiredQuantity As Decimal) As CartStandardMutationResult
        If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return New CartStandardMutationResult With {.ErrorMessage = GenericMutationError}

        Return MutateStandardProduct(ctx, 0, String.Empty, articleId, requestedTCId, desiredQuantity, 1, True)
    End Function

    Public Function AddStandardProduct(ByVal ctx As HttpContext,
                                       ByVal loginId As Integer,
                                       ByVal sessionId As String,
                                       ByVal articleId As Integer,
                                       ByVal requestedTCId As Integer,
                                       ByVal quantityToAdd As Decimal,
                                       ByVal listino As Integer) As CartStandardMutationResult
        Dim request As New CartStandardBatchMutationRequest With {
            .ArticleId = articleId,
            .RequestedTCId = requestedTCId,
            .QuantityDelta = quantityToAdd
        }
        Dim requests As New List(Of CartStandardBatchMutationRequest) From {request}
        Dim batchResult As CartStandardBatchMutationResult = MutateStandardProductsBatch(
            ctx, loginId, sessionId, listino, requests)
        If batchResult IsNot Nothing AndAlso batchResult.Succeeded AndAlso batchResult.Items.Count = 1 Then
            Return batchResult.Items(0)
        End If
        Return New CartStandardMutationResult With {
            .ArticleId = articleId,
            .TCId = NormalizeTCId(requestedTCId),
            .ErrorMessage = If(batchResult IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(batchResult.ErrorMessage),
                               batchResult.ErrorMessage,
                               GenericMutationError)
        }
    End Function

    Private Function MutateStandardProductsBatch(
        ByVal ctx As HttpContext,
        ByVal loginId As Integer,
        ByVal sessionId As String,
        ByVal listino As Integer,
        ByVal items As IList(Of CartStandardBatchMutationRequest)) As CartStandardBatchMutationResult

        Dim result As New CartStandardBatchMutationResult With {.ErrorMessage = GenericMutationError}
        Dim normalizedItems As List(Of CartStandardBatchMutationRequest) = Nothing
        Dim canonicalPayload As String = String.Empty
        If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse
           Not CartMutationIdempotencyService.TryNormalizeStandardBatchItems(
               items, CartMutationIdempotencyService.MaxStandardBatchItems, normalizedItems, canonicalPayload) Then
            Return result
        End If

        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return result

        Dim execution As CartTransactionExecutionResult(Of CartStandardBatchMutationResult) =
            CartTransactionRetryPolicy.Execute(Of CartStandardBatchMutationResult)(
                settings.ConnectionString,
                IsolationLevel.Serializable,
                "standard-batch",
                CartMutationIdempotencyService.GetCurrentRequestId(ctx),
                Function(conn As MySqlConnection, transaction As MySqlTransaction) As CartTransactionWorkResult(Of CartStandardBatchMutationResult)
            Dim owner As CartMutationOwnerContext = ResolveOwnerContext(ctx, loginId, sessionId, listino)
            If owner Is Nothing Then
                Return CartTransactionWorkResult(Of CartStandardBatchMutationResult).Abort(
                    New CartStandardBatchMutationResult With {.ErrorMessage = GenericMutationError})
            End If
            Dim attemptLoginId As Integer = owner.LoginId
            Dim attemptSessionId As String = owner.SessionId
            Dim attemptListino As Integer = owner.Listino
            Dim ownerRows As List(Of CartMutationExistingRow) = LoadOwnedRows(
                conn, transaction, attemptLoginId, attemptSessionId)
            Dim eligibilityContext As ProductPromotionEligibilityContext =
                ProductPromotionEligibilityResolver.CreateContext(ctx, attemptListino)

            Dim effectiveByKey As New Dictionary(Of String, CartStandardBatchMutationRequest)(StringComparer.Ordinal)
            For Each item As CartStandardBatchMutationRequest In normalizedItems
                Dim probeQuantity As Decimal = If(item.QuantityDelta > 0D, item.QuantityDelta, 1D)
                Dim preliminary As CartResolvedPrice = CartPriceRevalidationHelper.ResolveStandardPrice(
                    ctx, conn, transaction, eligibilityContext, item.ArticleId, item.RequestedTCId,
                    probeQuantity, attemptListino, True, True)
                EnsureResolved(preliminary)

                Dim effectiveKey As String = BatchKey(item.ArticleId, preliminary.EffectiveTCId)
                Dim effective As CartStandardBatchMutationRequest = Nothing
                If effectiveByKey.TryGetValue(effectiveKey, effective) Then
                    effective.QuantityDelta = Decimal.Add(effective.QuantityDelta, item.QuantityDelta)
                Else
                    effectiveByKey(effectiveKey) = New CartStandardBatchMutationRequest With {
                        .ArticleId = item.ArticleId,
                        .RequestedTCId = preliminary.EffectiveTCId,
                        .QuantityDelta = item.QuantityDelta
                    }
                End If
            Next

            Dim effectiveItems As New List(Of CartStandardBatchMutationRequest)()
            For Each effective As CartStandardBatchMutationRequest In effectiveByKey.Values
                If effective.QuantityDelta <> 0D Then effectiveItems.Add(effective)
            Next
            effectiveItems.Sort(AddressOf CompareBatchRequests)
            If effectiveItems.Count = 0 OrElse effectiveItems.Count > CartMutationIdempotencyService.MaxStandardBatchItems Then
                Throw New InvalidOperationException("The standard cart batch has no effective mutations.")
            End If

            Dim plans As New List(Of CartStandardBatchPlan)()
            For Each item As CartStandardBatchMutationRequest In effectiveItems
                Dim existing As List(Of CartMutationExistingRow) = ownerRows.FindAll(
                    Function(row As CartMutationExistingRow) row.ArticleId = item.ArticleId AndAlso
                        NormalizeTCId(row.TCId) = NormalizeTCId(item.RequestedTCId))
                If existing.Count = 0 AndAlso item.QuantityDelta < 0D Then
                    Throw New InvalidOperationException("A negative cart delta requires an existing owned row.")
                End If

                Dim finalQuantity As Decimal = item.QuantityDelta
                For Each row As CartMutationExistingRow In existing
                    finalQuantity = Decimal.Add(finalQuantity, row.Quantity)
                Next
                ValidateQuantity(finalQuantity)

                Dim resolved As CartResolvedPrice = CartPriceRevalidationHelper.ResolveStandardPrice(
                    ctx, conn, transaction, eligibilityContext, item.ArticleId, item.RequestedTCId,
                    finalQuantity, attemptListino, True, True)
                EnsureResolved(resolved)
                If NormalizeTCId(resolved.EffectiveTCId) <> NormalizeTCId(item.RequestedTCId) Then
                    Throw New InvalidOperationException("Effective product variant changed during batch planning.")
                End If
                plans.Add(New CartStandardBatchPlan With {
                    .Request = New CartStandardBatchMutationRequest With {
                        .ArticleId = item.ArticleId,
                        .RequestedTCId = resolved.EffectiveTCId,
                        .QuantityDelta = item.QuantityDelta
                    },
                    .ExistingRows = existing,
                    .FinalQuantity = finalQuantity,
                    .Resolved = resolved,
                    .FreeShipping = If(resolved.FreeShipping <> 0, 1, 0)
                })
            Next

            For planIndex As Integer = 0 To plans.Count - 1
                Dim plan As CartStandardBatchPlan = plans(planIndex)
                If plan.ExistingRows.Count = 0 Then
                    plan.CartRowId = InsertRow(conn, transaction, ctx, attemptLoginId, attemptSessionId, attemptListino,
                                               plan.FinalQuantity, plan.Resolved, plan.FreeShipping)
                Else
                    plan.CartRowId = plan.ExistingRows(0).Id
                    UpdateRow(conn, transaction, ctx, attemptLoginId, attemptSessionId, plan.CartRowId, attemptListino,
                              plan.FinalQuantity, plan.Resolved, plan.FreeShipping)
                    For index As Integer = 1 To plan.ExistingRows.Count - 1
                        DeleteOwnedRow(conn, transaction, attemptLoginId, attemptSessionId, plan.ExistingRows(index).Id)
                    Next
                End If
            Next

            Dim confirmedItems As New List(Of CartStandardMutationResult)()
            For Each plan As CartStandardBatchPlan In plans
                VerifyFinalRow(conn, transaction, attemptLoginId, attemptSessionId, plan.CartRowId,
                               plan.Request.ArticleId, plan.Resolved.EffectiveTCId,
                               plan.FinalQuantity, plan.Resolved)
                VerifySingleOwnedProductRow(conn, transaction, attemptLoginId, attemptSessionId,
                                            plan.Request.ArticleId, plan.Resolved.EffectiveTCId)
                confirmedItems.Add(New CartStandardMutationResult With {
                    .Succeeded = True,
                    .CartRowId = plan.CartRowId,
                    .ArticleId = plan.Request.ArticleId,
                    .TCId = plan.Resolved.EffectiveTCId,
                    .Quantity = plan.FinalQuantity,
                    .QuantityDelta = plan.Request.QuantityDelta,
                    .ProductName = plan.Resolved.Description,
                    .Price = plan.Resolved.Price,
                    .PriceIvato = plan.Resolved.PriceIvato,
                    .OfferDetailId = plan.Resolved.OfferDetailId,
                    .ErrorMessage = String.Empty
                })
            Next

            Dim attemptResult As New CartStandardBatchMutationResult With {
                .Succeeded = True,
                .Items = confirmedItems,
                .ErrorMessage = String.Empty
            }
            Return CartTransactionWorkResult(Of CartStandardBatchMutationResult).Commit(attemptResult)
                End Function)

        If execution.IsIndeterminate Then CartMutationIdempotencyService.MarkCurrentIntentIndeterminate(ctx)
        Return If(execution.Value, result)
    End Function

    Private Function MutateStandardProduct(ByVal ctx As HttpContext,
                                           ByVal loginId As Integer,
                                           ByVal sessionId As String,
                                           ByVal articleId As Integer,
                                           ByVal requestedTCId As Integer,
                                           ByVal quantityValue As Decimal,
                                           ByVal listino As Integer,
                                           ByVal setAbsoluteQuantity As Boolean) As CartStandardMutationResult
        Dim result As New CartStandardMutationResult() With {
            .ArticleId = articleId,
            .TCId = NormalizeTCId(requestedTCId),
            .ErrorMessage = GenericMutationError
        }
        If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse articleId <= 0 OrElse
           (If(setAbsoluteQuantity, quantityValue <= 0D, quantityValue = 0D)) Then Return result

        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return result

        Dim operationName As String = If(setAbsoluteQuantity, "set-standard", "add-standard")
        Dim execution As CartTransactionExecutionResult(Of CartStandardMutationResult) =
            CartTransactionRetryPolicy.Execute(Of CartStandardMutationResult)(
                settings.ConnectionString,
                IsolationLevel.Serializable,
                operationName,
                CartMutationIdempotencyService.GetCurrentRequestId(ctx),
                Function(conn As MySqlConnection, transaction As MySqlTransaction) As CartTransactionWorkResult(Of CartStandardMutationResult)
            Dim owner As CartMutationOwnerContext = ResolveOwnerContext(ctx, loginId, sessionId, listino)
            If owner Is Nothing Then
                Return CartTransactionWorkResult(Of CartStandardMutationResult).Abort(
                    New CartStandardMutationResult With {
                        .ArticleId = articleId,
                        .TCId = NormalizeTCId(requestedTCId),
                        .ErrorMessage = GenericMutationError
                    })
            End If
            Dim attemptLoginId As Integer = owner.LoginId
            Dim attemptSessionId As String = owner.SessionId
            Dim attemptListino As Integer = owner.Listino

            Dim ownedArticleRows As List(Of CartMutationExistingRow) = LoadOwnedArticleRows(
                conn, transaction, attemptLoginId, attemptSessionId, articleId)
            Dim eligibilityContext As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateContext(ctx, attemptListino)
            Dim probeQuantity As Decimal = If(quantityValue > 0D, quantityValue, 1D)
            Dim preliminary As CartResolvedPrice = CartPriceRevalidationHelper.ResolveStandardPrice(
                ctx, conn, transaction, eligibilityContext, articleId, requestedTCId, probeQuantity,
                attemptListino, True, True)
            EnsureResolved(preliminary)

            Dim effectiveTCId As Integer = preliminary.EffectiveTCId
            Dim existing As List(Of CartMutationExistingRow) = ownedArticleRows.FindAll(
                Function(row As CartMutationExistingRow) NormalizeTCId(row.TCId) = effectiveTCId)
            If Not setAbsoluteQuantity AndAlso existing.Count = 0 AndAlso quantityValue < 0D Then
                Return CartTransactionWorkResult(Of CartStandardMutationResult).Abort(
                    New CartStandardMutationResult With {
                        .ArticleId = articleId,
                        .TCId = NormalizeTCId(requestedTCId),
                        .ErrorMessage = GenericMutationError
                    })
            End If

            Dim finalQuantity As Decimal = quantityValue
            If Not setAbsoluteQuantity Then
                For Each row As CartMutationExistingRow In existing
                    finalQuantity = Decimal.Add(finalQuantity, row.Quantity)
                Next
            End If

            ValidateQuantity(finalQuantity)

            Dim resolved As CartResolvedPrice = CartPriceRevalidationHelper.ResolveStandardPrice(
                ctx, conn, transaction, eligibilityContext, articleId, effectiveTCId, finalQuantity,
                attemptListino, True, True)
            EnsureResolved(resolved)
            Dim freeShipping As Integer = If(resolved.FreeShipping <> 0, 1, 0)

            Dim cartRowId As Integer
            If existing.Count = 0 Then
                cartRowId = InsertRow(conn, transaction, ctx, attemptLoginId, attemptSessionId, attemptListino, finalQuantity, resolved, freeShipping)
            Else
                cartRowId = existing(0).Id
                UpdateRow(conn, transaction, ctx, attemptLoginId, attemptSessionId, cartRowId, attemptListino, finalQuantity, resolved, freeShipping)
                For i As Integer = 1 To existing.Count - 1
                    DeleteOwnedRow(conn, transaction, attemptLoginId, attemptSessionId, existing(i).Id)
                Next
            End If

            VerifyFinalRow(conn, transaction, attemptLoginId, attemptSessionId, cartRowId, articleId, effectiveTCId, finalQuantity, resolved)

            Dim attemptResult As New CartStandardMutationResult With {
                .Succeeded = True,
                .CartRowId = cartRowId,
                .ArticleId = articleId,
                .TCId = effectiveTCId,
                .Quantity = finalQuantity,
                .ProductName = resolved.Description,
                .Price = resolved.Price,
                .PriceIvato = resolved.PriceIvato,
                .OfferDetailId = resolved.OfferDetailId,
                .ErrorMessage = String.Empty
            }
            Return CartTransactionWorkResult(Of CartStandardMutationResult).Commit(attemptResult)
                End Function)

        If execution.IsIndeterminate Then CartMutationIdempotencyService.MarkCurrentIntentIndeterminate(ctx)
        Return If(execution.Value, result)
    End Function

    Private Function SessionInteger(ByVal ctx As HttpContext, ByVal key As String, ByVal fallback As Integer) As Integer
        Dim parsed As Integer
        If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing AndAlso
           Integer.TryParse(Convert.ToString(ctx.Session(key)), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed) Then Return parsed
        Return fallback
    End Function

    Private Function ResolveOwnerContext(ByVal ctx As HttpContext,
                                         ByVal fallbackLoginId As Integer,
                                         ByVal fallbackSessionId As String,
                                         ByVal fallbackListino As Integer) As CartMutationOwnerContext
        If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return Nothing
        Dim loginId As Integer = SessionInteger(ctx, "LoginId",
            SessionInteger(ctx, "LoginID", SessionInteger(ctx, "LOGINID", fallbackLoginId)))
        Dim sessionId As String = String.Empty
        If loginId <= 0 Then
            sessionId = Convert.ToString(ctx.Session.SessionID)
            If String.IsNullOrWhiteSpace(sessionId) Then sessionId = If(fallbackSessionId, String.Empty)
        End If
        Dim listino As Integer = SessionInteger(ctx, "Listino", SessionInteger(ctx, "listino", fallbackListino))
        If listino <= 0 Then listino = 1
        If loginId <= 0 AndAlso String.IsNullOrWhiteSpace(sessionId) Then Return Nothing
        Return New CartMutationOwnerContext With {
            .LoginId = loginId,
            .SessionId = sessionId,
            .Listino = listino
        }
    End Function

    Public Function UpdateStandardQuantities(ByVal ctx As HttpContext,
                                             ByVal loginId As Integer,
                                             ByVal sessionId As String,
                                             ByVal listino As Integer,
                                             ByVal requests As IList(Of CartQuantityMutationRequest)) As CartPriceRevalidationResult
        Dim quantityOverrides As New Dictionary(Of Integer, Decimal)()
        If requests IsNot Nothing Then
            For Each mutation As CartQuantityMutationRequest In requests
                If mutation Is Nothing OrElse mutation.CartRowId <= 0 OrElse mutation.Quantity <= 0D OrElse quantityOverrides.ContainsKey(mutation.CartRowId) Then
                    Return BlockingResult("La quantità richiesta non è valida.")
                End If
                If Not IsValidQuantity(mutation.Quantity) Then
                    Return BlockingResult("La quantità richiesta non è valida.")
                End If
                quantityOverrides.Add(mutation.CartRowId, mutation.Quantity)
            Next
        End If
        If quantityOverrides.Count = 0 Then Return BlockingResult("Il carrello non contiene righe aggiornabili.")

        If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return TechnicalResult()
        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return TechnicalResult()

        Dim execution As CartTransactionExecutionResult(Of CartPriceRevalidationResult) =
            CartTransactionRetryPolicy.Execute(Of CartPriceRevalidationResult)(
                settings.ConnectionString,
                IsolationLevel.Serializable,
                "update-quantities",
                CartMutationIdempotencyService.GetCurrentRequestId(ctx),
                Function(conn As MySqlConnection, transaction As MySqlTransaction) As CartTransactionWorkResult(Of CartPriceRevalidationResult)
            Dim owner As CartMutationOwnerContext = ResolveOwnerContext(ctx, loginId, sessionId, listino)
            If owner Is Nothing Then
                Return CartTransactionWorkResult(Of CartPriceRevalidationResult).Abort(TechnicalResult())
            End If
            Dim attemptOverrides As New Dictionary(Of Integer, Decimal)(quantityOverrides)
            Dim result As CartPriceRevalidationResult = CartPriceRevalidationHelper.RevalidateCurrentCart(
                ctx, conn, transaction, owner.LoginId, owner.SessionId, owner.Listino,
                True, True, attemptOverrides, True)
            If result Is Nothing OrElse result.HasBlockingError Then
                Return CartTransactionWorkResult(Of CartPriceRevalidationResult).Abort(
                    If(result, TechnicalResult()))
            End If
            Return CartTransactionWorkResult(Of CartPriceRevalidationResult).Commit(result)
                End Function)

        If execution.IsIndeterminate Then CartMutationIdempotencyService.MarkCurrentIntentIndeterminate(ctx)
        Return If(execution.Value, TechnicalResult())
    End Function

    Private Function LoadOwnedRows(ByVal conn As MySqlConnection,
                                   ByVal transaction As MySqlTransaction,
                                   ByVal loginId As Integer,
                                   ByVal sessionId As String) As List(Of CartMutationExistingRow)
        Dim rows As New List(Of CartMutationExistingRow)()
        Using cmd As New MySqlCommand(
            "SELECT ID, ArticoliId, COALESCE(TCId,-1) AS TCId, COALESCE(Qnt,0) AS Qnt " &
            "FROM carrello WHERE " & OwnerWhere(loginId) & " ORDER BY ID FOR UPDATE",
            conn,
            transaction)
            AddOwnerParameter(cmd, loginId, sessionId)
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    Dim row As New CartMutationExistingRow With {
                        .Id = Convert.ToInt32(reader("ID"), CultureInfo.InvariantCulture),
                        .ArticleId = Convert.ToInt32(reader("ArticoliId"), CultureInfo.InvariantCulture),
                        .TCId = Convert.ToInt32(reader("TCId"), CultureInfo.InvariantCulture),
                        .Quantity = ReadDecimal(reader("Qnt"), 0D)
                    }
                    If row.Id <= 0 OrElse row.ArticleId <= 0 OrElse row.Quantity < 0D OrElse
                       row.Quantity > 9999999.99999999D Then
                        Throw New InvalidOperationException("Invalid owned cart row encountered during batch mutation.")
                    End If
                    rows.Add(row)
                End While
            End Using
        End Using
        Return rows
    End Function

    Private Function LoadOwnedRowIds(ByVal conn As MySqlConnection,
                                     ByVal transaction As MySqlTransaction,
                                     ByVal loginId As Integer,
                                     ByVal sessionId As String) As List(Of Integer)
        Dim rowIds As New List(Of Integer)()
        Using cmd As New MySqlCommand(
            "SELECT ID FROM carrello WHERE " & OwnerWhere(loginId) & " ORDER BY ID FOR UPDATE",
            conn,
            transaction)
            AddOwnerParameter(cmd, loginId, sessionId)
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    rowIds.Add(Convert.ToInt32(reader("ID"), CultureInfo.InvariantCulture))
                End While
            End Using
        End Using
        Return rowIds
    End Function

    Private Function CountOwnedRows(ByVal conn As MySqlConnection,
                                    ByVal transaction As MySqlTransaction,
                                    ByVal loginId As Integer,
                                    ByVal sessionId As String,
                                    ByVal cartRowId As Integer) As Integer
        Dim sql As String = "SELECT COUNT(*) FROM carrello WHERE " & OwnerWhere(loginId)
        If cartRowId > 0 Then sql &= " AND ID=?id"
        Using cmd As New MySqlCommand(sql, conn, transaction)
            AddOwnerParameter(cmd, loginId, sessionId)
            If cartRowId > 0 Then cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = cartRowId
            Return Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture)
        End Using
    End Function

    Private Function LoadOwnedArticleRows(ByVal conn As MySqlConnection,
                                          ByVal transaction As MySqlTransaction,
                                          ByVal loginId As Integer,
                                          ByVal sessionId As String,
                                          ByVal articleId As Integer) As List(Of CartMutationExistingRow)
        Dim rows As New List(Of CartMutationExistingRow)()
        Using cmd As New MySqlCommand(
            "SELECT ID, COALESCE(TCId,-1) AS TCId, COALESCE(Qnt,0) AS Qnt " &
            "FROM carrello WHERE " & OwnerWhere(loginId) & " AND ArticoliId=?articleId ORDER BY ID FOR UPDATE",
            conn,
            transaction)
            AddOwnerParameter(cmd, loginId, sessionId)
            cmd.Parameters.Add("?articleId", MySqlDbType.Int32).Value = articleId
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    rows.Add(New CartMutationExistingRow() With {
                        .Id = Convert.ToInt32(reader("ID"), CultureInfo.InvariantCulture),
                        .ArticleId = articleId,
                        .TCId = Convert.ToInt32(reader("TCId"), CultureInfo.InvariantCulture),
                        .Quantity = ReadDecimal(reader("Qnt"), 0D)
                    })
                End While
            End Using
        End Using
        Return rows
    End Function

    Private Function InsertRow(ByVal conn As MySqlConnection,
                               ByVal transaction As MySqlTransaction,
                               ByVal ctx As HttpContext,
                               ByVal loginId As Integer,
                               ByVal sessionId As String,
                               ByVal listino As Integer,
                               ByVal quantity As Decimal,
                               ByVal resolved As CartResolvedPrice,
                               ByVal freeShipping As Integer) As Integer
        Using cmd As New MySqlCommand(
            "INSERT INTO carrello (LoginId,SessionId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,OfferteDettaglioId,Prodotto_Gratis,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,IdEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva) " &
            "VALUES (?loginId,?sessionId,?articleId,?tcId,?code,?description,?quantity,?listino,?price,?priceIvato,?offerId,?freeShipping,?idIvaRC,?valoreIvaRC,?descrizioneIvaRC,?idEsenzioneIva,?valoreEsenzioneIva,?descrizioneEsenzioneIva)",
            conn,
            transaction)
            AddRowParameters(cmd, ctx, loginId, sessionId, listino, quantity, resolved, freeShipping)
            If cmd.ExecuteNonQuery() <> 1 Then Throw New InvalidOperationException("Standard cart insert did not affect exactly one row.")
            cmd.Parameters.Clear()
            cmd.CommandText = "SELECT LAST_INSERT_ID()"
            Dim insertedId As Integer = Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture)
            If insertedId <= 0 Then Throw New InvalidOperationException("Standard cart insert did not return an identifier.")
            Return insertedId
        End Using
    End Function

    Private Sub UpdateRow(ByVal conn As MySqlConnection,
                          ByVal transaction As MySqlTransaction,
                          ByVal ctx As HttpContext,
                          ByVal loginId As Integer,
                          ByVal sessionId As String,
                          ByVal cartRowId As Integer,
                          ByVal listino As Integer,
                          ByVal quantity As Decimal,
                          ByVal resolved As CartResolvedPrice,
                          ByVal freeShipping As Integer)
        Using cmd As New MySqlCommand(
            "UPDATE carrello SET Codice=?code,Descrizione1=?description,Qnt=?quantity,NListino=?listino,Prezzo=?price,PrezzoIvato=?priceIvato,OfferteDettaglioId=?offerId,Prodotto_Gratis=?freeShipping,IdIvaRC=?idIvaRC,ValoreIvaRC=?valoreIvaRC,DescrizioneIvaRC=?descrizioneIvaRC,IdEsenzioneIva=?idEsenzioneIva,ValoreEsenzioneIva=?valoreEsenzioneIva,DescrizioneEsenzioneIva=?descrizioneEsenzioneIva WHERE ID=?cartRowId AND " & OwnerWhere(loginId),
            conn,
            transaction)
            AddMutableRowParameters(cmd, ctx, listino, quantity, resolved, freeShipping)
            cmd.Parameters.Add("?cartRowId", MySqlDbType.Int32).Value = cartRowId
            AddOwnerParameter(cmd, loginId, sessionId)
            Dim affected As Integer = cmd.ExecuteNonQuery()
            If affected <> 1 AndAlso Not OwnedRowExists(conn, transaction, loginId, sessionId, cartRowId) Then
                Throw New InvalidOperationException("Standard cart update did not affect the expected row.")
            End If
        End Using
    End Sub

    Private Sub AddRowParameters(ByVal cmd As MySqlCommand,
                                 ByVal ctx As HttpContext,
                                 ByVal loginId As Integer,
                                 ByVal sessionId As String,
                                 ByVal listino As Integer,
                                 ByVal quantity As Decimal,
                                 ByVal resolved As CartResolvedPrice,
                                 ByVal freeShipping As Integer)
        cmd.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
        cmd.Parameters.Add("?sessionId", MySqlDbType.VarChar, 50).Value = If(loginId > 0, String.Empty, If(sessionId, String.Empty))
        cmd.Parameters.Add("?articleId", MySqlDbType.Int32).Value = resolved.ArticleId
        cmd.Parameters.Add("?tcId", MySqlDbType.Int32).Value = resolved.EffectiveTCId
        AddMutableRowParameters(cmd, ctx, listino, quantity, resolved, freeShipping)
    End Sub

    Private Sub AddMutableRowParameters(ByVal cmd As MySqlCommand,
                                        ByVal ctx As HttpContext,
                                        ByVal listino As Integer,
                                        ByVal quantity As Decimal,
                                        ByVal resolved As CartResolvedPrice,
                                        ByVal freeShipping As Integer)
        cmd.Parameters.Add("?code", MySqlDbType.VarChar, 50).Value = If(resolved.Code, String.Empty)
        cmd.Parameters.Add("?description", MySqlDbType.VarChar, 255).Value = If(resolved.Description, String.Empty)
        AddDecimalParameter(cmd, "?quantity", quantity)
        cmd.Parameters.Add("?listino", MySqlDbType.Int32).Value = listino
        AddDecimalParameter(cmd, "?price", resolved.Price)
        AddDecimalParameter(cmd, "?priceIvato", resolved.PriceIvato)
        cmd.Parameters.Add("?offerId", MySqlDbType.Int32).Value = resolved.OfferDetailId
        cmd.Parameters.Add("?freeShipping", MySqlDbType.Int32).Value = freeShipping
        cmd.Parameters.Add("?idIvaRC", MySqlDbType.Int32).Value = resolved.ReverseChargeVatId
        AddDecimalParameter(cmd, "?valoreIvaRC", resolved.ReverseChargeVatValue)
        cmd.Parameters.Add("?descrizioneIvaRC", MySqlDbType.VarChar, 255).Value = If(resolved.ReverseChargeDescription, String.Empty)
        cmd.Parameters.Add("?idEsenzioneIva", MySqlDbType.Int32).Value = SessionInt(ctx, "IdEsenzioneIva", -1)
        AddDecimalParameter(cmd, "?valoreEsenzioneIva", SessionDecimal(ctx, "Iva_Utente", -1D))
        cmd.Parameters.Add("?descrizioneEsenzioneIva", MySqlDbType.VarChar, 255).Value = SessionText(ctx, "DescrizioneEsenzioneIva", String.Empty)
    End Sub

    Private Sub DeleteOwnedRow(ByVal conn As MySqlConnection,
                               ByVal transaction As MySqlTransaction,
                               ByVal loginId As Integer,
                               ByVal sessionId As String,
                               ByVal rowId As Integer)
        Using cmd As New MySqlCommand("DELETE FROM carrello WHERE ID=?id AND " & OwnerWhere(loginId), conn, transaction)
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = rowId
            AddOwnerParameter(cmd, loginId, sessionId)
            If cmd.ExecuteNonQuery() <> 1 Then Throw New InvalidOperationException("Duplicate cart row deletion failed.")
        End Using
    End Sub

    Private Sub VerifyFinalRow(ByVal conn As MySqlConnection,
                               ByVal transaction As MySqlTransaction,
                               ByVal loginId As Integer,
                               ByVal sessionId As String,
                               ByVal cartRowId As Integer,
                               ByVal articleId As Integer,
                               ByVal tcId As Integer,
                               ByVal quantity As Decimal,
                               ByVal resolved As CartResolvedPrice)
        Using cmd As New MySqlCommand(
            "SELECT COUNT(*) FROM carrello WHERE " & OwnerWhere(loginId) &
            " AND ID=?id AND ArticoliId=?articleId AND COALESCE(TCId,-1)=?tcId " &
            "AND ABS(Qnt-?quantity)<0.00000001 AND ABS(Prezzo-?price)<0.00000001 " &
            "AND ABS(PrezzoIvato-?priceIvato)<0.00000001 AND COALESCE(OfferteDettaglioId,0)=?offerId " &
            "AND COALESCE(Prodotto_Gratis,0)=?freeShipping",
            conn,
            transaction)
            AddOwnerParameter(cmd, loginId, sessionId)
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = cartRowId
            cmd.Parameters.Add("?articleId", MySqlDbType.Int32).Value = articleId
            cmd.Parameters.Add("?tcId", MySqlDbType.Int32).Value = tcId
            AddDecimalParameter(cmd, "?quantity", quantity)
            AddDecimalParameter(cmd, "?price", resolved.Price)
            AddDecimalParameter(cmd, "?priceIvato", resolved.PriceIvato)
            cmd.Parameters.Add("?offerId", MySqlDbType.Int32).Value = resolved.OfferDetailId
            cmd.Parameters.Add("?freeShipping", MySqlDbType.Int32).Value = If(resolved.FreeShipping <> 0, 1, 0)
            If Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture) <> 1 Then
                Throw New InvalidOperationException("Final standard cart state verification failed.")
            End If
        End Using
    End Sub

    Private Sub VerifySingleOwnedProductRow(ByVal conn As MySqlConnection,
                                            ByVal transaction As MySqlTransaction,
                                            ByVal loginId As Integer,
                                            ByVal sessionId As String,
                                            ByVal articleId As Integer,
                                            ByVal tcId As Integer)
        Using cmd As New MySqlCommand(
            "SELECT COUNT(*) FROM carrello WHERE " & OwnerWhere(loginId) &
            " AND ArticoliId=?articleId AND COALESCE(TCId,-1)=?tcId",
            conn,
            transaction)
            AddOwnerParameter(cmd, loginId, sessionId)
            cmd.Parameters.Add("?articleId", MySqlDbType.Int32).Value = articleId
            cmd.Parameters.Add("?tcId", MySqlDbType.Int32).Value = NormalizeTCId(tcId)
            If Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture) <> 1 Then
                Throw New InvalidOperationException("Final standard cart batch contains duplicate or missing rows.")
            End If
        End Using
    End Sub

    Private Function OwnedRowExists(ByVal conn As MySqlConnection,
                                    ByVal transaction As MySqlTransaction,
                                    ByVal loginId As Integer,
                                    ByVal sessionId As String,
                                    ByVal rowId As Integer) As Boolean
        Using cmd As New MySqlCommand("SELECT COUNT(*) FROM carrello WHERE ID=?id AND " & OwnerWhere(loginId), conn, transaction)
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = rowId
            AddOwnerParameter(cmd, loginId, sessionId)
            Return Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture) = 1
        End Using
    End Function

    Private Sub EnsureResolved(ByVal resolved As CartResolvedPrice)
        If resolved Is Nothing OrElse resolved.HasTechnicalError Then Throw New InvalidOperationException("Commercial price resolution failed.")
        If resolved.HasCommercialRuleError Then Throw New InvalidOperationException("Ambiguous commercial quantity rule was rejected.")
        If Not resolved.IsValid Then Throw New InvalidOperationException("Commercial price is not available.")
    End Sub

    Private Sub ValidateQuantity(ByVal quantity As Decimal)
        If Not IsValidQuantity(quantity) Then Throw New ArgumentOutOfRangeException("quantity")
    End Sub

    Private Function IsValidQuantity(ByVal quantity As Decimal) As Boolean
        Return quantity > 0D AndAlso quantity <= 9999999.99999999D
    End Function

    Private Function NormalizeTCId(ByVal tcId As Integer) As Integer
        Return If(tcId > 0, tcId, -1)
    End Function

    Private Function BatchKey(ByVal articleId As Integer, ByVal tcId As Integer) As String
        Return articleId.ToString(CultureInfo.InvariantCulture) & ":" &
               NormalizeTCId(tcId).ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function CompareBatchRequests(ByVal left As CartStandardBatchMutationRequest,
                                          ByVal right As CartStandardBatchMutationRequest) As Integer
        Dim articleCompare As Integer = left.ArticleId.CompareTo(right.ArticleId)
        If articleCompare <> 0 Then Return articleCompare
        Return NormalizeTCId(left.RequestedTCId).CompareTo(NormalizeTCId(right.RequestedTCId))
    End Function

    Private Function OwnerWhere(ByVal loginId As Integer) As String
        Return If(loginId > 0, "LoginId=?ownerLoginId", "COALESCE(LoginId,0)<=0 AND SessionId=?ownerSessionId")
    End Function

    Private Sub AddOwnerParameter(ByVal cmd As MySqlCommand, ByVal loginId As Integer, ByVal sessionId As String)
        If loginId > 0 Then
            cmd.Parameters.Add("?ownerLoginId", MySqlDbType.Int32).Value = loginId
        Else
            cmd.Parameters.Add("?ownerSessionId", MySqlDbType.VarChar, 50).Value = If(sessionId, String.Empty)
        End If
    End Sub

    Private Sub AddDecimalParameter(ByVal cmd As MySqlCommand, ByVal name As String, ByVal value As Decimal)
        Dim parameter As MySqlParameter = cmd.Parameters.Add(name, MySqlDbType.Decimal)
        parameter.Precision = 15
        parameter.Scale = 8
        parameter.Value = value
    End Sub

    Private Function ReadDecimal(ByVal value As Object, ByVal defaultValue As Decimal) As Decimal
        If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
        Try
            Return Convert.ToDecimal(value, CultureInfo.InvariantCulture)
        Catch
            Return defaultValue
        End Try
    End Function

    Private Function SessionInt(ByVal ctx As HttpContext, ByVal key As String, ByVal defaultValue As Integer) As Integer
        Dim parsed As Integer
        If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing AndAlso ctx.Session(key) IsNot Nothing AndAlso
           Integer.TryParse(Convert.ToString(ctx.Session(key), CultureInfo.InvariantCulture), parsed) Then Return parsed
        Return defaultValue
    End Function

    Private Function SessionDecimal(ByVal ctx As HttpContext, ByVal key As String, ByVal defaultValue As Decimal) As Decimal
        If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse ctx.Session(key) Is Nothing Then Return defaultValue
        Return ReadDecimal(ctx.Session(key), defaultValue)
    End Function

    Private Function SessionText(ByVal ctx As HttpContext, ByVal key As String, ByVal defaultValue As String) As String
        If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse ctx.Session(key) Is Nothing Then Return defaultValue
        Return Convert.ToString(ctx.Session(key))
    End Function

    Private Function BlockingResult(ByVal message As String) As CartPriceRevalidationResult
        Return New CartPriceRevalidationResult() With {.HasBlockingError = True, .ErrorMessage = message}
    End Function

    Private Function TechnicalResult() As CartPriceRevalidationResult
        Return New CartPriceRevalidationResult() With {
            .HasBlockingError = True,
            .HasTechnicalError = True,
            .ErrorMessage = CartPriceRevalidationHelper.GenericTechnicalErrorMessage
        }
    End Function

End Module
