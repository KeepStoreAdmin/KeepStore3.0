Imports MySql.Data.MySqlClient

Imports System.Data
Partial Class _Default
    Inherits System.Web.UI.Page

    Dim IvaTipo As Integer
    Public cont As Integer = 0
    Dim valoreIva As Integer

    Enum SqlExecutionType
        nonQuerya
        scalar
    End Enum

    Protected Function ExecuteQueryGetScalar(ByVal fields As String, ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
        Dim sqlString As String = "SELECT " & fields & " FROM " & table & " " & wherePart

        Dim conn As New MySqlConnection
        Dim result As Object = Nothing

        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not String.IsNullOrEmpty(connectionString) Then
                conn.ConnectionString = connectionString
                conn.Open()

                Dim cmd As New MySqlCommand With {
                    .Connection = conn,
                    .CommandText = sqlString,
                    .CommandType = CommandType.Text
                }

                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If

                result = cmd.ExecuteScalar()
                cmd.Dispose()
            End If

        Finally
            If conn.State = ConnectionState.Open Then conn.Close()
            conn.Dispose()
        End Try

        Return result
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        Me.Session("InOfferta") = 0

        Dim sqlString As String
        Dim sqlBaseTable As String
        Dim table1 As String
        Dim table2 As String

        ' NOTA SICUREZZA/BUGFIX:
        ' - Uso sempre lo stesso nome parametro @ivaUtente in tutte le espressioni (prima c'era @IvaUtente)
        Dim prezzoIvato As String = "IF(@ivaUtente>0,((vsuperarticoli.Prezzo)*((@ivaUtente/100)+1)),vsuperarticoli.PrezzoIvato) AS PrezzoIvato"
        Dim prezzoPromoIvato As String = "IF(@ivaUtente>0,((vsuperarticoli.PrezzoPromo)*((@ivaUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato) AS PrezzoPromoIvato"
        Dim iva As String = "IF(@ivaUtente>0,@ivaUtente,iva.valore) AS iva"

        Dim vsuperarticoliFieldsAndIvaFromVsuperarticoli As String =
            "vsuperarticoli.id as Articoliid, vsuperarticoli.TCId, vsuperarticoli.Codice, vsuperarticoli.Ean, vsuperarticoli.Descrizione1, vsuperarticoli.Descrizione2, " &
            "vsuperarticoli.MarcheId, vsuperarticoli.Marche_img, vsuperarticoli.SettoriId, vsuperarticoli.CategorieId, vsuperarticoli.TipologieId, vsuperarticoli.GruppiId, vsuperarticoli.SottoGruppiId, " &
            "vsuperarticoli.iva as ivaId, vsuperarticoli.UmId, vsuperarticoli.ListinoUfficiale, vsuperarticoli.img1, vsuperarticoli.Prezzo, " & prezzoIvato & ", " &
            "vsuperarticoli.PrezzoPromo, " & prezzoPromoIvato & ", vsuperarticoli.InOfferta, vsuperarticoli.speditoGratis, " & iva & " " &
            "FROM vsuperarticoli LEFT OUTER JOIN iva ON iva.id = vsuperarticoli.iva"

        Dim tagliecoloriJoin As String =
            "AS finalTable LEFT OUTER JOIN articoli_tagliecolori ON finalTable.TCId = articoli_tagliecolori.id " &
            "LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id " &
            "LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"

        Dim id As String
        Dim vsuperarticoliId As String

        Dim TC As Integer = 0
        If Session("TC") IsNot Nothing Then Integer.TryParse(Session("TC").ToString(), TC)

        If TC = 1 Then
            id = "TCId"
            vsuperarticoliId = id
        Else
            id = "Articoliid"
            vsuperarticoliId = "id"
        End If

        ' -------------------------------
        ' Nuovi arrivi (Repeat_Lista_Nuovi_Arrivi)
        ' -------------------------------
        sqlBaseTable = "(SELECT * FROM documenti WHERE tipoDocumentiid=11 OR tipoDocumentiid=22 ORDER BY id DESC LIMIT 20) AS documentibase"
        sqlBaseTable = "(SELECT articoliid, TCId FROM " & sqlBaseTable & " INNER JOIN documentirighe ON documentibase.id = documentirighe.DocumentiId GROUP BY " & id & " ORDER BY RAND()) AS articoliidTCIdTable"
        sqlBaseTable = "(SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli & " INNER JOIN " & sqlBaseTable & " ON articoliidTCIdTable." & id & " = vsuperarticoli." & vsuperarticoliId & " WHERE nlistino=@listino ORDER BY vsuperarticoli.PrezzoPromoIvato ASC) AS vsuperarticoliOrdered"

        table1 = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id

        If TC = 1 Then
            sqlBaseTable = "(SELECT * FROM articoli_tagliecolori ORDER BY id DESC LIMIT 20) As articolibase"
        Else
            sqlBaseTable = "(SELECT * FROM articoli ORDER BY id DESC LIMIT 20) As articolibase"
        End If

        table2 = "SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli & " INNER JOIN " & sqlBaseTable & " ON articolibase.id = vsuperarticoli." & vsuperarticoliId & " WHERE nlistino=@listino"

        sqlString = "SELECT * FROM (" & table1 & " UNION ALL " & table2 & ") AS united ORDER BY RAND() LIMIT " &
                    (If(Session("VetrinaArticoliUltimiArriviPuntoVendita") Is Nothing, 0, CInt(Session("VetrinaArticoliUltimiArriviPuntoVendita"))) * 3).ToString()

        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        SdsNewArticoli.SelectCommand = sqlString
        SdsNewArticoli.SelectParameters.Clear()
        SdsNewArticoli.SelectParameters.Add("@listino", Session("listino"))
        SdsNewArticoli.SelectParameters.Add("@ivaUtente", Session("Iva_Utente"))

        ' -------------------------------
        ' Articoli in vetrina (SdsArticoliInVetrina)
        ' -------------------------------
        sqlBaseTable = "(SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli &
                       " INNER JOIN (SELECT articoli_listini.id FROM articoli_listini INNER JOIN articoli ON articoli_listini.`ArticoliId` = articoli.id " &
                       "WHERE articoli_listini.`NListino` = @listino AND articoli.vetrina = 1 ORDER BY id DESC LIMIT 50) AS vsuperarticoliids " &
                       "ON vsuperarticoliids.id = vsuperarticoli.`ArticoliListiniId` ORDER BY " & id & " DESC, PrezzoPromo ASC) AS vsuperarticoliOrdered"

        sqlString = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id & " ORDER BY RAND() LIMIT " &
                    (If(Session("VetrinaArticoliImpatto") Is Nothing, 0, CInt(Session("VetrinaArticoliImpatto"))) * 3).ToString()

        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        SdsArticoliInVetrina.SelectCommand = sqlString
        SdsArticoliInVetrina.SelectParameters.Clear()
        SdsArticoliInVetrina.SelectParameters.Add("@listino", Session("listino"))
        SdsArticoliInVetrina.SelectParameters.Add("@ivaUtente", Session("Iva_Utente"))

        ' -------------------------------
        ' Più venduti (sdsPiuAcquistati)
        ' -------------------------------
        sqlBaseTable = "(SELECT documentirighe.ArticoliId, documentirighe.TCId, COUNT(documentirighe.ArticoliId) AS Conteggio_Vendite, " &
                       "DATEDIFF(CURDATE(),documenti.DataDocumento) AS Giorni " &
                       "FROM documenti INNER JOIN documentirighe ON documentirighe.DocumentiId=documenti.id " &
                       "WHERE articoliid>0 AND DATEDIFF(CURDATE(),documenti.DataDocumento)<15 " &
                       "GROUP BY " & id & " ORDER BY conteggio_vendite DESC LIMIT 50) AS documentiTable"

        sqlBaseTable = "(SELECT Conteggio_Vendite, " & vsuperarticoliFieldsAndIvaFromVsuperarticoli & " INNER JOIN " & sqlBaseTable & " ON documentiTable." & id & "=vsuperarticoli." & vsuperarticoliId & " WHERE NListino=@listino ORDER BY Conteggio_vendite DESC, PrezzoPromoIvato ASC) as vsuperarticoliOrdered"

        sqlString = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id & " ORDER BY conteggio_vendite DESC LIMIT " &
                    (If(Session("VetrinaArticoliPiuVenduti") Is Nothing, 0, CInt(Session("VetrinaArticoliPiuVenduti"))) * 4).ToString()

        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        sdsPiuAcquistati.SelectCommand = sqlString
        sdsPiuAcquistati.SelectParameters.Clear()
        sdsPiuAcquistati.SelectParameters.Add("@listino", Session("listino"))
        sdsPiuAcquistati.SelectParameters.Add("@ivaUtente", Session("Iva_Utente"))

        ' -------------------------------
        ' Pubblicità (banner)
        ' -------------------------------
        ' NOTA SICUREZZA/BUGFIX:
        ' - Evito di concatenare la data dentro SQL (anche se è server-side) e uso un parametro @DataOdierna.
        Dim DataOdierna_mod As String = Date.Today.ToString("yyyy-MM-dd")

        SqlDataSource_Pubblicita_id4_pos1.SelectCommand =
            "SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato " &
            "FROM pubblicitav2 WHERE (id_posizione_banner=4) AND (ordinamento=1) " &
            "AND ((data_inizio_pubblicazione<=@DataOdierna) AND (data_fine_pubblicazione>=@DataOdierna)) " &
            "AND ((numero_click_attuale<=limite_click) OR (limite_click=-1)) " &
            "AND ((numero_impressioni_attuale<=limite_impressioni) OR (limite_impressioni=-1)) " &
            "AND (abilitato=1) AND (id_Azienda=@AziendaID) ORDER BY id ASC LIMIT 1"

        SqlDataSource_Pubblicita_id4_pos1.SelectParameters.Clear()
        SqlDataSource_Pubblicita_id4_pos1.SelectParameters.Add("@AziendaID", Me.Session("AziendaID"))
        SqlDataSource_Pubblicita_id4_pos1.SelectParameters.Add("@DataOdierna", DataOdierna_mod)

        SqlDataSource_Pubblicita_id4_pos2.SelectCommand =
            "SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato " &
            "FROM pubblicitav2 WHERE (id_posizione_banner=4) And (ordinamento=2) " &
            "And ((data_inizio_pubblicazione<=@DataOdierna) AND (data_fine_pubblicazione>=@DataOdierna)) " &
            "AND ((numero_click_attuale<=limite_click) OR (limite_click=-1)) " &
            "AND ((numero_impressioni_attuale<=limite_impressioni) OR (limite_impressioni=-1)) " &
            "AND (abilitato=1) AND (id_Azienda=@AziendaID) ORDER BY id ASC LIMIT 1"

        SqlDataSource_Pubblicita_id4_pos2.SelectParameters.Clear()
        SqlDataSource_Pubblicita_id4_pos2.SelectParameters.Add("@AziendaID", Me.Session("AziendaID"))
        SqlDataSource_Pubblicita_id4_pos2.SelectParameters.Add("@DataOdierna", DataOdierna_mod)

        System.Diagnostics.Debug.WriteLine("end")
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender


        IvaTipo = 0
        If Session("IvaTipo") IsNot Nothing Then Integer.TryParse(Session("IvaTipo").ToString(), IvaTipo)

        If IvaTipo = 1 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Esclusa"
        ElseIf IvaTipo = 2 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Inclusa"
        End If

        ' Gestione slideshow impression
        Dim slideshowPage As String = "defaultPage"
        Dim slideshowVisited As Boolean = True

        Dim slideshowsVisited As List(Of String) = TryCast(Session("slideshows"), List(Of String))
        If slideshowsVisited Is Nothing OrElse Not slideshowsVisited.Contains(slideshowPage) Then
            slideshowVisited = False
        End If

        ' STEP6: placeholder parametrizzato (niente concatenazioni)
        Dim wherePart As String = "where placeholder = @placeholder And aziendeId = @aziendaId And abilitato = 1 And dataInizioPubblicazione<=CURDATE() And dataFinePubblicazione>CURDATE()"
        If Not slideshowVisited Then
            wherePart &= " And numeroImpressioniAttuale < limiteImpressioni"
        End If

        Dim params As New Dictionary(Of String, String)
        ' NOTA: uso la chiave di sessione coerente con il resto del sito
        params.Add("@aziendaId", Convert.ToString(Session("AziendaID")))
        params.Add("@placeholder", slideshowPage)

        Dim slideshows As Object = ExecuteQueryGetScalar("COUNT(*)", "slideshows", wherePart, params)
        Dim slideshowsCount As Integer = 0
        If slideshows IsNot Nothing AndAlso Integer.TryParse(slideshows.ToString(), slideshowsCount) Then
        End If

        If slideshowsCount = 0 Then
            Slide_Show_Container.Visible = False
        Else
            Slide_Show_Container.Visible = True

            If slideshowsVisited Is Nothing Then
                slideshowsVisited = New List(Of String) From {slideshowPage}
            ElseIf Not slideshowsVisited.Contains(slideshowPage) Then
                slideshowsVisited.Add(slideshowPage)
            End If

            Session("slideshows") = slideshowsVisited

            ExecuteUpdate("slideshows", "numeroImpressioniAttuale = numeroImpressioniAttuale + 1", "where placeholder = @placeholder And aziendeId = @aziendaId", params)
        End If

        ' SEO (Home)
        EnsureHomeSeo()


    End Sub

    Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
        Return ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object

        Dim conn As New MySqlConnection

        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not String.IsNullOrEmpty(connectionString) Then
                conn.ConnectionString = connectionString
                conn.Open()

                Dim cmd As New MySqlCommand With {
                    .Connection = conn,
                    .CommandText = sqlString
                }

                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        If paramName = "?parPrezzo" OrElse paramName = "?parPrezzoIvato" Then
                            cmd.Parameters.Add(paramName, MySqlDbType.Double).Value = Convert.ToDecimal(params(paramName), System.Globalization.CultureInfo.InvariantCulture)
                        Else
                            cmd.Parameters.AddWithValue(paramName, params(paramName))
                        End If
                    Next
                End If

                If isStoredProcedure Then
                    cmd.CommandType = CommandType.StoredProcedure
                    cmd.Parameters.AddWithValue("?parRetVal", "0")
                    cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
                Else
                    cmd.CommandType = CommandType.Text
                End If

                cmd.ExecuteNonQuery()
                cmd.Dispose()
            End If

        Finally
            If conn.State = ConnectionState.Open Then conn.Close()
            conn.Dispose()
        End Try

        Return Nothing
    End Function

    ' ==========================================================
    ' SEO / AI-READINESS (HOME)
    ' ==========================================================
