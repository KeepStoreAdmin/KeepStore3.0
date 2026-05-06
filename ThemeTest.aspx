<%@ Page Language="VB" AutoEventWireup="false" CodeFile="ThemeTest.aspx.vb" Inherits="ThemeTest" %>
<%@ Register Src="~/Public/ui/controls/ProductCardStatic.ascx" TagPrefix="ks" TagName="ProductCardStatic" %>
<%@ Register Src="~/Public/ui/controls/ProductCard.ascx" TagPrefix="ks" TagName="ProductCard" %>

<!DOCTYPE html>
<html lang="it">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Theme Test - KeepStore</title>
    <link rel="stylesheet" href="<%= ResolveUrl("~/Public/assets/theme/default/theme.css") %>" />
</head>
<body class="ks-theme-test-page">
    <form id="form1" runat="server">
        <main class="ks-theme-shell" aria-labelledby="themeTestTitle">
            <section class="ks-theme-hero">
                <div class="ks-theme-hero__content">
                    <p class="ks-theme-eyebrow">Ambiente isolato</p>
                    <h1 id="themeTestTitle">Test front-end neutro</h1>
                    <p>
                        Pagina temporanea senza database, login, carrello reale o logiche gestionali.
                    </p>
                    <a class="ks-theme-button" href="#product-preview">Guarda la card</a>
                </div>
                <div class="ks-theme-hero__panel" aria-hidden="true">
                    <span>Theme</span>
                    <strong>Shell</strong>
                </div>
            </section>

            <section id="product-preview" class="ks-theme-section" aria-labelledby="productPreviewTitle">
                <div class="ks-theme-section__heading">
                    <p class="ks-theme-eyebrow">Componente statico</p>
                    <h2 id="productPreviewTitle">Product card dimostrativa</h2>
                </div>
                <div class="ks-theme-product-grid">
                    <ks:ProductCardStatic ID="ProductCardStatic1" runat="server" />
                </div>
            </section>

            <section class="ks-theme-section" aria-labelledby="dynamicProductTitle">
                <div class="ks-theme-section__heading">
                    <p class="ks-theme-eyebrow">Componente dinamico</p>
                    <h2 id="dynamicProductTitle">Product card con proprieta WebForms</h2>
                </div>
                <div class="ks-theme-product-grid">
                    <ks:ProductCard ID="DemoProductCardSale" runat="server" />
                    <ks:ProductCard ID="DemoProductCardUnavailable" runat="server" />
                </div>
            </section>
        </main>
    </form>
    <script src="<%= ResolveUrl("~/Public/assets/theme/default/theme.js") %>"></script>
</body>
</html>
