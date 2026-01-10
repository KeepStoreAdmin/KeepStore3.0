<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="carrello.aspx.vb" Inherits="carrello" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server"><%: Page.Title %></asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <!-- Carrello (KEEPSTORE3) - HeadContent lasciato intenzionalmente minimale -->
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <!-- ============================================================
         carrello.aspx (KEEPSTORE3 - TEMPLATE-FIRST)
         FIX PARSER: nessun markup/commento fuori dai blocchi <asp:Content>
         NOTE: markup derivato da Entropic per stabilità + compatibilità IDs.
         ============================================================ -->

    <!-- Page Title / Breadcrumb (template wrapper) -->
    <section class="tf-page-title style-2">
        <div class="container">
            <div class="tf-page-title-inner">
                <h1 class="heading">Carrello</h1>
                <ul class="tf-breadcrumb">
                    <li><a href="Default.aspx">Home</a></li>
                    <li>Carrello</li>
                </ul>
            </div>
        </div>
    </section>




    <asp:ScriptManager ID="ScriptManager1" runat="server" />

    <asp:Panel ID="PanelDestinazione" runat="server" Style="display: none">
        <div id="Div1" class="checkout_box_500">
            <div id="Div2" style="margin: 0px 20px; padding-top: 15px; height: 500px;">
                <h2>
                    <asp:Label ID="lblIntestDestinazione" runat="server"></asp:Label>
                </h2>
                <hr size="0" />
                <div>
                    <div>
                        <br />
                        <label for="rdoExisting">Già esiste una seconda destinazione predefinita. 
                        Sostituirla con questa?</label>
                    </div>
                    <div class="inputcontainer">
                        <p style="text-align: center">
                            <br />
                            <asp:ImageButton runat="server" ID="ImgBtnDestinazioneSi" ImageUrl="images/modalok.png" TITLE="SI" STYLE="cursor:pointer;" />
                            &nbsp;
                            <asp:ImageButton runat="server" ID="ImgBtnDestinazioneNo" ImageUrl="images/modalno.png" TITLE="NO" STYLE="cursor:pointer;" />
                        </p>
                    </div>
                </div>
                
            </div>
        </div>
    </asp:Panel>
    <asp:LinkButton ID="dummy2" runat="server"></asp:LinkButton>





    <h1>Il tuo carrello</h1>

<br />
    <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        EnableViewState="False" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT vcarrello.id, vcarrello.LoginId, vcarrello.SessionId, vcarrello.DataOra, vcarrello.ArticoliId, vcarrello.Codice, vcarrello.Descrizione1, vcarrello.Qnt, vcarrello.NListino, vcarrello.OfferteDettaglioID, vcarrello.Ean, vcarrello.Descrizione2, vcarrello.UmID, vcarrello.MarcheId, vcarrello.MarcheDescrizione, vcarrello.MarcheOrdinamento, vcarrello.iva, vcarrello.Peso, vcarrello.PesoRiga, vcarrello.Img1, vcarrello.Giacenza, vcarrello.InOrdine, vcarrello.Disponibilita, vcarrello.Impegnata, vcarrello.ScortaMinima, vcarrello.Prezzo, vcarrello.PrezzoIvato, vcarrello.Importo, vcarrello.ImportoIvato, articoli.SpedizioneGratis_Listini, articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine FROM vcarrello LEFT OUTER JOIN articoli ON vcarrello.ArticoliId = articoli.id WHERE (articoli.SpedizioneGratis_Listini IS NULL) ORDER BY vcarrello.id"
        DeleteCommand="delete from carrello where (Id = ?Id)"
        UpdateCommand="update carrello set qnt = ?Qnt where (Id = ?Id)">
                    
    </asp:SqlDataSource><asp:SqlDataSource ID="sdsArticoli_Spedizione_Gratis" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        EnableViewState="False" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT vcarrello.id, vcarrello.LoginId, vcarrello.SessionId, vcarrello.DataOra, vcarrello.ArticoliId, vcarrello.Codice, vcarrello.Descrizione1, vcarrello.Qnt, vcarrello.NListino, vcarrello.OfferteDettaglioID, vcarrello.Ean, vcarrello.Descrizione2, vcarrello.UmID, vcarrello.MarcheId, vcarrello.MarcheDescrizione, vcarrello.MarcheOrdinamento, vcarrello.iva, vcarrello.Valoreiva, vcarrello.Peso, vcarrello.PesoRiga, vcarrello.Img1, vcarrello.Giacenza, vcarrello.InOrdine, vcarrello.Disponibilita, vcarrello.Impegnata, vcarrello.ScortaMinima, vcarrello.Prezzo, vcarrello.PrezzoIvato, vcarrello.Importo, vcarrello.ImportoIvato, articoli.SpedizioneGratis_Listini, articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine FROM vcarrello LEFT OUTER JOIN articoli ON vcarrello.ArticoliId = articoli.id WHERE (articoli.SpedizioneGratis_Listini IS NOT NULL) ORDER BY vcarrello.id"
        DeleteCommand="delete from carrello where (Id = ?Id)"
        UpdateCommand="update carrello set qnt = ?Qnt where (Id = ?Id)">
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
        
    
    <!-- Sezione degli Articoli Spediti GRATIS -->
	<asp:Repeater ID="gvArticoliGratis" runat="server" DataSourceID="sdsArticoli_Spedizione_Gratis" OnItemCommand="gvArticoliGratis_ItemCommand">

                <ItemTemplate>
                    <div class="row table-res m-0" style="border-style:dotted; border-bottom-style:none; border-color:Gray; border-width:1px;">
                        
                            <div class="col-2" style="align-self: center;">
                                <!-- Immagine -->
                                <div class="text-center">
                                    <asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") &"&TCid=" & Eval("TCid") %>' >
										<asp:Image ID="Image2" runat="server" style="width: 100%; max-width: 90px;" ImageUrl='<%# checkImg(Eval("img1")) %>' />
									</asp:HyperLink>
                                </div>
                            </div>
                            <div class="col-6 col-md-5">
								<div class="table-res-header">
									Descrizione
								</div>
							
                                <table style="border-collapse:collapse; width:100%">
                                    <tr>
                                        <td style="font-size:10pt; vertical-align:top;">
                                            <!-- Descrizione -->
                                            <asp:HyperLink ID="HyperLink5" ToolTip='<%# Eval("Descrizione1") %>' runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") &"&TCid=" & Eval("TCid") %>' style="cursor:hand">
                                                <asp:Label ID="Label2" runat="server" Text='<%# Eval("MarcheDescrizione") %>' Font-Bold="True" Font-Size="10pt" ForeColor="Red"></asp:Label><span style="padding-left:5px; font-size:9pt;"><%#controllaLunghezzaTesto(Eval("Descrizione1"), 60)%></span>
                                            </asp:HyperLink>
                                            </br>
                                            <asp:Label ID="tagliecolori" runat="server" Text='<%# Eval("taglia") & " " & Eval("colore") %>'></asp:Label>
                                            <asp:TextBox ID="tbArtID" runat="server" Text='<%# Eval("ArticoliID") %>' Visible="false"></asp:TextBox>
                                            
                                            <asp:Label ID="lblIvaReverseCharge" runat="server" Text='<%# stampa_iva_applicata(If(IsDBNull(Eval("DescrizioneEsenzioneIva")), "", Eval("DescrizioneEsenzioneIva")),If(IsDBNull(Eval("DescrizioneIvaRC")), "", Eval("DescrizioneIvaRC"))) %>' Visible="true" Font-Size="7pt"></asp:Label>
                                            <asp:Label ID="lblValoreIva" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Style="line-height: 150%" Text='<%# Eval("Valoreiva") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblidIvaRC" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Style="line-height: 150%" Text='<%# Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblPeso" runat="server" Text='<%# Eval("PesoRiga") %>' Visible="False"></asp:Label>
