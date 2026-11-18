Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports MySql.Data.MySqlClient

' Harness di Tools/Test-AccountOrders1B.ps1 (KS-DASHBOARD-ORDERS-1B), parte (D): esegue sul LAB locale la query REALE della lista «I miei ordini» prodotta da
' KeepStoreAccountOrderFilters.BuildListSql, con il connettore del sito, e la confronta con query di controllo scritte a mano sulla tabella documenti.
' Verifica l'isolamento: lo stesso utente in un'altra azienda e un altro utente della stessa azienda non compaiono mai. Sola lettura.
' Verifica l'identita del LAB prima di tutto; utente e segreto arrivano dall'ambiente del processo e non vengono mai stampati.
Module AccountOrdersLabHarness
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

    Private Function Scalar(ByVal connection As MySqlConnection, ByVal sql As String) As Object
        Using command As New MySqlCommand(sql, connection)
            Return command.ExecuteScalar()
        End Using
    End Function

    ' Esegue la query del sito con i parametri tipizzati e restituisce gli id nell'ordine della lista.
    Private Function SiteIds(ByVal connection As MySqlConnection, ByVal utentiId As Integer, ByVal aziendaId As Integer, ByVal tipoId As Integer,
                             ByVal stato As Integer, ByVal hasDal As Boolean, ByVal dal As DateTime, ByVal hasAl As Boolean, ByVal al As DateTime) As List(Of Integer)
        Dim ids As New List(Of Integer)()
        Dim sql As String = KeepStoreAccountOrderFilters.BuildListSql(stato > -1, hasDal, hasAl)
        Using command As New MySqlCommand(sql, connection)
            command.Parameters.Add("?UtentiId", MySqlDbType.Int32).Value = utentiId
            command.Parameters.Add("?AziendaId", MySqlDbType.Int32).Value = aziendaId
            command.Parameters.Add("?TipoDocumentiId", MySqlDbType.Int32).Value = tipoId
            If stato > -1 Then command.Parameters.Add("?Stato", MySqlDbType.Int32).Value = stato
            If hasDal Then command.Parameters.Add("?Dal", MySqlDbType.Date).Value = dal
            If hasAl Then command.Parameters.Add("?Al", MySqlDbType.Date).Value = al
            Using reader As MySqlDataReader = command.ExecuteReader()
                While reader.Read()
                    ids.Add(Convert.ToInt32(reader("Id")))
                End While
            End Using
        End Using
        Return ids
    End Function

    ' Controllo scritto a mano, direttamente sulla tabella documenti (non sulla vista).
    Private Function ControlIds(ByVal connection As MySqlConnection, ByVal utentiId As Integer, ByVal aziendaId As Integer, ByVal tipoId As Integer, ByVal extraWhere As String) As List(Of Integer)
        Dim ids As New List(Of Integer)()
        Using command As New MySqlCommand("SELECT id FROM documenti WHERE UtentiId=" & utentiId.ToString() & " AND AziendeId=" & aziendaId.ToString() & " AND TipoDocumentiId=" & tipoId.ToString() & extraWhere & " ORDER BY id DESC", connection)
            Using reader As MySqlDataReader = command.ExecuteReader()
                While reader.Read()
                    ids.Add(Convert.ToInt32(reader("id")))
                End While
            End Using
        End Using
        Return ids
    End Function

    Private Function SameList(ByVal a As List(Of Integer), ByVal b As List(Of Integer)) As Boolean
        If a.Count <> b.Count Then Return False
        For i As Integer = 0 To a.Count - 1
            If a(i) <> b(i) Then Return False
        Next
        Return True
    End Function

    Private Function Intersects(ByVal a As List(Of Integer), ByVal b As List(Of Integer)) As Boolean
        For Each x As Integer In a
            If b.Contains(x) Then Return True
        Next
        Return False
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
                Check(Convert.ToString(Scalar(connection, "SELECT @@server_uuid")) = LabUuid AndAlso
                      Convert.ToInt32(Scalar(connection, "SELECT @@port")) = 13317 AndAlso
                      Convert.ToString(Scalar(connection, "SELECT DATABASE()")) = LabSchema, "guardia: identita del LAB")
                If failed > 0 Then
                    Console.WriteLine("ACCOUNT_ORDERS_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If
                Using readOnlyCommand As New MySqlCommand("SET SESSION TRANSACTION READ ONLY", connection)
                    readOnlyCommand.ExecuteNonQuery()
                End Using

                ' La vista della lista non moltiplica le righe: tante righe quanti documenti (altrimenti conteggi e schede sarebbero doppi).
                Check(Convert.ToInt64(Scalar(connection, "SELECT COUNT(*) FROM vdocumenti")) = Convert.ToInt64(Scalar(connection, "SELECT COUNT(*) FROM documenti")), "vdocumenti ha una riga per documento")

                ' Utente U con ordini (tipo 4) in ENTRAMBE le aziende; utente V con ordini nell'azienda 1.
                Dim tipo As Integer = 4
                Dim userU As Integer = Convert.ToInt32(Scalar(connection, "SELECT COALESCE((SELECT UtentiId FROM documenti WHERE TipoDocumentiId=4 AND AziendeId IN (1,2) GROUP BY UtentiId HAVING SUM(AziendeId=1) BETWEEN 3 AND 15 AND SUM(AziendeId=2) BETWEEN 1 AND 15 ORDER BY COUNT(*) DESC LIMIT 1),0)"))
                Dim userV As Integer = Convert.ToInt32(Scalar(connection, "SELECT COALESCE((SELECT UtentiId FROM documenti WHERE TipoDocumentiId=4 AND AziendeId=1 AND UtentiId<>" & userU.ToString() & " GROUP BY UtentiId HAVING COUNT(*) BETWEEN 3 AND 15 ORDER BY COUNT(*) DESC LIMIT 1),0)"))
                Check(userU > 0 AndAlso userV > 0, "dati del LAB: esiste un utente con ordini in due aziende e un secondo utente")
                If userU > 0 AndAlso userV > 0 Then
                    Dim u1 As List(Of Integer) = SiteIds(connection, userU, 1, tipo, -1, False, DateTime.MinValue, False, DateTime.MinValue)
                    Dim u2 As List(Of Integer) = SiteIds(connection, userU, 2, tipo, -1, False, DateTime.MinValue, False, DateTime.MinValue)
                    Dim v1 As List(Of Integer) = SiteIds(connection, userV, 1, tipo, -1, False, DateTime.MinValue, False, DateTime.MinValue)
                    Dim c1 As List(Of Integer) = ControlIds(connection, userU, 1, tipo, "")
                    Dim c2 As List(Of Integer) = ControlIds(connection, userU, 2, tipo, "")
                    Dim cv As List(Of Integer) = ControlIds(connection, userV, 1, tipo, "")
                    Check(u1.Count > 0 AndAlso u2.Count > 0 AndAlso v1.Count > 0, "le tre letture restituiscono ordini")
                    Check(SameList(u1, c1), "utente U azienda 1: stessi documenti del controllo (" & u1.Count.ToString() & " contro " & c1.Count.ToString() & ")")
                    Check(SameList(u2, c2), "utente U azienda 2: stessi documenti del controllo (" & u2.Count.ToString() & " contro " & c2.Count.ToString() & ")")
                    Check(SameList(v1, cv), "utente V azienda 1: stessi documenti del controllo (" & v1.Count.ToString() & " contro " & cv.Count.ToString() & ")")
                    Check(Not Intersects(u1, u2), "isolamento: nessun documento di U azienda 2 nella lista di U azienda 1")
                    Check(Not Intersects(u1, v1) AndAlso Not Intersects(u2, v1), "isolamento: nessun documento di V nelle liste di U")
                    ' un'azienda senza documenti di U: lista vuota
                    Check(SiteIds(connection, userU, 99, tipo, -1, False, DateTime.MinValue, False, DateTime.MinValue).Count = 0, "azienda senza documenti: lista vuota")
                    Check(SiteIds(connection, 0, 1, tipo, -1, False, DateTime.MinValue, False, DateTime.MinValue).Count = 0, "utente 0: lista vuota")

                    ' filtro di stato, tutti gli stati presenti nei documenti di U azienda 1
                    Dim statiRows As New List(Of Integer)()
                    Using command As New MySqlCommand("SELECT DISTINCT StatiId FROM documenti WHERE UtentiId=" & userU.ToString() & " AND AziendeId=1 AND TipoDocumentiId=4 ORDER BY StatiId", connection)
                        Using reader As MySqlDataReader = command.ExecuteReader()
                            While reader.Read()
                                statiRows.Add(Convert.ToInt32(reader("StatiId")))
                            End While
                        End Using
                    End Using
                    Check(statiRows.Count >= 1, "dati del LAB: almeno uno stato nei documenti di U")
                    For Each st As Integer In statiRows
                        Dim got As List(Of Integer) = SiteIds(connection, userU, 1, tipo, st, False, DateTime.MinValue, False, DateTime.MinValue)
                        Check(SameList(got, ControlIds(connection, userU, 1, tipo, " AND StatiId=" & st.ToString())), "filtro di stato " & st.ToString() & ": stessi documenti del controllo")
                    Next

                    ' intervalli di date: solo dal, solo al, entrambi (la colonna e di tipo date)
                    Dim minDate As DateTime = Convert.ToDateTime(Scalar(connection, "SELECT MIN(DataDocumento) FROM documenti WHERE UtentiId=" & userU.ToString() & " AND AziendeId=1 AND TipoDocumentiId=4"))
                    Dim maxDate As DateTime = Convert.ToDateTime(Scalar(connection, "SELECT MAX(DataDocumento) FROM documenti WHERE UtentiId=" & userU.ToString() & " AND AziendeId=1 AND TipoDocumentiId=4"))
                    Dim midDate As DateTime = minDate.AddDays(CInt(Math.Floor((maxDate - minDate).TotalDays / 2.0)))
                    Check(SameList(SiteIds(connection, userU, 1, tipo, -1, True, midDate, False, DateTime.MinValue), ControlIds(connection, userU, 1, tipo, " AND DataDocumento >= '" & midDate.ToString("yyyy-MM-dd") & "'")), "solo dal: stessi documenti del controllo")
                    Check(SameList(SiteIds(connection, userU, 1, tipo, -1, False, DateTime.MinValue, True, midDate), ControlIds(connection, userU, 1, tipo, " AND DataDocumento <= '" & midDate.ToString("yyyy-MM-dd") & "'")), "solo al: stessi documenti del controllo")
                    Check(SameList(SiteIds(connection, userU, 1, tipo, -1, True, minDate, True, maxDate), c1), "dal minimo al massimo: tutti i documenti (estremi inclusi)")
                    Check(SiteIds(connection, userU, 1, tipo, -1, True, maxDate.AddDays(1), False, DateTime.MinValue).Count = 0, "dal dopo l'ultimo documento: nessuno")
                End If
            End Using
        Catch ex As Exception
            failed += 1
            Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & ": " & ex.Message)
        End Try
        Console.WriteLine("ACCOUNT_ORDERS_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
        Return If(failed = 0, 0, 1)
    End Function
End Module
