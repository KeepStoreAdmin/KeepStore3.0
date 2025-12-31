
Partial Class _promo
    Inherits System.Web.UI.Page

    Dim IvaTipo As Integer

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Me.tbData.Text = System.DateTime.Today
        Me.Session("InOfferta") = 1
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - " & Me.Session("AziendaDescrizione")
        IvaTipo = Me.Session("IvaTipo")
        If IvaTipo = 1 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Esclusa"
        ElseIf IvaTipo = 2 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Inclusa"
        End If
    End Sub

End Class
