<%@ Page Title="" Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="Articolo" %>
<%@ Import Namespace="System" %>
<%@ Register Src="~/Public/ui/controls/Breadcrumb.ascx" TagPrefix="ks" TagName="Breadcrumb" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Articolo
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="/Public/assets/keepstore/css/product-ui.css" />
    <link rel="stylesheet" href="/Public/assets/keepstore/css/catalog-product-flow.css" />
    <script src="/Public/assets/keepstore/js/catalog-product-flow.js" defer></script>
</asp:Content>

<asp:Content ID="BreadcrumbContent" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <ks:Breadcrumb runat="server" ID="bcArticolo" />
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- DataSource gestito dalla code-behind (SelectCommand impostata in Page_Load) -->
    <asp:SqlDataSource ID="sdsArticolo" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>">
    </asp:SqlDataSource>

    <section class="tf-sp-2">
        <div class="container">

            <asp:FormView ID="fvPage" runat="server" DataSourceID="sdsArticolo">
                <ItemTemplate>

                    <!-- Necessari per VB legacy -->
                    <asp:TextBox ID="tbID" runat="server" Text='<%# Eval("id") %>' Style="display:none" />

                    <!-- Promo datasource (gestito in VB) -->
                    <asp:SqlDataSource ID="sdsPromo" runat="server"
                        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>">
                    </asp:SqlDataSource>

                    <div class="row g-4 align-items-start">

                        <div class="col-12 col-lg-6">
                            <div class="card">
                                <div class="card-body">
                                    <img class="w-100" style="object-fit:contain; aspect-ratio:1/1;" alt='<%# Convert.ToString(Eval("Descrizione1")) %>'
                                         src='<%# If(Eval("Img1") Is Nothing OrElse Convert.ToString(Eval("Img1")).Trim() = "", "/Public/assets/keepstore/images/keepstore/placeholder.png", Convert.ToString(Eval("Img1")) ) %>' />
                                </div>
                            </div>
                        </div>

                        <div class="col-12 col-lg-6">

                            <div class="tf-page-title style-2">
                                <div class="heading">
                                    <asp:Label ID="lblDescrizione" runat="server" Text='<%# Eval("Descrizione1") %>'></asp:Label>
                                </div>
                                <div class="text-muted">
                                    <asp:Label ID="Label13" runat="server" Text='<%# Eval("Descrizione2") %>'></asp:Label>
                                </div>
                            </div>

                            <div class="mb-3">
                                <div class="d-flex flex-wrap gap-2">
                                    <span class="badge bg-light text-dark">Codice: <asp:Label ID="Label15" runat="server" Text='<%# Eval("Codice") %>'></asp:Label></span>
                                    <span class="badge bg-light text-dark">EAN: <span><%#: Eval("Ean") %></span></span>
                                    <span class="badge bg-light text-dark">Marca: <span><%#: Eval("MarcheDescrizione") %></span></span>
                                </div>
                            </div>

                            <!-- Prezzi (calcolati e impostati in VB: lblPrezzoDes/lblPrezzo/lblPrezzoIvato/lblPrezzoPromo) -->
                            <div class="card mb-3">
                                <div class="card-body">
                                    <div class="d-flex align-items-start justify-content-between gap-3">
                                        <div>
                                            <div class="text-muted small"><asp:Label ID="lblPrezzoDes" runat="server" Text=""></asp:Label></div>
                                            <div class="d-flex align-items-baseline gap-2 flex-wrap">
                                                <span class="fs-4 fw-semibold"><asp:Label ID="lblPrezzo" runat="server" Text=""></asp:Label></span>
                                                <span class="text-muted"><asp:Label ID="lblPrezzoIvato" runat="server" Text=""></asp:Label></span>
                                            </div>
                                            <div class="mt-2">
                                                <asp:Label ID="lblPrezzoPromo" runat="server" Text="" Visible="false" CssClass="text-danger fw-semibold"></asp:Label>
                                            </div>
                                        </div>
                                        <div class="text-end">
                                            <div class="text-muted small">Punti</div>
                                            <div class="fw-semibold">
                                                <asp:Label ID="lblPunti1" runat="server" Text="" />
                                                <asp:Label ID="lblPunti2" runat="server" Text="" />
                                                <asp:Label ID="lblPunti3" runat="server" Text="" />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Disponibilità (impostata in VB) -->
                            <div class="card mb-3">
                                <div class="card-body">
                                    <div class="d-flex align-items-center gap-2">
                                        <asp:Image ID="imgDispo" runat="server" />
                                        <div>
                                            <div class="fw-semibold"><asp:Label ID="lblDispo" runat="server" Text=""></asp:Label></div>
                                            <div class="text-muted small">
                                                <asp:Label ID="lblImpegnata" runat="server" Text=""></asp:Label>
                                                <asp:Label ID="lblArrivo" runat="server" Text=""></asp:Label>
                                                <asp:Label ID="lblArr" runat="server" Text="" />
                                                <asp:Label ID="lblImp" runat="server" Text="" />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Acquisto -->
                            <div class="card">
                                <div class="card-body">
                                    <div class="row g-2 align-items-end">
                                        <div class="col-12 col-sm-4">
                                            <label class="form-label">Quantità</label>
                                            <asp:TextBox ID="tbQuantita" runat="server" CssClass="form-control ks-qty" Text="1" />
                                        </div>
                                        <div class="col-12 col-sm-8">
                                            <asp:LinkButton ID="btnCarrello" runat="server" CommandName="carrello" CssClass="btn btn-primary w-100">
                                                Aggiungi al carrello
                                            </asp:LinkButton>
                                        </div>
                                    </div>
                                </div>
                            </div>

                        </div>

                    </div>

                    <div class="mt-4">
                        <ul class="nav nav-tabs" role="tablist">
                            <li class="nav-item" role="presentation">
                                <button class="nav-link active" id="tab-desc" data-bs-toggle="tab" data-bs-target="#pane-desc" type="button" role="tab" aria-controls="pane-desc" aria-selected="true">
                                    Descrizione
                                </button>
                            </li>
                            <li class="nav-item" role="presentation">
                                <button class="nav-link" id="tab-info" data-bs-toggle="tab" data-bs-target="#pane-info" type="button" role="tab" aria-controls="pane-info" aria-selected="false">
                                    Dettagli
                                </button>
                            </li>
                        </ul>

                        <div class="tab-content border border-top-0 rounded-bottom p-3">
                            <div class="tab-pane fade show active" id="pane-desc" role="tabpanel" aria-labelledby="tab-desc">
                                <asp:Label ID="lblDescrizioneArt" runat="server" Text=""></asp:Label>
                                <asp:Label ID="lblDescrizioneHTMLArt" runat="server" Text=""></asp:Label>
                            </div>
                            <div class="tab-pane fade" id="pane-info" role="tabpanel" aria-labelledby="tab-info">
                                <div class="text-muted small">
                                    Settore: <%#: Eval("SettoriDescrizione") %><br />
                                    Categoria: <%#: Eval("CategorieDescrizione") %><br />
                                    Tipologia: <%#: Eval("TipologieDescrizione") %><br />
                                    Gruppo: <%#: Eval("GruppiDescrizione") %><br />
                                    Sottogruppo: <%#: Eval("SottogruppiDescrizione") %>
                                </div>
                            </div>
                        </div>
                    </div>

                </ItemTemplate>
            </asp:FormView>

            <!-- Related products (loaded/bound in code-behind) -->
            <asp:PlaceHolder ID="phRelated" runat="server" Visible="false">
                <div class="mt-5">
                    <div class="d-flex align-items-center justify-content-between mb-3">
                        <h3 class="h5 mb-0">Prodotti correlati</h3>
                    </div>

                    <div class="row g-3">
                        <asp:Repeater ID="rptRelated" runat="server">
                            <ItemTemplate>
                                <div class="col-6 col-md-4 col-lg-3">
                                    <div class="card ks-product-card h-100">
                                        <a class="d-block" href='<%# Eval("Url") %>'>
                                            <img class="ks-product-img"
                                                 src='<%# Eval("Img") %>'
                                                 alt='<%#: Eval("Nome") %>'
                                                 loading="lazy" />
                                        </a>
                                        <div class="card-body p-3 d-flex flex-column">
                                            <a class="text-decoration-none fw-semibold mb-2" href='<%# Eval("Url") %>'><%#: Eval("Nome") %></a>
                                            <div class="mt-auto price-wrap fw-medium">
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

</asp:Content>

<asp:Content ID="ScriptsContent" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="/Public/assets/keepstore/js/product-ui.js"></script>
</asp:Content>
