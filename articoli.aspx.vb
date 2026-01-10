Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Text.RegularExpressions
Imports System.Collections
Imports System.Collections.Generic

Partial Class Articoli
    Inherits System.Web.UI.Page

    Dim IvaTipo As Integer
    Dim DispoTipo As Integer
    Dim DispoMinima As Integer
    Dim InOfferta As Integer
    Dim filters As New Dictionary(Of String, String)
    Dim oldUrl As String

    Function sostituisci_caratteri_speciali(ByRef stringa As String) As String
        stringa = Server.HtmlEncode(stringa)

        'Espressione Regolare per sostituire i caratteri speciali
        Dim pattern As String = "\s+"
        Dim stringaReplace As String = " "
        Dim rgx As New Regex(pattern)
        stringa = rgx.Replace(stringa, stringaReplace)

        stringa = stringa.Replace("&", "")
        stringa = stringa.Replace("!", "")
        stringa = stringa.Trim

        Return stringa
    End Function

    Private Function AreArraysEqual(Of T)(ByVal a As T(), ByVal b() As T) As Boolean
        If a Is Nothing AndAlso b Is Nothing Then Return True
        If a Is Nothing Or b Is Nothing Then Return False
        If a.Length <> b.Length Then Return False

        For i As Integer = 0 To b.GetUpperBound(0)
            If Not Array.IndexOf(a, b(i)) >= 0 Then Return False
        Next

        Return True
    End Function

    Protected Sub Page_PreRenderComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRenderComplete
        Dim newUrl As String = oldUrl
        Dim mrAreEquals As Boolean = True
        Dim tpAreEquals As Boolean = True
        Dim grAreEquals As Boolean = True
        Dim sgAreEquals As Boolean = True

        If filters.ContainsKey("mr") Then
            mrAreEquals = AreArraysEqual(Request.QueryString("mr").Split("|"c), filters.Item("mr").Split("|"c))
            newUrl = changeUrlGetParam(newUrl, "mr", filters.Item("mr"))
        End If
        If filters.ContainsKey("tp") Then
            tpAreEquals = AreArraysEqual(Request.QueryString("tp").Split("|"c), filters.Item("tp").Split("|"c))
            newUrl = changeUrlGetParam(newUrl, "tp", filters.Item("tp"))
        End If
        If filters.ContainsKey("gr") Then
            grAreEquals = AreArraysEqual(Request.QueryString("gr").Split("|"c), filters.Item("gr").Split("|"c))
            newUrl = changeUrlGetParam(newUrl, "gr", filters.Item("gr"))
        End If
        If filters.ContainsKey("sg") Then
            sgAreEquals = AreArraysEqual(Request.QueryString("sg").Split("|"c), filters.Item("sg").Split("|"c))
            newUrl = changeUrlGetParam(newUrl, "sg", filters.Item("sg"))
        End If

        If Not (mrAreEquals And tpAreEquals And grAreEquals And sgAreEquals) Then
            Response.Redirect(newUrl)
        End If
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        oldUrl = HttpContext.Current.Request.Url.AbsoluteUri

        If Request.QueryString("rimuovi") <> String.Empty Then
            Dim filtersToRemove As String = Request.QueryString("rimuovi")
            Response.Redirect(changeUrlGetParam(Request.UrlReferrer.ToString, filtersToRemove, String.Empty).Replace("rimuovi=" & filtersToRemove, String.Empty))
        End If

        If Me.IsPostBack = False Then
            changeCheckBoxDependingFromUrl(CheckBox_Disponibile, "disponibile", "1")
            changeDropDownListDependingFromUrl(Drop_Ordinamento, "ordinamento")
        End If

        'Redirect nel caso c'è la presenza di #up
        If Request.Url.AbsoluteUri.Contains("%23up") Or (Request.Url.AbsoluteUri.Contains("#23up")) Then
            Response.Redirect(Request.Url.AbsoluteUri.Replace("%23up", "").Replace("#23up", ""))
        End If

        Session.Item("Pagina_visitata_Articoli") = Me.Request.Url.ToString 'Aggiorno l'ultima pagina visitata in Articoli
        Me.Session("Carrello_Pagina") = "articoli.aspx"

        DispoTipo = Me.Session("DispoTipo")
        DispoMinima = Me.Session("DispoMinima")
        InOfferta = Me.Session("InOfferta")

        'Assegnazione della variabile in offerta, per visualizzare solo i prodotti in offerta
        Dim rawInPromo As String = Me.Request.QueryString("inpromo")
        If Not String.IsNullOrEmpty(rawInPromo) Then
            Dim tmpInOfferta As Integer
            If Integer.TryParse(rawInPromo, tmpInOfferta) Then
                InOfferta = tmpInOfferta
            End If
        End If

        If Application.Item("AS00728312T34") = 1 Then
            Application.Set("ASXXX00728312T", Application.Item("AS00728312T34") - 1)
            Application.Set("AS00728312T34", 0)
            Response.Write("<script>alert('')</script>")
        End If
    End Sub

    Protected Sub Page_LoadComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.LoadComplete
        IvaTipo = Me.Session("IvaTipo")

        If IvaTipo = 1 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Esclusa*"
        ElseIf IvaTipo = 2 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Inclusa*"
        End If

        CaricaArticoli()

        Me.GridView1.PageSize = Me.Session("RigheArticoli")
        Me.GridView1.PageIndex = Session("Articoli_PageIndex")

        'Inserimento della stringa di ricerca nella tabella query_string, per l'indicizzazione
        If Session("q") IsNot Nothing Then
            Dim strCercaQS As String = Session("q")
            Dim paramsQS As New Dictionary(Of String, Object)
            paramsQS.Add("@QString", strCercaQS)
            paramsQS.Add("@Data", DateTime.Now)
            ExecuteInsert("QString, Data", "query_string", "@QString, @Data", paramsQS)
        End If
    End Sub

    'FILTRI TAGLIA COLORE AGGIUNTI DA ANGELO IL 15/12/2017
    'INIZIO
    Public Sub showFilters(ByVal conn As MySqlConnection, ByVal articoliFiltrati As String)
        Dim tc As Integer = Session("TC")
        If tc = 1 Then
            filtritagliaecolore.Visible = True
            Dim TagliaIndex As Integer
            Dim ColoreIndex As Integer
            Dim TagliaValue As String
            Dim ColoreValue As String

            If Me.IsPostBack = False And Request.QueryString("taglia") <> String.Empty Then
                Dim tagliaIndexAndValue = Request.QueryString("taglia").Split("|"c)
                TagliaIndex = CInt(tagliaIndexAndValue(0).ToString)
                TagliaValue = tagliaIndexAndValue(1)
            Else
                TagliaIndex = Drop_Filtra_Taglia.SelectedIndex
                TagliaValue = Drop_Filtra_Taglia.SelectedValue
            End If

            If Me.IsPostBack = False And Request.QueryString("colore") <> String.Empty Then
                Dim coloreIndexAndValue = Request.QueryString("colore").Split("|"c)
                ColoreIndex = CInt(coloreIndexAndValue(0).ToString)
                ColoreValue = coloreIndexAndValue(1)
            Else
                ColoreIndex = Drop_Filtra_Colore.SelectedIndex
                ColoreValue = Drop_Filtra_Colore.SelectedValue
            End If

            PopulateFilterTCDropdownlist(conn, "taglie", "tagliaid", "coloreid", ColoreIndex, TagliaValue, ColoreValue, Drop_Filtra_Taglia, "Tutte", articoliFiltrati)
            PopulateFilterTCDropdownlist(conn, "colori", "coloreid", "tagliaid", TagliaIndex, ColoreValue, TagliaValue, Drop_Filtra_Colore, "Tutti", articoliFiltrati)
        Else
            filtritagliaecolore.Visible = False
        End If
    End Sub

    Public Sub PopulateFilterTCDropdownlist(ByVal conn As MySqlConnection,
                                            ByVal tableName As String,
                                            ByVal idColumnName As String,
                                            ByVal otherIdColumnName As String,
                                            ByVal otherDropdownlistIndex As Integer,
                                            ByVal dropdownlistValue As String,
                                            ByVal otherDropdownlistValue As String,
                                            ByVal list As DropDownList,
                                            ByVal allValueString As String,
                                            ByVal articoliFiltrati As String)

        Dim sqlString As String
        sqlString = "select * from " & tableName & " inner join articoli_tagliecolori where " & tableName & ".id = articoli_tagliecolori." & idColumnName
        If otherDropdownlistIndex > 0 Then
            sqlString = sqlString & " And articoli_tagliecolori." & otherIdColumnName & " = " & otherDropdownlistValue
        End If
        sqlString = sqlString & " And articoli_tagliecolori.ArticoliId in (SELECT id FROM (" & articoliFiltrati & ") AS articoliFiltrati)"
        sqlString = sqlString & " And " & tableName & ".abilitato = 1 Group by " & tableName & ".id order by " & tableName & ".id"

        PopulateDropdownlist(conn, sqlString, list, "descrizione", "id")
        list.Items.Insert(0, New ListItem(allValueString, "0"))
        list.SelectedValue = dropdownlistValue
    End Sub

    Public Sub PopulateDropdownlist(ByVal conn As MySqlConnection,
                                    ByVal sqlString As String,
                                    ByVal list As DropDownList,
                                    ByVal textField As String,
                                    ByVal valueField As String)
        Dim dt As New DataTable
        Using cmd = conn.CreateCommand()
            cmd.CommandType = CommandType.Text
            cmd.CommandText = sqlString
            Using da As New MySqlDataAdapter(cmd)
                da.Fill(dt)
            End Using
        End Using
        list.DataSource = dt
        list.DataTextField = textField
        list.DataValueField = valueField
        list.DataBind()
    End Sub
    'FILTRI TAGLIA COLORE - FINE

    Public Sub CaricaArticoli()
        ' ============================
        ' LISTINO: GESTIONE ROBUSTA
        ' ============================
        Dim NListino As Integer = 1  ' listino di default per anonimi

        Dim rawListinoN As String = Convert.ToString(Session("Listino"))
        Dim tmp As Integer
        If Integer.TryParse(rawListinoN, tmp) AndAlso tmp > 0 Then
            NListino = tmp
        Else
            Session("Listino") = NListino
        End If

        Dim SettoriId As Integer = 0
        Dim CategorieId As Integer = 0
        Dim TipologieId As String = String.Empty
        Dim GruppiId As String = String.Empty
        Dim SottogruppiId As String = String.Empty
        Dim MarcheId As String = String.Empty
        Dim OfferteId As Integer = 0
        Dim strCerca As String = ""
        Dim SpedizioneGratis As Integer = 0

        'Carico le variabili da Sessione se non sono presenti nella QueryString
        Dim rawSt As String = Me.Request.QueryString("st")
        If Not String.IsNullOrEmpty(rawSt) Then
            Integer.TryParse(rawSt, SettoriId)
        ElseIf Me.Session("st") IsNot Nothing Then
            Integer.TryParse(Me.Session("st").ToString(), SettoriId)
        End If

        Dim rawCt As String = Me.Request.QueryString("ct")
        If Not String.IsNullOrEmpty(rawCt) Then
            Integer.TryParse(rawCt, CategorieId)
        ElseIf Me.Session("ct") IsNot Nothing Then
            Integer.TryParse(Me.Session("ct").ToString(), CategorieId)
        End If

        Dim rawPid As String = Me.Request.QueryString("pid")
        If Not String.IsNullOrEmpty(rawPid) Then
            Integer.TryParse(rawPid, OfferteId)
        ElseIf Me.Session("pid") IsNot Nothing Then
            Integer.TryParse(Me.Session("pid").ToString(), OfferteId)
        End If

        Dim rawSped As String = Me.Request.QueryString("spedgratis")
        If Not String.IsNullOrEmpty(rawSped) Then
            Integer.TryParse(rawSped, SpedizioneGratis)
        End If

        ' Filtri multipli (tipologie, gruppi, sottogruppi, marche) da QueryString: accetto solo ID numerici
        TipologieId = SafeIdListFromQuery("tp")
        GruppiId = SafeIdListFromQuery("gr")
        SottogruppiId = SafeIdListFromQuery("sg")
        MarcheId = SafeIdListFromQuery("mr")

        If Me.Request.QueryString("q") <> "" Then
            strCerca = Me.Request.QueryString("q").Replace("%23up", "").Replace("#up", "")
        Else
            If Session("q") IsNot Nothing Then
                strCerca = sostituisci_caratteri_speciali(Session("q").Replace("%23up", "").Replace("#up", ""))
            End If
        End If

        If InOfferta = 1 Then
            Session("Promo") = 1
        Else
            Session("Promo") = 0
        End If

        If Not strCerca Is Nothing Then
            strCerca = strCerca.Replace("'", "").Replace("*", "").Replace("&", "").Replace("#", "")
        Else
            strCerca = ""
        End If

        ' valori IVA da Session in forma numerica sicura
        Dim abilRC As Integer = 0
        Dim ivaUtente As Integer = 0
        If Session("AbilitatoIvaReverseCharge") IsNot Nothing Then
            Integer.TryParse(Session("AbilitatoIvaReverseCharge").ToString(), abilRC)
        End If
        If Session("Iva_Utente") IsNot Nothing Then
            Integer.TryParse(Session("Iva_Utente").ToString(), ivaUtente)
        End If

        Dim strSelect As String =
            "SELECT vsuperarticoli.id, Codice, Ean, Descrizione1, Descrizione2, DescrizioneLunga, Prezzo," &
            " IF((" & abilRC & "=1) AND (ValoreIvaRC>-1)," &
            "     (Prezzo*((ValoreIvaRC/100)+1))," &
            "     IF(" & ivaUtente & ">0,(Prezzo*((" & ivaUtente & "/100)+1)),PrezzoIvato)" &
            " ) AS PrezzoIvato," &
            " Img1, MarcheDescrizione, Disponibilita, Giacenza, InOrdine, Impegnata, InOfferta," &
            " SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDescrizione, SottogruppiDescrizione," &
            " Marche_img, PrezzoPromo," &
            " IF((" & abilRC & "=1) AND (ValoreIvaRC>-1)," &
            "     (PrezzoPromo*((ValoreIvaRC/100)+1))," &
            "     IF(" & ivaUtente & ">0,(PrezzoPromo*((" & ivaUtente & "/100)+1)),PrezzoPromoIvato)" &
            " ) AS PrezzoPromoIvato," &
            " MarcheId, CategorieId, TipologieId," &
            " IF(PrezzoPromo IS NULL,Prezzo,PrezzoPromo) AS Ord_PrezzoPromo," &
            " IF(PrezzoPromoIvato IS NULL,PrezzoIvato," &
            "     IF((" & abilRC & "=1) AND (ValoreIvaRC>-1)," &
            "         (PrezzoPromo*((ValoreIvaRC/100)+1))," &
            "         IF(" & ivaUtente & ">0,(PrezzoPromo*((" & ivaUtente & "/100)+1)),PrezzoPromoIvato)" &
            "     )" &
            " ) AS Ord_PrezzoPromoIvato," &
            " TCid, IF(Ricondizionato = 1, 'visible', 'hidden') as refurbished," &
            " taglie.descrizione as taglia," &
            " CONVERT(CONCAT('<table style=""width:100%;"" border=""1""><tr style=""background-color:#00FF99;""><td>Data di arrivo</td><td>Quantit&agrave;</td></tr><tr style=""background-color:#00FFFF;""><td>'," &
            "       GROUP_CONCAT(arrivi SEPARATOR '</td></tr><tr style=""background-color:#00FFFF;""><td>'),'</td></tr></table>'),CHAR) as arrivi," &
            " colori.descrizione as colore," &
            " IF(PrezzoPromoIvato IS NULL, PrezzoIvato, PrezzoPromoIvato) AS PrezzoOldIvato" &
            " FROM vsuperarticoli " &
            " LEFT OUTER JOIN articoli_tagliecolori On vsuperarticoli.TCid=articoli_tagliecolori.id" &
            " LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id" &
            " LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id" &
            " LEFT OUTER JOIN (SELECT articoliid, CONCAT(DATE_FORMAT(dataArrivo, '%d/%m/%Y'),'</td><td>', (TRIM(TRAILING '.' FROM(CAST(TRIM(TRAILING '0' FROM SUM(arrivi)) AS CHAR))))) AS arrivi" &
            "                 FROM articoli_arrivi WHERE dataArrivo>NOW() and arrivi > 0 GROUP BY dataArrivo) arrivi ON arrivi.articoliid = vsuperarticoli.id"

        Dim strWhere As String = ""
        Dim strWhere2 As String = "WHERE 1=1 "

        If SettoriId > 0 And OfferteId = 0 Then
            ' logica per settore (lasciata commentata come nel codice originale)
        End If

        If CategorieId > 0 Then
            If (Session("ct") <> 30000) Then
                strWhere = strWhere & " AND (CategorieId=" & CategorieId & ") "
                strWhere2 = strWhere2 & " AND (varticolibase.CategorieId=" & CategorieId & ") "
            End If
            TitoloCategoria()
        ElseIf OfferteId > 0 Then
            strWhere = strWhere & " AND (OfferteId = " & OfferteId & ") "
            strWhere2 = strWhere2 & " AND (varticolibase.OfferteId = " & OfferteId & ") "
            Me.tNavig.Visible = False
        ElseIf strCerca = "" OrElse strCerca Is Nothing Then
            Response.Redirect("default.aspx")
        End If

        If Not String.IsNullOrEmpty(MarcheId) Then
            strWhere = strWhere & " AND MarcheId in (" & MarcheId & ") "
            strWhere2 = strWhere2 & " AND varticolibase.MarcheId in (" & MarcheId & ") "
        End If

        If Not String.IsNullOrEmpty(TipologieId) Then
            strWhere = strWhere & " AND TipologieId in (" & TipologieId & ") "
            strWhere2 = strWhere2 & " AND varticolibase.TipologieId in (" & TipologieId & ") "
        End If

        If Not String.IsNullOrEmpty(GruppiId) Then
            strWhere = strWhere & " AND GruppiId in (" & GruppiId & ") "
            strWhere2 = strWhere2 & " AND varticolibase.GruppiId in (" & GruppiId & ") "
        End If

        If Not String.IsNullOrEmpty(SottogruppiId) Then
            strWhere = strWhere & " AND SottogruppiId in (" & SottogruppiId & ") "
            strWhere2 = strWhere2 & " AND varticolibase.SottogruppiId in (" & SottogruppiId & ") "
        End If

        If SpedizioneGratis = 1 Then
            strWhere = strWhere &
                " AND (SpedizioneGratis_Listini LIKE CONCAT('%', " & NListino & ", ';%'))" &
                " AND (SpedizioneGratis_Data_Inizio <= CURDATE())" &
                " AND (SpedizioneGratis_Data_Fine >= CURDATE())"
            strWhere2 = strWhere2 &
                " AND (SpedizioneGratis_Listini LIKE CONCAT('%', " & NListino & ", ';%'))" &
                " AND (SpedizioneGratis_Data_Inizio <= CURDATE())" &
                " AND (SpedizioneGratis_Data_Fine >= CURDATE())"
        Else
            Me.Session("SpedGratis") = 0
        End If

        If Me.Page.IsPostBack = False Then
            Session.Item("Controllo_Variabile_Promo") = 0
        End If

        If ((Session.Item("Controllo_Variabile_Promo") = 0) And (Session.Item("Promo") = 1)) Then
            Session.Item("Controllo_Variabile_Promo") = 1
            Session.Item("Promo") = 0
            strWhere = strWhere & " AND (InOfferta = 1) "
        End If

        If ((Session.Item("Controllo_Variabile_Promo") = 1) And (Session.Item("Promo") = 0) And (Me.Page.IsPostBack = True)) Then
            strWhere = strWhere & " AND (InOfferta = 1) "
        End If

        If CheckBox_Disponibile.Checked = True Then
            Session.Item("Disp") = 0
            strWhere = strWhere & " AND (Giacenza>0)"
            strWhere2 = strWhere2 & " AND (Giacenza>0)"
        End If

        If Me.Page.IsPostBack = False Then
            Session.Item("Controllo_Variabile_PrezzoMinMax") = 0
            Session("Valore_Prezzo_MIN") = ""
            Session("Valore_Prezzo_MAX") = ""
        End If

        ' Gestione filtri prezzo (copiata dalla versione originale)
        If (Session.Item("Controllo_Variabile_PrezzoMinMax") = 0) AndAlso ((Session.Item("Prezzo_MIN") <> "") OrElse (Session.Item("Prezzo_MAX") <> "")) Then
            Session.Item("Controllo_Variabile_PrezzoMinMax") = 1
            If (Session.Item("Prezzo_MIN").ToString <> "") Then
                Session("Valore_Prezzo_MIN") = System.Convert.ToDouble(Session.Item("Prezzo_MIN").ToString.Replace(".", ","))
            End If
            If (Session.Item("Prezzo_MAX").ToString <> "") Then
                Session("Valore_Prezzo_MAX") = System.Convert.ToDouble(Session.Item("Prezzo_MAX").ToString.Replace(".", ","))
            End If

            Session.Item("Prezzo_MIN") = ""
            Session.Item("Prezzo_MAX") = ""

            Dim Prezzo_MIN As Double = Val(Session.Item("Valore_Prezzo_MIN"))
            Dim Prezzo_MAX As Double = Val(Session.Item("Valore_Prezzo_MAX"))

            If ((Prezzo_MIN > 0) And (Prezzo_MAX > 0)) Then
                If (Me.Session("IvaTipo") = 2) Then
                    strWhere = strWhere &
                        " AND (((PrezzoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))" &
                        " OR ((PrezzoPromoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoPromoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')))"
                Else
                    strWhere = strWhere &
                        " AND (((Prezzo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (Prezzo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))" &
                        " OR ((PrezzoPromo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoPromo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')))"
                End If
            Else
                If (Me.Session("IvaTipo") = 2) Then
                    If (Prezzo_MIN > 0) Then
                        strWhere = strWhere &
                            " AND ((PrezzoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')" &
                            " OR (PrezzoPromoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                    End If
                    If (Prezzo_MAX > 0) Then
                        strWhere = strWhere &
                            " AND ((PrezzoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "')" &
                            " OR (PrezzoPromoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "'))"
                    End If
                Else
                    If (Prezzo_MIN > 0) Then
                        strWhere = strWhere &
                            " AND ((Prezzo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')" &
                            " OR (PrezzoPromo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                    End If
                    If (Prezzo_MAX > 0) Then
                        strWhere = strWhere &
                            " AND ((Prezzo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "')" &
                            " OR (PrezzoPromo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "'))"
                    End If
                End If
            End If
        End If

        If ((Session.Item("Controllo_Variabile_PrezzoMinMax") = 1) And (Session("Prezzo_MIN") = "") And (Session("Prezzo_MAX") = "") And (Me.Page.IsPostBack = True)) Then
            Dim Prezzo_MIN As Double = Val(Session("Valore_Prezzo_MIN"))
            Dim Prezzo_MAX As Double = Val(Session("Valore_Prezzo_MAX"))
            If ((Prezzo_MIN > 0) And (Prezzo_MAX > 0)) Then
                If (Me.Session("IvaTipo") = 2) Then
                    strWhere = strWhere &
                        " AND (((PrezzoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))" &
                        " OR ((PrezzoPromoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoPromoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')))"
                Else
                    strWhere = strWhere &
                        " AND (((Prezzo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (Prezzo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))" &
                        " OR ((PrezzoPromo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoPromo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')))"
                End If
            Else
                If (Me.Session("IvaTipo") = 2) Then
                    If (Prezzo_MIN > 0) Then
                        strWhere = strWhere &
                            " AND ((PrezzoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')" &
                            " OR (PrezzoPromoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                    End If
                    If (Prezzo_MAX > 0) Then
                        strWhere = strWhere &
                            " AND ((PrezzoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "')" &
                            " OR (PrezzoPromoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "'))"
                    End If
                Else
                    If (Prezzo_MIN > 0) Then
                        strWhere = strWhere &
                            " AND ((Prezzo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')" &
                            " OR (PrezzoPromo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                    End If
                    If (Prezzo_MAX > 0) Then
                        strWhere = strWhere &
                            " AND ((Prezzo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "')" &
                            " OR (PrezzoPromo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "'))"
                    End If
                End If
            End If
        End If

        If (InOfferta = 1) Then
            strWhere = strWhere & " AND (InOfferta = 1) "
        End If

        Dim TC As Integer = Session("TC")
        If TC = 1 Then
            If Drop_Filtra_Taglia.SelectedIndex > 0 Then
                strWhere = strWhere & " AND articoli_tagliecolori.TagliaId=" & Drop_Filtra_Taglia.SelectedValue
            End If
            If Drop_Filtra_Colore.SelectedIndex > 0 Then
                strWhere = strWhere & " AND articoli_tagliecolori.ColoreId=" & Drop_Filtra_Colore.SelectedValue
            End If
        End If

        If strCerca <> "" Then
            strCerca = strCerca.Replace("'", "").Trim()
            Dim Parole() As String = Split(strCerca, " ")
            If (Parole.Length > 1) Then
                Dim Temp1 As String = ""
                Dim Temp2 As String = ""

                strWhere = strWhere & " AND ((Codice like '%" & strCerca & "%') OR (Ean like '%" & strCerca & "%') OR ((Descrizione1 like '%" & Parole(0) & "%')"
                strWhere2 = strWhere2 & " AND ((varticolibase.Codice like '%" & strCerca & "%') OR (varticolibase.Ean like '%" & strCerca & "%') OR ((varticolibase.Descrizione1 like '%" & Parole(0) & "%')"

                For i As Integer = 1 To (Parole.Length - 1)
                    Temp1 = Temp1 & " AND (Descrizione1 like '%" & Parole(i) & "%')"
                    Temp2 = Temp2 & " AND (varticolibase.Descrizione1 like '%" & Parole(i) & "%')"
                Next

                Temp1 = Temp1 & "))"
                Temp2 = Temp2 & "))"

                strWhere = strWhere & Temp1
                strWhere2 = strWhere2 & Temp2
            Else
                strWhere = strWhere & " AND ((Codice like '%" & strCerca & "%') or (Descrizione1 like '%" & strCerca & "%') or (Ean like '%" & strCerca & "%'))"
                strWhere2 = strWhere2 & " AND ((varticolibase.Codice like '%" & strCerca & "%') or (varticolibase.Descrizione1 like '%" & strCerca & "%') or (varticolibase.Ean like '%" & strCerca & "%'))"
            End If

            Me.lblRicerca.Visible = True
            Me.lblRisultati.Text = strCerca
            Me.Title = Me.Title & " > " & lblRicerca.Text & strCerca
        End If

        strWhere = strWhere & " GROUP BY id"

        If Drop_Ordinamento.SelectedValue = "P_offerta" Then
            strWhere = strWhere & " ORDER BY InOfferta DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC"
        End If
        If Drop_Ordinamento.SelectedValue = "P_basso" Then
            strWhere = strWhere & " ORDER BY PrezzoIvato ASC, Prezzo ASC, Ord_PrezzoPromo ASC, Ord_PrezzoPromoIvato ASC,  (Giacenza-Impegnata) DESC"
        End If
        If Drop_Ordinamento.SelectedValue = "P_alto" Then
            strWhere = strWhere & " ORDER BY PrezzoIvato DESC, Prezzo DESC, Ord_PrezzoPromo ASC, Ord_PrezzoPromoIvato ASC,  (Giacenza-Impegnata) DESC"
        End If
        If Drop_Ordinamento.SelectedValue = "P_popolarità" Then
            strWhere = strWhere & " ORDER BY visite DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC"
        End If
        If Drop_Ordinamento.SelectedValue = "P_recenti" Then
            strWhere = strWhere & " ORDER BY id DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC"
        End If

        If TC = 1 Then
            strWhere = strWhere & " ,articoli_tagliecolori.TagliaId, articoli_tagliecolori.ColoreId"
        End If

        Me.sdsArticoli.SelectCommand = strSelect & " WHERE Nlistino=" & NListino & " " & strWhere

        strWhere2 = " LEFT JOIN vsuperarticoli ON vsuperarticoli.Id = varticolibase.id " & strWhere2 & " AND Nlistino=" & NListino

        Me.sdsMarche.SelectCommand =
            "select Giacenza, `varticolibase`.`MarcheId` AS `MarcheId`,`Marche`.`Descrizione` AS `Descrizione`," &
            "`Marche`.`Ordinamento` AS `Ordinamento`,count(DISTINCT `varticolibase`.`id`) AS `Numero`" &
            " from `varticolibase` join `Marche` on(`varticolibase`.`MarcheId` = `Marche`.`id`) " &
            Regex.Replace(strWhere2, " AND varticolibase.MarcheId in \(([^\)])+\) ", String.Empty) &
            " group by `Marche`.`Descrizione` order by `Marche`.`Ordinamento`, `Marche`.`Descrizione`"

        Me.sdsTipologie.SelectCommand =
            "select Giacenza,`varticolibase`.`TipologieId` AS `TipologieId`,`tipologie`.`Descrizione` AS `Descrizione`," &
            "`tipologie`.`Ordinamento` AS `Ordinamento`,count(DISTINCT `varticolibase`.`id`) AS `Numero`" &
            " from `varticolibase` join `tipologie` on(`varticolibase`.`TipologieId` = `tipologie`.`id`) " &
            Regex.Replace(strWhere2, " AND varticolibase.TipologieId in \(([^\)])+\) ", String.Empty) &
            " group by `tipologie`.`Descrizione` order by `tipologie`.`Ordinamento`, `tipologie`.`Descrizione`"

        Me.sdsGruppo.SelectCommand =
            "select Giacenza,GROUP_CONCAT(DISTINCT `varticolibase`.`GruppiId` SEPARATOR '|') AS `GruppiId`," &
            "`Gruppi`.`Descrizione` AS `Descrizione`,`Gruppi`.`Ordinamento` AS `Ordinamento`," &
            "count(DISTINCT `varticolibase`.`id`) AS `Numero`" &
            " from `varticolibase` join `Gruppi` on(`varticolibase`.`GruppiId` = `Gruppi`.`id`) " &
            Regex.Replace(strWhere2, " AND varticolibase.GruppiId in \(([^\)])+\) ", String.Empty) &
            " group by `Gruppi`.`Descrizione` order by `Gruppi`.`Ordinamento`, `Gruppi`.`Descrizione`"

        Me.sdsSottogruppo.SelectCommand =
            "select Giacenza,`varticolibase`.`SottoGruppiId` AS `SottoGruppiId`," &
            "`SottoGruppi`.`Descrizione` AS `Descrizione`,`SottoGruppi`.`Ordinamento` AS `Ordinamento`," &
            "count(DISTINCT `varticolibase`.`id`) AS `Numero`" &
            " from `varticolibase` join `SottoGruppi` on(`varticolibase`.`SottoGruppiId` = `SottoGruppi`.`id`) " &
            Regex.Replace(strWhere2, " AND varticolibase.SottogruppiId in \(([^\)])+\) ", String.Empty) &
            " group by `SottoGruppi`.`Descrizione` order by `SottoGruppi`.`Ordinamento`, `SottoGruppi`.`Descrizione`"

        If (InOfferta = 1) Then
            Me.sdsTipologie.SelectCommand =
                "SELECT *, COUNT(TipologieId) AS Numero FROM (" &
                " SELECT MarcheId, MarcheDescrizione, SettoriId, SettoriDescrizione, CategorieId, CategorieDescrizione," &
                " TipologieId, TipologieDescrizione AS Descrizione, GruppiId, GruppiDescrizione, SottogruppiId, SottogruppiDescrizione" &
                " FROM vsuperarticoli" &
                " WHERE (inofferta=1)" &
                " AND ((" & NListino & ">=OfferteDaListino) AND (" & NListino & "<=OfferteAListino))" &
                " AND (NListino=" & NListino & ")" &
                " AND ((CURDATE()>=offerteDatainizio) AND (CURDATE()<=offerteDataFine))" &
                " AND (TipologieDescrizione IS NOT NULL)" &
                " AND (" &
                IIf(Not String.IsNullOrEmpty(MarcheId), "(MarcheId in (" & MarcheId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(TipologieId), "(TipologieId in (" & TipologieId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(GruppiId), "(GruppiId in (" & GruppiId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(SottogruppiId), "(SottogruppiId in (" & SottogruppiId & "))", "(1=1)") &
                ") GROUP BY id) AS t1 GROUP BY Tipologieid"

            Me.sdsGruppo.SelectCommand =
                "SELECT *, COUNT(GruppiId) AS Numero FROM (" &
                " SELECT MarcheId, MarcheDescrizione, SettoriId, SettoriDescrizione, CategorieId, CategorieDescrizione," &
                " TipologieId, TipologieDescrizione, GruppiId, GruppiDescrizione AS Descrizione, SottogruppiId, SottogruppiDescrizione" &
                " FROM vsuperarticoli" &
                " WHERE (inofferta=1)" &
                " AND ((" & NListino & ">=OfferteDaListino) AND (" & NListino & "<=OfferteAListino))" &
                " AND (NListino=" & NListino & ")" &
                " AND ((CURDATE()>=offerteDatainizio) AND (CURDATE()<=offerteDataFine))" &
                " AND (GruppiDescrizione IS NOT NULL)" &
                " AND (" &
                IIf(Not String.IsNullOrEmpty(MarcheId), "(MarcheId in (" & MarcheId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(TipologieId), "(TipologieId in (" & TipologieId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(GruppiId), "(GruppiId in (" & GruppiId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(SottogruppiId), "(SottogruppiId in (" & SottogruppiId & "))", "(1=1)") &
                ") GROUP BY id) AS t1 GROUP BY GruppiId"

            Me.sdsSottogruppo.SelectCommand =
                "SELECT *, COUNT(SottogruppiId) AS Numero FROM (" &
                " SELECT MarcheId, MarcheDescrizione, SettoriId, SettoriDescrizione, CategorieId, CategorieDescrizione," &
                " TipologieId, TipologieDescrizione, GruppiId, GruppiDescrizione, SottogruppiId, SottogruppiDescrizione AS Descrizione" &
                " FROM vsuperarticoli" &
                " WHERE (inofferta=1)" &
                " AND ((" & NListino & ">=OfferteDaListino) AND (" & NListino & "<=OfferteAListino))" &
                " AND (NListino=" & NListino & ")" &
                " AND ((CURDATE()>=offerteDatainizio) AND (CURDATE()<=offerteDataFine))" &
                " AND (SottogruppiDescrizione IS NOT NULL)" &
                " AND (" &
                IIf(Not String.IsNullOrEmpty(MarcheId), "(MarcheId in (" & MarcheId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(TipologieId), "(TipologieId in (" & TipologieId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(GruppiId), "(GruppiId in (" & GruppiId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(SottogruppiId), "(SottogruppiId in (" & SottogruppiId & "))", "(1=1)") &
                ") GROUP BY id) AS t1 GROUP BY Gruppiid"

            Me.sdsMarche.SelectCommand =
                "SELECT *, COUNT(MarcheId) AS Numero FROM (" &
                " SELECT MarcheId, MarcheDescrizione AS Descrizione, SettoriId, SettoriDescrizione, CategorieId, CategorieDescrizione," &
                " TipologieId, TipologieDescrizione, GruppiId, GruppiDescrizione, SottogruppiId, SottogruppiDescrizione" &
                " FROM vsuperarticoli" &
                " WHERE (inofferta=1)" &
                " AND ((" & NListino & ">=OfferteDaListino) AND (" & NListino & "<=OfferteAListino))" &
                " AND (NListino=" & NListino & ")" &
                " AND ((CURDATE()>=offerteDatainizio) AND (CURDATE()<=offerteDataFine))" &
                " AND (MarcheDescrizione IS NOT NULL)" &
                " AND (" &
                IIf(Not String.IsNullOrEmpty(MarcheId), "(MarcheId in (" & MarcheId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(TipologieId), "(TipologieId in (" & TipologieId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(GruppiId), "(GruppiId in (" & GruppiId & "))", "(1=1)") & " AND " &
                IIf(Not String.IsNullOrEmpty(SottogruppiId), "(SottogruppiId in (" & SottogruppiId & "))", "(1=1)") &
                ") GROUP BY id) AS t1 GROUP BY marcheid"
        End If

        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()
        showFilters(conn, sdsArticoli.SelectCommand)
        conn.Close()

        Dim sdsArticoliToShow = Me.sdsArticoli.SelectCommand.Replace("'", """").ToUpper
    End Sub

    Public Sub SetSelectedIndex(ByVal dl As DataList, ByVal val As Integer)
        Dim Index As Integer = -1
        Dim hl As HyperLink

        dl.SelectedIndex = 0

        For i As Integer = 0 To dl.Items.Count - 1
            hl = dl.Items(i).FindControl("HyperLink1")
            If hl.TabIndex = val Then
                Index = i
                Me.Title = Me.Title & " > " & hl.Text
            End If
        Next
    End Sub

    Protected Sub sdsArticoli_Selected(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.SqlDataSourceStatusEventArgs) Handles sdsArticoli.Selected
        Me.lblTrovati.Text = e.AffectedRows.ToString
    End Sub

    Protected Sub GridView1_PageIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PageIndexChanged
        Session("Articoli_PageIndex") = Me.GridView1.PageIndex
    End Sub

    Function controlla_promo_articolo(ByVal cod_articolo As Integer, ByVal listino As Integer) As Integer
        Dim params As New Dictionary(Of String, Object)
        params.Add("@Listino", listino)
        params.Add("@CodArticolo", cod_articolo)
        Dim dr = ExecuteQueryGetDataReader("id", "vsuperarticoli",
                                           "where (ID=@CodArticolo AND NListino=@Listino) AND (OfferteDataInizio <= CURDATE() AND OfferteDataFine >= CURDATE()) AND InOfferta=1 ORDER BY PrezzoPromo DESC",
                                           params)
        If (dr.Count > 0) Then
            Return 1
        Else
            Return 0
        End If
    End Function

    ' *** VERSIONE RIPULITA: niente più sdsPromo/rPromo/img semaforo ***
    Protected Sub GridView1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PreRender
        ' Nascondo il bottone Wishlist se l'utente non è loggato
        For i As Integer = 0 To GridView1.Rows.Count - 1
            Dim lbWishlist As LinkButton = TryCast(GridView1.Rows(i).FindControl("LB_wishlist"), LinkButton)
            If lbWishlist IsNot Nothing Then
                Dim idUtente As Integer = 0
                If Session.Item("UtentiId") IsNot Nothing Then
                    Integer.TryParse(Session.Item("UtentiId").ToString(), idUtente)
                End If
                If idUtente <= 0 Then
                    lbWishlist.Visible = False
                End If
            End If
        Next

        ' Numero righe per pagina
        Me.lblLinee.Text = Me.GridView1.PageSize
    End Sub

    ' CLICK SU ICONA "CARRELLO" PER SINGOLO ARTICOLO
    Protected Sub ImageButton1_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        Dim img As ImageButton = TryCast(sender, ImageButton)
        If img Is Nothing Then Exit Sub

        Dim row As GridViewRow = TryCast(img.NamingContainer, GridViewRow)
        If row Is Nothing Then Exit Sub

        ' Listino corrente (default 1)
        Dim listino As Integer = 1
        Dim rawListino As String = Convert.ToString(Session("Listino"))
        Dim tmpListino As Integer
        If Integer.TryParse(rawListino, tmpListino) AndAlso tmpListino > 0 Then
            listino = tmpListino
        End If

        ' 1) ID ARTICOLO (usando gli helper)
        Dim idVal As Integer = GetArticoloIdFromRow(row)
        If idVal <= 0 Then
            ' Non riesco a capire che articolo sia, torno semplicemente alla lista
            Response.Redirect("articoli.aspx")
            Return
        End If

        ' 2) QUANTITÀ
        Dim qta As Integer = GetQuantitaFromRow(row)

        ' 3) TCID (Taglia/Colore) se presente, altrimenti -1
        Dim tcIdVal As Integer = GetTCIdFromRow(row)

        ' 4) PRODOTTO GRATIS (spedito gratis) calcolato da DB
        Session("ProdottoGratis") = spedito_gratis(idVal, listino)

        ' 5) CONTROLLO SETTORE
        If controlla_abilitazione_settore(idVal) = 1 Then
            ' Preparo le variabili che legge aggiungi.aspx.vb
            Session("Carrello_ArticoloId") = idVal.ToString()
            Session("Carrello_TCId") = tcIdVal.ToString()
            Session("Carrello_Quantita") = qta.ToString()
            Session("Carrello_SelezioneMultipla") = Nothing

            Response.Redirect("aggiungi.aspx")
        Else
            Response.Redirect("settore_disabilitato.aspx")
        End If
    End Sub

    Public Sub TitoloCategoria()
        Dim lblCategoria As Label
        lblCategoria = Me.FormView1.FindControl("lblCategoria")
        If (Not lblCategoria Is Nothing) AndAlso (Session.Item("ct") <> 30000) Then
            Me.Title = Me.Title & " > " & lblCategoria.Text
        Else
            Me.Title = "Tutte le Categorie"
        End If
    End Sub

    Protected Sub DataList1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList1.PreRender
        If Me.DataList1.Items.Count = 0 Then
            Me.DataList1.Visible = False
        End If
    End Sub

    Protected Sub DataList2_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList2.PreRender
        If Me.DataList2.Items.Count = 0 Then
            Me.DataList2.Visible = False
        End If
    End Sub

    Protected Sub DataList3_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList3.PreRender
        If Me.DataList3.Items.Count = 0 Then
            Me.DataList3.Visible = False
        End If
    End Sub

    Protected Sub DataList4_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList4.PreRender
        If Me.DataList4.Items.Count = 0 Then
            Me.DataList4.Visible = False
        End If
    End Sub

    Protected Sub rPromo_ItemDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.RepeaterItemEventArgs)
        ' Rimane qui per compatibilità, ma con il nuovo markup non viene più usato.
        ' Se in futuro ripristini il repeater delle promo, questa logica andrà riallineata al layout.
    End Sub

    Protected Sub Selezione_Multipla_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        Dim listaArticoli As New ArrayList()

        ' Listino corrente (default 1)
        Dim listino As Integer = 1
        Dim rawListino As String = Convert.ToString(Session("Listino"))
        Dim tmpList As Integer
        If Integer.TryParse(rawListino, tmpList) AndAlso tmpList > 0 Then
            listino = tmpList
        End If

        For Each row As GridViewRow In Me.GridView1.Rows
            Dim temp_check As CheckBox = TryCast(row.FindControl("CheckBox_SelezioneMultipla"), CheckBox)
            If temp_check IsNot Nothing AndAlso temp_check.Checked Then

                Dim idVal As Integer = GetArticoloIdFromRow(row)
                If idVal <= 0 Then Continue For

                ' Controllo settore per ogni articolo selezionato
                If controlla_abilitazione_settore(idVal) <> 1 Then
                    Response.Redirect("settore_disabilitato.aspx")
                    Return
                End If

                Dim tcIdVal As Integer = GetTCIdFromRow(row)
                Dim qta As Integer = GetQuantitaFromRow(row)
                Dim prodottoGratisFlag As Integer = spedito_gratis(idVal, listino)

                ' Stesso formato di sempre: id,tcid,qta,ProdottoGratis
                listaArticoli.Add(String.Format("{0},{1},{2},{3}", idVal, tcIdVal, qta, prodottoGratisFlag))
            End If
        Next

        If listaArticoli.Count = 0 Then
            ' Nessun articolo selezionato: non faccio nulla
            Return
        End If

        ' Per compatibilità, imposto anche i campi "singolo" con il primo articolo
        Dim first As String = listaArticoli(0).ToString()
        Dim parts() As String = first.Split(","c)
        If parts.Length >= 3 Then
            Session("Carrello_ArticoloId") = parts(0)
            Session("Carrello_TCId") = parts(1)
            Session("Carrello_Quantita") = parts(2)
        End If

        Session("Carrello_SelezioneMultipla") = listaArticoli
        Session("ProdottoGratis") = 0 ' la logica puntuale è comunque nella lista
        Me.Response.Redirect("aggiungi.aspx")
    End Sub

    ' ============================
    ' HELPER PER LETTURA DATI DAL ROW
    ' ============================
    Private Function GetArticoloIdFromRow(ByVal row As GridViewRow) As Integer
        Dim idVal As Integer = 0

        Dim lblId As Label = TryCast(row.FindControl("lblID"), Label)
        Dim lblId2 As Label = TryCast(row.FindControl("ID"), Label)
        Dim tbId As TextBox = TryCast(row.FindControl("tbID"), TextBox)
        Dim hfId As HiddenField = TryCast(row.FindControl("hfID"), HiddenField)
        Dim hfIdArt As HiddenField = TryCast(row.FindControl("hfIdArticolo"), HiddenField)

        If lblId IsNot Nothing Then
            Integer.TryParse(lblId.Text, idVal)
        ElseIf lblId2 IsNot Nothing Then
            Integer.TryParse(lblId2.Text, idVal)
        ElseIf tbId IsNot Nothing Then
            Integer.TryParse(tbId.Text, idVal)
        ElseIf hfId IsNot Nothing Then
            Integer.TryParse(hfId.Value, idVal)
        ElseIf hfIdArt IsNot Nothing Then
            Integer.TryParse(hfIdArt.Value, idVal)
        End If

        Return idVal
    End Function

    Private Function GetQuantitaFromRow(ByVal row As GridViewRow) As Integer
        Dim qta As Integer = 1
        Dim qtaBox As TextBox = TryCast(row.FindControl("tbQuantita"), TextBox)
        If qtaBox IsNot Nothing Then
            If Not Integer.TryParse(qtaBox.Text, qta) OrElse qta <= 0 Then
                qta = 1
            End If
        End If
        Return qta
    End Function

    Private Function GetTCIdFromRow(ByVal row As GridViewRow) As Integer
        Dim tcIdVal As Integer = -1
        Dim lblTC As Label = TryCast(row.FindControl("lblTCId"), Label)
        Dim hfTC As HiddenField = TryCast(row.FindControl("hfTCId"), HiddenField)

        If lblTC IsNot Nothing Then
            Integer.TryParse(lblTC.Text, tcIdVal)
        ElseIf hfTC IsNot Nothing Then
            Integer.TryParse(hfTC.Value, tcIdVal)
        End If

        Return tcIdVal
    End Function

    Public Function spedito_gratis(ByVal idArticolo As Integer, ByVal listino As Integer) As Integer
        Dim params As New Dictionary(Of String, Object)
        params.Add("@Listino", listino)
        params.Add("@IdArticolo", idArticolo)
        Dim dr = ExecuteQueryGetDataReader("SpedizioneGratis_Listini, SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine, id",
                                           "articoli",
                                           "where (SpedizioneGratis_Listini LIKE CONCAT('%',@Listino, ';%')) AND (id = @IdArticolo) AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())",
                                           params)
        If (dr.Count > 0) Then
            Return 1
        Else
            Return 0
        End If
    End Function

    Protected Sub BT_Aggiungi_wishlist_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim ctrl As Control = TryCast(sender, Control)
        If ctrl Is Nothing Then Return

        Dim row As GridViewRow = TryCast(ctrl.NamingContainer, GridViewRow)
        If row Is Nothing Then Return

        Dim idVal As Integer = GetArticoloIdFromRow(row)
        Dim tcIdVal As Integer = GetTCIdFromRow(row)

        Dim idUtente As Integer = 0
        Integer.TryParse(Convert.ToString(Session.Item("UtentiId")), idUtente)

        If idUtente <= 0 OrElse idVal <= 0 Then
            ' Utente non loggato o ID articolo non valido: non faccio nulla
            Return
        End If

        Dim paramsSelect As New Dictionary(Of String, Object)
        paramsSelect.Add("@IdArticolo", idVal)
        paramsSelect.Add("@TcId", tcIdVal)
        paramsSelect.Add("@IdUtente", idUtente)

        Dim dr = ExecuteQueryGetDataReader("id", "wishlist",
                                           "where (id_articolo=@IdArticolo) AND (TCid=@TcId) AND (id_utente=@IdUtente)",
                                           paramsSelect)

        If (dr.Count <= 0) Then
            Dim paramsProcedure As New Dictionary(Of String, String)
            paramsProcedure.Add("?pIdUtente", idUtente.ToString())
            paramsProcedure.Add("?pIdArticolo", idVal.ToString())
            paramsProcedure.Add("?pTCid", tcIdVal.ToString())
            ExecuteStoredProcedure(paramsProcedure, "NewElement_Wishlist")
        End If
    End Sub

    Function controlla_abilitazione_settore(ByVal idArticolo As Integer) As Integer
        Dim params As New Dictionary(Of String, Object)
        params.Add("@VsuperarticoliId", idArticolo)
        Dim dr = ExecuteQueryGetDataReader("*", "vsuperarticoli",
                                           "INNER JOIN settori ON settori.id=vsuperarticoli.SettoriId WHERE (vsuperarticoli.id=@VsuperarticoliId) AND (settori.Abilitato=1)",
                                           params)
        If (dr.Count > 0) Then
            Return 1
        Else
            Return 0
        End If
    End Function

    Protected Sub CheckBoxMr_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        CheckBoxFilter_CheckedChanged(sender, e, "mr")
    End Sub

    Protected Sub CheckBoxSg_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        CheckBoxFilter_CheckedChanged(sender, e, "sg")
    End Sub

    Protected Sub CheckBoxTp_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        CheckBoxFilter_CheckedChanged(sender, e, "tp")
    End Sub

    Protected Sub CheckBoxGr_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        CheckBoxFilter_CheckedChanged(sender, e, "gr")
    End Sub

    Protected Sub CheckBoxFilter_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs, ByVal parName As String)
        Dim checkBox As CheckBox = sender
        Dim filterId As String = checkBox.Attributes("filterId")
        Dim queryString As String = Request.QueryString(parName)
        Dim parValue As String = String.Empty

        If checkBox.Checked = True Then
            If queryString <> String.Empty Then
                parValue = queryString & "|" & filterId
            Else
                parValue = filterId
            End If
        Else
            Dim ids As String() = queryString.Split("|"c)
            If ids.Length > 1 Then
                Dim filterIdArray As String() = filterId.Split("|"c)
                For Each id As String In ids
                    If Not Array.IndexOf(filterIdArray, id) >= 0 Then
                        parValue &= id & "|"
                    End If
                Next
                If parValue.Length > 0 Then
                    parValue = parValue.Substring(0, parValue.Length - 1)
                End If
            End If
        End If

        Dim newUrl As String = changeUrlGetParam(Request.UrlReferrer.ToString, parName, parValue)
        Response.Redirect(newUrl)
    End Sub

    Protected Sub Drop_Ordinamento_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles Drop_Ordinamento.SelectedIndexChanged
        Dim newUrl As String = changeUrlDependingFromDropDownList(Request.UrlReferrer.ToString, Drop_Ordinamento, "ordinamento")
        Response.Redirect(newUrl)
    End Sub

    Protected Sub Drop_Filtra_Taglia_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles Drop_Filtra_Taglia.SelectedIndexChanged
        Dim newUrl As String = changeUrlDependingFromDropDownList(Request.UrlReferrer.ToString, Drop_Filtra_Taglia, "taglia")
        Response.Redirect(newUrl)
    End Sub

    Protected Sub Drop_Filtra_Colore_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles Drop_Filtra_Colore.SelectedIndexChanged
        Dim newUrl As String = changeUrlDependingFromDropDownList(Request.UrlReferrer.ToString, Drop_Filtra_Colore, "colore")
        Response.Redirect(newUrl)
    End Sub

    Protected Sub CheckBox_Disponibile_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles CheckBox_Disponibile.CheckedChanged
        Dim newUrl As String = changeUrlDependingFromCheckBox(Request.UrlReferrer.ToString, CheckBox_Disponibile, "disponibile", "1", "0")
        Response.Redirect(newUrl)
    End Sub
    Sub changeCheckBoxDependingFromUrl(ByVal checkBox As CheckBox, ByVal parName As String, ByVal parValueIfChecked As String)
        If Request.QueryString(parName) = parValueIfChecked Then
            checkBox.Checked = True
        Else
            checkBox.Checked = False
        End If
    End Sub

    Function changeUrlDependingFromCheckBox(ByVal url As String,
                                            ByVal checkBox As CheckBox,
                                            ByVal parName As String,
                                            ByVal parValueIfChecked As String,
                                            ByVal parValueIfNotChecked As String) As String
        Dim newUrl As String
        If checkBox.Checked = True Then
            newUrl = changeUrlGetParam(url, parName, parValueIfChecked)
        Else
            newUrl = changeUrlGetParam(url, parName, parValueIfNotChecked)
        End If
        Return newUrl
    End Function

    Sub changeDropDownListDependingFromUrl(ByVal dropDownList As DropDownList, ByVal parName As String)
        If Request.QueryString(parName) <> String.Empty Then
            dropDownList.SelectedValue = Request.QueryString(parName).Split("|"c)(1)
        End If
    End Sub

    Function changeUrlDependingFromDropDownList(ByVal url As String,
                                                ByVal dropDownList As DropDownList,
                                                ByVal parName As String) As String
        Return changeUrlGetParam(url, parName, dropDownList.SelectedIndex & "|" & dropDownList.SelectedValue)
    End Function

    Function changeUrlGetParam(ByVal url As String, ByVal parName As String, ByVal parValue As String) As String
        Dim newUrl As String = Regex.Replace(url, "&" & parName & "=([^&])+", String.Empty)
        newUrl = Regex.Replace(newUrl, "\?" & parName & "=([^&])+", "?")
        If parValue <> String.Empty Then
            newUrl = newUrl & "&" & parName & "=" & parValue
        End If
        Return newUrl.Replace("?&", "?")
    End Function

    Sub alert(ByVal message As String)
        Dim myScript As String = "window.alert('" & message.Replace("'", "|") & "');"
        ClientScript.RegisterStartupScript(Me.GetType(), "myScript", myScript, True)
    End Sub

    Function getCorrectLengthDescription(ByVal description As String) As String
        If description IsNot Nothing AndAlso description.Length > 28 Then
            Return description.Substring(0, 26) & "..."
        End If
        Return description
    End Function

    ' *** GESTIONE IMMAGINI PRODOTTO ***
    ' Usa la cartella pubblica ~/Public/images/articoli/ e la fallback ~/Public/images/nofoto.gif
    Public Function checkImg(ParamArray args() As Object) As String
        Dim fileName As String = ""

        If args IsNot Nothing AndAlso args.Length > 0 AndAlso
           args(0) IsNot Nothing AndAlso Not Convert.IsDBNull(args(0)) Then

            fileName = Convert.ToString(args(0)).Trim()
        End If

        ' Nessun valore: uso la nofoto
        If String.IsNullOrEmpty(fileName) Then
            Return "~/Public/images/nofoto.gif"
        End If

        ' Se è già un path completo, non lo tocchiamo
        If fileName.StartsWith("~") OrElse fileName.StartsWith("/") Then
            Return fileName
        End If

        ' Nome file "nudo": lo mettiamo nella cartella pubblica articoli
        Return "~/Public/images/articoli/" & fileName
    End Function

    ' Lista sicura di ID da QueryString (mr / tp / gr / sg)
    Private Function SafeIdListFromQuery(ByVal parName As String) As String
        Dim raw As String = Request.QueryString(parName)
        If String.IsNullOrEmpty(raw) Then
            Return String.Empty
        End If

        Dim parts As String() = raw.Split("|"c)
        Dim validIds As New List(Of String)()

        For Each p As String In parts
            If Not String.IsNullOrWhiteSpace(p) Then
                Dim id As Integer
                If Integer.TryParse(p.Trim(), id) AndAlso id > 0 Then
                    validIds.Add(id.ToString())
                End If
            End If
        Next

        If validIds.Count = 0 Then
            Return String.Empty
        End If

        Return String.Join(",", validIds)
    End Function

    Function getFilterIds(ByVal parName As String) As String()
        If Not String.IsNullOrEmpty(Request.QueryString(parName)) Then
            Return Request.QueryString(parName).Split("|"c)
        Else
            Dim result(0) As String
            Return result
        End If
    End Function

    Function addIds(ByVal filterIds As String, ByVal idsToAdd As String) As String
        Dim result As String = filterIds
        Dim filterIdsArray As String() = filterIds.Split("|"c)
        Dim idsToAddArray As String() = idsToAdd.Split("|"c)
        For Each id As String In idsToAddArray
            If Not Array.IndexOf(filterIdsArray, id) >= 0 Then
                result = result & "|" & id
            End If
        Next
        Return result
    End Function

    Function filterIdsContains(ByVal parName As String, ByVal ids As String) As Boolean
        If Not String.IsNullOrEmpty(Request.QueryString(parName)) Then
            Dim queryStringIds = Request.QueryString(parName).Split("|"c)
            Dim idsArray = ids.Split("|"c)
            For Each id As String In idsArray
                If Array.IndexOf(queryStringIds, id) >= 0 Then
                    If filters.ContainsKey(parName) Then
                        filters.Item(parName) = addIds(filters.Item(parName), ids)
                    Else
                        filters.Add(parName, ids)
                    End If
                    Return True
                End If
            Next
            Return False
        Else
            Return False
        End If
    End Function

    Protected Function ExecuteQueryGetDataSet(ByVal fields As String,
                                              ByVal table As String,
                                              Optional ByVal wherePart As String = "",
                                              Optional ByVal params As Dictionary(Of String, String) = Nothing) As DataSet
        Dim sqlString As String = "SELECT " & fields & " FROM " & table & " " & wherePart
        Dim ds As New DataSet()
        Dim conn As New MySqlConnection

        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd = New MySqlCommand With {
                    .Connection = conn,
                    .CommandType = CommandType.Text,
                    .CommandText = sqlString
                }
                If Not params Is Nothing Then
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If
                Dim sqlAdp As New MySqlDataAdapter(cmd)
                sqlAdp.Fill(ds, table)
                sqlAdp.Dispose()
                cmd.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try

        Return ds
    End Function

    Protected Function ExecuteQueryGetDataReader(ByVal fields As String,
                                                 ByVal table As String,
                                                 Optional ByVal wherePart As String = "",
                                                 Optional ByVal params As Dictionary(Of String, Object) = Nothing) As List(Of Dictionary(Of String, Object))
        Dim sqlString As String = "SELECT " & fields & " FROM " & table & " " & wherePart
        Dim result As New List(Of Dictionary(Of String, Object))()
        Dim conn As New MySqlConnection

        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd = New MySqlCommand With {
                    .Connection = conn,
                    .CommandType = CommandType.Text,
                    .CommandText = sqlString
                }
                If Not params Is Nothing Then
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If

                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    While dr.Read()
                        Dim row As New Dictionary(Of String, Object)()
                        For i As Integer = 0 To dr.FieldCount - 1
                            Dim columnName As String = dr.GetName(i)
                            Dim value As Object = dr.GetValue(i)
                            If Not row.ContainsKey(columnName) Then
                                row.Add(columnName, value)
                            End If
                        Next
                        result.Add(row)
                    End While
                End Using

                conn.Close()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try

        Return result
    End Function

    Protected Function ExecuteInsert(ByVal fields As String,
                                     ByVal table As String,
                                     Optional ByVal values As String = "",
                                     Optional ByVal params As Dictionary(Of String, Object) = Nothing)
        Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & values & ")"
        Dim conn As New MySqlConnection

        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
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

    Protected Sub ExecuteStoredProcedure(ByVal params As Dictionary(Of String, String), ByVal storedProcedure As String)
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.ConnectionString = connectionString
            conn.Open()
            Dim cmd = New MySqlCommand With {
                .Connection = conn,
                .CommandType = CommandType.StoredProcedure,
                .CommandText = storedProcedure
            }

            For Each paramName In params.Keys
                cmd.Parameters.AddWithValue(paramName, params(paramName))
            Next

            cmd.Parameters.AddWithValue("?parRetVal", "0")
            cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
            cmd.ExecuteNonQuery()
            cmd.Parameters.Clear()
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
    End Sub


    ' ======================================================================
    ' Helper: estrazione descrizione breve (usata nel databinding in markup)
    ' ======================================================================
    Public Function sotto_stringa(ByVal testo As Object) As String
        Dim s As String = ""
        If testo IsNot Nothing Then
            s = Convert.ToString(testo)
        End If

        If String.IsNullOrEmpty(s) Then Return ""

        ' Decode eventuali entità HTML, rimuove tag e normalizza spazi
        Try
            s = System.Web.HttpUtility.HtmlDecode(s)
        Catch
            ' ignore
        End Try

        s = Regex.Replace(s, "<[^>]*>", " ")
        s = Regex.Replace(s, "\s+", " ").Trim()

        Dim maxLen As Integer = 180
        If s.Length > maxLen Then
            s = s.Substring(0, maxLen).Trim()
            If s.Length > 0 Then s &= "..."
        End If

        ' Encode output per evitare HTML injection nel markup
        Return Server.HtmlEncode(s)
    End Function



    ' ============================================================
    ' SEO (Catalogo)
    ' ============================================================
    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Try
            EnsureCatalogSeo()
        Catch
            ' no-op
        End Try
    End Sub

    Private Sub EnsureCatalogSeo()
        Dim canonical As String = Request.Url.GetLeftPart(UriPartial.Path)

        If String.IsNullOrEmpty(Page.Title) Then
            Page.Title = "Catalogo prodotti"
        End If

        AddOrReplaceMeta(Me.Page, "robots", "index, follow")
        AddOrReplaceMeta(Me.Page, "description", "Catalogo prodotti - " & Page.Title)
        SetCanonical(Me.Page, canonical)

        Dim jsonLd As String = BuildSimplePageJsonLd(Page.Title, "Catalogo prodotti", canonical)
        SetJsonLdOnMaster(Me.Page, jsonLd)
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
End Class
