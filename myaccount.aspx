<%@ Page Title="" Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="myaccount.aspx.vb" Inherits="myaccount" %>
<%@ Register Src="~/Public/ui/controls/Breadcrumb.ascx" TagPrefix="ks" TagName="Breadcrumb" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    My Account
</asp:Content>

<asp:Content ID="BreadcrumbContent" ContentPlaceHolderID="BreadcrumbContent" runat="server">
    <ks:Breadcrumb runat="server" ID="bcMyAccount" />
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <section class="tf-sp-2">
        <div class="container">

            <div class="tf-page-title style-2">
                <div class="heading">My Account</div>
                <p class="text-muted mb-0">Gestisci i tuoi dati, indirizzi, ordini e preferiti.</p>
            </div>

            <div class="row g-3 g-lg-4">

                <div class="col-12 col-md-6 col-xl-4">
                    <a class="card h-100 text-decoration-none" href="/datiutente.aspx">
                        <div class="card-body">
                            <div class="d-flex align-items-start justify-content-between">
                                <div>
                                    <div class="fw-semibold">I miei dati</div>
                                    <div class="text-muted small">Anagrafica e preferenze</div>
                                </div>
                                <span class="tf-icon-box"><i class="icon icon-user"></i></span>
                            </div>
                        </div>
                    </a>
                </div>

                <div class="col-12 col-md-6 col-xl-4">
                    <a class="card h-100 text-decoration-none" href="/indirizzi.aspx">
                        <div class="card-body">
                            <div class="d-flex align-items-start justify-content-between">
                                <div>
                                    <div class="fw-semibold">Indirizzi</div>
                                    <div class="text-muted small">Spedizione e fatturazione</div>
                                </div>
                                <span class="tf-icon-box"><i class="icon icon-map-pin"></i></span>
                            </div>
                        </div>
                    </a>
                </div>

                <div class="col-12 col-md-6 col-xl-4">
                    <a class="card h-100 text-decoration-none" href="/ordini.aspx">
                        <div class="card-body">
                            <div class="d-flex align-items-start justify-content-between">
                                <div>
                                    <div class="fw-semibold">Ordini</div>
                                    <div class="text-muted small">Storico ordini e dettagli</div>
                                </div>
                                <span class="tf-icon-box"><i class="icon icon-file-text"></i></span>
                            </div>
                        </div>
                    </a>
                </div>

                <div class="col-12 col-md-6 col-xl-4">
                    <a class="card h-100 text-decoration-none" href="/documenti.aspx?t=4">
                        <div class="card-body">
                            <div class="d-flex align-items-start justify-content-between">
                                <div>
                                    <div class="fw-semibold">Documenti</div>
                                    <div class="text-muted small">Fatture e documenti</div>
                                </div>
                                <span class="tf-icon-box"><i class="icon icon-download"></i></span>
                            </div>
                        </div>
                    </a>
                </div>

                <div class="col-12 col-md-6 col-xl-4">
                    <a class="card h-100 text-decoration-none" href="/wishlist.aspx">
                        <div class="card-body">
                            <div class="d-flex align-items-start justify-content-between">
                                <div>
                                    <div class="fw-semibold">Wishlist</div>
                                    <div class="text-muted small">I tuoi preferiti</div>
                                </div>
                                <span class="tf-icon-box"><i class="icon icon-heart"></i></span>
                            </div>
                        </div>
                    </a>
                </div>

                <div class="col-12 col-md-6 col-xl-4">
                    <a class="card h-100 text-decoration-none" href="/password.aspx">
                        <div class="card-body">
                            <div class="d-flex align-items-start justify-content-between">
                                <div>
                                    <div class="fw-semibold">Password</div>
                                    <div class="text-muted small">Cambia password</div>
                                </div>
                                <span class="tf-icon-box"><i class="icon icon-lock"></i></span>
                            </div>
                        </div>
                    </a>
                </div>

            </div>

            <div class="mt-4">
                <a class="btn btn-outline-danger" href="/logout.aspx">Logout</a>
            </div>

        </div>
    </section>

</asp:Content>
