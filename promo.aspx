<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="promo.aspx.vb" Inherits="_promo" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">

    <asp:TextBox ID="tbData" runat="server" Visible=false></asp:TextBox>
    <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM offerte WHERE ((DaListino<=?NListino AND AListino>=?NListino) OR UtentiID=@UtentiID) AND (Abilitato=1) AND (Vetrina=?Vetrina) AND (DataInizio<=?Data) AND (DataFine>=?Data) ORDER BY RAND() limit ?Numero">
        <SelectParameters>
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
            <asp:SessionParameter Name="UtentiID" SessionField="UtentiID" Type="Int32" />
            <asp:ControlParameter Name="Data" ControlID="tbData" Type="DateTime"/>
            <asp:Parameter DefaultValue="1" Name="Vetrina" Type="Int32" />
            <asp:SessionParameter SessionField="VetrinaPromoFissi" Name="Numero" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource> 
   <asp:SqlDataSource ID="sdsPromoRandom" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM offerte WHERE ((DaListino<=?NListino AND AListino>=?NListino) OR UtentiID=@UtentiID) AND (Abilitato=1) AND (Vetrina=?Vetrina) AND (DataInizio<=?Data) AND (DataFine>=?Data) ORDER BY RAND() limit ?Numero">
        <SelectParameters>
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
            <asp:SessionParameter Name="UtentiID" SessionField="UtentiID" Type="Int32" />
            <asp:ControlParameter Name="Data" ControlID="tbData" Type="DateTime"/>
            <asp:Parameter DefaultValue="0" Name="Vetrina" Type="Int32" />
            <asp:SessionParameter SessionField="VetrinaPromoRandom" Name="Numero" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource> 
    <asp:SqlDataSource ID="sdsPromoFine" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM offerte WHERE ((DaListino<=?NListino AND AListino>=?NListino) OR UtentiID=@UtentiID) AND (Abilitato=1) AND (DataInizio<=?Data) AND (DataFine>=?Data) ORDER BY DataFine limit ?Numero">
        <SelectParameters>
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
            <asp:SessionParameter Name="UtentiID" SessionField="UtentiID" Type="Int32" />
            <asp:ControlParameter Name="Data" ControlID="tbData" Type="DateTime"/>
            <asp:SessionParameter SessionField="VetrinaPromoScadenza" Name="Numero" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource> 
     <asp:SqlDataSource ID="sdsPromoInizio" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM offerte WHERE ((DaListino<=?NListino AND AListino>=?NListino) OR UtentiID=@UtentiID) AND (Abilitato=1) AND (DataInizio<=?Data) AND (DataFine>=?Data) ORDER BY DataInizio desc limit ?Numero">
        <SelectParameters>
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
            <asp:SessionParameter Name="UtentiID" SessionField="UtentiID" Type="Int32" />
            <asp:ControlParameter Name="Data" ControlID="tbData" Type="DateTime"/>
            <asp:SessionParameter SessionField="VetrinaPromoInizio" Name="Numero" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource> 
            
         <!-- vetrina -->
            <div id="boxpromo">
            <h1>..:: Promozioni in Vetrina ::..</h1>
            
                <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo">
                <ItemTemplate>
                <ul>
                    <li><asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "articoli.aspx?pid="& Eval("id") %>' ToolTip='<%# Eval("Descrizione") %>'><asp:Image ID="Image1" runat="server" ImageUrl='<%# "~/Public/offerte/_" & Eval("Immagine") %>' height="60" /></asp:HyperLink></li>
                    <li><asp:HyperLink ID="HyperLink1" runat="server" Text='<%# left(Eval("Descrizione"),40) %>' NavigateUrl='<%# "articoli.aspx?pid="& Eval("id") %>' CssClass="titolopromo"></asp:HyperLink></li>
                    <li>Scade il <asp:Label ID="Label1"  runat="server" Text='<%# Eval("DataFine","{0:d}") %>' ></asp:Label></li>
                </ul>                
                </ItemTemplate>
                </asp:Repeater>
                
                <asp:Repeater ID="rPromoRandom" runat="server" DataSourceID="sdsPromoRandom">
                <ItemTemplate>
                <ul>
                    <li><asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "articoli.aspx?pid="& Eval("id") %>' ToolTip='<%# Eval("Descrizione") %>'><asp:Image ID="Image1" runat="server" ImageUrl='<%# "~/Public/offerte/_" & Eval("Immagine") %>' height="60" /></asp:HyperLink></li>
                    <li><asp:HyperLink ID="HyperLink1" runat="server" Text='<%# left(Eval("Descrizione"),40) %>' NavigateUrl='<%# "articoli.aspx?pid="& Eval("id") %>' CssClass="titolopromo"></asp:HyperLink></li>
                    <li>Scade il <asp:Label ID="Label1"  runat="server" Text='<%# Eval("DataFine","{0:d}") %>' ></asp:Label></li>
                </ul>                
                </ItemTemplate>
                </asp:Repeater>          
     
           </div>
        <!-- end vetrina -->

         <!-- ultime -->
            <div id="boxpromo">
            <h1>..:: Le ultime Promozioni ::..</h1>
            
                 <asp:Repeater ID="rPromoInizio" runat="server" DataSourceID="sdsPromoInizio">
                <ItemTemplate>
                <ul>
                    <li><asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "articoli.aspx?pid="& Eval("id") %>' ToolTip='<%# Eval("Descrizione") %>'><asp:Image ID="Image1" runat="server" ImageUrl='<%# "~/Public/offerte/_" & Eval("Immagine") %>' height="60" /></asp:HyperLink></li>
                    <li><asp:HyperLink ID="HyperLink1" runat="server" Text='<%# left(Eval("Descrizione"),40) %>' NavigateUrl='<%# "articoli.aspx?pid="& Eval("id") %>' CssClass="titolopromo"></asp:HyperLink></li>
                    <li>Scade il <asp:Label ID="Label1"  runat="server" Text='<%# Eval("DataFine","{0:d}") %>' ></asp:Label></li>
                </ul>                
                </ItemTemplate>
                </asp:Repeater>

           </div>
        <!-- end ultime -->

         <!-- scadenza -->
            <div id="boxpromo">
            <h1>..:: Promozioni in scadenza ::..</h1>
            
                <asp:Repeater ID="rPromoFine" runat="server" DataSourceID="sdsPromoFine">
                <ItemTemplate>
                <ul>
                    <li><asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "articoli.aspx?pid="& Eval("id") %>' ToolTip='<%# Eval("Descrizione") %>'><asp:Image ID="Image1" runat="server" ImageUrl='<%# "~/Public/offerte/_" & Eval("Immagine") %>' height="60" /></asp:HyperLink></li>
                    <li><asp:HyperLink ID="HyperLink1" runat="server" Text='<%# left(Eval("Descrizione"),40) %>' NavigateUrl='<%# "articoli.aspx?pid="& Eval("id") %>' CssClass="titolopromo"></asp:HyperLink></li>
                    <li>Scade il <asp:Label ID="Label1"  runat="server" Text='<%# Eval("DataFine","{0:d}") %>' ></asp:Label></li>
                </ul>                
                </ItemTemplate>
                </asp:Repeater>

           </div>
        <!-- end scadenza -->

  <br /><asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label><br /><br />

</asp:Content>

