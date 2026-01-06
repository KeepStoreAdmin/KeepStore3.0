Option Strict On

Imports System
Imports System.Configuration
Imports System.Web
Imports MySql.Data.MySqlClient

Partial Class pagamento
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load

        ' Pagina destinata a rientri pagamento / callback.
        ' Manteniamo la logica esistente (coupon + pagamento documento), ma correggiamo gli errori di sintassi
        ' e rendiamo l'accesso e le query stabili.

        Dim loginId As Integer = 0
        If Session("LoginID") IsNot Nothing Then
            Integer.TryParse(Session("LoginID").ToString(), loginId)
        ElseIf Session("LoginId") IsNot Nothing Then
            Integer.TryParse(Session("LoginId").ToString(), loginId)
        End If

        If loginId <= 0 Then
            Session("Pagina_visitata") = Request.RawUrl
            Response.Redirect("accessonegato.aspx", True)
            Return
        End If

        Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(cs)
            conn.Open()

            ' ==========================================================
            ' 1) PAGAMENTO COUPON
            ' ==========================================================
            Dim cod_controllo As String = Qs("cod_controllo")
            If cod_controllo <> "" Then

                Dim idTransazione As String = ""

                ' PayPal
                Dim paypalTxnId As String = FormVal("txn_id")
                If paypalTxnId <> "" Then
                    idTransazione = paypalTxnId
                    Session("IdPagamentoCoupon") = 19
                End If

                ' IWBank (campo storico)
                Dim iwbankThxId As String = FormVal("thx_id")
                If idTransazione = "" AndAlso iwbankThxId <> "" Then
                    idTransazione = iwbankThxId
                    Session("IdPagamentoCoupon") = 10
                End If

                ' Banca Sella / GestPay (tx su querystring)
                Dim sellaTx As String = Qs("tx")
                If idTransazione = "" AndAlso sellaTx <> "" Then
                    idTransazione = sellaTx
                    Session("IdPagamentoCoupon") = 46
                End If

                If idTransazione = "" Then
                    idTransazione = Guid.NewGuid().ToString("N")
                End If

                Using cmd As New MySqlCommand("UPDATE coupon_tabella_temporanea SET StatoPagamento=1, idTransazione=?idTransazione WHERE cod_controllo=?cod_controllo", conn)
                    cmd.Parameters.AddWithValue("?idTransazione", idTransazione)
                    cmd.Parameters.AddWithValue("?cod_controllo", cod_controllo)
                    cmd.ExecuteNonQuery()
                End Using

                Session("Coupon_Codice_Controllo") = cod_controllo
                Session("Coupon_NumeroOpzione") = 0

                Response.Redirect("ordine_coupon.aspx?cod=" & Server.UrlEncode(cod_controllo), True)
                Return
            End If

            ' ==========================================================
            ' 2) PAGAMENTO DOCUMENTO (documenti)
            ' ==========================================================
            Dim docId As Integer = 0
            Integer.TryParse(Qs("id"), docId)

            Dim utentiId As Integer = 0
            If Session("UtentiId") IsNot Nothing Then
                Integer.TryParse(Session("UtentiId").ToString(), utentiId)
            End If

            If docId > 0 AndAlso utentiId > 0 Then

                Dim idTransazione As String = ""
                Dim stato As Integer = 1
                Dim idPagamento As Integer = 0

                ' IWBank
                Dim iwbankThxId As String = FormVal("thx_id")
                If iwbankThxId <> "" Then
                    idTransazione = iwbankThxId
                    idPagamento = 10
                    stato = 1
                End If

                ' PayPal
                Dim paypalTxnId As String = FormVal("txn_id")
                If idTransazione = "" AndAlso paypalTxnId <> "" Then
                    idTransazione = paypalTxnId
                    idPagamento = 19
                    stato = 1
                End If

                ' Banca Sella / GestPay (tx)
                Dim sellaTx As String = Qs("tx")
                If idTransazione = "" AndAlso sellaTx <> "" Then
                    idTransazione = sellaTx
                    idPagamento = 46
                    stato = 2 ' come nel codice precedente
                End If

                If idTransazione <> "" AndAlso idPagamento > 0 Then

                    Using cmd As New MySqlCommand("UPDATE documenti SET Stato=?Stato, DataPagamento=Now(), IdPagamento=?IdPagamento, IdTransazione=?IdTransazione WHERE id=?id AND utentiid=?utentiid", conn)
                        cmd.Parameters.AddWithValue("?Stato", stato)
                        cmd.Parameters.AddWithValue("?IdPagamento", idPagamento)
                        cmd.Parameters.AddWithValue("?IdTransazione", idTransazione)
                        cmd.Parameters.AddWithValue("?id", docId)
                        cmd.Parameters.AddWithValue("?utentiid", utentiId)
                        cmd.ExecuteNonQuery()
                    End Using

                    Session("IdPagamento") = idPagamento

                    Response.Redirect("documentidettaglio.aspx?id=" & docId.ToString(), True)
                    Return
                End If

            End If

        End Using

    End Sub

    Private Function Qs(ByVal key As String) As String
        Try
            Dim v As String = ""
            If Request IsNot Nothing AndAlso Request.QueryString(key) IsNot Nothing Then
                v = Request.QueryString(key).ToString()
            End If
            Return v.Trim()
        Catch
            Return ""
        End Try
    End Function

    Private Function FormVal(ByVal key As String) As String
        Try
            Dim v As String = ""
            If Request IsNot Nothing AndAlso Request.Form(key) IsNot Nothing Then
                v = Request.Form(key).ToString()
            End If
            Return v.Trim()
        Catch
            Return ""
        End Try
    End Function

End Class