<asp:Label ID="lblArrivo" runat="server" Text="0" Visible="False"></asp:Label>
                                        </td>
                                    </tr>
                                </table>
								<div class="row">
									<div class="col-12 col-md-6 pr-0">								
										Codice<asp:Label ID="Label3" runat="server"  Text='<%# Eval("Codice") %>' Font-Size="8pt" style="padding-left:10px; font-weight:bold;"></asp:Label>
									
										<asp:Label ID="Label7" runat="server"  Text='<%# Eval("Ean") %>' Font-Size="5pt" Visible="false"></asp:Label>    
										<asp:Label ID="lblImp" runat="server" Text='<%# Eval("Impegnata")%>' Font-Size="6pt" Visible="false"></asp:Label>
										<asp:Label ID="lbl" runat="server" Text='<%# Eval("InOrdine")%>' Font-Size="6pt" Visible="false"></asp:Label>
									</div>
									<div class="col-12 col-md-6 pr-0">
										Disponibilità<asp:Image ID="imgDispo" runat="server" style="padding-left:10px;" /><asp:Label ID="lblDispo" runat="server" Text='<%# Eval("giacenza")%>' Font-Size="8pt" style="padding-left:10px; font-weight:bold;"></asp:Label>
									</div>
								</div>
                            </div>
							<div class="col-2">
								<div class="table-res-header">
									Prezzo
								</div>
								<div style="text-align:center; font-weight:bold; vertical-align:top;">
									<asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>'></asp:Label>
									<asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>'></asp:Label>
									<div style="font-size:7pt; color:Red; font-weight:normal; padding-top:5px;"><span style="color:rgb(192, 192, 192);"><%= IIf(Me.Session("IvaTipo") = 1, "+", "")%>IVA. <%# Eval("ValoreIva")%>%</span></div>
									<div style="margin:auto;"><img src="Images/spedizione_gratis.png" alt="" style="padding:10px; height:30px;"/></div>																						
								</div>
							</div>
							<div class="col-2 col-md-1">
								<div class="table-res-header">
									Q.tà
								</div>
								<div style="width:55px; text-align:center; font-size:10pt; vertical-align:top; border-right-style:solid; border-left-style:solid; border-color:#f0f0f0; border-width:1px;">
									<i data-qty-action="decrementQty" style="color: #383838; font-size:11px; margin: 0px!important;" class="fa fa-minus-circle fa-2x align-self-center mx-1"></i>
									<asp:TextBox ID="tbQta" runat="server" Text='<%# Eval("qnt") %>' style="width:20px; font-size:11pt; font-weight:bold; border-style:none; text-align:center; border-style:none;" MaxLength="4"/>
									<i data-qty-action="incrementQty" style="color: #383838; font-size:11px; margin: 0px!important;" class="fa fa-plus-circle fa-2x align-self-center mx-1"></i>		
									<div>
										<asp:LinkButton ID="LB_Aggiorna" CommandName="Aggiorna" runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" style="margin:auto; font-size:7pt; color:Gray;">Aggiorna</asp:LinkButton>
									</div>
									<div style="padding-top:5px;">
										<asp:LinkButton ID="LB_Delete" CommandName="Elimina" CommandArgument='<%# Eval("id") %>' runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" style="margin:auto; font-size:7pt; color:rgb(205, 38, 44);">Elimina</asp:LinkButton>
									</div>
	  
									<asp:TextBox ID="tbID" runat="server" Text='<%# Eval("id") %>' Visible="false"/>
								</div>
							</div>
                            <div class="offset-2 col-10 offset-md-0 col-md-2" style="text-align:right; vertical-align:middle; font-weight:bold; font-size:12pt;">
								<div class="table-res-header">
									Prezzo Totale
								</div>
                                <table style=" width:100%; height:100%; vertical-align:top; text-align:center;">
                                    <tr>
                                        <td style="font-weight: 800; vertical-align:top; color:rgb(205, 38, 44);">
                                            <asp:Label ID="lblImportoIvato" runat="server" Text='<%# Bind("ImportoIvato", "{0:C}") %>'></asp:Label>
                                            <asp:Label ID="lblImporto" runat="server" Text='<%# Bind("Importo", "{0:C}") %>' Visible="false"></asp:Label>
                                        </td>
                                    </tr>
                                </table>
                            </div>
                        <div class="col-12 mt-2"></div>
                        
						
                        <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                            SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino GROUP BY offerteQntMinima, offerteMultipli, nlistino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                            <SelectParameters>
                                <asp:ControlParameter Name="ID" ControlID="tbArtID" PropertyName="Text" Type="Int32" />
                                <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                            </SelectParameters>
                        </asp:SqlDataSource>
                        
                        <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                            <ItemTemplate>
                                <div>
                                    <div style="display:none;">
                                        <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# Eval("PrezzoPromo") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%# Eval("PrezzoPromoIvato") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblDataInizio" runat="server" Text='<%# Eval("OfferteDataInizio") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblDataFine" runat="server" Text='<%# Eval("OfferteDataFine") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblidIvaRC" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Text='<%# Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                        <asp:Label ID="lblValoreIvaRC" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Text='<%# Eval("ValoreIvaRC") %>' Visible="False"></asp:Label>
                                    </div>
                                </div>
								<div class="col-12" style="<%# iif(Eval("InOfferta")=1,"","display:none;") %>">
									<div class="d-inline-flex w-100-mobile" style="min-width: 55%;border-style:dotted; font-size:6pt; border-width:1px; border-color:Gray; text-align:left; vertical-align:middle; font-weight:bold; background-color:rgb(244, 244, 244);">
										<div style="float:left; background-color:Red; color:White; padding:2px; border-bottom-style: none; border-top-style: dotted; border-color: Gray; border-width: 1px;">PROMO</div>
										<asp:Label ID="lblOfferta" runat="server" Visible="false" Font-Size="8pt" Text='<%# "PROMO FINO AL "& Eval("OfferteDataFine") %>' ForeColor="black" style="border-bottom-style: none; border-top-style: dotted; border-right-style: dotted; border-color: Gray; border-width: 1px; padding: 2px; background: #f4f4f4;padding-left:20px;width: 100%;"></asp:Label>
									</div>
								</div>
                            </ItemTemplate>
                        </asp:Repeater>
                            
                    </div>
                </ItemTemplate>
    </asp:Repeater>
    
    <!-- Sezione degli Articoli normali, senza spedizione Gratis -->
    <asp:Repeater ID="Repeater1" runat="server" DataSourceID="sdsArticoli" OnItemCommand="Repeater1_ItemCommand">
        
            
                <ItemTemplate>
                    <div class="row table-res m-0" style="border-style:dotted; border-bottom-style:none; border-color:Gray; border-width:1px;">
                        
                            <div class="col-2" style="align-self: center;">
                                <!-- Immagine -->
                                <div class="text-center">
                                    <asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") &"&TCid=" & Eval("TCid") %>' >
										<asp:Image ID="Image2" runat="server" style="width: 100%; max-width: 90px;" ImageUrl='<%# checkImg(Eval("img1")) %>' />
									</asp:HyperLink>
                                </div>
                            </div>
                            <div class="col-6 col-md-5">
								<div class="table-res-header">
									Descrizione
								</div>
							
                                <table style="border-collapse:collapse; width:100%">
                                    <tr>
                                        <td style="font-size:10pt; vertical-align:top;">
                                            <!-- Descrizione -->
                                            <asp:HyperLink ID="HyperLink5" ToolTip='<%# Eval("Descrizione1") %>' runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") &"&TCid=" & Eval("TCid") %>' style="cursor:hand">
                                                <asp:Label ID="Label2" runat="server" Text='<%# Eval("MarcheDescrizione") %>' Font-Bold="True" Font-Size="10pt" ForeColor="Red"></asp:Label><span style="padding-left:5px; font-size:9pt;"><%#controllaLunghezzaTesto(Eval("Descrizione1"), 60)%></span>
                                            </asp:HyperLink>
                                            </br>
                                            <asp:Label ID="tagliecolori" runat="server" Text='<%# Eval("taglia") & " " & Eval("colore") %>'></asp:Label>
                                            <asp:TextBox ID="tbArtID" runat="server" Text='<%# Eval("ArticoliID") %>' Visible="false"></asp:TextBox>
                                            
                                            <asp:Label ID="lblIvaReverseCharge" runat="server" Text='<%# stampa_iva_applicata(If(IsDBNull(Eval("DescrizioneEsenzioneIva")), "", Eval("DescrizioneEsenzioneIva")),If(IsDBNull(Eval("DescrizioneIvaRC")), "", Eval("DescrizioneIvaRC"))) %>' Visible="true" Font-Size="7pt"></asp:Label>
                                            <asp:Label ID="lblValoreIva" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Style="line-height: 150%" Text='<%# Eval("Valoreiva") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblidIvaRC" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Style="line-height: 150%" Text='<%# Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblPeso" runat="server" Text='<%# Eval("PesoRiga") %>' Visible="False"></asp:Label>
