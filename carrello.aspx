<%@ Page Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="carrello.aspx.vb" Inherits="carrello" Debug="false"%>

<%@ Register Assembly="ConwayControls" Namespace="ConwayControls.Web" TagPrefix="ccwc" %>




<asp:Content ID="ContentHead" ContentPlaceHolderID="HeadContent" runat="server">
        <!-- Tema: assets loaded in MasterPage -->
            <script src="/Public/assets/keepstore/js/cart-ui.js" defer></script>
    <script src="/Public/assets/keepstore/js/checkout-ui.js" defer></script>


<script type="text/javascript">
        (function(){
            function normalizeCartImage(img){
                if(!img) return;
                var original = img.getAttribute("src") || "";
                if(!original) return;
                var filename = original.split("?")[0].split("#")[0].split("/").pop();
                if(!filename) return;
                var clean = filename.replace(/^_+/, "");
                var low = "/Public/assets/images/articoli/_" + clean;
                var normal = "/Public/assets/images/articoli/" + clean;
                var step = 0;
                img.onerror = function(){
                    step++;
                    if(step === 1){ img.src = normal; img.setAttribute("data-src", normal); return; }
                    img.onerror = null;
                    img.src = original;
                };
                img.setAttribute("data-src", low);
                img.src = low;
            }
            window.ksNormalizeCartProductImages = function(){
                document.querySelectorAll('.tf-cart-item_product img, .cart-info img').forEach(normalizeCartImage);
            };
            document.addEventListener('DOMContentLoaded', window.ksNormalizeCartProductImages);
        })();
    </script>


</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">

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
                                <asp:ImageButton runat="server" ID="ImgBtnDestinazioneSi" ImageUrl="/Public/assets/images/ico/modalok.svg" TITLE="SI" STYLE="cursor:pointer;" />
                                &nbsp;
                                <asp:ImageButton runat="server" ID="ImgBtnDestinazioneNo" ImageUrl="/Public/assets/images/ico/modalno.svg" TITLE="NO" STYLE="cursor:pointer;" />
                            </p>
                        </div>
                    </div>
                    
                </div>
            </div>
        </asp:Panel>
        <asp:LinkButton ID="dummy2" runat="server"></asp:LinkButton>


    <!-- NOTE: rimosso frammento di markup corrotto rimasto da una migrazione precedente (carattere di controllo). -->

    <section class="s-shoping-cart tf-sp-2">
        <div class="container">

            <div class="checkout-status tf-sp-2 pt-0">
                <div class="checkout-status-wrap">
                    <div class="checkout-status-list">
                        <div class="checkout-status-item active">
                            <span class="icon"><i class="icon icon-bag"></i></span>
                            <span class="text">Carrello</span>
                        </div>
                        <div class="checkout-status-item">
                            <span class="icon"><i class="icon icon-credit-card"></i></span>
                            <span class="text">Checkout</span>
                        </div>
                        <div class="checkout-status-item">
                            <span class="icon"><i class="icon icon-check"></i></span>
                            <span class="text">Conferma</span>
                        </div>
                    </div>
                </div>
            </div>

            <div class="heading-section mb-3">
                <h3 class="heading">Il tuo carrello</h3>
                <div class="body-text-3">
                    <asp:Label ID="lblArticoli" runat="server" Text="" Font-Bold="true" ForeColor="#E12825"></asp:Label>
                    <asp:Label ID="lblPresenti" runat="server" Text=""></asp:Label>
                </div>
                <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label>
            </div>

            <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                EnableViewState="False" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                SelectCommand="SELECT vcarrello.id, vcarrello.LoginId, vcarrello.SessionId, vcarrello.DataOra, vcarrello.ArticoliId, vcarrello.Codice, vcarrello.Descrizione1, vcarrello.Qnt, vcarrello.NListino, vcarrello.OfferteDettaglioID, vcarrello.Ean, vcarrello.Descrizione2, vcarrello.UmID, vcarrello.MarcheId, vcarrello.MarcheDescrizione, vcarrello.MarcheOrdinamento, vcarrello.iva, vcarrello.Peso, vcarrello.PesoRiga, vcarrello.Img1, vcarrello.Giacenza, vcarrello.InOrdine, vcarrello.Disponibilita, vcarrello.Impegnata, vcarrello.ScortaMinima, vcarrello.Prezzo, vcarrello.PrezzoIvato, vcarrello.Importo, vcarrello.ImportoIvato, articoli.SpedizioneGratis_Listini, articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine FROM vcarrello LEFT OUTER JOIN articoli ON vcarrello.ArticoliId = articoli.id WHERE (articoli.SpedizioneGratis_Listini IS NULL) ORDER BY vcarrello.id"
                DeleteCommand="delete from carrello where (Id = ?Id)"
                UpdateCommand="update carrello set qnt = ?Qnt where (Id = ?Id)">
            </asp:SqlDataSource>

            <asp:SqlDataSource ID="sdsArticoli_Spedizione_Gratis" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                EnableViewState="False" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                SelectCommand="SELECT vcarrello.id, vcarrello.LoginId, vcarrello.SessionId, vcarrello.DataOra, vcarrello.ArticoliId, vcarrello.Codice, vcarrello.Descrizione1, vcarrello.Qnt, vcarrello.NListino, vcarrello.OfferteDettaglioID, vcarrello.Ean, vcarrello.Descrizione2, vcarrello.UmID, vcarrello.MarcheId, vcarrello.MarcheDescrizione, vcarrello.MarcheOrdinamento, vcarrello.iva, vcarrello.Valoreiva, vcarrello.Peso, vcarrello.PesoRiga, vcarrello.Img1, vcarrello.Giacenza, vcarrello.InOrdine, vcarrello.Disponibilita, vcarrello.Impegnata, vcarrello.ScortaMinima, vcarrello.Prezzo, vcarrello.PrezzoIvato, vcarrello.Importo, vcarrello.ImportoIvato, articoli.SpedizioneGratis_Listini, articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine FROM vcarrello LEFT OUTER JOIN articoli ON vcarrello.ArticoliId = articoli.id WHERE (articoli.SpedizioneGratis_Listini IS NOT NULL) ORDER BY vcarrello.id"
                DeleteCommand="delete from carrello where (Id = ?Id)"
                UpdateCommand="update carrello set qnt = ?Qnt where (Id = ?Id)">
            </asp:SqlDataSource>
