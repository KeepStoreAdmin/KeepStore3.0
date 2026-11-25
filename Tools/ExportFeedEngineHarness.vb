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
        Check(KeepStoreFeedEngine.FileName("1a2b3c4d", 7, tok, "XML") = "1a2b3c4d-7-" & tok & ".xml", "nome file")
        Check(KeepStoreFeedEngine.FileName("1a2b3c4d", 7, tok, "") = "1a2b3c4d-7-" & tok & ".txt", "formato vuoto = txt")
        Check(KeepStoreFeedEngine.IsStaleFileOf("1a2b3c4d-7-" & New String("B"c, 48) & ".csv", "1a2b3c4d", 7, "1a2b3c4d-7-" & tok & ".xml"), "file con altro codice dello stesso feed e vecchio")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf("1a2b3c4d-7-" & tok & ".xml", "1a2b3c4d", 7, "1a2b3c4d-7-" & tok & ".xml"), "il file attuale non e vecchio")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf("1a2b3c4d-77-" & New String("B"c, 48) & ".csv", "1a2b3c4d", 7, ""), "un altro feed (77) non si tocca")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf("ffffffff-7-" & New String("B"c, 48) & ".csv", "1a2b3c4d", 7, ""), "un'altra installazione non si tocca")
        Check(Not KeepStoreFeedEngine.IsStaleFileOf("web.config", "1a2b3c4d", 7, ""), "web.config della cartella non si tocca")
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

        Console.WriteLine("failures=" & failures.ToString())
        Return If(failures = 0, 0, 1)
    End Function
End Module
