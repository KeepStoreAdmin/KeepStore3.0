<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="documenti.aspx.vb" Inherits="documenti" Debug="true" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Consultazione documenti
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        /* KeepStore STEP22A (ONUS) - Tab tipo documento */
        .ks-doc-typebar { margin: 0 0 18px 0; }
        .ks-doc-typebar .selezionato,
        .ks-doc-typebar .nonSelezionato {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 10px 14px;
            border-radius: 14px;
            border: 1px solid rgba(0,0,0,0.10);
            text-decoration: none;
            font-size: 14px;
            line-height: 1;
            user-select: none;
            margin: 0;
        }
        .ks-doc-typebar .nonSelezionato { background: #ffffff; color: #111111; font-weight: 500; }
        .ks-doc-typebar .selezionato { background: #111111; color: #ffffff; font-weight: 700; border-color: #111111; }
        .ks-doc-typebar .nonSelezionato:hover { background: rgba(0,0,0,0.03); }

        /* Fieldset (Panel GroupingText) in stile card */
        .ks-fieldset {
            border: 1px solid rgba(0,0,0,0.08) !important;
            background: #ffffff;
            padding: 16px 16px 14px;
            border-radius: 16px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.04);
            margin: 0;
        }
        .ks-fieldset legend {
            width: auto !important;
            padding: 0 10px;
            font-size: 14px;
            font-weight: 700;
        }

        /* Spinner pagina */
        .ks-loading-panel {
            border: 1px solid #ddd;
            background-color: #fff;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
            border-radius: 16px;
        }

        .ks-spinner-circle {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            border: 3px solid #ccc;
            border-top-color: #333;
            animation: ks-spin 0.8s linear infinite;
            margin: 0 auto 8px;
        }

        @keyframes ks-spin {
            from { transform: rotate(0deg); }
            to   { transform: rotate(360deg); }
        }

        /* Sidebar sticky (desktop) */
        .ks-myaccount .wrap-sidebar-account {
            position: sticky;
            top: 110px;
        }
        @media (max-width: 991px) {
            .ks-myaccount .wrap-sidebar-account { position: static; top: auto; }
        }

        /* Form controls (minimo) */
        .ks-doc-filters .form-select,
        .ks-doc-filters input[type='text'] {
            max-width: 100%;
        }

        /* KeepStore STEP22B (ONUS) - Tabella ordine/documenti */
        .tf-order_history-table { margin-top: 12px; }
        .ks-order-table { width: 100%; }
        .ks-order-table th, .ks-order-table td { padding: 14px 12px; vertical-align: top; }
        .ks-order-table .td-order-item td { border-bottom: 1px solid rgba(0,0,0,0.06); }
        .ks-status-pill {
            display: inline-flex;
            align-items: center;
            padding: 6px 10px;
            border-radius: 999px;
            background: rgba(0,0,0,0.06);
            font-size: 12px;
            font-weight: 600;
            white-space: nowrap;
        }
        .ks-action-stack { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
        .ks-icon-btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 36px;
            height: 36px;
            border-radius: 10px;
            border: 1px solid rgba(0,0,0,0.12);
            background: #ffffff;
            padding: 0;
        }
        .ks-icon-btn img { max-width: 20px; max-height: 20px; }
        .ks-order-details summary { cursor: pointer; }
        .ks-order-details summary::-webkit-details-marker { display: none; }
        .ks-order-details-body {
            margin-top: 8px;
            padding: 10px 12px;
            border: 1px solid rgba(0,0,0,0.08);
            border-radius: 14px;
            background: rgba(0,0,0,0.02);
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
                    JQ('#' + popID).fadeIn().css({ 'width': Number(popWidth) }).prepend('<a href="#" class="close"><img src="public/images/close_pop.png" class="btn_close" title="Close Window" alt="Close" /></a>');

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
            <div><img src="Public/Images/Ok.png" alt="" /></div><br />
            <div>Richiesta inoltrata. Riceverà il documento presso la sua casella email !!!</div>
        </div>
        <% End If %>

        <asp:SqlDataSource ID="sdsDocumenti" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
            SelectCommand="SELECT * FROM (`vdocumenti` LEFT JOIN `utenti` ON ((`vdocumenti`.`UtentiId` = `utenti`.`Id`)) LEFT JOIN ( SELECT id, Link_Tracking FROM `vettori`) AS vettori ON (`vdocumenti`.`VettoriId` = `vettori`.`id`) ) Left Join pagamentitipo on vdocumenti.pagamentiTipoId = pagamentiTipo.id WHERE ( (UtentiId = ?UtentiId ) AND (TipoDocumentiId = ?TipoDocumentiId ) ) ORDER BY vdocumenti.ID DESC">
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

            <!-- Breakcrumbs (ONUS) -->
            <div class="tf-sp-1 pb-0">
                <div class="container">
                    <ul class="breakcrumbs">
                        <li><a href="Default.aspx" class="body-small link">Home</a></li>
                        <li class="d-flex align-items-center"><i class="icon icon-arrow-right"></i></li>
                        <li><a href="myaccount.aspx" class="body-small link">Account</a></li>
                        <li class="d-flex align-items-center"><i class="icon icon-arrow-right"></i></li>
                        <li><span class="body-small">Documenti</span></li>
                    </ul>
                </div>
            </div>

            <section class="tf-sp-2">
                <div class="container">
                    <div class="row">

                    <div class="col-lg-3">
                        <div class="wrap-sidebar-account">
                            <ul class="my-account-nav content-append">
                                <li><a href="myaccount.aspx" class="my-account-nav-item">Dashboard</a></li>
                                <li><a href="datiutente.aspx" class="my-account-nav-item">I miei dati</a></li>
                                <li>
                                    <% If Convert.ToString(Request.QueryString("t")) = "4" Then %>
                                        <span class="my-account-nav-item active">I miei ordini</span>
                                    <% Else %>
                                        <a href="documenti.aspx?t=4" class="my-account-nav-item">I miei ordini</a>
                                    <% End If %>
                                </li>
                                <li>
                                    <% If Convert.ToString(Request.QueryString("t")) = "2" Then %>
                                        <span class="my-account-nav-item active">Le mie fatture</span>
                                    <% Else %>
                                        <a href="documenti.aspx?t=2" class="my-account-nav-item">Le mie fatture</a>
                                    <% End If %>
                                </li>
                                <li>
                                    <% If Convert.ToString(Request.QueryString("t")) = "1" Then %>
                                        <span class="my-account-nav-item active">I miei DDT</span>
                                    <% Else %>
                                        <a href="documenti.aspx?t=1" class="my-account-nav-item">I miei DDT</a>
                                    <% End If %>
                                </li>
                                <li><a href="wishlist.aspx" class="my-account-nav-item">Wishlist</a></li>
                                <li><a href="password.aspx" class="my-account-nav-item">Cambia password</a></li>
                                <li><a href="logout.aspx" class="my-account-nav-item">Logout</a></li>
                            </ul>
                        </div>
                    </div>

                        <div class="col-lg-9">
                            <div class="my-account-content account-dashboard">

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

                    <div class="ks-doc-filters">
                        <div class="row g-3">
                            <div class="col-12 col-lg-6">
                                <asp:Panel ID="Panel1" runat="server" Font-Size="Small" GroupingText="Ricerca rapida" CssClass="ks-fieldset">
                                    <div class="d-flex align-items-center gap-2 flex-wrap">
                                        <span class="body-small text-main-2">Visualizza</span>
                                        <asp:DropDownList ID="filtroTempo" runat="server" OnSelectedIndexChanged="filtroDataRapido" AutoPostBack="true" CssClass="form-select form-select-sm">
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
                                                <asp:ImageButton runat="server" ID="ib_calendarInizio" ImageUrl="Public/Images/calendar_icon.gif" />
                                            </div>
                                        </div>

                                        <div class="col-12 col-md-6">
                                            <div class="body-small text-main-2 mb-1">Al</div>
                                            <div class="d-flex align-items-center gap-2">
                                                <asp:TextBox runat="server" ID="dataFine" CssClass="tf-input" Width="150px"></asp:TextBox>
                                                <asp:ImageButton runat="server" ID="ImageButton1" ImageUrl="Public/Images/calendar_icon.gif" />
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
                            <asp:Button ID="Button1" runat="server" Text="Filtra" OnClick="applicaFiltri" CssClass="tf-btn btn-fill" OnClientClick="ksShowSpinnerOnSubmit();" />
                        </div>
                    </div>

                    <div class="row align-items-center g-2 my-3">
                        <div class="col-12 col-md-6">
                            <span class="body-md-2"><span class="text-secondary fw-semibold"><%= nDocTrovati %></span> documenti trovati</span>
                        </div>
                        <div class="col-12 col-md-6 d-flex justify-content-md-end align-items-center gap-2">
                            <span class="body-small text-main-2">Stato</span>
                            <asp:DropDownList ID="filtroStati" runat="server" AutoPostBack="True"
                                DataSourceID="sdsStatoOrdine" DataTextField="Descrizione1" DataValueField="id"
                                OnSelectedIndexChanged="applicaFiltri" OnDataBound="aggiungiStato" CssClass="form-select form-select-sm">
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
            <!-- Numero documento -->
            <asp:TemplateField HeaderText="Numero">
                <ItemTemplate>
                    <div class="d-flex flex-column">
                        <div class="body-text-3">
                            <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then %>
                                <asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="idcoupon" runat="server"
                                    NavigateUrl='<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>'
                                    Text='<%# Eval("NDocumento") %>'
                                    ToolTip='<%# "Visualizza Dettagli " & Eval("tipodocumentidescrizione") %>'>
                                </asp:HyperLink>
                                <!-- Hidden iddoc (compatibilità RowCommand legacy) -->
                                <asp:HyperLink ID="iddoc" runat="server" Visible="false"
                                    NavigateUrl='<%# Eval("id", "documentidettaglio.aspx?id={0}") %>'
                                    Text='<%# Eval("NDocumento") %>'></asp:HyperLink>
                            <% Else %>
                                <asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="iddoc" runat="server"
                                    NavigateUrl='<%# Eval("id", "documentidettaglio.aspx?id={0}") %>'
                                    Text='<%# Eval("NDocumento") %>'
                                    ToolTip='<%# "Visualizza Dettagli " & Eval("tipodocumentidescrizione") %>'>
                                </asp:HyperLink>
                            <% End If %>
                        </div>

                        <details class="ks-order-details mt-1">
                            <summary class="body-small link">Info</summary>
                            <div class="ks-order-details-body">
                                <div class="body-small"><strong>Destinatario:</strong> <%# Eval("RagioneSociale") %> <%# Eval("CognomeNome") %> - <%# Eval("SedeLegale") %></div>
                                <div class="body-small"><strong>Altra destinazione:</strong> <%# Eval("DestinazioneMerci") %></div>
                                <div class="body-small"><strong>Pagamento:</strong> <%# Eval("PagamentiTipoDescrizione") %></div>
                                <div class="body-small"><strong>Spedizione:</strong> <%# Eval("VettoriDescrizione") %></div>
                                <div class="body-small"><strong>Tracking:</strong> <%# separa_tracking(Eval("Tracking"), Eval("Link_Tracking")) %></div>
                                <div class="body-small" style="<%# testNote(Eval("Note")) %>"><strong>Note corriere:</strong> <%# Eval("Note") %></div>
                                <div class="body-small"><strong>Note:</strong> <%# Eval("NoteEsterne") %></div>
                            </div>
                        </details>
                    </div>
                </ItemTemplate>
            </asp:TemplateField>

            <!-- Data -->
            <asp:TemplateField HeaderText="Data">
                <ItemTemplate>
                    <span class="body-text-3"><%# Eval("DataDocumento", "{0:d}") %></span>
                </ItemTemplate>
            </asp:TemplateField>

            <!-- Stato -->
            <asp:TemplateField HeaderText="Stato">
                <ItemTemplate>
                    <span class="body-text-3 ks-status-pill"><%# Eval("StatiDescrizione1") %></span>
                </ItemTemplate>
            </asp:TemplateField>

            <!-- Totale -->
            <asp:TemplateField HeaderText="Totale">
                <ItemTemplate>
                    <div class="d-flex flex-column">
                        <div class="body-text-3"><%# Eval("TotaleDocumento", "{0:C}") %></div>
                        <div class="body-small text-main-2">Imponibile: <%# Eval("TotImponibile", "{0:C}") %></div>
                    </div>
                </ItemTemplate>
            </asp:TemplateField>

            <!-- Azione -->
            <asp:TemplateField HeaderText="Azione">
                <ItemTemplate>
                    <div class="ks-action-stack">

                        <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then %>
                            <a href="<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>" class="tf-btn btn-small d-inline-flex">
                                <span class="text-white">Dettaglio</span>
                            </a>
                        <% Else %>
                            <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>" class="tf-btn btn-small d-inline-flex">
                                <span class="text-white">Dettaglio</span>
                            </a>
                        <% End If %>

                        <asp:ImageButton ID="imgStampaDoc" idDoc='<%# Eval("id")%>' runat="server"
                            ToolTip="Richiedi documento tramite posta elettronica"
                            ImageUrl="images/pdf2mail.png" OnClick="stampaClick" CssClass="ks-icon-btn" />

                        <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then %>
                            <a href="<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>"
                               class="ks-icon-btn"
                               style="display:<%# IIf(Eval("Pagato") = 1 Or (Eval("PagamentiTipoOnline") = 0), "", "none")%>;">
                                <img src="Public/Images/Pagato.png" alt="Pagato" />
                            </a>
                        <% Else %>
                            <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>"
                               class="ks-icon-btn"
                               style="display:<%# IIf((Eval("Pagato") = 1 And (Eval("PagamentiTipoOnline") > 0)) Or (Eval("CodiceAutorizzazione") <> ""), "", "none")%>;">
                                <img src="Public/Images/Pagato.png" alt="Pagato" />
                            </a>
                            <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>"
                               class="ks-icon-btn"
                               style="display:<%# MostraPagaOra(Eval("Pagato"), Eval("CodiceAutorizzazione"), Eval("StatiId"), Eval("PagamentiTipoOnline")) %>;">
                                <img src="Public/Images/Paga_Ora.png" alt="Paga ora" />
                            </a>
                        <% End If %>

                        <a <%# SafeTrackingHref(Eval("Tracking")) %> class="ks-icon-btn" target="_blank" title="Tracking">
                            <img src='<%# GetTrackingImage(Eval("Tracking")) %>' alt="Tracking" />
                        </a>

                    </div>
                </ItemTemplate>
            </asp:TemplateField>

            <!-- Campi tecnici nascosti -->
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

    <script runat="server">
        ' KeepStore STEP22B: forza <thead> per compatibilita stile ONUS
        Protected Sub GridView1_PreRender_22B(ByVal sender As Object, ByVal e As System.EventArgs)
            Try
                Dim gv As System.Web.UI.WebControls.GridView = TryCast(sender, System.Web.UI.WebControls.GridView)
                If gv Is Nothing Then Exit Sub
                gv.UseAccessibleHeader = True
                If gv.HeaderRow IsNot Nothing Then
                    gv.HeaderRow.TableSection = System.Web.UI.WebControls.TableRowSection.TableHeader
                End If
            Catch
            End Try
        End Sub

        Function testNote(ByVal note As Object) As String
            Try
                Return CStr(IIf(note = "", "display:none;", ""))
            Catch
                Return "display:none;"
            End Try
        End Function

        ' Sanifica l’href del tracking (no javascript:, no valori vuoti, no DBNull)
        Function SafeTrackingHref(ByVal trackingObj As Object) As String
            Try
                If trackingObj Is Nothing OrElse IsDBNull(trackingObj) Then
                    Return ""
                End If

                Dim url As String = trackingObj.ToString().Trim()
                If String.IsNullOrEmpty(url) Then
                    Return ""
                End If

                Dim lower As String = url.ToLowerInvariant()
                If Not (lower.StartsWith("http://") OrElse lower.StartsWith("https://")) Then
                    ' Blocca link non sicuri (javascript:, data:, ecc.)
                    Return ""
                End If

                Dim safeUrl As String = System.Web.HttpUtility.HtmlAttributeEncode(url)
                Return "href=""" & safeUrl & """"
            Catch
                Return ""
            End Try
        End Function

        ' Gestisce la logica del tracking multiplo usando il template Link_Tracking
        Function separa_tracking(ByVal trackingObj As Object, ByVal linkTrackingObj As Object) As String
            Dim tracking As String = ""
            Dim link_tracking As String = ""

            If trackingObj IsNot Nothing AndAlso Not IsDBNull(trackingObj) Then
                tracking = trackingObj.ToString()
            End If

            If linkTrackingObj IsNot Nothing AndAlso Not IsDBNull(linkTrackingObj) Then
                link_tracking = linkTrackingObj.ToString()
            End If

            If String.IsNullOrWhiteSpace(tracking) OrElse String.IsNullOrWhiteSpace(link_tracking) Then
                Return ""
            End If

            Dim ltLower As String = link_tracking.ToLowerInvariant()
            If Not (ltLower.StartsWith("http://") OrElse ltLower.StartsWith("https://")) Then
                ' Template di tracking non sicuro: non mostro nulla
                Return ""
            End If

            Dim temp As String() = tracking.Split(";"c)
            Dim sb As New System.Text.StringBuilder()

            For Each codiceRaw As String In temp
                Dim codice As String = codiceRaw.Trim()
                If codice <> "" Then
                    Dim safeCode As String = System.Web.HttpUtility.HtmlEncode(codice)
                    Dim href As String = link_tracking.Replace("#ID#", codice)
                    Dim safeHref As String = System.Web.HttpUtility.HtmlAttributeEncode(href)

                    sb.Append("<img src=""Public/Images/interrogativo.png"" alt="""" title=""Clicca sul Numero Tracking"">")
                    sb.Append("<a href=""")
                    sb.Append(safeHref)
                    sb.Append(""" target=""_blank"">")
                    sb.Append(safeCode)
                    sb.Append("</a>; ")
                End If
            Next

            Return sb.ToString()
        End Function
    </script>

</asp:Content>
