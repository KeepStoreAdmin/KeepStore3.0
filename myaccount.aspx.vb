Imports System.Collections.Generic
Imports System.Configuration
Imports MySql.Data.MySqlClient

Partial Class myaccount
    Inherits System.Web.UI.Page

    ' KS-MYACCOUNT-1B: i tipi documento sono dati del database (nessun id fisso); il conteggio e dell'utente nell'azienda dell'host.
    Private Const DocTypesSql As String =
        "SELECT td.id, td.Descrizione, CASE WHEN td.ImpegnaQnt=1 THEN 1 ELSE 0 END AS IsOrder, COUNT(d.id) AS N " &
        "FROM tipodocumenti td LEFT JOIN documenti d ON d.TipoDocumentiId=td.id AND d.UtentiId=@uid AND d.AziendeId=@azienda " &
        "WHERE td.Web=1 AND td.Abilitato=1 GROUP BY td.id, td.Descrizione, td.ImpegnaQnt, td.Ordinamento ORDER BY td.Ordinamento, td.Descrizione, td.id"

    ' Candidati dell'avviso "da pagare": solo le condizioni NECESSARIE della regola (la decisione resta KeepStoreRemotePaymentStore.CanPayNow).
    Private Const PayCandidatesSql As String =
        "SELECT STRAIGHT_JOIN d.id FROM documenti d INNER JOIN tipodocumenti td ON td.id=d.TipoDocumentiId INNER JOIN pagamentitipo p ON p.id=d.PagamentiTipoId " &
        "WHERE d.UtentiId=@uid AND d.AziendeId=@azienda AND COALESCE(d.Pagato,0)=0 AND COALESCE(d.StatiId,0) NOT IN (0,3) " &
        "AND td.Web=1 AND td.Abilitato=1 AND td.ImpegnaQnt=1 AND COALESCE(p.OnLine,0) IN (2,3) AND COALESCE(p.PermettiPagamentoSuccessivo,0)=1 " &
        "ORDER BY d.id DESC LIMIT 50"

    Private _tiles As List(Of AccountTile)

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Me.Session("LoginId") Is Nothing Then
            Me.Session("Page") = Me.Request.Url.ToString()
            Me.Response.Redirect("accessonegato.aspx", True)
        End If
        LoadDashboard()
    End Sub

    ' Riquadri e avviso: identita verificata dell'host (utente + azienda); ogni errore lascia i riquadri fissi e nessun avviso.
    Private Sub LoadDashboard()
        Dim types As New List(Of AccountDocType)()
        Dim payable As New List(Of Integer)()
        Dim orderTypeId As Integer = 0
        Dim identity As OrderStorefrontIdentity = Nothing
        Try
            identity = OrderStorefrontContext.Resolve(HttpContext.Current)
        Catch
            identity = Nothing
        End Try
        If identity IsNot Nothing AndAlso identity.IsComplete Then
            Try
                Dim candidates As New List(Of Integer)()
                Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                    conn.Open()
                    Using cmd As New MySqlCommand(DocTypesSql, conn)
                        cmd.Parameters.Add("@uid", MySqlDbType.Int64).Value = identity.UtentiId
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = identity.CompanyId
                        Using dr As MySqlDataReader = cmd.ExecuteReader()
                            While dr.Read()
                                Dim t As New AccountDocType()
                                t.Id = SafeInt(dr("id"), 0)
                                t.Description = SafeStatusText(dr("Descrizione"))
                                t.IsOrder = SafeInt(dr("IsOrder"), 0) = 1
                                t.Count = SafeInt(dr("N"), 0)
                                If t.IsOrder AndAlso orderTypeId = 0 Then orderTypeId = t.Id
                                types.Add(t)
                            End While
                        End Using
                    End Using
                    Using cmd As New MySqlCommand(PayCandidatesSql, conn)
                        cmd.Parameters.Add("@uid", MySqlDbType.Int64).Value = identity.UtentiId
                        cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = identity.CompanyId
                        Using dr As MySqlDataReader = cmd.ExecuteReader()
                            While dr.Read()
                                candidates.Add(SafeInt(dr("id"), 0))
                            End While
                        End Using
                    End Using
                End Using
                For Each candidate As Integer In candidates
                    If candidate <= 0 Then Continue For
                    If KeepStoreRemotePaymentStore.CanPayNow(candidate, identity.UtentiId, identity.CompanyId) Then payable.Add(candidate)
                    ' Il testo non dice un totale: bastano due ordini per scegliere fra dettaglio e lista.
                    If payable.Count >= 2 Then Exit For
                Next
            Catch
                payable.Clear()
            End Try
        End If
        _tiles = KeepStoreAccountTiles.Build(types)
        Dim noticeUrl As String = KeepStoreAccountTiles.PayNoticeUrl(payable, orderTypeId)
        If noticeUrl.Length > 0 Then
            pnlPayNotice.Visible = True
            lnkPayNotice.HRef = noticeUrl
            litPayNotice.Text = If(payable.Count = 1, "Hai un ordine da pagare", "Hai ordini da pagare")
        End If
    End Sub

    Protected Function TilesHtml(ByVal active As Boolean) As String
        If _tiles Is Nothing Then _tiles = KeepStoreAccountTiles.Build(Nothing)
        Return KeepStoreAccountTiles.RenderHtml(_tiles, active)
    End Function

    Protected Sub fvDashboardProfile_DataBound(ByVal sender As Object, ByVal e As System.EventArgs)
        Dim row As System.Data.DataRowView = TryCast(fvDashboardProfile.DataItem, System.Data.DataRowView)
        If row Is Nothing Then Return
        litGreeting.Text = HttpUtility.HtmlEncode(GetDashboardGreeting(row("RagioneSociale"), row("CognomeNome"), row("Username")))
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - La tua Dashboard"
    End Sub

    Protected Function GetDashboardGreeting(ByVal ragioneSocialeObj As Object,
                                            ByVal cognomeNomeObj As Object,
                                            ByVal usernameObj As Object) As String
        Dim displayName As String = SafeStatusText(FirstValue(ragioneSocialeObj, cognomeNomeObj, usernameObj))
        If displayName = "" Then Return "Benvenuto nella tua Dashboard"
        Return "Ciao, " & displayName
    End Function

    Protected Function FirstValue(ParamArray values() As Object) As Object
        If values Is Nothing Then Return Nothing

        For Each value As Object In values
            Dim text As String = SafeStatusText(value)
            If text <> "" Then Return text
        Next

        Return Nothing
    End Function

    Protected Function SafeAccountText(ByVal value As Object, ByVal fallback As String) As String
        Dim text As String = SafeStatusText(value)
        If text = "" Then Return fallback
        Return text
    End Function

    Protected Function FormatCityLine(ByVal capObj As Object,
                                      ByVal cittaObj As Object,
                                      ByVal provinciaObj As Object) As String
        Dim cap As String = SafeStatusText(capObj)
        Dim citta As String = SafeStatusText(cittaObj)
        Dim provincia As String = SafeStatusText(provinciaObj)
        Dim text As String = (cap & " " & citta).Trim()

        If provincia <> "" Then
            text = (text & " (" & provincia & ")").Trim()
        End If

        If text = "" Then Return "Localita non specificata"
        Return text
    End Function

    Private Function SafeStatusText(ByVal value As Object) As String
        If value Is Nothing OrElse IsDBNull(value) Then Return ""

        Dim text As String = Convert.ToString(value).Trim()
        If text = "" Then Return ""

        text = text.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ")
        Do While text.Contains("  ")
            text = text.Replace("  ", " ")
        Loop

        Return text
    End Function

    Private Function SafeInt(ByVal value As Object, ByVal fallback As Integer) As Integer
        Try
            If value Is Nothing OrElse IsDBNull(value) Then Return fallback
            Dim parsed As Integer = fallback
            If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return fallback
    End Function

    Private Function TruncateText(ByVal value As String, ByVal maxLength As Integer) As String
        If String.IsNullOrEmpty(value) Then Return ""
        If maxLength <= 0 Then Return ""
        If value.Length <= maxLength Then Return value
        Return value.Substring(0, maxLength).TrimEnd() & "..."
    End Function
End Class
