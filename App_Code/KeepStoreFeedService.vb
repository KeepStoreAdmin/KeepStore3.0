Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.IO
Imports System.Text
Imports System.Threading
Imports System.Web
Imports System.Xml
Imports MySql.Data.MySqlClient

' EXPORT-FEED-ENGINE-1A. Motore dei feed: configurazione, generazione di UN file pronto per feed (un solo lavoratore alla volta), servizio del file
' con 304. Il database resta la fonte di prezzo, promozione, IVA e giacenza: il prezzo e quello che il sito mostra a un utente anonimo per 1 pezzo
' (stesso resolver della scheda), mai le colonne di promozione della vista. Le richieste dei comparatori non toccano il database nel caso comune.

Public NotInheritable Class KeepStoreFeedConfig
    Public Property ExportId As Integer
    Public Property Token As String = ""
    Public Property Enabled As Boolean
    Public Property Domain As String = ""
    Public Property CompanyId As Integer
    Public Property Listino As Integer
    Public Property Listino2 As Integer
    Public Property IncludeTax As Boolean
    Public Property MinStock As Double = -1
    Public Property ShippingFee As Decimal
    Public Property ShippingDays As String = ""
    Public Property CarrierId As Integer
    Public Property CarrierVat As Decimal
    Public Property FormatString As String = ""
    Public Property Options As New KeepStoreFeedOptions()
    Public Property Columns As New List(Of KeepStoreFeedColumn)()
    ' Filtri di selezione (export_filtri), letti con il resto della configurazione: stessa fotografia per il file e per l'impronta.
    Public Property Filters As New List(Of Dictionary(Of String, Integer))()
    Public Property Fingerprint As String = ""
End Class

Public NotInheritable Class KeepStoreFeedException
    Inherits Exception
    Public ReadOnly Code As String
    Public Sub New(ByVal code As String)
        MyBase.New(code)
        Me.Code = code
    End Sub
End Class

