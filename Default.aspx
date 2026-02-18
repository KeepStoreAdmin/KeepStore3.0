<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server"><%: Page.Title %></asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- ============================================================
         HERO / BANNERS (FULL-WIDTH)
         (Slideshow legacy integrato nella posizione "wrap-item-2")
         ============================================================ -->

    <section class="tf-sp-5">
        <div class="container">
            <div class="s-banner-wrapper">

                <!-- LEFT: Department (Home 1) -->
                <div class="wrap-item-1 d-none d-lg-block">
                    <div class="tf-nav-menu">
                        <div class="main-nav">
                            <h6 class="fw-semibold title">
                                <i class="icon-menu-dots"></i>
                                Dipartimenti
                            </h6>

                            <ul class="menu-category-list">
                                <asp:Repeater ID="rptHeroCats" runat="server" DataSourceID="SdsHeroCats">
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

                    <!-- Small promo banner -->
                    <div class="banner-image-product-4 hover-img mb-20">
                        <div class="item-product">
                            <a href="articoli.aspx" class="box-link">
                                <div class="box-content">
                                    <span class="sub-title">Promo</span>
                                    <h5 class="title">Offerte del momento</h5>
                                    <p class="price fw-semibold">Scopri</p>
                                </div>
                                <div class="box-image">
                                    <img src='<%= ThemeManager.Asset("images/banner/banner-12.jpg") %>' alt="" onerror="this.style.display='none'" />
                                </div>
                            </a>
                        </div>
                    </div>
                </div>

                <!-- CENTER: Slideshow (dinamico) -->
                <div class="wrap-item-2">
                    <div class="banner-image-product-4 style-2 hover-img">
                        <div class="item-product">

                            <!-- Slide Show (legacy) -->
                            <div id="Slide_Show">

                                <asp:SqlDataSource 
                                    ID="slideShow" 
                                    runat="server"
                                    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                    ProviderName="MySql.Data.MySqlClient"
                                    SelectCommand="
                                        SELECT 
                                            sp.id,
                                            sp.slideshowId,
                                            sp.orderPosition,
                                            sp.image,
                                            sp.link,
                                            IFNULL(sp.caption,'') AS content,
                                            '' AS target
                                        FROM slideshows_parts sp
                                        WHERE sp.slideshowId = (
                                            SELECT MAX(id) 
                                            FROM slideshows 
                                            WHERE placeholder = 'defaultPage'
                                              AND aziendeId = @AziendaID
                                        )
                                        AND (CASE 
                                                WHEN sp.startDate IS NULL OR CAST(sp.startDate AS CHAR(10)) = '0000-00-00' 
                                                THEN DATE('1900-01-01') 
                                                ELSE sp.startDate 
                                             END) <= CURDATE()
                                        AND (CASE 
                                                WHEN sp.stopDate IS NULL OR CAST(sp.stopDate AS CHAR(10)) = '0000-00-00' 
                                                THEN DATE('2999-12-31') 
                                                ELSE sp.stopDate 
                                             END) > CURDATE()
                                        ORDER BY sp.orderPosition
                                    ">
                                    <SelectParameters>
                                        <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" Type="Int32" DefaultValue="1" />
                                    </SelectParameters>
                                </asp:SqlDataSource>

                                <div id="Slide_Show_Container" class="slideshow-container" runat="server">
                                    <asp:Repeater ID="slideshowItems" runat="server" DataSourceID="slideShow">
                                        <ItemTemplate>
                                            <% incrementa_slides() %>
                                            <div class="mySlides fade">
                                                <%# SlideLinkStart(Eval("link")) %>
                                                <img class="lazyload" src='<%# SafeSlideshowImageUrl(Eval("image")) %>' data-src='<%# SafeSlideshowImageUrl(Eval("image")) %>' alt="" />
                                                <%# SlideLinkEnd(Eval("link")) %>
                                                <div class="text"><%# SafeText(Eval("content")) %></div>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>

                                    <a class="prev" onclick="plusSlides(-1)">&#10094;</a>
                                    <a class="next" onclick="plusSlides(1)">&#10095;</a>
                                </div>

                                <div class="mt-2" style="text-align:center">
                                    <% For i = 1 To slides %>
                                        <span class="dot" onclick="currentSlide(<%=i%>)"></span>
                                    <% Next i %>
                                </div>

                                <script type="text/javascript">
                                    var slideIndex = 1;
                                    showSlides(slideIndex);

                                    function plusSlides(n) {
                                        showSlides(slideIndex += n);
                                    }

                                    function currentSlide(n) {
                                        showSlides(slideIndex = n);
                                    }

                                    function showSlides(n) {
                                        var i;
                                        var slides = document.getElementsByClassName("mySlides");
                                        var dots = document.getElementsByClassName("dot");
                                        if (n > slides.length) { slideIndex = 1 }
                                        if (n < 1) { slideIndex = slides.length }
                                        for (i = 0; i < slides.length; i++) {
                                            slides[i].style.display = "none";
                                        }
                                        for (i = 0; i < dots.length; i++) {
                                            dots[i].className = dots[i].className.replace(" active", "");
                                        }
                                        if (slides.length > 0) {
                                            slides[slideIndex - 1].style.display = "block";
                                        }
                                        if (dots.length > 0) {
                                            dots[slideIndex - 1].className += " active";
                                        }
                                    }
                                </script>

                            </div>
                            <!-- /Slide Show -->

                        </div>
                    </div>
                </div>

                <!-- RIGHT: 2 banners dinamici (pubblicità id_posizione_banner=4 ordinamento 1 e 2) -->
                <div class="wrap-item-3">

                    <!-- BANNER 1 -->
                    <div class="banner-image-product-4 style-4 hover-img mb-20">
                        <div class="item-product">

                            <!-- ========================= -->
                            <!-- INIZIO BLOCCO SPRINT2_HOME1_STEP5 SqlDataSource_Pubblicita_id4_pos1 (BANNERS POS4 ORD1) -->
                            <!-- ========================= -->
                            <asp:SqlDataSource 
                                ID="SqlDataSource_Pubblicita_id4_pos1" 
                                runat="server" 
                                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
                                ProviderName="MySql.Data.MySqlClient" 

                                SelectCommand="SELECT p.titolo, p.immagine, p.link, '' AS target FROM pubblicitav2 p WHERE p.abilitato = 1 AND p.id_posizione = 4 AND (p.data_inizio_pubblicazione IS NULL OR CAST(p.data_inizio_pubblicazione AS CHAR(10)) = '0000-00-00' OR p.data_inizio_pubblicazione <= NOW()) AND (p.data_fine_pubblicazione IS NULL OR CAST(p.data_fine_pubblicazione AS CHAR(10)) = '0000-00-00' OR p.data_fine_pubblicazione >= NOW()) ORDER BY p.ordinamento ASC, p.id DESC LIMIT 0,1"

                                UpdateCommand="
                                    UPDATE pubblicitav2 
                                    SET numero_impressioni_attuale = numero_impressioni_attuale + 1 
                                    WHERE id = ?id">

                                <SelectParameters>
                                    <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" Type="Int32" DefaultValue="0" />
                                </SelectParameters>

                                <UpdateParameters>
                                    <asp:Parameter Name="id" Type="Int32" />
                                </UpdateParameters>

                            </asp:SqlDataSource>
                            <!-- ========================= -->
                            <!-- FINE BLOCCO SPRINT2_HOME1_STEP5 SqlDataSource_Pubblicita_id4_pos1 -->
                            <!-- ========================= -->

                            <asp:Repeater ID="RepeaterPubblicita_id4_pos1" runat="server" OnItemDataBound="RepeaterPubblicita_id4_pos1_ItemDataBound" DataSourceID="SqlDataSource_Pubblicita_id4_pos1" EnableViewState="False">
                                <ItemTemplate>
                                    <a href='<%# "click.aspx?id=" & Eval("id") %>' class="box-link" target="_blank" rel="noopener noreferrer">
                                        <div class="box-image">
                                            <img class="lazyload"
                                                 src='<%# SafeBannerImageUrl(Eval("img_path")) %>'
                                                 data-src='<%# SafeBannerImageUrl(Eval("img_path")) %>'
                                                 alt='<%# SafeAttr(Eval("titolo")) %>' />
                                        </div>
                                    </a>
                                </ItemTemplate>
                            </asp:Repeater>

                        </div>
                    </div>

                    <!-- BANNER 2 -->
                    <div class="banner-image-product-4 style-4 hover-img">
                        <div class="item-product">

                            <!-- ========================= -->
                            <!-- INIZIO BLOCCO SPRINT2_HOME1_STEP5 SqlDataSource_Pubblicita_id4_pos2 (BANNERS POS4 ORD2) -->
                            <!-- ========================= -->
                            <asp:SqlDataSource 
                                ID="SqlDataSource_Pubblicita_id4_pos2" 
                                runat="server" 
                                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
                                ProviderName="MySql.Data.MySqlClient" 

                                SelectCommand="SELECT p.titolo, p.immagine, p.link, '' AS target FROM pubblicitav2 p WHERE p.abilitato = 1 AND p.id_posizione = 4 AND (p.data_inizio_pubblicazione IS NULL OR CAST(p.data_inizio_pubblicazione AS CHAR(10)) = '0000-00-00' OR p.data_inizio_pubblicazione <= NOW()) AND (p.data_fine_pubblicazione IS NULL OR CAST(p.data_fine_pubblicazione AS CHAR(10)) = '0000-00-00' OR p.data_fine_pubblicazione >= NOW()) ORDER BY p.ordinamento ASC, p.id DESC LIMIT 1,1"

                                UpdateCommand="
                                    UPDATE pubblicitav2 
                                    SET numero_impressioni_attuale = numero_impressioni_attuale + 1 
                                    WHERE id = ?id">

                                <SelectParameters>
                                    <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" Type="Int32" DefaultValue="0" />
                                </SelectParameters>

                                <UpdateParameters>
                                    <asp:Parameter Name="id" Type="Int32" />
                                </UpdateParameters>

                            </asp:SqlDataSource>
                            <!-- ========================= -->
                            <!-- FINE BLOCCO SPRINT2_HOME1_STEP5 SqlDataSource_Pubblicita_id4_pos2 -->
                            <!-- ========================= -->

                            <asp:Repeater ID="RepeaterPubblicita_id4_pos2" runat="server" OnItemDataBound="RepeaterPubblicita_id4_pos2_ItemDataBound" DataSourceID="SqlDataSource_Pubblicita_id4_pos2" EnableViewState="False">
                                <ItemTemplate>
                                    <a href='<%# "click.aspx?id=" & Eval("id") %>' class="box-link" target="_blank" rel="noopener noreferrer">
                                        <div class="box-image">
                                            <img class="lazyload"
                                                 src='<%# SafeBannerImageUrl(Eval("img_path")) %>'
                                                 data-src='<%# SafeBannerImageUrl(Eval("img_path")) %>'
                                                 alt='<%# SafeAttr(Eval("titolo")) %>' />
                                        </div>
                                    </a>
                                </ItemTemplate>
                            </asp:Repeater>

                        </div>
                    </div>

                </div>

            </div>
        </div>
    </section>

    <!-- Icon boxes (template) -->
    <div class="tf-sp-2 pt-0">
        <div class="container">
            <div class="swiper tf-sw-iconbox" data-preview="5" data-tablet="3" data-mobile-sm="2" data-mobile="1" data-space-lg="20" data-space-md="20" data-space="15" data-pagination="1" data-pagination-sm="1" data-pagination-md="1" data-pagination-lg="1">
                <div class="swiper-wrapper">
                    <div class="swiper-slide">
                        <div class="tf-icon-box style-border-line">
                            <div class="icon"><i class="icon-delivery-2"></i></div>
                            <div class="content">
                                <h5 class="title">Spedizione veloce</h5>
                                <p>Ordini gestiti rapidamente</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="tf-icon-box style-border-line">
                            <div class="icon"><i class="icon-payment-2"></i></div>
                            <div class="content">
                                <h5 class="title">Pagamenti sicuri</h5>
                                <p>Metodi di pagamento affidabili</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="tf-icon-box style-border-line">
                            <div class="icon"><i class="icon-return-2"></i></div>
                            <div class="content">
                                <h5 class="title">Assistenza</h5>
                                <p>Supporto pre e post vendita</p>
                            </div>
                        </div>
                    </div>
                    <div class="swiper-slide">
                        <div class="tf-icon-box style-border-line">
                            <div class="icon"><i class="icon-suport-3"></i></div>
                            <div class="content">
                                <h5 class="title">Contattaci</h5>
                                <p>Telefono, WhatsApp e Email</p>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="d-flex sw-dot-default sw-pagination-iconbox justify-content-center"></div>
            </div>
        </div>
    </div>

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
