<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="wishlist.aspx.vb" Inherits="wishlist" MaintainScrollPositionOnPostback="true" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Wishlist
</asp:Content>
<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
<div class="ks-myaccount">

        <!-- Breakcrumbs (ONUS) -->
        <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <a href="myaccount.aspx" class="text">Account</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Wishlist</span>
                </div>
            </div>
        </div>
    </div>

        <!-- My Account (ONUS) -->
        <section class="tf-sp-2">
            <div class="container">
                <div class="row">
                    <!-- Sidebar -->
                    <div class="col-lg-3">
                        <div class="wrap-sidebar-account">
                            <ul class="myaccount-nav content-append">
                                <li><a href="myaccount.aspx" class="myaccount-nav-item">Dashboard</a></li>
                                <li><a href="datiutente.aspx?tab=account" class="myaccount-nav-item">Dettagli account</a></li>
                                <li><a href="datiutente.aspx?tab=addr" class="myaccount-nav-item">Indirizzi</a></li>
                                <li><a href="documenti.aspx?t=4" class="myaccount-nav-item">I miei ordini</a></li>
                                <li><a href="documenti.aspx?t=2" class="myaccount-nav-item">Le mie fatture</a></li>
                                <li><a href="documenti.aspx?t=1" class="myaccount-nav-item">I miei DDT</a></li>
                                <li><span class="myaccount-nav-item active">Wishlist</span></li>
                                <li><a href="password.aspx" class="myaccount-nav-item">Cambia password</a></li>
                                <li><a href="logout.aspx" class="myaccount-nav-item">Logout</a></li>
                            </ul>
                        </div>
                    </div>

                    <!-- Content -->
                    <div class="col-lg-9">
<asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione1, PrezzoAcquisto, Img1, DescrizioneLunga FROM varticolibase ORDER BY NoPromo DESC, Codice, Descrizione1"
        EnableViewState="False">
    </asp:SqlDataSource>
                        <!-- Wishlist -->
                        <div class="tf-section-heading mb-4 d-flex flex-wrap justify-content-between align-items-center">
                <div>
                    <h3 class="heading mb-1">Wishlist</h3>
                    <div class="body-md-2 text-main-2">
                        <asp:Label ID="lblTrovati" runat="server" Text="0" Font-Bold="True"></asp:Label>
                        <span> articoli</span>
                    </div>
                </div>

                <div class="d-flex flex-wrap align-items-center ks-wl-actions">

                    <% If Convert.ToString(Session("G2A")) = "1" Then%>
                        <asp:LinkButton ID="LB_cancella_tutta_wishlist" runat="server" CssClass="tf-btn btn-gray" CausesValidation="false">
                            <span class="text-white">Svuota wishlist</span>
                        </asp:LinkButton>
                    <% End If %>

                    <asp:ImageButton CssClass="tf-btn btn-line" ID="Selezione_Multipla" runat="server" title="Aggiungi gli articoli selezionati al carrello"
                        OnClick="Selezione_Multipla_Click" ImageUrl="~/Public/Images/aggiungiMultiplo.png" CausesValidation="false" />

                    <% If Convert.ToString(Session("genera_html_mail")) = "1" Then%>
                        <asp:LinkButton ID="LB_crea_html" runat="server" CssClass="tf-btn btn-gray" CausesValidation="false">
                            <span class="text-white">Crea HTML</span>
                        </asp:LinkButton>
                    <% End If %>

                </div>
            </div>

            
                        <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                            <div class="tf-page-title style-2 mb_30">
                                <div class="heading text-center">La tua wishlist è vuota</div>
                                <p class="text text-center mt-2">Aggiungi un prodotto alla wishlist per ritrovarlo rapidamente qui.</p>
                                <div class="text-center mt-4">
                                    <a class="tf-btn btn-fill" href="articoli.aspx">Vai al catalogo</a>
                                </div>
                            </div>
                        </asp:PlaceHolder>

                        <asp:PlaceHolder ID="phTable" runat="server">
