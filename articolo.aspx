<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="articolo.aspx.vb" Inherits="articolo" Debug="true" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server"><%: Page.Title %></asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">

<!-- Facebook -->
<div id="fb-root"></div>
<script>(function(d, s, id) {
  var js, fjs = d.getElementsByTagName(s)[0];
  if (d.getElementById(id)) return;
  js = d.createElement(s); js.id = id;
  js.src = "//connect.facebook.net/it_IT/all.js#xfbml=1&appId=270573646450529";
  fjs.parentNode.insertBefore(js, fjs);
}(document, 'script', 'facebook-jssdk'));</script>

<%For Each pairInidsFbPixelsSku In idsFbPixelsSku
Dim facebook_pixel_id As String = pairInidsFbPixelsSku.key
Dim sku As String = pairInidsFbPixelsSku.value%>
<!-- Facebook Pixel Code -->
<script>
  !function(f,b,e,v,n,t,s)
  {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
  n.callMethod.apply(n,arguments):n.queue.push(arguments)};
  if(!f._fbq)n=f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
  n.queue=[];t=b.createElement(e);t.async=!0;
  t.src=v;s=b.getElementsByTagName(e)[0];
  s.parentNode.insertBefore(t,s)}(window, document,'script',
  'https://connect.facebook.net/en_US/fbevents.js');
  fbq('init', '<%=facebook_pixel_id%>'<%If utenteId = "-1" Then%>);<%Else%>, {
	fn: '<%=firstName%>',
    ln: '<%=lastName%>',
	em: '<%=email%>',
    ph: '<%=phone%>',
	country: '<%=country%>',
	st: '<%=province%>',
	ct: '<%=city%>',
	zp: '<%=cap%>'
  });<%End If%>
  fbq('track', 'ViewContent', {
    content_ids: '<%=sku%>',
    content_type: 'product',
  });
</script>
<noscript><img height="1" width="1" style="display:none"
  src="https://www.facebook.com/tr?id=<%=facebook_pixel_id%>&ev=PageView&noscript=1"
/></noscript>
<!-- End Facebook Pixel Code -->
<%Next%>
<!-- -------------------------------------------- -->

<script type="text/javascript" src="https://code.jquery.com/jquery-latest.js"></script> 
<script type="text/javascript" src="Public/script/ddpowerzoomer.js"></script>
<script type="text/javascript">
jQuery(document).ready(function($){

 $("a#close-panel").click(function(){
     $("#lightbox, #lightbox-panel").fadeOut(300);
 });
 
 $('#dettagli_arrivi').click(function(){
     $("#lightbox-panel").fadeIn(300);
 });

//Swap Image on Click
 $("ul.thumb li a").click(function() {
     var mainImage = $(this).attr("href"); //Find Image Name
     $("#main_view img").attr({ src: mainImage });
     $("#lightbox-panel #img").attr({ src: mainImage });
     return false;		
 });
 
 $('#main_img').click(function(){
     $("#lightbox-panel").fadeIn(300);
 });

});
</script> 

<style type="text/css">
#lightbox-panel {
 display:none;
 position:fixed;
 top:0px;
 left:0px;
 width:100%;
 height:100%;
 z-index:1001;
}
select {
 text-align: center;
}
</style>

<script runat="server">
    Function Sostituisci_caratteri(ByVal temp As String) As String
        Return System.Web.HttpUtility.HtmlEncode(temp)
    End Function
    
    Function controlla_iva_spedizione() As Integer
        Return Session.Item("IvaTipo")
    End Function
                
    Function controlla_iva_listinoufficiale() As Integer
        Return Session.Item("IvaTipo")
    End Function
    
    Function controlla_brochure(ByVal obj As Object) As Integer
        If Not IsDBNull(obj) Then
            If obj.ToString <> "" Then
                Return 1
            Else
                Return 0
            End If
        Else
            Return 0
        End If
    End Function
            
    Function controlla_link_produttore(ByVal obj As Object) As Integer
        If Not IsDBNull(obj) Then
            If ((obj.ToString <> "") AndAlso (obj.ToString.Length > 10)) Then
                Return 1
            Else
                Return 0
            End If
        Else
            Return 0
        End If
    End Function
            
    Function controlla_note_garanzia(ByVal obj As Object) As Integer
        If Not IsDBNull(obj) Then
            If (obj.ToString <> "") Then
                Return 1
            Else
                Return 0
            End If
        Else
            Return 0
        End If
    End Function
            
    Function controlla_garanzia(ByVal obj As Object) As Integer
        If Not IsDBNull(obj) Then
            If ((obj.ToString <> "") AndAlso (Val(obj.ToString) > 0)) Then
                Return 1
            Else
                Return 0
            End If
        Else
            Return 0
        End If
    End Function
            
    Function valore_LU(ByVal tmp As Object, ByVal iva As Double) As String
        If IsDBNull(tmp) OrElse tmp.ToString = "0" Then
            Return "-"
        Else
            If controlla_iva_listinoufficiale() = 2 Then
                Return String.Format("{0:c}", CDbl(tmp) * ((iva / 100) + 1))
            Else
                Return String.Format("{0:c}", CDbl(tmp))
            End If
        End If
    End Function
</script>

<div class="container mt-3">
    <div class="row">
        <div class="col-12">
            <h1>Scheda Prodotto</h1>
        </div>
    </div>
</div>

<asp:SqlDataSource ID="sdsArticolo" runat="server" 
    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
    SelectCommand="SELECT * FROM vsuperarticoli WHERE (id = ?id) and (NListino = ?NListino)">
    <SelectParameters>
        <asp:QueryStringParameter Name="id" QueryStringField="id" Type="Int32" />
        <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
    </SelectParameters>
</asp:SqlDataSource>
    
