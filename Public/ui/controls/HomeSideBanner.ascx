<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeSideBanner.ascx.vb" Inherits="UI_HomeSideBanner" %>

<div class="banner-image-product-4 style-4 hover-img <%: ExtraCssClass %>">
    <div class="item-product">

        <asp:SqlDataSource
            ID="SdsBanner"
            runat="server"
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="MySql.Data.MySqlClient">
        </asp:SqlDataSource>

        <asp:Repeater
            ID="RepeaterBanner"
            runat="server"
            DataSourceID="SdsBanner"
            EnableViewState="False"
            OnItemDataBound="RepeaterBanner_ItemDataBound">
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
