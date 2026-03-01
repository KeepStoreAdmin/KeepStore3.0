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
                                        We accept:
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
<h6 class="ft-heading footer-heading-mobile fw-semibold">Get help</h6>
<div class="tf-collapse-content">
<ul class="ft-menu-list">
<li><a class="link" href="Contattaci.aspx">Delivery Information</a></li>
<li><a class="link" href="Contattaci.aspx">Sale Terms &amp; Conditions</a></li>
<li><a class="link" href="Contattaci.aspx">Returns &amp; Refunds</a></li>
<li><a class="link" href="Contattaci.aspx">Privacy Notice</a></li>
<li><a class="link" href="Contattaci.aspx">Shopping FAQs</a></li>
</ul>
</div>
</li>
<li class="footer-col-block">
<h6 class="ft-heading footer-heading-mobile fw-semibold">Popular categories</h6>
<div class="tf-collapse-content">
<ul class="ft-menu-list">
<li><a class="link" href="articoli.aspx">Laptops &amp; Computers</a></li>
<li><a class="link" href="articoli.aspx">Cameras &amp; Photography</a></li>
<li><a class="link" href="articoli.aspx">Smart Phones &amp; Tablets</a></li>
<li><a class="link" href="articoli.aspx">Video Games &amp; Consoles</a></li>
<li><a class="link" href="articoli.aspx">TV &amp; Audio</a></li>
<li><a class="link" href="articoli.aspx">Gadgets</a></li>
<li><a class="link" href="articoli.aspx">Waterproof Headphones</a></li>
</ul>
</div>
</li>
<li class="footer-col-block">
<h6 class="ft-heading footer-heading-mobile fw-semibold">Customer Care</h6>
<div class="tf-collapse-content">
<ul class="ft-menu-list">
<li><a class="link" href="myaccount.aspx">My Account</a></li>
<li><a class="link" href="pay_your_orders.aspx">Track your Order</a></li>
<li><a class="link" href="contact.aspx">Customer Service</a></li>
<li><a class="link" href="Contattaci.aspx">Returns/Exchange</a></li>
<li><a class="link" href="Contattaci.aspx">FAQs</a></li>
<li><a class="link" href="contact.aspx">Product Support</a></li>
</ul>
</div>
</li>
<li class="footer-col-block type-sp-2">
<h6 class="ft-heading footer-heading-mobile fw-semibold">Contact</h6>
<div class="tf-collapse-content">
<ul class="ft-menu-list ft-contact-list">
<li>
<i class="icon">
<i class="icon-location"></i>
</i>
<a class="link" href="#">
                                                    8500 Lorem Street
                                                    Chicago, IL 55030 Dolor sit amet
                                                </a>
</li>
<li>
<i class="icon">
<i class="icon-phone"></i>
</i>
<a class="product-title" href="tel:88001234567">
<span class="product-title text-primary">
                                                        +8(800) 123 4567
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
                                    10% Off Your First Order
                                </span>
<span class="body-text-3">
                                    Be the first to know about offers, new products and discounted products
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
<li><a href="https://www.facebook.com"><i class="icon-facebook"></i></a></li>
<li><a href="https://x.com/"><i class="icon-x"></i></a></li>
<li><a href="https://www.instagram.com/"><i class="icon-instagram"></i></a></li>
<li><a href="https://www.linkedin.com/"><i class="icon-linkin"></i></a></li>
<li><a href="https://web.whatsapp.com/"><i class="icon-whatapp"></i></a></li>
</ul>
<ul class="ft-menu-list-2 body-text-3">
<li><a class="title-sidebar link fw-bold" href="Default.aspx">New arrivals</a></li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx">Best sale</a></li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx">Value of the day</a>
</li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx">Top 100 offers</a></li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx">Blog</a></li>
<li><a class="title-sidebar link fw-bold" href="Default.aspx"><i class="icon-fire"></i> 50% OFF</a>
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

