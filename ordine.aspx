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
        /* KeepStore: ONUS alignment for ordine.aspx (solo layout, nessuna logica VB toccata) */
        .ks-order-center{max-width:860px;margin:0 auto}
        .ks-alert{padding:14px 16px;border-radius:14px;border:1px solid rgba(0,0,0,0.10);background:#fff}
        .ks-alert-danger{border-color:#ffd0d0;background:#fff1f1;color:#b00020}
        .ks-order-actions{margin-top:14px}
        .ks-order-actions .tf-btn{display:inline-flex}
        .ks-order-inline-label{display:inline-block}
        .ks-order-inline-label + .ks-order-inline-label{margin-left:6px}
        @media (max-width: 575px){
            .ks-order-actions .tf-btn{width:100%;justify-content:center}
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

    <!-- Breadcrumb (ONUS) -->
    <div class="tf-sp-3 pb-0">
        <div class="container">
            <ul class="breakcrumbs">
                <li><a href="<%= ResolveUrl("~/Default.aspx") %>" class="body-small link">Home</a></li>
                <li class="d-flex align-items-center"><i class="icon icon-arrow-right"></i></li>
                <li><a href="<%= ResolveUrl("~/carrello.aspx") %>" class="body-small link">Carrello</a></li>
                <li class="d-flex align-items-center"><i class="icon icon-arrow-right"></i></li>
                <li><span class="body-small">Ordine</span></li>
            </ul>
        </div>
    </div>

    <section class="tf-sp-2">
        <div class="container">
            <div class="ks-order-center">

                <div class="tf-order-detail">

                    <div class="order-notice">
                        <span class="icon">
                            <svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" fill="#ffffff" viewBox="0 0 256 256">
                                <path d="M128,16A112,112,0,1,0,240,128,112.13,112.13,0,0,0,128,16Zm0,208a96,96,0,1,1,96-96A96.11,96.11,0,0,1,128,224Zm-8-56a12,12,0,1,1,12,12A12,12,0,0,1,120,168Zm20-88v48a8,8,0,0,1-16,0V88a8,8,0,0,1,16,0Z"></path>
                            </svg>
                        </span>
                        <p>Ordine</p>
                    </div>

                    <div class="order-detail-wrap">

                        <div style="margin-bottom:14px;">
                            <asp:Label ID="img_bs_label" runat="server" />
                        </div>

                        <asp:Panel ID="Panel1" runat="server">
                            <h4 class="heading" style="margin-bottom:8px;">Ordine inviato</h4>
                            <p class="body-text-3" style="margin:0;">
                                <span class="ks-order-inline-label"><asp:Label ID="Label2" runat="server" Text="" Font-Bold="true"></asp:Label></span>
                                <span class="ks-order-inline-label">n° <asp:Label ID="Label1" runat="server" Text="" Font-Bold="true"></asp:Label></span>
                                <span class="ks-order-inline-label">del <asp:Label ID="Label3" runat="server" Text="" Font-Bold="true"></asp:Label></span>
                                <span class="ks-order-inline-label">correttamente inviato.</span>
                            </p>

                            <div class="ks-order-actions">
                                <asp:HyperLink ID="HyperLink1" runat="server" Font-Underline="false" CssClass="tf-btn btn-line"></asp:HyperLink>
                            </div>
                        </asp:Panel>

                        <asp:Panel ID="Panel2" runat="server" Visible="false">
                            <div class="ks-alert ks-alert-danger">
                                <div style="font-weight:700; margin-bottom:6px;">Si è verificato un problema durante l'elaborazione.</div>
                                <div>La preghiamo di contattare l'amministratore.</div>
                            </div>
                        </asp:Panel>

                    </div>

                    <div class="order-detail-wrap">
                        <div runat="server" id="DivImg"></div>
                        <asp:Literal runat="server" ID="litScript"></asp:Literal>
                    </div>

                </div>
            </div>
        </div>
    </section>

</asp:Content>
