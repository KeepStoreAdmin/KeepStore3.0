
Partial Class carrello_groupon
    Inherits System.Web.UI.Page


' =========================
' SAFE HELPERS (redirect/session parsing)
' =========================
Private Sub SafeRedirect(ByVal url As String)
    Try
        Response.Redirect(url, False)
        Context.ApplicationInstance.CompleteRequest()
    Catch
    End Try
End Sub

Private Function GetSessionInt(ByVal key As String, Optional ByVal def As Integer = 0) As Integer
    Try
        Dim o As Object = Session(key)
        If o Is Nothing OrElse o Is DBNull.Value Then Return def
        Dim v As Integer
        If Integer.TryParse(o.ToString(), v) Then Return v
    Catch
    End Try
    Return def
End Function

Private Function GetSessionDbl(ByVal key As String, Optional ByVal def As Double = 0) As Double
    Try
        Dim o As Object = Session(key)
        If o Is Nothing OrElse o Is DBNull.Value Then Return def
        Dim v As Double
        If Double.TryParse(o.ToString(), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, v) Then Return v
        If Double.TryParse(o.ToString(), v) Then Return v
    Catch
    End Try
    Return def
End Function

Private Function GetSessionStr(ByVal key As String, Optional ByVal def As String = "") As String
    Try
        Dim o As Object = Session(key)
        If o Is Nothing OrElse o Is DBNull.Value Then Return def
        Return o.ToString()
    Catch
        Return def
    End Try
End Function


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
        Dim abilita As Integer = GetSessionInt("Abilita_Groupon", 0)
        Dim utentiId As Integer = GetSessionInt("UtentiId", -1)
        If (abilita = 0) OrElse (utentiId <= 0) Then
            SafeRedirect("accessonegato.aspx")
            Exit Sub
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
    Dim temp As ImageButton = TryCast(sender, ImageButton)
    If temp Is Nothing Then Exit Sub

    Try
        ' aggiorna dati coupon (sqlDataSource)
        SqlData_Buoni.Update()
    Catch
        ' non blocco: il binding potrebbe già essere valido
    End Try

    Dim codice As String = ""
    If TB_CodiceSconto IsNot Nothing Then codice = TB_CodiceSconto.Text.Trim()
    If String.IsNullOrEmpty(codice) Then
        ' niente codice: non proseguo
        Exit Sub
    End If

    Session("Groupon_idArticolo") = Convert.ToString(temp.Attributes("idArticolo"))
    Session("Groupon_DescrizioneArticolo") = Convert.ToString(temp.Attributes("DescrizioneArticolo"))

    Dim prezzo As Double = 0
    Double.TryParse(Convert.ToString(temp.Attributes("Prezzo")), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, prezzo)
    If prezzo = 0 Then Double.TryParse(Convert.ToString(temp.Attributes("Prezzo")), prezzo)
    Session("Groupon_Prezzo") = prezzo

    Session("Groupon_codArticolo") = Convert.ToString(temp.Attributes("codArticolo"))

    Dim speseSped As Double = 0
    Double.TryParse(Convert.ToString(temp.Attributes("SpeseSpedizione")), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, speseSped)
    If speseSped = 0 Then Double.TryParse(Convert.ToString(temp.Attributes("SpeseSpedizione")), speseSped)
    Session("Groupon_SpeseSpedizione") = speseSped

    Session("Groupon_Codice") = codice

    Dim ivaArt As Double = 0
    Double.TryParse(Convert.ToString(temp.Attributes("IvaArticolo")), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, ivaArt)
    If ivaArt = 0 Then Double.TryParse(Convert.ToString(temp.Attributes("IvaArticolo")), ivaArt)

    Dim ivaVett As Double = GetSessionDbl("Iva_Vettori", 0)

    Dim calcoloIva As Double = (prezzo * ((ivaArt / 100.0R) + 1.0R)) + (speseSped * ((ivaVett / 100.0R) + 1.0R))
    Session("Calcolo_Iva") = calcoloIva

    SafeRedirect("aggiungi.aspx?id=groupon")
End Sub
End Class
