<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="registrazioneok.aspx.vb" Inherits="registrazioneok" title="Untitled Page" %>
<asp:Content ID="Content1" ContentPlaceHolderID="Contentplaceholder1" Runat="Server">
    <%If Request.QueryString("state") = "coupon" Then  %>
        <meta http-equiv="refresh" content="2; url='<%= "login.aspx?username=" & Session("Login_User") & "&passw=" & Session("Login_Password") & "&redirect=" & Request.QueryString("redirect") %>' />
    <%else %>
        <meta http-equiv="refresh" content="2; url=default.aspx" />
    <%end if %>
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
<table cellpadding="1" cellspacing="5" border="0" width="100%" runat="server" id="tConclusa" visible="true">
    <tr>
        <td colspan="2"><br /><br /><hr size="1" /><br /></td>
    </tr>
    <tr>
        <td colspan="2" align="center">
        <b>Registrazione conclusa con successo!</b><br /><br />
         <u>Ti abbiamo inviato una <b>mail di conferma</b> con i tuoi dati d'accesso.</u>
        <br /><br />
        <img src="Public/Images/spinner.gif" alt="" />
        <br />
        Tra <b>pochi secondi</b> verrai reidirizzato al nostro SHOP.<br /><br />
        </td>
    </tr>   
    <tr>
        <td colspan="2" ><br /><hr size="1"/><br /></td>
    </tr>
</table>

</asp:Content>

