<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeFeaturedProducts.ascx.vb" Inherits="HomeFeaturedProducts" %>

<div class="ks-home-featured">
    <!-- Scelti per te / Vetrina -->
    <asp:Panel ID="pnlVetrina" runat="server" CssClass="tf-sp-2 pt-0" Visible="true">
        <div class="container">
            <div class="d-flex align-items-end justify-content-between flex-wrap gap-3 mb-3">
                <h2 class="title fw-semibold mb-0">Scelti per te</h2>
                <a class="tf-btn btn-line btn-sm" href="articoli.aspx">Vai al catalogo</a>
            </div>

            <asp:Repeater ID="Data_UltimiArrivi" runat="server" DataSourceID="SdsArticoliInVetrina">
                <HeaderTemplate><div class="row g-3"></HeaderTemplate>
                <ItemTemplate>
                    <div class="col-6 col-md-4 col-xl-3">
                        <div class="card-product ks-card-product">
                            <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                <img class="lazyload img-product" data-src='<%# Eval("img1") %>' src='<%# Eval("img1") %>' alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'/>
                            </a>
                            <div class="card-product-info p-2">
                                <div class="body-small text-main-2">Cod. <%# Server.HtmlEncode(Convert.ToString(Eval("Codice"))) %></div>
                                <a class="title body-md-2 fw-semibold d-block mt-1" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                </a>
                                <div class="price-wrap fw-medium mt-1">
                                    <%# UiPriceFormatter.RenderPriceHtml( If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")), If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")), If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")), If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")), Session("IvaTipo") ) %>
                                </div>
                            </div>
                        </div>
                    </div>
                </ItemTemplate>
                <FooterTemplate></div></FooterTemplate>
            </asp:Repeater>
        </div>
    </asp:Panel>

    <!-- Novità -->
    <asp:Panel ID="pnlNovita" runat="server" CssClass="tf-sp-2 pt-0" Visible="true">
        <div class="container">
            <h2 class="title fw-semibold mb-3">Novità</h2>
            <asp:Repeater ID="Repeat_Lista_Nuovi_Arrivi" runat="server" DataSourceID="SdsNewArticoli">
                <HeaderTemplate><div class="row g-3"></HeaderTemplate>
                <ItemTemplate>
                    <div class="col-6 col-md-4 col-xl-3">
                        <div class="card-product ks-card-product">
                            <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                <img class="lazyload img-product" data-src='<%# Eval("img1") %>' src='<%# Eval("img1") %>' alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'/>
                            </a>
                            <div class="card-product-info p-2">
                                <div class="body-small text-main-2">Cod. <%# Server.HtmlEncode(Convert.ToString(Eval("Codice"))) %></div>
                                <a class="title body-md-2 fw-semibold d-block mt-1" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                </a>
                                <div class="price-wrap fw-medium mt-1">
                                    <%# UiPriceFormatter.RenderPriceHtml( If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")), If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")), If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")), If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")), Session("IvaTipo") ) %>
                                </div>
                            </div>
                        </div>
                    </div>
                </ItemTemplate>
                <FooterTemplate></div></FooterTemplate>
            </asp:Repeater>
        </div>
    </asp:Panel>

    <!-- I più venduti -->
    <asp:Panel ID="pnlBest" runat="server" CssClass="tf-sp-2 pt-0" Visible="true">
        <div class="container">
            <h2 class="title fw-semibold mb-3">I più venduti</h2>
            <asp:Repeater ID="Data_Piu_Acquistati" runat="server" DataSourceID="sdsPiuAcquistati">
                <HeaderTemplate><div class="row g-3"></HeaderTemplate>
                <ItemTemplate>
                    <div class="col-6 col-md-4 col-xl-3">
                        <div class="card-product ks-card-product">
                            <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                <img class="lazyload img-product" data-src='<%# Eval("img1") %>' src='<%# Eval("img1") %>' alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'/>
                            </a>
                            <div class="card-product-info p-2">
                                <div class="body-small text-main-2">Cod. <%# Server.HtmlEncode(Convert.ToString(Eval("Codice"))) %></div>
                                <a class="title body-md-2 fw-semibold d-block mt-1" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                </a>
                                <div class="price-wrap fw-medium mt-1">
                                    <%# UiPriceFormatter.RenderPriceHtml( If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")), If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")), If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")), If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")), Session("IvaTipo") ) %>
                                </div>
                            </div>
                        </div>
                    </div>
                </ItemTemplate>
                <FooterTemplate></div></FooterTemplate>
            </asp:Repeater>
        </div>
    </asp:Panel>

    <!-- DataSources: restano qui per mantenere il contratto con Default.aspx.vb (FindCtrl). -->
    <asp:SqlDataSource ID="SdsNewArticoli" runat="server"></asp:SqlDataSource>
    <asp:SqlDataSource ID="SdsArticoliInVetrina" runat="server"></asp:SqlDataSource>
    <asp:SqlDataSource ID="sdsPiuAcquistati" runat="server"></asp:SqlDataSource>
</div>