<asp:Label ID="lblArrivo" runat="server" Text="0" Visible="False"></asp:Label>
                                        </td>
                                    </tr>
                                    
                                </table>
								<div class="row">
									<div class="col-12 col-md-6 pr-0">								
										Codice<asp:Label ID="Label3" runat="server"  Text='<%# Eval("Codice") %>' Font-Size="8pt" style="padding-left:10px; font-weight:bold;"></asp:Label>
									
										<asp:Label ID="Label7" runat="server"  Text='<%# Eval("Ean") %>' Font-Size="5pt" Visible="false"></asp:Label>    
										<asp:Label ID="lblImp" runat="server" Text='<%# Eval("Impegnata")%>' Font-Size="6pt" Visible="false"></asp:Label>
										<asp:Label ID="lbl" runat="server" Text='<%# Eval("InOrdine")%>' Font-Size="6pt" Visible="false"></asp:Label>
									</div>
									<div class="col-12 col-md-6 pr-0">
										Disponibilità<asp:Image ID="imgDispo" runat="server" style="padding-left:10px;" /><asp:Label ID="lblDispo" runat="server" Text='<%# Eval("giacenza")%>' Font-Size="8pt" style="padding-left:10px; font-weight:bold;"></asp:Label>
									</div>
								</div>
                            </div>
							<div class="col-2">
								<div class="table-res-header">
									Prezzo
								</div>
								<div style="text-align:center; font-weight:bold; vertical-align:top;">
									<asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Eval("PrezzoIvato") %>'></asp:Label>
									<asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>'></asp:Label>
									<div style="font-size:7pt; color:Red; font-weight:normal; padding-top:5px;"><span style="color:rgb(192, 192, 192);"><%= IIf(Me.Session("IvaTipo") = 1, "+", "")%>IVA. <%# Eval("ValoreIva")%>%</span></div>
								</div>
							</div>
							<div class="col-2 col-md-1">
								<div class="table-res-header">
									Q.tà
								</div>
								<div style="width:55px; text-align:center; font-size:10pt; vertical-align:top; border-right-style:solid; border-left-style:solid; border-color:#f0f0f0; border-width:1px;">
									<i data-qty-action="decrementQty" style="color: #383838; font-size:11px; margin: 0px!important;" class="fa fa-minus-circle fa-2x align-self-center mx-1"></i>
									<asp:TextBox ID="tbQta" runat="server" Text='<%# Eval("qnt") %>' style="width:20px; font-size:11pt; font-weight:bold; border-style:none; text-align:center; border-style:none;" MaxLength="4"/>
									<i data-qty-action="incrementQty" style="color: #383838; font-size:11px; margin: 0px!important;" class="fa fa-plus-circle fa-2x align-self-center mx-1"></i>		
									<div>
										<asp:LinkButton ID="LB_Aggiorna" CommandName="Aggiorna" runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" style="margin:auto; font-size:7pt; color:Gray;">Aggiorna</asp:LinkButton>
									</div>
									<div style="padding-top:5px;">
										<asp:LinkButton ID="LB_Delete" CommandName="Elimina" CommandArgument='<%# Eval("id") %>' runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" style="margin:auto; font-size:7pt; color:rgb(205, 38, 44);">Elimina</asp:LinkButton>
									</div>
	  
									<asp:TextBox ID="tbID" runat="server" Text='<%# Eval("id") %>' Visible="false"/>
								</div>
							</div>
                            <div class="offset-2 col-10 offset-md-0 col-md-2" style="text-align:right; vertical-align:middle; font-weight:bold; font-size:12pt;">
								<div class="table-res-header">
									Prezzo Totale
								</div>
                                <table style=" width:100%; height:100%; vertical-align:top; text-align:center;">
                                    <tr>
                                        <td style="font-weight: 800; vertical-align:top; color:rgb(205, 38, 44);">
                                            <asp:Label ID="lblImportoIvato" runat="server" Text='<%# Bind("ImportoIvato", "{0:C}") %>'></asp:Label>
                                            <asp:Label ID="lblImporto" runat="server" Text='<%# Bind("Importo", "{0:C}") %>' Visible="false"></asp:Label>
                                        </td>
                                    </tr>
                                </table>
                            </div>
                        <div class="col-12 mt-2"></div>
                        
                        <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                            SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino GROUP BY offerteQntMinima, offerteMultipli, nlistino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                            <SelectParameters>
                                <asp:ControlParameter Name="ID" ControlID="tbArtID" PropertyName="Text" Type="Int32" />
                                <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                            </SelectParameters>
                        </asp:SqlDataSource>
                        
                        <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                            <ItemTemplate>
                                <div>
                                    <div style="display:none;">
                                        <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# Eval("PrezzoPromo") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%# Eval("PrezzoPromoIvato") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblDataInizio" runat="server" Text='<%# Eval("OfferteDataInizio") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblDataFine" runat="server" Text='<%# Eval("OfferteDataFine") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblidIvaRC" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Text='<%# Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                        <asp:Label ID="lblValoreIvaRC" runat="server" BackColor="#e12825" Font-Size="7pt" ForeColor="white" Text='<%# Eval("ValoreIvaRC") %>' Visible="False"></asp:Label>
                                    </div>
                                </div>
								<div class="col-12" style="<%# iif(Eval("InOfferta")=1,"","display:none;") %>">
									<div class="d-inline-flex w-100-mobile" style="min-width: 55%;border-style:dotted; font-size:6pt; border-width:1px; border-color:Gray; text-align:left; vertical-align:middle; font-weight:bold; background-color:rgb(244, 244, 244);">
										<div style="float:left; background-color:Red; color:White; padding:2px; border-bottom-style: none; border-top-style: dotted; border-color: Gray; border-width: 1px;">PROMO</div>
										<asp:Label ID="lblOfferta" runat="server" Visible="false" Font-Size="8pt" Text='<%# "PROMO FINO AL "& Eval("OfferteDataFine") %>' ForeColor="black" style="border-bottom-style: none; border-top-style: dotted; border-right-style: dotted; border-color: Gray; border-width: 1px; padding: 2px; background: #f4f4f4;padding-left:20px;width: 100%;"></asp:Label>
									</div>
								</div>
                            </ItemTemplate>
                        </asp:Repeater>
                            
                    </div>
                </ItemTemplate>
            
        
        
    </asp:Repeater>
    
    <div id="Qnt_Errata" runat="server" style=" width:97%; font-size:10pt; padding:10px; text-align:center; color:white; background-color:Red; font-weight:bold; border:dotted 1px black;" visible="false">
        E' stata impostata una quantità articolo minore o uguale a 0.<br />Eliminare l'articolo dal carrello o impostare una quantità maggiore di 0.
    </div>
    
    <!-- Buono Sconto -->
    <asp:SqlDataSource ID="SqlDataBuonoSconto" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        EnableViewState="False" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM buoni_sconti WHERE id=@idBuonoSconto">
        <SelectParameters>
            <asp:SessionParameter DefaultValue="0" Name="idBuonoSconto" SessionField="BuonoSconto_id" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>
    
    <asp:GridView ID="GV_BuoniSconti" DataSourceID="SqlDataBuonoSconto" runat="server" AutoGenerateColumns="False" GridLines="None" BorderStyle="None" CellSpacing="0" ShowHeader="False" Width="100%">
        <Columns>
            <asp:TemplateField>
                <ItemTemplate>
                    <asp:Label ID="lbl_idBuonoSconto" runat="server" Text='<%# Eval("id")%>' Visible="false"></asp:Label>
                    <asp:Label ID="lbl_Percentuale_BuonoSconto" runat="server" Text='<%# Eval("scontoPercentuale")%>' Visible="false"></asp:Label>
                    <asp:Label ID="lbl_scontoFisso_BuonoSconto" runat="server" Text='<%# Eval("scontoFisso")%>' Visible="false"></asp:Label>
                    <asp:Label ID="lbl_valore_BuonoSconto" runat="server" Text='<%# Eval("valore")%>' Visible="false"></asp:Label>
                    <asp:Label ID="lbl_ScontoVettore" runat="server" Text='<%# Eval("scontoVettore")%>' Visible="false"></asp:Label>
                   
                    <table style="width:100%; vertical-align:middle; border:2px red dotted; border-collapse:collapse;">
                        <tr>
                            <td colspan="2" style="text-align:center; color:White; font-weight:bold; font-size:15px; padding:2px; background-color:rgb(109, 109, 109);">
                                BUONO SCONTO
                            </td>
                        </tr>
                        <tr style="background-color:white;">
                            <td style="width:70%; padding:2px;">
                                <b style="font-size:15px;">
                                    <asp:Label ID="lbl_Descrizione1_BuonoSconto" runat="server" Text='<%#Eval("descrizione1")%>'></asp:Label></b><br />
                                    <asp:Label ID="lbl_Descrizione2_BuonoSconto" runat="server" Text='<%#Eval("descrizione2")%>'></asp:Label>
                            </td>
                            <td style="text-align:right; padding:2px; color:Red;">
                               <asp:Label ID="lbl_TotSconto" runat="server" Text=""></asp:Label>
                            </td>
                        </tr>
                        <tr>
                            <td colspan="2" style="background-color:rgb(109, 109, 109); color:White; text-align:right;">
                                <asp:LinkButton ID="CancellaBuonoSconto" CommandName="CancellaBuonoSconto" runat="server" style="color:White;">X Elimina Buono Sconto</asp:LinkButton>                                
                            </td>
                        </tr>
                    </table>
                </ItemTemplate>
            </asp:TemplateField>
        </Columns>
    </asp:GridView>