<div class="row g-4">
                <div class="col-12">
                    <div class="overflow-x-auto">
                        <table class="tf-table-page-cart">
                    <thead>
                        <tr>
                            <th>Prodotto</th>
                            <th>Prezzo</th>
                            <th>Q.tà</th>
                            <th>Totale</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>

                        <!-- Sezione degli Articoli Spediti GRATIS -->
                        <asp:Repeater ID="gvArticoliGratis" runat="server" DataSourceID="sdsArticoli_Spedizione_Gratis" OnItemCommand="gvArticoliGratis_ItemCommand">
                            <ItemTemplate>
                                <tr class="tf-cart-item">
                                    <td class="tf-cart-item_product">
                                        <asp:HyperLink ID="HyperLink3" runat="server" CssClass="img-box" NavigateUrl='<%# "~/articolo.aspx?id=" & Eval("articoliid") & "&TCid=" & Eval("TCid") %>'>
                                            <asp:Image ID="Image2" runat="server" ImageUrl='<%# checkImg(Eval("img1")) %>' AlternateText="" />
                                        </asp:HyperLink>
                                        <div class="cart-info">
                                            <asp:HyperLink ID="HyperLink5" runat="server" CssClass="cart-title body-md-2 fw-semibold link" NavigateUrl='<%# "~/articolo.aspx?id=" & Eval("articoliid") & "&TCid=" & Eval("TCid") %>'>
                                                <span class="ks-cart-title">
                                                    <asp:Label ID="Label2" runat="server" Text='<%#: Eval("MarcheDescrizione") %>' CssClass="ks-brand"></asp:Label>
                                                    <span><%# controllaLunghezzaTesto(Eval("Descrizione1"), 60) %></span>
                                                </span>
                                            </asp:HyperLink>

                                            <div class="variant-box">
                                                <p class="body-text-3">Variante:</p>
                                                <asp:Label ID="tagliecolori" runat="server" CssClass="body-text-3" Text='<%#: Eval("taglia") & " " & Eval("colore") %>'></asp:Label>
                                            </div>

                                            <div class="body-text-3 mt-1">
                                                <span>Codice: <asp:Label ID="Label3" runat="server" Text='<%#: Eval("Codice") %>' Font-Bold="true"></asp:Label></span>
                                                <span class="mx-2">|</span>
                                                <span>Disponibilità: <asp:Label ID="lblDispo" runat="server" Text='<%#: Eval("giacenza") %>' Font-Bold="true"></asp:Label></span>
                                            </div>

                                            <span class="ks-cart-badge-free mt-2">Spedizione gratis</span>

                                            <!-- Hidden / technical fields (used by VB code-behind) -->
                                            <asp:TextBox ID="tbArtID" runat="server" Text='<%#: Eval("ArticoliID") %>' Visible="false"></asp:TextBox>
                                            <asp:Label ID="lblIvaReverseCharge" runat="server" Text='<%# stampa_iva_applicata(If(IsDBNull(Eval("DescrizioneEsenzioneIva")), "", Eval("DescrizioneEsenzioneIva")),If(IsDBNull(Eval("DescrizioneIvaRC")), "", Eval("DescrizioneIvaRC"))) %>' Visible="true" Font-Size="7pt"></asp:Label>
                                            <asp:Label ID="lblValoreIva" runat="server" Text='<%#: Eval("Valoreiva") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblidIvaRC" runat="server" Text='<%#: Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblPeso" runat="server" Text='<%#: Eval("PesoRiga") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblArrivo" runat="server" Text="" Visible="False"></asp:Label>
                                            <asp:Label ID="Label7" runat="server" Text='<%#: Eval("Ean") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblImp" runat="server" Text='<%#: Eval("Impegnata")%>' Visible="false"></asp:Label>
                                            <asp:Label ID="lbl" runat="server" Text='<%#: Eval("InOrdine")%>' Visible="false"></asp:Label>
                                            <asp:Image ID="imgDispo" runat="server" Visible="false" />
                                        </div>
                                    </td>

                                    <td data-cart-title="Prezzo" class="tf-cart-item_price">
                                        <p class="cart-price price-text fw-medium">
                                            <asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>'></asp:Label>
                                            <asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>'></asp:Label>
                                        </p>
                                        <p class="body-text-3 text-secondary"><%= IIf(Me.Session("IvaTipo") = 1, "+", "")%>IVA. <%#: Eval("ValoreIva")%>%</p>
                                    </td>

                                    <td data-cart-title="Q.tà" class="tf-cart-item_quantity">
                                        <div class="wg-quantity ks-wg-quantity">
                                            <span class="btn-quantity btn-decrease"><i class="icon icon-minus"></i></span>
                                            <asp:TextBox ID="tbQta" runat="server" Text='<%#: Eval("qnt") %>' CssClass="quantity-product" MaxLength="4" />
                                            <span class="btn-quantity btn-increase"><i class="icon icon-plus"></i></span>
                                        </div>
                                        <div class="mt-2">
                                            <asp:LinkButton ID="LB_Aggiorna" CommandName="Aggiorna" runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" CssClass="link body-text-3">Aggiorna</asp:LinkButton>
                                        </div>
                                        <asp:TextBox ID="tbID" runat="server" Text='<%#: Eval("id") %>' Visible="false" />
                                    </td>

                                    <td data-cart-title="Totale" class="tf-cart-item_total">
                                        <p class="cart-total total-price price-text fw-medium">
                                            <asp:Label ID="lblImportoIvato" runat="server" Text='<%# Bind("ImportoIvato", "{0:C}") %>'></asp:Label>
                                            <asp:Label ID="lblImporto" runat="server" Text='<%# Bind("Importo", "{0:C}") %>' Visible="false"></asp:Label>
                                        </p>
                                    </td>

                                    <td class="remove-cart">
                                        <asp:LinkButton ID="LB_Delete" CommandName="Elimina" CommandArgument='<%#: Eval("id") %>' runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" CssClass="link" Text="<i class='icon icon-close'></i>"></asp:LinkButton>
                                    </td>
                                </tr>

                                <tr class="ks-cart-item-promo">
                                    <td colspan="5">
                                        <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                            SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino GROUP BY offerteQntMinima, offerteMultipli, nlistino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                                            <SelectParameters>
                                                <asp:ControlParameter Name="ID" ControlID="tbArtID" PropertyName="Text" Type="Int32" />
                                                <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                                            </SelectParameters>
                                        </asp:SqlDataSource>

                                        <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                                            <ItemTemplate>
                                                <div style="display:none;">
                                                    <asp:Label ID="lblQtaMin" runat="server" Text='<%#: Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblMultipli" runat="server" Text='<%#: Eval("OfferteMultipli") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%#: Eval("PrezzoPromo") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%#: Eval("PrezzoPromoIvato") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblInOfferta" runat="server" Text='<%#: Eval("InOfferta") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblDataInizio" runat="server" Text='<%#: Eval("OfferteDataInizio") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblDataFine" runat="server" Text='<%#: Eval("OfferteDataFine") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblidIvaRC" runat="server" Text='<%#: Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                                    <asp:Label ID="lblValoreIvaRC" runat="server" Text='<%#: Eval("ValoreIvaRC") %>' Visible="False"></asp:Label>
                                                </div>
                                                <div style="<%# iif(Eval("InOfferta")=1,"","display:none;") %>">
                                                    <span class="ks-promo-badge">
                                                        <strong>PROMO</strong>
                                                        <asp:Label ID="lblOfferta" runat="server" Visible="false" Text='<%# "PROMO FINO AL " & Eval("OfferteDataFine") %>'></asp:Label>
                                                    </span>
                                                </div>
                                            </ItemTemplate>
                                        </asp:Repeater>
                                    </td>
                                </tr>
                            </ItemTemplate>
                        </asp:Repeater>

                        <!-- Sezione degli Articoli normali, senza spedizione Gratis -->
                        <asp:Repeater ID="Repeater1" runat="server" DataSourceID="sdsArticoli" OnItemCommand="Repeater1_ItemCommand">
                            <ItemTemplate>
                                <tr class="tf-cart-item">
                                    <td class="tf-cart-item_product">
                                        <asp:HyperLink ID="HyperLink3" runat="server" CssClass="img-box" NavigateUrl='<%# "~/articolo.aspx?id=" & Eval("articoliid") & "&TCid=" & Eval("TCid") %>'>
                                            <asp:Image ID="Image2" runat="server" ImageUrl='<%# checkImg(Eval("img1")) %>' AlternateText="" />
                                        </asp:HyperLink>
                                        <div class="cart-info">
                                            <asp:HyperLink ID="HyperLink5" runat="server" CssClass="cart-title body-md-2 fw-semibold link" NavigateUrl='<%# "~/articolo.aspx?id=" & Eval("articoliid") & "&TCid=" & Eval("TCid") %>'>
                                                <span class="ks-cart-title">
                                                    <asp:Label ID="Label2" runat="server" Text='<%#: Eval("MarcheDescrizione") %>' CssClass="ks-brand"></asp:Label>
                                                    <span><%# controllaLunghezzaTesto(Eval("Descrizione1"), 60) %></span>
                                                </span>
                                            </asp:HyperLink>

                                            <div class="variant-box">
                                                <p class="body-text-3">Variante:</p>
                                                <asp:Label ID="tagliecolori" runat="server" CssClass="body-text-3" Text='<%#: Eval("taglia") & " " & Eval("colore") %>'></asp:Label>
                                            </div>

                                            <div class="body-text-3 mt-1">
                                                <span>Codice: <asp:Label ID="Label3" runat="server" Text='<%#: Eval("Codice") %>' Font-Bold="true"></asp:Label></span>
                                                <span class="mx-2">|</span>
                                                <span>Disponibilità: <asp:Label ID="lblDispo" runat="server" Text='<%#: Eval("giacenza") %>' Font-Bold="true"></asp:Label></span>
                                            </div>

                                            <!-- Hidden / technical fields (used by VB code-behind) -->
                                            <asp:TextBox ID="tbArtID" runat="server" Text='<%#: Eval("ArticoliID") %>' Visible="false"></asp:TextBox>
                                            <asp:Label ID="lblIvaReverseCharge" runat="server" Text='<%# stampa_iva_applicata(If(IsDBNull(Eval("DescrizioneEsenzioneIva")), "", Eval("DescrizioneEsenzioneIva")),If(IsDBNull(Eval("DescrizioneIvaRC")), "", Eval("DescrizioneIvaRC"))) %>' Visible="true" Font-Size="7pt"></asp:Label>
                                            <asp:Label ID="lblValoreIva" runat="server" Text='<%#: Eval("Valoreiva") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblidIvaRC" runat="server" Text='<%#: Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblPeso" runat="server" Text='<%#: Eval("PesoRiga") %>' Visible="False"></asp:Label>
                                            <asp:Label ID="lblArrivo" runat="server" Text="" Visible="False"></asp:Label>
                                            <asp:Label ID="Label7" runat="server" Text='<%#: Eval("Ean") %>' Visible="false"></asp:Label>
                                            <asp:Label ID="lblImp" runat="server" Text='<%#: Eval("Impegnata")%>' Visible="false"></asp:Label>
                                            <asp:Label ID="lbl" runat="server" Text='<%#: Eval("InOrdine")%>' Visible="false"></asp:Label>
                                            <asp:Image ID="imgDispo" runat="server" Visible="false" />
                                        </div>
                                    </td>

                                    <td data-cart-title="Prezzo" class="tf-cart-item_price">
                                        <p class="cart-price price-text fw-medium">
                                            <asp:Label ID="lblPrezzoIvato" runat="server" Text='<%#: Eval("PrezzoIvato") %>'></asp:Label>
                                            <asp:Label ID="lblPrezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>'></asp:Label>
                                        </p>
                                        <p class="body-text-3 text-secondary"><%= IIf(Me.Session("IvaTipo") = 1, "+", "")%>IVA. <%#: Eval("ValoreIva")%>%</p>
                                    </td>

                                    <td data-cart-title="Q.tà" class="tf-cart-item_quantity">
                                        <div class="wg-quantity ks-wg-quantity">
                                            <span class="btn-quantity btn-decrease"><i class="icon icon-minus"></i></span>
                                            <asp:TextBox ID="tbQta" runat="server" Text='<%#: Eval("qnt") %>' CssClass="quantity-product" MaxLength="4" />
                                            <span class="btn-quantity btn-increase"><i class="icon icon-plus"></i></span>
                                        </div>
                                        <div class="mt-2">
                                            <asp:LinkButton ID="LB_Aggiorna" CommandName="Aggiorna" runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" CssClass="link body-text-3">Aggiorna</asp:LinkButton>
                                        </div>
                                        <asp:TextBox ID="tbID" runat="server" Text='<%#: Eval("id") %>' Visible="false" />
                                    </td>

                                    <td data-cart-title="Totale" class="tf-cart-item_total">
                                        <p class="cart-total total-price price-text fw-medium">
                                            <asp:Label ID="lblImportoIvato" runat="server" Text='<%# Bind("ImportoIvato", "{0:C}") %>'></asp:Label>
                                            <asp:Label ID="lblImporto" runat="server" Text='<%# Bind("Importo", "{0:C}") %>' Visible="false"></asp:Label>
                                        </p>
                                    </td>

                                    <td class="remove-cart">
                                        <asp:LinkButton ID="LB_Delete" CommandName="Elimina" CommandArgument='<%#: Eval("id") %>' runat="server" CausesValidation="false" PostBackUrl="carrello.aspx" CssClass="link" Text="<i class='icon icon-close'></i>"></asp:LinkButton>
                                    </td>
                                </tr>

                                <tr class="ks-cart-item-promo">
                                    <td colspan="5">
                                        <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                            SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino GROUP BY offerteQntMinima, offerteMultipli, nlistino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                                            <SelectParameters>
                                                <asp:ControlParameter Name="ID" ControlID="tbArtID" PropertyName="Text" Type="Int32" />
                                                <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                                            </SelectParameters>
                                        </asp:SqlDataSource>

                                        <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                                            <ItemTemplate>
                                                <div style="display:none;">
                                                    <asp:Label ID="lblQtaMin" runat="server" Text='<%#: Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblMultipli" runat="server" Text='<%#: Eval("OfferteMultipli") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%#: Eval("PrezzoPromo") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%#: Eval("PrezzoPromoIvato") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblInOfferta" runat="server" Text='<%#: Eval("InOfferta") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblDataInizio" runat="server" Text='<%#: Eval("OfferteDataInizio") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblDataFine" runat="server" Text='<%#: Eval("OfferteDataFine") %>' Visible="false"></asp:Label>
                                                    <asp:Label ID="lblidIvaRC" runat="server" Text='<%#: Eval("IdIvaRC") %>' Visible="False"></asp:Label>
                                                    <asp:Label ID="lblValoreIvaRC" runat="server" Text='<%#: Eval("ValoreIvaRC") %>' Visible="False"></asp:Label>
                                                </div>
                                                <div style="<%# iif(Eval("InOfferta")=1,"","display:none;") %>">
                                                    <span class="ks-promo-badge">
                                                        <strong>PROMO</strong>
                                                        <asp:Label ID="lblOfferta" runat="server" Visible="false" Text='<%# "PROMO FINO AL " & Eval("OfferteDataFine") %>'></asp:Label>
                                                    </span>
                                                </div>
                                            </ItemTemplate>
                                        </asp:Repeater>
                                    </td>
                                </tr>
                            </ItemTemplate>
                        </asp:Repeater>

                    </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <div id="Qnt_Errata" runat="server" class="ks-alert ks-alert-danger" visible="false">
                E' stata impostata una quantità articolo minore o uguale a 0.<br />Eliminare l'articolo dal carrello o impostare una quantità maggiore di 0.
            </div>

            <!-- Buono Sconto (dati) -->
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
                            <asp:Label ID="lbl_idBuonoSconto" runat="server" Text='<%#: Eval("id")%>' Visible="false"></asp:Label>
                            <asp:Label ID="lbl_Percentuale_BuonoSconto" runat="server" Text='<%#: Eval("scontoPercentuale")%>' Visible="false"></asp:Label>
                            <asp:Label ID="lbl_scontoFisso_BuonoSconto" runat="server" Text='<%#: Eval("scontoFisso")%>' Visible="false"></asp:Label>
                            <asp:Label ID="lbl_valore_BuonoSconto" runat="server" Text='<%#: Eval("valore")%>' Visible="false"></asp:Label>
                            <asp:Label ID="lbl_ScontoVettore" runat="server" Text='<%#: Eval("scontoVettore")%>' Visible="false"></asp:Label>

                            <div class="ks-discount-card mb-3">
                                <div class="ks-discount-card__header">BUONO SCONTO</div>
                                <div class="ks-discount-card__body">
                                    <div>
                                        <div class="body-md-2 fw-semibold">
                                            <asp:Label ID="lbl_Descrizione1_BuonoSconto" runat="server" Text='<%#: Eval("descrizione1")%>'></asp:Label>
                                        </div>
                                        <div class="body-text-3">
                                            <asp:Label ID="lbl_Descrizione2_BuonoSconto" runat="server" Text='<%#: Eval("descrizione2")%>'></asp:Label>
                                        </div>
                                    </div>
                                    <div class="ks-discount-card__value">
                                        <asp:Label ID="lbl_TotSconto" runat="server" Text=""></asp:Label>
                                    </div>
                                </div>
                                <div class="ks-discount-card__footer">
                                    <asp:LinkButton ID="CancellaBuonoSconto" CommandName="CancellaBuonoSconto" runat="server" CssClass="link">Elimina buono sconto</asp:LinkButton>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
            </asp:GridView>

            <div class="row g-4 ks-cart-bottom">
                <div class="col-12 col-lg-8">
                    <asp:Panel ID="Panel_BuoniSconto" runat="server" HorizontalAlign="left" CssClass="ks-coupon-panel">
                        <div class="mb-2"><b>CODICE SCONTO</b></div>
                        <div class="d-flex gap-2 align-items-center flex-wrap">
                            <asp:TextBox ID="TB_BuonoSconto" runat="server" CssClass="form-control ks-coupon-input"></asp:TextBox>
                            <asp:Button ID="BT_ApplicaBuonoSconto" runat="server" CausesValidation="false" Text="Aggiungi" CssClass="tf-btn btn-gray" />
                        </div>
                        <div class="mt-2">
                            <asp:Image ID="checkOKBuonoSconto" runat="server" ImageUrl="Public/Images/Ok.png" Height="30px" Visible="false" />
                            <asp:Image ID="checkNOBuonoSconto" runat="server" ImageUrl="Public/Images/Remove.png" Height="30px" Visible="false" />
                            <asp:Label ID="lblBuonoScontoConvalida" runat="server" Text=""></asp:Label>
                            <asp:LinkButton ID="LB_CancelBuonoSconto" runat="server" CssClass="link" ForeColor="Red" Visible="false">Elimina codice</asp:LinkButton>
                        </div>
                    </asp:Panel>

                    <!-- Hidden technical fields used by VB -->
                    <asp:TextBox ID="tbVettoriId" runat="server" ToolTip="VettoriId" Style="display:none" Width="20px"></asp:TextBox>
                    <asp:TextBox ID="tbPagamenti" runat="server" ToolTip="PagamentiId" Style="display:none" Width="20px"></asp:TextBox>
                    <asp:TextBox ID="tbShopIdGestPay" runat="server" ToolTip="tShopIdGestPay" Style="display:none" Width="20px"></asp:TextBox>
                    <asp:TextBox ID="tbContrPerc" runat="server" ToolTip="Contrassegno Percentuale" Style="display:none" Width="20px"></asp:TextBox>
                    <asp:TextBox ID="tbContrFisso" runat="server" ToolTip="Contrassegno Fisso" Style="display:none" Width="20px"></asp:TextBox>
                    <asp:TextBox ID="tbContrMinimo" runat="server" ToolTip="Contrassegno Minimo" Style="display:none" Width="20px"></asp:TextBox>
                    <asp:TextBox ID="tbPeso" runat="server" Width="20px" Style="display:none" ToolTip="Peso"></asp:TextBox>
                    <asp:TextBox ID="tbTotale" runat="server" Width="20px" Style="display:none" ToolTip="Totale"></asp:TextBox>
                </div>

                <div class="col-12 col-lg-4">
                    <div class="tf-page-cart-footer">
                        <div class="tf-cart-summery">
                            <h4 class="title">Riepilogo</h4>
                        <table width="100%" id="TableConteggi" runat="server" visible="false" class="ks-summary-table">
                            <tr>
                                <td align="right">Imponibile:</td>
                                <td align="right"><asp:Label ID="lblImponibile" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
                            </tr>
                            <tr>
                                <td align="right">Spedizione:</td>
                                <td align="right"><asp:Label ID="lblSpeseSped" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
                            </tr>
                            <tr>
                                <td align="right">Assicurazione:</td>
                                <td align="right"><asp:Label ID="lblSpeseAss" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
                            </tr>
                            <tr>
                                <td align="right">IVA:</td>
                                <td align="right"><asp:Label ID="lblIva" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
                            </tr>
                            <tr>
                                <td align="right">Pagamento:</td>
                                <td align="right"><asp:Label ID="lblPagamento" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
                            </tr>
                            <tr>
                                <td align="right">Buono Sconto:</td>
                                <td align="right"><asp:Label ID="lblBuonoSconto" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
                            </tr>
                            <tr>
                                <td align="right">Buono Sconto IVA:</td>
                                <td align="right"><asp:Label ID="lblBuonoScontoIVA" runat="server" Text="&#8364; 0,00" Font-Bold="true"></asp:Label></td>
                            </tr>
                            <tr>
                                <td align="right"><b>Totale:</b></td>
                                <td align="right"><asp:Label ID="lblTotale" runat="server" Text="&#8364; 0,00" Font-Bold="true" CssClass="ks-total" ></asp:Label></td>
                            </tr>
                        </table>
                        </div>
                    </div>
                </div>
            </div>

            <div ID="canorder" runat="server" class="ks-alert-warning">
                Non sei un utente abilitato a procedere con l'ordine. Contattaci se desideri invece procedere
            </div>

            <div class="ks-cart-buttons">
                <asp:LinkButton ID="btContinua" runat="server" CssClass="tf-btn btn-gray" CausesValidation="false">Continua lo Shopping</asp:LinkButton>
                <asp:LinkButton ID="btAggiorna" runat="server" CssClass="tf-btn btn-gray" CausesValidation="false">Aggiorna Carrello</asp:LinkButton>
                <asp:LinkButton ID="btSvuota" runat="server" CssClass="tf-btn btn-gray" CausesValidation="false">Svuota Carrello</asp:LinkButton>
                <div class="ks-right">
                    <asp:LinkButton ID="btCompleta" runat="server" CssClass="tf-btn" CausesValidation="false">Procedi con l'ordine</asp:LinkButton>
                </div>
            </div>

        </div>
    </section>

