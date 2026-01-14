Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class Articoli
    Inherits System.Web.UI.Page

    Dim IvaTipo As Integer
    Dim DispoTipo As Integer
    Dim DispoMinima As Integer
    Dim InOfferta As Integer

    Function sostituisci_caratteri_speciali(ByRef stringa As String) As String
        stringa = Server.HtmlDecode(stringa)
        Return stringa
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        'Redirect nel caso c'è la presenza di #up
        If Request.Url.AbsoluteUri.Contains("%23up") Or (Request.Url.AbsoluteUri.Contains("#23up")) Then
            Response.Redirect(Request.Url.AbsoluteUri.Replace("%23up", "").Replace("#23up", ""))
        End If

        Session.Item("Pagina_visitata_Articoli") = Me.Request.Url.ToString 'Aggiorno l'ultima pagina visitata in Articoli

        Me.Session("Carrello_Pagina") = "rettificaMagazzino.aspx"

        DispoTipo = Me.Session("DispoTipo")
        DispoMinima = Me.Session("DispoMinima")
        InOfferta = Me.Session("InOfferta")

        'Assegnazione della variabile in offerta, per visualizzare solo i prodotti in offerta
        If Me.Request.QueryString("inpromo") <> "" Then
            InOfferta = Me.Request.QueryString("inpromo")
        End If

        
    End Sub

    Protected Sub Page_LoadComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.LoadComplete

        IvaTipo = Me.Session("IvaTipo")

        'Modificato Ordine nella GridView
        'Il criterio d'ordine si trova nella vista "vsuperarticoli"
        If IvaTipo = 1 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Esclusa*"
            'Me.GridView1.Columns(5).SortExpression = "Prezzo"
        ElseIf IvaTipo = 2 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Inclusa*"
            'Me.GridView1.Columns(5).SortExpression = "PrezzoIvato"
        End If

        CaricaArticoli()

        Me.GridView1.PageSize = Me.Session("RigheArticoli")
        Me.GridView1.PageIndex = Session("Articoli_PageIndex")

        'Inserimento della stringa di ricerca nella tabella query_string, per l'indicizzazione
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet
        Dim strCerca As String = Me.Session("q")

        Try

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            sqlString = "INSERT INTO query_string (QString) VALUES (?search)"

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.CommandText = sqlString
            cmd.Parameters.AddWithValue("?search", strCerca)

            strCerca = sostituisci_caratteri_speciali(strCerca)
            If (strCerca.Contains("&") = False) Or (strCerca.Contains(";") = False) Then 'Non inseriamo nel Database le parole che contengono "&" o "amp;"
                cmd.ExecuteNonQuery()
            End If

            cmd.Dispose()
        Catch ex As Exception

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try
    End Sub

    Public Sub CaricaArticoli()
        If Page.IsPostBack = False Then
            Dim NListino As Integer = Me.Session("Listino")
            Dim SettoriId As Integer
            Dim CategorieId As Integer
            Dim TipologieId As Integer
            Dim GruppiId As Integer
            Dim SottogruppiId As Integer
            Dim MarcheId As Integer
            Dim OfferteId As Integer
            Dim strCerca As String = ""
            Dim SpedizioneGratis As Integer = Me.Request.QueryString("spedgratis")

            'Carico le variabili da Sessione se non sono presenti nella QueryString
            If Me.Request.QueryString("st") <> "" Then
                SettoriId = Me.Request.QueryString("st")
            Else
                SettoriId = Me.Session("st")
            End If

            If Me.Request.QueryString("ct") <> "" Then
                CategorieId = Me.Request.QueryString("ct")
            Else
                CategorieId = Me.Session("ct")
            End If

            If Me.Request.QueryString("tp") <> "" Then
                TipologieId = Me.Request.QueryString("tp")
            Else
                TipologieId = Me.Session("tp")
            End If

            If Me.Request.QueryString("gr") <> "" Then
                GruppiId = Me.Request.QueryString("gr")
            Else
                GruppiId = Me.Session("gr")
            End If

            If Me.Request.QueryString("sg") <> "" Then
                SottogruppiId = Me.Request.QueryString("sg")
            Else
                SottogruppiId = Me.Session("sg")
            End If

            If Me.Request.QueryString("mr") <> "" Then
                MarcheId = Me.Request.QueryString("mr")
            Else
                MarcheId = Me.Session("mr")
            End If

            If Me.Request.QueryString("pid") <> "" Then
                OfferteId = Me.Request.QueryString("pid")
            Else
                OfferteId = Me.Session("pid")
            End If

            If Me.Request.QueryString("q") <> "" Then
                strCerca = Me.Request.QueryString("q").Replace("%23up", "").Replace("#up", "")
            Else
                If Not Session("q") Is Nothing Then
                    strCerca = Me.Session("q").Replace("%23up", "").Replace("#up", "")
                End If
            End If

            If InOfferta = 1 Then
                Session("Promo") = 1
            Else
                Session("Promo") = 0
            End If

            If Not strCerca Is Nothing Then
                strCerca = strCerca.Replace("'", "")
                strCerca = strCerca.Replace("*", "")
                'strCerca = strCerca.Replace("/", "")
                strCerca = strCerca.Replace("&", "")
                strCerca = strCerca.Replace("#", "")
            Else
                strCerca = "*"
                Me.Session("q") = "*"
            End If

            'Utile per visualizzare i prezzi con iva dell'utente
            Dim strSelect As String = "SELECT id, Codice, Ean, Descrizione1, Descrizione2, DescrizioneLunga, Prezzo, IF((" & Session("AbilitatoIvaReverseCharge") & "=1) AND (ValoreIvaRC>-1),((Prezzo)*((ValoreIvaRC/100)+1)),IF(" & Session("Iva_Utente") & ">0,((Prezzo)*((" & Session("Iva_Utente") & "/100)+1)),PrezzoIvato)) AS PrezzoIvato, Img1, MarcheDescrizione, Disponibilita, Giacenza, InOrdine, Impegnata, InOfferta, SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDescrizione, SottogruppiDescrizione, MarcheDescrizione, Marche_img, PrezzoPromo, IF((" & Session("AbilitatoIvaReverseCharge") & "=1) AND (ValoreIvaRC>-1),((PrezzoPromo)*((ValoreIvaRC/100)+1)),IF(" & Session("Iva_Utente") & ">0,((PrezzoPromo)*((" & Session("Iva_Utente") & "/100)+1)),PrezzoPromoIvato)) AS PrezzoPromoIvato, MarcheId, CategorieId, TipologieId, IF(PrezzoPromo IS NULL,Prezzo,PrezzoPromo) Ord_PrezzoPromo, IF(PrezzoPromoIvato IS NULL,PrezzoIvato,IF((" & Session("AbilitatoIvaReverseCharge") & "=1) AND (ValoreIvaRC>-1),((PrezzoPromo)*((ValoreIvaRC/100)+1)),IF(" & Session("Iva_Utente") & ">0,((PrezzoPromo)*((" & Session("Iva_Utente") & "/100)+1)),PrezzoPromoIvato))) Ord_PrezzoPromoIvato FROM vsuperarticoli "

            Dim strWhere As String = ""
            Dim strWhere2 As String = "WHERE 1=1 "

            If SettoriId > 0 And OfferteId = 0 Then
                'strWhere = strWhere & " AND (SettoriId=" & SettoriId & ") "
                'strWhere2 = strWhere2 & " AND (varticolibase.SettoriId=" & SettoriId & ") "
            End If

            If CategorieId > 0 Then
                If (Session("ct") <> 30000) Then 'Usiamo 30000 quando nella ricerca avanzata vogliamo effettuare la ricerca su tutte le categorie
                    strWhere = strWhere & " AND (CategorieId=" & CategorieId & ") "
                    strWhere2 = strWhere2 & " AND (varticolibase.CategorieId=" & CategorieId & ") "
                Else
                    strWhere = strWhere & " "
                    strWhere2 = strWhere2 & " "
                End If
                TitoloCategoria()
            ElseIf OfferteId > 0 Then
                strWhere = strWhere & " AND (OfferteId = " & OfferteId & ") "
                strWhere2 = strWhere2 & " AND (varticolibase.OfferteId = " & OfferteId & ") "
                Me.tNavig.Visible = False
            ElseIf strCerca = "" Then
                Response.Redirect("default.aspx")
            End If

            If MarcheId > 0 Then
                strWhere = strWhere & " AND (MarcheId=" & MarcheId & ") "
                strWhere2 = strWhere2 & " AND (varticolibase.MarcheId=" & MarcheId & ") "
                SetSelectedIndex(Me.DataList4, MarcheId)
            End If

            If TipologieId > 0 Then
                strWhere = strWhere & " AND (TipologieId=" & TipologieId & ") "
                strWhere2 = strWhere2 & " AND (varticolibase.TipologieId=" & TipologieId & ") "
                SetSelectedIndex(Me.DataList1, TipologieId)
            End If

            If GruppiId > 0 Then
                strWhere = strWhere & " AND (GruppiId=" & GruppiId & ") "
                strWhere2 = strWhere2 & " AND (varticolibase.GruppiId=" & GruppiId & ") "
                SetSelectedIndex(Me.DataList2, GruppiId)
            End If

            If SottogruppiId > 0 Then
                strWhere = strWhere & " AND (SottogruppiId=" & SottogruppiId & ") "
                strWhere2 = strWhere2 & " AND (varticolibase.SottogruppiId=" & SottogruppiId & ") "
                SetSelectedIndex(Me.DataList3, SottogruppiId)
            End If

            If SpedizioneGratis = 1 Then
                strWhere = strWhere & "AND (SpedizioneGratis_Listini LIKE CONCAT('%', " & Session("Listino") & ", ';%')) AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())"
                strWhere2 = strWhere2 & "AND (SpedizioneGratis_Listini LIKE CONCAT('%', " & Session("Listino") & ", ';%')) AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())"
            Else
                Me.Session("SpedGratis") = 0
            End If

            If strCerca <> "" Then
                strCerca.Replace("'", "").Trim()
                'Splitto nel caso siano state inserite più parole
                Dim Parole() As String = Split(strCerca, " ")
                If (Parole.Length > 1) Then
                    Dim i As Integer
                    Dim Temp1 As String = ""
                    Dim Temp2 As String = ""

                    strWhere = strWhere & " AND ((Codice like '%" & strCerca & "%') OR (Ean like '%" & strCerca & "%') OR ((Descrizione1 like '%" & Parole(0) & "%')"
                    strWhere2 = strWhere2 & " AND ((varticolibase.Codice like '%" & strCerca & "%') OR (varticolibase.Ean like '%" & strCerca & "%') OR ((varticolibase.Descrizione1 like '%" & Parole(0) & "%')"

                    'Il for parte da 1 per correttezza di sintassi (parole(0) è nell'istruzione precedente)
                    For i = 1 To (Parole.Length - 1)
                        Temp1 = Temp1 & " AND (Descrizione1 like '%" & Parole(i) & "%')"
                        Temp2 = Temp2 & " AND (varticolibase.Descrizione1 like '%" & Parole(i) & "%')"
                    Next
                    'Chiusura dell'AND
                    Temp1 = Temp1 & "))"
                    Temp2 = Temp2 & "))"

                    strWhere = strWhere & Temp1
                    strWhere2 = strWhere2 & Temp2
                Else
                    'Caso in cui viene inserita una singola parola come stringa di ricerca
                    strWhere = strWhere & " AND ((Codice like '%" & strCerca & "%') or (Descrizione1 like '%" & strCerca & "%') or (Ean like '%" & strCerca & "%'))"
                    strWhere2 = strWhere2 & " AND ((varticolibase.Codice like '%" & strCerca & "%') or (varticolibase.Descrizione1 like '%" & strCerca & "%') or (varticolibase.Ean like '%" & strCerca & "%'))"
                End If

                Me.lblRicerca.Visible = True
                Me.lblRisultati.Text = strCerca
                Me.Title = Me.Title & " > " & lblRicerca.Text & strCerca
                'Me.tNavig.Visible = False
            End If
            '///////////////////////////////////////////////////////////////////////////////////////
            If Me.Page.IsPostBack = False Then
                Session.Item("Controllo_Variabile_Promo") = 0 'Variabile di controllo
            End If

            If ((Session.Item("Controllo_Variabile_Promo") = 0) And (Session.Item("Promo") = 1)) Then
                Session.Item("Controllo_Variabile_Promo") = 1
                Session.Item("Promo") = 0   'Resetto la variabile promo impostata in Ricerca Avanzata
                strWhere = strWhere & " AND (InOfferta = 1) "
                'strWhere2 = strWhere2 & " AND (varticolibase.NoPromo > 0)"
            End If

            If ((Session.Item("Controllo_Variabile_Promo") = 1) And (Session.Item("Promo") = 0) And (Me.Page.IsPostBack = True)) Then 'Caso in cui voglio solo le Promo e poi scorro le pagine della GridView
                strWhere = strWhere & " AND (InOfferta = 1) "
                'strWhere2 = strWhere2 & " AND (varticolibase.NoPromo > 0)"
            End If
            '////////////////////////////////////////////////////////////////////////////////////////
            '///////////////////////////////////////////////////////////////////////////////////////
            If Me.Page.IsPostBack = False Then
                Session.Item("Controllo_Variabile_Disp") = 0 'Variabile di controllo
            End If

            If (Session.Item("Controllo_Variabile_Disp") = 0) And ((Session.Item("Disp") = 1) Or (Request.QueryString("dispo") = 1)) Then
                Session.Item("Controllo_Variabile_Disp") = 1
                Session.Item("Disp") = 0   'Resetto la variabile promo impostata in Ricerca Avanzata
                'strWhere = strWhere & "AND ((Giacenza-Impegnata)>0)" 
                strWhere = strWhere & "AND (Giacenza>0)"
            End If
            '////////////////////////////////////////////////////////////////////////////////////////
            '///////////////////////////////////////////////////////////////////////////////////////
            If Me.Page.IsPostBack = False Then
                Session.Item("Controllo_Variabile_PrezzoMinMax") = 0 'Variabile di controllo
                Session("Valore_Prezzo_MIN") = ""
                Session("Valore_Prezzo_MAX") = ""
            End If

            If (Session.Item("Controllo_Variabile_PrezzoMinMax") = 0) And ((Session.Item("Prezzo_MIN") <> "") Or (Session.Item("Prezzo_MAX") <> "")) Then
                Session.Item("Controllo_Variabile_PrezzoMinMax") = 1
                'Assegnazione dalla search_complete
                If (Session.Item("Prezzo_MIN").ToString <> "") Then
                    Session("Valore_Prezzo_MIN") = System.Convert.ToDouble(Session.Item("Prezzo_MIN").ToString.Replace(".", ","))
                End If
                If (Session.Item("Prezzo_MAX").ToString <> "") Then
                    Session("Valore_Prezzo_MAX") = System.Convert.ToDouble(Session.Item("Prezzo_MAX").ToString.Replace(".", ","))
                End If

                Session.Item("Prezzo_MIN") = ""
                Session.Item("Prezzo_MAX") = ""

                'Assegnazione del Prezzo_MIN e Prezzo_MAX da matchare
                Dim Prezzo_MIN As Double = Val(Session.Item("Valore_Prezzo_MIN"))
                Dim Prezzo_MAX As Double = Val(Session.Item("Valore_Prezzo_MAX"))

                If ((Prezzo_MIN > 0) And (Prezzo_MAX > 0)) Then
                    If (Me.Session("IvaTipo") = 2) Then
                        strWhere = strWhere & "AND (((PrezzoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                        strWhere = strWhere & "OR ((PrezzoPromoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoPromoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')))"
                    Else
                        strWhere = strWhere & "AND (((Prezzo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (Prezzo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                        strWhere = strWhere & "OR ((PrezzoPromo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoPromo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')))"
                    End If
                Else
                    If (Me.Session("IvaTipo") = 2) Then
                        If (Prezzo_MIN > 0) Then
                            strWhere = strWhere & "AND ((PrezzoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')"
                            strWhere = strWhere & "OR (PrezzoPromoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                        End If
                        If (Prezzo_MAX > 0) Then
                            strWhere = strWhere & "AND ((PrezzoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "')"
                            strWhere = strWhere & "OR (PrezzoPromoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "'))"
                        End If
                    Else
                        If (Prezzo_MIN > 0) Then
                            strWhere = strWhere & "AND ((Prezzo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')"
                            strWhere = strWhere & "OR (PrezzoPromo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                        End If
                        If (Prezzo_MAX > 0) Then
                            strWhere = strWhere & "AND ((Prezzo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "')"
                            strWhere = strWhere & "OR (PrezzoPromo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "'))"
                        End If
                    End If
                End If
            End If

            If ((Session.Item("Controllo_Variabile_PrezzoMinMax") = 1) And (Session("Prezzo_MIN") = "") And (Session("Prezzo_MAX") = "") And (Me.Page.IsPostBack = True)) Then 'Caso in cui voglio solo le Promo e poi scorro le pagine della GridView
                Dim Prezzo_MIN As Double = Val(Session("Valore_Prezzo_MIN"))
                Dim Prezzo_MAX As Double = Val(Session("Valore_Prezzo_MAX"))
                If ((Prezzo_MIN > 0) And (Prezzo_MAX > 0)) Then
                    If (Me.Session("IvaTipo") = 2) Then
                        strWhere = strWhere & "AND (((PrezzoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                        strWhere = strWhere & "OR ((PrezzoPromoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoPromoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')))"
                    Else
                        strWhere = strWhere & "AND (((Prezzo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (Prezzo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                        strWhere = strWhere & "OR ((PrezzoPromo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "') AND (PrezzoPromo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')))"
                    End If
                Else
                    If (Me.Session("IvaTipo") = 2) Then
                        If (Prezzo_MIN > 0) Then
                            strWhere = strWhere & "AND ((PrezzoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')"
                            strWhere = strWhere & "OR (PrezzoPromoIvato>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                        End If
                        If (Prezzo_MAX > 0) Then
                            strWhere = strWhere & "AND ((PrezzoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "')"
                            strWhere = strWhere & "OR (PrezzoPromoIvato<='" & Prezzo_MAX.ToString.Replace(",", ".") & "'))"
                        End If
                    Else
                        If (Prezzo_MIN > 0) Then
                            strWhere = strWhere & "AND ((Prezzo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "')"
                            strWhere = strWhere & "OR (PrezzoPromo>='" & Prezzo_MIN.ToString.Replace(",", ".") & "'))"
                        End If
                        If (Prezzo_MAX > 0) Then
                            strWhere = strWhere & "AND ((Prezzo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "')"
                            strWhere = strWhere & "OR (PrezzoPromo<='" & Prezzo_MAX.ToString.Replace(",", ".") & "'))"
                        End If
                    End If
                End If
            End If
            '////////////////////////////////////////////////////////////////////////////////////////

            If (InOfferta = 1) Then
                strWhere = strWhere & " AND (InOfferta = 1) "
                'strWhere2 = strWhere2 & " AND (varticolibase.NoPromo > 0)"
            End If

            'Aggiunta per la search_complete
            Me.sdsArticoli.SelectCommand = strSelect & " WHERE Nlistino=" & NListino & strWhere & " GROUP BY id ORDER BY InOfferta DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC GROUP BY id"

            'Opzioni di ordinamento
            If Drop_Ordinamento.SelectedValue = "P_offerta" Then
                sdsArticoli.SelectCommand = strSelect & " WHERE Nlistino=" & NListino & strWhere & " GROUP BY id ORDER BY InOfferta DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC"
            End If
            If Drop_Ordinamento.SelectedValue = "P_basso" Then
                sdsArticoli.SelectCommand = strSelect & " WHERE Nlistino=" & NListino & strWhere & " GROUP BY id ORDER BY Ord_PrezzoPromo ASC, Ord_PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC"
            End If
            If Drop_Ordinamento.SelectedValue = "P_alto" Then
                sdsArticoli.SelectCommand = strSelect & " WHERE Nlistino=" & NListino & strWhere & " GROUP BY id ORDER BY Ord_PrezzoPromo ASC, Ord_PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC"
            End If
            If Drop_Ordinamento.SelectedValue = "P_popolarità" Then
                sdsArticoli.SelectCommand = strSelect & " WHERE Nlistino=" & NListino & strWhere & " GROUP BY id ORDER BY visite DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC"
            End If
            If Drop_Ordinamento.SelectedValue = "P_recenti" Then
                sdsArticoli.SelectCommand = strSelect & " WHERE Nlistino=" & NListino & strWhere & " GROUP BY id ORDER BY id DESC, PrezzoPromo ASC, PrezzoPromoIvato ASC, PrezzoIvato ASC, Prezzo ASC, (Giacenza-Impegnata) DESC"
            End If

            'Stringa articoli in Sessione
            Me.Session("Stringa_articoli") = sdsArticoli.SelectCommand

            Me.sdsMarche.SelectCommand = "select `varticolibase`.`MarcheId` AS `MarcheId`,`Marche`.`Descrizione` AS `Descrizione`,`Marche`.`Ordinamento` AS `Ordinamento`,count(`varticolibase`.`id`) AS `Numero` from `varticolibase` join `Marche` on(`varticolibase`.`MarcheId` = `Marche`.`id`) " & strWhere2 & "  group by `varticolibase`.`MarcheId`,`Marche`.`Descrizione`,`Marche`.`Ordinamento` order by `Marche`.`Ordinamento`, `Marche`.`Descrizione`"
            Me.sdsTipologie.SelectCommand = "select `varticolibase`.`TipologieId` AS `TipologieId`,`tipologie`.`Descrizione` AS `Descrizione`,`tipologie`.`Ordinamento` AS `Ordinamento`,count(`varticolibase`.`id`) AS `Numero` from `varticolibase` join `tipologie` on(`varticolibase`.`TipologieId` = `tipologie`.`id`) " & strWhere2 & "  group by `varticolibase`.`TipologieId`,`tipologie`.`Descrizione`,`tipologie`.`Ordinamento` order by `tipologie`.`Ordinamento`, `tipologie`.`Descrizione`"
            Me.sdsGruppo.SelectCommand = "select `varticolibase`.`GruppiId` AS `GruppiId`,`Gruppi`.`Descrizione` AS `Descrizione`,`Gruppi`.`Ordinamento` AS `Ordinamento`,count(`varticolibase`.`id`) AS `Numero` from `varticolibase` join `Gruppi` on(`varticolibase`.`GruppiId` = `Gruppi`.`id`) " & strWhere2 & "  group by `varticolibase`.`GruppiId`,`Gruppi`.`Descrizione`,`Gruppi`.`Ordinamento` order by `Gruppi`.`Ordinamento`, `Gruppi`.`Descrizione`"
            Me.sdsSottogruppo.SelectCommand = "select `varticolibase`.`SottoGruppiId` AS `SottoGruppiId`,`SottoGruppi`.`Descrizione` AS `Descrizione`,`SottoGruppi`.`Ordinamento` AS `Ordinamento`,count(`varticolibase`.`id`) AS `Numero` from `varticolibase` join `SottoGruppi` on(`varticolibase`.`SottoGruppiId` = `SottoGruppi`.`id`) " & strWhere2 & "  group by `varticolibase`.`SottoGruppiId`,`SottoGruppi`.`Descrizione`,`SottoGruppi`.`Ordinamento` order by `SottoGruppi`.`Ordinamento`, `SottoGruppi`.`Descrizione`"

            'Menu Superiore per i filtri su Marche - Tipologie - Grupi e Sottogruppi
            If (InOfferta = 1) Then
                Me.sdsTipologie.SelectCommand = "SELECT *, COUNT(TipologieId) AS Numero FROM (SELECT MarcheId, MarcheDescrizione, SettoriId, SettoriDescrizione, CategorieId, CategorieDescrizione, TipologieId, TipologieDescrizione AS Descrizione, GruppiId, GruppiDescrizione, SottogruppiId, SottogruppiDescrizione FROM vsuperarticoli WHERE (inofferta=1) AND ((" & NListino & ">=OfferteDaListino) AND (" & NListino & "<=OfferteAListino)) AND (NListino=" & NListino & ") AND ((CURDATE()>=offerteDatainizio) AND (CURDATE()<=offerteDataFine)) AND (TipologieDescrizione IS NOT NULL) AND (" & IIf(MarcheId > 0, "(MarcheId=" & MarcheId & ")", "(1=1)") & " AND " & IIf(TipologieId > 0, "(TipologieId=" & TipologieId & ")", "(1=1)") & " AND " & IIf(GruppiId > 0, "(GruppiId=" & GruppiId & ")", "(1=1)") & " AND " & IIf(SottogruppiId > 0, "(SottogruppiId=" & SottogruppiId & ")", "(1=1)") & ") GROUP BY id) AS t1 GROUP BY Tipologieid"
                Me.sdsGruppo.SelectCommand = "SELECT *, COUNT(GruppiId) AS Numero FROM (SELECT MarcheId, MarcheDescrizione, SettoriId, SettoriDescrizione, CategorieId, CategorieDescrizione, TipologieId, TipologieDescrizione, GruppiId, GruppiDescrizione AS Descrizione, SottogruppiId, SottogruppiDescrizione FROM vsuperarticoli WHERE (inofferta=1) AND ((" & NListino & ">=OfferteDaListino) AND (" & NListino & "<=OfferteAListino)) AND (NListino=" & NListino & ") AND ((CURDATE()>=offerteDatainizio) AND (CURDATE()<=offerteDataFine)) AND (GruppiDescrizione IS NOT NULL) AND (" & IIf(MarcheId > 0, "(MarcheId=" & MarcheId & ")", "(1=1)") & " AND " & IIf(TipologieId > 0, "(TipologieId=" & TipologieId & ")", "(1=1)") & " AND " & IIf(GruppiId > 0, "(GruppiId=" & GruppiId & ")", "(1=1)") & " AND " & IIf(SottogruppiId > 0, "(SottogruppiId=" & SottogruppiId & ")", "(1=1)") & ") GROUP BY id) AS t1 GROUP BY GruppiId"
                Me.sdsSottogruppo.SelectCommand = "SELECT *, COUNT(SottogruppiId) AS Numero FROM (SELECT MarcheId, MarcheDescrizione, SettoriId, SettoriDescrizione, CategorieId, CategorieDescrizione, TipologieId, TipologieDescrizione, GruppiId, GruppiDescrizione, SottogruppiId, SottogruppiDescrizione AS Descrizione FROM vsuperarticoli WHERE (inofferta=1) AND ((" & NListino & ">=OfferteDaListino) AND (" & NListino & "<=OfferteAListino)) AND (NListino=" & NListino & ") AND ((CURDATE()>=offerteDatainizio) AND (CURDATE()<=offerteDataFine)) AND (SottogruppiDescrizione IS NOT NULL) AND (" & IIf(MarcheId > 0, "(MarcheId=" & MarcheId & ")", "(1=1)") & " AND " & IIf(TipologieId > 0, "(TipologieId=" & TipologieId & ")", "(1=1)") & " AND " & IIf(GruppiId > 0, "(GruppiId=" & GruppiId & ")", "(1=1)") & " AND " & IIf(SottogruppiId > 0, "(SottogruppiId=" & SottogruppiId & ")", "(1=1)") & ") GROUP BY id) AS t1 GROUP BY Gruppiid"
                Me.sdsMarche.SelectCommand = "SELECT *, COUNT(MarcheId) AS Numero FROM (SELECT MarcheId, MarcheDescrizione AS Descrizione, SettoriId, SettoriDescrizione, CategorieId, CategorieDescrizione, TipologieId, TipologieDescrizione, GruppiId, GruppiDescrizione, SottogruppiId, SottogruppiDescrizione FROM vsuperarticoli WHERE (inofferta=1) AND ((" & NListino & ">=OfferteDaListino) AND (" & NListino & "<=OfferteAListino)) AND (NListino=" & NListino & ") AND ((CURDATE()>=offerteDatainizio) AND (CURDATE()<=offerteDataFine)) AND (MarcheDescrizione IS NOT NULL) AND (" & IIf(MarcheId > 0, "(MarcheId=" & MarcheId & ")", "(1=1)") & " AND " & IIf(TipologieId > 0, "(TipologieId=" & TipologieId & ")", "(1=1)") & " AND " & IIf(GruppiId > 0, "(GruppiId=" & GruppiId & ")", "(1=1)") & " AND " & IIf(SottogruppiId > 0, "(SottogruppiId=" & SottogruppiId & ")", "(1=1)") & ") GROUP BY id) AS t1 GROUP BY marcheid"
            End If

            'Assegno alla Sessione le stringhe della selezione in promo delle Marche, Tipologia, Gruppo, Sottosgruppo
            Me.Session("Stringa_Marche") = Me.sdsMarche.SelectCommand
            Me.Session("Stringa_Tipologie") = Me.sdsTipologie.SelectCommand
            Me.Session("Stringa_Gruppo") = Me.sdsGruppo.SelectCommand
            Me.Session("Stringa_Sottogruppo") = Me.sdsSottogruppo.SelectCommand
        Else
            If (Request.QueryString("dispo") = 1) Then
                Session("Stringa_articoli") = Session("Stringa_articoli").ToString.Replace("WHERE", "WHERE (Giacenza>0) AND ")
            End If

            sdsArticoli.SelectCommand = Me.Session("Stringa_articoli")
            'Assegno i dati salvati in sessione
            Me.sdsMarche.SelectCommand = Me.Session("Stringa_Marche")
            Me.sdsTipologie.SelectCommand = Me.Session("Stringa_Tipologie")
            Me.sdsGruppo.SelectCommand = Me.Session("Stringa_Gruppo")
            Me.sdsSottogruppo.SelectCommand = Me.Session("Stringa_Sottogruppo")
        End If
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
        Me.lblTrovati.Text = e.AffectedRows.ToString
    End Sub

    Protected Sub GridView1_PageIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PageIndexChanged
        Session("Articoli_PageIndex") = Me.GridView1.PageIndex
    End Sub

    'Restituisce 1 se ci sono delle promo valide sull'articiolo altrimenti 0
    Function controlla_promo_articolo(ByVal cod_articolo As Integer, ByVal listino As Integer) As Integer
        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand

        cmd.CommandText = "SELECT id FROM vsuperarticoli WHERE (ID=" & cod_articolo & " AND NListino=" & listino & ") AND ((OfferteDataInizio <= CURDATE()) AND (OfferteDataFine >= CURDATE())) AND (InOfferta=1) ORDER BY PrezzoPromo DESC"

        cmd.Connection = conn
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If (dr.HasRows) Then
            dr.Close()
            conn.Close()
            Return 1
        Else
            dr.Close()
            conn.Close()
            Return 0
        End If
    End Function

    Protected Sub GridView1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PreRender
        Dim img, img2 As Image
        Dim dispo As Label
        Dim arrivo As Label
        Dim impegnato As Label
        Dim Prezzo As Label
        Dim PrezzoIvato As Label
        Dim label_impegnato As Label
        Dim label_prezzo As Label
        Dim label_prezzo_ivato As Label
        Dim Qta As TextBox
        Dim InOfferta As TextBox
        Dim rPromo As Repeater
        Dim i As Integer
        Dim tb_id As TextBox
        Dim SQLDATA_Promo As SqlDataSource
        Dim prezzoPromo As Label

        For i = 0 To GridView1.Rows.Count - 1
            label_prezzo = GridView1.Rows(i).FindControl("Label10")
            label_prezzo_ivato = GridView1.Rows(i).FindControl("Label4")
            prezzoPromo = GridView1.Rows(i).FindControl("lblPrezzoPromo")
            InOfferta = GridView1.Rows(i).FindControl("tbInOfferta")
            rPromo = GridView1.Rows(i).FindControl("rPromo")
            tb_id = GridView1.Rows(i).FindControl("tbid")
            If (InOfferta.Text = 1) And (controlla_promo_articolo(tb_id.Text, Session("listino")) = 1) Then
                SQLDATA_Promo = GridView1.Rows(i).FindControl("sdsPromo")
                SQLDATA_Promo.SelectCommand = "SELECT id, Codice, Ean, Descrizione1, Descrizione2, DescrizioneLunga, Prezzo, IF((@AbilitatoIvaReverseCharge=1) AND (ValoreIvaRC>-1),((Prezzo)*((ValoreIvaRC/100)+1)),IF(@ivaUtente>0,((Prezzo)*((@ivaUtente/100)+1)),PrezzoIvato)) AS PrezzoIvato, Img1, MarcheDescrizione, Disponibilita, Giacenza, InOrdine, Impegnata, InOfferta, SettoriDescrizione, CategorieDescrizione, TipologieDescrizione, GruppiDescrizione, SottogruppiDescrizione, MarcheDescrizione, Marche_img, PrezzoPromo, IF((@AbilitatoIvaReverseCharge=1) AND (ValoreIvaRC>-1),((PrezzoPromo)*((ValoreIvaRC/100)+1)),IF(@ivaUtente>0,((PrezzoPromo)*((@ivaUtente/100)+1)),PrezzoPromoIvato)) AS PrezzoPromoIvato, MarcheId, CategorieId, TipologieId, IF(PrezzoPromo IS NULL,Prezzo,PrezzoPromo) Ord_PrezzoPromo, IF(PrezzoPromoIvato IS NULL,PrezzoIvato,IF((@AbilitatoIvaReverseCharge=1) AND (ValoreIvaRC>-1),((PrezzoPromo)*((ValoreIvaRC/100)+1)),IF(@ivaUtente>0,((PrezzoPromo)*((@ivaUtente/100)+1)),PrezzoPromoIvato))) Ord_PrezzoPromoIvato, OfferteQntMinima, OfferteMultipli, OfferteDataInizio, OfferteDataFine FROM vsuperarticoli WHERE (ID=@id AND NListino=@listino) AND ((OfferteDataInizio <= CURDATE()) AND (OfferteDataFine >= CURDATE())) ORDER BY PrezzoPromo DESC"
                SQLDATA_Promo.SelectParameters.Add("@AbilitatoIvaReverseCharge", Session("AbilitatoIvaReverseCharge"))
                SQLDATA_Promo.SelectParameters.Add("@ivaUtente", Session("Iva_utente"))
                SQLDATA_Promo.SelectParameters.Add("@listino", Session("listino"))
                SQLDATA_Promo.SelectParameters.Add("@id", tb_id.Text)
                rPromo.DataSourceID = "sdsPromo"
            Else
                rPromo.DataSourceID = ""
                prezzoPromo.Visible = False
            End If

            Prezzo = GridView1.Rows(i).FindControl("lblPrezzo")
            PrezzoIvato = GridView1.Rows(i).FindControl("lblPrezzoIvato")
            Qta = GridView1.Rows(i).FindControl("tbQuantita")

            ' --------------------------------------------------------------------------------

            If IvaTipo = 1 Then
                Prezzo.Visible = True
                PrezzoIvato.Visible = False

                label_prezzo.Visible = True
                label_prezzo_ivato.Visible = False
            ElseIf IvaTipo = 2 Then
                Prezzo.Visible = False
                PrezzoIvato.Visible = True

                label_prezzo.Visible = False
                label_prezzo_ivato.Visible = True
            End If

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
        Dim temp As ImageButton = sender
        Dim temp2 As GridView

        Dim img As Image = sender
        Dim Qta As TextBox
        Dim ID As Label

        ID = img.Parent.FindControl("lblID")
        Qta = img.Parent.FindControl("tbQuantita")

        'Verifica se il settore del prodotto è Attivo o meno. Altrimenti reindirizzo l'utente verso una pagina di errore, 
        'che avvisa l'utente che l'amministratore ha disabilitato tale Settore e quindi tutti gli articoli correlati non 
        'sono più disponibili per la vendita
        If controlla_abilitazione_settore(Val(ID.Text)) = 1 Then
            temp2 = CType(temp.NamingContainer.FindControl("GridView3"), GridView)
            If temp2.Rows.Count > 0 Then
                'Comunico al carrello se il prodotto è un prodotto ha spedizione gratis
                Session("ProdottoGratis") = 1
            Else
                'Comunico al carrello se il prodotto non è un prodotto ha spedizione gratis
                Session("ProdottoGratis") = 0
            End If

            Me.Session("Carrello_ArticoloId") = ID.Text
            Me.Session("Carrello_Quantita") = Qta.Text

            'Me.Session("SpedizioneGratis_Listini")
            'Me.Session("SpedizioneGratis_Data_Inizio")
            'Me.Session("SpedizioneGratis_Data_Fine")

            Me.Response.Redirect("aggiungi.aspx")
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
            'Else
            'If Me.DataList1.SelectedIndex > 0 Then
            'Me.DataList1.SelectedItem.Focus()
            'End If
        ElseIf Session.Item("tp") <> 0 Then
            Dim lbl As Label
            lbl = DataList1.Items(0).FindControl("Label9")
            lbl.Text = "<font color=#E12825>(X)</font>"
        End If
    End Sub

    Protected Sub DataList2_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList2.PreRender
        If Me.DataList2.Items.Count = 0 Then
            Me.DataList2.Visible = False
            'Else
            'If Me.DataList2.SelectedIndex > 0 Then
            'Me.DataList2.SelectedItem.Focus()
            'End If
        ElseIf Session.Item("gr") <> 0 Then
            Dim lbl As Label
            lbl = DataList2.Items(0).FindControl("Label9")
            lbl.Text = "<font color=#E12825>(X)</font>"
        End If
    End Sub

    Protected Sub DataList3_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList3.PreRender
        If Me.DataList3.Items.Count = 0 Then
            Me.DataList3.Visible = False
            'Else
            'If Me.DataList3.SelectedIndex > 0 Then
            'Me.DataList3.SelectedItem.Focus()
            'End If
        ElseIf Session.Item("sg") <> 0 Then
            Dim lbl As Label
            lbl = DataList3.Items(0).FindControl("Label9")
            lbl.Text = "<font color=#E12825>(X)</font>"
        End If
    End Sub

    Protected Sub DataList4_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList4.PreRender
        If Me.DataList4.Items.Count = 0 Then
            Me.DataList4.Visible = False
            'Else
            'If Me.DataList4.SelectedIndex > 0 Then
            'Me.DataList4.SelectedItem.Focus()
            'End If
        ElseIf Session.Item("mr") <> 0 Then
            Dim lbl As Label
            lbl = DataList4.Items(0).FindControl("Label9")
            lbl.Text = "<font color=#E12825>(X)</font>"
        End If
    End Sub

    Protected Sub rPromo_ItemDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.RepeaterItemEventArgs)
        Dim label_sconto As Label
        Dim panel_sconto As Panel

        panel_sconto = e.Item.Parent.Parent.FindControl("Panel_Visualizza_Percentuale_Sconto")
        label_sconto = e.Item.Parent.Parent.FindControl("sconto_applicato")

        Dim Offerta As Label = e.Item.FindControl("lblOfferta")
        Dim InOfferta As Label = e.Item.FindControl("lblInOfferta")

        'Salvo in session inOfferta per controllare se visualizzare o meno da rettificaMagazzino.aspx
        'Session("InOfferta") = InOfferta.Text

        Dim QtaMin As Label = e.Item.FindControl("lblQtaMin")
        Dim QtaMultipli As Label = e.Item.FindControl("lblMultipli")
        Dim PrezzoPromo As Label = e.Item.FindControl("lblPrezzoPromo")
        Dim PrezzoPromoIvato As Label = e.Item.FindControl("lblPrezzoPromoIvato")

        Dim dispo As Label = e.Item.Parent.Parent.FindControl("Label_dispo")
        Dim Panel_offerta As Panel = e.Item.Parent.Parent.FindControl("Panel_in_offerta")
        Dim img_offerta As Image = e.Item.Parent.Parent.FindControl("img_offerta")
        Dim Qta As TextBox = e.Item.Parent.Parent.FindControl("tbQuantita")
        Dim ParentPrezzoPromo As Label = e.Item.Parent.Parent.FindControl("lblPrezzoPromo")
        Dim ParentPrezzo As Label = e.Item.Parent.Parent.FindControl("lblPrezzo")
        Dim ParentPrezzoIvato As Label = e.Item.Parent.Parent.FindControl("lblPrezzoIvato")

        Dim temp As String

        If InOfferta.Text = 1 Then
            Panel_offerta.Visible = True

            img_offerta.Visible = True

            If QtaMin.Text > 0 Then
                Offerta.Text = Offerta.Text & "MINIMO"
                QtaMin.Visible = True
                Qta.Text = QtaMin.Text
            ElseIf QtaMultipli.Text > 0 Then
                Offerta.Text = Offerta.Text & "MULTIPLI"
                QtaMultipli.Visible = True
                Qta.Text = QtaMultipli.Text
            End If

            If IvaTipo = 1 Then
                'Offerta.Text = Offerta.Text & " A € " & FormatNumber(PrezzoPromo.Text, 2)
                ParentPrezzoPromo.Text = "€ " & FormatNumber(PrezzoPromo.Text, 2)
                PrezzoPromo.Visible = True
                ParentPrezzo.Visible = True
                ParentPrezzo.Font.Strikeout = True

                temp = ParentPrezzoPromo.Text
            ElseIf IvaTipo = 2 Then
                'Offerta.Text = Offerta.Text & " A € " & FormatNumber(PrezzoPromoIvato.Text, 2)
                ParentPrezzoPromo.Text = "€ " & FormatNumber(PrezzoPromoIvato.Text, 2)
                PrezzoPromoIvato.Visible = True
                ParentPrezzoIvato.Visible = True
                ParentPrezzoIvato.Font.Strikeout = True

                temp = ParentPrezzoPromo.Text
            End If

            'Stampo a video lo sconto applcato all'offerta
            panel_sconto.Visible = True
            If IvaTipo = 1 Then
                'label_sconto.Text = "- " & String.Format("{0:0}", ((100 * (ParentPrezzo.Text - temp)) / ParentPrezzo.Text)) & "%"
                label_sconto.Text = String.Format("{0:0}", (((ParentPrezzo.Text - temp) * 100) / ParentPrezzo.Text)) & "%"
            Else
                'label_sconto.Text = "- " & String.Format("{0:0}", ((100 * (ParentPrezzoIvato.Text - temp)) / ParentPrezzoIvato.Text)) & "%"
                label_sconto.Text = String.Format("{0:0}", (((ParentPrezzoIvato.Text - temp) * 100) / ParentPrezzoIvato.Text)) & "%"
            End If

            'Controllo che lo sconto non sia inferiore a 0
            Try
                If Val(label_sconto.Text) <= 0 Then
                    label_sconto.Text = "0%"
                Else
                    label_sconto.Text = "-" & label_sconto.Text
                End If
            Catch
            End Try


            Dim cifre_da_visualizzare As String = ""
            If Val(dispo.Text) > 0 Then
                cifre_da_visualizzare = "Images/cifre_ok/"
            Else
                cifre_da_visualizzare = "Images/cifre_no/"
            End If
        End If

    End Sub

    Protected Sub Selezione_Multipla_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        Dim i As Integer = 0
        Dim temp_check As CheckBox
        Dim ListaArticoli As New ArrayList

        Dim Qta As TextBox
        Dim ID As Label

        ID = Me.GridView1.Rows(i).FindControl("lblID")
        Qta = Me.GridView1.Rows(i).FindControl("tbQuantita")

        'Verifica se il settore del prodotto è Attivo o meno. Altrimenti reindirizzo l'utente verso una pagina di errore, 
        'che avvisa l'utente che l'amministratore ha disabilitato tale Settore e quindi tutti gli articoli correlati non 
        'sono più disponibili per la vendita
        If controlla_abilitazione_settore(Val(ID.Text)) = 1 Then
            For i = 0 To Me.GridView1.Rows.Count - 1
                temp_check = CType(Me.GridView1.Rows(i).FindControl("CheckBox_SelezioneMultipla"), CheckBox)
                If temp_check.Checked = True Then
                    Dim temp2 As GridView

                    temp2 = CType(Me.GridView1.Rows(i).FindControl("GridView3"), GridView)
                    If temp2.Rows.Count > 0 Then
                        'Comunico al carrello se il prodotto è un prodotto ha spedizione gratis
                        Session("ProdottoGratis") = 1
                    Else
                        'Comunico al carrello se il prodotto non è un prodotto ha spedizione gratis
                        Session("ProdottoGratis") = 0
                    End If


                    ID = Me.GridView1.Rows(i).FindControl("lblID")
                    Qta = Me.GridView1.Rows(i).FindControl("tbQuantita")

                    Me.Session("Carrello_ArticoloId") = ID.Text
                    Me.Session("Carrello_Quantita") = Qta.Text

                    ListaArticoli.Add(ID.Text & "," & Qta.Text & "," & Session("ProdottoGratis"))
                End If
            Next

            Session("Carrello_SelezioneMultipla") = ListaArticoli
            Me.Response.Redirect("aggiungi.aspx")
        Else
            Response.Redirect("settore_disabilitato.aspx")
        End If
    End Sub

    Public Function spedito_gratis(ByVal idArticolo As Integer, ByVal listino As Integer) As Integer
        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand

        cmd.CommandText = "SELECT SpedizioneGratis_Listini, SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine, id FROM articoli WHERE (SpedizioneGratis_Listini LIKE CONCAT('%'," & listino & ", ';%')) AND (id = " & idArticolo & ") AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())"

        cmd.Connection = conn
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        'Restituisce 1 nel caso ci sia almeno una riga come risultato, e quindi il settore relativo all' IDArticolo è ABILITATO altrimenti restituisce 0
        If (dr.HasRows = True) Then
            conn.Close()
            dr.Close()
            Return 1
        Else
            conn.Close()
            dr.Close()
            Return 0
        End If
    End Function

    Protected Sub Drop_Ordinamento_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles Drop_Ordinamento.SelectedIndexChanged
        Session("Articoli_PageIndex") = 0
    End Sub

    Protected Sub BT_Aggiungi_wishlist_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand

        Dim ArticoloId As Label = sender.NamingContainer.FindControl("label_idArticolo")

        If (Session.Item("UtentiId") > 0) Then
            cmd.CommandText = "Select id_wishlist from wishlist where (id_articolo=?ArticoloId) AND (id_utente=?UtentiID)"
            cmd.Parameters.AddWithValue("?ArticoloId", ArticoloId.Text)
            cmd.Parameters.AddWithValue("?UtentiID", Session.Item("UtentiID"))

            cmd.Connection = conn
            Dim dr As MySqlDataReader = cmd.ExecuteReader()
            dr.Read()
            conn.Close()

            If (dr.HasRows = False) Then
                conn.Open()
                'Inserisco articolo
                cmd.CommandType = CommandType.StoredProcedure
                cmd.CommandText = "NewElement_Wishlist"

                cmd.Parameters.AddWithValue("?pIdUtente", Session.Item("UtentiID"))
                cmd.Parameters.AddWithValue("?pIdArticolo", ArticoloId.Text)
                cmd.ExecuteNonQuery()
            End If

            'dr.Close()
            'dr.Dispose()
            'cmd.Dispose()

            cmd.Parameters.Clear()
            cmd.Dispose()

            conn.Close()
            conn.Dispose()
        End If
    End Sub

    Function controlla_abilitazione_settore(ByVal idArticolo As Integer) As Integer
        Dim conn As New MySqlConnection
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        Dim cmd As New MySqlCommand

        cmd.CommandText = "SELECT * FROM vsuperarticoli INNER JOIN settori ON settori.id=vsuperarticoli.SettoriId WHERE (vsuperarticoli.id=" & idArticolo & ") AND (settori.Abilitato=1)"

        cmd.Connection = conn
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        'Restituisce 1 nel caso ci sia almeno una riga come risultato, e quindi il settore relativo all' IDArticolo è ABILITATO altrimenti restituisce 0
        If (dr.HasRows = True) Then
            conn.Close()
            dr.Close()
            Return 1
        Else
            conn.Close()
            dr.Close()
            Return 0
        End If
    End Function

    Protected Sub CheckBox_Disponibile_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles CheckBox_Disponibile.CheckedChanged
        If CheckBox_Disponibile.Checked = True Then
            Response.Redirect(Request.UrlReferrer.ToString & "&dispo=1")
        Else
            Response.Redirect(Request.UrlReferrer.ToString.Replace("&dispo=1", ""))
        End If
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        'Devo ceccare la disponibilità se nella request è presente dispo=1
        If Request.QueryString("dispo") = 1 Then
            CheckBox_Disponibile.Checked = True
        Else
            CheckBox_Disponibile.Checked = False
        End If
    End Sub
End Class
