Imports System
Imports System.Globalization
Imports System.Text

' KS-DASHBOARD-ORDERS-1B: parte PURA della pagina «I miei ordini» (documenti.aspx): nessun accesso a richiesta, sessione o database.
' Filtri validati, intervalli di date, testi di stato e la query della lista con TUTTI i valori come parametri (?UtentiId, ?AziendaId, ...):
' i valori di utente e azienda li aggiunge la pagina, dall'identita verificata dell'host, nel momento della selezione.
Public Module KeepStoreAccountOrderFilters

    Private ReadOnly DateFormats As String() = {"yyyy-MM-dd", "dd-MM-yyyy"}

    ' Data di un filtro: ISO (campi type=date) o dd-MM-yyyy (vecchi collegamenti); anni plausibili; mai eccezioni.
    Public Function ParseFilterDate(ByVal raw As String, ByRef result As DateTime) As Boolean
        result = DateTime.MinValue
        If raw Is Nothing Then Return False
        Dim text As String = raw.Trim()
        If text.Length = 0 OrElse text.Length > 10 Then Return False
        Dim parsed As DateTime
        If Not DateTime.TryParseExact(text, DateFormats, CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then Return False
        If parsed.Year < 1990 OrElse parsed.Year > 2100 Then Return False
        result = parsed.Date
        Return True
    End Function

    Public Function FormatFilterDate(ByVal value As DateTime) As String
        Return value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
    End Function

    ' Stato: intero >= -1 (-1 = qualsiasi); tutto il resto diventa -1.
    Public Function SafeStato(ByVal raw As String) As Integer
        Dim parsed As Integer
        If Integer.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, parsed) AndAlso parsed >= -1 Then Return parsed
        Return -1
    End Function

    ' Periodo rapido: soltanto -1 (tutti), 7, 30, 60, 90 giorni.
    Public Function SafeTempo(ByVal raw As String) As Integer
        Dim parsed As Integer
        If Not Integer.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, parsed) Then Return -1
        Select Case parsed
            Case 7, 30, 60, 90
                Return parsed
            Case Else
                Return -1
        End Select
    End Function

    ' Estremi del filtro: il periodo rapido vince sulle date; altrimenti «dal» e «al» sono indipendenti; un intervallo invertito si scambia.
    Public Sub ResolveRange(ByVal tempo As Integer, ByVal dalRaw As String, ByVal alRaw As String, ByVal today As DateTime,
                            ByRef dal As DateTime, ByRef al As DateTime, ByRef hasDal As Boolean, ByRef hasAl As Boolean)
        dal = DateTime.MinValue
        al = DateTime.MinValue
        hasDal = False
        hasAl = False
        Select Case tempo
            Case 7, 30, 60, 90
                dal = today.Date.AddDays(-tempo)
                al = today.Date
                hasDal = True
                hasAl = True
                Return
        End Select
        hasDal = ParseFilterDate(dalRaw, dal)
        hasAl = ParseFilterDate(alRaw, al)
        If hasDal AndAlso hasAl AndAlso dal > al Then
            Dim swap As DateTime = dal
            dal = al
            al = swap
        End If
    End Sub

    ' Testo di stato pulito: niente ritorni a capo, tabulazioni o spazi doppi.
    Public Function CleanText(ByVal value As Object) As String
        If value Is Nothing OrElse Convert.IsDBNull(value) Then Return ""
        Dim text As String = Convert.ToString(value, CultureInfo.InvariantCulture)
        If text Is Nothing Then Return ""
        text = text.Replace(Convert.ToChar(13), " "c).Replace(Convert.ToChar(10), " "c).Replace(Convert.ToChar(9), " "c)
        Do While text.Contains("  ")
            text = text.Replace("  ", " ")
        Loop
        Return text.Trim()
    End Function

    ' Etichetta di stato: la prima descrizione; la seconda e una nota a parte (mai nello stesso badge).
    Public Function StatusTitle(ByVal stato1 As Object, ByVal stato2 As Object) As String
        Dim first As String = CleanText(stato1)
        If first.Length > 0 Then Return first
        Dim second As String = CleanText(stato2)
        If second.Length > 0 Then Return second
        Return "Non disponibile"
    End Function

    Public Function StatusNote(ByVal stato1 As Object, ByVal stato2 As Object) As String
        Dim first As String = CleanText(stato1)
        If first.Length = 0 Then Return ""
        Dim second As String = CleanText(stato2)
        If second.Length = 0 OrElse String.Equals(first, second, StringComparison.OrdinalIgnoreCase) Then Return ""
        Return second
    End Function

    ' Query della lista (stesse colonne e join di sempre). Segnaposto: ?UtentiId, ?AziendaId, ?TipoDocumentiId sempre; ?Stato, ?Dal, ?Al solo se richiesti.
    Public Function BuildListSql(ByVal withStato As Boolean, ByVal withDal As Boolean, ByVal withAl As Boolean) As String
        Dim sql As New StringBuilder()
        sql.Append("SELECT vdocumenti.*, utenti.*, vettori.Link_Tracking, ")
        sql.Append("COALESCE(dpay.Pagato,0) AS ListaPagato, ")
        sql.Append("COALESCE(dpay.StatoPagamentoWeb,0) AS ListaStatoPagamentoWeb, ")
        sql.Append("dpay.DataStatoPagamentoWeb AS ListaDataStatoPagamentoWeb, ")
        sql.Append("COALESCE(dpay.UltimoEsitoPagamentoWeb,'') AS ListaUltimoEsitoPagamentoWeb, ")
        sql.Append("COALESCE(pagamentitipo.Descrizione,'') AS ListaPagamentoDescrizione, ")
        sql.Append("COALESCE(pagamentitipo.OnLine,0) AS ListaPagamentiTipoOnline, ")
        sql.Append("CASE WHEN ltd.Web=1 AND ltd.Abilitato=1 AND ltd.ImpegnaQnt=1 THEN 1 ELSE 0 END AS ListaOrdineWeb ")
        sql.Append("FROM `vdocumenti` ")
        sql.Append("LEFT JOIN `tipodocumenti` ltd ON ltd.`id` = `vdocumenti`.`TipoDocumentiId` ")
        sql.Append("LEFT JOIN `utenti` ON `vdocumenti`.`UtentiId` = `utenti`.`Id` ")
        sql.Append("LEFT JOIN (SELECT id, Link_Tracking FROM `vettori`) AS vettori ON `vdocumenti`.`VettoriId` = `vettori`.`id` ")
        sql.Append("LEFT JOIN `pagamentitipo` ON `vdocumenti`.`PagamentiTipoId` = `pagamentitipo`.`id` ")
        sql.Append("LEFT JOIN `documenti` dpay ON dpay.`id` = `vdocumenti`.`Id` ")
        sql.Append("WHERE ((`vdocumenti`.`UtentiId`=?UtentiId) AND (`vdocumenti`.`AziendeId`=?AziendaId) AND (`vdocumenti`.`TipoDocumentiId`=?TipoDocumentiId))")
        If withStato Then sql.Append(" AND (`vdocumenti`.`StatiId`=?Stato)")
        If withDal Then sql.Append(" AND (`vdocumenti`.`DataDocumento` >= ?Dal)")
        If withAl Then sql.Append(" AND (`vdocumenti`.`DataDocumento` <= ?Al)")
        sql.Append(" ORDER BY `vdocumenti`.`ID` DESC")
        Return sql.ToString()
    End Function

    ' URL canonico della lista: soltanto parametri validi; il periodo rapido esclude le date; le date sono ISO.
    Public Function BuildListUrl(ByVal tipo As Integer, ByVal stato As Integer, ByVal tempo As Integer, ByVal dalRaw As String, ByVal alRaw As String) As String
        Dim url As New StringBuilder("documenti.aspx?t=")
        url.Append(Math.Max(tipo, 1).ToString(CultureInfo.InvariantCulture))
        If stato > -1 Then url.Append("&stato=").Append(stato.ToString(CultureInfo.InvariantCulture))
        Dim safeTime As Integer = SafeTempo(tempo.ToString(CultureInfo.InvariantCulture))
        If safeTime > 0 Then
            url.Append("&tempo=").Append(safeTime.ToString(CultureInfo.InvariantCulture))
        Else
            Dim dal As DateTime, al As DateTime, hasDal As Boolean, hasAl As Boolean
            ResolveRange(-1, dalRaw, alRaw, DateTime.Today, dal, al, hasDal, hasAl)
            If hasDal Then url.Append("&dal=").Append(FormatFilterDate(dal))
            If hasAl Then url.Append("&al=").Append(FormatFilterDate(al))
        End If
        Return url.ToString()
    End Function

End Module
