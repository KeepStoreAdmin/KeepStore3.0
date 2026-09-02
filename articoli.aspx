<%@ Page Title="Catalogo" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" %>
<%@ Reference Control="~/Public/ui/controls/ProductCard.ascx" %>

<%@ Register Src="~/Public/ui/controls/Breadcrumb.ascx" TagPrefix="ks" TagName="Breadcrumb" %>

<asp:Content ID="TitleContent1" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo
</asp:Content>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <asp:Literal ID="litSeoHead" runat="server" EnableViewState="false" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/catalog-ui.css") %>?v=20260901-catalogstructure1" />
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

    <section id="ksCatalogPage"
             class="flat-content ks-catalog-page"
             data-ks-async-cart-endpoint="<%= ResolveUrl("~/catalog_cart_async.aspx") %>"
             data-ks-async-cart-token="<%= System.Web.HttpUtility.HtmlAttributeEncode(CatalogAsyncCartToken) %>">
        <div id="ksCatalogCartStatus" class="visually-hidden" role="status" aria-live="polite" aria-atomic="true"></div>
        <div class="container">
            <div class="tf-product-view-content wrapper-control-shop">

                <div class="canvas-filter-product sidebar-filter handle-canvas left" aria-label="Filtri catalogo">
                    <div class="canvas-wrapper">
                        <div class="canvas-header d-flex d-xl-none">
                            <h5 class="title">Filtri</h5>
                            <span class="icon-close link icon-close-popup close-filter" aria-label="Chiudi"></span>
                        </div>

                        <div class="canvas-body">
                            <asp:Panel ID="pnlCatalogCategoryNav" runat="server" CssClass="facet-categories ks-catalog-category-nav" Visible="false">
                                <h6 class="title fw-medium">Settori</h6>
                                <asp:Literal ID="litCatalogCategoryNav" runat="server" />
                            </asp:Panel>

                            <asp:Panel ID="ksFilters" runat="server">
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

                                <div class="widget-facet facet-fieldset">
                                    <p class="facet-title title-sidebar fw-semibold">Gruppi</p>
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
                                    <p class="facet-title title-sidebar fw-semibold">Sottogruppi</p>
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

                                <div class="widget-facet facet-fieldset">
                                    <p class="facet-title title-sidebar fw-semibold">Disponibilita</p>
                                    <div class="box-fieldset-item">
                                        <fieldset class="fieldset-item ks-filter-checkbox">
                                            <asp:CheckBox ID="CheckBox_Disponibile" runat="server" Text="Solo disponibili" AutoPostBack="true" />
                                        </fieldset>
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
                        <div class="ks-shop-control-summary d-flex align-items-center gap-10">
                            <button id="filterShop" type="button" class="tf-btn-filter d-flex d-xl-none">
                                <span class="icon icon-filter"></span>
                                <span class="body-md-2 fw-medium">Filtri</span>
                            </button>
                            <p class="ks-catalog-result-summary body-text-3 mb-0" aria-live="polite">
                                <asp:Label ID="lblLinee" runat="server" Text="" Visible="false" />
                                <asp:Label ID="lblCatalogSummary" runat="server" Text="Sfoglia il catalogo" />
                            </p>
                        </div>

                        <div class="tf-control-view flat-title-tab-product flex-wrap">
                            <ul class="tf-control-layout menu-tab-line" role="tablist" aria-label="Visualizzazione prodotti">
                                <li role="presentation">
                                    <a href="#" class="ks-view-layout-switch active" data-ks-layout="tabgrid-1" role="tab" aria-label="Vista griglia" aria-pressed="true" aria-selected="true">
                                        <i class="icon-menu-dots" aria-hidden="true"></i>
                                    </a>
                                </li>
                                <li role="presentation">
                                    <a href="#" class="ks-view-layout-switch" data-ks-layout="tabgrid-2" role="tab" aria-label="Vista griglia compatta" aria-pressed="false" aria-selected="false">
                                        <i class="icon-dot-line" aria-hidden="true"></i>
                                    </a>
                                </li>
                                <li role="presentation">
                                    <a href="#" class="ks-view-layout-switch" data-ks-layout="tablist-1" role="tab" aria-label="Vista lista" aria-pressed="false" aria-selected="false">
                                        <i class="icon-list-1" aria-hidden="true"></i>
                                    </a>
                                </li>
                                <li role="presentation">
                                    <a href="#" class="ks-view-layout-switch" data-ks-layout="tablist-2" role="tab" aria-label="Vista lista compatta" aria-pressed="false" aria-selected="false">
                                        <i class="icon-list-2" aria-hidden="true"></i>
                                    </a>
                                </li>
                            </ul>

                            <div class="tf-control-sort type-sort-quatity tf-sort ks-toolbar-select">
                                <i class="icon-menu-dots" aria-hidden="true"></i>
                                <asp:DropDownList ID="Drop_Righe" runat="server" CssClass="ks-toolbar-native-select" AutoPostBack="true" aria-label="Numero prodotti per pagina">
                                    <asp:ListItem Value="12" Text="Mostra: 12"></asp:ListItem>
                                    <asp:ListItem Value="24" Text="Mostra: 24"></asp:ListItem>
                                    <asp:ListItem Value="48" Text="Mostra: 48"></asp:ListItem>
                                    <asp:ListItem Value="96" Text="Mostra: 96"></asp:ListItem>
                                </asp:DropDownList>
                                <i class="icon-arrow-down" aria-hidden="true"></i>
                            </div>

                            <div class="tf-control-sort type-sort-by ks-sort-control">
                                <div class="tf-sort ks-toolbar-select ks-sort-native-control">
                                    <i class="icon-sort" aria-hidden="true"></i>
                                    <span class="ks-toolbar-select-label" aria-hidden="true">Ordina:</span>
                                    <asp:DropDownList ID="Drop_Ordinamento" runat="server" CssClass="ks-toolbar-native-select" AutoPostBack="true" aria-label="Ordinamento prodotti">
                                        <asp:ListItem Value="" Text="Consigliati"></asp:ListItem>
                                        <asp:ListItem Value="P_basso" Text="Prezzo crescente"></asp:ListItem>
                                        <asp:ListItem Value="P_alto" Text="Prezzo decrescente"></asp:ListItem>
                                        <asp:ListItem Value="P_offerta" Text="Offerte"></asp:ListItem>
                                        <asp:ListItem Value="P_disponibilita" Text="Disponibilita"></asp:ListItem>
                                        <asp:ListItem Value="P_recenti" Text="Novita"></asp:ListItem>
                                        <asp:ListItem Value="P_popolarita" Text="Popolarita"></asp:ListItem>
                                        <asp:ListItem Value="P_codice" Text="Codice"></asp:ListItem>
                                        <asp:ListItem Value="P_descrizione" Text="Nome"></asp:ListItem>
                                    </asp:DropDownList>
                                    <i class="icon-arrow-down" aria-hidden="true"></i>
                                </div>

                                <div class="tf-dropdown-sort tf-sort ks-sort-dropdown" data-ks-sort-dropdown>
                                    <button type="button" class="btn-select ks-sort-trigger" aria-label="Ordina prodotti. Selezione attuale: Consigliati" aria-haspopup="listbox" aria-expanded="false" aria-controls="ksCatalogSortMenu">
                                        <i class="ks-sort-trigger-icon icon-sort" aria-hidden="true"></i>
                                        <span class="ks-sort-trigger-label" aria-hidden="true">Ordina:</span>
                                        <span class="ks-sort-trigger-value">Consigliati</span>
                                        <i class="icon-arrow-down ks-sort-trigger-arrow" aria-hidden="true"></i>
                                    </button>
                                    <div id="ksCatalogSortMenu" class="dropdown-menu ks-sort-menu" role="listbox" aria-label="Criterio di ordinamento">
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="true" data-ks-sort-value="" data-ks-sort-icon="icon-sort"><i class="icon-sort" aria-hidden="true"></i><span>Consigliati</span></button>
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="false" data-ks-sort-value="P_basso" data-ks-sort-icon="icon-money-bag"><i class="icon-money-bag" aria-hidden="true"></i><span>Prezzo crescente</span></button>
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="false" data-ks-sort-value="P_alto" data-ks-sort-icon="icon-money-bag"><i class="icon-money-bag" aria-hidden="true"></i><span>Prezzo decrescente</span></button>
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="false" data-ks-sort-value="P_offerta" data-ks-sort-icon="icon-fire"><i class="icon-fire" aria-hidden="true"></i><span>Offerte</span></button>
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="false" data-ks-sort-value="P_disponibilita" data-ks-sort-icon="icon-check"><i class="icon-check" aria-hidden="true"></i><span>Disponibilita</span></button>
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="false" data-ks-sort-value="P_recenti" data-ks-sort-icon="icon-clock"><i class="icon-clock" aria-hidden="true"></i><span>Novita</span></button>
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="false" data-ks-sort-value="P_popolarita" data-ks-sort-icon="icon-star"><i class="icon-star" aria-hidden="true"></i><span>Popolarita</span></button>
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="false" data-ks-sort-value="P_codice" data-ks-sort-icon="icon-sort"><i class="icon-sort" aria-hidden="true"></i><span>Codice</span></button>
                                        <button type="button" class="ks-sort-option" role="option" aria-selected="false" data-ks-sort-value="P_descrizione" data-ks-sort-icon="icon-sort"><i class="icon-sort" aria-hidden="true"></i><span>Nome</span></button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div id="ksActiveFilters" class="meta-filter-shop ks-active-filters" runat="server" Visible="false">
                        <div id="applied-filters">
                            <asp:Repeater ID="rptActiveFilters" runat="server">
                                <ItemTemplate>
                                    <a class="ks-applied-filter" href='<%# Server.HtmlEncode(Convert.ToString(Eval("RemoveUrl"))) %>'>
                                        <span class="caption"><%# Server.HtmlEncode(Convert.ToString(Eval("Label"))) %></span>
                                        <i class="icon icon-close" aria-hidden="true"></i>
                                    </a>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>

                        <a id="remove-all" class="remove-all-filters" href="<%= Server.HtmlEncode(ClearCatalogFiltersUrl) %>">
                            <span class="caption">Rimuovi tutto</span>
                            <i class="icon icon-close" aria-hidden="true"></i>
                        </a>
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
                                <div class='<%# CatalogCardCss(Container.DataItem) %>'>
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
                                                    <span class="tooltip">Aggiungi al carrello</span>
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
                                                <a href="#compare" data-bs-toggle="offcanvas" data-bs-target="#compare" aria-controls="compare"
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
                                                <p class="product-tag caption text-main-2 ks-card-category">
                                                    <%# Server.HtmlEncode(CatalogCategoryLabel(Container.DataItem)) %>
                                                </p>

                                                <a class="name-product body-md-2 fw-semibold text-secondary link ks-card-title" href='<%# CatalogProductUrl(Container.DataItem) %>'>
                                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
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
                                            <%# CatalogPromoDetailsHtml(Container.DataItem) %>
                                        </div>

                                        <div class="box-infor-detail">
                                            <ul class="list-infor-fearture">
                                                <li>
                                                    <p class="caption name-feature">Codice:</p>
                                                    <p class="caption property"><%# Server.HtmlEncode(UiData.Str(Container.DataItem, "Codice")) %></p>
                                                </li>
                                                <li class="ks-catalog-availability-row">
                                                    <%# CatalogAvailabilityHtml(Container.DataItem) %>
                                                </li>
                                            </ul>

                                            <div class='<%# CatalogQuantityBoxCss(Container.DataItem) %>' <%# CatalogQuantityBoxAttributes(Container.DataItem) %>>
                                                <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" CssClass="form-check-input" />
                                                <asp:TextBox ID="tbQuantita" runat="server" CssClass='<%# CatalogQuantityInputCss(Container.DataItem) %>' Text='<%# CatalogQuantityInputValue(Container.DataItem) %>' Width="70" data-ks-existing-cart-qty='<%# CatalogQuantityInputExistingQty(Container.DataItem) %>' />
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
                                    <div class="heading">Non abbiamo trovato prodotti per la tua ricerca</div>
                                    <asp:PlaceHolder ID="phEmptySearchQuery" runat="server" Visible="false">
                                        <p class="text-main-2 mt-2 mb-0">Ricerca: <strong><asp:Literal ID="litEmptySearchQuery" runat="server" /></strong></p>
                                    </asp:PlaceHolder>
                                    <p class="text-main-2 mt-2 mb-0">Controlla le parole chiave, prova termini piu generici o rimuovi i filtri applicati.</p>
                                    <div class="mt-4 d-flex flex-wrap gap-2 justify-content-center">
                                        <a class="tf-btn btn-fill" href="articoli.aspx">Reset filtri</a>
                                        <a class="tf-btn btn-line" href="articoli.aspx">Vai al catalogo</a>
                                    </div>
                                    <div class="mt-3 d-flex flex-wrap gap-2 justify-content-center">
                                        <asp:Literal ID="litEmptySearchLinks" runat="server" />
                                    </div>
                                </div>
                            </EmptyDataTemplate>
                        </asp:ListView>
                    </div>

                    <asp:Panel ID="ksMultiFooter" runat="server" ClientIDMode="Static" CssClass="mt-4 ks-multi-footer" Visible="false">
                        <div class="ks-multi-footer__content">
                            <div>
                                <p class="ks-multi-footer__title">
                                    <span class="ks-multi-select-icon" aria-hidden="true"></span>
                                    Acquisto multiplo
                                </p>
                                <p class="ks-multi-footer__text">Spunta la casella Seleziona sui prodotti desiderati, imposta le quantita e aggiungili insieme al carrello.</p>
                                <ul class="ks-multi-footer__steps" aria-label="Come funziona l'acquisto multiplo">
                                    <li><span>1</span>Spunta Seleziona</li>
                                    <li><span>2</span>Modifica le quantita</li>
                                    <li><span>3</span>Premi il pulsante</li>
                                </ul>
                                <asp:Label ID="lblMultiSelectFeedback" runat="server" CssClass="ks-multi-footer__feedback" Visible="false" />
                            </div>
                            <asp:LinkButton ID="btnAggiungiSelezionati" runat="server"
                                CssClass="tf-btn btn-fill ks-multi-footer__cta"
                                CausesValidation="false"
                                OnClick="Selezione_Multipla_Button_Click">
                                Aggiungi selezionati al carrello
                            </asp:LinkButton>
                        </div>
                    </asp:Panel>

                    <asp:Panel ID="ksPagerWrap" runat="server" ClientIDMode="Static" CssClass="ks-catalog-pager-wrap" Visible="false">
                        <span class="ks-catalog-pager__engine" aria-hidden="true">
                            <asp:DataPager ID="dpProdotti" runat="server" PagedControlID="lvProdotti" PageSize="12" EnableViewState="false" />
                        </span>
                        <asp:Literal ID="litCatalogPager" runat="server" EnableViewState="false" />
                    </asp:Panel>

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
    <script src="<%= ThemeManager.Asset("js/catalog-product-flow.js") %>?v=20260831-mediasort1"></script>
    <script src="<%= ThemeManager.Asset("js/keepstore-product.js") %>?v=20260902-catalogasynccart1a"></script>
    <script src="<%= ThemeManager.Asset("js/keepstore-recently-viewed.js") %>?v=20260902-cardlayout1a"></script>
</asp:Content>