Public NotInheritable Class KeepStoreFeedService
    Private Sub New()
    End Sub

    Public Const FolderVirtualPath As String = "~/Public/assets/images/export"
    Public Const ConfigCacheSeconds As Integer = 60
    Public Const NegativeCacheSeconds As Integer = 30
    Public Const NegativeCacheMax As Integer = 1000
    Public Const MissesPerSecond As Integer = 20
    Public Const FailureCooldownMinutes As Integer = 5
    Public Const FailureTableMax As Integer = 500
    Public Const RequestStampMinutes As Integer = 10
    Public Const MinMinutesCache As Integer = 15
    Public Const MaxMinutesCache As Integer = 1440

    ' Il file pronto non si serve mai staticamente: nessuna estensione ammessa nella cartella, tutto passa da feed.aspx.
    Public Const GuardConfigText As String = "<?xml version=""1.0"" encoding=""utf-8""?>" & vbCrLf &
        "<configuration>" & vbCrLf &
        "  <system.webServer>" & vbCrLf &
        "    <security>" & vbCrLf &
        "      <requestFiltering>" & vbCrLf &
        "        <fileExtensions allowUnlisted=""false"" />" & vbCrLf &
        "      </requestFiltering>" & vbCrLf &
        "    </security>" & vbCrLf &
        "  </system.webServer>" & vbCrLf &
        "</configuration>" & vbCrLf

    Private Shared ReadOnly Invariant As CultureInfo = CultureInfo.InvariantCulture
    Private Shared ReadOnly Gate As New SemaphoreSlim(1, 1)
    Private Shared ReadOnly StateLock As New Object()
    Private Shared ReadOnly Negative As New Dictionary(Of String, DateTime)()
    Private Shared ReadOnly FailureUntil As New Dictionary(Of String, DateTime)()
    Private Shared ReadOnly LastStamp As New Dictionary(Of String, DateTime)()
    Private Shared missSecond As Long = 0
    Private Shared missCount As Integer = 0

    ' ---------- impostazioni dell'installazione ----------

    Private Shared Function ConnectionString() As String
        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return ""
        Return settings.ConnectionString
    End Function

    ' Prefisso di 8 caratteri dell'installazione (database configurato): due database nella stessa cartella non si toccano.
    Public Shared Function ScopePrefix() As String
        Dim full As String = StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey()
        If String.IsNullOrEmpty(full) Then Return "00000000"
        Return full.Substring(0, 8)
    End Function

    Public Shared Function FolderPath() As String
        Return HttpContext.Current.Server.MapPath(FolderVirtualPath)
    End Function

    Public Shared Sub EnsureFolder(ByVal folder As String)
        Directory.CreateDirectory(folder)
        Dim guard As String = Path.Combine(folder, "web.config")
        If Not File.Exists(guard) Then
            Try
                File.WriteAllText(guard, GuardConfigText, New UTF8Encoding(False))
            Catch ex As IOException
            End Try
        End If
    End Sub

    ' ---------- configurazione (cache di processo 60 s) ----------

    Private Shared Function CacheKey(ByVal token As String) As String
        Return "KeepStore.Feed.Config." & ScopePrefix() & "." & token
    End Function

    ' Nothing = codice sconosciuto (o troppe richieste di codici sconosciuti: tooMany=True).
    Public Shared Function GetConfig(ByVal token As String, ByRef tooMany As Boolean) As KeepStoreFeedConfig
        tooMany = False
        Dim cached As KeepStoreFeedConfig = TryCast(HttpRuntime.Cache(CacheKey(token)), KeepStoreFeedConfig)
        If cached IsNot Nothing Then Return cached
        SyncLock StateLock
            Dim expires As DateTime
            If Negative.TryGetValue(token, expires) Then
                If expires > DateTime.UtcNow Then Return Nothing
                Negative.Remove(token)
            End If
            Dim second As Long = DateTime.UtcNow.Ticks \ TimeSpan.TicksPerSecond
            If second <> missSecond Then
                missSecond = second
                missCount = 0
            End If
            missCount += 1
            If missCount > MissesPerSecond Then
                tooMany = True
                Return Nothing
            End If
        End SyncLock

        Dim cfg As KeepStoreFeedConfig = LoadConfig(token)
        If cfg Is Nothing Then
            SyncLock StateLock
                If Negative.Count >= NegativeCacheMax Then Negative.Clear()
                Negative(token) = DateTime.UtcNow.AddSeconds(NegativeCacheSeconds)
            End SyncLock
            Return Nothing
        End If
        HttpRuntime.Cache.Insert(CacheKey(token), cfg, Nothing, DateTime.UtcNow.AddSeconds(ConfigCacheSeconds), System.Web.Caching.Cache.NoSlidingExpiration)
        If Not cfg.Enabled Then RemoveFeedFiles(cfg)
        Return cfg
    End Function

    Private Shared Function Txt(ByVal r As MySqlDataReader, ByVal name As String) As String
        Dim i As Integer = r.GetOrdinal(name)
        If r.IsDBNull(i) Then Return ""
        Return Convert.ToString(r.GetValue(i), Invariant)
    End Function

    Private Shared Function Dec(ByVal r As MySqlDataReader, ByVal name As String) As Decimal
        Dim i As Integer = r.GetOrdinal(name)
        If r.IsDBNull(i) Then Return 0D
        Return Convert.ToDecimal(r.GetValue(i), Invariant)
    End Function

    Private Shared Function GInt(ByVal r As MySqlDataReader, ByVal name As String) As Integer
        Dim i As Integer = r.GetOrdinal(name)
        If r.IsDBNull(i) Then Return 0
        Return Convert.ToInt32(r.GetValue(i), Invariant)
    End Function

    Private Shared Function LoadConfig(ByVal token As String) As KeepStoreFeedConfig
        Dim cs As String = ConnectionString()
        If cs = "" Then Return Nothing
        Dim cfg As New KeepStoreFeedConfig()
        Dim tipo As String = ""
        Dim domain As String = ""
        Using conn As New MySqlConnection(cs)
            conn.Open()
            Using cmd As New MySqlCommand("SELECT e.ID, e.FormatString, e.NListino, e.NListino2, e.IvaTipo, e.Giacenza, e.SpeseSpedizione, e.GiorniSpedizione, e.Azienda, e.Tipo, e.IdVettore, " &
                                          "e.Tutto_in_minuscolo, e.Abilitato, o.Separatore, o.DelimitatoreTesto, o.Codifica, o.SeparatoreDecimale, o.Intestazione, o.XmlRadice, o.XmlElemento, " &
                                          "o.TogliHtml, o.MinutiCache, o.ParolaDisponibile, o.ParolaInArrivo, o.ParolaNonDisponibile, o.SenzaImmagine, o.SenzaEan, o.PrezzoZero, iva.valore AS CarrierVat " &
                                          "FROM export_opzioni o JOIN export e ON e.ID = o.ExportId LEFT JOIN vettori v ON e.IdVettore=v.id LEFT JOIN iva ON v.iva=iva.id WHERE o.TokenAccesso=@t LIMIT 1", conn)
                cmd.CommandTimeout = 10
                cmd.Parameters.Add("@t", MySqlDbType.VarChar, 64).Value = token
                Using r As MySqlDataReader = cmd.ExecuteReader()
                    If Not r.Read() Then Return Nothing
                    cfg.ExportId = GInt(r, "ID")
                    cfg.Token = token
                    cfg.Enabled = (GInt(r, "Abilitato") = 1)
                    cfg.FormatString = Txt(r, "FormatString")
                    cfg.Listino = GInt(r, "NListino")
                    cfg.Listino2 = GInt(r, "NListino2")
                    cfg.IncludeTax = (GInt(r, "IvaTipo") <> 1)
                    cfg.MinStock = If(r.IsDBNull(r.GetOrdinal("Giacenza")), -1.0R, Convert.ToDouble(r.GetValue(r.GetOrdinal("Giacenza")), Invariant))
                    cfg.ShippingFee = Dec(r, "SpeseSpedizione")
                    cfg.ShippingDays = Txt(r, "GiorniSpedizione")
                    cfg.CarrierId = GInt(r, "IdVettore")
                    cfg.CarrierVat = Dec(r, "CarrierVat")
                    domain = StorefrontCanonicalHostPolicy.NormalizeHost(Txt(r, "Azienda"))
                    tipo = Txt(r, "Tipo")
                    Dim o As New KeepStoreFeedOptions()
                    o.Format = KeepStoreFeedEngine.NormalizeFormat(tipo)
                    o.Separator = Txt(r, "Separatore")
                    o.TextDelimiter = Txt(r, "DelimitatoreTesto")
                    o.EncodingName = Txt(r, "Codifica")
                    o.DecimalSeparator = Txt(r, "SeparatoreDecimale")
                    o.Header = (GInt(r, "Intestazione") = 1)
                    o.XmlRoot = Txt(r, "XmlRadice")
                    o.XmlElement = Txt(r, "XmlElemento")
                    o.StripHtml = (GInt(r, "TogliHtml") = 1)
                    Dim minutes As Integer = GInt(r, "MinutiCache")
                    o.MinutesCache = If(minutes >= MinMinutesCache AndAlso minutes <= MaxMinutesCache, minutes, 60)
                    o.WordAvailable = Txt(r, "ParolaDisponibile")
                    o.WordIncoming = Txt(r, "ParolaInArrivo")
                    o.WordUnavailable = Txt(r, "ParolaNonDisponibile")
                    o.SkipNoImage = (GInt(r, "SenzaImmagine") = 1)
                    o.SkipNoEan = (GInt(r, "SenzaEan") = 1)
                    o.SkipZeroPrice = (GInt(r, "PrezzoZero") = 1)
                    o.LowerCaseTitle = (GInt(r, "Tutto_in_minuscolo") = 1)
                    cfg.Options = o
                End Using
            End Using

            ' Azienda del feed: la riga di aziende con url1 o url2 UGUALE (confronto esatto, normalizzato) al dominio del feed; zero o piu di una = non risolta.
            Dim matches As Integer = 0
            If domain <> "" Then
                Using cmd As New MySqlCommand("SELECT Id, url1, url2 FROM aziende", conn)
                    cmd.CommandTimeout = 10
                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim u1 As String = StorefrontCanonicalHostPolicy.NormalizeHost(Txt(r, "url1"))
                            Dim u2 As String = StorefrontCanonicalHostPolicy.NormalizeHost(Txt(r, "url2"))
                            If (u1 <> "" AndAlso u1 = domain) OrElse (u2 <> "" AndAlso u2 = domain) Then
                                matches += 1
                                cfg.CompanyId = GInt(r, "Id")
                            End If
                        End While
                    End Using
                End Using
            End If
            If matches <> 1 Then cfg.CompanyId = 0
            cfg.Domain = domain

            Using cmd As New MySqlCommand("SELECT TitoloColonna, Campo, Prefisso, Suffisso, ValoreFisso, MassimoCaratteri, SeVuoto FROM export_colonne WHERE ExportId=@id ORDER BY Posizione, Id", conn)
                cmd.CommandTimeout = 10
                cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = cfg.ExportId
                Using r As MySqlDataReader = cmd.ExecuteReader()
                    While r.Read()
                        Dim col As New KeepStoreFeedColumn()
                        col.Title = Txt(r, "TitoloColonna")
                        Dim field As String = Txt(r, "Campo").Trim()
                        col.Source = If(field <> "", "#" & field & "#", Txt(r, "ValoreFisso"))
                        col.Prefix = Txt(r, "Prefisso")
                        col.Suffix = Txt(r, "Suffisso")
                        col.MaxChars = GInt(r, "MassimoCaratteri")
                        col.IfEmpty = Txt(r, "SeVuoto")
                        cfg.Columns.Add(col)
                    End While
                End Using
            End Using
            cfg.Filters = ReadFilters(conn, cfg.ExportId)
        End Using

        If cfg.Columns.Count = 0 Then
            cfg.Columns = KeepStoreFeedEngine.ParseLegacyFormat(cfg.FormatString)
            ' Feed senza colonne libere: il csv storico usa ";" e virgolette (opzioni non ancora scelte = predefinite).
            If KeepStoreFeedEngine.NormalizeFormat(tipo) = "csv" AndAlso cfg.Options.Separator = "|" AndAlso cfg.Options.TextDelimiter = "" Then
                cfg.Options.Separator = ";"
                cfg.Options.TextDelimiter = """"
            End If
        End If
        cfg.Fingerprint = ComputeFingerprint(cfg)
        Return cfg
    End Function

    ' Impronta della configurazione: tutto cio che cambia il CONTENUTO del file (azienda e dominio, listini, IVA, selezione, spedizione, opzioni gia normalizzate, colonne in ordine,
    ' filtri in ordine) piu il giorno (le promozioni valgono per giorno) e la versione del motore. Modificare un feed nel gestionale cambia il nome del file: mai un file vecchio.
    Private Shared Function ComputeFingerprint(ByVal cfg As KeepStoreFeedConfig) As String
        Dim p As New List(Of String)()
        Dim o As KeepStoreFeedOptions = cfg.Options
        p.Add(KeepStoreFeedEngine.EngineVersion)
        p.Add(Date.Today.ToString("yyyyMMdd", Invariant))
        p.Add(cfg.CompanyId.ToString(Invariant))
        p.Add(cfg.Domain)
        p.Add(cfg.Listino.ToString(Invariant))
        p.Add(cfg.Listino2.ToString(Invariant))
        p.Add(If(cfg.IncludeTax, "1", "0"))
        p.Add(cfg.MinStock.ToString("R", Invariant))
        p.Add(cfg.ShippingFee.ToString(Invariant))
        p.Add(cfg.ShippingDays)
        p.Add(cfg.CarrierId.ToString(Invariant))
        p.Add(cfg.CarrierVat.ToString(Invariant))
        p.Add(cfg.FormatString)
        p.Add(o.Format)
        p.Add(o.Separator)
        p.Add(o.TextDelimiter)
        p.Add(o.EncodingName)
        p.Add(o.DecimalSeparator)
        p.Add(If(o.Header, "1", "0"))
        p.Add(o.XmlRoot)
        p.Add(o.XmlElement)
        p.Add(If(o.StripHtml, "1", "0"))
        p.Add(o.MinutesCache.ToString(Invariant))
        p.Add(o.WordAvailable)
        p.Add(o.WordIncoming)
        p.Add(o.WordUnavailable)
        p.Add(If(o.SkipNoImage, "1", "0"))
        p.Add(If(o.SkipNoEan, "1", "0"))
        p.Add(If(o.SkipZeroPrice, "1", "0"))
        p.Add(If(o.LowerCaseTitle, "1", "0"))
        p.Add(cfg.Columns.Count.ToString(Invariant))
        For Each c As KeepStoreFeedColumn In cfg.Columns
            p.Add(c.Title)
            p.Add(c.Source)
            p.Add(c.Prefix)
            p.Add(c.Suffix)
            p.Add(c.MaxChars.ToString(Invariant))
            p.Add(c.IfEmpty)
        Next
        p.Add(cfg.Filters.Count.ToString(Invariant))
        For Each f As Dictionary(Of String, Integer) In cfg.Filters
            For Each name As String In New String() {"MarcheId", "SettoriId", "CategorieId", "TipologieId", "GruppiId", "SottogruppiId", "ArticoliId"}
                p.Add(f(name).ToString(Invariant))
            Next
        Next
        Return KeepStoreFeedEngine.Fingerprint(p)
    End Function

    ' ---------- file ----------

    Public Shared Function FinalPath(ByVal cfg As KeepStoreFeedConfig) As String
        Return Path.Combine(FolderPath(), KeepStoreFeedEngine.FileName(ScopePrefix(), cfg.ExportId, cfg.Token, cfg.Options.Format, cfg.Fingerprint))
    End Function

    Public Shared Sub RemoveFeedFiles(ByVal cfg As KeepStoreFeedConfig)
        RemoveStaleFiles(cfg, "")
    End Sub

    Private Shared Sub RemoveStaleFiles(ByVal cfg As KeepStoreFeedConfig, ByVal currentName As String)
        Try
            Dim folder As String = FolderPath()
            If Not Directory.Exists(folder) Then Return
            Dim scope As String = ScopePrefix()
            Dim tmpPrefix As String = scope & "-" & cfg.ExportId.ToString(Invariant) & "-"
            For Each f As String In Directory.GetFiles(folder)
                Dim name As String = Path.GetFileName(f)
                Dim stale As Boolean = KeepStoreFeedEngine.IsStaleFileOf(name, scope, cfg.ExportId, currentName)
                If Not stale AndAlso name.StartsWith(tmpPrefix, StringComparison.OrdinalIgnoreCase) AndAlso name.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase) Then
                    stale = (DateTime.UtcNow - File.GetLastWriteTimeUtc(f)) > TimeSpan.FromHours(1)
                End If
                If stale Then
                    Try
                        File.Delete(f)
                    Catch
                    End Try
                End If
            Next
        Catch
        End Try
    End Sub

    Private Shared Sub Publish(ByVal tmp As String, ByVal final As String)
        Dim attempt As Integer = 0
        While True
            Try
                If File.Exists(final) Then
                    File.Replace(tmp, final, Nothing, True)
                Else
                    File.Move(tmp, final)
                End If
                Return
            Catch ex As IOException
                attempt += 1
                If attempt >= 5 Then Throw New KeepStoreFeedException("PUBBLICAZIONE_NON_RIUSCITA")
                Thread.Sleep(200)
            Catch ex As UnauthorizedAccessException
                attempt += 1
                If attempt >= 5 Then Throw New KeepStoreFeedException("PUBBLICAZIONE_NON_RIUSCITA")
                Thread.Sleep(200)
            End Try
        End While
    End Sub

    ' ---------- stato (scritto dal sito in export_stato; mai in export) ----------

    Private Shared Sub WriteState(ByVal cfg As KeepStoreFeedConfig, ByVal rows As Integer, ByVal skipped As Integer, ByVal errorCode As String, ByVal touchOnly As Boolean)
        Try
            Dim cs As String = ConnectionString()
            If cs = "" Then Return
            Using conn As New MySqlConnection(cs)
                conn.Open()
                Dim sql As String
                If touchOnly Then
                    sql = "INSERT INTO export_stato (ExportId, UltimaRichiestaUtc) VALUES (@id, UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE UltimaRichiestaUtc=VALUES(UltimaRichiestaUtc)"
                ElseIf errorCode = "" Then
                    sql = "INSERT INTO export_stato (ExportId, UltimaGenerazioneUtc, UltimeRighe, UltimeScartate, UltimoErrore) VALUES (@id, UTC_TIMESTAMP(), @r, @s, NULL) " &
                          "ON DUPLICATE KEY UPDATE UltimaGenerazioneUtc=VALUES(UltimaGenerazioneUtc), UltimeRighe=VALUES(UltimeRighe), UltimeScartate=VALUES(UltimeScartate), UltimoErrore=NULL"
                Else
                    sql = "INSERT INTO export_stato (ExportId, UltimoErrore) VALUES (@id, @e) ON DUPLICATE KEY UPDATE UltimoErrore=VALUES(UltimoErrore)"
                End If
                Using cmd As New MySqlCommand(sql, conn)
                    cmd.CommandTimeout = 10
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = cfg.ExportId
                    If Not touchOnly Then
                        If errorCode = "" Then
                            cmd.Parameters.Add("@r", MySqlDbType.Int32).Value = rows
                            cmd.Parameters.Add("@s", MySqlDbType.Int32).Value = skipped
                        Else
                            cmd.Parameters.Add("@e", MySqlDbType.VarChar, 200).Value = If(errorCode.Length > 200, errorCode.Substring(0, 200), errorCode)
                        End If
                    End If
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch ex As Exception
            Try
                KeepStoreLog.Error("feed", "Stato del feed non scritto (id " & cfg.ExportId.ToString(Invariant) & ")", ex)
            Catch
            End Try
        End Try
    End Sub

    ' ---------- generazione ----------

    Private Shared Function FileIsFresh(ByVal path As String, ByVal minutes As Integer) As Boolean
        If Not File.Exists(path) Then Return False
        Return (DateTime.UtcNow - File.GetLastWriteTimeUtc(path)).TotalMinutes < minutes
    End Function

    Private Shared Function InCooldown(ByVal cfg As KeepStoreFeedConfig) As Boolean
        SyncLock StateLock
            Dim expires As DateTime
            If FailureUntil.TryGetValue(cfg.Token, expires) Then
                If expires > DateTime.UtcNow Then Return True
                FailureUntil.Remove(cfg.Token)
            End If
            Return False
        End SyncLock
    End Function

    Private Shared Sub MarkFailure(ByVal cfg As KeepStoreFeedConfig)
        SyncLock StateLock
            If FailureUntil.Count >= FailureTableMax Then FailureUntil.Clear()
            FailureUntil(cfg.Token) = DateTime.UtcNow.AddMinutes(FailureCooldownMinutes)
        End SyncLock
    End Sub

    ' True se il file pronto e aggiornato (rigenerato ora da questa richiesta o gia fresco). False = lavoro non svolto (occupato, errore, in attesa dopo un errore).
    Public Shared Function EnsureFresh(ByVal cfg As KeepStoreFeedConfig) As Boolean
        Dim path As String = FinalPath(cfg)
        If FileIsFresh(path, cfg.Options.MinutesCache) Then Return True
        If InCooldown(cfg) Then Return False
        If Not Gate.Wait(0) Then Return False
        Try
            Dim cs As String = ConnectionString()
            If cs = "" Then Return False
            Dim builder As New MySqlConnectionStringBuilder(cs)
            builder.Pooling = False
            Using lockConn As New MySqlConnection(builder.ConnectionString)
                lockConn.Open()
                Dim acquired As Boolean = False
                Try
                    Using cmd As New MySqlCommand("SELECT GET_LOCK(CONCAT('ksfeed.', MD5(CONCAT(DATABASE(), ':', @id))), 0)", lockConn)
                        cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = cfg.ExportId
                        acquired = (Convert.ToInt32(cmd.ExecuteScalar(), Invariant) = 1)
                    End Using
                    If Not acquired Then Return False
                    ' Un altro lavoratore puo averlo rigenerato mentre si aspettava il blocco.
                    If FileIsFresh(path, cfg.Options.MinutesCache) Then Return True
                    Return GenerateAndPublish(cfg, path)
                Finally
                    If acquired Then
                        Try
                            Using cmd As New MySqlCommand("SELECT RELEASE_LOCK(CONCAT('ksfeed.', MD5(CONCAT(DATABASE(), ':', @id))))", lockConn)
                                cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = cfg.ExportId
                                cmd.ExecuteScalar()
                            End Using
                        Catch
                        End Try
                    End If
                End Try
            End Using
            Return False
        Catch ex As Exception
            MarkFailure(cfg)
            WriteState(cfg, 0, 0, ErrorCodeOf(ex), False)
            Return False
        Finally
            Gate.Release()
        End Try
    End Function

    Private Shared Function GenerateAndPublish(ByVal cfg As KeepStoreFeedConfig, ByVal finalPath As String) As Boolean
        Dim folder As String = FolderPath()
        EnsureFolder(folder)
        Dim tmp As String = Path.Combine(folder, ScopePrefix() & "-" & cfg.ExportId.ToString(Invariant) & "-" & Guid.NewGuid().ToString("N") & ".tmp")
        Dim rows As Integer = 0
        Dim skipped As Integer = 0
        Try
            WriteFeed(cfg, tmp, rows, skipped)
            Publish(tmp, finalPath)
        Catch ex As KeepStoreFeedException
            TryDelete(tmp)
            MarkFailure(cfg)
            WriteState(cfg, 0, 0, ex.Code, False)
            Return False
        Catch ex As Exception
            TryDelete(tmp)
            MarkFailure(cfg)
            WriteState(cfg, 0, 0, ErrorCodeOf(ex), False)
            Try
                KeepStoreLog.Error("feed", "Generazione non riuscita (id " & cfg.ExportId.ToString(Invariant) & ")", ex)
            Catch
            End Try
            Return False
        End Try
        RemoveStaleFiles(cfg, Path.GetFileName(finalPath))
        WriteState(cfg, rows, skipped, "", False)
        Return True
    End Function

    ' Codice dell'errore per lo stato: la cartella non scrivibile (permessi dell'identita del sito) e il caso piu probabile alla prima installazione.
    Private Shared Function ErrorCodeOf(ByVal ex As Exception) As String
        If TypeOf ex Is UnauthorizedAccessException Then Return "CARTELLA_NON_SCRIVIBILE"
        Return "ERRORE_" & ex.GetType().Name
    End Function

    Private Shared Sub TryDelete(ByVal path As String)
        Try
            If File.Exists(path) Then File.Delete(path)
        Catch
        End Try
    End Sub

    ' ---------- lettura del catalogo e scrittura del file ----------

    Private Shared Function FilterConditions(ByVal f As Dictionary(Of String, Integer), ByVal cmd As MySqlCommand, ByVal index As Integer) As String
        Dim suffix As String = index.ToString(Invariant)
        Dim columns As String() = {"MarcheId", "SettoriId", "CategorieId", "TipologieId", "GruppiId", "SottogruppiId"}
        Dim sigle As String() = {"fm", "fs", "fc", "ft", "fg", "fsg"}
        Dim fields As String() = {"v.MarcheId", "v.SettoriId", "v.CategorieId", "v.TipologieId", "v.GruppiId", "v.SottoGrupPIId"}
        Dim thresholds As Integer() = {0, -1, -1, -1, -1, -1}
        Dim parts As New List(Of String)()
        For i As Integer = 0 To columns.Length - 1
            If f(columns(i)) > thresholds(i) Then
                parts.Add("(" & fields(i) & "=@" & sigle(i) & suffix & ")")
                cmd.Parameters.Add("@" & sigle(i) & suffix, MySqlDbType.Int32).Value = f(columns(i))
            Else
                parts.Add("(1=1)")
            End If
        Next
        If f("ArticoliId") > -1 Then
            parts.Add("(v.id=@fa" & suffix & ")")
            cmd.Parameters.Add("@fa" & suffix, MySqlDbType.Int32).Value = f("ArticoliId")
        End If
        Return "(" & String.Join(" AND ", parts.ToArray()) & ")"
    End Function

    Private Shared Function ReadFilters(ByVal conn As MySqlConnection, ByVal exportId As Integer) As List(Of Dictionary(Of String, Integer))
        Dim result As New List(Of Dictionary(Of String, Integer))()
        Using cmd As New MySqlCommand("SELECT MarcheId, SettoriId, CategorieId, TipologieId, GruppiId, SottogruppiId, ArticoliId FROM export_filtri WHERE ExportId=@id ORDER BY id", conn)
            cmd.CommandTimeout = 10
            cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = exportId
            Using r As MySqlDataReader = cmd.ExecuteReader()
                While r.Read()
                    Dim f As New Dictionary(Of String, Integer)()
                    For Each name As String In New String() {"MarcheId", "SettoriId", "CategorieId", "TipologieId", "GruppiId", "SottogruppiId", "ArticoliId"}
                        Dim i As Integer = r.GetOrdinal(name)
                        f(name) = If(r.IsDBNull(i), -1, Convert.ToInt32(r.GetValue(i), Invariant))
                    Next
                    result.Add(f)
                End While
            End Using
        End Using
        Return result
    End Function

    Private Shared Function ImageUrl(ByVal value As Object, ByVal domain As String, ByVal thumbnail As Boolean) As String
        Dim resolved As String = If(thumbnail, ThemeManager.ProductThumbnailImageUrl(value), ThemeManager.ProductImageUrl(value))
        If String.Equals(resolved, ThemeManager.PlaceholderProductImageUrl(), StringComparison.OrdinalIgnoreCase) Then Return ""
        If resolved.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse resolved.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then Return KeepStoreFeedEngine.HttpsUrl(resolved)
        If resolved.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then Return ""
        Return "https://" & domain.Trim().TrimEnd("/"c) & "/" & resolved.TrimStart("/"c)
    End Function

    Private Shared Function UsesToken(ByVal cols As IList(Of KeepStoreFeedColumn), ByVal prefix As String) As Boolean
        For Each c As KeepStoreFeedColumn In cols
            If c.Source IsNot Nothing AndAlso c.Source.IndexOf("#" & prefix, StringComparison.OrdinalIgnoreCase) >= 0 Then Return True
        Next
        Return False
    End Function

    Private Shared Function RowText(ByVal r As MySqlDataReader, ByVal name As String) As String
        Dim i As Integer = r.GetOrdinal(name)
        If r.IsDBNull(i) Then Return ""
        Return Convert.ToString(r.GetValue(i), Invariant)
    End Function

    Private Shared Function RowDec(ByVal r As MySqlDataReader, ByVal name As String) As Decimal
        Dim i As Integer = r.GetOrdinal(name)
        If r.IsDBNull(i) Then Return 0D
        Return Convert.ToDecimal(r.GetValue(i), Invariant)
    End Function

    Private Shared Function RowInt(ByVal r As MySqlDataReader, ByVal name As String, ByVal fallback As Integer) As Integer
        Dim i As Integer = r.GetOrdinal(name)
        If r.IsDBNull(i) Then Return fallback
        Return Convert.ToInt32(r.GetValue(i), Invariant)
    End Function

    Private Shared Function RowDate(ByVal r As MySqlDataReader, ByVal name As String) As Nullable(Of Date)
        Dim i As Integer = r.GetOrdinal(name)
        If r.IsDBNull(i) Then Return Nothing
        Dim d As DateTime
        If KeepStoreDates.TryToDate(r.GetValue(i), d) Then Return d
        Return Nothing
    End Function

    Private Shared Sub WriteFeed(ByVal cfg As KeepStoreFeedConfig, ByVal tmpPath As String, ByRef rowCount As Integer, ByRef skipped As Integer)
        Dim opts As KeepStoreFeedOptions = cfg.Options
        Dim columns As List(Of KeepStoreFeedColumn) = cfg.Columns
        Dim invalid As String = KeepStoreFeedEngine.Validate(opts, columns)
        If invalid <> "" Then Throw New KeepStoreFeedException(invalid)
        If cfg.CompanyId <= 0 Then Throw New KeepStoreFeedException("AZIENDA_NON_RISOLTA")
        If cfg.Listino <= 0 Then Throw New KeepStoreFeedException("LISTINO_NON_VALIDO")

        Dim needShipping As Boolean = UsesToken(columns, "CostoSpedizioneProdo#")
        Dim needPrice2 As Boolean = UsesToken(columns, "Prezzo2#")
        Dim needImages As Boolean = UsesToken(columns, "UrlImg") OrElse opts.SkipNoImage
        Dim isXml As Boolean = (KeepStoreFeedEngine.NormalizeFormat(opts.Format) = "xml")
        Dim ctx As New KeepStoreFeedContext()
        ctx.Domain = cfg.Domain
        ctx.ShippingDays = cfg.ShippingDays
        ctx.ShippingFee = KeepStoreFeedEngine.MoneyWithTax(cfg.ShippingFee, cfg.IncludeTax, cfg.CarrierVat, opts.DecimalSeparator)
        Dim enc As Encoding = KeepStoreFeedEngine.ResolveEncoding(If(isXml, "utf-8", opts.EncodingName))
        Dim cs As String = ConnectionString()
        Dim stopwatch As Diagnostics.Stopwatch = Diagnostics.Stopwatch.StartNew()

        Using conn As New MySqlConnection(cs)
            conn.Open()
            Dim today As Date = Date.Today
            Using cmd As New MySqlCommand("SELECT CURDATE()", conn)
                Dim d As DateTime
                If KeepStoreDates.TryToDate(cmd.ExecuteScalar(), d) Then today = d.Date
            End Using

            Dim bands As New List(Of KeyValuePair(Of Integer, Decimal))()
            If needShipping AndAlso cfg.CarrierId > 0 Then
                Using cmd As New MySqlCommand("SELECT PesoMax, CostoFisso FROM vettoricosti WHERE VettoriId=@v ORDER BY PesoMax", conn)
                    cmd.Parameters.Add("@v", MySqlDbType.Int32).Value = cfg.CarrierId
                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            bands.Add(New KeyValuePair(Of Integer, Decimal)(RowInt(r, "PesoMax", 0), RowDec(r, "CostoFisso")))
                        End While
                    End Using
                End Using
            End If

            Dim filters As List(Of Dictionary(Of String, Integer)) = cfg.Filters

            ' Promozioni valide oggi per un utente anonimo di questa azienda e di questo listino: una sola lettura per generazione.
            Dim promoContext As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateAnonymousContext(
                StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey(), cfg.CompanyId, cfg.Listino, today)
            Dim batch As ProductPromotionEligibilityBatch = ProductPromotionEligibilityResolver.CreateBatch(cs, promoContext)
            If batch Is Nothing OrElse batch.Status <> ProductPromotionEligibilityLoadStatus.Success Then Throw New KeepStoreFeedException("PROMOZIONI_NON_DISPONIBILI")

            Dim sql As New StringBuilder()
            sql.Append("SELECT x.* FROM (SELECT v.id, v.TCid, v.Codice, v.Ean, v.Descrizione1, v.Descrizione2, v.DescrizioneLunga, v.DescrizioneHTML, v.MarcheDescrizione, ")
            sql.Append("v.SettoriId, v.SettoriDescrizione, v.CategorieId, v.CategorieDescrizione, v.TipologieId, v.TipologieDescrizione, v.GruppiId, v.GruppiDEscrizione, v.SottoGrupPIId, ")
            sql.Append("v.MarcheId, v.Peso, v.Img1, v.Img2, v.Img3, v.Img4, v.Mesi, v.Garanzia, v.Giacenza, v.InOrdine, v.Ricondizionato, v.iva, v.Prezzo, v.PrezzoIvato, ")
            sql.Append("v.SpedizioneGratis_Listini, v.SpedizioneGratis_Data_Inizio, v.SpedizioneGratis_Data_Fine, ")
            If needPrice2 AndAlso cfg.Listino2 > 0 Then
                sql.Append("(SELECT al2.Prezzo FROM articoli_listini al2 WHERE al2.NListino=@lst2 AND al2.ArticoliId=v.id ORDER BY al2.id LIMIT 1) AS Prezzo2Net, ")
                sql.Append("(SELECT al2.PrezzoIvato FROM articoli_listini al2 WHERE al2.NListino=@lst2 AND al2.ArticoliId=v.id ORDER BY al2.id LIMIT 1) AS Prezzo2Gross, ")
            Else
                sql.Append("NULL AS Prezzo2Net, NULL AS Prezzo2Gross, ")
            End If
            sql.Append("ROW_NUMBER() OVER (PARTITION BY v.id ORDER BY CASE WHEN COALESCE(v.TCid,0)>0 THEN 0 ELSE 1 END, COALESCE(v.TCid,-1), COALESCE(v.ArticoliListiniId,0), COALESCE(v.OfferteDettagliId,0)) AS KsRank ")
            sql.Append("FROM vsuperarticoli v INNER JOIN articoli a ON a.id=v.id WHERE v.NListino=@lst AND COALESCE(v.Export,0)=1 AND COALESCE(a.Abilitato,0)=1")

            Using main As New MySqlCommand()
                main.Connection = conn
                main.CommandTimeout = KeepStoreFeedEngine.MaxSeconds
                main.Parameters.Add("@lst", MySqlDbType.Int32).Value = cfg.Listino
                If needPrice2 AndAlso cfg.Listino2 > 0 Then main.Parameters.Add("@lst2", MySqlDbType.Int32).Value = cfg.Listino2
                If cfg.MinStock >= 0 Then
                    sql.Append(" AND v.Giacenza >= @gia")
                    main.Parameters.Add("@gia", MySqlDbType.Double).Value = cfg.MinStock
                End If
                If filters.Count > 0 Then
                    Dim ors As New List(Of String)()
                    For i As Integer = 0 To filters.Count - 1
                        ors.Add(FilterConditions(filters(i), main, i))
                    Next
                    sql.Append(" AND (").Append(String.Join(" OR ", ors.ToArray())).Append(")")
                End If
                sql.Append(") x WHERE x.KsRank=1 ORDER BY x.SettoriId, x.CategorieId, x.TipologieId, x.MarcheId, x.Codice, x.id")
                main.CommandText = sql.ToString()

                Using fs As New FileStream(tmpPath, FileMode.CreateNew, FileAccess.Write, FileShare.None)
                    Dim textWriter As StreamWriter = Nothing
                    Dim xw As XmlWriter = Nothing
                    Try
                        If isXml Then
                            Dim xs As New XmlWriterSettings()
                            xs.Encoding = New UTF8Encoding(False)
                            xs.Indent = True
                            xs.IndentChars = "  "
                            xs.CheckCharacters = True
                            xs.NewLineHandling = NewLineHandling.Replace
                            xw = XmlWriter.Create(fs, xs)
                            xw.WriteStartDocument()
                            xw.WriteStartElement(opts.XmlRoot)
                        Else
                            textWriter = New StreamWriter(fs, enc)
                            textWriter.NewLine = vbCrLf
                            If opts.Header Then
                                Dim titles As New List(Of String)()
                                For Each c As KeepStoreFeedColumn In columns
                                    titles.Add(KeepStoreFeedEngine.CleanText(c.Title, False))
                                Next
                                textWriter.WriteLine(KeepStoreFeedEngine.DelimitedLine(titles, opts))
                            End If
                        End If

                        Using reader As MySqlDataReader = main.ExecuteReader()
                            While reader.Read()
                                Dim row As New KeepStoreFeedRow()
                                row.Id = RowInt(reader, "id", 0)
                                If row.Id <= 0 Then Continue While
                                Dim tcRaw As Integer = RowInt(reader, "TCid", -1)
                                Dim tcId As Integer = If(tcRaw <= 0, -1, tcRaw)
                                row.Code = RowText(reader, "Codice")
                                row.Ean = RowText(reader, "Ean")
                                row.Title1 = RowText(reader, "Descrizione1")
                                row.Title2 = RowText(reader, "Descrizione2")
                                row.LongText = RowText(reader, "DescrizioneLunga")
                                row.HtmlText = RowText(reader, "DescrizioneHTML")
                                row.Brand = RowText(reader, "MarcheDescrizione")
                                row.SectorId = RowInt(reader, "SettoriId", 0)
                                row.SectorName = RowText(reader, "SettoriDescrizione")
                                row.CategoryId = RowInt(reader, "CategorieId", 0)
                                row.CategoryName = RowText(reader, "CategorieDescrizione")
                                row.TypeId = RowInt(reader, "TipologieId", 0)
                                row.TypeName = RowText(reader, "TipologieDescrizione")
                                row.GroupId = RowInt(reader, "GruppiId", 0)
                                row.GroupName = RowText(reader, "GruppiDEscrizione")
                                row.SubgroupId = RowInt(reader, "SottoGrupPIId", 0)
                                row.Weight = RowDec(reader, "Peso")
                                row.Stock = RowDec(reader, "Giacenza")
                                row.Incoming = RowDec(reader, "InOrdine")
                                row.Refurbished = RowInt(reader, "Ricondizionato", 0)
                                row.WarrantyMonths = RowText(reader, "Mesi")
                                row.WarrantyText = RowText(reader, "Garanzia")
                                row.VatId = RowInt(reader, "iva", 0)

                                Dim net As Decimal = RowDec(reader, "Prezzo")
                                Dim gross As Decimal = RowDec(reader, "PrezzoIvato")
                                Dim chosenNet As Decimal = net
                                Dim chosenGross As Decimal = gross
                                If net > 0D AndAlso gross > 0D Then
                                    Dim res As ProductPromotionEligibilityResult = batch.ResolveForProduct(row.Id, tcId, 1D, net, gross)
                                    If res Is Nothing OrElse res.HasBlockingError Then Throw New KeepStoreFeedException("PROMOZIONI_NON_DISPONIBILI")
                                    If res.AppliedOffer IsNot Nothing Then
                                        chosenNet = res.AppliedOffer.PriceNet
                                        chosenGross = res.AppliedOffer.PriceGross
                                        row.DiscountPercent = res.AppliedOffer.DiscountPercent
                                    End If
                                End If
                                row.Price = Math.Round(If(cfg.IncludeTax, chosenGross, chosenNet), 2, MidpointRounding.AwayFromZero)
                                If Not reader.IsDBNull(reader.GetOrdinal("Prezzo2Net")) Then
                                    Dim p2 As Decimal = If(cfg.IncludeTax, RowDec(reader, "Prezzo2Gross"), RowDec(reader, "Prezzo2Net"))
                                    row.Price2 = Math.Round(p2, 2, MidpointRounding.AwayFromZero)
                                End If

                                If needShipping Then
                                    Dim startsOn As Nullable(Of Date) = RowDate(reader, "SpedizioneGratis_Data_Inizio")
                                    Dim endsOn As Nullable(Of Date) = RowDate(reader, "SpedizioneGratis_Data_Fine")
                                    If KeepStoreFeedEngine.IsFreeShipping(RowText(reader, "SpedizioneGratis_Listini"), cfg.Listino, startsOn, endsOn, today) Then
                                        row.ShippingCost = KeepStoreFeedEngine.FormatMoney(0D, opts.DecimalSeparator)
                                    Else
                                        Dim band As Nullable(Of Decimal) = KeepStoreFeedEngine.ShippingBandCost(bands, row.Weight)
                                        row.ShippingCost = If(band.HasValue, KeepStoreFeedEngine.MoneyWithTax(band.Value, cfg.IncludeTax, cfg.CarrierVat, opts.DecimalSeparator), "")
                                    End If
                                End If

                                If needImages Then
                                    For k As Integer = 1 To 4
                                        Dim value As Object = reader.GetValue(reader.GetOrdinal("Img" & k.ToString(Invariant)))
                                        row.ImageUrls((k - 1) * 2) = ImageUrl(value, cfg.Domain, True)
                                        row.ImageUrls((k - 1) * 2 + 1) = ImageUrl(value, cfg.Domain, False)
                                    Next
                                End If

                                If KeepStoreFeedEngine.SkipReason(row, opts) <> "" Then
                                    skipped += 1
                                    Continue While
                                End If

                                rowCount += 1
                                If rowCount > KeepStoreFeedEngine.MaxRows Then Throw New KeepStoreFeedException("TETTO_RIGHE")
                                If stopwatch.Elapsed.TotalSeconds > KeepStoreFeedEngine.MaxSeconds Then Throw New KeepStoreFeedException("TETTO_TEMPO")
                                If (rowCount And 255) = 0 AndAlso fs.Length > KeepStoreFeedEngine.MaxBytes Then Throw New KeepStoreFeedException("TETTO_BYTE")

                                If isXml Then
                                    xw.WriteStartElement(opts.XmlElement)
                                    For Each c As KeepStoreFeedColumn In columns
                                        xw.WriteElementString(c.Title, KeepStoreFeedEngine.StripInvalidXmlChars(KeepStoreFeedEngine.ColumnValue(c, row, ctx, opts)))
                                    Next
                                    xw.WriteEndElement()
                                Else
                                    Dim values As New List(Of String)()
                                    For Each c As KeepStoreFeedColumn In columns
                                        values.Add(KeepStoreFeedEngine.ColumnValue(c, row, ctx, opts))
                                    Next
                                    textWriter.WriteLine(KeepStoreFeedEngine.DelimitedLine(values, opts))
                                End If
                            End While
                        End Using

                        If isXml Then
                            xw.WriteEndElement()
                            xw.WriteEndDocument()
                            xw.Flush()
                        Else
                            textWriter.Flush()
                        End If
                    Finally
                        If xw IsNot Nothing Then xw.Close()
                        If textWriter IsNot Nothing Then textWriter.Dispose()
                    End Try
                End Using
            End Using
        End Using
    End Sub

    ' ---------- risposta ----------

    Private Shared Sub Plain(ByVal context As HttpContext, ByVal status As Integer, ByVal text As String, Optional ByVal retryAfter As Integer = 0)
        Dim r As HttpResponse = context.Response
        r.Clear()
        r.StatusCode = status
        r.TrySkipIisCustomErrors = True
        r.Cache.SetCacheability(HttpCacheability.NoCache)
        r.Cache.SetNoStore()
        r.AppendHeader("X-Robots-Tag", "noindex, nofollow")
        If retryAfter > 0 Then r.AppendHeader("Retry-After", retryAfter.ToString(Invariant))
        If status = 405 Then r.AppendHeader("Allow", "GET, HEAD")
        r.ContentType = "text/plain"
        r.Charset = "utf-8"
        If Not String.Equals(context.Request.HttpMethod, "HEAD", StringComparison.OrdinalIgnoreCase) Then r.Write(text)
    End Sub

    Private Shared Sub TouchRequest(ByVal cfg As KeepStoreFeedConfig)
        Dim due As Boolean = False
        SyncLock StateLock
            Dim last As DateTime
            If Not LastStamp.TryGetValue(cfg.Token, last) OrElse (DateTime.UtcNow - last).TotalMinutes >= RequestStampMinutes Then
                If LastStamp.Count >= FailureTableMax Then LastStamp.Clear()
                LastStamp(cfg.Token) = DateTime.UtcNow
                due = True
            End If
        End SyncLock
        If due Then WriteState(cfg, 0, 0, "", True)
    End Sub

    Public Shared Sub Serve(ByVal context As HttpContext)
        Dim method As String = context.Request.HttpMethod
        Dim isHead As Boolean = String.Equals(method, "HEAD", StringComparison.OrdinalIgnoreCase)
        If Not isHead AndAlso Not String.Equals(method, "GET", StringComparison.OrdinalIgnoreCase) Then
            Plain(context, 405, "Metodo non ammesso")
            Return
        End If

        Dim rawToken As String = context.Request.QueryString("c")
        If rawToken Is Nothing Then rawToken = ""
        Dim token As String = rawToken.Trim().ToUpperInvariant()
        If Not KeepStoreFeedEngine.IsValidToken(token) Then
            Plain(context, 404, "Feed non disponibile")
            Return
        End If

        Dim cfg As KeepStoreFeedConfig = Nothing
        Dim tooMany As Boolean = False
        Try
            cfg = GetConfig(token, tooMany)
        Catch ex As Exception
            Plain(context, 503, "Servizio non disponibile", 30)
            Return
        End Try
        If tooMany Then
            Plain(context, 429, "Troppe richieste", 5)
            Return
        End If
        If cfg Is Nothing OrElse Not cfg.Enabled Then
            Plain(context, 404, "Feed non disponibile")
            Return
        End If

        ' Se la richiesta e gia legata a un'azienda (host valido), deve essere quella del feed.
        Try
            Dim tenant As StorefrontSeoTenantIdentity = StorefrontSeoTenantContext.Resolve(context)
            If tenant IsNot Nothing AndAlso cfg.CompanyId > 0 AndAlso tenant.CompanyId <> cfg.CompanyId Then
                Plain(context, 404, "Feed non disponibile")
                Return
            End If
        Catch
        End Try

        Dim preview As Boolean = String.Equals(context.Request.QueryString("anteprima"), "1", StringComparison.Ordinal)
        Dim path As String = FinalPath(cfg)
        If Not isHead Then
            Try
                EnsureFresh(cfg)
            Catch
            End Try
        End If
        If Not preview Then TouchRequest(cfg)

        Dim maxAge As Double = Math.Max(24.0R * 60.0R, 3.0R * cfg.Options.MinutesCache)
        If Not File.Exists(path) OrElse (DateTime.UtcNow - File.GetLastWriteTimeUtc(path)).TotalMinutes > maxAge Then
            Plain(context, 503, "Feed in preparazione", 30)
            Return
        End If

        Try
            If preview Then
                SendPreview(context, cfg, path, isHead)
            Else
                SendFile(context, cfg, path, isHead)
            End If
        Catch ex As IOException
            Plain(context, 503, "Feed in preparazione", 30)
        End Try
    End Sub

    ' Anteprima per il gestionale: le prime righe del file pronto (mai una generazione in piu), al massimo 32 KB, decodificate con la codifica del file e riscritte in utf-8.
    ' Nessun ETag/304 (e la testa, non il file), nessuna registrazione di richiesta. X-Feed-Generato dichiara l'ora del file mostrato.
    Private Shared Sub SendPreview(ByVal context As HttpContext, ByVal cfg As KeepStoreFeedConfig, ByVal path As String, ByVal isHead As Boolean)
        Dim r As HttpResponse = context.Response
        Dim isXml As Boolean = (KeepStoreFeedEngine.NormalizeFormat(cfg.Options.Format) = "xml")
        Dim enc As Encoding = KeepStoreFeedEngine.ResolveEncoding(If(isXml, "utf-8", cfg.Options.EncodingName))
        Dim maxLines As Integer = If(isXml, KeepStoreFeedEngine.PreviewXmlLines, KeepStoreFeedEngine.PreviewTextLines + If(cfg.Options.Header, 1, 0))
        Dim buffer(KeepStoreFeedEngine.PreviewMaxBytes - 1) As Byte
        Dim total As Integer = 0
        Dim written As DateTime
        Dim fileLength As Long
        Using fs As New FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite Or FileShare.Delete)
            written = New FileInfo(path).LastWriteTimeUtc
            fileLength = fs.Length
            While total < buffer.Length
                Dim n As Integer = fs.Read(buffer, total, buffer.Length - total)
                If n <= 0 Then Exit While
                total += n
            End While
        End Using
        Dim cutByBytes As Boolean = (fileLength > total)
        Dim body As String = KeepStoreFeedEngine.PreviewText(enc.GetString(buffer, 0, total), maxLines, cutByBytes)

        r.Clear()
        r.TrySkipIisCustomErrors = True
        r.Cache.SetCacheability(HttpCacheability.NoCache)
        r.Cache.SetNoStore()
        r.AppendHeader("X-Robots-Tag", "noindex, nofollow")
        r.AppendHeader("X-Feed-Generato", written.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", Invariant))
        r.StatusCode = 200
        r.ContentType = "text/plain; charset=utf-8"
        If isHead Then
            r.SuppressContent = True
            Return
        End If
        r.Write(body)
    End Sub

    Private Shared Sub SendFile(ByVal context As HttpContext, ByVal cfg As KeepStoreFeedConfig, ByVal path As String, ByVal isHead As Boolean)
        Dim r As HttpResponse = context.Response
        Using fs As New FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite Or FileShare.Delete)
            Dim info As New FileInfo(path)
            Dim lastWrite As DateTime = info.LastWriteTimeUtc
            Dim length As Long = fs.Length
            Dim etag As String = KeepStoreFeedEngine.WeakETag(lastWrite.Ticks, length)

            r.Clear()
            r.TrySkipIisCustomErrors = True
            r.Cache.SetCacheability(HttpCacheability.Private)
            r.Cache.SetMaxAge(TimeSpan.FromSeconds(ConfigCacheSeconds))
            r.AppendHeader("ETag", etag)
            r.AppendHeader("Last-Modified", lastWrite.ToString("R", Invariant))
            r.AppendHeader("X-Robots-Tag", "noindex, nofollow")

            Dim ifNone As String = context.Request.Headers("If-None-Match")
            Dim notModified As Boolean = False
            If Not String.IsNullOrEmpty(ifNone) Then
                For Each part As String In ifNone.Split(","c)
                    If part.Trim() = etag OrElse part.Trim() = "*" Then notModified = True
                Next
            Else
                Dim ims As String = context.Request.Headers("If-Modified-Since")
                Dim since As DateTime
                If Not String.IsNullOrEmpty(ims) AndAlso DateTime.TryParse(ims, Invariant, DateTimeStyles.AdjustToUniversal Or DateTimeStyles.AssumeUniversal, since) Then
                    notModified = (lastWrite.AddTicks(-(lastWrite.Ticks Mod TimeSpan.TicksPerSecond)) <= since)
                End If
            End If
            If notModified Then
                r.StatusCode = 304
                r.SuppressContent = True
                Return
            End If

            r.StatusCode = 200
            r.ContentType = KeepStoreFeedEngine.ContentType(cfg.Options.Format, cfg.Options.EncodingName)
            r.AppendHeader("Content-Length", length.ToString(Invariant))
            If isHead Then
                r.SuppressContent = True
                Return
            End If
            r.BufferOutput = False
            Dim buffer(65535) As Byte
            Dim read As Integer = fs.Read(buffer, 0, buffer.Length)
            While read > 0
                r.OutputStream.Write(buffer, 0, read)
                read = fs.Read(buffer, 0, buffer.Length)
            End While
        End Using
    End Sub
End Class
