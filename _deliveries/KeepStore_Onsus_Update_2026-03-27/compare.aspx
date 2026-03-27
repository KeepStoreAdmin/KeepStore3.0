<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" Inherits="System.Web.UI.Page" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">Confronta prodotti</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Confronta prodotti</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-section-title mb_30">
                <h2 class="title">Confronta prodotti</h2>
                <p class="text-main-2 mt-2">Seleziona i prodotti dal catalogo e confrontali in questa pagina.</p>
            </div>

            <div class="tf-empty-state text-center" id="ksCompareEmptyState">
                <div class="heading">Nessun prodotto da confrontare</div>
                <p class="text-main-2 mt-2">Aggiungi prodotti al confronto dal catalogo per visualizzarli qui.</p>
                <div class="mt-4">
                    <a class="tf-btn btn-fill" href="articoli.aspx">Vai al catalogo</a>
                </div>
            </div>

            <div class="tf-compare-list ks-compare-page d-none" id="ksCompareShell">
                <h5 class="title fw-semibold">Compara prodotti</h5>
                <div class="tf-compare-wrap ks-compare-page-grid" id="ksCompareGrid"></div>
                <div class="tf-compare-buttons">
                    <div class="tf-compare-btn">
                        <a href="articoli.aspx" class="tf-btn btn-gray btn-large-3">
                            <span class="text-white">Continua acquisti</span>
                        </a>
                        <button type="button" class="tf-btn tf-compapre-button-clear-all clear-file-delete link btn-large-3" id="ksCompareClear">
                            <span class="text-white">Svuota</span>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
