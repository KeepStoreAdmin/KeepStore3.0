<%@ Control Language="VB" AutoEventWireup="false" CodeFile="Breadcrumb.ascx.vb" Inherits="Breadcrumb" %>

<asp:PlaceHolder ID="phBreadcrumb" runat="server" Visible="false">
    <div class="tf-sp-1 pb-0 ks-breadcrumb">
        <div class="container">
            <asp:Literal ID="litTitle" runat="server" EnableViewState="false" />
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <asp:Literal ID="litCrumbs" runat="server" EnableViewState="false" />
                </div>
            </div>
        </div>
    </div>
</asp:PlaceHolder>
