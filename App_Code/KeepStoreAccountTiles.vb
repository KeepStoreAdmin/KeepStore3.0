Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Net
Imports System.Text

' KS-MYACCOUNT-1B. Regole PURE (nessun accesso a database o sessione) dei riquadri del pannello dell'account.
' I tipi documento sono DATI (tabella tipodocumenti): qui non c'e nessun id fisso. I riquadri "in arrivo" non hanno indirizzo e non sono collegamenti.
Public NotInheritable Class AccountDocType
    Public Property Id As Integer
    Public Property Description As String
    ' True = tipo ordine (impegna la merce).
    Public Property IsOrder As Boolean
    ' Documenti di questo tipo dell'utente nell'azienda dell'host.
    Public Property Count As Integer
End Class

Public NotInheritable Class AccountTile
    Public Property Key As String = ""
    Public Property Label As String = ""
    ' "" = nessun collegamento.
    Public Property Url As String = ""
    Public Property IconKey As String = ""
    Public Property Enabled As Boolean
    ' -1 = nessun conteggio da mostrare.
    Public Property Count As Integer = -1
End Class

Public Module KeepStoreAccountTiles
    ' Come la colonna tipodocumenti.Descrizione.
    Public Const MaxLabelLength As Integer = 50
    Public Const SoonText As String = "In arrivo"

    Private Function NewTile(ByVal key As String, ByVal label As String, ByVal url As String, ByVal iconKey As String, ByVal enabled As Boolean) As AccountTile
        Dim tile As New AccountTile()
        tile.Key = key
        tile.Label = label
        tile.Url = url
        tile.IconKey = iconKey
        tile.Enabled = enabled
        Return tile
    End Function

    Private Function CleanLabel(ByVal raw As String) As String
        If raw Is Nothing Then Return "Documenti"
        Dim sb As New StringBuilder(raw.Length)
        Dim lastSpace As Boolean = True
        For Each ch As Char In raw
            If Char.IsWhiteSpace(ch) OrElse Char.IsControl(ch) Then
                If Not lastSpace Then sb.Append(" "c)
                lastSpace = True
            Else
                sb.Append(ch)
                lastSpace = False
            End If
        Next
        Dim label As String = sb.ToString().Trim()
        If label.Length = 0 Then label = "Documenti"
        If label.Length > MaxLabelLength Then
            label = label.Substring(0, MaxLabelLength - 3) & "..."
        End If
        Return label
    End Function

    Public Function Build(ByVal docTypes As IEnumerable(Of AccountDocType)) As List(Of AccountTile)
        Dim result As New List(Of AccountTile)()
        Dim seen As New HashSet(Of Integer)()
        Dim hasOrder As Boolean = False
        If docTypes IsNot Nothing Then
            For Each t As AccountDocType In docTypes
                If t Is Nothing OrElse t.Id <= 0 Then Continue For
                If Not seen.Add(t.Id) Then Continue For
                Dim count As Integer = Math.Max(0, t.Count)
                Dim label As String = CleanLabel(t.Description)
                If t.IsOrder AndAlso Not hasOrder Then
                    ' Il primo tipo ordine c'e sempre, anche senza ordini.
                    hasOrder = True
                    label = "I miei ordini"
                ElseIf count <= 0 Then
                    Continue For
                End If
                Dim tile As AccountTile = NewTile("doc" & t.Id.ToString(Globalization.CultureInfo.InvariantCulture), label,
                                                  "documenti.aspx?t=" & t.Id.ToString(Globalization.CultureInfo.InvariantCulture),
                                                  If(t.IsOrder, "orders", "document"), True)
                tile.Count = count
                result.Add(tile)
            Next
        End If
        ' Senza un tipo ordine noto (dati non disponibili) resta il collegamento alla lista: la pagina sceglie il tipo.
        If Not hasOrder Then result.Insert(0, NewTile("orders", "I miei ordini", "documenti.aspx", "orders", True))
        result.Add(NewTile("profile", "Dati account", "my-account-edit.aspx", "user", True))
        result.Add(NewTile("addresses", "Indirizzi", "my-account-address.aspx", "pin", True))
        result.Add(NewTile("wishlist", "Preferiti", "wishlist.aspx", "heart", True))
        result.Add(NewTile("password", "Password", "password.aspx", "lock", True))
        result.Add(NewTile("help", "Assistenza", "Contattaci.aspx", "chat", True))
        result.Add(NewTile("logout", "Esci", "logout.aspx", "exit", True))
        ' Funzioni non ancora sviluppate: visibili ma non cliccabili.
        result.Add(NewTile("returns", "Resi e riparazioni", "", "returns", False))
        result.Add(NewTile("tickets", "Ticket di assistenza", "", "ticket", False))
        result.Add(NewTile("reviews", "Le mie recensioni", "", "star", False))
        result.Add(NewTile("savedcarts", "Carrelli salvati", "", "cart", False))
        result.Add(NewTile("points", "Raccolta punti", "", "gift", False))
        Return result
    End Function

    ' Testo sotto il nome del riquadro di un tipo documento ("" = niente).
    Public Function CountText(ByVal isOrder As Boolean, ByVal count As Integer) As String
        If count < 0 Then Return ""
        If isOrder Then
            If count = 0 Then Return "Nessun ordine"
            If count = 1 Then Return "1 ordine"
            Return count.ToString(Globalization.CultureInfo.InvariantCulture) & " ordini"
        End If
        If count = 0 Then Return ""
        If count = 1 Then Return "1 documento"
        Return count.ToString(Globalization.CultureInfo.InvariantCulture) & " documenti"
    End Function

    ' Destinazione dell'avviso "da pagare": un solo ordine -> il suo dettaglio; piu ordini -> la lista; nessuno -> "".
    Public Function PayNoticeUrl(ByVal payableIds As IEnumerable(Of Integer), ByVal orderTypeId As Integer) As String
        Dim valid As New List(Of Integer)()
        If payableIds IsNot Nothing Then
            For Each id As Integer In payableIds
                If id > 0 Then valid.Add(id)
            Next
        End If
        If valid.Count = 0 Then Return ""
        If valid.Count = 1 Then
            Return "documentidettaglio.aspx?id=" & valid(0).ToString(Globalization.CultureInfo.InvariantCulture) & "#ksPayNow"
        End If
        If orderTypeId > 0 Then Return "documenti.aspx?t=" & orderTypeId.ToString(Globalization.CultureInfo.InvariantCulture)
        Return "documenti.aspx"
    End Function

    Private Function IconSvg(ByVal iconKey As String) As String
        Dim path As String
        Select Case iconKey
            Case "orders" : path = "<path d=""M4 7h16l-1.5 9h-13z""/><path d=""M8 7V5a4 4 0 0 1 8 0v2""/>"
            Case "document" : path = "<path d=""M7 3h7l4 4v14H7z""/><path d=""M14 3v4h4""/><path d=""M10 12h5M10 16h5""/>"
            Case "user" : path = "<circle cx=""12"" cy=""8"" r=""4""/><path d=""M4 21c0-4 4-6 8-6s8 2 8 6""/>"
            Case "pin" : path = "<path d=""M12 21s7-6.5 7-12a7 7 0 0 0-14 0c0 5.5 7 12 7 12z""/><circle cx=""12"" cy=""9"" r=""2.5""/>"
            Case "heart" : path = "<path d=""M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z""/>"
            Case "lock" : path = "<rect x=""5"" y=""11"" width=""14"" height=""9""/><path d=""M8 11V8a4 4 0 0 1 8 0v3""/>"
            Case "chat" : path = "<path d=""M4 5h16v11H9l-5 4z""/>"
            Case "exit" : path = "<path d=""M10 4H5v16h5""/><path d=""M14 8l4 4-4 4M18 12H9""/>"
            Case "returns" : path = "<path d=""M9 7L5 11l4 4""/><path d=""M5 11h9a5 5 0 0 1 0 10h-3""/>"
            Case "ticket" : path = "<path d=""M4 8h16v3a2 2 0 0 0 0 4v3H4v-3a2 2 0 0 0 0-4z""/>"
            Case "star" : path = "<path d=""M12 4l2.5 5 5.5.8-4 3.9.9 5.5-4.9-2.6-4.9 2.6.9-5.5-4-3.9 5.5-.8z""/>"
            Case "cart" : path = "<path d=""M3 5h3l2 10h10l2-7H7""/><circle cx=""10"" cy=""19"" r=""1.5""/><circle cx=""17"" cy=""19"" r=""1.5""/>"
            Case Else : path = "<rect x=""4"" y=""9"" width=""16"" height=""11""/><path d=""M4 9h16M12 9v11M12 9c-3 0-5-1-5-3s3-2 5 3c2-5 5-5 5-3s-2 3-5 3""/>"
        End Select
        Return "<svg class=""ks-account-tile__icon"" viewBox=""0 0 24 24"" width=""32"" height=""32"" fill=""none"" stroke=""currentColor"" stroke-width=""1.6"" aria-hidden=""true"" focusable=""false"">" & path & "</svg>"
    End Function

    ' HTML dei riquadri attivi (enabled = True) o di quelli "in arrivo" (False). Ogni testo e ogni indirizzo sono codificati qui.
    Public Function RenderHtml(ByVal tiles As IEnumerable(Of AccountTile), ByVal enabled As Boolean) As String
        If tiles Is Nothing Then Return ""
        Dim sb As New StringBuilder()
        For Each tile As AccountTile In tiles
            If tile Is Nothing OrElse tile.Enabled <> enabled Then Continue For
            Dim hint As String = If(enabled, CountText(String.Equals(tile.IconKey, "orders", StringComparison.Ordinal), tile.Count), SoonText)
            Dim inner As String = IconSvg(tile.IconKey) & "<span class=""ks-account-tile__label"">" & WebUtility.HtmlEncode(If(tile.Label, "")) & "</span>"
            If hint.Length > 0 Then inner &= "<span class=""ks-account-tile__hint"">" & WebUtility.HtmlEncode(hint) & "</span>"
            If tile.Enabled AndAlso Not String.IsNullOrEmpty(tile.Url) Then
                sb.Append("<li><a class=""ks-account-tile"" href=""").Append(WebUtility.HtmlEncode(tile.Url)).Append(""">").Append(inner).Append("</a></li>")
            Else
                sb.Append("<li><span class=""ks-account-tile is-soon"">").Append(inner).Append("</span></li>")
            End If
        Next
        If sb.Length = 0 Then Return ""
        Return "<ul class=""ks-account-tiles" & If(enabled, "", " is-soon-group") & """>" & sb.ToString() & "</ul>"
    End Function
End Module
