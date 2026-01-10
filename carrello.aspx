<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="carrello.aspx.vb" Inherits="carrello" %>

<!-- ============================================================
     carrello.aspx (KEEPSTORE3 - TEMPLATE-FIRST)
     NOTE:
     - Pagina mancante nel progetto: questa versione fornisce markup completo
       compatibile con carrello.aspx.vb esistente (Repo KeepStore3.0).
     - Struttura UI basata su shop-cart.html (template Keepstore).
     - I controlli legacy (ID) sono preservati per compatibilità logica.
     ============================================================ -->

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server"><%: Page.Title %></asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <!-- Cart page: small glue CSS only -->
    <style type="text/css">
        .ks-cart-summary .ks-row { display:flex; justify-content:space-between; gap:12px; }
        .ks-cart-summary .ks-row + .ks-row { margin-top: 8px; }
        .ks-cart-actions { display:flex; gap:12px; flex-wrap:wrap; }
        .ks-cart-actions .tf-button { min-width: 180px; }
        .ks-hidden { display:none; }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="cph" runat="server">

    <!-- ======== Page header / breadcrumb (template style) ======== -->
    <div class="page-title">
        <div class="container">
            <div class="row">
                <div class="col-12">
                    <div class="page-title-inner">
                        <h1 class="page-title-heading">Carrello</h1>
                        <ul class="breadcrumbs">
                            <li><a href="Default.aspx">Home</a></li>
                            <li class="divider">/</li>
                            <li>Carrello</li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- ======== Cart ======== -->
    <section class="tf-section cart">
        <div class="container">
            <div class="row">
                <!-- LEFT: items -->
                <div class="col-xl-8 col-lg-7 col-md-12">
                    <div class="tf-cart">
                        <div class="cart-table">
                            <div class="table-responsive">
                                <table class="table">
                                    <thead>
                                        <tr>
                                            <th>Prodotto</th>
                                            <th>Prezzo</th>
                                            <th>Quantità</th>
                                            <th>Totale</th>
                                            <th></th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <asp:Repeater ID="Repeater1" runat="server">
                                            <ItemTemplate>
                                                <tr>
                                                    <td class="product-name">
                                                        <div class="product-item d-flex align-items-center gap-3">
                                                            <div class="product-thumb">
                                                                <!-- immagine: se la query non restituisce un campo immagine, resta vuota -->
                                                                <asp:Image ID="imgProd" runat="server" CssClass="img-fluid" AlternateText="" />
                                                            </div>
                                                            <div class="product-info">
                                                                <asp:Label ID="lblNome" runat="server" CssClass="product-title" />
                                                                <div class="small text-muted">
                                                                    <asp:Label ID="lblDispo" runat="server" />
                                                                    <asp:Label ID="lblArrivo" runat="server" />
                                                                </div>
                                                            </div>
                                                        </div>

                                                        <!-- campi richiesti dal code-behind (FindControl) -->
                                                        <asp:Label ID="lblId" runat="server" CssClass="ks-hidden" />
                                                        <asp:TextBox ID="tbID" runat="server" CssClass="ks-hidden" />
                                                        <asp:Image ID="imgDispo" runat="server" CssClass="ks-hidden" />
                                                    </td>

                                                    <td class="product-price">
                                                        <asp:Label ID="lblprezzo" runat="server" />
                                                        <asp:Label ID="lblprezzoivato" runat="server" CssClass="ks-hidden" />
                                                    </td>

                                                    <td class="product-quantity">
                                                        <asp:TextBox ID="tbQta" runat="server" CssClass="form-control" TextMode="Number" />
                                                    </td>

                                                    <td class="product-subtotal">
                                                        <asp:Label ID="lblImporto" runat="server" />
                                                        <asp:Label ID="lblImportoIvato" runat="server" CssClass="ks-hidden" />
                                                        <asp:Label ID="lblPeso" runat="server" CssClass="ks-hidden" />
                                                    </td>

                                                    <td class="product-action text-end">
                                                        <div class="d-flex gap-2 justify-content-end flex-wrap">
                                                            <asp:LinkButton ID="lbAggiornaRiga" runat="server" CommandName="Aggiorna" CssClass="tf-button small" Text="Aggiorna" />
                                                            <asp:LinkButton ID="lbEliminaRiga" runat="server" CommandName="Elimina" CssClass="tf-button style-2 small" Text="Rimuovi" />
                                                        </div>
                                                    </td>
                                                </tr>
                                            </ItemTemplate>
                                        </asp:Repeater>
                                    </tbody>
                                </table>
                            </div>

                            <div class="ks-cart-actions mt-4">
                                <asp:Button ID="btAggiorna" runat="server" CssClass="tf-button" Text="Aggiorna carrello" />
                                <asp:Button ID="btSvuota" runat="server" CssClass="tf-button style-2" Text="Svuota carrello" />
                            </div>
                        </div>
                    </div>

                    <!-- Articoli gratis (se gestiti dal code-behind) -->
                    <div class="mt-5">
                        <asp:GridView ID="gvArticoliGratis" runat="server" AutoGenerateColumns="true" CssClass="table" Visible="false"></asp:GridView>
                    </div>
                </div>

                <!-- RIGHT: summary / shipping / coupon -->
                <div class="col-xl-4 col-lg-5 col-md-12">
                    <div class="tf-cart-total ks-cart-summary">
                        <h4 class="title">Riepilogo</h4>

                        <div class="ks-row">
                            <span>Totale</span>
                            <strong><asp:Label ID="lblTotale" runat="server" /></strong>
                        </div>

                        <div class="ks-row">
                            <span>Sconto</span>
                            <strong><asp:Label ID="lbl_TotSconto" runat="server" /></strong>
                        </div>

                        <hr />

                        <!-- Buono sconto -->
                        <div class="mt-3">
                            <label class="mb-2">Buono sconto</label>
                            <div class="d-flex gap-2">
                                <asp:TextBox ID="TB_BuonoSconto" runat="server" CssClass="form-control" />
                                <asp:LinkButton ID="LB_CancelBuonoSconto" runat="server" CssClass="tf-button style-2" Text="Annulla" />
                            </div>
                            <div class="small mt-2">
                                <asp:Label ID="lblBuonoScontoConvalida" runat="server" />
                                <asp:Label ID="lblBuonoScontoCodice" runat="server" CssClass="ks-hidden" />
                            </div>

                            <asp:GridView ID="GV_BuoniSconti" runat="server" AutoGenerateColumns="true" CssClass="table mt-3" Visible="false"></asp:GridView>
                        </div>

                        <hr />

                        <!-- Destinazione / indirizzo (legacy) -->
                        <div class="mt-3">
                            <label class="mb-2">Indirizzo di spedizione</label>
                            <asp:DropDownList ID="LstScegliIndirizzo" runat="server" CssClass="form-select" AutoPostBack="true"></asp:DropDownList>
                        </div>

                        <div class="mt-3">
                            <label class="mb-2">Destinazione</label>
                            <div class="d-flex gap-2 flex-wrap">
                                <asp:DropDownList ID="LstDestinazione" runat="server" CssClass="form-select" AutoPostBack="true"></asp:DropDownList>
                                <asp:ImageButton ID="ImgBtnDestinazioneSi" runat="server" ImageUrl="~/Public/images/ok.png" AlternateText="Sì" />
                                <asp:ImageButton ID="ImgBtnDestinazioneNo" runat="server" ImageUrl="~/Public/images/no.png" AlternateText="No" />
                            </div>
                            <div class="d-flex gap-2 mt-2">
                                <asp:Button ID="btnSalvaDest" runat="server" CssClass="tf-button small" Text="Salva" />
                                <asp:Button ID="btnAnnullaDest" runat="server" CssClass="tf-button style-2 small" Text="Annulla" />
                            </div>
                        </div>

                        <div class="mt-3">
                            <asp:RadioButton ID="rbSpedizioneGratis" runat="server" Text="Spedizione gratuita (se disponibile)" />
                        </div>

                        <hr />

                        <div class="ks-cart-actions mt-3">
                            <asp:Button ID="btContinua" runat="server" CssClass="tf-button style-2" Text="Continua acquisti" />
                            <asp:Button ID="btCompleta" runat="server" CssClass="tf-button" Text="Completa ordine" />
                            <asp:Button ID="btInviaOrdine" runat="server" CssClass="tf-button" Text="Invia ordine" Visible="false" />
                            <asp:Button ID="btSalvaPreventivo" runat="server" CssClass="tf-button style-2" Text="Salva preventivo" Visible="false" />
                        </div>

                        <!-- Grids legacy (vettori/pagamenti): inizialmente nascosti, ma presenti per compatibilità -->
                        <asp:GridView ID="gvVettori" runat="server" AutoGenerateColumns="true" CssClass="table mt-4" Visible="false"></asp:GridView>
                        <asp:GridView ID="gvVettoriPromo" runat="server" AutoGenerateColumns="true" CssClass="table mt-3" Visible="false"></asp:GridView>
                        <asp:GridView ID="gvPagamento" runat="server" AutoGenerateColumns="true" CssClass="table mt-3" Visible="false"></asp:GridView>

                        <!-- Panel legacy -->
                        <asp:Panel ID="pnlFatturazione" runat="server" Visible="false"></asp:Panel>

                        <!-- Note spedizione -->
                        <asp:TextBox ID="txtNoteSpedizione" runat="server" CssClass="form-control mt-3" TextMode="MultiLine" Rows="3" Visible="false"></asp:TextBox>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- ======== DataSources required by carrello.aspx.vb ======== -->
    <asp:SqlDataSource ID="sdsArticoli" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="MySql.Data.MySqlClient">
    </asp:SqlDataSource>

    <asp:SqlDataSource ID="sdsArticoli_Spedizione_Gratis" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="MySql.Data.MySqlClient">
    </asp:SqlDataSource>

    <!-- ======== Hidden legacy controls (prevents NullReference in code-behind) ======== -->
    <asp:Panel ID="pnlLegacyHidden" runat="server" Visible="false">
        <asp:Label ID="LbDescrDest" runat="server" />
        <asp:Label ID="LB_ConvalidaBuonoSconto" runat="server" />
        <asp:Label ID="LB_DestConfig" runat="server" />
        <asp:Label ID="LB_NuovoInd" runat="server" />
        <asp:Label ID="LB_ScegliInd" runat="server" />
        <asp:Label ID="LB_TitoloIndirizzo" runat="server" />
        <asp:Label ID="LB_TotaleCarrello" runat="server" />
        <asp:Label ID="LB_TotaleIvato" runat="server" />
        <asp:Label ID="LB_fatturazione" runat="server" />
        <asp:Label ID="LB_indirizzo" runat="server" />
        <asp:Label ID="LB_spedizione" runat="server" />
        <asp:Label ID="lblAliquotaIva" runat="server" />
        <asp:Label ID="lblCodArt" runat="server" />
        <asp:Label ID="lblCodArticolo" runat="server" />
        <asp:Label ID="lblDescrizione" runat="server" />
        <asp:Label ID="lblDescrizioneArticolo" runat="server" />
        <asp:Label ID="lblDispoGenerale" runat="server" />
        <asp:Label ID="lblIva" runat="server" />
        <asp:Label ID="lblPesoTotale" runat="server" />
        <asp:Label ID="lblPrezzo" runat="server" />
        <asp:Label ID="lblPrezzoIvato" runat="server" />
        <asp:Label ID="lblQuantita" runat="server" />
        <asp:Label ID="lblTotaleCarrello2" runat="server" />
        <asp:Label ID="lblTotaleSenzaIva" runat="server" />
        <asp:Label ID="lblVar" runat="server" />
        <asp:Label ID="lblVettoreScelto" runat="server" />
        <asp:Label ID="lbl_numero_articoli" runat="server" />
        <asp:Label ID="lbl_sconto" runat="server" />
        <asp:TextBox ID="tbCapA" runat="server" />
        <asp:TextBox ID="tbCapS" runat="server" />
        <asp:TextBox ID="tbCittaA" runat="server" />
        <asp:TextBox ID="tbCittaS" runat="server" />
        <asp:TextBox ID="tbCodiceFiscaleA" runat="server" />
        <asp:TextBox ID="tbCognomeA" runat="server" />
        <asp:TextBox ID="tbCognomeS" runat="server" />
        <asp:TextBox ID="tbContrMinimo" runat="server" />
        <asp:TextBox ID="tbDataConsegna" runat="server" />
        <asp:TextBox ID="tbEmailA" runat="server" />
        <asp:TextBox ID="tbFaxA" runat="server" />
        <asp:TextBox ID="tbIdBuonoSconto" runat="server" />
        <asp:TextBox ID="tbIdIndirizzo" runat="server" />
        <asp:TextBox ID="tbIdPagamento" runat="server" />
        <asp:TextBox ID="tbIdVettore" runat="server" />
        <asp:TextBox ID="tbIndirizzoA" runat="server" />
        <asp:TextBox ID="tbIndirizzoS" runat="server" />
        <asp:TextBox ID="tbIvaA" runat="server" />
        <asp:TextBox ID="tbNomeA" runat="server" />
        <asp:TextBox ID="tbNomeS" runat="server" />
        <asp:TextBox ID="tbNote" runat="server" />
        <asp:TextBox ID="tbNoteVettore" runat="server" />
        <asp:TextBox ID="tbProvinciaA" runat="server" />
        <asp:TextBox ID="tbProvinciaS" runat="server" />
        <asp:TextBox ID="tbRagioneSocialeA" runat="server" />
        <asp:TextBox ID="tbStatoA" runat="server" />
        <asp:TextBox ID="tbStatoS" runat="server" />
        <asp:TextBox ID="tbTelefonoA" runat="server" />
    </asp:Panel>

</asp:Content>
