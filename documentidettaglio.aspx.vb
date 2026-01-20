Imports System.Data
Imports System
Imports System.Text
Imports System.Web

Partial Class documentidettaglio
    Inherits System.Web.UI.Page

    ' Null-safe: limita testo a lunghezza massima.
    Protected Function AdattaTesto(ByVal testo As Object, ByVal lunghezza As Integer) As String
        Dim s As String = Convert.ToString(testo)
        If String.IsNullOrEmpty(s) Then
            Return String.Empty
        End If

        If lunghezza <= 0 Then
            Return String.Empty
        End If

        If s.Length > lunghezza Then
            Return Left(s, lunghezza) & " ..."
        End If

        Return s
    End Function

    ' Tracking: genera link multipli (separati da ";") applicando Link_Tracking (#ID#).
    ' Hardening: encoding HTML/attributo per evitare injection da input non previsto.
    Protected Function SeparaTracking(ByVal trackingObj As Object, ByVal linkTrackingObj As Object) As String
        Dim tracking As String = Convert.ToString(trackingObj)
        Dim linkTracking As String = Convert.ToString(linkTrackingObj)

        If String.IsNullOrEmpty(tracking) OrElse String.IsNullOrEmpty(linkTracking) Then
            Return String.Empty
        End If

        Dim parts() As String = tracking.Split(";"c)
        If parts Is Nothing OrElse parts.Length = 0 Then
            Return String.Empty
        End If

        Dim sb As New StringBuilder()
        For i As Integer = 0 To parts.Length - 1
            Dim code As String = Convert.ToString(parts(i)).Trim()
            If code = "" Then
                Continue For
            End If

            Dim url As String = linkTracking.Replace("#ID#", HttpUtility.UrlEncode(code))

            ' Permetti solo http/https; in caso contrario, mostra solo il testo.
            Dim urlTrim As String = url.Trim().ToLowerInvariant()
            Dim isHttp As Boolean = (urlTrim.StartsWith("http://") OrElse urlTrim.StartsWith("https://"))

            If isHttp Then
                sb.Append("<a class=\"link\" href=\"")
                sb.Append(HttpUtility.HtmlAttributeEncode(url))
                sb.Append("\" target=\"_blank\" rel=\"noopener noreferrer\">")
                sb.Append(HttpUtility.HtmlEncode(code))
                sb.Append("</a>")
            Else
                sb.Append(HttpUtility.HtmlEncode(code))
            End If

            If i < parts.Length - 1 Then
                sb.Append(" <span class=\"ks-muted\">;</span> ")
            End If
        Next

        Return sb.ToString()
    End Function

    Protected Sub FormView1_DataBound(sender As Object, e As EventArgs) Handles FormView1.DataBound
        ' Mostra i pulsanti di pagamento online solo quando: PagamentiTipoOnline=1 e documento non risulta gia' autorizzato.
        ' Logica volutamente conservativa per evitare regressioni: in dubbio, lascia nascosto.
        Try
            If FormView1 Is Nothing OrElse FormView1.DataItem Is Nothing Then
                Return
            End If

            Dim drv As DataRowView = TryCast(FormView1.DataItem, DataRowView)
            If drv Is Nothing Then
                Return
            End If

            Dim online As Integer = 0
            Dim authCode As String = ""
            Dim stato1 As String = ""
            Dim pagDescr As String = ""

            Try
                online = Convert.ToInt32(drv("PagamentiTipoOnline"))
            Catch
                online = 0
            End Try

            Try
                authCode = Convert.ToString(drv("CodiceAutorizzazione"))
            Catch
                authCode = ""
            End Try

            Try
                stato1 = Convert.ToString(drv("StatiDescrizione1"))
            Catch
                stato1 = ""
            End Try

            Try
                pagDescr = Convert.ToString(drv("PagamentiTipoDescrizione"))
            Catch
                pagDescr = ""
            End Try

            Dim show As Boolean = (online = 1 AndAlso String.IsNullOrEmpty(authCode))
            If stato1 IsNot Nothing AndAlso stato1.Trim().ToLowerInvariant() = "annullato" Then
                show = False
            End If

            Dim btSella As Control = FormView1.FindControl("btBancaSella")
            Dim btIw As Control = FormView1.FindControl("btIwBank")
            Dim btPP As Control = FormView1.FindControl("btPayPal")

            ' Default: nascondi
            SetVisible(btSella, False)
            SetVisible(btIw, False)
            SetVisible(btPP, False)

            If Not show Then
                Return
            End If

            ' Se PayPal e' il metodo selezionato, prova a mostrare PayPal; altrimenti mostra BancaSella.
            If pagDescr IsNot Nothing AndAlso pagDescr.Trim().ToLowerInvariant().Contains("paypal") Then
                SetVisible(btPP, True)
            Else
                SetVisible(btSella, True)
            End If

            ' IwBank: abilita solo se la sessione e' configurata.
            Dim acc As String = Convert.ToString(Me.Session("AccountIwBank"))
            If Not String.IsNullOrEmpty(acc) Then
                SetVisible(btIw, True)
            End If

        Catch
            ' Fail-safe: non interrompere la pagina.
        End Try
    End Sub

    Private Sub SetVisible(ByVal ctrl As Control, ByVal value As Boolean)
        If ctrl Is Nothing Then Return
        Try
            ctrl.Visible = value
        Catch
            ' ignore
        End Try
    End Sub

End Class
