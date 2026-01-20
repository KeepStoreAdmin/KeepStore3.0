Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.IO

Partial Class cambiapassword
    Inherits System.Web.UI.Page

    Private ReadOnly Property ConnString As String
        Get
            Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        lblEsito.Text = ""

        ' Pagina riservata
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

            ' Precarico dati login (senza esporre password)
            LoadLoginData()

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

                ' Tabella fisica: login (vlogin e' una vista)
                Using cmd As New MySqlCommand("SELECT UserName, email FROM login WHERE id = ?id LIMIT 0,1", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("?id", loginId)

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            tbUsername.Text = Convert.ToString(dr("UserName"))
                            tbEmail.Text = Convert.ToString(dr("email"))
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            LogException("LoadLoginData", ex)
        End Try
    End Sub

    Protected Sub cvOldPassword_ServerValidate(ByVal source As Object, ByVal args As ServerValidateEventArgs)
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

                Using cmd As New MySqlCommand("SELECT Password FROM login WHERE id = ?id LIMIT 0,1", conn)
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
                        ' Legacy-compatible: confronto case-insensitive
                        If String.Equals(dbPwd.Trim(), oldPwd.Trim(), StringComparison.OrdinalIgnoreCase) Then
                            args.IsValid = True
                        End If
                    End If
                End Using
            End Using

        Catch ex As Exception
            LogException("cvOldPassword_ServerValidate", ex)
            args.IsValid = False
        End Try
    End Sub

    Protected Sub btRegistrati_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btRegistrati.Click
        lblEsito.Text = ""

        If Not Page.IsValid Then
            Exit Sub
        End If

        Dim loginId As Integer = KeepStoreSecurity.ParseInt(Session("LoginId"), 0)
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        Dim newPwd As String = Convert.ToString(tbPasswordNuova.Text)
        Dim newPwd2 As String = Convert.ToString(tbPasswordConferma.Text)

        If String.IsNullOrWhiteSpace(newPwd) OrElse String.IsNullOrWhiteSpace(newPwd2) Then
            lblEsito.Text = "Inserisci la nuova password e la conferma."
            Exit Sub
        End If

        If newPwd <> newPwd2 Then
            lblEsito.Text = "Le password non coincidono."
            Exit Sub
        End If

        ' Criterio legacy: almeno 8 caratteri, solo lettere/numeri/_ e spazi (nessun carattere speciale)
        ' (coerente con regex [\w\s]{8,} lato ASPX)

        Try
            Using conn As New MySqlConnection(ConnString)
                conn.Open()

                Using cmd As New MySqlCommand("UPDATE login SET Password = ?pwd, DataPassword = ?dp WHERE id = ?id", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("?pwd", newPwd)
                    cmd.Parameters.AddWithValue("?dp", DateTime.Now)
                    cmd.Parameters.AddWithValue("?id", loginId)

                    Dim rows As Integer = cmd.ExecuteNonQuery()

                    If rows > 0 Then
                        Session("DataPassword") = DateTime.Now
                        tRegistrazione.Visible = False
                        tAggiorna.Visible = True

                        tbPasswordVecchia.Text = ""
                        tbPasswordNuova.Text = ""
                        tbPasswordConferma.Text = ""
                    Else
                        lblEsito.Text = "Errore tecnico durante l'aggiornamento della password."
                    End If
                End Using
            End Using

        Catch ex As Exception
            LogException("btRegistrati_Click", ex)
            lblEsito.Text = "Errore tecnico durante l'aggiornamento della password."
        End Try
    End Sub

    Private Sub LogException(ByVal context As String, ByVal ex As Exception)
        Try
            Dim baseDir As String = Server.MapPath("~/App_Data/Logs")
            If Not Directory.Exists(baseDir) Then
                Directory.CreateDirectory(baseDir)
            End If

            Dim path As String = Path.Combine(baseDir, "cambiapassword.log")
            Dim msg As String = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") & " | " & context & " | " & ex.GetType().FullName & " | " & ex.Message & Environment.NewLine & ex.StackTrace & Environment.NewLine & "----" & Environment.NewLine
            File.AppendAllText(path, msg)
        Catch
            ' no-throw
        End Try
    End Sub

End Class
