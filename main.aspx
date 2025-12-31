<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="main.aspx.vb" Inherits="main" title="Untitled Page" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
    <asp:SqlDataSource ID="sdsPagina" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM pagine WHERE ((Abilitato = ?Abilitato) AND (AziendeId = ?AziendeId) AND (id = ?id))">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="AziendeId" SessionField="AziendaID" Type="Int32" />
            <asp:QueryStringParameter Name="id" QueryStringField="id" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>
        <div style="overflow:hidden; height:auto; width:100%;">
        <asp:FormView ID="fvPage" runat="server" RenderOuterTable=false DataKeyNames="id" DataSourceID="sdsPagina" style="overflow:hidden;">

            <ItemTemplate>
            <h1><asp:Label ID="lblTitolo" runat="server"  Text='<%# Bind("Nome") %>' ></asp:Label></h1>
                <br />
                <asp:Label ID="htmlLabel" runat="server" Text='<%# Bind("html") %>' Font-Size="10pt"></asp:Label><br />
                <br />
            </ItemTemplate>
        </asp:FormView>
        </div>
    <br />
    <div style="margin:auto; text-align:center; vertical-align:middle">
    <div id="Form_Contatti"  runat="server" style="margin:auto; padding-top:30px; background-repeat:no-repeat; background-image:url('Images/Contattaci.jpg'); width: 440px; height: 290px; text-align:left; ">
        &nbsp;<table style="width: 424px; height: 246px">
            <tr>
                <td style="width: 112px; text-align: right">
                    Nome &nbsp;
                </td>
                <td style="width: 224px">
                    <asp:TextBox ID="TextBox_nome" runat="server" Width="150px"></asp:TextBox></td>
            </tr>
            <tr>
                <td style="width: 112px; text-align: right">
                    Email &nbsp;</td>
                <td style="width: 224px">
                    <asp:TextBox ID="TextBox_email" runat="server" Width="150px"></asp:TextBox></td>
            </tr>
            <tr>
                <td style="width: 112px; text-align: right">
                    Oggetto &nbsp;</td>
                <td style="width: 224px">
                    <asp:DropDownList ID="DropDownList_subject" runat="server" Width="296px">
                        <asp:ListItem Selected="True">Informazioni generali</asp:ListItem>
                        <asp:ListItem>Informazioni sulla spedizione</asp:ListItem>
                        <asp:ListItem>Informazioni sul prodotto</asp:ListItem>
                        <asp:ListItem>Informazioni sul pagamento</asp:ListItem>
                    </asp:DropDownList></td>
            </tr>
            <tr style="vertical-align: top">
                <td style="width: 112px; height: 40px; text-align: right">
                    Testo del messaggio</td>
                <td style="width: 224px; height: 40px">
                    <asp:TextBox ID="TextBox_testo" runat="server" Height="134px" TextMode="MultiLine"
                        Width="296px"></asp:TextBox></td>
            </tr>
            <tr>
                <td style="width: 112px; height: 26px; text-align: right">
                </td>
                <td style="width: 224px; height: 26px">
                    <asp:Button ID="Button_Invia" runat="server" Text="Invia Messaggio" Width="106px" />
                    <asp:Label ID="Label_esito" runat="server" Font-Bold="True" ForeColor="Red" Font-Names="arial" Font-Size="7pt"></asp:Label></td>
            </tr>
        </table>
    </div>
    </div>
</asp:Content>

