<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="remind.aspx.vb" Inherits="Remind" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Recupero dati di accesso
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        #tabellaReminder {
            margin-top: 30px;
        }

        /* mini spinner per operazione in corso (invio email) */
        #remind-spinner {
            margin-top: 20px;
            text-align: center;
            display: none;
        }

        #remind-spinner img {
            width: 40px;
            height: 40px;
        }

        #remind-spinner p {
            margin-top: 10px;
            font-size: 0.9rem;
            color: #555;
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

    <!-- SPINNER DI PAGINA -->
    <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel">
        <div class="ks-spinner-circle"></div>
        <div>Caricamento pagina in corso...</div>
    </asp:Panel>

    <!-- CONTENUTO PRINCIPALE -->
    <asp:Panel ID="pnlContent" runat="server" Style="display:none;">

        <h1 align="center">Non ricordi i tuoi dati d'accesso al sito?</h1>

        <!-- BOTTONE TORNA A MY ACCOUNT -->
        <div style="text-align:center; margin-bottom:20px;">
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

        <div class="ks-table" id="tabellaReminder">
            <div class="ks-sector" style="margin-top:10px">
                <div class="ks-col">
                    <div class="ks-row login-content login-label">
                        <asp:Label ID="lblUsername" runat="server" 
                                   Text="Inserisci il tuo indirizzo Email e te li spediremo!" 
                                   Visible="True"></asp:Label>
                    </div>
                </div>
            </div>

            <div class="ks-sector-no-flex">
                <div class="ks-col">
                    <div class="ks-row login-content" style="text-align:right">
                        <i id="login-email-icon" class="fa fa-envelope fa-3x"></i>
                    </div>
                    <div class="ks-row login-content">
                    </div>
                </div>
                <div class="ks-col">
                    <div class="ks-row login-content" style="width:350px">
                        <asp:TextBox ID="tbEmail" CssClass="form-control" AutoPostBack="false" 
                                     runat="server" Visible="True"></asp:TextBox>
                    </div>
                    <div class="ks-row login-content validator">
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
                </div>
            </div>

            <div class="ks-sector" style="margin-top:20px">
                <div class="ks-col">
                    <div class="ks-row login-content" style="text-align:center">
                        <asp:Button 
                            ID="btInvia" 
                            CssClass="btnStandardColor btn" 
                            CausesValidation="True" 
                            Visible="true" 
                            runat="server" 
                            Text="Invia dati d'accesso" 
                            PostBackUrl="remind.aspx" />
                    </div>
                    <div class="ks-row login-content" style="text-align:center">
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

    </asp:Panel>

</asp:Content>
