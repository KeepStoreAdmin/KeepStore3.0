<%@ Page Language="VB" MasterPageFile="~/Public/ui/master/Site.master" AutoEventWireup="false" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Accesso negato
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <section class="tf-sp-2 ks-access-denied">
        <div class="container">
            <div class="row justify-content-center">
                <div class="col-lg-7 col-md-9">
                    <div class="card p-4 p-md-5">
                        <div class="d-flex align-items-center gap-2 mb-2">
                            <span class="badge bg-danger-subtle text-danger-emphasis">403</span>
                            <h1 class="h5 mb-0 fw-semibold">Accesso negato</h1>
                        </div>

                        <p class="mb-3">
                            Non hai i permessi per visualizzare questa pagina oppure la sessione è scaduta.
                        </p>

                        <div class="d-flex flex-wrap gap-2">
                            <a href="login.aspx" class="btn btn-primary">Accedi</a>
                            <a href="Default.aspx" class="btn btn-outline-secondary">Torna alla Home</a>
                        </div>

                        <hr class="my-4" />

                        <p class="small text-muted mb-0">
                            Se pensi sia un errore, contatta l'assistenza.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