<asp:Panel ID="Panel_Unico" runat="server" CssClass="ks-checkout-panel">   
    
    <% If tOrdine IsNot Nothing AndAlso tOrdine.Visible Then %>
    <section class="tf-page-checkout flat-spacing-11 ks-checkout-shell">
        <div class="container">
            <div class="tf-checkout-wrap flex-lg-nowrap">
                <div class="page-checkout">
    <% End If %>
<asp:Panel ID="tOrdine" runat="server" Visible="false" CssClass="ks-checkout">
    <div id="promo_vettori">
    <asp:Panel ID="pSpedizione" runat="server" Width="100%" Visible="true" style="overflow:hidden;" CssClass="wrap">
                <h5 class="title fw-semibold">Spedizione</h5>
<!--<div id="infobar" style="width:100%; color:White; font-weight:bold; height:50px; background-image:url('Public/Images/StepCarrello1.png'); background-size:100%; background-repeat:no-repeat;"></div>-->
<asp:GridView ID="gvVettoriPromo" runat="server"
        AutoGenerateColumns="False" CellPadding="1" DataSourceID="sdsVettoriPromo"
        Font-Size="8pt" GridLines="None" Width="100%" DataKeyNames="id" BorderColor="#383838" BorderStyle="Solid" BorderWidth="2px" CssClass="ks-checkout-grid">
            <Columns>
                <asp:TemplateField ShowHeader="False">
                    <ItemTemplate>
                        <ccwc:RadioButton ID="rbSpedizione" runat="server" AutoPostBack="True" Checked='false'
                            GroupName="spedizione" Value='<%#: Eval("Id") %>' />
                    </ItemTemplate>
                    <ItemStyle HorizontalAlign="Left" VerticalAlign="Middle" />
                </asp:TemplateField>
                <asp:TemplateField InsertVisible="False" SortExpression="id" Visible="False" ShowHeader="False">
                    <EditItemTemplate>
                        <asp:Label ID="Label1" runat="server" Text='<%#: Eval("id") %>'></asp:Label>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblId" runat="server" Text='<%# Bind("id") %>'></asp:Label>
                    </ItemTemplate>
                    <ItemStyle HorizontalAlign="Left" VerticalAlign="Middle" />
                </asp:TemplateField>
                <asp:TemplateField InsertVisible="False" ShowHeader="False">
                     <ItemTemplate>
                        <img src='<%# "Public/Vettori/" & Eval("Img") %>' title='PROMO fino al <%#: Eval("Promo_Data_Fine","{0:d}") %>' alt="" />
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
                        Soglia:<asp:Label ID="lblSogliaMinima" runat="server" Text='<%#: Eval("Soglia_Minima") %>'></asp:Label><br />
                        Peso Max:<asp:Label ID="lblPeso" runat="server" Text='<%#: Eval("PesoMax") %>'></asp:Label><br />
                        Percentuale:<asp:Label ID="lblPercentuale" runat="server" Text='<%#: Eval("Costo_Percentuale") %>'></asp:Label>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField HeaderText="Spesa Minima (IVA incl)">
                    <ItemTemplate>
                        <asp:Label ID="Label2" runat="server" Text='<%# String.Format("{0:c}", Eval("Soglia_Minima")*((Session("Iva_Vettori")/100)+1)) %>'></asp:Label>
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
        <asp:GridView ID="gvVettori" runat="server" AutoGenerateColumns="False" CellPadding="1" DataSourceID="sdsVettori" Font-Size="8pt" GridLines="None" Width="100%" DataKeyNames="id" ShowHeader="False" CssClass="ks-checkout-grid">
            <HeaderStyle Font-Bold="False" Font-Size="8pt" HorizontalAlign="Left" ForeColor="#2050AF" />
            <AlternatingRowStyle BackColor="WhiteSmoke" BorderStyle="None" />
            <Columns>
                <asp:TemplateField HeaderText="Seleziona">
                    <ItemTemplate>
                        <ccwc:radiobutton id="rbSpedizione" runat="server" autopostback="True" checked='false'
                            groupname="spedizione" value='<%#: Eval("Id") %>'></ccwc:radiobutton>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField HeaderText="id" InsertVisible="False" SortExpression="id" Visible="False">
                    <EditItemTemplate>
                        <asp:Label ID="Label1" runat="server" Text='<%#: Eval("id") %>'></asp:Label>
                    </EditItemTemplate>
                    <ItemTemplate>
                        <asp:Label ID="lblId" runat="server" Text='<%# Bind("id") %>'></asp:Label>
                    </ItemTemplate>
                </asp:TemplateField>
                <asp:TemplateField InsertVisible="False" ShowHeader="False">
                     <ItemTemplate>
                        <img class="ml-2" src='<%# "Public/Vettori/" & Eval("Img") %>' title='<%#: Eval("Informazioni") %>' alt="" />
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
                      <ccwc:RadioButton ID="rbSpedizioneGratis" runat="server" AutoPostBack="True" Checked='True'
                      Font-Bold="True" Font-Names="Arial" ForeColor="Red" GroupName="spedizione"
                      Text="" Value='<%#: Eval("Id") %>' />
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
		<div class="row">
			<div class="col-12 col-md-6">
				<asp:Panel ID="pAssicurazione" runat="server" Width="100%"  Visible="true" style="overflow:hidden; margin-bottom: 15px"  CssClass="wrap">
					<h5 class="title fw-semibold">Assicurazione</h5>
                        <div class="d-flex align-items-center justify-content-between gap-3 py-2 flex-wrap">
                            <label class="d-inline-flex align-items-center gap-2 m-0 body-text-3" for="<%= cbAssicurazione.ClientID %>">
                                <asp:CheckBox ID="cbAssicurazione" runat="server" AutoPostBack="True" />
                                <span>Aggiungi assicurazione spedizione</span>
                            </label>
                            <span class="text-primary fw-semibold"><asp:Label ID="lblAssicurazione" runat="server" Text="€ 0,00" /></span>
                        </div>
                        <div class="d-none">
                            <asp:CheckBox ID="cbContrassegno" runat="server" AutoPostBack="True" />
                            <asp:Label ID="lblContrassegno" runat="server" Text="€ 0,00" />
                        </div>
					<table cellpadding="1" width="100%">
					</table>
				</asp:Panel>   
			</div>
			<div class="col-12 col-md-6">
			  <asp:Panel ID="pPagamento" runat="server" Width="99.5%" Visible="true" CssClass="wrap">
					<h5 class="title fw-semibold">Pagamento</h5>
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
					<asp:GridView ID="gvPagamento" runat="server" CssClass="ks-checkout-grid"
					AutoGenerateColumns="False" CellPadding="1" DataSourceID="sdsPagamento"
					Font-Size="8pt" GridLines="None" Width="100%" ShowHeader="False" DataKeyNames="id">
						<Columns>
							<asp:TemplateField HeaderText="sel">
								<ItemTemplate>
									<ccwc:radiobutton id="rbPagamento" runat="server" checked='<%#: Eval("Predefinito") %>'
										groupname="pagamento" value='<%# eval("id") %>' AutoPostBack="True"></ccwc:radiobutton>
								</ItemTemplate>
							</asp:TemplateField>
							<asp:TemplateField>
							<ItemTemplate>
								<img class="ml-2" src='<%# "/Public/assets/images/pagamenti/" & Eval("Img") %>' title='<%#: Eval("Informazioni") %>' alt="" />
							</ItemTemplate>
							</asp:TemplateField>
							<asp:TemplateField HeaderText="id" InsertVisible="False" SortExpression="id" Visible="False">
								<EditItemTemplate>
									<asp:Label ID="Label1" runat="server" Text='<%#: Eval("id") %>'></asp:Label>
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
    <asp:Panel ID="PnlFatturazione" runat="server" Width="100%" Visible="true" style="overflow:hidden;"  CssClass="wrap">
							<h5 class="title fw-semibold">Dati fatturazione</h5>
        <table cellspacing="5" border="0" style="border-bottom-style:solid;" width="100%">
            <tr>
            </tr>
            </tr>  
            <tr>
            </tr> 
            </tr> 
            <tr>
            </tr>
            <tr>
            <tr>
            <tr>
            </tr> 
            <tr>
            <tr>
            </tr>
            <tr>
            <tr>
        </table>
        </asp:Panel>
    <asp:Panel ID="PnlSpedizione" runat="server" Width="100%" Visible="true" style="overflow:hidden;"  CssClass="wrap">
							<h5 class="title fw-semibold">Indirizzo di spedizione</h5>
        <table cellspacing="5" border="0" style="border-bottom-style:solid;" width="100%">
            <tr>
                <td style="text-align:left;" class="carrello-td1-step4"><b>Indirizzi registrati:</b></td>
                <td colspan="2" style="text-align:left;">
                    <asp:DropDownList ID="LstScegliIndirizzo" runat="server" CssClass="form-select ks-form-select" />
                </td>
            </tr>
            <tr>
                <td style="text-align:left;"><b>Ragione Sociale / Cognome:&nbsp;</b></td>
            </tr>
                <td style="text-align:left;"><b>Nome:&nbsp;</b></td>
            </tr>  
            <tr>
                <td style="text-align:left;"><b>Indirizzo:&nbsp;</b></td>
                <td style="text-align:left;"><b>Città:&nbsp;</b></td>
            </tr>
            <tr>
                <td style="text-align:left;"><b>Provincia:&nbsp;</b></td>
                <td style="text-align:left;"><b>CAP:&nbsp;</b></td>
            <tr>
                <td style="text-align:left;"><b>Zona:&nbsp;</b></td>
                <td style="text-align:left;"><b>Telefono:&nbsp;</b></td>
                <td style="text-align:left;"><b>Nota destinazione:&nbsp;</b></td>
            <tr>
            <tr>
        </table>
        </asp:Panel>
		<div id="panel" runat="server" ClientIDMode="Static">
            <asp:Panel ID="PnlDestinazione" runat="server" Width="100%" Visible="True" GroupingText="Inserisci i dati"  CssClass="wrap">
							<h5 class="title fw-semibold">Gestisci destinazione</h5>
				<input type="hidden" runat="server" id="insOmod" ClientIDMode="Static">
				<!--
                <asp:Label ID="LblDescrDest" runat="server" Text=""></asp:Label>
                <br />
                <asp:DropDownList runat="server" ID="LstDestinazione" AutoPostBack="True" Style="width:100%; display:none;"></asp:DropDownList>
                <br />
				-->
                 <table id="tblDestAlter" class="ks-dest-form" cellpadding="1" cellspacing="5" border="0" width="100%" runat="server">
	                    <tr>
	                        <td style="padding: 0 5px;" width="155px">Ragione Sociale&nbsp;/&nbsp;Cognome: *</td>
	                        <td>
	                            <asp:TextBox ID="tbRagioneSocialeA" CssClass="form-control ks-form-control" runat="server" Width="100%" MaxLength="100" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
	                            <asp:requiredfieldvalidator id="RFRagioneSocialeA" runat="server" Display="None" ControlToValidate="tbRagioneSocialeA"
		                       ErrorMessage="Campo Obbligatorio (Ragione Sociale)"></asp:requiredfieldvalidator>
	                        </td>
	                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Nome:</td>
                        <td ><asp:TextBox ID="tbNomeA" CssClass="form-control ks-form-control" runat="server" Width="100%" MaxLength="50" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                        </td>
                    </tr>        
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Indirizzo: *</td>
                        <td ><asp:TextBox ID="tbIndirizzo2" CssClass="form-control ks-form-control" runat="server" Width="100%" MaxLength="100" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                            <asp:requiredfieldvalidator id="RFIndirizzo2" runat="server" Display="None" ControlToValidate="tbIndirizzo2"
		                       ErrorMessage="Campo Obbligatorio (Indirizzo)"></asp:requiredfieldvalidator>
                        </td>
	                    </tr>
	                    <tr>
						<td style="padding: 0 5px;" width="155px">Cap *</td>
						<td>
							<asp:TextBox ID="tbCap2" CssClass="form-control ks-form-control" runat="server" AutoPostBack="true" OnTextChanged="City_Bind_Data2" Width="100%" MaxLength="5" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
							<asp:requiredfieldvalidator id="RFCap2" runat="server" Display="None" ControlToValidate="tbCap2"
						       ErrorMessage="Campo Obbligatorio (CAP)"></asp:requiredfieldvalidator>
						</td>
					</tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Città: *</td>
                        <td ><asp:DropDownList ID="ddlCitta2" CssClass="form-select ks-form-select" onSelectedIndexChanged="Province_Bind_Data2" AutoPostBack="true" runat="server" Width="100%" ValidationGroup="registrazione" CausesValidation="True"></asp:DropDownList>
                             <asp:requiredfieldvalidator id="RFCitta2" runat="server" Display="None" ControlToValidate="ddlCitta2"
		                       ErrorMessage="Campo Obbligatorio (Città)"></asp:requiredfieldvalidator>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Provincia: *</td>
                        <td ><asp:TextBox ID="tbProvincia2" CssClass="form-control ks-form-control" ReadOnly="true" runat="server" Width="100%" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                             <asp:requiredfieldvalidator id="RFProvincia2" runat="server" Display="None" ControlToValidate="tbProvincia2"
		                       ErrorMessage="Campo Obbligatorio (Provincia)"></asp:requiredfieldvalidator>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Zona:</td>
                        <td ><asp:TextBox ID="tbZona" CssClass="form-control ks-form-control" runat="server" Width="100%" MaxLength="100" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px">Telefono: *</td>
                        <td ><asp:TextBox ID="tbTelefono2" CssClass="form-control ks-form-control" runat="server" Width="100%" MaxLength="100" ValidationGroup="registrazione" CausesValidation="True"></asp:TextBox>
                            <asp:requiredfieldvalidator id="RFTelefono2" runat="server" Display="None" ControlToValidate="tbTelefono2"
		                       ErrorMessage="Campo Obbligatorio (Telefono)"></asp:requiredfieldvalidator>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 0 5px;" width="155px" valign="top">Nota destinazione:</td>
                        <td ><asp:TextBox ID="tbNote" CssClass="form-control ks-form-control" runat="server" Width="100%" MaxLength="255" ValidationGroup="registrazione" CausesValidation="True" TextMode="MultiLine" Rows="5"></asp:TextBox>
                        </td>
                    </tr>  
	                    <tr>
                        <td align="center" colspan="2">
                            <asp:Button ID="btnSalvaDest" CssClass="tf-btn btn-gray ks-btn" runat="server" Text="Inserisci nuova destinazione" Height="25px" CausesValidation="true" />
                            <asp:Button ID="btnModDest" CssClass="tf-btn ks-btn" runat="server" Text="Salva modifiche destinazione" Height="25px" CausesValidation="true" />
                            <asp:Button ID="btnElimDest" CssClass="tf-btn btn-danger ks-btn" runat="server" Text="Elimina destinazione" Height="25px" CausesValidation="true" BackColor="#CC0000" ForeColor="White"/>
                            <br /><br /><asp:Button ID="btnAnnullaDest" CssClass="tf-btn btn-gray ks-btn" runat="server" Text="Annulla" Height="25px" CausesValidation="false" />
                        </td>
                    </tr>
                </table>
            </asp:Panel>
			</div>
		<asp:Panel ID="Panel_Note" runat="server" Width="100%" Visible="False" CssClass="wrap">
					<h5 class="title fw-semibold">Note</h5>
				<br/><asp:TextBox ID="txtNoteSpedizione" CssClass="form-control ks-form-control" TextMode="MultiLine" Rows="5" runat="server" Width="100%"></asp:TextBox>
			</asp:Panel>
    <div class="line"></div>
        <div class="wrap">
            <div class="ks-checkout-actions">
                <asp:LinkButton Visible="False" CausesValidation="false" ID="btSalvaPreventivo" runat="server" CssClass="tf-btn btn-gray" OnClientClick="javascript:visualizza_spinner_caricamento();">SALVA PREVENTIVO</asp:LinkButton>
                <%if Session("DESTINAZIONEALTERNATIVA")=0 then %>
                    <asp:LinkButton CausesValidation="false" ID="btInviaOrdine" runat="server" CssClass="tf-btn" OnClientClick="javascript:visualizza_spinner_caricamento();">CONFERMA ORDINE</asp:LinkButton>
                <%else%>
                    <span class="tf-btn btn-gray" style="pointer-events:none;opacity:.6;">CONFERMA ORDINE</span>
                <%end if%>
            </div>
            <div id="spinner_caricamento" style="text-align:center;display:none;padding-top:5px;padding-bottom:5px;">
                <div><b>ATTENDERE L'INVIO AI NOSTRI SERVER</b></div><br />
                <img src="Public/Images/spinner.gif" alt="" />
            </div>
        </div>
