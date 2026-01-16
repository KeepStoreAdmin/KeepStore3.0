<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="Contattaci.aspx.vb" Inherits="Contattaci" title="Untitled Page" %>
<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" Runat="Server">
</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="MainContent" Runat="Server">
    	<div>
	  <div class="form-group">
		<label for="TextBox_nome">Nome</label>
		<asp:TextBox ID="TextBox_nome" runat="server" CssClass="form-control"></asp:TextBox>
	  </div>
	  <div class="form-group">
		<label for="TextBox_email">Email</label>
		<asp:TextBox ID="TextBox_email" runat="server" CssClass="form-control"></asp:TextBox>
	  </div>
	  <div class="form-group">
		<label for="DropDownList_subject">Oggetto</label>
		<asp:DropDownList ID="DropDownList_subject" CssClass="form-control" runat="server">
			<asp:ListItem Selected="True">Informazioni generali</asp:ListItem>
			<asp:ListItem>Informazioni sulla spedizione</asp:ListItem>
			<asp:ListItem>Informazioni sul prodotto</asp:ListItem>
			<asp:ListItem>Informazioni sul pagamento</asp:ListItem>
		</asp:DropDownList>
	  </div>
	  <div class="form-group">
		<label for="TextBox_email">Messaggio</label>
		<asp:TextBox ID="TextBox_testo" runat="server" CssClass="form-control" TextMode="MultiLine" ></asp:TextBox>
	  </div>
	  <asp:Button ID="Button_Invia" runat="server" Text="Invia Messaggio" CssClass="btn btn-primary" />
      <asp:Label ID="Label_esito" runat="server" Font-Bold="True" ForeColor="Red" Text="Label"></asp:Label>
	</div>

</asp:Content>

