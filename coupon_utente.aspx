<%@ Page Language="VB" MasterPageFile="~/Coupon.master" AutoEventWireup="false" CodeFile="coupon_utente.aspx.vb" Inherits="coupon_utente" title="Pagina senza titolo" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
    <asp:GridView ID="GridView1" runat="server" AllowPaging="True" AutoGenerateColumns="False"
        CellPadding="5" DataKeyNames="id" DataSourceID="sdsDocumenti" EmptyDataText="Nessun documento presente"
        Font-Size="8pt" GridLines="None" PageSize="20" Width="100%">
        <EmptyDataRowStyle Font-Bold="False" Height="100px" HorizontalAlign="Center" />
        <Columns>

            <asp:TemplateField HeaderText="" SortExpression="NDocumento">
                <ItemTemplate>
                <table width="100%" >
                    <tr>
                        <td align="center" >
                        <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then%>
                            <asp:HyperLink ID="HyperLink1" runat="server" ForeColor="#E12825" NavigateUrl='<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>' Text="Dettagli Coupon"></asp:HyperLink>
                        <%Else%>
                            <asp:HyperLink ID="HyperLink2" runat="server" ForeColor="#E12825" NavigateUrl='<%# Eval("id", "documentidettaglio.aspx?id={0}") %>' Text="Dettaglio Documento"></asp:HyperLink>
                        <%End If%>
                        </td>
                    </tr>
                    <tr >
                        <td align="center" >
                            <br />
                            <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then%>
                                <a href="<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>" style="display:<%#IIf(Eval("Pagato") = 1, "", "none")%>; color:#E12825;"><img src="Public/Images/Pagato.png" alt="" /></a>
                            <%Else%>
                                <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>" style="display:<%#IIf(Eval("Pagato") = 1, "", "none")%>; color:#E12825;"><img src="Public/Images/Pagato.png" alt="" /></a>
                                <a href="<%# Eval("id", "documentidettaglio.aspx?id={0}") %>" style="display:<%#IIf(Eval("Pagato") = 1, "none", "")%>; color:#E12825;"><img src="Public/Images/Paga_Ora.png" alt="" /></a>
                            <%End If%>
                        </td>
                    </tr>
                </table>
                </ItemTemplate>
                <HeaderStyle HorizontalAlign="Right" />
                <ItemStyle Font-Bold="True" ForeColor="Red" HorizontalAlign="Right" />
            </asp:TemplateField>
            <asp:TemplateField HeaderText="Informazioni Coupon" SortExpression="DataDocumento">
                <EditItemTemplate></EditItemTemplate>
                <ItemTemplate>
                <div style="border-style:solid; border-width:1px; border-color:#ccc; width:100%;" >
                    <table width="100%" style="border-width:0px;" >
                        <tr >
                            <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;" ><strong>Numero</strong></td>
                            <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;" ><strong>Data</strong></td>
                            <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;"><strong>Imponibile</strong></td>
                            <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;"><strong>Totale</strong></td>
                            <td align="center" style="background-color:#ccc;font-size:14px; border-style:solid; border-color:White; border-width:1px;" ><strong>Stato</strong></td>
                        </tr>
                        <tr >
                            <td align="center" style="font-size:14px; background-color:#f0efef; border-style:solid; border-color:White; border-width:1px;" >
                            <% If Request.QueryString("t") = Session("IdDocumentoCoupon") Then%>
                                <asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="idcoupon" runat="server" NavigateUrl='<%# "coupon_esito_acquisto.aspx?id=" & Eval("Coupon_idCoupon") & "&cod=" & Eval("Coupon_CodControllo") %>' Text='<%# Eval("NDocumento") %>' ToolTip='<%# "Visualizza Dettagli "& Eval("tipodocumentidescrizione") %>'></asp:HyperLink></td>
                            <%Else%>
                                <asp:HyperLink ForeColor="#E12825" Font-Bold="true" ID="iddoc" runat="server" NavigateUrl='<%# Eval("id", "documentidettaglio.aspx?id={0}") %>' Text='<%# Eval("NDocumento") %>' ToolTip='<%# "Visualizza Dettagli "& Eval("tipodocumentidescrizione") %>'></asp:HyperLink></td>
                            <%End If%>
                            
                            <td align="center" style="font-size:12px; background-color:#f0efef;border-style:solid; border-color:White; border-width:1px;" ><%# Eval("DataDocumento", "{0:d}") %></td>
                            <td align="center" style="font-size:12px; background-color:#f0efef;border-style:solid; border-color:White; border-width:1px;" ><%# Eval("TotImponibile", "{0:C}") %></td>
                            <td align="center" style="font-size:12px; background-color:#f0efef;border-style:solid; border-color:White; border-width:1px;" ><%# Eval("TotaleDocumento", "{0:C}") %></td>
                            <td align="center" style="font-size:12px; background-color:#f0efef;border-style:solid; border-color:White; border-width:1px;" ><%# Eval("StatiDescrizione1") %></td>
                        </tr>
                    </table>
                    
                    <table width="100%" style="margin-top:10px;border-width:0px;" >
                    <tr style=" border-style:solid; border-color:White; border-width:1px;" >
                        <td valign="top" align="left" style="background-color:#ccc"><strong>Destinatario</strong></td>
                        <td style="background-color:#f0efef" ><%# Eval("RagioneSociale") %> <%# Eval("CognomeNome") %> - <%# Eval("SedeLegale") %></td>
                    </tr>
                    <tr style=" border-style:solid; border-color:White; border-width:1px;" >
                        <td valign="top" align="left" style="background-color:#ccc;width: 100px;"><strong>Altra destinazione </strong></td>
                        <td style="background-color:#f0efef" ><%# Eval("DestinazioneMerci") %></td>
                    </tr>
					<tr style=" border-style:solid; border-color:White; border-width:1px;" >
                        <td valign="top" align="left" style="background-color:#ccc"><strong>Pagamento</strong></td>
                        <td style="background-color:#f0efef" ><%# Eval("PagamentiTipoDescrizione") %></td>
                    </tr>
                    <tr style=" border-style:solid; border-color:White; border-width:1px;">
                        <td  valign="top" align="left" style="background-color:#ccc" ><strong>Spedizione</strong></td>
                        <td style="background-color:#f0efef" ><%# Eval("VettoriDescrizione") %></td>
                    </tr>
                    <tr style=" border-style:solid; border-color:White; border-width:1px;">
                        <td  valign="top" align="left" style="background-color:#ccc" ><strong>Tracking</strong></td>
                        <td style="background-color:#f0efef" >
                            <script runat="server">
                                Function separa_tracking(ByVal tracking As String, ByVal link_tracking As String) As String
                                    Dim temp As String() = tracking.Split(";")
                                    Dim risultato As String = ""
                                    Dim i As Integer = 0
                                    
                                    For i = 0 To temp.Length - 1
                                        If temp(i) <> "" Then
                                            risultato = risultato & "<img src=""Public/Images/interrogativo.png"" alt="""" title=""Clicca sul Numero Tracking"">" & "<a href=""" & link_tracking.Replace("#ID#", temp(i)) & """ target=""_blank"">" & temp(i) & "</a>; "
                                        End If
                                    Next
                                    
                                    Return risultato
                                End Function
                            </script>
                            <%# separa_tracking(Eval("Tracking").ToString(), Eval("Link_Tracking").ToString())%>
                        </td>
                    </tr>
                    <script runat="server">
                        Function testNote(ByVal note As Object) As String
                            Try
                                Return CStr(IIf(note = "", "display:none;", ""))
                            Catch
                                Return "display:none;"
                            End Try
                        End Function
                    </script>
                    <tr style="border-style:solid; border-color:White; border-width:1px;<%# testNote(Eval("Note")) %>" >
                        <td valign="top" align="left" style="background-color:#ccc"><strong>Note Corriere</strong></td>
                        <td style="background-color:#f0efef" ><%# Eval("Note") %> </td>
                    </tr>
                    <tr style=" border-style:solid; border-color:White; border-width:1px;">
                        <td valign="top" align="left" style="background-color:#ccc"><strong>Note</strong></td>
                        <td style="background-color:#f0efef"  ><%# Eval("NoteEsterne") %></td>
                    </tr>
                    </table>
                </div>    
                </ItemTemplate>
                <ItemStyle Font-Size="7pt" />
            </asp:TemplateField>
            
            <asp:BoundField DataField="TotIva" HeaderText="Iva" SortExpression="TotIva" DataFormatString="{0:C}" Visible="False" >
                <HeaderStyle HorizontalAlign="Right" />
                <ItemStyle HorizontalAlign="Right" />
            </asp:BoundField>
            
            <asp:BoundField DataField="NDocumento" HeaderText="NDocumento" ReadOnly="True" Visible="False" />
            <asp:BoundField DataField="id" HeaderText="id" ReadOnly="True" SortExpression="id"
                Visible="False" />
        </Columns>
        <PagerStyle CssClass="nav" Font-Bold="True" />
        <HeaderStyle Font-Bold="False" Font-Size="8pt" ForeColor="#2050AF" HorizontalAlign="Left" />
        <EditRowStyle Font-Bold="False" />
        <AlternatingRowStyle BackColor="WhiteSmoke" BorderStyle="None" />
        <RowStyle Height="25px" />
    </asp:GridView>
    
    <asp:SqlDataSource ID="sdsDocumenti" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM (`vdocumenti` LEFT JOIN `utenti` ON ((`vdocumenti`.`UtentiId` = `utenti`.`Id`)) LEFT JOIN ( SELECT id, Link_Tracking FROM `vettori`) AS vettori ON (`vdocumenti`.`VettoriId` = `vettori`.`id`) ) WHERE ( (UtentiId = ?UtentiId ) AND (TipoDocumentiId = ?TipoDocumentiId) AND (Pagato=1)) ORDER BY vdocumenti.ID DESC">
        <SelectParameters>
            <asp:SessionParameter Name="UtentiId" SessionField="UtentiID" Type="int32" />
            <asp:QueryStringParameter QueryStringField="t" Name="TipoDocumentiId" Type="Int16" />
        </SelectParameters>
    </asp:SqlDataSource>
    <asp:SqlDataSource ID="sdsTipo" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT id, Descrizione FROM tipodocumenti WHERE Web=1 AND Abilitato=1 ORDER BY Ordinamento, Descrizione"></asp:SqlDataSource>
    
    <asp:SqlDataSource ID="sdsStatoOrdine" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" SelectCommand="SELECT * FROM documentistati;">
    </asp:SqlDataSource>
</asp:Content>

