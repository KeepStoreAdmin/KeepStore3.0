<%@ Page Language="VB" AutoEventWireup="false" CodeFile="vetrina_interna.aspx.vb" Inherits="vetrina_interna" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Vetrina Interna</title>
    
    <link rel="stylesheet" rev="stylesheet" href="http://meyerweb.com/eric/tools/css/reset/reset.css" type="text/css" media="all">
	<link rel="stylesheet" href="Images/vetrina_interna/style/style.css" />
	<link rel="stylesheet" href="Images/vetrina_interna/style/jquery.ferro.ferroSlider.css" />

	<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js" type="text/javascript"></script>
	<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery-easing/1.3/jquery.easing.min.js" type="text/javascript"></script>
	<script src="Images/vetrina_interna/script/jquery.ferro.ferroSlider-1.1.1.js" type="text/javascript" language="javascript"></script>

    <link href='http://fonts.googleapis.com/css?family=Paytone+One' rel='stylesheet' type='text/css'>
</head>

    <script type="text/javascript">
		var displace = [
				[
					{full:0},{full:1,moveDirection:'yx'},{full:0}
				],
				[
					{full:1},{full:1,first:true},{full:1}
				],
				[
					{full:0},{full:1,moveDirection:'yx'},{full:0}
				]
		];
		
		$(document).ready(function() {
			$(".slidingSpaces").ferroSlider({
				axis					: 'xy',
				//displace				: displace,
				easing					: 'easeOutExpo',
				createMap				: false,
				feedbackArrows			: false,
				fullScreenBackground	: true,
				mapPosition				: 'bottom_center',
				backGroundImageClass	: 'bg',
				preloadBackgroundImages	: true,
				time					: 1000
			});
		});
	</script>
	
<body style=" width:100%; height:100%;">
    <form id="form1" runat="server">
    <div>
        <div style=" display:none;">
        <asp:SqlDataSource ID="SqlData_ArticoliVetrina" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT vsuperarticoli.Descrizione1, vsuperarticoli.Descrizione2, vsuperarticoli.DescrizioneLunga, vsuperarticoli.Marche_img, vsuperarticoli.MarcheDescrizione, vsuperarticoli.Ean, vsuperarticoli.id, vsuperarticoli.Codice, vsuperarticoli.Img1, vsuperarticoli.NListino, vsuperarticoli.PrezzoIvato, bollini_vetrina.path, vsuperarticoli.InOfferta, vsuperarticoli.OfferteQntMinima, vsuperarticoli.PrezzoPromoIvato FROM vetrinainterna INNER JOIN vsuperarticoli ON vetrinainterna.idArticolo = vsuperarticoli.id LEFT OUTER JOIN bollini_vetrina ON vetrinainterna.id_bollino = bollini_vetrina.idBollino WHERE (vsuperarticoli.NListino = @NListino) Limit 200">
            <SelectParameters>
                <asp:QueryStringParameter Name="NListino" QueryStringField="n" />
            </SelectParameters>
        </asp:SqlDataSource>
        </div>
        
        <script runat="server">
            Function adatta_titolo(ByVal temp As String) As String
                If temp.Length > 50 Then
                    Return Left(temp, 50) & " ..."
                Else
                    Return temp
                End If
            End Function
            
            Function genera_id() As Integer
                cont_prodotti = cont_prodotti + 1
                Return cont_prodotti
            End Function
        </script>
        
        <asp:Repeater ID="Repeater1" runat="server" DataSourceID="SqlData_ArticoliVetrina">
            <ItemTemplate>
            <div id='<%# "div" & genera_id() %>' class="slidingSpaces demo4" title="" style=" width:100%; height:100%;">
			    <img src="" class="bg"/>
			        <div style=" width:100%; height:20%; background-image:url('Images/vetrina_interna/metal_top.jpg'); background-position:bottom left; background-repeat:repeat-x; overflow:hidden; text-align:center;">
			            <table style="height:100%; width:100%; vertical-align:top;">
			                <tr style=" width:100%; height:100%; overflow:hidden; vertical-align:top;">
			                    <td style=" width:100%; height: 100%; vertical-align:top; padding:10px; text-align:center; overflow:hidden; font-family: 'Paytone One', sans-serif; font-size:35pt; color:yellow; line-height:70px;">
		                            <span style="font-family: 'Paytone One', sans-serif; color:white; font-size:70%; color:orange; text-shadow:0 0 11px black;"><%#Eval("MarcheDescrizione")%> </span>
		                            <span style="font-family: 'Paytone One', sans-serif; color:white; font-size:70%; text-shadow:0 0 11px black;"><%#adatta_titolo(Eval("Descrizione1"))%></span>
			                    </td>
			                </tr>
			            </table>
			        </div>
			        
			        <div style="width:100%; height:70%; background-color:white; position:relative;">
			                <!-- Immagini Prodotto -->
			                <img alt="" src='<%# "Public/Foto/" & Eval("img1") %>' style="max-height:90%; max-width:100%; position:absolute; top:10px; left:20px;" />    
			                
			                <!-- Immagini Bollini Promo -->
			                <img src='<%# "Public/Bollini/" & Eval("path") %>' alt="" style="height:60%; max-width:100%; position:absolute; top:10px; right:100px;" /> 
			                
					        <!-- Prezzo nascosto, solo come riferimento-->
					        <asp:Label ID="Prezzo" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>' ForeColor="Red" Visible="false"></asp:Label>
					        <asp:Label ID="InOfferta" runat="server" Text='<%# Eval("InOfferta") %>' ForeColor="Red" Visible="false"></asp:Label>
					        <asp:Label ID="OffertaQntMinima" runat="server" Text='<%# Eval("OfferteQntMinima") %>' ForeColor="Red" Visible="false"></asp:Label>
					        <asp:Label ID="PrezzoPromoIvato" runat="server" Text='<%# Eval("PrezzoPromoIvato","{0:C}") %>' ForeColor="Red" Visible="false"></asp:Label>
			        </div>
			        
			        <div style="width:100%; height:10%; background-image:url('Images/vetrina_interna/metal_bottom.jpg'); background-repeat:repeat-x; background-position:left top; vertical-align:middle;">
			            <div style="width:100%; height:20%; padding:0px; color: black; text-align:right; position:absolute; bottom:10px; right:1%; z-index:9999;">
                            <asp:Image ID="img_prezzo9" runat="server" Height="100%" Visible="False" />
                            <asp:Image ID="img_prezzo8" runat="server" Height="100%" Visible="False" />
                            <asp:Image ID="img_prezzo7" runat="server" Height="100%" Visible="False" />
                            <asp:Image ID="img_prezzo6" runat="server" Height="100%" Visible="False" />
                            <asp:Image ID="img_prezzo5" runat="server" Height="100%" Visible="False" />
                            <asp:Image ID="img_prezzo4" runat="server" Height="100%" Visible="False" />
                            <asp:Image ID="img_prezzo3" runat="server" Height="30%"  Visible="False" />
                            <asp:Image ID="img_prezzo2" runat="server" Height="60%" Visible="False" />
                            <asp:Image ID="img_prezzo1" runat="server" Height="60%" Visible="False" />
                        </div>
			        </div> 
		    </div>
		    </ItemTemplate>
        </asp:Repeater>
        
    </div>
    </form>
</body>
</html>
