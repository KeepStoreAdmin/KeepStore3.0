Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Net.Mail
Imports System.Configuration

Partial Class documenti
    Inherits System.Web.UI.Page

    Dim conn As New MySqlConnection
    Dim strSql As String = ""

    Public nDocTrovati As String = "0"


    '==============================================================
    ' Safe tipo documento (QueryString t)
    ' - se manca o è invalido: redirect a t=4 (se esiste), altrimenti primo tipo disponibile
    '==============================================================
    Private _safeTipoDocumentoId As Integer = -1

    Private ReadOnly Property SafeTipoDocumentoId As Integer
        Get
            If _safeTipoDocumentoId > 0 Then Return _safeTipoDocumentoId
            _safeTipoDocumentoId = ComputeSafeTipoDocumentoId()
            Return _safeTipoDocumentoId
        End Get
    End Property

    Private Function ComputeSafeTipoDocumentoId() As Integer
        Dim requested As Integer = -1
        If Integer.TryParse(Convert.ToString(Request.QueryString("t")), requested) Then
            If TipoDocumentoExists(requested) Then
                Return requested
            End If
        End If

        ' Preferisci 4 (Ordini) se disponibile
        If TipoDocumentoExists(4) Then
            Return 4
        End If

        Dim fallback As Integer = GetFirstEnabledTipoDocumentoId()
        If fallback > 0 Then Return fallback

        Return 4
    End Function

    Private Function TipoDocumentoExists(ByVal tipoId As Integer) As Boolean
        If tipoId <= 0 Then Return False
        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Using cmd As New MySqlCommand("SELECT 1 FROM tipodocumenti WHERE id=@id AND Web=1 AND Abilitato=1 LIMIT 1", c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = tipoId
                    c.Open()
                    Dim o As Object = cmd.ExecuteScalar()
                    Return (o IsNot Nothing AndAlso Not Convert.IsDBNull(o))
                End Using
            End Using
        Catch
            Return False
        End Try
    End Function

    Private Function GetFirstEnabledTipoDocumentoId() As Integer
        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Using cmd As New MySqlCommand("SELECT id FROM tipodocumenti WHERE Web=1 AND Abilitato=1 ORDER BY Ordinamento, Descrizione LIMIT 1", c)
                    c.Open()
                    Dim o As Object = cmd.ExecuteScalar()
                    If o Is Nothing OrElse Convert.IsDBNull(o) Then Return -1
                    Dim id As Integer = 0
                    If Integer.TryParse(Convert.ToString(o), id) AndAlso id > 0 Then Return id
                    Return -1
                End Using
            End Using
        Catch
            Return -1
        End Try
    End Function

    '==============================================================
    ' PAGE LOAD: protezione accesso
    '==============================================================
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        ' Protezione: solo utenti loggati
        If Session("LoginId") Is Nothing _
           OrElse Not IsNumeric(Session("LoginId")) _
           OrElse Convert.ToInt32(Session("LoginId")) <= 0 Then

            ' Salvo la pagina attuale (con eventuali querystring tipo ?t=4)
            Session("Pagina_visitata") = Request.RawUrl
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        
        ' Hardening: forza querystring t valida (preferisci t=4)
        Dim requestedT As Integer = -1
        Dim hasT As Boolean = Integer.TryParse(Convert.ToString(Request.QueryString("t")), requestedT)
        Dim safeT As Integer = SafeTipoDocumentoId

        If Not IsPostBack Then
            If (Not hasT) OrElse (requestedT <> safeT) Then
                Response.Redirect("documenti.aspx?t=" & safeT.ToString(), True)
                Exit Sub
            End If
        End If
' Eventuale logica iniziale (se ti serve in futuro)
        'If Not IsPostBack Then
        '    ...
        'End If

    End Sub

    '==============================================================
    ' Supporto per icona tracking (non obbligatoria nel markup attuale)
    '==============================================================
    Protected Function GetTrackingImage(ByVal trackingObj As Object) As String
        Try
            If trackingObj Is Nothing OrElse Convert.IsDBNull(trackingObj) Then
                Return "Public/Vettori/tracking_no.jpg"
            End If

            Dim t As String = trackingObj.ToString().Trim()
            If String.IsNullOrEmpty(t) Then
                Return "Public/Vettori/tracking_no.jpg"
            End If

            Return "Public/Vettori/tracking.jpg"
        Catch
            Return "Public/Vettori/tracking_no.jpg"
        End Try
    End Function

    '==============================================================
    ' Titolo pagina
    '==============================================================
    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - Consultazione documenti"
    End Sub

    '==============================================================
    ' TAB dei tipi documento (fatture, ordini, ddt, …)
    '==============================================================
    Sub preRenderClick(sender As Object, e As EventArgs)
        If Page.IsPostBack = False Then
            Dim t1 As String = SafeTipoDocumentoId.ToString()

            Dim link As LinkButton = CType(sender, LinkButton)
            Dim t As String = link.Attributes("tipoDocumento")

            link.CssClass = "nonSelezionato"
            If (t1 = t) Then
                link.CssClass = "selezionato"
            End If
        End If
    End Sub

    Sub tipoDocumentoClick(sender As Object, e As EventArgs)
        Dim link As LinkButton = CType(sender, LinkButton)
        Dim t As String = link.Attributes("tipoDocumento")

        Dim tipo As Integer = -1
        If Not Integer.TryParse(Convert.ToString(t), tipo) Then tipo = SafeTipoDocumentoId
        If Not TipoDocumentoExists(tipo) Then tipo = SafeTipoDocumentoId

        Response.Redirect("documenti.aspx?t=" & tipo.ToString())
    End Sub

    Sub aggiungiStato(sender As Object, e As EventArgs)
        filtroStati.Items.Insert(0, New ListItem("Qualsiasi stato", "-1"))
    End Sub

    '==============================================================
    ' FILTRO RAPIDO (ultima settimana, ultimo mese, ecc.)
    '==============================================================
    Sub filtroDataRapido(sender As Object, e As EventArgs) Handles filtroTempo.SelectedIndexChanged, filtroStati.SelectedIndexChanged

        Dim v As Integer = filtroTempo.SelectedValue

        dataFine.Text = Format(Date.Now, "dd-MM-yyyy")

        If (v = -1) Then
            dataInizio.Text = ""
        End If

        If (v = 7) Then
            dataInizio.Text = Format(Date.Now.AddDays(-7), "dd-MM-yyyy")
        End If

        If (v = 30) Then
            dataInizio.Text = Format(Date.Now.AddDays(-30), "dd-MM-yyyy")
        End If

        If (v = 60) Then
            dataInizio.Text = Format(Date.Now.AddDays(-60), "dd-MM-yyyy")
        End If

        If (v = 90) Then
            dataInizio.Text = Format(Date.Now.AddDays(-90), "dd-MM-yyyy")
        End If

        Session("filtroDocumentoDataInizio") = dataInizio.Text
        Session("filtroDocumentoDataFine") = dataFine.Text

        applicaFiltri(Nothing, Nothing)

    End Sub

    '==============================================================
    ' APPLICA FILTRI (date + stato) → aggiorna sdsDocumenti
    '==============================================================
    
    Private Function TryParseDDMMYYYY(ByVal raw As String, ByRef dt As DateTime) As Boolean
        If raw Is Nothing Then Return False
        raw = raw.Trim()
        If raw = "" Then Return False
        Return DateTime.TryParseExact(raw, "dd-MM-yyyy", System.Globalization.CultureInfo.GetCultureInfo("it-IT"), System.Globalization.DateTimeStyles.None, dt)
    End Function

Sub applicaFiltri(sender As Object, e As EventArgs)

        Dim tipoDocumentoId As Integer = SafeTipoDocumentoId

        ' Base query (con filtri aggiunti SOLO se validi)
        Dim strSql As String = ""
        strSql &= "SELECT vdocumenti.*, utenti.*, vettori.Link_Tracking, "
        strSql &= "COALESCE(dpay.Pagato,0) AS ListaPagato, "
        strSql &= "COALESCE(dpay.StatoPagamentoWeb,0) AS ListaStatoPagamentoWeb, "
        strSql &= "dpay.DataStatoPagamentoWeb AS ListaDataStatoPagamentoWeb, "
        strSql &= "COALESCE(dpay.UltimoEsitoPagamentoWeb,'') AS ListaUltimoEsitoPagamentoWeb, "
        strSql &= "COALESCE(pagamentitipo.Descrizione,'') AS ListaPagamentoDescrizione, "
        strSql &= "COALESCE(pagamentitipo.OnLine,0) AS ListaPagamentiTipoOnline "
        strSql &= "FROM `vdocumenti` "
        strSql &= "LEFT JOIN `utenti` ON `vdocumenti`.`UtentiId` = `utenti`.`Id` "
        strSql &= "LEFT JOIN (SELECT id, Link_Tracking FROM `vettori`) AS vettori ON `vdocumenti`.`VettoriId` = `vettori`.`id` "
        strSql &= "LEFT JOIN `pagamentitipo` ON `vdocumenti`.`PagamentiTipoId` = `pagamentitipo`.`id` "
        strSql &= "LEFT JOIN `documenti` dpay ON dpay.`id` = `vdocumenti`.`Id` "
        strSql &= "WHERE ((`vdocumenti`.`UtentiId`=?UtentiId) AND (`vdocumenti`.`TipoDocumentiId`=?TipoDocumentiId))"

        ' Stato
        Dim idStato As Integer = -1
        If filtroStati IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(filtroStati.SelectedValue), idStato) AndAlso idStato > -1 Then
            strSql &= " AND (`vdocumenti`.`StatiId`=?idStato)"
        Else
            idStato = -1
        End If

        ' Date range (formato dd-MM-yyyy)
        Dim hasInizio As Boolean = False
        Dim inizio As DateTime
        If dataInizio IsNot Nothing Then
            Dim rawInizio As String = Convert.ToString(dataInizio.Text)
            If TryParseDDMMYYYY(rawInizio, inizio) Then
                hasInizio = True
            Else
                dataInizio.Text = ""
            End If
        End If

        Dim fine As DateTime = DateTime.Now
        If dataFine IsNot Nothing Then
            Dim rawFine As String = Convert.ToString(dataFine.Text)
            Dim tmpFine As DateTime
            If TryParseDDMMYYYY(rawFine, tmpFine) Then
                fine = tmpFine
            Else
                fine = DateTime.Now
            End If
            dataFine.Text = fine.ToString("dd-MM-yyyy")
        End If

        If hasInizio Then
            strSql &= " AND (`vdocumenti`.`DataDocumento` >= ?DataInizio)"
        End If
        strSql &= " AND (`vdocumenti`.`DataDocumento` <= ?DataFine)"

        strSql &= " ORDER BY `vdocumenti`.`DataDocumento` DESC, `vdocumenti`.`NumeroDoc` DESC"

        sdsDocumenti.SelectCommand = strSql

        sdsDocumenti.SelectParameters.Clear()
        sdsDocumenti.SelectParameters.Add("UtentiId", TypeCode.Int32, Convert.ToString(Session("UtentiID")))
        sdsDocumenti.SelectParameters.Add("TipoDocumentiId", TypeCode.Int16, tipoDocumentoId.ToString())

        If idStato > -1 Then
            sdsDocumenti.SelectParameters.Add("idStato", TypeCode.Int16, idStato.ToString())
        End If
        If hasInizio Then
            sdsDocumenti.SelectParameters.Add("DataInizio", TypeCode.DateTime, inizio.ToString("yyyy-MM-dd"))
        End If
        sdsDocumenti.SelectParameters.Add("DataFine", TypeCode.DateTime, fine.ToString("yyyy-MM-dd"))

        GridView1.DataBind()
        nDocTrovati = GridView1.Rows.Count.ToString()

    End Sub

    '==============================================================
    ' Invio documento via email dal pulsante pdf2mail (imgStampaDoc)
    '==============================================================
    Sub stampaClick(sender As Object, e As System.Web.UI.ImageClickEventArgs)

        Dim link As ImageButton = CType(sender, ImageButton)
        Dim id As String = link.Attributes("idDoc")

        Try
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            strSql = "INSERT INTO INVIADOCUMENTI " &
                     "(UTENTIID, AZIENDEID, DOCUMENTIID, DataRichiesta) " &
                     "VALUES (@UTENTIID, @AziendaID, @DOCUMENTIID, Now())"

            Using cmdLocal As New MySqlCommand(strSql, conn)
                cmdLocal.CommandType = CommandType.Text
                cmdLocal.Parameters.AddWithValue("@UTENTIID", Session("UTENTIID"))
                cmdLocal.Parameters.AddWithValue("@AziendaID", Session("AziendaID"))
                cmdLocal.Parameters.AddWithValue("@DOCUMENTIID", id)
                cmdLocal.ExecuteNonQuery()
            End Using

            Session("esito_invio_mail") = 1

        Catch ex As Exception
            ' Se qualcosa va storto, segno esito = 0.
            Session("esito_invio_mail") = 0
            ' Non faccio Redirect qui: lo faccio nel Finally per avere sempre un solo redirect.
        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

            ' Torno sempre alla pagina documenti, con t invariato
            Response.Redirect("documenti.aspx?t=" & SafeTipoDocumentoId.ToString())
        End Try

    End Sub

    '==============================================================
    ' Eventuale RowCommand (se usi CommandName="Stampa" nella Grid)
    '==============================================================
    Protected Sub GridView1_RowCommand(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewCommandEventArgs) Handles GridView1.RowCommand

        If Page.IsPostBack = False Then
            Try
                Dim c As Control = DirectCast(e.CommandSource, Control)
                Dim r As GridViewRow = DirectCast(c.NamingContainer, GridViewRow)

                Dim ID_DOC As String = DirectCast(GridView1.Rows(r.RowIndex).FindControl("iddoc"), HyperLink).Text

                If (e.CommandName = "Stampa") Then
                    conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                    conn.Open()

                    strSql = "INSERT INTO INVIADOCUMENTI " &
                             "(UTENTIID, DOCUMENTIID, DataRichiesta) " &
                             "VALUES (@UTENTIID, @DOCUMENTIID, Now())"

                    Using cmdLocal As New MySqlCommand(strSql, conn)
                        cmdLocal.CommandType = CommandType.Text
                        cmdLocal.Parameters.AddWithValue("@UTENTIID", Session("UTENTIID"))
                        cmdLocal.Parameters.AddWithValue("@DOCUMENTIID", ID_DOC)
                        cmdLocal.ExecuteNonQuery()
                    End Using

                    Session("esito_invio_mail") = 1
                End If

            Catch ex As Exception
                Session("esito_invio_mail") = 0
            Finally
                If conn.State = ConnectionState.Open Then
                    conn.Close()
                    conn.Dispose()
                End If

                Response.Redirect("documenti.aspx?t=" & SafeTipoDocumentoId.ToString())
            End Try
        End If
    End Sub

    '==============================================================
    ' PreRender dei campi data (ricarica filtro da Session)
    '==============================================================
    Protected Sub dataInizio_PreRender(sender As Object, e As System.EventArgs) Handles dataInizio.PreRender
        If (dataInizio.Text = "") Then
            If Session("filtroDocumentoDataInizio") <> "" Then
                dataInizio.Text = Session("filtroDocumentoDataInizio")
            Else
                dataInizio.Text = ""
            End If
        End If
    End Sub

    Protected Sub dataFine_PreRender(sender As Object, e As System.EventArgs) Handles dataFine.PreRender
        If (dataFine.Text = "") Then
            If Session("filtroDocumentoDataInizio") <> "" Then
                dataFine.Text = Session("filtroDocumentoDataFine")
            Else
                dataFine.Text = Format(Date.Now, "dd-MM-yyyy")
            End If
        End If
    End Sub

    '==============================================================
    ' Numero documenti trovati (per label nDocTrovati)
    '==============================================================
    Protected Sub sdsDocumenti_Selected(sender As Object, e As System.Web.UI.WebControls.SqlDataSourceStatusEventArgs) Handles sdsDocumenti.Selected
        nDocTrovati = e.AffectedRows.ToString()
    End Sub

    '==============================================================
    ' Calendari
    '==============================================================
    Protected Sub Calendar1_SelectionChanged(sender As Object, e As System.EventArgs) Handles Calendar1.SelectionChanged
        dataInizio.Text = Format(Calendar1.SelectedDate, "dd-MM-yyyy")
        Calendar1.Visible = False
    End Sub

    Protected Sub Calendar2_SelectionChanged(sender As Object, e As System.EventArgs) Handles Calendar2.SelectionChanged
        dataFine.Text = Format(Calendar2.SelectedDate, "dd-MM-yyyy")
        Calendar2.Visible = False
    End Sub

    Protected Sub ib_calendarInizio_Click(sender As Object, e As System.Web.UI.ImageClickEventArgs) Handles ib_calendarInizio.Click
        Calendar1.Visible = True
    End Sub

    Protected Sub ImageButton1_Click(sender As Object, e As System.Web.UI.ImageClickEventArgs) Handles ImageButton1.Click
        Calendar2.Visible = True
    End Sub

    '==============================================================
    ' MostraPagaOra → usato nel markup per il bottone "Paga Ora"
    '==============================================================
    Public Function MostraPagaOra(ByVal documentIdObj As Object,
                                  ByVal pagatoObj As Object,
                                  ByVal codAutObj As Object,
                                  ByVal statiIdObj As Object,
                                  ByVal pagamentiTipoOnlineObj As Object,
                                  ByVal totaleDocumentoObj As Object) As String

        Try
            Dim documentId As Integer = SafeInt(documentIdObj, 0)
            If documentId > 0 Then
                Return If(CanShowPayNow(documentId), "", "none")
            End If

            Dim pagato As Integer = SafeInt(pagatoObj, 0)
            Dim statiId As Integer = SafeInt(statiIdObj, 0)
            Dim pagOnline As Integer = SafeInt(pagamentiTipoOnlineObj, 0)
            Dim totaleDocumento As Decimal = SafeDecimal(totaleDocumentoObj, 0D)
            Dim haAutorizzazione As Boolean = HasValue(codAutObj)

            If pagato = 0 AndAlso
               Not haAutorizzazione AndAlso
               statiId <> 0 AndAlso
               statiId <> 3 AndAlso
               pagOnline <> 0 AndAlso
               totaleDocumento > 0D Then

                Return ""
            Else
                Return "none"
            End If

        Catch
            ' In caso di dati sporchi, meglio NON mostrare "Paga Ora"
            Return "none"
        End Try

    End Function

    Public Function MostraPagaOra(ByVal pagatoObj As Object,
                                  ByVal codAutObj As Object,
                                  ByVal statiIdObj As Object,
                                  ByVal pagamentiTipoOnlineObj As Object) As String
        Return MostraPagaOra(Nothing, pagatoObj, codAutObj, statiIdObj, pagamentiTipoOnlineObj, Nothing)
    End Function

    Private Function CanShowPayNow(ByVal documentId As Integer) As Boolean
        If documentId <= 0 Then Return False

        Try
            Dim utentiId As Integer = SafeInt(Session("UtentiID"), 0)
            If utentiId <= 0 Then Return False

            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySql.Data.MySqlClient.MySqlConnection(cs)
                Dim sql As String = ""
                sql &= "SELECT "
                sql &= "  COALESCE(d.Pagato,0) AS Pagato, "
                sql &= "  COALESCE(d.StatiId,0) AS StatiId, "
                sql &= "  COALESCE(d.StatoPagamentoWeb,0) AS StatoPagamentoWeb, "
                sql &= "  COALESCE(p.OnLine,0) AS PagamentiTipoOnline, "
                sql &= "  COALESCE(p.PermettiPagamentoSuccessivo,0) AS PermettiPagamentoSuccessivo, "
                sql &= "  COALESCE(pie.TotaleDocumento,0) AS TotaleDocumento, "
                sql &= "  COALESCE(b.codiceAutorizzazione,'') AS CodiceAutorizzazione "
                sql &= "FROM documenti d "
                sql &= "LEFT JOIN pagamentitipo p ON p.id = d.PagamentiTipoId "
                sql &= "LEFT JOIN documentipie pie ON pie.DocumentiId = d.id "
                sql &= "LEFT JOIN bancasella_ordini_pagati b ON b.DocumentiId = d.id "
                sql &= "WHERE d.id=@id AND d.UtentiId=@uid "
                sql &= "LIMIT 1"

                Using cmd As New MySql.Data.MySqlClient.MySqlCommand(sql, c)
                    cmd.Parameters.Add("@id", MySql.Data.MySqlClient.MySqlDbType.Int32).Value = documentId
                    cmd.Parameters.Add("@uid", MySql.Data.MySqlClient.MySqlDbType.Int32).Value = utentiId
                    c.Open()

                    Using dr As MySql.Data.MySqlClient.MySqlDataReader = cmd.ExecuteReader()
                        If Not dr.Read() Then Return False

                        Dim pagato As Integer = SafeInt(dr("Pagato"), 0)
                        Dim statiId As Integer = SafeInt(dr("StatiId"), 0)
                        Dim statoPagamentoWeb As Integer = SafeInt(dr("StatoPagamentoWeb"), 0)
                        Dim online As Integer = SafeInt(dr("PagamentiTipoOnline"), 0)
                        Dim permettePagamentoSuccessivo As Integer = SafeInt(dr("PermettiPagamentoSuccessivo"), 0)
                        Dim totaleDocumento As Decimal = SafeDecimal(dr("TotaleDocumento"), 0D)
                        Dim haAutorizzazione As Boolean = HasValue(dr("CodiceAutorizzazione"))

                        Return pagato = 0 AndAlso
                               online <> 0 AndAlso
                               permettePagamentoSuccessivo = 1 AndAlso
                               (statoPagamentoWeb = 0 OrElse statoPagamentoWeb = 3 OrElse statoPagamentoWeb = 4 OrElse statoPagamentoWeb = 5) AndAlso
                               Not haAutorizzazione AndAlso
                               statiId <> 0 AndAlso
                               statiId <> 3 AndAlso
                               totaleDocumento > 0D
                    End Using
                End Using
            End Using
        Catch
            Return False
        End Try
    End Function

    Private Function SafeInt(ByVal value As Object, ByVal fallback As Integer) As Integer
        Try
            If value Is Nothing OrElse IsDBNull(value) Then Return fallback
            Dim parsed As Integer = fallback
            If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return fallback
    End Function

    Private Function SafeDecimal(ByVal value As Object, ByVal fallback As Decimal) As Decimal
        Try
            If value Is Nothing OrElse IsDBNull(value) Then Return fallback
            Dim parsed As Decimal = fallback
            If Decimal.TryParse(Convert.ToString(value), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, parsed) Then Return parsed
            If Decimal.TryParse(Convert.ToString(value), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.GetCultureInfo("it-IT"), parsed) Then Return parsed
        Catch
        End Try

        Return fallback
    End Function

    Private Function HasValue(ByVal value As Object) As Boolean
        If value Is Nothing OrElse IsDBNull(value) Then Return False
        Return Convert.ToString(value).Trim() <> ""
    End Function

    Protected Function FormatOrderStatus(ByVal stato1Obj As Object, ByVal stato2Obj As Object) As String
        Dim stato1 As String = SafeStatusText(stato1Obj)
        Dim stato2 As String = SafeStatusText(stato2Obj)

        If stato1 = "" Then Return If(stato2 = "", "Non disponibile", stato2)
        If stato2 = "" Then Return stato1
        Return (stato1 & " " & stato2).Trim()
    End Function

    Protected Function GetPaymentStatusLabel(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)

        If pagato = 1 OrElse stato = 2 Then Return "Pagato"

        Select Case stato
            Case 1
                Return "In verifica PayPal"
            Case 3
                Return "Non completato"
            Case 4
                Return "Annullato dall'utente"
            Case 5
                Return "In verifica"
            Case Else
                Return "Non avviato"
        End Select
    End Function

    Protected Function GetPaymentStatusCssClass(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)
        Dim baseClass As String = "ks-status-badge "

        If pagato = 1 OrElse stato = 2 Then Return baseClass & "is-success"

        Select Case stato
            Case 1, 5
                Return baseClass & "is-warning"
            Case 3
                Return baseClass & "is-danger"
            Case 4
                Return baseClass & "is-canceled"
            Case Else
                Return baseClass & "is-muted"
        End Select
    End Function

    Protected Function GetPaymentStatusDescription(ByVal pagatoObj As Object,
                                                   ByVal statoObj As Object,
                                                   ByVal esitoObj As Object,
                                                   ByVal onlineObj As Object,
                                                   ByVal pagamentoObj As Object) As String
        Dim esito As String = SafePaymentMessage(esitoObj)
        If esito <> "" Then Return esito

        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)
        Dim online As Integer = SafeInt(onlineObj, 0)
        Dim pagamento As String = SafeStatusText(pagamentoObj)

        If pagato = 1 OrElse stato = 2 Then Return "Pagamento confermato."

        Select Case stato
            Case 1
                Return "Pagamento in attesa di conferma dal gateway."
            Case 3
                Return "Pagamento non completato."
            Case 4
                Return "Pagamento annullato dall'utente."
            Case 5
                Return "Pagamento in verifica."
            Case Else
                If online = 0 AndAlso pagamento <> "" Then
                    Return "Metodo: " & pagamento
                End If
                Return "Pagamento non ancora avviato."
        End Select
    End Function

    Private Function SafePaymentMessage(ByVal value As Object) As String
        Dim text As String = SafeStatusText(value)
        If text = "" Then Return ""

        Dim lower As String = text.ToLowerInvariant()
        If lower.Contains("ec-token") OrElse lower.Contains("token=") OrElse lower.Contains("signature") OrElse lower.Contains("pwd") Then
            Return "Dettaglio pagamento disponibile nel documento."
        End If

        Return TruncateText(text, 90)
    End Function

    Private Function SafeStatusText(ByVal value As Object) As String
        If value Is Nothing OrElse IsDBNull(value) Then Return ""

        Dim text As String = Convert.ToString(value).Trim()
        If text = "" Then Return ""

        text = text.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ")
        Do While text.Contains("  ")
            text = text.Replace("  ", " ")
        Loop

        Return text
    End Function

    Private Function TruncateText(ByVal value As String, ByVal maxLength As Integer) As String
        If String.IsNullOrEmpty(value) Then Return ""
        If maxLength <= 0 Then Return ""
        If value.Length <= maxLength Then Return value
        Return value.Substring(0, maxLength).TrimEnd() & "..."
    End Function

    '==============================================================
    ' KeepStore: forza <thead> per compatibilita stile tema
    '==============================================================
    Protected Sub GridView1_PreRender_22B(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView1.PreRender
        Try
            GridView1.UseAccessibleHeader = True
            If GridView1.HeaderRow IsNot Nothing Then
                GridView1.HeaderRow.TableSection = System.Web.UI.WebControls.TableRowSection.TableHeader
            End If
        Catch
        End Try
    End Sub

    Public Function testNote(ByVal note As Object) As String
        Try
            Return CStr(IIf(note = "", "display:none;", ""))
        Catch
            Return "display:none;"
        End Try
    End Function

    ' Sanifica l’href del tracking (no javascript:, no valori vuoti, no DBNull)
    Public Function SafeTrackingHref(ByVal trackingObj As Object) As String
        Try
            If trackingObj Is Nothing OrElse IsDBNull(trackingObj) Then
                Return ""
            End If

            Dim url As String = trackingObj.ToString().Trim()
            If String.IsNullOrEmpty(url) Then
                Return ""
            End If

            Dim lower As String = url.ToLowerInvariant()
            If Not (lower.StartsWith("http://") OrElse lower.StartsWith("https://")) Then
                ' Blocca link non sicuri (javascript:, data:, ecc.)
                Return ""
            End If

            Dim safeUrl As String = System.Web.HttpUtility.HtmlAttributeEncode(url)
            Return "href=\"" & safeUrl & "\""
        Catch
            Return ""
        End Try
    End Function

    ' Gestisce la logica del tracking multiplo usando il template Link_Tracking
    Public Function separa_tracking(ByVal trackingObj As Object, ByVal linkTrackingObj As Object) As String
        Dim tracking As String = ""
        Dim link_tracking As String = ""

        If trackingObj IsNot Nothing AndAlso Not IsDBNull(trackingObj) Then
            tracking = trackingObj.ToString()
        End If

        If linkTrackingObj IsNot Nothing AndAlso Not IsDBNull(linkTrackingObj) Then
            link_tracking = linkTrackingObj.ToString()
        End If

        If String.IsNullOrWhiteSpace(tracking) OrElse String.IsNullOrWhiteSpace(link_tracking) Then
            Return ""
        End If

        Dim ltLower As String = link_tracking.ToLowerInvariant()
        If Not (ltLower.StartsWith("http://") OrElse ltLower.StartsWith("https://")) Then
            ' Template di tracking non sicuro: non mostro nulla
            Return ""
        End If

        Dim temp As String() = tracking.Split(";"c)
        Dim sb As New System.Text.StringBuilder()

        For Each codiceRaw As String In temp
            Dim codice As String = codiceRaw.Trim()
            If codice <> "" Then
                Dim safeCode As String = System.Web.HttpUtility.HtmlEncode(codice)
                Dim href As String = link_tracking.Replace("#ID#", codice)
                Dim safeHref As String = System.Web.HttpUtility.HtmlAttributeEncode(href)

                sb.Append("<img src=""/Public/Images/interrogativo.png"" alt="""" title=""Clicca sul Numero Tracking"">")
                sb.Append("<a href=""")
                sb.Append(safeHref)
                sb.Append(""" target=""_blank"">")
                sb.Append(safeCode)
                sb.Append("</a>; ")
            End If
        Next

        Return sb.ToString()
    End Function

End Class
