<%@ Page Title="" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="listino-catalogo.aspx.vb" Inherits="listino_catalogo" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Scarica listino e offerte
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="stylesheet" href="<%= ThemeManager.Asset("css/account-hub-ui.css") %>?v=20261118-orders-1b" />
    <style>
        .ks-dl-card { max-width: 720px; margin: 0 auto; padding: 24px 20px; border: 1px solid #d6dade; border-radius: 12px; background: #fff; }
        .ks-dl-card h1 { font-size: 22px; line-height: 26px; font-weight: 700; margin: 0 0 8px; }
        .ks-dl-card p { margin: 0 0 12px; color: #4b5563; }
        .ks-dl-list { margin: 0 0 16px; padding-left: 20px; color: #4b5563; }
        .ks-dl-actions { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 8px; }
        .ks-dl-actions .tf-btn { min-height: 48px; }
        .ks-dl-soon { opacity: .55; cursor: not-allowed; }
        .ks-dl-note { font-size: 13px; color: #6b7280; margin-top: 14px; }
        .ks-dl-msg { margin: 12px 0 0; padding: 10px 12px; border-radius: 8px; background: #fff4f4; border: 1px solid #f1b9bf; color: #7a1f2a; }
        .ks-dl-busy { position: fixed; inset: 0; z-index: 2000; display: none; align-items: center; justify-content: center; background: rgba(17, 24, 39, .55); padding: 16px; }
        .ks-dl-busy.is-on { display: flex; }
        .ks-dl-busy-box { max-width: 420px; width: 100%; background: #fff; border-radius: 12px; padding: 24px 20px; text-align: center; }
        .ks-dl-spin { width: 44px; height: 44px; margin: 0 auto 14px; border: 4px solid #d6dade; border-top-color: #1f2937; border-radius: 50%; animation: ksdlspin 0.9s linear infinite; }
        @keyframes ksdlspin { to { transform: rotate(360deg); } }
        @media (prefers-reduced-motion: reduce) { .ks-dl-spin { animation-duration: 3s; } }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="ks-myaccount ks-account-dashboard">
        <div class="tf-sp-1 pb-0">
            <div class="container">
                <div class="tf-breadcrumb-wrap">
                    <div class="tf-breadcrumb-list">
                        <a href="Default.aspx" class="text">Home</a>
                        <i class="icon icon-arrow-right"></i>
                        <a href="myaccount.aspx" class="text">Dashboard</a>
                        <i class="icon icon-arrow-right"></i>
                        <span class="text">Scarica listino e offerte</span>
                    </div>
                </div>
            </div>
        </div>

        <section class="tf-sp-2">
            <div class="container">
                <div class="ks-dl-card">
                    <h1>Scarica listino e offerte</h1>
                    <p>Il catalogo completo del negozio, da sfogliare sul tuo computer o telefono anche senza connessione.</p>
                    <ul class="ks-dl-list">
                        <li>Una foto, codice, EAN e descrizione per ogni articolo, ordinati per settore, tipologia e gruppo.</li>
                        <li>Prezzi del tuo profilo (<asp:Literal ID="litPriceLabel" runat="server" Text="IVA come da profilo"></asp:Literal>), con le offerte in evidenza.</li>
                        <li>Indice e segnalibri per andare subito dove ti serve; il codice apre la scheda dell'articolo sul sito.</li>
                    </ul>

                    <asp:HiddenField ID="hfToken" runat="server" />
                    <div class="ks-dl-actions">
                        <asp:Button ID="btnPdf" runat="server" Text="Scarica il PDF" CssClass="tf-btn btn-fill" OnClientClick="return ksCatalogStart(this);" />
                        <span class="tf-btn btn-line ks-dl-soon" aria-disabled="true">Excel (XLS) in arrivo</span>
                    </div>
                    <asp:Panel ID="pnlMessage" runat="server" Visible="false" CssClass="ks-dl-msg" role="alert">
                        <asp:Literal ID="litMessage" runat="server"></asp:Literal>
                    </asp:Panel>
                    <div id="ksDlClientMsg" class="ks-dl-msg" role="alert" hidden></div>
                    <p class="ks-dl-note">La preparazione puo richiedere fino a un minuto: i prezzi e le offerte sono quelli di oggi per il tuo account. Il file non viene conservato sul sito.</p>
                </div>
            </div>
        </section>
    </div>

    <div id="ksDlBusy" class="ks-dl-busy" role="status" aria-live="polite">
        <div class="ks-dl-busy-box">
            <div class="ks-dl-spin" aria-hidden="true"></div>
            <strong>Sto generando il listino...</strong>
            <p>Puo richiedere fino a un minuto. Non chiudere questa pagina: il download parte da solo.</p>
        </div>
    </div>
    <iframe name="ksDlFrame" id="ksDlFrame" title="Download listino" style="display:none" tabindex="-1" aria-hidden="true"></iframe>

    <script type="text/javascript">
        (function () {
            var tokenId = '<%= hfToken.ClientID %>';
            var timer = null, started = 0, form = null;
            function cookie(name) {
                var m = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'));
                return m ? decodeURIComponent(m[1]) : '';
            }
            function finish(msg) {
                if (timer) { clearInterval(timer); timer = null; }
                var busy = document.getElementById('ksDlBusy');
                if (busy) busy.classList.remove('is-on');
                if (form) { form.target = ''; }
                var box = document.getElementById('ksDlClientMsg');
                if (box) { if (msg) { box.textContent = msg; box.hidden = false; } else { box.hidden = true; } }
                document.cookie = 'ks_dl_done=; path=/; max-age=0';
            }
            window.ksCatalogStart = function (btn) {
                form = btn.form;
                var token = String(Date.now()) + Math.random().toString(16).slice(2, 10);
                document.getElementById(tokenId).value = token;
                form.target = 'ksDlFrame';
                started = Date.now();
                var busy = document.getElementById('ksDlBusy');
                if (busy) busy.classList.add('is-on');
                timer = setInterval(function () {
                    var v = cookie('ks_dl_done');
                    if (v.indexOf(token + '|') === 0) {
                        finish(v === token + '|ok' ? '' : 'Non e stato possibile generare il listino. Riprova tra qualche minuto.');
                    } else if (Date.now() - started > 240000) {
                        finish('La preparazione sta richiedendo troppo tempo. Riprova tra qualche minuto.');
                    }
                }, 700);
                return true;
            };
            window.addEventListener('pageshow', function () { finish(''); });
        })();
    </script>
</asp:Content>
