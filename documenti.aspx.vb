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
    ' CSS stato ordine (classi Onsus)
    '==============================================================
    Protected Function GetOrderStatusCss(ByVal statusObj As Object) As String
        Try
            Dim s As String = ""
            If statusObj IsNot Nothing AndAlso Not Convert.IsDBNull(statusObj) Then
                s = statusObj.ToString().Trim().ToLowerInvariant()
            End If
            If String.IsNullOrEmpty(s) Then Return ""

            If s.Contains("consegn") OrElse s.Contains("delivered") Then
                Return "text-delivered"
            End If
            If s.Contains("sped") OrElse s.Contains("in trans") OrElse s.Contains("on the way") OrElse s.Contains("in consegn") Then
                Return "text-on-the-way"
            End If
            If s.Contains("annull") OrElse s.Contains("cancell") OrElse s.Contains("rifiut") Then
                Return "text-cancelled"
            End If
            If s.Contains("lavor") OrElse s.Contains("processing") OrElse s.Contains("prepar") Then
                Return "text-processing"
            End If

            Return ""
        Catch
            Return ""
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
        Dim strSql As String = "SELECT `Id`, `DataDocumento`, `NumeroDoc`, `DocumentoStatiId`, `StatiId`, `Stati`, `TipoDocumento`, `TipoDoc`, `Token`, `TipoDocumentoAvanzato`, `TipoDocAv`, `IdDocumentoAvanzato`, `Note`, `DocumentoStatoAvanzatoId`, `StatoAvanzato`, `Magazzino` FROM `vdocumenti` WHERE ((`UtentiId`=?UtentiId) AND (`TipoDocumentiId`=?TipoDocumentiId))"

        ' Stato
        Dim idStato As Integer = -1
        If filtroStati IsNot Nothing AndAlso Integer.TryParse(Convert.ToString(filtroStati.SelectedValue), idStato) AndAlso idStato > -1 Then
            strSql &= " AND (`StatiId`=?idStato)"
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
            strSql &= " AND (`DataDocumento` >= ?DataInizio)"
        End If
        strSql &= " AND (`DataDocumento` <= ?DataFine)"

        strSql &= " ORDER BY `DataDocumento` DESC, `NumeroDoc` DESC"

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
    Public Function MostraPagaOra(ByVal pagatoObj As Object,
                                  ByVal codAutObj As Object,
                                  ByVal statiIdObj As Object,
                                  ByVal pagamentiTipoOnlineObj As Object) As String

        Try
            Dim pagato As Integer = 0
            Dim statiId As Integer = 0
            Dim pagOnline As Integer = 0
            Dim haAutorizzazione As Boolean = False

            If pagatoObj IsNot Nothing AndAlso Not IsDBNull(pagatoObj) Then
                Integer.TryParse(pagatoObj.ToString(), pagato)
            End If

            If statiIdObj IsNot Nothing AndAlso Not IsDBNull(statiIdObj) Then
                Integer.TryParse(statiIdObj.ToString(), statiId)
            End If

            If pagamentiTipoOnlineObj IsNot Nothing AndAlso Not IsDBNull(pagamentiTipoOnlineObj) Then
                Integer.TryParse(pagamentiTipoOnlineObj.ToString(), pagOnline)
            End If

            If codAutObj IsNot Nothing AndAlso Not IsDBNull(codAutObj) Then
                haAutorizzazione = (codAutObj.ToString().Trim() <> "")
            End If

            ' Stessa logica del badge "ordini da saldare"
            If pagato = 0 AndAlso
               Not haAutorizzazione AndAlso
               statiId <> 0 AndAlso
               statiId <> 3 AndAlso
               pagOnline <> 0 Then

                ' Mostra il bottone
                Return ""
            Else
                ' Nascondi il bottone
                Return "none"
            End If

        Catch
            ' In caso di dati sporchi, meglio NON mostrare "Paga Ora"
            Return "none"
        End Try

    End Function

End Class
