<%@ Control Language="VB" AutoEventWireup="false" CodeFile="MiniCart.ascx.vb" Inherits="MiniCart" %>

<div class="offcanvas offcanvas-end popup-style popup-shopping-cart" tabindex="-1" id="ksMiniCartCanvas" aria-labelledby="ksMiniCartLabel">
    <div class="canvas-header">
        <div class="ks-mini-cart-heading">
            <h5 class="title fw-semibold" id="ksMiniCartLabel">Il tuo carrello</h5>
            <p>Rivedi gli articoli prima di continuare.</p>
        </div>
        <button type="button" class="icon-close icon-close-popup link ks-mini-cart-close" data-bs-dismiss="offcanvas" aria-label="Chiudi"></button>
    </div>

    <div class="ks-mini-cart-content">
        <asp:PlaceHolder ID="phMiniCartEmpty" runat="server" Visible="false">
            <div class="offcanvas-body">
                <div class="minicart-empty text-center">
                    <span class="ks-mini-empty-icon icon-shop-cart-1" aria-hidden="true"></span>
                    <h6>Il tuo carrello è vuoto</h6>
                    <p>Scegli i prodotti dal catalogo: li ritroverai qui.</p>
                    <a class="tf-btn btn-fill w-100" href="articoli.aspx">Vai al catalogo</a>
                </div>
            </div>
        </asp:PlaceHolder>

        <asp:PlaceHolder ID="phMiniCartList" runat="server" Visible="false">
            <div class="offcanvas-body">
                <div class="ks-mini-cart-toolbar">
                    <span>Articoli nel carrello</span>
                    <asp:Literal ID="litMiniClearCart" runat="server" />
                </div>

                <asp:Repeater ID="rptMiniCart" runat="server">
                    <ItemTemplate>
                        <article class="ks-mini-cart-item">
                            <a class="flex-shrink-0 ks-mini-product-link" href='<%# GetProductUrl(Eval("ArticoliId"), Eval("TCId")) %>' aria-label="Vai al prodotto">
                                <img class="rounded ks-mini-product-image" src='<%# GetProductImg(Eval("Img1")) %>' alt="" />
                            </a>

                            <div class="ks-mini-cart-info">
                                <a class="link ks-mini-product-title" href='<%# GetProductUrl(Eval("ArticoliId"), Eval("TCId")) %>'>
                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                </a>

                                <div class="ks-mini-quantity">Quantità <strong><%# Eval("Qnt") %></strong></div>
                            </div>

                            <div class="ks-mini-remove-wrap">
                                <button type="submit" form="ksNativeCartForm" name="ksCartAction" value='<%# BuildRemoveCartActionValue(Eval("Id")) %>'
                                    class="btn btn-sm btn-outline-secondary ks-mini-remove" title="Rimuovi articolo" aria-label="Rimuovi articolo"><span class="icon-close" aria-hidden="true"></span><span class="visually-hidden">Rimuovi articolo</span></button>
                            </div>
                            <dl class="ks-mini-cart-costs">
                                <div>
                                    <dt>Prezzo unitario</dt>
                                    <dd><%# GetUnitPriceText(Eval("Prezzo"), Eval("PrezzoIvato")) %></dd>
                                </div>
                                <div>
                                    <dt>Totale articolo</dt>
                                    <dd><%# GetLineTotalText(Eval("Importo"), Eval("ImportoIvato")) %></dd>
                                </div>
                            </dl>
                        </article>
                    </ItemTemplate>
                </asp:Repeater>
            </div>

            <div class="ks-mini-cart-footer">
                <div class="ks-mini-cart-total">
                    <span>Totale articoli</span>
                    <strong><asp:Label ID="lblMiniCartTotale" runat="server" Text="0,00" /></strong>
                </div>
                <p class="ks-mini-cart-total-note">Spedizione e pagamento nel checkout.</p>

                <a class="tf-btn btn-fill w-100 js-ks-cart-context ks-mini-cart-primary" href="/carrello.aspx" data-ks-cart-full-link>Vai al carrello</a>
                <button class="tf-btn btn-line w-100 ks-mini-cart-continue" type="button" data-bs-dismiss="offcanvas">Continua lo shopping</button>
            </div>
        </asp:PlaceHolder>
    </div>
</div>