' ============================================================
' SEO / JSON-LD (HOME)
' ============================================================
Private Sub EnsureHomeSeo()
    Try
        Dim baseUrl As String = Request.Url.GetLeftPart(UriPartial.Authority)
        Dim canonical As String = baseUrl & ResolveUrl("~/")
        If Not canonical.EndsWith("/") Then canonical &= "/"

        Dim azienda As String = SafeSessionString("AziendaNome", "TAIKUN.IT")

        Dim descr As String = SafeSessionString("AziendaDescrizione", "")
        If String.IsNullOrWhiteSpace(descr) Then
    descr = "E-commerce " & azienda & ": informatica, telefonia, periferiche, consumabili e accessori. Scopri offerte e nuovi arrivi con disponibilità aggiornata."
End If
        ' Versione breve per meta/OG/Twitter (evita descrizioni troppo lunghe)
        Dim descrMeta As String = descr.Replace(ControlChars.Cr, " ").Replace(ControlChars.Lf, " ").Trim()
        If descrMeta.Length > 170 Then descrMeta = descrMeta.Substring(0, 167) & "..."

        Dim pageTitle As String = azienda & " | Informatica, Telefonia, Periferiche e Consumabili"
        Me.Title = pageTitle

        ' Meta standard
        AddOrReplaceMeta("description", descrMeta)
        AddOrReplaceMetaName("robots", "index,follow,max-snippet:-1,max-image-preview:large,max-video-preview:-1")
        AddOrReplaceCanonical(canonical)

        ' Open Graph
        AddOrReplaceMetaProperty("og:type", "website")
        AddOrReplaceMetaProperty("og:locale", "it_IT")
        AddOrReplaceMetaProperty("og:site_name", azienda)
        AddOrReplaceMetaProperty("og:title", pageTitle)
        AddOrReplaceMetaProperty("og:description", descrMeta)
        AddOrReplaceMetaProperty("og:url", canonical)

        ' Twitter
        AddOrReplaceMetaName("twitter:title", pageTitle)
        AddOrReplaceMetaName("twitter:description", descrMeta)

        ' Immagine (logo/og)
        Dim imageUrl As String = SafeSessionString("AziendaOgImage", "")
        If String.IsNullOrWhiteSpace(imageUrl) Then
            imageUrl = SafeSessionString("AziendaLogo", "")
        End If

        If Not String.IsNullOrWhiteSpace(imageUrl) Then
            ' Normalizza URL assoluto
            If Not (imageUrl.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse imageUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase)) Then
                If imageUrl.StartsWith("~/") OrElse imageUrl.StartsWith("/") Then
                    imageUrl = baseUrl & ResolveUrl(imageUrl)
                Else
                    imageUrl = baseUrl & ResolveUrl("~/" & imageUrl.TrimStart("/"c))
                End If
            End If

            AddOrReplaceMetaProperty("og:image", imageUrl)
            AddOrReplaceMetaProperty("og:image:alt", azienda)
            AddOrReplaceMetaName("twitter:card", "summary_large_image")
            AddOrReplaceMetaName("twitter:image", imageUrl)
        Else
            AddOrReplaceMetaName("twitter:card", "summary")
        End If

        ' JSON-LD @graph (SeoBuilder avanzato)
        Dim logoUrl As String = SafeSessionString("AziendaLogo", "")
        If Not String.IsNullOrWhiteSpace(logoUrl) Then
            If Not (logoUrl.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse logoUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase)) Then
                If logoUrl.StartsWith("~/") OrElse logoUrl.StartsWith("/") Then
                    logoUrl = baseUrl & ResolveUrl(logoUrl)
                Else
                    logoUrl = baseUrl & ResolveUrl("~/" & logoUrl.TrimStart("/"c))
                End If
            End If
        End If

        Dim jsonLdScript As String = SeoBuilder.BuildHomeJsonLd(Me, pageTitle, descr, canonical, logoUrl)
        SeoBuilder.SetJsonLdOnMaster(Me, jsonLdScript)

    Catch
        ' Fail-safe: non bloccare il rendering della home per errori SEO
    End Try
