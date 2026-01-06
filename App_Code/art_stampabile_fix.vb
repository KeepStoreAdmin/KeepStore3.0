Option Strict On

' Fix compilazione: art_stampabile.aspx.vb usa ArticoliId, ma nel file non risulta dichiarato.
' Aggiungiamo la property tramite Partial Class, senza toccare il code-behind esistente.
Partial Class art_stampabile

    Protected ReadOnly Property ArticoliId As Integer
        Get
            Dim id As Integer = 0
            Try
                Dim qs As String = ""
                If Request IsNot Nothing AndAlso Request.QueryString("id") IsNot Nothing Then
                    qs = Request.QueryString("id").ToString()
                End If
                Integer.TryParse(qs, id)
            Catch
                id = 0
            End Try
            Return id
        End Get
    End Property

End Class
