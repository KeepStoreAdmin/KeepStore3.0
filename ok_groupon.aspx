<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="ok_groupon.aspx.vb" Inherits="ok_groupon" EnableViewState="false" ValidateRequest="true" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Coupon Groupon
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
                    <a href="<%= ResolveUrl("~/carrello_groupon.aspx") %>" class="text">Coupon</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Conferma</span>
                </div>
            </div>
        </div>
    </div>

    <section class="tf-sp-2">
        <div class="container">
            <div class="row justify-content-center">
                <div class="col-12 col-md-10 col-lg-7">

                    <div class="tf-page-title">
                        <div class="heading text-center">Coupon registrato correttamente</div>
                        <p class="text text-center mt-2">
                            Il coupon Groupon è stato associato al tuo account. Ora puoi procedere con il carrello e con l'ordine.
                        </p>
                    </div>

                    <div class="tf-checkout-box mt-4">
                        <div class="order-notice">
                            <span class="icon">
                                <svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" fill="#ffffff" viewBox="0 0 256 256">
                                    <path d="M128,16A112,112,0,1,0,240,128,112.13,112.13,0,0,0,128,16Zm0,208a96,96,0,1,1,96-96A96.11,96.11,0,0,1,128,224Zm-8-56a12,12,0,1,1,12,12A12,12,0,0,1,120,168Zm20-88v48a8,8,0,0,1-16,0V88a8,8,0,0,1,16,0Z"></path>
                                </svg>
                            </span>
                            <p>Conferma</p>
                        </div>

                        <div class="order-detail-wrap">
                            <ul class="list-unstyled mb-0">
                                <li class="mb_8">✅ Coupon valido e registrato</li>
                                <li class="mb_8">🛒 Prosegui al carrello per completare l'acquisto</li>
                            </ul>

                            <div class="box-btn mt-4 d-flex gap-2 flex-wrap">
                                <a class="tf-btn btn-fill" href="<%= ResolveUrl("~/carrello.aspx") %>">Vai al carrello</a>
                                <a class="tf-btn btn-line" href="<%= ResolveUrl("~/carrello_groupon.aspx") %>">Inserisci un altro coupon</a>
                            </div>
                        </div>
                    </div>

                </div>
            </div>
        </div>
    </section>

</asp:Content>
