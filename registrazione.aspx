<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="registrazione.aspx.vb" Inherits="registrazione" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
<script language="vbscript" type="text/vbscript">

sub ctl00_cph_tRegistrazione_onkeydown()
    if window.event.keyCode=13 then
        window.event.returnValue=false
    end if
end sub

</script>

<h1><% =pagetype %>
    <asp:Label ID="lblSito" runat="server" ></asp:Label></h1>
      <div class="demoarea" id="principale" runat="server" visible="true">
                       
                        <!-- Tipologia Cliente -->
                        <div style="text-transform:uppercase; padding:10px; font-weight:bold; padding-top:20px;">.: TIPOLOGIA CLIENTE :.</div>
						<div id="sceltatipologiacliente" runat="server">
                        <table style="width:100%; border-style:solid; border-width:2px; border-color:rgb(215, 215, 215); background-color:rgb(250, 250, 250); font-size:9pt;">
                            <tr>
                                <td style="padding:5px;">
                                    <asp:RadioButton ID="rTipoPrivato" runat="server" GroupName="tipo" Text="Privato" AutoPostBack="True" Checked="True" style="text-transform:uppercase; font-weight:bold; font-size:14pt;" />
                                    <br />
                                    <span style="padding-left:20px;" >Se non si è titolari di partita iva oppure gli articoli acquistti non vengono utilizzati per fini professionali.</span>
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:5px;">
                                    <asp:RadioButton ID="rTipoAzienda" runat="server" GroupName="tipo" Text="Azienda" AutoPostBack="True" style="text-transform:uppercase; font-weight:bold; font-size:14pt;" />
                                    <br />
                                    <span style="padding-left:20px;">Se si è titolari di Partita iva.</span>
                                </td>
                            </tr>
							<tr>
                                <td style="padding:5px;">
                                    <asp:RadioButton ID="rTipoPubblicaAmministrazione" runat="server" GroupName="tipo" Text="Pubblica Amministrazione" AutoPostBack="True" style="text-transform:uppercase; font-weight:bold; font-size:14pt;" />
                                    <br />
                                    <span style="padding-left:20px;">Per la pubblica amministrazione.</span>
                                </td>
                            </tr>
                        </table>
						</div>
                        <div id="tipologiacliente" runat="server" style="border-style:solid; border-width:2px; border-color:rgb(215, 215, 215); background-color:rgb(250, 250, 250); font-size:9pt;">
							<asp:Label ID="label1tipocliente" runat="server" style="text-transform:uppercase; font-weight:bold; font-size:14pt; padding:5px;"></asp:Label><br />
							<asp:Label ID="label2tipocliente" runat="server" style="padding:5px;"></asp:Label>
						</div>
                        
                        <!-- Dati Anagrafici -->
                        <div style="text-transform:uppercase; padding:10px; font-weight:bold; padding-top:20px;">.: DATI ANAGRAFICI :.</div>
                        <table style="width:100%; border-style:solid; border-width:2px; border-color:rgb(215, 215, 215); background-color:rgb(250, 250, 250); font-size:11pt;">
                            <% If (rTipoPrivato.Checked = True) Then%>
                                <tr>
                                    <td style="padding:5px;">
                                        <asp:Label ID="lblNomeCognome" runat="server" Text="Nome e Cognome *" Visible="False"></asp:Label>  
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbNomeCognome" AutoPostBack="false" runat="server" Width="98%" MaxLength="100" Visible="False" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbNomeA');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbNomeA');" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                        <br />
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator7" runat="server" ControlToValidate="tbNomeCognome" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_DatiAnagrafici" Visible="False" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                    </td>
                                </tr>
                            <%End if %>
							<% If Not tbPartitaIva.Text = "" or Not rTipoPrivato.checked Then%>
                                <tr>
                                    <td style="padding:5px;">
                                        <asp:Label ID="lblPartitaIva" runat="server" Text="Partita Iva *"></asp:Label>
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbPartitaIva" runat="server" AutoPostBack="true" OnTextChanged="check_vat" CausesValidation="False" Width="98%" MaxLength="11" ValidationGroup="registrazione_DatiAnagrafici" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator16" runat="server" ControlToValidate="tbPartitaIva" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_DatiAnagrafici" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                        <asp:RegularExpressionValidator ID="RegularExpressionValidator5" runat="server" ControlToValidate="tbPartitaIva" ErrorMessage="P.IVA non corretta" ValidationExpression="^[A-Za-z0-9]{2,11}$" Width="137px" Display="Dynamic" ValidationGroup="registrazione_DatiAnagrafici" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RegularExpressionValidator>  
                                        <asp:Label ID="lblPiva" runat="server" Font-Bold="True" ForeColor="Red"></asp:Label>
                                    </td>
                                </tr>
                            <% end if%>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    <asp:Label ID="lblRagioneSociale" runat="server" Text="Ragione Sociale *"></asp:Label>
                                    <br />
                                    <asp:Label ID="Label1" runat="server" Font-Size="7pt" Font-Names="Arial" Text="(Completa di forma giuridica: Snc, Spa, etc.)"></asp:Label>
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbRagioneSociale" runat="server" Width="98%" MaxLength="100" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbRagioneSocialeA');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbRagioneSocialeA');" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    <br />
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator19" runat="server" ControlToValidate="tbRagioneSociale" Display="Dynamic" ErrorMessage="Campo obbligatorio" ValidationGroup="registrazione_DatiAnagrafici" Width="133px" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:5px;">
                                    <asp:Label ID="label_codice_fiscale" runat="server" Text="Codice Fiscale *"></asp:Label>
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbCodiceFiscale" runat="server" Width="98%" MaxLength="16" ValidationGroup="registrazione_DatiAnagrafici" style="text-transform:uppercase; font-size:10pt; padding:1%; font-weight:bold;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator12" runat="server" ControlToValidate="tbCodiceFiscale" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_DatiAnagrafici" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator><br />
                                    <asp:RegularExpressionValidator ID="RegularExpressionValidator6" runat="server" ControlToValidate="tbCodiceFiscale" ErrorMessage="Codice Fiscale non corretto" Width="185px" Display="Dynamic" ValidationGroup="registrazione_DatiAnagrafici" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RegularExpressionValidator>
                                </td>    
							</tr>
							<tr>
								<td>
								</td>
								<td style="padding:5px;">
									<asp:Button ID="Button_genera_codice_fiscale" Width="80%" Height="25px" runat="server" Text="RECUPERA CODICE FISCALE" Visible="False" UseSubmitBehavior="False" ValidationGroup="cf" />
                                    <asp:Panel ID="Panel_Cod_fiscale" runat="server" Visible="false" Width="80%" style="margin:0; border-style:dotted; border-color:Gray; border-width:1px;">
                                        <table cellpadding="1" cellspacing="2" border="0" width="100%" style="font-size:8pt; background-color:rgb(254, 255, 242); vertical-align:middle;">
                                            <tr>
                                                <td style="width:150px;">
                                                    <asp:Label ID="lblDataNascita" runat="server" Text="Data di nascita: "></asp:Label>
                                                </td>
                                                <td>
                                                    <asp:TextBox ID="txtDataNascita" Text="gg/mm/aaaa" runat="server" Width="98%" ValidationGroup="cf" style="padding:1%; font-size:10pt;"></asp:TextBox>
                                                    <asp:RegularExpressionValidator ID="revDataNascita" runat="server" ControlToValidate="txtDataNascita" ErrorMessage="Inserire una data corretta" ValidationExpression="(0[1-9]|[12][0-9]|3[01])[/](0[1-9]|1[012])[/](19|20)\d\d" Display="Dynamic" ValidationGroup="cf" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RegularExpressionValidator>
                                                    <asp:RequiredFieldValidator ID="rfvDataNascita" runat="server" ControlToValidate="txtDataNascita" ErrorMessage="Campo obbligatorio" Width="141px" Display="Dynamic" ValidationGroup="cf" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>                                        
                                                </td>
                                            </tr>
                                            <tr>
                                                <td>
                                                    Sesso:
                                                </td>
                                                <td>
                                                    <asp:RadioButtonList ID="rblSesso" runat="server" RepeatDirection="Horizontal">
                                                        <asp:ListItem Selected="True" Value="M">Maschile</asp:ListItem>
                                                        <asp:ListItem Value="F">Femminile</asp:ListItem>
                                                    </asp:RadioButtonList>
                                                </td>                                                     
                                            </tr>
                                            <tr>
                                                <td>
                                                </td>
                                                <td>
                                                    <asp:RadioButton ID="rboNatiEstero" runat="server" GroupName="grpNascita" Text="Nato all'estero" AutoPostBack="True" Width="150px" OnCheckedChanged="scegliNascita" />
                                                    <asp:RadioButton ID="rboNatiItalia" runat="server" GroupName="grpNascita" AutoPostBack="True" Checked="True" Text="Nato in Italia" OnCheckedChanged="scegliNascita" />
                                                </td>
                                            </tr>
                                            <tr id="pnlNatiEstero" runat="server" visible="false">
                                                <td>
                                                      <asp:Label ID="lblStatoNascita" runat="server" Text="Stato di nascita: "></asp:Label>
                                                </td>
                                                <td>
                                                      <asp:DropDownList ID="ddlStatoNascita" runat="server" Width="100%" DataSourceID="StatiSqlDataSource" DataTextField="Stato" DataValueField="Codice_ISTAT" ValidationGroup="cf"></asp:DropDownList>
                                                      <asp:CompareValidator ID="covStatoNascita" runat="server" ErrorMessage="Indicare lo stato di nascita!" Operator="NotEqual" ValueToCompare="--------" ControlToValidate="ddlStatoNascita" Width="176px" ValidationGroup="cf" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:CompareValidator>
                                                </td>
                                            </tr>
		                                    <tr id="pnlNatiItalia" runat="server" visible="true">
                                                <td>
                                                      <asp:Label ID="lblProvinciaNascita" runat="server" Text="Provincia di nascita: "></asp:Label>
                                                </td>
                                                <td>
                                                    <asp:DropDownList ID="ddlProvinciaNascita" runat="server" Width="100%"
                                                                DataSourceID="ProvinceSqlDataSource" DataTextField="Provincia" 
                                                                DataValueField="TargaProvincia" AutoPostBack="True" 
                                                                OnTextChanged="scegliComuniNascita" ValidationGroup="cf" style="font-size:10pt;">
                                                                <asp:ListItem>--------</asp:ListItem>
                                                    </asp:DropDownList>

                                                    <asp:CompareValidator ID="covProvinciaNascita"  runat="server" 
                                                          ErrorMessage="Indicare la provincia di nascita!" Operator="NotEqual" 
                                                          ValueToCompare="--------" ControlToValidate="ddlProvinciaNascita" Width="236px" ValidationGroup="cf" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:CompareValidator>                        
                                                </td>
                                            </tr>
                                            <tr id="lista_comuni" runat="server">
                                               <td>
                                                        <asp:Label ID="lblComuneNascita" runat="server" Text="Comune di nascita: "></asp:Label>
                                               </td>
                                               <td>
                                                        <asp:DropDownList ID="ddlComuneNascita" runat="server" Width="100%" DataSourceID="ComuniNascitaSqlDataSource" DataTextField="Comune" DataValueField="Codice_Comune" ValidationGroup="cf" style="font-size:10pt;">
                                                            <asp:ListItem>--------</asp:ListItem>
                                                        </asp:DropDownList>

                                                        <asp:CompareValidator ID="covComuneNascita" runat="server" 
                                                            ErrorMessage="Indicare il comune di nascita!" Operator="NotEqual" 
                                                            ValueToCompare="--------" ControlToValidate="ddlComuneNascita" Width="244px" ValidationGroup="cf" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:CompareValidator>                                         
                                               </td>
                                            </tr>     
                                        </table>
                                    </asp:Panel>
                                </td>
                            </tr>
							<tr><td colspan="2" align="right">
								<asp:Button ID="imgModDatiAnagrafici" runat="server" Text="MODIFICA" Height="25px" CausesValidation="true" BackColor="red" ForeColor="White" Visible="False" /></td>
                            </tr>
                        </table>
                        
						<!-- Dati Fatturazione Elettronica -->
						<asp:Panel ID="Panel_Fattura_Elettronica" runat="server" Visible="true">
                        <div style="text-transform:uppercase; padding:10px; font-weight:bold; padding-top:20px;">.: DATI FATTURAZIONE ELETTRONICA :.</div>
                        <table style="width:100%; border-style:solid; border-width:2px; border-color:rgb(215, 215, 215); background-color:rgb(250, 250, 250); font-size:11pt;">
							<tr>
                                <td style="padding:5px; width:200px;">
                                    <asp:Label ID="lblEmailPec" runat="server" Text="PEC"></asp:Label>
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbEmailPec" runat="server" CausesValidation="True" Width="98%" MaxLength="256" ValidationGroup="registrazione_FatturaElettronica" style="font-size:10pt; padding:1%;"></asp:TextBox>
									<asp:RegularExpressionValidator ID="RegularExpressionValidatorEmailPec" runat="server" ControlToValidate="tbEmailPec" Display="Dynamic" ErrorMessage="Indirizzo email non valido" SetFocusOnError="True" ValidationExpression="(?=^.{7,256}$)[\s]*\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*[\s]*" ValidationGroup="registrazione_FatturaElettronica" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RegularExpressionValidator>
								</td>
                            </tr>
							<tr>
                                <td style="padding:5px; width:200px;">
                                    <asp:Label ID="lblCsdi" runat="server" Text="Codice SDI"></asp:Label>
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbCsdi" runat="server" Width="98%" MaxLength="7" ValidationGroup="registrazione_FatturaElettronica" CausesValidation="True" style="font-size:10pt; padding:1%;"></asp:TextBox>
									<asp:RegularExpressionValidator ID="RegularExpressionValidatorCsdi" runat="server" ControlToValidate="tbCsdi" Display="Dynamic" ErrorMessage="Codice SDI non valido" SetFocusOnError="True" ValidationExpression="^([X]{0}|[A-Za-z0-9]{7})$" ValidationGroup="registrazione_FatturaElettronica" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RegularExpressionValidator>
									<asp:Label ID="lblPecAndSdi" runat="server" Font-Bold="True" ForeColor="Red" Text=""></asp:Label>
								</td>
                            </tr>
							<tr><td colspan="2" align="right">
									<asp:Button ID="imgModFatturaElettronica" runat="server" Text="MODIFICA" Height="25px" CausesValidation="true" BackColor="red" ForeColor="White"/></td>
								</tr>
                        </table>
						</asp:Panel>
					
						
                        <!-- Indirizzo Fatturazione -->
                        <div style="text-transform:uppercase; padding:10px; font-weight:bold; padding-top:20px;">.: INDIRIZZO FATTURAZIONE :.</div>
                        <table style="width:100%; border-style:solid; border-width:2px; border-color:rgb(215, 215, 215); background-color:rgb(250, 250, 250); font-size:11pt;">
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    Indirizzo *
                                </td>
                                <td style="padding:5px;">
									<asp:TextBox ID="tbIndirizzo" runat="server" Width="98%" MaxLength="100" ValidationGroup="registrazione_indirizzoP" CausesValidation="True" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbIndirizzo2');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbIndirizzo2');" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator8" runat="server" ControlToValidate="tbIndirizzo" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoP" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
								</td>
                            </tr>
							<tr>
                                <td style="padding:5px; width:200px;">
                                    CAP *
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbCap" runat="server" AutoPostBack="true" OnTextChanged="City_Bind_Data" CausesValidation="False" Width="98%" MaxLength="5" ValidationGroup="registrazione_indirizzoP" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbCap2');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbCap2');"  style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator11" runat="server" ControlToValidate="tbCap" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoP" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
								</td>      
                            </tr>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    Città *
                                </td>
                                <td style="padding:5px;">                                    
									<asp:DropDownList ID="ddlCitta" onSelectedIndexChanged="Province_Bind_Data" AutoPostBack="true" runat="server" Width="100%" ValidationGroup="registrazione_indirizzoP" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:DropDownList>
									<asp:RequiredFieldValidator ID="RequiredFieldValidator9" runat="server" ControlToValidate="ddlCitta" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoP" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
								</td>      
                            </tr>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    Provincia *
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbProvincia" runat="server" ReadOnly="true" Width="98%" MaxLength="20" ValidationGroup="registrazione_indirizzoP" CausesValidation="True" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbProvincia2');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbProvincia2');"  style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator10" runat="server" ControlToValidate="tbProvincia" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoP" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                </td>      
                            </tr>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    Telefono *
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbTelefono" runat="server" Width="98%" MaxLength="25" ValidationGroup="registrazione_indirizzoP" CausesValidation="True" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbTelefono2');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbTelefono2');"  style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator13" runat="server" ControlToValidate="tbTelefono" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoP" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                </td>      
                            </tr>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    Fax
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbFax" runat="server" Width="98%" MaxLength="25" ValidationGroup="registrazione_indirizzoP" CausesValidation="True" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbFax2');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbFax2');"  style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                </td>      
                            </tr>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    Cellulare
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbCellulare" runat="server" Width="98%" MaxLength="25" ValidationGroup="registrazione_indirizzoP" CausesValidation="True" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbCellulare2');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbCellulare2');"  style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                </td>      
                            </tr>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    Url Sito Web
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbSito" runat="server" Width="98%" MaxLength="50" ValidationGroup="registrazione_indirizzoP" CausesValidation="True"  style="text-transform:lowercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                </td>      
                            </tr>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    Skype
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbSkype" runat="server" Width="98%" MaxLength="50" ValidationGroup="registrazione_indirizzoP" CausesValidation="True" style="text-transform:lowercase; font-size:10pt; padding:1%;"></asp:TextBox>    
                                </td>      
                            </tr>
                            <tr>
                                <td style="padding:5px; width:200px;">
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox readonly ID="TextBoxNote" runat="server" Width="98%" MaxLength="255" ValidationGroup="registrazione_indirizzoP" CausesValidation="True" TextMode="MultiLine" Rows="5"  style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                </td>      
                            </tr>
							<tr><td colspan="2" align="right">
								<asp:Button ID="imgModIndirizzoP" runat="server" Text="MODIFICA" Height="25px" CausesValidation="true" BackColor="red" ForeColor="White"/></td>
                            </tr>
                        </table>
                        
                        <!-- Indirizzo Spedizione -->
                        <div style="text-transform:uppercase; padding:10px; font-weight:bold; padding-top:20px;">.: INDIRIZZO SPEDIZIONE :.</div>
                        
						<asp:Panel ID="Panel_IndirizzoSecondarioContainer" runat="server" Visible="true">
                        <!-- Checkbox indirizzo di Spedizione, indirizzo di fatturazione è diverso da quello di spedizione -->
                        <table style="width:100%; border-style:solid; border-width:2px; border-color:red; background-color:rgb(250, 250, 250); font-size:10pt; vertical-align:middle;">
                            <tr>
                                <td>
                                    <asp:RadioButton ID="RB_IndirizzoSpedizioneUguale" runat="server" GroupName="IndirizzoFatturazione" Text="Il mio indirizzo di <b>SPEDIZIONE</b> è lo stesso del mio indirizzo di <b>FATTURAZIONE</b>" AutoPostBack="true" Checked="true" />
                                    <br />
                                    <asp:RadioButton ID="RB_IndirizzoSpedizioneDiverso" runat="server" GroupName="IndirizzoFatturazione" Text="Usare un indirizzo di <b>SPEDIZIONE</b> diverso da quello di <b>FATTURAZIONE</b>" AutoPostBack="true" />
                                </td>
                            </tr>
                        </table>
                        <!-- Pannello Indirizzo Secondario -->
                        <asp:Panel ID="Panel_IndirizzoSecondario" runat="server" Enabled="false" Visible="false" style="margin-top:20px;">
							* Potrai inserire ulteriori indirizzi di spedizione in ogni momento dopo la procedura di registrazione.
                            <table style="width:100%; border-style:solid; border-width:2px; border-color:rgb(215, 215, 215); background-color:rgb(250, 250, 250); font-size:11pt;">
                                <tr>
                                    <td style="padding:5px; width:200px;">
                                        Cognome o Ragione Sociale *
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbRagioneSocialeA" runat="server" Width="98%" MaxLength="100" ValidationGroup="registrazione_indirizzoS" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox><asp:TextBox ID="tbRagioneSocialeAId" runat="server" Width="20" Visible="False" style="text-transform:uppercase; font-size:10pt; padding:1%;" ></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator6" runat="server" ControlToValidate="tbRagioneSocialeA" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoS" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding:5px;">
                                        Nome
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbNomeA" runat="server" Width="98%" MaxLength="50" ValidationGroup="registrazione_indirizzoS" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox><asp:TextBox ID="tbNomaAid" runat="server" Width="0" Visible="False"></asp:TextBox>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding:5px;">
                                        Indirizzo *
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbIndirizzo2" runat="server" Width="98%" MaxLength="100" ValidationGroup="registrazione_indirizzoS" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox><asp:TextBox ID="tbIndirizzoId" runat="server" Width="0" Visible="False" ></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator14" runat="server" ControlToValidate="tbIndirizzo2" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoS" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                    </td>
                                </tr>
                                <tr>
									<td style="padding:5px; width:200px;">
										CAP *
									</td>
									<td style="padding:5px;">
										<asp:TextBox ID="tbCap2" runat="server" AutoPostBack="true" OnTextChanged="City_Bind_Data2" CausesValidation="False" Width="98%" MaxLength="5" ValidationGroup="registrazione_indirizzoS" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbCap2');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbCap2');"  style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
										<asp:RequiredFieldValidator ID="RequiredFieldValidator21" runat="server" ControlToValidate="tbCap2" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoS" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
									</td>      
								</tr>
								<tr>
									<td style="padding:5px; width:200px;">
										Città *
									</td>
									<td style="padding:5px;">                                    
										<asp:DropDownList ID="ddlCitta2" onSelectedIndexChanged="Province_Bind_Data2" AutoPostBack="true" runat="server" Width="100%" ValidationGroup="registrazione_indirizzoS" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:DropDownList>
										<asp:RequiredFieldValidator ID="RequiredFieldValidator15" runat="server" ControlToValidate="ddlCitta2" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoS" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
									</td>      
								</tr>
								<tr>
									<td style="padding:5px; width:200px;">
										Provincia *
									</td>
									<td style="padding:5px;">
										<asp:TextBox ID="tbProvincia2" runat="server" ReadOnly="true" Width="98%" MaxLength="20" ValidationGroup="registrazione_indirizzoS" CausesValidation="True" onkeyup="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbProvincia2');" onblur="javascript:compilaAutomaticamente(this.id,'ctl00_cph_tbProvincia2');"  style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
										<asp:RequiredFieldValidator ID="RequiredFieldValidator20" runat="server" ControlToValidate="tbProvincia2" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoS" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
									</td>      
								</tr>
								<tr>
                                    <td style="padding:5px;">
                                        Zona
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbZona" runat="server" Width="98%" MaxLength="100" ValidationGroup="registrazione_indirizzoS" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding:5px;">
                                        Telefono *
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbTelefono2" runat="server" Width="98%" MaxLength="25" ValidationGroup="registrazione_indirizzoS" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator22" runat="server" ControlToValidate="tbTelefono2" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_indirizzoS" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                    </td>
                                </tr>
								<!--
                                <tr>
                                    <td style="padding:5px;">
                                        Fax
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbFax2" runat="server" Width="98%" MaxLength="25" ValidationGroup="registrazione" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding:5px;">
                                        Cellulare
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbCellulare2" runat="server" Width="98%" MaxLength="25" ValidationGroup="registrazione" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    </td>
                                </tr>
								-->
                                <tr>
                                    <td style="padding:5px;">
                                        Note
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbNote" runat="server" Width="98%" MaxLength="80" ValidationGroup="registrazione_indirizzoS" CausesValidation="True" Rows="5" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox><br />
                                        <span style="font-size:8pt;">Inserire MAX 80 caratteri</span>
                                    </td>
                                </tr>
								<tr><td colspan="2" align="right">
									<asp:Button ID="imgModIndirizzoS" runat="server" Text="MODIFICA" Height="25px" CausesValidation="true" BackColor="red" ForeColor="White"/></td>
								</tr>
                            </table>
                        </asp:Panel>
                      </asp:Panel>
					  
		<asp:Panel ID="PnlDestinazione" runat="server">
                <asp:Label ID="LblDescrDest" runat="server" Text=""></asp:Label>
                 <table style="width:100%; border-style:solid; border-width:2px; border-color:rgb(215, 215, 215); background-color:rgb(250, 250, 250); font-size:11pt;">
								<tr>
									<td style="padding:5px; width:200px;">
                                        Indirizzi esistenti
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:DropDownList runat="server" ID="LstDestinazione" AutoPostBack="True" Width="100%" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:DropDownList>
                                    </td>
								</tr>
                                <tr>
                                    <td style="padding:5px; width:200px;">
                                        Cognome o Ragione Sociale *
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbRagioneSocialeADest" runat="server" Width="98%" MaxLength="100" ValidationGroup="registrazione_Destinazione" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox><asp:TextBox ID="tbRagioneSocialeAIdDest" runat="server" Width="20" Visible="False" style="text-transform:uppercase; font-size:10pt; padding:1%;" ></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator6Dest" runat="server" ControlToValidate="tbRagioneSocialeADest" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Destinazione" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding:5px;">
                                        Nome
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbNomeADest" runat="server" Width="98%" MaxLength="50" ValidationGroup="registrazione_Destinazione" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox><asp:TextBox ID="tbNomaAidDest" runat="server" Width="0" Visible="False"></asp:TextBox>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding:5px;">
                                        Indirizzo *
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbIndirizzo2Dest" runat="server" Width="98%" MaxLength="100" ValidationGroup="registrazione_Destinazione" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox><asp:TextBox ID="tbIndirizzoIdDest" runat="server" Width="0" Visible="False" ></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator14Dest" runat="server" ControlToValidate="tbIndirizzo2Dest" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Destinazione" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                    </td>
                                </tr>
								<tr>
									<td style="padding:5px; width:200px;">
										CAP *
									</td>
									<td style="padding:5px;">
										<asp:TextBox ID="tbCap2Dest" runat="server" AutoPostBack="true" OnTextChanged="City_Bind_Data3" CausesValidation="False" Width="98%" MaxLength="5" ValidationGroup="registrazione_Destinazione" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
										<asp:RequiredFieldValidator ID="RequiredFieldValidatorCap2Dest" runat="server" ControlToValidate="tbCap2Dest" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Destinazione" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
									</td>      
								</tr>
								<tr>
									<td style="padding:5px; width:200px;">
										Città *
									</td>
									<td style="padding:5px;">                                    
										<asp:DropDownList ID="ddlCitta2Dest" onSelectedIndexChanged="Province_Bind_Data3" AutoPostBack="true" runat="server" Width="100%" ValidationGroup="registrazione_Destinazione" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:DropDownList>
										<asp:RequiredFieldValidator ID="RequiredFieldValidatorDdlCitta2Dest" runat="server" ControlToValidate="ddlCitta2Dest" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Destinazione" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
									</td>      
								</tr>
								<tr>
									<td style="padding:5px; width:200px;">
										Provincia *
									</td>
									<td style="padding:5px;">
										<asp:TextBox ID="tbProvincia2Dest" runat="server" ReadOnly="true" Width="98%" MaxLength="20" ValidationGroup="registrazione_Destinazione" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
										<asp:RequiredFieldValidator ID="RequiredFieldValidatorProvincia2Dest" runat="server" ControlToValidate="tbProvincia2Dest" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Destinazione" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
									</td>      
								</tr>
								<tr>
                                    <td style="padding:5px;">
                                        Zona
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbZonaDest" runat="server" Width="98%" MaxLength="100" ValidationGroup="registrazione_Destinazione" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding:5px;">
                                        Telefono *
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbTelefono2Dest" runat="server" Width="98%" MaxLength="25" ValidationGroup="registrazione_Destinazione" CausesValidation="True" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox>
                                        <asp:RequiredFieldValidator ID="RequiredFieldValidator22Dest" runat="server" ControlToValidate="tbTelefono2Dest" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Destinazione" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                    </td>
                                </tr>
                                <tr>
                                    <td style="padding:5px;">
                                        Note
                                    </td>
                                    <td style="padding:5px;">
                                        <asp:TextBox ID="tbNoteDest" runat="server" Width="98%" MaxLength="80" ValidationGroup="registrazione_Destinazione" CausesValidation="True" Rows="5" style="text-transform:uppercase; font-size:10pt; padding:1%;"></asp:TextBox><br />
                                        <span style="font-size:8pt;">Inserire MAX 80 caratteri</span>
                                    </td>
                                </tr>
								<tr>
									<td><asp:CheckBox runat="server" ID="CHKPREDEFINITO" Text="Indirizzo predefinito" Checked="false" /></td>
								</tr> 
								<asp:Panel ID="PnlBottoniModifica" runat="server">
								<tr>
									<td colspan="2" align="right">
									<asp:Button ID="imgInsDestinazione" runat="server" Text="INSERISCI" Height="25px" CausesValidation="true" BackColor="red" ForeColor="White"/>
									<asp:Button ID="imgModDestinazione" runat="server" Text="MODIFICA" Height="25px" CausesValidation="true" BackColor="red" ForeColor="White"/>
									</td>
								</tr>
								</asp:Panel>
								<asp:Panel ID="PnlBottoniDestinazioneModifica" runat="server">
								<tr>
									<td align="center" colspan="2" style="padding:10px;">
										<asp:Button ID="btnModDest" runat="server" Text="SALVA MODIFICHE" Height="25px" CausesValidation="true" ValidationGroup="registrazione_Destinazione"/>
										<asp:Button ID="btnElimDest" runat="server" Text="ELIMINA DESTINAZIONE" Height="25px" CausesValidation="true" BackColor="red" ForeColor="White" ValidationGroup="registrazione_Destinazione"/>
										<br /><br /><asp:Button ID="btnAnnullaDestMod" runat="server" Text="ANNULLA" Height="25px" CausesValidation="false" />
									</td>
								</tr>
								</asp:Panel>
								<asp:Panel ID="PnlBottoniDestinazioneInserisci" runat="server">
								<tr>
									<td align="center" colspan="2" style="padding:10px;">
										<asp:Button ID="btnSalvaDest" runat="server" Text="INSERISCI come NUOVA destinazione" Height="25px" CausesValidation="true" ValidationGroup="registrazione_Destinazione"/>
										<br /><br /><asp:Button ID="btnAnnullaDestIns" runat="server" Text="ANNULLA" Height="25px" CausesValidation="false" />
									</td>
								</tr>
								</asp:Panel>
                            </table>
            </asp:Panel>
					  
            <asp:SqlDataSource ID="StatiSqlDataSource" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            SelectCommand="SELECT Stato, Codice_ISTAT FROM cf_stati" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"></asp:SqlDataSource>  
        <asp:SqlDataSource ID="ProvinceSqlDataSource" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            SelectCommand="SELECT Provincia, TargaProvincia FROM cf_province" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"></asp:SqlDataSource>
        <asp:SqlDataSource ID="ComuniNascitaSqlDataSource" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            SelectCommand="SELECT Comune, Codice_Comune, Provincia FROM cf_comuni" ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"></asp:SqlDataSource>    
                        
                        <% If (Me.Session.Item("AziendaID") = 1) And (Not Request.UrlReferrer Is Nothing) Then%>
                            <%If (Request.UrlReferrer.AbsoluteUri.Contains("copupon")) Then%>
                        <table id="TableAgevolazioni" cellpadding="1" cellspacing="5" border="0" width="100%" runat="server">
                            <tr>
                                <td colspan="2" align="right" class="accordionLink" style="height: 75px"><br />[ LISTINI AGEVOLATI ]<hr /></td>
                            </tr>
                            <tr>
                                <td bgcolor="whitesmoke" width="200" valign="top" style="height: 36px">
                                    <asp:CheckBox ID="CheckBoxAgevolazione" runat="server" Text="Attiva Agevolazione" AutoPostBack="True" /><br />
                                    <img src="Public/Images/loghi_agevolazione.jpg" alt="" /></td>
                                
                                <td style="height: 36px" >
                                    Se sei un dipendente statale o fai parte di una delle categorie elencate di seguito
                                    avrai diritto all'attivazione di un listino agevolato. Inserisci la tua Mail Istituzionale
                                    su cui riceverai le istruzioni per attivare la scontistica su tutti i nostri prodotti.<br />
                                    <asp:HyperLink ID="hlcontatti" runat="server" NavigateUrl="mailito:g.ascione@entropic.it" EnableViewState="false" Text="Contattaci" Font-Bold="true" Target="_blank"></asp:HyperLink>
                                    per ulteriori informazioni</td>
                                    
                            </tr>
                            <tr>
                                <td bgcolor="whitesmoke" width="200" valign="top" style="height: 36px">
                                    Categoria</td>
                                <td style="height: 36px" >
                                    <asp:DropDownList ID="DropDownListAgevolazione" runat="server" Enabled="False">
                                        <asp:ListItem>Polizia Di stato</asp:ListItem>
                                        <asp:ListItem>Polizia Municipale</asp:ListItem>
                                        <asp:ListItem>Carabinieri</asp:ListItem>
                                        <asp:ListItem>Guardia di finanza</asp:ListItem>
                                        <asp:ListItem>Dipendenti statali</asp:ListItem>
                                        <asp:ListItem>Vigili del fuoco</asp:ListItem>
                                        <asp:ListItem>Esercito Italiano</asp:ListItem>
                                        <asp:ListItem>Banca di Credito Popolare</asp:ListItem>
                                        <asp:ListItem>Altro</asp:ListItem>
                                    </asp:DropDownList></td>
                            </tr>
                                 
                            <tr>
                                <td bgcolor="whitesmoke" width="200"><b>Email Istituzionale</b> **</td>
                                <td ><asp:TextBox ID="tbEmailIstituzionale" runat="server" Width="200" MaxLength="50" ValidationGroup="registrazione" CausesValidation="True" Enabled="False"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator17" runat="server" ControlToValidate="tbEmailIstituzionale"
                                        Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione" Enabled="false">
                                    </asp:RequiredFieldValidator>
                                        <asp:RegularExpressionValidator
                                            ID="RegularExpressionValidator4" runat="server" ControlToValidate="tbEmailIstituzionale" Display="Dynamic"
                                            ErrorMessage="Indirizzo email non valido" SetFocusOnError="True" ValidationExpression="[\s]*\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*[\s]*"
                                            ValidationGroup="registrazione">
                                        </asp:RegularExpressionValidator>
                                    <asp:Label ID="Label2" runat="server" Font-Bold="True" ForeColor="Red"></asp:Label></td>
                            </tr>     
                            <tr>
                                <td colspan="2" style="font-size:10px;">
                                    ** La mail istituzionale verrà utilizzata solo per l'attivazione del listino agevolato.
                                </td>
                            </tr>                  

                        </table>
                        <%End If
                    End If%>
                        
                        <!-- Dati Accesso -->
                        <div style="text-transform:uppercase; padding:10px; font-weight:bold; padding-top:20px;">.: DATI ACCESSO :.</div>
                        <table style="width:100%; border-style:solid; border-width:2px; border-color:rgb(215, 215, 215); background-color:rgb(250, 250, 250); font-size:11pt;">
                            <tr>
                                <td style="padding:5px; width:200px;">
                                    <b>username</b> * 
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbUsername" runat="server" Width="98%" MaxLength="50" ValidationGroup="registrazione_Accesso" CausesValidation="True" onclick="nascondi_errore_username();" style="font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator1" runat="server" ControlToValidate="tbUsername" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator>
                                    <asp:RegularExpressionValidator ID="RegularExpressionValidator1" runat="server" ControlToValidate="tbUsername" Display="Dynamic" ErrorMessage="Inserire min. 6 caratteri senza spazi" SetFocusOnError="True" ValidationExpression="[\w]{6,}" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RegularExpressionValidator>
                                    <script type="text/javascript">
                                        function nascondi_errore_username (){
                                            document.getElementById("ctl00_cph_lblUser").style.display='none';
                                        }
                                        function nascondi_errore_email (){
                                            document.getElementById("ctl00_cph_lblEmail").style.display='none';
                                        }
                                    </script>
                                    <asp:Label ID="lblUser" runat="server" Font-Bold="True" style="background-color:Red; font-weight:bold; color:White; font-size:9pt;"></asp:Label>
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:5px;">
                                    <b>password</b> * 
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbPassword" runat="server" Width="98%" MaxLength="25" TextMode="Password" ValidationGroup="registrazione_Accesso" CausesValidation="True" style="font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator2" runat="server" ControlToValidate="tbPassword" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator><asp:RegularExpressionValidator ID="RegularExpressionValidator2" runat="server" ControlToValidate="tbPassword" Display="Dynamic" ErrorMessage="la password deve essere almeno di 6 caratteri (max 12), non puo contenere caratteri speciali" SetFocusOnError="True" ValidationExpression="\w{6,12}" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RegularExpressionValidator>
                                </td>
                            </tr>
                            <tr>
                                 <td style="padding:5px;">
                                    <b>conferma password</b> * 
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbPasswordConferma" runat="server" Width="98%" MaxLength="25" TextMode="Password" ValidationGroup="registrazione_Accesso" CausesValidation="True" style="font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator3" runat="server" ControlToValidate="tbPasswordConferma" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator><asp:CompareValidator ID="CompareValidator1" runat="server" ControlToCompare="tbPassword" ControlToValidate="tbPasswordConferma" Display="Dynamic" ErrorMessage="Le Password devono coincidere" SetFocusOnError="True" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:CompareValidator>
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:5px;">
                                    <b>email</b> * 
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbEmail" runat="server" Width="98%" MaxLength="50" ValidationGroup="registrazione_Accesso" CausesValidation="True" onclick="nascondi_errore_email();" style="font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator4" runat="server" ControlToValidate="tbEmail" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator><asp:RegularExpressionValidator ID="RegularExpressionValidator3" runat="server" ControlToValidate="tbEmail" Display="Dynamic" ErrorMessage="Indirizzo email non valido" SetFocusOnError="True" ValidationExpression="[\s]*\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*[\s]*" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RegularExpressionValidator>
                                    <asp:Label ID="lblEmail" runat="server" Font-Bold="True" ForeColor="Red"></asp:Label>
                                </td>
                            </tr>
                            <tr>
                                 <td style="padding:5px;">
                                    <b>conferma email</b> * 
                                </td>
                                <td style="padding:5px;">
                                    <asp:TextBox ID="tbEmailConferma" runat="server" Width="98%" MaxLength="50" ValidationGroup="registrazione_Accesso" CausesValidation="True" style="font-size:10pt; padding:1%;"></asp:TextBox>
                                    <asp:RequiredFieldValidator ID="RequiredFieldValidator5" runat="server" ControlToValidate="tbEmailConferma" Display="Dynamic" ErrorMessage="Campo Obbligatorio" SetFocusOnError="True" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:RequiredFieldValidator><asp:CompareValidator ID="CompareValidator2" runat="server" ControlToCompare="tbEmail" ControlToValidate="tbEmailConferma" Display="Dynamic" ErrorMessage="Le Email devono coincidere" SetFocusOnError="True" ValidationGroup="registrazione_Accesso" style="background-color:Red; font-weight:bold; padding-left:3px; padding-right:3px; color:White; font-size:9pt;"></asp:CompareValidator>
                                </td>
                            </tr>
							<tr><td colspan="2" align="right">
								<asp:Button ID="imgModAccesso" runat="server" Text="MODIFICA" Height="25px" CausesValidation="true" BackColor="red" ForeColor="White"/></td>
                            </tr>
                        </table>
                        <asp:Panel ID="PnlPrivacy" runat="server">
                        <!-- Accettazione Condizioni -->
                        <table style="width:100%; margin-top:20px; border-style:solid; border-width:2px; border-color:red; background-color:rgb(250, 250, 250); font-size:11pt; text-align:center; border-collapse:collapse;">
                            <tr>
                                <td style="width:50%; border-right-style:dotted; border-width:1px; border-color:Gray;">
                                    Privacy Policy *
                                    
                                </td>
                                <td>
                                    Condizioni di Vendita *
                                </td>
                            </tr>
                            <tr>
                                <td style="border-right-style:dotted; border-width:1px; border-color:Gray;">
                                    <asp:CheckBox ID="cbPrivacy" runat="server" Font-Bold="True" Text="   Accetto" Enabled="true"/>
                                    <asp:TextBox ID="tbPrivacy" runat="server" style="display:none" AutoPostBack="True" CausesValidation="True" ValidationGroup="registrazione_Accesso" Width="10px"></asp:TextBox>
                                    
                                    <asp:SqlDataSource ID="sdsPrivacy" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"   ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"  SelectCommand="SELECT Nome, id FROM pagine WHERE ((Abilitato = ?Abilitato) AND (AziendeId = ?AziendeId) AND (Tipo = ?Tipo)) limit 0,1" EnableViewState="False">
                                        <SelectParameters>
                                            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
                                            <asp:SessionParameter Name="AziendeId" SessionField="AziendaID" Type="Int32" />
                                            <asp:Parameter DefaultValue="1" Name="Tipo" Type="Int32" />
                                        </SelectParameters>
                                    </asp:SqlDataSource>
                                    <asp:Repeater ID="rPrivacy" runat="server" DataSourceID="sdsPrivacy" EnableViewState="False" >
                                       <ItemTemplate>
                                       (<asp:HyperLink ID="hlMenu" runat="server" NavigateUrl='<%# "~/main.aspx?id="& eval("id") %>' EnableViewState="false" Text="Leggi" Font-Bold="true" Target="_blank"></asp:HyperLink>)
                                       </ItemTemplate>
                                    </asp:Repeater>    
                                </td>
                                <td>
                                    <asp:CheckBox ID="cbCondizioniVendita" runat="server" Font-Bold="True" Text="   Accetto" Enabled="true"/>
                                    <asp:TextBox ID="tbCondizioni" style="display:none" runat="server" AutoPostBack="True" Enabled="true" Width="10px"></asp:TextBox>
                                    
                                    <asp:SqlDataSource ID="sdsCondizioni" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"   ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"  SelectCommand="SELECT Nome, id FROM pagine WHERE ((Abilitato = ?Abilitato) AND (AziendeId = ?AziendeId) AND (Tipo = ?Tipo)) limit 0,1" EnableViewState="False">
                                        <SelectParameters>
                                            <asp:Parameter DefaultValue="1" Name="Abilitato" Type="Int32" />
                                            <asp:SessionParameter Name="AziendeId" SessionField="AziendaID" Type="Int32" />
                                            <asp:Parameter DefaultValue="2" Name="Tipo" Type="Int32" />
                                        </SelectParameters>
                                    </asp:SqlDataSource>
                                    <asp:Repeater ID="rCondizioni" runat="server" DataSourceID="sdsCondizioni" EnableViewState="False" >
                                       <ItemTemplate>
                                       (<asp:HyperLink ID="hlMenu" runat="server" NavigateUrl='<%# "~/main.aspx?id="& eval("id") %>' EnableViewState="false" Text="Leggi" Font-Bold="true" Target="_blank"></asp:HyperLink>)
                                       </ItemTemplate>
                                    </asp:Repeater>
                                </td>
                            </tr>
                            <tr>
                                <td colspan="2">
                                    <asp:Label ID="ErrorCondizioni" runat="server" Text="Devi accettare tutte le condizioni" ForeColor="Red" Visible="False"></asp:Label>
                                </td>
                            </tr>
                        </table>
                        </asp:Panel>
                        <!-- TASTO REGISTRATI -->
                        <%If btRegistrati.Visible = True Then%>
                            <table style="width:100%; height:50px; margin-top:20px; background-color:rgb(16, 152, 23); font-size:11pt; text-align:center; color:White;">
                                <tr>
                                    <td>
                                        <asp:Button ID="btRegistrati" CausesValidation="True" Visible="true" runat="server" Text="REGISTRATI" width="100%" Height="100%" PostBackUrl="registrazione.aspx" BackColor="Transparent" Font-Size="20pt" Font-Bold="true" ForeColor="white" BorderStyle="None"/>
                                    </td>
                                </tr>
                            </table>
                        <%End If%>
                        
                        <!-- Obbligatorietà campi -->
                        <div style="width:100%; text-align:left; font-size:9pt; margin-top:10px;">Tutti i campi contrassegnati dall' asterisco sono obbligatori.</div>
    </div>
    
