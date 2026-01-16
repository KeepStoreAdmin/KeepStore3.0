<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="promo_in_scadenza.aspx.vb" Inherits="promo_in_scadenza" title="Pagina senza titolo" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
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
    
    <div style=" width:650px; margin:auto; text-align:center;">
    
    <img src="Images/bannerOfferte.gif" /><br /><br />
    
    <div style=" width:636px; text-align:right; padding:5px; border-color:Gray; border-style:solid; border-width:1px; font-weight:bold;"> 
        <asp:DataList ID="DataList2" runat="server" DataSourceID="sdsCategorie" Width="636px" ShowFooter="False" ShowHeader="False" SeparatorStyle-Wrap="False" SeparatorStyle-VerticalAlign="NotSet" RepeatLayout="Flow" RepeatDirection="Horizontal" HorizontalAlign="Center" style=" margin:auto;">
            <ItemTemplate>
                <div style="float:left; width:205px; height:20px; padding:2px; text-align:center; font-family:Arial;">
                    <a href='promo_in_scadenza.aspx?ct=<%#Eval("Articolo_categoria")%>'>
                        <span style="font-size:8pt; font-weight:normal;"><%#Eval("Descrizione")%> (</span><span style="font-size:9pt; font-weight:bold;"><%#Eval("cont")%></span><span style="font-size:8pt; font-weight:normal;">)  </span>
                    </a>
                </div>
            </ItemTemplate>
        </asp:DataList>
        <!-- Tasto visualizza tutto -->
        <div style="width:100%; height:20px; text-align:center;">
            <a href="promo_in_scadenza.aspx">
                <span style="font-size:7pt; font-weight:bold; color:Red; padding-right:20px;">RESETTA FILTRO PER CATEGORIA</span>
            </a>
        </div>
    </div>
    
    <div style="width:100%; height:60px; text-align:right; vertical-align:middle; background-image:url('Images/sfondo_ordinamento.png'); background-repeat:no-repeat; background-position:bottom right;">
    <table style="width:100%; height:100%; vertical-align:middle; text-align:right; border-style:none;" cellspacing="0"> 
        <tr>
            <td style="background-image:url('Images/Sfondo_Ordinamento/1.gif'); background-repeat:no-repeat; width:19px; height:60px;">
            </td>
            <td style="background-image:url('Images/Sfondo_Ordinamento/2.gif'); background-repeat:repeat-x; height:60px; padding-right:15px;">
                ORDINA PER 
                <asp:DropDownList ID="Drop_Ordinamento" style="text-align:left;" runat="server" Width="150px" AutoPostBack="True" BackColor="#FFFF80" Font-Bold="False" Font-Size="10pt" ForeColor="Black">
                  <asp:ListItem Value="P_data_scadenza">Per Data di Scadenza</asp:ListItem>
                  <asp:ListItem Value="P_decrescente">Prezzo Decrescente</asp:ListItem>
                  <asp:ListItem Value="P_crescente">Prezzo Crescente</asp:ListItem>
                </asp:DropDownList>
            </td>
            <td style="background-image:url('Images/Sfondo_Ordinamento/3.gif'); background-repeat:no-repeat; width:19px; height:60px;">
            </td>
        </tr>   
    </table>
    </div>
    
    <asp:DataList ID="DataList1" runat="server" DataSourceID="sdsArticoli" Width="650px" ShowFooter="False" ShowHeader="False" SeparatorStyle-Wrap="False" SeparatorStyle-VerticalAlign="NotSet" RepeatLayout="Flow" RepeatDirection="Horizontal" HorizontalAlign="Center" style=" margin:auto;">
        <ItemTemplate>
            <% cont = cont + 1%>
            
            <!-- INIZIO BLOCCO -->
             <div style="float:left; overflow:hidden; width:214px; border-style:solid; border-width:1px; border-color:grey; position:relative;">
                 <table border="0" cellpadding="0" cellspacing="0">
                 <tr>
                  <td colspan="3">
                         <div width="214" height="11" ></div>
                  </td>
                 </tr>
                    
                 <tr>
                  <td rowspan="2">
                   <div width="13" height="208" ></div></td>
                  <td height="196px" >
                        <script runat="server">
                            Function spedire_gratis(ByVal val As Integer) As String
                                If val = 1 Then
                                    Return "block"
                                Else
                                    Return "none"
                                End If
                            End Function
                        </script>
                        <div style="height:191px; width:10px; float:right;">
                            <img src="Public/Images/angolo.png" style="top:0px; left:0px;" height="80px;" />
                        </div>
                        <div style="height:191px; width:191px; overflow:hidden; position:relative;">
                            <div style="position:absolute; top:0px; left:0px; z-index:999; width:191px; height:40px; overflow:hidden;">
                              <!-- Spedizione Gratis -->
                              <div style="height:40px; float:left; width:100px; margin:0px;  padding-top: 0px; padding-left: 0px;">
                                <img src="Public/Images/promoSpGratis.png" alt="Questo articolo verrà spedito GRATIS !!!" style=" display:<%# spedire_gratis(Eval("SpeditoGratis")) %>;" />
                              </div>
                              <!-- Bollino Sconto-->
                              <script runat="server">
                                  Function sconto(ByVal listino_ufficiale As Double, ByVal prezzo_promo As Double, ByVal prezzo_promo_ivato As Double) As String
                                      If ((prezzo_promo > 0) And (prezzo_promo_ivato > 0) And (listino_ufficiale > 0)) Then
                                          If Session("IvaTipo") = 1 Then
                                              Return "- " & String.Format("{0:0}", ((listino_ufficiale - prezzo_promo) * 100) / listino_ufficiale) & "%"
                                          Else
                                              Return "- " & String.Format("{0:0}", ((listino_ufficiale - prezzo_promo_ivato) * 100) / listino_ufficiale) & "%"
                                          End If
                                      Else
                                          Return "- 0%"
                                      End If
                                  End Function
                              </script>
                              
                              <!-- Percentuale di Sconto -->
                              <div style="height:40px; float:right; margin:0px; background-image:url('Public/Images/angolo_x.png'); background-repeat:repeat-x; padding-top:2px; padding-left: 2px; padding-right:2px; font-style:italic; color:White; text-align:center;"><span style="font-family:Verdana, Geneva, sans-serif; font-size:12px; font-weight:bold;">sconto</span><br /><span style="font-family:Verdana, Geneva, sans-serif; font-size:18px;  font-weight:bold;"><%#sconto(Eval("Listino_Ufficiale"), Eval("PrezzoPromo"), Eval("PrezzoPromoIvato"))%></span>
                              </div>
                             </div>
                            <table style="width:191px; height:191px; text-align:center; vertical-align:middle;">
                                <tr>
                                    <td>
                                       <a href="articolo.aspx?id=<%# Eval("id") %>"><img border="0" width="190px" src='<%# "Public/Foto/_" & Eval("Img1") %>' /></a>
                                    </td>
                                </tr>
                            </table>
                        </div>
                  </td>
                  <td rowspan="2"><div width="10" height="208"></div></td>
                 </tr>
                 <tr>
                  <td ><div width="191" height="15" ></div></td>
                 </tr>
                 <tr>
                  <td style="width:13px; height:35px; "></td>
                  <td >
                  <script runat="server">
                      Function compatta_testo(ByVal testo As String, ByVal lunghezza As Integer) As String
                          Return Left(testo, lunghezza) & "..."
                      End Function
                  </script>
                   <div style="width:191px; height:35px;overflow:hidden;font-size:14px; font-weight:bold;" ><%#compatta_testo(Eval("Descrizione1"), 37)%></div></td>
                  <td style=" width:10px; height:25px;">
                </td>
                 </tr>
                 
                 <tr>
                  <td style="width:13px; "></td>
                  <td >
                         <div style="width:191px; height:120px; overflow:hidden;font-size: 11px;" >
                                <div style="margin-top:0px; width:191px;font-size: 11px; text-align:center;" >
                                    <span style="background-image:url('Images/back_menu.png'); background-position:center; background-color:gray; background-repeat:repeat-x; display:block; color:white; font-weight:bold; padding:5px;">LA PROMO SCADE TRA</span>
                                    <span style="background-image:url('Images/back_menu.png'); background-position:center; background-color:#ff3c3c; background-repeat:repeat-x; display:block; color:white; font-size:11pt; padding:5px;"><div id='<%= "clock" & cont %>'>[clock<%=cont%>]</div></span>
                                    <script language="javascript">
                                        var cd<%=cont %> = new countdown('cd<%= cont %>','<%= "clock" & cont %>','<%# calcola_secondi(Eval("OfferteDataFine")) %>');
                                    </script>
                                </div>
                                <div style="width:191px; height:100%; margin-top:0px; overflow:hidden;font-size: 11px; padding-top:5px;" ><%#compatta_testo(Eval("Descrizione2"), 120)%></div>
                         </div>
                        </td>
                  <td style="width:10px;"></td>
                 </tr>
                 <tr>
                  <td style="width:13px; height:21px;"></td>
                  <td >
                   <div style="width:191px; height:21px;overflow:hidden;font-size: 11px; text-align:center; padding:5px;" >
                            Codice: <%#Eval("Codice")%>
                            </div></td>
                  <td style="width:10px; height:21px;">
                  </td>
                 </tr>
                  
                 <tr>
                  <td colspan="3" >
                        <script runat="server">
                            Function prezzo_formattato(ByVal prezzo As String) As String
                                Dim temp As String() = prezzo.Split(",")
                                Return "<span style=""font-size:27px;"">" & temp(0) & ",</span><span style=""font-size:20px;"">" & temp(1) & "</span>"
                            End Function
                        </script>
                        <%If Session("IvaTipo") = 1 Then%>
                            <div style="width:100%; height:31px; overflow:hidden; text-align:center; font-weight:bold;" ><%#prezzo_formattato(Eval("prezzoPromo", "{0:C}"))%></div>
                        <%Else%>
                            <div style="width:100%; height:31px; overflow:hidden; text-align:center; font-weight:bold;" ><%#prezzo_formattato(Eval("prezzoPromoIvato", "{0:C}"))%></div>
                        <%End If%>
                        
                        <!-- Listino Ufficiale -->
                        <div style="width:100%; height:30px; overflow:hidden; text-align:center; font-weight:bold; font-size:9pt;" >prezzo di listino <span style=" text-decoration:line-through; color:Red;"><%#Eval("Listino_Ufficiale", "{0:C}")%></span></div>
                        
                        <%If Session("IvaTipo") = 1 Then%>
                            <div style="width:100%; height:30px; overflow:hidden; text-align:center; font-weight:bold; font-size:11pt;" >risparmi <span style="color:Red; font-size:9pt;"><%#String.Format("{0:C}", Eval("Listino_Ufficiale") - Eval("PrezzoPromoIvato"))%></span></div>
                        <%Else%>
                            <div style="width:100%; height:30px; overflow:hidden; text-align:center; font-weight:bold; font-size:11pt;" >risparmi <span style="color:Red; font-size:9pt;"><%#String.Format("{0:C}", Eval("Listino_Ufficiale") - Eval("PrezzoPromoIvato"))%></span></div>
                        <%End If%> 
                  </td>
                 </tr>
                 <tr>
                  <td colspan="3" style="width:214px; height:10px;"></td>
                 </tr>
                </table>
            </div>
        </ItemTemplate>
    </asp:DataList>
    
    <!-- Visualizzo se i prezzi sono iva inclusa o eclusa -->
    <br /><br />
    <%If Session("IvaTipo") = 1 Then%>
        <div style="width:100%; height:21px; overflow:hidden; text-align:left; font-size:10pt;" >*I Prezzi sono da considerarsi IVA Esclusa</div>
    <%Else%>
        <div style="width:100%; height:21px; overflow:hidden; text-align:left; font-size:10pt;" >*I Prezzi sono da considerarsi IVA Inclusa</div>
    <%End If%>
    </div>
    
    <asp:SqlDataSource ID="sdsArticoli" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT * FROM [1_pubblico]"></asp:SqlDataSource>
    <asp:SqlDataSource ID="sdsCategorie" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT * FROM [1_pubblico]"></asp:SqlDataSource>    
    
</asp:Content>

