Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.IO

Partial Class export_amazon
    Inherits System.Web.UI.Page

    Enum DrItemType
        stringType
        intType
    End Enum

    Function getDataReader(ByVal conn As MySqlConnection, ByVal query As String) As MySqlDataReader
        Return getDataReader(conn, query, 0)
    End Function

    Function getDataReader(ByVal conn As MySqlConnection, ByVal query As String, ByVal timeout As Integer) As MySqlDataReader
        Dim cmd As New MySqlCommand
        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        If timeout > 0 Then
            cmd.CommandTimeout = timeout
        End If
        cmd.CommandText = query
        Return cmd.ExecuteReader()
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        Response.ContentType = "application/txt"
        Response.AddHeader("content-disposition", "attachment; filename=amazon.txt")

        Dim conn = New MySqlConnection()
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()
        Dim dr As MySqlDataReader

        Dim Phase As Integer = Request.QueryString("Phase")
        If Phase = 1 Then
            dr = getDataReader(conn, "select * from export_amazon")
            dr.Read()
            Dim response As String = dr.Item("enabled").ToString + "|" + dr.Item("update").ToString + "|" + dr.Item("partialupdates").ToString + "|" + dr.Item("force_partialupdate").ToString + "|" + dr.Item("force_update").ToString
            dr.Close()
            conn.Close()
            conn.Dispose()
			Response.Write(risposta)
            Response.End()
        End If

		if Phase = 3 Then
			Dim action As String = Request.QueryString("action")
			Dim executionStatus As String = Request.QueryString("executionStatus")
            Dim sqlString As String = "UPDATE export_amazon SET execution_status = '" & Now() & ":" & executionStatus & "'"
            If azione = "update" Then
                    sqlString = sqlString & ", force_update = 0"
				Else
                    sqlString = sqlString & ", force_partialupdate = 0"
            End If
            Dim cmd = New MySqlCommand()
            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.CommandText = sqlString
            cmd.ExecuteNonQuery()
            cmd.Dispose()
            conn.Close()
            conn.Dispose()
            Response.Write("True")
			Response.End()
        End If

		Dim formatString As String = Request.QueryString("formatString")
		Dim header As String = Request.QueryString("header")
		Response.Write(header & Environment.NewLine)
		Dim requestedData() As String = formatString.Split("|"c)
		Dim minQuantity As Integer
		dr = getDataReader(conn, "select min_quantity from export_amazon")
		dr.Read()
		minQuantity = dr.Item("min_quantity")
		dr.Close()
		Dim TC As Integer
		dr = getDataReader(conn, "select TC from aziende")
		dr.Read()
		TC = dr.Item("TC")
		dr.Close()
		Dim queryQuantity As String
		if TC = 0 Then
			queryQuantity = "products_amazon.product_id = articoli_giacenze.ArticoliId"
		Else
			queryQuantity = "products_amazon.tc_id = articoli_giacenze.TCid"
		End If
		dr = getDataReader(conn, "select products_amazon.*, articoli_giacenze.Giacenza as quantity, articoli.Abilitato as enabled from products_amazon LEFT JOIN articoli_giacenze ON " & queryQuantity & " LEFT JOIN articoli ON products_amazon.product_id = articoli.id;", 300)
		Dim resultString As String
        While dr.Read()
			resultString = ""
			If dr.Item("quantity") >= minQuantity AndAlso dr.Item("enabled") = 1 Then
				For Each data As String In requestedData()
					Select data
						Case ""
							resultString &= vbTab
						Case "x"
							resultString &= dr.Item(data)
						Case Else
							resultString &= data
					End Select
				Next
			End If
            Response.Write(resultString & Environment.NewLine)
        End While
		dr.Close()
        conn.Close()
        conn.Dispose()
		Response.End()
    End Sub
	
End Class
