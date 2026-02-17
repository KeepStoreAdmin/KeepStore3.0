Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class coupon_utente
    Inherits System.Web.UI.Page
    Dim conn As New MySqlConnection
    Dim cmd As New MySqlCommand
    Dim strSql As String = ""

    Protected Sub GridView1_RowCommand(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewCommandEventArgs) Handles GridView1.RowCommand
        Dim esito As Integer = -1

        If Page.IsPostBack = False Then
            Try
                Dim c As Control = DirectCast(e.CommandSource, Control)
                Dim r As GridViewRow = DirectCast(c.NamingContainer, GridViewRow)

                Dim ID_DOC As String = DirectCast(GridView1.Rows(r.RowIndex).FindControl("iddoc"), HyperLink).Text

                If (e.CommandName = "Stampa") Then
                    Dim params As New Dictionary(Of String, String)
                    params.add("@UTENTIID", Session("UTENTIID"))
                    params.add("@DOCUMENTIID", ID_DOC)
                    ExecuteInsert("INVIADOCUMENTI", "UTENTIID,DOCUMENTIID,DataRichiesta", "@UTENTIID,@DOCUMENTIID,Now()", params)


                    strSql = "INSERT INTO INVIADOCUMENTI "
                    strSql &= " ( "
                    strSql &= " UTENTIID, "
                    strSql &= " DOCUMENTIID, "
                    strSql &= " DataRichiesta "
                    strSql &= " ) VALUES ("
                    strSql &= Session("UTENTIID") & ", "
                    strSql &= ID_DOC & ", "
                    strSql &= "Now() )"

                    cmd.CommandType = CommandType.Text
                    cmd.CommandText = strSql

                    cmd.ExecuteNonQuery()
                    cmd.Dispose()

                    esito = 1
                End If

            Catch ex As Exception
                Me.Response.Redirect("documenti.aspx?esito=0&err=" & ex.Message)
            Finally
                Me.Response.Redirect("documenti.aspx?esito=" & esito)
            End Try
        End If
    End Sub

    Sub stampaClick(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs)

        Dim link As ImageButton = sender

        Dim id As String
        id = link.Attributes("idDoc")

        Dim esito As Integer = -1

        Try
            Dim params As New Dictionary(Of String, String)
            params.add("@UTENTIID", Session("UTENTIID"))
            params.add("@DOCUMENTIID", id)
            ExecuteInsert("INVIADOCUMENTI", "UTENTIID,DOCUMENTIID,DataRichiesta", "@UTENTIID,@DOCUMENTIID,Now()", params)

            'Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType, "prova", "<script type='text/javascript'>document.body.onload=function(){alert('Richiesta inoltrata. Riceverà il documento presso la sua casella email!')}</script>")
            'Comunico l'esecuzione positiva della richiesta 
            esito = 1

        Catch ex As Exception
            Me.Response.Redirect("documenti.aspx?t=" & Request.QueryString("t") & "&esito=0&err=" & ex.Message)
        Finally
            Me.Response.Redirect("documenti.aspx?esito=" & esito & "&t=" & Request.QueryString("t"))
        End Try
    End Sub

    Protected Function ExecuteInsert(ByVal table As String, ByVal fields As String, Optional ByVal values As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & values & ")"
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd As New MySqlCommand
                cmd.Connection = conn
                cmd.CommandText = sqlString
                For Each paramName In params.Keys
                    If paramName = "?parPrezzo" Or paramName = "?parPrezzoIvato" Then
                        cmd.Parameters.Add(paramName, MySqlDbType.Double).Value = Convert.ToDecimal(params(paramName), System.Globalization.CultureInfo.InvariantCulture)
                    Else
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    End If
                Next
                If isStoredProcedure Then
                    cmd.CommandType = CommandType.StoredProcedure
                    cmd.Parameters.AddWithValue("?parRetVal", "0")
                    cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
                Else
                    cmd.CommandType = CommandType.Text
                End If
                cmd.ExecuteNonQuery()
                cmd.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
    End Function
End Class

Protected Function separa_tracking(ByVal tracking As String, ByVal link_tracking As String) As String
    Try
        If String.IsNullOrEmpty(tracking) Then Return ""
        Dim temp As String() = tracking.Split(";"c)
        Dim risultato As String = ""
        For i As Integer = 0 To temp.Length - 1
            Dim id As String = ""
            Try
                id = temp(i).Trim()
            Catch
                id = ""
            End Try

            If id <> "" Then
                Dim href As String = "#"
                Try
                    href = Convert.ToString(link_tracking).Replace("#ID#", id)
                Catch
                    href = "#"
                End Try

                risultato &= "<img src=""Public/Images/interrogativo.png"" alt="""" title=""Clicca sul Numero Tracking"">" &
                             "<a href=""" & Server.HtmlAttributeEncode(href) & """ target=""_blank"">" &
                             Server.HtmlEncode(id) & "</a>; "
            End If
        Next
        Return risultato
    Catch
        Return ""
    End Try
End Function

Protected Function testNote(ByVal note As Object) As String
    Try
        Dim s As String = Convert.ToString(note)
        If String.IsNullOrEmpty(s) Then Return "display:none;"
        Return ""
    Catch
        Return "display:none;"
    End Try
End Function

