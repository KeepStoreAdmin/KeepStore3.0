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

                        <section class="mt-4" aria-labelledby="persistentCartCookiesTitle">
                            <h5 id="persistentCartCookiesTitle" class="mb-2">Cookie tecnici e carrello persistente</h5>
                            <p class="text-main-2">Il sito utilizza cookie tecnici necessari al funzionamento del servizio. Il cookie <span class="text-break">__Host-KeepStoreCart</span> viene creato quando effettui una reale operazione sul carrello e ti consente di ritrovare il carrello anonimo nelle visite successive, mantenendolo associato al tuo browser e trasferendolo al tuo account dopo il login.</p>
                            <p class="text-main-2 mt-2">La durata massima è di 30 giorni dall’ultima modifica effettiva del carrello: si rinnova soltanto quando il carrello viene realmente modificato, non quando visiti una pagina o aggiorni la visualizzazione. Il cookie viene revocato ed eliminato quando svuoti il carrello; al corretto trasferimento del carrello nell’account dopo il login viene consumato ed eliminato.</p>

                            <div class="border rounded p-3 mt-3 mb-3">
                                <dl class="row mb-0 text-main-2">
                                    <dt class="col-sm-4 mb-1">Nome</dt>
                                    <dd class="col-sm-8 mb-3 text-break">__Host-KeepStoreCart</dd>
                                    <dt class="col-sm-4 mb-1">Tipologia</dt>
                                    <dd class="col-sm-8 mb-3">Cookie tecnico / funzionale</dd>
                                    <dt class="col-sm-4 mb-1">Finalità</dt>
                                    <dd class="col-sm-8 mb-3">Memorizzazione e recupero del carrello anonimo</dd>
                                    <dt class="col-sm-4 mb-1">Durata</dt>
                                    <dd class="col-sm-8 mb-3">Fino a 30 giorni dall’ultima modifica effettiva del carrello</dd>
                                    <dt class="col-sm-4 mb-1">Prima / terza parte</dt>
                                    <dd class="col-sm-8 mb-3">Prima parte</dd>
                                    <dt class="col-sm-4 mb-1">Consenso</dt>
                                    <dd class="col-sm-8 mb-0">Non richiesto per il funzionamento tecnico del servizio</dd>
                                </dl>
                            </div>

                            <p class="text-main-2">Nel browser il cookie contiene esclusivamente un identificatore casuale opaco: non contiene nome, email, prodotti, prezzi, identificativi dell’account o dell’azienda, né altri dati personali o commerciali leggibili. Questo cookie non viene utilizzato per profilazione, pubblicità, analytics o tracciamento tra siti diversi.</p>
                            <p class="text-main-2 mt-2">È un cookie di prima parte, limitato al sito che lo crea: viene trasmesso soltanto su connessioni HTTPS (<strong>Secure</strong>) e non è accessibile agli script del browser (<strong>HttpOnly</strong>). Utilizza <strong>SameSite=Lax</strong> e <strong>Path=/</strong>, senza un attributo <strong>Domain</strong> esplicito, come previsto dal prefisso <strong>__Host-</strong>.</p>
                        </section>

                        <section class="mt-4" aria-labelledby="staySignedInCookieTitle">
                            <h5 id="staySignedInCookieTitle" class="mb-2">Cookie tecnico «Resta collegato»</h5>
                            <p class="text-main-2">Il cookie <span class="text-break">__Host-KeepStoreStay</span> viene creato soltanto se, nella pagina di accesso, scegli l’opzione «Resta collegato su questo dispositivo». Ti permette di ritrovarti collegato nelle visite successive senza digitare di nuovo la password.</p>

                            <div class="border rounded p-3 mt-3 mb-3">
                                <dl class="row mb-0 text-main-2">
                                    <dt class="col-sm-4 mb-1">Nome</dt>
                                    <dd class="col-sm-8 mb-3 text-break">__Host-KeepStoreStay</dd>
                                    <dt class="col-sm-4 mb-1">Tipologia</dt>
                                    <dd class="col-sm-8 mb-3">Cookie tecnico / funzionale, creato su tua richiesta</dd>
                                    <dt class="col-sm-4 mb-1">Finalità</dt>
                                    <dd class="col-sm-8 mb-3">Riconoscere il dispositivo e mantenere l’accesso al tuo account</dd>
                                    <dt class="col-sm-4 mb-1">Durata</dt>
                                    <dd class="col-sm-8 mb-3">Fino a 30 giorni dall’ultima visita da collegato</dd>
                                    <dt class="col-sm-4 mb-1">Prima / terza parte</dt>
                                    <dd class="col-sm-8 mb-3">Prima parte</dd>
                                    <dt class="col-sm-4 mb-1">Consenso</dt>
                                    <dd class="col-sm-8 mb-0">Non richiesto: è necessario a un servizio che chiedi tu, spuntando l’opzione</dd>
                                </dl>
                            </div>

                            <p class="text-main-2">Nel browser il cookie contiene esclusivamente un codice casuale: non contiene la password, il nome utente, l’email né altri dati personali. Sui nostri sistemi ne viene conservata soltanto un’impronta non reversibile, insieme alla data dell’ultimo utilizzo. Non viene utilizzato per profilazione, pubblicità, analytics o tracciamento tra siti diversi.</p>
                            <p class="text-main-2 mt-2">Il dispositivo viene scollegato e il cookie eliminato quando scegli «Esci». Smette inoltre di valere quando la password dell’account viene cambiata, quando l’account viene disabilitato e dopo 30 giorni senza visite. È trasmesso soltanto su connessioni HTTPS (<strong>Secure</strong>), non è accessibile agli script del browser (<strong>HttpOnly</strong>) e utilizza <strong>SameSite=Lax</strong> e <strong>Path=/</strong>, senza attributo <strong>Domain</strong>. Non usare questa opzione su computer o telefoni condivisi con altre persone.</p>
                        </section>

                        <h5 class="mt-4 mb-2">Conservazione</h5>
                        <p class="text-main-2">I dati sono conservati per il tempo necessario alle finalità e agli obblighi di legge.</p>
                        <p class="text-main-2 mt-2">La persistenza tecnica del carrello anonimo è limitata a 30 giorni dall’ultima attività effettiva sul carrello, salvo precedente svuotamento o trasferimento all’account.</p>

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
