<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeDepartmentsMenu.ascx.vb" Inherits="UI_HomeDepartmentsMenu" %>
<div class="tf-nav-menu ks-home-departments">
    <div class="main-nav">
        <div class="title">
            <i class="icon-menu-dots"></i>
            <span data-ks-i18n="nav.departments">Tutti i settori</span>
        </div>
        <ul class="menu-category-list">
            <asp:Repeater ID="rptSettoriHome" runat="server" OnItemDataBound="rptSettoriHome_ItemDataBound">
                <ItemTemplate>
                    <li id="liMenuItem" runat="server" class="menu-item">
                        <a href='<%# Eval("DefaultUrl") %>' class="item-link body-text-3">
                            <span class="ks-home-menu-link">
                                <span class="ks-menu-media">
                                    <img src='<%# Eval("ImgUrl") %>' alt='<%# SafeText(Eval("Descrizione")) %>' onerror="this.style.display='none';this.parentNode.classList.add('is-empty');" />
                                </span>
                                <span class="ks-menu-label"><%# SafeText(Eval("Descrizione")) %></span>
                                <span id="arrowIcon" runat="server" class="ks-menu-arrow" aria-hidden="true"><i class="icon-arrow-right-lg"></i></span>
                            </span>
                        </a>
                        <div class="sub-menu-container d-flex text-nowrap">
                            <ul class="sub-menu-list ks-home-submenu-list">
                                <asp:Literal ID="litDesktopSubmenu" runat="server" />
                            </ul>
                            <div id="promoCard" runat="server" class="cls-category style-abs abs-2 hover-img d-none d-xl-block">
                                <a href='<%# Eval("DefaultUrl") %>' class="img-box img-style d-block">
                                    <img src='<%# Eval("ImgUrl") %>' data-src='<%# Eval("ImgUrl") %>' alt='<%# SafeText(Eval("Descrizione")) %>' class="lazyload ks-settore-image" onerror="this.style.display='none';" />
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
