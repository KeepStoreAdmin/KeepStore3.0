<%@ Page Language="VB" AutoEventWireup="false" CodeFile="listini.aspx.vb" Inherits="test" MaintainScrollPositionOnPostBack="true"%>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" >
<head runat="server">
    <title>Listini Personalizzati - Entropic srl</title>
<style type="text/css">
/* body {
	color:#333;
	width:600px;
	font-size:14px;
	font-family:Verdana, Geneva, sans-serif;
	margin:0 auto;
	padding:0 100px;
}*/
a:focus {
outline: none;
}
a.trigger{
	position: absolute;
	background:#717171 url(Images/Immagini_Listini_Personalizzati/Slide/plus.png) 6% 55% no-repeat;
	text-decoration: none;
	font-size: 16px;
	letter-spacing:-1px;
	font-family: verdana, helvetica, arial, sans-serif;
	color:#fff;
	padding:7px 15px 6px 30px;
	font-weight: bold;
	
	z-index:2;
}
a.trigger.right {
	right: 0;
	border-bottom-left-radius: 5px;
	border-top-left-radius: 5px;
	-moz-border-radius-bottomleft: 5px;
	-moz-border-radius-topleft: 5px;
	-webkit-border-bottom-left-radius: 5px;
	-webkit-border-top-left-radius: 5px;
}
a.trigger:hover {
	background-color:#df4c49;
}
a.active.trigger {
	background:#df4c49 url(Images/Immagini_Listini_Personalizzati/Slide/minus.png) 6% 55% no-repeat;
}
.panel {
	border: solid 1px;
	border-color: #E12825;
	position: absolute;
	display: none;
	background: #ffffff;
	width: 700px;
	height: auto;
	z-index:1;
}

