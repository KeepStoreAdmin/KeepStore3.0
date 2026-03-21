<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeDepartmentsMenu.ascx.vb" Inherits="UI_HomeDepartmentsMenu" %>

<!--
    Departments menu for the home page.
    This markup has been updated to follow the Onsus template structure using
    the nav-category-wrap pattern.  The nav-title toggles the visibility of
    the category-menu via JavaScript defined in SiteHeader.ascx.  Sub menus
    appear on hover for desktop and can expand on mobile.
-->
<div class="tf-nav-menu ks-home-departments">
    <div class="nav-category-wrap">
        <!-- The nav-title acts as a button to show/hide the category menu -->
        <div class="nav-title btn-active">
            <i class="icon-menu-dots"></i>
            <h6 class="title fw-semibold">All departments</h6>
        </div>
        <!-- Category menu container; active-item class makes it visible by default -->
        <div class="category-menu active-item">
            <ul class="menu-category-list">
                <asp:Repeater ID="rptSettoriHome" runat="server" DataSourceID="sdsSettoriHome">
                    <ItemTemplate>
                        <li class="menu-item">
                            <a href='<%# BuildSettoreUrl(Eval("id")) %>' class="item-link body-text-3 ks-root-sector-link"><span><%# SafeText(Eval("Descrizione")) %></span></a>
                            <div class="sub-menu-container d-flex">
                                <ul class="sub-menu-list">
                                    <asp:Repeater ID="rptCategorieHome" runat="server" DataSourceID="sdsCategorieHome">
                                        <ItemTemplate>
                                            <li class="sub-menu-item"><a class="body-text-3 link" href='<%# "articoli.aspx?st=" & Eval("SettoriId") & "&ct=" & Eval("id") %>'><%# SafeText(Eval("Descrizione")) %></a></li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                    <asp:SqlDataSource ID="sdsCategorieHome" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="MySql.Data.MySqlClient" SelectCommand='<%# "SELECT id, SettoriId, Descrizione FROM categorie WHERE COALESCE(Abilitato,1)=1 AND SettoriId=" & Eval("id") & " ORDER BY COALESCE(Ordinamento,0), Descrizione LIMIT 9" %>' />
                                </ul>
                                <div class="cls-category style-abs abs-2 hover-img d-none d-xl-block">
                                    <a href='<%# BuildSettoreUrl(Eval("id")) %>' class="img-box img-style d-block">
                                        <img src='<%# GetSettoreImageLowUrl(Eval("Img")) %>' data-src='<%# GetSettoreImageLowUrl(Eval("Img")) %>' data-ks-fallback='<%# GetSettoreImageNormalUrl(Eval("Img")) %>' alt='<%# SafeText(Eval("Descrizione")) %>' class="lazyload ks-settore-image" />
                                    </a>
                                    <div class="content text-center">
                                        <div class="box-title">
                                            <h3 class="fw-bold text-uppercase">-60%</h3>
                                            <p class="product-title-2 text-uppercase"><%# SafeText(Eval("Descrizione")) %></p>
                                        </div>
                                        <div class="box-btn">
                                            <a href='<%# BuildSettoreUrl(Eval("id")) %>' class="tf-btn btn-line-white text-main d-inline-flex"><span>Shop now</span></a>
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
    <asp:SqlDataSource ID="sdsSettoriHome" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="MySql.Data.MySqlClient" SelectCommand="SELECT id, Descrizione, Img FROM settori WHERE COALESCE(Abilitato,1)=1 ORDER BY COALESCE(Predefinito,0) DESC, COALESCE(Ordinamento,0), Descrizione LIMIT 14" />
</div>