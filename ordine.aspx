<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="ordine.aspx.vb" Inherits="ordine" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Ordine
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
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
            if (target && target !== '') {
                window.location.replace(target);
            }
        })();
    </script>

    <h1>Ordine</h1>

    <br /><br /><br />

    <center>
        <asp:Label ID="img_bs_label" runat="server" />

        <asp:Panel ID="Panel1" runat="server">
            <asp:Label ID="Label2" runat="server" Text="" Font-Bold="true"></asp:Label>
            n°
            <asp:Label ID="Label1" runat="server" Text="" Font-Bold="true"></asp:Label>
            del
            <asp:Label ID="Label3" runat="server" Text="" Font-Bold="true"></asp:Label>
            correttamente inviato.
            <br /><br /><br />
            <asp:HyperLink ID="HyperLink1" runat="server" Font-Underline="true"></asp:HyperLink>
        </asp:Panel>

        <asp:Panel ID="Panel2" runat="server" Visible="false">
            <b>Si è verificato un problema durante l'elaborazione.</b>
            <br /><br />
            La preghiamo di contattare l'amministratore.
        </asp:Panel>
    </center>

    <br /><br /><br />

    <hr />

    <div runat="server" id="DivImg"></div>

    <asp:Literal runat="server" ID="litScript"></asp:Literal>

</asp:Content>