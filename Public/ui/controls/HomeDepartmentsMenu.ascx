<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeDepartmentsMenu.ascx.vb" Inherits="UI_HomeDepartmentsMenu" %>
<div class="tf-nav-menu active-container ks-home-departments">
    <div class="main-nav">
        <h6 class="fw-semibold title btn-active">
            <i class="icon-menu-dots"></i>
            Tutti i reparti
        </h6>
        <ul class="menu-category-list active-item">
            <asp:Repeater ID="rptSettoriHome" runat="server" DataSourceID="sdsSettoriHome">
                <ItemTemplate>
                    <li class="menu-item">
                        <a href='<%# "articoli.aspx?st=" & Eval("id") %>' class="item-link body-text-3">
                            <span>
                                <i class="icon icon-monitor"></i>
                                <%# SafeText(Eval("Descrizione")) %>
                            </span>
                        </a>
                        <div class="sub-menu-container d-flex">
                            <div class="wrapper-sub-menu flex-grow-1">
                                <div class="grid-sub-menu">
                                    <asp:Repeater ID="rptCategorieHome" runat="server" DataSourceID="sdsCategorieHome">
                                        <ItemTemplate>
                                            <div class="sub-nav-link">
                                                <a class="sub-menu-link body-text-3 link fw-semibold" href='<%# "articoli.aspx?st=" & Eval("SettoriId") & "&ct=" & Eval("id") %>'><%# SafeText(Eval("Descrizione")) %></a>
                                                <ul class="list-unstyled">
                                                    <asp:Repeater ID="rptTipologieHome" runat="server" DataSourceID="sdsTipologieHome">
                                                        <ItemTemplate>
                                                            <li class="sub-menu-item">
                                                                <a class="body-text-3 link" href='<%# "articoli.aspx?st=" & Eval("SettoriId") & "&ct=" & Eval("CategorieId") & "&tp=" & Eval("id") %>'><%# SafeText(Eval("Descrizione")) %></a>
                                                            </li>
                                                        </ItemTemplate>
                                                    </asp:Repeater>
                                                    <asp:SqlDataSource ID="sdsTipologieHome" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="MySql.Data.MySqlClient" SelectCommand='<%# "SELECT t.id, t.CategorieId, c.SettoriId, t.Descrizione FROM tipologie t INNER JOIN categorie c ON c.id = t.CategorieId WHERE COALESCE(t.Abilitato,1)=1 AND t.CategorieId=" & Eval("id") & " ORDER BY COALESCE(t.Ordinamento,0), t.Descrizione LIMIT 12" %>' />
                                                </ul>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                    <asp:SqlDataSource ID="sdsCategorieHome" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="MySql.Data.MySqlClient" SelectCommand='<%# "SELECT id, SettoriId, Descrizione FROM categorie WHERE COALESCE(Abilitato,1)=1 AND SettoriId=" & Eval("id") & " ORDER BY COALESCE(Ordinamento,0), Descrizione LIMIT 12" %>' />
                                </div>
                            </div>
                            <div class="cls-category style-abs abs-2 hover-img d-none d-xl-block">
                                <a href='<%# "articoli.aspx?st=" & Eval("id") %>' class="img-box img-style d-block">
                                    <img src="<%= ResolveUrl("~/Public/assets/images/item/camera-3.webp") %>" data-src="<%= ResolveUrl("~/Public/assets/images/item/camera-3.webp") %>" alt="reparto" class="lazyload">
                                </a>
                                <div class="content text-center">
                                    <div class="box-title">
                                        <h3 class="fw-bold text-uppercase">KeepStore</h3>
                                        <p class="product-title-2 text-uppercase"><%# SafeText(Eval("Descrizione")) %></p>
                                    </div>
                                    <div class="box-btn">
                                        <a href='<%# "articoli.aspx?st=" & Eval("id") %>' class="tf-btn btn-line-white text-main d-inline-flex">
                                            <span>Esplora</span>
                                            <i class="icon-circle-chevron-right"></i>
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
    <asp:SqlDataSource ID="sdsSettoriHome" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="MySql.Data.MySqlClient" SelectCommand="SELECT id, Descrizione FROM settori WHERE COALESCE(Abilitato,1)=1 ORDER BY COALESCE(Predefinito,0) DESC, COALESCE(Ordinamento,0), Descrizione LIMIT 14" />
