<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="condizioni-vendita.aspx.vb" Inherits="condizioni_vendita" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Condizioni Generali di Vendita
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Condizioni Generali di Vendita</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-section-title mb_30">
                <h2 class="title">Condizioni Generali di Vendita</h2>
                <p class="text-main-2 mt-2">
                    <asp:Literal ID="litCompanyName" runat="server" />
                </p>
            </div>

            <div class="row">
                <div class="col-lg-9">
                    <article class="tf-privacy">
                        <span id="diritto-recesso"></span>
                        <asp:Literal ID="litTermsContent" runat="server" />
                    </article>
                </div>

                <div class="col-lg-3">
                    <div class="tf-sidebar">
                        <div class="widget">
                            <h5 class="widget-title">Area legale</h5>
                            <ul class="category-list">
                                <li><a href="condizioni-vendita.aspx" class="text-secondary link">Condizioni di vendita</a></li>
                                <li><a href="condizioni-vendita.aspx#diritto-recesso" class="text-secondary link">Diritto di recesso</a></li>
                                <li><a href="privacy.aspx" class="text-secondary link">Privacy Policy</a></li>
                                <li><a href="Contattaci.aspx" class="text-secondary link">Contatti</a></li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
