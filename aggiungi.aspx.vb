Imports MySql.Data.MySqlClient
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Text.RegularExpressions
Imports System.Web

Partial Class aggiungi
    Inherits AntiCsrfPage


' =========================
' HELPERS (safe redirect)
' =========================
Private Sub SafeRedirect(ByVal url As String)
    Try
        Response.Redirect(url, False)
        Context.ApplicationInstance.CompleteRequest()
    Catch
    End Try
End Sub


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

    Private Function IsValidPixelId(ByVal pixelId As String) As Boolean
        If String.IsNullOrEmpty(pixelId) Then Return False
        Return Regex.IsMatch(pixelId, "^\d{5,20}$")
    End Function



    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim articoliIdGlobali As String = String.Empty

        Dim idParam As String = Convert.ToString(Request.QueryString("id"))

        If idParam Is Nothing Then idParam = ""
        idParam = idParam.Trim()

        ' 1) GESTIONE COUPON
        If String.Equals(idParam, "Coupon", StringComparison.OrdinalIgnoreCase) Then
            GestisciCoupon()
            Return
        End If

        ' 2) Buono sconto (placeholder, come in origine)
        If String.Equals(idParam, "BuonoSconto", StringComparison.OrdinalIgnoreCase) Then
            ' Codice per il Buono Sconto (lasciato vuoto come nel codice originale)
        End If

' 2b) GESTIONE GROUPON (coupon esterno)
        If String.Equals(idParam, "groupon", StringComparison.OrdinalIgnoreCase) Then
    Dim idArt As String = Convert.ToString(Session("Groupon_idArticolo"))
    If String.IsNullOrEmpty(idArt) Then
        SafeRedirect("carrello_groupon.aspx")
        Return
    End If

    Session("Carrello_ArticoloId") = idArt
    Session("Carrello_Quantita") = 1
    Session("Carrello_SelezioneMultipla") = Nothing
End If

        ' 2c) Compatibilita legacy: alcuni punti storici chiamano ancora
        ' aggiungi.aspx?id=123&TCid=-1&qty=1 senza passare da cart_add.aspx.
        If Me.Session("Carrello_ArticoloId") Is Nothing Then
            Dim directId As Integer = 0
            If Integer.TryParse(idParam, directId) AndAlso directId > 0 Then
                Dim directTc As Integer = -1
                Integer.TryParse(Convert.ToString(Request.QueryString("TCid")), directTc)
                If directTc <= 0 Then directTc = -1

                Dim directQty As Double = ResolveRequestedCartQuantity()

                Dim directProdottoGratis As Integer = 0
                Integer.TryParse(Convert.ToString(Request.QueryString("pg")), directProdottoGratis)

                Session("Carrello_ArticoloId") = directId.ToString(CultureInfo.InvariantCulture)
                Session("Carrello_TCId") = directTc.ToString(CultureInfo.InvariantCulture)
                Session("Carrello_Quantita") = directQty.ToString(CultureInfo.InvariantCulture)
                Session("ProdottoGratis") = directProdottoGratis.ToString(CultureInfo.InvariantCulture)
                Session("Carrello_Pagina") = If(Request.UrlReferrer IsNot Nothing, Request.UrlReferrer.PathAndQuery, "Default.aspx")
                Session("Carrello_SelezioneMultipla") = Nothing
            End If
        Else
            Dim requestedQty As Double
            If TryGetValidQueryStringQuantity(requestedQty) Then
                Session("Carrello_Quantita") = requestedQty.ToString(CultureInfo.InvariantCulture)
            End If
        End If


        ' 3) Pagina di provenienza (non usata ora, la mantengo per compatibilità)
        Dim Pagina As String = TryCast(Me.Session("Carrello_Pagina"), String)
        If String.IsNullOrEmpty(Pagina) AndAlso Request.UrlReferrer IsNot Nothing Then
            Pagina = Request.UrlReferrer.ToString()
        End If

        
' 3b) Se non c'è nessun articolo in sessione e non siamo in un flusso speciale, torno al carrello
If String.IsNullOrEmpty(idParam) AndAlso Me.Session("Carrello_ArticoloId") Is Nothing Then
    SafeRedirect("carrello.aspx")
    Return
End If