</asp:Panel>
    <% If tOrdine IsNot Nothing AndAlso tOrdine.Visible Then %>
                </div>
                <div class="flat-sidebar-checkout">
                    <div class="tf-sidebar-checkout">
                        <div class="sidebar-checkout-content">
                            <div class="sidebar-checkout-header">
                                <h5 class="fw-semibold">Riepilogo ordine</h5>
                            </div>

                            <div class="d-flex justify-content-between mt-3">
                                <span class="fw-medium">Imponibile</span>
                                <span><%= lblImponibile.Text %></span>
                            </div>
                            <div class="d-flex justify-content-between mt-2">
                                <span class="fw-medium">Spedizione</span>
                                <span><%= lblSpeseSped.Text %></span>
                            </div>
                            <div class="d-flex justify-content-between mt-2">
                                <span class="fw-medium">Assicurazione</span>
                                <span><%= lblSpeseAss.Text %></span>
                            </div>
                            <div class="d-flex justify-content-between mt-2">
                                <span class="fw-medium">IVA</span>
                                <span><%= lblIva.Text %></span>
                            </div>
                            <div class="d-flex justify-content-between mt-2">
                                <span class="fw-medium">Pagamento</span>
                                <span><%= lblPagamento.Text %></span>
                            </div>
                            <div class="d-flex justify-content-between mt-2">
                                <span class="fw-medium">Sconto</span>
                                <span><%= lblBuonoSconto.Text %></span>
                            </div>

                            <div class="d-flex justify-content-between mt-3 pt-3 border-top">
                                <span class="fw-semibold">Totale</span>
                                <span class="fw-semibold"><%= lblTotale.Text %></span>
                            </div>

                            <div class="mt-3 body-text-3 text-secondary">
                                Procedendo con l&#39;ordine confermi di aver letto e accettato le condizioni di vendita.
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
    <% End If %>

