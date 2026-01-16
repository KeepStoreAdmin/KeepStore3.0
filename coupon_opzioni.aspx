<%@ Page Language="VB" MasterPageFile="~/Coupon.master" AutoEventWireup="false" CodeFile="coupon_opzioni.aspx.vb" Inherits="coupon_opzioni" title="Pagina senza titolo" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
    <div style="width:100%;">
        <script runat="server">
            Function controllo_presenza_opzione(ByVal opzione As Integer) As String
                If opzione > 0 Then
                    Return ""
                Else
                    Return "none"
                End If
            End Function
        </script> 

        <asp:DataList ID="Coupon_Opzioni" runat="server" 
            DataSourceID="SqlData_CouponInserzioni" Width="99.9%" ShowFooter="False" 
            ShowHeader="False" >
            <ItemTemplate>
                <table>
                    <tr>
						<div class="row">
							<div class="col-12 col-md-6">
								<div style="width:100%; float:left; height:auto; overflow:auto; border-width:1px; border-color:Black; border-style:solid;">
									<!-- Header -->
									<div style="width:100%; height:40%; overflow:hidden;">
										<a href="coupon_dettagli.aspx?id=<%= Request.QueryString("id") %>"><img style="width:100%;" src="public/Coupon/img_coupon/<%#Eval("Img")%>" alt="" /></a>
									</div>
									<div style="width:100%; background-color:#DFDFDF; height:60%; padding-top:10px; padding-bottom:10px; text-align:right;">
										<div style="font-size:10pt; text-align:left; padding-left:10px;">
											<b>Coupon</b><br />
											<%#Left(Eval("Titolo").ToString, 100) & " ..."%>
										</div>
									</div>
								</div>
							</div>
							<div class="col-12 col-md-6">
								<div style="width:100%; float:left; color:Black; text-align:center;">                    
									<div style="width:100%; border-style:dashed; border-width:1px; border-color:Black; text-align:left;">
										<table style=" width:100%;">
											<tr>
												<td colspan="2" style="background-color:#DFDFDF; height:50px;">
													<b style="font-size:11pt;">Coupon Standard</b>
													<!-- Prezzo -->
													<div style="float:right; text-align:right; font-size:8pt; font-family:Arial; color:White; overflow:auto; background-repeat:no-repeat; background-color:#c01f1f; background-image:url('public/Coupon/Struttura/price.png'); width:210px; padding-right:5px; padding-bottom:5px;">
														<span style=" font-size:330%; color:White; font-weight:bold; clear:both; float:right; font-family:Arial Black; overflow:auto;">€ <%#String.Format("{0:n}", Eval("Prezzo"))%></span>
													   
														<div style="font-size:8pt; text-decoration:none; clear:both;">invece di <testo style="font-size:12pt; text-decoration:line-through;">€ <%#String.Format("{0:n}", Eval("PrezzoDiListino"))%></testo></div>          
													</div>
													<!-- Fine Prezzo -->
												</td>
											</tr>
											<tr>
												<td style="width:50%; text-align:left; vertical-align:middle;">
													<i style="font-size:10pt;">Coupon Standard</i>
												</td>
												<td style="width:50%; text-align:right; vertical-align:middle;">
													Qnt.
													<asp:DropDownList ID="DB_Quantità_standard" runat="server" Width="180px" style="font-size:12pt; font-weight:bold;">
													</asp:DropDownList><br />
													<asp:ImageButton ID="img_standard" runat="server" prz='<%#String.Format("{0:n}", Eval("Prezzo"))%>'  qnt="1" qnt_min='<%# Eval("Min_Ordinabile")%>' qnt_max='<%# Eval("Max_Ordinabile")%>'
														title='<%#Left(Eval("Titolo"),100) & " ..."%>' ImageUrl="public/Coupon/Struttura/acquista.png" onclick="img_standard_Click" />
												</td>
											</tr>
										</table>
									</div>
									
									<br />
									
									<div style="width:100%; border-style:dashed; border-width:1px; border-color:Black; text-align:left; display:<%#controllo_presenza_opzione(Eval("opzione1_qnt_min"))%>;">
										<table style=" width:100%;">
											<tr>
												<td colspan="2" style="background-color:#DFDFDF; height:50px;">
													<b style="font-size:12pt;">OPZIONE 1</b>
													<!-- Prezzo -->
													<div style="float:right; text-align:right; font-size:8pt; font-family:Arial; color:White; overflow:auto; background-repeat:no-repeat; background-color:#c01f1f; background-image:url('public/Coupon/Struttura/price.png'); width:210px; padding-right:5px; padding-bottom:5px;">
														<span style=" font-size:330%; color:White; font-weight:bold; clear:both; float:right; font-family:Arial Black; overflow:auto;">€ <%#String.Format("{0:n}", Eval("opzione1_prezzo"))%></span>
													   
														<div style="font-size:8pt; text-decoration:none; clear:both;">invece di <testo style="font-size:12pt; text-decoration:line-through;">€ <%#String.Format("{0:n}", Eval("opzione1_prezzodilistino"))%></testo></div>          
													</div>
													<!-- Fine Prezzo -->
												</td>
											</tr>
											<tr>
												<td style="width:50%; text-align:left;">
													<i style="font-size:10pt;"><%#Eval("opzione1_descrizione").ToString.Replace(vbCrLf, "<br/>")%></i>
												</td>
												<td style="width:50%; text-align:right;">
													Qnt.
													<asp:DropDownList ID="DB_Quantità_opzione1" runat="server" Width="180px" style="font-size:12pt; font-weight:bold;">
													</asp:DropDownList><br />
													<asp:ImageButton ID="img_opzione1" runat="server" 
														ImageUrl="public/Coupon/Struttura/acquista.png" 
														prz='<%#String.Format("{0:n}", Eval("opzione1_prezzo"))%>' qnt_min='<%# Eval("opzione1_qnt_min")%>' qnt_max='<%# Eval("opzione1_qnt_max")%>'
														qnt='<%# Eval("opzione1_qnt") %>' onclick="img_opzione1_Click" 
														title='<%#Eval("opzione1_descrizione") & " - " & Left(Eval("Titolo"),100) & " ..."%>'/>
												</td>
											</tr>
										</table>
									</div>
									
									<br />
									
									<div style="width:100%; border-style:dashed; border-width:1px; border-color:Black; text-align:left; display:<%#controllo_presenza_opzione(Eval("opzione2_qnt_min"))%>;">
										<table style=" width:100%;">
											<tr>
												<td colspan="2" style="background-color:#DFDFDF; height:50px;">
													<b style="font-size:12pt;">OPZIONE 2</b>
													<!-- Prezzo -->
													<div style="float:right; text-align:right; font-size:8pt; font-family:Arial; color:White; overflow:auto; background-repeat:no-repeat; background-color:#c01f1f; background-image:url('public/Coupon/Struttura/price.png'); width:210px; padding-right:5px; padding-bottom:5px;">
														<span style=" font-size:330%; color:White; font-weight:bold; clear:both; float:right; font-family:Arial Black; overflow:auto;">€ <%#String.Format("{0:n}", Eval("opzione2_prezzo"))%></span>
													   
														<div style="font-size:8pt; text-decoration:none; clear:both;">invece di <testo style="font-size:12pt; text-decoration:line-through;">€ <%#String.Format("{0:n}", Eval("opzione2_prezzodilistino"))%></testo></div>          
													</div>
													<!-- Fine Prezzo -->
												</td>
											</tr>
											<tr>
												<td style="width:50%; text-align:left;">
													<i style="font-size:10pt;"><%#Eval("opzione2_descrizione").ToString.Replace(vbCrLf, "<br/>")%></i>
												</td>
												<td style="width:50%; text-align:right;">
													Qnt.
													<asp:DropDownList ID="DB_Quantità_opzione2" runat="server" Width="180px" style="font-size:12pt; font-weight:bold;">
													</asp:DropDownList><br />
													<asp:ImageButton ID="img_opzione2" runat="server" 
														ImageUrl="public/Coupon/Struttura/acquista.png" qnt_min='<%# Eval("opzione2_qnt_min")%>' qnt_max='<%# Eval("opzione2_qnt_max")%>'
														prz='<%#String.Format("{0:n}", Eval("opzione2_prezzo"))%>' 
														qnt='<%# Eval("opzione2_qnt") %>' onclick="img_opzione2_Click" 
														title='<%#Eval("opzione2_descrizione") & " - " & Left(Eval("Titolo"),100) & " ..."%>'/>
												</td>
											</tr>
										</table>
									</div>
									
									<br />
									
									<div style="width:100%; border-style:dashed; border-width:1px; border-color:Black; text-align:left; display:<%#controllo_presenza_opzione(Eval("opzione3_qnt_min"))%>;">
										<table style=" width:100%;">
											<tr>
												<td colspan="2" style="background-color:#DFDFDF; height:50px;">
													<b style="font-size:12pt;">OPZIONE 3</b>
													<!-- Prezzo -->
													<div style="float:right; text-align:right; font-size:8pt; font-family:Arial; color:White; overflow:auto; background-repeat:no-repeat; background-color:#c01f1f; background-image:url('public/Coupon/Struttura/price.png'); width:210px; padding-right:5px; padding-bottom:5px;">
														<span style=" font-size:330%; color:White; font-weight:bold; clear:both; float:right; font-family:Arial Black; overflow:auto;">€ <%#String.Format("{0:n}", Eval("opzione3_prezzo"))%></span>
													   
														<div style="font-size:8pt; text-decoration:none; clear:both;">invece di <testo style="font-size:12pt; text-decoration:line-through;">€ <%#String.Format("{0:n}", Eval("opzione3_prezzodilistino"))%></testo></div>          
													</div>
													<!-- Fine Prezzo -->
												</td>
											</tr>
											<tr>
												<td style="width:50%; text-align:left;">
													<i style="font-size:10pt;"><%#Eval("opzione3_descrizione").ToString.Replace(vbCrLf, "<br/>")%></i>
												</td>
												<td style="width:50%; text-align:right;">
													Qnt.
													<asp:DropDownList ID="DB_Quantità_opzione3" runat="server" Width="180px" style="font-size:12pt; font-weight:bold;">
													</asp:DropDownList><br />
													<asp:ImageButton ID="img_opzione3" runat="server" 
														ImageUrl="public/Coupon/Struttura/acquista.png" qnt_min='<%# Eval("opzione3_qnt_min")%>' qnt_max='<%# Eval("opzione3_qnt_max")%>'
														prz='<%#String.Format("{0:n}", Eval("opzione3_prezzo"))%>' 
														qnt='<%# Eval("opzione3_qnt") %>' onclick="img_opzione3_Click" 
														title='<%#Eval("opzione3_descrizione") & " - " & Left(Eval("Titolo"),100) & " ..."%>'/>
												</td>
											</tr>
										</table>
									</div>
								</div>            
							</div>
						</div>
                    </tr>
                </table>
            </ItemTemplate>
        </asp:DataList>
    </div>
    <br />
    <br />
    
     <asp:SqlDataSource ID="SqlData_CouponInserzioni" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT * FROM coupon_inserzione"></asp:SqlDataSource>
        
</asp:Content>

