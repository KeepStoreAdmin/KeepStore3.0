Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Configuration
Imports System.Web.UI.HtmlControls
Imports System.Text.RegularExpressions
Imports System.Web
Imports System.Text
Imports System.Collections.Generic

Partial Class PageMaster
'==========================================================
' Helper: trova controlli anche quando non sono WithEvents
'==========================================================

    Inherits System.Web.UI.MasterPage
    Implements ISeoMaster

    Private Const GenericLoginFailureMessage As String = "Accesso non riuscito. Verifica le credenziali o contatta il supporto."
    Private Const LoginPostRejectionKey As String = "KeepStore.Login.PostOriginRejected"
    Private Const LoginPostErrorHandlerKey As String = "KeepStore.Login.RejectionErrorHandler"
    Private Const LoginPostRejectionMessage As String = "Richiesta di accesso non consentita."
    Private Const TenantPriceDisplayCompanyKey As String = "KeepStore.PriceDisplay.TenantCompanyId"
    Private Const TenantPriceDisplayListKey As String = "KeepStore.PriceDisplay.TenantPriceListId"
    Private Const TenantPriceDisplayModeKey As String = "KeepStore.PriceDisplay.TenantMode"
    Private Const AuthenticatedScopeRequestKey As String = "KeepStore.Authentication.ValidatedScope"
    Private _storefrontAuthenticationRevoked As Boolean
    Private _priceDisplayCompanyId As Integer
    Private _priceDisplayDefaultListId As Integer
    Private _priceDisplayTenantMode As StorefrontVatDisplayMode
    Private _priceDisplayCarrierVat As Nullable(Of Decimal)

    Public Shared Function IsLoginPostRejected(ByVal context As HttpContext) As Boolean
        Return context IsNot Nothing AndAlso context.Items(LoginPostRejectionKey) IsNot Nothing
    End Function

    Public Shared Sub RejectLoginPost(ByVal context As HttpContext, ByVal status As Integer)
        If context Is Nothing Then Return
        If Not IsLoginPostRejected(context) Then context.Items(LoginPostRejectionKey) = If(status = 405, 405, 403)
        If context.Items(LoginPostErrorHandlerKey) Is Nothing Then
            Dim page As System.Web.UI.Page = TryCast(context.CurrentHandler, System.Web.UI.Page)
            If page IsNot Nothing Then
                AddHandler page.Error, AddressOf HandleRejectedLoginError
                context.Items(LoginPostErrorHandlerKey) = True
            End If
        End If
        Dim response As HttpResponse = context.Response
        response.Clear()
        response.RedirectLocation = Nothing
        response.StatusCode = CInt(context.Items(LoginPostRejectionKey))
        response.TrySkipIisCustomErrors = True
        response.SuppressFormsAuthenticationRedirect = True
        response.ContentType = "text/plain"
        response.ContentEncoding = Encoding.UTF8
        response.Cache.SetCacheability(HttpCacheability.NoCache)
        response.Cache.SetNoStore()
        If response.StatusCode = 405 Then response.AppendHeader("Allow", "POST")
        If context.ApplicationInstance IsNot Nothing Then context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Shared Sub HandleRejectedLoginError(ByVal sender As Object, ByVal e As EventArgs)
        Dim context As HttpContext = HttpContext.Current
        If Not IsLoginPostRejected(context) Then Return
        ' An error during LoadViewState skips Render. Keep an already refused login terminal,
        ' including MAC failures, without changing validation or the ordinary global error path.
        context.Server.ClearError()
        RejectLoginPost(context, CInt(context.Items(LoginPostRejectionKey)))
        context.Response.Write(LoginPostRejectionMessage)
    End Sub

    Public Shared Function RenderRejectedLoginPost(ByVal context As HttpContext, ByVal writer As System.Web.UI.HtmlTextWriter) As Boolean
        If Not IsLoginPostRejected(context) Then Return False
        RejectLoginPost(context, CInt(context.Items(LoginPostRejectionKey)))
        writer.Write(LoginPostRejectionMessage)
        Return True
    End Function

    Protected Overrides Sub Render(ByVal writer As System.Web.UI.HtmlTextWriter)
        If RenderRejectedLoginPost(Context, writer) Then Return
        MyBase.Render(writer)
    End Sub

    Private Shared Function TryParseLoginSource(ByVal raw As String, ByVal originOnly As Boolean, ByRef source As Uri) As Boolean
        source = Nothing
        If String.IsNullOrEmpty(raw) OrElse raw.Length > 8192 Then Return False
        For Each ch As Char In raw
            If Char.IsWhiteSpace(ch) OrElse Char.IsControl(ch) OrElse ch = "\"c Then Return False
        Next
        ' Validate the raw authority before Uri can normalize backslashes, paths or escaped delimiters.
        Dim authority As String = "https?://(?:[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?\.?|\[[0-9A-Fa-f:.]+\])(?::[0-9]{1,5})?"
        Dim pattern As String = "\A" & authority & If(originOnly, "\z", "(?:[/?][^#]*)?\z")
        If Not Regex.IsMatch(raw, pattern, RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant) Then Return False
        If Regex.IsMatch(raw, ",https?://", RegexOptions.IgnoreCase Or RegexOptions.CultureInvariant) Then Return False
        If Not Uri.TryCreate(raw, UriKind.Absolute, source) OrElse source.UserInfo <> String.Empty OrElse source.Fragment <> String.Empty Then Return False
        Return source.Scheme = Uri.UriSchemeHttp OrElse source.Scheme = Uri.UriSchemeHttps
    End Function

    Private Shared Function LoginSourceMatches(ByVal source As Uri, ByVal target As Uri) As Boolean
        Return String.Equals(source.Scheme, target.Scheme, StringComparison.OrdinalIgnoreCase) AndAlso
            String.Equals(source.IdnHost, target.IdnHost, StringComparison.OrdinalIgnoreCase) AndAlso source.Port = target.Port
    End Function

    Public Function EnsureLoginPostOrigin() As Boolean
        If IsLoginPostRejected(Context) Then
            RejectLoginPost(Context, CInt(Context.Items(LoginPostRejectionKey)))
            Return False
        End If
        If Not String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then
            RejectLoginPost(Context, 405)
            Return False
        End If
        ' LeggiAzienda set this field during master Init using the authoritative tenant resolver.
        ' Reuse that successful request state; do not perform a second tenant lookup here.
        Dim target As Uri = Request.Url
        If _priceDisplayCompanyId <= 0 OrElse target Is Nothing OrElse
           (target.Scheme <> Uri.UriSchemeHttp AndAlso target.Scheme <> Uri.UriSchemeHttps) Then
            RejectLoginPost(Context, 403)
            Return False
        End If
        Dim origins As String() = Request.Headers.GetValues("Origin")
        Dim referrers As String() = Request.Headers.GetValues("Referer")
        Dim source As Uri = Nothing
        Dim allowed As Boolean = False
        If origins IsNot Nothing Then
            allowed = origins.Length = 1 AndAlso TryParseLoginSource(origins(0), True, source) AndAlso LoginSourceMatches(source, target)
        ElseIf referrers IsNot Nothing Then
            allowed = referrers.Length = 1 AndAlso TryParseLoginSource(referrers(0), False, source) AndAlso LoginSourceMatches(source, target)
        End If
        If allowed AndAlso referrers IsNot Nothing Then
            allowed = referrers.Length = 1 AndAlso TryParseLoginSource(referrers(0), False, source) AndAlso LoginSourceMatches(source, target)
        End If
        If Not allowed Then RejectLoginPost(Context, 403)
        Return allowed
    End Function
    Private Const CartFeedbackKindKey As String = "ks_cart_feedback_kind"
    Private Const CartFeedbackProductNameKey As String = "ks_cart_feedback_product_name"
    Private Const CartFeedbackArticleIdKey As String = "ks_cart_feedback_article_id"
    Private Const CartFeedbackTcidKey As String = "ks_cart_feedback_tcid"
    Private Const CartFeedbackCountKey As String = "ks_cart_feedback_count"
    Private Const CartFeedbackCreatedUtcKey As String = "ks_cart_feedback_created_utc"

    Private Function CurrentScriptPathLower() As String
        Try
            Return Convert.ToString(Me.Request.ServerVariables("SCRIPT_NAME")).ToLowerInvariant()
        Catch
            Return Convert.ToString(Me.Request.Url.AbsolutePath).ToLowerInvariant()
        End Try
    End Function

    Private Function IsAccountShellEnabledPath(ByVal absolutePath As String) As Boolean
        Dim path As String = Convert.ToString(absolutePath).ToLowerInvariant()

        Return path.EndsWith("/myaccount.aspx") OrElse
               path.EndsWith("/my-account-edit.aspx") OrElse
               path.EndsWith("/my-account-address.aspx") OrElse
               path.EndsWith("/documenti.aspx") OrElse
               path.EndsWith("/wishlist.aspx") OrElse
               path.EndsWith("/password.aspx")
    End Function

    ' PDP-TOOLS-1A: contatto WhatsApp fisso del sito. Si mostra solo se l'azienda dell'host ha un numero valido E la regola del pulsante
    ' attiva nei dati dell'azienda; mai nelle pagine di ordine e pagamento. Ogni errore lascia il pulsante nascosto.
    Private Sub BindWhatsAppContact()
        Try
            If lnkWhatsAppContact Is Nothing Then Return
            If IsCheckoutFlowPath(CurrentScriptPathLower()) Then Return
            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
            If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then Return
            Dim channel As ContactChannel = KeepStoreContactChannels.ForCompany(tenant.CompanyId)
            If channel Is Nothing OrElse Not channel.WidgetEnabled OrElse channel.WhatsAppNumber = "" Then Return
            Dim href As String = KeepStoreShareLinks.WhatsAppChatUrl(channel.WhatsAppNumber, KeepStoreShareLinks.SiteContactMessage(tenant.CanonicalHost))
            If href = "" Then Return
            Dim label As String = If(channel.CallToAction <> "", channel.CallToAction, "Scrivici") & " su WhatsApp"
            lnkWhatsAppContact.NavigateUrl = href
            lnkWhatsAppContact.Attributes("aria-label") = label
            lnkWhatsAppContact.ToolTip = label
            lnkWhatsAppContact.CssClass = "ks-wa-contact" & If(channel.Position = "left", " ks-wa-contact--left", "")
            lnkWhatsAppContact.Visible = True
        Catch
            If lnkWhatsAppContact IsNot Nothing Then lnkWhatsAppContact.Visible = False
        End Try
    End Sub

    Private Shared Function IsCheckoutFlowPath(ByVal absolutePath As String) As Boolean
        Dim path As String = Convert.ToString(absolutePath).ToLowerInvariant()
        Return path.EndsWith("/ordine.aspx") OrElse path.EndsWith("/ordine_coupon.aspx") OrElse path.EndsWith("/pagamento.aspx") OrElse
               path.EndsWith("/bancasella.aspx") OrElse path.Contains("/bancasella/") OrElse path.Contains("/paypal")
    End Function

    Private Function CurrentLoginIdSafe() As Integer
        Dim loginId As Integer = 0
        Try
            Integer.TryParse(Convert.ToString(Me.Session("LoginId")), loginId)
            If loginId <= 0 Then
                Integer.TryParse(Convert.ToString(Me.Session("LoginID")), loginId)
            End If
        Catch
            loginId = 0
        End Try
        Return loginId
    End Function

    Private Sub ClearStorefrontAuthenticationState()
        LoginAccessAuditRecorder.ClearAuthenticationMarker(HttpContext.Current)
        Dim authenticationKeys As String() = {
            "LoginId", "LoginID", "LoginEmail", "LoginNomeCognome", "LoginUltimoAccesso", "Login_User",
            "UtentiId", "UtentiID", "UtentiTipoId", "AuthenticatedAziendaID",
            "AbilitaListino", "genera_html_mail", "Iva_Utente", "DescrizioneEsenzioneIva",
            "IdEsenzioneIva", "AbilitatoIvaReverseCharge", "DataPassword", "IvaTipo", "Iva_Vettori"
        }
        For Each key As String In authenticationKeys
            Me.Session.Remove(key)
        Next
        If HttpContext.Current IsNot Nothing Then
            HttpContext.Current.Items.Remove(AuthenticatedScopeRequestKey)
        End If
        StorefrontPriceDisplayContextProvider.Invalidate(HttpContext.Current)
    End Sub

    Private Sub RequirePriceDisplayTenant()
        If _priceDisplayCompanyId <= 0 OrElse _priceDisplayDefaultListId <= 0 OrElse
           StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AziendaID")) <> _priceDisplayCompanyId Then
            Throw New InvalidOperationException("Validated storefront price display tenant is unavailable.")
        End If
    End Sub

    Private Function TenantCarrierVatDefault() As Decimal
        RequirePriceDisplayTenant()
        If Not _priceDisplayCarrierVat.HasValue Then
            _priceDisplayCarrierVat = Convert.ToDecimal(IvaVettoreDefault(_priceDisplayCompanyId), System.Globalization.CultureInfo.InvariantCulture)
        End If
        Return _priceDisplayCarrierVat.Value
    End Function

    ' Also used by login.aspx: its Load runs after master Init, so clearing a
    ' rejected login must restore browsing defaults now, not on a later GET.
    Public Sub RestoreAnonymousPriceDisplayState()
        RequirePriceDisplayTenant()
        Dim anonymousPriceListId As Integer = StorefrontCommercialIsolationPolicy.ResolveAnonymousPriceList(
            _priceDisplayCompanyId, _priceDisplayDefaultListId)
        Session("Listino") = anonymousPriceListId
        Session("listino") = anonymousPriceListId
        Session("IvaTipo") = CInt(_priceDisplayTenantMode)
        Session("Iva_Utente") = -1D
        Session("IdEsenzioneIva") = -1
        Session("DescrizioneEsenzioneIva") = String.Empty
        Session("AbilitatoIvaReverseCharge") = 0
        Session("Iva_Vettori") = TenantCarrierVatDefault()
        StorefrontPriceDisplayContextProvider.Invalidate(HttpContext.Current)
    End Sub

    Public Sub ApplyAuthenticatedPriceDisplayState(ByVal accountMode As Object,
                                                   ByVal exemptionIdValue As Object,
                                                   ByVal vatOverrideValue As Object,
                                                   ByVal exemptionDescriptionValue As Object,
                                                   ByVal reverseChargeValue As Object)
        RequirePriceDisplayTenant()
        If CurrentLoginIdSafe() <= 0 OrElse
           StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AuthenticatedAziendaID")) <> _priceDisplayCompanyId OrElse
           StorefrontCommercialIsolationPolicy.ResolveSessionPriceList(Session("Listino"), Session("listino")) <= 0 Then
            Throw New InvalidOperationException("Validated storefront account price scope is unavailable.")
        End If
        Dim exemptionId As Integer = StorefrontPriceDisplayContextProvider.NormalizeExemptionId(exemptionIdValue)
        Dim vatOverride As Nullable(Of Decimal) = Nothing
        If exemptionId >= 0 Then vatOverride = StorefrontPriceDisplayContextProvider.NormalizeVatOverride(vatOverrideValue)
        Session("IvaTipo") = CInt(StorefrontPriceDisplayContextProvider.ResolveDisplayMode(accountMode, _priceDisplayTenantMode))
        Session("Iva_Utente") = If(vatOverride.HasValue, vatOverride.GetValueOrDefault(), -1D)
        Session("IdEsenzioneIva") = If(vatOverride.HasValue, exemptionId, -1)
        Session("DescrizioneEsenzioneIva") = If(vatOverride.HasValue, Convert.ToString(exemptionDescriptionValue), String.Empty)
        Session("AbilitatoIvaReverseCharge") = If(StorefrontCommercialIsolationPolicy.PositiveInteger(reverseChargeValue) = 1, 1, 0)
        If vatOverride.HasValue Then
            Session("Iva_Vettori") = vatOverride.Value
        Else
            Session("Iva_Vettori") = TenantCarrierVatDefault()
        End If
        StorefrontPriceDisplayContextProvider.Invalidate(HttpContext.Current)
    End Sub

    Private Function CurrentAuthenticatedScopeKey(ByVal companyId As Integer) As String
        Dim databaseScope As String = StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey()
        If String.IsNullOrEmpty(databaseScope) Then Return String.Empty
        Return databaseScope & ":" & companyId.ToString() & ":" & CurrentLoginIdSafe().ToString() & ":" &
            StorefrontCommercialIsolationPolicy.PositiveInteger(Session("UtentiId")).ToString() & ":" &
            StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AuthenticatedAziendaID")).ToString() & ":" &
            StorefrontCommercialIsolationPolicy.ResolveSessionPriceList(Session("Listino"), Session("listino")).ToString()
    End Function

    Private Sub RejectStorefrontAuthentication()
        _storefrontAuthenticationRevoked = True
        ClearStorefrontAuthenticationState()
        Try
            RestoreAnonymousPriceDisplayState()
        Finally
            ' CompleteRequest alone does not stop WebForms Load/postback events.
            Throw New HttpException(403, "Sessione non valida. Accedi nuovamente.")
        End Try
    End Sub

    Private Sub RejectAuthenticatedRequestWithoutTenant()
        If _storefrontAuthenticationRevoked OrElse CurrentLoginIdSafe() > 0 OrElse
           StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AuthenticatedAziendaID")) > 0 Then
            _storefrontAuthenticationRevoked = True
            ClearStorefrontAuthenticationState()
            Throw New HttpException(421, "Sito non configurato per l'host richiesto.")
        End If
    End Sub

    Private Sub EnsureAuthenticatedStorefrontScope(ByVal companyId As Integer,
                                                   ByVal defaultPriceListId As Integer)
        If _storefrontAuthenticationRevoked Then RejectStorefrontAuthentication()
        Dim loginId As Integer = CurrentLoginIdSafe()
        If loginId <= 0 Then
            If StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AuthenticatedAziendaID")) > 0 Then
                RejectStorefrontAuthentication()
            End If
            ' AUTH-STAY-SIGNED-IN-2B: senza accesso si prova il dispositivo ricordato; se non vale si resta anonimi come sempre.
            If Not TryBeginDeviceRestore(companyId) Then
                ClearStorefrontAuthenticationState()
                RestoreAnonymousPriceDisplayState()
                Return
            End If
            ' Da qui vale la rivalidazione di ogni richiesta collegata, sull'accesso e sull'utente appena verificati.
            loginId = CurrentLoginIdSafe()
        End If

        Dim authenticatedCompanyId As Integer = 0
        Integer.TryParse(Convert.ToString(Me.Session("AuthenticatedAziendaID")), authenticatedCompanyId)
        If authenticatedCompanyId > 0 Then
            If authenticatedCompanyId <> companyId OrElse
               StorefrontCommercialIsolationPolicy.ResolveSessionPriceList(Me.Session("Listino"), Me.Session("listino")) <= 0 Then
                RejectStorefrontAuthentication()
            End If
        End If

        Dim requestScope As String = CurrentAuthenticatedScopeKey(companyId)
        If requestScope <> String.Empty AndAlso HttpContext.Current IsNot Nothing AndAlso
           String.Equals(TryCast(HttpContext.Current.Items(AuthenticatedScopeRequestKey), String), requestScope, StringComparison.Ordinal) Then
            ApplyAuthenticatedPriceDisplayState(Session("IvaTipo"), Session("IdEsenzioneIva"),
                Session("Iva_Utente"), Session("DescrizioneEsenzioneIva"), Session("AbilitatoIvaReverseCharge"))
            Return
        End If

        ' Every authenticated request revalidates the account, including marked
        ' sessions. Only an identical scope may reuse this request's result.
        Dim validationFailedTechnically As Boolean = False
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using authenticationConnection As New MySqlConnection(connectionString)
                authenticationConnection.Open()
                Const sql As String = "SELECT id, AziendeID, listino, utentiid, utentitipoid, IvaTipo, " &
                                      "IdEsenzioneIva, ValoreEsenzioneIva, DescrizioneEsenzioneIva, AbilitatoIvaReverseCharge FROM vlogin " &
                                      "WHERE id=@loginId AND AziendeID=@companyId AND Abilitato=1 AND UtentiAbilitato=1 LIMIT 0, 1"
                Using authenticationCommand As New MySqlCommand(sql, authenticationConnection)
                    authenticationCommand.Parameters.AddWithValue("@loginId", loginId)
                    authenticationCommand.Parameters.AddWithValue("@companyId", companyId)
                    Using reader As MySqlDataReader = authenticationCommand.ExecuteReader()
                        If reader.Read() Then
                            Dim persistedLoginId As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(reader("id"))
                            Dim persistedUserId As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(reader("utentiid"))
                            Dim cachedUserId As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(Session("UtentiId"))
                            Dim persistedPriceListId As Integer = StorefrontCommercialIsolationPolicy.ResolveAuthenticatedPriceList(
                                companyId,
                                Convert.ToInt32(reader("AziendeID")),
                                Convert.ToInt32(reader("listino")))
                            If persistedLoginId = loginId AndAlso persistedUserId > 0 AndAlso persistedPriceListId > 0 AndAlso
                               (cachedUserId = persistedUserId OrElse (authenticatedCompanyId <= 0 AndAlso cachedUserId <= 0)) Then
                                If authenticatedCompanyId <= 0 Then
                                    ' Legacy sessions hydrate only from the verified owner.
                                    Me.Session("AuthenticatedAziendaID") = companyId
                                    Me.Session("UtentiId") = persistedUserId
                                    Me.Session("UtentiID") = persistedUserId
                                    Me.Session("UtentiTipoId") = reader("utentitipoid")
                                End If
                                Me.Session("Listino") = persistedPriceListId
                                Me.Session("listino") = persistedPriceListId
                                ApplyAuthenticatedPriceDisplayState(reader("IvaTipo"), reader("IdEsenzioneIva"),
                                    reader("ValoreEsenzioneIva"), reader("DescrizioneEsenzioneIva"), reader("AbilitatoIvaReverseCharge"))
                                requestScope = CurrentAuthenticatedScopeKey(companyId)
                                If requestScope <> String.Empty AndAlso HttpContext.Current IsNot Nothing Then
                                    HttpContext.Current.Items(AuthenticatedScopeRequestKey) = requestScope
                                End If
                                Return
                            End If
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            validationFailedTechnically = True
            KeepStoreLog.Error("storefront-auth-scope", "Authenticated storefront scope validation failed closed.", Nothing, HttpContext.Current)
        End Try

        ' Un dispositivo ricordato che non supera la rivalidazione non deve bloccare il sito: si resta anonimi, senza errore.
        If _deviceRestoreAccount IsNot Nothing Then
            AbortDeviceRestore(companyId, validationFailedTechnically)
            Return
        End If
        RejectStorefrontAuthentication()
    End Sub

    ' ==========================================================
    ' AUTH-STAY-SIGNED-IN-2B: "Resta collegato" (dispositivo ricordato)
    ' ==========================================================
    Private _deviceRestoreAccount As StaySignedInAccount = Nothing
    Private _deviceRestoreRenewed As Boolean = False

    ' True = in sessione ci sono l'accesso e l'utente verificati dal dispositivo; la rivalidazione che segue decide se valgono.
    Private Function TryBeginDeviceRestore(ByVal companyId As Integer) As Boolean
        _deviceRestoreAccount = Nothing
        _deviceRestoreRenewed = False
        Try
            Dim current As HttpContext = HttpContext.Current
            Dim cookieValue As String = KeepStoreStaySignedInWeb.ReadCookie(current)
            If cookieValue.Length = 0 Then Return False
            Dim scriptPath As String = CurrentScriptPathLower()
            Dim hasHop As Boolean = KeepStoreStaySignedInWeb.HasHopCookie(current)
            Dim restoreStep As StaySignedInRestoreStep = KeepStoreStaySignedIn.DecideRestoreStep(
                KeepStoreStaySignedInWeb.IsEnabled(), Request.HttpMethod, scriptPath, IsCheckoutFlowPath(scriptPath), True,
                KeepStoreStaySignedInWeb.HasSessionCookie(current), hasHop, KeepStoreStaySignedInWeb.IsSkippedInThisSession(current))
            If restoreStep = StaySignedInRestoreStep.None Then Return False
            If hasHop Then KeepStoreStaySignedInWeb.ClearHopCookie(current)
            If restoreStep = StaySignedInRestoreStep.Blocked OrElse Not KeepStoreStaySignedInWeb.IsActive() Then Return False

            Dim account As StaySignedInAccount = Nothing
            Dim renewed As Boolean = False
            Dim outcome As StaySignedInOutcome = KeepStoreStaySignedIn.TryRestore(
                KeepStoreStaySignedInWeb.ConnectionText(), KeepStoreStaySignedInWeb.DatabaseScope(), companyId, cookieValue, account, renewed)
            If outcome = StaySignedInOutcome.Unavailable Then Return False
            If outcome <> StaySignedInOutcome.Restored OrElse account Is Nothing Then
                KeepStoreStaySignedInWeb.ClearCookie(current)
                Return False
            End If

            If restoreStep = StaySignedInRestoreStep.Regenerate Then
                ' Il browser porta un identificativo di sessione non creato ora dal sito: si cambia sessione e si ripete la stessa pagina.
                ' Nessun dato dell'account viene scritto in questa sessione.
                Session.Abandon()
                KeepStoreStaySignedInWeb.ExpireSessionCookie(current)
                KeepStoreStaySignedInWeb.SetHopCookie(current)
                If renewed Then KeepStoreStaySignedInWeb.WriteCookie(current, cookieValue)
                Response.Redirect(KeepStoreStaySignedIn.LocalRedirectTarget(Request.RawUrl), True)
                Return False
            End If

            ClearStorefrontAuthenticationState()
            Me.Session("LoginId") = account.LoginId
            Me.Session("LoginID") = account.LoginId
            Me.Session("UtentiId") = account.UtentiId
            Me.Session("UtentiID") = account.UtentiId
            _deviceRestoreAccount = account
            _deviceRestoreRenewed = renewed
            Return True
        Catch abortEx As System.Threading.ThreadAbortException
            Throw
        Catch ex As Exception
            _deviceRestoreAccount = Nothing
            KeepStoreLog.Error("stay-signed-in", "Device restore failed closed. Error type: " & ex.GetType().Name & ".", Nothing, HttpContext.Current)
            Return False
        End Try
    End Function

    ' La rivalidazione ha rifiutato il dispositivo ricordato: stato anonimo, nessun 403. Rifiuto definitivo = dispositivo annullato e cookie
    ' cancellato; errore tecnico = il cookie resta, ma in questa sessione non si riprova.
    Private Sub AbortDeviceRestore(ByVal companyId As Integer, ByVal technicalFailure As Boolean)
        _deviceRestoreAccount = Nothing
        _deviceRestoreRenewed = False
        ClearStorefrontAuthenticationState()
        RestoreAnonymousPriceDisplayState()
        Dim current As HttpContext = HttpContext.Current
        KeepStoreStaySignedInWeb.SkipInThisSession(current)
        If technicalFailure Then Return
        Dim cookieValue As String = KeepStoreStaySignedInWeb.ReadCookie(current)
        KeepStoreStaySignedIn.Revoke(KeepStoreStaySignedInWeb.ConnectionText(), KeepStoreStaySignedInWeb.DatabaseScope(), companyId, cookieValue, "account")
        KeepStoreStaySignedInWeb.ClearCookie(current)
    End Sub

    ' Dopo la rivalidazione riuscita: le chiavi che l'accesso scrive e la rivalidazione non idrata, il registro dell'accesso e il carrello.
    Private Sub CompleteDeviceRestore(ByVal companyId As Integer)
        Dim current As HttpContext = HttpContext.Current
        Dim account As StaySignedInAccount = _deviceRestoreAccount
        If account Is Nothing Then
            If String.Equals(Request.HttpMethod, "GET", StringComparison.Ordinal) AndAlso CurrentLoginIdSafe() > 0 Then
                KeepStoreStaySignedInWeb.TouchIfDue(current, companyId, CurrentLoginIdSafe())
            End If
            Return
        End If
        If CurrentLoginIdSafe() <> account.LoginId OrElse
           StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AuthenticatedAziendaID")) <> companyId OrElse
           StorefrontCommercialIsolationPolicy.PositiveInteger(Session("UtentiId")) <> account.UtentiId Then
            AbortDeviceRestore(companyId, True)
            Return
        End If
        Dim profile As StaySignedInProfile = KeepStoreStaySignedIn.LoadSessionProfile(
            KeepStoreStaySignedInWeb.ConnectionText(), account.LoginId, companyId, account.UtentiId)
        If profile Is Nothing Then
            AbortDeviceRestore(companyId, True)
            Return
        End If
        _deviceRestoreAccount = Nothing
        Me.Session("AbilitaListino") = profile.PriceListEnabled
        Me.Session("LoginEmail") = profile.Email
        Me.Session("LoginNomeCognome") = profile.DisplayName
        If Not IsDBNull(profile.LastAccess) Then Me.Session("LoginUltimoAccesso") = profile.LastAccess
        Me.Session("genera_html_mail") = profile.MailHtml
        Me.Session("DataPassword") = profile.PasswordDate
        Me.Session("CanOrder") = If(IsDBNull(profile.CanOrder), CType(1, Object), profile.CanOrder)
        KeepStoreStaySignedInWeb.MarkRestored(current)
        If _deviceRestoreRenewed Then KeepStoreStaySignedInWeb.WriteCookie(current, KeepStoreStaySignedInWeb.ReadCookie(current))
        _deviceRestoreRenewed = False

        LoginAccessAuditRecorder.TryRecordSuccessfulLogin(current, account.LoginId)
        Try
            AggiornaDati()
        Catch ex As Exception
            KeepStoreLog.Error("login-cart-sync", "Device restore cart synchronization failed. Error type: " & ex.GetType().Name & ".", Nothing, current)
        End Try
    End Sub

    '==========================================================
    ' Helper: trova controlli SENZA ricorsione (evita StackOverflow)
    '==========================================================
    Private Function FindControlIterative(ByVal root As Control, ByVal id As String) As Control
        If root Is Nothing OrElse String.IsNullOrEmpty(id) Then Return Nothing

        Dim st As New Stack(Of Control)()
        st.Push(root)

        While st.Count > 0
            Dim cur As Control = st.Pop()

            If cur IsNot Nothing AndAlso String.Equals(cur.ID, id, StringComparison.Ordinal) Then
                Return cur
            End If

            If cur IsNot Nothing AndAlso cur.HasControls() Then
                For i As Integer = cur.Controls.Count - 1 To 0 Step -1
                    st.Push(cur.Controls(i))
                Next
            End If
        End While

        Return Nothing
    End Function

    Private Function FindCtrl(Of T As Control)(ByVal id As String) As T
        Dim c As Control = FindControlIterative(Me, id)
        Return TryCast(c, T)
    End Function


    '==========================================================
    ' UI wiring: header/menu events when header is in UserControl
    '==========================================================
    Private _headerEventsWired As Boolean = False

    Private Sub WireHeaderEvents()
        If _headerEventsWired Then Exit Sub
        _headerEventsWired = True

        Try
            Dim btnSearchCtrl As HtmlButton = FindCtrl(Of HtmlButton)("btnSearch")
            If btnSearchCtrl IsNot Nothing Then AddHandler btnSearchCtrl.ServerClick, AddressOf btnSearch_ServerClick

            Dim btnSearchMobileCtrl As HtmlButton = FindCtrl(Of HtmlButton)("btnSearchMobile")
            If btnSearchMobileCtrl IsNot Nothing Then AddHandler btnSearchMobileCtrl.ServerClick, AddressOf btnSearch_ServerClick

            Dim tbCercaMobileCtrl As TextBox = FindCtrl(Of TextBox)("tbCercaMobile")
            If tbCercaMobileCtrl IsNot Nothing Then AddHandler tbCercaMobileCtrl.TextChanged, AddressOf tbCercaMobile_TextChanged
        Catch
            ' fail-safe
        End Try
    End Sub




