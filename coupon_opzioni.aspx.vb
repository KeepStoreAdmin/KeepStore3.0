Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Net
Imports System.Security.Authentication
	
Partial Class coupon_opzioni
    Inherits System.Web.UI.Page
	
	Const _Tls12 As SslProtocols = DirectCast(&HC00, SslProtocols)
	Const Tls12 As SecurityProtocolType = DirectCast(_Tls12, SecurityProtocolType)

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        SqlData_CouponInserzioni.SelectCommand = "SELECT * FROM coupon_inserzione WHERE idCoupon=@idCoupon"
        SqlData_CouponInserzioni.SelectParameters.Clear()
        SqlData_CouponInserzioni.SelectParameters.Add("@idCoupon", Request.QueryString("id"))
    End Sub

	Protected Sub acquista(ByVal sender As Object, ByVal db As String)
	    'Controllo se l'utente è loggato o meno, se non è loggato lo indirizzo alla registrazione
        If Session("LoginID") <= 0 Then
            Response.Redirect("registrazione.aspx?state=coupon&redirect=" & Request.Url.AbsoluteUri)
        End If
        '----------------------------------------------------------------------------------------

        'Genero il codice di controllo
        Dim cod_controllo As String = Guid.NewGuid.ToString

        Dim temp As ImageButton = sender
        Dim dd_temp As DropDownList = temp.Parent.FindControl(db)

        Dim quantita_coupon As Integer = Val(dd_temp.SelectedItem.Text)
        Dim quantita_pezzi As Integer = temp.Attributes("qnt") * Val(dd_temp.SelectedItem.Text)
        Dim totale As Double = temp.Attributes("prz")
        Dim descrizione As String = temp.Attributes("title")

        'Inserisco il coupon nella tabella temporanea dei coupon
        inserisci_in_tabella_coupon_temporanea(Request.QueryString("id"), descrizione, Session("UtentiId"), totale * quantita_coupon, quantita_coupon, quantita_pezzi, Session("AziendaID"), cod_controllo)
        'Reindirizzo l'output su iwbank
        'Response.Redirect("https://checkout.iwsmile.it/Pagamenti/?ACCOUNT=" & Me.Session("AccountIwBank") & "&ITEM_NAME=" & Val(dd_temp.SelectedItem.Text) & " x Coupon+-+" & System.Web.HttpUtility.HtmlDecode(temp.Attributes("title")) & "+del+" & Date.Now & "&ITEM_NUMBER=" & Session("Acquista_idCoupon") & "&QUANTITY=" & Val(dd_temp.SelectedItem.Text) & "&FLAG_ONLY_IWS=0&AMOUNT=" & Replace(Replace(totale, ".", ""), ",", ".") & "&CUSTOM=COUPON_" & Request.QueryString("id") & "_0_" & cod_controllo & "&NOTE=0&URL_OK=http://" & Request.Url.Host & "/pagamento.aspx" & "&URL_BAD=" & Request.Url.AbsoluteUri)
		ServicePointManager.SecurityProtocol = Tls12
		
        Dim tipo_di_pagamento As String = "PagamentoBancaSella"
		'Dim tipo_di_pagamento As String = ottieni_tipo_di_pagamento()
		If tipo_di_pagamento = "PagamentoBancaSella" Then
            'Dim btBancaSella As ImageButton = Me.FormView1.FindControl("btBancaSella")
            Dim currency As String = "242"
            Dim amount As String = HttpUtility.UrlEncode(totale * quantita_coupon)
            Dim shopTransactionId As String = HttpUtility.UrlEncode(cod_controllo)
            Dim idDocumento As String = HttpUtility.UrlEncode("coupon" + "-" + Request.QueryString("id"))
            Dim sitoWeb As String = HttpUtility.UrlEncode(Me.Session("AziendaUrl"))
            Dim buyerName As String = HttpUtility.UrlEncode(Me.Session("LoginNomeCognome"))
            Dim buyerEmail As String = HttpUtility.UrlEncode(Me.Session("LoginEmail"))
            Response.Redirect("/bancasella.aspx?currency=" & currency & "&amount=" & amount & "&shopTransactionId=" & cod_controllo & "&iddocumento=" & idDocumento & "&sitoweb=" & sitoWeb & "&buyername=" & buyerName & "&buyeremail=" & buyerEmail)
        ElseIf tipo_di_pagamento = "PagamentoPayPal" Then
            'Dim btPayPal As Button = Me.FormView1.FindControl("btPayPal")
            Dim accountPaypal As String = HttpUtility.UrlEncode(Me.Session("AccountPaypal"))
            'Dim nDocumento As String = HttpUtility.UrlEncode(Request.QueryString("id"))
            Dim dataDocumento As String = HttpUtility.UrlEncode(Date.Now.Year)
            Dim itemName As String = Replace(descrizione," ", "+")
            Dim totaleDocumento As String = HttpUtility.UrlEncode(totale * quantita_coupon)
            Dim idDocumento As String = Request.QueryString("id")
            Dim returnLink As String = HttpUtility.UrlEncode("http://" & Request.Url.Host & "/pagamento.aspx?cod_controllo=" & cod_controllo)
            Dim cancelReturnLink As String = HttpUtility.UrlEncode("http://" & Request.Url.Host & "/coupon_opzioni.aspx?id=" & idDocumento)
            Dim notifyUrl As String = HttpUtility.UrlEncode("http://" & Request.Url.Host & "/ipn.aspx?id=" & idDocumento)
            Response.Redirect("https://www.paypal.com/it/cgi-bin/webscr/?cmd=_xclick&business=" & accountPaypal & "&item_name=" & itemName & "&currency_code=EUR&amount=" & totaleDocumento & "&item_number=" & cod_controllo & "&quantity=1&return=" & returnLink & "&cancel_return=" & cancelReturnLink & "&notify_url=" & notifyUrl)
        End If
	End Sub

    Protected Sub img_standard_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
		acquista(sender,"DB_Quantità_standard")
	End Sub

    Protected Sub img_opzione1_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        acquista(sender,"DB_Quantità_opzione1")
    End Sub

    Protected Sub img_opzione2_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        acquista(sender,"DB_Quantità_opzione2")
	End Sub

    Protected Sub img_opzione3_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        acquista(sender,"DB_Quantità_opzione3")
	End Sub

    Protected Sub Coupon_Opzioni_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Coupon_Opzioni.PreRender
        Dim temp As DataList = sender

        Dim Acquista_standard As ImageButton = temp.Items(0).FindControl("img_standard")
        Dim Acquista_opzione1 As ImageButton = temp.Items(0).FindControl("img_opzione1")
        Dim Acquista_opzione2 As ImageButton = temp.Items(0).FindControl("img_opzione2")
        Dim Acquista_opzione3 As ImageButton = temp.Items(0).FindControl("img_opzione3")

        Dim DD_Quantita_Standard As DropDownList = temp.Items(0).FindControl("DB_Quantità_standard")
        Dim DD_Quantita_Opzione1 As DropDownList = temp.Items(0).FindControl("DB_Quantità_opzione1")
        Dim DD_Quantita_Opzione2 As DropDownList = temp.Items(0).FindControl("DB_Quantità_opzione2")
        Dim DD_Quantita_Opzione3 As DropDownList = temp.Items(0).FindControl("DB_Quantità_opzione3")

        Dim i As Integer
        'Costruisco il DropDown del coupon Standard
        For i = Acquista_standard.Attributes("qnt_min") To Acquista_standard.Attributes("qnt_max")
            DD_Quantita_Standard.Items.Add(i)
        Next
        'Costruisco il DropDown del coupon Opzione1
        For i = Acquista_opzione1.Attributes("qnt_min") To Acquista_opzione1.Attributes("qnt_max")
            DD_Quantita_Opzione1.Items.Add(i)
        Next
        'Costruisco il DropDown del coupon Opazione2
        For i = Acquista_opzione2.Attributes("qnt_min") To Acquista_opzione2.Attributes("qnt_max")
            DD_Quantita_Opzione2.Items.Add(i)
        Next
        'Costruisco il DropDown del coupon Opzione3
        For i = Acquista_opzione3.Attributes("qnt_min") To Acquista_opzione3.Attributes("qnt_max")
            DD_Quantita_Opzione3.Items.Add(i)
        Next

    End Sub
	
	Protected Function ottieni_tipo_di_pagamento() As String
        Dim params As New Dictionary(Of String, String)
        params.add("@AziendeId", Session("AziendaID"))
        Dim dr = ExecuteQueryGetDataReader("id", "pagamentitipo", "where AziendeId = @AziendeId And Abilitato = 1 And Coupon = 1", params)
        Dim idTipoPagamento As String = dr(0)("id")
        Dim tipoPagamento As String = ""
		if idTipoPagamento = "19" Then
			tipoPagamento = "PagamentoPayPal"
		Else if idTipoPagamento = "46" Then
			tipoPagamento = "PagamentoBancaSella"
		End If
		Return tipoPagamento
	End Function
	
    Protected Sub inserisci_in_tabella_coupon_temporanea(ByVal idCoupon As Integer, ByVal Descrizione As String, ByVal idUtente As Integer, ByVal prezzo As Double, ByVal qnt_coupon As Integer, ByVal qnt_pezzi As Integer, ByVal AziendaId As Integer, ByVal cod_controllo As String)
        'Inserisco l'ordine nella tabella temporanea
        Dim params As New Dictionary(Of String, String)
        params.add("@idCoupon", idCoupon)
        params.add("@Descrizione", Descrizione)
        params.add("@idUtente", idUtente)
        params.add("@prezzo", prezzo.ToString.Replace(",", "."))
        params.add("@qnt_coupon", qnt_coupon)
        params.add("@qnt_pezzi", qnt_pezzi)
        params.add("@AziendaId", AziendaId)
        params.add("@cod_controllo", cod_controllo)
        ExecuteInsert("coupon_tabella_temporanea", "idCoupon,Descrizione,idUtente,prezzo,qnt_coupon,qnt_pezzi,AziendaId,cod_controllo", "@idCoupon,@Descrizione,@idUtente,@prezzo,@qnt_coupon,@qnt_pezzi,@AziendaId,@cod_controllo", params)
        '-----------------------------------------------------------------------------------------------------------
    End Sub

    Protected Function ExecuteInsert(ByVal table As String, ByVal fields As String, Optional ByVal values As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & values & ")"
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteDelete(ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "DELETE FROM " & table & " " & wherePart
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd As New MySqlCommand
                cmd.Connection = conn
                cmd.CommandText = sqlString
                For Each paramName In params.Keys
                    If paramName = "?parPrezzo" Or paramName = "?parPrezzoIvato" Then
                        cmd.Parameters.Add(paramName, MySqlDbType.Double).Value = Convert.ToDecimal(params(paramName), System.Globalization.CultureInfo.InvariantCulture)
                    Else
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    End If
                Next
                If isStoredProcedure Then
                    cmd.CommandType = CommandType.StoredProcedure
                    cmd.Parameters.AddWithValue("?parRetVal", "0")
                    cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
                Else
                    cmd.CommandType = CommandType.Text
                End If
                cmd.ExecuteNonQuery()
                cmd.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
    End Function

    Protected Function ExecuteQueryGetDataReader(ByVal fields As String, ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As List(Of Dictionary(Of String, Object))
        Dim sqlString As String = "SELECT " & fields & " FROM " & table & " " & wherePart
        Dim dr As MySqlDataReader
        Dim result As New List(Of Dictionary(Of String, Object))
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd = New MySqlCommand With {
                    .Connection = conn,
                    .CommandType = CommandType.Text,
                    .CommandText = sqlString
                }
                If Not params Is Nothing Then
                    Dim paramName As String
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If
                dr = cmd.ExecuteReader()

                While dr.Read()
                    Dim row As New Dictionary(Of String, Object)()

                    ' Per ogni colonna nella riga, aggiungi la colonna al dizionario
                    For i As Integer = 0 To dr.FieldCount - 1
                        ' Prendi il nome della colonna e il valore
                        Dim columnName As String = dr.GetName(i)
                        Dim value As Object = dr.GetValue(i)

                        ' Aggiungi la colonna e il valore al dizionario
                        row.Add(columnName, value)
                    Next

                    ' Aggiungi la riga al risultato
                    result.Add(row)
                End While

                dr.Close()
                dr.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
        Return result
    End Function

End Class
