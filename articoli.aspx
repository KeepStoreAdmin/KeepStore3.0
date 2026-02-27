<%@ Page Language="VB" MasterPageFile="~/Public/ui/master/Site.master" ... %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo prodotti
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <%-- NOTE: stili spostati in /Public/assets/keepstore/css/keepstore.css --%>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <%-- Breadcrumb: ora gestito dal master (Breadcrumb UC) per evitare duplicazioni --%>

    <%-- CONTENUTO PAGINA: lasciare invariato markup/controlli esistenti.
         Questa patch modifica solo MasterPageFile e rimuove breadcrumb duplicati.
         Incolla qui il corpo originale della pagina (a partire dal primo section/container) se stai facendo merge manuale. --%>

</asp:Content>
