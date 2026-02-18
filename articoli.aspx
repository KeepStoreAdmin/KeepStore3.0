<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" MaintainScrollPositionOnPostback="true" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo prodotti
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">

    <asp:Literal ID="litSeoHead" runat="server" />    <%-- NOTE: stili spostati in /Public/assets/keepstore/css/keepstore.css --%>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">

    
    <div class="tf-sp-1">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="<%= ResolveUrl("~/Default.aspx") %>" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Articoli</span>
                </div>
            </div>
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

<div class="canvas-filter-product sidebar-filter handle-canvas left">
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

                        <div class="tf-control-view flat-title-tab-product flex-wrap">
                            <ul class="tf-control-layout menu-tab-line" role="tablist">
                                <li class="tf-view-layout-switch" data-tab="tabgrid-1">
                                    <a href="#" class="tab-link main-title link fw-semibold d-flex active" data-bs-toggle="tab">
                                        <i class="icon-menu-dots"></i>
                                    </a>
                                </li>
                                <li class="tf-view-layout-switch" data-tab="tabgrid-2">
                                    <a href="#" class="tab-link main-title link d-flex fw-semibold" data-bs-toggle="tab">
                                        <i class="icon-dot-line"></i>
                                    </a>
                                </li>
                                <li class="tf-view-layout-switch" data-tab="tablist-1">
                                    <a href="#" class="tab-link main-title link d-flex fw-semibold" data-bs-toggle="tab">
                                        <i class="icon-list-1"></i>
                                    </a>
                                </li>
                                <li class="tf-view-layout-switch" data-tab="tablist-2">
                                    <a href="#" class="tab-link main-title link d-flex fw-semibold" data-bs-toggle="tab">
                                        <i class="icon-list-2"></i>
                                    </a>
                                </li>
                            </ul>
                        </div>

                        <div class="tf-shop-control-right d-flex align-items-center flex-wrap gap-10 ms-auto">
                            <div class="d-flex align-items-center gap-8">
                                <asp:CheckBox ID="CheckBox_Disponibile" runat="server" AutoPostBack="True" Text="Solo disponibili" />
                            </div>

                            <div class="tf-dropdown-sort tf-sort type-sort-by">
                                <div class="btn-select w-100">
                                    <i class="icon-sort"></i>
                                    <p class="body-text-3 w-100">Ordina per</p>
                                    <i class="icon-arrow-down fs-10"></i>
                                </div>
                                <asp:DropDownList ID="Drop_Ordinamento" runat="server" AutoPostBack="True" CssClass="form-select form-select-sm w-100 mt-1">
                                    <asp:ListItem Value="varticolibase.Codice">Codice</asp:ListItem>
                                    <asp:ListItem Value="varticolibase.Descrizione1">Descrizione</asp:ListItem>
                                    <asp:ListItem Value="varticolibase.PrezzoAcquisto">Prezzo crescente</asp:ListItem>
                                    <asp:ListItem Value="varticolibase.PrezzoAcquisto DESC">Prezzo decrescente</asp:ListItem>
                                </asp:DropDownList>
                            </div>
                        </div>
                    </div>

                    <div class="meta-filter-shop" style="display: none;">
                        <div id="product-count-grid" class="count-text"></div>
                        <div id="product-count-list" class="count-text"></div>
                        <div id="applied-filters"></div>
                        <button id="remove-all" class="remove-all-filters" style="display: none;">
                            <span class="caption">REMOVE ALL</span>
                            <i class="icon icon-close"></i>
                        </button>
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
                        <asp:ListView ID="lvProdotti" runat="server"
    DataKeyNames="id"
    DataSourceID="sdsArticoli"
    OnPagePropertiesChanging="lvProdotti_PagePropertiesChanging"
    OnPreRender="lvProdotti_PreRender">
    <LayoutTemplate>
        <div class="tf-grid-layout lg-col-4 md-col-3 sm-col-2 flat-grid-product wrapper-shop layout-tabgrid-1">
            <asp:PlaceHolder ID="itemPlaceholder" runat="server" />
        </div>
    </LayoutTemplate>

    <ItemTemplate>
    <ItemTemplate>
        <div class="card-product ks-card-product">
            <div class="card-product-wrapper">
                <a href='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>' class="product-img">
                    <asp:Image ID="imgProd" runat="server" CssClass="img-product lazyload"
                        AlternateText='<%# H(Eval("Descrizione1")) %>'
                        ImageUrl='<%# checkImg(Eval("Img1")) %>' />
                    <asp:Image ID="imgHover" runat="server" CssClass="img-hover lazyload"
                        AlternateText='<%# H(Eval("Descrizione1")) %>'
                        ImageUrl='<%# checkImg(Eval("Img1")) %>' />
                </a>

                <ul class="list-product-btn top-0 end-0">
                    <li>
                        <asp:LinkButton ID="LB_addToCart" runat="server" CausesValidation="False"
                            OnClick="LB_AddToCart_Click"
                            CssClass="box-icon add-to-cart btn-icon-action hover-tooltip tooltip-left">
                            <span class="icon icon-cart2"></span>
                            <span class="tooltip">Aggiungi al carrello</span>
                        </asp:LinkButton>
                    </li>

                    <li class="d-none d-sm-block wishlist">
                        <asp:LinkButton ID="LB_wishlist" runat="server" CausesValidation="False"
                            OnClick="BT_Aggiungi_wishlist_Click"
                            CssClass="box-icon btn-icon-action hover-tooltip tooltip-left">
                            <i class="icon icon-heart2"></i>
                            <span class="tooltip">Wishlist</span>
                        </asp:LinkButton>
                    </li>

                    <li>
                        <a href='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>'
                            class="box-icon btn-icon-action hover-tooltip tooltip-left">
                            <i class="icon icon-view"></i>
                            <span class="tooltip">Scheda tecnica</span>
                        </a>
                    </li>

                    <li class="d-none d-sm-block">
                        <a href='<%# GetWhatsAppShareUrl(Eval("Descrizione1"), Eval("id"), Eval("TCid")) %>'
                            class="box-icon btn-icon-action hover-tooltip tooltip-left">
                            <img src='<%# GetWhatsAppIconUrl() %>' alt="WhatsApp" style="height:24px;" />
                            <span class="tooltip">WhatsApp</span>
                        </a>
                    </li>
                </ul>

                <asp:Panel ID="pnlSale" runat="server" Visible='<%# HasPromo(Eval("InOfferta"), Eval("PrezzoPromoIvato")) %>'>
                    <div class="box-sale-wrap pst-default">
                        <p class="small-text">Sale</p>
                        <p class="title-sidebar-2"><%# GetDiscountPercent(Eval("PrezzoIvato"), Eval("PrezzoPromoIvato")) %></p>
                    </div>
                </asp:Panel>
            </div>

            <div class="card-product-info">
                <div class="box-title">
                    <div>
                        <p class="product-tag caption text-main-2"><%# H(Eval("MarcheDescrizione")) %></p>
                        <asp:HyperLink ID="hlTitolo" runat="server"
                            CssClass="name-product body-md-2 fw-semibold text-secondary link"
                            NavigateUrl='<%# ResolveUrl("~/articolo.aspx?id=" & Eval("id") & "&TCid=" & Eval("TCid")) %>'
                            Text='<%# H(Eval("Descrizione1")) %>'></asp:HyperLink>
                    </div>

                    <p class="price-wrap fw-medium">
                        <asp:Label ID="lblPrezzoNew" runat="server"
                            CssClass="new-price price-text fw-medium"
                            Text='<%# GetPriceNewText(Eval("InOfferta"), Eval("PrezzoPromoIvato"), Eval("PrezzoIvato")) %>'></asp:Label>

                        <asp:Label ID="lblPrezzoOld" runat="server"
                            CssClass="old-price body-md-2 text-main-2"
                            Visible='<%# HasPromo(Eval("InOfferta"), Eval("PrezzoPromoIvato")) %>'
                            Text='<%# GetPriceOldText(Eval("InOfferta"), Eval("PrezzoPromoIvato"), Eval("PrezzoIvato")) %>'></asp:Label>
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
                <asp:HiddenField ID="hfIdArticolo" runat="server" Value='<%# Eval("id") %>' />
                <asp:HiddenField ID="hfTCId" runat="server" Value='<%# Eval("TCid") %>' />
            </div>
        </div>
    </ItemTemplate>
