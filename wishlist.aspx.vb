Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Configuration
Imports System.Globalization
Imports System.Web
Imports System.Collections.Generic

Partial Class wishlist
    Inherits AntiCsrfPage

    ' Connection string (MySQL)
    Private ReadOnly Property ConnectionString As String
        Get
            Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        End Get
    End Property


    Dim IvaTipo As Integer
    Dim DispoTipo As Integer
    Dim DispoMinima As Integer
    Dim InOfferta As Integer
    Private _wishlistSelectedRows As Integer = -1
    Private _wishlistBindingCompleted As Boolean = False

    Function sostituisci_caratteri_speciali(ByRef stringa As String) As String
    If stringa Is Nothing Then Return ""
    stringa = Server.UrlDecode(stringa)
    stringa = Server.HtmlDecode(stringa)
    stringa = stringa.Replace(ChrW(0), "").Trim()
    If stringa.Length > 250 Then stringa = stringa.Substring(0, 250)
    Return stringa
End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        KeepStoreSecurity.AddSecurityHeaders(Response)
        KeepStoreSecurity.RequireHttps(Request, Response, enableHsts:=True)
        If Not IsPostBack Then CartMutationIdempotencyService.ClearProgressiveRequestIds(HttpContext.Current, "wishlist:")

        ' AUTH-SESSION-EXPIRED-NOTICE-1A: senza identita (mai entrato o sessione scaduta) si va alla pagina che spiega e fa accedere, ricordando i preferiti.
        If Session("UtentiId") < 1 Then
            Session("Page") = Me.Request.Url.ToString()
            Response.Redirect("accessonegato.aspx", True)
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
        ConfigureWishlistPaging()
        BindWishlistDeterministically()
        'Analytics: logging query_string anche per GET (analytics)
        If Not IsPostBack AndAlso String.Equals(Request.HttpMethod, "GET", StringComparison.OrdinalIgnoreCase) Then
            Try
                Dim sb As New System.Text.StringBuilder()
                Dim keys() As String = New String() {"q","s","sg","st","ct","tp","gr","mr","inpromo","dispo","spedgratis"}
                For Each k As String In keys
                    Dim v As String = Convert.ToString(Request.QueryString(k))
                    If Not String.IsNullOrWhiteSpace(v) Then
                        v = sostituisci_caratteri_speciali(v)
                        If v <> "" Then
                            If sb.Length > 0 Then sb.Append(" ")
                            sb.Append(k).Append("=").Append(v)
                        End If
                    End If
                Next
                Dim qsToLog As String = sb.ToString()
                If qsToLog.Length > 0 Then
                    If qsToLog.Length > 250 Then qsToLog = qsToLog.Substring(0, 250)
                    Using connLog As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                        connLog.Open()
                        Using cmdLog As New MySqlCommand("INSERT INTO query_string (QString) VALUES (?qs)", connLog)
                            cmdLog.Parameters.Add("?qs", MySqlDbType.VarChar).Value = qsToLog
                            cmdLog.ExecuteNonQuery()
                        End Using
                    End Using
                End If
            Catch
                'No-op: analytics must never break page rendering
            End Try
        End If


    End Sub

    Private Sub ConfigureWishlistPaging()
        Dim configuredPageSize As Integer = Me.GridView1.PageSize
        Dim parsedPageSize As Integer = 0
        If Integer.TryParse(Convert.ToString(Me.Session("RigheArticoli")), parsedPageSize) AndAlso parsedPageSize > 0 Then
            configuredPageSize = parsedPageSize
        End If
        Me.GridView1.PageSize = configuredPageSize

        Dim requestedPageIndex As Integer = 0
        If Not Integer.TryParse(Convert.ToString(Me.Session("Articoli_PageIndex")), requestedPageIndex) OrElse requestedPageIndex < 0 Then
            requestedPageIndex = 0
        End If
        Me.GridView1.PageIndex = requestedPageIndex
    End Sub

    Private Sub BindWishlistDeterministically()
        If _wishlistBindingCompleted Then Return

        _wishlistSelectedRows = -1
        Me.GridView1.DataBind()

        Dim totalRows As Integer = Math.Max(0, _wishlistSelectedRows)
        Dim maxPageIndex As Integer = 0
        If totalRows > 0 Then
            maxPageIndex = (totalRows - 1) \ Me.GridView1.PageSize
        End If

        ' Una rimozione può rendere invalida l'ultima pagina salvata. In quel solo caso
        ' correggo l'indice ed eseguo l'unico rebind aggiuntivo ammesso per la request.
        If Me.GridView1.PageIndex > maxPageIndex Then
            Me.GridView1.PageIndex = maxPageIndex
            Me.Session("Articoli_PageIndex") = maxPageIndex
            _wishlistSelectedRows = -1
            Me.GridView1.DataBind()
            totalRows = Math.Max(0, _wishlistSelectedRows)
        End If

        Me.lblTrovati.Text = totalRows.ToString(CultureInfo.InvariantCulture)
        Me.phEmpty.Visible = (totalRows = 0)
        Me.phTable.Visible = (totalRows > 0)
        _wishlistBindingCompleted = True
    End Sub

    Protected Function TruncateText(ByVal testo As String, ByVal lunghezza As Integer) As String
        If testo Is Nothing Then Return ""
        Dim t As String = Convert.ToString(testo)
        If t.Length > lunghezza Then
            Return Left(t, lunghezza) & "..."
        End If
        Return t
    End Function

    Protected Function CheckImg(ByVal temp As Object) As String
        Return ThemeManager.ProductImageUrl(temp)
    End Function


