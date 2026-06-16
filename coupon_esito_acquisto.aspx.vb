Imports System.IO
Imports System.Globalization
Imports System.Net
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.WebControls

Partial Class coupon_esito_acquisto
    Inherits System.Web.UI.Page

    Private Const InvalidCouponRequestMessage As String = "Non è possibile visualizzare l’esito dell’acquisto coupon. Il link non è valido o i dati della richiesta non sono completi."

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Controllo se l'utente è loggato o meno, se non è loggato lo indirizzo alla registrazione
        Dim loginId As Integer = 0
        Dim rawLogin As Object = Session("LoginID")
        If rawLogin IsNot Nothing Then
            Integer.TryParse(Convert.ToString(rawLogin), loginId)
        End If

        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx")
        End If
        '----------------------------------------------------------------------------------------

        Dim couponId As Integer = 0
        Dim couponCode As String = NormalizeQueryStringValue(Request.QueryString("cod"))
        If Integer.TryParse(NormalizeQueryStringValue(Request.QueryString("id")), couponId) = False OrElse
           couponId <= 0 OrElse
           IsValidCouponCode(couponCode) = False Then
            ShowInvalidCouponRequest()
            Return
        End If

        SqlData_Coupon.SelectParameters.Clear()
        SqlData_Coupon.SelectParameters.Add(New Parameter("cod_controllo", TypeCode.String, couponCode))

        ' Seleziono il coupon da visualizzare (logica esistente)
        SqlData_CouponInserzioni.SelectCommand =
            "SELECT * FROM coupon_inserzione " &
            "JOIN coupon_partners ON coupon_inserzione.idPartner=coupon_partners.idPartner " &
            "JOIN coupon_tabella_temporanea ON coupon_inserzione.idCoupon=coupon_tabella_temporanea.idCoupon " &
            "WHERE (coupon_tabella_temporanea.idCoupon = @idCoupon) " &
            "AND (cod_controllo = @cod_controllo)"
        SqlData_CouponInserzioni.SelectParameters.Clear()
        SqlData_CouponInserzioni.SelectParameters.Add(New Parameter("idCoupon", TypeCode.Int32, couponId.ToString(CultureInfo.InvariantCulture)))
        SqlData_CouponInserzioni.SelectParameters.Add(New Parameter("cod_controllo", TypeCode.String, couponCode))
    End Sub

    Private Function NormalizeQueryStringValue(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Return value.Trim()
    End Function

    Private Function IsValidCouponCode(ByVal value As String) As Boolean
        If String.IsNullOrWhiteSpace(value) Then Return False
        If value.Length > 128 Then Return False

        For Each ch As Char In value
            If Char.IsControl(ch) Then Return False
        Next

        Return True
    End Function

    Private Sub ShowInvalidCouponRequest()
        InvalidCouponRequestPanel.Visible = True
        InvalidCouponRequestPanel.Controls.Clear()
        InvalidCouponRequestPanel.Controls.Add(New LiteralControl(Server.HtmlEncode(InvalidCouponRequestMessage)))

        Esito_pagamento_coupon.Visible = False
        Esito_pagamento_coupon.DataSourceID = String.Empty
        DataList_Coupon.Visible = False
        DataList_Coupon.DataSourceID = String.Empty

        SqlData_Coupon.SelectParameters.Clear()
        SqlData_Coupon.SelectCommand = "SELECT * FROM coupon_tabella_temporanea WHERE 1 = 0"
        SqlData_CouponInserzioni.SelectParameters.Clear()
        SqlData_CouponInserzioni.SelectCommand = "SELECT * FROM coupon_inserzione WHERE 1 = 0"
    End Sub

    ' --- Helper migrate dal markup (bonifica legacy) ---

    Protected Function controllo_presenza_opzione(ByVal opzione As String) As String
        If String.IsNullOrEmpty(opzione) Then Return "none"
        Return ""
    End Function

    ' Nel markup veniva usata con la stessa logica di controllo_presenza_opzione.
    Protected Function reindirizza_a_opzioni(ByVal opzione As String) As String
        If String.IsNullOrEmpty(opzione) Then Return "none"
        Return ""
    End Function

    Protected Function visualizza_descrizione_tecnica(ByVal stringa As Object) As String
        If stringa Is Nothing OrElse IsDBNull(stringa) Then Return "none"
        Dim s As String = Convert.ToString(stringa).Trim()
        If s = "" Then Return "none"
        Return ""
    End Function

    Protected Function genera_qrcode(ByVal stringa As String, ByVal dimensione As Integer, ByVal folder As String) As String
        If String.IsNullOrWhiteSpace(stringa) Then
            Return "<img src='Immagini/No_Image.jpg' alt=''>"
        End If

        ' Folder di default coerente con progetto
        If String.IsNullOrWhiteSpace(folder) Then folder = "Public/temp"

        ' Normalizza folder come virtual path
        folder = folder.Trim().TrimStart("~"c).TrimStart("/"c)
        Dim virtualFolder As String = "~/" & folder

        Try
            Dim absFolder As String = Server.MapPath(virtualFolder)
            If Directory.Exists(absFolder) = False Then
                Directory.CreateDirectory(absFolder)
            End If

            ' Pulizia cartella temporanea (comportamento esistente)
            For Each f As String In Directory.GetFiles(absFolder, "*.*")
                Try
                    File.Delete(f)
                Catch
                    ' Ignora singolo file bloccato
                End Try
            Next

            ' Nome file safe (evita caratteri invalidi su filesystem)
            Dim safeBase As String = stringa
            For Each ch As Char In Path.GetInvalidFileNameChars()
                safeBase = safeBase.Replace(ch, "_"c)
            Next
            If safeBase.Length > 80 Then safeBase = safeBase.Substring(0, 80)

            Dim fn As String = safeBase & "_" & String.Format("{0:MMddyyHHmmss}", DateTime.Now()) & ".png"
            Dim url As String = "https://chart.googleapis.com/chart?cht=qr&chs=" &
                                dimensione & "x" & dimensione &
                                "&chl=" & HttpUtility.UrlEncode(stringa)

            Using client As New WebClient()
                client.DownloadFile(url, Path.Combine(absFolder, fn))
            End Using

            Return "<img src='/" & folder & "/" & fn & "' alt=''>"
        Catch
            Return "<img src='Immagini/No_Image.jpg' alt=''>"
        End Try
    End Function

End Class
