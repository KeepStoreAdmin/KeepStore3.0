Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Security.Cryptography
Imports System.Text
Imports System.Threading
Imports System.Web
Imports System.Web.Caching

' AUTH-LOGIN-SESSION-RENEW-1A: dopo l'accesso con password il cliente riceve un identificativo di sessione NUOVO
' (contro la fissazione della sessione). La password esiste solo nella richiesta dell'accesso: l'identita verificata
' passa alla sessione nuova con un biglietto monouso tenuto in memoria dal server (stesso schema di cambio sessione
' del ripristino "Resta collegato"). Regole (.ai-review/AUTH-LOGIN-SESSION-RENEW-1A/decisione.md):
' - il biglietto porta SOLO l'identita (accesso e utente) e un elenco chiuso di valori tipizzati: mai l'intera sessione
'   (porterebbe il token del carrello anonimo e valori derivati dal vecchio identificativo);
' - il cookie del biglietto non contiene dati: solo una chiave casuale; la memoria tiene l'oggetto sotto l'impronta della chiave;
' - consumo: solo GET di login.aspx?k=1, senza cookie di sessione nella richiesta, con sessione nuova e identificativo
'   diverso da quello di prima; il prelievo dalla memoria e atomico e brucia SEMPRE il biglietto;
' - al massimo 3 biglietti pendenti per account (il piu vecchio e sostituito), scadenza assoluta di 60 secondi;
' - fallimento chiuso: se il rinnovo non si completa la sessione vecchia non resta collegata.
' Solo con connessione sicura (il prefisso __Host- lo richiede): su connessione non sicura il comportamento resta quello di prima.

Public Enum SignInRenewOutcome
    NotSupported = 0
    Renewed = 1
    Failed = 2
End Enum

Public NotInheritable Class SignInTicket
    Public Property LoginId As Integer
    Public Property UtentiId As Integer
    Public Property Host As String
    Public Property OldSessionFingerprint As String
    Public Property Target As String
    Public Property ExpiresUtc As DateTime
    Public Property Extras As Dictionary(Of String, Object)
End Class

