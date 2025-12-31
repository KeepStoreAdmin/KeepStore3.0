<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="search_complete.aspx.vb" Inherits="search_complete" title="Untitled Page" %>
<asp:Content ID="Content1" ContentPlaceHolderID="Contentplaceholder1" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
    Ricerca Avanzata<br />
    <br />
    <asp:SqlDataSource ID="Sql_Categorie" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT categorie.id, categorie.Descrizione, articoli.Abilitato FROM articoli INNER JOIN categorie ON articoli.CategorieId = categorie.id WHERE (articoli.Abilitato = 1) GROUP BY categorie.id ORDER BY categorie.Descrizione"></asp:SqlDataSource>
    Categorie<br />
    <asp:DropDownList ID="DropDownList_Categorie" runat="server" DataSourceID="Sql_Categorie"
        DataTextField="Descrizione" DataValueField="id" Width="200px" AutoPostBack="True">
        <asp:ListItem Value="*">Tutte</asp:ListItem>
    </asp:DropDownList>&nbsp;&nbsp;<asp:Button ID="Button_Abilita_Categorie" runat="server" Text="Tutte le categorie" /><br />
    <br />
    <asp:SqlDataSource ID="Sql_Marche" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT DISTINCT marche.id, marche.Descrizione, vsuperarticoli.CategorieId FROM marche INNER JOIN vsuperarticoli ON marche.id = vsuperarticoli.MarcheId WHERE (vsuperarticoli.CategorieId = @Param) ORDER BY marche.Descrizione">
        <SelectParameters>
            <asp:ControlParameter ControlID="DropDownList_Categorie" DefaultValue="3" Name="@Param"
                PropertyName="SelectedValue" />
        </SelectParameters>
    </asp:SqlDataSource>
    Marche<br />
    <asp:DropDownList ID="DropDownList_Marche" runat="server" AutoPostBack="True" DataSourceID="Sql_Marche"
        DataTextField="Descrizione" DataValueField="id" Enabled="False" Width="200px">
        <asp:ListItem Selected="True">Disabilitato</asp:ListItem>
    </asp:DropDownList>
    &nbsp;
    <asp:Button ID="Button_Abilita_Marche" runat="server" Text="Abilita" /><br />
    <br />
    <asp:SqlDataSource ID="Sql_Tipologie" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Descrizione, CategorieId FROM tipologie WHERE (CategorieId = @Param1) ORDER BY Descrizione">
        <SelectParameters>
            <asp:ControlParameter ControlID="DropDownList_Categorie" Name="@Param1" PropertyName="SelectedValue" DefaultValue="0" />
        </SelectParameters>
    </asp:SqlDataSource>
    Tipologie<br />
    <asp:DropDownList ID="DropDownList_Tipologie" runat="server" DataSourceID="Sql_Tipologie"
        DataTextField="Descrizione" DataValueField="id" Width="200px" AutoPostBack="True" Enabled="False">
    </asp:DropDownList>
    &nbsp;
    <asp:Button ID="Button_Abilita_Tipologie" runat="server" Text="Abilita" /><br />
    <br />
    <asp:SqlDataSource ID="Sql_Gruppi" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Descrizione, CategorieId FROM gruppi WHERE (CategorieId = @Param2) ORDER BY Descrizione">
        <SelectParameters>
            <asp:ControlParameter ControlID="DropDownList_Categorie" DefaultValue="0" Name="@Param2"
                PropertyName="SelectedValue" />
        </SelectParameters>
    </asp:SqlDataSource>
    Gruppi<br />
    <asp:DropDownList ID="DropDownList_Gruppi" runat="server" DataSourceID="Sql_Gruppi"
        DataTextField="Descrizione" DataValueField="id" Width="200px" AutoPostBack="True" Enabled="False">
    </asp:DropDownList>
    &nbsp;
    <asp:Button ID="Button_Abilita_Gruppi" runat="server" Text="Abilita" /><br />
    <br />
    <asp:SqlDataSource ID="Sql_Sottogruppi" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Descrizione, CategorieId FROM sottogruppi WHERE (CategorieId = @Param3) ORDER BY Descrizione">
        <SelectParameters>
            <asp:ControlParameter ControlID="DropDownList_Categorie" DefaultValue="0" Name="@Param3"
                PropertyName="SelectedValue" />
        </SelectParameters>
    </asp:SqlDataSource>
    Sottogruppi<br />
    <asp:DropDownList ID="DropDownList_Sottogruppi" runat="server" DataSourceID="Sql_Sottogruppi"
        DataTextField="Descrizione" DataValueField="id" Width="200px" AutoPostBack="True">
    </asp:DropDownList>
    &nbsp;
    <asp:Button ID="Button_Abilita_Sottogruppi" runat="server" Text="Abilita" /><br />
    <br />
    Solo
    Disponibile &nbsp;&nbsp;
    <asp:CheckBox ID="CheckBox_Disponibile" runat="server" />
    &nbsp;&nbsp; In Promozione &nbsp;&nbsp;
    <asp:CheckBox ID="CheckBox_InPromo" runat="server" /><br />
    <br />
    Prodotti con spedizione
    <img src="Images/freeshipping.gif" />
    <asp:CheckBox ID="CheckBox_SpedizioneGratis" runat="server" /><br />
    <br />
    Prezzo Min &nbsp;
    <asp:TextBox ID="TextBox_PrezzoMin" runat="server" Width="50px">,00</asp:TextBox>
    € &nbsp; Max &nbsp;
    <asp:TextBox ID="TextBox_PrezzoMax" runat="server" Width="50px">,00</asp:TextBox>
    €<br />
    <br />
    Descrizione &nbsp;
    <asp:TextBox ID="Text_Descrizione" runat="server" Width="200px"></asp:TextBox><br />
    <br />
    <asp:Button ID="Button_Effettua_Ricerca" runat="server" Text="Effettua la ricerca"
        Width="200px" /><br />
</asp:Content>