<script type="text/javascript" language="javascript">
<!--
function privacy() {
	if(document.aspnetForm.ctl00_cph_cbPrivacy.checked){
		document.aspnetForm.ctl00$cph$tbPrivacy.value='ok';
	}else{
		document.aspnetForm.ctl00$cph$tbPrivacy.value='';
	}
}
function condizioni() {
	if(document.aspnetForm.ctl00_cph_cbCondizioniVendita.checked){
		document.aspnetForm.ctl00$cph$tbCondizioni.value='ok';
	}else{
		document.aspnetForm.ctl00$cph$tbCondizioni.value='';
	}
}

function compilaAutomaticamente(idCampo1,idCampo2){
    //alert(document.getElementById(idCampo1).value);
    //alert(document.getElementById(idCampo2).value);
    if (document.getElementById('ctl00_cph_CB_DiversoIndirizzoSpedizione').checked == false){
        document.getElementById(idCampo2).value = document.getElementById(idCampo1).value;    
    }
}

// Restricts input for the given input to the given inputFilter.
function setInputFilter(input, inputFilter) {
  ["input", "keydown", "keyup", "mousedown", "mouseup", "select", "contextmenu", "drop"].forEach(function(event) {
    input.addEventListener(event, function() {
      if (inputFilter(this.value)) {
        this.oldValue = this.value;
        this.oldSelectionStart = this.selectionStart;
        this.oldSelectionEnd = this.selectionEnd;
      } else if (this.hasOwnProperty("oldValue")) {
        this.value = this.oldValue;
        this.setSelectionRange(this.oldSelectionStart, this.oldSelectionEnd);
      }
    });
  });
}


