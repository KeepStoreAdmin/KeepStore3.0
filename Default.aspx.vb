Imports System
Imports System.Data
Imports System.Configuration
Imports MySql.Data.MySqlClient

Partial Class _Default
    Inherits System.Web.UI.Page

    Dim IvaTipo As Integer
    Public cont As Integer = 0
    Dim valoreIva As Integer

    Enum SqlExecutionType
        nonQuerya
        scalar
    End Enum

    ' ---------------------------
    ' Helper: conversione sicura a Integer con clamp
    ' ---------------------------
    Private Function SafeInt(ByVal o As Object, ByVal defaultValue As Integer, ByVal minValue As Integer, ByVal maxValue As Integer) As Integer
        Dim n As Integer = defaultValue
        If o IsNot Nothing Then
            Integer.TryParse(Convert.ToString(o), n)
        End If
        If n < minValue Then n = minValue
        If n > maxValue Then n = maxValue
        Return n
    End Function

    Protected Function ExecuteQueryGetScalar(ByVal fields As String,
                                             ByVal table As String,
                                             Optional ByVal wherePart As String = "",
                                             Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object

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
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try

        Return result
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        Me.Session("InOfferta") = 0

        Dim sqlString As String
        Dim sqlBaseTable As String
        Dim table1 As String
        Dim table2 As String

        ' Parametro IVA utente: uso SOLO @ivaUtente (coerenza)
        Dim prezzoIvato As String = "IF(@ivaUtente>0,((vsuperarticoli.Prezzo)*((@ivaUtente/100)+1)),vsuperarticoli.PrezzoIvato) AS PrezzoIvato"
        Dim prezzoPromoIvato As String = "IF(@ivaUtente>0,((vsuperarticoli.PrezzoPromo)*((@ivaUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato) AS PrezzoPromoIvato"
        Dim iva As String = "IF(@ivaUtente>0,@ivaUtente,iva.valore) AS iva"

        Dim vsuperarticoliFieldsAndIvaFromVsuperarticoli As String =
            "vsuperarticoli.id as Articoliid, vsuperarticoli.TCId, vsuperarticoli.Codice, vsuperarticoli.Ean, vsuperarticoli.Descrizione1, vsuperarticoli.Descrizione2, vsuperarticoli.MarcheId, vsuperarticoli.Marche_img, vsuperarticoli.SettoriId, vsuperarticoli.CategorieId, vsuperarticoli.TipologieId, vsuperarticoli.GruppiId, vsuperarticoli.SottoGruppiId, vsuperarticoli.iva as ivaId, vsuperarticoli.UmId, vsuperarticoli.ListinoUfficiale, vsuperarticoli.img1, vsuperarticoli.Prezzo, " &
            prezzoIvato & ", vsuperarticoli.PrezzoPromo, " & prezzoPromoIvato & ", vsuperarticoli.InOfferta, vsuperarticoli.speditoGratis, " & iva &
            " FROM vsuperarticoli LEFT OUTER JOIN iva ON iva.id = vsuperarticoli.iva"

        Dim tagliecoloriJoin As String =
            "AS finalTable LEFT OUTER JOIN articoli_tagliecolori ON finalTable.TCId = articoli_tagliecolori.id " &
            "LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id " &
            "LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"

        Dim id As String
        Dim vsuperarticoliId As String

        Dim TC As Integer = 0
        If Session("TC") IsNot Nothing Then
            Integer.TryParse(Session("TC").ToString(), TC)
        End If

        If TC = 1 Then
            id = "TCId"
            vsuperarticoliId = id
        Else
            id = "Articoliid"
            vsuperarticoliId = "id"
        End If

        ' Listino e IVA utente in modo robusto
        Dim listino As Integer = SafeInt(Session("Listino"), 1, 1, 9999)
        Dim ivaUtente As Integer = SafeInt(Session("Iva_Utente"), -1, -1, 9999)

        ' -------------------------------
        ' Nuovi arrivi (Repeat_Lista_Nuovi_Arrivi)
        ' -------------------------------
        Dim limitNuoviArrivi As Integer = SafeInt(Session("VetrinaArticoliUltimiArriviPuntoVendita"), 0, 0, 200) * 3

        sqlBaseTable = "(SELECT * FROM documenti WHERE tipoDocumentiid=11 OR tipoDocumentiid=22 ORDER BY id DESC LIMIT 20) AS documentibase"
        sqlBaseTable = "(SELECT articoliid, TCId FROM " & sqlBaseTable & " INNER JOIN documentirighe ON documentibase.id = documentirighe.DocumentiId GROUP BY " & id & " ORDER BY RAND()) AS articoliidTCIdTable"
        sqlBaseTable = "(SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli &
                       " INNER JOIN " & sqlBaseTable & " ON articoliidTCIdTable." & id & " = vsuperarticoli." & vsuperarticoliId &
                       " WHERE nlistino=@listino ORDER BY vsuperarticoli.PrezzoPromoIvato ASC) AS vsuperarticoliOrdered"
        table1 = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id

        If TC = 1 Then
            sqlBaseTable = "(SELECT * FROM articoli_tagliecolori ORDER BY id DESC LIMIT 20) As articolibase"
        Else
            sqlBaseTable = "(SELECT * FROM articoli ORDER BY id DESC LIMIT 20) As articolibase"
        End If

        table2 = "SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli &
                 " INNER JOIN " & sqlBaseTable & " ON articolibase.id = vsuperarticoli." & vsuperarticoliId &
                 " WHERE nlistino=@listino"

        sqlString = "SELECT * FROM (" & table1 & " UNION ALL " & table2 & ") AS united ORDER BY RAND() LIMIT " & limitNuoviArrivi.ToString()
        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        SdsNewArticoli.SelectCommand = sqlString
        SdsNewArticoli.SelectParameters.Clear()
        SdsNewArticoli.SelectParameters.Add("@listino", listino)
        SdsNewArticoli.SelectParameters.Add("@ivaUtente", ivaUtente)

        ' -------------------------------
        ' Articoli in vetrina (SdsArticoliInVetrina)
        ' -------------------------------
        Dim limitVetrina As Integer = SafeInt(Session("VetrinaArticoliImpatto"), 0, 0, 200) * 3

        sqlBaseTable =
            "(SELECT " & vsuperarticoliFieldsAndIvaFromVsuperarticoli &
            " INNER JOIN (SELECT articoli_listini.id FROM articoli_listini INNER JOIN articoli ON articoli_listini.`ArticoliId` = articoli.id " &
            "WHERE articoli_listini.`NListino` = @listino AND articoli.vetrina = 1 ORDER BY id DESC LIMIT 50) AS vsuperarticoliids " &
            "ON vsuperarticoliids.id = vsuperarticoli.`ArticoliListiniId` ORDER BY " & id & " DESC, PrezzoPromo ASC) AS vsuperarticoliOrdered"

        sqlString = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id & " ORDER BY RAND() LIMIT " & limitVetrina.ToString()
        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        SdsArticoliInVetrina.SelectCommand = sqlString
        SdsArticoliInVetrina.SelectParameters.Clear()
        SdsArticoliInVetrina.SelectParameters.Add("@listino", listino)
        SdsArticoliInVetrina.SelectParameters.Add("@ivaUtente", ivaUtente)

        ' -------------------------------
        ' Più venduti (sdsPiuAcquistati)
        ' -------------------------------
        Dim limitPiuVenduti As Integer = SafeInt(Session("VetrinaArticoliPiuVenduti"), 0, 0, 200) * 4

        sqlBaseTable =
            "(SELECT documentirighe.ArticoliId, documentirighe.TCId, COUNT(documentirighe.ArticoliId) AS Conteggio_Vendite, " &
            "DATEDIFF(CURDATE(),documenti.DataDocumento) AS Giorni " &
            "FROM documenti INNER JOIN documentirighe ON documentirighe.DocumentiId=documenti.id " &
            "WHERE articoliid>0 AND DATEDIFF(CURDATE(),documenti.DataDocumento)<15 " &
            "GROUP BY " & id & " ORDER BY conteggio_vendite DESC LIMIT 50) AS documentiTable"

        sqlBaseTable =
            "(SELECT Conteggio_Vendite, " & vsuperarticoliFieldsAndIvaFromVsuperarticoli &
            " INNER JOIN " & sqlBaseTable & " ON documentiTable." & id & "=vsuperarticoli." & vsuperarticoliId &
            " WHERE NListino=@listino ORDER BY Conteggio_vendite DESC, PrezzoPromoIvato ASC) as vsuperarticoliOrdered"

        sqlString = "SELECT * FROM " & sqlBaseTable & " GROUP BY " & id &
                    " ORDER BY conteggio_vendite DESC LIMIT " & limitPiuVenduti.ToString()
        sqlString = "SELECT *, taglie.descrizione AS taglia, colori.descrizione AS colore FROM (" & sqlString & ") " & tagliecoloriJoin

        sdsPiuAcquistati.SelectCommand = sqlString
        sdsPiuAcquistati.SelectParameters.Clear()
        sdsPiuAcquistati.SelectParameters.Add("@listino", listino)
        sdsPiuAcquistati.SelectParameters.Add("@ivaUtente", ivaUtente)

        ' -------------------------------
        ' Pubblicità (banner) - mantenuta tua logica, con AziendaID parametrico
        ' -------------------------------
        Dim DataOdierna_mod As String = Date.Today.ToString("yyyy-MM-dd")

        SqlDataSource_Pubblicita_id4_pos1.SelectCommand =
            "SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato " &
            "FROM pubblicitav2 WHERE (id_posizione_banner=4) AND (ordinamento=1) " &
            "AND ((data_inizio_pubblicazione<='" & DataOdierna_mod & "') AND (data_fine_pubblicazione>='" & DataOdierna_mod & "')) " &
            "AND ((numero_click_attuale<=limite_click) OR (limite_click=-1)) " &
            "AND ((numero_impressioni_attuale<=limite_impressioni) OR (limite_impressioni=-1)) " &
            "AND (abilitato=1) AND (id_Azienda=@AziendaID) ORDER BY id ASC LIMIT 1"
        SqlDataSource_Pubblicita_id4_pos1.SelectParameters.Clear()
        SqlDataSource_Pubblicita_id4_pos1.SelectParameters.Add("@AziendaID", SafeInt(Me.Session("AziendaID"), 0, 0, Integer.MaxValue))

        SqlDataSource_Pubblicita_id4_pos2.SelectCommand =
            "SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato " &
            "FROM pubblicitav2 WHERE (id_posizione_banner=4) And (ordinamento=2) " &
            "And ((data_inizio_pubblicazione<='" & DataOdierna_mod & "') AND (data_fine_pubblicazione>='" & DataOdierna_mod & "')) " &
            "AND ((numero_click_attuale<=limite_click) OR (limite_click=-1)) " &
            "AND ((numero_impressioni_attuale<=limite_impressioni) OR (limite_impressioni=-1)) " &
            "AND (abilitato=1) AND (id_Azienda=@AziendaID) ORDER BY id ASC LIMIT 1"
        SqlDataSource_Pubblicita_id4_pos2.SelectParameters.Clear()
        SqlDataSource_Pubblicita_id4_pos2.SelectParameters.Add("@AziendaID", SafeInt(Me.Session("AziendaID"), 0, 0, Integer.MaxValue))

        System.Diagnostics.Debug.WriteLine("end")
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender

        Me.Title = Me.Title & " - " & Convert.ToString(Me.Session("AziendaDescrizione"))

        IvaTipo = 0
        If Session("IvaTipo") IsNot Nothing Then
            Integer.TryParse(Session("IvaTipo").ToString(), IvaTipo)
        End If

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

        Dim wherePart As String =
            "where placeholder = '" & slideshowPage & "' And aziendeId = @aziendaId And abilitato = 1 And dataInizioPubblicazione<=CURDATE() And dataFinePubblicazione>CURDATE()"

        If Not slideshowVisited Then
            wherePart &= " And numeroImpressioniAttuale < limiteImpressioni"
        End If

        Dim params As New Dictionary(Of String, String)
        ' Coerenza: uso AziendaID
        params.Add("@aziendaId", Convert.ToString(Session("AziendaID")))

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
            ExecuteUpdate("slideshows", "numeroImpressioniAttuale = numeroImpressioniAttuale + 1",
                          "where placeholder = '" & slideshowPage & "' And aziendeId = @aziendaId",
                          params)
        End If

    End Sub

    Protected Function ExecuteUpdate(ByVal table As String,
                                     ByVal fieldAndValues As String,
                                     Optional ByVal wherePart As String = "",
                                     Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object

        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
        Return ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean,
                                       ByVal sqlString As String,
                                       Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object

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
                            cmd.Parameters.Add(paramName, MySqlDbType.Double).Value =
                                Convert.ToDecimal(params(paramName), System.Globalization.CultureInfo.InvariantCulture)
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
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try

        Return Nothing
    End Function

End Class
