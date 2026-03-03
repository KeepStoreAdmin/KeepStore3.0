<%@ Control Language="VB" AutoEventWireup="false" CodeFile="SiteHeader.ascx.vb" Inherits="SiteHeader" %>
<%@ Register Src="~/Public/ui/controls/MiniCart.ascx" TagPrefix="ks" TagName="MiniCart" %>
<!-- ============================================================
                 HEADER
                 - Mantiene ID/handler esistenti (imgLogo/imgLogoMobile, tbCerca, btnSearch, mvLogin, rptNavSettori, lblCarrelloCount/lblCarrelloTotale)
                 ============================================================ -->
            <header class="tf-header style-2">
    <div class="inner-header">
        <div class="container">
            <div class="row align-items-center">
                <!-- Logo -->
                <div class="col-xl-3 col-md-3 col-7 d-flex align-items-center">
                    <div class="logo-site">
                        <a href="Default.aspx" class="d-inline-block">
                            <asp:Image ID="imgLogo" runat="server" AlternateText="KeepStore" CssClass="lazyload" ImageUrl="/Public/assets/keepstore/images/logo/logo.webp" />
                        </a>
                    </div>
                </div>

                <!-- Search (desktop) -->
                <div class="col-xl-6 col-md-6 d-none d-md-block">
                    <div class="header-center">
                        <div class="form-search-product style-2">
                            <fieldset>
                                <asp:TextBox ID="tbCerca" runat="server" CssClass="" placeholder="Cerca prodotti..." />
                            </fieldset>
                            <button id="btnSearch" runat="server" type="submit" class="btn-submit-form" aria-label="Cerca">
                                <i class="icon-search"></i>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Icons -->
                <div class="col-xl-3 col-md-3 col-5 d-flex align-items-center justify-content-end">
                    <ul class="nav-icon justify-content-end">
                        <li class="nav-account">
                            <a class="link nav-icon-item" href="myaccount.aspx" aria-label="Account">
                                <span class="icon">
                                    <i class="icon icon-user"></i>
                                </span>
                                <span class="body-small">
                                    <asp:MultiView ID="mvLogin" runat="server">
                                        <asp:View ID="vwLoginOff" runat="server">
                                            <span id="lblLogin" runat="server">Accedi</span>
                                        </asp:View>
                                        <asp:View ID="vwLoginOn" runat="server">
                                            <span>Ciao, <asp:Label ID="lblUtente" runat="server" /></span>
                                            <span class="d-none"><asp:Label ID="lblAccesso" runat="server" /></span>
                                        </asp:View>
                                    </asp:MultiView>
                                </span>
                            </a>
                        </li>

                        <ks:MiniCart ID="MiniCart1" runat="server" />

                        <li class="d-flex align-items-center d-xl-none">
                            <a class="mobile-button" data-bs-toggle="offcanvas" href="#mobileMenu" aria-controls="mobileMenu" aria-label="Menu">
                                <span></span>
                            </a>
                        </li>
                    </ul>
                </div>
            </div>
        </div>
    </div>

    <!-- NAV (desktop) -->
    <div class="header-bottom bg-gray-5 d-none d-xl-block">
        <div class="container relative">
            <nav class="main-nav-menu">
                <ul class="nav-list">
                    <li class="nav-item active pst-unset">
                        <a class="item-link link body-md-2 fw-semibold" href="Default.aspx"><span>Home</span></a>
                    </li>

                    <li class="nav-item pst-unset">
                        <a class="item-link link body-md-2 fw-semibold" href="articoli.aspx"><span>Catalogo</span></a>
                    </li>

                    <asp:Repeater ID="rptNavSettori" runat="server">
                        <ItemTemplate>
                            <li class="nav-item pst-unset">
                                <a class="item-link link body-md-2 fw-semibold" href='<%# Eval("DefaultUrl") %>'>
                                    <span><%# Eval("Descrizione") %></span>
                                    <i class="icon icon-arrow-down"></i>
                                </a>

                                <div class="sub-menu-container mega-menu">
                                    <div class="container">
                                        <div class="row">
                                            <asp:Repeater ID="rptNavCategorie" runat="server">
                                                <ItemTemplate>
                                                    <div class="col-xl-3 col-lg-4 col-md-6">
                                                        <div class="mega-menu-column">
                                                            <h6 class="menu-title mb-10">
                                                                <a class="link text-secondary fw-semibold" href='<%# Eval("DefaultUrl") %>'>
                                                                    <%# Eval("Descrizione") %>
                                                                </a>
                                                            </h6>

                                                            <ul class="sub-menu-list">
                                                                <asp:Repeater ID="rptNavTipologie" runat="server">
                                                                    <ItemTemplate>
                                                                        <li>
                                                                            <a class="link" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                                                        </li>
                                                                    </ItemTemplate>
                                                                </asp:Repeater>
                                                            </ul>
                                                        </div>
                                                    </div>
                                                </ItemTemplate>
                                            </asp:Repeater>
                                        </div>
                                    </div>
                                </div>
                            </li>
                        </ItemTemplate>
                    </asp:Repeater>

                    <li class="nav-item pst-unset">
                        <a class="item-link link body-md-2 fw-semibold" href="Contattaci.aspx"><span>Contatti</span></a>
                    </li>
                </ul>
            </nav>
        </div>
    </div>
