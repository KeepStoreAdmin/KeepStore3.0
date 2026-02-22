Option Strict On
Imports System

Partial Class pagamento
    Inherits System.Web.UI.Page

    ' =========================
    ' REDIRECT SAFE (avoid ThreadAbortException)
    ' =========================
    Private Sub SafeRedirect(ByVal url As String)
        Try
            Response.Redirect(url, False)
            Context.ApplicationInstance.CompleteRequest()
        Catch
        End Try
    End Sub

    Private Function GetQueryString(ByVal key As String, Optional ByVal maxLen As Integer = 200) As String
        Try
            Dim v As String = Convert.ToString(Request.QueryString(key))
            If v Is Nothing Then Return ""
            v = v.Trim()
            If v.Length > maxLen Then v = v.Substring(0, maxLen)
            Return v
        Catch
            Return ""
        End Try
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        ' Pagina destinata a rientri pagamento / callback.
        ' Supporta:
        ' 1) Coupon: qs "cod" o "cod_controllo" -> ordine_coupon.aspx
        ' 2) Documento: qs "id"/"docid"/"documento" -> documentidettaglio.aspx

        Try
            Dim cod As String = GetQueryString("cod", 200)
            If String.IsNullOrEmpty(cod) Then
                cod = GetQueryString("cod_controllo", 200) ' legacy
            End If

            If Not String.IsNullOrEmpty(cod) Then
                SafeRedirect("ordine_coupon.aspx?cod=" & Server.UrlEncode(cod))
                Return
            End If

            Dim docStr As String = GetQueryString("id", 50)
            If String.IsNullOrEmpty(docStr) Then docStr = GetQueryString("docid", 50)
            If String.IsNullOrEmpty(docStr) Then docStr = GetQueryString("documento", 50)

            Dim docId As Integer = 0
            Integer.TryParse(docStr, docId)

            If docId > 0 Then
                SafeRedirect("documentidettaglio.aspx?id=" & docId.ToString())
                Return
            End If

            ' fallback
            SafeRedirect("carrello.aspx")
        Catch
            SafeRedirect("carrello.aspx")
        End Try
    End Sub

End Class
