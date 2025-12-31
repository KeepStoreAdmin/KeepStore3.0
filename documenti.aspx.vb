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
            Dim t1 As String = Request.QueryString("t")

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

        Response.Redirect("documenti.aspx?t=" & t)
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
    Sub applicaFiltri(sender As Object, e As EventArgs)

        Dim idStato As Integer = filtroStati.SelectedValue
        Dim inizio As Date
        Dim fine As Date

        Try
            inizio = Date.Parse(dataInizio.Text)
        Catch
            dataInizio.Text = ""
            inizio = Date.MinValue
        End Try

        Try
            fine = Date.Parse(dataFine.Text)
        Catch
            fine = Date.Now
            dataFine.Text = Format(fine, "dd-MM-yyyy")
        End Try

        Dim condizione As String = ""

        If idStato > -1 Then
            ' uso ?idStato perché il provider è MySql (stessa sintassi che usi già per ?UtentiId)
            condizione = " AND (StatiId = ?idStato)"
        End If

        sdsDocumenti.SelectCommand =
            "SELECT * FROM (`vdocumenti` " &
            "LEFT JOIN `utenti` ON (`vdocumenti`.`UtentiId` = `utenti`.`Id`) " &
            "LEFT JOIN (SELECT id, Link_Tracking FROM `vettori`) AS vettori ON (`vdocumenti`.`VettoriId` = `vettori`.`id`) " &
            ") LEFT JOIN pagamentitipo ON vdocumenti.pagamentiTipoId = pagamentiTipo.id " &
            "WHERE ( (UtentiId = ?UtentiId) " &
            "AND (TipoDocumentiId = ?TipoDocumentiId) " &
            "AND (DataDocumento >= '" & Format(inizio, "yyyy-MM-dd") & "') " &
            "AND (DataDocumento <= '" & Format(fine, "yyyy-MM-dd") & "') " &
            condizione & " ) " &
            "ORDER BY vdocumenti.ID DESC"

        ' RIMETTO TUTTI I PARAMETRI A MANO (li avevi cancellati con Clear)
        sdsDocumenti.SelectParameters.Clear()
        sdsDocumenti.SelectParameters.Add("UtentiId", TypeCode.Int32, Convert.ToString(Session("UtentiID")))
        sdsDocumenti.SelectParameters.Add("TipoDocumentiId", TypeCode.Int16, Convert.ToString(Request.QueryString("t")))
        If idStato > -1 Then
            sdsDocumenti.SelectParameters.Add("idStato", TypeCode.Int32, idStato.ToString())
        End If

        Session("filtroDocumentoDataInizio") = dataInizio.Text
        Session("filtroDocumentoDataFine") = dataFine.Text

        rTipo.DataBind()

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
            Response.Redirect("documenti.aspx?t=" & Request.QueryString("t"))
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

                Response.Redirect("documenti.aspx")
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
