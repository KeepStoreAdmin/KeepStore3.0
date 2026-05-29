<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="documenti.aspx.vb" Inherits="documenti" Debug="false" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    I miei documenti
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
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

        <asp:SqlDataSource ID="sdsDocumenti" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
            SelectCommand="SELECT vdocumenti.*, utenti.*, vettori.Link_Tracking, COALESCE(dpay.Pagato,0) AS ListaPagato, COALESCE(dpay.StatoPagamentoWeb,0) AS ListaStatoPagamentoWeb, dpay.DataStatoPagamentoWeb AS ListaDataStatoPagamentoWeb, COALESCE(dpay.UltimoEsitoPagamentoWeb,'') AS ListaUltimoEsitoPagamentoWeb, COALESCE(pagamentitipo.Descrizione,'') AS ListaPagamentoDescrizione, COALESCE(pagamentitipo.OnLine,0) AS ListaPagamentiTipoOnline FROM `vdocumenti` LEFT JOIN `utenti` ON `vdocumenti`.`UtentiId` = `utenti`.`Id` LEFT JOIN (SELECT id, Link_Tracking FROM `vettori`) AS vettori ON `vdocumenti`.`VettoriId` = `vettori`.`id` LEFT JOIN `pagamentitipo` ON `vdocumenti`.`PagamentiTipoId` = `pagamentitipo`.`id` LEFT JOIN `documenti` dpay ON dpay.`id` = `vdocumenti`.`Id` WHERE ((`vdocumenti`.`UtentiId` = ?UtentiId) AND (`vdocumenti`.`TipoDocumentiId` = ?TipoDocumentiId)) ORDER BY `vdocumenti`.`ID` DESC">
            <SelectParameters>
                <asp:SessionParameter Name="UtentiId" SessionField="UtentiID" Type="int32" />
                <asp:QueryStringParameter QueryStringField="t" Name="TipoDocumentiId" Type="Int16" />
            </SelectParameters>
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
                    <a href="myaccount.aspx" class="text">Account</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Documenti</span>
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
                                        <h3 class="fw-semibold mb-0">I miei documenti</h3>
                                        <div class="body-small text-main-2">Consulta ordini, fatture e DDT.</div>
                                    </div>
                                    <asp:HyperLink 
                                        ID="hlBackMyAccount" 
                                        runat="server"
                                        NavigateUrl="myaccount.aspx"
                                        CssClass="tf-btn btn-line">&laquo; Torna a My Account</asp:HyperLink>
                                </div>

                    <div class="ks-doc-typebar">
                        <div class="body-small text-main-2 mb-2">Seleziona il tipo di documento</div>
                        <div class="d-flex flex-wrap gap-2">
                            <a href="documenti.aspx?t=4" class="<%= If(Convert.ToString(Request.QueryString("t")) = "4", "selezionato", "nonSelezionato") %>">Ordini</a>
                            <a href="documenti.aspx?t=2" class="<%= If(Convert.ToString(Request.QueryString("t")) = "2", "selezionato", "nonSelezionato") %>">Fatture</a>
                            <a href="documenti.aspx?t=1" class="<%= If(Convert.ToString(Request.QueryString("t")) = "1", "selezionato", "nonSelezionato") %>">DDT</a>
                        </div>
                    </div>

                    <asp:Label runat="server" ID="lblInfo" Visible="false"></asp:Label>

                    <div class="ks-doc-filters">
                        <div class="row g-3">
                            <div class="col-12 col-lg-6">
                                <asp:Panel ID="Panel1" runat="server" Font-Size="Small" GroupingText="Ricerca rapida" CssClass="ks-fieldset">
                                    <div class="d-flex align-items-center gap-2 flex-wrap">
                                        <span class="body-small text-main-2">Visualizza</span>
                                        <asp:DropDownList ID="filtroTempo" runat="server" OnSelectedIndexChanged="filtroDataRapido" AutoPostBack="false" CssClass="form-select form-select-sm" onchange="return ksApplyDocumentFilters();">
                                            <asp:ListItem Value="-1" Selected="True">tutti i documenti</asp:ListItem>
                                            <asp:ListItem Value="7">i documenti dell'ultima settimana</asp:ListItem>
                                            <asp:ListItem Value="30">i documenti dell'ultimo mese</asp:ListItem>
                                            <asp:ListItem Value="60">i documenti degli ultimi due mesi</asp:ListItem>
                                            <asp:ListItem Value="90">i documenti degli ultimi tre mesi</asp:ListItem>
                                        </asp:DropDownList>
                                    </div>
                                </asp:Panel>
                            </div>

                            <div class="col-12 col-lg-6">
                                <asp:Panel ID="Panel2" runat="server" Font-Size="Small" GroupingText="Ricerca dettagliata" CssClass="ks-fieldset">
                                    <div class="row g-2">
                                        <div class="col-12 col-md-6">
                                            <div class="body-small text-main-2 mb-1">Dal</div>
                                            <div class="d-flex align-items-center gap-2">
                                                <asp:TextBox runat="server" ID="dataInizio" CssClass="tf-input" Width="150px"></asp:TextBox>
                                                <asp:ImageButton runat="server" ID="ib_calendarInizio" ImageUrl="/Public/Images/calendar_icon.gif" />
                                            </div>
                                        </div>

                                        <div class="col-12 col-md-6">
                                            <div class="body-small text-main-2 mb-1">Al</div>
                                            <div class="d-flex align-items-center gap-2">
                                                <asp:TextBox runat="server" ID="dataFine" CssClass="tf-input" Width="150px"></asp:TextBox>
                                                <asp:ImageButton runat="server" ID="ImageButton1" ImageUrl="/Public/Images/calendar_icon.gif" />
                                            </div>
                                        </div>
                                    </div>

                                    <div class="mt-2">
                                        <asp:Calendar ID="Calendar1" runat="server" Width="150px" Visible="false">
                                            <SelectedDayStyle BackColor="#4E4E4E" />
                                            <WeekendDayStyle BackColor="#C4C4C4" />
                                        </asp:Calendar>
                                        <asp:Calendar ID="Calendar2" runat="server" Width="150px" Visible="false">
                                            <SelectedDayStyle BackColor="#4E4E4E" />
                                            <WeekendDayStyle BackColor="#C4C4C4" />
                                        </asp:Calendar>
                                    </div>
                                </asp:Panel>
                            </div>
                        </div>

                        <div class="d-flex justify-content-end mt-3">
                            <asp:Button ID="Button1" runat="server" Text="Filtra" OnClick="applicaFiltri" CssClass="tf-btn btn-fill" OnClientClick="return ksApplyDocumentFilters();" />
                        </div>
                    </div>

                    <div class="row align-items-center g-2 my-3">
                        <div class="col-12 col-md-6">
                            <span class="body-md-2"><span class="text-secondary fw-semibold"><%= nDocTrovati %></span> documenti trovati</span>
                        </div>
                        <div class="col-12 col-md-6 d-flex justify-content-md-end align-items-center gap-2">
                            <span class="body-small text-main-2">Stato</span>
                            <asp:DropDownList ID="filtroStati" runat="server" AutoPostBack="False"
                                DataSourceID="sdsStatoOrdine" DataTextField="Descrizione1" DataValueField="id"
                                OnSelectedIndexChanged="applicaFiltri" OnDataBound="aggiungiStato" CssClass="form-select form-select-sm" onchange="return ksApplyDocumentFilters();">
                            </asp:DropDownList>
                        </div>
                    </div>

