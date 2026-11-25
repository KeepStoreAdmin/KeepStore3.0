Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Net
Imports System.Text
Imports System.Text.RegularExpressions

' EXPORT-FEED-ENGINE-1A. Logica PURA dei feed (nessun accesso a database, file o richiesta): colonne libere, valori dei campi, formati
' (txt, csv, tsv, xml), nomi XML, scarti, spedizione, nomi dei file pronti. Provata dal test del task con righe sintetiche.
' Il motore non conosce nessun comparatore: ogni destinatario e un feed con le sue colonne e le sue opzioni (dati, non codice).

Public NotInheritable Class KeepStoreFeedColumn
    Public Property Title As String = ""
    ' Modello del valore: un campo (#Prezzo#), un testo fisso, o un testo con piu campi. Vuoto = colonna sempre vuota.
    Public Property Source As String = ""
    Public Property Prefix As String = ""
    Public Property Suffix As String = ""
    ' 0 = nessun limite.
    Public Property MaxChars As Integer = 0
    Public Property IfEmpty As String = ""
End Class

Public NotInheritable Class KeepStoreFeedOptions
    Public Property Format As String = "txt"
    Public Property Separator As String = "|"
    Public Property TextDelimiter As String = ""
    Public Property EncodingName As String = "utf-8"
    Public Property DecimalSeparator As String = "."
    Public Property Header As Boolean = True
    Public Property XmlRoot As String = "prodotti"
    Public Property XmlElement As String = "prodotto"
    Public Property StripHtml As Boolean = True
    Public Property MinutesCache As Integer = 60
    Public Property WordAvailable As String = "Disponibile"
    Public Property WordIncoming As String = "In Arrivo"
    Public Property WordUnavailable As String = "Non Disponibile"
    Public Property SkipNoImage As Boolean = False
    Public Property SkipNoEan As Boolean = False
    Public Property SkipZeroPrice As Boolean = True
    Public Property LowerCaseTitle As Boolean = False
End Class

' Valori gia risolti di una riga del catalogo (articolo + prezzo del sito per l'utente anonimo + spedizione). Riempita dal servizio.
Public NotInheritable Class KeepStoreFeedRow
    Public Property Id As Integer
    Public Property Code As String = ""
    Public Property Ean As String = ""
    Public Property Title1 As String = ""
    Public Property Title2 As String = ""
    Public Property LongText As String = ""
    Public Property HtmlText As String = ""
    Public Property Brand As String = ""
    Public Property SectorId As Integer
    Public Property SectorName As String = ""
    Public Property CategoryId As Integer
    Public Property CategoryName As String = ""
    Public Property TypeId As Integer
    Public Property TypeName As String = ""
    Public Property GroupId As Integer
    Public Property GroupName As String = ""
    Public Property SubgroupId As Integer
    Public Property Weight As Decimal
    Public Property Stock As Decimal
    Public Property Incoming As Decimal
    Public Property Refurbished As Integer
    Public Property WarrantyMonths As String = ""
    Public Property WarrantyText As String = ""
    Public Property VatId As Integer
    Public Property Price As Decimal
    Public Property Price2 As Nullable(Of Decimal)
    Public Property DiscountPercent As Decimal
    Public Property ShippingCost As String = ""
    ' UrlImg, UrlImgBig, UrlImg2, UrlImg2Big, UrlImg3, UrlImg3Big, UrlImg4, UrlImg4Big (gia https; vuoto se manca).
    Public Property ImageUrls As String() = New String() {"", "", "", "", "", "", "", ""}
End Class

' Valori uguali per tutte le righe del feed.
Public NotInheritable Class KeepStoreFeedContext
    Public Property Domain As String = ""
    Public Property ShippingFee As String = ""
    Public Property ShippingDays As String = ""
End Class

