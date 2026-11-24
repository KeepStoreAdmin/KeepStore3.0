Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports iTextSharp.text
Imports iTextSharp.text.pdf

' Listino e offerte in PDF sfogliabile (CATALOG-DOWNLOAD-1A). Gerarchia del sito: settore > categoria > tipologia > gruppo (segnalibri a quattro livelli).
' Prima pagina con logo e dati aziendali, nota sui prezzi del sito e legenda della disponibilita; indice a riquadri colorati (uno per settore) e, all'inizio
' di ogni settore, il reticolo delle sue categorie e tipologie con i numeri di pagina cliccabili. Righe con foto, codice, EAN, descrizione, disponibilita
' (pallino verde, giallo, rosso) e prezzo; le offerte hanno riferimento, validita e prezzo di listino barrato; il codice apre la scheda sul sito.
' Tutti i valori arrivano dallo snapshot: qui non si calcola nessun prezzo. Due passate: la prima (senza foto, stesso impaginato) registra la pagina di
' ogni titolo per scrivere i numeri; la seconda produce il file. Solo testo in CP1252 (i caratteri non codificabili diventano "?").
Public NotInheritable Class CatalogPdfWriter
    Private Sub New()
    End Sub

    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
    <ThreadStatic> Private Shared _clock As Diagnostics.Stopwatch
    Private Const RowHeight As Single = 44.0F
    ' Dopo questo tempo non si ridimensionano piu nuove foto (restano le miniature pronte e quelle in cache): il file si completa comunque,
    ' la generazione successiva trova le foto gia ridotte.
    Private Const ResizeBudgetSeconds As Integer = 150

    Friend Shared ReadOnly SectorPalette As Integer()() = New Integer()() {
        New Integer() {31, 78, 121}, New Integer() {0, 121, 107}, New Integer() {46, 125, 50}, New Integer() {191, 87, 0},
        New Integer() {173, 20, 87}, New Integer() {94, 53, 177}, New Integer() {0, 105, 148}, New Integer() {123, 31, 162},
        New Integer() {198, 40, 40}, New Integer() {69, 90, 100}, New Integer() {130, 119, 23}, New Integer() {0, 131, 143},
        New Integer() {109, 76, 65}, New Integer() {40, 53, 147}, New Integer() {85, 139, 47}, New Integer() {216, 67, 21}
    }

    Friend Shared ReadOnly Property SectorColorCount As Integer
        Get
            Return SectorPalette.Length
        End Get
    End Property

    Friend Shared Function SectorColor(ByVal index As Integer) As Integer()
        Return SectorPalette(index Mod SectorPalette.Length)
    End Function

    Private NotInheritable Class Styles
        Public ReadOnly Base As BaseFont
        Public ReadOnly Bold As BaseFont
        Public ReadOnly Dots As BaseFont
        Public ReadOnly Ink As New BaseColor(33, 37, 41)
        Public ReadOnly Muted As New BaseColor(110, 117, 124)
        Public ReadOnly Accent As New BaseColor(31, 41, 55)
        Public ReadOnly Sale As New BaseColor(216, 0, 39)
        Public ReadOnly Band As New BaseColor(240, 242, 245)
        Public ReadOnly Line As New BaseColor(214, 218, 222)
        Public ReadOnly White As New BaseColor(255, 255, 255)
        Public ReadOnly DotOk As New BaseColor(34, 160, 72)
        Public ReadOnly DotLow As New BaseColor(240, 176, 0)
        Public ReadOnly DotKo As New BaseColor(214, 40, 40)
        Public Sub New()
            Base = BaseFont.CreateFont(BaseFont.HELVETICA, BaseFont.CP1252, BaseFont.NOT_EMBEDDED)
            Bold = BaseFont.CreateFont(BaseFont.HELVETICA_BOLD, BaseFont.CP1252, BaseFont.NOT_EMBEDDED)
            Dots = BaseFont.CreateFont(BaseFont.ZAPFDINGBATS, BaseFont.CP1252, BaseFont.NOT_EMBEDDED)
        End Sub
        Public Function F(ByVal size As Single, ByVal bold As Boolean, ByVal color As BaseColor) As Font
            Return New Font(If(bold, Me.Bold, Me.Base), size, Font.NORMAL, color)
        End Function
        Public Function Dot(ByVal tone As Integer, ByVal size As Single) As Chunk
            Dim color As BaseColor = If(tone = 0, DotOk, If(tone = 1, DotLow, DotKo))
            Return New Chunk("l", New Font(Dots, size, Font.NORMAL, color))
        End Function
        Public Shared Function Tint(ByVal c As BaseColor, ByVal amount As Single) As BaseColor
            Return New BaseColor(CInt(c.R + (255 - c.R) * amount), CInt(c.G + (255 - c.G) * amount), CInt(c.B + (255 - c.B) * amount))
        End Function
    End Class

    Private NotInheritable Class PageEvents
        Inherits PdfPageEventHelper
        Private ReadOnly _styles As Styles
        Private ReadOnly _footer As String
        Public ReadOnly Pages As New Dictionary(Of String, Integer)(StringComparer.Ordinal)
        Public CurrentSector As String = ""
        Public CurrentColor As BaseColor
        Public Sub New(ByVal styles As Styles, ByVal footer As String)
            _styles = styles
            _footer = footer
            CurrentColor = styles.Accent
        End Sub
        Public Overrides Sub OnGenericTag(ByVal writer As PdfWriter, ByVal document As Document, ByVal rect As Rectangle, ByVal text As String)
            If Not Pages.ContainsKey(text) Then Pages.Add(text, writer.PageNumber)
        End Sub
        Public Overrides Sub OnEndPage(ByVal writer As PdfWriter, ByVal document As Document)
            If writer.PageNumber <= 1 Then Return
            Dim cb As PdfContentByte = writer.DirectContent
            Dim stripe As BaseColor = If(String.IsNullOrEmpty(CurrentSector), _styles.Accent, CurrentColor)
            cb.SetColorFill(stripe)
            cb.Rectangle(0.0F, document.PageSize.Height - 8.0F, document.PageSize.Width, 8.0F)
            cb.Fill()
            cb.SetColorStroke(_styles.Line)
            cb.SetLineWidth(0.5F)
            cb.MoveTo(document.LeftMargin, document.BottomMargin - 6.0F)
            cb.LineTo(document.PageSize.Width - document.RightMargin, document.BottomMargin - 6.0F)
            cb.Stroke()
            ColumnText.ShowTextAligned(cb, Element.ALIGN_LEFT, New Phrase(_footer, _styles.F(7.5F, False, _styles.Muted)),
                                       document.LeftMargin, document.BottomMargin - 18.0F, 0.0F)
            If Not String.IsNullOrEmpty(CurrentSector) Then
                ColumnText.ShowTextAligned(cb, Element.ALIGN_LEFT, New Phrase(CurrentSector, _styles.F(8.0F, True, CurrentColor)),
                                           document.LeftMargin, document.BottomMargin - 29.0F, 0.0F)
            End If
            ColumnText.ShowTextAligned(cb, Element.ALIGN_RIGHT,
                                       New Phrase("Pagina " & writer.PageNumber.ToString(CultureInfo.InvariantCulture), _styles.F(7.5F, False, _styles.Muted)),
                                       document.PageSize.Width - document.RightMargin, document.BottomMargin - 18.0F, 0.0F)
        End Sub
    End Class

    Private NotInheritable Class GroupNode
        Public Key As String
        Public Name As String
        Public Rows As New List(Of CatalogExportRow)()
        Public Anchor As String
    End Class

    Private NotInheritable Class TypeNode
        Public Key As String
        Public Name As String
        Public Groups As New List(Of GroupNode)()
        Public Anchor As String
        Public Count As Integer
    End Class

    Private NotInheritable Class CategoryNode
        Public Key As String
        Public Name As String
        Public Types As New List(Of TypeNode)()
        Public Anchor As String
        Public Count As Integer
    End Class

    Private NotInheritable Class SectorNode
        Public Key As String
        Public Name As String
        Public Categories As New List(Of CategoryNode)()
        Public Anchor As String
        Public Count As Integer
        Public Color As BaseColor
    End Class

    ' Costruisce il PDF in memoria. Le righe arrivano gia ordinate settore > categoria > tipologia > gruppo.
    Public Shared Function Build(ByVal snapshot As CatalogExportSnapshot) As Byte()
        If snapshot Is Nothing OrElse snapshot.Status <> CatalogExportStatus.Ready Then Throw New InvalidOperationException("SNAPSHOT_NOT_READY")
        Dim styles As New Styles()
        Dim sectors As List(Of SectorNode) = BuildTree(snapshot.Rows)
        MeasureColumns(styles, snapshot.Rows)
        Dim pages As Dictionary(Of String, Integer) = Nothing
        _clock = Diagnostics.Stopwatch.StartNew()
        RenderDocument(snapshot, styles, sectors, Nothing, False, pages)
        Dim ignored As Dictionary(Of String, Integer) = Nothing
        Return RenderDocument(snapshot, styles, sectors, pages, True, ignored)
    End Function

    Private Shared Function RenderDocument(ByVal snapshot As CatalogExportSnapshot, ByVal styles As Styles, ByVal sectors As List(Of SectorNode),
                                           ByVal knownPages As Dictionary(Of String, Integer), ByVal withImages As Boolean,
                                           ByRef capturedPages As Dictionary(Of String, Integer)) As Byte()
        Dim company As String = Pdf(If(snapshot.Company IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(snapshot.Company.Name), snapshot.Company.Name,
                                       If(String.IsNullOrWhiteSpace(snapshot.CompanyName), "KeepStore", snapshot.CompanyName)))
        Dim dateText As String = snapshot.GeneratedOn.ToString("dd/MM/yyyy", ItCulture)
        Dim priceNote As String = Pdf(If(String.IsNullOrWhiteSpace(snapshot.PriceLabel), "Prezzi", snapshot.PriceLabel)).TrimStart("*"c).Trim()
        Using output As New MemoryStream()
            Dim doc As New Document(PageSize.A4, 28.0F, 28.0F, 34.0F, 52.0F)
            Dim writer As PdfWriter = PdfWriter.GetInstance(doc, output)
            Dim events As New PageEvents(styles, company & " - Listino e offerte del " & dateText & " - " & priceNote)
            writer.PageEvent = events
            writer.SetFullCompression()
            doc.AddTitle("Listino e offerte " & company)
            doc.AddAuthor(company)
            doc.AddSubject("Listino a catalogo con offerte")
            doc.AddCreator("KeepStore")
            doc.Open()

            WriteCover(doc, styles, snapshot, company, dateText, priceNote, sectors.Count, withImages)
            WriteSectorIndex(doc, styles, sectors, knownPages)

            Dim root As PdfOutline = writer.DirectContent.RootOutline
            For Each sector As SectorNode In sectors
                doc.NewPage()
                events.CurrentSector = Pdf(sector.Name)
                events.CurrentColor = sector.Color
                Dim sectorOutline As New PdfOutline(root, PdfAction.GotoLocalPage(sector.Anchor, False), Pdf(sector.Name))
                WriteSectorBand(doc, styles, sector)
                WriteSectorGrid(doc, styles, sector, knownPages)
                For Each cat As CategoryNode In sector.Categories
                    Dim catOutline As New PdfOutline(sectorOutline, PdfAction.GotoLocalPage(cat.Anchor, False), Pdf(cat.Name))
                    WriteCategoryHeading(doc, styles, sector, cat)
                    For Each typ As TypeNode In cat.Types
                        Dim typeOutline As New PdfOutline(catOutline, PdfAction.GotoLocalPage(typ.Anchor, False), Pdf(typ.Name))
                        WriteTypeHeading(doc, styles, typ)
                        Dim lonely As Boolean = (typ.Groups.Count = 1 AndAlso typ.Groups(0).Key = "0")
                        For Each grp As GroupNode In typ.Groups
                            If Not lonely Then
                                Dim groupOutline As New PdfOutline(typeOutline, PdfAction.GotoLocalPage(grp.Anchor, False), Pdf(grp.Name))
                            End If
                            WriteRows(doc, styles, sector, grp, withImages, Not lonely)
                        Next
                    Next
                Next
            Next
            capturedPages = events.Pages
            doc.Close()
            Return output.ToArray()
        End Using
    End Function

    Private Shared Function BuildTree(ByVal rows As List(Of CatalogExportRow)) As List(Of SectorNode)
        Dim result As New List(Of SectorNode)()
        Dim sector As SectorNode = Nothing
        Dim cat As CategoryNode = Nothing
        Dim typ As TypeNode = Nothing
        Dim grp As GroupNode = Nothing
        Dim sectorCount As Integer = 0
        Dim categoryCount As Integer = 0
        Dim typeCount As Integer = 0
        Dim groupCount As Integer = 0
        For Each row As CatalogExportRow In rows
            If sector Is Nothing OrElse sector.Key <> row.SectorKey OrElse sector.Name <> row.SectorName Then
                Dim rgb As Integer() = SectorPalette(sectorCount Mod SectorPalette.Length)
                sectorCount += 1
                sector = New SectorNode() With {.Key = row.SectorKey, .Name = row.SectorName, .Anchor = "s" & sectorCount.ToString(CultureInfo.InvariantCulture),
                                                .Color = New BaseColor(rgb(0), rgb(1), rgb(2))}
                result.Add(sector)
                cat = Nothing
                typ = Nothing
                grp = Nothing
            End If
            If cat Is Nothing OrElse cat.Key <> row.CategoryKey OrElse cat.Name <> row.CategoryName Then
                categoryCount += 1
                cat = New CategoryNode() With {.Key = row.CategoryKey, .Name = row.CategoryName, .Anchor = "c" & categoryCount.ToString(CultureInfo.InvariantCulture)}
                sector.Categories.Add(cat)
                typ = Nothing
                grp = Nothing
            End If
            If typ Is Nothing OrElse typ.Key <> row.TypeKey OrElse typ.Name <> row.TypeName Then
                typeCount += 1
                typ = New TypeNode() With {.Key = row.TypeKey, .Name = row.TypeName, .Anchor = "t" & typeCount.ToString(CultureInfo.InvariantCulture)}
                cat.Types.Add(typ)
                grp = Nothing
            End If
            If grp Is Nothing OrElse grp.Key <> row.GroupKey OrElse grp.Name <> row.GroupName Then
                groupCount += 1
                grp = New GroupNode() With {.Key = row.GroupKey, .Name = row.GroupName, .Anchor = "g" & groupCount.ToString(CultureInfo.InvariantCulture)}
                typ.Groups.Add(grp)
            End If
            grp.Rows.Add(row)
            typ.Count += 1
            cat.Count += 1
            sector.Count += 1
        Next
        Return result
    End Function

    ' ---- Prima pagina ---------------------------------------------------------------------------------------------------------------------------------

    Private Shared Sub WriteCover(ByVal doc As Document, ByVal styles As Styles, ByVal snapshot As CatalogExportSnapshot, ByVal company As String,
                                  ByVal dateText As String, ByVal priceNote As String, ByVal sectorCount As Integer, ByVal withImages As Boolean)
        Dim info As CatalogExportCompany = snapshot.Company
        Dim logoDone As Boolean = False
        ' Il logo si carica in entrambe le passate: stesso spazio sulla prima pagina, stessi numeri di pagina.
        If info IsNot Nothing AndAlso Not String.IsNullOrEmpty(info.LogoFile) Then
            Try
                Dim logoBytes As Byte() = CatalogExportImages.LoadLogo(info.LogoFile)
                If logoBytes IsNot Nothing Then
                    Dim logo As iTextSharp.text.Image = iTextSharp.text.Image.GetInstance(logoBytes)
                    logo.ScaleToFit(210.0F, 80.0F)
                    logo.Alignment = Element.ALIGN_CENTER
                    doc.Add(logo)
                    logoDone = True
                End If
            Catch
            End Try
        End If
        If Not logoDone Then doc.Add(New Paragraph(" ") With {.SpacingBefore = 30.0F})
        doc.Add(New Paragraph(company.ToUpper(ItCulture), styles.F(24.0F, True, styles.Accent)) With {.Alignment = Element.ALIGN_CENTER, .SpacingBefore = 10.0F})
        doc.Add(New Paragraph("Listino e offerte", styles.F(17.0F, False, styles.Ink)) With {.Alignment = Element.ALIGN_CENTER, .SpacingBefore = 2.0F})
        doc.Add(New Paragraph(dateText & "  -  " & priceNote & "  -  " & snapshot.Rows.Count.ToString("N0", ItCulture) & " articoli in " &
                              sectorCount.ToString(CultureInfo.InvariantCulture) & " settori", styles.F(9.5F, False, styles.Muted)) With {.Alignment = Element.ALIGN_CENTER, .SpacingBefore = 6.0F})

        ' Dati aziendali completi (quelli gia pubblicati dal sito per questa azienda).
        If info IsNot Nothing Then
            Dim card As New PdfPTable(2) With {.WidthPercentage = 86.0F, .SpacingBefore = 18.0F, .HorizontalAlignment = Element.ALIGN_CENTER}
            card.SetWidths(New Single() {30.0F, 70.0F})
            AddInfoRow(card, styles, "Ragione sociale", If(String.IsNullOrEmpty(info.LegalName), info.Name, info.LegalName))
            AddInfoRow(card, styles, "Partita IVA", info.VatNumber)
            AddInfoRow(card, styles, "Sede legale", info.RegisteredOffice)
            AddInfoRow(card, styles, "Sede operativa", info.OperationalOffice)
            AddInfoRow(card, styles, "Telefono", info.Phone)
            AddInfoRow(card, styles, "E-mail", info.Email)
            AddInfoRow(card, styles, "Sito web", info.Website)
            doc.Add(card)
        End If

        ' Nota sui prezzi del sito.
        Dim site As String = If(info IsNot Nothing AndAlso Not String.IsNullOrEmpty(info.Website), Pdf(info.Website), "il sito web")
        Dim note As New PdfPTable(1) With {.WidthPercentage = 86.0F, .SpacingBefore = 16.0F, .HorizontalAlignment = Element.ALIGN_CENTER}
        Dim noteText As New Phrase()
        noteText.Add(New Chunk("Fanno fede sempre i prezzi e le disponibilità aggiornati sul sito. ", styles.F(9.5F, True, styles.Ink)))
        noteText.Add(New Chunk("Questo listino può subire variazioni di prezzo o di disponibilità: controlla sempre il sito web (" & site & ").", styles.F(9.0F, False, styles.Ink)))
        note.AddCell(New PdfPCell(noteText) With {.BackgroundColor = New BaseColor(255, 247, 214), .BorderColor = New BaseColor(240, 176, 0), .BorderWidth = 1.0F, .Padding = 9.0F})
        doc.Add(note)

        ' Legenda.
        Dim legend As New PdfPTable(1) With {.WidthPercentage = 86.0F, .SpacingBefore = 12.0F, .HorizontalAlignment = Element.ALIGN_CENTER}
        Dim legendText As New Phrase()
        legendText.Add(New Chunk("Disponibilità:   ", styles.F(8.5F, True, styles.Ink)))
        legendText.Add(styles.Dot(0, 11.0F))
        legendText.Add(New Chunk(" Disponibile     ", styles.F(8.5F, False, styles.Ink)))
        legendText.Add(styles.Dot(1, 11.0F))
        legendText.Add(New Chunk(" Pochi pezzi o in arrivo     ", styles.F(8.5F, False, styles.Ink)))
        legendText.Add(styles.Dot(2, 11.0F))
        legendText.Add(New Chunk(" Non disponibile", styles.F(8.5F, False, styles.Ink)))
        legendText.Add(New Chunk(vbLf & "Offerte:   ", styles.F(8.5F, True, styles.Ink)))
        legendText.Add(New Chunk("prezzo in rosso, prezzo di listino barrato e data di validità; le offerte a quantità indicano il minimo.", styles.F(8.5F, False, styles.Ink)))
        Dim legendCell As New PdfPCell(legendText) With {.BackgroundColor = styles.Band, .BorderColor = styles.Line, .Padding = 9.0F}
        legendCell.SetLeading(14.0F, 0.0F)
        legend.AddCell(legendCell)
        doc.Add(legend)

        doc.Add(New Paragraph("Come sfogliarlo: usa i segnalibri del lettore PDF (settore, categoria, tipologia, gruppo) oppure i riquadri colorati dell'indice nella pagina " &
                              "seguente; il codice di ogni articolo apre la sua scheda sul sito.", styles.F(8.5F, False, styles.Muted)) With {
                              .Alignment = Element.ALIGN_CENTER, .SpacingBefore = 14.0F, .IndentationLeft = 50.0F, .IndentationRight = 50.0F})
    End Sub

    Private Shared Sub AddInfoRow(ByVal table As PdfPTable, ByVal styles As Styles, ByVal label As String, ByVal value As String)
        If String.IsNullOrWhiteSpace(value) Then Return
        table.AddCell(New PdfPCell(New Phrase(label, styles.F(8.0F, True, styles.Muted))) With {.Border = Rectangle.BOTTOM_BORDER, .BorderColor = styles.Line, .PaddingTop = 4.0F, .PaddingBottom = 4.0F})
        table.AddCell(New PdfPCell(New Phrase(Pdf(value), styles.F(9.0F, False, styles.Ink))) With {.Border = Rectangle.BOTTOM_BORDER, .BorderColor = styles.Line, .PaddingTop = 4.0F, .PaddingBottom = 4.0F})
    End Sub

    ' ---- Indice a riquadri ----------------------------------------------------------------------------------------------------------------------------

    Private Shared Sub WriteSectorIndex(ByVal doc As Document, ByVal styles As Styles, ByVal sectors As List(Of SectorNode),
                                        ByVal knownPages As Dictionary(Of String, Integer))
        doc.NewPage()
        doc.Add(New Paragraph("Indice dei settori", styles.F(18.0F, True, styles.Accent)) With {.SpacingAfter = 2.0F})
        doc.Add(New Paragraph("Tocca un riquadro per andare al settore. All'inizio di ogni settore trovi il reticolo delle sue categorie e tipologie.",
                              styles.F(9.0F, False, styles.Muted)) With {.SpacingAfter = 12.0F})
        Dim grid As New PdfPTable(3) With {.WidthPercentage = 100.0F, .SplitRows = False}
        grid.SetWidths(New Single() {49.0F, 2.0F, 49.0F})
        Dim i As Integer = 0
        While i < sectors.Count
            grid.AddCell(SectorTile(styles, sectors(i), knownPages))
            grid.AddCell(New PdfPCell() With {.Border = Rectangle.NO_BORDER})
            If i + 1 < sectors.Count Then
                grid.AddCell(SectorTile(styles, sectors(i + 1), knownPages))
            Else
                grid.AddCell(New PdfPCell() With {.Border = Rectangle.NO_BORDER})
            End If
            For k As Integer = 1 To 3
                grid.AddCell(New PdfPCell() With {.Border = Rectangle.NO_BORDER, .FixedHeight = 8.0F})
            Next
            i += 2
        End While
        doc.Add(grid)
    End Sub

    Private Shared Function SectorTile(ByVal styles As Styles, ByVal sector As SectorNode, ByVal knownPages As Dictionary(Of String, Integer)) As PdfPCell
        Dim p As New Phrase()
        Dim name As New Chunk(Pdf(sector.Name).ToUpper(ItCulture), styles.F(11.5F, True, styles.White))
        name.SetLocalGoto(sector.Anchor)
        p.Add(name)
        Dim meta As New Chunk(vbLf & sector.Count.ToString("N0", ItCulture) & " articoli  -  " & sector.Categories.Count.ToString(CultureInfo.InvariantCulture) &
                              " categorie  -  pag. " & PageText(sector.Anchor, knownPages), styles.F(8.0F, False, styles.White))
        meta.SetLocalGoto(sector.Anchor)
        p.Add(meta)
        Return New PdfPCell(p) With {.BackgroundColor = sector.Color, .Border = Rectangle.NO_BORDER, .Padding = 11.0F, .FixedHeight = 60.0F,
                                     .VerticalAlignment = Element.ALIGN_MIDDLE}
    End Function

    Private Shared Function PageText(ByVal anchor As String, ByVal knownPages As Dictionary(Of String, Integer)) As String
        Dim page As Integer = 0
        If knownPages IsNot Nothing AndAlso knownPages.TryGetValue(anchor, page) Then Return page.ToString(CultureInfo.InvariantCulture)
        Return "000"
    End Function

    ' Fascia colorata del settore (destinazione del segnalibro) e reticolo delle sue categorie con le tipologie cliccabili.
    Private Shared Sub WriteSectorBand(ByVal doc As Document, ByVal styles As Styles, ByVal sector As SectorNode)
        Dim band As New PdfPTable(1) With {.WidthPercentage = 100.0F, .SpacingAfter = 8.0F}
        Dim p As New Phrase()
        Dim chunk As New Chunk(Pdf(sector.Name).ToUpper(ItCulture), styles.F(19.0F, True, styles.White))
        chunk.SetLocalDestination(sector.Anchor)
        chunk.SetGenericTag(sector.Anchor)
        p.Add(chunk)
        p.Add(New Chunk("    " & sector.Count.ToString("N0", ItCulture) & " articoli", styles.F(9.5F, False, styles.White)))
        band.AddCell(New PdfPCell(p) With {.BackgroundColor = sector.Color, .Border = Rectangle.NO_BORDER, .Padding = 12.0F})
        doc.Add(band)
    End Sub

    Private Shared Sub WriteSectorGrid(ByVal doc As Document, ByVal styles As Styles, ByVal sector As SectorNode, ByVal knownPages As Dictionary(Of String, Integer))
        doc.Add(New Paragraph("Categorie e tipologie del settore", styles.F(9.0F, True, sector.Color)) With {.SpacingAfter = 4.0F})
        Dim grid As New PdfPTable(3) With {.WidthPercentage = 100.0F, .SplitRows = False}
        Dim light As BaseColor = Styles.Tint(sector.Color, 0.9F)
        Dim count As Integer = 0
        For Each cat As CategoryNode In sector.Categories
            Dim p As New Phrase()
            Dim title As New Chunk(Pdf(cat.Name), styles.F(8.5F, True, sector.Color))
            title.SetLocalGoto(cat.Anchor)
            p.Add(title)
            Dim pg As New Chunk("  p." & PageText(cat.Anchor, knownPages), styles.F(7.0F, False, styles.Muted))
            pg.SetLocalGoto(cat.Anchor)
            p.Add(pg)
            For Each typ As TypeNode In cat.Types
                Dim t As New Chunk(vbLf & ChrW(&H95) & " " & Pdf(typ.Name), styles.F(7.3F, False, styles.Ink))
                t.SetLocalGoto(typ.Anchor)
                p.Add(t)
                Dim tp As New Chunk("  " & PageText(typ.Anchor, knownPages), styles.F(6.5F, False, styles.Muted))
                tp.SetLocalGoto(typ.Anchor)
                p.Add(tp)
            Next
            grid.AddCell(New PdfPCell(p) With {.BackgroundColor = light, .BorderColor = sector.Color, .BorderWidthLeft = 2.5F, .BorderWidthTop = 0.0F,
                                               .BorderWidthRight = 0.0F, .BorderWidthBottom = 0.0F, .Padding = 6.0F})
            count += 1
        Next
        While count Mod 3 <> 0
            grid.AddCell(New PdfPCell() With {.Border = Rectangle.NO_BORDER})
            count += 1
        End While
        doc.Add(grid)
    End Sub

    ' ---- Titoli e righe ---------------------------------------------------------------------------------------------------------------------------------

    Private Shared Sub WriteCategoryHeading(ByVal doc As Document, ByVal styles As Styles, ByVal sector As SectorNode, ByVal cat As CategoryNode)
        Dim table As New PdfPTable(1) With {.WidthPercentage = 100.0F, .SpacingBefore = 10.0F, .SpacingAfter = 2.0F}
        Dim p As New Phrase()
        Dim chunk As New Chunk(Pdf(cat.Name).ToUpper(ItCulture), styles.F(13.0F, True, sector.Color))
        chunk.SetLocalDestination(cat.Anchor)
        chunk.SetGenericTag(cat.Anchor)
        p.Add(chunk)
        p.Add(New Chunk("   " & cat.Count.ToString("N0", ItCulture) & " articoli", styles.F(8.0F, False, styles.Muted)))
        table.AddCell(New PdfPCell(p) With {.BackgroundColor = Styles.Tint(sector.Color, 0.88F), .BorderColor = sector.Color, .BorderWidthLeft = 4.0F,
                                            .BorderWidthTop = 0.0F, .BorderWidthRight = 0.0F, .BorderWidthBottom = 0.0F, .Padding = 8.0F})
        doc.Add(table)
    End Sub

    Private Shared Sub WriteTypeHeading(ByVal doc As Document, ByVal styles As Styles, ByVal typ As TypeNode)
        Dim chunk As New Chunk(Pdf(typ.Name), styles.F(11.0F, True, styles.Ink))
        chunk.SetLocalDestination(typ.Anchor)
        chunk.SetGenericTag(typ.Anchor)
        Dim p As New Paragraph(New Phrase(chunk)) With {.SpacingBefore = 8.0F, .SpacingAfter = 2.0F}
        p.Add(New Chunk("   " & typ.Count.ToString("N0", ItCulture) & " articoli", styles.F(7.5F, False, styles.Muted)))
        doc.Add(p)
    End Sub

    ' Il titolo del gruppo e la prima riga d'intestazione della tabella: si ripete sulle pagine successive e non resta mai solo in fondo a una pagina.
    ' Un gruppo unico senza nome (articoli senza gruppo) non ha titolo.
    Private Shared Sub WriteRows(ByVal doc As Document, ByVal styles As Styles, ByVal sector As SectorNode, ByVal grp As GroupNode,
                                 ByVal withImages As Boolean, ByVal showTitle As Boolean)
        Dim rows As List(Of CatalogExportRow) = grp.Rows
        Dim table As New PdfPTable(6) With {.WidthPercentage = 100.0F, .HeaderRows = If(showTitle, 2, 1), .SplitRows = False, .SpacingAfter = 4.0F, .SpacingBefore = 3.0F}
        table.SetWidths(New Single() {40.0F, _codeColumn, _eanColumn, 539.0F - 40.0F - 34.0F - 86.0F - _codeColumn - _eanColumn, 34.0F, 86.0F})
        Dim head As BaseColor = Styles.Tint(sector.Color, 0.86F)
        If showTitle Then
            Dim titleChunk As New Chunk(Pdf(grp.Name), styles.F(9.0F, True, sector.Color))
            titleChunk.SetLocalDestination(grp.Anchor)
            table.AddCell(New PdfPCell(New Phrase(titleChunk)) With {.Colspan = 6, .Border = Rectangle.NO_BORDER, .PaddingLeft = 0.0F, .PaddingBottom = 3.0F})
        End If
        Dim headers As String() = New String() {"Foto", "Codice", "EAN", "Descrizione", "Disp.", "Prezzo"}
        For i As Integer = 0 To headers.Length - 1
            Dim hc As New PdfPCell(New Phrase(headers(i), styles.F(7.5F, True, sector.Color))) With {
                .BackgroundColor = head, .BorderColor = styles.Line, .Padding = 3.0F,
                .HorizontalAlignment = If(i = 5, Element.ALIGN_RIGHT, If(i = 4, Element.ALIGN_CENTER, Element.ALIGN_LEFT))}
            table.AddCell(hc)
        Next
        For Each row As CatalogExportRow In rows
            table.AddCell(PhotoCell(styles, row, withImages))
            table.AddCell(NoWrapCell(styles, CodePhrase(styles, row, _codeColumn - 6.0F)))
            ' Solo un vero EAN (8-14 cifre): il campo del gestionale a volte contiene un testo uguale al codice, che qui non si ripete.
            table.AddCell(NoWrapCell(styles, EanPhrase(styles, row.Ean, _eanColumn - 6.0F)))
            table.AddCell(TextCell(styles, DescriptionPhrase(styles, row)))
            table.AddCell(New PdfPCell(New Phrase(styles.Dot(row.AvailabilityTone, 12.0F))) With {.FixedHeight = RowHeight, .BorderColor = styles.Line,
                .HorizontalAlignment = Element.ALIGN_CENTER, .VerticalAlignment = Element.ALIGN_MIDDLE})
            table.AddCell(PriceCell(styles, row))
        Next
        doc.Add(table)
    End Sub

    Private Shared Function PhotoCell(ByVal styles As Styles, ByVal row As CatalogExportRow, ByVal withImages As Boolean) As PdfPCell
        If withImages Then
            Try
                ' Come la scheda del catalogo: la prima delle foto dell'articolo che esiste davvero sul sito.
                Dim bytes As Byte() = Nothing
                Dim allowResize As Boolean = (_clock Is Nothing OrElse _clock.Elapsed.TotalSeconds < ResizeBudgetSeconds)
                If row.ImageFiles IsNot Nothing Then
                    For Each candidate As String In row.ImageFiles
                        bytes = CatalogExportImages.LoadThumbnail(candidate, allowResize)
                        If bytes IsNot Nothing Then Exit For
                    Next
                End If
                If bytes IsNot Nothing Then
                    Dim img As iTextSharp.text.Image = iTextSharp.text.Image.GetInstance(bytes)
                    Return New PdfPCell(img, True) With {.FixedHeight = RowHeight, .BorderColor = styles.Line, .Padding = 2.0F,
                                                         .HorizontalAlignment = Element.ALIGN_CENTER, .VerticalAlignment = Element.ALIGN_MIDDLE}
                End If
            Catch
            End Try
        End If
        Return New PdfPCell() With {.FixedHeight = RowHeight, .BorderColor = styles.Line, .Padding = 2.0F}
    End Function

    Friend Shared Function IsRealEan(ByVal value As String) As Boolean
        If String.IsNullOrEmpty(value) OrElse value.Length < 8 OrElse value.Length > 14 Then Return False
        For Each ch As Char In value
            If ch < "0"c OrElse ch > "9"c Then Return False
        Next
        Return True
    End Function

    Private Shared Function NoWrapCell(ByVal styles As Styles, ByVal content As Phrase) As PdfPCell
        Return New PdfPCell(content) With {.FixedHeight = RowHeight, .BorderColor = styles.Line, .Padding = 3.0F, .VerticalAlignment = Element.ALIGN_MIDDLE, .NoWrap = True}
    End Function

    Private Shared Function TextCell(ByVal styles As Styles, ByVal content As Phrase) As PdfPCell
        Return New PdfPCell(content) With {.FixedHeight = RowHeight, .BorderColor = styles.Line, .Padding = 3.0F, .VerticalAlignment = Element.ALIGN_MIDDLE}
    End Function

    ' Larghezze di codice ed EAN calcolate sul valore PIU LUNGO del listino (stesse nelle due passate): il testo non va mai a capo ne esce dal campo.
    ' Il codice puo arrivare a MaxCodeColumn punti; oltre, il carattere si riduce quanto basta (minimo 4,5 pt).
    Private Const MaxCodeColumn As Single = 108.0F
    <ThreadStatic> Private Shared _codeColumn As Single
    <ThreadStatic> Private Shared _eanColumn As Single

    Private Shared Sub MeasureColumns(ByVal styles As Styles, ByVal rows As List(Of CatalogExportRow))
        Dim maxCode As Single = 40.0F
        Dim maxEan As Single = 40.0F
        For Each row As CatalogExportRow In rows
            Dim w As Single = styles.Bold.GetWidthPoint(Pdf(row.Code), 7.0F)
            If w > maxCode Then maxCode = w
            If IsRealEan(row.Ean) Then
                Dim e As Single = styles.Base.GetWidthPoint(row.Ean, 6.8F)
                If e > maxEan Then maxEan = e
            End If
        Next
        _codeColumn = Math.Min(MaxCodeColumn, maxCode + 8.0F)
        _eanColumn = maxEan + 8.0F
    End Sub

    Private Shared Function EanPhrase(ByVal styles As Styles, ByVal ean As String, ByVal availableWidth As Single) As Phrase
        If Not IsRealEan(ean) Then Return New Phrase("")
        Dim size As Single = 6.8F
        Dim width As Single = styles.Base.GetWidthPoint(ean, size)
        If width > availableWidth AndAlso width > 0.0F Then size = Math.Max(5.0F, size * availableWidth / width)
        Return New Phrase(ean, styles.F(size, False, styles.Muted))
    End Function

    ' Il codice sta sempre su UNA riga: se e lungo si riduce il carattere (minimo 4,5 pt) finche entra nella colonna.
    Private Shared Function CodePhrase(ByVal styles As Styles, ByVal row As CatalogExportRow, ByVal availableWidth As Single) As Phrase
        Dim text As String = Pdf(row.Code)
        Dim size As Single = 7.0F
        Dim width As Single = styles.Bold.GetWidthPoint(text, size)
        If width > availableWidth AndAlso width > 0.0F Then size = Math.Max(4.5F, size * availableWidth / width)
        Dim chunk As New Chunk(text, styles.F(size, True, styles.Accent))
        If Not String.IsNullOrEmpty(row.ProductUrl) Then chunk.SetAnchor(row.ProductUrl)
        Return New Phrase(chunk)
    End Function

    Private Shared Function DescriptionPhrase(ByVal styles As Styles, ByVal row As CatalogExportRow) As Phrase
        Dim p As New Phrase()
        p.Add(New Chunk(Pdf(row.Description), styles.F(8.5F, True, styles.Ink)))
        If Not String.IsNullOrEmpty(row.Detail) Then
            p.Add(New Chunk(vbLf & Pdf(row.Detail), styles.F(7.0F, False, styles.Muted)))
        End If
        Return p
    End Function

    Private Shared Function PriceCell(ByVal styles As Styles, ByVal row As CatalogExportRow) As PdfPCell
        Dim p As New Phrase()
        If Not row.HasPrice Then
            p.Add(New Chunk("Su richiesta", styles.F(8.5F, False, styles.Muted)))
        Else
            If row.IsOffer Then
                ' Riferimento offerta e validita sulla stessa riga: rosso solo se lo sconto e mostrato (regola unica del sito).
                Dim head As String = "OFFERTA"
                If row.OfferEndsOn.HasValue AndAlso Not String.IsNullOrEmpty(row.OfferLabel) Then head &= "  fino al " & row.OfferEndsOn.Value.ToString("dd/MM/yyyy", ItCulture)
                p.Add(New Chunk(head & vbLf, styles.F(6.5F, True, If(row.ShowsDiscount, styles.Sale, styles.Muted))))
            End If
            p.Add(New Chunk(Euro(row.Price), styles.F(10.5F, True, If(row.ShowsDiscount, styles.Sale, styles.Ink))))
            If row.ShowsDiscount Then
                Dim old As New Chunk(vbLf & Euro(row.ListPrice), styles.F(7.5F, False, styles.Muted))
                old.SetUnderline(0.5F, 2.6F)
                p.Add(old)
            End If
            If Not String.IsNullOrEmpty(row.TierNote) Then
                p.Add(New Chunk(vbLf & Pdf(row.TierNote), styles.F(6.5F, True, styles.Accent)))
            End If
        End If
        Return New PdfPCell(p) With {.FixedHeight = RowHeight, .BorderColor = styles.Line, .Padding = 3.0F, .HorizontalAlignment = Element.ALIGN_RIGHT, .VerticalAlignment = Element.ALIGN_MIDDLE}
    End Function

    Private Shared Function Euro(ByVal value As Decimal) As String
        Return ChrW(&H20AC) & " " & value.ToString("N2", ItCulture)
    End Function

    ' Solo caratteri codificabili in CP1252 (le altre lettere diventano "?").
    Private Shared Function Pdf(ByVal raw As String) As String
        If String.IsNullOrEmpty(raw) Then Return ""
        Dim encoding As System.Text.Encoding = System.Text.Encoding.GetEncoding(1252, New System.Text.EncoderReplacementFallback("?"), New System.Text.DecoderReplacementFallback("?"))
        Dim bytes As Byte() = encoding.GetBytes(raw)
        Return encoding.GetString(bytes)
    End Function
End Class
