<%@ Control Language="VB" AutoEventWireup="false" CodeFile="Breadcrumb.ascx.vb" Inherits="Breadcrumb" %>

<asp:PlaceHolder ID="phBreadcrumb" runat="server" Visible="false">
    <div class="tf-sp-1 pb-0 ks-breadcrumb <%= Server.HtmlEncode(AdditionalCssClass) %>">
        <div class="container">
            <nav aria-label="Percorso di navigazione">
                <ul class="breakcrumbs flex-wrap">
                    <asp:Literal ID="litCrumbs" runat="server" EnableViewState="false" />
                </ul>
            </nav>
        </div>
    </div>
</asp:PlaceHolder>
