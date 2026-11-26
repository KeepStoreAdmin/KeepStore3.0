Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Text
Imports MySql.Data.MySqlClient

' EXPORT-FEED-GESTIONALE-1A. Riproduce, con il connettore .NET reale e sul database LAB, il modo in cui il gestionale (repository KeepStoreRepo, letto in sola lettura)
' salva i dati: AggiungiDati (HelpMe.vb) copia le colonne di "Select * from <tabella> where id=-1" dalla seconda all'ultima per POSIZIONE e mette l'Id nell'ultimo posto;
' ExecStoreTrnNoCommit (MSql.vb) costruisce i parametri dalle righe REALI di sysparametristored (ORDER BY nomestore, id), IN con il valore, il resto OUT; per le routine
' Mod* un risultato di 0 righe e un errore. Qui le stesse regole sono riscritte e chiamate sulle routine della migrazione EXPORT-FEED-DB-2A.
' Esce con 1 se un caso fallisce. La connessione arriva dall'ambiente del processo (KS_LAB_USER, KS_LAB_PWD, KS_LAB_SCHEMA): nessun segreto e scritto qui.
Public Module ExportFeedGestionaleHarness
    Private failures As Integer = 0
    Private cs As String = ""
    Private registry As DataTable
    Private ReadOnly Prefix As String = "KSGESTHARNESS"

    Private Sub Check(ByVal ok As Boolean, ByVal name As String)
        If ok Then
            Console.WriteLine("ok " & name)
        Else
            failures += 1
            Console.WriteLine("FAIL " & name)
        End If
    End Sub

    Private Function Conn() As MySqlConnection
        Dim c As New MySqlConnection(cs)
        c.Open()
        Return c
    End Function

    Private Function Table(ByVal c As MySqlConnection, ByVal sql As String) As DataTable
        Dim dt As New DataTable()
        Using cmd As New MySqlCommand(sql, c)
            Using da As New MySqlDataAdapter(cmd)
                da.Fill(dt)
            End Using
        End Using
        Return dt
    End Function

    Private Function Scalar(ByVal c As MySqlConnection, ByVal sql As String) As String
        Using cmd As New MySqlCommand(sql, c)
            Dim v As Object = cmd.ExecuteScalar()
            If v Is Nothing OrElse v Is DBNull.Value Then Return "NULL"
            Return Convert.ToString(v)
        End Using
    End Function

    Private Sub Exec(ByVal c As MySqlConnection, ByVal sql As String)
        Using cmd As New MySqlCommand(sql, c)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    ' Come CheckParametri del gestionale: una sola lettura, ORDER BY nomestore, id.
    Private Sub LoadRegistry(ByVal c As MySqlConnection)
        registry = Table(c, "SELECT nomestore, nomeparametro, tipo, lunghezza, direzione FROM sysparametristored ORDER BY nomestore, id")
    End Sub

    ' RecuperaParametri: DataTable.Select senza ordinamento: restano nell'ordine di caricamento (e DataTable non distingue le maiuscole).
    Private Function ParamsOf(ByVal store As String) As List(Of DataRow)
        Dim res As New List(Of DataRow)()
        For Each r As DataRow In registry.Select("nomestore='" & store.Replace("'", "''") & "'")
            res.Add(r)
        Next
        Return res
    End Function

    ' ExecStoreTrnNoCommit + ConfiguraParametriStored: valori per posizione, direzione IN o OUT.
    Private lastRows As Integer = 0
    Private Function ExecStore(ByVal c As MySqlConnection, ByVal t As MySqlTransaction, ByVal store As String, ByVal valori() As Object, ByRef lastError As String) As Boolean
        lastError = ""
        Dim pars As List(Of DataRow) = ParamsOf(store)
        If pars.Count = 0 Then
            lastError = "nessun parametro registrato"
            Return False
        End If
        Try
            Using cmd As New MySqlCommand(store, c, t)
                cmd.CommandType = CommandType.StoredProcedure
                Dim lastIdx As Integer = -1
                Dim i As Integer = 0
                For Each p As DataRow In pars
                    lastIdx += 1
                    Dim nome As String = Convert.ToString(p("nomeparametro"))
                    If Convert.ToString(p("direzione")).ToUpperInvariant() = "IN" Then
                        cmd.Parameters.AddWithValue(nome, valori(i))
                        cmd.Parameters(nome).Direction = ParameterDirection.Input
                    Else
                        cmd.Parameters.AddWithValue(nome, DBNull.Value)
                        cmd.Parameters(nome).Direction = ParameterDirection.Output
                    End If
                    i += 1
                Next
                lastRows = cmd.ExecuteNonQuery()
                Try
                    valori(lastIdx) = cmd.Parameters(lastIdx).Value
                Catch
                    valori(lastIdx) = -1
                End Try
                If lastRows = 0 AndAlso store.StartsWith("Mod", StringComparison.Ordinal) Then Return False
                Return True
            End Using
        Catch ex As MySqlException
            lastError = ex.Message
            Return False
        End Try
    End Function

    ' AggiungiDati(NomeStore, rw, transaction:=True, notnull:=False)
    Private Function AggiungiDati(ByVal c As MySqlConnection, ByVal t As MySqlTransaction, ByVal store As String, ByVal rw As DataRow, ByRef valorePar() As Object, ByRef lastError As String) As Boolean
        Dim i As Integer
        ReDim valorePar(rw.Table.Columns.Count)
        For i = 1 To rw.Table.Columns.Count - 1
            valorePar(i - 1) = rw(i)
        Next
        Try
            valorePar(i - 1) = rw("Id").ToString()
        Catch
        End Try
        Return ExecStore(c, t, store, valorePar, lastError)
    End Function

    Private Function NewExportRow(ByVal c As MySqlConnection, ByVal descr As String) As DataRow
        Dim dt As DataTable = Table(c, "Select * from export where id=-1")
        Dim rw As DataRow = dt.NewRow()
        rw("Descrizione") = descr
        rw("Password") = "x"
        rw("FormatString") = "#Codice#|#Prezzo#"
        rw("NListino") = 10
        rw("IvaTipo") = 2
        rw("Giacenza") = 0.0R
        rw("SpeseSpedizione") = 0.0R
        rw("GiorniSpedizione") = 1
        rw("Azienda") = "www.example.test"
        rw("Tipo") = "txt"
        rw("IdVettore") = 0
        rw("NListino2") = 0
        rw("Tutto_in_minuscolo") = 0
        rw("Google") = 0
        rw("Amazon") = 0
        rw("NoVettoreSuGratis") = 0
        rw("Abilitato") = 1
        Return rw
    End Function

    ' Salvataggio del gestionale VECCHIO (SalvaDati): NewExport / ModExport; l'id nuovo si legge in UBound-1.
    Private Function OldSave(ByVal c As MySqlConnection, ByVal t As MySqlTransaction, ByVal descr As String, ByVal modId As Integer, ByRef idExport As Integer, ByRef err As String) As Boolean
        Dim rw As DataRow = NewExportRow(c, descr)
        Dim store As String = "NewExport"
        If modId > 0 Then
            store = "ModExport"
            rw("id") = modId
        End If
        Dim vp() As Object = Nothing
        Dim ok As Boolean = AggiungiDati(c, t, store, rw, vp, err)
        If ok Then
            If modId > 0 Then
                idExport = modId
            Else
                Dim raw As String = Convert.ToString(vp(UBound(vp) - 1))
                If Not Integer.TryParse(raw, idExport) Then
                    err = "id letto in UBound-1 non valido: [" & raw & "]"
                    Return False
                End If
            End If
        End If
        Return ok
    End Function

    Private Sub Cleanup(ByVal c As MySqlConnection)
        Try
            Exec(c, "DELETE FROM export_filtri WHERE ExportId IN (SELECT ID FROM export WHERE Descrizione LIKE '" & Prefix & "%')")
            Exec(c, "DELETE FROM `export` WHERE Descrizione LIKE '" & Prefix & "%'")
        Catch ex As Exception
            Console.WriteLine("HARNESS_CLEANUP_ERROR " & ex.GetType().Name)
        End Try
    End Sub

    Private Function Ids(ByVal c As MySqlConnection, ByVal descr As String) As Integer
        Return Convert.ToInt32(Scalar(c, "SELECT ID FROM `export` WHERE Descrizione = '" & descr & "'"))
    End Function

    Public Function Main() As Integer
        Dim csb As New MySqlConnectionStringBuilder()
        csb.Server = "127.0.0.1"
        csb.Port = 13317UI
        csb.Database = Environment.GetEnvironmentVariable("KS_LAB_SCHEMA")
        csb.UserID = Environment.GetEnvironmentVariable("KS_LAB_USER")
        csb("Password") = Environment.GetEnvironmentVariable("KS_LAB_PWD")
        csb.SslMode = MySqlSslMode.Required
        csb.TlsVersion = "Tls12"
        csb.ConnectionTimeout = 8UI
        csb.DefaultCommandTimeout = 60UI
        cs = csb.ConnectionString
        Using c As MySqlConnection = Conn()
            Try
                Cleanup(c)
                RunAll(c)
            Catch ex As Exception
                failures += 1
                Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & " " & ex.Message.Replace(Environment.GetEnvironmentVariable("KS_LAB_PWD"), "<hidden>"))
            Finally
                Cleanup(c)
            End Try
        End Using
        Console.WriteLine("failures=" & failures.ToString())
        Return If(failures = 0, 0, 1)
    End Function

    Private Sub RunAll(ByVal c As MySqlConnection)
        LoadRegistry(c)
        Dim err As String = ""
        Dim optHeader As DataTable = Table(c, "Select * from export_opzioni where id=-1")
        Dim colHeader As DataTable = Table(c, "Select * from export_colonne where id=-1")
        Dim exportCols As Integer = Table(c, "Select * from export where id=-1").Columns.Count

        ' --- contratto: la forma delle tabelle e le routine registrate ---
        Check(exportCols = 18, "export ha ancora 18 colonne (il gestionale attuale non vede differenze)")
        Check(optHeader.Columns(0).ColumnName = "Id" AndAlso optHeader.Columns(1).ColumnName = "ExportId" AndAlso optHeader.Columns(2).ColumnName = "TokenAccesso", "export_opzioni: Id, ExportId, TokenAccesso in testa")
        Check(ParamsOf("Newexport_opzioni").Count = optHeader.Columns.Count - 1 + 1, "Newexport_opzioni: (colonne - 1) IN piu l'OUT")
        Check(ParamsOf("Newexport_colonne").Count = colHeader.Columns.Count - 1 + 1, "Newexport_colonne: (colonne - 1) IN piu l'OUT")
        Dim lastOpt As DataRow = ParamsOf("Newexport_opzioni")(ParamsOf("Newexport_opzioni").Count - 1)
        Check(Convert.ToString(lastOpt("direzione")) = "OUT" AndAlso Convert.ToString(lastOpt("nomeparametro")) = "parRetVal", "Newexport_opzioni: l'OUT e ultimo")

        ' --- 1. gestionale VECCHIO: nuovo feed e modifica (nessuna regressione) ---
        Dim idA As Integer = 0
        Dim t As MySqlTransaction = c.BeginTransaction()
        Dim ok As Boolean = OldSave(c, t, Prefix & "A", 0, idA, err)
        Check(ok AndAlso idA > 0, "vecchio gestionale: NewExport salva e restituisce l'id in UBound-1 (" & err & ")")
        t.Commit()
        Check(Scalar(c, "SELECT COUNT(*) FROM `export` WHERE ID = " & idA & " AND Descrizione = '" & Prefix & "A'") = "1", "vecchio gestionale: la riga esiste")
        t = c.BeginTransaction()
        Dim idA2 As Integer = 0
        ok = OldSave(c, t, Prefix & "A2", idA, idA2, err)
        t.Commit()
        Check(ok AndAlso idA2 = idA AndAlso Scalar(c, "SELECT Descrizione FROM `export` WHERE ID = " & idA) = Prefix & "A2", "vecchio gestionale: ModExport modifica la riga (" & err & ")")
        Exec(c, "UPDATE `export` SET Descrizione = '" & Prefix & "A' WHERE ID = " & idA)
        Check(Scalar(c, "SELECT COUNT(*) FROM export_opzioni WHERE ExportId = " & idA) = "0", "feed creato dal vecchio gestionale: nessuna riga di opzioni (nasce dal gestionale nuovo)")

        ' --- 2. gestionale NUOVO: opzioni (la riga manca: la routine inserisce) ---
        Dim rw As DataRow = optHeader.NewRow()
        rw("ExportId") = idA
        rw("TokenAccesso") = ""
        rw("Separatore") = ";"
        rw("DelimitatoreTesto") = """"
        rw("Codifica") = "iso-8859-1"
        rw("SeparatoreDecimale") = ","
        rw("XmlElemento") = "articolo"
        rw("TogliHtml") = 0
        rw("MinutiCache") = 120
        rw("ParolaDisponibile") = "in_stock"
        rw("ParolaInArrivo") = "preorder"
        rw("ParolaNonDisponibile") = "out_of_stock"
        rw("SenzaImmagine") = 1
        rw("SenzaEan") = 1
        rw("PrezzoZero") = 0
        ' Intestazione e XmlRadice restano DBNull: devono valere i predefiniti (1 e 'prodotti').
        Dim vp() As Object = Nothing
        t = c.BeginTransaction()
        ok = AggiungiDati(c, t, "Newexport_opzioni", rw, vp, err)
        t.Commit()
        Dim optId As String = Scalar(c, "SELECT Id FROM export_opzioni WHERE ExportId = " & idA)
        Check(ok, "nuovo gestionale: Newexport_opzioni via AggiungiDati (" & err & ")")
        Check(optId <> "NULL" AndAlso optId <> idA.ToString() AndAlso Convert.ToString(vp(UBound(vp) - 1)) = optId, "Newexport_opzioni restituisce l'Id della riga (diverso da ExportId) in UBound-1")
        Dim o As DataRow = Table(c, "SELECT * FROM export_opzioni WHERE ExportId = " & idA).Rows(0)
        Check(Convert.ToString(o("Separatore")) = ";" AndAlso Convert.ToString(o("DelimitatoreTesto")) = """" AndAlso Convert.ToString(o("Codifica")) = "iso-8859-1" AndAlso Convert.ToString(o("SeparatoreDecimale")) = "," AndAlso Convert.ToString(o("XmlElemento")) = "articolo", "opzioni di testo scritte nella colonna giusta (nessuno scambio di parametri)")
        Check(Convert.ToInt32(o("TogliHtml")) = 0 AndAlso Convert.ToInt32(o("MinutiCache")) = 120 AndAlso Convert.ToInt32(o("SenzaImmagine")) = 1 AndAlso Convert.ToInt32(o("SenzaEan")) = 1 AndAlso Convert.ToInt32(o("PrezzoZero")) = 0, "opzioni numeriche scritte nella colonna giusta")
        Check(Convert.ToString(o("ParolaDisponibile")) = "in_stock" AndAlso Convert.ToString(o("ParolaInArrivo")) = "preorder" AndAlso Convert.ToString(o("ParolaNonDisponibile")) = "out_of_stock", "parole della disponibilita nella colonna giusta")
        Check(Convert.ToInt32(o("Intestazione")) = 1 AndAlso Convert.ToString(o("XmlRadice")) = "prodotti", "DBNull = predefinito della colonna (Intestazione 1, XmlRadice prodotti)")
        Dim token1 As String = Convert.ToString(o("TokenAccesso"))
        Check(token1.Length = 48 AndAlso System.Text.RegularExpressions.Regex.IsMatch(token1, "^[0-9A-F]{48}$"), "il codice del link e creato dal database (48 esadecimali), non quello passato")

        ' --- upsert: stessa riga, valori nuovi, codice invariato ---
        rw("Separatore") = "|"
        rw("MinutiCache") = 30
        t = c.BeginTransaction()
        ok = AggiungiDati(c, t, "Newexport_opzioni", rw, vp, err)
        t.Commit()
        Check(ok AndAlso Scalar(c, "SELECT COUNT(*) FROM export_opzioni WHERE ExportId = " & idA) = "1" AndAlso Scalar(c, "SELECT Id FROM export_opzioni WHERE ExportId = " & idA) = optId, "seconda chiamata: aggiorna la stessa riga (una sola riga per feed, stesso Id)")
        Check(Scalar(c, "SELECT Separatore FROM export_opzioni WHERE ExportId = " & idA) = "|" AndAlso Scalar(c, "SELECT MinutiCache FROM export_opzioni WHERE ExportId = " & idA) = "30", "seconda chiamata: i valori nuovi sono scritti")
        Check(Scalar(c, "SELECT TokenAccesso FROM export_opzioni WHERE ExportId = " & idA) = token1, "il codice del link NON cambia salvando le opzioni (nemmeno con il campo vuoto)")
        ' valori mancanti (DBNull) su una riga esistente tornano al predefinito: lo dichiara la consegna
        Dim rw2 As DataRow = optHeader.NewRow()
        rw2("ExportId") = idA
        t = c.BeginTransaction()
        ok = AggiungiDati(c, t, "Newexport_opzioni", rw2, vp, err)
        t.Commit()
        Check(ok AndAlso Scalar(c, "SELECT Separatore FROM export_opzioni WHERE ExportId = " & idA) = "|" AndAlso Scalar(c, "SELECT Codifica FROM export_opzioni WHERE ExportId = " & idA) = "utf-8", "riga di sole colonne vuote: tutte le opzioni tornano ai predefiniti")

        ' --- colonne del file ---
        Exec(c, "DELETE FROM export_colonne WHERE ExportId = " & idA)
        Dim colIds As New List(Of String)()
        t = c.BeginTransaction()
        For k As Integer = 1 To 3
            Dim cr As DataRow = colHeader.NewRow()
            cr("ExportId") = idA
            cr("Posizione") = k
            cr("TitoloColonna") = "t" & k.ToString()
            cr("Campo") = If(k = 3, "", "Codice")
            cr("Prefisso") = "p" & k.ToString()
            cr("Suffisso") = "s" & k.ToString()
            cr("ValoreFisso") = If(k = 3, "IT", "")
            If k <> 2 Then cr("MassimoCaratteri") = 10 * k
            cr("SeVuoto") = "v" & k.ToString()
            Dim vc() As Object = Nothing
            ok = AggiungiDati(c, t, "Newexport_colonne", cr, vc, err)
            If Not ok Then Exit For
            colIds.Add(Convert.ToString(vc(UBound(vc) - 1)))
        Next
        t.Commit()
        Check(ok AndAlso colIds.Count = 3, "Newexport_colonne x3 via AggiungiDati (" & err & ")")
        Dim colRows As DataTable = Table(c, "SELECT * FROM export_colonne WHERE ExportId = " & idA & " ORDER BY Posizione")
        Check(colRows.Rows.Count = 3 AndAlso Convert.ToString(colRows.Rows(0)("TitoloColonna")) = "t1" AndAlso Convert.ToString(colRows.Rows(2)("ValoreFisso")) = "IT" AndAlso Convert.ToString(colRows.Rows(0)("Prefisso")) = "p1" AndAlso Convert.ToString(colRows.Rows(0)("Suffisso")) = "s1", "colonne scritte nelle colonne giuste")
        Check(colRows.Rows(1)("MassimoCaratteri") Is DBNull.Value AndAlso Convert.ToInt32(colRows.Rows(2)("MassimoCaratteri")) = 30, "MassimoCaratteri DBNull resta NULL")
        Check(colIds(0) = Convert.ToString(colRows.Rows(0)("Id")) AndAlso colIds(2) = Convert.ToString(colRows.Rows(2)("Id")), "Newexport_colonne restituisce l'Id della riga (LAST_INSERT_ID)")

        ' --- nuovo codice ---
        Dim vcod() As Object = New Object() {idA, Nothing}
        t = c.BeginTransaction()
        ok = ExecStore(c, t, "Modexport_codice", vcod, err)
        t.Commit()
        Dim token2 As String = Scalar(c, "SELECT TokenAccesso FROM export_opzioni WHERE ExportId = " & idA)
        Check(ok AndAlso token2 <> token1 AndAlso System.Text.RegularExpressions.Regex.IsMatch(token2, "^[0-9A-F]{48}$"), "Modexport_codice: nuovo codice valido e diverso (righe " & lastRows.ToString() & ")")
        Dim idB As Integer = 0
        t = c.BeginTransaction()
        OldSave(c, t, Prefix & "B", 0, idB, err)
        t.Commit()
        Dim vcod2() As Object = New Object() {idB, Nothing}
        t = c.BeginTransaction()
        ok = ExecStore(c, t, "Modexport_codice", vcod2, err)
        t.Commit()
        Check(Not ok, "Modexport_codice su un feed senza riga di opzioni: False (come ogni Mod* con 0 righe)")

        ' --- duplica ---
        Exec(c, "INSERT INTO export_filtri (ExportId, MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId) VALUES (" & idA & ", 5, -1, -1, -1, -1, -1, -1), (" & idA & ", -1, -1, -1, -1, -1, -1, 77)")
        Exec(c, "UPDATE export_opzioni SET Separatore = ';', MinutiCache = 45 WHERE ExportId = " & idA)
        Dim vd() As Object = New Object() {idA, Nothing}
        t = c.BeginTransaction()
        ok = ExecStore(c, t, "Dupexport", vd, err)
        t.Commit()
        Dim idD As Integer = Convert.ToInt32(vd(1))
        Check(ok AndAlso idD > 0 AndAlso idD <> idA, "Dupexport: nuovo feed (" & idD.ToString() & ")")
        Check(Scalar(c, "SELECT Abilitato FROM `export` WHERE ID = " & idD) = "0" AndAlso Scalar(c, "SELECT Descrizione FROM `export` WHERE ID = " & idD) = Prefix & "A_copia", "Dupexport: Abilitato = 0 e nome con _copia")
        Check(Scalar(c, "SELECT COUNT(*) FROM export_opzioni WHERE ExportId = " & idD & " AND Separatore = ';' AND MinutiCache = 45 AND TokenAccesso <> '" & token2 & "'") = "1", "Dupexport: opzioni copiate e codice NUOVO (mai copiato)")
        Check(Scalar(c, "SELECT COUNT(*) FROM export_colonne WHERE ExportId = " & idD) = "3" AndAlso Scalar(c, "SELECT COUNT(*) FROM export_filtri WHERE ExportId = " & idD) = "2", "Dupexport: colonne e filtri copiati")
        Check(Scalar(c, "SELECT COUNT(*) FROM export_filtri WHERE ExportId = " & idA) = "2" AndAlso Scalar(c, "SELECT COUNT(*) FROM export_colonne WHERE ExportId = " & idA) = "3", "Dupexport: l'origine e intatta")
        Dim vd2() As Object = New Object() {-12345, Nothing}
        t = c.BeginTransaction()
        ok = ExecStore(c, t, "Dupexport", vd2, err)
        t.Commit()
        Check(ok AndAlso Convert.ToInt32(vd2(1)) = -1, "Dupexport su un feed che non esiste: -1, nessuna riga")
        Dim vd3() As Object = New Object() {idB, Nothing}
        t = c.BeginTransaction()
        ok = ExecStore(c, t, "Dupexport", vd3, err)
        t.Commit()
        Dim idE As Integer = Convert.ToInt32(vd3(1))
        Check(ok AndAlso idE > 0 AndAlso Scalar(c, "SELECT COUNT(*) FROM export_opzioni WHERE ExportId = " & idE) = "1", "Dupexport di un feed senza opzioni: il duplicato le ha (predefiniti e codice nuovo)")

        ' --- transazione: annullamento ---
        Dim rw3 As DataRow = optHeader.NewRow()
        rw3("ExportId") = idB
        rw3("Separatore") = "#"
        t = c.BeginTransaction()
        ok = AggiungiDati(c, t, "Newexport_opzioni", rw3, vp, err)
        t.Rollback()
        Check(ok AndAlso Scalar(c, "SELECT COUNT(*) FROM export_opzioni WHERE ExportId = " & idB) = "0", "rollback del gestionale: la riga delle opzioni non resta")

        ' --- errore a meta: la cancellazione dei dettagli e le nuove righe stanno nella stessa transazione ---
        t = c.BeginTransaction()
        Exec2(c, t, "DELETE FROM export_colonne WHERE ExportId = " & idA)
        Dim bad As DataRow = colHeader.NewRow()
        bad("ExportId") = idA
        bad("Posizione") = 1
        Dim vb() As Object = Nothing
        Dim ok1 As Boolean = AggiungiDati(c, t, "Newexport_colonne", bad, vb, err)
        Dim bad2 As DataRow = colHeader.NewRow()
        bad2("ExportId") = idA
        bad2("Posizione") = 1
        Dim ok2 As Boolean = AggiungiDati(c, t, "Newexport_colonne", bad2, vb, err)
        t.Rollback()
        Check(ok1 AndAlso Not ok2 AndAlso Scalar(c, "SELECT COUNT(*) FROM export_colonne WHERE ExportId = " & idA) = "3", "due colonne nella stessa posizione: la seconda e rifiutata e il rollback riporta le tre originali")

        ' --- cascata: cancellare un feed (come fa l'elenco, DELETE diretta) cancella opzioni, colonne e stato ---
        Exec(c, "INSERT INTO export_stato (ExportId, UltimeRighe) VALUES (" & idA & ", 5)")
        Exec(c, "DELETE FROM `export` WHERE ID = " & idA)
        Exec(c, "DELETE FROM export_filtri WHERE ExportId = " & idA)
        Check(Scalar(c, "SELECT (SELECT COUNT(*) FROM export_opzioni WHERE ExportId = " & idA & ") + (SELECT COUNT(*) FROM export_colonne WHERE ExportId = " & idA & ") + (SELECT COUNT(*) FROM export_stato WHERE ExportId = " & idA & ")") = "0", "cancellare il feed cancella opzioni, colonne e stato (cascata)")

        ' --- il gestionale vecchio funziona ancora alla fine ---
        Dim idZ As Integer = 0
        t = c.BeginTransaction()
        ok = OldSave(c, t, Prefix & "Z", 0, idZ, err)
        t.Commit()
        Check(ok AndAlso idZ > 0, "alla fine il vecchio gestionale salva ancora (" & err & ")")
    End Sub

    Private Sub Exec2(ByVal c As MySqlConnection, ByVal t As MySqlTransaction, ByVal sql As String)
        Using cmd As New MySqlCommand(sql, c, t)
            cmd.ExecuteNonQuery()
        End Using
    End Sub
End Module
