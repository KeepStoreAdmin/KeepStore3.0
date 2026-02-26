<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeSideBanners.ascx.vb" Inherits="UI_HomeSideBanners" %>
<%@ Register Src="~/Public/ui/controls/HomeSideBanner.ascx" TagPrefix="ks" TagName="HomeSideBanner" %>

<div class="wrap-item-3 ks-home-side-banners">

    <ks:HomeSideBanner runat="server" ID="HomeSideBanner1" BannerOrder="1" ExtraCssClass="mb-20" />

    <ks:HomeSideBanner runat="server" ID="HomeSideBanner2" BannerOrder="2" />

</div>
