Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Web
Imports System.Web.Configuration

' AUTH-STAY-SIGNED-IN-2B, fase 2: collega "Resta collegato" alle pagine (cookie, chiave di configurazione, sessione).
' Il servizio KeepStoreStaySignedIn resta autonomo; qui sta tutto cio che tocca la richiesta. Regole (.ai-review/auth-stay-signed-in-2b/decisione.md):
' - La funzione e ACCESA solo con la chiave KeepStore.StaySignedIn.Enabled = true (assente = spenta) E con la tabella presente.
' - La chiave spenta ferma casella, emissione e ripristino; uscita e cambio password annullano e cancellano SEMPRE.
' - Nessun metodo lancia eccezioni verso la pagina; mai codici, password o impronte nei registri.
Public NotInheritable Class KeepStoreStaySignedInWeb
    Private Sub New()
    End Sub

    Public Const EnabledSettingName As String = "KeepStore.StaySignedIn.Enabled"
    Public Const HopCookieName As String = "__Host-KeepStoreStayHop"
    Public Const HopSeconds As Integer = 60
    Public Const RestoredSessionKey As String = "KeepStore:StaySignedIn:Restored"
    Public Const SkipSessionKey As String = "KeepStore:StaySignedIn:Skip"
    Public Const NextTouchSessionKey As String = "KeepStore:StaySignedIn:NextTouchUtc"
    Public Const FreshSignInMessage As String = "Per sicurezza, per modificare i dati di accesso devi prima accedere di nuovo con la password. Esci e accedi di nuovo, poi ripeti la modifica."

    Public Shared Function IsEnabled() As Boolean
        Try
            Return String.Equals(Convert.ToString(ConfigurationManager.AppSettings(EnabledSettingName)).Trim(), "true", StringComparison.OrdinalIgnoreCase)
        Catch
            Return False
        End Try
    End Function

    Public Shared Function ConnectionText() As String
        Try
            Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            Return If(settings Is Nothing, String.Empty, If(settings.ConnectionString, String.Empty))
        Catch
            Return String.Empty
        End Try
    End Function

    Public Shared Function DatabaseScope() As String
        Return StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey()
    End Function

    ' Accesa e utilizzabile: chiave, tabella e nessuna sospensione in corso.
    Public Shared Function IsActive() As Boolean
        Return IsEnabled() AndAlso KeepStoreStaySignedIn.IsAvailable(ConnectionText()) AndAlso Not KeepStoreStaySignedIn.IsSuspended()
    End Function

    ' ---------------------------------------------------------------- cookie

    Public Shared Function ReadCookie(ByVal context As HttpContext) As String
        Try
            If context Is Nothing OrElse context.Request Is Nothing Then Return String.Empty
            Dim cookie As HttpCookie = context.Request.Cookies(KeepStoreStaySignedIn.CookieName)
            Return If(cookie Is Nothing, String.Empty, If(cookie.Value, String.Empty))
        Catch
            Return String.Empty
        End Try
    End Function

    Private Shared Function BuildCookie(ByVal name As String, ByVal value As String, ByVal expires As DateTime) As HttpCookie
        ' Prefisso __Host-: solo HTTPS, percorso radice, nessun dominio; non leggibile dagli script; non inviato da altri siti nei POST.
        Return New HttpCookie(name, value) With {.Path = "/", .Secure = True, .HttpOnly = True, .SameSite = SameSiteMode.Lax, .Expires = expires}
    End Function

    Public Shared Function WriteCookie(ByVal context As HttpContext, ByVal value As String) As Boolean
        Try
            If context Is Nothing OrElse String.IsNullOrEmpty(value) OrElse Not context.Request.IsSecureConnection Then Return False
            context.Response.Cookies.Set(BuildCookie(KeepStoreStaySignedIn.CookieName, value, DateTime.UtcNow.AddDays(KeepStoreStaySignedIn.LifetimeDays)))
            Return True
        Catch
            Return False
        End Try
    End Function

    Public Shared Sub ClearCookie(ByVal context As HttpContext)
        Try
            If context Is Nothing Then Return
            context.Response.Cookies.Set(BuildCookie(KeepStoreStaySignedIn.CookieName, String.Empty, New DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc)))
        Catch
        End Try
    End Sub

    Public Shared Function HasHopCookie(ByVal context As HttpContext) As Boolean
        Try
            Return context IsNot Nothing AndAlso context.Request.Cookies(HopCookieName) IsNot Nothing
        Catch
            Return False
        End Try
    End Function

    Public Shared Sub SetHopCookie(ByVal context As HttpContext)
        Try
            context.Response.Cookies.Set(BuildCookie(HopCookieName, "1", DateTime.UtcNow.AddSeconds(HopSeconds)))
        Catch
        End Try
    End Sub

    Public Shared Sub ClearHopCookie(ByVal context As HttpContext)
        Try
            context.Response.Cookies.Set(BuildCookie(HopCookieName, String.Empty, New DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc)))
        Catch
        End Try
    End Sub

    Public Shared Function SessionCookieName() As String
        Try
            Dim section As SessionStateSection = TryCast(WebConfigurationManager.GetSection("system.web/sessionState"), SessionStateSection)
            If section IsNot Nothing AndAlso Not String.IsNullOrEmpty(section.CookieName) Then Return section.CookieName
        Catch
        End Try
        Return "ASP.NET_SessionId"
    End Function

    ' Il browser ha INVIATO un cookie di sessione? Si legge l'intestazione grezza: appena il sito crea una sessione nuova, ASP.NET aggiunge
    ' il suo cookie anche all'elenco dei cookie della richiesta, che quindi non distingue i due casi. Nel dubbio = si (si cambia sessione).
    Public Shared Function HasSessionCookie(ByVal context As HttpContext) As Boolean
        Try
            Dim header As String = context.Request.Headers("Cookie")
            If String.IsNullOrEmpty(header) Then Return False
            Dim prefix As String = SessionCookieName() & "="
            For Each part As String In header.Split(";"c)
                If part.Trim().StartsWith(prefix, StringComparison.Ordinal) Then Return True
            Next
            Return False
        Catch
            Return True
        End Try
    End Function

    ' Intestazione scritta direttamente: quando la sessione viene abbandonata ASP.NET toglie il proprio cookie dall'elenco della risposta,
    ' e con esso sparirebbe anche la scadenza.
    Public Shared Sub ExpireSessionCookie(ByVal context As HttpContext)
        Try
            Dim name As String = SessionCookieName()
            For Each ch As Char In name
                If Not (Char.IsLetterOrDigit(ch) OrElse ch = "."c OrElse ch = "_"c OrElse ch = "-"c) Then Return
            Next
            context.Response.AppendHeader("Set-Cookie", name & "=; expires=Sat, 01 Jan 2000 00:00:00 GMT; path=/; HttpOnly" &
                If(context.Request.IsSecureConnection, "; secure", String.Empty))
        Catch
        End Try
    End Sub

    ' ---------------------------------------------------------------- marcatori di sessione

    Private Shared Function SessionFlag(ByVal context As HttpContext, ByVal key As String) As Boolean
        Try
            Return context IsNot Nothing AndAlso context.Session IsNot Nothing AndAlso TypeOf context.Session(key) Is Boolean AndAlso CBool(context.Session(key))
        Catch
            Return False
        End Try
    End Function

    Public Shared Function IsSkippedInThisSession(ByVal context As HttpContext) As Boolean
        Return SessionFlag(context, SkipSessionKey)
    End Function

    Public Shared Sub SkipInThisSession(ByVal context As HttpContext)
        Try
            context.Session(SkipSessionKey) = True
        Catch
        End Try
    End Sub

    Public Shared Sub MarkRestored(ByVal context As HttpContext)
        Try
            context.Session(RestoredSessionKey) = True
            context.Session(NextTouchSessionKey) = DateTime.UtcNow.AddHours(KeepStoreStaySignedIn.RenewAfterHours)
        Catch
        End Try
    End Sub

    ' La sessione nasce da un dispositivo ricordato, non da una password digitata: le modifiche ai dati di accesso chiedono un accesso nuovo.
    Public Shared Function RequiresFreshSignIn(ByVal context As HttpContext) As Boolean
        Return SessionFlag(context, RestoredSessionKey)
    End Function

    ' ---------------------------------------------------------------- ciclo di vita

    ' Dopo un accesso riuscito con la password. Il dispositivo gia presente nel browser si annulla sempre; con la casella se ne crea uno nuovo.
    Public Shared Sub AfterSignIn(ByVal context As HttpContext, ByVal companyId As Integer, ByVal loginId As Integer, ByVal wantsStay As Boolean)
        Try
            If context Is Nothing OrElse context.Session Is Nothing Then Return
            context.Session.Remove(RestoredSessionKey)
            context.Session.Remove(SkipSessionKey)
            context.Session.Remove(NextTouchSessionKey)
            Dim previous As String = ReadCookie(context)
            If previous.Length > 0 Then
                KeepStoreStaySignedIn.Revoke(ConnectionText(), DatabaseScope(), companyId, previous, "replaced")
                ClearCookie(context)
            End If
            If Not wantsStay OrElse companyId <= 0 OrElse loginId <= 0 OrElse Not context.Request.IsSecureConnection OrElse Not IsActive() Then Return
            Dim issued As String = KeepStoreStaySignedIn.Issue(ConnectionText(), DatabaseScope(), companyId, loginId)
            If issued.Length = 0 Then Return
            If WriteCookie(context, issued) Then context.Session(NextTouchSessionKey) = DateTime.UtcNow.AddHours(KeepStoreStaySignedIn.RenewAfterHours)
        Catch
        End Try
    End Sub

    ' Uscita: annulla il dispositivo di questo browser per l'azienda dell'host e cancella il cookie comunque. Vale anche a funzione spenta.
    Public Shared Sub SignOut(ByVal context As HttpContext)
        Try
            If context Is Nothing Then Return
            If HasHopCookie(context) Then ClearHopCookie(context)
            Dim current As String = ReadCookie(context)
            If current.Length = 0 Then Return
            ClearCookie(context)
            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
            If tenant Is Nothing OrElse tenant.CompanyId <= 0 Then Return
            KeepStoreStaySignedIn.Revoke(ConnectionText(), DatabaseScope(), tenant.CompanyId, current, "logout")
        Catch
        End Try
    End Sub

    ' Cambio della password dal sito: tutti i dispositivi di quell'accesso si annullano; il cookie di questo browser si cancella.
    Public Shared Sub PasswordChanged(ByVal context As HttpContext, ByVal loginId As Integer)
        Try
            KeepStoreStaySignedIn.RevokeAllForLogin(ConnectionText(), loginId, "password")
            If context IsNot Nothing AndAlso ReadCookie(context).Length > 0 Then ClearCookie(context)
        Catch
        End Try
    End Sub

    ' Uso durante una sessione collegata: al massimo un controllo ogni 24 ore per sessione; se la scadenza e stata rinnovata il cookie si riemette.
    Public Shared Sub TouchIfDue(ByVal context As HttpContext, ByVal companyId As Integer, ByVal loginId As Integer)
        Try
            If context Is Nothing OrElse context.Session Is Nothing OrElse companyId <= 0 OrElse loginId <= 0 Then Return
            Dim current As String = ReadCookie(context)
            If current.Length = 0 OrElse Not IsEnabled() Then Return
            Dim nextTouch As Object = context.Session(NextTouchSessionKey)
            If TypeOf nextTouch Is DateTime AndAlso DateTime.UtcNow < CDate(nextTouch) Then Return
            context.Session(NextTouchSessionKey) = DateTime.UtcNow.AddHours(KeepStoreStaySignedIn.RenewAfterHours)
            If KeepStoreStaySignedIn.Touch(ConnectionText(), DatabaseScope(), companyId, loginId, current) Then WriteCookie(context, current)
        Catch
        End Try
    End Sub
End Class
