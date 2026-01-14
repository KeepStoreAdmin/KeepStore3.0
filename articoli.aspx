<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" MaintainScrollPositionOnPostback="true" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo prodotti
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">

    <link rel="canonical" href="<%= Request.Url.GetLeftPart(System.UriPartial.Path) %>" />

    <style>
        /* KeepStore: pager (GridView) – estetica coerente con template Onus */
        .pagination-ys { display: flex; justify-content: center; margin-top: 18px; }
        .pagination-ys table { margin: 0; border-collapse: separate; border-spacing: 6px 0; }
        .pagination-ys td { padding: 0; }
        .pagination-ys a, .pagination-ys span {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 38px;
            height: 38px;
            padding: 0 10px;
            border: 1px solid rgba(0,0,0,.12);
            border-radius: 10px;
            text-decoration: none;
            line-height: 1;
        }
        .pagination-ys span {
            background: #111;
            color: #fff;
            border-color: #111;
        }
        .pagination-ys a:hover { background: rgba(0,0,0,.04); }

        /* CheckBox WebForms: migliora allineamento input/label nei filtri */
        .filterCheckbox input[type="checkbox"] { margin-right: 8px; vertical-align: middle; }
        .filterCheckbox label { margin: 0; vertical-align: middle; }
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">

    
    <div class="tf-breadcrumb">
        <div class="container">
            <ul class="breadcrumb-list">
                <li><a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a></li>
                <li><span class="text">Articoli</span></li>
            </ul>
        </div>
    </div>

    <section class="flat-spacing-2">