Public NotInheritable Class KeepStoreFeedEngine
    Private Sub New()
    End Sub

    Private Shared ReadOnly Invariant As CultureInfo = CultureInfo.InvariantCulture

    ' Convert.ToString(Nothing As String) restituisce Nothing (non una stringa vuota): per i testi opzionali si usa NZ.
    Private Shared Function NZ(ByVal text As String) As String
        If text Is Nothing Then Return ""
        Return text
    End Function
    Private Shared ReadOnly TokenRegex As New Regex("#([A-Za-z0-9_<>]+)#", RegexOptions.Compiled)
    Private Shared ReadOnly TagRegex As New Regex("<[^>]*>", RegexOptions.Compiled)
    Private Shared ReadOnly SpaceRegex As New Regex("\s+", RegexOptions.Compiled)
    Private Shared ReadOnly XmlNameRegex As New Regex("^[A-Za-z_][A-Za-z0-9_.\-]*$", RegexOptions.Compiled)
    Private Shared ReadOnly TokenCodeRegex As New Regex("^[0-9A-F]{48}$", RegexOptions.Compiled)

    Public Const MaxRows As Integer = 200000
    Public Const MaxBytes As Long = 262144000L
    Public Const MaxSeconds As Integer = 120

    Private Shared ReadOnly KnownTokens As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "<br>", "Aliquota", "CampoVuoto1", "CampoVuoto2", "CampoVuoto3", "Categoria", "CategoriaPercorso", "Codice", "Comparatore",
        "Condizione", "CostoSpedizioneProdo", "Descrizione1", "Descrizione2", "DescrizioneHtml", "DescrizioneLunga", "DescrizioneLungaHtml",
        "Descrizione_Garanzia", "Disponibilita", "Ean", "Giacenza", "GiorniSpedizione", "Gruppo", "GruppiDesrizione", "id", "IdCategoria",
        "IdGruppo", "IdSettore", "IdSottogruppo", "IdTipologia", "Link", "Marca", "Mesi_Garanzia", "PercenualeSconto", "PercentualeSconto",
        "Peso", "Prezzo", "Prezzo2", "Settore", "SpeseSpedizione", "Tipologia", "UrlImg", "UrlImgBig", "UrlImg2", "UrlImg2Big",
        "UrlImg3", "UrlImg3Big", "UrlImg4", "UrlImg4Big"
    }

    ' ---------- codice del link e nomi dei file ----------

    Public Shared Function IsValidToken(ByVal token As String) As Boolean
        Return Not String.IsNullOrEmpty(token) AndAlso token.Length = 48 AndAlso TokenCodeRegex.IsMatch(token)
    End Function

    Public Shared Function NormalizeFormat(ByVal tipo As String) As String
        Dim t As String = NZ(tipo).Trim().ToLowerInvariant()
        If t = "csv" OrElse t = "tsv" OrElse t = "xml" OrElse t = "txt" Then Return t
        Return "txt"
    End Function

    Public Shared Function FileName(ByVal scope As String, ByVal exportId As Integer, ByVal token As String, ByVal format As String) As String
        Return scope & "-" & exportId.ToString(Invariant) & "-" & token & "." & NormalizeFormat(format)
    End Function

    ' Vero se il nome e un file pronto di QUESTO feed (stessa installazione e stesso id) diverso da quello attuale.
    Public Shared Function IsStaleFileOf(ByVal name As String, ByVal scope As String, ByVal exportId As Integer, ByVal currentName As String) As Boolean
        If String.IsNullOrEmpty(name) OrElse String.Equals(name, currentName, StringComparison.OrdinalIgnoreCase) Then Return False
        Dim pattern As String = "^" & Regex.Escape(scope & "-" & exportId.ToString(Invariant) & "-") & "[0-9A-F]{48}\.(txt|csv|tsv|xml)$"
        Return Regex.IsMatch(name, pattern, RegexOptions.IgnoreCase)
    End Function

    Public Shared Function ContentType(ByVal format As String, ByVal encodingName As String) As String
        Dim mime As String
        Select Case NormalizeFormat(format)
            Case "csv" : mime = "text/csv"
            Case "tsv" : mime = "text/tab-separated-values"
            Case "xml" : mime = "application/xml"
            Case Else : mime = "text/plain"
        End Select
        Dim charset As String = If(NormalizeFormat(format) = "xml", "utf-8", NZ(encodingName).Trim().ToLowerInvariant())
        Return mime & "; charset=" & charset
    End Function

    Public Shared Function WeakETag(ByVal lastWriteTicks As Long, ByVal length As Long) As String
        Return "W/""" & lastWriteTicks.ToString("x", Invariant) & "-" & length.ToString("x", Invariant) & """"
    End Function

    ' ---------- codifica ----------

    Public Shared Function ResolveEncoding(ByVal name As String) As Encoding
        Select Case NZ(name).Trim().ToLowerInvariant()
            Case "utf-8", "utf8"
                Return New UTF8Encoding(False)
            Case "iso-8859-1", "latin1"
                Return Encoding.GetEncoding(28591, New EncoderReplacementFallback("?"), DecoderFallback.ReplacementFallback)
            Case "windows-1252", "cp1252"
                Return Encoding.GetEncoding(1252, New EncoderReplacementFallback("?"), DecoderFallback.ReplacementFallback)
            Case Else
                Return Nothing
        End Select
    End Function

    ' ---------- validazione della configurazione: codice dell'errore, vuoto se tutto e coerente ----------

    Public Shared Function Validate(ByVal opts As KeepStoreFeedOptions, ByVal columns As IList(Of KeepStoreFeedColumn)) As String
        If opts Is Nothing OrElse columns Is Nothing OrElse columns.Count = 0 Then Return "COLONNE_ASSENTI"
        Dim fmt As String = NormalizeFormat(opts.Format)
        If ResolveEncoding(opts.EncodingName) Is Nothing Then Return "CODIFICA_NON_AMMESSA"
        If opts.DecimalSeparator <> "." AndAlso opts.DecimalSeparator <> "," Then Return "SEPARATORE_DECIMALE_NON_AMMESSO"
        If fmt <> "xml" Then
            Dim sep As String = EffectiveSeparator(opts)
            If sep.Length <> 1 AndAlso sep.Length <> 2 Then Return "SEPARATORE_NON_AMMESSO"
            If sep = opts.DecimalSeparator AndAlso String.IsNullOrEmpty(opts.TextDelimiter) Then Return "CONFIG_SEPARATORE_DECIMALE"
            If sep = opts.TextDelimiter Then Return "SEPARATORE_UGUALE_DELIMITATORE"
            If Not String.IsNullOrEmpty(opts.TextDelimiter) AndAlso opts.TextDelimiter.Length <> 1 Then Return "DELIMITATORE_NON_AMMESSO"
        Else
            If Not IsValidXmlName(opts.XmlRoot) OrElse Not IsValidXmlName(opts.XmlElement) Then Return "NOME_XML_NON_VALIDO"
            For Each col As KeepStoreFeedColumn In columns
                If Not IsValidXmlName(col.Title) Then Return "NOME_XML_NON_VALIDO"
            Next
        End If
        For Each col As KeepStoreFeedColumn In columns
            Dim unknown As String = UnknownToken(col.Source)
            If unknown <> "" Then Return "CAMPO_SCONOSCIUTO"
        Next
        Return ""
    End Function

    Public Shared Function EffectiveSeparator(ByVal opts As KeepStoreFeedOptions) As String
        If NormalizeFormat(opts.Format) = "tsv" Then Return vbTab
        Return NZ(opts.Separator)
    End Function

    Public Shared Function IsValidXmlName(ByVal name As String) As Boolean
        If String.IsNullOrEmpty(name) OrElse name.Length > 60 Then Return False
        If name.StartsWith("xml", StringComparison.OrdinalIgnoreCase) Then Return False
        Return XmlNameRegex.IsMatch(name)
    End Function

    ' Primo campo #Nome# non riconosciuto di un modello, vuoto se tutti sono noti.
    Public Shared Function UnknownToken(ByVal source As String) As String
        If String.IsNullOrEmpty(source) Then Return ""
        For Each m As Match In TokenRegex.Matches(source)
            If Not KnownTokens.Contains(m.Groups(1).Value) Then Return m.Groups(1).Value
        Next
        Return ""
    End Function

    ' ---------- feed senza colonne libere: l'elenco del formato storico #Campo#|#Campo# ----------

    Public Shared Function ParseLegacyFormat(ByVal formatString As String) As List(Of KeepStoreFeedColumn)
        Dim result As New List(Of KeepStoreFeedColumn)()
        If String.IsNullOrWhiteSpace(formatString) Then Return result
        For Each segment As String In formatString.Split("|"c)
            Dim s As String = segment.Trim()
            If s.Length = 0 Then Continue For
            Dim col As New KeepStoreFeedColumn()
            col.Source = s
            Dim title As String = s.Replace("#", "")
            If String.Equals(title, "Descrizione1", StringComparison.OrdinalIgnoreCase) Then title = "Titolo"
            col.Title = title
            result.Add(col)
        Next
        Return result
    End Function

    ' ---------- testo ----------

    ' Una sola riga: controlli e a-capo diventano spazio, spazi compressi; con stripTags tolti i tag HTML e decodificate le entita.
    Public Shared Function CleanText(ByVal raw As String, ByVal stripTags As Boolean) As String
        If String.IsNullOrEmpty(raw) Then Return ""
        Dim text As String = raw
        If stripTags Then
            text = TagRegex.Replace(text, " ")
            text = WebUtility.HtmlDecode(text)
        End If
        Dim sb As New StringBuilder(text.Length)
        For Each ch As Char In text
            If Char.IsControl(ch) Then
                sb.Append(" "c)
            Else
                sb.Append(ch)
            End If
        Next
        Return SpaceRegex.Replace(sb.ToString(), " ").Trim()
    End Function

    ' Caratteri ammessi da XML 1.0 (le coppie surrogate valide passano).
    Public Shared Function StripInvalidXmlChars(ByVal text As String) As String
        If String.IsNullOrEmpty(text) Then Return ""
        Dim sb As New StringBuilder(text.Length)
        Dim i As Integer = 0
        While i < text.Length
            Dim ch As Char = text(i)
            If Char.IsHighSurrogate(ch) AndAlso i + 1 < text.Length AndAlso Char.IsLowSurrogate(text(i + 1)) Then
                sb.Append(ch).Append(text(i + 1))
                i += 2
                Continue While
            End If
            Dim c As Integer = AscW(ch)
            If c = 9 OrElse c = 10 OrElse c = 13 OrElse (c >= &H20 AndAlso c <= &HD7FF) OrElse (c >= &HE000 AndAlso c <= &HFFFD) Then sb.Append(ch)
            i += 1
        End While
        Return sb.ToString()
    End Function

    Private Shared Function Truncate(ByVal text As String, ByVal maxChars As Integer) As String
        If maxChars <= 0 OrElse String.IsNullOrEmpty(text) OrElse text.Length <= maxChars Then Return text
        Dim cut As String = text.Substring(0, maxChars)
        If cut.Length > 0 AndAlso Char.IsHighSurrogate(cut(cut.Length - 1)) Then cut = cut.Substring(0, cut.Length - 1)
        Return cut.TrimEnd()
    End Function

    Private Shared Function CapitalizeLower(ByVal text As String) As String
        If String.IsNullOrEmpty(text) Then Return ""
        Dim lower As String = text.ToLowerInvariant()
        Return lower.Substring(0, 1).ToUpperInvariant() & lower.Substring(1)
    End Function

    Public Shared Function HttpsUrl(ByVal url As String) As String
        If String.IsNullOrEmpty(url) Then Return ""
        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) Then Return "https://" & url.Substring(7)
        Return url
    End Function

    ' ---------- numeri ----------

    Public Shared Function FormatMoney(ByVal value As Decimal, ByVal decimalSeparator As String) As String
        Dim rounded As Decimal = Math.Round(value, 2, MidpointRounding.AwayFromZero)
        Return rounded.ToString("0.00", Invariant).Replace(".", decimalSeparator)
    End Function

    Public Shared Function FormatNumber(ByVal value As Decimal, ByVal decimalSeparator As String) As String
        Return value.ToString("0.###", Invariant).Replace(".", decimalSeparator)
    End Function

    ' Importo (spedizione) come lo scrive il feed: senza IVA oppure con l'IVA del vettore.
    Public Shared Function MoneyWithTax(ByVal net As Decimal, ByVal includeTax As Boolean, ByVal carrierVat As Decimal, ByVal decimalSeparator As String) As String
        If includeTax Then Return FormatMoney(net * (1D + carrierVat / 100D), decimalSeparator)
        Return FormatMoney(net, decimalSeparator)
    End Function

    ' ---------- spedizione ----------

    ' Spedizione gratis: il listino e uno dei codici ESATTI dell'elenco "1;2;" e oggi e dentro il periodo (come il carrello; il vecchio LIKE riconosceva 11; per 1).
    Public Shared Function IsFreeShipping(ByVal lists As String, ByVal listino As Integer, ByVal startsOn As Nullable(Of Date),
                                          ByVal endsOn As Nullable(Of Date), ByVal today As Date) As Boolean
        If String.IsNullOrWhiteSpace(lists) OrElse Not startsOn.HasValue OrElse Not endsOn.HasValue Then Return False
        If today.Date < startsOn.Value.Date OrElse today.Date > endsOn.Value.Date Then Return False
        For Each part As String In lists.Split(";"c)
            Dim n As Integer
            If Integer.TryParse(part.Trim(), NumberStyles.Integer, Invariant, n) AndAlso n = listino Then Return True
        Next
        Return False
    End Function

    ' Fasce del vettore (ordinate per peso massimo crescente): la prima con peso <= PesoMax; oltre l'ultima nessuna tariffa.
    Public Shared Function ShippingBandCost(ByVal bands As IList(Of KeyValuePair(Of Integer, Decimal)), ByVal weight As Decimal) As Nullable(Of Decimal)
        If bands Is Nothing Then Return Nothing
        For Each band As KeyValuePair(Of Integer, Decimal) In bands
            If weight <= band.Key Then Return band.Value
        Next
        Return Nothing
    End Function

    ' ---------- valore di un campo ----------

    Private Shared Function Words(ByVal row As KeepStoreFeedRow, ByVal opts As KeepStoreFeedOptions) As String
        If row.Stock > 0D Then Return opts.WordAvailable
        If row.Incoming > 0D Then Return opts.WordIncoming
        Return opts.WordUnavailable
    End Function

    Public Shared Function TokenValue(ByVal token As String, ByVal row As KeepStoreFeedRow, ByVal ctx As KeepStoreFeedContext,
                                      ByVal opts As KeepStoreFeedOptions) As String
        Dim dec As String = opts.DecimalSeparator
        Select Case token.ToLowerInvariant()
            Case "<br>" : Return "<br>"
            Case "aliquota" : Return row.VatId.ToString(Invariant)
            Case "campovuoto1", "campovuoto2", "campovuoto3", "comparatore" : Return ""
            Case "categoria" : Return CleanText(row.CategoryName, False)
            Case "categoriapercorso"
                Dim parts As New List(Of String)()
                For Each p As String In New String() {row.SectorName, row.CategoryName, row.TypeName, row.GroupName}
                    Dim c As String = CleanText(p, False)
                    If c.Length > 0 Then parts.Add(c)
                Next
                Return String.Join(" > ", parts.ToArray())
            Case "codice" : Return CleanText(row.Code, False)
            Case "condizione" : Return If(row.Refurbished = 1, "RICONDIZIONATO", "NUOVO")
            Case "costospedizioneprodo" : Return row.ShippingCost
            Case "descrizione1"
                Dim t As String = CleanText(row.Title1, False)
                Return If(opts.LowerCaseTitle, CapitalizeLower(t), t)
            Case "descrizione2" : Return CleanText(row.Title2, False)
            Case "descrizionelunga" : Return CleanText(row.LongText, False)
            Case "descrizionehtml", "descrizionelungahtml" : Return CleanText(row.HtmlText, opts.StripHtml)
            Case "descrizione_garanzia" : Return CleanText(row.WarrantyText, False)
            Case "disponibilita" : Return Words(row, opts)
            Case "ean" : Return CleanText(row.Ean, False)
            Case "giacenza" : Return FormatNumber(Math.Max(row.Stock, 0D), ".")
            Case "giornispedizione" : Return ctx.ShippingDays
            Case "gruppo", "gruppidesrizione" : Return CleanText(row.GroupName, False)
            Case "id" : Return row.Id.ToString(Invariant)
            Case "idcategoria" : Return row.CategoryId.ToString(Invariant)
            Case "idgruppo" : Return row.GroupId.ToString(Invariant)
            Case "idsettore" : Return row.SectorId.ToString(Invariant)
            Case "idsottogruppo" : Return row.SubgroupId.ToString(Invariant)
            Case "idtipologia" : Return row.TypeId.ToString(Invariant)
            Case "link" : Return "https://" & ctx.Domain & "/articolo.aspx?id=" & row.Id.ToString(Invariant)
            Case "marca" : Return CleanText(row.Brand, False)
            Case "mesi_garanzia" : Return row.WarrantyMonths
            Case "percenualesconto", "percentualesconto"
                Return If(row.DiscountPercent > 0D, row.DiscountPercent.ToString("0", Invariant), "")
            Case "peso" : Return FormatNumber(row.Weight, dec)
            Case "prezzo" : Return FormatMoney(row.Price, dec)
            Case "prezzo2" : Return If(row.Price2.HasValue, FormatMoney(row.Price2.Value, dec), "")
            Case "settore" : Return CleanText(row.SectorName, False)
            Case "spesespedizione" : Return ctx.ShippingFee
            Case "tipologia" : Return CleanText(row.TypeName, False)
            Case "urlimg" : Return row.ImageUrls(0)
            Case "urlimgbig" : Return row.ImageUrls(1)
            Case "urlimg2" : Return row.ImageUrls(2)
            Case "urlimg2big" : Return row.ImageUrls(3)
            Case "urlimg3" : Return row.ImageUrls(4)
            Case "urlimg3big" : Return row.ImageUrls(5)
            Case "urlimg4" : Return row.ImageUrls(6)
            Case "urlimg4big" : Return row.ImageUrls(7)
            Case Else : Return ""
        End Select
    End Function

    ' Valore della colonna: modello -> se vuoto "SeVuoto" -> troncamento -> prefisso + valore + suffisso (solo se il valore non e vuoto).
    Public Shared Function ColumnValue(ByVal col As KeepStoreFeedColumn, ByVal row As KeepStoreFeedRow, ByVal ctx As KeepStoreFeedContext,
                                       ByVal opts As KeepStoreFeedOptions) As String
        Dim value As String = TokenRegex.Replace(NZ(col.Source), New MatchEvaluator(Function(m As Match) TokenValue(m.Groups(1).Value, row, ctx, opts)))
        If String.IsNullOrWhiteSpace(value) Then value = NZ(col.IfEmpty)
        If String.IsNullOrWhiteSpace(value) Then Return ""
        value = Truncate(value.Trim(), col.MaxChars)
        Return NZ(col.Prefix) & value & NZ(col.Suffix)
    End Function

    ' Motivo dello scarto di un prodotto ("" = si pubblica).
    Public Shared Function SkipReason(ByVal row As KeepStoreFeedRow, ByVal opts As KeepStoreFeedOptions) As String
        If opts.SkipZeroPrice AndAlso row.Price <= 0D Then Return "PREZZO_ZERO"
        If opts.SkipNoEan AndAlso String.IsNullOrWhiteSpace(row.Ean) Then Return "SENZA_EAN"
        If opts.SkipNoImage AndAlso String.IsNullOrEmpty(row.ImageUrls(1)) Then Return "SENZA_IMMAGINE"
        Return ""
    End Function

    ' ---------- righe di testo con separatore ----------

    Public Shared Function DelimitedLine(ByVal values As IList(Of String), ByVal opts As KeepStoreFeedOptions) As String
        Dim sep As String = EffectiveSeparator(opts)
        Dim delim As String = NZ(opts.TextDelimiter)
        Dim sb As New StringBuilder()
        For i As Integer = 0 To values.Count - 1
            If i > 0 Then sb.Append(sep)
            Dim v As String = NZ(values(i))
            If delim.Length > 0 Then
                sb.Append(delim).Append(v.Replace(delim, delim & delim)).Append(delim)
            Else
                sb.Append(v.Replace(sep, " "))
            End If
        Next
        Return sb.ToString()
    End Function
End Class
