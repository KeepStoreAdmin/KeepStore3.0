<%@ Page Language="VB"
    MasterPageFile="~/Page.master"
    AutoEventWireup="false"
    CodeFile="logout.aspx.vb"
    Inherits="logout" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Logout
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <!-- CSS/JS specifici per il logout (se servono) -->
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <h1>Logout</h1>

    <div class="account-box">
        <p>Sei stato disconnesso correttamente.</p>
        <p>
            <a href="default.aspx" class="tf-btn-icon type-2 style-white">Torna alla Home</a>
        </p>
    </div>

</asp:Content>
