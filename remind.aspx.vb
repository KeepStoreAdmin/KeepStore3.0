Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Net.Mail

Partial Class Remind
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        'Me.lblSito.Text = Session("AziendaNome")

        If Me.IsPostBack Then
            If Me.tbEmail.Text <> "" Then
                RecuperaDati()
            End If
        End If

    End Sub

    Public Sub RecuperaDati()

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "Select * from vlogin where AziendeID=?AziendeID and Email=?Email And Abilitato=1 and UtentiAbilitato=1"
        cmd.Parameters.AddWithValue("?AziendeID", Session("AziendaID"))
        cmd.Parameters.AddWithValue("?Email", Me.tbEmail.Text)
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            'Me.tCerca.Visible = False
            Me.lblOk.Visible = True
            Email(dr.Item("CognomeNome"), dr.Item("Username"), dr.Item("Password"), dr.Item("email"))
            'Email(dr)
        Else
            Me.lblerror.Visible = True
        End If

        dr.Close()
        dr.Dispose()

        cmd.Dispose()

        conn.Close()
        conn.Dispose()

    End Sub

    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreInit
        Try
            If Request.UrlReferrer.AbsoluteUri.Contains("coupon") Then
                Page.MasterPageFile = "Coupon.master"
            Else
                Page.MasterPageFile = "Page.master"
            End If
        Catch
        End Try
    End Sub

    Public Sub Email(ByVal nomecognome As String, ByVal user As String, ByVal pass As String, ByVal email As String)

        Dim oMsg As MailMessage = New MailMessage()
        oMsg.From = New MailAddress(Session("AziendaEmail"), Session("AziendaNome"))
        oMsg.To.Add(email)
        oMsg.Subject = "Dati d'accesso al sito " & Session("AziendaNome")
        oMsg.Body = "<font face=verdana size= 2>Gentile <b>" & nomecognome & "</b>, come da tua richiesta," & _
                    "<br>ti ricordiamo i dati d'accesso per accedere al sito <b>" & Session("AziendaNome") & "</b>:" & _
                    "<br><br>Username = <b>" & user & "</b>" & _
                    "<br>Password = <b>" & pass & "</b>" & _
                    "<br><br><br>Lo staff di <b>" & Session("AziendaNome") & "</b><br><a href=http://" & Session("AziendaUrl") & ">" & Session("AziendaUrl") & "</a></font>"

        oMsg.IsBodyHtml = True

        Dim oSmtp As SmtpClient = New SmtpClient(Session("smtp"))
        oSmtp.DeliveryMethod = SmtpDeliveryMethod.Network

        Dim oCredential As System.Net.NetworkCredential = New System.Net.NetworkCredential(CType(Session.Item("User_smtp"), String), CType(Session.Item("Password_smtp"), String))
        oSmtp.UseDefaultCredentials = True
        oSmtp.Credentials = oCredential

        oSmtp.Send(oMsg)

    End Sub


    Public Sub Email(ByVal dr As MySqlDataReader)

        Dim oMsg As MailMessage = New MailMessage()
        oMsg.From = New MailAddress(Session("AziendaEmail"), Session("AziendaNome"))
        oMsg.To.Add(dr.Item("email"))
        oMsg.Subject = "Dati di accesso al sito " & Session("AziendaNome")
        oMsg.Body = "<font face=arial size=2 color=black>Gentile " & dr.Item("CognomeNome") & "," & _
                    "<br>Le comunichiamo i suoi dati di accesso al sito web <u>" & Session("AziendaUrl") & "</u>" & _
                    "<br><br><b>Username:</b> " & dr.Item("Username") & "<br><b>Password:</b> " & dr.Item("Password") & "<br><b>Email:</b> " & dr.Item("Email") & " </b>" & _
                    "<br><br>Di seguito, Le riepiloghiamo i dati che ci ha fornito, pregandola di controllarne la correttezza." & _
                    "<br>Se necessario potrà comunque modificare tali dati accedendo alla sezione <i>MY ACCOUNT</i>.</font>" & _
                    "<br><br><table cellspacing=3 cellpadding=3 style='font-family:arial;font-size:9pt'>" & _
                    "<tr><td bgcolor=whitesmoke>Nome:</td><td>" & dr.Item("CognomeNome") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Cognome/Rag.Sociale:</td><td>" & dr.Item("RagioneSociale") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Codice Fiscale:</td><td>" & dr.Item("CodiceFiscale") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Partita Iva:</td><td>" & dr.Item("PIva") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Indirizzo Principale:</td><td>" & dr.Item("Indirizzo") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Città:</td><td>" & dr.Item("Citta") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Provincia:</td><td>" & dr.Item("provincia") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Cap:</td><td>" & dr.Item("cap") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Telefono:</td><td>" & dr.Item("telefono") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Fax:</td><td>" & dr.Item("fax") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Cellulare:</td><td>" & dr.Item("cellulare") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Sito:</td><td>" & dr.Item("url") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Indirizzo Secondario:</td><td>" & dr.Item("indirizzoa") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Città:</td><td>" & dr.Item("cittaa") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Provincia:</td><td>" & dr.Item("provinciaa") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Cap:</td><td>" & dr.Item("capa") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Zona:</td><td>" & dr.Item("zona") & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Note:</td><td>" & dr.Item("note") & "</td></tr>" & _
                    "</table>" & _
                    "<br><font face=arial size=2 color=black><b>" & Session("AziendaNome") & "</b><br>" & Session("AziendaDescrizione") & "<br>Sito Web: <a href=http://" & Session("AziendaUrl") & ">http://" & Session("AziendaUrl") & "</a> - Email: <a href=mailto:" & Session("AziendaEmail") & ">" & Session("AziendaEmail") & "</a></font>" & _
                    "<br><br><font face=arial size=1 color=silver>D.Lgs 196/2003 tutela delle persone di altri soggetti rispetto al trattamento di dati personali. La presente comunicazione è destinata esclusivamente al soggetto indicato più sopra quale destinatario o ad eventuali altri soggetti autorizzati a riceverla. Essa contiene informazioni strettamente confidenziali e riservate, la cui comunicazione o diffusione a terzi è proibita, salvo che non sia espressamente autorizzata. Se avete ricevuto questa comunicazione per errore, o se desiderate non ricevere più comunicazioni su novità e offerte, Vi preghiamo di darne immediata comunicazione al mittente scrivendo a " & Me.Session("AziendaEmail") & ". Si informa che i dati forniti saranno tenuti rigorosamente riservati, saranno utilizzati unicamente da " & Me.Session("AziendaNome") & " per comunicare offerte promozionali o novità sui prodotti/servizi e resteranno a disposizione per eventuali variazioni o per la cancellazione ai sensi dell'art. 7 del citato decreto legislativo.</font>"

        oMsg.IsBodyHtml = True

        Dim oSmtp As SmtpClient = New SmtpClient("smtp.entropic.it")
        oSmtp.DeliveryMethod = SmtpDeliveryMethod.Network

        Dim oCredential As System.Net.NetworkCredential = New System.Net.NetworkCredential("ecommerce@entropic.it", "12345")
        oSmtp.UseDefaultCredentials = True
        oSmtp.Credentials = oCredential

        oSmtp.Send(oMsg)

    End Sub

End Class
