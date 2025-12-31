<%@ Page Language="VB" AutoEventWireup="false" CodeFile="vers_stampabile.aspx.vb" Inherits="vers_stampabile" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Scheda Prodotto</title>
</head>
<body style="font-family:Arial; font-size:12pt;">
<form runat="server" style="width:960px; margin:auto;" action="#" onsubmit="return false;">
<script runat="server">
    Function Sostituisci_caratteri(ByVal temp As String) As String
               
        Return System.Web.HttpUtility.HtmlEncode(temp)
        
    End Function
</script>

 <h1 style="width:956px; color:black; padding:5px; font-weight:bold; font-size:18pt; border-color:Black; border-width:2px; border-style:solid;">Scheda Prodotto</h1>
 
    <asp:SqlDataSource ID="sdsArticolo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"  ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vsuperarticoli  WHERE (id = ?id) and (NListino = ?NListino)">
        <SelectParameters>
            <asp:QueryStringParameter Name="id" QueryStringField="id" Type="Int32" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>
    <asp:FormView ID="fvPage" runat="server" DataKeyNames="id" DataSourceID="sdsArticolo" Width="960px" Height="1px">
          <ItemTemplate>            
           
           <!-- Sezione Immagini -->
           <script runat="server">
               Function checkImg(ByVal imgname As String) As String
                   If imgname <> "" Then
                       Return "public/foto/" & imgname
                   Else
                       Return "Public/Foto/img_non_disponibile.png"
                   End If
               End Function
                                    
               Function controllo_img(ByVal temp) As String
                   If IsDBNull(temp) Then
                       Return "false"
                   Else
                       Return "true"
                   End If
               End Function
           </script>
           <table width="960px" style="width:960px; height:150px; vertical-align:middle; text-align:center; padding-bottom:50px;" cellpadding="0px" cellspacing="0px">
                <tr>
                    <td rowspan="2" style="width:360px; height:200px; overflow:hidden;">
                        <img src="<%# checkImg(Eval("Img1")) %>" style="height:100%;" alt="" />
                    </td>
                    <td style="width:200px; height:120px; overflow:hidden;">
                        <img src="<%# checkImg(Eval("Img2")) %>" style=" height:100%;" alt="" />
                    </td>
                    <td style="width:200px; height:120px; overflow:hidden">
                        <img src="<%# checkImg(Eval("Img3")) %>" style=" height:100%;" alt="" />
                    </td>
                    <td style="width:200px; height:120px; overflow:hidden">
                        <img src="<%# checkImg(Eval("Img4")) %>" style="height:100%;" alt="" />
                    </td>
                </tr>
                <tr style="font-family:Arial; font-size:16pt; font-weight:bold;">
                    <td style="height:30px; border-width:1px;">
                        DISPONIBILITA'<br />
                        <asp:Label ID="lblDispo" runat="server" ForeColor="Red" Font-Size="14pt" Text='<%# Eval("Giacenza") %>'></asp:Label>
                    </td>
                    <td style="height:30px;">
                        IMPEGNATE<br />
                        <asp:Label ID="lblImpegnata" ForeColor="Red" Font-Size="14pt" runat="server" Text='<%# Eval("Impegnata") %>'></asp:Label>
                    </td>
                    <td style="height:30px;">
                        IN ARRIVO<br />
                        <asp:Label ID="lblArrivo" ForeColor="Red" Font-Size="14pt" runat="server" Text='<%# Eval("InOrdine") %>'></asp:Label>
                    </td>
                </tr>
           </table>
           
           <!-- Corpo + Descrizione -->
           <div style="width:100%; border-color:Black; border-style:solid; border-width:1px;">
                <div style=" width:758px; float:left; font-size:10pt; padding-top:20px;">
                     <asp:Label ID="Label12" runat="server" Text=' <%# Eval("MarcheDescrizione") %>' Font-Size="16pt" Font-Bold="true" Height="10px" ForeColor="red" style="display:inline;"></asp:Label>
                     <br />
                     <asp:Label ID="Label8" runat="server" Text='<%# Eval("Descrizione1") %>' Font-Size="14pt" Font-Bold="true" ForeColor="black"></asp:Label>
                     <br />
                     <span style="color:black; font-size:7pt;">in <%# Eval("SettoriDescrizione") &" > "&  Eval("CategorieDescrizione") &" > "& Eval("MarcheDescrizione")%></span>
                     
                     <br /><br />
                     <div style="width:100%;">
                        <!-- PROMO -->
                        <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                         SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                         <SelectParameters>
                              <asp:ControlParameter Name="ID" ControlID="tbID" PropertyName="Text" Type="Int32" />
                              <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                         </SelectParameters>
                        </asp:SqlDataSource>  
                        
                        <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                        <ItemTemplate>
                        <script runat="server">
                            Function visualizza_promo(ByVal temp As Integer) As String
                                If temp = 1 Then
                                    Return ""
                                Else
                                    Return "none"
                                End If
                            End Function
                        </script>
                        
                        
                        <table id="vis_promo" style=" vertical-align:middle; width:98%; height:27px; border-style:none; display:<%# visualizza_promo(Eval("InOfferta"))%>; border-color:Red; border-width:2px; border-style:dashed; color:Black;" cellspacing="0">
                            <tr>
                                <td style="width:120px; text-align:center; font-size:14pt; font-weight:bold;">PROMO</td>
                                <td style="height:100%; vertical-align:middle; text-align:right; color:Black; font-weight:bold; padding-right:10px;">
                                    <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>' Visible="false" ForeColor="White" Font-Bold="true"></asp:Label>
                                    <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>' Visible="false" ForeColor="White" Font-Bold="true"></asp:Label>
                                    <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# Eval("PrezzoPromo") %>' Visible="false" ForeColor="White" Font-Bold="true"></asp:Label>
                                    <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%# Eval("PrezzoPromoIvato") %>' Visible="false" ForeColor="White" Font-Bold="true"></asp:Label>
                                    <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false" ForeColor="White" Font-Bold="true"></asp:Label>
                                    
                                    <asp:Label ID="lblOfferta" runat="server" Visible='<%# Eval("InOfferta")%>' Font-Size="10pt" Text='<%# "DAL "& Eval("OfferteDataInizio") &" AL "& Eval("OfferteDataFine") %>' ForeColor="Black" Font-Bold="true"></asp:Label>
                                </td>
                            </tr>
                        </table>
                        </ItemTemplate>
                        </asp:Repeater>
                    </div>
                    <br />
                    
                    <div style=" width:100%; overflow:visible; font-size:12pt; padding-right:20px;">
                        <asp:Label ID="lblDescrizioneArt" runat="server" Text='<%# convalida_stringa(Eval("DescrizioneLunga")) %>' Visible='<%# visualizza_descr_lunga(Eval("DescrizioneHTML")) %>' Font-Size="11pt" style="line-height:130%" Width="98%"></asp:Label>
                        <asp:Label ID="lblDescrizioneHTMLArt" runat="server" Text='<%# convalida_stringa(Eval("DescrizioneHTML")) %>' Font-Size="11pt" style="line-height:130%" Width="98%"></asp:Label>
                    </div>
                    
                    <div style=" width:100%;">
                        <asp:GridView ID="GridView3" runat="server" AutoGenerateColumns="False" 
                            BorderColor="White" BorderWidth="0px" corde DataSourceID="sdsSpedizioneGratis" 
                            ShowHeader="False">
                            <Columns>
                                <asp:TemplateField>
                                    <ItemTemplate>
                                        <table style="vertical-align:middle; width:100%; height:50px; font-size:20pt; font-weight:bold; border-style:none;">
                                            <tr>
                                                <td style="width:380px;">
                                                    SU QUESTO PRODOTTO
                                                </td>
                                                <td>
                                                    <img alt="" src="Images/freeshipping_BIG.gif" style="border-width: 0px; background-color: white;" 
                                                        title='Questo articolo verrà spedito GRATIS !!! fino al <%# Eval("SpedizioneGratis_Data_Fine","{0:d}") %>' />
                                                </td>
                                            </tr>
                                        </table>
                                    </ItemTemplate>
                                </asp:TemplateField>
                            </Columns>
                        </asp:GridView>
                       <asp:SqlDataSource ID="sdsSpedizioneGratis" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                          ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                          SelectCommand="SELECT SpedizioneGratis_Listini, SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine, id FROM articoli WHERE (SpedizioneGratis_Listini LIKE CONCAT('%', @Param1, ';%')) AND (id = @Param2) AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())">
                          <SelectParameters>
                              <asp:SessionParameter Name="Param1" SessionField="Listino" />
                              <asp:QueryStringParameter Name="Param2" QueryStringField="id" />
                          </SelectParameters>
                      </asp:SqlDataSource>
                    </div>
                </div>
                
                <div style=" width:198px; float:left; border-left-style:solid; border-left-width:1px; border-left-color:Black; padding-top:20px;">
                    <div style="width:100%; overflow:auto;">
                        <!-- Prezzo -->
                        <div style="padding:0px; color: black; text-align:right;">
                            <input id="prezzo_modificabile" runat="server" style=" width:95%; text-align:right; border:none; background-attachment:left center; background-image:url('Images/modificabile.png'); background-repeat:no-repeat; color:Black; font-size:26pt; font-weight:bold;" onclick="nascondi_promo_e_sconto();" />
                            
                            <asp:Panel ID="Panel_in_offerta" runat="server" Height="15px" Visible="False" style="text-align:right; font-weight:bold; float:right;">
                                invece di
                                <asp:Label ID="Label_Canc_PrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>' ForeColor="Red" style="text-decoration:line-through; text-align:right;"></asp:Label>
                                <asp:Label ID="Label_Canc_Prezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Visible="False" ForeColor="Red" style="text-decoration:line-through;"></asp:Label></asp:Panel>
                            <br /><br />
                            <asp:Label ID="lblPrezzoDes" runat="server" Text="Prezzo" Font-Bold="True" Font-Names="arial" Font-Size="8pt" style="text-align:left;"></asp:Label>
                            <br /><br />
                        </div>
                        
                        <script runat="server">
                            Function cod_articolo() As String
                                Return Request.QueryString("id")
                            End Function
                        </script>
                    
                        <asp:Label ID="Label4" runat="server" Text='<%# Eval("Prezzo", "{0:C}") %>' Visible='False'></asp:Label>
                        <asp:Label ID="lblID" runat="server" Text='<%# Bind("ID") %>' Visible="false"></asp:Label>
                    </div>
                    
                    <!-- Stampa dei Vettori con i relativi costi -->
                    <div style=" width:100%; overflow:auto;">
                        <div style="width:159px; padding-left: 10px; text-align:right; float:right; border-width:1px; border-color:Black; border-style:solid;">
                            <asp:DataList ID="DataList2" runat="server" DataSourceID="sdsVettori">
                                <ItemTemplate>
                                <div style="margin:0px; text-align:right; display:block; min-height:20px; padding-top: 5px;">
	                                <div style="float:left; width:45px;">
		                                <asp:Image ID="Image1" runat="server" ImageUrl='<%# "Public/Vettori/" & Eval("Img") %>' Visible='<%# controllo_img(Eval("Img")) %>' />
	                                </div> 
	                                <div style="width:150px;">
	                                    <asp:Label ID="Label7" runat="server" Font-Names="Arial" Font-Size="8pt" Text='<%# iif(controlla_iva_spedizione()=2,String.Format("{0:c}", (Eval("CostoFisso")+(Eval("CostoFisso")*0.2))),String.Format("{0:c}", (Eval("CostoFisso")))) %>'></asp:Label><br/><asp:Label ID="Label1" runat="server" Font-Bold="True" Font-Names="Arial" Font-Size="8pt" Text='<%# Eval("Descrizione") %>'></asp:Label></div>
                                    </div>
                                </ItemTemplate>
                            </asp:DataList>
                        </div>
                    </div>
                    
                    <br />
                    <div id="vis_sconto" style="width:100%; overflow:auto;">
                        <!-- Sconto Evidenziato -->
                        <asp:Panel ID="Panel_Visualizza_Percentuale_Sconto" runat="server" Visible="false" Width="100%">
                            <div style=" width:96%; color:red; border-top-style:dashed; border-bottom-style:dashed; border-top-width:2px; border-bottom-width:2px; border-color:Black; ">
                                <table style=" width:100%; height:50px; vertical-align:middle; text-align:right;">
                                    <tr>
                                        <td style="vertical-align:middle;">
                                            <span style="font-size:24px; font-weight:bold;">SCONTO </span><br />
                                            <asp:Label ID="sconto_applicato" runat="server" Text="" ForeColor="red" Font-Size="16pt" Font-Bold="true"></asp:Label>
                                        </td>
                                    </tr>
                                </table>
                            </div>
                        </asp:Panel>
                    </div>
                    
                    <br />
                    <div style="width:100%; overflow:visible;">
                        <table style="width:100%; text-align:right; font-size:10pt; font-style:italic;">
                            <tr style="width:100%;">
                                <td style="width:50%;">
                                    <b style="font-size:11pt; font-weight:bold; font-style:normal;">EAN</b><br /><asp:Label ID="Label21" runat="server" Text='<%# Bind("ean") %>'></asp:Label>
                                </td>
                            </tr>
                            <tr>
                                <td style="width:50%">
                                    <b style="font-size:11pt; font-weight:bold; font-style:normal;">Codice</b><br /><asp:Label ID="Label22" runat="server" Text='<%# Bind("codice") %>'></asp:Label>
                                </td>
                            </tr>
                            <tr style="width:100%;">
                                <td style="width:50%">
                                    <b style="font-size:11pt; font-weight:bold; font-style:normal;">Listino Ufficiale</b><br /><asp:Label ID="Label_LU" runat="server" Text='<%# valore_LU(Eval("ListinoUfficiale"),Eval("ArticoliIva")) %>'></asp:Label>
                                </td>
                            </tr>
                            <tr>
                                <td style="width:50%">
                                    <b style="font-size:11pt; font-weight:bold; font-style:normal;">Peso</b><br /><asp:Label ID="Label_Val_Peso" runat="server" Text='<%# Bind("Peso") %>'></asp:Label> Kg
                                </td>
                            </tr>
                            
                            <asp:SqlDataSource ID="sdsArticoloBase" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                SelectCommand="SELECT articoli.*, id AS Expr1 FROM articoli WHERE (id = ?ID)">
                                <SelectParameters>
                                    <asp:QueryStringParameter DefaultValue="Request.QueryString(&quot;id&quot;)" Name="?ID"
                                        QueryStringField="id" />
                                </SelectParameters>
                            </asp:SqlDataSource>
                                
                            <tr style="width:100%;">
                                <asp:Repeater ID="Repeater2" runat="server" DataSourceID="sdsArticoloBase" EnableViewState="false">
                                    <ItemTemplate>
                                        <td style="width:50%">
                                        <b style="font-size:11pt; font-weight:bold; font-style:normal;">Garanzia</b><br /><asp:Label ID="Label10" Font-Size="8pt" runat="server" Text='<%# iif(controlla_garanzia(Eval("Mesi"))=0,"nessuna informazione",Eval("Mesi") & " mesi") %>'></asp:Label>
                                        </td>
                                    </ItemTemplate>
                                </asp:Repeater>
                             </tr>
                            <tr>                                   
                                <td style="width:50%">
                                <b style="font-size:11pt; font-weight:bold; font-style:normal;">Marca</b><br /><img style="max-width:140px;" alt='<%# Eval("MarcheDescrizione") %>' src='<%# Eval("Marche_img", "Public/Marche/{0}") %>' visible='<%# controllo_img(Eval("Marche_img")) %>' />
                                </td>
                            </tr>
                        </table>
                    </div>
                    
                    <div style="width:100%;">
                        <asp:Image ID="img_trasportogratis" runat="server" ImageUrl="~/Images/icon_ecommerce/bag_green.png" Visible="false" />

                        <asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato","{0:C}") %>' ForeColor="#E12825" Font-Bold="True" Font-Size="12pt" Width="125px" style="text-align:right" Visible="False"></asp:Label>
                        <asp:Label ID="lblPrezzo" runat="server" Font-Bold="True" Font-Size="12pt" ForeColor="#E12825" Text='<%# Bind("Prezzo","{0:C}") %>' Visible="False" Width="125" style="text-align:right"></asp:Label>

                        <asp:Label ID="lblPrezzoPromo" runat="server" Font-Bold="True" Font-Size="12pt" ForeColor="#E12825" Text='<%# Bind("Prezzo","{0:C}") %>' Visible='False' Width="125px" style="text-align:right"></asp:Label>
                    </div>
                </div>
           </div> 
            
            <div style="display:none;">
                <asp:SqlDataSource ID="sdsVettori" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT Ordinamento, Descrizione, id, Abilitato, Web, Promo, Predefinito, AssicurazionePercentuale, AssicurazioneMinimo, ContrassegnoPercentuale, ContrassegnoFisso, ContrassegnoMinimo, Min(PesoMax) AS PesoMax, Min(CostoFisso) AS CostoFisso, Img FROM vvettoricosti WHERE Abilitato=1 AND Web=1 AND PesoMax&gt;=?Peso AND AziendeID=?AziendaId AND Promo=0 GROUP BY Ordinamento, Descrizione, id, Abilitato, Web, Predefinito, AssicurazionePercentuale, ContrassegnoPercentuale, ContrassegnoFisso">
                    <SelectParameters>
                        <asp:ControlParameter ControlID="Label_Val_Peso" Name="Peso" 
                            PropertyName="Text" />
                        <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" />
                    </SelectParameters>
                </asp:SqlDataSource>
                        
                <script runat="server">
                    Function controlla_iva_spedizione() As Integer
                        Return Session.Item("IvaTipo")
                    End Function
                    
                    Function controlla_iva_listinoufficiale() As Integer
                        Return Session.Item("IvaTipo")
                    End Function
                </script>
                
                <asp:TextBox ID="tbID" runat="server" Text='<%# Eval("ID") %>' Width="30" EnableViewState="false" Visible="false"></asp:TextBox>
            </div>

           <script runat="server">
               Function controlla_brochure(ByVal obj As Object) As Integer
                   If Not IsDBNull(obj) Then
                       If obj.ToString <> "" Then
                           Return 1
                       Else
                           Return 0
                       End If
                   Else
                       Return 0
                   End If
               End Function
                
               Function controlla_link_produttore(ByVal obj As Object) As Integer
                   If Not IsDBNull(obj) Then
                       If ((obj.ToString <> "") And (obj.ToString.Length > 10)) Then
                           Return 1
                       Else
                           Return 0
                       End If
                   Else
                       Return 0
                   End If
               End Function
                
               Function controlla_note_garanzia(ByVal obj As Object) As Integer
                   If Not IsDBNull(obj) Then
                       If (obj.ToString <> "") Then
                           Return 1
                       Else
                           Return 0
                       End If
                   Else
                       Return 0
                   End If
               End Function
            
               Function controlla_garanzia(ByVal obj As Object) As Integer
                   If Not IsDBNull(obj) Then
                       If ((obj.ToString <> "") And (Val(obj.ToString) > 0)) Then
                           Return 1
                       Else
                           Return 0
                       End If
                   Else
                       Return 0
                   End If
               End Function
            
               Function valore_LU(ByVal tmp As Object, ByVal iva As Integer) As String
                   If IsDBNull(tmp) Or tmp.ToString = "0" Then
                       Return "-"
                   Else
                       If controlla_iva_listinoufficiale() = 2 Then
                           Return String.Format("{0:c}", tmp * ((iva / 100) + 1))
                       Else
                           Return String.Format("{0:c}", tmp)
                       End If
                   End If
               End Function

               Function convalida_stringa(ByVal temp As String) As String
                   If IsDBNull(temp) Then
                       Return ""
                   End If
                   temp = Server.HtmlEncode(temp)
                   Return temp.Replace("&#160;", " ").Replace("&lt;", "<").Replace("&gt;", ">").Replace("&quot;", """")
               End Function

               Function visualizza_descr_lunga(ByVal descr_html As String) As String
                   If (IsDBNull(descr_html) Or (descr_html = "")) Then
                       Return "True"
                   Else
                       Return "False"
                   End If
               End Function
        </script>                                     

        </ItemTemplate>
    </asp:FormView>
    
    <script type="text/javascript">
        function nascondi_promo_e_sconto(){
            document.getElementById("vis_sconto").style.display="none";
            document.getElementById("vis_promo").style.display="none";
        }
    </script>
</form>
</body>
</html>
