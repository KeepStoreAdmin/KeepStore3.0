<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="wishlist.aspx.vb" Inherits="wishlist" MaintainScrollPositionOnPostback="true" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">

    <!-- DataSource principale: il SelectCommand viene sovrascritto da wishlist.aspx.vb (CaricaArticoli) -->
    <asp:SqlDataSource ID="sdsArticoli" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione1, PrezzoAcquisto, Img1, DescrizioneLunga FROM varticolibase ORDER BY Codice"
        EnableViewState="False">
        <SelectParameters>
            <asp:SessionParameter Name="IvaUtente" SessionField="Iva_Utente" Type="Int32" DefaultValue="0" />
            <asp:SessionParameter Name="id" SessionField="id" Type="Int32" DefaultValue="0" />
            <asp:SessionParameter Name="listino" SessionField="listino" Type="Int32" DefaultValue="1" />
        </SelectParameters>
    </asp:SqlDataSource>

    <script runat="server">
        Function stampa_iva_applicata(ByVal DescrizioneEsenzioneIva As String, ByVal DescrizioneIvaRC As String) As String
            If DescrizioneIvaRC <> "" Then
                Return DescrizioneIvaRC
            Else
                Return DescrizioneEsenzioneIva
            End If
        End Function

        Function controllaLunghezzaTesto(ByVal testo As String, ByVal lunghezza As Integer) As String
            If testo Is Nothing Then Return ""
            If testo.Length > lunghezza Then
                Return Left(testo, lunghezza) & "..."
            Else
                Return testo
            End If
        End Function
    </script>