.panel.right {
	width: 700px;
	right: 0;
	padding: 10px 50px 10px 10px;
	border-bottom-left-radius: 15px;
	border-top-left-radius: 15px;
	-moz-border-radius-bottomleft: 15px;
	-moz-border-radius-topleft: 15px;
	-webkit-border-bottom-left-radius: 15px;
	-webkit-border-top-left-radius: 15px;
}
.panel.right h1 { font-size: 13pt; color:#000000;}
.panel.right h2 { font-size: 12pt; color:#000000;}
.panel.right h3 { font-size: 10pt; color:#000000;}
.panel.right ul { padding-top: 0px;color:#000000;}

.panel p {
	font-size:11px;
}
</style>
<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>
<script type="text/javascript" src="Public/script/jquery.slidePanel.min.js"></script>

<script type="text/javascript">
$(document).ready(function(){
	
	// default settings
	// $('.panel').slidePanel();
		
	$('#panel2').slidePanel({
		triggerName: '#trigger2',
		triggerTopPos: '60px',
		panelTopPos: '60px'
	});
	
});
</script>
</head>
<body style=" width: 100%; height:100%; margin:0; padding:0;">
<a href="#" id="trigger2" class="trigger right">Istruzioni d'uso</a>
<div id="panel2" class="panel right" style="right: 0px; top: 0px">
	<h1>Istruzioni per la gesione dei listini personalizzati</h1>
	<h2>Creazione di un nuovo listino</h2>
	<h3>Utilizzare il pannello &quot;Crea nuovo listino&quot; specificando</h3>
	<ul>
	  <li>il nome del listino</li>
	  <li>se visualizzare i prezzi con o senza iva</li>
	  <li>il tipo di arrotondamento</li>
	</ul>
	<h2>Dopo aver creato un nuovo listino è necessario scegliere la merce da associare al listino.</h2>
	<h3>Per fare ciò utilizzare il pannello &quot;Seleziona Listino&quot; e</h3>
	<ul>
		<li>scegliere il listino da modificare</li>
		<li>selezionare dalla griglia sottostante le categorie da aggiungere al listino</li>
		<li>per ogni categoria merciologica è possibile indicare
			<ul>
				<li>se attivarla nel listino selezionato (ceck &quot;Attiva&quot;)</li>
				<li>la percentuale di ricarico da applicare (box &quot;Ricarico (%)&quot;)</li>
				<li>se attivare nel listino le eventuali promozioni presenti nella categoria in questione</li>
			</ul>
		</li>
		<li>per semplificare la selezione delle categorie è consigliabile l'utilizzo del filtro per isolare i settori</li>
		<li>per applicare la stesse impostazioni di categoria ad un intero settore usare i controlli del pannello &quot;Modifica rapida&quot;</li>
	</ul>
	<h2>Ogni listino personalizzato può essere esportato in due formati:</h2>
	<ul>
		<li>PDF con indice di selezione rapida, consultabile e stampabile</li>
		<li>XLS, ovvero foglio elettronico di calcolo excel, con la possibilità di compilare in maniera automatizzata un preventivo stampabile</li>
		</ul>
	<h2>A tutti i listini di ogni utente è possibile associare un logo personalizzato usando il pannello &quot;Upload logo&quot;</h2>
</div>
    <div style=" background-image:url(Images/Immagini_Listini_Personalizzati/Barra_superiore/Sfondo.png);  background-repeat:repeat-x; :100%; height:50px; margin:auto; position:inherit; top:-20px; left:0px; padding:0px;">
        <asp:HyperLink ID="HyperLink2" runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/HomePage/Home.png"
            NavigateUrl="default.aspx" Style="left: 10px; position: relative; top: 5px" Target="_self">HyperLink</asp:HyperLink></div>
    <form id="form1" runat="server">
    <div>
        <asp:SqlDataSource ID="SqlData_Listino_Personalizzato" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT listini_personalizzati.* FROM listini_personalizzati" UpdateCommand="UPDATE listini_personalizzati SET Nome_Listino = @Param2 WHERE (ID = @Param1)">
            <UpdateParameters>
                <asp:SessionParameter Name="@Param1" SessionField="ID_Listino_Personalizzato" />
                <asp:ControlParameter ControlID="TextBox_CambiaNomeListino" Name="@Param2" PropertyName="Text" />
            </UpdateParameters>
        </asp:SqlDataSource>
        <asp:SqlDataSource ID="SqlData_Dettagli_Listino_Personalizzato" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            DeleteCommand="DELETE FROM dettagli_listino_personalizzato WHERE (ID_Listino_Personalizzato = @Param1)"
            InsertCommand="INSERT INTO dettagli_listino_personalizzato(ID_Listino_Personalizzato, ID_Settore, ID_Categoria, ID_Tipologia, Promo, Ricarico) VALUES (1,1,1,1,1,1)"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT dettagli_listino_personalizzato.* FROM dettagli_listino_personalizzato">
            <DeleteParameters>
                <asp:SessionParameter Name="@Param1" SessionField="ID_Listino_Personalizzato" />
            </DeleteParameters>
        </asp:SqlDataSource>
        <asp:SqlDataSource ID="SqlData_ListaListiniUtente" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT ID, Nome_Listino, ID_Utente, IVA, Data_Creazione FROM listini_personalizzati">
        </asp:SqlDataSource>
        &nbsp; &nbsp;&nbsp;
         &nbsp;<asp:Panel ID="Panel_Principale" runat="server" Height="600px" Visible="False" Width="960px" Style="margin:auto" Font-Bold="True" Font-Names="ARIAL">
            <asp:SqlDataSource ID="SqlData_InfoUtente" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                SelectCommand="SELECT Id, Codice, TipoUtente, Azienda, RagioneSociale, CognomeNome, Piva, Indirizzo, Citta, Provincia, Cap, CodiceFiscale, Telefono, Cellulare, Fax, Email, Listino, Url, Privacy, Abilitato FROM vutenti WHERE (Abilitato > 0)">
            </asp:SqlDataSource>
             <br />
             <table id="Table7" width="945" height="300" border="0" cellpadding="0" cellspacing="0">
	            <tr>
		            <td colspan="2" style="height: 89px">
			        <img src="Images/Immagini_Listini_Personalizzati/InfoUtente/Info_Utente_01.png" width="945" height="89" alt=""></td>
	            </tr>
	            <tr>
		            <td style="padding-left:20px; padding-top:10px; font-size: 10pt; color: black;"> 
                   <asp:Image ID="logoListino" runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/LogoAzienda/LogoNullo.png" Height="100px" /><br />
                   <br />
                   MODULO UPLOAD LOGO<br />
                   <asp:FileUpload ID="FileUpload1" runat="server" Width="240px" Height="25px" ToolTip="Upload di file sul server"/>
                   <asp:Button ID="ButtonInvio" runat="server" Text="Upload Logo" Height="25px" />
                   <asp:Button ID="ButtonEliminaLogo" runat="server" Text="Elimina Logo" Height="25px" />
                   <asp:Label ID="FileUploadMessage" runat="server" Width="460px" Font-Names="arial" Font-Size="11pt"></asp:Label>&nbsp;</td>
		            <td style="padding-right:20px;">
                    		            <asp:FormView DataSourceID="SqlData_InfoUtente" Font-Names="arial" Font-Size="10pt" ID="FormView_InfoUtente" runat="server" Width="436px" Font-Bold="False">
                        <PagerSettings PageButtonCount="1" />
                        <EditItemTemplate>
                            Id:
                            <asp:Label ID="IdLabel1" runat="server" Text='<%# Eval("Id") %>'></asp:Label><br />
                            Codice:
                            <asp:TextBox ID="CodiceTextBox" runat="server" Text='<%# Bind("Codice") %>' /><br />
                            TipoUtente:
                            <asp:Label ID="TipoUtenteLabel1" runat="server" Text='<%# Eval("TipoUtente") %>' /><br>
                            Azienda:
                            <asp:TextBox ID="AziendaTextBox" runat="server" Text='<%# Bind("Azienda") %>' /><br/>
                            RagioneSociale:
                            <asp:TextBox ID="RagioneSocialeTextBox" runat="server" Text='<%# Bind("RagioneSociale") %>' /><br />
                            CognomeNome:
                            <asp:TextBox ID="CognomeNomeTextBox" runat="server" Text='<%# Bind("CognomeNome") %>' /><br>
                            Piva:
                            <asp:TextBox ID="PivaTextBox" runat="server" Text='<%# Bind("Piva") %>' /><br />
                            Indirizzo:
                            <asp:TextBox ID="IndirizzoTextBox" runat="server" Text='<%# Bind("Indirizzo") %>' /><br>
                            Citta:
                            <asp:TextBox id="CittaTextBox" runat="server" Text='<%# Bind("Citta") %>'>
                            </asp:TextBox><br>
                            Provincia:
                            <asp:TextBox ID="ProvinciaTextBox" runat="server" Text='<%# Bind("Provincia") %>'>
                            </asp:TextBox><br/>
                            Cap:
                            <asp:TextBox ID="CapTextBox" runat="server" Text='<%# Bind("Cap") %>'>
                            </asp:TextBox><br>
                            CodiceFiscale:
                            <asp:TextBox ID="CodiceFiscaleTextBox" runat="server" Text='<%# Bind("CodiceFiscale") %>'>
                            </asp:TextBox><br/>
                            Telefono:
                            <asp:TextBox ID="TelefonoTextBox" runat="server" Text='<%# Bind("Telefono") %>'>
                            </asp:TextBox><br>
                            Cellulare:
                            <asp:TextBox ID="CellulareTextBox" runat="server" Text='<%# Bind("Cellulare") %>'>
                    </asp:TextBox><br />
                            Fax:
                            <asp:TextBox ID="FaxTextBox" runat="server" Text='<%# Bind("Fax") %>' /><br />
                            Email:
                            <asp:TextBox ID="EmailTextBox" runat="server"
                        Text='<%# Bind("Email") %>' /><br />
                            Listino:
                            <asp:TextBox ID="ListinoTextBox" runat="server" Text='<%# Bind("Listino") %>' /><br>
                            Url:
                            <asp:TextBox id="UrlTextBox" runat="server" Text='<%# Bind("Url") %>'>
                            </asp:TextBox><br>
                            Privacy:
                            <asp:TextBox ID="PrivacyTextBox" runat="server" Text='<%# Bind("Privacy") %>'>
                            </asp:TextBox><br/>
                            Abilitato:
                            <asp:TextBox ID="AbilitatoTextBox" runat="server" Text='<%# Bind("Abilitato") %>'>
                            </asp:TextBox><br>
                            <asp:LinkButton CausesValidation="True" CommandName="Update" ID="UpdateButton" runat="server" Text="Aggiorna">
                            </asp:LinkButton>
                            <asp:LinkButton CausesValidation="False" CommandName="Cancel" ID="UpdateCancelButton" runat="server" Text="Annulla"/>
                        </EditItemTemplate>
                        <InsertItemTemplate>
                            Codice:
                            <asp:TextBox ID="CodiceTextBox" runat="server" Text='<%# Bind("Codice") %>'>
                            </asp:TextBox><br>
                            Azienda:
                            <asp:TextBox ID="AziendaTextBox" runat="server" Text='<%# Bind("Azienda") %>' /><br />
                            RagioneSociale:
                            <asp:TextBox ID="RagioneSocialeTextBox" runat="server"
                    Text='<%# Bind("RagioneSociale") %>' /><br />
                            CognomeNome:
                            <asp:TextBox ID="CognomeNomeTextBox" runat="server" Text='<%# Bind("CognomeNome") %>' /><br />
                            Piva:
                            <asp:TextBox ID="PivaTextBox" runat="server" Text='<%# Bind("Piva") %>'>
                            </asp:TextBox><br>
                            Indirizzo:
                            <asp:TextBox ID="IndirizzoTextBox" runat="server" Text='<%# Bind("Indirizzo") %>'>
                            </asp:TextBox><br />
                            Citta:
                            <asp:TextBox ID="CittaTextBox" runat="server" Text='<%# Bind("Citta") %>' /><br />
                            Provincia:
                            <asp:TextBox ID="ProvinciaTextBox" runat="server" Text='<%# Bind("Provincia") %>' /><br />
                            Cap:
                            <asp:TextBox ID="CapTextBox" runat="server" Text='<%# Bind("Cap") %>' /><br />
                            CodiceFiscale:
                            <asp:TextBox ID="CodiceFiscaleTextBox" runat="server" Text='<%# Bind("CodiceFiscale") %>'>
                            </asp:TextBox><br />
                            Telefono:
                            <asp:TextBox ID="TelefonoTextBox" runat="server" Text='<%# Bind("Telefono") %>'>
                            </asp:TextBox><br>
                            Cellulare:
                            <asp:TextBox ID="CellulareTextBox" runat="server" Text='<%# Bind("Cellulare") %>' /><br />
                            Fax:
                            <asp:TextBox ID="FaxTextBox" runat="server" Text='<%# Bind("Fax") %>' /><br />
                            Email:
                            <asp:TextBox ID="EmailTextBox" runat="server" Text='<%# Bind("Email") %>' /><br />
                            Listino:
                            <asp:TextBox ID="ListinoTextBox" runat="server" Text='<%# Bind("Listino") %>' /><br />
                            Url:
                            <asp:TextBox ID="UrlTextBox" runat="server" Text='<%# Bind("Url") %>' /><br />
                            Privacy:
                            <asp:TextBox ID="PrivacyTextBox" runat="server" Text='<%# Bind("Privacy") %>' /><br />
                            Abilitato:
                            <asp:TextBox ID="AbilitatoTextBox" runat="server" Text='<%# Bind("Abilitato") %>' /><br>
                            <asp:LinkButton ID="InsertButton" runat="server" CausesValidation="True" CommandName="Insert" Text="Inserisci">
                            </asp:LinkButton>
                            <asp:LinkButton CausesValidation="False" CommandName="Cancel" ID="InsertCancelButton" runat="server" Text="Annulla">
                            </asp:LinkButton>
                        </InsertItemTemplate>
                        <ItemTemplate >
                            <strong>RagioneSociale:</strong>
                            <asp:Label ID="RagioneSocialeLabel" runat="server" Text='<%# Bind("RagioneSociale") %>'></asp:Label>&nbsp;<br />
                            <strong>Cognome-Nome:</strong>
                            <asp:Label ID="CognomeNomeLabel" runat="server" Text='<%# Bind("CognomeNome") %>'></asp:Label>&nbsp;<br />
                            <strong>Piva:</strong>
                            <asp:Label ID="PivaLabel" runat="server" Text='<%# Bind("Piva") %>'></asp:Label><br />
                            <strong>Indirizzo:</strong>
                            <asp:Label ID="IndirizzoLabel" runat="server" Text='<%# Bind("Indirizzo") %>'></asp:Label><br />
                            <strong>Citta:</strong>
                            <asp:Label ID="CittaLabel" runat="server" Text='<%# Bind("Citta") %>'></asp:Label>
                            <strong>Provincia:</strong>
                            <asp:Label ID="ProvinciaLabel" runat="server" Text='<%# Bind("Provincia") %>'></asp:Label>
                            <strong>Cap:</strong>
                            <asp:Label ID="CapLabel" runat="server" Text='<%# Bind("Cap") %>'></asp:Label><br />
                            <strong>CodiceFiscale:</strong>
                            <asp:Label ID="CodiceFiscaleLabel" runat="server" Text='<%# Bind("CodiceFiscale") %>'></asp:Label><br />
                            <strong>Telefono:</strong>
                            <asp:Label ID="TelefonoLabel" runat="server" Text='<%# Bind("Telefono") %>'></asp:Label>
                            <strong>Cellulare:</strong>
                            <asp:Label ID="CellulareLabel" runat="server" Text='<%# Bind("Cellulare") %>'></asp:Label><br />
                            <strong>Fax:</strong>
                            <asp:Label ID="FaxLabel" runat="server" Text='<%# Bind("Fax") %>'></asp:Label>
                            <strong>Email:</strong>
                            <asp:Label ID="EmailLabel" runat="server" Text='<%# Bind("Email") %>'></asp:Label>
                            <strong>Url:</strong>
                            <asp:Label ID="UrlLabel" runat="server" Text='<%# Bind("Url") %>'></asp:Label>
                        </ItemTemplate>
                    </asp:FormView>
		            </td>
	            </tr>
	            <tr>
		            <td colspan="2">
			        <img src="Images/Immagini_Listini_Personalizzati/InfoUtente/Info_Utente_04.png" width="945" height="42" alt=""></td>
	            </tr>
            </table>
            <br />
        
            <asp:Panel ID="Panel_NuovoListino" runat="server" Height="100px" Width="945px" Font-Names="arial" Font-Size="10pt" BorderColor="Blue">
            <table id="Table_01" width="945" height="100" border="0" cellpadding="0" cellspacing="0">
	        <tr>
		        <td rowspan="2">
			    <img src="Images/Immagini_Listini_Personalizzati/Box/Sinistra.png" width="28" height="100" alt=""/></td>
		        <td style="width:890px; height:40px; background-position:left top; background-image:url(Images/Immagini_Listini_Personalizzati/Box/Crea_Listino.png); padding:0px; background-repeat:no-repeat; text-align:right">
			    <asp:Label ID="Label_Esito" runat="server" ForeColor="Yellow" Text="Label" Visible="False" Font-Bold="True" Font-Italic="True" Font-Size="11pt" Width="281px" style="padding-top:15px;" Height="13px"></asp:Label></td>
			    <td rowspan="2" style="width: 29px">
			    <img src="Images/Immagini_Listini_Personalizzati/Box/Destra.png" width="28" height="100" alt=""/></td>
	        </tr>
	        <tr>
		    <td width="890" height="60" style="font-size: 11px; font-family: Arial">
		    Nome Listino
                <asp:TextBox ID="TextBox_NomeListino" runat="server" Width="170px" Wrap="False" Font-Names="arial" Font-Size="10pt" Height="16px"></asp:TextBox>
                &nbsp;visualizza con IVA
                <asp:CheckBox ID="CheckBox_IVA" runat="server" Checked="True" Text=" " />
                &nbsp;&nbsp;Arrotonda per -&nbsp;<asp:RadioButton ID="RadioButton_Nessuno" runat="server"
                    Checked="True" GroupName="Scelta_Arrotondamento" Text="Nessuno" />
                <asp:RadioButton ID="RadioButton_Eccesso" runat="server" GroupName="Scelta_Arrotondamento"
                    Text="Eccesso" />&nbsp;<asp:RadioButton ID="RadioButton_Difetto" runat="server" GroupName="Scelta_Arrotondamento"
                        Text="Difetto" />
                &nbsp; &nbsp;&nbsp;&nbsp; &nbsp; &nbsp; &nbsp;
                <asp:ImageButton ID="ImageButton_CreaListino" runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/Pulsanti/Crea_Listino.png" style="position: relative; top: 8px; left: 6px;" /><br />
		    </td>
	        </tr>
            </table>
            </asp:Panel>
            <asp:Panel ID="Panel_ModificaListino" runat="server" Width="945px" Font-Names="arial" Font-Size="10pt" Height="100px">
                <table id="Table2" width="945" height="100" border="0" cellpadding="0" cellspacing="0">
	        <tr>
		        <td rowspan="2">
			    <img src="Images/Immagini_Listini_Personalizzati/Box/Sinistra.png" width="28" height="100" alt=""/></td>
		        <td style="width:890px; height:40px; background-position:left top; background-image:url(Images/Immagini_Listini_Personalizzati/Box/Modifica_Listino.png); padding:0px; background-repeat:no-repeat; text-align:right">
			    <asp:Label ID="Label_Cambia_Esito" runat="server" ForeColor="Yellow" Text="Label" Visible="False" Font-Bold="True" Font-Italic="True" Font-Size="11pt" Width="281px" style="padding-top:15px;" Height="13px"></asp:Label></td>
			    <td rowspan="2">
			    <img src="Images/Immagini_Listini_Personalizzati/Box/Destra.png" width="28" height="100" alt=""/></td>
	        </tr>
	        <tr>
		    <td width="890" height="60" style="font-size: 11px; font-family: Arial">
		    Nome Listino&nbsp;<asp:TextBox ID="TextBox_CambiaNomeListino" runat="server" Width="170px" Wrap="False" Font-Names="arial" Font-Size="10pt" Height="16px"></asp:TextBox>
                &nbsp;&nbsp;visualizza con &nbsp;IVA
                <asp:CheckBox ID="CheckBox_IVA2" runat="server" Text=" " />&nbsp;
                arrotonda per -&nbsp;<asp:RadioButton ID="RadioButton_Nessuno2" runat="server" Checked="True"
                    GroupName="Scelta_Arrotondamento2" Text="Nessuno" />
                <asp:RadioButton ID="RadioButton_Eccesso2" runat="server" GroupName="Scelta_Arrotondamento2"
                    Text="Eccesso" />&nbsp;<asp:RadioButton ID="RadioButton_Difetto2" runat="server"
                        GroupName="Scelta_Arrotondamento2" Text="Difetto" />&nbsp;&nbsp; &nbsp; &nbsp;
                &nbsp; &nbsp;&nbsp; 
                <asp:ImageButton ID="ImageButton_AggiornaListino" runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/Pulsanti/Aggiorna.png" style="position: relative; top: 8px; left: 8px;" /><br />
		    </td>
	        </tr>
            </table>
                <asp:SqlDataSource ID="SqlData_ProprietaListinoSelezionato" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT ID, Nome_Listino, ID_Utente, IVA, Data_Creazione, Arrotonda FROM listini_personalizzati">
                </asp:SqlDataSource>
                <asp:GridView ID="GridView_ProprietaListinoPersonalizzato" runat="server" DataSourceID="SqlData_ProprietaListinoSelezionato" AutoGenerateColumns="False" Visible="False">
                    <Columns>
                        <asp:BoundField DataField="ID" HeaderText="ID" InsertVisible="False" ReadOnly="True"
                            SortExpression="ID" />
                        <asp:BoundField DataField="Nome_Listino" HeaderText="Nome_Listino" SortExpression="Nome_Listino" />
                        <asp:BoundField DataField="ID_Utente" HeaderText="ID_Utente" SortExpression="ID_Utente" />
                        <asp:BoundField DataField="IVA" HeaderText="IVA" SortExpression="IVA" />
                        <asp:BoundField DataField="Data_Creazione" HeaderText="Data_Creazione" SortExpression="Data_Creazione" />
                        <asp:BoundField DataField="Arrotonda" HeaderText="Arrotonda" SortExpression="Arrotonda" />
                    </Columns>
                </asp:GridView>
                <br />
                <asp:SqlDataSource ID="SqlDataSource_ListinoSelezionato" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT dettagli_listino_personalizzato.ID, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.ID_Settore, dettagli_listino_personalizzato.ID_Categoria, dettagli_listino_personalizzato.ID_Tipologia, dettagli_listino_personalizzato.Promo, dettagli_listino_personalizzato.Ricarico, settori.Descrizione AS Descrizione_Settore, categorie.Descrizione AS Descrizione_Categoria, tipologie.Descrizione AS Descrizione_Tipologia FROM dettagli_listino_personalizzato INNER JOIN settori ON dettagli_listino_personalizzato.ID_Settore = settori.id INNER JOIN categorie ON dettagli_listino_personalizzato.ID_Categoria = categorie.id LEFT OUTER JOIN tipologie ON dettagli_listino_personalizzato.ID_Tipologia = tipologie.id WHERE (dettagli_listino_personalizzato.ID_Listino_Personalizzato = @Param1) ORDER BY Descrizione_Settore, Descrizione_Categoria, Descrizione_Tipologia">
                </asp:SqlDataSource>
                <br />
                <asp:GridView ID="GridView_ListinoSelezionato" runat="server" AutoGenerateColumns="False"
                    DataKeyNames="ID" DataSourceID="SqlDataSource_ListinoSelezionato" Width="937px">
                    <Columns>
                        <asp:BoundField DataField="ID" HeaderText="ID" InsertVisible="False" ReadOnly="True"
                            SortExpression="ID" />
                        <asp:BoundField DataField="ID_Listino_Personalizzato" HeaderText="ID_Listino_Personalizzato"
                            SortExpression="ID_Listino_Personalizzato" />
                        <asp:BoundField DataField="ID_Settore" HeaderText="ID_Settore" SortExpression="ID_Settore" />
                        <asp:BoundField DataField="ID_Categoria" HeaderText="ID_Categoria" SortExpression="ID_Categoria" />
                        <asp:BoundField DataField="ID_Tipologia" HeaderText="ID_Tipologia" SortExpression="ID_Tipologia" />
                        <asp:BoundField DataField="Promo" HeaderText="Promo" SortExpression="Promo" />
                        <asp:BoundField DataField="Ricarico" HeaderText="Ricarico" SortExpression="Ricarico" />
                        <asp:BoundField DataField="Descrizione_Settore" HeaderText="Descrizione_Settore"
                            SortExpression="Descrizione_Settore" />
                        <asp:BoundField DataField="Descrizione_Categoria" HeaderText="Descrizione_Categoria"
                            SortExpression="Descrizione_Categoria" />
                        <asp:BoundField DataField="Descrizione_Tipologia" HeaderText="Descrizione_Tipologia"
                            SortExpression="Descrizione_Tipologia" />
                    </Columns>
                    <RowStyle Font-Names="arial" Font-Size="10pt" />
                    <PagerStyle Font-Names="arial" Font-Size="10pt" />
                </asp:GridView>
                <br />
                <asp:SqlDataSource ID="SqlData_SettoriCategorieTipologieSelezionati" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT Descr_Settore, Descr_Categoria, Descr_Tipologia FROM vcategorietipologie GROUP BY Descr_Tipologia ORDER BY Descr_Settore, Descr_Categoria, Descr_Tipologia">
                </asp:SqlDataSource>
                <asp:GridView ID="GridView_SettoriCategorieTipologieSelezionati" runat="server" AutoGenerateColumns="False"
                    DataSourceID="SqlData_SettoriCategorieTipologieSelezionati">
                    <Columns>
                        <asp:BoundField DataField="Descr_Settore" HeaderText="Descr_Settore" SortExpression="Descr_Settore" />
                        <asp:BoundField DataField="Descr_Categoria" HeaderText="Descr_Categoria" SortExpression="Descr_Categoria" />
                        <asp:BoundField DataField="Descr_Tipologia" HeaderText="Descr_Tipologia" SortExpression="Descr_Tipologia" />
                    </Columns>
                </asp:GridView>
                &nbsp;&nbsp;
            </asp:Panel>
            <asp:Panel ID="Panel_SelezionaListino" runat="server" Height="100px" Width="945px" BorderStyle="None" BorderWidth="0px" Font-Names="Arial" Font-Size="10pt">
                <table id="Table3" width="945" height="100" border="0" cellpadding="0" cellspacing="0">
	        <tr>
		        <td rowspan="2">
			    <img src="Images/Immagini_Listini_Personalizzati/Box/Sinistra.png" width="28" height="100" alt=""/></td>
		        <td style="width:890px; height:40px; background-position:left top; background-image:url(Images/Immagini_Listini_Personalizzati/Box/Seleziona_Listino.png); padding:0px; background-repeat:no-repeat; text-align:right">
			    </td>
			    <td rowspan="2">
			    <img src="Images/Immagini_Listini_Personalizzati/Box/Destra.png" width="28" height="100" alt=""/></td>
	        </tr>
	        <tr>
		    <td width="890" height="60" style="font-size: 11px; font-family: Arial; vertical-align:middle">
		    <asp:DropDownList ID="DropDownList_ListiniUtente" runat="server" AutoPostBack="True"
                    DataSourceID="SqlData_ListaListiniUtente" DataTextField="Nome_Listino" DataValueField="ID"
                    Width="234px" Font-Names="arial" Font-Size="10pt" Height="25px">
                    <asp:ListItem Value="0">Seleziona Valore</asp:ListItem>
                </asp:DropDownList>
                &nbsp; &nbsp;&nbsp;<!-- <asp:ImageButton ID="ImageButton_EsportaPDF" runat="server"
                    ImageUrl="~/Images/Immagini_Listini_Personalizzati/Pulsanti/scarica_pdf.png" style="position: relative; top: 11px" /> -->
                &nbsp;&nbsp;
                <asp:ImageButton ID="ImageButton_EsportaEXCEL" runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/Pulsanti/scarica_excel.png" style="position: relative; top: 11px" />
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
                <asp:ImageButton ID="ImageButton_EliminaListino" runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/Pulsanti/Elimina_Listino.png" style="position: relative; top: 8px; left: 15px;" />&nbsp;<br />
		    </td>
	        </tr>
            </table>
                &nbsp;&nbsp;
                </asp:Panel>
             &nbsp;<br />
            <script runat="server">
                'funzione che cambia colore al filtro "settore" 
                Protected Function colora(ByVal descr) As String
                    If Request.QueryString("n") = descr Then
                        Return "font-weight: bold; color: navy; text-decoration: none"
                    Else
                        Return "font-weight: bold; color: white; text-decoration: none"
                    End If
                End Function
            </script>
            <asp:Panel ID="Panel_ListinoDaStampare" runat="server" Width="659px">
                <asp:SqlDataSource ID="SqlData_ListinoDaStampare" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT vsuperarticoli.id, vsuperarticoli.Codice, vsuperarticoli.Descrizione1, vsuperarticoli.MarcheDescrizione, vsuperarticoli.SettoriId, vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieId, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieId, vsuperarticoli.TipologieDescrizione, vsuperarticoli.GruppiId, vsuperarticoli.GruppiDescrizione, vsuperarticoli.SottoGruppiId, vsuperarticoli.SottogruppiDescrizione, vsuperarticoli.ArticoliIva, vsuperarticoli.Giacenza, vsuperarticoli.InOrdine, vsuperarticoli.Disponibilita, vsuperarticoli.Impegnata, vsuperarticoli.ArticoliListiniId, vsuperarticoli.NListino, vsuperarticoli.Prezzo, vsuperarticoli.PrezzoIvato, vsuperarticoli.OfferteID, vsuperarticoli.OfferteDettagliId, vsuperarticoli.OfferteDescrizione, vsuperarticoli.OfferteDataInizio, vsuperarticoli.OfferteDataFine, vsuperarticoli.OfferteDaListino, vsuperarticoli.OfferteAListino, vsuperarticoli.OfferteQntMinima, vsuperarticoli.OfferteMultipli, vsuperarticoli.OffertePrezzo, vsuperarticoli.OfferteSconto, vsuperarticoli.InOfferta, vsuperarticoli.PrezzoPromo, vsuperarticoli.PrezzoPromoIvato, dettagli_listino_personalizzato.ID_Listino_Personalizzato, dettagli_listino_personalizzato.Ricarico, dettagli_listino_personalizzato.Promo FROM vsuperarticoli LEFT OUTER JOIN dettagli_listino_personalizzato ON vsuperarticoli.SettoriId = dettagli_listino_personalizzato.ID_Settore AND vsuperarticoli.CategorieId = dettagli_listino_personalizzato.ID_Categoria AND vsuperarticoli.TipologieId = dettagli_listino_personalizzato.ID_Tipologia WHERE (dettagli_listino_personalizzato.ID_Listino_Personalizzato = 10) AND (vsuperarticoli.NListino = 5) ORDER BY vsuperarticoli.SettoriDescrizione, vsuperarticoli.CategorieDescrizione, vsuperarticoli.TipologieDescrizione, vsuperarticoli.id, vsuperarticoli.OfferteMultipli">
                </asp:SqlDataSource>
            <asp:Panel ID="Panel_Filtri" runat="server" Width="945px" HorizontalAlign="Center">
                <asp:SqlDataSource ID="SqlData_ListaSettoriFiltri" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT id, Descrizione FROM settori"></asp:SqlDataSource>
                <table id="Table4" width="945" height="auto" border="0" cellpadding="0" cellspacing="0">
	                <tr>
		                <td>
			            <a href="listini.aspx">
				        <img src="Images/Immagini_Listini_Personalizzati/Menu_Settori/Settori_01.png" width="252" height="47" border="0" alt=""/></a></td>
		                <td>
			            <img src="Images/Immagini_Listini_Personalizzati/Menu_Settori/Settori_02.png" width="693" height="47" alt=""/></td>
	               </tr>
	               <tr>
		                <td colspan="2" style=" background-position:left top; background-image:url(Images/Immagini_Listini_Personalizzati/Menu_Settori/Settori_03.png); width:945px; text-align:center;">
		                <asp:DataList ID="DataList_Settori" runat="server" CellSpacing="20" DataKeyField="id" DataSourceID="SqlData_ListaSettoriFiltri" RepeatColumns="4" RepeatDirection="Horizontal" style="color: white;" Width="866px" Font-Bold="True" Font-Italic="False" Font-Overline="False" Font-Strikeout="False" Font-Underline="False" Font-Names="arial" Font-Size="12pt">
                            <ItemTemplate>
                                <asp:HyperLink ID="HyperLink1" runat="server" Text='<%# Eval("Descrizione") %>' style='<%# colora(Eval("Descrizione")) %>' NavigateUrl='<%# "listini.aspx?f=" & Eval("Id") & "&n=" & Eval("Descrizione") %>'></asp:HyperLink>
                            </ItemTemplate>
                        </asp:DataList>
		                </td>
	               </tr>
	               <tr>
		                <td colspan="2">
			            <img src="Images/Immagini_Listini_Personalizzati/Menu_Settori/Settori_04.png" width="945" height="64" alt=""/></td>
	               </tr>
                </table>
                </asp:Panel>
                <asp:GridView ID="GridView_ListinoDaStampare" runat="server" AutoGenerateColumns="False"
                    DataKeyNames="id,ArticoliListiniId" DataSourceID="SqlData_ListinoDaStampare"
                    Width="659px" Font-Names="arial" Font-Size="6pt">
                    <Columns>
                        <asp:BoundField DataField="id" HeaderText="id" InsertVisible="False" ReadOnly="True"
                            SortExpression="id" />
                        <asp:BoundField DataField="Codice" HeaderText="Codice" SortExpression="Codice" />
                        <asp:BoundField DataField="Descrizione1" HeaderText="Descrizione1" SortExpression="Descrizione1" />
                        <asp:BoundField DataField="MarcheDescrizione" HeaderText="MarcheDescrizione" SortExpression="MarcheDescrizione" />
                        <asp:BoundField DataField="SettoriId" HeaderText="SettoriId" SortExpression="SettoriId" />
                        <asp:BoundField DataField="SettoriDescrizione" HeaderText="SettoriDescrizione" SortExpression="SettoriDescrizione" />
                        <asp:BoundField DataField="CategorieId" HeaderText="CategorieId" SortExpression="CategorieId" />
                        <asp:BoundField DataField="CategorieDescrizione" HeaderText="CategorieDescrizione"
                            SortExpression="CategorieDescrizione" />
                        <asp:BoundField DataField="TipologieId" HeaderText="TipologieId" SortExpression="TipologieId" />
                        <asp:BoundField DataField="TipologieDescrizione" HeaderText="TipologieDescrizione"
                            SortExpression="TipologieDescrizione" />
                        <asp:BoundField DataField="GruppiId" HeaderText="GruppiId" SortExpression="GruppiId" />
                        <asp:BoundField DataField="GruppiDescrizione" HeaderText="GruppiDescrizione" SortExpression="GruppiDescrizione" />
                        <asp:BoundField DataField="SottoGruppiId" HeaderText="SottoGruppiId" SortExpression="SottoGruppiId" />
                        <asp:BoundField DataField="SottogruppiDescrizione" HeaderText="SottogruppiDescrizione"
                            SortExpression="SottogruppiDescrizione" />
                        <asp:BoundField DataField="ArticoliIva" HeaderText="ArticoliIva" SortExpression="ArticoliIva" />
                        <asp:BoundField DataField="Giacenza" HeaderText="Giacenza" SortExpression="Giacenza" />
                        <asp:BoundField DataField="InOrdine" HeaderText="InOrdine" SortExpression="InOrdine" />
                        <asp:BoundField DataField="Disponibilita" HeaderText="Disponibilita" SortExpression="Disponibilita" />
                        <asp:BoundField DataField="Impegnata" HeaderText="Impegnata" SortExpression="Impegnata" />
                        <asp:BoundField DataField="ArticoliListiniId" HeaderText="ArticoliListiniId" InsertVisible="False"
                            ReadOnly="True" SortExpression="ArticoliListiniId" />
                        <asp:BoundField DataField="NListino" HeaderText="NListino" SortExpression="NListino" />
                        <asp:BoundField DataField="Prezzo" HeaderText="Prezzo" SortExpression="Prezzo" />
                        <asp:BoundField DataField="PrezzoIvato" HeaderText="PrezzoIvato" SortExpression="PrezzoIvato" />
                        <asp:BoundField DataField="OfferteID" HeaderText="OfferteID" SortExpression="OfferteID" />
                        <asp:BoundField DataField="OfferteDettagliId" HeaderText="OfferteDettagliId" SortExpression="OfferteDettagliId" />
                        <asp:BoundField DataField="OfferteDescrizione" HeaderText="OfferteDescrizione" SortExpression="OfferteDescrizione" />
                        <asp:BoundField DataField="OfferteDataInizio" HeaderText="OfferteDataInizio" SortExpression="OfferteDataInizio" />
                        <asp:BoundField DataField="OfferteDataFine" HeaderText="OfferteDataFine" SortExpression="OfferteDataFine" />
                        <asp:BoundField DataField="OfferteDaListino" HeaderText="OfferteDaListino" SortExpression="OfferteDaListino" />
                        <asp:BoundField DataField="OfferteAListino" HeaderText="OfferteAListino" SortExpression="OfferteAListino" />
                        <asp:BoundField DataField="OfferteQntMinima" HeaderText="OfferteQntMinima" SortExpression="OfferteQntMinima" />
                        <asp:BoundField DataField="OfferteMultipli" HeaderText="OfferteMultipli" SortExpression="OfferteMultipli" />
                        <asp:BoundField DataField="OffertePrezzo" HeaderText="OffertePrezzo" SortExpression="OffertePrezzo" />
                        <asp:BoundField DataField="OfferteSconto" HeaderText="OfferteSconto" SortExpression="OfferteSconto" />
                        <asp:BoundField DataField="InOfferta" HeaderText="InOfferta" SortExpression="InOfferta" />
                        <asp:BoundField DataField="PrezzoPromo" HeaderText="PrezzoPromo" SortExpression="PrezzoPromo" />
                        <asp:BoundField DataField="PrezzoPromoIvato" HeaderText="PrezzoPromoIvato" SortExpression="PrezzoPromoIvato" />
                        <asp:BoundField DataField="ID_Listino_Personalizzato" HeaderText="ID_Listino_Personalizzato"
                            SortExpression="ID_Listino_Personalizzato" />
                        <asp:BoundField DataField="Ricarico" HeaderText="Ricarico" SortExpression="Ricarico" />
                        <asp:BoundField DataField="Promo" HeaderText="Promo" SortExpression="Promo" />
                    </Columns>
                </asp:GridView>
            </asp:Panel>
            <asp:Panel ID="Panel_Listino" runat="server" Height="50px" Width="954px" style="font-size: 10pt; font-family: Arial">
                <asp:SqlDataSource ID="Sql_ListaSettori" runat="server" ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                    ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                    SelectCommand="SELECT DISTINCT categorie.id AS Id_Categoria, categorie.Descrizione AS Categoria, tipologie.id AS Id_Tipologia, tipologie.Descrizione AS Tipologia, settori.id AS Id_Settore, settori.Descrizione AS Settore, articoli.Abilitato, settori.Abilitato AS Expr1 FROM articoli INNER JOIN settori ON articoli.SettoriId = settori.id INNER JOIN categorie ON articoli.CategorieId = categorie.id LEFT OUTER JOIN tipologie ON articoli.TipologieId = tipologie.id WHERE (articoli.Abilitato > 0) AND (categorie.Abilitato > 0) AND (settori.Abilitato > 0) ORDER BY Settore, Categoria, Tipologia">
                </asp:SqlDataSource>
                <asp:Panel ID="Panel_ModificaRapida" runat="server" Height="120px" Width="946px" BackColor="White" ForeColor="Black">
                <table id="Table6" width="945" height="100" border="0" cellpadding="0" cellspacing="0">
	        <tr>
		        <td rowspan="2">
			    <img src="Images/Immagini_Listini_Personalizzati/Box/Sinistra.png" width="28" height="100" alt=""/></td>
		        <td style="width:890px; height:40px; background-position:left top; background-image:url(Images/Immagini_Listini_Personalizzati/Box/Modifica_Rapida.png); padding:0px; background-repeat:no-repeat; text-align:right">
			    </td>
			    <td rowspan="2">
			    <img src="Images/Immagini_Listini_Personalizzati/Box/Destra.png" width="28" height="100" alt=""/></td>
	        </tr>
	        <tr>
		    <td width="890" style="font-size: 11px; font-family: Arial; height: 60px;">
		    <asp:CheckBox ID="CheckBox_ImpostaAttiva_Tutti" runat="server" Font-Names="arial"
                    Font-Size="10pt" Text="Attiva" BackColor="White" Font-Bold="True" ForeColor="Black" Height="20px" Width="100px"/>&nbsp;
                    Ricarico(%)
                <asp:TextBox ID="TextBox_ImpostaRicarico_Tutti" runat="server" Font-Names="arial" Font-Size="10pt"
                    Width="40px"></asp:TextBox>&nbsp; &nbsp; &nbsp;<asp:CheckBox ID="CheckBox_ImpostaPromo_Tutti" runat="server"
                        Text="Promo" />
                    &nbsp;&nbsp; &nbsp; &nbsp;&nbsp;
		    <asp:ImageButton ID="ImageButton_ApplicaSelezione"
                        runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/Pulsanti/Applica_Selezione.png" style="position: relative; top: 8px"/>
		    </td>
	        </tr>
            </table>
                </asp:Panel>
                <br />
                <table id="Table5" width="945" height="29" border="0" cellpadding="0" cellspacing="0">
	                <tr>
		                <td width="492" height="29">
                <asp:Label ID="Label_SettoreSelezionato" runat="server" Font-Bold="True" Font-Names="arial"
                    Font-Size="15pt" Font-Underline="True" ForeColor="Navy" Style="text-align: center"></asp:Label></td>
		                <td>
                            <asp:ImageButton ID="ImageButton_ResettaTutto" runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/Pulsanti_Reset/Pulsanti-Reset_02.png" /></td>
		                <td>
                            <asp:ImageButton ID="ImageButton_ResettaSelezionati" runat="server" ImageUrl="~/Images/Immagini_Listini_Personalizzati/Pulsanti_Reset/Pulsanti-Reset_03.png" /></td>
	                </tr>
                </table>
        
                <asp:GridView ID="GridView_ListinoCompleto" runat="server" AutoGenerateColumns="False"
                    DataSourceID="Sql_ListaSettori" GridLines="None" PageSize="30" Width="945px" BorderColor="Red" BorderStyle="Solid" BorderWidth="3px">
                    <Columns>
                        <asp:TemplateField HeaderText="ID" Visible="False">
                            <ItemTemplate>
                                <asp:Label ID="Label_IDSettore" runat="server" Text='<%# Eval("Id_Settore") %>'></asp:Label><br />
                                <asp:Label ID="Label_IDCategoria" runat="server" Text='<%# Eval("Id_Categoria") %>'></asp:Label><br />
                                <asp:Label ID="Label_IDTipologia" runat="server" Text='<%# Eval("Id_Tipologia") %>'></asp:Label>
                            </ItemTemplate>
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Settore &gt; Categoria &gt; Tipologia">
                            <ItemTemplate>
                                <asp:Label ID="Label1" runat="server" Font-Bold="False" Text='<%# Eval("Settore") %>'></asp:Label>
                                <strong>&gt;</strong>
                                <asp:Label ID="Label2" runat="server" Text='<%# Eval("Categoria") %>'></asp:Label>
                                <asp:Label ID="Label3" runat="server" Text='<%# Eval("Tipologia") %>'></asp:Label>
                            </ItemTemplate>
                            <ItemStyle HorizontalAlign="Left" VerticalAlign="Middle" />
                            <HeaderStyle HorizontalAlign="Left" VerticalAlign="Middle" />
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Attivo">
                            <ItemTemplate>
                                <asp:CheckBox ID="CheckBox_Attivo" runat="server" BorderStyle="None" OnCheckedChanged="CheckBox_Attivo_CheckedChanged" AutoPostBack="True" />
                            </ItemTemplate>
                            <ItemStyle HorizontalAlign="Center" VerticalAlign="Middle" />
                            <HeaderStyle HorizontalAlign="Center" VerticalAlign="Middle" />
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Ricarico (%)">
                            <ItemTemplate>
                                <asp:TextBox ID="TextBox_Ricarico" runat="server" Width="30px" AutoPostBack="True" OnTextChanged="TextBox_Ricarico_TextChanged"></asp:TextBox>
                            </ItemTemplate>
                            <ItemStyle HorizontalAlign="Center" VerticalAlign="Middle" />
                            <HeaderStyle HorizontalAlign="Center" VerticalAlign="Middle" />
                        </asp:TemplateField>
                        <asp:TemplateField HeaderText="Promo">
                            <ItemTemplate>
                                <asp:CheckBox ID="CheckBox_Promo" runat="server" BorderStyle="None" OnCheckedChanged="CheckBox_Promo_CheckedChanged" AutoPostBack="True" />
                            </ItemTemplate>
                            <ItemStyle HorizontalAlign="Center" VerticalAlign="Middle" />
                            <HeaderStyle HorizontalAlign="Center" VerticalAlign="Middle" />
                        </asp:TemplateField>
                    </Columns>
                    <RowStyle BackColor="White" Font-Names="arial" Font-Size="10pt" />
                    <PagerStyle Font-Names="arial" Font-Size="10pt" BorderColor="MidnightBlue" BorderStyle="Solid" BorderWidth="1px" />
                    <AlternatingRowStyle BackColor="Gainsboro" />
                </asp:GridView>
            </asp:Panel>
            <br />
        </asp:Panel>
    
    </div>
    </form>
</body>
</html>
