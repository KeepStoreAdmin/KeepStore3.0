Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Runtime.InteropServices
Imports System.Text

' KS-C02-TRACK-ORDER-TENANT-SCOPE-1A.
' Esegue su SQLite di sistema (winsqlite3.dll, in memoria) la query REALE di track-your-order.aspx.vb, estratta
' meccanicamente dal sorgente (candidato e baseline), e il metodo reale ResolveTrackingCompanyId insieme alla
' selezione tenant reale StorefrontCanonicalHostPolicy.SelectExactTenant. Dati e host sono sintetici (.invalid).
' Nessun MySQL, IIS, rete o dato personale. SQLite non certifica la semantica MySQL.
Friend NotInheritable Class NativeSqlite
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_open(ByVal filename As Byte(), ByRef db As IntPtr) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_close(ByVal db As IntPtr) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_exec(ByVal db As IntPtr, ByVal sql As Byte(), ByVal callback As IntPtr, ByVal arg As IntPtr, ByRef errmsg As IntPtr) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_prepare_v2(ByVal db As IntPtr, ByVal sql As Byte(), ByVal nByte As Integer, ByRef stmt As IntPtr, ByRef tail As IntPtr) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_bind_parameter_index(ByVal stmt As IntPtr, ByVal name As Byte()) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_bind_text(ByVal stmt As IntPtr, ByVal index As Integer, ByVal value As Byte(), ByVal length As Integer, ByVal destructor As IntPtr) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_bind_int64(ByVal stmt As IntPtr, ByVal index As Integer, ByVal value As Long) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_step(ByVal stmt As IntPtr) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_column_count(ByVal stmt As IntPtr) As Integer
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_column_name(ByVal stmt As IntPtr, ByVal index As Integer) As IntPtr
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_column_text(ByVal stmt As IntPtr, ByVal index As Integer) As IntPtr
    End Function
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_finalize(ByVal stmt As IntPtr) As Integer
    End Function

    Private Const SqliteRow As Integer = 100
    Private Const SqliteDone As Integer = 101
    Private ReadOnly Transient As New IntPtr(-1)
    Private handle As IntPtr

    Private Shared Function Utf8Z(ByVal value As String) As Byte()
        Dim raw As Byte() = Encoding.UTF8.GetBytes(value)
        Dim withNul(raw.Length) As Byte
        Array.Copy(raw, withNul, raw.Length)
        Return withNul
    End Function

    Private Shared Function ReadUtf8(ByVal pointer As IntPtr) As String
        If pointer = IntPtr.Zero Then Return Nothing
        Dim length As Integer = 0
        While Marshal.ReadByte(pointer, length) <> 0
            length += 1
        End While
        Dim buffer(length - 1) As Byte
        If length > 0 Then Marshal.Copy(pointer, buffer, 0, length)
        Return Encoding.UTF8.GetString(buffer)
    End Function

    Public Sub New()
        If sqlite3_open(Utf8Z(":memory:"), handle) <> 0 Then Throw New InvalidOperationException("SQLITE_OPEN_FAILED")
    End Sub

    Public Sub Execute(ByVal sql As String)
        Dim message As IntPtr = IntPtr.Zero
        If sqlite3_exec(handle, Utf8Z(sql), IntPtr.Zero, IntPtr.Zero, message) <> 0 Then
            Throw New InvalidOperationException("SQLITE_EXEC_FAILED: " & ReadUtf8(message))
        End If
    End Sub

    ' Esegue SELECT con parametri con nome (@nome) tipizzati: testo o intero a 64 bit.
    Public Function Query(ByVal sql As String,
                          ByVal textParameters As Dictionary(Of String, String),
                          ByVal integerParameters As Dictionary(Of String, Long)) As List(Of Dictionary(Of String, String))
        Dim rows As New List(Of Dictionary(Of String, String))()
        Dim statement As IntPtr = IntPtr.Zero
        Dim tail As IntPtr = IntPtr.Zero
        If sqlite3_prepare_v2(handle, Utf8Z(sql), -1, statement, tail) <> 0 Then Throw New InvalidOperationException("SQLITE_PREPARE_FAILED")
        Try
            If textParameters IsNot Nothing Then
                For Each pair As KeyValuePair(Of String, String) In textParameters
                    Dim index As Integer = sqlite3_bind_parameter_index(statement, Utf8Z(pair.Key))
                    If index > 0 Then
                        Dim bytes As Byte() = Encoding.UTF8.GetBytes(pair.Value)
                        sqlite3_bind_text(statement, index, bytes, bytes.Length, Transient)
                    End If
                Next
            End If
            If integerParameters IsNot Nothing Then
                For Each pair As KeyValuePair(Of String, Long) In integerParameters
                    Dim index As Integer = sqlite3_bind_parameter_index(statement, Utf8Z(pair.Key))
                    If index > 0 Then sqlite3_bind_int64(statement, index, pair.Value)
                Next
            End If
            Dim columns As Integer = sqlite3_column_count(statement)
            While True
                Dim code As Integer = sqlite3_step(statement)
                If code = SqliteDone Then Exit While
                If code <> SqliteRow Then Throw New InvalidOperationException("SQLITE_STEP_FAILED")
                Dim row As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
                For i As Integer = 0 To columns - 1
                    row(ReadUtf8(sqlite3_column_name(statement, i))) = ReadUtf8(sqlite3_column_text(statement, i))
                Next
                rows.Add(row)
            End While
        Finally
            sqlite3_finalize(statement)
        End Try
        Return rows
    End Function

    Public Sub Close()
        If handle <> IntPtr.Zero Then sqlite3_close(handle)
        handle = IntPtr.Zero
    End Sub