End Sub

    Private Sub AddOrReplaceCanonical(ByVal href As String)
        Dim toRemove As New System.Collections.Generic.List(Of System.Web.UI.Control)()

        For Each c As System.Web.UI.Control In Page.Header.Controls
            Dim lnk As System.Web.UI.HtmlControls.HtmlLink = TryCast(c, System.Web.UI.HtmlControls.HtmlLink)
            If lnk IsNot Nothing Then
                Dim rel As String = Convert.ToString(lnk.Attributes("rel"))
                If Not String.IsNullOrEmpty(rel) AndAlso String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    toRemove.Add(c)
                End If
            End If
        Next

        For Each c As System.Web.UI.Control In toRemove
            Page.Header.Controls.Remove(c)
        Next

        Dim hl As New System.Web.UI.HtmlControls.HtmlLink()
        hl.Attributes("rel") = "canonical"
        hl.Href = href
        Page.Header.Controls.Add(hl)
    End Sub

    Private Sub AddOrReplaceMeta(ByVal name As String, ByVal content As String)
        Dim toRemove As New System.Collections.Generic.List(Of System.Web.UI.Control)()

        For Each c As System.Web.UI.Control In Page.Header.Controls
            Dim m As System.Web.UI.HtmlControls.HtmlMeta = TryCast(c, System.Web.UI.HtmlControls.HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, name, StringComparison.OrdinalIgnoreCase) Then
                toRemove.Add(c)
            End If
        Next

        For Each c As System.Web.UI.Control In toRemove
            Page.Header.Controls.Remove(c)
        Next

        Dim meta As New System.Web.UI.HtmlControls.HtmlMeta()
        meta.Name = name
        meta.Content = content
        Page.Header.Controls.Add(meta)
    End Sub


