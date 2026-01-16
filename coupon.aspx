<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="coupon.aspx.vb" Inherits="coupon" title="Pagina senza titolo" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">

    <script src="Public/script/jquery-1.4.2.min.js" type="text/javascript"></script>
    <script src="Public/script/jquery.facets.js" type="text/javascript"></script>
    <script src="Public/script/common.js" type="text/javascript"></script>
    <script src="Public/script/jquery.clip.js" type="text/javascript"></script>
    
    <script type="text/javascript">
    $(document).ready(function() {
	    $('#main-image-box').children().removeClass('facets').end().facets({
		    control: 'ul#mainlevel',
		    clipSpacing: 1,
		    animationSpeed: 400,
		    beforeMax: function(index) {
			    $('#main-image-box .clip:eq('+index+') .container').show();
		    },
		    beforeMin: function(index) {
			    $('#main-image-box .clip:eq('+index+') .container').hide();
		    }
	    });
    });
    </script>
    
    <script type="text/javascript" language="javascript" >
		function countdown(obj, divId, tDate)
		{
			this.obj		= obj;
			this.Div		= divId;
			this.BackColor		= "white";
			this.ForeColor		= "black";
			this.TargetDate		= tDate;
			this.DisplayFormat	= "%%D%%g %%H%%h %%M%%m %%S%%s";
			this.CountActive	= true;
			this.DisplayStr;
			this.Calcage		= cd_Calcage;
			this.CountBack		= cd_CountBack;
			this.Setup		= cd_Setup;
			this.Setup();
		}
	
		function cd_Calcage(secs, num1, num2)
		{
		  s = ((Math.floor(secs/num1))%num2).toString();
		  //if (s.length < 2) s = "0" + s;
		  return (s);
		}
		function cd_CountBack(secs)
		{
		  this.DisplayStr = this.DisplayFormat.replace(/%%D%%/g,	this.Calcage(secs,86400,100000));
		  this.DisplayStr = this.DisplayStr.replace(/%%H%%/g,		this.Calcage(secs,3600,24));
		  this.DisplayStr = this.DisplayStr.replace(/%%M%%/g,		this.Calcage(secs,60,60));
		  this.DisplayStr = this.DisplayStr.replace(/%%S%%/g,		this.Calcage(secs,1,60));
		
		  document.getElementById(this.Div).innerHTML = this.DisplayStr;
		  if (this.CountActive) setTimeout(this.obj +".CountBack(" + (secs-1) + ")", 990);
		}
		function cd_Setup()
		{
			this.CountBack(Math.floor(this.TargetDate/1000));
		}

    </script>
    
    <link href="Public/style/facets.css" rel="stylesheet" type="text/css" />
    <link href="Public/style/menu.css" rel="stylesheet" type="text/css" />
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
</script>

