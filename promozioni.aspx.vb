Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class promozioni
    Inherits System.Web.UI.Page

    Dim IvaTipo As Integer
    Dim DispoTipo As Integer
    Dim DispoMinima As Integer
    Dim iMarcheId As Integer
    Dim iSettoriId As Integer
    Dim iCategorieId As Integer
    Dim iTipologieId As Integer
    Dim iGruppiId As Integer
    Dim iSottogruppiId As Integer
    Dim iArticoliId As Integer
    Dim iPromoID As Integer

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        Me.Session("Carrello_Pagina") = "promozioni.aspx"

        Me.tbData.Text = System.DateTime.Today

        IvaTipo = Me.Session("IvaTipo")
        DispoTipo = Me.Session("DispoTipo")
        DispoMinima = Me.Session("DispoMinima")

        If IvaTipo = 1 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Esclusa"
            Me.GridView1.Columns(5).SortExpression = "Prezzo"
        ElseIf IvaTipo = 2 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Inclusa"
            Me.GridView1.Columns(5).SortExpression = "PrezzoIvato"
        End If

        If DispoTipo = 1 Then
            Me.GridView1.Columns(2).HeaderText = "[Disp.]"
            Me.GridView1.Columns(3).Visible = False
            Me.GridView1.Columns(4).Visible = False
        ElseIf DispoTipo = 2 Then
            Me.GridView1.Columns(2).HeaderText = "[D]"
            Me.GridView1.Columns(3).Visible = True
            Me.GridView1.Columns(4).Visible = True
        End If

    End Sub

    Protected Sub Page_LoadComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.LoadComplete
        CaricaArticoli()
        Me.GridView1.PageSize = Me.Session("RigheArticoli")
        Me.GridView1.PageIndex = Session("Promo_PageIndex")
        If Not Me.IsPostBack Then
            'If IvaTipo = 1 Then
            'Me.GridView1.Sort("Prezzo", SortDirection.Ascending)
            'ElseIf IvaTipo = 2 Then
            'Me.GridView1.Sort("PrezzoIvato", SortDirection.Ascending)
            'End If
            'Me.GridView1.Sort("DataFinePromo", SortDirection.Ascending)
        End If
    End Sub

    Public Sub CaricaArticoli()
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim UtentiID As Integer = Me.Session("UtentiID")
        Dim NListino As Integer = Me.Session("Listino")
        Dim Data As Date = System.DateTime.Today
        Dim strSelect As String = "SELECT id, Codice, Ean, Descrizione1, Prezzo, PrezzoIvato, Img1, MarcheDescrizione, Disponibilita, InOrdine, Impegnata"
        Dim strSelect2 As String
        Dim strFrom As String = "FROM varticolilistini WHERE NListino=@listino"
        Dim strWhere As String
        Dim strArticoli As String = ""
        Dim MarcheID As String
        Dim SettoriId As String
        Dim CategorieId As String
        Dim TipologieId As String
        Dim GruppiId As String
        Dim SottoGruppiId As String
        Dim ArticoliId As String
        Dim strWhere2 As String = ""

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        iMarcheId = Me.Session("pmr")
        iSettoriId = Me.Session("pst")
        iCategorieId = Me.Session("pct")
        iTipologieId = Me.Session("ptp")
        iGruppiId = Me.Session("pgr")
        iSottogruppiId = Me.Session("psg")
        iArticoliId = Me.Session("part")
        iPromoID = Me.Session("pid")

        cmd.Connection = conn

        If iMarcheId > 0 Then
            strWhere2 = strWhere2 & " AND MarcheID=?iMarcheId"
            cmd.Parameters.AddWithValue("?iMarcheId", iMarcheId)
        End If
        If iSettoriId > 0 Then
            strWhere2 = strWhere2 & " AND SettoriId=?iSettoriId"
            cmd.Parameters.AddWithValue("?iSettoriId", iSettoriId)
        End If
        If iCategorieId > 0 Then
            strWhere2 = strWhere2 & " AND CategorieId=?iCategorieId"
            cmd.Parameters.AddWithValue("?iCategorieId", iCategorieId)
        End If
        If iTipologieId > 0 Then
            strWhere2 = strWhere2 & " AND TipologieId=?iTipologieId"
            cmd.Parameters.AddWithValue("?iTipologieId", iTipologieId)
        End If
        If iGruppiId > 0 Then
            strWhere2 = strWhere2 & " AND GruppiId=?iGruppiId"
            cmd.Parameters.AddWithValue("?iGruppiId", iGruppiId)
        End If
        If iSottogruppiId > 0 Then
            strWhere2 = strWhere2 & " AND SottogruppiId=?iSottogruppiId"
            cmd.Parameters.AddWithValue("?iSottogruppiId", iSottogruppiId)
        End If
        If iArticoliId > 0 Then
            strWhere2 = strWhere2 & " AND ArticoliId=?iArticoliId"
            cmd.Parameters.AddWithValue("?iArticoliId", iArticoliId)
        End If
        If iPromoID > 0 Then
            strWhere2 = strWhere2 & " AND OfferteId=?iPromoID"
            cmd.Parameters.AddWithValue("?iPromoID", iPromoID)
            SetSelectedIndex(Me.DataList4, iPromoID)
        End If

        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT * FROM vOfferteDettagli WHERE ((DaListino<=?NListino AND AListino>=?NListino) OR UtentiID=@UtentiID) AND (Abilitato=1) AND (DataInizio<=?Data) AND (DataFine>=?Data) " & strWhere2 & " ORDER BY OfferteId, id"
        cmd.Parameters.AddWithValue("?NListino", NListino)
        cmd.Parameters.AddWithValue("?UtentiID", UtentiID)
        cmd.Parameters.AddWithValue("?Data", Data)

        dr = cmd.ExecuteReader()

        While dr.Read()
            MarcheID = dr.Item("MarcheId").ToString
            SettoriId = dr.Item("SettoriId").ToString
            CategorieId = dr.Item("CategorieId").ToString
            TipologieId = dr.Item("TipologieId").ToString
            GruppiId = dr.Item("GruppiId").ToString
            SottoGruppiId = dr.Item("SottoGruppiId").ToString
            ArticoliId = dr.Item("ArticoliId").ToString

            strSelect2 = ""
            strWhere = ""

            strSelect2 = strSelect2 & ", '" & dr.Item("OfferteId") & "' as OfferteID "
            strSelect2 = strSelect2 & ", '" & dr.Item("Id") & "' as OfferteDettaglioId "
            strSelect2 = strSelect2 & ", '" & dr.Item("Descrizione") & "' as DescrizionePromo "
            strSelect2 = strSelect2 & ", '" & dr.Item("Immagine") & "' as ImmaginePromo "
            strSelect2 = strSelect2 & ", '" & dr.Item("DataInizio") & "' as DataInizioPromo "
            strSelect2 = strSelect2 & ", '" & dr.Item("DataFine") & "' as DataFinePromo "
            strSelect2 = strSelect2 & ", '" & dr.Item("QntMinima") & "' as QntMinimaPromo "
            strSelect2 = strSelect2 & ", '" & dr.Item("Multipli") & "' as MultipliPromo "
            strSelect2 = strSelect2 & ", '" & dr.Item("Prezzo") & "' as PrezzoPromo "
            strSelect2 = strSelect2 & ", '" & dr.Item("Sconto") & "' as ScontoPromo "

            If MarcheID <> "" And MarcheID <> "0" Then
                strWhere = strWhere & " AND MarcheID=" & MarcheID
            End If
            If SettoriId <> "" And SettoriId <> "0" Then
                strWhere = strWhere & " AND SettoriId=" & SettoriId
            End If
            If CategorieId <> "" And CategorieId <> "0" Then
                strWhere = strWhere & " AND CategorieId=" & CategorieId
            End If
            If TipologieId <> "" And TipologieId <> "0" Then
                strWhere = strWhere & " AND TipologieId=" & TipologieId
            End If
            If GruppiId <> "" And GruppiId <> "0" Then
                strWhere = strWhere & " AND GruppiId=" & GruppiId
            End If
            If SottoGruppiId <> "" And SottoGruppiId <> "0" Then
                strWhere = strWhere & " AND SottoGruppiId=" & SottoGruppiId
            End If
            If ArticoliId <> "" And ArticoliId <> "0" Then
                strWhere = strWhere & " AND Id=" & ArticoliId
            End If

            If strArticoli <> "" Then
                strArticoli = strArticoli & " UNION ALL "
            End If
            strArticoli = strArticoli & "(" & strSelect & strSelect2 & strFrom & strWhere & ")"

        End While

        dr.Close()
        dr.Dispose()

        cmd.Dispose()

        conn.Close()
        conn.Dispose()

        Me.sdsArticoli.SelectCommand = strArticoli
        Me.sdsArticoli.SelectParameters.Add("@listino", NListino)

    End Sub

    Public Sub SetSelectedIndex(ByVal dl As DataList, ByVal val As Integer)
        Dim i As Integer
        Dim Index As Integer = -1
        Dim hl As HyperLink

        For i = 0 To dl.Items.Count - 1
            hl = dl.Items(i).FindControl("HyperLink1")
            If hl.TabIndex = val Then
                Index = i
                Me.Title = Me.Title & " > " & hl.ToolTip
                dl.SelectedIndex = Index
            End If
        Next

        'If Index = -1 Then
        'hl = dl.Items(0).FindControl("HyperLink1")
        'Me.Title = Me.Title & " > " & hl.ToolTip
        'dl.SelectedIndex = 0
        'End If

    End Sub

    Protected Sub sdsArticoli_Selected(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.SqlDataSourceStatusEventArgs) Handles sdsArticoli.Selected
        Me.lblTrovati.Text = e.AffectedRows.ToString
    End Sub

    Protected Sub GridView1_PageIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PageIndexChanged
        Session("Promo_PageIndex") = Me.GridView1.PageIndex
    End Sub

    Protected Sub GridView1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PreRender

        Dim img As Image
        Dim dispo As Label
        Dim arrivo As Label
        Dim impegnato As Label
        Dim i As Integer

        For i = 0 To GridView1.Rows.Count - 1

            If IvaTipo = 1 Then
                GridView1.Rows(i).Cells(5).FindControl("lblPrezzo").Visible = True
                GridView1.Rows(i).Cells(5).FindControl("lblPrezzoIvato").Visible = False
            ElseIf IvaTipo = 2 Then
                GridView1.Rows(i).Cells(5).FindControl("lblPrezzo").Visible = False
                GridView1.Rows(i).Cells(5).FindControl("lblPrezzoIvato").Visible = True
            End If

            img = GridView1.Rows(i).Cells(2).FindControl("imgDispo")
            dispo = GridView1.Rows(i).Cells(2).FindControl("lblDispo")
            arrivo = GridView1.Rows(i).Cells(2).FindControl("lblArrivo")
            impegnato = GridView1.Rows(i).Cells(2).FindControl("lblImpegnata")

            If DispoTipo = 1 Then

                If dispo.Text > DispoMinima Then
                    img.ImageUrl = "~/images/verde.gif"
                    img.AlternateText = "Disponibile"
                ElseIf dispo.Text > 0 Then
                    img.ImageUrl = "~/images/giallo.gif"
                    img.AlternateText = "Disponibilità Scarsa"
                Else
                    If arrivo.Text > 0 Then
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

        Next

        Me.lblLinee.Text = Me.GridView1.PageSize

    End Sub

    Protected Sub ImageButton1_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)

        Dim qta As TextBox
        Dim codice As Label
        Dim descrizione As Label
        Dim prezzo As Label
        Dim prezzoivato As Label
        Dim ID As Label

        Dim img As Image = sender

        ID = img.Parent.FindControl("lblID")
        qta = img.Parent.FindControl("tbQuantita")
        codice = img.Parent.FindControl("lblCodice")
        descrizione = img.Parent.FindControl("lblDescrizione")
        prezzo = img.Parent.FindControl("lblPrezzo")
        prezzoivato = img.Parent.FindControl("lblPrezzoIvato")

        Me.Session("Carrello_ArticoloId") = ID.Text
        Me.Session("Carrello_Codice") = codice.Text
        Me.Session("Carrello_Descrizione") = descrizione.Text
        Me.Session("Carrello_Quantita") = qta.Text
        Me.Session("Carrello_Prezzo") = prezzo.Text
        Me.Session("Carrello_PrezzoIvato") = prezzoivato.Text

        Me.Response.Redirect("aggiungi.aspx")

    End Sub

    Protected Sub DataList1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList1.PreRender
        If Me.DataList1.Items.Count = 0 Then
            Me.DataList1.Visible = False
        Else
            If Me.DataList1.SelectedIndex > 0 Then
                'Me.DataList1.SelectedItem.Focus()
            End If
        End If
    End Sub

    Protected Sub DataList4_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList4.PreRender
        If Me.DataList4.Items.Count = 0 Then
            Me.DataList4.Visible = False
        Else
            If Me.DataList4.SelectedIndex > 0 Then
                Me.DataList4.SelectedItem.Focus()
            End If
        End If
    End Sub

    Protected Sub DataList2_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList2.PreRender

        Dim i As Integer
        Dim hl As HyperLink
        Dim MarcheId As Label
        Dim MarcheDescrizione As Label
        Dim SettoriID As Label
        Dim SettoriDescrizione As Label
        Dim CategorieId As Label
        Dim CategorieDescrizione As Label
        Dim TipologieId As Label
        Dim TipologieDescrizione As Label
        Dim GruppiId As Label
        Dim GruppiDescrizione As Label
        Dim SottogruppiID As Label
        Dim SottogruppiDescrizione As Label
        Dim ArticoliId As Label
        Dim ArticoliDescrizione As Label

        For i = 0 To DataList2.Items.Count - 1
            hl = DataList2.Items(i).FindControl("HyperLink1")
            MarcheId = DataList2.Items(i).FindControl("lblMarcheId")
            MarcheDescrizione = DataList2.Items(i).FindControl("lblMarcheDescrizione")
            SettoriID = DataList2.Items(i).FindControl("lblSettoriID")
            SettoriDescrizione = DataList2.Items(i).FindControl("lblSettoriDescrizione")
            CategorieId = DataList2.Items(i).FindControl("lblCategorieId")
            CategorieDescrizione = DataList2.Items(i).FindControl("lblCategorieDescrizione")
            TipologieId = DataList2.Items(i).FindControl("lblTipologieId")
            TipologieDescrizione = DataList2.Items(i).FindControl("lblTipologieDescrizione")
            GruppiId = DataList2.Items(i).FindControl("lblGruppiId")
            GruppiDescrizione = DataList2.Items(i).FindControl("lblGruppiDescrizione")
            SottogruppiID = DataList2.Items(i).FindControl("lblSottogruppiID")
            SottogruppiDescrizione = DataList2.Items(i).FindControl("lblSottogruppiDescrizione")
            ArticoliId = DataList2.Items(i).FindControl("lblArticoliId")
            ArticoliDescrizione = DataList2.Items(i).FindControl("lblArticoliDescrizione")

            If MarcheDescrizione.Text <> "" Then
                hl.Text = hl.Text & " <font color='#E12825'><b>»</b></font> " & MarcheDescrizione.Text.ToUpper
                hl.NavigateUrl = hl.NavigateUrl & "&pmr=" & MarcheId.Text
            End If
            If SettoriDescrizione.Text <> "" Then
                hl.Text = hl.Text & " <font color='#E12825'><b>»</b></font> " & SettoriDescrizione.Text.ToUpper
                hl.NavigateUrl = hl.NavigateUrl & "&pst=" & SettoriID.Text
            End If
            If CategorieDescrizione.Text <> "" Then
                hl.Text = hl.Text & " <font color='#E12825'><b>»</b></font> " & CategorieDescrizione.Text.ToUpper
                hl.NavigateUrl = hl.NavigateUrl & "&pct=" & CategorieId.Text
            End If
            If TipologieDescrizione.Text <> "" Then
                hl.Text = hl.Text & " <font color='#E12825'><b>»</b></font> " & TipologieDescrizione.Text.ToUpper
                hl.NavigateUrl = hl.NavigateUrl & "&ptp=" & TipologieId.Text
            End If
            If GruppiDescrizione.Text <> "" Then
                hl.Text = hl.Text & " <font color='#E12825'><b>»</b></font> " & GruppiDescrizione.Text.ToUpper
                hl.NavigateUrl = hl.NavigateUrl & "&pgr=" & GruppiId.Text
            End If
            If SottogruppiDescrizione.Text <> "" Then
                hl.Text = hl.Text & "<font color='#E12825'><b>»</b></font> " & SottogruppiDescrizione.Text.ToUpper
                hl.NavigateUrl = hl.NavigateUrl & "&psg=" & SottogruppiID.Text
            End If
            If ArticoliDescrizione.Text <> "" Then
                hl.Text = hl.Text & " <font color='#E12825'><b>»</b></font> " & ArticoliDescrizione.Text.ToUpper
                hl.NavigateUrl = hl.NavigateUrl & "&part=" & ArticoliId.Text
            End If

            If iMarcheId > 0 And MarcheId.Text <> "" Then
                If iMarcheId = MarcheId.Text Then
                    Me.DataList2.SelectedIndex = i
                End If
            End If
            If iSettoriId > 0 And SettoriID.Text <> "" Then
                If iSettoriId = SettoriID.Text Then
                    Me.DataList2.SelectedIndex = i
                End If
            End If
            If iCategorieId > 0 And CategorieId.Text <> "" Then
                If iCategorieId = CategorieId.Text Then
                    Me.DataList2.SelectedIndex = i
                End If
            End If
            If iTipologieId > 0 And TipologieId.Text <> "" Then
                If iTipologieId = TipologieId.Text Then
                    Me.DataList2.SelectedIndex = i
                End If
            End If
            If iGruppiId > 0 And GruppiId.Text <> "" Then
                If iGruppiId = GruppiId.Text Then
                    Me.DataList2.SelectedIndex = i
                End If
            End If
            If iSottogruppiId > 0 And SottogruppiID.Text <> "" Then
                If iSottogruppiId = SottogruppiID.Text Then
                    Me.DataList2.SelectedIndex = i
                End If
            End If
            If iArticoliId > 0 And ArticoliId.Text <> "" Then
                If iArticoliId = ArticoliId.Text Then
                    Me.DataList2.SelectedIndex = i
                End If
            End If

        Next

        If Me.DataList2.Items.Count = 0 Then
            Me.DataList2.Visible = False
        Else
            If Me.DataList2.SelectedIndex > 0 Then
                'Me.DataList2.SelectedItem.Focus()
            End If
        End If
    End Sub

End Class
