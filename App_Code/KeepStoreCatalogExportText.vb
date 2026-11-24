Option Strict On
Option Explicit On

Imports System
Imports System.Text.RegularExpressions
Imports System.Web

' Testi del listino (CATALOG-DOWNLOAD-1D). La descrizione dell'azienda (aziende.Descrizione) compare nella prima pagina del PDF e dell'Excel: e testo del
' database scritto da una persona, quindi si decodifica (anche le entita doppie), si tolgono i tag, i caratteri di controllo e gli spazi in eccesso, e si scarta
' se e solo un indirizzo web. Mai eccezioni: in caso di errore la descrizione e vuota e la prima pagina resta com'era. Nessuna dipendenza da altre classi.
Public NotInheritable Class CatalogExportText
    Private Sub New()
    End Sub

    Private Const MaxLength As Integer = 255

    Public Shared Function Description(ByVal raw As String) As String
        If String.IsNullOrWhiteSpace(raw) Then Return ""
        Try
            Dim text As String = HttpUtility.HtmlDecode(raw)
            ' Prima i tag (dopo la decodifica: "&lt;b&gt;" diventa "<b>" e si toglie), poi i controlli, poi gli spazi.
            text = Regex.Replace(text, "<[^>]*>", " ")
            text = Regex.Replace(text, "[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]", " ")
            text = Regex.Replace(text, "\s+", " ").Trim()
            If text.StartsWith("http", StringComparison.OrdinalIgnoreCase) AndAlso Regex.IsMatch(text, "^https?://\S*$", RegexOptions.IgnoreCase) Then Return ""
            If text.Length > MaxLength Then
                Dim keep As Integer = MaxLength - 3
                If Char.IsHighSurrogate(text(keep - 1)) Then keep -= 1
                text = text.Substring(0, keep).TrimEnd() & "..."
            End If
            Return text
        Catch
            Return ""
        End Try
    End Function
End Class
