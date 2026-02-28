<%@ Control Language="VB" AutoEventWireup="false" CodeFile="AccountSidebar.ascx.vb" Inherits="AccountSidebar" %>
<!-- ============================================================
     Account Sidebar (KeepStore 3.0)
     - Menu area personale centralizzato
     - Solo UI: nessuna logica business / DB
     ============================================================ -->

<div class="ks-account-sidebar card">
    <div class="card-header py-3">
        <div class="d-flex align-items-center gap-2">
            <i class="icon icon-user"></i>
            <span class="fw-semibold">Area personale</span>
        </div>
    </div>

    <div class="list-group list-group-flush">
        <a id="lnkDashboard" runat="server" href="myaccount.aspx" class="list-group-item list-group-item-action">Dashboard</a>
        <a id="lnkAccountDetails" runat="server" href="datiutente.aspx" class="list-group-item list-group-item-action">Dettagli account</a>
        <a id="lnkAddresses" runat="server" href="datiutente.aspx?tab=addr" class="list-group-item list-group-item-action">Indirizzi</a>

        <div class="list-group-item py-2 small text-muted">Ordini e documenti</div>
        <a id="lnkOrders" runat="server" href="documenti.aspx?t=4" class="list-group-item list-group-item-action">I miei ordini</a>
        <a id="lnkInvoices" runat="server" href="documenti.aspx?t=2" class="list-group-item list-group-item-action">Le mie fatture</a>
        <a id="lnkDdt" runat="server" href="documenti.aspx?t=1" class="list-group-item list-group-item-action">I miei DDT</a>

        <div class="list-group-item py-2 small text-muted">Strumenti</div>
        <a id="lnkWishlist" runat="server" href="wishlist.aspx" class="list-group-item list-group-item-action">Wishlist</a>
        <a id="lnkChangePassword" runat="server" href="password.aspx" class="list-group-item list-group-item-action">Cambia password</a>
        <a id="lnkRecoverAccess" runat="server" href="remind.aspx" class="list-group-item list-group-item-action">Recupero accesso</a>

        <a id="lnkLogout" runat="server" href="logout.aspx" class="list-group-item list-group-item-action text-danger">Logout</a>
    </div>
</div>
