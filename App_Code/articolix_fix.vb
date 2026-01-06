Option Strict On

' Fix compilazione: articolix.aspx usa nei databinding checkImg(...) e sotto_stringa(...).
' Se nel code-behind originario non esistono, li aggiungiamo qui via Partial Class.
Partial Class articolix

    Public Function checkImg(img1 As Object) As String
        Dim s As String = ""
        If img1 IsNot Nothing Then
            s = img1.ToString().Trim()
        End If

        If String.IsNullOrWhiteSpace(s) Then
            Return "~/Public/images/nofoto.gif"
        End If

        ' Se è già un URL assoluto, lo lascio invariato
        If s.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse s.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return s
        End If

        ' Se è già un path assoluto/virtuale, lo lascio invariato
        If s.StartsWith("~/", StringComparison.Ordinal) OrElse s.StartsWith("/", StringComparison.Ordinal) Then
            Return s
        End If

        ' Default: cartella immagini articolo
        Return "~/Public/images/articoli/" & s
    End Function

    Public Function sotto_stringa(val As Object) As String
        Dim s As String = ""
        If val IsNot Nothing Then
            s = val.ToString()
        End If

        s = s.Trim()

        ' Taglio conservativo per descrizioni lunghe
        Const maxLen As Integer = 140
        If s.Length > maxLen Then
            s = s.Substring(0, maxLen - 3) & "..."
        End If

        Return s
    End Function

End Class
