Imports System
Imports System.Data
Imports System.IO
Imports System.Text
Imports System.Web
Imports System.Configuration
Imports System.Security.Principal
Imports MySql.Data.MySqlClient

Partial Class cambiapassword
    Inherits System.Web.UI.Page

    Private _diag As New StringBuilder()
    Private _diagTech As New StringBuilder()

    Private ReadOnly Property ConnString As String
        Get
            Dim cs As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If cs Is Nothing Then
                Return String.Empty
            End If
            Return cs.ConnectionString
        End Get
    End Property

    Private Enum LogDirMode
        PrimaryAppData = 0
        FallbackTemp = 1
        None = 2
    End Enum

    Private _logDirResolved As String = ""
    Private _logDirMode As LogDirMode = LogDirMode.None

    Private Function CurrentProcessIdentity() As String
        Try
            Dim wi As WindowsIdentity = WindowsIdentity.GetCurrent()
            If wi IsNot Nothing AndAlso Not String.IsNullOrEmpty(wi.Name) Then
                Return wi.Name
            End If
        Catch
        End Try
        Return "(unknown)"
    End Function

    Private Function PrimaryLogFolderPhysical() As String
        Try
            Return Server.MapPath("~/App_Data/Logs")
        Catch
            Return ""
        End Try
    End Function

    Private Function FallbackLogFolderPhysical() As String
        Try
            Return Path.Combine(Path.GetTempPath(), "KeepStoreLogs")
        Catch
            Return ""
        End Try
    End Function

    Private Function TryWriteTest(ByVal dir As String, ByVal fileName As String, ByVal tag As String, ByRef err As Exception) As Boolean
        err = Nothing
        Try
            If String.IsNullOrEmpty(dir) Then Return False
            Directory.CreateDirectory(dir)
            Dim fp As String = Path.Combine(dir, fileName)
            File.AppendAllText(fp, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") & " | " & tag & Environment.NewLine, Encoding.UTF8)
            Return True
        Catch ex As Exception
            err = ex
            Return False
        End Try
    End Function

    Private Function ResolveLogFolder() As String
        If Not String.IsNullOrEmpty(_logDirResolved) AndAlso _logDirMode <> LogDirMode.None Then
            Return _logDirResolved
        End If

        Dim ex1 As Exception = Nothing
        Dim primary As String = PrimaryLogFolderPhysical()
        If TryWriteTest(primary, "log_write_test.txt", "write-test", ex1) Then
            _logDirResolved = primary
            _logDirMode = LogDirMode.PrimaryAppData
            Return _logDirResolved
        End If

        ' Fallback: TEMP (utile su hosting dove App_Data e' readonly per l'identity IIS)
        Dim ex2 As Exception = Nothing
        Dim fallback As String = FallbackLogFolderPhysical()
        If TryWriteTest(fallback, "log_write_test.txt", "write-test", ex2) Then
            _logDirResolved = fallback
            _logDirMode = LogDirMode.FallbackTemp
            Return _logDirResolved
        End If

        ' Nessuna cartella scrivibile
        _logDirResolved = primary
        _logDirMode = LogDirMode.None
        Return _logDirResolved
    End Function

    Private Sub AppendDiag(ByVal msg As String)
        _diag.AppendLine(HttpUtility.HtmlEncode(msg) & "<br/>")
    End Sub

    Private Sub AppendDiagTech(ByVal msg As String)
        _diagTech.AppendLine(msg)
    End Sub

    Private Sub EnsureLogWritable()
        ' Test reale di scrittura log. Se App_Data\Logs non e' scrivibile, tenta fallback TEMP.
        Dim primary As String = PrimaryLogFolderPhysical()
        Dim resolved As String = ResolveLogFolder()

        If _logDirMode = LogDirMode.PrimaryAppData Then
            AppendDiag("Logging: OK (cartella: " & resolved & ")")
        ElseIf _logDirMode = LogDirMode.FallbackTemp Then
            AppendDiag("Logging: OK (fallback TEMP) (cartella: " & resolved & ")")
            AppendDiag("Nota: App_Data\\Logs non e' scrivibile per l'identity IIS. Vedi istruzioni permessi.")
            AppendDiag("Percorso primario (non scrivibile): " & primary)
        Else
            AppendDiag("Logging: ERRORE (primario: " & primary & ")")
            AppendDiag("Fallback TEMP: " & FallbackLogFolderPhysical())
            AppendDiag("Motivo: nessun percorso scrivibile per questa identity.")
        End If
    End Sub

    Private Sub WriteLog(ByVal msg As String)
        Try
            Dim dir As String = ResolveLogFolder()
            If String.IsNullOrEmpty(dir) Then
                AppendDiag("WriteLog fallito: log dir vuota")
                Return
            End If
            Directory.CreateDirectory(dir)
            Dim fp As String = Path.Combine(dir, "cambiapassword.log")
            File.AppendAllText(fp, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") & " | " & msg & Environment.NewLine, Encoding.UTF8)
        Catch ex As Exception
            ' Non blocco il flusso: segnalo in diagnostica.
            AppendDiag("WriteLog fallito: " & ex.GetType().Name & " - " & ex.Message)
            AppendDiagTech(ex.ToString())
        End Try
    End Sub

    Private Function SafeInt(ByVal o As Object, ByVal def As Integer) As Integer
        Try
            If o Is Nothing Then Return def
            Dim s As String = Convert.ToString(o)
            If String.IsNullOrWhiteSpace(s) Then Return def
            Dim n As Integer
            If Integer.TryParse(s, n) Then Return n
        Catch
        End Try
        Return def
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Minimo controllo login
        If Session("LoginId") Is Nothing Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        If Not Page.IsPostBack Then
            litEsito.Text = ""

            ' Diagnostica base (sempre compilata; mostrata solo se necessario)
            AppendDiag("Pagina: cambiapassword.aspx")
            AppendDiag("Ora server: " & DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss"))
            AppendDiag("Identity processo: " & CurrentProcessIdentity())
            Try
                AppendDiag("AppDomain: " & Convert.ToString(HttpRuntime.AppDomainAppId))
            Catch
            End Try
            AppendDiag("LoginId session: " & Convert.ToString(Session("LoginId")))
            AppendDiag("ConnString presente: " & If(String.IsNullOrEmpty(ConnString), "NO", "SI"))

            EnsureLogWritable()
            WriteLog("Page_Load: selftest")

            LoadLoginData()

            ' Se l'utente apre con ?diag=1 mostro i dettagli anche senza errore.
            ShowDiagPanel(False)

            tRegistrazione.Visible = True
            tAggiorna.Visible = False
        End If
    End Sub

    Private Sub LoadLoginData()
        Dim loginId As Integer = SafeInt(Session("LoginId"), 0)
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        Try
            Using conn As New MySqlConnection(ConnString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT UserName, email FROM login WHERE id = @id LIMIT 1", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@id", loginId)

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            tbUsername.Text = Convert.ToString(dr("UserName"))
                            tbEmail.Text = Convert.ToString(dr("email"))
                        End If
                    End Using
                End Using
            End Using

            AppendDiag("LoadLoginData: OK")
            WriteLog("LoadLoginData OK, loginId=" & loginId)

        Catch ex As Exception
            AppendDiag("LoadLoginData: ERRORE")
            AppendDiag("Motivo: " & ex.GetType().Name & " - " & ex.Message)
            AppendDiagTech(ex.ToString())
            WriteLog("LoadLoginData ERROR: " & ex.GetType().Name & " - " & ex.Message)

            ' Mostro diagnostica perche' qui e' chiaro che c'e' un problema DB/connessione.
            ShowDiagPanel(True)
        End Try
    End Sub

    Protected Sub cvOldPassword_ServerValidate(ByVal source As Object, ByVal args As ServerValidateEventArgs)
        args.IsValid = False

        Dim loginId As Integer = SafeInt(Session("LoginId"), 0)
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
                Using cmd As New MySqlCommand("SELECT Password FROM login WHERE id = @id LIMIT 1", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@id", loginId)

                    Dim dbPwd As String = Nothing
                    Dim o As Object = cmd.ExecuteScalar()
                    If o IsNot Nothing Then
                        dbPwd = Convert.ToString(o)
                    End If

                    If Not String.IsNullOrEmpty(dbPwd) Then
                        If dbPwd.Trim().ToLowerInvariant() = oldPwd.Trim().ToLowerInvariant() Then
                            args.IsValid = True
                        End If
                    End If
                End Using
            End Using

        Catch ex As Exception
            ' In caso di problemi DB, fallisco la validazione e preparo diagnostica.
            args.IsValid = False
            AppendDiag("Validazione vecchia password: ERRORE")
            AppendDiag("Motivo: " & ex.GetType().Name & " - " & ex.Message)
            AppendDiagTech(ex.ToString())
            WriteLog("OldPassword validate ERROR: " & ex.GetType().Name & " - " & ex.Message)
            ShowDiagPanel(True)
        End Try

    End Sub

    Protected Sub btRegistrati_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btRegistrati.Click
        litEsito.Text = ""

        ' Se i validator non passano, non procedo.
        If Not Page.IsValid Then
            WriteLog("Update aborted: Page.IsValid=False")
            Exit Sub
        End If

        Dim loginId As Integer = SafeInt(Session("LoginId"), 0)
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        Dim newPwd As String = Convert.ToString(tbPasswordNuova.Text)
        Dim newPwd2 As String = Convert.ToString(tbPasswordConferma.Text)

        If String.IsNullOrWhiteSpace(newPwd) OrElse String.IsNullOrWhiteSpace(newPwd2) Then
            litEsito.Text = "<div class='ks-alert ks-alert-danger'><strong>Errore:</strong> nuova password e conferma sono obbligatorie.</div>"
            Exit Sub
        End If

        If newPwd <> newPwd2 Then
            litEsito.Text = "<div class='ks-alert ks-alert-danger'><strong>Errore:</strong> le password non coincidono.</div>"
            Exit Sub
        End If

        ' Criterio: minimo 8, niente speciali (gia' in validator), ma protezione ulteriore server-side.
        If newPwd.Length < 8 Then
            litEsito.Text = "<div class='ks-alert ks-alert-danger'><strong>Errore:</strong> la nuova password deve avere almeno 8 caratteri.</div>"
            Exit Sub
        End If

        Try
            WriteLog("Update start, loginId=" & loginId)

            Using conn As New MySqlConnection(ConnString)
                conn.Open()

                Using cmd As New MySqlCommand("UPDATE login SET Password = @pwd, DataPassword = @dp WHERE id = @id", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@pwd", newPwd)
                    cmd.Parameters.AddWithValue("@dp", DateTime.Today)
                    cmd.Parameters.AddWithValue("@id", loginId)

                    Dim rows As Integer = cmd.ExecuteNonQuery()

                    AppendDiag("UPDATE login: righe modificate = " & rows)
                    WriteLog("Update rows=" & rows)

                    If rows > 0 Then
                        Session("DataPassword") = DateTime.Today

                        tRegistrazione.Visible = False
                        tAggiorna.Visible = True

                        tbPasswordVecchia.Text = ""
                        tbPasswordNuova.Text = ""
                        tbPasswordConferma.Text = ""

                        litEsito.Text = "<div class='ks-alert ks-alert-success'><strong>OK:</strong> password aggiornata correttamente.</div>"
                    Else
                        litEsito.Text = "<div class='ks-alert ks-alert-danger'><strong>Errore tecnico:</strong> nessuna riga aggiornata. Possibili cause: sessione non valida o utente non trovato.</div>"
                        ShowDiagPanel(True)
                    End If

                End Using
            End Using

        Catch ex As Exception
            ' Messaggio utente + diagnostica
            Dim code As String = "CP-" & DateTime.Now.ToString("yyyyMMddHHmmss")
            litEsito.Text = "<div class='ks-alert ks-alert-danger'><strong>Errore tecnico durante l'aggiornamento della password.</strong><br/>Codice: " & HttpUtility.HtmlEncode(code) & "</div>"

            AppendDiag("Update: ERRORE")
            AppendDiag("Motivo: " & ex.GetType().Name & " - " & ex.Message)
            AppendDiag("Codice errore: " & code)
            AppendDiagTech(ex.ToString())

            WriteLog("Update ERROR " & code & ": " & ex.GetType().Name & " - " & ex.Message)

            ' Se i log non si scrivono, questa sezione lo evidenzia.
            ShowDiagPanel(True)
        End Try

    End Sub

    Private Sub ShowDiagPanel(ByVal force As Boolean)
        ' Mostra la diagnostica se:
        ' - force=True
        ' - oppure querystring diag=1
        Dim show As Boolean = force
        Try
            If String.Equals(Convert.ToString(Request.QueryString("diag")), "1") Then
                show = True
            End If
        Catch
        End Try

        pnlDiag.Visible = show
        If show Then
            litDiag.Text = _diag.ToString()
            litDiagTech.Text = HttpUtility.HtmlEncode(_diagTech.ToString())
        End If
    End Sub

End Class
