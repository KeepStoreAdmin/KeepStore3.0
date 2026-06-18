<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="ordine.aspx.vb" Inherits="ordine" EnableViewState="false" ValidateRequest="true" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Ordine
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
        <meta name="robots" content="noindex,nofollow" />
    <meta http-equiv="Cache-Control" content="no-store, max-age=0" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <style>
        .ks-order-receipt-page{
            color:#1f2933;
            font-family:"Inter",Arial,sans-serif;
            font-size:16px;
            line-height:1.55;
        }
        .ks-order-receipt-page .container{max-width:1180px;}
        .ks-order-receipt-shell{display:grid;gap:24px;}
        .ks-order-hero{
            display:grid;
            grid-template-columns:minmax(0,1fr) auto;
            gap:18px;
            align-items:center;
            padding:28px;
            border:1px solid rgba(20,128,74,.18);
            border-radius:8px;
            background:linear-gradient(180deg,#f2fbf6 0%,#fff 100%);
        }
        .ks-order-hero h3{margin:0 0 8px;font-size:30px;line-height:1.2;}
        .ks-order-hero p{margin:0;color:#4b5563;}
        .ks-order-meta{display:flex;flex-wrap:wrap;gap:10px;margin-top:16px;}
        .ks-order-meta span{display:inline-flex;gap:6px;padding:8px 10px;border-radius:8px;background:#fff;border:1px solid rgba(0,0,0,.08);font-size:15px;}
        .ks-order-actions{display:flex;flex-wrap:wrap;gap:10px;justify-content:flex-end;}
        .ks-order-actions .tf-btn{min-height:46px;border-radius:8px;}
        .ks-order-grid{display:grid;grid-template-columns:minmax(0,1fr) minmax(320px,380px);gap:24px;align-items:start;}
        .ks-order-card{padding:22px;border:1px solid rgba(0,0,0,.08);border-radius:8px;background:#fff;box-shadow:0 14px 34px rgba(0,0,0,.05);}
        .ks-order-card h5{margin:0 0 14px;font-size:20px;line-height:1.3;}
        .ks-order-info-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;}
        .ks-order-info{display:grid;gap:4px;padding:12px 14px;border:1px solid rgba(0,0,0,.07);border-radius:8px;background:#fafafa;}
        .ks-order-info-wide{grid-column:1/-1;}
        .ks-order-label{color:#6b7280;font-size:12px;font-weight:800;letter-spacing:.02em;text-transform:uppercase;}
        .ks-order-info strong{color:#111;overflow-wrap:anywhere;}
        .ks-order-table-wrap{overflow-x:auto;}
        .ks-order-table{width:100%;border-collapse:collapse;}
        .ks-order-table th,.ks-order-table td{padding:12px;border-bottom:1px solid rgba(0,0,0,.08);vertical-align:middle;text-align:left;font-size:15px;}
        .ks-order-table th{background:#f7f8f7;color:#4b5563;font-size:13px;font-weight:800;text-transform:uppercase;}
        .ks-order-product{display:grid;grid-template-columns:56px minmax(0,1fr);gap:12px;align-items:center;}
        .ks-order-product img{width:56px;height:56px;object-fit:contain;border:1px solid rgba(0,0,0,.08);border-radius:8px;background:#fff;}
        .ks-order-product-title{font-weight:700;color:#111;}
        .ks-order-product-meta{color:#6b7280;font-size:13px;}
        .ks-order-total-list{display:grid;gap:0;}
        .ks-order-total-row{display:flex;justify-content:space-between;gap:14px;padding:10px 0;border-bottom:1px solid rgba(0,0,0,.08);}
        .ks-order-total-row strong{color:#111;}
        .ks-order-total-row-final{margin-top:4px;padding-top:14px;border-bottom:0;font-size:20px;font-weight:800;}
        .ks-order-next-steps{display:grid;gap:10px;margin:0;padding-left:18px;}
        @media (max-width: 991.98px){
            .ks-order-hero,.ks-order-grid{grid-template-columns:1fr;}
            .ks-order-actions{justify-content:flex-start;}
        }
        @media (max-width: 575.98px){
            .ks-order-receipt-page{font-size:15px;}
            .ks-order-hero,.ks-order-card{padding:18px;}
            .ks-order-info-grid{grid-template-columns:1fr;}
            .ks-order-product{grid-template-columns:1fr;}
            .ks-order-product img{display:none;}
        }
        @media print{
            body{background:#fff!important;color:#000!important;}
            header,footer,.tf-breadcrumb-wrap,.ks-order-actions,.newsletter,.offcanvas,.modal,.scroll-top,.tf-toolbar-bottom{display:none!important;}
            .ks-order-receipt-page{font-size:11pt;line-height:1.35;}
            .ks-order-receipt-page .container{max-width:none;width:100%;}
            .ks-order-hero,.ks-order-card{box-shadow:none!important;border:1px solid #999!important;background:#fff!important;break-inside:avoid;}
            .ks-order-grid{grid-template-columns:1fr;gap:12px;}
            .ks-order-table th,.ks-order-table td{padding:7px;border-color:#bbb;}
            .ks-order-product img{width:42px;height:42px;}
            .ks-order-card,.ks-order-table tr,.ks-order-info{break-inside:avoid;}
        }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <% For Each pairInidsFbPixelsSku As System.Collections.Generic.KeyValuePair(Of String, String) In idsFbPixelsSku %>
        <!-- Facebook Pixel Code -->
        <script>
            !function (f, b, e, v, n, t, s) {
                if (f.fbq) return;
                n = f.fbq = function () {
                    n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments)
                };
                if (!f._fbq) f._fbq = n;
                n.push = n;
                n.loaded = !0;
                n.version = '2.0';
                n.queue = [];
                t = b.createElement(e);
                t.async = !0;
                t.src = v;
                s = b.getElementsByTagName(e)[0];
                s.parentNode.insertBefore(t, s)
            }(window, document, 'script',
                'https://connect.facebook.net/en_US/fbevents.js');

            (function () {
                var pixelId = '<%= System.Web.HttpUtility.JavaScriptStringEncode(pairInidsFbPixelsSku.Key) %>';

                <% If utenteId <= 0 Then %>
                    fbq('init', pixelId);
                <% Else %>
                    fbq('init', pixelId, {
                        fn: '<%= System.Web.HttpUtility.JavaScriptStringEncode(firstName) %>',
                        ln: '<%= System.Web.HttpUtility.JavaScriptStringEncode(lastName) %>',
                        em: '<%= System.Web.HttpUtility.JavaScriptStringEncode(email) %>',
                        ph: '<%= System.Web.HttpUtility.JavaScriptStringEncode(phone) %>',
                        country: '<%= System.Web.HttpUtility.JavaScriptStringEncode(country) %>',
                        st: '<%= System.Web.HttpUtility.JavaScriptStringEncode(province) %>',
                        ct: '<%= System.Web.HttpUtility.JavaScriptStringEncode(city) %>',
                        zp: '<%= System.Web.HttpUtility.JavaScriptStringEncode(cap) %>'
                    });
                <% End If %>

                var skuCsv = '<%= System.Web.HttpUtility.JavaScriptStringEncode(pairInidsFbPixelsSku.Value) %>';
                var skuList = (skuCsv ? skuCsv.split(',') : []).map(function (x) { return (x || '').trim(); }).filter(Boolean);

                fbq('track', 'Purchase', {
                    content_ids: skuList,
                    content_type: 'product'
                });
            })();
        </script>

        <noscript>
            <img height="1"
                 width="1"
                 style="display:none"
                 src="https://www.facebook.com/tr?id=<%= System.Web.HttpUtility.UrlEncode(pairInidsFbPixelsSku.Key) %>&ev=PageView&noscript=1" />
        </noscript>
        <!-- End Facebook Pixel Code -->
    <% Next %>

    <script type="text/javascript">
        (function () {
            var target = '<%= System.Web.HttpUtility.JavaScriptStringEncode(redirect) %>';
            if (!target) return;
            target = (target || '').trim();
            if (!target) return;

            var lower = target.toLowerCase();
            // Block dangerous URL schemes (defense-in-depth)
            if (lower.indexOf('javascript:') === 0 || lower.indexOf('data:') === 0 || lower.indexOf('vbscript:') === 0) return;

            // Allow only relative URLs or absolute http(s) URLs
            var isRelative = (target.charAt(0) === '/' || target.indexOf('./') === 0 || target.indexOf('../') === 0);
            var isHttp = (lower.indexOf('http://') === 0 || lower.indexOf('https://') === 0);

            if (!isRelative && !isHttp) return;

            window.location.replace(target);
        })();
    </script>

    <!-- Breadcrumb -->
    <div class="tf-sp-1">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="<%= ResolveUrl("~/carrello.aspx") %>" class="text">Carrello</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Ordine</span>
                </div>
            </div>
        </div>
    </div>

</div>


    <section class="tf-sp-2 ks-order-receipt-page">
        <div class="container">
            <div class="ks-order-receipt-shell">

                <asp:Panel ID="Panel1" runat="server">
                    <div class="ks-order-hero">
                        <div>
                            <h3>Ordine inviato</h3>
                            <p>Abbiamo ricevuto il tuo ordine. Riceverai una conferma via email.</p>
                            <div class="ks-order-meta">
                                <span><strong>Documento</strong> <asp:Label ID="Label2" runat="server" Text=""></asp:Label></span>
                                <span><strong>N.</strong> <asp:Label ID="Label1" runat="server" Text=""></asp:Label></span>
                                <span><strong>Data</strong> <asp:Label ID="Label3" runat="server" Text=""></asp:Label></span>
                                <span><strong>Stato</strong> <asp:Label ID="lblOrderReceiptStatus" runat="server" Text="Ordine ricevuto"></asp:Label></span>
                            </div>
                        </div>
                        <div class="ks-order-actions">
                            <button type="button" class="tf-btn" onclick="window.print();">Stampa ordine</button>
                            <asp:HyperLink ID="HyperLink1" runat="server" Font-Underline="false" CssClass="tf-btn btn-line" Text="I miei ordini"></asp:HyperLink>
                            <a href="<%= ResolveUrl("~/Default.aspx") %>" class="tf-btn btn-gray">Continua gli acquisti</a>
                        </div>
                    </div>

                    <asp:Literal ID="litOrderReceipt" runat="server"></asp:Literal>
                </asp:Panel>

                        <asp:Panel ID="Panel2" runat="server" Visible="false">
                            <div class="ks-alert ks-alert-danger">
                                <div style="font-weight:700; margin-bottom:6px;">Si è verificato un problema durante l'elaborazione.</div>
                                <div>La preghiamo di contattare l'amministratore.</div>
                            </div>
                        </asp:Panel>

                    <div class="order-detail-wrap">
                        <asp:Label ID="img_bs_label" runat="server" />
                        <div runat="server" id="DivImg"></div>
                        <asp:Literal runat="server" ID="litScript"></asp:Literal>
                    </div>

            </div>
        </div>
    </section>

</asp:Content>
