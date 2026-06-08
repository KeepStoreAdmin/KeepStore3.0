<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="documentidettaglio.aspx.vb" Inherits="documentidettaglio" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Dettaglio ordine
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/order-ui.css") %>?v=20260609-order-confirmation-1a" />
    <script src="https://ecomm.sella.it/pagam/JavaScript/js_GestPay.js" type="text/javascript"></script>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">
<div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="myaccount.aspx" class="text">Account</a>
                    <i class="icon icon-arrow-right"></i>
                    <asp:HyperLink ID="hlDocumenti" runat="server" CssClass="text" NavigateUrl="documenti.aspx?t=4">Ordini</asp:HyperLink>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Dettaglio</span>
                </div>
            </div>
        </div>
    </div>

    <section class="tf-sp-2 ks-order-detail">
        <div class="container">
            <asp:SqlDataSource ID="sdsTestata" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT vd.*, utenti.*, vettori.*, COALESCE(dpay.Pagato,0) AS DettaglioPagato, COALESCE(dpay.StatoPagamentoWeb,0) AS DettaglioStatoPagamentoWeb, dpay.DataStatoPagamentoWeb AS DettaglioDataStatoPagamentoWeb, COALESCE(dpay.UltimoEsitoPagamentoWeb,'') AS DettaglioUltimoEsitoPagamentoWeb FROM ((vdocumenti vd LEFT JOIN utenti ON vd.`UtentiId` = utenti.`Id`) LEFT JOIN vettori ON vd.`VettoriId` = vettori.`id`) LEFT JOIN documenti dpay ON dpay.`id` = vd.`Id` WHERE ((vd.Id = ?Id) AND (vd.UtentiId = ?UtentiId))">
                <SelectParameters>
                    <asp:QueryStringParameter Name="Id" Type="Int64" QueryStringField="id"/>
                    <asp:SessionParameter Name="UtentiId" SessionField="UtentiID" Type="int32" />
                </SelectParameters>
            </asp:SqlDataSource>

            <div class="tf-order-detail">
                <asp:Panel ID="pnlPayReturnMessage" runat="server" Visible="false" CssClass="alert alert-info" role="alert">
                    <asp:Literal ID="litPayReturnMessage" runat="server" />
                </asp:Panel>

                <asp:FormView ID="FormView1" runat="server" DataSourceID="sdsTestata" Width="100%">
                    <ItemTemplate>

                        <section class="ks-order-confirmation" data-order-number='<%# HtmlAttr(Eval("NDocumento")) %>'>
                            <div class="ks-confirm-hero">
                                <div class="ks-confirm-hero-main">
                                    <div class="ks-confirm-kicker">
                                        <span class="ks-confirm-kicker-icon">✓</span>
                                        <span><%# GetOrderHeroBadge() %></span>
                                    </div>
                                    <h1><%# GetOrderHeroTitle() %></h1>
                                    <p class="ks-confirm-lead"><%# GetOrderHeroText(Eval("DettaglioPagato"), Eval("DettaglioStatoPagamentoWeb")) %></p>
                                    <div class="ks-confirm-actions" aria-label="Azioni ordine">
                                        <button type="button" class="tf-btn ks-print-order" data-action="print-order">Stampa ordine</button>
                                        <button type="button" class="tf-btn btn-gray ks-copy-order" data-action="copy-order" data-order-number='<%# HtmlAttr(Eval("NDocumento")) %>'>Copia numero ordine</button>
                                        <a href="documenti.aspx?t=4" class="tf-btn btn-gray">Vai ai miei ordini</a>
                                        <a href="default.aspx" class="tf-btn btn-gray">Continua gli acquisti</a>
                                    </div>
                                    <p class="ks-copy-feedback" aria-live="polite" role="status"></p>
                                </div>
                                <div class="ks-confirm-visual" aria-hidden="true">
                                    <div class="ks-confirm-package">
                                        <span class="ks-confirm-package-check">✓</span>
                                    </div>
                                    <span class="ks-confirm-route"></span>
                                    <span class="ks-confirm-dot"></span>
                                </div>
                            </div>

                            <div class="ks-confirm-overview" aria-label="Dati principali ordine">
                                <div>
                                    <span>Data ordine</span>
                                    <strong><%# Eval("DataDocumento", "{0:d}") %></strong>
                                </div>
                                <div>
                                    <span>Numero ordine</span>
                                    <strong><%# Eval("TipoDocumentiDescrizione") %> n. <%# Eval("NDocumento") %></strong>
                                </div>
                                <div>
                                    <span>Numero cliente</span>
                                    <strong><%# FormatCustomerNumber(Eval("UtentiId")) %></strong>
                                </div>
                                <div>
                                    <span>E-mail</span>
                                    <strong><%# HtmlText(Eval("Email")) %></strong>
                                </div>
                                <div>
                                    <span>Stato ordine</span>
                                    <strong><%# FormatOrderStatus(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %></strong>
                                </div>
                                <div>
                                    <span>Stato pagamento</span>
                                    <strong><%# GetPaymentStatusLabel(Eval("DettaglioPagato"), Eval("DettaglioStatoPagamentoWeb")) %></strong>
                                </div>
                            </div>

                            <div class="ks-confirm-card-grid">
                                <article class="ks-confirm-card">
                                    <div class="ks-confirm-card-head">
                                        <h5 class="fw-bold">Pagamento</h5>
                                        <span class='<%# GetPaymentStatusCssClass(Eval("DettaglioPagato"), Eval("DettaglioStatoPagamentoWeb")) %>'><%# GetPaymentStatusLabel(Eval("DettaglioPagato"), Eval("DettaglioStatoPagamentoWeb")) %></span>
                                    </div>
                                    <div class="billing-info">
                                        <p><span class="fw-semibold">Metodo:</span> <%# Eval("PagamentiTipoDescrizione") %></p>
                                        <p><%# HtmlText(Eval("PagamentiTipoInformazioni")) %></p>
                                        <p class="ks-muted"><%# GetPaymentStatusDescription(Eval("DettaglioPagato"), Eval("DettaglioStatoPagamentoWeb"), Eval("DettaglioUltimoEsitoPagamentoWeb")) %></p>
                                        <p class="ks-muted" runat="server" visible='<%# HasPaymentStateDate(Eval("DettaglioDataStatoPagamentoWeb")) %>'>Aggiornato: <%# FormatPaymentStateDate(Eval("DettaglioDataStatoPagamentoWeb")) %></p>
                                    </div>
                                </article>

                                <article class="ks-confirm-card">
                                    <h5 class="fw-bold">Indirizzo di spedizione</h5>
                                    <div class="billing-info">
                                        <p><%# FormatShippingRecipient(Eval("DestinazioneMerci"), Eval("RagioneSociale"), Eval("CognomeNome")) %></p>
                                        <p><%# FormatShippingAddress(Eval("DestinazioneMerci"), Eval("Indirizzo")) %></p>
                                        <p><%# Eval("Cap") %> <%# Eval("Citta") %> (<%# Eval("Provincia") %>)</p>
                                        <p><%# FormatPhoneLine(Eval("Telefono"), Eval("Cellulare")) %></p>
                                    </div>
                                </article>

                                <article class="ks-confirm-card">
                                    <h5 class="fw-bold">Indirizzo di fatturazione</h5>
                                    <div class="billing-info">
                                        <p><%# Eval("RagioneSociale") %></p>
                                        <p><%# Eval("CognomeNome") %></p>
                                        <p><%# Eval("Indirizzo") %></p>
                                        <p><%# Eval("Cap") %> <%# Eval("Citta") %> (<%# Eval("Provincia") %>)</p>
                                        <p><%# Eval("Telefono") %> <%# IIf(String.IsNullOrEmpty(Convert.ToString(Eval("Cellulare"))), "", " - " & Eval("Cellulare")) %></p>
                                        <p><%# Eval("Email") %></p>
                                    </div>
                                </article>

                                <article class="ks-confirm-card">
                                    <h5 class="fw-bold">Prossimi passi</h5>
                                    <ol class="ks-confirm-steps">
                                        <li class="is-complete"><span>Ordine ricevuto</span></li>
                                        <li class='<%# GetTimelineStepCssClass("payment", Eval("DettaglioPagato"), Eval("DettaglioStatoPagamentoWeb"), Eval("Tracking")) %>'><span><%# GetTimelinePaymentText(Eval("DettaglioPagato"), Eval("DettaglioStatoPagamentoWeb")) %></span></li>
                                        <li class="is-current"><span>Preparazione ordine</span></li>
                                        <li class='<%# GetTimelineStepCssClass("shipping", Eval("DettaglioPagato"), Eval("DettaglioStatoPagamentoWeb"), Eval("Tracking")) %>'><span><%# GetTimelineShippingText(Eval("Tracking")) %></span></li>
                                        <li><span>Consegna</span></li>
                                    </ol>
                                    <p class="ks-muted">Conserva il numero ordine per eventuali comunicazioni con l'assistenza.</p>
                                </article>

                                <article class="ks-confirm-card">
                                    <h5 class="fw-bold">Spedizione e tracking</h5>
                                    <div class="billing-info">
                                        <p><span class="fw-semibold">Vettore:</span> <%# Eval("VettoriDescrizione") %></p>
                                        <p><%# HtmlText(Eval("VettoriInformazioni")) %></p>
                                        <p>
                                            <span class="fw-semibold">Tracking:</span>
                                            <span class="ks-muted"><%# GetTrackingMessage(Eval("Tracking"), Eval("Link_Tracking")) %></span>
                                        </p>
                                    </div>
                                </article>

                                <article class="ks-confirm-card">
                                    <h5 class="fw-bold">Serve aiuto?</h5>
                                    <p class="ks-muted">Per assistenza indica sempre il numero ordine.</p>
                                    <div class="ks-confirm-mini-actions">
                                        <a href="documenti.aspx?t=4" class="link">Archivio ordini</a>
                                        <button type="button" class="ks-link-button" data-action="copy-order" data-order-number='<%# HtmlAttr(Eval("NDocumento")) %>'>Copia numero ordine</button>
                                    </div>
                                </article>
                            </div>
                        </section>

                        <div id="pnlPayNowCard" runat="server" visible="false" class="order-detail-wrap">
                            <h5 class="fw-bold">Paga adesso</h5>
                            <div class="ks-actions">
                                <asp:TextBox ID="tbTipo" runat="server" Visible="false" Text='<%# Eval("TipoDocumentiId") %>' Width="10"></asp:TextBox>
                                <asp:TextBox ID="tbOnline" runat="server" Visible="false" Text='<%# Eval("PagamentiTipoOnline") %>' Width="10"></asp:TextBox>
                                <asp:HiddenField ID="hfPayNowDocumentId" runat="server" Value='<%# Eval("id") %>' />

                                <asp:HyperLink ID="hlBancaSella" runat="server" Visible="false" ToolTip="Paga adesso con carta" CssClass="tf-btn" Text="Paga con carta" />
                                <asp:HyperLink ID="hlPayPalExpress" runat="server" Visible="false" ToolTip="Paga con PayPal" CssClass="tf-btn" Text="Paga con PayPal" />

                                <asp:ImageButton ID="btIwBank" runat="server" Visible="false" PostBackUrl='<%# "https://checkout.iwsmile.it/Pagamenti/?ACCOUNT=" & Me.Session("AccountIwBank") & "&ITEM_NAME=Ordine+n.+" & Eval("NDocumento") & "+del+" & Eval("DataDocumento") & "&ITEM_NUMBER=" & Eval("NDocumento") & "&QUANTITY=1&FLAG_ONLY_IWS=0&AMOUNT=" & Replace(Replace(Eval("TotaleDocumento", "{0:N}"), ".", ""), ",", ".") & "&NOTE=0&URL_OK=" & Request.Url.Scheme & "://" & Request.Url.Host & "/pagamento.aspx?id=" & Eval("id") & "&URL_BAD=" & Request.Url.Scheme & "://" & Request.Url.Host & "/documentidettaglio.aspx?id=" & Eval("id") %>' ToolTip="Paga con IwBank" ImageUrl="/Public/assets/images/pagamenti/visa.svg" Style="height:42px;" />

                                <asp:Button ID="btPayPal" runat="server" Visible="false" Text="PAGA ADESSO" Font-Bold="true" CommandName="PagamentoPayPal" idDocumento='<%# Eval("id") %>' nDocumento='<%# Eval("NDocumento") %>' totaleDocumento='<%# Replace(Replace(Eval("TotaleDocumento", "{0:N}"), ".", ""), ",", ".") %>' dataDocumento='<%# Eval("DataDocumento") %>' ToolTip="Paga con PayPal" CssClass="tf-btn" />
                            </div>
                            <p class="body-small ks-muted" style="margin-top:10px;">I pulsanti di pagamento vengono mostrati solo per documenti online non ancora saldati.</p>
                        </div>

                    </ItemTemplate>
                </asp:FormView>

                <div class="order-detail-wrap ks-confirm-card ks-confirm-card--wide">
                    <h5 class="fw-bold">Riepilogo ordine</h5>
                    <p class="body-small ks-muted">Prodotti, quantita e importi del documento.</p>

                    <!-- Righe: spedizione gratis (se presenti) -->
                    <asp:GridView ID="GridView2" runat="server" AutoGenerateColumns="False" CellPadding="0" DataKeyNames="id" DataSourceID="sdsRigheSpedizioneGratis" EmptyDataText="" GridLines="None" PageSize="100" Width="100%" CssClass="tf-table-order-detail" RowStyle-CssClass="tf-order-item">
                        <Columns>
                            <asp:TemplateField HeaderText="Prodotto">
                                <ItemTemplate>
                                    <div class="d-flex align-items-center gap-3">
                                        <div class="tf-order-img" style="width:64px; min-width:64px;">
                                            <img class="lazyload" src='<%# SafeImg(Eval("Img1")) %>' data-src='<%# SafeImg(Eval("Img1")) %>' alt="" style="width:64px; height:64px; object-fit:cover; border-radius:8px;" />
                                        </div>
                                        <div class="tf-order-item_product">
                                            <asp:HyperLink ID="hlProdottoSpGratis" runat="server" CssClass="link fw-normal"
                                                NavigateUrl='<%# "~/articolo.aspx?id=" & Eval("ArticoliId") & "&TCId=" & Eval("TCId") %>'
                                                Text='<%# Eval("Descrizione1") %>' />
                                            <div class="body-small ks-muted mt-1">
                                                <span>Codice: <%# Eval("Codice") %></span>
                                                <span class="ms-2"><%# Eval("taglia") & " " & Eval("colore") %></span>
                                                <span class="ms-2 badge bg-success" style="font-weight:600;">Spedizione gratis</span>
                                            </div>
                                        </div>
                                    </div>
                                </ItemTemplate>
                            </asp:TemplateField>

                            <asp:TemplateField HeaderText="Prezzo">
                                <ItemTemplate>
                                    <span class="fw-medium"><%# Eval("PrezzoIvato", "{0:C}") %></span>
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Right" Wrap="False" />
                            </asp:TemplateField>

                            <asp:TemplateField HeaderText="Q.tà">
                                <ItemTemplate>
                                    <span class="fw-medium">×<%# Eval("Qnt") %></span>
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" Wrap="False" />
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

                    <% If Me.GridView2.Rows.Count > 0 Then %>
                        <div style="margin:10px 0;">
                            <span class="badge bg-success" style="font-weight:600;">Spedizione gratis</span>
                        </div>
                    <% End If %>

                    <!-- Righe standard -->
                    <asp:GridView ID="GridView1" runat="server" AutoGenerateColumns="False" CellPadding="0" DataKeyNames="id" DataSourceID="sdsRighe" EmptyDataText="" GridLines="None" PageSize="100" Width="100%" CssClass="tf-table-order-detail" RowStyle-CssClass="tf-order-item">
                        <Columns>
                            <asp:TemplateField HeaderText="Prodotto">
                                <ItemTemplate>
                                    <div class="d-flex align-items-center gap-3">
                                        <div class="tf-order-img" style="width:64px; min-width:64px;">
                                            <img class="lazyload" src='<%# SafeImg(Eval("Img1")) %>' data-src='<%# SafeImg(Eval("Img1")) %>' alt="" style="width:64px; height:64px; object-fit:cover; border-radius:8px;" />
                                        </div>
                                        <div class="tf-order-item_product">
                                            <asp:HyperLink ID="hlProdotto" runat="server" CssClass="link fw-normal"
                                                NavigateUrl='<%# IIf(Eval("articoliid") > 0, "~/articolo.aspx?id=" & Eval("articoliid") & "&TCId=" & Eval("TCId"), "#") %>'
                                                Text='<%# AdattaTesto(Eval("Descrizione1"), 110) %>' />
                                            <div class="body-small ks-muted mt-1">
                                                <span>EAN: <%# Eval("Ean") %></span>
                                                <span class="ms-2">Codice: <%# Eval("Codice") %></span>
                                                <span class="ms-2">Marca: <%# Eval("MarcheDescrizione") %></span>
                                                <span class="ms-2"><%# Eval("taglia") & " " & Eval("colore") %></span>
                                            </div>
                                        </div>
                                    </div>
                                </ItemTemplate>
                            </asp:TemplateField>

                            <asp:TemplateField HeaderText="Prezzo">
                                <ItemTemplate>
                                    <span class="fw-medium"><%# Eval("PrezzoIvato", "{0:C}") %></span>
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Right" Wrap="False" />
                            </asp:TemplateField>

                            <asp:TemplateField HeaderText="Q.tà">
                                <ItemTemplate>
                                    <span class="fw-medium">×<%# Eval("Qnt") %></span>
                                </ItemTemplate>
                                <ItemStyle HorizontalAlign="Center" Wrap="False" />
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

                <div class="order-detail-wrap ks-confirm-card ks-confirm-card--wide">
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

                <div class="order-detail-wrap ks-confirm-bottom-actions">
                    <div class="ks-actions" style="justify-content:space-between;">
                        <a href="documenti.aspx?t=4" class="tf-btn"><span class="ks-link-back"><i class="icon-arrow-left-lg"></i>Vai ai miei ordini</span></a>
                        <a href="default.aspx" class="tf-btn btn-gray">Continua gli acquisti</a>
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
        if (typeof BrowserEnabled === "undefined") {
            var BrowserEnabled = true;
        }
        if (!BrowserEnabled) {
            var bsButton = document.getElementById("bsButton");
            if (bsButton) {
                bsButton.innerHTML = "HTML5 is not suported by your browser!";
            }
        }
    </script>

    <asp:Literal ID="litGoogleSurveyOptIn" runat="server"></asp:Literal>
