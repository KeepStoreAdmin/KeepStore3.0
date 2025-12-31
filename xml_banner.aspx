<%@ Page Language="VB" AutoEventWireup="false" CodeFile="xml_banner.aspx.vb" Inherits="xml_banner" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" >
<head runat="server">
    <title>Pagina senza titolo</title>
</head>
<body>
    <form id="form1" runat="server">
    <div>
        <asp:GridView ID="GridView_Banner" runat="server" AutoGenerateColumns="False" DataKeyNames="id"
            DataSourceID="SqlDataSource_Pubblicita" Font-Size="8pt">
            <Columns>
                <asp:BoundField DataField="id" HeaderText="id" InsertVisible="False" ReadOnly="True"
                    SortExpression="id" />
                <asp:BoundField DataField="img_path" HeaderText="img_path" SortExpression="img_path" />
                <asp:BoundField DataField="titolo" HeaderText="titolo" SortExpression="titolo" />
                <asp:BoundField DataField="descrizione" HeaderText="descrizione" SortExpression="descrizione" />
                <asp:BoundField DataField="link" HeaderText="link" SortExpression="link" />
            </Columns>
        </asp:GridView>
        <asp:SqlDataSource ID="SqlDataSource_Pubblicita" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato FROM pubblicita" UpdateCommand="UPDATE pubblicita SET numero_impressioni = numero_impressioni + 1 WHERE (id = 1)">
        </asp:SqlDataSource>
    
    </div>
    </form>
</body>
</html>
