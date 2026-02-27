<%@ Control Language="VB" AutoEventWireup="false" CodeFile="Breadcrumb.ascx.vb" Inherits="Breadcrumb" %>
<asp:PlaceHolder ID="phBreadcrumb" runat="server" Visible="false">
    <section class="ks-breadcrumb py-3">
        <div class="container">
            <div class="d-flex flex-column gap-1">
                <asp:Literal ID="litTitle" runat="server" EnableViewState="False" />
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb mb-0">
                        <asp:Literal ID="litCrumbs" runat="server" EnableViewState="False" />
                    </ol>
                </nav>
            </div>
        </div>
    </section>
</asp:PlaceHolder>
