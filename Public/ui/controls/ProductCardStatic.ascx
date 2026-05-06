<%@ Control Language="VB" AutoEventWireup="false" CodeFile="ProductCardStatic.ascx.vb" Inherits="Public_ui_controls_ProductCardStatic" %>

<article class="card-product" aria-labelledby="staticProductName">
    <div class="card-product-wrapper">
        <a href="#" class="product-img" aria-label="Scheda prodotto dimostrativa">
            <img class="img-product" src="/Public/assets/images/product/product-1.jpg" alt="Prodotto statico dimostrativo" />
            <img class="img-hover" src="/Public/assets/images/product/product-2.jpg" alt="" aria-hidden="true" />
        </a>
        <ul class="list-product-btn top-0 end-0" aria-label="Azioni dimostrative">
            <li>
                <button class="box-icon btn-icon-action hover-tooltip tooltip-left" type="button" disabled="disabled" aria-label="Carrello dimostrativo">
                    <span class="icon" aria-hidden="true">C</span>
                    <span class="tooltip">Demo carrello</span>
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
        <div class="box-sale-wrap pst-default">
            <p class="small-text">Promo</p>
            <p class="title-sidebar-2">20%</p>
        </div>
    </div>
    <div class="card-product-info">
        <div class="box-title">
            <div>
                <p class="product-tag caption text-main-2">Categoria demo</p>
                <a id="staticProductName" href="#" class="name-product body-md-2 fw-semibold text-secondary link">
                    Prodotto statico per test visuale della card
                </a>
            </div>
            <p class="price-wrap fw-medium" aria-label="Prezzo dimostrativo">
                <span class="new-price price-text fw-medium">74,90 &euro;</span>
                <span class="old-price body-md-2 text-main-2">92,90 &euro;</span>
            </p>
        </div>
        <div class="box-infor-detail">
            <ul class="list-computer-memory">
                <li><p class="caption">Demo</p></li>
                <li><p class="caption">Statico</p></li>
            </ul>
        </div>
    </div>
    <div class="card-product-btn">
        <button class="tf-btn btn-line w-100" type="button" disabled="disabled">
            <span>Azione dimostrativa</span>
        </button>
        <div class="box-btn">
            <button class="tf-btn-icon style-2 type-black" type="button" disabled="disabled">
                <span>Confronta</span>
            </button>
        </div>
    </div>
</article>
