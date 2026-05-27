<%@ Control Language="VB" AutoEventWireup="false" CodeFile="AccountSidebar.ascx.vb" Inherits="Public_ui_controls_AccountSidebar" %>

<div class="ks-account-card">
    <div class="ks-account-card-head">
        <div class="d-flex align-items-center gap-3">
            <div class="ks-account-avatar" aria-hidden="true">
                <i class="icon-user"></i>
            </div>
            <div>
                <div class="fw-semibold">Area Cliente</div>
                <div class="text-muted small">Gestisci il tuo account</div>
            </div>
        </div>
    </div>

    <div class="ks-account-card-body">
        <nav class="ks-account-nav" aria-label="Menu account">
            <ul class="ks-account-nav-list" runat="server" id="ulMenu">
                <li>
                    <a href="myaccount.aspx" class="ks-account-nav-link" data-ks-active="myaccount.aspx" runat="server" id="lnkDashboard">
                        <i class="icon-home"></i>
                        <span>Dashboard</span>
                    </a>
                </li>
                <li>
                    <a href="my-account-edit.aspx" class="ks-account-nav-link" data-ks-active="my-account-edit.aspx" runat="server" id="lnkDati">
                        <i class="icon-user"></i>
                        <span>Dettagli account</span>
                    </a>
                </li>
                <li>
                    <a href="my-account-address.aspx" class="ks-account-nav-link" data-ks-active="my-account-address.aspx" runat="server" id="lnkIndirizzi">
                        <i class="icon-map-pin"></i>
                        <span>Indirizzi</span>
                    </a>
                </li>
                <li>
                    <a href="documenti.aspx" class="ks-account-nav-link" data-ks-active="documenti.aspx" runat="server" id="lnkOrdini">
                        <i class="icon-file-text"></i>
                        <span>Ordini / Documenti</span>
                    </a>
                </li>
                <li>
                    <a href="wishlist.aspx" class="ks-account-nav-link" data-ks-active="wishlist.aspx" runat="server" id="lnkWishlist">
                        <i class="icon-heart"></i>
                        <span>Wishlist</span>
                    </a>
                </li>
                <li>
                    <a href="cambiapassword.aspx" class="ks-account-nav-link" data-ks-active="cambiapassword.aspx" runat="server" id="lnkPassword">
                        <i class="icon-lock"></i>
                        <span>Password</span>
                    </a>
                </li>
                <li>
                    <a href="logout.aspx" class="ks-account-nav-link" data-ks-active="logout.aspx" runat="server" id="lnkLogout">
                        <i class="icon-log-out"></i>
                        <span>Esci</span>
                    </a>
                </li>
            </ul>
        </nav>
    </div>
</div>
