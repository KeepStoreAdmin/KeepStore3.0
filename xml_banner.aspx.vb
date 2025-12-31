
Partial Class xml_banner
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim DataOdierna As String = Date.Today.Year.ToString & "-" & Date.Today.Month.ToString & "-" & Date.Today.Day.ToString

        'Seleziono solo i primi 5 Record
        Me.SqlDataSource_Pubblicita.SelectCommand = "SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato FROM pubblicita WHERE (id>" & Application.Item("Last_Banner") & ") AND ((data_inizio_pubblicazione<='" & DataOdierna & "') AND (data_fine_pubblicazione>='" & DataOdierna & "')) AND ((numero_click_attuale<=limite_click) OR (limite_click=-1)) AND ((numero_impressioni_attuale<=limite_impressioni) OR (limite_impressioni=-1)) AND (abilitato=1) ORDER BY id ASC LIMIT 5"
    End Sub


    Protected Sub Page_PreRenderComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRenderComplete
        Dim i As Integer

        If Me.GridView_Banner.Rows.Count = 0 Then
            Application.Set("Last_Banner", "0")
            Response.Redirect("xml_banner.aspx")
            Return
        End If

        Response.Write("<?xml version=""1.0"" encoding=""iso-8859-1""?>" & Chr(13))
        Response.Write("<root transition=""1"" timeplay=""4500"" circleColor=""0x0099FF"" normalColorItemMenu=""0xCCCCCC"" hitColorItemMenu=""0xFFFFFF"" >" & Chr(13))

        For i = 0 To Me.GridView_Banner.Rows.Count - 1
            'Aumento +1 il campo numero impressioni relativo al banner
            Me.SqlDataSource_Pubblicita.UpdateCommand = "UPDATE pubblicita SET numero_impressioni_attuale = numero_impressioni_attuale + 1 WHERE (id = " & Me.GridView_Banner.Rows(i).Cells(0).Text & ")"
            Me.SqlDataSource_Pubblicita.Update()
            '----------------------------------------------------------
            Response.Write(Chr(13) & "<product img=""" & Me.GridView_Banner.Rows(i).Cells(1).Text & """ link=""click.aspx?id=" & Me.GridView_Banner.Rows(i).Cells(0).Text & "&link=" & Me.GridView_Banner.Rows(i).Cells(4).Text & """ target=""_blank"">" & Chr(13))
            Response.Write("<title>" & Me.GridView_Banner.Rows(i).Cells(2).Text & "</title>" & Chr(13))
            Response.Write("<content>" & Me.GridView_Banner.Rows(i).Cells(3).Text & "</content>" & Chr(13))
            Response.Write("</product>" & Chr(13))
        Next

        Response.Write(Chr(13) & "</root>" & Chr(13) & Chr(13))

        'Salvo l'ultimo id_banner visualizzato
        Application.Set("Last_Banner", Me.GridView_Banner.Rows(Me.GridView_Banner.Rows.Count - 1).Cells(0).Text)


        Me.GridView_Banner.Visible = False
    End Sub
End Class
