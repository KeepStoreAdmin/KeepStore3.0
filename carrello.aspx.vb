Imports System
Imports System.Data
Imports System.Configuration
Imports System.Globalization
Imports MySql.Data.MySqlClient
Imports System.Web.UI
Imports System.Web.UI.WebControls


Partial Class carrello
    Inherits System.Web.UI.Page

Protected differenzaTrasportoGratis As Double = 0

    'dichiarazioni campi pagina
Private IvaTipo As Integer = 0
Private DispoTipo As Integer = 0
Private DispoMinima As Double = 0

Private qta As Integer = 0
Private TotaleMerce As Double = 0
Protected imponibile As Double = 0
Protected imponibile_gratis As Double = 0
Private calcolo_iva As Double = 0
Private totale As Double = 0
Private pesoTotale As Double = 0

Private indice_riga_da_selezionare As Integer = -1
Private cont_indice_riga As Integer = 0
Private costo_promo_minimo As Double = 0
Private Selezionato_Vettore_Promo As Integer = 0

Private Cookie As String = ""
Private RitiroSede As Boolean = False

'Enum Lst
Private Enum Lst
    indirizzoSpedizione = 1
    destinazioneAlternativa = 2
End Enum

'ExecuteInsert
    'ExecuteInsert (INSERT vero)
