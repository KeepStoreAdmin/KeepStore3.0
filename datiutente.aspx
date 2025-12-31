<%@ Page Language="VB"
    MasterPageFile="~/Page.master"
    AutoEventWireup="false"
    CodeFile="datiutente.aspx.vb"
    Inherits="datiutente" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    I miei dati
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        .account-box {
            border: 1px solid #ddd;
            padding: 15px;
            margin-bottom: 20px;
            background-color: #fff;
        }

        .account-box h2 {
            font-size: 20px;
            margin-bottom: 10px;
        }

        .account-section-title {
            font-size: 16px;
            font-weight: bold;
            margin-bottom: 8px;
        }

        .account-field-label {
            font-weight: bold;
        }

        .account-field-value {
            margin-bottom: 5px;
        }

        .ks-loading-panel {
            border: 1px solid #ddd;
            background-color: #fff;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
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

        .ks-edit-buttons {
            margin-top: 20px;
            text-align: right;
        }

        .ks-edit-buttons .tf-btn-icon {
            margin-left: 5px;
        }

        .text-muted-small {
            font-size: 0.9rem;
            color: #666;
        }

        .text-error {
            color: red;
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

        // Prima apertura normale
        document.addEventListener('DOMContentLoaded', function () {
            ksHideSpinnerAndShowContent();
        });

        // Ritorno tramite "indietro" del browser / bfcache
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

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <h1>I miei dati</h1>

    <div style="margin-bottom:20px;">
        <asp:HyperLink 
            ID="hlBackMyAccount" 
            runat="server"
            NavigateUrl="myaccount.aspx"
            CssClass="tf-btn-icon type-2 style-white">
            &laquo; Torna alla pagina My Account
        </asp:HyperLink>
    </div>

    <asp:Label ID="lblEsito" runat="server" CssClass="text-error" EnableViewState="false"></asp:Label>

    <!-- SPINNER CARICAMENTO -->
    <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel">
        <div class="ks-spinner-circle"></div>
        <div>Caricamento dati in corso...</div>
    </asp:Panel>

    <!-- CONTENUTO PRINCIPALE -->
    <asp:Panel ID="pnlContent" runat="server" Style="display:none;">

        <asp:Panel ID="pnlDati" runat="server" CssClass="account-box">
            <asp:FormView ID="fvUtente" runat="server"
                DataSourceID="sdsUtente"
                Width="100%"
                DataKeyNames="id,UtentiId"
                DefaultMode="ReadOnly"
                OnModeChanging="fvUtente_ModeChanging"
                OnItemUpdating="fvUtente_ItemUpdating"
                OnDataBound="fvUtente_DataBound">

                <%-- TEMPLATE LETTURA --%>
                <ItemTemplate>

                    <div class="row">
                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Dati di accesso / account</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Username: </span>
                                <%# Eval("Username") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Email: </span>
                                <%# Eval("email") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Ultimo accesso: </span>
                                <%# Eval("ultimoaccesso", "{0:dd/MM/yyyy HH:mm}") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Codice cliente: </span>
                                <%# Eval("Codice") %>
                            </div>
                        </div>

                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Dati anagrafici / fiscali</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Ragione sociale: </span>
                                <%# Eval("RagioneSociale") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Cognome / Nome: </span>
                                <%# Eval("cognomenome") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Partita IVA: </span>
                                <%# Eval("Piva") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Codice fiscale: </span>
                                <%# Eval("CodiceFiscale") %>
                            </div>
                        </div>
                    </div>

                    <hr />

                    <div class="row">
                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Indirizzo di fatturazione</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Indirizzo: </span>
                                <%# Eval("Indirizzo") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">CAP: </span>
                                <%# Eval("Cap") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Città: </span>
                                <%# Eval("Citta") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Provincia: </span>
                                <%# Eval("Provincia") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Nazione: </span>
                                <%# Eval("Nazione") %>
                            </div>
                        </div>

                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Contatti</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Telefono: </span>
                                <%# Eval("Telefono") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Cellulare: </span>
                                <%# Eval("Cellulare") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Fax: </span>
                                <%# Eval("Fax") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Email: </span>
                                <%# Eval("email") %>
                            </div>
                        </div>
                    </div>

                    <hr />

                    <div class="row">
                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Profilo commerciale</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Listino attivo: </span>
                                <%# Eval("listino") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Tipo cliente: </span>
                                <%# Eval("UtenteTipoDescrizione") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Modalità prezzi: </span>
                                <%# IIf(Convert.ToInt32(Eval("IvaTipo")) = 1, "Prezzi IVA esclusa", "Prezzi IVA inclusa") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Esenzione IVA: </span>
                                <%# Eval("DescrizioneEsenzioneIva") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Reverse charge: </span>
                                <%# IIf(Convert.ToInt32(Eval("AbilitatoIvaReverseCharge")) = 1, "Attivo", "Non attivo") %>
                            </div>
                        </div>
                    </div>

                    <asp:Panel ID="pnlDestAltRead" runat="server" CssClass="mt-3" Visible="false">
                        <hr />
                        <div class="account-section-title">Destinazione alternativa (predefinita)</div>

                        <div class="account-field-value">
                            <span class="account-field-label">Ragione sociale: </span>
                            <asp:Label ID="lblDestAltRagioneSociale" runat="server" />
                        </div>

                        <div class="account-field-value">
                            <span class="account-field-label">Nome: </span>
                            <asp:Label ID="lblDestAltNome" runat="server" />
                        </div>

                        <div class="account-field-value">
                            <span class="account-field-label">Indirizzo: </span>
                            <asp:Label ID="lblDestAltIndirizzo" runat="server" />
                        </div>

                        <div class="account-field-value">
                            <span class="account-field-label">CAP: </span>
                            <asp:Label ID="lblDestAltCap" runat="server" />
                        </div>

                        <div class="account-field-value">
                            <span class="account-field-label">Città: </span>
                            <asp:Label ID="lblDestAltCitta" runat="server" />
                        </div>

                        <div class="account-field-value">
                            <span class="account-field-label">Provincia: </span>
                            <asp:Label ID="lblDestAltProvincia" runat="server" />
                        </div>

                        <div class="account-field-value">
                            <span class="account-field-label">Nazione: </span>
                            <asp:Label ID="lblDestAltNazione" runat="server" />
                        </div>
                    </asp:Panel>

                    <hr />

                    <p class="text-muted-small">
                        Per modificare i dati anagrafici completi (ad es. intestazione fiscale, partita IVA, ecc.)
                        contatta il nostro servizio clienti.
                    </p>

                    <div class="ks-edit-buttons">
                        <asp:Button ID="btnEdit" runat="server"
                            Text="Modifica dati"
                            CssClass="tf-btn-icon type-2 style-white"
                            CommandName="Edit" />
                    </div>

                </ItemTemplate>

                <%-- TEMPLATE MODIFICA --%>
                <EditItemTemplate>

                    <div class="row">
                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Dati di accesso / account</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Username: </span>
                                <%# Eval("Username") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Email: </span>
                                <asp:TextBox ID="tbEmailEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("email") %>' />
                            </div>
                        </div>

                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Dati anagrafici / fiscali</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Ragione sociale: </span>
                                <%# Eval("RagioneSociale") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Cognome / Nome: </span>
                                <%# Eval("cognomenome") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Partita IVA: </span>
                                <%# Eval("Piva") %>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Codice fiscale: </span>
                                <%# Eval("CodiceFiscale") %>
                            </div>
                        </div>
                    </div>

                    <hr />

                    <div class="row">
                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Indirizzo di fatturazione</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Indirizzo:</span><br />
                                <asp:TextBox ID="tbIndirizzoEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("Indirizzo") %>' />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">CAP:</span><br />
                                <asp:TextBox ID="tbCapEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("Cap") %>'
                                    AutoPostBack="True"
                                    OnTextChanged="tbCapEdit_TextChanged" />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Città:</span><br />
                                <asp:DropDownList ID="ddlCittaEdit" runat="server"
                                    CssClass="form-control"
                                    AutoPostBack="True"
                                    Visible="False"
                                    OnSelectedIndexChanged="ddlCittaEdit_SelectedIndexChanged">
                                </asp:DropDownList>
                                <asp:TextBox ID="tbCittaEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("Citta") %>' />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Provincia:</span><br />
                                <asp:TextBox ID="tbProvinciaEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("Provincia") %>' />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Nazione:</span><br />
                                <asp:TextBox ID="tbNazioneEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("Nazione") %>'
                                    ReadOnly="True" />
                            </div>

                            <asp:Label ID="lblCapMessage" runat="server"
                                CssClass="text-error"
                                EnableViewState="True"></asp:Label>
                        </div>

                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Contatti</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Telefono:</span><br />
                                <asp:TextBox ID="tbTelefonoEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("Telefono") %>' />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Cellulare:</span><br />
                                <asp:TextBox ID="tbCellulareEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("Cellulare") %>' />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Fax:</span><br />
                                <asp:TextBox ID="tbFaxEdit" runat="server"
                                    CssClass="form-control"
                                    Text='<%# Bind("Fax") %>' />
                            </div>
                        </div>
                    </div>

                    <hr />

                    <div class="row">
                        <div class="col-12 col-md-6">
                            <div class="account-section-title">Destinazione alternativa</div>

                            <div class="account-field-value">
                                <span class="account-field-label">Seleziona destinazione:</span><br />
                                <asp:DropDownList ID="ddlDestAlt" runat="server"
                                    CssClass="form-control"
                                    AutoPostBack="True"
                                    OnSelectedIndexChanged="ddlDestAlt_SelectedIndexChanged">
                                </asp:DropDownList>
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Ragione sociale:</span><br />
                                <asp:TextBox ID="tbRagioneSocialeAEdit" runat="server"
                                    CssClass="form-control" />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Nome:</span><br />
                                <asp:TextBox ID="tbNomeAEdit" runat="server"
                                    CssClass="form-control" />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Indirizzo:</span><br />
                                <asp:TextBox ID="tbIndirizzoAEdit" runat="server"
                                    CssClass="form-control" />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">CAP:</span><br />
                                <asp:TextBox ID="tbCapAEdit" runat="server"
                                    CssClass="form-control"
                                    AutoPostBack="True"
                                    OnTextChanged="tbCapAEdit_TextChanged" />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Città:</span><br />
                                <asp:DropDownList ID="ddlCittaAEdit" runat="server"
                                    CssClass="form-control"
                                    AutoPostBack="True"
                                    Visible="False"
                                    OnSelectedIndexChanged="ddlCittaAEdit_SelectedIndexChanged">
                                </asp:DropDownList>
                                <asp:TextBox ID="tbCittaAEdit" runat="server"
                                    CssClass="form-control" />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Provincia:</span><br />
                                <asp:TextBox ID="tbProvinciaAEdit" runat="server"
                                    CssClass="form-control" />
                            </div>

                            <div class="account-field-value">
                                <span class="account-field-label">Nazione:</span><br />
                                <asp:TextBox ID="tbNazioneAEdit" runat="server"
                                    CssClass="form-control"
                                    ReadOnly="True" />
                            </div>

                            <asp:Label ID="lblCapAMessage" runat="server"
                                CssClass="text-error"
                                EnableViewState="True"></asp:Label>
                        </div>

                        <div class="col-12 col-md-6">
                            <p class="text-muted-small">
                                Puoi gestire qui le tue destinazioni alternative per la spedizione merce.<br />
                                Seleziona dall'elenco una destinazione esistente oppure scegli
                                "<strong>Nuova destinazione</strong>" per inserirne una nuova.
                            </p>
                        </div>
                    </div>

                    <div class="ks-edit-buttons">
                        <asp:Button ID="btnUpdate" runat="server"
                            Text="Salva"
                            CssClass="tf-btn-icon type-2 style-white"
                            CommandName="Update"
                            OnClientClick="ksShowSpinnerOnSubmit();" />
                        <asp:Button ID="btnCancel" runat="server"
                            Text="Annulla"
                            CssClass="tf-btn-icon type-2 style-white"
                            CommandName="Cancel" />
                    </div>

                </EditItemTemplate>

            </asp:FormView>
        </asp:Panel>

        <!-- DATASOURCE: join vlogin + utenti + utentitipo -->
        <asp:SqlDataSource ID="sdsUtente" runat="server"
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="
                SELECT 
                    v.id,
                    v.Username,
                    v.email,
                    v.cognomenome,
                    v.ultimoaccesso,
                    v.utentiid AS UtentiId,
                    v.utentitipoid,
                    v.listino,
                    v.IvaTipo,
                    v.Abilitato,
                    v.UtentiAbilitato,
                    v.IdEsenzioneIva,
                    v.ValoreEsenzioneIva,
                    v.DescrizioneEsenzioneIva,
                    v.AbilitatoIvaReverseCharge,
                    u.RagioneSociale,
                    u.Indirizzo,
                    u.Cap,
                    u.Citta,
                    u.Provincia,
                    u.Nazione,
                    u.Telefono,
                    u.Cellulare,
                    u.Fax,
                    u.Piva,
                    u.CodiceFiscale,
                    u.Codice,
                    t.Descrizione AS UtenteTipoDescrizione
                FROM vlogin v
                INNER JOIN utenti u ON v.utentiid = u.id
                LEFT JOIN utentitipo t ON v.utentitipoid = t.id
                WHERE v.id = ?LoginId">
            <SelectParameters>
                <asp:SessionParameter Name="LoginId" SessionField="LoginId" Type="Int32" />
            </SelectParameters>
        </asp:SqlDataSource>

    </asp:Panel>

</asp:Content>