<div id="navigation-panel" style="margin-left:6px;">
                <div class="menu">
                    <ul class="menu" id="mainlevel" style="list-style-type:none; list-style-position:inside; padding:0px; margin:auto;">
                        <asp:Repeater ID="Repeater_MenuSettori" runat="server" DataSourceID="SqlDataSettori">
                            <ItemTemplate>
                                <li><a id="settore" runat="server" href='<%# iif(Eval("linkSettore")<>"",Eval("linkSettore"),"coupon.aspx?st=" & Eval("idSettore")) %>'><%# Eval("NomeSettore") %><!--[if gte IE 7]><!--></a><!--<![endif]--><!--[if lte IE 6]><table><tr><td><![endif]--><ul>
                                    <asp:Label ID="LB_Settore" runat="server" Visible="false" Text='<%# Eval("idSettore") %>'></asp:Label>
                                    <asp:SqlDataSource ID="SqlDataCategorie" runat="server" 
                                        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
                                        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
                                        SelectCommand="SELECT idCategoria, NomeCategoria, OrdinamentoCategoria, Attiva_Disattiva_Categoria, imgCategoria, linkCategoria FROM coupon_categorie WHERE idSettore=1 ORDER BY OrdinamentoCategoria, NomeCategoria LIMIT 10"></asp:SqlDataSource>
                                    <asp:Repeater ID="Repeater_MenuCategorie" DataSourceID="SqlDataCategorie" runat="server">
                                        <ItemTemplate>
                                            <li><a target="_self" href='<%# iif(Eval("linkCategoria")<>"",Eval("linkCategoria"),"coupon.aspx?ct=" & Eval("idCategoria")) %>'><%# Eval("NomeCategoria") %>
                                            </a></li>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                </ul><!--[if lte IE 6]></td></tr></table></a><![endif]-->
                                </li>
                            </ItemTemplate>
                        </asp:Repeater>
                    </ul>
                </div>
                <div id="main-image-box">
                    <asp:Repeater ID="Repeater_SfondiSettori" DataSourceID="SqlDataSettori" runat="server">
                        <ItemTemplate>
                            <script runat="server">
                                Function maschera(ByRef val1 As Integer, ByRef val2 As Integer) As String
                                    val1 = val1 + 131
                                    val2 = val2 + 131
                                    Return "clip:rect(0px " & val1 & "px " & "455px " & val2 & "px);"
                                End Function
                            </script>
                            <div class="clip facets" style="background-image:url('<%# "public/coupon/sfondi_settori/" & Eval("imgSettore")%>'); <%= maschera(val1_maschera,val2_maschera)%>">
						        <div class="container"></div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </div>
    
    <!-- Menù Coupon -->
    <div style="width:642px; height:27px; background-color:#f7bb04; padding-left:10px; padding-right:10px; margin-top:-18px;">
        <table style="width:100%; height:100%; vertical-align:middle; text-align:center; font-family:Arial; font-weight:bold; font-size:10pt; color:White;">
            <tr>
                <td>
                    <a style="color:white;" href="default.aspx">TORNA AL SITO PRINCIPALE</a>
                </td>
                <td>
                    <a style="color:white;" href="coupon.aspx">TUTTI I COUPON</a>
                </td>
                <td>
                    <a style="color:white;" href="documenti.aspx?t=18">TUTTI I COUPON ACQUISTATI</a>
                </td>
            </tr>
        </table>
    </div>
    
    <br />
    
    <script runat="server">
        Function adatta_titolo(ByVal titolo As String, ByVal lunghezza As Integer) As String
            Return Left(titolo, lunghezza) & " ..."
        End Function
    </script>
    
    <asp:GridView ID="GV_Coupon" runat="server" DataSourceID="SqlCoupon" style="float:left;"
        ShowHeader="False" Width="460px" AutoGenerateColumns="false" BorderStyle="None" CellSpacing="0" CellPadding="0" BorderWidth="1px" RowStyle-BorderStyle="None" GridLines="None">
        <Columns>
            <asp:TemplateField>
                <ItemTemplate>
                    <% cont = cont + 1%>
                    <div style="float:left; width:460px; height:100%; border-color:Black; border-width:1px; border-style:solid; padding:5px;">
                            <div style="height:50px; width:280px; float:left; overflow:hidden;">
        	                    <p style=" margin-top:2px; margin-left:5px; font-size:10pt; font-weight:bold;"><%#adatta_titolo(Eval("Titolo"), 100)%></p>
       	                    </div>
       	                    <!-- Prezzo -->
                            <div style=" font-family:Arial; width:175px; height:50px; color:White; overflow:auto; background-repeat:no-repeat; background-color:#c01f1f; background-image:url('public/Coupon/Struttura/price_50px.png'); padding-right:5px; padding-bottom:5px;">
                                <span style=" font-size:250%; color:White; font-weight:bold; clear:both; float:right; font-family:Arial Black; overflow:auto;">€ <%#String.Format("{0:n}", Eval("Prezzo"))%></span>
                            </div>
                            <!-- Fine Prezzo -->
                            <div style="float:left; width:460px; height:200px; overflow:hidden;">
                            	<img style="width:100%;" src="public/Coupon/img_coupon/<%#Eval("Img")%>" alt="" />
                            </div>	
                            <div style="color:White; float:left; width:120px; height:50px; background:url('public/coupon/struttura/sconto_50px.png'); background-color:Green; background-repeat:no-repeat; background-position:left bottom; text-align:right; padding-right:5px;">
        	                    <p style="font-size:20pt; font-weight:bold; margin-top:10px;" >-<%#((Eval("PrezzoDiListino") - Eval("Prezzo")) * 100) / Eval("PrezzoDiListino")%>%</p>
                            </div>
                            <div style=" float:left; width:185px; height:50px; text-align:center;">
        	                    <div style="font-size:9pt; margin-top:8px;">L'inserzione scadrà tra</div>
                                <div style="font-size:13pt; font-weight:bold; -webkit-margin-before:0em; -webkit-margin-after:0em;">
                                    <div id='<%= "clock" & cont %>'>[clock<%=cont%>]</div>
                                    
                                    <script type="text/javascript">
                                        var cd<%=cont %> = new countdown('cd<%= cont %>','<%= "clock" & cont %>','<%# calcola_secondi(Eval("DataFine")) %>');
                                    </script>
                                </div>
                            </div>
                            <div style="float:left; width:150px; height:50px; text-align:right;">
        	                    <a href='<%# "coupon_dettagli.aspx?id=" & Eval("idCoupon") %>'><img src="public/coupon/struttura/dettagli.jpg" alt="" /></a>
                            </div>
                    </div>
                    
                    <div style="width:100%; height:20px; float:left;">
                        <br />
                    </div>             
                </ItemTemplate>
            </asp:TemplateField>
        </Columns>
    </asp:GridView>
        
    <div style="height:300px; width:5px; float:left;">
        <br />
    </div>
    
    <div style="float:left; width:185px; background-color:#e5e5e5;">
        <asp:SqlDataSource ID="SqlCoupon_Random" runat="server" 
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
            SelectCommand="SELECT idCoupon, Titolo, Prezzo, DataInizio, DataFine, NumeroAcquisti, Attiva_Disattiva, Min_Ordinabile, Max_Ordinabile, Img, Sintesi, Condizioni, ComeOrdinare, DescrizioneLunga, DescrizioneHtml, DescrizioneTecnica, RegioneCoupon, CittaCoupon, idPartner, PrezzoDiListino, idSettore, idCategoria, CodiceVerificaCoupon, Raggiungimento_Minimo, Raggiungimento_Massimo, idArticolo FROM coupon_inserzione ORDER BY RAND() LIMIT 4">
        </asp:SqlDataSource>
        
        <asp:Repeater ID="Repeater_Coupon_Random" runat="server" DataSourceID="SqlCoupon_Random">
            <ItemTemplate>
                <% cont_coupon_random = cont_coupon_random + 1%>
                <div style=" float:left; width:175px; height:140px; margin-top:5px; margin-left:5px;">
                    <div style="width:100%; height:100%;">
                        <div style=" float:left; width:100%; height:35px; overflow:hidden;">
                        <p style=" margin-top:2px; margin-left:5px; font-size:8pt; font-weight:bold;"><%#adatta_titolo(Eval("Titolo"), 30)%></p>
                        </div>
                        <div style=" float:left; width:100%; height:70px; overflow:hidden;">
                            <img style="width:100%;" src="public/Coupon/img_coupon/<%#Eval("Img")%>" alt="" />
                        </div>
                        <div style=" float:left; width:100%; height:35px;">
                            <div style="float: left;">
                                <p style=" margin-top:1px; margin-left:1px; font-size:15pt; font-weight:bold;" ><%#String.Format("{0:n}", Eval("Prezzo"))%></p>
                            </div>
                            <div style="float:right;">
                                <a href='<%# "coupon_dettagli.aspx?id=" & Eval("idCoupon") %>'><img src="public/coupon/struttura/dettagli_small.png" alt="" /></a>
                            </div>
                        </div>
                    </div>
                </div>
                
                <%  If cont_coupon_random = 1 Then%>
                    <div style="width:100%; height:20px; float:left;">
                        <br />
                    </div>
                <%  Else %>
                    <div style="width:100%; height:10px; float:left;">
                        <br />
                    </div>
                <%  cont_coupon_random = 0
                End If
                %>
                
            </ItemTemplate>
        </asp:Repeater>
    </div>
   
    <asp:SqlDataSource ID="SqlDataSettori" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT idSettore, NomeSettore, OrdinamentoSettore, Attiva_Disattiva_Settore, imgSettore, linkSettore FROM coupon_settori ORDER BY OrdinamentoSettore, NomeSettore LIMIT 5"></asp:SqlDataSource>
    <asp:SqlDataSource ID="SqlCoupon" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT idCoupon, Titolo, Prezzo, DataInizio, DataFine, NumeroAcquisti, Attiva_Disattiva, Min_Ordinabile, Max_Ordinabile, Img, Sintesi, Condizioni, ComeOrdinare, DescrizioneLunga, DescrizioneHtml, DescrizioneTecnica, RegioneCoupon, CittaCoupon, idPartner, PrezzoDiListino, idSettore, idCategoria, CodiceVerificaCoupon, Raggiungimento_Minimo, Raggiungimento_Massimo, idArticolo FROM coupon_inserzione WHERE (idSettore = @idSettore) or (idCategoria = @idCategoria)">
        <SelectParameters>
            <asp:QueryStringParameter Name="idSettore" QueryStringField="st" 
                DefaultValue="1" />
            <asp:QueryStringParameter Name="idCategoria" QueryStringField="ct" 
                DefaultValue="1" />
        </SelectParameters>
    </asp:SqlDataSource>
</asp:Content>

