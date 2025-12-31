<%@ Application Language="VB" %>

<script runat="server">

    Sub Application_Start(ByVal sender As Object, ByVal e As EventArgs)
        Application.Add("DataAggiornamentoOfferte", "01/01/1900")
        Application.Add("Last_Banner", "0")
        Application.Add("Last_Banner_Posizione_Sinistra_1", "0")
        Application.Add("Last_Banner_Posizione_Sinistra_2", "0")
        Application.Add("Last_Banner_Posizione_Sinistra_3", "0")
        Application.Add("Last_Banner_Posizione_Destra_1", "0")
        Application.Add("Last_Banner_Posizione_Destra_2", "0")
        Application.Add("Last_Banner_Posizione_Destra_3", "0")
        Application.Add("Semaforo", New Object)
        Application.Add("Campo_Ricerca", "cosa cerchi? Monitor TV PC Karaoke etc ...")
    End Sub

    ' Header di sicurezza base (non rompe layout/template)
    Sub Application_BeginRequest(ByVal sender As Object, ByVal e As EventArgs)
        Try
            Response.Headers.Set("X-Content-Type-Options", "nosniff")
            Response.Headers.Set("X-Frame-Options", "SAMEORIGIN")
            Response.Headers.Set("Referrer-Policy", "strict-origin-when-cross-origin")
            Response.Headers.Set("Permissions-Policy", "geolocation=(), microphone=(), camera=()")

            ' HSTS solo se HTTPS
            If Request.IsSecureConnection Then
                Response.Headers.Set("Strict-Transport-Security", "max-age=31536000")
            End If
        Catch
            ' no-op
        End Try
    End Sub

    Sub Application_End(ByVal sender As Object, ByVal e As EventArgs)
        ' Codice eseguito alla chiusura dell'applicazione
    End Sub

    Sub Application_Error(ByVal sender As Object, ByVal e As EventArgs)
    Try
        Dim ex As Exception = Server.GetLastError()

        ' Log minimale in App_Data (cartella normalmente scrivibile)
        Dim logDir As String = Server.MapPath("~/App_Data")
        Dim logFile As String = System.IO.Path.Combine(logDir, "errors.log")

        Dim msg As String =
            "-----" & Environment.NewLine &
            DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") & Environment.NewLine &
            Request.Url.ToString() & Environment.NewLine &
            If(ex Is Nothing, "(no exception)", ex.ToString()) & Environment.NewLine

        System.IO.File.AppendAllText(logFile, msg)

    Catch
        ' Non blocco ulteriori errori
    End Try

    ' Evito info leak verso l'utente
    Try
        Server.ClearError()
        Response.Redirect("~/404.aspx", False) ' se non hai 404.aspx, cambia con ~/Default.aspx o una pagina errore esistente
        Context.ApplicationInstance.CompleteRequest()
    Catch
    End Try
    End Sub

    Sub Session_Start(ByVal sender As Object, ByVal e As EventArgs)
        Session.Item("Pagina_visitata_Articoli") = ""
        Session.Item("Prezzo_MIN") = ""
        Session.Item("Prezzo_MAX") = ""
        Session.Item("Inserimento_User") = ""
        Session.Item("Inserimento_Password") = ""
        Session("ID_Listino_Personalizzato") = 0
        Session.Item("Crea_Vista_Promo") = 0
        Session("LoginUltimoAccesso") = "Primo Accesso"
        Session("AbilitaListino") = 0
        Session.Item("StavonelCarrello") = 0
        Session.Item("Popup") = 1

        Session("Iva_Utente") = -1
        Session("IvaReverseCharge_Utente") = -1
        Session("IdIvaReverseCharge_Utente") = -1
        Session("DescrizioneEsenzioneIva") = ""
        Session("IdEsenzioneIva") = -1
        Session("AbilitatoIvaReverseCharge") = 0
    End Sub

    Sub Session_End(ByVal sender As Object, ByVal e As EventArgs)
        Session.Item("Prezzo_MIN") = ""
        Session.Item("Prezzo_MAX") = ""
        Session.Item("Inserimento_User") = ""
        Session.Item("Inserimento_Password") = ""
        Session("ID_Listino_Personalizzato") = 0
        Session.Item("Crea_Vista_Promo") = 0
        Session("LoginUltimoAccesso") = "Primo Accesso"
        Session("AbilitaListino") = 0
        Session.Item("StavonelCarrello") = 0

        Session.Item("Pagina_visitata") = "default.aspx"
        Session.Item("UtentiId") = 0
    End Sub

</script>
