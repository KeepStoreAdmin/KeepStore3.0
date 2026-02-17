<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="404.aspx.vb" Inherits="_404" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Pagina non trovata
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Breadcrumbs (template) -->
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">404</span>
                </div>
            </div>
        </div>
    </div>

    <!-- 404 (template) -->
    <section class="flat-spacing">
        <div class="container">
            <div class="tf-page-title">
                <div class="heading text-center">Ops! Pagina non trovata</div>
                <p class="text text-center mt-3">
                    La pagina che stai cercando non esiste oppure è stata spostata.
                </p>
                <div class="text-center mt-4 d-flex gap-3 justify-content-center flex-wrap">
                    <a class="tf-btn btn-fill" href="Default.aspx">Torna alla Home</a>
                    <a class="tf-btn btn-line" href="articoli.aspx">Vai al catalogo</a>
                </div>
            </div>
        </div>
    </section>

</asp:Content>
