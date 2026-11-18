Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Threading
Imports MySql.Data.MySqlClient

' Harness di Tools/Test-BancaSellaCallback.ps1 (BANCASELLA-CALLBACK-AUTH-1A), parte (D): esegue sul LAB locale il percorso PRODUTTIVO
' BancaSellaCallback.ProcessServerCallback (transazione propria, schema e trigger reali) su tre documenti reali non pagati del LAB, che alla fine
' vengono riportati esattamente allo stato di partenza. Per provare l'isolamento fra aziende il negozio della seconda azienda riceve per la
' durata della prova un nome sintetico (nel LAB le due aziende condividono lo stesso negozio). Nessun negozio reale viene stampato.
' Verifica l'identita del LAB prima di tutto; utente e segreto arrivano dall'ambiente del processo e non vengono mai stampati.
Module BancaSellaCallbackLabHarness
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const LabSchema As String = "keepstore_regorder_lab_20261025"
    Private Const SyntheticLogin As String = "KSTESTSHOP2"
    Private Const CodePrefix As String = "KSTEST-"
    Private total As Integer = 0
    Private failed As Integer = 0
    Private connectionString As String = ""

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

    Private Function Fields(ByVal result As String, ByVal documentId As Integer, ByVal code As String, Optional ByVal custom As String = Nothing) As BancaSellaDecrypted
        Dim f As New BancaSellaDecrypted()
        f.TransactionResult = result
        f.AuthorizationCode = code
        f.ShopTransactionId = "1/2026"
        f.BankTransactionId = "1"
        f.ErrorCode = If(result = "OK", "0", "1143")
        f.ErrorDescription = If(result = "OK", "Transazione correttamente effettuata", "Autorizzazione negata")
        f.CustomInfo = If(custom, "iddocumento=" & documentId.ToString() & "*P1*SITO=www.example.test")
        Return f
    End Function

    Private Function State(ByVal connection As MySqlConnection, ByVal documentId As Integer) As String
        Return Convert.ToString(Scalar(connection, "SELECT CONCAT(COALESCE(Pagato,0),'/',COALESCE(StatoPagamentoWeb,0)) FROM documenti WHERE id=" & documentId.ToString()))
    End Function

    Private Function Rows(ByVal connection As MySqlConnection, ByVal documentId As Integer) As Integer
        Return IntOf(connection, "SELECT COUNT(*) FROM bancasella_ordini_pagati WHERE DocumentiId=" & documentId.ToString() & " AND codiceAutorizzazione LIKE '" & CodePrefix & "%'")
    End Function

    Private Function Run(ByVal login As String, ByVal f As BancaSellaDecrypted) As BancaSellaCallbackAction
        Return BancaSellaCallback.ProcessServerCallback(connectionString, login, f).Action
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
            connectionString = csb.ConnectionString
            Using connection As New MySqlConnection(connectionString)
                connection.Open()
                Check(Convert.ToString(Scalar(connection, "SELECT @@server_uuid")) = LabUuid AndAlso IntOf(connection, "SELECT @@port") = 13317 AndAlso
                      Convert.ToString(Scalar(connection, "SELECT DATABASE()")) = LabSchema, "guardia: identita del LAB")
                If failed > 0 Then
                    Console.WriteLine("BANCASELLA_CALLBACK_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If

                ' Due aziende con un negozio configurato; tre documenti non pagati della prima, uno della seconda.
                Dim company1 As Integer = IntOf(connection, "SELECT COALESCE(MIN(AziendeId),0) FROM bancasella_impostazioni_azienda WHERE COALESCE(TRIM(shopLogin),'')<>''")
                Dim company2 As Integer = IntOf(connection, "SELECT COALESCE(MIN(AziendeId),0) FROM bancasella_impostazioni_azienda WHERE COALESCE(TRIM(shopLogin),'')<>'' AND AziendeId>" & company1.ToString())
                Dim pick As String = "SELECT COALESCE((SELECT d.id FROM documenti d WHERE d.AziendeId={0} AND COALESCE(d.Pagato,0)=0 AND d.TipoDocumentiId=4 AND NOT EXISTS (SELECT 1 FROM bancasella_ordini_pagati b WHERE b.DocumentiId=d.id) ORDER BY d.id DESC LIMIT 1 OFFSET {1}),0)"
                Dim docA As Integer = IntOf(connection, String.Format(pick, company1, 0))
                Dim docC As Integer = IntOf(connection, String.Format(pick, company1, 1))
                Dim docD As Integer = IntOf(connection, String.Format(pick, company1, 2))
                Dim docB As Integer = IntOf(connection, String.Format(pick, company2, 0))
                Dim missing As Integer = IntOf(connection, "SELECT MAX(id)+100000 FROM documenti")
                Check(company1 > 0 AndAlso company2 > 0 AndAlso docA > 0 AndAlso docB > 0 AndAlso docC > 0 AndAlso docD > 0, "dati del LAB: due aziende con negozio e quattro documenti non pagati")
                If failed > 0 Then
                    Console.WriteLine("BANCASELLA_CALLBACK_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If

                Dim ids As String = docA.ToString() & "," & docB.ToString() & "," & docC.ToString() & "," & docD.ToString()
                Dim login1 As String = Convert.ToString(Scalar(connection, "SELECT shopLogin FROM bancasella_impostazioni_azienda WHERE AziendeId=" & company1.ToString() & " ORDER BY id LIMIT 1"))
                Exec(connection, "DROP TEMPORARY TABLE IF EXISTS ks_test_doc_backup")
                Exec(connection, "CREATE TEMPORARY TABLE ks_test_doc_backup AS SELECT id, Pagato, StatoPagamentoWeb, DataStatoPagamentoWeb, UltimoEsitoPagamentoWeb FROM documenti WHERE id IN (" & ids & ")")
                Exec(connection, "DROP TEMPORARY TABLE IF EXISTS ks_test_login_backup")
                Exec(connection, "CREATE TEMPORARY TABLE ks_test_login_backup AS SELECT id, shopLogin FROM bancasella_impostazioni_azienda WHERE AziendeId=" & company2.ToString())
                Try
                    Exec(connection, "UPDATE bancasella_impostazioni_azienda SET shopLogin='" & SyntheticLogin & "' WHERE AziendeId=" & company2.ToString())
                    Exec(connection, "UPDATE documenti SET StatoPagamentoWeb=1 WHERE id IN (" & ids & ")")
                    Dim c1 As String = CodePrefix & Guid.NewGuid().ToString("N").Substring(0, 12)
                    Dim c2 As String = CodePrefix & Guid.NewGuid().ToString("N").Substring(0, 12)
                    Dim c3 As String = CodePrefix & Guid.NewGuid().ToString("N").Substring(0, 12)

                    Check(BancaSellaCallback.IsKnownLogin(connectionString, login1) AndAlso BancaSellaCallback.IsKnownLogin(connectionString, SyntheticLogin) AndAlso
                          Not BancaSellaCallback.IsKnownLogin(connectionString, "KSTESTUNKNOWN") AndAlso Not BancaSellaCallback.IsKnownLogin(connectionString, ""), "negozi configurati riconosciuti, sconosciuti no")

                    ' Rifiuti: nessuna scrittura
                    Check(Run("KSTESTUNKNOWN", Fields("OK", docA, c1)) = BancaSellaCallbackAction.Rejected AndAlso State(connection, docA) = "0/1" AndAlso Rows(connection, docA) = 0, "negozio non configurato: rifiutato, documento intatto")
                    Check(Run(SyntheticLogin, Fields("OK", docA, c1)) = BancaSellaCallbackAction.Rejected AndAlso State(connection, docA) = "0/1" AndAlso Rows(connection, docA) = 0, "negozio di un'altra azienda: rifiutato, documento intatto")
                    Check(Run(login1, Fields("OK", docB, c1)) = BancaSellaCallbackAction.Rejected AndAlso State(connection, docB) = "0/1" AndAlso Rows(connection, docB) = 0, "negozio della prima azienda su documento della seconda: rifiutato")
                    Check(Run(login1, Fields("OK", missing, c1)) = BancaSellaCallbackAction.Rejected, "documento inesistente: rifiutato")
                    Check(Run(login1, Fields("OK", docA, c1, "iddocumento=coupon-" & docA.ToString() & "*P1*sito=x")) = BancaSellaCallbackAction.Rejected AndAlso State(connection, docA) = "0/1", "riferimento coupon: nessuna scrittura")
                    Check(Run(login1, Fields("OK", docA, c1, "iddocumento=" & docA.ToString() & " OR 1=1")) = BancaSellaCallbackAction.Rejected AndAlso State(connection, docA) = "0/1", "riferimento malformato: nessuna scrittura")

                    ' Esiti che non scrivono
                    Check(Run(login1, Fields("XX", docA, c1)) = BancaSellaCallbackAction.NoChange AndAlso State(connection, docA) = "0/1", "esito in sospeso: nessuna scrittura")
                    Check(Run(login1, Fields("OK", docA, "")) = BancaSellaCallbackAction.NoChange AndAlso State(connection, docA) = "0/1" AndAlso Rows(connection, docA) = 0, "OK senza codice: non segna pagato")

                    ' KO, poi OK, poi ripetizioni
                    Check(Run(login1, Fields("KO", docA, "")) = BancaSellaCallbackAction.MarkFailed AndAlso State(connection, docA) = "0/3", "KO: stato fallito, non pagato")
                    Check(Run(login1, Fields("OK", docA, c1)) = BancaSellaCallbackAction.MarkPaid AndAlso State(connection, docA) = "1/2" AndAlso Rows(connection, docA) = 1, "OK dopo KO: pagato, una riga")
                    Check(Convert.ToString(Scalar(connection, "SELECT UltimoEsitoPagamentoWeb FROM documenti WHERE id=" & docA.ToString())) = BancaSellaCallback.PaidOutcome, "OK: esito scritto sul documento")
                    Check(Run(login1, Fields("OK", docA, c1)) = BancaSellaCallbackAction.RecordOnlyAlreadyPaid AndAlso State(connection, docA) = "1/2" AndAlso Rows(connection, docA) = 1, "stesso OK ripetuto: nessuna riga in piu")
                    Check(Run(login1, Fields("OK", docA, c2)) = BancaSellaCallbackAction.RecordOnlyAlreadyPaid AndAlso State(connection, docA) = "1/2" AndAlso Rows(connection, docA) = 2, "secondo incasso diverso: registrato, documento intatto")
                    Check(Run(login1, Fields("KO", docA, "")) = BancaSellaCallbackAction.NoChange AndAlso State(connection, docA) = "1/2", "KO dopo OK: resta pagato")
                    Check(Run(login1, Fields("XX", docA, "")) = BancaSellaCallbackAction.NoChange AndAlso State(connection, docA) = "1/2", "in sospeso dopo OK: resta pagato")

                    ' Seconda azienda con il suo negozio
                    Check(Run(SyntheticLogin, Fields("OK", docB, c1)) = BancaSellaCallbackAction.MarkPaid AndAlso State(connection, docB) = "1/2" AndAlso Rows(connection, docB) = 1, "seconda azienda col suo negozio: pagato (stesso codice di un altro documento ammesso)")

                    ' Documento non piu in attesa (Pagato diverso da 0) che riceve un OK: riga registrata, stato intatto
                    Exec(connection, "UPDATE documenti SET Pagato=2 WHERE id=" & docD.ToString())
                    Check(Run(login1, Fields("OK", docD, c2)) = BancaSellaCallbackAction.RecordOnlyAlreadyPaid AndAlso State(connection, docD) = "2/1" AndAlso Rows(connection, docD) = 1, "OK su documento con Pagato diverso da 0: registrato, stato intatto")

                    ' Due conferme identiche nello stesso istante: un solo pagamento, una sola riga
                    Dim results As New List(Of BancaSellaCallbackAction)()
                    Dim errors As Integer = 0
                    Dim gate As New ManualResetEvent(False)
                    Dim workers As New List(Of Thread)()
                    For i As Integer = 1 To 4
                        Dim worker As New Thread(Sub()
                                                     gate.WaitOne()
                                                     Try
                                                         Dim action As BancaSellaCallbackAction = Run(login1, Fields("OK", docC, c3))
                                                         SyncLock results
                                                             results.Add(action)
                                                         End SyncLock
                                                     Catch
                                                         Interlocked.Increment(errors)
                                                     End Try
                                                 End Sub)
                        workers.Add(worker)
                        worker.Start()
                    Next
                    ' La riga del documento resta bloccata da un'altra connessione finche tutte le conferme sono partite: cosi si sovrappongono davvero.
                    Using holder As New MySqlConnection(connectionString)
                        holder.Open()
                        Dim holderTransaction As MySqlTransaction = holder.BeginTransaction()
                        Using hold As New MySqlCommand("SELECT id FROM documenti WHERE id=" & docC.ToString() & " FOR UPDATE", holder, holderTransaction)
                            hold.ExecuteScalar()
                        End Using
                        gate.Set()
                        Thread.Sleep(2500)
                        holderTransaction.Rollback()
                        holderTransaction.Dispose()
                    End Using
                    For Each worker As Thread In workers
                        worker.Join()
                    Next
                    Dim paidCount As Integer = 0
                    For Each action As BancaSellaCallbackAction In results
                        If action = BancaSellaCallbackAction.MarkPaid Then paidCount += 1
                    Next
                    Check(errors = 0 AndAlso results.Count = 4 AndAlso paidCount = 1 AndAlso State(connection, docC) = "1/2" AndAlso Rows(connection, docC) = 1, "quattro conferme identiche insieme: un solo pagamento e una sola riga (pagati=" & paidCount.ToString() & ", errori=" & errors.ToString() & ")")

                    ' Host di ritorno dell'azienda del documento
                    Dim hosts As List(Of String) = BancaSellaCallback.LoadCompanyHosts(connectionString, docA)
                    Dim url1 As String = Convert.ToString(Scalar(connection, "SELECT URL1 FROM aziende WHERE id=" & company1.ToString() & " LIMIT 1"))
                    Dim url2Other As String = Convert.ToString(Scalar(connection, "SELECT URL1 FROM aziende WHERE id=" & company2.ToString() & " LIMIT 1"))
                    Check(hosts.Count > 0 AndAlso BancaSellaCallback.ChooseReturnHost(url1, hosts) = BancaSellaCallback.NormalizeHost(url1) AndAlso
                          BancaSellaCallback.ChooseReturnHost(url2Other, hosts) = "" AndAlso BancaSellaCallback.LoadCompanyHosts(connectionString, missing).Count = 0, "host di ritorno: solo quelli dell'azienda del documento")
                Finally
                    Exec(connection, "DELETE FROM bancasella_ordini_pagati WHERE codiceAutorizzazione LIKE '" & CodePrefix & "%'")
                    Exec(connection, "UPDATE documenti d INNER JOIN ks_test_doc_backup b ON b.id=d.id SET d.Pagato=b.Pagato, d.StatoPagamentoWeb=b.StatoPagamentoWeb, d.DataStatoPagamentoWeb=b.DataStatoPagamentoWeb, d.UltimoEsitoPagamentoWeb=b.UltimoEsitoPagamentoWeb")
                    Exec(connection, "UPDATE bancasella_impostazioni_azienda s INNER JOIN ks_test_login_backup b ON b.id=s.id SET s.shopLogin=b.shopLogin")
                End Try
                Check(IntOf(connection, "SELECT COUNT(*) FROM bancasella_ordini_pagati WHERE codiceAutorizzazione LIKE '" & CodePrefix & "%'") = 0 AndAlso
                      IntOf(connection, "SELECT COUNT(*) FROM bancasella_impostazioni_azienda WHERE shopLogin='" & SyntheticLogin & "'") = 0 AndAlso
                      IntOf(connection, "SELECT COUNT(*) FROM documenti d INNER JOIN ks_test_doc_backup b ON b.id=d.id WHERE NOT (d.Pagato<=>b.Pagato AND d.StatoPagamentoWeb<=>b.StatoPagamentoWeb AND d.UltimoEsitoPagamentoWeb<=>b.UltimoEsitoPagamentoWeb)") = 0, "ripristino: LAB riportato allo stato di partenza")
            End Using
        Catch ex As Exception
            failed += 1
            Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & ": " & ex.Message)
        End Try
        Console.WriteLine("BANCASELLA_CALLBACK_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
        Return If(failed = 0, 0, 1)
    End Function
End Module
