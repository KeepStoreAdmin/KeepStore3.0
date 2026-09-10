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

        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return result

        Dim execution As CartTransactionExecutionResult(Of CartOwnershipMergeResult) =
            CartTransactionRetryPolicy.Execute(Of CartOwnershipMergeResult)(
                settings.ConnectionString,
                IsolationLevel.Serializable,
                "merge-anonymous-account",
                CartMutationIdempotencyService.GetCurrentRequestId(ctx),
                Function(conn As MySqlConnection, transaction As MySqlTransaction) As CartTransactionWorkResult(Of CartOwnershipMergeResult)
            Dim attemptLoginId As Integer = SessionInteger(ctx, "LoginId", SessionInteger(ctx, "LoginID", loginId))
            Dim attemptListino As Integer = SessionInteger(ctx, "Listino", SessionInteger(ctx, "listino", listino))
            Dim attemptSessionId As String = Convert.ToString(ctx.Session.SessionID)
            If attemptLoginId <= 0 OrElse attemptListino <= 0 OrElse String.IsNullOrWhiteSpace(attemptSessionId) Then
                Return CartTransactionWorkResult(Of CartOwnershipMergeResult).Abort(New CartOwnershipMergeResult())
            End If

            Dim attemptResult As New CartOwnershipMergeResult()

            Dim rows As List(Of CartOwnershipRow) = LoadOwnedRows(conn, transaction, attemptLoginId, attemptSessionId)
            If rows.Count > 0 Then
                MergeRows(conn, transaction, rows, attemptLoginId, attemptSessionId, attemptListino, attemptResult)

                attemptResult.PriceRevalidation = CartPriceRevalidationHelper.RevalidateCurrentCart(
                    ctx, conn, transaction, attemptLoginId, String.Empty, attemptListino,
                    True, True, Nothing, True)
                If attemptResult.PriceRevalidation Is Nothing OrElse attemptResult.PriceRevalidation.HasBlockingError Then
                    Throw New InvalidOperationException("Post-login cart price revalidation did not complete.")
                End If
            End If

            If CountAnonymousRows(conn, transaction, attemptSessionId) <> 0 Then
                Throw New InvalidOperationException("Anonymous cart ownership transfer was incomplete.")
            End If

            Return CartTransactionWorkResult(Of CartOwnershipMergeResult).Commit(attemptResult)
                End Function)

        If execution.IsIndeterminate Then CartMutationIdempotencyService.MarkCurrentIntentIndeterminate(ctx)
        If execution.Succeeded AndAlso execution.Value IsNot Nothing Then
            result = execution.Value
            result.Succeeded = True
            If result.PriceRevalidation IsNot Nothing AndAlso result.PriceRevalidation.HasChanges Then
                CartPriceRevalidationHelper.StoreResultInSession(ctx, result.PriceRevalidation)
            End If
        Else
            If result.PriceRevalidation Is Nothing OrElse Not result.PriceRevalidation.HasBlockingError Then
                result.PriceRevalidation = New CartPriceRevalidationResult() With {
                    .HasBlockingError = True,
                    .HasTechnicalError = True,
                    .ErrorMessage = "Non è stato possibile sincronizzare il carrello. Ricarica la pagina prima di procedere con l'ordine."
                }
            End If
            CartPriceRevalidationHelper.StoreResultInSession(ctx, result.PriceRevalidation)
        End If

        Return result
    End Function

    Private Function LoadOwnedRows(ByVal conn As MySqlConnection,
                                   ByVal transaction As MySqlTransaction,
                                   ByVal loginId As Integer,
                                   ByVal sessionId As String) As List(Of CartOwnershipRow)
        Dim rows As New List(Of CartOwnershipRow)()
        AppendOwnedRows(
            conn,
            transaction,
            "SELECT ID, COALESCE(LoginId,0) AS LoginId, COALESCE(SessionId,'') AS SessionId, " &
            "ArticoliId, COALESCE(TCId,-1) AS TCId, COALESCE(Qnt,0) AS Qnt " &
            "FROM carrello FORCE INDEX (IX_carrello_LoginId_ID) " &
            "WHERE LoginId=?ownerId ORDER BY ID FOR UPDATE",
            "?ownerId",
            loginId,
            rows)
        AppendOwnedRows(
            conn,
            transaction,
            "SELECT ID, COALESCE(LoginId,0) AS LoginId, COALESCE(SessionId,'') AS SessionId, " &
            "ArticoliId, COALESCE(TCId,-1) AS TCId, COALESCE(Qnt,0) AS Qnt " &
            "FROM carrello FORCE INDEX (IX_carrello_SessionId_ID) " &
            "WHERE SessionId=?ownerId AND COALESCE(LoginId,0)<=0 ORDER BY ID FOR UPDATE",
            "?ownerId",
            sessionId,
            rows)
        Return rows
    End Function

    Private Sub AppendOwnedRows(ByVal conn As MySqlConnection,
                                ByVal transaction As MySqlTransaction,
                                ByVal sql As String,
                                ByVal parameterName As String,
                                ByVal ownerId As Object,
                                ByVal rows As List(Of CartOwnershipRow))
        Using cmd As New MySqlCommand(
            sql,
            conn,
            transaction)
            If TypeOf ownerId Is Integer Then
                cmd.Parameters.Add(parameterName, MySqlDbType.Int32).Value = Convert.ToInt32(ownerId, CultureInfo.InvariantCulture)
            Else
                cmd.Parameters.Add(parameterName, MySqlDbType.VarChar, 50).Value = Convert.ToString(ownerId, CultureInfo.InvariantCulture)
            End If
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
    End Sub

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

    Private Function SessionInteger(ByVal ctx As HttpContext, ByVal key As String, ByVal fallback As Integer) As Integer
        Dim parsed As Integer
        If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing AndAlso
           Integer.TryParse(Convert.ToString(ctx.Session(key)), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed) Then Return parsed
        Return fallback
    End Function

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
