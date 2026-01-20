Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class cambiapassword
    Inherits System.Web.UI.Page

    Private ReadOnly Property ConnString As String
        Get
            Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Pagina riservata: se non sei loggato, vai a accessonegato.aspx
        If Session("LoginId") Is Nothing Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        If Not Page.IsPostBack Then
            ' Header informativo
            Try
                lblSito.Text = Convert.ToString(Session("AziendaNome"))
            Catch
                lblSito.Text = ""
            End Try

            Try
                lblMesi.Text = Convert.ToString(Session("ScadenzaPassword"))
            Catch
                lblMesi.Text = ""
            End Try

            ' Precarico dati login (senza esporre password al client)
            LoadLoginData()

            ' Stato pannelli
            tRegistrazione.Visible = True
            tAggiorna.Visible = False
        End If

    End Sub

    Private Sub LoadLoginData()
        Dim loginId As Integer = KeepStoreSecurity.ParseInt(Session("LoginId"), 0)
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        Try
            Using conn As New MySqlConnection(ConnString)
                conn.Open()

                Using cmd As New MySqlCommand("SELECT Username, Email FROM vlogin WHERE id = ?id LIMIT 0,1", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("?id", loginId)

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            Try
                                tbUsername.Text = Convert.ToString(dr("Username"))
                            Catch
                                tbUsername.Text = ""
                            End Try

                            Try
                                tbEmail.Text = Convert.ToString(dr("Email"))
                            Catch
                                tbEmail.Text = ""
                            End Try
                        End If
                    End Using
                End Using
            End Using
        Catch
            ' In produzione: eventuale logging
        End Try
    End Sub

    Protected Sub cvOldPassword_ServerValidate(ByVal source As Object, ByVal args As ServerValidateEventArgs)
        ' Valida la password vecchia lato server (evita compare con textbox nascosta)
        args.IsValid = False

        Dim loginId As Integer = KeepStoreSecurity.ParseInt(Session("LoginId"), 0)
        If loginId <= 0 Then
            Return
        End If

        Dim oldPwd As String = Convert.ToString(args.Value)
        If String.IsNullOrWhiteSpace(oldPwd) Then
            Return
        End If

        Try
            Using conn As New MySqlConnection(ConnString)
                conn.Open()

                Using cmd As New MySqlCommand("SELECT Password FROM vlogin WHERE id = ?id LIMIT 0,1", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("?id", loginId)

                    Dim dbPwd As String = Nothing
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            dbPwd = Convert.ToString(dr("Password"))
                        End If
                    End Using

                    If Not String.IsNullOrEmpty(dbPwd) Then
                        ' stesso criterio del login: confronto case-insensitive
                        If dbPwd.Trim().ToLower() = oldPwd.Trim().ToLower() Then
                            args.IsValid = True
                        End If
                    End If
                End Using
            End Using
        Catch
            ' In caso di errore tecnico, non faccio passare la validazione
            args.IsValid = False
        End Try
    End Sub

    Protected Sub btRegistrati_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btRegistrati.Click
        ' Rispetta i validator
        If Not Page.IsValid Then
            Exit Sub
        End If

        Dim loginId As Integer = KeepStoreSecurity.ParseInt(Session("LoginId"), 0)
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        Dim newPwd As String = tbPasswordNuova.Text
        Dim newPwd2 As String = tbPasswordConferma.Text

        If String.IsNullOrWhiteSpace(newPwd) OrElse String.IsNullOrWhiteSpace(newPwd2) Then
            Exit Sub
        End If

        If newPwd <> newPwd2 Then
            Exit Sub
        End If

        Try
            Using conn As New MySqlConnection(ConnString)
                conn.Open()

                Using cmd As New MySqlCommand("UPDATE vlogin SET Password = ?pwd, DataPassword = ?dp WHERE id = ?id", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("?pwd", newPwd)
                    cmd.Parameters.AddWithValue("?dp", DateTime.Today)
                    cmd.Parameters.AddWithValue("?id", loginId)

                    Dim rows As Integer = cmd.ExecuteNonQuery()

                    If rows > 0 Then
                        ' aggiorno sessione usata dal master per la scadenza
                        Session("DataPassword") = DateTime.Today

                        tRegistrazione.Visible = False
                        tAggiorna.Visible = True

                        ' pulizia campi
                        tbPasswordVecchia.Text = ""
                        tbPasswordNuova.Text = ""
                        tbPasswordConferma.Text = ""
                    End If
                End Using
            End Using
        Catch
            ' Fallback: la pagina resta visibile con i validator; non crasho.
        End Try

    End Sub

End Class
