<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="wishlist.aspx.vb" Inherits="wishlist" MaintainScrollPositionOnPostback="true" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
  
    <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione1, PrezzoAcquisto, Img1, DescrizioneLunga FROM varticolibase ORDER BY NoPromo DESC, Codice, Descrizione1" EnableViewState="False">

	</asp:SqlDataSource>
    
	<script runat="server">
        Function stampa_iva_applicata(ByVal DescrizioneEsenzioneIva As String, ByVal DescrizioneIvaRC As String) As String
            If DescrizioneIvaRC <> "" Then
                Return DescrizioneIvaRC
            Else
                Return DescrizioneEsenzioneIva
            End If
        End Function
        
        Function controllaLunghezzaTesto(ByVal testo As String, ByVal lunghezza As Integer) As String
            If testo.Length > lunghezza Then
                Return Left(testo, lunghezza) & "..."
            Else
                Return testo
            End If
        End Function
    </script>
<!--
    <center>
        <br />
    <asp:Label ID="lblTrovati" runat="server" Font-Bold="True" ForeColor="#E12825" ></asp:Label>
        articoli presenti nella wishlist <i>(<asp:Label ID="lblLinee" runat="server" Text="0" Font-Size="8pt">&gt;</asp:Label> 
        per pagina)<br />
    </i>
    </center>
           
    <asp:GridView ID="GridView1" runat="server" AutoGenerateColumns="False" DataKeyNames="id"
        DataSourceID="sdsArticoli" AllowPaging="True" Font-Size="8pt" GridLines="None" CellPadding="3" Width="100%" style=" z-index:-1;" ShowFooter="True" CssClass="table-responsive">
        <Columns>      
            <asp:TemplateField HeaderText="Prodotti della Wishlist" ShowHeader="False">
                <ItemTemplate>
                    <table style="width:659px; border-bottom: lightgrey solid; padding-bottom: 2px; margin-bottom: 2px;">
                        <tr>
                            <td rowspan="4" style=" width:150px; height:100px; border-style:solid; border-width:1px; border-color:lightgrey; text-align:center; vertical-align:middle;">
                                Immagine Prodotto
                                <asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("id") %>' >
                                <asp:Image ID="Image1" runat="server" style=" max-height:170px; width:150px;" AlternateText='<%# Eval("Descrizione1") %>' ImageUrl='<%# checkImg(Eval("img1")) %>' />
                                </asp:HyperLink>
                                 Controllo se esiste l'immagine 
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
                                            Return "public/foto/" & imgname
                                        Else
                                            Return "Public/Foto/img_non_disponibile.png"
                                        End If
                                    End Function
                                </script>
                                 Immagine e Descrizone Marca 
                                <div style="width:150px;  text-align:center; vertical-align:bottom;">
                                    <asp:Image ID="Image2" runat="server" style="margin:auto auto 0 auto; max-width:150px; max-height:100px;" AlternateText='<%# Eval("MarcheDescrizione") %>' ImageUrl='<%# Eval("Marche_img", "~/Public/Marche/{0}") %>' visible='<%# controllo_img(Eval("Marche_img")) %>'/>
                                </div>
                                
                                <br />
                                 Mi Piace di Facebook 
                                    <div style="width:100%; text-align:center;">
                                    <img alt="" src="Public/Images/facebook_su.png"/>
                                    <br />
                                     Pulsante Facebook, MI PIACE<iframe src='http://www.facebook.com/plugins/like.php?href=<%# "http://" & Request.Url.Host & "/articolo.aspx?id=" & Eval("id") %>&send=false&layout=button_count&width=100&show_faces=true&action=like&colorscheme=light&font&height=21' scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:70px; height:21px;"></iframe>
                                    </div>
                            </td>
                            <td colspan="2" style="padding-left:10px; padding-top:10px; padding-bottom:10px; padding-right:0px;">
                                 Titolo 
                                <span style="font-size:10pt; vertical-align:middle;">
                                <div style=" background-color: Gray; padding:5px;">
                                    <asp:Label ID="Label12" runat="server" Text=' <%# Eval("MarcheDescrizione") %>' Font-Size="11pt" Font-Bold="true" Height="10px" ForeColor="yellow" style="display:inline;"></asp:Label>
                                    <asp:HyperLink ID="HyperLink5"  ToolTip='<%# Eval("SettoriDescrizione") &" > "&  Eval("CategorieDescrizione") &" > "& Eval("MarcheDescrizione") &" > "& Eval("TipologieDescrizione") &" > "&  Eval("GruppiDescrizione") &" > "&  Eval("SottogruppiDescrizione") &" > "&  Eval("Codice") %>' runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("id") %>'>
                                    <asp:Label ID="Label8" runat="server" Text='<%# " - " & Eval("Descrizione1") %>' Font-Size="9pt" Font-Bold="true" ForeColor="White"></asp:Label>
                                    </asp:HyperLink>
                                    <br />
                                    <a href='<%# "articoli.aspx?tp=" & Eval("TipologieId") & "&mr=" & Eval("MarcheId") %>''><span style="color:Yellow; font-size:7pt;">
                                    in <%# Eval("SettoriDescrizione") &" > "&  Eval("CategorieDescrizione") &" > "& Eval("MarcheDescrizione")%></span></a>
                                </div>
                                 PROMO 
                                <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"  SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                                    <SelectParameters>
                                        <asp:ControlParameter Name="ID" ControlID="tbID" PropertyName="Text" Type="Int32" />
                                        <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                                    </SelectParameters>
                                </asp:SqlDataSource>
                                
                                <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                                <ItemTemplate>
                                <%Session("InOfferta") = 1%>
                                <table visible='<%# Eval("InOfferta")%>' style="height:27px; border-style:none;" cellspacing="0">
                                    <tr>
                                        <td style="background-image:url('Images/Promo/01.gif'); background-repeat:no-repeat; width:91px;">
                                        </td>
                                        <td style="background-image:url('Images/Promo/02.gif'); background-repeat:repeat-x; vertical-align:middle; padding-left:10px;">
                                            <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# Eval("PrezzoPromo") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%# Eval("PrezzoPromoIvato") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:Label>
                                            <div style="margin-top:-10px;">
                                                <asp:Label ID="lblOfferta" runat="server" Visible='<%# Eval("InOfferta")%>' Font-Size="7pt" Text='<%# "<br>DAL "& Eval("OfferteDataInizio") &" AL "& Eval("OfferteDataFine") %>' ForeColor="Black"></asp:Label>
                                            </div>
                                        </td>
                                        <td style="background-image:url('Images/Promo/03.gif'); background-repeat:no-repeat; width:17px;">
                                        </td>
                                    </tr>
                                </table>
                                </ItemTemplate>
                                </asp:Repeater>
                                </span>     
                            </td>
                        </tr>
                        <tr>
                            <td style="padding:10px;">
                                <asp:TextBox ID="tbID" runat="server" Text='<%# Eval("ID") %>' Width="30" EnableViewState="false" Visible="false" ></asp:TextBox>
                                <asp:TextBox ID="tbInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Width="30" EnableViewState="false" Visible="false" ></asp:TextBox>

                                <div>
                                    <script runat="server">
                                        Function sotto_stringa(ByVal temp As String) As String
                                            temp = Server.HtmlEncode(temp)
                                            Return Left(temp.Replace("&#160;", " "), 200) & " ..."
                                        End Function
                                    </script>
                                    <asp:Label ID="Label1" runat="server" Text='<%# Eval("Descrizione2") %>' Font-Size="7pt" Font-Italic="true" wrap="true" EnableTheming="False" EnableViewState="False"></asp:Label>
                                </div>
                                
                                <div style=" bottom:0px;">
                                <br /><asp:Label ID="Label5" runat="server" Text="Codice: " Font-Bold="True" Width="50"></asp:Label><asp:Label ID="Label3" runat="server"  Text='<%# Eval("Codice") %>' Width="80%" ForeColor="blue"></asp:Label>
                                <br /><asp:Label ID="Label6" runat="server" Text="EAN: " Font-Bold="True" Width="50"></asp:Label><asp:Label ID="Label7" runat="server"  Text='<%# Eval("Ean") %>' Width="80%" ForeColor="blue"></asp:Label>
                                <br /><asp:Label ID="Label13" runat="server" Text="ID Art.: " Font-Bold="True" Width="50"></asp:Label><asp:Label ID="Label_idArticolo" runat="server"  Text='<%# Eval("id") %>' Width="80%" ForeColor="blue"></asp:Label>
                                </div>
                            </td>
                            <td>
                                 Disponibilità 
                                &nbsp;
                                
                                 
                                <div style=" text-align:right; padding-bottom:3px;">
                                    <asp:Label ID="lblID" runat="server" Text='<%# Bind("ID") %>' style="z-index:-1;" Visible="false"></asp:Label>
                                    &nbsp;
                                <asp:Label ID="lblArrivo" runat="server" Text='<%# Eval("InOrdine")%>' Visible="false"></asp:Label><br />
                                    <div style="padding-right: 10px; background-position: right 50%; background-image: url(Public/Images/info_disp.png);
                                        width: 180px; color: black; padding-top: 10px; background-repeat: no-repeat; height: 50px; margin:0 0 0 auto;">
                                         Informazioni Articolo 
                                        <div>
                                            <table style="width:150px; height:30px; float:right;" cellspacing="0" cellpadding="0">
                                                <tr>
                                                    <td>
                                                        <asp:Label ID="lblDispo" runat="server" Font-Bold="True" Text="Disponibilità: "></asp:Label>
                                                    </td>
                                                    <td>
                                                        <asp:Label ID="Label_dispo" runat="server" ForeColor="Red" Text='<%# Eval("Giacenza") %>'></asp:Label>
                                                        <asp:Image ID="imgDispo" runat="server"/>
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <td>
                                                        <asp:Label ID="lblImpegnata" runat="server" Font-Bold="True" Text="Impegnati: "></asp:Label>
                                                    </td>
                                                    <td>
                                                        <asp:Label ID="Label_imp" runat="server" ForeColor="Red" Text='<%# Eval("Impegnata") %>'></asp:Label>
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <td>
                                                        <asp:Label ID="lblArrivo2" runat="server" Font-Bold="True" Text="In Arrivo: "></asp:Label>
                                                    </td>
                                                    <td>
                                                       <asp:Label ID="Label_arrivo" runat="server" ForeColor="Red" Text='<%# Eval("InOrdine") %>' style="padding-right"></asp:Label>
                                                        <asp:Image ID="imgArrivo" runat="server" Visible="false"/>
                                                    </td>
                                                </tr>
                                            </table>
                                        </div>
                                    </div>
                                        &nbsp;
                                    <br />

                                     Cifre con immagini 
                                    <div style="padding:0px; float:right; color: black; width: 200px;">
                                    <asp:Image ID="img_prezzo9" runat="server" Height="30px" Visible="False" />
                                    <asp:Image ID="img_prezzo8" runat="server" Height="30px" Visible="False" />
                                    <asp:Image ID="img_prezzo7" runat="server" Height="30px" Visible="False" />
                                    <asp:Image ID="img_prezzo6" runat="server" Height="30px" Visible="False" />
                                    <asp:Image ID="img_prezzo5" runat="server" Height="30px" Visible="False" />
                                    <asp:Image ID="img_prezzo4" runat="server" Height="30px" Visible="False" />
                                    <asp:Image ID="img_prezzo3" runat="server" Height="20px" Visible="False" />
                                    <asp:Image ID="img_prezzo2" runat="server" Height="20px" Visible="False" />
                                    <asp:Image ID="img_prezzo1" runat="server" Height="20px" Visible="False" />&nbsp;
                                    <%  
                                        If Session("InOfferta") = 1 Then
                                            Session("InOfferta") = 0
                                    %>
                                    <div style="height:20px;">
                                    <asp:Panel ID="Panel_in_offerta" runat="server" Height="15px" Width="150px" Visible="False" style="margin:0 0 0 auto;">
                                        invece di
                                    <asp:Label ID="Label4" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>' ForeColor="Red" style="text-decoration:line-through;"></asp:Label><asp:Label ID="Label10" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Visible="False" ForeColor="Red"></asp:Label></asp:Panel>
                                    </div>
                                    <%  End If%>
                                    </div>

                                    <asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>'></asp:Label>
                                    <asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Visible="false"></asp:Label>
                                    <br />
                                    <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# Eval("Prezzo", "{0:C}") %>' Visible='<%# Eval("InOfferta") %>'></asp:Label>                         
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbQuantita" Display="Dynamic" ErrorMessage="!" SetFocusOnError="True"></asp:RequiredFieldValidator>
                                    <asp:CompareValidator ID="CompareValidator2" runat="server" ControlToValidate="tbQuantita" Display="Dynamic"  ErrorMessage="!" Operator="GreaterThan" SetFocusOnError="True"  Type="Integer" ValueToCompare="0"></asp:CompareValidator>
                                        <br />
                                   <asp:HyperLink ID="HyperLink2" Visible="false" runat="server" ImageUrl='<%# "images/cart.gif" %>'  Text="Scheda Prodotto"></asp:HyperLink>
                                    &nbsp;&nbsp;&nbsp;
                               </div>
                            </td>
                        </tr>
                        <tr>
                            <td nowrap="nowrap" style="text-align: right; height:41px; padding-right:10px; background-image:url('Images/sfondo_carrello.png'); background-position: bottom right; background-repeat:no-repeat;" colspan="2">
                                <div style="float:left; vertical-align:bottom;  width:120px; padding-top:10px">
                                    <asp:Image ID="img_offerta" runat="server" ImageUrl="~/Images/icon_ecommerce/golden_offer.png"
                                        Visible="False" style="float:left;"/>
                                    <asp:Image ID="img_regalo" runat="server" ImageUrl="~/Images/icon_ecommerce/present.png"
                                        Visible="False" style="float:left;"/>
                                    <asp:Image ID="img_nodisp" runat="server" ImageUrl="~/Images/icon_ecommerce/cancel.png"
                                        Visible="False" style="float:left;"/>
                                    <asp:Image ID="img_trasportogratis" runat="server" ImageUrl="~/Images/icon_ecommerce/bag_green.png"
                                        Visible="False" style="float:left;"/>

                                     Spedizione Gratis 
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
                                                    <img style="border-width:0px; background-color:white; margin-top:5px;" src="Images/freeshipping.gif" title='Questo articolo verrà spedito GRATIS !!! fino al <%# Eval("SpedizioneGratis_Data_Fine","{0:d}") %>' alt="" />
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                        </Columns>
                                        <RowStyle BorderColor="White" BorderWidth="0px" />
                                        <PagerStyle BorderColor="White" BorderWidth="0px" />
                                    </asp:GridView>
                                     --------------------------------------------------------------------------------------------------- 
                                    </div> 
                                
                                <table style=" vertical-align:middle; margin: 0px 0px 0px auto;">
                                        <tr>
                                           <td>
                                                <div style="margin-top:18px; margin-right:55px;">
                                                    <asp:LinkButton ID="LB_wishlist" runat="server" OnClick="BT_Rimuovi_wishlist_Click">- Wishlist</asp:LinkButton>
                                                </div>
                                            </td>
                                           <td>
                                                <div style="margin-top:18px; margin-right:18px;">
                                                    <a href='<%# "articolo.aspx?id="& Eval("id") %>'>Scheda Tecnica</a>
                                                </div>
                                           </td>
                                           <td>
                                                <asp:TextBox ID="tbQuantita" runat="server" Width="20px" style="text-align:right;font-size:8pt">1</asp:TextBox>
                                           </td>
                                           <td>
                                                <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" BorderWidth="2" BorderColor="#CCCCCC" BorderStyle="Solid" />
                                           </td>
                                           <td>
                                                <asp:ImageButton ID="ImageButton1" runat="server" ImageUrl="Images/cart.png" ToolTip="Aggiungi al Carrello" OnClick="ImageButton1_Click" />
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
    
    <div style="margin-top:18px; margin-right:55px; width:100%;">
        <asp:LinkButton ID="LB_cancella_tutta_wishlist" runat="server" style=" border-style:none; text-decoration:none; border-width:0px; border-style:none; text-decoration:none; font-weight:bold; float:left;"><img style=" border-style:none; text-decoration:none; border-width:0px;" alt="" src="Images/svuota_wishlist.jpg"  /></asp:LinkButton>
        <% If Session("genera_html_mail") = 1 Then%>
            <asp:LinkButton ID="LB_crea_html" runat="server" style=" border-style:none; text-decoration:none; border-width:0px; float:right; font-weight:bold;"><img style=" border-style:none; text-decoration:none; border-width:0px;" alt="" src="Images/crea_html.jpg"  /></asp:LinkButton>
        <%End If%>
    </div>
    <br /><br /><br /><br />
    <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label><br /><br />
	
