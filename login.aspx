<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="login.aspx.vb" Inherits="Login" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Accedi
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style>
        .ks-login-password-wrap {
            position: relative;
        }

        .ks-login-password-wrap .form-control {
            padding-right: 5.75rem;
        }

        #<%= tbPassword.ClientID %>::-ms-reveal,
        #<%= tbPassword.ClientID %>::-ms-clear {
            display: none;
        }

        .ks-login-password-toggle {
            position: absolute;
            top: 50%;
            right: .5rem;
            transform: translateY(-50%);
            border: 0;
            background: transparent;
            color: #3a3a3a;
            font-size: .875rem;
            line-height: 1;
            padding: .45rem .5rem;
        }

        .ks-login-password-toggle:focus {
            outline: 2px solid currentColor;
            outline-offset: 2px;
        }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Breadcrumbs (tema) -->
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Accedi</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="row justify-content-center">
                <div class="col-xl-5 col-lg-6 col-md-8">
                    <div class="ks-auth-card">

                        <h5 class="title fw-semibold mb-4">Accedi</h5>

                        <div class="form-log">
                            <div class="form-content">

                                <fieldset>
                                    <label class="fw-semibold body-md-2">
                                        <asp:Label ID="lblUsername" runat="server" Text="Username *" Visible="True"></asp:Label>
                                    </label>
                                    <asp:TextBox ID="tbUsername" CssClass="form-control" AutoPostBack="false" runat="server" Visible="True"></asp:TextBox>
                                    <div class="validator">
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidatorUser" runat="server"
                                            ControlToValidate="tbUsername"
                                            Display="Dynamic"
                                            ErrorMessage="Inserire Username"
                                            ValidationGroup="LoginAccesso"></asp:RequiredFieldValidator>
                                    </div>
                                </fieldset>

                                <fieldset>
                                    <label class="fw-semibold body-md-2">
                                        <asp:Label ID="lblPassword" runat="server" Text="Password *" Visible="True"></asp:Label>
                                    </label>
                                    <div class="ks-login-password-wrap">
                                        <asp:TextBox ID="tbPassword" CssClass="form-control" AutoPostBack="false" TextMode="Password" runat="server" Visible="True"></asp:TextBox>
                                        <button type="button"
                                            id="btnToggleLoginPassword"
                                            class="ks-login-password-toggle"
                                            aria-controls="<%= tbPassword.ClientID %>"
                                            aria-pressed="false"
                                            aria-label="Mostra password">
                                            Mostra
                                        </button>
                                    </div>
                                    <div class="validator">
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidatorPass" runat="server"
                                            ControlToValidate="tbPassword"
                                            Display="Dynamic"
                                            ErrorMessage="Inserire Password"
                                            ValidationGroup="LoginAccesso"></asp:RequiredFieldValidator>
                                    </div>
                                </fieldset>

                                <div class="ks-auth-links text-end">
                                    <a id="hlRemind" href="remind.aspx" class="link body-text-3">Password persa?</a>
                                </div>

                            </div>

                            <asp:Button
                                ID="btnLogin"
                                runat="server"
                                Text="Login"
                                CssClass="tf-btn w-100 text-white"
                                OnClick="btnLogin_Click"
                                CausesValidation="True"
                                ValidationGroup="LoginAccesso"
                                UseSubmitBehavior="false"
                                Visible="True" />

                            <div class="mt-3 text-center">
                                <asp:Label ID="lblLogin" runat="server" Font-Size="8pt"
                                    ForeColor="Red" Font-Bold="True" EnableViewState="False"></asp:Label>
                            </div>

                            <p class="body-text-3 text-center mt-3 mb-0">
                                Non hai un account?
                                <a id="hlRegistrati" href="registrazione.aspx" class="text-primary">Registrati</a>
                            </p>
                        </div>

                    </div>
                </div>
            </div>
        </div>
    </section>

</asp:Content>

<asp:Content ID="ScriptsContent" ContentPlaceHolderID="ScriptsContent" runat="server">
    <script>
        (function () {
            function bindLoginPasswordToggle() {
                var input = document.getElementById('<%= tbPassword.ClientID %>');
                var button = document.getElementById('btnToggleLoginPassword');

                if (!input || !button) {
                    return;
                }

                button.addEventListener('click', function () {
                    var isVisible = input.getAttribute('type') === 'text';
                    input.setAttribute('type', isVisible ? 'password' : 'text');
                    button.setAttribute('aria-pressed', isVisible ? 'false' : 'true');
                    button.setAttribute('aria-label', isVisible ? 'Mostra password' : 'Nascondi password');
                    button.textContent = isVisible ? 'Mostra' : 'Nascondi';
                });
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', bindLoginPasswordToggle);
            } else {
                bindLoginPasswordToggle();
            }
        }());
    </script>
</asp:Content>
