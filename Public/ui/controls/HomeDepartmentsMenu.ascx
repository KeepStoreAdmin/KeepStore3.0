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
                        <div class="sub-menu-container">
                            <div class="wrapper-sub-menu flex-grow-1">
                                <div class="grid-sub-menu">
                                    <asp:Repeater ID="rptCategorieHome" runat="server" DataSourceID="sdsCategorieHome">
                                        <ItemTemplate>
                                            <div class="sub-nav-link">
                                                <a class="sub-menu-link body-text-3 link fw-semibold" href='<%# "articoli.aspx?st=" & Eval("SettoriId") & "&ct=" & Eval("id") %>'><%# SafeText(Eval("Descrizione")) %></a>
                                                <ul class="list-unstyled sub-menu-list">
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
                                    <img src='<%# GetSettoreImageUrl(Eval("Img")) %>' data-src='<%# GetSettoreImageUrl(Eval("Img")) %>' alt='<%# SafeText(Eval("Descrizione")) %>' class="lazyload">
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
    <asp:SqlDataSource ID="sdsSettoriHome" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="MySql.Data.MySqlClient" SelectCommand="SELECT id, Descrizione, Img FROM settori WHERE COALESCE(Abilitato,1)=1 ORDER BY COALESCE(Predefinito,0) DESC, COALESCE(Ordinamento,0), Descrizione LIMIT 14" />
</div>
<style type="text/css">
.ks-home-departments { position: relative; z-index: 35; }
.ks-home-departments .main-nav { position: relative; overflow: visible !important; }
.ks-home-departments .title { cursor: pointer; }
.ks-home-departments .menu-category-list { border: 1px solid var(--gray-5, #e5e7eb); border-top: 0; border-radius: 0 0 10px 10px; position: relative; max-height: none; overflow: visible !important; overflow-x: visible !important; overflow-y: visible !important; background: #fff; }
.ks-home-departments .menu-item { position: relative; }
.ks-home-departments .item-link { padding: 0 18px; position: relative; display: flex; }
.ks-home-departments .item-link > span { padding: 15px 0 14px; display: flex; gap: 6px; align-items: center; width: 100%; position: relative; }
.ks-home-departments .item-link::after { content: "\e919"; position: absolute; font-family: "icomoon"; right: 18px; top: 50%; transform: translateY(-50%); }
.ks-home-departments .menu-item:not(:last-child) .item-link > span { border-bottom: 1px solid var(--line-2, #ececec); }
.ks-home-departments .menu-item:hover .item-link { color: var(--primary); }
.ks-home-departments .sub-menu-container { position: absolute; top: 0; left: calc(100% - 1px); min-width: 780px; width: min(980px, calc(100vw - 360px)); display: flex; box-shadow: 0 12px 36px rgba(0,0,0,.12); border: 1px solid var(--gray-5, #e5e7eb); border-radius: 10px; pointer-events: none; opacity: 0; visibility: hidden; transition: all .22s ease-in-out; transform: translateY(10px); z-index: 9999; background-color: #fff; }
.ks-home-departments .menu-item:hover > .sub-menu-container,
.ks-home-departments .menu-item.open > .sub-menu-container,
.ks-home-departments .menu-item:focus-within > .sub-menu-container { transform: translateY(0); opacity: 1; visibility: visible; pointer-events: auto; }
.ks-home-departments .wrapper-sub-menu { padding: 30px; }
.ks-home-departments .grid-sub-menu { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px 28px; }
.ks-home-departments .sub-menu-list { display: flex; flex-direction: column; gap: 8px; margin-top: 10px; }
.ks-home-departments .cls-category .img-box { max-width: 230px; margin: 0 auto; }
.ks-home-departments .cls-category .img-box img { width: 100%; height: auto; object-fit: contain; }
@media (max-width: 1399px) {
    .ks-home-departments .sub-menu-container { min-width: 680px; }
}
@media (max-width: 1199px) {
    .ks-home-departments .menu-category-list { display: none; max-height: none; overflow: visible; }
    .ks-home-departments .menu-category-list.active-item { display: block; }
    .ks-home-departments .sub-menu-container { position: static; min-width: 0; width: 100%; display: none; margin-top: 12px; padding: 0; opacity: 1; visibility: visible; pointer-events: auto; transform: none; box-shadow: 0 12px 30px rgba(0,0,0,.08); }
    .ks-home-departments .menu-item.open > .sub-menu-container { display: block; }
    .ks-home-departments .wrapper-sub-menu { padding: 18px; }
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
        function isDesktop(){ return window.innerWidth > 1199; }
        if (title && list) {
            title.addEventListener('click', function (ev) {
                if (isDesktop()) return;
                ev.preventDefault();
                list.classList.toggle('active-item');
                title.classList.toggle('active');
            });
        }
        var closeTimer = 0;
        function openItem(item) {
            clearTimeout(closeTimer);
            root.querySelectorAll('.menu-item.open').forEach(function (other) { if (other !== item) other.classList.remove('open'); });
            item.classList.add('open');
        }
        function closeItem(item) {
            clearTimeout(closeTimer);
            closeTimer = setTimeout(function () { item.classList.remove('open'); }, 120);
        }
        root.querySelectorAll('.menu-item').forEach(function (item) {
            var trigger = item.querySelector(':scope > .item-link');
            var sub = item.querySelector(':scope > .sub-menu-container');
            if (!trigger || !sub) return;
            item.addEventListener('pointerenter', function () { if (isDesktop()) openItem(item); });
            item.addEventListener('mouseenter', function () { if (isDesktop()) openItem(item); });
            item.addEventListener('mouseleave', function () { if (isDesktop()) closeItem(item); });
            sub.addEventListener('mouseenter', function () { if (isDesktop()) openItem(item); });
            sub.addEventListener('mouseleave', function () { if (isDesktop()) closeItem(item); });
            trigger.addEventListener('focus', function () { if (isDesktop()) openItem(item); });
            trigger.addEventListener('mouseover', function () { if (isDesktop()) openItem(item); });
            trigger.addEventListener('click', function (ev) {
                if (isDesktop()) return;
                ev.preventDefault();
                root.querySelectorAll('.menu-item.open').forEach(function (other) { if (other !== item) other.classList.remove('open'); });
                item.classList.toggle('open');
            });
        });
    });
})();
</script>
