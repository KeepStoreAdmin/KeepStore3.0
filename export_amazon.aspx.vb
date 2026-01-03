Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.IO

Partial Class export_amazon
    Inherits System.Web.UI.Page

    Enum Modes
        SoloPrezzo
        PrezzoESpedizione
        PrezzoESpedizioneEAssicurazione
    End Enum

    Enum DrItemType
        stringType
        intType
    End Enum

    Function getDataReader(ByVal conn As MySqlConnection, ByVal query As String) As MySqlDataReader
        Return getDataReader(conn, query, 0)
    End Function

    Function getDataReader(ByVal conn As MySqlConnection, ByVal query As String, ByVal timeout As Integer) As MySqlDataReader
        Dim cmd As New MySqlCommand
        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        If timeout > 0 Then
            cmd.CommandTimeout = timeout
        End If
        cmd.CommandText = query
        Return cmd.ExecuteReader()
    End Function

    Function getDataTable(ByVal conn As MySqlConnection, ByVal dtAdapter As MySql.Data.MySqlClient.MySqlDataAdapter, ByVal query As String) As DataTable
        Dim cmd As New MySqlCommand
        Dim ds As New DataSet
        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = query
        dtAdapter.SelectCommand = cmd
        dtAdapter.Fill(ds)
        Return ds.Tables(0)
    End Function

    Function calcola_spese_spedizione(ByVal dt As DataTable, ByVal peso As String) As Double
        Dim dr() As DataRow = dt.Select(peso.Replace(",", ".") & " <= PesoMax")
        Return CDbl(dr(0).Item("CostoFisso").ToString.Replace(".", ","))
    End Function

    Function calcola_spese_assicurazione(ByVal dt As DataTable, ByVal totale As Double) As Double
        Dim dr() As DataRow = dt.Select()
        If ((totale / 100) * dr(0).Item("AssicurazionePercentuale")) < dr(0).Item("AssicurazioneMinimo") Then
            Return CDbl(dr(0).Item("AssicurazioneMinimo").ToString.Replace(".", ","))
        Else
            Return CDbl(((totale / 100) * CDbl(dr(0).Item("AssicurazionePercentuale").ToString.Replace(".", ","))))
        End If
    End Function

    Function secondo_prezzo(ByVal conn As MySqlConnection, ByVal idArticolo As Integer, ByVal nListino As Integer, ByVal iva_tipo As Integer) As String
        Dim dr As MySqlDataReader
        Dim result As String = ""
        dr = getDataReader(conn, "SELECT ArticoliId,NListino,Prezzo, PrezzoIvato FROM articoli_listini WHERE (NListino=" & nListino & ") AND (ArticoliId=" & idArticolo & ")")
        dr.Read()

        'Lettura Parametri
        If dr.HasRows Then
            If iva_tipo = 1 Then
                If IsDBNull(dr.Item("Prezzo")) = False Then
                    result = FormatNumber(dr.Item("Prezzo"), 2).Replace(".", "").Replace(",", ".")
                End If
            Else
                If IsDBNull(dr.Item("PrezzoIvato")) = False Then
                    result = (FormatNumber(dr.Item("PrezzoIvato"), 2).Replace(".", "").Replace(",", "."))
                End If
            End If
        End If
        dr.Close()
        Return result
    End Function

    Function verifica_spedizione_gratis(ByVal conn As MySqlConnection, ByVal idArticolo As Integer, ByVal nListino As Integer) As Integer
        Dim dr As MySqlDataReader
        Dim result As Integer = 0
        dr = getDataReader(conn, "SELECT SpedizioneGratis_Listini, SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine, id FROM articoli WHERE (SpedizioneGratis_Listini LIKE CONCAT('%', " & nListino & ", ';%')) AND (id = " & idArticolo & ") AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())")
        dr.Read()

        'Lettura Parametri
        If dr.HasRows Then
            result = 1
        End If
        dr.Close()
        Return result
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        'Formato del response
        Response.ContentType = "application/txt"
        Response.AddHeader("content-disposition", "attachment; filename=amazon.txt")

        Dim connCicloPrincipale = New MySqlConnection()
        connCicloPrincipale.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        connCicloPrincipale.Open()
        Dim dr As MySqlDataReader

        Dim fase As Integer = Request.QueryString("fase")
        If fase = 1 Then
            dr = getDataReader(connCicloPrincipale, "select * from export_amazon") '  where export_amazon.abilitato=1
            dr.Read()
            Dim risposta As String = dr.Item("abilitato").ToString + "|" + dr.Item("nuovo_inserimento").ToString + "|" + dr.Item("aggiornamenti").ToString + "|" + dr.Item("avvio_forzato_aggiornamento").ToString + "|" + dr.Item("avvio_forzato_nuovo_inserimento").ToString
            Response.Write(risposta)
            dr.Close()
            connCicloPrincipale.Close()
            connCicloPrincipale.Dispose()
            Response.End()
        End If

		if fase = 3 Then
			Dim azione As String = Request.QueryString("azione")
			Dim statoEsecuzione As String = Request.QueryString("statoesecuzione")
            Dim sqlString As String = "UPDATE export_amazon SET stato_esecuzione = '" & Now() & ":" & statoesecuzione & "'"
            If azione = "nuovoinserimento" Then
                    sqlString = sqlString & ", avvio_forzato_nuovo_inserimento = 0"
				Else
                    sqlString = sqlString & ", avvio_forzato_aggiornamento = 0"
            End If
            Dim cmd = New MySqlCommand()
            cmd.Connection = connCicloPrincipale
            cmd.CommandType = CommandType.Text
            cmd.CommandText = sqlString
            cmd.ExecuteNonQuery()
            cmd.Dispose()
            connCicloPrincipale.Close()
            connCicloPrincipale.Dispose()
            Response.Write("True")
			Response.End()
        End If

		Dim Dominio As String = ""
        Dim Listino As Integer = 0
        Dim Listino2 As Integer = 0
        Dim IvaTipo As Integer = 0
        Dim idVettore As Integer = 0
        Dim NoVettoreSuGratis As Integer = 0
        Dim calcola_spedizione_reale As Integer = 0
        Dim Giacenza_Impostata As Integer = 0
        Dim SpeseSpedizione As String = ""
        Dim GiorniSpedizione As String = ""

        Dim Ean As String = ""
        Dim Asin As String = ""
        Dim strLine As String = ""
        Dim ArtID As Int64 = 0
        Dim settore As String = ""
        Dim Descrizione1 As String = ""
        Dim Marca As String = ""
        Dim Descrizione2 As String = ""
        Dim DescrizioneLunga As String = ""
        Dim DescrizioneHTML As String = ""
        Dim Codice As String = ""
        Dim Link As String = ""
        Dim Categoria As String = ""
        Dim tipologia As String = ""
        Dim gruppi As String = ""
        Dim peso As String = ""
        Dim Giacenza As String = ""
        Dim IdSettore As String = ""
        Dim IdCategoria As String = ""
        Dim IdTipologia As String = ""
        Dim IdGruppo As String = ""
        Dim IdSottogruppo As String = ""
        Dim Aliquota As String = ""
        Dim UrlImg As String = ""
        Dim UrlImgBig As String = ""
        Dim UrlImg2 As String = ""
        Dim UrlImg2Big As String = ""
        Dim UrlImg3 As String = ""
        Dim UrlImg3Big As String = ""
        Dim UrlImg4 As String = ""
        Dim UrlImg4Big As String = ""
        Dim Gia As Integer = 0
        Dim Ordine As Integer = 0
        Dim Disponibilita As String = ""
        Dim Prezzo As String = ""
        Dim Prezzo2 As String = ""
        Dim note As String = ""
        Dim mode As Modes
        Dim Iva_Vettore As Double = 0

        Dim formatString As String = Request.QueryString("formatString")
		Dim header As String = Request.QueryString("header")
		
        dr = getDataReader(connCicloPrincipale, "select export_amazon.*, vettori.iva, iva.valore from export_amazon left join vettori on export_amazon.idVettore=vettori.id left join iva on vettori.iva=iva.id") '  where export_amazon.abilitato=1
        dr.Read()

        'Lettura Parametri
        'If Not dr.HasRows Then
        'connCicloPrincipale.Close()
        'connCicloPrincipale.Dispose()
        'Response.Write("Non abilitato")
        'Response.End()
        'End If

        'Applicazione Iva Vettore prelevata dalla tabella Vettori, ogni vettori ha la propria iva da applicare
        Iva_Vettore = dr.Item("valore")
        Dominio = dr.Item("Azienda")
        Listino = dr.Item("nlistino")
        Listino2 = dr.Item("nlistino2")
        IvaTipo = dr.Item("ivatipo")
        idVettore = dr.Item("IdVettore")
        NoVettoreSuGratis = dr.Item("NoVettoreSuGratis")
        'Controllo se devo calcolare o meno i costi di spedizione reale
        If formatString.Contains("#CostoSpedizioneProdo#") And (Not IsDBNull(dr.Item("IdVettore"))) Then
            calcola_spedizione_reale = 1
        End If
        Giacenza_Impostata = dr.Item("giacenza")
        If IvaTipo = 1 Then
            'Caso di IVA Esclusa con sostituzione dei caratteri per la stampa
            SpeseSpedizione = FormatNumber(dr.Item("SpeseSpedizione"), 2).Replace(".", "").Replace(",", ".")
        Else
            'Caso di IVA Inclusa con sostituzione dei caratteri per la stampa
            SpeseSpedizione = (FormatNumber(Val(dr.Item("SpeseSpedizione")) * ((Iva_Vettore / 100) + 1), 2).Replace(".", "").Replace(",", "."))
        End If
        GiorniSpedizione = dr.Item("giornispedizione")
        'Decido cosa deve includere il prezzo finale
        Select Case dr.Item("Mode")
            Case 1
                mode = Modes.SoloPrezzo
            Case 2
                mode = Modes.PrezzoESpedizione
            Case Else
                mode = Modes.PrezzoESpedizioneEAssicurazione
        End Select

        note = checkAndCorrectStringDrItem(dr.Item("Note"), False, False)
        dr.Close()

        'If calcola_spedizione_reale = 1 Then
        Dim dtAdapter As New MySql.Data.MySqlClient.MySqlDataAdapter
        Dim dt_peso_e_costo As DataTable = getDataTable(connCicloPrincipale, dtAdapter, "SELECT PesoMax, CostoFisso FROM (vettoricosti) WHERE (VettoriId = " & idVettore & ") ORDER BY PesoMax")
        Dim dt_assicurazione As DataTable = getDataTable(connCicloPrincipale, dtAdapter, "SELECT AssicurazionePercentuale,AssicurazioneMinimo FROM (vettori) WHERE (Id = " & idVettore & ")")
        'dtAdapter = Nothing
        'End If

        'Lettura Articoli
        If Listino > 0 Then

            'Setto il timeout della connessione per evitare problemi, visto che la query dovrà esportare tutti gli articoli presenti in magazzino, anche quelli disabilitati e con giacenza = 0
            dr = getDataReader(connCicloPrincipale, "select * from vsuperarticoli_amazon where abilitato=1 and nlistino=" & Listino & " and (isnull(offerteid) or offerteqntminima = 1 or offertemultipli=1) order by id, settoriid, categorieid, tipologieid, marcheid, codice", 300)
            'Testata
            Response.Write("TemplateType=Offer" & vbTab & "Version=1.4" & vbCrLf)
			Response.Write(header.Replace("|", vbTab) + Environment.NewLine)
            'Response.Write("sku" & vbTab & "price" & vbTab & "quantity" & vbTab & "product-id" & vbTab & "product-id-type" & vbTab & "condition-type" & vbTab & "condition-note" & vbTab & "operation-type" & vbTab & "leadtime-to-ship" & vbCrLf)

            Dim controlla_solo_numerico As Regex = New Regex("^[0-9]{13}$")
            Dim match As Match
            Dim connSecondoPrezzoSpedizioneGratis = New MySqlConnection()
            connSecondoPrezzoSpedizioneGratis.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            connSecondoPrezzoSpedizioneGratis.Open()

            While dr.Read()
                Ean = dr.Item("Ean")
                Asin = dr.Item("Asin")
                match = controlla_solo_numerico.Match(Ean)
                If (match.Success) Then
                    strLine = formatString
                    ArtID = dr.Item("id")
                    settore = dr.Item("SettoriDescrizione")
                    Descrizione1 = checkAndCorrectStringDrItem(dr.Item("descrizione1"), True, True)
                    Marca = dr.Item("MarcheDescrizione").ToString
                    Descrizione2 = checkAndCorrectStringDrItem(dr.Item("descrizione2"), True, True)
                    DescrizioneLunga = checkAndCorrectStringDrItem(dr.Item("descrizionelunga"), False, True)
                    DescrizioneHTML = checkAndCorrectStringDrItem(dr.Item("DescrizioneHTML"), False, True)
                    Codice = checkAndCorrectStringDrItem(dr.Item("codice"), True, True)
                    Link = "http://" & Dominio & "/articolo.aspx?id=" & ArtID
                    Categoria = checkAndCorrectStringDrItem(dr.Item("CategorieDescrizione"), False, False)
                    tipologia = checkAndCorrectStringDrItem(dr.Item("TipologieDescrizione"), False, False)
                    gruppi = checkAndCorrectStringDrItem(dr.Item("GruppiDescrizione"), False, False)
                    peso = checkAndCorrectIntDrItem(dr.Item("peso"))
                    Giacenza = checkAndCorrectIntDrItem(dr.Item("Giacenza"))

                    IdSettore = checkAndCorrectIntDrItem(dr.Item("SettoriId"))
                    IdCategoria = checkAndCorrectIntDrItem(dr.Item("CategorieId"))
                    IdTipologia = checkAndCorrectIntDrItem(dr.Item("TipologieId"))
                    IdGruppo = checkAndCorrectIntDrItem(dr.Item("GruppiId"))
                    IdSottogruppo = checkAndCorrectIntDrItem(dr.Item("SottoGruppiId"))
                    Aliquota = dr.Item("Valoreiva").ToString

                    If dr.Item("Img1") <> "" Then
                        UrlImg = "http://" & Dominio & "/Public/foto/_" & dr.Item("Img1")
                        UrlImgBig = "http://" & Dominio & "/Public/foto/" & dr.Item("Img1")
                    End If
                    If dr.Item("Img2") <> "" Then
                        UrlImg2 = "http://" & Dominio & "/Public/foto/_" & dr.Item("Img2")
                        UrlImg2Big = "http://" & Dominio & "/Public/foto/" & dr.Item("Img2")
                    End If
                    If dr.Item("Img3") <> "" Then
                        UrlImg3 = "http://" & Dominio & "/Public/foto/_" & dr.Item("Img3")
                        UrlImg3Big = "http://" & Dominio & "/Public/foto/" & dr.Item("Img3")
                    End If
                    If dr.Item("Img4") <> "" Then
                        UrlImg4 = "http://" & Dominio & "/Public/foto/_" & dr.Item("Img4")
                        UrlImg4Big = "http://" & Dominio & "/Public/foto/" & dr.Item("Img4")
                    End If

                    If (dr.Item("giacenza").ToString = "") Then
                        Gia = 0
                    Else
                        If Val(dr.Item("giacenza").ToString) < Val(Giacenza_Impostata) Then
                            Gia = 0
                        Else
                            Gia = CInt(dr.Item("giacenza"))
                        End If
                    End If

                    If dr.Item("InOrdine").ToString = "" Then
                        Ordine = 0
                    Else
                        Ordine = CInt(dr.Item("InOrdine"))
                    End If

                    If Gia > 0 Then
                        Disponibilita = "Disponibile"
                    ElseIf Ordine > 0 Then
                        Disponibilita = "In Arrivo"
                    Else
                        Disponibilita = "Non Disponibile"
                    End If

                    If IvaTipo = 1 Then
                        If dr.Item("InOfferta") = 1 Then
                            Prezzo = dr.Item("PrezzoPromo")
                        Else
                            If dr.Item("Prezzo").ToString <> "" Then
                                Prezzo = dr.Item("Prezzo")
                            Else
                                Prezzo = 0
                            End If
                        End If
                    ElseIf IvaTipo = 2 Then
                        If dr.Item("InOfferta") = 1 Then
                            Prezzo = dr.Item("PrezzoPromoIvato")
                        Else
                            If dr.Item("Prezzo").ToString <> "" Then
                                Prezzo = dr.Item("Prezzo") * ((Iva_Vettore / 100) + 1)
                            Else
                                Prezzo = 0
                            End If
                        End If
                    End If

                    Prezzo = FormatNumber(Prezzo, 4).Replace(".", "").Replace(",", ".")
                    'Secondo Prezzo, quello di riferimento
                    Prezzo2 = secondo_prezzo(connSecondoPrezzoSpedizioneGratis, ArtID, Listino2, IvaTipo)

                    If strLine.Contains("#CostoSpedizioneProdo#") Then
                        If verifica_spedizione_gratis(connSecondoPrezzoSpedizioneGratis, ArtID, Listino) = 1 Then
                            strLine = strLine.Replace("#CostoSpedizioneProdo#", 0)
                        End If
                    Else
                        If IvaTipo = 1 Then
                            strLine = strLine.Replace("#CostoSpedizioneProdo#", calcola_spese_spedizione(dt_peso_e_costo, peso))
                        Else
                            strLine = strLine.Replace("#CostoSpedizioneProdo#", calcola_spese_spedizione(dt_peso_e_costo, peso) * ((Iva_Vettore / 100) + 1))
                        End If
                    End If

                    checkAndReplaceStrLine(strLine, "#IdCategoria#", IdCategoria)
                    checkAndReplaceStrLine(strLine, "#IdGruppo#", IdGruppo)
                    checkAndReplaceStrLine(strLine, "#IdSettore#", IdSettore)
                    checkAndReplaceStrLine(strLine, "#IdSottogruppo#", IdSottogruppo)
                    checkAndReplaceStrLine(strLine, "#IdTipologia#", IdTipologia)
                    checkAndReplaceStrLine(strLine, "#Settore#", settore)
                    checkAndReplaceStrLine(strLine, "#Tipologia#", tipologia)
                    checkAndReplaceStrLine(strLine, "#Gruppo#", gruppi)
                    checkAndReplaceStrLine(strLine, "#Giacenza#", Gia)
                    checkAndReplaceStrLine(strLine, "#Descrizione1#", TrasformaTestoXHtml(Descrizione1))
                    checkAndReplaceStrLine(strLine, "#Marca#", Marca)
                    checkAndReplaceStrLine(strLine, "#Descrizione2#", Descrizione2)
                    checkAndReplaceStrLine(strLine, "#Note#", note)
                    checkAndReplaceStrLine(strLine, "#DescrizioneLunga#", TrasformaTestoXHtml(DescrizioneLunga))
                    checkAndReplaceStrLine(strLine, "#DescrizioneHtml#", TrasformaTestoXHtml(DescrizioneHTML))
                    If strLine.Contains("#Prezzo#") Then
                        Dim prezzoFinale As String
                        Select Case mode
                            Case Modes.SoloPrezzo
                                Format_prezzofinale(CDbl(Prezzo.Replace(".", ",")))
                            Case Modes.PrezzoESpedizione
                                If NoVettoreSuGratis = 1 AndAlso verifica_spedizione_gratis(connSecondoPrezzoSpedizioneGratis, ArtID, Listino) = 1 Then
                                    Format_prezzofinale(CDbl(Prezzo.Replace(".", ",")))
                                Else
                                    Dim speseSpedizioneDaAggiungere As Double
                                    If IvaTipo = 1 Then
                                        speseSpedizioneDaAggiungere = CDbl(CDbl(Prezzo.Replace(".", ",")) + calcola_spese_spedizione(dt_peso_e_costo, peso))
                                    Else
                                        speseSpedizioneDaAggiungere = CDbl(CDbl(Prezzo.Replace(".", ",")) + (calcola_spese_spedizione(dt_peso_e_costo, peso) * ((Iva_Vettore / 100) + 1)))
                                    End If
                                    prezzoFinale = Format_prezzofinale(speseSpedizioneDaAggiungere)
                                End If
                            Case Else
                                If NoVettoreSuGratis = 1 AndAlso verifica_spedizione_gratis(connSecondoPrezzoSpedizioneGratis, ArtID, Listino) = 1 Then
                                    prezzoFinale = Format_prezzofinale(CDbl(Prezzo.Replace(".", ",")))
                                Else
                                    Dim speseSpedizioneDaAggiungere As Double
                                    If IvaTipo = 1 Then
                                        speseSpedizioneDaAggiungere = CDbl(CDbl(Prezzo.Replace(".", ",")) + calcola_spese_assicurazione(dt_assicurazione, CDbl(Prezzo.Replace(".", ",")) + CDbl(calcola_spese_spedizione(dt_peso_e_costo, peso))))
                                    Else
                                        speseSpedizioneDaAggiungere = CDbl(CDbl(Prezzo.Replace(".", ",")) + (calcola_spese_assicurazione(dt_assicurazione, CDbl(Prezzo.Replace(".", ",")) + CDbl(calcola_spese_spedizione(dt_peso_e_costo, peso))) * ((Iva_Vettore / 100) + 1)))
                                    End If
                                    prezzoFinale = Format_prezzofinale(speseSpedizioneDaAggiungere)
                                End If
                        End Select
                        strLine = strLine.Replace("#Prezzo#", prezzoFinale)
                    End If

                    'Controllo se il prodotto è Ricondizionato oppure Nuovo, tali valori vanno inseriti nel campo CONDITION
                    checkAndReplaceStrLine(strLine, "#Condizione#", IIf(dr.Item("Ricondizionato") = 1, "REFURBISHED", "NEW"))
                    checkAndReplaceStrLine(strLine, "#Prezzo2#", Prezzo2)
                    checkAndReplaceStrLine(strLine, "#Codice#", Codice)
                    checkAndReplaceStrLine(strLine, "#Link#", Link)
                    checkAndReplaceStrLine(strLine, "#Disponibilita#", Disponibilita)
                    checkAndReplaceStrLine(strLine, "#Categoria#", Categoria)
                    checkAndReplaceStrLine(strLine, "#UrlImg#", UrlImg)
                    checkAndReplaceStrLine(strLine, "#UrlImgBig#", UrlImgBig)
                    checkAndReplaceStrLine(strLine, "#UrlImg2#", UrlImg2)
                    checkAndReplaceStrLine(strLine, "#UrlImg2Big#", UrlImg2Big)
                    checkAndReplaceStrLine(strLine, "#UrlImg3#", UrlImg3)
                    checkAndReplaceStrLine(strLine, "#UrlImg3Big#", UrlImg3Big)
                    checkAndReplaceStrLine(strLine, "#UrlImg4#", UrlImg4)
                    checkAndReplaceStrLine(strLine, "#UrlImg4Big#", UrlImg4Big)
                    checkAndReplaceStrLine(strLine, "#SpeseSpedizione#", SpeseSpedizione)
                    checkAndReplaceStrLine(strLine, "#GiorniSpedizione#", GiorniSpedizione)
                    checkAndReplaceStrLine(strLine, "#Ean#", Ean)

                    'Caso in cui si ha l'ASIN al posto dell'EAN, in questo caso inseriamo l'ASIN 
                    'perchè per gli articoli in multiselezione hanno bisogno di un codice univoco
                    If strLine.Contains("#Ean/Asin#") Then
                        If Asin <> "" Then
                            strLine = strLine.Replace("#Ean/Asin#", Asin & vbTab & "ASIN")
                        Else
                            strLine = strLine.Replace("#Ean/Asin#", Ean & vbTab & "EAN")
                        End If

                        'Resetto EAN e ASIN
                        Ean = ""
                        Asin = ""
                    End If

                    checkAndReplaceStrLine(strLine, "#Peso#", peso)
                    checkAndReplaceStrLine(strLine, "#Tipologia#", tipologia)
                    checkAndReplaceStrLine(strLine, "#GruppiDesrizione#", gruppi)
                    checkAndReplaceStrLine(strLine, "#<br>#", "<br>")
                    checkAndReplaceStrLine(strLine, "#Aliquota#", Aliquota)
                    checkAndReplaceStrLine(strLine, "#CampoVuoto1#", "")
                    checkAndReplaceStrLine(strLine, "#CampoVuoto2#", "")
                    checkAndReplaceStrLine(strLine, "#CampoVuoto3#", "")
                    checkAndReplaceStrLine(strLine, "#id#", ArtID)

                    Response.Write(strLine.Replace("|", vbTab) + Environment.NewLine)
                End If
            End While
            dr.Close()
        End If
        connCicloPrincipale.Close()
        connCicloPrincipale.Dispose()
    End Sub

	Public Function Format_prezzofinale(ByVal prezzoFinale As Double) As String
		prezzoFinale = Math.Round(prezzoFinale,2,MidpointRounding.AwayFromZero)
		return prezzoFinale.ToString().Replace(".", "").Replace(",", ".")
	End Function
	
    Public Function TrasformaTestoXHtml(ByVal str As String) As String
        Try
            str = str.Replace("à", "&agrave;")
            str = str.Replace("Ã", "&agrave;")
            str = str.Replace("è", "&egrave;")
            str = str.Replace("é", "&eacute;")
            str = str.Replace("ì", "&igrave;")
            str = str.Replace("ò", "&ograve;")
            str = str.Replace("ù", "&ugrave;")
            str = str.Replace("Ã¹", "&ugrave;")
            str = str.Replace("À", "&Agrave;")
            str = str.Replace("È", "&Egrave;")
            str = str.Replace("E'", "&Egrave;")
            str = str.Replace("É", "&Eacute;")
            str = str.Replace("Ì", "&Igrave;")
            str = str.Replace("Ò", "&Ograve;")
            str = str.Replace("Ù", "&Ugrave;")
            str = str.Replace("Ó", "&copy;")
            str = str.Replace("Ò", "&reg;")
            str = str.Replace(">", "&gt;")
            str = str.Replace("<", "&lt;")
            str = str.Replace("""", "&quot;")
            str = str.Replace("a'", "&agrave;")
            str = str.Replace("e'", "&egrave;")
            str = str.Replace("i'", "&igrave;")
            str = str.Replace("o'", "&ograve;")
            str = str.Replace("u'", "&ugrave;")
            str = str.Replace("a`", "&agrave;")
            str = str.Replace("e`", "&egrave;")
            str = str.Replace("i`", "&igrave;")
            str = str.Replace("o`", "&ograve;")
            str = str.Replace("u`", "&ugrave;")
            str = str.Replace("a´", "&agrave;")
            str = str.Replace("e´", "&egrave;")
            str = str.Replace("i´", "&igrave;")
            str = str.Replace("o´", "&ograve;")
            str = str.Replace("u´", "&ugrave;")
            str = str.Replace(vbNewLine, "<br>")
            str = str.Replace(Chr(13), "<br>")
            str = str.Replace(vbCrLf, "<br>")
            str = str.Replace(Chr(13) & Chr(10), "<br>")
            str = str.Replace("   ", " ")
            'str = "<p>" & str & "</p>"
        Catch
        End Try
        Return str
    End Function

    Public Function checkAndCorrectIntDrItem(ByVal drItem As Object) As String
        Return checkAndCorrectDrItem(drItem, DrItemType.intType, False, False)
    End Function

    Public Function checkAndCorrectStringDrItem(ByVal drItem As Object, ByVal replacevbCrLf As Boolean, ByVal replacePipe As Boolean) As String
        Return checkAndCorrectDrItem(drItem, DrItemType.stringType, replacevbCrLf, replacePipe)
    End Function

    Public Function checkAndCorrectDrItem(ByVal drItem As Object, ByVal itemType As DrItemType, ByVal replacevbCrLf As Boolean, ByVal replacePipe As Boolean) As String
        Dim result As String
        If Not drItem Is DBNull.Value Then
            result = correctDrItem(drItem, itemType, replacevbCrLf, replacePipe)
        Else
            Select Case itemType
                Case DrItemType.stringType
                    result = ""
                Case Else
                    result = "0"
            End Select
        End If
        Return result
    End Function

    Public Function correctIntDrItem(ByVal drItem As Object) As String
        Return correctDrItem(drItem, DrItemType.intType, False, False)
    End Function

    Public Function correctStringDrItem(ByVal drItem As Object, ByVal replacevbCrLf As Boolean, ByVal replacePipe As Boolean) As String
        Return correctDrItem(drItem, DrItemType.stringType, replacevbCrLf, replacePipe)
    End Function

    Public Function correctDrItem(ByVal drItem As Object, ByVal itemType As DrItemType, ByVal replacevbCrLf As Boolean, ByVal replacePipe As Boolean) As String
        Dim result As String = drItem
        If itemType = DrItemType.stringType Then
            If replacevbCrLf Then
                result = Left(result, 255).Trim.Replace(vbCrLf, "").Replace("|", "/")
            End If
            If replacePipe Then
                result = result.Trim.Replace("|", "/")
            End If
        Else
            result = result.Replace(",", ".")
        End If
        Return result
    End Function

    Public Sub checkAndReplaceStrLine(ByRef strLine As String, ByVal field As String, ByVal value As String)
        If strLine.Contains(field) Then
            strLine = strLine.Replace(field, value)
        End If
    End Sub
End Class
