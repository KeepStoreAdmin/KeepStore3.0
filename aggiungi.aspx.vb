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

                Dim directQty As Double = 1
                TryParseDouble(Request.QueryString("qty"), directQty)
                If directQty <= 0 Then directQty = 1

                Dim directProdottoGratis As Integer = 0
                Integer.TryParse(Convert.ToString(Request.QueryString("pg")), directProdottoGratis)

                Session("Carrello_ArticoloId") = directId.ToString(CultureInfo.InvariantCulture)
                Session("Carrello_TCId") = directTc.ToString(CultureInfo.InvariantCulture)
                Session("Carrello_Quantita") = directQty.ToString(CultureInfo.InvariantCulture)
                Session("ProdottoGratis") = directProdottoGratis.ToString(CultureInfo.InvariantCulture)
                Session("Carrello_Pagina") = If(Request.UrlReferrer IsNot Nothing, Request.UrlReferrer.PathAndQuery, "Default.aspx")
                Session("Carrello_SelezioneMultipla") = Nothing
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
        Me.Session("Carrello_Pagina") = Nothing
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
        Dim QuantitaBase As Double = 1
        If Me.Session("Carrello_Quantita") IsNot Nothing Then
            Dim tmpQ As Double
            If TryParseDouble(Me.Session("Carrello_Quantita"), tmpQ) AndAlso tmpQ > 0 Then
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

                ' Se l'articolo è già presente nel carrello sommo la quantità
                If dr.Count > 0 Then
                    Dim row = dr(0)
                    Dim oldQ As Double = 0
                    TryParseDouble(row("qnt"), oldQ)
                    Dim newQ As Double = 0
                    TryParseDouble(selezionamultipla_Qta, newQ)
                    quantitaRiga = newQ + oldQ

                    IdRiga = CInt(row("id"))
                    params.Add("@idRiga", IdRiga.ToString())
                    ExecuteDelete("carrello", "where id=@idRiga", params)
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
                        effectiveParams.Add("@idRiga", Convert.ToString(effectiveExisting(0)("id")))
                        ExecuteDelete("carrello", "where id=@idRiga", effectiveParams)
                    End If
                End If

                OfferteDettagliID = 0
                Prezzo = 0
                PrezzoIvato = 0

                For Each row As Dictionary(Of String, Object) In dr
                    Codice = CStr(row("Codice"))
                    Descrizione = CStr(row("Descrizione1"))
                    OfferteDettagliID = 0

                    If Prezzo = 0 Then
                        TryParseDouble(row("Prezzo"), Prezzo)
                    End If
                    If PrezzoIvato = 0 Then
                        TryParseDouble(row("PrezzoIvato"), PrezzoIvato)
                    End If

                    If CInt(row("InOfferta")) = 1 Then
                        Dim qmin As Double = 0
                        Dim multipli As Double = 0
                        TryParseDouble(row("OfferteQntMinima"), qmin)
                        TryParseDouble(row("OfferteMultipli"), multipli)

                        If quantitaRiga >= qmin AndAlso qmin > 0 Then
                            OfferteDettagliID = CInt(row("OfferteDettagliId"))
                            TryParseDouble(row("PrezzoPromo"), Prezzo)
                            TryParseDouble(row("PrezzoPromoIvato"), PrezzoIvato)
                        ElseIf multipli > 0 AndAlso quantitaRiga Mod multipli = 0 Then
                            OfferteDettagliID = CInt(row("OfferteDettagliId"))
                            TryParseDouble(row("PrezzoPromo"), Prezzo)
                            TryParseDouble(row("PrezzoPromoIvato"), PrezzoIvato)
                        End If
                    End If
                Next

                ' Inserisco articolo
                Dim addId As Integer = 0
                Dim addTc As Integer = -1
                Integer.TryParse(selezionamultipla_ID, addId)
                Integer.TryParse(selezionamultipla_TCID, addTc)

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

                ' Se l'articolo è già presente nel carrello sommo la quantità
                If dr.Count > 0 Then
                    Dim row = dr(0)
                    Dim oldQ As Double = 0
                    TryParseDouble(row("qnt"), oldQ)
                    quantitaRiga = quantitaRiga + oldQ
                    IdRiga = CInt(row("id"))
                    params.Add("@idRiga", IdRiga.ToString())
                    ExecuteDelete("carrello", "where id=@idRiga", params)
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
                        effectiveParams.Add("@idRiga", Convert.ToString(effectiveExisting(0)("id")))
                        ExecuteDelete("carrello", "where id=@idRiga", effectiveParams)
                    End If
                End If

                OfferteDettagliID = 0
                Prezzo = 0
                PrezzoIvato = 0

                For Each row As Dictionary(Of String, Object) In dr
                    Codice = CStr(row("Codice"))
                    Descrizione = CStr(row("Descrizione1"))
                    OfferteDettagliID = 0

                    If Prezzo = 0 Then
                        TryParseDouble(row("Prezzo"), Prezzo)
                    End If
                    If PrezzoIvato = 0 Then
                        TryParseDouble(row("PrezzoIvato"), PrezzoIvato)
                    End If

                    If CInt(row("InOfferta")) = 1 Then
                        Dim qmin As Double = 0
                        Dim multipli As Double = 0
                        TryParseDouble(row("OfferteQntMinima"), qmin)
                        TryParseDouble(row("OfferteMultipli"), multipli)

                        If quantitaRiga >= qmin AndAlso qmin > 0 Then
                            OfferteDettagliID = CInt(row("OfferteDettagliId"))
                            TryParseDouble(row("PrezzoPromo"), Prezzo)
                            TryParseDouble(row("PrezzoPromoIvato"), PrezzoIvato)
                        ElseIf multipli > 0 AndAlso quantitaRiga Mod multipli = 0 Then
                            OfferteDettagliID = CInt(row("OfferteDettagliId"))
                            TryParseDouble(row("PrezzoPromo"), Prezzo)
                            TryParseDouble(row("PrezzoPromoIvato"), PrezzoIvato)
                        End If
                    End If
                Next

                ' Inserisco articolo
                Dim prodottoGratis As Integer = 0
                If Session("ProdottoGratis") IsNot Nothing Then
                    Integer.TryParse(Session("ProdottoGratis").ToString(), prodottoGratis)
                End If
                Dim addId As Integer = 0
                Dim addTc As Integer = -1
                Integer.TryParse(ListaArticoli(i).ToString(), addId)
                Integer.TryParse(tcidRiga, addTc)

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
        Dim text As String = Convert.ToString(raw).Trim()
        If String.IsNullOrEmpty(text) Then Return False
        If Double.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, result) Then Return True
        If Double.TryParse(text, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), result) Then Return True
        Dim normalized As String = text.Replace("."c, ","c)
        If Double.TryParse(normalized, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), result) Then Return True
        normalized = text.Replace(","c, "."c)
        Return Double.TryParse(normalized, NumberStyles.Any, CultureInfo.InvariantCulture, result)
    End Function

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
