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

        If Me.Page Is Nothing OrElse Me.Page.Request Is Nothing Then
            phBreadcrumb.Visible = False
            Return
        End If

        Dim pathLower As String = String.Empty
        Try
            pathLower = Convert.ToString(Me.Page.Request.Url.AbsolutePath).ToLowerInvariant()
        Catch
            Try
                pathLower = Convert.ToString(Me.Page.Request.Path).ToLowerInvariant()
            Catch
                pathLower = String.Empty
            End Try
        End Try

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

        ' Title (markup/spacing allineati al tema)
        If ShowTitle Then
            litTitle.Text = "<h1 class=""h5 mb-1 fw-semibold"">" & HttpUtility.HtmlEncode(title) & "</h1>"
        Else
            litTitle.Text = String.Empty
        End If

        ' Trail: stile tema (con freccia)
        Dim sb As New StringBuilder()
        sb.Append("<a href=""Default.aspx"" class=""text"">Home</a>")
        sb.Append(" <i class=""icon icon-arrow-right""></i> ")
        sb.Append("<span class=""text"">" & HttpUtility.HtmlEncode(title) & "</span>")

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
            Case "articoli.aspx" : Return "Catalogo"
            Case "articolo.aspx" : Return "Prodotto"
            Case "carrello.aspx" : Return "Carrello"
            Case "checkout.aspx" : Return "Checkout"
            Case "myaccount.aspx" : Return "Account"
            Case "login.aspx" : Return "Accedi"
            Case "register.aspx" : Return "Registrati"
            Case "documenti.aspx" : Return "Ordini"
            Case "documentidettaglio.aspx" : Return "Dettaglio ordine"
            Case "contattaci.aspx", "contact.aspx" : Return "Contatti"
            Case "faq.aspx" : Return "FAQ"
            Case "about.aspx" : Return "Chi siamo"
        End Select

        If String.IsNullOrWhiteSpace(f) Then Return String.Empty

        Dim nameOnly As String = f
        If nameOnly.EndsWith(".aspx") Then nameOnly = nameOnly.Substring(0, nameOnly.Length - 5)
        nameOnly = nameOnly.Replace("-", " ").Replace("_", " ").Trim()
        If nameOnly.Length = 0 Then Return String.Empty

        Return Char.ToUpperInvariant(nameOnly(0)) & nameOnly.Substring(1)
    End Function
End Class
