<%@ Control Language="VB" AutoEventWireup="false" CodeFile="ProductCard.ascx.vb" Inherits="Public_ui_controls_ProductCard" %>

<article class="card-product <%= SafeCardStateCssClass %>" aria-labelledby="<%= ProductTitleClientId %>">
    <div class="card-product-wrapper">
        <a href="<%= SafeProductUrl %>" class="product-img" aria-label="<%= SafeProductNameAttribute %>">
            <img class="img-product" src="<%= SafeImageUrl %>" alt="<%= SafeProductNameAttribute %>" />
            <img class="img-hover" src="<%= SafeHoverImageUrl %>" alt="" aria-hidden="true" />
        </a>
        <% If RenderQuickActions Then %>
        <ul class="list-product-btn top-0 end-0" aria-label="Azioni prodotto">
            <% If RenderWishlist Then %>
            <li>
                <% If IsDemoMode Then %>
                <button class="box-icon btn-icon-action hover-tooltip tooltip-left" type="button" disabled="disabled" aria-label="Wishlist dimostrativa">
                    <span class="icon" aria-hidden="true">&#9825;</span>
                    <span class="tooltip">Demo wishlist</span>
                </button>
                <% Else %>
                <a href="<%= SafeWishlistUrl %>" class="<%= WishlistActionClass %>" aria-label="Aggiungi a wishlist"<%= SafeActionDataAttributes %>>
                    <span class="icon icon-heart2"></span>
                    <span class="tooltip">Wishlist</span>
                </a>
                <% End If %>
            </li>
            <% End If %>
            <% If RenderQuickView Then %>
            <li>
                <% If IsDemoMode Then %>
                <button class="box-icon btn-icon-action hover-tooltip tooltip-left" type="button" disabled="disabled" aria-label="Vista rapida dimostrativa">
                    <span class="icon" aria-hidden="true">&#9673;</span>
                    <span class="tooltip">Demo vista rapida</span>
                </button>
                <% Else %>
                <a href="<%= SafeQuickViewTarget %>"<%= QuickViewToggleAttribute %> class="<%= QuickViewActionClass %>" aria-label="Vista rapida"<%= SafeActionDataAttributes %>>
                    <span class="icon icon-view"></span>
                    <span class="tooltip">Vista rapida</span>
                </a>
                <% End If %>
            </li>
            <% End If %>
            <% If RenderCompare Then %>
            <li>
                <% If IsDemoMode Then %>
                <button class="box-icon btn-icon-action hover-tooltip tooltip-left" type="button" disabled="disabled" aria-label="Confronto dimostrativo">
                    <span class="icon" aria-hidden="true">&#8644;</span>
                    <span class="tooltip">Demo confronto</span>
                </button>
                <% Else %>
                <a href="<%= SafeCompareTarget %>"<%= CompareToggleAttribute %> class="<%= CompareActionClass %>" aria-label="Confronta articolo"<%= SafeActionDataAttributes %>>
                    <span class="icon icon-compare1"></span>
                    <span class="tooltip">Confronta</span>
                </a>
                <% End If %>
            </li>
            <% End If %>
        </ul>
        <% End If %>
        <asp:PlaceHolder ID="phBadge" runat="server">
            <div class="box-sale-wrap pst-default">
                <p class="small-text"><%= SafeBadgeText %></p>
                <p class="title-sidebar-2">Demo</p>
            </div>
        </asp:PlaceHolder>
        <% If IsRefurbished Then %>
        <div class="box-sale-wrap pst-default">
            <p class="small-text ks-badge-refurb"><%= SafeRefurbishedText %></p>
        </div>
        <% End If %>
    </div>
    <div class="card-product-info">
        <div class="box-title">
            <div>
                <p class="product-tag caption text-main-2 ks-card-category"><%= SafeMetaText %></p>
                <a id="<%= ProductTitleClientId %>" href="<%= SafeProductUrl %>" class="name-product body-md-2 fw-semibold text-secondary link ks-card-title">
                    <%= SafeProductName %>
                </a>
            </div>
            <p class="price-wrap fw-medium" aria-label="Prezzo dimostrativo">
                <span class="new-price price-text fw-medium"><%= SafePriceText %></span>
                <asp:PlaceHolder ID="phOldPrice" runat="server">
                    <span class="old-price body-md-2 text-main-2"><%= SafeOldPriceText %></span>
                </asp:PlaceHolder>
            </p>
            <% If RenderPromoSummary Then %>
            <%= PromoSummaryHtml %>
            <% End If %>
        </div>
        <div class="box-infor-detail">
            <ul class="list-computer-memory">
                <li>
                    <% If RenderAvailabilityHtml Then %>
                    <%= TrustedAvailabilityHtml %>
                    <% Else %>
                    <p class="caption <%= SafeAvailabilityCss %>"><%= SafeAvailabilityText %></p>
                    <% End If %>
                </li>
                <li><p class="caption"><%= SafeProductCodeText %></p></li>
            </ul>
            <% If ShowMultiSelect Then %>
            <div class="d-flex align-items-center gap-2 mt-2">
                <input type="checkbox" class="form-check-input" disabled="disabled" aria-label="Selezione multipla dimostrativa" />
                <input type="text" class="form-control form-control-sm" value="<%= SafeQuantityText %>" disabled="disabled" inputmode="numeric" aria-label="Quantita dimostrativa" />
            </div>
            <% End If %>
            <asp:PlaceHolder ID="phLegacyServerControls" runat="server" Visible="false">
                <asp:HiddenField ID="hfID" runat="server" />
                <asp:HiddenField ID="hfTCId" runat="server" />
                <div class="d-flex align-items-center gap-2 mt-2 ks-card-purchase-actions <%= SafeLegacyQuantityStateCssClass %>"<%= SafeLegacyQuantityStateAttributes %>>
                    <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" CssClass="form-check-input" />
                    <asp:TextBox ID="tbQuantita" runat="server" CssClass="form-control form-control-sm ks-qty" Width="70" />
                    <% If RenderAddToCart Then %>
                    <a href="<%= SafeCartUrl %>"
                       class="ks-card-buy-cta ks-compact-buy-cta js-ks-cart-link"
                       aria-label="Acquista: aggiungi al carrello"
                       title="Acquista: aggiungi al carrello"<%= SafeActionDataAttributes %>>
                        <span class="ks-card-buy-cta__icon icon-cart-2" aria-hidden="true"></span>
                        <span class="ks-compact-buy-cta__tooltip" aria-hidden="true">Acquista</span>
                    </a>
                    <% End If %>
                </div>
            </asp:PlaceHolder>
        </div>
    </div>
    <div class="card-product-btn">
        <% If IsDemoMode Then %>
        <button class="tf-btn btn-line w-100" type="button" disabled="disabled">
            <span><%= CartButtonText %></span>
        </button>
        <% ElseIf RenderAddToCart Then %>
        <a href="<%= SafeCartUrl %>" class="<%= PrimaryButtonClass %>" aria-label="Acquista: aggiungi al carrello" title="Acquista: aggiungi al carrello"<%= SafeActionDataAttributes %>>
            <span><%= CartButtonText %></span>
        </a>
        <% End If %>
        <div class="box-btn">
            <% If IsDemoMode Then %>
            <button class="tf-btn-icon style-2 type-black" type="button" disabled="disabled">
                <span>Confronta</span>
            </button>
            <% ElseIf RenderCompare Then %>
            <a href="<%= SafeCompareTarget %>"<%= CompareToggleAttribute %> class="tf-btn-icon style-2 type-black js-ks-compare" aria-label="Confronta articolo"<%= SafeActionDataAttributes %>>
                <span>Confronta</span>
            </a>
            <% End If %>
        </div>
    </div>
</article>
