Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text
Imports System.Web

' "Venduti negli ultimi 12 mesi": UNA definizione per tutto il sito (HOME-DEAL-PROGRESS-1A, CATALOG-DEAL-PROGRESS-1B).
' Decisione del PO del 2026-11-19 ("tutte le vendite"): per articolo, il maggiore fra quantita ordinate e quantita scaricate,
' uscite non annullate, senza note di credito, azienda dell'host e aziende con la stessa partita IVA valida.
' Modulo PURO: compone la query e la barra, non apre connessioni (la lettura e in StorefrontSoldUnitsReader).
Public NotInheritable Class StorefrontSoldUnits
    Private Sub New()
    End Sub

    Public Const Heading As String = "Venduti negli ultimi 12 mesi"
    Public Const MaxArticles As Integer = 400

    Public Shared Function BuildFiscalCompanyScopeSql() As String
        ' Only a formal Italian VAT identity can expand the scope; unknown formats stay local.
        ' Trim outer spaces and accept the standard IT prefix, never strip arbitrary characters.
        Dim rawVat As String = "TRIM(COALESCE(Piva,''))"
        Dim normalizedVat As String = "CASE WHEN ASCII(SUBSTRING(" & rawVat & ",1,1)) IN (73,105) AND ASCII(SUBSTRING(" & rawVat & ",2,1)) IN (84,116) THEN SUBSTRING(" & rawVat & ",3) ELSE " & rawVat & " END"
        Dim checksumTerms As New List(Of String)()
        For position As Integer = 1 To 10
            Dim digit As String = "CAST(SUBSTRING(currentFiscal.FiscalVat," & position.ToString(CultureInfo.InvariantCulture) & ",1) AS UNSIGNED)"
            If position Mod 2 = 0 Then
                checksumTerms.Add("CAST(SUBSTRING('0246813579'," & digit & "+1,1) AS UNSIGNED)")
            Else
                checksumTerms.Add(digit)
            End If
        Next
        ' UNION prevents counting the current company twice. No per-card query or shared cache.
        Return "SELECT @commercialCompany AS AziendaId UNION " &
               "SELECT peer.id AS AziendaId FROM (SELECT id," & normalizedVat & " AS FiscalVat FROM aziende) peer " &
               "INNER JOIN (SELECT " & normalizedVat & " AS FiscalVat FROM aziende WHERE id=@commercialCompany) currentFiscal " &
               "ON peer.FiscalVat=currentFiscal.FiscalVat " &
               "AND peer.id>0 AND CHAR_LENGTH(peer.FiscalVat)=11 AND peer.FiscalVat NOT REGEXP '[^0-9]' " &
               "WHERE CHAR_LENGTH(currentFiscal.FiscalVat)=11 AND currentFiscal.FiscalVat NOT REGEXP '[^0-9]' " &
               "AND currentFiscal.FiscalVat<>'00000000000' " &
               "AND MOD(10-MOD(" & String.Join("+", checksumTerms.ToArray()) & ",10),10)=CAST(SUBSTRING(currentFiscal.FiscalVat,11,1) AS UNSIGNED)"
    End Function

    Public Shared Function BuildCommercialActivitySql(Optional ByVal articleIdList As String = "") As String
        ' Ranking index, not certified sales. Fiscal scope affects only aggregate activity.
        ' The direction lookup is configuration, never the document's name or a type-ID list.
        Return "SELECT q.ArticoliId, GREATEST(SUM(q.QtaOrdini),SUM(q.QtaScarichi)) AS CommercialScore, MAX(q.LastActivity) AS LastCommercialActivity " &
               "FROM (SELECT dr.ArticoliId, dr.TCid, " &
               "SUM(CASE WHEN COALESCE(td.ImpegnaQnt,0)=1 THEN dr.Qnt ELSE 0 END) AS QtaOrdini, " &
               "SUM(CASE WHEN COALESCE(td.Segno,0)<0 THEN dr.Qnt ELSE 0 END) AS QtaScarichi, MAX(d.DataDocumento) AS LastActivity " &
               "FROM documentirighe dr INNER JOIN documenti d ON d.id=dr.DocumentiId " &
               "INNER JOIN tipodocumenti td ON td.id=d.TipoDocumentiId " &
               "INNER JOIN movimentitipo mt ON mt.id=td.MovimentiTipoId " &
               "LEFT JOIN documentistati ds ON ds.id=d.StatiId " &
               "INNER JOIN (" & BuildFiscalCompanyScopeSql() & ") fiscalScope ON fiscalScope.AziendaId=d.AziendeId " &
               "WHERE @commercialCompany>0 " &
               "AND UPPER(TRIM(COALESCE(mt.Descrizione,'')))='USCITA' " &
               "AND (COALESCE(td.GestioneStato,0)=0 OR ds.id IS NOT NULL) AND (ds.id IS NULL OR (COALESCE(ds.Abilitato,0)=1 AND LOWER(TRIM(COALESCE(ds.Descrizione1,''))) NOT LIKE 'annull%')) " &
               "AND d.DataDocumento>=@commercialStart AND d.DataDocumento<@commercialEnd " &
               "AND COALESCE(dr.ArticoliId,0)>0 AND COALESCE(dr.Qnt,0)>0 AND COALESCE(dr.TipoRiga,'A')='A' " &
               If(String.IsNullOrEmpty(articleIdList), String.Empty, "AND dr.ArticoliId IN (" & articleIdList & ") ") &
               "AND (COALESCE(td.ImpegnaQnt,0)=1 OR COALESCE(td.Segno,0)<0) " &
               "AND NOT EXISTS (SELECT 1 FROM tipodocumenticontabili tc WHERE tc.TipoDocumentiId=td.id " &
               "AND (COALESCE(tc.NotaCreditoClienti,0)=1 OR COALESCE(tc.NotaCreditoFornitori,0)=1)) " &
               "GROUP BY dr.ArticoliId, dr.TCid) q GROUP BY q.ArticoliId"
    End Function

    ' Elenco per la clausola IN: solo interi positivi, senza ripetizioni, al massimo MaxArticles. Vuoto = nessuna lettura.
    Public Shared Function FormatIdList(ByVal articleIds As IEnumerable(Of Integer)) As String
        If articleIds Is Nothing Then Return String.Empty
        Dim seen As New HashSet(Of Integer)()
        Dim parts As New List(Of String)()
        For Each id As Integer In articleIds
            If parts.Count >= MaxArticles Then Exit For
            If id > 0 AndAlso seen.Add(id) Then parts.Add(id.ToString(CultureInfo.InvariantCulture))
        Next
        Return String.Join(",", parts.ToArray())
    End Function

    ' Percentuale della barra: venduti / (venduti + disponibili netti). Zero venduti = nessuna barra (0).
    ' exact = True solo per chi puo vedere i numeri di giacenza: valore intero fra 1 e 99.
    ' exact = False (ospiti e vista sintetica): gradini di 10 punti fra 10 e 90, cosi dalla barra non si ricava la giacenza.
    Public Shared Function Percent(ByVal sold As Decimal, ByVal available As Decimal, ByVal exact As Boolean) As Integer
        If sold <= 0D Then Return 0
        Dim stock As Decimal = Math.Max(0D, available)
        Dim raw As Decimal = (100D * sold) / (sold + stock)
        If exact Then
            If stock <= 0D Then Return 100
            Return CInt(Math.Max(1D, Math.Min(99D, Math.Floor(raw))))
        End If
        Dim stepped As Integer = CInt(Math.Round(raw / 10D, MidpointRounding.AwayFromZero)) * 10
        Return Math.Max(10, Math.Min(90, stepped))
    End Function

    ' Quantita mostrata: numero intero (le frazioni si troncano), separatore delle migliaia italiano.
    Public Shared Function Units(ByVal value As Decimal) As String
        Dim whole As Decimal = Math.Floor(Math.Max(0D, value))
        Return whole.ToString("#,##0", System.Globalization.CultureInfo.GetCultureInfo("it-IT"))
    End Function

    ' Barra compatta per le schede dell'elenco: etichetta e numero dei venduti su una riga, barra sotto. Nessun numero di
    ' disponibilita (la scheda lo mostra gia a chi puo vederlo). Sotto un pezzo venduto: nessuna barra.
    Public Shared Function RenderCompact(ByVal sold As Decimal, ByVal available As Decimal, ByVal exact As Boolean, ByVal productName As String) As String
        Dim whole As Decimal = Math.Floor(sold)
        If whole <= 0D Then Return String.Empty
        Dim value As Integer = Percent(whole, available, exact)
        If value <= 0 Then Return String.Empty
        Dim valueText As String = value.ToString(CultureInfo.InvariantCulture)
        Dim soldText As String = Units(whole)
        Dim sb As New StringBuilder()
        sb.Append("<div class='ks-card-sales'>")
        sb.Append("<div class='ks-card-sales__head'><span>").Append(Heading).Append("</span><strong>").Append(soldText).Append("</strong></div>")
        sb.Append("<div class='ks-card-sales__track' role='progressbar' aria-valuemin='0' aria-valuemax='100' aria-valuenow='").Append(valueText)
        sb.Append("' aria-valuetext='").Append(soldText).Append(" venduti negli ultimi 12 mesi' aria-label='")
        sb.Append(HttpUtility.HtmlEncode("Vendite di " & HttpUtility.HtmlDecode(productName))).Append("'>")
        sb.Append("<div class='ks-card-sales__bar' style='width:").Append(valueText).Append("%'></div>")
        sb.Append("</div></div>")
        Return sb.ToString()
    End Function
End Class