End Class

Module TrackOrderTenantScopeHarness
    Private tests As Integer
    Private failures As Integer
    Private database As NativeSqlite
    Private tenants As List(Of StorefrontSeoTenantIdentity)

    Private Sub Check(ByVal name As String, ByVal condition As Boolean)
        tests += 1
        If condition Then Return
        failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Private Sub Seed()
        database = New NativeSqlite()
        ' Schema minimo delle sole colonne usate dalla query reale. NDocumento ha affinita numerica come in MySQL.
        database.Execute("CREATE TABLE utenti(Id INTEGER PRIMARY KEY, AziendeId INTEGER NOT NULL, Email TEXT);" &
                         "CREATE TABLE vettori(id INTEGER PRIMARY KEY, Link_Tracking TEXT);" &
                         "CREATE TABLE pagamentitipo(id INTEGER PRIMARY KEY, Descrizione TEXT);" &
                         "CREATE TABLE vdocumenti(id INTEGER PRIMARY KEY, NDocumento INTEGER, DataDocumento TEXT, TotaleDocumento REAL, " &
                         "StatiDescrizione1 TEXT, Tracking TEXT, VettoriId INTEGER, PagamentiTipoId INTEGER, TipoDocumentiId INTEGER, " &
                         "UtentiId INTEGER, AziendeId INTEGER);")
        database.Execute("INSERT INTO vettori VALUES(1,'https://carrier.invalid/t/{tracking}');" &
                         "INSERT INTO pagamentitipo VALUES(1,'SYNTHETIC-PAY');")
        ' Stessa email "alice" registrata in entrambe le vetrine dello stesso database (utenti distinti per azienda).
        database.Execute("INSERT INTO utenti VALUES(701,1,'alice@example.invalid');" &
                         "INSERT INTO utenti VALUES(702,2,'alice@example.invalid');" &
                         "INSERT INTO utenti VALUES(703,1,'bob@example.invalid');" &
                         "INSERT INTO utenti VALUES(704,2,'carol@example.invalid');" &
                         "INSERT INTO utenti VALUES(705,1,'dave@example.invalid');")
        database.Execute("INSERT INTO vdocumenti VALUES(9001,1001,'2026-01-10',10.0,'S-C1-OLD','T9001',1,1,4,701,1);" &
                         "INSERT INTO vdocumenti VALUES(9006,1001,'2026-03-10',11.0,'S-C1-NEW','T9006',1,1,4,701,1);" &
                         "INSERT INTO vdocumenti VALUES(9010,1001,'2026-02-10',12.0,'S-C2','T9010',1,1,4,702,2);" &
                         "INSERT INTO vdocumenti VALUES(9003,2002,'2026-02-11',20.0,'S-C1-BOB','T9003',1,1,4,703,1);" &
                         "INSERT INTO vdocumenti VALUES(9004,3003,'2026-02-12',30.0,'S-C2-CAROL','T9004',1,1,4,704,2);" &
                         "INSERT INTO vdocumenti VALUES(9005,4004,'2026-02-13',40.0,'S-C1-NOT-ORDER','T9005',1,1,3,701,1);" &
                         "INSERT INTO vdocumenti VALUES(9007,5005,'2026-02-14',50.0,'S-C2-MISMATCH','T9007',1,1,4,705,2);")
    End Sub

    Private Function Host(ByVal company As Integer, ByVal primary As String, ByVal secondary As String) As StorefrontSeoTenantIdentity
        Return StorefrontCanonicalHostPolicy.CreateTenant(company, "SYNTHETIC-" & company.ToString(), "SYNTHETIC", primary, secondary, "", company)
    End Function

    ' Replica la logica della pagina: risolve il tenant dall'host, applica il metodo reale; azienda 0 = nessuna lettura.
    Private Function ResolveCompany(ByVal requestHost As String, ByVal list As IEnumerable(Of StorefrontSeoTenantIdentity), ByVal loopback As Boolean) As Integer
        Return TrackResolverFixture.ResolveTrackingCompanyId(StorefrontCanonicalHostPolicy.SelectExactTenant(list, requestHost, loopback))
    End Function

    Private Function Lookup(ByVal sql As String, ByVal company As Integer, ByVal withCompany As Boolean, ByVal email As String, ByVal number As String) As List(Of Dictionary(Of String, String))
        Dim textValues As New Dictionary(Of String, String) From {{"@n", number}, {"@email", email}}
        Dim integerValues As Dictionary(Of String, Long) = Nothing
        If withCompany Then integerValues = New Dictionary(Of String, Long) From {{"@aziendaId", company}}
        Return database.Query(sql, textValues, integerValues)
    End Function

    Private Function FirstId(ByVal rows As List(Of Dictionary(Of String, String))) As String
        If rows.Count = 0 Then Return "NONE"
        Return rows(0)("id")
    End Function

    Sub Main()
        Dim candidateSql As String = SqlCandidate.Text()
        Dim baselineSql As String = SqlBaseline.Text()
        Seed()
        Try
            tenants = New List(Of StorefrontSeoTenantIdentity) From {
                Host(1, "https://shop-one.example.invalid/", "https://www.shop-one.example.invalid/"),
                Host(2, "https://shop-two.example.invalid/", "")
            }

            ' --- Risoluzione dell'azienda dall'host (metodo reale + selezione tenant reale) ---
            Check("host canonico vetrina 1 -> azienda 1", ResolveCompany("shop-one.example.invalid", tenants, False) = 1)
            Check("alias vetrina 1 -> azienda 1", ResolveCompany("www.shop-one.example.invalid", tenants, False) = 1)
            Check("host vetrina 2 -> azienda 2", ResolveCompany("shop-two.example.invalid", tenants, False) = 2)
            Check("host maiuscolo normalizzato -> azienda 2", ResolveCompany("SHOP-TWO.EXAMPLE.INVALID", tenants, False) = 2)
            Check("host sconosciuto fail-closed", ResolveCompany("unknown.example.invalid", tenants, False) = 0)
            Check("host parziale fail-closed", ResolveCompany("shop-one.example.invalid.evil.invalid", tenants, False) = 0)
            Check("host vuoto fail-closed", ResolveCompany("", tenants, False) = 0)
            Check("loopback con due vetrine fail-closed", ResolveCompany("localhost", tenants, True) = 0)
            Dim ambiguous As New List(Of StorefrontSeoTenantIdentity) From {
                Host(1, "https://shared.example.invalid/", ""),
                Host(2, "https://shared.example.invalid/", "")
            }
            Check("host in comune a due aziende fail-closed", ResolveCompany("shared.example.invalid", ambiguous, False) = 0)
            Check("identita assente -> 0", TrackResolverFixture.ResolveTrackingCompanyId(Nothing) = 0)
            Check("azienda 0 -> 0", TrackResolverFixture.ResolveTrackingCompanyId(Host(0, "https://zero.example.invalid/", "")) = 0)
            Check("azienda negativa -> 0", TrackResolverFixture.ResolveTrackingCompanyId(Host(-3, "https://neg.example.invalid/", "")) = 0)

            ' --- Caso positivo e proiezione ---
            Dim rows As List(Of Dictionary(Of String, String)) = Lookup(candidateSql, 1, True, "alice@example.invalid", "1001")
            ' La query non ha LIMIT: la pagina legge la prima riga (id piu alto). Qui la vetrina 1 vede solo le proprie due righe.
            Check("positivo: vetrina 1 vede solo i propri ordini, il piu recente per primo", rows.Count = 2 AndAlso rows(0)("id") = "9006" AndAlso rows(1)("id") = "9001")
            Check("positivo: proiezione invariata", rows.Count >= 1 AndAlso rows(0)("NDocumento") = "1001" AndAlso rows(0)("StatiDescrizione1") = "S-C1-NEW" AndAlso rows(0)("Tracking") = "T9006" AndAlso rows(0)("Link_Tracking") = "https://carrier.invalid/t/{tracking}" AndAlso rows(0)("PagamentiTipoDescrizione") = "SYNTHETIC-PAY")
            Check("positivo: vetrina 2 trova solo il proprio ordine", FirstId(Lookup(candidateSql, 2, True, "alice@example.invalid", "1001")) = "9010")
            Check("email case-insensitive", FirstId(Lookup(candidateSql, 1, True, "ALICE@EXAMPLE.INVALID", "1001")) = "9006")
            Check("ordinamento id DESC invariato nella stessa azienda", FirstId(Lookup(candidateSql, 1, True, "alice@example.invalid", "1001")) = "9006")
            Check("solo documenti tipo 4", Lookup(candidateSql, 1, True, "alice@example.invalid", "4004").Count = 0)

            ' --- Isolamento tra aziende (candidato) ---
            Check("vetrina 2 non vede ordine di bob (azienda 1)", Lookup(candidateSql, 2, True, "bob@example.invalid", "2002").Count = 0)
            Check("vetrina 1 non vede ordine di carol (azienda 2)", Lookup(candidateSql, 1, True, "carol@example.invalid", "3003").Count = 0)
            Check("vetrina 1 non vede lo stesso numero dell'altra azienda", Not Lookup(candidateSql, 1, True, "alice@example.invalid", "1001").Exists(Function(r) r("id") = "9010"))
            Check("vetrina 2 vede solo il proprio ordine con lo stesso numero", Lookup(candidateSql, 2, True, "alice@example.invalid", "1001").Count = 1)
            Check("documento azienda 2 con utente azienda 1 negato da vetrina 1", Lookup(candidateSql, 1, True, "dave@example.invalid", "5005").Count = 0)
            Check("documento azienda 2 con utente azienda 1 negato da vetrina 2", Lookup(candidateSql, 2, True, "dave@example.invalid", "5005").Count = 0)
            Check("azienda 0 (bypass del guard) non legge nulla", Lookup(candidateSql, 0, True, "alice@example.invalid", "1001").Count = 0)
            Check("azienda inesistente non legge nulla", Lookup(candidateSql, 99, True, "alice@example.invalid", "1001").Count = 0)

            ' --- Input ostili: i parametri non cambiano la forma della query ---
            Check("email ostile non allarga", Lookup(candidateSql, 1, True, "x' OR '1'='1", "1001").Count = 0)
            Check("email con commento SQL non allarga", Lookup(candidateSql, 1, True, "alice@example.invalid' --", "1001").Count = 0)
            Check("numero ostile non allarga", Lookup(candidateSql, 1, True, "bob@example.invalid", "1001 OR 1=1").Count = 0)
            Check("email vuota non trova nulla", Lookup(candidateSql, 1, True, "", "1001").Count = 0)

            ' --- Baseline: il difetto era riproducibile a livello SQL ---
            Check("baseline: vetrina senza filtro azienda restituisce l'ordine altrui (alice/1001)", FirstId(Lookup(baselineSql, 0, False, "alice@example.invalid", "1001")) = "9010")
            Check("baseline: bob (azienda 1) letto senza vincolo azienda", FirstId(Lookup(baselineSql, 0, False, "bob@example.invalid", "2002")) = "9003")
            Check("baseline: carol (azienda 2) letta senza vincolo azienda", FirstId(Lookup(baselineSql, 0, False, "carol@example.invalid", "3003")) = "9004")
            Check("baseline: documento con utente di altra azienda visibile", FirstId(Lookup(baselineSql, 0, False, "dave@example.invalid", "5005")) = "9007")

            ' --- Composizione pagina: host -> azienda -> query, oppure nessuna lettura ---
            Dim companyForBob As Integer = ResolveCompany("shop-two.example.invalid", tenants, False)
            Check("composizione: bob su host vetrina 2 non trova ordini", companyForBob = 2 AndAlso Lookup(candidateSql, companyForBob, True, "bob@example.invalid", "2002").Count = 0)
            Dim companyForUnknown As Integer = ResolveCompany("unknown.example.invalid", tenants, False)
            Check("composizione: host sconosciuto non raggiunge la query", companyForUnknown <= 0)
            Dim companyForAlice As Integer = ResolveCompany("www.shop-one.example.invalid", tenants, False)
            Check("composizione: alias vetrina 1 trova l'ordine di alice", companyForAlice = 1 AndAlso FirstId(Lookup(candidateSql, companyForAlice, True, "alice@example.invalid", "1001")) = "9006")
        Finally
            database.Close()
        End Try

        Console.WriteLine("TRACK_ORDER_TENANT_TESTS=" & tests.ToString())
        Console.WriteLine("TRACK_ORDER_TENANT_FAILURES=" & failures.ToString())
        If failures > 0 Then Environment.Exit(1)
    End Sub
End Module