<div class="container mt-3">
        <h1>
            <asp:FormView ID="FormView1" runat="server" DataSourceID="sdsCategorie" EnableViewState="False">
                <ItemTemplate>
                    <asp:Label ID="lblSettore" runat="server" Text='<%# ucase(Eval("SettoriDescrizone")) %>' EnableViewState="False"></asp:Label>
                    »
                    <asp:Label ID="lblCategoria" runat="server" Text='<%# Eval("Descrizione") %>' EnableViewState="False"></asp:Label>
                </ItemTemplate>
            </asp:FormView>
            <asp:Label ID="lblRicerca" runat="server" Text="Risultato ricerca per:" Font-Bold="False" Visible="False"></asp:Label>
            <asp:Label ID="lblRisultati" runat="server" Font-Bold="True"></asp:Label>
        </h1>
    </div>

    <asp:SqlDataSource ID="sdsCategorie" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione, SettoriCodice, SettoriDescrizone FROM vCategorieSettori WHERE ((Abilitato = ?Abilitato) AND (ID = ?ID)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="ID" SessionField="ct" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>

    <asp:SqlDataSource ID="sdsCategorieSettore" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT DISTINCT CategorieId AS Id, CategorieDescrizione AS Descrizione FROM varticolibase WHERE SettoriId=?SettoriId ORDER BY CategorieDescrizione">
        <SelectParameters>
            <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>


    <asp:SqlDataSource ID="sdsTipologie" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vcategorietipologie WHERE ((Abilitato = ?Abilitato) AND (SettoriId = ?SettoriId) AND (CategorieId = ?CategorieId)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
            <asp:SessionParameter Name="CategorieId" SessionField="ct" Type="String" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>
    
    <asp:SqlDataSource ID="sdsGruppo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vcategoriegruppi WHERE ((Abilitato = ?Abilitato) AND (SettoriId = ?SettoriId) AND (CategorieId = ?CategorieId)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
            <asp:SessionParameter Name="CategorieId" SessionField="ct" Type="String" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>

    <asp:SqlDataSource ID="sdsSottogruppo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vcategoriesottogruppi WHERE ((Abilitato = ?Abilitato) AND (SettoriId = ?SettoriId) AND (CategorieId = ?CategorieId)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
            <asp:SessionParameter Name="CategorieId" SessionField="ct" Type="String" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>

    <asp:SqlDataSource ID="sdsMarche" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM vcategoriemarche WHERE Abilitato=@Abilitato AND SettoriId=?SettoriId AND CategorieId=?CategorieId ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" />
            <asp:SessionParameter Name="CategorieId" SessionField="ct" Type="String" />
            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
        </SelectParameters>
    </asp:SqlDataSource>

    <div class="container">

        <div class="row mt-3">

            <!-- Sidebar (Template Onus, SINISTRA) -->
            <div class="col-lg-3 mb-4">
                <aside class="sidebar-filter">

                    <!-- Navigazione categorie -->
                    <div class="facet-categories mb-4">
                        <h6 class="title fw-medium">Categorie</h6>
                        <ul>
                            <asp:Repeater ID="rptCategorieSettore" runat="server" DataSourceID="sdsCategorieSettore">
                                <ItemTemplate>
                                    <li>
                                        <a href='<%# "articoli.aspx?st=" & Session("st") & "&ct=" & Eval("Id") %>'>
                                            <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %>
                                            <i class="icon-arrow-right"></i>
                                        </a>
                                    </li>
                                </ItemTemplate>
                            </asp:Repeater>
                        </ul>
                    </div>

                    <!-- Navigazione tipologie (link) -->
                    <div class="facet-categories mb-4">
                        <h6 class="title fw-medium">Tipologie</h6>
                        <ul>
                            <asp:Repeater ID="rptTipologieLink" runat="server" DataSourceID="sdsTipologie">
                                <ItemTemplate>
                                    <li>
                                        <a href='<%# "articoli.aspx?st=" & Session("st") & "&ct=" & Session("ct") & "&tp=" & Eval("TipologieId") %>'>
                                            <%# Server.HtmlEncode(Convert.ToString(Eval("Descrizione"))) %>
                                            <i class="icon-arrow-right"></i>
                                        </a>
                                    </li>
                                </ItemTemplate>
                            </asp:Repeater>
                        </ul>
                    </div>

                    <!-- Filtri (checkbox multi-selezione) -->
                    <div class="mt-4" runat="server" id="tNavig">

                        <div id="filtersMr" class="mb-4" style="position:relative;">
                            <asp:DataList ID="DataList4" runat="server" DataSourceID="sdsMarche" RepeatLayout="Flow" Font-Size="8pt">
                                <HeaderTemplate>
                                    <div class="widget-facet facet-fieldset">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <p class="facet-title title-sidebar fw-semibold mb-0">Marche</p>
                                            <asp:HyperLink CssClass='body-text-3 link filterRemoveAll' ID="hlTutti" runat="server" NavigateUrl='<%# changeUrlGetParam(Me.Request.Url.toString, "rimuovi", "mr") %>' Text="Rimuovi tutti"></asp:HyperLink>
                                        </div>
                                        <div class="box-fieldset-item">
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <fieldset class="fieldset-item">
                                        <%# If(filterIdsContains("mr",Eval("marcheid").ToString()),"<b>","") %>
                                        <asp:CheckBox ID='CheckBoxMr' checked='<%# If(filterIdsContains("mr",Eval("marcheid").ToString()),True,False) %>' runat='server' AutoPostBack='True' OnCheckedChanged ='CheckBoxMr_CheckedChanged' filterId='<%# Eval("marcheid") %>' CssClass='tf-check filterCheckbox' Text='<%# getCorrectLengthDescription(Eval("Descrizione")) & " " & "<span class=""text-main-4"">(" & Eval("Numero") & ")</span>"  %>' Width='150px' ToolTip='Applica/Rimuovi Filtro'/></asp:CheckBox>
                                        <%# If(filterIdsContains("mr",Eval("marcheid").ToString()),"</b>","") %>
                                    </fieldset>
                                </ItemTemplate>
                                <FooterTemplate>
                                        </div>
                                    </div>
                                </FooterTemplate>
                            </asp:DataList>
                        </div>

                        <div id="filtersTp" class="mb-4" style="position:relative;">
                            <asp:DataList ID="DataList1" runat="server" DataSourceID="sdsTipologie" RepeatLayout="Flow" Font-Size="8pt">
                                <HeaderTemplate>
                                    <div class="widget-facet facet-fieldset">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <p class="facet-title title-sidebar fw-semibold mb-0">Tipologie</p>
                                            <asp:HyperLink CssClass='body-text-3 link filterRemoveAll' ID="hlTutti" runat="server" NavigateUrl='<%# changeUrlGetParam(Me.Request.Url.toString, "rimuovi", "tp") %>' Text="Rimuovi tutti"></asp:HyperLink>
                                        </div>
                                        <div class="box-fieldset-item">
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <fieldset class="fieldset-item">
                                        <%# If(filterIdsContains("tp",Eval("TipologieId").ToString()),"<b>","") %>
                                        <asp:CheckBox ID='CheckBoxTp' checked='<%# If(filterIdsContains("tp",Eval("TipologieId").ToString()),True,False) %>' runat='server' AutoPostBack='True' OnCheckedChanged ='CheckBoxTp_CheckedChanged' filterId='<%# Eval("TipologieId") %>' CssClass='tf-check filterCheckbox' Text='<%# getCorrectLengthDescription(Eval("Descrizione")) & " " & "<span class=""text-main-4"">(" & Eval("Numero") & ")</span>"  %>' Width='150px' ToolTip='Applica/Rimuovi Filtro'/></asp:CheckBox>
                                        <%# If(filterIdsContains("tp",Eval("TipologieId").ToString()),"</b>","") %>
                                    </fieldset>
                                </ItemTemplate>
                                <FooterTemplate>
                                        </div>
                                    </div>
                                </FooterTemplate>
                            </asp:DataList>
                        </div>

                        <div id="filtersGr" class="mb-4" style="position:relative;">
                            <asp:DataList ID="DataList2" runat="server" DataSourceID="sdsGruppo" RepeatLayout="Flow" Font-Size="8pt">
                                <HeaderTemplate>
                                    <div class="widget-facet facet-fieldset">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <p class="facet-title title-sidebar fw-semibold mb-0">Gruppo</p>
                                            <asp:HyperLink CssClass='body-text-3 link filterRemoveAll' ID="hlTutti" runat="server" NavigateUrl='<%# changeUrlGetParam(Me.Request.Url.toString, "rimuovi", "gr") %>' Text="Rimuovi tutti"></asp:HyperLink>
                                        </div>
                                        <div class="box-fieldset-item">
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <fieldset class="fieldset-item">
                                        <%# If(filterIdsContains("gr",Eval("GruppiId").ToString()),"<b>","") %>
                                        <asp:CheckBox ID='CheckBoxGr' checked='<%# If(filterIdsContains("gr",Eval("GruppiId").ToString()),True,False) %>' runat='server' AutoPostBack='True' OnCheckedChanged ='CheckBoxGr_CheckedChanged' filterId='<%# Eval("GruppiId") %>' CssClass='tf-check filterCheckbox' Text='<%# getCorrectLengthDescription(Eval("Descrizione")) & " " & "<span class=""text-main-4"">(" & Eval("Numero") & ")</span>"  %>' Width='150px' ToolTip='Applica/Rimuovi Filtro'/></asp:CheckBox>
                                        <%# If(filterIdsContains("gr",Eval("GruppiId").ToString()),"</b>","") %>
                                    </fieldset>
                                </ItemTemplate>
                                <FooterTemplate>
                                        </div>
                                    </div>
                                </FooterTemplate>
                            </asp:DataList>
                        </div>

                        <div id="filtersSg" class="mb-4" style="position:relative;">
                            <asp:DataList ID="DataList3" runat="server" DataSourceID="sdsSottogruppo" RepeatLayout="Flow" Font-Size="8pt">
                                <HeaderTemplate>
                                    <div class="widget-facet facet-fieldset">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <p class="facet-title title-sidebar fw-semibold mb-0">Sottogruppi</p>
                                            <asp:HyperLink CssClass='body-text-3 link filterRemoveAll' ID="hlTutti" runat="server" NavigateUrl='<%# changeUrlGetParam(Me.Request.Url.toString, "rimuovi", "sg") %>' Text="Rimuovi tutti"></asp:HyperLink>
                                        </div>
                                        <div class="box-fieldset-item">
                                </HeaderTemplate>
                                <ItemTemplate>
                                    <fieldset class="fieldset-item">
                                        <%# If(filterIdsContains("sg",Eval("SottogruppiId").ToString()),"<b>","") %>
                                        <asp:CheckBox ID='CheckBoxSg' checked='<%# If(filterIdsContains("sg",Eval("SottogruppiId").ToString()),True,False) %>' runat='server' AutoPostBack='True' OnCheckedChanged ='CheckBoxSg_CheckedChanged' filterId='<%# Eval("SottogruppiId") %>' CssClass='tf-check filterCheckbox' Text='<%# getCorrectLengthDescription(Eval("Descrizione")) & " " & "<span class=""text-main-4"">(" & Eval("Numero") & ")</span>"  %>' Width='150px' ToolTip='Applica/Rimuovi Filtro'/></asp:CheckBox>
                                        <%# If(filterIdsContains("sg",Eval("SottogruppiId").ToString()),"</b>","") %>
                                    </fieldset>
                                </ItemTemplate>
                                <FooterTemplate>
                                        </div>
                                    </div>
                                </FooterTemplate>
                            </asp:DataList>
                        </div>

                    </div>

                </aside>
            </div>

            <!-- Main content -->

            <div class="col-lg-9">

    <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione1, PrezzoAcquisto, Img1, DescrizioneLunga FROM varticolibase ORDER BY Codice, Descrizione1" EnableViewState="False">
    </asp:SqlDataSource>

    <div class="container mt-3">
        <div class="tf-shop-control flex-wrap gap-10 mb-3">
            <div class="tf-shop-control-left">
                <p class="body-text-3 mb-0">
                    <span class="fw-semibold">Trovati:</span>
                    <asp:Label ID="lblTrovati" runat="server" Font-Bold="True"></asp:Label>
                    <span class="ms-1">articoli</span>
                    <span class="text-muted ms-2">|</span>
                    <span class="ms-2">Visualizzati:</span>
                    <asp:Label ID="lblLinee" runat="server" Text="0"></asp:Label>
                </p>
            </div>

            <div class="tf-shop-control-right d-flex align-items-center flex-wrap gap-10 ms-auto">
                <div class="d-flex align-items-center gap-8">
                    <asp:CheckBox ID="CheckBox_Disponibile" runat="server" AutoPostBack="True" Text="Solo disponibili" />
                </div>

                <div class="d-flex align-items-center gap-8">
                    <span class="body-text-3">Ordina per</span>
                    <asp:DropDownList ID="Drop_Ordinamento" runat="server" AutoPostBack="True" CssClass="form-select form-select-sm">
                        <asp:ListItem Value="varticolibase.Codice">Codice</asp:ListItem>
                        <asp:ListItem Value="varticolibase.Descrizione1">Descrizione</asp:ListItem>
                        <asp:ListItem Value="varticolibase.PrezzoAcquisto">Prezzo crescente</asp:ListItem>
                        <asp:ListItem Value="varticolibase.PrezzoAcquisto DESC">Prezzo decrescente</asp:ListItem>
                    </asp:DropDownList>
                </div>
            </div>
        </div>

        <div id="filtritagliaecolore" runat="server" class="tf-shop-control flex-wrap gap-10 mb-2">
            <div class="d-flex align-items-center gap-8">
                <span class="body-text-3">Filtra taglia</span>
                <asp:DropDownList ID="Drop_Filtra_Taglia" style="text-align:left;vertical-align:middle" runat="server" Width="140px" AutoPostBack="True" BackColor="#FFFF80" Font-Bold="False" Font-Size="10pt" ForeColor="Black">
                    <asp:ListItem Value="P_tutte_taglie">Tutte</asp:ListItem>
                </asp:DropDownList>
            </div>

            <div class="d-flex align-items-center gap-8">
                <span class="body-text-3">Filtra colore</span>
                <asp:DropDownList ID="Drop_Filtra_Colore" style="text-align:left;vertical-align:middle" runat="server" Width="140px" AutoPostBack="True" BackColor="#FFFF80" Font-Bold="False" Font-Size="10pt" ForeColor="Black">
                    <asp:ListItem Value="P_tutti_colori">Tutti</asp:ListItem>
                </asp:DropDownList>
            </div>
        </div>
    </div> <!-- fine container mt-3 -->

    <div class="bg-white home-box-position bg-shadow">
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
                                <a href='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>'
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
                                        <a href='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>'
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
                                                       NavigateUrl='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>'
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

                            <!-- hidden fields -->
                            <asp:TextBox ID="tbID" runat="server" Text='<%# Eval("ID") %>' Visible="false"></asp:TextBox>
                            <asp:TextBox ID="tbInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:TextBox>
                            <asp:HiddenField ID="hfIdArticolo" runat="server" Value='<%# Eval("ID") %>' />
                            <asp:HiddenField ID="hfTCId" runat="server" Value='<%# Eval("TCid") %>' />
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
	
    <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label><br /><br />
    
    <script type="text/javascript">
        $(function () {
            $("[id*=CheckBoxMr]").click(disable_checkbox);
            $("[id*=CheckBoxTp]").click(disable_checkbox);
            $("[id*=CheckBoxGr]").click(disable_checkbox);
            $("[id*=CheckBoxSg]").click(disable_checkbox);
        });
		
        function disable_checkbox() {
            $('#filtersMr').fadeTo('fast', .6);
            $('#filtersMr').append('<div style="position: absolute;top:0;left:0;width: 100%;height:100%;z-index:2;opacity:0.4;filter: alpha(opacity = 50)"></div>');
            $('#filtersTp').fadeTo('fast', .6);
            $('#filtersTp').append('<div style="position: absolute;top:0;left:0;width: 100%;height:100%;z-index:2;opacity:0.4;filter: alpha(opacity = 50)"></div>');
            $('#filtersGr').fadeTo('fast', .6);
            $('#filtersGr').append('<div style="position: absolute;top:0;left:0;width: 100%;height:100%;z-index:2;opacity:0.4;filter: alpha(opacity = 50)"></div>');
            $('#filtersSg').fadeTo('fast', .6);
            $('#filtersSg').append('<div style="position: absolute;top:0;left:0;width: 100%;height:100%;z-index:2;opacity:0.4;filter: alpha(opacity = 50)"></div>');
        }
    </script>

            </div>

        </div>

    </div>

    </section>

</asp:Content>