Private Function GetWishlistTcidColumnName() As String
    Try
        Using conn As New MySqlConnection(ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME='wishlist' AND LOWER(COLUMN_NAME)='tcid' LIMIT 1", conn)
                Dim o As Object = cmd.ExecuteScalar()
                If o IsNot Nothing AndAlso Not Convert.IsDBNull(o) Then
                    Dim name As String = Convert.ToString(o)
                    If name IsNot Nothing Then
                        name = name.Trim()
                        If name <> "" Then Return name
                    End If
                End If
            End Using
        End Using
    Catch
        'No-op: se non ho permessi o la colonna non esiste, considero "no TC".
    End Try
    Return ""
End Function

Public Sub CaricaArticoli()
    'Utile per visualizzare i prezzi con iva dell'utente

    'La SelectCommand che viene assegnata qui sotto usa parametri (@IvaUtente, @id, @listino).
    'ATTENZIONE: alcuni FindControl ricorsivi (SeoBuilder) possono innescare il DataBind della GridView/SqlDataSource.
    'Per questo i parametri vengono definiti PRIMA del SelectCommand.
    Dim ivaUtenteStr As String = Convert.ToString(Session("Iva_Utente"))
    If String.IsNullOrWhiteSpace(ivaUtenteStr) Then ivaUtenteStr = "0"
    'MySQL accetta il punto come separatore decimale: uniformo eventuale virgola.
    ivaUtenteStr = ivaUtenteStr.Replace(",", ".")

    Dim idUtenteStr As String = Convert.ToString(Session("UtentiId"))
    If String.IsNullOrWhiteSpace(idUtenteStr) Then idUtenteStr = "0"

    Dim listinoStr As String = Convert.ToString(Session("listino"))
    If String.IsNullOrWhiteSpace(listinoStr) Then listinoStr = "0"

    'Gestione Taglie/Colori:
    ' - Se nel DB esiste wishlist.TCid (installazioni che salvano la variante), faccio JOIN e mostro taglia/colore.
    ' - Se NON esiste (schema base taikun.sql), ritorno taglia/colore vuoti senza fare join, evitando errori SQL.
    Dim tcidCol As String = GetWishlistTcidColumnName()
    Dim hasTc As Boolean = Not String.IsNullOrEmpty(tcidCol)

    Dim tcSelect As String
    If hasTc Then
        tcSelect = "taglie.descrizione AS taglia, colori.descrizione AS colore"
    Else
        tcSelect = "'' AS taglia, '' AS colore"
    End If

    ' MySQL 8 con ONLY_FULL_GROUP_BY rifiuta il vecchio GROUP BY id su ~76 colonne non aggregate (errore 1055, pagina in InternalError).
    ' Una riga completa per articolo, scelta con lo stesso criterio del catalogo (BuildCatalogRowRankSql in articoli.aspx.vb): utente e listino
    ' filtrano DENTRO la sottoquery, prima del rank; nessun MIN/MAX/ANY_VALUE su prezzi o giacenze; ordine esterno per id come col vecchio GROUP BY.
    Dim Sqlstring As String = "SELECT ks_w.* FROM (SELECT vsuperarticoli.id AS id, vsuperarticoli.Codice AS Codice, vsuperarticoli.Ean AS Ean, vsuperarticoli.Descrizione1 AS Descrizione1, vsuperarticoli.Descrizione2 AS Descrizione2, vsuperarticoli.DescrizioneLunga AS DescrizioneLunga, vsuperarticoli.UmId AS UmId, vsuperarticoli.Vetrina AS Vestrina, vsuperarticoli.MarcheId AS MarcheId, vsuperarticoli.MarcheDescrizione AS MarcheDescrizione, vsuperarticoli.Marche_img AS Marche_img, vsuperarticoli.MarcheOrdinamento AS MarcheOrdinamento, vsuperarticoli.SettoriId AS SettoriId, vsuperarticoli.SettoriDescrizione AS SettoriDescrizione, vsuperarticoli.SettoriOrdinamento AS SettoriOrdinamento, vsuperarticoli.CategorieId AS CategorieId, vsuperarticoli.CategorieDescrizione AS CategorieDescrizione, vsuperarticoli.CategorieOrdinamento AS CategorieOrdinamento, vsuperarticoli.TipologieId AS TipologieId, vsuperarticoli.TipologieDescrizione AS TipologieDescrizione, vsuperarticoli.TipologieOrdinamento AS TipologieOrdinamento, vsuperarticoli.GruppiId AS GruppiId, vsuperarticoli.GruppiDescrizione AS GruppiDescrizione, vsuperarticoli.GruppiOrdinamento AS GruppiOrdinamento, vsuperarticoli.SottoGruppiId AS SottoGruppiId, vsuperarticoli.SottogruppiDescrizione AS SottogruppiDescrizione, vsuperarticoli.SottogruppiOrdinamento AS SottogruppiOrdinamento, vsuperarticoli.ArticoliIva AS ArticoliId, vsuperarticoli.Peso AS Peso, vsuperarticoli.ArticoliPrezzoAcquisto AS ArticoliPrezzoAcquisto, vsuperarticoli.ListinoUfficiale AS ListinoUfficiale, vsuperarticoli.Img1 AS Img1, vsuperarticoli.Img2 AS Img2, vsuperarticoli.Img3 AS Img3, vsuperarticoli.Img4 AS Img4, vsuperarticoli.LinkProduttore AS LinkProduttore, vsuperarticoli.Brochure AS Brochure, vsuperarticoli.DataCreazione AS DataCreazione, vsuperarticoli.visite AS Visite, vsuperarticoli.Export AS Export, vsuperarticoli.Giacenza AS Giacenza, vsuperarticoli.InOrdine AS InOrdine, vsuperarticoli.Disponibilita AS Disponibilita, vsuperarticoli.Impegnata AS Impegnata, vsuperarticoli.ScortaMinima AS ScortaMinima, vsuperarticoli.ArticoliListiniId AS ArticoliListiniId, vsuperarticoli.NListino AS NListino, vsuperarticoli.PrezzoAcquisto AS PrezzoAcquisto, vsuperarticoli.Ricarico AS Ricarico, vsuperarticoli.sconto1 AS sconto1, vsuperarticoli.sconto2 AS sconto2, vsuperarticoli.iva AS iva, vsuperarticoli.Prezzo AS Prezzo, IF(@IvaUtente>0,((vsuperarticoli.Prezzo)*((@IvaUtente/100)+1)),vsuperarticoli.PrezzoIvato) AS PrezzoIvato, vsuperarticoli.SpedizioneGratis_Listini AS SpedizioneGratis_Listini, vsuperarticoli.SpedizioneGratis_Data_Inizio AS SpedizioneGratis_Data_Inizio, vsuperarticoli.SpedizioneGratis_Data_Fine AS SpedizioneGratis_Data_Fine, vsuperarticoli.OfferteID AS OfferteID, vsuperarticoli.OfferteDettagliId AS OfferteDettagliId, vsuperarticoli.OfferteDescrizione AS OfferteDescrizione, vsuperarticoli.OfferteImmagine AS OfferteImmagine, vsuperarticoli.OfferteDataInizio AS OfferteDataInizio, vsuperarticoli.OfferteDataFine AS OfferteDataFine, vsuperarticoli.OfferteDaListino AS OfferteDaListino, vsuperarticoli.OfferteAListino AS OfferteAListino, vsuperarticoli.OfferteQntMinima AS OfferteQntMinima, vsuperarticoli.OfferteMultipli AS OfferteMultipli, vsuperarticoli.OffertePrezzo AS OffertePrezzo, vsuperarticoli.InOfferta AS InOfferta, vsuperarticoli.PrezzoPromo AS PrezzoPromo, IF(@IvaUtente>0,((vsuperarticoli.PrezzoPromo)*((@IvaUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato) AS PrezzoPromoIvato, wishlist.id_utente, " & tcSelect & ", varticoli_iva.valore as ValoreIva, ROW_NUMBER() OVER (PARTITION BY vsuperarticoli.id ORDER BY CASE WHEN COALESCE(vsuperarticoli.TCid,0)>0 THEN 0 ELSE 1 END, COALESCE(vsuperarticoli.TCid,-1), COALESCE(vsuperarticoli.ArticoliListiniId,0), COALESCE(vsuperarticoli.OfferteDettagliId,0), wishlist.id_wishlist) AS WishlistRowRank FROM wishlist"

    Sqlstring = Sqlstring + " INNER JOIN vsuperarticoli ON (wishlist.id_articolo = vsuperarticoli.id)"

    If hasTc Then
        Sqlstring = Sqlstring + " LEFT OUTER JOIN articoli_tagliecolori ON wishlist." & tcidCol & " = articoli_tagliecolori.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"
    End If

    Sqlstring = Sqlstring + " LEFT OUTER JOIN varticoli_iva ON varticoli_iva.ArticoliId = wishlist.id_articolo"
    Sqlstring = Sqlstring + " WHERE (wishlist.id_utente=@id) AND (vsuperarticoli.NListino=@listino)) ks_w WHERE ks_w.WishlistRowRank=1 ORDER BY ks_w.id"

    sdsArticoli.SelectParameters.Clear()
    sdsArticoli.SelectParameters.Add("@IvaUtente", ivaUtenteStr)
    sdsArticoli.SelectParameters.Add("@id", idUtenteStr)
    sdsArticoli.SelectParameters.Add("@listino", listinoStr)

    sdsArticoli.SelectCommand = Sqlstring
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
        _wishlistSelectedRows = Math.Max(0, e.AffectedRows)
    End Sub

    Protected Sub GridView1_PageIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PageIndexChanged
        Session("Articoli_PageIndex") = Me.GridView1.PageIndex
    End Sub

    Protected Sub GridView1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PreRender
        Dim img, img2 As Image
        Dim dispo As Label
        Dim arrivo As Label
        Dim impegnato As Label
        Dim label_impegnato As Label
        Dim i As Integer

        For i = 0 To GridView1.Rows.Count - 1
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
        Dim btn As ImageButton = TryCast(sender, ImageButton)
        Dim row As GridViewRow = Nothing
        If btn IsNot Nothing Then
            row = TryCast(btn.NamingContainer, GridViewRow)
        End If
        If row Is Nothing Then
            Exit Sub
        End If

        Dim ID As Label = TryCast(row.FindControl("lblID"), Label)
        Dim Qta As TextBox = TryCast(row.FindControl("tbQuantita"), TextBox)
        If ID Is Nothing OrElse Qta Is Nothing Then
            Exit Sub
        End If

        Dim articleId As Integer = 0
        Dim quantity As Decimal = 0D
        If Not Integer.TryParse(ID.Text, articleId) OrElse articleId <= 0 OrElse
           Not Decimal.TryParse(Qta.Text, NumberStyles.Number, CultureInfo.GetCultureInfo("it-IT"), quantity) OrElse quantity <= 0D Then Exit Sub
        If ExecuteWishlistCartMutation(articleId, quantity, "wishlist:single:" & articleId.ToString(CultureInfo.InvariantCulture)) Then
            Response.Redirect(Request.RawUrl, False)
            Context.ApplicationInstance.CompleteRequest()
        End If

    End Sub

    ' Prezzo della scheda: lo stesso che il carrello applichera a un pezzo (vedi App_Code/KeepStoreWishlistPriceDisplay.vb).
    Protected Function WishlistPriceHtml(ByVal dataItem As Object) As String
        Return WishlistPriceDisplay.PriceHtml(UiData.Int(dataItem, "id"))
    End Function

    Protected Sub Selezione_Multipla_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        Dim i As Integer = 0
        Dim temp_check As CheckBox
        Dim batchItems As New List(Of CartStandardBatchMutationRequest)()
        Dim selectedCount As Integer = 0
        Dim invalidSelection As Boolean = False

        For i = 0 To Me.GridView1.Rows.Count - 1
            temp_check = CType(Me.GridView1.Rows(i).FindControl("CheckBox_SelezioneMultipla"), CheckBox)
            If temp_check.Checked = True Then
                selectedCount += 1
                Dim Qta As TextBox
                Dim ID As Label

                ID = Me.GridView1.Rows(i).FindControl("lblID")
                Qta = Me.GridView1.Rows(i).FindControl("tbQuantita")

                Dim articleId As Integer = 0
                Dim quantity As Decimal = 0D
                If Integer.TryParse(ID.Text, articleId) AndAlso articleId > 0 AndAlso
                   Decimal.TryParse(Qta.Text, NumberStyles.Number, CultureInfo.GetCultureInfo("it-IT"), quantity) AndAlso quantity > 0D Then
                    batchItems.Add(New CartStandardBatchMutationRequest With {
                        .ArticleId = articleId,
                        .RequestedTCId = -1,
                        .QuantityDelta = quantity
                    })
                Else
                    invalidSelection = True
                End If
            End If
        Next

        If selectedCount = 0 Then
            ShowWishlistBatchFeedback("Seleziona almeno un prodotto prima di aggiungerlo al carrello.")
            Return
        End If
        If invalidSelection OrElse selectedCount > CartMutationIdempotencyService.MaxStandardBatchItems Then
            ShowWishlistBatchFeedback("La selezione contiene dati non validi o troppi prodotti.")
            Return
        End If

        If ExecuteWishlistCartBatch(batchItems) Then
            Response.Redirect(Request.RawUrl, False)
            Context.ApplicationInstance.CompleteRequest()
        Else
            ShowWishlistBatchFeedback("I prodotti selezionati non sono stati aggiunti. Verifica disponibilità e prezzo.")
        End If
    End Sub

    Private Sub ShowWishlistBatchFeedback(ByVal message As String)
        Dim feedback As New CustomValidator() With {
            .ID = "cvWishlistBatchFeedback",
            .IsValid = False,
            .ErrorMessage = message,
            .Text = message,
            .Display = ValidatorDisplay.Dynamic,
            .CssClass = "ks-cart-message ks-cart-message-warning"
        }
        Me.phTable.Controls.AddAt(0, feedback)
    End Sub

    Protected Sub BT_Rimuovi_wishlist_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        If Not IsPostRequest() Then
            RejectNonPost()
            Exit Sub
        End If

        Dim utentiId As Integer = KeepStoreSecurity.SqlCleanInt(Session.Item("UtentiID"))
        Dim articoloId As Integer = 0
        If sender IsNot Nothing AndAlso TypeOf sender Is Control Then
            Dim ArticoloIdCtrl As Label = CType(CType(sender, Control).NamingContainer.FindControl("label_idArticolo"), Label)
            If ArticoloIdCtrl IsNot Nothing Then
                articoloId = KeepStoreSecurity.SqlCleanInt(ArticoloIdCtrl.Text)
            End If
        End If
        If utentiId <= 0 OrElse articoloId <= 0 Then
            Exit Sub
        End If

        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand



        'Inserisco articolo
        cmd.Connection = conn
        cmd.CommandType = CommandType.StoredProcedure
        cmd.CommandText = "RemoveElement_Wishlist"

        cmd.Parameters.Add("?pIdUtente", MySqlDbType.Int32).Value = utentiId
        cmd.Parameters.Add("?pIdArticolo", MySqlDbType.Int32).Value = articoloId
        cmd.ExecuteNonQuery()

        cmd.Parameters.Clear()
        cmd.Dispose()

        conn.Close()
        conn.Dispose()
    End Sub


    Protected Sub LB_cancella_tutta_wishlist_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles LB_cancella_tutta_wishlist.Click
        If Not IsPostRequest() Then
            RejectNonPost()
            Exit Sub
        End If

        Dim utentiId As Integer = KeepStoreSecurity.SqlCleanInt(Session.Item("UtentiID"))
        If utentiId <= 0 Then
            Exit Sub
        End If
        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand

        'Inserisco articolo
        cmd.Connection = conn
        cmd.CommandType = CommandType.StoredProcedure
        cmd.CommandText = "RemoveElement_All_Wishlist"

        cmd.Parameters.Add("?pIdUtente", MySqlDbType.Int32).Value = utentiId
        cmd.ExecuteNonQuery()

        cmd.Parameters.Clear()
        cmd.Dispose()

        conn.Close()
        conn.Dispose()
    End Sub

    Protected Sub LB_crea_html_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles LB_crea_html.Click
        Response.Redirect("mail_html_entropic.aspx?mod=1")
    End Sub

    ' STEP 5 - State change only via POST (anti-CSRF + hardening)
    Private Function IsPostRequest() As Boolean
        Return String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase)
    End Function

    Private Sub RejectNonPost()
        Response.StatusCode = 405
        Response.StatusDescription = "Method Not Allowed"
        Response.AddHeader("Allow", "POST")
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Function ExecuteWishlistCartMutation(ByVal articleId As Integer,
                                                 ByVal quantity As Decimal,
                                                 ByVal slotName As String) As Boolean
        Dim payload As String = CartMutationIdempotencyService.BuildStandardPayload(articleId, -1, quantity)
        Dim requestId As String = CartMutationIdempotencyService.GetOrCreateProgressiveRequestId(
            HttpContext.Current, slotName, "wishlist-add", payload)
        Dim decision As CartMutationIntentDecision = CartMutationIdempotencyService.RegisterIntent(
            HttpContext.Current, requestId, "wishlist-add", payload)
        If decision = CartMutationIntentDecision.Completed Then Return True
        If decision <> CartMutationIntentDecision.Accepted AndAlso decision <> CartMutationIntentDecision.Pending Then Return False
        decision = CartMutationIdempotencyService.BeginIntent(HttpContext.Current, requestId, "wishlist-add", payload)
        If decision = CartMutationIntentDecision.Completed Then Return True
        If decision <> CartMutationIntentDecision.Accepted Then Return False

        Dim result As CartStandardMutationResult = CartMutationService.AddStandardProductForCurrentOwner(
            HttpContext.Current, articleId, -1, quantity)
        If result Is Nothing OrElse Not result.Succeeded Then
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, requestId)
            Return False
        End If
        CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, requestId)
        Return True
    End Function

    Private Function ExecuteWishlistCartBatch(
        ByVal items As IList(Of CartStandardBatchMutationRequest)) As Boolean

        Dim normalized As List(Of CartStandardBatchMutationRequest) = Nothing
        Dim payload As String = String.Empty
        If Not CartMutationIdempotencyService.TryNormalizeStandardBatchItems(
            items, CartMutationIdempotencyService.MaxStandardBatchItems, normalized, payload) Then Return False

        Dim requestId As String = CartMutationIdempotencyService.GetOrCreateProgressiveRequestId(
            HttpContext.Current, "wishlist:multi", "wishlist-add-batch", payload)
        Dim decision As CartMutationIntentDecision = CartMutationIdempotencyService.RegisterIntent(
            HttpContext.Current, requestId, "wishlist-add-batch", payload)
        If decision = CartMutationIntentDecision.Completed Then Return True
        If decision <> CartMutationIntentDecision.Accepted AndAlso decision <> CartMutationIntentDecision.Pending Then Return False

        decision = CartMutationIdempotencyService.BeginIntent(
            HttpContext.Current, requestId, "wishlist-add-batch", payload)
        If decision = CartMutationIntentDecision.Completed Then Return True
        If decision <> CartMutationIntentDecision.Accepted Then Return False

        Dim result As CartStandardBatchMutationResult =
            CartMutationService.AddStandardProductsBatchForCurrentOwner(HttpContext.Current, items)
        If result Is Nothing OrElse Not result.Succeeded OrElse result.Items.Count = 0 Then
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, requestId)
            Return False
        End If

        CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, requestId)
        Return True
    End Function

End Class
