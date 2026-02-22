<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" Inherits="System.Web.UI.Page" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">Compare</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Compare</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-section-title mb_30">
                <h2 class="title">Confronta prodotti</h2>
                <p class="text-main-2 mt-2">Funzione in fase di integrazione. Nel frattempo puoi confrontare manualmente le schede prodotto.</p>
            </div>

            <div class="tf-empty-state text-center">
                <div class="heading">Nessun prodotto da confrontare</div>
                <p class="text-main-2 mt-2">Aggiungi prodotti al confronto dal catalogo per visualizzarli qui.</p>
                <div class="mt-4">
                    <a class="tf-btn btn-fill" href="articoli.aspx">Vai al catalogo</a>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
