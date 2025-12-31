<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="sitemap.aspx.vb" Inherits="sitemap"  %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">

<div class="map">

    <asp:SqlDataSource ID="sdsCategorie" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM vcategoriesettori where settoriabilitato=1 and abilitato=1 order by settoriordinamento, settoridescrizone, ordinamento, descrizione " EnableViewState="False"></asp:SqlDataSource>
    <asp:DataList ID="dlCategorie" runat="server" DataSourceID="sdsCategorie" EnableViewState="False" Width="100%">
        <ItemTemplate>
            <h1><asp:Label ID="Label1" runat="server" Text='<%# Eval("SettoriDescrizone") &" > "& Eval("Descrizione") %>'></asp:Label></h1>
            <asp:TextBox ID="tbSettore" runat="server" Text='<%# Eval("SettoriId") %>' Visible="false" EnableViewState="False"></asp:TextBox><asp:TextBox ID="tbCategoria" runat="server" Text='<%# Eval("Id") %>' Visible="false" EnableViewState="False"></asp:TextBox>
            <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM varticolibase WHERE SettoriId=?SettoriId AND CategorieId=?CategorieId ORDER BY MarcheDescrizione, Codice, Descrizione1" EnableViewState="False">
            <SelectParameters>
                <asp:ControlParameter ControlID="tbSettore" Name="SettoriId" PropertyName="Text" Type="Int32" />
                <asp:ControlParameter ControlID="tbCategoria" Name="CategorieId" PropertyName="Text" Type="Int32" />
            </SelectParameters>
            </asp:SqlDataSource>
             
             <ul>
             <asp:DataList ID="dlArticoli" runat="server" DataSourceID="sdsArticoli" EnableViewState="False" Width="100%">
                <ItemTemplate>
                    <li><asp:HyperLink ID="HyperLink1" EnableViewState="False" runat="server" Text='<%# Eval("Descrizione1") %>' ToolTip='<%# Eval("SettoriDescrizione") &" > "&  Eval("CategorieDescrizione") &" > "& Eval("MarcheDescrizione") &" > "& Eval("TipologieDescrizione") &" > "&  Eval("GruppiDescrizione") &" > "&  Eval("SottogruppiDescrizione") &" > "&  Eval("Codice") %>' NavigateUrl='<%# "articolo.aspx?id="& Eval("id") %>'></asp:HyperLink></li>
                </ItemTemplate>
             </asp:DataList>
             </ul>
        </ItemTemplate>
    </asp:DataList>

</div>

</asp:Content>

