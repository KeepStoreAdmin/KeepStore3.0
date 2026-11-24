Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.IO
Imports System.Threading
Imports MySql.Data.MySqlClient

' Harness di Tools/Test-AuthAttemptLimit.ps1 (AUTH-ATTEMPT-LIMIT-1A), parte LAB: esegue sul LAB locale il servizio REALE KeepStoreAuthAttemptLimit con il
' connettore del sito. La tabella login_attempt_limits viene tolta e ricreata LEGGENDO lo script della pagina docs (variabile KS_AUTH_DDL): prima si prova
' il comportamento a tabella assente. Non usa nessun accesso reale ne password: le chiavi sono numeri di prova. Verifica l'identita del LAB prima di tutto;
' utente e segreto arrivano dall'ambiente del processo. Al termine la tabella viene tolta di nuovo (il LAB resta come prima).
Module AuthAttemptLimitLabHarness
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const LabSchema As String = "keepstore_regorder_lab_20261025"
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

    Private Function Reserve(ByVal company As Integer, ByVal scope As Integer, ByVal key As String) As AttemptLimitDecision
        Return KeepStoreAuthAttemptLimit.Reserve(cs, company, scope, key)
    End Function

    ' Un tentativo completo sbagliato: prenota e, se ammesso, registra l'errore. Restituisce la decisione.
    Private Function WrongTry(ByVal company As Integer, ByVal scope As Integer, ByVal key As String) As AttemptLimitDecision
        Dim decision As AttemptLimitDecision = Reserve(company, scope, key)
        If decision = AttemptLimitDecision.Allowed Then KeepStoreAuthAttemptLimit.Fail(cs, company, scope, key)
        Return decision
    End Function

    Private Function FiveWrong(ByVal company As Integer, ByVal scope As Integer, ByVal key As String) As Boolean
        For i As Integer = 1 To 5
            If WrongTry(company, scope, key) <> AttemptLimitDecision.Allowed Then Return False
        Next
        Return True
    End Function

    Private Function RowSql(ByVal company As Integer, ByVal scope As Integer, ByVal key As String) As String
        Return " FROM login_attempt_limits WHERE AziendeId = " & company.ToString() & " AND ScopeCode = " & scope.ToString() & " AND KeyHash = '" & KeepStoreAuthAttemptLimit.ComputeKeyHash(scope, key) & "'"
    End Function

    Private Function Num(ByVal connection As MySqlConnection, ByVal column As String, ByVal company As Integer, ByVal scope As Integer, ByVal key As String) As Integer
        Dim value As Object = Scalar(connection, "SELECT " & column & RowSql(company, scope, key))
        If value Is Nothing OrElse Convert.IsDBNull(value) Then Return -999
        Return Convert.ToInt32(value)
    End Function

    ' Secondi mancanti alla fine del blocco (-999 se non bloccato).
    Private Function BlockSeconds(ByVal connection As MySqlConnection, ByVal company As Integer, ByVal scope As Integer, ByVal key As String) As Integer
        Return Num(connection, "TIMESTAMPDIFF(SECOND, UTC_TIMESTAMP(), BlockedUntilUtc)", company, scope, key)
    End Function

    ' Simula il passare del tempo sulla riga: il blocco e la finestra risultano scaduti da pochi secondi.
    Private Sub ExpireBlock(ByVal connection As MySqlConnection, ByVal company As Integer, ByVal scope As Integer, ByVal key As String)
        Exec(connection, "UPDATE login_attempt_limits SET BlockedUntilUtc = UTC_TIMESTAMP() - INTERVAL 1 SECOND, WindowStartUtc = UTC_TIMESTAMP() - INTERVAL 70 MINUTE" & RowSql(company, scope, key).Replace(" FROM login_attempt_limits", ""))
    End Sub

    Private Function InRange(ByVal seconds As Integer, ByVal minutes As Integer) As Boolean
        Return seconds >= minutes * 60 - 20 AndAlso seconds <= minutes * 60
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
            csb.MaximumPoolSize = 60UI
            cs = csb.ConnectionString
            Dim ddl As String = File.ReadAllText(Environment.GetEnvironmentVariable("KS_AUTH_DDL"))
            Using connection As New MySqlConnection(cs)
                connection.Open()
                Check(Convert.ToString(Scalar(connection, "SELECT @@server_uuid")) = LabUuid AndAlso IntOf(connection, "SELECT @@port") = 13317 AndAlso
                      Convert.ToString(Scalar(connection, "SELECT DATABASE()")) = LabSchema, "guardia: identita del LAB")
                If failed > 0 Then
                    Console.WriteLine("AUTH_ATTEMPT_LIMIT_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If

                ' H01 tabella assente: spento, mai un'eccezione, una sola segnalazione; ricontrollo dopo la sospensione.
                Exec(connection, "DROP TABLE IF EXISTS login_attempt_limits")
                KeepStoreAuthAttemptLimit.ResetStateForTests()
                Check(Reserve(1, 1, "500") = AttemptLimitDecision.Inactive, "H01a tabella assente => Inactive")
                Check(KeepStoreAuthAttemptLimit.IsSuspended(), "H01b sospensione dopo tabella assente")
                Check(KeepStoreAuthAttemptLimit.TakeNotice() = "table-missing", "H01c segnalazione tabella assente")
                Check(KeepStoreAuthAttemptLimit.TakeNotice() = "", "H01d la segnalazione si consuma")
                KeepStoreAuthAttemptLimit.Succeed(cs, 1, 1, "500")
                KeepStoreAuthAttemptLimit.Fail(cs, 1, 1, "500")
                KeepStoreAuthAttemptLimit.Release(cs, 1, 1, "500")
                KeepStoreAuthAttemptLimit.ClearLogin(cs, 500)
                Check(True, "H01e esiti e pulizia senza tabella non lanciano")

                ' Tabella creata dallo script della pagina docs.
                Exec(connection, ddl)
                KeepStoreAuthAttemptLimit.ResetStateForTests()
                Check(IntOf(connection, "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'login_attempt_limits'") = 9, "H02 la tabella ha 9 colonne")

                ' H03 cinque errori poi blocco, anche con la password giusta (il sesto non confronta nulla).
                Check(FiveWrong(1, 1, "1001"), "H03a cinque tentativi ammessi")
                Check(Reserve(1, 1, "1001") = AttemptLimitDecision.Blocked, "H03b il sesto e bloccato")
                Check(InRange(BlockSeconds(connection, 1, 1, "1001"), 15), "H03c primo blocco di 15 minuti")
                Check(Num(connection, "StrikeLevel", 1, 1, "1001") = 1, "H03d livello di ricaduta 1")
                Check(Num(connection, "FailCount", 1, 1, "1001") = 5, "H03e il rifiuto non aumenta il conteggio")

                ' H04 il rifiuto non allunga il blocco.
                Dim before As Integer = BlockSeconds(connection, 1, 1, "1001")
                Thread.Sleep(1100)
                For i As Integer = 1 To 4
                    Reserve(1, 1, "1001")
                Next
                Dim after As Integer = BlockSeconds(connection, 1, 1, "1001")
                Check(after <= before - 1 AndAlso after >= before - 5, "H04 i rifiuti non allungano il blocco")
                Check(Num(connection, "StrikeLevel", 1, 1, "1001") = 1, "H04b i rifiuti non salgono di livello")

                ' H05 isolamento: altro accesso, altra azienda, altro scopo.
                Check(Reserve(1, 1, "1002") = AttemptLimitDecision.Allowed, "H05a altro accesso non toccato")
                Check(Reserve(2, 1, "1001") = AttemptLimitDecision.Allowed, "H05b stessa chiave in un'altra azienda non toccata")
                Check(Reserve(1, 2, "1001") = AttemptLimitDecision.Allowed, "H05c stessa chiave in un altro scopo non toccata")

                ' H06 il successo azzera conteggio e progressione.
                For i As Integer = 1 To 4
                    WrongTry(1, 1, "1003")
                Next
                Check(Reserve(1, 1, "1003") = AttemptLimitDecision.Allowed, "H06a quinta prenotazione ammessa")
                KeepStoreAuthAttemptLimit.Succeed(cs, 1, 1, "1003")
                Check(Num(connection, "FailCount", 1, 1, "1003") = 0 AndAlso Num(connection, "StrikeLevel", 1, 1, "1003") = 0, "H06b il successo azzera")
                Check(FiveWrong(1, 1, "1003"), "H06c dopo il successo servono altri cinque errori")
                ' il successo di un'azienda non azzera l'altra
                For i As Integer = 1 To 3
                    WrongTry(1, 1, "1004")
                    WrongTry(2, 1, "1004")
                Next
                KeepStoreAuthAttemptLimit.Succeed(cs, 1, 1, "1004")
                Check(Num(connection, "FailCount", 1, 1, "1004") = 0 AndAlso Num(connection, "FailCount", 2, 1, "1004") = 3, "H06d il successo non azzera un'altra azienda")

                ' H07 la prenotazione si restituisce se non si confronta; mai sotto zero; non si restituisce a un blocco.
                For i As Integer = 1 To 4
                    WrongTry(1, 1, "1005")
                Next
                Check(Reserve(1, 1, "1005") = AttemptLimitDecision.Allowed, "H07a prenotazione")
                KeepStoreAuthAttemptLimit.Release(cs, 1, 1, "1005")
                Check(Num(connection, "FailCount", 1, 1, "1005") = 4, "H07b restituita")
                KeepStoreAuthAttemptLimit.Release(cs, 1, 1, "1006")
                Reserve(1, 1, "1006")
                KeepStoreAuthAttemptLimit.Release(cs, 1, 1, "1006")
                KeepStoreAuthAttemptLimit.Release(cs, 1, 1, "1006")
                Check(Num(connection, "FailCount", 1, 1, "1006") = 0, "H07c mai sotto zero")
                KeepStoreAuthAttemptLimit.Release(cs, 1, 1, "1001")
                Check(Num(connection, "FailCount", 1, 1, "1001") = 5, "H07d un blocco attivo non si restituisce")

                ' H08 le prenotazioni senza esito arrivano comunque alla soglia (cinque prenotate, sesta rifiutata).
                For i As Integer = 1 To 5
                    Reserve(1, 1, "1007")
                Next
                Check(Reserve(1, 1, "1007") = AttemptLimitDecision.Blocked, "H08 cinque prenotazioni senza esito riempiono la soglia")

                ' H09 concorrenza reale: 30 connessioni distinte (il LAB ne ammette 40), gia aperte (pool scaldato) e liberate insieme, tre giri su tre chiavi:
                ' esattamente 5 ammesse per giro; un solo blocco, un solo livello.
                Dim warm As New List(Of MySqlConnection)()
                For i As Integer = 1 To 30
                    Dim w As New MySqlConnection(cs)
                    w.Open()
                    warm.Add(w)
                Next
                For Each w As MySqlConnection In warm
                    w.Close()
                Next
                For round As Integer = 1 To 3
                    Dim concurrentKey As String = (2000 + round).ToString()
                    Dim allowedCount As Integer = 0
                    Dim blockedCount As Integer = 0
                    Dim startGate As New ManualResetEvent(False)
                    Dim threads As New List(Of Thread)()
                    For i As Integer = 1 To 30
                        Dim worker As New Thread(Sub()
                                                     startGate.WaitOne()
                                                     Dim d As AttemptLimitDecision = KeepStoreAuthAttemptLimit.Reserve(cs, 1, 1, concurrentKey)
                                                     If d = AttemptLimitDecision.Allowed Then
                                                         Interlocked.Increment(allowedCount)
                                                         KeepStoreAuthAttemptLimit.Fail(cs, 1, 1, concurrentKey)
                                                     ElseIf d = AttemptLimitDecision.Blocked Then
                                                         Interlocked.Increment(blockedCount)
                                                     End If
                                                 End Sub)
                        threads.Add(worker)
                        worker.Start()
                    Next
                    startGate.Set()
                    For Each worker As Thread In threads
                        worker.Join()
                    Next
                    Check(allowedCount = 5 AndAlso blockedCount = 25, "H09a giro " & round.ToString() & ": 30 richieste simultanee, esattamente 5 confronti e 25 rifiuti (" & allowedCount.ToString() & " e " & blockedCount.ToString() & "; ultimo errore: " & KeepStoreAuthAttemptLimit.LastErrorForTests() & ")")
                    Check(Num(connection, "StrikeLevel", 1, 1, concurrentKey) = 1 AndAlso InRange(BlockSeconds(connection, 1, 1, concurrentKey), 15), "H09b giro " & round.ToString() & ": un solo blocco, un solo livello")
                Next

                ' H10 progressione 15 / 30 / 60 / 60 (tetto) e ritorno a 15 dopo la scadenza del livello.
                Check(FiveWrong(1, 1, "3001"), "H10a ciclo 1")
                Check(InRange(BlockSeconds(connection, 1, 1, "3001"), 15), "H10b 15 minuti")
                ExpireBlock(connection, 1, 1, "3001")
                Check(FiveWrong(1, 1, "3001"), "H10c ciclo 2 dopo la scadenza")
                Check(InRange(BlockSeconds(connection, 1, 1, "3001"), 30), "H10d 30 minuti")
                ExpireBlock(connection, 1, 1, "3001")
                Check(FiveWrong(1, 1, "3001"), "H10e ciclo 3")
                Check(InRange(BlockSeconds(connection, 1, 1, "3001"), 60), "H10f 60 minuti")
                ExpireBlock(connection, 1, 1, "3001")
                Check(FiveWrong(1, 1, "3001"), "H10g ciclo 4")
                Check(InRange(BlockSeconds(connection, 1, 1, "3001"), 60) AndAlso Num(connection, "StrikeLevel", 1, 1, "3001") = 2, "H10h tetto a 60 minuti")
                ExpireBlock(connection, 1, 1, "3001")
                Exec(connection, "UPDATE login_attempt_limits SET StrikeExpiresUtc = UTC_TIMESTAMP() - INTERVAL 1 SECOND" & RowSql(1, 1, "3001").Replace(" FROM login_attempt_limits", "").Replace("WHERE", "WHERE"))
                Check(FiveWrong(1, 1, "3001"), "H10i ciclo dopo la scadenza del livello")
                Check(InRange(BlockSeconds(connection, 1, 1, "3001"), 15), "H10j il livello torna a 15 minuti")

                ' H10k il successo azzera anche la progressione: dopo un blocco e un accesso riuscito il blocco successivo torna a 15 minuti
                Check(FiveWrong(1, 1, "3005"), "H10k ciclo 1")
                ExpireBlock(connection, 1, 1, "3005")
                Check(Reserve(1, 1, "3005") = AttemptLimitDecision.Allowed, "H10l prenotazione dopo la scadenza")
                KeepStoreAuthAttemptLimit.Succeed(cs, 1, 1, "3005")
                Check(FiveWrong(1, 1, "3005"), "H10m ciclo dopo il successo")
                Check(InRange(BlockSeconds(connection, 1, 1, "3005"), 15) AndAlso Num(connection, "StrikeLevel", 1, 1, "3005") = 1, "H10n dopo un successo il blocco torna a 15 minuti")

                ' H11 un blocco attivo vale anche se la finestra e vecchia (blocchi da 30 e 60 minuti oltre i 15 della finestra).
                Check(FiveWrong(1, 1, "3002"), "H11a ciclo")
                Exec(connection, "UPDATE login_attempt_limits SET WindowStartUtc = UTC_TIMESTAMP() - INTERVAL 20 MINUTE" & RowSql(1, 1, "3002").Replace(" FROM login_attempt_limits", ""))
                Check(Reserve(1, 1, "3002") = AttemptLimitDecision.Blocked, "H11b blocco attivo con finestra vecchia resta bloccato")

                ' H12 finestra scaduta: il conteggio riparte.
                For i As Integer = 1 To 4
                    WrongTry(1, 1, "3003")
                Next
                Exec(connection, "UPDATE login_attempt_limits SET WindowStartUtc = UTC_TIMESTAMP() - INTERVAL 20 MINUTE" & RowSql(1, 1, "3003").Replace(" FROM login_attempt_limits", ""))
                Check(Reserve(1, 1, "3003") = AttemptLimitDecision.Allowed AndAlso Num(connection, "FailCount", 1, 1, "3003") = 1, "H12 finestra scaduta: riparte da uno")
                ' finestra ancora valida (10 minuti su 15): il conteggio NON riparte
                For i As Integer = 1 To 3
                    WrongTry(1, 1, "3004")
                Next
                Exec(connection, "UPDATE login_attempt_limits SET WindowStartUtc = UTC_TIMESTAMP() - INTERVAL 10 MINUTE" & RowSql(1, 1, "3004").Replace(" FROM login_attempt_limits", ""))
                Check(Reserve(1, 1, "3004") = AttemptLimitDecision.Allowed AndAlso Num(connection, "FailCount", 1, 1, "3004") = 4, "H12b finestra valida: il conteggio continua")

                ' H13 nome inesistente: stessa regola e stessa chiave per maiuscole e spazi.
                Dim ghostKey As String = KeepStoreAuthAttemptLimit.NormalizeUnknownName("  MARIO ")
                Check(ghostKey = "mario" AndAlso ghostKey = KeepStoreAuthAttemptLimit.NormalizeUnknownName("mario"), "H13a normalizzazione del nome")
                Check(WrongTry(1, 3, "mario") = AttemptLimitDecision.Allowed AndAlso WrongTry(1, 3, KeepStoreAuthAttemptLimit.NormalizeUnknownName("MARIO")) = AttemptLimitDecision.Allowed AndAlso
                      WrongTry(1, 3, "mario") = AttemptLimitDecision.Allowed AndAlso WrongTry(1, 3, "mario") = AttemptLimitDecision.Allowed AndAlso WrongTry(1, 3, "mario") = AttemptLimitDecision.Allowed, "H13b cinque tentativi")
                Check(Reserve(1, 3, KeepStoreAuthAttemptLimit.NormalizeUnknownName(" Mario")) = AttemptLimitDecision.Blocked, "H13c il nome inesistente si blocca come un accesso")
                Check(Reserve(2, 3, "mario") = AttemptLimitDecision.Allowed, "H13d stesso nome in un'altra azienda non toccato")

                ' H14 recupero password: toglie il blocco dell'accesso e solo quello.
                Check(FiveWrong(1, 1, "4001") AndAlso FiveWrong(1, 2, "4001"), "H14a due blocchi")
                KeepStoreAuthAttemptLimit.ClearLogin(cs, 4001)
                Check(Reserve(1, 1, "4001") = AttemptLimitDecision.Allowed, "H14b l'accesso e sbloccato")
                Check(Reserve(1, 2, "4001") = AttemptLimitDecision.Blocked, "H14c la password attuale resta bloccata")
                KeepStoreAuthAttemptLimit.ClearLogin(cs, 4002)
                Check(Reserve(1, 1, "1001") = AttemptLimitDecision.Blocked, "H14d un altro accesso resta com'e")

                ' H15 impronta: 64 esadecimali, dipende dallo scopo, uguale al calcolo del database.
                Dim hash1 As String = KeepStoreAuthAttemptLimit.ComputeKeyHash(1, "123")
                Check(hash1.Length = 64 AndAlso hash1 = Convert.ToString(Scalar(connection, "SELECT SHA2('v1|1|123', 256)")) AndAlso hash1 <> KeepStoreAuthAttemptLimit.ComputeKeyHash(2, "123") AndAlso hash1 <> KeepStoreAuthAttemptLimit.ComputeKeyHash(1, "124"), "H15 impronta")

                ' H16 ingressi non validi: nessuna riga, nessuna eccezione.
                Dim rowsBefore As Integer = IntOf(connection, "SELECT COUNT(*) FROM login_attempt_limits")
                Check(Reserve(0, 1, "9") = AttemptLimitDecision.Inactive AndAlso Reserve(1, 9, "9") = AttemptLimitDecision.Inactive AndAlso Reserve(1, 1, "") = AttemptLimitDecision.Inactive AndAlso
                      KeepStoreAuthAttemptLimit.Reserve("", 1, 1, "9") = AttemptLimitDecision.Inactive AndAlso IntOf(connection, "SELECT COUNT(*) FROM login_attempt_limits") = rowsBefore, "H16 ingressi non validi")

                ' H17 pulizia: una scrittura su 50 toglie al massimo 200 righe vecchie e mai un blocco attivo.
                Exec(connection, "DELETE FROM login_attempt_limits")
                KeepStoreAuthAttemptLimit.ResetStateForTests()
                Dim fill As String = "INSERT INTO login_attempt_limits (AziendeId, ScopeCode, KeyHash, FailCount, WindowStartUtc, BlockedUntilUtc, UpdatedUtc) " &
                    "SELECT 7, 1, SHA2(CONCAT('old', seq.n), 256), 1, UTC_TIMESTAMP() - INTERVAL 5 DAY, NULL, UTC_TIMESTAMP() - INTERVAL 3 DAY FROM " &
                    "(SELECT a.N + b.N * 10 + c.N * 100 AS n FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a, " &
                    "(SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b, " &
                    "(SELECT 0 N UNION SELECT 1 UNION SELECT 2) c) seq WHERE seq.n < 250"
                Exec(connection, fill)
                Exec(connection, "INSERT INTO login_attempt_limits (AziendeId, ScopeCode, KeyHash, FailCount, WindowStartUtc, BlockedUntilUtc, UpdatedUtc) VALUES (7, 1, SHA2('active', 256), 5, UTC_TIMESTAMP() - INTERVAL 5 DAY, UTC_TIMESTAMP() + INTERVAL 20 MINUTE, UTC_TIMESTAMP() - INTERVAL 3 DAY)")
                Check(IntOf(connection, "SELECT COUNT(*) FROM login_attempt_limits WHERE AziendeId = 7") = 251, "H17a righe di prova")
                For i As Integer = 1 To 49
                    Reserve(8, 1, (5000 + i).ToString())
                Next
                Check(IntOf(connection, "SELECT COUNT(*) FROM login_attempt_limits WHERE AziendeId = 7") = 251, "H17b nessuna pulizia prima della cinquantesima scrittura")
                Reserve(8, 1, "5999")
                Check(IntOf(connection, "SELECT COUNT(*) FROM login_attempt_limits WHERE AziendeId = 7") = 51, "H17c la pulizia toglie al massimo 200 righe")
                Check(IntOf(connection, "SELECT COUNT(*) FROM login_attempt_limits WHERE AziendeId = 7 AND KeyHash = SHA2('active', 256)") = 1, "H17d il blocco attivo resta")
                Check(IntOf(connection, "SELECT COUNT(*) FROM login_attempt_limits WHERE AziendeId = 8") = 50, "H17e le righe recenti restano")

                ' H18 un esito su una connessione propria sopravvive all'annullamento della transazione della pagina.
                Using pageConnection As New MySqlConnection(cs)
                    pageConnection.Open()
                    Using pageTx As MySqlTransaction = pageConnection.BeginTransaction()
                        Check(WrongTry(1, 2, "6001") = AttemptLimitDecision.Allowed, "H18a tentativo dentro la pagina")
                        pageTx.Rollback()
                    End Using
                End Using
                Check(Num(connection, "FailCount", 1, 2, "6001") = 1, "H18b l'errore sopravvive all'annullamento")

                ' H19 errore diverso da tabella assente: si lascia passare, nessuna sospensione, una segnalazione di degrado.
                Exec(connection, "ALTER TABLE login_attempt_limits DROP COLUMN WindowStartUtc")
                KeepStoreAuthAttemptLimit.ResetStateForTests()
                Check(Reserve(1, 1, "7001") = AttemptLimitDecision.Inactive, "H19a errore di schema => Inactive")
                Check(Not KeepStoreAuthAttemptLimit.IsSuspended(), "H19b nessuna sospensione per un errore diverso")
                Check(KeepStoreAuthAttemptLimit.TakeNotice() = "degraded", "H19c segnalazione di degrado")
                Exec(connection, "DROP TABLE login_attempt_limits")
                Exec(connection, ddl)
                KeepStoreAuthAttemptLimit.ResetStateForTests()
                Check(Reserve(1, 1, "7001") = AttemptLimitDecision.Allowed, "H19d la tabella ricreata riparte")

                ' Il LAB resta com'era: la tabella di prova viene tolta.
                Exec(connection, "DROP TABLE IF EXISTS login_attempt_limits")
            End Using
        Catch ex As Exception
            Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & " " & ex.Message.Substring(0, Math.Min(160, ex.Message.Length)).Replace(vbCr, " ").Replace(vbLf, " "))
            Return 2
        End Try
        Console.WriteLine("AUTH_ATTEMPT_LIMIT_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
        Return If(failed = 0, 0, 1)
    End Function
End Module
