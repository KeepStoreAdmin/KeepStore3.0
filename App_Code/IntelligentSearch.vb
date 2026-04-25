Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Linq
Imports System.Text
Imports System.Text.RegularExpressions
Imports MySql.Data.MySqlClient

' Ricerca "AI-like" senza nuove tabelle.
Public Module IntelligentSearch

    Private ReadOnly TokenRx As New Regex("[^\p{L}\p{Nd}]+", RegexOptions.Compiled)

    Public Function NormalizeQuery(ByVal q As String, Optional maxLen As Integer = 80) As String
        If q Is Nothing Then Return String.Empty
        Dim s As String = q.Trim()
        If s.Length > maxLen Then s = s.Substring(0, maxLen)
        s = s.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ")
        s = Regex.Replace(s, "\s{2,}", " ").Trim()
        Return s
    End Function

    Public Function Tokenize(ByVal q As String, Optional maxTokens As Integer = 6) As List(Of String)
        Dim s As String = NormalizeQuery(q, 120)
        Dim out As New List(Of String)()
        If String.IsNullOrWhiteSpace(s) Then Return out
        Dim stopWords As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {"il", "la", "lo", "le", "gli", "un", "una", "uno", "di", "da", "a", "e", "o", "in", "con", "per", "del", "della", "dello", "dei", "degli", "prodotto", "prodotti", "cerca", "cerco", "trova", "voglio", "serve", "servono", "mi", "buon", "buona"}

        Dim parts As String() = TokenRx.Split(s)
        For Each p As String In parts
            If out.Count >= maxTokens Then Exit For
            Dim t As String = If(p, "").Trim()
            If t.Length < 2 Then Continue For
            If stopWords.Contains(t) Then Continue For
            out.Add(t)
        Next

        Return out
    End Function

    Public Function ExpandSearchTokens(ByVal q As String, Optional maxTokens As Integer = 10) As List(Of String)
        Dim expanded As New List(Of String)()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        For Each token As String In Tokenize(q, maxTokens)
            AddExpandedToken(expanded, seen, token)
            AddExpandedToken(expanded, seen, SingularizeToken(token))
            For Each synonym As String In SynonymsFor(token)
                AddExpandedToken(expanded, seen, synonym)
            Next
            If expanded.Count >= maxTokens Then Exit For
        Next
        Return expanded.Take(Math.Max(1, maxTokens)).ToList()
    End Function

    Private Sub AddExpandedToken(ByVal target As List(Of String), ByVal seen As HashSet(Of String), ByVal value As String)
        If target Is Nothing OrElse seen Is Nothing Then Return
        Dim token As String = If(value, String.Empty).Trim().ToLowerInvariant()
        If token.Length < 2 Then Return
        If seen.Contains(token) Then Return
        seen.Add(token)
        target.Add(token)
    End Sub

    Private Function SingularizeToken(ByVal value As String) As String
        Dim token As String = If(value, String.Empty).Trim().ToLowerInvariant()
        If token.Length > 4 AndAlso (token.EndsWith("i", StringComparison.OrdinalIgnoreCase) OrElse token.EndsWith("e", StringComparison.OrdinalIgnoreCase)) Then
            Return token.Substring(0, token.Length - 1)
        End If
        Return token
    End Function

    Private Function SynonymsFor(ByVal value As String) As List(Of String)
        Dim token As String = If(value, String.Empty).Trim().ToLowerInvariant()
        Dim result As New List(Of String)()

        Select Case token
            Case "smartphone", "cellulare", "cellulari", "telefono", "telefoni", "telefonia"
                result.AddRange(New String() {"smartphone", "cellulare", "telefono", "galaxy", "iphone"})
            Case "pc", "computer", "desktop"
                result.AddRange(New String() {"pc", "computer", "desktop"})
            Case "portatile", "portatili", "notebook", "laptop"
                result.AddRange(New String() {"notebook", "portatile", "laptop", "computer"})
            Case "monitor", "schermo", "display"
                result.AddRange(New String() {"monitor", "schermo", "display"})
            Case "toner", "cartuccia", "cartucce", "inchiostro", "drum", "tamburo"
                result.AddRange(New String() {"toner", "cartuccia", "inchiostro", "drum", "tamburo", "stampante"})
            Case "stampante", "stampanti", "printer", "ufficio"
                result.AddRange(New String() {"stampante", "printer", "toner", "cartuccia", "laser"})
            Case "cavo", "cavi"
                result.AddRange(New String() {"cavo", "hdmi", "usb", "adattatore"})
            Case "usb", "typec"
                result.AddRange(New String() {"usb", "usb c", "type c", "adattatore", "hub"})
            Case "hdmi"
                result.AddRange(New String() {"hdmi", "cavo", "adattatore"})
            Case "alimentatore", "caricatore", "charger", "power"
                result.AddRange(New String() {"alimentatore", "caricatore", "charger", "power", "usb c"})
            Case "ricondizionato", "ricondizionati", "refurbished", "usato"
                result.AddRange(New String() {"ricondizionato", "ricondizionati", "refurbished", "usato"})
            Case "memoria", "ram", "storage", "archiviazione"
                result.AddRange(New String() {"memoria", "ram", "gb", "storage", "ssd"})
            Case "gaming", "gamer"
                result.AddRange(New String() {"gaming", "gamer"})
        End Select

        Return result
    End Function

    ' Costruisce un comando parametricamente sicuro.
    ' Ranking semplice: match su Codice/Ean > descrizioni > tag.
    Public Function BuildRankedSearchCommand(ByVal conn As MySqlConnection,
                                             ByVal nListino As Integer,
                                             ByVal q As String,
                                             Optional limit As Integer = 48) As MySqlCommand
        If conn Is Nothing Then Throw New ArgumentNullException("conn")

        Dim query As String = NormalizeQuery(q, 120)
        Dim qExact As String = query
        Dim qLike As String = "%" & KeepStoreSecurity.SqlEscapeLike(query) & "%"
        Dim tokens As List(Of String) = Tokenize(query, 6)

        Dim sb As New StringBuilder()
        sb.AppendLine("SELECT")
        sb.AppendLine("  a.id, a.Codice, a.Ean, a.Descrizione1, a.Descrizione2, a.Img1,")
        sb.AppendLine("  l.Prezzo, l.PrezzoIvato,")
        sb.AppendLine("  (CASE")
        sb.AppendLine("     WHEN a.Codice = @qExact THEN 1000")
        sb.AppendLine("     WHEN a.Ean   = @qExact THEN 950")
        sb.AppendLine("     WHEN a.Codice LIKE CONCAT(@qExact, '%') THEN 700")
        sb.AppendLine("     WHEN a.Descrizione1 LIKE CONCAT(@qExact, '%') THEN 220")
        sb.AppendLine("     WHEN a.Descrizione1 LIKE @qLike THEN 160")
        sb.AppendLine("     WHEN a.Descrizione2 LIKE @qLike THEN 120")
        sb.AppendLine("     WHEN t.Tag LIKE @qLike THEN 80")
        sb.AppendLine("     ELSE 0")
        sb.AppendLine("   END")

        For i As Integer = 0 To tokens.Count - 1
            sb.AppendLine("   + (CASE")
            sb.AppendLine("        WHEN a.Codice = @t" & i & " THEN 400")
            sb.AppendLine("        WHEN a.Codice LIKE CONCAT(@t" & i & ", '%') THEN 240")
            sb.AppendLine("        WHEN a.Descrizione1 LIKE CONCAT('%', @t" & i & ", '%') THEN 90")
            sb.AppendLine("        WHEN t.Tag LIKE CONCAT('%', @t" & i & ", '%') THEN 40")
            sb.AppendLine("        ELSE 0")
            sb.AppendLine("      END)")
        Next

        sb.AppendLine("  ) AS Score")
        sb.AppendLine("FROM articoli a")
        sb.AppendLine("LEFT JOIN articoli_listini l ON l.ArticoliId = a.id AND l.NListino = @nListino")
        sb.AppendLine("LEFT JOIN articoli_tag t ON t.ArticoliId = a.id")
        sb.AppendLine("WHERE a.Abilitato = 1")
        sb.AppendLine("  AND (")
        sb.AppendLine("       a.Codice = @qExact OR a.Ean = @qExact")
        sb.AppendLine("    OR a.Codice LIKE CONCAT(@qExact, '%')")
        sb.AppendLine("    OR a.Descrizione1 LIKE @qLike OR a.Descrizione2 LIKE @qLike")
        sb.AppendLine("    OR t.Tag LIKE @qLike")

        For i As Integer = 0 To tokens.Count - 1
            sb.AppendLine("    OR a.Codice = @t" & i)
            sb.AppendLine("    OR a.Codice LIKE CONCAT(@t" & i & ", '%')")
            sb.AppendLine("    OR a.Descrizione1 LIKE CONCAT('%', @t" & i & ", '%')")
            sb.AppendLine("    OR t.Tag LIKE CONCAT('%', @t" & i & ", '%')")
        Next

        sb.AppendLine("  )")
        sb.AppendLine("GROUP BY a.id")
        sb.AppendLine("ORDER BY Score DESC, a.Visite DESC, a.Codice ASC")
        sb.AppendLine("LIMIT @lim;")

        Dim cmd As MySqlCommand = conn.CreateCommand()
        cmd.CommandType = CommandType.Text
        cmd.CommandText = sb.ToString()

        cmd.Parameters.AddWithValue("@nListino", nListino)
        cmd.Parameters.AddWithValue("@qExact", qExact)
        cmd.Parameters.AddWithValue("@qLike", qLike)
        cmd.Parameters.AddWithValue("@lim", Math.Max(1, Math.Min(limit, 200)))

        For i As Integer = 0 To tokens.Count - 1
            cmd.Parameters.AddWithValue("@t" & i, tokens(i))
        Next

        Return cmd
    End Function

End Module
