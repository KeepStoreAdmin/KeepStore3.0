<%@ Page Title="" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="myaccount.aspx.vb" Inherits="myaccount" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    La tua Dashboard
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/account-hub-ui.css") %>?v=20261118-orders-1b" />
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="ks-myaccount ks-account-dashboard">
        <div class="tf-sp-1 pb-0">
            <div class="container">
                <div class="tf-breadcrumb-wrap">
                    <div class="tf-breadcrumb-list">
                        <a href="Default.aspx" class="text">Home</a>
                        <i class="icon icon-arrow-right"></i>
                        <span class="text">Dashboard</span>
                    </div>
                </div>
            </div>
        </div>

        <section class="tf-sp-2">
            <div class="container">
                <asp:SqlDataSource ID="sdsDashboardProfile" runat="server"
                    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT v.Username, v.email, COALESCE(u.CognomeNome, v.cognomenome, '') AS CognomeNome, v.ultimoaccesso, u.Codice, u.RagioneSociale, u.Piva, u.CodiceFiscale, u.Telefono, u.Cellulare, u.Indirizzo, u.Cap, u.Citta, u.Provincia, u.Nazione FROM vlogin v INNER JOIN utenti u ON v.utentiid=u.id WHERE v.id=?LoginId">
                    <SelectParameters>
                        <asp:SessionParameter Name="LoginId" SessionField="LoginId" Type="Int32" />
                    </SelectParameters>
                </asp:SqlDataSource>

                <div class="row">
                    <div class="col-12">
                        <div class="myaccount-content account-dashboard">
                            <div class="ks-dashboard-hero">
                                <div>
                                    <h3 class="fw-semibold mb-2"><asp:Literal ID="litGreeting" runat="server" Text="Benvenuto nella tua Dashboard" /></h3>
                                    <p class="body-md-2 text-main-2 mb-0">Da qui puoi controllare ordini, documenti, dati account e indirizzi.</p>
                                </div>
                                <a href="documenti.aspx" class="tf-btn btn-fill">I miei ordini</a>
                            </div>

                            <div id="pnlPayNotice" runat="server" visible="false" class="ks-account-notice">
                                <svg class="ks-account-notice__icon" viewBox="0 0 24 24" width="32" height="32" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true" focusable="false"><rect x="3" y="6" width="18" height="12"/><path d="M3 10h18"/></svg>
                                <div class="ks-account-notice__text">
                                    <h4 class="ks-account-notice__title"><asp:Literal ID="litPayNotice" runat="server" /></h4>
                                    <p class="body-small mb-0">Puoi completare il pagamento online in pochi passaggi.</p>
                                </div>
                                <a id="lnkPayNotice" runat="server" class="tf-btn btn-fill ks-account-notice__btn">Paga adesso</a>
                            </div>

                            <nav class="ks-account-hub" aria-label="Servizi dell'account">
                                <%= TilesHtml(True) %>
                            </nav>

                            <asp:FormView ID="fvDashboardProfile" runat="server" DataSourceID="sdsDashboardProfile" RenderOuterTable="false" OnDataBound="fvDashboardProfile_DataBound">
                                <ItemTemplate>
                                    <div class="ks-account-strip">
                                        <dl class="ks-account-strip__list">
                                            <div><dt>Codice cliente</dt><dd><%#: SafeAccountText(Eval("Codice"), "n/d") %></dd></div>
                                            <div><dt>Email</dt><dd><%#: SafeAccountText(FirstValue(Eval("email"), Eval("Username")), "n/d") %></dd></div>
                                            <div><dt>Telefono</dt><dd><%#: SafeAccountText(FirstValue(Eval("Cellulare"), Eval("Telefono")), "n/d") %></dd></div>
                                            <div><dt>Indirizzo principale</dt><dd><%#: SafeAccountText(Eval("Indirizzo"), "n/d") %>, <%#: FormatCityLine(Eval("Cap"), Eval("Citta"), Eval("Provincia")) %></dd></div>
                                        </dl>
                                    </div>
                                </ItemTemplate>
                            </asp:FormView>

                            <section class="ks-account-soon" aria-labelledby="ksAccountSoonTitle">
                                <h4 id="ksAccountSoonTitle" class="fw-semibold mb-1">In arrivo</h4>
                                <p class="body-small text-main-2 mb-3">Servizi che stiamo preparando: non sono ancora disponibili.</p>
                                <%= TilesHtml(False) %>
                            </section>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    </div>

</asp:Content>
