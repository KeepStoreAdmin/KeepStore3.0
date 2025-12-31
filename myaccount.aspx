<%@ Page Language="VB"
    MasterPageFile="~/Page.master"
    AutoEventWireup="false"
    CodeFile="myaccount.aspx.vb"
    Inherits="myaccount" %>

<asp:Content ID="TitleContent1" ContentPlaceHolderID="TitleContent" runat="server">
    My Account
</asp:Content>

<asp:Content ID="HeadContent1" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        .account-box {
            border: 1px solid #ddd;
            padding: 15px;
            margin-bottom: 20px;
            background-color: #fff;
        }

        .account-box h2 {
            font-size: 20px;
            margin-bottom: 10px;
        }

        .account-links ul {
            list-style: none;
            padding-left: 0;
        }

        .account-links li {
            margin-bottom: 8px;
        }

        .account-links a {
            text-decoration: none;
        }

        .account-links a:hover {
            text-decoration: underline;
        }

        #spinner_myaccount {
            display: none;
            position: fixed;
            z-index: 9999;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: rgba(255, 255, 255, 0.75);
            text-align: center;
            padding-top: 200px;
        }
    </style>

    <script type="text/javascript">
        function showMyAccountSpinner() {
            var sp = document.getElementById('spinner_myaccount');
            if (sp) {
                sp.style.display = 'block';
            }
        }

        function attachMyAccountSpinner() {
            var links = document.querySelectorAll('.account-links a');
            for (var i = 0; i < links.length; i++) {
                links[i].addEventListener('click', function () {
                    showMyAccountSpinner();
                });
            }
        }

        (function () {
            if (document.readyState === "loading") {
                document.addEventListener("DOMContentLoaded", attachMyAccountSpinner);
            } else {
                attachMyAccountSpinner();
            }
        })();
    </script>
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <!-- tuoi CSS / script esistenti -->

    <script type="text/javascript">
        // Gestione ritorno da "indietro" del browser: se la pagina viene
        // ripristinata dalla cache della cronologia, la ricarico dal server
        window.addEventListener('pageshow', function (event) {
            try {
                // Caso moderno: event.persisted = true quando la pagina arriva da bfcache
                if (event.persisted) {
                    window.location.reload();
                    return;
                }

                // Fallback per browser più vecchi (performance.navigation.type = 2 = back/forward)
                if (window.performance && window.performance.navigation) {
                    if (window.performance.navigation.type === 2) {
                        window.location.reload();
                    }
                }
            } catch (e) {
                // Se qualcosa va storto, non blocco la pagina
            }
        });
    </script>
</asp:Content>

<asp:Content ID="MainContent1" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Overlay spinner area MyAccount -->
    <div id="spinner_myaccount">
        <div><b>Attendere, caricamento area personale...</b></div>
        <br />
        <img src="Public/Images/spinner.gif" alt="Caricamento..." />
    </div>

    <h1>My Account</h1>

    <asp:Panel ID="pnlAccount" runat="server" CssClass="account-box">
        <h2>Area personale</h2>
        <p>Da qui puoi gestire i tuoi dati e consultare i tuoi documenti.</p>

        <div class="account-links">
            <ul>
                <li><a href="datiutente.aspx">I miei dati</a></li>
                <li><a href="documenti.aspx?t=4">I miei ordini</a></li>
                <li><a href="documenti.aspx?t=2">Le mie fatture</a></li>
                <li><a href="documenti.aspx?t=1">I miei DDT</a></li>
                <li><a href="password.aspx">Cambia password</a></li>
                <li><a href="remind.aspx">Recupero dati di accesso</a></li>
            </ul>
        </div>
    </asp:Panel>

</asp:Content>
