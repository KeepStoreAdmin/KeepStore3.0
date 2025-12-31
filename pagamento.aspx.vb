zzImports MySql.Data.MySqlClient
Imports System.Data

Partial Class pagamento
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand

        'Controllo se l'utente è loggato o meno, se non è loggato lo indirizzo alla registrazione
        If Session("LoginID") <= 0 Then
            Response.Redirect("accessonegato.aspx")
        End If
        '----------------------------------------------------------------------------------------

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        cmd.Connection = conn

        conn.Open()

            'If (Not Request.Form("custom") Is Nothing) AndAlso (Request.Form("custom").Contains("COUPON_")) Then
            '    Dim temp As String() = Request.Form("custom").Split("_")
            '    Dim idCoupon As Integer = temp(1)
            '    Dim numero_opzione As Integer = temp(2)
            '    Dim cod_controllo As String = temp(3)
            '    Dim idTransazione As String = ""
		if Request.QueryString("cod_controllo") <> "" Then
				Dim cod_controllo As String = Request.QueryString("cod_controllo")
				Dim idTransazione As String
				
				If Request.Form("txn_id") <> "" Then
					idTransazione = Request.Form("txn_id")
					Session("IdPagamentoCoupon") = 19
                Else If Request.Form("thx_id") = "" Then
					idTransazione = Request.Form("thx_id")
					Session("IdPagamentoCoupon") = 10
                End If

				if idTransazione = ""
                    idTransazione = Guid.NewGuid.ToString.Replace("-", "")
					if Request.QueryString("bancasella") = "true" then
						Session("IdPagamentoCoupon") = 46
					else
						Session("IdPagamentoCoupon") = 19
					end if
				End If

            cmd.CommandText = "UPDATE coupon_tabella_temporanea SET StatoPagamento=1, idTransazione=?idTransazione WHERE cod_controllo=?cod_controllo"
            cmd.Parameters.AddWithValue("?idTransazione", idTransazione)
            cmd.Parameters.AddWithValue("?Email", cod_controllo)
            cmd.ExecuteNonQuery()

                cmd.Dispose()

                conn.Close()
                conn.Dispose()

                Session("Coupon_Codice_Controllo") = cod_controllo
                Session("Coupon_NumeroOpzione") = "0"

                'Mi reco alla pagina ordine coupon, dove confermo l'esito del pagamento
                Response.Redirect("ordine_coupon.aspx?cod=" & cod_controllo)
            End If

        'Sezione IWBank, per gestire il codice di ritorno tramite POST
        If Request.Form("thx_id") <> "" Then
            cmd.CommandText = "update documenti set pagato=1, idtransazione=?idTransazione where id=?id AND UtentiIdt=?UtentiId"
            cmd.Parameters.AddWithValue("?idTransazione", Request.Form("thx_id"))
            cmd.Parameters.AddWithValue("?id", Request.QueryString("id"))
            cmd.Parameters.AddWithValue("?UtentiId", Session("UtentiId"))
        End If

        'Sezione Paypal, per gestire il codice di ritorno tramite POST
        If Request.Form("txn_id") <> "" Then
            cmd.CommandText = "update documenti set pagato=1, idtransazione=?idTransazione where id=id=?id AND UtentiIdt=?UtentiId"
            cmd.Parameters.AddWithValue("?idTransazione", Request.Form("thx_id"))
            cmd.Parameters.AddWithValue("?id", Request.QueryString("id"))
            cmd.Parameters.AddWithValue("?UtentiId", Session("UtentiId"))
            cmd.ExecuteNonQuery()
        End If

        If Request.QueryString("tx") <> "" Then
            If Request.QueryString("st") = "Pending" Then 'Pending è un pagamento in fase di verifica e noi gli impostiamo 2 nel database
                cmd.CommandText = "update documenti set pagato=2, idtransazione=?idTransazione where id=?id"
                cmd.Parameters.AddWithValue("?idTransazione", Request.Form("tx"))
                cmd.Parameters.AddWithValue("?id", Request.QueryString("id"))
                cmd.ExecuteNonQuery()
            Else
                cmd.CommandText = "update documenti set pagato=1, idtransazione=?idTransazione where id=?id"
                cmd.Parameters.AddWithValue("?idTransazione", Request.Form("tx"))
                cmd.Parameters.AddWithValue("?id", Request.QueryString("id"))
                cmd.ExecuteNonQuery()
            End If
        End If

        cmd.Dispose()

        conn.Close()
        conn.Dispose()


        Response.Redirect("documentidettaglio.aspx?id=" & Request.QueryString("id"))

    End Sub

End Class
