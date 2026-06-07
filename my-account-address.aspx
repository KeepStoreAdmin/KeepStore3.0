<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="my-account-address.aspx.vb" Inherits="my_account_address" %>
<%@ Register Src="~/Public/ui/controls/AccountSidebar.ascx" TagPrefix="ks" TagName="AccountSidebar" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Indirizzi
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style>
        body.ks-page-account .ks-address-page .ks-address-sidebar,
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
                <div class="row g-4">
                    <div class="col-12 col-lg-3 ks-address-sidebar">
                        <ks:AccountSidebar ID="AccountSidebar" runat="server" />
                    </div>

                    <div class="col-12 col-lg-9 ks-address-content">
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
                                                <div class="text-muted small">Ragione sociale</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainRagioneSociale" runat="server" /></div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="text-muted small">Cognome/Nome</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainCognomeNome" runat="server" /></div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="text-muted small">Email</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainEmail" runat="server" /></div>
                                            </div>
                                            <div class="col-12">
                                                <div class="text-muted small">Indirizzo</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainAddress" runat="server" /></div>
                                            </div>
                                            <div class="col-6 col-md-3">
                                                <div class="text-muted small">CAP</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainCap" runat="server" /></div>
                                            </div>
                                            <div class="col-6 col-md-4">
                                                <div class="text-muted small">Citta</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainCity" runat="server" /></div>
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <div class="text-muted small">Provincia</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainProvince" runat="server" /></div>
                                            </div>
                                            <div class="col-6 col-md-3">
                                                <div class="text-muted small">Nazione</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainCountry" runat="server" /></div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="text-muted small">Telefono</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainPhone" runat="server" /></div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="text-muted small">Cellulare</div>
                                                <div class="fw-medium ks-address-value"><asp:Literal ID="litMainMobile" runat="server" /></div>
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
                                    <a href="datiutente.aspx?edit=1&amp;tab=addr" class="tf-btn btn-line">Aggiungi o modifica</a>
                                </div>
                                <div class="card-body">
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
                                            <div class="col-12 col-xl-6">
                                                <div class="card h-100 border">
                                                    <div class="card-body d-flex flex-column gap-3">
                                                        <div class="d-flex justify-content-between align-items-start gap-2">
                                                            <div class="ks-address-title">
                                                                <div class="fw-semibold ks-address-value"><%# SafeField(Container.DataItem, "RagioneSocialeA", "Ragione sociale non indicata") %></div>
                                                                <div class="body-small text-main-2 ks-address-value"><%# SafeField(Container.DataItem, "NomeA", "Nome non indicato") %></div>
                                                                <div class="body-small text-main-2 ks-address-value"><%# SafeField(Container.DataItem, "IndirizzoA", "Indirizzo non indicato") %></div>
                                                            </div>
                                                            <asp:PlaceHolder ID="phDefaultBadge" runat="server" Visible='<%# IsDefaultAddress(Container.DataItem) %>'>
                                                                <span class="badge bg-success">Predefinito</span>
                                                            </asp:PlaceHolder>
                                                        </div>

                                                        <div class="row g-2 body-small">
                                                            <div class="col-6">
                                                                <div class="text-muted">CAP</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "CapA", "-") %></div>
                                                            </div>
                                                            <div class="col-6">
                                                                <div class="text-muted">Citta</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "CittaA", "-") %></div>
                                                            </div>
                                                            <div class="col-6">
                                                                <div class="text-muted">Provincia</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "ProvinciaA", "-") %></div>
                                                            </div>
                                                            <div class="col-6">
                                                                <div class="text-muted">Nazione</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "NazioneA", "-") %></div>
                                                            </div>
                                                            <div class="col-6">
                                                                <div class="text-muted">Telefono</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "TelefonoA", "-") %></div>
                                                            </div>
                                                            <div class="col-6">
                                                                <div class="text-muted">Cellulare</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "CellulareA", "-") %></div>
                                                            </div>
                                                            <div class="col-12">
                                                                <div class="text-muted">Note</div>
                                                                <div class="fw-medium ks-address-value"><%# SafeField(Container.DataItem, "Note", "-") %></div>
                                                            </div>
                                                        </div>

                                                        <div class="mt-auto">
                                                            <asp:LinkButton ID="btnSetDefault" runat="server"
                                                                CssClass="tf-btn btn-line w-100 justify-content-center"
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
            </div>
        </section>
    </div>

</asp:Content>
