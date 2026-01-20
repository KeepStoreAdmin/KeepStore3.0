<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="cambiapassword.aspx.vb" Inherits="cambiapassword" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Cambia Password
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <script type="text/javascript">
    (function () {
        function preventEnter(e) {
            e = e || window.event;
            var key = e.key || e.keyCode;
            if (key === 'Enter' || key === 13) {
                if (e.preventDefault) e.preventDefault();
                e.returnValue = false;
                return false;
            }
            return true;
        }

        document.addEventListener('DOMContentLoaded', function () {
            var box = document.getElementById('tRegistrazione');
            if (!box) return;
            box.addEventListener('keydown', function (ev) {
                preventEnter(ev);
            }, true);
        });
    })();
    </script>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <section class="tf-sp-2">
        <div class="container">

            <div class="row">
                <div class="col-lg-3">
                    <div class="my-account-nav">
                        <ul class="my-account-nav-list">
                            <li><a href="my-account.aspx" class="my-account-nav-item">Dashboard</a></li>
                            <li><a href="documenti.aspx" class="my-account-nav-item">I miei ordini</a></li>
                            <li><a href="wishlist.aspx" class="my-account-nav-item">Wishlist</a></li>
                            <li><a href="datiutente.aspx" class="my-account-nav-item">Dati account</a></li>
                            <li><a href="cambiapassword.aspx" class="my-account-nav-item active">Cambia password</a></li>
                            <li><a href="logout.aspx" class="my-account-nav-item">Logout</a></li>
                        </ul>
                    </div>
                </div>

                <div class="col-lg-9">
                    <div class="my-account-content">

                        <div class="wrap">
                            <h4 class="fw-semibold mb-20">Cambia Password</h4>
                            <asp:Label ID="lblEsito" runat="server" EnableViewState="false" CssClass="text-danger"></asp:Label>


                            <div class="mb-20">
                                <p>
                                    Gentile utente di <asp:Label ID="lblSito" runat="server" Text=""></asp:Label>,<br />
                                    per motivi di sicurezza ti chiediamo di aggiornare la password (scadenza impostata: <asp:Label ID="lblMesi" runat="server" Text=""></asp:Label> mesi).
                                </p>
                            </div>

                            <asp:ValidationSummary ID="ValidationSummary1" runat="server" ValidationGroup="registrazione" DisplayMode="BulletList" CssClass="text-danger" />

                            <asp:Panel ID="tRegistrazione" runat="server" ClientIDMode="Static">
                                <div class="def form-reset-password">

                                    <fieldset>
                                        <asp:TextBox ID="tbUsername" runat="server" Enabled="False" placeholder="Username"></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator1" runat="server" ControlToValidate="tbUsername" ErrorMessage="Username" ValidationGroup="registrazione" Display="Dynamic" CssClass="text-danger" />
                                    </fieldset>

                                    <asp:TextBox ID="tbEmail" runat="server" Visible="False"></asp:TextBox>

                                    <fieldset>
                                        <asp:TextBox ID="tbPasswordVecchia" runat="server" TextMode="Password" placeholder="Vecchia password" AutoCompleteType="Disabled"></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator5" runat="server" ControlToValidate="tbPasswordVecchia" ErrorMessage="Vecchia Password" ValidationGroup="registrazione" Display="Dynamic" CssClass="text-danger" />

                                        <asp:CustomValidator ID="cvOldPassword" runat="server" ControlToValidate="tbPasswordVecchia" ErrorMessage="Vecchia Password errata" ValidationGroup="registrazione" Display="Dynamic" CssClass="text-danger" OnServerValidate="cvOldPassword_ServerValidate" />
                                    </fieldset>

                                    <fieldset>
                                        <asp:TextBox ID="tbPasswordNuova" runat="server" TextMode="Password" placeholder="Nuova password" AutoCompleteType="Disabled"></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbPasswordNuova" ErrorMessage="Nuova Password" ValidationGroup="registrazione" Display="Dynamic" CssClass="text-danger" />
                                        <asp:RegularExpressionValidator ID="RegularExpressionValidator1" runat="server" ControlToValidate="tbPasswordNuova" ErrorMessage="La password deve contenere almeno 8 caratteri" ValidationExpression="[\w\s]{8,}" ValidationGroup="registrazione" Display="Dynamic" CssClass="text-danger" />
                                    </fieldset>

                                    <fieldset>
                                        <asp:TextBox ID="tbPasswordConferma" runat="server" TextMode="Password" placeholder="Conferma password" AutoCompleteType="Disabled"></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator3" runat="server" ControlToValidate="tbPasswordConferma" ErrorMessage="Conferma password" ValidationGroup="registrazione" Display="Dynamic" CssClass="text-danger" />
                                        <asp:CompareValidator ID="CompareValidator1" runat="server" ControlToValidate="tbPasswordConferma" ControlToCompare="tbPasswordNuova" ErrorMessage="La password non coincide" ValidationGroup="registrazione" Display="Dynamic" CssClass="text-danger" />
                                    </fieldset>

                                    <asp:TextBox ID="tbPasswordOK" runat="server" Visible="False"></asp:TextBox>

                                    <div class="box-btn">
                                        <asp:Button ID="btRegistrati" runat="server" Text="CAMBIA PASSWORD" Width="100%" CssClass="tf-btn btn-large" ValidationGroup="registrazione" />
                                    </div>
                                </div>
                            </asp:Panel>

                            <asp:Panel ID="tAggiorna" runat="server" Visible="False">
                                <div class="def form-reset-password">
                                    <div class="alert alert-success" role="alert">
                                        Password cambiata correttamente.
                                    </div>
                                    <div class="box-btn">
                                        <a class="tf-btn btn-large" href="my-account.aspx"><span class="text-white">Vai al tuo account</span></a>
                                    </div>
                                </div>
                            </asp:Panel>

                        </div>

                    </div>
                </div>
            </div>

        </div>
    </section>

</asp:Content>
