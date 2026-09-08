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
    Public Property ProductName As String
    Public Property Price As Decimal
    Public Property PriceIvato As Decimal
    Public Property OfferDetailId As Integer
    Public Property ErrorMessage As String
End Class

Friend Class CartMutationExistingRow
    Public Property Id As Integer
    Public Property TCId As Integer
    Public Property Quantity As Decimal
End Class

Public Module CartMutationService
    Private Const GenericMutationError As String = "Non è stato possibile aggiornare il carrello. Riprova."

    Public Function AddStandardProductForCurrentOwner(ByVal ctx As HttpContext,
                                                       ByVal articleId As Integer,
                                                       ByVal requestedTCId As Integer,
                                                       ByVal quantityToAdd As Decimal) As CartStandardMutationResult
        If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return New CartStandardMutationResult With {.ErrorMessage = GenericMutationError}

        Dim loginId As Integer = SessionInteger(ctx, "LoginId", SessionInteger(ctx, "LoginID", 0))
        Dim sessionId As String = If(loginId > 0, String.Empty, ctx.Session.SessionID)
        Dim listino As Integer = SessionInteger(ctx, "Listino", SessionInteger(ctx, "listino", 1))
        If listino <= 0 Then listino = 1
        Return AddStandardProduct(ctx, loginId, sessionId, articleId, requestedTCId, quantityToAdd, listino)
    End Function

    Public Function SetStandardProductQuantityForCurrentOwner(ByVal ctx As HttpContext,
                                                              ByVal articleId As Integer,
                                                              ByVal requestedTCId As Integer,
                                                              ByVal desiredQuantity As Decimal) As CartStandardMutationResult
        If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return New CartStandardMutationResult With {.ErrorMessage = GenericMutationError}

        Dim loginId As Integer = SessionInteger(ctx, "LoginId", SessionInteger(ctx, "LoginID", 0))
        Dim sessionId As String = If(loginId > 0, String.Empty, ctx.Session.SessionID)
        Dim listino As Integer = SessionInteger(ctx, "Listino", SessionInteger(ctx, "listino", 1))
        If listino <= 0 Then listino = 1
        Return MutateStandardProduct(ctx, loginId, sessionId, articleId, requestedTCId, desiredQuantity, listino, True)
    End Function

    Public Function AddStandardProduct(ByVal ctx As HttpContext,
                                       ByVal loginId As Integer,
                                       ByVal sessionId As String,
                                       ByVal articleId As Integer,
                                       ByVal requestedTCId As Integer,
                                       ByVal quantityToAdd As Decimal,
                                       ByVal listino As Integer) As CartStandardMutationResult
        Return MutateStandardProduct(ctx, loginId, sessionId, articleId, requestedTCId, quantityToAdd, listino, False)
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
        Dim conn As MySqlConnection = Nothing
        Dim transaction As MySqlTransaction = Nothing
        Try
            If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse articleId <= 0 OrElse
               (If(setAbsoluteQuantity, quantityValue <= 0D, quantityValue = 0D)) OrElse listino <= 0 OrElse
               (loginId <= 0 AndAlso String.IsNullOrWhiteSpace(sessionId)) Then Return result

            conn = New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            transaction = conn.BeginTransaction(IsolationLevel.Serializable)

            Dim ownedArticleRows As List(Of CartMutationExistingRow) = LoadOwnedArticleRows(
                conn, transaction, loginId, sessionId, articleId)
            Dim eligibilityContext As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateContext(ctx, listino)
            Dim probeQuantity As Decimal = If(quantityValue > 0D, quantityValue, 1D)
            Dim preliminary As CartResolvedPrice = CartPriceRevalidationHelper.ResolveStandardPrice(
                ctx, conn, transaction, eligibilityContext, articleId, requestedTCId, probeQuantity, listino, True)
            EnsureResolved(preliminary)

            Dim effectiveTCId As Integer = preliminary.EffectiveTCId
            Dim existing As List(Of CartMutationExistingRow) = ownedArticleRows.FindAll(
                Function(row As CartMutationExistingRow) NormalizeTCId(row.TCId) = effectiveTCId)
            If Not setAbsoluteQuantity AndAlso existing.Count = 0 AndAlso quantityValue < 0D Then Return result

            Dim finalQuantity As Decimal = quantityValue
            If Not setAbsoluteQuantity Then
                For Each row As CartMutationExistingRow In existing
                    finalQuantity = Decimal.Add(finalQuantity, row.Quantity)
                Next
            End If

            ValidateQuantity(finalQuantity)

            Dim resolved As CartResolvedPrice = CartPriceRevalidationHelper.ResolveStandardPrice(
                ctx, conn, transaction, eligibilityContext, articleId, effectiveTCId, finalQuantity, listino, True)
            EnsureResolved(resolved)
            Dim freeShipping As Integer = If(resolved.FreeShipping <> 0, 1, 0)

            Dim cartRowId As Integer
            If existing.Count = 0 Then
                cartRowId = InsertRow(conn, transaction, ctx, loginId, sessionId, listino, finalQuantity, resolved, freeShipping)
            Else
                cartRowId = existing(0).Id
                UpdateRow(conn, transaction, ctx, loginId, sessionId, cartRowId, listino, finalQuantity, resolved, freeShipping)
                For i As Integer = 1 To existing.Count - 1
                    DeleteOwnedRow(conn, transaction, loginId, sessionId, existing(i).Id)
                Next
            End If

            VerifyFinalRow(conn, transaction, loginId, sessionId, cartRowId, articleId, effectiveTCId, finalQuantity, resolved)
            transaction.Commit()
            transaction.Dispose()
            transaction = Nothing

            result.Succeeded = True
            result.CartRowId = cartRowId
            result.TCId = effectiveTCId
            result.Quantity = finalQuantity
            result.ProductName = resolved.Description
            result.Price = resolved.Price
            result.PriceIvato = resolved.PriceIvato
            result.OfferDetailId = resolved.OfferDetailId
            result.ErrorMessage = String.Empty
        Catch ex As Exception
            TryRollback(transaction, ctx, If(setAbsoluteQuantity, "set-standard", "add-standard"))
            LogFailure(ctx, If(setAbsoluteQuantity, "Atomic standard cart quantity update failed", "Atomic standard cart add failed"), ex)
        Finally
            If transaction IsNot Nothing Then transaction.Dispose()
            If conn IsNot Nothing Then conn.Dispose()
        End Try
        Return result
    End Function

    Private Function SessionInteger(ByVal ctx As HttpContext, ByVal key As String, ByVal fallback As Integer) As Integer
        Dim parsed As Integer
        If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing AndAlso
           Integer.TryParse(Convert.ToString(ctx.Session(key)), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed) Then Return parsed
        Return fallback
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

        Dim conn As MySqlConnection = Nothing
        Dim transaction As MySqlTransaction = Nothing
        Try
            conn = New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            transaction = conn.BeginTransaction(IsolationLevel.Serializable)
            Dim result As CartPriceRevalidationResult = CartPriceRevalidationHelper.RevalidateCurrentCart(
                ctx, conn, transaction, loginId, sessionId, listino, True, True, quantityOverrides)
            If result Is Nothing OrElse result.HasBlockingError Then
                TryRollback(transaction, ctx, "update-quantities")
                transaction.Dispose()
                transaction = Nothing
                Return If(result, TechnicalResult())
            End If
            transaction.Commit()
            transaction.Dispose()
            transaction = Nothing
            Return result
        Catch ex As Exception
            TryRollback(transaction, ctx, "update-quantities")
            LogFailure(ctx, "Atomic cart quantity update failed", ex)
            Return TechnicalResult()
        Finally
            If transaction IsNot Nothing Then transaction.Dispose()
            If conn IsNot Nothing Then conn.Dispose()
        End Try
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

    Private Sub TryRollback(ByVal transaction As MySqlTransaction, ByVal ctx As HttpContext, ByVal operationName As String)
        If transaction Is Nothing Then Return
        Try
            transaction.Rollback()
        Catch rollbackError As Exception
            LogFailure(ctx, "Rollback failed for " & operationName, rollbackError)
        End Try
    End Sub

    Private Sub LogFailure(ByVal ctx As HttpContext, ByVal message As String, ByVal ex As Exception)
        Try
            KeepStoreLog.Error("cart-mutation", message & ". Error type: " & ex.GetType().Name & ".", Nothing, ctx)
        Catch logError As Exception
            System.Diagnostics.Trace.TraceError("cart-mutation logging failed. Error type: " & logError.GetType().Name & ".")
        End Try
    End Sub
End Module