Protected Function ExecuteInsert(ByVal table As String, ByVal fields As String, ByVal valuesPart As String, Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
    Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & valuesPart & ")"
    ExecuteNonQuery(False, sqlString, params)
    Return Nothing
    End Function

    'ExecuteInsert_Legacy (NON è un overload: serve solo se nel progetto esistono vecchie chiamate “strane”)
    'ATTENZIONE: non fa niente. Se qualche punto del codice la usa davvero, va corretto quel punto.
Protected Function ExecuteInsert_Legacy(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
    Return Nothing
    End Function


' serve perché nel tuo Catch fai LogEx(..., sqlString) fuori scope
Private lastSqlString As String = ""

    ' Evita doppi aggiornamenti nella stessa request (es. click evento + altra chiamata indiretta)
    Private _carrelloAggiornatoThisRequest As Boolean = False

    Private Structure CartRowInfo
    Public Id As Integer
    Public ArtId As Integer
    Public Qnt As Long
    End Structure

    Private Class VsuperInfo
    Public Prezzo As Double
    Public PrezzoIvato As Double
    Public InOfferta As Integer
    Public OfferteDataInizio As Nullable(Of Date)
    Public OfferteDataFine As Nullable(Of Date)
    Public OfferteQntMinima As Long
    Public OfferteMultipli As Long
    Public OfferteDettagliId As Long
    Public PrezzoPromo As Double
    Public PrezzoPromoIvato As Double
    Public IdIvaRC As Integer
    Public ValoreIvaRC As Double
    Public DescrizioneIvaRC As String
    End Class

' =========================
' PATCH STEP 4 - HELPERS
' =========================

Private Const SessUtentiId_A As String = "UTENTIID"
Private Const SessUtentiId_B As String = "UtentiId"
Private Const SessUtentiId_C As String = "UtentiID"

Private Const SessListino_A As String = "Listino"
Private Const SessListino_B As String = "listino"

Private Const SessLoginId_A As String = "LoginId"
Private Const SessLoginId_B As String = "LOGINID"

    Private Function GetSessionInt(ByVal key As String, Optional ByVal def As Integer = 0) As Integer
    Try
        Dim o As Object = Session(key)
        If o Is Nothing OrElse o Is DBNull.Value Then Return def

        Dim n As Integer
        If Integer.TryParse(o.ToString(), n) Then Return n

        Return def
    Catch
        Return def
    End Try
    End Function

    Private Function GetUtentiIdSafe(Optional ByVal defaultVal As Integer = 0) As Integer
    Dim id As Integer = GetSessionInt(SessUtentiId_A, 0)
    If id = 0 Then id = GetSessionInt(SessUtentiId_B, 0)
    If id = 0 Then id = GetSessionInt(SessUtentiId_C, 0)

    If id > 0 Then
        Session(SessUtentiId_A) = id
    End If

    Return If(id > 0, id, defaultVal)
    End Function

    Private Function GetLoginIdSafe(Optional ByVal defaultVal As Integer = 0) As Integer
    Dim id As Integer = GetSessionInt(SessLoginId_A, 0)
    If id = 0 Then id = GetSessionInt(SessLoginId_B, 0)

    Session(SessLoginId_A) = id
    Return If(id > 0, id, defaultVal)
    End Function

    Private Function GetListinoSafe(Optional ByVal defaultVal As Integer = 0) As Integer
    Dim l As Integer = GetSessionInt(SessListino_A, 0)
    If l = 0 Then l = GetSessionInt(SessListino_B, 0)

    If l > 0 Then
        Session(SessListino_A) = l
    End If

    Return If(l > 0, l, defaultVal)
    End Function

    Private Function GetListinoSafeString(Optional ByVal defaultVal As String = "") As String
    Dim o As Object = Session(SessListino_A)
    If o Is Nothing OrElse o.ToString().Trim() = "" Then o = Session(SessListino_B)

    Dim s As String = If(o, "").ToString().Trim()
    If s <> "" Then Session(SessListino_A) = s

    If s = "" Then s = defaultVal
    Return s
    End Function

    Private Sub LogEx(ByVal ex As Exception, Optional ByVal context As String = "", Optional ByVal sql As String = "")
    Try
        Dim msg As String = "carrello.aspx.vb"
        If context <> "" Then msg &= " [" & context & "]"
        If sql <> "" Then msg &= " SQL=" & sql
        System.Diagnostics.Trace.TraceError(msg & " - " & ex.ToString())
    Catch
    End Try
    End Sub


    Private Function ReadCartRowFromItem(ByVal item As RepeaterItem) As CartRowInfo
    Dim r As New CartRowInfo

    Dim tbQta As TextBox = TryCast(item.FindControl("tbQta"), TextBox)
    Dim tbID As TextBox = TryCast(item.FindControl("tbID"), TextBox)
    Dim tbArtID As TextBox = TryCast(item.FindControl("tbArtID"), TextBox)

    r.Id = SafeInt(If(tbID IsNot Nothing, tbID.Text, 0), 0)
    r.ArtId = SafeInt(If(tbArtID IsNot Nothing, tbArtID.Text, 0), 0)

    Dim q As Integer = SafeInt(If(tbQta IsNot Nothing, tbQta.Text, 0), 0)
    If q < 0 Then q = 0
    r.Qnt = CLng(q)

    Return r
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
    ' Setto il Timeout di Sessione
    Session.Timeout = 10
    If Session("DESTINAZIONEALTERNATIVA") Is Nothing Then
    Session("DESTINAZIONEALTERNATIVA") = 0
    End If

    Me.MaintainScrollPositionOnPostBack = True

    IvaTipo = GetSessionInt("IvaTipo", 0)
    DispoTipo = GetSessionInt("DispoTipo", 0)
    DispoMinima = GetSessionInt("DispoMinima", 0)

    Dim loginId As Integer = GetSessionInt("LoginId", 0)

    ' Nascondo i pannelli dei dati anagrafici quando non sono loggato
    Dim isLogged As Boolean = (loginId > 0)

    Me.pnlFatturazione.Visible = isLogged
    Me.PnlSpedizione.Visible = isLogged
    Me.PnlDestinazione.Visible = isLogged
    Me.Panel_Note.Visible = isLogged

    ' FillTableInfo SOLO se loggato e UTENTIID valido
    If isLogged Then
    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId > 0 Then
        FillTableInfo()
    End If
    End If
    End Sub

    ' forgotten code?

    ' preleva_prezzi_articoli() hardening Session/parametri
    Sub preleva_prezzi_articoli()

    Dim LoginId As Integer = GetSessionInt("LoginId", 0)

    Dim ivaUtente As Double = SafeDbl(Session("Iva_Utente"), -1)
    Dim ivaRCUtente As Double = SafeDbl(Session("IvaReverseCharge_Utente"), -1)

    Dim listino As Integer = GetSessionInt("Listino", 0)

    Dim params As New Dictionary(Of String, String)
    params.Add("@IvaUtente", ivaUtente.ToString(CultureInfo.InvariantCulture))
    params.Add("@IvaRCUtente", ivaRCUtente.ToString(CultureInfo.InvariantCulture))
    params.Add("@listino", listino.ToString())

    Dim loginOrSessionId As String = ""
    If LoginId = 0 Then
        loginOrSessionId = "SessionID=@SessionId"
        params.Add("@SessionId", If(Me.Session IsNot Nothing, Me.Session.SessionID, ""))
    Else
        loginOrSessionId = "LoginId=@LoginId"
        params.Add("@LoginId", LoginId.ToString())
    End If

    Dim innerJoin As String =
        " INNER JOIN (" &
        "   SELECT carrello.id AS idCarrello, carrello.ArticoliId, vsuperarticoli.id, vsuperarticoli.Nlistino, vsuperarticoli.InOfferta, vsuperarticoli.DescrizioneIvaRC, " &
        "   IF((InOfferta=1) AND ((OfferteDataInizio<=CURDATE()) AND (OfferteDataFine>=CURDATE())),vsuperarticoli.PrezzoPromo,vsuperarticoli.Prezzo) AS new_Prezzo, " & _
        "   IF((InOfferta=1) AND ((OfferteDataInizio<=CURDATE()) AND (OfferteDataFine>=CURDATE())),IF(@IvaUtente>-1,((vsuperarticoli.PrezzoPromo)*((@IvaUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato),IF(@IvaUtente>-1,((vsuperarticoli.Prezzo)*((@IvaUtente/100)+1)),vsuperarticoli.PrezzoIvato)) AS new_PrezzoIvato, " & _
        "   IF((InOfferta=1) AND ((OfferteDataInizio<=CURDATE()) AND (OfferteDataFine>=CURDATE())),IF(@IvaRCUtente>-1,((vsuperarticoli.PrezzoPromo)*((@IvaRCUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato),IF(@IvaRCUtente>-1,((vsuperarticoli.Prezzo)*((@IvaRCUtente/100)+1)),-1)) AS new_PrezzoRC " & _
        "   FROM carrello INNER JOIN vsuperarticoli ON (carrello.ArticoliId=vsuperarticoli.id) " &
        "   WHERE (vsuperarticoli.Nlistino=@listino) AND " & loginOrSessionId &
        " ) AS t1 ON t1.idCarrello=carrello.id "

    ExecuteUpdate("carrello " & innerJoin,
                  "carrello.Prezzo=new_Prezzo, carrello.PrezzoIvato=new_PrezzoIvato, carrello.ValoreIvaRC=new_PrezzoRC, carrello.DescrizioneIvaRC=DescrizioneIvaRC",
                  "",
                  params)

    End Sub

	
    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - Il tuo Carrello"
		
        Dim LoginId As Integer = Me.Session("LoginId")
        Dim SessionID As String = Me.Session.SessionID
        Dim WhereUserId As String

		'cancella_campi_destinazione_alternativa_o_indirizzo_spedizione()
		
        Dim Sqlstring As String = "SELECT vcarrello.*, articoli.SpedizioneGratis_Listini, articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine, taglie.descrizione as taglia, colori.descrizione as colore FROM vcarrello"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN articoli ON vcarrello.ArticoliId = articoli.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN articoli_tagliecolori ON vcarrello.TCid = articoli_tagliecolori.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"
        If LoginId = 0 Then
            WhereUserId = "(SessionId=@SessionId)"
        Else
            WhereUserId = "(LoginId=@LoginId)"
        End If
        Me.sdsArticoli.SelectCommand = Sqlstring & " WHERE (" & WhereUserId & " ) ORDER BY id"
        sdsArticoli.SelectParameters.Clear()
        sdsArticoli.SelectParameters.Add("@SessionId", SessionID)
        sdsArticoli.SelectParameters.Add("@LoginId", LoginId)

        Me.sdsArticoli_Spedizione_Gratis.SelectCommand = Sqlstring & " WHERE " & WhereUserId & " AND (articoli.SpedizioneGratis_Listini != '') AND (SpedizioneGratis_Listini LIKE CONCAT('%', @listino, ';%')) AND ((SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE() OR SpedizioneGratis_Data_Fine Is NULL)) ORDER BY id"
        sdsArticoli_Spedizione_Gratis.SelectParameters.Clear()
        sdsArticoli_Spedizione_Gratis.SelectParameters.Add("@SessionId", SessionID)
        sdsArticoli_Spedizione_Gratis.SelectParameters.Add("@LoginId", LoginId)
        sdsArticoli_Spedizione_Gratis.SelectParameters.Add("@listino", GetListinoSafeString())

        IvaTipo = Me.Session("IvaTipo")
        If IvaTipo = 1 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Esclusa"
        ElseIf IvaTipo = 2 Then
            If Session("Iva_Utente") > -1 Then
                Me.lblPrezzi.Text = "*Prezzi Iva Inclusa - (IVA Utente al " & Session("Iva_Utente") & "%)"
            Else
                Me.lblPrezzi.Text = "*Prezzi Iva Inclusa"
            End If
        End If

        'Nascondo i pannelli dei dati anagrafici quando non sono loggato
        If Me.Session("LoginId") > 0 Then
            Me.pnlFatturazione.Visible = True
			Me.PnlSpedizione.Visible = True
			Me.PnlDestinazione.Visible = True
            Me.Panel_Note.Visible = True
        Else
            Me.pnlFatturazione.Visible = False
			Me.PnlSpedizione.Visible = False
            Me.PnlDestinazione.Visible = False
            Me.Panel_Note.Visible = False
        End If
		
		
		REM Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType, "prova", "<script type='text/javascript'>document.body.onload=function(){alert('" & Me.sdsArticoli.SelectCommand.Replace("'", """").ToUpper & "')}</script>")
    End Sub

    Protected Sub Repeater1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Repeater1.PreRender
        Dim i As Integer

        'Carrello Normale
        For i = 0 To Repeater1.items.Count - 1
            Dim img As Image
            Dim dispo As Label
            Dim arrivo As Label
            Dim importo As Label
            Dim importoIvato As Label
            Dim peso As Label
            Dim tbQta As TextBox

            tbQta = Repeater1.items(i).FindControl("tbQta")
            img = Repeater1.items(i).FindControl("imgDispo")
            dispo = Repeater1.items(i).FindControl("lblDispo")
            arrivo = Repeater1.items(i).FindControl("lblArrivo")
            importo = Repeater1.items(i).FindControl("lblImporto")
            importoIvato = Repeater1.items(i).FindControl("lblImportoIvato")
            peso = Repeater1.items(i).FindControl("lblPeso")

        Dim qtaRiga As Integer = SafeIntFromText(tbQta.Text, 0)
        qta = qta + qtaRiga

    If qtaRiga > 0 Then

    If IvaTipo = 1 Then
        importo.Visible = True
        importoIvato.Visible = False
        Repeater1.items(i).FindControl("lblprezzo").Visible = True
        Repeater1.items(i).FindControl("lblprezzoivato").Visible = False

        TotaleMerce += SafeDblFromText(importo.Text, 0)
    ElseIf IvaTipo = 2 Then
        importo.Visible = False
        importoIvato.Visible = True
        Repeater1.items(i).FindControl("lblprezzo").Visible = False
        Repeater1.items(i).FindControl("lblprezzoivato").Visible = True

        TotaleMerce += SafeDblFromText(importoIvato.Text, 0)
    End If

    Session("TotaleMerce") = TotaleMerce

    imponibile = imponibile + SafeDblFromText(importo.Text, 0)
    calcolo_iva = calcolo_iva + (SafeDblFromText(importoIvato.Text, 0) - SafeDblFromText(importo.Text, 0))
    totale = totale + SafeDblFromText(importoIvato.Text, 0)

    If peso IsNot Nothing AndAlso peso.Text <> "" Then
        pesoTotale = pesoTotale + SafeDblFromText(peso.Text, 0)
    End If

    If DispoTipo = 1 Then
        Dim dispoDouble As Double = 0
        Dim dispoTxt As String = If(dispo.Text, "").Replace("−", "-").Replace(">", "").Trim()
        Double.TryParse(dispoTxt.Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, dispoDouble)

        If dispoDouble > DispoMinima Then
            img.ImageUrl = "~/images/verde.gif"
            img.AlternateText = "Disponibile"
        ElseIf dispoDouble > 0 Then
            img.ImageUrl = "~/images/giallo.gif"
            img.AlternateText = "Disponibilità Scarsa"
        Else
            Dim arrivoDouble As Double = 0
            Double.TryParse(If(arrivo.Text, "0").Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, arrivoDouble)

            If arrivoDouble > 0 Then
                img.ImageUrl = "~/images/azzurro.gif"
                img.AlternateText = "In Arrivo"
            Else
                img.ImageUrl = "~/images/rosso.gif"
                img.AlternateText = "Non Disponibile"
            End If
        End If

    ElseIf DispoTipo = 2 Then
        img.Visible = False
        dispo.Visible = True
    End If
    End If
        Next

        ' ------------------------ CONTEGGIO DEI TOTALI DA PAGARE -----------------------
        'Salvataggio per l'SQLData relativo ai vettori in PROMO
        Session.Item("Imponibile") = imponibile - imponibile_gratis

        Me.lblImponibile.Text = "€ " & FormatNumber(imponibile, 2)
        'Session("Calcolo_Iva") = calcolo_iva
        Me.tbPeso.Text = pesoTotale

        Me.tbTotale.Text = totale
        ' --------------------------------------------------------------------------------

        'ABILITA E DISABILITA I PULSANTI
        ArticoliCarrello(qta)

        'Me.gvVettori.DataBind()
    End Sub

    Public Sub ArticoliCarrello(ByVal numero As Integer)
        Me.lblArticoli.Text = numero
        If numero = 0 Then
            Me.lblPresenti.Text = "articoli nel carrello"
            Me.btSvuota.Visible = False
            Me.btCompleta.Visible = False
            Me.btAggiorna.Visible = True
        ElseIf numero = 1 Then
            Me.lblPresenti.Text = "articolo nel carrello"
            Me.btSvuota.Visible = True
            If (Me.gvVettoriPromo.Visible = True) Then
                Me.btCompleta.Visible = False
            Else
                Me.btCompleta.Visible = True
            End If
            Me.btAggiorna.Visible = True
        Else
            Me.lblPresenti.Text = "articoli nel carrello"
            Me.btSvuota.Visible = True
            If (Me.gvVettoriPromo.Visible = True) Then
                Me.btCompleta.Visible = False
            Else
                Me.btCompleta.Visible = True
            End If
            Me.btAggiorna.Visible = True
        End If
		if Me.Session("CanOrder") = 0 Then
			Me.btCompleta.Visible = False
			Me.canorder.Visible = True
		else
			Me.canorder.Visible = False
		End If
    End Sub

    Private Sub SendOrder()

        Try

            Me.Session("Ordine_TipoDoc") = 4
            Me.Session("Ordine_Documento") = "Ordine"
            Me.Session("Ordine_Pagamento") = Me.tbPagamenti.Text
            Me.Session("Ordine_BancaSellaGestPay_ShopId") = Me.tbShopIdGestPay.Text
            Me.Session("Ordine_Vettore") = Me.tbVettoriId.Text
            Me.Session("Ordine_SpeseSped") = SafeDbl(Me.lblSpeseSped.Text, 0)
            Me.Session("Ordine_SpeseAss") = SafeDbl(Me.lblSpeseAss.Text, 0)
            Me.Session("Ordine_SpesePag") = SafeDbl(Me.lblPagamento.Text, 0)
            Me.Session("Ordine_Totale_Documento") = SafeDbl(Me.lblTotale.Text, 0)


            '// INIZIO BLOCCO BUONO SCONTO - FIX COMPILAZIONE (SendOrder)
Dim buonoImp As Double = SafeMoney(lblBuonoSconto.Text, 0)
Dim buonoIva As Double = SafeMoney(lblBuonoScontoIVA.Text, 0)
Dim buonoTot As Double = buonoImp + buonoIva

' Se buono applicato: nel markup il GridView GV_BuoniSconti esiste e contiene le descrizioni nel primo record
If buonoTot > 0 Then

    Dim desc1 As String = ""
    Dim desc2 As String = ""

    If GV_BuoniSconti IsNot Nothing AndAlso GV_BuoniSconti.Rows.Count > 0 Then
        Dim r As GridViewRow = GV_BuoniSconti.Rows(0)
        Dim l1 As Label = TryCast(r.FindControl("lbl_Descrizione1_BuonoSconto"), Label)
        Dim l2 As Label = TryCast(r.FindControl("lbl_Descrizione2_BuonoSconto"), Label)
        If l1 IsNot Nothing Then desc1 = l1.Text
        If l2 IsNot Nothing Then desc2 = l2.Text
    End If

    Me.Session("Ordine_DescrizioneBuonoSconto") =
        (desc1 & " " & desc2).Trim() &
        " per un valore di " & String.Format("{0:c}", buonoTot) &
        " Codice Applicato: " & TB_BuonoSconto.Text

            Me.Session("Ordine_TotaleBuonoSconto") = buonoTot
            Me.Session("Ordine_TotaleBuonoScontoImponibile") = buonoImp
            Me.Session("Ordine_BuonoScontoIdIva") = preleva_IdIva(GetSessionInt("Iva_Utente", -1))
            Me.Session("Ordine_BuonoScontoValoreIva") = preleva_ValoreIva(GetSessionInt("Iva_Utente", -1))
            Me.Session("Ordine_CodiceBuonoSconto") = TB_BuonoSconto.Text

            Else
            Me.Session("Ordine_DescrizioneBuonoSconto") = ""
            Me.Session("Ordine_TotaleBuonoSconto") = 0
            Me.Session("Ordine_TotaleBuonoScontoImponibile") = 0
            Me.Session("Ordine_BuonoScontoIdIva") = -1
            Me.Session("Ordine_BuonoScontoValoreIva") = 0
            Me.Session("Ordine_CodiceBuonoSconto") = ""
            End If
            Me.Session("NoteDocumento") = Me.txtNoteSpedizione.Text

            Response.Redirect("ordine.aspx?C=" & Cookie.ToUpper)

            'Test di controllo, relativo al buono sconto del carrello
            'Dim test As Integer = 0
            'Dim test2 As Integer = 0

            'test = test2 + Session("Ordine_DescrizioneBuonoSconto")

        Catch ex As Exception
        LogEx(ex, "SendOrder")

        End Try

    End Sub

    Protected Sub gvVettori_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles gvVettori.PreRender
        LeggiVettori()
    End Sub

    Public Sub LeggiVettori()

    Dim i As Integer
    Dim rb As RadioButton
    Dim AsssicurazionePercentuale As Double
    Dim AssicurazioneMinimo As Double
    Dim TotAssicurazione As Double
    Dim lbl As Label
    Dim lblContrPerc As Label
    Dim lblContrFisso As Label
    Dim lblContrMinimo As Label
    Dim lblCosto As Label
    Dim sel As Boolean = False

    ' Resetto il prezzo relativo al metodo di pagamento
    lblPagamento.Text = String.Format("{0:c}", 0D)

    ' Base imponibile (la Label contiene spesso "€ ...", quindi la leggo in modo safe)
    Dim imponibileBase As Double = SafeMoney(Me.lblImponibile.Text, 0)

    'Controllo se Esiste ed è abilitato un Vettore PROMO
    Dim Vettore_Promo_Abilitato As Integer = 0
    For i = 0 To (Me.gvVettoriPromo.Rows.Count - 1)
        rb = gvVettoriPromo.Rows(i).FindControl("rbSpedizione")
        If rb IsNot Nothing AndAlso rb.Enabled = True Then
            Vettore_Promo_Abilitato = 1
            Exit For
        End If
    Next

    'Controllo se è selezionato un vettore NORMALE
    Dim Vettore_NoNPromo_Selezionato As Integer = 0
    For i = 0 To (Me.gvVettori.Rows.Count - 1)
        rb = gvVettori.Rows(i).FindControl("rbSpedizione")
        If rb IsNot Nothing AndAlso rb.Checked = True Then
            Vettore_NoNPromo_Selezionato = 1
            Exit For
        End If
    Next

    If (Vettore_Promo_Abilitato = 0) Or ((Vettore_Promo_Abilitato = 1) And (Vettore_NoNPromo_Selezionato = 1)) Then

        For i = 0 To gvVettori.Rows.Count - 1

            rb = gvVettori.Rows(i).FindControl("rbSpedizione")
            If rb IsNot Nothing AndAlso rb.Checked Then

                sel = True

                'Spedizione
                lblCosto = gvVettori.Rows(i).FindControl("lblCosto")
                Dim costoSped As Double = SafeMoney(If(lblCosto IsNot Nothing, lblCosto.Text, "0"), 0)
                Me.lblSpeseSped.Text = String.Format("{0:c}", costoSped)

                lbl = gvVettori.Rows(i).FindControl("lblId")
                If lbl IsNot Nothing Then Me.tbVettoriId.Text = lbl.Text

                'Assicurazione
                lbl = gvVettori.Rows(i).FindControl("lblAssPerc")
                AsssicurazionePercentuale = SafeDblFromText(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

                lbl = gvVettori.Rows(i).FindControl("lblAssicurazioneMinimo")
                AssicurazioneMinimo = SafeMoney(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

                Dim imponibileValTmp As Double = SafeMoney(Me.lblImponibile.Text, 0)
                TotAssicurazione = (AsssicurazionePercentuale * imponibileValTmp) / 100

                If TotAssicurazione < AssicurazioneMinimo Then
                    TotAssicurazione = AssicurazioneMinimo
                End If
                Me.lblAssicurazione.Text = String.Format("{0:c}", TotAssicurazione)

                'Contrassegno
                lblContrPerc = gvVettori.Rows(i).FindControl("lblContrPerc")
                lblContrFisso = gvVettori.Rows(i).FindControl("lblContrFisso")
                lblContrMinimo = gvVettori.Rows(i).FindControl("lblContrMinimo")

                Me.tbContrFisso.Text = If(lblContrFisso IsNot Nothing, lblContrFisso.Text, "")
                Me.tbContrPerc.Text = If(lblContrPerc IsNot Nothing, lblContrPerc.Text, "")
                Me.tbContrMinimo.Text = If(lblContrMinimo IsNot Nothing, lblContrMinimo.Text, "")

                AggiornaSpeseAssicurazione()

                If AsssicurazionePercentuale = 0 Then
                    Me.cbAssicurazione.Checked = False
                    Me.cbAssicurazione.Enabled = False
                Else
                    Me.cbAssicurazione.Enabled = True
                End If

                If SafeDblFromText(Me.tbContrPerc.Text, 0) = 0 Then
                    RitiroSede = True
                Else
                    RitiroSede = False
                End If

            End If
        Next

        If sel = False Then
            If (gvVettori.Rows.Count > 0) And (Selezionato_Vettore_Promo = 0) Then
                rb = gvVettori.Rows(0).FindControl("rbSpedizione")
                If rb IsNot Nothing Then
                    rb.Checked = True
                    LeggiVettori()
                    Exit Sub
                End If
            End If
        End If

    Else

        For i = 0 To Me.gvVettoriPromo.Rows.Count - 1

            rb = gvVettoriPromo.Rows(i).FindControl("rbSpedizione")

            If rb IsNot Nothing AndAlso rb.Enabled = True Then
                rb.Checked = True
            End If

            If rb IsNot Nothing AndAlso rb.Checked Then

                sel = True

                'Spedizione
                lblCosto = gvVettoriPromo.Rows(i).FindControl("lblCosto")
                Dim costoSped As Double = SafeMoney(If(lblCosto IsNot Nothing, lblCosto.Text, "0"), 0)
                Me.lblSpeseSped.Text = String.Format("{0:c}", costoSped)

                lbl = gvVettoriPromo.Rows(i).FindControl("lblId")
                If lbl IsNot Nothing Then Me.tbVettoriId.Text = lbl.Text

                'Assicurazione
                lbl = gvVettoriPromo.Rows(i).FindControl("lblAssPerc")
                AsssicurazionePercentuale = SafeDblFromText(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

                lbl = gvVettoriPromo.Rows(i).FindControl("lblAssicurazioneMinimo")
                AssicurazioneMinimo = SafeMoney(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

                Dim imponibileValTmp As Double = SafeMoney(Me.lblImponibile.Text, 0)
                TotAssicurazione = (AsssicurazionePercentuale * imponibileValTmp) / 100
                If TotAssicurazione < AssicurazioneMinimo Then
                    TotAssicurazione = AssicurazioneMinimo
                End If

                Me.lblAssicurazione.Text = String.Format("{0:c}", TotAssicurazione)

                'Contrassegno
                lblContrPerc = gvVettoriPromo.Rows(i).FindControl("lblContrPerc")
                lblContrFisso = gvVettoriPromo.Rows(i).FindControl("lblContrFisso")
                lblContrMinimo = gvVettoriPromo.Rows(i).FindControl("lblContrMinimo")

                Me.tbContrFisso.Text = If(lblContrFisso IsNot Nothing, lblContrFisso.Text, "")
                Me.tbContrPerc.Text = If(lblContrPerc IsNot Nothing, lblContrPerc.Text, "")
                Me.tbContrMinimo.Text = If(lblContrMinimo IsNot Nothing, lblContrMinimo.Text, "")

                AggiornaSpeseAssicurazione()

                If AsssicurazionePercentuale = 0 Then
                    Me.cbAssicurazione.Checked = False
                    Me.cbAssicurazione.Enabled = False
                Else
                    Me.cbAssicurazione.Enabled = True
                End If

                If SafeDblFromText(Me.tbContrPerc.Text, 0) = 0 Then
                    RitiroSede = True
                Else
                    RitiroSede = False
                End If

            End If
        Next

    End If

    'Setto l'iva relativa al vettore selezionato
    If tbVettoriId.Text <> "" Then
        Session("Iva_Vettori") = IvaVettore(SafeIntFromText(tbVettoriId.Text, 0))
    End If

    End Sub


    Public Sub AggiornaSpeseAssicurazione()
        If Me.cbAssicurazione.Checked Then
            Me.lblSpeseAss.Text = Me.lblAssicurazione.Text
        Else
            Me.lblSpeseAss.Text = "€ 0,00"
        End If
    End Sub

    Protected Sub gvPagamento_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles gvPagamento.PreRender
        LeggiPagamenti()
    End Sub

    Public Sub LeggiPagamenti()

    Dim i As Integer
    Dim rb As RadioButton
    Dim Percentuale As Double
    Dim Fisso As Double
    Dim Minimo As Double
    Dim totPagamento As Double
    Dim lbl As Label
    Dim lblContrassegno As Label
    Dim sel As Boolean = False
    Dim firstSelectableIndex As Integer = -1

    ' Leggo importi in modo safe (le Label contengono spesso "€ ...")
    Dim impD As Double = SafeMoney(Me.lblImponibile.Text, 0)
    Dim spedD As Double = SafeMoney(Me.lblSpeseSped.Text, 0)
    Dim assD As Double = SafeMoney(Me.lblSpeseAss.Text, 0)
    Dim buonoD As Double = SafeMoney(Me.lblBuonoSconto.Text, 0)

    Dim ivaVett As Integer = GetSessionInt("Iva_Vettori", 0)

    Dim ivaUtentePerc As Double = SafeDblFromText(If(Session("Iva_Utente"), "-1").ToString(), -1)
    ' Assicurazione: se l'utente ha IVA specifica uso quella (percentuale), altrimenti uso la default (preleva_ValoreIva(-1))
    Dim ivaAssPerc As Double = If(ivaUtentePerc > -1, ivaUtentePerc, preleva_ValoreIva(-1))

    Dim ivaCalcolata As Double = calcola_iva(spedD, ivaVett) + assD * (ivaAssPerc / 100)

    Me.lblIva.Text = "€ " & FormatNumber(ivaCalcolata, 2)

    ' Totale base per calcolare percentuali pagamento
    Dim totBase As Double = impD + spedD + assD + ivaCalcolata

    For i = 0 To gvPagamento.Rows.Count - 1

        rb = gvPagamento.Rows(i).FindControl("rbPagamento")
        If firstSelectableIndex = -1 AndAlso rb IsNot Nothing AndAlso rb.Enabled Then
            firstSelectableIndex = i
        End If

        lblContrassegno = gvPagamento.Rows(i).FindControl("lblContrassegno")

        If lblContrassegno IsNot Nothing AndAlso Val(lblContrassegno.Text) = 1 Then

            Percentuale = SafeDblFromText(Me.tbContrPerc.Text, 0)
            Fisso = SafeMoney(Me.tbContrFisso.Text, 0)
            Minimo = SafeMoney(Me.tbContrMinimo.Text, 0)

            If RitiroSede = True Then
                If rb IsNot Nothing Then
                    rb.Checked = False
                    rb.Enabled = False
                End If
            Else
                If rb IsNot Nothing Then rb.Enabled = True
            End If

        Else

            lbl = gvPagamento.Rows(i).FindControl("lblCostoP")
            Percentuale = SafeDblFromText(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

            lbl = gvPagamento.Rows(i).FindControl("lblCostoF")
            Fisso = SafeMoney(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

            Minimo = 0

        End If

        totPagamento = (totBase * (Percentuale / 100)) + Fisso
        If totPagamento < Minimo Then
            totPagamento = Minimo
        End If

        lbl = gvPagamento.Rows(i).FindControl("lblCosto")
        Try
            If lbl IsNot Nothing Then lbl.Text = String.Format("{0:c}", totPagamento)
        Catch
            If lbl IsNot Nothing Then lbl.Text = "€ 0,00"
        End Try

        If rb IsNot Nothing AndAlso rb.Checked = True AndAlso rb.Enabled = True Then
            sel = True

            lbl = gvPagamento.Rows(i).FindControl("lblId")
            If lbl IsNot Nothing Then Me.tbPagamenti.Text = lbl.Text

            lbl = gvPagamento.Rows(i).FindControl("lblShopLogin")
            If lbl IsNot Nothing Then Me.tbShopIdGestPay.Text = lbl.Text

            Me.lblPagamento.Text = String.Format("{0:c}", totPagamento)
        End If

    Next

    ' Se non selezionato nulla, seleziono la prima opzione disponibile (senza CDbl su "€ ...")
    If sel = False AndAlso firstSelectableIndex > -1 Then

        rb = gvPagamento.Rows(firstSelectableIndex).FindControl("rbPagamento")
        If rb IsNot Nothing Then rb.Checked = True

        lbl = gvPagamento.Rows(firstSelectableIndex).FindControl("lblId")
        If lbl IsNot Nothing Then Me.tbPagamenti.Text = lbl.Text

        lbl = gvPagamento.Rows(firstSelectableIndex).FindControl("lblShopLogin")
        If lbl IsNot Nothing Then Me.tbShopIdGestPay.Text = lbl.Text

        lbl = gvPagamento.Rows(firstSelectableIndex).FindControl("lblCosto")
        If lbl IsNot Nothing Then
            Me.lblPagamento.Text = lbl.Text
        Else
            Me.lblPagamento.Text = String.Format("{0:c}", 0D)
        End If

    End If

    ' Aggiorno Totale con pagamento corrente
    Dim pagD As Double = SafeMoney(Me.lblPagamento.Text, 0)
    Me.lblTotale.Text = "€ " & FormatNumber(impD + ivaCalcolata + assD + spedD + pagD + buonoD, 2)

    End Sub



    Protected Sub gvVettoriPromo_RowDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles gvVettoriPromo.RowDataBound
    Dim Soglia As Label
    Dim Peso As Label
    Dim Costo As Label
    Dim Percentuale As Label
    Dim Selezione As RadioButton

    cont_indice_riga += 1

    If e.Row.RowType = DataControlRowType.DataRow Then

        Selezione = TryCast(e.Row.FindControl("rbSpedizione"), RadioButton)
        Soglia = TryCast(e.Row.FindControl("lblSogliaMinima"), Label)
        Peso = TryCast(e.Row.FindControl("lblPeso"), Label)
        Costo = TryCast(e.Row.FindControl("lblCosto"), Label)
        Percentuale = TryCast(e.Row.FindControl("lblPercentuale"), Label)

        Dim sogliaVal As Double = SafeDblFromText(If(Soglia IsNot Nothing, Soglia.Text, "0"), 0)
        Dim pesoVal As Double = SafeDblFromText(If(Peso IsNot Nothing, Peso.Text, "0"), 0)

        If (sogliaVal <= (imponibile - imponibile_gratis)) AndAlso (pesoVal >= pesoTotale) Then

            If Selezione IsNot Nothing Then
                Selezione.Enabled = False
                Selezione.Checked = False
            End If

            Try
                Dim percVal As Double = SafeDblFromText(If(Percentuale IsNot Nothing, Percentuale.Text, "0"), 0)
                If percVal > 0 AndAlso Costo IsNot Nothing Then
                    Costo.Text = String.Format("{0:c}", ((imponibile - imponibile_gratis) / 100) * percVal)
                End If
            Catch
                If Percentuale IsNot Nothing Then Percentuale.Text = "0"
            End Try

            Dim costoVal As Double = SafeMoney(If(Costo IsNot Nothing, Costo.Text, "0"), 0)
            If costoVal < costo_promo_minimo Then
                costo_promo_minimo = costoVal
                indice_riga_da_selezionare = cont_indice_riga
            End If

        Else
            If Selezione IsNot Nothing Then
                Selezione.Enabled = False
            End If
        End If

    End If
    End Sub


    Public Sub BindLstDestinazioneLstScegliIndirizzo

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet

        Try

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
			cmd.Parameters.AddWithValue("@id", GetUtentiIdSafe(0))
            cmd.CommandText = "SELECT ID, CONCAT(RAGIONESOCIALEA, ' - ', NOMEA, ' - ',INDIRIZZOA, ', CAP: ', CAPA, ' - ',CITTAA,' (', PROVINCIAA, ')') AS CAMPO FROM utentiindirizzi where UTENTEID = @id Order by Predefinito Desc"


            Dim sqlAdp As New MySqlDataAdapter(cmd)
            sqlAdp.Fill(dsData, "utentiindirizzi")

            cmd.Dispose()

            LstDestinazione.Items.Clear()
            LstDestinazione.DataSource = dsData
            LstDestinazione.DataValueField = "ID"
            LstDestinazione.DataTextField = "CAMPO"
            LstDestinazione.DataBind()
			LstDestinazione.Items.Insert(0, New ListItem("(Seleziona)", "0"))
			
			LstScegliIndirizzo.Items.Clear()
            LstScegliIndirizzo.DataSource = dsData
            LstScegliIndirizzo.DataValueField = "ID"
            LstScegliIndirizzo.DataTextField = "CAMPO"
            LstScegliIndirizzo.DataBind()

        Catch ex As Exception
        LogEx(ex, "SendOrder")

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try

    End Sub

    Public Function getIndirizzoPrincipale() As String

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet

        Try
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
			cmd.Parameters.AddWithValue("@id", GetUtentiIdSafe(0))
            cmd.CommandText = "SELECT CONCAT(RAGIONESOCIALE, ' - ', COGNOMENOME, ' - ',INDIRIZZO, ', CAP: ', CAP, ' - ',CITTA,' (', PROVINCIA, ')')AS CAMPO FROM utenti where ID = @id"

            Dim obj = cmd.ExecuteScalar()
            If obj IsNot Nothing AndAlso obj IsNot DBNull.Value Then
            Return obj.ToString()
            End If
            Return ""


            cmd.Dispose()

        Catch ex As Exception
        LogEx(ex, "SendOrder")

            Return "ERRORE"

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try

    End Function

    Public Sub FillTableInfo()

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dr As MySqlDataReader

        Try

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@id", GetUtentiIdSafe(0))
            cmd.CommandText = "SELECT * FROM utenti WHERE ID=@id"
            dr = cmd.ExecuteReader

            If dr.Read Then
                Me.lblTab_Cap.Text = dr.Item("CAP")
                If Not IsDBNull(dr.Item("CELLULARE")) Then Me.lblTab_Cell.Text = dr.Item("CELLULARE")
                Me.lblTab_CF.Text = dr.Item("CODICEFISCALE")
                Me.lblTab_Citta.Text = dr.Item("CITTA")
                If Not IsDBNull(dr.Item("FAX")) Then Me.lblTab_Fax.Text = dr.Item("FAX")
                Me.lblTab_Indirizzo.Text = dr.Item("INDIRIZZO")
                Me.lblTab_mail.Text = dr.Item("EMAIL")
                Me.lblTab_Nome.Text = dr.Item("COGNOMENOME")
                Me.lblTab_pIva.Text = dr.Item("PIVA")
                Me.lblTab_Provincia.Text = dr.Item("PROVINCIA")
                Me.lblTab_RagioneSociale.Text = dr.Item("RAGIONESOCIALE")
                Me.lblTab_Tel.Text = dr.Item("TELEFONO")
            End If

            dr.Close()
            cmd.Dispose()

        Catch ex As Exception
        LogEx(ex, "SendOrder")

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try

    End Sub

    Protected Sub ImgBtnDestinazioneSi_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImgBtnDestinazioneSi.Click
        AggiornaDestinazionePredefinita(True)
    End Sub

    Protected Sub ImgBtnDestinazioneNo_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImgBtnDestinazioneNo.Click
        AggiornaDestinazionePredefinita(False)
    End Sub

    Private Sub AggiornaDestinazionePredefinita(ByVal Aggiorna As Boolean)

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Exit Sub

    Dim predefinito As Integer = 0

    ' Se richiesto, azzero tutti i predefiniti
    If Aggiorna = True Then
        Dim paramsUpd As New Dictionary(Of String, String)
        paramsUpd.Add("@UtenteId", utentiId.ToString())
        ExecuteUpdate("utentiindirizzi", "PREDEFINITO = 0", "UTENTEID=@UtenteId", paramsUpd)
        predefinito = 1
    End If

    ' Inserimento nuovo indirizzo
    Dim paramsIns As New Dictionary(Of String, String)
    paramsIns.Add("@UtenteId", utentiId.ToString())
    paramsIns.Add("@RAGIONESOCIALEA", Me.tbRagioneSocialeA.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@NOMEA", Me.tbNomeA.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@INDIRIZZOA", Me.tbIndirizzo2.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@CAPA", Me.tbCap2.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@CITTAA", getDdlCittaValue(Me.ddlCitta2).Replace("'", "''").ToUpper)
    paramsIns.Add("@PROVINCIAA", Me.tbProvincia2.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@NOTE", Me.tbNote.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@TELEFONOA", Me.tbTelefono2.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@ZONA", Me.tbZona.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@PREDEFINITO", predefinito.ToString())

    ExecuteInsert("utentiindirizzi",
                  "UTENTEID, RAGIONESOCIALEA, NOMEA, INDIRIZZOA, CAPA, CITTAA, PROVINCIAA, NOTE, TELEFONOA, ZONA, PREDEFINITO",
                  "@UtenteId, @RAGIONESOCIALEA, @NOMEA, @INDIRIZZOA, @CAPA, @CITTAA, @PROVINCIAA, @NOTE, @TELEFONOA, @ZONA, @PREDEFINITO",
                  paramsIns)

    BindLstDestinazioneLstScegliIndirizzo()
    Me.tblDestAlter.Visible = False

    Me.tbRagioneSocialeA.Text = ""
    Me.tbNomeA.Text = ""
    Me.tbIndirizzo2.Text = ""
    Me.tbCap2.Text = ""
    riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2, "")
    Me.tbProvincia2.Text = ""
    Me.tbNote.Text = ""
    Me.tbZona.Text = ""
    Me.tbTelefono2.Text = ""

    Me.RFRagioneSocialeA.Enabled = False
    Me.RFIndirizzo2.Enabled = False
    Me.RFCitta2.Enabled = False
    Me.RFProvincia2.Enabled = False
    Me.RFCap2.Enabled = False
    Me.RFTelefono2.Enabled = False

    End Sub


	Protected Sub clear_destinazione_alternativa()
		BindLstDestinazioneLstScegliIndirizzo
		Me.tbRagioneSocialeA.Text = ""
        Me.tbNomeA.Text = ""
        Me.tbIndirizzo2.Text = ""
        Me.tbCap2.Text = ""
        riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2, "")
        Me.tbProvincia2.Text = ""
        Me.tbNote.Text = ""
        Me.tbZona.Text = ""
		Me.tbTelefono2.Text = ""
	End Sub
	
    Protected Sub btnAnnullaDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnAnnullaDest.Click
        'btInviaOrdine.Enabled = True
		clear_destinazione_alternativa
		Session("cityBinding") = 0
    End Sub

    Protected Sub LstScegliIndirizzo_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles LstScegliIndirizzo.PreRender

    Dim selectedId As Integer = 0

    If LstScegliIndirizzo.Items.Count > 0 Then

        ' Se non selezionato, provo a impostare il predefinito (senza generare eccezioni se non esiste in lista)
        If Val(LstScegliIndirizzo.SelectedValue) <= 0 Then
            Dim prefId As Integer = calcola_indirizzo_spedizione_predefinito()
            If prefId > 0 AndAlso LstScegliIndirizzo.Items.FindByValue(prefId.ToString()) IsNot Nothing Then
                LstScegliIndirizzo.SelectedValue = prefId.ToString()
            Else
                LstScegliIndirizzo.SelectedIndex = 0
            End If
        End If

        Integer.TryParse(LstScegliIndirizzo.SelectedValue, selectedId)

        ' Compilo tab spedizione (se ho un ID valido)
        If selectedId > 0 Then
            compila_campi_destinazione_alternativa_o_indirizzo_spedizione(selectedId, Lst.indirizzoSpedizione)
        End If

        Me.CHKPREDEFINITO.Visible = True
    Else
        Me.CHKPREDEFINITO.Visible = False
    End If

    ' FIX: SelectedItem può essere Nothing se Items.Count=0
    Session("SCEGLIINDIRIZZO") = selectedId

    Dim cityBinding As Integer = 0
    If Session("cityBinding") IsNot Nothing Then Integer.TryParse(Session("cityBinding").ToString(), cityBinding)

    If cityBinding <> 1 Then
        open1.Style.Item("display") = ""
        open2.Style.Item("display") = ""
        panel.Style.Item("display") = "none"

        ' Mantengo la logica originale: aggiorno campi destinazione alternatica coerenti con selezione
        compila_campi_destinazione_alternativa_o_indirizzo_spedizione(selectedId, Lst.destinazioneAlternativa)
    Else
        open1.Style.Item("display") = "none"
        open2.Style.Item("display") = "none"
        panel.Style.Item("display") = ""

        If insOmod.Value = "mod" Then
            btnModDest.Style.Item("display") = ""
            btnElimDest.Style.Item("display") = "none"
            btnSalvaDest.Style.Item("display") = "none"
        ElseIf insOmod.Value = "ins" Then
            btnModDest.Style.Item("display") = "none"
            btnElimDest.Style.Item("display") = "none"
            btnSalvaDest.Style.Item("display") = ""
        End If

        Session("cityBinding") = 0
    End If

    End Sub
	
    Protected Sub LstDestinazione_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles LstDestinazione.PreRender
        'If LstDestinazione.SelectedValue <= 0 Then
        '    LstDestinazione.SelectedValue = calcola_predefinito_destinazione_alternativa()
        'End If
		
        REM Session("DESTINAZIONEALTERNATIVA") = LstDestinazione.SelectedItem.Value

		REM btnElimDest.enabled = false
		REM btnModDest.enabled = false
		REM if LstDestinazione.Items(0).value = 0 then
			REM if Session("DESTINAZIONEALTERNATIVA") > 0 then
				REM LstDestinazione.Items.RemoveAt(0)
				REM btnModDest.enabled = true
				REM if LstDestinazione.items.count > 1 Then
					REM btnElimDest.enabled = true
				REM End If
			REM End If
		REM Else
			REM if LstDestinazione.items.count > 1 Then
				REM btnElimDest.enabled = true
				REM btnModDest.enabled = true
			REM End If
		REM End If

        REM 'Aggiorno i campi Text sottostanti per dar modo all'utente di modificare o inserire una nuova destinazione in modo facile
        REM if Session("VECCHIADESTINAZIONEALTERNATIVA") <> Session("DESTINAZIONEALTERNATIVA") Then
			REM compila_campi_destinazione_alternativa_o_indirizzo_spedizione(LstDestinazione.SelectedValue,Lst.destinazioneAlternativa)
			REM Session("VECCHIADESTINAZIONEALTERNATIVA") = Session("DESTINAZIONEALTERNATIVA")
		REM End if
    End Sub

    Protected Sub LstDestinazione_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles LstDestinazione.SelectedIndexChanged
		Session("VECCHIADESTINAZIONEALTERNATIVA") = Session("DESTINAZIONEALTERNATIVA")
        'If LstDestinazione.SelectedItem.Value <> "0" Then
        '    Session("DESTINAZIONEALTERNATIVA") = LstDestinazione.SelectedItem.Value
        'Else
        '    Session("DESTINAZIONEALTERNATIVA") = 0
        'End If
		
    End Sub

    Function calcola_indirizzo_spedizione_predefinito() As Integer
        Dim predefinito As Integer = 0
        Dim params As New Dictionary(Of String, String)
        params.add("@UtenteId", GetUtentiIdSafe(0).ToString())
        Dim dr = ExecuteQueryGetDataReader("id", "utentiindirizzi", "(UtenteId=@UtenteId) AND (Predefinito=1)", params)
        dr.Read()

        If dr.HasRows = True Then
            predefinito = dr.Item("id")
        End If

        dr.Close()

        Return predefinito
    End Function

    Private Function compila_campi_destinazione_alternativa_o_indirizzo_spedizione(ByVal idDestinazione As Integer, ByVal tipolst As Lst) As Integer

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Return 0
    If idDestinazione <= 0 Then Return 0

    Try
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()

            Using cmd As New MySqlCommand("SELECT * FROM utentiindirizzi WHERE ID=@id AND UtenteId=@UtentiId LIMIT 1", conn)
                cmd.CommandType = CommandType.Text
                cmd.Parameters.AddWithValue("@id", idDestinazione)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)

                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    If dr.Read() Then

                        If tipolst = Lst.destinazioneAlternativa Then

                            tbRagioneSocialeA.Text = If(IsDBNull(dr("RagioneSocialeA")), "", dr("RagioneSocialeA").ToString())
                            tbNomeA.Text = If(IsDBNull(dr("NomeA")), "", dr("NomeA").ToString())
                            tbIndirizzo2.Text = If(IsDBNull(dr("IndirizzoA")), "", dr("IndirizzoA").ToString())

                            Dim capA As String = If(IsDBNull(dr("CapA")), "", dr("CapA").ToString())
                            Dim cittaA As String = If(IsDBNull(dr("CittaA")), "", dr("CittaA").ToString())

                            riempi_ddl_citta(capA, ddlCitta2, tbProvincia2, cittaA)

                            tbCap2.Text = capA
                            tbProvincia2.Text = If(IsDBNull(dr("ProvinciaA")), "", dr("ProvinciaA").ToString())
                            tbZona.Text = If(IsDBNull(dr("Zona")), "", dr("Zona").ToString())
                            tbTelefono2.Text = If(IsDBNull(dr("TelefonoA")), "", dr("TelefonoA").ToString())
                            tbNote.Text = If(IsDBNull(dr("Note")), "", dr("Note").ToString())

                            Dim pref As Integer = 0
                            If Not IsDBNull(dr("Predefinito")) Then Integer.TryParse(dr("Predefinito").ToString(), pref)
                            CHKPREDEFINITO.Checked = (pref = 1)

                        Else
                            lblTab_RagioneSocialeSpedizione.Text = If(IsDBNull(dr("RagioneSocialeA")), "", dr("RagioneSocialeA").ToString())
                            lblTab_NomeSpedizione.Text = If(IsDBNull(dr("NomeA")), "", dr("NomeA").ToString())
                            lblTab_IndirizzoSpedizione.Text = If(IsDBNull(dr("IndirizzoA")), "", dr("IndirizzoA").ToString())
                            lblTab_CittaSpedizione.Text = If(IsDBNull(dr("CittaA")), "", dr("CittaA").ToString())
                            lblTab_CapSpedizione.Text = If(IsDBNull(dr("CapA")), "", dr("CapA").ToString())
                            lblTab_ProvinciaSpedizione.Text = If(IsDBNull(dr("ProvinciaA")), "", dr("ProvinciaA").ToString())
                            lblTab_ZonaSpedizione.Text = If(IsDBNull(dr("Zona")), "", dr("Zona").ToString())
                            lblTab_TelSpedizione.Text = If(IsDBNull(dr("TelefonoA")), "", dr("TelefonoA").ToString())
                            lblTab_NotaDestinazione.Text = If(IsDBNull(dr("Note")), "", dr("Note").ToString())
                        End If

                    End If
                End Using
            End Using
        End Using

    Catch ex As Exception
        LogEx(ex, "compila_campi_destinazione_alternativa_o_indirizzo_spedizione")
    End Try

    Return 0
End Function

    Protected Sub gvArticoliGratis_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles gvArticoliGratis.PreRender
    Dim i As Integer

    For i = 0 To gvArticoliGratis.Items.Count - 1

        Dim img As Image = TryCast(gvArticoliGratis.Items(i).FindControl("imgDispo"), Image)
        Dim dispo As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblDispo"), Label)
        Dim arrivo As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblArrivo"), Label)
        Dim importo As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblImporto"), Label)
        Dim importoIvato As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblImportoIvato"), Label)
        Dim peso As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblPeso"), Label)
        Dim tbQta As TextBox = TryCast(gvArticoliGratis.Items(i).FindControl("tbQta"), TextBox)

        Dim qtaRiga As Integer = SafeIntFromText(If(tbQta IsNot Nothing, tbQta.Text, "0"), 0)
        qta += qtaRiga

        If qtaRiga <= 0 Then
            Continue For
        End If

        ' visibilità prezzi e totale merce
        If IvaTipo = 1 Then
            If importo IsNot Nothing Then importo.Visible = True
            If importoIvato IsNot Nothing Then importoIvato.Visible = False
            Dim lblPrezzo As Control = gvArticoliGratis.Items(i).FindControl("lblprezzo")
            Dim lblPrezzoIvato As Control = gvArticoliGratis.Items(i).FindControl("lblprezzoivato")
            If lblPrezzo IsNot Nothing Then lblPrezzo.Visible = True
            If lblPrezzoIvato IsNot Nothing Then lblPrezzoIvato.Visible = False

            TotaleMerce += SafeDblFromText(If(importo IsNot Nothing, importo.Text, "0"), 0)

        ElseIf IvaTipo = 2 Then
            If importo IsNot Nothing Then importo.Visible = False
            If importoIvato IsNot Nothing Then importoIvato.Visible = True
            Dim lblPrezzo As Control = gvArticoliGratis.Items(i).FindControl("lblprezzo")
            Dim lblPrezzoIvato As Control = gvArticoliGratis.Items(i).FindControl("lblprezzoivato")
            If lblPrezzo IsNot Nothing Then lblPrezzo.Visible = False
            If lblPrezzoIvato IsNot Nothing Then lblPrezzoIvato.Visible = True

            TotaleMerce += SafeDblFromText(If(importoIvato IsNot Nothing, importoIvato.Text, "0"), 0)
        End If

        Session("TotaleMerce") = TotaleMerce

        Dim impNetto As Double = SafeDblFromText(If(importo IsNot Nothing, importo.Text, "0"), 0)
        Dim impIvato As Double = SafeDblFromText(If(importoIvato IsNot Nothing, importoIvato.Text, "0"), 0)

        imponibile += impNetto
        calcolo_iva += (impIvato - impNetto)

        imponibile_gratis += impNetto
        totale += impIvato

        Dim pesoVal As Double = SafeDblFromText(If(peso IsNot Nothing, peso.Text, "0"), 0)
        If pesoVal <> 0 Then
            pesoTotale += pesoVal
        End If

        ' disponibilità
        If DispoTipo = 1 Then
            Dim dispoDouble As Double = 0
            Dim dispoTxt As String = If(If(dispo IsNot Nothing, dispo.Text, ""), "").Replace("−", "-").Replace(">", "").Trim()
            Double.TryParse(dispoTxt.Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, dispoDouble)

            If dispoDouble > DispoMinima Then
                If img IsNot Nothing Then
                    img.ImageUrl = "~/images/verde.gif"
                    img.AlternateText = "Disponibile"
                End If
            ElseIf dispoDouble > 0 Then
                If img IsNot Nothing Then
                    img.ImageUrl = "~/images/giallo.gif"
                    img.AlternateText = "Disponibilità Scarsa"
                End If
            Else
                Dim arrivoDouble As Double = 0
                Dim arrTxt As String = If(arrivo IsNot Nothing, arrivo.Text, "0")
                Double.TryParse(arrTxt.Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, arrivoDouble)

                If arrivoDouble > 0 Then
                    If img IsNot Nothing Then
                        img.ImageUrl = "~/images/azzurro.gif"
                        img.AlternateText = "In Arrivo"
                    End If
                Else
                    If img IsNot Nothing Then
                        img.ImageUrl = "~/images/rosso.gif"
                        img.AlternateText = "Non Disponibile"
                    End If
                End If
            End If
        ElseIf DispoTipo = 2 Then
            If img IsNot Nothing Then img.Visible = False
            If dispo IsNot Nothing Then dispo.Visible = True
        End If

    Next
    End Sub

    Protected Sub gvVettoriPromo_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles gvVettoriPromo.PreRender
        Dim i As Integer = 0
        Dim Selezione_Vettore As RadioButton
        'Dim Selezione_Vettore_Temp As RadioButton

        If indice_riga_da_selezionare > -1 Then
            '(indice_riga_da_selezionare - 2) e non (indice_riga_da_selezionare - 1) perchè il DataRowBound viene fatto una volta in più
            Selezione_Vettore = Me.gvVettoriPromo.Rows(indice_riga_da_selezionare - 2).FindControl("rbSpedizione")
            Selezione_Vettore.Enabled = True
            Selezione_Vettore.Checked = True

            Selezionato_Vettore_Promo = 1
        End If

        'For i = 0 To Me.gvVettoriPromo.Rows.Count - 1
        'Selezione_Vettore = Me.gvVettoriPromo.Rows(i).FindControl("rbSpedizione")

        'If Selezione_Vettore.Enabled = True Then
        'Selezione_Vettore.Checked = True
        'Selezionato_Vettore_Promo = 1
        'End If

        'If ((i = 1) And (Selezione_Vettore.Enabled = True)) Then
        'Selezione_Vettore_Temp = Me.gvVettoriPromo.Rows(i - 1).FindControl("rbSpedizione")
        'Selezione_Vettore_Temp.Enabled = False

        'If Selezione_Vettore.Enabled = True Then
        'Selezione_Vettore.Checked = True
        'Selezionato_Vettore_Promo = 1
        'End If
        'End If
        'Next

        'Nel caso ci sia nel carrello SOLO prodotti GRATIS
        If (imponibile - imponibile_gratis = 0) Then
            Me.Panel_SpedizioneGratis.Visible = True
        Else
            Me.Panel_SpedizioneGratis.Visible = False
        End If
    End Sub

    Protected Sub rbSpedizioneGratis_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles rbSpedizioneGratis.PreRender
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand

        Dim AsssicurazionePercentuale As Double
        Dim AssicurazioneMinimo As Double
        Dim TotAssicurazione As Double

        If Me.rbSpedizioneGratis.Checked = True Then
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            cmd.Connection = conn

            conn.Open()

            cmd.CommandType = CommandType.Text
            If Session("AziendaID") = 1 Then
                cmd.CommandText = "SELECT * FROM vettori WHERE id=-1"
            Else
                cmd.CommandText = "SELECT * FROM vettori WHERE id=-2"
            End If

            Dim dr As MySqlDataReader = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows Then
                'Spedizione
                Me.lblSpeseSped.Text = String.Format("{0:c}", 0)

                If Session("AziendaID") = 1 Then
                    Me.tbVettoriId.Text = "-1"
                Else
                    Me.tbVettoriId.Text = "-2"
                End If

                'Assicurazione
                AsssicurazionePercentuale = dr.Item("AssicurazionePercentuale")
                AssicurazioneMinimo = dr.Item("AssicurazioneMinimo")

                Dim imponibileBase As Double = SafeMoney(Me.lblImponibile.Text, 0)
                TotAssicurazione = (AsssicurazionePercentuale * imponibileBase) / 100
                If TotAssicurazione < AssicurazioneMinimo Then
                    TotAssicurazione = AssicurazioneMinimo
                End If

                Me.lblAssicurazione.Text = String.Format("{0:c}", TotAssicurazione)

                'Contrassegno
                Me.tbContrFisso.Text = dr.Item("ContrassegnoFisso")
                Me.tbContrPerc.Text = dr.Item("ContrassegnoPercentuale")
                Me.tbContrMinimo.Text = dr.Item("ContrassegnoMinimo")

                AggiornaSpeseAssicurazione()

                If AsssicurazionePercentuale = 0 Then
                    Me.cbAssicurazione.Checked = False
                    Me.cbAssicurazione.Enabled = False
                Else
                    Me.cbAssicurazione.Enabled = True
                End If

                If dr.Item("ContrassegnoPercentuale") = 0 Then
                    RitiroSede = True
                Else
                    RitiroSede = False
                End If
            End If
        End If
    End Sub

    Protected Sub Page_PreRenderComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRenderComplete
        Dim imponibileVal As Double = SafeDbl(lblImponibile.Text, 0)
        Dim speseAssVal As Double = SafeDbl(lblSpeseAss.Text, 0)
        Dim speseSpedVal As Double = SafeDbl(lblSpeseSped.Text, 0)
        Dim pagamentoVal As Double = SafeDbl(lblPagamento.Text, 0)
        Dim buonoVal As Double = SafeDbl(lblBuonoSconto.Text, 0)
        Dim ivaVettoreVal As Double = SafeDbl(Session("Iva_Vettori"), 0)
        ' IVA utente: nel carrello è trattata come PERCENTUALE (es. 22) quando > -1
        Dim ivaUtentePerc As Double = SafeDblFromText(If(Session("Iva_Utente"), "-1").ToString(), -1)
        ' Per l'assicurazione: se l'utente non ha IVA propria, uso la default (preleva_ValoreIva(-1))
        Dim ivaAssPerc As Double = If(ivaUtentePerc > -1, ivaUtentePerc, preleva_ValoreIva(-1))

        
        'Nascondo i Pannelli quando non ci sono articoli nel carrello
        If (Me.gvArticoliGratis.Items.Count = 0) And (Me.Repeater1.items.Count = 0) Then
            Me.Panel_Unico.Visible = False
            Me.btContinua.Enabled = True
        Else
            Me.Panel_Unico.Visible = True
        End If

        If (controlla_articoli_quantita_zero() = 0) Then
            Qnt_Errata.Visible = True
        End If

        'Aggiorno una sola volta i prezzi degli articoli nel carrello
        'If (Request.QueryString("update") = Nothing) And (controlla_articoli_quantita_zero() = 1) Then
        'Aggiorna_Prezzi_Carrello()
        'Response.Redirect("carrello.aspx?update=1")
        'End If

        'Buono Sconto
        If (Val(Session("BuonoSconto_id")) > 0) Then
            TB_BuonoSconto.Text = getBuonoScontoCodice(Val(Session("BuonoSconto_id")))
            TB_BuonoSconto.Enabled = False
        Else
            TB_BuonoSconto.Enabled = True

            checkOKBuonoSconto.Visible = False
            lblBuonoSconto.Text = String.Format("{0:c}", 0)
            lblBuonoScontoIVA.Text = String.Format("{0:c}", 0)
        End If

        If (gvArticoliGratis.Items.Count > 0) Or (Repeater1.items.Count > 0) Then
            TB_BuonoSconto_TextChanged(TB_BuonoSconto, New System.EventArgs)
            GV_BuoniSconti.DataBind()
        Else
            GV_BuoniSconti.Visible = False
            Session("BuonoSconto_id") = 0
        End If

        'Aggiorno i Pagamenti ed i relativi costi
        'LeggiPagamenti()

        'Conteggi dell'iva
        Dim ivaNuova As Double = calcola_iva(speseSpedVal, ivaVettoreVal) + (speseAssVal * (ivaAssPerc / 100))
        lblIva.Text = "€ " & FormatNumber(ivaNuova, 2)

        Dim totaleDoc As Double = imponibileVal + ivaNuova + speseAssVal + speseSpedVal + pagamentoVal + buonoVal
        lblTotale.Text = "€ " & FormatNumber(totaleDoc, 2)


        'Aggiorno il valore del Buono Sconto
        If GV_BuoniSconti.Rows.Count > 0 Then
            Dim scontoPercentuale As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_Percentuale_BuonoSconto")
            Dim scontoFisso As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_scontoFisso_BuonoSconto")
            Dim scontoVettore As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_scontoVettore")
            Dim valoreBuonoSconto As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_valore_BuonoSconto")
            Dim totSconto As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_TotSconto")

            'Controllo che lo sconto da applicare non sia uno sconto vettore
    If Val(scontoVettore.Text) = 1 Then

    Dim spedTmp As Double = SafeMoney(lblSpeseSped.Text, 0)
    Dim ivaVettTmp As Double = SafeDblFromText(If(Session("Iva_Vettori"), "0").ToString(), 0)

    Dim scontoSped As Double = -(spedTmp + (spedTmp * (ivaVettTmp / 100)))
    lblBuonoSconto.Text = "€ " & FormatNumber(scontoSped, 2)

    Else

    Dim perc As Double = SafeDblFromText(scontoPercentuale.Text, 0)
    Dim valore As Double = SafeDblFromText(valoreBuonoSconto.Text, 0)

    Dim scontoCalc As Double
    If perc > 0 Then
        scontoCalc = (SafeDbl(TotaleMerce, 0) / 100) * valore
    Else
        scontoCalc = valore
    End If

    lblBuonoSconto.Text = "€ " & FormatNumber(-scontoCalc, 2)

    End If

    ' --- SEO hardening: carrello/checkout noindex + canonical + JSON-LD ---
Dim canonical As String = Request.Url.GetLeftPart(UriPartial.Path)

AddOrReplaceMeta(Me.Page, "robots", "noindex, nofollow")
SetCanonical(Me.Page, canonical)

Dim jsonLd As String = SeoBuilder.BuildSimplePageJsonLd(Me.Title,
                                                        "Checkout e riepilogo carrello su Taikun.",
                                                        canonical,
                                                        "CheckoutPage")
SeoBuilder.SetJsonLdOnMaster(Me, jsonLd)


            ' IVA per scorporare il buono: se l'utente ha IVA propria uso quella (percentuale), altrimenti default
            Dim ivaBuonoPerc As Double = If(ivaUtentePerc > -1, ivaUtentePerc, preleva_ValoreIva(-1))


            Dim buonoTot As Double = SafeMoney(lblBuonoSconto.Text, 0) ' totale sconto (negativo)
            Dim buonoImp As Double = Math.Round(buonoTot / (1 + (ivaBuonoPerc / 100)), 2, MidpointRounding.AwayFromZero)
            Dim buonoIva As Double = Math.Round(buonoTot - buonoImp, 2, MidpointRounding.AwayFromZero)

            lblBuonoScontoIVA.Text = "€ " & FormatNumber(buonoIva, 2)
            lblBuonoSconto.Text = "€ " & FormatNumber(buonoImp, 2)

            lblIva.Text = "€ " & FormatNumber(SafeMoney(lblIva.Text, 0) + buonoIva, 2)

            Dim totBuono As Double = SafeMoney(lblBuonoSconto.Text, 0) + SafeMoney(lblBuonoScontoIVA.Text, 0)
            totSconto.Text =
            IIf(SafeDblFromText(scontoPercentuale.Text, 0) > 0,
        "Sconto in percentuale " & SafeDblFromText(valoreBuonoSconto.Text, 0) & "%",
        IIf(Val(scontoVettore.Text) > 0, "SPEDIZIONE OMAGGIO", "Sconto fisso euro " & SafeDblFromText(valoreBuonoSconto.Text, 0))) &
        "<br/>" & String.Format("{0:c}", totBuono)
        End If

		Dim totaleTemp As Double =
            SafeMoney(lblImponibile.Text, 0) +
            SafeMoney(lblIva.Text, 0) +
            SafeMoney(lblSpeseAss.Text, 0) +
            SafeMoney(lblSpeseSped.Text, 0) +
            SafeMoney(lblPagamento.Text, 0) +
            SafeMoney(lblBuonoSconto.Text, 0)


            totaleTemp = Math.Round(totaleTemp, 2, MidpointRounding.AwayFromZero)
            lblTotale.Text = "€ " & FormatNumber(totaleTemp, 2)
 

        Session("Calcolo_Iva") = lblIva.Text

        'Simulo il Click del tasto btCompleta
        'If Page.IsPostBack = False Then
        '    btCompleta_Click(sender, e)
        '    LeggiPagamenti()
        '    LeggiVettori()
        'End If

        'Visualizzo o meno il pannello relativo ai Buoni Sconti, in base alle impostazioni nell'azienda
        If (Session("AbilitaBuoniScontiCarrello") = 1) AndAlso (TableConteggi.Visible = True) Then
            Panel_BuoniSconto.Visible = True
        Else
            Panel_BuoniSconto.Visible = False
        End If
    End Sub

    'Restituisce 1, se il controllo è andato a buon fine, altrimenti 0
    Function controlla_articoli_quantita_zero() As Integer
        Dim row As RepeaterItem

        'Controllo che non ci siano articoli con quantità zero
        If Repeater1.items.Count > 0 Then
            For Each row In Repeater1.items
                Dim Qta As TextBox = row.FindControl("tbQta")
                If (SafeInt(Qta.Text, 0) <= 0) Then
                    Return 0
                End If
            Next
        End If

        'Controllo che non ci siano articoli con quantità zero
        If Me.gvArticoliGratis.items.Count > 0 Then
            For Each row In gvArticoliGratis.items
                Dim Qta As TextBox = row.FindControl("tbQta")
                If (SafeInt(Qta.Text, 0) <= 0) Then
                    Return 0
                End If
            Next
        End If

        Return 1
    End Function

    Sub Aggiorna_Prezzi_Carrello()

    If _carrelloAggiornatoThisRequest Then Exit Sub
    _carrelloAggiornatoThisRequest = True

    If (controlla_articoli_quantita_zero() = 0) Then
        Qnt_Errata.Visible = True
        ' continuo comunque: salvo Qnt=0 come da logica originale
    End If

    ' 1) Raccolgo righe dal Repeater (normali + gratis) UNA volta
    Dim rows As New List(Of CartRowInfo)

    If Repeater1 IsNot Nothing AndAlso Repeater1.Items IsNot Nothing AndAlso Repeater1.Items.Count > 0 Then
        For Each it As RepeaterItem In Repeater1.Items
            Dim r As CartRowInfo = ReadCartRowFromItem(it)
            If r.Id > 0 AndAlso r.ArtId > 0 Then rows.Add(r)
        Next
    End If

    If gvArticoliGratis IsNot Nothing AndAlso gvArticoliGratis.Items IsNot Nothing AndAlso gvArticoliGratis.Items.Count > 0 Then
        For Each it As RepeaterItem In gvArticoliGratis.Items
            Dim r As CartRowInfo = ReadCartRowFromItem(it)
            If r.Id > 0 AndAlso r.ArtId > 0 Then rows.Add(r)
        Next
    End If

    If rows.Count = 0 Then Exit Sub

    ' 2) Lista ArtId univoci
    Dim artIds As New List(Of Integer)
    Dim seen As New HashSet(Of Integer)
    For Each r As CartRowInfo In rows
        If Not seen.Contains(r.ArtId) Then
            seen.Add(r.ArtId)
            artIds.Add(r.ArtId)
        End If
    Next

    Dim listino As Integer = SafeInt(GetListinoSafe(0), 0)
    Dim ivaUtentePct As Double = SafeDbl(Session("Iva_Utente"), -1) ' qui è “%” (o id=valore, come nel tuo impianto)
    Dim abRC As Boolean = (SafeInt(Session("AbilitatoIvaReverseCharge"), 0) = 1)

    Dim idEsenzioneIva As Integer = SafeInt(Session("IdEsenzioneIva"), -1)
    Dim valoreEsenzioneIva As Double = SafeDbl(Session("Iva_Utente"), -1)
    Dim descrEsenzioneIva As String = If(TryCast(Session("DescrizioneEsenzioneIva"), String), "")

    Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
        conn.Open()

        ' 3) Carico vsuperarticoli per tutti gli ArtId con UNA query
        Dim vsup As New Dictionary(Of Integer, List(Of VsuperInfo))

        Using cmdV As New MySqlCommand()
            cmdV.Connection = conn
            cmdV.CommandType = CommandType.Text

            Dim inNames As New List(Of String)
            For i As Integer = 0 To artIds.Count - 1
                Dim pName As String = "@a" & i.ToString()
                inNames.Add(pName)
                cmdV.Parameters.AddWithValue(pName, artIds(i))
            Next

            cmdV.Parameters.AddWithValue("@listino", listino)

            cmdV.CommandText =
                "SELECT ID, prezzo, prezzoIvato, InOfferta, OfferteDataInizio, OfferteDataFine, " &
                "OfferteQntMinima, OfferteMultipli, OfferteDettagliId, prezzopromo, prezzopromoIvato, " &
                "IdIvaRC, ValoreIvaRC, DescrizioneIvaRC " &
                "FROM vsuperarticoli " &
                "WHERE NListino=@listino AND ID IN (" & String.Join(",", inNames) & ") " &
                "ORDER BY ID, PrezzoPromo DESC"

            Using dr As MySqlDataReader = cmdV.ExecuteReader()
                While dr.Read()
                    Dim id As Integer = SafeInt(dr("ID"), 0)
                    If id <= 0 Then Continue While

                    Dim info As New VsuperInfo()
                    info.Prezzo = SafeDbl(dr("prezzo"), 0)
                    info.PrezzoIvato = SafeDbl(dr("prezzoIvato"), 0)
                    info.InOfferta = SafeInt(dr("InOfferta"), 0)

                    If Not IsDBNull(dr("OfferteDataInizio")) Then info.OfferteDataInizio = CDate(dr("OfferteDataInizio"))
                    If Not IsDBNull(dr("OfferteDataFine")) Then info.OfferteDataFine = CDate(dr("OfferteDataFine"))

                    info.OfferteQntMinima = CLng(SafeInt(dr("OfferteQntMinima"), 0))
                    info.OfferteMultipli = CLng(SafeInt(dr("OfferteMultipli"), 0))
                    info.OfferteDettagliId = CLng(SafeDbl(dr("OfferteDettagliId"), 0))

                    info.PrezzoPromo = SafeDbl(dr("prezzopromo"), 0)
                    info.PrezzoPromoIvato = SafeDbl(dr("prezzopromoIvato"), 0)

                    info.IdIvaRC = SafeInt(dr("IdIvaRC"), -1)
                    info.ValoreIvaRC = SafeDbl(dr("ValoreIvaRC"), -1)
                    info.DescrizioneIvaRC = If(TryCast(dr("DescrizioneIvaRC"), String), "")

                    If Not vsup.ContainsKey(id) Then
                        vsup(id) = New List(Of VsuperInfo)
                    End If
                    vsup(id).Add(info)
                End While
            End Using
        End Using

        ' 4) Preparo UPDATE UNA volta (N esecuzioni, stessa connessione)
        Using cmdU As New MySqlCommand()
            cmdU.Connection = conn
            cmdU.CommandType = CommandType.Text
            cmdU.CommandText =
                "UPDATE carrello SET " &
                "Qnt=@Qnt, OfferteDettaglioId=@OfferteDettaglioId, Prezzo=@Prezzo, PrezzoIvato=@PrezzoIvato, " &
                "IdIvaRC=@IdIvaRC, ValoreIvaRC=@ValoreIvaRC, DescrizioneIvaRC=@DescrizioneIvaRC, " &
                "IdEsenzioneIva=@IdEsenzioneIva, ValoreEsenzioneIva=@ValoreEsenzioneIva, DescrizioneEsenzioneIva=@DescrizioneEsenzioneIva " &
                "WHERE ID=@id"

            cmdU.Parameters.Add("@Qnt", MySqlDbType.Int64)
            cmdU.Parameters.Add("@OfferteDettaglioId", MySqlDbType.Int64)
            cmdU.Parameters.Add("@Prezzo", MySqlDbType.Double)
            cmdU.Parameters.Add("@PrezzoIvato", MySqlDbType.Double)
            cmdU.Parameters.Add("@IdIvaRC", MySqlDbType.Int32)
            cmdU.Parameters.Add("@ValoreIvaRC", MySqlDbType.Double)
            cmdU.Parameters.Add("@DescrizioneIvaRC", MySqlDbType.VarChar)
            cmdU.Parameters.Add("@IdEsenzioneIva", MySqlDbType.Int32)
            cmdU.Parameters.Add("@ValoreEsenzioneIva", MySqlDbType.Double)
            cmdU.Parameters.Add("@DescrizioneEsenzioneIva", MySqlDbType.VarChar)
            cmdU.Parameters.Add("@id", MySqlDbType.Int32)

            Dim today As Date = Date.Today

            For Each r As CartRowInfo In rows

                If Not vsup.ContainsKey(r.ArtId) OrElse vsup(r.ArtId).Count = 0 Then
                    ' niente record vsuperarticoli -> aggiorno solo quantità e pulisco offerta
                    cmdU.Parameters("@Qnt").Value = r.Qnt
                    cmdU.Parameters("@OfferteDettaglioId").Value = 0
                    cmdU.Parameters("@Prezzo").Value = 0
                    cmdU.Parameters("@PrezzoIvato").Value = 0
                    cmdU.Parameters("@IdIvaRC").Value = -1
                    cmdU.Parameters("@ValoreIvaRC").Value = -1
                    cmdU.Parameters("@DescrizioneIvaRC").Value = ""
                    cmdU.Parameters("@IdEsenzioneIva").Value = idEsenzioneIva
                    cmdU.Parameters("@ValoreEsenzioneIva").Value = valoreEsenzioneIva
                    cmdU.Parameters("@DescrizioneEsenzioneIva").Value = descrEsenzioneIva
                    cmdU.Parameters("@id").Value = r.Id
                    cmdU.ExecuteNonQuery()
                    Continue For
                End If

                Dim lst As List(Of VsuperInfo) = vsup(r.ArtId)
                Dim baseRow As VsuperInfo = lst(0)

                Dim prezzo As Double = baseRow.Prezzo
                Dim prezzoIvato As Double = 0
                Dim offId As Long = 0
                Dim promoApplied As Boolean = False
                Dim chosenPromoRow As VsuperInfo = Nothing

                ' Replica logica originale: scorro tutte le righe (ordinate per PrezzoPromo DESC)
                ' e tengo l’ULTIMA promo valida che matcha (quindi, di fatto, il prezzo promo più basso)
                For Each info As VsuperInfo In lst
                    If info.InOfferta = 1 AndAlso info.OfferteDataInizio.HasValue AndAlso info.OfferteDataFine.HasValue Then
                        If info.OfferteDataInizio.Value.Date <= today AndAlso info.OfferteDataFine.Value.Date >= today Then

                            Dim match As Boolean = False
                            If info.OfferteQntMinima > 0 AndAlso r.Qnt >= info.OfferteQntMinima Then match = True
                            If (Not match) AndAlso info.OfferteMultipli > 0 AndAlso (r.Qnt Mod info.OfferteMultipli = 0) Then match = True

                            If match Then
                                promoApplied = True
                                offId = info.OfferteDettagliId
                                prezzo = info.PrezzoPromo
                                chosenPromoRow = info
                            End If

                        End If
                    End If
                Next

                If promoApplied AndAlso chosenPromoRow IsNot Nothing Then
                    ' prezzoIvato su promo
                    If abRC AndAlso chosenPromoRow.IdIvaRC > -1 Then
                        prezzoIvato = prezzo * ((chosenPromoRow.ValoreIvaRC / 100) + 1)
                    ElseIf ivaUtentePct > -1 Then
                        prezzoIvato = prezzo * ((ivaUtentePct / 100) + 1)
                    Else
                        prezzoIvato = chosenPromoRow.PrezzoPromoIvato
                    End If
                Else
                    ' prezzoIvato su base
                    If abRC AndAlso baseRow.IdIvaRC > -1 Then
                        prezzoIvato = prezzo * ((baseRow.ValoreIvaRC / 100) + 1)
                    ElseIf ivaUtentePct > -1 Then
                        prezzoIvato = prezzo * ((ivaUtentePct / 100) + 1)
                    Else
                        prezzoIvato = baseRow.PrezzoIvato
                    End If
                End If

                ' Reverse charge: replico logica “abilitato + idIvaRC valido”
                Dim idIvaRC As Integer = -1
                Dim valoreIvaRC As Double = -1
                Dim descIvaRC As String = ""

                If abRC AndAlso baseRow.IdIvaRC > -1 Then
                    idIvaRC = baseRow.IdIvaRC
                    valoreIvaRC = baseRow.ValoreIvaRC
                    descIvaRC = baseRow.DescrizioneIvaRC
                End If

                cmdU.Parameters("@Qnt").Value = r.Qnt
                cmdU.Parameters("@OfferteDettaglioId").Value = offId
                cmdU.Parameters("@Prezzo").Value = prezzo
                cmdU.Parameters("@PrezzoIvato").Value = prezzoIvato
                cmdU.Parameters("@IdIvaRC").Value = idIvaRC
                cmdU.Parameters("@ValoreIvaRC").Value = valoreIvaRC
                cmdU.Parameters("@DescrizioneIvaRC").Value = descIvaRC
                cmdU.Parameters("@IdEsenzioneIva").Value = idEsenzioneIva
                cmdU.Parameters("@ValoreEsenzioneIva").Value = valoreEsenzioneIva
                cmdU.Parameters("@DescrizioneEsenzioneIva").Value = descrEsenzioneIva
                cmdU.Parameters("@id").Value = r.Id

                cmdU.ExecuteNonQuery()
            Next

        End Using
    End Using

    End Sub


    Protected Sub btSvuota_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btSvuota.Click
        Dim LoginId As Integer = Me.Session("LoginId")
        Dim SessionID As String = Me.Session.SessionID
        Me.sdsArticoli.DeleteParameters.Clear()
        If LoginId = 0 Then
            Me.sdsArticoli.DeleteParameters.Add("@SessionID", SessionID)
            Me.sdsArticoli.DeleteCommand = "delete from carrello where (SessionID=@SessionID)"
        Else
            Me.sdsArticoli.DeleteParameters.Add("@LoginId", LoginId)
            Me.sdsArticoli.DeleteCommand = "delete from carrello where (LoginId=@LoginId)"
        End If

        Me.sdsArticoli.Delete()
    End Sub

    Protected Sub btCompleta_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btCompleta.Click
        'Aggiorno i prodotti e il prezzo
        Aggiorna_Prezzi_Carrello()

        'Disabilito il completa ordine, quando già cliccato
        Me.btCompleta.Visible = False

        If Me.tOrdine.Visible = True Then
            Me.tOrdine.Visible = False
            Me.TableConteggi.Visible = False
            Me.btAggiorna.Enabled = True
            Me.btContinua.Enabled = True
            Me.btSvuota.Enabled = True
            'Me.Repeater1.DataBind()
            Me.lblPagamento.Text = String.Format("{0:c}", CDbl("0"))
            Me.lblSpeseSped.Text = String.Format("{0:c}", CDbl("0"))
            Me.lblSpeseAss.Text = String.Format("{0:c}", CDbl("0"))
            Me.lblPagamento.Text = String.Format("{0:c}", CDbl("0"))
        Else
            Me.TableConteggi.Visible = True
            Me.tOrdine.Visible = True
            Me.btAggiorna.Enabled = True
            Me.btContinua.Enabled = True
            Me.btSvuota.Enabled = True
        End If


        FillTableInfo()

        BindLstDestinazioneLstScegliIndirizzo

        'Me.LblDescrDest.Text = "Destinazione predefinita: " & vbCrLf & Me.getIndirizzoPrincipale

    End Sub

   Protected Sub btnModDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnModDest.Click

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Exit Sub

    Dim idSel As Integer = 0
    Integer.TryParse(If(LstScegliIndirizzo IsNot Nothing, LstScegliIndirizzo.SelectedValue, "0"), idSel)
    If idSel <= 0 Then Exit Sub

    Try
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text

                ' Se predefinito, resetto gli altri
                If CHKPREDEFINITO.Checked Then
                    cmd.CommandText = "UPDATE utentiindirizzi SET Predefinito=0 WHERE UtenteId=@UtentiId"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    cmd.ExecuteNonQuery()
                End If

                ' UPDATE parametrico corretto
                cmd.CommandText =
                    "UPDATE utentiindirizzi SET " &
                    "RAGIONESOCIALEA=@ragioneSocialeA, " &
                    "NOMEA=@nomeA, " &
                    "INDIRIZZOA=@indirizzo2, " &
                    "CAPA=@cap2, " &
                    "CITTAA=@citta, " &
                    "PROVINCIAA=@provincia, " &
                    "NOTE=@note, " &
                    "ZONA=@zona, " &
                    "TELEFONOA=@telefono2, " &
                    "PREDEFINITO=@predefinito " &
                    "WHERE Id=@Id AND UtenteId=@UtentiId"

                cmd.Parameters.Clear()
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                cmd.Parameters.AddWithValue("@Id", idSel)

                ' NOTA: niente Replace("'", "''") con query parametrizzate
                cmd.Parameters.AddWithValue("@ragioneSocialeA", (If(tbRagioneSocialeA.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@nomeA", (If(tbNomeA.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@indirizzo2", (If(tbIndirizzo2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@cap2", (If(tbCap2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@citta", (If(getDdlCittaValue(Me.ddlCitta2), "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@provincia", (If(tbProvincia2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@note", (If(tbNote.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@telefono2", (If(tbTelefono2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@zona", (If(tbZona.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@predefinito", If(CHKPREDEFINITO.Checked, 1, 0))

                cmd.ExecuteNonQuery()

                ' Se non è predefinito, garantisco che esista almeno 1 predefinito
                If Not CHKPREDEFINITO.Checked Then
                    cmd.CommandText = "UPDATE utentiindirizzi SET Predefinito=1 WHERE UtenteId=@UtentiId ORDER BY Id DESC LIMIT 1"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    cmd.ExecuteNonQuery()
                End If

            End Using
        End Using

        clear_destinazione_alternativa()

        Me.RFRagioneSocialeA.Enabled = False
        Me.RFIndirizzo2.Enabled = False
        Me.RFCitta2.Enabled = False
        Me.RFProvincia2.Enabled = False
        Me.RFCap2.Enabled = False
        Me.RFTelefono2.Enabled = False

    Catch ex As Exception
        LogEx(ex, "btnModDest_Click")
    End Try

End Sub
	
    Protected Sub btnSalvaDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnSalvaDest.Click

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Exit Sub

    Try
        ' (coerente con Page_Load: se loggato aggiorno tab)
        FillTableInfo()

        Dim setAsPredef As Boolean = False
        If CHKPREDEFINITO.Checked Then
            setAsPredef = True
        ElseIf LstScegliIndirizzo Is Nothing OrElse LstScegliIndirizzo.Items.Count = 0 Then
            setAsPredef = True
        End If

        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text
                cmd.Parameters.Clear()

                If setAsPredef Then
                    cmd.CommandText = "UPDATE utentiindirizzi SET Predefinito=0 WHERE UtenteId=@UtentiId"
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    cmd.ExecuteNonQuery()
                    cmd.Parameters.Clear()
                End If

                cmd.CommandText =
                    "INSERT INTO utentiindirizzi " &
                    "(UTENTEID, RAGIONESOCIALEA, NOMEA, INDIRIZZOA, CAPA, CITTAA, PROVINCIAA, NOTE, TELEFONOA, ZONA, PREDEFINITO) " &
                    "VALUES " &
                    "(@utentiId, @ragioneSocialeA, @nomeA, @indirizzo2, @cap2, @citta, @provincia, @note, @telefono2, @zona, @predefinito)"

                cmd.Parameters.AddWithValue("@utentiId", utentiId)

                ' NOTA: niente Replace("'", "''") con query parametrizzate
                cmd.Parameters.AddWithValue("@ragioneSocialeA", (If(tbRagioneSocialeA.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@nomeA", (If(tbNomeA.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@indirizzo2", (If(tbIndirizzo2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@cap2", (If(tbCap2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@citta", (If(getDdlCittaValue(Me.ddlCitta2), "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@provincia", (If(tbProvincia2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@note", (If(tbNote.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@telefono2", (If(tbTelefono2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@zona", (If(tbZona.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@predefinito", If(setAsPredef, 1, 0))

                cmd.ExecuteNonQuery()

            End Using
        End Using

        clear_destinazione_alternativa()

        Me.RFRagioneSocialeA.Enabled = False
        Me.RFIndirizzo2.Enabled = False
        Me.RFCitta2.Enabled = False
        Me.RFProvincia2.Enabled = False
        Me.RFCap2.Enabled = False
        Me.RFTelefono2.Enabled = False

    Catch ex As Exception
        LogEx(ex, "btnSalvaDest_Click")
    End Try

End Sub

    Protected Sub btnElimDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnElimDest.Click

    If LstScegliIndirizzo Is Nothing OrElse LstScegliIndirizzo.Items.Count <= 1 Then Exit Sub

    Dim idSel As Integer = 0
    Integer.TryParse(LstScegliIndirizzo.SelectedValue, idSel)
    If idSel <= 0 Then Exit Sub

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Exit Sub

    Try
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text

                ' 1) Leggo se l'indirizzo è predefinito
                cmd.CommandText = "SELECT Predefinito FROM utentiindirizzi WHERE Id=@id AND UtenteId=@UtentiId LIMIT 1"
                cmd.Parameters.Clear()
                cmd.Parameters.AddWithValue("@id", idSel)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)

                Dim predefinito As Integer = 0
                Dim obj As Object = cmd.ExecuteScalar()
                If obj IsNot Nothing AndAlso obj IsNot DBNull.Value Then
                    Integer.TryParse(obj.ToString(), predefinito)
                End If

                ' 2) Cancello
                cmd.CommandText = "DELETE FROM utentiindirizzi WHERE Id=@id AND UtenteId=@UtentiId"
                cmd.Parameters.Clear()
                cmd.Parameters.AddWithValue("@id", idSel)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                cmd.ExecuteNonQuery()

                ' 3) Se ho cancellato il predefinito, imposto predefinito l'ultimo rimasto
                If predefinito = 1 Then
                    cmd.CommandText = "UPDATE utentiindirizzi SET Predefinito=1 WHERE UtenteId=@UtentiId ORDER BY Id DESC LIMIT 1"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    cmd.ExecuteNonQuery()
                End If

            End Using
        End Using

        clear_destinazione_alternativa()

        Me.RFRagioneSocialeA.Enabled = False
        Me.RFIndirizzo2.Enabled = False
        Me.RFCitta2.Enabled = False
        Me.RFProvincia2.Enabled = False
        Me.RFCap2.Enabled = False
        Me.RFTelefono2.Enabled = False

    Catch ex As Exception
        LogEx(ex, "btnElimDest_Click")
    End Try

End Sub

    'Mi permette di leggere dal vettore l'IVA impostata per il Vettori
    Function IvaVettore(ByVal idVettore As Integer) As Double
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim temp_iva As Double = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT vettori.*, iva.Valore FROM vettori LEFT JOIN iva ON vettori.iva=iva.id WHERE vettori.id= @IdVettore"
		cmd.Parameters.AddWithValue("@IdVettore",idVettore)
        dr = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows = True Then
            temp_iva = dr.Item("Valore")
        End If

        dr.Close()
        conn.Close()

        Return temp_iva
    End Function

    Function preleva_ValoreIva(ByVal idIva As Integer) As Double
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim temp_iva As Double = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text

        If idIva = -1 Then
            cmd.CommandText = "SELECT iva.Valore FROM ivadefault INNER JOIN iva ON ivadefault.IvaVId=iva.id WHERE CURDATE() BETWEEN dal AND al"
        Else
			cmd.Parameters.AddWithValue("@idIva",idIva)
            cmd.CommandText = "SELECT iva.Valore FROM iva WHERE iva.id=@idIva"
        End If


        dr = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows = True Then
            temp_iva = dr.Item("Valore")
        End If

        dr.Close()
        conn.Close()

        Return temp_iva
    End Function

    Function preleva_IdIva(ByVal idIva As Integer) As Integer
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim risultato As Integer = 0

        If idIva = -1 Then
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text

            cmd.CommandText = "SELECT IvaVid FROM ivadefault INNER JOIN iva ON ivadefault.IvaVId=iva.id WHERE CURDATE() BETWEEN dal AND al"

            dr = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows = True Then
                risultato = dr.Item("IvaVid")
            End If

            dr.Close()
            conn.Close()
        Else
            risultato = idIva
        End If

        Return risultato
    End Function

    Function calcola_iva(ByVal Spese_Spedizione As Double, ByVal ValoreIvaVettore As Integer) As Double

    Dim tot_iva As Double = 0

    ' Iva utente: qui è trattata come PERCENTUALE (es. 22) quando > -1
    Dim ivaUtentePerc As Double = -1
    If Session("Iva_Utente") IsNot Nothing Then
        ivaUtentePerc = SafeDblFromText(Session("Iva_Utente").ToString(), -1)
    End If

    Dim rcEnabled As Boolean = (GetSessionInt("AbilitatoIvaReverseCharge", 0) = 1)

    ' -------------------- ARTICOLI NORMALI (Repeater1) --------------------
    If Repeater1.Items.Count > 0 Then
        For Each row As RepeaterItem In Repeater1.Items

            Dim lblValoreIva As Label = CType(row.FindControl("lblValoreIva"), Label)
            Dim lblIdIvaRC As Label = CType(row.FindControl("lblidIvaRC"), Label)
            Dim lblPrezzo As Label = CType(row.FindControl("lblPrezzo"), Label)
            Dim tbQta As TextBox = CType(row.FindControl("tbQta"), TextBox)

            Dim qnt As Integer = SafeIntFromText(If(tbQta IsNot Nothing, tbQta.Text, "0"), 0)
            If qnt <= 0 Then Continue For

            Dim prezzoNetto As Double = SafeMoney(If(lblPrezzo IsNot Nothing, lblPrezzo.Text, "0"), 0)

            Dim ivaPerc As Double = 0

            ' Caso esenzione / IVA utente personalizzata (percentuale)
            If ivaUtentePerc > -1 Then

                ivaPerc = ivaUtentePerc

            Else
                ' Caso Reverse Charge: qui prendo il valore IVA dalla tabella IVA (id in lblIdIvaRC)
                Dim idRc As Integer = SafeIntFromText(If(lblIdIvaRC IsNot Nothing, lblIdIvaRC.Text, "-1"), -1)

                If rcEnabled AndAlso idRc <> -1 Then
                    ivaPerc = preleva_ValoreIva(idRc)
                Else
                    ivaPerc = SafeDblFromText(If(lblValoreIva IsNot Nothing, lblValoreIva.Text, "0"), 0)
                End If
            End If

            tot_iva += (prezzoNetto * qnt) * (ivaPerc / 100)

        Next
    End If

    ' -------------------- ARTICOLI GRATIS (gvArticoliGratis) --------------------
    If gvArticoliGratis.Items.Count > 0 Then
        For Each row As RepeaterItem In gvArticoliGratis.Items

            Dim lblValoreIva As Label = CType(row.FindControl("lblValoreIva"), Label)
            Dim lblIdIvaRC As Label = CType(row.FindControl("lblidIvaRC"), Label)
            Dim lblPrezzo As Label = CType(row.FindControl("lblPrezzo"), Label)
            Dim tbQta As TextBox = CType(row.FindControl("tbQta"), TextBox)

            Dim qnt As Integer = SafeIntFromText(If(tbQta IsNot Nothing, tbQta.Text, "0"), 0)
            If qnt <= 0 Then Continue For

            Dim prezzoNetto As Double = SafeMoney(If(lblPrezzo IsNot Nothing, lblPrezzo.Text, "0"), 0)

            Dim ivaPerc As Double = 0

            If ivaUtentePerc > -1 Then
                ivaPerc = ivaUtentePerc
            Else
                Dim idRc As Integer = SafeIntFromText(If(lblIdIvaRC IsNot Nothing, lblIdIvaRC.Text, "-1"), -1)

                If rcEnabled AndAlso idRc <> -1 Then
                    ivaPerc = preleva_ValoreIva(idRc)
                Else
                    ivaPerc = SafeDblFromText(If(lblValoreIva IsNot Nothing, lblValoreIva.Text, "0"), 0)
                End If
            End If

            tot_iva += (prezzoNetto * qnt) * (ivaPerc / 100)

        Next
    End If

    ' IVA sulle spese di spedizione
    tot_iva += Spese_Spedizione * (ValoreIvaVettore / 100)

    Return Math.Round(tot_iva, 2, MidpointRounding.AwayFromZero)

    End Function

	
    Protected Sub Repeater1_ItemCommand(ByVal sender As Object, ByVal e As RepeaterCommandEventArgs) Handles Repeater1.ItemCommand
		If e.CommandName = "Aggiorna" Then
            btAggiorna_Click(sender, e)
        End If

        If e.CommandName = "Elimina" Then
            eliminaRigaCarrello(e.CommandArgument)
        End If
    End Sub

    Protected Sub gvArticoliGratis_ItemCommand(ByVal sender As Object, ByVal e As RepeaterCommandEventArgs) Handles gvArticoliGratis.ItemCommand
        If e.CommandName = "Aggiorna" Then
            btAggiorna_Click(sender, e)
        End If

        If e.CommandName = "Elimina" Then
            eliminaRigaCarrello(e.CommandArgument)
        End If
    End Sub

    Public Sub eliminaRigaCarrello(ByVal id As Integer)
    Dim conn As New MySqlConnection
    Dim cmd As New MySqlCommand

    Try
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn
        conn.Open()

        cmd.CommandText = "DELETE FROM carrello WHERE (Id = @Id)"
        cmd.Parameters.Clear()
        cmd.Parameters.AddWithValue("@Id", id)

        cmd.ExecuteNonQuery()
    Catch
        ' (mantengo comportamento originale: nessun messaggio)
    Finally
        Try : conn.Close() : Catch : End Try
    End Try
    End Sub

    Protected Sub TB_BuonoSconto_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles TB_BuonoSconto.TextChanged

    Dim codice As String = If(TB_BuonoSconto.Text, "").Trim()
    If codice.Length <= 0 Then Exit Sub

    ' Recupero valori Session in modo sicuro (mantengo le stesse chiavi che usi nel codice attuale)
    Dim aziendaId As Integer = 0
    If Session("AziendaID") IsNot Nothing Then Integer.TryParse(Session("AziendaID").ToString(), aziendaId)

    Dim utenteId As Integer = GetUtentiIdSafe(0)
    If Session("UtentiId") IsNot Nothing Then Integer.TryParse(Session("UtentiId").ToString(), utenteId)

    Dim listino As String = GetListinoSafeString("")

    Dim totaleMerce As Double = 0
    If Session("TotaleMerce") IsNot Nothing Then
        Double.TryParse(Session("TotaleMerce").ToString(), NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), totaleMerce)
    End If

    ' Verifica applicabilità
    Dim ok As Integer = VerificaBuonoSconto(listaArticoliInCarrello(), codice, aziendaId, listino, utenteId, totaleMerce)

    If ok <> 0 Then

        Dim idBuono As Integer = 0

        ' FIX: connessione/command in Using, niente DataReader per un singolo ID
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString),
              cmd As New MySqlCommand("SELECT id FROM buoni_sconti WHERE buonoSconto=@CodiceBuonoSconto LIMIT 1", conn)

            cmd.Parameters.AddWithValue("@CodiceBuonoSconto", codice)

            conn.Open()
            Dim obj As Object = cmd.ExecuteScalar()

            If obj IsNot Nothing AndAlso obj IsNot DBNull.Value Then
                Integer.TryParse(obj.ToString(), idBuono)
            End If
        End Using

        If idBuono > 0 Then
            Session("BuonoSconto_id") = idBuono

            TB_BuonoSconto.Enabled = False

            checkOKBuonoSconto.Visible = True
            checkNOBuonoSconto.Visible = False

            'Descrizione convalida Codice Sconto
            lblBuonoScontoConvalida.Text = "Buono Sconto Applicato"
            lblBuonoScontoConvalida.ForeColor = Drawing.Color.Green
            lblBuonoScontoConvalida.Font.Size = 8

            'Nascondo il pulsante Applica Codice Sconto
            BT_ApplicaBuonoSconto.Enabled = False

            'Visualizzo pulsante di cancellazione BuonoSconto
            LB_CancelBuonoSconto.Visible = True
        Else
            ' Caso raro: Verifica ok ma record non trovato => tratto come non valido
            Session("BuonoSconto_id") = Nothing

            TB_BuonoSconto.Enabled = True
            lblBuonoSconto.Text = String.Format("{0:c}", 0)
            lblBuonoScontoIVA.Text = String.Format("{0:c}", 0)

            checkOKBuonoSconto.Visible = False
            checkNOBuonoSconto.Visible = True

            lblBuonoScontoConvalida.Text = "Buono Sconto non valido"
            lblBuonoScontoConvalida.ForeColor = Drawing.Color.Red
            lblBuonoScontoConvalida.Font.Size = 8

            BT_ApplicaBuonoSconto.Enabled = True
            LB_CancelBuonoSconto.Visible = False
        End If

    Else
        Session("BuonoSconto_id") = Nothing

        TB_BuonoSconto.Enabled = True
        lblBuonoSconto.Text = String.Format("{0:c}", 0)
        lblBuonoScontoIVA.Text = String.Format("{0:c}", 0)

        checkOKBuonoSconto.Visible = False
        checkNOBuonoSconto.Visible = True

        lblBuonoScontoConvalida.Text = "Buono Sconto non valido"
        lblBuonoScontoConvalida.ForeColor = Drawing.Color.Red
        lblBuonoScontoConvalida.Font.Size = 8

        BT_ApplicaBuonoSconto.Enabled = True
        LB_CancelBuonoSconto.Visible = False
    End If

    End Sub


    Public Function listaArticoliInCarrello() As String
    Dim stringa As String = ""

    Dim LoginId As Integer = 0
    If Session("LoginId") IsNot Nothing Then
        Integer.TryParse(Session("LoginId").ToString(), LoginId)
    End If

    Dim SessionID As String = ""
    If Session IsNot Nothing AndAlso Session.SessionID IsNot Nothing Then
        SessionID = Session.SessionID
    End If

    Dim listino As String = GetListinoSafeString()

    Dim whereUserId As String = ""

    Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString),
          cmd As New MySqlCommand()

        cmd.Connection = conn

        Dim Sqlstring As String = "SELECT vcarrello.*, articoli.SpedizioneGratis_Listini, articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine, taglie.descrizione as taglia, colori.descrizione as colore FROM vcarrello"
        Sqlstring &= " LEFT OUTER JOIN articoli ON vcarrello.ArticoliId = articoli.id"
        Sqlstring &= " LEFT OUTER JOIN articoli_tagliecolori ON vcarrello.TCid = articoli_tagliecolori.id"
        Sqlstring &= " LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id"
        Sqlstring &= " LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"

        If LoginId = 0 Then
            cmd.Parameters.AddWithValue("@SessionId", SessionID)
            whereUserId = "(SessionId=@SessionId)"
        Else
            cmd.Parameters.AddWithValue("@LoginId", LoginId)
            whereUserId = "(LoginId=@LoginId)"
        End If

        cmd.Parameters.AddWithValue("@Listino", listino)

        Dim query As String =
            Sqlstring & " WHERE " & whereUserId &
            " AND (articoli.SpedizioneGratis_Listini = '' " &
            " OR (articoli.SpedizioneGratis_Listini <> '' AND (" &
            "     SpedizioneGratis_Listini NOT LIKE CONCAT('%', @Listino, ';%') " &
            "     OR SpedizioneGratis_Data_Fine < CURDATE() " &
            "     OR (SpedizioneGratis_Listini LIKE CONCAT('%', @Listino, ';%') AND SpedizioneGratis_Data_Inizio <= CURDATE() AND (SpedizioneGratis_Data_Fine >= CURDATE() OR SpedizioneGratis_Data_Fine IS NULL))" &
            " ))) ORDER BY vcarrello.id"

        cmd.CommandText = query

        conn.Open()

        Using dr As MySqlDataReader = cmd.ExecuteReader()
            While dr.Read()
                Dim artId As String = ""
                If Not IsDBNull(dr("articoliid")) Then
                    artId = dr("articoliid").ToString()
                End If

                If artId <> "" Then
                    If stringa.Trim().Length = 0 Then
                        stringa = artId
                    Else
                        stringa &= "," & artId
                    End If
                End If
            End While
        End Using

    End Using

    Return stringa
End Function


Public Function VerificaBuonoSconto(ByVal articoli As String, ByVal buonosconto As String, ByVal azienda As Integer, ByVal listino As String, ByVal utenteid As Integer, ByVal totaleMerceCarrello As Double) As Integer
    Dim retval As Integer = 0

    Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString),
          cmd As New MySqlCommand()

        cmd.Connection = conn
        conn.Open()

        ' 1) Verifica utilizzo già avvenuto (documenti)
        cmd.Parameters.Clear()
        cmd.CommandText = "SELECT id FROM documenti WHERE codicebuonosconto=@buonoSconto AND utentiid=@utenteid LIMIT 1"
        cmd.Parameters.AddWithValue("@buonoSconto", buonosconto)
        cmd.Parameters.AddWithValue("@utenteid", utenteid)

        Dim objUso As Object = cmd.ExecuteScalar()
        Dim verificaUtilizzoBuonoSconto As Integer = 0
        If objUso IsNot Nothing AndAlso objUso IsNot DBNull.Value Then
            Integer.TryParse(objUso.ToString(), verificaUtilizzoBuonoSconto)
        End If

        If verificaUtilizzoBuonoSconto <> 0 AndAlso getUtilizzoBuonoSconto(buonosconto, azienda) = 1 Then
            Return 0
        End If

        ' 2) Recupero sSql da buoni_sconti (ATTENZIONE: è SQL salvato nel DB; lo uso come da logica esistente)
        cmd.Parameters.Clear()
        cmd.CommandText =
            "SELECT sSql FROM Buoni_Sconti " &
            "WHERE buonosconto=@buonoSconto AND idAzienda=@azienda " &
            "AND ListaListini LIKE CONCAT('%,', @listino, ',%') " &
            "AND (listautentiid=',' OR listautentiid LIKE CONCAT('%,', @utenteid, ',%')) " &
            "AND sogliaprezzo<=@totaleMerceCarrello " &
            "AND CURDATE() BETWEEN datainizio AND datafine " &
            "LIMIT 1"

        cmd.Parameters.AddWithValue("@buonoSconto", buonosconto)
        cmd.Parameters.AddWithValue("@azienda", azienda)
        cmd.Parameters.AddWithValue("@listino", listino)
        cmd.Parameters.AddWithValue("@utenteid", utenteid)
        cmd.Parameters.AddWithValue("@totaleMerceCarrello", CDec(totaleMerceCarrello))

        Dim tQueryObj As Object = cmd.ExecuteScalar()
        Dim tQuery As String = ""
        If tQueryObj IsNot Nothing AndAlso tQueryObj IsNot DBNull.Value Then
            tQuery = tQueryObj.ToString()
        End If

        If tQuery.Trim() <> "" Then
            ' Creo IN(...) parametrico a partire da "articoli" (lista ID)
            Dim ids As New List(Of Integer)
            If articoli IsNot Nothing Then
                For Each part As String In articoli.Split(","c)
                    Dim n As Integer
                    If Integer.TryParse(part.Trim(), n) Then
                        ids.Add(n)
                    End If
                Next
            End If

            If ids.Count = 0 Then
                Return 0
            End If

            Dim inParts As New List(Of String)
            cmd.Parameters.Clear()

            For i As Integer = 0 To ids.Count - 1
                Dim pName As String = "@id" & i.ToString()
                inParts.Add(pName)
                cmd.Parameters.AddWithValue(pName, ids(i))
            Next

            ' tQuery è una subquery SQL salvata nel DB (logica originale)
            cmd.CommandText =
                "SELECT CASE WHEN COUNT(articoli.id)>0 THEN 1 ELSE 0 END AS Trovato " &
                "FROM articoli INNER JOIN (" & tQuery & ") AS Test ON articoli.id=Test.id " &
                "WHERE Test.id IN (" & String.Join(",", inParts) & ")"

            Dim foundObj As Object = cmd.ExecuteScalar()
            If foundObj IsNot Nothing AndAlso foundObj IsNot DBNull.Value Then
                Dim n As Integer = 0
                Integer.TryParse(foundObj.ToString(), n)
                retval = n
            Else
                retval = 0
            End If
        End If

    End Using

    Return retval
End Function


Public Function controllaValiditaBuonoSconto(ByVal codiceBuono As String, Optional ByVal idAzienda As Integer = 0, Optional ByVal idArticolo As Integer = -1, Optional ByVal idUtente As Integer = -1, Optional ByVal idTipoUtente As Integer = -1, Optional ByVal idListinoUtente As Integer = -1) As Integer
    Dim operatoreLogico As String = ""
    Dim tipoOperatoreLogico As Integer = 0

    ' Inizializzo a -1 per rispettare la logica dei controlli " > -1 "
    Dim idMarca As Integer = -1
    Dim idSettore As Integer = -1
    Dim idCategoria As Integer = -1
    Dim idTipologia As Integer = -1
    Dim idGruppo As Integer = -1
    Dim idSottoGruppo As Integer = -1

    Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString),
          cmd As New MySqlCommand()

        cmd.Connection = conn
        conn.Open()

        If idArticolo > -1 Then
            cmd.Parameters.Clear()
            cmd.CommandText = "SELECT * FROM articoli WHERE id=@idArticolo"
            cmd.Parameters.AddWithValue("@idArticolo", idArticolo)

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                If dr.HasRows Then
                    dr.Read()
                    If Not IsDBNull(dr("MarcheId")) Then idMarca = Convert.ToInt32(dr("MarcheId"))
                    If Not IsDBNull(dr("SettoriId")) Then idSettore = Convert.ToInt32(dr("SettoriId"))
                    If Not IsDBNull(dr("CategorieId")) Then idCategoria = Convert.ToInt32(dr("CategorieId"))
                    If Not IsDBNull(dr("TipologieId")) Then idTipologia = Convert.ToInt32(dr("TipologieId"))
                    If Not IsDBNull(dr("GruppiId")) Then idGruppo = Convert.ToInt32(dr("GruppiId"))
                    If Not IsDBNull(dr("SottogruppiId")) Then idSottoGruppo = Convert.ToInt32(dr("SottogruppiId"))
                End If
            End Using
        End If

        ' Operatore logico
        cmd.Parameters.Clear()
        cmd.CommandText = "SELECT operatoreLogico FROM buoni_sconti WHERE (buonoSconto=@buonoSconto) AND (idAzienda=@idAzienda) LIMIT 1"
        cmd.Parameters.AddWithValue("@buonoSconto", codiceBuono)
        cmd.Parameters.AddWithValue("@idAzienda", idAzienda)

        Dim opObj As Object = cmd.ExecuteScalar()
        If opObj IsNot Nothing AndAlso opObj IsNot DBNull.Value Then
            Integer.TryParse(opObj.ToString(), tipoOperatoreLogico)
        End If

        If tipoOperatoreLogico = 1 Then
            operatoreLogico = " OR "
        Else
            operatoreLogico = " AND "
        End If

        ' Creo il filtro
        Dim where As String = " WHERE ("
        Dim hasAny As Boolean = False

        cmd.Parameters.Clear()
        cmd.Parameters.AddWithValue("@codiceBuono", "")
        cmd.Parameters.AddWithValue("@id", "")

        If idMarca > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidMarca(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idMarca
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idSettore > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidSettore(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idSettore
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idCategoria > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidCategoria(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idCategoria
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idTipologia > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidTipologia(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idTipologia
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idGruppo > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidGruppo(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idGruppo
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idSottoGruppo > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidSottogruppo(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idSottoGruppo
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idArticolo > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidArticolo(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idArticolo
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idUtente > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidUtente(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idUtente
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idTipoUtente > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidTipoUtente(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idTipoUtente
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idListinoUtente > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidListinoUtente(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idListinoUtente
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If Not hasAny Then
            where &= "1=1"
        End If

        where &= ")"

        ' Utilizzo
        cmd.CommandText = "SELECT BuoniScontiPerUtilizzo(@codiceBuono,@idUtente,@idAzienda)"
        cmd.Parameters("@codiceBuono").Value = codiceBuono

        Dim utId As Integer = GetUtentiIdSafe(0)

        If cmd.Parameters.Contains("@idUtente") Then
        cmd.Parameters("@idUtente").Value = utId
        Else
        cmd.Parameters.AddWithValue("@idUtente", utId)
        End If

        where &= " AND " & cmd.ExecuteScalar().ToString()

        ' Soglia prezzo
        cmd.CommandText = "SELECT BuoniScontiPerSogliaPrezzo(@codiceBuono,@totaleCarrello)"
        cmd.Parameters("@codiceBuono").Value = codiceBuono

        Dim totaleCarrelloVal As Double = SafeMoney(lblTotale.Text, 0)

        If cmd.Parameters.Contains("@totaleCarrello") Then
        cmd.Parameters("@totaleCarrello").Value = totaleCarrelloVal
        Else
        cmd.Parameters.AddWithValue("@totaleCarrello", totaleCarrelloVal)
        End If

        where &= " AND " & cmd.ExecuteScalar().ToString()

        ' Query finale
        cmd.CommandText = "SELECT COUNT(*) FROM buoni_sconti" & where & " AND ((buonoSconto=@codiceBuono) AND (idAzienda=@idAzienda))"
        Dim risultato As Integer = 0

        Dim resObj As Object = cmd.ExecuteScalar()
        If resObj IsNot Nothing AndAlso resObj IsNot DBNull.Value Then
            Integer.TryParse(resObj.ToString(), risultato)
        End If

        If risultato > 0 Then
            Return 1
        Else
            Return 0
        End If

    End Using
End Function


Protected Sub GV_BuoniSconti_RowCommand(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewCommandEventArgs) Handles GV_BuoniSconti.RowCommand
    If e.CommandName = "CancellaBuonoSconto" Then
        Session("BuonoSconto_id") = Nothing
        TB_BuonoSconto.Text = ""
        lblBuonoScontoConvalida.Text = ""
        BT_ApplicaBuonoSconto.Enabled = True
    End If
End Sub


'Funzione che restituisce 1 se il buono può essere utilizzato solo una volta, 0 nel caso il buono possa essere utilizzato più volte
Function getUtilizzoBuonoSconto(ByVal codiceBuonoSconto As String, ByVal idAzienda As Integer) As Integer
    Dim UtilizzaSoloUnaVolta As Integer = 0
    Dim paramsSelect As New Dictionary(Of String, String)
    paramsSelect.Add("codiceBuono", codiceBuonoSconto)
    paramsSelect.Add("idAzienda", idAzienda)

    Dim dr As MySqlDataReader = ExecuteQueryGetDataReader("UtilizzaSoloUnaVolta", "buoni_sconti", "(buonoSconto=@codiceBuono) AND (idAzienda=@idAzienda)", paramsSelect)

    If dr IsNot Nothing Then
        If dr.HasRows Then
            dr.Read()
            If Not IsDBNull(dr("UtilizzaSoloUnaVolta")) Then
                UtilizzaSoloUnaVolta = Convert.ToInt32(dr("UtilizzaSoloUnaVolta"))
            End If
        End If
        dr.Close()
    End If

    Return UtilizzaSoloUnaVolta
End Function


Function getBuonoScontoCodice(ByVal idBuonoSconto As Integer) As String
    Dim codiceBuonoSconto As String = ""
    Dim paramsSelect As New Dictionary(Of String, String)
    paramsSelect.Add("@IdBuonoScorto", idBuonoSconto)

    Dim dr As MySqlDataReader = ExecuteQueryGetDataReader("buonoSconto", "buoni_sconti", "id=@IdBuonoScorto", paramsSelect)

    If dr IsNot Nothing Then
        If dr.HasRows Then
            dr.Read()
            If Not IsDBNull(dr("buonoSconto")) Then
                codiceBuonoSconto = dr("buonoSconto").ToString()
            End If
        End If
        dr.Close()
    End If

    Return codiceBuonoSconto
End Function


Protected Sub btContinua_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btContinua.Click
    If Session.Item("Pagina_visitata_Articoli") Is Nothing Then
        Response.Redirect("default.aspx")
    Else
        If Session.Item("Pagina_visitata_Articoli").ToString = String.Empty Then
            Response.Redirect("default.aspx")
        Else
            Response.Redirect(Session.Item("Pagina_visitata_Articoli").ToString)
        End If
    End If
End Sub


Protected Sub btAggiorna_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btAggiorna.Click
    Aggiorna_Prezzi_Carrello()

    ' Session("Click_AggiornaCarrello") = 1 
    Response.Redirect("carrello.aspx")
End Sub


Protected Sub LB_CancelBuonoSconto_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles LB_CancelBuonoSconto.Click
    Session("BuonoSconto_id") = Nothing
    TB_BuonoSconto.Text = ""
    lblBuonoScontoConvalida.Text = ""
    BT_ApplicaBuonoSconto.Enabled = True
    LB_CancelBuonoSconto.Visible = False
End Sub


Protected Sub btSalvaPreventivo_click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btSalvaPreventivo.Click
    Me.PnlDestinazione.Visible = False

    Me.Session("Ordine_TipoDoc") = 2
    Me.Session("Ordine_Documento") = "Preventivo"
    Me.Session("Ordine_Pagamento") = Me.tbPagamenti.Text
    Me.Session("Ordine_Vettore") = Me.tbVettoriId.Text

    Me.Session("Ordine_SpeseSped") = SafeMoney(Me.lblSpeseSped.Text, 0)
    Me.Session("Ordine_SpeseAss") = SafeMoney(Me.lblSpeseAss.Text, 0)
    Me.Session("Ordine_SpesePag") = SafeMoney(Me.lblPagamento.Text, 0)
    Me.Session("Ordine_Totale_Documento") = SafeMoney(Me.lblTotale.Text, 0)

    Session("Ordine_DescrizioneBuonoSconto") = ""
    Session("Ordine_TotaleBuonoSconto") = 0
    Session("Ordine_CodiceBuonoSconto") = ""

    Me.Session("NoteDocumento") = Me.txtNoteSpedizione.Text

    Response.Redirect("ordine.aspx")
End Sub


Protected Sub btInviaOrdine_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btInviaOrdine.Click
    Me.PnlDestinazione.Visible = False

    Try
        LeggiVettori()
        Aggiorna_Prezzi_Carrello()

        If (controlla_articoli_quantita_zero() = 1) Then

            LeggiPagamenti()

            Dim paramsSelect As New Dictionary(Of String, String)
            paramsSelect.Add("@IdUtenti", GetUtentiIdSafe(0).ToString())

            Dim dr As MySqlDataReader = ExecuteQueryGetDataReader(
                "UTENTI.AZIENDEID, AZIENDE.RAGIONESOCIALE",
                "UTENTI",
                "INNER JOIN AZIENDE ON UTENTI.AZIENDEID = AZIENDE.ID WHERE UTENTI.Id=@IdUtenti",
                paramsSelect)

            If dr IsNot Nothing Then
                Try
                    If dr.HasRows Then
                        dr.Read()
                        lblIntestDestinazione.Text = dr.Item("RAGIONESOCIALE").ToString()
                    End If
                Finally
                    dr.Close()
                End Try
            End If

        Else
            Qnt_Errata.Visible = True
        End If

    Catch ex As Exception
        LogEx(ex, "btInviaOrdine_Click")
        ' (mantengo logica originale: nessun messaggio utente)
    Finally
        If (controlla_articoli_quantita_zero() = 1) Then
            If (GetLoginIdSafe(0) > 0) Then
                Cookie = "N"
                SendOrder()
            Else
                Session.Item("StavonelCarrello") = 1
                Response.Redirect("accessonegato.aspx")
            End If
        End If
    End Try
    End Sub

' =========================
' CITY REGISTRY - BLOCCO COMPLETO (Copia-Incolla)
' =========================

Protected Sub City_Bind_Data2(ByVal sender As Object, ByVal e As System.EventArgs)
    riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2)
    Session("cityBinding") = 1
End Sub

Protected Sub riempi_ddl_citta(ByVal cap As String, ByVal cittaddl As DropDownList, ByVal provincia As TextBox, Optional ByVal citta As String = "")
    ' CHIAMATA SAFE (evita errore compile se il metodo non esiste nella reference)
    Dim ds As DataSet = GetCitiesFromPostcodeCodeSafe(cap)

    ConvertDataSetColumnToUpper(ds, "name_city")

    If ds IsNot Nothing AndAlso ds.Tables.Count > 0 Then
        cittaddl.DataSource = ds.Tables(0)
        cittaddl.DataTextField = ds.Tables(0).Columns("name_city").ToString().ToUpper()
        cittaddl.DataValueField = ds.Tables(0).Columns("name_city").ToString().ToUpper()
        cittaddl.DataBind()
    Else
        cittaddl.Items.Clear()
    End If

    If citta <> String.Empty Then
        Try
            If cittaddl.Items.Count > 0 Then
                cittaddl.Items(cittaddl.SelectedIndex).Selected = False
                Dim it As ListItem = cittaddl.Items.FindByValue(citta)
                If it IsNot Nothing Then it.Selected = True
            End If
        Catch
        End Try
    End If

    citta = String.Empty
    If cittaddl.Items.Count > 0 Then
        citta = cittaddl.Items(cittaddl.SelectedIndex).Text
    End If

    riempi_text_provincia(citta, provincia)
End Sub

Protected Sub ConvertDataSetColumnToUpper(ByRef ds As DataSet, ByVal columnName As String)
    If ds Is Nothing OrElse ds.Tables.Count = 0 Then Exit Sub
    If ds.Tables(0) Is Nothing Then Exit Sub
    If Not ds.Tables(0).Columns.Contains(columnName) Then Exit Sub

    For Each row As DataRow In ds.Tables(0).Rows
        If row IsNot Nothing AndAlso Not IsDBNull(row(columnName)) Then
            row(columnName) = row(columnName).ToString().ToUpperInvariant()
        End If
    Next
End Sub

Protected Sub riempi_text_provincia(ByVal citta As String, ByVal provincia As TextBox)
    If citta <> String.Empty Then
        ' CHIAMATA SAFE (evita errore compile se il metodo non esiste nella reference)
        Dim ds As DataSet = GetProvinceFromCitySafe(citta)

        Try
            If ds IsNot Nothing AndAlso ds.Tables.Count > 0 AndAlso ds.Tables(0).Rows.Count > 0 Then
                provincia.Text = ds.Tables(0).Rows(0)("abbreviation").ToString()
            Else
                provincia.Text = String.Empty
            End If
        Catch
            provincia.Text = String.Empty
        End Try
    Else
        provincia.Text = String.Empty
    End If
End Sub

Protected Sub Province_Bind_Data2(ByVal sender As Object, ByVal e As System.EventArgs)
    riempi_text_provincia(getDdlCittaValue(ddlCitta2), tbProvincia2)
    Session("cityBinding") = 1
End Sub

Protected Function getDdlCittaValue(ByVal ddlCitta As DropDownList) As String
    Dim value As String
    Try
        value = ddlCitta.Items(ddlCitta.SelectedIndex).Text
    Catch ex As Exception
        LogEx(ex, "SendOrder")
        value = ""
    End Try
    Return value
End Function

' =========================
' CITY REGISTRY - WRAPPER SAFE (USA cityRegistry ESISTENTE)
' Fix BC30112: evita conflitto con namespace CityRegistry
' =========================

Private Function GetCitiesFromPostcodeCodeSafe(ByVal cap As String) As DataSet
    Try
        ' Forzo l'uso dell'istanza di pagina/classe, NON del namespace
        Dim o As Object = Nothing
        Try
            o = CallByName(Me, "cityRegistry", CallType.Get)
        Catch
            o = Nothing
        End Try

        If o Is Nothing Then Return New DataSet()

        Dim res As Object = CallByName(o, "GetCitiesFromPostcodeCode", CallType.Method, cap)
        If TypeOf res Is DataSet Then Return DirectCast(res, DataSet)

        Return New DataSet()
    Catch ex As Exception
        LogEx(ex, "GetCitiesFromPostcodeCodeSafe")
        Return New DataSet()
    End Try
End Function

Private Function GetProvinceFromCitySafe(ByVal citta As String) As DataSet
    Try
        Dim o As Object = Nothing
        Try
            o = CallByName(Me, "cityRegistry", CallType.Get)
        Catch
            o = Nothing
        End Try

        If o Is Nothing Then Return New DataSet()

        Dim res As Object = CallByName(o, "GetProvinceFromCity", CallType.Method, citta)
        If TypeOf res Is DataSet Then Return DirectCast(res, DataSet)

        Return New DataSet()
    Catch ex As Exception
        LogEx(ex, "GetProvinceFromCitySafe")
        Return New DataSet()
    End Try
End Function

' =========================
' ExecuteQueryGetDataReader (normalizza nomi parametri)
' =========================
Protected Function ExecuteQueryGetDataReader(ByVal fields As String, ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As MySqlDataReader

    Dim sqlString As String = "SELECT " & fields & " FROM " & table & NormalizeWherePart(wherePart)
    lastSqlString = sqlString

    Dim conn As New MySqlConnection

    Try
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        If String.IsNullOrEmpty(connectionString) Then Return Nothing

        conn.ConnectionString = connectionString
        conn.Open()

        Dim cmd As New MySqlCommand With {
            .Connection = conn,
            .CommandType = CommandType.Text,
            .CommandText = sqlString
        }

        If params IsNot Nothing Then
            For Each paramName As String In params.Keys
                Dim p As String = paramName
                If Not p.StartsWith("@") AndAlso Not p.StartsWith("?") Then
                    p = "@" & p
                End If
                cmd.Parameters.AddWithValue(p, params(paramName))
            Next
        End If

        ' IMPORTANT: chiude automaticamente la connessione quando chiudi il reader
        Return cmd.ExecuteReader(CommandBehavior.CloseConnection)

    Catch ex As Exception
        LogEx(ex, "ExecuteQueryGetDataReader", sqlString)
        Try
            If conn IsNot Nothing AndAlso conn.State = ConnectionState.Open Then conn.Close()
        Catch
        End Try
        Return Nothing
    End Try

End Function

' =========================
' NormalizeWherePart
' =========================
Private Function NormalizeWherePart(ByVal wherePart As String) As String
    Dim wp As String = If(wherePart, "").Trim()
    If wp = "" Then Return ""

    Dim up As String = wp.ToUpperInvariant()

    If up.StartsWith("WHERE ") _
        OrElse up.StartsWith("INNER ") _
        OrElse up.StartsWith("LEFT ") _
        OrElse up.StartsWith("RIGHT ") _
        OrElse up.StartsWith("JOIN ") _
        OrElse up.StartsWith("ORDER ") _
        OrElse up.StartsWith("GROUP ") _
        OrElse up.StartsWith("LIMIT ") Then

        Return " " & wp
    End If

    If up.StartsWith("AND ") OrElse up.StartsWith("OR ") Then
        Return " WHERE 1=1 " & wp
    End If

    Return " WHERE " & wp
End Function

' =========================
' ExecuteDelete (UNA SOLA DEFINIZIONE)
' =========================
Protected Function ExecuteDelete(ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
    Dim sqlString As String = "DELETE FROM " & table & NormalizeWherePart(wherePart)
    ExecuteNonQuery(False, sqlString, params)
    Return Nothing
End Function

' =========================
' ExecuteUpdate (UNA SOLA DEFINIZIONE)
' =========================
Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
    Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & NormalizeWherePart(wherePart)
    ExecuteNonQuery(False, sqlString, params)
    Return Nothing
End Function

' =========================
' ExecuteNonQuery (Using: no Finally, no End Try sbilanciati)
' =========================
Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object

    lastSqlString = sqlString

    Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    If String.IsNullOrEmpty(connectionString) Then Return Nothing

    Try
        Using conn As New MySqlConnection(connectionString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandText = sqlString

                If params IsNot Nothing Then
                    For Each paramName As String In params.Keys

                        Dim p As String = paramName
                        If Not p.StartsWith("@") AndAlso Not p.StartsWith("?") Then
                            p = "@" & p
                        End If

                        If p = "?parPrezzo" OrElse p = "?parPrezzoIvato" OrElse p = "@parPrezzo" OrElse p = "@parPrezzoIvato" Then
                            cmd.Parameters.Add(p, MySqlDbType.Double).Value =
                                Convert.ToDecimal(params(paramName), CultureInfo.GetCultureInfo("it-IT"))
                        Else
                            cmd.Parameters.AddWithValue(p, params(paramName))
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
            End Using
        End Using

    Catch ex As Exception
        LogEx(ex, "ExecuteNonQuery", sqlString)
    End Try

    Return Nothing
End Function

' =========================
' SAFE PARSING HELPERS
' =========================

Private Function SafeIntFromText(ByVal value As Object, Optional ByVal def As Integer = 0) As Integer
    Try
        If value Is Nothing OrElse value Is DBNull.Value Then Return def

        Dim s As String = value.ToString().Trim()
        If s = "" Then Return def

        s = s.Replace("€", "").Replace("%", "").Trim()
        s = s.Replace("−", "-")

        ' rimuovo separatori comuni
        s = s.Replace(".", "").Replace(",", "").Replace(" ", "")

        Dim n As Integer
        If Integer.TryParse(s, n) Then Return n

        Return def
    Catch
        Return def
    End Try
End Function

Private Function SafeDblFromText(ByVal value As Object, Optional ByVal def As Double = 0) As Double
    Try
        If value Is Nothing OrElse value Is DBNull.Value Then Return def

        Dim s As String = value.ToString().Trim()
        If s = "" Then Return def

        s = s.Replace("€", "").Replace("%", "").Trim()
        s = s.Replace("−", "-")

        Dim d As Double

        ' prova formato italiano
        If Double.TryParse(s, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), d) Then
            Return d
        End If

        ' prova invariant
        If Double.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
            Return d
        End If

        ' fallback: tipico caso "1.234,56"
        Dim t As String = s.Replace(".", "").Replace(",", ".")
        If Double.TryParse(t, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
            Return d
        End If

        Return def
    Catch
        Return def
    End Try
End Function

Private Function SafeInt(ByVal value As Object, Optional ByVal def As Integer = 0) As Integer
    Return SafeIntFromText(value, def)
End Function

Private Function SafeDbl(ByVal value As Object, Optional ByVal def As Double = 0) As Double
    Return SafeDblFromText(value, def)
End Function

' SafeMoney: per importi in euro (Label spesso tipo "€ 1.234,56")
    Private Function SafeMoney(ByVal value As Object, Optional ByVal def As Double = 0) As Double
    Try
        If value Is Nothing OrElse value Is DBNull.Value Then Return def

        Dim s As String = value.ToString().Trim()
        If s = "" Then Return def

        s = s.Replace("€", "").Trim()
        s = s.Replace("−", "-")

        ' "1.234,56" -> tolgo i punti migliaia
        s = s.Replace(".", "")

        Dim d As Double
        If Double.TryParse(s, NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), d) Then
            Return d
        End If

        ' fallback invariant
        s = s.Replace(",", ".")
        If Double.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
            Return d
        End If

        Return def
    Catch
        Return def
    End Try
    End Function
    
    ' Gestisce OnItemDataBound="rPromo_ItemDataBound" dei repeater rPromo nei template
    Protected Sub rPromo_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)

    If e Is Nothing OrElse e.Item Is Nothing Then Exit Sub

    If e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem Then
        Exit Sub
    End If

    Dim lblInOfferta As Label = TryCast(e.Item.FindControl("lblInOfferta"), Label)
    Dim lblDataFine As Label = TryCast(e.Item.FindControl("lblDataFine"), Label)
    Dim lblOfferta As Label = TryCast(e.Item.FindControl("lblOfferta"), Label)

    If lblInOfferta Is Nothing OrElse lblOfferta Is Nothing Then Exit Sub

    Dim inOfferta As Integer = 0
    Integer.TryParse((If(lblInOfferta.Text, "")).Trim(), inOfferta)

    If inOfferta = 1 Then
        lblOfferta.Visible = True

        Dim dataFine As String = ""
        If lblDataFine IsNot Nothing Then
            dataFine = (If(lblDataFine.Text, "")).Trim()
        End If

        If dataFine <> "" Then
            lblOfferta.Text = "PROMO FINO AL " & dataFine
        Else
            lblOfferta.Text = "PROMO"
        End If
    Else
        lblOfferta.Visible = False
    End If

    End Sub



    ' ============================================================
    ' SEO helpers locali (compatibilità: SeoBuilder non disponibile)
    ' ============================================================

    Private Shared Sub AddOrReplaceMeta(ByVal page As System.Web.UI.Page, ByVal metaName As String, ByVal metaContent As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim found As System.Web.UI.HtmlControls.HtmlMeta = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim m As System.Web.UI.HtmlControls.HtmlMeta = TryCast(ctrl, System.Web.UI.HtmlControls.HtmlMeta)
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

    Private Shared Sub SetCanonical(ByVal page As System.Web.UI.Page, ByVal canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(canonicalUrl) Then Exit Sub

        Dim found As System.Web.UI.HtmlControls.HtmlLink = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim l As System.Web.UI.HtmlControls.HtmlLink = TryCast(ctrl, System.Web.UI.HtmlControls.HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = Convert.ToString(l.Attributes("rel"))
                If String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    found = l
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then
            found = New System.Web.UI.HtmlControls.HtmlLink()
            found.Attributes("rel") = "canonical"
            page.Header.Controls.Add(found)
        End If

        found.Href = canonicalUrl
    End Sub
    Private Shared Function BuildSimplePageJsonLd(ByVal pageTitle As String, ByVal descr As String, ByVal canonicalUrl As String) As String
        Dim sb As New StringBuilder()
        sb.Append("{""@context"":""https://schema.org"",""@type"":""WebPage""")
        sb.Append(",""name"":""").Append(JsonEscape(pageTitle)).Append("""")
        sb.Append(",""url"":""").Append(JsonEscape(canonicalUrl)).Append("""")
        If Not String.IsNullOrEmpty(descr) Then
            sb.Append(",""description"":""").Append(JsonEscape(descr)).Append("""")
        End If
        sb.Append("}")
        Return sb.ToString()
    End Function
    Private Shared Sub SetJsonLdOnMaster(ByVal page As System.Web.UI.Page, ByVal jsonLd As String)
        Try
            Dim m As Object = page.Master
            If m IsNot Nothing Then
                Dim prop = m.GetType().GetProperty("SeoJsonLd")
                If prop IsNot Nothing AndAlso prop.CanWrite Then
                    prop.SetValue(m, jsonLd, Nothing)
                    Return
                End If
            End If
        Catch
            ' NOP
        End Try

        Try
            Dim ph As Control = page.Header.FindControl("HeadContent")
            If ph Is Nothing Then
                ' fallback: inject directly in <head>
                ph = page.Header
            End If

            Dim lit As New Literal()
            lit.ID = "litJsonLd"
            lit.Text = "<script type=""application/ld+json"">" & jsonLd & "</script>"
            ph.Controls.Add(lit)
        Catch
            ' NOP
        End Try
    End Sub

    Private Shared Function JsonEscape(ByVal s As String) As String
        If s Is Nothing Then Return ""
        Dim sb As New StringBuilder(s.Length + 16)

        For Each ch As Char In s
            Select Case ch
                Case """"c
                    ' JSON: \"
                    sb.Append("\\")
                    sb.Append(ChrW(34))
                Case "\"c
                    ' JSON: \\
                    sb.Append("\\\\")
                Case ControlChars.Cr
                    sb.Append("\\r")
                Case ControlChars.Lf
                    sb.Append("\\n")
                Case ControlChars.Tab
                    sb.Append("\\t")
                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 Then
                        sb.Append("\\u").Append(code.ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function
End Class