<hr />

	<div class="container">
		<div class="row my-2">
			<div class="col-12 col-md-8">
				<asp:Label ID="lblArticoli" runat="server" Text="" Font-Bold="true" ForeColor="#E12825"></asp:Label>
				<asp:Label ID="lblPresenti" runat="server" Text=""></asp:Label>
				<br /><br />
				<asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label>

				<asp:Panel ID="Panel_BuoniSconto" runat="server" HorizontalAlign="left" style="padding:5px; border-width:1px; text-align:center; margin-top: 20px;border-top-style: solid;border-bottom-style: solid;overflow:hidden;background-color: #444444;" >
							<div>
							<b style="color:#70db10">CODICE SCONTO</b>
							</div>
							<div>
							<asp:TextBox ID="TB_BuonoSconto" runat="server" style="height:20px; text-align:center; font-weight:bold; width:98%; text-transform:uppercase; padding:1%; padding-left:1%;"></asp:TextBox>            
							</div>
							<div>
							<asp:Image ID="checkOKBuonoSconto" runat="server" ImageUrl="Public/Images/Ok.png" Height="30px" Visible="false" style="position:absolute; right:2px; top:0px;" />
							</div>
							<div>
							<asp:Image ID="checkNOBuonoSconto" runat="server" ImageUrl="Public/Images/Remove.png" Height="30px" Visible="false" style="position:absolute; right:2px; top:0px;"/>
							</div>
							<div>
							<asp:Button ID="BT_ApplicaBuonoSconto" style="border-style: none; margin-top: 3px; background-color: #70db10; color: white;" runat="server" CausesValidation="false" Text="Aggiungi" Height="100%"/>
							</div>
							<div>
							<asp:Label ID="lblBuonoScontoConvalida" runat="server" Text=""></asp:Label>
							</div>
							<div>
							<asp:LinkButton ID="LB_CancelBuonoSconto" runat="server" style="float:right;" Font-Size="8pt" ForeColor="Red" Visible="false">X Cancella Codice Buono</asp:LinkButton>
							</div>
					</asp:Panel>
				
				<br />

				<asp:TextBox ID="tbVettoriId" runat="server" ToolTip="VettoriId" style="display:none" Width="20px"></asp:TextBox>
				<asp:TextBox ID="tbPagamenti" runat="server" ToolTip="PagamentiId" style="display:none" Width="20px"></asp:TextBox>
				<asp:TextBox ID="tbShopIdGestPay" runat="server" ToolTip="tShopIdGestPay" style="display:none" Width="20px"></asp:TextBox>
				<asp:TextBox ID="tbContrPerc" runat="server" ToolTip="Contrassegno Percentuale" style="display:none" Width="20px"></asp:TextBox>
				<asp:TextBox ID="tbContrFisso" runat="server" ToolTip="Contrassegno Fisso" style="display:none" Width="20px"></asp:TextBox>
				<asp:TextBox ID="tbContrMinimo" runat="server" ToolTip="Contrassegno Minimo" style="display:none" Width="20px"></asp:TextBox>
				<asp:TextBox ID="tbPeso" runat="server" Width="20px" style="display:none" ToolTip="Peso"></asp:TextBox>
				<asp:TextBox ID="tbTotale" runat="server" Width="20px" style="display:none" ToolTip="Totale"></asp:TextBox> 

			</div>
			<div class="col-12 col-md-4" style="line-height: 135%;font-size:9pt;">
				<table width="100%" id="TableConteggi" runat="server" visible="false">
					<tr>
						<td align="right" valign="top" style="line-height: 135%;font-size:9pt; width:70%;">
							Imponibile:</td>
						<td align="right" width="30%" valign="top" style="font-size:9pt"><asp:Label ID="lblImponibile" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
					</tr>
					<tr>
						<td align="right" valign="top" style="line-height: 135%;font-size:9pt; width:70%;">
							Spedizione:</td>
						<td align="right" width="30%" valign="top" style="font-size:9pt"><asp:Label ID="lblSpeseSped" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
					</tr>
					<tr>
						<td align="right" valign="top" style="line-height: 135%;font-size:9pt; width:70%;">
							Assicurazione:</td>
						<td align="right" width="30%" valign="top" style="font-size:9pt"><asp:Label ID="lblSpeseAss" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
					</tr>
					<tr>
						<td align="right" valign="top" style="line-height: 135%;font-size:9pt; width:70%;">
							IVA:</td>
						<td align="right" width="30%" valign="top" style="font-size:9pt"><asp:Label ID="lblIva" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
					</tr>
					<tr>
						<td align="right" valign="top" style="line-height: 135%;font-size:9pt; width:70%;">
							Pagamento:</td>
						<td align="right" width="30%" valign="top" style="font-size:9pt"><asp:Label ID="lblPagamento" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
					</tr>
					<tr>
						<td align="right" valign="top" style="line-height: 135%;font-size:9pt; width:70%;">
							Buono Sconto:</td>
						<td align="right" width="30%" valign="top" style="font-size:9pt"><asp:Label ID="lblBuonoSconto" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
					</tr>
					<tr>
						<td align="right" valign="top" style="line-height: 135%;font-size:9pt; width:70%;">
							Buono Sconto IVA:</td>
						<td align="right" width="30%" valign="top" style="font-size:9pt"><asp:Label ID="lblBuonoScontoIVA" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
					</tr>
					<tr>
						<td align="right" valign="top" style="line-height: 135%;font-size:9pt; width:70%;"><b>
							Totale:</b></td>
						<td align="right" width="30%" valign="top" style="font-size:9pt"><asp:Label ID="lblTotale" runat="server" Text="&#8364; 0,00" Font-Bold="true" style="color:rgb(205, 38, 44);"></asp:Label></td>
					</tr>
				</table>
			</div>
		</div>
		<div ID="canorder" runat="server" Style="font-size:12px; color:white; background:red; text-align:center">
			Non sei un utente abilitato a procedere con l'ordine. Contattaci se desideri invece procedere
			</div>
	</div>
	<div class="row">
		<div class="col-12">

			<asp:LinkButton ID="btContinua" runat="server" Style="min-width:130px; font-size:12px; border-radius: unset" ForeColor="White" CssClass="btn btn-default m-1" CausesValidation="false">Continua lo Shopping</asp:LinkButton>

			<asp:LinkButton ID="btAggiorna" runat="server" Style="min-width:130px; font-size:12px; border-radius: unset" ForeColor="White" CssClass="btn btn-default m-1" CausesValidation="false">Aggiorna Carrello</asp:LinkButton>

			<asp:LinkButton ID="btSvuota" runat="server" Style="min-width:130px; font-size:12px; border-radius: unset" ForeColor="White" CssClass="btn btn-default m-1" CausesValidation="false">Svuota Carrello</asp:LinkButton>
		<div style="text-align: right;float: right;">
        <asp:LinkButton ID="btCompleta" runat="server" ForeColor="White" CssClass="btn btn-lg btn-default m-1" Style="min-width:130px; font-size:15px;background-color: #70db10!important; border-radius: unset" CausesValidation="false">Procedi con l'ordine</asp:LinkButton>
		</div>
			
		</div>
	</div>
	<asp:Panel ID="Panel_Unico" runat="server">   
    <table width="100%" border="0" runat="server" id="tOrdine" visible="false">
    <tr>
        <td colspan="2" style=" border-top-style:solid; border-top-width:1px; border-top-color:Gray; padding-top:10px; padding-bottom:10px;">
        </td>
    </tr>
    
    <tr><td style="width: 100%;" colspan="2" valign="top" >
    
    <div id="promo_vettori">
    <asp:Panel ID="pSpedizione" runat="server" Width="100%" Visible="true" style="overflow:hidden;">
        <!--<div id="infobar" style="width:100%; color:White; font-weight:bold; height:50px; background-image:url('Public/Images/StepCarrello1.png'); background-size:100%; background-repeat:no-repeat;"></div>-->		
		<div class="row shopBar">
			<div class="col-12">
				<div style="display: flex;align-items: center;">
					<span class="step-number">1</span>
					<div class="w-100 step-text">
						<span>STEP di <% if Session("LoginId")>0 then %> 5 <% else %> 2 <% end if %></span>
						<span class="ml-5">SPEDIZIONE</span>
					</div>
				</div>
			</div>
		</div>
		
        <asp:GridView ID="gvVettoriPromo" runat="server"
        AutoGenerateColumns="False" CellPadding="1" DataSourceID="sdsVettoriPromo"
        Font-Size="8pt" GridLines="None" Width="100%" DataKeyNames="id" BorderColor="#383838" BorderStyle="Solid" BorderWidth="2px">
            <Columns>
                <asp:TemplateField ShowHeader="False">
                    <ItemTemplate>
                        <asp:RadioButton ID="rbSpedizione" runat="server" AutoPostBack="True" Checked='false'
                            GroupName="spedizione" Value='<%# Eval("Id") %>' />
                    </ItemTemplate>
                    <ItemStyle HorizontalAlign="Left" VerticalAlign="Middle" />
                </asp:TemplateField>
                <asp:TemplateField InsertVisible="False" SortExpression="id" Visible="False" ShowHeader="False">
                    <EditItemTemplate>
                        <asp:Label ID="Label1" runat="server" Text='<%# Eval("id") %>'></asp:Label>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblId" runat="server" Text='<%# Bind("id") %>'></asp:Label>
                    </ItemTemplate>
                    <ItemStyle HorizontalAlign="Left" VerticalAlign="Middle" />
                </asp:TemplateField>
                <asp:TemplateField InsertVisible="False" ShowHeader="False">
                     <ItemTemplate>
                        <img src='<%# "Public/Vettori/" & Eval("Img") %>' title='PROMO fino al <%# Eval("Promo_Data_Fine","{0:d}") %>' alt="" />
                    </ItemTemplate>
                    <ItemStyle HorizontalAlign="Left" VerticalAlign="Middle" />
                </asp:TemplateField>
                <asp:BoundField DataField="Descrizione" SortExpression="Descrizione" ShowHeader="False" >
                    <ItemStyle Width="150px" HorizontalAlign="Center" VerticalAlign="Middle" />
                </asp:BoundField>
                <asp:TemplateField SortExpression="AssicurazionePercentuale" ShowHeader="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox1" runat="server" Text='<%# Bind("AssicurazionePercentuale") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblAssPerc" runat="server" Text='<%# Bind("AssicurazionePercentuale", "{0:F}") %>'
                            Visible="False"></asp:Label>
                    </ItemTemplate>
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" />
                </asp:TemplateField>
                <asp:TemplateField SortExpression="AssicurazioneMinimo" Visible="False" ShowHeader="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox4" runat="server" Text='<%# Bind("AssicurazioneMinimo") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblAssicurazioneMinimo" runat="server" Text='<%# Bind("AssicurazioneMinimo") %>'></asp:Label>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField SortExpression="ContrassegnoPercentuale" Visible="False" ShowHeader="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox2" runat="server" Text='<%# Bind("ContrassegnoPercentuale") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblContrPerc" runat="server" Text='<%# Bind("ContrassegnoPercentuale", "{0:F}") %>'></asp:Label>
                    </ItemTemplate>
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" />
                </asp:TemplateField>
                <asp:TemplateField SortExpression="ContrassegnoFisso" Visible="False" ShowHeader="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox3" runat="server" Text='<%# Bind("ContrassegnoFisso") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblContrFisso" runat="server" Text='<%# Bind("ContrassegnoFisso", "{0:F}") %>'></asp:Label>
                    </ItemTemplate>
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" />
                </asp:TemplateField>
                <asp:TemplateField SortExpression="ContrassegnoMinimo" Visible="False" ShowHeader="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox5" runat="server" Text='<%# Bind("ContrassegnoMinimo") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblContrMinimo" runat="server" Text='<%# Bind("ContrassegnoMinimo") %>'></asp:Label>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:BoundField DataField="PesoMax"
                 SortExpression="PesoMax" DataFormatString="{0:F}" Visible="False" ShowHeader="False">
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" VerticalAlign="Middle" />
                </asp:BoundField>
                <asp:TemplateField HeaderText="Costo">
                    <ItemTemplate>
                    <% If (Me.Session("IvaTipo") = 1) Then%>
                        <asp:Label ID="lblCosto" runat="server" Text='<%# String.Format("{0:c}", Eval("CostoFisso")) %>'></asp:Label>
                    <%Else%>
                        <asp:Label ID="Label10" runat="server" Text='<%# String.Format("{0:c}", (Eval("CostoFisso")*((Session("Iva_Vettori")/100)+1))) %>'></asp:Label>
                    <%End If%>
                    </ItemTemplate>
                    <ItemStyle Width="130px" Wrap="False" Font-Size="7pt" HorizontalAlign="Right" VerticalAlign="Middle" />
                    <HeaderStyle HorizontalAlign="Right" VerticalAlign="Middle" />
                </asp:TemplateField>
                <asp:TemplateField Visible="False">
                    <ItemTemplate>
                        Soglia:<asp:Label ID="lblSogliaMinima" runat="server" Text='<%# Eval("Soglia_Minima") %>'></asp:Label><br />
                        Peso Max:<asp:Label ID="lblPeso" runat="server" Text='<%# Eval("PesoMax") %>'></asp:Label>
