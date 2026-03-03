<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeDepartmentsMenu.ascx.vb" Inherits="UI_HomeDepartmentsMenu" %>

<!-- LEFT: Departments (Home) -->
<div class="wrap-item-1 d-none d-xl-block ks-home-departments">
    <div class="tf-nav-menu">
        <div class="main-nav">
            <h6 class="fw-semibold title">
                <i class="icon-menu-dots"></i>
                Dipartimenti
            </h6>

            <ul class="menu-category-list">
                <asp:Repeater ID="rptHeroCats" runat="server" DataSourceID="SdsHeroCats" EnableViewState="False">
                    <ItemTemplate>
                        <li class="menu-item">
                            <a href='<%# BuildSettoreUrl(Eval("id"), Eval("DefaultCt"), Eval("DefaultTp")) %>' class="item-link body-text-3">
                                <span>
                                    <i class="icon icon-categories"></i>
                                    <%# SafeText(Eval("descrizione")) %>
                                </span>
                            </a>
                        </li>
                    </ItemTemplate>
                </asp:Repeater>
            </ul>

            <asp:SqlDataSource ID="SdsHeroCats" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="MySql.Data.MySqlClient"
                SelectCommand="SELECT s.id, s.Descrizione AS descrizione, s.Img, (SELECT c.id FROM categorie c WHERE c.SettoriId = s.id AND c.Abilitato = 1 ORDER BY c.Ordinamento, c.Descrizione, c.id LIMIT 1) AS DefaultCt, (SELECT t.id FROM tipologie t WHERE t.CategorieId = (SELECT c2.id FROM categorie c2 WHERE c2.SettoriId = s.id AND c2.Abilitato = 1 ORDER BY c2.Ordinamento, c2.Descrizione, c2.id LIMIT 1) AND t.Abilitato = 1 ORDER BY t.Ordinamento, t.Descrizione, t.id LIMIT 1) AS DefaultTp FROM settori s WHERE s.Abilitato = 1 ORDER BY s.Predefinito DESC, s.Ordinamento, s.Descrizione, s.id">
            </asp:SqlDataSource>

        </div>
    </div>
</div>
