<%@ Control Language="VB" AutoEventWireup="false" CodeFile="MiniCart.ascx.vb" Inherits="MiniCart" %>
<li class="nav-cart">
    <a class="link nav-icon-item position-relative" href="carrello.aspx" aria-label="Carrello">
        <span class="icon">
            <i class="icon icon-cart"></i>
        </span>
        <span class="body-small d-none d-xl-inline">
            <span class="text-secondary">Carrello:</span>
            <strong class="text-secondary"><asp:Label ID="lblCarrelloTotale" runat="server" Text="0,00" /></strong>
        </span>
        <span class="badge bg-primary position-absolute" style="top:-6px; right:-6px;">
            <asp:Label ID="lblCarrelloCount" runat="server" Text="0" />
        </span>
    </a>
</li>
