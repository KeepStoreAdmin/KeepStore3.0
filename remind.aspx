<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="remind.aspx.vb" Inherits="Remind" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Recupero dati di accesso
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style>
        .ks-remind-confirmation {
            border: 1px solid rgba(39, 174, 96, 0.24);
            background: #f1fbf6;
            border-radius: 8px;
            padding: 24px;
            margin: 18px 0 22px;
        }

        .ks-remind-confirmation__eyebrow {
            color: #17633a;
            font-size: 1.35rem;
            font-weight: 700;
            margin-bottom: 10px;
        }

        .ks-remind-confirmation__text {
            color: #25362d;
            font-size: 1rem;
            line-height: 1.55;
            margin-bottom: 10px;
        }

        .ks-remind-confirmation__note {
            color: #4f6659;
            font-size: 0.94rem;
            line-height: 1.5;
            margin-bottom: 0;
        }

        .ks-remind-confirmation__actions {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            align-items: center;
            margin-top: 20px;
        }

        .ks-remind-new-request {
            color: inherit;
            font-weight: 600;
            text-decoration: underline;
            text-underline-offset: 3px;
        }

        .ks-remind-operation {
            display: none;
            align-items: center;
            gap: 10px;
            margin: 0 0 18px;
            color: #4f6659;
            font-size: 0.95rem;
        }

        .ks-remind-operation__spinner {
            width: 18px;
            height: 18px;
            border: 2px solid rgba(0, 0, 0, 0.12);
            border-top-color: #17633a;
            border-radius: 50%;
            animation: ks-remind-spin 0.8s linear infinite;
        }

        @keyframes ks-remind-spin {
            to { transform: rotate(360deg); }
        }
    </style>

    <script type="text/javascript">
        JQ(document).ready(function () {
            var btn = JQ('#<%= btInvia.ClientID %>');

            btn.on('click', function () {
                if (typeof (Page_ClientValidate) === 'function') {
                    if (!Page_ClientValidate()) {
                        return;
                    }
                }
                JQ('#<%= pnlOperationProgress.ClientID %>').css('display', 'flex');
            });
        });
    </script>

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

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">

    <!-- Breadcrumbs (tema) -->
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="login.aspx" class="text">Accedi</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Recupero accesso</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">

            <!-- SPINNER DI PAGINA -->
            <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel" Visible="false">
                <div class="ks-spinner-circle"></div>
                <div>Caricamento pagina in corso...</div>
            </asp:Panel>

            <!-- CONTENUTO PRINCIPALE -->
            <asp:Panel ID="pnlContent" runat="server" Style="display:block;">

                <div class="row justify-content-center">
                    <div class="col-xl-6 col-lg-7 col-md-9">
                        <div class="ks-auth-card">

                            <h5 class="title fw-semibold mb-2">Recupero accesso</h5>

                            <asp:Panel ID="pnlSentConfirmation" runat="server" Visible="false" CssClass="ks-remind-confirmation">
                                <div class="ks-remind-confirmation__eyebrow">Richiesta ricevuta</div>
                                <p class="ks-remind-confirmation__text">Se i dati inseriti sono corretti, riceverai le istruzioni per completare il reset della password.</p>
                                <p class="ks-remind-confirmation__note">Controlla anche la cartella spam o posta indesiderata. Il link sara valido per 30 minuti.</p>
                                <div class="ks-remind-confirmation__actions">
                                    <asp:HyperLink
                                        ID="hlLogin"
                                        runat="server"
                                        NavigateUrl="login.aspx"
                                        CssClass="tf-btn text-white">
                                        Vai al login
                                    </asp:HyperLink>
                                    <asp:HyperLink
                                        ID="hlNewRequest"
                                        runat="server"
                                        NavigateUrl="remind.aspx"
                                        CssClass="ks-remind-new-request">
                                        Effettua una nuova richiesta
                                    </asp:HyperLink>
                                </div>
                            </asp:Panel>

                            <asp:Panel ID="pnlRequestIntro" runat="server">
                                <p class="body-text-3 mb-4">Inserisci l'email del tuo account e il codice fiscale o la partita IVA. Se i dati sono corretti riceverai un link per impostare una nuova password.</p>

                                <!-- BOTTONE TORNA A MY ACCOUNT -->
                                <div class="mb-3">
                                    <asp:HyperLink
                                        ID="hlBackMyAccount"
                                        runat="server"
                                        NavigateUrl="myaccount.aspx"
                                        CssClass="tf-btn-icon type-2 style-white">
                                        &laquo; Torna alla pagina My Account
                                    </asp:HyperLink>
                                </div>
                            </asp:Panel>

                            <asp:Panel ID="pnlRequestForm" runat="server" CssClass="form-log">
                                <asp:Panel ID="pnlOperationProgress" runat="server" CssClass="ks-remind-operation">
                                    <span class="ks-remind-operation__spinner" aria-hidden="true"></span>
                                    <span>Richiesta in elaborazione...</span>
                                </asp:Panel>

                                <div class="form-content">
                                    <fieldset>
                                        <label class="fw-semibold body-md-2">
                                            <asp:Label ID="lblUsername" runat="server" Text="Email *" Visible="True"></asp:Label>
                                        </label>
                                        <asp:TextBox ID="tbEmail" CssClass="form-control" AutoPostBack="false" runat="server" Visible="True"></asp:TextBox>

                                        <div class="validator">
                                            <asp:RegularExpressionValidator ID="RegularExpressionValidator1"
                                                runat="server"
                                                ControlToValidate="tbEmail"
                                                ErrorMessage="Indirizzo Email non valido!"
                                                Font-Bold="True"
                                                SetFocusOnError="True"
                                                ValidationExpression="\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*"
                                                Display="Dynamic">
                                            </asp:RegularExpressionValidator>

                                            <asp:Label ID="lblError" runat="server"
                                                Font-Bold="True"
                                                ForeColor="Red"
                                                Text="Se i dati inseriti sono corretti riceverai le istruzioni per completare il reset della password."
                                                Visible="False">
                                            </asp:Label>

                                            <asp:RequiredFieldValidator ID="RequiredFieldValidatorUser"
                                                runat="server"
                                                ControlToValidate="tbEmail"
                                                ErrorMessage="Inserire Email">
                                            </asp:RequiredFieldValidator>
                                        </div>
                                    </fieldset>

                                    <fieldset>
                                        <label class="fw-semibold body-md-2">
                                            <asp:Label ID="lblFiscalCodeOrVat" runat="server" Text="Codice fiscale o Partita IVA *" Visible="True"></asp:Label>
                                        </label>
                                        <asp:TextBox ID="txtFiscalCodeOrVat" CssClass="form-control" AutoPostBack="false" runat="server" Visible="True"></asp:TextBox>

                                        <div class="validator">
                                            <asp:RequiredFieldValidator ID="RequiredFieldValidatorFiscalCodeOrVat"
                                                runat="server"
                                                ControlToValidate="txtFiscalCodeOrVat"
                                                ErrorMessage="Inserire Codice fiscale o Partita IVA">
                                            </asp:RequiredFieldValidator>
                                        </div>
                                    </fieldset>
                                </div>

                                <asp:Button
                                    ID="btInvia"
                                    CssClass="tf-btn w-100 text-white"
                                    CausesValidation="True"
                                    Visible="true"
                                    runat="server"
                                    Text="Invia link reset" />

                                <div class="mt-3 text-center">
                                    <asp:Label ID="lblOk" runat="server"
                                        Font-Size="8pt"
                                        Visible="false"
                                        Text="Se i dati inseriti sono corretti riceverai le istruzioni per completare il reset della password."
                                        Font-Bold="True"
                                        EnableViewState="False">
                                    </asp:Label>
                                </div>
                            </asp:Panel>

                        </div>
                    </div>
                </div>

            </asp:Panel>

        </div>
    </section>

</asp:Content>
