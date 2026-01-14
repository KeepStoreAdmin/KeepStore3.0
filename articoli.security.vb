Imports System
Imports System.Web

Partial Class articoli

    ' WhatsApp share helpers (URL-encoded and attribute-safe)
    Protected Function GetWhatsAppShareUrl(descrizione As Object, id As Object, tcid As Object) As String
        Dim descr As String = Convert.ToString(descrizione)
        Dim host As String = Convert.ToString(Session("AziendaUrl"))
        Dim baseUrl As String = "https://" & host & "/articolo.aspx?id=" & Convert.ToString(id) & "&TCid=" & Convert.ToString(tcid)
        Dim txt As String = descr & " - " & baseUrl
        Dim url As String = "https://wa.me/?text=" & HttpUtility.UrlEncode(txt)
        Return HttpUtility.HtmlAttributeEncode(url)
    End Function

    Protected Function GetWhatsAppIconUrl() As String
        Dim host As String = Convert.ToString(Session("AziendaUrl"))
        Dim url As String = "https://" & host & "/Public/Images/WhatsApp-Symbolo.png"
        Return HttpUtility.HtmlAttributeEncode(url)
    End Function

End Class
