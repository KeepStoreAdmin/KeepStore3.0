
Partial Class vetrina_interna
    Inherits System.Web.UI.Page

    Public cont_prodotti As Integer = 0

    Protected Sub Repeater1_ItemDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.RepeaterItemEventArgs) Handles Repeater1.ItemDataBound
        Dim InOfferta As Label = e.Item.FindControl("InOfferta")
        Dim PrezzoPromoIvato As Label = e.Item.FindControl("PrezzoPromoIvato")
        Dim OffertaQntMinima As Label = e.Item.FindControl("OffertaQntMinima")

        ' ------------------------------- Prezzo con immagini ----------------------------
        Dim temp As String = ""
        Dim img_cifra9 As Image = e.Item.FindControl("img_prezzo9")
        Dim img_cifra8 As Image = e.Item.FindControl("img_prezzo8")
        Dim img_cifra7 As Image = e.Item.FindControl("img_prezzo7")
        Dim img_cifra6 As Image = e.Item.FindControl("img_prezzo6")
        Dim img_cifra5 As Image = e.Item.FindControl("img_prezzo5")
        Dim img_cifra4 As Image = e.Item.FindControl("img_prezzo4")
        Dim img_cifra3 As Image = e.Item.FindControl("img_prezzo3")
        Dim img_cifra2 As Image = e.Item.FindControl("img_prezzo2")
        Dim img_cifra1 As Image = e.Item.FindControl("img_prezzo1")

        img_cifra1.Visible = False
        img_cifra2.Visible = False
        img_cifra3.Visible = False
        img_cifra4.Visible = False
        img_cifra5.Visible = False
        img_cifra6.Visible = False
        img_cifra7.Visible = False
        img_cifra8.Visible = False
        img_cifra9.Visible = False

        If InOfferta.Text = "1" And OffertaQntMinima.Text = "1" Then
            temp = PrezzoPromoIvato.Text
        Else
            Dim temp_prezzo As Label = e.Item.FindControl("Prezzo")
            temp = temp_prezzo.Text
            temp_prezzo.Visible = False
        End If


        Dim cifre_da_visualizzare As String = ""
        'If Val(dispo.Text) > 0 Then
        cifre_da_visualizzare = "Images/cifre_vetrina/"
        'Else
        'cifre_da_visualizzare = "Images/cifre_no/"
        'End If

        temp = temp.Substring(2)
        img_cifra1.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 1) & ".png"
        img_cifra2.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 2) & ".png"
        img_cifra3.ImageUrl = cifre_da_visualizzare & "v.png"
        img_cifra4.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 4) & ".png"
        img_cifra1.Visible = True
        img_cifra2.Visible = True
        img_cifra3.Visible = True
        img_cifra4.Visible = True

        If (temp.Length >= 5) Then
            img_cifra5.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 5) & ".png"
            img_cifra5.Visible = True
        End If
        If (temp.Length >= 6) Then
            img_cifra6.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 6) & ".png"
            img_cifra6.Visible = True
        End If
        If (temp.Length >= 7) Then
            img_cifra7.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 7) & ".png"
            img_cifra7.Visible = True
        End If
        If (temp.Length >= 8) Then
            img_cifra8.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 8) & ".png"
            img_cifra8.Visible = True
        End If

        img_cifra9.ImageUrl = cifre_da_visualizzare & "e.png"
        img_cifra9.Visible = True

        ' ---------------------------------------------------------------------------------
    End Sub
End Class
