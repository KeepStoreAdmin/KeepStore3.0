Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class wishlist
    Inherits System.Web.UI.Page

    Dim IvaTipo As Integer
    Dim DispoTipo As Integer
    Dim DispoMinima As Integer
    Dim InOfferta As Integer

    Function sostituisci_caratteri_speciali(ByRef stringa As String) As String
        stringa = Server.HtmlDecode(stringa)
        Return stringa
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("UtentiId") < 1 Then
            Response.Redirect("default.aspx")
        End If

        Session.Item("Pagina_visitata_Articoli") = Me.Request.Url.ToString 'Aggiorno l'ultima pagina visitata in Articoli

        Me.Session("Carrello_Pagina") = "articoli.aspx"

        DispoTipo = Me.Session("DispoTipo")
        DispoMinima = Me.Session("DispoMinima")

        
    End Sub

    Protected Sub Page_LoadComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.LoadComplete

        IvaTipo = Me.Session("IvaTipo")

        'Modificato Ordine nella GridView
        'Il criterio d'ordine si trova nella vista "vsuperarticoli"
        If IvaTipo = 1 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Esclusa"
            'Me.GridView1.Columns(5).SortExpression = "Prezzo"
        ElseIf IvaTipo = 2 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Inclusa"
            'Me.GridView1.Columns(5).SortExpression = "PrezzoIvato"
        End If

        CaricaArticoli()
        Me.GridView1.PageSize = Me.Session("RigheArticoli")
        Me.GridView1.PageIndex = Session("Articoli_PageIndex")

        'Inserimento della stringa di ricerca nella tabella query_string, per l'indicizzazione
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet
        Dim strCerca As String = Me.Session("q")

        Try

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            sqlString = "INSERT INTO query_string (QString) VALUES (@strCerca)"

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.CommandText = sqlString
            cmd.Parameters.AddWithValue("@strCerca", strCerca)

            strCerca = sostituisci_caratteri_speciali(strCerca)
            If (strCerca.Contains("&") = False) Or (strCerca.Contains(";") = False) Then 'Non inseriamo nel Database le parole che contengono "&" o "amp;"
                cmd.ExecuteNonQuery()
            End If

            cmd.Dispose()
        Catch ex As Exception

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try
    End Sub

    Public Sub CaricaArticoli()
        'Utile per visualizzare i prezzi con iva dell'utente
        Dim Sqlstring As String = "SELECT vsuperarticoli.id AS id, vsuperarticoli.Codice AS Codice, vsuperarticoli.Ean AS Ean, vsuperarticoli.Descrizione1 AS Descrizione1, vsuperarticoli.Descrizione2 AS Descrizione2, vsuperarticoli.DescrizioneLunga AS DescrizioneLunga, vsuperarticoli.UmId AS UmId, vsuperarticoli.Vetrina AS Vestrina, vsuperarticoli.MarcheId AS MarcheId, vsuperarticoli.MarcheDescrizione AS MarcheDescrizione, vsuperarticoli.Marche_img AS Marche_img, vsuperarticoli.MarcheOrdinamento AS MarcheOrdinamento, vsuperarticoli.SettoriId AS SettoriId, vsuperarticoli.SettoriDescrizione AS SettoriDescrizione, vsuperarticoli.SettoriOrdinamento AS SettoriOrdinamento, vsuperarticoli.CategorieId AS CategorieId, vsuperarticoli.CategorieDescrizione AS CategorieDescrizione, vsuperarticoli.CategorieOrdinamento AS CategorieOrdinamento, vsuperarticoli.TipologieId AS TipologieId, vsuperarticoli.TipologieDescrizione AS TipologieDescrizione, vsuperarticoli.TipologieOrdinamento AS TipologieOrdinamento, vsuperarticoli.GruppiId AS GruppiId, vsuperarticoli.GruppiDescrizione AS GruppiDescrizione, vsuperarticoli.GruppiOrdinamento AS GruppiOrdinamento, vsuperarticoli.SottoGruppiId AS SottoGruppiId, vsuperarticoli.SottogruppiDescrizione AS SottogruppiDescrizione, vsuperarticoli.SottogruppiOrdinamento AS SottogruppiOrdinamento, vsuperarticoli.ArticoliIva AS ArticoliId, vsuperarticoli.Peso AS Peso, vsuperarticoli.ArticoliPrezzoAcquisto AS ArticoliPrezzoAcquisto, vsuperarticoli.ListinoUfficiale AS ListinoUfficiale, vsuperarticoli.Img1 AS Img1, vsuperarticoli.Img2 AS Img2, vsuperarticoli.Img3 AS Img3, vsuperarticoli.Img4 AS Img4	, vsuperarticoli.LinkProduttore AS LinkProduttore, vsuperarticoli.Brochure AS Brochure, vsuperarticoli.DataCreazione AS DataCreazione, vsuperarticoli.visite AS Visite, vsuperarticoli.Export AS Export, vsuperarticoli.Giacenza AS Giacenza, vsuperarticoli.InOrdine AS InOrdine, vsuperarticoli.Disponibilita AS Disponibilita, vsuperarticoli.Impegnata AS Impegnata, vsuperarticoli.ScortaMinima AS ScortaMinima, vsuperarticoli.ArticoliListiniId AS ArticoliListiniId, vsuperarticoli.NListino AS NListino, vsuperarticoli.PrezzoAcquisto AS PrezzoAcquisto, vsuperarticoli.Ricarico AS Ricarico, vsuperarticoli.sconto1 AS sconto1, vsuperarticoli.sconto2 AS sconto2	, vsuperarticoli.iva AS iva, vsuperarticoli.Prezzo AS Prezzo, IF(@IvaUtente>0,((vsuperarticoli.Prezzo)*((@IvaUtente/100)+1)),vsuperarticoli.PrezzoIvato) AS PrezzoIvato, vsuperarticoli.SpedizioneGratis_Listini AS SpedizioneGratis_Listini, vsuperarticoli.SpedizioneGratis_Data_Inizio AS SpedizioneGratis_Data_Inizio, vsuperarticoli.SpedizioneGratis_Data_Fine AS SpedizioneGratis_Data_Fine, vsuperarticoli.OfferteID AS OfferteID, vsuperarticoli.OfferteDettagliId AS OfferteDettagliId, vsuperarticoli.OfferteDescrizione AS OfferteDescrizione, vsuperarticoli.OfferteImmagine AS OfferteImmagine, vsuperarticoli.OfferteDataInizio AS OfferteDataInizio, vsuperarticoli.OfferteDataFine AS OfferteDataFine	, vsuperarticoli.OfferteDaListino AS OfferteDaListino, vsuperarticoli.OfferteAListino AS OfferteAListino, vsuperarticoli.OfferteQntMinima AS OfferteQntMinima, vsuperarticoli.OfferteMultipli AS OfferteMultipli, vsuperarticoli.OffertePrezzo AS OffertePrezzo, vsuperarticoli.InOfferta AS InOfferta, vsuperarticoli.PrezzoPromo AS PrezzoPromo, IF(@IvaUtente>0,((vsuperarticoli.PrezzoPromo)*((@IvaUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato) AS PrezzoPromoIvato, wishlist.id_utente, taglie.descrizione as taglia, colori.descrizione as colore, varticoli_iva.valore as ValoreIva FROM wishlist"
        Sqlstring = Sqlstring + " INNER JOIN vsuperarticoli ON (wishlist.id_articolo = vsuperarticoli.id)"
		Sqlstring = Sqlstring + " LEFT OUTER JOIN articoli_tagliecolori ON wishlist.TCid = articoli_tagliecolori.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"
		Sqlstring = Sqlstring + " LEFT OUTER JOIN varticoli_iva ON varticoli_iva.ArticoliId = wishlist.id_articolo"
        Sqlstring = Sqlstring + " WHERE (wishlist.id_utente=@id) AND (NListino=@listino) GROUP BY id"
        sdsArticoli.SelectCommand = Sqlstring
        Dim sdsPromo As SqlDataSource = TryCast(SeoBuilder.FindControlRecursive(Me, "SQLDATA_Promo"), SqlDataSource)
        If sdsPromo IsNot Nothing Then
        sdsPromo.SelectParameters.Clear()
        sdsPromo.SelectParameters.Add("IvaUtente", Convert.ToString(Session("Iva_Utente")))
        sdsPromo.SelectParameters.Add("id", Convert.ToString(Session("UtentiId")))
        sdsPromo.SelectParameters.Add("listino", Convert.ToString(Session("listino")))
        End If
    End Sub

    Public Sub SetSelectedIndex(ByVal dl As DataList, ByVal val As Integer)
        Dim i As Integer
        Dim Index As Integer = -1
        Dim hl As HyperLink

        dl.SelectedIndex = 0

        For i = 0 To dl.Items.Count - 1
            hl = dl.Items(i).FindControl("HyperLink1")

            If hl.TabIndex = val Then
                Index = i
                Me.Title = Me.Title & " > " & hl.Text
                'dl.SelectedIndex = Index
            End If
        Next

    End Sub

    Protected Sub sdsArticoli_Selected(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.SqlDataSourceStatusEventArgs) Handles sdsArticoli.Selected
        Me.lblTrovati.Text = e.AffectedRows.ToString
    End Sub

    Protected Sub GridView1_PageIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PageIndexChanged
        Session("Articoli_PageIndex") = Me.GridView1.PageIndex
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

    Protected Sub GridView1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PreRender
        Dim img, img2 As Image
        Dim dispo As Label
        Dim arrivo As Label
        Dim impegnato As Label
        Dim Prezzo As Label
        Dim PrezzoIvato As Label
        Dim label_impegnato As Label
        Dim Qta As TextBox
        Dim InOfferta As TextBox
        Dim rPromo As Repeater
        Dim i As Integer
        Dim tb_id As TextBox
        Dim SQLDATA_Promo As SqlDataSource
        Dim prezzoPromo As Label

        For i = 0 To GridView1.Rows.Count - 1
            prezzoPromo = GridView1.Rows(i).FindControl("lblPrezzoPromo")
            InOfferta = GridView1.Rows(i).FindControl("tbInOfferta")
            rPromo = GridView1.Rows(i).FindControl("rPromo")
            tb_id = GridView1.Rows(i).FindControl("tbid")
            If (InOfferta.Text = 1) And (controlla_promo_articolo(tb_id.Text, Session("listino")) = 1) Then
                SQLDATA_Promo = GridView1.Rows(i).FindControl("sdsPromo")
                SQLDATA_Promo.SelectCommand = "SELECT id, Codice, Ean, Descrizione1, Descrizione2, DescrizioneLunga, Prezzo, IF(@IvaUtente>0,((Prezzo)*((@IvaUtente/100)+1)),PrezzoIvato) AS PrezzoIvato, Img1, MarcheDescrizione, Disponibilita, Giacenza, InOrdine, Impegnata, InOfferta, SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDescrizione, SottogruppiDescrizione, MarcheDescrizione, Marche_img, PrezzoPromo, IF(@IvaUtente>0,((PrezzoPromo)*((@IvaUtente/100)+1)),PrezzoPromoIvato) AS PrezzoPromoIvato, MarcheId, CategorieId, TipologieId, IF(PrezzoPromo IS NULL,Prezzo,PrezzoPromo) Ord_PrezzoPromo, IF(PrezzoPromoIvato IS NULL,PrezzoIvato,IF(@IvaUtente>0,((PrezzoPromo)*((@IvaUtente/100)+1)),PrezzoPromoIvato)) Ord_PrezzoPromoIvato, OfferteQntMinima, OfferteMultipli, OfferteDataInizio, OfferteDataFine FROM vsuperarticoli WHERE (ID=@id AND NListino=@listino) AND ((OfferteDataInizio <= CURDATE()) AND (OfferteDataFine >= CURDATE())) ORDER BY PrezzoPromo DESC"
                SQLDATA_Promo.SelectParameters.Add("@IvaUtente", Session("Iva_Utente"))
                SQLDATA_Promo.SelectParameters.Add("@id", tb_id.Text)
                SQLDATA_Promo.SelectParameters.Add("@listino", Session("listino"))
                rPromo.DataSourceID = "sdsPromo"
            Else
                rPromo.DataSourceID = ""
                prezzoPromo.Visible = False
            End If

            Prezzo = GridView1.Rows(i).FindControl("lblPrezzo")
            PrezzoIvato = GridView1.Rows(i).FindControl("lblPrezzoIvato")
            Qta = GridView1.Rows(i).FindControl("tbQuantita")

            ' --------------------------------------------------------------------------------
            ' ------------------------------- Prezzo con immagini ----------------------------
            Dim temp As String = ""
            Dim img_cifra9 As Image = GridView1.Rows(i).FindControl("img_prezzo9")
            Dim img_cifra8 As Image = GridView1.Rows(i).FindControl("img_prezzo8")
            Dim img_cifra7 As Image = GridView1.Rows(i).FindControl("img_prezzo7")
            Dim img_cifra6 As Image = GridView1.Rows(i).FindControl("img_prezzo6")
            Dim img_cifra5 As Image = GridView1.Rows(i).FindControl("img_prezzo5")
            Dim img_cifra4 As Image = GridView1.Rows(i).FindControl("img_prezzo4")
            Dim img_cifra3 As Image = GridView1.Rows(i).FindControl("img_prezzo3")
            Dim img_cifra2 As Image = GridView1.Rows(i).FindControl("img_prezzo2")
            Dim img_cifra1 As Image = GridView1.Rows(i).FindControl("img_prezzo1")

            If IvaTipo = 1 Then
                Prezzo.Visible = True
                PrezzoIvato.Visible = False

                temp = Prezzo.Text.Replace(".", "")
            ElseIf IvaTipo = 2 Then
                Prezzo.Visible = False
                PrezzoIvato.Visible = True

                temp = PrezzoIvato.Text.Replace(".", "")
            End If

            Dim cifre_da_visualizzare As String = ""
            dispo = GridView1.Rows(i).FindControl("Label_dispo")
            If Val(dispo.Text) > 0 Then
                cifre_da_visualizzare = "Images/cifre_ok/"
            Else
                cifre_da_visualizzare = "Images/cifre_no/"
            End If

            If (temp <> "") Then
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
                Else
                    img_cifra5.Visible = False
                End If
                If (temp.Length >= 6) Then
                    img_cifra6.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 6) & ".png"
                    img_cifra6.Visible = True
                Else
                    img_cifra6.Visible = False
                End If
                If (temp.Length >= 7) Then
                    img_cifra7.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 7) & ".png"
                    img_cifra7.Visible = True
                Else
                    img_cifra7.Visible = False
                End If
                If (temp.Length >= 8) Then
                    img_cifra8.ImageUrl = cifre_da_visualizzare & temp(temp.Length - 8) & ".png"
                    img_cifra8.Visible = True
                Else
                    img_cifra8.Visible = False
                End If

                img_cifra9.ImageUrl = cifre_da_visualizzare & "e.png"
                img_cifra9.Visible = True
            End If
            ' ---------------------------------------------------------------------------------

            If IvaTipo = 1 Then
                Prezzo.Visible = True
                PrezzoIvato.Visible = False
            ElseIf IvaTipo = 2 Then
                Prezzo.Visible = False
                PrezzoIvato.Visible = True
            End If

            Prezzo.Visible = False
            PrezzoIvato.Visible = False

            img = GridView1.Rows(i).FindControl("imgDispo")
            img2 = GridView1.Rows(i).FindControl("imgArrivo")
            dispo = GridView1.Rows(i).FindControl("Label_dispo")
            arrivo = GridView1.Rows(i).FindControl("Label_arrivo")
            impegnato = GridView1.Rows(i).FindControl("Label_imp")
            label_impegnato = GridView1.Rows(i).FindControl("lblImpegnata")

            '------------------------------ Visualizzazione a Pallini delle Disponibilità, Impegnate, Ariivi -------------------------
            'Immagine di Default 
            img.ImageUrl = "~/images/rosso2.gif"
            img.AlternateText = "Non Disponibile"
            img.Visible = True
            '------------------------------------
            If DispoTipo = 1 Then
                'Nascondo gli oggetti impegnati
                impegnato.Visible = False
                label_impegnato.Visible = False
                '-------------------------------
                dispo.Visible = False
                If arrivo.Text > 0 Then
                    img2.ImageUrl = "~/images/azzurro2.gif"
                    img2.AlternateText = "In Arrivo"
                    arrivo.Visible = False
                    img2.Visible = True
                Else
                    arrivo.Visible = True
                    img2.Visible = False
                End If

                If dispo.Text > DispoMinima Then
                    img.ImageUrl = "~/images/verde2.gif"
                    img.AlternateText = "Disponibile"
                ElseIf dispo.Text > 0 Then
                    img.ImageUrl = "~/images/giallo2.gif"
                    img.AlternateText = "Disponibilità Scarsa"
                Else
                    If arrivo.Text <= 0 Then
                        img.ImageUrl = "~/images/rosso2.gif"
                        img.AlternateText = "Non Disponibile"
                    End If
                End If

                '------------------------------ Visualizzazione a quantità delle Disponibilità, Impegnate, Arrivi -------------------------
            ElseIf DispoTipo = 2 Then
                arrivo.Visible = True
                img.Visible = False
                dispo.Visible = True
            End If

        Next

        Me.lblLinee.Text = Me.GridView1.PageSize

    End Sub

    Protected Sub ImageButton1_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        Dim temp As ImageButton = sender
        Dim temp2 As GridView

        temp2 = CType(temp.NamingContainer.FindControl("GridView3"), GridView)
        If temp2.Rows.Count > 0 Then
            'Comunico al carrello se il prodotto è un prodotto ha spedizione gratis
            Session("ProdottoGratis") = 1
        Else
            'Comunico al carrello se il prodotto non è un prodotto ha spedizione gratis
            Session("ProdottoGratis") = 0
        End If

        Dim img As Image = sender
        Dim Qta As TextBox
        Dim ID As Label

        ID = img.Parent.FindControl("lblID")
        Qta = img.Parent.FindControl("tbQuantita")

        Me.Session("Carrello_ArticoloId") = ID.Text
        Me.Session("Carrello_Quantita") = Qta.Text

        'Me.Session("SpedizioneGratis_Listini")
        'Me.Session("SpedizioneGratis_Data_Inizio")
        'Me.Session("SpedizioneGratis_Data_Fine")

        Me.Response.Redirect("aggiungi.aspx")

    End Sub

    Protected Sub rPromo_ItemDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.RepeaterItemEventArgs)

        Dim Offerta As Label = e.Item.FindControl("lblOfferta")
        Dim InOfferta As Label = e.Item.FindControl("lblInOfferta")

        'Salvo in session inOfferta per controllare se visualizzare o meno da articoli.aspx
        'Session("InOfferta") = InOfferta.Text

        Dim QtaMin As Label = e.Item.FindControl("lblQtaMin")
        Dim QtaMultipli As Label = e.Item.FindControl("lblMultipli")
        Dim PrezzoPromo As Label = e.Item.FindControl("lblPrezzoPromo")
        Dim PrezzoPromoIvato As Label = e.Item.FindControl("lblPrezzoPromoIvato")

        Dim dispo As Label = e.Item.Parent.Parent.FindControl("Label_dispo")
        Dim Panel_offerta As Panel = e.Item.Parent.Parent.FindControl("Panel_in_offerta")
        'Dim img_offerta As Image = e.Item.Parent.Parent.FindControl("img_offerta")
        Dim Qta As TextBox = e.Item.Parent.Parent.FindControl("tbQuantita")
        Dim ParentPrezzoPromo As Label = e.Item.Parent.Parent.FindControl("lblPrezzoPromo")
        Dim ParentPrezzo As Label = e.Item.Parent.Parent.FindControl("lblPrezzo")
        Dim ParentPrezzoIvato As Label = e.Item.Parent.Parent.FindControl("lblPrezzoIvato")

        ' ------------------------------- Prezzo con immagini ----------------------------
        Dim temp As String = ""
        Dim img_cifra9 As Image = e.Item.Parent.Parent.FindControl("img_prezzo9")
        Dim img_cifra8 As Image = e.Item.Parent.Parent.FindControl("img_prezzo8")
        Dim img_cifra7 As Image = e.Item.Parent.Parent.FindControl("img_prezzo7")
        Dim img_cifra6 As Image = e.Item.Parent.Parent.FindControl("img_prezzo6")
        Dim img_cifra5 As Image = e.Item.Parent.Parent.FindControl("img_prezzo5")
        Dim img_cifra4 As Image = e.Item.Parent.Parent.FindControl("img_prezzo4")
        Dim img_cifra3 As Image = e.Item.Parent.Parent.FindControl("img_prezzo3")
        Dim img_cifra2 As Image = e.Item.Parent.Parent.FindControl("img_prezzo2")
        Dim img_cifra1 As Image = e.Item.Parent.Parent.FindControl("img_prezzo1")
        
        img_cifra1.Visible = False
        img_cifra2.Visible = False
        img_cifra3.Visible = False
        img_cifra4.Visible = False
        img_cifra5.Visible = False
        img_cifra6.Visible = False
        img_cifra7.Visible = False
        img_cifra8.Visible = False
        img_cifra9.Visible = False


        If InOfferta.Text = 1 Then
            Panel_offerta.Visible = True
            'img_offerta.Visible = True

            If QtaMin.Text > 0 Then
                Offerta.Text = Offerta.Text & " MINIMO " & QtaMin.Text & " PZ."
                Qta.Text = QtaMin.Text
            ElseIf QtaMultipli.Text > 0 Then
                Offerta.Text = Offerta.Text & " MULTIPLI " & QtaMultipli.Text & " PZ."
                Qta.Text = QtaMultipli.Text
            End If

            If IvaTipo = 1 Then
                Offerta.Text = Offerta.Text & " A € " & FormatNumber(PrezzoPromo.Text, 2)
                ParentPrezzoPromo.Text = "€ " & FormatNumber(PrezzoPromo.Text, 2)
                ParentPrezzo.Visible = True
                ParentPrezzo.Font.Strikeout = True

                temp = ParentPrezzoPromo.Text
            ElseIf IvaTipo = 2 Then
                Offerta.Text = Offerta.Text & " A € " & FormatNumber(PrezzoPromoIvato.Text, 2)
                ParentPrezzoPromo.Text = "€ " & FormatNumber(PrezzoPromoIvato.Text, 2)
                ParentPrezzoIvato.Visible = True
                ParentPrezzoIvato.Font.Strikeout = True

                temp = ParentPrezzoPromo.Text
            End If


            Dim cifre_da_visualizzare As String = ""
            If Val(dispo.Text) > 0 Then
                cifre_da_visualizzare = "Images/cifre_ok/"
            Else
                cifre_da_visualizzare = "Images/cifre_no/"
            End If

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
        End If

        'Nascondo le Label dei prezzi
        ParentPrezzoPromo.Visible = False
        ParentPrezzo.Visible = False
        ParentPrezzoIvato.Visible = False
    End Sub

    Protected Sub Selezione_Multipla_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        Dim i As Integer = 0
        Dim temp_check As CheckBox
        Dim ListaArticoli As New ArrayList

        For i = 0 To Me.GridView1.Rows.Count - 1
            temp_check = CType(Me.GridView1.Rows(i).FindControl("CheckBox_SelezioneMultipla"), CheckBox)
            If temp_check.Checked = True Then
                Dim temp2 As GridView

                temp2 = CType(Me.GridView1.Rows(i).FindControl("GridView3"), GridView)
                If temp2.Rows.Count > 0 Then
                    'Comunico al carrello se il prodotto è un prodotto ha spedizione gratis
                    Session("ProdottoGratis") = 1
                Else
                    'Comunico al carrello se il prodotto non è un prodotto ha spedizione gratis
                    Session("ProdottoGratis") = 0
                End If

                Dim Qta As TextBox
                Dim ID As Label

                ID = Me.GridView1.Rows(i).FindControl("lblID")
                Qta = Me.GridView1.Rows(i).FindControl("tbQuantita")

                Me.Session("Carrello_ArticoloId") = ID.Text
                Me.Session("Carrello_Quantita") = Qta.Text

                ListaArticoli.Add(ID.Text & "," & Qta.Text & "," & Session("ProdottoGratis"))
            End If
        Next

        Session("Carrello_SelezioneMultipla") = ListaArticoli
        Me.Response.Redirect("aggiungi.aspx")
    End Sub

    Protected Sub BT_Rimuovi_wishlist_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand

        Dim ArticoloId As Label = sender.NamingContainer.FindControl("label_idArticolo")

        'Inserisco articolo
        cmd.Connection = conn
        cmd.CommandType = CommandType.StoredProcedure
        cmd.CommandText = "RemoveElement_Wishlist"

        cmd.Parameters.AddWithValue("?pIdUtente", Session.Item("UtentiID"))
        cmd.Parameters.AddWithValue("?pIdArticolo", ArticoloId.Text)
        cmd.ExecuteNonQuery()

        cmd.Parameters.Clear()
        cmd.Dispose()

        conn.Close()
        conn.Dispose()
    End Sub


    Protected Sub LB_cancella_tutta_wishlist_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles LB_cancella_tutta_wishlist.Click
        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand

        Dim ArticoloId As Label = sender.NamingContainer.FindControl("label_idArticolo")

        'Inserisco articolo
        cmd.Connection = conn
        cmd.CommandType = CommandType.StoredProcedure
        cmd.CommandText = "RemoveElement_All_Wishlist"

        cmd.Parameters.AddWithValue("?pIdUtente", Session.Item("UtentiID"))
        cmd.ExecuteNonQuery()

        cmd.Parameters.Clear()
        cmd.Dispose()

        conn.Close()
        conn.Dispose()
    End Sub

    Protected Sub LB_crea_html_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles LB_crea_html.Click
        Response.Redirect("mail_html_entropic.aspx?mod=1")
    End Sub
End Class
