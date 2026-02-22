Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.IO
Imports AmazonUtilities.ServiceSoapClient

Partial Class amazon
    Inherits System.Web.UI.Page

    Dim amazonUtilities As New AmazonUtilities.ServiceSoapClient

	Const PENDING_STATE_ID As String = "6"
	Const UNSHIPPED_STATE_ID As String = "1"
    Const SHIPPED_STATE_ID As String = "4"
    Const CANCELED_STATE_ID As String = "3"

    Public Structure AmazonAccessData
        Public awsAccessKeyId As String
        Public mwsAuthToken As String
        Public sellerId As String
        Public hachKey As String
    End Structure

    Public Structure DocumentDefaultData
        Public mode As String
        Public documenTypeId As String
        Public companyId As String
        Public userId As String
        Public carrierId As String
        Public carrierVat As String
        Public assurancePercentage As Integer
        Public assuranceMinimum As Integer
        Public agentId As String
        Public commission As String
        Public paymentTypeId As String
        Public priceList As String
        Public statusId As String
        Public portCausalId As String
        Public transportCausalId As String
        Public shapeCausalId As String
        Public dateDocument As String
        Public year As String
        Public registeredOffice As String
    End Structure

    Public Structure OrderItem
        Public asin As String
        Public ean As String
        Public sku As String
        Public productId As String
        Public description As String
        Public um As String
        Public tcId As Integer
        Public quantityOrdered As Double
        Public quotedItemPrice As Double
        Public quotedShippingPrice As Double
        Public quotedAssurancePrice As Double
        Public itemPrice As Double
        Public shippingPrice As Double
        Public assurancePrice As Double
        Public weight As Double
        Public vat As Double
        Public accountSales As Integer
    End Structure

    Enum DrItemType
        stringType
        intType
    End Enum

    Enum AmazonOrderStatus
        pending
        pendingAvailability
        unshipped
        partiallyShipped
        shipped
        canceled
    End Enum

    Enum SqlExecutionType
        nonQuery
        scalar
    End Enum
	
    Protected Function getDataReader(ByVal conn As MySqlConnection, ByVal query As String) As MySqlDataReader
        Return getDataReader(conn, query, 0)
    End Function

    Protected Function getDataReader(ByVal conn As MySqlConnection, ByVal query As String, ByVal timeout As Integer) As MySqlDataReader
        Dim cmd As New MySqlCommand
        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        If timeout > 0 Then
            cmd.CommandTimeout = timeout
        End If
        cmd.CommandText = query
        Return cmd.ExecuteReader()
    End Function

    Protected Function ExecuteQuery(ByVal conn As MySqlConnection, ByVal query As String, ByVal executionType As SqlExecutionType) As Object
        Dim cmd = New MySqlCommand()
        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = query
        Dim result As Object
        If executionType = SqlExecutionType.nonQuery Then
            result = cmd.ExecuteNonQuery()
        Else
            result = cmd.ExecuteScalar()
        End If
        cmd.Dispose()
        Return result
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        Dim action As String = Request.QueryString("action")
        Select Case action
            Case "import_orders"
                importOrders()
				Response.Write("True")
				Response.End()
            Case "export_feeds"
                exportFeeds()
				Response.End()
        End Select

    End Sub

    Protected Sub importOrders()
        Dim conn = New MySqlConnection()
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()
        Dim dr As MySqlDataReader
        Dim query As String = "select aws_access_key_id, mws_auth_token, seller_id, hach_key, marketplaces, document_type_id, company_id, user_id, carrier_id, mode, agenteId, provvigione1, tipopagamento, listino, causaliPortoId, causaliTrasportoId, causaliAspettoId, valore, vettori.descrizione as carrierName, assicurazioneMinimo, assicurazionePercentuale, indirizzo, citta, provincia, cap, telefono, fax from ks_amazon_data "
        query &= "Left join utenti on utenti.id=ks_amazon_data.user_id "
        query &= "Left join utentiagenti on utentiagenti.utentiId = ks_amazon_data.user_id "
        query &= "Left join utentirapporto on utentirapporto.utenteid = ks_amazon_data.user_id "
        query &= "Left join tipodocumenti on tipodocumenti.id = document_type_id "
        query &= "Left join vettori on vettori.id = ks_amazon_data.carrier_id And vettori.AziendeId = ks_amazon_data.company_id "
        query &= "Left join iva on iva.id = vettori.iva"
        dr = getDataReader(conn, query)
        dr.Read()
        Dim amazonAccessData As New AmazonAccessData
        amazonAccessData.awsAccessKeyId = dr.Item("aws_access_key_id")
        amazonAccessData.mwsAuthToken = dr.Item("mws_auth_token")
        amazonAccessData.sellerId = dr.Item("seller_id")
        amazonAccessData.hachKey = dr.Item("hach_key")
        Dim marketplaces As String = dr.Item("marketplaces")
        Dim documentDefaultData As New DocumentDefaultData
        Dim carrierName As String = dr.Item("carrierName")
        documentDefaultData.mode = dr.Item("mode")
        documentDefaultData.documenTypeId = dr.Item("document_type_id")
        documentDefaultData.companyId = dr.Item("company_id")
        documentDefaultData.userId = dr.Item("user_id")
        documentDefaultData.carrierId = dr.Item("carrier_id")
        documentDefaultData.carrierVat = dr.Item("valore")
		documentDefaultData.assuranceMinimum = getValueCheckingDbNull(dr,"assicurazioneMinimo","0")
		documentDefaultData.assurancePercentage = getValueCheckingDbNull(dr,"assicurazionePercentuale","0")
		documentDefaultData.agentId = getValueCheckingDbNull(dr,"agenteId","NULL")
		documentDefaultData.commission = getValueCheckingDbNull(dr,"provvigione1","NULL")
        documentDefaultData.paymentTypeId = dr.Item("tipopagamento")
        documentDefaultData.priceList = dr.Item("listino")
        documentDefaultData.portCausalId = dr.Item("causaliPortoId") 
        documentDefaultData.transportCausalId = dr.Item("causaliTrasportoId")
        documentDefaultData.shapeCausalId = dr.Item("causaliAspettoId")
        documentDefaultData.registeredOffice = dr.Item("Indirizzo") & vbCrLf & dr.Item("cap") & " " & dr.Item("citta") & " " & dr.Item("provincia") & vbCrLf & "Tel:" & dr.Item("telefono") & vbCrLf & "Fax." & dr.Item("fax")
        dr.Close()
        Dim now As DateTime = DateTime.Now
        documentDefaultData.dateDocument = now.ToString("yyyy-MM-dd")
        documentDefaultData.year = now.ToString("yyyy")
        Dim countryCodes() As String = marketplaces.Split(";")
        Dim newOrders As DataSet
        For Each countryCode As String In countryCodes
            newOrders = amazonUtilities.getNewOrders(amazonAccessData.awsAccessKeyId, amazonAccessData.mwsAuthToken, countryCode, amazonAccessData.sellerId, amazonAccessData.hachKey)
            Dim order As DataTable = newOrders.Tables("Order")
            Dim paymentMethodDetails As DataTable = newOrders.Tables("PaymentMethodDetails")
            Dim orderTotal As DataTable = newOrders.Tables("OrderTotal")
            Dim shippingAddress As DataTable = newOrders.Tables("ShippingAddress")
            Dim whereAmazonOrderIdIsDifferentFromAlreadyExaminated As String = ""
            If order IsNot Nothing Then
                Dim sellerOrderIdColumnExists = order.Columns.Contains("SellerOrderId")
                For Each row In order.Rows
					Try
						Dim orderStatus As String = row("OrderStatus").ToString.ToLower
						Dim amazonOrderId As String = row("AmazonOrderId")
						whereAmazonOrderIdIsDifferentFromAlreadyExaminated &= " And Amazon_Order_Id != '" & amazonOrderId & "'"
						dr = getDataReader(conn, "select COUNT(ks_amazon_orders.id) as n_rows, order_status, statiid, documenti.tracking as tracking, vettoriid from ks_amazon_orders Left join documentipie on documentipie.documentiId = ks_amazon_orders.document_id Left join documenti on documenti.id = ks_amazon_orders.document_id where amazon_order_id = '" & amazonOrderId & "'")
						dr.Read()
						Dim orderExists As Boolean = Convert.ToBoolean(dr("n_rows"))
						Dim existingOrderStatus As String = ""
						Dim statiId As String = ""
						Dim tracking As String = ""
						If orderExists Then
							existingOrderStatus = getValueCheckingDbNull(dr,"order_status","")
							statiId = getValueCheckingDbNull(dr,"statiid","")
							tracking = getValueCheckingDbNull(dr,"tracking","")
							documentDefaultData.carrierId = getValueCheckingDbNull(dr,"vettoriid","")
						End If
						dr.Close()
						If isOrderPending(orderStatus) Then
							If Not orderExists Then
								documentDefaultData.statusId = PENDING_STATE_ID
								Dim documentId As String = insertOrderPending(conn, row, amazonOrderId, countryCode, orderStatus, documentDefaultData)
								insertOrderRowsAndFoot(conn, dr, amazonOrderId, countryCode, orderStatus, amazonAccessData, documentDefaultData, documentId)
							End If
						Else
							If sellerOrderIdColumnExists AndAlso Not IsDBNull(row("SellerOrderId")) Then
								If orderExists Then
									If statiId = SHIPPED_STATE_ID AndAlso tracking <> "" Then
										ExecuteQuery(conn, "UPDATE ks_amazon_orders SET order_status = '" + AmazonOrderStatus.shipped.ToString + "', buyer_name = '" + Replace(row("BuyerName"),"'","\'") + "' where amazon_order_id = '" & amazonOrderId & "'", SqlExecutionType.nonQuery)
										Dim merchantOrderId As String = getMerchantOrderIdByAmazonOrderId(conn, dr, amazonOrderId)
										amazonUtilities.setShipperTrakingNumber(amazonAccessData.awsAccessKeyId, amazonAccessData.mwsAuthToken, countryCode, amazonAccessData.sellerId, amazonAccessData.hachKey, merchantOrderId, tracking, carrierName)
									End If
								End If
							Else
								If orderExists Then
									If isOrderPending(existingOrderStatus) Then
										Dim documentId As String = updatePendingOrderToUnshipped(conn, row, shippingAddress, amazonOrderId)
										deleteDocumentRows(conn, dr, documentId)
										ExecuteQuery(conn, "delete from documentipie where DocumentiId = " & documentId, SqlExecutionType.nonQuery)
										Dim merchantOrderId As String = getMerchantOrderIdByAmazonOrderId(conn, dr, amazonOrderId)
										insertOrderRowsAndFoot(conn, dr, amazonOrderId, countryCode, orderStatus, amazonAccessData, documentDefaultData, documentId)
										amazonUtilities.setSellerOrderId(amazonAccessData.awsAccessKeyId, amazonAccessData.mwsAuthToken, countryCode, amazonAccessData.sellerId, amazonAccessData.hachKey, amazonOrderId, merchantOrderId)
									Else
										Dim merchantOrderId As String = getMerchantOrderIdByAmazonOrderId(conn, dr, amazonOrderId)
										amazonUtilities.setSellerOrderId(amazonAccessData.awsAccessKeyId, amazonAccessData.mwsAuthToken, countryCode, amazonAccessData.sellerId, amazonAccessData.hachKey, amazonOrderId, merchantOrderId)
									End If
								Else
									documentDefaultData.statusId = UNSHIPPED_STATE_ID
									Dim documentId As String = insertOrderUnshipped(conn, row, shippingAddress, amazonOrderId, countryCode, orderStatus, documentDefaultData)
									insertOrderRowsAndFoot(conn, dr, amazonOrderId, countryCode, orderStatus, amazonAccessData, documentDefaultData, documentId)
									Dim merchantOrderId As String = getMerchantOrderIdByDocumentiId(conn, dr, documentId)
									amazonUtilities.setSellerOrderId(amazonAccessData.awsAccessKeyId, amazonAccessData.mwsAuthToken, countryCode, amazonAccessData.sellerId, amazonAccessData.hachKey, amazonOrderId, merchantOrderId)
								End If
							End If
						End If
					Catch ex As Exception
						dr.Close()
					End Try
                Next
            End If
			Dim ordersProbablyCanceled As DataSet
			dr = getDataReader(conn, "select COUNT(id) as n_rows from ks_amazon_orders where (order_status = 'pending' OR order_status = 'unshipped')" & whereAmazonOrderIdIsDifferentFromAlreadyExaminated)
			dr.Read()
			Dim nRows As Integer = dr("n_rows")
			dr.Close()
			Dim maxAmazonOrderId As Integer = 9
			Dim ordersProbablyCanceledCycles As Integer
			If nRows > 0 Then
				ordersProbablyCanceledCycles = (nRows - 1)\maxAmazonOrderId +1
			Else 
				ordersProbablyCanceledCycles = 0
			End If
			Dim orderProbablyCanceledTables(ordersProbablyCanceledCycles) As DataTable
               If ordersProbablyCanceledCycles > 0 Then
				dr = getDataReader(conn, "select amazon_order_id from ks_amazon_orders where (order_status = 'pending' OR order_status = 'unshipped')" & whereAmazonOrderIdIsDifferentFromAlreadyExaminated)
				For i = 1 To ordersProbablyCanceledCycles
					Dim nAmazonOrderId As Integer
					If  nRows - maxAmazonOrderId*(i-1) > maxAmazonOrderId Then
						nAmazonOrderId = maxAmazonOrderId
						nRows -= nAmazonOrderId
					Else 
						nAmazonOrderId = nRows
						nRows = 0
					End If						
					Dim amazonOrderIds(nAmazonOrderId - 1) As String						
					For nRow = 0 To nAmazonOrderId - 1
						dr.Read()
						amazonOrderIds(nRow) = dr("amazon_order_id")
					Next nRow
					ordersProbablyCanceled = amazonUtilities.getOrders(amazonAccessData.awsAccessKeyId, amazonAccessData.mwsAuthToken, countryCode, amazonAccessData.sellerId, amazonAccessData.hachKey, amazonOrderIds)
					if i <> ordersProbablyCanceledCycles then System.Threading.Thread.Sleep(5000)
					orderProbablyCanceledTables(i) = ordersProbablyCanceled.Tables("Order")
				Next i
				dr.Close()
               End If
               If ordersProbablyCanceledCycles > 0 Then
				For Each orderProbablyCanceled In orderProbablyCanceledTables
					If orderProbablyCanceled isNot Nothing Then
						For Each row In orderProbablyCanceled.Rows
							If String.Compare(row("OrderStatus"), AmazonOrderStatus.canceled.ToString, True) = 0 Then
								ExecuteQuery(conn, "UPDATE ks_amazon_orders SET order_status = 'canceled' where amazon_order_id = '" & row("AmazonOrderId") & "'", SqlExecutionType.nonQuery)
								Dim documentId As String = ExecuteQuery(conn, "Select document_id from ks_amazon_orders where amazon_order_id = '" & row("AmazonOrderId") & "'", SqlExecutionType.scalar)
								deleteDocumentRows(conn, dr, documentId)
								ExecuteQuery(conn, "UPDATE documenti SET statiid = " & CANCELED_STATE_ID & " where id = " & documentId, SqlExecutionType.nonQuery)
							End If
						Next
					End if
				Next
            End If
        Next
        Dim sqlString As String = "UPDATE ks_amazon_data SET execution_status_import_orders = '" & now & ":REQUEST CORRECTLY EXECUTED'"
        ExecuteQuery(conn, sqlString, SqlExecutionType.nonQuery)
        conn.Close()
        conn.Dispose()
    End Sub

    Protected Sub deleteDocumentRows(ByVal conn As MySqlConnection, ByVal dr As MySqlDataReader, ByVal documentId As String)
        dr = getDataReader(conn, "select COUNT(id) as n_rows, qnt, articoliid from documentirighe where documentiid = " & documentId)
        dr.Read()
        Dim nRows As Integer = dr("n_rows")
        Dim productIds(nRows - 1) As String
        Dim qnts(nRows - 1) As String
        If nRows > 0 Then
            Dim nRow As Integer = 0
            productIds(nRow) = dr("articoliid")
            qnts(nRow) = dr("qnt")
            While dr.Read()
                nRow += 1
                productIds(nRow) = dr("articoliid")
                qnts(nRow) = dr("qnt")
            End While
        End If
        dr.Close()
        For nRow = 0 To nRows - 1
            ExecuteQuery(conn, "UPDATE articoli_giacenze SET giacenza = giacenza + " & qnts(nRow) & " where articoliId = " & productIds(nRow), SqlExecutionType.nonQuery)
        Next
        ExecuteQuery(conn, "delete from documentirighe where DocumentiId = " & documentId, SqlExecutionType.nonQuery)
		ExecuteQuery(conn, "UPDATE documentipie SET CausaliTrasportoId = 0, CausaliPortoId = 0, VettoriId = 0, colli = 0, peso = 0, CausaliAspettoId = 0, costoassicurazione = 0, costospedizione = 0, TotImponibile = 0, TotIva = 0, TotaleDocumento = 0 where DocumentiId = " & documentId, SqlExecutionType.nonQuery)
    End Sub

    Protected Function getMerchantOrderIdByAmazonOrderId(ByVal conn As MySqlConnection, ByVal dr As MySqlDataReader, ByVal amazonOrderId As String) As String
        Dim querySuffix As String = "Left Join ks_amazon_orders on documenti.id = ks_amazon_orders.document_id where amazon_order_id = '" & amazonOrderId & "'"
        Return getMerchantOrderId(conn, dr, querySuffix)
    End Function

    Protected Function getMerchantOrderIdByDocumentiId(ByVal conn As MySqlConnection, ByVal dr As MySqlDataReader, ByVal documentiId As String) As String
        Dim querySuffix As String = "Where id = " & documentiId
        Return getMerchantOrderId(conn, dr, querySuffix)
    End Function

    Protected Function getMerchantOrderId(ByVal conn As MySqlConnection, ByVal dr As MySqlDataReader, ByVal querySuffix As String) As String
        dr = getDataReader(conn, "select NDocumento from documenti " & querySuffix)
        dr.Read()
        Dim merchantOrderId As String = dr("NDocumento")
        dr.Close()
        Return merchantOrderId
    End Function

    Protected Function isOrderPending(ByVal orderStatus As String) As Boolean
        Return (String.Compare(orderStatus, AmazonOrderStatus.pending.ToString, True) = 0) OrElse (String.Compare(orderStatus, AmazonOrderStatus.pendingAvailability.ToString, True) = 0)
    End Function

    Protected Function insertOrderPending(ByVal conn As MySqlConnection, ByVal order As DataRow, ByVal amazonOrderId As String, ByVal countryCode As String, ByVal orderStatus As String, ByVal documentDefaultData As DocumentDefaultData) As String
		Dim purchaseDate As String = order("purchaseDate").Split("T")(0)
		Return insertOrder(conn, countryCode, amazonOrderId, orderStatus, documentDefaultData, "", "", purchaseDate)
    End Function

    Protected Function insertOrderUnshipped(ByVal conn As MySqlConnection, ByVal order As DataRow, ByVal shippingAddress As DataTable, ByVal amazonOrderId As String, ByVal countryCode As String, ByVal orderStatus As String, ByVal documentDefaultData As DocumentDefaultData) As String
		Dim buyerName As String = Replace(order("BuyerName"),"'","\'")
        Dim destination As String = getAddress(order, shippingAddress)
		Dim purchaseDate As String = order("purchaseDate").Split("T")(0)
        Return insertOrder(conn, countryCode, amazonOrderId, orderStatus, documentDefaultData, buyerName, destination, purchaseDate)
    End Function

    Protected Function getAddress(ByVal order As DataRow, ByVal shippingAddress As DataTable) As String
		Dim pageId As String = order("page_Id")
        Dim orderId As String = order("Order_Id")
		Dim address As DataRow = shippingAddress.Select("page_id = " & pageId & " And Order_id = " & orderId)(0)
        Dim name As String = addStringFromDataRow("", address, "Name")
		Dim addressLine As String = ""
		addressLine = addStringFromDataRow(addressLine, address, "AddressLine1")
		addressLine = addStringFromDataRow(addressLine, address, "AddressLine2")
		addressLine = addStringFromDataRow(addressLine, address, "AddressLine3")
        Dim city As String = addStringFromDataRow("", address, "City")
        Dim postalCode As String = addStringFromDataRow("", address, "PostalCode")
		Dim stateOrRegion As String = addStringFromDataRow("", address, "stateOrRegion")
        Dim phone As String = addStringFromDataRow("", address, "Phone")
        Dim destination As String = name & vbCrLf & addressLine & vbCrLf & postalCode & " " & city & " " & stateOrRegion & vbCrLf & "Tel." & phone
		Return Replace(destination.ToUpper(),"'","\'")
    End Function

	Protected Function addStringFromDataRow(ByVal initialString As String, ByVal dr As DataRow, ByVal fieldName As String) As String
		Dim finalString As String
		try
			If initialString = "" Then
				finalString = dr(fieldName)
			Else
				finalString = initialString & " " & dr(fieldName)
			End If
		Catch ex As Exception
			finalString = initialString
		End Try
		Return finalString
	End Function
	
    Protected Function updatePendingOrderToUnshipped(ByVal conn As MySqlConnection, ByVal order As DataRow, ByVal shippingAddress As DataTable, ByVal amazonOrderId As String) As String
        Dim buyerName As String =  Replace(order("BuyerName"),"'","\'")
        Dim destination As String = getAddress(order, shippingAddress)
        ExecuteQuery(conn, "UPDATE ks_amazon_orders SET order_status = '" + AmazonOrderStatus.unshipped.ToString + "', buyer_name = '" + buyerName + "', destination = '" + destination + "' where amazon_order_id = '" & amazonOrderId & "'", SqlExecutionType.nonQuery)
        Dim documentId As String = ExecuteQuery(conn, "Select document_id from ks_amazon_orders where amazon_order_id = '" & amazonOrderId & "'", SqlExecutionType.scalar)
        ExecuteQuery(conn, "UPDATE documenti SET destinazioneMerci = '" + destination + "', statiid = " + UNSHIPPED_STATE_ID + ", utente = '" + destination.Split(vbCrLf)(0) + "' where id = " & documentId, SqlExecutionType.nonQuery)
        Return documentId
    End Function

    Protected Function insertOrder(ByVal conn As MySqlConnection, ByVal countryCode As String, ByVal amazonOrderId As String, ByVal orderStatus As String, ByVal documentDefaultData As DocumentDefaultData, ByVal buyerName As String, ByVal destination As String, ByVal purchaseDate As String) As String
        Dim nameFromAddress as String = ""
		if destination <> "" Then
			nameFromAddress = destination.Split(vbCrLf)(0)
		End if
		ExecuteQuery(conn, "insert into documenti (AziendeId, TipoDocumentiId, DataDocumento, UtentiId, Utente, AgentiId, Provvigione, DestinazioneMerci, PagamentiTipoId, Listino, StatiId, Anno, SedeLegale) " & _
                        "VALUES (" & documentDefaultData.companyId & ", " & documentDefaultData.documenTypeId & ", '" & documentDefaultData.dateDocument & "', " & documentDefaultData.userId & ", '" & nameFromAddress & "', " & documentDefaultData.agentId & ", " & documentDefaultData.commission & ", '" & destination & "', " & documentDefaultData.paymentTypeId & ", " & documentDefaultData.priceList & ", " & documentDefaultData.statusId & ", " & documentDefaultData.year & ", '" & documentDefaultData.registeredOffice & "')", SqlExecutionType.nonQuery)
        Dim documentId As String = CStr(ExecuteQuery(conn, "Select LAST_INSERT_ID()", SqlExecutionType.scalar))
        ExecuteQuery(conn, "insert into ks_amazon_orders (document_id, amazon_order_id, country_code, order_status, buyer_name, destination, purchase_date) " & _
                        "VALUES (" & documentId & ", '" & amazonOrderId & "', '" & countryCode & "', '" & orderStatus & "', '" & buyerName & "', '" & destination & "', '" & purchaseDate & "' )", SqlExecutionType.nonQuery)
        ExecuteQuery(conn, "insert into documenticollegati (documentiid, amazon_order_id) " & _
                        "VALUES (" & documentId & ", '" & amazonOrderId & "')", SqlExecutionType.nonQuery)
		Return documentId
    End Function

    Protected Sub insertOrderRowsAndFoot(ByVal conn As MySqlConnection, ByVal dr As MySqlDataReader, ByVal amazonOrderId As String, ByVal countryCode As String, ByVal orderStatus As String, ByVal amazonAccessData As AmazonAccessData, ByVal documentDefaultData As DocumentDefaultData, ByVal documentId As String)
        Dim orderItems As DataSet = amazonUtilities.getListOrderItem(amazonAccessData.awsAccessKeyId, amazonAccessData.mwsAuthToken, countryCode, amazonAccessData.sellerId, amazonAccessData.hachKey, amazonOrderId)
        Dim itemPrice As DataTable = orderItems.Tables("ItemPrice")
        Dim shippingPrice As DataTable = orderItems.Tables("ShippingPrice")
        Dim packages As Integer = 0
        Dim totalWeight As Double = 0
        Dim totalAssurancePrice As Double = 0
        Dim totalShippingPrice As Double = 0
        Dim totalDocumentPrice As Double = 0
        Dim totalPrice As Double = 0
        Dim totalVat As Double = 0
		try
			For Each row In orderItems.Tables("OrderItem").Rows
				Dim orderItem As OrderItem = getOrderItem(row, itemPrice, shippingPrice)
				dr = getDataReader(conn, "select package_weight, product_id, item_name, tc_id, iva.valore as valore, iva.id as ivaid , ean, unitadimisura.id as um, contovend from ks_amazon_products Left Join articoli on articoli.id = ks_amazon_products.product_id Left Join iva on iva.id = articoli.iva Left Join unitadimisura on unitadimisura.id = articoli.umid where ks_amazon_products.item_sku = '" & orderItem.sku & "' and country_code = '" & countryCode & "'")
				dr.Read()
				orderItem.productId = dr("product_id")
				Dim singleItemWeight As Double = dr("package_weight")
				orderItem.ean = dr("ean")
				orderItem.vat = dr("valore")
				Dim ivaId As String = dr("ivaId")
				orderItem.description = Replace(dr("item_name"),"'","\'")
				orderItem.tcId = dr("tc_id")
				orderItem.um = dr("um")
				orderItem.accountSales = dr("contovend")
				dr.Close()
				packages += orderItem.quantityOrdered
				orderItem.weight = orderItem.quantityOrdered * singleItemWeight
				totalWeight += orderItem.weight
				If Not isOrderPending(orderStatus) Then
					calculateItemPriceAndShippingPrice(conn, orderItem, documentDefaultData)
				End If
				totalAssurancePrice += orderItem.assurancePrice
				totalShippingPrice += orderItem.shippingPrice
				totalPrice += orderItem.itemPrice + orderItem.shippingPrice + orderItem.assurancePrice
				totalDocumentPrice += orderItem.quotedItemPrice + orderItem.quotedShippingPrice + orderItem.quotedAssurancePrice
				totalVat += orderItem.quotedItemPrice + orderItem.quotedShippingPrice + orderItem.quotedAssurancePrice - (orderItem.itemPrice + orderItem.shippingPrice + orderItem.assurancePrice)
				ExecuteQuery(conn, "insert into documentirighe (DocumentiId, articoliId, ean, codice, descrizione1, um, peso, prezzo, qnt, importo, iva, qntevadibile, TCid, idConto ) " & _
							"VALUES (" & documentId & ", " & orderItem.productId & ", '" & orderItem.ean & "', '" & orderItem.sku & "', '" & orderItem.description & "', " & orderItem.um & ", " & formatDecimalNumber(orderItem.weight) & ", " & formatDecimalNumber(orderItem.itemPrice / orderItem.quantityOrdered) & ", " & orderItem.quantityOrdered & ", " & formatDecimalNumber(orderItem.itemPrice) & ", " & ivaId & ", " & orderItem.quantityOrdered & ", " & orderItem.tcId & ", " & orderItem.accountSales & " )", SqlExecutionType.nonQuery)
				ExecuteQuery(conn, "UPDATE articoli_giacenze SET giacenza = giacenza - " & orderItem.quantityOrdered & " where articoliId = " & orderItem.productId, SqlExecutionType.nonQuery)
			Next
		Catch ex As Exception
			dr.Close()
			'deleteDocumentRows(conn, dr, documentId)
			Throw ex
		End Try
        ExecuteQuery(conn, "insert into documentipie (DocumentiId, CausaliTrasportoId, CausaliPortoId, VettoriId, colli, peso, CausaliAspettoId, costoassicurazione, costospedizione, TotImponibile, TotIva, TotaleDocumento ) " & _
                        "VALUES (" & documentId & ", " & documentDefaultData.transportCausalId & ", " & documentDefaultData.portCausalId & ", " & documentDefaultData.carrierId & ", " & packages & ", " & formatDecimalNumber(totalWeight) & ", " & documentDefaultData.shapeCausalId & ", " & formatDecimalNumber(totalAssurancePrice) & ", " & formatDecimalNumber(totalShippingPrice) & ", " & formatDecimalNumber(totalPrice) & ", " & formatDecimalNumber(totalVat) & ", " & formatDecimalNumber(totalDocumentPrice) & " )", SqlExecutionType.nonQuery)
        ExecuteQuery(conn, "insert into documentiplus (DocumentiId, spedizione) VALUES (" & documentId & ", 1 )", SqlExecutionType.nonQuery)
    End Sub

    Protected Sub calculateItemPriceAndShippingPrice(ByVal conn As MySqlConnection, ByRef orderItem As OrderItem, ByVal documentDefaultData As DocumentDefaultData)
        Dim orderItemVat As Double = (100 + orderItem.vat) / 100
        Dim carrierVat As Double = (100 + documentDefaultData.carrierVat) / 100
        If documentDefaultData.mode = 1 Then
            orderItem.shippingPrice = orderItem.quotedShippingPrice / carrierVat
            orderItem.itemPrice = orderItem.quotedItemPrice / orderItemVat
        Else
            Dim dr As MySqlDataReader
            dr = getDataReader(conn, "select COUNT(vettoricosti.id) as n_rows, CostoFisso, Costo_Percentuale from vettoricosti where vettoriId = " & documentDefaultData.carrierId & " And PesoMax > " & formatDecimalNumber(orderItem.weight / orderItem.quantityOrdered) & " Order by PesoMax Asc")
            dr.Read()
            If dr("n_rows") = 0 Then
                dr.Close()
                dr = getDataReader(conn, "select CostoFisso, Costo_Percentuale from vettoricosti where vettoriId = " & documentDefaultData.carrierId & " And PesoMax < " & formatDecimalNumber(orderItem.weight / orderItem.quantityOrdered) & " Order by PesoMax Desc")
                dr.Read()
            End If
            Dim carrierFixedCost As Double = dr("CostoFisso") * orderItem.quantityOrdered
            Dim carrierPercentageCost As Double = dr("Costo_Percentuale")
            dr.Close()
            If documentDefaultData.mode = 2 Then
                If carrierFixedCost = 0 Then
                    If carrierPercentageCost > 0 Then
                        orderItem.itemPrice = orderItem.quotedItemPrice / (orderItemVat + (carrierPercentageCost / 100) * carrierVat)
                        orderItem.quotedItemPrice = orderItem.itemPrice * orderItemVat
                        orderItem.shippingPrice = orderItem.itemPrice * carrierPercentageCost / 100
                        orderItem.quotedShippingPrice = orderItem.shippingPrice * carrierVat
                    End If
                Else
                    orderItem.shippingPrice = carrierFixedCost
                    orderItem.quotedShippingPrice = orderItem.shippingPrice * carrierVat
                    orderItem.quotedItemPrice -= orderItem.quotedShippingPrice
                    orderItem.itemPrice = orderItem.quotedItemPrice / orderItemVat
                End If
            Else
                If carrierFixedCost = 0 Then
                    If carrierPercentageCost > 0 Then
                        orderItem.itemPrice = orderItem.quotedItemPrice / (orderItemVat + (carrierPercentageCost / 100) * carrierVat + (documentDefaultData.assurancePercentage / 100) * carrierVat)
                        orderItem.assurancePrice = orderItem.itemPrice * documentDefaultData.assurancePercentage / 100
                        If orderItem.assurancePrice < documentDefaultData.assuranceMinimum Then
                            orderItem.assurancePrice = documentDefaultData.assuranceMinimum
                            orderItem.quotedAssurancePrice = orderItem.assurancePrice * carrierVat
                            orderItem.quotedItemPrice -= orderItem.quotedAssurancePrice
                            orderItem.itemPrice = orderItem.quotedItemPrice / (orderItemVat + (carrierPercentageCost / 100) * carrierVat)
                            orderItem.quotedItemPrice = orderItem.itemPrice * orderItemVat
                            orderItem.shippingPrice = orderItem.itemPrice * carrierPercentageCost / 100
                            orderItem.quotedShippingPrice = orderItem.shippingPrice * carrierVat
                        Else
                            orderItem.quotedAssurancePrice = orderItem.assurancePrice * carrierVat
                            orderItem.quotedItemPrice = orderItem.itemPrice * orderItemVat
                            orderItem.shippingPrice = orderItem.itemPrice * carrierPercentageCost / 100
                            orderItem.quotedShippingPrice = orderItem.shippingPrice * carrierVat
                        End If
                    End If
                Else
                    orderItem.shippingPrice = carrierFixedCost
                    orderItem.quotedShippingPrice = orderItem.shippingPrice * carrierVat
                    orderItem.quotedItemPrice -= orderItem.quotedShippingPrice
                    orderItem.itemPrice = orderItem.quotedItemPrice / (orderItemVat + (documentDefaultData.assurancePercentage / 100) * carrierVat)
                    orderItem.assurancePrice = orderItem.itemPrice * documentDefaultData.assurancePercentage / 100
                    If orderItem.assurancePrice < documentDefaultData.assuranceMinimum Then
                        orderItem.assurancePrice = documentDefaultData.assuranceMinimum
                        orderItem.quotedAssurancePrice = orderItem.assurancePrice * carrierVat
                        orderItem.quotedItemPrice -= orderItem.quotedAssurancePrice
                        orderItem.itemPrice = orderItem.quotedItemPrice / orderItemVat
                    Else
                        orderItem.quotedAssurancePrice = orderItem.assurancePrice * carrierVat
                        orderItem.quotedItemPrice = orderItem.itemPrice * orderItemVat
                    End If
                End If
            End If
        End If
    End Sub

    Protected Function getOrderItem(ByVal orderItem As DataRow, ByVal itemPrice As DataTable, ByVal shippingPrice As DataTable) As OrderItem
        Dim resultOrderItem As New OrderItem
        resultOrderItem.asin = orderItem("ASIN")
		resultOrderItem.sku = orderItem("SellerSKU")
        resultOrderItem.quantityOrdered = orderItem("QuantityOrdered")
        Dim pageId As String = orderItem("Page_Id")
        Dim orderItem_Id As String = orderItem("OrderItem_Id")
        If Not itemPrice Is Nothing Then
            resultOrderItem.quotedItemPrice = Replace(itemPrice.Select("page_id = " & pageId & " And OrderItem_Id = " & orderItem_Id)(0)("Amount"), ".", ",")
        End If
        If Not shippingPrice Is Nothing Then
            resultOrderItem.quotedShippingPrice = Replace(shippingPrice.Select("page_id = " & pageId & " And OrderItem_Id = " & orderItem_Id)(0)("Amount"), ".", ",")
        End If
        Return resultOrderItem
    End Function

    Protected Function formatDecimalNumber(ByVal number As Double) As String
        Return Replace(CStr(number), ",", ".")
    End Function

	Protected Function getValueCheckingDbNull(ByVal dr As MySqlDataReader, ByVal field As String, ByVal defaultValue As String) As String
		Dim result As String = defaultValue
		If (Not IsDBNull(dr.item(field))) Then
			result = dr.item(field)
		End If
		return result
	End Function
	
    Protected Sub exportFeeds()
        

        Dim phase As Integer = Request.QueryString("phase")
        Select Case phase
            Case 1
				Dim conn = New MySqlConnection()
				conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
				conn.Open()
				Dim dr As MySqlDataReader
                dr = getDataReader(conn, "SELECT enabled, `update`, `updates` AS partialupdates, force_partialupdate, force_update, marketplaces FROM ks_amazon_data, ks_updates")
                dr.Read()
                Dim responseString As String = dr.Item("enabled").ToString + "|" + dr.Item("update").ToString + "|" + dr.Item("partialupdates").ToString + "|" + dr.Item("force_partialupdate").ToString + "|" + dr.Item("force_update").ToString + "|" + dr.Item("marketplaces").ToString
                dr.Close()
                conn.Close()
                conn.Dispose()
                Response.Write(responseString)
            Case 2
				importOrders()
				Dim conn = New MySqlConnection()
				conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
				conn.Open()
				Dim dr As MySqlDataReader
                Response.ContentType = "application/txt"
                Response.AddHeader("content-disposition", "attachment; filename=amazon.txt")
                Dim header As String = Request.QueryString("header")
                Response.Write(header & Environment.NewLine)
				Dim requestedHeader() As String = header.Split(vbCrLf)(2).Split(vbTab)
				Dim formatString As String = Request.QueryString("formatString")
                Dim requestedData() As String = formatString.Split("|"c)
				Dim marketplace As String = Request.QueryString("marketplace")
                dr = getDataReader(conn, "select min_quantity, company_id from ks_amazon_data")
                dr.Read()
                Dim minQuantity As Integer = dr.Item("min_quantity")
				Dim companyId As String = dr.Item("company_id")
                dr.Close()
                dr = getDataReader(conn, "select TC from aziende where id = " + companyId)
                dr.Read()
                Dim TC As Integer = dr.Item("TC")
                dr.Close()
                Dim queryPartGiacenze As String
				'Dim queryPartGiacenzeWhere As String
                If TC = 0 Then
                    queryPartGiacenze = "ks_amazon_products.product_id = articoli_giacenze.ArticoliId"
					'queryPartGiacenzeWhere = "articoli_giacenze.Giacenza >= " & minQuantity
                Else
                    queryPartGiacenze = "ks_amazon_products.tc_id = articoli_giacenze.TCid"
					'queryPartGiacenzeWhere = "((parent_child = 'child' and articoli_giacenze.Giacenza >= " & minQuantity & ") OR (parent_child = 'parent'))"
                End If
                'dr = getDataReader(conn, "select ks_amazon_products.*, articoli_giacenze.Giacenza as quantity from ks_amazon_products LEFT JOIN articoli_giacenze ON " & queryPartGiacenze & " LEFT JOIN articoli ON ks_amazon_products.product_id = articoli.id where articoli.Abilitato = 1 and ks_amazon_products.enabled = 1 and country_code = '"& marketplace & "' and " & queryPartGiacenzeWhere & ";", 300)
                'dr = getDataReader(conn, "select ks_amazon_products.*, CASE WHEN articoli_giacenze.Giacenza >= " & minQuantity & " THEN articoli_giacenze.Giacenza ELSE 0 END as quantity from ks_amazon_products LEFT JOIN articoli_giacenze ON " & queryPartGiacenze & " LEFT JOIN articoli ON ks_amazon_products.product_id = articoli.id where articoli.Abilitato = 1 and ks_amazon_products.enabled = 1 and country_code = '"& marketplace & "';", 300)
				Dim queryPartQuantityCase As String = "CASE WHEN articoli_giacenze.Giacenza >= " & minQuantity & " AND articoli.Abilitato = 1 and ks_amazon_products.enabled = 1 THEN articoli_giacenze.Giacenza ELSE 0 END"
				Dim queryPartJoin As String = " LEFT JOIN articoli_giacenze ON " & queryPartGiacenze & " LEFT JOIN articoli ON ks_amazon_products.product_id = articoli.id"
				Dim queryPartWhere As String = " where ks_amazon_products.last_quantity_exported <> " & queryPartQuantityCase & " AND country_code = '"& marketplace & "';"
				dr = getDataReader(conn, "select ks_amazon_products.*, " & queryPartQuantityCase & " as quantity from ks_amazon_products" & queryPartJoin & queryPartWhere, 300)
				Dim resultString As String
                While dr.Read()
                    resultString = ""
                    For i = 0 To requestedData.Length - 1
                        Dim column As String = requestedHeader(i).Trim
                        Dim value As String = requestedData(i).Trim
                        Select Case requestedData(i)
                            Case ""
								If TC = 1 Then
									If column = "relationship_type" Then
										If Not dr.Item("parent_child") = "parent" Then
											resultString &= "variation"
										End If
									Else If column = "variation_theme" Then
										resultString &= "SizeName-ColorName"
									Else
										resultString &= ""
									End If
								End If
                            Case "x"
								If column = "standard_price" Then
									Dim now As DateTime = DateTime.Now
									Dim resultBegin As Integer = DateTime.Compare(now, dr.Item("date_offer_begin"))
									Dim resultEnd As Integer = DateTime.Compare(now, dr.Item("date_offer_end"))
								    If resultBegin >= 0 AndAlso resultEnd <= 0 Then
										resultString &= Replace(dr.Item("offer_price"),",",".")     
									Else
										resultString &= Replace(dr.Item(column),",",".")
									End If
								Else If column = "package_weight" Then
									resultString &= Replace(dr.Item(column),",",".")
								Else
									resultString &= dr.Item(column)
								End If
                            Case Else
                                resultString &= value.Replace(Chr(10),"").Replace(Chr(13),"")
                        End Select
                        resultString &= vbTab
                    Next i
                    Response.Write(resultString & Environment.NewLine)
                End While
                dr.Close()
                Dim sqlString As String = "UPDATE ks_amazon_products" & queryPartJoin & " SET last_quantity_exported = " & queryPartQuantityCase & queryPartWhere
                ExecuteQuery(conn, sqlString, SqlExecutionType.nonQuery)
                conn.Close()
                conn.Dispose()
            Case 3
				Dim conn = New MySqlConnection()
				conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
				conn.Open()
                Dim subaction As String = Request.QueryString("subaction")
                Dim executionStatus As String = Request.QueryString("executionStatus")
                Dim sqlString As String = "UPDATE ks_amazon_data SET execution_status_export_feeds = '" & Now() & ":" & executionStatus & "'"
                Select Case subaction
                    Case "update"
                        sqlString = sqlString & ", force_update = 0"
                    Case "partialupdate"
                        sqlString = sqlString & ", force_partialupdate = 0"
                End Select
                ExecuteQuery(conn, sqlString, SqlExecutionType.nonQuery)
                conn.Close()
                conn.Dispose()
                Response.Write("True")
        End Select
    End Sub

End Class
