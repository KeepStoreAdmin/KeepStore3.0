<%@ Control Language="VB" AutoEventWireup="false" CodeFile="ProductCardStatic.ascx.vb" Inherits="Public_ui_controls_ProductCardStatic" %>

<article class="ks-product-card" aria-labelledby="staticProductName">
    <a class="ks-product-card__media" href="#" aria-label="Scheda prodotto dimostrativa">
        <span class="ks-product-card__badge">Demo</span>
        <span class="ks-product-card__image" aria-hidden="true">
            <span class="ks-product-card__device"></span>
        </span>
    </a>
    <div class="ks-product-card__body">
        <p class="ks-product-card__meta">Categoria dimostrativa</p>
        <h3 id="staticProductName">
            <a href="#">Prodotto statico per test tema</a>
        </h3>
        <p class="ks-product-card__description">
            Card isolata senza query, sessioni o collegamenti al carrello reale.
        </p>
        <div class="ks-product-card__price" aria-label="Prezzo dimostrativo">74,90 &euro;</div>
        <div class="ks-product-card__actions" aria-label="Azioni dimostrative">
            <button class="ks-product-card__button" type="button" disabled="disabled">
                Azione demo
            </button>
            <button class="ks-product-card__icon" type="button" disabled="disabled" aria-label="Wishlist dimostrativa">
                <span aria-hidden="true">&#9825;</span>
            </button>
        </div>
    </div>
</article>
