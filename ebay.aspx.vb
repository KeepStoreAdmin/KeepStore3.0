Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.IO
Imports EbayUtilities.KsEbayServiceSoapClient
Imports System.Xml
Imports Ionic.Zip
'Imports Microsoft.VisualBasic.FileIO

Partial Class ebay
    Inherits System.Web.UI.Page

	Const SANDBOX_TOKEN As String = "AgAAAA**AQAAAA**aAAAAA**1Y88Xg**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4agDZCBpw+dj6x9nY+seQ**RZMEAA**AAMAAA**wMVjtEFJLuqrluA9pX1uSo/lhDLlUp7c5lIhv7tvsynuxyfj5vT39w/IITnDP40yhn1xaXF/xXVFAnTLDklU6WT7rqA1y63Dcfnic2fEYPnjdPUznzNJ+uSq6iv8u2vcAcORfXiXSW74CYApV9gAbGOWT8AyNr18j/vpJWOcyIyJTmKFAgrN/Fk2npDKK8EohEchow9Xc+g5XE2jsCgNyROgCDEgVqYyKytemprrdT/zOaTJVSuBx44nyOd8eEZ0x79pPUzkUVJKL38EwDeQ1NPGn3q5b5egdobEDBNyA2+ClIxbksxfv/MNPevJ1NnNvU3jb3cUG15ZbzZVFlefXORi26eRmIMD1kZyQoG33lXi4xqGUW0cDIvoDGeg14rP6D6pXH7iC5J2LZO55dOPxfKx6eLYr5uzTqMJqaw7+KZbAnU/sAt/eGSj8hWEQU+tfRFYdWm+R0M6aQofRwHKraQzlTv8TlPDhIR6rRgogNild9WgxlxxvHC/nhHG6udJNAQmyqbzmUgNHrdJQNrNbNiXHiK94Kca4enRDQMRfyFtT2mMIc9PNi/D5HR4fssAxEeTQClEDHMkvpX1nGfMYLQsHlOrBHC2U9fapIZNHdgyTpQKRzRutDMTL/322/aU+ExF+B/l2tOj1LERAiV1b9exrYs/SOwG8u5cPUEjk+Pi3WgZxAx+FojdXzka5UYbc93s/3ANzTjJjWxxgGSar1sQ+R4w8BP1kguWrApj8oMi6ndLMM9H2W00ZG27pm+P"
	
	Const SANDBOX_ACTIVE As Boolean = true
	
	Enum XmlAndZipFilesType
		toEndItem
		toAddItem
		toReviseItem
	End Enum
	
	Enum GlobalXmlFields
        condition_id
        currency
		description
		dispatch_time_max
		brand
		location
		postal_code
		category_id
		payment_profile_id
		return_profile_id
		shipping_profile_id
		title
		site
    End Enum
	
	Enum VariationXmlFields
        quantity
        ean
        sku
		color
		size
    End Enum
	
	Const API_VERSION As String = "1095"
	
	Const BULK_HEADER As String = "<?xml version=""1.0"" encoding=""UTF-8""?>" & vbNewLine & _
									"<BulkDataExchangeRequests xmlns=""urn:ebay:apis:eBLBaseComponents"">" & vbNewLine & _
									"<Header>" & vbNewLine & _
									"<Version>${version}</Version>" & vbNewLine & _
									"<SiteID>${site_id}</SiteID>" & vbNewLine & _
									"</Header>"
									
	Const REQUEST_HEADER As String = "<${request} xmlns=""urn:ebay:apis:eBLBaseComponents"">" & vbNewLine & _
								  "<ErrorLanguage>it_IT</ErrorLanguage>" & vbNewLine & _
								  "<WarningLevel>High</WarningLevel>" & vbNewLine & _
								  "<Version>${version}</Version>" & vbNewLine
	
	Const REQUEST_FOOTER As String = "</${request}>"
	
	Const BULK_FOOTER As String = "</BulkDataExchangeRequests>"
	
	Const ITEM As String = 	"<Item>" & vbNewLine & _
							"<ConditionID>${condition_id}</ConditionID>" & vbNewLine & _
							"<Country>${country}</Country>" & vbNewLine & _
							"<Currency>${currency}</Currency>" & vbNewLine & _
							"<Description>${description}</Description>" & vbNewLine & _
							"<DispatchTimeMax>${dispatch_time_max}</DispatchTimeMax>" & vbNewLine & _
							"<InventoryTrackingMethod>SKU</InventoryTrackingMethod>" & vbNewLine & _
							"<ItemSpecifics>" & vbNewLine & _ 
							"<NameValueList>" & vbNewLine & _
							"<Name>Brand</Name>" & vbNewLine & _
							"<Value>${brand}</Value>" & vbNewLine & _
							"</NameValueList>" & vbNewLine & _
							"${ean}" & vbNewLine & _
							"</ItemSpecifics>" & vbNewLine & _
							"<ListingDuration>GTC</ListingDuration>" & vbNewLine & _
							"<ListingType>FixedPriceItem</ListingType>" & vbNewLine & _
							"<Location>${location}</Location>" & vbNewLine & _
							"<PostalCode>${postal_code}</PostalCode>" & vbNewLine & _
							"<PrimaryCategory>" & vbNewLine & _
							"<CategoryID>${category_id}</CategoryID>" & vbNewLine & _
							"</PrimaryCategory>" & vbNewLine & _
							"${quantity}" & vbNewLine & _
							"<SellerProfiles>" & vbNewLine & _
							"<SellerPaymentProfile>" & vbNewLine & _
							"<PaymentProfileID>${payment_profile_id}</PaymentProfileID>" & vbNewLine & _
							"</SellerPaymentProfile>" & vbNewLine & _
							"<SellerReturnProfile>" & vbNewLine & _
							"<ReturnProfileID>${return_profile_id}</ReturnProfileID>" & vbNewLine & _
							"</SellerReturnProfile>" & vbNewLine & _
							"<SellerShippingProfile>"  & _
							"<ShippingProfileID>${shipping_profile_id}</ShippingProfileID>" & vbNewLine & _
							"</SellerShippingProfile>" & vbNewLine & _
							"</SellerProfiles>" & vbNewLine & _
							"<Site>${site}</Site>" & vbNewLine & _
							"${sku}" & vbNewLine & _
							"${start_price}" & vbNewLine & _
							"<Title>${title}</Title>" & vbNewLine & _
							"<PictureDetails>" & vbNewLine & _
							"${pictures}" & vbNewLine & _
							"</PictureDetails>" & vbNewLine & _
							"${variations}" & vbNewLine & _
							"</Item>" & vbNewLine

	Const SKU As String = 	"<SKU>${sku}</SKU>"
									
	Const QUANTITY As String = 	"<Quantity>${quantity}</Quantity>"
									
	Const EAN As String = 	"<NameValueList>" & vbNewLine & _
							"<Name>EAN</Name>" & vbNewLine & _
							"<Value>${ean}</Value>" & vbNewLine & _
							"</NameValueList>"
	
	Const START_PRICE As String = "<StartPrice>${start_price}</StartPrice>"
	
	Const VARIATIONS As String = 	"<Variations>" & vbNewLine & _
									"<Pictures>" & vbNewLine & _
									"<VariationSpecificName>Color</VariationSpecificName>" & vbNewLine & _
									"${pictures}" & vbNewLine & _
									"</Pictures>" & vbNewLine & _
									"<VariationSpecificsSet>" & vbNewLine & _
									"<NameValueList>" & vbNewLine & _
									"<Name>Color</Name>" & vbNewLine & _
									"${colors}" & vbNewLine & _
									"</NameValueList>" & vbNewLine & _
									"<NameValueList>" & vbNewLine & _
									"<Name>Size</Name>" & vbNewLine & _
									"${sizes}" & vbNewLine & _
									"</NameValueList>" & vbNewLine & _
									"</VariationSpecificsSet>" & vbNewLine & _
									"${variations}" & vbNewLine & _
									"</Variations>"
									
	Const VARIATION As String = 	"<Variation>" & vbNewLine & _
									"<Quantity>${quantity}</Quantity>" & vbNewLine & _
									"<SKU>${sku}</SKU>" & vbNewLine & _
									"<StartPrice>${start_price}</StartPrice>" & vbNewLine & _
									"<VariationProductListingDetails>" & vbNewLine & _
									"<EAN>${ean}</EAN>" & vbNewLine & _
									"</VariationProductListingDetails>" & vbNewLine & _
									"<VariationSpecifics>" & vbNewLine & _
									"<NameValueList>" & vbNewLine & _
									"<Name>Color</Name>" & vbNewLine & _
									"<Value>${color}</Value>" & vbNewLine & _
									"</NameValueList>" & vbNewLine & _
									"<NameValueList>" & vbNewLine & _
									"<Name>Size</Name>" & vbNewLine & _
									"<Value>${size}</Value>" & vbNewLine & _
									"</NameValueList>" & vbNewLine & _
									"</VariationSpecifics>" & vbNewLine & _
									"</Variation>"

	Const PICTURE_URL As String =	"<PictureURL>${picture_url}</PictureURL>"		
							
	Const VALUE As String =	"<Value>${value}</Value>"

	Const VARIATIONS_PICTURES As String = "<VariationSpecificPictureSet>" & vbNewLine & _
								"<VariationSpecificValue>${variation_specific_value}</VariationSpecificValue>" & vbNewLine & _
								"${picture_url}" & vbNewLine & _
								"</VariationSpecificPictureSet>" 

	Const END_ITEM As String = "<SKU>${sku}</SKU>" & vbNewLine & _
								"<EndingReason>NotAvailable</EndingReason>"
								
    Dim ebayUtilities As New EbayUtilities.KsEbayServiceSoapClient

	Const PENDING_STATE_ID As String = "6"
	Const UNSHIPPED_STATE_ID As String = "1"
    Const SHIPPED_STATE_ID As String = "4"
    Const CANCELED_STATE_ID As String = "3"

	Const CANCELED As String = "CANCELED"
	
	Public Structure EbayData
		Public clientSecret As String
        Public accessToken As String
		Public countries As String
    End Structure
       
    Public Structure DocumentDefaultData
        Public mode As String
		Public countries As String
        Public documenTypeId As String
        Public companyId As String
        Public userId As String
        Public carrierId As String
        Public carrierVat As String
        Public assurancePercentage As String
        Public assuranceMinimum As String
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

    Public Structure OrderItemPrices
		Public vat As Double
        Public quotedItemPrice As Double
        Public quotedShippingPrice As Double
        Public quotedAssurancePrice As Double
        Public itemPrice As Double
        Public shippingPrice As Double
        Public assurancePrice As Double
    End Structure

	Enum EbayOrderFulfillmentStatus
        not_started
        in_progress
        fulfilled
    End Enum
	
	Enum EbayOrderStatus
        pending
        unshipped
		shipped
		canceled
		cancelPending
		inProcess
		inactive
    End Enum
	
    Enum SqlExecutionType
        nonQuery
        scalar
    End Enum

	Enum SkuListInclusionType
		Included
		Not_Included
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
			Case "test_import_orders"
				importOrders()
            Case "import_orders"
                'importOrders()
            Case "export_feeds"
                exportFeeds()
			Case "store_token"
				storeToken()
        End Select

    End Sub

	Protected Sub storeToken()
		Dim result As String = String.Empty
		Dim secret As String = HttpUtility.UrlDecode(Request.QueryString("secret"))
		Dim conn = New MySqlConnection()
		conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
		conn.Open()
		dim ebayData as EbayData = getAllData()
		If ebayData.clientSecret = secret Then
			Dim sessionId As String = HttpUtility.UrlDecode(Request.QueryString("session_id"))
			REM Dim token As XmlDocument = ToXmlDocument(ebayUtilities.fetchToken(sessionId))
			REM Dim root As XmlElement = token.DocumentElement
			Dim root As XmlElement = ebayUtilities.fetchToken(sessionId)
			Dim accessToken As String = root.getElementsByTagName("eBayAuthToken").Item(0).innerText 'tokens.tables(0).rows(0).item(4)
			'accessToken = accessToken.replace(" ","+")
			if accessToken <> "" Then
				'Dim accessTokenExpiryDate As String = Today.addDays(180)
				'Dim sqlString As String = String.format("UPDATE ks_ebay_data SET access_token = '{0}', access_token_expiry_date = {1}", accessToken, accessTokenExpiryDate)
				Dim sqlString As String = String.format("UPDATE ks_ebay_data SET access_token = '{0}'", accessToken)
				ExecuteQuery(conn, sqlString, SqlExecutionType.nonQuery)
				result = "Autorizzazione completata.<br>Puoi chiudere la finestra o la scheda del browser"
			Else
				result = "Access Token vuoto"
			End If
		Else
			result = "Secret errato"
		End If
		conn.Close()
		conn.Dispose()
		Response.Write(result)
		Response.End()
	End Sub
	
	protected Function getAllData() as EbayData
		Dim conn = New MySqlConnection()
		conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
		conn.Open()
		Dim dr As MySqlDataReader
        Dim query As String = "select * from ks_ebay_data"
        dr = getDataReader(conn, query)
        dr.Read()
		dim ebayData as new EbayData
		ebayData.accessToken = dr.Item("access_token")
		ebayData.clientSecret = dr.Item("secret")
		ebayData.countries = dr.Item("countries")
		dr.Close()
		return ebayData
	End Function
	
	Protected Function getValueCheckingDbNull(ByVal dr As MySqlDataReader, ByVal field As String, ByVal defaultValue As String) As String
		Dim result As String = defaultValue
		If (Not IsDBNull(dr.item(field))) Then
			result = dr.item(field)
		End If
		return result
	End Function
	
     protected sub importorders()
		Dim result As String = String.Empty
		Dim secret As String = HttpUtility.UrlDecode(Request.QueryString("secret"))
		Dim ebayData as EbayData = getAllData()
		dim conn = new mysqlconnection()
		conn.connectionstring = configurationmanager.connectionstrings("entropicconnectionstring").connectionstring
		conn.open()
		If ebayData.clientSecret = secret Then
			dim dr as mysqldatareader
			dim query as string = "select document_type_id, company_id, user_id, carrier_id, mode, access_token, agenteid, provvigione1, tipopagamento, listino, causaliportoid, causalitrasportoid, causaliaspettoid, valore, vettori.descrizione as carriername, assicurazioneminimo, assicurazionepercentuale, indirizzo, citta, provincia, cap, telefono, fax from ks_ebay_data "
			query &= "left join utenti on utenti.id=ks_ebay_data.user_id "
			query &= "left join utentiagenti on utentiagenti.utentiid = ks_ebay_data.user_id "
			query &= "left join utentirapporto on utentirapporto.utenteid = ks_ebay_data.user_id "
			query &= "left join tipodocumenti on tipodocumenti.id = ks_ebay_data.document_type_id "
			query &= "left join vettori on vettori.id = ks_ebay_data.carrier_id and vettori.aziendeid = ks_ebay_data.company_id "
			query &= "left join iva on iva.id = vettori.iva"
			dr = getdatareader(conn, query)
			dr.read()
			Dim documentDefaultData As New DocumentDefaultData
			dim carriername as string = dr.item("carriername")
			documentDefaultData.mode = dr.item("mode")
			documentDefaultData.documentypeid = dr.item("document_type_id")
			documentDefaultData.companyid = dr.item("company_id")
			documentDefaultData.userid = dr.item("user_id")
			documentDefaultData.carrierid = dr.item("carrier_id")
			documentDefaultData.carriervat = dr.item("valore")
			documentDefaultData.assuranceMinimum = getValueCheckingDbNull(dr,"assicurazioneMinimo","0")
			documentDefaultData.assurancePercentage = getValueCheckingDbNull(dr,"assicurazionePercentuale","0")
			documentDefaultData.agentId = getValueCheckingDbNull(dr,"agenteId","NULL")
			documentDefaultData.commission = getValueCheckingDbNull(dr,"provvigione1","NULL")
			documentDefaultData.paymenttypeid = dr.item("tipopagamento")
			documentDefaultData.pricelist = dr.item("listino")
			documentDefaultData.portcausalid = dr.item("causaliportoid")
			documentDefaultData.transportcausalid = dr.item("causalitrasportoid")
			documentDefaultData.shapecausalid = dr.item("causaliaspettoid")
			documentDefaultData.registeredoffice = dr.item("indirizzo") & vbcrlf & dr.item("cap") & " " & dr.item("citta") & " " & dr.item("provincia") & vbcrlf & "tel:" & dr.item("telefono") & vbcrlf & "fax." & dr.item("fax")
			dr.close()
			dim now as datetime = datetime.now
			documentDefaultData.datedocument = now.tostring("yyyy-MM-dd")
			documentDefaultData.year = now.tostring("yyyy")
			Dim countries as String() = ebayData.countries.Trim().Split(",")
			Dim accessToken As String
			if SANDBOX_ACTIVE then
				accessToken = SANDBOX_TOKEN
			else
				accessToken = ebayData.accessToken
			end if
			For Each country As String In countries
				try
					if result <> String.Empty Then result &= " - "
					result &= country & ": " & analyzeNewOrders(conn, dr, documentDefaultData, accessToken, country)
				catch ex As Exception
					result &= "error analyzing orders on country "& country & ":" & Replace(ex.Message (), "'", """") & " - " 
				end try
			Next
		Else
			result = "Secret errato"
		End If
		dim sqlstring as string = "update ks_ebay_data set execution_status_import_orders = '" & now & ":" & result & "'"
		executequery(conn, sqlstring, sqlexecutiontype.nonquery)
		conn.Close()
		conn.Dispose()
		Response.Write(result)
		Response.End()
     end sub

	Protected Function analyzeNewOrders(ByVal conn As MySqlConnection, ByVal dr As MySqlDataReader, ByRef documentDefaultData As DocumentDefaultData, ByVal accessToken As String, ByVal country As String) As String
		Dim result As String = String.Empty
		REM Dim neworders as XmlDocument = ToXmlDocument(ebayutilities.getNewOrders(accessToken, country))
		REM Dim root As XmlElement = neworders.DocumentElement
		Dim root As XmlElement = ebayutilities.getNewOrders(accessToken, country)
		Dim orderArray As XmlElement = root.getElementsByTagName("OrderArray").Item(0)
		Dim whereOrderIdIsDifferentFromAlreadyExaminated As String = ""
		if orderArray isNot Nothing then
			Dim orders As XmlNodeList = orderArray.ChildNodes			
			For Each order As XmlNode In orders
				Dim ebayOrderId As String = order.Item("OrderID").InnerText
				whereOrderIdIsDifferentFromAlreadyExaminated &= " And ebay_order_id != '" & ebayOrderId & "'"
				dr = getDataReader(conn, "select COUNT(ks_ebay_orders.id) as n_rows, order_status, statiid, documenti.tracking as tracking, vettoriid from ks_ebay_orders Left join documentipie on documentipie.documentiId = ks_ebay_orders.document_id Left join documenti on documenti.id = ks_ebay_orders.document_id where ebay_order_id = '" & ebayOrderId & "'")
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
				Dim orderStatus As String = getOrderStatus(order).toString
				If orderStatus = EbayOrderStatus.pending.toString Then 
					If Not orderExists Then
						documentDefaultData.statusId = PENDING_STATE_ID
						Dim documentId As String = insertOrderPendingOrUnshipped(conn, order, ebayOrderId, country, orderStatus, documentDefaultData)
						insertOrderRowsAndFoot(conn, dr, order, ebayOrderId, country, orderStatus, documentDefaultData, documentId)
					End If
				Else If orderStatus = EbayOrderStatus.unshipped.toString Then
					If Not orderExists Then
						documentDefaultData.statusId = UNSHIPPED_STATE_ID
						Dim documentId As String = insertOrderPendingOrUnshipped(conn, order, ebayOrderId, country, orderStatus, documentDefaultData)
						insertOrderRowsAndFoot(conn, dr, order, ebayOrderId, country, orderStatus, documentDefaultData, documentId)
					Else
						If existingOrderStatus = EbayOrderStatus.Pending.toString Then
							Dim documentId As String = updatePendingOrderToUnshipped(conn, order, ebayOrderId)
						End If
					End If
				Else If orderStatus = EbayOrderStatus.canceled.toString OrElse orderStatus = EbayOrderStatus.inactive.toString Then
				End If				
			Next
			result = "Import procedure correctly executed. Orders handled: " & orders.count
		End If
		return result
	End Function
	
	Protected Function getOrderStatus(ByVal order As XmlNode) As EbayOrderStatus
		Dim result As EbayOrderStatus
		Dim orderStatus As String =  order.Item("OrderStatus").InnerText
		if (String.Compare(orderStatus, "Active",True)=0) OrElse (String.Compare(orderStatus, "Completed",True)=0) Then
			Dim checkoutStatus As String = order.Item("CheckoutStatus").Item("Status").InnerText
			if String.Compare(checkoutStatus, "Incomplete") OrElse String.Compare(checkoutStatus, "Pending") Then
				result = EbayOrderStatus.Pending
			Else if IsDBNull(order.Item("ShippedTime")) Then
				result = EbayOrderStatus.Unshipped
			Else
				result = EbayOrderStatus.Shipped
			End If
		Else if (String.Compare(orderStatus, "Cancelled",True)=0) Then
			result = EbayOrderStatus.Canceled
		Else if (String.Compare(orderStatus, "CancelPending",True)=0) Then
			result = EbayOrderStatus.CancelPending
		Else if (String.Compare(orderStatus, "InProcess",True)=0) Then
			result = EbayOrderStatus.InProcess
		Else if (String.Compare(orderStatus, "Inactive",True)=0) Then
			result = EbayOrderStatus.Inactive
		End If
		return result
	End Function

	Protected Function getBuyerName(ByVal order As XmlNode) As String
		Dim Buyer As XmlElement = order.Item("TransactionArray").Item("Transaction").Item("Buyer")
		return Buyer.Item("UserFirstName").InnerText & " " & Buyer.Item("UserLastName").InnerText
	End Function

	Protected Function getAddress(ByVal order As XmlNode) As String
		Dim shippingAddress As XmlElement = order.Item("ShippingAddress")
        Dim name As String = shippingAddress.Item("Name").InnerText
		Dim addressLine As String = shippingAddress.Item("Street1").InnerText
		if shippingAddress.Item("Street2").InnerText <> String.Empty Then addressLine &= " " & shippingAddress.Item("Street2").InnerText
        Dim city As String = shippingAddress.Item("CityName").InnerText
        Dim postalCode As String = shippingAddress.Item("PostalCode").InnerText
		Dim stateOrRegion As String = shippingAddress.Item("StateOrProvince").InnerText
        Dim phone As String = shippingAddress.Item("Phone").InnerText
        Dim destination As String = name & vbCrLf & addressLine & vbCrLf & postalCode & " " & city & " " & stateOrRegion & vbCrLf & "Tel." & phone
		Return Replace(destination.ToUpper(),"'","\'")
    End Function

    Protected Function updatePendingOrderToUnshipped(ByVal conn As MySqlConnection, ByVal order As XmlNode, ByVal ebayOrderId As String) As String
        Dim buyerName As String = Replace(getBuyerName(order),"'","\'")
		Dim destination As String = getAddress(order)
        ExecuteQuery(conn, "UPDATE ks_ebay_orders SET order_status = '" + EbayOrderStatus.unshipped.ToString + "', buyer_name = '" + buyerName + "', destination = '" + destination + "' where ebay_order_id = '" & ebayOrderId & "'", SqlExecutionType.nonQuery)
        Dim documentId As String = ExecuteQuery(conn, "Select document_id from ks_ebay_orders where ebay_order_id = '" & ebayOrderId & "'", SqlExecutionType.scalar)
        ExecuteQuery(conn, "UPDATE documenti SET destinazioneMerci = '" + destination + "', statiid = " + UNSHIPPED_STATE_ID + ", utente = '" + destination.Split(vbCrLf)(0) + "' where id = " & documentId, SqlExecutionType.nonQuery)
        Return documentId
    End Function
	
	Protected Function insertOrderPendingOrUnshipped(ByVal conn As MySqlConnection, ByVal order As XmlNode, ByVal ebayOrderId As String, ByVal country As String, ByVal orderStatus As String, ByVal documentDefaultData As DocumentDefaultData) As String
		Dim buyerName As String = Replace(getBuyerName(order),"'","\'")
		Dim destination As String = getAddress(order)
		Return insertOrder(conn, country, ebayOrderId, orderStatus, documentDefaultData, "", "", order)
    End Function

    Protected Function insertOrder(ByVal conn As MySqlConnection, ByVal country As String, ByVal ebayOrderId As String, ByVal orderStatus As String, ByVal documentDefaultData As DocumentDefaultData, ByVal buyerName As String, ByVal destination As String, ByVal order As XmlNode) As String
        Dim purchaseDate As String = order.item("CreatedTime").InnerText.Split("T")(0)
		ExecuteQuery(conn, "insert into documenti (AziendeId, TipoDocumentiId, DataDocumento, UtentiId, Utente, AgentiId, Provvigione, DestinazioneMerci, PagamentiTipoId, Listino, StatiId, Anno, SedeLegale) " & _
                        "VALUES (" & documentDefaultData.companyId & ", " & documentDefaultData.documenTypeId & ", '" & documentDefaultData.dateDocument & "', " & documentDefaultData.userId & ", '" & buyerName & "', " & documentDefaultData.agentId & ", " & documentDefaultData.commission & ", '" & destination & "', " & documentDefaultData.paymentTypeId & ", " & documentDefaultData.priceList & ", " & documentDefaultData.statusId & ", " & documentDefaultData.year & ", '" & documentDefaultData.registeredOffice & "')", SqlExecutionType.nonQuery)
        Dim documentId As String = CStr(ExecuteQuery(conn, "Select LAST_INSERT_ID()", SqlExecutionType.scalar))
        ExecuteQuery(conn, "insert into ks_ebay_orders (document_id, ebay_order_id, country_code, order_status, buyer_name, destination, purchase_date) " & _
                        "VALUES (" & documentId & ", '" & ebayOrderId & "', '" & country & "', '" & orderStatus.ToString & "', '" & buyerName & "', '" & destination & "', '" & purchaseDate & "')", SqlExecutionType.nonQuery)
		return documentId
    End Function 
	
    Protected Sub insertOrderRowsAndFoot(ByVal conn As MySqlConnection, ByVal dr As MySqlDataReader, ByVal order As XmlNode, ByVal ebayOrderId As String, ByVal country As String, ByVal orderStatus As String, ByVal documentDefaultData As DocumentDefaultData, ByVal documentId As String)
		Dim transactionArray As XmlElement = order.Item("TransactionArray")
		if transactionArray isNot Nothing then			
		    Dim packages As Integer = 0
			Dim totalWeight As Double = 0
			Dim totalAssurancePrice As Double = 0
			Dim totalShippingPrice As Double = 0
			Dim totalDocumentPrice As Double = 0
			Dim totalPrice As Double = 0
			Dim totalVat As Double = 0
			Dim transactions As XmlNodeList = transactionArray.ChildNodes			
			For Each transaction As XmlNode In transactions
				Dim orderItemPrices As OrderItemPrices
				Dim item As XmlNode = transaction.item("Item")
				Dim sku As String = item.item("SKU").InnerText
				dr = getDataReader(conn, "select package_weight, product_id, description, tc_id, iva.valore as valore, iva.id as ivaid , ks_ebay_products.ean, unitadimisura.id as um, contovend from ks_ebay_products Left Join articoli on articoli.id = ks_ebay_products.product_id Left Join iva on iva.id = articoli.iva Left Join unitadimisura on unitadimisura.id = articoli.umid where ks_ebay_products.sku = '" & sku & "' and ks_ebay_products.country_code = '" & country & "'")
				dr.Read()
				Dim productId As String = dr("product_id")
				Dim singleItemWeight As Double = dr("package_weight")
				Dim ean As String = dr("ean")
				orderItemPrices.vat = dr("valore")
				Dim ivaId As String = dr("ivaId")
				Dim description As String = dr("description")
				Dim tcId As String = dr("tc_id")
				Dim um As String = dr("um")
				Dim accountSales As String = dr("contovend")
				Dim quantity As Integer = CType(transaction.item("QuantityPurchased").innerText,Integer)
				Dim weight As Double = dr("package_weight")
				packages += quantity
				totalWeight += quantity * weight
				dr.Close()
				orderItemPrices.quotedItemPrice = CType(order.item("Subtotal").innerText,Double) / quantity
				orderItemPrices.quotedShippingPrice = CType(order.item("ShippingServiceSelected").item("ShippingServiceCost").InnerText,Double)
				If orderStatus <> EbayOrderStatus.Pending.ToString Then
					calculateItemPriceAndShippingPrice(conn, orderItemPrices, weight, quantity, documentDefaultData)
				End If
				totalAssurancePrice += orderItemPrices.assurancePrice
				totalShippingPrice += orderItemPrices.shippingPrice
				totalPrice += orderItemPrices.itemPrice + orderItemPrices.shippingPrice + orderItemPrices.assurancePrice
				totalDocumentPrice += orderItemPrices.quotedItemPrice + orderItemPrices.quotedShippingPrice + orderItemPrices.quotedAssurancePrice
				totalVat += orderItemPrices.quotedItemPrice + orderItemPrices.quotedShippingPrice + orderItemPrices.quotedAssurancePrice - (orderItemPrices.itemPrice + orderItemPrices.shippingPrice + orderItemPrices.assurancePrice)
				ExecuteQuery(conn, "insert into documentirighe (DocumentiId, articoliId, ean, codice, descrizione1, um, peso, prezzo, qnt, importo, iva, qntevadibile, TCid, idConto ) " & _
							"VALUES (" & documentId & ", " & productId & ", '" & ean & "', '" & sku & "', '" & description & "', " & um & ", " & formatDecimalNumber(weight) & ", " & formatDecimalNumber(orderItemPrices.itemPrice / quantity) & ", " & quantity & ", " & formatDecimalNumber(orderItemPrices.itemPrice) & ", " & ivaId & ", " & quantity & ", " & tcId & ", " & accountSales & " )", SqlExecutionType.nonQuery)
				ExecuteQuery(conn, "UPDATE articoli_giacenze SET giacenza = giacenza - " & quantity & " where articoliId = " & productId, SqlExecutionType.nonQuery)
			Next
			ExecuteQuery(conn, "insert into documentipie (DocumentiId, CausaliTrasportoId, CausaliPortoId, VettoriId, colli, peso, CausaliAspettoId, costoassicurazione, costospedizione, TotImponibile, TotIva, TotaleDocumento ) " & _
							"VALUES (" & documentId & ", " & documentDefaultData.transportCausalId & ", " & documentDefaultData.portCausalId & ", " & documentDefaultData.carrierId & ", " & packages & ", " & formatDecimalNumber(totalWeight) & ", " & documentDefaultData.shapeCausalId & ", " & formatDecimalNumber(totalAssurancePrice) & ", " & formatDecimalNumber(totalShippingPrice) & ", " & formatDecimalNumber(totalPrice) & ", " & formatDecimalNumber(totalVat) & ", " & formatDecimalNumber(totalDocumentPrice) & " )", SqlExecutionType.nonQuery)
			ExecuteQuery(conn, "insert into documentiplus (DocumentiId, spedizione) VALUES (" & documentId & ", 1 )", SqlExecutionType.nonQuery)
		End If
	End Sub

    Protected Sub calculateItemPriceAndShippingPrice(ByVal conn As MySqlConnection, ByRef orderItemPrices As OrderItemPrices, ByVal weight As Double, ByVal quantity As Integer, ByVal documentDefaultData As DocumentDefaultData)
        Dim orderItemVat As Double = (100 + orderItemPrices.vat) / 100
        Dim carrierVat As Double = (100 + documentDefaultData.carrierVat) / 100
        If documentDefaultData.mode = 1 Then
            orderItemPrices.shippingPrice = orderItemPrices.quotedShippingPrice / carrierVat
            orderItemPrices.itemPrice = orderItemPrices.quotedItemPrice / orderItemVat
        Else
            Dim dr As MySqlDataReader
            dr = getDataReader(conn, "select COUNT(vettoricosti.id) as n_rows, CostoFisso, Costo_Percentuale from vettoricosti where vettoriId = " & documentDefaultData.carrierId & " And PesoMax > " & formatDecimalNumber(weight / quantity) & " Order by PesoMax Asc")
            dr.Read()
            If dr("n_rows") = 0 Then
                dr.Close()
                dr = getDataReader(conn, "select CostoFisso, Costo_Percentuale from vettoricosti where vettoriId = " & documentDefaultData.carrierId & " And PesoMax < " & formatDecimalNumber(weight / quantity) & " Order by PesoMax Desc")
                dr.Read()
            End If
            Dim carrierFixedCost As Double = dr("CostoFisso") * quantity
            Dim carrierPercentageCost As Double = dr("Costo_Percentuale")
            dr.Close()
            If documentDefaultData.mode = 2 Then
                If carrierFixedCost = 0 Then
                    If carrierPercentageCost > 0 Then
                        orderItemPrices.itemPrice = orderItemPrices.quotedItemPrice / (orderItemVat + (carrierPercentageCost / 100) * carrierVat)
                        orderItemPrices.quotedItemPrice = orderItemPrices.itemPrice * orderItemVat
                        orderItemPrices.shippingPrice = orderItemPrices.itemPrice * carrierPercentageCost / 100
                        orderItemPrices.quotedShippingPrice = orderItemPrices.shippingPrice * carrierVat
                    End If
                Else
                    orderItemPrices.shippingPrice = carrierFixedCost
                    orderItemPrices.quotedShippingPrice = orderItemPrices.shippingPrice * carrierVat
                    orderItemPrices.quotedItemPrice -= orderItemPrices.quotedShippingPrice
                    orderItemPrices.itemPrice = orderItemPrices.quotedItemPrice / orderItemVat
                End If
            Else
                If carrierFixedCost = 0 Then
                    If carrierPercentageCost > 0 Then
                        orderItemPrices.itemPrice = orderItemPrices.quotedItemPrice / (orderItemPrices.Vat + (carrierPercentageCost / 100) * carrierVat + (documentDefaultData.assurancePercentage / 100) * carrierVat)
                        orderItemPrices.assurancePrice = orderItemPrices.itemPrice * documentDefaultData.assurancePercentage / 100
                        If orderItemPrices.assurancePrice < documentDefaultData.assuranceMinimum Then
                            orderItemPrices.assurancePrice = documentDefaultData.assuranceMinimum
                            orderItemPrices.quotedAssurancePrice = orderItemPrices.assurancePrice * carrierVat
                            orderItemPrices.quotedItemPrice -= orderItemPrices.quotedAssurancePrice
                            orderItemPrices.itemPrice = orderItemPrices.quotedItemPrice / (orderItemPrices.Vat + (carrierPercentageCost / 100) * carrierVat)
                            orderItemPrices.quotedItemPrice = orderItemPrices.itemPrice * orderItemPrices.Vat
                            orderItemPrices.shippingPrice = orderItemPrices.itemPrice * carrierPercentageCost / 100
                            orderItemPrices.quotedShippingPrice = orderItemPrices.shippingPrice * carrierVat
                        Else
                            orderItemPrices.quotedAssurancePrice = orderItemPrices.assurancePrice * carrierVat
                            orderItemPrices.quotedItemPrice = orderItemPrices.itemPrice * orderItemPrices.Vat
                            orderItemPrices.shippingPrice = orderItemPrices.itemPrice * carrierPercentageCost / 100
                            orderItemPrices.quotedShippingPrice = orderItemPrices.shippingPrice * carrierVat
                        End If
                    End If
                Else
                    orderItemPrices.shippingPrice = carrierFixedCost
                    orderItemPrices.quotedShippingPrice = orderItemPrices.shippingPrice * carrierVat
                    orderItemPrices.quotedItemPrice -= orderItemPrices.quotedShippingPrice
                    orderItemPrices.itemPrice = orderItemPrices.quotedItemPrice / (orderItemPrices.Vat + (documentDefaultData.assurancePercentage / 100) * carrierVat)
                    orderItemPrices.assurancePrice = orderItemPrices.itemPrice * documentDefaultData.assurancePercentage / 100
                    If orderItemPrices.assurancePrice < documentDefaultData.assuranceMinimum Then
                        orderItemPrices.assurancePrice = documentDefaultData.assuranceMinimum
                        orderItemPrices.quotedAssurancePrice = orderItemPrices.assurancePrice * carrierVat
                        orderItemPrices.quotedItemPrice -= orderItemPrices.quotedAssurancePrice
                        orderItemPrices.itemPrice = orderItemPrices.quotedItemPrice / orderItemPrices.Vat
                    Else
                        orderItemPrices.quotedAssurancePrice = orderItemPrices.assurancePrice * carrierVat
                        orderItemPrices.quotedItemPrice = orderItemPrices.itemPrice * orderItemPrices.Vat
                    End If
                End If
            End If
        End If
    End Sub


    Protected Function formatDecimalNumber(ByVal number As Double) As String
        Return Replace(CStr(number), ",", ".")
    End Function

	private Function getDbConnection() As MySqlConnection
		Dim conn = New MySqlConnection()
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()
		return conn
	End Function
	
    Protected Sub exportFeeds()
        Dim conn As MySqlConnection
		Dim dr As MySqlDataReader
        Dim Phase As Integer = Request.QueryString("phase")
        Select Case Phase
            Case 1
				conn = getDbConnection()
                dr = getDataReader(conn, "select enabled, updates, force_update from ks_ebay_data")
                dr.Read()
                Dim responseString As String = dr.Item("enabled").ToString + "|" + dr.Item("updates").ToString + "|" + dr.Item("force_update").ToString 
                dr.Close()
                conn.Close()
                conn.Dispose()
                Response.Write(responseString)
                Response.End()
            Case 2
				Dim result As String = String.Empty
				Dim secret As String = HttpUtility.UrlDecode(Request.QueryString("secret"))
				Dim ebayData as EbayData = getAllData()
				If ebayData.clientSecret = secret Then
					Dim countries as String() = ebayData.countries.Trim().Split(",")
					Dim accessToken As String
					if SANDBOX_ACTIVE then
						accessToken = SANDBOX_TOKEN
					else
						accessToken = ebayData.accessToken
					end if
					For Each country As String In countries
						Dim activeSkuList As String = getSkuLists(accessToken, country, "ActiveList")
						Dim deletedFromSoldList As String = getSkuLists(accessToken, country, "DeletedFromSoldList")
						Dim deletedFromUnsoldList As String = getSkuLists(accessToken, country, "DeletedFromUnsoldList")
						Dim soldList As String = getSkuLists(accessToken, country, "SoldList")
						Dim unsoldList As String = getSkuLists(accessToken, country, "UnsoldList")
						Dim notActiveSkuList As String = String.Empty
						'addNotFirstSkuListToContainerSkuList(notActiveSkuList, deletedFromSoldList)
						'addNotFirstSkuListToContainerSkuList(notActiveSkuList, deletedFromUnsoldList)
						addNotFirstSkuListToContainerSkuList(notActiveSkuList, soldList)
						addNotFirstSkuListToContainerSkuList(notActiveSkuList, unsoldList)
						Dim activeAndNotActiveSkuList As String = String.Empty
						addNotFirstSkuListToContainerSkuList(activeAndNotActiveSkuList,activeSkuList)
						addNotFirstSkuListToContainerSkuList(activeAndNotActiveSkuList,notActiveSkuList)
						'Response.ContentType = "xml"
						'Response.AddHeader("content-disposition", "attachment; filename=item.xml")
						conn = getDbConnection()
						dr = getDataReader(conn, "select min_quantity, company_id from ks_ebay_data")
						dr.Read()
						Dim minQuantity As Integer = dr.Item("min_quantity")
						Dim companyId As String = dr.Item("company_id")
						dr.Close()
						dr = getDataReader(conn, "select TC from aziende where id = " + companyId)
						dr.Read()
						Dim TC As Integer = dr.Item("TC")
						'Dim TC As Integer = 1
						dr.Close()
						conn.Close()
						conn.Dispose()
						'new items
						if writeXmlNewOrRevisedItems(SkuListInclusionType.Not_Included, activeAndNotActiveSkuList, TC, minQuantity, country, Replace(Replace(REQUEST_HEADER, "${version}", API_VERSION),"${request}","AddFixedPriceItemRequest"), Replace(REQUEST_FOOTER,"${request}","AddFixedPriceItemRequest"), "AddFixedPriceItem", XmlAndZipFilesType.toAddItem) then
							result &= "Result for New Items: " & uploadZipFile(accessToken, country, "AddFixedPriceItem") & "-"
						end if
						'revised items
						if writeXmlNewOrRevisedItems(SkuListInclusionType.Included, activeAndNotActiveSkuList, TC, minQuantity, country, Replace(Replace(REQUEST_HEADER, "${version}", API_VERSION),"${request}","ReviseFixedPriceItemRequest"), Replace(REQUEST_FOOTER,"${request}","ReviseFixedPriceItemRequest"), "ReviseFixedPriceItem", XmlAndZipFilesType.toReviseItem) then
							result &= "Result for Revised Items: " & uploadZipFile(accessToken, country, "ReviseFixedPriceItem") & "-"
						else 
							result &= "No Revised Items -"
						end if
						'to end items
						if writeXmlToEndItems(activeSkuList, TC, minQuantity, country, Replace(Replace(REQUEST_HEADER, "${version}", API_VERSION),"${request}","EndFixedPriceItemRequest"), Replace(REQUEST_FOOTER,"${request}","EndFixedPriceItemRequest"), "EndFixedPriceItem") then
							result &= "Result for To End Items: " & uploadZipFile(accessToken, country, "EndFixedPriceItem") & "-"
						else 
							result &= "No To End Items -"
						end if
					Next
				Else
					result = "Secret errato"
				End If
				Dim sqlString As String = "UPDATE ks_ebay_data SET execution_status_export_feeds = '" & Now() & ":" & result & "'"
				sqlString = sqlString & ", force_update = 0"
				conn = getDbConnection()
				ExecuteQuery(conn, sqlString, SqlExecutionType.nonQuery)
                conn.Close()
                conn.Dispose()
				Response.Write(result)
                Response.End()
        End Select
    End Sub
	
	private Function uploadZipFile(ByVal accessToken As String, ByVal country As String, ByVal uploadJobType As String) As String
		Dim root As XmlElement
		Dim result As String = String.Empty
		Dim attempts As Integer = 0
		Dim jobId As String
		Dim fileReferenceId As String
		REM Dim createUploadJobResponse As XmlDocument
		REM while attempts < 12
			try
				REM createUploadJobResponse = ToXmlDocument(ebayUtilities.createUploadJobRequest(accessToken, country, uploadJobType))
				root = ebayUtilities.createUploadJobRequest(accessToken, country, uploadJobType)
				jobId = root.getElementsByTagName("jobId").Item(0).innerText
				fileReferenceId = root.getElementsByTagName("fileReferenceId").Item(0).innerText
				REM Exit while
			catch
				result = "Problems with createUploadJobResponse"
				REM Threading.Thread.Sleep(5000)
				REM attempts += 1
			end try
		REM end while
		REM if attempts = 12 then
			REM result = "Problems with createUploadJobResponse"
		REM else
			REM attempts = 0
			REM root = createUploadJobResponse.DocumentElement
		if result = String.Empty Then
			ebayUtilities.uploadFileRequest(accessToken, country, jobId, fileReferenceId, Server.MapPath(".") & "\ebay\" & uploadJobType & ".zip")
			REM Dim startUploadJobResponse As XmlDocument = ToXmlDocument(ebayUtilities.startUploadJobRequest(accessToken, country, jobId))
			REM root = startUploadJobResponse.DocumentElement
			root = ebayUtilities.startUploadJobRequest(accessToken, country, jobId)
			result = root.getElementsByTagName("ack").Item(0).innerText
			if result = "Success" Then
				result = "Upload TimeOut"
				while attempts < 20
					REM Dim getJobStatusResponse As XmlDocument = ToXmlDocument(ebayUtilities.getJobStatusRequest(accessToken, country, jobId))
					REM root = getJobStatusResponse.DocumentElement
					root = ebayUtilities.getJobStatusRequest(accessToken, country, jobId)
					Dim jobStatus As String = root.getElementsByTagName("jobStatus").Item(0).innerText
					if jobStatus = "Aborted" OrElse jobStatus = "Completed" OrElse jobStatus = "Failed" Then
						result = "Upload " & jobStatus
						Exit while
					End If 
					Threading.Thread.Sleep(15000)
					attempts += 1
				end while
			End If
		end if
		return result
	End Function
	
	private Sub addNotFirstSkuListToContainerSkuList(ByRef skuListContainer AS String, ByVal skuList As String) 
		if skuListContainer <> String.Empty Then
			if skuList <> String.Empty Then
				skuListContainer = skuListContainer & "," & skuList
			End If
		Else
			if skuList <> String.Empty Then
				skuListContainer &= skuList
			End If
		End If
	End Sub
	
	private Function getSkuLists(ByVal accessToken As String, ByVal country As String, ByVal listType As String) as String
		Dim result As String = String.Empty
		Dim conn = getDbConnection()
		REM Dim myEbaySelling As XmlDocument = ToXmlDocument(ebayUtilities.getMyEbaySelling(accessToken, country))
		REM Dim root As XmlElement = myEbaySelling.DocumentElement
		Dim root As XmlElement = ebayUtilities.getMyEbaySelling(accessToken, country)
		Dim list As XmlElement = root.getElementsByTagName(listType).Item(0)
		if list isNot Nothing then
			Dim itemNodes As XmlNodeList = list.Item("ItemArray").ChildNodes
			result & = "'"
			For Each itemNode As XmlNode In itemNodes
				result &= itemNode.Item("SKU").InnerText
				result & = "','"
			Next
			if result <> "'" Then
				result = result.Substring(0,result.length-2)
			end if
		End If
		conn.Close()
		conn.Dispose()
		return result
	End Function
	
	REM private Function ToXmlDocument(ByVal doc As XElement) As XmlDocument
        REM Dim xmlDocument = new XmlDocument()
        REM using xmlReader = doc.CreateReader()
			REM xmlDocument.Load(xmlReader)
        REM end using 
		REM return xmlDocument
    REM End Function
	
	private Function writeXmlAndZipFiles(ByVal conn As MySqlConnection, ByVal query As String, ByVal skuList As String, ByVal TC as Integer, ByVal minQuantity as Integer, ByVal country As String, ByVal header As String, ByVal footer As String, ByVal fileName As String, ByVal fileType As XmlAndZipFilesType) As Boolean
		Dim dr As MySqlDataReader = getDataReader(conn, query)
		Dim writeFile As Boolean = dr.HasRows
		if writeFile Then
			Dim fileXml As String = "ebay\" & fileName & ".xml"
			Dim fileZip As String = "ebay\" & fileName & ".zip"
			deleteFile(fileXml)
			deleteFile(fileZip)
			writeInFile(fileXml, Replace(Replace(BULK_HEADER,"${version}",API_VERSION),"${site_id}",ebayUtilities.getSiteCode(country)))
			While dr.Read()
				if fileType = XmlAndZipFilesType.toEndItem Then
					writeInFile(fileXml, getXmlForToEndItem(dr, TC, minQuantity, header, footer) & Environment.NewLine)
				else
					writeInFile(fileXml, getXmlNewOrRevisedItem(dr, TC, minQuantity, country, header, footer) & Environment.NewLine)
				End If
			End While
			writeInFile(fileXml, BULK_FOOTER)
			writeZipFile(fileXml, fileZip)
		End If
		dr.Close()
		return writeFile
	End Function
	
	private Function writeXmlToEndItems(ByVal skuList As String, ByVal TC as Integer, ByVal minQuantity as Integer, ByVal country As String, ByVal header As String, ByVal footer As String, ByVal fileName As String ) As Boolean
		Dim query As String = getQueryForToEndItems(skuList, TC, minQuantity)  
		Dim conn = getDbConnection()
		Dim result As String = writeXmlAndZipFiles(conn, query, skuList, TC, minQuantity, country, header, footer, fileName, XmlAndZipFilesType.toEndItem)
		conn.Close()
		conn.Dispose()
		return result
	End Function
	
	private Function writeXmlNewOrRevisedItems(ByVal skuListInclusionType As SkuListInclusionType, ByVal skuList As String, ByVal TC as Integer, ByVal minQuantity as Integer, ByVal country As String, ByVal header As String, ByVal footer As String, ByVal fileName As String, ByVal fileType As XmlAndZipFilesType) As Boolean
		Dim query As String = getQueryForNewOrReviseItems(skuListInclusionType, skuList, TC, minQuantity)  
		Dim conn = getDbConnection()
		Dim result As String =  writeXmlAndZipFiles(conn, query, skuList, TC, minQuantity, country, header, footer, fileName, fileType)
		conn.Close()
		conn.Dispose()
		return result
	End Function
	
	private Function getQueryForNewOrReviseItems(ByVal skuListInclusionType As  SkuListInclusionType, ByVal skuList As String, ByVal TC as Integer, ByVal minQuantity as Integer) As String
		Dim query As String = String.Empty
		Dim skuListInclusionTypeWhereString As String = String.Empty
		If skuList = String.Empty Then
			If skuListInclusionType = SkuListInclusionType.Included Then
				skuListInclusionTypeWhereString = " and 1=0"
			End If
		Else
			If skuListInclusionType = SkuListInclusionType.Included Then
				skuListInclusionTypeWhereString = " and ks_ebay_products.sku IN (" & skuList & ")"
			Else 
				skuListInclusionTypeWhereString = " and ks_ebay_products.sku NOT IN (" & skuList & ")"
			End If
		End If
		query = getQueryForNewOrReviseItemsWithoutEndPart(TC, minQuantity) & skuListInclusionTypeWhereString & ";"
		return query
	End Function
	
	private Function getQueryForNewOrReviseItemsWithoutEndPart(ByVal TC as Integer, ByVal minQuantity as Integer) As String
		Dim query As String
		Dim queryQuantitySelect As String = String.Empty
		Dim queryQuantityJoin As String = String.Empty
		Dim queryQuantityWhere As String = String.Empty
		Dim whereParent As String = String.Empty
		If TC = 0 Then
			queryQuantitySelect = ", articoli_giacenze.Giacenza as quantity"
			queryQuantityJoin = "LEFT JOIN articoli_giacenze ON ks_ebay_products.product_id = articoli_giacenze.ArticoliId AND articoli_giacenze.TCid = -1 "
			queryQuantityWhere = " and articoli_giacenze.Giacenza >= " & minQuantity
		Else
			whereParent = " and ks_ebay_products.parent_child = 'P'"
		End If
		query = "select ks_ebay_products.*" & queryQuantitySelect & " from ks_ebay_data, ks_ebay_products "
		query &= queryQuantityJoin
		query &= "LEFT JOIN articoli ON ks_ebay_products.product_id = articoli.id "
		query &= "WHERE articoli.Abilitato = 1 and ks_ebay_products.enabled = 1 " & queryQuantityWhere & whereParent
		return query
	End Function
	
	private Function getXmlNewOrRevisedItem(ByVal dr As MySqlDataReader, ByVal TC as Integer, ByVal minQuantity as Integer, ByVal country as String, ByVal header as String , ByVal footer as String) As String
		Dim resultXml As String = header
		resultXml &= ITEM
		resultXml &= footer
		Dim xmlFields As Array
		Dim xmlField As String
		xmlFields = System.Enum.GetNames(GetType(GlobalXmlFields))
		For Each xmlField In xmlFields
			resultXml = Replace(resultXml, "${" + xmlField + "}", dr.Item(xmlField))
		Next
		resultXml = Replace(resultXml, "${country}", country)
		Dim tempPicture as String = String.Empty
		Dim tempQuantity as String = String.Empty
		Dim tempEan as String = String.Empty
		Dim tempSku as String = Replace(SKU, "${sku}", dr.Item("sku"))
		Dim tempStartPrice As String = String.Empty
		Dim tempVariations as String = String.Empty
		If TC = 0 Then
			tempQuantity = Replace(QUANTITY, "${quantity}", dr.Item("quantity"))
			tempEan = Replace(EAN, "${ean}", dr.Item("ean"))
			For i = 1 To 6
				tempPicture += Replace(PICTURE_URL, "${picture_url}", dr.Item("picture_url" & i))
			Next i
			tempStartPrice = Replace(START_PRICE,"${start_price}",getStartPrice(dr.Item("date_offer_begin"),dr.Item("date_offer_end"),dr.Item("offer_price"),dr.Item("price")))
		Else
			Dim tempVariationSet as String = String.Empty
			Dim colors As ArrayList = New ArrayList()
			Dim sizes As ArrayList = New ArrayList()
			Dim variationPictures as New Dictionary(of String, ArrayList)
			Dim query As String = "select ks_ebay_products.*, articoli_giacenze.Giacenza as quantity from ks_ebay_products "
			query &= "LEFT JOIN articoli_giacenze ON ks_ebay_products.tc_id = articoli_giacenze.TcId "
			query &= "LEFT JOIN articoli ON ks_ebay_products.product_id = articoli.id "
			query &= "WHERE articoli.Abilitato = 1 and ks_ebay_products.enabled = 1 and articoli_giacenze.Giacenza >= " & minQuantity & " and ks_ebay_products.parent_child = 'C' and ks_ebay_products.parent_sku = '" & dr.Item("sku") & "';"
			Dim connChildren = getDbConnection()
			Dim drChildren As MySqlDataReader = getDataReader(connChildren, query)
			While drChildren.Read()
				Dim tempVariation as String = VARIATION
				xmlFields = System.Enum.GetNames(GetType(VariationXmlFields))
				For Each xmlField In xmlFields
					tempVariation = Replace(tempVariation, "${" + xmlField + "}", drChildren.Item(xmlField))
				Next
				if not colors.Contains(drChildren.Item("color")) Then
					colors.add(drChildren.Item("color"))
				End If
				if not sizes.Contains(drChildren.Item("size")) Then
					sizes.add(drChildren.Item("size"))
				End If
				if not variationPictures.ContainsKey(drChildren.Item("color")) Then
					Dim variationPictureUrl As ArrayList = New ArrayList()
					variationPictureUrl.Add(drChildren.Item("picture_url1"))
					variationPictures.Add(drChildren.Item("color"), variationPictureUrl)
				else
					variationPictures.item(drChildren.Item("color")).Add(drChildren.Item("picture_url1"))
				End If
				tempVariation = Replace(tempVariation, "${start_price}", getStartPrice(drChildren.Item("date_offer_begin"),drChildren.Item("date_offer_end"),drChildren.Item("offer_price"),drChildren.Item("price")))
				tempVariationSet &= tempVariation
			End While
			drChildren.Close()
			connChildren.Close()
			connChildren.Dispose()
			tempVariations = Replace(VARIATIONS, "${variations}", tempVariationSet)
			Dim colorValues as String = String.Empty
			For Each color In colors
				colorValues &= Replace(VALUE, "${value}", color)
			Next
			tempVariations = Replace(tempVariations, "${colors}", colorValues)
			Dim sizeValues as String = String.Empty
			For Each size In sizes
				sizeValues &= Replace(VALUE, "${value}", size)
			Next
			tempVariations = Replace(tempVariations, "${sizes}", sizeValues)
			Dim variationColorsAndPicturesUrls as String = String.Empty
			For Each pairInVariationPictures In variationPictures
				Dim variationPicturesUrls as String = String.Empty
				For Each variationPictureUrls In pairInVariationPictures.value
					variationPicturesUrls += Replace(PICTURE_URL, "${picture_url}", variationPictureUrls)
				Next
				variationColorsAndPicturesUrls &= Replace(VARIATIONS_PICTURES, "${variation_specific_value}", pairInVariationPictures.key)
				variationColorsAndPicturesUrls = Replace(variationColorsAndPicturesUrls, "${picture_url}", variationPicturesUrls)
			Next
			tempVariations = Replace(tempVariations, "${pictures}", variationColorsAndPicturesUrls)
		End If
		resultXml = Replace(resultXml, "${quantity}", tempQuantity)
		resultXml = Replace(resultXml, "${ean}", tempEan)
		resultXml = Replace(resultXml, "${sku}", tempSku)
		resultXml = Replace(resultXml, "${pictures}", tempPicture)
		resultXml = Replace(resultXml, "${start_price}", tempStartPrice)
		resultXml = Replace(resultXml, "${variations}", tempVariations)
		resultXml.Replace(Chr(10),"").Replace(Chr(13),"")
		return resultXml
	End Function
	
	private Function getQueryForToEndItems(ByVal skuList As String, ByVal TC as Integer, ByVal minQuantity as Integer) As String
		Dim whereParent As String = String.Empty
		Dim whereInSkuList As String = String.Empty
		If TC = 1 Then
			whereParent = " and ks_ebay_products.parent_child = 'P'"
		End If
		If skuList = String.Empty Then
			whereInSkuList = " and 1=0"
		else
			whereInSkuList = " and ks_ebay_products.sku IN (" & skuList & ")"
		End If
		Dim query As String
		query = "select ks_ebay_products.*, articoli_giacenze.Giacenza as quantity from ks_ebay_data, ks_ebay_products "
		query &= "LEFT JOIN articoli_giacenze ON ks_ebay_products.product_id = articoli_giacenze.ArticoliId AND articoli_giacenze.TCid = -1 "
		query &= "LEFT JOIN articoli ON ks_ebay_products.product_id = articoli.id "
		query &= "WHERE ((articoli.Abilitato = 1 and ks_ebay_products.enabled = 1 and articoli_giacenze.Giacenza < " & minQuantity & ") OR articoli.Abilitato = 0 OR ks_ebay_products.enabled = 0)" & whereParent & whereInSkuList & ";"
		return query
	End Function
	
	private Function getXmlForToEndItem(ByVal dr As MySqlDataReader, ByVal TC as Integer, ByVal minQuantity as Integer, ByVal header as String , ByVal footer as String) As String
		Dim resultXml As String = header
		resultXml &= END_ITEM
		resultXml &= footer
		resultXml = Replace(resultXml, "${sku}", dr.Item("sku"))
		return resultXml
	End Function
	
	private Function getStartPrice(ByVal dateOfferBegin As String, ByVal dateOfferEnd As String, ByVal offerPrice As String, ByVal price As String) As String
		Dim startPrice As String = String.Empty
		Dim now As DateTime = DateTime.Now
		Dim resultBegin As Integer = DateTime.Compare(now, dateOfferBegin)
		Dim resultEnd As Integer = DateTime.Compare(now, dateOfferEnd)
		If resultBegin >= 0 AndAlso resultEnd <= 0 Then
			startPrice = offerPrice
		Else
			startPrice = price
		End If
		return startPrice
	End Function
	
	private Sub writeInFile(ByVal path As String, ByVal content As String)
		path = Server.MapPath(".") & "\" & path
		If Not File.Exists(path) Then
            ' Create a file to write to.
            Using sw As StreamWriter = File.CreateText(path)
                sw.WriteLine(content)
			End Using
		Else
			' This text is always added, making the file longer over time
			' if it is not deleted.
			Using sw As StreamWriter = File.AppendText(path)
				sw.WriteLine(content)
			End Using	
		End If
	End Sub
	
	private Sub deleteFile(ByVal path As String)
		If File.Exists(Server.MapPath(".") & "\" & path) Then
			My.Computer.FileSystem.DeleteFile(Server.MapPath(".") & "\" & path)
		End If
	End Sub
	
	private Sub writeZipFile(ByVal content As String, ByVal path As String)
		Using zip As ZipFile = new ZipFile()
			zip.AddFile(Server.MapPath(".") & "\" & content,"")
			zip.Save(Server.MapPath(".") & "\" & path)
		End Using
	End Sub
End Class
