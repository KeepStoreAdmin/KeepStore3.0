<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="cambiapassword.aspx.vb" Inherits="cambiapassword" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">

<script language="vbscript" type="text/vbscript">
<!--
sub ctl00_cph_tRegistrazione_onkeydown()
    if window.event.keyCode=13 then
        window.event.returnValue=false
    end if
end sub
-->
</script>

<h1>Cambia la tua password di accesso al sito <asp:Label ID="lblSito" runat="server" ></asp:Label></h1>

<table cellpadding="1" cellspacing="5" border="0" width="100%" runat="server" id="tRegistrazione" >
    <tr>
        <td colspan="2" >
<br />Gentile Cliente,
<br />per motivi di sicurezza, la tua password di accesso al sito scade automaticamente ogni <asp:Label ID="lblMesi" runat="server" Font-Bold=true></asp:Label> mesi,
<br />ti invitiamo quindi a rinnovare e a conservare scrupolosamente la nuova password in luoghi sicuri.
<br /><br /><hr /></td>
    </tr>
    <tr>
        <td bgcolor="whitesmoke" width="35%">&nbsp;<b>Username</b></td>
        <td><asp:TextBox ID="tbUsername" Enabled="false" runat="server" Width="200" MaxLength="50" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox><asp:TextBox ID="tbEmail" visible="false" runat="server"></asp:TextBox>
            <asp:RequiredFieldValidator ID="RequiredFieldValidator1" runat="server" ControlToValidate="tbUsername" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione"></asp:RequiredFieldValidator>
            <asp:RegularExpressionValidator ID="RegularExpressionValidator1" runat="server" ControlToValidate="tbUsername" Display="Dynamic" ErrorMessage="Inserire minimo: 8 caratteri, senza caratteri speciali" SetFocusOnError="True" ValidationExpression="[\w\s]{8,}" ValidationGroup="registrazione"></asp:RegularExpressionValidator>
        </td>
    </tr>
    
    <tr>
        <td bgcolor="whitesmoke" width="35%">&nbsp;<b>Vecchia Password</b></td>
        <td><asp:TextBox ID="tbPasswordVecchia" runat="server" Width="200" MaxLength="25" TextMode="Password" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox><asp:TextBox ID="tbPasswordOK" runat="server" style="display:none" Width="0"  ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
            <asp:RequiredFieldValidator ID="RequiredFieldValidator4" runat="server" ControlToValidate="tbPasswordVecchia" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione"></asp:RequiredFieldValidator>
            <asp:CompareValidator ID="CompareValidator2" runat="server" ControlToCompare="tbPasswordOK" ControlToValidate="tbPasswordVecchia" Display="Dynamic" ErrorMessage="Vecchia Password errata" SetFocusOnError="True" ValidationGroup="registrazione"></asp:CompareValidator>
        </td>
    </tr>    

    <tr>
        <td bgcolor="whitesmoke" width="35%">&nbsp;<b>Nuova Password</b></td>
        <td><asp:TextBox ID="tbPasswordNuova" runat="server" Width="200" MaxLength="25" TextMode="Password" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
            <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbPasswordNuova" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione"></asp:RequiredFieldValidator>
            <br />
            <asp:RegularExpressionValidator ID="RegularExpressionValidator2" runat="server" ControlToValidate="tbPasswordNuova" Display="Dynamic" ErrorMessage="Inserire minimo: 8 caratteri, senza caratteri speciali" SetFocusOnError="True" ValidationExpression="[\w\s]{8,}" ValidationGroup="registrazione"></asp:RegularExpressionValidator>
        </td>
    </tr>
    <tr>
        <td bgcolor="whitesmoke" width="35%">&nbsp;<b>Conferma Nuova Password</b></td>
        <td ><asp:TextBox ID="tbPasswordConferma" runat="server" Width="200" MaxLength="25" TextMode="Password" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
            <asp:RequiredFieldValidator ID="RequiredFieldValidator3" runat="server" ControlToValidate="tbPasswordConferma" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione"></asp:RequiredFieldValidator>
            <asp:CompareValidator ID="CompareValidator1" runat="server" ControlToCompare="tbPasswordNuova" ControlToValidate="tbPasswordConferma" Display="Dynamic" ErrorMessage="Le Password devono coincidere" SetFocusOnError="True" ValidationGroup="registrazione"></asp:CompareValidator>
        </td>
    </tr>
   
    <tr>
        <td></td>
        <td><br /><asp:Button ID="btRegistrati" runat="server" Text="CAMBIA PASSWORD" width="150" ValidationGroup="registrazione" PostBackUrl="cambiapassword.aspx"/></td>        
    </tr> 
    <tr>
        <td colspan="2" align="right"><hr/></td>
    </tr>            
</table>


<table cellpadding="1" cellspacing="5" border="0" width="100%" runat="server" id="tAggiorna" visible="false">
    <tr>
        <td colspan="2"><br /><hr size=1/><br /></td>
    </tr>
    <tr>
        <td colspan="2" align="center">
        <br />La tua Password è stata correttamente aggiornata!<br /><br />
        <a href="default.aspx"><b>Continua</b></a>
        <br /><br />
        </td>
    </tr>   
    <tr>
        <td colspan="2" ><br /><hr size="1"/><br /></td>
    </tr>
</table>

</asp:Content>

