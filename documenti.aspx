<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="documenti.aspx.vb" Inherits="documenti" Debug="false" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    I miei ordini
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/order-ui.css") %>?v=20261117-pay-now-1a" />
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/account-hub-ui.css") %>?v=20261118-orders-1b" />
    <style>
        .ks-myaccount .ks-document-date {
            min-width: 0;
            flex: 1 1 150px;
        }

    </style>
<script type="text/javascript">
        function ksHideSpinnerAndShowContent() {
            var spinner = document.getElementById('<%= pnlLoading.ClientID %>');
            var content = document.getElementById('<%= pnlContent.ClientID %>');

            if (spinner) {
                spinner.style.display = 'none';
            }
            if (content) {
                content.style.display = 'block';
                content.style.opacity = '1';
            }
        }

        // Prima apertura
        document.addEventListener('DOMContentLoaded', function () {
            ksHideSpinnerAndShowContent();
        });

        // Ritorno tramite tasto indietro / bfcache
        window.addEventListener('pageshow', function (event) {
            ksHideSpinnerAndShowContent();
        });

        function ksShowSpinnerOnSubmit() {
            var spinner = document.getElementById('<%= pnlLoading.ClientID %>');
            var content = document.getElementById('<%= pnlContent.ClientID %>');
            if (spinner) spinner.style.display = 'block';
            if (content) content.style.opacity = '0.5';
        }

        function ksApplyDocumentFilters() {
            var stato = document.getElementById('<%= filtroStati.ClientID %>');
            var tempo = document.getElementById('<%= filtroTempo.ClientID %>');
            var dal = document.getElementById('<%= dataInizio.ClientID %>');
            var al = document.getElementById('<%= dataFine.ClientID %>');
            var params = new URLSearchParams(window.location.search);

            if (!params.get('t')) {
                params.set('t', '4');
            }

            if (stato && stato.value && stato.value !== '-1') {
                params.set('stato', stato.value);
            } else {
                params.delete('stato');
            }

            if (tempo && tempo.value && tempo.value !== '-1') {
                params.set('tempo', tempo.value);
                params.delete('dal');
                params.delete('al');
            } else {
                params.delete('tempo');

                if (dal && dal.value) {
                    params.set('dal', dal.value);
                } else {
                    params.delete('dal');
                }

                if (al && al.value) {
                    params.set('al', al.value);
                } else {
                    params.delete('al');
                }
            }

            ksShowSpinnerOnSubmit();
            window.location.href = 'documenti.aspx?' + params.toString();
            return false;
        }
    </script>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">
<!-- SPINNER DI PAGINA -->
    <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel">
        <div class="ks-spinner-circle"></div>
        <div>Caricamento documenti in corso...</div>
    </asp:Panel>

    <!-- CONTENUTO PRINCIPALE (inizialmente nascosto, lo mostra lo script) -->
    <asp:Panel ID="pnlContent" runat="server" Style="display:none;">
