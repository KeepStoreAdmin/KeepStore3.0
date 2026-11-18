<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="login.aspx.vb" Inherits="Login" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Accedi
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style>
        /* KS-QA-BROWSER-1A - pagina di accesso: due riquadri piatti (accesso + nuovo cliente), un solo pulsante principale ben visibile, bersagli da 44 px. */
        .ks-login {
            display: grid;
            grid-template-columns: minmax(0, 1fr);
            gap: 20px;
            max-width: 960px;
            margin: 0 auto;
        }

        .ks-login__panel {
            min-width: 0;
            padding: 24px 20px;
            background: #fff;
            box-shadow: 5px 6px 30px 0 rgba(0, 0, 0, .1);
        }

        .ks-login__title {
            margin: 0 0 6px;
            font-size: 26px;
            font-weight: 600;
            line-height: 1.2;
        }

        .ks-login__lead {
            margin: 0 0 20px;
            color: #595959;
            font-size: 15px;
        }

        .ks-login__field {
            margin: 0 0 16px;
            padding: 0;
            border: 0;
        }

        .ks-login__field label {
            display: block;
            margin-bottom: 6px;
            font-size: 14px;
            font-weight: 600;
        }

        .ks-login__field .form-control {
            width: 100%;
            min-height: 48px;
            padding: 10px 14px;
            border: 1px solid #8a8a8a;
            border-radius: 0;
            background: #fff;
            color: #1f2933;
            font-size: 16px;
        }

        .ks-login__field .form-control:focus {
            border-color: var(--primary, #D80027);
            box-shadow: 0 0 0 2px rgba(216, 0, 39, .18);
        }

        .ks-login-password-wrap {
            position: relative;
        }

        .ks-login-password-wrap .form-control {
            padding-right: 6.5rem;
        }

        #<%= tbPassword.ClientID %>::-ms-reveal,
        #<%= tbPassword.ClientID %>::-ms-clear {
            display: none;
        }

        .ks-login-password-toggle {
            position: absolute;
            top: 2px;
            right: 2px;
            bottom: 2px;
            min-width: 88px;
            padding: 0 12px;
            border: 0;
            background: #f2f2f2;
            color: #1f2933;
            font-size: 14px;
            font-weight: 600;
        }

        .ks-login-password-toggle:focus-visible {
            outline: 2px solid var(--focus-ring, #B8001F);
            outline-offset: -2px;
        }

        .ks-login__error {
            display: block;
            margin-top: 6px;
            color: #b00020;
            font-size: 14px;
            font-weight: 600;
        }

        .ks-login__row {
            display: flex;
            justify-content: flex-end;
            margin: -4px 0 18px;
        }

        .ks-login__row a {
            display: inline-flex;
            align-items: center;
            min-height: 44px;
            color: #1f2933;
            font-size: 14px;
            text-decoration: underline;
        }

        .ks-login__submit.tf-btn {
            width: 100%;
            min-height: 52px;
            border-radius: 0;
            font-size: 16px;
        }

        .ks-login__message {
            min-height: 22px;
            margin-top: 12px;
            color: #b00020;
            font-size: 14px;
            font-weight: 600;
        }

        .ks-login__panel--new {
            display: flex;
            flex-direction: column;
            background: #f7f7f7;
            box-shadow: none;
        }

        .ks-login__benefits {
            margin: 0 0 20px;
            padding: 0;
            list-style: none;
        }

        .ks-login__benefits li {
            position: relative;
            padding: 6px 0 6px 28px;
            font-size: 15px;
        }

        .ks-login__benefits li::before {
            content: "";
            position: absolute;
            top: 12px;
            left: 4px;
            width: 12px;
            height: 7px;
            border-left: 2px solid var(--primary, #D80027);
            border-bottom: 2px solid var(--primary, #D80027);
            transform: rotate(-45deg);
        }

        .ks-login__register.tf-btn {
            min-height: 48px;
            margin-top: auto;
            border-radius: 0;
        }

        @media (min-width: 768px) {
            .ks-login {
                grid-template-columns: minmax(0, 1.1fr) minmax(0, .9fr);
                gap: 28px;
            }

            .ks-login__panel {
                padding: 32px;
            }
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
            <div class="ks-login">

                <asp:Panel ID="pnlLogin" runat="server" CssClass="ks-login__panel ks-auth-card" DefaultButton="btnLogin">
                    <h1 class="ks-login__title">Accedi</h1>
                    <p class="ks-login__lead">Entra con le credenziali del tuo account per vedere ordini, prezzi riservati e documenti.</p>

                    <fieldset class="ks-login__field">
                        <asp:Label ID="lblUsername" runat="server" Text="Username" Visible="True" AssociatedControlID="tbUsername"></asp:Label>
                        <asp:TextBox ID="tbUsername" CssClass="form-control" AutoPostBack="false" autocomplete="username" autocapitalize="none" spellcheck="false" runat="server" Visible="True"></asp:TextBox>
                        <asp:RequiredFieldValidator ID="RequiredFieldValidatorUser" runat="server"
                            ControlToValidate="tbUsername"
                            Display="Dynamic"
                            CssClass="ks-login__error"
                            ErrorMessage="Inserisci lo username"
                            ValidationGroup="LoginAccesso"></asp:RequiredFieldValidator>
                    </fieldset>

                    <fieldset class="ks-login__field">
                        <asp:Label ID="lblPassword" runat="server" Text="Password" Visible="True" AssociatedControlID="tbPassword"></asp:Label>
                        <div class="ks-login-password-wrap">
                            <asp:TextBox ID="tbPassword" CssClass="form-control" AutoPostBack="false" TextMode="Password" autocomplete="current-password" runat="server" Visible="True"></asp:TextBox>
                            <button type="button"
                                id="btnToggleLoginPassword"
                                class="ks-login-password-toggle"
                                aria-controls="<%= tbPassword.ClientID %>"
                                aria-pressed="false"
                                aria-label="Mostra password">
                                Mostra
                            </button>
                        </div>
                        <asp:RequiredFieldValidator ID="RequiredFieldValidatorPass" runat="server"
                            ControlToValidate="tbPassword"
                            Display="Dynamic"
                            CssClass="ks-login__error"
                            ErrorMessage="Inserisci la password"
                            ValidationGroup="LoginAccesso"></asp:RequiredFieldValidator>
                    </fieldset>

                    <div class="ks-login__row">
                        <a id="hlRemind" href="remind.aspx">Password dimenticata?</a>
                    </div>

                    <asp:Button
                        ID="btnLogin"
                        runat="server"
                        Text="Accedi"
                        CssClass="tf-btn ks-login__submit"
                        OnClick="btnLogin_Click"
                        CausesValidation="True"
                        ValidationGroup="LoginAccesso"
                        UseSubmitBehavior="false"
                        Visible="True" />

                    <div class="ks-login__message" role="alert">
                        <asp:Label ID="lblLogin" runat="server" EnableViewState="False"></asp:Label>
                    </div>
                </asp:Panel>

                <aside class="ks-login__panel ks-login__panel--new" aria-labelledby="ksLoginNewTitle">
                    <h2 id="ksLoginNewTitle" class="ks-login__title">Nuovo cliente?</h2>
                    <p class="ks-login__lead">Crea un account gratuito in pochi minuti.</p>
                    <ul class="ks-login__benefits">
                        <li>Segui i tuoi ordini e le spedizioni</li>
                        <li>Ritrovi fatture, DDT e documenti</li>
                        <li>Paghi online gli ordini in sospeso</li>
                        <li>Salvi indirizzi e prodotti preferiti</li>
                    </ul>
                    <a id="hlRegistrati" href="registrazione.aspx" class="tf-btn btn-line ks-login__register">Crea un account</a>
                </aside>

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
