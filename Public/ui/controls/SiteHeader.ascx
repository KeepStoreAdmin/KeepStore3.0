<%@ Control Language="VB" AutoEventWireup="false" CodeFile="SiteHeader.ascx.vb" Inherits="SiteHeader" %>
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

                        <li class="nav-cart">
                            <a class="link nav-icon-item position-relative" href="carrello.aspx" aria-label="Carrello">
                                <span class="icon">
                                    <i class="icon icon-cart"></i>
                                </span>
                                <span class="body-small d-none d-xl-inline">
                                    <span class="text-secondary">Carrello:</span>
                                    <strong class="text-secondary"><asp:Label ID="lblCarrelloTotale" runat="server" Text="0,00" /></strong>
                                </span>
                                <span class="badge bg-primary position-absolute" style="top:-6px; right:-6px;">
                                    <asp:Label ID="lblCarrelloCount" runat="server" Text="0" />
                                </span>
                            </a>
                        </li>

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
    <div class="canvas-header">
        <h5 class="offcanvas-title" id="mobileMenuLabel">Menu</h5>
        <button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="Close"></button>
    </div>

    <div class="canvas-body">
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

        <div class="mb-3">
            <a class="tf-btn btn-line w-100" href="myaccount.aspx">Area personale</a>
        </div>

        <div class="mb-3">
            <a class="tf-btn btn-line w-100" href="carrello.aspx">Carrello</a>
        </div>

        <div class="wrap-sidebar-account">
            <ul class="myaccount-nav content-append">
                <li><a href="Default.aspx" class="myaccount-nav-item">Home</a></li>
                <li><a href="articoli.aspx" class="myaccount-nav-item">Catalogo</a></li>
            </ul>
        </div>

        <div class="mt-4">
            <div class="wrap-sidebar-account">
                <ul class="myaccount-nav content-append">
                    <asp:Repeater ID="rptNavSettoriMobile" runat="server">
                        <ItemTemplate>
                            <li class="myaccount-nav-item fw-semibold">
                                <a class="myaccount-nav-item" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                <asp:Repeater ID="rptNavCategorieMobile" runat="server">
                                    <ItemTemplate>
                                        <div class="ms-3 mt-2">
                                            <a class="link text-secondary fw-semibold" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                            <ul class="list-unstyled ms-3 mt-2">
                                                <asp:Repeater ID="rptNavTipologieMobile" runat="server">
                                                    <ItemTemplate>
                                                        <li class="mb-1">
                                                            <a class="link" href='<%# Eval("DefaultUrl") %>'><%# Eval("Descrizione") %></a>
                                                        </li>
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </ul>
                                        </div>
                                    </ItemTemplate>
                                </asp:Repeater>
                            </li>
                        </ItemTemplate>
                    </asp:Repeater>
                </ul>
            </div>
        </div>
    </div>
</div>

