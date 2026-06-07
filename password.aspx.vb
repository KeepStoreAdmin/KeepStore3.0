Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Configuration

Partial Class password
    Inherits System.Web.UI.Page

    Private Const MinPasswordLength As Integer = 8
    Private Const MaxPasswordLength As Integer = 25

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("LoginId") Is Nothing Then
            Response.Redirect("accessonegato.aspx", True)
        End If

        If Not IsPostBack Then
            ClearPasswordMessage()
        End If
    End Sub

    Protected Sub btnSalva_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnSalva.Click
        ClearPasswordMessage()

        Page.Validate("PasswordChange")
        If Not Page.IsValid Then
            Exit Sub
        End If

        Dim oldPwd As String = Convert.ToString(tbPasswordAttuale.Text)
        Dim newPwd As String = Convert.ToString(tbPasswordNuova.Text)
        Dim newPwd2 As String = Convert.ToString(tbPasswordConferma.Text)

        If Not String.Equals(newPwd, newPwd2, StringComparison.Ordinal) Then
            ShowPasswordMessage("Le nuove password non coincidono.", False)
            Exit Sub
        End If

        Dim loginIdValue As Integer = 0
        If Not TryGetLoginId(loginIdValue) Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Try
            Using conn As New MySqlConnection(connString)
                conn.Open()

                Dim currentPassword As String = GetCurrentPassword(conn, loginIdValue)
                Dim validationMessage As String = ""

                If Not ValidatePasswordChange(oldPwd, newPwd, newPwd2, currentPassword, validationMessage) Then
                    ShowPasswordMessage(validationMessage, False)
                    Exit Sub
                End If

                If Not UpdatePassword(conn, loginIdValue, currentPassword, newPwd, newPwd2) Then
                    ShowPasswordMessage("Nessuna modifica eseguita.", False)
                    Exit Sub
                End If

                ShowPasswordMessage("Password aggiornata correttamente.", True)
                Session("DataPassword") = DateTime.Today
                tbPasswordAttuale.Text = ""
                tbPasswordNuova.Text = ""
                tbPasswordConferma.Text = ""
            End Using

        Catch
            ShowPasswordMessage("Non e stato possibile aggiornare la password. Riprova piu tardi.", False)
        End Try
    End Sub

    Private Sub ClearPasswordMessage()
        lblMessaggio.Text = ""
        lblMessaggio.CssClass = "d-none"
    End Sub

    Private Sub ShowPasswordMessage(ByVal message As String, ByVal success As Boolean)
        lblMessaggio.Text = message
        lblMessaggio.ForeColor = If(success, Drawing.Color.Green, Drawing.Color.Red)
        lblMessaggio.CssClass = If(success, "alert alert-success d-block", "alert alert-danger d-block")
    End Sub

    Private Function TryGetLoginId(ByRef loginIdValue As Integer) As Boolean
        loginIdValue = 0
        If Session("LoginId") Is Nothing Then
            Return False
        End If

        If Not Integer.TryParse(Convert.ToString(Session("LoginId")), loginIdValue) Then
            Return False
        End If

        Return loginIdValue > 0
    End Function

    Private Function GetCurrentPassword(ByVal conn As MySqlConnection, ByVal loginIdValue As Integer) As String
        Using cmd As New MySqlCommand("SELECT Password FROM login WHERE id = @id LIMIT 1", conn)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@id", loginIdValue)

            Dim result As Object = cmd.ExecuteScalar()
            If result Is Nothing OrElse Convert.IsDBNull(result) Then
                Return ""
            End If

            Return Convert.ToString(result)
        End Using
    End Function

    Private Function ValidatePasswordChange(ByVal oldPwd As String,
                                            ByVal newPwd As String,
                                            ByVal newPwd2 As String,
                                            ByVal currentPassword As String,
                                            ByRef validationMessage As String) As Boolean

        validationMessage = ""

        If String.IsNullOrWhiteSpace(oldPwd) OrElse
           String.IsNullOrWhiteSpace(newPwd) OrElse
           String.IsNullOrWhiteSpace(newPwd2) Then

            validationMessage = "Compila tutti i campi."
            Return False
        End If

        If String.IsNullOrEmpty(currentPassword) Then
            validationMessage = "Impossibile verificare la password attuale."
            Return False
        End If

        If Not String.Equals(currentPassword, oldPwd, StringComparison.Ordinal) Then
            validationMessage = "La password attuale non e corretta."
            Return False
        End If

        If newPwd.Length < MinPasswordLength Then
            validationMessage = "La nuova password deve avere almeno " & MinPasswordLength.ToString() & " caratteri."
            Return False
        End If

        If newPwd.Length > MaxPasswordLength Then
            validationMessage = "La nuova password non puo superare " & MaxPasswordLength.ToString() & " caratteri."
            Return False
        End If

        If Not String.Equals(newPwd, newPwd2, StringComparison.Ordinal) Then
            validationMessage = "Le nuove password non coincidono."
            Return False
        End If

        If String.Equals(currentPassword, newPwd, StringComparison.Ordinal) Then
            validationMessage = "La nuova password deve essere diversa da quella attuale."
            Return False
        End If

        Return True
    End Function

    Private Function UpdatePassword(ByVal conn As MySqlConnection,
                                    ByVal loginIdValue As Integer,
                                    ByVal currentPassword As String,
                                    ByVal newPwd As String,
                                    ByVal confirmPwd As String) As Boolean

        Const sql As String = "UPDATE login " &
                              "SET Password = @newpwd, DataPassword = @dataPassword " &
                              "WHERE id = @id " &
                              "AND BINARY Password = BINARY @currentpwd " &
                              "AND BINARY @newpwd = BINARY @confirmpwd " &
                              "AND CHAR_LENGTH(@newpwd) BETWEEN @minLen AND @maxLen " &
                              "AND BINARY @newpwd <> BINARY @currentpwd"

        Using cmd As New MySqlCommand(sql, conn)
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@newpwd", newPwd)
            cmd.Parameters.AddWithValue("@dataPassword", DateTime.Today)
            cmd.Parameters.AddWithValue("@id", loginIdValue)
            cmd.Parameters.AddWithValue("@currentpwd", currentPassword)
            cmd.Parameters.AddWithValue("@confirmpwd", confirmPwd)
            cmd.Parameters.AddWithValue("@minLen", MinPasswordLength)
            cmd.Parameters.AddWithValue("@maxLen", MaxPasswordLength)

            Return cmd.ExecuteNonQuery() > 0
        End Using
    End Function
End Class
