<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" Inherits="System.Web.UI.Page" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">Chi siamo</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Chi siamo</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="row align-items-center">
                <div class="col-lg-6">
                    <div class="tf-section-title mb_30">
                        <h2 class="title">KeepStore</h2>
                        <p class="text-main-2 mt-2">E-commerce e assistenza: hardware, telefonia, consumabili e accessori con focus su consulenza e post-vendita.</p>
                    </div>
                    <ul class="text-main-2">
                        <li>Catalogo sempre aggiornato e disponibilità trasparente.</li>
                        <li>Supporto tecnico e consulenza pre-acquisto.</li>
                        <li>Gestione rapida ordini e documenti nell’area account.</li>
                    </ul>
                    <div class="mt-4 d-flex gap-3 flex-wrap">
                        <a class="tf-btn btn-fill" href="articoli.aspx">Vai al catalogo</a>
                        <a class="tf-btn btn-line" href="Contattaci.aspx">Contattaci</a>
                    </div>
                </div>
                <div class="col-lg-6">
                    <div class="tf-img-with-text">
                        <img class="lazyload" data-src="/Public/onsus/images/slider/slider-1.jpg" src="/Public/onsus/images/slider/slider-1.jpg" alt="KeepStore" />
                    </div>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
