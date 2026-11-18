<%@ Page Title="" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="myaccount.aspx.vb" Inherits="myaccount" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    La tua Dashboard
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/account-hub-ui.css") %>?v=20261118-qa-1a" />
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

                <asp:SqlDataSource ID="sdsRecentOrders" runat="server"
                    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT vdocumenti.Id, vdocumenti.NDocumento, vdocumenti.DataDocumento, vdocumenti.StatiId, vdocumenti.TotaleDocumento, vdocumenti.StatiDescrizione1, vdocumenti.StatiDescrizione2, COALESCE(dpay.Pagato,0) AS ListaPagato, COALESCE(dpay.StatoPagamentoWeb,0) AS ListaStatoPagamentoWeb, COALESCE(dpay.UltimoEsitoPagamentoWeb,'') AS ListaUltimoEsitoPagamentoWeb, COALESCE(pagamentitipo.Descrizione,'') AS ListaPagamentoDescrizione FROM vdocumenti LEFT JOIN pagamentitipo ON vdocumenti.PagamentiTipoId = pagamentitipo.id LEFT JOIN documenti dpay ON dpay.id = vdocumenti.Id WHERE vdocumenti.UtentiId = ?UtentiId AND vdocumenti.AziendeId = ?AziendaId AND EXISTS (SELECT 1 FROM tipodocumenti tdo WHERE tdo.id = vdocumenti.TipoDocumentiId AND tdo.Web = 1 AND tdo.Abilitato = 1 AND tdo.ImpegnaQnt = 1) ORDER BY vdocumenti.ID DESC LIMIT 5">
                    <SelectParameters>
                        <asp:SessionParameter Name="UtentiId" SessionField="UtentiID" Type="Int32" />
                        <asp:SessionParameter Name="AziendaId" SessionField="AuthenticatedAziendaID" Type="Int32" />
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

                            <section class="ks-account-recent" aria-labelledby="ksAccountRecentTitle">
                                <div class="ks-account-recent__head">
                                    <h4 id="ksAccountRecentTitle" class="fw-semibold mb-0">Ordini recenti</h4>
                                    <a href="documenti.aspx" class="tf-btn btn-line">Vedi tutti gli ordini</a>
                                </div>

                                <asp:Repeater ID="rptRecentOrders" runat="server" DataSourceID="sdsRecentOrders">
                                    <ItemTemplate>
                                        <article class="ks-doc-card ks-doc-card--compact">
                                            <header class="ks-doc-card__head">
                                                <div class="ks-doc-card__title">
                                                    <a href='<%# Eval("Id", "documentidettaglio.aspx?id={0}") %>'>Ordine n. <%#: Eval("NDocumento") %></a>
                                                </div>
                                                <span class="ks-doc-card__date"><%#: KeepStoreDates.ShortDate(Eval("DataDocumento")) %></span>
                                            </header>
                                            <div class="ks-doc-card__body">
                                                <div class="ks-doc-card__cell">
                                                    <span class="ks-doc-card__k">Stato</span>
                                                    <span class="ks-status-badge ks-status-badge-order"><%#: SafeAccountText(Eval("StatiDescrizione1"), "Non disponibile") %></span>
                                                    <%# KeepStoreOrderProgress.MiniProgressHtml(True, RecentStateId(Eval("StatiId"))) %>
                                                </div>
                                                <div class="ks-doc-card__cell">
                                                    <span class="ks-doc-card__k">Totale</span>
                                                    <span class="ks-doc-card__total"><%# Eval("TotaleDocumento", "{0:C}") %></span>
                                                </div>
                                                <div class="ks-doc-card__cell">
                                                    <span class="ks-doc-card__k">Pagamento</span>
                                                    <span class='<%# GetPaymentStatusCssClass(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb")) %>'><%#: GetPaymentStatusLabel(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb")) %></span>
                                                    <span class="body-small text-main-2"><%#: SafeAccountText(Eval("ListaPagamentoDescrizione"), "") %></span>
                                                </div>
                                                <div class="ks-doc-card__cell ks-doc-card__cell--action">
                                                    <a href='<%# Eval("Id", "documentidettaglio.aspx?id={0}") %>' class="tf-btn btn-small">Dettaglio</a>
                                                </div>
                                            </div>
                                        </article>
                                    </ItemTemplate>
                                </asp:Repeater>
                                <p id="pRecentEmpty" runat="server" visible="false" class="body-md-2 text-main-2 mb-0">Non hai ancora ordini. <a href="Default.aspx" class="link">Inizia dagli articoli in evidenza</a>.</p>
                            </section>

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