</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="cph" Runat="Server">

    <style>
        /* STEP21: Wishlist in stile ONUS (hard-hide markup legacy senza rimuovere i controlli necessari al code-behind) */
        .ks-legacy-hidden { display: none !important; }
        .ks-btn-wrap { position: relative; display: inline-flex; align-items: center; justify-content: center; }
        .ks-btn-overlay { position: absolute; inset: 0; width: 100%; height: 100%; opacity: 0; cursor: pointer; }
        .ks-wishlist-actions { display: flex; gap: 10px; flex-wrap: wrap; justify-content: flex-end; }
        .ks-wishlist-actions .tf-btn { min-width: 200px; }
        .ks-wishlist-qty { max-width: 90px; }
        .ks-wishlist-meta { font-size: 12px; opacity: .85; }
        .ks-wishlist-product-title { font-weight: 600; }
        .ks-wishlist-empty { padding: 30px 0; text-align: center; }
        .ks-wishlist-empty h6 { margin-bottom: 6px; }
    </style>

    <!-- Breadcrumb (ONUS) -->
    <div class="tf-sp-3 pb-0">
        <div class="container">
            <ul class="breadcrumb-menu p-0 m-0">
                <li><a href="Default.aspx">Home</a></li>
                <li><span>Wishlist</span></li>
            </ul>
        </div>
    </div>

    <div class="tf-sp-2">
        <div class="container">

            <div class="d-flex flex-wrap align-items-end justify-content-between gap-2 mb-3">
                <div>
                    <h4 class="mb-1">Wishlist</h4>
                    <div class="ks-wishlist-meta">
                        <asp:Label ID="lblTrovati" runat="server" Font-Bold="True"></asp:Label>
                        articoli presenti nella wishlist
                        <i>(<asp:Label ID="lblLinee" runat="server" Text="0"></asp:Label> per pagina)</i>
                    </div>
                </div>
            </div>

            <!-- Tabella Wishlist (ONUS) -->
            <div class="table-responsive">
                <asp:GridView ID="GridView1" runat="server"
                    AutoGenerateColumns="False"
                    DataKeyNames="id"
                    DataSourceID="sdsArticoli"
                    AllowPaging="True"
                    PageSize="20"
                    GridLines="None"
                    CellPadding="0"
                    CssClass="tf-table-wishlist"
                    ShowHeader="True">

                    <EmptyDataTemplate>
                        <div class="ks-wishlist-empty">
                            <h6>La tua wishlist è vuota</h6>
                            <p class="mb-0">Aggiungi prodotti ai preferiti e li troverai qui.</p>
                        </div>
                    </EmptyDataTemplate>

                    <Columns>

                        <!-- Remove -->
                        <asp:TemplateField HeaderText="">
                            <ItemTemplate>
                                <asp:Label ID="label_idArticolo" runat="server" Text='<%# Eval("id") %>' Visible="False"></asp:Label>
                                <asp:LinkButton ID="LB_wishlist" runat="server" CssClass="remove" OnClick="BT_Rimuovi_wishlist_Click" ToolTip="Rimuovi dalla wishlist">
                                    <span class="icon-close"></span>
                                </asp:LinkButton>
                            </ItemTemplate>
                        </asp:TemplateField>

                        <!-- Image -->
                        <asp:TemplateField HeaderText="">
                            <ItemTemplate>
                                <asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "articolo.aspx?id=" & Eval("id") %>'>
                                    <asp:Image ID="Image1" runat="server" ImageUrl='<%# Eval("Img1") %>' AlternateText='<%# Eval("Descrizione1") %>' />
                                </asp:HyperLink>
                            </ItemTemplate>
                        </asp:TemplateField>

                        <!-- Product -->
                        <asp:TemplateField HeaderText="Product">
                            <ItemTemplate>
                                <div class="wishlist-product-info">
                                    <asp:Panel ID="Panel_in_offerta" runat="server" CssClass="mb-1" Visible="False">
                                        <span class="badge bg-danger">Promo</span>
                                    </asp:Panel>

                                    <asp:HyperLink ID="HyperLink1" runat="server" CssClass="ks-wishlist-product-title" NavigateUrl='<%# "articolo.aspx?id=" & Eval("id") %>'>
                                        <%# controllaLunghezzaTesto(Convert.ToString(Eval("Descrizione1")), 80) %>
                                    </asp:HyperLink>

                                    <div class="ks-wishlist-meta">
                                        Codice: <asp:Label ID="Label2" runat="server" Text='<%# Eval("Codice") %>'></asp:Label>
                                    </div>

                                    <asp:Label ID="tagliecolori" runat="server" CssClass="ks-wishlist-meta"></asp:Label>
                                </div>

                                <!-- Controlli legacy richiesti dal code-behind -->
                                <asp:Panel ID="pnlLegacy1" runat="server" CssClass="ks-legacy-hidden">
                                    <asp:Label ID="lblID" runat="server" Text='<%# Eval("id") %>'></asp:Label>
                                    <asp:TextBox ID="tbid" runat="server" Text='<%# Eval("id") %>'></asp:TextBox>
                                    <asp:TextBox ID="tbInOfferta" runat="server" Text='<%# Eval("InOfferta") %>'></asp:TextBox>

                                    <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" />

                                    <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" OnItemDataBound="rPromo_ItemDataBound">
                                        <ItemTemplate>
                                            <div class="ks-legacy-hidden">
                                                <asp:Label ID="lblOfferta" runat="server" Text="OFFERTA"></asp:Label>
                                                <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>'></asp:Label>
                                                <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>'></asp:Label>
                                                <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>'></asp:Label>
                                                <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# Eval("PrezzoPromo") %>'></asp:Label>
                                                <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%# Eval("PrezzoPromoIvato") %>'></asp:Label>
                                            </div>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </asp:Panel>

                            </ItemTemplate>
                        </asp:TemplateField>

                        <!-- Price -->
                        <asp:TemplateField HeaderText="Price">
                            <ItemTemplate>
                                <div class="price-wrap fw-medium flex-nowrap">
                                    <asp:Label ID="lblPrezzoPromo" runat="server" Visible="false" CssClass="price-text new-price"></asp:Label>
                                    <asp:Label ID="lblPrezzo" runat="server" Text='<%# "€ " & FormatNumber(Eval("Prezzo"), 2) %>' CssClass="price-text"></asp:Label>
                                    <asp:Label ID="lblPrezzoIvato" runat="server" Text='<%# "€ " & FormatNumber(Eval("PrezzoIvato"), 2) %>' CssClass="price-text"></asp:Label>
                                </div>

                                <!-- Immagini cifre prezzo (legacy) - mantenute per compatibilità, ma nascoste via CSS -->
                                <div class="ks-legacy-hidden">
                                    <asp:Image ID="img_prezzo1" runat="server" />
                                    <asp:Image ID="img_prezzo2" runat="server" />
                                    <asp:Image ID="img_prezzo3" runat="server" />
                                    <asp:Image ID="img_prezzo4" runat="server" />
                                    <asp:Image ID="img_prezzo5" runat="server" />
                                    <asp:Image ID="img_prezzo6" runat="server" />
                                    <asp:Image ID="img_prezzo7" runat="server" />
                                    <asp:Image ID="img_prezzo8" runat="server" />
                                    <asp:Image ID="img_prezzo9" runat="server" />
                                </div>
                            </ItemTemplate>
                        </asp:TemplateField>

                        <!-- Stock -->
                        <asp:TemplateField HeaderText="Stock">
                            <ItemTemplate>
                                <span class="wishlist-stock-status">
                                    <%# If((If(IsDBNull(Eval("Disponibilita")), 0, Convert.ToInt32(Eval("Disponibilita")))) > 0, "In Stock", "Out of Stock") %>
                                </span>

                                <!-- Dati legacy per code-behind (logica disponibilità) -->
                                <div class="ks-legacy-hidden">
                                    <asp:Label ID="Label_dispo" runat="server" Text='<%# Eval("Disponibilita") %>'></asp:Label>
                                    <asp:Label ID="Label_arrivo" runat="server" Text='<%# Eval("Arrivo") %>'></asp:Label>
                                    <asp:Label ID="Label_imp" runat="server" Text='<%# Eval("Impegnata") %>'></asp:Label>
                                    <asp:Label ID="lblImpegnata" runat="server"></asp:Label>
                                    <asp:Image ID="imgDispo" runat="server" />
                                    <asp:Image ID="imgArrivo" runat="server" />
                                </div>
                            </ItemTemplate>
                        </asp:TemplateField>

                        <!-- Action -->
                        <asp:TemplateField HeaderText="Action">
                            <ItemTemplate>
                                <div class="d-flex flex-column gap-2">

                                    <!-- Quantità -->
                                    <asp:TextBox ID="tbQuantita" runat="server" CssClass="form-control ks-wishlist-qty" Text="1" MaxLength="3"></asp:TextBox>

                                    <!-- Aggiungi al carrello (wrapper ONUS, click passa all'ImageButton invisibile) -->
                                    <div class="ks-btn-wrap tf-btn btn-gray">
                                        Aggiungi al carrello
                                        <asp:ImageButton ID="ImageButton1" runat="server" ImageUrl="~/Public/Banner/blank.GIF" CssClass="ks-btn-overlay" OnClick="ImageButton1_Click" />
                                    </div>

                                    <!-- Multiselezione (checkbox) -->
                                    <div class="d-flex align-items-center gap-2">
                                        <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" />
                                        <span class="ks-wishlist-meta">Seleziona</span>
                                    </div>

                                    <!-- GridView3 + datasource spedizione gratis (legacy) -->
                                    <div class="ks-legacy-hidden">
                                        <asp:SqlDataSource ID="sdsSpedizioneGratis" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand=""></asp:SqlDataSource>
                                        <asp:GridView ID="GridView3" runat="server" AutoGenerateColumns="False" DataSourceID="sdsSpedizioneGratis">
                                            <Columns>
                                                <asp:BoundField DataField="Spedizione" HeaderText="Spedizione" />
                                            </Columns>
                                        </asp:GridView>
                                    </div>

                                </div>
                            </ItemTemplate>
                        </asp:TemplateField>

                    </Columns>

                </asp:GridView>
            </div>

            <!-- Azioni pagina (ONUS) -->
            <div class="mt-4 d-flex flex-wrap align-items-center justify-content-between gap-2">

                <div class="d-flex flex-wrap align-items-center gap-2">
                    <asp:Label ID="lblPrezzi" runat="server" CssClass="ks-legacy-hidden"></asp:Label>
                </div>

                <div class="ks-wishlist-actions">
                    <asp:ImageButton ID="Selezione_Multipla" runat="server" ImageUrl="~/Images/bt_acquista.jpg" OnClick="Selezione_Multipla_Click" AlternateText="Aggiungi selezionati" ToolTip="Aggiungi selezionati al carrello" />
                    <asp:LinkButton ID="LB_cancella_tutta_wishlist" runat="server" CssClass="tf-btn btn-gray" ToolTip="Svuota wishlist">Svuota wishlist</asp:LinkButton>
                    <asp:LinkButton ID="LB_crea_html" runat="server" CssClass="tf-btn btn-gray" ToolTip="Crea HTML">Crea HTML</asp:LinkButton>
                </div>

            </div>

        </div>
    </div>

</asp:Content>