</asp:Panel> 
<asp:validationsummary id="ValidationSummary1" runat="server" HeaderText="Attenzione!" ShowMessageBox="True" ShowSummary="False"></asp:validationsummary>
		                
    <!--<script type="text/javascript" language="Javascript" src="Public/script/slide.js"> </script> -->
<br />
    <br />
	<!-- Controllo se esiste l'immagine -->

<asp:Panel ID="pLegacyCheckoutBindings" runat="server" Visible="false" style="display:none;">
    <asp:Label ID="lblTab_Cap" runat="server" />
    <asp:Label ID="lblTab_Cell" runat="server" />
    <asp:Label ID="lblTab_CF" runat="server" />
    <asp:Label ID="lblTab_Citta" runat="server" />
    <asp:Label ID="lblTab_Cognome" runat="server" />
    <asp:Label ID="lblTab_Email" runat="server" />
    <asp:Label ID="lblTab_Fax" runat="server" />
    <asp:Label ID="lblTab_Indirizzo" runat="server" />
    <asp:Label ID="lblTab_Nazione" runat="server" />
    <asp:Label ID="lblTab_Nome" runat="server" />
    <asp:Label ID="lblTab_Piva" runat="server" />
    <asp:Label ID="lblTab_Provincia" runat="server" />
    <asp:Label ID="lblTab_RagioneSociale" runat="server" />
    <asp:Label ID="lblTab_SedeLegale" runat="server" />
    <asp:Label ID="lblTab_Tel" runat="server" />
    <asp:Label ID="lblTab_Telefono" runat="server" />
    <asp:Label ID="lblTab_Utente" runat="server" />
    <asp:Label ID="lblTab_mail" runat="server" />
    <asp:Label ID="lblTab_pIva" runat="server" />
    <asp:Label ID="lblTab_Email2" runat="server" />
    <asp:Label ID="lblTab_PIVA" runat="server" />
</asp:Panel>
</asp:Content>