<% If Session("esito_invio_mail") = "1" Or Session("esito_invio_mail") = "0" Then %>
        <script type="text/javascript">
            JQ(document).ready(
                function () {
                    var popID = "popup"; //Get Popup Name
                    var popURL = "#?w=700"; //Get Popup href to define size

                    //Pull Query & Variables from href URL
                    var query = popURL.split('?');
                    var dim = query[1].split('&');
                    var popWidth = dim[0].split('=')[1]; //Gets the first query string value

                    //Fade in the Popup and add close button
                    JQ('#' + popID).fadeIn().css({ 'width': Number(popWidth) }).prepend('<a href="#" class="close"><img src="/Public/Images/close_pop.png" class="btn_close" title="Close Window" alt="Close" /></a>');

                    //Define margin for center alignment (vertical + horizontal)
                    var popMargTop = (10 + 80) / 2;
                    var popMargLeft = (700 + 80) / 2;

                    //Apply Margin to Popup
                    JQ('#' + popID).css({
                        'margin-top': -popMargTop,
                        'margin-left': -popMargLeft
                    });

                    //Fade in Background
                    JQ('body').append('<div id="fade"></div>');
                    JQ('#fade').css({ 'filter': 'alpha(opacity=80)' }).fadeIn();

                    //Close Popups and Fade Layer
                    JQ('a.close, #fade').on('click', function () {
                        JQ('#fade , .popup_block').fadeOut(function () {
                            JQ('#fade, a.close').remove();
                        });
                        return false;
                    });
                }
            );
        </script>
        <% End If %>

        <% If Session("esito_invio_mail") = "1" Then
               Session("esito_invio_mail") = 0
        %>
        <div id="popup" class="popup_block" style="display:none; vertical-align:middle;">
            <div><img src="/Public/Images/Ok.png" alt="" /></div><br />
            <div>Richiesta inoltrata. Riceverà il documento presso la sua casella email !!!</div>
        </div>
        <% End If %>

        <%-- KS-DASHBOARD-ORDERS-1B: la query vera, i filtri e i parametri tipizzati (utente e azienda dell'identita verificata) li imposta il code-behind a ogni richiesta; questo ripiego non restituisce righe. --%>
        <asp:SqlDataSource ID="sdsDocumenti" runat="server" EnableViewState="false"
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT `vdocumenti`.`Id` FROM `vdocumenti` WHERE 1=0">
        </asp:SqlDataSource>

        <asp:SqlDataSource ID="sdsTipo" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
            SelectCommand="SELECT id, Descrizione FROM tipodocumenti WHERE Web=1 AND Abilitato=1 ORDER BY Ordinamento, Descrizione">
        </asp:SqlDataSource>
        
        <asp:SqlDataSource ID="sdsStatoOrdine" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
            SelectCommand="SELECT * FROM documentistati;">
        </asp:SqlDataSource>
        
        
        <div class="ks-myaccount">

            <!-- Breadcrumb -->
            <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="myaccount.aspx" class="text">Dashboard</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">I miei ordini</span>
                </div>
            </div>
        </div>
    </div>

            <section class="tf-sp-2">
                <div class="container">
                    <div class="row">
                        <div class="col-12">
                            <div class="myaccount-content account-dashboard">

                                <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
                                    <div>
                                        <h3 class="fw-semibold mb-0">I miei ordini</h3>
                                        <div class="body-small text-main-2">Ordini, fatture e DDT in un solo posto.</div>
                                    </div>
                                    <asp:HyperLink 
                                        ID="hlBackMyAccount" 
                                        runat="server"
                                        NavigateUrl="myaccount.aspx"
                                        CssClass="tf-btn btn-line">&laquo; Torna alla Dashboard</asp:HyperLink>
                                </div>

                    <div class="ks-doc-typebar">
                        <div class="body-small text-main-2 mb-2">Seleziona il tipo di documento</div>
                        <div class="d-flex flex-wrap gap-2">
                            <asp:Repeater ID="rTipo" runat="server" DataSourceID="sdsTipo">
                                <ItemTemplate>
                                    <asp:LinkButton ID="lbTipoDocumento" runat="server" CssClass="nonSelezionato"
                                        tipoDocumento='<%# Eval("id") %>'
                                        OnClick="tipoDocumentoClick"
                                        OnPreRender="preRenderClick">
                                        <%# Eval("descrizione") %>
                                    </asp:LinkButton>
                                </ItemTemplate>
                            </asp:Repeater>
                        </div>
                    </div>

                    <asp:Label runat="server" ID="lblInfo" Visible="false"></asp:Label>

                    <div class="ks-doc-filters" role="group" aria-label="Filtra i documenti">
                        <div class="ks-doc-filters__row">
                            <div class="ks-doc-filters__field">
                                <label class="body-small text-main-2" for="<%= filtroTempo.ClientID %>">Periodo</label>
                                <asp:DropDownList ID="filtroTempo" runat="server" AutoPostBack="false" CssClass="form-select form-select-sm" onchange="return ksApplyDocumentFilters();">
                                    <asp:ListItem Value="-1" Selected="True">Tutti i documenti</asp:ListItem>
                                    <asp:ListItem Value="7">Ultima settimana</asp:ListItem>
                                    <asp:ListItem Value="30">Ultimo mese</asp:ListItem>
                                    <asp:ListItem Value="60">Ultimi due mesi</asp:ListItem>
                                    <asp:ListItem Value="90">Ultimi tre mesi</asp:ListItem>
                                </asp:DropDownList>
                            </div>
                            <div class="ks-doc-filters__field">
                                <label class="body-small text-main-2" for="<%= filtroStati.ClientID %>">Stato</label>
                                <asp:DropDownList ID="filtroStati" runat="server" AutoPostBack="False"
                                    DataSourceID="sdsStatoOrdine" DataTextField="Descrizione1" DataValueField="id"
                                    OnSelectedIndexChanged="applicaFiltri" OnDataBound="aggiungiStato" CssClass="form-select form-select-sm" onchange="return ksApplyDocumentFilters();">
                                </asp:DropDownList>
                            </div>
                        </div>
                        <details class="ks-doc-more-dates"<%= MoreDatesOpenAttribute %>>
                            <summary class="body-small link">Altre date</summary>
                            <div class="ks-doc-filters__row">
                                <div class="ks-doc-filters__field">
                                    <label class="body-small text-main-2" for="<%= dataInizio.ClientID %>">Dal</label>
                                    <asp:TextBox runat="server" ID="dataInizio" TextMode="Date" CssClass="tf-input ks-document-date"></asp:TextBox>
                                </div>
                                <div class="ks-doc-filters__field">
                                    <label class="body-small text-main-2" for="<%= dataFine.ClientID %>">Al</label>
                                    <asp:TextBox runat="server" ID="dataFine" TextMode="Date" CssClass="tf-input ks-document-date"></asp:TextBox>
                                </div>
                                <asp:Button ID="Button1" runat="server" Text="Filtra" OnClick="applicaFiltri" CssClass="tf-btn btn-fill" OnClientClick="return ksApplyDocumentFilters();" />
                            </div>
                        </details>
                    </div>

                    <p class="body-md-2 ks-doc-count"><span class="text-secondary fw-semibold"><%= nDocTrovati %></span> documenti trovati</p>

<div class="tf-order_history-table ks-doc-list-wrap">
    <asp:GridView ID="GridView1" runat="server"
        AllowPaging="True"
        AutoGenerateColumns="False"
        DataKeyNames="id"
        DataSourceID="sdsDocumenti"
        EmptyDataText="Nessun documento presente"
        GridLines="None"
        PageSize="20"
        Width="100%"
        ShowHeader="False"
        CssClass="table_def ks-order-table ks-doc-list"
        UseAccessibleHeader="True"
        OnPreRender="GridView1_PreRender_22B">

        <EmptyDataRowStyle Font-Bold="False" Height="100px" HorizontalAlign="Center" />

        <Columns>
            <asp:TemplateField>
                <ItemTemplate>
                    <article class="ks-doc-card">
                        <header class="ks-doc-card__head">
                            <div class="ks-doc-card__title">
                                <span class="ks-doc-card__type"><%#: Eval("TipoDocumentiDescrizione") %> n.</span>
                                <asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="idcoupon" runat="server"
                                    Visible='<%# (Convert.ToString(Request.QueryString("t")) = Convert.ToString(Session("IdDocumentoCoupon"))) %>'
                                    NavigateUrl='<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>'
                                    Text='<%# Eval("NDocumento") %>'
                                    ToolTip='<%# "Visualizza Dettagli " & Eval("tipodocumentidescrizione") %>'>
                                </asp:HyperLink>

                                <asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="iddoc" runat="server"
                                    Visible='<%# Not (Convert.ToString(Request.QueryString("t")) = Convert.ToString(Session("IdDocumentoCoupon"))) %>'
                                    NavigateUrl='<%# Eval("id", "documentidettaglio.aspx?id={0}") %>'
                                    Text='<%# Eval("NDocumento") %>'
                                    ToolTip='<%# "Visualizza Dettagli " & Eval("tipodocumentidescrizione") %>'>
                                </asp:HyperLink>
                            </div>
                            <span class="ks-doc-card__date"><%#: KeepStoreDates.ShortDate(Eval("DataDocumento")) %></span>
                        </header>

                        <div class="ks-doc-card__body">
                            <div class="ks-doc-card__cell">
                                <span class="ks-doc-card__k">Stato</span>
                                <span class="ks-status-badge ks-status-badge-order"><%#: OrderStatusTitle(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %></span>
                                <span class="ks-doc-card__status-note body-small text-main-2"><%#: OrderStatusNote(Eval("StatiDescrizione1"), Eval("StatiDescrizione2")) %></span>
                                <%# ListProgressHtml(Eval("ListaOrdineWeb"), Eval("StatiId")) %>
                            </div>
                            <div class="ks-doc-card__cell">
                                <span class="ks-doc-card__k">Totale</span>
                                <span class="ks-doc-card__total"><%# Eval("TotaleDocumento", "{0:C}") %></span>
                                <span class="body-small text-main-2">Imponibile: <%# Eval("TotImponibile", "{0:C}") %></span>
                            </div>
                            <div class="ks-doc-card__cell">
                                <span class="ks-doc-card__k">Pagamento</span>
                                <span class="body-text-3"><%#: GetPaymentMethodLabel(Eval("ListaPagamentoDescrizione")) %></span>
                                <div class="ks-order-payment-state">
                                    <span class='<%# GetPaymentStatusCssClass(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb")) %>'><%# GetPaymentStatusLabel(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb")) %></span>
                                    <asp:Label ID="lblListaDaPagare" runat="server" CssClass="ks-pay-now__badge" Text="Da pagare" Visible='<%# ListPayNowVisible(Eval("id")) %>' />
                                    <span class="body-small text-main-2"><%#: GetPaymentStatusDescription(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb"), Eval("ListaUltimoEsitoPagamentoWeb"), Eval("ListaPagamentiTipoOnline"), Eval("ListaPagamentoDescrizione")) %></span>
                                </div>
                            </div>
                            <div class="ks-doc-card__cell">
                                <span class="ks-doc-card__k">Spedizione</span>
                                <span class="body-text-3"><%#: Eval("VettoriDescrizione") %></span>
                                <%# ListTrackingHtml(Eval("Tracking"), Eval("Link_Tracking"), Eval("StatiId")) %>
                            </div>
                        </div>

                        <footer class="ks-doc-card__foot">
                            <details class="ks-order-details">
                                <summary class="body-small link">Info</summary>
                                <div class="ks-order-details-body">
                                    <div class="body-small"><strong>Destinatario:</strong> <%#: Eval("RagioneSociale") %> <%#: Eval("CognomeNome") %> - <%#: Eval("SedeLegale") %></div>
                                    <div class="body-small"><strong>Altra destinazione:</strong> <%#: Eval("DestinazioneMerci") %></div>
                                    <div class="body-small" style="<%# testNote(Eval("Note")) %>"><strong>Note corriere:</strong> <%#: Eval("Note") %></div>
                                    <div class="body-small"><strong>Note:</strong> <%#: Eval("NoteEsterne") %></div>
                                </div>
                            </details>
                            <div class="ks-action-stack">

                                <asp:HyperLink ID="hlListaPagaAdesso" runat="server" CssClass="tf-btn btn-small d-inline-flex ks-pay-now__btn" NavigateUrl='<%# Eval("id", "documentidettaglio.aspx?id={0}#ksPayNow") %>' Visible='<%# ListPayNowVisible(Eval("id")) %>' Text="Paga adesso" ToolTip='<%# "Paga adesso ordine n. " & Eval("NDocumento") %>' />

                                <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>" class="tf-btn btn-small d-inline-flex">
                                    <span class="text-white">Dettaglio</span>
                                </a>

                            </div>
                        </footer>
                    </article>
                </ItemTemplate>
            </asp:TemplateField>
        </Columns>

        <PagerStyle CssClass="nav ks-doc-list__pager" Font-Bold="True" />
        <EditRowStyle Font-Bold="False" />
        <RowStyle CssClass="td-order-item" />

    </asp:GridView>
</div>

                            </div>
                        </div>
                    </div>
                </div>
            </section>

        </div>

    </asp:Panel> <!-- fine pnlContent -->
</asp:Content>
