<%@ Page Title="" Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" %>
<%@ Import Namespace="System" %>
<%@ Register Src="~/Public/ui/controls/Breadcrumb.ascx" TagPrefix="ks" TagName="Breadcrumb" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Public/assets/keepstore/css/catalog-ui.css" />
    <link rel="stylesheet" href="/Public/assets/keepstore/css/catalog-filters-ui.css" />
</asp:Content>

<asp:Content ID="BreadcrumbContent" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <ks:Breadcrumb runat="server" ID="bcCatalogo" />
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

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

                            <!--
                              Spazi riservati per filtri avanzati.
                              IMPORTANT: Manteniamo invariati controlli/VB. Se in futuro verranno
                              aggiunti repeater/checkbox server-side, inserirli qui senza cambiare ID.
                            -->
                            <div class="ks-filter-group" id="filtersMr">
                                <!-- Marche -->
                            </div>
                            <div class="ks-filter-group" id="filtersTp">
                                <!-- Tipologie -->
                            </div>
                            <div class="ks-filter-group" id="filtersGr">
                                <!-- Gruppi -->
                            </div>
                            <div class="ks-filter-group" id="filtersSg">
                                <!-- Sottogruppi -->
                            </div>

                        </div>
                    </div>
                </div>

                <!-- Products grid -->
                <div class="col-12 col-lg-9">

                    <div class="d-flex justify-content-end mb-2">
                        <asp:Label ID="lblPrezzi" runat="server" CssClass="text-muted small" Text=""></asp:Label>
                    </div>

                    <asp:GridView ID="GridView1" runat="server"
                        AutoGenerateColumns="False"
                        ShowHeader="False"
                        AllowPaging="True"
                        CssClass="ks-gv-grid"
                        PagerStyle-CssClass="ks-gv-pager"
                        GridLines="None">

                        <Columns>
                            <asp:TemplateField>
                                <ItemTemplate>
                                    <div class="card ks-product-card">
                                        <a class="d-block" href='<%# "/articolo.aspx?id=" & Eval("id") %>'>
                                            <img class="ks-product-img" alt='<%# Convert.ToString(Eval("Descrizione1")) %>'
                                                 src='<%# If(Eval("Img1") Is Nothing OrElse Convert.ToString(Eval("Img1")).Trim() = "", "/Public/assets/keepstore/images/keepstore/placeholder.png", Convert.ToString(Eval("Img1")) ) %>' />
                                        </a>
                                        <div class="card-body">
                                            <div class="ks-product-meta mb-1"><%#: Eval("MarcheDescrizione") %></div>
                                            <a class="ks-product-title text-decoration-none d-block" href='<%# "/articolo.aspx?id=" & Eval("id") %>'>
                                                <%#: Eval("Descrizione1") %>
                                            </a>

                                            <div class="text-muted small mt-1"><%#: Eval("Descrizione2") %></div>

                                            <div class="price-wrap">
                                                <%# UiPriceFormatter.RenderPriceHtml(Eval("Prezzo"), Eval("PrezzoIvato"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"), Eval("InOfferta"), Session("IvaTipo")) %>
                                            </div>

                                            <div class="text-muted small mt-2">
                                                <span>Disponibilità:</span>
                                                <span class="fw-semibold"><%#: Eval("Disponibilita") %></span>
                                            </div>
                                        </div>
                                    </div>
                                </ItemTemplate>
                            </asp:TemplateField>
                        </Columns>

                        <EmptyDataTemplate>
                            <div class="alert alert-light border mt-2">
                                Nessun articolo trovato con i filtri selezionati.
                            </div>
                        </EmptyDataTemplate>

                    </asp:GridView>

                    <%--
                        Legacy compat: alcuni rami della logica VB (articoli.aspx.vb)
                        si aspettano un DataPager con ID "dpProdotti" per gestire PageSize.
                        Qui lo dichiariamo senza impattare la UI (il paging reale resta su GridView).
                    --%>
                    <asp:DataPager ID="dpProdotti" runat="server" PageSize="12" Visible="false" />

                </div>

            </div>

        </div>
    </section>

</asp:Content>

<asp:Content ID="ScriptsContent" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="/Public/assets/keepstore/js/catalog-ui.js"></script>
</asp:Content>
