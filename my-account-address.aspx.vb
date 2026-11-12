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

        Dim scope As AccountAddressScope = CurrentAddressScope()
        If scope Is Nothing Then
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        BindMainAddress(scope)
        BindAlternativeAddresses(scope)
    End Sub

    Private Function CurrentLoginId() As Integer
        Dim value As Integer = 0
        Integer.TryParse(Convert.ToString(Session("LoginId")), value)
        If value <= 0 Then Integer.TryParse(Convert.ToString(Session("LoginID")), value)
        Return value
    End Function

    Private Function SafeInt(ByVal value As Object) As Integer
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return 0
            Dim parsed As Integer = 0
            If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try
        Return 0
    End Function

    ' Proprietario degli indirizzi: solo lo scope gia validato dal master per questa richiesta (stesso contratto di
    ' my-account-edit). Nessuna ricostruzione da vlogin e nessuna scrittura in sessione: scope assente = fail-closed.
    Private Function CurrentAddressScope() As AccountAddressScope
        If Context Is Nothing OrElse Context.Session Is Nothing Then Return Nothing
        Dim loginId As Integer = CurrentLoginId()
        Dim userId As Integer = SafeInt(Session("UtentiId"))
        Dim companyId As Integer = SafeInt(Session("AuthenticatedAziendaID"))
        Dim priceListId As Integer = StorefrontCommercialIsolationPolicy.ResolveSessionPriceList(Session("Listino"), Session("listino"))
        ' Consuma solo il risultato gia pubblicato dal master Init, senza altre risoluzioni.
        Dim tenant As StorefrontSeoTenantIdentity = TryCast(Context.Items("KeepStore.StorefrontSeoTenant"), StorefrontSeoTenantIdentity)
        If loginId <= 0 OrElse userId <= 0 OrElse companyId <= 0 OrElse priceListId <= 0 OrElse
           companyId <> SafeInt(Session("AziendaID")) OrElse tenant Is Nothing OrElse tenant.CompanyId <> companyId Then Return Nothing
        Dim databaseScope As String = StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey()
        If String.IsNullOrEmpty(databaseScope) Then Return Nothing
        ' Contratto esatto di PageMaster.CurrentAuthenticatedScopeKey, incluso proprietario e listino.
        Dim marker As String = databaseScope & ":" & companyId.ToString() & ":" & loginId.ToString() & ":" &
            userId.ToString() & ":" & companyId.ToString() & ":" & priceListId.ToString()
        If Not String.Equals(TryCast(Context.Items("KeepStore.Authentication.ValidatedScope"), String), marker, StringComparison.Ordinal) Then Return Nothing
        Return New AccountAddressScope() With {.LoginId = loginId, .UserId = userId, .CompanyId = companyId, .Marker = marker}
    End Function

    Private Function IsAddressScopeCurrent(ByVal expected As AccountAddressScope) As Boolean
        If expected Is Nothing Then Return False
        Dim current As AccountAddressScope = CurrentAddressScope()
        Return current IsNot Nothing AndAlso String.Equals(current.Marker, expected.Marker, StringComparison.Ordinal)
    End Function

    Private Sub AddAddressScopeParameters(ByVal command As MySqlCommand, ByVal scope As AccountAddressScope)
        command.Parameters.Add("@LoginId", MySqlDbType.Int32).Value = scope.LoginId
        command.Parameters.Add("@UtentiId", MySqlDbType.Int32).Value = scope.UserId
        command.Parameters.Add("@AziendaId", MySqlDbType.Int32).Value = scope.CompanyId
    End Sub

    ' Prima istruzione di ogni transazione di scrittura: blocca login e proprietario e verifica la tupla
    ' login + utente + azienda della vetrina; senza riga nessuna istruzione successiva viene eseguita.
    Private Function LockAddressOwner(ByVal conn As MySqlConnection, ByVal tr As MySqlTransaction, ByVal scope As AccountAddressScope) As Boolean
        If Not IsAddressScopeCurrent(scope) Then Return False
        Using cmd As New MySqlCommand("SELECT 1 FROM login l INNER JOIN utenti u ON l.UtentiId = u.Id WHERE l.id = @LoginId AND u.Id = @UtentiId AND u.AziendeId = @AziendaId AND u.Abilitato = 1 AND l.Abilitato = 1 LIMIT 1 FOR UPDATE", conn, tr)
            AddAddressScopeParameters(cmd, scope)
            Dim raw As Object = cmd.ExecuteScalar()
            Return raw IsNot Nothing AndAlso raw IsNot DBNull.Value
        End Using
    End Function

    Private NotInheritable Class AccountAddressScope
        Public LoginId As Integer
        Public UserId As Integer
        Public CompanyId As Integer
        Public Marker As String
    End Class

    Private Sub BindMainAddress(ByVal scope As AccountAddressScope)
        Dim dt As New DataTable()

        If IsAddressScopeCurrent(scope) Then
            Using conn As New MySqlConnection(ConnString)
                conn.Open()

                ' Letture con tupla completa nello stesso statement: nessuna finestra tra verifica e lettura.
                Dim sql As String =
                    "SELECT " &
                    "COALESCE(u.RagioneSociale,'') AS RagioneSociale, " &
                    "COALESCE(u.CognomeNome,'') AS CognomeNome, " &
                    "COALESCE(u.Email,'') AS Email, " &
                    "COALESCE(u.Indirizzo,'') AS Indirizzo, " &
                    "COALESCE(u.Cap,'') AS Cap, " &
                    "COALESCE(u.Citta,'') AS Citta, " &
                    "COALESCE(u.Provincia,'') AS Provincia, " &
                    "COALESCE(u.Nazione,'') AS Nazione, " &
                    "COALESCE(u.Telefono,'') AS Telefono, " &
                    "COALESCE(u.Cellulare,'') AS Cellulare " &
                    "FROM utenti u INNER JOIN login l ON l.UtentiId = u.Id " &
                    "WHERE u.Id = @UtentiId AND l.id = @LoginId AND u.AziendeId = @AziendaId " &
                    "AND u.Abilitato = 1 AND l.Abilitato = 1 LIMIT 1"

                Using cmd As New MySqlCommand(sql, conn)
                    AddAddressScopeParameters(cmd, scope)
                    Using da As New MySqlDataAdapter(cmd)
                        da.Fill(dt)
                    End Using
                End Using
            End Using
        End If

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

    Private Sub BindAlternativeAddresses(ByVal scope As AccountAddressScope)
        Dim dt As DataTable = LoadAlternativeAddresses(scope)
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

    Private Function LoadAlternativeAddresses(ByVal scope As AccountAddressScope) As DataTable
        Dim dt As New DataTable()

        If Not IsAddressScopeCurrent(scope) Then Return dt

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Dim sql As String =
                "SELECT " &
                "a.Id AS Id, " &
                "COALESCE(a.RagioneSocialeA,'') AS RagioneSocialeA, " &
                "COALESCE(a.NomeA,'') AS NomeA, " &
                "COALESCE(a.IndirizzoA,'') AS IndirizzoA, " &
                "COALESCE(a.CapA,'') AS CapA, " &
                "COALESCE(a.CittaA,'') AS CittaA, " &
                "COALESCE(a.ProvinciaA,'') AS ProvinciaA, " &
                "COALESCE(a.Zona,'') AS Zona, " &
                "COALESCE(a.TelefonoA,'') AS TelefonoA, " &
                "COALESCE(a.CellulareA,'') AS CellulareA, " &
                "COALESCE(a.FaxA,'') AS FaxA, " &
                "COALESCE(a.Note,'') AS Note, " &
                "COALESCE(a.Predefinito,0) AS Predefinito, " &
                "COALESCE(a.NazioneA,'') AS NazioneA " &
                "FROM utentiindirizzi a " &
                "INNER JOIN utenti u ON u.Id = a.UtenteId " &
                "INNER JOIN login l ON l.UtentiId = u.Id " &
                "WHERE a.UtenteId = @UtentiId AND l.id = @LoginId AND u.AziendeId = @AziendaId " &
                "AND u.Abilitato = 1 AND l.Abilitato = 1 " &
                "ORDER BY COALESCE(a.Predefinito,0) DESC, a.Id ASC"

            Using cmd As New MySqlCommand(sql, conn)
                AddAddressScopeParameters(cmd, scope)
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

        Dim scope As AccountAddressScope = CurrentAddressScope()

        If String.Equals(e.CommandName, "EditAddress", StringComparison.OrdinalIgnoreCase) Then
            If addressId <= 0 OrElse scope Is Nothing Then
                ShowMessage("Non e stato possibile aprire la sede richiesta.", False)
                Return
            End If

            ShowEditAddressForm(scope, addressId)
            Return
        End If

        If Not String.Equals(e.CommandName, "SetDefault", StringComparison.OrdinalIgnoreCase) Then Return

        If addressId <= 0 OrElse scope Is Nothing Then
            ShowMessage("Non e stato possibile aggiornare la sede predefinita.", False)
            If scope IsNot Nothing Then BindAlternativeAddresses(scope)
            Return
        End If

        If SetDefaultAlternativeAddress(scope, addressId) Then
            ShowMessage("Sede predefinita aggiornata correttamente.", True)
        Else
            ShowMessage("Non e stato possibile aggiornare la sede predefinita.", False)
        End If

        BindAlternativeAddresses(scope)
    End Sub

    Protected Sub btnShowAddAddress_Click(ByVal sender As Object, ByVal e As EventArgs)
        ClearMessage()
        ShowAddAddressForm()
    End Sub

    Protected Sub btnCancelAddress_Click(ByVal sender As Object, ByVal e As EventArgs)
        ClearMessage()
        HideAddressForm()

        Dim scope As AccountAddressScope = CurrentAddressScope()
        If scope IsNot Nothing Then BindAlternativeAddresses(scope)
    End Sub

    Protected Sub btnSaveAddress_Click(ByVal sender As Object, ByVal e As EventArgs)
        Dim scope As AccountAddressScope = CurrentAddressScope()

        If scope Is Nothing Then
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

        If SaveAlternativeAddress(scope, addressId) Then
            HideAddressForm()
            BindAlternativeAddresses(scope)
            ShowMessage(If(addressId > 0, "Indirizzo aggiornato correttamente.", "Indirizzo aggiunto correttamente."), True)
        Else
            pnlAddressForm.Visible = True
            litAddressFormTitle.Text = If(addressId > 0, "Modifica indirizzo", "Aggiungi indirizzo")
            ShowMessage("Non e stato possibile salvare l'indirizzo.", False)
        End If
    End Sub

    Private Function SetDefaultAlternativeAddress(ByVal scope As AccountAddressScope, ByVal addressId As Integer) As Boolean
        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Using tr As MySqlTransaction = conn.BeginTransaction()
                Try
                    If Not LockAddressOwner(conn, tr, scope) Then
                        tr.Rollback()
                        Return False
                    End If

                    Using verifyCmd As New MySqlCommand("SELECT COUNT(*) FROM utentiindirizzi WHERE Id = @Id AND UtenteId = @UtentiId", conn, tr)
                        verifyCmd.Parameters.Add("@Id", MySqlDbType.Int32).Value = addressId
                        verifyCmd.Parameters.Add("@UtentiId", MySqlDbType.Int32).Value = scope.UserId
                        Dim existsCount As Integer = Convert.ToInt32(verifyCmd.ExecuteScalar())
                        If existsCount <= 0 Then
                            tr.Rollback()
                            Return False
                        End If
                    End Using

                    Using resetCmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito = 0 WHERE UtenteId = @UtentiId", conn, tr)
                        resetCmd.Parameters.Add("@UtentiId", MySqlDbType.Int32).Value = scope.UserId
                        resetCmd.ExecuteNonQuery()
                    End Using

                    Using setCmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito = 1 WHERE Id = @Id AND UtenteId = @UtentiId", conn, tr)
                        setCmd.Parameters.Add("@Id", MySqlDbType.Int32).Value = addressId
                        setCmd.Parameters.Add("@UtentiId", MySqlDbType.Int32).Value = scope.UserId
                        If setCmd.ExecuteNonQuery() <> 1 Then
                            tr.Rollback()
                            Return False
                        End If
                    End Using

                    If Not IsAddressScopeCurrent(scope) Then
                        tr.Rollback()
                        Return False
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

    Private Sub ShowAddAddressForm()
        ClearAddressForm()
        hfAddressId.Value = "0"
        chkSetDefault.Checked = False
        litAddressFormTitle.Text = "Aggiungi indirizzo"
        pnlAddressForm.Visible = True
    End Sub

    Private Sub ShowEditAddressForm(ByVal scope As AccountAddressScope, ByVal addressId As Integer)
        Dim row As DataRow = LoadAlternativeAddressById(scope, addressId)
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

    Private Function LoadAlternativeAddressById(ByVal scope As AccountAddressScope, ByVal addressId As Integer) As DataRow
        Dim dt As New DataTable()

        If Not IsAddressScopeCurrent(scope) Then Return Nothing

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Dim sql As String =
                "SELECT " &
                "a.Id AS Id, " &
                "COALESCE(a.RagioneSocialeA,'') AS RagioneSocialeA, " &
                "COALESCE(a.NomeA,'') AS NomeA, " &
                "COALESCE(a.IndirizzoA,'') AS IndirizzoA, " &
                "COALESCE(a.CapA,'') AS CapA, " &
                "COALESCE(a.CittaA,'') AS CittaA, " &
                "COALESCE(a.ProvinciaA,'') AS ProvinciaA, " &
                "COALESCE(a.Zona,'') AS Zona, " &
                "COALESCE(a.TelefonoA,'') AS TelefonoA, " &
                "COALESCE(a.CellulareA,'') AS CellulareA, " &
                "COALESCE(a.FaxA,'') AS FaxA, " &
                "COALESCE(a.Note,'') AS Note, " &
                "COALESCE(a.Predefinito,0) AS Predefinito, " &
                "COALESCE(a.NazioneA,'') AS NazioneA " &
                "FROM utentiindirizzi a " &
                "INNER JOIN utenti u ON u.Id = a.UtenteId " &
                "INNER JOIN login l ON l.UtentiId = u.Id " &
                "WHERE a.Id = @Id AND a.UtenteId = @UtentiId AND l.id = @LoginId AND u.AziendeId = @AziendaId " &
                "AND u.Abilitato = 1 AND l.Abilitato = 1 " &
                "LIMIT 1"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.Add("@Id", MySqlDbType.Int32).Value = addressId
                AddAddressScopeParameters(cmd, scope)
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

    Private Function SaveAlternativeAddress(ByVal scope As AccountAddressScope, ByVal addressId As Integer) As Boolean
        Dim utentiId As Integer = If(scope Is Nothing, 0, scope.UserId)

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Using tr As MySqlTransaction = conn.BeginTransaction()
                Try
                    If Not LockAddressOwner(conn, tr, scope) Then
                        tr.Rollback()
                        Return False
                    End If

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

                    If Not IsAddressScopeCurrent(scope) Then
                        tr.Rollback()
                        Return False
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
            cmd.Parameters.Add("@Id", MySqlDbType.Int32).Value = addressId
            cmd.Parameters.Add("@UtentiId", MySqlDbType.Int32).Value = utentiId
            Return Convert.ToInt32(cmd.ExecuteScalar()) > 0
        End Using
    End Function

    Private Function CountAlternativeAddresses(ByVal conn As MySqlConnection, ByVal tr As MySqlTransaction, ByVal utentiId As Integer) As Integer
        Using cmd As New MySqlCommand("SELECT COUNT(*) FROM utentiindirizzi WHERE UtenteId = @UtentiId", conn, tr)
            cmd.Parameters.Add("@UtentiId", MySqlDbType.Int32).Value = utentiId
            Return Convert.ToInt32(cmd.ExecuteScalar())
        End Using
    End Function

    Private Sub ResetDefaultAddresses(ByVal conn As MySqlConnection, ByVal tr As MySqlTransaction, ByVal utentiId As Integer)
        Using cmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito = 0 WHERE UtenteId = @UtentiId", conn, tr)
            cmd.Parameters.Add("@UtentiId", MySqlDbType.Int32).Value = utentiId
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
            cmd.Parameters.Add("@Id", MySqlDbType.Int32).Value = addressId
            If cmd.ExecuteNonQuery() <> 1 Then Throw New InvalidOperationException("Address update failed")
        End Using
    End Sub

    Private Sub AddAddressParameters(ByVal cmd As MySqlCommand, ByVal utentiId As Integer, ByVal setDefault As Boolean, ByVal includeDefault As Boolean)
        cmd.Parameters.Add("@UtentiId", MySqlDbType.Int32).Value = utentiId
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