' ============================================================
' SEO JSON-LD (iniettato dalle pagine contenuto tramite SeoBuilder)
' ============================================================
Private _seoJsonLd As String = String.Empty

    Public Property SeoJsonLd As String Implements ISeoMaster.SeoJsonLd
        Get
            Return If(_seoJsonLd, String.Empty)
        End Get
        Set(value As String)
            _seoJsonLd = If(value, String.Empty)

            ' Aggiorna subito il literal nel <head> (se già disponibile)
            If phSeoJsonLd IsNot Nothing Then
                phSeoJsonLd.Visible = Not String.IsNullOrWhiteSpace(_seoJsonLd)
            End If

            If litSeoJsonLd IsNot Nothing Then
                litSeoJsonLd.Text = _seoJsonLd
            End If
        End Set
    End Property

    ' Ritorna un contenitore sicuro dentro <head> per iniettare meta/link anche quando
    ' il master contiene blocchi <% ... %> (in tal caso Me.Page.Header.Controls.Add lancia eccezione).
    Private Function GetHeadDynamicContainer() As Control
        ' Preferisci placeholder dedicato nel master
        Dim c As Control = Me.FindControl("phHeadDynamic")
        If c IsNot Nothing Then Return c
        ' Fallback (patch precedenti)
        c = Me.FindControl("phHeadLinks")
        If c IsNot Nothing Then Return c
        Return Nothing
    End Function


