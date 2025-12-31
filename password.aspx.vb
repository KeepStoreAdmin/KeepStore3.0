Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class password
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Pagina riservata: se non sei loggato, vai a accessonegato.aspx
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

        ' Rispetta i validator
        If Not Page.IsValid Then
            Exit Sub
        End If

        Dim oldPwd As String = tbPasswordAttuale.Text
        Dim newPwd As String = tbPasswordNuova.Text
        Dim newPwd2 As String = tbPasswordConferma.Text

        If String.IsNullOrWhiteSpace(oldPwd) OrElse
           String.IsNullOrWhiteSpace(newPwd) OrElse
           String.IsNullOrWhiteSpace(newPwd2) Then

            lblMessaggio.Text = "Compila tutti i campi."
            Exit Sub
        End If

        If newPwd.Length < 4 Then
            lblMessaggio.Text = "La nuova password deve avere almeno 4 caratteri."
            Exit Sub
        End If

        If newPwd <> newPwd2 Then
            lblMessaggio.Text = "Le nuove password non coincidono."
            Exit Sub
        End If

        Dim loginId As Object = Session("LoginId")
        If loginId Is Nothing Then
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

                    ' 1) Controllo che la password attuale sia corretta
                    cmd.CommandText = "SELECT Password FROM vlogin WHERE id = ?id LIMIT 0,1"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("?id", CInt(loginId))

                    Dim dbPwd As String = Nothing
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            dbPwd = dr("Password").ToString()
                        End If
                    End Using

                    If String.IsNullOrEmpty(dbPwd) Then
                        lblMessaggio.Text = "Impossibile verificare la password attuale."
                        Exit Sub
                    End If

                    ' Stesso criterio del login: confronto case-insensitive
                    If dbPwd.ToLower() <> oldPwd.ToLower() Then
                        lblMessaggio.Text = "La password attuale non è corretta."
                        Exit Sub
                    End If

                    ' 2) Aggiorno la password (aggiornando la vista vlogin, se updatabile)
                    cmd.CommandText = "UPDATE vlogin SET Password = ?newpwd WHERE id = ?id"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("?newpwd", newPwd)
                    cmd.Parameters.AddWithValue("?id", CInt(loginId))

                    Dim rows As Integer = cmd.ExecuteNonQuery()

                    If rows > 0 Then
                        lblMessaggio.ForeColor = Drawing.Color.Green
                        lblMessaggio.Text = "Password aggiornata correttamente."
                        ' facoltativo: aggiorna anche in sessione una data password, se la usi
                        ' Session("DataPassword") = DateTime.Now
                    Else
                        lblMessaggio.Text = "Nessuna modifica eseguita."
                    End If
                End Using
            End Using

        Catch ex As Exception
            ' In ambiente di produzione meglio loggare l'errore
            lblMessaggio.Text = "Errore tecnico durante l'aggiornamento della password."
        End Try

    End Sub

End Class
