<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="cambiapassword.aspx.vb" Inherits="cambiapassword" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Cambia password
</asp:Content>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">



<script type="text/javascript">
(function () {
    // Evita submit involontario con ENTER nei campi password.
    document.addEventListener('DOMContentLoaded', function () {
        var box = document.getElementById('tRegistrazione');
        if (!box) return;
        box.addEventListener('keydown', function (ev) {
            var k = ev.key || ev.keyCode;
            if (k === 'Enter' || k === 13) {
                ev.preventDefault();
                return false;
            }
        }, true);
    });
})();
</script>

<!-- Breadcrumbs (tema) -->
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

<section class="tf-sp-2">
    <div class="container">

        <h4 class="fw-semibold mb-20">Cambia password</h4>

        <!-- ISTRUZIONI (visibili al cliente) -->
        <div class="ks-alert ks-alert-info ks-rules">
            <strong>Istruzioni e criteri per cambiare password</strong>
            <ul>
                <li>Inserisci la <strong>vecchia password</strong> attuale.</li>
                <li>Inserisci una <strong>nuova password</strong> e ripetila in <strong>Conferma</strong>.</li>
                <li>La nuova password deve essere lunga <strong>almeno 8 caratteri</strong> (max 25 in questa pagina).</li>
                <li>Sono ammessi solo: <strong>lettere</strong>, <strong>numeri</strong>, <strong>underscore (_)</strong> e <strong>spazi</strong>.</li>
                <li>Non sono ammessi caratteri speciali come: <strong>! @ # € % &amp; *</strong> ecc.</li>
                <li>Esempi validi: <strong>password_2026</strong>, <strong>MarioRossi 01</strong>, <strong>Abcdef12</strong>.</li>
            </ul>
            <div class="ks-small">Suggerimento: usa una password unica e non riutilizzata su altri siti.</div>
        </div>

        <asp:Literal ID="litEsito" runat="server" EnableViewState="false" />

        <asp:ValidationSummary ID="ValidationSummary1" runat="server" ValidationGroup="registrazione" DisplayMode="BulletList" CssClass="ks-alert ks-alert-danger" />

        <asp:Panel ID="tRegistrazione" runat="server" ClientIDMode="Static" CssClass="ks-box">

            <div class="ks-form-row">
                <label>Username</label>
                <asp:TextBox ID="tbUsername" runat="server" Enabled="false" MaxLength="50" />
                <asp:TextBox ID="tbEmail" runat="server" Visible="false" />
            </div>

            <div class="ks-form-row">
                <label>Vecchia password</label>
                <asp:TextBox ID="tbPasswordVecchia" runat="server" MaxLength="25" TextMode="Password" />
                <asp:RequiredFieldValidator ID="RequiredFieldValidator4" runat="server" ControlToValidate="tbPasswordVecchia" Display="Dynamic" ErrorMessage="Vecchia password obbligatoria" SetFocusOnError="True" ValidationGroup="registrazione" CssClass="ks-alert ks-alert-danger" />
                <asp:CustomValidator ID="cvOldPassword" runat="server" ControlToValidate="tbPasswordVecchia" ErrorMessage="Vecchia password errata" ValidationGroup="registrazione" Display="Dynamic" CssClass="ks-alert ks-alert-danger" OnServerValidate="cvOldPassword_ServerValidate" />
            </div>

            <div class="ks-form-row">
                <label>Nuova password</label>
                <asp:TextBox ID="tbPasswordNuova" runat="server" MaxLength="25" TextMode="Password" />
                <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbPasswordNuova" Display="Dynamic" ErrorMessage="Nuova password obbligatoria" SetFocusOnError="True" ValidationGroup="registrazione" CssClass="ks-alert ks-alert-danger" />
                <asp:RegularExpressionValidator ID="RegularExpressionValidator2" runat="server" ControlToValidate="tbPasswordNuova" Display="Dynamic" ErrorMessage="Nuova password: minimo 8 caratteri, senza caratteri speciali" SetFocusOnError="True" ValidationExpression="[\w\s]{8,}" ValidationGroup="registrazione" CssClass="ks-alert ks-alert-danger" />
            </div>

            <div class="ks-form-row">
                <label>Conferma nuova password</label>
                <asp:TextBox ID="tbPasswordConferma" runat="server" MaxLength="25" TextMode="Password" />
                <asp:RequiredFieldValidator ID="RequiredFieldValidator3" runat="server" ControlToValidate="tbPasswordConferma" Display="Dynamic" ErrorMessage="Conferma password obbligatoria" SetFocusOnError="True" ValidationGroup="registrazione" CssClass="ks-alert ks-alert-danger" />
                <asp:CompareValidator ID="CompareValidator1" runat="server" ControlToCompare="tbPasswordNuova" ControlToValidate="tbPasswordConferma" Display="Dynamic" ErrorMessage="Le password devono coincidere" SetFocusOnError="True" ValidationGroup="registrazione" CssClass="ks-alert ks-alert-danger" />
            </div>

            <!-- Campo legacy: lasciato per compatibilita' (non usato) -->
            <asp:TextBox ID="tbPasswordOK" runat="server" Visible="false" />

            <div class="ks-actions">
                <asp:Button ID="btRegistrati" runat="server" Text="CAMBIA PASSWORD" Width="220" ValidationGroup="registrazione" />
            </div>

        </asp:Panel>

        <asp:Panel ID="tAggiorna" runat="server" Visible="false" CssClass="ks-alert ks-alert-success">
            <strong>Password aggiornata correttamente.</strong>
            <div style="margin-top:10px;">
                <a class="tf-btn" href="myaccount.aspx">Vai al tuo account</a>
            </div>
        </asp:Panel>

        <!-- DIAGNOSTICA LOGGING: visibile solo se serve (riempito dal code-behind) -->
        <asp:Panel ID="pnlDiag" runat="server" Visible="false" CssClass="ks-box">
            <strong>Diagnostica (assistenza)</strong>
            <div class="ks-small">Queste informazioni servono per capire perche' la password non si aggiorna e perche' i log non vengono creati.</div>
            <div style="margin-top:10px;">
                <asp:Literal ID="litDiag" runat="server" />
            </div>
            <div class="ks-tech">
                <asp:Literal ID="litDiagTech" runat="server" />
            </div>
        </asp:Panel>

    </div>
</section>

</asp:Content>
