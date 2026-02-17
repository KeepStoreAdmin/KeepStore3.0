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

    '=== Helper spostate dal markup (bonifica legacy) ===
    Protected Function calcola_secondi(ByVal data As String) As String
        If String.IsNullOrWhiteSpace(data) Then Return "0"
        Dim temp_data As String() = data.Split("/"c)
        If temp_data.Length <> 3 Then Return "0"

        Dim giorno As Integer
        Dim mese As Integer
        Dim anno As Integer
        If Not Integer.TryParse(temp_data(0), giorno) Then Return "0"
        If Not Integer.TryParse(temp_data(1), mese) Then Return "0"
        If Not Integer.TryParse(temp_data(2), anno) Then Return "0"

        Dim temp_data1 As New DateTime(anno, mese, giorno, 0, 0, 0)
        Dim temp_data2 As DateTime = Date.Now
        'Le promo scadono alla mezzanotte del giorno di fine
        temp_data1 = temp_data1.AddDays(1)
        Dim temp_sec As TimeSpan = temp_data1.Subtract(temp_data2)
        Return temp_sec.TotalMilliseconds
    End Function

    Protected Function controllo_presenza_opzione(ByVal opzione As String) As String
        If Not String.IsNullOrEmpty(opzione) Then
            Return ""
        End If
        Return "none"
    End Function

    Protected Function reindirizza_a_opzioni(ByVal opzione As String) As String
        'Compatibilità: stessa logica di controllo_presenza_opzione
        If Not String.IsNullOrEmpty(opzione) Then
            Return ""
        End If
        Return "none"
    End Function

    Protected Function visualizza_descrizione_tecnica(ByVal stringa As Object) As String
        If stringa Is Nothing OrElse IsDBNull(stringa) Then Return "none"
        Dim s As String = TryCast(stringa, String)
        If String.IsNullOrEmpty(s) Then Return "none"
        Return ""
    End Function

    Protected Function adatta_titolo(ByVal titolo As String, ByVal lunghezza As Integer) As String
        If String.IsNullOrEmpty(titolo) Then Return ""
        If lunghezza <= 0 Then Return ""
        If titolo.Length <= lunghezza Then Return titolo
        Return Left(titolo, lunghezza) & " ..."
    End Function
End Class