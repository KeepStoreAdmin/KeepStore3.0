<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeHeroSlider.ascx.vb" Inherits="UI_HomeHeroSlider" %>

<div class="wrap-item-2 ks-home-hero" id="HeroWrap" runat="server">
    <div class="banner-image-product-4 style-2 hover-img">
        <div class="item-product">

            <!-- Hero Slider (database-driven) -->
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

                <div id="Slide_Show_Container" class="swiper ks-home-hero-slider" runat="server" aria-label="Promozioni">
                    <div class="swiper-wrapper">
                        <asp:Repeater ID="slideshowItems" runat="server" DataSourceID="slideShow" EnableViewState="False">
                            <ItemTemplate>
                                <div class="swiper-slide">
                                    <%# SlideLinkStart(Eval("link")) %>
                                    <img class="lazyload"
                                         src='<%# SafeSlideshowImageUrl(Eval("image")) %>'
                                         data-src='<%# SafeSlideshowImageUrl(Eval("image")) %>'
                                         alt='<%# SafeAttr(Eval("content")) %>' />
                                    <%# SlideLinkEnd(Eval("link")) %>
                                    <div class="ks-hero-caption"><%# SafeText(Eval("content")) %></div>
                                </div>
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>

                    <div class="swiper-button-prev nav-swiper ks-hero-prev" aria-label="Precedente">
                        <i class="icon-arrow-left-lg"></i>
                    </div>
                    <div class="swiper-button-next nav-swiper ks-hero-next" aria-label="Successivo">
                        <i class="icon-arrow-right-lg"></i>
                    </div>
                    <div class="sw-dot-default swiper-pagination ks-hero-pagination" aria-label="Paginazione slideshow"></div>
                </div>

            </div>
            <!-- /Hero Slider -->

        </div>
    </div>
</div>
