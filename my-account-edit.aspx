<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="my-account-edit.aspx.vb" Inherits="my_account_edit" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Dettagli account
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="ks-myaccount">

        <!-- Breadcrumb Onsus -->
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

        <!-- My Account -->
        <section class="tf-sp-2">
            <div class="container">
                <div class="row">

                    <!-- Sidebar -->
                    <div class="col-lg-3">
                        <div class="wrap-sidebar-account">
                            <ul class="myaccount-nav content-append">
                                <li><a href="myaccount.aspx" class="myaccount-nav-item">Dashboard</a></li>
                                <li><a href="documenti.aspx?t=4" class="myaccount-nav-item">I miei ordini</a></li>
                                <li><a href="my-account-address.aspx" class="myaccount-nav-item">Indirizzi</a></li>
                                <li><span class="myaccount-nav-item active">Dettagli account</span></li>
                                <li><a href="wishlist.aspx" class="myaccount-nav-item">Wishlist</a></li>
                                <li><a href="logout.aspx" class="myaccount-nav-item">Logout</a></li>
                            </ul>
                        </div>
                    </div>

                    <!-- Content -->
                    <div class="col-lg-9">
                        <div class="myaccount-content account-edit">
                            <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
                                <div>
                                    <h4 class="fw-semibold mb-0">Dettagli account</h4>
                                    <div class="body-small text-main-2">Aggiorna i tuoi dati anagrafici, fiscali e i contatti.</div>
                                </div>
                                <a href="datiutente.aspx?edit=1" class="tf-btn btn-fill">Modifica</a>
                            </div>

                            <asp:SqlDataSource ID="sdsUtente" runat="server"
                                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                SelectCommand="SELECT v.Username, v.email, v.cognomenome, v.ultimoaccesso, u.Codice, u.RagioneSociale, u.Piva, u.CodiceFiscale, u.Telefono, u.Cellulare FROM vlogin v INNER JOIN utenti u ON v.utentiid=u.id WHERE v.id=?LoginId">
                                <SelectParameters>
                                    <asp:SessionParameter Name="LoginId" SessionField="LoginId" Type="Int32" />
                                </SelectParameters>
                            </asp:SqlDataSource>

                            <asp:FormView ID="fvAcc" runat="server" DataSourceID="sdsUtente" DefaultMode="ReadOnly">
                                <ItemTemplate>
                                    <div class="ks-card tf-bg-1">
                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <div class="account-section-title">Accesso / Account</div>
                                                <div class="account-field-value"><span class="account-field-label">Username:</span> <%# Eval("Username") %></div>
                                                <div class="account-field-value"><span class="account-field-label">Email:</span> <%# Eval("email") %></div>
                                                <div class="account-field-value"><span class="account-field-label">Ultimo accesso:</span> <%# Eval("ultimoaccesso", "{0:dd/MM/yyyy HH:mm}") %></div>
                                                <div class="account-field-value"><span class="account-field-label">Codice cliente:</span> <%# Eval("Codice") %></div>
                                            </div>
                                            <div class="col-12 col-md-6">
                                                <div class="account-section-title">Anagrafica / Fiscale</div>
                                                <div class="account-field-value"><span class="account-field-label">Ragione sociale:</span> <%# Eval("RagioneSociale") %></div>
                                                <div class="account-field-value"><span class="account-field-label">Cognome / Nome:</span> <%# Eval("cognomenome") %></div>
                                                <div class="account-field-value"><span class="account-field-label">Partita IVA:</span> <%# Eval("Piva") %></div>
                                                <div class="account-field-value"><span class="account-field-label">Codice fiscale:</span> <%# Eval("CodiceFiscale") %></div>
                                            </div>
                                        </div>

                                        <hr class="my-4" />

                                        <div class="row g-3">
                                            <div class="col-12 col-md-6">
                                                <div class="account-section-title">Contatti</div>
                                                <div class="account-field-value"><span class="account-field-label">Telefono:</span> <%# Eval("Telefono") %></div>
                                                <div class="account-field-value"><span class="account-field-label">Cellulare:</span> <%# Eval("Cellulare") %></div>
                                            </div>
                                            <div class="col-12 col-md-6 d-flex align-items-end justify-content-md-end">
                                                <div class="d-flex gap-2 flex-wrap">
                                                    <a class="tf-btn btn-line" href="my-account-address.aspx">Indirizzi</a>
                                                    <a class="tf-btn btn-fill" href="datiutente.aspx?edit=1">Modifica dati</a>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </ItemTemplate>
                            </asp:FormView>

                            <div class="mt-4">
                                <a href="password.aspx" class="tf-btn btn-line">Cambia password</a>
                            </div>

                        </div>
                    </div>

                </div>
            </div>
        </section>

    </div>

</asp:Content>
