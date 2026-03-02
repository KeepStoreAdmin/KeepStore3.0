<%@ Page Title="" Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" %>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litSeoHead" runat="server" EnableViewState="False" />

    <%-- JSON-LD (riempito dal VB) --%>
    <asp:PlaceHolder ID="phJsonLdHead" runat="server" EnableViewState="False">
        <script type="application/ld+json"><asp:Literal ID="litJsonLdHead" runat="server" EnableViewState="False" /></script>
    </asp:PlaceHolder>

    <%-- CSS di pagina (tema) --%>
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/product-page.css") %>" />
</asp:Content>

<asp:Content ID="BreadcrumbContent1" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <section class="tf-breadcrumb">
        <div class="container">
            <ul class="breadcrumb">
                <li class="breadcrumb-item"><a href="Default.aspx">Home</a></li>
                <li class="breadcrumb-item"><a href="articoli.aspx">Catalogo</a></li>
                <li class="breadcrumb-item active" aria-current="page"><asp:Literal ID="litBreadcrumbCurrent" runat="server" /></li>
            </ul>
            <h1 class="h5 fw-semibold mb-0"><asp:Literal ID="litNome" runat="server" /></h1>
        </div>
    </section>
</asp:Content>

<asp:Content ID="MainContent1" ContentPlaceHolderID="MainContent" runat="server">

    <%-- SHELL PRODOTTO (tutti gli ID richiesti dalla logica VB sono presenti) --%>
    <asp:Panel ID="pnlProduct" runat="server" CssClass="tf-sp-2">
        <div class="container">

            <div class="row g-4">

                <%-- GALLERY --%>
                <div class="col-lg-6">
                    <div class="ks-product-gallery">

                        <div class="swiper tf-product-view-main">
                            <div class="swiper-wrapper">
                                <asp:Repeater ID="rptMainImages" runat="server">
                                    <ItemTemplate>
                                        <div class="swiper-slide">
                                            <a class="tf-image-view d-block" href='<%# Eval("Url") %>' target="_blank" rel="noopener">
                                                <img class="lazyload" src='<%# Eval("Url") %>' data-src='<%# Eval("Url") %>' alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Alt"))) %>' />
                                            </a>
                                        </div>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </div>

                            <div class="swiper-button-prev nav-swiper-2 single-slide-prev" aria-label="Precedente"></div>
                            <div class="swiper-button-next nav-swiper-2 single-slide-next" aria-label="Successivo"></div>
                        </div>

                        <div class="swiper tf-product-view-thumbs" data-direction="horizontal">
                            <div class="swiper-wrapper">
                                <asp:Repeater ID="rptThumbs" runat="server">
                                    <ItemTemplate>
                                        <div class="swiper-slide">
                                            <div class="item">
                                                <img class="lazyload" src='<%# Eval("Url") %>' data-src='<%# Eval("Url") %>' alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Alt"))) %>' />
                                            </div>
                                        </div>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </div>
                        </div>

                    </div>
                </div>

                <%-- SUMMARY --%>
                <div class="col-lg-6">
                    <div class="ks-product-summary tf-product-info-content">

                        <div class="infor-heading">
                            <div class="d-flex flex-wrap gap-3 small text-muted">
                                <span><strong>Codice:</strong> <asp:Literal ID="litCodice" runat="server" /></span>

                                <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
                                    <span><strong>Marca:</strong> <asp:HyperLink ID="lnkMarca" runat="server" CssClass="link text-secondary" /></span>
                                </asp:PlaceHolder>

                                <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
                                    <span><strong>EAN:</strong> <asp:Literal ID="litEan" runat="server" /></span>
                                </asp:PlaceHolder>
                            </div>
                        </div>

                        <div class="infor-center mt-3">

                            <div class="product-info-price">
                                <div class="price-wrap">
                                    <asp:Literal ID="litPriceHtml" runat="server" EnableViewState="False" />
                                </div>
                            </div>

                            <asp:PlaceHolder ID="phAvailability" runat="server" Visible="false">
                                <div class="mt-2">
                                    <span class="badge bg-success-subtle text-success-emphasis">
                                        <asp:Literal ID="litAvailability" runat="server" />
                                    </span>
                                </div>
                            </asp:PlaceHolder>

                            <div class="mt-3 ks-richtext">
                                <asp:Literal ID="litShortDesc" runat="server" EnableViewState="False" />
                            </div>

                            <asp:Panel ID="pnlVariants" runat="server" Visible="false" CssClass="mt-3">
                                <label class="form-label fw-semibold mb-1">Variante</label>
                                <asp:DropDownList ID="ddlTc" runat="server" CssClass="form-select" AutoPostBack="true" OnSelectedIndexChanged="ddlTc_SelectedIndexChanged" />
                            </asp:Panel>

                            <div class="box-quantity-wrap mt-4">
                                <div class="wg-quantity">
                                    <span class="btn-quantity minus-btn" role="button" aria-label="Diminuisci quantità"><i class="icon-minus"></i></span>
                                    <asp:TextBox ID="txtQty" runat="server" CssClass="quantity-product" Text="1" />
                                    <span class="btn-quantity plus-btn" role="button" aria-label="Aumenta quantità"><i class="icon-plus"></i></span>
                                </div>

                                <asp:LinkButton ID="btnAddToCart" runat="server" CssClass="tf-btn" CausesValidation="false" OnClick="btnAddToCart_Click">
                                    <span class="text-white">Aggiungi al carrello</span>
                                </asp:LinkButton>
                            </div>

                            <div class="mt-2 small text-muted">
                                <asp:Literal ID="litQtyHelp" runat="server" EnableViewState="False" />
                            </div>

                        </div>

                    </div>
                </div>

            </div>

            <%-- TAB DETTAGLI / DESCRIZIONE --%>
            <div class="mt-5">
                <ul class="nav nav-tabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" data-bs-toggle="tab" data-bs-target="#tab-desc" type="button" role="tab">Descrizione</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" data-bs-toggle="tab" data-bs-target="#tab-details" type="button" role="tab">Dettagli</button>
                    </li>
                </ul>

                <div class="tab-content border border-top-0 p-3">

                    <div class="tab-pane fade show active ks-richtext" id="tab-desc" role="tabpanel">
                        <asp:Literal ID="litLongDesc" runat="server" EnableViewState="False" />
                    </div>

                    <div class="tab-pane fade" id="tab-details" role="tabpanel">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <ul class="list-unstyled mb-0">
                                    <li><strong>Codice:</strong> <asp:Literal ID="litCodice2" runat="server" /></li>

                                    <asp:PlaceHolder ID="phBrand2" runat="server" Visible="false">
                                        <li><strong>Marca:</strong> <asp:Literal ID="litMarca2" runat="server" /></li>
                                    </asp:PlaceHolder>

                                    <asp:PlaceHolder ID="phEan2" runat="server" Visible="false">
                                        <li><strong>EAN:</strong> <asp:Literal ID="litEan2" runat="server" /></li>
                                    </asp:PlaceHolder>
                                </ul>
                            </div>
                        </div>
                    </div>

                </div>
            </div>

            <%-- RELATED PRODUCTS --%>
            <asp:PlaceHolder ID="phRelated" runat="server" Visible="false">
                <div class="tf-sp-2 ks-related-products">
                    <div class="d-flex align-items-center justify-content-between mb-3">
                        <h4 class="fw-semibold mb-0">Prodotti correlati</h4>
                        <a href="articoli.aspx" class="link text-secondary">Vedi catalogo</a>
                    </div>

                    <div class="row g-3">
                        <asp:Repeater ID="rptRelated" runat="server">
                            <ItemTemplate>
                                <div class="col-6 col-md-4 col-lg-3">
                                    <div class="card-product">
                                        <div class="card-product-wrapper">
                                            <a class="product-img" href='<%# Eval("Url") %>'>
                                                <img class="img-product lazyload" src='<%# Eval("Img") %>' data-src='<%# Eval("Img") %>' alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>' />
                                            </a>
                                        </div>
                                        <div class="card-product-info">
                                            <div class="box-title">
                                                <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# Eval("Url") %>'>
                                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Nome"))) %>
                                                </a>
                                                <div class="price-wrap fw-medium mt-1">
                                                    <%# Eval("PrezzoHtml") %>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </div>
            </asp:PlaceHolder>

            <%-- Campo non obbligatorio ma presente nella logica VB: seconda renderizzazione prezzo (es. sticky) --%>
            <asp:Literal ID="litPriceHtml2" runat="server" Visible="false" EnableViewState="False" />

        </div>
    </asp:Panel>

    <%-- NOT FOUND --%>
    <asp:PlaceHolder ID="phNotFound" runat="server" Visible="false">
        <section class="tf-sp-2">
            <div class="container">
                <div class="alert alert-warning mb-0">
                    Articolo non trovato o non disponibile.
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

</asp:Content>

<asp:Content ID="ScriptsContent1" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script defer src="<%= ThemeManager.Asset("js/ks-product-gallery.js") %>"></script>
</asp:Content>
