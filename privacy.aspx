<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" Inherits="System.Web.UI.Page" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">Privacy Policy</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Privacy</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-section-title mb_30">
                <h2 class="title">Privacy Policy</h2>
                <p class="text-main-2 mt-2">Informativa ai sensi della normativa vigente (GDPR).</p>
            </div>

            <div class="row">
                <div class="col-lg-9">
                    <div class="tf-privacy">
                        <h5 class="mb-2">Titolare del trattamento</h5>
                        <p class="text-main-2">I dati sono trattati dal titolare del sito. Per richieste e diritti dell’interessato usa la pagina <a class="text-secondary link" href="Contattaci.aspx">Contatti</a>.</p>

                        <h5 class="mt-4 mb-2">Dati trattati</h5>
                        <ul class="text-main-2">
                            <li>Dati di registrazione e account (nome, email, indirizzi).</li>
                            <li>Dati di acquisto e fatturazione per evadere ordini e adempimenti fiscali.</li>
                            <li>Dati tecnici di navigazione (log, cookie tecnici, sicurezza).</li>
                        </ul>

                        <h5 class="mt-4 mb-2">Finalità e basi giuridiche</h5>
                        <ul class="text-main-2">
                            <li>Esecuzione del contratto e gestione dell’ordine.</li>
                            <li>Obblighi legali (contabilità/fatturazione).</li>
                            <li>Legittimo interesse (sicurezza, prevenzione frodi).</li>
                            <li>Consenso (marketing dove previsto).</li>
                        </ul>

                        <h5 class="mt-4 mb-2">Conservazione</h5>
                        <p class="text-main-2">I dati sono conservati per il tempo necessario alle finalità e agli obblighi di legge.</p>

                        <h5 class="mt-4 mb-2">Diritti</h5>
                        <p class="text-main-2">Accesso, rettifica, cancellazione, limitazione, portabilità, opposizione e reclamo all’autorità di controllo.</p>

                        <div class="mt-4">
                            <a class="tf-btn btn-line" href="Contattaci.aspx">Contattaci per richieste privacy</a>
                        </div>
                    </div>
                </div>

                <div class="col-lg-3">
                    <div class="tf-sidebar">
                        <div class="widget">
                            <div class="widget-title">Pagine utili</div>
                            <ul class="list-unstyled m-0">
                                <li class="mb-2"><a class="text-secondary link" href="faq.aspx">FAQ</a></li>
                                <li class="mb-2"><a class="text-secondary link" href="about.aspx">Chi siamo</a></li>
                                <li><a class="text-secondary link" href="Contattaci.aspx">Contatti</a></li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>
</asp:Content>
