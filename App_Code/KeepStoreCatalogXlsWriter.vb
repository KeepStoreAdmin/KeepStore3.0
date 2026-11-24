Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports Hs = NPOI.HSSF.UserModel
Imports Ss = NPOI.SS.UserModel

' Listino e offerte in Excel (CATALOG-DOWNLOAD-1B), formato .xls (HSSF, NPOI 1.2.3). Legge SOLO lo snapshot gia risolto (stessi prezzi, offerte, IVA e
' disponibilita del PDF): nessun secondo calcolo. Cartella di lavoro: foglio "Indice" (dati azienda, nota sui prezzi, legenda, collegamenti ai settori),
' un foglio per settore (foto, codice con collegamento alla scheda, EAN, descrizione, disponibilita, prezzo, prezzo di listino, offerta, note; righe di
' titolo categoria/tipologia/gruppo senza celle unite, raggruppate per categoria) e un foglio "Elenco" piatto e ordinabile (senza foto).
' Limiti HSSF rispettati: nome foglio <= 31 caratteri senza []:*?/\ e unico, meno di 4.000 stili (si creano per ruolo e settore, mai per riga),
' foto piccole (80 px) incorporate una sola volta per file. Le celle di testo sono sempre stringhe (mai formule).
Public NotInheritable Class CatalogXlsWriter
    Private Sub New()
    End Sub

    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
    Private Const ResizeBudgetSeconds As Integer = 120
    Private Const MaxArticlesPerSheet As Integer = 12000
    Private Const MaxSheetNameLength As Integer = 28
    Private Const PhotoRowPoints As Single = 62.0F
    Private Const PhotoColumnPixels As Integer = 96
    Private Const PhotoRowPixels As Integer = 82
    Private Const ColumnCount As Integer = 9
    Private Const SectorColorBase As Short = 32S
    Private Const ColorOk As Short = 48S
    Private Const ColorLow As Short = 49S
    Private Const ColorKo As Short = 50S
    Private Const ColorInk As Short = 8S
    Private Const ColorWhite As Short = 9S
    Private Const ColorLink As Short = 12S
    Private Const ColorGrey As Short = 22S
    Private Const ColorMuted As Short = 23S
    Private Const ColorPale As Short = 26S

    ' ---- Contesto di costruzione ---------------------------------------------------------------------------------------------------------------

    Private NotInheritable Class Ctx
        Public ReadOnly Wb As Hs.HSSFWorkbook
        Public ReadOnly Fonts As New Dictionary(Of String, Ss.Font)(StringComparer.Ordinal)
        Public ReadOnly Styles As New Dictionary(Of String, Ss.CellStyle)(StringComparer.Ordinal)
        Public ReadOnly Photos As New Dictionary(Of String, Integer)(StringComparer.Ordinal)
        Public ReadOnly UsedNames As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Public ReadOnly Clock As Diagnostics.Stopwatch = Diagnostics.Stopwatch.StartNew()
        Public ReadOnly Money As Short
        Public ReadOnly Text As Short
        Public Sub New()
            Wb = New Hs.HSSFWorkbook()
            Dim fmt As Ss.DataFormat = Wb.CreateDataFormat()
            Money = fmt.GetFormat("#,##0.00")
            Text = fmt.GetFormat("@")
        End Sub
    End Class

    Private NotInheritable Class SectorBlock
        Public Name As String = ""
        Public ColorIndex As Short
        Public ReadOnly Rows As New List(Of CatalogExportRow)()
        Public ReadOnly Sheets As New List(Of Ss.Sheet)()
        Public ReadOnly SheetNames As New List(Of String)()
        Public ReadOnly Chunks As New List(Of List(Of CatalogExportRow))()
    End Class

    ' ---- Punto di ingresso ---------------------------------------------------------------------------------------------------------------------

    Public Shared Function Build(ByVal snapshot As CatalogExportSnapshot) As Byte()
        If snapshot Is Nothing OrElse snapshot.Status <> CatalogExportStatus.Ready Then Throw New InvalidOperationException("SNAPSHOT_NOT_READY")
        Dim c As New Ctx()
        SetupPalette(c.Wb)
        Dim sectors As List(Of SectorBlock) = BuildSectors(snapshot.Rows)

        ' Tutti i fogli si creano prima di riempirli (ordine: Indice, settori nell'ordine del sito, Elenco).
        Dim indexSheet As Ss.Sheet = c.Wb.CreateSheet("Indice")
        c.UsedNames.Add("Indice")
        c.UsedNames.Add("Elenco")
        For Each sector As SectorBlock In sectors
            Dim part As Integer = 0
            For Each chunk As List(Of CatalogExportRow) In sector.Chunks
                part += 1
                Dim wanted As String = If(part = 1, sector.Name, sector.Name & " (" & part.ToString(CultureInfo.InvariantCulture) & ")")
                Dim sheetName As String = UniqueSheetName(c, wanted)
                sector.SheetNames.Add(sheetName)
                sector.Sheets.Add(c.Wb.CreateSheet(sheetName))
            Next
        Next
        Dim listSheet As Ss.Sheet = c.Wb.CreateSheet("Elenco")

        Dim priceNote As String = If(String.IsNullOrWhiteSpace(snapshot.PriceLabel), "Prezzi", snapshot.PriceLabel).TrimStart("*"c).Trim()
        WriteIndex(c, indexSheet, snapshot, sectors, priceNote)
        For Each sector As SectorBlock In sectors
            For i As Integer = 0 To sector.Sheets.Count - 1
                WriteSectorSheet(c, sector, sector.Sheets(i), sector.Chunks(i), priceNote)
            Next
        Next
        WriteList(c, listSheet, snapshot.Rows, priceNote)
        indexSheet.IsSelected = True

        ' Write produce il contenitore OLE2 (.xls vero); GetBytes restituirebbe il solo flusso interno, non apribile.
        Using output As New MemoryStream()
            c.Wb.Write(output)
            Return output.ToArray()
        End Using
    End Function

    ' ---- Struttura dati --------------------------------------------------------------------------------------------------------------------------

    Private Shared Function BuildSectors(ByVal rows As List(Of CatalogExportRow)) As List(Of SectorBlock)
        Dim result As New List(Of SectorBlock)()
        Dim current As SectorBlock = Nothing
        Dim currentKey As String = Nothing
        Dim currentName As String = Nothing
        For Each row As CatalogExportRow In rows
            If current Is Nothing OrElse currentKey <> row.SectorKey OrElse currentName <> row.SectorName Then
                current = New SectorBlock() With {.Name = row.SectorName, .ColorIndex = CShort(SectorColorBase + (result.Count Mod CatalogPdfWriter.SectorColorCount))}
                result.Add(current)
                currentKey = row.SectorKey
                currentName = row.SectorName
            End If
            current.Rows.Add(row)
        Next
        For Each sector As SectorBlock In result
            Dim chunk As List(Of CatalogExportRow) = Nothing
            For Each row As CatalogExportRow In sector.Rows
                If chunk Is Nothing OrElse chunk.Count >= MaxArticlesPerSheet Then
                    chunk = New List(Of CatalogExportRow)()
                    sector.Chunks.Add(chunk)
                End If
                chunk.Add(row)
            Next
        Next
        Return result
    End Function

    ' ---- Nomi dei fogli ------------------------------------------------------------------------------------------------------------------------

    Friend Shared Function SanitizeSheetName(ByVal raw As String) As String
        Dim sb As New StringBuilder()
        For Each ch As Char In If(raw, "")
            If "[]:*?/\".IndexOf(ch) >= 0 OrElse Char.IsControl(ch) Then
                sb.Append(" "c)
            Else
                sb.Append(ch)
            End If
        Next
        Dim name As String = sb.ToString().Trim().Trim("'"c).Trim()
        While name.Contains("  ")
            name = name.Replace("  ", " ")
        End While
        If name.Length > MaxSheetNameLength Then name = name.Substring(0, MaxSheetNameLength).Trim().Trim("'"c).Trim()
        If name.Length = 0 Then name = "Settore"
        Return name
    End Function

    Private Shared Function UniqueSheetName(ByVal c As Ctx, ByVal raw As String) As String
        Dim candidate As String = raw
        candidate = SanitizeSheetName(raw) 'SHEET_SANITIZE
        Dim baseName As String = candidate
        Dim n As Integer = 1
        While c.UsedNames.Contains(candidate)
            n += 1
            Dim suffix As String = " (" & n.ToString(CultureInfo.InvariantCulture) & ")"
            candidate = baseName
            If candidate.Length + suffix.Length > 31 Then candidate = candidate.Substring(0, 31 - suffix.Length).Trim()
            candidate &= suffix
        End While
        c.UsedNames.Add(candidate)
        Return candidate
    End Function

    Private Shared Function SheetRef(ByVal sheetName As String, ByVal cellRef As String) As String
        Return "'" & sheetName.Replace("'", "''") & "'!" & cellRef
    End Function

    ' ---- Palette, font e stili ---------------------------------------------------------------------------------------------------------------

    Private Shared Sub SetupPalette(ByVal wb As Hs.HSSFWorkbook)
        Dim palette As Hs.HSSFPalette = wb.GetCustomPalette()
        For i As Integer = 0 To CatalogPdfWriter.SectorColorCount - 1
            Dim rgb As Integer() = CatalogPdfWriter.SectorColor(i)
            palette.SetColorAtIndex(CShort(SectorColorBase + i), CByte(rgb(0)), CByte(rgb(1)), CByte(rgb(2)))
        Next
        palette.SetColorAtIndex(ColorOk, CByte(34), CByte(160), CByte(72))
        palette.SetColorAtIndex(ColorLow, CByte(240), CByte(176), CByte(0))
        palette.SetColorAtIndex(ColorKo, CByte(214), CByte(40), CByte(40))
    End Sub

    Private Shared Function GetFont(ByVal c As Ctx, ByVal color As Short, ByVal size As Short, ByVal bold As Boolean, Optional ByVal underline As Boolean = False, Optional ByVal strike As Boolean = False) As Ss.Font
        Dim key As String = color.ToString(CultureInfo.InvariantCulture) & "|" & size.ToString(CultureInfo.InvariantCulture) & "|" & bold.ToString() & "|" & underline.ToString() & "|" & strike.ToString()
        Dim font As Ss.Font = Nothing
        If c.Fonts.TryGetValue(key, font) Then Return font
        font = c.Wb.CreateFont()
        font.FontName = "Arial"
        font.Color = color
        font.FontHeightInPoints = size
        font.Boldweight = CShort(If(bold, 700, 400))
        If underline Then font.Underline = CByte(1)
        font.IsStrikeout = strike
        c.Fonts(key) = font
        Return font
    End Function

    Private Shared Function GetStyle(ByVal c As Ctx, ByVal font As Ss.Font, ByVal fill As Short, ByVal horizontal As Ss.HorizontalAlignment, ByVal vertical As Ss.VerticalAlignment,
                                     ByVal wrap As Boolean, ByVal format As Short, ByVal border As Boolean) As Ss.CellStyle
        Dim key As String = font.Color.ToString(CultureInfo.InvariantCulture) & "|" & font.FontHeightInPoints.ToString(CultureInfo.InvariantCulture) & "|" &
            font.Boldweight.ToString(CultureInfo.InvariantCulture) & "|" & font.Underline.ToString(CultureInfo.InvariantCulture) & "|" & font.IsStrikeout.ToString() & "|" &
            fill.ToString(CultureInfo.InvariantCulture) & "|" & horizontal.ToString() & "|" & vertical.ToString() & "|" & wrap.ToString() & "|" & format.ToString(CultureInfo.InvariantCulture) & "|" & border.ToString()
        Dim style As Ss.CellStyle = Nothing
        If c.Styles.TryGetValue(key, style) Then Return style
        style = c.Wb.CreateCellStyle()
        style.SetFont(font)
        If fill >= 0S Then
            style.FillForegroundColor = fill
            style.FillPattern = Ss.FillPatternType.SOLID_FOREGROUND
        End If
        style.Alignment = horizontal
        style.VerticalAlignment = vertical
        style.WrapText = wrap
        If format > 0S Then style.DataFormat = format
        If border Then
            style.BorderBottom = Ss.CellBorderType.HAIR
            style.BottomBorderColor = ColorGrey
        End If
        c.Styles(key) = style
        Return style
    End Function

    Private Shared Function Body(ByVal c As Ctx, Optional ByVal bold As Boolean = False, Optional ByVal wrap As Boolean = True, Optional ByVal format As Short = 0S) As Ss.CellStyle
        Return GetStyle(c, GetFont(c, ColorInk, 9S, bold), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, wrap, format, True)
    End Function

    ' ---- Utilita di cella ----------------------------------------------------------------------------------------------------------------------

    Private Shared Function PutText(ByVal row As Ss.Row, ByVal col As Integer, ByVal value As String, ByVal style As Ss.CellStyle) As Ss.Cell
        Dim cell As Ss.Cell = row.CreateCell(col)
        cell.SetCellValue(If(value, ""))
        cell.CellStyle = style
        Return cell
    End Function

    Private Shared Sub PutBlank(ByVal row As Ss.Row, ByVal col As Integer, ByVal style As Ss.CellStyle)
        Dim cell As Ss.Cell = row.CreateCell(col)
        cell.CellStyle = style
    End Sub

    Private Shared Sub PutUrlLink(ByVal cell As Ss.Cell, ByVal url As String)
        Dim link As New Hs.HSSFHyperlink(Ss.HyperlinkType.URL)
        link.Address = url
        cell.Hyperlink = link
    End Sub

    Private Shared Sub PutSheetLink(ByVal cell As Ss.Cell, ByVal sheetName As String, ByVal cellRef As String)
        Dim link As New Hs.HSSFHyperlink(Ss.HyperlinkType.DOCUMENT)
        link.Address = SheetRef(sheetName, cellRef)
        cell.Hyperlink = link
    End Sub

    Private Shared Function WidthUnits(ByVal chars As Double) As Integer
        Return CInt(Math.Min(255.0R, Math.Max(2.0R, chars)) * 256.0R)
    End Function

    Private Shared Function LineCount(ByVal text As String, ByVal charsPerLine As Integer) As Integer
        If String.IsNullOrEmpty(text) Then Return 1
        Dim total As Integer = 0
        For Each part As String In text.Split(New Char() {ChrW(10)})
            total += Math.Max(1, CInt(Math.Ceiling(part.Length / CDbl(charsPerLine))))
        Next
        Return Math.Max(1, total)
    End Function

    Private Shared Function ToDouble(ByVal value As Decimal) As Double
        Return CDbl(value)
    End Function

    ' ---- Foto ----------------------------------------------------------------------------------------------------------------------------------------

    Private Shared Function FindPhoto(ByVal c As Ctx, ByVal row As CatalogExportRow) As CatalogExportPhoto
        If row.ImageFiles Is Nothing Then Return Nothing
        Dim allowResize As Boolean = c.Clock.Elapsed.TotalSeconds < ResizeBudgetSeconds
        For Each candidate As String In row.ImageFiles
            Dim photo As CatalogExportPhoto = CatalogExportImages.LoadSheetPhoto(candidate, allowResize)
            If photo IsNot Nothing Then Return photo
        Next
        Return Nothing
    End Function

    ' Inserisce la foto, centrata nella cella della colonna 0, sulla riga r (stesso indice della riga dell'articolo).
    Private Shared Sub PlacePhoto(ByVal c As Ctx, ByVal patriarch As Ss.Drawing, ByVal photo As CatalogExportPhoto, ByVal r As Integer)
        Dim pictureIndex As Integer = 0
        If Not c.Photos.TryGetValue(photo.Key, pictureIndex) Then
            pictureIndex = c.Wb.AddPicture(photo.Bytes, Ss.PictureType.JPEG)
            c.Photos(photo.Key) = pictureIndex
        End If
        Dim w As Integer = Math.Min(photo.Width, PhotoColumnPixels - 6)
        Dim h As Integer = Math.Min(photo.Height, PhotoRowPixels - 6)
        Dim dx1 As Integer = CInt((PhotoColumnPixels - w) / 2.0R / PhotoColumnPixels * 1023.0R)
        Dim dy1 As Integer = CInt((PhotoRowPixels - h) / 2.0R / PhotoRowPixels * 255.0R)
        Dim dx2 As Integer = Math.Min(1023, dx1 + CInt(w / CDbl(PhotoColumnPixels) * 1023.0R))
        Dim dy2 As Integer = Math.Min(255, dy1 + CInt(h / CDbl(PhotoRowPixels) * 255.0R))
        Dim anchorRow As Integer = r 'PHOTO_ROW
        Dim anchor As New Hs.HSSFClientAnchor(dx1, dy1, dx2, dy2, 0, anchorRow, 0, anchorRow)
        patriarch.CreatePicture(anchor, pictureIndex)
    End Sub

    ' ---- Foglio Indice -------------------------------------------------------------------------------------------------------------------------

    Private Shared Sub WriteIndex(ByVal c As Ctx, ByVal sheet As Ss.Sheet, ByVal snapshot As CatalogExportSnapshot, ByVal sectors As List(Of SectorBlock), ByVal priceNote As String)
        sheet.DisplayGridlines = False
        sheet.SetColumnWidth(0, WidthUnits(40))
        sheet.SetColumnWidth(1, WidthUnits(46))
        sheet.SetColumnWidth(2, WidthUnits(18))
        sheet.SetColumnWidth(3, WidthUnits(18))
        Dim info As CatalogExportCompany = snapshot.Company
        Dim company As String = If(info IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(info.Name), info.Name, If(String.IsNullOrWhiteSpace(snapshot.CompanyName), "KeepStore", snapshot.CompanyName))
        Dim dateText As String = snapshot.GeneratedOn.ToString("dd/MM/yyyy", ItCulture)
        Dim patriarch As Ss.Drawing = sheet.CreateDrawingPatriarch()

        Dim r As Integer = 0
        Dim logoRow As Ss.Row = sheet.CreateRow(r)
        logoRow.HeightInPoints = 54.0F
        Dim logoBytes As Byte() = Nothing
        If info IsNot Nothing AndAlso Not String.IsNullOrEmpty(info.LogoFile) Then logoBytes = CatalogExportImages.LoadLogo(info.LogoFile)
        If logoBytes IsNot Nothing Then
            Try
                Dim lw As Integer = 0
                Dim lh As Integer = 0
                Using ms As New MemoryStream(logoBytes)
                    Using img As System.Drawing.Image = System.Drawing.Image.FromStream(ms, False, False)
                        lw = img.Width
                        lh = img.Height
                    End Using
                End Using
                If lw > 0 AndAlso lh > 0 Then
                    Dim scale As Double = Math.Min(260.0R / lw, 64.0R / lh)
                    Dim pw As Integer = Math.Max(1, CInt(lw * scale))
                    Dim ph As Integer = Math.Max(1, CInt(lh * scale))
                    Dim colPx As Double = 40.0R * 7.0R + 5.0R
                    Dim rowPx As Double = 54.0R * 96.0R / 72.0R
                    Dim pictureIndex As Integer = c.Wb.AddPicture(logoBytes, Ss.PictureType.JPEG)
                    Dim x2 As Integer = Math.Min(1023, CInt(pw / colPx * 1023.0R))
                    Dim y2 As Integer = Math.Min(255, CInt(ph / rowPx * 255.0R))
                    patriarch.CreatePicture(New Hs.HSSFClientAnchor(0, 0, x2, y2, 0, r, 0, r), pictureIndex)
                End If
            Catch
            End Try
        End If
        r += 1
        Dim nameStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorInk, 20S, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False)
        Dim nameRow As Ss.Row = sheet.CreateRow(r)
        nameRow.HeightInPoints = 30.0F
        PutText(nameRow, 0, company, nameStyle)
        r += 1
        Dim subStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorMuted, 11S, False), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False)
        PutText(sheet.CreateRow(r), 0, "Listino e offerte del " & dateText & " - " & priceNote & " - " & snapshot.Rows.Count.ToString("N0", ItCulture) & " articoli in " &
                sectors.Count.ToString(CultureInfo.InvariantCulture) & " settori", subStyle)
        r += 2

        Dim labelStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorMuted, 9S, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.TOP, False, 0S, False)
        Dim valueStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorInk, 10S, False), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.TOP, True, 0S, False)
        Dim linkStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorLink, 10S, False, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.TOP, False, 0S, False)
        If info IsNot Nothing Then
            Dim pairs As New List(Of KeyValuePair(Of String, String))()
            pairs.Add(New KeyValuePair(Of String, String)("Ragione sociale", If(String.IsNullOrEmpty(info.LegalName), info.Name, info.LegalName)))
            pairs.Add(New KeyValuePair(Of String, String)("Partita IVA", info.VatNumber))
            pairs.Add(New KeyValuePair(Of String, String)("Sede legale", info.RegisteredOffice))
            pairs.Add(New KeyValuePair(Of String, String)("Sede operativa", info.OperationalOffice))
            pairs.Add(New KeyValuePair(Of String, String)("Telefono", info.Phone))
            pairs.Add(New KeyValuePair(Of String, String)("E-mail", info.Email))
            pairs.Add(New KeyValuePair(Of String, String)("Sito web", info.Website))
            For Each pair As KeyValuePair(Of String, String) In pairs
                If String.IsNullOrWhiteSpace(pair.Value) Then Continue For
                Dim rowObj As Ss.Row = sheet.CreateRow(r)
                PutText(rowObj, 0, pair.Key, labelStyle)
                Dim valueCell As Ss.Cell = PutText(rowObj, 1, pair.Value, valueStyle)
                If pair.Key = "Sito web" AndAlso (pair.Value.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse pair.Value.StartsWith("https://", StringComparison.OrdinalIgnoreCase)) Then
                    valueCell.CellStyle = linkStyle
                    PutUrlLink(valueCell, pair.Value)
                End If
                r += 1
            Next
            r += 1
        End If

        Dim site As String = If(info IsNot Nothing AndAlso Not String.IsNullOrEmpty(info.Website), info.Website, "il sito web")
        Dim noteStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorInk, 10S, True), ColorPale, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, True, 0S, False)
        Dim noteRow As Ss.Row = sheet.CreateRow(r)
        noteRow.HeightInPoints = 44.0F
        PutText(noteRow, 0, "Fanno fede sempre i prezzi e le disponibilit" & ChrW(&HE0) & " aggiornati sul sito. Questo listino pu" & ChrW(&HF2) & " subire variazioni di prezzo o di disponibilit" & ChrW(&HE0) &
                ": controlla sempre il sito web (" & site & ").", noteStyle)
        For k As Integer = 1 To 3
            PutBlank(noteRow, k, noteStyle)
        Next
        sheet.AddMergedRegion(New NPOI.SS.Util.CellRangeAddress(r, r, 0, 3))
        r += 2

        ' Legenda della disponibilita e delle offerte.
        Dim legendTitle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorInk, 10S, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False)
        PutText(sheet.CreateRow(r), 0, "Legenda", legendTitle)
        r += 1
        Dim dot As String = ChrW(&H25CF).ToString() & " "
        Dim legendRows As New List(Of KeyValuePair(Of Short, String))()
        legendRows.Add(New KeyValuePair(Of Short, String)(ColorOk, dot & "Disponibile"))
        legendRows.Add(New KeyValuePair(Of Short, String)(ColorLow, dot & "Pochi pezzi o in arrivo"))
        legendRows.Add(New KeyValuePair(Of Short, String)(ColorKo, dot & "Non disponibile"))
        For Each item As KeyValuePair(Of Short, String) In legendRows
            PutText(sheet.CreateRow(r), 0, item.Value, GetStyle(c, GetFont(c, item.Key, 10S, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False))
            r += 1
        Next
        PutText(sheet.CreateRow(r), 0, "Offerte: prezzo in rosso, prezzo di listino barrato e data di validit" & ChrW(&HE0) & "; le offerte a quantit" & ChrW(&HE0) & " indicano il minimo.", valueStyle)
        r += 2

        ' Settori: ogni riga apre il proprio foglio.
        PutText(sheet.CreateRow(r), 0, "Settori", GetStyle(c, GetFont(c, ColorInk, 14S, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False))
        r += 1
        Dim countStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorMuted, 10S, False), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False)
        For Each sector As SectorBlock In sectors
            Dim tileStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorWhite, 11S, True, True), sector.ColorIndex, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False)
            Dim tileRow As Ss.Row = sheet.CreateRow(r)
            tileRow.HeightInPoints = 24.0F
            Dim tile As Ss.Cell = PutText(tileRow, 0, sector.Name, tileStyle)
            PutSheetLink(tile, sector.SheetNames(0), "A1")
            PutText(tileRow, 1, sector.Rows.Count.ToString("N0", ItCulture) & " articoli", countStyle)
            r += 1
        Next
        r += 1
        Dim listLink As Ss.Cell = PutText(sheet.CreateRow(r), 0, "Elenco completo, ordinabile (senza foto)", GetStyle(c, GetFont(c, ColorLink, 11S, True, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False))
        PutSheetLink(listLink, "Elenco", "A1")

        sheet.PrintSetup.Landscape = False
        sheet.PrintSetup.FitWidth = 1S
        sheet.PrintSetup.FitHeight = 0S
        sheet.FitToPage = True
    End Sub

    ' ---- Foglio di un settore ------------------------------------------------------------------------------------------------------------------

    Private Shared Sub WriteSectorSheet(ByVal c As Ctx, ByVal sector As SectorBlock, ByVal sheet As Ss.Sheet, ByVal rows As List(Of CatalogExportRow), ByVal priceNote As String)
        Dim hsSheet As Hs.HSSFSheet = CType(sheet, Hs.HSSFSheet)
        hsSheet.TabColorIndex = sector.ColorIndex
        sheet.DisplayGridlines = False
        Dim patriarch As Ss.Drawing = sheet.CreateDrawingPatriarch()

        Dim maxCode As Integer = 8
        For Each row As CatalogExportRow In rows
            If Not String.IsNullOrEmpty(row.Code) Then maxCode = Math.Max(maxCode, row.Code.Length)
        Next
        sheet.SetColumnWidth(0, WidthUnits(13.5))
        sheet.SetColumnWidth(1, WidthUnits(maxCode * 1.15 + 3))
        sheet.SetColumnWidth(2, WidthUnits(17))
        sheet.SetColumnWidth(3, WidthUnits(58))
        sheet.SetColumnWidth(4, WidthUnits(19))
        sheet.SetColumnWidth(5, WidthUnits(15))
        sheet.SetColumnWidth(6, WidthUnits(15))
        sheet.SetColumnWidth(7, WidthUnits(30))
        sheet.SetColumnWidth(8, WidthUnits(26))

        Dim fillIndex As Short = sector.ColorIndex
        Dim titleStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorWhite, 16S, True), fillIndex, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False)
        Dim backStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorWhite, 10S, True, True), fillIndex, Ss.HorizontalAlignment.RIGHT, Ss.VerticalAlignment.CENTER, False, 0S, False)
        Dim headStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorWhite, 9S, True), fillIndex, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, True, 0S, False)
        Dim categoryStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorWhite, 11S, True), fillIndex, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False)
        Dim typeStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorInk, 10S, True), ColorGrey, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, False)
        Dim groupStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorMuted, 9S, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, True)

        Dim r As Integer = 0
        Dim titleRow As Ss.Row = sheet.CreateRow(r)
        titleRow.HeightInPoints = 30.0F
        PutText(titleRow, 0, sector.Name, titleStyle)
        For k As Integer = 1 To ColumnCount - 2
            PutBlank(titleRow, k, titleStyle)
        Next
        Dim back As Ss.Cell = PutText(titleRow, ColumnCount - 1, "Torna all'indice", backStyle)
        PutSheetLink(back, "Indice", "A1")
        r += 1

        Dim headRow As Ss.Row = sheet.CreateRow(r)
        headRow.HeightInPoints = 26.0F
        Dim heads As String() = {"Foto", "Codice", "EAN", "Descrizione", "Disponibilit" & ChrW(&HE0), "Prezzo - " & priceNote, "Prezzo di listino", "Offerta", "Note quantit" & ChrW(&HE0)}
        For k As Integer = 0 To heads.Length - 1
            PutText(headRow, k, heads(k), headStyle)
        Next
        r += 1
        sheet.CreateFreezePane(0, r)
        sheet.RowSumsBelow = False

        Dim catKey As String = Nothing
        Dim catName As String = Nothing
        Dim typeKey As String = Nothing
        Dim typeName As String = Nothing
        Dim groupKey As String = Nothing
        Dim groupName As String = Nothing
        Dim catFirstRow As Integer = -1
        For Each row As CatalogExportRow In rows
            If catKey Is Nothing OrElse catKey <> row.CategoryKey OrElse catName <> row.CategoryName Then
                If catFirstRow >= 0 AndAlso r - 1 > catFirstRow Then sheet.GroupRow(catFirstRow, r - 1)
                Dim band As Ss.Row = sheet.CreateRow(r)
                band.HeightInPoints = 22.0F
                PutText(band, 0, row.CategoryName, categoryStyle)
                For k As Integer = 1 To ColumnCount - 1
                    PutBlank(band, k, categoryStyle)
                Next
                r += 1
                catFirstRow = r
                catKey = row.CategoryKey
                catName = row.CategoryName
                typeKey = Nothing
                groupKey = Nothing
            End If
            If typeKey Is Nothing OrElse typeKey <> row.TypeKey OrElse typeName <> row.TypeName Then
                Dim band As Ss.Row = sheet.CreateRow(r)
                band.HeightInPoints = 19.0F
                PutText(band, 0, row.TypeName, typeStyle)
                For k As Integer = 1 To ColumnCount - 1
                    PutBlank(band, k, typeStyle)
                Next
                r += 1
                typeKey = row.TypeKey
                typeName = row.TypeName
                groupKey = Nothing
            End If
            If (groupKey Is Nothing OrElse groupKey <> row.GroupKey OrElse groupName <> row.GroupName) Then
                If row.GroupKey <> "0" Then
                    Dim band As Ss.Row = sheet.CreateRow(r)
                    band.HeightInPoints = 17.0F
                    PutText(band, 0, row.GroupName, groupStyle)
                    For k As Integer = 1 To ColumnCount - 1
                        PutBlank(band, k, groupStyle)
                    Next
                    r += 1
                End If
                groupKey = row.GroupKey
                groupName = row.GroupName
            End If
            WriteArticleRow(c, sheet, patriarch, r, row)
            r += 1
        Next
        If catFirstRow >= 0 AndAlso r - 1 > catFirstRow Then sheet.GroupRow(catFirstRow, r - 1)

        sheet.PrintSetup.Landscape = True
        sheet.PrintSetup.FitWidth = 1S
        sheet.PrintSetup.FitHeight = 0S
        sheet.FitToPage = True
    End Sub

    Private Shared Sub WriteArticleRow(ByVal c As Ctx, ByVal sheet As Ss.Sheet, ByVal patriarch As Ss.Drawing, ByVal r As Integer, ByVal row As CatalogExportRow)
        Dim photo As CatalogExportPhoto = FindPhoto(c, row)
        Dim desc As String = row.Description
        If Not String.IsNullOrEmpty(row.Detail) Then desc &= ChrW(10) & row.Detail
        Dim lines As Integer = LineCount(desc, 62)
        Dim height As Single = CSng(Math.Min(180.0R, Math.Max(If(photo IsNot Nothing, PhotoRowPoints, 28.0F), lines * 11.5R + 6.0R)))
        Dim rowObj As Ss.Row = sheet.CreateRow(r)
        rowObj.HeightInPoints = height

        PutBlank(rowObj, 0, Body(c))
        If photo IsNot Nothing Then PlacePhoto(c, patriarch, photo, r)

        Dim codeStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorLink, 9S, True, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, c.Text, True)
        Dim code As Ss.Cell = PutText(rowObj, 1, row.Code, codeStyle)
        If Not String.IsNullOrEmpty(row.ProductUrl) Then PutUrlLink(code, row.ProductUrl)
        PutText(rowObj, 2, If(CatalogPdfWriter.IsRealEan(row.Ean), row.Ean, ""), Body(c, False, False, c.Text))
        PutText(rowObj, 3, desc, Body(c, False, True))
        WriteCommercialCells(c, rowObj, 4, row)
    End Sub

    ' Colonne dalla "Disponibilita" in poi (sono le stesse nei fogli settore e, spostate, nell'Elenco).
    Private Shared Sub WriteCommercialCells(ByVal c As Ctx, ByVal rowObj As Ss.Row, ByVal firstColumn As Integer, ByVal row As CatalogExportRow)
        Dim tone As Short = If(row.AvailabilityTone = 0, ColorOk, If(row.AvailabilityTone = 1, ColorLow, ColorKo))
        PutText(rowObj, firstColumn, ChrW(&H25CF).ToString() & " " & row.AvailabilityText,
                GetStyle(c, GetFont(c, tone, 9S, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, 0S, True))

        Dim moneyStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorInk, 10S, True), -1S, Ss.HorizontalAlignment.RIGHT, Ss.VerticalAlignment.CENTER, False, c.Money, True)
        Dim saleStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorKo, 10S, True), -1S, Ss.HorizontalAlignment.RIGHT, Ss.VerticalAlignment.CENTER, False, c.Money, True)
        Dim oldStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorMuted, 9S, False, False, True), -1S, Ss.HorizontalAlignment.RIGHT, Ss.VerticalAlignment.CENTER, False, c.Money, True)
        Dim askStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorMuted, 9S, False), -1S, Ss.HorizontalAlignment.RIGHT, Ss.VerticalAlignment.CENTER, False, 0S, True)
        Dim offerStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorKo, 8S, True), ColorPale, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, True, 0S, True)

        If Not row.HasPrice Then
            PutText(rowObj, firstColumn + 1, "Su richiesta", askStyle)
            PutBlank(rowObj, firstColumn + 2, Body(c))
        Else
            Dim price As Ss.Cell = rowObj.CreateCell(firstColumn + 1)
            price.SetCellValue(ToDouble(row.Price))
            price.CellStyle = If(row.ShowsDiscount, saleStyle, moneyStyle)
            If row.ShowsDiscount Then
                Dim old As Ss.Cell = rowObj.CreateCell(firstColumn + 2)
                old.SetCellValue(ToDouble(row.ListPrice))
                old.CellStyle = oldStyle
            Else
                PutBlank(rowObj, firstColumn + 2, Body(c))
            End If
        End If

        If row.IsOffer Then
            Dim text As String = "OFFERTA"
            If Not String.IsNullOrEmpty(row.OfferLabel) AndAlso Not String.Equals(row.OfferLabel, "Offerta", StringComparison.OrdinalIgnoreCase) Then text &= " - " & row.OfferLabel
            If row.OfferEndsOn.HasValue Then text &= " fino al " & row.OfferEndsOn.Value.ToString("dd/MM/yyyy", ItCulture)
            PutText(rowObj, firstColumn + 3, text, offerStyle)
        Else
            PutBlank(rowObj, firstColumn + 3, Body(c))
        End If
        PutText(rowObj, firstColumn + 4, row.TierNote, GetStyle(c, GetFont(c, ColorMuted, 8S, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, True, 0S, True))
    End Sub

    ' ---- Foglio Elenco (piatto, ordinabile, senza foto) ----------------------------------------------------------------------------

    Private Shared Sub WriteList(ByVal c As Ctx, ByVal sheet As Ss.Sheet, ByVal rows As List(Of CatalogExportRow), ByVal priceNote As String)
        Dim hsSheet As Hs.HSSFSheet = CType(sheet, Hs.HSSFSheet)
        hsSheet.TabColorIndex = ColorMuted
        Dim maxCode As Integer = 8
        For Each row As CatalogExportRow In rows
            If Not String.IsNullOrEmpty(row.Code) Then maxCode = Math.Max(maxCode, row.Code.Length)
        Next
        Dim widths As Double() = {24, 24, 26, 24, maxCode * 1.15 + 3, 17, 58, 19, 15, 15, 30, 26}
        For k As Integer = 0 To widths.Length - 1
            sheet.SetColumnWidth(k, WidthUnits(widths(k)))
        Next
        Dim headStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorWhite, 9S, True), ColorInk, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, True, 0S, False)
        Dim heads As String() = {"Settore", "Categoria", "Tipologia", "Gruppo", "Codice", "EAN", "Descrizione", "Disponibilit" & ChrW(&HE0), "Prezzo - " & priceNote, "Prezzo di listino", "Offerta", "Note quantit" & ChrW(&HE0)}
        Dim headRow As Ss.Row = sheet.CreateRow(0)
        headRow.HeightInPoints = 26.0F
        For k As Integer = 0 To heads.Length - 1
            PutText(headRow, k, heads(k), headStyle)
        Next
        sheet.CreateFreezePane(0, 1)
        Dim r As Integer = 1
        For Each row As CatalogExportRow In rows
            Dim rowObj As Ss.Row = sheet.CreateRow(r)
            Dim textStyle As Ss.CellStyle = Body(c, False, False)
            PutText(rowObj, 0, row.SectorName, textStyle)
            PutText(rowObj, 1, row.CategoryName, textStyle)
            PutText(rowObj, 2, row.TypeName, textStyle)
            PutText(rowObj, 3, If(row.GroupKey = "0", "", row.GroupName), textStyle)
            Dim codeStyle As Ss.CellStyle = GetStyle(c, GetFont(c, ColorLink, 9S, True, True), -1S, Ss.HorizontalAlignment.LEFT, Ss.VerticalAlignment.CENTER, False, c.Text, True)
            Dim code As Ss.Cell = PutText(rowObj, 4, row.Code, codeStyle)
            If Not String.IsNullOrEmpty(row.ProductUrl) Then PutUrlLink(code, row.ProductUrl)
            PutText(rowObj, 5, If(CatalogPdfWriter.IsRealEan(row.Ean), row.Ean, ""), Body(c, False, False, c.Text))
            PutText(rowObj, 6, row.Description, Body(c, False, False))
            WriteCommercialCells(c, rowObj, 7, row)
            r += 1
        Next
        sheet.PrintSetup.Landscape = True
        sheet.PrintSetup.FitWidth = 1S
        sheet.PrintSetup.FitHeight = 0S
        sheet.FitToPage = True
    End Sub
End Class
