Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Globalization
Imports System.Web

Partial Class promozioni
    Inherits AntiCsrfPage

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

        If Not IsPostBack Then CartMutationIdempotencyService.ClearProgressiveRequestIds(HttpContext.Current, "promozioni:")

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
        Dim nListino As Integer = GetSessionInt("Listino", 0)
        Dim aziendaId As Integer = GetSessionInt("AziendaID", 0)

        iMarcheId = GetSessionInt("pmr", 0)
        iSettoriId = GetSessionInt("pst", 0)
        iCategorieId = GetSessionInt("pct", 0)
        iTipologieId = GetSessionInt("ptp", 0)
        iGruppiId = GetSessionInt("pgr", 0)
        iSottogruppiId = GetSessionInt("psg", 0)
        iArticoliId = GetSessionInt("part", 0)
        iPromoID = GetSessionInt("pid", 0)

        If iPromoID > 0 Then
            SetSelectedIndex(Me.DataList4, iPromoID)
        End If

        Me.sdsArticoli.SelectParameters.Clear()
        If nListino <= 0 OrElse aziendaId <= 0 OrElse iPromoID < 0 Then
            Me.sdsArticoli.SelectCommand = "SELECT * FROM varticolilistini WHERE 1=0"
            Return
        End If

        Dim eligibilityContext As ProductPromotionEligibilityContext =
            ProductPromotionEligibilityResolver.CreateContext(HttpContext.Current,
                                                              aziendaId,
                                                              nListino,
                                                              iPromoID)
        StorefrontPromotionCatalogProvider.AddParameters(Me.sdsArticoli.SelectParameters, eligibilityContext)
        Dim promotionJoin As String = StorefrontPromotionCatalogProvider.BuildLegacyCatalogJoin()

        Me.sdsArticoli.SelectCommand =
            "SELECT STRAIGHT_JOIN a.id, a.Codice, a.Ean, a.Descrizione1, a.Prezzo, a.PrezzoIvato, " &
            "       a.Img1, a.MarcheDescrizione, a.Disponibilita, a.InOrdine, a.Impegnata, " &
            "       ks_promo_catalog.OfferId AS OfferteID, ks_promo_catalog.OfferDetailId AS OfferteDettaglioId, " &
            "       ks_promo_catalog.OfferDescription AS DescrizionePromo, ks_promo_catalog.OfferImage AS ImmaginePromo, " &
            "       ks_promo_catalog.OfferStartsOn AS DataInizioPromo, ks_promo_catalog.OfferEndsOn AS DataFinePromo, " &
            "       ks_promo_catalog.OfferMinimumQuantity AS QntMinimaPromo, ks_promo_catalog.OfferMultipleQuantity AS MultipliPromo, " &
            "       ks_promo_catalog.OfferPrice AS PrezzoPromo, ks_promo_catalog.OfferDiscount AS ScontoPromo " &
            "FROM varticolilistini a " & promotionJoin &
            "WHERE a.NListino = @NListino " &
            "  AND (@pmr = 0 OR a.MarcheId = @pmr) " &
            "  AND (@pst = 0 OR a.SettoriId = @pst) " &
            "  AND (@pct = 0 OR a.CategorieId = @pct) " &
            "  AND (@ptp = 0 OR a.TipologieId = @ptp) " &
            "  AND (@pgr = 0 OR a.GruppiId = @pgr) " &
            "  AND (@psg = 0 OR a.SottoGruppiId = @psg) " &
            "  AND (@part = 0 OR a.id = @part) " &
            "ORDER BY a.Codice, a.Descrizione1, a.id"

        Me.sdsArticoli.SelectParameters.Add(New System.Web.UI.WebControls.Parameter("NListino", TypeCode.Int32, nListino.ToString()))
        Me.sdsArticoli.SelectParameters.Add(New System.Web.UI.WebControls.Parameter("pmr", TypeCode.Int32, iMarcheId.ToString()))
        Me.sdsArticoli.SelectParameters.Add(New System.Web.UI.WebControls.Parameter("pst", TypeCode.Int32, iSettoriId.ToString()))
        Me.sdsArticoli.SelectParameters.Add(New System.Web.UI.WebControls.Parameter("pct", TypeCode.Int32, iCategorieId.ToString()))
        Me.sdsArticoli.SelectParameters.Add(New System.Web.UI.WebControls.Parameter("ptp", TypeCode.Int32, iTipologieId.ToString()))
        Me.sdsArticoli.SelectParameters.Add(New System.Web.UI.WebControls.Parameter("pgr", TypeCode.Int32, iGruppiId.ToString()))
        Me.sdsArticoli.SelectParameters.Add(New System.Web.UI.WebControls.Parameter("psg", TypeCode.Int32, iSottogruppiId.ToString()))
        Me.sdsArticoli.SelectParameters.Add(New System.Web.UI.WebControls.Parameter("part", TypeCode.Int32, iArticoliId.ToString()))

    End Sub

    Private Function GetSessionInt(ByVal key As String, ByVal fallbackValue As Integer) As Integer
        Dim parsedValue As Integer
        Dim rawValue As Object = Me.Session(key)

        If rawValue IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(rawValue), parsedValue) Then
            Return parsedValue
        End If

        Return fallbackValue
    End Function

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

        Dim articleId As Integer = 0
        Dim quantity As Decimal = 0D
        If Not Integer.TryParse(ID.Text, articleId) OrElse articleId <= 0 OrElse
           Not Decimal.TryParse(qta.Text, NumberStyles.Number, CultureInfo.GetCultureInfo("it-IT"), quantity) OrElse quantity <= 0D Then Exit Sub
        If ExecutePromotionCartMutation(articleId, quantity) Then
            Response.Redirect(Request.RawUrl, False)
            Context.ApplicationInstance.CompleteRequest()
        End If

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

    Private Function ExecutePromotionCartMutation(ByVal articleId As Integer,
                                                   ByVal quantity As Decimal) As Boolean
        Dim payload As String = CartMutationIdempotencyService.BuildStandardPayload(articleId, -1, quantity)
        Dim slotName As String = "promozioni:single:" & articleId.ToString(CultureInfo.InvariantCulture)
        Dim requestId As String = CartMutationIdempotencyService.GetOrCreateProgressiveRequestId(
            HttpContext.Current, slotName, "promotion-add", payload)
        Dim decision As CartMutationIntentDecision = CartMutationIdempotencyService.RegisterIntent(
            HttpContext.Current, requestId, "promotion-add", payload)
        If decision = CartMutationIntentDecision.Completed Then Return True
        If decision <> CartMutationIntentDecision.Accepted AndAlso decision <> CartMutationIntentDecision.Pending Then Return False

        decision = CartMutationIdempotencyService.BeginIntent(
            HttpContext.Current, requestId, "promotion-add", payload)
        If decision = CartMutationIntentDecision.Completed Then Return True
        If decision <> CartMutationIntentDecision.Accepted Then Return False

        Dim result As CartStandardMutationResult = CartMutationService.AddStandardProductForCurrentOwner(
            HttpContext.Current, articleId, -1, quantity)
        If result Is Nothing OrElse Not result.Succeeded Then
            CartMutationIdempotencyService.AbandonIntent(HttpContext.Current, requestId)
            Return False
        End If

        CartMutationIdempotencyService.CompleteIntent(HttpContext.Current, requestId)
        Return True
    End Function

End Class
