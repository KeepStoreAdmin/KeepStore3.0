Imports MySql.Data.MySqlClient

Partial Class ordine_coupon
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        'Controllo se l'utente è loggato o meno, se non è loggato lo indirizzo alla registrazione
        If Session("LoginID") <= 0 Then
            Response.Redirect("accessonegato.aspx")
        End If
        '----------------------------------------------------------------------------------------

        'Controllo il pagamento del Coupon è andato a Buon fine ed effettuo l'ordine
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandText = "SELECT coupon_inserzione.`idArticolo`, coupon_inserzione.`VettoreId`, coupon_inserzione.Iva_Coupon, iva.`Valore` AS ValoreIva_Coupon, coupon_tabella_temporanea.idCoupon, coupon_tabella_temporanea.Descrizione, coupon_tabella_temporanea.`cod_controllo`,coupon_tabella_temporanea.`StatoPagamento`,coupon_tabella_temporanea.`idTransazione`,articoli.`Codice`,articoli.`Descrizione1` AS Titolo, coupon_tabella_temporanea.`idCoupon`, coupon_tabella_temporanea.`prezzo`, coupon_tabella_temporanea.`qnt_coupon`, coupon_tabella_temporanea.`qnt_pezzi` FROM coupon_inserzione JOIN coupon_partners ON coupon_inserzione.idPartner=coupon_partners.idPartner JOIN coupon_tabella_temporanea ON coupon_inserzione.idCoupon=coupon_tabella_temporanea.idCoupon JOIN articoli ON coupon_inserzione.idArticolo=articoli.id JOIN iva ON Iva_Coupon=iva.`id` WHERE cod_controllo=?cod"
        cmd.Parameters.AddWithValue("?cod", Request.QueryString("cod"))

        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        'Va in errore se non combiano
        If dr.Item("StatoPagamento") = 1 Then
			Session("Coupon_idCoupon") = dr.Item("idCoupon")
            Session("Coupon_idArticolo") = dr.Item("IdArticolo")
            Session("Coupon_DescrizioneCoupon") = dr.Item("Descrizione")
            Session("Coupon_codArticolo") = dr.Item("Codice")
            Session("Coupon_DescrizioneArticolo") = dr.Item("Titolo")
            Session("Coupon_Qnt_Coupon") = dr.Item("qnt_coupon")
            Session("Coupon_Qnt_Pezzi") = dr.Item("qnt_pezzi")
            Session("Coupon_Prezzo") = Math.Round((dr.Item("prezzo") / ((dr.Item("ValoreIva_Coupon") / 100) + 1)) / dr.Item("qnt_pezzi"), 3)
            Session("Coupon_PrezzoIvato") = Math.Round(dr.Item("prezzo") / dr.Item("qnt_pezzi"), 3)
            Session("Coupon_Arrotondamento") = 0

            'Controllo se Aggiungere o meno un valore per l'arrotondamento
            If ((Session("Coupon_Prezzo") * ((dr.Item("ValoreIva_Coupon") / 100) + 1)) * Session("Coupon_Qnt_Pezzi")) <> (Session("Coupon_PrezzoIvato") * Session("Coupon_Qnt_Pezzi")) Then
                Session("Coupon_Arrotondamento") = Math.Round((Session("Coupon_PrezzoIvato") * Session("Coupon_Qnt_Pezzi")) - ((Session("Coupon_Prezzo") * ((dr.Item("ValoreIva_Coupon") / 100) + 1)) * Session("Coupon_Qnt_Pezzi")), 2)
            End If

            Session("Coupon_StatoPagamento") = dr.Item("StatoPagamento")
            Session("Coupon_idTransazione") = dr.Item("idTransazione")
            Session("Ordine_Vettore") = dr.Item("VettoreId")
            Session("Spese_Spedizione") = 0
            Session("Codice") = dr.Item("cod_controllo")

            conn.Close()

            Response.Redirect("aggiungi.aspx?id=Coupon")
        End If
        '-----------------------------------------------------------------------------------------------------------
    End Sub
End Class