' ------------------------------------------------------------
' Helpers
' ------------------------------------------------------------
Private Function SafeSessionString(ByVal key As String, ByVal fallback As String) As String
    Try
        If Session IsNot Nothing AndAlso Session(key) IsNot Nothing Then
            Dim s As String = Convert.ToString(Session(key))
            If Not String.IsNullOrEmpty(s) Then Return s
        End If
    Catch
    End Try
    Return fallback
End Function

Private Sub AddOrReplaceMetaName(ByVal metaName As String, ByVal content As String)
    If Page Is Nothing OrElse Page.Header Is Nothing Then Return
    If String.IsNullOrEmpty(metaName) Then Return

    ' Remove existing <meta name="...">
    For i As Integer = Page.Header.Controls.Count - 1 To 0 Step -1
        Dim hm As HtmlMeta = TryCast(Page.Header.Controls(i), HtmlMeta)
        If hm IsNot Nothing Then
            If (Not String.IsNullOrEmpty(hm.Name)) AndAlso hm.Name.Equals(metaName, StringComparison.OrdinalIgnoreCase) Then
                Page.Header.Controls.RemoveAt(i)
            End If
        End If
    Next

    Dim m As New HtmlMeta()
    m.Name = metaName
    m.Content = If(content, "")
    Page.Header.Controls.Add(m)
