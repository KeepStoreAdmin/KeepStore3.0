Option Strict On

' Fix compilazione: articolix.aspx usa nei databinding checkImg(...) e sotto_stringa(...).
' Se nel code-behind originario non esistono, li aggiungiamo qui via Partial Class.
Partial Class articolix

    Public Function checkImg(img1 As Object) As String
        Return ThemeManager.ProductImageUrl(img1)
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
