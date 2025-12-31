<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="documentidettaglio.aspx.vb" Inherits="documentidettaglio" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">

<script src="https://ecomm.sella.it/pagam/JavaScript/js_GestPay.js" type="text/javascript"></script>

<h1>Dettaglio documento</h1>
    <asp:SqlDataSource ID="sdsTestata" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM vdocumenti LEFT JOIN vettori ON vdocumenti.`VettoriId`=vettori.`id` WHERE ((vdocumenti.Id = ?Id) AND (vdocumenti.UtentiId = ?UtentiId))">
        <SelectParameters>
            <asp:QueryStringParameter Name="Id" Type="Int64" QueryStringField="id"/>
            <asp:SessionParameter Name="UtentiId" SessionField="UtentiID" Type="int32" />
        </SelectParameters>
    </asp:SqlDataSource>
    
    <br />
    
    <asp:FormView ID="FormView1" runat="server" DataSourceID="sdsTestata" Width="100%" >
        <ItemTemplate>
            <table style="width:100%; border-width:1px; border-style:solid; border-color:Black;">
                <tr>
                    <td colspan="2" style="background-color:#dadada; vertical-align:middle; height:40px; font-weight:bold; font-size:16pt; padding-left:5px; color:Gray;">
                        <%#Eval("TipoDocumentiDescrizione") & " n° " & "<b style=""font-weigth:bold; color:red;"">" & Eval("NDocumento") & "</b>" & " del " & Eval("DataDocumento", "{0:d}")%>
                    </td>
                </tr>
				<tr>
                    <td colspan="2">
						<div <%# iif (Eval("StatiDescrizione1")="Annullato","","style=""display:none""") %> >
							<table style="width:100%">
								<tr>
									<td style="background-color:#dadada;">
										<b>Stato:</b>
									</td>
									<td>
										<asp:Label ID="LabelStato" runat="server" Font-Bold="True" ForeColor="#E12825" Text='<%# Eval("StatiDescrizione1") %>'></asp:Label> - <asp:Label ID="LabelStato2" runat="server" Text='<%# Eval("StatiDescrizione2") %>'></asp:Label><br />
									</td>
								</tr>
							</table>
						</div>
						<div <%# iif (Eval("StatiDescrizione1")="Annullato","style=""display:none""","") %> >
							<table style="width:100%">
							<tr>
								<td style="background-color:#dadada;">
									<b>Stato:</b>
								</td>
								<td>
									<asp:Label ID="Label6" runat="server" Font-Bold="True" ForeColor="#E12825" Text='<%# Eval("StatiDescrizione1") %>'></asp:Label> - <asp:Label ID="Label8" runat="server" Text='<%# Eval("StatiDescrizione2") %>'></asp:Label><br />
								</td>
							</tr>
							<tr>
								<td style="background-color:#dadada;">
									<b>Spedizione:</b>        
								</td>
								<td>
									<asp:Label ID="Label5" runat="server" Font-Bold="True" ForeColor="#E12825" Text='<%# Eval("VettoriDescrizione") %>'></asp:Label> - <asp:Label ID="Label9" runat="server"  Text='<%# Eval("VettoriInformazioni") %>'></asp:Label><br />
								</td>
							</tr>
							<tr>
								<td style="background-color:#dadada;">
									<b>Pagamento:</b>
								</td>
								<td>
									<asp:Label ID="Label4" runat="server" Font-Bold="True" ForeColor="#E12825" Text='<%# Eval("PagamentiTipoDescrizione") %>'></asp:Label> - <asp:Label ID="Label10" runat="server"  Text='<%# Eval("PagamentiTipoInformazioni") %>'></asp:Label>        
								</td>
							</tr>
							<tr>
								<td style="background-color:#dadada;">
									<b>Tracking:</b>
								</td>
								<td style="vertical-align:center;">
									<script runat="server">
										Function separa_tracking(ByVal tracking As String, ByVal link_tracking As String) As String
											Dim temp As String() = tracking.Split(";")
											Dim risultato As String = ""
											Dim i As Integer = 0
											
											For i = 0 To temp.Length - 1
												If temp(i) <> "" Then
													risultato = risultato & "<img src=""Public/Images/interrogativo.png"" alt="""" title=""Clicca sul Numero Tracking"">" & "<a href=""" & link_tracking.Replace("#ID#", temp(i)) & """ target=""_blank"">" & temp(i) & "</a>; "
												End If
											Next
											
											Return risultato
										End Function
									</script>
									<%# separa_tracking(Eval("Tracking").ToString(), Eval("Link_Tracking").ToString())%>
								</td>
							</tr>
							<tr>
								<td colspan="2" style="background-color:#dadada; text-align:center;">
									<asp:TextBox ID="tbTipo" runat="server" Visible="false" Text='<%# Eval("TipoDocumentiId") %>' width="10"></asp:TextBox>
									<asp:TextBox ID="tbOnline" runat="server" Visible="false" Text='<%# Eval("PagamentiTipoOnline") %>' width="10"></asp:TextBox>
									<asp:TextBox ID="tbPagato" runat="server" Visible="false" Text='<%# Eval("Pagato") %>' width="10"></asp:TextBox>
									<br />
									<img src="Public/Images/pagato.gif" style="display:<%# iif(Eval("CodiceAutorizzazione")<>"","","none")  %>;" />
									
									<!-- Pagamento Tramite Banca Sella -->
									<div id="bsButton">
									<asp:ImageButton ID="btBancaSella" runat="server" Visible="false" CommandName="PagamentoBancaSella" CommandArgument='<%# Eval("ShopLogin") %>' codiceAutorizzazione='<%# Eval("CodiceAutorizzazione")%>' idDocumento='<%# Eval("id") %>' nDocumento='<%# Eval("NDocumento") %>' totaleDocumento='<%# Eval("TotaleDocumento") %>' text="PAGA ADESSO" ToolTip="Paga Adesso" ImageUrl="public/images/paga_adesso.gif" style="margin:auto; width:100%;" />
									</div>
									<!-- Pagamento Tramite iwBank -->
									<asp:ImageButton ID="btIwBank" runat="server" Visible="false" Text="PAGA ADESSO" PostBackUrl='<%# "https://checkout.iwsmile.it/Pagamenti/?ACCOUNT=" & me.session("AccountIwBank") & "&ITEM_NAME=Ordine+n.+"& Eval("NDocumento") &"+del+"& Eval("DataDocumento") &"&ITEM_NUMBER="& Eval("NDocumento") &"&QUANTITY=1&FLAG_ONLY_IWS=0&AMOUNT="& replace(replace(Eval("TotaleDocumento","{0:N}"),".",""),",",".") &"&NOTE=0&URL_OK=http://"& Request.Url.Host  &"/pagamento.aspx?id="& Eval("id") &"&URL_BAD=http://"& Request.Url.Host &"/documentidettaglio.aspx?id="& Eval("id") &""  %>' ToolTip="Paga con IwBank" ImageUrl="public/images/paga_adesso.gif" style="margin:auto; width:100%;" />
									<!-- Pagamento Tramite Paypal -->
									<asp:Button ID="btPayPal" runat="server" visible="false" Text="PAGA ADESSO" Width="100" Font-Bold="true" CommandName="PagamentoPayPal" idDocumento='<%# Eval("id") %>' nDocumento='<%# Eval("NDocumento") %>' totaleDocumento='<%# replace(replace(Eval("TotaleDocumento","{0:N}"),".",""),",",".") %>' dataDocumento='<%# Eval("DataDocumento") %> ' ToolTip="Paga con PayPal"/>         
									
								</td>
							</tr>
							</table>
						</div>
					</td>
                </tr>
            </table>
        </ItemTemplate>
        <RowStyle Font-Size="8pt" />
    </asp:FormView>
        
    <asp:GridView ID="GridView2" runat="server" AutoGenerateColumns="False"
        CellPadding="3" DataKeyNames="id" DataSourceID="sdsRigheSpedizioneGratis" EmptyDataText="" Font-Bold="false"
        Font-Size="8pt" GridLines="None" PageSize="15" Width="100%" BorderColor="Red" BorderWidth="2px">
        <EmptyDataRowStyle Font-Bold="False" Height="50px" HorizontalAlign="Center" />
        <Columns>
            <asp:TemplateField>
                <ItemTemplate>
                    <div class="row m-0" style="font-size:8pt; text-align:left; border-color:Gray; border-collapse:collapse; border-width:1px; border-style:solid;">
                        <!-- Foto -->
						
                        <div class="col-4" style="float:left; vertical-align:middle;">
                            <table style="width:100%; height:100%;">
                                <tr>
                                    <td style="width:100%; height:100%; vertical-align:middle; overflow:hidden;">
                                        <div style="width:100px; overflow:hidden;">
                                            <asp:HyperLink ID="HyperLink3" idarticolo='<%# Eval("ArticoliId") %>' runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") & "&TCId=" & Eval("TCId") %>' ><asp:Image ID="Image_Articolo" runat="server" Width="80"  AlternateText='<%# Eval("Descrizione1") %>' ImageUrl='<%# Eval("img1", "~/Public/foto/_{0}") %>' /></asp:HyperLink>
                                        </div>
                                    </td>
                                </tr>
                            </table>
                        </div>
                        <script runat="server">
                            Function adatta_testo(ByVal stringa As String, ByVal lunghezza As Integer) As String
                                If stringa.Length > lunghezza Then
                                    Return Left(stringa, lunghezza) & " ..."
                                Else
                                    Return stringa
                                End If
                            End Function
                        </script>
                        <!-- Info prodotto -->
                        <div class="col-8" style=" vertical-align:middle;">
                            <table style="width:100%; height:100%;">
                                <!-- Titolo Prodotto -->
                                <tr>
                                    <td style="width:100%; height:25%; font-size:10pt; font-weight:bold; vertical-align:top; overflow:hidden;">
                                        <asp:HyperLink ID="HyperLink5" style="cursor:hand" ToolTip='<%# Eval("Descrizione1") %>' runat="server" NavigateUrl='<%# iif(Eval("articoliid")>0,"~/articolo.aspx?id=" & Eval("articoliid") & "&TCId=" & Eval("TCId"),"#") %>' ><br />
                                            <asp:Label ID="Label8" runat="server" Text='<%# adatta_testo(Eval("Descrizione1"),80) %>' Font-Bold="true" ForeColor="Red"></asp:Label><img src="images/successivo.jpg" title='<%# Eval("Descrizione1") %>' alt="" /><br />
                                            <asp:Label ID="tagliecolori" runat="server" Text='<%# Eval("taglia") & " " & Eval("colore") %>' Font-Bold="true" ForeColor="Red"></asp:Label><br />
                                        </asp:HyperLink>
                                    </td>
                                </tr>
                                <!-- Seriali -->
                                <tr>
                                    <td style=" width:100%; height:45%; vertical-align:top;">
                                        <div id="Panel_Seriali" visible="False" runat="server" style="width:420px; height:25px; margin-top:0px; padding-bottom:10px;">
                                            <b>Seriali</b><br />
                                                <div style=" width:100%; height:100%; overflow:auto; margin:0px;">
                                                    <asp:Label ID="lbl_seriale" runat="server" Text="" Font-Italic="true"></asp:Label>
                                                </div>
                                        </div>
                                    </td>
                                </tr>
                                <!-- Info -->
                                <tr>
                                    <td style=" width:100%; height:30%; vertical-align:middle; overflow:hidden; font-size:8pt;">
                                        <div style="float:left;"><b>EAN.</b> <%# Eval("Ean") %></div>
                                        <div class="pl-md-2" style="float:left;"><b>CODICE</b> <%# Eval("Codice") %></div>
                                        <div class="pl-md-2" style="float:left;"><b>MARCA</b> <%# Eval("MarcheDescrizione") %></div>
                                    </td>
                                </tr>
                            </table>
                        </div>
                    </div>
					<!-- Prezzo e Quantità -->
					<div style="width:100%; height:100px; float:left;">
						<table style="width:100%; height:100%; vertical-align:middle; background-color:#dadada; font-size:7pt;">
							<!-- Quantità -->
							<tr>
								<td>
									Quantità
								</td>
								<td style=" width:100%; height:20%; vertical-align:middle; text-align:right; overflow:hidden; font-weight:bold;">
									<%#Eval("Qnt")%>
								</td>
							</tr>
							<!-- IVA applicata -->
							<tr>
								<td>
									IVA
								</td>
								<td style=" width:100%; height:20%; vertical-align:middle; text-align:right; overflow:hidden; font-weight:bold;">
									<%#Eval("ValoreIVA")%>%<br />                             
								</td>
							</tr>
							<!-- Prezzo Singolo Prodotto -->
							<tr>
								<td>
									Prezzo
								</td>
								<td style=" width:100%; height:20%; vertical-align:middle; text-align:right; overflow:hidden;">
									<asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>' Font-Bold="true" Font-Size="7pt"></asp:Label>
									<asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Font-Bold="true" Visible="false" Font-Size="7pt"></asp:Label>
								</td>
							</tr>
							<!-- Importo Totale -->
							<tr>
								<td colspan="2" style="width:100%; height:60%; vertical-align:bottom; text-align:right; overflow:hidden; font-size:12pt; font-weight:bold; border-style:solid; border-width:1px; border-color:Black; background-color:White; padding-bottom:5px;">
									<span style=" font-size:7pt; font-weight:normal; color:Red;">Importo</span><br />
									<asp:Label ID="lblImportoIvato" runat="server" Text='<%# Bind("ImportoIvato", "{0:C}") %>'></asp:Label>
									<asp:Label ID="lblImporto" runat="server" Text='<%# Bind("Importo", "{0:C}") %>' Visible="false"></asp:Label>
								</td>
							</tr>
						</table>
					</div>
                    </ItemTemplate>
                <HeaderStyle HorizontalAlign="Right" />
                <ItemStyle Font-Bold="True" HorizontalAlign="Right" Wrap="False" />
            </asp:TemplateField>
        </Columns>
        <PagerStyle CssClass="nav" Font-Bold="True" />
        <HeaderStyle Font-Bold="False" Font-Size="8pt" ForeColor="#2050AF" HorizontalAlign="Left" />
        <EditRowStyle Font-Bold="False" />
        <AlternatingRowStyle BackColor="WhiteSmoke" BorderStyle="None" />
    </asp:GridView>
    
    <%If Me.GridView2.Rows.Count > 0 Then%>
        <img src="Public/Images/spGratis.gif" />
    <%End If%>
        
    <asp:GridView ID="GridView1" runat="server" AutoGenerateColumns="False"
        CellPadding="3" DataKeyNames="id" DataSourceID="sdsRighe" EmptyDataText=""
        Font-Size="8pt" GridLines="None" PageSize="15" Width="100%">
        <Columns>
            <asp:TemplateField>
                <ItemTemplate>
                    <div class="row m-0" style="font-size:8pt; text-align:left; border-color:Gray; border-collapse:collapse; border-width:1px; border-style:solid;">
                        <!-- Foto -->
                        <div class="col-4" style="float:left; vertical-align:middle;">
                            <table style="width:100%; height:100%;">
                                <tr>
                                    <td style="width:100%; height:100%; vertical-align:middle; overflow:hidden;">
                                        <div style="width:100px; height:95px; overflow:hidden;">
                                            <asp:HyperLink ID="HyperLink3" idarticolo='<%# Eval("ArticoliId") %>' runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") & "&TCId=" & Eval("TCId") %>' ><asp:Image ID="Image_Articolo" runat="server" Width="80"  AlternateText='<%# Eval("Descrizione1") %>' ImageUrl='<%# Eval("img1", "~/Public/foto/_{0}") %>' /></asp:HyperLink>
                                        </div>
                                    </td>
                                </tr>
                            </table>
                        </div>
                        <!-- Info prodotto -->
                        <div class="col-8" style="float:left; vertical-align:middle;">
                            <table style="width:100%; height:100%;">
                                <!-- Titolo Prodotto -->
                                <tr>
                                    <td style="width:100%; height:25%; font-size:10pt; font-weight:bold; vertical-align:top; overflow:hidden;">
                                        <asp:HyperLink ID="HyperLink5" style="cursor:hand" ToolTip='<%# Eval("Descrizione1") %>' runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("articoliid") & "&TCId=" & Eval("TCId") %>' ><br />
                                            <asp:Label ID="Label8" runat="server" Text='<%# adatta_testo(Eval("Descrizione1"),80) %>' Font-Bold="true" ForeColor="Red"></asp:Label><img src="images/successivo.jpg" title='<%# Eval("Descrizione1") %>' alt="" /><br />
                                            <asp:Label ID="tagliecolori" runat="server" Text='<%# Eval("taglia") & " " & Eval("colore") %>' Font-Bold="true" ForeColor="Red"></asp:Label><br />
                                        </asp:HyperLink>
                                    </td>
                                </tr>
                                <!-- Seriali -->
                                <tr>
                                    <td style=" width:100%; height:45%; vertical-align:middle;">
                                        <div id="Panel_Seriali" visible="False" runat="server" style="width:420px; height:25px; margin-top:0px; padding-bottom:10px;">
                                            <b>Seriali</b><br />
                                                <div style=" width:100%; height:100%; overflow:auto; margin:0px;">
                                                    <asp:Label ID="lbl_seriale" runat="server" Text="" Font-Italic="true"></asp:Label>
                                                </div>
                                        </div>
                                    </td>
                                </tr>
                                <!-- Info -->
                                <tr>
                                    <td style=" width:100%; height:30%; vertical-align:middle; overflow:hidden; font-size:8pt;">
                                        <div style="float:left;"><b>EAN.</b> <%# Eval("Ean") %></div>
                                        <div class="pl-md-2" style="float:left;"><b>CODICE</b> <%# Eval("Codice") %></div>
                                        <div class="pl-md-2" style="float:left;"><b>MARCA</b> <%# Eval("MarcheDescrizione") %></div>
                                    </td>
                                </tr>
                            </table>
                        </div>
                        
                    </div>
					<!-- Prezzo e Quantità -->
					<div style="width:100%; height:100px; float:left;">
						<table style="width:100%; height:100%; vertical-align:middle; background-color:#dadada; font-size:7pt;">
							<!-- Quantità -->
							<tr>
								<td style="width:10%;">
									Quantità:
								</td>
								<td style="height:20%; vertical-align:middle; overflow:hidden; font-weight:bold;">
									<%#Eval("Qnt")%>
								</td>
							</tr>
							<!-- Prezzo Singolo Prodotto -->
							<tr>
								<td style="width:10%;">
									Prezzo:
								</td>
								<td style="height:20%; vertical-align:middle; overflow:hidden;">
									<asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>' Font-Bold="true" Font-Size="7pt"></asp:Label>
									<asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Font-Bold="true" Visible="false" Font-Size="7pt"></asp:Label>
								</td>
							</tr>
							 <!-- IVA applicata -->
							<tr>
								<td style="width:10%;">
									IVA:
								</td>
								<td style="height:20%; vertical-align:middle; overflow:hidden; font-weight:bold;">
									<%#Eval("ValoreIva")%>%
								</td>
							</tr>
							<!-- Importo Totale -->
							<tr>
								<td style="width:10%;">
									<span style=" font-size:7pt; font-weight:normal; color:Red;">Importo:</span><br />
								</td>
								<td style="height:20%; vertical-align:middle; overflow:hidden;font-weight:bold;">
									<asp:Label ID="lblImportoIvato" runat="server" Text='<%# Bind("ImportoIvato", "{0:C}") %>'></asp:Label>
									<asp:Label ID="lblImporto" runat="server" Text='<%# Bind("Importo", "{0:C}") %>' Visible="false"></asp:Label>
								</td>
							</tr>
						</table>
					</div>
                </ItemTemplate>
            </asp:TemplateField>
        </Columns>
        <HeaderStyle Font-Bold="False" Font-Size="8pt" ForeColor="#2050AF" HorizontalAlign="Left" />
        <PagerStyle CssClass="nav" Font-Bold="True" />
        <AlternatingRowStyle BackColor="WhiteSmoke" BorderStyle="None" />
        <EmptyDataRowStyle Font-Bold="False" Height="50px" HorizontalAlign="Center" />
        <EditRowStyle Font-Bold="False" />
    </asp:GridView>
    <asp:SqlDataSource ID="sdsRighe" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT vdocumentirighe.id, DocumentiId, vdocumentirighe.ArticoliId, TCid, Ean, Codice, Descrizione1, Descrizione2, um, peso, prezzobase, Qnt, sc1, sc2, sc3, importo, iva, Valoreiva, SpGratis, ImportoIvato, PrezzoIvato, prezzo, omaggio, movimento, movimentato, Img1, MarcheId, MarcheDescrizione, taglie.descrizione as taglia, colori.descrizione as colore FROM vdocumentirighe left outer join articoli_tagliecolori on articoli_tagliecolori.id = vdocumentirighe.TCId left outer join taglie on taglie.id = articoli_tagliecolori.tagliaid left outer join colori on colori.id = articoli_tagliecolori.coloreid WHERE (DocumentiId = @idDocumento) AND (SpGratis = 0) OR (DocumentiId = @idDocumento) AND (SpGratis IS NULL)">
        <SelectParameters>
            <asp:QueryStringParameter Name="idDocumento" Type="Int64" QueryStringField="id"/>
        </SelectParameters>
    </asp:SqlDataSource>
    <asp:SqlDataSource ID="sdsRigheSpedizioneGratis" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT vdocumentirighe.*, taglie.descrizione as taglia, colori.descrizione as colore FROM vdocumentirighe left outer join articoli_tagliecolori on articoli_tagliecolori.id = vdocumentirighe.TCId left outer join taglie on taglie.id = articoli_tagliecolori.tagliaid left outer join colori on colori.id = articoli_tagliecolori.coloreid WHERE (DocumentiId = ?DocumentiId) AND (SpGratis=1)">
        <SelectParameters>
            <asp:QueryStringParameter Name="DocumentiId" Type="Int64" QueryStringField="id"/>
        </SelectParameters>
    </asp:SqlDataSource>

	<style>
		.table-det td{
			padding: 0px;
		}
	</style>
  <asp:FormView ID="FormView2" runat="server" DataSourceID="sdsTestata" Width="100%" CssClass="table-det">
        <ItemTemplate>  
            <div style="text-align:right; vertical-align:middle; font-size:8pt; background-color:#dadada;">
                <div class="container">
					<div class="row">
						<div class="col-4 col-md-2" style="height:50px; background-color:White;border: 1px solid #dadada;">
							<span style="color:Red;">Spedizione</span><br />
							<asp:Label ID="lblSpeseSped" runat="server" Text='<%# Eval("CostoSpedizione","{0:C}") %>' Font-Bold="true" Font-Size="10pt"></asp:Label>
						</div>
						<div class="col-4 col-md-2" style="height:50px; background-color:White;border: 1px solid #dadada;">
							<span style="color:Red;">Assicurazione</span><br />
							<asp:Label ID="lblSpeseAss" runat="server" Text='<%# Eval("CostoAssicurazione","{0:C}") %>' Font-Bold="true" Font-Size="10pt"></asp:Label>
						</div>
						<div class="col-4 col-md-2" style="height:50px; background-color:White;border: 1px solid #dadada;">
							<span style="color:Red;">Pagamento</span><br />
							<asp:Label ID="lblSpesePag" runat="server" Text='<%# Eval("CostoPagamento","{0:C}") %>' Font-Bold="true" Font-Size="10pt"></asp:Label>
						</div>
						<div class="col-4 col-md-2" style="height:50px; background-color:White;border: 1px solid #dadada;">
							<span style="color:Red;">Imponibile</span><br />
							<asp:Label ID="lblImponibile" runat="server" Text='<%# Eval("TotImponibile","{0:C}") %>' Font-Bold="True" Font-Size="10pt"></asp:Label>
						</div>
						<div class="col-4 col-md-2" style="height:50px; background-color:White;border: 1px solid #dadada;">
							<span style="color:Red;">IVA</span><br />
							<asp:Label ID="lblIva" runat="server" Text='<%# Eval("TotIva","{0:C}") %>' Font-Bold="True" Font-Size="10pt"></asp:Label><br />
						</div>
						<div class="col-4 col-md-2" style=" height:50px; background-color:White; border-style:solid; border-color:Black; border-width:1px;">
							<span style="color:Red;">Totale</span><br />
							<asp:Label ID="lblTotale" runat="server" Text='<%# Eval("TotaleDocumento","{0:C}") %>' ForeColor="#E12825" Font-Bold="True" Font-Size="15pt"></asp:Label>
						</div>
					</div>
				</div>
				<div class="row">
					<div class="col-12">
						<asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label>
					</div>
				</div>
            </div>
        </ItemTemplate>
    </asp:FormView>
    
    <br />
    <div style=" width:100%; padding:10px; font-weight:bold; border-width:1px; border-color:Gray; border-style:solid; overflow:auto; background-color:Gray; color:White;">
        <div style="float:left;">
            <a style="cursor:hand; cursor:pointer; color:White;" onClick="javascript:history.back()">Torna Indietro</a>
        </div>
        <div style="float:right;">
            <a href="default.aspx" style="color:White;">Vai alla HOMEPAGE</a>
        </div>
    </div>
    
    <asp:Repeater ID="Lista_Articoli" runat="server" DataSourceID="sdsRighe">
        <ItemTemplate>
            
        </ItemTemplate>
    </asp:Repeater>
    
    
    <!-- Tracking per Bestshopping -->
    <asp:Label ID="img_bs_label" runat="server"></asp:Label>
    
    <script type="text/javascript">
        //check if the browser support HTML5 postmessage
        if (!BrowserEnabled) {
            document.getElementById("bsButton").innerHTML = "HTML5 is not suported by your browser!";
        }
    </script>
</asp:Content>