<div class="tf-order_history-table">
    <asp:GridView ID="GridView1" runat="server"
        AllowPaging="True"
        AutoGenerateColumns="False"
        DataKeyNames="id"
        DataSourceID="sdsDocumenti"
        EmptyDataText="Nessun documento presente"
        GridLines="None"
        PageSize="20"
        Width="100%"
        CssClass="table_def ks-order-table"
        UseAccessibleHeader="True"
        OnPreRender="GridView1_PreRender_22B">

        <EmptyDataRowStyle Font-Bold="False" Height="100px" HorizontalAlign="Center" />

        <Columns>
            <asp:TemplateField HeaderText="Numero">
                <ItemTemplate>
                    <div class="d-flex flex-column">
                        <div class="body-text-3">
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

                        <details class="ks-order-details mt-1">
                            <summary class="body-small link">Info</summary>
                            <div class="ks-order-details-body">
                                <div class="body-small"><strong>Destinatario:</strong> <%#: Eval("RagioneSociale") %> <%#: Eval("CognomeNome") %> - <%#: Eval("SedeLegale") %></div>
                                <div class="body-small"><strong>Altra destinazione:</strong> <%#: Eval("DestinazioneMerci") %></div>
                                <div class="body-small"><strong>Pagamento:</strong> <%#: Eval("ListaPagamentoDescrizione") %></div>
                                <div class="body-small"><strong>Spedizione:</strong> <%#: Eval("VettoriDescrizione") %></div>
                                <div class="body-small"><strong>Tracking:</strong> <%# separa_tracking(Eval("Tracking"), Eval("Link_Tracking")) %></div>
                                <div class="body-small" style="<%# testNote(Eval("Note")) %>"><strong>Note corriere:</strong> <%#: Eval("Note") %></div>
                                <div class="body-small"><strong>Note:</strong> <%#: Eval("NoteEsterne") %></div>
                            </div>
                        </details>
                    </div>
                </ItemTemplate>
            </asp:TemplateField>

            <asp:TemplateField HeaderText="Data">
                <ItemTemplate>
                    <span class="body-text-3"><%# Eval("DataDocumento", "{0:d}") %></span>
                </ItemTemplate>
            </asp:TemplateField>

            <asp:TemplateField HeaderText="Totale">
                <ItemTemplate>
                    <div class="d-flex flex-column">
                        <div class="body-text-3"><%# Eval("TotaleDocumento", "{0:C}") %></div>
                        <div class="body-small text-main-2">Imponibile: <%# Eval("TotImponibile", "{0:C}") %></div>
                    </div>
                </ItemTemplate>
            </asp:TemplateField>

            <asp:TemplateField HeaderText="Metodo pagamento">
                <ItemTemplate>
                    <span class="body-text-3"><%#: GetPaymentMethodLabel(Eval("ListaPagamentoDescrizione")) %></span>
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
                        <span class="body-small text-main-2"><%#: GetPaymentStatusDescription(Eval("ListaPagato"), Eval("ListaStatoPagamentoWeb"), Eval("ListaUltimoEsitoPagamentoWeb"), Eval("ListaPagamentiTipoOnline"), Eval("ListaPagamentoDescrizione")) %></span>
                    </div>
                </ItemTemplate>
            </asp:TemplateField>

            <asp:TemplateField HeaderText="Azione">
                <ItemTemplate>
                    <div class="ks-action-stack">

                        <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>" class="tf-btn btn-small d-inline-flex">
                            <span class="text-white">Dettaglio</span>
                        </a>

                    </div>
                </ItemTemplate>
            </asp:TemplateField>
            <asp:BoundField DataField="TotIva" HeaderText="Iva" SortExpression="TotIva" DataFormatString="{0:C}" Visible="False" />
            <asp:BoundField DataField="NDocumento" HeaderText="NDocumento" ReadOnly="True" Visible="False" />
            <asp:BoundField DataField="id" HeaderText="id" ReadOnly="True" SortExpression="id" Visible="False" />
        </Columns>

        <PagerStyle CssClass="nav" Font-Bold="True" />
        <HeaderStyle CssClass="title-sidebar fw-medium" />
        <EditRowStyle Font-Bold="False" />
        <RowStyle CssClass="td-order-item" Height="25px" />

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
