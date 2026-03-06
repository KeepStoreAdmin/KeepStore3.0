<%@ Control Language="VB" AutoEventWireup="false" CodeFile="SiteFooter.ascx.vb" Inherits="SiteFooter" %>
<!-- Footer -->
            <footer class="tf-footer">
<div class="ft-body-wrap">
<div class="ft-body-inner">
<div class="container">
<div class="ft-inner flex-wrap flex-xl-nowrap">
<div class="ft-logo">
<a class="logo-site" href="Default.aspx">
<img alt="Logo" class="lazyload" decoding="async" height="128" src="<%= ThemeManager.Asset("images/logo/logo.webp") %>" srcset="<%= ThemeManager.Asset("images/logo/logo.webp") %> 328w" width="185"/>
</a>
<div class="method-payment">
<p>
                                        Pagamenti accettati:
                                    </p>
<ul class="method-list">
<li>
<img alt="Payment" src="<%= ThemeManager.Asset("images/payment/visa.svg") %>"/>
</li>
<li>
<img alt="Payment" src="<%= ThemeManager.Asset("images/payment/paypal.svg") %>"/>
</li>
<li>
<img alt="Payment" src="<%= ThemeManager.Asset("images/payment/discover.svg") %>"/>
</li>
<li>
<img alt="Payment" src="<%= ThemeManager.Asset("images/payment/master.svg") %>"/>
</li>
</ul>
</div>
</div>
<ul class="ft-link-wrap w-100 tf-grid-layout md-col-2 lg-col-4">
<li class="footer-col-block">
<h6 class="ft-heading footer-heading-mobile fw-semibold">Supporto</h6>
<div class="tf-collapse-content">
<ul class="ft-menu-list">
<li><a class="link" href="Contattaci.aspx">Informazioni consegna</a></li>
<li><a class="link" href="Contattaci.aspx">Condizioni di vendita</a></li>
<li><a class="link" href="Contattaci.aspx">Resi e rimborsi</a></li>
<li><a class="link" href="Contattaci.aspx">Privacy</a></li>
<li><a class="link" href="Contattaci.aspx">Domande frequenti</a></li>
</ul>
</div>
</li>
<li class="footer-col-block">
<h6 class="ft-heading footer-heading-mobile fw-semibold">Categorie popolari</h6>
<div class="tf-collapse-content">
<ul class="ft-menu-list">
<li><a class="link" href="articoli.aspx">Notebook e computer</a></li>
<li><a class="link" href="articoli.aspx">Fotografia e video</a></li>
<li><a class="link" href="articoli.aspx">Smartphone e tablet</a></li>
<li><a class="link" href="articoli.aspx">Gaming e console</a></li>
<li><a class="link" href="articoli.aspx">TV e audio</a></li>
<li><a class="link" href="articoli.aspx">Accessori tech</a></li>
<li><a class="link" href="articoli.aspx">Audio e cuffie</a></li>
</ul>
</div>
</li>
<li class="footer-col-block">
<h6 class="ft-heading footer-heading-mobile fw-semibold">Area cliente</h6>
<div class="tf-collapse-content">
<ul class="ft-menu-list">
<li><a class="link" href="myaccount.aspx">Il mio account</a></li>
<li><a class="link" href="pay_your_orders.aspx">Monitora il tuo ordine</a></li>
<li><a class="link" href="Contattaci.aspx">Servizio clienti</a></li>
<li><a class="link" href="Contattaci.aspx">Resi e cambi</a></li>
<li><a class="link" href="Contattaci.aspx">FAQ</a></li>
<li><a class="link" href="Contattaci.aspx">Supporto prodotti</a></li>
</ul>
</div>
</li>
<li class="footer-col-block type-sp-2">
<h6 class="ft-heading footer-heading-mobile fw-semibold">Contatti</h6>
<div class="tf-collapse-content">
<ul class="ft-menu-list ft-contact-list">
<li>
<i class="icon">
<i class="icon-location"></i>
</i>
<a class="link" href="#">
                                                    KeepStore
                                                    Assistenza pre e post vendita
                                                </a>
</li>
<li>
<i class="icon">
<i class="icon-phone"></i>
</i>
<a class="product-title" href="tel:88001234567">
<span class="product-title text-primary">
                                                        +39 000 000 0000
                                                    </span>
</a>
</li>
<li>
<span class="icon">
<i class="icon-direction"></i>
</span>
<a id="lnkSupportEmail" runat="server" class="" href="#">
<span class="text-primary"><asp:Literal ID="litSupportEmail" runat="server" EnableViewState="False" /></span>
</a>
</li>
</ul>
</div>
</li>
</ul>
</div>
</div>
</div>
<div class="ft-body-center bg-gray">
<div class="container">
<div class="ft-center justify-content-xxl-between">
<p class="notice text-white justify-content-xxl-between">
<span class="main-title fw-semibold">
<img alt="" src="<%= ThemeManager.Asset("images/mail.svg") %>"/>
                                    Novita e promozioni KeepStore
                                </span>
<span class="body-text-3">
                                    Ricevi aggiornamenti su offerte, nuovi arrivi e prodotti in promozione
                                </span>
</p>
<div class="form-newsletter" data-ks-newsletter="1">
<div class="subscribe-content">
<fieldset class="email">
<input id="ksNewsletterEmail" class="subscribe-email type-fs-2" name="ksNewsletterEmail" placeholder="Inserisci la tua email" tabindex="0" type="email" autocomplete="email"/>
</fieldset>
<div class="button-submit">
<button id="ksNewsletterSubmit" class="subscribe-button tf-btn btn-large hover-shine" type="button" aria-label="Iscriviti alla newsletter">
<span class="body-md-2 fw-semibold text-white">Iscriviti</span>
</button>
</div>
</div>
</div>
</div>
</div>
</div>
<div class="ft-body-bottom">
<div class="container">
<div class="ft-bottom">
<ul class="social-list">
<li><a href="https://www.facebook.com/taikun.it"><i class="icon-facebook"></i></a></li>
<li><a href="https://x.com/"><i class="icon-x"></i></a></li>
<li><a href="https://www.instagram.com/taikun.it"><i class="icon-instagram"></i></a></li>
<li><a href="https://www.linkedin.com/"><i class="icon-linkin"></i></a></li>
<li><a href="https://web.whatsapp.com/"><i class="icon-whatapp"></i></a></li>
</ul>
<ul class="ft-menu-list-2 body-text-3">
<li><a class="title-sidebar link fw-bold" href="Default.aspx">Nuovi arrivi</a></li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx">Migliori offerte</a></li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx">Occasione del giorno</a>
</li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx">Top offerte</a></li>
<li><a class="title-sidebar link fw-bold" href="Contattaci.aspx">Contatti</a></li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx"><i class="icon-fire"></i> Promo</a>
</li>
</ul>
<p class="nocopy caption text-center">
<span class="fw-medium">KeepStore</span> © <%= DateTime.Now.Year %>
</p>
</div>
</div>
</div>
</div>
</footer>