<div class="tf-wishlist">
                <asp:GridView ID="GridView1" runat="server" AutoGenerateColumns="False" DataKeyNames="id"
                    DataSourceID="sdsArticoli" AllowPaging="True" GridLines="None" CellPadding="0"
                    Width="100%" ShowHeader="True" CssClass="tf-table-wishlist ks-table-clean">

                    <Columns>

                        <asp:TemplateField>
                            <HeaderStyle CssClass="wishlist-item_remove" />
                            <ItemStyle CssClass="wishlist-item_remove" />
                            <ItemTemplate>
                                <asp:LinkButton ID="BT_Rimuovi_wishlist" runat="server" OnClick="BT_Rimuovi_wishlist_Click" CausesValidation="false"
                                    CssClass="link cs-pointer" Text="<i class='icon-close remove'></i>"></asp:LinkButton>
                                <asp:Label ID="label_idArticolo" runat="server" Text='<%# Eval("id") %>' Visible="false"></asp:Label>
                            </ItemTemplate>
                        </asp:TemplateField>

                        <asp:TemplateField>
                            <HeaderStyle CssClass="wishlist-item_image" />
                            <ItemStyle CssClass="wishlist-item_image" />
                            <ItemTemplate>
                                <asp:HyperLink ID="HyperLink3" runat="server" NavigateUrl='<%# "~/articolo.aspx?id=" & Eval("id") %>'>
                                    <img alt="Image" class="lazyload" src='<%# CheckImg(Eval("Img1")) %>' data-src='<%# CheckImg(Eval("Img1")) %>' />
                                </asp:HyperLink>
                            </ItemTemplate>
                        </asp:TemplateField>

                        <asp:TemplateField>
                            <HeaderStyle CssClass="wishlist-item_info" />
                            <ItemStyle CssClass="wishlist-item_info" />
                            <ItemTemplate>
                                <a class="text-line-clamp-2 body-md-2 fw-semibold text-secondary link"
                                    href='<%# "articolo.aspx?id=" & Eval("id") %>'>
                                    <%# TruncateText(Convert.ToString(Eval("Descrizione1")), 90) %>
                                </a>

                                <div class="body-small text-main-2 mt-1">
                                    <asp:Label ID="tagliecolori" runat="server"></asp:Label>
                                </div>

                                <asp:Label ID="lblID" runat="server" Text='<%# Eval("id") %>' Visible="false"></asp:Label>
                                <asp:TextBox ID="tbid" runat="server" Text='<%# Eval("id") %>' Visible="false" EnableViewState="false"></asp:TextBox>
                                <asp:TextBox ID="tbInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false" EnableViewState="false"></asp:TextBox>
                            </ItemTemplate>
                        </asp:TemplateField>

                        <asp:TemplateField>
                            <HeaderStyle CssClass="wishlist-item_price" />
                            <ItemStyle CssClass="wishlist-item_price" />
                            <ItemTemplate>

                                <p class="price-wrap fw-medium flex-nowrap">
                                    <asp:Label ID="lblPrezzoPromo" runat="server" CssClass="new-price price-text fw-medium mb-0" Text='<%# Eval("PrezzoPromo", "{0:N2}") %>'></asp:Label>
                                    <asp:Label ID="lblPrezzoPromoIvato" runat="server" CssClass="new-price price-text fw-medium mb-0" Text='<%# Eval("PrezzoPromoIvato", "{0:N2}") %>' Visible="false"></asp:Label>

                                    <asp:Label ID="lblPrezzo" runat="server" CssClass="old-price body-md-2 text-main-2 fw-normal" Text='<%# Eval("Prezzo", "{0:N2}") %>'></asp:Label>
                                    <asp:Label ID="lblPrezzoIvato" runat="server" CssClass="old-price body-md-2 text-main-2 fw-normal" Text='<%# Eval("PrezzoIvato", "{0:N2}") %>' Visible="false"></asp:Label>
                                </p>

                                <div class="ks-hidden">
                                    <asp:Image ID="img_prezzo9" runat="server" />
                                    <asp:Image ID="img_prezzo8" runat="server" />
                                    <asp:Image ID="img_prezzo7" runat="server" />
                                    <asp:Image ID="img_prezzo6" runat="server" />
                                    <asp:Image ID="img_prezzo5" runat="server" />
                                    <asp:Image ID="img_prezzo4" runat="server" />
                                    <asp:Image ID="img_prezzo3" runat="server" />
                                    <asp:Image ID="img_prezzo2" runat="server" />
                                    <asp:Image ID="img_prezzo1" runat="server" />
                                </div>

                                <asp:SqlDataSource ID="sdsPromo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                    SelectCommand="SELECT '' AS OfferteDescrizione, 0 AS InOfferta, 0 AS OfferteQntMinima, 0 AS OfferteMultipli WHERE 1=0" EnableViewState="False" />

                                <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                                    <ItemTemplate>
                                        <asp:Label ID="lblOfferta" runat="server" Text='<%# Eval("OfferteDescrizione") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                        <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>' Visible="false"></asp:Label>
                                    </ItemTemplate>
                                </asp:Repeater>

                                <asp:Panel ID="Panel_in_offerta" runat="server" Visible="False"></asp:Panel>

                            </ItemTemplate>
                        </asp:TemplateField>

                        <asp:TemplateField>
                            <HeaderStyle CssClass="wishlist-item_stock" />
                            <ItemStyle CssClass="wishlist-item_stock" />
                            <ItemTemplate>
                                <asp:Image ID="imgDispo" runat="server" Visible="false" />
                                <asp:Image ID="imgArrivo" runat="server" Visible="false" />

                                <asp:Label ID="Label_dispo" runat="server" CssClass="wishlist-stock-status" ForeColor="Red" Text='<%# Eval("Giacenza") %>'></asp:Label>
                                <asp:Label ID="Label_arrivo" runat="server" Visible="false" Text='<%# Eval("InOrdine") %>'></asp:Label>
                                <asp:Label ID="Label_imp" runat="server" Visible="false" Text='<%# Eval("Impegnata") %>'></asp:Label>
                                <asp:Label ID="lblImpegnata" runat="server" Visible="false" Text='<%# Eval("Impegnata") %>'></asp:Label>

                            </ItemTemplate>
                        </asp:TemplateField>

                        <asp:TemplateField>
                            <HeaderStyle CssClass="wishlist-item_action" />
                            <ItemStyle CssClass="wishlist-item_action" />
                            <ItemTemplate>

                                <asp:SqlDataSource ID="sdsSpedizioneGratis" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                    SelectCommand="SELECT SpedizioneGratis_Listini, SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine, id FROM articoli WHERE (SpedizioneGratis_Listini LIKE CONCAT('%', @Param1, ';%')) AND (id = @Param2) AND (SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE())">
                                    <SelectParameters>
                                        <asp:SessionParameter Name="Param1" SessionField="Listino" />
                                        <asp:ControlParameter ControlID="lblID" Name="Param2" PropertyName="Text" />
                                    </SelectParameters>
                                </asp:SqlDataSource>

                                <asp:GridView ID="GridView3" runat="server" AutoGenerateColumns="False" DataSourceID="sdsSpedizioneGratis" BorderWidth="0px" ShowHeader="False" CssClass="ks-hidden">
                                    <Columns>
                                        <asp:TemplateField>
                                            <ItemTemplate>
                                                <img style="border-width:0px; background-color:white; margin-top:5px;" src="Images/freeshipping.gif" title='Questo articolo verra' spedito GRATIS !!! fino al <%# Eval("SpedizioneGratis_Data_Fine","{0:d}") %>' alt="" />
                                            </ItemTemplate>
                                        </asp:TemplateField>
                                    </Columns>

                    <EmptyDataTemplate>
                        <div class='tf-empty-state text-center py-5'>
                            <div class='heading'>La tua wishlist è vuota</div>
                            <p class='text-main-2 mt-2'>Aggiungi articoli che ti interessano per ritrovarli qui rapidamente.</p>
                            <div class='mt-4'>
                                <a class='tf-btn btn-fill' href='articoli.aspx'>Vai al catalogo</a>
                            </div>
                        </div>
                    </EmptyDataTemplate>

                </asp:GridView>

                                <div class="d-flex flex-column align-items-end gap-2">
                                    <div class="d-flex align-items-center gap-2">
                                        <asp:TextBox ID="tbQuantita" runat="server" Text="1" CssClass="ks-qty" />
                                        <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" />
                                    </div>

                                    <asp:ImageButton ID="ImageButton1" runat="server" ImageUrl="Images/cart.png" ToolTip="Aggiungi al Carrello" OnClick="ImageButton1_Click"
                                        CssClass="ks-btn-image" CausesValidation="false" />

                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbQuantita" Display="Dynamic" ErrorMessage="!" SetFocusOnError="True"></asp:RequiredFieldValidator>
                                    <asp:CompareValidator ID="CompareValidator2" runat="server" ControlToValidate="tbQuantita" Display="Dynamic" ErrorMessage="!" Operator="GreaterThan" SetFocusOnError="True" Type="Integer" ValueToCompare="0"></asp:CompareValidator>
                                </div>

                            </ItemTemplate>
                        </asp:TemplateField>

                    </Columns>

                    <PagerStyle CssClass="nav" />
                </asp:GridView>

            </div>

            <div class="mt-3">
                <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" CssClass="body-small text-main-2"></asp:Label>
                <asp:Label ID="lblLinee" runat="server" Text="0" Visible="false"></asp:Label>
            </div>

                        </asp:PlaceHolder>

                        <!-- /Wishlist -->

                    </div>
                </div>
            </div>
        </section>
</div>
</asp:Content>
