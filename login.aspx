<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="login.aspx.vb" Inherits="Login" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Accedi
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="tf-breadcrumb">
        <div class="container">
            <ul class="breadcrumb-list">
                <li><a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a></li>
                <li><span class="text">Accedi</span></li>
            </ul>
        </div>
    </div>

    <section class="flat-spacing-2">
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
                                            ErrorMessage="Inserire Username"></asp:RequiredFieldValidator>
                                    </div>
                                </fieldset>

                                <fieldset>
                                    <label class="fw-semibold body-md-2">
                                        <asp:Label ID="lblPassword" runat="server" Text="Password *" Visible="True"></asp:Label>
                                    </label>
                                    <asp:TextBox ID="tbPassword" CssClass="form-control" AutoPostBack="false" TextMode="Password" runat="server" Visible="True"></asp:TextBox>
                                    <div class="validator">
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidatorPass" runat="server"
                                            ControlToValidate="tbPassword"
                                            Display="Dynamic"
                                            ErrorMessage="Inserire Password"></asp:RequiredFieldValidator>
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
