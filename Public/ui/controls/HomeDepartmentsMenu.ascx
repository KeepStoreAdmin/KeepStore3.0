<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeDepartmentsMenu.ascx.vb" Inherits="UI_HomeDepartmentsMenu" %>
<div class="tf-nav-menu ks-home-departments" data-ks-home-menu="1">
    <div class="main-nav">
        <div class="title">
            <i class="icon-menu-dots"></i>
            <span data-ks-i18n="nav.departments">Tutti i settori</span>
        </div>
        <ul class="menu-category-list" role="menu">
            <asp:Repeater ID="rptSettoriHome" runat="server" OnItemDataBound="rptSettoriHome_ItemDataBound">
                <ItemTemplate>
                    <li id="liMenuItem" runat="server" class="menu-item" role="none" data-ks-menu-item="1">
                        <div class="ks-home-menu-row" data-ks-menu-row="1">
                            <a href='<%# Eval("DefaultUrl") %>' class="item-link body-text-3" role="menuitem">
                                <span class="ks-home-menu-link">
                                    <span class='<%# MenuSectorMediaClass(Eval("ImgUrl")) %>'>
                                        <%# RenderSectorMenuImage(Eval("ImgUrl"), Eval("Descrizione")) %>
                                    </span>
                                    <span class="ks-menu-label"><%# SafeText(Eval("Descrizione")) %></span>
                                    <span id="arrowIcon" runat="server" class="ks-menu-arrow" aria-hidden="true"><i class="icon-arrow-right-lg"></i></span>
                                </span>
                            </a>
                            <button id="toggleButton" runat="server" type="button" class="ks-menu-toggle" aria-expanded="false" aria-label="Apri sottomenu">
                                <i class="icon-arrow-right-lg"></i>
                            </button>
                        </div>
                        <div id="subMenuContainer" runat="server" class="sub-menu-container d-flex text-nowrap" aria-hidden="true" data-ks-submenu="1">
                            <ul class="sub-menu-list ks-home-submenu-list">
                                <asp:Literal ID="litDesktopSubmenu" runat="server" />
                            </ul>
                            <div id="promoCard" runat="server" class="cls-category style-abs abs-2 hover-img d-none d-xl-block ks-home-sector-promo" data-ks-sector-promo="1">
                                <a href='<%# Eval("DefaultUrl") %>' class="img-box img-style d-block">
                                    <img src='<%# ResolveSectorPromoImage(Eval("ImgUrl")) %>'
                                         data-src='<%# ResolveSectorPromoImage(Eval("ImgUrl")) %>'
                                         alt='<%# SafeText(Eval("Descrizione")) %>'
                                         class="lazyload ks-settore-image"
                                         onerror="this.closest('.ks-home-sector-promo').style.display='none';" />
                                </a>
                                <div class="content text-center">
                                    <div class="box-title">
                                        <p class="product-title-2 text-uppercase" data-ks-i18n="nav.departmentCollection">Collezione reparto</p>
                                        <h4><%# SafeText(Eval("Descrizione")) %></h4>
                                    </div>
                                    <div class="box-btn">
                                        <a href='<%# Eval("DefaultUrl") %>' class="tf-btn btn-line-white text-main d-inline-flex">
                                            <span data-ks-i18n="nav.shopNow">Scopri ora</span>
                                        </a>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </li>
                </ItemTemplate>
            </asp:Repeater>
        </ul>
    </div>
</div>
