<%@ Page Title="Catalogo" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" %>
<%@ Reference Control="~/Public/ui/controls/ProductCard.ascx" %>

<%@ Register Src="~/Public/ui/controls/Breadcrumb.ascx" TagPrefix="ks" TagName="Breadcrumb" %>

<asp:Content ID="TitleContent1" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo
</asp:Content>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litSeoHead" runat="server" EnableViewState="false" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/catalog-ui.css") %>" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/catalog-filters-ui.css") %>" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/catalog-product-flow.css") %>" />
</asp:Content>

<asp:Content ID="BreadcrumbContent1" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <ks:Breadcrumb ID="Breadcrumb1" runat="server" />
</asp:Content>

<asp:Content ID="MainContent1" ContentPlaceHolderID="MainContent" runat="server">

    <asp:Panel ID="ksPageTitle" runat="server" CssClass="tf-page-title d-none">
        <div class="container">
            <div class="d-flex flex-column flex-sm-row align-items-start align-items-sm-end justify-content-between gap-3">
                <div class="d-flex flex-column gap-2">
                    <h1 class="title">Catalogo</h1>
                    <div class="d-flex flex-wrap align-items-center gap-2 text-muted small">
                        <asp:Label ID="lblRicerca" runat="server" Visible="false" Text="Risultati ricerca:" />
                        <asp:Label ID="lblRisultati" runat="server" />
                        <asp:Label ID="lblTrovati" runat="server" />
                    </div>
                </div>
                <div class="text-muted small">
                    <asp:Label ID="lblPrezzi" runat="server" />
                </div>
            </div>
        </div>
    </asp:Panel>

    <section id="ksCatalogPage" class="flat-content ks-catalog-page">
        <div class="container">
            <div class="tf-product-view-content wrapper-control-shop">

                <div class="canvas-filter-product sidebar-filter handle-canvas left" aria-label="Filtri catalogo">
                    <div class="canvas-wrapper">
                        <div class="canvas-header d-flex d-xl-none">
                            <h5 class="title">Filtri</h5>
                            <span class="icon-close link icon-close-popup close-filter" aria-label="Chiudi"></span>
                        </div>

                        <div class="canvas-body">
                            <asp:Panel ID="ksFilters" runat="server">
                                <div class="widget-facet facet-fieldset">
                                    <p class="facet-title title-sidebar fw-semibold">Disponibilita</p>
                                    <div class="box-fieldset-item">
                                        <fieldset class="fieldset-item ks-filter-checkbox">
                                            <asp:CheckBox ID="CheckBox_Disponibile" runat="server" Text="Solo disponibili" AutoPostBack="true" />
                                        </fieldset>
                                    </div>
                                </div>

                                <div class="widget-facet facet-fieldset">
                                    <p class="facet-title title-sidebar fw-semibold">Categorie</p>
                                    <asp:FormView ID="FormView1" runat="server" DataSourceID="sdsGruppo">
                                        <ItemTemplate>
                                            <asp:Label ID="lblCategoria" runat="server" Text='<%# Eval("descrizione") %>' Visible="false" />
                                        </ItemTemplate>
                                    </asp:FormView>
                                    <div class="box-fieldset-item">
                                        <asp:DataList ID="DataList1" runat="server" DataSourceID="sdsGruppo" RepeatLayout="Flow" CssClass="ks-filter-list">
                                            <ItemTemplate>
                                                <fieldset class="fieldset-item">
                                                    <a class='ks-filter-option link<%# If(ThemeManager.CatalogFilterSelected("gr", Container.DataItem), " active", "") %>' href='<%# ThemeManager.CatalogFilterUrl("gr", Container.DataItem) %>'>
                                                        <span><%# Server.HtmlEncode(Convert.ToString(Eval("descrizione"))) %></span>
                                                        <small><%# If(UiData.HasColumn(Container.DataItem, "Numero"), Eval("Numero"), "") %></small>
                                                    </a>
                                                </fieldset>
                                            </ItemTemplate>
                                        </asp:DataList>
                                    </div>
                                </div>

                                <div class="widget-facet facet-fieldset">
                                    <p class="facet-title title-sidebar fw-semibold">Sottocategorie</p>
                                    <div class="box-fieldset-item">
                                        <asp:DataList ID="DataList4" runat="server" DataSourceID="sdsSottogruppo" RepeatLayout="Flow" CssClass="ks-filter-list">
                                            <ItemTemplate>
                                                <fieldset class="fieldset-item">
                                                    <a class='ks-filter-option link<%# If(ThemeManager.CatalogFilterSelected("sg", Container.DataItem), " active", "") %>' href='<%# ThemeManager.CatalogFilterUrl("sg", Container.DataItem) %>'>
                                                        <span><%# Server.HtmlEncode(Convert.ToString(Eval("descrizione"))) %></span>
                                                        <small><%# If(UiData.HasColumn(Container.DataItem, "Numero"), Eval("Numero"), "") %></small>
                                                    </a>
                                                </fieldset>
                                            </ItemTemplate>
                                        </asp:DataList>
                                    </div>
                                </div>

                                <div class="widget-facet facet-fieldset has-loadmore">
                                    <p class="facet-title title-sidebar fw-semibold">Marche</p>
                                    <div class="box-fieldset-item">
                                        <asp:DataList ID="DataList2" runat="server" DataSourceID="sdsMarche" RepeatLayout="Flow" CssClass="ks-filter-list">
                                            <ItemTemplate>
                                                <fieldset class="fieldset-item">
                                                    <a class='ks-filter-option link<%# If(ThemeManager.CatalogFilterSelected("mr", Container.DataItem), " active", "") %>' href='<%# ThemeManager.CatalogFilterUrl("mr", Container.DataItem) %>'>
                                                        <span><%# Server.HtmlEncode(Convert.ToString(Eval("descrizione"))) %></span>
                                                        <small><%# If(UiData.HasColumn(Container.DataItem, "Numero"), Eval("Numero"), "") %></small>
                                                    </a>
                                                </fieldset>
                                            </ItemTemplate>
                                        </asp:DataList>
                                    </div>
                                </div>

                                <div class="widget-facet facet-fieldset">
                                    <p class="facet-title title-sidebar fw-semibold">Tipologie</p>
                                    <div class="box-fieldset-item">
                                        <asp:DataList ID="DataList3" runat="server" DataSourceID="sdsTipologie" RepeatLayout="Flow" CssClass="ks-filter-list">
                                            <ItemTemplate>
                                                <fieldset class="fieldset-item">
                                                    <a class='ks-filter-option link<%# If(ThemeManager.CatalogFilterSelected("tp", Container.DataItem), " active", "") %>' href='<%# ThemeManager.CatalogFilterUrl("tp", Container.DataItem) %>'>
                                                        <span><%# Server.HtmlEncode(Convert.ToString(Eval("descrizione"))) %></span>
                                                        <small><%# If(UiData.HasColumn(Container.DataItem, "Numero"), Eval("Numero"), "") %></small>
                                                    </a>
                                                </fieldset>
                                            </ItemTemplate>
                                        </asp:DataList>
                                    </div>
                                </div>

                                <asp:Panel ID="filtritagliaecolore" runat="server" Visible="false" CssClass="widget-facet facet-fieldset">
                                    <p class="facet-title title-sidebar fw-semibold">Varianti</p>
                                    <div class="box-fieldset-item">
                                        <fieldset class="fieldset-item d-block">
                                            <label class="body-text-3 mb-1">Taglia</label>
                                            <asp:DropDownList ID="Drop_Filtra_Taglia" runat="server" CssClass="form-select" AutoPostBack="true" />
                                        </fieldset>
                                        <fieldset class="fieldset-item d-block">
                                            <label class="body-text-3 mb-1">Colore</label>
                                            <asp:DropDownList ID="Drop_Filtra_Colore" runat="server" CssClass="form-select" AutoPostBack="true" />
                                        </fieldset>
                                    </div>
                                </asp:Panel>
                            </asp:Panel>
                        </div>

                        <div class="canvas-bottom d-flex d-xl-none">
                            <a class="tf-btn btn-reset w-100" href="articoli.aspx">
                                <span class="caption text-white">Reset filtri</span>
                            </a>
                        </div>
                    </div>
                </div>

                <div class="content-area">
                    <div class="tf-shop-control flex-wrap gap-10">
                        <div class="d-flex align-items-center gap-10">
                            <button id="filterShop" type="button" class="tf-btn-filter d-flex d-xl-none">
                                <span class="icon icon-filter"></span>
                                <span class="body-md-2 fw-medium">Filtri</span>
                            </button>
                            <p class="body-text-3 mb-0 d-none d-lg-block">
                                <asp:Label ID="lblLinee" runat="server" Text="" CssClass="d-none" />
                                <asp:Label ID="lblCatalogSummary" runat="server" CssClass="title-sidebar fw-bold" Text="Sfoglia il catalogo" />
                            </p>
                        </div>

                        <div class="tf-control-view flat-title-tab-product flex-wrap">
                            <div class="tf-control-show d-flex align-items-center gap-2">
                                <span class="body-text-3">Mostra</span>
                                <asp:DropDownList ID="Drop_Righe" runat="server" CssClass="select-show form-select" AutoPostBack="true">
                                    <asp:ListItem Value="12" Text="12"></asp:ListItem>
                                    <asp:ListItem Value="24" Text="24"></asp:ListItem>
                                    <asp:ListItem Value="48" Text="48"></asp:ListItem>
                                    <asp:ListItem Value="96" Text="96"></asp:ListItem>
                                </asp:DropDownList>
                            </div>

                            <div class="tf-control-sorting d-flex align-items-center gap-2">
                                <span class="body-text-3">Ordina</span>
                                <asp:DropDownList ID="Drop_Ordinamento" runat="server" CssClass="select-sorting form-select" AutoPostBack="true">
                                    <asp:ListItem Value="" Text="Consigliati"></asp:ListItem>
                                    <asp:ListItem Value="P_basso" Text="Prezzo: crescente"></asp:ListItem>
                                    <asp:ListItem Value="P_alto" Text="Prezzo: decrescente"></asp:ListItem>
                                    <asp:ListItem Value="P_offerta" Text="Offerte"></asp:ListItem>
                                    <asp:ListItem Value="P_disponibilita" Text="Disponibilita"></asp:ListItem>
                                    <asp:ListItem Value="P_recenti" Text="Novita"></asp:ListItem>
                                    <asp:ListItem Value="P_popolarita" Text="Popolarita"></asp:ListItem>
                                    <asp:ListItem Value="P_codice" Text="Codice"></asp:ListItem>
                                    <asp:ListItem Value="P_descrizione" Text="Nome"></asp:ListItem>
                                </asp:DropDownList>
                            </div>
                        </div>
                    </div>

                    <div id="ksActiveFilters" class="ks-active-filters mb-3" runat="server" Visible="false">
                        <div class="d-flex flex-wrap gap-2 align-items-center">
                            <asp:Repeater ID="rptActiveFilters" runat="server" OnItemCommand="rptActiveFilters_ItemCommand">
                                <ItemTemplate>
                                    <asp:LinkButton ID="lbRemove" runat="server" CssClass="badge rounded-pill text-bg-secondary" CommandName="remove" CommandArgument='<%# Eval("Key") %>'>
                                        <%# Eval("Label") %> <span class="ms-1">x</span>
                                    </asp:LinkButton>
                                </ItemTemplate>
                            </asp:Repeater>

                            <asp:LinkButton ID="lbClearAllFilters" runat="server" CssClass="badge rounded-pill text-bg-dark" CommandName="clear" OnClick="lbClearAllFilters_Click" Visible="false">
                                Pulisci tutto
                            </asp:LinkButton>
                        </div>
                    </div>

                    <section id="ksRecentlyViewedBlock"
                             class="ks-recently-viewed-block d-none"
                             data-ks-limit="8"
                             data-ks-placeholder="<%= ThemeManager.PlaceholderProductImageUrl() %>">
                        <div class="flat-title mb-3">
                            <h5 class="fw-semibold">Visti di recente</h5>
                            <div class="box-btn-slide relative">
                                <div class="swiper-button-prev nav-swiper nav-prev-products ks-rv-prev">
                                    <i class="icon-arrow-left-lg"></i>
                                </div>
                                <div class="swiper-button-next nav-swiper nav-next-products ks-rv-next">
                                    <i class="icon-arrow-right-lg"></i>
                                </div>
                            </div>
                        </div>
                        <div class="swiper tf-sw-products ks-recently-viewed-swiper">
                            <div class="swiper-wrapper" data-ks-recent-items></div>
                        </div>
                    </section>

                    <div class="meta-filter-shop d-none">
                        <div id="product-count-grid" class="count-text"></div>
                        <div id="product-count-list" class="count-text"></div>
                        <div id="applied-filters"></div>
                    </div>

                    <asp:PlaceHolder ID="phProductCardPreview" runat="server" Visible="false" />

                    <div class="gridLayout-wrapper">
                        <asp:ListView ID="lvProdotti" runat="server" DataSourceID="sdsArticoli" OnPagePropertiesChanging="lvProdotti_PagePropertiesChanging" OnPreRender="lvProdotti_PreRender">
                            <LayoutTemplate>
                                <div id="gridLayout" class="tf-grid-layout lg-col-4 md-col-3 sm-col-2 flat-grid-product wrapper-shop layout-tabgrid-1">
                                    <asp:PlaceHolder ID="itemPlaceholder" runat="server" />
                                </div>
                            </LayoutTemplate>

                            <ItemTemplate>
                                <asp:PlaceHolder ID="phReplacementProductCard" runat="server" />
                                <asp:PlaceHolder ID="phInlineProductCard" runat="server">
                                <div class="card-product ks-catalog-card">
                                    <div class="card-product-wrapper">
                                        <a href='<%# CatalogProductUrl(Container.DataItem) %>' class="product-img">
                                            <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                                                 src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>'
                                                 data-src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
                                        </a>

                                        <ul class="list-product-btn top-0 end-0">
                                            <li>
                                                <a href='<%# CatalogCartAddUrl(Container.DataItem) %>'
                                                    class="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left js-ks-cart-link"
                                                    aria-label="Aggiungi al carrello"
                                                    <%# CatalogActionDataAttributes(Container.DataItem) %>>
                                                    <span class="icon icon-cart2"></span>
                                                    <span class="tooltip">Carrello</span>
                                                </a>
                                            </li>
                                            <li class="wishlist">
                                                <a href='<%# CatalogWishlistAddUrl(Container.DataItem) %>'
                                                    class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-wishlist-link"
                                                    aria-label="Aggiungi a wishlist"
                                                    <%# CatalogActionDataAttributes(Container.DataItem) %>>
                                                    <span class="icon icon-heart2"></span>
                                                    <span class="tooltip">Wishlist</span>
                                                </a>
                                            </li>
                                            <li>
                                                <a href="#quickView" data-bs-toggle="modal"
                                                    class="box-icon quickview btn-icon-action hover-tooltip tooltip-left js-ks-quickview"
                                                    aria-label="Vista rapida"
                                                    <%# CatalogActionDataAttributes(Container.DataItem) %>>
                                                    <span class="icon icon-view"></span>
                                                    <span class="tooltip">Vista rapida</span>
                                                </a>
                                            </li>
                                            <li>
                                                <a href="#compare" data-bs-toggle="offcanvas"
                                                    class="box-icon btn-icon-action hover-tooltip tooltip-left js-ks-compare"
                                                    aria-label="Confronta articolo"
                                                    <%# CatalogActionDataAttributes(Container.DataItem) %>>
                                                    <span class="icon icon-compare1"></span>
                                                    <span class="tooltip">Confronta</span>
                                                </a>
                                            </li>
                                        </ul>

                                        <asp:PlaceHolder ID="phRefurbBadge" runat="server"
                                            Visible='<%# UiData.Bool(Container.DataItem, "Ricondizionato") OrElse UiData.Int(Container.DataItem, "st") = 34 OrElse UiData.Int(Container.DataItem, "SettoriId") = 34 %>'>
                                            <div class="box-sale-wrap pst-default">
                                                <p class="small-text ks-badge-refurb">Ricondizionato</p>
                                            </div>
                                        </asp:PlaceHolder>

                                        <%# CatalogPromoBadgeHtml(Container.DataItem) %>

                                        <asp:HiddenField ID="hfID" runat="server" Value='<%# Eval("id") %>' />
                                        <asp:HiddenField ID="hfTCId" runat="server" Value='<%# Eval("TCId") %>' />
                                    </div>

                                    <div class="card-product-info">
                                        <div class="box-title">
                                            <div>
                                                <p class="product-tag caption text-main-2">
                                                    <%# Server.HtmlEncode(CatalogCategoryLabel(Container.DataItem)) %>
                                                </p>

                                                <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# CatalogProductUrl(Container.DataItem) %>'>
                                                    <%# Server.HtmlEncode(ThemeManager.CompactText(Convert.ToString(Eval("Descrizione1")), 72)) %>
                                                </a>
                                                <p class="caption text-main-2 ks-card-brand-code">
                                                    <%# Server.HtmlEncode(CatalogBrandCodeLabel(Container.DataItem)) %>
                                                </p>
                                            </div>

                                            <div class="price-wrap fw-medium mt-1">
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

                                        <div class="box-infor-detail">
                                            <ul class="list-infor-fearture">
                                                <li>
                                                    <p class="caption name-feature">Codice:</p>
                                                    <p class="caption property"><%# Server.HtmlEncode(UiData.Str(Container.DataItem, "Codice")) %></p>
                                                </li>
                                                <li>
                                                    <p class="caption name-feature">Disponibilita:</p>
                                                    <p class='caption property <%# CatalogAvailabilityCss(Container.DataItem) %>'><%# Server.HtmlEncode(CatalogAvailabilityText(Container.DataItem)) %></p>
                                                </li>
                                            </ul>

                                            <div class="d-flex align-items-center gap-2 mt-2 ks-catalog-card-actions">
                                                <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" CssClass="form-check-input" />
                                                <asp:TextBox ID="tbQuantita" runat="server" CssClass="form-control form-control-sm ks-qty" Text="1" Width="70" />
                                            </div>
                                        </div>
                                    </div>

                                    <div class="card-product-btn">
                                        <a href='<%# CatalogCartAddUrl(Container.DataItem) %>'
                                            class="tf-btn btn-line w-100 js-ks-cart-link"
                                            aria-label="Aggiungi al carrello"
                                            <%# CatalogActionDataAttributes(Container.DataItem) %>>
                                            <span>Aggiungi al carrello</span>
                                            <i class="icon-cart-2"></i>
                                        </a>
                                        <div class="box-btn">
                                            <a href='<%# CatalogProductUrl(Container.DataItem) %>' class="tf-btn-icon style-2 type-black" aria-label="Apri dettagli prodotto">
                                                <i class="icon-view"></i>
                                                <span class="body-text-3 fw-normal">Dettagli</span>
                                            </a>
                                        </div>
                                    </div>
                                </div>
                                </asp:PlaceHolder>
                            </ItemTemplate>

                            <EmptyDataTemplate>
                                <div class="tf-empty-state text-center py-5">
                                    <div class="heading">Nessun prodotto trovato</div>
                                    <p class="text-main-2 mt-2">Modifica i filtri o torna al catalogo completo.</p>
                                    <div class="mt-4">
                                        <a class="tf-btn btn-fill" href="articoli.aspx">Reset filtri</a>
                                    </div>
                                </div>
                            </EmptyDataTemplate>
                        </asp:ListView>
                    </div>

                    <asp:Panel ID="ksPagerWrap" runat="server" CssClass="wrap-pagination d-flex justify-content-center mt-4">
                        <asp:DataPager ID="dpProdotti" runat="server" PagedControlID="lvProdotti" PageSize="12">
                            <Fields>
                                <asp:NextPreviousPagerField ShowFirstPageButton="false" ShowPreviousPageButton="true" ShowNextPageButton="false" ShowLastPageButton="false" ButtonType="Link" PreviousPageText="&laquo;" ButtonCssClass="pagination-link" />
                                <asp:NumericPagerField ButtonType="Link" ButtonCount="7" NumericButtonCssClass="pagination-link" CurrentPageLabelCssClass="pagination-link active" />
                                <asp:NextPreviousPagerField ShowFirstPageButton="false" ShowPreviousPageButton="false" ShowNextPageButton="true" ShowLastPageButton="false" ButtonType="Link" NextPageText="&raquo;" ButtonCssClass="pagination-link" />
                            </Fields>
                        </asp:DataPager>
                    </asp:Panel>

                    <asp:Panel ID="ksMultiFooter" runat="server" CssClass="mt-4" Visible="false">
                        <div class="alert alert-info">Selezione multipla attiva: scegli le quantita e aggiungi al carrello.</div>
                    </asp:Panel>

                    <asp:Panel ID="tNavig" runat="server" Visible="false" />
                </div>
            </div>
        </div>
    </section>

    <div class="overlay-filter" id="overlay-filter"></div>

    <asp:SqlDataSource ID="sdsArticoli" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT 0 as id, 0 as TCId, '' as Descrizione1, '' as img1, 0 as Prezzo, 0 as PrezzoIvato, 0 as InOfferta, 0 as PrezzoPromo, 0 as PrezzoPromoIvato WHERE 1=0" />

    <asp:SqlDataSource ID="sdsMarche" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT 0 as id, '' as descrizione, '' as url WHERE 1=0" />

    <asp:SqlDataSource ID="sdsTipologie" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT 0 as id, '' as descrizione, '' as url WHERE 1=0" />

    <asp:SqlDataSource ID="sdsGruppo" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT 0 as id, '' as descrizione, '' as url WHERE 1=0" />

    <asp:SqlDataSource ID="sdsSottogruppo" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT 0 as id, '' as descrizione, '' as url WHERE 1=0" />

</asp:Content>

<asp:Content ID="ScriptsContent1" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="<%= ThemeManager.Asset("js/catalog-ui.js") %>"></script>
    <script src="<%= ThemeManager.Asset("js/catalog-product-flow.js") %>"></script>
    <script src="<%= ThemeManager.Asset("js/keepstore-product.js") %>"></script>
    <script src="<%= ThemeManager.Asset("js/keepstore-recently-viewed.js") %>"></script>
</asp:Content>
