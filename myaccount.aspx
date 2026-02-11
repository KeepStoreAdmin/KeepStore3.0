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
        /* KeepStore STEP20 (ONUS): spinner */
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
            padding-top: 180px;
        }

        #spinner_myaccount .ks-spinner-box {
            display: inline-block;
            background: #ffffff;
            border-radius: 14px;
            padding: 20px 26px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
        }

        /* Sidebar sticky (desktop) */
        .ks-myaccount .wrap-sidebar-account {
            position: sticky;
            top: 110px;
        }

        @media (max-width: 991px) {
            .ks-myaccount .wrap-sidebar-account {
                position: static;
                top: auto;
            }
        }

        /* Small polish for quick links */
        .ks-myaccount .ks-quick-links .tf-btn {
            width: 100%;
            justify-content: center;
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
            try {
                var links = document.querySelectorAll('.ks-myaccount a');
                for (var i = 0; i < links.length; i++) {
                    links[i].addEventListener('click', function () {
                        showMyAccountSpinner();
                    });
                }
            } catch (e) {
            }
        }

        (function () {
            if (document.readyState === "loading") {
                document.addEventListener("DOMContentLoaded", attachMyAccountSpinner);
            } else {
                attachMyAccountSpinner();
            }
        })();

        // Gestione ritorno da "indietro" del browser: se la pagina viene ripristinata dalla cache
        window.addEventListener('pageshow', function (event) {
            try {
                if (event.persisted) {
                    window.location.reload();
                    return;
                }

                if (window.performance && window.performance.navigation) {
                    if (window.performance.navigation.type === 2) {
                        window.location.reload();
                    }
                }
            } catch (e) {
            }
        });
    </script>
</asp:Content>

<asp:Content ID="MainContent1" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Overlay spinner area MyAccount -->
    <div id="spinner_myaccount" aria-hidden="true">
        <div class="ks-spinner-box">
            <div><b>Attendere, caricamento area personale...</b></div>
            <br />
            <img src="Public/assets/onsus/images/spinner.gif" alt="Caricamento..." />
        </div>
    </div>

    <div class="ks-myaccount">

        <!-- Breakcrumbs (ONUS) -->
        <div class="tf-sp-1 pb-0">
            <div class="container">
                <ul class="breakcrumbs">
                    <li>
                        <a href="Default.aspx" class="body-small link">Home</a>
                    </li>
                    <li class="d-flex align-items-center">
                        <i class="icon icon-arrow-right"></i>
                    </li>
                    <li>
                        <span class="body-small">Account</span>
                    </li>
                </ul>
            </div>
        </div>

        <!-- My Account (ONUS) -->
        <section class="tf-sp-2">
            <div class="container">
                <div class="row">

                    <!-- Sidebar -->
                    <div class="col-lg-3">
                        <div class="wrap-sidebar-account">
                            <ul class="myaccount-nav content-append">
                                <li><span class="myaccount-nav-item active">Dashboard</span></li>
                                <li><a href="datiutente.aspx" class="myaccount-nav-item">I miei dati</a></li>
                                <li><a href="documenti.aspx?t=4" class="myaccount-nav-item">I miei ordini</a></li>
                                <li><a href="documenti.aspx?t=2" class="myaccount-nav-item">Le mie fatture</a></li>
                                <li><a href="documenti.aspx?t=1" class="myaccount-nav-item">I miei DDT</a></li>
                                <li><a href="wishlist.aspx" class="myaccount-nav-item">Wishlist</a></li>
                                <li><a href="password.aspx" class="myaccount-nav-item">Cambia password</a></li>
                                <li><a href="remind.aspx" class="myaccount-nav-item">Recupero accesso</a></li>
                                <li><a href="logout.aspx" class="myaccount-nav-item">Logout</a></li>
                            </ul>
                        </div>
                    </div>

                    <!-- Content -->
                    <div class="col-lg-9">
                        <asp:Panel ID="pnlAccount" runat="server" CssClass="myaccount-content account-dashboard">

                            <div class="mb_60">
                                <h3 class="fw-semibold mb-20">Area personale</h3>
                                <p>
                                    Da qui puoi consultare i tuoi
                                    <a class="text-secondary link fw-medium" href="documenti.aspx?t=4">ordini</a>,
                                    gestire i tuoi
                                    <a class="text-secondary link fw-medium" href="datiutente.aspx">dati</a>
                                    e aggiornare le informazioni dell’account.
                                </p>
                            </div>

                            <div class="row g-3 ks-quick-links">
                                <div class="col-md-4">
                                    <a href="documenti.aspx?t=4" class="tf-btn btn-line">I miei ordini</a>
                                </div>
                                <div class="col-md-4">
                                    <a href="datiutente.aspx" class="tf-btn btn-line">I miei dati</a>
                                </div>
                                <div class="col-md-4">
                                    <a href="password.aspx" class="tf-btn btn-line">Cambia password</a>
                                </div>
                            </div>

                        </asp:Panel>
                    </div>

                </div>
            </div>
        </section>

    </div>

</asp:Content>