<div class="container-fluid bg-white home-box-position mt-3 bg-shadow">
    <asp:FormView ID="fvPage" runat="server" DataKeyNames="id" DataSourceID="sdsArticolo" Width="100%" Height="1px">
        <ItemTemplate>

            <script type="text/javascript">
                //Funzioni per la visualizzazione di specifiche, NON UTILIZZATE AL MOMENTO
                function nascondi_immagine_lightbox(){
                    document.getElementById("img").style.display='none';
                    document.getElementById("dettagli_arrivi_lightbox").style.display='';
                }
                
                function nascondi_dettagli_lightbox(){
                    document.getElementById("dettagli_arrivi_lightbox").style.display='none';
                    document.getElementById("img").style.display='';
                }
            </script>

            <!-- Immagine a tutto schermo -->
            <div id="lightbox-panel" style="overflow:auto;">
                <a id="close-panel" href="#" style="text-decoration:none; color:red; font-weight:bold; border:none;">
                    <table style=" width:100%; height:100%; background-image:url('Images/back_zoom.png'); background-repeat:repeat; background-position:left top;">
                        <tr>
                            <td style="text-align:center; vertical-align:middle;">
                                <p align="center">
                                    <div id="contenuto_popup" style="overflow:auto; height:auto; width:auto;">
                                        <!-- Visualizzatore Immagine -->
                                        <img id="img" src="<%# checkImg(Eval("Img1")) %>" style="border:none; max-height:800px; max-width:1000px;" alt=""/>
                                        
                                        <!-- Visualizzatore specifiche Data di Arrivo -->
                                        <!-- Arrivi -->
                                        <div id="dettagli_arrivi_lightbox" style="width:500px; height:100%; overflow:auto; background-color:White; margin:auto;">
                                            <asp:SqlDataSource ID="SqlData_Arrivo" runat="server" 
                                                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
                                                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                                SelectCommand="SELECT * FROM articoli_arrivi WHERE (ArticoliId=?ID) AND ((TO_DAYS(DataArrivo) - TO_DAYS(CURDATE())) >= 0) ORDER BY dataArrivo ASC" EnableViewState="False">
                                                <SelectParameters>
                                                    <asp:ControlParameter Name="ID" ControlID="tbID" PropertyName="Text" Type="Int32" />
                                                </SelectParameters>
                                            </asp:SqlDataSource>
                                            
                                            <table style="width:100%; color:Black; padding:5px; vertical-align:middle;">
                                                <tr>
                                                    <td colspan="5" style="text-align:center; font-weight:bold; font-size:12pt; background-color:#ededed; padding:10px;">
                                                        Dettagli Arrivi
                                                    </td>
                                                </tr>
                                                <asp:Repeater ID="Repeater_Arrivi" runat="server" DataSourceID="SqlData_Arrivo" EnableViewState="false">
                                                    <ItemTemplate>
                                                        <tr>
                                                            <td>
                                                                <img src="Public/Images/stock_machine.png" alt="" height="30px" />
                                                            </td>
                                                            <td style="background-color:#ededed;">
                                                                Qnt
                                                            </td>
                                                            <td>
                                                                <b style="color:Red;"><%#Eval("Arrivi")%></b>
                                                            </td>
                                                            <td style="background-color:#ededed;">
                                                                Data Arrivo
                                                            </td>
                                                            <td>
                                                                <%#Eval("DataArrivo", "{0:dd/MM/yyyy}")%>
                                                            </td>
                                                        </tr>    
                                                    </ItemTemplate>
                                                </asp:Repeater>
                                            </table>
                                        </div> <!-- end dettagli_arrivi_lightbox -->
                                    </div> <!-- end contenuto_popup -->
                                </p>
                            </td>
                        </tr>
                    </table>
                </a>
            </div>
            <!-- -------------- -->
            
            <br />
            <asp:HyperLink ID="HyperLink1" runat="server" ToolTip="Visualizza tutta la categoria" Font-Size="8pt" 
                NavigateUrl='<%# "articoli.aspx?st="& Eval("SettoriId") &"&ct="& Eval("CategorieID") &"&mr="& Eval("MarcheId") &"&tp="& Eval("TipologieID") &"&gr="& Eval("GruppiID") &"&sg="& Eval("SottogruppiID") %>'
                Text='<%# Eval("SettoriDescrizione") & " <font color=#E12825><b>»</b></font> " & Eval("CategorieDescrizione") & " <font color=#E12825><b>»</b></font> "& Eval("MarcheDescrizione") &" <font color=#E12825><b>»</b></font> "& Eval("TipologieDescrizione") &" <font color=#E12825><b>»</b></font> "& Eval("GruppiDescrizione") &" <font color=#E12825><b>»</b></font> "& Eval("SottogruppiDescrizione") %>'>
            </asp:HyperLink>
            <br /><br />

            <span class="link">
            <!-- Articolo Nuovo -->
            <div class="bg-white">
            
                <!-- Descrizione Prodotto -->
                <div class="container">
                    <div class="row">
                        <div class="col-12" style="border-bottom:1px solid Gray; padding:10px 5px;">
                            <!-- Titolo ARTICOLO -->
                            <div>
                                <asp:Label ID="Label12" CssClass="colore_sito" runat="server" Text=' <%# Eval("MarcheDescrizione") %>' Font-Size="12pt" Font-Bold="true" Height="10px" style="display:inline;"></asp:Label>
                                <asp:HyperLink ID="HyperLink5"  ToolTip="<%# Eval("SettoriDescrizione").toString.Replace("""","''") & " > " &  Eval("CategorieDescrizione").toString.Replace("""","''") & " > " & Eval("MarcheDescrizione").toString.Replace("""","''") & " > " & Eval("TipologieDescrizione").toString.Replace("""","''") & " > " &  Eval("GruppiDescrizione").toString.Replace("""","''") & " > " &  Eval("SottogruppiDescrizione").toString.Replace("""","''") & " > " & Eval("Codice") %>" runat="server" NavigateUrl='<%# "~/articolo.aspx?id="& Eval("id") %>'>
                                    <asp:Label ID="Label8" runat="server" Text='<%# " - " & Eval("Descrizione1") %>' Font-Size="11pt" ForeColor="Gray"></asp:Label>
                                </asp:HyperLink>
                            </div>
                            <!-- FINE Titolo ARTICOLO -->
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-12 col-md-5">

                            <div class="row mt-3">
                                <div class="col-12">

                                    <div class="container">
                                        <div class="row">

                                            <div class="col-12 col-md-5">
                                                <!-- AddThis Button BEGIN -->
                                                <div class="addthis_toolbox addthis_default_style addthis_32x32_style">
                                                    <a class="addthis_button_preferred_1"></a>
                                                    <a class="addthis_button_preferred_2"></a>
                                                    <a class="addthis_button_compact"></a>
                                                    <a class="addthis_counter addthis_bubble_style"></a>
                                                </div>
                                                <script type="text/javascript">var addthis_config = {"data_track_addressbar":true};</script>
                                                <script type="text/javascript" src="//s7.addthis.com/js/300/addthis_widget.js#pubid=ra-52a5f0943d53948f"></script>
                                                <!-- AddThis Button END -->
                                                
                                                <div style="margin-top:0px; width:100%; margin-left:5px; position:relative;"> 
                                                    <div style="position:absolute; right:0px; top:0px;">
                                                        <asp:Image ID="img_promo" runat="server" ImageUrl="~/Public/Images/bollinoPromoVetrina.png" Visible="false" />
                                                    </div>
                                                    <div id="main_view" style="text-align:center; float:right; width:100%; margin: 4rem 0;">
                                                        <a href="#" target="_self">
                                                            <img id="main_img" style="max-height: 100%; max-width: 100%;" src="<%# checkImg(Eval("Img1")) %>" alt="" onclick="nascondi_dettagli_lightbox();" />
                                                        </a>
                                                    </div>

                                                    <div class="thumb" style="width:100%; margin:auto;"> 
                                                        <ul class="thumb" style="overflow:auto; margin:auto; width:100%; border-style:none; padding-top:5px; padding-bottom:5px; border-color:Black; border-width:1px; border-top-style:solid; border-bottom-style:solid;"> 

                                                            <script runat="server">
                                                                ' NUOVA VERSIONE: mantiene le foto reali in /Public/Foto/
                                                                ' ma usa il fallback in /Public/images/nofoto.gif
                                                                Function checkImg(ByVal imgnameObj As Object) As String
                                                                    If IsDBNull(imgnameObj) OrElse imgnameObj Is Nothing Then
                                                                        Return "Public/images/nofoto.gif"
                                                                    End If

                                                                    Dim imgname As String = imgnameObj.ToString().Trim()

                                                                    If imgname <> "" Then
                                                                        ' Percorso attuale reale delle foto articolo
                                                                        Return "Public/Foto/" & imgname
                                                                    Else
                                                                        ' Fallback globale
                                                                        Return "Public/images/nofoto.gif"
                                                                    End If
                                                                End Function
                                                                
                                                                Function controllo_img(ByVal temp As Object) As String
                                                                    If IsDBNull(temp) OrElse temp Is Nothing OrElse temp.ToString() = "" Then
                                                                        Return "false"
                                                                    Else
                                                                        Return "true"
                                                                    End If
                                                                End Function
                                                            </script>

                                                            <li style='float:left; padding:3px;'>
                                                                <table style='width:70px; height:80px; text-align:center; vertical-align:middle;'>
                                                                    <tr>
                                                                        <td>
                                                                            <a href='<%# checkImg(Eval("Img1")) %>'>
                                                                                <img src='<%# checkImg(Eval("Img1")) %>' style='width:40px; max-height:80px;' alt='' />
                                                                            </a>
                                                                        </td>
                                                                    </tr>
                                                                </table>
                                                            </li>

                                                            <%#IIf(Eval("Img2") <> "", 
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img2")) & "'><img src='" & checkImg(Eval("Img2")) & "' style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>",
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img1")) & "'><img src=" & checkImg(Eval("Img1")) & " style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>")%>

                                                            <%#IIf(Eval("Img3") <> "", 
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img3")) & "'><img src='" & checkImg(Eval("Img3")) & "' style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>",
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img1")) & "'><img src=" & checkImg(Eval("Img1")) & " style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>")%>

                                                            <%#IIf(Eval("Img4") <> "", 
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img4")) & "'><img src='" & checkImg(Eval("Img4")) & "' style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>",
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img1")) & "'><img src=" & checkImg(Eval("Img1")) & " style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>")%>

                                                            <%#IIf(Eval("Img5") <> "", 
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img5")) & "'><img src='" & checkImg(Eval("Img5")) & "' style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>",
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img1")) & "'><img src=" & checkImg(Eval("Img1")) & " style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>")%>

                                                            <%#IIf(Eval("Img6") <> "", 
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img6")) & "'><img src='" & checkImg(Eval("Img6")) & "' style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>",
                                                                "<li style='float:left; padding:3px;'><table style='width:70px; height:80px; text-align:center; vertical-align:middle;'><tr><td><a href='" & checkImg(Eval("Img1")) & "'><img src=" & checkImg(Eval("Img1")) & " style='width:40px; max-height:80px;' alt='' /></a></td></tr></table></li>")%>

                                                        </ul> 
                                                    </div>          
                                                </div>
                                            </div>
                                            
                                            <div class="col-12 col-md-7">
                                                <div style="width:100%; overflow:hidden;">
                                                    <!-- Marca -->
                                                    <li style="list-style:none; text-align:center;">
                                                        <img style="height:50px; max-width:300px;" 
                                                             alt='<%# Eval("MarcheDescrizione") %>' 
                                                             src='<%# Eval("Marche_img", "Public/Marche/{0}") %>' 
                                                             visible='<%# controllo_img(Eval("Marche_img")) %>' />
                                                    </li>
                                                    
                                                    <!-- Icone Operazioni -->
                                                    <div style="width:100%; height:40px; text-align:center; padding-bottom:20px;">
                                                        <img src="Images/refurbished.png" title="Articolo ricondizionato" alt="" style="visibility:<%# Eval("refurbished")%>" /> 
                                                        <asp:HyperLink ID="Stampa_link" runat="server" Font-Bold="True" ForeColor="Navy" ImageUrl="Images/print.png" NavigateUrl='<%# "vers_stampabile.aspx?id=" & cod_articolo() %>' ToolTip="Versione Stampabile" Target="_blank" ></asp:HyperLink>
                                                        <a href="<%# IIf(controlla_brochure(Eval("Brochure"))=0,"",Eval("Brochure")) %>" style="display:<%# IIf(controlla_brochure(Eval("Brochure"))=0,"none","") %>;" target="_blank"><img src="Images/pdf.png" alt="" /></a>
                                                        <a href="<%# IIf(controlla_link_produttore(Eval("LinkProduttore"))=0,"",Eval("LinkProduttore")) %>" style="display:<%# IIf(controlla_link_produttore(Eval("LinkProduttore"))=0,"none","") %>;" target="_blank"><img src="Images/link.png" alt="" /></a>
                                                        <asp:Image ID="img_offerta" runat="server" ImageUrl="~/Images/promo.png" Visible="false" Height="40px"/>
                                                        <img src="Images/spedizione_gratis.png" alt="" title='Questo articolo verrà spedito GRATIS !!! fino al <%# Eval("SpedizioneGratis_Data_Fine","{0:d}") %>' style="width:40px; <%# IIf(Eval("SpeditoGratis")=1,"","display:none;") %>" />
                                                        <input id="SpeditoGratis" runat="server" value='<%# IIf(Eval("SpeditoGratis")=1,"1","0") %>' visible="false" />
                                                    </div>

                                                    <div class="row mt-3">
                                                        <div class="col-12 text-center">
                                                            <asp:DropDownList ID="Drop_Tagliecolori" style="text-align:center" runat="server" Width="280px" AutoPostBack="True" BackColor="#FFFF80" Font-Bold="False" Font-Size="10pt" ForeColor="Black" OnSelectedIndexChanged="Drop_Tagliecolori_SelectedIndexChanged">
                                                            </asp:DropDownList>
                                                        </div>
                                                    </div>
                                                    <br />

                                                    <table style="vertical-align:top; margin:0 auto;">
                                                        <tr>
                                                            <td style="vertical-align:top;">
                                                                <table>
                                                                    <tr>
                                                                        <td><b>Codice</b></td>
                                                                        <td><asp:Label ID="Label22" runat="server" Text='<%# Bind("codice") %>'></asp:Label></td>
                                                                    </tr>
                                                                    <tr>
                                                                        <td><b>EAN</b></td>
                                                                        <td><asp:Label ID="Label21" runat="server" Text='<%# Bind("ean") %>'></asp:Label></td>
                                                                    </tr>
                                                                    <tr>
                                                                        <td><b>Visite</b></td>
                                                                        <td><asp:Label ID="Label2" runat="server" Text='<%# Bind("Visite") %>'></asp:Label></td>
                                                                    </tr>
                                                                </table>
                                                            </td>
                                                            <td style="vertical-align:top;padding-left: 2rem;">
                                                                <!-- Numeri -->
                                                                <table>
                                                                    <tr>
                                                                        <td><b>Disponibilità </b></td>
                                                                        <td>
                                                                            <asp:Image ID="imgDispo" runat="server" />
                                                                            <asp:Label ID="lblDispo" runat="server" ForeColor="Red" Text='<%# Eval("Giacenza") %>'></asp:Label>
                                                                        </td>
                                                                    </tr>
                                                                    <tr>
                                                                        <td><b>Impegnati </b></td>
                                                                        <td>
                                                                            <asp:Label ID="lblImpegnata" ForeColor="Red" runat="server" Text='<%# Eval("Impegnata") %>'></asp:Label>
                                                                        </td>
                                                                    </tr>
                                                                    <tr>
                                                                        <td>
                                                                            <%# 
                                                                            IIf(
                                                                                Eval("arrivi").Equals(DBNull.Value),
                                                                                IIf(
                                                                                    Eval("tempiconsegnadescrizione").Equals(DBNull.Value),
                                                                                    "<b>In Arrivo:</b>", 
                                                                                    "<a href='#' style='color:#333333;text-decoration:none;' data-placement='bottom' data-toggle='tooltip' data-html='true' title='<p style=&quot;margin-bottom:unset; text-align:justify;&quot;>Il tempo di consegna indicativo &egrave; di " & Eval("tempiconsegnadescrizione") & " dalla data di inserimento del tuo ordine. </p><p style=&quot;background-color:#FFFF66;margin-bottom:unset; text-align:left;&quot;><strong>Nota</strong></p><p style=&quot;margin-bottom:unset; text-align:justify;&quot;>Le date di arrivo merce sono indicative. L&#39;effettiva consegna presso i ns. magazzini potrebbe essere prorogata senza alcun preavviso a causa di eventi esterni. Non siamo in alcun modo responsabili per eventuali ritardi rispetto alle previsioni di arrivo ivi indicate.</p>' onclick='return false'><b><u>In Arrivo:</u></b></a>"
                                                                                ),
                                                                                "<a href='#' style='color:#333333;text-decoration:none;' data-placement='bottom' data-toggle='tooltip' data-html='true' title='<p style=&quot;margin-bottom:unset; text-align:justify;&quot;>La merce &egrave; in produzione. I nostri fornitori prevedono di consegnare il:</p><br/>" & Eval("arrivi") & "<br/><p style=&quot;background-color:#FFFF66;margin-bottom:unset; text-align:left;&quot;><strong>Nota</strong></p><p style=&quot;margin-bottom:unset; text-align:justify;&quot;>Le date di arrivo merce sono indicative. L&#39;effettiva consegna presso i ns. magazzini potrebbe essere prorogata senza alcun preavviso a causa di eventi esterni. Non siamo in alcun modo responsabili per eventuali ritardi rispetto alle previsioni di arrivo ivi indicate.</p>' onclick='return false'><b><u>In Arrivo:</u></b></a>"
                                                                            )
                                                                            %>
                                                                        </td>
                                                                        <td>
                                                                            <asp:Label ID="lblArrivo" ForeColor="Red" runat="server" Text='<%# Eval("InOrdine") %>'></asp:Label>
                                                                        </td>
                                                                    </tr>
                                                                </table>
                                                             </td>
                                                        </tr>
                                                        <tr>
                                                            <td colspan="2">
                                                                <%#IIf(Eval("Giacenza") > 0, "<b style=""color:Green; font-size:16pt;"">Disponibile</b>", "<b style=""color:red; font-size:16pt;"">Non Disponibile</b>")%>       
                                                            </td>
                                                        </tr>
                                                    </table>
                                                    
                                                    <ul class="mt-3" style="list-style-type:square; font-size:9pt; line-height:20px;">
                                                        <li><b>Garanzia </b><asp:Label ID="Label10" Font-Size="8pt" runat="server" Text='<%# IIf(controlla_garanzia(Eval("Mesi"))=0,"nessuna informazione",Eval("Mesi") & " mesi") %>'></asp:Label></li>
                                                        <li><b>Peso </b><asp:Label ID="Label_Val_Peso" runat="server" Text='<%# Bind("Peso") %>'></asp:Label> Kg</li>
                                                        <li style="padding-bottom:10px;"><b>Spedizione</b>
                                                            <ul id="Spedizioni" style="list-style-type:none; width:100%; font-size:8pt; line-height:15px; padding-left:5px;">
                                                                <asp:DataList ID="DataList1" runat="server" DataSourceID="sdsVettori" Width="100%">
                                                                    <ItemTemplate>
                                                                        <li>
                                                                            <div style="margin:0px; width:100%; text-align:right; display:block;">
                                                                                <table style="width:98%; background-color:#ededed; vertical-align:middle;">
                                                                                    <tr style="padding-right:2%;">
                                                                                        <td style="background-color:White; padding:3px; text-align:left; width:50px; height:20px;display:<%#IIf(IsDBNull(Eval("Img")), "none", "")%>;">
                                                                                            <asp:Image ID="Image1" runat="server" ImageUrl='<%# "Public/Vettori/" & Eval("Img") %>' ToolTip='<%# Eval("informazioni") %>' Visible='<%#IIf(IsDBNull(Eval("Img")), "false", "true")%>' />
                                                                                        </td>
                                                                                        <td style="padding:3px; text-align:right;">
                                                                                            <asp:Label ID="Label1" runat="server" Font-Names="Arial" Font-Size="8pt" Text='<%# Eval("Descrizione") %>'></asp:Label> 
                                                                                            <b style="color:Red;">
                                                                                                <asp:Label ID="Label7" runat="server" Font-Names="Arial" Font-Size="8pt" Text='<%# IIf(controlla_iva_spedizione()=2,String.Format("{0:c}", Eval("CostoFisso")*((Session("Iva_Vettori")/100)+1)),String.Format("{0:c}", (Eval("CostoFisso")))) %>'></asp:Label>
                                                                                            </b>        
                                                                                        </td>
                                                                                    </tr>
                                                                                </table>
                                                                            </div>
                                                                        </li>
                                                                    </ItemTemplate>
                                                                </asp:DataList>
                                                            </ul>
                                                        </li>
                                                    </ul>
                                                    
                                                    <!-- Prezzi -->
                                                    <table style="width:100%; text-align:right;">
                                                        <tr>
                                                            <td style="font-size:8pt;"></td>
                                                            <td>Prezzo di Listino 
                                                                <b><asp:Label ID="Label_LU" runat="server" Text='<%# valore_LU(Eval("ListinoUfficiale"),Eval("ValoreIva")) %>' Width="100px"></asp:Label></b>
                                                            </td>
                                                        </tr>
                                                        <asp:Panel ID="Panel_in_offerta" runat="server" Height="15px" Visible="False" style="text-align:right; float:right; font-size:9pt;">            
                                                            <tr>
                                                                <td style="font-size:8pt;"></td>
                                                                <td>Prezzo Standard 
                                                                    <asp:Label ID="Label_Canc_PrezzoIvato" runat="server" Text='<%# Bind("PrezzoIvato", "{0:C}") %>' ForeColor="black" Width="100px" style="text-decoration:line-through;"></asp:Label>
                                                                    <asp:Label ID="Label_Canc_Prezzo" runat="server" Text='<%# Bind("Prezzo", "{0:C}") %>' Visible="False" ForeColor="black" style="text-decoration:line-through; text-align:right;"></asp:Label>
                                                                </td>
                                                            </tr>
                                                        </asp:Panel>
                                                        <tr>
                                                            <td colspan="2">
                                                                <asp:Label ID="lblPrezzoPromo" runat="server" Font-Bold="True" Font-Size="12pt" ForeColor="#E12825" Text='<%# Bind("Prezzo","{0:C}") %>' Visible="False" style="text-align:right"></asp:Label>
                                                                <asp:Label ID="lblPrezzoIvato" CssClass="colore_sito" runat="server" Text='<%# Bind("PrezzoIvato","{0:C}") %>' Font-Bold="True" Font-Size="22pt" style="text-align:right" Visible="False"></asp:Label>
                                                                <asp:Label ID="lblPrezzo" CssClass="colore_sito" runat="server" Font-Bold="True" Font-Size="22pt" Text='<%# Bind("Prezzo","{0:C}") %>' Visible="False" style="text-align:right"></asp:Label>
                                                                <asp:Label ID="lblID" runat="server" Text='<%# Bind("ID") %>' Visible="false"></asp:Label>
                                                                <br />
                                                                <asp:Label ID="lblPrezzoDes" runat="server" Text="Prezzo" Font-Names="arial" Font-Size="7pt" style="text-align:left;"></asp:Label>
                                                                
                                                                <script runat="server">
                                                                    Function controlla_abilitazione_iva_rc(ByVal utente_abilitato_reverse_charge As Integer, ByVal idIvaRC_articolo As Integer) As String
                                                                        If (utente_abilitato_reverse_charge = 1) AndAlso (idIvaRC_articolo <> -1) Then
                                                                            Return ""
                                                                        Else
                                                                            Return "none"
                                                                        End If
                                                                    End Function
                                                                </script>
                                                                <div style="color:red; font-size:7pt; display:<%# controlla_abilitazione_iva_rc(Session("AbilitatoIvaReverseCharge"),Eval("IdIvaRC")) %>;">
                                                                    REVERSE CHARGE. <%#Eval("DescrizioneIvaRC")%>
                                                                </div>  
                                                            </td>
                                                        </tr>
                                                    </table>
                                                    
                                                    <!-- PROMO -->
                                                    <asp:SqlDataSource ID="sdsPromo" runat="server" 
                                                        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
                                                        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                                                        SelectCommand="SELECT * FROM vsuperarticoli WHERE ID=?ID AND NListino=?NListino ORDER BY PrezzoPromo DESC" EnableViewState="False">
                                                        <SelectParameters>
                                                            <asp:ControlParameter Name="ID" ControlID="tbID" PropertyName="Text" Type="Int32" />
                                                            <asp:SessionParameter Name="NListino" SessionField="listino" Type="Int32" />
                                                        </SelectParameters>
                                                    </asp:SqlDataSource>  
                                                    
                                                    <script runat="server">
                                                        Function visualizza_promo(ByVal temp As Integer) As String
                                                            If temp = 1 Then
                                                                Return ""
                                                            Else
                                                                Return "none"
                                                            End If
                                                        End Function
                                                    </script>
                                                    
                                                    <asp:Repeater ID="rPromo" runat="server" DataSourceID="sdsPromo" EnableViewState="false" OnItemDataBound="rPromo_ItemDataBound">
                                                        <ItemTemplate>
                                                            <div class="row">
                                                                <div class="col-12">
                                                                    <table style="width:300px; background-color:#ededed; float:right;">
                                                                        <tr>
                                                                            <td style="width:120px; text-align:left;">
                                                                                <%#IIf(Eval("OfferteQntMinima") > 0, "<img src=""Public/Images/Promo/quantita.jpg"" height=""20px"" title=""Quantità Minima"" />", "<img src=""Public/Images/Promo/multiplo.jpg"" height=""20px"" title=""Quantità Multipla"" />")%>
                                                                            </td>
                                                                            <td style="text-align:right; width:50px;">
                                                                                <%#IIf(Eval("OfferteQntMinima") > 0, "<b>" & Eval("OfferteQntMinima") & "</b> PZ.", "<b>" & Eval("OfferteMultipli") & "</b> PZ.")%>
                                                                            </td>
                                                                            <td style="text-align:right;">
                                                                                <%#IIf(IvaTipo = 1, "€ " & FormatNumber(Eval("PrezzoPromo"), 2), "€ <b>" & FormatNumber(Eval("PrezzoPromoIvato"), 2) & "</b>")%>
                                                                            </td>
                                                                        </tr>
                                                                        <tr>
                                                                            <td colspan="3" style="background-color:White; font-size:8pt; text-align:right;">
                                                                                <%#"<b>dal </b>" & Eval("OfferteDataInizio") & " <b>al </b> " & Eval("OfferteDataFine")%>
                                                                            </td>
                                                                        </tr>
                                                                    </table>
                                                                    
                                                                    <table style="width:300px; display:none; float:right;" cellspacing="0">
                                                                        <tr>
                                                                            <td style="background-color:#dcdcdc; text-align:left;">
                                                                                <asp:Label ID="lblQtaMin" runat="server" Text='<%# Eval("OfferteQntMinima") %>' Visible="false"></asp:Label>
                                                                                <asp:Label ID="lblMultipli" runat="server" Text='<%# Eval("OfferteMultipli") %>' Visible="false"></asp:Label>                                      
                                                                                <asp:Label ID="lblOfferta" runat="server"  Visible='<%# Eval("InOfferta")%>' Font-Size="7pt" Text='<%# "<b style=""color:green;"">DAL </b>" & Eval("OfferteDataInizio") & " <b style=""color:red;"">AL </b> " & Eval("OfferteDataFine") %>' ForeColor="white"></asp:Label>
                                                                            </td>
                                                                            <td>
                                                                                <asp:Label ID="lblPrezzoPromo" runat="server" Text='<%# Eval("PrezzoPromo") %>' Visible="false" Font-Bold="true"></asp:Label>
                                                                                <asp:Label ID="lblPrezzoPromoIvato" runat="server" Text='<%# Eval("PrezzoPromoIvato") %>' Visible="false" Font-Bold="true"></asp:Label>
                                                                                <asp:Label ID="lblInOfferta" runat="server" Text='<%# Eval("InOfferta") %>' Visible="false"></asp:Label>
                                                                            </td>
                                                                        </tr>
                                                                    </table>
                                                                </div>
                                                            </div>
                                                        </ItemTemplate>
                                                    </asp:Repeater>
                                                    
                                                    <!-- Sconto Evidenziato -->
                                                    <asp:Panel ID="Panel_Visualizza_Percentuale_Sconto" runat="server" Width="100%" Visible="false" style="float:right;">
                                                        <table style="width:300px; background-color:#ededed; text-align:center; float:right;">
                                                            <tr>
                                                                <td style="width:120px; text-align:left;">
                                                                    <img src="Public/Images/Promo/sconto.jpg" height="20px" title="Sconto Applicato" alt="" />
                                                                </td>
                                                                <td style="padding:2px;">
                                                                    <asp:Label ID="sconto_applicato" runat="server" Text="" ForeColor="red" Font-Size="14pt" Font-Bold="true"></asp:Label>
                                                                </td>
                                                            </tr>
                                                        </table>
                                                    </asp:Panel>
                                                </div>

                                                <div class="my-3" style="float: right">
                                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbQuantita"  Display="Dynamic" ErrorMessage="!" SetFocusOnError="True"></asp:RequiredFieldValidator>
                                                    <asp:CompareValidator ID="CompareValidator2" runat="server" ControlToValidate="tbQuantita" Display="Dynamic"  ErrorMessage="!" Operator="GreaterThan" SetFocusOnError="True"  Type="Integer" ValueToCompare="0"></asp:CompareValidator>
                                                    
                                                    <div class="d-flex">
                                                        <div class="d-flex" style="height:37px;background-color: lightgray; text-align: center; vertical-align: middle;line-height: 21px;margin:auto; margin-right:3px ">
                                                            <i data-qty-action="decrementQty" style="color: #383838;font-size:16px;" class="fa fa-minus-circle fa-2x align-self-center mx-1"></i>
                                                            <asp:TextBox ID="tbQuantita" runat="server" Width="50px" style="text-align:center;font-weight: bold;" MaxLength="4" Pattern="\d*">1</asp:TextBox>
                                                            <i data-qty-action="incrementQty" style="color: #383838;font-size:16px;" class="fa fa-plus-circle fa-2x align-self-center mx-1"></i>									   
                                                        </div>								   
                                            
                                                        <div class="d-flex" style="position: relative;">
                                                            <div style="background-image: url(../../Images/back_menu.png);<%# IIf (Eval("Giacenza") > 0,"background-color: #70db10;" ,"background-color: #e02020;") %>; color: white; position: absolute;height:37px; width:180px; text-align: center; vertical-align: middle;line-height: 37px; font-size: 13px; font-weight: bold;">
                                                                <i class="fas fa-cart-plus" style="font-size: 16px;"></i>&nbsp;&nbsp;Aggiungi al carrello
                                                            </div>
                                                            <div style="z-index: 10;height:37px; width:180px;">
                                                                <asp:ImageButton ID="ImageButton2" style="border: none;height:37px; width:180px;" runat="server" ImageUrl="Public/Images/spazio_vuoto.gif" ToolTip="Aggiungi al Carrello" OnClick="ImageButton1_Click" />
                                                            </div>
                                                        </div>
                                                    </div>
                                                    
                                                    <div>
                                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator1" runat="server" ControlToValidate="tbQuantita" Display="Dynamic" ErrorMessage="Inserire una Quantità Valida" SetFocusOnError="True"></asp:RequiredFieldValidator>
                                                        <asp:CompareValidator ID="CompareValidator1" runat="server" ControlToValidate="tbQuantita" Display="Dynamic" ErrorMessage="Inserire una Quantità Valida" Operator="GreaterThan" SetFocusOnError="True" Type="Integer" ValueToCompare="0"></asp:CompareValidator>
                                                    </div> 
                                                </div>

                                                <script runat="server">
                                                    Function cod_articolo() As String
                                                        Return Request.QueryString("id")
                                                    End Function
                                                </script>
                                            </div>
                                        </div>
                                    </div>

                                </div>
                            </div>        
                        </div>
                    </div>
                </div> <!-- fine container -->
            </div> <!-- fine bg-white -->
            </span>

            <div style="display:none;">
                <asp:SqlDataSource ID="sdsVettori" runat="server" 
                    ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT vvettoricosti.Ordinamento, vvettoricosti.Informazioni, vvettoricosti.Descrizione, vvettoricosti.id, vvettoricosti.Abilitato, vvettoricosti.Web, vvettoricosti.Predefinito, vvettoricosti.AssicurazionePercentuale, vvettoricosti.AssicurazioneMinimo, vvettoricosti.ContrassegnoPercentuale, vvettoricosti.ContrassegnoFisso, vvettoricosti.ContrassegnoMinimo, vvettoricosti.Img, MIN(vvettoricosti.PesoMax) AS PesoMax, MIN(vvettoricosti.CostoFisso) AS CostoFisso FROM vvettoricosti INNER JOIN vettoricosti ON vvettoricosti.id = vettoricosti.VettoriId WHERE (vvettoricosti.Abilitato = 1) AND (vvettoricosti.Web = 1) AND (vvettoricosti.PesoMax >= @Peso) AND (vvettoricosti.AziendeId = @AziendaId) AND (vettoricosti.Soglia_Minima <= 0) GROUP BY vvettoricosti.Ordinamento, vvettoricosti.Descrizione, vvettoricosti.id, vvettoricosti.Abilitato, vvettoricosti.Web, vvettoricosti.Predefinito, vvettoricosti.AssicurazionePercentuale, vvettoricosti.ContrassegnoPercentuale, vvettoricosti.ContrassegnoFisso HAVING (vvettoricosti.id >= 0)">
                    <SelectParameters>
                        <asp:ControlParameter ControlID="Label_Val_Peso" Name="Peso" PropertyName="Text" Type="Double" />
                        <asp:SessionParameter Name="AziendaID" SessionField="AziendaID" />
                    </SelectParameters>
                </asp:SqlDataSource>
                        
                <asp:TextBox ID="tbID" runat="server" Text='<%# Eval("ID") %>' Width="30" EnableViewState="false" Visible="false"></asp:TextBox>
            </div>
            
            <script runat="server">
                Function convalida_stringa(ByVal temp As String) As String
                    If IsDBNull(temp) Then
                        Return ""
                    End If
                    temp = Server.HtmlEncode(temp)
                    Return temp.Replace("&#160;", " ").Replace("&lt;", "<").Replace("&gt;", ">").Replace("&quot;", """")
                End Function
                    
                Function convalida_stringa_html(ByVal temp As String) As String
                    If IsDBNull(temp) Then
                        Return ""
                    End If
                    temp = Server.HtmlDecode(temp)
                    Return temp.Replace("&#160;", " ").Replace("&lt;", "<").Replace("&gt;", ">").Replace("&quot;", """")
                End Function
                    
                Function visualizza_descr_lunga(ByVal descr_html As String) As String
                    If (IsDBNull(descr_html) OrElse (descr_html = "")) Then
                        Return "True"
                    Else
                        Return "False"
                    End If
                End Function
            </script>
            
            <!-- Menu TAB -->
            <div class="bg-white" style="width:100%; padding-top:0px; overflow:auto; height:auto; color:White; font-weight:bold; font-size:8pt; border-bottom-style:solid; border-bottom-width:2px; border-color:Gray;">
                <div id="infobar" style="text-align:left; float:left; width:148px; height:33px; background-image:url('Images/tab.png'); background-repeat:no-repeat; background-position:top left; z-index:1;">
                    <div style="margin-left:28px; margin-top:12px; overflow:auto;">
                        <asp:LinkButton ID="LB_Dettagli" ForeColor="white" runat="server" OnClick="LB_Dettagli_Click" CausesValidation="False">DETTAGLI</asp:LinkButton>
                    </div>
                </div>
                <div id="infobar" style="text-align:left; float:left; width:148px; height:33px; background-image:url('Images/tab.png'); background-repeat:no-repeat; background-position:top left; z-index:2; margin-left:-25px;">
                    <div style="margin-left:13px; margin-top:12px; overflow:auto;">
                        <asp:LinkButton ID="LB_ArtCollegati" ForeColor="white" runat="server" OnClick="LB_ArtCollegati_Click" CausesValidation="False">ART. CORRELATI</asp:LinkButton>
                    </div>
                </div>
                <div id="infobar" style="text-align:left; float:left; width:148px; height:33px; background-image:url('Images/tab.png'); background-repeat:no-repeat; background-position:top left; z-index:2; margin-left:-25px;">
                    <div style="margin-left:25px; margin-top:12px; overflow:auto;">
                        <asp:LinkButton ID="LB_Recensioni" ForeColor="white" runat="server" OnClick="LB_Recensioni_Click" CausesValidation="False">IN PROMO</asp:LinkButton>
                    </div>
                </div>
				<div id="infobar" style="text-align:left; float:left; width:148px; height:33px; background-image:url('Images/tab.png'); background-repeat:no-repeat; background-position:top left; z-index:2; margin-left:-25px;">
                    <div style="margin-left:25px; margin-top:12px; overflow:auto;">
                        <asp:LinkButton ID="LB_NormeGaranzia" ForeColor="white" runat="server" OnClick="LB_NormeGaranzia_Click" CausesValidation="False">GARANZIA</asp:LinkButton>
                    </div>
                </div>
            </div>

            <div class="bg-white w-100" style="overflow:hidden;">
                <asp:MultiView ID="Multi_Vista" runat="server" ActiveViewIndex="0">
                    <asp:View ID="Tab1" runat="server">
                        <div class="p-3" style="overflow:auto;">
                            <asp:Label ID="lblDescrizioneArt" runat="server" Text='<%# convalida_stringa(Eval("DescrizioneLunga")) %>' Visible='<%# visualizza_descr_lunga(Eval("DescrizioneHTML")) %>' Font-Size="12px"></asp:Label>
                            <asp:Label ID="lblDescrizioneHTMLArt" runat="server" Text='<%# convalida_stringa(Eval("DescrizioneHTML")) %>' Font-Size="12px"></asp:Label>
                        </div>
                    </asp:View>
                    <asp:View ID="Tab2" runat="server">
                        <div style="overflow:auto; padding-top:10px; padding-bottom:10px;">
                            Funzionalità in fase di progettazione
                        </div>
                    </asp:View>
                    <asp:View ID="Tab3" runat="server">
                        <div style="overflow:auto; padding-top:10px; padding-bottom:10px;"></div>
                    </asp:View>
					<asp:View ID="Tab4" runat="server">
                        <div class="p-3" style="overflow:auto;">
							<asp:Label ID="lblNormeGaranzia" runat="server" Text='<%# Eval("NoteRicondizionato")%>' Font-Size="12px"></asp:Label>
						</div>
                    </asp:View>
               </asp:MultiView>
           </div>

           <div class="fb-comments" data-href='<%= Request.url.AbsoluteUri %>' data-width="660px" data-numposts="5" data-colorscheme="light" style="margin-top:10px; border-top:1px solid gray;"></div>

        </ItemTemplate>
    </asp:FormView>
</div> <!-- fine container-fluid bg-white home-box-position mt-3 bg-shadow -->

</asp:Content>