Private Function HeaderHasMeta(ByVal metaName As String) As Boolean
    If Me.Page Is Nothing OrElse Me.Page.Header Is Nothing OrElse String.IsNullOrWhiteSpace(metaName) Then Return False

    Dim stack As New Stack(Of Control)()
    stack.Push(Me.Page.Header)

    While stack.Count > 0
        Dim current As Control = stack.Pop()
        If current Is Nothing Then Continue While

        Dim hm As HtmlMeta = TryCast(current, HtmlMeta)
        If hm IsNot Nothing AndAlso Not String.IsNullOrEmpty(hm.Name) Then
            If String.Equals(hm.Name, metaName, StringComparison.OrdinalIgnoreCase) Then
                Return True
            End If
        End If

        If current.HasControls() Then
            For i As Integer = current.Controls.Count - 1 To 0 Step -1
                stack.Push(current.Controls(i))
            Next
        End If
    End While

    Return False
End Function

Private Function HeaderHasCanonical() As Boolean
    If Me.Page Is Nothing OrElse Me.Page.Header Is Nothing Then Return False
    Dim stack As New Stack(Of Control)()
    stack.Push(Me.Page.Header)
    While stack.Count > 0
        Dim current As Control = stack.Pop()
        If current Is Nothing Then Continue While
        Dim link As HtmlLink = TryCast(current, HtmlLink)
        If link IsNot Nothing AndAlso
           String.Equals(Convert.ToString(link.Attributes("rel")), "canonical", StringComparison.OrdinalIgnoreCase) Then
            Return True
        End If
        If current.HasControls() Then
            For i As Integer = current.Controls.Count - 1 To 0 Step -1
                stack.Push(current.Controls(i))
            Next
        End If
    End While
    Return False
