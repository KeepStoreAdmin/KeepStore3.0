Imports System
Imports System.Configuration
Imports System.Data
Imports System.Web.UI.WebControls
Imports MySql.Data.MySqlClient

Partial Class my_account_address
    Inherits System.Web.UI.Page

    Private ReadOnly Property ConnString As String
        Get
            Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("LoginId") Is Nothing Then
            Session("Pagina_visitata") = Request.Url
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        If Not IsPostBack Then
            BindAddressPage()
        End If
    End Sub

    Private Sub BindAddressPage()
        ClearMessage()

        Dim loginId As Integer = CurrentLoginId()
        Dim utentiId As Integer = ResolveUtentiId(loginId)

        If loginId <= 0 OrElse utentiId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        BindMainAddress(utentiId)
        BindAlternativeAddresses(utentiId)
    End Sub

    Private Function CurrentLoginId() As Integer
        Dim value As Integer = 0
        Integer.TryParse(Convert.ToString(Session("LoginId")), value)
        If value <= 0 Then Integer.TryParse(Convert.ToString(Session("LoginID")), value)
        Return value
    End Function

    Private Function ResolveUtentiId(ByVal loginId As Integer) As Integer
        Dim utentiId As Integer = 0

        Integer.TryParse(Convert.ToString(Session("UtentiId")), utentiId)
        If utentiId <= 0 Then Integer.TryParse(Convert.ToString(Session("UTENTIID")), utentiId)
        If utentiId <= 0 Then Integer.TryParse(Convert.ToString(Session("UtentiID")), utentiId)
        If utentiId > 0 Then Return utentiId

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Using cmd As New MySqlCommand("SELECT u.Id FROM vlogin v INNER JOIN utenti u ON v.utentiid = u.Id WHERE v.Id = @LoginId LIMIT 1", conn)
                cmd.Parameters.AddWithValue("@LoginId", loginId)
                Dim raw As Object = cmd.ExecuteScalar()
                If raw IsNot Nothing AndAlso raw IsNot DBNull.Value Then
                    Integer.TryParse(Convert.ToString(raw), utentiId)
                End If
            End Using
        End Using

        If utentiId > 0 Then
            Session("UtentiId") = utentiId
            Session("UTENTIID") = utentiId
            Session("UtentiID") = utentiId
        End If

        Return utentiId
    End Function

    Private Sub BindMainAddress(ByVal utentiId As Integer)
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Dim sql As String =
                "SELECT " &
                "COALESCE(RagioneSociale,'') AS RagioneSociale, " &
                "COALESCE(CognomeNome,'') AS CognomeNome, " &
                "COALESCE(Email,'') AS Email, " &
                "COALESCE(Indirizzo,'') AS Indirizzo, " &
                "COALESCE(Cap,'') AS Cap, " &
                "COALESCE(Citta,'') AS Citta, " &
                "COALESCE(Provincia,'') AS Provincia, " &
                "COALESCE(Nazione,'') AS Nazione, " &
                "COALESCE(Telefono,'') AS Telefono, " &
                "COALESCE(Cellulare,'') AS Cellulare " &
                "FROM utenti WHERE Id = @UtentiId LIMIT 1"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        If dt.Rows.Count = 0 Then
            pnlMainAddress.Visible = False
            pnlNoMainAddress.Visible = True
            Return
        End If

        Dim row As DataRow = dt.Rows(0)
        pnlMainAddress.Visible = True
        pnlNoMainAddress.Visible = False

        litMainName.Text = Server.HtmlEncode(FirstValue(row, "RagioneSociale", "CognomeNome", "Non indicato"))
        litMainEmail.Text = Server.HtmlEncode(SafeRowValue(row, "Email", "Non indicata"))
        litMainAddress.Text = Server.HtmlEncode(SafeRowValue(row, "Indirizzo", "Non indicato"))
        litMainCap.Text = Server.HtmlEncode(SafeRowValue(row, "Cap", "-"))
        litMainCity.Text = Server.HtmlEncode(SafeRowValue(row, "Citta", "-"))
        litMainProvince.Text = Server.HtmlEncode(SafeRowValue(row, "Provincia", "-"))
        litMainCountry.Text = Server.HtmlEncode(SafeRowValue(row, "Nazione", "-"))
        litMainPhone.Text = Server.HtmlEncode(SafeRowValue(row, "Telefono", "-"))
        litMainMobile.Text = Server.HtmlEncode(SafeRowValue(row, "Cellulare", "-"))
    End Sub

    Private Sub BindAlternativeAddresses(ByVal utentiId As Integer)
        Dim dt As DataTable = LoadAlternativeAddresses(utentiId)
        Dim hasDefaultAlternative As Boolean = False

        For Each row As DataRow In dt.Rows
            If IsDefaultValue(row("Predefinito")) Then
                hasDefaultAlternative = True
                Exit For
            End If
        Next

        lblMainDefaultBadge.Visible = Not hasDefaultAlternative
        pnlNoAlternativeAddresses.Visible = (dt.Rows.Count = 0)
        rptAlternativeAddresses.Visible = (dt.Rows.Count > 0)
        rptAlternativeAddresses.DataSource = dt
        rptAlternativeAddresses.DataBind()
    End Sub

    Private Function LoadAlternativeAddresses(ByVal utentiId As Integer) As DataTable
        Dim dt As New DataTable()

        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Dim sql As String =
                "SELECT " &
                "Id, " &
                "COALESCE(RagioneSocialeA,'') AS RagioneSocialeA, " &
                "COALESCE(NomeA,'') AS NomeA, " &
                "COALESCE(IndirizzoA,'') AS IndirizzoA, " &
                "COALESCE(CapA,'') AS CapA, " &
                "COALESCE(CittaA,'') AS CittaA, " &
                "COALESCE(ProvinciaA,'') AS ProvinciaA, " &
                "COALESCE(Zona,'') AS Zona, " &
                "COALESCE(TelefonoA,'') AS TelefonoA, " &
                "COALESCE(CellulareA,'') AS CellulareA, " &
                "COALESCE(FaxA,'') AS FaxA, " &
                "COALESCE(Note,'') AS Note, " &
                "COALESCE(Predefinito,0) AS Predefinito, " &
                "COALESCE(NazioneA,'') AS NazioneA " &
                "FROM utentiindirizzi " &
                "WHERE UtenteId = @UtentiId " &
                "ORDER BY COALESCE(Predefinito,0) DESC, Id ASC"

            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                Using da As New MySqlDataAdapter(cmd)
                    da.Fill(dt)
                End Using
            End Using
        End Using

        Return dt
    End Function

    Protected Sub rptAlternativeAddresses_ItemCommand(ByVal source As Object, ByVal e As RepeaterCommandEventArgs)
        If Not String.Equals(e.CommandName, "SetDefault", StringComparison.OrdinalIgnoreCase) Then Return

        Dim addressId As Integer = 0
        Integer.TryParse(Convert.ToString(e.CommandArgument), addressId)

        Dim loginId As Integer = CurrentLoginId()
        Dim utentiId As Integer = ResolveUtentiId(loginId)

        If addressId <= 0 OrElse utentiId <= 0 Then
            ShowMessage("Non e stato possibile aggiornare la sede predefinita.", False)
            BindAlternativeAddresses(utentiId)
            Return
        End If

        If SetDefaultAlternativeAddress(utentiId, addressId) Then
            ShowMessage("Sede predefinita aggiornata correttamente.", True)
        Else
            ShowMessage("Non e stato possibile aggiornare la sede predefinita.", False)
        End If

        BindAlternativeAddresses(utentiId)
    End Sub

    Private Function SetDefaultAlternativeAddress(ByVal utentiId As Integer, ByVal addressId As Integer) As Boolean
        Using conn As New MySqlConnection(ConnString)
            conn.Open()

            Using tr As MySqlTransaction = conn.BeginTransaction()
                Try
                    Using verifyCmd As New MySqlCommand("SELECT COUNT(*) FROM utentiindirizzi WHERE Id = @Id AND UtenteId = @UtentiId", conn, tr)
                        verifyCmd.Parameters.AddWithValue("@Id", addressId)
                        verifyCmd.Parameters.AddWithValue("@UtentiId", utentiId)
                        Dim existsCount As Integer = Convert.ToInt32(verifyCmd.ExecuteScalar())
                        If existsCount <= 0 Then
                            tr.Rollback()
                            Return False
                        End If
                    End Using

                    Using resetCmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito = 0 WHERE UtenteId = @UtentiId", conn, tr)
                        resetCmd.Parameters.AddWithValue("@UtentiId", utentiId)
                        resetCmd.ExecuteNonQuery()
                    End Using

                    Using setCmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito = 1 WHERE Id = @Id AND UtenteId = @UtentiId", conn, tr)
                        setCmd.Parameters.AddWithValue("@Id", addressId)
                        setCmd.Parameters.AddWithValue("@UtentiId", utentiId)
                        If setCmd.ExecuteNonQuery() <> 1 Then
                            tr.Rollback()
                            Return False
                        End If
                    End Using

                    tr.Commit()
                    Return True
                Catch
                    Try
                        tr.Rollback()
                    Catch
                    End Try
                    Return False
                End Try
            End Using
        End Using
    End Function

    Public Function FormatAlternativeTitle(ByVal dataItem As Object) As String
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return "Sede alternativa"

        Dim ragione As String = SafeRowViewValue(rowView, "RagioneSocialeA", "")
        If Not String.IsNullOrWhiteSpace(ragione) Then Return Server.HtmlEncode(ragione)

        Dim nome As String = SafeRowViewValue(rowView, "NomeA", "")
        If Not String.IsNullOrWhiteSpace(nome) Then Return Server.HtmlEncode(nome)

        Return "Sede alternativa"
    End Function

    Public Function SafeField(ByVal dataItem As Object, ByVal fieldName As String, ByVal fallback As String) As String
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return Server.HtmlEncode(fallback)
        Return Server.HtmlEncode(SafeRowViewValue(rowView, fieldName, fallback))
    End Function

    Public Function IsDefaultAddress(ByVal dataItem As Object) As Boolean
        Dim rowView As DataRowView = TryCast(dataItem, DataRowView)
        If rowView Is Nothing Then Return False
        Return IsDefaultValue(rowView("Predefinito"))
    End Function

    Private Function IsDefaultValue(ByVal raw As Object) As Boolean
        Dim value As Integer = 0
        If raw IsNot Nothing AndAlso raw IsNot DBNull.Value Then Integer.TryParse(Convert.ToString(raw), value)
        Return value = 1
    End Function

    Private Function SafeRowViewValue(ByVal rowView As DataRowView, ByVal fieldName As String, ByVal fallback As String) As String
        If rowView Is Nothing OrElse rowView.Row Is Nothing OrElse Not rowView.Row.Table.Columns.Contains(fieldName) Then Return fallback
        Return SafeText(rowView(fieldName), fallback)
    End Function

    Private Function SafeRowValue(ByVal row As DataRow, ByVal fieldName As String, ByVal fallback As String) As String
        If row Is Nothing OrElse Not row.Table.Columns.Contains(fieldName) Then Return fallback
        Return SafeText(row(fieldName), fallback)
    End Function

    Private Function FirstValue(ByVal row As DataRow, ByVal firstField As String, ByVal secondField As String, ByVal fallback As String) As String
        Dim first As String = SafeRowValue(row, firstField, "")
        If Not String.IsNullOrWhiteSpace(first) Then Return first

        Dim second As String = SafeRowValue(row, secondField, "")
        If Not String.IsNullOrWhiteSpace(second) Then Return second

        Return fallback
    End Function

    Private Function SafeText(ByVal raw As Object, ByVal fallback As String) As String
        If raw Is Nothing OrElse raw Is DBNull.Value Then Return fallback
        Dim value As String = Convert.ToString(raw).Trim()
        If String.IsNullOrWhiteSpace(value) Then Return fallback
        Return value
    End Function

    Private Sub ClearMessage()
        lblPageMessage.Text = ""
        lblPageMessage.CssClass = "d-none"
    End Sub

    Private Sub ShowMessage(ByVal message As String, ByVal success As Boolean)
        lblPageMessage.Text = message
        lblPageMessage.CssClass = If(success, "alert alert-success d-block mb-4", "alert alert-danger d-block mb-4")
    End Sub
End Class
