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
        'Peso oltre l'ultima fascia del vettore: nessuna tariffa inventata, il campo resta vuoto (il feed non si interrompe).
        If dr.Length = 0 Then Return ""

        If Request.QueryString("google") = 1 Then
            Return "IT::Standard:" & dr(0).Item("CostoFisso").ToString.Replace(",", ".")
        Else
            Return dr(0).Item("CostoFisso")
        End If

    End Function

    'UNA connessione ausiliaria per richiesta (EXPORT-FEED-REPAIR-1A): aperta al primo uso, fuori dal lettore principale (MySQL non ammette due comandi su una
    'connessione con un lettore aperto) e chiusa in Finally. Prima ogni riga apriva una connessione nuova (e non sempre la chiudeva).
    Private connAux As MySqlConnection = Nothing
    Private cmdSecondoPrezzo As MySqlCommand = Nothing
    Private cmdSpedizioneGratis As MySqlCommand = Nothing

    Private Function AuxConnection() As MySqlConnection
        If connAux Is Nothing Then
            connAux = New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            connAux.Open()
        End If
        Return connAux
    End Function

    Function secondo_prezzo(ByVal idArticolo As Integer, ByVal nListino As Integer, ByVal iva_tipo As Integer) As String
        If cmdSecondoPrezzo Is Nothing Then
            cmdSecondoPrezzo = New MySqlCommand("SELECT Prezzo, PrezzoIvato FROM articoli_listini WHERE (NListino=@lst) AND (ArticoliId=@art)", AuxConnection())
            cmdSecondoPrezzo.Parameters.Add("@lst", MySqlDbType.Int32)
            cmdSecondoPrezzo.Parameters.Add("@art", MySqlDbType.Int32)
        End If
        cmdSecondoPrezzo.Parameters("@lst").Value = nListino
        cmdSecondoPrezzo.Parameters("@art").Value = idArticolo

        Using dr As MySqlDataReader = cmdSecondoPrezzo.ExecuteReader()
            If Not dr.Read() Then Return ""
            Dim colonna As String = If(iva_tipo = 1, "Prezzo", "PrezzoIvato")
            If IsDBNull(dr.Item(colonna)) Then Return ""
            Return FormatNumber(CDbl(dr.Item(colonna)), 2).Replace(".", "").Replace(",", ".")
        End Using
    End Function

    Function converti_in_minuscolo(ByVal testo As String) As String
        testo = LCase(testo)
        Return (UCase(testo.Substring(0, 1)) & (testo.Substring(1, testo.Length - 1)))
    End Function

    Private Function ExportProductImageUrl(ByVal value As Object, ByVal dominio As String, ByVal thumbnail As Boolean) As String
        Dim resolved As String = If(thumbnail, ThemeManager.ProductThumbnailImageUrl(value), ThemeManager.ProductImageUrl(value))
        If String.Equals(resolved, ThemeManager.PlaceholderProductImageUrl(), StringComparison.OrdinalIgnoreCase) Then Return String.Empty
        If resolved.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse resolved.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then Return resolved
        If resolved.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then Return String.Empty
        Return "https://" & dominio.Trim().TrimEnd("/"c) & "/" & resolved.TrimStart("/"c)
    End Function

    Function verifica_spedizione_gratis(ByVal idArticolo As Integer, ByVal nListino As Integer) As Integer
        If cmdSpedizioneGratis Is Nothing Then
            cmdSpedizioneGratis = New MySqlCommand("SELECT id FROM articoli WHERE (SpedizioneGratis_Listini LIKE CONCAT('%', @lst, ';%')) AND (id = @art) AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())", AuxConnection())
            cmdSpedizioneGratis.Parameters.Add("@lst", MySqlDbType.Int32)
            cmdSpedizioneGratis.Parameters.Add("@art", MySqlDbType.Int32)
        End If
        cmdSpedizioneGratis.Parameters("@lst").Value = nListino
        cmdSpedizioneGratis.Parameters("@art").Value = idArticolo

        Using dr As MySqlDataReader = cmdSpedizioneGratis.ExecuteReader()
            If dr.Read() Then Return 1
            Return 0
        End Using
    End Function

    'Promozione valida OGGI per 1 pezzo, con la stessa regola della scheda articolo (articolo.aspx.vb, BuildProductSql): quantita minima tra 0 (esclusa) e 1,
    'oppure nessuna quantita minima e multipli = 1. Scaglioni (minimo > 1) e multipli maggiori di 1 non sono prezzi per 1 pezzo.
    Private Const SqlPromoPerUnPezzo As String = "(InOfferta=1 and ((coalesce(OfferteQntMinima,0)>0 and OfferteQntMinima<=1) or (coalesce(OfferteQntMinima,0)<=0 and coalesce(OfferteMultipli,0)=1)))"

    'Una sola riga per articolo: la vista ha una riga per offerta; le righe dello stesso articolo sono adiacenti (id nell'ordine) e la prima e quella con la promozione
    'valida per 1 pezzo (a parita il prezzo piu basso), se esiste.
    Private Const SqlOrdineArticolo As String = " order by settoriid, categorieid, tipologieid, marcheid, codice, id, " & SqlPromoPerUnPezzo & " desc, (case when " & SqlPromoPerUnPezzo & " then PrezzoPromoIvato end), coalesce(OfferteDettagliId,0)"

    'Condizioni di una riga di export_filtri: le colonne sono intere, ogni valore passa da un parametro numerato (@fm0, @fs0, ...); il testo SQL non contiene valori.
    Private Function FiltroCondizioni(ByVal riga As MySqlDataReader, ByVal comando As MySqlCommand, ByVal indice As Integer) As String
        Dim suffisso As String = indice.ToString()
        Dim colonne() As String = {"MarcheId", "SettoriId", "CategorieId", "TipologieId", "GruppiId", "SottogruppiId"}
        Dim sigle() As String = {"fm", "fs", "fc", "ft", "fg", "fsg"}
        Dim campi() As String = {"marcheid", "settoriid", "categorieid", "tipologieid", "gruppiid", "sottogruppiid"}
        Dim soglie() As Integer = {0, -1, -1, -1, -1, -1}
        Dim parti As New List(Of String)
        For i As Integer = 0 To colonne.Length - 1
            If riga.Item(colonne(i)) > soglie(i) Then
                parti.Add("(" & campi(i) & "=@" & sigle(i) & suffisso & ")")
                comando.Parameters.AddWithValue("@" & sigle(i) & suffisso, riga.Item(colonne(i)))
            Else
                parti.Add("(1=1)")
            End If
        Next
        Return String.Join(" and ", parti.ToArray())
    End Function

    Private Function FiltroArticolo(ByVal riga As MySqlDataReader, ByVal comando As MySqlCommand, ByVal indice As Integer) As String
        If riga.Item("ArticoliId") > -1 Then
            comando.Parameters.AddWithValue("@fa" & indice.ToString(), riga.Item("ArticoliId"))
            Return "id=@fa" & indice.ToString()
        End If
        Return "1=1"
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
        Dim dr As MySqlDataReader = Nothing
        Dim ultimoArtId As Int64 = -1

        Dim calcola_spedizione_reale As Integer = 0

        Try
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "select export.*, vettori.iva, iva.valore from export left join vettori on export.idVettore=vettori.id left join iva on vettori.iva=iva.id where (export.id=@id and export.`password`=@pwd) limit 0, 1"
        cmd.Parameters.AddWithValue("@id", ID)
        cmd.Parameters.AddWithValue("@pwd", If(Password, ""))

        dr = cmd.ExecuteReader()
        dr.Read()

        'Lettura Parametri
        If Not dr.HasRows Then
            Response.Write("ID o Password errati.")
            Return
        ElseIf IsDBNull(dr.Item("Abilitato")) OrElse Convert.ToInt32(dr.Item("Abilitato")) <> 1 Then
            'Feed spento (o senza valore): breve testo, nessun dato; lo stato si dice solo a chi conosce id e password.
            Response.Write("Feed non disponibile")
            Return
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

            cmd.Parameters.Clear()

            If calcola_spedizione_reale = 1 Then
                cmd.CommandText = "SELECT PesoMax, CostoFisso FROM (vettoricosti) WHERE (VettoriId = @vet)ORDER BY PesoMax"
                cmd.Parameters.AddWithValue("@vet", idVettore)

                dtAdapter.SelectCommand = cmd
                dtAdapter.Fill(ds)
                dt = ds.Tables(0)

                dtAdapter = Nothing
            End If

            'Lettura Articoli
            If Listino > 0 Then

                Path = Path & Nome & ".txt"

                cmd.Parameters.Clear()
                cmd.Parameters.AddWithValue("@lst", Listino)

                If Giacenza >= 0 Then
                    strGiacenza = " and Giacenza >= @gia"
                    cmd.Parameters.AddWithValue("@gia", Giacenza)
                End If

                'cmd.CommandText = "select * from varticolilistini where export=1 and nlistino=" & Listino & strGiacenza & " order by settoriid, categorieid, tipologieid, marcheid, codice"

                '-----------------------------------------------------------------------------------------------------
                '-----------------------------------------------------------------------------------------------------
                'Filtro Esportazione
                Dim cmd2 As New MySqlCommand
                Dim dr2 As MySqlDataReader

                cmd2.Connection = conn
                cmd2.CommandType = CommandType.Text
                cmd2.CommandText = "select * from export_filtri where ExportId=@exid"
                cmd2.Parameters.AddWithValue("@exid", ID)

                dr2 = cmd2.ExecuteReader()
                dr2.Read()

                'Lettura Parametri
                If dr2.HasRows Then
                    Dim idxFiltro As Integer = 0
                    cmd.CommandText = "select * from vsuperarticoli where export=1 and nlistino=@lst" & strGiacenza & " and ( ((" & FiltroCondizioni(dr2, cmd, idxFiltro) & " ) AND (" & FiltroArticolo(dr2, cmd, idxFiltro) & "))"
                    While dr2.Read()
                        idxFiltro += 1
                        cmd.CommandText = cmd.CommandText & " or ((" & FiltroCondizioni(dr2, cmd, idxFiltro) & " ) AND (" & FiltroArticolo(dr2, cmd, idxFiltro) & "))"
                    End While
                    cmd.CommandText = cmd.CommandText & ")" & SqlOrdineArticolo
                Else
                    cmd.CommandText = "select * from vsuperarticoli where export=1 and nlistino=@lst" & strGiacenza & SqlOrdineArticolo
                End If
                dr2.Close()
                cmd2.Dispose()
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
                'Righe dello stesso articolo (una per offerta): vale la prima, gia scelta dall'ordine.
                If ArtID = ultimoArtId Then Continue While
                ultimoArtId = ArtID
                If ArtID = 15143 Then
                    Dim a As Integer = 1
                End If
                settore = dr.Item("SettoriDescrizione")
                Descrizione1 = Left(dr.Item("descrizione1"), 255).Trim.Replace(vbCrLf, "").Replace("|", "/")
                Marca = dr.Item("MarcheDescrizione").ToString
                Descrizione2 = String.Empty
                If Not dr.Item("descrizione2") Is DBNull.Value Then Descrizione2 = Left(dr.Item("descrizione2"), 255).Trim.Replace(vbCrLf, "").Replace("|", "/")
                DescrizioneLunga = dr.Item("descrizionelunga").Trim.Replace("|", "/")
                DescrizioneHTML = ""
                If IsDBNull(dr.Item("DescrizioneHTML")) = False Then
                    DescrizioneHTML = dr.Item("DescrizioneHTML").Trim.Replace("|", "/")
                End If
                'Codice = ArtID
                'comparatore = dr.Item("comparatore")
                Codice = Left(dr.Item("codice"), 255).Trim.Replace(vbCrLf, "").Replace("|", "/")
                Link = "https://" & Dominio & "/articolo.aspx?id=" & ArtID & "&comparatore=" & comparatore
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

                    UrlImg = ExportProductImageUrl(dr.Item("Img1"), Dominio, True)
                    UrlImgBig = ExportProductImageUrl(dr.Item("Img1"), Dominio, False)
                    UrlImg2 = ExportProductImageUrl(dr.Item("Img2"), Dominio, True)
                    UrlImg2Big = ExportProductImageUrl(dr.Item("Img2"), Dominio, False)
                    UrlImg3 = ExportProductImageUrl(dr.Item("Img3"), Dominio, True)
                    UrlImg3Big = ExportProductImageUrl(dr.Item("Img3"), Dominio, False)
                    UrlImg4 = ExportProductImageUrl(dr.Item("Img4"), Dominio, True)
                    UrlImg4Big = ExportProductImageUrl(dr.Item("Img4"), Dominio, False)

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

                    'Promozione valida oggi per 1 pezzo (mai prezzi a scaglioni di quantita): altrimenti prezzo di listino.
                    Dim promoPerUnPezzo As Boolean = False
                    If Not IsDBNull(dr.Item("InOfferta")) AndAlso Convert.ToInt32(dr.Item("InOfferta")) = 1 Then
                        Dim qMin As Double = If(IsDBNull(dr.Item("OfferteQntMinima")), 0, Convert.ToDouble(dr.Item("OfferteQntMinima")))
                        Dim multipli As Integer = If(IsDBNull(dr.Item("OfferteMultipli")), 0, Convert.ToInt32(dr.Item("OfferteMultipli")))
                        promoPerUnPezzo = (qMin > 0 AndAlso qMin <= 1) OrElse (qMin <= 0 AndAlso multipli = 1)
                    End If
                    Prezzo = "0"

                    If IvaTipo = 1 Then
                        If promoPerUnPezzo Then
                            Prezzo = dr.Item("PrezzoPromo")
                        Else
                            If dr.Item("Prezzo").ToString <> "" Then
                                Prezzo = dr.Item("Prezzo")
                            Else
                                Prezzo = 0
                            End If
                        End If
                    ElseIf IvaTipo = 2 Then
                        If promoPerUnPezzo Then
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
                    Prezzo2 = ""
                    If strLine.Contains("#Prezzo2#") Then Prezzo2 = secondo_prezzo(ArtID, Listino2, IvaTipo)

                    If strLine.Contains("#CostoSpedizioneProdo#") Then
                        If verifica_spedizione_gratis(ArtID, Listino) = 1 Then
                            If Request.QueryString("google") = 1 Then
                                strLine = strLine.Replace("#CostoSpedizioneProdo#", "IT::Standard:0")
                            Else
                                strLine = strLine.Replace("#CostoSpedizioneProdo#", 0)
                            End If
                        Else
                            Dim costoFascia As String = calcola_spese_spedizione(peso)
                            If costoFascia = "" Then
                                strLine = strLine.Replace("#CostoSpedizioneProdo#", "")
                            ElseIf IvaTipo = 1 Then
                                strLine = strLine.Replace("#CostoSpedizioneProdo#", costoFascia)
                            Else
                                If Request.QueryString("google") = 1 Then
                                    strLine = strLine.Replace("#CostoSpedizioneProdo#", costoFascia)
                                Else
                                    strLine = strLine.Replace("#CostoSpedizioneProdo#", costoFascia * ((Iva_Vettore / 100) + 1))
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

                    'Nome scritto a mano in 17 feed reali: la descrizione lunga con i tag HTML (stessa colonna DescrizioneHTML di #DescrizioneHtml#).
                    If strLine.Contains("#DescrizioneLungaHtml#") Then
                        strLine = strLine.Replace("#DescrizioneLungaHtml#", TrasformaTestoXHtml(DescrizioneHTML))
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
                    Else
                        Response.Write(strLine + Environment.NewLine)
                    End If
                End While

                dr.Close()
            End If

        Finally
            'Connessioni sempre chiuse, anche con errore: principale e ausiliaria (le richieste non lasciano connessioni aperte).
            If dr IsNot Nothing Then dr.Dispose()
            If cmdSecondoPrezzo IsNot Nothing Then cmdSecondoPrezzo.Dispose()
            If cmdSpedizioneGratis IsNot Nothing Then cmdSpedizioneGratis.Dispose()
            If connAux IsNot Nothing Then
                connAux.Close()
                connAux.Dispose()
            End If
            cmd.Dispose()
            conn.Close()
            conn.Dispose()
        End Try

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
