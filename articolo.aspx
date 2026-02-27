<%@ Page Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" %>
<%@ Register Src="~/Public/ui/controls/Breadcrumb.ascx" TagPrefix="ks" TagName="Breadcrumb" %>

<asp:Content ID="TitleContent1" ContentPlaceHolderID="TitleContent" runat="server">
    <%: Page.Title %>
</asp:Content>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <!-- KeepStore UI contract (product detail) -->
    <link rel="stylesheet" href="/Public/assets/keepstore/css/product-ui.css" />

    <!-- SEO/AI: JSON-LD injected by articolo.aspx.vb -->
    <asp:Literal ID="litJsonLdHead" runat="server" />
</asp:Content>

<asp:Content ID="BreadcrumbContent1" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <!-- Breadcrumb: no titolo per evitare H1 duplicato (H1 principale è in pagina) -->
    <ks:Breadcrumb ID="Breadcrumb1" runat="server" ShowTitle="False" />
</asp:Content>

<asp:Content ID="MainContent1" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Compatibilità: vecchi markup usavano questo Literal per breadcrumb corrente -->
    <asp:Literal ID="litBreadcrumbCurrent" runat="server" Visible="false" />

    <!-- Not found -->
    <asp:PlaceHolder ID="phNotFound" runat="server" Visible="false">
        <section class="tf-sp-2">
            <div class="container">
                <div class="alert alert-warning mb-0" role="alert">
                    Articolo non trovato oppure non disponibile.
                    <a class="alert-link" href="/articoli.aspx">Torna al catalogo</a>
                </div>
            </div>
        </section>
    </asp:PlaceHolder>

    <!-- Product -->
    <asp:Panel ID="pnlProduct" runat="server" Visible="false">
        <section class="tf-sp-2 ks-product-page">
            <div class="container">

                <div class="row g-4">

                    <!-- Gallery -->
                    <div class="col-lg-6">
                        <div class="ks-product-gallery">

                            <div class="swiper ks-product-gallery-main" aria-label="Galleria prodotto">
                                <div class="swiper-wrapper">
                                    <asp:Repeater ID="rptMainImages" runat="server">
                                        <ItemTemplate>
                                            <div class="swiper-slide">
                                                <img class="img-fluid w-100 ks-product-image"
                                                     src="<%# Eval(\"Url\") %>"
                                                     alt="<%#: Eval(\"Alt\") %>"
                                                     loading="lazy" />
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>

                                <div class="swiper-button-prev" aria-hidden="true"></div>
                                <div class="swiper-button-next" aria-hidden="true"></div>
                                <div class="swiper-pagination" aria-hidden="true"></div>
                            </div>

                            <div class="swiper ks-product-gallery-thumbs mt-3" aria-label="Miniature prodotto">
                                <div class="swiper-wrapper">
                                    <asp:Repeater ID="rptThumbs" runat="server">
                                        <ItemTemplate>
                                            <div class="swiper-slide">
                                                <img class="img-fluid ks-product-thumb"
                                                     src="<%# Eval(\"Url\") %>"
                                                     alt="<%#: Eval(\"Alt\") %>"
                                                     loading="lazy" />
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>

                        </div>
                    </div>

                    <!-- Buy box -->
                    <div class="col-lg-6">
                        <div class="ks-product-buy" id="ks-buy">

                            <div class="heading-section mb-3">
                                <h1 class="heading mb-2">
                                    <asp:Literal ID="litNome" runat="server" />
                                </h1>
                                <div class="body-text-3 text-muted">
                                    <asp:Literal ID="litShortDesc" runat="server" />
                                </div>
                            </div>

                            <div class="ks-product-price mb-3">
                                <asp:Literal ID="litPriceHtml" runat="server" />
                            </div>

                            <div class="ks-product-meta mb-4">
                                <ul class="list-unstyled mb-0">
                                    <li class="d-flex justify-content-between gap-3">
                                        <span class="text-muted">Codice</span>
                                        <strong><asp:Literal ID="litCodice" runat="server" /></strong>
                                    </li>

                                    <asp:PlaceHolder ID="phEan" runat="server" Visible="false">
                                        <li class="d-flex justify-content-between gap-3">
                                            <span class="text-muted">EAN</span>
                                            <strong><asp:Literal ID="litEan" runat="server" /></strong>
                                        </li>
                                    </asp:PlaceHolder>

                                    <asp:PlaceHolder ID="phBrand" runat="server" Visible="false">
                                        <li class="d-flex justify-content-between gap-3">
                                            <span class="text-muted">Marca</span>
                                            <strong><asp:HyperLink ID="lnkMarca" runat="server" CssClass="link" /></strong>
                                        </li>
                                    </asp:PlaceHolder>

                                    <asp:PlaceHolder ID="phAvailability" runat="server" Visible="false">
                                        <li class="d-flex justify-content-between gap-3">
                                            <span class="text-muted">Disponibilità</span>
                                            <strong><asp:Literal ID="litAvailability" runat="server" /></strong>
                                        </li>
                                    </asp:PlaceHolder>
                                </ul>
                            </div>

                            <div class="row g-3 align-items-end mb-3">

                                <asp:Panel ID="pnlVariants" runat="server" CssClass="col-12" Visible="false">
                                    <label class="form-label fw-semibold" for="<%= ddlTc.ClientID %>">Variante</label>
                                    <asp:DropDownList ID="ddlTc" runat="server" CssClass="form-select" AutoPostBack="true"
                                        OnSelectedIndexChanged="ddlTc_SelectedIndexChanged" />
                                </asp:Panel>

                                <div class="col-6 col-md-5">
                                    <label class="form-label fw-semibold" for="<%= txtQty.ClientID %>">Quantità</label>
                                    <div class="ks-qty-stepper">
                                        <button type="button" class="btn btn-light ks-qty-btn" data-ks-qty="minus" aria-label="Diminuisci quantità">-</button>
                                        <asp:TextBox ID="txtQty" runat="server" CssClass="form-control text-center ks-qty-input" />
                                        <button type="button" class="btn btn-light ks-qty-btn" data-ks-qty="plus" aria-label="Aumenta quantità">+</button>
                                    </div>
                                </div>

                                <div class="col-6 col-md-7">
                                    <asp:Button ID="btnAddToCart" runat="server" Text="Aggiungi al carrello"
                                        CssClass="tf-btn btn-fill w-100" OnClick="btnAddToCart_Click" UseSubmitBehavior="true" />
                                </div>

                            </div>

                            <asp:Literal ID="litQtyHelp" runat="server" />

                            <div class="mt-3">
                                <a class="tf-btn btn-outline w-100" href="/carrello.aspx">Vai al carrello</a>
                            </div>

                        </div>
                    </div>

                </div>

                <!-- Tabs -->
                <div class="row mt-5">
                    <div class="col-12">

                        <div class="tf-product-desc">
                            <ul class="nav nav-tabs ks-tabs" id="ksProductTabs" role="tablist">
                                <li class="nav-item" role="presentation">
                                    <button class="nav-link active" id="tab-desc" data-bs-toggle="tab" data-bs-target="#panel-desc" type="button" role="tab" aria-controls="panel-desc" aria-selected="true">Descrizione</button>
                                </li>
                                <li class="nav-item" role="presentation">
                                    <button class="nav-link" id="tab-info" data-bs-toggle="tab" data-bs-target="#panel-info" type="button" role="tab" aria-controls="panel-info" aria-selected="false">Info</button>
                                </li>
                            </ul>

                            <div class="tab-content pt-4">
                                <div class="tab-pane fade show active" id="panel-desc" role="tabpanel" aria-labelledby="tab-desc">
                                    <div class="ks-product-description">
                                        <asp:Literal ID="litLongDesc" runat="server" />
                                    </div>
                                </div>

                                <div class="tab-pane fade" id="panel-info" role="tabpanel" aria-labelledby="tab-info">
                                    <div class="card">
                                        <div class="card-body">

                                            <div class="d-flex justify-content-between gap-3">
                                                <span class="text-muted">Codice</span>
                                                <strong><asp:Literal ID="litCodice2" runat="server" /></strong>
                                            </div>

                                            <asp:PlaceHolder ID="phEan2" runat="server" Visible="false">
                                                <div class="d-flex justify-content-between gap-3 mt-2">
                                                    <span class="text-muted">EAN</span>
                                                    <strong><asp:Literal ID="litEan2" runat="server" /></strong>
                                                </div>
                                            </asp:PlaceHolder>

                                            <asp:PlaceHolder ID="phBrand2" runat="server" Visible="false">
                                                <div class="d-flex justify-content-between gap-3 mt-2">
                                                    <span class="text-muted">Marca</span>
                                                    <strong><asp:Literal ID="litMarca2" runat="server" /></strong>
                                                </div>
                                            </asp:PlaceHolder>

                                            <div class="ks-product-price mt-3">
                                                <asp:Literal ID="litPriceHtml2" runat="server" />
                                            </div>

                                        </div>
                                    </div>
                                </div>

                            </div>
                        </div>

                    </div>
                </div>

                <!-- Related -->
                <asp:PlaceHolder ID="phRelated" runat="server" Visible="false">
                    <div class="mt-5">
                        <div class="heading-section mb-3">
                            <h3 class="heading">Prodotti correlati</h3>
                        </div>

                        <div class="row g-4">
                            <asp:Repeater ID="rptRelated" runat="server">
                                <ItemTemplate>
                                    <div class="col-6 col-md-4 col-lg-3">
                                        <div class="card ks-product-card h-100">
                                            <a class="ks-product-card-image" href="<%# Eval(\"Url\") %>">
                                                <img class="img-fluid" src="<%# Eval(\"Img\") %>" alt="<%#: Eval(\"Nome\") %>" loading="lazy" />
                                            </a>
                                            <div class="card-body d-flex flex-column">
                                                <a class="ks-product-card-title fw-semibold mb-2" href="<%# Eval(\"Url\") %>"><%#: Eval("Nome") %></a>
                                                <div class="mt-auto ks-product-card-price">
                                                    <%# Eval("PrezzoHtml") %>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>

                    </div>
                </asp:PlaceHolder>

            </div>
        </section>
    </asp:Panel>

</asp:Content>

<asp:Content ID="ScriptsContent1" ContentPlaceHolderID="ScriptsContent" runat="server">
    <!-- KeepStore UI contract (product detail) -->
    <script src="/Public/assets/keepstore/js/product-ui.js"></script>
</asp:Content>
