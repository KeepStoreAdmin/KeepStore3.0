Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class Login
    Inherits System.Web.UI.Page

    Private Const LimitRequestItemKey As String = "KeepStore:AuthAttemptLimit:LoginRequest"
    Private Const GenericLoginFailureMessage As String = "Accesso non riuscito. Verifica le credenziali o contatta il supporto."
    Private Const SessionExpiredMessage As String = "La sessione e' scaduta per inattivita. Accedi di nuovo per continuare dal carrello."

    Private Function EnsureLoginPostOrigin() As Boolean
        Dim masterPage As PageMaster = TryCast(Me.Master, PageMaster)
        If masterPage Is Nothing Then
            PageMaster.RejectLoginPost(Context, 403)
            Return False
        End If
        Return masterPage.EnsureLoginPostOrigin()
    End Function

    Protected Sub Page_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Init
        ' Master Init has already resolved the storefront. Reject POST before Page_Load can consume return context.
        If String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then EnsureLoginPostOrigin()
        ' AUTH-LOGIN-SESSION-RENEW-1A: dopo l'accesso con password il sito cambia sessione e rinvia qui (GET login.aspx?k=1). Il biglietto monouso
        ' si consuma DOPO l'Init della master (che ha gia stabilito il negozio della sessione nuova: una identita scritta prima verrebbe revocata):
        ' si scrive solo l'identita; Page_Load completa e rinvia alla destinazione, dove la rivalidazione della master idrata il resto.
        Try
            If KeepStoreSignInSessionRenew.IsRenewRequest(Context) Then
                Dim ticket As SignInTicket = Nothing
                If KeepStoreSignInSessionRenew.TryConsume(Context, ticket) Then KeepStoreSignInSessionRenew.ApplyIdentity(Context, ticket)
            End If
        Catch ex As Exception
            KeepStoreLog.Error("login-session-renew", "Sign-in ticket consumption failed closed. Error type: " & ex.GetType().Name & ".", Nothing, HttpContext.Current)
        End Try
    End Sub

    Protected Overrides Sub Render(ByVal writer As System.Web.UI.HtmlTextWriter)
        If PageMaster.RenderRejectedLoginPost(Context, writer) Then Return
        MyBase.Render(writer)
    End Sub

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
        LoginAccessAuditRecorder.ClearAuthenticationMarker(HttpContext.Current)
        Session.Remove("LoginId")
        Session.Remove("LoginID")
        Session.Remove("LoginEmail")
        Session.Remove("LoginNomeCognome")
        Session.Remove("LoginUltimoAccesso")
        Session.Remove("UtentiId")
        Session.Remove("UtentiID")
        Session.Remove("UtentiTipoId")
        Session.Remove("AuthenticatedAziendaID")
        Dim masterPage As PageMaster = TryCast(Me.Master, PageMaster)
        If masterPage Is Nothing Then Throw New InvalidOperationException("Storefront login master is unavailable.")
        masterPage.RestoreAnonymousPriceDisplayState()
    End Sub

    '================================================================
    ' PAGE_LOAD
    ' - Se l'utente è già loggato, lo mando in home
    ' - Provo a precompilare solo lo USERNAME dai cookie
    '   (nessuna password salvata in chiaro nei cookie, per ovvi motivi)
    '================================================================
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If PageMaster.IsLoginPostRejected(Context) Then Return
        ' AUTH-STAY-SIGNED-IN-2B: la casella "Resta collegato" esiste solo a funzione accesa (chiave di configurazione e tabella).
        phStaySignedIn.Visible = KeepStoreStaySignedInWeb.IsActive()
        chkStaySignedIn.InputAttributes("aria-describedby") = "ksStaySignedInHint"
        If Not IsPostBack Then

            ' Rinvio dopo l'accesso con password: identita ricostruita nella sessione nuova, valori dell'accesso, poi la destinazione richiesta.
            Dim renewedTicket As SignInTicket = KeepStoreSignInSessionRenew.ConsumedTicket(Context)
            If renewedTicket IsNot Nothing AndAlso CurrentLoginIdSafe() > 0 Then
                KeepStoreSignInSessionRenew.ApplyExtras(Context, renewedTicket)
                Response.Redirect(ResolveUrl(renewedTicket.Target), False)
                Context.ApplicationInstance.CompleteRequest()
                Return
            End If

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
        If Not EnsureLoginPostOrigin() Then Return
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

          ' AUTH-LOGIN-SESSION-RENEW-1A: se il rinnovo della sessione e attivo e non si completa, la sessione vecchia non resta collegata.
          Dim renewalFinished As Boolean = False
          Try

            ' Registra l'accesso riuscito prima delle operazioni accessorie.
            LoginAccessAuditRecorder.TryRecordSuccessfulLogin(HttpContext.Current, CurrentLoginIdSafe())

            ' "Resta collegato": il dispositivo gia ricordato da questo browser si annulla sempre; con la casella se ne ricorda uno nuovo.
            KeepStoreStaySignedInWeb.AfterSignIn(HttpContext.Current,
                StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AuthenticatedAziendaID")), CurrentLoginIdSafe(),
                phStaySignedIn.Visible AndAlso chkStaySignedIn.Checked)

            ' Sincronizza il carrello separatamente: un errore non annulla l'audit o il login.
            Try
                Dim masterPage As PageMaster = TryCast(Me.Master, PageMaster)
                If masterPage IsNot Nothing Then
                    masterPage.AggiornaDati()
                Else
                    KeepStoreLog.Error("login-cart-sync", "Post-login cart synchronization master was unavailable.", Nothing, HttpContext.Current)
                End If
            Catch ex As Exception
                KeepStoreLog.Error(
                    "login-cart-sync",
                    "Post-login cart synchronization failed. Error type: " & ex.GetType().Name & ".",
                    Nothing,
                    HttpContext.Current)
            End Try

            ' Decido dove reindirizzare senza tornare su pagine tecniche.
            Dim targetUrl As String = ResolveAndConsumePostLoginTarget()

            ' Identificativo di sessione nuovo (contro la fissazione): il biglietto porta l'identita verificata alla sessione nuova.
            Dim renewal As SignInRenewOutcome = KeepStoreSignInSessionRenew.TryRenewAfterSignIn(
                HttpContext.Current, CurrentLoginIdSafe(),
                StorefrontCommercialIsolationPolicy.PositiveInteger(Session("UtentiId")), targetUrl)
            If renewal = SignInRenewOutcome.Renewed Then
                renewalFinished = True
                Response.Redirect(KeepStoreSignInSessionRenew.RenewRedirectUrl(ResolveUrl("~/login.aspx")), False)
                Context.ApplicationInstance.CompleteRequest()
                Return
            End If
            If renewal = SignInRenewOutcome.NotSupported Then
                renewalFinished = True
                Response.Redirect(targetUrl, False)
                Context.ApplicationInstance.CompleteRequest()
                Return
            End If
            ' Failed: si esce dal blocco senza completare; il Finally toglie l'identita e abbandona la sessione.
          Finally
            If Not renewalFinished AndAlso KeepStoreSignInSessionRenew.IsSupported(HttpContext.Current) Then FailSignInRenewalClosed()
          End Try
            lblLogin.Text = GenericLoginFailureMessage
            Return
        End If

        ' Se EseguiLogin restituisce False, lblLogin contiene già il messaggio
        If String.IsNullOrWhiteSpace(lblLogin.Text) Then
            lblLogin.Text = GenericLoginFailureMessage
        End If
    End Sub

    ' Fallimento chiuso del rinnovo: nessuna identita resta nella sessione vecchia e la sessione viene abbandonata.
    Private Sub FailSignInRenewalClosed()
        Try
            ClearInvalidLoginSession()
        Catch
        End Try
        Try
            Session.Abandon()
        Catch
        End Try
    End Sub

    '================================================================
    ' LOGICA DI LOGIN (DB)
    '================================================================
    Private Function EseguiLogin(ByVal user As String, ByVal pass As String) As Boolean
        If Not EnsureLoginPostOrigin() Then Return False

        lblLogin.Text = ""

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        ' AUTH-ATTEMPT-LIMIT-1A: esito del tentativo prenotato, registrato in ogni uscita (successo azzera, ogni altra uscita e un errore).
        Dim limitReserved As Boolean = False
        Dim limitPasswordOk As Boolean = False
        Dim limitScope As Integer = 0
        Dim limitKeyText As String = String.Empty
        Dim limitCompany As Integer = 0
        Try
            Using conn As New MySqlConnection(connString)
                conn.Open()

                Using cmd As New MySqlCommand()
                    cmd.Connection = conn
                    cmd.CommandType = CommandType.Text

                    ' Il login e' sempre vincolato allo storefront risolto server-side.
                    Dim aziendaId As Integer = 0
                    Integer.TryParse(Convert.ToString(Session("AziendaID")), aziendaId)
                    If aziendaId <= 0 Then
                        ClearInvalidLoginSession()
                        lblLogin.Text = GenericLoginFailureMessage
                        Return False
                    End If
                    cmd.CommandText = "SELECT * FROM vlogin WHERE AziendeID=?aziendaId AND UPPER(Username) = ?username LIMIT 0, 1"
                    cmd.Parameters.AddWithValue("?aziendaId", aziendaId)
                    cmd.Parameters.AddWithValue("?username", user.ToUpper())

                    Using dr As MySqlDataReader = cmd.ExecuteReader()

                        ' AUTH-ATTEMPT-LIMIT-1A: il tentativo si prenota PRIMA di ogni confronto di password. Chiave: il LoginId trovato, oppure il nome digitato se l'accesso non esiste.
                        Dim rowFound As Boolean = dr.Read()
                        limitScope = If(rowFound, KeepStoreAuthAttemptLimit.ScopeLogin, KeepStoreAuthAttemptLimit.ScopeUnknownUser)
                        limitKeyText = If(rowFound, KeepStoreAuthAttemptLimitWeb.LoginKey(Convert.ToInt32(dr.Item("id"))), KeepStoreAuthAttemptLimit.NormalizeUnknownName(user))
                        limitCompany = aziendaId
                        ' Il pulsante e collegato due volte (OnClick nella pagina e Handles nel codice): il gestore gira due volte per clic. Il tentativo si conta UNA volta
                        ' per richiesta; la seconda chiamata confronta la stessa password gia contata e, se la prima era bloccata, resta bloccata.
                        Dim limitMarker As Object = HttpContext.Current.Items(LimitRequestItemKey)
                        Dim limitDecision As AttemptLimitDecision
                        If limitMarker Is Nothing Then
                            limitDecision = KeepStoreAuthAttemptLimitWeb.Reserve(HttpContext.Current, limitCompany, limitScope, limitKeyText)
                            HttpContext.Current.Items(LimitRequestItemKey) = If(limitDecision = AttemptLimitDecision.Blocked, "blocked", "counted")
                        ElseIf String.Equals(Convert.ToString(limitMarker), "blocked", StringComparison.Ordinal) Then
                            limitDecision = AttemptLimitDecision.Blocked
                        Else
                            limitDecision = AttemptLimitDecision.Inactive
                        End If
                        If limitDecision = AttemptLimitDecision.Blocked Then
                            lblLogin.Text = KeepStoreAuthAttemptLimitWeb.BlockedMessage
                            Return False
                        End If
                        limitReserved = (limitDecision = AttemptLimitDecision.Allowed)

                        If Not rowFound Then
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

                        Dim accountCompanyId As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(dr.Item("AziendeID"))
                        Dim persistedPriceListId As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(dr.Item("listino"))
                        Dim authenticatedPriceListId As Integer = StorefrontCommercialIsolationPolicy.ResolveAuthenticatedPriceList(
                            aziendaId,
                            accountCompanyId,
                            persistedPriceListId)
                        If authenticatedPriceListId <= 0 Then
                            ClearInvalidLoginSession()
                            lblLogin.Text = GenericLoginFailureMessage
                            Return False
                        End If

                        ' Controllo password (case-insensitive, come in origine)
                        Dim dbPass As String = dr.Item("Password").ToString()
                        If dbPass.ToLower() <> pass.ToLower() Then
                            lblLogin.Text = GenericLoginFailureMessage
                            Return False
                        End If
                        limitPasswordOk = True

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
                        Session("AuthenticatedAziendaID") = accountCompanyId

                        'Indica se l'utente può o meno creare l'html per le promo mailing
                        Session("genera_html_mail") = dr.Item("genera_html_mail")

                        Session("Listino") = authenticatedPriceListId
                        Session("listino") = authenticatedPriceListId
                        Dim masterPage As PageMaster = TryCast(Me.Master, PageMaster)
                        If masterPage Is Nothing Then Throw New InvalidOperationException("Storefront login master is unavailable.")
                        masterPage.ApplyAuthenticatedPriceDisplayState(dr.Item("IvaTipo"), dr.Item("IdEsenzioneIva"),
                            dr.Item("ValoreEsenzioneIva"), dr.Item("DescrizioneEsenzioneIva"), dr.Item("AbilitatoIvaReverseCharge"))
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

        Finally
            If limitReserved Then
                If limitPasswordOk Then
                    KeepStoreAuthAttemptLimitWeb.Succeed(HttpContext.Current, limitCompany, limitScope, limitKeyText)
                Else
                    KeepStoreAuthAttemptLimitWeb.Fail(HttpContext.Current, limitCompany, limitScope, limitKeyText)
                End If
            End If
        End Try

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
