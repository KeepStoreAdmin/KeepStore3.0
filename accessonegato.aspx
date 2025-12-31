<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="accessonegato.aspx.vb" Inherits="accessonegato" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">

    <h1>Accesso negato</h1>
    <br />

    <b>
        Per eseguire l'operazione richiesta è necessario registrarsi al sito
        <asp:Label ID="lblUrl" runat="server" Text="Url" Font-Bold="True"></asp:Label>
    </b>

    <br /><br />

    Se sei già un utente registrato, clicca sul link
    <b>“Accedi / Registrati”</b> in alto a destra, inserisci la tua
    <i>Username</i> e la tua <i>Password</i> ed effettua il <b>Login</b>.
    Dopo l’accesso potrai usare la voce <b>“My Account”</b> per gestire i tuoi dati e consultare ordini e documenti.

    <br /><br />

    <a href="remind.aspx">
        <span style="text-decoration: underline">
            Non ricordi i tuoi dati d'accesso al sito
            <asp:Label ID="lblSito" runat="server" Text="sito" Font-Underline="True"></asp:Label>?
        </span>
    </a>

    <br /><br /><br />

    <b>
        <asp:Label ID="Label1" ForeColor="#e12825" runat="server"
            Text="Se non sei registrato, registrati subito! È gratis e potrai usufruire di tanti vantaggi:">
        </asp:Label>
        <br />
        <ul>
            <li>Assegnazione di scontistiche dei prodotti</li>
            <li>Richiedere quotazioni per quantità</li>
            <li>Inviare ordini e visualizzare il loro stato in tempo reale</li>
            <li>Visualizzare in &quot;My Account&quot; tutte le tue movimentazioni</li>
            <li>Ricevere promozioni ed offerte personalizzate</li>
            <li>Effettuare richieste di resi merce direttamente online</li>
            <li>Accumulare punti fedeltà per i premi</li>
        </ul>
    </b>

    <p align="center">
        <asp:Button ID="Button1" runat="server"
            Text="REGISTRATI ADESSO"
            PostBackUrl="registrazione.aspx" />
    </p>

    <hr />

</asp:Content>
