Imports MySql.Data.MySqlClient
Imports System
Imports System.Configuration
Imports System.Text.RegularExpressions
Imports System.Web.UI.WebControls

Partial Class my_account_edit
    Inherits System.Web.UI.Page

    Private Const MaxEmailLength As Integer = 50
    Private Const MaxPhoneLength As Integer = 50
    Private Const MaxAddressLength As Integer = 255
    Private Const MaxCapLength As Integer = 12
    Private Const MaxCityLength As Integer = 120
    Private Const MaxProvinceLength As Integer = 8
    Private Const MaxNationLength As Integer = 8

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
            LoadProfile()
        End If
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - Dettagli account"
    End Sub

    Protected Sub btnSave_Click(ByVal sender As Object, ByVal e As EventArgs)
        Dim loginId As Integer = CurrentLoginId()
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        Dim current As AccountProfileData = LoadProfileData(loginId)
        If current Is Nothing OrElse current.UtentiId <= 0 Then
            ShowMessage("Non e stato possibile caricare il profilo account.", False)
            Return
        End If

        Dim updated As New AccountProfileData()
        updated.UtentiId = current.UtentiId
        updated.Email = CleanText(txtEmail.Text)
        updated.Indirizzo = MergeText(txtIndirizzo, current.Indirizzo)
        updated.Cap = MergeText(txtCap, current.Cap)
        updated.Citta = MergeText(txtCitta, current.Citta)
        updated.Provincia = MergeText(txtProvincia, current.Provincia)
        updated.Nazione = MergeText(txtNazione, current.Nazione)
        updated.Telefono = SubmittedText(txtTelefono)
        updated.Cellulare = SubmittedText(txtCellulare)
        updated.Fax = SubmittedText(txtFax)

        Dim validationMessage As String = ""
        If Not ValidateProfileInput(updated, validationMessage) Then
            ShowMessage(validationMessage, False)
            Return
        End If

        Try
            Using conn As New MySqlConnection(ConnString)
                conn.Open()

                Using tr As MySqlTransaction = conn.BeginTransaction()
                    Dim sqlUtente As String =
                        "UPDATE utenti u " &
                        "INNER JOIN login l ON l.UtentiId = u.id " &
                        "SET u.Email = @Email, " &
                        "u.Indirizzo = @Indirizzo, " &
                        "u.Cap = @Cap, " &
                        "u.Citta = @Citta, " &
                        "u.Provincia = @Provincia, " &
                        "u.Nazione = @Nazione, " &
                        "u.Telefono = @Telefono, " &
                        "u.Cellulare = @Cellulare, " &
                        "u.Fax = @Fax " &
                        "WHERE u.id = @UtentiId AND l.id = @LoginId"

                    Using cmd As New MySqlCommand(sqlUtente, conn, tr)
                        cmd.Parameters.AddWithValue("@Email", updated.Email)
                        cmd.Parameters.AddWithValue("@Indirizzo", updated.Indirizzo)
                        cmd.Parameters.AddWithValue("@Cap", updated.Cap)
                        cmd.Parameters.AddWithValue("@Citta", updated.Citta)
                        cmd.Parameters.AddWithValue("@Provincia", updated.Provincia)
                        cmd.Parameters.AddWithValue("@Nazione", updated.Nazione)
                        cmd.Parameters.AddWithValue("@Telefono", updated.Telefono)
                        cmd.Parameters.AddWithValue("@Cellulare", updated.Cellulare)
                        cmd.Parameters.AddWithValue("@Fax", updated.Fax)
                        cmd.Parameters.AddWithValue("@UtentiId", current.UtentiId)
                        cmd.Parameters.AddWithValue("@LoginId", loginId)
                        cmd.ExecuteNonQuery()
                    End Using

                    Dim sqlLogin As String =
                        "UPDATE login SET Email = @Email WHERE id = @LoginId AND UtentiId = @UtentiId"

                    Using cmdLogin As New MySqlCommand(sqlLogin, conn, tr)
                        cmdLogin.Parameters.AddWithValue("@Email", updated.Email)
                        cmdLogin.Parameters.AddWithValue("@LoginId", loginId)
                        cmdLogin.Parameters.AddWithValue("@UtentiId", current.UtentiId)
                        cmdLogin.ExecuteNonQuery()
                    End Using

                    tr.Commit()
                End Using
            End Using

            LoadProfile()
            ShowMessage("Dati aggiornati correttamente.", True)
        Catch
            ShowMessage("Non e stato possibile salvare i dati. Riprova piu tardi.", False)
        End Try
    End Sub

    Private Sub LoadProfile()
        Dim loginId As Integer = CurrentLoginId()
        If loginId <= 0 Then Return

        Dim profile As AccountProfileData = LoadProfileData(loginId)
        If profile Is Nothing OrElse profile.UtentiId <= 0 Then
            pnlProfile.Visible = False
            ShowMessage("Non e stato possibile caricare il profilo account.", False)
            Return
        End If

        pnlProfile.Visible = True
        hidUtentiId.Value = profile.UtentiId.ToString()
        txtUsername.Text = profile.Username
        txtEmail.Text = profile.Email
        txtCodice.Text = profile.Codice
        txtUltimoAccesso.Text = profile.UltimoAccessoText
        txtRagioneSociale.Text = profile.RagioneSociale
        txtCognomeNome.Text = profile.CognomeNome
        txtPiva.Text = profile.Piva
        txtCodiceFiscale.Text = profile.CodiceFiscale
        txtTelefono.Text = profile.Telefono
        txtCellulare.Text = profile.Cellulare
        txtFax.Text = profile.Fax
        txtIndirizzo.Text = profile.Indirizzo
        txtCap.Text = profile.Cap
        txtCitta.Text = profile.Citta
        txtProvincia.Text = profile.Provincia
        txtNazione.Text = profile.Nazione
    End Sub

    Private Function LoadProfileData(ByVal loginId As Integer) As AccountProfileData
        If loginId <= 0 Then Return Nothing

        Using conn As New MySqlConnection(ConnString)
            Dim sql As String =
                "SELECT " &
                "u.id AS UtentiId, " &
                "COALESCE(v.Username,'') AS Username, " &
                "COALESCE(v.email, u.Email, '') AS Email, " &
                "COALESCE(v.cognomenome,'') AS CognomeNome, " &
                "v.ultimoaccesso AS UltimoAccesso, " &
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
                conn.Open()

                Using r As MySqlDataReader = cmd.ExecuteReader()
                    If Not r.Read() Then Return Nothing

                    Dim profile As New AccountProfileData()
                    profile.UtentiId = SafeInt(r("UtentiId"))
                    profile.Username = SafeString(r("Username"))
                    profile.Email = SafeString(r("Email"))
                    profile.CognomeNome = SafeString(r("CognomeNome"))
                    profile.UltimoAccessoText = FormatDate(r("UltimoAccesso"))
                    profile.Codice = SafeString(r("Codice"))
                    profile.RagioneSociale = SafeString(r("RagioneSociale"))
                    profile.Piva = SafeString(r("Piva"))
                    profile.CodiceFiscale = SafeString(r("CodiceFiscale"))
                    profile.Telefono = SafeString(r("Telefono"))
                    profile.Cellulare = SafeString(r("Cellulare"))
                    profile.Fax = SafeString(r("Fax"))
                    profile.Indirizzo = SafeString(r("Indirizzo"))
                    profile.Cap = SafeString(r("Cap"))
                    profile.Citta = SafeString(r("Citta"))
                    profile.Provincia = SafeString(r("Provincia"))
                    profile.Nazione = SafeString(r("Nazione"))
                    Return profile
                End Using
            End Using
        End Using
    End Function

    Private Function CurrentLoginId() As Integer
        If Session("LoginId") Is Nothing Then Return 0
        Return SafeInt(Session("LoginId"))
    End Function

    Private Function MergeText(ByVal tb As TextBox, ByVal currentValue As String) As String
        If tb Is Nothing Then Return CleanText(currentValue)

        Dim value As String = CleanText(tb.Text)
        If String.IsNullOrWhiteSpace(value) Then Return CleanText(currentValue)
        Return value
    End Function

    Private Function SubmittedText(ByVal tb As TextBox) As String
        If tb Is Nothing Then Return ""
        Return CleanText(tb.Text)
    End Function

    Private Function ValidateProfileInput(ByVal profile As AccountProfileData, ByRef message As String) As Boolean
        message = ""

        If profile Is Nothing Then
            message = "Non e stato possibile verificare i dati del profilo."
            Return False
        End If

        If String.IsNullOrWhiteSpace(profile.Email) OrElse Not LooksLikeEmail(profile.Email) Then
            message = "Inserisci un indirizzo email valido."
            Return False
        End If
        If profile.Email.Length > MaxEmailLength Then
            message = "L'indirizzo email non puo superare 50 caratteri."
            Return False
        End If

        If Not ValidateMaxLength(profile.Telefono, MaxPhoneLength, "Il telefono", message) Then Return False
        If Not ValidateMaxLength(profile.Cellulare, MaxPhoneLength, "Il cellulare", message) Then Return False
        If Not ValidateMaxLength(profile.Fax, MaxPhoneLength, "Il fax", message) Then Return False
        If Not ValidateMaxLength(profile.Indirizzo, MaxAddressLength, "L'indirizzo", message) Then Return False
        If Not ValidateMaxLength(profile.Cap, MaxCapLength, "Il CAP", message) Then Return False
        If Not ValidateMaxLength(profile.Citta, MaxCityLength, "La citta", message) Then Return False
        If Not ValidateMaxLength(profile.Provincia, MaxProvinceLength, "La provincia", message) Then Return False
        If Not ValidateMaxLength(profile.Nazione, MaxNationLength, "La nazione", message) Then Return False

        If profile.Cap <> "" AndAlso Not Regex.IsMatch(profile.Cap, "^[A-Za-z0-9][A-Za-z0-9\s-]{1,11}$") Then
            message = "Inserisci un CAP valido."
            Return False
        End If

        If profile.Provincia <> "" AndAlso Not Regex.IsMatch(profile.Provincia, "^[A-Za-z]{2,8}$") Then
            message = "Inserisci una provincia valida."
            Return False
        End If

        If Not IsContactTextValid(profile.Telefono) OrElse Not IsContactTextValid(profile.Cellulare) OrElse Not IsContactTextValid(profile.Fax) Then
            message = "Telefono, cellulare e fax possono contenere solo numeri, spazi e simboli telefonici comuni."
            Return False
        End If

        Return True
    End Function

    Private Function ValidateMaxLength(ByVal value As String, ByVal maxLength As Integer, ByVal label As String, ByRef message As String) As Boolean
        If value IsNot Nothing AndAlso value.Length > maxLength Then
            message = label & " non puo superare " & maxLength.ToString() & " caratteri."
            Return False
        End If
        Return True
    End Function

    Private Function IsContactTextValid(ByVal value As String) As Boolean
        If String.IsNullOrWhiteSpace(value) Then Return True
        Return Regex.IsMatch(value, "^[0-9+()./\s-]+$")
    End Function

    Private Function CleanText(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Dim text As String = value.Trim()
        text = text.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ")
        Do While text.Contains("  ")
            text = text.Replace("  ", " ")
        Loop
        Return text
    End Function

    Private Function SafeString(ByVal value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return ""
        Return CleanText(Convert.ToString(value))
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

    Private Function FormatDate(ByVal value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return ""
        Try
            Return Convert.ToDateTime(value).ToString("dd/MM/yyyy HH:mm")
        Catch
            Return ""
        End Try
    End Function

    Private Function LooksLikeEmail(ByVal value As String) As Boolean
        If String.IsNullOrWhiteSpace(value) Then Return False
        Return Regex.IsMatch(value.Trim(), "^[^@\s]+@[^@\s]+\.[^@\s]+$")
    End Function

    Private Sub ShowMessage(ByVal message As String, ByVal success As Boolean)
        pnlMessage.Visible = True
        pnlMessage.CssClass = If(success, "alert alert-success mb-4", "alert alert-danger mb-4")
        litMessage.Text = Server.HtmlEncode(message)
    End Sub

    Private Class AccountProfileData
        Public Property UtentiId As Integer
        Public Property Username As String
        Public Property Email As String
        Public Property CognomeNome As String
        Public Property UltimoAccessoText As String
        Public Property Codice As String
        Public Property RagioneSociale As String
        Public Property Piva As String
        Public Property CodiceFiscale As String
        Public Property Telefono As String
        Public Property Cellulare As String
        Public Property Fax As String
        Public Property Indirizzo As String
        Public Property Cap As String
        Public Property Citta As String
        Public Property Provincia As String
        Public Property Nazione As String
    End Class
End Class
