<%@ Page Title="" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articoli.aspx.vb" Inherits="articoli" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    <%: Page.Title %>
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        /* STEP 3 (ARTICOLI) - allineamento layout al template (sidebar + contenuti)
           Nota: solo CSS minimale per rendere i filtri leggibili e coerenti. */
        .ks-filter-card{border:1px solid rgba(0,0,0,.08);border-radius:12px;padding:14px;margin-bottom:14px;background:#fff;}
        .ks-filter-card h5{font-size:15px;margin:0 0 10px 0;}
        .ks-filter-list a{display:block;padding:6px 8px;border-radius:8px;text-decoration:none;}
        .ks-filter-list a:hover{background:rgba(0,0,0,.04);}
        .ks-filter-list a.active{background:rgba(0,0,0,.06);font-weight:600;}
        .ks-filter-card label{margin:0;}
        .ks-filter-card .form-check{margin-bottom:6px;}
        .ks-filter-card .badge{font-size:12px;}
    </style>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="cph" runat="server">
    <!-- DataSources (in pagina per semplicità di manutenzione) -->
<asp:SqlDataSource ID="sdsCategorieSettore" runat="server"
    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
    SelectCommand="SELECT id, descrizione FROM categorie WHERE abilitato = ?Abilitato AND settoriid = ?SettoriId ORDER BY descrizione;">
    <SelectParameters>
        <asp:Parameter Name="Abilitato" Type="Int32" DefaultValue="1" />
        <asp:SessionParameter Name="SettoriId" SessionField="st" Type="Int32" DefaultValue="0" />
    </SelectParameters>
</asp:SqlDataSource>

<asp:SqlDataSource ID="sdsCategorie" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione, SettoriCodice, SettoriDescrizone FROM vCategorieSettori WHERE ((Abilitato = ?Abilitato) AND (ID = ?ID)) ORDER BY Ordinamento, Descrizione" EnableViewState="False">
        <SelectParameters>
            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
            <asp:SessionParameter Name="ID" SessionField="ct" Type="Int32" />
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
<asp:SqlDataSource ID="sdsArticoli" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, Codice, Descrizione1, PrezzoAcquisto, Img1, DescrizioneLunga FROM varticolibase ORDER BY Codice, Descrizione1" EnableViewState="False">
    </asp:SqlDataSource>

    <div class="container mt-3">
        <div class="row">
            <aside class="col-lg-3 mb-4">
                <div class="ks-filter-card">
                    <h5>Categorie</h5>
                    <asp:DataList ID="DataListCategorie" runat="server" DataSourceID="sdsCategorieSettore" RepeatLayout="Flow" CssClass="ks-filter-list">
                        <ItemTemplate>
                            <a href="<%# BuildCategoriaUrl(Convert.ToInt32(Eval("id"))) %>" class="<%# If(IsCategoriaCorrente(Convert.ToInt32(Eval("id"))), "active", "") %>"><%# Eval("descrizione") %></a>
                        </ItemTemplate>
                    </asp:DataList>
                </div>

                <div class="ks-filter-card">
                    <h5>Tipologie</h5>
<asp:DataList ID="DataList2" runat="server" DataSourceID="sdsGruppo" RepeatLayout="Flow" Font-Size="8pt">
                    <ItemTemplate>
                        <%# If(filterIdsContains("gr",Eval("GruppiId").ToString()),"<b>","") %>
                        <asp:CheckBox ID='CheckBoxGr' checked='<%# If(filterIdsContains("gr",Eval("GruppiId").ToString()),True,False) %>' runat='server' AutoPostBack='True' OnCheckedChanged ='CheckBoxGr_CheckedChanged' filterId='<%# Eval("GruppiId") %>' CssClass='filterCheckbox' Text='<%# getCorrectLengthDescription(Eval("Descrizione")) & " " & "<font color=#E12825>("& Eval("Numero") &")</font>"  %>' Width='150px' ToolTip='Applica/Rimuovi Filtro'/></asp:CheckBox> 
                        <%# If(filterIdsContains("gr",Eval("GruppiId").ToString()),"</b>","") %>
                    </ItemTemplate>
                    <HeaderTemplate>
                        <div style=" font-weight:bold; font-size:10pt; background-position: left top; color:White; background-image:url('Public/Images/back.jpg'); background-repeat:repeat-x; text-align:center;">
                            GRUPPO
                        </div>
                        <asp:Label CssClass='filterRemoveAll' ID="Label2" runat="server" Text=": :" Font-Bold="true" ForeColor="#E12825"></asp:Label>&nbsp;&nbsp;
                        <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl='<%# Me.Request.Url.toString & "&rimuovi=gr" %>' Text="Rimuovi tutti"></asp:HyperLink>
                    </HeaderTemplate>
                    <SelectedItemStyle Font-Bold="True" />
                </asp:DataList>
                </div>

                <div class="ks-filter-card">
                    <h5>Gruppi</h5>
<asp:DataList ID="DataList3" runat="server" DataSourceID="sdsSottogruppo" RepeatLayout="Flow" Font-Size="8pt">
                    <ItemTemplate>
                        <%# If(filterIdsContains("sg",Eval("SottogruppiId").ToString()),"<b>","") %>
                        <asp:CheckBox ID='CheckBoxSg' checked='<%# If(filterIdsContains("sg",Eval("SottogruppiId").ToString()),True,False) %>' runat='server' AutoPostBack='True' OnCheckedChanged ='CheckBoxSg_CheckedChanged' filterId='<%# Eval("SottogruppiId") %>' CssClass='filterCheckbox' Text='<%# getCorrectLengthDescription(Eval("Descrizione")) & " " & "<font color=#E12825>("& Eval("Numero") &")</font>"  %>' Width='150px' ToolTip='Applica/Rimuovi Filtro'/></asp:CheckBox> 
                        <%# If(filterIdsContains("sg",Eval("SottogruppiId").ToString()),"</b>","") %>
                    </ItemTemplate>
                    <HeaderTemplate>
                        <div style=" font-weight:bold; font-size:10pt; background-position: left top; color:White; background-image:url('Public/Images/back.jpg'); text-align:center;">
                            SOTTOGRUPPI
                        </div>
                        <asp:Label CssClass='filterRemoveAll' ID="Label2" runat="server" Text=": :" Font-Bold="true" ForeColor="#E12825"></asp:Label>&nbsp;&nbsp;
                        <asp:HyperLink ID="hlTutti" runat="server" NavigateUrl='<%# Me.Request.Url.toString & "&rimuovi=sg" %>' Text="Rimuovi tutti"></asp:HyperLink>
                    </HeaderTemplate>
                    <SelectedItemStyle Font-Bold="True" />
                </asp:DataList>
                </div>

                <div class="ks-filter-card">
                    <h5>Sottogruppi</h5>
<asp:DataList ID="DataList4" runat="server" DataSourceID="sdsMarche" RepeatLayout="Flow" Font-Size="8pt">
                    <SelectedItemStyle Font-Bold="True" />
                    <HeaderTemplate>
                        <div style=" font-weight:bold; font-size:10pt; background-position: left top; color:White; background-image:url('Public/Images/back.jpg'); background-repeat:repeat-x; text-align:center;">
                            MARCHE
                        </div>
                        <asp:Label ID="Label2" runat="server" Text=": :" Font-Bold="true" ForeColor="#E12825"></asp:Label>&nbsp;&nbsp;&nbsp;
                        <asp:HyperLink CssClass='filterRemoveAll' ID="hlTutti" runat="server" NavigateUrl='<%# Me.Request.Url.toString & "&rimuovi=mr" %>' Text="Rimuovi tutti"></asp:HyperLink>
                    </HeaderTemplate>
                    <ItemTemplate>
                        <%# If(filterIdsContains("mr",Eval("marcheid").ToString()),"<b>","") %>
                        <asp:CheckBox ID='CheckBoxMr' checked='<%# If(filterIdsContains("mr",Eval("marcheid").ToString()),True,False) %>' runat='server' AutoPostBack='True' OnCheckedChanged ='CheckBoxMr_CheckedChanged' filterId='<%# Eval("marcheid") %>' CssClass='filterCheckbox' Text='<%# getCorrectLengthDescription(Eval("Descrizione")) & " " & "<font color=#E12825>("& Eval("Numero") &")</font>"  %>' Width='150px' ToolTip='Applica/Rimuovi Filtro'/></asp:CheckBox> 
                        <%# If(filterIdsContains("mr",Eval("marcheid").ToString()),"</b>","") %>
                    </ItemTemplate>
                </asp:DataList>
                </div>

                <div class="ks-filter-card">
                    <h5>Marche</h5>
<asp:DataList ID="DataList1" runat="server" DataSourceID="sdsTipologie" RepeatLayout="Flow" Font-Size="8pt">
                    <ItemTemplate>
                        <%# If(filterIdsContains("tp",Eval("TipologieId").ToString()),"<b>","") %>
                        <asp:CheckBox ID='CheckBoxTp' checked='<%# If(filterIdsContains("tp",Eval("TipologieId").ToString()),True,False) %>' runat='server' AutoPostBack='True' OnCheckedChanged ='CheckBoxTp_CheckedChanged' filterId='<%# Eval("TipologieId") %>' CssClass='filterCheckbox' Text='<%# getCorrectLengthDescription(Eval("Descrizione")) & " " & "<font color=#E12825>("& Eval("Numero") &")</font>"  %>' Width='150px' ToolTip='Applica/Rimuovi Filtro'/></asp:CheckBox> 
                        <%# If(filterIdsContains("tp",Eval("TipologieId").ToString()),"</b>","") %>
                    </ItemTemplate>
                    <HeaderTemplate>
                        <div style=" font-weight:bold; font-size:10pt; background-position: left top; color:White; background-image:url('Public/Images/back.jpg'); background-repeat:repeat-x; text-align:center;">
                            TIPOLOGIE
                        </div>
                        <asp:Label ID="Label2" runat="server" Text=": :" Font-Bold="true" ForeColor="#E12825"></asp:Label>&nbsp;&nbsp;&nbsp;
                        <asp:HyperLink CssClass='filterRemoveAll' ID="hlTutti" runat="server" NavigateUrl='<%# Me.Request.Url.toString & "&rimuovi=tp" %>' Text="Rimuovi tutti"></asp:HyperLink>
                    </HeaderTemplate>
                    <SelectedItemStyle Font-Bold="True" />
                </asp:DataList>
                </div>
            </aside>

            <div class="col-lg-9">
                <!-- Titolo categoria corrente (se presente) -->
<asp:FormView ID="FormView1" runat="server" DataSourceID="sdsCategorie" EnableViewState="False">
                <ItemTemplate>
                    <asp:Label ID="lblSettore" runat="server" Text='<%# ucase(Eval("SettoriDescrizone")) %>' EnableViewState="False"></asp:Label>
                    »
                    <asp:Label ID="lblCategoria" runat="server" Text='<%# Eval("Descrizione") %>' EnableViewState="False"></asp:Label>
                </ItemTemplate>
            </asp:FormView>

                <div class="d-flex flex-wrap justify-content-between align-items-end mt-3 mb-3">
                    <div>
                        <h5 class="mb-1"><asp:Label ID="lblTrovati" runat="server" Text=""></asp:Label></h5>
                        <small><asp:Label ID="lblPrezzi" runat="server" Text=""></asp:Label></small>
                    </div>
                    <div class="d-flex flex-wrap gap-2 align-items-center">
                        <div class="form-check">
                            <asp:CheckBox ID="CheckBox_Disponibile" runat="server" Text="Solo disponibili" AutoPostBack="true" CssClass="form-check-input" />
                        </div>
                        <asp:DropDownList ID="Drop_Ordinamento" runat="server" AutoPostBack="true" CssClass="form-select" Width="220px">
                            <asp:ListItem Value="" Text="Ordina per..." />
                            <asp:ListItem Value="prezzo_asc" Text="Prezzo (crescente)" />
                            <asp:ListItem Value="prezzo_desc" Text="Prezzo (decrescente)" />
                            <asp:ListItem Value="nome_asc" Text="Nome (A-Z)" />
                            <asp:ListItem Value="nome_desc" Text="Nome (Z-A)" />
                        </asp:DropDownList>
                    </div>
                </div>
            </div>
        </div>
    </div>




</asp:Content>
