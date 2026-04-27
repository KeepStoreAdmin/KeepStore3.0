<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeDepartmentsMenu.ascx.vb" Inherits="UI_HomeDepartmentsMenu" %>
<style id="ks-home-menu-runtime-style">
.ks-home-departments{position:relative;z-index:300;overflow:visible;}
.ks-home-departments .main-nav,.ks-home-departments .menu-category-list{position:relative;overflow:visible;}
.ks-home-departments .menu-item{position:static;}
.ks-home-departments [data-ks-submenu="1"],.ks-home-departments [data-ks-submenu="1"][hidden]{display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;max-height:0!important;overflow:hidden!important;}
.ks-home-departments .ks-home-submenu-container{z-index:4000;}
.ks-home-departments .ks-menu-media{display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;min-width:28px;overflow:hidden;border-radius:8px;background:#fff;}
.ks-home-departments .ks-menu-media img{display:block;max-width:100%;max-height:100%;object-fit:contain;}
.ks-home-departments .ks-menu-media.is-empty img{display:none!important;}
.ks-home-departments .ks-menu-media-fallback,.ks-home-departments .ks-menu-media-placeholder{display:inline-flex;align-items:center;justify-content:center;width:100%;height:100%;border-radius:8px;background:#f4f6f8;color:#6b7785;font-size:11px;font-weight:700;text-transform:uppercase;}
.ks-home-departments .ks-menu-media.has-image .ks-menu-media-fallback{display:none!important;}
.ks-home-departments .ks-home-sector-promo{position:relative!important;inset:auto!important;left:auto!important;right:auto!important;top:auto!important;bottom:auto!important;transform:none!important;flex:0 0 240px;max-width:240px;overflow:hidden;margin-left:0;}
.ks-home-departments .ks-home-submenu-grid{flex:1 1 auto;min-width:0;}
.ks-home-departments .ks-home-sector-promo[data-ks-hidden="1"]{display:none!important;}
@media (min-width:1200px){
  .ks-home-departments .main-nav{max-height:520px!important;overflow:visible!important;}
  .ks-home-departments .menu-category-list{max-height:468px!important;overflow-y:auto!important;overflow-x:hidden!important;}
  .ks-home-departments .menu-category-list::-webkit-scrollbar,.ks-home-departments .ks-home-submenu-container::-webkit-scrollbar{width:6px!important;}
  .ks-home-departments .menu-category-list::-webkit-scrollbar-thumb,.ks-home-departments .ks-home-submenu-container::-webkit-scrollbar-thumb{background:#b8c0cc!important;border-radius:999px!important;}
  .ks-home-departments .ks-menu-toggle{display:none!important;}
  .ks-home-departments .ks-home-menu-row{min-height:56px!important;display:flex!important;align-items:center!important;}
  .ks-home-departments .item-link{flex:1 1 auto!important;min-width:0!important;}
  .ks-home-departments .ks-home-menu-link{display:flex!important;align-items:center!important;gap:12px!important;width:100%!important;min-width:0!important;}
  .ks-home-departments .ks-menu-label{flex:1 1 auto!important;min-width:0!important;overflow:hidden!important;text-overflow:ellipsis!important;white-space:nowrap!important;}
  .ks-home-departments .ks-menu-arrow{margin-left:auto!important;display:inline-flex!important;align-items:center!important;color:#303846!important;}
  .ks-home-departments .ks-home-submenu-container{position:absolute!important;top:0!important;left:100%!important;min-width:820px!important;max-width:min(1040px,calc(100vw - 520px))!important;width:min(960px,calc(100vw - 520px))!important;max-height:min(560px,calc(100vh - 140px))!important;overflow:auto!important;background:#fff!important;white-space:normal!important;box-shadow:0 22px 54px rgba(15,23,42,.14)!important;border:1px solid #edf1f6!important;border-radius:0 12px 12px 12px!important;}
  .ks-home-departments .ks-home-submenu-grid{display:grid!important;grid-template-columns:repeat(4,minmax(175px,1fr))!important;gap:28px 30px!important;padding:32px!important;align-items:start!important;align-content:start!important;min-width:0!important;}
  .ks-home-departments .ks-home-submenu-col{display:block!important;min-width:0!important;width:100%!important;}
  .ks-home-departments .ks-home-submenu-tipology-list{display:grid!important;gap:6px!important;margin-top:8px!important;padding-left:0!important;}
  .ks-home-departments .ks-home-submenu-tipology,.ks-home-departments .ks-home-submenu-tipology-link{display:block!important;min-width:0!important;white-space:normal!important;}
  .ks-home-departments .ks-home-submenu-category{display:block!important;white-space:normal!important;font-weight:800!important;line-height:1.25!important;margin:0 0 8px!important;}
  .ks-home-departments .ks-home-submenu-more{display:inline-flex!important;margin-top:8px!important;font-size:12px!important;font-weight:800!important;color:#ef4444!important;}
  .ks-home-departments .ks-home-submenu-view-all{border:1px solid #eef1f5!important;border-radius:10px!important;padding:14px!important;background:#f8fafc!important;}
  .ks-home-departments .ks-home-submenu-view-all span{display:block!important;margin-top:6px!important;font-size:12px!important;color:#64748b!important;}
  .ks-home-departments .menu-item:hover > [data-ks-submenu="1"],
  .ks-home-departments .menu-item:focus-within > [data-ks-submenu="1"],
  .ks-home-departments .menu-item.is-hover > [data-ks-submenu="1"],
  .ks-home-departments .menu-item.is-open > [data-ks-submenu="1"]{display:block!important;visibility:visible!important;opacity:1!important;pointer-events:auto!important;max-height:430px!important;overflow:auto!important;}
  .ks-home-departments .menu-item[data-ks-submenu-mode="list"]:hover > [data-ks-submenu="1"],
  .ks-home-departments .menu-item[data-ks-submenu-mode="list"]:focus-within > [data-ks-submenu="1"],
  .ks-home-departments .menu-item[data-ks-submenu-mode="list"].is-hover > [data-ks-submenu="1"],
  .ks-home-departments .menu-item[data-ks-submenu-mode="list"].is-open > [data-ks-submenu="1"]{display:block!important;visibility:visible!important;opacity:1!important;pointer-events:auto!important;max-height:430px!important;overflow:auto!important;}
}
@media (max-width:1199.98px){
  .ks-home-departments .menu-item[data-ks-open="1"] > [data-ks-submenu="1"]{display:flex!important;visibility:visible!important;opacity:1!important;pointer-events:auto!important;max-height:none!important;overflow:visible!important;}
  .ks-home-departments .menu-item[data-ks-submenu-mode="list"][data-ks-open="1"] > [data-ks-submenu="1"]{display:block!important;visibility:visible!important;opacity:1!important;pointer-events:auto!important;max-height:none!important;overflow:visible!important;}
}
</style>
<div class="nav-category-wrap tf-nav-menu ks-home-departments" data-ks-home-menu="1">
    <div class="main-nav category-menu active-item">
        <h6 class="fw-semibold title nav-title btn-active">
            <i class="icon-menu-dots"></i>
            <span data-ks-i18n="nav.departments">Tutti i settori</span>
        </h6>
        <ul class="menu-category-list megamenu" role="menu">
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
                            <button id="toggleButton" runat="server" type="button" class="ks-menu-toggle" aria-expanded="false" aria-label="Apri sottomenu" data-ks-toggle="1">
                                <i class="icon-arrow-right-lg"></i>
                            </button>
                        </div>
                        <div id="subMenuContainer" runat="server" class="sub-menu-container d-flex ks-home-submenu-container" aria-hidden="true" data-ks-submenu="1" data-ks-inline-state="closed">
                            <div class="sub-menu-grid ks-home-submenu-grid">
                                <asp:Literal ID="litDesktopSubmenu" runat="server" />
                            </div>
                            <div id="promoCard" runat="server" class="cls-category hover-img d-none d-xl-block ks-home-sector-promo" data-ks-sector-promo="1">
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
