Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class vers_stampabile
    Inherits System.Web.UI.Page

    Dim IvaTipo As Integer
    Dim DispoTipo As Integer
    Dim DispoMinima As Integer

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        IvaTipo = Me.Session("IvaTipo")
        DispoTipo = Me.Session("DispoTipo")
        DispoMinima = Me.Session("DispoMinima")

        If Session("Listino") Is Nothing Then
            Response.Redirect("default.aspx")
        End If

        'Nella query devo controllare che i valori di Descrizione Lunga e Descrizione Html non siano NULL altrimenti si genera un'errore sui valori del campo
        sdsArticolo.SelectCommand = "SELECT id, Codice, Ean, Descrizione1, Descrizione2, IF(DescrizioneLunga IS NULL,'',DescrizioneLunga) AS DescrizioneLunga, IF(DescrizioneHTML IS NULL,'',DescrizioneHTML) AS DescrizioneHTML, ArticoliIva, Prezzo, IF(@IvaUtente>-1,((Prezzo)*((@IvaUtente/100)+1)),PrezzoIvato) AS PrezzoIvato, Img1, MarcheDescrizione, Disponibilita, Giacenza, InOrdine, Impegnata, InOfferta, SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDescrizione, SottogruppiDescrizione, MarcheDescrizione, Marche_img, PrezzoPromo, IF(@IvaUtente>-1,((PrezzoPromo)*((@IvaUtente/100)+1)),PrezzoPromoIvato) AS PrezzoPromoIvato, MarcheId, CategorieId, TipologieId, IF(PrezzoPromo IS NULL,Prezzo,PrezzoPromo) Ord_PrezzoPromo, IF(PrezzoPromoIvato IS NULL,PrezzoIvato,IF(@IvaUtente>-1,((PrezzoPromo)*((@IvaUtente/100)+1)),PrezzoPromoIvato)) Ord_PrezzoPromoIvato, OfferteQntMinima, OfferteMultipli, OfferteDataInizio, OfferteDataFine, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, Img1, Img2, Img3, Img4, Peso, ListinoUfficiale, Brochure, LinkProduttore FROM vsuperarticoli WHERE (id = @id2) and (NListino = @listino)"
        sdsArticolo.SelectParameters.Add("@IvaUtente", Session("Iva_Utente"))
        sdsArticolo.SelectParameters.Add("@id2", Request.QueryString("id"))
        sdsArticolo.SelectParameters.Add("@listino", Session("listino"))
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        SettaTitolo()
        AggiornaVisite()
    End Sub

    Public Sub SettaTitolo()
        Try
            Dim lblDescrizione As Label
            Dim Codice As Label = Me.fvPage.FindControl("Label13")
            Dim EAN As Label = Me.fvPage.FindControl("Label15")
            lblDescrizione = Me.fvPage.FindControl("lblDescrizione")
            Me.Title = Me.Title & " > " & lblDescrizione.Text & " > Codice: " & Codice.Text & " > EAN: " & EAN.Text
        Catch ex As Exception
        End Try
    End Sub

    Public Sub SettaDisponibilita()
        Dim img As Image
        Dim dispo As Label
        Dim impegnato As Label
        Dim arrivo As Label
        Dim PrezzoDes As Label
        Dim Prezzo As Label
        Dim PrezzoIvato As Label
        Dim PrezzoPromo As Label
        Try

            PrezzoDes = Me.fvPage.FindControl("lblPrezzoDes")
            Prezzo = Me.fvPage.FindControl("lblPrezzo")
            PrezzoIvato = Me.fvPage.FindControl("lblPrezzoIvato")
            PrezzoPromo = Me.fvPage.FindControl("lblPrezzoPromo")

            If IvaTipo = 1 Then
                PrezzoDes.Text = "Prezzo Iva Esclusa"
                'Prezzo.Visible = True
                'PrezzoIvato.Visible = False
            ElseIf IvaTipo = 2 Then
                PrezzoDes.Text = "Prezzo Iva Inclusa"
                'Prezzo.Visible = False
                'PrezzoIvato.Visible = True
            End If

            img = Me.fvPage.FindControl("imgDispo")
            dispo = Me.fvPage.FindControl("lblDispo")
            impegnato = Me.fvPage.FindControl("lblImpegnata")
            arrivo = Me.fvPage.FindControl("lblArrivo")

            If DispoTipo = 1 Then
                dispo.Visible = False
                If dispo.Text > DispoMinima Then
                    img.ImageUrl = "~/images/verde2.gif"
                    img.AlternateText = "Disponibile"
                ElseIf dispo.Text > 0 Then
                    img.ImageUrl = "~/images/giallo2.gif"
                    img.AlternateText = "Disponibilità Scarsa"
                Else
                    If arrivo.Text > 0 Then
                        img.ImageUrl = "~/images/azzurro2.gif"
                        img.AlternateText = "In Arrivo"
                    Else
                        img.ImageUrl = "~/images/rosso2.gif"
                        img.AlternateText = "Non Disponibile"
                    End If
                End If

            ElseIf DispoTipo = 2 Then
                img.Visible = False
                impegnato.Visible = True
                dispo.Visible = True
                arrivo.Visible = True
                Me.fvPage.FindControl("lblArr").Visible = True
                Me.fvPage.FindControl("lblImp").Visible = True
                Me.fvPage.FindControl("lblPunti1").Visible = True
                Me.fvPage.FindControl("lblPunti2").Visible = True
                Me.fvPage.FindControl("lblPunti3").Visible = True
            End If
        Catch
        End Try
    End Sub

    'Restituisce 1 se ci sono delle promo valide sull'articiolo altrimenti 0
    Function controlla_promo_articolo(ByVal cod_articolo As Integer, ByVal listino As Integer) As Integer
        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand

        cmd.CommandText = "SELECT id FROM vsuperarticoli WHERE (ID=" & cod_articolo & " AND NListino=" & listino & ") AND ((OfferteDataInizio <= CURDATE()) AND (OfferteDataFine >= CURDATE())) AND (InOfferta=1) ORDER BY PrezzoPromo DESC"

        cmd.Connection = conn
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If (dr.HasRows) Then
            dr.Close()
            conn.Close()
            Return 1
        Else
            dr.Close()
            conn.Close()
            Return 0
        End If
    End Function

    Protected Sub fvPage_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles fvPage.PreRender
        Dim Prezzo As Label
        Dim PrezzoIvato As Label
        Dim PrezzoModificabile As System.Web.UI.HtmlControls.HtmlInputText
        Dim dispo As Label

        Dim form As FormView
        Dim tb_id As TextBox
        Dim SQLDATA_Promo As SqlDataSource
        Dim prezzoPromo As Label

        Try
            form = CType(sender, FormView)

            prezzoPromo = form.FindControl("lblPrezzoPromo")
            tb_id = form.FindControl("tbid")
            SQLDATA_Promo = form.FindControl("sdsPromo")
            If (controlla_promo_articolo(Val(tb_id.Text), Session("listino")) = 1) Then
                'Nella query devo controllare che i valori di Descrizione Lunga e Descrizione Html non siano NULL altrimenti si genera un'errore sui valori del campo
                SQLDATA_Promo.SelectCommand = "SELECT id, Codice, Ean, Descrizione1, Descrizione2, IF(DescrizioneLunga IS NULL,'',DescrizioneLunga) AS DescrizioneLunga, IF(DescrizioneHTML IS NULL,'',DescrizioneHTML) AS DescrizioneHTML, Prezzo, IF(@IvaUtente>-1,((Prezzo)*((@IvaUtente/100)+1)),PrezzoIvato) AS PrezzoIvato, Img1, MarcheDescrizione, Disponibilita, Giacenza, InOrdine, Impegnata, InOfferta, SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDescrizione, SottogruppiDescrizione, MarcheDescrizione, Marche_img, PrezzoPromo, IF(@IvaUtente>-1,((PrezzoPromo)*((@IvaUtente/100)+1)),PrezzoPromoIvato) AS PrezzoPromoIvato, MarcheId, CategorieId, TipologieId, IF(PrezzoPromo IS NULL,Prezzo,PrezzoPromo) Ord_PrezzoPromo, IF(PrezzoPromoIvato IS NULL,PrezzoIvato,IF(@IvaUtente>-1,((PrezzoPromo)*((@IvaUtente/100)+1)),PrezzoPromoIvato)) Ord_PrezzoPromoIvato, OfferteQntMinima, OfferteMultipli, OfferteDataInizio, OfferteDataFine FROM vsuperarticoli WHERE ID=@id1 AND NListino=@listino ORDER BY PrezzoPromo DESC"
                SQLDATA_Promo.SelectParameters.Add("@IvaUtente", Session("Iva_Utente"))
                SQLDATA_Promo.SelectParameters.Add("@id1", tb_id.Text)
                SQLDATA_Promo.SelectParameters.Add("@listino", Session("listino"))
            Else
                SQLDATA_Promo.SelectCommand = ""
                prezzoPromo.Visible = False
            End If

            Try
                SettaDisponibilita()
                Dim lblDes As Label
                Dim lblDesHTML As Label
                lblDes = Me.fvPage.FindControl("lblDescrizioneArt")
                lblDesHTML = Me.fvPage.FindControl("lblDescrizioneHTMLArt")
                If lblDes.Text <> "" Then
                    lblDes.Text = lblDes.Text.Replace(vbNewLine, "<br>")
                End If

                Dim IvaTipo As Integer = Me.Session("IvaTipo")
                dispo = Me.fvPage.FindControl("lblDispo")
                Prezzo = Me.fvPage.FindControl("lblPrezzo")
                PrezzoIvato = Me.fvPage.FindControl("lblPrezzoIvato")
                PrezzoModificabile = Me.fvPage.FindControl("prezzo_modificabile")

                ' --------------------------------------------------------------------------------

                If IvaTipo = 1 Then
                    'Prezzo.Visible = True
                    'PrezzoIvato.Visible = False
                    PrezzoModificabile.Value = Prezzo.Text.Replace(".", ",")
                ElseIf IvaTipo = 2 Then
                    'Prezzo.Visible = False
                    'PrezzoIvato.Visible = True
                    PrezzoModificabile.Value = PrezzoIvato.Text.Replace(".", ",")
                End If

                ' ---------------------------------------------------------------------------------
            Catch ex As Exception
            End Try
        Catch
        End Try
    End Sub

    Public Sub AggiornaVisite()
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim id As Integer = Me.Request.QueryString("id")

        If id <> CLng(Me.Session("visite_articoloid")) Then

            Me.Session("visite_articoloid") = id

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text

            cmd.CommandText = "update articoli set visite=visite+1 where id=@id"
            cmd.Parameters.AddWithValue("@id", id)
            cmd.ExecuteNonQuery()

            cmd.Dispose()

            conn.Close()
            conn.Dispose()

        End If
    End Sub

    Protected Sub rPromo_ItemDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.RepeaterItemEventArgs)

        Dim label_sconto As Label
        Dim panel_sconto As Panel
        Dim prezzo_canc As Label
        Dim prezzo_ivato_canc As Label
        Dim PrezzoModificabile As System.Web.UI.HtmlControls.HtmlInputText

        panel_sconto = e.Item.Parent.Parent.FindControl("Panel_Visualizza_Percentuale_Sconto")
        prezzo_canc = e.Item.Parent.Parent.FindControl("Label_Canc_Prezzo")
        prezzo_ivato_canc = e.Item.Parent.Parent.FindControl("Label_Canc_PrezzoIvato")

        label_sconto = e.Item.Parent.Parent.FindControl("sconto_applicato")

        Dim Offerta As Label = e.Item.FindControl("lblOfferta")
        Dim InOfferta As Label = e.Item.FindControl("lblInOfferta")
        Dim QtaMin As Label = e.Item.FindControl("lblQtaMin")
        Dim QtaMultipli As Label = e.Item.FindControl("lblMultipli")
        Dim PrezzoPromo As Label = e.Item.FindControl("lblPrezzoPromo")
        Dim PrezzoPromoIvato As Label = e.Item.FindControl("lblPrezzoPromoIvato")

        Dim ParentPrezzoPromo As Label = e.Item.Parent.Parent.FindControl("lblPrezzoPromo")
        Dim ParentPrezzo As Label = e.Item.Parent.Parent.FindControl("lblPrezzo")
        Dim ParentPrezzoIvato As Label = e.Item.Parent.Parent.FindControl("lblPrezzoIvato")
        Dim ParentIconPromo As Image = e.Item.Parent.Parent.FindControl("img_offerta")

        If InOfferta.Text = 1 Then
            'Visualizzo o meno l'icona in offerta
            'ParentIconPromo.Visible = True

            Dim temp As String = ""
            If IvaTipo = 1 Then
                temp = FormatNumber(PrezzoPromo.Text.Replace(".", ""), 2)
            ElseIf IvaTipo = 2 Then
                temp = FormatNumber(PrezzoPromoIvato.Text.Replace(".", ""), 2)
            End If

            If QtaMin.Text > 0 Then
                Offerta.Text = Offerta.Text & " MINIMO " & QtaMin.Text & " PZ."
            ElseIf QtaMultipli.Text > 0 Then
                Offerta.Text = Offerta.Text & " MULTIPLI " & QtaMultipli.Text & " PZ."
            End If

            PrezzoModificabile = e.Item.Parent.Parent.FindControl("prezzo_modificabile")

            If IvaTipo = 1 Then
                Offerta.Text = Offerta.Text & " A € " & FormatNumber(PrezzoPromo.Text, 2)
                ParentPrezzoPromo.Text = "€ " & FormatNumber(PrezzoPromo.Text, 2)
                PrezzoModificabile.Value = "€ " & FormatNumber(PrezzoPromo.Text, 2)
                ParentPrezzo.Font.Strikeout = True
            ElseIf IvaTipo = 2 Then
                Offerta.Text = Offerta.Text & " A € " & FormatNumber(PrezzoPromoIvato.Text, 2)
                ParentPrezzoPromo.Text = "€ " & FormatNumber(PrezzoPromoIvato.Text, 2)
                PrezzoModificabile.Value = "€ " & FormatNumber(PrezzoPromoIvato.Text, 2)
                ParentPrezzoIvato.Font.Strikeout = True
            End If

            'Stampo a video lo sconto applcato all'offerta
            panel_sconto.Visible = True
            If IvaTipo = 1 Then
                label_sconto.Text = "- " & String.Format("{0:0}", (((ParentPrezzo.Text - temp) * 100) / ParentPrezzo.Text)) & "%"
            Else
                label_sconto.Text = "- " & String.Format("{0:0}", (((ParentPrezzoIvato.Text - temp) * 100) / ParentPrezzoIvato.Text)) & "%"
            End If

            If Val(label_sconto.Text) = 0 Then
                label_sconto.Text = "0%"
            End If

            ' ---------------------------------------------------------------------------------

            e.Item.Parent.Parent.FindControl("Panel_in_offerta").Visible = True

            If Session("IvaTipo") = 1 Then
                prezzo_canc.Visible = True
                prezzo_ivato_canc.Visible = False
            Else
                prezzo_canc.Visible = False
                prezzo_ivato_canc.Visible = True
            End If
        End If

    End Sub

    Protected Sub Image1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs)

        Dim img As Image = sender
        Dim imageurl As String = Server.MapPath(img.ImageUrl)

        Dim temp_obj As HtmlLink
        temp_obj = Me.Page.Master.FindControl("Immagine_Facebook")
        temp_obj.Href = img.ImageUrl.ToString

        Try
            Dim bmp As System.Drawing.Image = System.Drawing.Image.FromFile(imageurl)

            If bmp.Width > 400 Then
                img.Width = 400
            End If
        Catch ex As Exception

        End Try

    End Sub

End Class