// Install input filters.
setInputFilter(document.getElementById("cph_tbCap"), function(value) {
  return /^\d*$/.test(value); });
setInputFilter(document.getElementById("cph_tbPartitaIva"), function(value) {
  return /^[0-9a-z]*$/i.test(value); });
setInputFilter(document.getElementById("cph_tbCodiceFiscale"), function(value) {
  return /^[0-9a-z]*$/i.test(value); });
/*
setInputFilter(document.getElementById("intTextBox"), function(value) {
  return /^-?\d*$/.test(value); });
setInputFilter(document.getElementById("uintTextBox"), function(value) {
  return /^\d*$/.test(value); });
setInputFilter(document.getElementById("intLimitTextBox"), function(value) {
  return /^\d*$/.test(value) && (value === "" || parseInt(value) <= 500); });
setInputFilter(document.getElementById("floatTextBox"), function(value) {
  return /^-?\d*[.,]?\d*$/.test(value); });
setInputFilter(document.getElementById("currencyTextBox"), function(value) {
  return /^-?\d*[.,]?\d{0,2}$/.test(value); });
setInputFilter(document.getElementById("hexTextBox"), function(value) {
  return /^[0-9a-f]*$/i.test(value); });
*/
</script>


<table cellpadding="1" cellspacing="5" border="0" width="100%" runat="server" id="tConclusa" visible="false">
    <tr>
        <td colspan="2"><br /><br /><hr size="1" /><br /></td>
    </tr>
    <tr>
        <td colspan="2" align="center">
        <b>Registrazione conclusa con successo!</b><br /><br />
         <u>Ti abbiamo inviato una mail di conferma con i tuoi dati d'accesso.</u>
        <br /><br /><br />
        Ora puoi accedere all'area My Account per effettuare gli ordini.<br /><br />
        </td>
    </tr>   
    <tr>
        <td colspan="2" ><br /><hr size="1"/><br /></td>
    </tr>
