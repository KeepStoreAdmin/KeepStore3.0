<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="settore_disabilitato.aspx.vb" Inherits="settore_disabilitato" title="Pagina senza titolo" %>

<asp:Content ID="Content1" ContentPlaceHolderID="Contentplaceholder1" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
    <div style=" text-align:center; margin:auto; padding:10px; font-size:12pt;">
        <img src="Images/error.png" alt="" /><br /><br />
        Il prodotto inserito nel carrello non può essere acquistato, perchè l'amministratore del sistema ha disabilitato il Settore di appartenenza.
        <br /><br />
        Se si è comunque intenzionati all'acquisto del prodotto inviare una email a <%=Session("AziendaEmail")%>
        <br /><br />
        <a href="Default.aspx" style="font-weight:bold; color:Red;">Ritorna alla Home-Page</a>
    </div>
</asp:Content>