' 4) LOGICA DI AGGIUNTA AL CARRELLO

        If Me.Session("Carrello_ArticoloId") IsNot Nothing Then
            Try
                articoliIdGlobali = GestisciAggiuntaArticoli()
            Catch ex As Exception
                articoliIdGlobali = String.Empty
                Try
                    KeepStoreLog.Error("aggiungi.aspx", "Errore aggiunta carrello ArticoloId=" & Convert.ToString(Me.Session("Carrello_ArticoloId")) & " TCid=" & Convert.ToString(Me.Session("Carrello_TCId")), ex, HttpContext.Current)
                Catch
                End Try
            End Try
        End If

        ' 5) Pulizia variabili di sessione carrello temporanee
        Me.Session("Carrello_ArticoloId") = Nothing
        Me.Session("Carrello_ListaArticoloId") = Nothing
        Me.Session("Carrello_Quantita") = Nothing
        Me.Session("Carrello_SelezioneMultipla") = Nothing
        Me.Session("ProdottoGratis") = Nothing

        ' 6) Facebook Pixel (solo se abbiamo effettivamente aggiunto qualcosa)
        If Not String.IsNullOrEmpty(articoliIdGlobali) Then
            facebook_pixel(articoliIdGlobali)
        End If

        
    ' 7) Redirect server-side al carrello: questa è una pagina tecnica di inserimento,
    ' non deve dipendere dal rendering client per completare il flusso.
    SafeRedirect("carrello.aspx")
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
        Dim couponQnt As Double = 1
        TryParseDouble(Session("Coupon_Qnt_Pezzi"), couponQnt)
        Dim couponPrezzo As Double = 0
        TryParseDouble(Session("Coupon_Prezzo"), couponPrezzo)
        Dim couponPrezzoIvato As Double = 0
        TryParseDouble(Session("Coupon_PrezzoIvato"), couponPrezzoIvato)

        Dim couponArticleId As Integer = 0
        Integer.TryParse(Convert.ToString(Session("Coupon_idArticolo")), couponArticleId)
        AddCartRowWithNewcarrello(loginId,
                                  Session.SessionID,
                                  couponArticleId,
                                  -1,
                                  Convert.ToString(Session("Coupon_codArticolo")),
                                  Convert.ToString(Session("Coupon_DescrizioneArticolo")),
                                  couponQnt,
                                  1,
                                  couponPrezzo,
                                  couponPrezzoIvato,
                                  0,
                                  0)

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
        Dim QuantitaBase As Double = ResolveRequestedCartQuantity()

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
                If parts.Length < 3 Then
                    Continue For
                End If

                Dim selezionamultipla_ID As String = parts(0)
                Dim selezionamultipla_TCID As String = "-1"
                Dim selezionamultipla_Qta As String = "1"
                Dim selezionamultipla_SpedGRATIS As String = "0"

                If parts.Length >= 4 Then
                    selezionamultipla_TCID = parts(1)
                    selezionamultipla_Qta = parts(2)
                    selezionamultipla_SpedGRATIS = parts(3)
                Else
                    ' Formato storico wishlist: id,qta,ProdottoGratis
                    selezionamultipla_Qta = parts(1)
                    selezionamultipla_SpedGRATIS = parts(2)
                End If

                selezionamultipla_TCID = NormalizeTcidText(selezionamultipla_TCID)

                ' SpedizioneGratis: deve essere 0/1 (evita '' che rompe MySQL)
                Dim _pgTmp As Integer = 0
                If Not Integer.TryParse(selezionamultipla_SpedGRATIS, _pgTmp) Then _pgTmp = 0
                selezionamultipla_SpedGRATIS = _pgTmp.ToString()
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
                Dim existingCartRowId As Integer = 0
                Dim effectiveExistingCartRowId As Integer = 0

                ' Se l'articolo è già presente nel carrello sommo la quantità
                If dr.Count > 0 Then
                    Dim row = dr(0)
                    Dim oldQ As Double = 0
                    TryParseDouble(row("qnt"), oldQ)
                    Dim newQ As Double = 0
                    TryParseDouble(selezionamultipla_Qta, newQ)
                    quantitaRiga = newQ + oldQ

                    Integer.TryParse(Convert.ToString(row("id")), existingCartRowId)
                Else
                    TryParseDouble(selezionamultipla_Qta, quantitaRiga)
                End If

                ' Leggo prezzi e promozioni
                dr = LoadCartProductRows(selezionamultipla_ID, selezionamultipla_TCID, NListino)
                Dim effectiveTCID As String = ResolveEffectiveTcidText(dr, selezionamultipla_TCID)
                If effectiveTCID <> selezionamultipla_TCID Then
                    selezionamultipla_TCID = effectiveTCID
                    Dim effectiveWhere As String
                    If LoginId = 0 Then
                        effectiveWhere = "where SessionID=@SessionID"
                    Else
                        effectiveWhere = "where LoginID=@LoginId"
                    End If
                    effectiveWhere &= " and ArticoliId=@ArticoliId and TCId=@TCId"
                    Dim effectiveParams As New Dictionary(Of String, String)
                    effectiveParams.Add("@ArticoliId", selezionamultipla_ID)
                    effectiveParams.Add("@TCId", selezionamultipla_TCID)
                    effectiveParams.Add("@SessionID", SessionID)
                    effectiveParams.Add("@LoginId", LoginId.ToString())
                    Dim effectiveExisting = ExecuteQueryGetDataReader("id, qnt", "carrello", effectiveWhere, effectiveParams)
                    If effectiveExisting.Count > 0 Then
                        Dim oldQEffective As Double = 0
                        TryParseDouble(effectiveExisting(0)("qnt"), oldQEffective)
                        quantitaRiga += oldQEffective
                        Integer.TryParse(Convert.ToString(effectiveExisting(0)("id")), effectiveExistingCartRowId)
                    End If
                End If

                ResolveCartPriceFromRows(dr, quantitaRiga, Codice, Descrizione, Prezzo, PrezzoIvato, OfferteDettagliID)

                ' Inserisco articolo
                Dim addId As Integer = 0
                Dim addTc As Integer = -1
                Integer.TryParse(selezionamultipla_ID, addId)
                Integer.TryParse(selezionamultipla_TCID, addTc)

                If ShouldSkipZeroPriceCartInsert(Prezzo, PrezzoIvato, _pgTmp) Then
                    SetCartAddPriceLookupMessage()
                    LogCartPriceLookupFailed(selezionamultipla_ID, selezionamultipla_TCID, NListino, LoginId, SessionID, "multipla")
                    Continue For
                End If

                DeleteDeferredCartRows(existingCartRowId, effectiveExistingCartRowId)
                Dim cartRowId As Integer = AddCartRowWithNewcarrello(LoginId, SessionID, addId, addTc, Codice, Descrizione, quantitaRiga, NListino, Prezzo, PrezzoIvato, OfferteDettagliID, _pgTmp)
                Dim rawCartOk As Boolean = VerifyCartRow(LoginId, SessionID, addId, addTc)
                Dim visualCartOk As Boolean = VerifyVCarrelloRow(LoginId, SessionID, addId, addTc)
                If Not rawCartOk Then
                    Try
                        KeepStoreLog.Info("aggiungi.aspx", "Aggiunta multipla non verificata in carrello id=" & selezionamultipla_ID & " tcid=" & selezionamultipla_TCID & " rowId=" & cartRowId.ToString(CultureInfo.InvariantCulture) & " sessionId=" & SessionID & " nListino=" & NListino.ToString(CultureInfo.InvariantCulture), HttpContext.Current)
                    Catch
                    End Try
                    Continue For
                End If
                If Not visualCartOk Then
                    Try
                        KeepStoreLog.Info("aggiungi.aspx", "Aggiunta multipla presente in carrello ma non ancora visibile in vcarrello id=" & selezionamultipla_ID & " tcid=" & selezionamultipla_TCID & " rowId=" & cartRowId.ToString(CultureInfo.InvariantCulture) & " sessionId=" & SessionID & " nListino=" & NListino.ToString(CultureInfo.InvariantCulture), HttpContext.Current)
                    Catch
                    End Try
                End If

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
                Dim tcidRiga As String = NormalizeTcidText(ListaTCs(i).ToString())

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
                params.Add("@TCId", tcidRiga)
                params.Add("@SessionID", SessionID)
                params.Add("@LoginId", LoginId.ToString())

                Dim dr = ExecuteQueryGetDataReader("id, qnt", "carrello", wherePart, params)
                Dim existingCartRowId As Integer = 0
                Dim effectiveExistingCartRowId As Integer = 0

                ' Se l'articolo è già presente nel carrello sommo la quantità
                If dr.Count > 0 Then
                    Dim row = dr(0)
                    Dim oldQ As Double = 0
                    TryParseDouble(row("qnt"), oldQ)
                    quantitaRiga = quantitaRiga + oldQ
                    Integer.TryParse(Convert.ToString(row("id")), existingCartRowId)
                End If

                ' Leggo prezzi e promozioni
                dr = LoadCartProductRows(ListaArticoli(i).ToString(), tcidRiga, NListino)
                Dim effectiveTcidRiga As String = ResolveEffectiveTcidText(dr, tcidRiga)
                If effectiveTcidRiga <> tcidRiga Then
                    tcidRiga = effectiveTcidRiga
                    Dim effectiveWhere As String
                    If LoginId = 0 Then
                        effectiveWhere = "where SessionID=@SessionID"
                    Else
                        effectiveWhere = "where LoginID=@LoginId"
                    End If
                    effectiveWhere &= " and ArticoliId=@ArticoliId and TCId=@TCId"
                    Dim effectiveParams As New Dictionary(Of String, String)
                    effectiveParams.Add("@ArticoliId", ListaArticoli(i).ToString())
                    effectiveParams.Add("@TCId", tcidRiga)
                    effectiveParams.Add("@SessionID", SessionID)
                    effectiveParams.Add("@LoginId", LoginId.ToString())
                    Dim effectiveExisting = ExecuteQueryGetDataReader("id, qnt", "carrello", effectiveWhere, effectiveParams)
                    If effectiveExisting.Count > 0 Then
                        Dim oldQEffective As Double = 0
                        TryParseDouble(effectiveExisting(0)("qnt"), oldQEffective)
                        quantitaRiga += oldQEffective
                        Integer.TryParse(Convert.ToString(effectiveExisting(0)("id")), effectiveExistingCartRowId)
                    End If
                End If

                ResolveCartPriceFromRows(dr, quantitaRiga, Codice, Descrizione, Prezzo, PrezzoIvato, OfferteDettagliID)

                ' Inserisco articolo
                Dim prodottoGratis As Integer = 0
                If Session("ProdottoGratis") IsNot Nothing Then
                    Integer.TryParse(Session("ProdottoGratis").ToString(), prodottoGratis)
                End If
                Dim addId As Integer = 0
                Dim addTc As Integer = -1
                Integer.TryParse(ListaArticoli(i).ToString(), addId)
                Integer.TryParse(tcidRiga, addTc)

                If ShouldSkipZeroPriceCartInsert(Prezzo, PrezzoIvato, prodottoGratis) Then
                    SetCartAddPriceLookupMessage()
                    LogCartPriceLookupFailed(ListaArticoli(i).ToString(), tcidRiga, NListino, LoginId, SessionID, "singola")
                    Continue For
                End If

                DeleteDeferredCartRows(existingCartRowId, effectiveExistingCartRowId)
                Dim cartRowId As Integer = AddCartRowWithNewcarrello(LoginId, SessionID, addId, addTc, Codice, Descrizione, quantitaRiga, NListino, Prezzo, PrezzoIvato, OfferteDettagliID, prodottoGratis)
                Dim rawCartOk As Boolean = VerifyCartRow(LoginId, SessionID, addId, addTc)
                Dim visualCartOk As Boolean = VerifyVCarrelloRow(LoginId, SessionID, addId, addTc)
                If Not rawCartOk Then
                    Try
                        KeepStoreLog.Info("aggiungi.aspx", "Aggiunta singola non verificata in carrello id=" & ListaArticoli(i).ToString() & " tcid=" & tcidRiga & " rowId=" & cartRowId.ToString(CultureInfo.InvariantCulture) & " sessionId=" & SessionID & " nListino=" & NListino.ToString(CultureInfo.InvariantCulture), HttpContext.Current)
                    Catch
                    End Try
                    Continue For
                End If
                If Not visualCartOk Then
                    Try
                        KeepStoreLog.Info("aggiungi.aspx", "Aggiunta singola presente in carrello ma non ancora visibile in vcarrello id=" & ListaArticoli(i).ToString() & " tcid=" & tcidRiga & " rowId=" & cartRowId.ToString(CultureInfo.InvariantCulture) & " sessionId=" & SessionID & " nListino=" & NListino.ToString(CultureInfo.InvariantCulture), HttpContext.Current)
                    Catch
                    End Try
                End If

                AggiornaVisite(CInt(ListaArticoli(i)))
                If articoliIdGlobali <> String.Empty Then
                    articoliIdGlobali &= ","
                End If
                articoliIdGlobali &= ListaArticoli(i).ToString()
            Next
        End If

        Return articoliIdGlobali
    End Function

    Private Function LoadCartProductRows(ByVal articoloId As String, ByVal tcid As String, ByVal nListino As Integer) As List(Of Dictionary(Of String, Object))
        Dim params As New Dictionary(Of String, String)
        params.Add("@ArticoliId", articoloId)
        params.Add("@TCId", NormalizeTcidText(tcid))
        params.Add("@NListino", nListino.ToString(CultureInfo.InvariantCulture))

        Dim rows = ExecuteQueryGetDataReader("*", "vsuperarticoli", "where id=@ArticoliId and TCId=@TCId AND NListino=@NListino ORDER BY PrezzoPromo DESC", params)
        If rows.Count > 0 Then Return rows

        Dim fallbackParams As New Dictionary(Of String, String)
        fallbackParams.Add("@ArticoliId", articoloId)
        fallbackParams.Add("@NListino", nListino.ToString(CultureInfo.InvariantCulture))
        rows = ExecuteQueryGetDataReader("*", "vsuperarticoli", "where id=@ArticoliId AND NListino=@NListino ORDER BY CASE WHEN COALESCE(TCid,-1) IN (-1,0) THEN 0 ELSE 1 END, PrezzoPromo DESC LIMIT 1", fallbackParams)
        If rows.Count > 0 Then Return rows

        Dim articleParams As New Dictionary(Of String, String)
        articleParams.Add("@ArticoliId", articoloId)
        Return ExecuteQueryGetDataReader("id, -1 AS TCId, Codice, Descrizione1, 0 AS Prezzo, 0 AS PrezzoIvato, 0 AS InOfferta, 0 AS PrezzoPromo, 0 AS PrezzoPromoIvato, 0 AS OfferteQntMinima, 0 AS OfferteMultipli, 0 AS OfferteDettagliId", "articoli", "where id=@ArticoliId LIMIT 1", articleParams)
    End Function

    Private Function ResolveEffectiveTcidText(ByVal rows As List(Of Dictionary(Of String, Object)), ByVal requestedTcid As String) As String
        Dim fallback As String = NormalizeTcidText(requestedTcid)
        If rows Is Nothing OrElse rows.Count = 0 Then Return fallback

        Dim raw As Object = Nothing
        If TryGetRowValue(rows(0), raw, "TCId", "TCid", "tcid", "TCID") Then
            Dim effective As Integer = -1
            Integer.TryParse(Convert.ToString(raw), effective)
            If effective >= 0 Then Return effective.ToString(CultureInfo.InvariantCulture)
        End If

        Return fallback
    End Function

    Private Sub ResolveCartPriceFromRows(ByVal rows As List(Of Dictionary(Of String, Object)),
                                         ByVal quantity As Double,
                                         ByRef codice As String,
                                         ByRef descrizione As String,
                                         ByRef prezzo As Double,
                                         ByRef prezzoIvato As Double,
                                         ByRef offerteDettaglioId As Integer)
        codice = ""
        descrizione = ""
        prezzo = 0
        prezzoIvato = 0
        offerteDettaglioId = 0

        If rows Is Nothing OrElse rows.Count = 0 Then Exit Sub

        Dim baseRow As Dictionary(Of String, Object) = rows(0)
        codice = RowString(baseRow, "Codice")
        descrizione = RowString(baseRow, "Descrizione1")
        prezzo = RowDouble(baseRow, "Prezzo", 0)
        prezzoIvato = ResolveCartPrezzoIvato(baseRow, prezzo, RowDouble(baseRow, "PrezzoIvato", 0))

        Dim today As Date = Date.Today

        For Each row As Dictionary(Of String, Object) In rows
            If String.IsNullOrEmpty(codice) Then codice = RowString(row, "Codice")
            If String.IsNullOrEmpty(descrizione) Then descrizione = RowString(row, "Descrizione1")

            If RowInt(row, "InOfferta", 0) <> 1 Then Continue For
            If Not CartOfferIsActive(row, today) Then Continue For

            Dim qmin As Double = RowDouble(row, "OfferteQntMinima", 0)
            Dim multipli As Double = RowDouble(row, "OfferteMultipli", 0)
            Dim promo As Double = RowDouble(row, "PrezzoPromo", 0)
            Dim rowBase As Double = RowDouble(row, "Prezzo", 0)

            Dim match As Boolean = False
            If qmin > 0 AndAlso quantity >= qmin Then match = True
            If (Not match) AndAlso multipli > 0 AndAlso QuantityMatchesMultiple(quantity, multipli) Then match = True

            If match AndAlso promo > 0 AndAlso rowBase > 0 AndAlso promo < rowBase Then
                prezzo = promo
                prezzoIvato = ResolveCartPrezzoIvato(row, promo, RowDouble(row, "PrezzoPromoIvato", 0))
                offerteDettaglioId = RowInt(row, "OfferteDettagliId", 0)
            End If
        Next
    End Sub

    Private Function ResolveCartPrezzoIvato(ByVal row As Dictionary(Of String, Object),
                                            ByVal prezzoNetto As Double,
                                            ByVal fallbackIvato As Double) As Double
        Dim abRC As Boolean = False
        Dim abRaw As Object = Me.Session("AbilitatoIvaReverseCharge")
        If abRaw IsNot Nothing Then
            Dim abInt As Integer = 0
            Integer.TryParse(Convert.ToString(abRaw), abInt)
            abRC = (abInt = 1)
        End If

        Dim idIvaRC As Integer = RowInt(row, "IdIvaRC", -1)
        Dim valoreIvaRC As Double = RowDouble(row, "ValoreIvaRC", -1)
        If abRC AndAlso idIvaRC > -1 AndAlso valoreIvaRC > -1 Then
            Return prezzoNetto * ((valoreIvaRC / 100) + 1)
        End If

        Dim ivaUtente As Double = -1
        Dim parsedIvaUtente As Double = -1
        If TryParseDouble(Me.Session("Iva_Utente"), parsedIvaUtente) Then ivaUtente = parsedIvaUtente
        If ivaUtente > -1 Then
            Return prezzoNetto * ((ivaUtente / 100) + 1)
        End If

        Return fallbackIvato
    End Function

    Private Function CartOfferIsActive(ByVal row As Dictionary(Of String, Object), ByVal today As Date) As Boolean
        Dim dataInizio As Nullable(Of Date) = RowDate(row, "OfferteDataInizio")
        Dim dataFine As Nullable(Of Date) = RowDate(row, "OfferteDataFine")
        If dataInizio.HasValue AndAlso dataInizio.Value.Date > today Then Return False
        If dataFine.HasValue AndAlso dataFine.Value.Date < today Then Return False
        Return True
    End Function

    Private Function QuantityMatchesMultiple(ByVal quantity As Double, ByVal multiple As Double) As Boolean
        If multiple <= 0 Then Return False
        Dim quotient As Double = quantity / multiple
        Return Math.Abs(quotient - Math.Round(quotient, 0, MidpointRounding.AwayFromZero)) < 0.000001
    End Function

    Private Function RowString(ByVal row As Dictionary(Of String, Object), ByVal key As String, Optional ByVal defaultValue As String = "") As String
        Dim raw As Object = Nothing
        If TryGetRowValue(row, raw, key) AndAlso raw IsNot Nothing AndAlso raw IsNot DBNull.Value Then
            Return Convert.ToString(raw)
        End If
        Return defaultValue
    End Function

    Private Function RowInt(ByVal row As Dictionary(Of String, Object), ByVal key As String, Optional ByVal defaultValue As Integer = 0) As Integer
        Dim raw As Object = Nothing
        If TryGetRowValue(row, raw, key) Then
            Dim output As Integer = defaultValue
            If Integer.TryParse(Convert.ToString(raw), output) Then Return output
        End If
        Return defaultValue
    End Function

    Private Function RowDouble(ByVal row As Dictionary(Of String, Object), ByVal key As String, Optional ByVal defaultValue As Double = 0) As Double
        Dim raw As Object = Nothing
        If TryGetRowValue(row, raw, key) Then
            Dim output As Double = defaultValue
            If TryParseDouble(raw, output) Then Return output
        End If
        Return defaultValue
    End Function

    Private Function RowDate(ByVal row As Dictionary(Of String, Object), ByVal key As String) As Nullable(Of Date)
        Dim raw As Object = Nothing
        If Not TryGetRowValue(row, raw, key) OrElse raw Is Nothing OrElse raw Is DBNull.Value Then Return Nothing
        Try
            Return CDate(raw)
        Catch
            Dim parsed As Date
            If Date.TryParse(Convert.ToString(raw), CultureInfo.GetCultureInfo("it-IT"), DateTimeStyles.None, parsed) Then Return parsed
            If Date.TryParse(Convert.ToString(raw), CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then Return parsed
        End Try
        Return Nothing
    End Function

    Private Function TryGetRowValue(ByVal row As Dictionary(Of String, Object), ByRef value As Object, ParamArray keys() As String) As Boolean
        If row Is Nothing OrElse keys Is Nothing Then Return False
        For Each key As String In keys
            If key IsNot Nothing AndAlso row.ContainsKey(key) Then
                value = row(key)
                Return True
            End If
        Next
        Return False
    End Function

    Private Function NormalizeTcidText(ByVal raw As String) As String
        Dim tcid As Integer = -1
        Integer.TryParse(Convert.ToString(raw), tcid)
        If tcid < 0 Then tcid = -1
        Return tcid.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Function TryParseDouble(ByVal raw As Object, ByRef result As Double) As Boolean
        result = 0
        If raw Is Nothing OrElse raw Is DBNull.Value Then Return False

        Try
            If TypeOf raw Is Decimal OrElse TypeOf raw Is Double OrElse TypeOf raw Is Single OrElse
               TypeOf raw Is Integer OrElse TypeOf raw Is Long OrElse TypeOf raw Is Short Then
                result = Convert.ToDouble(raw, CultureInfo.InvariantCulture)
                Return True
            End If
        Catch
        End Try

        Dim text As String = Convert.ToString(raw).Trim()
        If String.IsNullOrEmpty(text) Then Return False

        Dim normalized As String = NormalizeCartDecimalText(text)
        If Double.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, result) Then Return True
        If Double.TryParse(text, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), result) Then Return True
        Return Double.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, result)
    End Function

    Private Function ResolveRequestedCartQuantity() As Double
        Dim queryQty As Double
        If TryGetValidQueryStringQuantity(queryQty) Then
            Session("Carrello_Quantita") = queryQty.ToString(CultureInfo.InvariantCulture)
            Return queryQty
        End If

        Dim sessionQty As Double
        If TryParseDouble(Session("Carrello_Quantita"), sessionQty) AndAlso sessionQty > 0 Then
            Return sessionQty
        End If

        Return 1
    End Function

    Private Function TryGetValidQueryStringQuantity(ByRef quantity As Double) As Boolean
        quantity = 0
        If Request Is Nothing OrElse Request.QueryString("qty") Is Nothing Then Return False
        Return TryParseDouble(Request.QueryString("qty"), quantity) AndAlso quantity > 0
    End Function

    Private Function NormalizeCartDecimalText(ByVal value As String) As String
        Dim s As String = Convert.ToString(value)
        If String.IsNullOrWhiteSpace(s) Then Return ""

        s = s.Trim()
        s = s.Replace(ChrW(8364), "")
        s = s.Replace("&euro;", "").Replace("&#8364;", "")
        s = s.Replace("EUR", "").Replace("eur", "").Replace("Euro", "").Replace("euro", "")
        s = s.Replace(ChrW(8722), "-")
        s = s.Replace(ChrW(160), "").Replace(ChrW(8239), "")
        s = s.Replace(" ", "").Replace("'", "")

        Dim comma As Integer = s.LastIndexOf(","c)
        Dim dot As Integer = s.LastIndexOf("."c)

        If comma >= 0 AndAlso dot >= 0 Then
            If comma > dot Then
                Return s.Replace(".", "").Replace(","c, "."c)
            End If

            Return s.Replace(",", "")
        End If

        If comma >= 0 Then
            Return NormalizeCartSingleSeparator(s, ","c)
        End If

        If dot >= 0 Then
            Return NormalizeCartSingleSeparator(s, "."c)
        End If

        Return s
    End Function

    Private Function NormalizeCartSingleSeparator(ByVal value As String, ByVal separator As Char) As String
        Dim parts() As String = value.Split(separator)
        If parts.Length <= 1 Then Return value

        Dim last As String = parts(parts.Length - 1)

        If parts.Length > 2 Then
            If last.Length > 0 AndAlso last.Length <= 2 Then
                Return JoinCartDecimalParts(parts) & "." & last
            End If

            Return String.Join("", parts)
        End If

        If last.Length = 3 Then
            Return parts(0) & last
        End If

        If separator = ","c Then
            Return parts(0) & "." & last
        End If

        Return value
    End Function

    Private Function JoinCartDecimalParts(ByVal parts() As String) As String
        Dim output As String = ""
        For i As Integer = 0 To parts.Length - 2
            output &= parts(i)
        Next
        Return output
    End Function

    Private Function ShouldSkipZeroPriceCartInsert(ByVal prezzo As Double,
                                                   ByVal prezzoIvato As Double,
                                                   ByVal prodottoGratis As Integer) As Boolean
        If prodottoGratis <> 0 Then Return False
        Return prezzo <= 0 AndAlso prezzoIvato <= 0
    End Function

    Private Sub SetCartAddPriceLookupMessage()
        Try
            Session("CartAddMessage") = "Prezzo prodotto non disponibile. Articolo non aggiunto al carrello."
        Catch
        End Try
    End Sub

    Private Sub DeleteDeferredCartRows(ByVal firstRowId As Integer, ByVal secondRowId As Integer)
        DeleteDeferredCartRow(firstRowId)
        If secondRowId <> firstRowId Then
            DeleteDeferredCartRow(secondRowId)
        End If
    End Sub

    Private Sub DeleteDeferredCartRow(ByVal rowId As Integer)
        If rowId <= 0 Then Exit Sub

        Dim params As New Dictionary(Of String, String)
        params.Add("@idRiga", rowId.ToString(CultureInfo.InvariantCulture))
        ExecuteDelete("carrello", "where id=@idRiga", params)
    End Sub

    Private Sub LogCartPriceLookupFailed(ByVal articoloId As String,
                                         ByVal tcId As String,
                                         ByVal nListino As Integer,
                                         ByVal loginId As Integer,
                                         ByVal sessionId As String,
                                         ByVal source As String)
        Try
            KeepStoreLog.Info("aggiungi.aspx", "Price lookup failed: skip cart insert source=" & source & " id=" & articoloId & " tcid=" & tcId & " nListino=" & nListino.ToString(CultureInfo.InvariantCulture) & " loginId=" & loginId.ToString(CultureInfo.InvariantCulture) & " sessionId=" & sessionId, HttpContext.Current)
        Catch
        End Try
    End Sub

    Private Function AddCartRowWithNewcarrello(ByVal loginId As Integer,
                                               ByVal sessionId As String,
                                               ByVal articoloId As Integer,
                                               ByVal tcId As Integer,
                                               ByVal codice As String,
                                               ByVal descrizione As String,
                                               ByVal qnt As Double,
                                               ByVal nListino As Integer,
                                               ByVal prezzo As Double,
                                               ByVal prezzoIvato As Double,
                                               ByVal offerteDettaglioId As Integer,
                                               ByVal prodottoGratis As Integer) As Integer
        If articoloId <= 0 Then Return 0
        If tcId < 0 Then tcId = -1
        If qnt <= 0 Then qnt = 1
        If nListino <= 0 Then nListino = 1
        If String.IsNullOrEmpty(sessionId) AndAlso loginId <= 0 Then sessionId = Me.Session.SessionID

        Dim connectionSettings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If connectionSettings Is Nothing OrElse String.IsNullOrEmpty(connectionSettings.ConnectionString) Then Return 0

        Try
            Using conn As New MySqlConnection(connectionSettings.ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("Newcarrello", conn)
                    cmd.CommandType = CommandType.StoredProcedure
                    cmd.Parameters.Add("?parLoginId", MySqlDbType.Int32).Value = loginId
                    cmd.Parameters.Add("?parSessionId", MySqlDbType.VarChar, 50).Value = If(sessionId, String.Empty)
                    cmd.Parameters.Add("?parArticoliId", MySqlDbType.Int32).Value = articoloId
                    cmd.Parameters.Add("?parTCId", MySqlDbType.Int32).Value = tcId
                    cmd.Parameters.Add("?parCodice", MySqlDbType.VarChar, 50).Value = If(codice, String.Empty)
                    cmd.Parameters.Add("?parDescrizione1", MySqlDbType.VarChar, 255).Value = If(descrizione, String.Empty)
                    cmd.Parameters.Add("?parQnt", MySqlDbType.Double).Value = qnt
                    cmd.Parameters.Add("?parNListino", MySqlDbType.Int32).Value = nListino
                    cmd.Parameters.Add("?parPrezzo", MySqlDbType.Double).Value = prezzo
                    cmd.Parameters.Add("?parPrezzoIvato", MySqlDbType.Double).Value = prezzoIvato
                    cmd.Parameters.Add("?parOfferteDettaglioID", MySqlDbType.Int32).Value = offerteDettaglioId
                    cmd.Parameters.Add("?parProdottoGratis", MySqlDbType.Int32).Value = prodottoGratis
                    Dim ret = cmd.Parameters.Add("?parRetVal", MySqlDbType.Int32)
                    ret.Direction = ParameterDirection.Output

                    cmd.ExecuteNonQuery()

                    Dim insertedId As Integer = 0
                    Integer.TryParse(Convert.ToString(ret.Value), insertedId)
                    If insertedId > 0 Then Return insertedId
                End Using
            End Using
        Catch ex As Exception
            Try
                KeepStoreLog.Info("aggiungi.aspx", "Newcarrello non riuscita, fallback insert diretto: " & ex.Message, HttpContext.Current)
            Catch
            End Try
        End Try

        Return AddCartRowDirect(loginId, sessionId, articoloId, tcId, codice, descrizione, qnt, nListino, prezzo, prezzoIvato, offerteDettaglioId, prodottoGratis)
    End Function

    Private Function AddCartRowDirect(ByVal loginId As Integer,
                                      ByVal sessionId As String,
                                      ByVal articoloId As Integer,
                                      ByVal tcId As Integer,
                                      ByVal codice As String,
                                      ByVal descrizione As String,
                                      ByVal qnt As Double,
                                      ByVal nListino As Integer,
                                      ByVal prezzo As Double,
                                      ByVal prezzoIvato As Double,
                                      ByVal offerteDettaglioId As Integer,
                                      ByVal prodottoGratis As Integer) As Integer
        Dim connectionSettings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If connectionSettings Is Nothing OrElse String.IsNullOrEmpty(connectionSettings.ConnectionString) Then Return 0

        Using conn As New MySqlConnection(connectionSettings.ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand("", conn)
                cmd.CommandText = "INSERT INTO carrello (LoginId, SessionId, ArticoliId, TCId, Codice, Descrizione1, Qnt, NListino, Prezzo, PrezzoIvato, OfferteDettaglioId, Prodotto_Gratis) VALUES (?LoginId, ?SessionId, ?ArticoliId, ?TCId, ?Codice, ?Descrizione1, ?Qnt, ?NListino, ?Prezzo, ?PrezzoIvato, ?OfferteDettaglioId, ?ProdottoGratis)"
                cmd.Parameters.Add("?LoginId", MySqlDbType.Int32).Value = loginId
                cmd.Parameters.Add("?SessionId", MySqlDbType.VarChar, 50).Value = If(sessionId, String.Empty)
                cmd.Parameters.Add("?ArticoliId", MySqlDbType.Int32).Value = articoloId
                cmd.Parameters.Add("?TCId", MySqlDbType.Int32).Value = tcId
                cmd.Parameters.Add("?Codice", MySqlDbType.VarChar, 50).Value = If(codice, String.Empty)
                cmd.Parameters.Add("?Descrizione1", MySqlDbType.VarChar, 255).Value = If(descrizione, String.Empty)
                cmd.Parameters.Add("?Qnt", MySqlDbType.Double).Value = qnt
                cmd.Parameters.Add("?NListino", MySqlDbType.Int32).Value = nListino
                cmd.Parameters.Add("?Prezzo", MySqlDbType.Double).Value = prezzo
                cmd.Parameters.Add("?PrezzoIvato", MySqlDbType.Double).Value = prezzoIvato
                cmd.Parameters.Add("?OfferteDettaglioId", MySqlDbType.Int32).Value = offerteDettaglioId
                cmd.Parameters.Add("?ProdottoGratis", MySqlDbType.Int32).Value = prodottoGratis

                Dim affected As Integer = cmd.ExecuteNonQuery()
                If affected <= 0 Then Return 0

                cmd.Parameters.Clear()
                cmd.CommandText = "SELECT LAST_INSERT_ID()"
                Dim rawId As Object = cmd.ExecuteScalar()
                Dim insertedId As Integer = 0
                Integer.TryParse(Convert.ToString(rawId), insertedId)
                Return insertedId
            End Using
        End Using
    End Function

    Private Function VerifyCartRow(ByVal loginId As Integer, ByVal sessionId As String, ByVal articoloId As Integer, ByVal tcId As Integer) As Boolean
        If articoloId <= 0 Then Return False
        If tcId < 0 Then tcId = -1
        If String.IsNullOrEmpty(sessionId) AndAlso loginId <= 0 Then sessionId = Me.Session.SessionID

        Dim wherePart As String
        Dim params As New Dictionary(Of String, String)
        params.Add("@ArticoliId", articoloId.ToString(CultureInfo.InvariantCulture))
        params.Add("@TCId", tcId.ToString(CultureInfo.InvariantCulture))

        If loginId > 0 Then
            wherePart = "where LoginId=@LoginId and ArticoliId=@ArticoliId and TCId=@TCId and Qnt>0"
            params.Add("@LoginId", loginId.ToString(CultureInfo.InvariantCulture))
        Else
            wherePart = "where SessionId=@SessionId and ArticoliId=@ArticoliId and TCId=@TCId and Qnt>0"
            params.Add("@SessionId", Convert.ToString(sessionId))
        End If

        Dim rows = ExecuteQueryGetDataReader("id", "carrello", wherePart & " ORDER BY id DESC LIMIT 1", params)
        Return rows.Count > 0
    End Function

    Private Function VerifyVCarrelloRow(ByVal loginId As Integer, ByVal sessionId As String, ByVal articoloId As Integer, ByVal tcId As Integer) As Boolean
        If articoloId <= 0 Then Return False
        If tcId < 0 Then tcId = -1
        If String.IsNullOrEmpty(sessionId) AndAlso loginId <= 0 Then sessionId = Me.Session.SessionID

        Dim wherePart As String
        Dim params As New Dictionary(Of String, String)
        params.Add("@ArticoliId", articoloId.ToString(CultureInfo.InvariantCulture))
        params.Add("@TCId", tcId.ToString(CultureInfo.InvariantCulture))

        If loginId > 0 Then
            wherePart = "where LoginId=@LoginId and ArticoliId=@ArticoliId and TCId=@TCId and Qnt>0"
            params.Add("@LoginId", loginId.ToString(CultureInfo.InvariantCulture))
        Else
            wherePart = "where SessionId=@SessionId and ArticoliId=@ArticoliId and TCId=@TCId and Qnt>0"
            params.Add("@SessionId", Convert.ToString(sessionId))
        End If

        Dim rows = ExecuteQueryGetDataReader("id", "vcarrello", wherePart & " ORDER BY id DESC LIMIT 1", params)
        Return rows.Count > 0
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
                    If IsValidPixelId(oldIdFbPixel) Then idsFbPixelsSku.Add(oldIdFbPixel, sku)
                End If
                oldIdFbPixel = newIdFbPixel
                sku = String.Empty
            Else
                sku &= ","
            End If

            sku &= CStr(subRow("sku"))
        Next

        If oldIdFbPixel <> String.Empty Then
            If IsValidPixelId(oldIdFbPixel) Then idsFbPixelsSku.Add(oldIdFbPixel, sku)
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
    Protected Function ExecuteDelete(ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Integer
        Dim sqlString As String = "DELETE FROM " & table & " " & wherePart
        Return ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Integer
        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
        Return ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing) As Integer
        Dim conn As New MySqlConnection
        Dim affectedRows As Integer = 0
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
                        If paramName = "?parPrezzo" OrElse paramName = "?parPrezzoIvato" OrElse
                           paramName = "@Prezzo" OrElse paramName = "@PrezzoIvato" OrElse paramName = "@Qnt" Then
                            Dim decValue As Double = 0
                            TryParseDouble(params(paramName), decValue)
                            cmd.Parameters.Add(paramName, MySqlDbType.Double).Value = decValue
                        ElseIf paramName = "@LoginId" OrElse paramName = "@ArticoliId" OrElse paramName = "@TCId" OrElse
                               paramName = "@NListino" OrElse paramName = "@OfferteDettaglioId" OrElse paramName = "@ProdottoGratis" Then
                            Dim intValue As Integer = 0
                            Integer.TryParse(params(paramName), intValue)
                            cmd.Parameters.Add(paramName, MySqlDbType.Int32).Value = intValue
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

                affectedRows = cmd.ExecuteNonQuery()
                cmd.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
        Return affectedRows
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
