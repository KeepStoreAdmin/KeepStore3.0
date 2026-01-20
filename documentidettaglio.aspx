<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="documentidettaglio.aspx.vb" Inherits="documentidettaglio" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Dettaglio documento
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <script src="https://ecomm.sella.it/pagam/JavaScript/js_GestPay.js" type="text/javascript"></script>

    <style type="text/css">
        /* STEP24 (ONUS): tabella dettaglio ordine/documento */
        .ks-order-detail .tf-table-order-detail {
            width: 100%;
        }

        .ks-order-detail .tf-table-order-detail th,
        .ks-order-detail .tf-table-order-detail td {
            vertical-align: top;
        }

        .ks-order-detail .tf-table-order-detail .ks-muted {
            opacity: 0.75;
        }

        .ks-order-detail .ks-actions {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }

        .ks-order-detail .ks-actions a,
        .ks-order-detail .ks-actions input,
        .ks-order-detail .ks-actions button {
            white-space: nowrap;
        }

        .ks-order-detail .ks-link-back {
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

        .ks-order-detail .ks-link-back i {
            font-size: 14px;
        }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">

    <div class="tf-breadcrumb">
        <div class="container">
            <ul class="breakcrumbs">
                <li>
                    <a href="default.aspx" class="body-small link">Home</a>
                </li>
                <li class="d-flex align-items-center">
                    <i class="icon icon-arrow-right"></i>
                </li>
                <li>
                    <a href="documenti.aspx" class="body-small link">I miei documenti</a>
                </li>
                <li class="d-flex align-items-center">
                    <i class="icon icon-arrow-right"></i>
                </li>
                <li>
                    <span class="body-small">Dettaglio documento</span>
                </li>
            </ul>
        </div>
    </div>

    <section class="tf-sp-2 ks-order-detail">
        <div class="container">

            <asp:SqlDataSource ID="sdsTestata" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM vdocumenti LEFT JOIN vettori ON vdocumenti.`VettoriId`=vettori.`id` WHERE ((vdocumenti.Id = ?Id) AND (vdocumenti.UtentiId = ?UtentiId))">
                <SelectParameters>
                    <asp:QueryStringParameter Name="Id" Type="Int64" QueryStringField="id"/>
                    <asp:SessionParameter Name="UtentiId" SessionField="UtentiID" Type="int32" />
                </SelectParameters>
            </asp:SqlDataSource>

            <div class="tf-order-detail">

                <asp:FormView ID="FormView1" runat="server" DataSourceID="sdsTestata" Width="100%">
                    <ItemTemplate>

                        <div class="order-notice">
                            <span class="icon">
                                <svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" fill="#ffffff" viewBox="0 0 256 256">
                                    <path d="M128,16A112,112,0,1,0,240,128,112.13,112.13,0,0,0,128,16Zm0,208a96,96,0,1,1,96-96A96.11,96.11,0,0,1,128,224Zm-8-56a12,12,0,1,1,12,12A12,12,0,0,1,120,168Zm20-88v48a8,8,0,0,1-16,0V88a8,8,0,0,1,16,0Z"></path>
                                </svg>
                            </span>
                            <p>Dettaglio documento</p>
                        </div>

                        <ul class="order-overview-list">
                            <li>Documento: <strong><%# Eval("TipoDocumentiDescrizione") %> n. <%# Eval("NDocumento") %></strong></li>
                            <li>Data: <strong><%# Eval("DataDocumento", "{0:d}") %></strong></li>
                            <li>Totale: <strong><%# Eval("TotaleDocumento", "{0:C}") %></strong></li>
                            <li>Stato: <strong><%# Eval("StatiDescrizione1") %> <%# Eval("StatiDescrizione2") %></strong></li>
                        </ul>

                        <div class="order-detail-wrap">
                            <h5 class="fw-bold">Spedizione, pagamento e tracking</h5>
                            <div class="billing-info">
                                <p><span class="fw-semibold">Spedizione:</span> <%# Eval("VettoriDescrizione") %> - <%# Eval("VettoriInformazioni") %></p>
                                <p><span class="fw-semibold">Pagamento:</span> <%# Eval("PagamentiTipoDescrizione") %> - <%# Eval("PagamentiTipoInformazioni") %></p>
                                <p>
                                    <span class="fw-semibold">Tracking:</span>
                                    <span class="ks-muted"><%# SeparaTracking(Eval("Tracking"), Eval("Link_Tracking")) %></span>
                                </p>
                            </div>
                        </div>

                        <div class="order-detail-wrap">
                            <h5 class="fw-bold">Paga adesso</h5>
                            <div class="ks-actions">
                                <asp:TextBox ID="tbTipo" runat="server" Visible="false" Text='<%# Eval("TipoDocumentiId") %>' Width="10"></asp:TextBox>
                                <asp:TextBox ID="tbOnline" runat="server" Visible="false" Text='<%# Eval("PagamentiTipoOnline") %>' Width="10"></asp:TextBox>

                                <asp:ImageButton ID="btBancaSella" runat="server" Visible="false" CommandName="PagamentoBancaSella" CommandArgument='<%# Eval("ShopLogin") %>' codiceAutorizzazione='<%# Eval("CodiceAutorizzazione")%>' idDocumento='<%# Eval("id") %>' nDocumento='<%# Eval("NDocumento") %>' totaleDocumento='<%# Eval("TotaleDocumento") %>' ToolTip="Paga Adesso" ImageUrl="public/images/paga_adesso.gif" Style="height:42px;" />

                                <asp:ImageButton ID="btIwBank" runat="server" Visible="false" PostBackUrl='<%# "https://checkout.iwsmile.it/Pagamenti/?ACCOUNT=" & Me.Session("AccountIwBank") & "&ITEM_NAME=Ordine+n.+" & Eval("NDocumento") & "+del+" & Eval("DataDocumento") & "&ITEM_NUMBER=" & Eval("NDocumento") & "&QUANTITY=1&FLAG_ONLY_IWS=0&AMOUNT=" & Replace(Replace(Eval("TotaleDocumento", "{0:N}"), ".", ""), ",", ".") & "&NOTE=0&URL_OK=" & Request.Url.Scheme & "://" & Request.Url.Host & "/pagamento.aspx?id=" & Eval("id") & "&URL_BAD=" & Request.Url.Scheme & "://" & Request.Url.Host & "/documentidettaglio.aspx?id=" & Eval("id") %>' ToolTip="Paga con IwBank" ImageUrl="public/images/paga_adesso.gif" Style="height:42px;" />

                                <asp:Button ID="btPayPal" runat="server" Visible="false" Text="PAGA ADESSO" Font-Bold="true" CommandName="PagamentoPayPal" idDocumento='<%# Eval("id") %>' nDocumento='<%# Eval("NDocumento") %>' totaleDocumento='<%# Replace(Replace(Eval("TotaleDocumento", "{0:N}"), ".", ""), ",", ".") %>' dataDocumento='<%# Eval("DataDocumento") %>' ToolTip="Paga con PayPal" CssClass="tf-btn" />
                            </div>
                            <p class="body-small ks-muted" style="margin-top:10px;">I pulsanti di pagamento vengono mostrati solo per documenti online non ancora saldati.</p>
                        </div>

                    </ItemTemplate>
                </asp:FormView>

                <div class="order-detail-wrap">
                    <h5 class="fw-bold">Righe documento</h5>

                    <asp:GridView ID="GridView2" runat="server" AutoGenerateColumns="False" CellPadding="3" DataKeyNames="id" DataSourceID="sdsRigheSpedizioneGratis" EmptyDataText="" Font-Size="8pt" GridLines="None" PageSize="15" Width="100%" CssClass="tf-table-order-detail" RowStyle-CssClass="tf-order-item">
                        <Columns>
                            <asp:TemplateField HeaderText="Prodotto">
                                <ItemTemplate>
                                    <div class="tf-order-item_product">
                                        <asp:HyperLink ID="hlProdottoSpGratis" runat="server" CssClass="link fw-normal"
                                            NavigateUrl='<%# "~/articolo.aspx?id=" & Eval("ArticoliId") & "&TCId=" & Eval("TCId") %>'
                                            Text='<%# Eval("Descrizione1") %>' />
                                        <span class="text-black">×<%# Eval("Qnt") %></span>
                                        <div class="body-small ks-muted">Spedizione gratis</div>
                                    </div>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Totale">
                                <ItemTemplate>
                                    <span class="fw-medium"><%# Eval("ImportoIvato", "{0:C}") %></span>
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Right" />
                            </asp:TemplateField>
                        </Columns>
                        <HeaderStyle Font-Bold="True" />
                        <AlternatingRowStyle BackColor="WhiteSmoke" />
                    </asp:GridView>

                    <% If Me.GridView2.Rows.Count > 0 Then %>
                        <div style="margin:10px 0;">
                            <img src="Public/Images/spGratis.gif" alt="Spedizione gratis" />
                        </div>
                    <% End If %>

                    <asp:GridView ID="GridView1" runat="server" AutoGenerateColumns="False" CellPadding="3" DataKeyNames="id" DataSourceID="sdsRighe" EmptyDataText="" Font-Size="8pt" GridLines="None" PageSize="15" Width="100%" CssClass="tf-table-order-detail" RowStyle-CssClass="tf-order-item">
                        <Columns>
                            <asp:TemplateField HeaderText="Prodotto">
                                <ItemTemplate>
                                    <div class="tf-order-item_product">
                                        <asp:HyperLink ID="hlProdotto" runat="server" CssClass="link fw-normal"
                                            NavigateUrl='<%# IIf(Eval("articoliid") > 0, "~/articolo.aspx?id=" & Eval("articoliid") & "&TCId=" & Eval("TCId"), "#") %>'
                                            Text='<%# AdattaTesto(Eval("Descrizione1"), 110) %>' />
                                        <span class="text-black">×<%# Eval("Qnt") %></span>
                                        <div class="body-small ks-muted">
                                            <span>EAN: <%# Eval("Ean") %></span>
                                            <span class="ms-2">Codice: <%# Eval("Codice") %></span>
                                            <span class="ms-2">Marca: <%# Eval("MarcheDescrizione") %></span>
                                            <span class="ms-2"><%# Eval("taglia") & " " & Eval("colore") %></span>
                                        </div>
                                    </div>
                                </ItemTemplate>
                            </asp:TemplateField>
                            <asp:TemplateField HeaderText="Totale">
                                <ItemTemplate>
                                    <span class="fw-medium"><%# Eval("ImportoIvato", "{0:C}") %></span>
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Right" Wrap="False" />
                            </asp:TemplateField>
                        </Columns>
                        <HeaderStyle Font-Bold="True" />
                        <AlternatingRowStyle BackColor="WhiteSmoke" />
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

                </div>

                <div class="order-detail-wrap">
                    <h5 class="fw-bold">Riepilogo importi</h5>
                    <asp:FormView ID="FormView2" runat="server" DataSourceID="sdsTestata" Width="100%">
                        <ItemTemplate>
                            <table class="tf-table-order-detail">
                                <tbody>
                                    <tr>
                                        <th><span>Spedizione:</span></th>
                                        <td style="text-align:right;"><asp:Label ID="lblSpeseSped" runat="server" Text='<%# Eval("CostoSpedizione","{0:C}") %>' Font-Bold="true"></asp:Label></td>
                                    </tr>
                                    <tr>
                                        <th><span>Assicurazione:</span></th>
                                        <td style="text-align:right;"><asp:Label ID="lblSpeseAss" runat="server" Text='<%# Eval("CostoAssicurazione","{0:C}") %>' Font-Bold="true"></asp:Label></td>
                                    </tr>
                                    <tr>
                                        <th><span>Pagamento:</span></th>
                                        <td style="text-align:right;"><asp:Label ID="lblSpesePag" runat="server" Text='<%# Eval("CostoPagamento","{0:C}") %>' Font-Bold="true"></asp:Label></td>
                                    </tr>
                                    <tr>
                                        <th><span>Imponibile:</span></th>
                                        <td style="text-align:right;"><asp:Label ID="lblImponibile" runat="server" Text='<%# Eval("TotImponibile","{0:C}") %>' Font-Bold="True"></asp:Label></td>
                                    </tr>
                                    <tr>
                                        <th><span>IVA:</span></th>
                                        <td style="text-align:right;"><asp:Label ID="lblIva" runat="server" Text='<%# Eval("TotIva","{0:C}") %>' Font-Bold="True"></asp:Label></td>
                                    </tr>
                                    <tr>
                                        <th>
                                            <p class="fw-semibold product-title text-uppercase" style="margin:0;">Totale:</p>
                                        </th>
                                        <td style="text-align:right;"><asp:Label ID="lblTotale" runat="server" Text='<%# Eval("TotaleDocumento","{0:C}") %>' Font-Bold="True"></asp:Label></td>
                                    </tr>
                                </tbody>
                            </table>
                            <div class="body-small ks-muted" style="margin-top:8px;">
                                <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi"></asp:Label>
                            </div>
                        </ItemTemplate>
                    </asp:FormView>
                </div>

                <div class="order-detail-wrap">
                    <div class="ks-actions" style="justify-content:space-between;">
                        <a href="javascript:history.back()" class="tf-btn"><span class="ks-link-back"><i class="icon-arrow-left-lg"></i>Torna indietro</span></a>
                        <a href="default.aspx" class="tf-btn">Vai alla homepage</a>
                    </div>
                </div>

            </div>

        </div>
    </section>

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