<%@ Page Language="VB" MasterPageFile="~/Coupon.master" AutoEventWireup="false" CodeFile="lista_coupon.aspx.vb" Inherits="lista_coupon" title="Pagina senza titolo" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
    <script runat="server">
        Function calcola_secondi(ByVal data As String) As String
            Dim temp_data As String() = data.Split("/")
            Dim temp_data1 As New DateTime(temp_data(2), temp_data(1), temp_data(0), 0, 0, 0)
            Dim temp_data2 As New DateTime(Date.Now.Year, Date.Now.Month, Date.Now.Day, Date.Now.Hour, Date.Now.Minute, Date.Now.Second)
            'Aggiungo 1 giorno in più, perchè le nostre promo scadono alla mezzanotte del giorno di fine
            temp_data1 = temp_data1.AddDays(1)
            Dim temp_sec As TimeSpan = temp_data1.Subtract(temp_data2)
            Return temp_sec.TotalMilliseconds
        End Function
        
        Function adatta_titolo(ByVal titolo As String, ByVal lunghezza As Integer) As String
            Return Left(titolo, lunghezza) & " ..."
        End Function
    </script>
    
    <div class="row">
		<asp:Repeater ID="Repeater_Coupon" DataSourceID="SqlDataCoupon" runat="server">
			<ItemTemplate>
				<% cont_clock = cont_clock + 1%>
				<!-- Box Coupon -->
				<div class="col-12 col-sm-6 col-md-4 col-lg-3 pt-4">
					<div class="box_background" style="margin: 0 auto;">
						<!-- Top -->
						<div class="box_coupon_header">
							<div class="box_coupon_price">
								<%#Eval("prezzo")%>
							</div>
							<div class="box_coupon_price_full">
								invece di <span style="text-decoration:line-through;">€ <%#Eval("PrezzoDiListino")%></span>
							</div>
							<div class="box_coupon_price_discount">
								-<%#((Eval("PrezzoDiListino") - Eval("Prezzo")) * 100) / Eval("PrezzoDiListino")%>%
							</div>
						</div>
						<!-- Immagine -->
						<div class="box_image" style="background-image:url('public/Coupon/img_coupon/<%#Eval("Img")%>'); background-size:cover;">
							<a href='<%# "coupon_dettagli.aspx?id=" & Eval("idCoupon") %>'>
								<div style=" width:100%; height:100%;">
									<div class="box_coupon_category"><%# Eval("NomeSettore") & " > " & eval("NomeCategoria")  %></div>
								</div>
							</a>
						</div>
						<a href='<%# "coupon_dettagli.aspx?id=" & Eval("idCoupon") %>' style="text-decoration:none;">
							<!-- Footer -->
							<div class="box_coupon_footer">
								<div class="box_coupon_title">
									<%#adatta_titolo(Eval("Titolo"), 62)%>
								</div>
								<div class="box_coupon_clock">
									<div id='<%= "clock" & cont_clock %>'>[clock<%=cont_clock%>]</div>
								
									<script type="text/javascript">
										var cd<%=cont_clock %> = new countdown('cd<%= cont_clock %>','<%= "clock" & cont_clock %>','<%# calcola_secondi(Eval("DataFine")) %>');
									</script>
								</div>
							</div>
						</a>
					</div>
				</div>
			</ItemTemplate>
		</asp:Repeater>
	</div>
    <!-- Fine Box Coupon -->
    
    <!-- Visualizzo il messaggio che non è stato trovato nessun Coupon -->
    <%If Repeater_Coupon.Items.Count = 0 Then%>
        <div style="margin:auto; width:500px; height:200px; text-align:center; margin-top:200px;">
            Nessun Coupon Trovato
        </div>
    <%End If%>
    
	<br />
	
    <!-- Data Source -->
    <asp:SqlDataSource ID="SqlDataCoupon" runat="server" 
    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
    SelectCommand="SELECT * FROM coupon_inserzione WHERE ((DATEDIFF(CURDATE(),DataInizio)>=0) AND (DATEDIFF(CURDATE(),DataFine)<=0))"></asp:SqlDataSource>
</asp:Content>

