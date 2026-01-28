<%@ Page Language="VB"
    MasterPageFile="~/Page.master"
    AutoEventWireup="false"
    CodeFile="password.aspx.vb"
    Inherits="password" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Cambia password
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        .pwd-box {
            border: 1px solid #ddd;
            padding: 15px;
            margin-bottom: 20px;
            background-color: #fff;
            max-width: 500px;
        }

        .pwd-box h2 {
            font-size: 20px;
            margin-bottom: 15px;
        }

        .pwd-row {
            margin-bottom: 10px;
        }

        .pwd-row label {
            display: block;
            margin-bottom: 3px;
            font-weight: 600;
        }

        .pwd-message {
            margin-top: 10px;
        }

        /* Spinner pagina */
        .ks-loading-panel {
            border: 1px solid #ddd;
            background-color: #fff;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
        }

        .ks-spinner-circle {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            border: 3px solid #ccc;
            border-top-color: #333;
            animation: ks-spin 0.8s linear infinite;
            margin: 0 auto 8px;
        }

        @keyframes ks-spin {
            from { transform: rotate(0deg); }
            to   { transform: rotate(360deg); }
        }
    </style>

    <script type="text/javascript">
        function ksHideSpinnerAndShowContent() {
            var spinner = document.getElementById('<%= pnlLoading.ClientID %>');
            var content = document.getElementById('<%= pnlContent.ClientID %>');

            if (spinner) {
                spinner.style.display = 'none';
            }
            if (content) {
                content.style.display = 'block';
                content.style.opacity = '1';
            }
        }

        document.addEventListener('DOMContentLoaded', function () {
            ksHideSpinnerAndShowContent();
        });

        window.addEventListener('pageshow', function (event) {
            ksHideSpinnerAndShowContent();
        });

        function ksShowSpinnerOnSubmit() {
            var spinner = document.getElementById('<%= pnlLoading.ClientID %>');
            var content = document.getElementById('<%= pnlContent.ClientID %>');
            if (spinner) spinner.style.display = 'block';
            if (content) content.style.opacity = '0.5';
        }
    </script>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
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
                        <a href="myaccount.aspx" class="body-small link">Account</a>
                    </li>
                    <li class="d-flex align-items-center">
                        <i class="icon icon-arrow-right"></i>
                    </li>
                    <li>
                        <span class="body-small">Cambia password</span>
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
                                <li><a href="myaccount.aspx" class="myaccount-nav-item">Dashboard</a></li>
                                <li><a href="datiutente.aspx" class="myaccount-nav-item">I miei dati</a></li>
                                <li><a href="documenti.aspx?t=4" class="myaccount-nav-item">I miei ordini</a></li>
                                <li><a href="documenti.aspx?t=2" class="myaccount-nav-item">Le mie fatture</a></li>
                                <li><a href="documenti.aspx?t=1" class="myaccount-nav-item">I miei DDT</a></li>
                                <li><a href="wishlist.aspx" class="myaccount-nav-item">Wishlist</a></li>
                                <li><span class="myaccount-nav-item active">Cambia password</span></li>
                                <li><a href="remind.aspx" class="myaccount-nav-item">Recupero accesso</a></li>
                                <li><a href="logout.aspx" class="myaccount-nav-item">Logout</a></li>
                            </ul>
                        </div>
                    </div>

                    <!-- Content -->
                    <div class="col-lg-9">
                        <div class="tf-section-heading mb-4">
                            <h3 class="heading">Cambia password</h3>
                        </div>

<!-- SPINNER DI PAGINA -->
    <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel">
        <div class="ks-spinner-circle"></div>
        <div>Caricamento dati in corso...</div>
    </asp:Panel>

    <!-- CONTENUTO PRINCIPALE -->
    <asp:Panel ID="pnlContent" runat="server" Style="display:none;">

        <h1>Cambia password</h1>

        <div style="margin-bottom:20px;">
            <asp:HyperLink 
                ID="hlBackMyAccount" 
                runat="server"
                NavigateUrl="myaccount.aspx"
                CssClass="tf-btn-icon type-2 style-white">
                &laquo; Torna alla pagina My Account
            </asp:HyperLink>
        </div>

        <asp:Panel ID="pnlPassword" runat="server" CssClass="pwd-box">
            <h2>Modifica la tua password</h2>
            <p>Inserisci la password attuale e quella nuova.</p>

            <div class="pwd-row">
                <label for="tbPasswordAttuale">Password attuale</label>
                <asp:TextBox ID="tbPasswordAttuale" runat="server"
                             CssClass="form-control"
                             TextMode="Password" />
                <asp:RequiredFieldValidator ID="rfvOld"
                    runat="server"
                    ControlToValidate="tbPasswordAttuale"
                    ErrorMessage="Inserisci la password attuale."
                    Display="Dynamic"
                    ForeColor="Red" />
            </div>

            <div class="pwd-row">
                <label for="tbPasswordNuova">Nuova password</label>
                <asp:TextBox ID="tbPasswordNuova" runat="server"
                             CssClass="form-control"
                             TextMode="Password" />
                <asp:RequiredFieldValidator ID="rfvNew"
                    runat="server"
                    ControlToValidate="tbPasswordNuova"
                    ErrorMessage="Inserisci la nuova password."
                    Display="Dynamic"
                    ForeColor="Red" />
            </div>

            <div class="pwd-row">
                <label for="tbPasswordConferma">Conferma nuova password</label>
                <asp:TextBox ID="tbPasswordConferma" runat="server"
                             CssClass="form-control"
                             TextMode="Password" />
                <asp:RequiredFieldValidator ID="rfvNew2"
                    runat="server"
                    ControlToValidate="tbPasswordConferma"
                    ErrorMessage="Conferma la nuova password."
                    Display="Dynamic"
                    ForeColor="Red" />
                <asp:CompareValidator ID="cvPwd"
                    runat="server"
                    ControlToValidate="tbPasswordConferma"
                    ControlToCompare="tbPasswordNuova"
                    ErrorMessage="Le nuove password non coincidono."
                    Display="Dynamic"
                    ForeColor="Red" />
            </div>

            <div class="pwd-row">
                <asp:Button ID="btnSalva" runat="server"
                            CssClass="btn btn-primary"
                            Text="Aggiorna password"
                            OnClientClick="ksShowSpinnerOnSubmit();" />
            </div>

            <div class="pwd-row pwd-message">
                <asp:Label ID="lblMessaggio" runat="server" />
            </div>
        </asp:Panel>

    </asp:Panel>

                    </div>
                </div>
            </div>
        </section>
</div>
</asp:Content>
