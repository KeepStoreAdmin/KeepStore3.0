<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="my-account-address.aspx.vb" Inherits="my_account_address" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Indirizzi
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style>
        body.ks-page-account .ks-address-page .container {
            max-width: 100%;
            padding-left: 0;
            padding-right: 0;
        }

        body.ks-page-account .ks-address-page .ks-address-content,
        body.ks-page-account .ks-address-page .ks-address-card,
        body.ks-page-account .ks-address-page .ks-address-card [class*="col-"] {
            min-width: 0;
        }

        body.ks-page-account .ks-address-page .ks-address-value {
            white-space: normal;
            overflow-wrap: anywhere;
            word-break: break-word;
        }

        body.ks-page-account .ks-address-page .ks-address-heading {
            max-width: 100%;
        }

        body.ks-page-account .ks-address-page .ks-address-card .badge {
            white-space: normal;
        }

        body.ks-page-account .ks-address-page .ks-address-title {
            min-width: 0;
        }

        body.ks-page-account .ks-address-page .ks-address-field {
            padding: .75rem;
            border: 1px solid rgba(0,0,0,.08);
            border-radius: .5rem;
            background: rgba(0,0,0,.015);
            height: 100%;
        }

        body.ks-page-account .ks-address-page .ks-address-field-label {
            color: #6c757d;
            font-size: .8125rem;
            margin-bottom: .25rem;
        }

        body.ks-page-account .ks-address-page .ks-address-form {
            border: 1px solid rgba(0,0,0,.12);
            border-radius: .5rem;
            padding: 1rem;
            background: #fff;
        }

        body.ks-page-account .ks-address-page textarea.form-control {
            min-height: 96px;
        }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="ks-address-page">

        <div class="tf-sp-1 pb-0">
            <div class="container">
                <div class="tf-breadcrumb-wrap">
                    <div class="tf-breadcrumb-list">
                        <a href="Default.aspx" class="text">Home</a>
                        <i class="icon icon-arrow-right"></i>
                        <a href="myaccount.aspx" class="text">Account</a>
                        <i class="icon icon-arrow-right"></i>
                        <span class="text">Indirizzi</span>
                    </div>
                </div>
            </div>
        </div>

        <section class="tf-sp-2">
            <div class="container">
                <div class="ks-address-content">
                        <div class="myaccount-content account-address">
                            <div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
                                <div class="ks-address-heading">
                                    <p class="text-uppercase text-main-2 fw-semibold mb-2">Area cliente</p>
                                    <h1 class="h4 fw-semibold mb-2">I tuoi indirizzi</h1>
                                    <div class="body-small text-main-2">
                                        Consulta l'indirizzo principale e scegli la sede alternativa predefinita per le spedizioni.
                                    </div>
                                </div>
                            </div>

                            <asp:Label ID="lblPageMessage" runat="server" EnableViewState="false" />

                            <div class="card mb-4 ks-address-card">
                                <div class="card-header py-3 d-flex justify-content-between align-items-center gap-2 flex-wrap">
                                    <div>
                                        <span class="fw-semibold">Indirizzo principale</span>
                                        <div class="text-muted small">Anagrafica cliente usata come fallback se nessuna sede alternativa e predefinita.</div>
                                    </div>
                                    <asp:Label ID="lblMainDefaultBadge" runat="server" CssClass="badge bg-light text-dark border" Text="Fallback predefinito" />
                                </div>
                                <div class="card-body">
                                    <asp:Panel ID="pnlMainAddress" runat="server">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Ragione Sociale/Cognome</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainRagioneSociale" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Nome</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainCognomeNome" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Email</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainEmail" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-12">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Indirizzo completo</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainAddress" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-6 col-md-3">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">CAP</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainCap" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-6 col-md-4">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Citta</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainCity" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Provincia</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainProvince" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-6 col-md-3">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Nazione</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainCountry" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Telefono</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainPhone" runat="server" /></div>
                                                </div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="ks-address-field">
                                                    <div class="ks-address-field-label">Cellulare</div>
                                                    <div class="fw-medium ks-address-value"><asp:Literal ID="litMainMobile" runat="server" /></div>
                                                </div>
                                            </div>
                                        </div>
                                    </asp:Panel>

                                    <asp:Panel ID="pnlNoMainAddress" runat="server" Visible="false">
                                        <div class="alert alert-warning mb-0" role="alert">
                                            Non risultano dati indirizzo associati al profilo corrente.
                                        </div>
                                    </asp:Panel>
                                </div>
                            </div>

                            <div class="card ks-address-card">
                                <div class="card-header py-3 d-flex justify-content-between align-items-center gap-2 flex-wrap">
                                    <div>
                                        <span class="fw-semibold">Sedi alternative</span>
                                        <div class="text-muted small">Puoi scegliere una sola sede alternativa predefinita.</div>
                                    </div>
                                    <asp:LinkButton ID="btnShowAddAddress" runat="server" CssClass="tf-btn btn-line" CausesValidation="false" OnClick="btnShowAddAddress_Click">
                                        Aggiungi indirizzo
                                    </asp:LinkButton>
                                </div>
                                <div class="card-body">
                                    <asp:Panel ID="pnlAddressForm" runat="server" Visible="false" CssClass="ks-address-form mb-4">
                                        <asp:HiddenField ID="hfAddressId" runat="server" Value="0" />
                                        <h2 class="h5 fw-semibold mb-3"><asp:Literal ID="litAddressFormTitle" runat="server" /></h2>
                                        <asp:ValidationSummary ID="vsAddressForm" runat="server" ValidationGroup="AddressEdit" CssClass="alert alert-danger" HeaderText="Controlla i campi indirizzo:" />
                                        <div class="row g-3">
                                            <div class="col-12 col-lg-6">
                                                <label class="form-label" for="<%= tbRagioneSocialeA.ClientID %>">Ragione Sociale/Cognome</label>
                                                <asp:TextBox ID="tbRagioneSocialeA" runat="server" CssClass="form-control" MaxLength="100" />
                                            </div>
                                            <div class="col-12 col-lg-6">
                                                <label class="form-label" for="<%= tbNomeA.ClientID %>">Nome</label>
                                                <asp:TextBox ID="tbNomeA" runat="server" CssClass="form-control" MaxLength="50" />
                                            </div>
                                            <div class="col-12">
                                                <label class="form-label" for="<%= tbIndirizzoA.ClientID %>">Indirizzo *</label>
                                                <asp:TextBox ID="tbIndirizzoA" runat="server" CssClass="form-control" MaxLength="100" />
                                                <asp:RequiredFieldValidator ID="rfvIndirizzoA" runat="server" ControlToValidate="tbIndirizzoA" ValidationGroup="AddressEdit" Display="None" ErrorMessage="Inserire l'indirizzo." />
                                            </div>
                                            <div class="col-6 col-lg-3">
                                                <label class="form-label" for="<%= tbCapA.ClientID %>">CAP</label>
                                                <asp:TextBox ID="tbCapA" runat="server" CssClass="form-control" MaxLength="10" />
                                            </div>
                                            <div class="col-12 col-lg-5">
                                                <label class="form-label" for="<%= tbCittaA.ClientID %>">Citta *</label>
                                                <asp:TextBox ID="tbCittaA" runat="server" CssClass="form-control" MaxLength="80" />
                                                <asp:RequiredFieldValidator ID="rfvCittaA" runat="server" ControlToValidate="tbCittaA" ValidationGroup="AddressEdit" Display="None" ErrorMessage="Inserire la citta." />
                                            </div>
                                            <div class="col-6 col-lg-2">
                                                <label class="form-label" for="<%= tbProvinciaA.ClientID %>">Provincia</label>
                                                <asp:TextBox ID="tbProvinciaA" runat="server" CssClass="form-control" MaxLength="10" />
                                            </div>
                                            <div class="col-12 col-lg-2">
                                                <label class="form-label" for="<%= tbNazioneA.ClientID %>">Nazione</label>
                                                <asp:TextBox ID="tbNazioneA" runat="server" CssClass="form-control" MaxLength="50" />
                                            </div>
                                            <div class="col-12 col-lg-4">
                                                <label class="form-label" for="<%= tbZona.ClientID %>">Zona</label>
                                                <asp:TextBox ID="tbZona" runat="server" CssClass="form-control" MaxLength="100" />
                                            </div>
                                            <div class="col-12 col-lg-4">
                                                <label class="form-label" for="<%= tbTelefonoA.ClientID %>">Telefono</label>
                                                <asp:TextBox ID="tbTelefonoA" runat="server" CssClass="form-control" MaxLength="30" />
                                            </div>
                                            <div class="col-12 col-lg-4">
                                                <label class="form-label" for="<%= tbCellulareA.ClientID %>">Cellulare</label>
                                                <asp:TextBox ID="tbCellulareA" runat="server" CssClass="form-control" MaxLength="30" />
                                            </div>
                                            <div class="col-12 col-lg-4">
                                                <label class="form-label" for="<%= tbFaxA.ClientID %>">Fax</label>
                                                <asp:TextBox ID="tbFaxA" runat="server" CssClass="form-control" MaxLength="30" />
                                            </div>
                                            <div class="col-12 col-lg-8">
                                                <label class="form-label" for="<%= tbNote.ClientID %>">Note</label>
                                                <asp:TextBox ID="tbNote" runat="server" CssClass="form-control" MaxLength="255" TextMode="MultiLine" Rows="3" />
                                            </div>
                                            <div class="col-12">
                                                <div class="form-check">
                                                    <asp:CheckBox ID="chkSetDefault" runat="server" CssClass="form-check-input" />
                                                    <label class="form-check-label" for="<%= chkSetDefault.ClientID %>">Imposta come predefinito</label>
                                                </div>
                                            </div>
                                            <div class="col-12 d-flex flex-wrap gap-2">
                                                <asp:Button ID="btnSaveAddress" runat="server" CssClass="tf-btn" Text="Salva indirizzo" ValidationGroup="AddressEdit" OnClick="btnSaveAddress_Click" />
                                                <asp:Button ID="btnCancelAddress" runat="server" CssClass="tf-btn btn-line" Text="Annulla" CausesValidation="false" OnClick="btnCancelAddress_Click" />
                                            </div>
                                        </div>
                                    </asp:Panel>

                                    <asp:Panel ID="pnlNoAlternativeAddresses" runat="server" Visible="false">
                                        <div class="alert alert-info mb-0" role="status">
                                            Non hai ancora indirizzi alternativi salvati. Verra usato l'indirizzo principale.
                                        </div>
                                    </asp:Panel>

                                    <asp:Repeater ID="rptAlternativeAddresses" runat="server" OnItemCommand="rptAlternativeAddresses_ItemCommand">
                                        <HeaderTemplate>
                                            <div class="row g-3">
                                        </HeaderTemplate>
                                        <ItemTemplate>
                                            <div class="col-12">
                                                <div class="card h-100 border">
                                                    <div class="card-body d-flex flex-column gap-3">
                                                        <div class="d-flex justify-content-between align-items-start gap-2 flex-wrap">
                                                            <div class="ks-address-title">
                                                                <div class="ks-address-field-label">Ragione Sociale/Cognome</div>
                                                                <div class="fw-semibold ks-address-value"><%# SafeField(Container.DataItem, "RagioneSocialeA", "-") %></div>
                                                                <div class="ks-address-field-label mt-2">Nome</div>
                                                                <div class="body-small text-main-2 ks-address-value"><%# SafeField(Container.DataItem, "NomeA", "-") %></div>
                                                            </div>
                                                            <asp:PlaceHolder ID="phDefaultBadge" runat="server" Visible='<%# IsDefaultAddress(Container.DataItem) %>'>
                                                                <span class="badge bg-success">Predefinito</span>
                                                            </asp:PlaceHolder>
                                                        </div>

                                                        <div class="row g-2 body-small">
                                                            <div class="col-12">
                                                                <div class="text-muted">Indirizzo completo</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "IndirizzoA", "-") %></div>
                                                            </div>
                                                            <div class="col-6 col-lg-2">
                                                                <div class="text-muted">CAP</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "CapA", "-") %></div>
                                                            </div>
                                                            <div class="col-6 col-lg-3">
                                                                <div class="text-muted">Citta</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "CittaA", "-") %></div>
                                                            </div>
                                                            <div class="col-6 col-lg-2">
                                                                <div class="text-muted">Provincia</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "ProvinciaA", "-") %></div>
                                                            </div>
                                                            <div class="col-6 col-lg-2">
                                                                <div class="text-muted">Zona</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "Zona", "-") %></div>
                                                            </div>
                                                            <div class="col-6 col-lg-3">
                                                                <div class="text-muted">Nazione</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "NazioneA", "-") %></div>
                                                            </div>
                                                            <div class="col-6 col-lg-4">
                                                                <div class="text-muted">Telefono</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "TelefonoA", "-") %></div>
                                                            </div>
                                                            <div class="col-6 col-lg-4">
                                                                <div class="text-muted">Cellulare</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "CellulareA", "-") %></div>
                                                            </div>
                                                            <div class="col-6 col-lg-4">
                                                                <div class="text-muted">Fax</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "FaxA", "-") %></div>
                                                            </div>
                                                            <div class="col-12">
                                                                <div class="text-muted">Note</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "Note", "-") %></div>
                                                            </div>
                                                        </div>

                                                        <div class="mt-auto d-flex flex-wrap gap-2">
                                                            <asp:LinkButton ID="btnEditAddress" runat="server"
                                                                CssClass="tf-btn btn-line"
                                                                CommandName="EditAddress"
                                                                CommandArgument='<%# Eval("Id") %>'
                                                                CausesValidation="false">
                                                                Modifica
                                                            </asp:LinkButton>
                                                            <asp:LinkButton ID="btnSetDefault" runat="server"
                                                                CssClass="tf-btn btn-line"
                                                                CommandName="SetDefault"
                                                                CommandArgument='<%# Eval("Id") %>'
                                                                Visible='<%# Not IsDefaultAddress(Container.DataItem) %>'
                                                                CausesValidation="false">
                                                                Imposta come predefinito
                                                            </asp:LinkButton>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </ItemTemplate>
                                        <FooterTemplate>
                                            </div>
                                        </FooterTemplate>
                                    </asp:Repeater>
                                </div>
                            </div>
                        </div>
                </div>
            </div>
        </section>
    </div>

</asp:Content>
