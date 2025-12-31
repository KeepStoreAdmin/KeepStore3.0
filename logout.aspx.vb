Imports MySql.Data.MySqlClient
Imports System.Configuration
Imports System.Data

Partial Class logout
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not IsPostBack Then
            EseguiLogout()
        End If
    End Sub

    Private Sub EseguiLogout()
        Dim loginId As Integer = 0

        ' Provo a leggere il LoginId dalla sessione (se non c'è, amen)
        If Session("LoginId") IsNot Nothing Then
            Integer.TryParse(Session("LoginId").ToString(), loginId)
        End If

        ' Se l'utente era loggato, pulisco il carrello legato al LoginId
        If loginId > 0 Then
            PulisciCarrelloUtente(loginId)
        End If

        ' Pulizia sessione (butto giù tutto quello che riguarda l'utente)
        Try
            Session.Clear()
            Session.Abandon()
        Catch
            ' Se per qualche motivo fa storie, non blocco la pagina di logout.
        End Try

        ' Nessun redirect qui: viene renderizzata logout.aspx
        ' con il messaggio "Sei stato disconnesso correttamente."
    End Sub

    Private Sub PulisciCarrelloUtente(ByVal loginId As Integer)
        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        If String.IsNullOrEmpty(connString) Then
            Exit Sub
        End If

        Using conn As New MySqlConnection(connString)
            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text
                cmd.CommandText = "DELETE FROM carrello WHERE LoginId = ?LoginId"
                cmd.Parameters.AddWithValue("?LoginId", loginId)

                Try
                    conn.Open()
                    cmd.ExecuteNonQuery()
                Catch
                    ' Non blocco il logout se il delete fallisce.
                    ' Qui eventualmente log su file/event viewer.
                End Try
            End Using
        End Using
    End Sub

End Class
