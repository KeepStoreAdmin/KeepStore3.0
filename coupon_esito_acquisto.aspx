<%@ Page Language="VB" MasterPageFile="~/Coupon.master" AutoEventWireup="false" CodeFile="coupon_esito_acquisto.aspx.vb" Inherits="coupon_esito_acquisto" title="Pagina senza titolo" %>

<%@ Import Namespace="System.IO" %>

<asp:Content ID="Content1" ContentPlaceHolderID="Contentplaceholder1" Runat="Server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
<asp:DataList ID="Esito_pagamento_coupon" runat="server" DataSourceID="SqlData_Coupon" style="margin:auto;">
        <ItemTemplate>
            <div style="margin:auto; margin-top:20px; position:relative; width:500px; height:200px; border-color:Black; border-width:1px; border-style:solid;">
                <div style="position:absolute; top:10px; left:20px; font-size:20pt; font-weight:bold;">
                    COUPON
                    <div style="font-size:10pt;">
                        <%#IIf(Eval("StatoPagamento") = 1, "Complimenti il suo pagamento è stato accettato.<br/>Il coupon è stato validato.", "Il suo pagamento non è stato accettato.<br/>Il coupon non è stato validato.")%>
                    </div>
                </div>
                <div style="position:absolute; left:0px; top:135px; width:100px; height:60px;">
                    <table style="width:100%; height:100%; vertical-align:middle; text-align:center;">
                        <tr>
                            <td style=" padding-right:20px; font-weight:bold;">
                                <img src='<%#IIf(Eval("StatoPagamento") = 1, "Images/Coupon/ok.png", "Images/Coupon/no.png")%>' alt="" />
                            </td>
                       </tr>
                    </table>
                </div>
                <div style="position:absolute; right:15px; top:-2px; font-size:70pt; color:red; text-align:right;">
                    <table style=" width:100%; height:100%; vertical-align:middle;">
                        <tr>
                            <td style="font-weight:bold; text-shadow:rgb(214, 214, 214) 0.05em 0.05em 0.05em">
                                <w style="font-size:50pt;">x</w><%#Eval("qnt_coupon")%>
                            </td>
                        </tr>
                    </table>
                </div>
                <div style="position:absolute; right:10px; top:135px; width:400px; height:60px; font-size:11pt; color:Black; text-align:right; border-top-color:Black; border-top-style:solid; border-top-width:1px;">
                    <table style=" width:100%; height:100%; vertical-align:middle;">
                        <tr>
                            <td style="padding-right:10px; font-weight:bold; font-size:13pt;">
                                <%#Eval("cod_controllo").ToString.ToUpper%>
                            </td>
                        </tr>
                    </table>
                </div>
            </div>
                
            <script runat="server">
                Function genera_qrcode(ByVal stringa As String, ByVal dimensione As Integer, ByVal folder As String) As String
                    'Controllo se la cartella temporanea di salvataggio esiste oppure devo crearla
                    If Directory.Exists(Server.MapPath("./") & folder) = False Then
                        Directory.CreateDirectory(Server.MapPath("./") & folder)
                    End If
                    
                    Dim fileList As String() = Directory.GetFiles(Server.MapPath("./") & folder, "*.*")
                    
                    'Elimino tutti i file nella cartella temporanea
                    For Each f As String In fileList
                        File.Delete(f)
                    Next
                    
                    Dim fn As String = stringa & "_" & String.Format("{0:MMddyyhhmmss}", DateTime.Now()) & ".png"

                    Try
                        Dim client As New System.Net.WebClient
                        client.DownloadFile("http://chart.apis.google.com/chart?cht=qr&chs=" & dimensione & "x" & dimensione & "&chl=" & stringa, Server.MapPath("./") & folder & "/" & fn)
                        client = Nothing
                    Catch ex As Exception
                        'Return immagine negativa (QrCode non generato)
                        Return "<img src='Immagini/No_Image.jpg' alt=''>"
                    End Try

                    'I have an <asp:label> on my form so I can quickly test if the file downloaded.
                    Return "<img src='" & folder & "/" & fn & "' alt=''>"
                End Function
            </script>
            
            <!-- <img src="barcode.ashx?barcode=123456" alt="" /> -->
            
            <div style="width:500px; padding-top:10px; overflow:auto; display:<%#IIf(Eval("StatoPagamento") = 1, "", "none")%>;">
                <a href='<%# "coupon_stampa.aspx?id=" & Request.QueryString("id") & "&cod=" & Eval("cod_controllo") %>' style="font-weight:bold; color:Gray;" target="_blank">Clicca qui</a> per stampare il coupon.
            </div>
            
            <div style="width:500px; padding-top:10px; overflow:auto; display:<%#IIf(Eval("StatoPagamento") = 1, "", "none")%>;">
                Il pagamento è stato eseguito correttamente
                
                <br /><br />Vedi tutti i Coupon acquistati, <a href="./coupon_utente.aspx?t=<%= Session("IdDocumentoCoupon") %>"><b>cliccando qui</b></a>
            </div>
            
            <div style="width:500px; padding-top:10px; overflow:auto; display:<%#IIf(Eval("StatoPagamento") = 0, "", "none")%>;">
                Il pagamento non è stato stato eseguito correttamente.
            </div>
        </ItemTemplate>
    </asp:DataList>
    
    <br />
    <br />
    

    <asp:DataList ID="DataList_Coupon" runat="server" DataSourceID="SqlData_CouponInserzioni" style="margin:auto;">
        <ItemTemplate>
            <div style=" width:662px; height:auto; overflow:auto; margin:auto; color:Black; font-size:8pt; font-family:Verdana;">
                <!-- Titolo -->
                <div style=" width:622px; font-size:200%; font-weight:700; text-align:justify; background-color:#e6e6e6; padding:20px; font-family:Arial;">
                    <%#Eval("Titolo")%>
                </div>
                
                <div style="width:660px; height:auto; overflow:auto; border-width:1px; border-color:Black; border-style:solid;">
                <!-- Header -->
                <div style=" width:190px; background-color:#fcfacf; float:left; min-height:200px; padding-top:10px; padding-bottom:10px; padding-right:5px; padding-right:10px; text-align:right;">
                    <span style=" font-size:330%; color:black; font-weight:bold; clear:both; float:right; font-family:Arial Black; overflow:auto;">€ <%#String.Format("{0:n}", Eval("Prezzo"))%></span>
                   
                    <div style="font-size:8pt; text-decoration:none; clear:both;">invece di <testo style="font-size:12pt; text-decoration:line-through;">€ <%#String.Format("{0:n}", Eval("PrezzoDiListino"))%></testo></div>
                </div>
                <div style="width:460px; float:left; height:200px; padding-top:10px; padding-bottom:10px; overflow:hidden;">
                    <img src="public/Coupon/img_coupon/<%#Eval("Img")%>" alt=""/>
                </div>
          </div>
          
          <!-- Box Caratteristiche -->
                <div style=" width:640px; overflow:auto; padding-top:20px; padding-bottom:20px; padding-left:10px; padding-right:10px; border-style:solid; border-width:1px; border-color:black; border-top-style:none;">
                    <div style=" width:50%; float:left; overflow:auto;">
                        <div style="width:90%;">
                            <b style="font-size:10pt;">Sintesi</b><br /><br />
                            <%#Eval("Sintesi").ToString.Replace(vbCrLf, "<br/>")%>
                            <br /><br />
                            
                            <b style="font-size:10pt;">Condizioni</b><br /><br />
                            <%#Eval("Condizioni").ToString.Replace(vbCrLf, "<br/>")%>
                            
                            <br /><br /><b style="font-size:10pt; display:<%#controllo_presenza_opzione(Eval("opzione1_descrizione").ToString.Replace(vbCrLf, "<br/>"))%>;">Opzioni</b><br />
                            <ul style=" width:90%; line-height:16px;" type="square">
                                
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
                                
                                <li style="display:<%#controllo_presenza_opzione(Eval("opzione1_descrizione").ToString.Replace(vbCrLf, "<br/>"))%>;">
                                    <%#Eval("opzione1_descrizione").ToString.Replace(vbCrLf, "<br/>")%> <b> a € <%#String.Format("{0:n}", Eval("opzione1_prezzo"))%></b> invece di € <%#String.Format("{0:n}", Eval("opzione1_prezzodilistino"))%>
                                </li>
                                <li style="display:<%#controllo_presenza_opzione(Eval("opzione2_descrizione").ToString.Replace(vbCrLf, "<br/>"))%>;">
                                    <%#Eval("opzione2_descrizione").ToString.Replace(vbCrLf, "<br/>")%> <b> a € <%#String.Format("{0:n}", Eval("opzione2_prezzo"))%></b> invece di € <%#String.Format("{0:n}", Eval("opzione2_prezzodilistino"))%>
                                </li>
                                <li style="display:<%#controllo_presenza_opzione(Eval("opzione3_descrizione").ToString.Replace(vbCrLf, "<br/>"))%>;">
                                    <%#Eval("opzione3_descrizione").ToString.Replace(vbCrLf, "<br/>")%> <b> a € <%#String.Format("{0:n}", Eval("opzione3_prezzo"))%></b> invece di € <%#String.Format("{0:n}", Eval("opzione3_prezzodilistino"))%>
                                </li>
                            </ul>
                        </div>
                    </div>
                    <div style=" width:50%; float:left; overflow:auto;">
                        <b style="font-size:10pt;">Descrizione</b><br />
                        <%#Eval("DescrizioneLunga").ToString.Replace(vbCrLf, "<br/>")%>
                    </div>
                </div>
                
                <!-- Box Info Partners - 2 Sezioni-->
                <div style="background-color:#e6e6e6; width:100%; overflow:auto; font-weight:bold; font-size:150%; padding-bottom:10px; padding-top:20px; border-color:Black; border-style:solid; border-width:0px; border-bottom-width:1px;">
                    Il Partner
                </div>
                <div style=" width:100%; height:100%; overflow:auto; padding-top:20px; padding-bottom:20px; border-color:Black; border-width:0px; border-style:solid; border-bottom-width:1px;">
                    <div style="width:45%; float:left; overflow:auto; padding-right:5px;">
                        <b><%#Eval("RagioneSociale")%></b><br />
                        <%#Eval("Cognome")%> <%#Eval("Nome")%><br />
                        <%#Eval("Via")%><br />
                        <%#Eval("Citta")%> (<%#Eval("Provincia")%>)<br />
                        <%#Eval("CAP")%><br />
                        <%#Eval("Telefono") %> - <%#Eval("Fax")%><br />
                        <a href='<%#Eval("SitoWeb")%>'><%#Eval("SitoWeb")%></a>
                        
                        <br /><br />
                        <b>Più info</b>
                        <br />
                        <%#Eval("Descrizione_Partner") %>
                    </div>
                    <div style="width:50%; float:right; overflow:auto; text-align:right; overflow:hidden;">
                        <%#Eval("GoogleMaps_iFrame")%>
                    </div>
                </div>
                
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
                <div style="display:<%# visualizza_descrizione_tecnica(Eval("DescrizioneTecnica"))%>; background-color:#e6e6e6; width:100%; overflow:auto; font-weight:bold; font-size:150%; padding-bottom:10px; padding-top:20px; border-color:Black; border-style:solid; border-width:0px; border-bottom-width:1px;">
                    Descrizione Tecnica
                </div>
                <div style="display:<%# visualizza_descrizione_tecnica(Eval("DescrizioneTecnica"))%>; width:100%; padding-top:20px; padding-bottom:20px; border-color:Black; border-width:0px; border-style:solid; border-bottom-width:1px;">
                    <%#Eval("DescrizioneTecnica")%>
                </div>
                
            </div>
            
            <br /><br />
            
            <div style=" width:99.5%; height:160px; border-width:1px; border-color:Black; border-style:dotted; padding:5px;">
                <table style="text-align:left; vertical-align:middle;">
                    <tr>
                        <td>
                            <img src="Public/Images/servizio_clienti.jpg"  alt="" />
                        </td>
                        <td>
                            <div style="font-weight:bold; font-size:22pt; color:Black;">
                                Servizio clienti a disposizione dalle 8:00 alle 18:00
                            </div>
                        </td>
                    </tr>
                </table>
            </div>
        </ItemTemplate>
    </asp:DataList>
    
    <asp:SqlDataSource ID="SqlData_Coupon" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
        SelectCommand="SELECT * FROM coupon_tabella_temporanea WHERE (cod_controllo = @cod_controllo)">
        <SelectParameters>
            <asp:QueryStringParameter Name="cod_controllo" QueryStringField="cod" />
        </SelectParameters>
    </asp:SqlDataSource>
    
    <asp:SqlDataSource ID="SqlData_CouponInserzioni" runat="server" 
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>" 
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>" 
    SelectCommand="SELECT * FROM coupon_inserzione"></asp:SqlDataSource>
</asp:Content>

