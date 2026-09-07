Imports MySql.Data.MySqlClient
Partial Class logout
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not IsPostBack Then
            EseguiLogout()
        End If
    End Sub

    Private Sub EseguiLogout()
        ' Il carrello autenticato resta persistente tra logout e login.
        Try
            Session.Clear()
            Session.Abandon()
        Catch
            ' Se per qualche motivo fa storie, non blocco la pagina di logout.
        End Try

        ' Nessun redirect qui: viene renderizzata logout.aspx
        ' con il messaggio "Sei stato disconnesso correttamente."
    End Sub

End Class
