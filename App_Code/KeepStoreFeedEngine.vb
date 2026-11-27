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
    Private Shared ReadOnly CommentRegex As New Regex("<!--.*?-->", RegexOptions.Compiled Or RegexOptions.Singleline)
    Private Shared ReadOnly ScriptStyleRegex As New Regex("<(script|style)\b[^>]*>.*?</\1\s*>", RegexOptions.Compiled Or RegexOptions.Singleline Or RegexOptions.IgnoreCase)
    Private Shared ReadOnly RealTagRegex As New Regex("</?[A-Za-z][^<>]*>", RegexOptions.Compiled)
    Private Shared ReadOnly SpaceRegex As New Regex("\s+", RegexOptions.Compiled)
    Private Shared ReadOnly XmlNameRegex As New Regex("^[A-Za-z_][A-Za-z0-9_.\-]*$", RegexOptions.Compiled)
    Private Shared ReadOnly TokenCodeRegex As New Regex("^[0-9A-F]{48}$", RegexOptions.Compiled)

    ' Versione del formato dei file pronti: fa parte dell'impronta (cambiandola si rigenerano tutti).
    Public Const EngineVersion As String = "E3"
    Public Const PreviewTextLines As Integer = 20
    Public Const PreviewXmlLines As Integer = 80
    Public Const PreviewMaxBytes As Integer = 32768

    Public Const MaxRows As Integer = 200000
    Public Const MaxBytes As Long = 262144000L
    Public Const MaxSeconds As Integer = 120

    Private Shared ReadOnly KnownTokens As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        "<br>", "Aliquota", "CampoVuoto1", "CampoVuoto2", "CampoVuoto3", "Categoria", "CategoriaPercorso", "Codice", "Comparatore",
        "Condizione", "CostoSpedizioneProdo", "Descrizione1", "Descrizione2", "DescrizioneHtml", "DescrizioneLunga", "DescrizioneLungaHtml",
        "Descrizione_Garanzia", "Disponibilita", "Ean", "Giacenza", "GiorniSpedizione", "Gruppo", "GruppiDesrizione", "id", "IdCategoria",
        "IdGruppo", "IdSettore", "IdSottogruppo", "IdTipologia", "Link", "Marca", "Mesi_Garanzia", "PercenualeSconto", "PercentualeSconto",
        "Peso", "Prezzo", "Prezzo2", "Settore", "SpeseSpedizione", "Tipologia", "UrlImg", "UrlImgBig", "UrlImg2", "UrlImg2Big",
        "UrlImg3", "UrlImg3Big", "UrlImg4", "UrlImg4Big",
        "CondizioneInglese", "EanValido", "DescrizioneSoloTesto", "TitoloNormalizzato"
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

    ' Il nome porta l'impronta della configurazione (azienda, listino, opzioni, colonne, filtri, giorno): una modifica nel gestionale cambia il nome, quindi il file
    ' di una configurazione diversa non si serve mai.
    Public Shared Function FileName(ByVal scope As String, ByVal exportId As Integer, ByVal token As String, ByVal format As String, ByVal fingerprint As String) As String
        Return scope & "-" & exportId.ToString(Invariant) & "-" & token & "-" & fingerprint & "." & NormalizeFormat(format)
    End Function

    ' SHA-256 di un testo canonico: ogni parte con la sua lunghezza (nessuna ambiguita fra "ab"+"c" e "a"+"bc"); 12 caratteri esadecimali minuscoli.
    Public Shared Function Fingerprint(ByVal parts As IList(Of String)) As String
        Dim sb As New StringBuilder()
        For Each p As String In parts
            Dim v As String = NZ(p)
            sb.Append(v.Length.ToString(Invariant)).Append(":"c).Append(v).Append(";"c)
        Next
        Using sha As System.Security.Cryptography.SHA256 = System.Security.Cryptography.SHA256.Create()
            Dim hash As Byte() = sha.ComputeHash(Encoding.UTF8.GetBytes(sb.ToString()))
            Dim hex As New StringBuilder()
            For i As Integer = 0 To 5
                hex.Append(hash(i).ToString("x2", Invariant))
            Next
            Return hex.ToString()
        End Using
    End Function

    ' Anteprima: le prime righe del testo letto dalla testa del file. Se la lettura e stata tagliata in byte, l'ultima riga (forse incompleta) si scarta.
    Public Shared Function PreviewText(ByVal text As String, ByVal maxLines As Integer, ByVal cutByBytes As Boolean) As String
        Dim lines As New List(Of String)(NZ(text).Replace(vbCrLf, vbLf).Split(ControlChars.Lf))
        ' L'ultimo elemento e vuoto se il testo finisce con un a-capo, parziale se la lettura e stata tagliata: in entrambi i casi non e una riga completa.
        If lines.Count > 0 AndAlso (cutByBytes OrElse lines(lines.Count - 1).Length = 0) Then lines.RemoveAt(lines.Count - 1)
        If lines.Count > maxLines Then lines.RemoveRange(maxLines, lines.Count - maxLines)
        Return String.Join(vbCrLf, lines.ToArray())
    End Function

    ' Vero se il nome e un file pronto di QUESTO feed (stessa installazione e stesso id) diverso da quello attuale.
    Public Shared Function IsStaleFileOf(ByVal name As String, ByVal scope As String, ByVal exportId As Integer, ByVal currentName As String) As Boolean
        If String.IsNullOrEmpty(name) OrElse String.Equals(name, currentName, StringComparison.OrdinalIgnoreCase) Then Return False
        Dim pattern As String = "^" & Regex.Escape(scope & "-" & exportId.ToString(Invariant) & "-") & "[0-9A-F]{48}(-[0-9a-f]{12})?\.(txt|csv|tsv|xml)$"
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

    ' Testo semplice di un testo con HTML (GOOGLE-MERCHANT-CENTER-FEED-1A). Ordine: si decodificano le entita (una sola volta), si tolgono commenti, script e stile CON il loro
    ' contenuto, poi i soli tag veri (< seguito da una lettera o da /): "5 < 10 > 3" e "<2kg" non sono tag. Una riga, spazi compressi.
    Public Shared Function PlainText(ByVal raw As String) As String
        If String.IsNullOrEmpty(raw) Then Return ""
        Dim text As String = WebUtility.HtmlDecode(raw)
        text = CommentRegex.Replace(text, " ")
        text = ScriptStyleRegex.Replace(text, " ")
        text = RealTagRegex.Replace(text, " ")
        Return CleanText(text, False)
    End Function

    ' GTIN valido secondo le regole GS1 richieste da Google: 8, 12, 13 o 14 cifre senza spazi ne trattini, cifra di controllo corretta, non tutto zero,
    ' non limitato (prefissi 02, 04, 2) ne coupon (98, 99), valutati sul codice a 13 cifre (12 cifre = 0 + codice, 14 cifre = senza la prima). Vuoto se non valido.
    Public Shared Function ValidGtin(ByVal raw As String) As String
        If raw Is Nothing Then Return ""
        Dim s As String = raw.Trim()
        Dim n As Integer = s.Length
        If n <> 8 AndAlso n <> 12 AndAlso n <> 13 AndAlso n <> 14 Then Return ""
        For Each ch As Char In s
            If ch < "0"c OrElse ch > "9"c Then Return ""
        Next
        If s.Trim("0"c).Length = 0 Then Return ""
        Dim sum As Integer = 0
        For i As Integer = 0 To n - 2
            Dim d As Integer = AscW(s(i)) - AscW("0"c)
            Dim fromRight As Integer = n - 1 - i
            sum += d * If(fromRight Mod 2 = 1, 3, 1)
        Next
        Dim check As Integer = (10 - (sum Mod 10)) Mod 10
        If check <> AscW(s(n - 1)) - AscW("0"c) Then Return ""
        If n > 8 Then
            Dim ean13 As String = s
            If n = 12 Then ean13 = "0" & s
            If n = 14 Then ean13 = s.Substring(1)
            Dim p2 As String = ean13.Substring(0, 2)
            If p2 = "02" OrElse p2 = "04" OrElse p2 = "98" OrElse p2 = "99" OrElse ean13(0) = "2"c Then Return ""
        End If
        Return s
    End Function

    ' Titolo per i destinatari che non ammettono il tutto maiuscolo (FEED-TITLES-1B). Il testo e ripulito (CleanText) e le virgolette sono sistemate SEMPRE: un pollice (virgoletta
    ' subito dopo una cifra) diventa U+2033 se il file e xml o utf-8 (altrimenti resta com'e: nessun punto interrogativo), le altre sono citazioni e diventano virgolette basse a coppie (U+00AB e U+00BB), oppure
    ' tutte apostrofo se sono in numero dispari. Poi, SOLO se il titolo e "urlato", ogni parola senza cifre si ricompone per segmenti (spazio, trattino, barra): un segmento tutto
    ' maiuscolo diventa maiuscola sulla prima LETTERA e resto minuscolo; un segmento con una minuscola resta; le parole con cifre (codici modello) restano intere. Regola solo strutturale.
    Public Shared Function NormalizeTitle(ByVal raw As String, ByVal primeAllowed As Boolean) As String
        Dim t As String = FixTitleQuotes(CleanText(raw, False), primeAllowed)
        If t.Length = 0 OrElse Not IsShoutingTitle(t) Then Return t
        Dim words As String() = t.Split(" "c)
        For i As Integer = 0 To words.Length - 1
            If words(i).Length > 0 AndAlso Not HasDigit(words(i)) Then words(i) = CapitalizeSegments(words(i))
        Next
        Return String.Join(" ", words)
    End Function

    ' Il primo doppio (U+2033) esiste solo in utf-8 e in xml (sempre utf-8): in iso-8859-1 e windows-1252 uscirebbe come punto interrogativo.
    Private Shared Function PrimeAllowed(ByVal opts As KeepStoreFeedOptions) As Boolean
        If NormalizeFormat(opts.Format) = "xml" Then Return True
        Dim enc As Encoding = ResolveEncoding(opts.EncodingName)
        Return enc IsNot Nothing AndAlso enc.CodePage = 65001
    End Function

    Private Shared Function HasDigit(ByVal word As String) As Boolean
        For Each ch As Char In word
            If Char.IsDigit(ch) Then Return True
        Next
        Return False
    End Function

    ' Urlato = nessuna lettera minuscola, oppure maiuscole/(maiuscole+minuscole) >= 0,6 contando solo le parole (separate da spazio) senza cifre e con almeno 5 lettere:
    ' le sigle corte (USB, HDMI, SSD) e i codici con cifre non pesano. Aritmetica intera: nessun confronto in virgola mobile sul confine.
    Private Shared Function IsShoutingTitle(ByVal t As String) As Boolean
        Dim anyLower As Boolean = False
        For Each ch As Char In t
            If Char.IsLower(ch) Then
                anyLower = True
                Exit For
            End If
        Next
        If Not anyLower Then Return True
        Dim up As Integer = 0
        Dim lo As Integer = 0
        For Each w As String In t.Split(" "c)
            If w.Length = 0 OrElse HasDigit(w) Then Continue For
            Dim letters As Integer = 0
            Dim wu As Integer = 0
            Dim wl As Integer = 0
            For Each ch As Char In w
                If Char.IsLetter(ch) Then
                    letters += 1
                    If Char.IsUpper(ch) Then
                        wu += 1
                    ElseIf Char.IsLower(ch) Then
                        wl += 1
                    End If
                End If
            Next
            If letters >= 5 Then
                up += wu
                lo += wl
            End If
        Next
        Return up + lo > 0 AndAlso up * 10 >= (up + lo) * 6
    End Function

    Private Shared Function CapitalizeSegments(ByVal word As String) As String
        Dim sb As New StringBuilder(word.Length)
        Dim seg As New StringBuilder()
        For Each ch As Char In word
            If ch = "-"c OrElse ch = "/"c Then
                sb.Append(CapitalizeSegment(seg.ToString())).Append(ch)
                seg.Length = 0
            Else
                seg.Append(ch)
            End If
        Next
        sb.Append(CapitalizeSegment(seg.ToString()))
        Return sb.ToString()
    End Function

    ' Un segmento con almeno una maiuscola e nessuna minuscola diventa minuscolo con la maiuscola sulla prima lettera (non sul primo carattere: "(NERO" diventa "(Nero").
    Private Shared Function CapitalizeSegment(ByVal seg As String) As String
        Dim hasUpper As Boolean = False
        For Each ch As Char In seg
            If Char.IsLower(ch) Then Return seg
            If Char.IsUpper(ch) Then hasUpper = True
        Next
        If Not hasUpper Then Return seg
        Dim lower As String = seg.ToLowerInvariant()
        For k As Integer = 0 To lower.Length - 1
            If Char.IsLetter(lower(k)) Then Return lower.Substring(0, k) & Char.ToUpperInvariant(lower(k)) & lower.Substring(k + 1)
        Next
        Return lower
    End Function

    Private Shared Function FixTitleQuotes(ByVal t As String, ByVal primeAllowed As Boolean) As String
        If t.IndexOf(""""c) < 0 Then Return t
        Dim cites As Integer = 0
        For i As Integer = 0 To t.Length - 1
            If t(i) = """"c AndAlso Not (i > 0 AndAlso Char.IsDigit(t(i - 1))) Then cites += 1
        Next
        Dim paired As Boolean = (cites Mod 2 = 0)
        Dim opening As Boolean = True
        Dim sb As New StringBuilder(t.Length)
        For i As Integer = 0 To t.Length - 1
            Dim ch As Char = t(i)
            If ch <> """"c Then
                sb.Append(ch)
            ElseIf i > 0 AndAlso Char.IsDigit(t(i - 1)) Then
                sb.Append(If(primeAllowed, ChrW(&H2033), ch))
            ElseIf paired Then
                sb.Append(If(opening, ChrW(&HAB), ChrW(&HBB)))
                opening = Not opening
            Else
                sb.Append("'"c)
            End If
        Next
        Return sb.ToString()
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
            Case "condizioneinglese" : Return If(row.Refurbished = 1, "refurbished", "new")
            Case "eanvalido" : Return ValidGtin(row.Ean)
            Case "descrizionesolotesto" : Return PlainText(row.LongText)
            Case "titolonormalizzato" : Return NormalizeTitle(row.Title1, PrimeAllowed(opts))
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
