<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="documenti.aspx.vb" Inherits="documenti" Debug="true" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Consultazione documenti
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
    <style type="text/css">
        .selezionato {
            font-size: 14px;
            color: Red;
            font-weight: bolder;
            margin: auto;
        }
        .nonSelezionato {
            font-size: 14px;
            font-weight: normal;
            margin: auto;
        }
        fieldset {
            padding-bottom: 0.625em;
            padding-left: 0.5em;
            padding-right: 0.5em;
            border: 2px groove;
        }
        legend {
            width: auto !important;
        }

        /* Spinner pagina */
        .ks-loading-panel {
            border: 1px solid #ddd;
            background-color: #fff;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
        }

        .ks-spinner-circle {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            border: 3px solid #ccc;
            border-top-color: #333;
            animation: ks-spin 0.8s linear infinite;
            margin: 0 auto 8px;
        }

        @keyframes ks-spin {
            from { transform: rotate(0deg); }
            to   { transform: rotate(360deg); }
        }
    </style>

    <script type="text/javascript">
        function ksHideSpinnerAndShowContent() {
            var spinner = document.getElementById('<%= pnlLoading.ClientID %>');
            var content = document.getElementById('<%= pnlContent.ClientID %>');

            if (spinner) {
                spinner.style.display = 'none';
            }
            if (content) {
                content.style.display = 'block';
                content.style.opacity = '1';
            }
        }

        // Prima apertura
        document.addEventListener('DOMContentLoaded', function () {
            ksHideSpinnerAndShowContent();
        });

        // Ritorno tramite tasto indietro / bfcache
        window.addEventListener('pageshow', function (event) {
            ksHideSpinnerAndShowContent();
        });

        function ksShowSpinnerOnSubmit() {
            var spinner = document.getElementById('<%= pnlLoading.ClientID %>');
            var content = document.getElementById('<%= pnlContent.ClientID %>');
            if (spinner) spinner.style.display = 'block';
            if (content) content.style.opacity = '0.5';
        }
    </script>
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">

    <!-- SPINNER DI PAGINA -->
    <asp:Panel ID="pnlLoading" runat="server" CssClass="ks-loading-panel">
        <div class="ks-spinner-circle"></div>
        <div>Caricamento documenti in corso...</div>
    </asp:Panel>

    <!-- CONTENUTO PRINCIPALE (inizialmente nascosto, lo mostra lo script) -->
    <asp:Panel ID="pnlContent" runat="server" Style="display:none;">

        <h1>Consultazione documenti</h1>

        <!-- BOTTONE TORNA A MY ACCOUNT -->
        <div style="margin-bottom:20px;">
            <asp:HyperLink 
                ID="hlBackMyAccount" 
                runat="server"
                NavigateUrl="myaccount.aspx"
                CssClass="tf-btn-icon type-2 style-white">
                &laquo; Torna alla pagina My Account
            </asp:HyperLink>
        </div>

        <% If Session("esito_invio_mail") = "1" Or Session("esito_invio_mail") = "0" Then %>
        <script type="text/javascript">
            JQ(document).ready(
                function () {
                    var popID = "popup"; //Get Popup Name
                    var popURL = "#?w=700"; //Get Popup href to define size

                    //Pull Query & Variables from href URL
                    var query = popURL.split('?');
                    var dim = query[1].split('&');
                    var popWidth = dim[0].split('=')[1]; //Gets the first query string value

                    //Fade in the Popup and add close button
                    JQ('#' + popID).fadeIn().css({ 'width': Number(popWidth) }).prepend('<a href="#" class="close"><img src="public/images/close_pop.png" class="btn_close" title="Close Window" alt="Close" /></a>');

                    //Define margin for center alignment (vertical + horizontal)
                    var popMargTop = (10 + 80) / 2;
                    var popMargLeft = (700 + 80) / 2;

                    //Apply Margin to Popup
                    JQ('#' + popID).css({
                        'margin-top': -popMargTop,
                        'margin-left': -popMargLeft
                    });

                    //Fade in Background
                    JQ('body').append('<div id="fade"></div>');
                    JQ('#fade').css({ 'filter': 'alpha(opacity=80)' }).fadeIn();

                    //Close Popups and Fade Layer
                    JQ('a.close, #fade').on('click', function () {
                        JQ('#fade , .popup_block').fadeOut(function () {
                            JQ('#fade, a.close').remove();
                        });
                        return false;
                    });
                }
            );
        </script>
        <% End If %>

        <% If Session("esito_invio_mail") = "1" Then
               Session("esito_invio_mail") = 0
        %>
        <div id="popup" class="popup_block" style="display:none; vertical-align:middle;">
            <div><img src="Public/Images/Ok.png" alt="" /></div><br />
            <div>Richiesta inoltrata. Riceverà il documento presso la sua casella email !!!</div>
        </div>
        <% End If %>

        <asp:SqlDataSource ID="sdsDocumenti" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
            SelectCommand="SELECT * FROM (`vdocumenti` LEFT JOIN `utenti` ON ((`vdocumenti`.`UtentiId` = `utenti`.`Id`)) LEFT JOIN ( SELECT id, Link_Tracking FROM `vettori`) AS vettori ON (`vdocumenti`.`VettoriId` = `vettori`.`id`) ) Left Join pagamentitipo on vdocumenti.pagamentiTipoId = pagamentiTipo.id WHERE ( (UtentiId = ?UtentiId ) AND (TipoDocumentiId = ?TipoDocumentiId ) ) ORDER BY vdocumenti.ID DESC">
            <SelectParameters>
                <asp:SessionParameter Name="UtentiId" SessionField="UtentiID" Type="int32" />
                <asp:QueryStringParameter QueryStringField="t" Name="TipoDocumentiId" Type="Int16" />
            </SelectParameters>
        </asp:SqlDataSource>

        <asp:SqlDataSource ID="sdsTipo" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
            SelectCommand="SELECT id, Descrizione FROM tipodocumenti WHERE Web=1 AND Abilitato=1 ORDER BY Ordinamento, Descrizione">
        </asp:SqlDataSource>
        
        <asp:SqlDataSource ID="sdsStatoOrdine" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
            SelectCommand="SELECT * FROM documentistati;">
        </asp:SqlDataSource>
        
        <asp:Repeater ID="rTipo" runat="server" DataSourceID="sdsTipo">
            <HeaderTemplate>
                <div style="padding:5px; padding-right:15px; margin-right:3px; display:block;">
                    Selezionare il tipo di documento
                </div>
                <div>
            </HeaderTemplate>
            <ItemTemplate>
                <div style="padding:5px; padding-right:15px; float:left; background-color:#ccc; margin-right:3px; margin-bottom:3px;">
                    <asp:LinkButton ID="lbTipoDocumento" runat="server" CssClass="disable" 
                        tipoDocumento='<%# Eval("id") %>' 
                        OnClick="tipoDocumentoClick" 
                        OnPreRender="preRenderClick">
                        <%# Eval("descrizione")%>
                    </asp:LinkButton>
                </div>
            </ItemTemplate>
            <FooterTemplate>
                </div>
                <br />
                <br />
                <br />
            </FooterTemplate>
        </asp:Repeater>

        <br /><br />
        <asp:Label runat="server" ID="lblInfo" Visible="false"></asp:Label>
        <br />

        <div class="row">
            <div class="col-12 col-md-6 mb-3">
                <asp:Panel ID="Panel1" runat="server" Font-Size="Small" GroupingText="Ricerca rapida">
                    <span style="font-weight:normal;">Visualizza</span>
                    <asp:DropDownList ID="filtroTempo" runat="server" OnSelectedIndexChanged="filtroDataRapido" AutoPostBack="true">
                        <asp:ListItem Value="-1" Selected="True">tutti i documenti</asp:ListItem>
                        <asp:ListItem Value="7">i documenti dell'ultima settimana</asp:ListItem>
                        <asp:ListItem Value="30">i documenti dell'ultimo mese</asp:ListItem>
                        <asp:ListItem Value="60">i documenti degli ultimi due mesi</asp:ListItem>
                        <asp:ListItem Value="90">i documenti degli ultimi tre mesi</asp:ListItem>
                    </asp:DropDownList>
                </asp:Panel>
            </div>
            <div class="col-12 col-md-6 mb-3">
                <asp:Panel ID="Panel2" runat="server" Font-Size="Small" GroupingText="Ricerca dettagliata" Style="width:100%" CssClass="float-md-right">
                    <div>
                        <div style="float:left; padding:5px; width:75px; text-align:right;">Filtra dal</div>
                        <div style="float:left;">
                            <asp:TextBox runat="server" ID="dataInizio" Width="150px"></asp:TextBox>
                            <asp:ImageButton runat="server" ID="ib_calendarInizio" ImageUrl="Public/Images/calendar_icon.gif" />
                        </div>
                        <div style="clear:both"></div>
                        <div style="float:left;padding:5px; width:75px; text-align:right;">al</div>
                        <div style="float:left;">
                            <asp:TextBox runat="server" ID="dataFine" Width="150px"></asp:TextBox>
                            <asp:ImageButton runat="server" ID="ImageButton1" ImageUrl="Public/Images/calendar_icon.gif" />
                        </div>
                        <div style="clear:both"></div>
                        <div style="padding-left:87px;">
                            <asp:Calendar ID="Calendar1" runat="server" Width="150px" Visible="false">
                                <SelectedDayStyle BackColor="#4E4E4E" />
                                <WeekendDayStyle BackColor="#C4C4C4" />
                            </asp:Calendar>
                            <asp:Calendar ID="Calendar2" runat="server" Width="150px" Visible="false">
                                <SelectedDayStyle BackColor="#4E4E4E" />
                                <WeekendDayStyle BackColor="#C4C4C4" />
                            </asp:Calendar>
                        </div>
                    </div>
                </asp:Panel>
            </div>
            
            <div class="col-12 doc-btn-filtra">
                <asp:Button ID="Button1" CssClass="btn btn-default" runat="server" Style="float: right;" 
                    Text="Filtra" OnClick="applicaFiltri" />
            </div>
        </div>
        
        <div style="clear:both;"></div>

        <div class="row my-3">
            <div class="col-12 col-md-6">
                <span style="color:Red; font-weight:bold;"><%= nDocTrovati %></span> documenti trovati
            </div>
            <div class="col-12 col-md-6 text-md-right">
                Filtra documenti per stato &nbsp;
                <asp:DropDownList ID="filtroStati" runat="server" AutoPostBack="True"
                    DataSourceID="sdsStatoOrdine" DataTextField="Descrizione1" DataValueField="id"
                    OnSelectedIndexChanged="applicaFiltri" OnDataBound="aggiungiStato">
                </asp:DropDownList>
            </div>
        </div>
        
        <asp:GridView ID="GridView1" runat="server" AllowPaging="True" AutoGenerateColumns="False"
            CellPadding="5" DataKeyNames="id" DataSourceID="sdsDocumenti" EmptyDataText="Nessun documento presente"
            Font-Size="8pt" GridLines="None" PageSize="20" Width="100%">
            <EmptyDataRowStyle Font-Bold="False" Height="100px" HorizontalAlign="Center" />
            <Columns>
                <asp:TemplateField HeaderText="Informazioni Documento" SortExpression="DataDocumento">
                    <EditItemTemplate></EditItemTemplate>
                    <ItemTemplate>
                        <div class="row">
                            <div class="col-12 col-md-3 col-lg-2 pb-2 my-auto d-md-block d-flex align-items-center doc-col-1">
                                <div>
                                    <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then %>
                                        <asp:HyperLink ID="HyperLink1" runat="server" ForeColor="#E12825" 
                                            NavigateUrl='<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>' 
                                            Text="Dettaglio Documento">
                                        </asp:HyperLink>
                                    <% Else %>
                                        <asp:HyperLink ID="HyperLink2" runat="server" ForeColor="#E12825" 
                                            NavigateUrl='<%# Eval("id", "documentidettaglio.aspx?id={0}") %>' 
                                            Text="Dettaglio Documento">
                                        </asp:HyperLink>
                                    <% End If %>
                                </div>
                                
                                <asp:ImageButton ID="imgStampaDoc" idDoc='<%# Eval("id")%>' runat="server" 
                                    ToolTip="Richiedi documento tramite posta elettronica" 
                                    ImageUrl="images/pdf2mail.png" OnClick="stampaClick" />
                                
                                <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then %>
                                    <a href="<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>" 
                                       style="display:<%# IIf(Eval("Pagato") = 1 Or (Eval("PagamentiTipoOnline") = 0), "", "none")%>; color:#E12825;">
                                        <img src="Public/Images/Pagato.png" alt="" />
                                    </a>
                                <% Else %>
                                    <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>" 
                                       style="display:<%# IIf((Eval("Pagato") = 1 And (Eval("PagamentiTipoOnline") > 0)) Or (Eval("CodiceAutorizzazione") <> ""), "", "none")%>; color:#E12825;">
                                        <img src="Public/Images/Pagato.png" alt="" />
                                    </a>
                                    <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>" 
                                       style="display:<%# MostraPagaOra(Eval("Pagato"), Eval("CodiceAutorizzazione"), Eval("StatiId"), Eval("PagamentiTipoOnline")) %>; color:#E12825;">
                                        <img src="Public/Images/Paga_Ora.png" alt="" />
                                    </a>
                                <% End If %>

                                <table style="margin-top:5px;">
                                    <tr>
                                        <td align="center">
                                            <a <%# SafeTrackingHref(Eval("Tracking")) %> style="text-decoration:none;">
                                                <img src='<%# IIf(Convert.ToString(Eval("Tracking")) = "", "Public/Vettori/tracking_no.jpg", "Public/Vettori/tracking.jpg") %>'
                                                     alt="" title="Clicca per visualizzare il tracking" />
                                            </a>
                                        </td>
                                    </tr>
                                </table>
                            </div>

                            <div class="col-12 col-md-9 col-lg-10">
                                <table width="100%" style="border-width:0px;">
                                    <tr>
                                        <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;"><strong>Numero</strong></td>
                                        <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;"><strong>Data</strong></td>
                                        <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;"><strong>Imponibile</strong></td>
                                        <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;"><strong>Totale</strong></td>
                                        <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;"><strong>Stato</strong></td>
                                    </tr>
                                    <tr>
                                        <td align="center" style="font-size:14px; background-color:#f0efef; border-style:solid; border-color:White; border-width:1px;">
                                            <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then %>
                                                <asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="idcoupon" runat="server"
                                                    NavigateUrl='<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>'
                                                    Text='<%# Eval("NDocumento") %>'
                                                    ToolTip='<%# "Visualizza Dettagli " & Eval("tipodocumentidescrizione") %>'>
                                                </asp:HyperLink>
                                            <% Else %>
                                                <asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="iddoc" runat="server"
                                                    NavigateUrl='<%# Eval("id", "documentidettaglio.aspx?id={0}") %>'
                                                    Text='<%# Eval("NDocumento") %>'
                                                    ToolTip='<%# "Visualizza Dettagli " & Eval("tipodocumentidescrizione") %>'>
                                                </asp:HyperLink>
                                            <% End If %>
                                        </td>
                                        <td align="center" style="font-size:12px; background-color:#f0efef;border-style:solid; border-color:White; border-width:1px;"><%# Eval("DataDocumento", "{0:d}") %></td>
                                        <td align="center" style="font-size:12px; background-color:#f0efef;border-style:solid; border-color:White; border-width:1px;"><%# Eval("TotImponibile", "{0:C}") %></td>
                                        <td align="center" style="font-size:12px; background-color:#f0efef;border-style:solid; border-color:White; border-width:1px;"><%# Eval("TotaleDocumento", "{0:C}") %></td>
                                        <td align="center" style="font-size:12px; background-color:#f0efef;border-style:solid; border-color:White; border-width:1px;"><%# Eval("StatiDescrizione1") %></td>
                                    </tr>
                                </table>

                                <div style="border-style:solid; border-width:1px; border-color:#ccc; width:100%;">
                                    <table width="100%" style="margin-top:10px;border-width:0px;">
                                        <tr style="border-style:solid; border-color:White; border-width:1px;">
                                            <td valign="top" align="left" style="background-color:#ccc"><strong>Destinatario</strong></td>
                                            <td style="background-color:#f0efef"><%# Eval("RagioneSociale") %> <%# Eval("CognomeNome") %> - <%# Eval("SedeLegale") %></td>
                                        </tr>
                                        <tr style="border-style:solid; border-color:White; border-width:1px;">
                                            <td valign="top" align="left" style="background-color:#ccc;width: 100px;"><strong>Altra destinazione </strong></td>
                                            <td style="background-color:#f0efef"><%# Eval("DestinazioneMerci") %></td>
                                        </tr>
                                        <tr style="border-style:solid; border-color:White; border-width:1px;">
                                            <td valign="top" align="left" style="background-color:#ccc"><strong>Pagamento</strong></td>
                                            <td style="background-color:#f0efef"><%# Eval("PagamentiTipoDescrizione") %></td>
                                        </tr>
                                        <tr style="border-style:solid; border-color:White; border-width:1px;">
                                            <td valign="top" align="left" style="background-color:#ccc"><strong>Spedizione</strong></td>
                                            <td style="background-color:#f0efef"><%# Eval("VettoriDescrizione") %></td>
                                        </tr>
                                        <tr style="border-style:solid; border-color:White; border-width:1px;">
                                            <td valign="top" align="left" style="background-color:#ccc"><strong>Tracking</strong></td>
                                            <td style="background-color:#f0efef">
                                                <%# separa_tracking(Eval("Tracking"), Eval("Link_Tracking")) %>
                                            </td>
                                        </tr>
                                        <tr style="border-style:solid; border-color:White; border-width:1px;<%# testNote(Eval("Note")) %>">
                                            <td valign="top" align="left" style="background-color:#ccc"><strong>Note Corriere</strong></td>
                                            <td style="background-color:#f0efef"><%# Eval("Note") %></td>
                                        </tr>
                                        <tr style="border-style:solid; border-color:White; border-width:1px;">
                                            <td valign="top" align="left" style="background-color:#ccc"><strong>Note</strong></td>
                                            <td style="background-color:#f0efef"><%# Eval("NoteEsterne") %></td>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </ItemTemplate>
                    <ItemStyle Font-Size="8pt" />
                </asp:TemplateField>
                
                <asp:BoundField DataField="TotIva" HeaderText="Iva" SortExpression="TotIva" DataFormatString="{0:C}" Visible="False">
                    <HeaderStyle HorizontalAlign="Right" />
                    <ItemStyle HorizontalAlign="Right" />
                </asp:BoundField>
                
                <asp:BoundField DataField="NDocumento" HeaderText="NDocumento" ReadOnly="True" Visible="False" />
                <asp:BoundField DataField="id" HeaderText="id" ReadOnly="True" SortExpression="id" Visible="False" />
            </Columns>
            <PagerStyle CssClass="nav" Font-Bold="True" />
            <HeaderStyle Font-Bold="False" Font-Size="8pt" ForeColor="#2050AF" HorizontalAlign="Left" />
            <EditRowStyle Font-Bold="False" />
            <AlternatingRowStyle BackColor="WhiteSmoke" BorderStyle="None" />
            <RowStyle Height="25px" />
        </asp:GridView>

    </asp:Panel> <!-- fine pnlContent -->

    <script runat="server">
        Function testNote(ByVal note As Object) As String
            Try
                Return CStr(IIf(note = "", "display:none;", ""))
            Catch
                Return "display:none;"
            End Try
        End Function

        ' Sanifica l’href del tracking (no javascript:, no valori vuoti, no DBNull)
        Function SafeTrackingHref(ByVal trackingObj As Object) As String
            Try
                If trackingObj Is Nothing OrElse IsDBNull(trackingObj) Then
                    Return ""
                End If

                Dim url As String = trackingObj.ToString().Trim()
                If String.IsNullOrEmpty(url) Then
                    Return ""
                End If

                Dim lower As String = url.ToLowerInvariant()
                If Not (lower.StartsWith("http://") OrElse lower.StartsWith("https://")) Then
                    ' Blocca link non sicuri (javascript:, data:, ecc.)
                    Return ""
                End If

                Dim safeUrl As String = System.Web.HttpUtility.HtmlAttributeEncode(url)
                Return "href=""" & safeUrl & """"
            Catch
                Return ""
            End Try
        End Function

        ' Gestisce la logica del tracking multiplo usando il template Link_Tracking
        Function separa_tracking(ByVal trackingObj As Object, ByVal linkTrackingObj As Object) As String
            Dim tracking As String = ""
            Dim link_tracking As String = ""

            If trackingObj IsNot Nothing AndAlso Not IsDBNull(trackingObj) Then
                tracking = trackingObj.ToString()
            End If

            If linkTrackingObj IsNot Nothing AndAlso Not IsDBNull(linkTrackingObj) Then
                link_tracking = linkTrackingObj.ToString()
            End If

            If String.IsNullOrWhiteSpace(tracking) OrElse String.IsNullOrWhiteSpace(link_tracking) Then
                Return ""
            End If

            Dim ltLower As String = link_tracking.ToLowerInvariant()
            If Not (ltLower.StartsWith("http://") OrElse ltLower.StartsWith("https://")) Then
                ' Template di tracking non sicuro: non mostro nulla
                Return ""
            End If

            Dim temp As String() = tracking.Split(";"c)
            Dim sb As New System.Text.StringBuilder()

            For Each codiceRaw As String In temp
                Dim codice As String = codiceRaw.Trim()
                If codice <> "" Then
                    Dim safeCode As String = System.Web.HttpUtility.HtmlEncode(codice)
                    Dim href As String = link_tracking.Replace("#ID#", codice)
                    Dim safeHref As String = System.Web.HttpUtility.HtmlAttributeEncode(href)

                    sb.Append("<img src=""Public/Images/interrogativo.png"" alt="""" title=""Clicca sul Numero Tracking"">")
                    sb.Append("<a href=""")
                    sb.Append(safeHref)
                    sb.Append(""" target=""_blank"">")
                    sb.Append(safeCode)
                    sb.Append("</a>; ")
                End If
            Next

            Return sb.ToString()
        End Function
    </script>

</asp:Content>
