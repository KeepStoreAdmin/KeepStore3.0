<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="Setup_Listino_Personalizzato.aspx.vb" Inherits="Setup_Listino_Personalizzato" title="Untitled Page" %>

<%@ Register Assembly="Microsoft.ReportViewer.WebForms, Version=9.0.0.0, Culture=neutral, PublicKeyToken=B03F5F7F11D50A3A"
    Namespace="Microsoft.Reporting.WebForms" TagPrefix="rsweb" %>
<asp:Content ID="Content1" ContentPlaceHolderID="Contentplaceholder1" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
    <asp:SqlDataSource ID="SqlData_Listino_Personalizzato" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        InsertCommand="INSERT INTO listini_personalizzati(Nome_Listino, ID_Utente, IVA) VALUES (@Param1, @Param2, @Param3)"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT listini_personalizzati.* FROM listini_personalizzati" UpdateCommand="UPDATE listini_personalizzati SET Nome_Listino = @Param2 WHERE (ID = @Param1)">
        <InsertParameters>
            <asp:ControlParameter ControlID="TextBox_NomeListino" Name="@Param1" PropertyName="Text"
                Type="String" />
            <asp:SessionParameter Name="@Param2" SessionField="UtentiId" Type="Int32" />
            <asp:ControlParameter ControlID="CheckBox_IVA" Name="@Param3" PropertyName="Checked"
                Type="Boolean" />
        </InsertParameters>
        <UpdateParameters>
            <asp:SessionParameter Name="@Param1" SessionField="ID_Listino_Personalizzato" />
            <asp:ControlParameter ControlID="TextBox_CambiaNomeListino" Name="@Param2" PropertyName="Text" />
        </UpdateParameters>
    </asp:SqlDataSource>
    <asp:SqlDataSource ID="SqlData_Dettagli_Listino_Personalizzato" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT dettagli_listino_personalizzato.* FROM dettagli_listino_personalizzato" DeleteCommand="DELETE FROM dettagli_listino_personalizzato WHERE (ID_Listino_Personalizzato = @Param1)" InsertCommand="INSERT INTO dettagli_listino_personalizzato(ID_Listino_Personalizzato, ID_Settore, ID_Categoria, ID_Tipologia, Promo, Ricarico) VALUES (1,1,1,1,1,1)">
        <DeleteParameters>
            <asp:SessionParameter Name="@Param1" SessionField="ID_Listino_Personalizzato" />
        </DeleteParameters>
    </asp:SqlDataSource>
    <asp:SqlDataSource ID="SqlData_ListaListiniUtente" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT ID, Nome_Listino, ID_Utente, IVA, Data_Creazione FROM listini_personalizzati"></asp:SqlDataSource>
    &nbsp;<br />
    <asp:Panel ID="Panel_Principale" runat="server" Height="50px" Visible="False" Width="680px">
    <asp:Panel ID="Panel_NuovoListino" runat="server" Height="50px" Width="670px">
    Inserire il nome del listino
    <asp:TextBox ID="TextBox_NomeListino" runat="server" Width="150px" Wrap="False"></asp:TextBox>
    &nbsp;visualizza con IVA
    <asp:CheckBox ID="CheckBox_IVA" runat="server" Checked="True" />
    &nbsp;&nbsp;
    <asp:Button ID="Button_CreaListino" runat="server" Text="Crea Listino" Width="87px" /><br />
    <asp:Label ID="Label_Esito" runat="server" ForeColor="#FF0000" Text="Label" Visible="False"></asp:Label></asp:Panel>
        <br />
        <asp:Panel ID="Panel_ModificaListino" runat="server" Height="50px" Width="664px">
            Seleziona il tuo listino personalizzato &nbsp; &nbsp; &nbsp; &nbsp;&nbsp;
    <asp:DropDownList ID="DropDownList_ListiniUtente" runat="server" DataSourceID="SqlData_ListaListiniUtente"
        DataTextField="Nome_Listino" DataValueField="ID" Width="200px" AutoPostBack="True">
        <asp:ListItem Value="0">Seleziona Valore</asp:ListItem>
    </asp:DropDownList>
            &nbsp; &nbsp;&nbsp; 
            <br />
            <br />
            Cambia il nome al Listino&nbsp;&nbsp; &nbsp; &nbsp;<asp:TextBox ID="TextBox_CambiaNomeListino" runat="server" Width="200px"></asp:TextBox>
            &nbsp;&nbsp;
            <asp:Button ID="Button_AggiornaListino" runat="server" Text="Aggiorna" /><br />
            <asp:Label ID="Label_Cambia_Esito" runat="server" ForeColor="Red" Text="Label" Visible="False"></asp:Label><br />
            <asp:SqlDataSource ID="SqlDataSource_ListinoSelezionato" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                SelectCommand="SELECT ID, ID_Listino_Personalizzato, ID_Settore, ID_Categoria, ID_Tipologia, Promo, Ricarico FROM dettagli_listino_personalizzato">
            </asp:SqlDataSource>
            <br />
            <asp:GridView ID="GridView_ListinoSelezionato" runat="server" AutoGenerateColumns="False" DataKeyNames="ID"
                DataSourceID="SqlDataSource_ListinoSelezionato" Width="349px">
                <Columns>
                    <asp:BoundField DataField="ID" HeaderText="ID" InsertVisible="False" ReadOnly="True"
                        SortExpression="ID" />
                    <asp:BoundField DataField="ID_Listino_Personalizzato" HeaderText="ID_Listino_Personalizzato"
                        SortExpression="ID_Listino_Personalizzato" />
                    <asp:BoundField DataField="ID_Settore" HeaderText="ID_Settore" SortExpression="ID_Settore" />
                    <asp:BoundField DataField="ID_Categoria" HeaderText="ID_Categoria" SortExpression="ID_Categoria" />
                    <asp:BoundField DataField="ID_Tipologia" HeaderText="ID_Tipologia" SortExpression="ID_Tipologia" />
                    <asp:BoundField DataField="Promo" HeaderText="Promo" SortExpression="Promo" />
                    <asp:BoundField DataField="Ricarico" HeaderText="Ricarico" SortExpression="Ricarico" />
                </Columns>
            </asp:GridView>
        </asp:Panel>
        &nbsp;&nbsp;<br />
        <br />
        <br />
        <br />
        <asp:Panel ID="Panel_Listino" runat="server" Height="50px" Width="659px">
    <asp:SqlDataSource ID="Sql_ListaSettori" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT DISTINCT settori.id AS ID_Settore, settori.Descrizione, categorie.id AS ID_Categoria, categorie.Descrizione AS Categoria, tipologie.id AS ID_Tipologia, tipologie.Descrizione AS Tipologia, settori.Abilitato, tipologie.Abilitato AS Expr1, categorie.Abilitato AS Expr2 FROM categorie LEFT OUTER JOIN tipologie ON categorie.id = tipologie.CategorieId LEFT OUTER JOIN gruppi ON categorie.id = tipologie.CategorieId RIGHT OUTER JOIN settori ON categorie.SettoriId = settori.id HAVING (settori.Abilitato > 0) AND (categorie.Abilitato > 0) OR (settori.Abilitato > 0) AND (tipologie.Abilitato > 0) OR (settori.Abilitato > 0) AND (categorie.Abilitato > 0) AND (tipologie.Abilitato > 0) ORDER BY settori.Descrizione, Categoria">
    </asp:SqlDataSource>
            <br />
    <asp:GridView ID="GridView_ListinoCompleto" runat="server" AutoGenerateColumns="False" DataSourceID="Sql_ListaSettori" GridLines="None" PageSize="30">
        <Columns>
            <asp:TemplateField HeaderText="ID" Visible="False">
                <ItemTemplate>
                    <asp:Label ID="Label_IDSettore" runat="server" Text='<%# Eval("ID_Settore") %>'></asp:Label><br />
                    <asp:Label ID="Label_IDCategoria" runat="server" Text='<%# Eval("ID_Categoria") %>'></asp:Label><br />
                    <asp:Label ID="Label_IDTipologia" runat="server" Text='<%# Eval("ID_Tipologia") %>'></asp:Label>
                </ItemTemplate>
            </asp:TemplateField>
            <asp:TemplateField HeaderText="Settore">
                <ItemTemplate>
                    <asp:Label ID="Label1" runat="server" Text='<%# Eval("Descrizione") %>' Font-Bold="False"></asp:Label>&nbsp;<strong>&gt;</strong>
                    <asp:Label ID="Label2" runat="server" Text='<%# Eval("Categoria") %>'></asp:Label>
                    <asp:Label ID="Label3" runat="server" Text='<%# Eval("Tipologia") %>'></asp:Label>
                </ItemTemplate>
                <ItemStyle HorizontalAlign="Left" VerticalAlign="Middle" />
            </asp:TemplateField>
            <asp:TemplateField HeaderText="Attivo">
                <ItemTemplate>
                    <asp:CheckBox ID="CheckBox_Attivo" runat="server" BorderStyle="None" />
                </ItemTemplate>
                <ItemStyle HorizontalAlign="Center" VerticalAlign="Middle" />
            </asp:TemplateField>
            <asp:TemplateField HeaderText="Ricarico">
                <ItemTemplate>
                    <asp:TextBox ID="TextBox_Ricarico" runat="server" Width="30px"></asp:TextBox>
                </ItemTemplate>
                <ItemStyle HorizontalAlign="Center" VerticalAlign="Middle" />
            </asp:TemplateField>
            <asp:TemplateField HeaderText="Promo">
                <ItemTemplate>
                    <asp:CheckBox ID="CheckBox_Promo" runat="server" BorderStyle="None" />
                </ItemTemplate>
                <ItemStyle HorizontalAlign="Center" VerticalAlign="Middle" />
            </asp:TemplateField>
        </Columns>
    </asp:GridView>
        </asp:Panel>
        <br />
    </asp:Panel>
    <br />
    &nbsp;<br />
    <br />
    <br />
    <br />
    &nbsp;<br />
    <br />
    <br />
    <br />
</asp:Content>

