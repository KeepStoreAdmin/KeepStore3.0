<%@ Page Title="Prodotto" Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" %>

<asp:Content ID="TitleContent1" ContentPlaceHolderID="TitleContent" runat="server">
    <%= If(litNome IsNot Nothing AndAlso Not String.IsNullOrEmpty(litNome.Text), Server.HtmlEncode(litNome.Text), "Prodotto") %>
</asp:Content>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litSeoHead" runat="server" EnableViewState="false" />

    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/vendor/swiper-bundle.min.css") %>" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/vendor/photoswipe.css") %>" />
    <link rel="stylesheet" href="/Public/assets/keepstore/css/keepstore-product.css" />

    <script type="application/ld+json">
        <asp:Literal ID="litJsonLdHead" runat="server" EnableViewState="false" />
    </script>
</asp:Content>

<asp:Content ID="BreadcrumbContent1" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <div class="tf-breadcrumb-wrap">
        <div class="container">
            <ul class="tf-breadcrumb-list">
                <li><a href="/">Home</a></li>
                <li><a href="/articoli.aspx">Catalogo</a></li>
                <li><span class="current"><asp:Literal ID="litBreadcrumbCurrent" runat="server" /></span></li>
            </ul>
        </div>
    </div>
</asp:Content>

<asp:Content ID="MainContent1" ContentPlaceHolderID="MainContent" runat="server">

    <!-- NOT FOUND -->
    <asp:PlaceHolder ID="phNotFound" runat="server" Visible="false">
        <section class="flat-spacing-2">
            <div class="container">
                <div class="alert alert-warning">Prodotto non trovato o non disponibile.</div>
            </div>
        </section>
    </asp:PlaceHolder>

    <!-- PRODUCT DETAIL (Template: Product Detail) -->
    <asp:Panel ID="pnlProduct" runat="server" CssClass="flat-spacing-3 pt-0">
        <div class="container">
            <div class="row g-4">

                <!-- MEDIA -->
                <div class="col-md-6">
                    <div class="tf-product-media-wrap">
                        <div class="tf-product-media-main" data-swiper="product-gallery">
                            <div class="swiper tf-sw-product-media" data-preview="1" data-space="0">
                                <div class="swiper-wrapper">
                                    <asp:Repeater ID="rptMainImages" runat="server">
                                        <ItemTemplate>
                                            <div class="swiper-slide">
                                                <a class="tf-image" href='<%# Eval("Url") %>' data-pswp-width="1200" data-pswp-height="1200">
                                                    <img class="lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Alt"))) %>' src='<%# Eval("Url") %>' />
                                                </a>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>

                        <div class="tf-product-media-thumbs mt-3">
                            <div class="swiper tf-sw-product-media-thumbs" data-preview="5" data-space="10">
                                <div class="swiper-wrapper">
                                    <asp:Repeater ID="rptThumbs" runat="server">
                                        <ItemTemplate>
                                            <div class="swiper-slide">
                                                <div class="tf-image">
                                                    <img class="lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Alt"))) %>' src='<%# Eval("Url") %>' />
                                                </div>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- INFO -->
                <div class="col-md-6">
                    <div class="tf-product-info-wrap position-relative">

                        <div class="tf-product-info-list">
                            <div class="tf-product-info-content">
                                <h3 class="tf-product-info-title">
                                    <asp:Literal ID="litNome" runat="server" />
                                </h3>

                                <div class="text-muted small mb-2">
                                    Codice:
                                    <strong><asp:Literal ID="litCodice" runat="server" /></strong>
                                    <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
                                        <span class="ms-2">EAN: <strong><asp:Literal ID="litEan" runat="server" /></strong></span>
                                    </asp:PlaceHolder>
                                </div>

                                <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
                                    <div class="text-muted small mb-2">
                                        Marca: <asp:HyperLink ID="lnkMarca" runat="server" CssClass="link" />
                                    </div>
                                </asp:PlaceHolder>

                                <asp:PlaceHolder ID="phAvailability" runat="server" Visible="false">
                                    <div class="mb-3">
                                        <asp:Literal ID="litAvailability" runat="server" />
                                    </div>
                                </asp:PlaceHolder>

                                <div class="tf-product-info-price mb-3">
                                    <asp:Literal ID="litPriceHtml" runat="server" />
                                </div>

                                <asp:Literal ID="litShortDesc" runat="server" />
                            </div>
                        </div>

                        <!-- CHOOSE OPTION / BUY BOX (sticky) -->
                        <div class="tf-product-info-choose-option sticky-top">
                            <div class="tf-product-info-by">

                                <div class="mb-2 text-muted small">
                                    Codice: <strong><asp:Literal ID="litCodice2" runat="server" /></strong>
                                    <asp:PlaceHolder ID="phEan2" runat="server" Visible="false">
                                        <span class="ms-2">EAN: <strong><asp:Literal ID="litEan2" runat="server" /></strong></span>
                                    </asp:PlaceHolder>
                                </div>

                                <asp:PlaceHolder ID="phBrand2" runat="server" Visible="false">
                                    <div class="mb-2 text-muted small">
                                        Marca: <strong><asp:Literal ID="litMarca2" runat="server" /></strong>
                                    </div>
                                </asp:PlaceHolder>

                                <div class="tf-product-info-price">
                                    <asp:Literal ID="litPriceHtml2" runat="server" />
                                </div>

                                <asp:Panel ID="pnlVariants" runat="server" Visible="false" CssClass="mt-3">
                                    <label class="form-label">Variante</label>
                                    <asp:DropDownList ID="ddlTc" runat="server" CssClass="form-select" AutoPostBack="true" OnSelectedIndexChanged="ddlTc_SelectedIndexChanged" />
                                </asp:Panel>

                                <div class="mt-3">
                                    <label class="form-label">Quantità</label>
                                    <div class="d-flex align-items-center gap-2">
                                        <asp:TextBox ID="txtQty" runat="server" CssClass="form-control" Text="1" />
                                        <asp:Button ID="btnAddToCart" runat="server" CssClass="tf-btn w-100" Text="Aggiungi al carrello" OnClick="btnAddToCart_Click" />
                                    </div>
                                    <div class="small text-danger mt-1">
                                        <asp:Literal ID="litQtyHelp" runat="server" />
                                    </div>
                                </div>

                                <div class="mt-3">
                                    <a class="tf-btn btn-fill" href="/carrello.aspx">Vai al carrello</a>
                                </div>

                            </div>
                        </div>

                    </div>
                </div>

            </div>

            <!-- DESCRIPTION / DETAILS -->
            <div class="mt-5">
                <ul class="nav nav-tabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" data-bs-toggle="tab" data-bs-target="#tab-desc" type="button" role="tab">Descrizione</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" data-bs-toggle="tab" data-bs-target="#tab-details" type="button" role="tab">Dettagli</button>
                    </li>
                </ul>

                <div class="tab-content pt-3">
                    <div class="tab-pane fade show active" id="tab-desc" role="tabpanel">
                        <div class="tf-rte">
                            <asp:Literal ID="litLongDesc" runat="server" />
                        </div>
                    </div>
                    <div class="tab-pane fade" id="tab-details" role="tabpanel">
                        <div class="tf-rte">
                            <p class="mb-1"><strong>Codice:</strong> <asp:Literal ID="litCodice3" runat="server" Visible="false" /></p>
                            <p class="mb-1"><strong>EAN:</strong> <asp:Literal ID="litEan3" runat="server" Visible="false" /></p>
                        </div>
                    </div>
                </div>
            </div>

        </div>
    </asp:Panel>

    <!-- RELATED PRODUCTS -->
    <asp:PlaceHolder ID="phRelated" runat="server" Visible="false">
        <section class="flat-spacing-2">
            <div class="container">
                <div class="tf-section-heading">
                    <h3 class="heading">Prodotti correlati</h3>
                    <a href="/articoli.aspx" class="link">Vedi tutto</a>
                </div>

                <div class="tf-grid-layout md-col-4">
                    <asp:Repeater ID="rptRelated" runat="server">
                        <ItemTemplate>
                            <div class="card-product style-1">
                                <div class="card-product-wrapper">
                                    <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("id") %>'>
                                        <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                                             src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
                                    </a>

                                    <%# If(Val(Eval("InOfferta")) = 1, "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", "") %>
                                </div>

                                <div class="card-product-info">
                                    <a class="name-product link" href='<%# "articolo.aspx?id=" & Eval("id") %>'>
                                        <%# Server.HtmlEncode(compatta_testo(Convert.ToString(Eval("Descrizione1")), 70)) %>
                                    </a>

                                    <div class="price-wrap">
                                        <%# UiPriceFormatter.RenderPriceHtml(
                                                If(IsDBNull(Eval("Prezzo")), 0, Eval("Prezzo")),
                                                If(IsDBNull(Eval("PrezzoIvato")), 0, Eval("PrezzoIvato")),
                                                If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")),
                                                If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")),
                                                Val(Eval("InOfferta")),
                                                Session("IvaTipo")
                                            ) %>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

</asp:Content>

<asp:Content ID="ScriptsContent1" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="<%= ThemeManager.Asset("js/vendor/swiper-bundle.min.js") %>"></script>
    <script src="<%= ThemeManager.Asset("js/vendor/photoswipe.umd.min.js") %>"></script>
    <script src="/Public/assets/keepstore/js/keepstore-product.js"></script>
</asp:Content>
