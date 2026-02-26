<%@ Page Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>
<%@ Register Src="~/Public/ui/controls/HomeSideBanners.ascx" TagPrefix="ks" TagName="HomeSideBanners" %>
<%@ Register Src="~/Public/ui/controls/HomeDepartmentsMenu.ascx" TagPrefix="ks" TagName="HomeDepartmentsMenu" %>
<%@ Register Src="~/Public/ui/controls/HomeHeroSlider.ascx" TagPrefix="ks" TagName="HomeHeroSlider" %>
<%@ Register Src="~/Public/ui/controls/HomeIconBoxes.ascx" TagPrefix="ks" TagName="HomeIconBoxes" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server"><%: Page.Title %></asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- ============================================================
         HERO / BANNERS (FULL-WIDTH)
         (Slider database-driven su Swiper, integrato nella posizione "wrap-item-2")
         ============================================================ -->

    <section class="tf-sp-5">
        <div class="container">
            <div class="s-banner-wrapper">

                <!-- LEFT: Departments -->
                <ks:HomeDepartmentsMenu runat="server" ID="HomeDepartmentsMenu1" />

                <!-- CENTER: Hero Slider -->
                <ks:HomeHeroSlider runat="server" ID="HomeHeroSlider1" />

                <!-- RIGHT: 2 banners dinamici (pubblicità id_posizione_banner=4 ordinamento 1 e 2) -->
                <ks:HomeSideBanners runat="server" ID="HomeSideBanners1" />


            </div>
        </div>
    </section>

    <!-- Icon boxes (template) -->
    <ks:HomeIconBoxes runat="server" ID="HomeIconBoxes1" />

    <!-- ============================================================
         SCELTI PER TE (vetrina)
         ============================================================ -->

    <% If Data_UltimiArrivi.Items.Count > 0 Then %>
    <section class="tf-sp-5">
        <div class="container">
            <div class="flat-title d-flex align-items-center justify-content-between flex-wrap gap-12">
                <h2 class="flat-title-heading">Scelti per te</h2>
            </div>

            <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile="2" data-space-lg="20" data-space-md="20" data-space="10" data-pagination="2" data-pagination-sm="2" data-pagination-md="3" data-pagination-lg="3">
                <div class="swiper-wrapper">

                    <asp:Repeater ID="Data_UltimiArrivi" runat="server" DataSourceID="SdsArticoliInVetrina">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <div class="card-product style-img-border">
                                    <div class="card-product-wrapper">
                                        <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="product-img">
                                            <img class="img-product lazyload"
                                                 src='<%# checkImg(Eval("img1")) %>'
                                                 data-src='<%# checkImg(Eval("img1")) %>'
                                                 alt='<%# SafeAttr(Eval("Descrizione1")) %>' />
                                            <img class="img-hover lazyload"
                                                 src='<%# checkImg(Eval("img1")) %>'
                                                 data-src='<%# checkImg(Eval("img1")) %>'
                                                 alt='<%# SafeAttr(Eval("Descrizione1")) %>' />
                                        </a>

                                        <!-- Badge sconto -->
                                        <div class="on-sale-wrap text-end" style='display:<%# controlla_promo(Eval("inOfferta")) %>;'>
                                            <span class="on-sale-item"><%# SafeText(sconto(Eval("ListinoUfficiale"), If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), Eval("iva"))) %></span>
                                        </div>
                                    </div>

                                    <div class="card-product-info">
                                        <div class="box-title">
                                            <div class="d-flex flex-column">
                                                <p class="caption text-main-2 font-2">Cod. <%# SafeText(Eval("Codice")) %></p>
                                                <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="name-product body-md-2 fw-semibold text-secondary link">
                                                    <%# SafeText(compatta_testo(Eval("Descrizione1"), 60)) %>
                                                </a>
                                            </div>
                                            <p class="price-wrap fw-medium">
                                                <span class="new-price price-text fw-medium">
                                                    <%# controlla_prezzo(
                                                            If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                                            If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                                            If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                                            If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                                            Session("IvaTipo")
                                                        ) %>
                                                </span>
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                </div>
                <div class="d-flex sw-dot-default sw-pagination-products justify-content-center"></div>
            </div>
        </div>

        <!-- DataSource (vetrina) - il comando viene sovrascritto in Default.aspx.vb -->
        <asp:SqlDataSource ID="SdsArticoliInVetrina" runat="server"
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="MySql.Data.MySqlClient"
            SelectCommand="SELECT * FROM documenti JOIN documentirighe ON documenti.id=documentirighe.`DocumentiId` WHERE documentirighe.`ArticoliId`>0 AND documenti.`TipoDocumentiId`=11 GROUP BY documentirighe.`ArticoliId` ORDER BY documenti.id DESC LIMIT 1">
        </asp:SqlDataSource>

    </section>
    <% End If %>

    <!-- ============================================================
         NOVITÀ (nuovi arrivi)
         ============================================================ -->

    <section class="tf-sp-5">
        <div class="container">
            <div class="flat-title d-flex align-items-center justify-content-between flex-wrap gap-12">
                <h2 class="flat-title-heading">Novità</h2>
            </div>

            <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile="2" data-space-lg="20" data-space-md="20" data-space="10" data-pagination="2" data-pagination-sm="2" data-pagination-md="3" data-pagination-lg="3">
                <div class="swiper-wrapper">

                    <asp:Repeater ID="Repeat_Lista_Nuovi_Arrivi" DataSourceID="SdsNewArticoli" runat="server">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <div class="card-product style-img-border">
                                    <div class="card-product-wrapper">
                                        <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="product-img">
                                            <img class="img-product lazyload"
                                                 src='<%# checkImg(Eval("img1")) %>'
                                                 data-src='<%# checkImg(Eval("img1")) %>'
                                                 alt='<%# SafeAttr(Eval("Descrizione1")) %>' />
                                            <img class="img-hover lazyload"
                                                 src='<%# checkImg(Eval("img1")) %>'
                                                 data-src='<%# checkImg(Eval("img1")) %>'
                                                 alt='<%# SafeAttr(Eval("Descrizione1")) %>' />
                                        </a>

                                        <div class="on-sale-wrap text-end" style='display:<%# controlla_promo(Eval("inOfferta")) %>;'>
                                            <span class="on-sale-item"><%# SafeText(sconto(Eval("ListinoUfficiale"), If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), Eval("iva"))) %></span>
                                        </div>
                                    </div>

                                    <div class="card-product-info">
                                        <div class="box-title">
                                            <div class="d-flex flex-column">
                                                <p class="caption text-main-2 font-2">Cod. <%# SafeText(Eval("Codice")) %></p>
                                                <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="name-product body-md-2 fw-semibold text-secondary link">
                                                    <%# SafeText(compatta_testo(Eval("Descrizione1"), 60)) %>
                                                </a>
                                            </div>
                                            <p class="price-wrap fw-medium">
                                                <span class="new-price price-text fw-medium">
                                                    <%# controlla_prezzo(
                                                            If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                                            If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                                            If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                                            If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                                            Session("IvaTipo")
                                                        ) %>
                                                </span>
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                </div>
                <div class="d-flex sw-dot-default sw-pagination-products justify-content-center"></div>
            </div>

            <!-- DataSource - comando sovrascritto in Default.aspx.vb -->
            <asp:SqlDataSource ID="SdsNewArticoli" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="MySql.Data.MySqlClient"
                SelectCommand="SELECT * FROM articoli LIMIT 1">
            </asp:SqlDataSource>

        </div>
    </section>

    <!-- ============================================================
         PIÙ VENDUTI
         ============================================================ -->

    <section class="tf-sp-5">
        <div class="container">
            <div class="flat-title d-flex align-items-center justify-content-between flex-wrap gap-12">
                <h2 class="flat-title-heading">I più venduti</h2>
            </div>

            <div class="swiper tf-sw-products" data-preview="5" data-tablet="4" data-mobile="2" data-space-lg="20" data-space-md="20" data-space="10" data-pagination="2" data-pagination-sm="2" data-pagination-md="3" data-pagination-lg="3">
                <div class="swiper-wrapper">

                    <asp:Repeater ID="DataList1" runat="server" DataSourceID="sdsPiuAcquistati">
                        <ItemTemplate>
                            <div class="swiper-slide">
                                <div class="card-product style-img-border">
                                    <div class="card-product-wrapper">
                                        <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="product-img">
                                            <img class="img-product lazyload"
                                                 src='<%# checkImg(Eval("img1")) %>'
                                                 data-src='<%# checkImg(Eval("img1")) %>'
                                                 alt='<%# SafeAttr(Eval("Descrizione1")) %>' />
                                            <img class="img-hover lazyload"
                                                 src='<%# checkImg(Eval("img1")) %>'
                                                 data-src='<%# checkImg(Eval("img1")) %>'
                                                 alt='<%# SafeAttr(Eval("Descrizione1")) %>' />
                                        </a>

                                        <div class="on-sale-wrap text-end" style='display:<%# controlla_promo(Eval("inOfferta")) %>;'>
                                            <span class="on-sale-item"><%# SafeText(sconto(Eval("ListinoUfficiale"), If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), Eval("iva"))) %></span>
                                        </div>
                                    </div>

                                    <div class="card-product-info">
                                        <div class="box-title">
                                            <div class="d-flex flex-column">
                                                <p class="caption text-main-2 font-2">Cod. <%# SafeText(Eval("Codice")) %></p>
                                                <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="name-product body-md-2 fw-semibold text-secondary link">
                                                    <%# SafeText(compatta_testo(Eval("Descrizione1"), 60)) %>
                                                </a>
                                            </div>
                                            <p class="price-wrap fw-medium">
                                                <span class="new-price price-text fw-medium">
                                                    <%# controlla_prezzo(
                                                            If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                                            If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                                            If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                                            If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                                            Session("IvaTipo")
                                                        ) %>
                                                </span>
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                </div>
                <div class="d-flex sw-dot-default sw-pagination-products justify-content-center"></div>
            </div>

            <asp:SqlDataSource ID="sdsPiuAcquistati" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="MySql.Data.MySqlClient"
                SelectCommand="SELECT * FROM documenti LIMIT 1">
            </asp:SqlDataSource>

        </div>
    </section>

    <!-- ============================================================
         BRAND (marche random)
         ============================================================ -->

    <section class="tf-sp-5">
        <div class="container">
            <div class="flat-title d-flex align-items-center justify-content-between flex-wrap gap-12">
                <h2 class="flat-title-heading">Rivenditori ufficiali - I nostri brand</h2>
            </div>

            <div class="row align-items-center g-3">
                <asp:Repeater ID="MarcheRandom" runat="server" DataSourceID="sdsMarcheRandom">
                    <ItemTemplate>
                        <div class="col-6 col-md-2">
                            <a class="d-block" href='<%# "articoli.aspx?ct=30000&mr=" & Eval("id") %>'>
                                <img class="lazyload"
                                     src='<%# ResolveUrl("~/Public/Marche/" & Convert.ToString(Eval("img"))) %>'
                                     data-src='<%# ResolveUrl("~/Public/Marche/" & Convert.ToString(Eval("img"))) %>'
                                     style="width:100%; max-width:150px;"
                                     alt='<%# SafeAttr(Eval("Descrizione")) %>'
                                     title='<%# SafeAttr(Eval("Descrizione")) %>' />
                            </a>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>

            <asp:SqlDataSource ID="sdsMarcheRandom" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="MySql.Data.MySqlClient"
                SelectCommand="SELECT * FROM marche WHERE (Abilitato=1) AND (img is not NULL) ORDER BY RAND() LIMIT 6">
            </asp:SqlDataSource>
        </div>
    </section>

    <!-- Nota prezzi -->
    <section class="tf-sp-5">
        <div class="container">
            <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" CssClass="body-text-3" />
        </div>
    </section>


    

</asp:Content>

<asp:Content ID="ScriptsHome" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="<%= ThemeManager.Asset("js/home-slideshow.js") %>"></script>
</asp:Content>
