Imports System.IO
Imports System.Net
Imports System.Web

Partial Class coupon_esito_acquisto
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        'Controllo se l'utente è loggato o meno, se non è loggato lo indirizzo alla registrazione
        Dim loginId As Integer = 0
        If Session("LoginID") IsNot Nothing Then
            Integer.TryParse(Session("LoginID").ToString(), loginId)
        End If
        If loginId <= 0 Then
            Response.Redirect("accessonegato.aspx")
        End If
        '----------------------------------------------------------------------------------------

        'Seleziono il coupon da visualizzare
        SqlData_CouponInserzioni.SelectCommand = "SELECT * FROM coupon_inserzione JOIN coupon_partners ON coupon_inserzione.idPartner=coupon_partners.idPartner JOIN coupon_tabella_temporanea ON coupon_inserzione.idCoupon=coupon_tabella_temporanea.idCoupon WHERE (coupon_tabella_temporanea.idCoupon=" & Request.QueryString("id") & ") AND (cod_controllo='" & Request.QueryString("cod") & "')"
    End Sub

    '------------------------------------------------------------
    ' Helper migrate dal markup (bonifica legacy)
    '------------------------------------------------------------
    Protected Function controllo_presenza_opzione(ByVal opzione As String) As String
        If String.IsNullOrEmpty(opzione) Then
            Return "none"
        End If
        Return ""
    End Function

    ' Nota: nel markup storico era duplicata rispetto a controllo_presenza_opzione.
    ' La manteniamo per compatibilità (stessa semantica di visualizzazione).
    Protected Function reindirizza_a_opzioni(ByVal opzione As String) As String
        Return controllo_presenza_opzione(opzione)
    End Function

    Protected Function visualizza_descrizione_tecnica(ByVal stringa As Object) As String
        If stringa Is Nothing OrElse IsDBNull(stringa) Then
            Return "none"
        End If

        Dim s As String = TryCast(stringa, String)
        If String.IsNullOrEmpty(s) Then
            Return "none"
        End If

        Return ""
    End Function

    'Helper spostata dal markup (bonifica legacy)
    Protected Function genera_qrcode(ByVal stringa As String, ByVal dimensione As Integer, ByVal folder As String) As String
        If String.IsNullOrWhiteSpace(folder) Then folder = "Public/temp"

        Dim virtFolder As String = folder.Trim().TrimStart("/"c)
        Dim folderUrl As String = "/" & virtFolder
        Dim absFolder As String = Server.MapPath("~/" & virtFolder)
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

            Dim safeBase As String = If(stringa, "").Trim()
            For Each ch As Char In Path.GetInvalidFileNameChars()
                safeBase = safeBase.Replace(ch, "_"c)
            Next
            If safeBase = "" Then safeBase = "qr"

            Dim fn As String = safeBase & "_" & String.Format("{0:MMddyyHHmmss}", DateTime.Now()) & ".png"
            Dim url As String = "https://chart.googleapis.com/chart?cht=qr&chs=" & dimensione & "x" & dimensione & "&chl=" & HttpUtility.UrlEncode(stringa)

            Using client As New WebClient()
                client.DownloadFile(url, absFolder & "/" & fn)
            End Using

            Return "<img src='" & folderUrl & "/" & fn & "' alt=''>"
        Catch
            Return "<img src='Immagini/No_Image.jpg' alt=''>"
        End Try
    End Function
End Class
