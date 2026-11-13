Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

''' <summary>
''' Inputs of the read-only database routine Carrello_Totali. They are the SAME values that
''' ordine.aspx.vb passes to Carrello_Documento from the sealed checkout draft, so that the total
''' shown to the customer is the total the database writes into the document.
''' </summary>
Public NotInheritable Class CartTotalsInput
    Public Property LoginId As Long
    Public Property InsuranceCost As Decimal
    Public Property ShippingCost As Decimal
    Public Property Rounding As Decimal
    Public Property PaymentCost As Decimal
    Public Property ReverseCharge As Integer
    Public Property CarrierVat As Decimal
    Public Property CouponTaxable As Decimal
    Public Property CouponVatValue As Decimal

    ''' <summary>
    ''' Normalizes the inputs exactly like the order page does before calling Carrello_Documento:
    ''' for a coupon-article order the insurance, shipping and payment costs are zeroed; rounding,
    ''' reverse charge, carrier VAT and the voucher values are passed unchanged.
    ''' </summary>
    Public Shared Function ForOrder(ByVal loginId As Long,
                                    ByVal insuranceCost As Decimal,
                                    ByVal shippingCost As Decimal,
                                    ByVal paymentCost As Decimal,
                                    ByVal rounding As Decimal,
                                    ByVal reverseCharge As Integer,
                                    ByVal carrierVat As Decimal,
                                    ByVal couponTaxable As Decimal,
                                    ByVal couponVatValue As Decimal,
                                    ByVal isCouponArticleOrder As Boolean) As CartTotalsInput
        Return New CartTotalsInput() With {
            .LoginId = loginId,
            .InsuranceCost = If(isCouponArticleOrder, 0D, insuranceCost),
            .ShippingCost = If(isCouponArticleOrder, 0D, shippingCost),
            .PaymentCost = If(isCouponArticleOrder, 0D, paymentCost),
            .Rounding = rounding,
            .ReverseCharge = reverseCharge,
            .CarrierVat = carrierVat,
            .CouponTaxable = couponTaxable,
            .CouponVatValue = couponVatValue
        }
    End Function
End Class

