<%@ Page Title="" Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="responseClient.aspx.vb" Inherits="BancaSella_responseClient" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cph" Runat="Server">
    <table>
        <tr>
            <td>Errore pagamento ordine <b>n° <%= shopTransactionID %></b></td>
        </tr>
        <tr>
            <td>Specifica Errore: <b><%= errore %></b></td>
        </tr>
        <tr>
            Si prega di contattare il venditore
        </tr>
    </table>
</asp:Content>

