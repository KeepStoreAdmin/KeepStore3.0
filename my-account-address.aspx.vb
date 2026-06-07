Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Web.UI.WebControls
Imports MySql.Data.MySqlClient

Partial Class my_account_address
    Inherits System.Web.UI.Page

    Private ReadOnly Property ConnString As String
        Get
            Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("LoginId") Is Nothing Then
            Session("Pagina_visitata") = Request.Url
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        If Not IsPostBack Then
            HideAddressForm()
            BindAddressPage()
        End If
    End Sub

    Private Sub BindAddressPage()
        ClearMessage()

        Dim loginId As Integer = CurrentLoginId()
        Dim utentiId As Integer = ResolveUtentiId(loginId)

        If loginId <= 0 OrElse utentiId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        BindMainAddress(utentiId)
        BindAlternativeAddresses(utentiId)
    End Sub

    Private Function CurrentLoginId() As Integer
        Dim value As Integer = 0
        Integer.TryParse(Convert.ToString(Session("LoginId")), value)
        If value <= 0 Then Integer.TryParse(Convert.ToString(Session("LoginID")), value)
        Return value
    End Function

    Private Function ResolveUtentiId(ByVal loginId As Integer) As Integer
        Dim utentiId As Integer = 0

        Integer.TryParse(Convert.ToString(Session("UtentiId")), utentiId)
        If utentiId <= 0 Then Integer.TryParse(Convert.ToString(Session("UTENTIID")), utentiId)
        If utentiId <= 0 Then Integer.TryParse(Convert.ToString(Session("UtentiID")), utentiId)
        If utentiId > 0 Then Return utentiId

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Using cmd As New MySqlCommand("SELECT u.Id FROM vlogin v INNER JOIN utenti u ON v.utentiid = u.Id WHERE v.Id = @LoginId LIMIT 1", conn)
                cmd.Parameters.AddWithValue("@LoginId", loginId)
                Dim raw As Object = cmd.ExecuteScalar()
                If raw IsNot Nothing AndAlso raw IsNot DBNull.Value Then
                    Integer.TryParse(Convert.ToString(raw), utentiId)
                End If
            End Using
        End Using

        If utentiId > 0 Then
            Session("UtentiId") = utentiId
            Session("UTENTIID") = utentiId
            Session("UtentiID") = utentiId
        End If

        Return utentiId
    End Function

    Private Sub BindMainAddress(ByVal utentiId As Integer)
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Dim sql As String =
                "SELECT " &
                "COALESCE(RagioneSociale,'') AS RagioneSociale, " &
                "COALESCE(CognomeNome,'') AS CognomeNome, " &
                "COALESCE(Email,'') AS Email, " &
                "COALESCE(Indirizzo,'') AS Indirizzo, " &
                "COALESCE(Cap,'') AS Cap, " &
                "COALESCE(Citta,'') AS Citta, " &
                "COALESCE(Provincia,'') AS Provincia, " &
                "COALESCE(Nazione,'') AS Nazione, " &
                "COALESCE(Telefono,'') AS Telefono, " &
                "COALESCE(Cellulare,'') AS Cellulare " &
                "FROM utenti WHERE Id = @UtentiId LIMIT 1"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        If dt.Rows.Count = 0 Then
            pnlMainAddress.Visible = False
            pnlNoMainAddress.Visible = True
            Return
        End If

        Dim row As DataRow = dt.Rows(0)
        pnlMainAddress.Visible = True
        pnlNoMainAddress.Visible = False

        litMainRagioneSociale.Text = Server.HtmlEncode(SafeRowValue(row, "RagioneSociale", "Non indicata"))
        litMainCognomeNome.Text = Server.HtmlEncode(SafeRowValue(row, "CognomeNome", "Non indicato"))
        litMainEmail.Text = Server.HtmlEncode(SafeRowValue(row, "Email", "Non indicata"))
        litMainAddress.Text = Server.HtmlEncode(SafeRowValue(row, "Indirizzo", "Non indicato"))
        litMainCap.Text = Server.HtmlEncode(SafeRowValue(row, "Cap", "-"))
        litMainCity.Text = Server.HtmlEncode(SafeRowValue(row, "Citta", "-"))
        litMainProvince.Text = Server.HtmlEncode(SafeRowValue(row, "Provincia", "-"))
        litMainCountry.Text = Server.HtmlEncode(SafeRowValue(row, "Nazione", "-"))
        litMainPhone.Text = Server.HtmlEncode(SafeRowValue(row, "Telefono", "-"))
        litMainMobile.Text = Server.HtmlEncode(SafeRowValue(row, "Cellulare", "-"))
    End Sub

    Private Sub BindAlternativeAddresses(ByVal utentiId As Integer)
        Dim dt As DataTable = LoadAlternativeAddresses(utentiId)
        Dim hasDefaultAlternative As Boolean = False

        For Each row As DataRow In dt.Rows
            If IsDefaultValue(row("Predefinito")) Then
                hasDefaultAlternative = True
                Exit For
            End If
        Next

        lblMainDefaultBadge.Visible = Not hasDefaultAlternative
        pnlNoAlternativeAddresses.Visible = (dt.Rows.Count = 0)
        rptAlternativeAddresses.Visible = (dt.Rows.Count > 0)
        rptAlternativeAddresses.DataSource = dt
        rptAlternativeAddresses.DataBind()
    End Sub

    Private Function LoadAlternativeAddresses(ByVal utentiId As Integer) As DataTable
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Dim sql As String =
                "SELECT " &
                "Id, " &
                "COALESCE(RagioneSocialeA,'') AS RagioneSocialeA, " &
                "COALESCE(NomeA,'') AS NomeA, " &
                "COALESCE(IndirizzoA,'') AS IndirizzoA, " &
                "COALESCE(CapA,'') AS CapA, " &
                "COALESCE(CittaA,'') AS CittaA, " &
                "COALESCE(ProvinciaA,'') AS ProvinciaA, " &
                "COALESCE(Zona,'') AS Zona, " &
                "COALESCE(TelefonoA,'') AS TelefonoA, " &
                "COALESCE(CellulareA,'') AS CellulareA, " &
                "COALESCE(FaxA,'') AS FaxA, " &
                "COALESCE(Note,'') AS Note, " &
                "COALESCE(Predefinito,0) AS Predefinito, " &
                "COALESCE(NazioneA,'') AS NazioneA " &
                "FROM utentiindirizzi " &
                "WHERE UtenteId = @UtentiId " &
                "ORDER BY COALESCE(Predefinito,0) DESC, Id ASC"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        Return dt
    End Function

    Protected Sub rptAlternativeAddresses_ItemCommand(ByVal source As Object, ByVal e As RepeaterCommandEventArgs)
        Dim addressId As Integer = 0
        Integer.TryParse(Convert.ToString(e.CommandArgument), addressId)

        Dim loginId As Integer = CurrentLoginId()
        Dim utentiId As Integer = ResolveUtentiId(loginId)

        If String.Equals(e.CommandName, "EditAddress", StringComparison.OrdinalIgnoreCase) Then
            If addressId <= 0 OrElse utentiId <= 0 Then
                ShowMessage("Non e stato possibile aprire la sede richiesta.", False)
                Return
            End If

            ShowEditAddressForm(utentiId, addressId)
            Return
        End If

        If Not String.Equals(e.CommandName, "SetDefault", StringComparison.OrdinalIgnoreCase) Then Return

        If addressId <= 0 OrElse utentiId <= 0 Then
            ShowMessage("Non e stato possibile aggiornare la sede predefinita.", False)
            BindAlternativeAddresses(utentiId)
            Return
        End If

        If SetDefaultAlternativeAddress(utentiId, addressId) Then
            ShowMessage("Sede predefinita aggiornata correttamente.", True)
        Else
            ShowMessage("Non e stato possibile aggiornare la sede predefinita.", False)
        End If

        BindAlternativeAddresses(utentiId)
    End Sub

    Protected Sub btnShowAddAddress_Click(ByVal sender As Object, ByVal e As EventArgs)
        ClearMessage()
        ShowAddAddressForm()
    End Sub

    Protected Sub btnCancelAddress_Click(ByVal sender As Object, ByVal e As EventArgs)
        ClearMessage()
        HideAddressForm()

        Dim loginId As Integer = CurrentLoginId()
        Dim utentiId As Integer = ResolveUtentiId(loginId)
        If utentiId > 0 Then BindAlternativeAddresses(utentiId)
    End Sub

    Protected Sub btnSaveAddress_Click(ByVal sender As Object, ByVal e As EventArgs)
        Dim loginId As Integer = CurrentLoginId()
        Dim utentiId As Integer = ResolveUtentiId(loginId)

        If loginId <= 0 OrElse utentiId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        Dim addressId As Integer = CurrentAddressFormId()
        Dim errors As List(Of String) = ValidateAddressForm()

        If errors.Count > 0 Then
            ShowValidationMessage(errors)
            pnlAddressForm.Visible = True
            litAddressFormTitle.Text = If(addressId > 0, "Modifica indirizzo", "Aggiungi indirizzo")
            Return
        End If

        If SaveAlternativeAddress(utentiId, addressId) Then
            HideAddressForm()
            BindAlternativeAddresses(utentiId)
            ShowMessage(If(addressId > 0, "Indirizzo aggiornato correttamente.", "Indirizzo aggiunto correttamente."), True)
        Else
            pnlAddressForm.Visible = True
            litAddressFormTitle.Text = If(addressId > 0, "Modifica indirizzo", "Aggiungi indirizzo")
            ShowMessage("Non e stato possibile salvare l'indirizzo.", False)
        End If
    End Sub

    Private Function SetDefaultAlternativeAddress(ByVal utentiId As Integer, ByVal addressId As Integer) As Boolean
        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Using tr As MySqlTransaction = conn.BeginTransaction()
                Try
                    Using verifyCmd As New MySqlCommand("SELECT COUNT(*) FROM utentiindirizzi WHERE Id = @Id AND UtenteId = @UtentiId", conn, tr)
                        verifyCmd.Parameters.AddWithValue("@Id", addressId)
                        verifyCmd.Parameters.AddWithValue("@UtentiId", utentiId)
                        Dim existsCount As Integer = Convert.ToInt32(verifyCmd.ExecuteScalar())
                        If existsCount <= 0 Then
                            tr.Rollback()
                            Return False
                        End If
                    End Using

                    Using resetCmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito = 0 WHERE UtenteId = @UtentiId", conn, tr)
                        resetCmd.Parameters.AddWithValue("@UtentiId", utentiId)
                        resetCmd.ExecuteNonQuery()
                    End Using

                    Using setCmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito = 1 WHERE Id = @Id AND UtenteId = @UtentiId", conn, tr)
                        setCmd.Parameters.AddWithValue("@Id", addressId)
                        setCmd.Parameters.AddWithValue("@UtentiId", utentiId)
                        If setCmd.ExecuteNonQuery() <> 1 Then
                            tr.Rollback()
                            Return False
                        End If
                    End Using

                    tr.Commit()
                    Return True
                Catch
                    Try
                        tr.Rollback()
                    Catch
                    End Try
                    Return False
                End Try
            End Using
        End Using
    End Function

    Private Sub ShowAddAddressForm()
        ClearAddressForm()
        hfAddressId.Value = "0"
        chkSetDefault.Checked = False
        litAddressFormTitle.Text = "Aggiungi indirizzo"
        pnlAddressForm.Visible = True
    End Sub

    Private Sub ShowEditAddressForm(ByVal utentiId As Integer, ByVal addressId As Integer)
        Dim row As DataRow = LoadAlternativeAddressById(utentiId, addressId)
        If row Is Nothing Then
            ShowMessage("Non e stato possibile aprire la sede richiesta.", False)
            Return
        End If

        ClearMessage()
        hfAddressId.Value = Convert.ToString(addressId)
        litAddressFormTitle.Text = "Modifica indirizzo"
        tbRagioneSocialeA.Text = SafeRowValue(row, "RagioneSocialeA", "")
        tbNomeA.Text = SafeRowValue(row, "NomeA", "")
        tbIndirizzoA.Text = SafeRowValue(row, "IndirizzoA", "")
        tbCapA.Text = SafeRowValue(row, "CapA", "")
        tbCittaA.Text = SafeRowValue(row, "CittaA", "")
        tbProvinciaA.Text = SafeRowValue(row, "ProvinciaA", "")
        tbZona.Text = SafeRowValue(row, "Zona", "")
        tbTelefonoA.Text = SafeRowValue(row, "TelefonoA", "")
        tbCellulareA.Text = SafeRowValue(row, "CellulareA", "")
        tbFaxA.Text = SafeRowValue(row, "FaxA", "")
        tbNote.Text = SafeRowValue(row, "Note", "")
        tbNazioneA.Text = SafeRowValue(row, "NazioneA", "")
        chkSetDefault.Checked = IsDefaultValue(row("Predefinito"))
        pnlAddressForm.Visible = True
    End Sub

    Private Sub HideAddressForm()
        pnlAddressForm.Visible = False
        ClearAddressForm()
    End Sub

    Private Sub ClearAddressForm()
        hfAddressId.Value = "0"
        litAddressFormTitle.Text = ""
        tbRagioneSocialeA.Text = ""
        tbNomeA.Text = ""
        tbIndirizzoA.Text = ""
        tbCapA.Text = ""
        tbCittaA.Text = ""
        tbProvinciaA.Text = ""
        tbZona.Text = ""
        tbTelefonoA.Text = ""
        tbCellulareA.Text = ""
        tbFaxA.Text = ""
        tbNote.Text = ""
        tbNazioneA.Text = "IT"
        chkSetDefault.Checked = False
    End Sub

    Private Function CurrentAddressFormId() As Integer
        Dim addressId As Integer = 0
        Integer.TryParse(Convert.ToString(hfAddressId.Value), addressId)
        Return addressId
    End Function

    Private Function LoadAlternativeAddressById(ByVal utentiId As Integer, ByVal addressId As Integer) As DataRow
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Dim sql As String =
                "SELECT " &
                "Id, " &
                "COALESCE(RagioneSocialeA,'') AS RagioneSocialeA, " &
                "COALESCE(NomeA,'') AS NomeA, " &
                "COALESCE(IndirizzoA,'') AS IndirizzoA, " &
                "COALESCE(CapA,'') AS CapA, " &
                "COALESCE(CittaA,'') AS CittaA, " &
                "COALESCE(ProvinciaA,'') AS ProvinciaA, " &
                "COALESCE(Zona,'') AS Zona, " &
                "COALESCE(TelefonoA,'') AS TelefonoA, " &
                "COALESCE(CellulareA,'') AS CellulareA, " &
                "COALESCE(FaxA,'') AS FaxA, " &
                "COALESCE(Note,'') AS Note, " &
                "COALESCE(Predefinito,0) AS Predefinito, " &
                "COALESCE(NazioneA,'') AS NazioneA " &
                "FROM utentiindirizzi " &
                "WHERE Id = @Id AND UtenteId = @UtentiId " &
                "LIMIT 1"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@Id", addressId)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        If dt.Rows.Count = 0 Then Return Nothing
        Return dt.Rows(0)
    End Function

    Private Function ValidateAddressForm() As List(Of String)
        Dim errors As New List(Of String)()

        If String.IsNullOrWhiteSpace(tbIndirizzoA.Text) Then errors.Add("Inserire l'indirizzo.")
        If String.IsNullOrWhiteSpace(tbCittaA.Text) Then errors.Add("Inserire la citta.")
        If CleanInput(tbCapA.Text).Length > 10 Then errors.Add("Il CAP e troppo lungo.")
        If CleanInput(tbProvinciaA.Text).Length > 10 Then errors.Add("La provincia e troppo lunga.")
        If CleanInput(tbTelefonoA.Text).Length > 30 Then errors.Add("Il telefono e troppo lungo.")
        If CleanInput(tbCellulareA.Text).Length > 30 Then errors.Add("Il cellulare e troppo lungo.")
        If CleanInput(tbFaxA.Text).Length > 30 Then errors.Add("Il fax e troppo lungo.")
        If CleanInput(tbRagioneSocialeA.Text).Length > 100 Then errors.Add("La ragione sociale/cognome e troppo lunga.")
        If CleanInput(tbNomeA.Text).Length > 50 Then errors.Add("Il nome e troppo lungo.")
        If CleanInput(tbIndirizzoA.Text).Length > 100 Then errors.Add("L'indirizzo e troppo lungo.")
        If CleanInput(tbCittaA.Text).Length > 80 Then errors.Add("La citta e troppo lunga.")
        If CleanInput(tbZona.Text).Length > 100 Then errors.Add("La zona e troppo lunga.")
        If CleanInput(tbNazioneA.Text).Length > 50 Then errors.Add("La nazione e troppo lunga.")
        If CleanInput(tbNote.Text).Length > 255 Then errors.Add("Le note sono troppo lunghe.")

        Return errors
    End Function

    Private Function SaveAlternativeAddress(ByVal utentiId As Integer, ByVal addressId As Integer) As Boolean
        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Using tr As MySqlTransaction = conn.BeginTransaction()
                Try
                    If addressId > 0 AndAlso Not AddressBelongsToUser(conn, tr, utentiId, addressId) Then
                        tr.Rollback()
                        Return False
                    End If

                    Dim forceDefault As Boolean = chkSetDefault.Checked OrElse (addressId <= 0 AndAlso CountAlternativeAddresses(conn, tr, utentiId) = 0)

                    If forceDefault Then
                        ResetDefaultAddresses(conn, tr, utentiId)
                    End If

                    If addressId > 0 Then
                        UpdateAlternativeAddress(conn, tr, utentiId, addressId, forceDefault)
                    Else
                        InsertAlternativeAddress(conn, tr, utentiId, forceDefault)
                    End If

                    tr.Commit()
                    Return True
                Catch
                    Try
                        tr.Rollback()
                    Catch
                    End Try
                    Return False
                End Try
            End Using
        End Using
    End Function

    Private Function AddressBelongsToUser(ByVal conn As MySqlConnection, ByVal tr As MySqlTransaction, ByVal utentiId As Integer, ByVal addressId As Integer) As Boolean
        Using cmd As New MySqlCommand("SELECT COUNT(*) FROM utentiindirizzi WHERE Id = @Id AND UtenteId = @UtentiId", conn, tr)
            cmd.Parameters.AddWithValue("@Id", addressId)
            cmd.Parameters.AddWithValue("@UtentiId", utentiId)
            Return Convert.ToInt32(cmd.ExecuteScalar()) > 0
        End Using
    End Function

    Private Function CountAlternativeAddresses(ByVal conn As MySqlConnection, ByVal tr As MySqlTransaction, ByVal utentiId As Integer) As Integer
        Using cmd As New MySqlCommand("SELECT COUNT(*) FROM utentiindirizzi WHERE UtenteId = @UtentiId", conn, tr)
            cmd.Parameters.AddWithValue("@UtentiId", utentiId)
            Return Convert.ToInt32(cmd.ExecuteScalar())
        End Using
    End Function

    Private Sub ResetDefaultAddresses(ByVal conn As MySqlConnection, ByVal tr As MySqlTransaction, ByVal utentiId As Integer)
        Using cmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito = 0 WHERE UtenteId = @UtentiId", conn, tr)
            cmd.Parameters.AddWithValue("@UtentiId", utentiId)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Sub InsertAlternativeAddress(ByVal conn As MySqlConnection, ByVal tr As MySqlTransaction, ByVal utentiId As Integer, ByVal setDefault As Boolean)
        Dim sql As String =
            "INSERT INTO utentiindirizzi " &
            "(UtenteId, RagioneSocialeA, NomeA, IndirizzoA, CapA, CittaA, ProvinciaA, Zona, TelefonoA, CellulareA, FaxA, Note, NazioneA, Predefinito) " &
            "VALUES " &
            "(@UtentiId, @RagioneSocialeA, @NomeA, @IndirizzoA, @CapA, @CittaA, @ProvinciaA, @Zona, @TelefonoA, @CellulareA, @FaxA, @Note, @NazioneA, @Predefinito)"

        Using cmd As New MySqlCommand(sql, conn, tr)
            AddAddressParameters(cmd, utentiId, setDefault, True)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Sub UpdateAlternativeAddress(ByVal conn As MySqlConnection, ByVal tr As MySqlTransaction, ByVal utentiId As Integer, ByVal addressId As Integer, ByVal setDefault As Boolean)
        Dim sql As String =
            "UPDATE utentiindirizzi SET " &
            "RagioneSocialeA = @RagioneSocialeA, " &
            "NomeA = @NomeA, " &
            "IndirizzoA = @IndirizzoA, " &
            "CapA = @CapA, " &
            "CittaA = @CittaA, " &
            "ProvinciaA = @ProvinciaA, " &
            "Zona = @Zona, " &
            "TelefonoA = @TelefonoA, " &
            "CellulareA = @CellulareA, " &
            "FaxA = @FaxA, " &
            "Note = @Note, " &
            "NazioneA = @NazioneA"

        If setDefault Then sql &= ", Predefinito = @Predefinito"
        sql &= " WHERE Id = @Id AND UtenteId = @UtentiId"

        Using cmd As New MySqlCommand(sql, conn, tr)
            AddAddressParameters(cmd, utentiId, setDefault, setDefault)
            cmd.Parameters.AddWithValue("@Id", addressId)
            If cmd.ExecuteNonQuery() <> 1 Then Throw New InvalidOperationException("Address update failed")
        End Using
    End Sub

    Private Sub AddAddressParameters(ByVal cmd As MySqlCommand, ByVal utentiId As Integer, ByVal setDefault As Boolean, ByVal includeDefault As Boolean)
        cmd.Parameters.AddWithValue("@UtentiId", utentiId)
        cmd.Parameters.AddWithValue("@RagioneSocialeA", CleanInput(tbRagioneSocialeA.Text))
        cmd.Parameters.AddWithValue("@NomeA", CleanInput(tbNomeA.Text))
        cmd.Parameters.AddWithValue("@IndirizzoA", CleanInput(tbIndirizzoA.Text))
        cmd.Parameters.AddWithValue("@CapA", CleanInput(tbCapA.Text))
        cmd.Parameters.AddWithValue("@CittaA", CleanInput(tbCittaA.Text))
        cmd.Parameters.AddWithValue("@ProvinciaA", CleanInput(tbProvinciaA.Text))
        cmd.Parameters.AddWithValue("@Zona", CleanInput(tbZona.Text))
        cmd.Parameters.AddWithValue("@TelefonoA", CleanInput(tbTelefonoA.Text))
        cmd.Parameters.AddWithValue("@CellulareA", CleanInput(tbCellulareA.Text))
        cmd.Parameters.AddWithValue("@FaxA", CleanInput(tbFaxA.Text))
        cmd.Parameters.AddWithValue("@Note", CleanInput(tbNote.Text))
        cmd.Parameters.AddWithValue("@NazioneA", CleanInput(tbNazioneA.Text))
        If includeDefault Then cmd.Parameters.AddWithValue("@Predefinito", If(setDefault, 1, 0))
    End Sub

    Private Function CleanInput(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Return value.Trim()
    End Function

    Public Function SafeField(ByVal dataItem As Object, ByVal fieldName As String, ByVal fallback As String) As String
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return Server.HtmlEncode(fallback)
        Return Server.HtmlEncode(SafeRowViewValue(rowView, fieldName, fallback))
    End Function

    Public Function IsDefaultAddress(ByVal dataItem As Object) As Boolean
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return False
        Return IsDefaultValue(rowView("Predefinito"))
    End Function

    Private Function IsDefaultValue(ByVal raw As Object) As Boolean
        Dim value As Integer = 0
        If raw IsNot Nothing AndAlso raw IsNot DBNull.Value Then Integer.TryParse(Convert.ToString(raw), value)
        Return value = 1
    End Function

    Private Function SafeRowViewValue(ByVal rowView As DataRowView, ByVal fieldName As String, ByVal fallback As String) As String
        If rowView Is Nothing OrElse rowView.Row Is Nothing OrElse Not rowView.Row.Table.Columns.Contains(fieldName) Then Return fallback
        Return SafeText(rowView(fieldName), fallback)
    End Function

    Private Function SafeRowValue(ByVal row As DataRow, ByVal fieldName As String, ByVal fallback As String) As String
        If row Is Nothing OrElse Not row.Table.Columns.Contains(fieldName) Then Return fallback
        Return SafeText(row(fieldName), fallback)
    End Function

    Private Function SafeText(ByVal raw As Object, ByVal fallback As String) As String
        If raw Is Nothing OrElse raw Is DBNull.Value Then Return fallback
        Dim value As String = Convert.ToString(raw).Trim()
        If String.IsNullOrWhiteSpace(value) Then Return fallback
        Return value
    End Function

    Private Sub ClearMessage()
        lblPageMessage.Text = ""
        lblPageMessage.CssClass = "d-none"
    End Sub

    Private Sub ShowMessage(ByVal message As String, ByVal success As Boolean)
        lblPageMessage.Text = message
        lblPageMessage.CssClass = If(success, "alert alert-success d-block mb-4", "alert alert-danger d-block mb-4")
    End Sub

    Private Sub ShowValidationMessage(ByVal errors As List(Of String))
        lblPageMessage.Text = Server.HtmlEncode(String.Join(" ", errors.ToArray()))
        lblPageMessage.CssClass = "alert alert-danger d-block mb-4"
    End Sub
End Class