''' <summary>Merchandise net, VAT and document total as computed by the database (two decimals, rounded once).</summary>
Public NotInheritable Class CartTotalsResult
    Public Property Merce As Decimal
    Public Property Iva As Decimal
    Public Property Totale As Decimal
End Class

''' <summary>
''' Reads the cart totals from the database routine Carrello_Totali (single source of the document total).
''' The web never computes, rounds or reconstructs these values. Every failure (missing routine, missing
''' EXECUTE, database error, NULL output for an incomplete cart row, invalid owner) returns False and never a
''' guessed or zero value; the caller must treat False as "totals unavailable" and fail closed.
''' </summary>
Public NotInheritable Class CartTotalsService
    Friend Const ProcedureName As String = "Carrello_Totali"
    Private Const LogCategory As String = "cart-totals"

    ''' <summary>Opens a read connection from the configured storefront connection string.</summary>
    Public Shared Function TryCompute(ByVal input As CartTotalsInput,
                                      ByRef result As CartTotalsResult,
                                      ByVal context As HttpContext) As Boolean
        result = Nothing
        If input Is Nothing OrElse input.LoginId <= 0 Then Return False
        Try
            Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return False
            Using connection As New MySqlConnection(BuildConnectionString(settings.ConnectionString))
                connection.Open()
                Return TryComputeCore(connection, Nothing, input, ProcedureName, result, context)
            End Using
        Catch ex As Exception
            LogFailure(ex, context)
            result = Nothing
            Return False
        End Try
    End Function

    ''' <summary>Uses a caller-owned connection (and optional transaction), for example the draft capture.</summary>
    Public Shared Function TryCompute(ByVal connection As MySqlConnection,
                                      ByVal transaction As MySqlTransaction,
                                      ByVal input As CartTotalsInput,
                                      ByRef result As CartTotalsResult,
                                      ByVal context As HttpContext) As Boolean
        Return TryComputeCore(connection, transaction, input, ProcedureName, result, context)
    End Function

    ''' <summary>Test seam: same call with another routine name (for example a missing routine).</summary>
    Friend Shared Function TryComputeNamed(ByVal connection As MySqlConnection,
                                           ByVal transaction As MySqlTransaction,
                                           ByVal input As CartTotalsInput,
                                           ByVal procedureName As String,
                                           ByRef result As CartTotalsResult,
                                           ByVal context As HttpContext) As Boolean
        Return TryComputeCore(connection, transaction, input, procedureName, result, context)
    End Function

    ''' <summary>
    ''' The routine metadata lookup of the connector is switched off: the call below supplies every
    ''' parameter, typed and in the signature order, so no read access to the routine definition is needed
    ''' beyond EXECUTE on Carrello_Totali.
    ''' </summary>
    Friend Shared Function BuildConnectionString(ByVal configured As String) As String
        Dim builder As New MySqlConnectionStringBuilder(configured)
        builder.CheckParameters = False
        Return builder.ConnectionString
    End Function

    Private Shared Function TryComputeCore(ByVal connection As MySqlConnection,
                                           ByVal transaction As MySqlTransaction,
                                           ByVal input As CartTotalsInput,
                                           ByVal procedureName As String,
                                           ByRef result As CartTotalsResult,
                                           ByVal context As HttpContext) As Boolean
        result = Nothing
        If connection Is Nothing OrElse input Is Nothing OrElse input.LoginId <= 0 Then Return False
        Try
            Using command As New MySqlCommand(procedureName, connection, transaction)
                command.CommandType = CommandType.StoredProcedure
                command.Parameters.Add("?pLoginId", MySqlDbType.Int64).Value = input.LoginId
                AddDecimalInput(command, "?pCostoAssicurazione", input.InsuranceCost)
                AddDecimalInput(command, "?pCostoSpedizione", input.ShippingCost)
                AddDecimalInput(command, "?pArrotondamento", input.Rounding)
                AddDecimalInput(command, "?pCostoPagamento", input.PaymentCost)
                command.Parameters.Add("?pUtenteAbilitatoRC", MySqlDbType.Int32).Value = input.ReverseCharge
                AddDecimalInput(command, "?pIvaVettore", input.CarrierVat)
                AddDecimalInput(command, "?pBuonoScontoTotale", input.CouponTaxable)
                AddDecimalInput(command, "?pBuonoScontoValoreIva", input.CouponVatValue)
                Dim outMerce As MySqlParameter = AddDecimalOutput(command, "?pTotMerce")
                Dim outIva As MySqlParameter = AddDecimalOutput(command, "?pTotIva")
                Dim outTotale As MySqlParameter = AddDecimalOutput(command, "?pTotale")
                command.ExecuteNonQuery()

                ' A NULL output means the database could not total an incomplete cart row: never a zero.
                If IsNull(outMerce.Value) OrElse IsNull(outIva.Value) OrElse IsNull(outTotale.Value) Then Return False
                result = New CartTotalsResult() With {
                    .Merce = Convert.ToDecimal(outMerce.Value, CultureInfo.InvariantCulture),
                    .Iva = Convert.ToDecimal(outIva.Value, CultureInfo.InvariantCulture),
                    .Totale = Convert.ToDecimal(outTotale.Value, CultureInfo.InvariantCulture)
                }
                Return True
            End Using
        Catch ex As Exception
            LogFailure(ex, context)
            result = Nothing
            Return False
        End Try
    End Function

    Private Shared Sub AddDecimalInput(ByVal command As MySqlCommand, ByVal name As String, ByVal value As Decimal)
        Dim parameter As MySqlParameter = command.Parameters.Add(name, MySqlDbType.Decimal)
        parameter.Precision = 15
        parameter.Scale = 8
        parameter.Value = value
    End Sub

    Private Shared Function AddDecimalOutput(ByVal command As MySqlCommand, ByVal name As String) As MySqlParameter
        Dim parameter As MySqlParameter = command.Parameters.Add(name, MySqlDbType.Decimal)
        parameter.Precision = 15
        parameter.Scale = 2
        parameter.Direction = ParameterDirection.Output
        Return parameter
    End Function

    Private Shared Function IsNull(ByVal value As Object) As Boolean
        Return value Is Nothing OrElse value Is DBNull.Value
    End Function

    ''' <summary>Sanitized: exception type and MySQL error number only; no SQL text, parameters or values.</summary>
    Private Shared Sub LogFailure(ByVal ex As Exception, ByVal context As HttpContext)
        Dim detail As String = "Error type: " & ex.GetType().Name & "."
        Dim mysqlError As MySqlException = TryCast(ex, MySqlException)
        If mysqlError IsNot Nothing Then detail &= " MySQL error " & mysqlError.Number.ToString(CultureInfo.InvariantCulture) & "."
        KeepStoreLog.Error(LogCategory, "Cart totals read failed. " & detail, Nothing, context)
    End Sub
End Class
