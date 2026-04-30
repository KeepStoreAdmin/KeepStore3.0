<%@ Page Title="Catalogo" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" %>

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

    <!-- PAGE TITLE / SUMMARY (kept for VB codebehind compatibility) -->
    <asp:Panel ID="ksPageTitle" runat="server" CssClass="tf-page-title">
        <div class="container">
            <div class="d-flex flex-wrap align-items-end justify-content-between gap-2">
                <div>
                    <h1 class="title">Catalogo</h1>
                    <div class="text-muted small">
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

    <!-- SHOP DEFAULT LAYOUT -->
    <section class="flat-spacing-2">
        <div class="container">

            <!-- CONTROL BAR -->
	            <div class="tf-shop-control-wrapper mb-3">
	                <div class="tf-shop-control">
	                    <div class="tf-control-filter">
	                        <a class="tf-btn-filter" href="#filterShop" data-bs-toggle="offcanvas" role="button" aria-controls="filterShop">
	                            <span class="icon icon-filter"></span>
	                            <span class="text">Filtri</span>
	                        </a>
	                    </div>
	
	                    <div class="tf-control-view">
	                        <div class="tf-control-show">
	                            <div class="text">Mostra</div>
	                            <asp:DropDownList ID="Drop_Righe" runat="server" CssClass="select-show" AutoPostBack="true">
	                                <asp:ListItem Value="12" Text="12"></asp:ListItem>
	                                <asp:ListItem Value="24" Text="24"></asp:ListItem>
	                                <asp:ListItem Value="48" Text="48"></asp:ListItem>
	                                <asp:ListItem Value="96" Text="96"></asp:ListItem>
	                            </asp:DropDownList>
	                            <asp:Label ID="lblLinee" runat="server" Text="" CssClass="d-none" />
	                        </div>
	
	                        <div class="tf-control-sorting">
	                            <div class="text">Ordina</div>
	                            <asp:DropDownList ID="Drop_Ordinamento" runat="server" CssClass="select-sorting" AutoPostBack="true">
	                                <asp:ListItem Value="0" Text="Consigliati"></asp:ListItem>
	                                <asp:ListItem Value="1" Text="Prezzo: crescente"></asp:ListItem>
	                                <asp:ListItem Value="2" Text="Prezzo: decrescente"></asp:ListItem>
	                                <asp:ListItem Value="3" Text="Disponibilità"></asp:ListItem>
	                            </asp:DropDownList>
	                        </div>
	
	                        <div class="tf-control-availability d-none d-xl-flex align-items-center">
	                            <div class="text">Disponibilità</div>
	                            <div class="tf-check">
	                                <asp:CheckBox ID="CheckBox_Disponibile" runat="server" Text="Solo disponibili" AutoPostBack="true" />
	                            </div>
	                        </div>
	                    </div>
	                </div>

                <div class="tf-shop-control-right">
                    <!-- Placeholder: if you later want to add view toggles / layout switch, this is the right slot -->
                </div>
            </div>

            <!-- ACTIVE FILTERS (from Step 31/32) -->
            <div id="ksActiveFilters" class="mb-3" runat="server" Visible="false">
                <div class="d-flex flex-wrap gap-2 align-items-center">
                    <asp:Repeater ID="rptActiveFilters" runat="server">
                        <ItemTemplate>
                            <asp:LinkButton ID="lbRemove" runat="server" CssClass="badge rounded-pill text-bg-secondary" CommandName="remove" CommandArgument='<%# Eval("Key") %>'>
                                <%# Eval("Label") %> <span class="ms-1">×</span>
                            </asp:LinkButton>
                        </ItemTemplate>
                    </asp:Repeater>

                    <asp:LinkButton ID="lbClearAllFilters" runat="server" CssClass="badge rounded-pill text-bg-dark" CommandName="clear" Visible="false">
                        Pulisci tutto
                    </asp:LinkButton>
                </div>
            </div>

            <!-- PRODUCT GRID -->
            <div class="wrapper-control-shop">
                <asp:ListView ID="lvProdotti" runat="server" DataSourceID="sdsArticoli">
                    <LayoutTemplate>
                        <div id="gridLayout" class="tf-grid-layout lg-col-4 md-col-3 sm-col-2 flat-grid-product wrapper-shop layout-tabgrid-1">
                            <asp:PlaceHolder ID="itemPlaceholder" runat="server" />
                        </div>
                    </LayoutTemplate>

                    <ItemTemplate>
	                        <div class="card-product style-1">
	                            <div class="card-product-wrapper overflow-visible">

	                                <div class="product-thumb-image">
	                                    <a href='<%# "articolo.aspx?id=" & Eval("id") %>' class="card-image">
	                                        <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
	                                             src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>'
	                                             data-src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
	                                    </a>
	                                    <ul class="list-image-product">
	                                        <li class="image-swap active">
	                                            <img class="lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
	                                                 src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>'
	                                                 data-src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
	                                        </li>
	                                        <li class="image-swap">
	                                            <img class="lazyload" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
	                                                 src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>'
	                                                 data-src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
	                                        </li>
	                                    </ul>
	                                </div>

	                                <ul class="list-product-btn top-0 end-0">
	                                    <li>
	                                        <asp:LinkButton ID="btnAdd" runat="server" CommandArgument='<%# Eval("id") %>'
	                                            CssClass="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left"
	                                            OnClick="LB_AddToCart_Click" CausesValidation="False" ToolTip="Aggiungi al carrello">
	                                            <i class="icon icon-cart2"></i>
	                                            <span class="tooltip">Carrello</span>
	                                        </asp:LinkButton>
	                                    </li>
	                                    <li class="wishlist">
	                                        <asp:LinkButton ID="LB_wishlist" runat="server" CommandArgument='<%# Eval("id") %>'
	                                            CssClass="box-icon btn-icon-action hover-tooltip tooltip-left"
	                                            OnClick="BT_Aggiungi_wishlist_Click" CausesValidation="False" ToolTip="Aggiungi alla wishlist">
	                                            <i class="icon icon-heart2"></i>
	                                            <span class="tooltip">Wishlist</span>
	                                        </asp:LinkButton>
	                                    </li>
	                                    <li>
	                                        <a href='<%# "articolo.aspx?id=" & Eval("id") %>' class="box-icon btn-icon-action hover-tooltip tooltip-left">
	                                            <i class="icon icon-view"></i>
	                                            <span class="tooltip">Dettagli</span>
	                                        </a>
	                                    </li>
	                                </ul>

	                                <asp:PlaceHolder ID="phRefurbBadge" runat="server"
                                        Visible='<%# UiData.Bool(Container.DataItem, "Ricondizionato") OrElse UiData.Int(Container.DataItem, "st") = 34 OrElse UiData.Int(Container.DataItem, "SettoriId") = 34 %>'>
                                        <div class='box-sale-wrap pst-default'>
                                            <p class='small-text ks-badge-refurb'>Ricondizionato</p>
                                        </div>
                                    </asp:PlaceHolder>

                                    <%# If(Val(Eval("InOfferta")) = 1, "<div class='box-sale-wrap pst-default'><p class='small-text'>Sale</p></div>", "") %>

	                                <!-- Required by codebehind -->
	                                <asp:HiddenField ID="hfID" runat="server" Value='<%# Eval("id") %>' />
	                                <asp:HiddenField ID="hfTCId" runat="server" Value='<%# Eval("TCId") %>' />
	                            </div>

	                            <div class="card-product-info">
	                                <a class="name-product body-md-2 fw-semibold text-secondary link" href='<%# "articolo.aspx?id=" & Eval("id") %>'>
                                    <%# Server.HtmlEncode(ThemeManager.CompactText(Eval("Descrizione1"), 70)) %>
                                </a>

	                                <p class="price-wrap fw-medium mt-1">
                                    <%# UiPriceFormatter.RenderPriceHtml(
                                            If(IsDBNull(Eval("Prezzo")), 0, Eval("Prezzo")),
                                            If(IsDBNull(Eval("PrezzoIvato")), 0, Eval("PrezzoIvato")),
                                            If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")),
                                            If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")),
                                            Val(Eval("InOfferta")),
                                            Session("IvaTipo")
                                        ) %>
	                                </p>

                                <!-- Multi-select / quantity (kept, but visually compact) -->
                                <div class="d-flex align-items-center gap-2 mt-2">
                                    <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" CssClass="form-check-input" />
                                    <asp:TextBox ID="tbQuantita" runat="server" CssClass="form-control form-control-sm" Text="1" Width="70" />
                                </div>
                            </div>
                        </div>
                    </ItemTemplate>

                    <EmptyDataTemplate>
                        <div class="alert alert-warning">Nessun prodotto trovato con i filtri selezionati.</div>
                    </EmptyDataTemplate>
                </asp:ListView>

                <!-- PAGER (used by codebehind) -->
	                <asp:Panel ID="ksPagerWrap" runat="server" CssClass="wrap-pagination d-flex justify-content-center mt-4">
                    <asp:DataPager ID="dpProdotti" runat="server" PagedControlID="lvProdotti" PageSize="12">
                        <Fields>
	                            <asp:NextPreviousPagerField ShowFirstPageButton="false" ShowPreviousPageButton="true" ShowNextPageButton="false" ShowLastPageButton="false" ButtonType="Link" PreviousPageText="&laquo;" ButtonCssClass="pagination-link" />
	                            <asp:NumericPagerField ButtonType="Link" ButtonCount="7" NumericButtonCssClass="pagination-link" CurrentPageLabelCssClass="pagination-link active" />
	                            <asp:NextPreviousPagerField ShowFirstPageButton="false" ShowPreviousPageButton="false" ShowNextPageButton="true" ShowLastPageButton="false" ButtonType="Link" NextPageText="&raquo;" ButtonCssClass="pagination-link" />
                        </Fields>
                    </asp:DataPager>
                </asp:Panel>

                <!-- Optional multi-add footer used by codebehind -->
                <asp:Panel ID="ksMultiFooter" runat="server" CssClass="mt-4" Visible="false">
                    <div class="alert alert-info">Selezione multipla attiva: scegli le quantità e aggiungi al carrello.</div>
                </asp:Panel>

                <!-- Legacy navigation container referenced in codebehind -->
                <asp:Panel ID="tNavig" runat="server" Visible="false" />
            </div>

        </div>
    </section>

	    <!-- FILTER CANVAS (Shop Default) -->
	    <div class="offcanvas offcanvas-start canvas-filter-product sidebar-filter handle-canvas left" tabindex="-1" id="filterShop" aria-labelledby="filterShopLabel">
	        <div class="canvas-wrapper">
	            <div class="canvas-header d-flex d-xl-none">
	                <span class="title fw-semibold" id="filterShopLabel">Filtri</span>
	                <span class="icon-close link" data-bs-dismiss="offcanvas" aria-label="Chiudi"></span>
	            </div>
	
	            <div class="canvas-body">
            <asp:Panel ID="ksFilters" runat="server">

                <div class="mb-4">
                    <h6 class="mb-2">Categorie</h6>
                    <asp:FormView ID="FormView1" runat="server" DataSourceID="sdsGruppo">
                        <ItemTemplate>
                            <asp:Label ID="lblCategoria" runat="server" Text='<%# Eval("descrizione") %>' Visible="false" />
                        </ItemTemplate>
                    </asp:FormView>

                    <asp:DataList ID="DataList1" runat="server" DataSourceID="sdsGruppo" RepeatLayout="Flow" CssClass="ks-filter-list">
                        <ItemTemplate>
                            <div class="form-check">
                                <a class='form-check-label ks-filter-option<%# If(ThemeManager.CatalogFilterSelected("gr", Container.DataItem), " active", "") %>' href='<%# ThemeManager.CatalogFilterUrl("gr", Container.DataItem) %>'><%# Eval("descrizione") %></a>
                            </div>
                        </ItemTemplate>
                    </asp:DataList>
                </div>

                <div class="mb-4">
                    <h6 class="mb-2">Sottocategorie</h6>
                    <asp:DataList ID="DataList4" runat="server" DataSourceID="sdsSottogruppo" RepeatLayout="Flow" CssClass="ks-filter-list">
                        <ItemTemplate>
                            <div class="form-check">
                                <a class='form-check-label ks-filter-option<%# If(ThemeManager.CatalogFilterSelected("sg", Container.DataItem), " active", "") %>' href='<%# ThemeManager.CatalogFilterUrl("sg", Container.DataItem) %>'><%# Eval("descrizione") %></a>
                            </div>
                        </ItemTemplate>
                    </asp:DataList>
                </div>

                <div class="mb-4">
                    <h6 class="mb-2">Marche</h6>
                    <asp:DataList ID="DataList2" runat="server" DataSourceID="sdsMarche" RepeatLayout="Flow" CssClass="ks-filter-list">
                        <ItemTemplate>
                            <div class="form-check">
                                <a class='form-check-label ks-filter-option<%# If(ThemeManager.CatalogFilterSelected("mr", Container.DataItem), " active", "") %>' href='<%# ThemeManager.CatalogFilterUrl("mr", Container.DataItem) %>'><%# Eval("descrizione") %></a>
                            </div>
                        </ItemTemplate>
                    </asp:DataList>
                </div>

                <div class="mb-4">
                    <h6 class="mb-2">Tipologie</h6>
                    <asp:DataList ID="DataList3" runat="server" DataSourceID="sdsTipologie" RepeatLayout="Flow" CssClass="ks-filter-list">
                        <ItemTemplate>
                            <div class="form-check">
                                <a class='form-check-label ks-filter-option<%# If(ThemeManager.CatalogFilterSelected("tp", Container.DataItem), " active", "") %>' href='<%# ThemeManager.CatalogFilterUrl("tp", Container.DataItem) %>'><%# Eval("descrizione") %></a>
                            </div>
                        </ItemTemplate>
                    </asp:DataList>
                </div>

                <!-- ADVANCED: size & color (kept, VB uses these IDs) -->
                <asp:Panel ID="filtritagliaecolore" runat="server" Visible="false">
                    <div class="mb-4">
                        <h6 class="mb-2">Taglia</h6>
                        <asp:DropDownList ID="Drop_Filtra_Taglia" runat="server" CssClass="form-select" AutoPostBack="true" />
                    </div>

                    <div class="mb-4">
                        <h6 class="mb-2">Colore</h6>
                        <asp:DropDownList ID="Drop_Filtra_Colore" runat="server" CssClass="form-select" AutoPostBack="true" />
                    </div>
                </asp:Panel>

	                </asp:Panel>
	            </div>
	        </div>
	    </div>

    <!-- DATA SOURCES (IDs required by codebehind) -->
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
</asp:Content>
