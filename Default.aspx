<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Home
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        /* ============================================================
           Home (Sprint 2 - HOME 1)
           NOTE: solo stile minimo per integrare lo slideshow legacy
           ============================================================ */
        #Slide_Show {
            width: 100%;
        }

        #Slide_Show .slideshow-container {
            width: 100%;
            position: relative;
            overflow: hidden;
            border-radius: 12px;
        }

        #Slide_Show img {
            display: block;
            width: 100%;
            height: auto;
        }

        /* I controlli prev/next e dots sono gestiti dal CSS esistente.
           Qui NON sovrascriviamo colori o layout del template. */
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- ============================================================
         HOME 1 (Onsus) - HERO / BANNERS
         (Slideshow legacy integrato nella posizione "wrap-item-2")
         ============================================================ -->

    <section class="flat-spacing-4 pt_0">
        <div class="container">
            <div class="s-banner-wrapper style-2">

                <!-- LEFT: Department (static template) -->
                <div class="wrap-item-1">
                    <div class="department-menu hover-menu">
                        <div class="sub-department-menu">
                            <div class="department-title bg_main">
                                <span class="icon icon-categories"></span>
                                <span class="fw-semibold">Dipartimenti</span>
                            </div>
                            <ul class="department-list">
                                <!-- Static (template). In futuro possiamo collegarlo alle categorie reali. -->
                                <li><a href="shop-default.html" class="department-link">Laptop</a></li>
                                <li><a href="shop-default.html" class="department-link">Computer</a></li>
                                <li><a href="shop-default.html" class="department-link">Monitor</a></li>
                                <li><a href="shop-default.html" class="department-link">TV</a></li>
                                <li><a href="shop-default.html" class="department-link">Smartphone</a></li>
                                <li><a href="shop-default.html" class="department-link">Audio</a></li>
                                <li><a href="shop-default.html" class="department-link">Gadget</a></li>
                                <li><a href="shop-default.html" class="department-link">Accessori</a></li>
                            </ul>
                        </div>
                    </div>

                    <!-- Small promo banner (static) -->
                    <div class="banner-image-product-4 hover-img mb-20">
                        <div class="item-product">
                            <a href="shop-default.html" class="box-link">
                                <div class="box-content">
                                    <span class="sub-title">Promo</span>
                                    <h5 class="title">Offerte del momento</h5>
                                    <p class="price fw-semibold">Scopri</p>
                                </div>
                                <div class="box-image">
                                    <img src="/Public/assets/images/banner/banner-department-1.png" alt="" onerror="this.style.display='none'" />
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

                                <asp:SqlDataSource ID="slideShow" runat="server"
                                    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                    SelectCommand="SELECT * 
                                                   FROM slideshows_parts 
                                                   WHERE slideshowId = (
                                                        SELECT MAX(id) 
                                                        FROM slideshows 
                                                        WHERE placeholder = 'defaultPage' 
                                                          AND aziendeId = ?AziendaID
                                                   )
                                                   AND startDate <= CURDATE()
                                                   AND stopDate > CURDATE()
                                                   ORDER BY orderPosition">
                                    <SelectParameters>
                                        <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" Type="Int32" />
                                    </SelectParameters>
                                </asp:SqlDataSource>

                                <div id="Slide_Show_Container" class="slideshow-container" runat="server">
                                    <asp:Repeater ID="slideshowItems" runat="server" DataSourceID="slideShow">
                                        <ItemTemplate>
                                            <% incrementa_slides() %>
                                            <div class="mySlides fade">
                                                <%# SlideLinkStart(Eval("link")) %>
                                                <img src='<%# SafeSlideshowImageUrl(Eval("image")) %>' style="width:100%" alt="" />
                                                <%# SlideLinkEnd(Eval("link")) %>
                                                <div class="text"><%# SafeText(Eval("caption")) %></div>
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

                            <asp:SqlDataSource ID="SqlDataSource_Pubblicita_id4_pos1" runat="server"
                                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                SelectCommand="SELECT id, link, img_path, titolo, descrizione FROM pubblicitaV2 WHERE abilitato=1 AND id_posizione_banner=4 AND ordinamento=1 AND (data_inizio_pubblicazione IS NULL OR data_inizio_pubblicazione &lt;= CURDATE()) AND (data_fine_pubblicazione IS NULL OR data_fine_pubblicazione &gt;= CURDATE()) AND (limite_impressioni IS NULL OR limite_impressioni=0 OR numero_impressioni_attuale &lt; limite_impressioni) AND (limite_click IS NULL OR limite_click=0 OR numero_click_attuale &lt; limite_click) ORDER BY id DESC LIMIT 1"
                                UpdateCommand="UPDATE pubblicitaV2 SET numero_impressioni_attuale = numero_impressioni_attuale + 1 WHERE id=@id">
                                <UpdateParameters>
                                    <asp:Parameter Name="id" Type="Int32" />
                                </UpdateParameters>
                            </asp:SqlDataSource>

                            <asp:Repeater ID="RepeaterPubblicita_id4_pos1" runat="server" DataSourceID="SqlDataSource_Pubblicita_id4_pos1" EnableViewState="False" OnItemDataBound="RepeaterPubblicita_id4_pos1_ItemDataBound">
                                <ItemTemplate>
                                    <a href='<%# "click.aspx?id=" & Eval("id") %>' class="box-link" target="_blank" rel="noopener noreferrer">
                                        <div class="box-image">
                                            <img class="lazyload"
                                                 src='<%# ResolveUrl("~/Public/Banner/" & SafeFileNameOnly(Convert.ToString(Eval("img_path")))) %>'
                                                 data-src='<%# ResolveUrl("~/Public/Banner/" & SafeFileNameOnly(Convert.ToString(Eval("img_path")))) %>'
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

                            <asp:SqlDataSource ID="SqlDataSource_Pubblicita_id4_pos2" runat="server"
                                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                SelectCommand="SELECT id, link, img_path, titolo, descrizione FROM pubblicitaV2 WHERE abilitato=1 AND id_posizione_banner=4 AND ordinamento=2 AND (data_inizio_pubblicazione IS NULL OR data_inizio_pubblicazione &lt;= CURDATE()) AND (data_fine_pubblicazione IS NULL OR data_fine_pubblicazione &gt;= CURDATE()) AND (limite_impressioni IS NULL OR limite_impressioni=0 OR numero_impressioni_attuale &lt; limite_impressioni) AND (limite_click IS NULL OR limite_click=0 OR numero_click_attuale &lt; limite_click) ORDER BY id DESC LIMIT 1"
                                UpdateCommand="UPDATE pubblicitaV2 SET numero_impressioni_attuale = numero_impressioni_attuale + 1 WHERE id=@id">
                                <UpdateParameters>
                                    <asp:Parameter Name="id" Type="Int32" />
                                </UpdateParameters>
                            </asp:SqlDataSource>

                            <asp:Repeater ID="RepeaterPubblicita_id4_pos2" runat="server" DataSourceID="SqlDataSource_Pubblicita_id4_pos2" EnableViewState="False" OnItemDataBound="RepeaterPubblicita_id4_pos2_ItemDataBound">
                                <ItemTemplate>
                                    <a href='<%# "click.aspx?id=" & Eval("id") %>' class="box-link" target="_blank" rel="noopener noreferrer">
                                        <div class="box-image">
                                            <img class="lazyload"
                                                 src='<%# ResolveUrl("~/Public/Banner/" & SafeFileNameOnly(Convert.ToString(Eval("img_path")))) %>'
                                                 data-src='<%# ResolveUrl("~/Public/Banner/" & SafeFileNameOnly(Convert.ToString(Eval("img_path")))) %>'
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
    <section class="flat-spacing-3 pt_0">
        <div class="container">
            <div class="swiper tf-sw-iconbox" data-preview="4" data-tablet="2" data-mobile="1" data-space-lg="0" data-space-md="0" data-space="0" data-pagination="1" data-pagination-sm="1" data-pagination-md="1" data-pagination-lg="1">
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
                <div class="sw-pagination-iconbox sw-dots type-circle justify-content-center"></div>
            </div>
        </div>
    </section>

    <!-- ============================================================
         SCELTI PER TE (vetrina)
         ============================================================ -->

    <% If Data_UltimiArrivi.Items.Count > 0 Then %>
    <section class="flat-spacing-4 pt_0">
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
                                            <img class="lazyload img-product"
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
                                        <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="title link">
                                            <%# SafeText(compatta_testo(Eval("Descrizione1"), 60)) %>
                                        </a>

                                        <span class="price">
                                            <span class="new-price">
                                                <%# controlla_prezzo(
                                                        If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                                        If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                                        If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                                        If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                                        Session("IvaTipo")
                                                    ) %>
                                            </span>
                                        </span>

                                        <div class="body-text-3 mt-1">
                                            <span class="fw-semibold">Cod.</span> <%# SafeText(Eval("Codice")) %>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                </div>
                <div class="sw-pagination-products sw-dots type-circle justify-content-center"></div>
            </div>
        </div>

        <!-- DataSource (vetrina) - il comando viene sovrascritto in Default.aspx.vb -->
        <asp:SqlDataSource ID="SdsArticoliInVetrina" runat="server"
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT * FROM documenti JOIN documentirighe ON documenti.id=documentirighe.`DocumentiId` WHERE documentirighe.`ArticoliId`>0 AND documenti.`TipoDocumentiId`=11 GROUP BY documentirighe.`ArticoliId` ORDER BY documenti.id DESC LIMIT 1">
        </asp:SqlDataSource>

    </section>
    <% End If %>

    <!-- ============================================================
         NOVITÀ (nuovi arrivi)
         ============================================================ -->

    <section class="flat-spacing-4 pt_0">
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
                                            <img class="lazyload img-product"
                                                 src='<%# checkImg(Eval("img1")) %>'
                                                 data-src='<%# checkImg(Eval("img1")) %>'
                                                 alt='<%# SafeAttr(Eval("Descrizione1")) %>' />
                                        </a>

                                        <div class="on-sale-wrap text-end" style='display:<%# controlla_promo(Eval("inOfferta")) %>;'>
                                            <span class="on-sale-item"><%# SafeText(sconto(Eval("ListinoUfficiale"), If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), Eval("iva"))) %></span>
                                        </div>
                                    </div>

                                    <div class="card-product-info">
                                        <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="title link">
                                            <%# SafeText(compatta_testo(Eval("Descrizione1"), 60)) %>
                                        </a>

                                        <span class="price">
                                            <span class="new-price">
                                                <%# controlla_prezzo(
                                                        If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                                        If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                                        If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                                        If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                                        Session("IvaTipo")
                                                    ) %>
                                            </span>
                                        </span>

                                        <div class="body-text-3 mt-1">
                                            <span class="fw-semibold">Cod.</span> <%# SafeText(Eval("Codice")) %>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                </div>
                <div class="sw-pagination-products sw-dots type-circle justify-content-center"></div>
            </div>

            <!-- DataSource - comando sovrascritto in Default.aspx.vb -->
            <asp:SqlDataSource ID="SdsNewArticoli" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                SelectCommand="SELECT * FROM articoli LIMIT 1">
            </asp:SqlDataSource>

        </div>
    </section>

    <!-- ============================================================
         PIÙ VENDUTI
         ============================================================ -->

    <section class="flat-spacing-4 pt_0">
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
                                            <img class="lazyload img-product"
                                                 src='<%# checkImg(Eval("img1")) %>'
                                                 data-src='<%# checkImg(Eval("img1")) %>'
                                                 alt='<%# SafeAttr(Eval("Descrizione1")) %>' />
                                        </a>

                                        <div class="on-sale-wrap text-end" style='display:<%# controlla_promo(Eval("inOfferta")) %>;'>
                                            <span class="on-sale-item"><%# SafeText(sconto(Eval("ListinoUfficiale"), If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), Eval("iva"))) %></span>
                                        </div>
                                    </div>

                                    <div class="card-product-info">
                                        <a href='articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>' class="title link">
                                            <%# SafeText(compatta_testo(Eval("Descrizione1"), 60)) %>
                                        </a>

                                        <span class="price">
                                            <span class="new-price">
                                                <%# controlla_prezzo(
                                                        If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                                        If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                                        If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                                        If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                                        Session("IvaTipo")
                                                    ) %>
                                            </span>
                                        </span>

                                        <div class="body-text-3 mt-1">
                                            <span class="fw-semibold">Cod.</span> <%# SafeText(Eval("Codice")) %>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>

                </div>
                <div class="sw-pagination-products sw-dots type-circle justify-content-center"></div>
            </div>

            <asp:SqlDataSource ID="sdsPiuAcquistati" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                SelectCommand="SELECT * FROM documenti LIMIT 1">
            </asp:SqlDataSource>

        </div>
    </section>

    <!-- ============================================================
         BRAND (marche random)
         ============================================================ -->

    <section class="flat-spacing-4 pt_0">
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
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                SelectCommand="SELECT * FROM marche WHERE (Abilitato=1) AND (img is not NULL) ORDER BY RAND() LIMIT 6">
            </asp:SqlDataSource>
        </div>
    </section>

    <!-- Nota prezzi -->
    <section class="flat-spacing-4 pt_0">
        <div class="container">
            <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" CssClass="body-text-3" />
        </div>
    </section>


    <script runat="server">
        ' ============================================================
        ' Helper generali / slideshow / prezzi
        ' ============================================================

        Dim slides As Integer = 0

        ' ===========================
        ' HARDENING OUTPUT (XSS / URL)
        ' ===========================

        Function SafeText(ByVal obj As Object) As String
            Return System.Web.HttpUtility.HtmlEncode(Convert.ToString(obj))
        End Function

        Function SafeAttr(ByVal obj As Object) As String
            Return System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(obj))
        End Function

        ' Consente: URL relativi (/, ~/), o assoluti http/https (solo per HREF)
        Function SafeUrl(ByVal urlObj As Object) As String
            If urlObj Is Nothing OrElse IsDBNull(urlObj) Then Return ""
            Dim raw As String = Convert.ToString(urlObj).Trim()
            If raw = "" Then Return ""

            Dim lower As String = raw.ToLowerInvariant()
            If lower.StartsWith("javascript:") OrElse lower.StartsWith("data:") OrElse lower.StartsWith("vbscript:") Then
                Return ""
            End If

            If raw.StartsWith("/") OrElse raw.StartsWith("~/") Then
                Return raw
            End If

            Dim uri As Uri = Nothing
            If Uri.TryCreate(raw, UriKind.Absolute, uri) Then
                If uri.Scheme = Uri.UriSchemeHttp OrElse uri.Scheme = Uri.UriSchemeHttps Then
                    Return uri.ToString()
                End If
            End If

            Return ""
        End Function

        Function SlideLinkStart(ByVal linkObj As Object) As String
            Dim u As String = SafeUrl(linkObj)
            If u = "" Then Return ""
            If u.StartsWith("~/") Then u = ResolveUrl(u)
            Return "<a href=\"" & SafeAttr(u) & "\">"
        End Function

        Function SlideLinkEnd(ByVal linkObj As Object) As String
            Dim u As String = SafeUrl(linkObj)
            If u = "" Then Return ""
            Return "</a>"
        End Function

        Function SafeFileNameOnly(ByVal fileObj As Object) As String
            If fileObj Is Nothing OrElse IsDBNull(fileObj) Then Return ""
            Dim s As String = Convert.ToString(fileObj).Trim()
            If s = "" Then Return ""

            s = s.Replace("\\", "/")

            ' blocco path traversal / path assoluti
            If s.Contains("..") OrElse s.Contains(":") Then Return ""

            ' prendo solo l'ultimo segmento
            If s.Contains("/") Then
                s = s.Substring(s.LastIndexOf("/"c) + 1)
            End If

            Return s
        End Function

        Function SafeSlideshowImageUrl(ByVal fileObj As Object) As String
            Dim fileName As String = SafeFileNameOnly(fileObj)
            If fileName = "" Then
                Return ResolveUrl("~/Public/images/nofoto.gif")
            End If
            Return ResolveUrl("~/Public/Slideshows/" & fileName)
        End Function

        Sub incrementa_slides()
            slides += 1
        End Sub

        ' ============================================================
        ' Promo / prezzi / risparmio
        ' ============================================================

        Function controlla_promo(ByVal inpromo As Integer) As String
            If inpromo = 1 Then
                Return ""
            Else
                Return "none"
            End If
        End Function

        Function calcola_risparmio(ByVal prezzo_listino As Double, ByVal prezzo1 As Object, ByVal prezzo2 As Object) As Double
            Dim risparmio As Double
            Dim prezzo As Double

            If IsDBNull(prezzo2) OrElse prezzo2 Is Nothing OrElse CDbl(prezzo2) = 0 Then
                If IsDBNull(prezzo1) OrElse prezzo1 Is Nothing Then
                    Return 0
                End If
                prezzo = Convert.ToDouble(prezzo1)
            Else
                prezzo = Convert.ToDouble(prezzo2)
            End If

            risparmio = Math.Round(prezzo_listino - prezzo, 2)
            Return risparmio
        End Function

        Function controlla_risparmio(ByVal prezzo_listino As Double, ByVal prezzo1 As Object, ByVal prezzo2 As Object) As String
            If prezzo_listino = 0 Then
                Return "none"
            ElseIf calcola_risparmio(prezzo_listino, prezzo1, prezzo2) < 0.01 Then
                Return "none"
            Else
                Return ""
            End If
        End Function

        Function controlla_prezzo(ByVal prezzo As Double,
                                  ByVal prezzo_ivato As Double,
                                  ByVal prezzo_promo As Double,
                                  ByVal prezzo_promo_ivato As Double,
                                  ByVal iva_tipo As Integer) As String

            If prezzo_promo > 0 Then
                If iva_tipo = 1 Then
                    Return String.Format("{0:c}", prezzo_promo)
                Else
                    Return String.Format("{0:c}", prezzo_promo_ivato)
                End If
            Else
                If iva_tipo = 1 Then
                    Return String.Format("{0:c}", prezzo)
                Else
                    Return String.Format("{0:c}", prezzo_ivato)
                End If
            End If
        End Function

        Function compatta_testo(ByVal testo As String, ByVal lunghezza As Integer) As String
            If String.IsNullOrEmpty(testo) Then
                Return ""
            End If

            Dim testoFinale As String = Left(testo, lunghezza)
            If testo.Length > lunghezza Then
                testoFinale &= "..."
            End If
            Return testoFinale
        End Function

        Function sconto(ByVal listino_ufficiale As Double,
                        ByVal prezzo_promo As Double,
                        ByVal prezzo_promo_ivato As Double,
                        ByVal iva_articolo As Double) As String

            Dim percentuale As String = ""

            If (prezzo_promo > 0 AndAlso prezzo_promo_ivato > 0 AndAlso listino_ufficiale > 0) Then
                If Session("IvaTipo") = 1 Then
                    percentuale = String.Format("{0:0}", ((listino_ufficiale - prezzo_promo) * 100) / listino_ufficiale)
                Else
                    Dim listino_ivato As Double = listino_ufficiale * ((iva_articolo / 100) + 1)
                    percentuale = String.Format("{0:0}", ((listino_ivato - prezzo_promo_ivato) * 100) / listino_ivato)
                End If
            End If

            Return "- " & percentuale & "%"
        End Function

        ' ============================================================
        ' Immagini articoli: path hardening
        ' ============================================================

        Function checkImg(ByVal imgname As Object) As String
            ' nulla / DBNull
            If imgname Is Nothing OrElse Convert.IsDBNull(imgname) Then
                Return ResolveUrl("~/Public/images/nofoto.gif")
            End If

            Dim fileName As String = Convert.ToString(imgname).Trim()
            If String.IsNullOrEmpty(fileName) Then
                Return ResolveUrl("~/Public/images/nofoto.gif")
            End If

            fileName = fileName.Replace("\\", "/")

            ' blocco traversal
            If fileName.Contains("..") OrElse fileName.Contains(":") Then
                Return ResolveUrl("~/Public/images/nofoto.gif")
            End If

            ' già path (relativo sito)
            If fileName.StartsWith("~/") Then
                Return ResolveUrl(fileName)
            End If
            If fileName.StartsWith("/") Then
                Return fileName
            End If

            ' nome file semplice
            If fileName.Contains("/") Then
                fileName = fileName.Substring(fileName.LastIndexOf("/"c) + 1)
            End If

            Return ResolveUrl("~/Public/images/articoli/" & fileName)
        End Function

    </script>

</asp:Content>