</table>

<table cellpadding="1" cellspacing="5" border="0" width="100%" runat="server" id="tAggiorna" visible="false">
    <tr>
        <td colspan="2"><br /><hr size="1"/><br /></td>
    </tr>
    <tr>
        <td colspan="2" align="center">
        <br />I tuoi dati sono stati correttamente aggiornati!<br /><br />
        <a href="default.aspx"><b>Continua</b></a>
        <br /><br />
        </td>
    </tr>   
    <tr>
        <td colspan="2" ><br /><hr size="1"/><br /></td>
    </tr>
</table>

<table cellpadding="1" cellspacing="5" border="0" width="100%" runat="server" id="tError" visible="false">
    <tr>
        <td colspan="2"><br /><br /><hr size="1"/><br /></td>
    </tr>
    <tr>
        <td colspan="2" align="center">
        <b><font color="#E12825">ATTENZIONE</font></b><br /><br />
         <u>Codice Fiscale o Partita Iva già presenti in anagrafica</u>
        <br /><br /><br />
        Non è possibile effeturare la registrazione, contattare l'azienda<br /><br />
        <b><a href='javascript:window.history.back();'>« Torna Indietro</a></b>
        <br /><br />
        </td>
    </tr>   
    <tr>
        <td colspan="2" ><br /><hr size="1"/><br /></td>
    </tr>
</table>

</asp:Content>

