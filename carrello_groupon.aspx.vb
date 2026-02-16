
Partial Class carrello_groupon
    Inherits System.Web.UI.Page

    ''' <summary>
    ''' Helper di binding: calcola e formatta il prezzo fisso IVA inclusa.
    ''' Manteniamo la logica qui (code-behind) per evitare script/runat nel markup.
    ''' </summary>
    Public Function PrezzoFissoConIva(ByVal prezzoFissoObj As Object, ByVal ivaObj As Object) As String
        Dim prezzoFisso As Double = 0
        Dim iva As Double = 0

        Try
            If prezzoFissoObj IsNot Nothing AndAlso Not Convert.IsDBNull(prezzoFissoObj) Then
                prezzoFisso = Convert.ToDouble(prezzoFissoObj)
            End If
        Catch
        End Try

        Try
            If ivaObj IsNot Nothing AndAlso Not Convert.IsDBNull(ivaObj) Then
                iva = Convert.ToDouble(ivaObj)
            End If
        Catch
        End Try

        Dim totale As Double = prezzoFisso * ((iva / 100.0R) + 1.0R)
        Return String.Format(System.Globalization.CultureInfo.CurrentCulture, "{0:C}", totale)
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        'Controllo se l'Azienda è abilitata per Groupon
        If ((Me.Session("Abilita_Groupon") = 0) Or (Me.Session("UtentiId") = -1)) Then
            Response.Redirect("accessonegato.aspx")
        End If

        'SqlData_Buoni.SelectCommand = "SELECT buoni_acquisto.idBuono, buoni_acquisto.idArticolo, buoni_acquisto.imgBuono, buoni_acquisto.listini_abilitati, buoni_acquisto.prezzo_fisso, buoni_acquisto.sconto, buoni_acquisto.spese_spedizione, buoni_acquisto.valido_da, buoni_acquisto.valido_a, articoli.Codice, articoli.Peso, articoli.Img1, articoli.Abilitato, codici_buono.idCodiceBuono, codici_buono.codice_buono, codici_buono.associazione_groupon, articoli.Descrizione1, articoli.codice, articoli.iva, buoni_acquisto.idAzienda FROM buoni_acquisto INNER JOIN articoli ON buoni_acquisto.idArticolo = articoli.id INNER JOIN codici_buono ON buoni_acquisto.idArticolo = codici_buono.idArticolo WHERE (codici_buono.associazione_groupon = @Codice_Sconto) AND (buoni_acquisto.listini_abilitati LIKE CONCAT('%', " & Session("ListinoUser") & ", ';%')) AND (buoni_acquisto.valido_da <= CURDATE()) AND (buoni_acquisto.valido_a >= CURDATE()) AND (buoni_acquisto.idAzienda = " & Session("AziendaId") & ")"
    End Sub

    Protected Sub Page_PreRenderComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRenderComplete
        'Controllo se il codice inserito è giusto e quindi visualizzato all'utente
        If (FormView_Articolo.DataItemCount > 0) Then
            TB_CodiceSconto.Enabled = False
            imgOK.Visible = True
            imgNO.Visible = False
        Else
            If Page.IsPostBack Then
                imgNO.Visible = True
                imgOK.Visible = False
            Else
                imgNO.Visible = False
                imgOK.Visible = False
            End If
        End If
    End Sub

    Protected Sub IB_Conferma_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)
        Dim temp As ImageButton = sender

        SqlData_Buoni.Update()

        Session("Groupon_idArticolo") = temp.Attributes("idArticolo")
        Session("Groupon_DescrizioneArticolo") = temp.Attributes("DescrizioneArticolo")
        Session("Groupon_Prezzo") = CDbl(temp.Attributes("Prezzo"))
        Session("Groupon_codArticolo") = temp.Attributes("codArticolo")
        Session("Groupon_SpeseSpedizione") = CDbl(temp.Attributes("SpeseSpedizione"))
        Session("Groupon_Codice") = TB_CodiceSconto.Text

        Me.Session("Calcolo_Iva") = (Session("Groupon_Prezzo") * ((CDbl(temp.Attributes("IvaArticolo")) / 100) + 1)) + (Session("Groupon_SpeseSpedizione") * ((Session("Iva_Vettori") / 100) + 1))

        Response.Redirect("aggiungi.aspx?id=groupon")
    End Sub
End Class
