<%@ Page Title="Home" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>

<%@ Register Src="~/Public/ui/controls/HomeDepartmentsMenu.ascx" TagPrefix="ks" TagName="HomeDepartmentsMenu" %>
<%@ Register Src="~/Public/ui/controls/HomeHeroSlider.ascx" TagPrefix="ks" TagName="HomeHeroSlider" %>
<%@ Register Src="~/Public/ui/controls/HomeSideBanners.ascx" TagPrefix="ks" TagName="HomeSideBanners" %>
<%@ Register Src="~/Public/ui/controls/HomeIconBoxes.ascx" TagPrefix="ks" TagName="HomeIconBoxes" %>

<asp:Content ID="Content1" ContentPlaceHolderID="TitleContent" runat="Server">
    Home
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="HeadContent" runat="Server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="MainContent" runat="Server">

    <!-- HERO (Home 1) -->
    <section class="tf-sp-5">
        <div class="container">
            <div class="row">
                <div class="col-lg-3 d-none d-lg-block">
                    <ks:HomeDepartmentsMenu ID="HomeDepartmentsMenu1" runat="server" />
                </div>

                <div class="col-lg-6">
                    <ks:HomeHeroSlider ID="HomeHeroSlider1" runat="server" />
                </div>

                <div class="col-lg-3 d-none d-lg-block">
                    <ks:HomeSideBanners ID="HomeSideBanners1" runat="server" />
                </div>
            </div>
        </div>
    </section>

    <!-- ICON BOXES -->
    <section class="tf-sp-2">
        <div class="container">
            <ks:HomeIconBoxes ID="HomeIconBoxes1" runat="server" />
        </div>
    </section>

    <!-- FEATURED / VETRINA -->
    <section class="tf-sp-2">
        <div class="container">
            <div class="tf-section-heading">
                <h3 class="heading">In vetrina</h3>
                <a href="/articoli.aspx" class="link">Vedi tutto</a>
            </div>

            <div class="tf-grid-layout md-col-4">
                <asp:Repeater ID="rptVetrina" runat="server" DataSourceID="SdsArticoliInVetrina">
                    <ItemTemplate>
                        <div class="card-product style-1">
                            <div class="card-product-wrapper">
                                <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                                         src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
                                </a>

                                <%# If(Val(Eval("InOfferta")) = 1, "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", "") %>
                            </div>

                            <div class="card-product-info">
                                <a class="name-product link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                </a>

                                <div class="price-wrap">
                                    <%# UiPriceFormatter.RenderPriceHtml(
                                            If(IsDBNull(Eval("Prezzo")), 0, Eval("Prezzo")),
                                            If(IsDBNull(Eval("PrezzoIvato")), 0, Eval("PrezzoIvato")),
                                            If(Val(Eval("InOfferta")) = 1, If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), 0),
                                            If(Val(Eval("InOfferta")) = 1, If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), 0),
                                            Session("IvaTipo")
                                        ) %>
                                </div>
                            </div>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </div>
    </section>

    <!-- NEW ARRIVALS -->
    <section class="tf-sp-2">
        <div class="container">
            <div class="tf-section-heading">
                <h3 class="heading">Novità</h3>
                <a href="/articoli.aspx" class="link">Vedi tutto</a>
            </div>

            <div class="tf-grid-layout md-col-4">
                <asp:Repeater ID="rptNewArrivals" runat="server" DataSourceID="SdsNewArticoli">
                    <ItemTemplate>
                        <div class="card-product style-1">
                            <div class="card-product-wrapper">
                                <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                                         src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
                                </a>

                                <%# If(Val(Eval("InOfferta")) = 1, "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", "") %>
                            </div>

                            <div class="card-product-info">
                                <a class="name-product link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                </a>

                                <div class="price-wrap">
                                    <%# UiPriceFormatter.RenderPriceHtml(
                                            If(IsDBNull(Eval("Prezzo")), 0, Eval("Prezzo")),
                                            If(IsDBNull(Eval("PrezzoIvato")), 0, Eval("PrezzoIvato")),
                                            If(Val(Eval("InOfferta")) = 1, If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), 0),
                                            If(Val(Eval("InOfferta")) = 1, If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), 0),
                                            Session("IvaTipo")
                                        ) %>
                                </div>
                            </div>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </div>
    </section>

    <!-- BEST SELLERS -->
    <section class="tf-sp-2">
        <div class="container">
            <div class="tf-section-heading">
                <h3 class="heading">Più venduti</h3>
                <a href="/articoli.aspx" class="link">Vedi tutto</a>
            </div>

            <div class="tf-grid-layout md-col-4">
                <asp:Repeater ID="rptBestSellers" runat="server" DataSourceID="sdsPiuAcquistati">
                    <ItemTemplate>
                        <div class="card-product style-1">
                            <div class="card-product-wrapper">
                                <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                                         src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
                                </a>

                                <%# If(Val(Eval("InOfferta")) = 1, "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", "") %>
                            </div>

                            <div class="card-product-info">
                                <a class="name-product link" href='<%# "articolo.aspx?id=" & Eval("Articoliid") %>'>
                                    <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                                </a>

                                <div class="price-wrap">
                                    <%# UiPriceFormatter.RenderPriceHtml(
                                            If(IsDBNull(Eval("Prezzo")), 0, Eval("Prezzo")),
                                            If(IsDBNull(Eval("PrezzoIvato")), 0, Eval("PrezzoIvato")),
                                            If(Val(Eval("InOfferta")) = 1, If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), 0),
                                            If(Val(Eval("InOfferta")) = 1, If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), 0),
                                            Session("IvaTipo")
                                        ) %>
                                </div>
                            </div>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>

            <div class="mt-3 text-muted small">
                <asp:Label ID="lblPrezzi" runat="server" />
            </div>
        </div>
    </section>

    <!-- DATA SOURCES (filled by Default.aspx.vb, safe defaults when not set) -->
    <asp:SqlDataSource ID="SdsArticoliInVetrina" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT 0 as Articoliid, 0 as TCId, '' as Codice, '' as Ean, '' as Descrizione1, '' as img1, 0 as Prezzo, 0 as PrezzoIvato, 0 as InOfferta, 0 as PrezzoPromo, 0 as PrezzoPromoIvato WHERE 1=0" />

    <asp:SqlDataSource ID="SdsNewArticoli" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT 0 as Articoliid, 0 as TCId, '' as Codice, '' as Ean, '' as Descrizione1, '' as img1, 0 as Prezzo, 0 as PrezzoIvato, 0 as InOfferta, 0 as PrezzoPromo, 0 as PrezzoPromoIvato WHERE 1=0" />

    <asp:SqlDataSource ID="sdsPiuAcquistati" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT 0 as Articoliid, 0 as TCId, '' as Codice, '' as Ean, '' as Descrizione1, '' as img1, 0 as Conteggio_Vendite, 0 as Prezzo, 0 as PrezzoIvato, 0 as InOfferta, 0 as PrezzoPromo, 0 as PrezzoPromoIvato WHERE 1=0" />

</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="ScriptsContent" runat="Server">
</asp:Content>
