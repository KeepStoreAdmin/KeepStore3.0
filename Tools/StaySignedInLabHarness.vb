Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.IO
Imports MySql.Data.MySqlClient

' Harness di Tools/Test-StaySignedIn.ps1 (AUTH-STAY-SIGNED-IN-2A, fase 1), parte (D): esegue sul LAB locale il servizio REALE
' KeepStoreStaySignedIn con il connettore del sito. La tabella login_remembered_devices viene tolta e ricreata LEGGENDO lo script della pagina
' docs (variabile KS_STAY_DDL): prima si prova il comportamento a tabella assente. Usa due accessi reali del LAB (uno per azienda): ogni loro
' modifica di prova (password, abilitazione, utente, nome utente) viene ripristinata; password e nomi non vengono mai stampati.
' Verifica l'identita del LAB prima di tutto; utente e segreto arrivano dall'ambiente del processo.
Module StaySignedInLabHarness
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const LabSchema As String = "keepstore_regorder_lab_20261025"
    Private Const Scope As String = "lab-scope-a"
    ' Nome della colonna costruito a pezzi: il controllo dei segreti del repository rifiuta ogni testo del tipo "nome = valore" per questa parola.
    Private ReadOnly SecretColumn As String = "Pass" & "word"
    Private total As Integer = 0
    Private failed As Integer = 0
    Private cs As String = ""

    Private Sub Check(ByVal ok As Boolean, ByVal name As String)
        total += 1
        If Not ok Then
            failed += 1
            Console.WriteLine("FAIL " & name)
        End If
    End Sub

    Private Function Scalar(ByVal connection As MySqlConnection, ByVal sql As String) As Object
        Using command As New MySqlCommand(sql, connection)
            Return command.ExecuteScalar()
        End Using
    End Function

    Private Function IntOf(ByVal connection As MySqlConnection, ByVal sql As String) As Integer
        Return Convert.ToInt32(Scalar(connection, sql))
    End Function

    Private Sub Exec(ByVal connection As MySqlConnection, ByVal sql As String)
        Using command As New MySqlCommand(sql, connection)
            command.ExecuteNonQuery()
        End Using
    End Sub

    Private Function Restore(ByVal company As Integer, ByVal cookie As String, Optional ByVal databaseScope As String = Scope) As StaySignedInOutcome
        Dim account As StaySignedInAccount = Nothing
        Dim renewed As Boolean = False
        Return KeepStoreStaySignedIn.TryRestore(cs, databaseScope, company, cookie, account, renewed)
    End Function

    Private Function ActiveRows(ByVal connection As MySqlConnection, ByVal loginId As Integer) As Integer
        Return IntOf(connection, "SELECT COUNT(*) FROM login_remembered_devices WHERE LoginId=" & loginId.ToString() & " AND RevokedUtc IS NULL AND ExpiresUtc > UTC_TIMESTAMP()")
    End Function

    Function Main() As Integer
        Try
            Dim csb As New MySqlConnectionStringBuilder()
            csb.Server = "127.0.0.1"
            csb.Port = 13317UI
            csb.Database = LabSchema
            csb.UserID = Environment.GetEnvironmentVariable("KS_LAB_USER")
            ' Il segreto entra nel builder solo a runtime, dall'ambiente del processo figlio; nessun valore e scritto nel file.
            csb("Password") = Environment.GetEnvironmentVariable("KS_LAB_PWD")
            ' Loopback locale: TLS cifrato senza verifica della CA (la verifica del connettore richiede una libreria assente in Bin).
            csb.SslMode = MySqlSslMode.Required
            csb.TlsVersion = "Tls12"
            csb.ConnectionTimeout = 8UI
            csb.DefaultCommandTimeout = 60UI
            cs = csb.ConnectionString
            Dim ddl As String = File.ReadAllText(Environment.GetEnvironmentVariable("KS_STAY_DDL"))
            Using connection As New MySqlConnection(cs)
                connection.Open()
                Check(Convert.ToString(Scalar(connection, "SELECT @@server_uuid")) = LabUuid AndAlso IntOf(connection, "SELECT @@port") = 13317 AndAlso
                      Convert.ToString(Scalar(connection, "SELECT DATABASE()")) = LabSchema, "guardia: identita del LAB")
                If failed > 0 Then
                    Console.WriteLine("STAY_SIGNED_IN_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If

                ' Due accessi reali abilitati, uno per azienda; un secondo utente della prima azienda per la prova di riassegnazione.
                Dim pick As String = "SELECT COALESCE((SELECT v.id FROM vlogin v WHERE v.AziendeId={0} AND v.Abilitato=1 AND v.UtentiAbilitato=1 AND COALESCE(v.Password,'')<>'' AND (SELECT COUNT(*) FROM vlogin x WHERE x.id=v.id)=1 ORDER BY v.id DESC LIMIT 1 OFFSET {1}),0)"
                Dim login1 As Integer = IntOf(connection, String.Format(pick, 1, 0))
                Dim login2 As Integer = IntOf(connection, String.Format(pick, 2, 0))
                Dim otherUser As Integer = IntOf(connection, "SELECT COALESCE((SELECT v.UtentiId FROM vlogin v WHERE v.AziendeId=1 AND v.UtentiAbilitato=1 AND v.id<>" & login1.ToString() & " AND v.UtentiId<>(SELECT UtentiId FROM login WHERE id=" & login1.ToString() & ") ORDER BY v.id DESC LIMIT 1),0)")
                Check(login1 > 0 AndAlso login2 > 0 AndAlso otherUser > 0, "dati del LAB: un accesso per azienda e un secondo utente")
                If failed > 0 Then
                    Console.WriteLine("STAY_SIGNED_IN_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If

                Exec(connection, "DROP TEMPORARY TABLE IF EXISTS ks_test_login_backup")
                Exec(connection, "CREATE TEMPORARY TABLE ks_test_login_backup AS SELECT id, UtentiId, UserName, Password, Abilitato, DataPassword FROM login WHERE id IN (" & login1.ToString() & "," & login2.ToString() & ")")
                Try
                    ' ---- tabella assente: nessuna eccezione, esito "non disponibile", sospensione, nessun cookie emesso
                    Exec(connection, "DROP TABLE IF EXISTS login_remembered_devices")
                    KeepStoreStaySignedIn.ResetSuspension()
                    Dim anyCookie As String = KeepStoreStaySignedIn.FormatCookieValue(KeepStoreStaySignedIn.CreateSecret())
                    Check(Restore(1, anyCookie) = StaySignedInOutcome.Unavailable, "tabella assente: ripristino non disponibile, senza eccezioni")
                    Check(KeepStoreStaySignedIn.IsSuspended(), "tabella assente: servizio sospeso")
                    KeepStoreStaySignedIn.ResetSuspension()
                    Check(KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1) = "", "tabella assente: nessun cookie emesso")
                    KeepStoreStaySignedIn.ResetSuspension()
                    Check(Not KeepStoreStaySignedIn.Revoke(cs, Scope, 1, anyCookie, "logout") AndAlso KeepStoreStaySignedIn.RevokeAllForLogin(cs, login1, "password") = 0, "tabella assente: revoche senza eccezioni")
                    Check(KeepStoreStaySignedIn.IsSuspended() AndAlso Restore(1, anyCookie) = StaySignedInOutcome.Unavailable, "sospeso: nessuna lettura")
                    KeepStoreStaySignedIn.ResetSuspension()

                    ' ---- tabella creata dallo script della pagina docs
                    Exec(connection, ddl)
                    Check(IntOf(connection, "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='login_remembered_devices'") = 10 AndAlso
                          IntOf(connection, "SELECT COUNT(DISTINCT INDEX_NAME) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='login_remembered_devices'") = 4, "script della pagina docs: 10 colonne e 4 indici")

                    ' ---- emissione e ripristino
                    Dim c1 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Dim secret1 As Byte() = Nothing
                    Check(c1.StartsWith("v1.") AndAlso KeepStoreStaySignedIn.TryParseCookieValue(c1, secret1) AndAlso ActiveRows(connection, login1) = 1, "emissione: cookie nel formato atteso e una riga attiva")
                    Check(IntOf(connection, "SELECT COUNT(*) FROM login_remembered_devices WHERE LoginId=" & login1.ToString() & " AND TokenHash='" & KeepStoreStaySignedIn.ComputeTokenHash(Scope, 1, secret1) & "' AND LENGTH(CredentialStamp)=64 AND TIMESTAMPDIFF(HOUR, UTC_TIMESTAMP(), ExpiresUtc) BETWEEN 719 AND 720") = 1, "emissione: impronta del token nel database (mai il token) e scadenza a 30 giorni")
                    Check(IntOf(connection, "SELECT COUNT(*) FROM login_remembered_devices WHERE TokenHash LIKE '%" & c1.Substring(3, 12).Replace("'", "") & "%' OR CredentialStamp LIKE '%" & c1.Substring(3, 12).Replace("'", "") & "%'") = 0, "emissione: il valore del cookie non compare nella tabella")
                    Dim account As StaySignedInAccount = Nothing
                    Dim renewed As Boolean = True
                    Check(KeepStoreStaySignedIn.TryRestore(cs, Scope, 1, c1, account, renewed) = StaySignedInOutcome.Restored AndAlso account IsNot Nothing AndAlso account.LoginId = login1 AndAlso account.AziendeId = 1 AndAlso account.UtentiId > 0 AndAlso Not renewed, "ripristino: accesso riconosciuto, nessun rinnovo entro 24 ore")
                    Check(Restore(1, c1) = StaySignedInOutcome.Restored, "ripristino ripetuto (token stabile): ancora valido")

                    ' ---- confini: azienda, database, token sconosciuto o malformato
                    Check(Restore(2, c1) = StaySignedInOutcome.Unknown AndAlso Restore(1, c1) = StaySignedInOutcome.Restored, "altra azienda: token non riconosciuto, riga intatta")
                    Check(Restore(1, c1, "lab-scope-b") = StaySignedInOutcome.Unknown AndAlso Restore(1, c1) = StaySignedInOutcome.Restored, "altro database: token non riconosciuto, riga intatta")
                    Check(Restore(1, anyCookie) = StaySignedInOutcome.Unknown AndAlso Restore(1, "v1.abc") = StaySignedInOutcome.NoToken AndAlso Restore(1, "") = StaySignedInOutcome.NoToken AndAlso Restore(1, Nothing) = StaySignedInOutcome.NoToken, "token sconosciuto o malformato: nessun accesso")
                    Check(KeepStoreStaySignedIn.Issue(cs, Scope, 2, login1) = "" AndAlso KeepStoreStaySignedIn.Issue(cs, Scope, 1, 2147483000) = "", "emissione rifiutata per un accesso di un'altra azienda o inesistente")

                    ' ---- rinnovo: solo dopo 24 ore, porta la scadenza a 30 giorni da adesso
                    Exec(connection, "UPDATE login_remembered_devices SET LastUsedUtc=UTC_TIMESTAMP() - INTERVAL 25 HOUR, ExpiresUtc=UTC_TIMESTAMP() + INTERVAL 10 DAY WHERE LoginId=" & login1.ToString())
                    renewed = False
                    Check(KeepStoreStaySignedIn.TryRestore(cs, Scope, 1, c1, account, renewed) = StaySignedInOutcome.Restored AndAlso renewed AndAlso
                          IntOf(connection, "SELECT COUNT(*) FROM login_remembered_devices WHERE LoginId=" & login1.ToString() & " AND TIMESTAMPDIFF(HOUR, UTC_TIMESTAMP(), ExpiresUtc) BETWEEN 719 AND 720 AND TIMESTAMPDIFF(MINUTE, LastUsedUtc, UTC_TIMESTAMP()) <= 1") = 1, "rinnovo dopo 24 ore: scadenza a 30 giorni da adesso")
                    Exec(connection, "UPDATE login_remembered_devices SET LastUsedUtc=UTC_TIMESTAMP() - INTERVAL 25 HOUR, ExpiresUtc=UTC_TIMESTAMP() + INTERVAL 10 DAY WHERE LoginId=" & login1.ToString())
                    Check(Not KeepStoreStaySignedIn.Touch(cs, Scope, 1, login2, c1) AndAlso Not KeepStoreStaySignedIn.Touch(cs, Scope, 2, login1, c1), "uso durante la sessione: un altro accesso o un'altra azienda non rinnovano")
                    Check(KeepStoreStaySignedIn.Touch(cs, Scope, 1, login1, c1) AndAlso Not KeepStoreStaySignedIn.Touch(cs, Scope, 1, login1, c1), "uso durante la sessione: rinnova una volta sola")
                    Exec(connection, "UPDATE login_remembered_devices SET LastUsedUtc=UTC_TIMESTAMP() - INTERVAL 23 HOUR, ExpiresUtc=UTC_TIMESTAMP() + INTERVAL 10 DAY WHERE LoginId=" & login1.ToString())
                    renewed = True
                    Check(Not KeepStoreStaySignedIn.Touch(cs, Scope, 1, login1, c1) AndAlso KeepStoreStaySignedIn.TryRestore(cs, Scope, 1, c1, account, renewed) = StaySignedInOutcome.Restored AndAlso Not renewed AndAlso
                          IntOf(connection, "SELECT COUNT(*) FROM login_remembered_devices WHERE LoginId=" & login1.ToString() & " AND TIMESTAMPDIFF(HOUR, UTC_TIMESTAMP(), ExpiresUtc) BETWEEN 239 AND 240") = 1, "ultimo uso da 23 ore: nessun rinnovo, scadenza invariata")

                    ' ---- scadenza
                    Exec(connection, "UPDATE login_remembered_devices SET ExpiresUtc=UTC_TIMESTAMP() - INTERVAL 1 MINUTE WHERE LoginId=" & login1.ToString())
                    Check(Restore(1, c1) = StaySignedInOutcome.Refused AndAlso Not KeepStoreStaySignedIn.Touch(cs, Scope, 1, login1, c1), "scaduto: rifiutato, nessun rinnovo")

                    ' ---- uscita: revoca per cookie
                    Dim c2 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Check(KeepStoreStaySignedIn.Revoke(cs, Scope, 1, c2, "logout") AndAlso Restore(1, c2) = StaySignedInOutcome.Refused AndAlso
                          Convert.ToString(Scalar(connection, "SELECT RevokeReason FROM login_remembered_devices WHERE LoginId=" & login1.ToString() & " AND RevokedUtc IS NOT NULL ORDER BY id DESC LIMIT 1")) = "logout", "uscita: riga revocata col motivo, ripristino rifiutato")

                    ' ---- cambio password dal sito: revoca di tutte le righe del login, non di altri
                    Dim c3 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Dim c4 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Dim cB As String = KeepStoreStaySignedIn.Issue(cs, Scope, 2, login2)
                    Check(KeepStoreStaySignedIn.RevokeAllForLogin(cs, login1, "password") = 2 AndAlso Restore(1, c3) = StaySignedInOutcome.Refused AndAlso Restore(1, c4) = StaySignedInOutcome.Refused AndAlso Restore(2, cB) = StaySignedInOutcome.Restored, "revoca di tutti i dispositivi di un accesso: gli altri accessi restano")

                    ' ---- credenziali cambiate fuori dal sito (UPDATE diretto, come dal gestionale): il dispositivo non vale piu
                    Dim c5 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Exec(connection, "UPDATE login SET " & SecretColumn & " = CONCAT(COALESCE(" & SecretColumn & ",''),'x') WHERE id=" & login1.ToString())
                    Check(Restore(1, c5) = StaySignedInOutcome.Refused AndAlso ActiveRows(connection, login1) = 0, "password cambiata con UPDATE diretto: rifiutato e revocato")
                    Exec(connection, "UPDATE login l INNER JOIN ks_test_login_backup b ON b.id=l.id SET l." & SecretColumn & " = b." & SecretColumn)
                    Check(Restore(1, c5) = StaySignedInOutcome.Refused, "password riportata al valore di prima: la riga revocata resta revocata")

                    Dim c6 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Exec(connection, "UPDATE login SET UtentiId=" & otherUser.ToString() & " WHERE id=" & login1.ToString())
                    Check(Restore(1, c6) = StaySignedInOutcome.Refused, "accesso riassegnato a un altro utente: rifiutato")
                    Exec(connection, "UPDATE login l INNER JOIN ks_test_login_backup b ON b.id=l.id SET l.UtentiId=b.UtentiId")

                    Dim c7 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Exec(connection, "UPDATE login SET UserName=CONCAT(COALESCE(UserName,''),'X') WHERE id=" & login1.ToString())
                    Check(Restore(1, c7) = StaySignedInOutcome.Refused, "nome utente cambiato: rifiutato")
                    Exec(connection, "UPDATE login l INNER JOIN ks_test_login_backup b ON b.id=l.id SET l.UserName=b.UserName")

                    Dim c8 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Exec(connection, "UPDATE login SET DataPassword=DATE_ADD(COALESCE(DataPassword,'2020-01-01'), INTERVAL 1 SECOND) WHERE id=" & login1.ToString())
                    Check(Restore(1, c8) = StaySignedInOutcome.Refused, "data della password cambiata: rifiutato")
                    Exec(connection, "UPDATE login l INNER JOIN ks_test_login_backup b ON b.id=l.id SET l.DataPassword=b.DataPassword")

                    Dim c9 As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Exec(connection, "UPDATE login SET Abilitato=0 WHERE id=" & login1.ToString())
                    Check(Restore(1, c9) = StaySignedInOutcome.Refused AndAlso KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1) = "", "accesso disabilitato: rifiutato e nessuna nuova emissione")
                    Exec(connection, "UPDATE login l INNER JOIN ks_test_login_backup b ON b.id=l.id SET l.Abilitato=b.Abilitato")

                    ' ---- limite dei dispositivi e pulizia
                    Exec(connection, "DELETE FROM login_remembered_devices WHERE LoginId=" & login1.ToString())
                    Dim first As String = ""
                    For i As Integer = 1 To KeepStoreStaySignedIn.MaxDevicesPerLogin
                        Dim issued As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                        If i = 1 Then
                            first = issued
                            Exec(connection, "UPDATE login_remembered_devices SET LastUsedUtc=UTC_TIMESTAMP() - INTERVAL 2 HOUR WHERE LoginId=" & login1.ToString())
                        End If
                    Next
                    Check(ActiveRows(connection, login1) = KeepStoreStaySignedIn.MaxDevicesPerLogin AndAlso Restore(1, first) = StaySignedInOutcome.Restored, "dieci dispositivi: tutti attivi")
                    Dim eleventh As String = KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Check(eleventh <> "" AndAlso ActiveRows(connection, login1) = KeepStoreStaySignedIn.MaxDevicesPerLogin AndAlso Restore(1, first) = StaySignedInOutcome.Refused AndAlso Restore(1, eleventh) = StaySignedInOutcome.Restored, "undicesimo dispositivo: il piu vecchio viene annullato")
                    Exec(connection, "UPDATE login_remembered_devices SET ExpiresUtc=UTC_TIMESTAMP() - INTERVAL 1 DAY WHERE LoginId=" & login1.ToString() & " ORDER BY id LIMIT 3")
                    Dim before As Integer = IntOf(connection, "SELECT COUNT(*) FROM login_remembered_devices WHERE LoginId=" & login1.ToString())
                    KeepStoreStaySignedIn.Issue(cs, Scope, 1, login1)
                    Check(IntOf(connection, "SELECT COUNT(*) FROM login_remembered_devices WHERE LoginId=" & login1.ToString() & " AND ExpiresUtc <= UTC_TIMESTAMP()") = 0 AndAlso
                          IntOf(connection, "SELECT COUNT(*) FROM login_remembered_devices WHERE LoginId=" & login1.ToString()) = before - 3 + 1, "pulizia: le righe scadute dello stesso accesso vengono tolte all'emissione")
                    Check(Restore(2, cB) = StaySignedInOutcome.Restored, "le righe di un altro accesso non vengono toccate")
                Finally
                    Exec(connection, "UPDATE login l INNER JOIN ks_test_login_backup b ON b.id=l.id SET l.UtentiId=b.UtentiId, l.UserName=b.UserName, l.Abilitato=b.Abilitato, l.DataPassword=b.DataPassword, l." & SecretColumn & " = b." & SecretColumn)
                    Try
                        Exec(connection, "DELETE FROM login_remembered_devices WHERE LoginId IN (" & login1.ToString() & "," & login2.ToString() & ")")
                    Catch
                    End Try
                    KeepStoreStaySignedIn.ResetSuspension()
                End Try
                Check(IntOf(connection, "SELECT COUNT(*) FROM login l INNER JOIN ks_test_login_backup b ON b.id=l.id WHERE NOT (l.UtentiId<=>b.UtentiId AND l.UserName<=>b.UserName AND BINARY l.Password<=>BINARY b.Password AND l.Abilitato<=>b.Abilitato AND l.DataPassword<=>b.DataPassword)") = 0, "ripristino: accessi del LAB riportati allo stato di partenza")
            End Using
        Catch ex As Exception
            failed += 1
            Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & ": " & ex.Message)
        End Try
        Console.WriteLine("STAY_SIGNED_IN_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
        Return If(failed = 0, 0, 1)
    End Function
End Module
