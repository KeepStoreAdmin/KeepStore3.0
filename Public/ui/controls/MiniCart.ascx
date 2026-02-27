<%@ Control Language="VB" AutoEventWireup="false" CodeFile="MiniCart.ascx.vb" Inherits="MiniCart" %>

<li class="nav-cart">
    <a class="link nav-icon-item position-relative" href="#ksMiniCartCanvas" data-bs-toggle="offcanvas" aria-controls="ksMiniCartCanvas" aria-label="Apri carrello">
        <span class="icon">
            <i class="icon icon-cart"></i>
        </span>
        <span class="body-small d-none d-xl-inline">
            <span class="text-secondary">Carrello:</span>
            <strong class="text-secondary"><asp:Label ID="lblCarrelloTotale" runat="server" Text="0,00" /></strong>
        </span>
        <span class="badge bg-primary position-absolute" style="top:-6px; right:-6px;">
            <asp:Label ID="lblCarrelloCount" runat="server" Text="0" />
        </span>
    </a>

    <!-- Offcanvas MiniCart (esteso) -->
    <div class="offcanvas offcanvas-end" tabindex="-1" id="ksMiniCartCanvas" aria-labelledby="ksMiniCartLabel">
        <div class="offcanvas-header">
            <h5 class="offcanvas-title" id="ksMiniCartLabel">Carrello</h5>
            <button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="Chiudi"></button>
        </div>

        <div class="offcanvas-body">
            <asp:PlaceHolder ID="phMiniCartEmpty" runat="server" Visible="false">
                <p class="mb-3">Il carrello è vuoto.</p>
                <a class="tf-btn btn-fill w-100" href="articoli.aspx">Vai al catalogo</a>
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

                                <div class="small text-muted">Q.tà: <%# Eval("Qnt") %></div>
                                <div class="small">Totale riga: <%# GetLineTotalText(Eval("Importo"), Eval("ImportoIvato")) %></div>
                            </div>

                            <div class="text-end">
                                <asp:LinkButton ID="lbRemove" runat="server" CommandName="Remove" CommandArgument='<%# Eval("Id") %>'
                                    CssClass="btn btn-sm btn-outline-secondary" CausesValidation="False" Text="×" ToolTip="Rimuovi" />
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
</li>
