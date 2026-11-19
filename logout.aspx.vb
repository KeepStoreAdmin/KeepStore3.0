Imports MySql.Data.MySqlClient
Partial Class logout
    Inherits System.Web.UI.Page

    ' AUTH-STAY-SIGNED-IN-2B: l'uscita scollega anche il dispositivo ricordato. Avviene qui, prima del master, perche il master puo
    ' rifiutare la richiesta (account disabilitato, errore) prima che la pagina arrivi a Page_Load.
    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreInit
        KeepStoreStaySignedInWeb.SignOut(HttpContext.Current)
    End Sub

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
