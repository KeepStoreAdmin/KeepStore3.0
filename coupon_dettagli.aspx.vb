Imports MySql.Data.MySqlClient

Partial Class coupon_dettagli
    Inherits System.Web.UI.Page

    'Variabili utilizzate per mascherare le immagini del menu
    Public val1_maschera As Integer = 0
    Public val2_maschera As Integer = -130
    'Per il conto alla rovescia
    Public cont As Integer = 0
    'Calcolo degli acquisti reali del coupon, prelevati dagli ordini. Ricordarsi che il numero di acquisti presenti sul web è uguale a Numero Acquisti presenti nella riga del Coupon + Numero Acquisti Reali (Presenti negli Ordini)
    Public conteggio_acquistati As Integer = 0


    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Request.QueryString("id") > 0 Then
            'Seleziono il coupon da visualizzare
            SqlData_CouponInserzioni.SelectCommand = "SELECT * FROM vsupercoupon JOIN coupon_partners ON vsupercoupon.idPartner=coupon_partners.idPartner WHERE idCoupon=@id"
            SqlData_CouponInserzioni.SelectParameters.Clear()
            SqlData_CouponInserzioni.SelectParameters.Add("@id", Request.QueryString("id"))
            'Aggiungo una visita al Coupon selezionato
            SqlData_CouponInserzioni.UpdateCommand = "UPDATE coupon_inserzione SET visite=visite+1 WHERE idCoupon=@id"
            SqlData_CouponInserzioni.UpdateParameters.Clear()
            SqlData_CouponInserzioni.UpdateParameters.add("@id", Request.QueryString("id"))
            SqlData_CouponInserzioni.Update()

            'Conteggio del numero dei Coupon Acquistati Realmente, tramite i documenti
            Dim conn As New MySqlConnection
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            Dim cmd As New MySqlCommand
            cmd.Connection = conn

            cmd.CommandText = "SELECT COUNT(*) AS Conteggio FROM documenti WHERE Coupon_idCoupon=@id"
            cmd.Parameters.AddWithValue("@id", Request.QueryString("id"))
            Dim dr As MySqlDataReader = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows Then
                conteggio_acquistati = dr.Item("Conteggio")
            End If

            dr.Close()
            dr.Dispose()
            cmd.Dispose()
            conn.Close()
            '------------------------------------------------------------------------------------------------------------------
        Else
            Response.Redirect("coupon.aspx")
        End If
    End Sub
End Class