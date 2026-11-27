Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Text

' EXPORT-FEED-ENGINE-1A. Prova unitaria del motore puro (App_Code\KeepStoreFeedEngine.vb), compilato insieme a questo file da Tools\Test-ExportFeedEngine.ps1.
' Stampa una riga "ok <nome>" o "FAIL <nome>" per ogni caso; esce con 1 se ne fallisce almeno uno.
Public Module ExportFeedEngineHarness
    Private failures As Integer = 0

    Private Sub Check(ByVal ok As Boolean, ByVal name As String)
        If ok Then
            Console.WriteLine("ok " & name)
        Else
            failures += 1
            Console.WriteLine("FAIL " & name)
        End If
    End Sub

    Private Function HexOf(ByVal enc As Encoding, ByVal text As String) As String
        Dim sb As New StringBuilder()
        For Each bt As Byte In enc.GetBytes(text)
            sb.Append(bt.ToString("X2"))
        Next
        Return sb.ToString()
    End Function

    Private Function Col(ByVal title As String, ByVal source As String) As KeepStoreFeedColumn
        Dim c As New KeepStoreFeedColumn()
        c.Title = title
        c.Source = source
        Return c
    End Function

    Private Function Row() As KeepStoreFeedRow
        Dim r As New KeepStoreFeedRow()
        r.Id = 42
        r.Code = "AB-1"
        r.Ean = "123"
        r.Title1 = "Cavo ""A&B"" <rosso>; 2|3" & vbCrLf & "riga"
        r.HtmlText = "<p>Ciao&nbsp;<b>mondo</b> &amp; co</p>"
        r.Brand = "Marca"
        r.SectorName = "Sett"
        r.CategoryName = "Cat"
        r.TypeName = ""
        r.GroupName = "Grp"
        r.Price = 12.5D
        r.Weight = 1.25D
        r.Stock = 3D
        Return r
    End Function

    Private Function Ctx() As KeepStoreFeedContext
        Dim c As New KeepStoreFeedContext()
        c.Domain = "www.example.test"
        c.ShippingFee = "4.90"
        c.ShippingDays = "2"
        Return c
    End Function

    Public Function Main() As Integer
        Dim o As New KeepStoreFeedOptions()
        Dim cols As New List(Of KeepStoreFeedColumn)()
        cols.Add(Col("Link", "#Link#"))
        cols.Add(Col("Prezzo", "#Prezzo#"))

        ' --- codice del link e nomi dei file ---
        Check(KeepStoreFeedEngine.NormalizeFormat(Nothing) = "txt" AndAlso Not KeepStoreFeedEngine.IsValidToken(Nothing) AndAlso KeepStoreFeedEngine.ContentType("txt", Nothing) = "text/plain; charset=", "valori Nothing non fanno eccezione")
        Check(KeepStoreFeedEngine.IsValidToken(New String("A"c, 48)), "token valido")
        Check(Not KeepStoreFeedEngine.IsValidToken(New String("A"c, 47)), "token troppo corto")
        Check(Not KeepStoreFeedEngine.IsValidToken(New String("a"c, 48)), "token minuscolo non valido (il servizio lo porta in maiuscolo prima)")
        Check(Not KeepStoreFeedEngine.IsValidToken(New String("G"c, 48)), "token non esadecimale")
        Check(Not KeepStoreFeedEngine.IsValidToken(New String("A"c, 47) & "'"), "token con apice")
        Dim tok As String = New String("A"c, 48)
        Dim fp As String = "0123456789ab"
        Check(KeepStoreFeedEngine.FileName("1a2b3c4d", 7, tok, "XML", fp) = "1a2b3c4d-7-" & tok & "-" & fp & ".xml", "nome file con l'impronta")
        Check(KeepStoreFeedEngine.FileName("1a2b3c4d", 7, tok, "", fp) = "1a2b3c4d-7-" & tok & "-" & fp & ".txt", "formato vuoto = txt")
        Dim current As String = KeepStoreFeedEngine.FileName("1a2b3c4d", 7, tok, "xml", fp)
        Check(KeepStoreFeedEngine.IsStaleFileOf(KeepStoreFeedEngine.FileName("1a2b3c4d", 7, tok, "xml", "ba9876543210"), "1a2b3c4d", 7, current), "file con un'altra impronta dello stesso feed e vecchio")
        Check(KeepStoreFeedEngine.IsStaleFileOf("1a2b3c4d-7-" & New String("B"c, 48) & "-" & fp & ".csv", "1a2b3c4d", 7, current), "file con altro codice dello stesso feed e vecchio")
        Check(KeepStoreFeedEngine.IsStaleFileOf("1a2b3c4d-7-" & tok & ".xml", "1a2b3c4d", 7, current), "file di una versione senza impronta e vecchio")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf(current, "1a2b3c4d", 7, current), "il file attuale non e vecchio")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf(KeepStoreFeedEngine.FileName("1a2b3c4d", 77, New String("B"c, 48), "csv", fp), "1a2b3c4d", 7, ""), "un altro feed (77) non si tocca")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf(KeepStoreFeedEngine.FileName("ffffffff", 7, New String("B"c, 48), "csv", fp), "1a2b3c4d", 7, ""), "un'altra installazione non si tocca")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf("web.config", "1a2b3c4d", 7, ""), "web.config della cartella non si tocca")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf("1a2b3c4d-7-" & tok & "-" & fp & ".xml.tmp", "1a2b3c4d", 7, ""), "un temporaneo non e un file pronto")
        Dim fpa As String = KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"a", "b"})
        Check(fpa = KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"a", "b"}) AndAlso fpa.Length = 12 AndAlso System.Text.RegularExpressions.Regex.IsMatch(fpa, "^[0-9a-f]{12}$"), "impronta: stabile, 12 esadecimali minuscoli")
        Check(KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"ab", "c"}) <> KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"a", "bc"}), "impronta: i confini delle parti contano")
        Check(KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"a", ""}) <> KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"a"}), "impronta: una parte vuota in piu cambia l'impronta")
        Check(KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"a", "b"}) <> KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"b", "a"}), "impronta: l'ordine conta")
        Check(KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"a", Nothing}) = KeepStoreFeedEngine.Fingerprint(New List(Of String) From {"a", ""}), "impronta: Nothing = vuoto")
        Check(KeepStoreFeedEngine.PreviewText("h" & vbCrLf & "r1" & vbCrLf & "r2" & vbCrLf, 2, False) = "h" & vbCrLf & "r1", "anteprima: prime righe, a capo finale scartato")
        Check(KeepStoreFeedEngine.PreviewText("a" & vbLf & "b" & vbLf & "c", 10, True) = "a" & vbCrLf & "b", "anteprima: lettura tagliata in byte, ultima riga incompleta scartata")
        Check(KeepStoreFeedEngine.PreviewText("a" & vbLf & "b", 10, False) = "a" & vbCrLf & "b", "anteprima: file breve intero, ultima riga senza a capo conservata")
        Check(KeepStoreFeedEngine.PreviewText("", 5, False) = "" AndAlso KeepStoreFeedEngine.PreviewText(Nothing, 5, False) = "", "anteprima: testo vuoto")
        Check(KeepStoreFeedEngine.PreviewText(New String("x"c, 100), 3, True) = "", "anteprima: una sola riga tagliata in byte non si mostra a meta")
        Check(KeepStoreFeedEngine.WeakETag(255L, 16L) = "W/""ff-10""", "etag debole")
        Check(KeepStoreFeedEngine.ContentType("csv", "UTF-8") = "text/csv; charset=utf-8", "content type csv")
        Check(KeepStoreFeedEngine.ContentType("xml", "iso-8859-1") = "application/xml; charset=utf-8", "xml sempre utf-8")

        ' --- validazione ---
        Check(KeepStoreFeedEngine.Validate(o, cols) = "", "configurazione di base valida")
        Check(KeepStoreFeedEngine.Validate(o, New List(Of KeepStoreFeedColumn)()) = "COLONNE_ASSENTI", "senza colonne")
        o.DecimalSeparator = "|"
        Check(KeepStoreFeedEngine.Validate(o, cols) = "SEPARATORE_DECIMALE_NON_AMMESSO", "decimale non ammesso")
        o.DecimalSeparator = ","
        o.Separator = ","
        Check(KeepStoreFeedEngine.Validate(o, cols) = "CONFIG_SEPARATORE_DECIMALE", "separatore uguale al decimale senza delimitatore")
        o.TextDelimiter = """"
        Check(KeepStoreFeedEngine.Validate(o, cols) = "", "separatore uguale al decimale con delimitatore")
        o.Separator = """"
        Check(KeepStoreFeedEngine.Validate(o, cols) = "SEPARATORE_UGUALE_DELIMITATORE", "separatore uguale al delimitatore")
        o = New KeepStoreFeedOptions()
        o.EncodingName = "utf-16"
        Check(KeepStoreFeedEngine.Validate(o, cols) = "CODIFICA_NON_AMMESSA", "codifica non ammessa")
        o = New KeepStoreFeedOptions()
        o.Separator = ""
        Check(KeepStoreFeedEngine.Validate(o, cols) = "SEPARATORE_NON_AMMESSO", "separatore vuoto")
        o = New KeepStoreFeedOptions()
        Dim unknownCols As New List(Of KeepStoreFeedColumn)()
        unknownCols.Add(Col("X", "#Inventato#"))
        Check(KeepStoreFeedEngine.Validate(o, unknownCols) = "CAMPO_SCONOSCIUTO", "campo sconosciuto")
        o.Format = "xml"
        Dim badXml As New List(Of KeepStoreFeedColumn)()
        badXml.Add(Col("g:price", "#Prezzo#"))
        Check(KeepStoreFeedEngine.Validate(o, badXml) = "NOME_XML_NON_VALIDO", "nome xml con prefisso non ammesso")
        Check(KeepStoreFeedEngine.IsValidXmlName("price") AndAlso KeepStoreFeedEngine.IsValidXmlName("_a.b-c1"), "nomi xml validi")
        Check(Not KeepStoreFeedEngine.IsValidXmlName("1a") AndAlso Not KeepStoreFeedEngine.IsValidXmlName("a b") AndAlso Not KeepStoreFeedEngine.IsValidXmlName("xmlfoo") AndAlso Not KeepStoreFeedEngine.IsValidXmlName(""), "nomi xml non validi")
        o.XmlRoot = "bad name"
        Check(KeepStoreFeedEngine.Validate(o, cols) = "NOME_XML_NON_VALIDO", "radice xml non valida")

        ' --- formato storico ---
        Dim legacy As List(Of KeepStoreFeedColumn) = KeepStoreFeedEngine.ParseLegacyFormat("#Codice#|#Descrizione1#||#Prezzo#")
        Check(legacy.Count = 3 AndAlso legacy(0).Title = "Codice" AndAlso legacy(1).Title = "Titolo" AndAlso legacy(2).Source = "#Prezzo#", "formato storico (Descrizione1 = Titolo, segmenti vuoti ignorati)")

        ' --- testo ---
        Check(KeepStoreFeedEngine.CleanText("a" & vbCrLf & "b" & vbTab & " c", False) = "a b c", "a capo e tab diventano uno spazio")
        Check(KeepStoreFeedEngine.CleanText("<p>Ciao&nbsp;<b>m</b> &amp; c</p>", True).Replace(ChrW(160), " ") = "Ciao m & c", "tag tolti, entita decodificate")
        Check(KeepStoreFeedEngine.CleanText("<b>x</b>", False) = "<b>x</b>", "tag conservati se non richiesto")
        Check(KeepStoreFeedEngine.StripInvalidXmlChars("a" & ChrW(1) & "b" & ChrW(&HFFFE) & "c" & ChrW(&HD83D) & ChrW(&HDE00)) = "abc" & ChrW(&HD83D) & ChrW(&HDE00), "caratteri non ammessi da XML 1.0")
        Check(KeepStoreFeedEngine.HttpsUrl("http://x.test/a.jpg") = "https://x.test/a.jpg" AndAlso KeepStoreFeedEngine.HttpsUrl("https://x") = "https://x" AndAlso KeepStoreFeedEngine.HttpsUrl("") = "", "https")

        ' --- numeri ---
        Check(KeepStoreFeedEngine.FormatMoney(1.005D, ".") = "1.01", "arrotondamento mezzo centesimo in su")
        Check(KeepStoreFeedEngine.FormatMoney(2.994D, ".") = "2.99", "arrotondamento 4 resta")
        Check(KeepStoreFeedEngine.FormatMoney(1234.5D, ",") = "1234,50", "decimale virgola, nessun separatore di migliaia")
        Check(KeepStoreFeedEngine.FormatNumber(1.25D, ".") = "1.25" AndAlso KeepStoreFeedEngine.FormatNumber(2D, ",") = "2", "peso")
        Check(KeepStoreFeedEngine.MoneyWithTax(10D, True, 22D, ".") = "12.20" AndAlso KeepStoreFeedEngine.MoneyWithTax(10D, False, 22D, ".") = "10.00", "importo con e senza IVA del vettore")

        ' --- spedizione ---
        Dim today As Date = New Date(2026, 11, 25)
        Check(KeepStoreFeedEngine.IsFreeShipping("1;2;", 1, New Date(2026, 11, 1), New Date(2026, 12, 1), today), "spedizione gratis: listino 1 presente")
        Check(Not KeepStoreFeedEngine.IsFreeShipping("11;2;", 1, New Date(2026, 11, 1), New Date(2026, 12, 1), today), "spedizione gratis: 11; NON vale per il listino 1 (token esatti)")
        Check(Not KeepStoreFeedEngine.IsFreeShipping("1;", 1, New Date(2026, 11, 26), New Date(2026, 12, 1), today), "spedizione gratis: non ancora iniziata")
        Check(Not KeepStoreFeedEngine.IsFreeShipping("1;", 1, New Date(2026, 11, 1), New Date(2026, 11, 24), today), "spedizione gratis: finita")
        Check(Not KeepStoreFeedEngine.IsFreeShipping("1;", 1, Nothing, New Date(2026, 12, 1), today), "spedizione gratis: senza data di inizio")
        Check(KeepStoreFeedEngine.IsFreeShipping("1;", 1, New Date(2026, 11, 25), New Date(2026, 11, 25), today), "spedizione gratis: estremi inclusi")
        Dim bands As New List(Of KeyValuePair(Of Integer, Decimal))()
        bands.Add(New KeyValuePair(Of Integer, Decimal)(5, 6D))
        bands.Add(New KeyValuePair(Of Integer, Decimal)(20, 9D))
        Check(KeepStoreFeedEngine.ShippingBandCost(bands, 5D).Value = 6D AndAlso KeepStoreFeedEngine.ShippingBandCost(bands, 5.01D).Value = 9D AndAlso Not KeepStoreFeedEngine.ShippingBandCost(bands, 20.5D).HasValue, "fasce di peso, oltre l'ultima nessuna tariffa")

        ' --- valori ---
        o = New KeepStoreFeedOptions()
        Dim r As KeepStoreFeedRow = Row()
        Dim cx As KeepStoreFeedContext = Ctx()
        Check(KeepStoreFeedEngine.TokenValue("Link", r, cx, o) = "https://www.example.test/articolo.aspx?id=42", "link https senza parametri di comparatore")
        Check(KeepStoreFeedEngine.TokenValue("Prezzo", r, cx, o) = "12.50", "prezzo")
        Check(KeepStoreFeedEngine.TokenValue("Disponibilita", r, cx, o) = "Disponibile", "disponibile")
        r.Stock = 0D : r.Incoming = 2D
        Check(KeepStoreFeedEngine.TokenValue("Disponibilita", r, cx, o) = "In Arrivo", "in arrivo")
        r.Incoming = 0D
        Check(KeepStoreFeedEngine.TokenValue("Disponibilita", r, cx, o) = "Non Disponibile", "non disponibile")
        o.WordUnavailable = "out_of_stock"
        Check(KeepStoreFeedEngine.TokenValue("Disponibilita", r, cx, o) = "out_of_stock", "parola scelta per la disponibilita")
        o = New KeepStoreFeedOptions()
        Check(KeepStoreFeedEngine.TokenValue("CategoriaPercorso", r, cx, o) = "Sett > Cat > Grp", "percorso categoria senza livelli vuoti")
        Check(KeepStoreFeedEngine.TokenValue("Condizione", r, cx, o) = "NUOVO", "condizione nuovo")
        r.Refurbished = 1
        Check(KeepStoreFeedEngine.TokenValue("Condizione", r, cx, o) = "RICONDIZIONATO", "condizione ricondizionato")
        o.LowerCaseTitle = True
        r.Title1 = "ABC dEF"
        Check(KeepStoreFeedEngine.TokenValue("Descrizione1", r, cx, o) = "Abc def", "tutto minuscolo con iniziale maiuscola")
        r.Title1 = ""
        Check(KeepStoreFeedEngine.TokenValue("Descrizione1", r, cx, o) = "", "tutto minuscolo sul testo vuoto non va in errore")

        ' --- colonne: prefisso, suffisso, massimo, se vuoto ---
        o = New KeepStoreFeedOptions()
        r = Row()
        Dim cp As KeepStoreFeedColumn = Col("price", "#Prezzo#")
        cp.Suffix = " EUR"
        Check(KeepStoreFeedEngine.ColumnValue(cp, r, cx, o) = "12.50 EUR", "suffisso della valuta")
        Dim ce As KeepStoreFeedColumn = Col("t", "#Descrizione2#")
        ce.Prefix = "P:"
        ce.Suffix = ":S"
        Check(KeepStoreFeedEngine.ColumnValue(ce, r, cx, o) = "", "colonna vuota: nessun prefisso ne suffisso")
        ce.IfEmpty = "n/d"
        Check(KeepStoreFeedEngine.ColumnValue(ce, r, cx, o) = "P:n/d:S", "valore se vuoto, poi prefisso e suffisso")
        Dim cm As KeepStoreFeedColumn = Col("m", "#Codice#")
        r.Code = "ABCDEFGHIJ"
        cm.MaxChars = 4
        Check(KeepStoreFeedEngine.ColumnValue(cm, r, cx, o) = "ABCD", "massimo di caratteri")
        Dim cf As KeepStoreFeedColumn = Col("f", "IT::Standard:#CostoSpedizioneProdo# EUR")
        r.ShippingCost = "4.90"
        Check(KeepStoreFeedEngine.ColumnValue(cf, r, cx, o) = "IT::Standard:4.90 EUR", "modello con testo e campo")
        Dim cx2 As KeepStoreFeedColumn = Col("fix", "new")
        Check(KeepStoreFeedEngine.ColumnValue(cx2, r, cx, o) = "new", "valore fisso")
        Dim cs As KeepStoreFeedColumn = Col("s", "#Marca#")
        cs.MaxChars = 3
        r.Brand = ChrW(&HD83D) & ChrW(&HDE00) & "ab"
        Check(KeepStoreFeedEngine.ColumnValue(cs, r, cx, o) = ChrW(&HD83D) & ChrW(&HDE00) & "a" OrElse KeepStoreFeedEngine.ColumnValue(cs, r, cx, o) = ChrW(&HD83D) & ChrW(&HDE00) & "a", "troncamento")
        cs.MaxChars = 1
        Check(KeepStoreFeedEngine.ColumnValue(cs, r, cx, o) = "", "troncamento che cadrebbe in mezzo a una coppia surrogata")

        ' --- scarti ---
        o = New KeepStoreFeedOptions()
        r = Row()
        r.Price = 0D
        Check(KeepStoreFeedEngine.SkipReason(r, o) = "PREZZO_ZERO", "scarto prezzo zero (predefinito)")
        o.SkipZeroPrice = False
        Check(KeepStoreFeedEngine.SkipReason(r, o) = "", "prezzo zero ammesso se scelto")
        r.Price = 1D
        o.SkipNoEan = True
        r.Ean = " "
        Check(KeepStoreFeedEngine.SkipReason(r, o) = "SENZA_EAN", "scarto senza EAN")
        o.SkipNoEan = False
        o.SkipNoImage = True
        Check(KeepStoreFeedEngine.SkipReason(r, o) = "SENZA_IMMAGINE", "scarto senza immagine")
        r.ImageUrls(1) = "https://x/y.jpg"
        Check(KeepStoreFeedEngine.SkipReason(r, o) = "", "con immagine non si scarta")

        ' --- righe con separatore ---
        o = New KeepStoreFeedOptions()
        Dim vals As New List(Of String)()
        vals.Add("a|b")
        vals.Add("12,50")
        Check(KeepStoreFeedEngine.DelimitedLine(vals, o) = "a b|12,50", "senza delimitatore il separatore nel valore diventa spazio")
        o.Separator = ";"
        o.TextDelimiter = """"
        vals(0) = "dice ""ciao""; ok"
        Check(KeepStoreFeedEngine.DelimitedLine(vals, o) = """dice """"ciao""""; ok"";""12,50""", "delimitatore: virgolette raddoppiate, separatore dentro il valore protetto")
        o = New KeepStoreFeedOptions()
        o.Format = "tsv"
        o.Separator = "|"
        vals(0) = "x" & vbTab & "y"
        Check(KeepStoreFeedEngine.DelimitedLine(vals, o) = "x y" & vbTab & "12,50", "tsv: il separatore e il tab, ignorando l'opzione")

        ' --- codifiche ---
        Check(KeepStoreFeedEngine.ResolveEncoding("utf-8").GetBytes("e" & ChrW(&HE8)).Length = 3, "utf-8 senza bom")
        Check(KeepStoreFeedEngine.ResolveEncoding("iso-8859-1").GetBytes("e" & ChrW(&HE8)).Length = 2, "latin1")
        Check(Encoding.GetEncoding(28591).GetString(KeepStoreFeedEngine.ResolveEncoding("iso-8859-1").GetBytes("a" & ChrW(&H20AC))) = "a?", "carattere non rappresentabile diventa ?")
        Check(KeepStoreFeedEngine.ResolveEncoding("windows-1252").GetBytes(ChrW(&H20AC))(0) = &H80, "windows-1252 ha l'euro")
        Check(KeepStoreFeedEngine.ResolveEncoding("utf-16") Is Nothing, "codifica sconosciuta")

        ' --- GOOGLE-MERCHANT-CENTER-FEED-1A: campi nuovi (CondizioneInglese, EanValido, DescrizioneSoloTesto, TitoloNormalizzato) ---
        ' PlainText: ordine decodifica entita, via commenti/script/stile con il contenuto, via i soli tag veri, poi una riga.
        Check(KeepStoreFeedEngine.PlainText("<p>Ciao&nbsp;<b>mondo</b> &amp; co</p>") = "Ciao mondo & co", "testo semplice: tag e entita")
        Check(KeepStoreFeedEngine.PlainText("A &amp; B") = "A & B", "testo semplice: entita senza tag decodificata")
        Check(KeepStoreFeedEngine.PlainText("&lt;b&gt;X&lt;/b&gt;") = "X", "testo semplice: tag scritto come entita non ricompare")
        Check(KeepStoreFeedEngine.PlainText("<script>alert(1)</script>Testo") = "Testo", "testo semplice: contenuto di script tolto")
        Check(KeepStoreFeedEngine.PlainText("<SCRIPT type=""x"">a</SCRIPT>y<style>p{color:red}</style>z") = "y z", "testo semplice: script e stile in maiuscolo")
        Check(KeepStoreFeedEngine.PlainText("a<!-- x > y -->b") = "a b", "testo semplice: commento con > dentro")
        Check(KeepStoreFeedEngine.PlainText("peso <2kg, schermo >15"" ok") = "peso <2kg, schermo >15"" ok", "testo semplice: minore e maggiore non sono tag")
        Check(KeepStoreFeedEngine.PlainText("5 < 10 > 3") = "5 < 10 > 3", "testo semplice: confronto numerico intatto")
        Check(KeepStoreFeedEngine.PlainText("Riga1<br>Riga2<br/>Riga3") = "Riga1 Riga2 Riga3", "testo semplice: br diventa spazio")
        Check(KeepStoreFeedEngine.PlainText("&amp;lt;b&amp;gt;") = "&lt;b&gt;", "testo semplice: una sola decodifica")
        Check(KeepStoreFeedEngine.PlainText("Linea" & vbTab & "x" & vbLf & "y") = "Linea x y", "testo semplice: tab e a-capo in spazio")
        Check(KeepStoreFeedEngine.PlainText("") = "" AndAlso KeepStoreFeedEngine.PlainText(Nothing) = "", "testo semplice: vuoto")
        Check(KeepStoreFeedEngine.PlainText("<script>abc") = "abc", "testo semplice: script non chiuso lascia il testo")
        ' ValidGtin: cifra di controllo GS1, lunghezze 8/12/13/14, niente spazi, niente tutto zero, prefissi non ammessi.
        Check(KeepStoreFeedEngine.ValidGtin("4006381333931") = "4006381333931", "gtin: EAN-13 valido")
        Check(KeepStoreFeedEngine.ValidGtin("3001234567892") = "3001234567892", "gtin: EAN-13 valido (esempio Google)")
        Check(KeepStoreFeedEngine.ValidGtin("036000291452") = "036000291452", "gtin: UPC-A con zero iniziale valido, zeri conservati")
        Check(KeepStoreFeedEngine.ValidGtin("10856435001702") = "10856435001702", "gtin: GTIN-14 valido")
        Check(KeepStoreFeedEngine.ValidGtin("96385074") = "96385074", "gtin: EAN-8 valido")
        Check(KeepStoreFeedEngine.ValidGtin(" 4006381333931 ") = "4006381333931", "gtin: spazi ai bordi tolti")
        Check(KeepStoreFeedEngine.ValidGtin("4006381333932") = "", "gtin: cifra di controllo errata")
        Check(KeepStoreFeedEngine.ValidGtin("96385075") = "", "gtin: EAN-8 con cifra errata")
        Check(KeepStoreFeedEngine.ValidGtin("4006 381333931") = "" AndAlso KeepStoreFeedEngine.ValidGtin("4006-381333931") = "", "gtin: spazi o trattini interni non validi")
        Check(KeepStoreFeedEngine.ValidGtin("40063813339X1") = "" AndAlso KeepStoreFeedEngine.ValidGtin("12345678901") = "" AndAlso KeepStoreFeedEngine.ValidGtin("123456789") = "" AndAlso KeepStoreFeedEngine.ValidGtin("123456789012345") = "", "gtin: lettere o lunghezza non ammessa")
        Check(KeepStoreFeedEngine.ValidGtin("300123456A892") = "", "gtin: lettera che lascia giusta la somma di controllo (A vale 17, come un 7)")
        Check(KeepStoreFeedEngine.ValidGtin("0000000000000") = "" AndAlso KeepStoreFeedEngine.ValidGtin("000000000000") = "" AndAlso KeepStoreFeedEngine.ValidGtin("00000000") = "", "gtin: tutto zero non valido")
        Check(KeepStoreFeedEngine.ValidGtin("0212345678909") = "" AndAlso KeepStoreFeedEngine.ValidGtin("0412345678903") = "" AndAlso KeepStoreFeedEngine.ValidGtin("2012345678903") = "", "gtin: prefissi 02, 04, 2 non ammessi")
        Check(KeepStoreFeedEngine.ValidGtin("9812345678902") = "" AndAlso KeepStoreFeedEngine.ValidGtin("9912345678909") = "", "gtin: prefissi 98 e 99 (coupon) non ammessi")
        Check(KeepStoreFeedEngine.ValidGtin("212345678909") = "" AndAlso KeepStoreFeedEngine.ValidGtin("412345678903") = "", "gtin: UPC-A che comincia con 2 o 4 non ammesso")
        Check(KeepStoreFeedEngine.ValidGtin("0012345678905") = "0012345678905", "gtin: prefisso 00 ammesso")
        Check(KeepStoreFeedEngine.ValidGtin("") = "" AndAlso KeepStoreFeedEngine.ValidGtin(Nothing) = "", "gtin: vuoto")
        ' NormalizeTitle (FEED-TITLES-1B): urlato = nessuna minuscola, oppure maiuscole/(maiuscole+minuscole) >= 0,6 sulle sole parole senza cifre con almeno 5 lettere.
        ' Ricomposizione per segmenti (spazio, trattino, barra) con la maiuscola sulla prima LETTERA; virgolette: pollici dopo cifra, citazioni a coppie. Attesi scritti a mano.
        Dim qd As String = ChrW(34)
        Dim prime As String = ChrW(&H2033)
        Dim lq As String = ChrW(&HAB)
        Dim rq As String = ChrW(&HBB)
        Check(KeepStoreFeedEngine.NormalizeTitle("CAVO DI RETE EWENT", True) = "Cavo Di Rete Ewent", "titolo: tutto maiuscolo normalizzato")
        Check(KeepStoreFeedEngine.NormalizeTitle("HARD DISK 2.5" & qd & " STKM2000400 2TB USB 3.0", True) = "Hard Disk 2.5" & prime & " STKM2000400 2TB Usb 3.0", "titolo: le parole con cifre restano, il pollice diventa primo doppio")
        Check(KeepStoreFeedEngine.NormalizeTitle("HARD DISK 2.5" & qd & " STKM2000400 2TB USB 3.0", False) = "Hard Disk 2.5" & qd & " STKM2000400 2TB Usb 3.0", "titolo: codifica senza primo doppio, il pollice resta virgoletta")
        Check(KeepStoreFeedEngine.NormalizeTitle("HP USB-C", True) = "Hp Usb-C", "titolo: ogni segmento con trattino")
        Check(KeepStoreFeedEngine.NormalizeTitle("Cavo HDMI 2m SSD", True) = "Cavo HDMI 2m SSD", "titolo: normale con sigle resta com'e")
        Check(KeepStoreFeedEngine.NormalizeTitle("Cavo HDMI SSD LED 2m", True) = "Cavo HDMI SSD LED 2m" AndAlso KeepStoreFeedEngine.NormalizeTitle("Cavo USB-C HDMI LED", True) = "Cavo USB-C HDMI LED" AndAlso KeepStoreFeedEngine.NormalizeTitle("Scheda Video NVIDIA RTX", True) = "Scheda Video NVIDIA RTX", "titolo: le sigle corte non rendono urlato un titolo normale")
        Check(KeepStoreFeedEngine.NormalizeTitle("Cavo HDMI LAN WIFI 2m", True) = "Cavo HDMI LAN WIFI 2m", "titolo: parole di 4 lettere non contano nel rapporto")
        Check(KeepStoreFeedEngine.NormalizeTitle("ALPHA beta 2m", True) = "Alpha beta 2m", "titolo: una parola di 5 lettere conta nel rapporto")
        Check(KeepStoreFeedEngine.NormalizeTitle("CUSTODIA IN SILICONE 2mm CON MagSafe PROTEZIONE FOTOCAMERA ( NERO ) PER SAMSUNG S26 ULTRA 5G", True) = "Custodia In Silicone 2mm Con MagSafe Protezione Fotocamera ( Nero ) Per Samsung S26 Ultra 5G", "titolo: urlato con minuscole sparse")
        Check(KeepStoreFeedEngine.NormalizeTitle("CAVO DI RETE (NERO) ORIGINALE", True) = "Cavo Di Rete (Nero) Originale", "titolo: la maiuscola va sulla prima lettera, non sul primo carattere")
        Check(KeepStoreFeedEngine.NormalizeTitle("SCHEDA S-ATA KDI/ANYCOOL DDR-II", True) = "Scheda S-Ata Kdi/Anycool Ddr-Ii", "titolo: trattino e barra separano i segmenti")
        Check(KeepStoreFeedEngine.NormalizeTitle("CAPACITA' DALL'ANELLO PROTEZIONE", True) = "Capacita' Dall'anello Protezione", "titolo: apostrofo")
        Check(KeepStoreFeedEngine.NormalizeTitle("TONER BROTHER COMPATIBILE TN-243BK / TN-247BK NERO", True) = "Toner Brother Compatibile TN-243BK / TN-247BK Nero", "titolo: codici con cifre e trattino interi")
        Check(KeepStoreFeedEngine.NormalizeTitle("ALPHA BRAVO CHARL delta echoo", True) = "Alpha Bravo Charl delta echoo", "titolo: rapporto esattamente 0,6 e urlato")
        Check(KeepStoreFeedEngine.NormalizeTitle("ALPHA BRAVO CHARL delta echoos", True) = "ALPHA BRAVO CHARL delta echoos", "titolo: rapporto appena sotto 0,6 non e urlato")
        Check(KeepStoreFeedEngine.NormalizeTitle("CAVO USB", True) = "Cavo Usb" AndAlso KeepStoreFeedEngine.NormalizeTitle("Cavo USB 2m", True) = "Cavo USB 2m", "titolo: senza parole lunghe vale solo il tutto maiuscolo")
        Check(KeepStoreFeedEngine.NormalizeTitle("CAFF" & ChrW(&HC8) & " NERO", True) = "Caff" & ChrW(&HE8) & " Nero", "titolo: lettere accentate")
        Check(KeepStoreFeedEngine.NormalizeTitle(ChrW(&H4E2D) & ChrW(&H6587) & " USB", True) = ChrW(&H4E2D) & ChrW(&H6587) & " Usb", "titolo: lettere senza maiuscola restano")
        Check(KeepStoreFeedEngine.NormalizeTitle("123 456", True) = "123 456" AndAlso KeepStoreFeedEngine.NormalizeTitle("", True) = "" AndAlso KeepStoreFeedEngine.NormalizeTitle(Nothing, True) = "", "titolo: senza lettere o vuoto")
        Check(KeepStoreFeedEngine.NormalizeTitle("A  B", True) = "A B", "titolo: spazi compressi")
        Check(KeepStoreFeedEngine.NormalizeTitle("Cavo " & qd & "A&B" & qd & " <rosso>;" & vbCrLf & "x", True) = "Cavo " & lq & "A&B" & rq & " <rosso>; x", "titolo: ripulito, citazione fra virgolette basse")
        Check(KeepStoreFeedEngine.NormalizeTitle("Cavo " & qd & "OUT nero", True) = "Cavo 'OUT nero", "titolo: citazione dispari diventa apostrofo")
        Check(KeepStoreFeedEngine.NormalizeTitle(qd & "B&W" & qd & " stampante", True) = lq & "B&W" & rq & " stampante", "titolo: citazione a inizio valore")
        Check(KeepStoreFeedEngine.NormalizeTitle("Monitor 15.6" & qd & " " & qd & "Pro" & qd & " nero", True) = "Monitor 15.6" & prime & " " & lq & "Pro" & rq & " nero", "titolo: pollici e citazione insieme")
        Check(KeepStoreFeedEngine.NormalizeTitle("Monitor 15.6" & qd & " " & qd & "Pro" & qd & " nero", False) = "Monitor 15.6" & qd & " " & lq & "Pro" & rq & " nero", "titolo: pollici senza primo doppio, citazione sempre rappresentabile")
        Check(KeepStoreFeedEngine.NormalizeTitle("HARD DISK " & qd & "OUT" & qd & " 2TB", True) = "Hard Disk " & lq & "Out" & rq & " 2TB", "titolo: urlato con citazione")
        Check(KeepStoreFeedEngine.NormalizeTitle(ChrW(&H4E2D) & ChrW(&H6587) & ChrW(&H4E2D) & ChrW(&H6587) & ChrW(&H4E2D) & " ALPHA beta", True) = ChrW(&H4E2D) & ChrW(&H6587) & ChrW(&H4E2D) & ChrW(&H6587) & ChrW(&H4E2D) & " Alpha beta", "titolo: le lettere senza maiuscola non contano nel rapporto")
        Check(KeepStoreFeedEngine.EngineVersion = "E3", "versione del motore E3: i file pronti col titolo vecchio si rigenerano")
        Dim idem As String() = New String() {"CAVO DI RETE (NERO) ORIGINALE", "HARD DISK 2.5" & qd & " USB-C", "Monitor 15.6" & qd & " " & qd & "Pro" & qd & " nero", "ALPHA BRAVO CHARL delta echoo", "SCHEDA S-ATA KDI/ANYCOOL"}
        Dim idemOk As Boolean = True
        For Each it As String In idem
            Dim once As String = KeepStoreFeedEngine.NormalizeTitle(it, True)
            If KeepStoreFeedEngine.NormalizeTitle(once, True) <> once Then idemOk = False
        Next
        Check(idemOk, "titolo: applicata due volte da lo stesso risultato")
        ' Token nuovi: valore, conoscenza (Validate) e campi esistenti invariati.
        Dim gr As KeepStoreFeedRow = Row()
        Dim go As New KeepStoreFeedOptions()
        Dim gc As KeepStoreFeedContext = Ctx()
        gr.Refurbished = 1
        Check(KeepStoreFeedEngine.TokenValue("CondizioneInglese", gr, gc, go) = "refurbished", "token CondizioneInglese: ricondizionato")
        gr.Refurbished = 0
        Check(KeepStoreFeedEngine.TokenValue("CondizioneInglese", gr, gc, go) = "new", "token CondizioneInglese: nuovo")
        gr.Refurbished = 2
        Check(KeepStoreFeedEngine.TokenValue("condizioneinglese", gr, gc, go) = "new", "token CondizioneInglese: valore diverso da 1 e nuovo, nome in minuscolo")
        gr.Refurbished = 1
        Check(KeepStoreFeedEngine.TokenValue("Condizione", gr, gc, go) = "RICONDIZIONATO", "token Condizione esistente invariato")
        gr.Ean = "4006381333931"
        Check(KeepStoreFeedEngine.TokenValue("EanValido", gr, gc, go) = "4006381333931", "token EanValido: valido")
        gr.Ean = "123"
        Check(KeepStoreFeedEngine.TokenValue("EanValido", gr, gc, go) = "" AndAlso KeepStoreFeedEngine.TokenValue("Ean", gr, gc, go) = "123", "token EanValido: non valido vuoto, Ean esistente invariato")
        gr.LongText = "Testo <b>lungo</b> &amp; <script>x()</script>ok"
        Check(KeepStoreFeedEngine.TokenValue("DescrizioneSoloTesto", gr, gc, go) = "Testo lungo & ok", "token DescrizioneSoloTesto")
        Check(KeepStoreFeedEngine.TokenValue("DescrizioneLunga", gr, gc, go) = "Testo <b>lungo</b> &amp; <script>x()</script>ok", "token DescrizioneLunga esistente invariato")
        gr.Title1 = "CAVO RETE"
        go.LowerCaseTitle = False
        Check(KeepStoreFeedEngine.TokenValue("TitoloNormalizzato", gr, gc, go) = "Cavo Rete" AndAlso KeepStoreFeedEngine.TokenValue("Descrizione1", gr, gc, go) = "CAVO RETE", "token TitoloNormalizzato e Descrizione1 invariato")
        go.LowerCaseTitle = True
        Check(KeepStoreFeedEngine.TokenValue("TitoloNormalizzato", gr, gc, go) = "Cavo Rete", "token TitoloNormalizzato non dipende da Tutto in minuscolo")
        go.LowerCaseTitle = False
        gr.Title1 = "MONITOR 15.6" & qd & " " & qd & "PRO" & qd & " NERO"
        Dim wantUtf As String = "Monitor 15.6" & prime & " " & lq & "Pro" & rq & " Nero"
        Dim wantLat As String = "Monitor 15.6" & qd & " " & lq & "Pro" & rq & " Nero"
        go.EncodingName = "utf-8"
        Check(KeepStoreFeedEngine.TokenValue("TitoloNormalizzato", gr, gc, go) = wantUtf, "token TitoloNormalizzato: utf-8 con primo doppio")
        go.EncodingName = "iso-8859-1"
        Check(KeepStoreFeedEngine.TokenValue("TitoloNormalizzato", gr, gc, go) = wantLat, "token TitoloNormalizzato: iso-8859-1 senza primo doppio")
        go.EncodingName = "windows-1252"
        Check(KeepStoreFeedEngine.TokenValue("TitoloNormalizzato", gr, gc, go) = wantLat, "token TitoloNormalizzato: windows-1252 senza primo doppio")
        go.Format = "xml"
        Check(KeepStoreFeedEngine.TokenValue("TitoloNormalizzato", gr, gc, go) = wantUtf, "token TitoloNormalizzato: xml e sempre utf-8")
        go.Format = "txt"
        go.EncodingName = "iso-8859-1"
        Check(HexOf(KeepStoreFeedEngine.ResolveEncoding("iso-8859-1"), KeepStoreFeedEngine.TokenValue("TitoloNormalizzato", gr, gc, go)) = "4D6F6E69746F7220" & "31352E3622" & "20AB" & "50726F" & "BB204E65726F", "titolo in iso-8859-1: byte esatti, nessun punto interrogativo")
        go.EncodingName = "utf-8"
        Check(HexOf(KeepStoreFeedEngine.ResolveEncoding("utf-8"), KeepStoreFeedEngine.TokenValue("TitoloNormalizzato", gr, gc, go)) = "4D6F6E69746F7220" & "31352E36E280B3" & "20C2AB" & "50726F" & "C2BB204E65726F", "titolo in utf-8: byte esatti")
        Check(KeepStoreFeedEngine.TokenValue("Descrizione1", gr, gc, go) = gr.Title1, "token Descrizione1 conserva le virgolette")
        gr.LongText = "Misura 15" & qd & " e " & qd & "citazione" & qd
        Check(KeepStoreFeedEngine.TokenValue("DescrizioneSoloTesto", gr, gc, go) = "Misura 15" & qd & " e " & qd & "citazione" & qd, "token DescrizioneSoloTesto conserva le virgolette")
        gr.Title1 = "CAVO RETE"
        Dim vcols As New List(Of KeepStoreFeedColumn)()
        vcols.Add(Col("a", "#CondizioneInglese#"))
        vcols.Add(Col("b", "#EanValido#"))
        vcols.Add(Col("c", "#DescrizioneSoloTesto#"))
        vcols.Add(Col("d", "#TitoloNormalizzato#. #DescrizioneSoloTesto#"))
        Check(KeepStoreFeedEngine.Validate(New KeepStoreFeedOptions(), vcols) = "", "i quattro token nuovi sono noti alla validazione")
        vcols.Add(Col("e", "#TokenInventato#"))
        Check(KeepStoreFeedEngine.Validate(New KeepStoreFeedOptions(), vcols) = "CAMPO_SCONOSCIUTO", "un token inventato resta sconosciuto")

        Console.WriteLine("failures=" & failures.ToString())
        Return If(failures = 0, 0, 1)
    End Function
End Module
