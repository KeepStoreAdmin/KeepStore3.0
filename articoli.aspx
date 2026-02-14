<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" MaintainScrollPositionOnPostback="true" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo prodotti
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">

    <asp:Literal ID="litSeoHead" runat="server" />
    <style type="text/css">
        .filter-scroll { max-height: 260px; overflow: auto; padding-right: 6px; }
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
    

        /* ==========================================================
           STEP16 (CATALOGO/UI): GridView -> ONus grid + card polish
           - Trasforma la <table> del GridView in una griglia responsive
           - Uniforma immagini, hover, badge e barra quantità
           ========================================================== */
        table.ks-gridview-as-grid {
            width: 100% !important;
            display: grid;
            grid-template-columns: repeat(4, minmax(0, 1fr));
            gap: 20px;
        }
        @media (max-width: 1199.98px) {
            table.ks-gridview-as-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
        }
        @media (max-width: 991.98px) {
            table.ks-gridview-as-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        }
        @media (max-width: 575.98px) {
            table.ks-gridview-as-grid { grid-template-columns: repeat(1, minmax(0, 1fr)); }
        }
        table.ks-gridview-as-grid > tbody,
        table.ks-gridview-as-grid > tbody > tr,
        table.ks-gridview-as-grid > tbody > tr > td {
            display: contents;
        }

        /* Eccezioni per footer/pager, che devono stare a tutta larghezza */
        table.ks-gridview-as-grid > tbody > tr.ks-grid-footer,
        table.ks-gridview-as-grid > tbody > tr.pagination-ys {
            display: block !important;
            grid-column: 1 / -1;
        }
        table.ks-gridview-as-grid > tbody > tr.ks-grid-footer > td,
        table.ks-gridview-as-grid > tbody > tr.pagination-ys > td {
            display: block;
            width: 100%;
        }

        /* Card: immagine quadrata e hover */
        .ks-card-product .product-img {
            display: block;
            position: relative;
            aspect-ratio: 1 / 1;
            overflow: hidden;
        }
        .ks-card-product .img-product,
        .ks-card-product .img-hover {
            width: 100% !important;
            height: 100% !important;
            object-fit: contain;
        }
        .ks-card-product .img-hover {
            position: absolute;
            inset: 0;
            opacity: 0;
            transition: opacity .25s ease;
        }
        .ks-card-product:hover .img-hover { opacity: 1; }

        /* Quantità: usa classi ONus (main.js) */
        .ks-card-product .wg-quantity {
            min-width: 120px;
        }
        .ks-card-product .quantity-product {
            width: 48px;
            text-align: center;
        }

        /* Multi selezione: compatta e non invasiva */
        .ks-card-product .ks-multi {
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }

