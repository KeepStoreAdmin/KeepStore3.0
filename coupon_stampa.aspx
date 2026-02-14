<%@ Page Language="VB" AutoEventWireup="false" CodeFile="coupon_stampa.aspx.vb" Inherits="coupon_stampa" %>

<%@ Import Namespace="System.Drawing" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Stampa il tuo Coupon</title>
    
    <style type="text/css">
        #tab td
        {
            border-style:none;
            border-width:0px;	
        }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <asp:DataList ID="Stampa_coupon" runat="server" DataSourceID="SqlData_CouponInserzioni" style="margin:auto;">
            <ItemTemplate>
                <table id="tab" style=" font-family:Arial; width:700px; padding:10px; border-style:solid; border-width:2px; border-color:Black; font-size:11pt;" cellpadding="0px" cellspacing="0px" border="collapse">
                    <tr>
                        <td style="height:30px; text-align:left; font-size:18pt; font-weight:bold;">
                            Coupon
                        </td>
                    </tr>
                    <tr>
                        <td style="text-align:right; font-size:11pt; padding-bottom:10px;">
                            <div style=" float:left;">
                                <% If Session("AziendaID") = 1 Then%>
                                    <img src="Images/Coupon/loghi/coupon_entropic.png" alt="" />
                                <%Else%>
                                    <img src="Images/Coupon/loghi/coupon_webaffare.png" alt="" />
                                <%End If%>
                            </div>
                            <b>Codice Controllo</b><br />
                            <%#Eval("cod_controllo")%>
                        </td>
                    </tr>
                    <tr>
                        <td style=" font-style:italic; color:Red; text-align:right; font-size:9pt; padding-bottom:10px;">
                            Acquistato il <%#Eval("DataInserimento")%>
                        </td>
                    </tr>
                    <tr>
                        <td style=" height:1px; border-color:Black; border-width:2px; border-style:solid;">
                        </td>
                    </tr>
                    <tr>
                        <td style="text-align:center; padding-top:10px;">
                            <div style="float:left; width:460px; height:200px; overflow:hidden;"><img style="width:100%;" src='public/Coupon/img_coupon/<%#Eval("Img")%>')' alt="" /></div>
                            <div style="float:right; text-align:right;">
                                <span style=" font-style:italic; font-size:9pt;">Presso</span><br /><br />
                                <b><%#Eval("RagioneSociale")%></b><br />
                                <%#Eval("Cognome")%> <%#Eval("Nome")%><br />
                                <%#Eval("Via")%><br />
                                <%#Eval("Citta")%> (<%#Eval("Provincia")%>)<br />
                                <%#Eval("CAP")%><br />
                                <%#Eval("Telefono") %> - <%#Eval("Fax")%><br />
                                <a href='<%# "http://" & Eval("SitoWeb")%>'><%#Eval("SitoWeb")%></a>
                            </div>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding-top:10px; padding-bottom:10px;">
                            <%#Eval("Titolo")%>
                        </td>
                    </tr>
                    <tr>
                        <td style=" height:1px; border-color:Black; border-width:2px; border-style:solid;">
                        </td>
                    </tr>
                    <tr>
                        <td style="font-weight:bold; font-size:12pt; padding-top:10px; text-decoration:underline;">
                            Descrizione Coupon Acquistato
                        </td>
                    </tr>
                    <tr>
                        <td style="padding-top:5px; padding-bottom:5px;">
                            <%#Eval("qnt_coupon") & "x " & Eval("Descrizione")%>
                        </td>
                    </tr>
                    <tr>
                        <td style="font-weight:bold; font-size:12pt; text-decoration:underline;">
                            Sintesi
                        </td>
                    </tr>
                    <tr>
                        <td style="padding-top:5px; padding-bottom:5px;">
                            <%#Eval("Sintesi")%>
                        </td>
                    </tr>
                   <tr>
                        <td style="font-weight:bold; font-size:12pt; text-decoration:underline;">
                            Condizioni
                        </td>
                    </tr>
                    <tr>
                        <td style="padding-top:5px; padding-bottom:5px;">
                            <%#Eval("Condizioni")%>
                        </td>
                    </tr>
                    <tr>
                        <td style="font-weight:bold; font-size:9pt; text-align:right; padding-top:30px;">
                            Totale
                        </td>
                    </tr>
                    <tr>
                        <td style="padding-top:5px; padding-bottom:5px; text-align:right; font-size:25pt; font-weight:bold;">
                            <%#String.Format("{0:c}", Eval("prezzo"))%>
                        </td>
                    </tr>
                    <tr>
                        <td style=" font-style:italic; text-align:center; padding-top:5px; padding-bottom:2px; font-size:9pt;">
                            Assistenza clienti - <%=Session("AziendaEmail")%>
                        </td>
                    </tr>                
                </table>
            </ItemTemplate>
       </asp:DataList>
    </form>
    
    <asp:SqlDataSource ID="SqlData_CouponInserzioni" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
    SelectCommand="SELECT * FROM coupon_inserzione"></asp:SqlDataSource>
</body>
</html>
