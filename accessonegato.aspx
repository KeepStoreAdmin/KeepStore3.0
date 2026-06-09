<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="accessonegato.aspx.vb" Inherits="accessonegato" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Accesso non consentito
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <section class="flat-spacing ks-access-denied" aria-labelledby="ksAccessDeniedTitle">
        <div class="container">
            <div class="row justify-content-center">
                <div class="col-lg-7 col-md-9">
                    <div class="ks-auth-card bg-white shadow-sm p-4 p-md-5">
                        <div class="ks-auth-header px-0 pt-0">
                            <div>
                                <span class="caption text-primary fw-semibold">Area riservata</span>
                                <h1 id="ksAccessDeniedTitle" class="ks-auth-title h4 fw-semibold">Accesso non consentito</h1>
                            </div>
                        </div>

                        <p class="body-text-3 mb-4">
                            Non hai i permessi necessari oppure la sessione non e' piu valida.
                        </p>

                        <div class="d-flex flex-wrap gap-2">
                            <asp:HyperLink ID="hlLogin" runat="server" CssClass="tf-btn text-white" NavigateUrl="~/login.aspx">Accedi</asp:HyperLink>
                            <asp:HyperLink ID="hlHome" runat="server" CssClass="tf-btn btn-line" NavigateUrl="~/Default.aspx">Torna alla home</asp:HyperLink>
                            <asp:HyperLink ID="hlReturn" runat="server" CssClass="tf-btn btn-gray" Visible="false">Torna alla pagina richiesta</asp:HyperLink>
                        </div>

                        <hr class="my-4" />

                        <p class="small text-muted mb-0">
                            Se pensi sia un errore, accedi di nuovo o torna alla home.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
