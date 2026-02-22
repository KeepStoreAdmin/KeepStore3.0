<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="my-account-address.aspx.vb" Inherits="my_account_address" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Indirizzi
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="ks-myaccount">

        <!-- Breadcrumb (tema) -->
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
                                <li><span class="myaccount-nav-item active">Indirizzi</span></li>
                                <li><a href="my-account-edit.aspx" class="myaccount-nav-item">Dettagli account</a></li>
                                <li><a href="wishlist.aspx" class="myaccount-nav-item">Wishlist</a></li>
                                <li><a href="logout.aspx" class="myaccount-nav-item">Logout</a></li>
                            </ul>
                        </div>
                    </div>

                    <!-- Content -->
                    <div class="col-lg-9">
                        <div class="myaccount-content account-address">
                            <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-3">
                                <div>
                                    <h4 class="fw-semibold mb-0">I tuoi indirizzi</h4>
                                    <div class="body-small text-main-2">Gestisci i dati di fatturazione (ed eventuali destinazioni alternative dal pannello dati).</div>
                                </div>
                                <a href="datiutente.aspx?edit=1" class="tf-btn btn-fill">Modifica</a>
                            </div>

                            <asp:SqlDataSource ID="sdsUtente" runat="server"
                                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                SelectCommand="SELECT u.RagioneSociale, u.Indirizzo, u.Cap, u.Citta, u.Provincia, u.Nazione, u.Telefono, u.Cellulare, u.email FROM utenti u INNER JOIN vlogin v ON v.utentiid=u.id WHERE v.id=?LoginId">
                                <SelectParameters>
                                    <asp:SessionParameter Name="LoginId" SessionField="LoginId" Type="Int32" />
                                </SelectParameters>
                            </asp:SqlDataSource>

                            <asp:FormView ID="fvAddr" runat="server" DataSourceID="sdsUtente" DefaultMode="ReadOnly">
                                <ItemTemplate>
                                    <ul class="list-account-address tf-grid-layout md-col-2">
                                        <li class="account-address-item">
                                            <p class="title title-sidebar fw-semibold">Indirizzo di fatturazione</p>
                                            <div class="info-detail">
                                                <div class="box-infor">
                                                    <p class="title-sidebar"><%# Eval("RagioneSociale") %></p>
                                                    <p class="title-sidebar"><%# Eval("email") %></p>
                                                    <p class="title-sidebar"><%# Eval("Indirizzo") %></p>
                                                    <p class="title-sidebar"><%# Eval("Citta") %> (<%# Eval("Provincia") %>)</p>
                                                    <p class="title-sidebar"><%# Eval("Cap") %></p>
                                                    <p class="title-sidebar"><%# Eval("Nazione") %></p>
                                                    <p class="title-sidebar">
                                                        <%# IIf(String.IsNullOrEmpty(Convert.ToString(Eval("Cellulare"))), Eval("Telefono"), Eval("Cellulare")) %>
                                                    </p>
                                                </div>
                                                <div class="box-btn">
                                                    <a class="tf-btn btn-large" href="datiutente.aspx?edit=1"><span class="text-white">Modifica</span></a>
                                                </div>
                                            </div>
                                        </li>

                                        <li class="account-address-item ks-muted">
                                            <p class="title title-sidebar fw-semibold">Altre destinazioni</p>
                                            <div class="info-detail">
                                                <div class="box-infor">
                                                    <p class="title-sidebar">Puoi gestire eventuali destinazioni alternative (spedizione) dalla pagina <a class=\"link\" href=\"datiutente.aspx\">I miei dati</a>.</p>
                                                </div>
                                                <div class="box-btn">
                                                    <a class="tf-btn btn-large" href="datiutente.aspx"><span class="text-white">Apri</span></a>
                                                </div>
                                            </div>
                                        </li>
                                    </ul>
                                </ItemTemplate>
                            </asp:FormView>

                        </div>
                    </div>

                </div>
            </div>
        </section>

    </div>

</asp:Content>
