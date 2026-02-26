<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" Inherits="System.Web.UI.Page" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">FAQ</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">FAQ</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-section-title mb_30">
                <h2 class="title">Domande frequenti</h2>
                <p class="text-main-2 mt-2">Risposte rapide alle domande più comuni su ordini, pagamenti e spedizioni.</p>
            </div>

            <div class="tf-accordion" id="faqAccordion">

                <div class="tf-accordion-item">
                    <div class="tf-accordion-header" id="q1">
                        <button class="tf-accordion-button" type="button" data-bs-toggle="collapse" data-bs-target="#a1" aria-expanded="true" aria-controls="a1">
                            Come posso effettuare un ordine?
                        </button>
                    </div>
                    <div id="a1" class="accordion-collapse collapse show" aria-labelledby="q1" data-bs-parent="#faqAccordion">
                        <div class="tf-accordion-body text-main-2">
                            Aggiungi i prodotti al carrello e completa il checkout. Se hai un account, puoi vedere lo storico nella sezione "I miei ordini".
                        </div>
                    </div>
                </div>

                <div class="tf-accordion-item">
                    <div class="tf-accordion-header" id="q2">
                        <button class="tf-accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#a2" aria-expanded="false" aria-controls="a2">
                            Quali metodi di pagamento sono disponibili?
                        </button>
                    </div>
                    <div id="a2" class="accordion-collapse collapse" aria-labelledby="q2" data-bs-parent="#faqAccordion">
                        <div class="tf-accordion-body text-main-2">
                            I metodi disponibili sono mostrati al checkout (carta, bonifico e/o altri gateway in base alla configurazione).
                        </div>
                    </div>
                </div>

                <div class="tf-accordion-item">
                    <div class="tf-accordion-header" id="q3">
                        <button class="tf-accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#a3" aria-expanded="false" aria-controls="a3">
                            Come traccio la spedizione?
                        </button>
                    </div>
                    <div id="a3" class="accordion-collapse collapse" aria-labelledby="q3" data-bs-parent="#faqAccordion">
                        <div class="tf-accordion-body text-main-2">
                            Usa la pagina "Traccia ordine" se disponibile o consulta i dettagli ordine nell’area account.
                        </div>
                    </div>
                </div>

                <div class="tf-accordion-item">
                    <div class="tf-accordion-header" id="q4">
                        <button class="tf-accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#a4" aria-expanded="false" aria-controls="a4">
                            Posso richiedere una fattura?
                        </button>
                    </div>
                    <div id="a4" class="accordion-collapse collapse" aria-labelledby="q4" data-bs-parent="#faqAccordion">
                        <div class="tf-accordion-body text-main-2">
                            Se hai inserito i dati di fatturazione corretti, la fattura sarà disponibile nella sezione "Le mie fatture" (se abilitata).
                        </div>
                    </div>
                </div>

            </div>

            <div class="mt-5">
                <a class="tf-btn btn-line" href="Contattaci.aspx">Hai altre domande? Contattaci</a>
            </div>
        </div>
    </section>
</asp:Content>
