<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="pagamento.aspx.vb" Inherits="pagamento" EnableViewState="false" ValidateRequest="true" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Pagamento
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
                    <a href="<%= ResolveUrl("~/carrello.aspx") %>" class="text">Carrello</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Pagamento</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-page-title">
                <div class="heading text-center">Stiamo elaborando il pagamento</div>
                <p class="text text-center mt-3">
                    Non chiudere questa pagina. Se non vieni reindirizzato automaticamente, attendi qualche secondo e poi torna alla pagina ordine.
                </p>
            </div>

            <div class="d-flex justify-content-center mt-4">
                <div class="tf-loading" aria-label="Loading"></div>
            </div>

            <div class="text-center mt-5">
                <a class="tf-btn btn-line" href="<%= ResolveUrl("~/carrello.aspx") %>">Torna al carrello</a>
            </div>
        </div>
    </section>

</asp:Content>
