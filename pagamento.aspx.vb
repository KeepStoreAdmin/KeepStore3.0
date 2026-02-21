Option Strict On

Imports System
Imports System.Configuration
Imports System.Web
Imports MySql.Data.MySqlClient

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


Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
    ' Pagina destinata a rientri pagamento / callback.
    ' Supporta due rami:
    ' 1) Coupon: qs "cod" -> ordine_coupon.aspx?cod=...
    ' 2) Documento: qs "id" / "docid" -> documentidettaglio.aspx?id=...

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

        ' fallback: nessun parametro riconosciuto
        SafeRedirect("carrello.aspx")
    Catch
        SafeRedirect("carrello.aspx")
    End Try
End Sub

End Class
