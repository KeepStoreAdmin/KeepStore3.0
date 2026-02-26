<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="ordine_coupon.aspx.vb" Inherits="ordine_coupon" EnableViewState="false" ValidateRequest="true" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Coupon
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
        <meta name="robots" content="noindex,nofollow" />
    <meta http-equiv="Cache-Control" content="no-store, max-age=0" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Breadcrumb -->
    <div class="tf-sp-3 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Coupon</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-page-title">
                <div class="heading text-center">Stiamo elaborando il coupon</div>
                <p class="text text-center mt-3">Non chiudere questa pagina: l'operazione verrà completata automaticamente.</p>
            </div>

            <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="ks-alert ks-alert-danger mt-4">
                <asp:Literal ID="litMsg" runat="server" />
            </asp:Panel>

            <div class="d-flex justify-content-center mt-4">
                <div class="tf-loading" aria-label="Loading"></div>
            </div>

            <div class="text-center mt-5">
                <a class="tf-btn btn-line" href="<%= ResolveUrl("~/carrello.aspx") %>">Torna al carrello</a>
            </div>
        </div>
    </section>

</asp:Content>