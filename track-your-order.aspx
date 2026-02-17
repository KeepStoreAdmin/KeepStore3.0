<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="track-your-order.aspx.vb" Inherits="track_your_order" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">Traccia il tuo ordine</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <!-- Breadcrumbs (Onsus) -->
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Traccia ordine</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-section-title mb_30">
                <h2 class="title">Traccia il tuo ordine</h2>
                <p class="text-main-2 mt-2">Inserisci il numero d’ordine e l’email usata in fase di acquisto.</p>
            </div>

            <div class="row justify-content-center">
                <div class="col-lg-7">
                    <div class="tf-form-track">

                        <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="alert alert-warning mb-3">
                            <asp:Literal ID="litMsg" runat="server" />
                        </asp:Panel>

                        <div class="row g-3">
                            <div class="col-md-6">
                                <label class="body-md-2 mb-2" for="<%= txtOrderNumber.ClientID %>">Numero ordine</label>
                                <asp:TextBox ID="txtOrderNumber" runat="server" CssClass="form-control" placeholder="Es. 12345" />
                            </div>
                            <div class="col-md-6">
                                <label class="body-md-2 mb-2" for="<%= txtEmail.ClientID %>">Email</label>
                                <asp:TextBox ID="txtEmail" runat="server" CssClass="form-control" TextMode="Email" placeholder="nome@dominio.it" />
                            </div>
                        </div>

                        <div class="mt-3">
                            <asp:Button ID="btnTrack" runat="server" Text="Traccia" CssClass="tf-btn btn-fill w-100" OnClick="btnTrack_Click" />
                        </div>

                        <asp:Panel ID="pnlResult" runat="server" Visible="false" CssClass="mt-4">
                            <div class="tf-page-title style-2 mb-3">
                                <div class="heading text-center">Risultato</div>
                            </div>

                            <div class="tf-cart-summery">
                                <div class="tf-cart-summery-total mb-2">
                                    <span class="title">Ordine</span>
                                    <span class="total-price"><asp:Literal ID="litOrderId" runat="server" /></span>
                                </div>

                                <ul class="tf-cart-summery-list">
                                    <li>
                                        <span class="text">Data</span>
                                        <span class="text"><asp:Literal ID="litDate" runat="server" /></span>
                                    </li>
                                    <li>
                                        <span class="text">Stato</span>
                                        <span class="text"><asp:Literal ID="litStatus" runat="server" /></span>
                                    </li>
                                    <li>
                                        <span class="text">Totale</span>
                                        <span class="text fw-semibold"><asp:Literal ID="litTotal" runat="server" /></span>
                                    </li>
                                    <li>
                                        <span class="text">Pagamento</span>
                                        <span class="text"><asp:Literal ID="litPayment" runat="server" /></span>
                                    </li>
                                </ul>

                                <div class="d-grid gap-2 mt-3">
                                    <asp:HyperLink ID="hlDetail" runat="server" CssClass="tf-btn btn-line w-100">Vedi dettaglio</asp:HyperLink>
                                    <asp:HyperLink ID="hlTracking" runat="server" CssClass="tf-btn btn-fill w-100" Target="_blank" Visible="false">Apri tracking</asp:HyperLink>
                                </div>
                            </div>

                            <div class="mt-3 text-main-2">
                                Se hai un account, puoi consultare tutti gli ordini nella tua <a class="text-secondary link" href="myaccount.aspx">Area personale</a>.
                            </div>
                        </asp:Panel>

                    </div>
                </div>
            </div>
        </div>
    </section>

    
</asp:Content>
