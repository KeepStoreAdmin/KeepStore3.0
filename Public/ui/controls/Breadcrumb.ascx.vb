Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web

Partial Class Breadcrumb
    Inherits System.Web.UI.UserControl

    ' Titolo forzato (opzionale) impostabile dalla pagina
    Public Property TitleOverride As String

    ' Nasconde automaticamente il breadcrumb in Home
    Public Property HideOnHome As Boolean = True

    ' Mostra un titolo (H1 piccolo) sopra la trail
    Public Property ShowTitle As Boolean = True

    Protected Overrides Sub OnPreRender(ByVal e As EventArgs)
        MyBase.OnPreRender(e)

        If Me.Page Is Nothing OrElse Me.Page.Request Is Nothing OrElse Me.Page.Request.Url Is Nothing Then
            phBreadcrumb.Visible = False
            Return
        End If

        Dim path As String = String.Empty
        Try
            path = Me.Page.Request.Url.AbsolutePath
        Catch
            path = Me.Page.Request.Path
        End Try

        Dim pathLower As String = If(path, String.Empty).ToLowerInvariant()

        Dim isHome As Boolean = False
        If pathLower = "/" OrElse pathLower.EndsWith("/default.aspx") Then
            isHome = True
        End If

        If HideOnHome AndAlso isHome Then
            phBreadcrumb.Visible = False
            Return
        End If

        Dim title As String = If(TitleOverride, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(title) Then
            title = GetTitleFromPageOrPath(pathLower)
        End If

        If String.IsNullOrWhiteSpace(title) Then
            phBreadcrumb.Visible = False
            Return
        End If

        ' Title
        If ShowTitle Then
            litTitle.Text = "<h1 class=\"h6 mb-0 fw-semibold\">" & HttpUtility.HtmlEncode(title) & "</h1>"
        Else
            litTitle.Text = String.Empty
        End If

        ' Trail
        Dim sb As New StringBuilder()
        sb.Append("<li class=\"breadcrumb-item\"><a href=\"Default.aspx\">Home</a></li>")
        sb.Append("<li class=\"breadcrumb-item active\" aria-current=\"page\">")
        sb.Append(HttpUtility.HtmlEncode(title))
        sb.Append("</li>")
        litCrumbs.Text = sb.ToString()

        phBreadcrumb.Visible = True
    End Sub

    Private Function GetTitleFromPageOrPath(ByVal pathLower As String) As String
        Dim t As String = String.Empty

        Try
            t = If(Me.Page IsNot Nothing, Me.Page.Title, String.Empty)
        Catch
            t = String.Empty
        End Try

        If Not String.IsNullOrWhiteSpace(t) Then
            ' Rimuovi eventuale suffisso del sito (es: "Pagina - KeepStore")
            Try
                t = Regex.Replace(t, "\s*-\s*KeepStore\s*$", "", RegexOptions.IgnoreCase).Trim()
            Catch
            End Try

            If Not String.IsNullOrWhiteSpace(t) Then Return t
        End If

        Return GetFriendlyTitleFromPath(pathLower)
    End Function

    Private Function GetFriendlyTitleFromPath(ByVal pathLower As String) As String
        Dim file As String = String.Empty
        Try
            file = System.IO.Path.GetFileName(pathLower)
        Catch
            file = pathLower
        End Try

        Dim f As String = If(file, String.Empty).ToLowerInvariant()

        Select Case f
            Case "articoli.aspx"
                Return "Catalogo"
            Case "articolo.aspx"
                Return "Prodotto"
            Case "carrello.aspx"
                Return "Carrello"
            Case "checkout.aspx"
                Return "Checkout"
            Case "myaccount.aspx"
                Return "Account"
            Case "login.aspx"
                Return "Accedi"
            Case "register.aspx"
                Return "Registrati"
            Case "documenti.aspx"
                Return "Ordini"
            Case "documentidettaglio.aspx"
                Return "Dettaglio ordine"
            Case "contattaci.aspx", "contact.aspx"
                Return "Contatti"
            Case "faq.aspx"
                Return "FAQ"
            Case "about.aspx"
                Return "Chi siamo"
        End Select

        If String.IsNullOrWhiteSpace(f) Then Return String.Empty

        ' Fallback: nome file -> titolo leggibile
        Dim nameOnly As String = f
        If nameOnly.EndsWith(".aspx") Then nameOnly = nameOnly.Substring(0, nameOnly.Length - 5)
        nameOnly = nameOnly.Replace("-", " ").Replace("_", " ").Trim()

        If nameOnly.Length = 0 Then Return String.Empty

        Return Char.ToUpperInvariant(nameOnly(0)) & nameOnly.Substring(1)
    End Function

End Class
