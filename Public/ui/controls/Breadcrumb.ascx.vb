Imports System.Text.RegularExpressions

Partial Class Breadcrumb
    Inherits System.Web.UI.UserControl

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        If Not Page.IsPostBack Then
            litTitle.Text = GetFriendlyTitle()
        End If
    End Sub

    Private Function GetFriendlyTitle() As String
        Dim path As String = (Request.Url.AbsolutePath & "").ToLowerInvariant()
        Dim pageName As String = System.IO.Path.GetFileName(path)

        Select Case pageName
            Case "default.aspx"
                Return "Home"

            Case "articoli.aspx"
                Return "Catalogo"

            Case "articolo.aspx"
                Return "Dettaglio prodotto"

            Case "carrello.aspx"
                Return "Carrello"

            Case "checkout.aspx"
                Return "Checkout"

            Case "checkout_success.aspx"
                Return "Ordine completato"

            Case "myaccount.aspx"
                Return "My Account"

            Case "datiutente.aspx"
                Return "I miei dati"

            Case "wishlist.aspx"
                Return "Wishlist"

            Case "documenti.aspx"
                Return "Ordini"

            Case "password.aspx", "cambiapassword.aspx"
                Return "Cambia password"

            Case "login.aspx"
                Return "Accedi"

            Case "registrazione.aspx"
                Return "Registrati"

            Case "remind.aspx"
                Return "Recupera password"

            Case "accessonegato.aspx"
                Return "Accesso negato"
        End Select

        ' fallback: usa Title pagina, ripulito
        Dim t As String = (Page.Title & "").Trim()
        If String.IsNullOrWhiteSpace(t) Then
            t = pageName.Replace(".aspx", "")
        End If

        ' rimuove eventuale suffisso "- KeepStore"
        t = Regex.Replace(t, "\s*-\s*KeepStore\s*$", "", RegexOptions.IgnoreCase).Trim()

        Return t
    End Function
End Class
