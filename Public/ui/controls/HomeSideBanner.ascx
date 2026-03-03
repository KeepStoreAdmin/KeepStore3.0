<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeSideBanner.ascx.vb" Inherits="UI_HomeSideBanner" %>

<div class="cls-category style-abs hover-img <%: ExtraCssClass %>">
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
	                <a href='<%# "click.aspx?id=" & Eval("id") %>' class="img-style d-block" target="_blank" rel="noopener noreferrer">
	                    <img class="lazyload"
	                         src='<%# SafeBannerImageUrl(Eval("img_path")) %>'
	                         data-src='<%# SafeBannerImageUrl(Eval("img_path")) %>'
	                         alt='<%# SafeAttr(Eval("titolo")) %>' />
	                </a>
	                <div class="content">
	                    <h4>
	                        <a href='<%# "click.aspx?id=" & Eval("id") %>' target="_blank" rel="noopener noreferrer">
	                            <%# Server.HtmlEncode(Convert.ToString(Eval("titolo"))) %>
	                        </a>
	                    </h4>
	                    <span class="sale-off text-white"><%# Server.HtmlEncode(Convert.ToString(Eval("descrizione"))) %></span>
	                </div>
	            </ItemTemplate>
	        </asp:Repeater>

    </div>
</div>
