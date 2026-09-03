Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class Login
    Inherits System.Web.UI.Page

    Private Const GenericLoginFailureMessage As String = "Accesso non riuscito. Verifica le credenziali o contatta il supporto."
    Private Const SessionExpiredMessage As String = "La sessione e' scaduta per inattivita. Accedi di nuovo per continuare dal carrello."

    Private Function ResolveAndConsumePostLoginTarget() As String
        Dim target As String = PostLoginReturnUrlPolicy.ResolvePostLoginTarget(
            HttpContext.Current,
            Request.QueryString("ReturnUrl"),
            Session("Page"),
            Session("Pagina_visitata"))

        PostLoginReturnUrlPolicy.ClearRememberedContext(HttpContext.Current)
        Session.Remove("Page")
        Session.Remove("Pagina_visitata")
        Return target
    End Function

    Private Function CurrentLoginIdSafe() As Integer
        Dim loginId As Integer = 0
        Try
            Integer.TryParse(Convert.ToString(Session("LoginId")), loginId)
            If loginId <= 0 Then
                Integer.TryParse(Convert.ToString(Session("LoginID")), loginId)
            End If
        Catch
            loginId = 0
        End Try
        Return loginId
    End Function

    Private Sub ClearInvalidLoginSession()
        Session.Remove("LoginId")
        Session.Remove("LoginID")
        Session.Remove("LoginEmail")
        Session.Remove("LoginNomeCognome")
        Session.Remove("LoginUltimoAccesso")
        Session.Remove("UtentiId")
        Session.Remove("UtentiID")
        Session.Remove("UtentiTipoId")
    End Sub

    '================================================================
    ' PAGE_LOAD
    ' - Se l'utente è già loggato, lo mando in home
    ' - Provo a precompilare solo lo USERNAME dai cookie
    '   (nessuna password salvata in chiaro nei cookie, per ovvi motivi)
    '================================================================
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not IsPostBack Then

            ' Se è già loggato, non ha senso stare sulla pagina di login
            If CurrentLoginIdSafe() > 0 Then
                Response.Redirect(ResolveAndConsumePostLoginTarget(), False)
                Context.ApplicationInstance.CompleteRequest()
                Return
            Else
                ClearInvalidLoginSession()
            End If

            If String.Equals(Convert.ToString(Request.QueryString("sessionExpired")), "1", StringComparison.OrdinalIgnoreCase) Then
                lblLogin.Text = SessionExpiredMessage
            End If

            ' Prefill da cookie (solo username, se presente)
            Try
                If Session("AziendaNome") IsNot Nothing Then
                    Dim cookieName As String = Session("AziendaNome").ToString()
                    Dim userCookie As HttpCookie = Request.Cookies(cookieName)

                    If userCookie IsNot Nothing AndAlso userCookie("Username") IsNot Nothing Then
                        tbUsername.Text = userCookie("Username")
                    End If
                End If
            Catch
                ' Se qualcosa va storto coi cookie, pazienza.
            End Try

        End If
    End Sub

    '================================================================
    ' CLICK DEL BOTTONE DI LOGIN
    '================================================================
    Protected Sub btnLogin_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnLogin.Click
        ' Rispetto i RequiredFieldValidator
        If Not Page.IsValid Then
            Exit Sub
        End If

        lblLogin.Text = ""

        Dim user As String = tbUsername.Text.Trim()
        Dim pass As String = tbPassword.Text

        If user = "" OrElse pass = "" Then
            lblLogin.Text = GenericLoginFailureMessage
            Exit Sub
        End If

        ' Eseguo il login "vero"
        Dim ok As Boolean = EseguiLogin(user, pass)

        ' Se il login è andato a buon fine, Session("LoginId") è valorizzata
        If ok AndAlso CurrentLoginIdSafe() > 0 Then

            ' Chiamo AggiornaDati della master (aggiorna carrello, prezzi, ecc.)
            Try
                Dim masterObj As Object = Me.Master
                If masterObj IsNot Nothing Then
                    masterObj.AggiornaDati()
                End If
            Catch
                ' Se per qualche motivo fallisce, non blocchiamo il login
            End Try

            ' Decido dove reindirizzare senza tornare su pagine tecniche.
            Dim targetUrl As String = ResolveAndConsumePostLoginTarget()

            Response.Redirect(targetUrl, False)
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        ' Se EseguiLogin restituisce False, lblLogin contiene già il messaggio
        If String.IsNullOrWhiteSpace(lblLogin.Text) Then
            lblLogin.Text = GenericLoginFailureMessage
        End If
    End Sub

    '================================================================
    ' LOGICA DI LOGIN (DB)
    '================================================================
    Private Function EseguiLogin(ByVal user As String, ByVal pass As String) As Boolean

        lblLogin.Text = ""

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text

                ' Query parametrizzata su vlogin (no concatenazioni stringa).
                ' Se l'azienda Ã¨ giÃ  in sessione, filtro come nel flusso storico della master.
                Dim aziendaId As Integer = 0
                Integer.TryParse(Convert.ToString(Session("AziendaID")), aziendaId)
                If aziendaId > 0 Then
                    cmd.CommandText = "SELECT * FROM vlogin WHERE AziendeID=?aziendaId AND UPPER(Username) = ?username LIMIT 0, 1"
                    cmd.Parameters.AddWithValue("?aziendaId", aziendaId)
                Else
                    cmd.CommandText = "SELECT * FROM vlogin WHERE UPPER(Username) = ?username LIMIT 0, 1"
                End If
                cmd.Parameters.AddWithValue("?username", user.ToUpper())

                Using dr As MySqlDataReader = cmd.ExecuteReader()

                    If Not dr.Read() Then
                        lblLogin.Text = GenericLoginFailureMessage
                        Return False
                    End If

                    ' Controlli di abilitazione
                    If dr.Item("Abilitato") <> 1 Then
                        lblLogin.Text = GenericLoginFailureMessage
                        Return False
                    End If

                    If dr.Item("UtentiAbilitato") <> 1 Then
                        lblLogin.Text = GenericLoginFailureMessage
                        Return False
                    End If

                    ' Controllo password (case-insensitive, come in origine)
                    Dim dbPass As String = dr.Item("Password").ToString()
                    If dbPass.ToLower() <> pass.ToLower() Then
                        lblLogin.Text = GenericLoginFailureMessage
                        Return False
                    End If

                    '=======================
                    ' LOGIN OK → set Session
                    '=======================
                    Try
                        Session("AbilitaListino") = CInt(dr.Item("AbilitaListino"))
                    Catch
                        Session("AbilitaListino") = 0
                    End Try

                    Session("LoginId") = dr.Item("id")
                    Session("LoginID") = dr.Item("id")
                    Session("LoginEmail") = dr.Item("email")
                    Session("LoginNomeCognome") = dr.Item("cognomenome")

                    If Not IsDBNull(dr.Item("ultimoaccesso")) Then
                        Session("LoginUltimoAccesso") = dr.Item("ultimoaccesso")
                    End If

                    Session("UtentiId") = dr.Item("utentiid")
                    Session("UtentiID") = dr.Item("utentiid")
                    Session("UtentiTipoId") = dr.Item("utentitipoid")

                    'Indica se l'utente può o meno creare l'html per le promo mailing
                    Session("genera_html_mail") = dr.Item("genera_html_mail")

                    'Iva applicata all'utente Utente - Esenzioni
                    If dr.Item("idEsenzioneIva") <> -1 Then
                        Session("Iva_Utente") = dr.Item("ValoreEsenzioneIva")
                        Session("DescrizioneEsenzioneIva") = dr.Item("DescrizioneEsenzioneIva")
                        Session("IdEsenzioneIva") = dr.Item("IdEsenzioneIva")
                        'Iva da applicare al vettore (da settare nella tabella Aziende)
                        Session("Iva_Vettori") = Session("Iva_Utente")
                    Else
                        Session("IdEsenzioneIva") = -1
                        Session("DescrizioneEsenzioneIva") = ""
                        Session("Iva_Utente") = -1
                    End If

                    'Reverse Charge Utente
                    Session("AbilitatoIvaReverseCharge") = dr.Item("AbilitatoIvaReverseCharge")

                    Session("Listino") = dr.Item("listino")
                    Session("listino") = dr.Item("listino")
                    Session("IvaTipo") = dr.Item("IvaTipo")
                    Session("DataPassword") = dr.Item("DataPassword")
                    Try
                        Session("CanOrder") = dr.Item("CanOrder")
                    Catch
                        Session("CanOrder") = 1
                    End Try
                    Try
                        Session("ScadenzaPassword") = dr.Item("ScadenzaPassword")
                    Catch
                    End Try

                End Using
            End Using
        End Using

        ' Salvo il cookie per lo USERNAME (ma NON la password)
        Try
            If Session("AziendaNome") IsNot Nothing Then
                Dim cookieName As String = Session("AziendaNome").ToString()
                Dim userCookie As HttpCookie = Request.Cookies(cookieName)

                If userCookie Is Nothing Then
                    userCookie = New HttpCookie(cookieName)
                End If

                userCookie("Username") = user
                userCookie.HttpOnly = True
                userCookie.Expires = DateTime.Now.AddYears(1)

                Response.Cookies.Set(userCookie)
            End If
        Catch
            ' Se falliscono i cookie non è la fine del mondo
        End Try

        Return True
    End Function

End Class
