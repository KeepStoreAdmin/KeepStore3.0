Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Web

' AUTH-ATTEMPT-LIMIT-1A: strato del limite ai tentativi che tocca il sito (configurazione, connessione, registro). La logica sta in KeepStoreAuthAttemptLimit.
' - Chiave di configurazione KeepStore.AuthAttemptLimit.Enabled: assente = accesa SE la tabella login_attempt_limits esiste; "false" = spenta.
'   Il web.config del sito non va modificato: l'accensione e la creazione della tabella, atto deliberato del PO.
' - Nessun metodo lancia eccezioni verso la pagina. Nel registro mai nome utente, password, indirizzo ne impronte: solo "tabella assente" o "degradato",
'   al massimo una segnalazione ogni 10 minuti per processo.
Public NotInheritable Class KeepStoreAuthAttemptLimitWeb
    Private Sub New()
    End Sub

    Public Const EnabledSettingName As String = "KeepStore.AuthAttemptLimit.Enabled"
    Public Const BlockedMessage As String = "Troppi tentativi. Riprova tra qualche minuto, oppure recupera la password dalla pagina di accesso."
    Public Const NoticeEveryMinutes As Integer = 10

    Private Shared ReadOnly NoticeLock As New Object()
    Private Shared _lastNoticeUtc As DateTime = DateTime.MinValue

    Public Shared Function IsEnabled() As Boolean
        Try
            Dim value As String = Convert.ToString(ConfigurationManager.AppSettings(EnabledSettingName))
            Return Not String.Equals(If(value, String.Empty).Trim(), "false", StringComparison.OrdinalIgnoreCase)
        Catch
            Return True
        End Try
    End Function

    Private Shared Function ConnectionText() As String
        Try
            Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If settings Is Nothing Then Return String.Empty
            Return If(settings.ConnectionString, String.Empty)
        Catch
            Return String.Empty
        End Try
    End Function

    Private Shared Sub FlushNotice(ByVal context As HttpContext)
        Try
            Dim notice As String = KeepStoreAuthAttemptLimit.TakeNotice()
            If notice.Length = 0 Then Return
            SyncLock NoticeLock
                If DateTime.UtcNow < _lastNoticeUtc.AddMinutes(NoticeEveryMinutes) Then Return
                _lastNoticeUtc = DateTime.UtcNow
            End SyncLock
            KeepStoreLog.Error("auth-attempt-limit", If(notice = "table-missing", "Attempt limit table is missing: the limit is off until it is created.", "Attempt limit degraded: a database error let attempts pass unchecked."), Nothing, context)
        Catch
        End Try
    End Sub

    Public Shared Function Reserve(ByVal context As HttpContext, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String) As AttemptLimitDecision
        Try
            If Not IsEnabled() Then Return AttemptLimitDecision.Inactive
            Dim decision As AttemptLimitDecision = KeepStoreAuthAttemptLimit.Reserve(ConnectionText(), companyId, scope, key)
            FlushNotice(context)
            Return decision
        Catch
            Return AttemptLimitDecision.Inactive
        End Try
    End Function

    Public Shared Sub Succeed(ByVal context As HttpContext, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String)
        Try
            KeepStoreAuthAttemptLimit.Succeed(ConnectionText(), companyId, scope, key)
            FlushNotice(context)
        Catch
        End Try
    End Sub

    Public Shared Sub Fail(ByVal context As HttpContext, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String)
        Try
            KeepStoreAuthAttemptLimit.Fail(ConnectionText(), companyId, scope, key)
            FlushNotice(context)
        Catch
        End Try
    End Sub

    Public Shared Sub Release(ByVal context As HttpContext, ByVal companyId As Integer, ByVal scope As Integer, ByVal key As String)
        Try
            KeepStoreAuthAttemptLimit.Release(ConnectionText(), companyId, scope, key)
            FlushNotice(context)
        Catch
        End Try
    End Sub

    ' Recupero password completato: toglie il blocco dell'accesso (dopo il commit del recupero, mai dentro la sua transazione).
    Public Shared Sub ClearLogin(ByVal context As HttpContext, ByVal loginId As Integer)
        Try
            If Not IsEnabled() Then Return
            KeepStoreAuthAttemptLimit.ClearLogin(ConnectionText(), loginId)
            FlushNotice(context)
        Catch
        End Try
    End Sub

    Public Shared Function LoginKey(ByVal loginId As Integer) As String
        Return loginId.ToString(CultureInfo.InvariantCulture)
    End Function
End Class