</ItemTemplate>

    <EmptyDataTemplate>
        <div class="tf-page-title py-5">
                                    <div class="heading text-center">Nessun prodotto trovato</div>
                                    <p class="text text-center mt-3">Prova a rimuovere alcuni filtri o cambia ricerca.</p>
                                    <div class="text-center mt-4">
                                        <a class="tf-btn btn-fill" href="articoli.aspx">Rimuovi filtri</a>
                                    </div>
                                </div>
    </EmptyDataTemplate>
</asp:ListView>

<div id="ksMultiFooter" runat="server" class="ks-grid-footer d-flex justify-content-center align-items-center gap-10 py-3">
    <span class="body-text-3 fw-semibold">Aggiungi selezionati</span>
    <asp:ImageButton ID="Selezione_Multipla" runat="server" ImageUrl="~/Public/Images/aggiungiMultiplo.png" OnClick="Selezione_Multipla_Click" AlternateText="Aggiungi selezionati" />
</div>

<div id="ksPagerWrap" runat="server" class="d-flex justify-content-center mt-4">
    <div class="ks-pager wg-pagination wd-load">
        <asp:DataPager ID="dpProdotti" runat="server" PagedControlID="lvProdotti" PageSize="12">
            <Fields>
                <asp:NextPreviousPagerField ShowFirstPageButton="False" ShowPreviousPageButton="True"
                    ShowNextPageButton="False" ShowLastPageButton="False" ButtonType="Link"
                    PreviousPageText="<i class='icon-arrow-left-lg'></i>"  ButtonCssClass="link" />
                <asp:NumericPagerField ButtonType="Link" RenderNonBreakingSpacesBetweenControls="False"
                    NumericButtonCssClass="title-normal link"
                    CurrentPageLabelCssClass="title-normal link ks-current" />
                <asp:NextPreviousPagerField ShowFirstPageButton="False" ShowPreviousPageButton="False"
                    ShowNextPageButton="True" ShowLastPageButton="False" ButtonType="Link"
                    NextPageText="<i class='icon-arrow-right-lg'></i>"  ButtonCssClass="link" />
            </Fields>
        </asp:DataPager>
    </div>
</div>
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
                

            </div>
        </div>
    </div>

    <div class="overlay-filter" id="overlay-filter"></div>
</section>

</asp:Content>
