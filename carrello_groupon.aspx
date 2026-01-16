<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="carrello_groupon.aspx.vb" Inherits="carrello_groupon" title="Pagina senza titolo" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
    <link href='http://fonts.googleapis.com/css?family=Asap:700' rel='stylesheet' type='text/css'>
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
    <div style=" width:500px; margin:auto; text-align:center;">
        <img src="Images/groupon/groupon_logo.png" style=" width:500px;" /> <br /><br />
        <span>INSERIRE IL CODICE COUPON</span>
        <asp:TextBox ID="TB_CodiceSconto" runat="server" AutoPostBack="True" 
            Font-Size="24pt" Width="80%" Font-Bold="True" style=" color:#4BC1DD; text-align:center;" 
            BorderStyle="Solid" BorderColor="#4BC1DD" BorderWidth="1px" 
            AutoCompleteType="Disabled"></asp:TextBox>
        <asp:Image ID="imgOK" runat="server" ImageUrl="Images/groupon/OK.png" Visible="False" style="position:relative; top:6px;" />
        <asp:Image ID="imgNO" runat="server" ImageUrl="Images/groupon/NO.png" Visible="False" style="position:relative; top:6px;" />
        <br /><br />
        <asp:FormView ID="FormView_Articolo" runat="server" DataSourceID="SqlData_Buoni" style=" width:100%; text-align:center;">
            <ItemTemplate>
                <table style="width:100%; text-align:center; vertical-align:middle; font-size:9pt; border-style:solid; border-width:2px; border-color:#ccc; padding:5px;">
                    <tr>
                        <td style=" width:300px;">
                            <img src='<%# Eval("imgBuono") %>' style="width:300px;" alt=""/>
                        </td>
                        <td style=" vertical-align:bottom;">
                            <table>    
                                 <tr>
                                    <td>
                                    <div style=" width:140px; height:42px; background-image:url('images/groupon/price.png'); background-repeat:no-repeat; background-position:bottom right; text-align:right; padding-right:10px; display:<%# iif(Eval("spese_spedizione")>0,";","none") %>">
                                        <span style="font-family: 'Asap', sans-serif; font-size:18pt; color:White; position:relative; top:10px;"><%#Eval("spese_spedizione", "{0:C}")%></span>
                                    </div>
                                    </td>
                                 </tr>
                                 <tr>
                                    <td>
                                    <div style=" width:140px; height:42px; text-align:right; display:<%# iif(Eval("spese_spedizione")=0,";","none") %>">
                                        <img src="Images/groupon/free_shipping.gif" alt="" style=" position:relative; right:-10px;" />
                                    </div>
                                    </td>
                                 </tr>
                                 <tr>
                                    <td>
                                    <div style=" width:140px; height:42px; background-image:url('images/groupon/price.png'); background-repeat:no-repeat; background-position:bottom right; text-align:right; padding-right:10px;">
                                        <script runat="server">
                                            Function prezzo_fisso_con_iva(ByVal prezzo_fisso As Double, ByVal iva As Double) As String
                                                Dim temp As Double
                                                temp = prezzo_fisso * ((iva / 100) + 1)
                                                Return Format("{0:N2}", temp.ToString)
                                            End Function
                                        </script>
                                        <span style="font-family: 'Asap', sans-serif; font-size:18pt; color:White; position:relative; top:10px;">€ <%#prezzo_fisso_con_iva(Eval("prezzo_fisso"), Eval("iva"))%></span>
                                    </div>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                    <tr>
                        <td colspan="2">
                            <asp:ImageButton ID="IB_Conferma" runat="server" style="padding-top:20px;" ImageUrl="Images/groupon/button.png" onclick="IB_Conferma_Click" idArticolo='<%#Eval("idArticolo")%>' Prezzo='<%#Eval("prezzo_fisso", "{0:C}")%>' codArticolo='<%#Eval("Codice")%>' SpeseSpedizione='<%# Eval("spese_spedizione", "{0:C}") %>' DescrizioneArticolo='<%# Eval("Descrizione1", "{0:C}") %>' IvaArticolo='<%# Eval("iva") %>'/>
                        </td>
                    </tr>
                </table>
            </ItemTemplate>
        </asp:FormView>
    
    </div>
    <asp:SqlDataSource ID="SqlData_Buoni" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT buoni_acquisto.idBuono, buoni_acquisto.idArticolo, buoni_acquisto.imgBuono, buoni_acquisto.listini_abilitati, buoni_acquisto.prezzo_fisso, buoni_acquisto.sconto, buoni_acquisto.spese_spedizione, buoni_acquisto.valido_da, buoni_acquisto.valido_a, articoli.Codice, articoli.Peso, articoli.Img1, articoli.Abilitato, codici_buono.idCodiceBuono, codici_buono.idBuono, codici_buono.associazione_groupon, articoli.Descrizione1, articoli.codice, articoli.iva, buoni_acquisto.idAzienda FROM buoni_acquisto INNER JOIN articoli ON buoni_acquisto.idArticolo = articoli.id INNER JOIN codici_buono ON buoni_acquisto.idBuono = codici_buono.idBuono WHERE (codici_buono.associazione_groupon = @Codice_Sconto) AND (codici_buono.data_convalida IS NULL) AND (buoni_acquisto.listini_abilitati LIKE CONCAT('%', @Listino, ';%')) AND (buoni_acquisto.valido_da &lt;= CURDATE()) AND (buoni_acquisto.valido_a &gt;= CURDATE()) AND (buoni_acquisto.idAzienda = @Azienda)" 
        UpdateCommand="UPDATE codici_buono SET data_convalida = NOW() WHERE (associazione_groupon = @Codice)">
        <SelectParameters>
            <asp:ControlParameter ControlID="TB_CodiceSconto" Name="Codice_Sconto" 
                PropertyName="Text" />
            <asp:SessionParameter Name="Azienda" SessionField="AziendaID" />
            <asp:SessionParameter Name="Listino" SessionField="Listino" />
        </SelectParameters>
        <UpdateParameters>
            <asp:ControlParameter ControlID="TB_CodiceSconto" Name="Codice" PropertyName="Text" />
        </UpdateParameters>
    </asp:SqlDataSource>
</asp:Content>

