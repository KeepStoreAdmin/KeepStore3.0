<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="login.aspx.vb" Inherits="Login" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Accedi
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style>
        #tabellaLogin {
            margin-top: 30px;
        }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <h1 align="center">Accedi</h1>

    <div class="ks-table" id="tabellaLogin">

        <!-- USERNAME -->
        <div class="ks-sector" style="margin-top:10px">
            <div class="ks-col">
                <div class="ks-row login-content login-label">
                    <asp:Label ID="lblUsername" runat="server" Text="USERNAME:" Visible="True"></asp:Label>
                </div>
            </div>
        </div>

        <div class="ks-sector-no-flex">
            <div class="ks-col">
                <div class="ks-row login-content" style="text-align:right">
                    <i id="login-user-icon" class="fa fa-user-circle fa-3x"></i>
                </div>
                <div class="ks-row login-content">
                </div>
            </div>
            <div class="ks-col">
                <div class="ks-row login-content">
                    <asp:TextBox ID="tbUsername" CssClass="form-control" AutoPostBack="false" runat="server" Visible="True"></asp:TextBox>
                </div>
                <div class="ks-row login-content validator">
                    <asp:RequiredFieldValidator ID="RequiredFieldValidatorUser" runat="server"
                        ControlToValidate="tbUsername"
                        Display="Dynamic"
                        ErrorMessage="Inserire Username"></asp:RequiredFieldValidator>
                </div>
            </div>
        </div>

        <!-- PASSWORD -->
        <div class="ks-sector" style="margin-top:10px">
            <div class="ks-col">
                <div class="ks-row login-content login-label">
                    <asp:Label ID="lblPassword" runat="server" Text="PASSWORD:" Visible="True"></asp:Label>
                </div>
            </div>
        </div>

        <div class="ks-sector-no-flex">
            <div class="ks-col">
                <div class="ks-row login-content" style="text-align:right">
                    <i id="login-pass-icon" class="fa fa-key fa-3x"></i>
                </div>
                <div class="ks-row login-content">
                </div>
            </div>
            <div class="ks-col">
                <div class="ks-row login-content">
                    <asp:TextBox ID="tbPassword" CssClass="form-control" AutoPostBack="false"
                        TextMode="Password" runat="server" Visible="True"></asp:TextBox>
                </div>
                <div class="ks-row login-content validator">
                    <asp:RequiredFieldValidator ID="RequiredFieldValidatorPass" runat="server"
                        ControlToValidate="tbPassword"
                        Display="Dynamic"
                        ErrorMessage="Inserire Password"></asp:RequiredFieldValidator>
                </div>
            </div>
        </div>

        <!-- BOTTONI + LINK -->
        <div class="ks-sector" style="margin-top:20px">
            <div class="ks-col">
                <div class="ks-row login-content" style="text-align:center">
                    <asp:Button 
                        ID="btnLogin" 
                        runat="server" 
                        Text="Login"
                        CssClass="tf-btn-icon type-2 style-white" 
                        OnClick="btnLogin_Click"
                        CausesValidation="True"
                        Visible="True" />
                </div>
                <div class="ks-row login-content" style="text-align:center">
                    <asp:Label ID="lblLogin" runat="server" Font-Size="8pt"
                        ForeColor="Red" Font-Bold="True" EnableViewState="False"></asp:Label>
                </div>
                <div class="ks-row login-content" style="text-align:center">
                    <a id="hlRegistrati" href="registrazione.aspx" style="font-weight:bold;">REGISTRATI!</a>
                </div>
                <div class="ks-row login-content" style="text-align:center">
                    <a id="hlRemind" href="remind.aspx">PASSWORD PERSA?</a>
                </div>
            </div>
        </div>

    </div>

</asp:Content>
