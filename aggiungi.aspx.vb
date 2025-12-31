Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class aggiungi
    Inherits System.Web.UI.Page

    ' Dati utente per Facebook Pixel
    Public firstName As String
    Public lastName As String
    Public email As String
    Public phone As String
    Public country As String
    Public province As String
    Public city As String
    Public cap As String
    Public facebook_pixel_id As String
    Public utenteId As String = "-1"
    Public idsFbPixelsSku As New Dictionary(Of String, String)

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim articoliIdGlobali As String = String.Empty

        Dim idParam As String = Convert.ToString(Request.QueryString("id"))

        ' 1) GESTIONE COUPON
        If String.Equals(idParam, "Coupon", StringComparison.OrdinalIgnoreCase) Then
            GestisciCoupon()
            Return
        End If

        ' 2) Buono sconto (placeholder, come in origine)
        If String.Equals(idParam, "BuonoSconto", StringComparison.OrdinalIgnoreCase) Then
            ' Codice per il Buono Sconto (lasciato vuoto come nel codice originale)
        End If

        ' 3) Pagina di provenienza (non usata ora, la mantengo per compatibilità)
        Dim Pagina As String = TryCast(Me.Session("Carrello_Pagina"), String)
        If String.IsNullOrEmpty(Pagina) AndAlso Request.UrlReferrer IsNot Nothing Then
            Pagina = Request.UrlReferrer.ToString()
        End If

        ' 4) LOGICA DI AGGIUNTA AL CARRELLO
        If Me.Session("Carrello_ArticoloId") IsNot Nothing Then
            articoliIdGlobali = GestisciAggiuntaArticoli()
        End If

        ' 5) Pulizia variabili di sessione carrello temporanee
        Me.Session("Carrello_ArticoloId") = Nothing
        Me.Session("Carrello_ListaArticoloId") = Nothing
        Me.Session("Carrello_Quantita") = Nothing
        Me.Session("Carrello_Pagina") = Nothing
        Me.Session("Carrello_SelezioneMultipla") = Nothing

        ' 6) Facebook Pixel (solo se abbiamo effettivamente aggiunto qualcosa)
        If Not String.IsNullOrEmpty(articoliIdGlobali) Then
            facebook_pixel(articoliIdGlobali)
        End If

        ' 7) Redirect al carrello
        Me.Response.Redirect("carrello.aspx")
    End Sub

    ' =======================================
    '  COUPON
    ' =======================================
    Private Sub GestisciCoupon()
        ' loginId sicuro
        Dim loginId As Integer = 0
        If Session("LoginId") IsNot Nothing Then
            Integer.TryParse(Session("LoginId").ToString(), loginId)
        End If

        Dim params As New Dictionary(Of String, String)
        params.Add("@LoginId", loginId.ToString())
        params.Add("@SessionId", Session.SessionID)

        ' Svuoto il carrello dell'utente/sessione
        ExecuteDelete("carrello", "WHERE LoginId=@LoginId OR SessionId=@SessionId", params)

        ' Inserisco l'articolo coupon
        Dim paramsProcedure As New Dictionary(Of String, String)
        paramsProcedure.Add("?parLoginId", loginId.ToString())
        paramsProcedure.Add("?parSessionId", Session.SessionID)
        paramsProcedure.Add("?parArticoliId", Convert.ToString(Session("Coupon_idArticolo")))
        paramsProcedure.Add("?parCodice", Convert.ToString(Session("Coupon_codArticolo")))
        paramsProcedure.Add("?parDescrizione1", Convert.ToString(Session("Coupon_DescrizioneArticolo")))
        paramsProcedure.Add("?parQnt", Convert.ToString(Session("Coupon_Qnt_Pezzi")))
        paramsProcedure.Add("?parNListino", "1")
        paramsProcedure.Add("?parTCid", "-1")
        paramsProcedure.Add("?parPrezzo", Convert.ToString(Session("Coupon_Prezzo")))
        paramsProcedure.Add("?parPrezzoIvato", Convert.ToString(Session("Coupon_PrezzoIvato")))
        paramsProcedure.Add("?parOfferteDettaglioID", "0")
        paramsProcedure.Add("?parProdottoGratis", "0")
        ExecuteStoredProcedure("Newcarrello", paramsProcedure)

        ' Set vari ordine
        Me.Session("Ordine_TipoDoc") = Session("IdDocumentoCoupon")
        Me.Session("Ordine_Documento") = "Coupon"
        Me.Session("Ordine_Pagamento") = Session("IdPagamentoCoupon")
        Me.Session("Ordine_Vettore") = Session("Ordine_Vettore")
        Me.Session("Ordine_SpeseSped") = Session("Coupon_SpeseSpedizione")
        Me.Session("Ordine_SpeseAss") = 0
        Me.Session("Ordine_SpesePag") = 0
        Me.Session("NoteDocumento") = "Acquisto " & Session("Coupon_Qnt_Coupon") & "x Coupon - " & Session("Coupon_DescrizioneCoupon") & " - codice controllo ** " & Session("Coupon_Codice_Controllo") & " **"

        ' Reset variabili coupon
        Session("Coupon_idArticolo") = 0
        Session("Coupon_DescrizioneCoupon") = ""
        Session("Coupon_codArticolo") = 0
        Session("Coupon_DescrizioneArticolo") = ""
        Session("Coupon_Qnt_Pezzi") = 0
        Session("Coupon_Prezzo") = 0
        Session("Coupon_PrezzoIvato") = 0
        Session("Coupon_StatoPagamento") = 0
        Session("Spese_Spedizione") = 0

        Session("Ordine_DescrizioneBuonoSconto") = 0
        Session("Ordine_TotaleBuonoScontoImponibile") = 0
        Session("Ordine_CodiceBuonoSconto") = 0
        Session("Ordine_BuonoScontoIdIva") = 0
        Session("Ordine_BuonoScontoValoreIva") = 0

        Response.Redirect("ordine.aspx")
    End Sub

    ' =======================================
    '  AGGIUNTA AL CARRELLO (ARTICOLI NORMALI)
    ' =======================================
    Private Function GestisciAggiuntaArticoli() As String
        Dim articoliIdGlobali As String = String.Empty

        Dim IdRiga As Integer = 0
        Dim LoginId As Integer = 0
        Dim SessionID As String = Me.Session.SessionID

        ' LoginId sicuro
        If Me.Session("LoginId") IsNot Nothing Then
            Integer.TryParse(Me.Session("LoginId").ToString(), LoginId)
        End If

        ' Quantità base richiesta (se manca qualcosa, almeno 1)
        Dim QuantitaBase As Double = 1
        If Me.Session("Carrello_Quantita") IsNot Nothing Then
            Dim tmpQ As Double
            If Double.TryParse(Me.Session("Carrello_Quantita").ToString(), tmpQ) AndAlso tmpQ > 0 Then
                QuantitaBase = tmpQ
            End If
        End If

        ' Listino
        Dim NListino As Integer = 1
        If Me.Session("Listino") IsNot Nothing Then
            Integer.TryParse(Me.Session("Listino").ToString(), NListino)
        End If

        Dim Codice As String = ""
        Dim Descrizione As String = ""
        Dim Prezzo As Double = 0
        Dim PrezzoIvato As Double = 0
        Dim OfferteDettagliID As Integer

        Dim ArticoliId As String = Convert.ToString(Me.Session("Carrello_ArticoloId"))
        Dim TCId As String = Convert.ToString(Me.Session("Carrello_TCId"))

        Dim i As Integer
        Dim ListaArticoli As New ArrayList()
        Dim ListaTCs As New ArrayList()

        If ArticoliId = "0" Then
            ' Caso "vecchio" in cui passavi solo lista articoli
            If Me.Session("Carrello_ListaArticoloId") IsNot Nothing Then
                ListaArticoli = CType(Me.Session("Carrello_ListaArticoloId"), ArrayList)

                ' Per compatibilità: se non esiste TCId, imposto -1 per tutti
            For Each articolo As Object In ListaArticoli
            ListaTCs.Add("-1")
            Next

            End If
        ElseIf Not String.IsNullOrEmpty(ArticoliId) Then
            ListaArticoli.AddRange(ArticoliId.Split(","c))
            If Not String.IsNullOrEmpty(TCId) Then
                ListaTCs.AddRange(TCId.Split(","c))
            End If
        End If

        ' Allineo eventualmente le liste: TCId mancanti -> -1
        While ListaTCs.Count < ListaArticoli.Count
            ListaTCs.Add("-1")
        End While

        ' Selezione multipla
        Dim SelezioneMultipla As New ArrayList()
        If Session("Carrello_SelezioneMultipla") IsNot Nothing Then
            SelezioneMultipla = CType(Session("Carrello_SelezioneMultipla"), ArrayList)
        End If

        ' -------------------------
        ' CASO 1: Selezione multipla
        ' -------------------------
        If SelezioneMultipla.Count > 0 Then

            For i = 0 To SelezioneMultipla.Count - 1
                Dim parts = SelezioneMultipla(i).ToString().Split(","c)
                If parts.Length < 4 Then
                    Continue For
                End If

                Dim selezionamultipla_ID As String = parts(0)
                Dim selezionamultipla_TCID As String = parts(1)
                Dim selezionamultipla_Qta As String = parts(2)
                Dim selezionamultipla_SpedGRATIS As String = parts(3)

                Dim quantitaRiga As Double = 0

                Dim wherePart As String
                If LoginId = 0 Then
                    wherePart = "where SessionID=@SessionID"
                Else
                    wherePart = "where LoginID=@LoginId"
                    SessionID = ""
                End If
                wherePart &= " and ArticoliId=@ArticoliId and TCId=@TCId"

                Dim params As New Dictionary(Of String, String)
                params.Add("@ArticoliId", selezionamultipla_ID)
                params.Add("@TCId", selezionamultipla_TCID)
                params.Add("@SessionID", SessionID)
                params.Add("@LoginId", LoginId.ToString())

                Dim dr = ExecuteQueryGetDataReader("id, qnt", "carrello", wherePart, params)

                ' Se l'articolo è già presente nel carrello sommo la quantità
                If dr.Count > 0 Then
                    Dim row = dr(0)
                    Dim oldQ As Double = 0
                    Double.TryParse(row("qnt").ToString(), oldQ)
                    Dim newQ As Double = 0
                    Double.TryParse(selezionamultipla_Qta, newQ)
                    quantitaRiga = newQ + oldQ

                    IdRiga = CInt(row("id"))
                    params.Add("@idRiga", IdRiga.ToString())
                    ExecuteDelete("carrello", "where id=@idRiga", params)
                Else
                    Double.TryParse(selezionamultipla_Qta, quantitaRiga)
                End If

                ' Leggo prezzi e promozioni
                params.Add("@NListino", NListino.ToString())
                dr = ExecuteQueryGetDataReader("*", "vsuperarticoli", "where id=@ArticoliId and TCId=@TCId AND NListino=@NListino ORDER BY PrezzoPromo DESC", params)

                OfferteDettagliID = 0
                Prezzo = 0
                PrezzoIvato = 0

                For Each row As Dictionary(Of String, Object) In dr
                    Codice = CStr(row("Codice"))
                    Descrizione = CStr(row("Descrizione1"))
                    OfferteDettagliID = 0

                    If Prezzo = 0 Then
                        Double.TryParse(row("Prezzo").ToString(), Prezzo)
                    End If
                    If PrezzoIvato = 0 Then
                        Double.TryParse(row("PrezzoIvato").ToString(), PrezzoIvato)
                    End If

                    If CInt(row("InOfferta")) = 1 Then
                        Dim qmin As Double = 0
                        Dim multipli As Double = 0
                        Double.TryParse(row("OfferteQntMinima").ToString(), qmin)
                        Double.TryParse(row("OfferteMultipli").ToString(), multipli)

                        If quantitaRiga >= qmin AndAlso qmin > 0 Then
                            OfferteDettagliID = CInt(row("OfferteDettagliId"))
                            Double.TryParse(row("PrezzoPromo").ToString(), Prezzo)
                            Double.TryParse(row("PrezzoPromoIvato").ToString(), PrezzoIvato)
                        ElseIf multipli > 0 AndAlso quantitaRiga Mod multipli = 0 Then
                            OfferteDettagliID = CInt(row("OfferteDettagliId"))
                            Double.TryParse(row("PrezzoPromo").ToString(), Prezzo)
                            Double.TryParse(row("PrezzoPromoIvato").ToString(), PrezzoIvato)
                        End If
                    End If
                Next

                ' Inserisco articolo
                Dim paramsProcedure As New Dictionary(Of String, String)
                paramsProcedure.Add("?parLoginId", LoginId.ToString())
                paramsProcedure.Add("?parSessionId", SessionID)
                paramsProcedure.Add("?parArticoliId", selezionamultipla_ID)
                paramsProcedure.Add("?parCodice", Codice)
                paramsProcedure.Add("?parDescrizione1", Descrizione)
                paramsProcedure.Add("?parQnt", quantitaRiga.ToString().Replace(","c, "."c))
                paramsProcedure.Add("?parNListino", NListino.ToString())
                paramsProcedure.Add("?parTCId", selezionamultipla_TCID)
                paramsProcedure.Add("?parPrezzo", Prezzo.ToString().Replace(","c, "."c))
                paramsProcedure.Add("?parPrezzoIvato", PrezzoIvato.ToString().Replace(","c, "."c))
                paramsProcedure.Add("?parOfferteDettaglioID", OfferteDettagliID.ToString())
                paramsProcedure.Add("?parProdottoGratis", selezionamultipla_SpedGRATIS)
                ExecuteStoredProcedure("Newcarrello", paramsProcedure)

                AggiornaVisite(CInt(selezionamultipla_ID))

                If articoliIdGlobali <> String.Empty Then
                    articoliIdGlobali &= ","
                End If
                articoliIdGlobali &= selezionamultipla_ID
            Next

        Else
            ' -------------------------
            ' CASO 2: Articolo/i singolo/i
            ' -------------------------
            For i = 0 To ListaArticoli.Count - 1
                Dim quantitaRiga As Double = QuantitaBase

                Dim wherePart As String
                If LoginId = 0 Then
                    wherePart = "where SessionID=@SessionID"
                Else
                    wherePart = "where LoginID=@LoginId"
                    SessionID = ""
                End If

                wherePart &= " and ArticoliId=@ArticoliId and TCId=@TCId"

                Dim params As New Dictionary(Of String, String)
                params.Add("@ArticoliId", ListaArticoli(i).ToString())
                params.Add("@TCId", ListaTCs(i).ToString())
                params.Add("@SessionID", SessionID)
                params.Add("@LoginId", LoginId.ToString())

                Dim dr = ExecuteQueryGetDataReader("id, qnt", "carrello", wherePart, params)

                ' Se l'articolo è già presente nel carrello sommo la quantità
                If dr.Count > 0 Then
                    Dim row = dr(0)
                    Dim oldQ As Double = 0
                    Double.TryParse(row("qnt").ToString(), oldQ)
                    quantitaRiga = quantitaRiga + oldQ
                    IdRiga = CInt(row("id"))
                    params.Add("@idRiga", IdRiga.ToString())
                    ExecuteDelete("carrello", "where id=@idRiga", params)
                End If

                ' Leggo prezzi e promozioni
                params.Add("@NListino", NListino.ToString())
                dr = ExecuteQueryGetDataReader("*", "vsuperarticoli", "where id=@ArticoliId and TCId=@TCId AND NListino=@NListino ORDER BY PrezzoPromo DESC", params)

                OfferteDettagliID = 0
                Prezzo = 0
                PrezzoIvato = 0

                For Each row As Dictionary(Of String, Object) In dr
                    Codice = CStr(row("Codice"))
                    Descrizione = CStr(row("Descrizione1"))
                    OfferteDettagliID = 0

                    If Prezzo = 0 Then
                        Double.TryParse(row("Prezzo").ToString(), Prezzo)
                    End If
                    If PrezzoIvato = 0 Then
                        Double.TryParse(row("PrezzoIvato").ToString(), PrezzoIvato)
                    End If

                    If CInt(row("InOfferta")) = 1 Then
                        Dim qmin As Double = 0
                        Dim multipli As Double = 0
                        Double.TryParse(row("OfferteQntMinima").ToString(), qmin)
                        Double.TryParse(row("OfferteMultipli").ToString(), multipli)

                        If quantitaRiga >= qmin AndAlso qmin > 0 Then
                            OfferteDettagliID = CInt(row("OfferteDettagliId"))
                            Double.TryParse(row("PrezzoPromo").ToString(), Prezzo)
                            Double.TryParse(row("PrezzoPromoIvato").ToString(), PrezzoIvato)
                        ElseIf multipli > 0 AndAlso quantitaRiga Mod multipli = 0 Then
                            OfferteDettagliID = CInt(row("OfferteDettagliId"))
                            Double.TryParse(row("PrezzoPromo").ToString(), Prezzo)
                            Double.TryParse(row("PrezzoPromoIvato").ToString(), PrezzoIvato)
                        End If
                    End If
                Next

                ' Inserisco articolo
                Dim paramsProcedure As New Dictionary(Of String, String)
                paramsProcedure.Add("?parLoginId", LoginId.ToString())
                paramsProcedure.Add("?parSessionId", SessionID)
                paramsProcedure.Add("?parArticoliId", ListaArticoli(i).ToString())
                paramsProcedure.Add("?parTCId", ListaTCs(i).ToString())
                paramsProcedure.Add("?parCodice", Codice)
                paramsProcedure.Add("?parDescrizione1", Descrizione)
                paramsProcedure.Add("?parQnt", quantitaRiga.ToString().Replace(","c, "."c))
                paramsProcedure.Add("?parNListino", NListino.ToString())
                paramsProcedure.Add("?parPrezzo", Prezzo.ToString().Replace(","c, "."c))
                paramsProcedure.Add("?parPrezzoIvato", PrezzoIvato.ToString().Replace(","c, "."c))
                paramsProcedure.Add("?parOfferteDettaglioID", OfferteDettagliID.ToString())
                paramsProcedure.Add("?parProdottoGratis", Convert.ToString(Session("ProdottoGratis")))
                ExecuteStoredProcedure("Newcarrello", paramsProcedure)

                AggiornaVisite(CInt(ListaArticoli(i)))
                If articoliIdGlobali <> String.Empty Then
                    articoliIdGlobali &= ","
                End If
                articoliIdGlobali &= ListaArticoli(i).ToString()
            Next
        End If

        Return articoliIdGlobali
    End Function

    ' =======================================
    '  FACEBOOK PIXEL (AddToCart)
    ' =======================================
    Public Sub facebook_pixel(ByVal articoliId As String)
        ' Default: utente non identificato
        utenteId = "-1"

        ' Recupero id utente in modo sicuro
        Dim utenteIdInt As Integer = -1
        If Session("utentiid") IsNot Nothing Then
            Integer.TryParse(Session("utentiid").ToString(), utenteIdInt)
        End If

        If utenteIdInt <= -1 Then
            Exit Sub
        End If

        ' Dati utente
        Dim paramsUtente As New Dictionary(Of String, String)
        paramsUtente.Add("@id", utenteIdInt.ToString())

        Dim dr = ExecuteQueryGetDataReader("ifnull(CognomeNome,'') as CognomeNome, RagioneSociale, ifnull(email,'') as email, coalesce(case when ifnull(cellulare,'') = '' then null else cellulare end,case when ifnull(telefono,'') = '' then null else telefono end,'') as telefono, ifnull(nazione,'') as nazione, ifnull(provincia,'') as provincia, ifnull(citta,'') as citta, ifnull(cap,'') as cap", "utenti", "WHERE id = @id", paramsUtente)

        If dr.Count = 0 Then
            Exit Sub
        End If

        Dim row = dr(0)
        firstName = CStr(row("CognomeNome"))
        lastName = CStr(row("RagioneSociale"))
        email = CStr(row("email"))
        phone = CStr(row("telefono"))
        country = CStr(row("nazione"))
        province = CStr(row("provincia"))
        city = CStr(row("citta"))
        cap = CStr(row("cap"))

        utenteId = utenteIdInt.ToString()

        ' Sanitizzo la lista di articoli per la clausola IN
        Dim idList As New List(Of Integer)()
        If Not String.IsNullOrEmpty(articoliId) Then
            For Each part As String In articoliId.Split(","c)
                Dim tmp As Integer
                If Integer.TryParse(part.Trim(), tmp) AndAlso tmp > 0 Then
                    If Not idList.Contains(tmp) Then
                        idList.Add(tmp)
                    End If
                End If
            Next
        End If

        If idList.Count = 0 Then
            Exit Sub
        End If

        ' Preparo parametri per IN (@id0,@id1,...)
        Dim paramsArt As New Dictionary(Of String, String)
        paramsArt.Add("@aziendaId", Convert.ToString(Session("AziendaID")))
        Dim inParams As New List(Of String)()

        For idx As Integer = 0 To idList.Count - 1
            Dim pname As String = "@id" & idx.ToString()
            inParams.Add(pname)
            paramsArt.Add(pname, idList(idx).ToString())
        Next

        Dim wherePart As String = "Left Join ks_fb_pixel_products on ks_fb_pixel_products.id_product = articoli.id "
        wherePart &= "Left Join ks_fb_pixel on ks_fb_pixel_products.id_fb_pixel = ks_fb_pixel.id "
        wherePart &= "WHERE articoli.id in (" & String.Join(",", inParams.ToArray()) & ") "
        wherePart &= "And ks_fb_pixel.start_date<=CURDATE() "
        wherePart &= "And ks_fb_pixel.stop_date>CURDATE() "
        wherePart &= "And ks_fb_pixel.id_company = @aziendaId "
        wherePart &= "Order by ks_fb_pixel_products.id_fb_pixel"

        dr = ExecuteQueryGetDataReader("articoli.codice as sku, ks_fb_pixel.id_pixel", "articoli", wherePart, paramsArt)

        Dim oldIdFbPixel As String = String.Empty
        Dim sku As String = String.Empty

        For Each subRow As Dictionary(Of String, Object) In dr
            Dim newIdFbPixel As String = CStr(subRow("id_pixel"))

            If newIdFbPixel <> oldIdFbPixel Then
                If oldIdFbPixel <> String.Empty Then
                    idsFbPixelsSku.Add(oldIdFbPixel, sku)
                End If
                oldIdFbPixel = newIdFbPixel
                sku = String.Empty
            Else
                sku &= ","
            End If

            sku &= CStr(subRow("sku"))
        Next

        If oldIdFbPixel <> String.Empty Then
            idsFbPixelsSku.Add(oldIdFbPixel, sku)
        End If
    End Sub

    Public Sub aggiungiInCarrello()
        ' placeholder storico, lasciato per compatibilità
    End Sub

    Public Sub AggiornaVisite(ByVal ArticoliId As Integer)
        Dim lastId As Long = -1
        If Me.Session("visite_articoloid") IsNot Nothing Then
            Long.TryParse(Me.Session("visite_articoloid").ToString(), lastId)
        End If

        If ArticoliId <> lastId Then
            Me.Session("visite_articoloid") = ArticoliId
            Dim params As New Dictionary(Of String, String)
            params.Add("@id", ArticoliId.ToString())
            ExecuteUpdate("articoli", "visite=visite+1", "where id=@id", params)
        End If
    End Sub

    ' =======================================
    '  DB HELPERS
    ' =======================================
    Protected Function ExecuteDelete(ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "DELETE FROM " & table & " " & wherePart
        ExecuteNonQuery(False, sqlString, params)
    End Function

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
                Dim cmd As New MySqlCommand
                cmd.Connection = conn
                cmd.CommandText = sqlString

                If params IsNot Nothing Then
                    For Each paramName In params.Keys
                        If paramName = "?parPrezzo" OrElse paramName = "?parPrezzoIvato" Then
                            cmd.Parameters.Add(paramName, MySqlDbType.Double).Value =
                                Convert.ToDecimal(params(paramName), System.Globalization.CultureInfo.GetCultureInfo("it-IT"))
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
    End Function

    Protected Sub ExecuteStoredProcedure(ByVal storedProcedure As String, Optional ByVal params As Dictionary(Of String, String) = Nothing)
        ExecuteNonQuery(True, storedProcedure, params)
    End Sub

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

End Class