</header>

<!-- Mobile Menu -->
<div class="offcanvas offcanvas-start canvas-mb" tabindex="-1" id="mobileMenu" aria-labelledby="mobileMenuLabel">
    <!-- Close icon (template-like) -->
    <span class="icon-close btn-close-mb link" data-bs-dismiss="offcanvas" aria-label="Chiudi"></span>

	    <h5 class="visually-hidden" id="mobileMenuLabel">Menu</h5>
	    <div class="mb-canvas-content">
	        <div class="mb-body">
	            <div class="flat-animate-tab">
	                <div class="flat-title-tab-nav-mobile">
	                    <ul class="menu-tab-line" role="tablist">
	                        <li class="nav-tab-item" role="presentation">
	                            <a href="#main-menu" class="tab-link link fw-semibold active" data-bs-toggle="tab" role="tab" aria-selected="true">Menu</a>
	                        </li>
	                        <li class="br-line type-vertical bg-line h23" aria-hidden="true"></li>
	                        <li class="nav-tab-item" role="presentation">
	                            <a href="#category" class="tab-link link fw-semibold" data-bs-toggle="tab" role="tab" aria-selected="false">Categorie</a>
	                        </li>
	                    </ul>
	                </div>
	
	                <div class="tab-content">
	                    <!-- MENU -->
	                    <div class="tab-pane active show" id="main-menu" role="tabpanel">
	                        <div class="mb-content-top">
	                            <div class="mb-3">
	                                <a class="site-logo" href="Default.aspx" aria-label="Home">
	                                    <img src="/Public/assets/keepstore/images/logo/LogoKeepStore.png" alt="KeepStore" width="160" height="40" />
	                                </a>
	                            </div>
	
	                            <!-- Search (no nested <form> in WebForms) -->
	                            <div class="mb-3">
	                                <div class="form-search-product style-2">
	                                    <fieldset>
	                                        <asp:TextBox ID="tbCercaMobile" runat="server" CssClass="" placeholder="Cerca prodotti..." AutoPostBack="true" />
	                                    </fieldset>
	                                    <button id="btnSearchMobile" runat="server" type="submit" class="btn-submit-form" aria-label="Cerca">
	                                        <i class="icon-search"></i>
	                                    </button>
	                                </div>
	                            </div>
	
	                            <div class="wrap-sidebar-account">
	                                <ul class="myaccount-nav content-append">
	                                    <li><a href="Default.aspx" class="myaccount-nav-item">Home</a></li>
	                                    <li><a href="articoli.aspx" class="myaccount-nav-item">Catalogo</a></li>
	                                    <li><a href="Contattaci.aspx" class="myaccount-nav-item">Contatti</a></li>
	                                </ul>
	                            </div>
	
	                            <div class="mt-3 d-grid gap-2">
	                                <a class="tf-btn btn-line w-100" href="myaccount.aspx">Area personale</a>
	                                <a class="tf-btn btn-line w-100" href="carrello.aspx">Carrello</a>
	                            </div>
	                        </div>
	                    </div>
	
	                    <!-- CATEGORIES (scrollable) -->
	                    <div class="tab-pane" id="category" role="tabpanel">
	                        <div class="mb-content-top">
	                            <ul class="nav-ul-mb" aria-label="Categorie">
	                                <asp:Repeater ID="rptNavSettoriMobile" runat="server">
	                                    <ItemTemplate>
	                                        <li class="nav-mb-item">
	                                            <a class="collapsed mb-menu-link" data-bs-toggle="collapse" href='<%# "#mbSector" & Container.ItemIndex %>' role="button" aria-expanded="false" aria-controls='<%# "mbSector" & Container.ItemIndex %>'>
	                                                <span><%# Eval("Descrizione") %></span>
	                                                <span class="btn-open-sub"></span>
	                                            </a>
	                                            <div class="collapse" id='<%# "mbSector" & Container.ItemIndex %>'>
	                                                <ul class="sub-nav-menu">
	                                                    <li>
	                                                        <a class="sub-nav-link fw-semibold" href='<%# Eval("DefaultUrl") %>'>Tutti i prodotti</a>
	                                                    </li>
	
	                                                    <asp:Repeater ID="rptNavCategorieMobile" runat="server">
	                                                        <ItemTemplate>
	                                                            <li class="mt-2">
	                                                                <a class="sub-nav-link" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
	                                                                <ul class="sub-menu-level-2 mt-2">
	                                                                    <asp:Repeater ID="rptNavTipologieMobile" runat="server">
	                                                                        <ItemTemplate>
	                                                                            <li class="mb-1">
	                                                                                <a class="sub-nav-link-2" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
	                                                                            </li>
	                                                                        </ItemTemplate>
	                                                                    </asp:Repeater>
	                                                                </ul>
	                                                            </li>
	                                                        </ItemTemplate>
	                                                    </asp:Repeater>
	                                                </ul>
	                                            </div>
	                                        </li>
	                                    </ItemTemplate>
	                                </asp:Repeater>
	                            </ul>
	                        </div>
	                    </div>
	                </div>
	            </div>
	        </div>
	    </div>
</div>

