<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="accessonegato.aspx.vb" Inherits="accessonegato" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Accedi per continuare
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
                                <h1 id="ksAccessDeniedTitle" class="ks-auth-title h4 fw-semibold">Accedi per continuare</h1>
                            </div>
                        </div>

                        <%-- AUTH-SESSION-EXPIRED-NOTICE-1A: la pagina dice perche si e fuori (accesso richiesto o sessione scaduta) e promette il ritorno solo quando esiste. --%>
                        <p class="body-text-3 mb-3">
                            Per vedere questa pagina devi accedere con il tuo account.
                        </p>
                        <p class="body-text-3 mb-3">
                            Se avevi gi&agrave; fatto l'accesso, la sessione &egrave; scaduta per inattivit&agrave; o per un aggiornamento del sito. Quello che non avevi ancora salvato va inserito di nuovo.
                        </p>
                        <asp:PlaceHolder ID="phReturnPromise" runat="server" Visible="false">
                            <p class="body-text-3 mb-4">Dopo l'accesso tornerai alla pagina che stavi aprendo.</p>
                        </asp:PlaceHolder>

                        <div class="d-flex flex-wrap gap-2">
                            <asp:HyperLink ID="hlLogin" runat="server" CssClass="tf-btn text-white" NavigateUrl="~/login.aspx">Accedi</asp:HyperLink>
                            <asp:HyperLink ID="hlHome" runat="server" CssClass="tf-btn btn-line" NavigateUrl="~/Default.aspx">Torna alla home</asp:HyperLink>
                            <asp:HyperLink ID="hlReturn" runat="server" CssClass="tf-btn btn-gray" Visible="false">Torna alla pagina richiesta</asp:HyperLink>
                        </div>

                        <hr class="my-4" />

                        <p class="small text-muted mb-0">
                            Se hai gi&agrave; fatto l'accesso e vedi ancora questa pagina, il contenuto richiesto non &egrave; disponibile per il tuo account: torna alla home o contatta l'assistenza.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
