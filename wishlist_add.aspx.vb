Imports System
Imports System.Configuration
Imports System.Data
Imports MySql.Data.MySqlClient

Partial Class wishlist_add
    Inherits AntiCsrfPage

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        Dim userId As Integer = 0
        Integer.TryParse(Convert.ToString(Session("UtentiId")), userId)

        If userId <= 0 Then
            Response.Redirect("login.aspx", False)
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        Dim articleId As Integer = 0
        Integer.TryParse(Convert.ToString(Request.QueryString("id")), articleId)
        If articleId <= 0 Then
            Response.Redirect("wishlist.aspx", False)
            Context.ApplicationInstance.CompleteRequest()
            Return
        End If

        Dim tcId As Integer = -1
        Integer.TryParse(Convert.ToString(Request.QueryString("TCid")), tcId)

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()

                Dim tcidExists As Boolean = WishlistHasTcidColumn(conn)
                Dim exists As Boolean = False

                Dim checkSql As String = "SELECT COUNT(*) FROM wishlist WHERE id_articolo=@articolo AND id_utente=@utente"
                If tcidExists Then
                    checkSql &= " AND TCid=@tcid"
                End If

                Using checkCmd As New MySqlCommand(checkSql, conn)
                    checkCmd.Parameters.AddWithValue("@articolo", articleId)
                    checkCmd.Parameters.AddWithValue("@utente", userId)
                    If tcidExists Then
                        checkCmd.Parameters.AddWithValue("@tcid", tcId)
                    End If

                    Dim raw As Object = checkCmd.ExecuteScalar()
                    Dim count As Integer = 0
                    If raw IsNot Nothing AndAlso raw IsNot DBNull.Value Then
                        Integer.TryParse(Convert.ToString(raw), count)
                    End If
                    exists = (count > 0)
                End Using

                If Not exists Then
                    Using cmd As New MySqlCommand("NewElement_Wishlist", conn)
                        cmd.CommandType = CommandType.StoredProcedure
                        cmd.Parameters.AddWithValue("?pIdUtente", userId)
                        cmd.Parameters.AddWithValue("?pIdArticolo", articleId)
                        cmd.Parameters.AddWithValue("?pTCid", tcId)
                        cmd.ExecuteNonQuery()
                    End Using
                End If
            End Using
        Catch
        End Try

        Response.Redirect("wishlist.aspx", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Function WishlistHasTcidColumn(ByVal conn As MySqlConnection) As Boolean
        Using cmd As New MySqlCommand("SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME='wishlist' AND LOWER(COLUMN_NAME)='tcid' LIMIT 1", conn)
            Dim raw As Object = cmd.ExecuteScalar()
            Return raw IsNot Nothing AndAlso raw IsNot DBNull.Value
        End Using
    End Function
End Class
