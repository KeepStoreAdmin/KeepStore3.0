<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="promozioni.aspx.vb" Inherits="promozioni"  %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">

<h1>PROMOZIONI » TUTTE LE OFFERTE</h1>

    <asp:SqlDataSource ID="sdsScadenze" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT DataFine FROM offerte WHERE ((DaListino<=?NListino AND AListino>=?NListino) OR UtentiID=@UtentiID) AND (Abilitato=1) AND (DataInizio<=?Data) AND (DataFine>=?Data) Group BY DataFine">
        <SelectParameters>
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
            <asp:SessionParameter Name="UtentiID" SessionField="UtentiID" Type="Int32" />
            <asp:ControlParameter Name="Data" ControlID="tbData" Type="DateTime"/>
        </SelectParameters>
    </asp:SqlDataSource> 
    
    <asp:SqlDataSource ID="sdsDettagli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT MarcheId,MarcheDescrizione,SettoriId,SettoriDescrizione,CategorieId,CategorieDescrizione,TipologieId,TipologieDescrizione,GruppiId,GruppiDescrizione,SottogruppiId,SottogruppiDescrizione,ArticoliId,ArticoliDescrizione1 FROM vOfferteDettagliCompleta WHERE ((DaListino<=?NListino AND AListino>=?NListino) OR UtentiID=@UtentiID) AND (Abilitato=1) AND (DataInizio<=?Data) AND (DataFine>=?Data) Group By MarcheId,MarcheDescrizione,SettoriId,SettoriDescrizione,CategorieId,CategorieDescrizione,TipologieId,TipologieDescrizione,GruppiId,GruppiDescrizione,SottogruppiId,SottogruppiDescrizione,ArticoliId,ArticoliDescrizione1">
        <SelectParameters>
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
            <asp:SessionParameter Name="UtentiID" SessionField="UtentiID" Type="Int32" />
            <asp:ControlParameter Name="Data" ControlID="tbData" Type="DateTime"/>
        </SelectParameters>
    </asp:SqlDataSource>     
    
    <asp:TextBox ID="tbData" runat="server" Visible="false"></asp:TextBox>
    <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM offerte WHERE ((DaListino<=?NListino AND AListino>=?NListino) OR UtentiID=@UtentiID) AND (Abilitato=1) AND (DataInizio<=?Data) AND (DataFine>=?Data) ORDER BY Descrizione">
        <SelectParameters>
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
            <asp:SessionParameter Name="UtentiID" SessionField="UtentiID" Type="Int32" />
            <asp:ControlParameter Name="Data" ControlID="tbData" Type="DateTime"/>
        </SelectParameters>
    </asp:SqlDataSource> 
    
    <div style="height:5px"></div>
    <table cellspacing="0" cellpadding="3" width="100%" runat="server" id="tNavig">
        <tr>
        <td valign="top" style="border-left-style: solid; border-left-width: 1px; " nowrap width="50%">

        <asp:DataList ID="DataList4" runat="server" DataSourceID="sdsPromo" DataKeyField="id" Font-Size="7pt" Height="120px" Width="100%" RepeatLayout="Flow" style="overflow-y:auto;overflow-x:hidden;SCROLLBAR-SHADOW-COLOR:whitesmoke;SCROLLBAR-ARROW-COLOR:#E12825;SCROLLBAR-DARKSHADOW-COLOR:white;SCROLLBAR-BASE-COLOR:white" EnableViewState="False">
            <SelectedItemStyle Font-Bold="True" />
            <HeaderTemplate>
                <asp:Label ID="Label2" runat="server" Font-Bold="true" ForeColor="#E12825" Text="::"></asp:Label>
                <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl="promozioni.aspx?pid=0" Text="Tutti"   ToolTip="Tutti i risultati"></asp:HyperLink>
            </HeaderTemplate>
            <ItemTemplate>
                <asp:Label ID="Label2" runat="server" Font-Bold="true" ForeColor="#E12825" Text="»"></asp:Label>
                <asp:HyperLink ID="HyperLink1" runat="server"  NavigateUrl='<%# "promozioni.aspx?pid="& Eval("id") %>'  TabIndex='<%# Eval("id") %>' Text='<%# Eval("Descrizione") %>' ></asp:HyperLink>
            </ItemTemplate>
        </asp:DataList>
        
        </td>
        <td valign="top" style="border-left-style: solid; border-left-width: 1px;" nowrap width="0%">
    
    <asp:DataList ID="DataList1" Visible=false runat="server" DataSourceID="sdsScadenze" DataKeyField="DataFine" EnableViewState="False" Font-Size="7pt" Height="120px" RepeatLayout="Flow" Width="100%" style="overflow-y:auto;overflow-x:hidden;SCROLLBAR-SHADOW-COLOR:whitesmoke;SCROLLBAR-ARROW-COLOR:#E12825;SCROLLBAR-DARKSHADOW-COLOR:white;SCROLLBAR-BASE-COLOR:white">
        <ItemTemplate>
            <asp:Label ID="Label2" runat="server" Text="»" Font-Bold="true" ForeColor="#E12825"></asp:Label> <asp:HyperLink ID="HyperLink1" runat="server" NavigateUrl='<%# "promozioni.aspx?data="& Eval("DataFine") %>' Text='<%# "Scade il "& Eval("DataFine") %>' TabIndex="0" ></asp:HyperLink>
        </ItemTemplate>
        <HeaderTemplate>
        <asp:Label ID="Label2" runat="server" Text="::" Font-Bold="true" ForeColor="#E12825"></asp:Label> <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl="promozioni.aspx" Text="TuttI" ToolTip="Tutti i risultati"></asp:HyperLink>
        </HeaderTemplate>
        <SelectedItemStyle Font-Bold="True" />
    </asp:DataList>
    
            </td>
        <td valign="top" style="border-left-style: solid; border-left-width: 1px; border-right-style: solid; border-right-width: 1px;" nowrap width="50%">
    
    <asp:DataList ID="DataList2" runat="server" DataSourceID="sdsDettagli" DataKeyField="marcheid" EnableViewState="False" Font-Size="7pt" Height="120px" RepeatLayout="Flow" Width="100%" style="overflow-y:auto;overflow-x:hidden;SCROLLBAR-SHADOW-COLOR:whitesmoke;SCROLLBAR-ARROW-COLOR:#E12825;SCROLLBAR-DARKSHADOW-COLOR:white;SCROLLBAR-BASE-COLOR:white">
        <ItemTemplate>
            <asp:HyperLink ID="HyperLink1" runat="server" NavigateUrl='<%# "promozioni.aspx?" %>'  TabIndex="0" ></asp:HyperLink>
            <asp:Label ID="lblMarcheId" runat="server" Text='<%# Eval("MarcheId") %>' Visible=false></asp:Label><asp:Label Visible=false ID="lblMarcheDescrizione" runat="server" Text='<%# Eval("MarcheDescrizione") %>'></asp:Label>
            <asp:Label ID="lblSettoriId" runat="server" Text='<%# Eval("SettoriId") %>' Visible=false></asp:Label><asp:Label Visible=false ID="lblSettoriDescrizione" runat="server" Text='<%# Eval("SettoriDescrizione") %>'></asp:Label>
            <asp:Label ID="lblCategorieId" runat="server" Text='<%# Eval("CategorieId") %>' Visible=false></asp:Label><asp:Label Visible=false ID="lblCategorieDescrizione" runat="server" Text='<%# Eval("CategorieDescrizione") %>'></asp:Label>
            <asp:Label ID="lblTipologieId" runat="server" Text='<%# Eval("TipologieId") %>' Visible=false></asp:Label><asp:Label Visible=false ID="lblTipologieDescrizione" runat="server" Text='<%# Eval("TipologieDescrizione") %>'></asp:Label>
            <asp:Label ID="lblGruppiId" runat="server" Text='<%# Eval("GruppiID") %>' Visible=false></asp:Label><asp:Label Visible=false ID="lblGruppiDescrizione" runat="server" Text='<%# Eval("GruppiDescrizione") %>'></asp:Label>
            <asp:Label ID="lblSottogruppiId" runat="server" Text='<%# Eval("SottogruppiId") %>' Visible=false></asp:Label><asp:Label Visible=false ID="lblSottogruppiDescrizione" runat="server" Text='<%# Eval("SottogruppiDescrizione") %>'></asp:Label>
            <asp:Label ID="lblArticoliID" runat="server" Text='<%# Eval("ArticoliId") %>' Visible=false></asp:Label><asp:Label Visible=false ID="lblArticoliDescrizione" runat="server" Text='<%# Eval("ArticoliDescrizione1") %>'></asp:Label>
        </ItemTemplate>
        <HeaderTemplate>
        <asp:Label ID="Label2" runat="server" Text="::" Font-Bold="true" ForeColor="#E12825"></asp:Label> <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl="promozioni.aspx?pmr=0&pst=0&pct=0&ptp=0&pgr=0&psg=0&art=0" Text="Tutti" ToolTip="Tutti i risultati"></asp:HyperLink>
        </HeaderTemplate>
        <SelectedItemStyle Font-Bold="True" />
    </asp:DataList>
    
        </td>
        </tr>
    </table>

    <hr size="2"/>
   
   
    <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione1, PrezzoAcquisto, Img1 FROM varticolibase ORDER BY Codice, Descrizione1" EnableViewState="False">
    </asp:SqlDataSource>
    
    <center>
        <br />
    <asp:Label ID="lblTrovati" runat="server" Font-Bold="True" ForeColor="#E12825" ></asp:Label>
    articoli trovati <i>(<asp:Label ID="lblLinee" runat="server" Text="0" Font-Size="8pt">></asp:Label> per pagina)<br />
        <br />
    </i>
    </center>
    
    <asp:GridView ID="GridView1" runat="server" AutoGenerateColumns="False" DataKeyNames="id" Width="100%" DataSourceID="sdsArticoli" AllowPaging="True" AllowSorting="True" Font-Size="8pt" GridLines="None" CellPadding="3">
        <Columns>
            <asp:ImageField DataAlternateTextField="Descrizione1" DataImageUrlField="img1" DataImageUrlFormatString="~/Public/foto/test.jpg"
                HeaderText="Ordina &gt;&gt;" NullImageUrl="~/Public/foto/nofoto.gif">
                <HeaderStyle ForeColor="#E12825" />
                <ItemStyle Height="60px" HorizontalAlign="Center" VerticalAlign="Middle"
                    Width="80px" />
            </asp:ImageField>
            <asp:TemplateField HeaderText="[Descrizione]" SortExpression="Descrizione1">
                <ItemTemplate>
                    <asp:HyperLink ID="HyperLink5" ToolTip="Scheda Prodotto" runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("id") %>' >
                    <asp:Label ID="Label8" runat="server" Text='<%# Eval("Descrizione1") %>' ForeColor="#e12825" Font-Bold="true"></asp:Label><br />
                    <asp:Label ID="Label4" runat="server" Text="Marca: " ></asp:Label><asp:Label ID="Label2" runat="server" Text='<%# Eval("MarcheDescrizione") %>' Font-Bold="True" ></asp:Label>
                    &nbsp;<asp:Label ID="Label5" runat="server" Text="Codice: " ></asp:Label><asp:Label ID="Label3" runat="server" Font-Bold="True" Text='<%# Eval("Codice") %>' ></asp:Label>
                    &nbsp;<asp:Label ID="Label6" runat="server" Text="Ean: "></asp:Label><asp:Label ID="Label7" runat="server" Font-Bold="True" Text='<%# Eval("Ean") %>' ></asp:Label>
                    </asp:HyperLink> <br />
                    <asp:Label ID="Label9" runat="server" Text="In Promozione fino al " BackColor="#e12825" ForeColor="white"></asp:Label><asp:Label ID="Label1" runat="server" Text='<%# Eval ("DataFinePromo") %>' BackColor="#e12825" ForeColor="white" Font-Bold="false"></asp:Label><asp:Label ID="Label10" runat="server" Text=" | Prezzo: " BackColor="#e12825" ForeColor="white" Visible='<%# Eval("prezzopromo") %>'></asp:Label><asp:Label ID="Label11" runat="server" Text='<%# Eval ("PrezzoPromo") &" €" %>' Visible='<%# Eval("prezzopromo")  %>' BackColor="#e12825" ForeColor="white" Font-Bold=true></asp:Label><asp:Label ID="Label12" runat="server" Text=" | Sconto: " BackColor="#e12825" ForeColor="white" Visible='<%# Eval("scontopromo") %>'></asp:Label><asp:Label ID="Label13" runat="server" Text='<%# Eval ("scontopromo") &" %" %>' Visible='<%# Eval("scontopromo") %>' BackColor="#e12825" ForeColor="white" Font-Bold=true></asp:Label>
                </ItemTemplate>
            </asp:TemplateField>
            
            
              <asp:TemplateField HeaderText="[Disp.]" SortExpression="Disponibilita">
                <ItemTemplate><asp:Label ID="lblDispo" runat="server" Text='<%# Eval("Disponibilita")%>' Visible="false"></asp:Label><asp:Label ID="lblArrivo" runat="server" Text='<%# Eval("InOrdine")%>' Visible="false"></asp:Label><asp:Label ID="lblImpegnata" runat="server" Text='<%# Eval("Impegnata")%>' Visible="false"></asp:Label><asp:Image ID="imgDispo" runat="server"  /></ItemTemplate>
                  <HeaderStyle HorizontalAlign="Center" />
                  <ItemStyle HorizontalAlign="Center" VerticalAlign="Middle" />
              </asp:TemplateField>
            <asp:BoundField DataField="Impegnata" HeaderText="[I]" SortExpression="Impegnata" Visible="False">
                <HeaderStyle HorizontalAlign="Center" />
                <ItemStyle HorizontalAlign="Center" />
            </asp:BoundField>
            <asp:BoundField DataField="InOrdine" HeaderText="[A]" SortExpression="InOrdine" Visible="False">
                <HeaderStyle HorizontalAlign="Center" />
                <ItemStyle HorizontalAlign="Center" />
            </asp:BoundField>
              
            
            <asp:TemplateField HeaderText="[Prezzo]" SortExpression="PrezzoIvato">
                <ItemTemplate>
                    <asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>'></asp:Label><asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Visible="false"></asp:Label><asp:Label ID="lblCodice" runat="server" Text='<%# Bind("Codice") %>' Visible="false"></asp:Label><asp:Label ID="lblDescrizione" runat="server" Text='<%# Bind("Descrizione1") %>' Visible="false"></asp:Label><asp:Label ID="lblID" runat="server" Text='<%# Bind("ID") %>' Visible="false"></asp:Label><br />
                         
                            <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbQuantita"
                    Display="Dynamic" ErrorMessage="!" SetFocusOnError="True"></asp:RequiredFieldValidator><asp:CompareValidator
                        ID="CompareValidator2" runat="server" ControlToValidate="tbQuantita" Display="Dynamic"
                        ErrorMessage="!" Operator="GreaterThan" SetFocusOnError="True"
                        Type="Integer" ValueToCompare="0"></asp:CompareValidator><asp:TextBox ID="tbQuantita" runat="server" Width="20px" style="text-align:right;font-size:8pt">1</asp:TextBox>
                <asp:ImageButton ID="ImageButton1" runat="server" ImageUrl="Images/cart.gif" ToolTip="Aggiungi al Carrello" OnClick="ImageButton1_Click" />
                                
         
                   <asp:HyperLink ID="HyperLink2" Visible="false" runat="server" ImageUrl='<%# "images/cart.gif" %>' NavigateUrl='<%# "articolo.aspx?id="& Eval("id") %>' Text="Scheda Prodotto"></asp:HyperLink>
                </ItemTemplate>
                <ItemStyle Font-Bold="True" ForeColor="#E12825" HorizontalAlign="Right" Wrap="False" />
                <HeaderStyle HorizontalAlign="Right" />
            </asp:TemplateField>
        </Columns>
        <HeaderStyle HorizontalAlign="Left" Font-Bold="False" Font-Size="8pt" />
        <PagerStyle CssClass="nav" Font-Bold="True" />
        <AlternatingRowStyle BackColor="WhiteSmoke" />
        <PagerSettings Position="TopAndBottom" />
    </asp:GridView>
    
    <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label><br /><br />
    
    
</asp:Content>

