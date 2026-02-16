<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" Inherits="System.Web.UI.Page" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">Traccia il tuo ordine</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
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
                <div class="col-lg-6">
                    <div class="tf-form-track">
                        <div class="mb-3">
                            <label class="body-md-2 mb-2" for="orderNumber">Numero ordine</label>
                            <input id="orderNumber" name="orderNumber" type="text" class="form-control" placeholder="Es. 12345" />
                        </div>
                        <div class="mb-3">
                            <label class="body-md-2 mb-2" for="orderEmail">Email</label>
                            <input id="orderEmail" name="orderEmail" type="email" class="form-control" placeholder="nome@dominio.it" />
                        </div>
                        <button type="button" class="tf-btn btn-fill w-100" onclick="alert('Funzione in attivazione: collega questa pagina alla tua logica ordini.');">
                            Traccia
                        </button>
                        <div class="mt-3 text-main-2">
                            In alternativa puoi consultare lo stato ordine nella tua <a class="text-secondary link" href="myaccount.aspx">Area personale</a>.
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
