
Partial Class lista_coupon
    Inherits System.Web.UI.Page

    Public cont_clock As Integer = 0

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        SqlDataCoupon.SelectCommand = "SELECT * FROM vsupercoupon WHERE ((DATEDIFF(CURDATE(),DataInizio)>=0) AND (DATEDIFF(CURDATE(),DataFine)<=0))"
        If Request.QueryString("search") <> "" Then
            SqlDataCoupon.SelectCommand = SqlDataCoupon.SelectCommand & " AND (Titolo LIKE CONCAT('%', @search, '%'))"
            SqlDataCoupon.SelectParameters.Add("@search", Request.QueryString("search"))
        End If

        'Nel caso di filtro su categoria
        If Val(Request.QueryString("ct")) > 0 Then
            SqlDataCoupon.SelectCommand = SqlDataCoupon.SelectCommand + " AND (idCategoria=@ct)"
            SqlDataCoupon.SelectParameters.Add("@ct", Request.QueryString("ct"))
        End If

        SqlDataCoupon.DataBind()
    End Sub

    Protected Function calcola_secondi(ByVal data As String) As String
        If String.IsNullOrEmpty(data) Then Return "0"
        Dim temp_data As String() = data.Split("/"c)
        If temp_data.Length < 3 Then Return "0"
        Dim d As DateTime
        ' formato atteso: dd/MM/yyyy
        If Not DateTime.TryParseExact(data, "dd/MM/yyyy", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, d) Then
            ' fallback (in caso di formati diversi)
            Try
                d = New DateTime(CInt(temp_data(2)), CInt(temp_data(1)), CInt(temp_data(0)), 0, 0, 0)
            Catch
                Return "0"
            End Try
        End If

        Dim nowDt As DateTime = DateTime.Now
        'Aggiungo 1 giorno in più, perchè le nostre promo scadono alla mezzanotte del giorno di fine
        d = d.AddDays(1)
        Dim temp_sec As TimeSpan = d.Subtract(nowDt)
        Return temp_sec.TotalMilliseconds.ToString(System.Globalization.CultureInfo.InvariantCulture)
    End Function

    Protected Function adatta_titolo(ByVal titolo As String, ByVal lunghezza As Integer) As String
        If titolo Is Nothing Then Return ""
        If lunghezza <= 0 Then Return ""
        If titolo.Length <= lunghezza Then Return titolo
        Return Left(titolo, lunghezza) & " ..."
    End Function

End Class