<asp:Label ID="lblArrivo" runat="server" Text="0" Visible="False"></asp:Label><br />
                        Percentuale:<asp:Label ID="lblPercentuale" runat="server" Text='<%# Eval("Costo_Percentuale") %>'></asp:Label>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Spesa Minima (IVA incl)">
                    <ItemTemplate>
                        <asp:Label ID="Label2" runat="server" Text='<%# String.Format("{0:c}", Eval("Soglia_Minima")*((Session("Iva_Vettori")/100)+1)) %>'></asp:Label>
                        
                        <script runat="server">
                            Function mancano_ancora(ByVal soglia As Double, ByVal imponibile As Double, ByVal imponibile_gratis As Double) As String
                                If soglia - (imponibile - imponibile_gratis) < 0 Then
                                    Return "** SOGLIA SUPERATA **"
                                Else
                                    Return "Per usufruire della PROMO mancano ancora " & String.Format("{0:c}", ((soglia - (imponibile - imponibile_gratis)) * ((Session("Iva_Vettori") / 100) + 1))) & " - Non vengono conteggiati gli articoli con SPEDIZIONE GRATIS"
                                End If
                            End Function
                            
                            Function mancano_ancora_number(ByVal soglia As Double, ByVal imponibile As Double, ByVal imponibile_gratis As Double) As String
                                If soglia - (imponibile - imponibile_gratis) > 0 Then
                                    differenzaTrasportoGratis = ((soglia - (imponibile - imponibile_gratis)) * ((Session("Iva_Vettori") / 100) + 1))
                                    Return 1
                                Else
                                    Return 0
                                End If
                            End Function
                        </script>
                        
                        <span style="display:none;"><%# mancano_ancora_number(Eval("Soglia_Minima"), imponibile, imponibile_gratis)%></span>
                        <img src="Public/Images/interrogativo.png" alt="" title="<%# mancano_ancora(Eval("Soglia_Minima"),imponibile, imponibile_gratis)%>" />
                    
                    </ItemTemplate>
                    <HeaderStyle HorizontalAlign="Right" VerticalAlign="Middle" Wrap="True" />
                    <ItemStyle HorizontalAlign="Right" VerticalAlign="Middle" Width="130px" Wrap="False" Font-Size="7pt" />
                </asp:TemplateField>
                <asp:BoundField DataField="PesoMax" DataFormatString="{0:0.0} Kg" HeaderText="Peso Massimo">
                    <HeaderStyle HorizontalAlign="Right" VerticalAlign="Middle" />
                    <ItemStyle HorizontalAlign="Right" VerticalAlign="Middle" Width="130px" Wrap="False" Font-Size="7pt" />
                </asp:BoundField>
            </Columns>
            <SelectedRowStyle BackColor="#FFFFC0" />
            <HeaderStyle Font-Bold="False" Font-Size="7pt" HorizontalAlign="Left" ForeColor="#2050AF" Font-Strikeout="False" />
            <AlternatingRowStyle BackColor="WhiteSmoke" BorderStyle="None" />
        </asp:GridView>
        
        <%If differenzaTrasportoGratis > 0 Then%>
            <div style="width:100%; padding-top:2px; padding-bottom:2px; font-size:10px; text-align:center; background-color:#383838; color: white;">
                <%="TRASPORTO GRATUITO se spendi ancora <b>" & String.Format("{0:c}", differenzaTrasportoGratis) & "</b>"%>
            </div>
        <%End If%>    
        
        <br />
            
        <div id="gvVettori_tooltip">
        <asp:GridView ID="gvVettori" runat="server" AutoGenerateColumns="False" CellPadding="1" DataSourceID="sdsVettori" Font-Size="8pt" GridLines="None" Width="100%" DataKeyNames="id" ShowHeader="False">
            <HeaderStyle Font-Bold="False" Font-Size="8pt" HorizontalAlign="Left" ForeColor="#2050AF" />
            <AlternatingRowStyle BackColor="WhiteSmoke" BorderStyle="None" />
            <Columns>
                <asp:TemplateField HeaderText="Seleziona">
                    <ItemTemplate>
                        <asp:RadioButton id="rbSpedizione" runat="server" autopostback="True" checked='false'
                            groupname="spedizione" value='<%# Eval("Id") %>'></asp:RadioButton>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField HeaderText="id" InsertVisible="False" SortExpression="id" Visible="False">
                    <EditItemTemplate>
                        <asp:Label ID="Label1" runat="server" Text='<%# Eval("id") %>'></asp:Label>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblId" runat="server" Text='<%# Bind("id") %>'></asp:Label>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField InsertVisible="False" ShowHeader="False">
                     <ItemTemplate>
                        <img class="ml-2" src='<%# "Public/Vettori/" & Eval("Img") %>' title='<%# Eval("Informazioni") %>' alt="" />
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:BoundField DataField="Descrizione" HeaderText="Descrizione" SortExpression="Descrizione" >
                    <ItemStyle Width="100%" />
                </asp:BoundField>
                <asp:TemplateField HeaderText="Ass.P" SortExpression="AssicurazionePercentuale">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox1" runat="server" Text='<%# Bind("AssicurazionePercentuale") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblAssPerc" runat="server" Text='<%# Bind("AssicurazionePercentuale", "{0:F}") %>'
                            Visible="False"></asp:Label>
                    </ItemTemplate>
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" />
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Ass.M" SortExpression="AssicurazioneMinimo" Visible="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox4" runat="server" Text='<%# Bind("AssicurazioneMinimo") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblAssicurazioneMinimo" runat="server" Text='<%# Bind("AssicurazioneMinimo") %>'></asp:Label>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Con.P" SortExpression="ContrassegnoPercentuale" Visible="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox2" runat="server" Text='<%# Bind("ContrassegnoPercentuale") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblContrPerc" runat="server" Text='<%# Bind("ContrassegnoPercentuale", "{0:F}") %>'></asp:Label>
                    </ItemTemplate>
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" />
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Con.F" SortExpression="ContrassegnoFisso" Visible="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox3" runat="server" Text='<%# Bind("ContrassegnoFisso") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblContrFisso" runat="server" Text='<%# Bind("ContrassegnoFisso", "{0:F}") %>'></asp:Label>
                    </ItemTemplate>
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" />
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Con.M" SortExpression="ContrassegnoMinimo" Visible="False">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox5" runat="server" Text='<%# Bind("ContrassegnoMinimo") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblContrMinimo" runat="server" Text='<%# Bind("ContrassegnoMinimo") %>'></asp:Label>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:BoundField DataField="PesoMax" HeaderText="Peso"
                 SortExpression="PesoMax" DataFormatString="{0:F}" Visible="False">
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" />
                </asp:BoundField>
                <asp:TemplateField HeaderText="Costo" SortExpression="CostoFisso">
                    <EditItemTemplate>
                        <asp:TextBox ID="TextBox6" runat="server" Text='<%# Bind("CostoFisso") %>'></asp:TextBox>
                    </EditItemTemplate>
                    <ItemTemplate>
                    <% If (Me.Session("IvaTipo") = 1) Then%>
                        <asp:Label ID="lblCosto" runat="server" Text='<%# Bind("CostoFisso", "{0:c}") %>'></asp:Label>
                    <%else %>
                        <asp:Label ID="Label9" runat="server" Text='<%# String.Format("{0:c}", Eval("CostoFisso")*((Session("Iva_Vettori")/100)+1)) %>'></asp:Label>
                    <%End If%>
                    </ItemTemplate>
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" Wrap="False" />
                </asp:TemplateField>
            </Columns>
            <SelectedRowStyle BackColor="#FFFFC0" />
        </asp:GridView>
        </div>
        
        <asp:Panel ID="Panel_SpedizioneGratis" runat="server" Height="10px" Visible="False"
            Width="100%" Font-Size="8pt">
            <table>
                <tr>
                    <td style=" text-align:left; vertical-align:middle;">
                      <asp:RadioButton ID="rbSpedizioneGratis" runat="server" AutoPostBack="True" Checked='True'
                      Font-Bold="True" Font-Names="Arial" ForeColor="Red" GroupName="spedizione"
                      Text="" Value='<%# Eval("Id") %>' />
                    </td>
                    <td>
                        <img src="Public/Vettori/free.jpg"  alt=""/>
                    </td>
                    <td style="color:Red; font-weight:bold;">
                        Spedizione Gratis
                    </td>
                </tr>
            </table>        
        </asp:Panel>
        <br />
    </asp:Panel>   
    </div>
        <asp:SqlDataSource ID="sdsVettori" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT vvettoricosti.Ordinamento, vvettoricosti.Informazioni, vvettoricosti.Descrizione, vvettoricosti.id, vvettoricosti.Abilitato, vvettoricosti.Web, vvettoricosti.Predefinito, vvettoricosti.AssicurazionePercentuale, vvettoricosti.AssicurazioneMinimo, vvettoricosti.ContrassegnoPercentuale, vvettoricosti.ContrassegnoFisso, vvettoricosti.ContrassegnoMinimo, vvettoricosti.Img, MIN(vvettoricosti.PesoMax) AS PesoMax, MIN(vvettoricosti.CostoFisso) AS CostoFisso FROM vvettoricosti INNER JOIN vettoricosti ON vvettoricosti.id = vettoricosti.VettoriId WHERE (vvettoricosti.Abilitato = 1) AND (vvettoricosti.Web = 1) AND (vvettoricosti.PesoMax >= @Peso) AND (vvettoricosti.AziendeId = @AziendaId) AND (vettoricosti.Soglia_Minima <= 0) GROUP BY vvettoricosti.Ordinamento, vvettoricosti.Descrizione, vvettoricosti.id, vvettoricosti.Abilitato, vvettoricosti.Web, vvettoricosti.Predefinito, vvettoricosti.AssicurazionePercentuale, vvettoricosti.ContrassegnoPercentuale, vvettoricosti.ContrassegnoFisso HAVING (vvettoricosti.id >= 0)">
            <SelectParameters>
                <asp:ControlParameter ControlID="tbPeso" Name="Peso" PropertyName="Text" Type="Decimal" />
                <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" Type="Int32" />
            </SelectParameters>
        </asp:SqlDataSource>
        <asp:SqlDataSource ID="sdsVettoriPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT vettori.id, vettori.Descrizione, vettori.Informazioni, vettori.Ordinamento, vettori.Predefinito, vettori.AssicurazionePercentuale, vettori.AssicurazioneMinimo, vettori.ContrassegnoPercentuale, vettori.ContrassegnoFisso, vettori.ContrassegnoMinimo, vettori.Promo_Data_Fine, vettori.Promo_Data_Inizio, vettori.Img, vettoricosti.CostoFisso, vettoricosti.Costo_Percentuale, vettoricosti.Soglia_Minima, vettoricosti.PesoMax FROM vettoricosti INNER JOIN vettori ON vettoricosti.VettoriId = vettori.id WHERE (vettori.Abilitato = 1) AND (vettori.Web = 1) AND (vettori.AziendeId = @AziendaId) AND (vettori.Promo = 1) AND (vettori.Promo_Data_Inizio <= CURDATE()) AND (vettori.Promo_Data_Fine >= CURDATE()) AND (vettori.Listini_Abilitati LIKE CONCAT('%', @Param1, ';%')) GROUP BY vettori.id, vettori.Descrizione, vettori.Informazioni, vettori.Ordinamento, vettori.Predefinito, vettori.AssicurazionePercentuale, vettori.AssicurazioneMinimo, vettori.ContrassegnoPercentuale, vettori.ContrassegnoFisso, vettori.ContrassegnoMinimo, vettori.Img, vettoricosti.CostoFisso, vettoricosti.Costo_Percentuale, vettoricosti.PesoMax, vettoricosti.Soglia_Minima, vettori.Listini_Abilitati, vettori.Promo_Data_Inizio, vettori.Promo_Data_Fine HAVING (vettori.id >= 0) ORDER BY vettoricosti.Soglia_Minima">
            <SelectParameters>
                <asp:SessionParameter Name="Param1" SessionField="Listino" />
                <asp:SessionParameter Name="AziendaId" SessionField="AziendaId" />
            </SelectParameters>
        </asp:SqlDataSource>
       
    </td>
    </tr>

    <tr>
        <td colspan="2">
			<div class="row shopBar">
				<div class="col-12">
					<div style="display: flex;align-items: center;">
						<span class="step-number">2</span>
						<div class="w-100 step-text">
							<span>STEP di <% if Session("LoginId")>0 then %> 5 <% else %> 2 <% end if %></span>
							<span class="ml-5">ASSICURAZIONE E PAGAMENTO</span>
						</div>
					</div>
				</div>
			</div>
        </td>
    </tr>
    
    <tr style="border-bottom:">
		<td>
		<div class="row">
			<div class="col-12 col-md-6">
				<asp:Panel ID="pAssicurazione" runat="server" Width="100%"  Visible="true" style="overflow:hidden; margin-bottom: 15px" >
					<table cellpadding="1" width="100%">
						<tr>
							<td><asp:CheckBox ID="cbAssicurazione" runat="server" AutoPostBack="True" /></td>
							<td width="100%"><span class="ml-2">Assicurazione merce (escluso IVA)</span></td>
							<td align="right" nowrap><asp:Label ID="lblAssicurazione" runat="server" Text="&#8364; 0,00" Font-Size="8pt"></asp:Label></td>
						</tr>
					</table>
				</asp:Panel>   
			</div>
			<div class="col-12 col-md-6">
			  <asp:Panel ID="pPagamento" runat="server" Width="99.5%" Visible="true">
					<asp:SqlDataSource ID="sdsPagamento" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
						ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
						SelectCommand="SELECT * FROM vpagamentitipo WHERE Abilitato=1 AND CostoMassimo >= ?CostoMassimo AND (Web=1 OR UtenteID=?UtenteID) AND AziendeID=?AziendaID GROUP BY id ORDER BY Ordinamento, Descrizione">
					   <SelectParameters>
						   <asp:ControlParameter ControlID="tbTotale" Name="CostoMassimo" PropertyName="Text" />
						   <asp:SessionParameter Name="UtenteID" SessionField="UtentiID" />
						   <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" />
						</SelectParameters>    
					</asp:SqlDataSource>
					
					<div id="gvPagamento_tooltip">
					<asp:GridView ID="gvPagamento" runat="server"
					AutoGenerateColumns="False" CellPadding="1" DataSourceID="sdsPagamento"
					Font-Size="8pt" GridLines="None" Width="100%" ShowHeader="False" DataKeyNames="id">
						<Columns>
							<asp:TemplateField HeaderText="sel">
								<ItemTemplate>
									<asp:RadioButton id="rbPagamento" runat="server" checked='<%# Eval("Predefinito") %>'
										groupname="pagamento" value='<%# eval("id") %>' AutoPostBack="True"></asp:RadioButton>
								</ItemTemplate>
							</asp:TemplateField>
							<asp:TemplateField>
							<ItemTemplate>
								<img class="ml-2" src='<%# "Public/Pagamenti/" & Eval("Img") %>' title='<%# Eval("Informazioni") %>' alt="" />
							</ItemTemplate>
							</asp:TemplateField>
							<asp:TemplateField HeaderText="id" InsertVisible="False" SortExpression="id" Visible="False">
								<EditItemTemplate>
									<asp:Label ID="Label1" runat="server" Text='<%# Eval("id") %>'></asp:Label>
								</EditItemTemplate>
								<ItemTemplate>
									<asp:Label ID="lblId" runat="server" Text='<%# Bind("id") %>'></asp:Label>
								</ItemTemplate>
							</asp:TemplateField>
							<asp:BoundField DataField="Descrizione" HeaderText="Descrizione" SortExpression="Descrizione" >
								<ItemStyle Width="100%" />
							</asp:BoundField>
							<asp:BoundField DataField="Predefinito" HeaderText="Predefinito" SortExpression="Predefinito"
								Visible="False" />
							<asp:TemplateField HeaderText="CostoP" SortExpression="CostoPercentuale">
								<EditItemTemplate>
									<asp:TextBox ID="TextBox1" runat="server" Text='<%# Bind("CostoPercentuale") %>'></asp:TextBox>
								</EditItemTemplate>
								<ItemTemplate>
									<asp:Label ID="lblCostoP" runat="server" Text='<%# Bind("CostoPercentuale", "{0:F}") %>'
										Visible="False"></asp:Label>
								</ItemTemplate>
								<ItemStyle HorizontalAlign="Right" />
							</asp:TemplateField>
							<asp:TemplateField HeaderText="CostoF" SortExpression="CostoFisso">
								<EditItemTemplate>
									<asp:TextBox ID="TextBox2" runat="server" Text='<%# Bind("CostoFisso") %>'></asp:TextBox>
								</EditItemTemplate>
								<ItemTemplate>
									<asp:Label ID="lblCostoF" runat="server" Text='<%# Bind("CostoFisso", "{0:F}") %>'
										Visible="False"></asp:Label>
								</ItemTemplate>
								<ItemStyle HorizontalAlign="Right" />
							</asp:TemplateField>
							<asp:TemplateField HeaderText="Contrassegno" SortExpression="Contrassegno" Visible="False">
								<EditItemTemplate>
									<asp:TextBox ID="TextBox3" runat="server" Text='<%# Bind("Contrassegno") %>'></asp:TextBox>
								</EditItemTemplate>
								<ItemTemplate>
									<asp:Label ID="lblContrassegno" runat="server" Text='<%# Bind("Contrassegno") %>'></asp:Label>
								</ItemTemplate>
							</asp:TemplateField>
							<asp:TemplateField HeaderText="ShopLogin" SortExpression="ShopLogin" Visible="False">
								<EditItemTemplate>
									<asp:TextBox ID="TextBox3" runat="server" Text='<%# Bind("ShopLogin") %>'></asp:TextBox>
								</EditItemTemplate>
								<ItemTemplate>
									<asp:Label ID="lblShopLogin" runat="server" Text='<%# Bind("ShopLogin") %>'></asp:Label>
								</ItemTemplate>
							</asp:TemplateField>
							<asp:TemplateField HeaderText="Costo">
								<ItemTemplate>
									<asp:Label ID="lblCosto" runat="server" Text='&#8364; 0,00'></asp:Label>
								</ItemTemplate>
								<ItemStyle HorizontalAlign="Right" Wrap="False" />
							</asp:TemplateField>
						</Columns>
						<SelectedRowStyle BackColor="#FFFFC0" />
						<HeaderStyle Font-Bold="False" Font-Size="8pt" HorizontalAlign="Left" ForeColor="#2050AF" />
						<AlternatingRowStyle BackColor="WhiteSmoke" BorderStyle="None" />
					</asp:GridView>
					</div>
				</asp:Panel>   
				<br />
			</div>
			<!--<td>&nbsp;</td>-->
		</div>
		</td>
	</tr>
    
    <tr>
    
    <td colspan="2">
    <asp:Panel ID="PnlFatturazione" runat="server" Width="100%" Visible="true" style="overflow:hidden;" >
		<div class="row shopBar">
			<div class="col-12">
				<div style="display: flex;align-items: center;">			
					<span class="step-number">3</span>
					<div class="w-100 step-text">
						<span>STEP di 5</span>
						<span class="ml-5">DATI FATTURAZIONE</span>
					</div>
				</div>
			</div>
		</div>
        <table cellspacing="5" border="0" style="border-bottom-style:solid;" width="100%">
            
            <tr>
				<td style="text-align:left;" class="carrello-td1-step4"><b>Ragione Sociale / Cognome:&nbsp;</b></td>
				<td style="text-align:left;" class="carrello-td2-step4"><asp:Label runat="server" ID="lblTab_RagioneSociale"></asp:Label></td>
            </tr>
			<tr>
				<td style="text-align:left;"><b>Nome:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_Nome"></asp:Label></td>
            </tr>  
            <tr>
				<td style="text-align:left;"><b>P.IVA:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_pIva"></asp:Label></td>
            </tr> 
			<tr>
				<td style="text-align:left;"><b>Codice fiscale:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_CF"></asp:Label></td>
            </tr> 
            <tr>
				<td style="text-align:left;"><b>Indirizzo:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_Indirizzo"></asp:Label></td>
			</tr>
			<tr>
				<td style="text-align:left;"><b>Città:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_Citta"></asp:Label></td>
            </tr>
            <tr>
				<td style="text-align:left;"><b>Provincia:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_Provincia"></asp:Label></td>
			</tr>
			<tr>
				<td style="text-align:left;"><b>CAP&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_Cap"></asp:Label></td>
			</tr>
            <tr>
				<td style="text-align:left;"><b>Telefono:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_Tel"></asp:Label></td>
			</tr>
            <tr>
				<td style="text-align:left;"><b>Cellulare:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_Cell"></asp:Label></td>
            </tr> 
            <tr>
				<td style="text-align:left;"><b>Fax:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_Fax"></asp:Label></td>
			</tr>
            <tr>
				<td style="text-align:left;"><b>E-mail:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_mail"></asp:Label></td>
            </tr>
            <tr>
				<td>&nbsp;</td>
			</tr>
            <tr>
				<td colspan="2"><a href="registrazione.aspx">I tuoi dati sono errati? Clicca Qui per modificarli</a></td>
			</tr>
			
        </table>
        </asp:Panel>
    </td>
    </tr>
	
	    <tr>
    
    <td colspan="2">
    <asp:Panel ID="PnlSpedizione" runat="server" Width="100%" Visible="true" style="overflow:hidden;" >
		<div class="row shopBar">
			<div class="col-12">
				<div style="display: flex;align-items: center;">
					<span class="step-number">4</span>
					<div class="w-100 step-text">
						<span>STEP di 5</span>
						<span class="ml-5">INDIRIZZO DI SPEDIZIONE</span>
					</div>
				</div>
			</div>
		</div>
        <table cellspacing="5" border="0" style="border-bottom-style:solid;" width="100%">
		<% If LstScegliIndirizzo.items.count > 0 Then %>
            <tr>
                <td style="text-align:left;" class="carrello-td1-step4"><b>Indirizzi registrati:</td>
				<td style="text-align:left;" class="carrello-td2-step4"><asp:DropDownList runat="server" ID="LstScegliIndirizzo" AutoPostBack="True" Style="width: 99%;"></asp:DropDownList></td>
            </tr>
		<% end if %>
            <tr>
                <td style="text-align:left;"><b>Ragione Sociale / Cognome:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_RagioneSocialeSpedizione"></asp:Label></td>
            </tr>
			<tr>
                <td style="text-align:left;"><b>Nome:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_NomeSpedizione"></asp:Label></td>
            </tr>  
            <tr>
                <td style="text-align:left;"><b>Indirizzo:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_IndirizzoSpedizione"></asp:Label></td>
			</tr>
			<tr>
                <td style="text-align:left;"><b>Città:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_CittaSpedizione"></asp:Label></td>
            </tr>
            <tr>
                <td style="text-align:left;"><b>Provincia:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_ProvinciaSpedizione"></asp:Label></td>
			</tr>
			<tr>
                <td style="text-align:left;"><b>CAP:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_CapSpedizione"></asp:Label></td>
			</tr>
            <tr>
                <td style="text-align:left;"><b>Zona:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_ZonaSpedizione"></asp:Label></td>
			</tr>
			<tr>
                <td style="text-align:left;"><b>Telefono:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_TelSpedizione"></asp:Label></td>
			</tr>
			<tr>
                <td style="text-align:left;"><b>Nota destinazione:&nbsp;</b></td>
				<td style="text-align:left;"><asp:Label runat="server" ID="lblTab_NotaDestinazione"></asp:Label></td>
			</tr>
            <tr>
				<td>&nbsp;</td>
			</tr>
            <tr>
				<td colspan="2"><a id="open1" runat="server" href="#">Desideri modificare l'indirizzo selezionato? Clicca Qui</a></td>
			</tr>
			<tr>
				<td colspan="2"><a id="open2" runat="server" href="#">Desideri inserire un nuovo indirizzo di spedizione? Clicca Qui</a></td>
			</tr>
        </table>
        </asp:Panel>
    </td>
    </tr>
 
    <tr>
        <td colspan="2">
		<div id="panel" runat="server">
            <asp:Panel ID="PnlDestinazione" runat="server" Width="100%" Visible="True" GroupingText="Inserisci i dati" >
				<input type="hidden" runat="server" id="insOmod">
				<!--
                <asp:Label ID="LblDescrDest" runat="server" Text=""></asp:Label>
                <br />
				<% If LstScegliIndirizzo.items.count > 0 Then %>
                Indirizzi esistenti (seleziona in caso di modifica):<br />
                <asp:DropDownList runat="server" ID="LstDestinazione" AutoPostBack="True" Style="width:100%"></asp:DropDownList>
                <br />
				<% end if %>
                <br />
				-->
                 <table id="tblDestAlter" bgcolor="whitesmoke" cellpadding="1" cellspacing="5" border="0" width="100%" runat="server" style="margin:auto;">
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Ragione Sociale&nbsp;/&nbsp;Cognome: *</td>
                        <td ><asp:TextBox ID="tbRagioneSocialeA" runat="server" Width="100%" MaxLength="100" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                            <asp:requiredfieldvalidator id="RFRagioneSocialeA" runat="server" Display="None" ControlToValidate="tbRagioneSocialeA"
		                       ErrorMessage="Campo Obbligatorio (Ragione Sociale)"></asp:requiredfieldvalidator>
		                </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Nome:</td>
                        <td ><asp:TextBox ID="tbNomeA" runat="server" Width="100%" MaxLength="50" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                        </td>
                    </tr>        
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Indirizzo: *</td>
                        <td ><asp:TextBox ID="tbIndirizzo2" runat="server" Width="100%" MaxLength="100" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                            <asp:requiredfieldvalidator id="RFIndirizzo2" runat="server" Display="None" ControlToValidate="tbIndirizzo2"
		                       ErrorMessage="Campo Obbligatorio (Indirizzo)"></asp:requiredfieldvalidator>
                        </td>
                    </tr>
					<tr>
                        <td style="padding: 0 5px;" width="155px">Cap *</td>
                        <td ><asp:TextBox ID="tbCap2" runat="server" AutoPostBack="true" OnTextChanged="City_Bind_Data2" Width="100%" MaxLength="5" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
							 <asp:requiredfieldvalidator id="RFCap2" runat="server" Display="None" ControlToValidate="tbCap2"
		                       ErrorMessage="Campo Obbligatorio (CAP)"></asp:requiredfieldvalidator>
                        </td>
                    </tr>     
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Città: *</td>
                        <td ><asp:DropDownList ID="ddlCitta2" onSelectedIndexChanged="Province_Bind_Data2" AutoPostBack="true" runat="server" Width="100%" ValidationGroup="registrazione" CausesValidation="True"></asp:DropDownList>
                             <asp:requiredfieldvalidator id="RFCitta2" runat="server" Display="None" ControlToValidate="ddlCitta2"
		                       ErrorMessage="Campo Obbligatorio (Città)"></asp:requiredfieldvalidator>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Provincia: *</td>
                        <td ><asp:TextBox ID="tbProvincia2" ReadOnly="true" runat="server" Width="100%" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                             <asp:requiredfieldvalidator id="RFProvincia2" runat="server" Display="None" ControlToValidate="tbProvincia2"
		                       ErrorMessage="Campo Obbligatorio (Provincia)"></asp:requiredfieldvalidator>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Zona:</td>
                        <td ><asp:TextBox ID="tbZona" runat="server" Width="100%" MaxLength="100" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Telefono: *</td>
                        <td ><asp:TextBox ID="tbTelefono2" runat="server" Width="100%" MaxLength="100" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                            <asp:requiredfieldvalidator id="RFTelefono2" runat="server" Display="None" ControlToValidate="tbTelefono2"
		                       ErrorMessage="Campo Obbligatorio (Telefono)"></asp:requiredfieldvalidator>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px" valign="top">Nota destinazione:</td>
                        <td ><asp:TextBox ID="tbNote" runat="server" Width="100%" MaxLength="255" ValidationGroup="registrazione" CausesValidation="True" TextMode="MultiLine" Rows="5"></asp:TextBox>
                        </td>
                    </tr>  
                    <tr>
						<td colspan="2"><asp:CheckBox runat="server" ID="CHKPREDEFINITO" Text="Indirizzo predefinito" Checked="false" /><br />
						</td>
					</tr> 
                    <tr>
                        <td align="center" colspan="2">
                            <asp:Button ID="btnSalvaDest" runat="server" Text="Inserisci nuova destinazione" Height="25px" CausesValidation="true" />
                            <asp:Button ID="btnModDest" runat="server" Text="Salva modifiche destinazione" Height="25px" CausesValidation="true" />
                            <asp:Button ID="btnElimDest" runat="server" Text="Elimina destinazione" Height="25px" CausesValidation="true" BackColor="#CC0000" ForeColor="White"/>
                            <br /><br /><asp:Button ID="btnAnnullaDest" runat="server" Text="Annulla" Height="25px" CausesValidation="false" />
                        </td>
                    </tr>
                </table>
            </asp:Panel>
			</div>
        </td>
        
    </tr>
	
    <tr>
		<td colspan="2">
		<asp:Panel ID="Panel_Note" runat="server" Width="100%" Visible="False">
			<div class="row shopBar">
				<div class="col-12">
					<div style="display: flex;align-items: center;">
						<span class="step-number">5</span>
						<div class="w-100 step-text">
							<span>STEP di 5</span>
							<span class="ml-5">NOTE</span>
						</div>
					</div>
				</div>
			</div>
			
				<br/><asp:TextBox ID="txtNoteSpedizione" TextMode="MultiLine" Rows="5" runat="server" Width="100%"></asp:TextBox>
			</asp:Panel>
		</td>
	</tr>
    <tr><td colspan="3"><br/><hr size="1"/></td></tr>
    
     <tr><td colspan="3" align="center">
   <table style="text-align:center;" width="100%">
   <tr>
        <td style=" border-bottom-style:solid; border-bottom-width:1px; border-bottom-color:Gray; padding-bottom:10px;">
			<asp:LinkButton Visible="False" CausesValidation="false" ID="btSalvaPreventivo" runat="server" ForeColor="White" OnClientClick="javascript:visualizza_spinner_caricamento();"><div id="infobar" style="width:30%; background-color:#70db10; text-align:center; padding:5px; padding:5px; color:White; font-weight:bold; font-size:12pt; float:left;">SALVA PREVENTIVO</div></asp:LinkButton>
            <%if Session("DESTINAZIONEALTERNATIVA")=0 then %>
				<asp:LinkButton CausesValidation="false" ID="btInviaOrdine" runat="server" ForeColor="White" OnClientClick="javascript:visualizza_spinner_caricamento();"><div id="confermaOrdinde" style="background-color:#70db10; text-align:center; padding:5px; padding:5px; color:White; font-weight:bold; font-size:12pt; float:right;">CONFERMA ORDINE</div></asp:LinkButton>
			<%else%>
				<div id="confermaOrdinde" style="max-width: 200px; background-color:lightgray; text-align:center; padding:5px; padding:5px; color:White; font-weight:bold; font-size:12pt; float:right;">CONFERMA ORDINE</div>
			<%end if%> 
        </td>
   </tr>
   <tr>
        <td style="text-align:center;">
            <div id="spinner_caricamento" style=" text-align:center; display:none; padding-top:5px; padding-bottom:5px;">
                <div><b>ATTENDERE L'INVIO AI NOSTRI SERVER</b></div><br />
                <img src="Public/Images/spinner.gif" alt="" />
            </div>
        </td>
   </tr>
   </table>
   
   </td></tr>
   </table>   
      <script type="text/javascript">
        function visualizza_spinner_caricamento(){
            document.getElementById('spinner_caricamento').style.display = "";
            document.getElementById('ctl00_cph_btInviaOrdine').style.display="none";
			document.getElementById('ctl00_cph_btSalvaPreventivo').style.display="none";
        }
      </script>
	 
