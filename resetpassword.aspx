<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="resetpassword.aspx.vb" Inherits="resetpassword" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Reset password
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        .ks-password-field {
            position: relative;
        }

        .ks-password-field .form-control {
            padding-right: 5.75rem;
        }

        #<%= tbPasswordNuova.ClientID %>::-ms-reveal,
        #<%= tbPasswordNuova.ClientID %>::-ms-clear,
        #<%= tbPasswordConferma.ClientID %>::-ms-reveal,
        #<%= tbPasswordConferma.ClientID %>::-ms-clear {
            display: none;
        }

        .ks-password-toggle {
            position: absolute;
            top: 50%;
            right: 0.75rem;
            transform: translateY(-50%);
            border: 0;
            background: transparent;
            color: inherit;
            cursor: pointer;
            font-size: 0.875rem;
            font-weight: 600;
            padding: 0.25rem;
        }

        .ks-password-toggle:focus {
            outline: 2px solid currentColor;
            outline-offset: 2px;
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

        window.addEventListener('pageshow', function () {
            ksHideSpinnerAndShowContent();
        });

        function ksShowSpinnerOnSubmit() {
            var spinner = document.getElementById('<%= pnlLoading.ClientID %>');
            var content = document.getElementById('<%= pnlContent.ClientID %>');
            if (spinner) spinner.style.display = 'block';
            if (content) content.style.opacity = '0.5';
        }

        function ksTogglePasswordVisibility(inputId, button) {
            var input = document.getElementById(inputId);
            if (!input || !button) return;

            var showPassword = input.type === 'password';
            input.type = showPassword ? 'text' : 'password';
            button.setAttribute('aria-pressed', showPassword ? 'true' : 'false');
            button.setAttribute('aria-label', showPassword ? 'Nascondi password' : 'Mostra password');
            button.innerText = showPassword ? 'Nascondi' : 'Mostra';
        }
    </script>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="login.aspx" class="text">Accedi</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Reset password</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel">
                <div class="ks-spinner-circle"></div>
                <div>Caricamento pagina in corso...</div>
            </asp:Panel>

            <asp:Panel ID="pnlContent" runat="server" Style="display:none;">
                <div class="row justify-content-center">
                    <div class="col-xl-6 col-lg-7 col-md-9">
                        <div class="ks-auth-card">
                            <h5 class="title fw-semibold mb-2">Reset password</h5>
                            <p class="body-text-3 mb-4">Imposta una nuova password per il tuo account.</p>

                            <asp:Panel ID="pnlInvalid" runat="server" Visible="false">
                                <div class="alert alert-warning">
                                    Il link di reset non e valido o non e piu utilizzabile. Richiedi un nuovo link dalla pagina di recupero accesso.
                                </div>
                                <asp:HyperLink ID="hlRemind" runat="server" NavigateUrl="remind.aspx" CssClass="tf-btn w-100 text-white">
                                    Richiedi un nuovo link
                                </asp:HyperLink>
                            </asp:Panel>

                            <asp:Panel ID="pnlSuccess" runat="server" Visible="false">
                                <div class="alert alert-success">
                                    <asp:Label ID="lblSuccess" runat="server" />
                                </div>
                                <asp:HyperLink ID="hlLogin" runat="server" NavigateUrl="login.aspx" CssClass="tf-btn w-100 text-white">
                                    Vai al login
                                </asp:HyperLink>
                            </asp:Panel>

                            <asp:Panel ID="pnlResetForm" runat="server" Visible="false">
                                <div class="form-log">
                                    <div class="form-content">
                                        <fieldset>
                                            <label class="fw-semibold body-md-2" for="<%= tbPasswordNuova.ClientID %>">Nuova password *</label>
                                            <div class="ks-password-field">
                                                <asp:TextBox ID="tbPasswordNuova" runat="server" CssClass="form-control" TextMode="Password" MaxLength="25" />
                                                <button type="button" class="ks-password-toggle" aria-label="Mostra password" aria-pressed="false" onclick="ksTogglePasswordVisibility('<%= tbPasswordNuova.ClientID %>', this);">Mostra</button>
                                            </div>
                                            <div class="validator">
                                                <asp:RequiredFieldValidator ID="rfvNew" runat="server" ControlToValidate="tbPasswordNuova" ErrorMessage="Inserisci la nuova password." Display="Dynamic" ForeColor="Red" />
                                                <asp:RegularExpressionValidator ID="revNewLength" runat="server" ControlToValidate="tbPasswordNuova" ValidationExpression="^[\s\S]{8,25}$" ErrorMessage="La nuova password deve avere tra 8 e 25 caratteri." Display="Dynamic" ForeColor="Red" />
                                            </div>
                                        </fieldset>

                                        <fieldset>
                                            <label class="fw-semibold body-md-2" for="<%= tbPasswordConferma.ClientID %>">Conferma nuova password *</label>
                                            <div class="ks-password-field">
                                                <asp:TextBox ID="tbPasswordConferma" runat="server" CssClass="form-control" TextMode="Password" MaxLength="25" />
                                                <button type="button" class="ks-password-toggle" aria-label="Mostra password" aria-pressed="false" onclick="ksTogglePasswordVisibility('<%= tbPasswordConferma.ClientID %>', this);">Mostra</button>
                                            </div>
                                            <div class="validator">
                                                <asp:RequiredFieldValidator ID="rfvConfirm" runat="server" ControlToValidate="tbPasswordConferma" ErrorMessage="Conferma la nuova password." Display="Dynamic" ForeColor="Red" />
                                                <asp:CompareValidator ID="cvPwd" runat="server" ControlToValidate="tbPasswordConferma" ControlToCompare="tbPasswordNuova" ErrorMessage="Le nuove password non coincidono." Display="Dynamic" ForeColor="Red" />
                                            </div>
                                        </fieldset>
                                    </div>

                                    <asp:Button ID="btnReset" runat="server" CssClass="tf-btn w-100 text-white" Text="Aggiorna password" OnClientClick="ksShowSpinnerOnSubmit();" />

                                    <div class="mt-3 text-center">
                                        <asp:Label ID="lblMessage" runat="server" ForeColor="Red" />
                                    </div>
                                </div>
                            </asp:Panel>
                        </div>
                    </div>
                </div>
            </asp:Panel>
        </div>
    </section>
</asp:Content>
