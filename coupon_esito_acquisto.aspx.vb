Imports System.IO
Imports System.Net
Imports System.Web

Partial Class coupon_esito_acquisto
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        'Controllo se l'utente è loggato o meno, se non è loggato lo indirizzo alla registrazione
        If Session("LoginID") <= 0 Then
            Response.Redirect("accessonegato.aspx")
        End If
        '----------------------------------------------------------------------------------------

        'Seleziono il coupon da visualizzare
        SqlData_CouponInserzioni.SelectCommand = "SELECT * FROM coupon_inserzione JOIN coupon_partners ON coupon_inserzione.idPartner=coupon_partners.idPartner JOIN coupon_tabella_temporanea ON coupon_inserzione.idCoupon=coupon_tabella_temporanea.idCoupon WHERE (coupon_tabella_temporanea.idCoupon=" & Request.QueryString("id") & ") AND (cod_controllo='" & Request.QueryString("cod") & "')"
    End Sub

    'Helper spostata dal markup (bonifica legacy)
    Protected Function genera_qrcode(ByVal stringa As String, ByVal dimensione As Integer, ByVal folder As String) As String
        If String.IsNullOrWhiteSpace(folder) Then folder = "Public/temp"
        If Not folder.StartsWith("/") Then
            folder = "/" & folder.TrimStart("/"c)
        End If

        Dim absFolder As String = Server.MapPath("./") & folder
        Try
            If Directory.Exists(absFolder) = False Then
                Directory.CreateDirectory(absFolder)
            End If

            'Pulizia cartella temporanea
            For Each f As String In Directory.GetFiles(absFolder, "*.*")
                Try
                    File.Delete(f)
                Catch
                    'Ignora singolo file bloccato
                End Try
            Next

            Dim fn As String = stringa & "_" & String.Format("{0:MMddyyhhmmss}", DateTime.Now()) & ".png"
            Dim url As String = "https://chart.googleapis.com/chart?cht=qr&chs=" & dimensione & "x" & dimensione & "&chl=" & HttpUtility.UrlEncode(stringa)

            Using client As New WebClient()
                client.DownloadFile(url, absFolder & "/" & fn)
            End Using

            Return "<img src='" & folder & "/" & fn & "' alt=''>"
        Catch
            Return "<img src='Immagini/No_Image.jpg' alt=''>"
        End Try
    End Function
End Class
