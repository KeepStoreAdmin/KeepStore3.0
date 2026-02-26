<%@ Page Language="VB" AutoEventWireup="false" ValidateRequest="false"  CodeFile="diagnostic.aspx.vb" Inherits="diagnostic" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="System.Text" %>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>KeepStore Diagnostic</title>
    <meta charset="utf-8" />
</head>
<body>
<form id="form1" runat="server">
    <div style="font-family: Consolas, monospace; padding: 16px;">
        <h2>Diagnostic</h2>
        <asp:Literal ID="lit" runat="server" />
    </div>
</form>
</body>
</html>
