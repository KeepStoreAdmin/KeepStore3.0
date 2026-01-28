<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="remind.aspx.vb" Inherits="Remind" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Recupero dati di accesso
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        /* mini spinner per operazione in corso (invio email) */
        #remind-spinner {
            margin-top: 16px;
            text-align: center;
            display: none;
        }

        #remind-spinner img {
            width: 40px;
            height: 40px;
        }

        #remind-spinner p {
            margin-top: 10px;
            font-size: 0.95rem;
            color: #555;
        }

        /* Spinner pagina */
        .ks-loading-panel {
            border: 1px solid rgba(0,0,0,.08);
            background-color: #fff;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
            border-radius: 12px;
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

        /* Card stile Onsus */
        .ks-auth-card {
            padding: 28px;
            border: 1px solid rgba(0,0,0,.08);
            border-radius: 12px;
            background: #fff;
        }

        .ks-auth-card .validator,
        .ks-auth-card .validator span,
        .ks-auth-card .validator div {
            display: block;
            margin-top: 6px;
        }

        .ks-auth-card .validator,
        .ks-auth-card .validator span {
            color: #dc3545;
            font-weight: 600;
            font-size: 0.9rem;
        }
    </style>

    <script type="text/javascript">
        // Spinner invio email (già presente)
        JQ(document).ready(function () {
            var btn = JQ('#<%= btInvia.ClientID %>');

            btn.on('click', function () {
                // se esiste la validazione client ASP.NET, la rispetto
                if (typeof (Page_ClientValidate) === 'function') {
                    if (!Page_ClientValidate()) {
                        return;
                    }
                }
                JQ('#remind-spinner').show();
            });
        });
    </script>

    <script type="text/javascript">
        // Spinner di pagina (caricamento + back)
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

    <div class="tf-breadcrumb">
        <div class="container">
            <ul class="breadcrumb-list">
                <li><a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a></li>
                <li><a href="login.aspx" class="text">Accedi</a></li>
                <li><span class="text">Recupero accesso</span></li>
            </ul>
        </div>
    </div>

    <section class="flat-spacing-2">
        <div class="container">

            <!-- SPINNER DI PAGINA -->
            <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel">
                <div class="ks-spinner-circle"></div>
                <div>Caricamento pagina in corso...</div>
            </asp:Panel>

            <!-- CONTENUTO PRINCIPALE -->
            <asp:Panel ID="pnlContent" runat="server" Style="display:none;">

                <div class="row justify-content-center">
                    <div class="col-xl-6 col-lg-7 col-md-9">
                        <div class="ks-auth-card">

                            <h5 class="title fw-semibold mb-2">Recupero dati di accesso</h5>
                            <p class="body-text-3 mb-4">Inserisci il tuo indirizzo email e riceverai i dati di accesso.</p>

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

                            <!-- SPINNER OPERAZIONE IN CORSO (invio email) -->
                            <div id="remind-spinner">
                                <img src="Public/Images/loader.gif" alt="Operazione in corso..." />
                                <p>Operazione in corso, attendere il completamento della richiesta...</p>
                            </div>

                            <div class="form-log">
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
                                                Text="Indirizzo Email non presente in archivio!"
                                                Visible="False">
                                            </asp:Label>

                                            <asp:RequiredFieldValidator ID="RequiredFieldValidatorUser"
                                                runat="server"
                                                ControlToValidate="tbEmail"
                                                ErrorMessage="Inserire Email">
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
                                    Text="Invia dati d'accesso"
                                    PostBackUrl="remind.aspx" />

                                <div class="mt-3 text-center">
                                    <asp:Label ID="lblOk" runat="server"
                                        Font-Size="8pt"
                                        Visible="false"
                                        Text="I tuoi dati d'accesso al sito sono stati inviati correttamente.<br><br>Attendi qualche istante e controlla la tua email."
                                        Font-Bold="True"
                                        EnableViewState="False">
                                    </asp:Label>
                                </div>
                            </div>

                        </div>
                    </div>
                </div>

            </asp:Panel>

        </div>
    </section>

</asp:Content>
