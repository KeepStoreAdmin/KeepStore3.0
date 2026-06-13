<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="datiutente.aspx.vb" Inherits="datiutente" %>

<asp:Content ID="ContentTitle" ContentPlaceHolderID="TitleContent" runat="server">
    I miei dati
</asp:Content>

<asp:Content ID="ContentHead" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/datiutente-ui.css") %>" />
</asp:Content>

<asp:Content ID="ContentBreadcrumb" ContentPlaceHolderID="BreadcrumbContent" runat="server">
</asp:Content>

<asp:Content ID="ContentMain" ContentPlaceHolderID="MainContent" runat="server">

    <asp:ScriptManager ID="ScriptManager1" runat="server" />

    <div class="ks-myaccount ks-userdata js-ks-userdata">
        <div class="tf-sp-1 pb-0 ks-userdata-modern-breadcrumb">
            <div class="container">
                <div class="tf-breadcrumb-wrap">
                    <div class="tf-breadcrumb-list">
                        <a href="Default.aspx" class="text">Home</a>
                        <i class="icon icon-arrow-right"></i>
                        <a href="myaccount.aspx" class="text">Account</a>
                        <i class="icon icon-arrow-right"></i>
                        <span class="text">I miei dati</span>
                    </div>
                </div>
            </div>
        </div>

        <section class="tf-sp-2 ks-userdata-modern">
            <div class="container">
                <div class="myaccount-content account-dashboard">
                    <div class="ks-userdata-hero">
                        <div>
                            <h3 class="fw-semibold mb-2">Gestione dati account</h3>
                            <p class="body-md-2 text-main-2 mb-0">Per modificare i dati personali, di fatturazione o gli indirizzi usa le sezioni aggiornate dell'area cliente.</p>
                        </div>
                        <a href="myaccount.aspx" class="tf-btn btn-line">Torna al mio account</a>
                    </div>

                    <div class="ks-userdata-actions-card">
                        <div class="ks-dashboard-card-head">
                            <div>
                                <h4 class="fw-semibold mb-1">Dati account</h4>
                                <p class="body-small text-main-2 mb-0">Questa pagina resta disponibile come ponte legacy di compatibilita.</p>
                            </div>
                            <i class="icon-user"></i>
                        </div>

                        <div class="ks-userdata-actions">
                            <a href="my-account-edit.aspx" class="tf-btn btn-fill">Modifica dati account</a>
                            <a href="my-account-address.aspx" class="tf-btn btn-line">Rubrica indirizzi</a>
                            <a href="myaccount.aspx" class="tf-btn btn-line">Torna al mio account</a>
                        </div>
                    </div>

                    <div class="ks-userdata-legacy-card">
                        <div class="d-flex flex-wrap align-items-start justify-content-between gap-3 mb-3">
                            <div>
                                <h4 class="fw-semibold mb-1">Sezione legacy di compatibilita</h4>
                                <p class="body-small text-main-2 mb-0">Consulta i dati storici qui sotto solo se arrivi da un vecchio collegamento.</p>
                            </div>
                            <div class="ks-userdata-tab-links js-ks-userdata-tabs" role="tablist">
                                <a class="tf-btn btn-line nav-link" href="datiutente.aspx">Dettagli account</a>
                                <a class="tf-btn btn-line nav-link" href="datiutente.aspx?tab=addr">Indirizzi</a>
                            </div>
                        </div>

        <asp:UpdateProgress ID="updProgress" runat="server">
            <ProgressTemplate>
                <div class="alert alert-info py-2 px-3 d-inline-flex align-items-center gap-2 mb-3" role="status">
                    <span class="spinner-border spinner-border-sm" aria-hidden="true"></span>
                    <span>Caricamento dati in corso…</span>
                </div>
            </ProgressTemplate>
        </asp:UpdateProgress>

        <asp:UpdatePanel ID="updMain" runat="server" UpdateMode="Conditional">
            <ContentTemplate>

                <asp:Label ID="lblEsito" runat="server" EnableViewState="false" CssClass="ks-esito alert alert-info py-2 px-3 mb-3" />

                <%--
                    Compatibilità: in base alle versioni del progetto, il code-behind può
                    referenziare FormView con ID differenti.

                    - FormView1 (default comune)
                    - fvDatiUtente (più descrittivo)
                    - fvUtente (variante breve)

                    Lo script UI rende visibile
                    automaticamente il FormView che risulta effettivamente popolato.
                --%>

                <div class="ks-userdata-formview js-ks-userdata-fv" data-fv-id="FormView1">
                <asp:FormView ID="FormView1" runat="server" RenderOuterTable="false">

                    <%-- TEMPLATE LETTURA --%>
                    <ItemTemplate>

                        <div class="ks-userdata-pane ks-userdata-pane-details">
                            <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
                                <h3 class="h6 mb-0 fw-semibold">Dettagli account</h3>
                                <asp:LinkButton ID="btnEdit" runat="server" CommandName="Edit" CssClass="btn btn-primary btn-sm">
                                    Modifica dati
                                </asp:LinkButton>
                            </div>

                            <div class="row g-3">
                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Dati di accesso</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Username</dt>
                                                <dd class="col-7"><%#: Eval("username") %></dd>

                                                <dt class="col-5">Email</dt>
                                                <dd class="col-7"><%#: Eval("email") %></dd>

                                                <dt class="col-5">Password</dt>
                                                <dd class="col-7">********</dd>

                                                <dt class="col-5">Ultimo accesso</dt>
                                                <dd class="col-7"><%#: Eval("ultimoaccesso") %></dd>
                                            </dl>

                                            <div class="mt-3">
                                                <a class="btn btn-outline-secondary btn-sm" href="password.aspx">Cambia password</a>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Profilo commerciale</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Codice cliente</dt>
                                                <dd class="col-7"><%#: Eval("Codice") %></dd>

                                                <dt class="col-5">Listino</dt>
                                                <dd class="col-7"><%#: Eval("listino") %></dd>

                                                <dt class="col-5">Tipo utente</dt>
                                                <dd class="col-7"><%#: Eval("UtenteTipoDescrizione") %></dd>

                                                <dt class="col-5">Modalità IVA</dt>
                                                <dd class="col-7">
                                                    <%#: If(Convert.ToInt32(Eval("IvaTipo")) = 1, "Prezzi IVA esclusa", "Prezzi IVA inclusa") %>
                                                </dd>

                                                <dt class="col-5">Esenzione IVA</dt>
                                                <dd class="col-7"><%#: Eval("DescrizioneEsenzioneIva") %></dd>

                                                <dt class="col-5">Reverse charge</dt>
                                                <dd class="col-7"><%#: If(Convert.ToBoolean(Eval("AbilitatoIvaReverseCharge")), "Si", "No") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Dati intestazione</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Ragione sociale</dt>
                                                <dd class="col-7"><%#: Eval("RagioneSociale") %></dd>

                                                <dt class="col-5">Nome / Cognome</dt>
                                                <dd class="col-7"><%#: Eval("cognomenome") %></dd>

                                                <dt class="col-5">Partita IVA</dt>
                                                <dd class="col-7"><%#: Eval("Piva") %></dd>

                                                <dt class="col-5">Codice fiscale</dt>
                                                <dd class="col-7"><%#: Eval("CodiceFiscale") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Contatti</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Telefono</dt>
                                                <dd class="col-7"><%#: Eval("Telefono") %></dd>

                                                <dt class="col-5">Cellulare</dt>
                                                <dd class="col-7"><%#: Eval("Cellulare") %></dd>

                                                <dt class="col-5">Fax</dt>
                                                <dd class="col-7"><%#: Eval("Fax") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Indirizzo di fatturazione</span>
                                        </div>
                                        <div class="card-body">
                                            <div class="row g-3">
                                                <div class="col-12 col-md-6">
                                                    <div class="text-muted small">Indirizzo</div>
                                                    <div class="fw-medium"><%#: Eval("Indirizzo") %></div>
                                                </div>
                                                <div class="col-6 col-md-2">
                                                    <div class="text-muted small">CAP</div>
                                                    <div class="fw-medium"><%#: Eval("Cap") %></div>
                                                </div>
                                                <div class="col-6 col-md-4">
                                                    <div class="text-muted small">Città</div>
                                                    <div class="fw-medium"><%#: Eval("Citta") %></div>
                                                </div>
                                                <div class="col-6 col-md-2">
                                                    <div class="text-muted small">Provincia</div>
                                                    <div class="fw-medium"><%#: Eval("Provincia") %></div>
                                                </div>
                                                <div class="col-6 col-md-4">
                                                    <div class="text-muted small">Nazione</div>
                                                    <div class="fw-medium"><%#: Eval("Nazione") %></div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                            </div>
                        </div>

                        <div class="ks-userdata-pane ks-userdata-pane-addresses" id="addr">
                            <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
                                <h3 class="h6 mb-0 fw-semibold">Indirizzi</h3>
                                <a class="btn btn-outline-primary btn-sm" href="datiutente.aspx">Torna ai dettagli</a>
                            </div>

                            <div class="card">
                                <div class="card-header py-3">
                                    <span class="fw-semibold">Destinazione alternativa (predefinita)</span>
                                </div>
                                <div class="card-body">
                                    <div class="text-muted small mb-3">Se non impostata, verrà usato l’indirizzo di fatturazione.</div>

                                    <dl class="row ks-kv mb-0">
                                        <dt class="col-5">Ragione sociale</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestRagioneSociale" runat="server" /></dd>

                                        <dt class="col-5">Nome</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestNome" runat="server" /></dd>

                                        <dt class="col-5">Cognome</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCognome" runat="server" /></dd>

                                        <dt class="col-5">Indirizzo</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestIndirizzo" runat="server" /></dd>

                                        <dt class="col-5">CAP</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCap" runat="server" /></dd>

                                        <dt class="col-5">Città</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCitta" runat="server" /></dd>

                                        <dt class="col-5">Provincia</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestProvincia" runat="server" /></dd>

                                        <dt class="col-5">Nazione</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestNazione" runat="server" /></dd>

                                        <dt class="col-5">Telefono</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestTelefono" runat="server" /></dd>
                                    </dl>

                                    <div class="mt-3">
                                        <asp:LinkButton ID="btnEditAddr" runat="server" CommandName="Edit" CssClass="btn btn-primary btn-sm">
                                            Gestisci indirizzi
                                        </asp:LinkButton>
                                    </div>
                                </div>
                            </div>
                        </div>

                    </ItemTemplate>

                    <%-- TEMPLATE MODIFICA --%>
                    <EditItemTemplate>

                        <div class="alert alert-warning py-2 px-3 mb-3" role="alert">
                            <strong>Nota:</strong> dopo il salvataggio potrebbero essere necessari alcuni secondi perché i dati si aggiornino.
                        </div>

                        <div class="row g-3">

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Dati di accesso</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <label class="form-label">Username</label>
                                                <div class="form-control-plaintext fw-medium"><%#: Eval("username") %></div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="txtEmail">Email</label>
                                                <asp:TextBox ID="txtEmail" runat="server" CssClass="form-control" Text='<%# Bind("email") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Indirizzo di fatturazione</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12">
                                                <label class="form-label" for="txtIndirizzo">Indirizzo</label>
                                                <asp:TextBox ID="txtIndirizzo" runat="server" CssClass="form-control" Text='<%# Bind("Indirizzo") %>' />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="txtCap">CAP</label>
                                                <asp:TextBox ID="txtCap" runat="server" CssClass="form-control" Text='<%# Bind("Cap") %>' />
                                            </div>
                                            <div class="col-12 col-md-5">
                                                <label class="form-label" for="txtCitta">Città</label>
                                                <asp:TextBox ID="txtCitta" runat="server" CssClass="form-control" Text='<%# Bind("Citta") %>' />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="txtProvincia">Provincia</label>
                                                <asp:TextBox ID="txtProvincia" runat="server" CssClass="form-control" Text='<%# Bind("Provincia") %>' />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="txtNazione">Nazione</label>
                                                <asp:TextBox ID="txtNazione" runat="server" CssClass="form-control" Text='<%# Bind("Nazione") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Contatti</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtTelefono">Telefono</label>
                                                <asp:TextBox ID="txtTelefono" runat="server" CssClass="form-control" Text='<%# Bind("Telefono") %>' />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtCellulare">Cellulare</label>
                                                <asp:TextBox ID="txtCellulare" runat="server" CssClass="form-control" Text='<%# Bind("Cellulare") %>' />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtFax">Fax</label>
                                                <asp:TextBox ID="txtFax" runat="server" CssClass="form-control" Text='<%# Bind("Fax") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12" id="addrEdit">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Destinazione alternativa</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="ddlDestinazione">Seleziona destinazione</label>
                                                <asp:DropDownList ID="ddlDestinazione" runat="server" CssClass="form-select" AutoPostBack="true" />
                                            </div>
                                            <div class="col-12"></div>

                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="tbDestRagioneSociale">Ragione sociale</label>
                                                <asp:TextBox ID="tbDestRagioneSociale" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestNome">Nome</label>
                                                <asp:TextBox ID="tbDestNome" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestCognome">Cognome</label>
                                                <asp:TextBox ID="tbDestCognome" runat="server" CssClass="form-control" />
                                            </div>

                                            <div class="col-12">
                                                <label class="form-label" for="tbDestIndirizzo">Indirizzo</label>
                                                <asp:TextBox ID="tbDestIndirizzo" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestCap">CAP</label>
                                                <asp:TextBox ID="tbDestCap" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-5">
                                                <label class="form-label" for="tbDestCitta">Città</label>
                                                <asp:TextBox ID="tbDestCitta" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="tbDestProvincia">Provincia</label>
                                                <asp:TextBox ID="tbDestProvincia" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="tbDestNazione">Nazione</label>
                                                <asp:TextBox ID="tbDestNazione" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="tbDestTelefono">Telefono</label>
                                                <asp:TextBox ID="tbDestTelefono" runat="server" CssClass="form-control" />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="d-flex flex-wrap align-items-center gap-2">
                                    <asp:LinkButton ID="btnUpdate" runat="server" CommandName="Update" CssClass="btn btn-success">
                                        Salva dati
                                    </asp:LinkButton>
                                    <asp:LinkButton ID="btnCancel" runat="server" CommandName="Cancel" CssClass="btn btn-outline-secondary">
                                        Annulla
                                    </asp:LinkButton>
                                </div>
                            </div>

                        </div>

                    </EditItemTemplate>

                </asp:FormView>
                </div>

                <div class="ks-userdata-formview js-ks-userdata-fv" data-fv-id="fvDatiUtente">
                <asp:FormView ID="fvDatiUtente" runat="server" RenderOuterTable="false">

                    <%-- TEMPLATE LETTURA --%>
                    <ItemTemplate>

                        <div class="ks-userdata-pane ks-userdata-pane-details">
                            <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
                                <h3 class="h6 mb-0 fw-semibold">Dettagli account</h3>
                                <asp:LinkButton ID="btnEdit" runat="server" CommandName="Edit" CssClass="btn btn-primary btn-sm">
                                    Modifica dati
                                </asp:LinkButton>
                            </div>

                            <div class="row g-3">
                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Dati di accesso</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Username</dt>
                                                <dd class="col-7"><%#: Eval("username") %></dd>

                                                <dt class="col-5">Email</dt>
                                                <dd class="col-7"><%#: Eval("email") %></dd>

                                                <dt class="col-5">Password</dt>
                                                <dd class="col-7">********</dd>

                                                <dt class="col-5">Ultimo accesso</dt>
                                                <dd class="col-7"><%#: Eval("ultimoaccesso") %></dd>
                                            </dl>

                                            <div class="mt-3">
                                                <a class="btn btn-outline-secondary btn-sm" href="password.aspx">Cambia password</a>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Profilo commerciale</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Codice cliente</dt>
                                                <dd class="col-7"><%#: Eval("Codice") %></dd>

                                                <dt class="col-5">Listino</dt>
                                                <dd class="col-7"><%#: Eval("listino") %></dd>

                                                <dt class="col-5">Tipo utente</dt>
                                                <dd class="col-7"><%#: Eval("UtenteTipoDescrizione") %></dd>

                                                <dt class="col-5">Modalità IVA</dt>
                                                <dd class="col-7">
                                                    <%#: If(Convert.ToInt32(Eval("IvaTipo")) = 1, "Prezzi IVA esclusa", "Prezzi IVA inclusa") %>
                                                </dd>

                                                <dt class="col-5">Esenzione IVA</dt>
                                                <dd class="col-7"><%#: Eval("DescrizioneEsenzioneIva") %></dd>

                                                <dt class="col-5">Reverse charge</dt>
                                                <dd class="col-7"><%#: If(Convert.ToBoolean(Eval("AbilitatoIvaReverseCharge")), "Si", "No") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Dati intestazione</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Ragione sociale</dt>
                                                <dd class="col-7"><%#: Eval("RagioneSociale") %></dd>

                                                <dt class="col-5">Nome / Cognome</dt>
                                                <dd class="col-7"><%#: Eval("cognomenome") %></dd>

                                                <dt class="col-5">Partita IVA</dt>
                                                <dd class="col-7"><%#: Eval("Piva") %></dd>

                                                <dt class="col-5">Codice fiscale</dt>
                                                <dd class="col-7"><%#: Eval("CodiceFiscale") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Contatti</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Telefono</dt>
                                                <dd class="col-7"><%#: Eval("Telefono") %></dd>

                                                <dt class="col-5">Cellulare</dt>
                                                <dd class="col-7"><%#: Eval("Cellulare") %></dd>

                                                <dt class="col-5">Fax</dt>
                                                <dd class="col-7"><%#: Eval("Fax") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Indirizzo di fatturazione</span>
                                        </div>
                                        <div class="card-body">
                                            <div class="row g-3">
                                                <div class="col-12 col-md-6">
                                                    <div class="text-muted small">Indirizzo</div>
                                                    <div class="fw-medium"><%#: Eval("Indirizzo") %></div>
                                                </div>
                                                <div class="col-6 col-md-2">
                                                    <div class="text-muted small">CAP</div>
                                                    <div class="fw-medium"><%#: Eval("Cap") %></div>
                                                </div>
                                                <div class="col-6 col-md-4">
                                                    <div class="text-muted small">Città</div>
                                                    <div class="fw-medium"><%#: Eval("Citta") %></div>
                                                </div>
                                                <div class="col-6 col-md-2">
                                                    <div class="text-muted small">Provincia</div>
                                                    <div class="fw-medium"><%#: Eval("Provincia") %></div>
                                                </div>
                                                <div class="col-6 col-md-4">
                                                    <div class="text-muted small">Nazione</div>
                                                    <div class="fw-medium"><%#: Eval("Nazione") %></div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                            </div>
                        </div>

                        <div class="ks-userdata-pane ks-userdata-pane-addresses" id="addr">
                            <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
                                <h3 class="h6 mb-0 fw-semibold">Indirizzi</h3>
                                <a class="btn btn-outline-primary btn-sm" href="datiutente.aspx">Torna ai dettagli</a>
                            </div>

                            <div class="card">
                                <div class="card-header py-3">
                                    <span class="fw-semibold">Destinazione alternativa (predefinita)</span>
                                </div>
                                <div class="card-body">
                                    <div class="text-muted small mb-3">Se non impostata, verrà usato l’indirizzo di fatturazione.</div>

                                    <dl class="row ks-kv mb-0">
                                        <dt class="col-5">Ragione sociale</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestRagioneSociale" runat="server" /></dd>

                                        <dt class="col-5">Nome</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestNome" runat="server" /></dd>

                                        <dt class="col-5">Cognome</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCognome" runat="server" /></dd>

                                        <dt class="col-5">Indirizzo</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestIndirizzo" runat="server" /></dd>

                                        <dt class="col-5">CAP</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCap" runat="server" /></dd>

                                        <dt class="col-5">Città</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCitta" runat="server" /></dd>

                                        <dt class="col-5">Provincia</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestProvincia" runat="server" /></dd>

                                        <dt class="col-5">Nazione</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestNazione" runat="server" /></dd>

                                        <dt class="col-5">Telefono</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestTelefono" runat="server" /></dd>
                                    </dl>

                                    <div class="mt-3">
                                        <asp:LinkButton ID="btnEditAddr" runat="server" CommandName="Edit" CssClass="btn btn-primary btn-sm">
                                            Gestisci indirizzi
                                        </asp:LinkButton>
                                    </div>
                                </div>
                            </div>
                        </div>

                    </ItemTemplate>

                    <%-- TEMPLATE MODIFICA --%>
                    <EditItemTemplate>

                        <div class="alert alert-warning py-2 px-3 mb-3" role="alert">
                            <strong>Nota:</strong> dopo il salvataggio potrebbero essere necessari alcuni secondi perché i dati si aggiornino.
                        </div>

                        <div class="row g-3">

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Dati di accesso</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <label class="form-label">Username</label>
                                                <div class="form-control-plaintext fw-medium"><%#: Eval("username") %></div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="txtEmail">Email</label>
                                                <asp:TextBox ID="txtEmail" runat="server" CssClass="form-control" Text='<%# Bind("email") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Indirizzo di fatturazione</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12">
                                                <label class="form-label" for="txtIndirizzo">Indirizzo</label>
                                                <asp:TextBox ID="txtIndirizzo" runat="server" CssClass="form-control" Text='<%# Bind("Indirizzo") %>' />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="txtCap">CAP</label>
                                                <asp:TextBox ID="txtCap" runat="server" CssClass="form-control" Text='<%# Bind("Cap") %>' />
                                            </div>
                                            <div class="col-12 col-md-5">
                                                <label class="form-label" for="txtCitta">Città</label>
                                                <asp:TextBox ID="txtCitta" runat="server" CssClass="form-control" Text='<%# Bind("Citta") %>' />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="txtProvincia">Provincia</label>
                                                <asp:TextBox ID="txtProvincia" runat="server" CssClass="form-control" Text='<%# Bind("Provincia") %>' />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="txtNazione">Nazione</label>
                                                <asp:TextBox ID="txtNazione" runat="server" CssClass="form-control" Text='<%# Bind("Nazione") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Contatti</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtTelefono">Telefono</label>
                                                <asp:TextBox ID="txtTelefono" runat="server" CssClass="form-control" Text='<%# Bind("Telefono") %>' />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtCellulare">Cellulare</label>
                                                <asp:TextBox ID="txtCellulare" runat="server" CssClass="form-control" Text='<%# Bind("Cellulare") %>' />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtFax">Fax</label>
                                                <asp:TextBox ID="txtFax" runat="server" CssClass="form-control" Text='<%# Bind("Fax") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12" id="addrEdit">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Destinazione alternativa</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="ddlDestinazione">Seleziona destinazione</label>
                                                <asp:DropDownList ID="ddlDestinazione" runat="server" CssClass="form-select" AutoPostBack="true" />
                                            </div>
                                            <div class="col-12"></div>

                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="tbDestRagioneSociale">Ragione sociale</label>
                                                <asp:TextBox ID="tbDestRagioneSociale" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestNome">Nome</label>
                                                <asp:TextBox ID="tbDestNome" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestCognome">Cognome</label>
                                                <asp:TextBox ID="tbDestCognome" runat="server" CssClass="form-control" />
                                            </div>

                                            <div class="col-12">
                                                <label class="form-label" for="tbDestIndirizzo">Indirizzo</label>
                                                <asp:TextBox ID="tbDestIndirizzo" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestCap">CAP</label>
                                                <asp:TextBox ID="tbDestCap" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-5">
                                                <label class="form-label" for="tbDestCitta">Città</label>
                                                <asp:TextBox ID="tbDestCitta" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="tbDestProvincia">Provincia</label>
                                                <asp:TextBox ID="tbDestProvincia" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="tbDestNazione">Nazione</label>
                                                <asp:TextBox ID="tbDestNazione" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="tbDestTelefono">Telefono</label>
                                                <asp:TextBox ID="tbDestTelefono" runat="server" CssClass="form-control" />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="d-flex flex-wrap align-items-center gap-2">
                                    <asp:LinkButton ID="btnUpdate" runat="server" CommandName="Update" CssClass="btn btn-success">
                                        Salva dati
                                    </asp:LinkButton>
                                    <asp:LinkButton ID="btnCancel" runat="server" CommandName="Cancel" CssClass="btn btn-outline-secondary">
                                        Annulla
                                    </asp:LinkButton>
                                </div>
                            </div>

                        </div>

                    </EditItemTemplate>

                </asp:FormView>
                </div>

                <div class="ks-userdata-formview js-ks-userdata-fv" data-fv-id="fvUtente">
                <asp:FormView ID="fvUtente" runat="server" RenderOuterTable="false"
                    DataKeyNames="UtentiId"
                    OnModeChanging="fvUtente_ModeChanging"
                    OnDataBound="fvUtente_DataBound"
                    OnItemUpdating="fvUtente_ItemUpdating">

                    <%-- TEMPLATE LETTURA --%>
                    <ItemTemplate>

                        <div class="ks-userdata-pane ks-userdata-pane-details">
                            <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
                                <h3 class="h6 mb-0 fw-semibold">Dettagli account</h3>
                                <asp:LinkButton ID="btnEdit" runat="server" CommandName="Edit" CssClass="btn btn-primary btn-sm">
                                    Modifica dati
                                </asp:LinkButton>
                            </div>

                            <div class="row g-3">
                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Dati di accesso</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Username</dt>
                                                <dd class="col-7"><%#: Eval("username") %></dd>

                                                <dt class="col-5">Email</dt>
                                                <dd class="col-7"><%#: Eval("email") %></dd>

                                                <dt class="col-5">Password</dt>
                                                <dd class="col-7">********</dd>

                                                <dt class="col-5">Ultimo accesso</dt>
                                                <dd class="col-7"><%#: Eval("ultimoaccesso") %></dd>
                                            </dl>

                                            <div class="mt-3">
                                                <a class="btn btn-outline-secondary btn-sm" href="password.aspx">Cambia password</a>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Profilo commerciale</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Codice cliente</dt>
                                                <dd class="col-7"><%#: Eval("Codice") %></dd>

                                                <dt class="col-5">Listino</dt>
                                                <dd class="col-7"><%#: Eval("listino") %></dd>

                                                <dt class="col-5">Tipo utente</dt>
                                                <dd class="col-7"><%#: Eval("UtenteTipoDescrizione") %></dd>

                                                <dt class="col-5">Modalità IVA</dt>
                                                <dd class="col-7">
                                                    <%#: If(Convert.ToInt32(Eval("IvaTipo")) = 1, "Prezzi IVA esclusa", "Prezzi IVA inclusa") %>
                                                </dd>

                                                <dt class="col-5">Esenzione IVA</dt>
                                                <dd class="col-7"><%#: Eval("DescrizioneEsenzioneIva") %></dd>

                                                <dt class="col-5">Reverse charge</dt>
                                                <dd class="col-7"><%#: If(Convert.ToBoolean(Eval("AbilitatoIvaReverseCharge")), "Si", "No") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Dati intestazione</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Ragione sociale</dt>
                                                <dd class="col-7"><%#: Eval("RagioneSociale") %></dd>

                                                <dt class="col-5">Nome / Cognome</dt>
                                                <dd class="col-7"><%#: Eval("cognomenome") %></dd>

                                                <dt class="col-5">Partita IVA</dt>
                                                <dd class="col-7"><%#: Eval("Piva") %></dd>

                                                <dt class="col-5">Codice fiscale</dt>
                                                <dd class="col-7"><%#: Eval("CodiceFiscale") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12 col-lg-6">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Contatti</span>
                                        </div>
                                        <div class="card-body">
                                            <dl class="row ks-kv mb-0">
                                                <dt class="col-5">Telefono</dt>
                                                <dd class="col-7"><%#: Eval("Telefono") %></dd>

                                                <dt class="col-5">Cellulare</dt>
                                                <dd class="col-7"><%#: Eval("Cellulare") %></dd>

                                                <dt class="col-5">Fax</dt>
                                                <dd class="col-7"><%#: Eval("Fax") %></dd>
                                            </dl>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-12">
                                    <div class="card">
                                        <div class="card-header py-3">
                                            <span class="fw-semibold">Indirizzo di fatturazione</span>
                                        </div>
                                        <div class="card-body">
                                            <div class="row g-3">
                                                <div class="col-12 col-md-6">
                                                    <div class="text-muted small">Indirizzo</div>
                                                    <div class="fw-medium"><%#: Eval("Indirizzo") %></div>
                                                </div>
                                                <div class="col-6 col-md-2">
                                                    <div class="text-muted small">CAP</div>
                                                    <div class="fw-medium"><%#: Eval("Cap") %></div>
                                                </div>
                                                <div class="col-6 col-md-4">
                                                    <div class="text-muted small">Città</div>
                                                    <div class="fw-medium"><%#: Eval("Citta") %></div>
                                                </div>
                                                <div class="col-6 col-md-2">
                                                    <div class="text-muted small">Provincia</div>
                                                    <div class="fw-medium"><%#: Eval("Provincia") %></div>
                                                </div>
                                                <div class="col-6 col-md-4">
                                                    <div class="text-muted small">Nazione</div>
                                                    <div class="fw-medium"><%#: Eval("Nazione") %></div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                            </div>
                        </div>

                        <div class="ks-userdata-pane ks-userdata-pane-addresses" id="addr">
                            <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
                                <h3 class="h6 mb-0 fw-semibold">Indirizzi</h3>
                                <a class="btn btn-outline-primary btn-sm" href="datiutente.aspx">Torna ai dettagli</a>
                            </div>

                            <div class="card">
                                <div class="card-header py-3">
                                    <span class="fw-semibold">Destinazione alternativa (predefinita)</span>
                                </div>
                                <div class="card-body">
                                    <div class="text-muted small mb-3">Se non impostata, verrà usato l’indirizzo di fatturazione.</div>

                                    <dl class="row ks-kv mb-0">
                                        <dt class="col-5">Ragione sociale</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestRagioneSociale" runat="server" /></dd>

                                        <dt class="col-5">Nome</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestNome" runat="server" /></dd>

                                        <dt class="col-5">Cognome</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCognome" runat="server" /></dd>

                                        <dt class="col-5">Indirizzo</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestIndirizzo" runat="server" /></dd>

                                        <dt class="col-5">CAP</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCap" runat="server" /></dd>

                                        <dt class="col-5">Città</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestCitta" runat="server" /></dd>

                                        <dt class="col-5">Provincia</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestProvincia" runat="server" /></dd>

                                        <dt class="col-5">Nazione</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestNazione" runat="server" /></dd>

                                        <dt class="col-5">Telefono</dt>
                                        <dd class="col-7"><asp:Label ID="lblDestTelefono" runat="server" /></dd>
                                    </dl>

                                    <div class="mt-3">
                                        <asp:LinkButton ID="btnEditAddr" runat="server" CommandName="Edit" CssClass="btn btn-primary btn-sm">
                                            Gestisci indirizzi
                                        </asp:LinkButton>
                                    </div>
                                </div>
                            </div>
                        </div>

                    </ItemTemplate>

                    <%-- TEMPLATE MODIFICA --%>
                    <EditItemTemplate>

                        <div class="alert alert-warning py-2 px-3 mb-3" role="alert">
                            <strong>Nota:</strong> dopo il salvataggio potrebbero essere necessari alcuni secondi perché i dati si aggiornino.
                        </div>

                        <div class="row g-3">

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Dati di accesso</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <label class="form-label">Username</label>
                                                <div class="form-control-plaintext fw-medium"><%#: Eval("username") %></div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="txtEmail">Email</label>
                                                <asp:TextBox ID="txtEmail" runat="server" CssClass="form-control" Text='<%# Bind("email") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Indirizzo di fatturazione</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12">
                                                <label class="form-label" for="txtIndirizzo">Indirizzo</label>
                                                <asp:TextBox ID="txtIndirizzo" runat="server" CssClass="form-control" Text='<%# Bind("Indirizzo") %>' />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="txtCap">CAP</label>
                                                <asp:TextBox ID="txtCap" runat="server" CssClass="form-control" Text='<%# Bind("Cap") %>' />
                                            </div>
                                            <div class="col-12 col-md-5">
                                                <label class="form-label" for="txtCitta">Città</label>
                                                <asp:TextBox ID="txtCitta" runat="server" CssClass="form-control" Text='<%# Bind("Citta") %>' />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="txtProvincia">Provincia</label>
                                                <asp:TextBox ID="txtProvincia" runat="server" CssClass="form-control" Text='<%# Bind("Provincia") %>' />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="txtNazione">Nazione</label>
                                                <asp:TextBox ID="txtNazione" runat="server" CssClass="form-control" Text='<%# Bind("Nazione") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Contatti</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtTelefono">Telefono</label>
                                                <asp:TextBox ID="txtTelefono" runat="server" CssClass="form-control" Text='<%# Bind("Telefono") %>' />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtCellulare">Cellulare</label>
                                                <asp:TextBox ID="txtCellulare" runat="server" CssClass="form-control" Text='<%# Bind("Cellulare") %>' />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="txtFax">Fax</label>
                                                <asp:TextBox ID="txtFax" runat="server" CssClass="form-control" Text='<%# Bind("Fax") %>' />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12" id="addrEdit">
                                <div class="card">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Destinazione alternativa</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="ddlDestinazione">Seleziona destinazione</label>
                                                <asp:DropDownList ID="ddlDestinazione" runat="server" CssClass="form-select" AutoPostBack="true" OnSelectedIndexChanged="ddlDestAlt_SelectedIndexChanged" />
                                            </div>
                                            <div class="col-12"></div>

                                            <div class="col-12 col-md-6">
                                                <label class="form-label" for="tbDestRagioneSociale">Ragione sociale</label>
                                                <asp:TextBox ID="tbDestRagioneSociale" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestNome">Nome</label>
                                                <asp:TextBox ID="tbDestNome" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestCognome">Cognome</label>
                                                <asp:TextBox ID="tbDestCognome" runat="server" CssClass="form-control" />
                                            </div>

                                            <div class="col-12">
                                                <label class="form-label" for="tbDestIndirizzo">Indirizzo</label>
                                                <asp:TextBox ID="tbDestIndirizzo" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-3">
                                                <label class="form-label" for="tbDestCap">CAP</label>
                                                <asp:TextBox ID="tbDestCap" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-5">
                                                <label class="form-label" for="tbDestCitta">Città</label>
                                                <asp:TextBox ID="tbDestCitta" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="tbDestProvincia">Provincia</label>
                                                <asp:TextBox ID="tbDestProvincia" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <label class="form-label" for="tbDestNazione">Nazione</label>
                                                <asp:TextBox ID="tbDestNazione" runat="server" CssClass="form-control" />
                                            </div>
                                            <div class="col-12 col-md-4">
                                                <label class="form-label" for="tbDestTelefono">Telefono</label>
                                                <asp:TextBox ID="tbDestTelefono" runat="server" CssClass="form-control" />
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12">
                                <div class="d-flex flex-wrap align-items-center gap-2">
                                    <asp:LinkButton ID="btnUpdate" runat="server" CommandName="Update" CssClass="btn btn-success">
                                        Salva dati
                                    </asp:LinkButton>
                                    <asp:LinkButton ID="btnCancel" runat="server" CommandName="Cancel" CssClass="btn btn-outline-secondary">
                                        Annulla
                                    </asp:LinkButton>
                                </div>
                            </div>

                        </div>

                    </EditItemTemplate>

                </asp:FormView>
                </div>

            </ContentTemplate>
        </asp:UpdatePanel>

                    </div>
                </div>
            </div>
        </section>

    </div>

</asp:Content>

<asp:Content ID="ContentScripts" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="<%= ThemeManager.Asset("js/datiutente-ui.js") %>" defer></script>
</asp:Content>