</asp:Panel> 
<asp:validationsummary id="ValidationSummary1" runat="server" HeaderText="Attenzione!" ShowMessageBox="True" ShowSummary="False"></asp:validationsummary>
		                
    <!--<script type="text/javascript" language="Javascript" src="Public/script/slide.js"> </script> -->
	<script type="text/javascript">
		
		function fnJqueryReady(){
			//Tooltip
			//$("#promo_vettori img[title]").tooltip({position: "center right"});
			//$("#gvVettori_tooltip img[title]").tooltip({position: "center right"});
			//$("#gvPagamento_tooltip img[title]").tooltip({position: "center right"});
		
			// Expand Panel
			$("#cph_open1").click(function(e){
				e.preventDefault();
				$("#cph_panel").slideDown("slow");
				$("#cph_open1").toggle();
				$("#cph_open2").toggle();
				$("#confermaOrdinde").css('background-color', 'lightgray');
				$("#cph_btInviaOrdine").removeAttr('href');
				$("#cph_btInviaOrdine").removeAttr('onclick');
				$("#cph_btnModDest").show();
				$("#cph_btnElimDest").hide();
				$("#cph_btnSalvaDest").hide();
				$("#cph_insOmod").val("mod");
			});	
			
			// Expand Panel
			$("#cph_open2").click(function(e){
				e.preventDefault();
				$("#cph_panel").slideDown("slow");
				$("#cph_open1").toggle();
				$("#cph_open2").toggle();
				$("#confermaOrdinde").css('background-color', 'lightgray');
				$("#cph_btInviaOrdine").removeAttr('href');
				$("#cph_btInviaOrdine").removeAttr('onclick');
				$("#cph_btnModDest").hide();
				$("#cph_btnElimDest").hide();
				$("#cph_btnSalvaDest").show();
				$("#cph_tbRagioneSocialeA").val("");
				$("#cph_tbIndirizzo2").val("");
				$("#cph_tbCap2").val("");
				$("#cph_ddlCitta2 option").remove("");
				$("#cph_tbProvincia2").val("");
				$("#cph_tbZona").val("");
				$("#cph_tbTelefono2").val("");
				$("#cph_tbNote").val("");
				$("#cph_CHKPREDEFINITO").prop("checked", 1);
				$("#cph_insOmod").val("ins");
			});	
			
			// Collapse Panel
			$("#close").click(function(){
				$("#cph_panel").slideUp("slow");	
				$("#cph_open1").toggle();
				$("#cph_open2").toggle();
			});		
		}
		
		defer(fnJqueryReady)

  

	</script>
    <br />
    <br />
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


</asp:Content>
