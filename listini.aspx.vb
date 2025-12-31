Imports MySql.Data.MySqlClient
Imports System.Data
Imports iTextSharp.text
Imports iTextSharp.text.pdf

Imports System
Imports System.Text
Imports System.IO
Imports NPOI.HSSF.UserModel
Imports NPOI.HPSF
Imports NPOI.POIFS.FileSystem


Partial Class test
    Inherits System.Web.UI.Page

    Dim username As String

    Dim hssfworkbook As HSSFWorkbook 'Variabile per l'EXCEL

    Dim temp_stampa_settore As String = "" 'Variabile temporale per sapere l'ultima cosa scritta, utile per l'indice
    Dim temp_stampa_categoria As String = "" 'Variabile temporale per sapere l'ultima cosa scritta, utile per l'indice

    Dim Stampa_IVA As Integer = 0
    Dim dimensioneTabSx As Integer = 105
    Dim dimensioneTabDx As Integer = 105
    Dim tablePdf As PdfPTable
    Dim tableSx As PdfPTable
    Dim tableDx As PdfPTable
    Dim myDoc As Document
    Dim font_indice As Font = FontFactory.GetFont(FontFactory.HELVETICA, 12, Font.NORMAL, BaseColor.BLACK)
    Dim font_intestazione As Font = FontFactory.GetFont(FontFactory.COURIER, 10, Font.NORMAL, BaseColor.BLACK)
    Dim font_indice_link As Font = FontFactory.GetFont(FontFactory.HELVETICA, 7, Font.NORMAL, BaseColor.BLUE)
    Dim font_indice_link_settore As Font = FontFactory.GetFont(FontFactory.HELVETICA, 9, Font.BOLD, BaseColor.RED)
    Dim font_indice_link_categoria As Font = FontFactory.GetFont(FontFactory.HELVETICA, 8, Font.ITALIC, BaseColor.BLACK)

    'Enumerazione del tipo di arrotondamento desiderato
    Public Enum TipoArrotonda
        Difetto = 0
        Eccesso = 1
        Nessuno = 2
        Matematico = 3
    End Enum

    Function WriteToStream() As MemoryStream
        'Write the stream data of workbook to the root directory
        Dim File As MemoryStream = New MemoryStream()
        hssfworkbook.Write(File)
        Return File
    End Function

    Sub InitializeWorkbook()

        'read the template via FileStream, it is suggested to use FileAccess.Read to prevent file lock.
        'book1.xls is an Excel-2007-generated file, so some new unknown BIFF records are added. 
        Dim file As FileStream = New FileStream(Server.MapPath("Public/xls_template/modelloPreventivo.xls"), FileMode.Open, FileAccess.Read)

        hssfworkbook = New HSSFWorkbook(file)

        'create a entry of DocumentSummaryInformation
        Dim dsi As DocumentSummaryInformation = PropertySetFactory.CreateDocumentSummaryInformation()
        dsi.Company = "NPOI Team"
        hssfworkbook.DocumentSummaryInformation = dsi

        'create a entry of SummaryInformation
        Dim si As SummaryInformation = PropertySetFactory.CreateSummaryInformation()
        si.Subject = "NPOI SDK Example"
        hssfworkbook.SummaryInformation = si

    End Sub
    Function Arrotonda(ByVal Valore As Double, ByVal Arrotondamento As Double, Optional ByVal Direzione As TipoArrotonda = TipoArrotonda.Eccesso) As Double
        On Error Resume Next
        Dim Temp As Double

        If (Direzione <> 2) Then 'Controllo se devo arrotondare o meno
            Temp = Valore / Arrotondamento
            If Int(Temp) = Temp Then
                Arrotonda = Valore
            Else
                Select Case Direzione
                    Case TipoArrotonda.Difetto
                        Temp = Int(Temp)
                    Case TipoArrotonda.Eccesso
                        Temp = Int(Temp) + 1
                    Case TipoArrotonda.Matematico
                        Temp = CDbl(Format(Temp, "0"))
                End Select
                Arrotonda = Temp * Arrotondamento
            End If
        Else
            Return Valore
        End If
    End Function

    Protected Sub nuovaRiga(ByVal codice As String, ByVal descrizione As String, ByVal disp As String, ByVal prezzo As String)

        'Troncamento
        codice = Left(codice.ToUpper, 12)
        descrizione = Left(descrizione.ToLower, 50)

        If dimensioneTabDx <= 0 Then
            'aggiungo la tabella al documento
            nuovoTop()
            myDoc.Add(tablePdf)
            nuovaPagina()
        End If

        If dimensioneTabSx > 0 Then
            'metto le 4 celle tabella sx
            Me.tableSx.AddCell(cellaCodice(codice))
            Me.tableSx.AddCell(cellaDescrizione(descrizione))
            Me.tableSx.AddCell(cellaDisp(disp))
            Me.tableSx.AddCell(cellaPrezzo(prezzo))
            Me.dimensioneTabSx -= 1
        Else
            'metto le 4 celle tabella dx
            Me.tableDx.AddCell(cellaCodice(codice))
            Me.tableDx.AddCell(cellaDescrizione(descrizione))
            Me.tableDx.AddCell(cellaDisp(disp))
            Me.tableDx.AddCell(cellaPrezzo(prezzo))
            Me.dimensioneTabDx -= 1
        End If
    End Sub

    Protected Sub nuovaRigaPromo(ByVal codice As String, ByVal descrizione As String, ByVal disp As String, ByVal prezzo As String, ByVal promoText() As String)
        Dim i As Integer = 0

        'Troncamento
        codice = Left(codice.ToUpper, 12)
        descrizione = Left(descrizione.ToLower, 50)

        If dimensioneTabDx <= 1 Then
            'aggiungo la tabella al documento
            nuovoTop()
            myDoc.Add(tablePdf)
            nuovaPagina()
        End If

        'Conto se riesco a stampare tutte le promo nella tabella sinistra
        Dim conteggio_promo As Integer = 0
        For i = 0 To promoText.Length - 1
            If promoText(i) <> "" Then
                conteggio_promo += 1
            End If
        Next

        If dimensioneTabSx > (1 + conteggio_promo) Then

            'metto le 4 celle tabella sx
            Me.tableSx.AddCell(cellaCodicePromo(codice))
            Me.tableSx.AddCell(cellaDescrizione(descrizione))
            Me.tableSx.AddCell(cellaDisp(disp))
            Me.tableSx.AddCell(cellaPrezzo(prezzo))
            For i = 0 To promoText.Length - 1
                If promoText(i) <> "" Then
                    Me.tableSx.AddCell(separatorePromo(promoText(i)))
                    Me.dimensioneTabSx -= 1
                End If
            Next
            Me.dimensioneTabSx -= 1
        Else
            'metto le 4 celle tabella dx
            Me.dimensioneTabSx = 0
            Me.tableDx.AddCell(cellaCodicePromo(codice))
            Me.tableDx.AddCell(cellaDescrizione(descrizione))
            Me.tableDx.AddCell(cellaDisp(disp))
            Me.tableDx.AddCell(cellaPrezzo(prezzo))
            For i = 0 To promoText.Length - 1
                If promoText(i) <> "" Then
                    Me.tableDx.AddCell(separatorePromo(promoText(i)))
                    Me.dimensioneTabDx -= 1
                End If
            Next
            Me.dimensioneTabDx -= 1

        End If

    End Sub

    Protected Sub nuovoTop()


        Dim p1 As Paragraph = New Paragraph()
        Dim click As Anchor

        'gli anchor hanno un Reference di tipo "#Settore-Categoria-Gruppo-Sottogruppo" (senza spazi tra i trattini)
        click = New Anchor(New Chunk("Torna all'indice", font_intestazione))
        click.Reference = "#Indice"
        p1.Add(click)

        Dim cell_titolo As New PdfPCell(p1)
        cell_titolo.HorizontalAlignment = Element.ALIGN_LEFT
        cell_titolo.BorderWidth = 1
        cell_titolo.BorderColor = BaseColor.BLACK
        cell_titolo.Colspan = 8
        cell_titolo.Padding = 1
        cell_titolo.PaddingBottom = 2

        tablePdf.AddCell(cell_titolo)
    End Sub

    Function sostituisci_caratteri_speciali(ByRef stringa As String) As String
        stringa = Server.HtmlDecode(stringa)
        stringa = stringa.Replace("~", "-")
        Return stringa
    End Function


    Protected Sub nuovaPagina()

        'la tabella vera e propria formata da 8 colonne di larghezze diverse
        tablePdf = New PdfPTable(New Single() {50, 50})

        'Per le tabelle, usare l'oggetto PdfPTable e non quello PdfTable, ha funzionalità nettamente migliori
        'importante ricordare che non esiste il concetto di riga, le tabelle sono formate da una serie di mattoncini(pdfcell)uniti.
        'attenzione che superare nell'assegnazione delle larghezze delle colonne il 100% da errore senza aprire il doc. 
        'Spesso lo fa anche se si sbaglia magari con il columnspan il totale delle cellette
        tablePdf.WidthPercentage = 100

        Dim Stringa_IVA As String
        If (Stampa_IVA = 0) Then
            Stringa_IVA = " (I prezzi sono da considerarsi IVA ESCLUSA)"
        Else
            Stringa_IVA = " (I prezzi sono da considerarsi IVA INCLUSA)"
        End If

        Dim cell_titolo As New PdfPCell(New Phrase(New Chunk("Listino Prezzi aggiornato al " & Date.Now.Day.ToString() & "/" & Date.Now.Month.ToString() & "/" & Date.Now.Year.ToString() & Stringa_IVA, font_intestazione)))
        cell_titolo.HorizontalAlignment = Element.ALIGN_LEFT
        cell_titolo.BorderWidth = 1
        cell_titolo.BorderColor = BaseColor.BLACK
        cell_titolo.Colspan = 8
        cell_titolo.Padding = 1
        cell_titolo.PaddingBottom = 2

        tablePdf.AddCell(cell_titolo)

        Dim columnsPercentageWidth() As Single = New Single() {20, 61, 7, 12}

        tableSx = New PdfPTable(columnsPercentageWidth)
        tableSx.WidthPercentage = 100
        tableDx = New PdfPTable(columnsPercentageWidth)
        tableDx.WidthPercentage = 100
        tablePdf.AddCell(tableSx)
        tablePdf.AddCell(tableDx)

        'creo una pagina nuova per verificare la scritta del numero di pagina in fondo al documento
        myDoc.NewPage()

        'reimposto la dimensione (in termini di righe) delle tabelle
        dimensioneTabSx = 105
        dimensioneTabDx = 105
    End Sub

    Protected Sub nuovoSeparatore(ByVal Settore As String, ByVal Categoria As String, ByVal Gruppo As String, ByVal Sottogruppo As String)
        'Sostituzione dei caratteri speciali
        Settore = sostituisci_caratteri_speciali(Settore)
        Categoria = sostituisci_caratteri_speciali(Categoria)
        Gruppo = sostituisci_caratteri_speciali(Gruppo)

        If dimensioneTabDx <= 2 Then
            'aggiungo la tabella al documento
            nuovoTop()
            myDoc.Add(tablePdf)
            nuovaPagina()
        End If

        If dimensioneTabSx > 1 Then
            tableSx.AddCell(separatore(Settore, Categoria, Gruppo, Sottogruppo))
            inserire_intestazione(tableSx)
            Me.dimensioneTabSx -= 2
        Else
            tableDx.AddCell(separatore(Settore, Categoria, Gruppo, Sottogruppo))
            inserire_intestazione(tableDx)
            Me.dimensioneTabDx -= 2
        End If

    End Sub

    Protected Sub nuovoIndice(ByVal Settore As String, ByVal Categoria As String, ByVal Gruppo As String, ByVal Sottogruppo As String, ByRef table As PdfPTable)
        'Sostituzione dei caratteri speciali
        Settore = sostituisci_caratteri_speciali(Settore)
        Categoria = sostituisci_caratteri_speciali(Categoria)
        Gruppo = sostituisci_caratteri_speciali(Gruppo)

        'Dim p1 As Paragraph = New Paragraph()
        Dim click As Object

        Dim tmpCell As PdfPCell = New PdfPCell()
        Dim p As Paragraph = New Paragraph()

        'gli anchor hanno un Reference di tipo "#Settore-Categoria-Gruppo-Sottogruppo" (senza spazi tra i trattini)
        If (Settore = "") And (Categoria = "") And (Gruppo = "") Then
            click = New Chunk("", font_indice_link)
        Else
            If Settore.Equals(temp_stampa_settore) Then
                If Categoria.Equals(temp_stampa_categoria) Then
                    click = New Anchor(New Chunk(Gruppo.ToUpper & Chr(13), font_indice_link))
                    tmpCell = New PdfPCell(CType(click, Anchor))
                Else
                    p.Add(New Chunk(Categoria.ToUpper & Chr(13), font_indice_link_categoria))
                    click = New Anchor(New Chunk(Gruppo.ToUpper, font_indice_link))
                    p.Add(click)
                    tmpCell = New PdfPCell(p)
                End If
            Else
                p.Add(New Chunk(Settore.ToUpper & Chr(13), font_indice_link_settore))
                p.Add(New Chunk(Categoria.ToUpper & Chr(13), font_indice_link_categoria))
                click = New Anchor(New Chunk(Gruppo.ToUpper, font_indice_link))
                p.Add(click)
                tmpCell = New PdfPCell(p)
                'tmpCell = New PdfPCell(CType(click, Anchor))
            End If
            click.Reference = "#" & Settore & "-" & Categoria & "-" & Gruppo & "-" & Sottogruppo
        End If

        'myDoc.Add(click)

        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        table.AddCell(tmpCell)

        'Dim e As Chunk
        'e.SetCharacterSpacing()

        'Per non ristampare lo stesso settore e categoria (lo stampa solo una volta)
        temp_stampa_settore = Settore
        temp_stampa_categoria = Categoria
    End Sub


    Protected Sub inserire_intestazione(ByRef table As PdfPTable)
        Dim tmpCell As PdfPCell
        Dim font_cella As Font = FontFactory.GetFont(FontFactory.HELVETICA, 7, Font.NORMAL, BaseColor.BLACK)

        tmpCell = New PdfPCell(New Phrase(New Chunk("Codice", font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        table.AddCell(tmpCell)
        tmpCell = New PdfPCell(New Phrase(New Chunk("Descrizione", font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 1
        tmpCell.PaddingTop = 0
        table.AddCell(tmpCell)
        tmpCell = New PdfPCell(New Phrase(New Chunk("Disp", font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        tmpCell.HorizontalAlignment = Element.ALIGN_RIGHT
        table.AddCell(tmpCell)
        tmpCell = New PdfPCell(New Phrase(New Chunk("Prezzo", font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        tmpCell.HorizontalAlignment = Element.ALIGN_RIGHT
        table.AddCell(tmpCell)
    End Sub

    Protected Function separatore(ByVal settore As String, ByVal categoria As String, ByVal gruppo As String, ByVal sottogruppo As String) As PdfPCell
        Dim tmpCell As PdfPCell
        Dim font_cella As Font = FontFactory.GetFont(FontFactory.HELVETICA, 6, Font.NORMAL, BaseColor.BLACK)

        'Controllo se è presente la tipologia per la STAMPA
        Dim temp As String
        If (gruppo <> "&nbsp;") Then
            temp = settore & " - " & categoria & " - " & gruppo
        Else
            temp = settore & " - " & categoria
        End If

        'Il testo di ogni separatore viene considerato come "anchor" nel listino
        Dim target As Anchor = New Anchor(New Phrase(New Chunk(Left(temp, 77), font_cella)))

        target.Name = settore & "-" & categoria & "-" & gruppo & "-" & sottogruppo

        tmpCell = New PdfPCell(target)
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        tmpCell.BackgroundColor = BaseColor.YELLOW
        tmpCell.Colspan = 4
        tmpCell.HorizontalAlignment = Element.ALIGN_CENTER
        Return tmpCell
    End Function

    Protected Function cellaCodice(ByVal text As String) As PdfPCell
        Dim tmpCell As PdfPCell
        Dim font_cella As Font = FontFactory.GetFont(FontFactory.HELVETICA, 6, Font.NORMAL, BaseColor.BLACK)

        tmpCell = New PdfPCell(New Phrase(New Chunk(text, font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        tmpCell.HorizontalAlignment = Element.ALIGN_LEFT
        Return tmpCell
    End Function

    Protected Function cellaCodicePromo(ByVal text As String) As PdfPCell
        Dim tmpCell As PdfPCell
        Dim font_cella As Font = FontFactory.GetFont(FontFactory.HELVETICA, 6, Font.NORMAL, BaseColor.BLACK)
        tmpCell = New PdfPCell(New Phrase(New Chunk(text, font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        Return tmpCell
    End Function

    Protected Function cellaDescrizione(ByVal text As String) As PdfPCell
        'Sostituzione dei caratteri speciali
        text = sostituisci_caratteri_speciali(text)
        
        Dim tmpCell As PdfPCell
        Dim font_cella As Font = FontFactory.GetFont(FontFactory.HELVETICA, 6, Font.NORMAL, BaseColor.BLACK)
        tmpCell = New PdfPCell(New Phrase(New Chunk(text, font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        tmpCell.HorizontalAlignment = Element.ALIGN_LEFT
        Return tmpCell
    End Function

    Protected Function cellaDisp(ByVal text As String) As PdfPCell
        Dim tmpCell As PdfPCell
        Dim font_cella As Font = FontFactory.GetFont(FontFactory.HELVETICA, 6, Font.NORMAL, BaseColor.BLACK)
        tmpCell = New PdfPCell(New Phrase(New Chunk(text, font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        tmpCell.HorizontalAlignment = Element.ALIGN_RIGHT
        Return tmpCell
    End Function

    Protected Function cellaPrezzo(ByVal text As String) As PdfPCell
        Dim tmpCell As PdfPCell
        Dim font_cella As Font = FontFactory.GetFont(FontFactory.HELVETICA, 6, Font.NORMAL, BaseColor.BLACK)
        tmpCell = New PdfPCell(New Phrase(New Chunk(text, font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        tmpCell.HorizontalAlignment = Element.ALIGN_RIGHT
        Return tmpCell
    End Function

    Protected Function separatorePromo(ByVal text As String) As PdfPCell
        Dim tmpCell As PdfPCell
        Dim font_cella As Font = FontFactory.GetFont(FontFactory.HELVETICA, 6, Font.BOLD, BaseColor.RED)

        tmpCell = New PdfPCell(New Phrase(New Chunk(text, font_cella)))
        tmpCell.BorderWidth = 0
        tmpCell.Padding = 0
        tmpCell.PaddingBottom = 1
        tmpCell.PaddingRight = 0
        tmpCell.PaddingTop = 0
        tmpCell.HorizontalAlignment = Element.ALIGN_CENTER
        tmpCell.Colspan = 4
        Return tmpCell
    End Function

    Protected Sub Aggiorna_Listino_Personalizzato(ByRef oggetto As Object)

        'Intercettazione del controllo che ha generato l'evento

        'CheckBox
        Dim tmpIdSettore As Label = oggetto.NamingContainer.FindControl("Label_IDSettore")
        Dim tmpIdCategoria As Label = oggetto.NamingContainer.FindControl("Label_IDCategoria")
        Dim tmpIdTipologia As Label = oggetto.NamingContainer.FindControl("Label_IDTipologia")
        Dim tmpAttivo As CheckBox = oggetto.NamingContainer.FindControl("CheckBox_Attivo")
        Dim tmpRicarico As TextBox = oggetto.NamingContainer.FindControl("TextBox_Ricarico")
        Dim tmpPromo As CheckBox = oggetto.NamingContainer.FindControl("CheckBox_Promo")

        'Assegno 0 ai controlli che non hanno valore
        If tmpIdSettore.Text = "" Then
            tmpIdSettore.Text = "0"
        End If
        If tmpIdCategoria.Text = "" Then
            tmpIdCategoria.Text = "0"
        End If
        If tmpIdTipologia.Text = "" Then
            tmpIdTipologia.Text = "0"
        End If
        '////////////////////////////////////////////

        'Controllo sui parametri passati
        'If (tmpRicarico.Text < 0) Then
        'tmpRicarico.Text = "0"
        'End If
        '-------------------------------

        Me.SqlData_Dettagli_Listino_Personalizzato.DeleteCommand = "DELETE FROM dettagli_listino_personalizzato WHERE (ID_Listino_Personalizzato = ?listinoPersonalizzato) AND (ID_Settore = ?settore) AND (ID_Categoria = ?categoria) AND (ID_Tipologia = ?tipologia)"
        Me.SqlData_Dettagli_Listino_Personalizzato.DeleteParameters.Add("?listinoPersonalizzato", Session("ID_Listino_Personalizzato"))
        Me.SqlData_Dettagli_Listino_Personalizzato.DeleteParameters.Add("?settore", tmpIdSettore.Text)
        Me.SqlData_Dettagli_Listino_Personalizzato.DeleteParameters.Add("?categoria", tmpIdCategoria.Text)
        Me.SqlData_Dettagli_Listino_Personalizzato.DeleteParameters.Add("?tipologia", tmpIdTipologia.Text)
        Me.SqlData_Dettagli_Listino_Personalizzato.Delete()

        If (oggetto.Equals(tmpAttivo)) And (tmpAttivo.Checked = False) Then
            Return
        End If

        Dim Valore_Promo As Integer = 0

        Dim ricarico As Double
        tmpRicarico.Text = tmpRicarico.Text.Replace(".", ",")
        ricarico = 0
        Double.TryParse(tmpRicarico.Text, ricarico) 'Converto in Double il contenuto di tmpRicarico, se c'è testo il valore è zero

        tmpAttivo.Checked = True
        If tmpPromo.Checked = True Then
            Valore_Promo = 1
        End If
        Me.SqlData_Dettagli_Listino_Personalizzato.InsertCommand = "INSERT INTO dettagli_listino_personalizzato (ID_Listino_Personalizzato, ID_Settore, ID_Categoria, ID_Tipologia, Promo, Ricarico) VALUES ( ?listinoPersonalizzato, ?settore, ?categoria, ?tipologia, ?valorePromo, ?ricarico)"
        Me.SqlData_Dettagli_Listino_Personalizzato.SelectParameters.Add("?listinoPersonalizzato", Session("ID_Listino_Personalizzato"))
        Me.SqlData_Dettagli_Listino_Personalizzato.SelectParameters.Add("?settore", tmpIdSettore.Text)
        Me.SqlData_Dettagli_Listino_Personalizzato.SelectParameters.Add("?categoria", tmpIdCategoria.Text)
        Me.SqlData_Dettagli_Listino_Personalizzato.SelectParameters.Add("?tipologia", tmpIdTipologia.Text)
        Me.SqlData_Dettagli_Listino_Personalizzato.SelectParameters.Add("?valorePromo", Valore_Promo)
        Me.SqlData_Dettagli_Listino_Personalizzato.SelectParameters.Add("?ricarico", ricarico.ToString.Replace(",", "."))
        Me.SqlData_Dettagli_Listino_Personalizzato.Insert()
    End Sub

    Protected Sub Azzera_Selezioni_Listino()
        Dim i As Integer

        For i = 0 To Me.GridView_ListinoCompleto.Rows.Count - 1
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(1).FindControl("CheckBox_Attivo"), CheckBox).Checked = False
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(2).FindControl("TextBox_Ricarico"), TextBox).Text = ""
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(3).FindControl("CheckBox_Promo"), CheckBox).Checked = False

            'Coloro a righe alterne
            If (i Mod 2) = 0 Then
                Me.GridView_ListinoCompleto.Rows(i).BackColor = Drawing.Color.Gainsboro
            Else
                Me.GridView_ListinoCompleto.Rows(i).BackColor = Drawing.Color.White
            End If
        Next
    End Sub

    Protected Sub GridView_ListinoCompleto_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView_ListinoCompleto.PreRender
        Dim i As Integer
        Dim temp As Label

        For i = 0 To Me.GridView_ListinoCompleto.Rows.Count - 1
            temp = Me.GridView_ListinoCompleto.Rows(i).FindControl("Label3")

            If ((temp.Text <> "") And (Me.Page.IsPostBack = False)) Then
                temp.Text = "> " & temp.Text
                temp.Font.Bold = True
            Else
                temp = Me.GridView_ListinoCompleto.Rows(i).FindControl("Label2")
                temp.Font.Bold = True
            End If
        Next
    End Sub

    Protected Sub Preleva_listino(ByVal Tipo_Listino As Integer) '1 per stampare il PDF e 2 per stampare EXCEL, RICORDARSI -> Per le proprietà di stampa bisogna impostare la riga con codice 0 nella tabella "dettagli_listino_personalizzati"
        'Stampare o meno l'iva
        Stampa_IVA = Session.Item("IvaTipo")

        'Seleziono gli elementi da stampare
        Me.SqlData_SettoriCategorieTipologieSelezionati.SelectCommand = "SELECT Descr_Settore, Descr_Categoria, Descr_Tipologia FROM vcategorietipologie GROUP BY Descr_Tipologia ORDER BY Descr_Settore, Descr_Categoria, Descr_Tipologia"

        'Seleziono il listino da stampare, per impostare le proprietà di stampa del Listino Pubblico da prelevare, dovrò impostare in dettagli_listino_personalizzato le mie impostazioni all'ID_listino_personalizzato uguale a 0
        If (Session.Item("UtentiId") > 0) Then
            Me.SqlData_ListinoDaStampare.SelectCommand = "SELECT vsuperarticoli.id, vsuperarticoli.Codice, vsuperarticoli.Descrizione1, vsuperarticoli.MarcheDescrizione, vsuperarticoli.SettoriId, vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieId, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieId, vsuperarticoli.TipologieDescrizione, vsuperarticoli.GruppiId, vsuperarticoli.GruppiDescrizione, vsuperarticoli.SottoGruppiId, vsuperarticoli.SottogruppiDescrizione, vsuperarticoli.ArticoliIva, vsuperarticoli.Giacenza, vsuperarticoli.InOrdine, vsuperarticoli.Disponibilita, vsuperarticoli.Impegnata, vsuperarticoli.ArticoliListiniId, vsuperarticoli.NListino, vsuperarticoli.Prezzo, vsuperarticoli.PrezzoIvato, vsuperarticoli.OfferteID, vsuperarticoli.OfferteDettagliId, vsuperarticoli.OfferteDescrizione, vsuperarticoli.OfferteDataInizio, vsuperarticoli.OfferteDataFine, vsuperarticoli.OfferteDaListino, vsuperarticoli.OfferteAListino, vsuperarticoli.OfferteQntMinima, vsuperarticoli.OfferteMultipli, vsuperarticoli.OffertePrezzo, vsuperarticoli.OfferteSconto, vsuperarticoli.InOfferta, vsuperarticoli.PrezzoPromo, vsuperarticoli.PrezzoPromoIvato, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.Promo, dettagli_listino_personalizzato.Ricarico FROM vsuperarticoli, dettagli_listino_personalizzato WHERE (vsuperarticoli.NListino = ?listino) AND (dettagli_listino_personalizzato.ID_Listino_Personalizzato = 0) ORDER BY vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieDescrizione, vsuperarticoli.MarcheId, vsuperarticoli.Descrizione1, vsuperarticoli.id, vsuperarticoli.OfferteMultipli"
            Me.SqlData_ListinoDaStampare.SelectParameters.Add("?listino", Me.Session("listino"))
        Else
            If Me.Session("AziendaID") = 1 Then
                Me.SqlData_ListinoDaStampare.SelectCommand = "SELECT vsuperarticoli.id, vsuperarticoli.Codice, vsuperarticoli.Descrizione1, vsuperarticoli.MarcheDescrizione, vsuperarticoli.SettoriId, vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieId, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieId, vsuperarticoli.TipologieDescrizione, vsuperarticoli.GruppiId, vsuperarticoli.GruppiDescrizione, vsuperarticoli.SottoGruppiId, vsuperarticoli.SottogruppiDescrizione, vsuperarticoli.ArticoliIva, vsuperarticoli.Giacenza, vsuperarticoli.InOrdine, vsuperarticoli.Disponibilita, vsuperarticoli.Impegnata, vsuperarticoli.ArticoliListiniId, vsuperarticoli.NListino, vsuperarticoli.Prezzo, vsuperarticoli.PrezzoIvato, vsuperarticoli.OfferteID, vsuperarticoli.OfferteDettagliId, vsuperarticoli.OfferteDescrizione, vsuperarticoli.OfferteDataInizio, vsuperarticoli.OfferteDataFine, vsuperarticoli.OfferteDaListino, vsuperarticoli.OfferteAListino, vsuperarticoli.OfferteQntMinima, vsuperarticoli.OfferteMultipli, vsuperarticoli.OffertePrezzo, vsuperarticoli.OfferteSconto, vsuperarticoli.InOfferta, vsuperarticoli.PrezzoPromo, vsuperarticoli.PrezzoPromoIvato, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.Promo, dettagli_listino_personalizzato.Ricarico FROM vsuperarticoli, dettagli_listino_personalizzato WHERE (vsuperarticoli.NListino = 1) AND (dettagli_listino_personalizzato.ID_Listino_Personalizzato = 0) ORDER BY vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieDescrizione, vsuperarticoli.MarcheId, vsuperarticoli.Descrizione1, vsuperarticoli.id, vsuperarticoli.OfferteMultipli"
            End If
            If Me.Session("AziendaID") = 2 Then
                Me.SqlData_ListinoDaStampare.SelectCommand = "SELECT vsuperarticoli.id, vsuperarticoli.Codice, vsuperarticoli.Descrizione1, vsuperarticoli.MarcheDescrizione, vsuperarticoli.SettoriId, vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieId, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieId, vsuperarticoli.TipologieDescrizione, vsuperarticoli.GruppiId, vsuperarticoli.GruppiDescrizione, vsuperarticoli.SottoGruppiId, vsuperarticoli.SottogruppiDescrizione, vsuperarticoli.ArticoliIva, vsuperarticoli.Giacenza, vsuperarticoli.InOrdine, vsuperarticoli.Disponibilita, vsuperarticoli.Impegnata, vsuperarticoli.ArticoliListiniId, vsuperarticoli.NListino, vsuperarticoli.Prezzo, vsuperarticoli.PrezzoIvato, vsuperarticoli.OfferteID, vsuperarticoli.OfferteDettagliId, vsuperarticoli.OfferteDescrizione, vsuperarticoli.OfferteDataInizio, vsuperarticoli.OfferteDataFine, vsuperarticoli.OfferteDaListino, vsuperarticoli.OfferteAListino, vsuperarticoli.OfferteQntMinima, vsuperarticoli.OfferteMultipli, vsuperarticoli.OffertePrezzo, vsuperarticoli.OfferteSconto, vsuperarticoli.InOfferta, vsuperarticoli.PrezzoPromo, vsuperarticoli.PrezzoPromoIvato, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.Promo, dettagli_listino_personalizzato.Ricarico FROM vsuperarticoli, dettagli_listino_personalizzato WHERE (vsuperarticoli.NListino = 10) AND (dettagli_listino_personalizzato.ID_Listino_Personalizzato = 0) ORDER BY vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieDescrizione, vsuperarticoli.MarcheId, vsuperarticoli.Descrizione1, vsuperarticoli.id, vsuperarticoli.OfferteMultipli"
            End If
        End If

        Dim i As Integer

        'Controllare se esiste
        Dim temp_selezione As String = ""
        Dim ricarico As Double = 0
        Dim prezzo As Double = 0
        Dim prezzo_promo As Double = 0
        Dim prezzo_promo_multipla As Double = 0

        'Inserimento dell'intestazione dell'azienda max 5 righe
        Dim RagioneSociale As Label = Me.FormView_InfoUtente.FindControl("RagioneSocialeLabel")
        Dim CognomeNome As Label = Me.FormView_InfoUtente.FindControl("CognomeNomeLabel")
        Dim PIVA As Label = Me.FormView_InfoUtente.FindControl("PivaLabel")
        Dim Città As Label = Me.FormView_InfoUtente.FindControl("CittaLabel")
        Dim Indirizzo As Label = Me.FormView_InfoUtente.FindControl("IndirizzoLabel")
        Dim Provincia As Label = Me.FormView_InfoUtente.FindControl("ProvinciaLabel")
        Dim CAP As Label = Me.FormView_InfoUtente.FindControl("CapLabel")
        Dim CodiceFiscale As Label = Me.FormView_InfoUtente.FindControl("CodiceFiscaleLabel")
        Dim Telefono As Label = Me.FormView_InfoUtente.FindControl("CittaLabel")
        Dim Cellulare As Label = Me.FormView_InfoUtente.FindControl("CellulareLabel")
        Dim fax As Label = Me.FormView_InfoUtente.FindControl("FaxLabel")
        Dim email As Label = Me.FormView_InfoUtente.FindControl("EmailLabel")
        Dim URL As Label = Me.FormView_InfoUtente.FindControl("URLLabel")

        Dim TipoArrotondamento As Integer

        'nome file
        Dim nomefile As String = "Listino_" & Date.Now.Day & "_" & Date.Now.Month & "_" & Date.Now.Year & ".pdf"
        Dim filename As String = "Listino_" & Date.Now.Day & "_" & Date.Now.Month & "_" & Date.Now.Year & ".xls"

        If (Tipo_Listino = 1) Then
            Try
                Response.Clear()
                Response.AddHeader("content-disposition", String.Format("attachment; filename={0}", nomefile))
                Response.ContentType = "application/pdf"

                'creo il documento itextsharp
                myDoc = New Document(PageSize.A4, 25, 25, 25, 25)

                'creo il writer
                Dim pwr As PdfWriter = PdfWriter.GetInstance(myDoc, HttpContext.Current.Response.OutputStream)

                myDoc.Open()

                Dim fileTrovato As String = Me.findUserLogo(username)
                Dim img As Image
                img = Image.GetInstance(Server.MapPath(Me.Session("AziendaLogo")))

                If (fileTrovato <> "") Then
                    'metto l'immagine dentro alla celletta riducendola
                    img = Image.GetInstance(Server.MapPath("Public/Logo_Listini/" & fileTrovato))
                End If

                ' Dimensione massima dell'immagine 80px
                img.ScalePercent(80 * 100 / img.Height)

                img.Alignment = Element.ALIGN_CENTER

                'Aggiunge il logo al pdf
                myDoc.Add(img)

                If Session.Item("UtentiID") > 0 Then
                    myDoc.Add(New Paragraph(String.Format("Ragione Sociale : {0,-35}", RagioneSociale.Text) & String.Format(" Tel      : {0,-25}", Telefono.Text), font_intestazione))
                    myDoc.Add(New Paragraph(String.Format("Nome            : {0,-35}", CognomeNome.Text) & String.Format(" Fax      : {0,-25}", fax.Text), font_intestazione))
                    myDoc.Add(New Paragraph(String.Format("P.IVA           : {0,-35}", PIVA.Text) & String.Format(" Cell     : {0,-25}", Cellulare.Text), font_intestazione))
                    myDoc.Add(New Paragraph(String.Format("Indirizzo       : {0,-35}", Indirizzo.Text) & String.Format(" e-mail   : {0,-25}", email.Text), font_intestazione))
                    myDoc.Add(New Paragraph(String.Format("                : {0,-35}", Città.Text & " (" & Provincia.Text & "), " & CAP.Text) & String.Format(" Sito Web : {0,-25}", URL.Text), font_intestazione))

                    myDoc.Add(New Paragraph(vbCrLf))
                End If
                '---------------------------------------------------------------------------------

                Dim columns As MultiColumnText = New MultiColumnText()

                'float left, float right, float gutterwidth, int numcolumns

                columns.AddRegularColumns(30.0F, myDoc.PageSize.Width - 1.0F, 1.0F, 4)
                Dim tPdf As PdfPTable = New PdfPTable(New Single() {100})
                columns.AddElement(tPdf)

                '---------------------------------------------------------------------------------

                '----------------------------------------[ Inizio Indice ]-----------------------------

                Dim targetIndice As Anchor = New Anchor(New Phrase(New Chunk("Indice " & Chr(13) & Chr(13), font_indice)))
                targetIndice.Name = "Indice"
                myDoc.Add(targetIndice)

                For i = 0 To Me.GridView_SettoriCategorieTipologieSelezionati.Rows.Count - 1
                    nuovoIndice(Me.GridView_SettoriCategorieTipologieSelezionati.Rows(i).Cells(0).Text, Me.GridView_SettoriCategorieTipologieSelezionati.Rows(i).Cells(1).Text, Me.GridView_SettoriCategorieTipologieSelezionati.Rows(i).Cells(2).Text, "", tPdf)
                Next


                myDoc.Add(columns)

                nuovaPagina()
                '----------------------------------------[ Fine Indice ]-----------------------------

                'Controllare se esiste
                temp_selezione = ""
                ricarico = 0
                prezzo = 0
                prezzo_promo = 0
                prezzo_promo_multipla = 0

                'Seleziono il tipo di arrotondamento
                TipoArrotondamento = TipoArrotonda.Nessuno
                '------------------------------------

                Dim j As Integer
                For i = 0 To Me.GridView_ListinoDaStampare.Rows.Count - 1

                    If temp_selezione.Contains(Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text) = False Then
                        nuovoSeparatore(Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text, "")
                    End If

                    ricarico = Double.Parse(Me.GridView_ListinoDaStampare.Rows(i).Cells(38).Text)

                    'Controllo se devo stampare il prezzo con IVA o meno
                    If Session("IvaTipo") = 0 Then
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(21).Text, prezzo)
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(35).Text, prezzo_promo)
                        If i < Me.GridView_ListinoDaStampare.Rows.Count - 1 Then
                            Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + 1).Cells(35).Text, prezzo_promo_multipla)
                        End If
                    Else
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(22).Text, prezzo)
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(36).Text, prezzo_promo)
                        If i < Me.GridView_ListinoDaStampare.Rows.Count - 1 Then
                            Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + 1).Cells(36).Text, prezzo_promo_multipla)
                        End If
                    End If
                    '------------------------------------------------------------------------------
                    'Controllo se Stampare o meno la Promo
                    Dim cont = 0 'variabile che rappresenta il numero delle promozioni da stampare

                    If (Me.GridView_ListinoDaStampare.Rows(i).Cells(39).Text = "0") Then 'Se promo uguale a 0, faccio una stampa normale di una riga
                        If (i > 1) Then
                            If (Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text <> Me.GridView_ListinoDaStampare.Rows(i - 1).Cells(1).Text) Then
                                nuovaRiga(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text, String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento)))
                            End If
                        Else
                            nuovaRiga(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text, String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento)))
                        End If
                    Else
                        If (Me.GridView_ListinoDaStampare.Rows(i).Cells(34).Text = "1") Then
                            'Resetto il vettore offerte
                            Dim offerte(20) As String
                            Dim x As Integer = 0
                            For x = 0 To offerte.Length - 1
                                offerte(x) = ""
                            Next
                            '-------------------------------
                            'Conteggio il numero di Promo Righe da stampare
                            cont = 0
                            While ((Me.GridView_ListinoDaStampare.Rows(i).Cells(0).Text) = (Me.GridView_ListinoDaStampare.Rows(i + cont + 1).Cells(0).Text))
                                cont += 1
                                If ((cont + i) <= (Me.GridView_ListinoDaStampare.Rows.Count - 1)) Then
                                    Exit While
                                End If
                            End While
                            '----------------------------------------------
                            'Stampa delle righe PROMO
                            For j = 0 To cont 'modificato a cont-1, prima era solo cont
                                'Controllo se devo stampare il prezzo con IVA o meno
                                If Session("IvaTipo") = "0" Then
                                    Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + j).Cells(35).Text, prezzo_promo)
                                Else
                                    Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + j).Cells(36).Text, prezzo_promo)
                                End If
                                'Controllo se stampare una Offerta a Quantità Min o Multipla
                                If (Me.GridView_ListinoDaStampare.Rows(i + j).Cells(30).Text) > 0 Then 'Offerta Quantità Minima
                                    offerte(j) = "PROMO dal " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(26).Text & " al " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(27).Text & " MIN. " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(30).Text & " pz. a € " & String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo_promo / 100) * ricarico) + (prezzo_promo), 0.1, TipoArrotondamento))
                                Else 'Offerta Quantità Multipla
                                    offerte(j) = "PROMO dal " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(26).Text & " al " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(27).Text & " MULTIPLI " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(31).Text & " pz. a € " & String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo_promo / 100) * ricarico) + (prezzo_promo), 0.1, TipoArrotondamento))
                                End If
                            Next
                            '------------------------------------------------

                            nuovaRigaPromo(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text, String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento)), offerte)
                            i = i + cont
                        Else
                            'Se non ci sono PROMO da stampare
                            nuovaRiga(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text, String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento)))
                        End If
                    End If
                    'i = i + cont - 1  'Incremento i per non stampare di nuovo l'articolo che presenta offerta a Quantità min e Multipla
                    'End If

                    '--------------------------------------------------------------------------------
                    'mi salvo cosa sto scrivendo per controllare se cambia la categoria-settore-tipologia
                    temp_selezione = (Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text)
                Next
                'Response.Flush()
                'Response.End()
            Catch ex As Exception
                'Response.Flush()
                'Response.End()
                'aggiungere l'ultima pagina al documento
                If (dimensioneTabDx <> 1) Or (dimensioneTabSx <> 1) Then
                    'aggiungo la tabella al documento
                    nuovoTop()
                    myDoc.NewPage()
                    myDoc.Add(tablePdf)
                End If

                'chiudo il documento
                myDoc.Close()
            Finally
                'aggiungere l'ultima pagina al documento
                If (dimensioneTabDx <> 1) Or (dimensioneTabSx <> 1) Then
                    'aggiungo la tabella al documento
                    nuovoTop()
                    myDoc.NewPage()
                    myDoc.Add(tablePdf)
                End If

                'chiudo il documento
                myDoc.Close()
            End Try
        End If 'Chiudo if -> se TipoListino=1
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Me.Label_Cambia_Esito.Visible = False
        Me.Label_Esito.Visible = False

        If Me.DropDownList_ListiniUtente.Items.Count > 0 Then
            Session("ID_Listino_Personalizzato") = Me.DropDownList_ListiniUtente.SelectedItem.Value
        End If


        If (Request.QueryString("f") <> "") Then
            'Me.Sql_ListaSettori.SelectCommand = "SELECT DISTINCT settori.id AS ID_Settore, settori.Descrizione, categorie.id AS ID_Categoria, categorie.Descrizione AS Categoria, tipologie.id AS ID_Tipologia, tipologie.Descrizione AS Tipologia, settori.Abilitato, tipologie.Abilitato AS Expr1, categorie.Abilitato AS Expr2 FROM categorie LEFT OUTER JOIN tipologie ON categorie.id = tipologie.CategorieId LEFT OUTER JOIN gruppi ON categorie.id = tipologie.CategorieId RIGHT OUTER JOIN settori ON categorie.SettoriId = settori.id WHERE (settori.id =" & Request.QueryString("f") & ")HAVING (settori.Abilitato > 0) AND (categorie.Abilitato > 0) OR (settori.Abilitato > 0) AND (tipologie.Abilitato > 0) OR (settori.Abilitato > 0) AND (categorie.Abilitato > 0) AND (tipologie.Abilitato > 0)"
            Me.Sql_ListaSettori.SelectCommand = "SELECT DISTINCT categorie.id AS Id_Categoria, categorie.Descrizione AS Categoria, tipologie.id AS Id_Tipologia, tipologie.Descrizione AS Tipologia, settori.id AS Id_Settore, settori.Descrizione AS Settore, articoli.Abilitato, settori.Abilitato AS Expr1 FROM articoli INNER JOIN settori ON articoli.SettoriId = settori.id INNER JOIN categorie ON articoli.CategorieId = categorie.id LEFT OUTER JOIN tipologie ON articoli.TipologieId = tipologie.id WHERE (settori.id =?settoriId) AND (articoli.Abilitato > 0) AND (categorie.Abilitato > 0) AND (settori.Abilitato > 0) ORDER BY Settore, Categoria, Tipologia"
            Me.Sql_ListaSettori.SelectParameters.Add("?settoriId", Request.QueryString("f"))
        End If

        Me.SqlData_InfoUtente.SelectCommand = "SELECT Id, Codice, TipoUtente, Azienda, RagioneSociale, CognomeNome, Piva, Indirizzo, Citta, Provincia, Cap, CodiceFiscale, Telefono, Cellulare, Fax, Email, Listino, Url, Privacy, Abilitato FROM vutenti WHERE (Abilitato > 0) AND (Id = ?utenteId)"
        Me.SqlData_InfoUtente.SelectParameters.Add("?utenteId", Session.Item("UtentiID"))

        '----------------------------------------------------------
        username = Session.Item("UtentiID")


        Dim fileTrovato As String = Me.findUserLogo(username)


        If (fileTrovato <> "") Then
            Me.logoListino.ImageUrl = "Public/Logo_Listini/" & fileTrovato
            Me.ButtonEliminaLogo.Enabled = True
            Me.FileUpload1.Enabled = False
            Me.ButtonInvio.Enabled = False
        Else
            Me.logoListino.ImageUrl = "Images/Immagini_Listini_Personalizzati/LogoAzienda/LogoNullo.png"
            Me.ButtonEliminaLogo.Enabled = False
            Me.FileUpload1.Enabled = True
            Me.ButtonInvio.Enabled = True
        End If
        '----------------------------------------------------------
    End Sub

    Protected Sub Page_PreLoad(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreLoad
        If Session.Item("AbilitaListino") > 0 Then
            Me.Panel_Principale.Visible = True
        End If
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        'Visualizzo la griglia
        Me.GridView_ListinoSelezionato.Visible = True
        Me.GridView_ProprietaListinoPersonalizzato.Visible = True
        Me.GridView_SettoriCategorieTipologieSelezionati.Visible = True
        Me.GridView_ListinoDaStampare.Visible = False

        'Genero le select appropriate
        Me.SqlData_ListaListiniUtente.SelectCommand = "SELECT ID, Nome_Listino, ID_Utente FROM listini_personalizzati WHERE (ID_Utente = ?utenteId)"
        Me.SqlData_ListaListiniUtente.SelectParameters.Add("?utenteId", Session.Item("UtentiID"))
        Me.SqlDataSource_ListinoSelezionato.SelectCommand = "SELECT dettagli_listino_personalizzato.ID, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.ID_Settore, dettagli_listino_personalizzato.ID_Categoria, dettagli_listino_personalizzato.ID_Tipologia, dettagli_listino_personalizzato.Promo, dettagli_listino_personalizzato.Ricarico, settori.Descrizione AS Descrizione_Settore, categorie.Descrizione AS Descrizione_Categoria, tipologie.Descrizione AS Descrizione_Tipologia FROM dettagli_listino_personalizzato INNER JOIN settori ON dettagli_listino_personalizzato.ID_Settore = settori.id INNER JOIN categorie ON dettagli_listino_personalizzato.ID_Categoria = categorie.id LEFT OUTER JOIN tipologie ON dettagli_listino_personalizzato.ID_Tipologia = tipologie.id WHERE (dettagli_listino_personalizzato.ID_Listino_Personalizzato = ?idListinoPersonalizzato) ORDER BY Descrizione_Settore, Descrizione_Categoria, Descrizione_Tipologia"
        Me.SqlDataSource_ListinoSelezionato.SelectParameters.Add("?idListinoPersonalizzato", Session.Item("ID_Listino_Personalizzato"))
        'Seleziono le proprietà del listino selezionato
        If (Me.GridView_ProprietaListinoPersonalizzato.Rows.Count > 0) And (Me.DropDownList_ListiniUtente.Items.Count > 0) Then
            Me.SqlData_ProprietaListinoSelezionato.SelectCommand = "SELECT ID, Nome_Listino, ID_Utente, IVA, Data_Creazione, Arrotonda FROM listini_personalizzati WHERE (ID = ?listinoUtente)"
            Me.SqlData_ProprietaListinoSelezionato.SelectParameters.Add("?listinoUtente", Me.DropDownList_ListiniUtente.SelectedItem.Value)
        Else
            Me.SqlData_ProprietaListinoSelezionato.SelectCommand = "SELECT ID, Nome_Listino, ID_Utente, IVA, Data_Creazione, Arrotonda FROM listini_personalizzati WHERE (ID = ?idListinoPersonalizzato)" 'Caso in cui non ci sono listini personali
            Me.SqlData_ProprietaListinoSelezionato.SelectParameters.Add("?idListinoPersonalizzato", Session.Item("ID_Listino_Personalizzato"))
        End If

        Azzera_Selezioni_Listino()

    End Sub

    Protected Sub Page_PreRenderComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRenderComplete

        'Se voglio prelevare direttamente il Listino, senza passare per la pagina "Listini personalizzati"
        't raprresenta il tipo di listino (PDF o excel)
        If Request.QueryString("stampa") = 3 Then
            If Request.QueryString("t") > 0 Then
                Preleva_listino(Request.QueryString("t"))
            Else
                Preleva_listino(1)
            End If
            Return
        End If

        'Salvo la selezione del listino sul postback della pagina
        Dim i As Integer
        For i = 0 To Me.DropDownList_ListiniUtente.Items.Count - 1
            If Me.DropDownList_ListiniUtente.Items(i).Value = Session("ID_Listino_Personalizzato") Then
                Me.DropDownList_ListiniUtente.SelectedIndex = i
            End If
        Next

        'Seleziono il Settore-Categorie-Tipologie in base alla selezione dell'utente
        'Valorizzo la label
        If Me.DropDownList_ListiniUtente.Items.Count > 0 Then
            Me.Label_SettoreSelezionato.Text = Me.DropDownList_ListiniUtente.SelectedItem.Text & " - " & Request.QueryString("n")
        End If

        'Seleziono, se esiste, il primo valore della lista dei listni personalizzati
        If (Session("ID_Listino_Personalizzato") = 0) And (Me.DropDownList_ListiniUtente.Items.Count > 0) Then
            Session("ID_Listino_Personalizzato") = Me.DropDownList_ListiniUtente.Items(0).Value
            'Genero la Select
            Me.SqlDataSource_ListinoSelezionato.SelectCommand = "SELECT dettagli_listino_personalizzato.ID, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.ID_Settore, dettagli_listino_personalizzato.ID_Categoria, dettagli_listino_personalizzato.ID_Tipologia, dettagli_listino_personalizzato.Promo, dettagli_listino_personalizzato.Ricarico, settori.Descrizione AS Descrizione_Settore, categorie.Descrizione AS Descrizione_Categoria, tipologie.Descrizione AS Descrizione_Tipologia FROM dettagli_listino_personalizzato INNER JOIN settori ON dettagli_listino_personalizzato.ID_Settore = settori.id INNER JOIN categorie ON dettagli_listino_personalizzato.ID_Categoria = categorie.id LEFT OUTER JOIN tipologie ON dettagli_listino_personalizzato.ID_Tipologia = tipologie.id WHERE (dettagli_listino_personalizzato.ID_Listino_Personalizzato = ?idListinoPersonalizzato) ORDER BY Descrizione_Settore, Descrizione_Categoria, Descrizione_Tipologia"
            Me.SqlDataSource_ListinoSelezionato.SelectParameters.Add("?idListinoPersonalizzato", Session.Item("ID_Listino_Personalizzato"))
            'Seleziono il Settore-Categorie-Tipologie in base alla selezione dell'utente
            Me.SqlData_SettoriCategorieTipologieSelezionati.SelectCommand = "SELECT settori.Descrizione AS `Descr_Settore`, categorie.Descrizione AS `Descr_Categoria`, tipologie.Descrizione AS `Descr_Tipologia`, dettagli_listino_personalizzato.ID_Listino_Personalizzato FROM dettagli_listino_personalizzato INNER JOIN settori ON dettagli_listino_personalizzato.ID_Settore = settori.id INNER JOIN categorie ON dettagli_listino_personalizzato.ID_Categoria = categorie.id INNER JOIN tipologie ON dettagli_listino_personalizzato.ID_Tipologia = tipologie.id WHERE (dettagli_listino_personalizzato.ID_Listino_Personalizzato = ?idListinoPersonalizzato) ORDER BY `Descr_Settore`, `Descr_Categoria`, `Descr_Tipologia`"
            Me.SqlData_SettoriCategorieTipologieSelezionati.SelectParameters.Add("?idListinoPersonalizzato", Session.Item("ID_Listino_Personalizzato"))
        End If

        'Nel caso in cui devo stampare il listino direttamente (senza passare per la pagina di gestione dei listini)

        Me.SqlData_SettoriCategorieTipologieSelezionati.SelectCommand = "SELECT settori.Descrizione AS `Descr_Settore`, categorie.Descrizione AS `Descr_Categoria`, tipologie.Descrizione AS `Descr_Tipologia`, dettagli_listino_personalizzato.ID_Listino_Personalizzato, articoli.Abilitato FROM dettagli_listino_personalizzato INNER JOIN settori ON dettagli_listino_personalizzato.ID_Settore = settori.id INNER JOIN categorie ON dettagli_listino_personalizzato.ID_Categoria = categorie.id INNER JOIN tipologie ON dettagli_listino_personalizzato.ID_Tipologia = tipologie.id INNER JOIN articoli ON dettagli_listino_personalizzato.ID_Settore = articoli.SettoriId AND dettagli_listino_personalizzato.ID_Categoria = articoli.CategorieId AND dettagli_listino_personalizzato.ID_Tipologia = articoli.TipologieId WHERE (dettagli_listino_personalizzato.ID_Listino_Personalizzato = idListinoPersonalizzato) AND (articoli.Abilitato > 0) GROUP BY `Descr_Tipologia` ORDER BY `Descr_Settore`, `Descr_Categoria`, `Descr_Tipologia`"
        Me.SqlData_SettoriCategorieTipologieSelezionati.SelectParameters.Add("?idListinoPersonalizzato", Session.Item("ID_Listino_Personalizzato"))
        'Cancello le selezioni precedenti
        If Me.DropDownList_ListiniUtente.Items.Count > 0 Then
            Me.TextBox_CambiaNomeListino.Text = Me.DropDownList_ListiniUtente.SelectedItem.Text
        End If

        If Me.GridView_ProprietaListinoPersonalizzato.Rows.Count <= 0 Then 'Controllo che sia la prima volta che apro la pagina
            If Me.DropDownList_ListiniUtente.Items.Count > 0 Then
                'Seleziono le proprietà del listino selezionato
                Me.SqlData_ProprietaListinoSelezionato.SelectCommand = "SELECT ID, Nome_Listino, ID_Utente, IVA, Data_Creazione, Arrotonda FROM listini_personalizzati WHERE (ID = ?listinoUtente)"
                Me.SqlData_ProprietaListinoSelezionato.SelectParameters.Add("?listinoUtente", Me.DropDownList_ListiniUtente.Items(Me.DropDownList_ListiniUtente.SelectedIndex).Value)
            Else
                Me.SqlData_ProprietaListinoSelezionato.SelectCommand = "SELECT ID, Nome_Listino, ID_Utente, IVA, Data_Creazione, Arrotonda FROM listini_personalizzati WHERE (ID = 0)"
            End If
        End If

        If Me.GridView_ProprietaListinoPersonalizzato.Rows.Count > 0 Then
            Stampa_IVA = Val(Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(3).Text)
            'Leggo le proprietà del Listino Utente
            If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(3).Text = "1" Then
                Me.CheckBox_IVA2.Checked = True
            Else
                Me.CheckBox_IVA2.Checked = False
            End If

            'Resetto le radio button
            Me.RadioButton_Difetto2.Checked = False
            Me.RadioButton_Eccesso2.Checked = False
            Me.RadioButton_Nessuno2.Checked = False

            If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "2" Then
                Me.RadioButton_Nessuno2.Checked = True
            End If
            If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "0" Then
                Me.RadioButton_Difetto2.Checked = True
            End If
            If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "1" Then
                Me.RadioButton_Eccesso2.Checked = True
            End If
        End If

        'Prelevo le selezioni effettuate precedentemente nel listino
        'Dim i As Integer

        Dim tmpSettore, tmpCategoria, tmpTipologia As String
        For i = 0 To (Me.GridView_ListinoSelezionato.Rows.Count) - 1
            Dim trovato As Integer = 0
            Dim cont As Integer = 0
            tmpSettore = Me.GridView_ListinoSelezionato.Rows(i).Cells(2).Text
            tmpCategoria = Me.GridView_ListinoSelezionato.Rows(i).Cells(3).Text
            tmpTipologia = Me.GridView_ListinoSelezionato.Rows(i).Cells(4).Text

            While ((trovato = 0) And (cont < Me.GridView_ListinoCompleto.Rows.Count))
                Dim re As String = CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDTipologia"), Label).Text
                'Se la Tipologia non è stata inserita nel DataBase la impostiamo a "0"
                If CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDTipologia"), Label).Text = "" Then
                    CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDTipologia"), Label).Text = "0"
                End If

                If ((tmpSettore = CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDSettore"), Label).Text) And (tmpCategoria = CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDCategoria"), Label).Text) And (tmpTipologia = CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDTipologia"), Label).Text)) Then

                    'Coloro la celletta selezionata
                    Me.GridView_ListinoCompleto.Rows(cont).BackColor = Drawing.Color.GreenYellow
                    Me.GridView_ListinoCompleto.Rows(cont).ForeColor = Drawing.Color.Black
                    trovato = 1 'L'oggetto è stato trovato ed esco dal ciclo
                    CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(1).FindControl("CheckBox_Attivo"), CheckBox).Checked = True
                    CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(2).FindControl("TextBox_Ricarico"), TextBox).Text = Me.GridView_ListinoSelezionato.Rows(i).Cells(6).Text
                    If (Me.GridView_ListinoSelezionato.Rows(i).Cells(5).Text = 1) Then
                        CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(3).FindControl("CheckBox_Promo"), CheckBox).Checked = True
                    End If
                End If
                cont = cont + 1
            End While
        Next

        '////////////////////////////////////////////////////////////////////////////////////////////////
        'Dim i As Integer
        'Dim tmpSettore, tmpCategoria, tmpTipologia As String

        If (Me.GridView_ListinoSelezionato.Rows.Count > 0) Then
            Me.SqlData_ListinoDaStampare.SelectCommand = "SELECT vsuperarticoli.id, vsuperarticoli.Codice, vsuperarticoli.Descrizione1, vsuperarticoli.MarcheDescrizione, vsuperarticoli.SettoriId, vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieId, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieId, vsuperarticoli.TipologieDescrizione, vsuperarticoli.GruppiId, vsuperarticoli.GruppiDescrizione, vsuperarticoli.SottoGruppiId, vsuperarticoli.SottogruppiDescrizione, vsuperarticoli.ArticoliIva, vsuperarticoli.Giacenza, vsuperarticoli.InOrdine, vsuperarticoli.Disponibilita, vsuperarticoli.Impegnata, vsuperarticoli.ArticoliListiniId, vsuperarticoli.NListino, vsuperarticoli.Prezzo, vsuperarticoli.PrezzoIvato, vsuperarticoli.OfferteID, vsuperarticoli.OfferteDettagliId, vsuperarticoli.OfferteDescrizione, vsuperarticoli.OfferteDataInizio, vsuperarticoli.OfferteDataFine, vsuperarticoli.OfferteDaListino, vsuperarticoli.OfferteAListino, vsuperarticoli.OfferteQntMinima, vsuperarticoli.OfferteMultipli, vsuperarticoli.OffertePrezzo, vsuperarticoli.OfferteSconto, vsuperarticoli.InOfferta, vsuperarticoli.PrezzoPromo, vsuperarticoli.PrezzoPromoIvato, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.Ricarico, dettagli_listino_personalizzato.Promo FROM vsuperarticoli LEFT OUTER JOIN dettagli_listino_personalizzato ON vsuperarticoli.SettoriId = dettagli_listino_personalizzato.ID_Settore AND vsuperarticoli.CategorieId = dettagli_listino_personalizzato.ID_Categoria AND (IF(dettagli_listino_personalizzato.ID_Tipologia>0,vsuperarticoli.TipologieId = dettagli_listino_personalizzato.ID_Tipologia,1=1)) WHERE (dettagli_listino_personalizzato.ID_Listino_Personalizzato = ?idListinoPersonalizzato) AND (vsuperarticoli.NListino = ?listino) ORDER BY vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieDescrizione, vsuperarticoli.MarcheId, vsuperarticoli.Descrizione1, vsuperarticoli.id, vsuperarticoli.OfferteMultipli"
            Me.SqlData_ListinoDaStampare.SelectParameters.Add("?idListinoPersonalizzato", Session.Item("ID_Listino_Personalizzato"))
            Me.SqlData_ListinoDaStampare.SelectParameters.Add("?listino", Me.Session("listino"))
        Else
            Me.SqlData_ListinoDaStampare.SelectCommand = "SELECT vsuperarticoli.id, vsuperarticoli.Codice, vsuperarticoli.Descrizione1, vsuperarticoli.MarcheDescrizione, vsuperarticoli.SettoriId, vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieId, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieId, vsuperarticoli.TipologieDescrizione, vsuperarticoli.GruppiId, vsuperarticoli.GruppiDescrizione, vsuperarticoli.SottoGruppiId, vsuperarticoli.SottogruppiDescrizione, vsuperarticoli.ArticoliIva, vsuperarticoli.Giacenza, vsuperarticoli.InOrdine, vsuperarticoli.Disponibilita, vsuperarticoli.Impegnata, vsuperarticoli.ArticoliListiniId, vsuperarticoli.NListino, vsuperarticoli.Prezzo, vsuperarticoli.PrezzoIvato, vsuperarticoli.OfferteID, vsuperarticoli.OfferteDettagliId, vsuperarticoli.OfferteDescrizione, vsuperarticoli.OfferteDataInizio, vsuperarticoli.OfferteDataFine, vsuperarticoli.OfferteDaListino, vsuperarticoli.OfferteAListino, vsuperarticoli.OfferteQntMinima, vsuperarticoli.OfferteMultipli, vsuperarticoli.OffertePrezzo, vsuperarticoli.OfferteSconto, vsuperarticoli.InOfferta, vsuperarticoli.PrezzoPromo, vsuperarticoli.PrezzoPromoIvato, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.Ricarico, dettagli_listino_personalizzato.Promo FROM vsuperarticoli LEFT OUTER JOIN dettagli_listino_personalizzato ON vsuperarticoli.SettoriId = dettagli_listino_personalizzato.ID_Settore AND vsuperarticoli.CategorieId = dettagli_listino_personalizzato.ID_Categoria AND vsuperarticoli.TipologieId = dettagli_listino_personalizzato.ID_Tipologia WHERE (dettagli_listino_personalizzato.ID_Listino_Personalizzato = 0) AND (vsuperarticoli.NListino = 0) ORDER BY vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieDescrizione, vsuperarticoli.MarcheId, vsuperarticoli.Descrizione1, vsuperarticoli.id, vsuperarticoli.OfferteMultipli"
        End If

        'nome file
        Dim nomefile As String
        Dim filename As String
        If (Me.DropDownList_ListiniUtente.Items.Count > 0) Then
            nomefile = Me.DropDownList_ListiniUtente.SelectedItem.Text & "_" & Date.Now.Day & "_" & Date.Now.Month & "_" & Date.Now.Year & ".pdf"
            filename = Me.DropDownList_ListiniUtente.SelectedItem.Text & "_" & Date.Now.Day & "_" & Date.Now.Month & "_" & Date.Now.Year & ".xls"
        Else
            nomefile = "Listino_" & Date.Now.Day & "_" & Date.Now.Month & "_" & Date.Now.Year & ".pdf"
            filename = "Listino_" & Date.Now.Day & "_" & Date.Now.Month & "_" & Date.Now.Year & ".xls"
        End If

        'Controllare se esiste
        Dim temp_selezione As String = ""
        Dim ricarico As Double = 0
        Dim prezzo As Double = 0
        Dim prezzo_promo As Double = 0
        Dim prezzo_promo_multipla As Double = 0


        'Inserimento dell'intestazione dell'azienda max 5 righe
        Dim RagioneSociale As Label = Me.FormView_InfoUtente.FindControl("RagioneSocialeLabel")
        Dim CognomeNome As Label = Me.FormView_InfoUtente.FindControl("CognomeNomeLabel")
        Dim PIVA As Label = Me.FormView_InfoUtente.FindControl("PivaLabel")
        Dim Città As Label = Me.FormView_InfoUtente.FindControl("CittaLabel")
        Dim Indirizzo As Label = Me.FormView_InfoUtente.FindControl("IndirizzoLabel")
        Dim Provincia As Label = Me.FormView_InfoUtente.FindControl("ProvinciaLabel")
        Dim CAP As Label = Me.FormView_InfoUtente.FindControl("CapLabel")
        Dim CodiceFiscale As Label = Me.FormView_InfoUtente.FindControl("CodiceFiscaleLabel")
        Dim Telefono As Label = Me.FormView_InfoUtente.FindControl("CittaLabel")
        Dim Cellulare As Label = Me.FormView_InfoUtente.FindControl("CellulareLabel")
        Dim fax As Label = Me.FormView_InfoUtente.FindControl("FaxLabel")
        Dim email As Label = Me.FormView_InfoUtente.FindControl("EmailLabel")
        Dim URL As Label = Me.FormView_InfoUtente.FindControl("URLLabel")

        Dim TipoArrotondamento As Integer

        If (Request.QueryString("stampa") = 1) And (Session.Item("UtentiID") > 0) Then
            Try
                Response.Clear()
                Response.AddHeader("content-disposition", String.Format("attachment; filename={0}", nomefile))
                Response.ContentType = "application/pdf"

                'creo il documento itextsharp
                myDoc = New Document(PageSize.A4, 25, 25, 25, 25)



                'creo il writer
                Dim pwr As PdfWriter = PdfWriter.GetInstance(myDoc, HttpContext.Current.Response.OutputStream)

                myDoc.Open()

                Dim fileTrovato As String = Me.findUserLogo(username)

                Dim img As Image = Image.GetInstance(Server.MapPath("Images/Immagini_Listini_Personalizzati/LogoAzienda/LogoNullo.png"))
                If (fileTrovato <> "") Then
                    'metto l'immagine dentro alla celletta riducendola
                    img = Image.GetInstance(Server.MapPath("Public/Logo_Listini/" & fileTrovato))
                End If

                ' Dimensione massima dell'immagine 80px
                img.ScalePercent(80 * 100 / img.Height)

                img.Alignment = Element.ALIGN_CENTER

                'Aggiunge il logo al pdf
                myDoc.Add(img)

                myDoc.Add(New Paragraph(String.Format("Ragione Sociale : {0,-35}", RagioneSociale.Text) & String.Format(" Tel      : {0,-25}", Telefono.Text), font_intestazione))
                myDoc.Add(New Paragraph(String.Format("Nome            : {0,-35}", CognomeNome.Text) & String.Format(" Fax      : {0,-25}", fax.Text), font_intestazione))
                myDoc.Add(New Paragraph(String.Format("P.IVA           : {0,-35}", PIVA.Text) & String.Format(" Cell     : {0,-25}", Cellulare.Text), font_intestazione))
                myDoc.Add(New Paragraph(String.Format("Indirizzo       : {0,-35}", Indirizzo.Text) & String.Format(" e-mail   : {0,-25}", email.Text), font_intestazione))
                myDoc.Add(New Paragraph(String.Format("                : {0,-35}", Città.Text & " (" & Provincia.Text & "), " & CAP.Text) & String.Format(" Sito Web : {0,-25}", URL.Text), font_intestazione))
                myDoc.Add(New Paragraph(vbCrLf))

                '---------------------------------------------------------------------------------

                Dim columns As MultiColumnText = New MultiColumnText()

                'float left, float right, float gutterwidth, int numcolumns

                columns.AddRegularColumns(30.0F, myDoc.PageSize.Width - 1.0F, 1.0F, 4)
                Dim tPdf As PdfPTable = New PdfPTable(New Single() {100})
                columns.AddElement(tPdf)

                '---------------------------------------------------------------------------------

                '----------------------------------------[ Inizio Indice ]-----------------------------

                Dim targetIndice As Anchor = New Anchor(New Phrase(New Chunk("Indice " & Chr(13) & Chr(13), font_indice)))
                targetIndice.Name = "Indice"
                myDoc.Add(targetIndice)

                'myDoc.Add(New Chunk("Settore" & Chr(13), font_indice_link_settore))
                'myDoc.Add(New Chunk("Categoria" & Chr(13), font_indice_link_categoria))
                'myDoc.Add(New Chunk("Gruppo" & Chr(13) & Chr(13), font_indice_link))

                'Dim i As Integer
                For i = 0 To Me.GridView_SettoriCategorieTipologieSelezionati.Rows.Count - 1
                    'If (i Mod 2) = 0 Then
                    'nuovoIndice("", "", "", "")
                    'End If
                    nuovoIndice(Me.GridView_SettoriCategorieTipologieSelezionati.Rows(i).Cells(0).Text, Me.GridView_SettoriCategorieTipologieSelezionati.Rows(i).Cells(1).Text, Me.GridView_SettoriCategorieTipologieSelezionati.Rows(i).Cells(2).Text, "", tPdf)
                Next


                myDoc.Add(columns)

                nuovaPagina()
                '----------------------------------------[ Fine Indice ]-----------------------------

                'Controllare se esiste
                temp_selezione = ""
                ricarico = 0
                prezzo = 0
                prezzo_promo = 0
                prezzo_promo_multipla = 0

                'Seleziono il tipo di arrotondamento
                If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "0" Then
                    TipoArrotondamento = TipoArrotonda.Difetto
                End If
                If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "1" Then
                    TipoArrotondamento = TipoArrotonda.Eccesso
                End If
                If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "2" Then
                    TipoArrotondamento = TipoArrotonda.Nessuno
                End If
                '------------------------------------

                Dim j As Integer
                For i = 0 To Me.GridView_ListinoDaStampare.Rows.Count - 1

                    If temp_selezione.Contains(Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text) = False Then
                        nuovoSeparatore(Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text, "")
                    End If

                    ricarico = Double.Parse(Me.GridView_ListinoDaStampare.Rows(i).Cells(38).Text)

                    'Controllo se devo stampare il prezzo con IVA o meno
                    If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(3).Text = "0" Then
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(21).Text, prezzo)
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(35).Text, prezzo_promo)
                        If i < Me.GridView_ListinoDaStampare.Rows.Count - 1 Then
                            Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + 1).Cells(35).Text, prezzo_promo_multipla)
                        End If
                    Else
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(22).Text, prezzo)
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(36).Text, prezzo_promo)
                        If i < Me.GridView_ListinoDaStampare.Rows.Count - 1 Then
                            Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + 1).Cells(36).Text, prezzo_promo_multipla)
                        End If
                    End If
                    '------------------------------------------------------------------------------
                    'Controllo se Stampare o meno la Promo
                    Dim cont = 0 'variabile che rappresenta il numero delle promozioni da stampare

                    If (Me.GridView_ListinoDaStampare.Rows(i).Cells(39).Text = "0") Then 'Se promo uguale a 0, faccio una stampa normale di una riga
                        If (i > 1) Then
                            If (Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text <> Me.GridView_ListinoDaStampare.Rows(i - 1).Cells(1).Text) Then
                                nuovaRiga(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text, String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento)))
                            End If
                        Else
                            nuovaRiga(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text, String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento)))
                        End If
                    Else
                        If (Me.GridView_ListinoDaStampare.Rows(i).Cells(34).Text = "1") Then
                            'Resetto il vettore offerte
                            Dim offerte(20) As String
                            Dim x As Integer = 0
                            For x = 0 To offerte.Length - 1
                                offerte(x) = ""
                            Next
                            '-------------------------------
                            'Conteggio il numero di Promo RIghe da stampare
                            cont = 0
                            While ((Me.GridView_ListinoDaStampare.Rows(i).Cells(0).Text) = (Me.GridView_ListinoDaStampare.Rows(i + cont + 1).Cells(0).Text))
                                cont += 1
                                If ((cont + i) <= (Me.GridView_ListinoDaStampare.Rows.Count - 1)) Then
                                    Exit While
                                End If
                            End While
                            '----------------------------------------------
                            'Stampa delle righe PROMO
                            For j = 0 To cont 'modificato a cont-1, prima era solo cont
                                'Controllo se devo stampare il prezzo con IVA o meno
                                If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(3).Text = "0" Then
                                    Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + j).Cells(35).Text, prezzo_promo)
                                Else
                                    Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + j).Cells(36).Text, prezzo_promo)
                                End If
                                'Controllo se stampare una Offerta a Quantità Min o Multipla
                                If (Me.GridView_ListinoDaStampare.Rows(i + j).Cells(30).Text) > 0 Then 'Offerta Quantità Minima
                                    offerte(j) = "PROMO dal " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(26).Text & " al " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(27).Text & " MIN. " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(30).Text & " pz. a € " & String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo_promo / 100) * ricarico) + (prezzo_promo), 0.1, TipoArrotondamento))
                                Else 'Offerta Quantità Multipla
                                    offerte(j) = "PROMO dal " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(26).Text & " al " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(27).Text & " MULTIPLI " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(31).Text & " pz. a € " & String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo_promo / 100) * ricarico) + (prezzo_promo), 0.1, TipoArrotondamento))
                                End If
                            Next
                            '------------------------------------------------

                            nuovaRigaPromo(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text, String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento)), offerte)
                            i = i + cont
                        Else
                            'Se non ci sono PROMO da stampare
                            nuovaRiga(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text, Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text, String.Format("{0:n2}", Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento)))
                        End If
                    End If
                    'i = i + cont - 1  'Incremento i per non stampare di nuovo l'articolo che presenta offerta a Quantità min e Multipla
                    'End If

                    '--------------------------------------------------------------------------------
                    'mi salvo cosa sto scrivendo per controllare se cambia la categoria-settore-tipologia
                    temp_selezione = (Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text)
                Next
                'Response.Flush()
                'Response.End()
            Catch ex As Exception

            Finally
                'aggiungere l'ultima pagina al documento
                If (dimensioneTabDx <> 1) Or (dimensioneTabSx <> 1) Then
                    'aggiungo la tabella al documento
                    nuovoTop()
                    myDoc.NewPage()
                    myDoc.Add(tablePdf)
                End If

                'chiudo il documento
                myDoc.Close()
            End Try
        End If

        If (Request.QueryString("stampa") = 2) And (Session.Item("UtentiID") > 0) Then
            Response.ContentType = "application/vnd.ms-excel"
            Response.AddHeader("Content-Disposition", String.Format("attachment;filename={0}", filename))
            Response.Clear()

            InitializeWorkbook()


            Dim sheet1, sheet2 As NPOI.SS.UserModel.Sheet

            Dim row, row2 As NPOI.SS.UserModel.Row
            Dim c, c2 As NPOI.SS.UserModel.Cell

            Dim Stringa_IVA As String
            Stampa_IVA = Val(Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(3).Text)
            If (Stampa_IVA = 0) Then
                Stringa_IVA = " (I prezzi sono da considerarsi IVA ESCLUSA)"
            Else
                Stringa_IVA = " (I prezzi sono da considerarsi IVA INCLUSA)"
            End If

            Dim nomeAzienda As String = RagioneSociale.Text
            Dim via As String = Indirizzo.Text
            Dim capECitta As String = Città.Text & "(" & Provincia.Text & ")" & CAP.Text
            Dim telFax As String = "Tel. " & Telefono.Text & " / Fax. " & fax.Text
            Dim pi As String = PIVA.Text
            Dim dataListino As String = "Listino aggiornato al " & Date.Now.Day & "/" & Date.Now.Month & "/" & Date.Now.Year & " ** " & Stringa_IVA & " **"

            '-------------------[ Pagina Prodotto ]------------------------

            sheet1 = hssfworkbook.GetSheet("Preventivo")
            row = sheet1.GetRow(2)
            c = row.GetCell(2)
            c.SetCellValue(nomeAzienda)

            row = sheet1.GetRow(3)
            c = row.GetCell(2)
            c.SetCellValue(via)

            row = sheet1.GetRow(4)
            c = row.GetCell(2)
            c.SetCellValue(capECitta)

            row = sheet1.GetRow(5)
            c = row.GetCell(2)
            c.SetCellValue(telFax)

            row = sheet1.GetRow(7)
            c = row.GetCell(2)
            c.SetCellValue("P.IVA " & pi)

            row = sheet1.GetRow(49)
            c = row.GetCell(2)
            c.SetCellValue(Stringa_IVA)

            '----------------[ prodotti ]---------------------


            sheet1 = hssfworkbook.GetSheet("Prodotti")

            row = sheet1.GetRow(0)
            c = row.GetCell(0)
            c.SetCellValue(nomeAzienda)

            row = sheet1.GetRow(1)
            c = row.GetCell(0)
            c.SetCellValue(via)

            row = sheet1.GetRow(2)
            c = row.GetCell(0)
            c.SetCellValue(capECitta)

            row = sheet1.GetRow(3)
            c = row.GetCell(0)
            c.SetCellValue(telFax)

            row = sheet1.GetRow(5)
            c = row.GetCell(0)
            c.SetCellValue("P.IVA " & pi)

            row = sheet1.GetRow(7)
            c = row.GetCell(0)
            c.SetCellValue(dataListino)


            '----------------[ vers. stampabile ]---------------------


            sheet2 = hssfworkbook.GetSheet("Versione Stampabile")

            row = sheet1.GetRow(0)
            c = row.GetCell(0)
            c.SetCellValue(nomeAzienda)

            row = sheet1.GetRow(1)
            c = row.GetCell(0)
            c.SetCellValue(via)

            row = sheet1.GetRow(2)
            c = row.GetCell(0)
            c.SetCellValue(capECitta)

            row = sheet1.GetRow(3)
            c = row.GetCell(0)
            c.SetCellValue(telFax)

            row = sheet1.GetRow(5)
            c = row.GetCell(0)
            c.SetCellValue("P.IVA " & pi)

            row = sheet1.GetRow(7)
            c = row.GetCell(0)
            c.SetCellValue(dataListino)


            'stampa prodotti
            'Controllare se esiste
            temp_selezione = ""
            ricarico = 0
            prezzo = 0
            prezzo_promo = 0
            prezzo_promo_multipla = 0

            'Seleziono il tipo di arrotondamento
            If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "0" Then
                TipoArrotondamento = TipoArrotonda.Difetto
            End If
            If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "1" Then
                TipoArrotondamento = TipoArrotonda.Eccesso
            End If
            If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(5).Text = "2" Then
                TipoArrotondamento = TipoArrotonda.Nessuno
            End If
            '------------------------------------

            Dim offset_separatore As Integer = 0
            Dim offset_promo As Integer = 0

            'Style delle celle di Excel
            Dim style As NPOI.SS.UserModel.CellStyle
            style = Me.hssfworkbook.CreateCellStyle
            style.FillBackgroundColor = NPOI.HSSF.Util.HSSFColor.LIGHT_TURQUOISE.index
            style.FillForegroundColor = NPOI.HSSF.Util.HSSFColor.LIGHT_TURQUOISE.index
            style.Alignment = NPOI.SS.UserModel.HorizontalAlignment.CENTER
            style.FillPattern = NPOI.SS.UserModel.FillPatternType.SOLID_FOREGROUND
            Dim style_promo As NPOI.SS.UserModel.CellStyle
            style_promo = Me.hssfworkbook.CreateCellStyle
            style_promo.FillBackgroundColor = NPOI.HSSF.Util.HSSFColor.LIGHT_YELLOW.index
            style_promo.FillForegroundColor = NPOI.HSSF.Util.HSSFColor.LIGHT_YELLOW.index
            style_promo.Alignment = NPOI.SS.UserModel.HorizontalAlignment.CENTER
            style_promo.FillPattern = NPOI.SS.UserModel.FillPatternType.SOLID_FOREGROUND
            '______________________________________________________________________________________

            Dim pos As Integer = 0 'Posizione della cella su cui stampare
            For i = 0 To Me.GridView_ListinoDaStampare.Rows.Count - 1

                If temp_selezione.Contains(Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text) = False Then
                    pos = pos + 1
                    row = sheet1.CreateRow(pos + 9)
                    row2 = sheet2.CreateRow(pos + 9)

                    c = row.CreateCell(0)
                    c.SetCellValue("")
                    c.CellStyle = style
                    c = row.CreateCell(1)
                    c.SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text & " - " & Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text & " - " & Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text))
                    c.CellStyle = style
                    'Prezzo unitario
                    c = row.CreateCell(2)
                    c.SetCellValue("")
                    c.CellStyle = style
                    'Disponibilità
                    c = row.CreateCell(3)
                    c.SetCellValue("")
                    c.CellStyle = style
                    c = row.CreateCell(4)
                    c.SetCellValue(0)
                    c.CellStyle = style
                    '-----------------------------------
                    c2 = row2.CreateCell(0)
                    c2.SetCellValue("")
                    c2.CellStyle = style
                    c2 = row2.CreateCell(1)
                    c2.SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text & " - " & Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text))
                    c2.CellStyle = style
                    'Prezzo unitario
                    c2 = row2.CreateCell(2)
                    c2.SetCellValue("")
                    c2.CellStyle = style
                    'Disponibilità
                    c2 = row2.CreateCell(3)
                    c2.SetCellValue("")
                    c2.CellStyle = style
                End If

                ricarico = Double.Parse(Me.GridView_ListinoDaStampare.Rows(i).Cells(38).Text)

                'Controllo se devo stampare il prezzo con IVA o meno
                If Me.GridView_ProprietaListinoPersonalizzato.Rows(0).Cells(3).Text = "0" Then
                    Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(21).Text, prezzo)
                    Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(35).Text, prezzo_promo)
                    If i < Me.GridView_ListinoDaStampare.Rows.Count - 1 Then
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + 1).Cells(35).Text, prezzo_promo_multipla)
                    End If
                Else
                    Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(22).Text, prezzo)
                    Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i).Cells(36).Text, prezzo_promo)
                    If i < Me.GridView_ListinoDaStampare.Rows.Count - 1 Then
                        Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + 1).Cells(36).Text, prezzo_promo_multipla)
                    End If
                End If
                '------------------------------------------------------------------------------

                'Controllo se Stampare o meno la Promo
                Dim cont = 0 'variabile che rappresenta il numero delle promozioni da stampare

                If (Me.GridView_ListinoDaStampare.Rows(i).Cells(39).Text = "0") Then 'Se promo uguale a 0, faccio una stampa normale di una riga
                    If (i >= 1) Then
                        If (Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text <> Me.GridView_ListinoDaStampare.Rows(i - 1).Cells(1).Text) Then
                            pos = pos + 1 'Incremento la posizione su cui stampare
                            row = sheet1.CreateRow(pos + 9)
                            row2 = sheet2.CreateRow(pos + 9)

                            row.CreateCell(0).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text)
                            row.CreateCell(1).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text & " - " & sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text))
                            row2.CreateCell(0).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text)
                            row2.CreateCell(1).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text))
                            'Prezzo unitario
                            row.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento))
                            row2.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento))
                            'Disponibilità
                            row.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                            row.CreateCell(4).SetCellValue(0)
                            row2.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                        End If
                    Else 'Solo per stampare la prima riga
                        pos = pos + 1
                        row = sheet1.CreateRow(pos + 9)
                        row2 = sheet2.CreateRow(pos + 9)

                        row.CreateCell(0).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text)
                        row.CreateCell(1).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text & " - " & sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text))
                        row2.CreateCell(0).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text)
                        row2.CreateCell(1).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text))
                        'Prezzo unitario
                        row.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento))
                        row2.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento))
                        'Disponibilità
                        row.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                        row.CreateCell(4).SetCellValue(0)
                        row2.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                    End If
                Else
                    If (Me.GridView_ListinoDaStampare.Rows(i).Cells(34).Text = "1") Then
                        pos = pos + 1
                        row = sheet1.CreateRow(pos + 9)
                        row2 = sheet2.CreateRow(pos + 9)

                        'Stampo la riga normale
                        row.CreateCell(0).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text)
                        row.CreateCell(1).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text & " - " & sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text))
                        'Prezzo unitario
                        row.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento))
                        'Disponibilità
                        row.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                        row.CreateCell(4).SetCellValue(0)
                        '-----------------------------------
                        'Stampo la riga normale
                        row2.CreateCell(0).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text)
                        row2.CreateCell(1).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text))
                        'Prezzo unitario
                        row2.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento))
                        'Disponibilità
                        row2.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))

                        'Conteggio il numero di Promo RIghe da stampare
                        cont = 0
                        If ((cont + i + 1) <= (Me.GridView_ListinoDaStampare.Rows.Count - 1)) Then
                            While ((Me.GridView_ListinoDaStampare.Rows(i).Cells(0).Text) = (Me.GridView_ListinoDaStampare.Rows(i + cont + 1).Cells(0).Text))
                                cont += 1
                                If ((cont + i + 1) >= (Me.GridView_ListinoDaStampare.Rows.Count - 1)) Then
                                    Exit While
                                End If
                            End While
                        End If

                        '----------------------------------------------
                        'Stampa delle righe PROMO
                        Dim j As Integer = 0
                        For j = 0 To cont 'modificato a cont-1, prima era solo cont
                            'Controllo se devo stampare il prezzo con IVA o meno
                            Double.TryParse(Me.GridView_ListinoDaStampare.Rows(i + j).Cells(35).Text, prezzo_promo)

                            'Controllo se stampare una Offerta a Quantità Min o Multipla
                            If (Me.GridView_ListinoDaStampare.Rows(i + j).Cells(30).Text) > 0 Then 'Offerta Quantità Minima
                                pos = pos + 1
                                row = sheet1.CreateRow(pos + 9)
                                row2 = sheet2.CreateRow(pos + 9)

                                'Stampa delle righe PROMO
                                row.CreateCell(0).SetCellValue("")
                                c = row.CreateCell(1)
                                c.SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text & " **PROMO dal " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(26).Text & " al " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(27).Text & " MIN. " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(30).Text & " pz.**")
                                c.CellStyle = style_promo
                                'Prezzo unitario
                                row.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo_promo / 100) * ricarico) + (prezzo_promo), 0.1, TipoArrotondamento))
                                'Disponibilità
                                row.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                                row.CreateCell(4).SetCellValue(0)

                                'Stampa delle righe PROMO in altro foglio
                                row2.CreateCell(0).SetCellValue("")
                                c2 = row2.CreateCell(1)
                                c2.SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text & " **PROMO dal " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(26).Text & " al " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(27).Text & " MIN. " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(30).Text & " pz.**")
                                c2.CellStyle = style_promo
                                'Prezzo unitario
                                row2.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo_promo / 100) * ricarico) + (prezzo_promo), 0.1, TipoArrotondamento))
                                'Disponibilità
                                row2.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))

                            Else 'Offerta Quantità Multipla
                                pos = pos + 1
                                row = sheet1.CreateRow(pos + 9)
                                row2 = sheet2.CreateRow(pos + 9)

                                'Stampa delle righe PROMO
                                row.CreateCell(0).SetCellValue("")
                                c = row.CreateCell(1)
                                c.SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text & " **PROMO dal " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(26).Text & " al " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(27).Text & " MULTIPLI " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(31).Text & " pz.**")
                                c.CellStyle = style_promo
                                'Prezzo unitario
                                row.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo_promo / 100) * ricarico) + (prezzo_promo), 0.1, TipoArrotondamento))
                                'Disponibilità
                                row.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                                row.CreateCell(4).SetCellValue(0)

                                'Stampa delle righe PROMO
                                row2.CreateCell(0).SetCellValue("")
                                c2 = row2.CreateCell(1)
                                c2.SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text & " **PROMO dal " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(26).Text & " al " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(27).Text & " MULTIPLI " & Me.GridView_ListinoDaStampare.Rows(i + j).Cells(31).Text & " pz.**")
                                c2.CellStyle = style_promo
                                'Prezzo unitario
                                row2.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo_promo / 100) * ricarico) + (prezzo_promo), 0.1, TipoArrotondamento))
                                'Disponibilità
                                row2.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                            End If
                        Next
                        '------------------------------------------------
                        i = i + cont
                    Else
                        pos = pos + 1
                        row = sheet1.CreateRow(pos + 9)
                        row2 = sheet2.CreateRow(pos + 9)
                        'Se non ci sono PROMO da stampare
                        row.CreateCell(0).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text)
                        row.CreateCell(1).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text & " - " & sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text))
                        'Prezzo unitario
                        row.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento))
                        'Disponibilità
                        row.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                        row.CreateCell(4).SetCellValue(0)

                        'Se non ci sono PROMO da stampare
                        row2.CreateCell(0).SetCellValue(Me.GridView_ListinoDaStampare.Rows(i).Cells(1).Text)
                        row2.CreateCell(1).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(2).Text))
                        'Prezzo unitario
                        row2.CreateCell(2).SetCellValue(Arrotonda(Double.Parse((prezzo / 100) * ricarico) + (prezzo), 0.1, TipoArrotondamento))
                        'Disponibilità
                        row2.CreateCell(3).SetCellValue(sostituisci_caratteri_speciali(Me.GridView_ListinoDaStampare.Rows(i).Cells(15).Text))
                    End If
                End If
                temp_selezione = (Me.GridView_ListinoDaStampare.Rows(i).Cells(5).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(7).Text & "," & Me.GridView_ListinoDaStampare.Rows(i).Cells(9).Text)
            Next

            'Force excel to recalculate all the formula while open
            sheet1.ForceFormulaRecalculation = True
            sheet2.ForceFormulaRecalculation = True

            Response.BinaryWrite(WriteToStream().GetBuffer())
            'Response.End()
        End If

        '///////////////////////////////////////////////////////////////////////////////////////////////////

        Me.GridView_ListinoSelezionato.Visible = False 'Nascondo la griglia del listino selezionato
        Me.GridView_ProprietaListinoPersonalizzato.Visible = False 'Nascondo la griglia delle proprietà del listino selezionato
        Me.GridView_SettoriCategorieTipologieSelezionati.Visible = False 'Nascondo la griglia dei Settori-Categorie-Tipologie Selezionati
        'Me.GridView_ListinoDaStampare.Visible = False

        'Nascondo il pannello di creazione listini se ho raggiunto il limite massimo
        If Me.DropDownList_ListiniUtente.Items.Count < 5 Then 'Imposto un MAX di 5 listni
            Me.Panel_NuovoListino.Visible = True
        Else
            Me.Panel_NuovoListino.Visible = False
        End If
    End Sub

    Protected Sub DropDownList_ListiniUtente_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles DropDownList_ListiniUtente.SelectedIndexChanged
        Session("ID_Listino_Personalizzato") = Me.DropDownList_ListiniUtente.SelectedValue
        Me.Azzera_Selezioni_Listino() 'Azzero le selezioni precedenti
        Me.SqlData_ProprietaListinoSelezionato.SelectCommand = "SELECT ID, Nome_Listino, ID_Utente, IVA, Data_Creazione, Arrotonda FROM listini_personalizzati WHERE (ID = " & Me.DropDownList_ListiniUtente.SelectedItem.Value & ")"
    End Sub

    Protected Sub CheckBox_Attivo_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        Aggiorna_Listino_Personalizzato(sender)
    End Sub

    Protected Sub TextBox_Ricarico_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        Aggiorna_Listino_Personalizzato(sender)
    End Sub

    Protected Sub CheckBox_Promo_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        Aggiorna_Listino_Personalizzato(sender)
    End Sub

    Protected Sub ButtonInvio_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles ButtonInvio.Click
        ' otteniamo il path della cartella
        ' principale dell'applicazione
        Dim filePath As String = Request.PhysicalApplicationPath

        ' aggiungiamo il nome della nostra cartella al path
        filePath += "Public/Logo_Listini/"


        ' controlliamo se il controllo FileUpload1
        ' contiene un file da caricare
        If (Not FileUpload1.HasFile) Then
            Me.FileUploadMessage.Text = "Selezionare un file!"
            Return
        End If

        ' estensione del file.
        Dim extension As String = System.IO.Path.GetExtension(Server.HtmlEncode(FileUpload1.FileName))

        ' se si, aggiorniamo il path del file modificando il nome utente
        filePath += username & extension

        'controllo l'estensione
        If ((extension <> ".jpg") And (extension <> ".jpeg") And (extension <> ".gif") And (extension <> ".png")) Then
            Me.FileUploadMessage.Text = "File non supportato!"
            Return
        End If

        ' controllo il contentType
        If ((FileUpload1.PostedFile.ContentType <> "image/gif") And (FileUpload1.PostedFile.ContentType <> "image/pjpeg") And (FileUpload1.PostedFile.ContentType <> "image/jpeg") And (FileUpload1.PostedFile.ContentType <> "image/png") And (FileUpload1.PostedFile.ContentType <> "image/x-png")) Then
            Me.FileUploadMessage.Text = "File non supportato!"
            Return
        End If

        ' controllo la dimensione del file
        If (FileUpload1.PostedFile.ContentLength > 1000000) Then
            Me.FileUploadMessage.Text = "Il file non può essere caricato perché supera 1MB!"
            Return
        End If

        If (System.IO.File.Exists(filePath)) Then
            ' il file è già sul server
            Me.FileUploadMessage.Text = "Il file non può essere caricato perché già presente sul server!"
            Return
        End If

        ' salviamo il file nel percorso calcolato
        FileUpload1.SaveAs(filePath)

        ' mandiamo un messaggio all'utente
        Me.FileUploadMessage.Text = "File caricato!"
        Me.logoListino.ImageUrl = "Public/Logo_Listini/" & username & extension

        Me.ButtonEliminaLogo.Enabled = True
        Me.FileUpload1.Enabled = False
        Me.ButtonInvio.Enabled = False

        Response.Redirect("Listini.aspx")
    End Sub

    Protected Sub ButtonEliminaLogo_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles ButtonEliminaLogo.Click

        Dim fileTrovato As String = Me.findUserLogo(username)

        If (fileTrovato <> "") Then
            System.IO.File.Delete(Server.MapPath("Public/Logo_Listini/" & fileTrovato))
            Me.logoListino.ImageUrl = "Images/Immagini_Listini_Personalizzati/LogoAzienda/LogoNullo.png"
            Me.FileUploadMessage.Text = "Logo Eliminato!"
        End If
        Response.Redirect("Listini.aspx")
    End Sub


    Function findUserLogo(ByVal username As String) As String

        'Controlla se l'utente ha già un file immagine caricato
        Dim di As New IO.DirectoryInfo(Server.MapPath("Public/Logo_Listini/"))
        Dim aryFi As IO.FileInfo() = di.GetFiles()
        Dim fi As IO.FileInfo

        Dim fileTrovato As String = ""

        For Each fi In aryFi
            If fi.Name.Contains(username) Then
                Return fi.Name
            End If
        Next

        Return ""

    End Function

    Protected Sub ImageButton_CreaListino_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImageButton_CreaListino.Click
        If (Me.TextBox_NomeListino.Text <> "") Then

            'Controllo che il nome_listino non sia già presente nella dropdownlist
            Dim temp As Object
            temp = Me.DropDownList_ListiniUtente.Items.FindByText(Me.TextBox_NomeListino.Text)
            If Not (temp Is Nothing) Then
                Me.Label_Esito.Text = "LISTINO GIA' PRESENTE - Inserire un nome diverso"
                Return
            End If
            '////////////////////////////////////////////////////////////////////////

            Dim Check_IVA As Integer
            If Me.CheckBox_IVA.Checked = True Then
                Check_IVA = 1
            Else
                Check_IVA = 0
            End If
            Me.SqlData_Listino_Personalizzato.InsertCommand = "INSERT INTO listini_personalizzati (Nome_Listino, ID_Utente, IVA, Arrotonda) VALUES (?cambiaNomeListino, ?utenteId, ?checkIva, "
            If Me.RadioButton_Difetto.Checked = True Then
                Me.SqlData_Listino_Personalizzato.InsertCommand = Me.SqlData_Listino_Personalizzato.InsertCommand & "0)"
            Else
                If Me.RadioButton_Eccesso.Checked = True Then
                    Me.SqlData_Listino_Personalizzato.InsertCommand = Me.SqlData_Listino_Personalizzato.InsertCommand & "1)"
                Else
                    Me.SqlData_Listino_Personalizzato.InsertCommand = Me.SqlData_Listino_Personalizzato.InsertCommand & "2)"
                End If
            End If
            Me.SqlData_Listino_Personalizzato.InsertParameters.Add("?cambiaNomeListino", Me.TextBox_CambiaNomeListino.Text)
            Me.SqlData_Listino_Personalizzato.InsertParameters.Add("?utenteId", Session.Item("UtentiID"))
            Me.SqlData_Listino_Personalizzato.InsertParameters.Add("?checkIva", Check_IVA)
            Me.SqlData_Listino_Personalizzato.Insert() 'Aggiunge un NUOVO Listino

            'Me.TextBox_NomeListino.Text = ""
            Me.Label_Esito.Visible = True
            Me.Label_Esito.Text = "LISTINO SALVATO CORRETTAMENTE"

            Dim conn As New MySqlConnection
            Dim cmd As New MySqlCommand
            Dim sqlString As String = ""
            Dim dsData As New DataSet
            Dim strCerca As String = Me.Session("q")

            Try

                conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                conn.Open()

                sqlString = "SELECT ID, ID_Utente, Nome_Listino FROM(listini_personalizzati) WHERE (ID_Utente = ?utenteId) AND (Nome_Listino = ?nomeListino)"
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text
                cmd.CommandText = sqlString
                cmd.Parameters.AddWithValue("?utenteId", Session.Item("UtentiId"))
                cmd.Parameters.AddWithValue("?nomeListino", Me.TextBox_NomeListino.Text)

                Dim dr As MySqlDataReader = cmd.ExecuteReader()

                'Prendiamo l'ID del Listino appena creato e lo salviamo in sessione
                dr.Read()
                If dr.HasRows Then
                    Session("ID_Listino_Personalizzato") = dr.Item("ID")
                End If

                cmd.Dispose()

            Catch ex As Exception

            Finally

                If conn.State = ConnectionState.Open Then
                    conn.Close()
                    conn.Dispose()
                End If

            End Try
        Else
            Me.Label_Esito.Visible = True
            Me.Label_Esito.Text = "INSERIRE UN NOME AL LISTINO"
        End If
    End Sub

    Protected Sub ImageButton_AggiornaListino_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImageButton_AggiornaListino.Click
        If (Me.TextBox_CambiaNomeListino.Text <> "") Then

            'Controllo che il nome_listino non sia già presente nella dropdownlist
            If (Me.DropDownList_ListiniUtente.SelectedItem.Text) <> Me.TextBox_CambiaNomeListino.Text Then
                Dim temp As Object
                temp = Me.DropDownList_ListiniUtente.Items.FindByText(Me.TextBox_CambiaNomeListino.Text)
                If Not (temp Is Nothing) Then
                    Me.Label_Cambia_Esito.Visible = True
                    Me.Label_Cambia_Esito.Text = "LISTINO GIA' PRESENTE - Inserire un nome diverso"
                    Return
                End If
            End If
            '////////////////////////////////////////////////////////////////////////
            'Aggiorno le proprietà del Listino
            Dim Check_IVA As Integer
            If Me.CheckBox_IVA2.Checked = True Then
                Check_IVA = 1
            Else
                Check_IVA = 0
            End If
            Me.SqlData_Listino_Personalizzato.UpdateCommand = "UPDATE listini_personalizzati SET Nome_Listino=?cambiaNomeListino,  ID_Utente = ?utenteId, IVA =?checkIva, Arrotonda = "
            If Me.RadioButton_Difetto2.Checked = True Then
                Me.SqlData_Listino_Personalizzato.UpdateCommand = Me.SqlData_Listino_Personalizzato.UpdateCommand & "0"
            Else
                If Me.RadioButton_Eccesso2.Checked = True Then
                    Me.SqlData_Listino_Personalizzato.UpdateCommand = Me.SqlData_Listino_Personalizzato.UpdateCommand & "1"
                Else
                    Me.SqlData_Listino_Personalizzato.UpdateCommand = Me.SqlData_Listino_Personalizzato.UpdateCommand & "2"
                End If
            End If
            Me.SqlData_Listino_Personalizzato.UpdateCommand = Me.SqlData_Listino_Personalizzato.UpdateCommand & " WHERE id=?listinoId"
            Me.SqlData_Listino_Personalizzato.UpdateParameters.Add("?cambiaNomeListino", Me.TextBox_CambiaNomeListino.Text)
            Me.SqlData_Listino_Personalizzato.UpdateParameters.Add("?utenteId", Session.Item("UtentiID"))
            Me.SqlData_Listino_Personalizzato.UpdateParameters.Add("?checkIva", Check_IVA)
            Me.SqlData_Listino_Personalizzato.UpdateParameters.Add("?listinoId", Session.Item("ID_Listino_Personalizzato"))
            Me.SqlData_Listino_Personalizzato.Update() 'Aggiorno il Listino

            Me.Label_Cambia_Esito.Visible = True

            Me.Label_Cambia_Esito.Text = "LISTINO SALVATO CORRETTAMENTE"
        Else
            Me.Label_Cambia_Esito.Visible = True
            Me.Label_Cambia_Esito.Text = "INSERIRE UN NOME AL LISTINO"
        End If
    End Sub

    Protected Sub ImageButton_EsportaPDF_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImageButton_EsportaPDF.Click
        Response.Redirect("listini.aspx?stampa=1")
    End Sub

    Protected Sub ImageButton_EliminaListino_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImageButton_EliminaListino.Click
        If Me.DropDownList_ListiniUtente.Items.Count > 0 Then
            Me.SqlDataSource_ListinoSelezionato.DeleteCommand = "DELETE FROM listini_personalizzati WHERE (ID = ?id)"
            Me.SqlDataSource_ListinoSelezionato.SelectParameters.Add("?id", Me.DropDownList_ListiniUtente.SelectedValue)
            Me.SqlDataSource_ListinoSelezionato.Delete()
            Response.Redirect("listini.aspx")
        End If
    End Sub

    Protected Sub ImageButton_EsportaEXCEL_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImageButton_EsportaEXCEL.Click
        Response.Redirect("listini.aspx?stampa=2")
    End Sub

    Protected Sub ImageButton_ResettaTutto_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImageButton_ResettaTutto.Click
        Me.SqlData_Dettagli_Listino_Personalizzato.DeleteCommand = "DELETE FROM dettagli_listino_personalizzato WHERE (ID_Listino_Personalizzato = ?id)"
        Me.SqlData_Dettagli_Listino_Personalizzato.SelectParameters.Add("?id", Session.Item("ID_Listino_Personalizzato"))
        Me.SqlData_Dettagli_Listino_Personalizzato.Delete()
    End Sub

    Protected Sub ImageButton_ResettaSelezionati_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImageButton_ResettaSelezionati.Click
        Dim i As Integer
        For i = 0 To Me.GridView_ListinoCompleto.Rows.Count - 1
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(1).FindControl("CheckBox_Attivo"), CheckBox).Checked = False

            Aggiorna_Listino_Personalizzato(Me.GridView_ListinoCompleto.Rows(i).Cells(1).FindControl("CheckBox_Attivo"))
        Next
    End Sub

    Protected Sub ImageButton_ApplicaSelezione_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImageButton_ApplicaSelezione.Click
        Dim i As Integer
        For i = 0 To Me.GridView_ListinoCompleto.Rows.Count - 1
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(1).FindControl("CheckBox_Attivo"), CheckBox).Checked = Me.CheckBox_ImpostaAttiva_Tutti.Checked
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(2).FindControl("TextBox_Ricarico"), TextBox).Text = Me.TextBox_ImpostaRicarico_Tutti.Text
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(3).FindControl("CheckBox_Promo"), CheckBox).Checked = Me.CheckBox_ImpostaPromo_Tutti.Checked

            If Me.CheckBox_ImpostaAttiva_Tutti.Checked = False Then
                Aggiorna_Listino_Personalizzato(Me.GridView_ListinoCompleto.Rows(i).Cells(1).FindControl("CheckBox_Attivo"))
            Else
                Aggiorna_Listino_Personalizzato(Me.GridView_ListinoCompleto.Rows(i).Cells(2).FindControl("TextBox_Ricarico"))
            End If
        Next
    End Sub
End Class
