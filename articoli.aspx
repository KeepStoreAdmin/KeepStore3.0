<%@ Page Title="" Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Web" %>
<%@ Register Src="~/Public/ui/controls/Breadcrumb.ascx" TagPrefix="ks" TagName="Breadcrumb" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Public/assets/keepstore/css/catalog-ui.css" />
    <link rel="stylesheet" href="/Public/assets/keepstore/css/catalog-filters-ui.css" />
    <link rel="stylesheet" href="/Public/assets/keepstore/css/catalog-product-flow.css" />
    <script src="/Public/assets/keepstore/js/catalog-product-flow.js" defer></script>

    <%-- SEO slot injected by articoli.aspx.vb (robots/canonical, etc.) --%>
    <asp:Literal ID="litSeoHead" runat="server" />
</asp:Content>

<asp:Content ID="BreadcrumbContent" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <ks:Breadcrumb runat="server" ID="bcCatalogo" />
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <%-- Hidden helpers required by VB logic (no UI) --%>
    <asp:Panel ID="tNavig" runat="server" CssClass="d-none" />
    <asp:Label ID="lblRicerca" runat="server" CssClass="d-none" />
    <asp:Label ID="lblTrovati" runat="server" CssClass="d-none" />

    <%-- Categoria helper (Title/SEO) --%>
    <asp:FormView ID="FormView1" runat="server" Visible="false">
        <ItemTemplate>
            <asp:Label ID="lblCategoria" runat="server" Text="" />
        </ItemTemplate>
    </asp:FormView>

    <section class="tf-sp-2">
        <div class="container">

            <div class="d-flex align-items-start align-items-md-center justify-content-between gap-2 flex-wrap mb-3 ks-catalog-toolbar">
                <div>
                    <h1 class="tf-title mb-1">Catalogo</h1>
                    <div class="text-muted small">
                        <asp:Label ID="lblRisultati" runat="server" Text=""></asp:Label>
                    </div>
                </div>

                <div class="d-flex align-items-center gap-2 flex-wrap">

                    <!-- Mobile filters trigger -->
                    <button id="ksToolbarFiltersBtn" class="btn btn-outline-secondary d-lg-none" type="button">
                        <i class="icon icon-filter"></i>
                        Filtri
                    </button>

                    <div class="d-flex align-items-center gap-2">
                        <label class="text-muted small mb-0" for="<%= Drop_Ordinamento.ClientID %>">Ordina</label>
                        <asp:DropDownList ID="Drop_Ordinamento" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true">
                            <asp:ListItem Value="0" Text="Consigliati"></asp:ListItem>
                            <asp:ListItem Value="1" Text="Prezzo: crescente"></asp:ListItem>
                            <asp:ListItem Value="2" Text="Prezzo: decrescente"></asp:ListItem>
                            <asp:ListItem Value="3" Text="Disponibilità"></asp:ListItem>
                        </asp:DropDownList>
                    </div>

                    <div class="d-flex align-items-center gap-2">
                        <label class="text-muted small mb-0" for="<%= Drop_Righe.ClientID %>">Righe</label>
                        <asp:DropDownList ID="Drop_Righe" runat="server" CssClass="form-select form-select-sm" AutoPostBack="true">
                            <asp:ListItem Value="12" Text="12"></asp:ListItem>
                            <asp:ListItem Value="24" Text="24"></asp:ListItem>
                            <asp:ListItem Value="48" Text="48"></asp:ListItem>
                            <asp:ListItem Value="96" Text="96"></asp:ListItem>
                        </asp:DropDownList>
                        <asp:Label ID="lblLinee" runat="server" Text="" CssClass="d-none" />
                    </div>

                </div>
            </div>

            <div class="row g-4">

                <!-- Filters sidebar (desktop) -->
                <div class="col-12 col-lg-3 d-none d-lg-block">
                    <div class="card">
                        <div class="card-body">
                            <div class="d-flex align-items-center justify-content-between mb-3">
                                <div class="fw-semibold">Filtri</div>
                                <a class="small text-decoration-none js-ks-reset-filters" href="#">Reset</a>
                            </div>

                            <div class="form-check mb-3" id="filtersDisp">
                                <asp:CheckBox ID="CheckBox_Disponibile" runat="server" CssClass="form-check-input" AutoPostBack="true" />
                                <label class="form-check-label" for="<%= CheckBox_Disponibile.ClientID %>">Solo disponibili</label>
                            </div>

                            <asp:Panel ID="filtritagliaecolore" runat="server" CssClass="mb-3" Visible="false">
                                <div class="mb-2">
                                    <label class="form-label small text-muted" for="<%= Drop_Filtra_Taglia.ClientID %>">Taglia</label>
                                    <asp:DropDownList ID="Drop_Filtra_Taglia" runat="server" CssClass="form-select" AutoPostBack="true" />
                                </div>
                                <div>
                                    <label class="form-label small text-muted" for="<%= Drop_Filtra_Colore.ClientID %>">Colore</label>
                                    <asp:DropDownList ID="Drop_Filtra_Colore" runat="server" CssClass="form-select" AutoPostBack="true" />
                                </div>
                            </asp:Panel>

                            <!-- Advanced filters (server-driven, no VB changes) -->
                            <div class="ks-filter-group" id="filtersMr">
                                <asp:DataList ID="DataList1" runat="server" DataSourceID="sdsMarche" RepeatLayout="Flow">
                                    <ItemTemplate>
                                        <div class="form-check d-flex align-items-start gap-2 ks-filter-item">
                                            <asp:CheckBox ID="CheckBoxMr" runat="server"
                                                CssClass="form-check-input"
                                                AutoPostBack="true"
                                                OnCheckedChanged="CheckBoxMr_CheckedChanged"
                                                filterId='<%# Eval("MarcheId") %>'
                                                Checked='<%# (("|" & Convert.ToString(Request.QueryString("mr")) & "|").Contains("|" & Convert.ToString(Eval("MarcheId")) & "|")) %>' />
                                            <div class="flex-grow-1">
                                                <asp:Label ID="lblMr" runat="server" AssociatedControlID="CheckBoxMr" CssClass="form-check-label"
                                                    Text='<%# HttpUtility.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %>' />
                                            </div>
                                            <span class="badge bg-light text-muted"><%# Eval("Numero") %></span>
                                        </div>
                                    </ItemTemplate>
                                </asp:DataList>
                            </div>

                            <div class="ks-filter-group" id="filtersTp">
                                <asp:DataList ID="DataList2" runat="server" DataSourceID="sdsTipologie" RepeatLayout="Flow">
                                    <ItemTemplate>
                                        <div class="form-check d-flex align-items-start gap-2 ks-filter-item">
                                            <asp:CheckBox ID="CheckBoxTp" runat="server"
                                                CssClass="form-check-input"
                                                AutoPostBack="true"
                                                OnCheckedChanged="CheckBoxTp_CheckedChanged"
                                                filterId='<%# Eval("TipologieId") %>'
                                                Checked='<%# (("|" & Convert.ToString(Request.QueryString("tp")) & "|").Contains("|" & Convert.ToString(Eval("TipologieId")) & "|")) %>' />
                                            <div class="flex-grow-1">
                                                <asp:Label ID="lblTp" runat="server" AssociatedControlID="CheckBoxTp" CssClass="form-check-label"
                                                    Text='<%# HttpUtility.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %>' />
                                            </div>
                                            <span class="badge bg-light text-muted"><%# Eval("Numero") %></span>
                                        </div>
                                    </ItemTemplate>
                                </asp:DataList>
                            </div>

                            <div class="ks-filter-group" id="filtersGr">
                                <asp:DataList ID="DataList3" runat="server" DataSourceID="sdsGruppo" RepeatLayout="Flow">
                                    <ItemTemplate>
                                        <div class="form-check d-flex align-items-start gap-2 ks-filter-item">
                                            <asp:CheckBox ID="CheckBoxGr" runat="server"
                                                CssClass="form-check-input"
                                                AutoPostBack="true"
                                                OnCheckedChanged="CheckBoxGr_CheckedChanged"
                                                filterId='<%# Eval("GruppiId") %>'
                                                Checked='<%# (("|" & Convert.ToString(Request.QueryString("gr")) & "|").Contains("|" & Convert.ToString(Eval("GruppiId")) & "|")) %>' />
                                            <div class="flex-grow-1">
                                                <asp:Label ID="lblGr" runat="server" AssociatedControlID="CheckBoxGr" CssClass="form-check-label"
                                                    Text='<%# HttpUtility.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %>' />
                                            </div>
                                            <span class="badge bg-light text-muted"><%# Eval("Numero") %></span>
                                        </div>
                                    </ItemTemplate>
                                </asp:DataList>
                            </div>

                            <div class="ks-filter-group" id="filtersSg">
                                <asp:DataList ID="DataList4" runat="server" DataSourceID="sdsSottogruppo" RepeatLayout="Flow">
                                    <ItemTemplate>
                                        <div class="form-check d-flex align-items-start gap-2 ks-filter-item">
                                            <asp:CheckBox ID="CheckBoxSg" runat="server"
                                                CssClass="form-check-input"
                                                AutoPostBack="true"
                                                OnCheckedChanged="CheckBoxSg_CheckedChanged"
                                                filterId='<%# Eval("SottogruppiId") %>'
                                                Checked='<%# (("|" & Convert.ToString(Request.QueryString("sg")) & "|").Contains("|" & Convert.ToString(Eval("SottogruppiId")) & "|")) %>' />
                                            <div class="flex-grow-1">
                                                <asp:Label ID="lblSg" runat="server" AssociatedControlID="CheckBoxSg" CssClass="form-check-label"
                                                    Text='<%# HttpUtility.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %>' />
                                            </div>
                                            <span class="badge bg-light text-muted"><%# Eval("Numero") %></span>
                                        </div>
                                    </ItemTemplate>
                                </asp:DataList>
                            </div>

                        </div>
                    </div>
                </div>

                <!-- Products grid -->
                <div class="col-12 col-lg-9">

                    <div class="d-flex justify-content-end mb-2">
                        <asp:Label ID="lblPrezzi" runat="server" CssClass="text-muted small" Text=""></asp:Label>
                    </div>

                    <asp:ListView ID="lvProdotti" runat="server" DataSourceID="sdsArticoli" OnPreRender="lvProdotti_PreRender">
                        <LayoutTemplate>
                            <div class="row g-3" id="ksProductsGrid">
                                <asp:PlaceHolder ID="itemPlaceholder" runat="server" />
                            </div>
                        </LayoutTemplate>

                        <ItemTemplate>
                            <div class="col-6 col-md-4">
                                <div class="card ks-product-card h-100">
                                    <a class="d-block" href='<%# "/articolo.aspx?id=" & Eval("id") %>'>
                                        <img class="ks-product-img"
                                             alt='<%# HttpUtility.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                                             src='<%# ResolveUrl(checkImg(Eval("Img1"))) %>' />
                                    </a>

                                    <div class="card-body p-3 d-flex flex-column">
                                        <a class="text-decoration-none" href='<%# "/articolo.aspx?id=" & Eval("id") %>'>
                                            <div class="ks-product-title">
                                                <%# HttpUtility.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                            </div>
                                        </a>

                                        <div class="price-wrap fw-medium mt-1">
                                            <%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %>
                                        </div>

                                        <div class="mt-auto d-flex align-items-center gap-2 pt-2">
                                            <asp:TextBox ID="tbQuantita" runat="server" Text="1" CssClass="form-control form-control-sm ks-qty" />

                                            <asp:LinkButton ID="LB_AddToCart" runat="server"
                                                CssClass="btn btn-primary btn-sm flex-grow-1"
                                                CausesValidation="false"
                                                OnClick="LB_AddToCart_Click">
                                                Aggiungi
                                            </asp:LinkButton>

                                            <asp:LinkButton ID="LB_wishlist" runat="server"
                                                CssClass="btn btn-outline-secondary btn-sm"
                                                CausesValidation="false"
                                                OnClick="BT_Aggiungi_wishlist_Click"
                                                ToolTip="Aggiungi alla wishlist">
                                                ♥
                                            </asp:LinkButton>
                                        </div>

                                        <%-- helper fields used by VB helpers --%>
                                        <asp:HiddenField ID="hfID" runat="server" Value='<%# Eval("id") %>' />
                                        <asp:HiddenField ID="hfTCId" runat="server" Value='<%# If(Eval("TCid") Is Nothing OrElse Convert.IsDBNull(Eval("TCid")), "-1", Eval("TCid")) %>' />
                                        <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" CssClass="d-none" />
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>

                        <EmptyDataTemplate>
                            <div class="alert alert-light border">
                                Nessun prodotto trovato con i filtri selezionati.
                            </div>
                        </EmptyDataTemplate>

                    </asp:ListView>

                    <div class="d-flex align-items-center justify-content-between flex-wrap gap-2 mt-4" id="ksPagerWrap" runat="server">
                        <asp:DataPager ID="dpProdotti" runat="server" PagedControlID="lvProdotti" PageSize="12" CssClass="pagination ks-pager">
                            <Fields>
                                <asp:NextPreviousPagerField ButtonType="Link" ShowPreviousPageButton="true" ShowNextPageButton="false" PreviousPageText="&laquo;" />
                                <asp:NumericPagerField ButtonType="Link" ButtonCount="7" />
                                <asp:NextPreviousPagerField ButtonType="Link" ShowPreviousPageButton="false" ShowNextPageButton="true" NextPageText="&raquo;" />
                            </Fields>
                        </asp:DataPager>

                        <asp:Panel ID="ksMultiFooter" runat="server" CssClass="d-flex align-items-center gap-2" Visible="false">
                            <asp:ImageButton ID="IB_SelezioneMultipla" runat="server"
                                CssClass="btn btn-outline-primary btn-sm"
                                ImageUrl="/Public/assets/keepstore/images/keepstore/placeholder.png"
                                AlternateText="Aggiungi selezione al carrello"
                                CausesValidation="false"
                                OnClick="Selezione_Multipla_Click" />
                        </asp:Panel>
                    </div>


                </div>

            </div>

            <%-- DataSources required by VB (commands/params set in VB) --%>
            <asp:SqlDataSource ID="sdsArticoli" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" />

            <asp:SqlDataSource ID="sdsMarche" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" />

            <asp:SqlDataSource ID="sdsTipologie" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" />

            <asp:SqlDataSource ID="sdsGruppo" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" />

            <asp:SqlDataSource ID="sdsSottogruppo" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" />

        </div>
    </section>

</asp:Content>

<asp:Content ID="ScriptsContent" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="/Public/assets/keepstore/js/catalog-ui.js"></script>
</asp:Content>
