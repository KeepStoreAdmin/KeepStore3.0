<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="carrello_groupon.aspx.vb" Inherits="carrello_groupon" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Coupon Groupon
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">

    <!-- Breadcrumb (Onsus) -->
    <div class="tf-sp-3 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Coupon</span>
                </div>
            </div>
        </div>
    </div>

    <section class="tf-sp-2">
        <div class="container">
            <div class="row justify-content-center">
                <div class="col-12 col-md-10 col-lg-7">

                    <div class="tf-page-title">
                        <div class="heading text-center">Inserisci il codice coupon Groupon</div>
                        <p class="text text-center mt-2">Inserisci il codice e conferma per proseguire con l'acquisto.</p>
                    </div>

                    <div class="tf-checkout-box">
                        <div class="tf-checkout-box-title">
                            <h4 class="title">Codice coupon</h4>
                        </div>

                        <div class="tf-checkout-box-content">
                            <div class="d-flex align-items-center gap-2">
                                <asp:TextBox ID="TB_CodiceSconto" runat="server" AutoPostBack="True" CssClass="form-control" AutoCompleteType="Disabled" placeholder="Es. ABCD-1234" />
                                <asp:Image ID="imgOK" runat="server" ImageUrl="Images/groupon/OK.png" Visible="False" style="width:28px;height:28px;" AlternateText="OK" />
                                <asp:Image ID="imgNO" runat="server" ImageUrl="Images/groupon/NO.png" Visible="False" style="width:28px;height:28px;" AlternateText="Errore" />
                            </div>
                            <div class="mt-2 text-muted" style="font-size:13px;">Il coupon verrà validato automaticamente.</div>
                        </div>
                    </div>

                    <asp:FormView ID="FormView_Articolo" runat="server" DataSourceID="SqlData_Buoni" CssClass="mt-4">
                        <ItemTemplate>
                            <div class="tf-checkout-box">
                                <div class="tf-checkout-box-title">
                                    <h4 class="title">Riepilogo coupon</h4>
                                </div>
                                <div class="tf-checkout-box-content">
                                    <div class="row g-3 align-items-center">
                                        <div class="col-12 col-md-6">
                                            <div class="tf-image-box">
                                                <img src='<%# Eval("imgBuono") %>' alt="Coupon" style="width:100%;border-radius:12px;" />
                                            </div>
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <div class="d-flex flex-column gap-2">

                                                <div class="d-flex align-items-center justify-content-between">
                                                    <span class="text">Prezzo</span>
                                                    <span class="fw-6"><%# PrezzoFissoConIva(Eval("prezzo_fisso"), Eval("iva")) %></span>
                                                </div>

                                                <div class="d-flex align-items-center justify-content-between">
                                                    <span class="text">Spedizione</span>
                                                    <span class="fw-6">
                                                        <%# If(CDbl(Eval("spese_spedizione")) > 0, String.Format(System.Globalization.CultureInfo.CurrentCulture, "{0:C}", Eval("spese_spedizione")), "Gratis") %>
                                                    </span>
                                                </div>

                                                <div class="mt-3">
                                                    <asp:LinkButton ID="IB_Conferma" runat="server" CssClass="tf-btn btn-fill w-100 justify-content-center"
                                                        OnClick="IB_Conferma_Click"
                                                        idArticolo='<%# Eval("idArticolo") %>'
                                                        Prezzo='<%# Eval("prezzo_fisso") %>'
                                                        codArticolo='<%# Eval("Codice") %>'
                                                        SpeseSpedizione='<%# Eval("spese_spedizione") %>'
                                                        DescrizioneArticolo='<%# Eval("Descrizione1") %>'
                                                        IvaArticolo='<%# Eval("iva") %>'>
                                                        Conferma e prosegui
                                                    </asp:LinkButton>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:FormView>

                    <asp:SqlDataSource ID="SqlData_Buoni" runat="server"
                        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                        SelectCommand="SELECT buoni_acquisto.idBuono, buoni_acquisto.idArticolo, buoni_acquisto.imgBuono, buoni_acquisto.listini_abilitati, buoni_acquisto.prezzo_fisso, buoni_acquisto.sconto, buoni_acquisto.spese_spedizione, buoni_acquisto.valido_da, buoni_acquisto.valido_a, articoli.Codice, articoli.Peso, articoli.Img1, articoli.Abilitato, codici_buono.idCodiceBuono, codici_buono.idBuono, codici_buono.associazione_groupon, articoli.Descrizione1, articoli.codice, articoli.iva, buoni_acquisto.idAzienda FROM buoni_acquisto INNER JOIN articoli ON buoni_acquisto.idArticolo = articoli.id INNER JOIN codici_buono ON buoni_acquisto.idBuono = codici_buono.idBuono WHERE (codici_buono.associazione_groupon = @Codice_Sconto) AND (codici_buono.data_convalida IS NULL) AND (buoni_acquisto.listini_abilitati LIKE CONCAT('%', @Listino, ';%')) AND (buoni_acquisto.valido_da &lt;= CURDATE()) AND (buoni_acquisto.valido_a &gt;= CURDATE()) AND (buoni_acquisto.idAzienda = @Azienda)"
                        UpdateCommand="UPDATE codici_buono SET data_convalida = NOW() WHERE (associazione_groupon = @Codice)">
                        <SelectParameters>
                            <asp:ControlParameter ControlID="TB_CodiceSconto" Name="Codice_Sconto" PropertyName="Text" />
                            <asp:SessionParameter Name="Azienda" SessionField="AziendaID" />
                            <asp:SessionParameter Name="Listino" SessionField="Listino" />
                        </SelectParameters>
                        <UpdateParameters>
                            <asp:ControlParameter ControlID="TB_CodiceSconto" Name="Codice" PropertyName="Text" />
                        </UpdateParameters>
                    </asp:SqlDataSource>

                </div>
            </div>
        </div>
    </section>

</asp:Content>