End Function

    
' ============================================================
' STEP29 - SEO globale (noindex + canonical) per pagine NON SEO
' - Non tocca logica business, filtri o postback
' - Evita indicizzazione aree private e URL azione (rimuovi/st)
' ============================================================
Private Sub ApplyGlobalSeoPolicy()

        '---------------------------
        ' HEADER ICONS (Account / Wishlist) - template integration
        '---------------------------
        Try
            Dim lblWish As Label = FindCtrl(Of Label)("lblWishlistCount")

            If lblWish IsNot Nothing Then
                ' wishlist.id_utente appartiene a utenti.Id (Session("UtentiId")), la stessa chiave di wishlist.aspx e
                ' wishlist_add.aspx; login.id (Session("LoginId")) e un altro identificativo e serve solo come gate di accesso.
                Dim wishCount As Integer = GetWishlistCountForHeader(ResolveWishlistOwnerId(Session("LoginId"), Session("UtentiId")))
                lblWish.Text = wishCount.ToString()
                lblWish.Visible = True
            End If
        Catch ex As Exception
            ' fail-safe
        End Try

    Try
        If litGlobalSeoHead Is Nothing OrElse Request Is Nothing OrElse Request.Url Is Nothing Then Exit Sub

        Dim path As String = String.Empty
        Try
            path = If(Request.Url.AbsolutePath, String.Empty)
        Catch
            path = If(Request.Path, String.Empty)
        End Try
        Dim pathLower As String = path.ToLowerInvariant()

        ' Pagine SEO (gestiscono già canonical/noindex): non interferire
        If pathLower.EndsWith("/articoli.aspx") OrElse pathLower.EndsWith("/articolo.aspx") Then
            litGlobalSeoHead.Text = String.Empty
            Exit Sub
        End If

        Dim qs As NameValueCollection = Request.QueryString
        Dim hasMutationParameter As Boolean = (qs IsNot Nothing AndAlso
            qs("rimuovi") IsNot Nothing AndAlso Convert.ToString(qs("rimuovi")).Trim() <> String.Empty)
        Dim applyNoIndex As Boolean = hasMutationParameter OrElse
            StorefrontCanonicalHostPolicy.IsNoIndexPath(pathLower) OrElse
            Response.StatusCode >= 400

        Dim sb As New StringBuilder()
        If applyNoIndex Then
            Try
                Response.Headers("X-Robots-Tag") = "noindex, nofollow"
            Catch
                Try
                    Response.AddHeader("X-Robots-Tag", "noindex, nofollow")
                Catch
                End Try
            End Try

            Try
                Response.Cache.SetCacheability(HttpCacheability.NoCache)
                Response.Cache.SetNoStore()
                Response.Cache.SetRevalidation(HttpCacheRevalidation.AllCaches)
                Response.Cache.SetExpires(DateTime.UtcNow.AddMinutes(-1))
            Catch
            End Try

            If Not HeaderHasMeta("robots") Then
                sb.Append("<meta name=""robots"" content=""noindex,nofollow"" />")
            End If
            litGlobalSeoHead.Text = sb.ToString()
            Exit Sub
        End If

        Dim relativeCanonical As String = path
        If pathLower.EndsWith("/default.aspx", StringComparison.Ordinal) Then
            relativeCanonical = "/"
        End If
        Dim canonicalUrl As String = StorefrontSeoTenantContext.BuildCanonicalUrl(HttpContext.Current, relativeCanonical)
        If String.IsNullOrEmpty(canonicalUrl) Then
            Response.Headers("X-Robots-Tag") = "noindex, nofollow"
            litGlobalSeoHead.Text = "<meta name=""robots"" content=""noindex,nofollow"" />"
            Exit Sub
        End If

        If Not HeaderHasMeta("robots") Then
            sb.Append("<meta name=""robots"" content=""index,follow"" />").Append(vbCrLf)
        End If
        If Not HeaderHasMeta("description") Then
            Dim description As String = Convert.ToString(Page.Title).Trim()
            If String.IsNullOrEmpty(description) Then description = "Storefront " & StorefrontSeoTenantContext.BrandName(HttpContext.Current)
            sb.Append("<meta name=""description"" content=""")
            sb.Append(HttpUtility.HtmlAttributeEncode(description))
            sb.Append(""" />").Append(vbCrLf)
        End If
        If Not HeaderHasCanonical() Then
            sb.Append("<link rel=""canonical"" href=""")
            sb.Append(HttpUtility.HtmlAttributeEncode(canonicalUrl))
            sb.Append(""" />")
        End If
        litGlobalSeoHead.Text = sb.ToString()

    Catch
        ' Fail-safe: mai bloccare la master per SEO
        Try
            If litGlobalSeoHead IsNot Nothing Then litGlobalSeoHead.Text = String.Empty
        Catch
        End Try
    End Try
End Sub


' ============================================================
' SECURITY: Rimuove il cookie legacy "Password" (conteneva la password in chiaro)
' - Migrazione trasparente: se un client ha ancora quel cookie, viene eliminato.
' - Fail-safe: non interrompe mai il rendering.
' ============================================================
Private Sub ExpireLegacyPasswordCookie()
    Try
        Dim legacy As HttpCookie = Nothing
        Try
            legacy = Request.Cookies("Password")
        Catch
            legacy = Nothing
        End Try

        If legacy Is Nothing Then Exit Sub

        Dim expired As New HttpCookie("Password")
        expired.Value = ""
        expired.Path = "/"
        expired.HttpOnly = True
        expired.Secure = Request.IsSecureConnection
        Try
            expired.SameSite = SameSiteMode.Lax
        Catch
            ' SameSite non disponibile in alcune configurazioni legacy
        End Try
        expired.Expires = DateTime.UtcNow.AddDays(-7)

        Response.Cookies.Set(expired)
    Catch
        ' mai bloccare la master per la gestione cookie
    End Try
End Sub

Dim IvaTipo As Integer
    Dim conn As New MySqlConnection
    Dim conn2 As New MySqlConnection
    Dim cmd As New MySqlCommand

    Function sostituisci_caratteri_speciali(ByRef stringa As String) As String
        stringa = Server.HtmlDecode(stringa)
        stringa = stringa.Replace("'", "''")
        Return stringa
    End Function

    '==========================================================
    ' NAVBAR: Settori/Categorie/Tipologie (abilitati)
    '==========================================================
    '==========================================================
    ' INIT: azienda, catalogo, popup, sfondo
    '==========================================================
    Protected Sub Page_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Init
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn2.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn

        ' Wire header/menu events (header may be rendered via UserControl)
        WireHeaderEvents()



        ' ============================================================
        ' STEP-Sec: Anti-CSRF (ViewStateUserKey)
        ' - Non sovrascrive il token impostato dalle pagine AntiCsrfPage
        ' - Fallback legacy su SessionID solo quando nessuna pagina ha gia'
        '   scelto una chiave stabile prima del caricamento ViewState.
        ' ============================================================
        Try
            If Me.Page IsNot Nothing AndAlso Me.Session IsNot Nothing Then
                Dim currentKey As String = String.Empty
                Try
                    currentKey = Convert.ToString(Me.Page.ViewStateUserKey)
                Catch
                    currentKey = String.Empty
                End Try

                If String.IsNullOrEmpty(currentKey) Then
                    Dim sid As String = Convert.ToString(Me.Session.SessionID)
                    If Not String.IsNullOrEmpty(sid) Then
                        Me.Page.ViewStateUserKey = sid
                    End If
                End If
            End If
        Catch
        End Try
        LeggiAzienda()
        If Response.StatusCode = 421 Then Return
        SettaCatalogo()

        If Me.Session.Item("ListaSettori") Is Nothing Then
            Me.Session.Item("ListaSettori") = Settore.creaListaSettori()
        End If

        Dim aziendaId As Integer = 0
        Integer.TryParse(Convert.ToString(Me.Session("AziendaID")), aziendaId)
        Dim dr As MySqlDataReader

        'MiPiace di Facebook
        Dim facebookLink As String = ""
        If Session("facebookLink") IsNot Nothing Then
            facebookLink = Session("facebookLink").ToString().Trim()
        End If

        If (Request.Cookies("FacebookLike") Is Nothing) AndAlso (facebookLink.Length > 0) Then
            PopUpfacebook.Visible = True
        Else
            PopUpfacebook.Visible = False
        End If

        'Popup 
        Dim DataOdierna As String = Date.Today.Year.ToString & "-" & Date.Today.Month.ToString & "-" & Date.Today.Day.ToString
        If (Me.Session.Item("Popup") = 1) AndAlso aziendaId > 0 Then
            conn = New MySqlConnection()
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            cmd.Connection = conn
            conn.Open()

            cmd.CommandType = CommandType.Text
            cmd.CommandText = "SELECT Azienda, Data_Inizio, Data_Fine, Messaggio, Abilitato " &
                              "FROM popup " &
                              "WHERE (Azienda=@aziendaId) " &
                              "AND ((Data_Inizio<=@dataOdierna) AND (Data_Fine>=@dataOdierna)) " &
                              "AND (Abilitato=1)"

            cmd.Parameters.Clear()
            cmd.Parameters.AddWithValue("@aziendaId", aziendaId)
            cmd.Parameters.AddWithValue("@dataOdierna", DataOdierna)

            Me.SqlData_Popup.SelectCommand = cmd.CommandText

            dr = cmd.ExecuteReader()
            dr.Read()

            If Not dr.HasRows Then
                Me.Session.Item("Popup") = 0
            Else
                Me.Session.Item("Popup") = 1
            End If

            dr.Close()
            conn.Close()
        End If

        cmd.Dispose()
    End Sub

    '==========================================================
    ' LOAD: login automatico, cookie, scadenza password, partners
    '==========================================================
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If IsLoginPostRejected(Context) Then Return
        If String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) AndAlso
           Me.FindControl("tbUsername") IsNot Nothing AndAlso Me.FindControl("tbPassword") IsNot Nothing Then
            If Not EnsureLoginPostOrigin() Then Return
        End If
        ' Tema grafico: tagging per CSS token/switch (non altera la logica business)
        ApplyThemeTagging()
        BindWhatsAppContact()

        Dim nativeCartToken As String = CatalogAsyncCartSupport.GetOrCreateCsrfToken(HttpContext.Current)
        litNativeCartSecurityFields.Text =
            "<input type=""hidden"" name=""csrfToken"" value=""" & HttpUtility.HtmlAttributeEncode(nativeCartToken) & """ />" &
            "<input type=""hidden"" name=""ReturnUrl"" value=""" & HttpUtility.HtmlAttributeEncode(Request.RawUrl) & """ />"

        ' Footer: email supporto configurabile (fallback safe)
        ApplySupportEmail()

        PostLoginReturnUrlPolicy.RememberContext(HttpContext.Current, Me.Request.Url)


        ' SECURITY: rimuove subito il cookie legacy \"Password\" (se presente)
        ExpireLegacyPasswordCookie()

        ' Controlli login sulla master (se esistono)
        Dim tbUser As TextBox = TryCast(Me.FindControl("tbUsername"), TextBox)
        Dim tbPass As TextBox = TryCast(Me.FindControl("tbPassword"), TextBox)

        If tbUser IsNot Nothing AndAlso tbPass IsNot Nothing Then
            If String.Equals(Request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase) Then
                ' Dati legacy post-registrazione: non usare password in sessione per auto-login.
                If Session.Item("Inserimento_User") IsNot Nothing Then Session.Item("Inserimento_User") = ""
                If Session.Item("Inserimento_Password") IsNot Nothing Then Session.Item("Inserimento_Password") = ""

                If tbUser.Text <> "" AndAlso tbUser.Text <> "Username" AndAlso tbPass.Text <> "" Then
                    Login(tbUser.Text.Replace("'", ""), tbPass.Text.Replace("'", ""))
                    If IsLoginPostRejected(Context) Then Return
                End If
            End If

            tbPass.ReadOnly = True

            If Not Me.IsPostBack Then
                If Me.Session("LoginId") Is Nothing Then
                    Dim aziendaNome As Object = Me.Session("AziendaNome")
                    If aziendaNome IsNot Nothing AndAlso Not IsNothing(Me.Request.Cookies(aziendaNome.ToString())) Then
                        tbUser.Text = Me.Request.Cookies(aziendaNome.ToString())("Username")
                        tbPass.Text = ""
End If
                End If
            End If
        End If

        'Scadenza password: redirect robusto e non ciclico.
        Dim currentScript As String = CurrentScriptPathLower()
        Dim loginIdPassword As Integer = CurrentLoginIdSafe()
        If loginIdPassword > 0 AndAlso
           Not currentScript.EndsWith("/password.aspx") AndAlso
           Not currentScript.EndsWith("/login.aspx") AndAlso
           Not currentScript.EndsWith("/logout.aspx") AndAlso
           Not currentScript.EndsWith("/accessonegato.aspx") Then
            Try
                Dim dataPassword As DateTime
                Dim mesiScadenza As Integer
                If DateTime.TryParse(Convert.ToString(Me.Session("DataPassword")), dataPassword) AndAlso
                   Integer.TryParse(Convert.ToString(Me.Session("ScadenzaPassword")), mesiScadenza) AndAlso
                   mesiScadenza > 0 Then

                    If DateTime.Today > dataPassword.AddMonths(mesiScadenza).Date Then
                        Me.Response.Redirect("password.aspx", False)
                        Context.ApplicationInstance.CompleteRequest()
                        Return
                    End If
                End If
            Catch
                ' se DataPassword/ScadenzaPassword non sono coerenti, non butto fuori l'utente
            End Try
        End If

        'aggiorno la query relativa agli ordini effettuati sul sito
        SqlData_TotOrdini.SelectCommand =
            "SELECT COUNT(*) AS Conteggio " &
            "FROM documenti " &
            "WHERE (TipoDocumentiId = 4) " &
            "AND (DataDocumento <= { d '" & Date.Now.Year & "-12-31' }) " &
            "AND (DataDocumento >= { d '" & Date.Now.Year & "-01-01' })"

        'Setto i Partners dell'Azienda
        Dim aziendaIdPartners As Integer = 0
        Integer.TryParse(Convert.ToString(Session("AziendaID")), aziendaIdPartners)
        If aziendaIdPartners > 0 Then
            Sql_Partners.SelectCommand =
                "SELECT partners.*, Ordinamento AS Expr1 " &
                "FROM partners " &
                "WHERE (AziendaId=" & aziendaIdPartners & ") " &
                "ORDER BY Expr1"
        End If
    
End Sub

    '==========================================================
    ' BANNER / PUBBLICITÀ LEGACY (DISABILITATI)
    '==========================================================
#Region "Pubblicità legacy (disabilitata)"
#If False Then
    ' TUTTO IL CODICE DEI BANNER QUI RESTA COM'ERA (NON VIENE COMPILATO)
#End If
#End Region

    '==========================================================
    ' PRE-RENDER: mini-login, badge ordini, carrello, meta
    '==========================================================
    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        If IsLoginPostRejected(Context) Then Return

        ' controlli dinamici (il tema non espone tutti gli ID legacy)
        Dim lbl4 As Label = FindCtrl(Of Label)("Label4")
        Dim hl14 As HyperLink = FindCtrl(Of HyperLink)("HyperLink14")
        Dim mv As MultiView = FindCtrl(Of MultiView)("mvLogin")
        Dim payYourOrders As Control = FindControlIterative(Me, "pay_your_orders")
        Dim toPay As System.Web.UI.HtmlControls.HtmlGenericControl = TryCast(FindControlIterative(Me, "to_pay"), System.Web.UI.HtmlControls.HtmlGenericControl)
        ' STEP29: applica policy SEO globale (noindex/canonical su pagine non SEO)
        ApplyGlobalSeoPolicy()

        '---------------------------
        ' LINK LISTINO PERSONALIZZATO
        '---------------------------
        Try
            If Not IsNothing(Session("AbilitaListino")) AndAlso
               IsNumeric(Session("AbilitaListino")) AndAlso
               CInt(Session("AbilitaListino")) > 0 Then

                If lbl4 IsNot Nothing Then If lbl4 IsNot Nothing Then lbl4.Visible = True
                If hl14 IsNot Nothing Then If hl14 IsNot Nothing Then hl14.Visible = True
            Else
                If lbl4 IsNot Nothing Then If lbl4 IsNot Nothing Then lbl4.Visible = False
                If hl14 IsNot Nothing Then If hl14 IsNot Nothing Then hl14.Visible = False
            End If
        Catch
            If lbl4 IsNot Nothing Then If lbl4 IsNot Nothing Then lbl4.Visible = False
            If hl14 IsNot Nothing Then If hl14 IsNot Nothing Then hl14.Visible = False
        End Try

        '---------------------------
        ' MINI LOGIN HEADER
        '---------------------------
        If CurrentLoginIdSafe() > 0 Then
            ' Utente loggato → mostra view 1 (Ciao, Nome + Esci)
            If mv IsNot Nothing Then If mv IsNot Nothing Then mv.ActiveViewIndex = 1

            Dim lblUser As Label = If(mv Is Nothing, Nothing, TryCast(mv.FindControl("lblUtente"), Label))
            If lblUser IsNot Nothing Then
                Dim displayName As String = Convert.ToString(Session("LoginNomeCognome")).Trim()
                If String.IsNullOrWhiteSpace(displayName) Then
                    displayName = Convert.ToString(Session("LoginEmail")).Trim()
                End If
                If String.IsNullOrWhiteSpace(displayName) Then
                    displayName = "cliente"
                End If
                lblUser.Text = displayName
            End If

            ' *** CORRETTO QUI: niente "Is Not Nothing" su Session("LoginUltimoAccesso") ***
            Dim lblAccesso As Label = If(mv Is Nothing, Nothing, TryCast(mv.FindControl("lblAccesso"), Label))
            If lblAccesso IsNot Nothing Then
                Dim lastAccess As String = Convert.ToString(Session("LoginUltimoAccesso"))
                If String.IsNullOrEmpty(lastAccess) Then
                    lblAccesso.Text = "Oggi"
                Else
                    lblAccesso.Text = lastAccess
                End If
            End If

            ' Ordini da saldare (badge)
            Dim toPayString As String = get_documents_toPay()
            If toPayString <> "0" Then
                If payYourOrders IsNot Nothing Then If payYourOrders IsNot Nothing Then payYourOrders.Visible = True
                If toPay IsNot Nothing Then CType(toPay, HtmlGenericControl).InnerHtml = toPayString
            Else
                If payYourOrders IsNot Nothing Then If payYourOrders IsNot Nothing Then payYourOrders.Visible = False
            End If
        Else
            ' Utente NON loggato → mostra view 0 (Accedi / Registrati)
            If mv IsNot Nothing Then If mv IsNot Nothing Then mv.ActiveViewIndex = 0
            If payYourOrders IsNot Nothing Then If payYourOrders IsNot Nothing Then payYourOrders.Visible = False
        End If

        'IVA tipo (campo di classe, usato solo legacy)
        Try
            IvaTipo = CInt(Me.Session("IvaTipo"))
        Catch
            IvaTipo = 0
        End Try

        'Carrello (icone in header) → usa totale aggiornato direttamente da DB
        LeggiCarrello()
        BindCartFeedback(CartStateSnapshotProvider.GetCurrent(HttpContext.Current))

        'Meta tag SEO
        Meta()
    
        ' SEO JSON-LD (se valorizzato dalla pagina contenuto)
        If litSeoJsonLd IsNot Nothing Then
            litSeoJsonLd.Text = SeoJsonLd
        End If

End Sub

' Proprietario della wishlist: richiede sessione autenticata (LoginId) e restituisce utenti.Id, mai login.id.
' Valori assenti, non numerici o non positivi falliscono chiusi con 0, senza ripiegare su LoginId.
Private Shared Function ResolveWishlistOwnerId(ByVal loginIdRaw As Object, ByVal utentiIdRaw As Object) As Integer
    Dim loginId As Integer = 0
    Dim utentiId As Integer = 0
    If loginIdRaw Is Nothing OrElse Not Integer.TryParse(Convert.ToString(loginIdRaw), loginId) OrElse loginId <= 0 Then
        Return 0
    End If
    If utentiIdRaw Is Nothing OrElse Not Integer.TryParse(Convert.ToString(utentiIdRaw), utentiId) OrElse utentiId <= 0 Then
        Return 0
    End If
    Return utentiId
End Function

Private Function GetWishlistCountForHeader(ByVal ownerUtentiId As Integer) As Integer
    If ownerUtentiId <= 0 Then
        Return 0
    End If

    Try
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand("SELECT COUNT(*) FROM wishlist WHERE id_utente=@id", conn)
                cmd.Parameters.AddWithValue("@id", ownerUtentiId)
                Dim raw As Object = cmd.ExecuteScalar()
                If raw Is Nothing OrElse raw Is DBNull.Value Then
                    Return 0
                End If

                Dim count As Integer = 0
                Integer.TryParse(Convert.ToString(raw), count)
                Return count
            End Using
        End Using
    Catch
        Return 0
    End Try
End Function

    '==========================================================
    ' SUPPORTO IVA DI DEFAULT
    '==========================================================
    Function preleva_idiva_default() As Integer
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim risultato As Integer = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn

        conn.Open()

        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT * FROM ivadefault WHERE NOW() BETWEEN Dal AND Al"

        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            risultato = CInt(dr.Item("IdIva"))
        Else
            risultato = -1
        End If

        dr.Close()
        conn.Close()

        Return risultato
    End Function

    Function preleva_valoreiva_default() As Integer
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim risultato As Integer = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn

        conn.Open()

        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT * FROM ivadefault INNER JOIN iva ON iva.`id`=ivadefault.`IvaId` WHERE NOW() BETWEEN Dal AND Al"

        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            risultato = CInt(dr.Item("Valore"))
        Else
            risultato = -1
        End If

        dr.Close()
        conn.Close()

        Return risultato
    End Function

    '==========================================================
    ' SETUP CATALOGO
    '==========================================================
    Public Sub SettaCatalogo()
        SettoreDefault()

        'Settore
        If IsNumeric(Me.Request.QueryString("st")) Then
            Me.Session("st") = Me.Request.QueryString("st")
            Me.Session("ct") = 30000
            Me.Session("tp") = 0
            Me.Session("gr") = 0
            Me.Session("sg") = 0
            Me.Session("mr") = 0
            Me.Session("pid") = 0
            Me.Session("q") = Nothing
        End If

        'Categoria
        If IsNumeric(Me.Request.QueryString("ct")) Then
            Me.Session("ct") = Me.Request.QueryString("ct")
            Me.Session("tp") = 0
            Me.Session("gr") = 0
            Me.Session("sg") = 0
            Me.Session("pid") = 0
            Me.Session("q") = Nothing
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Tipologia
        If IsNumeric(Me.Request.QueryString("tp")) Then
            Me.Session("tp") = Me.Request.QueryString("tp")
            Me.Session("pid") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Gruppo
        If IsNumeric(Me.Request.QueryString("gr")) Then
            Me.Session("gr") = Me.Request.QueryString("gr")
            Me.Session("pid") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Sottogruppo
        If IsNumeric(Me.Request.QueryString("sg")) Then
            Me.Session("sg") = Me.Request.QueryString("sg")
            Me.Session("pid") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Marca
        If IsNumeric(Me.Request.QueryString("mr")) Then
            Me.Session("mr") = Me.Request.QueryString("mr")
            Me.Session("pid") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Promo
        If IsNumeric(Me.Request.QueryString("pid")) Then
            Me.Session("pid") = Me.Request.QueryString("pid")
            Me.Session("mr") = 0
            Me.Session("ct") = 30000
            Me.Session("tp") = 0
            Me.Session("gr") = 0
            Me.Session("sg") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Ricerca
        Me.Session("q") = Nothing
        If Me.Request.QueryString("q") <> "" Then
            Me.Session("q") = Me.Request.QueryString("q").Trim

            If Not IsNothing(Me.Request.UrlReferrer) Then
                If (Me.Request.UrlReferrer.AbsolutePath.ToString().IndexOf("search_complete") < 0) Then
                    Me.Session("ct") = 30000
                End If
            End If
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If
    End Sub

    Private Sub ApplyThemeTagging()
        Try
            Dim theme As String = ThemeManager.ThemeName

            If PageBody Is Nothing Then Exit Sub

            ' Base body classes (tokenizzabili via web.config)
            Dim baseCls As String = ThemeManager.Css("body", "preload-wrapper popup-loader color-primary").Trim()

            ' Merge classi: preservo eventuali classi pre-esistenti
            Dim cls As String = Convert.ToString(PageBody.Attributes("class"))
            cls = If(cls, String.Empty).Trim()

            If Not String.IsNullOrWhiteSpace(baseCls) Then
                For Each part As String In baseCls.Split(New Char() {" "c}, StringSplitOptions.RemoveEmptyEntries)
                    If cls.IndexOf(part, StringComparison.OrdinalIgnoreCase) < 0 Then
                        cls = (cls & " " & part).Trim()
                    End If
                Next
            End If

            ' Theme tag
            Dim tag As String = ("ks-theme-" & theme).Trim()
            If Not String.IsNullOrWhiteSpace(tag) AndAlso cls.IndexOf(tag, StringComparison.OrdinalIgnoreCase) < 0 Then
                cls = (cls & " " & tag).Trim()
            End If

            If IsAccountShellEnabledPath(Me.Request.Url.AbsolutePath) AndAlso cls.IndexOf("ks-page-account", StringComparison.OrdinalIgnoreCase) < 0 Then
                cls = (cls & " ks-page-account").Trim()
            End If

            PageBody.Attributes("class") = cls

            ' data attribute
            PageBody.Attributes("data-ks-theme") = theme
            PageBody.Attributes("data-ks-async-cart-endpoint") = ResolveUrl("~/catalog_cart_async.aspx")
            PageBody.Attributes("data-ks-async-cart-token") = CatalogAsyncCartSupport.GetOrCreateCsrfToken(HttpContext.Current)
        Catch
            ' no-op
        End Try

        ' Colore di accento per vetrina (tenant-accent.css): il body porta l'azienda risolta per host. Errore o azienda ignota = attributo assente.
        Try
            Dim accentTenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
            If PageBody IsNot Nothing AndAlso accentTenant IsNot Nothing AndAlso accentTenant.CompanyId > 0 Then
                PageBody.Attributes("data-ks-company") = accentTenant.CompanyId.ToString(System.Globalization.CultureInfo.InvariantCulture)
            End If
        Catch
            ' no-op
        End Try
    End Sub

    Private Sub ApplySupportEmail()
        Try
            Dim email As String = String.Empty
            Try
                email = Convert.ToString(ConfigurationManager.AppSettings("KeepStore.Site.SupportEmail"))
            Catch
                email = String.Empty
            End Try

            If String.IsNullOrWhiteSpace(email) Then
                ' fallback: info@host
                Dim host As String = String.Empty
                Try
                    host = Me.Request.Url.Host
                Catch
                    host = ""
                End Try
                If String.IsNullOrWhiteSpace(host) Then host = "keepstore.it"
                email = "info@" & host
            End If

            Dim lit As Literal = FindCtrl(Of Literal)("litSupportEmail")
            If lit IsNot Nothing Then lit.Text = HttpUtility.HtmlEncode(email)

            Dim a As HtmlAnchor = FindCtrl(Of HtmlAnchor)("lnkSupportEmail")
            If a IsNot Nothing Then a.HRef = "mailto:" & email
        Catch
            ' no-op
        End Try
    End Sub

    '==========================================================
    ' LETTURA AZIENDA + TEMPLATE (hardening host query)
    '==========================================================
    Public Sub LeggiAzienda()
        Dim localConn As New MySqlConnection
        Dim localCmd As New MySqlCommand

        Dim resolvedTenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(HttpContext.Current)
        If resolvedTenant Is Nothing OrElse resolvedTenant.CompanyId <= 0 Then
            Response.Clear()
            Response.StatusCode = 421
            Response.TrySkipIisCustomErrors = True
            Response.SuppressContent = True
            Response.Write("Sito non configurato per l'host richiesto.")
            RejectAuthenticatedRequestWithoutTenant()
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        Dim sessionCompanyId As Integer = 0
        Integer.TryParse(Convert.ToString(Me.Session("AziendaID")), sessionCompanyId)
        Dim authenticatedCompanyId As Integer = 0
        Integer.TryParse(Convert.ToString(Me.Session("AuthenticatedAziendaID")), authenticatedCompanyId)
        If StorefrontCommercialIsolationPolicy.ShouldClearAuthentication(
               sessionCompanyId,
               resolvedTenant.CompanyId,
               CurrentLoginIdSafe(),
               authenticatedCompanyId) Then
            _storefrontAuthenticationRevoked = _storefrontAuthenticationRevoked OrElse
                CurrentLoginIdSafe() > 0 OrElse authenticatedCompanyId > 0
            ClearStorefrontAuthenticationState()
        End If
        ' Retain only scalar, host-validated tenant defaults in Session. Old
        ' sessions hydrate them once; account IvaTipo is never a tenant default.
        Dim cachedTenantMode As Integer = StorefrontCommercialIsolationPolicy.PositiveInteger(Session(TenantPriceDisplayModeKey))
        Dim hasTenantPriceDisplayDefaults As Boolean =
            StorefrontCommercialIsolationPolicy.PositiveInteger(Session(TenantPriceDisplayCompanyKey)) = resolvedTenant.CompanyId AndAlso
            StorefrontCommercialIsolationPolicy.PositiveInteger(Session(TenantPriceDisplayListKey)) = resolvedTenant.DefaultPriceListId AndAlso
            (cachedTenantMode = 1 OrElse cachedTenantMode = 2)
        If sessionCompanyId <> resolvedTenant.CompanyId OrElse Not hasTenantPriceDisplayDefaults Then

            localConn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            localCmd.Connection = localConn

            localConn.Open()

            localCmd.CommandType = CommandType.Text
            localCmd.CommandText = "SELECT Id, Nome, Descrizione, url1, url2, logoWeb, ListinoDefault, Email, " &
                                   "RagioneSociale, Indirizzo, Cap, Citta, provincia, Piva, Telefono, Fax, " &
                                   "ListinoUser, IvaTipo, CanOrder, MagazzinoDefault, DispoTipo, DispoMinima, RigheArticoli, " &
                                   "Groupon, Coupon, ScadenzaPassword, VetrinaArticoliNovita, VetrinaArticoliUltimiArriviPuntoVendita, " &
                                   "VetrinaArticoliImpatto, VetrinaArticoliPiuVenduti, VetrinaPromoFissi, VetrinaPromoRandom, " &
                                   "VetrinaPromoScadenza, VetrinaPromoInizio, VetrinaDispoMinima, css, copyright, " &
                                   "descrizione_servizio_coupon, logo_verific_site1, logo_verific_site2, logo_verific_site3, " &
                                   "logo_verific_site4, link_logo_verific_site1, link_logo_verific_site2, link_logo_verific_site3, " &
                                   "link_logo_verific_site4, logo_footer, statistiche_visite, facebookLink, Icona_web, " &
                                   "AbilitaBuoniScontiCarrello, TC, AccountIwBank " &
                                   "FROM aziende " &
                                   "WHERE Id=@companyId " &
                                   "LIMIT 0, 1"
            localCmd.Parameters.Clear()
            localCmd.Parameters.AddWithValue("@companyId", resolvedTenant.CompanyId)

            Dim dr As MySqlDataReader = localCmd.ExecuteReader()
            dr.Read()

            If Not dr.HasRows Then
                Response.Clear()
                Response.StatusCode = 421
                Response.TrySkipIisCustomErrors = True
                Response.SuppressContent = True
                Response.Write("Sito non configurato per l'host richiesto.")
                Try
                    dr.Close()
                Finally
                    Try
                        localConn.Close()
                    Finally
                        RejectAuthenticatedRequestWithoutTenant()
                    End Try
                End Try
                Context.ApplicationInstance.CompleteRequest()
                Return
            Else
                Dim configuredTenant As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.CreateTenant(
                    Convert.ToInt32(dr.Item("Id")),
                    Convert.ToString(dr.Item("Nome")),
                    Convert.ToString(dr.Item("Descrizione")),
                    Convert.ToString(dr.Item("url1")),
                    Convert.ToString(dr.Item("url2")),
                    Convert.ToString(dr.Item("logoWeb")),
                    Convert.ToInt32(dr.Item("ListinoDefault")))
                If configuredTenant Is Nothing OrElse
                   configuredTenant.CompanyId <> resolvedTenant.CompanyId OrElse
                   Not String.Equals(configuredTenant.CanonicalHost,
                                     resolvedTenant.CanonicalHost,
                                     StringComparison.OrdinalIgnoreCase) OrElse
                   Not String.Equals(configuredTenant.SecondaryHost,
                                     resolvedTenant.SecondaryHost,
                                     StringComparison.OrdinalIgnoreCase) Then
                    Response.Clear()
                    Response.StatusCode = 421
                    Response.TrySkipIisCustomErrors = True
                    Response.SuppressContent = True
                    Response.Write("Sito non configurato per l'host richiesto.")
                    Try
                        dr.Close()
                    Finally
                        Try
                            localConn.Close()
                        Finally
                            RejectAuthenticatedRequestWithoutTenant()
                        End Try
                    End Try
                    Context.ApplicationInstance.CompleteRequest()
                    Return
                End If
                Session(TenantPriceDisplayCompanyKey) = configuredTenant.CompanyId
                Session(TenantPriceDisplayListKey) = configuredTenant.DefaultPriceListId
                Session(TenantPriceDisplayModeKey) = CInt(StorefrontPriceDisplayContextProvider.NormalizeTenantDisplayMode(dr.Item("IvaTipo"), HttpContext.Current))
                If sessionCompanyId <> resolvedTenant.CompanyId Then
                Me.Session("AziendaID") = dr.Item("Id")
                Me.Session("AziendaEmail") = dr.Item("Email")
                Me.Session("AziendaNome") = dr.Item("Nome")
                Me.Session("AziendaDescrizione") = dr.Item("Descrizione")
                Dim logoWebPath As String = BuildLogoWebAssetPath(dr.Item("logoWeb"))
                Me.Session("AziendaLogo") = logoWebPath
                Me.Session("AziendaLogoMobile") = logoWebPath
                Me.Session("AziendaUrl") = dr.Item("url1")
                Me.Session("AziendaUrl2") = dr.Item("url2")
                Me.Session("Credits") = " <b>© " & DateTime.Now.Year.ToString() & " " & dr.Item("RagioneSociale") & "</b> - " & dr.Item("Indirizzo") & " - " & dr.Item("Cap") & " " & dr.Item("Citta") & " (" & dr.Item("provincia") & ") - P.I. " & dr.Item("Piva") & " - Tel. " & dr.Item("Telefono") & " - Fax " & dr.Item("Fax")
                Me.Session("Credits2") = "<br>" & dr.Item("RagioneSociale") & "<br>" & dr.Item("Indirizzo") & "-" & dr.Item("Cap") & "<br>" & dr.Item("Citta") & " (" & dr.Item("provincia") & ")<br>P.Iva " & dr.Item("Piva") & "<br>Tel " & dr.Item("Telefono") & "<br>Fax " & dr.Item("Fax")
                Me.Session("Listino") = dr.Item("ListinoDefault")
                Me.Session("listino") = dr.Item("ListinoDefault")
                Me.Session("ListinoUser") = dr.Item("ListinoUser")
                Me.Session("IvaTipo") = Session(TenantPriceDisplayModeKey)
                Me.Session("CanOrder") = dr.Item("CanOrder")
                Me.Session("MagazzinoDefault") = dr.Item("MagazzinoDefault")
                Me.Session("DispoTipo") = dr.Item("DispoTipo")
                Me.Session("DispoMinima") = dr.Item("DispoMinima")
                Me.Session("RigheArticoli") = dr.Item("RigheArticoli")
                Me.Session("Abilita_Groupon") = dr.Item("Groupon")
                Me.Session("Abilita_Coupon") = dr.Item("Coupon")
                Me.Session("UtentiId") = -1
                Me.Session("ScadenzaPassword") = dr.Item("ScadenzaPassword")
                Me.Session("VetrinaArticoliNovita") = dr.Item("VetrinaArticoliNovita")
                Me.Session("VetrinaArticoliUltimiArriviPuntoVendita") = dr.Item("VetrinaArticoliUltimiArriviPuntoVendita")
                Me.Session("VetrinaArticoliImpatto") = dr.Item("VetrinaArticoliImpatto")
                Me.Session("VetrinaArticoliPiuVenduti") = dr.Item("VetrinaArticoliPiuVenduti")
                Me.Session("VetrinaPromoFissi") = dr.Item("VetrinaPromoFissi")
                Me.Session("VetrinaPromoRandom") = dr.Item("VetrinaPromoRandom")
                Me.Session("VetrinaPromoScadenza") = dr.Item("VetrinaPromoScadenza")
                Me.Session("VetrinaPromoInizio") = dr.Item("VetrinaPromoInizio")
                Me.Session("VetrinaDispoMinima") = dr.Item("VetrinaDispoMinima")
                Me.Session("css") = dr.Item("css")
                Me.Session("AziendaCopyright") = dr.Item("copyright")
                Me.Session("AziendaDescrizioneServizioCoupon") = dr.Item("descrizione_servizio_coupon")
                Me.Session("AziendaLogoVerificSite1") = dr.Item("logo_verific_site1")
                Me.Session("AziendaLogoVerificSite2") = dr.Item("logo_verific_site2")
                Me.Session("AziendaLogoVerificSite3") = dr.Item("logo_verific_site3")
                Me.Session("AziendaLogoVerificSite4") = dr.Item("logo_verific_site4")
                Me.Session("LinkAziendaLogoVerificSite1") = dr.Item("link_logo_verific_site1")
                Me.Session("LinkAziendaLogoVerificSite2") = dr.Item("link_logo_verific_site2")
                Me.Session("LinkAziendaLogoVerificSite3") = dr.Item("link_logo_verific_site3")
                Me.Session("LinkAziendaLogoVerificSite4") = dr.Item("link_logo_verific_site4")
                Me.Session("AziendaLogoFooter") = "Images/Coupon/loghi/" & dr.Item("logo_footer")
                Me.Session("Script_Visite_Azienda") = dr.Item("statistiche_visite")
                Me.Session("facebookLink") = dr.Item("facebookLink")
                Me.Session("IconaWeb") = dr.Item("Icona_web")
                Me.Session("AbilitaBuoniScontiCarrello") = dr.Item("AbilitaBuoniScontiCarrello")
                Me.Session("TC") = dr.Item("TC")

                'Setto l'id del documento che mi indica il Coupon
                Session("IdDocumentoCoupon") = 18

                Try
                    Me.Session("AccountIwBank") = dr.Item("AccountIwBank")
                Catch ex As Exception
                    Me.Session("AccountIwBank") = "000000"
                End Try
                End If
            End If

            dr.Close()
            dr.Dispose()

            localConn.Close()
            localConn.Dispose()

            localCmd.Dispose()
        End If

        _priceDisplayCompanyId = resolvedTenant.CompanyId
        _priceDisplayDefaultListId = resolvedTenant.DefaultPriceListId
        _priceDisplayTenantMode = StorefrontPriceDisplayContextProvider.NormalizeTenantDisplayMode(Session(TenantPriceDisplayModeKey), HttpContext.Current)
        StorefrontPriceDisplayContextProvider.SetTenantDefaults(HttpContext.Current, _priceDisplayCompanyId,
            _priceDisplayDefaultListId, CInt(_priceDisplayTenantMode))
        EnsureAuthenticatedStorefrontScope(resolvedTenant.CompanyId, resolvedTenant.DefaultPriceListId)
        CompleteDeviceRestore(resolvedTenant.CompanyId)
        ImpostaTemplate()
    End Sub


    Public Sub ImpostaTemplate()
        Dim imgLogoCtrl As Image = FindCtrl(Of Image)("imgLogo")
        Dim imgLogoMobileCtrl As Image = FindCtrl(Of Image)("imgLogoMobile")
        Dim lblCreditsCtrl As Label = FindCtrl(Of Label)("lblCredits")
        Dim headC As Control = GetHeadDynamicContainer()

	        ' Defensive: i controlli possono non esistere su alcune pagine/master varianti.
	        ' Inoltre le session potrebbero non essere ancora valorizzate in Page_Init.
	        Dim aziendaNome As String = If(Me.Session("AziendaNome") Is Nothing, "", Me.Session("AziendaNome").ToString())
	        Dim aziendaDescrizione As String = If(Me.Session("AziendaDescrizione") Is Nothing, "", Me.Session("AziendaDescrizione").ToString())
	        Dim aziendaLogo As String = If(Me.Session("AziendaLogo") Is Nothing, "", Me.Session("AziendaLogo").ToString())
	        Dim aziendaLogoMobile As String = If(Me.Session("AziendaLogoMobile") Is Nothing, "", Me.Session("AziendaLogoMobile").ToString())
	        Dim credits As String = If(Me.Session("Credits") Is Nothing, "", Me.Session("Credits").ToString())
	        Dim desktopLogoUrl As String = ResolveExistingLogoAsset(aziendaLogo, ThemeManager.Asset("images/logo/logo.svg"))
	        Dim mobileLogoUrl As String = ResolveExistingLogoAsset(aziendaLogoMobile, desktopLogoUrl)
	        If mobileLogoUrl.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then mobileLogoUrl = desktopLogoUrl

        If aziendaNome <> "" Then Me.Page.Title = aziendaNome
	        Dim altLogo As String = (aziendaNome & " - " & aziendaDescrizione).Trim()

	        If imgLogoCtrl IsNot Nothing Then
	            imgLogoCtrl.ImageUrl = desktopLogoUrl
	            If altLogo <> "" Then imgLogoCtrl.AlternateText = altLogo
	        End If

	        If imgLogoMobileCtrl IsNot Nothing Then
	            imgLogoMobileCtrl.ImageUrl = mobileLogoUrl
	            imgLogoMobileCtrl.Attributes("onerror") = "this.onerror=null;this.src='" & desktopLogoUrl & "';"
	            If altLogo <> "" Then imgLogoMobileCtrl.AlternateText = altLogo
	        End If

	        If lblCreditsCtrl IsNot Nothing Then
	            lblCreditsCtrl.Text = credits
	        End If

        Dim obj3 As New HtmlLink()
        Dim cssFile As String = If(Session("css") Is Nothing, "", Session("css").ToString())
        Dim cssHref As String = TenantRuntimeAssetResolver.ResolveTenantStylesheet(cssFile, Server.MapPath("~/"))

        obj3.Attributes.Add("rel", "shortcut icon")
        obj3.Href = If(Session("IconaWeb") Is Nothing, "", Session("IconaWeb").ToString())

        If headC IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(cssHref) Then
            Dim objcss As New HtmlLink()
            objcss.Href = cssHref
            objcss.Attributes.Add("rel", "stylesheet")
            objcss.Attributes.Add("type", "text/css")
            headC.Controls.Add(objcss)
        End If
        If headC IsNot Nothing Then headC.Controls.Add(obj3)
    End Sub

    Private Function ResolveExistingLogoAsset(ByVal candidate As String, ByVal fallback As String) As String
        Dim normalized As String = NormalizeLogoAssetUrl(candidate)
        If Not String.IsNullOrWhiteSpace(normalized) AndAlso LogoAssetExists(normalized) Then Return normalized

        normalized = NormalizeLogoAssetUrl(fallback)
        If Not String.IsNullOrWhiteSpace(normalized) AndAlso LogoAssetExists(normalized) Then Return normalized

        Return InlineLogoPlaceholder()
    End Function

    Private Function BuildLogoWebAssetPath(ByVal rawFileName As Object) As String
        Dim value As String = Convert.ToString(rawFileName).Trim()
        If value = "" Then Return ThemeManager.Asset("images/logo/logo.svg")
        If value.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           value.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
           value.StartsWith("//", StringComparison.OrdinalIgnoreCase) OrElse
           value.StartsWith("data:", StringComparison.OrdinalIgnoreCase) OrElse
           value.Contains("/") OrElse
           value.Contains("\") Then
            Return ThemeManager.Asset("images/logo/logo.svg")
        End If

        Dim fileName As String = IO.Path.GetFileName(value)
        If String.IsNullOrWhiteSpace(fileName) OrElse fileName.Contains("..") OrElse fileName.Contains("/") OrElse fileName.Contains("\") Then
            Return ThemeManager.Asset("images/logo/logo.svg")
        End If

        Return "/Public/assets/images/logo/" & fileName
    End Function

    Private Function NormalizeLogoAssetUrl(ByVal value As String) As String
        Dim url As String = If(value, String.Empty).Trim()
        If url = "" Then Return String.Empty
        url = url.Replace("\", "/").Replace("images../", "images/").Replace("image../", "images/").Replace("images.../", "images/").Replace("image.../", "images/")
        url = url.Replace("/Public/assets/image/", "/Public/assets/images/").Replace("/public/assets/image/", "/public/assets/images/")
        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
           url.StartsWith("//", StringComparison.OrdinalIgnoreCase) OrElse
           url.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then
            Return url
        End If
        If url.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
            Return ResolveUrl(url)
        End If
        If Not url.StartsWith("/", StringComparison.Ordinal) Then
            url = "/" & url.TrimStart("/"c)
        End If
        Return url
    End Function

    Private Function LogoAssetExists(ByVal url As String) As Boolean
        If String.IsNullOrWhiteSpace(url) Then Return False
        If url.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
           url.StartsWith("https://", StringComparison.OrdinalIgnoreCase) OrElse
           url.StartsWith("//", StringComparison.OrdinalIgnoreCase) OrElse
           url.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then
            Return True
        End If
        Try
            Dim path As String = url
            If path.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then path = ResolveUrl(path)
            If Not path.StartsWith("/", StringComparison.Ordinal) Then path = "/" & path.TrimStart("/"c)
            Dim physical As String = Server.MapPath("~" & path)
            Return Not String.IsNullOrWhiteSpace(physical) AndAlso IO.File.Exists(physical)
        Catch
            Return False
        End Try
    End Function

    Private Function InlineLogoPlaceholder() As String
        Return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='240' height='80' viewBox='0 0 240 80'%3E%3Crect width='240' height='80' rx='10' fill='%23ffffff'/%3E%3Ctext x='20' y='48' font-family='Arial,sans-serif' font-size='30' font-weight='700' fill='%23111827'%3EKeepStore%3C/text%3E%3C/svg%3E"
    End Function

    Public Sub SettoreDefault()
        If IsNothing(Me.Session("st")) Then
            conn.Open()

            cmd.CommandType = CommandType.Text
            cmd.CommandText = "Select id from settori where predefinito = 1"

            Dim dr As MySqlDataReader = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows Then
                Me.Session("st") = dr.Item("Id")
            End If

            dr.Close()
            dr.Dispose()

            conn.Close()
            conn.Dispose()

            cmd.Dispose()
        End If
    End Sub

    '==========================================================
    ' LOGIN + AGGIORNAMENTO DATI
    '==========================================================
    Public Sub Login(ByVal user As String, ByVal pass As String)
        If Not EnsureLoginPostOrigin() Then Return
        Dim authenticationSucceeded As Boolean = False
        conn.Open()

        cmd.CommandType = CommandType.Text
        cmd.CommandText = "Select * from vlogin where AziendeID=?id and UPPER(Username)=?Username limit 0, 1"
        cmd.Parameters.Clear()
        cmd.Parameters.AddWithValue("?id", Session("AziendaID"))
        cmd.Parameters.AddWithValue("?Username", user.ToUpper())
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        ' Controlli di interfaccia login (se esistono nella master)
        Dim lblLogin As Label = TryCast(Me.FindControl("lblLogin"), Label)
        Dim tbUser As TextBox = TryCast(Me.FindControl("tbUsername"), TextBox)
        Dim tbPass As TextBox = TryCast(Me.FindControl("tbPassword"), TextBox)

        If dr.HasRows Then
            If dr.Item("Abilitato") <> 1 Then
                If lblLogin IsNot Nothing Then
                    lblLogin.Text = GenericLoginFailureMessage
                    lblLogin.Focus()
                End If
                Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType(), "prova", "<script type='text/javascript'>document.body.onload=function(){alert('" & GenericLoginFailureMessage & "')}</script>")

            ElseIf dr.Item("UtentiAbilitato") <> 1 Then
                If lblLogin IsNot Nothing Then
                    lblLogin.Text = GenericLoginFailureMessage
                    lblLogin.Focus()
                End If
                Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType(), "prova", "<script type='text/javascript'>document.body.onload=function(){alert('" & GenericLoginFailureMessage & "')}</script>")

            ElseIf dr.Item("Password").ToString().ToLower() = pass.ToLower() AndAlso
                   StorefrontCommercialIsolationPolicy.ResolveAuthenticatedPriceList(
                       StorefrontCommercialIsolationPolicy.PositiveInteger(Session("AziendaID")),
                       StorefrontCommercialIsolationPolicy.PositiveInteger(dr.Item("AziendeID")),
                       StorefrontCommercialIsolationPolicy.PositiveInteger(dr.Item("listino"))) > 0 Then
                'Login OK
                Try
                    Me.Session("AbilitaListino") = CType(dr.Item("AbilitaListino"), Integer)
                Catch
                    Me.Session("AbilitaListino") = 0
                End Try
                Me.Session("LoginId") = dr.Item("id")
                Me.Session("LoginID") = dr.Item("id")
                Me.Session("LoginEmail") = dr.Item("email")
                Me.Session("LoginNomeCognome") = dr.Item("cognomenome")

                If (dr.Item("ultimoaccesso") Is Nothing) = False Then
                    Me.Session("LoginUltimoAccesso") = dr.Item("ultimoaccesso")
                End If

                Me.Session("UtentiId") = dr.Item("utentiid")
                Me.Session("UtentiID") = dr.Item("utentiid")
                Me.Session("UtentiTipoId") = dr.Item("utentitipoid")
                Me.Session("AuthenticatedAziendaID") = dr.Item("AziendeID")
                Me.Session("genera_html_mail") = dr.Item("genera_html_mail")

                Me.Session("Listino") = dr.Item("listino")
                Me.Session("listino") = dr.Item("listino")
                ApplyAuthenticatedPriceDisplayState(dr.Item("IvaTipo"), dr.Item("IdEsenzioneIva"),
                    dr.Item("ValoreEsenzioneIva"), dr.Item("DescrizioneEsenzioneIva"), dr.Item("AbilitatoIvaReverseCharge"))
                Me.Session("DataPassword") = dr.Item("DataPassword")
                ' Cookie username (OK)
                Try
                    If Me.Session("AziendaNome") IsNot Nothing Then
                        Dim cookieName As String = Me.Session("AziendaNome").ToString()
                        If Not String.IsNullOrEmpty(cookieName) Then
                            Dim c As HttpCookie = Response.Cookies(cookieName)
                            c("Username") = user
                            c.HttpOnly = True
                            c.Secure = Request.IsSecureConnection
                            c.Path = "/"
                            Try
                                c.SameSite = SameSiteMode.Lax
                            Catch
                            End Try
                            c.Expires = DateTime.Now.AddYears(1)
                        End If
                    End If
                Catch
                End Try

                ' SECURITY: non salvare mai la password nei cookie.
                ' Elimino eventuale cookie legacy "Password" residuo.
                ExpireLegacyPasswordCookie()
                authenticationSucceeded = True

            Else
                If lblLogin IsNot Nothing Then
                    lblLogin.Text = GenericLoginFailureMessage
                End If
                If tbPass IsNot Nothing Then
                    tbPass.Focus()
                End If
                Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType(), "prova", "<script type='text/javascript'>document.body.onload=function(){alert('" & GenericLoginFailureMessage & "')}</script>")
            End If
        Else
            If lblLogin IsNot Nothing Then
                lblLogin.Text = GenericLoginFailureMessage
            End If
            If tbUser IsNot Nothing Then
                tbUser.Focus()
            End If
            Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType(), "prova", "<script type='text/javascript'>document.body.onload=function(){alert('" & GenericLoginFailureMessage & "')}</script>")
        End If

        dr.Close()
        dr.Dispose()

        conn.Close()
        conn.Dispose()

        cmd.Dispose()

        If authenticationSucceeded AndAlso CurrentLoginIdSafe() > 0 Then
            Dim authenticatedLoginId As Integer = CurrentLoginIdSafe()
            LoginAccessAuditRecorder.TryRecordSuccessfulLogin(HttpContext.Current, authenticatedLoginId)

            Try
                AggiornaDati()
            Catch ex As Exception
                KeepStoreLog.Error(
                    "login-cart-sync",
                    "Legacy post-login cart synchronization failed. Error type: " & ex.GetType().Name & ".",
                    Nothing,
                    HttpContext.Current)
            End Try

            Dim targetUrl As String = PostLoginReturnUrlPolicy.ResolvePostLoginTarget(
                HttpContext.Current,
                Request.QueryString("ReturnUrl"),
                Session.Item("Page"),
                Session.Item("Pagina_visitata"))
            PostLoginReturnUrlPolicy.ClearRememberedContext(HttpContext.Current)
            Session.Remove("Page")
            Session.Remove("Pagina_visitata")
            Response.Redirect(targetUrl, False)
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If
    End Sub

    Public Sub AggiornaDati()
        Dim loginId As Integer = CurrentLoginIdSafe()
        If loginId <= 0 Then Exit Sub

        Session("LoginID") = loginId
        Session("LoginId") = loginId

        Dim listinoLogin As Integer = 1
        Integer.TryParse(Convert.ToString(Session("Listino")), listinoLogin)
        If listinoLogin <= 0 Then Integer.TryParse(Convert.ToString(Session("listino")), listinoLogin)
        If listinoLogin <= 0 Then listinoLogin = 1

        Dim mergeResult As CartOwnershipMergeResult =
            CartOwnershipService.MergeAnonymousCartIntoAccount(HttpContext.Current, loginId, listinoLogin)
        If mergeResult Is Nothing OrElse Not mergeResult.Succeeded Then
            Throw New InvalidOperationException("Post-login cart ownership merge did not complete.")
        End If
    End Sub

    '================================================================
    '  DOCUMENTI DA SALDARE (badge "Ordini da saldare")
    '================================================================
    Private Function get_documents_toPay() As String
        ' Se non è loggato, nessun ordine da saldare
        If Session("LoginId") Is Nothing Then
            Return "0"
        End If

        Dim loginId As Integer
        Try
            loginId = CInt(Session("LoginId"))
        Catch
            Return "0"
        End Try

        Dim toPay As Integer = 0

        Try
            Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Using conn As New MySqlConnection(connString)
                conn.Open()

                Using cmd As New MySqlCommand()
                    cmd.Connection = conn
                    cmd.CommandType = CommandType.Text

                    cmd.CommandText =
                        "SELECT COUNT(*) " &
                        "FROM vdocumenti d " &
                        "INNER JOIN login l ON d.UtentiId = l.UtentiId " &
                        "WHERE l.id = ?LoginId " &
                        "AND d.TipoDocumentiId = 4 " &
                        "AND d.StatiId <> 0 " &
                        "AND d.StatiId <> 3 " &
                        "AND d.Pagato = 0 " &
                        "AND d.PagamentiTipoOnline <> 0"

                    cmd.Parameters.AddWithValue("?LoginId", loginId)

                    Dim result As Object = cmd.ExecuteScalar()
                    If result IsNot Nothing AndAlso Not IsDBNull(result) Then
                        toPay = Convert.ToInt32(result)
                    End If
                End Using
            End Using

        Catch
            ' Non faccio cadere il sito per il badge
            toPay = 0
        End Try

        Return toPay.ToString()
    End Function

    '==========================================================
    ' CARRELLO HEADER (quantità + totale) - HARDENED
    '==========================================================
    Public Sub LeggiCarrello()
        Dim lblCarrelloCountCtrl As Label = FindCtrl(Of Label)("lblCarrelloCount")
        Dim lblCarrelloCountMobileCtrl As Label = FindCtrl(Of Label)("lblCarrelloCountMobile")
        Dim lblCarrelloTotaleCtrl As Label = FindCtrl(Of Label)("lblCarrelloTotale")
        ' Reset di default
        If lblCarrelloCountCtrl IsNot Nothing Then
            If lblCarrelloCountCtrl IsNot Nothing Then lblCarrelloCountCtrl.Text = "0"
        End If
        If lblCarrelloCountMobileCtrl IsNot Nothing Then lblCarrelloCountMobileCtrl.Text = "0"
        If lblCarrelloTotaleCtrl IsNot Nothing Then
            If lblCarrelloTotaleCtrl IsNot Nothing Then lblCarrelloTotaleCtrl.Text = "0,00"
        End If

        Session("Carrello_Quantita") = 0
        Session("Carrello_Totale_Merce") = 0D

        Dim cartReadModel As CartAuthoritativeReadModel = CartAuthoritativeReadModel.GetCurrent(HttpContext.Current)
        Dim cartSnapshot As CartStateSnapshotProvider = CartStateSnapshotProvider.GetCurrent(HttpContext.Current)

        ' Tipo IVA: 1 = imponibile, 2 = ivato. Default 2 se non impostato.
        Dim ivaTipoLocal As Integer = 2
        If Not IsNothing(Me.Session("IvaTipo")) AndAlso IsNumeric(Me.Session("IvaTipo")) Then
            ivaTipoLocal = CInt(Me.Session("IvaTipo"))
        End If

        Try
            Dim quantity As Decimal = cartReadModel.TotalQuantity
            Dim qVal As Integer = Convert.ToInt32(Decimal.Truncate(quantity))
            Dim totDec As Decimal = If(ivaTipoLocal = 1, cartReadModel.TotalNet, cartReadModel.TotalGross)

            Session("Carrello_Quantita") = qVal
            Session("Carrello_Totale_Merce") = Convert.ToDouble(totDec)
            If lblCarrelloCountCtrl IsNot Nothing Then lblCarrelloCountCtrl.Text = qVal.ToString()
            If lblCarrelloCountMobileCtrl IsNot Nothing Then lblCarrelloCountMobileCtrl.Text = qVal.ToString()
            If lblCarrelloTotaleCtrl IsNot Nothing Then lblCarrelloTotaleCtrl.Text = totDec.ToString("N2")
        Catch
            ' In caso di errore nel read model: lascia i valori a 0.
            If lblCarrelloCountCtrl IsNot Nothing Then
                If lblCarrelloCountCtrl IsNot Nothing Then lblCarrelloCountCtrl.Text = "0"
            End If
            If lblCarrelloCountMobileCtrl IsNot Nothing Then lblCarrelloCountMobileCtrl.Text = "0"
            If lblCarrelloTotaleCtrl IsNot Nothing Then
                If lblCarrelloTotaleCtrl IsNot Nothing Then lblCarrelloTotaleCtrl.Text = "0,00"
            End If
            Session("Carrello_Quantita") = 0
            Session("Carrello_Totale_Merce") = 0D
        End Try

        PublishCartProductState(cartSnapshot)
    End Sub

    Private Sub PublishEmptyCartProductState()
        Try
            Dim lit As Literal = FindCtrl(Of Literal)("litCartStateScript")
            If lit IsNot Nothing Then
                lit.Text = "<script>window.KeepStoreCartState={items:[]};</script>"
            End If
        Catch
        End Try
    End Sub

    Private Sub PublishCartProductState(ByVal snapshot As CartStateSnapshotProvider)
        Try
            Dim items As New List(Of Dictionary(Of String, Object))()
            If snapshot IsNot Nothing Then
                For Each snapshotItem As CartStateSnapshotItem In snapshot.Items
                    If snapshotItem Is Nothing OrElse snapshotItem.ArticleId <= 0 OrElse snapshotItem.Quantity <= 0D Then Continue For

                    Dim item As New Dictionary(Of String, Object)()
                    item("id") = snapshotItem.ArticleId.ToString(System.Globalization.CultureInfo.InvariantCulture)
                    item("tcid") = snapshotItem.TCId.ToString(System.Globalization.CultureInfo.InvariantCulture)
                    item("qty") = snapshotItem.Quantity
                    item("key") = snapshotItem.ArticleId.ToString(System.Globalization.CultureInfo.InvariantCulture) & ":" & snapshotItem.TCId.ToString(System.Globalization.CultureInfo.InvariantCulture)
                    items.Add(item)
                Next
            End If

            Dim lit As Literal = FindCtrl(Of Literal)("litCartStateScript")
            If lit IsNot Nothing Then
                Dim js As New System.Web.Script.Serialization.JavaScriptSerializer()
                lit.Text = "<script>window.KeepStoreCartState={items:" & js.Serialize(items) & "};</script>"
            End If
        Catch
            PublishEmptyCartProductState()
        End Try
    End Sub

    Private Sub BindCartFeedback(ByVal snapshot As CartStateSnapshotProvider)
        Dim panel As Panel = FindCtrl(Of Panel)("pnlCartFeedbackToast")
        If panel IsNot Nothing Then panel.Visible = False

        Try
            Dim kind As String = Convert.ToString(Session(CartFeedbackKindKey)).Trim().ToLowerInvariant()
            If kind <> "single" AndAlso kind <> "multi" Then Return

            Dim createdUtc As DateTime
            If Not DateTime.TryParse(Convert.ToString(Session(CartFeedbackCreatedUtcKey)),
                                     System.Globalization.CultureInfo.InvariantCulture,
                                     System.Globalization.DateTimeStyles.RoundtripKind,
                                     createdUtc) Then
                Return
            End If
            createdUtc = createdUtc.ToUniversalTime()
            Dim feedbackAge As TimeSpan = DateTime.UtcNow.Subtract(createdUtc)
            If feedbackAge.TotalSeconds < -30 OrElse feedbackAge.TotalMinutes > 2 Then Return

            Dim successfulCount As Integer = 0
            Integer.TryParse(Convert.ToString(Session(CartFeedbackCountKey)), successfulCount)
            If successfulCount <= 0 OrElse snapshot Is Nothing Then Return

            Dim title As String
            Dim message As String
            Dim currentQuantity As Decimal = 0D

            If kind = "single" Then
                Dim articleId As Integer = 0
                Dim tcId As Integer = -1
                Integer.TryParse(Convert.ToString(Session(CartFeedbackArticleIdKey)), articleId)
                Integer.TryParse(Convert.ToString(Session(CartFeedbackTcidKey)), tcId)
                If articleId <= 0 Then Return

                If tcId > 0 Then
                    currentQuantity = snapshot.GetQuantity(articleId, tcId)
                Else
                    currentQuantity = snapshot.GetArticleQuantity(articleId)
                End If
                If currentQuantity <= 0D Then Return

                Dim productName As String = Convert.ToString(Session(CartFeedbackProductNameKey)).Trim()
                If productName = "" Then productName = "Il prodotto"
                title = "Prodotto aggiunto al carrello"
                message = productName & " è stato aggiunto al tuo carrello."
            Else
                For Each item As CartStateSnapshotItem In snapshot.Items
                    If item IsNot Nothing AndAlso item.Quantity > 0D Then currentQuantity += item.Quantity
                Next
                If currentQuantity <= 0D Then Return

                title = "Prodotti aggiunti al carrello"
                message = successfulCount.ToString(System.Globalization.CultureInfo.GetCultureInfo("it-IT")) & " prodotti sono stati aggiunti al tuo carrello."
            End If

            Dim titleLiteral As Literal = FindCtrl(Of Literal)("litCartFeedbackTitle")
            Dim messageLiteral As Literal = FindCtrl(Of Literal)("litCartFeedbackMessage")
            Dim stateLiteral As Literal = FindCtrl(Of Literal)("litCartFeedbackState")
            If panel Is Nothing OrElse titleLiteral Is Nothing OrElse messageLiteral Is Nothing OrElse stateLiteral Is Nothing Then Return

            titleLiteral.Text = title
            messageLiteral.Text = message
            stateLiteral.Text = "Nel carrello attivo: " & FormatCartFeedbackQuantity(currentQuantity) & " pz."
            panel.Visible = True
        Finally
            ClearCartFeedbackSession()
        End Try
    End Sub

    Private Function FormatCartFeedbackQuantity(ByVal quantity As Decimal) As String
        Dim culture As System.Globalization.CultureInfo = System.Globalization.CultureInfo.GetCultureInfo("it-IT")
        If Decimal.Truncate(quantity) = quantity Then Return quantity.ToString("0", culture)
        Return quantity.ToString("0.##", culture)
    End Function

    Private Sub ClearCartFeedbackSession()
        Session.Remove(CartFeedbackKindKey)
        Session.Remove(CartFeedbackProductNameKey)
        Session.Remove(CartFeedbackArticleIdKey)
        Session.Remove(CartFeedbackTcidKey)
        Session.Remove(CartFeedbackCountKey)
        Session.Remove(CartFeedbackCreatedUtcKey)
    End Sub

    ' Metodo pubblico comodo da usare dalle pagine figlie

    '==========================================================
    ' META TAG SEO
    '==========================================================
    Sub Meta()
        Dim headC As Control = GetHeadDynamicContainer()
    ' Meta legacy: mantiene compatibilità, ma NON sovrascrive i meta tag se già presenti nella pagina contenuto.
    Dim description As String = Me.Page.Title
    description = Regex.Replace(description, "<[^>]*>", "")

    If description.Length > 255 Then
        description = description.Substring(0, 255)
    End If

    If Not HeaderHasMeta("description") Then
        Dim metaDescription As New HtmlMeta()
        metaDescription.Name = "description"
        metaDescription.Content = description
        If headC IsNot Nothing Then headC.Controls.Add(metaDescription)
    End If

    Dim keywords As String = Me.Page.Title
    keywords = keywords.Replace(" ", ",")

    If Not HeaderHasMeta("keywords") Then
        Dim metaKeywords As New HtmlMeta()
        metaKeywords.Name = "keywords"
        metaKeywords.Content = keywords
        If headC IsNot Nothing Then headC.Controls.Add(metaKeywords)
    End If
End Sub


    '==========================================================
    ' CERCA Cerca() harden + URL encode
    '==========================================================
    Public Sub Cerca()
        Cerca(False)
    End Sub

    Private Sub Cerca(ByVal preferMobile As Boolean)
        Dim tbCercaCtrl As TextBox = FindCtrl(Of TextBox)("tbCerca")
        Dim tbCercaMobileCtrl As TextBox = FindCtrl(Of TextBox)("tbCercaMobile")
        Dim ddlDesktop As DropDownList = FindCtrl(Of DropDownList)("product_cat")
        Dim ddlMobile As DropDownList = FindCtrl(Of DropDownList)("product_cat_mobile")
        Dim q As String = ""
        Dim selectedUrl As String = String.Empty

        Dim primaryText As TextBox = If(preferMobile, tbCercaMobileCtrl, tbCercaCtrl)
        Dim fallbackText As TextBox = If(preferMobile, tbCercaCtrl, tbCercaMobileCtrl)
        Dim primaryScope As DropDownList = If(preferMobile, ddlMobile, ddlDesktop)
        Dim fallbackScope As DropDownList = If(preferMobile, ddlDesktop, ddlMobile)

        If primaryText IsNot Nothing Then
            q = primaryText.Text.Trim()
        ElseIf fallbackText IsNot Nothing Then
            q = fallbackText.Text.Trim()
        End If

        If primaryScope IsNot Nothing Then
            selectedUrl = primaryScope.SelectedValue.Trim()
        ElseIf fallbackScope IsNot Nothing Then
            selectedUrl = fallbackScope.SelectedValue.Trim()
        End If

        Dim targetUrl As String = If(String.IsNullOrWhiteSpace(selectedUrl), "articoli.aspx", selectedUrl)

        If Not String.IsNullOrWhiteSpace(q) Then
            Dim separator As String = If(targetUrl.Contains("?"), "&", "?")
            targetUrl &= separator & "q=" & System.Web.HttpUtility.UrlEncode(q)
        End If

        Me.Response.Redirect(targetUrl)
    End Sub

    Protected Sub tbCercaMobile_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        Cerca(True)
    End Sub


    '==========================================================
    ' IVA VETTORE DEFAULT
    '==========================================================
    Function IvaVettoreDefault(ByVal AziendaId As Integer) As Double
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim temp_iva As Double = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT vettori.*, iva.Valore " &
                          "FROM vettori LEFT JOIN iva ON vettori.iva=iva.id " &
                          "WHERE vettori.Predefinito=1 AND vettori.AziendeID=@aziendaId"
        cmd.Parameters.Clear()
        cmd.Parameters.AddWithValue("@aziendaId", AziendaId)

        dr = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows = True Then
            temp_iva = CDbl(dr.Item("Valore"))
        End If

        dr.Close()
        conn.Close()

        Return temp_iva
    End Function

    '==========================================================
    ' FOOTER DIV (menu informativi)
    '==========================================================




    '==========================================================
    ' FACEBOOK POPUP COOKIE
    '==========================================================
    Protected Sub LB_CancelFacebook_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles LB_CancelFacebook.Click
        Session("MiPiaceFacebook") = 1

        'Creo un Cookie per nascondere il mi piace per una settimana
        CreateCookiesLikeFacebook()

        Response.Redirect(Request.UrlReferrer.AbsoluteUri)
    End Sub

    Private Sub CreateCookiesLikeFacebook()
        If Request.Cookies("FacebookLike") Is Nothing Then
            Dim aCookie As New HttpCookie("FacebookLike")
            aCookie.Values("Nascondi") = 1
            aCookie.Expires = DateTime.Now.AddDays(7)
            Response.Cookies.Add(aCookie)
        Else
            Dim cookie As HttpCookie = HttpContext.Current.Request.Cookies("FacebookLike")
            cookie.Values("Nascondi") = 1
            cookie.Expires = DateTime.Now.AddDays(-30)
            Response.Cookies.Add(cookie)
        End If
    End Sub



    ' ============================================================
    ' SEARCH (header) - button click
    ' ============================================================
    Protected Sub btnSearch_ServerClick(ByVal sender As Object, ByVal e As System.EventArgs)
        Try
            Dim button As HtmlButton = TryCast(sender, HtmlButton)
            Cerca(button IsNot Nothing AndAlso button.ID = "btnSearchMobile")
        Catch ex As Exception
            ' fail-safe: non interrompe la pagina
        End Try
    End Sub



    '------------------------------------------------------------
    ' Utility: HTML encode per binding in markup (prevenzione XSS)
    '------------------------------------------------------------
    Public Function SafeText(ByVal value As Object) As String
        Dim s As String = Convert.ToString(value)
        If s Is Nothing Then s = String.Empty
        Return System.Web.HttpUtility.HtmlEncode(s)
    End Function



End Class
