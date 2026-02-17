
Partial Class coupon
    Inherits System.Web.UI.Page
    'Variabili utilizzate per mascherare le immagini del menu
    Public val1_maschera As Integer = 0
    Public val2_maschera As Integer = -130
    'Per il conto alla rovescia
    Public cont As Integer = 0
    'Per la spaziatura dei coupon random
    Public cont_coupon_random As Integer = 0

    ' Bonifica legacy: prima era in <script runat="server"> nella pagina
    Public Function calcola_secondi(ByVal data As String) As String
        If String.IsNullOrWhiteSpace(data) Then
            Return "0"
        End If
        Dim temp_data As String() = data.Split("/"c)
        If temp_data.Length < 3 Then
            Return "0"
        End If
        Dim dd As Integer = Val(temp_data(0))
        Dim mm As Integer = Val(temp_data(1))
        Dim yy As Integer = Val(temp_data(2))
        If dd <= 0 OrElse mm <= 0 OrElse yy <= 0 Then
            Return "0"
        End If
        Dim temp_data1 As New DateTime(yy, mm, dd, 0, 0, 0)
        Dim temp_data2 As DateTime = Date.Now
        ' Aggiungo 1 giorno in più, perché le promo scadono a mezzanotte del giorno di fine
        temp_data1 = temp_data1.AddDays(1)
        Dim temp_sec As TimeSpan = temp_data1.Subtract(temp_data2)
        Return temp_sec.TotalMilliseconds.ToString(System.Globalization.CultureInfo.InvariantCulture)
    End Function

    Public Function adatta_titolo(ByVal titolo As String, ByVal lunghezza As Integer) As String
        Dim s As String = If(titolo, "")
        If lunghezza <= 0 Then
            Return s
        End If
        If s.Length <= lunghezza Then
            Return s
        End If
        Return Left(s, lunghezza) & " ..."
    End Function

    ' Maschera per lo slider settori (mantiene lo stesso comportamento legacy)
    Public Function Maschera() As String
        val1_maschera = val1_maschera + 131
        val2_maschera = val2_maschera + 131
        Return "clip:rect(0px " & val1_maschera & "px 455px " & val2_maschera & "px);"
    End Function

    Protected Sub Repeater_MenuSettori_ItemDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.RepeaterItemEventArgs) Handles Repeater_MenuSettori.ItemDataBound
        'Creo le Categorie rispettive al Settore Creato dal repeater
        Dim temp_repeater As Repeater = sender
        Dim temp_sql As SqlDataSource = New SqlDataSource
        Dim temp_label As Label = New Label

        temp_label.Text = ""

        If (temp_repeater.Items.Count > 0) Then
            temp_label = temp_repeater.Items(temp_repeater.Items.Count - 1).FindControl("LB_Settore")
            temp_sql = temp_repeater.Items(temp_repeater.Items.Count - 1).FindControl("SqlDataCategorie")
            temp_sql.SelectCommand = "SELECT idCategoria, NomeCategoria, OrdinamentoCategoria, Attiva_Disattiva_Categoria, imgCategoria, linkCategoria FROM coupon_categorie WHERE idSettore=@idSettore ORDER BY OrdinamentoCategoria, Nomecategoria LIMIT 10"
            temp_sql.SelectParameters.Clear()
            temp_sql.SelectParameters.Add("@idSettore", IIf(Val(temp_label.Text) > 0, Val(temp_label.Text), 0))
        End If

        'Setto la visualizzazione dei Coupon
        SqlCoupon.SelectCommand = "SELECT idCoupon, Titolo, Prezzo, DataInizio, DataFine, NumeroAcquisti, Attiva_Disattiva, Min_Ordinabile, Max_Ordinabile, Img, Sintesi, Condizioni, ComeOrdinare, DescrizioneLunga, DescrizioneHtml, DescrizioneTecnica, RegioneCoupon, CittaCoupon, idPartner, PrezzoDiListino, idSettore, idCategoria, CodiceVerificaCoupon, Raggiungimento_Minimo, Raggiungimento_Massimo, idArticolo FROM vsupercoupon WHERE ((DataInizio<=CURDATE()) AND (DataFine>=CURDATE()))"
    End Sub

    Protected Sub Repeater_MenuSettori_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Repeater_MenuSettori.PreRender
        'Creo le Categorie rispettive all'ultimo Settore Creato dal Repeater
        'Lo faccio nel Prerender per lavorare l'ultimo elemento generato dal Repeater
        Dim temp_repeater As Repeater = sender
        Dim temp_sql As SqlDataSource = New SqlDataSource
        Dim temp_label As Label = New Label

        temp_label.Text = ""

        If (temp_repeater.Items.Count > 0) Then
            temp_label = temp_repeater.Items(temp_repeater.Items.Count - 1).FindControl("LB_Settore")
            temp_sql = temp_repeater.Items(temp_repeater.Items.Count - 1).FindControl("SqlDataCategorie")
            temp_sql.SelectCommand = "SELECT idCategoria, NomeCategoria, OrdinamentoCategoria, Attiva_Disattiva_Categoria, imgCategoria, linkCategoria FROM coupon_categorie WHERE idSettore=@idSettore ORDER BY OrdinamentoCategoria, Nomecategoria LIMIT 10"
            temp_sql.SelectParameters.Clear()
            temp_sql.SelectParameters.Add("@idSettore", IIf(Val(temp_label.Text) > 0, Val(temp_label.Text), 0))
        End If
    End Sub

    Protected Sub GV_Coupon_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles GV_Coupon.PreRender
        'Filtro i Coupon per i valori st e ct passati nella QueryString + controllo la Data di validità del coupon
        If (Request.QueryString("st") > 0) Or (Request.QueryString("ct") > 0) Then
            SqlCoupon.SelectCommand = "SELECT idCoupon, Titolo, Prezzo, DataInizio, DataFine, NumeroAcquisti, Attiva_Disattiva, Min_Ordinabile, Max_Ordinabile, Img, Sintesi, Condizioni, ComeOrdinare, DescrizioneLunga, DescrizioneTecnica, RegioneCoupon, CittaCoupon, idPartner, PrezzoDiListino, idSettore, idCategoria, CodiceVerificaCoupon, Raggiungimento_Minimo, Raggiungimento_Massimo, idArticolo FROM coupon_inserzione WHERE (" & IIf(Request.QueryString("st") > 0, "idSettore=@idSettore", "1=1") & ") AND (" & IIf(Request.QueryString("ct") > 0, "idCategoria=@idCategoria", "1=1") & ") AND ((DataInizio<=CURDATE()) AND (DataFine>=CURDATE()))"
            SqlCoupon.SelectParameters.Clear()
            If Request.QueryString("st") > 0 Then
                SqlCoupon.SelectParameters.Add("@idSettore", Request.QueryString("st"))
            End If
            If Request.QueryString("ct") > 0 Then
                SqlCoupon.SelectParameters.Add("@idCategoria", Request.QueryString("ct"))
            End If
            SqlCoupon.DataBind()
            End If

            'Visualizzo i coupon random in base al numero di coupon visualizzati (filtrati).
            'Esempio -> Quando vengono visualizzati 2 coupon, visualizzo [numero_coupon_visualizzati]*2 coupon random
            SqlCoupon_Random.SelectCommand = "SELECT idCoupon, Titolo, Prezzo, DataInizio, DataFine, NumeroAcquisti, Attiva_Disattiva, Min_Ordinabile, Max_Ordinabile, Img, Sintesi, Condizioni, ComeOrdinare, DescrizioneLunga, DescrizioneTecnica, RegioneCoupon, CittaCoupon, idPartner, PrezzoDiListino, idSettore, idCategoria, CodiceVerificaCoupon, Raggiungimento_Minimo, Raggiungimento_Massimo, idArticolo FROM coupon_inserzione ORDER BY RAND() LIMIT " & GV_Coupon.Rows.Count * 2
    End Sub
End Class
