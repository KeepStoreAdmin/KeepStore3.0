Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class PayPalPaymentDocumentInfo
    Public Property Exists As Boolean
    Public Property DocumentId As Integer
    Public Property UtentiId As Integer
    Public Property AziendeId As Integer
    Public Property PagamentiTipoId As Integer
    Public Property TipoDocumentiId As Integer
    Public Property OrigineOrdine As String
    Public Property DocumentState As Integer
    Public Property AllowLaterPayment As Integer
    Public Property ValidOrderType As Boolean
    Public Property HasGatewayAuthorization As Boolean
    Public Property DocumentNumber As Integer
    Public Property DocumentDate As DateTime
    Public Property Pagato As Integer
    Public Property PaymentState As Integer
    Public Property PaymentOnline As Integer
    Public Property TotalDocument As Decimal
    Public Property TransactionId As String
End Class

Public Class PayPalPendingRecheckResult
    Public Property Success As Boolean
    Public Property DocumentId As Integer
    Public Property Outcome As String
    Public Property Message As String
    Public Property TransactionId As String
    Public Property PayReturn As String = "ko"
End Class

Public Module PayPalPaymentState
    Public Const PAYPAL_ONLINE_VALUE As Integer = 2
    Public Const ORDER_PREFIX As String = "PP-ORDER:"
    Public Const CAPTURE_PREFIX As String = "TXN:"

    Public Function LoadDocumentForUser(ByVal documentId As Integer, ByVal utentiId As Integer) As PayPalPaymentDocumentInfo
        Return LoadDocument(documentId, utentiId, True)
    End Function

    Public Function LoadDocumentForPayment(ByVal documentId As Integer) As PayPalPaymentDocumentInfo
        Return LoadDocument(documentId, 0, False)
    End Function

    Private Function LoadDocument(ByVal documentId As Integer, ByVal utentiId As Integer, ByVal requireUser As Boolean) As PayPalPaymentDocumentInfo
        Dim info As New PayPalPaymentDocumentInfo()
        If documentId <= 0 OrElse (requireUser AndAlso utentiId <= 0) Then Return info
        Try
            Dim tenantId As Integer = 0
            If requireUser Then
                Dim tenant As OrderStorefrontIdentity = OrderStorefrontContext.Resolve(HttpContext.Current)
                If tenant Is Nothing OrElse Not tenant.IsComplete OrElse tenant.UtentiId <> utentiId Then Return info
                tenantId = tenant.CompanyId
            End If
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Dim sql As String = "SELECT d.id,d.UtentiId,COALESCE(d.AziendeId,0) AziendeId,COALESCE(d.PagamentiTipoId,0) PagamentiTipoId," &
                    "COALESCE(d.TipoDocumentiId,0) TipoDocumentiId,COALESCE(d.OrigineOrdine,'') OrigineOrdine," &
                    "COALESCE(d.StatiId,0) DocumentState,COALESCE(p.PermettiPagamentoSuccessivo,0) AllowLaterPayment," &
                    "CASE WHEN td.Web=1 AND td.Abilitato=1 AND td.ImpegnaQnt=1 THEN 1 ELSE 0 END ValidOrderType," &
                    "CASE WHEN EXISTS (SELECT 1 FROM bancasella_ordini_pagati b WHERE b.DocumentiId=d.id AND COALESCE(b.codiceAutorizzazione,'')<>'') THEN 1 ELSE 0 END HasGatewayAuthorization," &
                    "COALESCE(d.NDocumento,0) NDocumento,d.DataDocumento,COALESCE(d.Pagato,0) Pagato,COALESCE(d.StatoPagamentoWeb,0) StatoPagamentoWeb," &
                    "COALESCE(p.OnLine,0) PaymentOnline,COALESCE(pie.TotaleDocumento,0) TotaleDocumento,COALESCE(d.IdTransazione,'') IdTransazione " &
                    "FROM documenti d LEFT JOIN pagamentitipo p ON p.id=d.PagamentiTipoId LEFT JOIN tipodocumenti td ON td.id=d.TipoDocumentiId " &
                    "LEFT JOIN documentipie pie ON pie.DocumentiId=d.id WHERE d.id=@id"
                If requireUser Then sql &= " AND d.UtentiId=@uid AND d.AziendeId=@azienda"
                sql &= " LIMIT 1"
                Using cmd As New MySqlCommand(sql, conn)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    If requireUser Then
                        cmd.Parameters.Add("@uid", MySqlDbType.Int32).Value = utentiId
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = tenantId
                    End If
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            info.Exists = True
                            info.DocumentId = SafeInt(dr("id"))
                            info.UtentiId = SafeInt(dr("UtentiId"))
                            info.AziendeId = SafeInt(dr("AziendeId"))
                            info.PagamentiTipoId = SafeInt(dr("PagamentiTipoId"))
                            info.TipoDocumentiId = SafeInt(dr("TipoDocumentiId"))
                            info.OrigineOrdine = Convert.ToString(dr("OrigineOrdine")).Trim()
                            info.DocumentState = SafeInt(dr("DocumentState"))
                            info.AllowLaterPayment = SafeInt(dr("AllowLaterPayment"))
                            info.ValidOrderType = SafeInt(dr("ValidOrderType")) = 1
                            info.HasGatewayAuthorization = SafeInt(dr("HasGatewayAuthorization")) = 1
                            info.DocumentNumber = SafeInt(dr("NDocumento"))
                            info.DocumentDate = If(dr("DataDocumento") Is DBNull.Value, DateTime.MinValue, Convert.ToDateTime(dr("DataDocumento"), CultureInfo.InvariantCulture))
                            info.Pagato = SafeInt(dr("Pagato"))
                            info.PaymentState = SafeInt(dr("StatoPagamentoWeb"))
                            info.PaymentOnline = SafeInt(dr("PaymentOnline"))
                            info.TotalDocument = Convert.ToDecimal(dr("TotaleDocumento"), CultureInfo.InvariantCulture)
                            info.TransactionId = Convert.ToString(dr("IdTransazione"))
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-payment-state", If(requireUser, "LoadDocumentForUser", "LoadDocumentForPayment"), ex, HttpContext.Current)
        End Try
        Return info
    End Function

    Public Function MarkPending(ByVal documentId As Integer, ByVal message As String, Optional ByVal conn As MySqlConnection = Nothing, Optional ByVal trns As MySqlTransaction = Nothing) As Integer
        Return UpdatePaymentState(documentId, 1, message, Nothing, conn, trns)
    End Function

    Public Function MarkFailed(ByVal documentId As Integer, ByVal message As String) As Integer
        Return UpdatePaymentState(documentId, 3, message, Nothing, Nothing, Nothing)
    End Function

    Public Function MarkCanceled(ByVal documentId As Integer, ByVal message As String) As Integer
        Return UpdatePaymentState(documentId, 4, message, Nothing, Nothing, Nothing)
    End Function

    Public Function MarkPendingWithOrder(ByVal documentId As Integer, ByVal message As String, ByVal orderId As String) As Integer
        Return UpdatePaymentState(documentId, 1, message, BuildOrderMarker(orderId), Nothing, Nothing)
    End Function

    Public Function RecheckPendingPayment(ByVal documentId As Integer, ByVal utentiId As Integer) As PayPalPendingRecheckResult
        Dim result As New PayPalPendingRecheckResult With {.DocumentId = documentId}
        Dim doc As PayPalPaymentDocumentInfo = LoadDocumentForUser(documentId, utentiId)
        If doc Is Nothing OrElse Not doc.Exists Then result.Message = "PayPal Checkout: documento non trovato" : Return result
        If doc.Pagato = 1 Then result.Success = True : result.Outcome = "ALREADY_COMPLETED" : result.PayReturn = "ok" : Return result
        If doc.PaymentOnline <> PAYPAL_ONLINE_VALUE Then result.Message = "PayPal Checkout: metodo non coerente" : Return result
        Dim tx As PayPalCheckoutTransactionInfo = PayPalCheckoutRepository.LoadTransactionForDocument(documentId)
        If tx Is Nothing OrElse Not tx.Exists OrElse String.IsNullOrWhiteSpace(tx.PayPalOrderId) Then result.Message = "PayPal Checkout: transazione non trovata" : Return result
        Dim cfg As PayPalCheckoutConfig = PayPalCheckoutConfig.LoadForDocument(documentId)
        If cfg Is Nothing OrElse Not PayPalCheckoutSafetyPolicy.CanUseLiveCheckout(HttpContext.Current, cfg) Then result.Message = "PayPal Checkout: configurazione non disponibile" : Return result
        Dim response As PayPalOrdersV2Result = New PayPalOrdersV2Client(cfg).GetOrder(tx.PayPalOrderId)
        If response Is Nothing OrElse Not response.Success OrElse Not PayPalOrdersV2Client.ValidateSnapshot(doc, cfg, tx.PayPalOrderId, response.Snapshot) Then result.Message = "PayPal Checkout: verifica non riuscita" : Return result
        Dim captureStatus As String = Convert.ToString(response.Snapshot.CaptureStatus).ToUpperInvariant()
        If captureStatus = "COMPLETED" Then
            result.Success = PayPalCheckoutRepository.ApplyAuthoritativeState(tx, response.Snapshot, String.Empty)
            result.Outcome = "COMPLETED"
            result.PayReturn = If(result.Success, "ok", "ko")
        ElseIf captureStatus = "PENDING" OrElse String.Equals(response.Snapshot.Status, "APPROVED", StringComparison.OrdinalIgnoreCase) Then
            PayPalCheckoutRepository.ApplyAuthoritativeState(tx, response.Snapshot, String.Empty)
            result.Success = True
            result.Outcome = "PENDING"
            result.PayReturn = "ok"
        Else
            result.Outcome = "NOT_COMPLETED"
        End If
        result.TransactionId = If(captureStatus = "COMPLETED", response.Snapshot.CaptureId, tx.PayPalOrderId)
        Return result
    End Function

    Public Function BuildOrderMarker(ByVal orderId As String) As String
        Return SanitizeMarker(ORDER_PREFIX & SanitizeExternalId(orderId))
    End Function

    Public Function BuildCaptureMarker(ByVal captureId As String) As String
        Return SanitizeMarker(CAPTURE_PREFIX & SanitizeExternalId(captureId))
    End Function

    Public Function ExtractOrderId(ByVal value As String) As String
        Dim clean As String = SanitizeMarker(value)
        If clean.StartsWith(ORDER_PREFIX, StringComparison.Ordinal) Then Return clean.Substring(ORDER_PREFIX.Length)
        Return String.Empty
    End Function

    Public Function IsOrderInProgressMarker(ByVal value As String) As Boolean
        Return SanitizeMarker(value).StartsWith(ORDER_PREFIX, StringComparison.Ordinal)
    End Function

    Public Function SanitizeOutcome(ByVal value As String) As String
        Dim clean As String = Convert.ToString(value).Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ").Trim()
        While clean.Contains("  ")
            clean = clean.Replace("  ", " ")
        End While
        If clean.Length > 255 Then clean = clean.Substring(0, 255)
        Return clean
    End Function

    Public Function SanitizeExternalId(ByVal value As String) As String
        Dim clean As String = Convert.ToString(value).Trim()
        If clean.Length > 100 Then clean = clean.Substring(0, 100)
        For Each ch As Char In clean
            If Not Char.IsLetterOrDigit(ch) AndAlso ch <> "-"c AndAlso ch <> "_"c Then Return String.Empty
        Next
        Return clean
    End Function

    Public Function GetSessionInt(ByVal key As String, Optional ByVal defaultValue As Integer = 0) As Integer
        Try
            If HttpContext.Current Is Nothing OrElse HttpContext.Current.Session Is Nothing Then Return defaultValue
            Dim value As Object = HttpContext.Current.Session(key)
            If value Is Nothing Then Return defaultValue
            Dim parsed As Integer
            If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function UpdatePaymentState(ByVal documentId As Integer, ByVal stateValue As Integer, ByVal message As String, ByVal marker As String, ByVal existingConn As MySqlConnection, ByVal trns As MySqlTransaction) As Integer
        If documentId <= 0 Then Return 0
        Dim owns As Boolean = existingConn Is Nothing
        Dim conn As MySqlConnection = existingConn
        Try
            If owns Then conn = New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString) : conn.Open()
            Dim sql As String = "UPDATE documenti SET Pagato=0,StatoPagamentoWeb=@stato,DataStatoPagamentoWeb=CURRENT_TIMESTAMP,UltimoEsitoPagamentoWeb=@esito"
            If marker IsNot Nothing Then sql &= ",IdTransazione=@marker"
            sql &= " WHERE Id=@id AND COALESCE(Pagato,0)=0"
            Using cmd As New MySqlCommand(sql, conn)
                If trns IsNot Nothing Then cmd.Transaction = trns
                cmd.Parameters.Add("@stato", MySqlDbType.Int16).Value = stateValue
                cmd.Parameters.Add("@esito", MySqlDbType.VarChar, 255).Value = SanitizeOutcome(message)
                If marker IsNot Nothing Then cmd.Parameters.Add("@marker", MySqlDbType.VarChar, 150).Value = marker
                cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                Return cmd.ExecuteNonQuery()
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("paypal-payment-state", "UpdatePaymentState", ex, HttpContext.Current)
            Return 0
        Finally
            If owns AndAlso conn IsNot Nothing Then conn.Dispose()
        End Try
    End Function

    Private Function SanitizeMarker(ByVal value As String) As String
        Dim clean As String = Convert.ToString(value).Replace(vbCr, String.Empty).Replace(vbLf, String.Empty).Trim()
        If clean.Length > 150 Then clean = clean.Substring(0, 150)
        Return clean
    End Function

    Private Function SafeInt(ByVal value As Object) As Integer
        If value Is Nothing OrElse value Is DBNull.Value Then Return 0
        Dim parsed As Integer
        Integer.TryParse(Convert.ToString(value), parsed)
        Return parsed
    End Function
End Module