End Sub

Private Sub AddOrReplaceMetaProperty(ByVal propertyName As String, ByVal content As String)
    If Page Is Nothing OrElse Page.Header Is Nothing Then Return
    If String.IsNullOrEmpty(propertyName) Then Return

    ' Remove existing <meta property="...">
    For i As Integer = Page.Header.Controls.Count - 1 To 0 Step -1
        Dim hm As HtmlMeta = TryCast(Page.Header.Controls(i), HtmlMeta)
        If hm IsNot Nothing Then
            Dim prop As String = Nothing
            If hm.Attributes IsNot Nothing Then prop = hm.Attributes("property")
            If (Not String.IsNullOrEmpty(prop)) AndAlso prop.Equals(propertyName, StringComparison.OrdinalIgnoreCase) Then
                Page.Header.Controls.RemoveAt(i)
            End If
        End If
    Next

    Dim m As New HtmlMeta()
    m.Attributes("property") = propertyName
    m.Content = If(content, "")
    Page.Header.Controls.Add(m)
End Sub


    ' STEP6: JSON-LD realmente emesso in <head> (prima era vuoto)

    ' ===========================
    ' BANNER HOME: Impression tracking (sicuro, parametrizzato)
    ' ===========================
    Private ReadOnly _pubblicitaImpressionDedup As New System.Collections.Generic.HashSet(Of Integer)()

    Protected Sub RepeaterPubblicita_id4_pos1_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e Is Nothing OrElse e.Item Is Nothing Then Exit Sub
        If e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem Then Exit Sub

        Dim idPub As Integer = 0
        Dim objId As Object = DataBinder.Eval(e.Item.DataItem, "id")
        If objId IsNot Nothing Then Integer.TryParse(objId.ToString(), idPub)

        If idPub > 0 Then IncrementPubblicitaImpression(idPub)
    End Sub

    Protected Sub RepeaterPubblicita_id4_pos2_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e Is Nothing OrElse e.Item Is Nothing Then Exit Sub
        If e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem Then Exit Sub

        Dim idPub As Integer = 0
        Dim objId As Object = DataBinder.Eval(e.Item.DataItem, "id")
        If objId IsNot Nothing Then Integer.TryParse(objId.ToString(), idPub)

        If idPub > 0 Then IncrementPubblicitaImpression(idPub)
    End Sub

    Private Sub IncrementPubblicitaImpression(ByVal idPubblicita As Integer)
        Try
            If idPubblicita <= 0 Then Exit Sub
            If _pubblicitaImpressionDedup.Contains(idPubblicita) Then Exit Sub

            _pubblicitaImpressionDedup.Add(idPubblicita)

            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Using conn As New MySqlConnection(cs)
                conn.Open()

                Dim sql As String =
                    "UPDATE pubblicitaV2 SET numero_impressioni_attuale = numero_impressioni_attuale + 1 " &
                    "WHERE (id=@id) AND (abilitato=1) " &
                    "AND ((limite_impressioni IS NULL) OR (limite_impressioni=0) OR (numero_impressioni_attuale < limite_impressioni))"

                Using cmd As New MySqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@id", idPubblicita)
                    cmd.ExecuteNonQuery()
                End Using
            End Using

        Catch
            ' Non bloccare la pagina home per tracking impression
        End Try
    End Sub

    ' Risolve in modo robusto i percorsi immagini provenienti dal DB
    Protected Function ResolveMediaUrl(rawPath As Object, defaultFolderInPublic As String) As String
        Dim p As String = If(rawPath Is Nothing, "", rawPath.ToString().Trim())

        If String.IsNullOrEmpty(p) Then Return ""

        ' URL assoluto
        If p.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse p.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return p
        End If

        ' Già in formato ASP.NET
        If p.StartsWith("~/") Then
            Return ResolveUrl(p)
        End If

        ' Path assoluto sito (/Public/..., /Images/...)
        If p.StartsWith("/") Then
            Return ResolveUrl("~" & p)
        End If

        ' Path relativo già completo
        If p.StartsWith("Public/", StringComparison.OrdinalIgnoreCase) OrElse p.StartsWith("Images/", StringComparison.OrdinalIgnoreCase) Then
            Return ResolveUrl("~/" & p)
        End If

        ' Solo filename: lo metto nella cartella standard
        Dim folder As String = defaultFolderInPublic.Trim("/"c)
        Return ResolveUrl("~/Public/" & folder & "/" & p.TrimStart("/"c))
    End Function



    '==========================================================
    ' HOME - Settori (Dipartimenti): URL compatibile legacy (webaffare.it)
    '==========================================================
    Protected Function BuildSettoreUrl(ByVal settoreIdObj As Object, ByVal defaultCtObj As Object, ByVal defaultTpObj As Object) As String
        Dim settoreId As Integer = 0
        Integer.TryParse(Convert.ToString(settoreIdObj), settoreId)

        Dim ct As Integer = 0
        Integer.TryParse(Convert.ToString(defaultCtObj), ct)

        Dim tp As Integer = 0
        Integer.TryParse(Convert.ToString(defaultTpObj), tp)

        If settoreId <= 0 Then
            Return ResolveUrl("~/articoli.aspx")
        End If

        Dim url As String = ResolveUrl("~/articoli.aspx") & "?st=" & settoreId.ToString()

        If ct > 0 Then
            url &= "&ct=" & ct.ToString()
        End If

        If tp > 0 Then
            url &= "&tp=" & tp.ToString()
        End If

        Return url
    End Function



'==========================================================
' HOME: URL helper per Settori (st/ct/tp) - template-first
'==========================================================



End Class
