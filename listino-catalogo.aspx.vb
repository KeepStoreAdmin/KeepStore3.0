Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Threading
Imports System.Web

' Scarica listino e offerte (CATALOG-DOWNLOAD-1A PDF, CATALOG-DOWNLOAD-1B Excel). Pagina privata dell'utente collegato: un POST protetto da token genera il file al momento e lo
' invia come allegato (mai salvato sul sito). Confini: prima di qualsiasi query si verifica che il POST non sia stato respinto dal controllo CSRF, che
' l'utente sia collegato e che il contesto prezzi sia coerente (lo fa lo snapshot); un solo file alla volta per utente e al massimo due insieme nel sito.
Partial Class listino_catalogo
    Inherits AntiCsrfPage

    Private Const MaxParallelGenerations As Integer = 2
    Private Shared ReadOnly Gate As New SemaphoreSlim(MaxParallelGenerations, MaxParallelGenerations)
    Private Shared ReadOnly ActiveUsers As New HashSet(Of Integer)()

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Session("LoginId") Is Nothing Then
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If
        If Not IsPostBack Then
            Try
                Dim priceContext As StorefrontPriceDisplayContext = StorefrontPriceDisplayContextProvider.GetCurrent(Context)
                If priceContext IsNot Nothing AndAlso priceContext.IsAuthenticated AndAlso Not String.IsNullOrWhiteSpace(priceContext.DisplayLabel) Then
                    litPriceLabel.Text = HttpUtility.HtmlEncode(priceContext.DisplayLabel.Trim().TrimStart("*"c).Trim())
                End If
            Catch
            End Try
        End If
    End Sub

    Protected Sub btnPdf_Click(ByVal sender As Object, ByVal e As EventArgs) Handles btnPdf.Click
        RunExport(False)
    End Sub

    Protected Sub btnXls_Click(ByVal sender As Object, ByVal e As EventArgs) Handles btnXls.Click
        RunExport(True)
    End Sub

    ' Stesse guardie per PDF ed Excel: CSRF, accesso, un file alla volta per utente, al massimo due insieme nel sito.
    Private Sub RunExport(ByVal asExcel As Boolean)
        ' Il rifiuto CSRF reindirizza ma non ferma il ciclo di vita: nessuna generazione dopo un POST respinto.
        If Response.IsRequestBeingRedirected Then Return
        Dim token As String = SafeToken(hfToken.Value)
        Dim loginId As Integer = CurrentLoginId()
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        If Not TryEnter(loginId) Then
            Fail(token, "Stai già generando un listino: attendi che finisca.", 429)
            Return
        End If
        Dim bytes As Byte() = Nothing
        Dim status As Integer = 200
        Dim message As String = ""
        Try
            If Not Gate.Wait(TimeSpan.FromSeconds(20)) Then
                status = 503
                message = "Il servizio è occupato con altri listini: riprova tra un minuto."
            Else
                Try
                    Server.ScriptTimeout = 600
                    Dim snapshot As CatalogExportSnapshot = CatalogExportSnapshotProvider.LoadCurrent(Context)
                    If snapshot.Status = CatalogExportStatus.NotAuthenticated Then
                        status = 401
                        message = "Per scaricare il listino devi essere collegato."
                    ElseIf snapshot.Status <> CatalogExportStatus.Ready Then
                        status = 500
                        message = "Non è stato possibile preparare il listino. Riprova più tardi."
                    Else
                        bytes = If(asExcel, CatalogXlsWriter.Build(snapshot), CatalogPdfWriter.Build(snapshot))
                    End If
                Catch ex As Exception
                    status = 500
                    message = "Non è stato possibile preparare il listino. Riprova più tardi."
                    Try
                        KeepStoreLog.Error("catalog-export", If(asExcel, "Generazione Excel non riuscita: ", "Generazione PDF non riuscita: ") & ex.GetType().Name, Nothing, Context)
                    Catch
                    End Try
                Finally
                    Gate.Release()
                End Try
            End If
        Finally
            Leave(loginId)
        End Try

        If bytes Is Nothing Then
            Fail(token, message, status)
            Return
        End If
        SendFile(token, bytes, asExcel)
    End Sub

    Private Sub SendFile(ByVal token As String, ByVal bytes As Byte(), ByVal asExcel As Boolean)
        Response.Clear()
        Response.Cache.SetCacheability(HttpCacheability.NoCache)
        Response.Cache.SetNoStore()
        Response.AppendHeader("X-Robots-Tag", "noindex, nofollow, noarchive")
        Response.ContentType = If(asExcel, "application/vnd.ms-excel", "application/pdf")
        Response.AppendHeader("Content-Disposition", "attachment; filename=""listino-offerte-" & Date.Today.ToString("yyyyMMdd", CultureInfo.InvariantCulture) & If(asExcel, ".xls", ".pdf") & """")
        Response.AppendHeader("Content-Length", bytes.Length.ToString(CultureInfo.InvariantCulture))
        SetDoneCookie(token, "ok")
        Response.BinaryWrite(bytes)
        Response.End()
    End Sub

    Private Sub Fail(ByVal token As String, ByVal message As String, ByVal status As Integer)
        SetDoneCookie(token, "err")
        Response.StatusCode = status
        Response.TrySkipIisCustomErrors = True
        pnlMessage.Visible = True
        litMessage.Text = HttpUtility.HtmlEncode(message)
    End Sub

    Private Sub SetDoneCookie(ByVal token As String, ByVal result As String)
        If String.IsNullOrEmpty(token) Then Return
        Dim cookie As New HttpCookie("ks_dl_done", token & "|" & result) With {.Path = "/", .HttpOnly = False, .Secure = Request.IsSecureConnection}
        Try
            cookie.SameSite = SameSiteMode.Lax
        Catch
        End Try
        Response.Cookies.Add(cookie)
    End Sub

    ' Il token del cookie e solo un riferimento per chiudere l'attesa: cifre e lettere, lunghezza limitata.
    Private Shared Function SafeToken(ByVal raw As String) As String
        If String.IsNullOrEmpty(raw) OrElse raw.Length > 40 Then Return ""
        For Each ch As Char In raw
            If Not (Char.IsLetterOrDigit(ch) AndAlso AscW(ch) < 128) Then Return ""
        Next
        Return raw
    End Function

    Private Function CurrentLoginId() As Integer
        Dim v As Object = Session("LoginId")
        If v Is Nothing Then Return 0
        Dim n As Integer = 0
        If Integer.TryParse(Convert.ToString(v, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, n) Then Return n
        Return 0
    End Function

    Private Shared Function TryEnter(ByVal loginId As Integer) As Boolean
        SyncLock ActiveUsers
            Return ActiveUsers.Add(loginId)
        End SyncLock
    End Function

    Private Shared Sub Leave(ByVal loginId As Integer)
        SyncLock ActiveUsers
            ActiveUsers.Remove(loginId)
        End SyncLock
    End Sub
End Class
