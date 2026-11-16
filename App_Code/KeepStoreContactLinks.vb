Option Strict On
Option Explicit On

Imports System
Imports System.Text
Imports System.Text.RegularExpressions

' Collegamenti tel: e mailto: costruiti dai dati dell'azienda (campi liberi del gestionale), in UN solo punto per piede, testata e pagina Contattaci.
' Un valore che non e UN solo numero o UN solo indirizzo plausibile non diventa mai un href: chi lo mostra scrive il testo senza collegamento.
' Funzioni pure (nessun accesso a sessione, database o richiesta), provate compilando questo stesso file (Tools/Test-ContactLinks.ps1).
Public NotInheritable Class KeepStoreContactLinks

    Private Shared ReadOnly MailPattern As New Regex("^[A-Za-z0-9](?:[A-Za-z0-9._+\-]{0,62}[A-Za-z0-9])?@(?:[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,24}\z", RegexOptions.CultureInvariant)
    ' Lo "0 facoltativo" tra parentesi dopo il prefisso internazionale, con o senza spazi dentro: la cifra e ambigua, quindi nessun collegamento.
    Private Shared ReadOnly ZeroGroup As New Regex("\(\s*0\s*\)", RegexOptions.CultureInvariant)

    Private Sub New()
    End Sub

    ' Solo cifre ASCII, separatori usuali (spazio . - parentesi) e un "+" iniziale; da 6 a 15 cifre, non tutte zero.
    ' Tutto il resto ("dalle 9 alle 18", due numeri separati da "/", lettere, cifre Unicode, "(0)") non diventa mai un attributo href.
    Public Shared Function BuildTelHref(ByVal phone As String) As String
        Dim raw As String = If(phone, String.Empty).Trim()
        If raw.Length = 0 OrElse raw.Length > 40 Then Return String.Empty
        If ZeroGroup.IsMatch(raw) Then Return String.Empty
        Dim digits As New StringBuilder()
        Dim nonZero As Boolean = False
        For i As Integer = 0 To raw.Length - 1
            Dim c As Char = raw(i)
            If c >= "0"c AndAlso c <= "9"c Then
                digits.Append(c)
                If c <> "0"c Then nonZero = True
            ElseIf c = "+"c Then
                If i <> 0 Then Return String.Empty
                digits.Append(c)
            ElseIf c = " "c OrElse c = "."c OrElse c = "-"c OrElse c = "("c OrElse c = ")"c Then
                ' separatore ignorato
            Else
                Return String.Empty
            End If
        Next
        Dim number As String = digits.ToString()
        Dim count As Integer = number.Length - If(number.StartsWith("+", StringComparison.Ordinal), 1, 0)
        If count < 6 OrElse count > 15 OrElse Not nonZero Then Return String.Empty
        Return "tel:" & number
    End Function

    ' Un solo indirizzo semplice (niente parametri, elenchi, spazi, a capo, percentuali, cancelletti, punti consecutivi).
    Public Shared Function BuildMailtoHref(ByVal email As String) As String
        Dim raw As String = If(email, String.Empty).Trim()
        If raw.Length = 0 OrElse raw.Length > 254 Then Return String.Empty
        If Not MailPattern.IsMatch(raw) Then Return String.Empty
        If raw.Contains("..") Then Return String.Empty
        Return "mailto:" & raw
    End Function

End Class
