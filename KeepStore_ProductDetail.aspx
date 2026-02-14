<%@ Page Language="VB" AutoEventWireup="false" %>
<script runat="server">
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        ' STEP S: KeepStore_ProductDetail.aspx becomes an alias of articolo.aspx (real product detail).
        ' Keep querystring intact.
        Dim qs As String = If(Request.Url IsNot Nothing, Request.Url.Query, "")
        Dim target As String = "~/articolo.aspx" & qs
        Server.Transfer(target, True)
    End Sub
</script>
