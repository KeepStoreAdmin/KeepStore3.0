Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Configuration

Partial Class documenti
    Inherits System.Web.UI.Page

    Dim conn As New MySqlConnection
    Dim strSql As String = ""

    Public nDocTrovati As String = "0"
    Private _orderIdentity As OrderStorefrontIdentity

    Private ReadOnly Property CurrentOrderIdentity As OrderStorefrontIdentity
        Get
            If _orderIdentity Is Nothing Then _orderIdentity = OrderStorefrontContext.Resolve(HttpContext.Current)
            Return _orderIdentity
        End Get
    End Property

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

        If CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete Then
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

            If HasDocumentFiltersRequest() Then
                ApplyFilterControlsFromRequest()
            End If
        End If

        ' KS-DASHBOARD-ORDERS-1B: comando e parametri a OGNI richiesta (anche il postback della paginazione): il comando non e persistito nel ViewState.
        ConfigureSelectFromRequest()
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
        TrySetListValue(filtroStati, KeepStoreAccountOrderFilters.SafeStato(Request.QueryString("stato")).ToString(System.Globalization.CultureInfo.InvariantCulture))
    End Sub

    '==============================================================
    ' FILTRI: tipo, stato, periodo e date arrivano SEMPRE dalla query string e si validano con il modulo puro.
    ' Il SelectCommand NON e persistito nel ViewState (a ogni richiesta torna quello del markup, che non restituisce righe) mentre SelectParameters si:
    ' per questo comando e parametri si impostano a ogni richiesta e i valori tipizzati entrano in sdsDocumenti_Selecting, mai nel ViewState.
    '==============================================================
    Private _listReady As Boolean = False
    Private _listTipo As Integer = 0
    Private _listStato As Integer = -1
    Private _listHasDal As Boolean = False
    Private _listHasAl As Boolean = False
    Private _listDal As DateTime = DateTime.MinValue
    Private _listAl As DateTime = DateTime.MinValue

    Private Function HasDocumentFiltersRequest() As Boolean
        Return Request.QueryString("stato") IsNot Nothing OrElse
               Request.QueryString("tempo") IsNot Nothing OrElse
               Request.QueryString("dal") IsNot Nothing OrElse
               Request.QueryString("al") IsNot Nothing
    End Function

    Private Sub ReadRangeFromRequest(ByRef tempo As Integer, ByRef dal As DateTime, ByRef al As DateTime, ByRef hasDal As Boolean, ByRef hasAl As Boolean)
        tempo = KeepStoreAccountOrderFilters.SafeTempo(Request.QueryString("tempo"))
        KeepStoreAccountOrderFilters.ResolveRange(tempo, Request.QueryString("dal"), Request.QueryString("al"), DateTime.Now, dal, al, hasDal, hasAl)
    End Sub

    ' Primo caricamento: i controlli mostrano soltanto cio che sta nella query string; con un periodo rapido le date restano vuote.
    Private Sub ApplyFilterControlsFromRequest()
        Dim tempo As Integer, dal As DateTime, al As DateTime, hasDal As Boolean, hasAl As Boolean
        ReadRangeFromRequest(tempo, dal, al, hasDal, hasAl)
        TrySetListValue(filtroTempo, tempo.ToString(System.Globalization.CultureInfo.InvariantCulture))
        If tempo <= 0 Then
            If hasDal Then dataInizio.Text = KeepStoreAccountOrderFilters.FormatFilterDate(dal)
            If hasAl Then dataFine.Text = KeepStoreAccountOrderFilters.FormatFilterDate(al)
        End If
    End Sub

    Private Sub ConfigureSelectFromRequest()
        Dim tempo As Integer, dal As DateTime, al As DateTime, hasDal As Boolean, hasAl As Boolean
        ReadRangeFromRequest(tempo, dal, al, hasDal, hasAl)
        ConfigureDocumentSelect(SafeTipoDocumentoId, KeepStoreAccountOrderFilters.SafeStato(Request.QueryString("stato")), hasDal, dal, hasAl, al)
    End Sub

    Private Sub ConfigureDocumentSelect(ByVal tipoDocumentoId As Integer,
                                        ByVal idStato As Integer,
                                        ByVal hasDal As Boolean,
                                        ByVal dal As DateTime,
                                        ByVal hasAl As Boolean,
                                        ByVal al As DateTime)
        sdsDocumenti.SelectCommand = KeepStoreAccountOrderFilters.BuildListSql(idStato > -1, hasDal, hasAl)
        sdsDocumenti.SelectParameters.Clear()
        _listTipo = tipoDocumentoId
        _listStato = idStato
        _listHasDal = hasDal
        _listDal = dal
        _listHasAl = hasAl
        _listAl = al
        _listReady = True
    End Sub

    ' Parametri tipizzati: utente e azienda SOLO dall'identita verificata dell'host; senza identita completa o senza configurazione la lettura e annullata.
    Protected Sub sdsDocumenti_Selecting(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.SqlDataSourceSelectingEventArgs) Handles sdsDocumenti.Selecting
        Dim identity As OrderStorefrontIdentity = CurrentOrderIdentity
        If Not _listReady OrElse identity Is Nothing OrElse Not identity.IsComplete Then
            e.Cancel = True
            Return
        End If
        Dim parameters As System.Data.Common.DbParameterCollection = e.Command.Parameters
        parameters.Add(New MySqlParameter("?UtentiId", MySqlDbType.Int64) With {.Value = identity.UtentiId})
        parameters.Add(New MySqlParameter("?AziendaId", MySqlDbType.Int32) With {.Value = identity.CompanyId})
        parameters.Add(New MySqlParameter("?TipoDocumentiId", MySqlDbType.Int32) With {.Value = _listTipo})
        If _listStato > -1 Then parameters.Add(New MySqlParameter("?Stato", MySqlDbType.Int32) With {.Value = _listStato})
        If _listHasDal Then parameters.Add(New MySqlParameter("?Dal", MySqlDbType.Date) With {.Value = _listDal})
        If _listHasAl Then parameters.Add(New MySqlParameter("?Al", MySqlDbType.Date) With {.Value = _listAl})
    End Sub

    ' Senza JavaScript il pulsante Filtra e i filtri a tendina inviano il form: si torna all'indirizzo canonico, cosi la paginazione conserva i filtri.
    Sub applicaFiltri(sender As Object, e As EventArgs)
        Dim idStato As Integer = -1
        If filtroStati IsNot Nothing Then idStato = KeepStoreAccountOrderFilters.SafeStato(filtroStati.SelectedValue)
        Dim tempo As Integer = -1
        If filtroTempo IsNot Nothing Then tempo = KeepStoreAccountOrderFilters.SafeTempo(filtroTempo.SelectedValue)
        Response.Redirect(KeepStoreAccountOrderFilters.BuildListUrl(SafeTipoDocumentoId, idStato, tempo, dataInizio.Text, dataFine.Text))
    End Sub

    ' «Altre date» si apre da solo soltanto se la query string porta date scelte dall'utente.
    Protected ReadOnly Property MoreDatesOpenAttribute As String
        Get
            Dim tempo As Integer, dal As DateTime, al As DateTime, hasDal As Boolean, hasAl As Boolean
            ReadRangeFromRequest(tempo, dal, al, hasDal, hasAl)
            If tempo <= 0 AndAlso (hasDal OrElse hasAl) Then Return " open"
            Return ""
        End Get
    End Property
    Private Sub TrySetListValue(ByVal list As ListControl, ByVal value As String)
        If list Is Nothing Then Exit Sub
        Dim item As ListItem = list.Items.FindByValue(value)
        If item Is Nothing Then Exit Sub

        list.ClearSelection()
        item.Selected = True
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
            Dim documentId As Integer = SafeInt(id, 0)
            If Not DocumentBelongsToCurrentStorefront(conn, documentId) Then Throw New UnauthorizedAccessException("Document scope mismatch.")

            strSql = "INSERT INTO INVIADOCUMENTI " &
                     "(UTENTIID, AZIENDEID, DOCUMENTIID, DataRichiesta) " &
                     "VALUES (@UTENTIID, @AziendaID, @DOCUMENTIID, Now())"

            Using cmdLocal As New MySqlCommand(strSql, conn)
                cmdLocal.CommandType = CommandType.Text
                cmdLocal.Parameters.AddWithValue("@UTENTIID", CurrentOrderIdentity.UtentiId)
                cmdLocal.Parameters.AddWithValue("@AziendaID", CurrentOrderIdentity.CompanyId)
                cmdLocal.Parameters.AddWithValue("@DOCUMENTIID", documentId)
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
                    Dim documentId As Integer = SafeInt(ID_DOC, 0)
                    If Not DocumentBelongsToCurrentStorefront(conn, documentId) Then Throw New UnauthorizedAccessException("Document scope mismatch.")

                    strSql = "INSERT INTO INVIADOCUMENTI " &
                             "(UTENTIID, AZIENDEID, DOCUMENTIID, DataRichiesta) " &
                             "VALUES (@UTENTIID, @AziendaID, @DOCUMENTIID, Now())"

                    Using cmdLocal As New MySqlCommand(strSql, conn)
                        cmdLocal.CommandType = CommandType.Text
                        cmdLocal.Parameters.AddWithValue("@UTENTIID", CurrentOrderIdentity.UtentiId)
                        cmdLocal.Parameters.AddWithValue("@AziendaID", CurrentOrderIdentity.CompanyId)
                        cmdLocal.Parameters.AddWithValue("@DOCUMENTIID", documentId)
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
    ' Numero documenti trovati (per label nDocTrovati)
    '==============================================================
    Protected Sub sdsDocumenti_Selected(sender As Object, e As System.Web.UI.WebControls.SqlDataSourceStatusEventArgs) Handles sdsDocumenti.Selected
        nDocTrovati = e.AffectedRows.ToString()
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

            ' Senza documentId non e possibile provare owner, tenant e provenienza.
            Return "none"

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

    ' ORDER-REMOTE-PAYMENT-1A: usato dal markup della lista per mostrare «Da pagare» e il pulsante «Paga adesso» solo quando la decisione completa lo ammette.
    Protected Function ListPayNowVisible(ByVal documentIdObj As Object) As Boolean
        Return CanShowPayNow(SafeInt(documentIdObj, 0))
    End Function

    ' KS-MYACCOUNT-1B: la scheda chiede la decisione due volte (etichetta e pulsante): si calcola una volta per documento nella richiesta.
    Private ReadOnly _payNowDecisions As New System.Collections.Generic.Dictionary(Of Integer, Boolean)()

    Private Function CanShowPayNow(ByVal documentId As Integer) As Boolean
        If documentId <= 0 Then Return False
        Dim cached As Boolean = False
        If _payNowDecisions.TryGetValue(documentId, cached) Then Return cached
        Dim decision As Boolean = False
        ' ORDER-REMOTE-PAYMENT-1A: decisione completa sui fatti del documento (una sola query, owner e azienda dell'identita verificata); ogni errore chiude.
        Try
            If CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete Then Return False
            decision = InternalOrderRemotePaymentPolicy.CanPayNow(
                KeepStoreRemotePaymentStore.LoadFacts(documentId, CurrentOrderIdentity.UtentiId, CurrentOrderIdentity.CompanyId), True, True)
        Catch
            decision = False
        End Try
        _payNowDecisions(documentId) = decision
        Return decision
    End Function

    Private Function DocumentBelongsToCurrentStorefront(ByVal connection As MySqlConnection,
                                                        ByVal documentId As Integer) As Boolean
        If connection Is Nothing OrElse documentId <= 0 OrElse
           CurrentOrderIdentity Is Nothing OrElse Not CurrentOrderIdentity.IsComplete Then Return False
        Using command As New MySqlCommand(
            "SELECT COUNT(*) FROM documenti WHERE id=@id AND UtentiId=@utentiId AND AziendeId=@aziendaId",
            connection)
            command.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
            command.Parameters.Add("@utentiId", MySqlDbType.Int64).Value = CurrentOrderIdentity.UtentiId
            command.Parameters.Add("@aziendaId", MySqlDbType.Int32).Value = CurrentOrderIdentity.CompanyId
            Return Convert.ToInt32(command.ExecuteScalar()) = 1
        End Using
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

    Protected Function OrderStatusTitle(ByVal stato1Obj As Object, ByVal stato2Obj As Object) As String
        Return KeepStoreAccountOrderFilters.StatusTitle(stato1Obj, stato2Obj)
    End Function

    Protected Function OrderStatusNote(ByVal stato1Obj As Object, ByVal stato2Obj As Object) As String
        Return KeepStoreAccountOrderFilters.StatusNote(stato1Obj, stato2Obj)
    End Function
    Protected Function GetPaymentMethodLabel(ByVal value As Object) As String
        Dim text As String = SafeStatusText(value)
        If text = "" Then Return "Non specificato"
        Return text
    End Function

    Protected Function GetPaymentStatusLabel(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, -1)

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
            Case 0
                Return "Non avviato"
            Case Else
                Return "Non verificabile"
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
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, -1)
        If pagato <> 1 AndAlso (stato < 0 OrElse stato > 5) Then Return "Stato del pagamento non verificabile."

        Dim esito As String = SafePaymentMessage(esitoObj)
        If esito <> "" Then Return esito

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

    ' KS-MYACCOUNT-1B: mini barra e tracking della scheda, dal modulo puro e provato (testo codificato, collegamento solo se sicuro, niente per gli annullati).
    Protected Function ListProgressHtml(ByVal isOrderObj As Object, ByVal statiIdObj As Object) As String
        Return KeepStoreOrderProgress.MiniProgressHtml(SafeInt(isOrderObj, 0) = 1, SafeInt(statiIdObj, 0))
    End Function

    Protected Function ListTrackingHtml(ByVal trackingObj As Object, ByVal linkTrackingObj As Object, ByVal statiIdObj As Object) As String
        Dim tracking As String = If(HasValue(trackingObj), Convert.ToString(trackingObj), "")
        Dim template As String = If(HasValue(linkTrackingObj), Convert.ToString(linkTrackingObj), "")
        Return KeepStoreOrderProgress.TrackingLinksHtml(tracking, template, SafeInt(statiIdObj, 0))
    End Function
End Class
