Imports MySql.Data.MySqlClient

Partial Class ordine_coupon
    Inherits System.Web.UI.Page

        Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        ' Controllo se l'utente è loggato o meno, se non è loggato lo indirizzo alla registrazione
        If Session("LoginID") Is Nothing OrElse Convert.ToInt32(Session("LoginID")) <= 0 Then
            Response.Redirect("accessonegato.aspx", False)
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        Dim cod As String = Convert.ToString(Request.QueryString("cod"))
        If String.IsNullOrEmpty(cod) Then
            pnlMsg.Visible = True
            litMsg.Text = "Codice di controllo mancante."
            Return
        End If

        ' Controllo il pagamento del Coupon: se è andato a buon fine effettuo l'ordine
        Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(cs)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandText = "SELECT coupon_inserzione.`idArticolo`, coupon_inserzione.`VettoreId`, coupon_inserzione.Iva_Coupon, iva.`Valore` AS ValoreIva_Coupon, coupon_tabella_temporanea.idCoupon, coupon_tabella_temporanea.Descrizione, coupon_tabella_temporanea.`cod_controllo`,coupon_tabella_temporanea.`StatoPagamento`,coupon_tabella_temporanea.`idTransazione`,articoli.`Codice`,articoli.`Descrizione1` AS Titolo, coupon_tabella_temporanea.`idCoupon`, coupon_tabella_temporanea.`prezzo`, coupon_tabella_temporanea.`qnt_coupon`, coupon_tabella_temporanea.`qnt_pezzi` FROM coupon_inserzione JOIN coupon_partners ON coupon_inserzione.idPartner=coupon_partners.idPartner JOIN coupon_tabella_temporanea ON coupon_inserzione.idCoupon=coupon_tabella_temporanea.idCoupon JOIN articoli ON coupon_inserzione.idArticolo=articoli.id JOIN iva ON Iva_Coupon=iva.`id` WHERE cod_controllo=?cod"
                cmd.Parameters.AddWithValue("?cod", cod)

                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    If Not dr.Read() Then
                        pnlMsg.Visible = True
                        litMsg.Text = "Codice non valido o non trovato."
                        Return
                    End If

                    Dim stato As Integer = 0
                    Try
                        stato = Convert.ToInt32(dr.Item("StatoPagamento"))
                    Catch
                        stato = 0
                    End Try

                    If stato <> 1 Then
                        pnlMsg.Visible = True
                        litMsg.Text = "Pagamento non confermato. Se hai appena pagato, attendi e riprova tra qualche secondo."
                        Return
                    End If

                    Session("Coupon_idCoupon") = dr.Item("idCoupon")
                    Session("Coupon_idArticolo") = dr.Item("IdArticolo")
                    Session("Coupon_DescrizioneCoupon") = dr.Item("Descrizione")
                    Session("Coupon_codArticolo") = dr.Item("Codice")
                    Session("Coupon_DescrizioneArticolo") = dr.Item("Titolo")
                    Session("Coupon_Qnt_Coupon") = dr.Item("qnt_coupon")
                    Session("Coupon_Qnt_Pezzi") = dr.Item("qnt_pezzi")

                    Dim valoreIva As Decimal = Convert.ToDecimal(dr.Item("ValoreIva_Coupon"))
                    Dim prezzo As Decimal = Convert.ToDecimal(dr.Item("prezzo"))
                    Dim qntPezzi As Decimal = Convert.ToDecimal(dr.Item("qnt_pezzi"))

                    Session("Coupon_Prezzo") = Math.Round((prezzo / ((valoreIva / 100D) + 1D)) / qntPezzi, 3)
                    Session("Coupon_PrezzoIvato") = Math.Round(prezzo / qntPezzi, 3)
                    Session("Coupon_Arrotondamento") = 0

                    ' Controllo se aggiungere valore arrotondamento
                    If ((Convert.ToDecimal(Session("Coupon_Prezzo")) * ((valoreIva / 100D) + 1D)) * qntPezzi) <> (Convert.ToDecimal(Session("Coupon_PrezzoIvato")) * qntPezzi) Then
                        Session("Coupon_Arrotondamento") = Math.Round((Convert.ToDecimal(Session("Coupon_PrezzoIvato")) * qntPezzi) - ((Convert.ToDecimal(Session("Coupon_Prezzo")) * ((valoreIva / 100D) + 1D)) * qntPezzi), 2)
                    End If

                    Session("Coupon_StatoPagamento") = stato
                    Session("Coupon_idTransazione") = dr.Item("idTransazione")
                    Session("Ordine_Vettore") = dr.Item("VettoreId")
                    Session("Spese_Spedizione") = 0
                    Session("Codice") = dr.Item("cod_controllo")

                End Using
            End Using
        End Using

        Response.Redirect("aggiungi.aspx?id=Coupon", False)
            Context.ApplicationInstance.CompleteRequest()
    End Sub
End Class
