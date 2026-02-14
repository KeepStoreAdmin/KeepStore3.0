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

    <div class="tf-sp-3 pb-0">
        <div class="container">
            <ul class="breakcrumbs">
                <li><a href="<%= ResolveUrl("~/Default.aspx") %>" class="body-small link">Home</a></li>
                <li class="d-flex align-items-center"><i class="icon icon-arrow-right"></i></li>
                <li><span class="body-small">Coupon</span></li>
            </ul>
        </div>
    </div>

    <section class="tf-sp-2">
        <div class="container">
            <div class="ks-coupon-center">
                <div class="order-notice">
                    <span class="icon">
                        <svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" fill="#ffffff" viewBox="0 0 256 256">
                            <path d="M128,16A112,112,0,1,0,240,128,112.13,112.13,0,0,0,128,16Zm0,208a96,96,0,1,1,96-96A96.11,96.11,0,0,1,128,224Z"></path>
                        </svg>
                    </span>
                    <p>Elaborazione coupon</p>
                </div>

                <div class="order-detail-wrap">
                    <p class="body-text-3" style="margin:0;">Stiamo elaborando la richiesta... se la pagina non si aggiorna automaticamente, torna indietro e riprova.</p>
                </div>
            </div>
        </div>
    </section>

</asp:Content>
