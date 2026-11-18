Option Strict On
Option Explicit On

Imports System
Imports System.Data
Imports MySql.Data.MySqlClient

' Harness di Tools/Test-OrderBeforePaymentPolicy.ps1 (PAYMENT-PAY-FIRST-BY-FLAG-1A), parte (D): esegue sul LAB locale il lettore REALE
' KeepStoreOrderBeforePaymentPolicy.TryRead con il connettore del sito e lo schema reale di pagamentitipo. Il flag 0 si prova dentro una
' transazione che viene sempre annullata (nessun dato resta modificato). Verifica l'identita del LAB prima di tutto; utente e segreto arrivano
' dall'ambiente del processo e non vengono mai stampati.
Module OrderBeforePaymentLabHarness
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const LabSchema As String = "keepstore_regorder_lab_20261025"
    Private total As Integer = 0
    Private failed As Integer = 0

    Private Sub Check(ByVal ok As Boolean, ByVal name As String)
        total += 1
        If Not ok Then
            failed += 1
            Console.WriteLine("FAIL " & name)
        End If
    End Sub

    Private Function Scalar(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction, ByVal sql As String) As Object
        Using command As New MySqlCommand(sql, connection, transaction)
            Return command.ExecuteScalar()
        End Using
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
            csb.DefaultCommandTimeout = 30UI
            Using connection As New MySqlConnection(csb.ConnectionString)
                connection.Open()
                Check(Convert.ToString(Scalar(connection, Nothing, "SELECT @@server_uuid")) = LabUuid AndAlso
                      Convert.ToInt32(Scalar(connection, Nothing, "SELECT @@port")) = 13317 AndAlso
                      Convert.ToString(Scalar(connection, Nothing, "SELECT DATABASE()")) = LabSchema, "guardia: identita del LAB")
                If failed > 0 Then
                    Console.WriteLine("ORDER_BEFORE_PAYMENT_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If

                ' Un metodo con carta (OnLine 3) e uno offline (OnLine 0) di un'azienda, e un'altra azienda che NON possiede quegli id.
                Dim company As Integer = Convert.ToInt32(Scalar(connection, Nothing, "SELECT COALESCE((SELECT AziendeID FROM pagamentitipo WHERE Web=1 GROUP BY AziendeID HAVING SUM(OnLine=3)>0 AND SUM(OnLine=0)>0 ORDER BY AziendeID LIMIT 1),0)"))
                Dim cardId As Integer = Convert.ToInt32(Scalar(connection, Nothing, "SELECT COALESCE((SELECT id FROM pagamentitipo WHERE Web=1 AND OnLine=3 AND AziendeID=" & company.ToString() & " ORDER BY id LIMIT 1),0)"))
                Dim offlineId As Integer = Convert.ToInt32(Scalar(connection, Nothing, "SELECT COALESCE((SELECT id FROM pagamentitipo WHERE Web=1 AND OnLine=0 AND AziendeID=" & company.ToString() & " ORDER BY id LIMIT 1),0)"))
                Dim otherCompany As Integer = Convert.ToInt32(Scalar(connection, Nothing, "SELECT COALESCE((SELECT AziendeID FROM pagamentitipo WHERE AziendeID<>" & company.ToString() & " ORDER BY AziendeID LIMIT 1),0)"))
                Check(company > 0 AndAlso cardId > 0 AndAlso offlineId > 0 AndAlso otherCompany > 0, "dati del LAB: carta, offline e una seconda azienda")
                If failed = 0 Then
                    Dim snap As PaymentPolicySnapshot = Nothing
                    Dim expectedFlag As Integer = Convert.ToInt32(Scalar(connection, Nothing, "SELECT ConfermaOrdinePrimaPagamento FROM pagamentitipo WHERE id=" & cardId.ToString()))
                    Check(KeepStoreOrderBeforePaymentPolicy.TryRead(connection, Nothing, company, cardId, snap) AndAlso snap IsNot Nothing AndAlso snap.OnLine = 3 AndAlso
                          snap.ConfirmBeforePayment = expectedFlag, "carta: riga letta con OnLine 3 e flag del database")
                    Check(KeepStoreOrderBeforePaymentPolicy.TryRead(connection, Nothing, company, offlineId, snap) AndAlso snap IsNot Nothing AndAlso snap.OnLine = 0, "offline: riga letta con OnLine 0")
                    Check(Not KeepStoreOrderBeforePaymentPolicy.TryRead(connection, Nothing, otherCompany, cardId, snap) AndAlso snap Is Nothing, "isolamento: il metodo di un'altra azienda non si legge")
                    Check(Not KeepStoreOrderBeforePaymentPolicy.TryRead(connection, Nothing, company, 2147483000, snap) AndAlso snap Is Nothing, "id inesistente: non letto")
                    Check(Not KeepStoreOrderBeforePaymentPolicy.TryRead(connection, Nothing, 0, cardId, snap) AndAlso snap Is Nothing, "azienda 0: non letto")

                    ' Flag 0 sullo schema reale, dentro una transazione sempre annullata.
                    Dim transaction As MySqlTransaction = connection.BeginTransaction()
                    Try
                        Using update As New MySqlCommand("UPDATE pagamentitipo SET ConfermaOrdinePrimaPagamento=0 WHERE id IN (" & cardId.ToString() & "," & offlineId.ToString() & ") AND AziendeID=" & company.ToString(), connection, transaction)
                            Check(update.ExecuteNonQuery() = 2, "transazione di prova: due righe a flag 0")
                        End Using
                        Check(KeepStoreOrderBeforePaymentPolicy.TryRead(connection, transaction, company, cardId, snap) AndAlso snap.ConfirmBeforePayment = 0, "carta con flag 0: letto 0")
                        Check(KeepStoreOrderBeforePaymentPolicy.Evaluate(True, snap, 3, 0, 4, False) = PaymentPolicyGateOutcome.NotAllowed, "carta con flag 0: ordine rifiutato")
                        Check(KeepStoreOrderBeforePaymentPolicy.Evaluate(True, snap, 3, 1, 4, False) = PaymentPolicyGateOutcome.Changed, "carta: bozza emessa con flag 1, database a 0 = nuova conferma")
                        Check(KeepStoreOrderBeforePaymentPolicy.TryRead(connection, transaction, company, offlineId, snap) AndAlso
                              KeepStoreOrderBeforePaymentPolicy.Decide(snap.OnLine, snap.ConfirmBeforePayment, 4, False) = OrderBeforePaymentDecision.NotSupported, "offline con flag 0: metodo rifiutato")
                        Check(KeepStoreOrderBeforePaymentPolicy.Decide(snap.OnLine, snap.ConfirmBeforePayment, 2, False) = OrderBeforePaymentDecision.OrderFirst, "offline con flag 0: il preventivo resta permesso")
                    Finally
                        transaction.Rollback()
                        transaction.Dispose()
                    End Try
                    Check(Convert.ToInt32(Scalar(connection, Nothing, "SELECT ConfermaOrdinePrimaPagamento FROM pagamentitipo WHERE id=" & cardId.ToString())) = expectedFlag, "dopo l'annullo: flag del LAB invariato")
                End If
            End Using
        Catch ex As Exception
            failed += 1
            Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & ": " & ex.Message)
        End Try
        Console.WriteLine("ORDER_BEFORE_PAYMENT_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
        Return If(failed = 0, 0, 1)
    End Function
End Module
