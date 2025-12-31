<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="rettificaMagazzino.aspx.vb" Inherits="Articoli" MaintainScrollPositionOnPostback="true" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">

    <h1> 
    <asp:FormView ID="FormView1" runat="server" DataSourceID="sdsCategorie" EnableViewState="False">
        <ItemTemplate>
    <asp:Label ID="lblSettore" runat="server" Text='<%# ucase(Eval("SettoriDescrizone")) %>' EnableViewState="False"></asp:Label>
            »
    <asp:Label ID="lblCategoria" runat="server" Text='<%# Eval("Descrizione") %>' EnableViewState="False"></asp:Label>
        </ItemTemplate>
    </asp:FormView>
            <asp:Label ID="lblRicerca" runat="server" Text="Risultato ricerca per:" Font-Bold="False" Visible="False"></asp:Label>
            <asp:Label ID="lblRisultati" runat="server" Font-Bold="True" ></asp:Label></h1>

<asp:SqlDataSource ID="sdsCategorie" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione, SettoriCodice, SettoriDescrizone FROM vCategorieSettori WHERE ((Abilitato = ?Abilitato) AND (ID = ?ID)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="ID" SessionField="ct" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>


    <asp:SqlDataSource ID="sdsTipologie" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vcategorietipologie WHERE ((Abilitato = ?Abilitato) AND (SettoriId = ?SettoriId) AND (CategorieId = ?CategorieId)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
             <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
            <asp:SessionParameter Name="CategorieId" SessionField="ct" Type="String" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>
    
    <asp:SqlDataSource ID="sdsGruppo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vcategoriegruppi WHERE ((Abilitato = ?Abilitato) AND (SettoriId = ?SettoriId) AND (CategorieId = ?CategorieId)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
             <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
            <asp:SessionParameter Name="CategorieId" SessionField="ct" Type="String" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>
    <asp:SqlDataSource ID="sdsSottogruppo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vcategoriesottogruppi WHERE ((Abilitato = ?Abilitato) AND (SettoriId = ?SettoriId) AND (CategorieId = ?CategorieId)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
             <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
            <asp:SessionParameter Name="CategorieId" SessionField="ct" Type="String" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource><asp:SqlDataSource ID="sdsMarche" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vcategoriemarche WHERE Abilitato=@Abilitato AND SettoriId=?SettoriId AND CategorieId=?CategorieId ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
            <asp:SessionParameter Name="CategorieId" SessionField="ct" Type="String" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>
 <table cellspacing="0" cellpadding="1" width="100%" runat="server" id="tNavig">
    <tr>

        <td valign="top" style="border-left-style: solid; border-left-width: 1px; height: 103px;" nowrap="nowrap" width="165px">
        <asp:DataList ID="DataList4" runat="server" DataSourceID="sdsMarche" DataKeyField="marcheid" CellPadding="-1" Font-Size="8pt" Height="150px" Width="100%" RepeatLayout="Flow" style="overflow-y:auto;overflow-x:hidden;SCROLLBAR-SHADOW-COLOR:whitesmoke;SCROLLBAR-ARROW-COLOR:#E12825;SCROLLBAR-DARKSHADOW-COLOR:white;SCROLLBAR-BASE-COLOR:white" EnableViewState="False">
            <SelectedItemStyle Font-Bold="True" />
            <HeaderTemplate>
                <div style=" font-weight:bold; font-size:10pt; background-position: left top; color:White; background-image:url('Public/Images/back.jpg'); background-repeat:repeat-x; text-align:center;">
                    MARCHE
                </div>
                <asp:Label ID="Label2" runat="server" Font-Bold="true" ForeColor="#E12825" Text="::"></asp:Label>
                <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl='<%# "rettificaMagazzino.aspx?ct="&Session.item("ct")&"&mr=0&tp="&Session.item("tp")&"&gr="&Session.item("gr")&"&sg="&Session.item("sg")&"&q="&Session.item("q")&"&spedgratis="&Session("SpedGratis")&"&inpromo=" & Request.QueryString("inpromo") %>' Text="Tutti" ToolTip="Visualizza Tutti"></asp:HyperLink>
            </HeaderTemplate>
            <ItemTemplate>
                <asp:Label ID="Label2" runat="server" Font-Bold="True" ForeColor="#E12825" Text="»"></asp:Label>
                <asp:HyperLink ID="HyperLink1" runat="server" NavigateUrl='<%# "rettificaMagazzino.aspx?ct="&Session.item("ct")&"&mr="& Eval("marcheid")&"&tp="& Session.item("tp")&"&gr="& Session.item("gr")&"&sg="& Session.item("sg")&"&q="&Session.item("q")&"&spedgratis="&Session("SpedGratis")&"&inpromo=" & Request.QueryString("inpromo") %>' TabIndex='<%# Eval("marcheid") %>' Text='<%# Eval("Descrizione") %>' ToolTip="Applica/Rimuovi Filtro"></asp:HyperLink> 
                <asp:Label ID="Label9" runat="server" Text='<%# "<font color=#E12825>("& Eval("Numero") &")</font>"%>'></asp:Label>
            </ItemTemplate>
        </asp:DataList></td><td valign="top" style="border-left-style: solid; border-left-width: 1px; height: 103px;" nowrap="nowrap" width="25%">
    
    <asp:DataList ID="DataList1" runat="server" DataSourceID="sdsTipologie" DataKeyField="tipologieid" EnableViewState="False" Font-Size="8pt" Height="150px" RepeatLayout="Flow" width="165px" style="overflow-y:auto;overflow-x:hidden;SCROLLBAR-SHADOW-COLOR:whitesmoke;SCROLLBAR-ARROW-COLOR:#E12825;SCROLLBAR-DARKSHADOW-COLOR:white;SCROLLBAR-BASE-COLOR:white">
        <ItemTemplate>
            <asp:Label ID="Label2" runat="server" Text="»" Font-Bold="true" ForeColor="#E12825"></asp:Label> 
            <asp:HyperLink ID="HyperLink1" runat="server" NavigateUrl='<%# "rettificaMagazzino.aspx?ct="&Session.item("ct")&"&mr="& Session.item("marcheid")&"&tp="& Eval("TipologieId")&"&gr="& Session.item("gr")&"&sg="& Session.item("sg")&"&q="&Session.item("q")&"&spedgratis="&Session("SpedGratis")&"&inpromo=" & Request.QueryString("inpromo") %>'  Text='<%# Eval("Descrizione") %>' TabIndex='<%# Eval("tipologieid") %>' ToolTip="Applica/Rimuovi Filtro"></asp:HyperLink> 
            <asp:Label ID="Label9" runat="server" Text='<%# "<font color=#E12825>("& Eval("Numero") &")</font>"%>'></asp:Label>
        </ItemTemplate>
        <HeaderTemplate>
        <div style=" font-weight:bold; font-size:10pt; background-position: left top; color:White; background-image:url('Public/Images/back.jpg'); background-repeat:repeat-x; text-align:center;">
            TIPOLOGIE
        </div>
        <asp:Label ID="Label2" runat="server" Text="::" Font-Bold="true" ForeColor="#E12825"></asp:Label> <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl='<%# "rettificaMagazzino.aspx?ct="&Session.item("ct")&"&mr="&Session.item("mr")&"&tp=0&gr="&Session.item("gr")&"&sg="&Session.item("sg")&"&q="&Session.item("q")&"&spedgratis="&Session("SpedGratis")&"&inpromo=" & Request.QueryString("inpromo") %>' Text="Tutti" ToolTip="Visualizza Tutti"></asp:HyperLink>
        </HeaderTemplate>
        <SelectedItemStyle Font-Bold="True" />
    </asp:DataList></td><td valign="top" style="border-left-style: solid; border-left-width: 1px; height: 103px;" nowrap="nowrap" width="25%">
    
    <asp:DataList ID="DataList2" runat="server" DataSourceID="sdsGruppo" DataKeyField="gruppiid" EnableViewState="False" Font-Size="8pt" Height="150px" RepeatLayout="Flow" width="165px" style="overflow-y:auto;overflow-x:hidden;SCROLLBAR-SHADOW-COLOR:whitesmoke;SCROLLBAR-ARROW-COLOR:#E12825;SCROLLBAR-DARKSHADOW-COLOR:white;SCROLLBAR-BASE-COLOR:white">
        <ItemTemplate>
            <asp:Label ID="Label2" runat="server" Text="»" Font-Bold="true" ForeColor="#E12825"></asp:Label> 
            <asp:HyperLink ID="HyperLink1" runat="server" NavigateUrl='<%# "rettificaMagazzino.aspx?ct="&Session.item("ct")&"&mr="& Session.item("marcheid")&"&tp="& Session.item("tp")&"&gr="& Eval("GruppiId")&"&sg="& Session.item("sg")&"&q="&Session.item("q")&"&spedgratis="&Session("SpedGratis")&"&inpromo=" & Request.QueryString("inpromo") %>' Text='<%# Eval("Descrizione") %>' TabIndex='<%# Eval("gruppiid") %>' ToolTip="Applica/Rimuovi Filtro"></asp:HyperLink> 
             <asp:Label ID="Label9" runat="server" Text='<%# "<font color=#E12825>("& Eval("Numero") &")</font>"%>'></asp:Label>
        </ItemTemplate>
         <HeaderTemplate>
         <div style=" font-weight:bold; font-size:10pt; background-position: left top; color:White; background-image:url('Public/Images/back.jpg'); background-repeat:repeat-x; text-align:center;">
             GRUPPO
         </div>
        <asp:Label ID="Label2" runat="server" Text="::" Font-Bold="true" ForeColor="#E12825"></asp:Label> <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl='<%# "rettificaMagazzino.aspx?ct="&Session.item("ct")&"&mr="&Session.item("mr")&"&tp="&Session.item("tp")&"&gr=0&sg="&Session.item("sg")&"&q="&Session.item("q")&"&spedgratis="&Session("SpedGratis")&"&inpromo=" & Request.QueryString("inpromo") %>' Text="Tutti" ToolTip="Visualizza Tutti"></asp:HyperLink>
        </HeaderTemplate>
        <SelectedItemStyle Font-Bold="True" />
    </asp:DataList></td><td valign="top" style="border-left-style: solid; border-left-width: 1px; border-right-style: solid; border-right-width: 1px; height: 103px;" nowrap="nowrap" width="25%">
    
    <asp:DataList ID="DataList3" runat="server" DataSourceID="sdsSottogruppo" DataKeyField="sottogruppiid" EnableViewState="False" Font-Size="8pt" Height="150px" RepeatLayout="Flow" width="165px" style="overflow-y:auto;overflow-x:hidden;SCROLLBAR-SHADOW-COLOR:whitesmoke;SCROLLBAR-ARROW-COLOR:#E12825;SCROLLBAR-DARKSHADOW-COLOR:white;SCROLLBAR-BASE-COLOR:white">
        <ItemTemplate>
            <asp:Label ID="Label2" runat="server" Text="»" Font-Bold="true" ForeColor="#E12825"></asp:Label> 
            <asp:HyperLink ID="HyperLink1" runat="server" NavigateUrl='<%# "rettificaMagazzino.aspx?ct="&Session.item("ct")&"&mr="& Session.Item("marcheid")&"&tp="& Session.item("tp")&"&gr="& Session.item("gr")&"&sg="& Eval("SottogruppiId")&"&q="&Session.item("q")&"&spedgratis="&Session("SpedGratis")&"&inpromo=" & Request.QueryString("inpromo") %>' Text='<%# Eval("Descrizione") %>'  TabIndex='<%# Eval("sottogruppiid") %>' ToolTip="Applica/Rimuovi Filtro"></asp:HyperLink> 
             <asp:Label ID="Label9" runat="server" Text='<%# "<font color=#E12825>("& Eval("Numero") &")</font>"%>'></asp:Label>
        </ItemTemplate>
          <HeaderTemplate>
          <div style=" font-weight:bold; font-size:10pt; background-position: left top; color:White; background-image:url('Public/Images/back.jpg'); text-align:center;">
              SOTTOGRUPPI
          </div>
        <asp:Label ID="Label2" runat="server" Text="::" Font-Bold="true" ForeColor="#E12825"></asp:Label> <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl='<%# "rettificaMagazzino.aspx?ct="&Session.item("ct")&"&mr="&Session.item("mr")&"&tp="&Session.item("tp")&"&gr="&Session.item("gr")&"&sg=0"&"&q="&Session.item("q")&"&spedgratis="&Session("SpedGratis")&"&inpromo=" & Request.QueryString("inpromo") %>' Text="Tutti" ToolTip="Visualizza Tutti"></asp:HyperLink>
        </HeaderTemplate>
        <SelectedItemStyle Font-Bold="True" />
    </asp:DataList></td>
    </tr>
</table>

    <hr size="2" id="HR1"/>
   
   
    <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione1, PrezzoAcquisto, Img1, DescrizioneLunga FROM varticolibase ORDER BY Codice, Descrizione1" EnableViewState="False">
    </asp:SqlDataSource>
    
    <center>
        <br />
    <asp:Label ID="lblTrovati" runat="server" Font-Bold="True" ForeColor="#E12825" ></asp:Label>
        articoli trovati <i>(<asp:Label ID="lblLinee" runat="server" Text="0" Font-Size="8pt">&gt;</asp:Label> 
        per pagina)<br />
    </i>
    </center>
    
    <!-- Oridinamento Articoli -->
    <br />
    <br />
    <div style="width:100%; height:60px; text-align:right; vertical-align:middle; background-image:url('Images/sfondo_ordinamento.png'); background-repeat:no-repeat; background-position:bottom right;">
    <table style="width:100%; height:100%; vertical-align:middle; text-align:right; border-style:none;" cellspacing="0"> 
        <tr>
            <td style="background-image:url('Images/Sfondo_Ordinamento/1.gif'); background-repeat:no-repeat; width:19px; height:60px;">
            </td>
            <td style="background-image:url('Images/Sfondo_Ordinamento/2.gif'); background-repeat:repeat-x; height:60px; padding-right:15px;">
                <asp:CheckBox ID="CheckBox_Disponibile" runat="server" Text=" Solo Disponibili" Width="150px" AutoPostBack="True" style="float:left;" />
                ORDINA PER 
                <asp:DropDownList ID="Drop_Ordinamento" style="text-align:left;" runat="server" Width="150px" AutoPostBack="True" BackColor="#FFFF80" Font-Bold="False" Font-Size="10pt" ForeColor="Black">
                  <asp:ListItem Value="P_offerta">offerta</asp:ListItem>
                  <asp:ListItem Value="P_basso">prezzo più basso</asp:ListItem>
                  <asp:ListItem Value="P_alto">prezzo più alto</asp:ListItem>
                  <asp:ListItem Value="P_recenti">più recenti</asp:ListItem>
                  <asp:ListItem Value="P_popolarit&#224;">popolarità</asp:ListItem>
                </asp:DropDownList>
            </td>
            <td style="background-image:url('Images/Sfondo_Ordinamento/3.gif'); background-repeat:no-repeat; width:19px; height:60px;">
            </td>
        </tr>   
    </table>
    </div>
    
    <asp:GridView ID="GridView1" runat="server" AutoGenerateColumns="False" DataKeyNames="id"
        DataSourceID="sdsArticoli" AllowPaging="True" Font-Size="8pt" GridLines="None" CellPadding="3" Width="100%" style=" z-index:-1;" ShowFooter="True">
        <Columns>      
            <asp:TemplateField HeaderText="Ordina &gt;&gt;" ShowHeader="False">
                <ItemTemplate>
                    <!-- Nuovo Articolo -->
                    <table style="width:659px; margin:auto; border-style:none;">
                        <tr>
                            <td class="colore_sito" style="background-color:rgb(224, 224, 224); border-style:none; padding:5px;">
                                <!-- Titolo -->
                                <asp:Label ID="Label12" runat="server" Text=' <%# Eval("MarcheDescrizione") %>' Font-Size="11pt" Font-Bold="true" Height="10px" style="display:inline;"></asp:Label>
                                <asp:HyperLink ID="HyperLink5"  ToolTip='<%# Eval("SettoriDescrizione") &" > "&  Eval("CategorieDescrizione") &" > "& Eval("MarcheDescrizione") &" > "& Eval("TipologieDescrizione") &" > "&  Eval("GruppiDescrizione") &" > "&  Eval("SottogruppiDescrizione") &" > "&  Eval("Codice") %>' runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("id") %>'>
                                <asp:Label ID="Label8" runat="server" Text='<%# " - " & Eval("Descrizione1") %>' Font-Size="9pt" Font-Bold="true" ForeColor="Black"></asp:Label>
                                </asp:HyperLink>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <a href='<%# "rettificaMagazzino.aspx?tp=" & Eval("TipologieId") & "&mr=" & Eval("MarcheId") %>''><span style="font-size:7pt;">
                                in <%# Eval("SettoriDescrizione") &" > "&  Eval("CategorieDescrizione") &" > "& Eval("MarcheDescrizione")%></span></a>
                                
                                <div style="float:right; width:auto; font-size:7pt; color:rgb(24, 40, 156);">
                                    <asp:Label ID="Label5" runat="server" Text="Codice: " ForeColor="black"></asp:Label><asp:Label ID="Label3" runat="server" Text='<%# Eval("Codice") %>' Font-Bold="true"></asp:Label>&nbsp;&nbsp;<asp:Label ID="Label6" runat="server" Text="EAN: " ForeColor="black"></asp:Label><asp:Label ID="Label7" runat="server"  Text='<%# Eval("Ean") %>' Font-Bold="true"></asp:Label>
                                </div>
                            </td>
                        </tr>
                        <tr>
                           <td>
                                <table style="width:100%;">
                                    <tr>
                                        <td rowspan="3" style="border-style:none; width:120px; padding:5px; vertical-align:middle; text-align:center;">
                                            <div style="position:relative; overflow:hidden; height:100%;">
                                                <!-- Immagine Prodotto -->
                                                <asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("id") %>' >
                                                    <asp:Image ID="Image1" runat="server" style=" max-height:150px; width:150px;" AlternateText='<%# Eval("Descrizione1") %>' ImageUrl='<%# checkImg(Eval("img1"))%>' />
                                                </asp:HyperLink>
                                                <div style="position:absolute; right:0px; top:0px;">
                                                    <asp:Image ID="img_offerta" runat="server" ImageUrl="~/Public/Images/bollinoPromoVetrina.png" Visible="False"/>
                                                </div>
                                            </div>    
                                            <!-- Controllo se esiste l'immagine -->
                                            <script runat="server">
                                                Function controllo_img(ByVal temp) As String
                                                    If IsDBNull(temp) Then
                                                        Return "false"
                                                    Else
                                                        Return "true"
                                                    End If
                                                End Function
                                                
                                                Function checkImg(ByVal imgname As String) As String
                                                    If imgname <> "" Then
                                                        Return "public/foto/_" & imgname
                                                    Else
                                                        Return "Public/Foto/img_non_disponibile.png"
                                                    End If
                                                End Function
                                            </script>
                                            
                                        </td>
                                    </tr>
                                    <tr>
                                        <td colspan="2" style="border-style:none; height:40px; padding:5px; text-align:left;">
                                            <!-- Descrizione Breve -->
                                            <script runat="server">
                                                Function sotto_stringa(ByVal temp As String) As String
                                                    temp = Server.HtmlEncode(temp)
                                                    Return Left(temp.Replace("&#160;", " "), 200) & " ..."
                                                End Function
                                            </script>
                                            <asp:Label ID="Label1" runat="server" Text='<%# Eval("Descrizione2") %>' Font-Size="8pt" style="text-align:justify;" wrap="true" EnableTheming="False" EnableViewState="False"></asp:Label>
                                        </td>
                                    </tr>
                                    <tr style="height:50px;">
                                        <!-- Info Articolo + Prezzo -->
                                        <td style="border-style:none; padding:5px; width:30%; font-size:7pt; border-right-style:dotted; border-width:1px; border-color:Gray; text-align:center;">
                                            <asp:Label ID="Label13" runat="server" Text="ID Art.: " Font-Bold="True" Visible="false"></asp:Label><asp:Label ID="Label_idArticolo" runat="server"  Text='<%# Eval("id") %>' ForeColor="white" Visible="false"></asp:Label>
                                            
                                            <table style="vertical-align:middle; font-size:6pt; text-align:left; margin:auto;">
                                                <tr>
                                                    <td>
                                                        <!-- PROMO -->
                                                        <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"  SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                                                            <SelectParameters>
                                                                <asp:ControlParameter Name="ID" ControlID="tbID" PropertyName="Text" Type="Int32" />
                                                                <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                                                            </SelectParameters>
                                                        </asp:SqlDataSource>

                                                        <table visible='<%# Eval("InOfferta")%>' style="width:100%; border-style:none; padding:3px; vertical-align:middle; border-style:dotted; border-width:1px; border-color:Gray;" cellspacing="0">
                                                            <tr>
                                                                <td colspan="5" style="text-align:center; font-weight:bold; background-color:Gray; color:White; padding:2px;">
                                                                    <%#IIf(Eval("InOfferta") = 1, "PROMO", "NESSUNA PROMO")%>
                                                                </td>
                                                            </tr>
                                                            <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                                                            <ItemTemplate>
                                                            <%Session("InOfferta") = 1%>
                                                                <tr>
                                                                    <td>
                                                                       <asp:Label ID="lblOfferta" runat="server" Visible='<%# Eval("InOfferta")%>' Font-Size="6pt" Text="" ForeColor="Black"></asp:Label> 
                                                                    </td>
                                                                    <td style="font-size:7pt; font-weight:bold; color:Red; padding-left:5px;">
                                                                        <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                                                        <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>' Visible="false"></asp:Label>
                                                                    </td>
                                                                    <td style="padding-left:5px;">
                                                                        PZ.
                                                                    </td>
                                                                    <td style="padding-left:5px;">
                                                                        A
                                                                    </td>
                                                                    <td style="font-size:7pt; font-weight:bold; color:Red; padding-left:5px;">
                                                                        <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# "&#8364;" & FormatNumber(Eval("PrezzoPromo"), 2) %>' Visible="false"></asp:Label>
                                                                        <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%# "&#8364;" & FormatNumber(Eval("PrezzoPromoIvato"), 2) %>' Visible="false"></asp:Label>     
                                                                    </td>
                                                                    <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:Label>
                                                                </tr>
                                                            </ItemTemplate>
                                                            </asp:Repeater>
                                                        </table>
                                                    </td>
                                                </tr>
                                            </table>    
                                        </td>
                                        <td style="border-style:none; padding-left:5px;">
                                            <table style="width:100%; height:30px; float:right; font-size:7pt; text-align:left; padding:2px; border-bottom-style:dotted; border-top-style:dotted; border-width:1px;" cellspacing="0" cellpadding="0" >
                                                <tr>
                                                    <td style="width:80px;">
                                                        <asp:Label ID="lblDispo" runat="server" Font-Bold="True" Font-Size="6pt" Text="Disponibilità:"></asp:Label>
                                                    </td>
                                                    <td style="text-align:center; padding-right:10px;">
                                                        <asp:Label ID="Label_dispo" runat="server" ForeColor="red" Font-Bold="true" Text='<%# iif(Eval("Giacenza")>1000,">1000",iif(Eval("Giacenza").toString.contains("-"),Eval("Giacenza").toString.Replace("-","&minus;"),Eval("Giacenza"))) %>'></asp:Label>
                                                        <asp:Image ID="imgDispo" runat="server"/>
                                                    </td>
                                                    <td style="width:80px;">
                                                        <asp:Label ID="lblImpegnata" runat="server" Font-Bold="True" Font-Size="6pt" Text="Impegnati:"></asp:Label>
                                                    </td>
                                                    <td style="text-align:center; padding-right:10px;">
                                                        <asp:Label ID="Label_imp" runat="server" ForeColor="red" Font-Bold="true" Text='<%# iif(Val(Eval("Impegnata").toString)>1000,">1000", Val(Eval("Impegnata").toString)) %>'></asp:Label>
                                                    </td>
                                                    <td style="width:80px;">
                                                        <asp:Label ID="lblArrivo2" runat="server" Font-Bold="True" Font-Size="6pt" Text="In&nbsp;Arrivo:"></asp:Label>
                                                    </td>
                                                    <td style="text-align:center; padding-right:10px;">
                                                       <asp:Label ID="Label_arrivo" runat="server" ForeColor="red" Font-Bold="true" Text='<%# iif(Val(Eval("InOrdine").toString)>1000,">1000", Val(Eval("InOrdine").toString)) %>' style="padding-right"></asp:Label>
                                                        <asp:Image ID="imgArrivo" runat="server" Visible="false"/>
                                                    </td>
                                                </tr>
                                            </table>
                                            <br />
                                            
                                            <!-- Sconto -->
                                            <asp:Panel ID="Panel_Visualizza_Percentuale_Sconto" runat="server" Visible="false" style="float:left;">
                                                <div style="padding:5px; height:61px; background-image:url('Images/sfondoOfferta.png'); background-position:center; background-repeat:no-repeat; color:White;">
                                                    <table style="height:61px; width:61px; vertical-align:middle; text-align:center;">
                                                        <tr>
                                                            <td>
                                                                <span style="font-size:9px;">SCONTO</span><br />
                                                                <asp:Label ID="sconto_applicato" runat="server" Text="" ForeColor="White" Font-Size="12pt" Font-Bold="true"></asp:Label>
                                                            </td>
                                                        </tr>
                                                    </table>
                                                </div>
                                            </asp:Panel>
                                            
                                            <span class="colore_sito" style="float:right; padding-top:3px; text-align:right;">
                                                <asp:Label ID="lblPrezzoPromo" runat="server" Width="100%" Text='<%# Eval("Prezzo", "{0:C}") %>' Visible='<%# Eval("InOfferta") %>' style="font-size:19pt; font-weight:bold; width:100%; text-align:right;"></asp:Label><br />
                                                <%  
                                                    If Session("InOfferta") = 1 Then
                                                        Session("InOfferta") = 0
                                                %>
                                                    <div>
                                                    <asp:Panel ID="Panel_in_offerta" runat="server" Height="15px" Width="150px" Visible="False" style="margin:0 0 0 auto;">
                                                        invece di
                                                    <asp:Label ID="Label4" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>' ForeColor="Red" style="text-decoration:line-through;"></asp:Label>
                                                    <asp:Label ID="Label10" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Visible="False" ForeColor="Red" style="text-decoration:line-through;"></asp:Label></asp:Panel>
                                                    </div>
                                                <%Else%>
                                                    <asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>' style="font-size:19pt; font-weight:bold;"></asp:Label>
                                                    <asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Visible="false" style="font-size:19pt; font-weight:bold;"></asp:Label>
                                                <%  End If%>
                                                
                                                <br /><%#IIf(Eval("Giacenza") > 0, "<span style=""color:green; font-weight:bold; font-size:11pt;"">DISPONIBILE</span>", "<span style=""color:Red; font-weight:bold; font-size:12pt;"">NON DISPONIBILE</span>")%>
                                                
                                            </span>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="text-align:center;">
                                            <!-- Marca -->
                                            <asp:Image ID="Image2" runat="server" style="margin:auto auto 0 auto; max-width:100px; max-height:45px;" AlternateText='<%# Eval("MarcheDescrizione") %>' ImageUrl='<%# Eval("Marche_img", "~/Public/Marche/{0}") %>' visible='<%# controllo_img(Eval("Marche_img")) %>'/>
                                        </td>
                                        <td colspan="2" style="border-style:none; width:200px; height:20px; vertical-align:middle; text-align:center;">
                                            <!-- Spedizione Gratis -->
                                            <asp:Label ID="lblID" runat="server" Text='<%# Bind("ID") %>' style="z-index:-1;" Visible="false"></asp:Label>
                                            <asp:SqlDataSource ID="sdsSpedizioneGratis" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                                SelectCommand="SELECT SpedizioneGratis_Listini, SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine, id FROM articoli WHERE (SpedizioneGratis_Listini LIKE CONCAT('%', @Param1, ';%')) AND (id = @Param2) AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())">
                                                <SelectParameters>
                                                    <asp:SessionParameter Name="Param1" SessionField="Listino" />
                                                    <asp:ControlParameter ControlID="lblID" Name="Param2" PropertyName="Text" />
                                                </SelectParameters>
                                            </asp:SqlDataSource>
                                            <asp:GridView ID="GridView3" runat="server" AutoGenerateColumns="False" DataSourceID="sdsSpedizioneGratis" BorderWidth="0px" ShowHeader="False" style="float:left; vertical-align:middle;">
                                                <Columns>
                                                    <asp:TemplateField>
                                                        <ItemTemplate>
                                                            <img style="border-width:0px; height:30px; margin-top:5px;" src="Images/spedizione_gratis.png" title='Questo articolo verrà spedito GRATIS !!! fino al <%# Eval("SpedizioneGratis_Data_Fine","{0:d}") %>' alt="" />
                                                        </ItemTemplate>
                                                    </asp:TemplateField>
                                                </Columns>
                                                <RowStyle BorderColor="White" BorderWidth="0px" />
                                                <PagerStyle BorderColor="White" BorderWidth="0px" />
                                            </asp:GridView>
                                            <!-- --------------------------------------------------------------------------------------------------- -->
                                            
                                            <!-- Icone Proprietà -->
                                            <asp:Image ID="img_facebook" runat="server" ImageUrl="~/Images/facebook.png" Visible="false" style="height:30px; float:left; padding:5px;"/>
                                            <asp:Image ID="img_regalo" runat="server" ImageUrl="~/Images/icon_ecommerce/present.png" Visible="False" style="height:30px; float:left; padding:5px;"/>
                                            <asp:Image ID="img_nodisp" runat="server" ImageUrl="~/Images/icon_ecommerce/cancel.png" Visible="False" style="height:30px; float:left; padding:5px;"/>
                                            <asp:Image ID="img_trasportogratis" runat="server" ImageUrl="~/Images/icon_ecommerce/bag_green.png" Visible="False" style="height:30px; float:left; padding:5px;"/>
                                            <asp:LinkButton ID="LB_wishlist" runat="server" OnClick="BT_Aggiungi_wishlist_Click" style="float:left;  padding:5px;"><img src="Images/wishlist.png" title="Aggiungi a Wishlist" alt="" style="height:30px" /></asp:LinkButton>
                                            <a href='<%# "articolo.aspx?id="& Eval("id") %>' style="float:left; padding:5px;"><img src="Images/scheda_tecnica.png" title="Scheda Tecnica" alt="" style="height:30px;" /></a>
                                            <!-- AddThis Button BEGIN -->
                                            <div class="addthis_toolbox addthis_default_style addthis_32x32_style" style="float:left; padding-top:4px;">
                                            <a class="addthis_button_preferred_1" addthis:url="<%# "http://" & Session("AziendaUrl") & "/articolo.aspx?id=" & Eval("id") %>"></a>
                                            <a class="addthis_button_compact"></a>
                                            </div>
                                            <script type="text/javascript">var addthis_config = {"data_track_addressbar":true};</script>
                                            <script type="text/javascript" src="//s7.addthis.com/js/300/addthis_widget.js#pubid=ra-52a5f0943d53948f"></script>
                                            <!-- AddThis Button END -->
                                            
                                            
                                            <table style="vertical-align:middle; width:100px; height:100%; float:right;">
                                                <tr>
                                                   <td>
                                                        <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" BorderWidth="2" BorderColor="#CCCCCC" BorderStyle="Solid" />
                                                   </td>
                                                   <td>
                                                        <asp:TextBox ID="tbQuantita" runat="server" Width="50px" style="text-align:center; font-size:12pt;" MaxLength="4">1</asp:TextBox>
                                                   </td>
                                                   <td>
                                                        <asp:ImageButton ID="ImageButton1" runat="server" Height="30px" ImageUrl="Images/carrello.png" ToolTip="Aggiungi al Carrello" OnClick="ImageButton1_Click" />
                                                   </td>
                                                </tr>
                                            </table>
                                            <asp:HyperLink ID="HyperLink2" Visible="false" runat="server" ImageUrl='<%# "images/cart.gif" %>'  Text="Scheda Prodotto"></asp:HyperLink>
                                            <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbQuantita" Display="Dynamic" ErrorMessage="!" SetFocusOnError="True"></asp:RequiredFieldValidator>
                                            <asp:CompareValidator ID="CompareValidator2" runat="server" ControlToValidate="tbQuantita" Display="Dynamic"  ErrorMessage="!" Operator="GreaterThan" SetFocusOnError="True"  Type="Integer" ValueToCompare="0"></asp:CompareValidator>
                                        </td>
                                    </tr>
                                    <tr style="display:none;">
                                        <td>
                                            <asp:TextBox ID="tbID" runat="server" Text='<%# Eval("ID") %>' Width="30" EnableViewState="false" Visible="false" ></asp:TextBox>
                                            <asp:TextBox ID="tbInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Width="30" EnableViewState="false" Visible="false" ></asp:TextBox>
                                        </td>
                                    </tr>
                                </table>
                           </td>
                        </tr>
                    </table>
         </ItemTemplate>
         <FooterTemplate>
             <img src="Public/Images/selection.gif" alt=""/>
             &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                    <asp:ImageButton ID="Selezione_Multipla" runat="server" title="Aggiungi gli articoli selezionati al carrello" OnClick="Selezione_Multipla_Click" ImageUrl="~/Public/Images/aggiungiMultiplo.png" />
                </FooterTemplate>
                <FooterStyle BackColor="#CCCCCC" HorizontalAlign="Center" VerticalAlign="Middle" />
      </asp:TemplateField>
     </Columns>
        <PagerStyle CssClass="nav" />
        <SelectedRowStyle BackColor="Red" />
        <AlternatingRowStyle BorderStyle="None" />
    </asp:GridView>
    
    <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label><br /><br />
    
</asp:Content>