</div>
<style type="text/css">
.ks-home-departments .main-nav > .title { cursor: pointer; }
.ks-home-departments .menu-item { position: relative; }
.ks-home-departments .menu-item > .sub-menu-container { display: none; z-index: 30; }
@media (min-width: 1200px) {
    .ks-home-departments .menu-category-list { max-height: none !important; overflow: visible !important; }
    .ks-home-departments .menu-item:hover > .sub-menu-container,
    .ks-home-departments .menu-item.open > .sub-menu-container,
    .ks-home-departments .menu-item:focus-within > .sub-menu-container { display: flex !important; }
}
.ks-home-departments .menu-category-list { max-height: 560px; overflow: auto; }
.ks-home-departments .grid-sub-menu { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px 28px; }
.ks-home-departments .sub-nav-link > ul { margin-top: 10px; }
.ks-home-departments .sub-nav-link li + li { margin-top: 6px; }
.ks-home-departments .cls-category .img-box { max-width: 230px; margin: 0 auto; }
@media (max-width: 1199px) {
    .ks-home-departments .menu-category-list { display: none; max-height: none; }
    .ks-home-departments .menu-category-list.active-item { display: block; }
    .ks-home-departments .sub-menu-container { position: static; display: none; margin-top: 12px; padding: 16px; background: #fff; border-radius: 18px; box-shadow: 0 12px 30px rgba(0,0,0,.08); }
    .ks-home-departments .menu-item.open > .sub-menu-container { display: block; }
    .ks-home-departments .grid-sub-menu { grid-template-columns: 1fr; }
}
</style>
<script type="text/javascript">
(function () {
    document.addEventListener('DOMContentLoaded', function () {
        var root = document.querySelector('.ks-home-departments');
        if (!root) return;
        var title = root.querySelector('.title.btn-active');
        var list = root.querySelector('.menu-category-list');
        if (title && list) {
            title.addEventListener('click', function (ev) {
                if (window.innerWidth > 1199) return;
                ev.preventDefault();
                list.classList.toggle('active-item');
                title.classList.toggle('active');
            });
        }
        function openDesktopItem(item) {
            if (!item || window.innerWidth <= 1199) return;
            root.querySelectorAll('.menu-item.open').forEach(function (other) { if (other !== item) other.classList.remove('open'); });
            item.classList.add('open');
        }
        function closeDesktopItems() {
            if (window.innerWidth <= 1199) return;
            root.querySelectorAll('.menu-item.open').forEach(function (item) { item.classList.remove('open'); });
        }
        root.querySelectorAll('.menu-item').forEach(function (item) {
            item.addEventListener('mouseenter', function () { openDesktopItem(item); });
            item.addEventListener('mouseover', function () { openDesktopItem(item); });
            var trigger = item.querySelector('.item-link');
            if (trigger) {
                trigger.addEventListener('mousemove', function () { openDesktopItem(item); });
                trigger.addEventListener('focus', function () { openDesktopItem(item); });
            }
            var sub = item.querySelector('.sub-menu-container');
            if (sub) {
                sub.addEventListener('mouseenter', function () { openDesktopItem(item); });
            }
        });
        root.addEventListener('mouseleave', function () { closeDesktopItems(); });
        root.querySelectorAll('.menu-item > .item-link').forEach(function (link) {
            link.addEventListener('click', function (ev) {
                if (window.innerWidth > 1199) return;
                var parent = link.closest('.menu-item');
                var sub = parent ? parent.querySelector('.sub-menu-container') : null;
                if (!sub) return;
                ev.preventDefault();
                parent.classList.toggle('open');
            });
        });
    });
})();
</script>
