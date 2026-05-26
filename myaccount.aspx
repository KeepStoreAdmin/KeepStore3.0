<%@ Page Title="" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="myaccount.aspx.vb" Inherits="myaccount" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Area personale
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="ks-myaccount ks-account-dashboard">
        <div class="tf-sp-1 pb-0">
            <div class="container">
                <div class="tf-breadcrumb-wrap">
                    <div class="tf-breadcrumb-list">
                        <a href="Default.aspx" class="text">Home</a>
                        <i class="icon icon-arrow-right"></i>
                        <span class="text">Account</span>
                    </div>
                </div>
            </div>
        </div>

        <section class="tf-sp-2">
            <div class="container">
                <asp:SqlDataSource ID="sdsDashboardProfile" runat="server"
                    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT v.Username, v.email, v.cognomenome, v.ultimoaccesso, u.Codice, u.RagioneSociale, u.Piva, u.CodiceFiscale, u.Telefono, u.Cellulare, u.Indirizzo, u.Cap, u.Citta, u.Provincia, u.Nazione FROM vlogin v INNER JOIN utenti u ON v.utentiid=u.id WHERE v.id=?LoginId">
                    <SelectParameters>
                        <asp:SessionParameter Name="LoginId" SessionField="LoginId" Type="Int32" />
                    </SelectParameters>
                </asp:SqlDataSource>

                <asp:SqlDataSource ID="sdsRecentOrders" runat="server"
                    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT vdocumenti.Id, vdocumenti.NDocumento, vdocumenti.DataDocumento, vdocumenti.TotaleDocumento, vdocumenti.StatiDescrizione1, vdocumenti.StatiDescrizione2, COALESCE(dpay.Pagato,0) AS ListaPagato, COALESCE(dpay.StatoPagamentoWeb,0) AS ListaStatoPagamentoWeb, COALESCE(dpay.UltimoEsitoPagamentoWeb,'') AS ListaUltimoEsitoPagamentoWeb, COALESCE(pagamentitipo.Descrizione,'') AS ListaPagamentoDescrizione FROM vdocumenti LEFT JOIN pagamentitipo ON vdocumenti.PagamentiTipoId = pagamentitipo.id LEFT JOIN documenti dpay ON dpay.id = vdocumenti.Id WHERE vdocumenti.UtentiId = ?UtentiId AND vdocumenti.TipoDocumentiId = 4 ORDER BY vdocumenti.ID DESC LIMIT 5">
                    <SelectParameters>
                        <asp:SessionParameter Name="UtentiId" SessionField="UtentiID" Type="Int32" />
                    </SelectParameters>
                </asp:SqlDataSource>

                <div class="row">
                    <div class="col-lg-3">
                        <div class="wrap-sidebar-account">
                            <ul class="myaccount-nav content-append">
                                <li><span class="myaccount-nav-item active">Dashboard</span></li>
                                <li><a href="documenti.aspx?t=4" class="myaccount-nav-item">I miei ordini</a></li>
                                <li><a href="my-account-address.aspx" class="myaccount-nav-item">Indirizzi</a></li>
                                <li><a href="my-account-edit.aspx" class="myaccount-nav-item">Dettagli account</a></li>
                                <li><a href="wishlist.aspx" class="myaccount-nav-item">Wishlist</a></li>
                                <li><a href="password.aspx" class="myaccount-nav-item">Cambia password</a></li>
                                <li><a href="logout.aspx" class="myaccount-nav-item">Logout</a></li>
                            </ul>
                        </div>
                    </div>

                    <div class="col-lg-9">
                        <div class="myaccount-content account-dashboard">
                            <asp:FormView ID="fvDashboardProfile" runat="server" DataSourceID="sdsDashboardProfile" RenderOuterTable="false">
                                <ItemTemplate>
                                    <div class="ks-dashboard-hero">
                                        <div>
                                            <h3 class="fw-semibold mb-2"><%#: GetDashboardGreeting(Eval("RagioneSociale"), Eval("cognomenome"), Eval("Username")) %></h3>
                                            <p class="body-md-2 text-main-2 mb-0">Da qui puoi controllare ordini, dati account e indirizzi.</p>
                                        </div>
                                        <a href="documenti.aspx?t=4" class="tf-btn btn-fill">I miei ordini</a>
                                    </div>

                                    <div class="row g-3 g-xl-4 mb-4">
                                        <div class="col-12 col-xl-6">
                                            <div class="ks-dashboard-card h-100">
                                                <div class="ks-dashboard-card-head">
                                                    <div>
                                                        <h4 class="fw-semibold mb-1">Profilo</h4>
                                                        <p class="body-small text-main-2 mb-0">Dati essenziali del tuo account.</p>
                                                    </div>
                                                    <i class="icon-user"></i>
                                                </div>

                                                <dl class="ks-dashboard-list">
                                                    <dt>Nome / Ragione sociale</dt>
                                                    <dd><%#: SafeAccountText(FirstValue(Eval("RagioneSociale"), Eval("cognomenome"), Eval("Username")), "Non specificato") %></dd>
                                                    <dt>Email / Username</dt>
                                                    <dd><%#: SafeAccountText(FirstValue(Eval("email"), Eval("Username")), "Non specificato") %></dd>
                                                    <dt>Telefono</dt>
                                                    <dd><%#: SafeAccountText(FirstValue(Eval("Cellulare"), Eval("Telefono")), "Non specificato") %></dd>
                                                    <dt>Codice cliente</dt>
                                                    <dd><%#: SafeAccountText(Eval("Codice"), "Non specificato") %></dd>
                                                </dl>

                                                <div class="ks-dashboard-actions">
                                                    <a href="my-account-edit.aspx" class="tf-btn btn-line">Modifica dati</a>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="col-12 col-xl-6">
                                            <div class="ks-dashboard-card h-100">
                                                <div class="ks-dashboard-card-head">
                                                    <div>
                                                        <h4 class="fw-semibold mb-1">Indirizzi</h4>
                                                        <p class="body-small text-main-2 mb-0">Indirizzo principale registrato.</p>
                                                    </div>
                                                    <i class="icon-map-pin"></i>
                                                </div>

                                                <address class="ks-dashboard-address">
                                                    <span><%#: SafeAccountText(Eval("Indirizzo"), "Indirizzo non specificato") %></span>
                                                    <span><%#: FormatCityLine(Eval("Cap"), Eval("Citta"), Eval("Provincia")) %></span>
                                                    <span><%#: SafeAccountText(Eval("Nazione"), "Nazione non specificata") %></span>
                                                </address>

                                                <div class="ks-dashboard-actions">
                                                    <a href="my-account-address.aspx" class="tf-btn btn-line">Gestisci indirizzi</a>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </ItemTemplate>
                                <EmptyDataTemplate>
                                    <div class="ks-dashboard-hero">
                                        <div>
                                            <h3 class="fw-semibold mb-2">Benvenuto nella tua area personale</h3>
                                            <p class="body-md-2 text-main-2 mb-0">Da qui puoi controllare ordini, dati account e indirizzi.</p>
                                        </div>
                                        <a href="documenti.aspx?t=4" class="tf-btn btn-fill">I miei ordini</a>
                                    </div>
                                </EmptyDataTemplate>
                            </asp:FormView>

                            <div class="ks-dashboard-card mb-4">
                                <div class="ks-dashboard-card-head">
                                    <div>
                                        <h4 class="fw-semibold mb-1">Ordini recenti</h4>
                                        <p class="body-small text-main-2 mb-0">Ultimi ordini con stato ordine e stato pagamento separati.</p>
                                    </div>
                                    <a href="documenti.aspx?t=4" class="tf-btn btn-line">Vedi tutti gli ordini</a>
                                </div>

                                <div class="tf-order_history-table ks-dashboard-orders">
                                    <asp:GridView ID="gvRecentOrders" runat="server"
                                        AutoGenerateColumns="False"
                                        DataKeyNames="Id"
                                        DataSourceID="sdsRecentOrders"
                                        EmptyDataText="Nessun ordine recente"
                                        GridLines="None"
                                        Width="100%"
                                        CssClass="table_def ks-order-table"
                                        UseAccessibleHeader="True"
                                        OnPreRender="gvRecentOrders_PreRender">
                                        <Columns>
                                            <asp:TemplateField HeaderText="Numero">
                                                <ItemTemplate>
                                                    <span class="body-text-3 fw-semibold"><%#: Eval("NDocumento") %></span>
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Data">
                                                <ItemTemplate>
                                                    <span class="body-text-3"><%# Eval("DataDocumento", "{0:d}") %></span>
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Totale">
                                                <ItemTemplate>
                                                    <span class="body-text-3"><%# Eval("TotaleDocumento", "{0:C}") %></span>
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Stato ordine">
                                                <ItemTemplate>
                                                    <span class="ks-status-badge ks-status-badge-order"><%#: FormatOrderStatus(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %></span>
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Stato pagamento">
                                                <ItemTemplate>
                                                    <div class="ks-order-payment-state">
                                                        <span class='<%# GetPaymentStatusCssClass(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb")) %>'><%# GetPaymentStatusLabel(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb")) %></span>
                                                        <span class="body-small text-main-2"><%#: GetPaymentStatusDescription(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb"), Eval("ListaUltimoEsitoPagamentoWeb"), Eval("ListaPagamentoDescrizione")) %></span>
                                                    </div>
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                            <asp:TemplateField HeaderText="Azione">
                                                <ItemTemplate>
                                                    <a href="<%# Eval("Id", "documentidettaglio.aspx?id={0}") %>" class="tf-btn btn-small d-inline-flex">
                                                        <span class="text-white">Dettaglio</span>
                                                    </a>
                                                </ItemTemplate>
                                            </asp:TemplateField>
                                        </Columns>
                                        <HeaderStyle CssClass="title-sidebar fw-medium" />
                                        <RowStyle CssClass="td-order-item" />
                                    </asp:GridView>
                                </div>
                            </div>

                            <div class="ks-dashboard-card">
                                <div class="ks-dashboard-card-head">
                                    <div>
                                        <h4 class="fw-semibold mb-1">Azioni rapide</h4>
                                        <p class="body-small text-main-2 mb-0">Le scorciatoie principali della tua area personale.</p>
                                    </div>
                                </div>

                                <div class="ks-dashboard-quicklinks">
                                    <a href="documenti.aspx?t=4" class="tf-btn btn-line">I miei ordini</a>
                                    <a href="my-account-edit.aspx" class="tf-btn btn-line">Modifica dati</a>
                                    <a href="my-account-address.aspx" class="tf-btn btn-line">Indirizzi</a>
                                    <a href="wishlist.aspx" class="tf-btn btn-line">Wishlist</a>
                                    <a href="password.aspx" class="tf-btn btn-line">Password</a>
                                    <a href="logout.aspx" class="tf-btn btn-line">Logout</a>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    </div>

</asp:Content>
