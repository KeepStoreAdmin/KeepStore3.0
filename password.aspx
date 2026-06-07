<%@ Page Language="VB"
    MasterPageFile="~/Page.master"
    AutoEventWireup="false"
    CodeFile="password.aspx.vb"
    Inherits="password" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Cambia password
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    

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


        <!-- Breadcrumb -->
        <div class="tf-sp-1 pb-0">
            <div class="container">
                <div class="tf-breadcrumb-wrap">
                    <div class="tf-breadcrumb-list">
                        <a href="Default.aspx" class="text">Home</a>
                        <i class="icon icon-arrow-right"></i>
                        <a href="myaccount.aspx" class="text">Account</a>
                        <i class="icon icon-arrow-right"></i>
                        <span class="text">Cambia password</span>
                    </div>
                </div>
            </div>
        </div>

        <!-- My Account -->
        <section class="tf-sp-2">
            <div class="container">
                <div class="row">
                    <div class="col-12">
                        <div class="tf-section-heading mb-4">
                            <h3 class="heading">Cambia password</h3>
                            <p class="text mt-2">Aggiorna la tua password in modo sicuro.</p>
                        </div>

<!-- SPINNER DI PAGINA -->
    <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel">
        <div class="ks-spinner-circle"></div>
        <div>Caricamento dati in corso...</div>
    </asp:Panel>

    <!-- CONTENUTO PRINCIPALE -->
    <asp:Panel ID="pnlContent" runat="server" Style="display:none;">

        <div class="mb-3">
            <asp:HyperLink
                ID="hlBackMyAccount"
                runat="server"
                NavigateUrl="myaccount.aspx"
                CssClass="tf-btn btn-line">
                &laquo; Torna al tuo account
            </asp:HyperLink>
        </div>

        <asp:Panel ID="pnlPassword" runat="server" CssClass="ks-auth-card">
            <h5 class="title fw-semibold mb-2">Modifica password</h5>
            <p class="body-text-3 mb-4">Inserisci la password attuale e imposta quella nuova.</p>

            <div class="form-log">
                <div class="form-content">

                    <fieldset>
                        <label class="fw-semibold body-md-2" for="tbPasswordAttuale">Password attuale *</label>
                        <asp:TextBox ID="tbPasswordAttuale" runat="server" CssClass="form-control" TextMode="Password" MaxLength="25" />
                        <div class="validator">
                            <asp:RequiredFieldValidator ID="rfvOld" runat="server" ControlToValidate="tbPasswordAttuale" ErrorMessage="Inserisci la password attuale." Display="Dynamic" ForeColor="Red" ValidationGroup="PasswordChange" />
                        </div>
                    </fieldset>

                    <fieldset>
                        <label class="fw-semibold body-md-2" for="tbPasswordNuova">Nuova password *</label>
                        <asp:TextBox ID="tbPasswordNuova" runat="server" CssClass="form-control" TextMode="Password" MaxLength="25" />
                        <div class="validator">
                            <asp:RequiredFieldValidator ID="rfvNew" runat="server" ControlToValidate="tbPasswordNuova" ErrorMessage="Inserisci la nuova password." Display="Dynamic" ForeColor="Red" ValidationGroup="PasswordChange" />
                            <asp:RegularExpressionValidator ID="revNewLength" runat="server" ControlToValidate="tbPasswordNuova" ValidationExpression="^[\s\S]{8,25}$" ErrorMessage="La nuova password deve avere tra 8 e 25 caratteri." Display="Dynamic" ForeColor="Red" ValidationGroup="PasswordChange" />
                            <asp:CompareValidator ID="cvPwdDiversa" runat="server" ControlToValidate="tbPasswordNuova" ControlToCompare="tbPasswordAttuale" Operator="NotEqual" ErrorMessage="La nuova password deve essere diversa da quella attuale." Display="Dynamic" ForeColor="Red" ValidationGroup="PasswordChange" />
                        </div>
                    </fieldset>

                    <fieldset>
                        <label class="fw-semibold body-md-2" for="tbPasswordConferma">Conferma nuova password *</label>
                        <asp:TextBox ID="tbPasswordConferma" runat="server" CssClass="form-control" TextMode="Password" MaxLength="25" />
                        <div class="validator">
                            <asp:RequiredFieldValidator ID="rfvNew2" runat="server" ControlToValidate="tbPasswordConferma" ErrorMessage="Conferma la nuova password." Display="Dynamic" ForeColor="Red" ValidationGroup="PasswordChange" />
                            <asp:CompareValidator ID="cvPwd" runat="server" ControlToValidate="tbPasswordConferma" ControlToCompare="tbPasswordNuova" ErrorMessage="Le nuove password non coincidono." Display="Dynamic" ForeColor="Red" ValidationGroup="PasswordChange" />
                        </div>
                    </fieldset>

                </div>

                <asp:Button ID="btnSalva" runat="server" CssClass="tf-btn w-100 text-white" Text="Aggiorna password" ValidationGroup="PasswordChange" OnClientClick="if (typeof(Page_ClientValidate) === 'function' && !Page_ClientValidate('PasswordChange')) { return false; } ksShowSpinnerOnSubmit();" />

                <div class="mt-3 text-center">
                    <asp:Label ID="lblMessaggio" runat="server" CssClass="d-none" />
                </div>
            </div>

        </asp:Panel>

    </asp:Panel>

                    </div>
                </div>
            </div>
        </section>
</div>
</asp:Content>
