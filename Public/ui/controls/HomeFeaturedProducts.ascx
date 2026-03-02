<%@ Control Language="VB" AutoEventWireup="false" CodeFile="HomeFeaturedProducts.ascx.vb" Inherits="Public_ui_controls_HomeFeaturedProducts" %>

<asp:SqlDataSource ID="sdsHomeFeatured" runat="server"
    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
    SelectCommand="SELECT id, TCId, Descrizione1, img1, Prezzo, PrezzoIvato, InOfferta, PrezzoPromo, PrezzoPromoIvato FROM vsuperarticoli ORDER BY id DESC LIMIT 8" />

<div class="tf-section-heading">
    <h3 class="heading">Prodotti in evidenza</h3>
    <a href="/articoli.aspx" class="link">Vedi tutto</a>
</div>

<div class="tf-grid-layout md-col-4">
    <asp:Repeater ID="rptHomeFeatured" runat="server" DataSourceID="sdsHomeFeatured">
        <ItemTemplate>
            <div class="card-product style-1">
                <div class="card-product-wrapper">
                    <a class="product-img" href='<%# "articolo.aspx?id=" & Eval("id") %>'>
                        <img class="lazyload img-product" alt='<%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>'
                             src='<%# ThemeManager.ProductImageUrl(Eval("img1")) %>' />
                    </a>

                    <%# If(Val(Eval("InOfferta")) = 1, "<div class='box-sale-wrap'><span class='sale-item'>Offerta</span></div>", "") %>
                </div>

                <div class="card-product-info">
                    <a class="name-product link" href='<%# "articolo.aspx?id=" & Eval("id") %>'>
                        <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione1"))) %>
                    </a>

                    <div class="price-wrap">
                        <%# UiPriceFormatter.RenderPriceHtml(
                                If(IsDBNull(Eval("Prezzo")), 0, Eval("Prezzo")),
                                If(IsDBNull(Eval("PrezzoIvato")), 0, Eval("PrezzoIvato")),
                                If(Val(Eval("InOfferta")) = 1, If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")), 0),
                                If(Val(Eval("InOfferta")) = 1, If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")), 0),
                                Session("IvaTipo")
                            ) %>
                    </div>
                </div>
            </div>
        </ItemTemplate>
    </asp:Repeater>
</div>
