<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="registrazioneok.aspx.vb" Inherits="registrazioneok" %>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <meta http-equiv="refresh" content="<%= System.Web.HttpUtility.HtmlAttributeEncode("2; url=" & ConfirmationTargetUrl) %>" />

    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="login.aspx" class="text">Accedi</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Registrazione</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="row justify-content-center">
                <div class="col-xl-6 col-lg-7">
                    <div class="ks-auth-card text-center">
                        <h3 class="fw-semibold mb-10">Registrazione conclusa con successo!</h3>
                        <p class="mb-20">La registrazione &egrave; completata. L'invio dell'e-mail di conferma non &egrave; verificato in questa pagina.</p>

                        <div class="d-flex align-items-center justify-content-center gap-2 mb-20">
                            <span class="icon icon-loader"></span>
                            <span class="body-text-3"><%= System.Web.HttpUtility.HtmlEncode(ConfirmationRedirectMessage) %></span>
                        </div>

                        <div class="mt-3">
                            <a href="<%= System.Web.HttpUtility.HtmlAttributeEncode(ConfirmationTargetUrl) %>" class="tf-btn btn-fill"><%= System.Web.HttpUtility.HtmlEncode(ConfirmationActionText) %></a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

</asp:Content>
