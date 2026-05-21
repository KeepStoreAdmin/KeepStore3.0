<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="paypalreturn.aspx.vb" Inherits="paypalreturn" EnableViewState="false" ValidateRequest="true" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Rientro PayPal
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <meta name="robots" content="noindex,nofollow" />
    <meta http-equiv="Cache-Control" content="no-store, max-age=0" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <section class="flat-spacing">
        <div class="container">
            <div class="tf-page-title">
                <div class="heading text-center">Verifica pagamento PayPal</div>
                <p class="text text-center mt-3">Stiamo aggiornando l'esito del pagamento.</p>
            </div>
        </div>
    </section>
</asp:Content>
