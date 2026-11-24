Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Text

' Nome del file scaricato dal listino (CATALOG-DOWNLOAD-FILENAME-1A): Listino_<azienda>_<gg-mm-aaaa>.<pdf|xls>.
' Il nome azienda e testo del database dentro un'intestazione HTTP: qui diventa ASCII sicuro per costruzione (solo A-Z a-z 0-9 e trattino, il resto e un
' solo trattino basso), senza mai lanciare eccezioni (un nome strano non deve bloccare il download). Nessuna dipendenza da altre classi: si prova da sola.
Public NotInheritable Class CatalogExportFileName
    Private Sub New()
    End Sub

    Private Const MaxCompanyLength As Integer = 40
    Private Const FallbackCompany As String = "KeepStore"

    ' La data e quella dello snapshot (non una seconda lettura dell'orologio), nel formato italiano gg-mm-aaaa scelto dal PO, con cultura invariante (nessun anno thai).
    Public Shared Function Build(ByVal companyName As String, ByVal generatedOn As Date, ByVal asExcel As Boolean) As String
        Dim stamp As String = generatedOn.ToString("dd-MM-yyyy", CultureInfo.InvariantCulture)
        Dim extension As String = If(asExcel, ".xls", ".pdf")
        Dim part As String = FallbackCompany
        Try
            part = CompanyPart(companyName)
        Catch
            part = FallbackCompany
        End Try
        Return "Listino_" & part & "_" & stamp & extension
    End Function

    Private Shared Function CompanyPart(ByVal raw As String) As String
        If String.IsNullOrWhiteSpace(raw) Then Return FallbackCompany

        ' Un surrogato isolato (testo troncato a meta di un'emoji) farebbe lanciare Normalize: diventa uno spazio.
        Dim safe As New StringBuilder(raw.Length)
        For Each ch As Char In raw
            If Char.IsSurrogate(ch) Then
                safe.Append(" "c)
            Else
                safe.Append(ch)
            End If
        Next

        ' Scomposizione di compatibilita (accenti, legature, lettere a tutta larghezza); i segni combinanti si tolgono, punti, virgole e apostrofi si eliminano.
        Dim folded As String = safe.ToString().Normalize(NormalizationForm.FormKD)
        Dim result As New StringBuilder(folded.Length)
        Dim pendingSeparator As Boolean = False
        For Each ch As Char In folded
            If CharUnicodeInfo.GetUnicodeCategory(ch) = UnicodeCategory.NonSpacingMark Then Continue For
            If ch = "."c OrElse ch = ","c OrElse ch = "'"c Then Continue For
            If IsAsciiAllowed(ch) Then
                If pendingSeparator AndAlso result.Length > 0 Then result.Append("_"c)
                pendingSeparator = False
                result.Append(ch)
            Else
                pendingSeparator = True
            End If
        Next

        Dim part As String = result.ToString()
        If part.Length > MaxCompanyLength Then part = part.Substring(0, MaxCompanyLength) 'NAME_CUT
        part = part.Trim("_"c, "-"c)
        If part.Length = 0 Then Return FallbackCompany
        Return part
    End Function

    Private Shared Function IsAsciiAllowed(ByVal ch As Char) As Boolean
        Return (ch >= "A"c AndAlso ch <= "Z"c) OrElse (ch >= "a"c AndAlso ch <= "z"c) OrElse (ch >= "0"c AndAlso ch <= "9"c) OrElse ch = "-"c
    End Function
End Class
