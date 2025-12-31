<%@ Page Language="VB" MasterPageFile="~/Coupon.master" AutoEventWireup="false" CodeFile="coupon_dettagli.aspx.vb" Inherits="coupon_dettagli" title="Pagina senza titolo" %>

<asp:Content ID="Content1" ContentPlaceHolderID="Contentplaceholder1" Runat="Server">
    <script src="Public/script/google_maps.js" type="text/javascript"></script>
    
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
    
    <!-- COUPON -->
    <a name="coupon"></a>
    
    <asp:DataList ID="DataList_Coupon" runat="server" DataSourceID="SqlData_CouponInserzioni" style="margin-top:10px;">
        <ItemTemplate>
            <div class="container-fluid">
                <div class="row">
                    <div class="col-12 col-lg-8">
                        <table>
                            <tr>
                                <td colspan="2">
                                    <div class="box_coupon_category" style="background-color:#e6e6e6; color:Black; font-size:12px;"><%#Eval("NomeSettore") & " > " & Eval("NomeCategoria")%></div>
                                </td>
                            </tr>
                            <tr>
                                <td colspan="2" style="font-size:20px; border-bottom-style:dashed; border-bottom-width:1px; border-bottom-color:Black; padding-bottom:15px;">
                                <!-- Titolo -->
                                    <%#Eval("Titolo")%>
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    <!-- Immagine Principale -->
                                    <div style="width:100%; height:200px; overflow:hidden; float:left;">
                                        <img style="width:100%;" src="public/Coupon/img_coupon/<%#Eval("Img")%>" alt="" />
                                    </div>
                                </td>
                                <td style="text-align:right;">                                   
                                    <!-- Prezzo -->
                                    <span style="font-size:2.2rem; color:rgb(180, 15, 15); font-weight:bold; clear:both; float:right; font-family:Arial Black; overflow:auto;">€ <%#String.Format("{0:n}", Eval("Prezzo"))%></span>
                                    <div style="font-size:8pt; text-decoration:none; clear:both;">invece di <testo style="font-size:12pt; text-decoration:line-through;">€ <%#String.Format("{0:n}", Eval("PrezzoDiListino"))%></testo></div>
                                    
                                    <!-- Conto alla rovescia -->
                                    <table style="width:200px; margin-right:0px; float:right;">
                                        <tr>
                                            <td>
                                                <img src="Images/Coupon/clessidra.png" alt="" /> 
                                            </td>
                                            <td>
                                                <div style="font-size:9pt; margin-top:8px;">L'inserzione scadrà tra</div>
                                                <div style="font-size:12pt; font-weight:bold; -webkit-margin-before:0em; -webkit-margin-after:0em;">
                                                    <div id='<%= "clock" & cont %>'>[clock<%=cont%>]</div>
                                                    <script type="text/javascript">
                                                        var cd<%=cont %> = new countdown('cd<%= cont %>','<%= "clock" & cont %>','<%# calcola_secondi(Eval("DataFine")) %>');
                                                    </script>
                                                </div>
                                            </td>
                                        </tr>
                                    </table>
                                    
                                    <a style=" margin:auto;" href='<%# "coupon_opzioni.aspx?id=" & Eval("idCoupon") %>'><img src="public/Coupon/Struttura/acquista.png" alt="" height="50px" /></a>
                                </td>
                            </tr>
                            <tr>
                                <td colspan="2">
                                     <!-- Acquistati e Visite -->
                                      <div style=" width:99,8%; margin:0.5rem; text-align:center; vertical-align:middle; background-color:#e6e6e6; border-style:dashed; border-width:1px; border-color:Black;">
                                        <table style=" width:80%; margin:auto; text-align:left; vertical-align:middle; font-size:10pt;">
                                            <tr>
                                                <td>
                                                    <img src="Public/Images/Acquistati.png" alt=""/>
                                                </td>
                                                <td>                         
                                                     Già <b style="font-size:14pt;"><%#Eval("NumeroAcquisti")%></b> Coupon Acquistati
                                                </td>
                                                <td>
                                                    <img src="Public/Images/Visite.png" alt=""/>
                                                </td>
                                                <td>
                                                    Il Coupon ha già ricevuto <b style="font-size:14pt;"><%#Eval("Visite")%></b> visite
                                                </td>
                                            </tr>
                                        </table>
                                      </div>
                                </td>
                            </tr>
                            <tr>
                                <td colspan="2">
                                    <!-- Box Caratteristiche -->
                                    <div class="row">
                                        <div class="col-12 col-md-6">
                                            <p>
                                                <b>Sintesi</b><br /><br />
                                                <%#Eval("Sintesi").ToString.Replace(vbCrLf, "<br/>")%>
                                                <br /><br />
                                                
                                                <b style="font-size:10pt;">Condizioni</b><br /><br />
                                                <%#Eval("Condizioni").ToString.Replace(vbCrLf, "<br/>")%>
                                                
                                                <br /><br /><b style="font-size:10pt; display:<%#controllo_presenza_opzione(Eval("opzione1_descrizione").ToString.Replace(vbCrLf, "<br/>"))%>;">Opzioni</b><br />
                                                <ul style=" width:90%; line-height:30px;" type="square">
                                                    
                                                    <script runat="server">
                                                        Function controllo_presenza_opzione(ByVal opzione As String) As String
                                                            If opzione <> "" Then
                                                                Return ""
                                                            Else
                                                                Return "none"
                                                            End If
                                                        End Function
                                                        
                                                        Function reindirizza_a_opzioni(ByVal opzione As String) As String
                                                            If opzione <> "" Then
                                                                Return ""
                                                            Else
                                                                Return "none"
                                                            End If
                                                        End Function
                                                    </script>
                                                    
                                                    <li style="margin-left:-30px; display:<%#controllo_presenza_opzione(Eval("opzione1_descrizione").ToString.Replace(vbCrLf, "<br/>"))%>;">
                                                        <%#Eval("opzione1_descrizione").ToString.Replace(vbCrLf, "<br/>")%> <b> a € <%#String.Format("{0:n}", Eval("opzione1_prezzo"))%></b> invece di € <%#String.Format("{0:n}", Eval("opzione1_prezzodilistino"))%>
                                                    </li>
                                                    <li style="margin-left:-30px; display:<%#controllo_presenza_opzione(Eval("opzione2_descrizione").ToString.Replace(vbCrLf, "<br/>"))%>;">
                                                        <%#Eval("opzione2_descrizione").ToString.Replace(vbCrLf, "<br/>")%> <b> a € <%#String.Format("{0:n}", Eval("opzione2_prezzo"))%></b> invece di € <%#String.Format("{0:n}", Eval("opzione2_prezzodilistino"))%>
                                                    </li>
                                                    <li style="margin-left:-30px; display:<%#controllo_presenza_opzione(Eval("opzione3_descrizione").ToString.Replace(vbCrLf, "<br/>"))%>;">
                                                        <%#Eval("opzione3_descrizione").ToString.Replace(vbCrLf, "<br/>")%> <b> a € <%#String.Format("{0:n}", Eval("opzione3_prezzo"))%></b> invece di € <%#String.Format("{0:n}", Eval("opzione3_prezzodilistino"))%>
                                                    </li>
                                                </ul>
                                            </p>
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <b style="font-size:10pt;">Descrizione</b><br />
                                            <%#Eval("DescrizioneLunga").ToString.Replace(vbCrLf, "<br/>")%>
                                        </div>
                                    </div>
                                </td>
                            </tr>
                           <tr>
                                <td colspan="2" style="background-color:#efedee; font-weight:bold; padding:10px;">
                                    IL PARTNER
                                </td>
                           </tr>
                           <tr>
                                <td colspan="2">
                                    <div class="row">
                                        <div class="col-12 col-md-6">
                                            <b><%#Eval("RagioneSociale")%></b><br />
                                            <%#Eval("Cognome")%> <%#Eval("Nome")%><br />
                                            <%#Eval("Via")%><br />
                                            <%#Eval("Citta")%> (<%#Eval("Provincia")%>)<br />
                                            <%#Eval("CAP")%><br />
                                            <%#Eval("Telefono") %> - <%#Eval("Fax")%><br />
                                            <a href='<%# "http://" & Eval("SitoWeb")%>'><%#Eval("SitoWeb")%></a>
                                            
                                            <br /><br />
                                            <b>Più info</b>
                                            <br />
                                            <%#Eval("Descrizione_Partner") %>
                                        </div>
                                        <div class="col-12 col-md-6">
                                            <%#Eval("GoogleMaps_iFrame")%>
                                        </div>
                                    </div>
                                </td>
                           </tr>
                           <tr>
                                <td colspan="2" style="background-color:#efedee; font-weight:bold; padding:10px; display:<%# visualizza_descrizione_tecnica(Eval("DescrizioneTecnica"))%>;">
                                    Descrizione Tecnica
                                </td>
                           </tr>
                           <tr>
                                <td colspan="2">
                                    <script runat="server">
                                        Function visualizza_descrizione_tecnica(ByVal stringa As Object) As String
                                            If Not IsDBNull(stringa) Then
                                                stringa = CType(stringa, String)
                                                If stringa <> "" Then
                                                    Return ""
                                                Else
                                                    Return "none"
                                                End If
                                            Else
                                                Return "none"
                                            End If
                                        End Function
                                    </script>
                                    
                                    <!-- Box Articolo - 1 Sezione -->
                                     <div style="display:<%# visualizza_descrizione_tecnica(Eval("DescrizioneTecnica"))%>; width:100%; padding-top:20px; padding-bottom:20px;">
                                        <%#Eval("DescrizioneTecnica")%>
                                    </div>
                                </td>
                           </tr>
                        </table>
                    </div>
                    <div class="col-12 col-lg-4" style="margin: 0 auto;">
                        <script runat="server">
                            Function adatta_titolo(ByVal titolo As String, ByVal lunghezza As Integer) As String
                                Return Left(titolo, lunghezza) & " ..."
                            End Function
                        </script>
                        <!-- Inserzioni Random -->
                        <asp:Repeater ID="Repeater_Coupon_Random" runat="server" DataSourceID="SqlCoupon_Random">
                            <ItemTemplate>
                                <div style="float:left; width:250px; height:300px; margin-top:5px; margin-left:5px; background-color:#efedee; padding:2px;">
                                    <table style="width:100%; height:100%;">
                                        <tr>
                                            <td>
                                                <div class="box_coupon_category" style="background-color:#e6e6e6; color:Black; font-size:12px;"><%#Eval("NomeSettore") & " > " & Eval("NomeCategoria")%></div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <div style="width:100%; overflow:hidden;">
                                                    <p style="font-size:9pt; font-weight:bold;"><%#adatta_titolo(Eval("Titolo"), 30)%></p>
                                                </div>        
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <div style="width:100%; overflow:hidden;">
                                                    <a href='<%# "coupon_dettagli.aspx?id=" & Eval("idCoupon") %>'><img style="width:100%;" src="public/Coupon/img_coupon/<%#Eval("Img")%>" alt="" /></a>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>
                                                <div style="float:left; width:50%;">
                                                    <p style="font-size:15pt; font-weight:bold; margin:auto;">€ <%#String.Format("{0:n}", Eval("Prezzo"))%></p>
                                                    <p style="font-size:9pt; font-weight:bold; margin:auto;">invece di <testo style="font-size:10pt; text-decoration:line-through;">€ <%#String.Format("{0:n}", Eval("PrezzoDiListino"))%></testo></p>
                                                </div>
                                                <div style="float:right;">
                                                    <a href='<%# "coupon_dettagli.aspx?id=" & Eval("idCoupon") %>'><img src="public/coupon/struttura/dettagli_small.png" alt="" /></a>
                                                </div>
                                            </td>
                                        </tr>
                                    </table>                                        
                                </div>                                
                            </ItemTemplate>
                        </asp:Repeater>
                    </div>
                </div>
            </div>
            </ItemTemplate>
    </asp:DataList>
    
    <asp:SqlDataSource ID="SqlCoupon_Random" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT * FROM vsupercoupon WHERE ((DATEDIFF(CURDATE(),DataInizio)>=0) AND (DATEDIFF(CURDATE(),DataFine)<=0)) ORDER BY RAND() LIMIT 10">
    </asp:SqlDataSource>
    <asp:SqlDataSource ID="SqlData_CouponInserzioni" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT * FROM coupon_inserzione">
    </asp:SqlDataSource>
</asp:Content>

