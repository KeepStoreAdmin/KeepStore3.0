<%@ Page Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>
<%@ Register Src="~/Public/ui/controls/HomeSideBanners.ascx" TagPrefix="ks" TagName="HomeSideBanners" %>
<%@ Register Src="~/Public/ui/controls/HomeDepartmentsMenu.ascx" TagPrefix="ks" TagName="HomeDepartmentsMenu" %>
<%@ Register Src="~/Public/ui/controls/HomeHeroSlider.ascx" TagPrefix="ks" TagName="HomeHeroSlider" %>
<%@ Register Src="~/Public/ui/controls/HomeIconBoxes.ascx" TagPrefix="ks" TagName="HomeIconBoxes" %>
<%@ Register Src="~/Public/ui/controls/HomeFeaturedProducts.ascx" TagPrefix="ks" TagName="HomeFeaturedProducts" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server"><%: Page.Title %></asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <%-- Home: stili in /Public/assets/keepstore/css/keepstore.css --%>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <section class="tf-sp-2">
        <div class="container">
            <div class="row g-3">
                <div class="col-xl-3 d-none d-xl-block">
                    <ks:HomeDepartmentsMenu runat="server" ID="HomeDepartmentsMenu1" />
                </div>
                <div class="col-xl-6">
                    <ks:HomeHeroSlider runat="server" ID="HomeHeroSlider1" />
                </div>
                <div class="col-xl-3">
                    <ks:HomeSideBanners runat="server" ID="HomeSideBanners1" />
                </div>
            </div>
        </div>
    </section>

    <ks:HomeIconBoxes runat="server" ID="HomeIconBoxes1" />

    <ks:HomeFeaturedProducts runat="server" ID="HomeFeaturedProducts1" />

</asp:Content>

<asp:Content ID="ScriptsContent" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script src="/Public/assets/keepstore/js/home-slideshow.js"></script>
</asp:Content>
