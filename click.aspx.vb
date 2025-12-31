Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class click
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        Dim id_pubblicita As Integer
        Dim ip_utente As String
        Dim id_utente As Integer
        Dim link As String
        Dim DataOdierna As String = Date.Today.Year.ToString & "-" & Date.Today.Month.ToString & "-" & Date.Today.Day.ToString

        id_pubblicita = Request.QueryString("id")
        ip_utente = Request.UserHostAddress
        id_utente = Me.Session("UtentiId")
        Dim params As New Dictionary(Of String, String)
        params.add("@dataOdierna", DataOdierna)
        params.add("@ipUtente", ip_utente)
        params.add("@idPubblicità", id_pubblicita)
        Dim dr = ExecuteQueryGetDataReader("*", "pubblicita_click", "WHERE (data_click=@dataOdierna) AND (ip_utente=@ipUtente) AND (id_pubblicita=@idPubblicità)", params)
        Dim pubblicitaClickExists As Boolean = dr.Count > 0

        If Not pubblicitaClickExists Then

            'Nel caso l'utente non sia loggato
            If (id_utente <= 0) Then
                id_utente = -1
            End If
            '---------------------------------
            params.add("@UtenteId", id_utente)
            ExecuteInsert("pubblicita_click", "id_utente,ip_utente,id_pubblicita,data_click", "@UtenteId, @ipUtente, @idPubblicità, @dataOdierna", params)

            ExecuteUpdate("pubblicitaV2", "numero_click_attuale=numero_click_attuale+1", "WHERE id = @idPubblicità", params)
        End If
        dr = ExecuteQueryGetDataReader("link", "pubblicitav2", "WHERE id = @idPubblicità", params)
        link = dr(0)("link")

        If Not (link.Contains("http://") OrElse link.Contains("https://")) Then
            If (link <> "#") Then
                link = "http://" & link
            End If
        End If

        Response.Redirect(link)
    End Sub

    Protected Function ExecuteInsert(ByVal table As String, ByVal fields As String, Optional ByVal values As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & values & ")"
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteDelete(ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "DELETE FROM " & table & " " & wherePart
        ExecuteNonQuery(False, sqlString, params)
    End Function

    Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing)
        Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & " " & wherePart
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

    Protected Sub ExecuteStoredProcedure(ByVal storedProcedure As String, Optional ByVal params As Dictionary(Of String, String) = Nothing)
        ExecuteNonQuery(True, storedProcedure, params)
    End Sub

    Protected Function ExecuteQueryGetDataReader(ByVal fields As String, ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As List(Of Dictionary(Of String, Object))
        Dim sqlString As String = "SELECT " & fields & " FROM " & table & " " & wherePart
        Dim dr As MySqlDataReader
        Dim result As New List(Of Dictionary(Of String, Object))
        Dim conn As New MySqlConnection
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            If Not connectionString Is Nothing Then
                conn.ConnectionString = connectionString
                conn.Open()
                Dim cmd = New MySqlCommand With {
                    .Connection = conn,
                    .CommandType = CommandType.Text,
                    .CommandText = sqlString
                }
                If Not params Is Nothing Then
                    Dim paramName As String
                    For Each paramName In params.Keys
                        cmd.Parameters.AddWithValue(paramName, params(paramName))
                    Next
                End If
                dr = cmd.ExecuteReader()

                While dr.Read()
                    Dim row As New Dictionary(Of String, Object)()

                    ' Per ogni colonna nella riga, aggiungi la colonna al dizionario
                    For i As Integer = 0 To dr.FieldCount - 1
                        ' Prendi il nome della colonna e il valore
                        Dim columnName As String = dr.GetName(i)
                        Dim value As Object = dr.GetValue(i)

                        ' Aggiungi la colonna e il valore al dizionario
                        row.Add(columnName, value)
                    Next

                    ' Aggiungi la riga al risultato
                    result.Add(row)
                End While

                dr.Close()
                dr.Dispose()
            End If
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If
        End Try
        Return result
    End Function
End Class