</style>
    <style>
        /* Facet filters: link-style checkbox (can be reverted to classic checkbox) */
        .filterLink input[type="checkbox"]{
            position:absolute;
            opacity:0;
            width:1px;
            height:1px;
            margin:0;
            padding:0;
        }
        .filterLink label{
            cursor:pointer;
            text-decoration: underline;
            text-underline-offset: 2px;
        }
        .filterLink input[type="checkbox"]:checked + label{
            font-weight:600;
            text-decoration:none;
        }
        .filterLink label:focus,
        .filterLink label:hover{
            text-decoration-thickness: 2px;
        }

        /* Product card micro-alignments */
        .card-product .name-product{
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
            overflow: hidden;
            min-height: 3.0em;
        }
        .card-product .price-wrap{
            display:flex;
            gap:8px;
            align-items:baseline;
            flex-wrap:wrap;
        }
        .card-product .price-wrap .compare-at{
            text-decoration: line-through;
            opacity: .6;
            font-size: .9em;
        }
        .card-product .product-badges{
            display:flex;
            gap:6px;
            flex-wrap:wrap;
            margin-top:6px;
        }
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
                    <asp:Label ID="lblCategoria" runat="server" Text='<%# H(Eval("Descrizione")) %>' EnableViewState="False"></asp:Label>
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

    <div class="flat-content">
        <div class="container">
            <div class="tf-product-view-content wrapper-control-shop">

                <!-- AREA CONTENUTO (prodotti) -->
                <div class="content-area">

                    <asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                        SelectCommand="SELECT id, Codice, Descrizione1, PrezzoAcquisto, Img1, DescrizioneLunga FROM varticolibase ORDER BY Codice, Descrizione1" EnableViewState="False">
                    </asp:SqlDataSource>

                    <div class="tf-shop-control flex-wrap gap-10 mb-3">
                        <div class="d-flex align-items-center gap-10">
                            <button id="filterShop" type="button" class="tf-btn-filter d-flex d-xl-none">
                                <span class="icon icon-filter">
                                    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="#121212" viewBox="0 0 256 256">
                                        <path d="M176,80a8,8,0,0,1,8-8h32a8,8,0,0,1,0,16H184A8,8,0,0,1,176,80ZM40,88H144v16a8,8,0,0,0,16,0V56a8,8,0,0,0-16,0V72H40a8,8,0,0,0,0,16Zm176,80H120a8,8,0,0,0,0,16h96a8,8,0,0,0,0-16ZM88,144a8,8,0,0,0-8,8v16H40a8,8,0,0,0,0,16H80v16a8,8,0,0,0,16,0V152A8,8,0,0,0,88,144Z"></path>
                                    </svg>
                                </span>
                                <span class="body-md-2 fw-medium">Filtri</span>
                            </button>

                            <p class="body-text-3 mb-0 d-none d-lg-block">
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

                    <div id="filtritagliaecolore" runat="server" class="tf-shop-control flex-wrap gap-10 mb-3">
                        <div class="d-flex align-items-center gap-8">
                            <span class="body-text-3">Filtra taglia</span>
                            <asp:DropDownList ID="Drop_Filtra_Taglia" runat="server" Width="160px" AutoPostBack="True" CssClass="form-select form-select-sm">
                                <asp:ListItem Value="P_tutte_taglie">Tutte</asp:ListItem>
                            </asp:DropDownList>
                        </div>

                        <div class="d-flex align-items-center gap-8">
                            <span class="body-text-3">Filtra colore</span>
                            <asp:DropDownList ID="Drop_Filtra_Colore" runat="server" Width="160px" AutoPostBack="True" CssClass="form-select form-select-sm">
                                <asp:ListItem Value="P_tutti_colori">Tutti</asp:ListItem>
                            </asp:DropDownList>
                        </div>
                    </div>

                    <div class="gridLayout-wrapper">
                        <asp:GridView ID="GridView1" runat="server"
                            AutoGenerateColumns="False"
                            DataKeyNames="id"
                            DataSourceID="sdsArticoli"
                            AllowPaging="True"
                            Font-Size="8pt"
                            GridLines="None"
                            CellPadding="0"
                            Width="100%"
                            ShowFooter="True"
                            ShowHeader="False"
                            CssClass="table-borderless ks-gridview-as-grid tf-grid-layout lg-col-4 md-col-3 sm-col-2 flat-grid-product wrapper-shop layout-tabgrid-1">

                            <Columns>
                                <asp:TemplateField>
                                    <ItemTemplate>
                                        <div class="card-product ks-card-product">

                                            <div class="card-product-wrapper">
                                                <a href='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>' class="product-img">
                                                    <asp:Image ID="imgProd" runat="server" CssClass="img-product lazyload" AlternateText='<%# H(Eval("Descrizione1")) %>' ImageUrl='<%# checkImg(Eval("img1")) %>' />
                                                    <asp:Image ID="imgHover" runat="server" CssClass="img-hover lazyload" AlternateText='<%# H(Eval("Descrizione1")) %>' ImageUrl='<%# checkImg(Eval("img1")) %>' />
                                                </a>

                                                <ul class="list-product-btn top-0 end-0">
                                                    <li>
                                                        <asp:ImageButton ID="ImageButton2" runat="server" OnClick="ImageButton1_Click" CssClass="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left" ToolTip="Aggiungi al carrello" ImageUrl="~/Public/assets/keepstore/images/icon-cart2.svg" />
                                                    </li>

                                                    <li class="d-none d-sm-block wishlist">
                                                        <asp:LinkButton ID="LB_wishlist" runat="server" OnClick="BT_Aggiungi_wishlist_Click" CssClass="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                            <i class="icon icon-heart2"></i>
                                                            <span class="tooltip">Wishlist</span>
                                                        </asp:LinkButton>
                                                    </li>

                                                    <li>
                                                        <a href='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>' class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                            <i class="icon icon-view"></i>
                                                            <span class="tooltip">Scheda tecnica</span>
                                                        </a>
                                                    </li>

                                                    <li class="d-none d-sm-block">
                                                        <a href='<%# GetWhatsAppShareUrl(Eval("Descrizione1"), Eval("id"), Eval("TCid")) %>' class="box-icon btn-icon-action hover-tooltip tooltip-left">
                                                            <img src='<%# GetWhatsAppIconUrl() %>' alt="WhatsApp" style="height:24px;" />
                                                            <span class="tooltip">WhatsApp</span>
                                                        </a>
                                                    </li>
                                                </ul>

                                                <asp:Panel ID="pnlSale" runat="server" Visible='<%# Eval("InOfferta") %>'>
                                                    <div class="box-sale-wrap pst-default">
                                                        <p class="small-text">Sale</p>
                                                        <p class="title-sidebar-2"><%# GetDiscountPercent(Eval("PrezzoOldIvato"), Eval("PrezzoIvato")) %></p>
                                                    </div>
                                                </asp:Panel>
                                            </div>

                                            <div class="card-product-info">
                                                <div class="box-title">
                                                    <div>
                                                        <p class="product-tag caption text-main-2"><%# H(Eval("MarcheDescrizione")) %></p>
                                                        <asp:HyperLink ID="hlTitolo" runat="server" CssClass="name-product body-md-2 fw-semibold text-secondary link" NavigateUrl='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>' Text='<%# H(Eval("Descrizione1")) %>'></asp:HyperLink>
                                                    </div>
                                                    <p class="price-wrap fw-medium">
                                                        <asp:Label ID="lblPrezzoPromo" runat="server" CssClass="new-price price-text fw-medium" Text='<%# Bind("PrezzoIvato", "{0:C}") %>'></asp:Label>
                                                        <asp:Label ID="lblPrezzoVecchio" runat="server" CssClass="old-price body-md-2 text-main-2" Visible='<%# Eval("InOfferta") %>' Text='<%# Bind("PrezzoOldIvato", "{0:C}") %>'></asp:Label>
                                                    </p>
                                                </div>
                                            </div>

                                            <div class="card-product-btn">
                                                <div class="d-flex align-items-center justify-content-between flex-wrap gap-10">
                                                    <div class="wg-quantity">
                                                        <span class="btn-quantity minus-btn"><i class="icon-minus"></i></span>
                                                        <asp:TextBox ID="tbQuantita" runat="server" CssClass="quantity-product" Text="1" MaxLength="4"></asp:TextBox>
                                                        <span class="btn-quantity plus-btn"><i class="icon-plus"></i></span>
                                                    </div>

                                                    <div class="ks-multi">
                                                        <asp:CheckBox ID="CheckBox_SelezioneMultipla" runat="server" ToolTip="Seleziona per aggiunta multipla" />
                                                        <span class="caption text-main-2">Multi</span>
                                                    </div>
                                                </div>

                                                <!-- Campi per la logica esistente (ID/TCID/QTA) -->
                                                <asp:TextBox ID="tbID" runat="server" Text='<%# Eval("ID") %>' Visible="false"></asp:TextBox>
                                                <asp:HiddenField ID="hfIdArticolo" runat="server" Value='<%# Eval("ID") %>' />
                                                <asp:HiddenField ID="hfTCId" runat="server" Value='<%# Eval("TCid") %>' />
                                            </div>
                                        </div>
                                    </ItemTemplate>

                                    <FooterTemplate>
                                        <div class="ks-grid-footer d-flex justify-content-center align-items-center gap-10 py-3">
                                            <span class="body-text-3 fw-semibold">Aggiungi selezionati</span>
                                            <asp:ImageButton ID="Selezione_Multipla" runat="server" ImageUrl="~/Public/Images/aggiungiMultiplo.png" OnClick="Selezione_Multipla_Click" AlternateText="Aggiungi selezionati" />
                                        </div>
                                    </FooterTemplate>
                                </asp:TemplateField>
                            </Columns>
                            <FooterStyle CssClass="ks-grid-footer" />



                            <PagerStyle CssClass="pagination-ys" />
                            <PagerSettings Position="Bottom" Mode="NumericFirstLast" FirstPageText="&lt;&lt;" LastPageText="&gt;&gt;" />
                        </asp:GridView>
                    </div>

                    <div class="mt-3">
                        <asp:Label ID="lblPrezzi" runat="server" Font-Italic="True" ForeColor="#7D879C" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label>
                    </div>

                </div>

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


                <!-- SIDEBAR / FILTRI (ONus: canvas-filter-product right) -->
                <div class="canvas-filter-product sidebar-filter handle-canvas right">
                    <div class="canvas-wrapper">
                        <div class="canvas-header d-flex d-xl-none">
                            <h5 class="title">Filtri</h5>
                            <span class="icon-close link icon-close-popup close-filter"></span>
                        </div>
                        <div class="canvas-body">

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
                                                <div class="box-fieldset-item filter-scroll">
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
                                                <div class="box-fieldset-item filter-scroll">
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
                                                    <asp:HyperLink CssClass='body-text-3 link filterRemoveAll' ID="hlTutti" runat="server" NavigateUrl='<%# changeUrlGetParam(Me.Request.Url.tostring, "rimuovi", "gr") %>' Text="Rimuovi tutti"></asp:HyperLink>
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

                        </div>
                    </div>
                </div>

            </div>
        </div>
    </div>

    <div class="overlay-filter" id="overlay-filter"></div>
</section>

</asp:Content>
