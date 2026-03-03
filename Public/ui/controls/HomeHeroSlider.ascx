<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeHeroSlider.ascx.vb" Inherits="UI_HomeHeroSlider" %>

<div class="wrap-item-2 ks-home-hero" id="HeroWrap" runat="server">
    <!-- Home 1 hero (template-like, still database-driven) -->
    <div class="banner-image-product-4 style-2 hover-img has-bg-img" data-bg-image='<%= ThemeManager.Asset("images/banner/banner-30.jpg") %>'>
        <div class="item-product">

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
                        LIMIT 1
                    ">
                    <SelectParameters>
                        <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" Type="Int32" DefaultValue="1" />
                    </SelectParameters>
                </asp:SqlDataSource>

                <asp:Repeater ID="slideshowItems" runat="server" DataSourceID="slideShow" EnableViewState="False">
                    <ItemTemplate>
                        <%# SlideLinkStart(Eval("link")).Replace("<a ", "<a class=""box-link"" ") %>
                            <div class="box-content">
                                <span class="sub-title">Best seller</span>
                                <h4 class="title"><%# SafeText(Eval("content")) %></h4>
                                <p class="description">Scopri l'offerta del momento su KeepStore</p>
                            </div>
                            <div class="box-image">
                                <img class="lazyload"
                                     src='<%# SafeSlideshowImageUrl(Eval("image")) %>'
                                     data-src='<%# SafeSlideshowImageUrl(Eval("image")) %>'
                                     alt='<%# SafeAttr(Eval("content")) %>' />
                            </div>
                        <%# SlideLinkEnd(Eval("link")) %>
                    </ItemTemplate>
                </asp:Repeater>

        </div>
    </div>
</div>
