Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports MySql.Data.MySqlClient

' Harness di Tools/Test-PdpTools.ps1 (PDP-TOOLS-1A), parte (D): lettura REALE del canale WhatsApp sul LAB locale con il connettore del sito.
' Sola lettura. Verifica l'identita del LAB prima di tutto; utente e segreto arrivano dall'ambiente del processo e non vengono mai stampati.
' Le due classi qui sotto sostituiscono, solo per la compilazione dell'harness, la cache e il contesto del sito (non usati dalla lettura diretta).
Public NotInheritable Class StorefrontTenantScopedCache
    Public Shared Function GetOrLoad(Of T As Class)(ByVal area As String, ByVal databaseScopeKey As String, ByVal companyId As Integer,
                                                    ByVal extraKey As String, ByVal ttlSeconds As Integer, ByVal loader As Func(Of T)) As T
        Return loader()
    End Function
End Class

Public NotInheritable Class StorefrontSeoTenantContext
    Public Shared Function ConfiguredDatabaseScopeKey() As String
        Return "lab"
    End Function
End Class

Module PdpToolsLabHarness
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
            csb.DefaultCommandTimeout = 15UI
            Using connection As New MySqlConnection(csb.ConnectionString)
                connection.Open()
                Check(Convert.ToString(Scalar(connection, "SELECT @@server_uuid")) = LabUuid AndAlso
                      Convert.ToInt32(Scalar(connection, "SELECT @@port")) = 13317 AndAlso
                      Convert.ToString(Scalar(connection, "SELECT DATABASE()")) = LabSchema, "guardia: identita del LAB")
                If failed > 0 Then
                    Console.WriteLine("PDP_TOOLS_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
                    Return 1
                End If
                Using readOnlyCommand As New MySqlCommand("SET SESSION TRANSACTION READ ONLY", connection)
                    readOnlyCommand.ExecuteNonQuery()
                End Using

                ' Aziende con una sola riga WhatsApp abilitata: il canale deve uscire con il numero normalizzato e la regola come intero.
                Dim companies As New List(Of Integer)()
                Using command As New MySqlCommand("SELECT CAST(company_id AS SIGNED) AS c FROM social_buttons WHERE `key`='whatsapp' AND enabled=1 GROUP BY company_id HAVING COUNT(*)=1 ORDER BY c", connection)
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        While reader.Read()
                            companies.Add(Convert.ToInt32(reader("c")))
                        End While
                    End Using
                End Using
                Check(companies.Count >= 2, "dati del LAB: almeno due aziende con un pulsante WhatsApp abilitato")
                Check(companies.Contains(2), "dati del LAB: esiste l'azienda 2 (con tinyint(1) letto come Boolean diventerebbe 1)")

                For Each companyId As Integer In companies
                    Dim expectedRaw As String = Convert.ToString(Scalar(connection, "SELECT `value` FROM social_buttons WHERE `key`='whatsapp' AND enabled=1 AND company_id=" & companyId.ToString()))
                    Dim expectedRule As Integer = Convert.ToInt32(Scalar(connection, "SELECT CAST(COALESCE((SELECT enabled FROM social_buttons_rules WHERE company_id=" & companyId.ToString() & "),0) AS SIGNED)"))
                    Dim channel As ContactChannel = KeepStoreContactChannels.ReadChannel(connection, companyId)
                    Check(channel IsNot Nothing AndAlso channel.WhatsAppNumber = KeepStoreShareLinks.NormalizeWhatsAppNumber(expectedRaw) AndAlso channel.WhatsAppNumber <> "",
                          "azienda " & companyId.ToString() & ": numero letto e valido")
                    Check(channel IsNot Nothing AndAlso channel.WidgetEnabled = (expectedRule = 1), "azienda " & companyId.ToString() & ": regola del pulsante letta come intero")
                    Check(channel IsNot Nothing AndAlso (channel.Position = "left" OrElse channel.Position = "right"), "azienda " & companyId.ToString() & ": posizione normalizzata")
                Next

                ' Azienda senza righe: nessun canale, nessuna eccezione.
                Dim none As ContactChannel = KeepStoreContactChannels.ReadChannel(connection, 126)
                Check(none Is ContactChannel.None, "azienda senza pulsanti: nessun canale")

                ' La colonna grezza senza CAST viene davvero letta come Boolean dal connettore: e il motivo del CAST nella query del sito.
                Using command As New MySqlCommand("SELECT enabled FROM social_buttons_rules LIMIT 1", connection)
                    Dim rawValue As Object = command.ExecuteScalar()
                    Check(TypeOf rawValue Is Boolean, "connettore: tinyint(1) senza CAST arriva come Boolean (tipo " & If(rawValue Is Nothing, "Nothing", rawValue.GetType().Name) & ")")
                End Using
                Using command As New MySqlCommand(KeepStoreContactChannels.ChannelSql, connection)
                    command.Parameters.Add("@companyId", MySqlDbType.Int32).Value = companies(0)
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        Check(reader.Read() AndAlso Not TypeOf reader("WidgetEnabled") Is Boolean, "query del sito: la regola con CAST non arriva come Boolean")
                    End Using
                End Using
            End Using
        Catch ex As Exception
            failed += 1
            Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & ": " & ex.Message)
        End Try
        Console.WriteLine("PDP_TOOLS_LAB CHECKS=" & total.ToString() & " FAIL=" & failed.ToString())
        Return If(failed = 0, 0, 1)
    End Function
End Module