-->

	<asp:Repeater ID="Repeater1" runat="server" DataSourceID="sdsArticoli" >
                <ItemTemplate>
                    <div class="row table-res m-0" style="/*border-style:dotted;*/ border-bottom-style:none; border-color:Gray; border-width:1px;">
                        
                            <div class="col-2" style="align-self: center; width:20%; flex:0 0 auto; max-width:none;">
                                <!-- Immagine -->
                                    <asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") %>' >
										<asp:Image ID="Image2" runat="server" style="width: 100%;"  AlternateText='<%# Eval("Descrizione1") %>' ImageUrl='<%# Eval("img1", "~/Public/foto/_{0}") %>' />
									</asp:HyperLink>
                            </div>
                            <div class="col-6 col-md-5" style="width:50%; flex:0 0 auto; max-width:none;">
								<div class="table-res-header">
									Descrizione
								</div>
							
                                <table style="border-collapse:collapse;">
                                    <tr>
                                        <td style="font-size:10pt; vertical-align:top;">
                                            <!-- Descrizione -->
                                            <asp:HyperLink ID="HyperLink5" ToolTip='<%# Eval("Descrizione1") %>' runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") %>' style="cursor:hand">
                                                <asp:Label ID="Label2" runat="server" Text='<%# Eval("MarcheDescrizione") %>' Font-Bold="True" Font-Size="10pt" ForeColor="Red"></asp:Label><span style="padding-left:5px; font-size:9pt;"><%#controllaLunghezzaTesto(Eval("Descrizione1"), 60)%></span>
                                            </asp:HyperLink>
                                            </br>
                                            <asp:Label ID="tagliecolori" runat="server" Text='<%# Eval("taglia") & " " & Eval("colore") %>'></asp:Label>
                                            <asp:TextBox ID="tbArtID" runat="server" Text='<%# Eval("ArticoliID") %>' Visible="false"></asp:TextBox>
                                            
                                        
                                            <asp:Label ID="lblValoreIva" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Style="line-height: 150%" Text='<%# Eval("Valoreiva") %>' Visible="False"></asp:Label>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>
                                            <table style="width:100%;">
                                                <tr>
                                                    <td style="position:relative; width:50%; text-align:left; padding-right:10px;">
                                                        Codice<asp:Label ID="Label3" runat="server"  Text='<%# Eval("Codice") %>' Font-Size="8pt" style="padding-left:10px; font-weight:bold;"></asp:Label>
                                                    </td>
                                                </tr>
												<tr>
                                                    <td style="position:relative; width:50%; text-align:left; padding-right:10px;">
                                                        Disponibilità<asp:Image ID="imgDispo" runat="server" style="padding-left:10px;" /><asp:Label ID="lblDispo" runat="server" Text='<%# Eval("giacenza")%>' Font-Size="8pt" style="padding-left:10px; font-weight:bold;"></asp:Label>
                                                    </td>
                                                
                                                    <asp:Label ID="Label7" runat="server"  Text='<%# Eval("Ean") %>' Font-Size="5pt" Visible="false"></asp:Label>    
                                                    <asp:Label ID="lblImp" runat="server" Text='<%# Eval("Impegnata")%>' Font-Size="6pt" Visible="false"></asp:Label>
                                                    <asp:Label ID="lbl" runat="server" Text='<%# Eval("InOrdine")%>' Font-Size="6pt" Visible="false"></asp:Label>
                                                </tr>
                                            </table>
                                        </td>
                                    </tr>
                                </table>
                            </div>
							<div class="col-2" style="width:20%; flex:0 0 auto; max-width:none;">
								<div class="table-res-header">
									Prezzo
								</div>
								<div style="text-align:center; font-weight:bold; vertical-align:top;">
									<asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>'></asp:Label>
									<div style="font-size:7pt; color:Red; font-weight:normal; padding-top:5px;"><span style="color:rgb(192, 192, 192);"><%= IIf(Me.Session("IvaTipo") = 1, "+", "")%>IVA. <%# Eval("ValoreIva")%>%</span></div>
								</div>
							</div>
							<div class="col-2 col-md-1" style="width:10%; flex:0 0 auto; max-width:none;">
								<div class="table-res-header">
									Elimina
								</div>
								<div style="text-align:center; font-size:10pt; vertical-align:top; border-right-style:solid; border-left-style:solid; border-color:#f0f0f0; border-width:1px;">
									<div style="padding-top:5px;">
										<asp:LinkButton ID="LB_Delete" CommandName="Elimina" CommandArgument='<%# Eval("id") %>' runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" style="margin:auto; font-size:7pt; color:rgb(205, 38, 44);">X</asp:LinkButton>
									</div>
	  
									<asp:TextBox ID="tbID" runat="server" Text='<%# Eval("id") %>' Visible="false"/>
								</div>
							</div>
                        
                        
                        <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                            SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino GROUP BY offerteQntMinima, offerteMultipli, nlistino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                            <SelectParameters>
                                <asp:ControlParameter Name="ID" ControlID="tbArtID" PropertyName="Text" Type="Int32" />
                                <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                            </SelectParameters>
                        </asp:SqlDataSource>
                        
                        <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                            <ItemTemplate>
                                <tr>
                                    <td style="display:none;">
                                        <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# Eval("PrezzoPromo") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%# Eval("PrezzoPromoIvato") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblDataInizio" runat="server" Text='<%# Eval("OfferteDataInizio") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblDataFine" runat="server" Text='<%# Eval("OfferteDataFine") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblidIvaRC" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Text='<%# Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                        <asp:Label ID="lblValoreIvaRC" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Text='<%# Eval("ValoreIvaRC") %>' Visible="False"></asp:Label>
                                    </td>
                                </tr>
                                <tr>
                                    <td colspan="2" style="border-style:dotted; font-size:6pt; border-width:1px; border-color:Gray; text-align:left; vertical-align:middle; font-weight:bold; background-color:rgb(244, 244, 244); <%# iif(Eval("InOfferta")=1,"","display:none;") %>">
                                        <div style="float:left; background-color:Red; color:White; padding:2px;">PROMO</div>
                                        <asp:Label ID="lblOfferta" runat="server" Visible="false" Font-Size="7pt" Text='<%# "PROMO FINO AL "& Eval("OfferteDataFine") %>' ForeColor="black" style="padding-left:20px;"></asp:Label>
                                    </td>
                                </tr>   
                            </ItemTemplate>
                        </asp:Repeater>
                            
                    </div>
                </ItemTemplate>
        </asp:Repeater>
</asp:Content>

