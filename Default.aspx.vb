Imports System.Data
Imports System.Data.Common
Imports MySql.Data.MySqlClient
Imports System.Configuration
Imports System.Web

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

        Me.Title = Me.Title & " - " & Convert.ToString(Me.Session("AziendaDescrizione"))

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
    ' ============================
    ' JSON ESCAPE
    ' ============================
    Private Function JsonEscape(ByVal s As String) As String
    If String.IsNullOrEmpty(s) Then Return ""

    ' Normalizza i fine-linea (CRLF/CR -> LF)
    Dim normalized As String = s.Replace(vbCrLf, vbLf).Replace(vbCr, vbLf)

    ' Escape robusto per stringhe JSON/JS (include caratteri di controllo)
    Dim encoded As String = System.Web.HttpUtility.JavaScriptStringEncode(normalized)

    ' Hardening minimo quando il JSON finisce in <script> (evita chiusure involontarie)
    encoded = encoded.Replace("</", "<\/")

    Return encoded
    End Function

' ============================
' COSTRUZIONE JSON-LD HOME (DINAMICO DA DB)
' ============================
    Private Function BuildHomeJsonLd(ByVal baseUrl As String, ByVal aziendaSession As String) As String
    Dim siteUrl As String = baseUrl & ResolveUrl("~/")
    Dim searchUrl As String = baseUrl & ResolveUrl("~/articoli.aspx?q={search_term_string}")
    Dim logoUrl As String = baseUrl & ResolveUrl("~/img/logo.png") ' aggiorna se necessario

    Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

    ' --- DATI AZIENDA (LocalBusiness / Organization) ---
    Dim ragioneSociale As String = aziendaSession
    Dim indirizzo As String = ""
    Dim cap As String = ""
    Dim citta As String = ""
    Dim provincia As String = ""
    Dim paese As String = ""
    Dim telefono As String = ""
    Dim email As String = ""

    Using cn As New SqlConnection(connString)
        cn.Open()
        Using cmd As New SqlCommand("SELECT TOP 1 RagioneSociale, Indirizzo, Cap, Citta, Provincia, FE_IdPaese, Telefono, Email FROM Aziende", cn)
            Using dr As SqlDataReader = cmd.ExecuteReader()
                If dr.Read() Then
                    If Not dr.IsDBNull(0) Then ragioneSociale = Convert.ToString(dr(0))
                    If Not dr.IsDBNull(1) Then indirizzo = Convert.ToString(dr(1))
                    If Not dr.IsDBNull(2) Then cap = Convert.ToString(dr(2))
                    If Not dr.IsDBNull(3) Then citta = Convert.ToString(dr(3))
                    If Not dr.IsDBNull(4) Then provincia = Convert.ToString(dr(4))
                    If Not dr.IsDBNull(5) Then paese = Convert.ToString(dr(5))
                    If Not dr.IsDBNull(6) Then telefono = Convert.ToString(dr(6))
                    If Not dr.IsDBNull(7) Then email = Convert.ToString(dr(7))
                End If
            End Using
        End Using
    End Using

    If String.IsNullOrWhiteSpace(ragioneSociale) Then ragioneSociale = aziendaSession
    If String.IsNullOrWhiteSpace(ragioneSociale) Then ragioneSociale = "Keepstore"

    Dim nameEsc As String = JsonEscape(ragioneSociale)
    Dim siteEsc As String = JsonEscape(siteUrl)
    Dim searchEsc As String = JsonEscape(searchUrl)
    Dim logoEsc As String = JsonEscape(logoUrl)
    Dim indirizzoEsc As String = JsonEscape(indirizzo)
    Dim capEsc As String = JsonEscape(cap)
    Dim cittaEsc As String = JsonEscape(citta)
    Dim provinciaEsc As String = JsonEscape(provincia)
    Dim paeseEsc As String = JsonEscape(paese)
    Dim telefonoEsc As String = JsonEscape(telefono)
    Dim emailEsc As String = JsonEscape(email)

    ' --- CATEGORIE PRINCIPALI (ItemList) ---
    Dim itemListJson As String = ""
    Using cn As New SqlConnection(connString)
        cn.Open()
        Using cmd As New SqlCommand("SELECT Descrizione, Id FROM Categorie ORDER BY Ordinamento", cn)
            Using dr As SqlDataReader = cmd.ExecuteReader()
                Dim pos As Integer = 1
                While dr.Read()
                    Dim catNome As String = If(dr.IsDBNull(0), "", Convert.ToString(dr(0)))
                    Dim catId As Integer = If(dr.IsDBNull(1), 0, Convert.ToInt32(dr(1)))

                    If Not String.IsNullOrWhiteSpace(catNome) AndAlso catId > 0 Then
                        Dim catUrl As String = siteUrl & "categoria.aspx?id=" & catId.ToString()
                        Dim catEsc As String = JsonEscape(catNome)
                        Dim catUrlEsc As String = JsonEscape(catUrl)

                        itemListJson &= "{" &
                            """@type"":""ListItem""," &
                            """position"":" & pos & "," &
                            """name"":""" & catEsc & """," &
                            """url"":""" & catUrlEsc & """" &
                        "},"

                        pos += 1
                    End If
                End While
            End Using
        End Using
    End Using
    If itemListJson.EndsWith(",") Then
        itemListJson = itemListJson.Substring(0, itemListJson.Length - 1)
    End If

    ' --- PRODOTTI (Product + Offer) ---
    Dim productsJson As String = ""
    Using cn As New SqlConnection(connString)
        cn.Open()
        Using cmd As New SqlCommand("SELECT TOP 20 id, Descrizione1, Prezzo, PrezzoScontato, Img1 FROM Articoli ORDER BY id DESC", cn)
            Using dr As SqlDataReader = cmd.ExecuteReader()
                While dr.Read()
                    Dim idArt As Integer = If(dr.IsDBNull(0), 0, Convert.ToInt32(dr(0)))
                    Dim descr As String = If(dr.IsDBNull(1), "", Convert.ToString(dr(1)))
                    Dim prezzo As Decimal = If(dr.IsDBNull(2), 0D, Convert.ToDecimal(dr(2)))
                    Dim prezzoScontato As Decimal = If(dr.IsDBNull(3), 0D, Convert.ToDecimal(dr(3)))
                    Dim img As String = If(dr.IsDBNull(4), "", Convert.ToString(dr(4)))

                    If idArt <= 0 OrElse String.IsNullOrWhiteSpace(descr) Then Continue While

                    Dim prodUrl As String = siteUrl & "articolo.aspx?id=" & idArt.ToString()
                    Dim imgUrl As String = If(String.IsNullOrWhiteSpace(img), "", siteUrl & "img/articoli/" & img)

                    Dim descrEsc As String = JsonEscape(descr)
                    Dim prodUrlEsc As String = JsonEscape(prodUrl)
                    Dim imgUrlEsc As String = JsonEscape(imgUrl)

                    ' disponibilità (somma giacenze)
                    Dim qty As Integer = 0
                    Using cn2 As New SqlConnection(connString)
                        cn2.Open()
                        Using cmd2 As New SqlCommand("SELECT ISNULL(SUM(Giacenza),0) FROM articoli_giacenze WHERE ArticoliId = @id", cn2)
                            cmd2.Parameters.AddWithValue("@id", idArt)
                            Dim o As Object = cmd2.ExecuteScalar()
                            If o IsNot Nothing AndAlso o IsNot DBNull.Value Then
                                qty = Convert.ToInt32(o)
                            End If
                        End Using
                    End Using

                    Dim availability As String = If(qty > 0, "https://schema.org/InStock", "https://schema.org/OutOfStock")
                    Dim priceToUse As Decimal = If(prezzoScontato > 0D, prezzoScontato, prezzo)
                    Dim priceStr As String = priceToUse.ToString("0.00", Globalization.CultureInfo.InvariantCulture)

                    productsJson &= "{" &
                        """@type"":""Product""," &
                        """@id"":""" & prodUrlEsc & "#product""," &
                        """name"":""" & descrEsc & """," &
                        If(String.IsNullOrWhiteSpace(imgUrlEsc), "", """image"":""" & imgUrlEsc & """,") &
                        """url"":""" & prodUrlEsc & """," &
                        """offers"":{" &
                            """@type"":""Offer""," &
                            """price"":" & """" & priceStr & """," &
                            """priceCurrency"":""EUR""," &
                            """availability"":""" & availability & """," &
                            """url"":""" & prodUrlEsc & """" &
                        "}" &
                    "},"
                End While
            End Using
        End Using
    End Using
    If productsJson.EndsWith(",") Then
        productsJson = productsJson.Substring(0, productsJson.Length - 1)
    End If

    ' --- FAQPage (statiche di esempio, personalizzabili) ---
    Dim faqs As New List(Of Tuple(Of String, String)) From {
        Tuple.Create("Come funziona la spedizione?", "Offriamo spedizioni rapide con corriere espresso in tutta Italia."),
        Tuple.Create("Posso restituire un prodotto?", "Sì, hai 14 giorni di tempo per effettuare il reso secondo le nostre condizioni."),
        Tuple.Create("Quali metodi di pagamento accettate?", "Accettiamo carte di credito, PayPal e altri metodi sicuri.")
    }

    Dim faqJson As String = ""
    For Each f In faqs
        Dim qEsc As String = JsonEscape(f.Item1)
        Dim aEsc As String = JsonEscape(f.Item2)
        faqJson &= "{" &
            """@type"":""Question""," &
            """name"":""" & qEsc & """," &
            """acceptedAnswer"":{" &
                """@type"":""Answer""," &
                """text"":""" & aEsc & """" &
            "}" &
        "},"
    Next
    If faqJson.EndsWith(",") Then
        faqJson = faqJson.Substring(0, faqJson.Length - 1)
    End If

    ' --- COSTRUZIONE FINALE @graph ---
    Dim json As String =
        "{" &
            """@context"":""https://schema.org""," &
            """@graph"":[" &

                ' ORGANIZATION
                "{" &
                    """@type"":""Organization""," &
                    """@id"":""" & siteEsc & "#org""," &
                    """name"":""" & nameEsc & """," &
                    """url"":""" & siteEsc & """," &
                    """logo"":""" & logoEsc & """" &
                "}," &

                ' LOCALBUSINESS
                "{" &
                    """@type"":""LocalBusiness""," &
                    """@id"":""" & siteEsc & "#local""," &
                    """name"":""" & nameEsc & """," &
                    """url"":""" & siteEsc & """," &
                    """image"":""" & logoEsc & """," &
                    """telephone"":""" & telefonoEsc & """," &
                    If(String.IsNullOrWhiteSpace(emailEsc), "", """email"":""" & emailEsc & """,") &
                    """address"":{" &
                        """@type"":""PostalAddress""," &
                        """streetAddress"":""" & indirizzoEsc & """," &
                        """postalCode"":""" & capEsc & """," &
                        """addressLocality"":""" & cittaEsc & """," &
                        """addressRegion"":""" & provinciaEsc & """," &
                        """addressCountry"":""" & paeseEsc & """" &
                    "}" &
                "}," &

                ' LOGO IMAGEOBJECT
                "{" &
                    """@type"":""ImageObject""," &
                    """@id"":""" & siteEsc & "#logo""," &
                    """url"":""" & logoEsc & """," &
                    """inLanguage"":""it-IT""," &
                    """contentUrl"":""" & logoEsc & """" &
                "}," &

                ' WEBSITE
                "{" &
                    """@type"":""WebSite""," &
                    """@id"":""" & siteEsc & "#website""," &
                    """name"":""" & nameEsc & """," &
                    """url"":""" & siteEsc & """," &
                    """publisher"":{""@id"":""" & siteEsc & "#org""}," &
                    """potentialAction"":{" &
                        """@type"":""SearchAction""," &
                        """target"":""" & searchEsc & """," &
                        """query-input"":""required name=search_term_string""" &
                    "}" &
                "}," &

                ' WEBPAGE
                "{" &
                    """@type"":""WebPage""," &
                    """@id"":""" & siteEsc & "#webpage""," &
                    """url"":""" & siteEsc & """," &
                    """name"":""" & nameEsc & " - Home""," &
                    """isPartOf"":{""@id"":""" & siteEsc & "#website""}," &
                    """about"":{""@id"":""" & siteEsc & "#org""}," &
                    """inLanguage"":""it-IT""" &
                "}," &

                ' BREADCRUMBLIST
                "{" &
                    """@type"":""BreadcrumbList""," &
                    """@id"":""" & siteEsc & "#breadcrumb""," &
                    """itemListElement"":[" &
                        "{" &
                            """@type"":""ListItem""," &
                            """position"":1," &
                            """name"":""Home""," &
                            """item"":""" & siteEsc & """" &
                        "}" &
                    "]" &
                "}," &

                ' ITEMLIST CATEGORIE
                "{" &
                    """@type"":""ItemList""," &
                    """@id"":""" & siteEsc & "#categories""," &
                    """name"":""Categorie principali""," &
                    """itemListElement"":[" & itemListJson & "]" &
                "}," &

                ' FAQPAGE
                "{" &
                    """@type"":""FAQPage""," &
                    """@id"":""" & siteEsc & "#faq""," &
                    """mainEntity"":[" & faqJson & "]" &
                "}," &

                ' PRODUCTS
                productsJson &

            "]" &
        "}"

    Return json
    End Function

' ============================
' INSERIMENTO JSON-LD NEL <HEAD>
' ============================
    Private Sub AddOrReplaceJsonLd(ByVal controlId As String, ByVal json As String)
    Try
        If Page Is Nothing OrElse Page.Header Is Nothing Then Exit Sub

        Dim lit As System.Web.UI.WebControls.Literal =
            TryCast(Page.Header.FindControl(controlId), System.Web.UI.WebControls.Literal)

        If lit Is Nothing Then
            Dim existing As System.Web.UI.Control = Page.Header.FindControl(controlId)
            If existing IsNot Nothing Then Page.Header.Controls.Remove(existing)

            lit = New System.Web.UI.WebControls.Literal()
            lit.ID = controlId
            lit.Mode = System.Web.UI.WebControls.LiteralMode.PassThrough
            Page.Header.Controls.Add(lit)
        End If

        If json Is Nothing Then json = ""
        json = json.Trim()

        If json.Length = 0 Then
            lit.Text = ""
            Exit Sub
        End If

        json = json.Replace("</", "<\/")

        lit.Text = "<script type=""application/ld+json"">" & json & "</script>"

    Catch
        ' Non bloccare la home
    End Try
    End Sub

' ============================
' SEO COMPLETO DELLA HOME
' ============================
    Private Sub EnsureHomeSeo()
    Try
        If Page Is Nothing OrElse Page.Header Is Nothing Then Exit Sub

        Dim baseUrl As String = Request.Url.GetLeftPart(UriPartial.Authority)
        Dim canonical As String = baseUrl & ResolveUrl("~/Default.aspx")

        AddOrReplaceCanonical(canonical)

        Dim azienda As String = Convert.ToString(Session("AziendaDescrizione")).Trim()
        If String.IsNullOrEmpty(azienda) Then azienda = "Keepstore"

        Dim descr As String =
            "Acquista online su " & azienda &
            ": nuovi arrivi, articoli in vetrina e i più venduti. Spedizioni rapide e offerte aggiornate."

        If descr.Length > 160 Then descr = descr.Substring(0, 157) & "..."

        AddOrReplaceMeta("description", descr)
        AddOrReplaceMeta("robots", "index,follow")

        Dim jsonLd As String = BuildHomeJsonLd(baseUrl, azienda)
        AddOrReplaceJsonLd("ldjson_home", jsonLd)

    Catch
        ' SEO non deve mai bloccare la pagina
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

    ' STEP6: JSON-LD realmente emesso in <head> (prima era vuoto)
    Private Sub AddOrReplaceJsonLd(ByVal controlId As String, ByVal json As String)
    Try
        If Page Is Nothing OrElse Page.Header Is Nothing Then Exit Sub

        Dim lit As System.Web.UI.WebControls.Literal = TryCast(Page.Header.FindControl(controlId), System.Web.UI.WebControls.Literal)
        If lit Is Nothing Then
            Dim existing As System.Web.UI.Control = Page.Header.FindControl(controlId)
            If existing IsNot Nothing Then Page.Header.Controls.Remove(existing)

            lit = New System.Web.UI.WebControls.Literal()
            lit.ID = controlId
            lit.Mode = System.Web.UI.WebControls.LiteralMode.PassThrough
            Page.Header.Controls.Add(lit)
        End If

        If json Is Nothing Then json = ""
        json = json.Trim()

        If json.Length = 0 Then
            lit.Text = ""
            Exit Sub
        End If

        ' hardening: evita chiusure </script> involontarie
        json = json.Replace("</", "<\/")

        lit.Text = "<script type=""application/ld+json"">" & json & "</script>"

    Catch
        ' Non bloccare la home
    End Try
    End Sub

    Private Function BuildHomeJsonLd(ByVal baseUrl As String, ByVal azienda As String) As String
    Dim siteUrl As String = baseUrl & ResolveUrl("~/")
    Dim searchUrl As String = baseUrl & ResolveUrl("~/articoli.aspx?q={search_term_string}")

    Dim nameEsc As String = JsonEscape(azienda)
    Dim siteEsc As String = JsonEscape(siteUrl)
    Dim searchEsc As String = JsonEscape(searchUrl)

    Dim json As String =
        "{" &
            """@context"":""https://schema.org""," &
            """@graph"":[" &
                "{" &
                    """@type"":""Organization""," &
                    """@id"":""" & siteEsc & "#org""," &
                    """name"":""" & nameEsc & """," &
                    """url"":""" & siteEsc & """" &
                "}," &
                "{" &
                    """@type"":""WebSite""," &
                    """@id"":""" & siteEsc & "#website""," &
                    """name"":""" & nameEsc & """," &
                    """url"":""" & siteEsc & """," &
                    """potentialAction"":{" &
                        """@type"":""SearchAction""," &
                        """target"":""" & searchEsc & """," &
                        """query-input"":""required name=search_term_string""" &
                    "}" &
                "}" &
            "]" &
        "}"

    Return json
    End Function

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

End Class
