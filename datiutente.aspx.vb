Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Configuration
Imports System.Web.UI.WebControls

Partial Class datiutente
    Inherits System.Web.UI.Page

    Private ReadOnly Property ConnString As String
        Get
            Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        ' PAGINA PROTETTA
        If Session("LoginId") Is Nothing Then
            Session("Pagina_visitata") = Request.Url
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        If Not IsPostBack Then
            lblEsito.Text = ""
            PrepareLegacyFormViews()

            ' Supporto deep-link in modalità modifica (es. da my-account-edit.aspx)
            Dim qEdit As String = Convert.ToString(Request.QueryString("edit"))
            If String.Equals(qEdit, "1", StringComparison.OrdinalIgnoreCase) OrElse String.Equals(qEdit, "true", StringComparison.OrdinalIgnoreCase) Then
                fvUtente.ChangeMode(FormViewMode.Edit)
            End If

            BindUtenteFormView()
        End If
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - I miei dati"
    End Sub

    ' Cambio modalità (ReadOnly/Edit)
    Protected Sub fvUtente_ModeChanging(ByVal sender As Object, ByVal e As FormViewModeEventArgs)
        fvUtente.ChangeMode(e.NewMode)
        BindUtenteFormView()
        lblEsito.Text = ""
    End Sub

    Private Sub PrepareLegacyFormViews()
        If FormView1 IsNot Nothing Then FormView1.Visible = False
        If fvDatiUtente IsNot Nothing Then fvDatiUtente.Visible = False
        If fvUtente IsNot Nothing Then fvUtente.Visible = True
    End Sub

    Private Sub BindUtenteFormView()
        If fvUtente Is Nothing Then
            ShowUserDataMessage("Non e stato possibile caricare la sezione dati utente.")
            Return
        End If

        Dim loginId As Integer = CurrentLoginId()
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        Try
            Dim dt As DataTable = LoadUtenteData(loginId)
            fvUtente.DataKeyNames = New String() {"UtentiId"}
            fvUtente.DataSource = dt
            fvUtente.DataBind()

            If dt.Rows.Count = 0 Then
                ShowUserDataMessage("Non sono stati trovati dati per il profilo corrente.")
            End If
        Catch
            fvUtente.Visible = False
            ShowUserDataMessage("Non e stato possibile caricare i dati. Riprova piu tardi.")
        End Try
    End Sub

    Private Function CurrentLoginId() As Integer
        Dim loginId As Integer = 0
        If Session("LoginId") IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session("LoginId")), loginId)
        End If
        Return loginId
    End Function

    Private Function LoadUtenteData(ByVal loginId As Integer) As DataTable
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            Dim sql As String =
                "SELECT " &
                "u.id AS UtentiId, " &
                "COALESCE(v.Username,'') AS username, " &
                "COALESCE(v.email, u.Email, '') AS email, " &
                "COALESCE(v.cognomenome,'') AS cognomenome, " &
                "v.ultimoaccesso AS ultimoaccesso, " &
                "COALESCE(u.Codice,'') AS Codice, " &
                "COALESCE(u.RagioneSociale,'') AS RagioneSociale, " &
                "COALESCE(u.Piva,'') AS Piva, " &
                "COALESCE(u.CodiceFiscale,'') AS CodiceFiscale, " &
                "COALESCE(u.Telefono,'') AS Telefono, " &
                "COALESCE(u.Cellulare,'') AS Cellulare, " &
                "COALESCE(u.Fax,'') AS Fax, " &
                "COALESCE(u.Indirizzo,'') AS Indirizzo, " &
                "COALESCE(u.Cap,'') AS Cap, " &
                "COALESCE(u.Citta,'') AS Citta, " &
                "COALESCE(u.Provincia,'') AS Provincia, " &
                "COALESCE(u.Nazione,'') AS Nazione " &
                "FROM vlogin v " &
                "INNER JOIN utenti u ON v.utentiid = u.id " &
                "WHERE v.id = @LoginId " &
                "LIMIT 1"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@LoginId", loginId)
                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        EnsureLegacyDisplayColumns(dt)

        Return dt
    End Function

    Private Sub EnsureLegacyDisplayColumns(ByVal dt As DataTable)
        If dt Is Nothing OrElse dt.Rows.Count = 0 Then Return

        EnsureColumn(dt, "listino", GetSessionText("listino", GetSessionText("Listino", "")))
        EnsureColumn(dt, "UtenteTipoDescrizione", GetSessionText("UtentiTipoDescrizione", ""))
        EnsureColumn(dt, "IvaTipo", GetSessionInt("IvaTipo", 2))
        EnsureColumn(dt, "DescrizioneEsenzioneIva", GetSessionText("DescrizioneEsenzioneIva", ""))
        EnsureColumn(dt, "AbilitatoIvaReverseCharge", GetSessionInt("AbilitatoIvaReverseCharge", 0) = 1)
    End Sub

    Private Sub EnsureColumn(ByVal dt As DataTable, ByVal columnName As String, ByVal value As Object)
        If Not dt.Columns.Contains(columnName) Then
            dt.Columns.Add(columnName, If(value Is Nothing, GetType(String), value.GetType()))
        End If

        For Each row As DataRow In dt.Rows
            row(columnName) = If(value Is Nothing, "", value)
        Next
    End Sub

    Private Function GetSessionText(ByVal key As String, ByVal fallback As String) As String
        If Session IsNot Nothing AndAlso Session(key) IsNot Nothing Then
            Return Convert.ToString(Session(key))
        End If
        Return fallback
    End Function

    Private Function GetSessionInt(ByVal key As String, ByVal fallback As Integer) As Integer
        Dim value As Integer = fallback
        If Session IsNot Nothing AndAlso Session(key) IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session(key)), value)
        End If
        Return value
    End Function

    Private Sub ShowUserDataMessage(ByVal message As String)
        If lblEsito Is Nothing Then Return
        lblEsito.Text = message
        lblEsito.CssClass = "ks-esito alert alert-warning py-2 px-3 mb-3"
    End Sub

    ' Quando il FormView ha fatto DataBind
    Protected Sub fvUtente_DataBound(ByVal sender As Object, ByVal e As EventArgs)
        If fvUtente.Row Is Nothing Then Return

        Dim utentiId As Integer = 0
        If fvUtente.DataKey IsNot Nothing AndAlso fvUtente.DataKey("UtentiId") IsNot Nothing Then
            Integer.TryParse(fvUtente.DataKey("UtentiId").ToString(), utentiId)
        End If

        If fvUtente.CurrentMode = FormViewMode.Edit Then
            Dim row As FormViewRow = fvUtente.Row

            ' --- Anagrafica principale ---
            Dim tbCapEdit As TextBox = FindTextBox(row, "tbCapEdit", "txtCap")
            Dim ddlCittaEdit As DropDownList = TryCast(row.FindControl("ddlCittaEdit"), DropDownList)
            Dim tbCittaEdit As TextBox = FindTextBox(row, "tbCittaEdit", "txtCitta")
            Dim tbProvinciaEdit As TextBox = FindTextBox(row, "tbProvinciaEdit", "txtProvincia")
            Dim lblCapMessage As Label = TryCast(row.FindControl("lblCapMessage"), Label)

            ' Città non modificabile manualmente
            If tbCittaEdit IsNot Nothing Then
                tbCittaEdit.ReadOnly = True
                tbCittaEdit.Enabled = False
            End If

            If tbProvinciaEdit IsNot Nothing Then
                tbProvinciaEdit.ReadOnly = True
            End If

            SetupCapCittaProvincia(tbCapEdit, ddlCittaEdit, tbCittaEdit, tbProvinciaEdit, lblCapMessage)

            ' --- Destinazione alternativa: combo + campi editabili ---
            Dim ddlDestAlt As DropDownList = FindDropDown(row, "ddlDestAlt", "ddlDestinazione")
            Dim tbRagioneSocialeAEdit As TextBox = FindTextBox(row, "tbRagioneSocialeAEdit", "tbDestRagioneSociale")
            Dim tbNomeAEdit As TextBox = FindTextBox(row, "tbNomeAEdit", "tbDestNome")
            Dim tbIndirizzoAEdit As TextBox = FindTextBox(row, "tbIndirizzoAEdit", "tbDestIndirizzo")
            Dim tbCapAEdit As TextBox = FindTextBox(row, "tbCapAEdit", "tbDestCap")
            Dim ddlCittaAEdit As DropDownList = TryCast(row.FindControl("ddlCittaAEdit"), DropDownList)
            Dim tbCittaAEdit As TextBox = FindTextBox(row, "tbCittaAEdit", "tbDestCitta")
            Dim tbProvinciaAEdit As TextBox = FindTextBox(row, "tbProvinciaAEdit", "tbDestProvincia")
            Dim tbNazioneAEdit As TextBox = FindTextBox(row, "tbNazioneAEdit", "tbDestNazione")
            Dim lblCapAMessage As Label = TryCast(row.FindControl("lblCapAMessage"), Label)

            ' Città destinazione alternativa non editabile a mano
            If tbCittaAEdit IsNot Nothing Then
                tbCittaAEdit.ReadOnly = True
                tbCittaAEdit.Enabled = False
                tbCittaAEdit.Visible = True
            End If
            If tbProvinciaAEdit IsNot Nothing Then
                tbProvinciaAEdit.ReadOnly = True
            End If
            ' Nazione altra destinazione non modificabile
            If tbNazioneAEdit IsNot Nothing Then
                tbNazioneAEdit.ReadOnly = True
            End If

            If utentiId > 0 AndAlso ddlDestAlt IsNot Nothing Then
                Dim selectedId As Integer = 0
                PopolaDropdownDestAlt(utentiId, ddlDestAlt, selectedId)

                If selectedId > 0 Then
                    Dim altRow As DataRow = GetDestinazioneById(selectedId, utentiId)
                    If altRow IsNot Nothing Then
                        If tbRagioneSocialeAEdit IsNot Nothing Then tbRagioneSocialeAEdit.Text = altRow("RagioneSocialeA").ToString()
                        If tbNomeAEdit IsNot Nothing Then tbNomeAEdit.Text = altRow("NomeA").ToString()
                        If tbIndirizzoAEdit IsNot Nothing Then tbIndirizzoAEdit.Text = altRow("IndirizzoA").ToString()
                        If tbCapAEdit IsNot Nothing Then tbCapAEdit.Text = altRow("CapA").ToString()
                        If tbCittaAEdit IsNot Nothing Then tbCittaAEdit.Text = altRow("CittaA").ToString()
                        If tbProvinciaAEdit IsNot Nothing Then tbProvinciaAEdit.Text = altRow("ProvinciaA").ToString()
                        If tbNazioneAEdit IsNot Nothing Then tbNazioneAEdit.Text = altRow("NazioneA").ToString()
                    End If
                Else
                    ' Nuova destinazione: campi vuoti
                    If tbRagioneSocialeAEdit IsNot Nothing Then tbRagioneSocialeAEdit.Text = ""
                    If tbNomeAEdit IsNot Nothing Then tbNomeAEdit.Text = ""
                    If tbIndirizzoAEdit IsNot Nothing Then tbIndirizzoAEdit.Text = ""
                    If tbCapAEdit IsNot Nothing Then tbCapAEdit.Text = ""
                    If tbCittaAEdit IsNot Nothing Then tbCittaAEdit.Text = ""
                    If tbProvinciaAEdit IsNot Nothing Then tbProvinciaAEdit.Text = ""
                    If tbNazioneAEdit IsNot Nothing AndAlso String.IsNullOrEmpty(tbNazioneAEdit.Text) Then
                        tbNazioneAEdit.Text = "IT"
                    End If
                End If
            End If

            ' Gestione CAP/CITTÀ/PROV per destinazione alternativa
            SetupCapCittaProvincia(tbCapAEdit, ddlCittaAEdit, tbCittaAEdit, tbProvinciaAEdit, lblCapAMessage, True)

        ElseIf fvUtente.CurrentMode = FormViewMode.ReadOnly Then
            Dim row As FormViewRow = fvUtente.Row
            Dim pnlDestAltRead As Panel = TryCast(row.FindControl("pnlDestAltRead"), Panel)
            Dim lblRag As Label = FindLabel(row, "lblDestAltRagioneSociale", "lblDestRagioneSociale")
            Dim lblNome As Label = FindLabel(row, "lblDestAltNome", "lblDestNome")
            Dim lblInd As Label = FindLabel(row, "lblDestAltIndirizzo", "lblDestIndirizzo")
            Dim lblCap As Label = FindLabel(row, "lblDestAltCap", "lblDestCap")
            Dim lblCitta As Label = FindLabel(row, "lblDestAltCitta", "lblDestCitta")
            Dim lblProv As Label = FindLabel(row, "lblDestAltProvincia", "lblDestProvincia")
            Dim lblNaz As Label = FindLabel(row, "lblDestAltNazione", "lblDestNazione")
            Dim lblCognome As Label = FindLabel(row, "lblDestCognome")
            Dim lblTelefono As Label = FindLabel(row, "lblDestTelefono")

            If utentiId > 0 Then
                Dim alt As DataRow = GetDestinazioneAlternativa(utentiId)
                If alt IsNot Nothing Then
                    If pnlDestAltRead IsNot Nothing Then pnlDestAltRead.Visible = True
                    If lblRag IsNot Nothing Then lblRag.Text = alt("RagioneSocialeA").ToString()
                    If lblNome IsNot Nothing Then lblNome.Text = alt("NomeA").ToString()
                    If lblInd IsNot Nothing Then lblInd.Text = alt("IndirizzoA").ToString()
                    If lblCap IsNot Nothing Then lblCap.Text = alt("CapA").ToString()
                    If lblCitta IsNot Nothing Then lblCitta.Text = alt("CittaA").ToString()
                    If lblProv IsNot Nothing Then lblProv.Text = alt("ProvinciaA").ToString()
                    If lblNaz IsNot Nothing Then lblNaz.Text = alt("NazioneA").ToString()
                    If lblCognome IsNot Nothing Then lblCognome.Text = ""
                    If lblTelefono IsNot Nothing Then lblTelefono.Text = ""
                Else
                    If pnlDestAltRead IsNot Nothing Then pnlDestAltRead.Visible = False
                    ShowEmptyDestinazioneMessage(row)
                End If
            Else
                If pnlDestAltRead IsNot Nothing Then pnlDestAltRead.Visible = False
                ShowEmptyDestinazioneMessage(row)
            End If
        End If
    End Sub

    ' Cambio destinazione alternativa da dropdown
    Protected Sub ddlDestAlt_SelectedIndexChanged(ByVal sender As Object, ByVal e As EventArgs)
        If fvUtente.Row Is Nothing Then Return

        Dim row As FormViewRow = fvUtente.Row
        Dim ddl As DropDownList = FindDropDown(row, "ddlDestAlt", "ddlDestinazione")
        If ddl Is Nothing Then Return

        Dim tbRagioneSocialeAEdit As TextBox = FindTextBox(row, "tbRagioneSocialeAEdit", "tbDestRagioneSociale")
        Dim tbNomeAEdit As TextBox = FindTextBox(row, "tbNomeAEdit", "tbDestNome")
        Dim tbIndirizzoAEdit As TextBox = FindTextBox(row, "tbIndirizzoAEdit", "tbDestIndirizzo")
        Dim tbCapAEdit As TextBox = FindTextBox(row, "tbCapAEdit", "tbDestCap")
        Dim ddlCittaAEdit As DropDownList = TryCast(row.FindControl("ddlCittaAEdit"), DropDownList)
        Dim tbCittaAEdit As TextBox = FindTextBox(row, "tbCittaAEdit", "tbDestCitta")
        Dim tbProvinciaAEdit As TextBox = FindTextBox(row, "tbProvinciaAEdit", "tbDestProvincia")
        Dim tbNazioneAEdit As TextBox = FindTextBox(row, "tbNazioneAEdit", "tbDestNazione")
        Dim lblCapAMessage As Label = TryCast(row.FindControl("lblCapAMessage"), Label)
        Dim tbNazioneEdit As TextBox = FindTextBox(row, "tbNazioneEdit", "txtNazione")

        Dim utentiId As Integer = 0
        If fvUtente.DataKey IsNot Nothing AndAlso fvUtente.DataKey("UtentiId") IsNot Nothing Then
            Integer.TryParse(fvUtente.DataKey("UtentiId").ToString(), utentiId)
        End If

        Dim destId As Integer = 0
        Integer.TryParse(ddl.SelectedValue, destId)

        If destId > 0 AndAlso utentiId > 0 Then
            Dim alt As DataRow = GetDestinazioneById(destId, utentiId)
            If alt IsNot Nothing Then
                If tbRagioneSocialeAEdit IsNot Nothing Then tbRagioneSocialeAEdit.Text = alt("RagioneSocialeA").ToString()
                If tbNomeAEdit IsNot Nothing Then tbNomeAEdit.Text = alt("NomeA").ToString()
                If tbIndirizzoAEdit IsNot Nothing Then tbIndirizzoAEdit.Text = alt("IndirizzoA").ToString()
                If tbCapAEdit IsNot Nothing Then tbCapAEdit.Text = alt("CapA").ToString()
                If tbCittaAEdit IsNot Nothing Then tbCittaAEdit.Text = alt("CittaA").ToString()
                If tbProvinciaAEdit IsNot Nothing Then tbProvinciaAEdit.Text = alt("ProvinciaA").ToString()
                If tbNazioneAEdit IsNot Nothing Then tbNazioneAEdit.Text = alt("NazioneA").ToString()
            End If
        Else
            ' Nuova destinazione: reset campi
            If tbRagioneSocialeAEdit IsNot Nothing Then tbRagioneSocialeAEdit.Text = ""
            If tbNomeAEdit IsNot Nothing Then tbNomeAEdit.Text = ""
            If tbIndirizzoAEdit IsNot Nothing Then tbIndirizzoAEdit.Text = ""
            If tbCapAEdit IsNot Nothing Then tbCapAEdit.Text = ""
            If tbCittaAEdit IsNot Nothing Then tbCittaAEdit.Text = ""
            If tbProvinciaAEdit IsNot Nothing Then tbProvinciaAEdit.Text = ""
            If tbNazioneAEdit IsNot Nothing Then
                If tbNazioneEdit IsNot Nothing AndAlso Not String.IsNullOrEmpty(tbNazioneEdit.Text) Then
                    tbNazioneAEdit.Text = tbNazioneEdit.Text
                Else
                    tbNazioneAEdit.Text = "IT"
                End If
            End If
        End If

        ' ricalcolo combo città/prov per la destinazione alternativa
        SetupCapCittaProvincia(tbCapAEdit, ddlCittaAEdit, tbCittaAEdit, tbProvinciaAEdit, lblCapAMessage, True)
    End Sub

    ' Salvataggio dati
    Protected Sub fvUtente_ItemUpdating(ByVal sender As Object, ByVal e As FormViewUpdateEventArgs)
        lblEsito.Text = ""

        If fvUtente.Row Is Nothing OrElse fvUtente.DataKey Is Nothing Then
            e.Cancel = True
            Return
        End If

        Dim utentiId As Integer = 0
        If fvUtente.DataKey("UtentiId") IsNot Nothing Then
            Integer.TryParse(fvUtente.DataKey("UtentiId").ToString(), utentiId)
        End If

        If utentiId <= 0 Then
            lblEsito.Text = "Impossibile aggiornare i dati: utente non valido."
            e.Cancel = True
            Return
        End If

        Dim row As FormViewRow = fvUtente.Row

        ' Controlli anagrafica principale
        Dim tbEmailEdit As TextBox = FindTextBox(row, "tbEmailEdit", "txtEmail")
        Dim tbIndirizzoEdit As TextBox = FindTextBox(row, "tbIndirizzoEdit", "txtIndirizzo")
        Dim tbCapEdit As TextBox = FindTextBox(row, "tbCapEdit", "txtCap")
        Dim tbCittaEdit As TextBox = FindTextBox(row, "tbCittaEdit", "txtCitta")
        Dim tbProvinciaEdit As TextBox = FindTextBox(row, "tbProvinciaEdit", "txtProvincia")
        Dim tbNazioneEdit As TextBox = FindTextBox(row, "tbNazioneEdit", "txtNazione")
        Dim tbTelefonoEdit As TextBox = FindTextBox(row, "tbTelefonoEdit", "txtTelefono")
        Dim tbCellulareEdit As TextBox = FindTextBox(row, "tbCellulareEdit", "txtCellulare")
        Dim tbFaxEdit As TextBox = FindTextBox(row, "tbFaxEdit", "txtFax")

        ' Controlli destinazione alternativa
        Dim ddlDestAlt As DropDownList = FindDropDown(row, "ddlDestAlt", "ddlDestinazione")
        Dim tbRagioneSocialeAEdit As TextBox = FindTextBox(row, "tbRagioneSocialeAEdit", "tbDestRagioneSociale")
        Dim tbNomeAEdit As TextBox = FindTextBox(row, "tbNomeAEdit", "tbDestNome")
        Dim tbIndirizzoAEdit As TextBox = FindTextBox(row, "tbIndirizzoAEdit", "tbDestIndirizzo")
        Dim tbCapAEdit As TextBox = FindTextBox(row, "tbCapAEdit", "tbDestCap")
        Dim tbCittaAEdit As TextBox = FindTextBox(row, "tbCittaAEdit", "tbDestCitta")
        Dim tbProvinciaAEdit As TextBox = FindTextBox(row, "tbProvinciaAEdit", "tbDestProvincia")
        Dim tbNazioneAEdit As TextBox = FindTextBox(row, "tbNazioneAEdit", "tbDestNazione")

        Dim destAltId As Integer = 0
        If ddlDestAlt IsNot Nothing Then
            Integer.TryParse(ddlDestAlt.SelectedValue, destAltId)
        End If

        Try
            Using conn As New MySqlConnection(ConnString)
                conn.Open()
                Using tr As MySqlTransaction = conn.BeginTransaction()

                    ' 1) Aggiorno anagrafica principale (tabella utenti)
                    Dim sqlUtente As String = _
                        "UPDATE utenti SET " & _
                        "Indirizzo = @Indirizzo, " & _
                        "Cap = @Cap, " & _
                        "Citta = @Citta, " & _
                        "Provincia = @Provincia, " & _
                        "Nazione = @Nazione, " & _
                        "Telefono = @Telefono, " & _
                        "Cellulare = @Cellulare, " & _
                        "Fax = @Fax, " & _
                        "Email = @Email " & _
                        "WHERE id = @UtentiId"

                    Using cmd As New MySqlCommand(sqlUtente, conn, tr)
                        cmd.Parameters.AddWithValue("@Indirizzo", If(tbIndirizzoEdit Is Nothing, "", tbIndirizzoEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@Cap", If(tbCapEdit Is Nothing, "", tbCapEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@Citta", If(tbCittaEdit Is Nothing, "", tbCittaEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@Provincia", If(tbProvinciaEdit Is Nothing, "", tbProvinciaEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@Nazione", If(tbNazioneEdit Is Nothing, "", tbNazioneEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@Telefono", If(tbTelefonoEdit Is Nothing, "", tbTelefonoEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@Cellulare", If(tbCellulareEdit Is Nothing, "", tbCellulareEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@Fax", If(tbFaxEdit Is Nothing, "", tbFaxEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@Email", If(tbEmailEdit Is Nothing, "", tbEmailEdit.Text.Trim()))
                        cmd.Parameters.AddWithValue("@UtentiId", utentiId)

                        cmd.ExecuteNonQuery()
                    End Using

                    ' 2) Aggiorno anche la Email nella tabella login (se esiste)
                    If tbEmailEdit IsNot Nothing Then
                        Dim sqlLogin As String = _
                            "UPDATE login " & _
                            "SET Email = @Email " & _
                            "WHERE UtentiId = @UtentiId"

                        Using cmdLogin As New MySqlCommand(sqlLogin, conn, tr)
                            cmdLogin.Parameters.AddWithValue("@Email", tbEmailEdit.Text.Trim())
                            cmdLogin.Parameters.AddWithValue("@UtentiId", utentiId)
                            cmdLogin.ExecuteNonQuery()
                        End Using
                    End If

                    ' 3) Aggiorno / creo Destinazione Alternativa selezionata
                    AggiornaDestinazioneAlternativa(conn, tr, utentiId,
                                                   tbRagioneSocialeAEdit,
                                                   tbNomeAEdit,
                                                   tbIndirizzoAEdit,
                                                   tbCapAEdit,
                                                   tbCittaAEdit,
                                                   tbProvinciaAEdit,
                                                   tbNazioneAEdit,
                                                   tbNazioneEdit,
                                                   destAltId)

                    tr.Commit()
                End Using
            End Using

            lblEsito.Text = "Dati aggiornati correttamente."
            fvUtente.ChangeMode(FormViewMode.ReadOnly)
            BindUtenteFormView()
            e.Cancel = True

        Catch
            lblEsito.Text = "Non e stato possibile salvare i dati. Riprova piu tardi."
            e.Cancel = True
        End Try
    End Sub

    Private Function FindTextBox(ByVal row As FormViewRow, ParamArray ids() As String) As TextBox
        If row Is Nothing OrElse ids Is Nothing Then Return Nothing

        For Each id As String In ids
            Dim tb As TextBox = TryCast(row.FindControl(id), TextBox)
            If tb IsNot Nothing Then Return tb
        Next

        Return Nothing
    End Function

    Private Function FindDropDown(ByVal row As FormViewRow, ParamArray ids() As String) As DropDownList
        If row Is Nothing OrElse ids Is Nothing Then Return Nothing

        For Each id As String In ids
            Dim ddl As DropDownList = TryCast(row.FindControl(id), DropDownList)
            If ddl IsNot Nothing Then Return ddl
        Next

        Return Nothing
    End Function

    Private Function FindLabel(ByVal row As FormViewRow, ParamArray ids() As String) As Label
        If row Is Nothing OrElse ids Is Nothing Then Return Nothing

        For Each id As String In ids
            Dim lbl As Label = TryCast(row.FindControl(id), Label)
            If lbl IsNot Nothing Then Return lbl
        Next

        Return Nothing
    End Function

    Private Sub ShowEmptyDestinazioneMessage(ByVal row As FormViewRow)
        If row Is Nothing Then Return

        Dim lblRag As Label = FindLabel(row, "lblDestAltRagioneSociale", "lblDestRagioneSociale")
        Dim lblNome As Label = FindLabel(row, "lblDestAltNome", "lblDestNome")
        Dim lblCognome As Label = FindLabel(row, "lblDestCognome")
        Dim lblInd As Label = FindLabel(row, "lblDestAltIndirizzo", "lblDestIndirizzo")
        Dim lblCap As Label = FindLabel(row, "lblDestAltCap", "lblDestCap")
        Dim lblCitta As Label = FindLabel(row, "lblDestAltCitta", "lblDestCitta")
        Dim lblProv As Label = FindLabel(row, "lblDestAltProvincia", "lblDestProvincia")
        Dim lblNaz As Label = FindLabel(row, "lblDestAltNazione", "lblDestNazione")
        Dim lblTelefono As Label = FindLabel(row, "lblDestTelefono")

        If lblRag IsNot Nothing Then lblRag.Text = "Non hai ancora destinazioni salvate."
        If lblNome IsNot Nothing Then lblNome.Text = ""
        If lblCognome IsNot Nothing Then lblCognome.Text = ""
        If lblInd IsNot Nothing Then lblInd.Text = ""
        If lblCap IsNot Nothing Then lblCap.Text = ""
        If lblCitta IsNot Nothing Then lblCitta.Text = ""
        If lblProv IsNot Nothing Then lblProv.Text = ""
        If lblNaz IsNot Nothing Then lblNaz.Text = ""
        If lblTelefono IsNot Nothing Then lblTelefono.Text = ""
    End Sub

    ' =========================
    '   DESTINAZIONE ALTERNATIVA
    ' =========================

    Private Function GetDestinazioneAlternativa(ByVal utentiId As Integer) As DataRow
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            Dim sql As String = _
                "SELECT " & _
                "RagioneSocialeA, " & _
                "NomeA, " & _
                "IndirizzoA, " & _
                "CapA, " & _
                "CittaA, " & _
                "ProvinciaA, " & _
                "NazioneA " & _
                "FROM utentiindirizzi " & _
                "WHERE UtenteId = @UtenteId " & _
                "AND Predefinito = 1 " & _
                "LIMIT 1"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@UtenteId", utentiId)

                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        If dt.Rows.Count > 0 Then
            Return dt.Rows(0)
        End If

        Return Nothing
    End Function

    Private Function GetDestinazioneById(ByVal destId As Integer, ByVal utentiId As Integer) As DataRow
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            Dim sql As String = _
                "SELECT " & _
                "id, " & _
                "RagioneSocialeA, " & _
                "NomeA, " & _
                "IndirizzoA, " & _
                "CapA, " & _
                "CittaA, " & _
                "ProvinciaA, " & _
                "NazioneA, " & _
                "Predefinito " & _
                "FROM utentiindirizzi " & _
                "WHERE id = @Id " & _
                "AND UtenteId = @UtenteId " & _
                "LIMIT 1"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@Id", destId)
                cmd.Parameters.AddWithValue("@UtenteId", utentiId)

                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        If dt.Rows.Count > 0 Then
            Return dt.Rows(0)
        End If

        Return Nothing
    End Function

    Private Function GetDestinazioniList(ByVal utentiId As Integer) As DataTable
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            Dim sql As String = _
                "SELECT " & _
                "id, " & _
                "RagioneSocialeA, " & _
                "NomeA, " & _
                "IndirizzoA, " & _
                "CapA, " & _
                "CittaA, " & _
                "ProvinciaA, " & _
                "NazioneA, " & _
                "Predefinito " & _
                "FROM utentiindirizzi " & _
                "WHERE UtenteId = @UtenteId " & _
                "ORDER BY Predefinito DESC, id ASC"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@UtenteId", utentiId)

                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        Return dt
    End Function

    Private Sub PopolaDropdownDestAlt(ByVal utentiId As Integer,
                                      ByVal ddl As DropDownList,
                                      ByRef selectedId As Integer)

        selectedId = 0
        ddl.Items.Clear()

        Dim dt As DataTable = GetDestinazioniList(utentiId)

        If dt.Rows.Count > 0 Then
            Dim predefId As Integer = 0

            For Each r As DataRow In dt.Rows
                Dim id As Integer = Convert.ToInt32(r("id"))
                Dim rag As String = r("RagioneSocialeA").ToString()
                Dim nome As String = r("NomeA").ToString()
                Dim citta As String = r("CittaA").ToString()
                Dim cap As String = r("CapA").ToString()
                Dim predef As Boolean = False

                If Not IsDBNull(r("Predefinito")) Then
                    predef = (Convert.ToInt32(r("Predefinito")) = 1)
                End If

                Dim label As String = ""
                If rag <> "" Then
                    label = rag
                ElseIf nome <> "" Then
                    label = nome
                ElseIf citta <> "" Then
                    label = citta
                Else
                    label = "Destinazione " & id.ToString()
                End If

                If cap <> "" Then
                    label &= " - " & cap
                End If
                If citta <> "" Then
                    label &= " " & citta
                End If

                If predef Then
                    label &= " (predefinita)"
                    predefId = id
                End If

                ddl.Items.Add(New ListItem(label, id.ToString()))
            Next

            If predefId > 0 Then
                selectedId = predefId
            Else
                selectedId = Convert.ToInt32(dt.Rows(0)("id"))
            End If

            Dim item As ListItem = ddl.Items.FindByValue(selectedId.ToString())
            If item IsNot Nothing Then
                ddl.ClearSelection()
                item.Selected = True
            End If
        End If

        ' Aggiungo sempre l'opzione "Nuova destinazione"
        ddl.Items.Add(New ListItem("-- Nuova destinazione --", "0"))

        ' Se non ho trovato nulla, seleziono "Nuova"
        If selectedId = 0 Then
            ddl.SelectedValue = "0"
        End If
    End Sub

    Private Sub AggiornaDestinazioneAlternativa(ByVal conn As MySqlConnection,
                                                ByVal tr As MySqlTransaction,
                                                ByVal utentiId As Integer,
                                                ByVal tbRag As TextBox,
                                                ByVal tbNome As TextBox,
                                                ByVal tbInd As TextBox,
                                                ByVal tbCap As TextBox,
                                                ByVal tbCitta As TextBox,
                                                ByVal tbProv As TextBox,
                                                ByVal tbNazA As TextBox,
                                                ByVal tbNazPrincipale As TextBox,
                                                ByVal destAltId As Integer)

        Dim rag As String = If(tbRag Is Nothing, "", tbRag.Text.Trim())
        Dim nome As String = If(tbNome Is Nothing, "", tbNome.Text.Trim())
        Dim ind As String = If(tbInd Is Nothing, "", tbInd.Text.Trim())
        Dim cap As String = If(tbCap Is Nothing, "", tbCap.Text.Trim())
        Dim citta As String = If(tbCitta Is Nothing, "", tbCitta.Text.Trim())
        Dim prov As String = If(tbProv Is Nothing, "", tbProv.Text.Trim())
        Dim naz As String = If(tbNazA Is Nothing, "", tbNazA.Text.Trim())

        If String.IsNullOrEmpty(naz) AndAlso tbNazPrincipale IsNot Nothing Then
            naz = tbNazPrincipale.Text.Trim()
        End If
        If String.IsNullOrEmpty(naz) Then
            naz = "IT"
        End If

        ' Se l'utente non ha compilato praticamente nulla, non creo / non modifico
        Dim hasData As Boolean = Not (String.IsNullOrEmpty(rag) AndAlso
                                      String.IsNullOrEmpty(nome) AndAlso
                                      String.IsNullOrEmpty(ind) AndAlso
                                      String.IsNullOrEmpty(cap) AndAlso
                                      String.IsNullOrEmpty(citta) AndAlso
                                      String.IsNullOrEmpty(prov))

        If Not hasData Then
            Return
        End If

        If destAltId > 0 Then
            ' UPDATE destinazione esistente
            Dim sqlUpd As String = _
                "UPDATE utentiindirizzi SET " & _
                "RagioneSocialeA = @RagioneSocialeA, " & _
                "NomeA = @NomeA, " & _
                "IndirizzoA = @IndirizzoA, " & _
                "CapA = @CapA, " & _
                "CittaA = @CittaA, " & _
                "ProvinciaA = @ProvinciaA, " & _
                "NazioneA = @NazioneA " & _
                "WHERE id = @Id AND UtenteId = @UtenteId"

            Using cmdUpd As New MySqlCommand(sqlUpd, conn, tr)
                cmdUpd.Parameters.AddWithValue("@RagioneSocialeA", rag)
                cmdUpd.Parameters.AddWithValue("@NomeA", nome)
                cmdUpd.Parameters.AddWithValue("@IndirizzoA", ind)
                cmdUpd.Parameters.AddWithValue("@CapA", cap)
                cmdUpd.Parameters.AddWithValue("@CittaA", citta)
                cmdUpd.Parameters.AddWithValue("@ProvinciaA", prov)
                cmdUpd.Parameters.AddWithValue("@NazioneA", naz)
                cmdUpd.Parameters.AddWithValue("@Id", destAltId)
                cmdUpd.Parameters.AddWithValue("@UtenteId", utentiId)

                cmdUpd.ExecuteNonQuery()
            End Using
        Else
            ' INSERT nuova destinazione
            Dim predefinito As Integer = 0

            ' Se l'utente non ha ancora destinazioni, questa può essere la predefinita
            Dim sqlCount As String = _
                "SELECT COUNT(*) FROM utentiindirizzi WHERE UtenteId = @UtenteId"

            Using cmdCount As New MySqlCommand(sqlCount, conn, tr)
                cmdCount.Parameters.AddWithValue("@UtenteId", utentiId)
                Dim cntObj As Object = cmdCount.ExecuteScalar()
                Dim cnt As Integer = 0
                If cntObj IsNot Nothing AndAlso cntObj IsNot DBNull.Value Then
                    Integer.TryParse(cntObj.ToString(), cnt)
                End If
                If cnt = 0 Then
                    predefinito = 1
                End If
            End Using

            Dim sqlIns As String = _
                "INSERT INTO utentiindirizzi " & _
                "(UtenteId, RagioneSocialeA, NomeA, IndirizzoA, CapA, CittaA, ProvinciaA, NazioneA, Predefinito) " & _
                "VALUES " & _
                "(@UtenteId, @RagioneSocialeA, @NomeA, @IndirizzoA, @CapA, @CittaA, @ProvinciaA, @NazioneA, @Predefinito)"

            Using cmdIns As New MySqlCommand(sqlIns, conn, tr)
                cmdIns.Parameters.AddWithValue("@UtenteId", utentiId)
                cmdIns.Parameters.AddWithValue("@RagioneSocialeA", rag)
                cmdIns.Parameters.AddWithValue("@NomeA", nome)
                cmdIns.Parameters.AddWithValue("@IndirizzoA", ind)
                cmdIns.Parameters.AddWithValue("@CapA", cap)
                cmdIns.Parameters.AddWithValue("@CittaA", citta)
                cmdIns.Parameters.AddWithValue("@ProvinciaA", prov)
                cmdIns.Parameters.AddWithValue("@NazioneA", naz)
                cmdIns.Parameters.AddWithValue("@Predefinito", predefinito)

                cmdIns.ExecuteNonQuery()
            End Using
        End If
    End Sub

    ' =========================
    '   LOGICA CAP → CITTA / PROV
    ' =========================

    Private Function GetComuniByCap(ByVal cap As String) As DataTable
        Dim dt As New DataTable()

        If String.IsNullOrWhiteSpace(cap) Then
            Return dt
        End If

        Using conn As New MySqlConnection(ConnString)
            Dim sql As String = _
                "SELECT Comune, Provincia " & _
                "FROM comuni " & _
                "WHERE CAP = @CAP " & _
                "ORDER BY Comune"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@CAP", cap.Trim())

                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        Return dt
    End Function

    Private Sub SetupCapCittaProvincia(ByVal tbCap As TextBox,
                                       ByVal ddlCitta As DropDownList,
                                       ByVal tbCitta As TextBox,
                                       ByVal tbProv As TextBox,
                                       ByVal lblMsg As Label,
                                       Optional ByVal isAlt As Boolean = False)

        ' Qui forziamo il compilatore a trattare tbCitta come Object,
        ' così l'operatore Is non può lamentarsi di tipi value (Integer)
        Dim tbCittaObj As Object = tbCitta

        If tbCittaObj IsNot Nothing Then
            tbCitta.ReadOnly = True
            tbCitta.Enabled = False
            tbCitta.Visible = True      ' visibile di default
        End If

        If tbProv IsNot Nothing Then
            tbProv.ReadOnly = True
        End If

        If ddlCitta Is Nothing OrElse tbCap Is Nothing Then
            Return
        End If

        If lblMsg IsNot Nothing Then
            lblMsg.Text = ""
        End If

        ddlCitta.Items.Clear()
        ddlCitta.Visible = False

        Dim cap As String = tbCap.Text.Trim()

        If cap.Length <> 5 Then
            ' CAP non completo, non faccio nulla
            Return
        End If

        Dim dt As DataTable = GetComuniByCap(cap)

        If dt.Rows.Count = 0 Then
            ddlCitta.Visible = False
            If tbCitta IsNot Nothing Then
                tbCitta.Visible = True
                tbCitta.Text = ""
            End If
            If tbProv IsNot Nothing Then
                tbProv.Text = ""
            End If
            If lblMsg IsNot Nothing Then
                lblMsg.Text = "CAP non trovato. Controlla il valore inserito."
            End If

        ElseIf dt.Rows.Count = 1 Then
            ddlCitta.Visible = False
            If tbCitta IsNot Nothing Then
                tbCitta.Visible = True
                tbCitta.Text = dt.Rows(0)("Comune").ToString()
            End If
            If tbProv IsNot Nothing Then
                tbProv.Text = dt.Rows(0)("Provincia").ToString()
            End If

        Else
            ddlCitta.DataSource = dt
            ddlCitta.DataTextField = "Comune"
            ddlCitta.DataValueField = "Provincia"
            ddlCitta.DataBind()
            ddlCitta.Visible = True

            ' quando ho più città: mostro solo la DropDownList
            If tbCitta IsNot Nothing Then
                tbCitta.Visible = False
                If ddlCitta.Items.Count > 0 Then
                    tbCitta.Text = ddlCitta.Items(0).Text
                End If
            End If
            If tbProv IsNot Nothing AndAlso ddlCitta.Items.Count > 0 Then
                tbProv.Text = ddlCitta.Items(0).Value
            End If
        End If
    End Sub

    Private Sub AggiornaDaDropDownCitta(ByVal ddl As DropDownList,
                                        ByVal tbCitta As TextBox,
                                        ByVal tbProv As TextBox)
        If ddl Is Nothing OrElse tbCitta Is Nothing OrElse tbProv Is Nothing Then
            Return
        End If

        tbCitta.Text = ddl.SelectedItem.Text
        tbProv.Text = ddl.SelectedValue
    End Sub

    ' EVENTI CAP/CITTÀ - ANAGRAFICA PRINCIPALE
    Protected Sub tbCapEdit_TextChanged(ByVal sender As Object, ByVal e As EventArgs)
        If fvUtente.Row Is Nothing Then Return

        Dim row As FormViewRow = fvUtente.Row
        Dim tbCap As TextBox = TryCast(row.FindControl("tbCapEdit"), TextBox)
        Dim ddlCitta As DropDownList = TryCast(row.FindControl("ddlCittaEdit"), DropDownList)
        Dim tbCitta As TextBox = TryCast(row.FindControl("tbCittaEdit"), TextBox)
        Dim tbProv As TextBox = TryCast(row.FindControl("tbProvinciaEdit"), TextBox)
        Dim lblMsg As Label = TryCast(row.FindControl("lblCapMessage"), Label)

        SetupCapCittaProvincia(tbCap, ddlCitta, tbCitta, tbProv, lblMsg)
    End Sub

    Protected Sub ddlCittaEdit_SelectedIndexChanged(ByVal sender As Object, ByVal e As EventArgs)
        If fvUtente.Row Is Nothing Then Return

        Dim row As FormViewRow = fvUtente.Row
        Dim ddl As DropDownList = TryCast(row.FindControl("ddlCittaEdit"), DropDownList)
        Dim tbCitta As TextBox = TryCast(row.FindControl("tbCittaEdit"), TextBox)
        Dim tbProv As TextBox = TryCast(row.FindControl("tbProvinciaEdit"), TextBox)

        AggiornaDaDropDownCitta(ddl, tbCitta, tbProv)
    End Sub

    ' EVENTI CAP/CITTÀ - DESTINAZIONE ALTERNATIVA
    Protected Sub tbCapAEdit_TextChanged(ByVal sender As Object, ByVal e As EventArgs)
        If fvUtente.Row Is Nothing Then Return

        Dim row As FormViewRow = fvUtente.Row
        Dim tbCap As TextBox = TryCast(row.FindControl("tbCapAEdit"), TextBox)
        Dim ddlCitta As DropDownList = TryCast(row.FindControl("ddlCittaAEdit"), DropDownList)
        Dim tbCitta As TextBox = TryCast(row.FindControl("tbCittaAEdit"), TextBox)
        Dim tbProv As TextBox = TryCast(row.FindControl("tbProvinciaAEdit"), TextBox)
        Dim lblMsg As Label = TryCast(row.FindControl("lblCapAMessage"), Label)

        SetupCapCittaProvincia(tbCap, ddlCitta, tbCitta, tbProv, lblMsg, True)
    End Sub

    Protected Sub ddlCittaAEdit_SelectedIndexChanged(ByVal sender As Object, ByVal e As EventArgs)
        If fvUtente.Row Is Nothing Then Return

        Dim row As FormViewRow = fvUtente.Row
        Dim ddl As DropDownList = TryCast(row.FindControl("ddlCittaAEdit"), DropDownList)
        Dim tbCitta As TextBox = TryCast(row.FindControl("tbCittaAEdit"), TextBox)
        Dim tbProv As TextBox = TryCast(row.FindControl("tbProvinciaAEdit"), TextBox)

        AggiornaDaDropDownCitta(ddl, tbCitta, tbProv)
    End Sub

End Class
