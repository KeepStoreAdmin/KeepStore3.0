<%@ Application Language="VB" %>

<script runat="server">

    Sub Application_Start(ByVal sender As Object, ByVal e As EventArgs)
        Application.Add("DataAggiornamentoOfferte", "01/01/1900")
        'Codice per la gestione delle pubblicità
        Application.Add("Last_Banner", "0")
        Application.Add("Last_Banner_Posizione_Sinistra_1", "0")
        Application.Add("Last_Banner_Posizione_Sinistra_2", "0")
        Application.Add("Last_Banner_Posizione_Sinistra_3", "0")
        Application.Add("Last_Banner_Posizione_Destra_1", "0")
        Application.Add("Last_Banner_Posizione_Destra_2", "0")
        Application.Add("Last_Banner_Posizione_Destra_3", "0")
        'Semaforo di accesso
        Application.Add("Semaforo", New Object)
        'Scritta nel campo di ricerca
        Application.Add("Campo_Ricerca", "cosa cerchi? Monitor TV PC Karaoke etc ...")
    End Sub
    
    Sub Application_End(ByVal sender As Object, ByVal e As EventArgs)
        ' Codice eseguito alla chiusura dell&apos;applicazione
    End Sub
        
    Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
        ' Codice eseguito in caso di errore non gestito
    End Sub

    Sub Session_Start(ByVal sender As Object, ByVal e As EventArgs)
        ' Codice eseguito all&apos;avvio di una nuova sessione
        Session.Item("Pagina_visitata_Articoli") = ""
        Session.Item("Prezzo_MIN")=""
        Session.Item("Prezzo_MAX")=""
        Session.Item("Inserimento_User") = ""
        Session.Item("Inserimento_Password") = ""
        Session("ID_Listino_Personalizzato")=0
        Session.Item("Crea_Vista_Promo") = 0
        Session("LoginUltimoAccesso") = "Primo Accesso"
        Session("AbilitaListino") = 0
        Session.Item("StavonelCarrello") = 0
        Session.Item("Popup") = 1
        
        'Inizializzazione variabili per Esenzione Iva e Reverse Charge dell'Utente
        Session("Iva_Utente") = -1
        Session("IvaReverseCharge_Utente") = -1
        Session("IdIvaReverseCharge_Utente") = -1
        Session("DescrizioneEsenzioneIva") = ""
        Session("IdEsenzioneIva") = -1
        Session("AbilitatoIvaReverseCharge") = 0
    End Sub

    Sub Session_End(ByVal sender As Object, ByVal e As EventArgs)
        ' Codice eseguito al termine di una sessione. 
        ' Nota: l&apos;evento Session_End viene generato solo quando la modalità sessionstate
        ' è impostata su InProc nel file Web.config. Se tale modalità è impostata su StateServer 
        ' o su SQLServer, l&apos;evento non viene generato.
        Session.Item("Prezzo_MIN")=""
        Session.Item("Prezzo_MAX")=""
        Session.Item("Inserimento_User") = ""
        Session.Item("Inserimento_Password") = ""
        Session("ID_Listino_Personalizzato")=0
        Session.Item("Crea_Vista_Promo") = 0
        Session("LoginUltimoAccesso") = "Primo Accesso"
        Session("AbilitaListino") = 0
        Session.Item("StavonelCarrello") = 0
        
        'Importante per impostare la prima pagina visitata
        Session.Item("Pagina_visitata") = "default.aspx"
        
        Session.Item("UtentiId")=0
    End Sub
       
</script>