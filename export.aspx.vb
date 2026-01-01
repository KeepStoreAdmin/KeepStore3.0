Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.IO

Partial Class export
    Inherits System.Web.UI.Page

    Dim dtAdapter As New MySql.Data.MySqlClient.MySqlDataAdapter
    Dim ds As New DataSet
    Dim dt As DataTable
    'Visto che i comparatori fanno accesso alla pagina export.aspx direttamente senza passare per
    'altre pagine devo leggermi dall'Azienda il valore di ivaVettore
    Dim Iva_Vettore As Double = 0

    Function calcola_spese_spedizione(ByVal peso As String) As String
        Dim dr() As DataRow = dt.Select(peso.Replace(",", ".") & " <= PesoMax")

        If Request.QueryString("google") = 1 Then
            Return "IT::Standard:" & dr(0).Item("CostoFisso").ToString.Replace(",", ".")
        Else
            Return dr(0).Item("CostoFisso")
        End If

    End Function

    Function secondo_prezzo(ByVal idArticolo As Integer, ByVal nListino As Integer, ByVal iva_tipo As Integer) As String
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT ArticoliId,NListino,Prezzo, PrezzoIvato FROM articoli_listini WHERE (NListino=" & nListino & ") AND (ArticoliId=" & idArticolo & ")"

        dr = cmd.ExecuteReader()
        dr.Read()

        'Lettura Parametri
        If dr.HasRows Then
            Dim prezzo As Double

            If iva_tipo = 1 Then
                If IsDBNull(dr.Item("Prezzo")) = False Then
                    prezzo = dr.Item("Prezzo")
                    conn.Close()
                    dr.Close()
                    Return FormatNumber(prezzo, 2).Replace(".", "").Replace(",", ".")
                End If

            Else
                If IsDBNull(dr.Item("PrezzoIvato")) = False Then
                    prezzo = dr.Item("PrezzoIvato")
                    conn.Close()
                    dr.Close()
                    Return FormatNumber(prezzo, 2).Replace(".", "").Replace(",", ".")
                End If
            End If

            Return ""
        Else
                conn.Close()
                dr.Close()
                Return ""
        End If
    End Function

    Function converti_in_minuscolo(ByVal testo As String) As String
        testo = LCase(testo)
        Return (UCase(testo.Substring(0, 1)) & (testo.Substring(1, testo.Length - 1)))
    End Function

    Function verifica_spedizione_gratis(ByVal idArticolo As Integer, ByVal nListino As Integer) As Integer
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT SpedizioneGratis_Listini, SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine, id FROM articoli WHERE (SpedizioneGratis_Listini LIKE CONCAT('%', " & nListino & ", ';%')) AND (id = " & idArticolo & ") AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())"

        dr = cmd.ExecuteReader()
        dr.Read()

        'Lettura Parametri
        If dr.HasRows Then
            conn.Close()
            dr.Close()
            Return 1
        Else
            conn.Close()
            dr.Close()
            Return 0
        End If
    End Function


    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        'Formato del response
        Response.ContentType = "application/txt"
        Response.AddHeader("content-disposition", "attachment; filename=export.txt")

        Dim Dominio As String = ""
        Dim ID As Integer = CInt(Me.Request.QueryString("id"))
        Dim Password As String = CStr(Me.Request.QueryString("pwd"))
        Dim comparatore As String = CStr(Me.Request.QueryString("comparatore"))

        Dim Path As String = "Public/Export/"
        Dim Nome As String = ""
        Dim Listino As Integer = 0
        Dim Listino2 As Integer = 0
        Dim IvaTipo As Integer = 0
        Dim FormatString As String = ""
        Dim Giacenza As Integer = 0
        Dim strGiacenza As String = ""
        Dim SpeseSpedizione As String = ""
        Dim GiorniSpedizione As String = ""
        Dim ArtID As Int64 = 0
        Dim Descrizione1 As String = ""
        Dim Marca As String = ""
        Dim Descrizione2 As String = ""
        Dim DescrizioneLunga As String = ""
        Dim DescrizioneHTML As String = ""
        Dim Prezzo As String = ""
        Dim Prezzo2 As String = ""
        Dim Codice As String = ""
        Dim Link As String
        Dim IdCategoria As Integer = 0
        Dim IdGruppo As Integer = 0
        Dim IdSettore As Integer = 0
        Dim IdSottogruppo As Integer = 0
        Dim IdTipologia As Integer = 0
        Dim Disponibilita As String = "Vedere sito"
        Dim Categoria As String = ""
        Dim UrlImg As String = ""
        Dim UrlImgBig As String = ""
        Dim UrlImg2 As String = ""
        Dim UrlImg2Big As String = ""
        Dim UrlImg3 As String = ""
        Dim UrlImg3Big As String = ""
        Dim UrlImg4 As String = ""
        Dim UrlImg4Big As String = ""
        Dim Ean As String = ""
        Dim strLine As String = ""
        Dim settore As String = String.Empty
        Dim peso As String = ""
        Dim tipologia As String = String.Empty
        Dim gruppi As String = String.Empty
        Dim Aliquota As Double = 0
        Dim CVuoto1 As String = String.Empty
        Dim CVuoto2 As String = String.Empty
        Dim CVuoto3 As String = String.Empty
        Dim idVettore As Integer = 0
        Dim tutto_in_minuscolo As Integer = 0
        Dim Mesi_Garanzia As String = ""
        Dim Descrizione_Garanzia As String = ""

        Dim Gia As Integer = 0
        Dim Ordine As Integer = 0
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader

        Dim calcola_spedizione_reale As Integer = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "select export.*, vettori.iva, iva.valore from export left join vettori on export.idVettore=vettori.id left join iva on vettori.iva=iva.id where (export.id='" & ID & "' and export.password='" & Password & "') limit 0, 1"

        dr = cmd.ExecuteReader()
        dr.Read()

        'Lettura Parametri
        If Not dr.HasRows Then
            Response.Write("ID o Password errati.")
            Response.End()
        Else
            'Applicazione Iva Vettore prelevata dalla tabella Vettori, ogni vettori ha la propria iva da applicare
            If (Not IsDBNull(dr.Item("Valore"))) Then
                Iva_Vettore = dr.Item("Valore")
            End If

            Nome = dr.Item("descrizione").ToString.Replace(" ", "")
            Dominio = dr.Item("Azienda")
            Listino = dr.Item("nlistino")
            Listino2 = dr.Item("nlistino2")
            IvaTipo = dr.Item("ivatipo")
            FormatString = dr.Item("formatstring")
            tutto_in_minuscolo = dr.Item("Tutto_in_minuscolo")

            'Controllo se devo calcolare o meno i costi di spedizione reale
            If FormatString.Contains("#CostoSpedizioneProdo#") AndAlso (Not IsDBNull(dr.Item("IdVettore"))) Then
                calcola_spedizione_reale = 1
                idVettore = dr.Item("IdVettore")
            End If

            Giacenza = dr.Item("giacenza")

            If IvaTipo = 1 Then
                'Caso di IVA Esclusa con sostituzione dei caratteri per la stampa
                SpeseSpedizione = FormatNumber(dr.Item("SpeseSpedizione"), 2).Replace(".", "").Replace(",", ".")
            Else
                'Caso di IVA Inclusa con sostituzione dei caratteri per la stampa
                SpeseSpedizione = (FormatNumber(Val(dr.Item("SpeseSpedizione")) * ((Iva_Vettore / 100) + 1), 2).Replace(".", "").Replace(",", "."))
            End If

            GiorniSpedizione = dr.Item("giornispedizione")
            End If

            dr.Close()

            If calcola_spedizione_reale = 1 Then
                cmd.CommandText = "SELECT PesoMax, CostoFisso FROM (vettoricosti) WHERE (VettoriId = " & idVettore & ")ORDER BY PesoMax"

                dtAdapter.SelectCommand = cmd
                dtAdapter.Fill(ds)
                dt = ds.Tables(0)

                dtAdapter = Nothing
            End If

            'Lettura Articoli
            If Listino > 0 Then

                Path = Path & Nome & ".txt"

                If Giacenza >= 0 Then
                    strGiacenza = " and Giacenza >= " & Giacenza
                End If

                'cmd.CommandText = "select * from varticolilistini where export=1 and nlistino=" & Listino & strGiacenza & " order by settoriid, categorieid, tipologieid, marcheid, codice"

                '-----------------------------------------------------------------------------------------------------
                '-----------------------------------------------------------------------------------------------------
                'Filtro Esportazione
                Dim conn2 As New MySqlConnection
                Dim cmd2 As New MySqlCommand
                Dim dr2 As MySqlDataReader

                conn2.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                conn2.Open()

                cmd2.Connection = conn
                cmd2.CommandType = CommandType.Text
                cmd2.CommandText = "select * from export_filtri where ExportId=" & ID

                dr2 = cmd2.ExecuteReader()
                dr2.Read()

                'Lettura Parametri
                If dr2.HasRows Then
                    cmd.CommandText = "select * from vsuperarticoli where export=1 and nlistino=" & Listino & strGiacenza & " and (isnull(offerteid) or offerteqntminima = 1 or offertemultipli=1) and ( (" & IIf(dr2.Item("MarcheId") > 0, "(marcheid=" & dr2.Item("MarcheId") & ")", "(1=1)") & " and " & IIf(dr2.Item("SettoriId") > -1, "(settoriid=" & dr2.Item("SettoriId") & ")", "(1=1)") & " and " & IIf(dr2.Item("CategorieId") > -1, "(categorieid=" & dr2.Item("CategorieId") & ")", "(1=1)") & " and " & IIf(dr2.Item("TipologieId") > -1, "(tipologieid=" & dr2.Item("TipologieId") & ")", "(1=1)") & " and " & IIf(dr2.Item("GruppiId") > -1, "(gruppiid=" & dr2.Item("GruppiId") & ")", "(1=1)") & " and " & IIf(dr2.Item("SottogruppiId") > -1, "(sottogruppiid=" & dr2.Item("SottogruppiId") & ")", "(1=1)") & " ) "
                    While dr2.Read()
                        cmd.CommandText = cmd.CommandText & " or ((" & IIf(dr2.Item("MarcheId") > 0, "(marcheid=" & dr2.Item("MarcheId") & ")", "(1=1)") & " and " & IIf(dr2.Item("SettoriId") > -1, "(settoriid=" & dr2.Item("SettoriId") & ")", "(1=1)") & " and " & IIf(dr2.Item("CategorieId") > -1, "(categorieid=" & dr2.Item("CategorieId") & ")", "(1=1)") & " and " & IIf(dr2.Item("TipologieId") > -1, "(tipologieid=" & dr2.Item("TipologieId") & ")", "(1=1)") & " and " & IIf(dr2.Item("GruppiId") > -1, "(gruppiid=" & dr2.Item("GruppiId") & ")", "(1=1)") & " and " & IIf(dr2.Item("SottogruppiId") > -1, "(sottogruppiid=" & dr2.Item("SottogruppiId") & ")", "(1=1)") & " ) AND (" & IIf(dr2.Item("ArticoliId") > -1, "id=" & dr2.Item("ArticoliId"), "1=1") & "))"
                    End While
                    cmd.CommandText = cmd.CommandText & ") order by settoriid, categorieid, tipologieid, marcheid, codice"
                Else
                    cmd.CommandText = "select * from vsuperarticoli where export=1 and nlistino=" & Listino & strGiacenza & " and (isnull(offerteid) or offerteqntminima = 1 or offertemultipli=1) order by settoriid, categorieid, tipologieid, marcheid, codice"
                End If
                conn2.Close()
                cmd2.Dispose()
                dr2.Close()
                '-----------------------------------------------------------------------------------------------------
                '-----------------------------------------------------------------------------------------------------

                dr = cmd.ExecuteReader()

                If Request.QueryString("google") = 1 Then
                    Response.Write("id" + vbTab + "titolo" + vbTab + "descrizione" + vbTab + "categoria" + vbTab + "link" + vbTab + "link immagine" + vbTab + "condizione" + vbTab + "disponibilità" + vbTab + "prezzo" + vbTab + "ean" + vbTab + "marca" + vbTab + "spedizione" + Environment.NewLine)
                Else
                    'Testata
                    Response.Write(FormatString.Replace("#", "").Replace("Descrizione1", "Titolo") & Environment.NewLine)
                End If

                While dr.Read()
                strLine = FormatString
                ArtID = dr.Item("id")
                If ArtID = 15143 Then
                    Dim a As Integer = 1
                End If
                settore = dr.Item("SettoriDescrizione")
                Descrizione1 = Left(dr.Item("descrizione1"), 255).Trim.Replace(vbCrLf, "").Replace("|", "/")
                Marca = dr.Item("MarcheDescrizione").ToString
                Descrizione2 = String.Empty
                If Not dr.Item("descrizione2") Is DBNull.Value Then Descrizione2 = Left(dr.Item("descrizione2"), 255).Trim.Replace(vbCrLf, "").Replace("|", "/")
                DescrizioneLunga = dr.Item("descrizionelunga").Trim.Replace("|", "/")
                If IsDBNull(dr.Item("DescrizioneHTML")) = False Then
                    DescrizioneHTML = dr.Item("DescrizioneHTML").Trim.Replace("|", "/")
                End If
                'Codice = ArtID
                'comparatore = dr.Item("comparatore")
                Codice = Left(dr.Item("codice"), 255).Trim.Replace(vbCrLf, "").Replace("|", "/")
                Link = "http://" & Dominio & "/articolo.aspx?id=" & ArtID & "&comparatore=" & comparatore
                Ean = dr.Item("Ean")
                Categoria = IIf(dr.Item("CategorieDescrizione") Is System.DBNull.Value, "", dr.Item("CategorieDescrizione"))
                tipologia = IIf(dr("TipologieDescrizione") Is System.DBNull.Value, "", dr("TipologieDescrizione"))
                gruppi = IIf(dr("GruppiDescrizione") Is DBNull.Value, "", dr("GruppiDescrizione"))
                peso = IIf(dr("Peso") Is DBNull.Value, 0, dr("peso").ToString.Replace(",", "."))
                Giacenza = IIf(dr("Giacenza") Is DBNull.Value, 0, dr("Giacenza").ToString.Replace(",", "."))
                Mesi_Garanzia = dr.Item("Mesi")
                Descrizione_Garanzia = IIf(dr.Item("Garanzia") Is DBNull.Value, "", dr.Item("Garanzia"))

                    'ID Settori - Categorie etc ......
                    IdSettore = IIf(dr("SettoriId") Is DBNull.Value, 0, dr("SettoriId"))
                    IdCategoria = IIf(dr("CategorieId") Is DBNull.Value, 0, dr("CategorieId"))
                    IdTipologia = IIf(dr("TipologieId") Is DBNull.Value, 0, dr("TipologieId"))
                    IdGruppo = IIf(dr("GruppiId") Is DBNull.Value, 0, dr("GruppiId"))
                    IdSottogruppo = IIf(dr("SottoGruppiId") Is DBNull.Value, 0, dr("SottoGruppiId"))

                    Aliquota = dr.Item("iva")
                    CVuoto1 = ""
                    CVuoto2 = ""
                    CVuoto3 = ""

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

                    If dr.Item("giacenza").ToString = "" Then
                        Gia = 0
                    Else
                        Gia = CInt(dr.Item("giacenza"))
                    End If

                    If dr.Item("InOrdine").ToString = "" Then
                        Ordine = 0
                    Else
                        Ordine = CInt(dr.Item("InOrdine"))
                    End If

                    If Gia > 0 Then
                        Disponibilita = "Disponibile"
                    ElseIf Ordine > 0 Then
                        If Request.QueryString("google") = 1 Then
                            Disponibilita = "Non Disponibile"
                        Else
                            Disponibilita = "In Arrivo"
                        End If
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
                            If dr.Item("PrezzoIvato").ToString <> "" Then
                                Prezzo = dr.Item("PrezzoIvato")
                            Else
                                Prezzo = 0
                            End If
                        End If
                    End If

                    Prezzo = FormatNumber(Prezzo, 2).Replace(".", "").Replace(",", ".")
                    'Secondo Prezzo, quello di riferimento
                    Prezzo2 = secondo_prezzo(ArtID, Listino2, IvaTipo)

                    If strLine.Contains("#CostoSpedizioneProdo#") Then
                        If verifica_spedizione_gratis(ArtID, Listino) = 1 Then
                            If Request.QueryString("google") = 1 Then
                                strLine = strLine.Replace("#CostoSpedizioneProdo#", "IT::Standard:0")
                            Else
                                strLine = strLine.Replace("#CostoSpedizioneProdo#", 0)
                            End If
                        Else
                            If IvaTipo = 1 Then
                                strLine = strLine.Replace("#CostoSpedizioneProdo#", calcola_spese_spedizione(peso))
                            Else
                                If Request.QueryString("google") = 1 Then
                                    strLine = strLine.Replace("#CostoSpedizioneProdo#", calcola_spese_spedizione(peso))
                                Else
                                    strLine = strLine.Replace("#CostoSpedizioneProdo#", calcola_spese_spedizione(peso) * ((Iva_Vettore / 100) + 1))
                                End If
                            End If
                        End If
                    End If

                    If strLine.Contains("#IdCategoria#") Then
                        strLine = strLine.Replace("#IdCategoria#", IdCategoria)
                    End If

                    If strLine.Contains("#IdGruppo#") Then
                        strLine = strLine.Replace("#IdGruppo#", IdGruppo)
                    End If

                    If strLine.Contains("#IdSettore#") Then
                        strLine = strLine.Replace("#IdSettore#", IdSettore)
                    End If

                    If strLine.Contains("#IdSottogruppo#") Then
                        strLine = strLine.Replace("#IdSottogruppo#", IdSottogruppo)
                    End If

                    If strLine.Contains("#IdTipologia#") Then
                        strLine = strLine.Replace("#IdTipologia#", IdTipologia)
                    End If

                    If strLine.Contains("#Settore#") Then
                        strLine = strLine.Replace("#Settore#", settore)
                    End If

                    If strLine.Contains("#Tipologia#") Then
                        strLine = strLine.Replace("#Tipologia#", tipologia)
                    End If

                    If strLine.Contains("#Gruppo#") Then
                        strLine = strLine.Replace("#Gruppo#", gruppi)
                    End If

                    If strLine.Contains("#Giacenza#") Then
                        strLine = strLine.Replace("#Giacenza#", Giacenza)
                    End If

                    If strLine.Contains("#Mesi_Garanzia#") Then
                        strLine = strLine.Replace("#Mesi_Garanzia#", """" & Mesi_Garanzia & """")
                    End If

                    If strLine.Contains("#Descrizione_Garanzia#") Then
                        strLine = strLine.Replace("#Descrizione_Garanzia#", """" & Descrizione_Garanzia & """")
                    End If

                    If strLine.Contains("#Descrizione1#") Then
                        If tutto_in_minuscolo = 1 Then
                            strLine = strLine.Replace("#Descrizione1#", TrasformaTestoXHtml(converti_in_minuscolo(Descrizione1)))
                        Else
                            strLine = strLine.Replace("#Descrizione1#", TrasformaTestoXHtml(Descrizione1))
                        End If
                    End If

                    If strLine.Contains("#Marca#") Then
                        strLine = strLine.Replace("#Marca#", Marca)
                    End If

                    If strLine.Contains("#Descrizione2#") Then
                        strLine = strLine.Replace("#Descrizione2#", Descrizione2)
                    End If

                    If strLine.Contains("#DescrizioneLunga#") Then
                        If Request.QueryString("google") = 1 Then
                            strLine = strLine.Replace("#DescrizioneLunga#", Left(TrasformaTestoXHtml(DescrizioneLunga.Replace(vbCrLf, "").Replace(";", ".")), 100))
                        Else
                            strLine = strLine.Replace("#DescrizioneLunga#", TrasformaTestoXHtml(DescrizioneLunga))
                        End If
                    End If

                    If strLine.Contains("#DescrizioneHtml#") Then
                        strLine = strLine.Replace("#DescrizioneHtml#", TrasformaTestoXHtml(DescrizioneHTML))
                    End If

                    If strLine.Contains("#Prezzo#") Then
                        strLine = strLine.Replace("#Prezzo#", Prezzo)
                    End If

                    If strLine.Contains("#Prezzo2#") Then
                        strLine = strLine.Replace("#Prezzo2#", Prezzo2)
                    End If

                    If strLine.Contains("#Condizione#") Then
                        strLine = strLine.Replace("#Condizione#", IIf(dr.Item("Ricondizionato") = 1, "RICONDIZIONATO", "NUOVO"))
                    End If

                    If strLine.Contains("#Codice#") Then
                        strLine = strLine.Replace("#Codice#", Codice)
                    End If

                    If strLine.Contains("#Link#") Then
                        strLine = strLine.Replace("#Link#", Link)
                    End If

                    If strLine.Contains("#Disponibilita#") Then
                        strLine = strLine.Replace("#Disponibilita#", Disponibilita)
                    End If

                    If strLine.Contains("#Categoria#") Then
                        strLine = strLine.Replace("#Categoria#", Categoria)
                    End If

                    If strLine.Contains("#UrlImg#") Then
                        strLine = strLine.Replace("#UrlImg#", UrlImg)
                    End If

                    If strLine.Contains("#UrlImgBig#") Then
                        strLine = strLine.Replace("#UrlImgBig#", UrlImgBig)
                    End If

                    If strLine.Contains("#UrlImg2#") Then
                        strLine = strLine.Replace("#UrlImg2#", UrlImg2)
                    End If

                    If strLine.Contains("#UrlImg2Big#") Then
                        strLine = strLine.Replace("#UrlImg2Big#", UrlImg2Big)
                    End If

                    If strLine.Contains("#UrlImg3#") Then
                        strLine = strLine.Replace("#UrlImg3#", UrlImg3)
                    End If

                    If strLine.Contains("#UrlImg3Big#") Then
                        strLine = strLine.Replace("#UrlImg3Big#", UrlImg3Big)
                    End If

                    If strLine.Contains("#UrlImg4#") Then
                        strLine = strLine.Replace("#UrlImg4#", UrlImg4)
                    End If

                    If strLine.Contains("#UrlImg4Big#") Then
                        strLine = strLine.Replace("#UrlImg4Big#", UrlImg4Big)
                    End If

                    If strLine.Contains("#SpeseSpedizione#") Then
                        strLine = strLine.Replace("#SpeseSpedizione#", SpeseSpedizione)
                    End If

                    If strLine.Contains("#GiorniSpedizione#") Then
                        strLine = strLine.Replace("#GiorniSpedizione#", GiorniSpedizione)
                    End If

                    If strLine.Contains("#Ean#") Then
                        strLine = strLine.Replace("#Ean#", Ean)
                    End If

                    If strLine.Contains("#Peso#") Then
                        strLine = strLine.Replace("#Peso#", peso)
                    End If

                    If strLine.Contains("#Tipologia#") Then
                        strLine = strLine.Replace("#Tipologia#", tipologia)
                    End If

                    If strLine.Contains("#GruppiDesrizione#") Then
                        strLine = strLine.Replace("#GruppiDesrizione#", gruppi)
                    End If

                    If strLine.Contains("#<br>#") Then
                        strLine = strLine.Replace("#<br>#", "<br>")
                    End If

                    If strLine.Contains("#Aliquota#") Then
                        strLine = strLine.Replace("#Aliquota#", Aliquota)
                    End If
                    If strLine.Contains("#CampoVuoto1#") Then
                        strLine = strLine.Replace("#CampoVuoto1#", CVuoto1)
                    End If
                    If strLine.Contains("#CampoVuoto2#") Then
                        strLine = strLine.Replace("#CampoVuoto2#", CVuoto1)
                    End If
                    If strLine.Contains("#CampoVuoto3#") Then
                        strLine = strLine.Replace("#CampoVuoto3#", CVuoto1)
                    End If
                    If strLine.Contains("#id#") Then
                        strLine = strLine.Replace("#id#", ArtID)
                    End If

                    'Vedo se il separatore deve essere il TAB o il PIPE
                    If Request.QueryString("google") = 1 Then
                        Response.Write(strLine.Replace("|", vbTab) + Environment.NewLine)
						Response.End()

                    Else
                        Response.Write(strLine + Environment.NewLine)
						Response.End()

                    End If
                End While

                dr.Close()
            End If

            dr.Dispose()

            cmd.Dispose()

            conn.Close()
            conn.Dispose()
            'Response.Redirect(Path)
            'Response.Write("<script language=vbscript>window.open """ & Path & """</script>")

    End Sub

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
End Class
