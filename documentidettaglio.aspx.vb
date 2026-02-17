Imports System.Data
Imports System
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient
Imports System.Configuration
Imports System.Globalization

Partial Class documentidettaglio
    Inherits System.Web.UI.Page

    Private _fallbackTipoDocumentoId As Integer = -1

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Richiede login
        If Session("LoginId") Is Nothing OrElse Convert.ToString(Session("LoginId")) = "" Then
            Response.Redirect("accesonegato.aspx")
            Return
        End If

        Dim idDocumento As Integer = -1
        If Not Integer.TryParse(Convert.ToString(Request.QueryString("id")), idDocumento) OrElse idDocumento <= 0 Then
            Response.Redirect("documenti.aspx?t=" & GetFallbackTipoDocumentoId().ToString(), True)
            Return
        End If

        If Not IsPostBack Then
            Dim tipoDocId As Integer = -1
            If Not DocumentoAppartieneAUtente(idDocumento, tipoDocId) Then
                Response.Redirect("documenti.aspx?t=" & GetFallbackTipoDocumentoId().ToString(), True)
                Return
            End If

            ' Breadcrumb: torna alla tipologia corretta
            If tipoDocId > 0 Then
                hlDocumenti.NavigateUrl = "documenti.aspx?t=" & tipoDocId.ToString()
            Else
                hlDocumenti.NavigateUrl = "documenti.aspx?t=" & GetFallbackTipoDocumentoId().ToString()
            End If

            ' Google Customer Reviews - Survey Opt-in (mostra solo al rientro dal checkout)
            TryRenderGoogleCustomerReviewsOptIn(idDocumento)

        End If
    End Sub

    Private Function DocumentoAppartieneAUtente(ByVal idDocumento As Integer, ByRef tipoDocId As Integer) As Boolean
        tipoDocId = -1
        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Using cmd As New MySqlCommand("SELECT TipoDocumentiId FROM vdocumenti WHERE Id=@id AND UtentiId=@uid LIMIT 1", c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = idDocumento
                    cmd.Parameters.Add("@uid", MySqlDbType.Int32).Value = Convert.ToInt32(Session("UtentiID"))
                    c.Open()
                    Dim o As Object = cmd.ExecuteScalar()
                    If o Is Nothing OrElse Convert.IsDBNull(o) Then Return False
                    Integer.TryParse(Convert.ToString(o), tipoDocId)
                    Return True
                End Using
            End Using
        Catch
            Return False
        End Try
    End Function

    Private Function GetFallbackTipoDocumentoId() As Integer
        If _fallbackTipoDocumentoId > 0 Then Return _fallbackTipoDocumentoId

        If TipoDocumentoExists(4) Then
            _fallbackTipoDocumentoId = 4
            Return _fallbackTipoDocumentoId
        End If

        Dim first As Integer = GetFirstEnabledTipoDocumentoId()
        If first > 0 Then
            _fallbackTipoDocumentoId = first
            Return _fallbackTipoDocumentoId
        End If

        _fallbackTipoDocumentoId = 4
        Return _fallbackTipoDocumentoId
    End Function

    Private Function TipoDocumentoExists(ByVal tipoId As Integer) As Boolean
        If tipoId <= 0 Then Return False
        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Using cmd As New MySqlCommand("SELECT 1 FROM tipodocumenti WHERE id=@id AND Web=1 AND Abilitato=1 LIMIT 1", c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = tipoId
                    c.Open()
                    Dim o As Object = cmd.ExecuteScalar()
                    Return (o IsNot Nothing AndAlso Not Convert.IsDBNull(o))
                End Using
            End Using
        Catch
            Return False
        End Try
    End Function

    Private Function GetFirstEnabledTipoDocumentoId() As Integer
        Try
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            Using c As New MySqlConnection(cs)
                Using cmd As New MySqlCommand("SELECT id FROM tipodocumenti WHERE Web=1 AND Abilitato=1 ORDER BY Ordinamento, Descrizione LIMIT 1", c)
                    c.Open()
                    Dim o As Object = cmd.ExecuteScalar()
                    If o Is Nothing OrElse Convert.IsDBNull(o) Then Return -1
                    Dim id As Integer = 0
                    If Integer.TryParse(Convert.ToString(o), id) AndAlso id > 0 Then Return id
                End Using
            End Using
        Catch
            ' ignore
        End Try
        Return -1
    End Function


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
	                sb.Append("<a class=""link"" href=""")
                sb.Append(HttpUtility.HtmlAttributeEncode(url))
			    		    sb.Append(""" target=""_blank"" rel=""noopener noreferrer"">")
                sb.Append(HttpUtility.HtmlEncode(code))
                sb.Append("</a>")
            Else
                sb.Append(HttpUtility.HtmlEncode(code))
            End If

            If i < parts.Length - 1 Then
	                sb.Append(" <span class=""ks-muted"">;</span> ")
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


    Private Sub TryRenderGoogleCustomerReviewsOptIn(ByVal idDocumento As Integer)
        ' Google Customer Reviews (Survey Opt-in)
        ' Mostra il popup SOLO subito dopo il checkout (gating tramite Session("GCR_ShowOptIn_DocId"))
        Try
            If Session Is Nothing OrElse Session("GCR_ShowOptIn_DocId") Is Nothing Then Return

            Dim sessionDocId As Integer = 0
            If Not Integer.TryParse(Convert.ToString(Session("GCR_ShowOptIn_DocId")), sessionDocId) Then Return
            If sessionDocId <= 0 OrElse sessionDocId <> idDocumento Then Return

            ' Clear early: evita ri-trigger su refresh/visite successive
            Session("GCR_ShowOptIn_DocId") = Nothing

            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Dim merchantId As String = ""
            Dim buyerEmail As String = ""
            Dim deliveryCountry As String = ""
            Dim baseDocDate As DateTime = DateTime.Today

            Dim sql As String = ""
            sql &= "SELECT "
            sql &= "  IFNULL(a.google_merchant_id,'') AS google_merchant_id, "
            sql &= "  IFNULL(u.email,'') AS buyer_email, "
            sql &= "  IFNULL(ui.NazioneA,'') AS nazione, "
            sql &= "  d.DataDocumento AS data_documento "
            sql &= "FROM documenti d "
            sql &= "LEFT JOIN aziende a ON a.id = d.AziendeId "
            sql &= "LEFT JOIN utenti u ON u.id = d.UtentiId "
            sql &= "LEFT JOIN utentiindirizzi ui ON ui.id = d.UtentiIndirizziId "
            sql &= "WHERE d.id=@id AND d.UtentiId=@uid "
            sql &= "LIMIT 1"

            Using c As New MySqlConnection(cs)
                c.Open()

                Using cmd As New MySqlCommand(sql, c)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = idDocumento
                    cmd.Parameters.Add("@uid", MySqlDbType.Int32).Value = Convert.ToInt32(Session("UtentiID"))

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            merchantId = Convert.ToString(dr("google_merchant_id")).Trim()
                            buyerEmail = Convert.ToString(dr("buyer_email")).Trim()
                            deliveryCountry = Convert.ToString(dr("nazione")).Trim().ToUpperInvariant()

                            Try
                                Dim oDt As Object = dr("data_documento")
                                If oDt IsNot Nothing AndAlso oDt IsNot DBNull.Value Then
                                    baseDocDate = CType(oDt, DateTime)
                                End If
                            Catch
                            End Try
                        End If
                    End Using
                End Using
            End Using

            ' Parametri minimi richiesti da Google
            If String.IsNullOrWhiteSpace(merchantId) Then Return
            If String.IsNullOrWhiteSpace(buyerEmail) Then Return

            If String.IsNullOrWhiteSpace(deliveryCountry) OrElse deliveryCountry.Length <> 2 Then
                deliveryCountry = "IT"
            End If

            ' Strategia B: data stimata consegna deterministica (DataDocumento + N giorni)
            Const defaultDeliveryDays As Integer = 5
            Dim estimatedDelivery As DateTime = baseDocDate.AddDays(defaultDeliveryDays)
            Dim estimatedDeliveryStr As String = estimatedDelivery.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)

            Dim orderIdStr As String = idDocumento.ToString(CultureInfo.InvariantCulture)

            ' Output encoding (JS)
            Dim jsMerchantId As String = HttpUtility.JavaScriptStringEncode(merchantId)
            Dim jsOrderId As String = HttpUtility.JavaScriptStringEncode(orderIdStr)
            Dim jsEmail As String = HttpUtility.JavaScriptStringEncode(buyerEmail)
            Dim jsCountry As String = HttpUtility.JavaScriptStringEncode(deliveryCountry)
            Dim jsEdd As String = HttpUtility.JavaScriptStringEncode(estimatedDeliveryStr)

            Dim sb As New StringBuilder()
            sb.AppendLine("<script src=""https://apis.google.com/js/platform.js?onload=renderOptIn"" async defer></script>")
            sb.AppendLine("<script>")
            sb.AppendLine("window.renderOptIn = function() {")
            sb.AppendLine("  window.gapi.load('surveyoptin', function() {")
            sb.AppendLine("    window.gapi.surveyoptin.render({")
            sb.AppendLine("      ""merchant_id"": """ & jsMerchantId & """,")
            sb.AppendLine("      ""order_id"": """ & jsOrderId & """,")
            sb.AppendLine("      ""email"": """ & jsEmail & """,")
            sb.AppendLine("      ""delivery_country"": """ & jsCountry & """,")
            sb.AppendLine("      ""estimated_delivery_date"": """ & jsEdd & """")
            sb.AppendLine("    });")
            sb.AppendLine("  });")
            sb.AppendLine("};")
            sb.AppendLine("</script>")

            litGoogleSurveyOptIn.Text = sb.ToString()

        Catch
            ' Fail-closed: nessun impatto sul checkout
        End Try
    End Sub

    '==============================================================
    ' KeepStore: immagine prodotto sicura (fallback nofoto)
    '==============================================================
    Protected Function SafeImg(ByVal temp As Object) As String
        Dim imgname As String = ""
        Try
            If temp IsNot Nothing AndAlso Not Convert.IsDBNull(temp) Then
                imgname = Convert.ToString(temp)
            End If
        Catch
        End Try

        If imgname Is Nothing Then imgname = ""
        imgname = imgname.Trim()

        If imgname = "" Then
            Return ResolveUrl("~/Public/images/nofoto.gif")
        End If

        If imgname.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse imgname.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return imgname
        End If

        ' Se il DB contiene gia' un percorso (es. Public/foto/xxx.jpg)
        If imgname.IndexOf("/") >= 0 OrElse imgname.IndexOf("\\") >= 0 Then
            imgname = imgname.Replace("\\", "/")
            imgname = imgname.TrimStart("/"c)
            Return ResolveUrl("~/" & imgname)
        End If

        Return ResolveUrl("~/Public/foto/" & imgname)
    End Function

End Class