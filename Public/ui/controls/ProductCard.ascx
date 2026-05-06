<%@ Control Language="VB" AutoEventWireup="false" CodeFile="ProductCard.ascx.vb" Inherits="Public_ui_controls_ProductCard" %>

<article class="card-product" aria-labelledby="<%= ProductTitleClientId %>">
    <div class="card-product-wrapper">
        <a href="<%= SafeProductUrl %>" class="product-img" aria-label="<%= SafeProductNameAttribute %>">
            <img class="img-product" src="<%= SafeImageUrl %>" alt="<%= SafeProductNameAttribute %>" />
            <img class="img-hover" src="<%= SafeHoverImageUrl %>" alt="" aria-hidden="true" />
        </a>
        <ul class="list-product-btn top-0 end-0" aria-label="Azioni dimostrative">
            <li>
                <button class="box-icon btn-icon-action hover-tooltip tooltip-left" type="button" disabled="disabled" aria-label="Carrello dimostrativo">
                    <span class="icon" aria-hidden="true">C</span>
                    <span class="tooltip"><%= CartButtonText %></span>
                </button>
            </li>
            <li>
                <button class="box-icon btn-icon-action hover-tooltip tooltip-left" type="button" disabled="disabled" aria-label="Wishlist dimostrativa">
                    <span class="icon" aria-hidden="true">&#9825;</span>
                    <span class="tooltip">Demo wishlist</span>
                </button>
            </li>
            <li>
                <button class="box-icon btn-icon-action hover-tooltip tooltip-left" type="button" disabled="disabled" aria-label="Vista rapida dimostrativa">
                    <span class="icon" aria-hidden="true">&#9673;</span>
                    <span class="tooltip">Demo vista rapida</span>
                </button>
            </li>
        </ul>
        <asp:PlaceHolder ID="phBadge" runat="server">
            <div class="box-sale-wrap pst-default">
                <p class="small-text"><%= SafeBadgeText %></p>
                <p class="title-sidebar-2">Demo</p>
            </div>
        </asp:PlaceHolder>
    </div>
    <div class="card-product-info">
        <div class="box-title">
            <div>
                <p class="product-tag caption text-main-2"><%= SafeMetaText %></p>
                <a id="<%= ProductTitleClientId %>" href="<%= SafeProductUrl %>" class="name-product body-md-2 fw-semibold text-secondary link">
                    <%= SafeProductName %>
                </a>
            </div>
            <p class="price-wrap fw-medium" aria-label="Prezzo dimostrativo">
                <span class="new-price price-text fw-medium"><%= SafePriceText %></span>
                <asp:PlaceHolder ID="phOldPrice" runat="server">
                    <span class="old-price body-md-2 text-main-2"><%= SafeOldPriceText %></span>
                </asp:PlaceHolder>
            </p>
        </div>
        <div class="box-infor-detail">
            <ul class="list-computer-memory">
                <li><p class="caption"><%= SafeAvailabilityText %></p></li>
                <li><p class="caption"><%= SafeProductCodeText %></p></li>
            </ul>
        </div>
    </div>
    <div class="card-product-btn">
        <button class="tf-btn btn-line w-100" type="button" disabled="disabled">
            <span><%= CartButtonText %></span>
        </button>
        <div class="box-btn">
            <button class="tf-btn-icon style-2 type-black" type="button" disabled="disabled">
                <span>Confronta</span>
            </button>
        </div>
    </div>
</article>
