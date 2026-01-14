<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="Articoli" MaintainScrollPositionOnPostback="true" %>
<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Catalogo prodotti
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <link rel="canonical" href="<%= Request.Url.GetLeftPart(System.UriPartial.Path) %>" />

    <style type="text/css">
        /* Sidebar filter: scrollable blocks */
        .filter-scroll {
            max-height: 240px;
            overflow-y: auto;
            padding-right: 6px;
        }
        .filter-scroll::-webkit-scrollbar { width: 6px; }
        .filter-scroll::-webkit-scrollbar-thumb {
            background-color: rgba(0, 0, 0, 0.2);
            border-radius: 3px;
        }

        /* GridView => responsive product grid */
        .ks-products { --ks-cols: 4; }
        @media (max-width: 1199.98px) { .ks-products { --ks-cols: 3; } }
        @media (max-width: 991.98px)  { .ks-products { --ks-cols: 2; } }
        @media (max-width: 575.98px)  { .ks-products { --ks-cols: 1; } }

        .ks-products #GridView1 { width: 100%; }
        .ks-products #GridView1 > tbody {
            display: flex;
            flex-wrap: wrap;
            gap: 24px;
        }
        .ks-products #GridView1 > tbody > tr {
            flex: 0 0 calc((100% - (var(--ks-cols) - 1) * 24px) / var(--ks-cols));
            max-width: calc((100% - (var(--ks-cols) - 1) * 24px) / var(--ks-cols));
        }
        .ks-products #GridView1 > tbody > tr > td {
            display: block;
            padding: 0 !important;
            border: 0 !important;
        }
        /* Pager/Footer rows must span full width */
        .ks-products #GridView1 > tbody > tr.pagination-ys,
        .ks-products #GridView1 > tbody > tr.bg-light,
        .ks-products #GridView1 > tbody > tr.text-center,
        .ks-products #GridView1 > tbody > tr > td.pagination-ys,
        .ks-products #GridView1 > tbody > tr > td.bg-light,
        .ks-products #GridView1 > tbody > tr > td.text-center {
            flex: 0 0 100%;
            max-width: 100%;
        }

        /* GridView pager styling (closest to ONUS) */
        .pagination-ys a,
        .pagination-ys span {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 38px;
            height: 38px;
            padding: 0 10px;
            margin: 0 4px;
            border: 1px solid rgba(0, 0, 0, 0.15);
            border-radius: 10px;
            text-decoration: none;
            font-size: 14px;
            line-height: 1;
        }
        .pagination-ys a:hover { border-color: rgba(0, 0, 0, 0.35); }
        .pagination-ys span {
            background: rgba(0, 0, 0, 0.06);
            font-weight: 600;
        }

        /* Mobile filter drawer (no duplicated server-controls) */
        .ks-sidebar-backdrop {
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.45);
            z-index: 1040;
            display: none;
        }
        .ks-shop-sidebar {
            position: relative;
        }
        @media (max-width: 1199.98px) {
            .ks-shop-sidebar {
                position: fixed;
                top: 0;
                left: -360px;
                height: 100vh;
                width: 340px;
                max-width: 92vw;
                z-index: 1050;
                background: #fff;
                overflow-y: auto;
                padding: 18px 18px 24px 18px;
                transition: left 0.22s ease-in-out;
                box-shadow: 0 16px 40px rgba(0, 0, 0, 0.22);
            }
            html.ks-sidebar-open .ks-shop-sidebar { left: 0; }
            html.ks-sidebar-open .ks-sidebar-backdrop { display: block; }
            html.ks-sidebar-open { overflow: hidden; }
        }

        /* View control buttons */
        .ks-view-btn {
            width: 38px;
            height: 38px;
            border: 1px solid rgba(0, 0, 0, 0.15);
            border-radius: 10px;
            background: transparent;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 0;
        }
        .ks-view-btn[aria-pressed="true"] {
            background: rgba(0, 0, 0, 0.06);
            border-color: rgba(0, 0, 0, 0.35);
        }
    </style>

    <script type="text/javascript">
        (function () {
            function qs(sel) { return document.querySelector(sel); }
            function setHtmlClass(cls, enabled) {
                var el = document.documentElement;
                if (!el) return;
                if (enabled) el.classList.add(cls); else el.classList.remove(cls);
            }

            window.KeepStoreSidebar = {
                open: function () { setHtmlClass("ks-sidebar-open", true); },
                close: function () { setHtmlClass("ks-sidebar-open", false); },
                toggle: function () {
                    var el = document.documentElement;
                    if (!el) return;
                    if (el.classList.contains("ks-sidebar-open")) window.KeepStoreSidebar.close();
                    else window.KeepStoreSidebar.open();
                }
            };

            window.KeepStoreView = {
                setCols: function (cols) {
                    var grid = qs("#ksProducts");
                    if (!grid) return;
                    grid.style.setProperty("--ks-cols", String(cols));

                    var btns = document.querySelectorAll("[data-ks-cols]");
                    btns.forEach(function (b) {
                        b.setAttribute("aria-pressed", (b.getAttribute("data-ks-cols") === String(cols)) ? "true" : "false");
                    });
                }
            };

            document.addEventListener("DOMContentLoaded", function () {
                // Close sidebar when clicking backdrop
                var backdrop = qs("#ksSidebarBackdrop");
                if (backdrop) backdrop.addEventListener("click", function () { window.KeepStoreSidebar.close(); });

                // Default view based on viewport (keeps mobile readable)
                var defaultCols = 4;
                if (window.matchMedia) {
                    if (window.matchMedia("(max-width: 575.98px)").matches) defaultCols = 1;
                    else if (window.matchMedia("(max-width: 991.98px)").matches) defaultCols = 2;
                    else if (window.matchMedia("(max-width: 1199.98px)").matches) defaultCols = 3;
                }
                window.KeepStoreView.setCols(defaultCols);
});
        })();
    </script>
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
            <div class="col-lg-3 mb-4 ks-shop-sidebar" id="ksShopSidebar">
                <aside class="sidebar-filter">
                <div class="d-flex d-xl-none justify-content-between align-items-center mb-3">
                    <p class="title-sidebar fw-semibold mb-0">Filtri</p>
                    <button type="button" class="btn-close" aria-label="Chiudi" onclick="KeepStoreSidebar.close();"></button>
                </div>

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
                <div class="d-flex align-items-center gap-10 flex-wrap">
                    <button type="button" class="tf-btn-filter d-flex d-xl-none align-items-center gap-6" onclick="KeepStoreSidebar.open();" aria-label="Apri filtri">
                        <span class="ks-view-btn" style="border:0; width:auto; height:auto; border-radius:0; padding:0; background:transparent;">
                            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                                <path d="M3 5h18M6 12h12M10 19h4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                            </svg>
                        </span>
                        <span class="body-md-2 fw-medium">Filtri</span>
                    </button>

                    <p class="body-text-3 mb-0">
                        <span class="fw-semibold">Trovati:</span> <asp:Label ID="lblTrovati" runat="server"></asp:Label>
                        <span class="ms-2 d-none d-md-inline">Mostra:</span> <asp:Label ID="lblLinee" runat="server" Text="0"></asp:Label>
                    </p>
                </div>

                <div class="d-flex align-items-center gap-10 flex-wrap">
                    <div class="d-flex align-items-center gap-6">
                        <button type="button" class="ks-view-btn" data-ks-cols="4" aria-pressed="true" aria-label="Vista 4 colonne" onclick="KeepStoreView.setCols(4);">
                            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                                <path d="M4 4h7v7H4V4zm9 0h7v7h-7V4zM4 13h7v7H4v-7zm9 0h7v7h-7v-7z" fill="currentColor"/>
                            </svg>
                        </button>
                        <button type="button" class="ks-view-btn" data-ks-cols="3" aria-pressed="false" aria-label="Vista 3 colonne" onclick="KeepStoreView.setCols(3);">
                            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                                <path d="M4 4h5v7H4V4zm7 0h5v7h-5V4zm7 0h2v7h-2V4zM4 13h5v7H4v-7zm7 0h5v7h-5v-7zm7 0h2v7h-2v-7z" fill="currentColor"/>
                            </svg>
                        </button>
                        <button type="button" class="ks-view-btn" data-ks-cols="2" aria-pressed="false" aria-label="Vista 2 colonne" onclick="KeepStoreView.setCols(2);">
                            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                                <path d="M4 4h8v7H4V4zm10 0h6v7h-6V4zM4 13h8v7H4v-7zm10 13v-7h6v7h-6z" fill="currentColor"/>
                            </svg>
                        </button>
                        <button type="button" class="ks-view-btn" data-ks-cols="1" aria-pressed="false" aria-label="Vista lista" onclick="KeepStoreView.setCols(1);">
                            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                                <path d="M4 6h16M4 12h16M4 18h16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                            </svg>
                        </button>
                    </div>

                    <div class="d-flex align-items-center gap-6">
                        <span class="body-text-3">Ordina:</span>
                        <asp:DropDownList ID="Drop_Ordinamento" runat="server" AutoPostBack="True" CssClass="form-select form-select-sm">
                        <asp:ListItem Value="varticolibase.Codice">Codice</asp:ListItem>
                        <asp:ListItem Value="varticolibase.Descrizione1">Descrizione</asp:ListItem>
                        <asp:ListItem Value="varticolibase.PrezzoAcquisto">Prezzo crescente</asp:ListItem>
                        <asp:ListItem Value="varticolibase.PrezzoAcquisto DESC">Prezzo decrescente</asp:ListItem>
                    </asp:DropDownList>
                    </div>

                    <div class="d-flex align-items-center gap-6">
                        <asp:CheckBox ID="CheckBox_Disponibile" runat="server" AutoPostBack="True" CssClass="tf-check" Text="Solo disponibili" />
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
        <div id="ksProducts" class="ks-products">
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

    
    <div id="ksSidebarBackdrop" class="ks-sidebar-backdrop" aria-hidden="true"></div>
</section>

</asp:Content>