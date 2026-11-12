Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Runtime.InteropServices
Imports System.Text
Imports MySql.Data.MySqlClient

' KS-C02-ADDRESS-OWNER-TENANT-BARRIER-1A.
' Esegue su SQLite di sistema in memoria (winsqlite3.dll):
'  1) le tre query di lettura REALI della pagina indirizzi, estratte meccanicamente (candidato e base);
'  2) i metodi di scrittura REALI (SetDefault/Save e helper) estratti meccanicamente, con connessione,
'     transazione e comando sostituiti da adattatori che usano gli stessi MySqlParameter nativi.
' Dati sintetici, nessun MySQL, IIS, rete o dato personale. SQLite non certifica MySQL ne i lock reali.
Public NotInheritable Class NativeSqlite
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
    <DllImport("winsqlite3.dll", CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function sqlite3_changes(ByVal db As IntPtr) As Integer
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

    Public Function Run(ByVal sql As String, ByVal values As Dictionary(Of String, Object), ByRef changes As Integer) As List(Of Dictionary(Of String, String))
        Dim rows As New List(Of Dictionary(Of String, String))()
        Dim statement As IntPtr = IntPtr.Zero
        Dim tail As IntPtr = IntPtr.Zero
        If sqlite3_prepare_v2(handle, Utf8Z(sql), -1, statement, tail) <> 0 Then Throw New InvalidOperationException("SQLITE_PREPARE_FAILED: " & sql)
        Try
            If values IsNot Nothing Then
                For Each pair As KeyValuePair(Of String, Object) In values
                    Dim index As Integer = sqlite3_bind_parameter_index(statement, Utf8Z(pair.Key))
                    If index <= 0 OrElse pair.Value Is Nothing OrElse pair.Value Is DBNull.Value Then Continue For
                    If TypeOf pair.Value Is Integer OrElse TypeOf pair.Value Is Long OrElse TypeOf pair.Value Is Boolean Then
                        sqlite3_bind_int64(statement, index, Convert.ToInt64(pair.Value))
                    Else
                        Dim bytes As Byte() = Encoding.UTF8.GetBytes(Convert.ToString(pair.Value))
                        sqlite3_bind_text(statement, index, bytes, bytes.Length, Transient)
                    End If
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
            changes = sqlite3_changes(handle)
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

Public NotInheritable Class StatementRecord
    Public Sql As String
    Public Locking As Boolean
    Public InTransaction As Boolean
End Class

Public NotInheritable Class AddressFixture
    Public Shared Database As NativeSqlite
    Public Shared Log As New List(Of StatementRecord)()
    Public Shared Commits As Integer
    Public Shared Rollbacks As Integer
    Public Shared ScopeAnswers As New Queue(Of Boolean)()
    Public Shared InTransaction As Boolean

    Public Shared Function ScopeCurrent() As Boolean
        If ScopeAnswers.Count > 0 Then Return ScopeAnswers.Dequeue()
        Return True
    End Function

    Public Shared Sub Reset()
        If Database IsNot Nothing Then Database.Close()
        Database = New NativeSqlite()
        Log.Clear()
        Commits = 0
        Rollbacks = 0
        InTransaction = False
        ScopeAnswers.Clear()
        Database.Execute("CREATE TABLE utenti(Id INTEGER PRIMARY KEY, AziendeId INTEGER NOT NULL, Abilitato INTEGER, Email TEXT, RagioneSociale TEXT, CognomeNome TEXT, Indirizzo TEXT, Cap TEXT, Citta TEXT, Provincia TEXT, Nazione TEXT, Telefono TEXT, Cellulare TEXT);" &
                         "CREATE TABLE login(id INTEGER PRIMARY KEY, UtentiId INTEGER, Abilitato INTEGER);" &
                         "CREATE TABLE utentiindirizzi(Id INTEGER PRIMARY KEY AUTOINCREMENT, UtenteId INTEGER, RagioneSocialeA TEXT, NomeA TEXT, IndirizzoA TEXT, CapA TEXT, CittaA TEXT, ProvinciaA TEXT, Zona TEXT, TelefonoA TEXT, CellulareA TEXT, FaxA TEXT, Note TEXT, NazioneA TEXT, Predefinito INTEGER);")
        ' Aziende 1 e 2 nello stesso database. 703: utente disabilitato; 704: login disabilitato; 706: senza indirizzi.
        Database.Execute("INSERT INTO utenti VALUES(701,1,1,'u701@example.invalid','RS-701','CN-701','VIA-701','00100','CITTA-701','RM','IT','T701','C701');" &
                         "INSERT INTO utenti VALUES(702,2,1,'u702@example.invalid','RS-702','CN-702','VIA-702','00200','CITTA-702','MI','IT','T702','C702');" &
                         "INSERT INTO utenti VALUES(703,1,0,'u703@example.invalid','RS-703','CN-703','VIA-703','00300','CITTA-703','NA','IT','T703','C703');" &
                         "INSERT INTO utenti VALUES(704,1,1,'u704@example.invalid','RS-704','CN-704','VIA-704','00400','CITTA-704','TO','IT','T704','C704');" &
                         "INSERT INTO utenti VALUES(706,1,1,'u706@example.invalid','RS-706','CN-706','VIA-706','00600','CITTA-706','BA','IT','T706','C706');")
        Database.Execute("INSERT INTO login VALUES(101,701,1);INSERT INTO login VALUES(202,702,1);INSERT INTO login VALUES(303,703,1);" &
                         "INSERT INTO login VALUES(404,704,0);INSERT INTO login VALUES(505,701,1);INSERT INTO login VALUES(606,706,1);")
        Database.Execute("INSERT INTO utentiindirizzi VALUES(1001,701,'RSA-1001','N1','IND-1001','00101','C1001','RM','Z1','T1','C1','F1','NOTE1','IT',0);" &
                         "INSERT INTO utentiindirizzi VALUES(1002,701,'RSA-1002','N2','IND-1002','00102','C1002','RM','Z2','T2','C2','F2','NOTE2','IT',1);" &
                         "INSERT INTO utentiindirizzi VALUES(1003,701,'RSA-1003','N3','IND-1003','00103','C1003','RM','Z3','T3','C3','F3','NOTE3','IT',0);" &
                         "INSERT INTO utentiindirizzi VALUES(2001,702,'RSA-2001','N4','IND-2001','00201','C2001','MI','Z4','T4','C4','F4','NOTE4','IT',1);" &
                         "INSERT INTO utentiindirizzi VALUES(3001,703,'RSA-3001','N5','IND-3001','00301','C3001','NA','Z5','T5','C5','F5','NOTE5','IT',1);" &
                         "INSERT INTO utentiindirizzi VALUES(4001,704,'RSA-4001','N6','IND-4001','00401','C4001','TO','Z6','T6','C6','F6','NOTE6','IT',1);")
    End Sub

    Public Shared Function Snapshot() As String
        Dim changes As Integer = 0
        Dim rows As List(Of Dictionary(Of String, String)) = Database.Run("SELECT Id, UtenteId, RagioneSocialeA, IndirizzoA, CittaA, Predefinito FROM utentiindirizzi ORDER BY Id", Nothing, changes)
        Dim text As New StringBuilder()
        For Each row As Dictionary(Of String, String) In rows
            text.Append(row("Id")).Append("|").Append(row("UtenteId")).Append("|").Append(row("RagioneSocialeA")).Append("|").Append(row("IndirizzoA")).Append("|").Append(row("CittaA")).Append("|").Append(row("Predefinito")).Append(";")
        Next
        Return text.ToString()
    End Function
End Class

Public NotInheritable Class FixtureConnection
    Implements IDisposable
    Public Sub New(ByVal connectionString As String)
    End Sub
    Public Sub Open()
    End Sub
    Public Function BeginTransaction() As FixtureTransaction
        AddressFixture.Database.Execute("BEGIN")
        AddressFixture.InTransaction = True
        Return New FixtureTransaction()
    End Function
    Public Sub Dispose() Implements IDisposable.Dispose
    End Sub
End Class

Public NotInheritable Class FixtureTransaction
    Implements IDisposable
    Private finished As Boolean
    Public Sub Commit()
        If finished Then Throw New InvalidOperationException("TRANSACTION_ALREADY_FINISHED")
        AddressFixture.Database.Execute("COMMIT")
        AddressFixture.Commits += 1
        AddressFixture.InTransaction = False
        finished = True
    End Sub
    Public Sub Rollback()
        If finished Then Return
        AddressFixture.Database.Execute("ROLLBACK")
        AddressFixture.Rollbacks += 1
        AddressFixture.InTransaction = False
        finished = True
    End Sub
    Public Sub Dispose() Implements IDisposable.Dispose
        Rollback()
    End Sub
End Class

Public NotInheritable Class FixtureCommand
    Implements IDisposable
    Private ReadOnly native As MySqlCommand
    Private ReadOnly transaction As FixtureTransaction

    Public Sub New(ByVal sql As String, ByVal connection As FixtureConnection)
        native = New MySqlCommand(sql)
    End Sub
    Public Sub New(ByVal sql As String, ByVal connection As FixtureConnection, ByVal transaction As FixtureTransaction)
        native = New MySqlCommand(sql)
        Me.transaction = transaction
    End Sub

    Public ReadOnly Property Parameters As MySqlParameterCollection
        Get
            Return native.Parameters
        End Get
    End Property

    Private Function Execute(ByRef changes As Integer) As List(Of Dictionary(Of String, String))
        Dim sql As String = native.CommandText
        Dim locking As Boolean = sql.TrimEnd().EndsWith(" FOR UPDATE", StringComparison.Ordinal)
        ' FOR UPDATE e solo registrato: SQLite non ha lock di riga ne modalita equivalente.
        If locking Then sql = sql.TrimEnd().Substring(0, sql.TrimEnd().Length - " FOR UPDATE".Length)
        Dim values As New Dictionary(Of String, Object)(StringComparer.Ordinal)
        For Each parameter As MySqlParameter In native.Parameters
            Dim key As String = parameter.ParameterName
            If Not key.StartsWith("@", StringComparison.Ordinal) Then key = "@" & key.TrimStart("?"c)
            values(key) = parameter.Value
        Next
        AddressFixture.Log.Add(New StatementRecord() With {.Sql = native.CommandText, .Locking = locking, .InTransaction = AddressFixture.InTransaction})
        Return AddressFixture.Database.Run(sql, values, changes)
    End Function

    Public Function ExecuteScalar() As Object
        Dim changes As Integer = 0
        Dim rows As List(Of Dictionary(Of String, String)) = Execute(changes)
        If rows.Count = 0 Then Return Nothing
        For Each value As String In rows(0).Values
            If value Is Nothing Then Return DBNull.Value
            Return value
        Next
        Return Nothing
    End Function

    Public Function ExecuteNonQuery() As Integer
        Dim changes As Integer = 0
        Execute(changes)
        Return changes
    End Function

    Public Sub Dispose() Implements IDisposable.Dispose
        native.Dispose()
    End Sub
End Class

Public NotInheritable Class FakeText
    Public Text As String = ""
End Class

Public NotInheritable Class FakeCheck
    Public Checked As Boolean
End Class

Module AddressOwnerTenantBarrierHarness
    Private tests As Integer
    Private failures As Integer

    Private Sub Check(ByVal name As String, ByVal condition As Boolean)
        tests += 1
        If condition Then Return
        failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Private Function Ids(ByVal rows As List(Of Dictionary(Of String, String))) As String
        Dim parts As New List(Of String)()
        For Each row As Dictionary(Of String, String) In rows
            parts.Add(row("Id"))
        Next
        Return String.Join(",", parts.ToArray())
    End Function

    Private Function Scoped(ByVal user As Integer, ByVal login As Integer, ByVal company As Integer, Optional ByVal id As Integer = 0) As Dictionary(Of String, Object)
        Dim values As New Dictionary(Of String, Object)(StringComparer.Ordinal) From {{"@UtentiId", user}, {"@LoginId", login}, {"@AziendaId", company}}
        If id > 0 Then values("@Id") = id
        Return values
    End Function

    Private Function Query(ByVal sql As String, ByVal values As Dictionary(Of String, Object)) As List(Of Dictionary(Of String, String))
        Dim changes As Integer = 0
        Return AddressFixture.Database.Run(sql, values, changes)
    End Function

    Private Function NewScope(ByVal user As Integer, ByVal login As Integer, ByVal company As Integer) As AddressWriteFixture.AccountAddressScope
        Return New AddressWriteFixture.AccountAddressScope() With {.UserId = user, .LoginId = login, .CompanyId = company, .Marker = "SYNTHETIC-" & user.ToString() & "-" & login.ToString() & "-" & company.ToString()}
    End Function

    Private Function NewPage() As AddressWriteFixture
        Dim page As New AddressWriteFixture()
        page.tbIndirizzoA.Text = "  NUOVA-VIA  "
        page.tbCittaA.Text = "NUOVA-CITTA"
        page.tbCapA.Text = "99999"
        page.tbNazioneA.Text = "IT"
        Return page
    End Function

    Sub Main()
        Dim mainSql As String = ReadSqlCandidate.MainAddress()
        Dim altSql As String = ReadSqlCandidate.AlternativeList()
        Dim byIdSql As String = ReadSqlCandidate.AlternativeById()

        ' ---------- Letture del candidato ----------
        AddressFixture.Reset()
        Check("lettura lista: tupla valida -> solo propri indirizzi, predefinito per primo", Ids(Query(altSql, Scoped(701, 101, 1))) = "1002,1001,1003")
        Check("lettura lista: stessa tupla con secondo login dello stesso utente", Ids(Query(altSql, Scoped(701, 505, 1))) = "1002,1001,1003")
        Check("lettura lista: azienda diversa -> nessuna riga", Query(altSql, Scoped(701, 101, 2)).Count = 0)
        Check("lettura lista: login di un altro utente -> nessuna riga", Query(altSql, Scoped(701, 202, 1)).Count = 0)
        Check("lettura lista: login inesistente -> nessuna riga", Query(altSql, Scoped(701, 999, 1)).Count = 0)
        Check("lettura lista: utente disabilitato -> nessuna riga", Query(altSql, Scoped(703, 303, 1)).Count = 0)
        Check("lettura lista: login disabilitato -> nessuna riga", Query(altSql, Scoped(704, 404, 1)).Count = 0)
        Check("lettura lista: utente dell'azienda 2 solo nella sua vetrina", Ids(Query(altSql, Scoped(702, 202, 2))) = "2001" AndAlso Query(altSql, Scoped(702, 202, 1)).Count = 0)
        Check("lettura lista: colonne e valori invariati", Query(altSql, Scoped(701, 101, 1))(0)("RagioneSocialeA") = "RSA-1002" AndAlso Query(altSql, Scoped(701, 101, 1))(0)("Predefinito") = "1" AndAlso Query(altSql, Scoped(701, 101, 1))(0)("NazioneA") = "IT")
        Check("lettura per id: indirizzo proprio", Ids(Query(byIdSql, Scoped(701, 101, 1, 1001))) = "1001")
        Check("lettura per id: indirizzo di un altro utente -> nessuna riga", Query(byIdSql, Scoped(701, 101, 1, 2001)).Count = 0)
        Check("lettura per id: indirizzo dell'altra azienda con login proprio -> nessuna riga", Query(byIdSql, Scoped(702, 101, 1, 2001)).Count = 0)
        Check("lettura per id: azienda sbagliata -> nessuna riga", Query(byIdSql, Scoped(701, 101, 2, 1001)).Count = 0)
        Check("lettura per id: utente disabilitato -> nessuna riga", Query(byIdSql, Scoped(703, 303, 1, 3001)).Count = 0)
        Check("lettura per id: login di un altro utente -> nessuna riga", Query(byIdSql, Scoped(701, 202, 1, 1001)).Count = 0)
        Check("lettura per id: login inesistente -> nessuna riga", Query(byIdSql, Scoped(701, 999, 1, 1001)).Count = 0)
        Check("lettura per id: login disabilitato -> nessuna riga", Query(byIdSql, Scoped(704, 404, 1, 4001)).Count = 0)
        Check("lettura per id: secondo login dello stesso utente", Ids(Query(byIdSql, Scoped(701, 505, 1, 1001))) = "1001")
        Check("lettura principale: tupla valida", Query(mainSql, Scoped(701, 101, 1)).Count = 1 AndAlso Query(mainSql, Scoped(701, 101, 1))(0)("CognomeNome") = "CN-701" AndAlso Query(mainSql, Scoped(701, 101, 1))(0)("Email") = "u701@example.invalid")
        Check("lettura principale: azienda diversa -> nessuna riga", Query(mainSql, Scoped(701, 101, 2)).Count = 0)
        Check("lettura principale: login altrui -> nessuna riga", Query(mainSql, Scoped(701, 202, 1)).Count = 0)
        Check("lettura principale: utente disabilitato -> nessuna riga", Query(mainSql, Scoped(703, 303, 1)).Count = 0)
        Check("lettura principale: login disabilitato -> nessuna riga", Query(mainSql, Scoped(704, 404, 1)).Count = 0)
        Check("lettura principale: un solo risultato anche con due login", Query(mainSql, Scoped(701, 505, 1)).Count = 1)

        ' ---------- Difetto della base (letture chiavate solo dal proprietario) ----------
        Dim baseMain As String = ReadSqlBaseline.MainAddress()
        Dim baseAlt As String = ReadSqlBaseline.AlternativeList()
        Dim baseById As String = ReadSqlBaseline.AlternativeById()
        Dim ownerOnly As New Dictionary(Of String, Object)(StringComparer.Ordinal) From {{"@UtentiId", 702}}
        Check("base: lista servita a un proprietario senza vincolo di azienda o login", Ids(Query(baseAlt, ownerOnly)) = "2001")
        Check("base: indirizzo servito per solo proprietario e id", Ids(Query(baseById, New Dictionary(Of String, Object)(StringComparer.Ordinal) From {{"@UtentiId", 702}, {"@Id", 2001}})) = "2001")
        Check("base: principale servito per solo proprietario", Query(baseMain, ownerOnly).Count = 1)
        Check("base: utente disabilitato ancora servito", Ids(Query(baseAlt, New Dictionary(Of String, Object)(StringComparer.Ordinal) From {{"@UtentiId", 703}})) = "3001")

        ' ---------- Scritture del candidato: SetDefaultAlternativeAddress ----------
        AddressFixture.Reset()
        Dim before As String = AddressFixture.Snapshot()
        Dim page As AddressWriteFixture = NewPage()
        Check("set default valido", page.SetDefaultAlternativeAddress(NewScope(701, 101, 1), 1001))
        Check("set default: solo l'indirizzo scelto resta predefinito e gli altri utenti non cambiano", Query("SELECT Id FROM utentiindirizzi WHERE Predefinito = 1 ORDER BY Id", Nothing).Count = 4 AndAlso Ids(Query("SELECT Id FROM utentiindirizzi WHERE UtenteId = 701 AND Predefinito = 1", Nothing)) = "1001" AndAlso Ids(Query("SELECT Id FROM utentiindirizzi WHERE UtenteId = 702 AND Predefinito = 1", Nothing)) = "2001")
        Check("set default: prima istruzione = guardia con lock dentro la transazione", AddressFixture.Log.Count >= 1 AndAlso AddressFixture.Log(0).Locking AndAlso AddressFixture.Log(0).InTransaction AndAlso AddressFixture.Log(0).Sql.Contains("FROM login l INNER JOIN utenti u"))
        Check("set default: una sola commit, nessun rollback", AddressFixture.Commits = 1 AndAlso AddressFixture.Rollbacks = 0)

        AddressFixture.Reset()
        before = AddressFixture.Snapshot()
        Check("set default su indirizzo altrui rifiutato", Not NewPage().SetDefaultAlternativeAddress(NewScope(701, 101, 1), 2001))
        Check("set default altrui: nessuna modifica e rollback", AddressFixture.Snapshot() = before AndAlso AddressFixture.Commits = 0 AndAlso AddressFixture.Rollbacks = 1)

        Dim denied As New List(Of Integer()) From {
            New Integer() {701, 101, 2}, New Integer() {701, 202, 1}, New Integer() {703, 303, 1}, New Integer() {704, 404, 1}, New Integer() {701, 999, 1}, New Integer() {702, 101, 1}
        }
        For Each tuple As Integer() In denied
            AddressFixture.Reset()
            before = AddressFixture.Snapshot()
            Dim name As String = tuple(0).ToString() & "/" & tuple(1).ToString() & "/" & tuple(2).ToString()
            Check("set default negato " & name & ": rifiutato", Not NewPage().SetDefaultAlternativeAddress(NewScope(tuple(0), tuple(1), tuple(2)), 1001))
            Check("set default negato " & name & ": solo la guardia eseguita, nessuna modifica, rollback", AddressFixture.Log.Count = 1 AndAlso AddressFixture.Snapshot() = before AndAlso AddressFixture.Commits = 0 AndAlso AddressFixture.Rollbacks = 1)
        Next

        AddressFixture.Reset()
        before = AddressFixture.Snapshot()
        AddressFixture.ScopeAnswers.Enqueue(True)
        AddressFixture.ScopeAnswers.Enqueue(False)
        Check("set default: scope cambiato prima del commit -> rifiutato", Not NewPage().SetDefaultAlternativeAddress(NewScope(701, 101, 1), 1001))
        Check("set default: scope cambiato -> tutto annullato", AddressFixture.Snapshot() = before AndAlso AddressFixture.Commits = 0 AndAlso AddressFixture.Rollbacks = 1)

        AddressFixture.Reset()
        before = AddressFixture.Snapshot()
        AddressFixture.ScopeAnswers.Enqueue(False)
        Check("set default: scope non piu valido all'ingresso -> nessun SQL", Not NewPage().SetDefaultAlternativeAddress(NewScope(701, 101, 1), 1001) AndAlso AddressFixture.Log.Count = 0 AndAlso AddressFixture.Snapshot() = before)

        ' ---------- Scritture del candidato: SaveAlternativeAddress ----------
        AddressFixture.Reset()
        page = NewPage()
        Check("salvataggio nuovo indirizzo valido", page.SaveAlternativeAddress(NewScope(701, 101, 1), 0))
        Check("nuovo indirizzo: inserita una riga per il proprietario, predefiniti invariati", Query("SELECT Id FROM utentiindirizzi WHERE UtenteId = 701", Nothing).Count = 4 AndAlso Ids(Query("SELECT Id FROM utentiindirizzi WHERE UtenteId = 701 AND Predefinito = 1", Nothing)) = "1002")
        Check("nuovo indirizzo: testo ripulito e prima istruzione = guardia con lock", Query("SELECT IndirizzoA FROM utentiindirizzi WHERE UtenteId = 701 AND Id > 4001", Nothing)(0)("IndirizzoA") = "NUOVA-VIA" AndAlso AddressFixture.Log(0).Locking AndAlso AddressFixture.Log(0).InTransaction AndAlso AddressFixture.Commits = 1)

        AddressFixture.Reset()
        Check("primo indirizzo di un utente senza indirizzi -> predefinito", NewPage().SaveAlternativeAddress(NewScope(706, 606, 1), 0) AndAlso Query("SELECT Predefinito FROM utentiindirizzi WHERE UtenteId = 706", Nothing)(0)("Predefinito") = "1")

        AddressFixture.Reset()
        page = NewPage()
        page.chkSetDefault.Checked = True
        Check("modifica del proprio indirizzo con predefinito", page.SaveAlternativeAddress(NewScope(701, 101, 1), 1001))
        Check("modifica: 1001 predefinito, altri indirizzi del proprietario no, altri utenti invariati", Ids(Query("SELECT Id FROM utentiindirizzi WHERE UtenteId = 701 AND Predefinito = 1", Nothing)) = "1001" AndAlso Ids(Query("SELECT Id FROM utentiindirizzi WHERE UtenteId = 702 AND Predefinito = 1", Nothing)) = "2001" AndAlso Query("SELECT IndirizzoA FROM utentiindirizzi WHERE Id = 1001", Nothing)(0)("IndirizzoA") = "NUOVA-VIA")

        AddressFixture.Reset()
        before = AddressFixture.Snapshot()
        Check("modifica di un indirizzo altrui rifiutata", Not NewPage().SaveAlternativeAddress(NewScope(701, 101, 1), 2001))
        Check("modifica altrui: nessuna modifica e rollback", AddressFixture.Snapshot() = before AndAlso AddressFixture.Commits = 0 AndAlso AddressFixture.Rollbacks = 1)

        For Each tuple As Integer() In denied
            AddressFixture.Reset()
            before = AddressFixture.Snapshot()
            Dim name As String = tuple(0).ToString() & "/" & tuple(1).ToString() & "/" & tuple(2).ToString()
            Check("salvataggio negato " & name & ": rifiutato", Not NewPage().SaveAlternativeAddress(NewScope(tuple(0), tuple(1), tuple(2)), 0))
            Check("salvataggio negato " & name & ": solo la guardia, nessuna riga inserita, rollback", AddressFixture.Log.Count = 1 AndAlso AddressFixture.Snapshot() = before AndAlso AddressFixture.Commits = 0 AndAlso AddressFixture.Rollbacks = 1)
        Next

        AddressFixture.Reset()
        before = AddressFixture.Snapshot()
        AddressFixture.ScopeAnswers.Enqueue(True)
        AddressFixture.ScopeAnswers.Enqueue(False)
        Check("salvataggio: scope cambiato prima del commit -> rifiutato e annullato", Not NewPage().SaveAlternativeAddress(NewScope(701, 101, 1), 0) AndAlso AddressFixture.Snapshot() = before AndAlso AddressFixture.Commits = 0 AndAlso AddressFixture.Rollbacks = 1)

        AddressFixture.Reset()
        before = AddressFixture.Snapshot()
        AddressFixture.Database.Execute("CREATE TRIGGER synthetic_fail BEFORE UPDATE OF IndirizzoA ON utentiindirizzi WHEN NEW.Id = 1001 BEGIN SELECT RAISE(ABORT, 'SYNTHETIC-UPDATE-FAILURE'); END;")
        page = NewPage()
        page.chkSetDefault.Checked = True
        Check("errore dopo il reset del predefinito -> rifiutato", Not page.SaveAlternativeAddress(NewScope(701, 101, 1), 1001))
        Check("errore dopo il reset: predefiniti e dati ripristinati dal rollback", AddressFixture.Snapshot() = before AndAlso AddressFixture.Commits = 0 AndAlso AddressFixture.Rollbacks >= 1)

        AddressFixture.Database.Close()
        Console.WriteLine("ADDRESS_OWNER_TESTS=" & tests.ToString())
        Console.WriteLine("ADDRESS_OWNER_FAILURES=" & failures.ToString())
        If failures > 0 Then Environment.Exit(1)
    End Sub
End Module
