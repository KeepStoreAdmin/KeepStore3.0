<%@ Control Language="VB" AutoEventWireup="false" CodeFile="MiniCart.ascx.vb" Inherits="MiniCart" %>

<div class="offcanvas offcanvas-end popup-style popup-shopping-cart" tabindex="-1" id="ksMiniCartCanvas" aria-labelledby="ksMiniCartLabel">
    <div class="canvas-header">
        <h5 class="title fw-semibold" id="ksMiniCartLabel">Carrello</h5>
        <span class="icon-close icon-close-popup link" data-bs-dismiss="offcanvas" aria-label="Chiudi"></span>
    </div>

    <div class="offcanvas-body">
        <asp:PlaceHolder ID="phMiniCartEmpty" runat="server" Visible="false">
            <div class="minicart-empty text-center">
                <p class="mb-3">Il carrello e' vuoto.</p>
                <a class="tf-btn btn-fill w-100" href="articoli.aspx">Vai al catalogo</a>
            </div>
        </asp:PlaceHolder>

        <asp:PlaceHolder ID="phMiniCartList" runat="server" Visible="false">
            <div class="d-flex justify-content-between align-items-center mb-2">
                <span class="text-muted small">Articoli nel carrello</span>
                <asp:LinkButton ID="lbClearCart" runat="server" CssClass="link small text-decoration-underline" CausesValidation="False" OnClick="lbClearCart_Click" Text="Svuota" />
            </div>

            <asp:Repeater ID="rptMiniCart" runat="server" OnItemCommand="rptMiniCart_ItemCommand">
                <ItemTemplate>
                    <div class="d-flex gap-3 align-items-start py-2 border-bottom">
                        <a class="flex-shrink-0" href='<%# GetProductUrl(Eval("ArticoliId"), Eval("TCId")) %>' aria-label="Vai al prodotto">
                            <img class="rounded" style="width:64px;height:64px;object-fit:contain;" src='<%# GetProductImg(Eval("Img1")) %>' alt="" />
                        </a>

                        <div class="flex-grow-1">
                            <a class="link fw-semibold d-block mb-1" href='<%# GetProductUrl(Eval("ArticoliId"), Eval("TCId")) %>'>
                                <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                            </a>

                            <div class="small text-muted">Q.ta: <%# Eval("Qnt") %></div>
                            <div class="small">Prezzo: <%# GetUnitPriceText(Eval("Prezzo"), Eval("PrezzoIvato")) %></div>
                            <div class="small">Totale riga: <%# GetLineTotalText(Eval("Importo"), Eval("ImportoIvato")) %></div>
                        </div>

                        <div class="text-end">
                            <asp:LinkButton ID="lbRemove" runat="server" CommandName="Remove" CommandArgument='<%# Eval("Id") %>'
                                CssClass="btn btn-sm btn-outline-secondary" CausesValidation="False" Text="x" ToolTip="Rimuovi" />
                        </div>
                    </div>
                </ItemTemplate>
            </asp:Repeater>

            <div class="mt-3">
                <div class="d-flex justify-content-between mb-2">
                    <span class="fw-semibold">Totale</span>
                    <span class="fw-semibold"><asp:Label ID="lblMiniCartTotale" runat="server" Text="0,00" /></span>
                </div>

                <a class="tf-btn btn-fill w-100 mb-2" href="carrello.aspx">Vai al carrello</a>
                <a class="tf-btn btn-line w-100" href="articoli.aspx">Continua lo shopping</a>
            </div>
        </asp:PlaceHolder>
    </div>
</div>
