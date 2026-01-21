<%@ Page Language="VB" AutoEventWireup="false" CodeFile="articolix.aspx.vb" Inherits="articolix" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Offerte</title>
</head>
<body>
    <form id="form1" runat="server">
    <div>
    <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM varticolibase ORDER BY Codice, Descrizione1" EnableViewState="False">
    </asp:SqlDataSource>
    
<asp:GridView ID="GridView1" runat="server"
    AutoGenerateColumns="False"
    DataKeyNames="id"
    DataSourceID="sdsArticoli"
    AllowPaging="True"
    Font-Size="8pt"
    GridLines="None"
    CellPadding="3"
    Width="100%"
    ShowFooter="True"
    ShowHeader="False"
    CssClass="table-borderless">

    <Columns>
        <asp:TemplateField>
            <ItemTemplate>
                <div class="card-product style-border mb-4">
                    <div class="card-product-wrapper d-flex flex-wrap">
                        <!-- IMMAGINE PRODOTTO -->
                        <a href='<%# "~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid") %>'
                           class="product-img">
                            <asp:Image ID="imgProd"
                                       runat="server"
                                       CssClass="img-product lazyload"
                                       AlternateText='<%# Eval("Descrizione1") %>'
                                       ImageUrl='<%# checkImg(Eval("img1")) %>' />
                        </a>

                        <!-- BOTTONI AZIONE (wishlist, scheda, whatsapp) -->
                        <ul class="list-product-btn">
                            <li class="wishlist">
                                <asp:LinkButton ID="LB_wishlist"
                                                runat="server"
                                                OnClick="BT_Aggiungi_wishlist_Click"
                                                CssClass="box-icon btn-icon-action hover-tooltip tooltip-left">
                                    <i class="icon icon-heart2"></i>
                                    <span class="tooltip">Aggiungi a Wishlist</span>
                                </asp:LinkButton>
                            </li>
                            <li>
                                <a href='<%# "~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid") %>'
                                   class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                    <i class="icon icon-view"></i>
                                    <span class="tooltip">Scheda tecnica</span>
                                </a>
                            </li>
                            <li>
                                <a href='https://wa.me/?text=<%# Eval("Descrizione1") %> - https://<%# Session("AziendaUrl") %>/articolo.aspx?id=<%# Eval("id") %>%26TCid=<%# Eval("TCid") %>'
                                   class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                    <img src='https://<%# Session("AziendaUrl") %>/Public/Images/WhatsApp-Symbolo.png'
                                         alt="WhatsApp"
                                         style="height:24px;" />
                                    <span class="tooltip">Condividi su WhatsApp</span>
                                </a>
                            </li>
                        </ul>
                    </div>

                    <!-- INFO PRODOTTO -->
                    <div class="card-product-info">
                        <div class="box-title d-flex flex-column">
                            <p class="caption text-main-2 font-2">
                                <%# Eval("MarcheDescrizione") %>
                            </p>
                            <h6>
                                <asp:HyperLink ID="hlTitolo"
                                               runat="server"
                                               CssClass="name-product body-md-2 fw-semibold text-secondary link"
                                               NavigateUrl='<%# "~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid") %>'
                                               Text='<%# Eval("Descrizione1") %>' />
                            </h6>
                        </div>

                        <!-- CODICE / EAN -->
                        <p class="body-small text-main-2 mb-1">
                            Codice:
                            <span class="fw-semibold"><%# Eval("Codice") %></span>
                            &nbsp;&nbsp;
                            EAN:
                            <span class="fw-semibold"><%# Eval("Ean") %></span>
                        </p>

                        <!-- DESCRIZIONE BREVE -->
                        <p class="body-text-3" style="text-align:justify;">
                            <%# sotto_stringa(Eval("DescrizioneLunga")) %>
                        </p>

                        <!-- DISPONIBILITÀ -->
                        <div class="d-flex flex-wrap align-items-center mt-2 mb-2"
                             style="border-top:1px dotted #ccc; border-bottom:1px dotted #ccc; padding:4px 0;">
                            <span class="body-small fw-semibold mr-2">Disponibilità:</span>
                            <asp:Label ID="Label_dispo"
                                       runat="server"
                                       CssClass="body-small fw-bold text-danger"
                                       Text='<%# IIf(Eval("Giacenza") > 1000, ">1000", IIf(Eval("Giacenza").ToString().Contains("-"), Eval("Giacenza").ToString().Replace("-","&minus;"), Eval("Giacenza"))) %>' />
                            &nbsp;&nbsp;
                            <span class="body-small fw-semibold mr-1">Impegnati:</span>
                            <asp:Label ID="Label_imp"
                                       runat="server"
                                       CssClass="body-small fw-bold text-danger"
                                       Text='<%# IIf(Val(Eval("Impegnata").ToString()) > 1000, ">1000", Val(Eval("Impegnata").ToString())) %>' />
                            &nbsp;&nbsp;
                            <span class="body-small fw-semibold mr-1">In arrivo:</span>
                            <asp:Label ID="Label_arrivo"
                                       runat="server"
                                       CssClass="body-small fw-bold text-danger"
                                       Text='<%# IIf(Val(Eval("InOrdine").ToString()) > 1000, ">1000", Val(Eval("InOrdine").ToString())) %>' />
                        </div>

                        <!-- PREZZO + PROMO -->
                        <div class="d-flex flex-wrap justify-content-between align-items-center mt-2">
                            <div>
                                <%-- SCONTISTICA / PROMO SEMPLIFICATA --%>
                                <asp:Label ID="lblPrezzoPromo"
                                           runat="server"
                                           CssClass="h4 fw-normal text-primary mb-0 d-block"
                                           Text='<%# Bind("PrezzoIvato", "{0:C}") %>'></asp:Label>

                                <asp:Panel ID="Panel_in_offerta"
                                           runat="server"
                                           Visible='<%# Eval("InOfferta") %>'>
                                    <span class="body-small text-main-2">
                                        invece di
                                        <asp:Label ID="Label4"
                                                   runat="server"
                                                   CssClass="text-danger"
                                                   Style="text-decoration:line-through;"
                                                   Text='<%# Bind("PrezzoOldIvato", "{0:C}") %>'></asp:Label>
                                    </span>
                                </asp:Panel>
                            </div>

                            <!-- STATO DISPONIBILE / NON DISPONIBILE -->
                            <div class="text-right">
                                <%# IIf(Eval("Giacenza") > 0,
                                        "<span style=""color:green; font-weight:bold; font-size:11pt;"">DISPONIBILE</span>",
                                        "<span style=""color:red; font-weight:bold; font-size:12pt;"">NON DISPONIBILE</span>") %>
                            </div>
                        </div>

                        <!-- QUANTITÀ + CARRELLO -->
                        <div class="d-flex flex-wrap justify-content-end align-items-center mt-3">
                            <asp:CheckBox ID="CheckBox_SelezioneMultipla"
                                          runat="server"
                                          CssClass="mr-2" />

                            <div class="d-flex align-items-center mr-2" style="height:37px; background-color: #f0f0f0;">
                                <i data-qty-action="decrementQty"
                                   class="fa fa-minus-circle fa-2x align-self-center mx-1"
                                   style="font-size:16px;"></i>
                                <asp:TextBox ID="tbQuantita"
                                             runat="server"
                                             Width="50px"
                                             Style="text-align:center;font-size: 13px; font-weight: bold;"
                                             MaxLength="4">1</asp:TextBox>
                                <i data-qty-action="incrementQty"
                                   class="fa fa-plus-circle fa-2x align-self-center mx-1"
                                   style="font-size:16px;"></i>
                            </div>

                            <asp:ImageButton ID="ImageButton2"
                                             runat="server"
                                             OnClick="ImageButton1_Click"
                                             ToolTip="Aggiungi al Carrello"
                                             Style="border:none;height:37px; width:180px;"
                                             ImageUrl="Public/Images/spazio_vuoto.gif" />
                        </div>
                    </div>

                    <%-- Hidden fields se ti servono ancora lato server --%>
                    <asp:TextBox ID="tbID" runat="server" Text='<%# Eval("ID") %>' Visible="false"></asp:TextBox>
                    <asp:TextBox ID="tbInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:TextBox>
                </div>
            </ItemTemplate>

            <FooterTemplate>
                <img src="Public/Images/selection.gif" style="max-width:100%" alt="" />
                &nbsp;&nbsp;&nbsp;
                <asp:ImageButton ID="Selezione_Multipla"
                                 runat="server"
                                 title="Aggiungi gli articoli selezionati al carrello"
                                 OnClick="Selezione_Multipla_Click"
                                 ImageUrl="~/Public/Images/aggiungiMultiplo.png" />
            </FooterTemplate>

            <FooterStyle CssClass="bg-light text-center" />
        </asp:TemplateField>
    </Columns>

    <PagerStyle CssClass="pagination-ys" />
    <PagerSettings Mode="NumericFirstLast" FirstPageText="Inizio" LastPageText="Fine" />
</asp:GridView>

</div>
    </form>
</body>
</html>
