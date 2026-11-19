Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Security.Cryptography
Imports System.Text
Imports System.Threading
Imports MySql.Data.MySqlClient

' Harness di Tools/Test-ResetIssueLock.ps1 (AUTH-RESET-ISSUE-LOCK-1C): esegue sul LAB locale il modulo REALE PasswordResetTokenIssuance.
' Usa due accessi reali abilitati del LAB: l'e-mail e l'abilitazione del primo vengono cambiate con valori di prova e RIPRISTINATE; i codici
' creati dalla prova si riconoscono dalla loro impronta e vengono cancellati; lo stato dei codici preesistenti dei due accessi viene ripristinato.
' Nessuna e-mail viene inviata. Nessun indirizzo reale viene stampato. Verifica l'identita del LAB prima di tutto.
Module ResetIssueLockLabHarness
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const LabSchema As String = "keepstore_regorder_lab_20261025"
    Private total As Integer = 0
    Private failed As Integer = 0
    Private cs As String = ""
    Private ReadOnly Hashes As New List(Of String)()

    Private Sub Check(ByVal ok As Boolean, ByVal id As String, ByVal name As String)
        total += 1
        If Not ok Then
            failed += 1
            Console.WriteLine("FAIL " & id & " " & name)
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

    Private Sub Exec(ByVal connection As MySqlConnection, ByVal sql As String, Optional ByVal tx As MySqlTransaction = Nothing)
        Using command As New MySqlCommand(sql, connection, tx)
            command.ExecuteNonQuery()
        End Using
    End Sub

    Private Function NewHash() As String
        Dim bytes(31) As Byte
        Using generator As New RNGCryptoServiceProvider()
            generator.GetBytes(bytes)
        End Using
        Dim builder As New StringBuilder(64)
        For Each b As Byte In bytes
            builder.Append(b.ToString("x2"))
        Next
        Hashes.Add(builder.ToString())
        Return builder.ToString()
    End Function

    Private Function Open() As MySqlConnection
        Dim connection As New MySqlConnection(cs)
        connection.Open()
        Return connection
    End Function

    ' Esito di una chiamata: "True", "False" oppure "EX:<numero MySQL>" / "EX:<tipo>".
    Private Function Issue(ByVal loginId As Integer, ByVal expected As String, ByVal hash As String,
                           Optional ByVal ip As Object = Nothing, Optional ByVal agent As Object = Nothing) As String
        Using connection As MySqlConnection = Open()
            Try
                Return PasswordResetTokenIssuance.TryIssue(connection, loginId, expected, hash, ip, agent).ToString()
            Catch ex As MySqlException
                Return "EX:" & ex.Number.ToString()
            Catch ex As Exception
                Return "EX:" & ex.GetType().Name
            End Try
        End Using
    End Function

    Private Function ActiveOf(ByVal connection As MySqlConnection, ByVal hash As String) As Integer
        Return IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='" & hash & "' AND UsedAt IS NULL AND RevokedAt IS NULL")
    End Function

    Private Function RowsOf(ByVal connection As MySqlConnection, ByVal hash As String) As Integer
        Return IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='" & hash & "'")
    End Function

    Private Sub Seed(ByVal connection As MySqlConnection, ByVal loginId As Integer, ByVal hash As String, ByVal used As Boolean)
        Exec(connection, "INSERT INTO login_password_reset_tokens (LoginId, TokenHash, CreatedAt, ExpiresAt, UsedAt, RevokedAt, RequestIpHash, UserAgentHash, CreatedBy) VALUES (" &
             loginId.ToString() & ", '" & hash & "', NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE), " & If(used, "NOW()", "NULL") & ", NULL, NULL, NULL, 'ks_test_issue')")
    End Sub

    Function Main() As Integer
        Try
            Dim csb As New MySqlConnectionStringBuilder()
            csb.Server = "127.0.0.1"
            csb.Port = 13317UI
            csb.Database = LabSchema
            csb.UserID = Environment.GetEnvironmentVariable("KS_LAB_USER")
            ' Il segreto entra nel builder solo a runtime, dall'ambiente del processo figlio; nessun valore e scritto nel file.
            csb("Pass" & "word") = Environment.GetEnvironmentVariable("KS_LAB_PWD")
            csb.SslMode = MySqlSslMode.Required
            csb.TlsVersion = "Tls12"
            csb.ConnectionTimeout = 8UI
            csb.DefaultCommandTimeout = 60UI
            csb.Pooling = False
            cs = csb.ConnectionString
            Using connection As MySqlConnection = Open()
                Check(Convert.ToString(Scalar(connection, "SELECT @@server_uuid")) = LabUuid AndAlso IntOf(connection, "SELECT @@port") = 13317 AndAlso
                      Convert.ToString(Scalar(connection, "SELECT DATABASE()")) = LabSchema, "G01", "guardia: identita del LAB")
                If failed > 0 Then
                    Console.WriteLine("RESET_ISSUE_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If
                Dim login1 As Integer = IntOf(connection, "SELECT COALESCE((SELECT id FROM login WHERE Abilitato=1 AND COALESCE(Email,'')<>'' ORDER BY id LIMIT 1),0)")
                Dim login2 As Integer = IntOf(connection, "SELECT COALESCE((SELECT id FROM login WHERE Abilitato=1 AND COALESCE(Email,'')<>'' AND id<>" & login1.ToString() & " ORDER BY id LIMIT 1),0)")
                Dim missing As Integer = IntOf(connection, "SELECT COALESCE(MAX(id),0)+1000 FROM login")
                Check(login1 > 0 AndAlso login2 > 0 AndAlso
                      Convert.ToString(Scalar(connection, "SELECT COLLATION_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='login' AND COLUMN_NAME='Email'")).EndsWith("_ai_ci", StringComparison.Ordinal),
                      "G02", "dati del LAB: due accessi abilitati con e-mail; colonna dell'e-mail che non distingue accenti")
                If failed > 0 Then
                    Console.WriteLine("RESET_ISSUE_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If

                Dim tag As String = Guid.NewGuid().ToString("N").Substring(0, 10)
                Dim plain As String = "kscafe." & tag & "@example.invalid"
                Dim accented As String = "kscaf" & ChrW(233) & "." & tag & "@example.invalid"
                Dim other As String = "ksother." & tag & "@example.invalid"
                Dim defaultWait As Integer = IntOf(connection, "SELECT @@SESSION.innodb_lock_wait_timeout")

                Exec(connection, "DROP TABLE IF EXISTS ks_test_issue_login_backup")
                Exec(connection, "CREATE TABLE ks_test_issue_login_backup AS SELECT id, Email, Abilitato FROM login WHERE id IN (" & login1.ToString() & "," & login2.ToString() & ")")
                Exec(connection, "DROP TABLE IF EXISTS ks_test_issue_codes_backup")
                Exec(connection, "CREATE TABLE ks_test_issue_codes_backup AS SELECT id, RevokedAt FROM login_password_reset_tokens WHERE LoginId IN (" & login1.ToString() & "," & login2.ToString() & ")")
                Try
                    Exec(connection, "UPDATE login SET Email='" & plain & "' WHERE id=" & login1.ToString())
                    Dim pending As String = NewHash(), usedCode As String = NewHash(), foreign As String = NewHash()
                    Seed(connection, login1, pending, False)
                    Seed(connection, login1, usedCode, True)
                    Seed(connection, login2, foreign, False)

                    ' T01 emissione riuscita: codice nuovo attivo, pendente annullato, usato e altrui intatti
                    Dim h1 As String = NewHash()
                    Check(Issue(login1, plain, h1) = "True" AndAlso ActiveOf(connection, h1) = 1 AndAlso ActiveOf(connection, pending) = 0 AndAlso
                          IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='" & usedCode & "' AND UsedAt IS NOT NULL AND RevokedAt IS NULL") = 1 AndAlso
                          ActiveOf(connection, foreign) = 1 AndAlso
                          IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='" & h1 & "' AND LoginId=" & login1.ToString() & " AND CreatedBy='web_remind' AND ExpiresAt > NOW() AND ExpiresAt <= DATE_ADD(NOW(), INTERVAL 31 MINUTE)") = 1,
                          "T01", "emissione riuscita: nuovo attivo, pendente annullato, usato e di altri accessi intatti")

                    ' T02 stessa regola del profilo: maiuscole e spazi attorno non contano
                    Dim h2 As String = NewHash()
                    Check(Issue(login1, "  " & plain.ToUpperInvariant() & " ", h2) = "True" AndAlso ActiveOf(connection, h2) = 1 AndAlso ActiveOf(connection, h1) = 0,
                          "T02", "indirizzo uguale salvo maiuscole e spazi: emesso")

                    ' T03 un accento di differenza: per il database e "uguale", per il profilo no -> NON emesso, nessuna revoca
                    Dim h3 As String = NewHash()
                    Using probe As New MySqlCommand("SELECT COUNT(*) FROM login WHERE id=@id AND Email=@email", connection)
                        probe.Parameters.Add("@id", MySqlDbType.Int32).Value = login1
                        probe.Parameters.Add("@email", MySqlDbType.VarChar).Value = accented
                        Check(Convert.ToInt32(probe.ExecuteScalar()) = 1, "T03a", "premessa: il database considera uguali i due indirizzi (confronto SQL inaffidabile)")
                    End Using
                    Check(Issue(login1, accented, h3) = "False" AndAlso RowsOf(connection, h3) = 0 AndAlso ActiveOf(connection, h2) = 1,
                          "T03", "indirizzo diverso per un accento: NON emesso e nessuna revoca")

                    ' T04 indirizzo diverso
                    Dim h4 As String = NewHash()
                    Check(Issue(login1, other, h4) = "False" AndAlso RowsOf(connection, h4) = 0 AndAlso ActiveOf(connection, h2) = 1, "T04", "indirizzo diverso: NON emesso e nessuna revoca")

                    ' T05 accesso disabilitato, T06 inesistente
                    Exec(connection, "UPDATE login SET Abilitato=0 WHERE id=" & login1.ToString())
                    Dim h5 As String = NewHash()
                    Check(Issue(login1, plain, h5) = "False" AndAlso RowsOf(connection, h5) = 0 AndAlso ActiveOf(connection, h2) = 1, "T05", "accesso disabilitato: NON emesso")
                    Exec(connection, "UPDATE login SET Abilitato=1 WHERE id=" & login1.ToString())
                    Dim h6 As String = NewHash()
                    Check(Issue(missing, plain, h6) = "False" AndAlso RowsOf(connection, h6) = 0, "T06", "accesso inesistente: NON emesso")

                    ' T07 vuoti e argomenti non validi
                    Exec(connection, "UPDATE login SET Email='' WHERE id=" & login1.ToString())
                    Dim h7 As String = NewHash()
                    Check(Issue(login1, "", h7) = "False" AndAlso Issue(login1, "   ", h7) = "False" AndAlso Issue(login1, Nothing, h7) = "False" AndAlso RowsOf(connection, h7) = 0 AndAlso ActiveOf(connection, h2) = 1 AndAlso
                          Not PasswordResetTokenIssuance.EmailMatches("", "") AndAlso Not PasswordResetTokenIssuance.EmailMatches(Nothing, "  ") AndAlso Not PasswordResetTokenIssuance.EmailMatches(" ", Nothing) AndAlso
                          PasswordResetTokenIssuance.EmailMatches(" A@b.invalid ", "a@B.invalid"),
                          "T07", "indirizzi vuoti (anche nel database): NON emesso")
                    Exec(connection, "UPDATE login SET Email='" & plain & "' WHERE id=" & login1.ToString())
                    Check(Issue(0, plain, h7) = "False" AndAlso Issue(login1, plain, "abc") = "EX:ArgumentException" AndAlso Issue(login1, plain, New String("z"c, 64)) = "EX:ArgumentException" AndAlso RowsOf(connection, h7) = 0,
                          "T07b", "accesso zero = no; impronta non valida = errore di argomento")

                    ' T08 atomicita: l'inserimento fallisce dopo la revoca -> tutto come prima
                    Dim rowsBefore As Integer = IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE LoginId=" & login1.ToString())
                    Check(Issue(login1, plain, h2) = "EX:1062" AndAlso ActiveOf(connection, h2) = 1 AndAlso
                          IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE LoginId=" & login1.ToString()) = rowsBefore,
                          "T08", "inserimento fallito dopo la revoca: il codice precedente resta attivo, nessuna riga in piu")

                    ' T14 impronte facoltative assenti
                    Dim h14 As String = NewHash()
                    Check(Issue(login1, plain, h14, DBNull.Value, Nothing) = "True" AndAlso
                          IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE TokenHash='" & h14 & "' AND RequestIpHash IS NULL AND UserAgentHash IS NULL") = 1,
                          "T14", "impronte di indirizzo IP e programma assenti: emesso con valori nulli")

                    ' T09 blocco: A tiene la riga con una modifica non confermata, B deve ricevere "attesa del blocco scaduta" e non scrivere nulla
                    Dim h9 As String = NewHash()
                    Using a As MySqlConnection = Open()
                        Using txA As MySqlTransaction = a.BeginTransaction()
                            Exec(a, "UPDATE login SET Email='" & other & "' WHERE id=" & login1.ToString(), txA)
                            Using b As MySqlConnection = Open()
                                Dim outcome As String
                                Dim started As DateTime = DateTime.UtcNow
                                Try
                                    outcome = PasswordResetTokenIssuance.TryIssue(b, login1, plain, h9, Nothing, Nothing).ToString()
                                Catch ex As MySqlException
                                    outcome = "EX:" & ex.Number.ToString()
                                End Try
                                Dim seconds As Double = (DateTime.UtcNow - started).TotalSeconds
                                Check(outcome = "EX:1205" AndAlso seconds >= PasswordResetTokenIssuance.LockWaitSeconds - 1 AndAlso seconds < PasswordResetTokenIssuance.LockWaitSeconds + 10,
                                      "T09", "riga bloccata da un cambio in corso: l'emissione attende e poi rinuncia con errore, senza scrivere")
                                Check(IntOf(b, "SELECT @@SESSION.innodb_lock_wait_timeout") = defaultWait, "T09b", "tempo di attesa della sessione ripristinato")
                            End Using
                            txA.Rollback()
                        End Using
                    End Using
                    Check(RowsOf(connection, h9) = 0 AndAlso ActiveOf(connection, h14) = 1, "T09c", "dopo l'attesa scaduta: nessun codice nuovo, precedente intatto")

                    ' T10 A conferma il cambio mentre B attende -> B = False; T11 A annulla -> B = True
                    For Each commitA As Boolean In New Boolean() {True, False}
                        Dim hx As String = NewHash()
                        Dim result As String = ""
                        Dim worker As New Thread(Sub() result = Issue(login1, plain, hx))
                        Using a As MySqlConnection = Open()
                            Using txA As MySqlTransaction = a.BeginTransaction()
                                Exec(a, "UPDATE login SET Email='" & other & "' WHERE id=" & login1.ToString(), txA)
                                worker.Start()
                                Dim stillWaiting As Boolean = Not worker.Join(1500)
                                If commitA Then txA.Commit() Else txA.Rollback()
                                worker.Join(20000)
                                If commitA Then
                                    Check(stillWaiting AndAlso result = "False" AndAlso RowsOf(connection, hx) = 0, "T10", "cambio confermato mentre l'emissione attende: NON emesso")
                                    Exec(connection, "UPDATE login SET Email='" & plain & "' WHERE id=" & login1.ToString())
                                Else
                                    Check(stillWaiting AndAlso result = "True" AndAlso ActiveOf(connection, hx) = 1, "T11", "cambio annullato mentre l'emissione attende: emesso")
                                End If
                            End Using
                        End Using
                    Next

                    ' T13 due emissioni insieme per lo stesso accesso: alla fine un solo codice attivo fra i due
                    Dim hA As String = NewHash(), hB As String = NewHash()
                    Dim rA As String = "", rB As String = ""
                    Dim tA As New Thread(Sub() rA = Issue(login1, plain, hA))
                    Dim tB As New Thread(Sub() rB = Issue(login1, plain, hB))
                    tA.Start() : tB.Start() : tA.Join(30000) : tB.Join(30000)
                    Check((rA = "True" OrElse rB = "True") AndAlso ActiveOf(connection, hA) + ActiveOf(connection, hB) = 1 AndAlso
                          IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE LoginId=" & login1.ToString() & " AND UsedAt IS NULL AND RevokedAt IS NULL") = 1,
                          "T13", "due emissioni insieme: un solo codice attivo per l'accesso")
                Finally
                    Try
                        If Hashes.Count > 0 Then Exec(connection, "DELETE FROM login_password_reset_tokens WHERE TokenHash IN ('" & String.Join("','", Hashes.ToArray()) & "')")
                        Exec(connection, "DELETE FROM login_password_reset_tokens WHERE CreatedBy='ks_test_issue'")
                        Exec(connection, "UPDATE login_password_reset_tokens t INNER JOIN ks_test_issue_codes_backup b ON b.id=t.id SET t.RevokedAt=b.RevokedAt")
                        Exec(connection, "UPDATE login l INNER JOIN ks_test_issue_login_backup b ON b.id=l.id SET l.Email=b.Email, l.Abilitato=b.Abilitato")
                    Catch ex As Exception
                        failed += 1
                        Console.WriteLine("HARNESS_ERROR ripristino: " & ex.GetType().Name)
                    End Try
                End Try
                Dim restored As Boolean = IntOf(connection, "SELECT COUNT(*) FROM login l INNER JOIN ks_test_issue_login_backup b ON b.id=l.id WHERE l.Email<=>b.Email AND l.Abilitato<=>b.Abilitato") = 2 AndAlso
                    IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens t INNER JOIN ks_test_issue_codes_backup b ON b.id=t.id WHERE NOT (t.RevokedAt<=>b.RevokedAt)") = 0 AndAlso
                    IntOf(connection, "SELECT COUNT(*) FROM login_password_reset_tokens WHERE LoginId IN (" & login1.ToString() & "," & login2.ToString() & ")") =
                    IntOf(connection, "SELECT COUNT(*) FROM ks_test_issue_codes_backup")
                Check(restored, "Z99", "dati di prova riportati allo stato di partenza")
                If restored Then
                    Exec(connection, "DROP TABLE IF EXISTS ks_test_issue_login_backup")
                    Exec(connection, "DROP TABLE IF EXISTS ks_test_issue_codes_backup")
                End If
            End Using
        Catch ex As Exception
            failed += 1
            Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & ": " & ex.Message)
        End Try
        Console.WriteLine("RESET_ISSUE_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
        Return If(failed = 0, 0, 1)
    End Function
End Module