</asp:Content>

<asp:Content ID="ScriptsContent" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script type="text/javascript">
        (function () {
            function setFeedback(root, text) {
                var feedback = root ? root.querySelector('.ks-copy-feedback') : null;
                if (feedback) {
                    feedback.textContent = text;
                    window.setTimeout(function () { feedback.textContent = ''; }, 2500);
                }
            }

            document.addEventListener('click', function (event) {
                var printButton = event.target.closest('[data-action="print-order"]');
                if (printButton) {
                    event.preventDefault();
                    window.print();
                    return;
                }

                var copyButton = event.target.closest('[data-action="copy-order"]');
                if (!copyButton) return;

                event.preventDefault();
                var root = copyButton.closest('.ks-order-confirmation');
                var value = copyButton.getAttribute('data-order-number') || '';
                if (!value) return;

                if (navigator.clipboard && navigator.clipboard.writeText) {
                    navigator.clipboard.writeText(value).then(function () {
                        setFeedback(root, 'Numero ordine copiato.');
                    }).catch(function () {
                        setFeedback(root, 'Seleziona e copia manualmente il numero ordine.');
                    });
                } else {
                    setFeedback(root, 'Seleziona e copia manualmente il numero ordine.');
                }
            });
        })();
    </script>
</asp:Content>
