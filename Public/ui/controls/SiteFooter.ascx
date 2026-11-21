<%@ Control Language="VB" AutoEventWireup="false" CodeFile="SiteFooter.ascx.vb" Inherits="SiteFooter" %>
<footer class="tf-footer">
    <div class="ft-body-wrap">
        <div class="ft-body-inner">
            <div class="container">
                <div class="ft-inner flex-wrap flex-xl-nowrap">
                    <div class="ft-logo">
                        <a class="logo-site" href="Default.aspx">
                            <asp:Image ID="imgFooterLogo" runat="server" AlternateText="KeepStore" CssClass="lazyload ks-footer-logo-img" />
                        </a>
                    </div>
                    <ul id="ulFooterColumns" runat="server" class="ft-link-wrap w-100 tf-grid-layout md-col-2 lg-col-4">
                        <li class="footer-col-block">
                            <h6 class="ft-heading footer-heading-mobile fw-semibold">Supporto</h6>
                            <div class="tf-collapse-content">
                                <ul class="ft-menu-list">
                                    <li><a class="link" href="condizioni-vendita.aspx">Condizioni di vendita</a></li>
                                    <li><a class="link" href="condizioni-vendita.aspx#diritto-recesso">Diritto di recesso</a></li>
                                    <li><a class="link" href="faq.aspx">Domande frequenti</a></li>
                                    <li><a class="link" href="privacy.aspx">Privacy</a></li>
                                </ul>
                            </div>
                        </li>
                        <asp:PlaceHolder ID="phFooterCategories" runat="server" Visible="false">
                            <li class="footer-col-block">
                                <h6 class="ft-heading footer-heading-mobile fw-semibold">Catalogo</h6>
                                <div class="tf-collapse-content">
                                    <ul class="ft-menu-list">
                                        <asp:Literal ID="litFooterCategories" runat="server" EnableViewState="False" />
                                    </ul>
                                </div>
                            </li>
                        </asp:PlaceHolder>
                        <li class="footer-col-block">
                            <h6 class="ft-heading footer-heading-mobile fw-semibold">Area cliente</h6>
                            <div class="tf-collapse-content">
                                <ul class="ft-menu-list">
                                    <li><a class="link" href="myaccount.aspx">La tua Dashboard</a></li>
                                    <li><a class="link" href="pay_your_orders.aspx">I miei ordini</a></li>
                                    <li><a class="link" href="track-your-order.aspx">Traccia il tuo ordine</a></li>
                                </ul>
                            </div>
                        </li>
                        <li class="footer-col-block type-sp-2">
                            <h6 class="ft-heading footer-heading-mobile fw-semibold">Contatti</h6>
                            <div class="tf-collapse-content">
                                <ul class="ft-menu-list ft-contact-list">
                                    <asp:Literal ID="litFooterContacts" runat="server" EnableViewState="False" />
                                </ul>
                            </div>
                        </li>
                    </ul>
                </div>
            </div>
        </div>
        <div class="ft-body-bottom">
            <div class="container">
                <div class="ft-bottom">
                    <ul id="ulFooterSocial" runat="server" class="social-list">
                        <li id="liFooterFacebook" runat="server" visible="false"><a id="lnkFooterFacebook" runat="server" rel="noopener noreferrer"><i class="icon-facebook" aria-hidden="true"></i></a></li>
                    </ul>
                    <ul class="ft-menu-list-2 body-text-3">
                        <li><a class="title-sidebar link fw-bold" href="articoli.aspx?inpromo=1">Offerte</a></li>
                        <li><a class="title-sidebar link fw-bold" href="Contattaci.aspx">Contatti</a></li>
                    </ul>
                    <asp:PlaceHolder ID="phFooterPayments" runat="server" Visible="false">
                        <p class="caption text-center text-break ft-payments">Metodi di pagamento: <asp:Literal ID="litFooterPayments" runat="server" EnableViewState="False" /></p>
                        <asp:Literal ID="litFooterPaymentLogos" runat="server" EnableViewState="False" />
                    </asp:PlaceHolder>
                    <asp:PlaceHolder ID="phFooterLegal" runat="server" Visible="false">
                        <p class="caption text-center text-break ft-legal"><asp:Literal ID="litFooterLegal" runat="server" EnableViewState="False" /></p>
                    </asp:PlaceHolder>
                    <p class="nocopy caption text-center"><asp:Literal ID="litFooterCopyright" runat="server" EnableViewState="False" /></p>
                </div>
            </div>
        </div>
    </div>
</footer>
