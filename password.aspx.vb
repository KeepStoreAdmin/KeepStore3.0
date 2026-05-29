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
            lblMessaggio.Text = ""
        End If
    End Sub

    Protected Sub btnSalva_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnSalva.Click
        lblMessaggio.ForeColor = Drawing.Color.Red
        lblMessaggio.Text = ""

        If Not Page.IsValid Then
            Exit Sub
        End If

        Dim oldPwd As String = Convert.ToString(tbPasswordAttuale.Text)
        Dim newPwd As String = Convert.ToString(tbPasswordNuova.Text)
        Dim newPwd2 As String = Convert.ToString(tbPasswordConferma.Text)

        If String.IsNullOrWhiteSpace(oldPwd) OrElse
           String.IsNullOrWhiteSpace(newPwd) OrElse
           String.IsNullOrWhiteSpace(newPwd2) Then

            lblMessaggio.Text = "Compila tutti i campi."
            Exit Sub
        End If

        If newPwd.Length < MinPasswordLength Then
            lblMessaggio.Text = "La nuova password deve avere almeno " & MinPasswordLength.ToString() & " caratteri."
            Exit Sub
        End If

        If newPwd.Length > MaxPasswordLength Then
            lblMessaggio.Text = "La nuova password non puo superare " & MaxPasswordLength.ToString() & " caratteri."
            Exit Sub
        End If

        If newPwd <> newPwd2 Then
            lblMessaggio.Text = "Le nuove password non coincidono."
            Exit Sub
        End If

        If String.Equals(oldPwd, newPwd, StringComparison.Ordinal) Then
            lblMessaggio.Text = "La nuova password deve essere diversa da quella attuale."
            Exit Sub
        End If

        Dim loginIdValue As Integer = 0
        If Session("LoginId") Is Nothing OrElse
           Not Integer.TryParse(Convert.ToString(Session("LoginId")), loginIdValue) OrElse
           loginIdValue <= 0 Then

            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Try
            Using conn As New MySqlConnection(connString)
                conn.Open()

                Using cmd As New MySqlCommand()
                    cmd.Connection = conn
                    cmd.CommandType = CommandType.Text

                    cmd.CommandText = "SELECT Password FROM login WHERE id = @id LIMIT 1"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@id", loginIdValue)

                    Dim dbPwd As String = Nothing
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            dbPwd = Convert.ToString(dr("Password"))
                        End If
                    End Using

                    If String.IsNullOrEmpty(dbPwd) Then
                        lblMessaggio.Text = "Impossibile verificare la password attuale."
                        Exit Sub
                    End If

                    If Not String.Equals(dbPwd, oldPwd, StringComparison.Ordinal) Then
                        lblMessaggio.Text = "La password attuale non e corretta."
                        Exit Sub
                    End If

                    cmd.CommandText = "UPDATE login SET Password = @newpwd, DataPassword = @dataPassword WHERE id = @id"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@newpwd", newPwd)
                    cmd.Parameters.AddWithValue("@dataPassword", DateTime.Today)
                    cmd.Parameters.AddWithValue("@id", loginIdValue)

                    Dim rows As Integer = cmd.ExecuteNonQuery()

                    If rows > 0 Then
                        lblMessaggio.ForeColor = Drawing.Color.Green
                        lblMessaggio.Text = "Password aggiornata correttamente."
                        Session("DataPassword") = DateTime.Today
                        tbPasswordAttuale.Text = ""
                        tbPasswordNuova.Text = ""
                        tbPasswordConferma.Text = ""
                    Else
                        lblMessaggio.Text = "Nessuna modifica eseguita."
                    End If
                End Using
            End Using

        Catch ex As Exception
            lblMessaggio.Text = "Errore tecnico durante l'aggiornamento della password."
        End Try
    End Sub
End Class
