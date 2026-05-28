<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="my-account-address.aspx.vb" Inherits="my_account_address" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Indirizzi
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <div class="ks-address-page">

        <div class="tf-sp-1 pb-0">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="myaccount.aspx" class="text">Account</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Indirizzi</span>
                </div>
            </div>
        </div>

        <section class="tf-sp-2">
            <div class="myaccount-content account-address">
                <div class="d-flex justify-content-between align-items-start flex-wrap gap-3 mb-4">
                    <div>
                        <p class="text-uppercase text-main-2 fw-semibold mb-2">Area cliente</p>
                        <h1 class="h4 fw-semibold mb-2">I tuoi indirizzi</h1>
                        <div class="body-small text-main-2">
                            Consulta i dati di fatturazione e accedi alla gestione legacy delle destinazioni alternative.
                        </div>
                    </div>
                    <div class="d-flex flex-wrap gap-2">
                        <a href="datiutente.aspx?edit=1" class="tf-btn btn-fill">Modifica dati</a>
                        <a href="datiutente.aspx?edit=1&amp;tab=addr" class="tf-btn btn-line">Gestisci destinazioni</a>
                    </div>
                </div>

                <asp:SqlDataSource ID="sdsUtente" runat="server"
                    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT u.RagioneSociale, u.Indirizzo, u.Cap, u.Citta, u.Provincia, u.Nazione, u.Telefono, u.Cellulare, u.email FROM utenti u INNER JOIN vlogin v ON v.utentiid=u.id WHERE v.id=?LoginId">
                    <SelectParameters>
                        <asp:SessionParameter Name="LoginId" SessionField="LoginId" Type="Int32" />
                    </SelectParameters>
                </asp:SqlDataSource>

                <asp:FormView ID="fvAddr" runat="server" DataSourceID="sdsUtente" DefaultMode="ReadOnly" RenderOuterTable="false">
                    <ItemTemplate>
                        <div class="row g-4">
                            <div class="col-12 col-xl-7">
                                <div class="card h-100">
                                    <div class="card-header py-3 d-flex justify-content-between align-items-center gap-2 flex-wrap">
                                        <div>
                                            <span class="fw-semibold">Indirizzo di fatturazione</span>
                                            <div class="text-muted small">Usato come riferimento principale del profilo cliente.</div>
                                        </div>
                                        <span class="badge bg-light text-dark border">Predefinito</span>
                                    </div>
                                    <div class="card-body">
                                        <div class="row g-3">
                                            <div class="col-12">
                                                <div class="text-muted small">Intestazione</div>
                                                <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("RagioneSociale"))), "Non indicato", Convert.ToString(Eval("RagioneSociale"))) %></div>
                                            </div>
                                            <div class="col-12">
                                                <div class="text-muted small">Indirizzo</div>
                                                <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("Indirizzo"))), "Non indicato", Convert.ToString(Eval("Indirizzo"))) %></div>
                                            </div>
                                            <div class="col-6 col-md-3">
                                                <div class="text-muted small">CAP</div>
                                                <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("Cap"))), "Non indicato", Convert.ToString(Eval("Cap"))) %></div>
                                            </div>
                                            <div class="col-6 col-md-5">
                                                <div class="text-muted small">Citta</div>
                                                <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("Citta"))), "Non indicata", Convert.ToString(Eval("Citta"))) %></div>
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <div class="text-muted small">Provincia</div>
                                                <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("Provincia"))), "-", Convert.ToString(Eval("Provincia"))) %></div>
                                            </div>
                                            <div class="col-6 col-md-2">
                                                <div class="text-muted small">Nazione</div>
                                                <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("Nazione"))), "-", Convert.ToString(Eval("Nazione"))) %></div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="col-12 col-xl-5">
                                <div class="card h-100">
                                    <div class="card-header py-3">
                                        <span class="fw-semibold">Contatti e destinazioni</span>
                                    </div>
                                    <div class="card-body d-flex flex-column gap-3">
                                        <div>
                                            <div class="text-muted small">Email</div>
                                            <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("email"))), "Non indicata", Convert.ToString(Eval("email"))) %></div>
                                        </div>
                                        <div>
                                            <div class="text-muted small">Telefono</div>
                                            <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("Telefono"))), "Non indicato", Convert.ToString(Eval("Telefono"))) %></div>
                                        </div>
                                        <div>
                                            <div class="text-muted small">Cellulare</div>
                                            <div class="fw-medium"><%#: If(String.IsNullOrWhiteSpace(Convert.ToString(Eval("Cellulare"))), "Non indicato", Convert.ToString(Eval("Cellulare"))) %></div>
                                        </div>
                                        <div class="border-top pt-3">
                                            <div class="fw-semibold mb-1">Destinazioni alternative</div>
                                            <p class="body-small text-main-2 mb-3">
                                                Le destinazioni di spedizione restano gestite dal pannello dati legacy.
                                            </p>
                                            <a href="datiutente.aspx?edit=1&amp;tab=addr" class="tf-btn btn-line w-100 justify-content-center">Gestisci destinazioni</a>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </ItemTemplate>
                    <EmptyDataTemplate>
                        <div class="card">
                            <div class="card-body">
                                <h2 class="h5 fw-semibold mb-2">Nessun indirizzo disponibile</h2>
                                <p class="body-small text-main-2 mb-3">Non risultano dati indirizzo associati al profilo corrente.</p>
                                <a href="datiutente.aspx?edit=1" class="tf-btn btn-fill">Modifica dati</a>
                            </div>
                        </div>
                    </EmptyDataTemplate>
                </asp:FormView>

            </div>
        </section>

    </div>

</asp:Content>
