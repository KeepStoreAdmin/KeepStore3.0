<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="my-account-edit.aspx.vb" Inherits="my_account_edit" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Dettagli account
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="ks-myaccount">

        <div class="tf-sp-1 pb-0">
            <div class="container">
                <div class="tf-breadcrumb-wrap">
                    <div class="tf-breadcrumb-list">
                        <a href="Default.aspx" class="text">Home</a>
                        <i class="icon icon-arrow-right"></i>
                        <a href="myaccount.aspx" class="text">Account</a>
                        <i class="icon icon-arrow-right"></i>
                        <span class="text">Dettagli account</span>
                    </div>
                </div>
            </div>
        </div>

        <section class="tf-sp-2">
            <div class="container">
                <div class="row">
                    <div class="col-12">
                        <div class="myaccount-content account-edit">
                            <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
                                <div>
                                    <h4 class="fw-semibold mb-0">Dettagli account</h4>
                                    <div class="body-small text-main-2">Aggiorna profilo, contatti e indirizzo di fatturazione.</div>
                                </div>
                                <a href="myaccount.aspx" class="tf-btn btn-line">Annulla</a>
                            </div>

                            <asp:Panel ID="pnlMessage" runat="server" Visible="false" CssClass="alert mb-4" role="status">
                                <asp:Literal ID="litMessage" runat="server" />
                            </asp:Panel>

                            <asp:Panel ID="pnlProfile" runat="server">
                                <asp:HiddenField ID="hidUtentiId" runat="server" />

                                <div class="ks-card tf-bg-1 mb-4">
                                    <div class="account-section-title">Dati accesso / profilo</div>
                                    <div class="row g-3">
                                        <div class="col-12 col-md-6">
                                            <label class="body-small text-main-2" for="<%= txtUsername.ClientID %>">Username</label>
                                            <asp:TextBox ID="txtUsername" runat="server" CssClass="form-control" ReadOnly="true" />
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <label class="body-small text-main-2" for="<%= txtEmail.ClientID %>">Email</label>
                                            <asp:TextBox ID="txtEmail" runat="server" CssClass="form-control" TextMode="Email" MaxLength="50" />
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <label class="body-small text-main-2" for="<%= txtCodice.ClientID %>">Codice cliente</label>
                                            <asp:TextBox ID="txtCodice" runat="server" CssClass="form-control" ReadOnly="true" />
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <label class="body-small text-main-2" for="<%= txtUltimoAccesso.ClientID %>">Ultimo accesso</label>
                                            <asp:TextBox ID="txtUltimoAccesso" runat="server" CssClass="form-control" ReadOnly="true" />
                                        </div>
                                    </div>
                                </div>

                                <div class="ks-card tf-bg-1 mb-4">
                                    <div class="account-section-title">Dati fiscali / intestazione</div>
                                    <div class="row g-3">
                                        <div class="col-12 col-md-6">
                                            <label class="body-small text-main-2" for="<%= txtRagioneSociale.ClientID %>">Ragione Sociale / Cognome</label>
                                            <asp:TextBox ID="txtRagioneSociale" runat="server" CssClass="form-control" ReadOnly="true" />
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <label class="body-small text-main-2" for="<%= txtCognomeNome.ClientID %>">Nome</label>
                                            <asp:TextBox ID="txtCognomeNome" runat="server" CssClass="form-control" ReadOnly="true" />
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <label class="body-small text-main-2" for="<%= txtPiva.ClientID %>">Partita IVA</label>
                                            <asp:TextBox ID="txtPiva" runat="server" CssClass="form-control" ReadOnly="true" />
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <label class="body-small text-main-2" for="<%= txtCodiceFiscale.ClientID %>">Codice fiscale</label>
                                            <asp:TextBox ID="txtCodiceFiscale" runat="server" CssClass="form-control" ReadOnly="true" />
                                        </div>
                                    </div>
                                </div>

                                <div class="ks-card tf-bg-1 mb-4">
                                    <div class="account-section-title">Contatti</div>
                                    <div class="row g-3">
                                        <div class="col-12 col-md-4">
                                            <label class="body-small text-main-2" for="<%= txtTelefono.ClientID %>">Telefono</label>
                                            <asp:TextBox ID="txtTelefono" runat="server" CssClass="form-control" MaxLength="50" />
                                        </div>
                                        <div class="col-12 col-md-4">
                                            <label class="body-small text-main-2" for="<%= txtCellulare.ClientID %>">Cellulare</label>
                                            <asp:TextBox ID="txtCellulare" runat="server" CssClass="form-control" MaxLength="50" />
                                        </div>
                                        <div class="col-12 col-md-4">
                                            <label class="body-small text-main-2" for="<%= txtFax.ClientID %>">Fax</label>
                                            <asp:TextBox ID="txtFax" runat="server" CssClass="form-control" MaxLength="50" />
                                        </div>
                                    </div>
                                </div>

                                <div class="ks-card tf-bg-1 mb-4">
                                    <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
                                        <div class="account-section-title mb-0">Indirizzo di fatturazione</div>
                                        <a href="my-account-address.aspx" class="tf-btn btn-line">Indirizzi</a>
                                    </div>
                                    <div class="row g-3">
                                        <div class="col-12">
                                            <label class="body-small text-main-2" for="<%= txtIndirizzo.ClientID %>">Indirizzo</label>
                                            <asp:TextBox ID="txtIndirizzo" runat="server" CssClass="form-control" MaxLength="255" />
                                        </div>
                                        <div class="col-12 col-md-3">
                                            <label class="body-small text-main-2" for="<%= txtCap.ClientID %>">CAP</label>
                                            <asp:TextBox ID="txtCap" runat="server" CssClass="form-control" MaxLength="12" />
                                        </div>
                                        <div class="col-12 col-md-5">
                                            <label class="body-small text-main-2" for="<%= txtCitta.ClientID %>">Citta</label>
                                            <asp:TextBox ID="txtCitta" runat="server" CssClass="form-control" MaxLength="120" />
                                        </div>
                                        <div class="col-6 col-md-2">
                                            <label class="body-small text-main-2" for="<%= txtProvincia.ClientID %>">Provincia</label>
                                            <asp:TextBox ID="txtProvincia" runat="server" CssClass="form-control" MaxLength="8" />
                                        </div>
                                        <div class="col-6 col-md-2">
                                            <label class="body-small text-main-2" for="<%= txtNazione.ClientID %>">Nazione</label>
                                            <asp:TextBox ID="txtNazione" runat="server" CssClass="form-control" MaxLength="8" />
                                        </div>
                                    </div>
                                </div>

                                <div class="d-flex flex-wrap align-items-center gap-2">
                                    <asp:LinkButton ID="btnSave" runat="server" CssClass="tf-btn btn-fill" OnClick="btnSave_Click">
                                        Salva dati
                                    </asp:LinkButton>
                                    <a href="myaccount.aspx" class="tf-btn btn-line">Annulla</a>
                                    <a href="password.aspx" class="tf-btn btn-line">Cambia password</a>
                                </div>
                            </asp:Panel>
                        </div>
                    </div>

                </div>
            </div>
        </section>

    </div>

</asp:Content>
