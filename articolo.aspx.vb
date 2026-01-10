Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class Articolo
    Inherits System.Web.UI.Page

    Public IvaTipo As Integer
    Dim DispoTipo As Integer
    Dim DispoMinima As Integer
    Dim requestId As Integer
    Dim requestTCId As Integer

    Public firstName As String
    Public lastName As String
    Public email As String
    Public phone As String
    Public country As String
    Public province As String
    Public city As String
    Public cap As String
    Public facebook_pixel_id As String
    Public utenteId As String
    Public idsFbPixelsSku As New Dictionary(Of String, String)

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        Dim articoloId As String = Request.QueryString("id")

        ' Valido id e TCid: se non sono numerici rimando alla home
        If Not Integer.TryParse(articoloId, requestId) Then
            Response.Redirect("default.aspx")
        End If

        ' TCid può essere mancante o -1: in quel caso lo considero 0
        Dim tcidRaw As String = Request.QueryString("TCid")
        If Not Integer.TryParse(tcidRaw, requestTCId) Then
            requestTCId = 0
        End If

        IvaTipo = Me.Session("IvaTipo")
        DispoTipo = Me.Session("DispoTipo")
        DispoMinima = Me.Session("DispoMinima")

        'Redirect nel caso c'è la presenza di #up
        If Request.Url.AbsoluteUri.Contains("%23up") OrElse Request.Url.AbsoluteUri.Contains("#23up") Then
            Response.Redirect(Request.Url.AbsoluteUri.Replace("%23up", "").Replace("#23up", ""))
        End If

        ' Query principale per il FormView
        sdsArticolo.SelectCommand = "SELECT vsuperarticoli.id, vsuperarticoli.NoteRicondizionato, Mesi, Codice, Ean, Descrizione1, Descrizione2, SpeditoGratis, SpedizioneGratis_Data_Fine, DescrizioneIvaRC, IF(DescrizioneLunga IS NULL,'',DescrizioneLunga) AS DescrizioneLunga, IF(DescrizioneHTML IS NULL,'',DescrizioneHTML) AS DescrizioneHTML, ArticoliIva, Prezzo, " &
                                    "IF((@AbilitatoIvaReverseCharge=1) AND (ValoreIvaRC>-1), ((Prezzo)*((ValoreIvaRC/100)+1)), " &
                                    "   IF(@Iva_Utente>-1, ((Prezzo)*((@Iva_Utente/100)+1)), PrezzoIvato) " &
                                    ") AS PrezzoIvato, " &
                                    "MarcheDescrizione, Disponibilita, Giacenza, InOrdine, Impegnata, InOfferta, SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, ValoreIva, GruppiDescrizione, SottogruppiDescrizione, MarcheDescrizione, Marche_img, " &
                                    "PrezzoPromo, " &
                                    "IF((@AbilitatoIvaReverseCharge=1) AND (ValoreIvaRC>-1), ((PrezzoPromo)*((ValoreIvaRC/100)+1)), " &
                                    "   IF(@Iva_Utente>-1, ((PrezzoPromo)*((@Iva_Utente/100)+1)), PrezzoPromoIvato) " &
                                    ") AS PrezzoPromoIvato, " &
                                    "MarcheId, CategorieId, TipologieId, " &
                                    "IF(PrezzoPromo IS NULL, Prezzo, PrezzoPromo) AS Ord_PrezzoPromo, " &
                                    "IF(PrezzoPromoIvato IS NULL, PrezzoIvato, " &
                                    "   IF((@AbilitatoIvaReverseCharge=1) AND (ValoreIvaRC>-1), ((PrezzoPromo)*((ValoreIvaRC/100)+1)), " &
                                    "      IF(@Iva_Utente>-1, ((PrezzoPromo)*((@Iva_Utente/100)+1)), PrezzoPromoIvato) " &
                                    "   ) " &
                                    ") AS Ord_PrezzoPromoIvato, " &
                                    "OfferteQntMinima, OfferteMultipli, OfferteDataInizio, OfferteDataFine, " &
                                    "MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, " &
                                    "Peso, ListinoUfficiale, Brochure, LinkProduttore, IdIvaRC, Visite, vsuperarticoli.TCid, " &
                                    "IF(Ricondizionato = 1, 'visible', 'hidden') AS refurbished, " &
                                    "CONVERT(CONCAT('<table style=""width:100%;"" border=""1""><tr style=""background-color:#00FF99;""><td>Data di arrivo</td><td>Quantit&agrave;</td></tr><tr style=""background-color:#00FFFF;""><td>', " &
                                    "       GROUP_CONCAT(arrivi SEPARATOR '</td></tr><tr style=""background-color:#00FFFF;""><td>'), '</td></tr></table>'), CHAR) AS arrivi, " &
                                    "tempiconsegna.descrizione AS tempiconsegnadescrizione"

        Dim tc As Integer = 0
        If Session("TC") IsNot Nothing AndAlso Integer.TryParse(Session("TC").ToString(), tc) Then
            ' tc ottenuto da Session
        End If

        If tc = 1 Then
            sdsArticolo.SelectCommand &= ", IFNULL(immagine1, '') AS Img1, IFNULL(immagine2, '') AS Img2, IFNULL(immagine3, '') AS Img3, IFNULL(immagine4, '') AS Img4, IFNULL(immagine5, '') AS Img5, IFNULL(immagine6, '') AS Img6 FROM vsuperarticoli "
            sdsArticolo.SelectCommand &= "LEFT JOIN articoli_tagliecolori ON vsuperarticoli.TCid = articoli_tagliecolori.id "
            sdsArticolo.SelectCommand &= "LEFT JOIN immagini ON articoli_tagliecolori.immaginiId = immagini.id "
            sdsArticolo.SelectCommand &= "LEFT OUTER JOIN tempiconsegnaperlivello ON tempiconsegnaperlivello.livellitipoid = GetArticoloLivelloTipoId(vsuperarticoli.id) AND tempiconsegnaperlivello.livelloid = GetArticoloLivelloId(vsuperarticoli.id) "
            sdsArticolo.SelectCommand &= "LEFT OUTER JOIN tempiconsegna ON tempiconsegna.id = tempiconsegnaperlivello.tempiconsegnaid "
            sdsArticolo.SelectCommand &= "LEFT OUTER JOIN (SELECT articoliid, TCId, CONCAT(DATE_FORMAT(dataArrivo, '%d/%m/%Y'),'</td><td>', (TRIM(TRAILING '.' FROM(CAST(TRIM(TRAILING '0' FROM SUM(arrivi)) AS CHAR))))) AS arrivi FROM articoli_arrivi WHERE dataArrivo>NOW() AND arrivi > 0 GROUP BY dataArrivo) arrivi ON arrivi.articoliid = vsuperarticoli.id AND vsuperarticoli.TCid = arrivi.TCid "
            sdsArticolo.SelectCommand &= "WHERE vsuperarticoli.id = @requestId AND vsuperarticoli.TCid = @requestTCId "
        Else
            sdsArticolo.SelectCommand &= ", Img1, Img2, Img3, Img4 AS Img4, Img4 AS Img5, Img4 AS Img6 FROM vsuperarticoli "
            sdsArticolo.SelectCommand &= "LEFT OUTER JOIN tempiconsegnaperlivello ON tempiconsegnaperlivello.livellitipoid = GetArticoloLivelloTipoId(vsuperarticoli.id) AND tempiconsegnaperlivello.livelloid = GetArticoloLivelloId(vsuperarticoli.id) "
            sdsArticolo.SelectCommand &= "LEFT OUTER JOIN tempiconsegna ON tempiconsegna.id = tempiconsegnaperlivello.tempiconsegnaid "
            sdsArticolo.SelectCommand &= "LEFT OUTER JOIN (SELECT articoliid, CONCAT(DATE_FORMAT(dataArrivo, '%d/%m/%Y'),'</td><td>', (TRIM(TRAILING '.' FROM(CAST(TRIM(TRAILING '0' FROM SUM(arrivi)) AS CHAR))))) AS arrivi FROM articoli_arrivi WHERE dataArrivo>NOW() AND arrivi > 0 GROUP BY dataArrivo) arrivi ON arrivi.articoliid = vsuperarticoli.id "
            sdsArticolo.SelectCommand &= "WHERE vsuperarticoli.id = @requestId "
        End If

        sdsArticolo.SelectCommand &= "AND NListino = @NListino "
        sdsArticolo.SelectParameters.Clear()
        sdsArticolo.SelectParameters.Add("@AbilitatoIvaReverseCharge", Session("AbilitatoIvaReverseCharge"))
        sdsArticolo.SelectParameters.Add("@Iva_Utente", Session("Iva_Utente"))
        sdsArticolo.SelectParameters.Add("@requestId", requestId)
        sdsArticolo.SelectParameters.Add("@requestTCId", requestTCId)
        sdsArticolo.SelectParameters.Add("@NListino", Session("listino"))

        ' TAG Facebook OpenGraph
        aggiungi_tag_Facebook()

        ' Tracking BestShopping
        If Request.QueryString("comparatore") = "BESTSHOPPING" Then
            Session("Tracking_BestShopping") = 1
        End If

        ' Facebook pixel (parametrizzato, niente injection)
        facebook_pixel(requestId)

    End Sub

    Public Sub facebook_pixel(ByVal articoliId As Integer)

        If Session("utentiid") > -1 Then
            Dim params As New Dictionary(Of String, String)
            params.Add("@id", Session("utentiid"))

            ' Dati utente
            Dim dr = ExecuteQueryGetDataReader("ifnull(CognomeNome,'') as CognomeNome, RagioneSociale, ifnull(email,'') as email, coalesce(case when ifnull(cellulare,'') = '' then null else cellulare end,case when ifnull(telefono,'') = '' then null else telefono end,'') as telefono, ifnull(nazione,'') as nazione, ifnull(provincia,'') as provincia, ifnull(citta,'') as citta, ifnull(cap,'') as cap", "utenti", "WHERE id = @id", params)

            If dr.Count > 0 Then
                Dim row = dr(0)
                firstName = row("CognomeNome").ToString()
                lastName = row("RagioneSociale").ToString()
                email = row("email").ToString()
                phone = row("telefono").ToString()
                country = row("nazione").ToString()
                province = row("provincia").ToString()
                city = row("citta").ToString()
                cap = row("cap").ToString()

                Dim oldIdFbPixel As String = String.Empty
                Dim sku As String = String.Empty

                params.Add("@aziendaId", Session("AziendaID"))
                params.Add("@articoloId", articoliId.ToString())

                Dim wherePart As String = "Left Join ks_fb_pixel_products on ks_fb_pixel_products.id_product = articoli.id "
                wherePart &= "Left Join ks_fb_pixel on ks_fb_pixel_products.id_fb_pixel = ks_fb_pixel.id "
                wherePart &= "WHERE articoli.id = @articoloId And ks_fb_pixel.start_date<=CURDATE() And ks_fb_pixel.stop_date>CURDATE() And ks_fb_pixel.id_company = @aziendaId "
                wherePart &= "Order by ks_fb_pixel_products.id_fb_pixel"

                dr = ExecuteQueryGetDataReader("articoli.codice as sku, ks_fb_pixel.id_pixel", "articoli", wherePart, params)

                For Each subRow As Dictionary(Of String, Object) In dr
                    Dim newIdFbPixel As String = subRow("id_pixel").ToString()
                    If newIdFbPixel <> oldIdFbPixel Then
                        If oldIdFbPixel <> String.Empty Then
                            idsFbPixelsSku.Add(oldIdFbPixel, sku)
                        End If
                        oldIdFbPixel = newIdFbPixel
                        sku = String.Empty
                    Else
                        sku &= ","
                    End If
                    sku &= subRow("sku").ToString()
                Next

                If oldIdFbPixel <> String.Empty Then
                    idsFbPixelsSku.Add(oldIdFbPixel, sku)
                End If
            End If
        End If

    End Sub

    Public Sub aggiungi_tag_Facebook()
        Dim params As New Dictionary(Of String, String)
        params.Add("@requestId", requestId)
        params.Add("@NListino", Session("listino"))
        Dim dr = ExecuteQueryGetDataReader("*", "vsuperarticoli", "where ID=@requestId AND NListino=@NListino", params)

        If dr.Count > 0 Then
            Dim row = dr(0)

            Dim keywords As HtmlMeta = New HtmlMeta()
            keywords.Attributes("property") = "og:type"
            keywords.Content = "website"

            keywords = New HtmlMeta()
            keywords.Attributes("property") = "og:title"
            keywords.Content = row("Descrizione1").ToString()
            Page.Header.Controls.AddAt(0, keywords)

            keywords = New HtmlMeta()
            keywords.Attributes("property") = "og:image"
            keywords.Content = "http://" & Session("AziendaUrl") & "/Public/Foto/Facebook/facebook_" & row("Img1").ToString()
            Page.Header.Controls.AddAt(0, keywords)

            keywords = New HtmlMeta()
            keywords.Attributes("property") = "og:url"
            keywords.Content = Request.Url.AbsoluteUri
            Page.Header.Controls.AddAt(0, keywords)

            keywords = New HtmlMeta()
            keywords.Attributes("property") = "og:site_name"
            keywords.Content = "http://" & Session("AziendaUrl")
            Page.Header.Controls.AddAt(0, keywords)

            keywords = New HtmlMeta()
            keywords.Attributes("property") = "og:description"
            keywords.Content = row("Descrizione2").ToString()
            Page.Header.Controls.AddAt(0, keywords)
        End If
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        SettaTitolo()
        AggiornaVisite()
    End Sub

    Public Sub SettaTitolo()
        Try
            Dim lblDescrizione As Label = TryCast(Me.fvPage.FindControl("lblDescrizione"), Label)
            Dim Codice As Label = TryCast(Me.fvPage.FindControl("Label13"), Label)
            Dim EAN As Label = TryCast(Me.fvPage.FindControl("Label15"), Label)

            If lblDescrizione IsNot Nothing AndAlso Codice IsNot Nothing AndAlso EAN IsNot Nothing Then
                Me.Title = Me.Title & " > " & lblDescrizione.Text & " > Codice: " & Codice.Text & " > EAN: " & EAN.Text
            End If
        Catch ex As Exception
            ' Tanto era già in try/catch vuoto prima
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
        Dim Qta As TextBox

        Try
            PrezzoDes = CType(Me.fvPage.FindControl("lblPrezzoDes"), Label)
            Prezzo = CType(Me.fvPage.FindControl("lblPrezzo"), Label)
            PrezzoIvato = CType(Me.fvPage.FindControl("lblPrezzoIvato"), Label)
            PrezzoPromo = CType(Me.fvPage.FindControl("lblPrezzoPromo"), Label)
            Qta = CType(Me.fvPage.FindControl("tbQuantita"), TextBox)

            If IvaTipo = 1 Then
                PrezzoDes.Text = "Prezzo Iva Esclusa"
            ElseIf IvaTipo = 2 Then
                PrezzoDes.Text = "Prezzo Iva Inclusa"
            End If

            img = CType(Me.fvPage.FindControl("imgDispo"), Image)
            dispo = CType(Me.fvPage.FindControl("lblDispo"), Label)
            impegnato = CType(Me.fvPage.FindControl("lblImpegnata"), Label)
            arrivo = CType(Me.fvPage.FindControl("lblArrivo"), Label)

            If DispoTipo = 1 Then
                If dispo IsNot Nothing Then dispo.Visible = False

                If dispo IsNot Nothing AndAlso Val(dispo.Text) > DispoMinima Then
                    img.ImageUrl = "~/images/verde2.gif"
                    img.AlternateText = "Disponibile"
                ElseIf dispo IsNot Nothing AndAlso Val(dispo.Text) > 0 Then
                    img.ImageUrl = "~/images/giallo2.gif"
                    img.AlternateText = "Disponibilità Scarsa"
                Else
                    If arrivo IsNot Nothing AndAlso Val(arrivo.Text) > 0 Then
                        img.ImageUrl = "~/images/azzurro2.gif"
                        img.AlternateText = "In Arrivo"
                    Else
                        img.ImageUrl = "~/images/rosso2.gif"
                        img.AlternateText = "Non Disponibile"
                    End If
                End If

            ElseIf DispoTipo = 2 Then
                If img IsNot Nothing Then img.Visible = False
                If impegnato IsNot Nothing Then impegnato.Visible = True
                If dispo IsNot Nothing Then dispo.Visible = True
                If arrivo IsNot Nothing Then arrivo.Visible = True

                Dim lblArr As Control = Me.fvPage.FindControl("lblArr")
                Dim lblImp As Control = Me.fvPage.FindControl("lblImp")
                Dim lblPunti1 As Control = Me.fvPage.FindControl("lblPunti1")
                Dim lblPunti2 As Control = Me.fvPage.FindControl("lblPunti2")
                Dim lblPunti3 As Control = Me.fvPage.FindControl("lblPunti3")

                If lblArr IsNot Nothing Then lblArr.Visible = True
                If lblImp IsNot Nothing Then lblImp.Visible = True
                If lblPunti1 IsNot Nothing Then lblPunti1.Visible = True
                If lblPunti2 IsNot Nothing Then lblPunti2.Visible = True
                If lblPunti3 IsNot Nothing Then lblPunti3.Visible = True
            End If
        Catch
            ' Gestione come in origine: silenzio tombale
        End Try
    End Sub

    'Restituisce 1 se ci sono delle promo valide sull'articiolo altrimenti 0
    Function controlla_promo_articolo(ByVal cod_articolo As Integer, ByVal listino As Integer) As Integer
        Dim params As New Dictionary(Of String, String)
        params.Add("@cod_articolo", cod_articolo)
        params.Add("@NListino", listino)

        Dim dr = ExecuteQueryGetDataReader("id", "vsuperarticoli", "WHERE (ID=@cod_articolo AND NListino=@NListino) AND ((OfferteDataInizio <= CURDATE()) AND (OfferteDataFine >= CURDATE())) AND (InOfferta=1) ORDER BY PrezzoPromo DESC", params)

        If (dr.Count > 0) Then
            Return 1
        Else
            Return 0
        End If
    End Function

    Protected Sub fvPage_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles fvPage.PreRender
        Dim Prezzo As Label
        Dim PrezzoIvato As Label
        Dim dispo As Label

        Dim form As FormView = CType(sender, FormView)
        Dim tb_id As TextBox = CType(form.FindControl("tbID"), TextBox)
        Dim SQLDATA_Promo As SqlDataSource = CType(form.FindControl("sdsPromo"), SqlDataSource)
        Dim prezzoPromo As Label = CType(form.FindControl("lblPrezzoPromo"), Label)

        If tb_id IsNot Nothing Then
            If controlla_promo_articolo(Val(tb_id.Text), Session("listino")) = 1 Then
                ' QUERY PROMO SEMPLIFICATA: niente IF annidati su IVA, usiamo PrezzoPromo e PrezzoPromoIvato così come sono
                SQLDATA_Promo.SelectCommand =
                    "SELECT id, Codice, Ean, Descrizione1, Descrizione2, NoteRicondizionato, " &
                    "IF(DescrizioneLunga IS NULL,'',DescrizioneLunga) AS DescrizioneLunga, " &
                    "IF(DescrizioneHTML IS NULL,'',DescrizioneHTML) AS DescrizioneHTML, " &
                    "Prezzo, PrezzoIvato, Img1, MarcheDescrizione, Disponibilita, Giacenza, InOrdine, Impegnata, InOfferta, " &
                    "SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDescrizione, SottogruppiDescrizione, " &
                    "MarcheDescrizione, Marche_img, PrezzoPromo, PrezzoPromoIvato, MarcheId, CategorieId, TipologieId, " &
                    "IF(PrezzoPromo IS NULL, Prezzo, PrezzoPromo) AS Ord_PrezzoPromo, " &
                    "IF(PrezzoPromoIvato IS NULL, PrezzoIvato, PrezzoPromoIvato) AS Ord_PrezzoPromoIvato, " &
                    "OfferteQntMinima, OfferteMultipli, OfferteDataInizio, OfferteDataFine " &
                    "FROM vsuperarticoli " &
                    "WHERE ID=@TB_ID AND NListino=@NListino " &
                    "AND InOfferta=1 " &
                    "AND OfferteDataInizio <= CURDATE() AND OfferteDataFine >= CURDATE() " &
                    "ORDER BY PrezzoPromo DESC"

                SQLDATA_Promo.SelectParameters.Clear()
                SQLDATA_Promo.SelectParameters.Add("@TB_ID", tb_id.Text)
                SQLDATA_Promo.SelectParameters.Add("@NListino", Session("listino"))
            Else
                SQLDATA_Promo.SelectCommand = ""
                prezzoPromo.Visible = False
            End If

            Try
                SettaDisponibilita()
                Dim lblDes As Label = CType(Me.fvPage.FindControl("lblDescrizioneArt"), Label)
                Dim lblDesHTML As Label = CType(Me.fvPage.FindControl("lblDescrizioneHTMLArt"), Label)

                If lblDes IsNot Nothing AndAlso lblDes.Text <> "" Then
                    lblDes.Text = lblDes.Text.Replace(vbNewLine, "<br>")
                End If

                Dim ivaTipoLocale As Integer = Me.Session("IvaTipo")
                dispo = CType(Me.fvPage.FindControl("lblDispo"), Label)
                Prezzo = CType(Me.fvPage.FindControl("lblPrezzo"), Label)
                PrezzoIvato = CType(Me.fvPage.FindControl("lblPrezzoIvato"), Label)

                If ivaTipoLocale = 1 Then
                    If Prezzo IsNot Nothing Then Prezzo.Visible = True
                ElseIf ivaTipoLocale = 2 Then
                    If PrezzoIvato IsNot Nothing Then PrezzoIvato.Visible = True
                End If

                showTagliecolori()

            Catch ex As Exception
                ' Silenzio come da codice originale
            End Try
        Else
            Response.Redirect("default.aspx")
        End If
    End Sub

    Protected Sub ImageButton1_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        Dim temp As ImageButton = CType(sender, ImageButton)
        Dim temp2 As HtmlInputControl

        ' Verifica settore abilitato
        If controlla_abilitazione_settore(Me.requestId) = 1 Then
            temp2 = CType(temp.NamingContainer.FindControl("SpeditoGratis"), HtmlInputControl)
            If temp2 IsNot Nothing AndAlso temp2.Value = "1" Then
                Session("ProdottoGratis") = 1
            Else
                Session("ProdottoGratis") = 0
            End If

            Dim Qta As TextBox = CType(Me.fvPage.FindControl("tbQuantita"), TextBox)

            Me.Session("Carrello_ArticoloId") = Me.requestId
            Me.Session("Carrello_TCId") = Me.requestTCId
            Me.Session("Carrello_Quantita") = If(Qta IsNot Nothing, Qta.Text, "1")
            Me.Response.Redirect("aggiungi.aspx")
        Else
            Response.Redirect("settore_disabilitato.aspx")
        End If

    End Sub

    Public Sub AggiornaVisite()
        Dim id As Integer = Me.requestId
        Dim lastId As Long = -1
        If Me.Session("visite_articoloid") IsNot Nothing Then
            Long.TryParse(Me.Session("visite_articoloid").ToString(), lastId)
        End If

        If id <> lastId Then
            Me.Session("visite_articoloid") = id
            Dim params As New Dictionary(Of String, String)
            params.Add("@id", id)
            ExecuteUpdate("articoli", "visite=visite+1", "where id=@id", params)
        End If
    End Sub

    Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not String.IsNullOrEmpty(connectionString) Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd = New MySqlCommand With {
                    .Connection = conn,
                    .CommandType = CommandType.Text,
                    .CommandText = sqlString
                }

                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If

                If isStoredProcedure Then
                    cmd.Parameters.AddWithValue("?parRetVal", "0")
                    cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
                End If

                cmd.ExecuteNonQuery()
                cmd.Parameters.Clear()
                cmd.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
    End Function

    Protected Function ExecuteQueryGetDataReader(ByVal fields As String, ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As List(Of Dictionary(Of String, Object))
        Dim sqlString As String = "SELECT " & fields & " FROM " & table & " " & wherePart
        Dim dr As MySqlDataReader = Nothing
        Dim result As New List(Of Dictionary(Of String, Object))()
        Dim conn As New MySqlConnection

        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not String.IsNullOrEmpty(connectionString) Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd = New MySqlCommand With {
                    .Connection = conn,
                    .CommandType = CommandType.Text,
                    .CommandText = sqlString
                }

                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If

                dr = cmd.ExecuteReader()

                While dr.Read()
                    Dim row As New Dictionary(Of String, Object)()
                    For i As Integer = 0 To dr.FieldCount - 1
                        Dim columnName As String = dr.GetName(i)
                        Dim value As Object = dr.GetValue(i)
                        row.Add(columnName, value)
                    Next
                    result.Add(row)
                End While

                dr.Close()
                dr.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try

        Return result
    End Function

    Protected Sub rPromo_ItemDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.RepeaterItemEventArgs)

        Dim label_sconto As Label
        Dim panel_sconto As Panel
        Dim prezzo_canc As Label
        Dim prezzo_ivato_canc As Label

        panel_sconto = CType(e.Item.Parent.Parent.FindControl("Panel_Visualizza_Percentuale_Sconto"), Panel)
        prezzo_canc = CType(e.Item.Parent.Parent.FindControl("Label_Canc_Prezzo"), Label)
        prezzo_ivato_canc = CType(e.Item.Parent.Parent.FindControl("Label_Canc_PrezzoIvato"), Label)
        label_sconto = CType(e.Item.Parent.Parent.FindControl("sconto_applicato"), Label)

        Dim Offerta As Label = CType(e.Item.FindControl("lblOfferta"), Label)
        Dim InOfferta As Label = CType(e.Item.FindControl("lblInOfferta"), Label)
        Dim QtaMin As Label = CType(e.Item.FindControl("lblQtaMin"), Label)
        Dim QtaMultipli As Label = CType(e.Item.FindControl("lblMultipli"), Label)
        Dim PrezzoPromo As Label = CType(e.Item.FindControl("lblPrezzoPromo"), Label)
        Dim PrezzoPromoIvato As Label = CType(e.Item.FindControl("lblPrezzoPromoIvato"), Label)

        Dim Qta As TextBox = CType(e.Item.Parent.Parent.FindControl("tbQuantita"), TextBox)
        Dim ParentPrezzoPromo As Label = CType(e.Item.Parent.Parent.FindControl("lblPrezzoPromo"), Label)
        Dim ParentPrezzo As Label = CType(e.Item.Parent.Parent.FindControl("lblPrezzo"), Label)
        Dim ParentPrezzoIvato As Label = CType(e.Item.Parent.Parent.FindControl("lblPrezzoIvato"), Label)
        Dim ParentIconPromo As Image = CType(e.Item.Parent.Parent.FindControl("img_offerta"), Image)
        Dim ParentIconPromoImg As Image = CType(e.Item.Parent.Parent.FindControl("img_promo"), Image)
        Dim prezzoStandard As Label = CType(e.Item.Parent.Parent.FindControl("Label_Canc_PrezzoIvato"), Label)
        Dim lblListinoUfficiale As Label = CType(e.Item.Parent.Parent.FindControl("Label_LU"), Label)

        If InOfferta.Text = "1" Then
            ParentIconPromo.Visible = True
            ParentIconPromoImg.Visible = True

            If Val(QtaMin.Text) > 0 Then
                Offerta.Text = Offerta.Text & " MINIMO " & QtaMin.Text & " PZ."
                Qta.Text = QtaMin.Text
            ElseIf Val(QtaMultipli.Text) > 0 Then
                Offerta.Text = Offerta.Text & " MULTIPLI " & QtaMultipli.Text & " PZ."
                Qta.Text = QtaMultipli.Text
            End If

            If IvaTipo = 1 Then
                Offerta.Text = Offerta.Text & " A € " & FormatNumber(PrezzoPromo.Text, 2)
            ElseIf IvaTipo = 2 Then
                Offerta.Text = Offerta.Text & " A € " & FormatNumber(PrezzoPromoIvato.Text, 2)
            End If

            panel_sconto.Visible = True

            If IvaTipo = 1 Then
                Dim prezzoPromoDouble As Double = CDbl(FormatNumber(PrezzoPromo.Text.Replace(".", ""), 2))
                Dim prezzoParentDouble As Double = CDbl(FormatNumber(ParentPrezzo.Text.Replace(".", ""), 2))
                label_sconto.Text = "- " & String.Format("{0:0}", (prezzoParentDouble - prezzoPromoDouble) * 100 / prezzoParentDouble) & "%"
                ParentPrezzo.Text = "€ " & FormatNumber(PrezzoPromo.Text, 2)
            Else
                Dim prezzoPromoIvatoDouble As Double = CDbl(FormatNumber(PrezzoPromoIvato.Text.Replace(".", ""), 2))
                Dim prezzoStandardDouble As Double = CDbl(FormatNumber(prezzoStandard.Text.Replace(".", ""), 2))
                label_sconto.Text = "- " & String.Format("{0:0}", (prezzoStandardDouble - prezzoPromoIvatoDouble) * 100 / prezzoStandardDouble) & "%"
                ParentPrezzoIvato.Text = "€ " & FormatNumber(PrezzoPromoIvato.Text, 2)
            End If

            If Val(label_sconto.Text) = 0 Then
                label_sconto.Text = "0%"
            End If

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
        Dim img As Image = CType(sender, Image)
        Dim imageurl As String = Server.MapPath(img.ImageUrl)

        Dim temp_obj As HtmlLink = CType(Me.Page.Master.FindControl("Immagine_Facebook"), HtmlLink)
        If temp_obj IsNot Nothing Then
            temp_obj.Href = img.ImageUrl.ToString()
        End If

        Try
            Dim bmp As System.Drawing.Image = System.Drawing.Image.FromFile(imageurl)
            If bmp.Width > 400 Then
                img.Width = 400
            End If
        Catch ex As Exception
            ' Se l'immagine non esiste o dà errore, lasciamo stare
        End Try
    End Sub

    Function controlla_abilitazione_settore(ByVal idArticolo As Integer) As Integer
        Dim params As New Dictionary(Of String, String)
        params.Add("@idArticolo", idArticolo)

        Dim dr = ExecuteQueryGetDataReader("vsuperarticoli.*, settori.Descrizione, settori.Abilitato, settori.Ordinamento, settori.Predefinito, settori.Img", "vsuperarticoli", "INNER JOIN settori ON settori.id=vsuperarticoli.SettoriId WHERE (vsuperarticoli.id=@idArticolo) AND (settori.Abilitato=1)", params)

        If (dr.Count > 0) Then
            Return 1
        Else
            Return 0
        End If
    End Function

    Protected Sub LB_Dettagli_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim pulsante As LinkButton = CType(sender, LinkButton)
        Dim MV As MultiView = CType(pulsante.Parent.FindControl("Multi_Vista"), MultiView)
        MV.ActiveViewIndex = 0
    End Sub

    Protected Sub LB_ArtCollegati_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim pulsante As LinkButton = CType(sender, LinkButton)
        Dim MV As MultiView = CType(pulsante.Parent.FindControl("Multi_Vista"), MultiView)
        MV.ActiveViewIndex = 1
    End Sub

    Protected Sub LB_Recensioni_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim pulsante As LinkButton = CType(sender, LinkButton)
        Dim MV As MultiView = CType(pulsante.Parent.FindControl("Multi_Vista"), MultiView)
        MV.ActiveViewIndex = 2
    End Sub

    Protected Sub LB_NormeGaranzia_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim pulsante As LinkButton = CType(sender, LinkButton)
        Dim MV As MultiView = CType(pulsante.Parent.FindControl("Multi_Vista"), MultiView)
        MV.ActiveViewIndex = 3
    End Sub

    ' FILTRI TAGLIA COLORE

    Public Sub showTagliecolori()
        Dim list As DropDownList = CType(Me.fvPage.FindControl("Drop_Tagliecolori"), DropDownList)
        Dim tc As Integer = 0

        If Session("TC") IsNot Nothing AndAlso Integer.TryParse(Session("TC").ToString(), tc) Then
        End If

        If tc = 1 Then
            list.Visible = True
            Dim sqlString As String
            sqlString = "SELECT CONCAT_WS(' , ',taglie.descrizione, colori.descrizione , (TRIM(TRAILING '.' FROM(CAST(TRIM(TRAILING '0' FROM vsuperarticoli.Giacenza)AS char))))) AS details, TCid, ArticoliId FROM vsuperarticoli "
            sqlString &= "INNER JOIN articoli_tagliecolori ON vsuperarticoli.TCid = articoli_tagliecolori.id "
            sqlString &= "INNER JOIN taglie ON taglie.id = articoli_tagliecolori.tagliaid "
            sqlString &= "INNER JOIN colori ON colori.id = articoli_tagliecolori.coloreid "
            sqlString &= "WHERE NListino=@NListino AND ArticoliId = @ArticoliId GROUP BY TCid ORDER BY tagliaid, coloreid"

            Dim params As New Dictionary(Of String, String)
            params.Add("@NListino", Session("listino"))
            params.Add("@ArticoliId", Me.requestId)

            PopulateDropdownlist(sqlString, list, "details", "TCid", params)
            list.SelectedValue = requestTCId.ToString()
        Else
            list.Visible = False
        End If
    End Sub

    Public Sub PopulateDropdownlist(ByVal sqlString As String, ByVal list As DropDownList, ByVal textField As String, ByVal valueField As String, Optional params As Dictionary(Of String, String) = Nothing)
        Dim dt As New DataTable()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        If String.IsNullOrEmpty(connectionString) Then
            Return
        End If

        Using conn As New MySqlConnection(connectionString)
            Using cmd As MySqlCommand = conn.CreateCommand()
                cmd.CommandType = CommandType.Text
                cmd.CommandText = sqlString

                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If

                Using da As New MySqlDataAdapter(cmd)
                    conn.Open()
                    da.Fill(dt)
                End Using
            End Using
        End Using

        list.DataSource = dt
        list.DataTextField = textField
        list.DataValueField = valueField
        list.DataBind()
    End Sub

    Protected Sub Drop_Tagliecolori_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim list As DropDownList = CType(Me.fvPage.FindControl("Drop_Tagliecolori"), DropDownList)
        Response.Redirect(Request.Url.AbsolutePath & "?id=" & requestId & "&TCid=" & list.SelectedValue)
    End Sub


    ' ============================================================
    ' SEO (Scheda Prodotto)
    ' ============================================================
    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Try
            EnsureProductSeo()
        Catch
            ' no-op
        End Try
    End Sub

    Private Sub EnsureProductSeo()
        Dim canonical As String = Request.Url.GetLeftPart(UriPartial.Path)
        AddOrReplaceMeta(Me.Page, "robots", "index, follow")
        SetCanonical(Me.Page, canonical)

        Dim name As String = Nothing
        Dim sku As String = Nothing
        Dim img1 As String = Nothing
        Dim price As Decimal = 0D
        Dim hasPrice As Boolean = False
        Dim giacenza As Integer = 0

        Try
            Dim dv As System.Data.DataView = TryCast(sdsArticolo.Select(System.Web.UI.DataSourceSelectArguments.Empty), System.Data.DataView)
            If dv IsNot Nothing AndAlso dv.Count > 0 Then
                Dim r As System.Data.DataRowView = dv(0)
                name = SafeStr(r, "Descrizione1")
                sku = SafeStr(r, "Codice")
                img1 = SafeStr(r, "Img1")
                giacenza = SafeInt(r, "Giacenza")

                ' Prezzo: preferisci promo ivato, poi ivato, poi base
                If TryGetDec(r, "PrezzoPromoIvato", price) Then
                    hasPrice = True
                ElseIf TryGetDec(r, "PrezzoIvato", price) Then
                    hasPrice = True
                ElseIf TryGetDec(r, "PrezzoPromo", price) Then
                    hasPrice = True
                ElseIf TryGetDec(r, "Prezzo", price) Then
                    hasPrice = True
                End If

                If Not String.IsNullOrEmpty(name) Then
                    Page.Title = name
                    AddOrReplaceMeta(Me.Page, "description", LeftSafe(name, 155))

                    Dim jsonLd As String = BuildProductJsonLd(name, sku, img1, canonical, hasPrice, price, giacenza)
                    SetJsonLdOnMaster(Me.Page, jsonLd)
                End If
            End If
        Catch
            ' no-op
        End Try
    End Sub

    Private Shared Function BuildProductJsonLd(ByVal name As String, ByVal sku As String, ByVal img1 As String, ByVal canonical As String, ByVal hasPrice As Boolean, ByVal price As Decimal, ByVal giacenza As Integer) As String
        Dim sb As New System.Text.StringBuilder(512)
        sb.Append("{")
        sb.Append("\"@context\":\"https://schema.org\",")
        sb.Append("\"@type\":\"Product\",")
        sb.Append("\"name\":\"").Append(JsonEscape(name)).Append("\"")

        If Not String.IsNullOrEmpty(sku) Then
            sb.Append(",\"sku\":\"").Append(JsonEscape(sku)).Append("\"")
        End If

        If Not String.IsNullOrEmpty(img1) Then
            Dim imgUrl As String = ResolveImageAbsolute(img1)
            If Not String.IsNullOrEmpty(imgUrl) Then
                sb.Append(",\"image\":[\"").Append(JsonEscape(imgUrl)).Append("\"]")
            End If
        End If

        sb.Append(",\"url\":\"").Append(JsonEscape(canonical)).Append("\"")

        If hasPrice Then
            sb.Append(",\"offers\":{")
            sb.Append("\"@type\":\"Offer\",")
            sb.Append("\"priceCurrency\":\"EUR\",")
            sb.Append("\"price\":\"").Append(JsonEscape(price.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture))).Append("\",")
            Dim availability As String = If(giacenza > 0, "https://schema.org/InStock", "https://schema.org/OutOfStock")
            sb.Append("\"availability\":\"").Append(JsonEscape(availability)).Append("\"")
            sb.Append("}")
        End If

        sb.Append("}")
        Return sb.ToString()
    End Function

    Private Shared Function ResolveImageAbsolute(ByVal img1 As String) As String
        Try
            ' Path canonico progetto: ~/Public/images/articoli/
            Dim rel As String = "~/Public/images/articoli/" & img1
            Dim urlRel As String = System.Web.VirtualPathUtility.ToAbsolute(rel)

            Dim ctx As System.Web.HttpContext = System.Web.HttpContext.Current
            If ctx Is Nothing OrElse ctx.Request Is Nothing OrElse ctx.Request.Url Is Nothing Then Return urlRel

            Dim baseUrl As String = ctx.Request.Url.GetLeftPart(UriPartial.Authority)
            Return baseUrl & urlRel
        Catch
            Return ""
        End Try
    End Function

    Private Shared Function LeftSafe(ByVal s As String, ByVal maxLen As Integer) As String
        If String.IsNullOrEmpty(s) Then Return ""
        If s.Length <= maxLen Then Return s
        Return s.Substring(0, maxLen)
    End Function

    Private Shared Function SafeStr(ByVal r As System.Data.DataRowView, ByVal col As String) As String
        Try
            If r Is Nothing OrElse r.Row Is Nothing OrElse Not r.Row.Table.Columns.Contains(col) Then Return ""
            Dim v As Object = r(col)
            If v Is Nothing OrElse v Is DBNull.Value Then Return ""
            Return Convert.ToString(v)
        Catch
            Return ""
        End Try
    End Function

    Private Shared Function SafeInt(ByVal r As System.Data.DataRowView, ByVal col As String) As Integer
        Try
            Dim s As String = SafeStr(r, col)
            Dim i As Integer
            If Integer.TryParse(s, i) Then Return i
            Return 0
        Catch
            Return 0
        End Try
    End Function

    Private Shared Function TryGetDec(ByVal r As System.Data.DataRowView, ByVal col As String, ByRef value As Decimal) As Boolean
        Try
            Dim s As String = SafeStr(r, col)
            Dim d As Decimal
            If Decimal.TryParse(s, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, d) Then
                value = d
                Return True
            End If

            If Decimal.TryParse(s, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.CurrentCulture, d) Then
                value = d
                Return True
            End If

            Return False
        Catch
            Return False
        End Try
    End Function

    Private Shared Sub AddOrReplaceMeta(ByVal page As Page, ByVal metaName As String, ByVal metaContent As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim found As System.Web.UI.HtmlControls.HtmlMeta = Nothing
        For Each c As Control In page.Header.Controls
            Dim m As System.Web.UI.HtmlControls.HtmlMeta = TryCast(c, System.Web.UI.HtmlControls.HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, metaName, StringComparison.OrdinalIgnoreCase) Then
                found = m
                Exit For
            End If
        Next

        If found Is Nothing Then
            found = New System.Web.UI.HtmlControls.HtmlMeta()
            found.Name = metaName
            page.Header.Controls.Add(found)
        End If

        found.Content = metaContent
    End Sub

    Private Shared Sub SetCanonical(ByVal page As Page, ByVal canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim found As System.Web.UI.HtmlControls.HtmlLink = Nothing
        For Each c As Control In page.Header.Controls
            Dim l As System.Web.UI.HtmlControls.HtmlLink = TryCast(c, System.Web.UI.HtmlControls.HtmlLink)
            If l IsNot Nothing AndAlso String.Equals(Convert.ToString(l.Attributes("rel")), "canonical", StringComparison.OrdinalIgnoreCase) Then
                found = l
                Exit For
            End If
        Next

        If found Is Nothing Then
            found = New System.Web.UI.HtmlControls.HtmlLink()
            found.Attributes("rel") = "canonical"
            page.Header.Controls.Add(found)
        End If

        found.Href = canonicalUrl
    End Sub

    Private Shared Sub SetJsonLdOnMaster(ByVal page As Page, ByVal jsonLd As String)
        If page Is Nothing Then Exit Sub

        Dim script As String = "<script type=\"application/ld+json\">" & jsonLd & "</script>"

        Try
            If page.Master IsNot Nothing Then
                Dim lit As System.Web.UI.WebControls.Literal = TryCast(page.Master.FindControl("litSeoJsonLd"), System.Web.UI.WebControls.Literal)
                If lit IsNot Nothing Then
                    lit.Text = script
                    Exit Sub
                End If
            End If
        Catch
            ' no-op
        End Try

        Try
            If page.Header IsNot Nothing Then
                page.Header.Controls.Add(New LiteralControl(script))
            End If
        Catch
            ' no-op
        End Try
    End Sub

    Private Shared Function JsonEscape(ByVal s As String) As String
        If s Is Nothing Then Return ""
        Return System.Web.HttpUtility.JavaScriptStringEncode(s)
    End Function
End Class
