Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class PayPalPaymentDocumentInfo
    Public Property Exists As Boolean
    Public Property DocumentId As Integer
    Public Property UtentiId As Integer
    Public Property DocumentNumber As Integer
    Public Property DocumentDate As DateTime
    Public Property Pagato As Integer
    Public Property PaymentOnline As Integer
    Public Property TotalDocument As Decimal
    Public Property TransactionId As String
End Class

Public Module PayPalPaymentState
    Public Const PAYPAL_ONLINE_VALUE As Integer = 2

    Public Function LoadDocumentForUser(ByVal documentId As Integer, ByVal utentiId As Integer) As PayPalPaymentDocumentInfo
        Dim info As New PayPalPaymentDocumentInfo()
        If documentId <= 0 OrElse utentiId <= 0 Then Return info

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT d.id, d.UtentiId, COALESCE(d.NDocumento,0) AS NDocumento, d.DataDocumento, COALESCE(d.Pagato,0) AS Pagato, COALESCE(p.OnLine,0) AS PaymentOnline, COALESCE(pie.TotaleDocumento,0) AS TotaleDocumento, COALESCE(d.IdTransazione,'') AS IdTransazione FROM documenti d LEFT JOIN pagamentitipo p ON p.id=d.PagamentiTipoId LEFT JOIN documentipie pie ON pie.DocumentiId=d.id WHERE d.id=@id AND d.UtentiId=@uid LIMIT 1", conn)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    cmd.Parameters.Add("@uid", MySqlDbType.Int32).Value = utentiId

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            info.Exists = True
                            info.DocumentId = SafeInt(dr("id"), 0)
                            info.UtentiId = SafeInt(dr("UtentiId"), 0)
                            info.DocumentNumber = SafeInt(dr("NDocumento"), 0)
                            info.DocumentDate = SafeDate(dr("DataDocumento"), DateTime.MinValue)
                            info.Pagato = SafeInt(dr("Pagato"), 0)
                            info.PaymentOnline = SafeInt(dr("PaymentOnline"), 0)
                            info.TotalDocument = SafeDecimal(dr("TotaleDocumento"), 0D)
                            info.TransactionId = Convert.ToString(dr("IdTransazione"))
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-payment-state", "LoadDocumentForUser documentId=" & documentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        End Try

        Return info
    End Function

    Public Function MarkPending(ByVal documentId As Integer, ByVal message As String, Optional ByVal conn As MySqlConnection = Nothing, Optional ByVal trns As MySqlTransaction = Nothing) As Integer
        Return UpdatePaymentState(documentId, 1, message, True, conn, trns)
    End Function

    Public Function MarkFailed(ByVal documentId As Integer, ByVal message As String) As Integer
        Return UpdatePaymentState(documentId, 3, message, True, Nothing, Nothing)
    End Function

    Public Function MarkCanceled(ByVal documentId As Integer, ByVal message As String) As Integer
        Return UpdatePaymentState(documentId, 4, message, True, Nothing, Nothing)
    End Function

    Public Function MarkPendingWithTransaction(ByVal documentId As Integer, ByVal message As String, ByVal transactionId As String) As Integer
        Return UpdatePaymentState(documentId, 1, message, True, Nothing, Nothing, transactionId)
    End Function

    Public Function MarkCompleted(ByVal documentId As Integer, ByVal transactionId As String, ByVal message As String) As Integer
        If documentId <= 0 Then Return 0

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("UPDATE documenti SET Pagato=1, IdTransazione=@transazione, StatoPagamentoWeb=2, DataStatoPagamentoWeb=CURRENT_TIMESTAMP, UltimoEsitoPagamentoWeb=@esito WHERE id=@id AND COALESCE(Pagato,0)<>1", conn)
                    cmd.Parameters.Add("@transazione", MySqlDbType.VarChar, 100).Value = SanitizeTransactionId(transactionId)
                    cmd.Parameters.Add("@esito", MySqlDbType.VarChar, 255).Value = SanitizeOutcome(message)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    Return cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-payment-state", "MarkCompleted documentId=" & documentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        End Try

        Return 0
    End Function

    Private Function UpdatePaymentState(ByVal documentId As Integer, ByVal stateValue As Integer, ByVal message As String, ByVal forceUnpaid As Boolean, ByVal existingConn As MySqlConnection, ByVal trns As MySqlTransaction) As Integer
        Return UpdatePaymentState(documentId, stateValue, message, forceUnpaid, existingConn, trns, Nothing)
    End Function

    Private Function UpdatePaymentState(ByVal documentId As Integer, ByVal stateValue As Integer, ByVal message As String, ByVal forceUnpaid As Boolean, ByVal existingConn As MySqlConnection, ByVal trns As MySqlTransaction, ByVal transactionId As String) As Integer
        If documentId <= 0 Then Return 0

        Dim ownsConnection As Boolean = False
        Dim conn As MySqlConnection = existingConn

        Try
            If conn Is Nothing Then
                conn = New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                ownsConnection = True
            End If

            Dim sql As String = "UPDATE documenti SET "
            If forceUnpaid Then sql &= "Pagato=0, "
            If transactionId IsNot Nothing Then sql &= "IdTransazione=@transazione, "
            sql &= "StatoPagamentoWeb=@stato, DataStatoPagamentoWeb=CURRENT_TIMESTAMP, UltimoEsitoPagamentoWeb=@esito WHERE id=@id AND COALESCE(Pagato,0)<>1"

            Using cmd As New MySqlCommand(sql, conn)
                If trns IsNot Nothing Then cmd.Transaction = trns
                If transactionId IsNot Nothing Then cmd.Parameters.Add("@transazione", MySqlDbType.VarChar, 100).Value = SanitizeTransactionId(transactionId)
                cmd.Parameters.Add("@stato", MySqlDbType.Int16).Value = stateValue
                cmd.Parameters.Add("@esito", MySqlDbType.VarChar, 255).Value = SanitizeOutcome(message)
                cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                Return cmd.ExecuteNonQuery()
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-payment-state", "UpdatePaymentState documentId=" & documentId.ToString(CultureInfo.InvariantCulture) & " state=" & stateValue.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        Finally
            If ownsConnection AndAlso conn IsNot Nothing Then
                Try
                    conn.Close()
                    conn.Dispose()
                Catch
                End Try
            End If
        End Try

        Return 0
    End Function

    Public Function SanitizeOutcome(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim sanitized As String = value.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ").Trim()
        While sanitized.Contains("  ")
            sanitized = sanitized.Replace("  ", " ")
        End While
        If sanitized.Length > 255 Then sanitized = sanitized.Substring(0, 255)
        Return sanitized
    End Function

    Public Function SanitizeTransactionId(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim sanitized As String = value.Replace(vbCr, "").Replace(vbLf, "").Replace(vbTab, "").Trim()
        If sanitized.Length > 100 Then sanitized = sanitized.Substring(0, 100)
        Return sanitized
    End Function

    Public Function GetSessionInt(ByVal key As String, Optional ByVal defaultValue As Integer = 0) As Integer
        Try
            If HttpContext.Current Is Nothing OrElse HttpContext.Current.Session Is Nothing Then Return defaultValue
            Dim o As Object = HttpContext.Current.Session(key)
            If o Is Nothing Then Return defaultValue
            Return SafeInt(o, defaultValue)
        Catch
        End Try

        Return defaultValue
    End Function

    Private Function SafeInt(ByVal value As Object, ByVal defaultValue As Integer) As Integer
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim parsed As Integer
            If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return defaultValue
    End Function

    Private Function SafeDecimal(ByVal value As Object, ByVal defaultValue As Decimal) As Decimal
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim parsed As Decimal
            If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.CurrentCulture, parsed) Then Return parsed
            If Decimal.TryParse(Convert.ToString(value), NumberStyles.Any, CultureInfo.InvariantCulture, parsed) Then Return parsed
        Catch
        End Try

        Return defaultValue
    End Function

    Private Function SafeDate(ByVal value As Object, ByVal defaultValue As DateTime) As DateTime
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim parsed As DateTime
            If DateTime.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return defaultValue
    End Function
End Module