Public NotInheritable Class KeepStoreSignInSessionRenew
    Public Const CookieName As String = "__Host-KeepStoreSignIn"
    Public Const QueryName As String = "k"
    Public Const QueryValue As String = "1"
    Public Const LifetimeSeconds As Integer = 60
    Public Const MaxPendingPerAccount As Integer = 3

    Private Const CachePrefix As String = "KeepStore:SignInTicket:"
    Private Const ConsumedItemKey As String = "KeepStore:SignInTicket:Consumed"

    ' Valori che l'accesso scrive e la rivalidazione della master non idrata, piu i due messaggi dell'unione del carrello.
    Private Shared ReadOnly AllowedExtraKeys As String() = {
        "AbilitaListino", "LoginEmail", "LoginNomeCognome", "LoginUltimoAccesso", "genera_html_mail",
        "DataPassword", "CanOrder", "ScadenzaPassword", "CartPriceRevalidationMessage", "CartPriceRevalidationChanged"}

    Private Shared ReadOnly PendingLock As New Object()
    Private Shared ReadOnly Pending As New Dictionary(Of Integer, List(Of String))()

    Private Sub New()
    End Sub

    Public Shared Function IsSupported(ByVal context As HttpContext) As Boolean
        Try
            Return context IsNot Nothing AndAlso context.Session IsNot Nothing AndAlso context.Request.IsSecureConnection
        Catch
            Return False
        End Try
    End Function

    ' ---------------------------------------------------------------- emissione (richiesta dell'accesso)

    ' Da chiamare dopo audit, "Resta collegato" e unione del carrello, con la sessione ancora intatta. Renewed = la sessione vecchia e
    ' abbandonata, il cookie di sessione e scaduto e il cookie del biglietto e scritto: il chiamante rinvia a login.aspx?k=1.
    ' Failed = nessun biglietto utilizzabile: il chiamante deve togliere l'identita e abbandonare la sessione.
    Public Shared Function TryRenewAfterSignIn(ByVal context As HttpContext, ByVal loginId As Integer, ByVal utentiId As Integer,
                                               ByVal target As String) As SignInRenewOutcome
        If Not IsSupported(context) Then Return SignInRenewOutcome.NotSupported
        Try
            If loginId <= 0 OrElse utentiId <= 0 Then Return SignInRenewOutcome.Failed
            Dim nonce As String = NewNonce()
            Dim ticket As SignInTicket = BuildTicket(context, loginId, utentiId, target)
            Store(nonce, ticket)
            context.Session.Abandon()
            KeepStoreStaySignedInWeb.ExpireSessionCookie(context)
            context.Response.Cookies.Set(BuildCookie(nonce, DateTime.UtcNow.AddSeconds(LifetimeSeconds)))
            Return SignInRenewOutcome.Renewed
        Catch abortEx As ThreadAbortException
            Throw
        Catch
            Return SignInRenewOutcome.Failed
        End Try
    End Function

    Public Shared Function RenewRedirectUrl(ByVal loginPageUrl As String) As String
        Return loginPageUrl & "?" & QueryName & "=" & QueryValue
    End Function

    ' ---------------------------------------------------------------- consumo (login.aspx?k=1, prima della master)

    Public Shared Function IsRenewRequest(ByVal context As HttpContext) As Boolean
        Try
            Return context IsNot Nothing AndAlso
                String.Equals(context.Request.HttpMethod, "GET", StringComparison.Ordinal) AndAlso
                String.Equals(Convert.ToString(context.Request.QueryString(QueryName)), QueryValue, StringComparison.Ordinal)
        Catch
            Return False
        End Try
    End Function

    ' True = biglietto valido consumato: l'identita va scritta con ApplyIdentity. In ogni altro caso il biglietto e bruciato.
    Public Shared Function TryConsume(ByVal context As HttpContext, ByRef ticket As SignInTicket) As Boolean
        ticket = Nothing
        Try
            If context Is Nothing OrElse context.Session Is Nothing Then Return False
            Dim cookie As HttpCookie = context.Request.Cookies(CookieName)
            If cookie Is Nothing Then Return False
            Dim nonce As String = If(cookie.Value, String.Empty)
            ClearCookie(context)
            If Not IsWellFormedNonce(nonce) Then Return False
            Dim taken As SignInTicket = TakeFromCache(nonce)
            If taken Is Nothing Then Return False
            If Not IsRenewRequest(context) Then Return False
            If KeepStoreStaySignedInWeb.HasSessionCookie(context) Then Return False
            If Not context.Session.IsNewSession Then Return False
            If taken.ExpiresUtc <= DateTime.UtcNow Then Return False
            If Not String.Equals(taken.Host, context.Request.Url.Host, StringComparison.OrdinalIgnoreCase) Then Return False
            If String.Equals(taken.OldSessionFingerprint, FingerprintSession(context.Session.SessionID), StringComparison.Ordinal) Then Return False
            ticket = taken
            context.Items(ConsumedItemKey) = taken
            Return True
        Catch
            ticket = Nothing
            Return False
        End Try
    End Function

    Public Shared Function ConsumedTicket(ByVal context As HttpContext) As SignInTicket
        Try
            Return If(context Is Nothing, Nothing, TryCast(context.Items(ConsumedItemKey), SignInTicket))
        Catch
            Return Nothing
        End Try
    End Function

    ' Solo l'identita: la rivalidazione della master (a ogni richiesta, su vlogin) idrata azienda, listino e IVA.
    Public Shared Sub ApplyIdentity(ByVal context As HttpContext, ByVal ticket As SignInTicket)
        If context Is Nothing OrElse context.Session Is Nothing OrElse ticket Is Nothing Then Return
        context.Session("LoginId") = ticket.LoginId
        context.Session("LoginID") = ticket.LoginId
        context.Session("UtentiId") = ticket.UtentiId
        context.Session("UtentiID") = ticket.UtentiId
    End Sub

    ' Dopo la rivalidazione riuscita: i valori che l'accesso aveva scritto (elenco chiuso).
    Public Shared Sub ApplyExtras(ByVal context As HttpContext, ByVal ticket As SignInTicket)
        If context Is Nothing OrElse context.Session Is Nothing OrElse ticket Is Nothing OrElse ticket.Extras Is Nothing Then Return
        For Each key As String In AllowedExtraKeys
            Dim value As Object = Nothing
            If ticket.Extras.TryGetValue(key, value) Then context.Session(key) = value
        Next
    End Sub

    Public Shared Sub ClearCookie(ByVal context As HttpContext)
        Try
            If context Is Nothing Then Return
            context.Response.Cookies.Set(BuildCookie(String.Empty, New DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc)))
        Catch
        End Try
    End Sub

    ' ---------------------------------------------------------------- memoria del biglietto

    Private Shared Function BuildTicket(ByVal context As HttpContext, ByVal loginId As Integer, ByVal utentiId As Integer,
                                        ByVal target As String) As SignInTicket
        Dim extras As New Dictionary(Of String, Object)(StringComparer.Ordinal)
        For Each key As String In AllowedExtraKeys
            Dim value As Object = context.Session(key)
            If value IsNot Nothing AndAlso IsPlainValue(value) Then extras(key) = value
        Next
        Return New SignInTicket() With {
            .LoginId = loginId,
            .UtentiId = utentiId,
            .Host = context.Request.Url.Host,
            .OldSessionFingerprint = FingerprintSession(context.Session.SessionID),
            .Target = If(String.IsNullOrWhiteSpace(target), "~/Default.aspx", target),
            .ExpiresUtc = DateTime.UtcNow.AddSeconds(LifetimeSeconds),
            .Extras = extras}
    End Function

    Private Shared Function IsPlainValue(ByVal value As Object) As Boolean
        Return TypeOf value Is String OrElse TypeOf value Is Integer OrElse TypeOf value Is Long OrElse TypeOf value Is Short OrElse
               TypeOf value Is Byte OrElse TypeOf value Is Boolean OrElse TypeOf value Is DateTime OrElse
               TypeOf value Is Decimal OrElse TypeOf value Is Double OrElse TypeOf value Is DBNull
    End Function

    Private Shared Sub Store(ByVal nonce As String, ByVal ticket As SignInTicket)
        Dim key As String = CacheKey(nonce)
        SyncLock PendingLock
            Dim list As List(Of String) = Nothing
            If Not Pending.TryGetValue(ticket.LoginId, list) Then
                list = New List(Of String)()
                Pending(ticket.LoginId) = list
            End If
            list.RemoveAll(Function(k As String) HttpRuntime.Cache.Get(k) Is Nothing)
            While list.Count >= MaxPendingPerAccount
                HttpRuntime.Cache.Remove(list(0))
                list.RemoveAt(0)
            End While
            HttpRuntime.Cache.Insert(key, ticket, Nothing, ticket.ExpiresUtc, Cache.NoSlidingExpiration, CacheItemPriority.NotRemovable, Nothing)
            list.Add(key)
            If Pending.Count > 1000 Then
                Dim stale As New List(Of Integer)()
                For Each pair As KeyValuePair(Of Integer, List(Of String)) In Pending
                    pair.Value.RemoveAll(Function(k As String) HttpRuntime.Cache.Get(k) Is Nothing)
                    If pair.Value.Count = 0 Then stale.Add(pair.Key)
                Next
                For Each id As Integer In stale
                    Pending.Remove(id)
                Next
            End If
        End SyncLock
    End Sub

    ' Cache.Remove restituisce il valore tolto: due richieste con lo stesso cookie non possono prendere lo stesso biglietto.
    Private Shared Function TakeFromCache(ByVal nonce As String) As SignInTicket
        Return TryCast(HttpRuntime.Cache.Remove(CacheKey(nonce)), SignInTicket)
    End Function

    ' ---------------------------------------------------------------- piccole funzioni pure

    Public Shared Function NewNonce() As String
        Dim bytes(31) As Byte
        Using rng As RandomNumberGenerator = RandomNumberGenerator.Create()
            rng.GetBytes(bytes)
        End Using
        Return Convert.ToBase64String(bytes).TrimEnd("="c).Replace("+"c, "-"c).Replace("/"c, "_"c)
    End Function

    Public Shared Function IsWellFormedNonce(ByVal value As String) As Boolean
        If String.IsNullOrEmpty(value) OrElse value.Length <> 43 Then Return False
        For Each ch As Char In value
            If Not (Char.IsLetterOrDigit(ch) AndAlso ch < ChrW(128) OrElse ch = "-"c OrElse ch = "_"c) Then Return False
        Next
        Return True
    End Function

    Private Shared Function CacheKey(ByVal nonce As String) As String
        Return CachePrefix & Hash("key|" & nonce)
    End Function

    Public Shared Function FingerprintSession(ByVal sessionId As String) As String
        Return Hash("session|" & If(sessionId, String.Empty)).Substring(0, 24)
    End Function

    Private Shared Function Hash(ByVal text As String) As String
        Using sha As SHA256 = SHA256.Create()
            Dim bytes As Byte() = sha.ComputeHash(Encoding.UTF8.GetBytes(text))
            Dim sb As New StringBuilder(bytes.Length * 2)
            For Each b As Byte In bytes
                sb.Append(b.ToString("x2"))
            Next
            Return sb.ToString()
        End Using
    End Function

    Private Shared Function BuildCookie(ByVal value As String, ByVal expires As DateTime) As HttpCookie
        Return New HttpCookie(CookieName, value) With {.Path = "/", .Secure = True, .HttpOnly = True, .SameSite = SameSiteMode.Lax, .Expires = expires}
    End Function
End Class
