Imports System
Imports System.Web

' NOTE:
' - Questo file contiene helper "UI-only" usati dal markup di articoli.aspx.
' - Serve a mantenere il code-behind principale più pulito e a evitare duplicazioni.
Partial Class Articoli

    ' Restituisce la base url del sito:
    ' 1) se presente, usa Session("AziendaUrl") (con o senza schema)
    ' 2) fallback: Request.Url (schema + authority della request corrente)
    Private Function GetSiteBaseUrl() As String
        Dim s As String = ""
        Try
            s = Convert.ToString(Session("AziendaUrl"))
        Catch
            s = ""
        End Try

        s = If(s, "").Trim()

        If s <> "" Then
            ' Normalizza: aggiunge schema se manca e rimuove slash finale
            If Not (s.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse
                    s.StartsWith("https://", StringComparison.OrdinalIgnoreCase)) Then
                s = "https://" & s
            End If

            s = s.TrimEnd("/"c)
            Return s
        End If

        ' Fallback robusto (usa lo schema reale della request corrente)
        Dim req As HttpRequest = HttpContext.Current.Request
        Dim baseUrl As String = req.Url.GetLeftPart(UriPartial.Authority)
        Return baseUrl.TrimEnd("/"c)
    End Function

    ' WhatsApp share helpers (URL-encoded e sicuri per attributo HTML)
    Protected Function GetWhatsAppShareUrl(descrizione As Object, id As Object, tcid As Object) As String
        Dim descr As String = Convert.ToString(descrizione)
        Dim idStr As String = Convert.ToString(id)
        Dim tcidStr As String = Convert.ToString(tcid)

        Dim siteBase As String = GetSiteBaseUrl()
        Dim articoloPath As String = Me.ResolveUrl("~/articolo.aspx")
        Dim articoloUrl As String = siteBase & articoloPath & "?id=" & idStr & "&TCid=" & tcidStr

        Dim txt As String = descr & " - " & articoloUrl
        Dim url As String = "https://wa.me/?text=" & HttpUtility.UrlEncode(txt)

        Return HttpUtility.HtmlAttributeEncode(url)
    End Function

    Protected Function GetWhatsAppIconUrl() As String
        ' Icona locale (non dipende dal tema) - restituita come url relativa
        Dim url As String = Me.ResolveUrl("~/Public/Images/WhatsApp-Symbolo.png")
        Return HttpUtility.HtmlAttributeEncode(url)
    End Function

End Class
