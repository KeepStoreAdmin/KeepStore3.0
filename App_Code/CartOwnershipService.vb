Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class CartOwnershipMergeResult
    Public Property Succeeded As Boolean
    Public Property RowsTransferred As Integer
    Public Property RowsMerged As Integer
    Public Property PriceRevalidation As CartPriceRevalidationResult
End Class

Friend Class CartOwnershipRow
    Public Property Id As Integer
    Public Property LoginId As Integer
    Public Property SessionId As String
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property Quantity As Decimal

    Public ReadOnly Property IsAnonymous As Boolean
        Get
            Return LoginId <= 0
        End Get
    End Property
End Class

Public Module CartOwnershipService
    Public Function MergeAnonymousCartIntoAccount(ByVal ctx As HttpContext,
                                                   ByVal loginId As Integer,
                                                   ByVal listino As Integer) As CartOwnershipMergeResult
        Dim result As New CartOwnershipMergeResult()
        If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse loginId <= 0 OrElse listino <= 0 Then Return result

        Dim sessionId As String = Convert.ToString(ctx.Session.SessionID)
        If String.IsNullOrWhiteSpace(sessionId) Then Return result

        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return result

        Dim conn As MySqlConnection = Nothing
        Dim transaction As MySqlTransaction = Nothing
        Try
            conn = New MySqlConnection(settings.ConnectionString)
            conn.Open()
            transaction = conn.BeginTransaction(IsolationLevel.Serializable)

            Dim rows As List(Of CartOwnershipRow) = LoadOwnedRows(conn, transaction, loginId, sessionId)
            If rows.Count > 0 Then
                MergeRows(conn, transaction, rows, loginId, sessionId, listino, result)

                result.PriceRevalidation = CartPriceRevalidationHelper.RevalidateCurrentCart(
                    ctx, conn, transaction, loginId, String.Empty, listino, True, True, Nothing)
                If result.PriceRevalidation Is Nothing OrElse result.PriceRevalidation.HasBlockingError Then
                    Throw New InvalidOperationException("Post-login cart price revalidation did not complete.")
                End If
            End If

            If CountAnonymousRows(conn, transaction, sessionId) <> 0 Then
                Throw New InvalidOperationException("Anonymous cart ownership transfer was incomplete.")
            End If

            transaction.Commit()
            transaction.Dispose()
            transaction = Nothing
            result.Succeeded = True

            If result.PriceRevalidation IsNot Nothing AndAlso result.PriceRevalidation.HasChanges Then
                CartPriceRevalidationHelper.StoreResultInSession(ctx, result.PriceRevalidation)
            End If
        Catch ex As Exception
            TryRollback(transaction, ctx)
            LogFailure(ctx, "Post-login cart ownership merge failed", ex)
            If result.PriceRevalidation Is Nothing OrElse Not result.PriceRevalidation.HasBlockingError Then
                result.PriceRevalidation = New CartPriceRevalidationResult() With {
                    .HasBlockingError = True,
                    .HasTechnicalError = True,
                    .ErrorMessage = "Non è stato possibile sincronizzare il carrello. Ricarica la pagina prima di procedere con l'ordine."
                }
            End If
            CartPriceRevalidationHelper.StoreResultInSession(ctx, result.PriceRevalidation)
        Finally
            If transaction IsNot Nothing Then transaction.Dispose()
            If conn IsNot Nothing Then conn.Dispose()
        End Try

        Return result
    End Function

    Private Function LoadOwnedRows(ByVal conn As MySqlConnection,
                                   ByVal transaction As MySqlTransaction,
                                   ByVal loginId As Integer,
                                   ByVal sessionId As String) As List(Of CartOwnershipRow)
        Dim rows As New List(Of CartOwnershipRow)()
        Using cmd As New MySqlCommand(
            "SELECT ID, COALESCE(LoginId,0) AS LoginId, COALESCE(SessionId,'') AS SessionId, " &
            "ArticoliId, COALESCE(TCId,-1) AS TCId, COALESCE(Qnt,0) AS Qnt " &
            "FROM carrello WHERE LoginId=?loginId OR (COALESCE(LoginId,0)<=0 AND SessionId=?sessionId) " &
            "ORDER BY ID FOR UPDATE",
            conn,
            transaction)
            cmd.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
            cmd.Parameters.Add("?sessionId", MySqlDbType.VarChar, 50).Value = sessionId
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                While reader.Read()
                    Dim row As New CartOwnershipRow() With {
                        .Id = ReadInt(reader("ID"), 0),
                        .LoginId = ReadInt(reader("LoginId"), 0),
                        .SessionId = Convert.ToString(reader("SessionId")),
                        .ArticleId = ReadInt(reader("ArticoliId"), 0),
                        .TCId = ReadInt(reader("TCId"), -1),
                        .Quantity = ReadDecimal(reader("Qnt"), 0D)
                    }
                    If row.Id <= 0 OrElse row.ArticleId <= 0 OrElse row.Quantity <= 0D Then
                        Throw New InvalidOperationException("Invalid cart row encountered during ownership merge.")
                    End If
                    rows.Add(row)
                End While
            End Using
        End Using
        Return rows
    End Function

    Private Sub MergeRows(ByVal conn As MySqlConnection,
                          ByVal transaction As MySqlTransaction,
                          ByVal rows As List(Of CartOwnershipRow),
                          ByVal loginId As Integer,
                          ByVal sessionId As String,
                          ByVal listino As Integer,
                          ByVal result As CartOwnershipMergeResult)
        Dim groups As New Dictionary(Of String, List(Of CartOwnershipRow))(StringComparer.Ordinal)
        For Each row As CartOwnershipRow In rows
            Dim key As String = row.ArticleId.ToString(CultureInfo.InvariantCulture) & ":" &
                                NormalizeTCId(row.TCId).ToString(CultureInfo.InvariantCulture)
            If Not groups.ContainsKey(key) Then groups(key) = New List(Of CartOwnershipRow)()
            groups(key).Add(row)
        Next

        Dim keys As New List(Of String)(groups.Keys)
        keys.Sort(StringComparer.Ordinal)
        For Each key As String In keys
            Dim group As List(Of CartOwnershipRow) = groups(key)
            Dim canonical As CartOwnershipRow = ChooseCanonicalRow(group)
            Dim total As Decimal = 0D
            For Each row As CartOwnershipRow In group
                total = Decimal.Add(total, row.Quantity)
            Next
            If total <= 0D OrElse total > 9999999.99999999D Then
                Throw New OverflowException("Merged cart quantity is outside the supported range.")
            End If

            UpdateOwnedRow(conn, transaction, canonical, loginId, sessionId, listino, total)
            If canonical.IsAnonymous Then result.RowsTransferred += 1

            For Each duplicate As CartOwnershipRow In group
                If duplicate.Id = canonical.Id Then Continue For
                DeleteOwnedRow(conn, transaction, duplicate, loginId, sessionId)
                result.RowsMerged += 1
                If duplicate.IsAnonymous Then result.RowsTransferred += 1
            Next
        Next
    End Sub

    Private Function ChooseCanonicalRow(ByVal rows As List(Of CartOwnershipRow)) As CartOwnershipRow
        Dim best As CartOwnershipRow = Nothing
        For Each row As CartOwnershipRow In rows
            If best Is Nothing OrElse
               (best.IsAnonymous AndAlso Not row.IsAnonymous) OrElse
               (best.IsAnonymous = row.IsAnonymous AndAlso row.Id < best.Id) Then
                best = row
            End If
        Next
        Return best
    End Function

    Private Sub UpdateOwnedRow(ByVal conn As MySqlConnection,
                               ByVal transaction As MySqlTransaction,
                               ByVal row As CartOwnershipRow,
                               ByVal loginId As Integer,
                               ByVal sessionId As String,
                               ByVal listino As Integer,
                               ByVal quantity As Decimal)
        Using cmd As New MySqlCommand(
            "UPDATE carrello SET LoginId=?targetLoginId, SessionId='', NListino=?listino, " &
            "Qnt=?quantity WHERE ID=?id AND " & OriginalOwnerWhere(row),
            conn,
            transaction)
            cmd.Parameters.Add("?targetLoginId", MySqlDbType.Int32).Value = loginId
            cmd.Parameters.Add("?listino", MySqlDbType.Int32).Value = listino
            AddDecimalParameter(cmd, "?quantity", quantity)
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = row.Id
            AddOriginalOwnerParameter(cmd, row, loginId, sessionId)
            Dim affected As Integer = cmd.ExecuteNonQuery()
            If affected <> 1 AndAlso Not IsOwnedByLogin(conn, transaction, row.Id, loginId) Then
                Throw New InvalidOperationException("Cart row ownership update did not affect the expected row.")
            End If
        End Using
    End Sub

    Private Sub DeleteOwnedRow(ByVal conn As MySqlConnection,
                               ByVal transaction As MySqlTransaction,
                               ByVal row As CartOwnershipRow,
                               ByVal loginId As Integer,
                               ByVal sessionId As String)
        Using cmd As New MySqlCommand("DELETE FROM carrello WHERE ID=?id AND " & OriginalOwnerWhere(row), conn, transaction)
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = row.Id
            AddOriginalOwnerParameter(cmd, row, loginId, sessionId)
            If cmd.ExecuteNonQuery() <> 1 Then
                Throw New InvalidOperationException("Cart duplicate deletion did not affect exactly one owned row.")
            End If
        End Using
    End Sub

    Private Function CountAnonymousRows(ByVal conn As MySqlConnection,
                                        ByVal transaction As MySqlTransaction,
                                        ByVal sessionId As String) As Integer
        Using cmd As New MySqlCommand(
            "SELECT COUNT(*) FROM carrello WHERE COALESCE(LoginId,0)<=0 AND SessionId=?sessionId",
            conn,
            transaction)
            cmd.Parameters.Add("?sessionId", MySqlDbType.VarChar, 50).Value = sessionId
            Return Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture)
        End Using
    End Function

    Private Function IsOwnedByLogin(ByVal conn As MySqlConnection,
                                    ByVal transaction As MySqlTransaction,
                                    ByVal rowId As Integer,
                                    ByVal loginId As Integer) As Boolean
        Using cmd As New MySqlCommand("SELECT COUNT(*) FROM carrello WHERE ID=?id AND LoginId=?loginId", conn, transaction)
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = rowId
            cmd.Parameters.Add("?loginId", MySqlDbType.Int32).Value = loginId
            Return Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture) = 1
        End Using
    End Function

    Private Function OriginalOwnerWhere(ByVal row As CartOwnershipRow) As String
        If row IsNot Nothing AndAlso Not row.IsAnonymous Then Return "LoginId=?ownerLoginId"
        Return "COALESCE(LoginId,0)<=0 AND SessionId=?ownerSessionId"
    End Function

    Private Sub AddOriginalOwnerParameter(ByVal cmd As MySqlCommand,
                                          ByVal row As CartOwnershipRow,
                                          ByVal loginId As Integer,
                                          ByVal sessionId As String)
        If row IsNot Nothing AndAlso Not row.IsAnonymous Then
            cmd.Parameters.Add("?ownerLoginId", MySqlDbType.Int32).Value = loginId
        Else
            cmd.Parameters.Add("?ownerSessionId", MySqlDbType.VarChar, 50).Value = sessionId
        End If
    End Sub

    Private Sub AddDecimalParameter(ByVal cmd As MySqlCommand, ByVal name As String, ByVal value As Decimal)
        Dim parameter As MySqlParameter = cmd.Parameters.Add(name, MySqlDbType.Decimal)
        parameter.Precision = 15
        parameter.Scale = 8
        parameter.Value = value
    End Sub

    Private Function NormalizeTCId(ByVal tcId As Integer) As Integer
        Return If(tcId > 0, tcId, -1)
    End Function

    Private Sub TryRollback(ByVal transaction As MySqlTransaction, ByVal ctx As HttpContext)
        If transaction Is Nothing Then Return
        Try
            transaction.Rollback()
        Catch rollbackError As Exception
            LogFailure(ctx, "Post-login cart ownership rollback failed", rollbackError)
        End Try
    End Sub

    Private Sub LogFailure(ByVal ctx As HttpContext, ByVal message As String, ByVal ex As Exception)
        Try
            KeepStoreLog.Error("cart-ownership", message & ". Error type: " & ex.GetType().Name & ".", Nothing, ctx)
        Catch logError As Exception
            System.Diagnostics.Trace.TraceError("cart-ownership logging failed. Error type: " & logError.GetType().Name & ".")
        End Try
    End Sub

    Private Function ReadInt(ByVal value As Object, ByVal defaultValue As Integer) As Integer
        If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
        Dim parsed As Integer
        If Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), parsed) Then Return parsed
        Return defaultValue
    End Function

    Private Function ReadDecimal(ByVal value As Object, ByVal defaultValue As Decimal) As Decimal
        If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
        Try
            Return Convert.ToDecimal(value, CultureInfo.InvariantCulture)
        Catch
            Return defaultValue
        End Try
    End Function
End Module
