Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Net.Mail
Imports CityRegistry.CityRegistrySoapClient

Partial Class registrazione
    Inherits System.Web.UI.Page

    Dim conn As New MySqlConnection
    Dim cmd As New MySqlCommand
    Dim strSql As String = ""
	Dim cityRegistry As New CityRegistry.CityRegistrySoapClient
	
	Enum Panel
		Fatturazione
        Spedizione
        Accesso
		FatturaElettronica
    End Enum
	
	public pagetype As String = ""
	public regexCFPrivato As String = "^[A-Za-z]{6}[0-9]{2}[A-Za-z]{1}[0-9]{2}[A-Za-z]{1}[0-9]{3}[A-Za-z]{1}$"
	public regexCFAzienda As String = "^[A-Za-z0-9]{11,16}$"
	
    Sub scegliNascita(ByVal sender As Object, ByVal e As EventArgs) Handles rboNatiEstero.CheckedChanged, rboNatiItalia.CheckedChanged

        If (rboNatiItalia.Checked) Then

            pnlNatiItalia.Visible = True
            pnlNatiEstero.Visible = False
            covProvinciaNascita.Enabled = True
            covComuneNascita.Enabled = True
            covStatoNascita.Enabled = False
            Me.lista_comuni.Visible = True

        Else ' rboNatiEstero.Checked

            pnlNatiEstero.Visible = True
            pnlNatiItalia.Visible = False
            covStatoNascita.Enabled = True
            covProvinciaNascita.Enabled = False
            covComuneNascita.Enabled = False
            Me.lista_comuni.Visible = False
        End If
    End Sub

    Sub scegliComuniNascita(ByVal sender As Object, ByVal e As EventArgs)
        covComuneNascita.Enabled = False
        ComuniNascitaSqlDataSource.SelectCommand = "SELECT Comune, Codice_Comune, Provincia FROM(cf_comuni) WHERE (Provincia = ?provincia)"
        ComuniNascitaSqlDataSource.SelectParameters.Add("?provincia", ddlProvinciaNascita.Text)
    End Sub


    Function calcolaCodiceFiscale(ByVal nome As String, ByVal cognome As String, ByVal dataDiNascita As String, ByVal sesso As String, ByVal codiceISTAT As String) As String

        Dim mesi As String = "ABCDEHLMPRST" 'lettere x corrispondenza mesi
        Dim alfabeto As String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        Dim codfisc As String = ""

        Dim MATRICECOD(100, 2) As Integer
        'matrice per calcolare il carattere di controllo
        'il primo indice è il codice ascii del carattere il secondo indice la posizione pari o dispari
        ' "A"
        MATRICECOD(65, 0) = 1
        MATRICECOD(65, 1) = 0
        ' "B"
        MATRICECOD(66, 0) = 0
        MATRICECOD(66, 1) = 1
        ' "C"
        MATRICECOD(67, 0) = 5
        MATRICECOD(67, 1) = 2
        ' "D"
        MATRICECOD(68, 0) = 7
        MATRICECOD(68, 1) = 3
        ' "E"
        MATRICECOD(69, 0) = 9
        MATRICECOD(69, 1) = 4
        ' "F"
        MATRICECOD(70, 0) = 13
        MATRICECOD(70, 1) = 5
        ' "G"
        MATRICECOD(71, 0) = 15
        MATRICECOD(71, 1) = 6
        ' "H"
        MATRICECOD(72, 0) = 17
        MATRICECOD(72, 1) = 7
        ' "I"
        MATRICECOD(73, 0) = 19
        MATRICECOD(73, 1) = 8
        ' "J"
        MATRICECOD(74, 0) = 21
        MATRICECOD(74, 1) = 9
        ' "K"
        MATRICECOD(75, 0) = 2
        MATRICECOD(75, 1) = 10
        ' "L"
        MATRICECOD(76, 0) = 4
        MATRICECOD(76, 1) = 11
        ' "M"
        MATRICECOD(77, 0) = 18
        MATRICECOD(77, 1) = 12
        ' "N"
        MATRICECOD(78, 0) = 20
        MATRICECOD(78, 1) = 13
        ' "O"
        MATRICECOD(79, 0) = 11
        MATRICECOD(79, 1) = 14
        ' "P"
        MATRICECOD(80, 0) = 3
        MATRICECOD(80, 1) = 15
        ' "Q"
        MATRICECOD(81, 0) = 6
        MATRICECOD(81, 1) = 16
        ' "R"
        MATRICECOD(82, 0) = 8
        MATRICECOD(82, 1) = 17
        ' "S"
        MATRICECOD(83, 0) = 12
        MATRICECOD(83, 1) = 18
        ' "T"
        MATRICECOD(84, 0) = 14
        MATRICECOD(84, 1) = 19
        ' "U"
        MATRICECOD(85, 0) = 16
        MATRICECOD(85, 1) = 20
        ' "V"
        MATRICECOD(86, 0) = 10
        MATRICECOD(86, 1) = 21
        ' "W"
        MATRICECOD(87, 0) = 22
        MATRICECOD(87, 1) = 22
        ' "X"
        MATRICECOD(88, 0) = 25
        MATRICECOD(88, 1) = 23
        ' "Y"
        MATRICECOD(89, 0) = 24
        MATRICECOD(89, 1) = 24
        ' "Z"
        MATRICECOD(90, 0) = 23
        MATRICECOD(90, 1) = 25
        ' "0"
        MATRICECOD(48, 0) = 1
        MATRICECOD(48, 1) = 0
        ' "1"
        MATRICECOD(49, 0) = 0
        MATRICECOD(49, 1) = 1
        ' "2"
        MATRICECOD(50, 0) = 5
        MATRICECOD(50, 1) = 2
        ' "3"
        MATRICECOD(51, 0) = 7
        MATRICECOD(51, 1) = 3
        ' "4"
        MATRICECOD(52, 0) = 9
        MATRICECOD(52, 1) = 4
        ' "5"
        MATRICECOD(53, 0) = 13
        MATRICECOD(53, 1) = 5
        ' "6"
        MATRICECOD(54, 0) = 15
        MATRICECOD(54, 1) = 6
        ' "7"
        MATRICECOD(55, 0) = 17
        MATRICECOD(55, 1) = 7
        ' "8"
        MATRICECOD(56, 0) = 19
        MATRICECOD(56, 1) = 8
        ' "9"
        MATRICECOD(57, 0) = 21
        MATRICECOD(57, 1) = 9

        'converte tutto in maiuscolo
        Dim ccognome As String = cognome.ToUpper()
        Dim cnome As String = nome.ToUpper()
		
        codfisc = calcolaCognome(ccognome.Trim())
        codfisc = codfisc + calcolaNome(cnome.Trim())
		
		if codfisc.Length < 6 then return ""
		
        ' richiede una using Sytem.Globalization;
        Dim dataNascita As DateTime

        Dim itaDate As IFormatProvider = New System.Globalization.CultureInfo("IT-it").DateTimeFormat

        dataNascita = DateTime.Parse(dataDiNascita, itaDate)

        Dim anno As String = dataDiNascita.Substring(8, 2)
        Dim mese As Integer = Int32.Parse(dataDiNascita.Substring(3, 2))
        Dim giorno As Integer = Int32.Parse(dataDiNascita.Substring(0, 2))
        codfisc = codfisc & dataNascita.Year.ToString().Substring(2)
        codfisc = codfisc & mesi(dataNascita.Month - 1)
        If (sesso = "F") Then
            codfisc = codfisc & (dataNascita.Day + 40).ToString()
        Else

            Dim tmpGiorno As String = dataNascita.Day.ToString
            If (tmpGiorno.Length = 1) Then
                tmpGiorno = "0" & tmpGiorno
            End If
            codfisc = codfisc & tmpGiorno
        End If

        codfisc = codfisc & codiceISTAT

        Dim codcontrollo As Integer = 0
        Dim asciicode As Integer = 0

        ' richiede una using System.Text;
        Dim ascii As ASCIIEncoding = New ASCIIEncoding()

        Dim i As Integer
        For i = 0 To 14
            Dim carattere As String = codfisc(i).ToString()
            Dim asciibytes() As Byte = ascii.GetBytes(carattere)
            asciicode = Int32.Parse(asciibytes(0).ToString())
            codcontrollo = codcontrollo + MATRICECOD(asciicode, i Mod 2)
        Next

        codfisc = codfisc & alfabeto(codcontrollo Mod 26)

        Return codfisc

    End Function

    Function calcolaCognome(ByVal cognome As String) As String

        ' restituisce le 3 lettere relative al cognome

        Dim treLettereCognome As String = ""
        Dim VOCALI As String = "AEIOU"
        Dim CONSONANTI As String = "BCDFGHJKLMNPQRSTVWXYZ"

        cognome = stripAccentate(cognome)
        Dim i As Integer = 0
        Dim j As Integer

        Do While ((treLettereCognome.Length < 3) And (i < cognome.Length))

            For j = 0 To CONSONANTI.Length - 1

                If (cognome(i) = CONSONANTI(j)) Then
                    treLettereCognome = treLettereCognome & cognome(i)
                End If

            Next
            i += 1
        Loop

        i = 0
        'se non ha ancora 3 consonanti sceglie fra le vocali
        Do While ((treLettereCognome.Length < 3) And (i < cognome.Length))

            For j = 0 To VOCALI.Length - 1
                If (cognome(i) = VOCALI(j)) Then
                    treLettereCognome = treLettereCognome & cognome(i)
                End If
            Next
            i += 1
        Loop

        'se non ha ancora 3 lettere aggiunge x per arrivare a 3
        If (treLettereCognome.Length < 3) Then
            Dim k As Integer
            For k = treLettereCognome.Length To k <= 2
                treLettereCognome = treLettereCognome & "X"
            Next
        End If

        Return treLettereCognome

    End Function

    Function calcolaNome(ByVal nome As String) As String
        'restituisce le 3 lettere relative al nome                                          

        Dim VOCALI As String = "AEIOU"
        Dim CONSONANTI As String = "BCDFGHJKLMNPQRSTVWXYZ"

        nome = stripAccentate(nome)
        Dim i As Integer = 0
        Dim cons As String = ""
        Dim treLettereNome As String = ""
        Dim j As Integer

        Do While ((cons.Length < 4) And (i < nome.Length))

            For j = 0 To CONSONANTI.Length - 1
                If (nome(i) = CONSONANTI(j)) Then
                    cons = cons & nome(i)
                End If
            Next
            i += 1

        Loop

        If (cons.Length > 3) Then

            'se ha 4 consonanti prende la 1a, 3a e 4a
            treLettereNome = cons(0).ToString() & cons(2).ToString() & cons(3).ToString()
        Else
            treLettereNome = cons
        End If

        i = 0
        'scorre il nome in cerca di vocali finchè $stringa non contiene 3 lettere

        Do While ((treLettereNome.Length < 3) And (i < nome.Length))

            For j = 0 To VOCALI.Length - 1
                If (nome(i) = VOCALI(j)) Then
                    treLettereNome = treLettereNome & nome(i)
                End If
            Next
            i += 1
        Loop

        'se non ha ancora 3 lettere aggiunge x per arrivare a 3
        If (treLettereNome.Length < 3) Then
            Dim k As Integer
            For k = treLettereNome.Length To k <= 2
                treLettereNome = treLettereNome & "X"
            Next
        End If

        Return treLettereNome
    End Function

    Function stripAccentate(ByVal s As String) As String

        Dim ACCENTATE As String = "ÀÈÉÌÒÙàèéìòù"
        Dim NOACCENTO As String = "AEEIOUAEEIOU"
        Dim tmpString As String = ""

        Dim i As Integer
        Dim j As Integer

        For i = 0 To s.Length - 1
            Dim accentata As Boolean = False
            Dim tmpIndex As Integer = 0
            For j = 0 To ACCENTATE.Length - 1
                If (s(i) = ACCENTATE(j)) Then
                    accentata = True
                    tmpIndex = j
                End If
            Next
            If (accentata) Then
                tmpString = tmpString & NOACCENTO(tmpIndex)
            Else
                tmpString = tmpString & s(i)
            End If
        Next

        Return tmpString

    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
	
		Session("DESTINAZIONEALTERNATIVA") = 0
		btnElimDest.enabled = false
		btnModDest.enabled = false
		Me.MaintainScrollPositionOnPostBack = True
        'Setto il Timeout per la fase di registrazione, dò all'utente la possibilità di registrarsi con una sessione che dura 1200min
        Session.Timeout = 10

        '--------------------[ I LISTINI AGEVOLATI NON DEVONO COMPARIRE SU WEBAFFARE ]-------------------------------
        'If (Session.Item("AziendaID") <> 2) Then
        '    Me.TableAgevolazioni.Visible = True
        '    Me.RequiredFieldValidator17.Enabled = True
        '    Me.RegularExpressionValidator4.Enabled = True
        'Else
        '    Me.TableAgevolazioni.Visible = False
        '    Me.RequiredFieldValidator17.Enabled = False
        '    Me.RegularExpressionValidator4.Enabled = False
        'End If
        'If Me.CheckBoxAgevolazione.Checked = False Then
        '    RequiredFieldValidator17.Enabled = False
        'End If
        '------------------------------------------------------------------------------------------------------------

		Me.TextBoxNote.visible = false
		
		If Not Me.Session("LoginId") Is Nothing Then
			pagetype = "Aggiornamento dati utente"
			Me.Panel_IndirizzoSecondarioContainer.Visible = False
			Me.PnlDestinazione.Visible = True
		else
			pagetype = "Registrazione al sito"
			Me.Panel_IndirizzoSecondarioContainer.Visible = True
			Me.PnlDestinazione.Visible = False
		end if
		Me.Title = Me.Title & " - " & pagetype
		
        If Not Page.IsPostBack Then
			BindLstDestinazione()
			Dim login As Boolean = true
			try
				If Me.Session("LoginId") Is Nothing Then
					login = false
				Else if Me.Session("LoginId") = String.Empty
					login = false
				End If
			catch
				If Me.Session("LoginId") = -1 Then
					login = false
				End If
			end try
            Me.lblSito.Text = Session("AziendaNome")
            If login Then
				
                Me.imgModAccesso.Visible = True
                'Me.imgModDatiAnagrafici.Visible = True
                Me.imgModIndirizzoP.Visible = True
                Me.imgModIndirizzoS.Visible = True
				Me.imgModFatturaElettronica.Visible = True
                btRegistrati.Visible = False

                'Nel caso l'utente sia già registrato devo nascondere il bottone di generazione del codice fiscale
                Me.Button_genera_codice_fiscale.Visible = False

                RequiredFieldValidator2.Enabled = False
                RequiredFieldValidator3.Enabled = False

                CaricaDati()
				
				Me.sceltatipologiacliente.Visible = false
				Me.tipologiacliente.Visible = true
				
				if Me.rTipoPrivato.enabled then
					Me.label1tipocliente.text = "Privato"
					Me.label2tipocliente.text = "Utente non titolare di partita iva oppure che effettua acquistti non per fini professionali."
				else if Me.rTipoAzienda.enabled then
					Me.label1tipocliente.text = "Azienda"
					Me.label2tipocliente.text = "Utente titolare di partita iva."
				else
					Me.label1tipocliente.text = "Pubblica Amministrazione"
					Me.label2tipocliente.text = "Per la pubblica amministrazione."
				End if
				Me.PnlPrivacy.Visible = False
            Else
			
				Me.PnlPrivacy.Visible = True
                Me.imgModAccesso.Visible = False
                'Me.imgModDatiAnagrafici.Visible = False
                Me.imgModIndirizzoP.Visible = False
                Me.imgModIndirizzoS.Visible = False
				Me.imgModFatturaElettronica.Visible = False
                btRegistrati.Visible = True
				
				Me.sceltatipologiacliente.Visible = true
				Me.tipologiacliente.Visible = false
				
            End If
			
        End If

        'Dim TipoPrivato As CheckBox = Me.rTipoPrivato

        'If TipoPrivato.Checked Then
        '    Privato()
        'End If

        'Per codice fiscale
        covProvinciaNascita.Enabled = True
        covComuneNascita.Enabled = True

        'Nascondo il validatore del codice fiscale se si sta registrando un'azienda
        If Me.rTipoPrivato.Checked = True Then
            Me.RegularExpressionValidator6.ValidationExpression = regexCFPrivato
        Else 
            Me.RegularExpressionValidator6.ValidationExpression = regexCFAzienda 
        End If
		Me.tbCodiceFiscale.MaxLength = 16
		Me.tbCsdi.MaxLength = 7
		Me.lblPecAndSdi.Text = ""
    End Sub

    Protected Sub Page_PreInit(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreInit
        Try
            If Request.UrlReferrer.AbsoluteUri.Contains("coupon") Or (Request.QueryString("state") = "coupon") Then
                Page.MasterPageFile = "Coupon.master"
            Else
                Page.MasterPageFile = "Page.master"
            End If
        Catch
        End Try
    End Sub

    Protected Sub Page_PreLoad(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreLoad
        Dim TipoPrivato As CheckBox = Me.rTipoPrivato

        If TipoPrivato.Checked Then
            Privato()
        End If

        Dim nome As TextBox = Me.tbNomeCognome
        Session("nomecognome") = nome.Text

    End Sub

    Public Sub Registrazione()
        If (cbCondizioniVendita.Checked = True) And (cbPrivacy.Checked = True) Then
            ErrorCondizioni.Visible = False
            ErrorCondizioni.Text = vbCrLf & ErrorCondizioni.Text
            ControllaUser(Session("AziendaID"))
        Else
            ErrorCondizioni.Visible = True
            ErrorCondizioni.Focus()
        End If
    End Sub

    Public Sub ControllaUtente(ByVal aziendaId As Integer)
        Dim codice As String = 1

        cmd.CommandType = CommandType.Text

        If Me.tbPartitaIva.Text.Trim <> "" Then
            cmd.CommandText = "Select Utenti.id from Utenti join utentitipo on Utenti.UtentiTipoId=utentitipo.id where Utenti.AziendeID=" & aziendaId & " and Utenti.PIva=?Piva and utentitipo.Clienti = 1"
            cmd.Parameters.AddWithValue("?Piva", Me.tbPartitaIva.Text.Trim)
        Else
            cmd.CommandText = "Select Utenti.id from Utenti join utentitipo on Utenti.UtentiTipoId=utentitipo.id where Utenti.AziendeID=" & aziendaId & " and CodiceFiscale=?CodiceFiscale and utentitipo.Clienti = 1"
            cmd.Parameters.AddWithValue("?CodiceFiscale", Me.tbCodiceFiscale.Text.Trim)
        End If
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            'Se l'utente esiste già, blocco la registrazione
            'Me.tRegistrazione.Visible = False
            Me.principale.Visible = False
            Me.tError.Visible = True
            dr.Close()
            dr.Dispose()

        Else

            'Se non esiste lo registro
            dr.Close()
            dr.Dispose()

            cmd.CommandText = "SELECT Max((Codice*1)+1) AS Cod FROM utenti"
            dr = cmd.ExecuteReader
            dr.Read()

            If dr.HasRows Then
                codice = dr.Item("Cod")
            End If

            dr.Close()
            dr.Dispose()

            'Controllo se ha richiesto l'attivazione di un listino agevolato
            If Me.CheckBoxAgevolazione.Checked = True Then
                Me.TextBoxNote.Text = "Agevolazione: " & Me.DropDownListAgevolazione.SelectedValue & "; Mail: " & Me.tbEmailIstituzionale.Text & "<br>" & Me.TextBoxNote.Text
            End If


            AggiungiUtente(codice)

            Try
                'Invio l'email di registrazione effettuata
                Email("Conferma registrazione al sito ", 1)
            Catch ex As Exception
                'Response.Write(ex.Message.ToString & "in " & cmd.CommandText)
                'Response.end()
                'Se l'email esiste già lo blocco
                'Me.lblEmail.Text = "Email errata !!"
                'Me.tbEmail.Focus()
            End Try
            'Setto dove reindirizzare l'uitente
            If Not Session("StavonelCarrello") Is Nothing Then
                If (Session("StavonelCarrello") = 1) Then
                    Session("StavonelCarrello") = 0
                    Response.Redirect("carrello.aspx")
                Else
                    If Request.UrlReferrer.AbsoluteUri.Contains("coupon") Then
                        Session("Login_User") = tbUsername.Text
                        Session("Login_Password") = tbPassword.Text
                        Response.Redirect("registrazioneok.aspx?state=coupon")
                    Else
                        Response.Redirect("registrazioneok.aspx?redirect=" & Request.QueryString("redirect"))
                    End If
                End If
            Else
                If Request.UrlReferrer.AbsoluteUri.Contains("coupon") Then
                    Session("Login_User") = tbUsername.Text
                    Session("Login_Password") = tbPassword.Text
                    Response.Redirect("registrazioneok.aspx?state=coupon")
                Else
                    Response.Redirect("registrazioneok.aspx?redirect=" & Request.QueryString("redirect"))
                End If
            End If
        End If

        cmd.Dispose()
    End Sub


    Public Sub AggiungiUtente(ByVal cod As Integer)
		
            cmd.CommandType = CommandType.StoredProcedure
            cmd.CommandText = "Newutenti"
            cmd.Parameters.AddWithValue("?parAziendeID", Session("AziendaID"))
            cmd.Parameters.AddWithValue("?parCodice", cod)
            cmd.Parameters.AddWithValue("?parUtentiTipoId", "2")
            cmd.Parameters.AddWithValue("?parRagioneSociale", Me.tbRagioneSociale.Text.ToString.ToUpper.Trim)
            cmd.Parameters.AddWithValue("?parCognomeNome", Me.tbNomeCognome.Text.ToString.ToUpper.Trim)
            cmd.Parameters.AddWithValue("?parPiva", Me.tbPartitaIva.Text.ToString.ToUpper.Trim)
            cmd.Parameters.AddWithValue("?parIndirizzo", Me.tbIndirizzo.Text.ToString.ToUpper.Trim)
            cmd.Parameters.AddWithValue("?parCitta", Me.ddlCitta.Text.ToString.ToUpper.Trim)
            cmd.Parameters.AddWithValue("?parProvincia", Me.tbProvincia.Text.ToString.ToUpper.Trim)
            cmd.Parameters.AddWithValue("?parCap", Me.tbCap.Text.ToString.ToUpper.Trim)
			Dim parPrivato As String
			If rTipoPubblicaAmministrazione.Checked = True Then
				parPrivato = "0"
			Else
				parPrivato = "1"
			End If
			Dim cf As String
			'if Me.tbCodiceFiscale.Text.ToString = "" then 
			'	cf = Me.tbPartitaIva.Text.ToString.ToUpper.Trim
			'else
				cf = Me.tbCodiceFiscale.Text.ToString.ToUpper.Trim
			'End if
			Dim parCodiceSdi As String
			If Me.tbCsdi.Text.ToString.ToUpper.Trim = "" Then
				parCodiceSdi = "0000000"
			else
				parCodiceSdi = Me.tbCsdi.Text.ToString.ToUpper.Trim
			End If
			cmd.Parameters.AddWithValue("?paremail_pec", Me.tbEmailPec.Text.ToString.ToUpper.Trim)
			cmd.Parameters.AddWithValue("?parcodice_sdi", parCodiceSdi)
            cmd.Parameters.AddWithValue("?parCodiceFiscale", cf)
            cmd.Parameters.AddWithValue("?parTelefono", Me.tbTelefono.Text.ToString.ToUpper.Trim)
			if Me.tbCellulare.Text<>"" then
				cmd.Parameters.AddWithValue("?parCellulare", Me.tbCellulare.Text.ToString.ToUpper.Trim)
			else 
				cmd.Parameters.AddWithValue("?parCellulare", dbNull.value)
			end if
            cmd.Parameters.AddWithValue("?parMsn", "")
            cmd.Parameters.AddWithValue("?parSkype", Me.tbSkype.Text.ToString.ToUpper.Trim)
			if Me.tbFax.Text<>"" then
				cmd.Parameters.AddWithValue("?parFax", Me.tbFax.Text.ToString.ToUpper.Trim)
			else 
				cmd.Parameters.AddWithValue("?parFax", dbNull.value)
			end if
            cmd.Parameters.AddWithValue("?parEmail", Me.tbEmail.Text.ToString.Trim.ToLower)
            cmd.Parameters.AddWithValue("?parListino", Session("ListinoUser"))
            cmd.Parameters.AddWithValue("?parUrl", Me.tbSito.Text.ToString.Trim)
            cmd.Parameters.AddWithValue("?parPrivacy", "1")
            cmd.Parameters.AddWithValue("?parAbilitato", "1")
            cmd.Parameters.AddWithValue("?parCanOrder", Me.Session("CanOrder"))
            cmd.Parameters.AddWithValue("?parIvaTipo", Me.Session("IvaTipo"))
            cmd.Parameters.AddWithValue("?parMagazziniID", Me.Session("MagazzinoDefault"))
            cmd.Parameters.AddWithValue("?paridEsenzioneIva", "-1")
            cmd.Parameters.AddWithValue("?parinfoNote", Me.TextBoxNote.Text.ToUpper.Trim)
            cmd.Parameters.AddWithValue("?pargenera_html_mail", "0")
            cmd.Parameters.AddWithValue("?parNewsLetter", "1")
            cmd.Parameters.AddWithValue("?pargenera_html_ebay", "0")
            cmd.Parameters.AddWithValue("?parContiId", "178")
            cmd.Parameters.AddWithValue("?parAbilitatoIvaReverseCharge", "-1")
            cmd.Parameters.AddWithValue("?parNazione", "IT")
			cmd.Parameters.AddWithValue("?parPrivato", parPrivato)
			cmd.Parameters.AddWithValue("?parEsigibilita", "I")
            cmd.Parameters.AddWithValue("?parRetVal", "0")
			
            cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output

            cmd.ExecuteNonQuery()

            cmd.Parameters.Clear()
            cmd.Dispose()
            'UtentiID = cmd.Parameters("?parRetVal").Value

            cmd.CommandType = CommandType.Text
            cmd.CommandText = "SELECT Id FROM utenti WHERE Codice=" & cod
			
            Dim dr As MySqlDataReader = cmd.ExecuteReader()

            If dr.HasRows Then
                dr.Read()
                Session("UTENTIID") = dr.Item("Id")
            End If

            dr.Close()
            dr.Dispose()

            cmd.Parameters.Clear()
            cmd.Dispose()

            'If (tbRagioneSocialeA.Text.ToString.Trim <> "") Or (tbNomeA.Text.ToString.Trim <> "") Then
            AggiungiUtenteIndirizzo(Session("UTENTIID"))
            'End If

            AggiungiUtenteRapporto(Session("AZIENDAID"), Session("UTENTIID"))
			
            'Aggiungo l'utente alle credenziali di Accesso WEB
            AggiungiLogin(Session("UTENTIID"))

    End Sub

    Protected Sub AggiungiUtenteRapporto(ByVal aziendaId As Integer, ByVal utenteId As String)
        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "Select id from pagamentitipo where AziendeID=" & aziendaId & " and Predefinito = 1"

        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            Dim pagamentoTipo As String = dr.Item("id").ToString
            dr.Close()
            dr.Dispose()

            cmd.CommandType = CommandType.StoredProcedure
            cmd.CommandText = "Newutentirapporto"
            cmd.Parameters.AddWithValue("?parUtenteId", utenteId)
            cmd.Parameters.AddWithValue("?parExtra", dbNull.value)
            cmd.Parameters.AddWithValue("?parConOfferta", dbNull.value)
            cmd.Parameters.AddWithValue("?parSettore", dbNull.value)
            cmd.Parameters.AddWithValue("?parFido", dbNull.value)
            cmd.Parameters.AddWithValue("?parDataInizio", dbNull.value)
            cmd.Parameters.AddWithValue("?parDataFine", dbNull.value)
            cmd.Parameters.AddWithValue("?parTipoPagamento", pagamentoTipo)
            cmd.Parameters.AddWithValue("?parRetVal", "0")
            cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
            cmd.ExecuteNonQuery()
            cmd.Parameters.Clear()
            cmd.Dispose()
        Else
            dr.Close()
            dr.Dispose()
            cmd.Dispose()
        End If


    End Sub

    Protected Function getDdlCittaValue(ByVal ddlCitta As DropDownList) As String
		Dim value As String
		Try
			value = ddlCitta.Items(ddlCitta.SelectedIndex).Text
		Catch ex As Exception
			value = ""
        End Try
		return value
	End Function
	
    Public Sub AggiungiUtenteIndirizzo(ByVal UtenteId As Integer)
        Dim UtentiID As Integer = UtenteId
		'Response.Write("<script language='javascript'> alert('1'); </script>")
		
        Try
            cmd.CommandType = CommandType.StoredProcedure
            cmd.CommandText = "Newutentiindirizzi"	
            If (tbRagioneSocialeA.Text <> "") And (tbIndirizzo2.Text <> "") And (getDdlCittaValue(ddlCitta2) <> "") And (tbProvincia2.Text <> "") And (tbCap2.Text <> "") And (tbTelefono2.Text <> "") Then
				cmd.Parameters.AddWithValue("?parUtenteId", UtenteId)
                cmd.Parameters.AddWithValue("?parRagioneSocialeA", Me.tbRagioneSocialeA.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parNomeA", Me.tbNomeA.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parIndirizzoA", Me.tbIndirizzo2.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parCittaA", Me.getDdlCittaValue(ddlCitta2).ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parCapA", Me.tbCap2.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parProvinciaA", Me.tbProvincia2.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parZona", Me.tbZona.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parNote", Me.tbNote.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parTelefonoA", Me.tbTelefono2.Text.ToString.ToUpper)
                if Me.tbCellulare.Text<>"" Then
					cmd.Parameters.AddWithValue("?parCellulareA", Me.tbCellulare.Text.ToString.ToUpper)
				else
					cmd.Parameters.AddWithValue("?parCellulareA", dbNull.value)
				end if
				if Me.tbFax.Text<>"" Then
					cmd.Parameters.AddWithValue("?parFaxA", Me.tbFax.Text.ToString.ToUpper)
				else
					cmd.Parameters.AddWithValue("?parFaxA", dbNull.value)
				end if
				cmd.Parameters.AddWithValue("?parNazioneA", "IT")
            Else
                cmd.Parameters.AddWithValue("?parUtenteId", UtenteId)
				cmd.Parameters.AddWithValue("?parRagioneSocialeA", Me.tbRagioneSociale.Text.ToString.ToUpper)
				cmd.Parameters.AddWithValue("?parNomeA", Me.tbNomeCognome.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parIndirizzoA", Me.tbIndirizzo.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parCittaA", Me.getDdlCittaValue(ddlCitta).ToUpper)
                cmd.Parameters.AddWithValue("?parCapA", Me.tbCap.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parProvinciaA", Me.tbProvincia.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parZona", "")
                cmd.Parameters.AddWithValue("?parNote", Me.TextBoxNote.Text.ToString.ToUpper)
                cmd.Parameters.AddWithValue("?parTelefonoA", Me.tbTelefono.Text.ToString.ToUpper)
				if Me.tbCellulare.Text<>"" Then
					cmd.Parameters.AddWithValue("?parCellulareA", Me.tbCellulare.Text.ToString.ToUpper)
				else
					cmd.Parameters.AddWithValue("?parCellulareA", dbNull.value)
				end if
				if Me.tbFax.Text<>"" Then
					cmd.Parameters.AddWithValue("?parFaxA", Me.tbFax.Text.ToString.ToUpper)
				else
					cmd.Parameters.AddWithValue("?parFaxA", dbNull.value)
				end if
				cmd.Parameters.AddWithValue("?parNazioneA", "IT")
                
            End If

            cmd.Parameters.AddWithValue("?parPredefinito", "1")
            cmd.Parameters.AddWithValue("?parRetVal", "0")
            cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output

            cmd.ExecuteNonQuery()

            cmd.Parameters.Clear()

            cmd.Dispose()
        Catch ex As Exception
            Response.Write(ex.Message.ToString & tbRagioneSocialeA.Text & tbIndirizzo2.Text & getDdlCittaValue(ddlCitta2) & tbProvincia2.Text & tbCap2.Text & tbTelefono2.Text &" in " & cmd.CommandText)
			
        End Try
    End Sub

    Public Sub ControllaUser(ByVal aziendaId As Integer)
        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "Select id from vlogin where AziendeID=" & aziendaId & " And (Username =?Piva )"
        cmd.Parameters.AddWithValue("?Piva", Me.tbUsername.Text)

        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            'Se lo username esiste già lo blocco
            Me.lblUser.Text = "Username già esistente!"
            Me.tbUsername.Focus()
            dr.Close()
            dr.Dispose()
        Else
            'Altrimenti procedo
            Me.lblUser.Text = ""
            dr.Close()
            dr.Dispose()
            ControllaPIVA(Session("AziendaID"))
        End If

        cmd.Dispose()
    End Sub

    Public Sub ControllaPIVA(ByVal aziendaId As Integer)
        If tbPartitaIva.Text <> "" Then
            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.CommandText = "Select id from vlogin where AziendeID=" & aziendaId & " and (Piva=?Piva )"
            cmd.Parameters.AddWithValue("?Piva", Me.tbPartitaIva.Text)

            Dim dr As MySqlDataReader = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows Then
                'Se lo username esiste già lo blocco
                Me.lblPiva.Text = "P.IVA già presente!"
                Me.tbPartitaIva.Focus()
                dr.Close()
                dr.Dispose()
            Else
                'Altrimenti procedo
                Me.lblPiva.Text = ""
                dr.Close()
                dr.Dispose()
                ControllaEmail(Session("AziendaID"))
            End If

            cmd.Dispose()
        Else
            ControllaEmail(Session("AziendaID"))
        End If
    End Sub

    Public Sub ControllaEmail(ByVal aziendaId As Integer)

        cmd.CommandType = CommandType.Text
        cmd.CommandText = "Select id from vlogin where AziendeID=" & aziendaId & " and (Email=?Email )"
        cmd.Parameters.AddWithValue("?Email", Me.tbEmail.Text)

        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            'Se l'email esiste già lo blocco
            Me.lblEmail.Text = "Email già esistente!"
            Me.tbEmail.Focus()
            dr.Close()
            dr.Dispose()
        Else
            'Altrimenti procedo
            Me.lblEmail.Text = ""
            dr.Close()
            dr.Dispose()
            ControllaUtente(Session("AziendaID"))
        End If

        cmd.Dispose()
    End Sub

    Public Sub AggiungiLogin(ByVal UtenteId As Integer)
        Try
            cmd.CommandType = CommandType.StoredProcedure
            cmd.CommandText = "Newlogin"

            cmd.Parameters.AddWithValue("?parUtentiId", UtenteId)
            cmd.Parameters.AddWithValue("?parUsername", Me.tbUsername.Text.ToString.Trim.ToLower)
            cmd.Parameters.AddWithValue("?parPassword", Me.tbPassword.Text.ToString.Trim.ToLower)
            cmd.Parameters.AddWithValue("?parEmail", Me.tbEmail.Text.ToString.Trim.ToLower)
            cmd.Parameters.AddWithValue("?parCognomeNome", Me.tbRagioneSociale.Text.ToString.Trim.ToUpper)
            cmd.Parameters.AddWithValue("?parUltimoAccesso", System.DateTime.Now)
            cmd.Parameters.AddWithValue("?parUltimoIp", Me.Request.UserHostAddress)
            cmd.Parameters.AddWithValue("?parAbilitato", "1")
            cmd.Parameters.AddWithValue("?parPrivacy", "1")
            cmd.Parameters.AddWithValue("?parDataPassword", System.DateTime.Today)
            cmd.Parameters.AddWithValue("?parNumeroAccessi", "0")
            cmd.Parameters.AddWithValue("?parRetVal", "0")
            cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
            cmd.Parameters.AddWithValue("?parAbilitaListino", "0")

            cmd.ExecuteNonQuery()

            cmd.Parameters.Clear()

            cmd.Dispose()

            'Me.MyAccordion.Visible = False
            Me.btRegistrati.Visible = False

            'Metto in sezione la user e la password scelti
            Session.Item("Inserimento_User") = Me.tbUsername.Text
            Session.Item("Inserimento_Password") = Me.tbPassword.Text
        Catch ex As Exception
        End Try
    End Sub

    Public Sub Email(ByVal oggetto As String, ByVal tipo As Integer)
        Dim indirizzoSecondario As String = ""

        Dim pass As String = ""
        If tipo = 1 Then
            pass = Me.tbPassword.Text
        ElseIf tipo = 2 Then
            pass = Me.tbPassword.Attributes("value").ToString
        End If

        Dim oMsg As MailMessage = New MailMessage()
        oMsg.From = New MailAddress(Session("AziendaEmail"), Session("AziendaNome"))
        oMsg.To.Add(Me.tbEmail.Text)
        oMsg.Bcc.Add(New MailAddress(Session("AziendaEmail"), Session("AziendaNome")))
        oMsg.Subject = oggetto & Session("AziendaNome")
        oMsg.Body = "<font face=arial size=2 color=black>Gentile " & Me.tbNomeCognome.Text.ToUpper & "," & _
                    "<br>Le comunichiamo i suoi dati di accesso al sito web <u>" & Session("AziendaUrl") & "</u>" & _
                    "<br><br><b>Username:</b> " & Me.tbUsername.Text & "<br><b>Password:</b> " & pass & "<br><b>Email:</b> " & Me.tbEmail.Text.ToLower & " </b>" & _
                    "<br><br>Di seguito, Le riepiloghiamo i dati che ci ha fornito, pregandola di controllarne la correttezza." & _
                    "<br>Se necessario potrà comunque modificare tali dati accedendo alla sezione <i>MY ACCOUNT</i>.</font>" & _
                    "<br><br><table cellspacing=3 cellpadding=3 style='font-family:arial;font-size:9pt'>" & _
                    "<tr><td colspan='2' style='text-align:center;' bgcolor=whitesmoke><b>INDIRIZZO FATTURAZIONE</b></td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Nome:</td><td>" & Me.tbNomeCognome.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Cognome/Rag.Sociale:</td><td>" & Me.tbRagioneSociale.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Codice Fiscale:</td><td>" & Me.tbCodiceFiscale.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Partita Iva:</td><td>" & Me.tbPartitaIva.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Indirizzo Principale:</td><td>" & Me.tbIndirizzo.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Città:</td><td>" & Me.ddlCitta.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Provincia:</td><td>" & Me.tbProvincia.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Cap:</td><td>" & Me.tbCap.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Telefono:</td><td>" & Me.tbTelefono.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Fax:</td><td>" & Me.tbFax.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Cellulare:</td><td>" & Me.tbCellulare.Text.ToUpper & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Skype:</td><td>" & Me.tbSkype.Text.ToLower & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Sito:</td><td>" & Me.tbSito.Text.ToLower & "</td></tr>" & _
                    "<tr><td bgcolor=whitesmoke>Note:</td><td>" & Me.TextBoxNote.Text & "</td></tr>" & _
                    "<tr><td colspan='2' style='text-align:center;' bgcolor=whitesmoke><b>INDIRIZZO SPEDIZIONE</b></td></tr>"

        'Indico l'indirizzo di spedizione uguale a quello di fatturazione nel caso quello di spedizione non sia stato specificato
        If (tbRagioneSocialeA.Text <> "") And (tbIndirizzo2.Text <> "") And (getDdlCittaValue(ddlCitta2) <> "") And (tbProvincia2.Text <> "") And (tbCap2.Text <> "") And (tbTelefono2.Text <> "") Then
            indirizzoSecondario = "<tr><td bgcolor=whitesmoke>Cogn./Rag Soc:</td><td>" & Me.tbRagioneSocialeA.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Nome:</td><td>" & Me.tbNomeA.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Indirizzo:</td><td>" & Me.tbIndirizzo2.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Città:</td><td>" & Me.getDdlCittaValue(ddlCitta2).ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Provincia:</td><td>" & Me.tbProvincia2.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Cap:</td><td>" & Me.tbCap2.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Telefono:</td><td>" & Me.tbTelefono2.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Fax:</td><td>" & Me.tbFax2.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Cellulare:</td><td>" & Me.tbCellulare2.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Zona:</td><td>" & Me.tbZona.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Note:</td><td>" & Me.tbNote.Text.ToUpper & "</td></tr>" & _
                                "</table>" & _
                                "<br><font face=arial size=2 color=black><b>" & Session("AziendaNome") & "</b><br>" & Session("AziendaDescrizione") & "<br>Sito Web: <a href=http://" & Session("AziendaUrl") & ">http://" & Session("AziendaUrl") & "</a> - Email: <a href=mailto:" & Session("AziendaEmail") & ">" & Session("AziendaEmail") & "</a></font>" & _
                                "<br><br><font face=arial size=1 color=silver>D.Lgs 196/2003 tutela delle persone di altri soggetti rispetto al trattamento di dati personali. La presente comunicazione è destinata esclusivamente al soggetto indicato più sopra quale destinatario o ad eventuali altri soggetti autorizzati a riceverla. Essa contiene informazioni strettamente confidenziali e riservate, la cui comunicazione o diffusione a terzi è proibita, salvo che non sia espressamente autorizzata. Se avete ricevuto questa comunicazione per errore, o se desiderate non ricevere più comunicazioni su novità e offerte, Vi preghiamo di darne immediata comunicazione al mittente scrivendo a " & Me.Session("AziendaEmail") & ". Si informa che i dati forniti saranno tenuti rigorosamente riservati, saranno utilizzati unicamente da " & Me.Session("AziendaNome") & " per comunicare offerte promozionali o novità sui prodotti/servizi e resteranno a disposizione per eventuali variazioni o per la cancellazione ai sensi dell'art. 7 del citato decreto legislativo.</font>"
        Else
            indirizzoSecondario = "<tr><td bgcolor=whitesmoke>Cogn./Rag Soc:</td><td>" & Me.tbRagioneSociale.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Nome:</td><td>" & Me.tbNomeCognome.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Indirizzo:</td><td>" & Me.tbIndirizzo.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Città:</td><td>" & Me.ddlCitta.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Provincia:</td><td>" & Me.tbProvincia.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Cap:</td><td>" & Me.tbCap.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Telefono:</td><td>" & Me.tbTelefono.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Fax:</td><td>" & Me.tbFax.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Cellulare:</td><td>" & Me.tbCellulare.Text.ToUpper & "</td></tr>" & _
                                "<tr><td bgcolor=whitesmoke>Note:</td><td>" & Me.TextBoxNote.Text.ToUpper & "</td></tr>" & _
                                "</table>" & _
                                "<br><font face=arial size=2 color=black><b>" & Session("AziendaNome") & "</b><br>" & Session("AziendaDescrizione") & "<br>Sito Web: <a href=http://" & Session("AziendaUrl") & ">http://" & Session("AziendaUrl") & "</a> - Email: <a href=mailto:" & Session("AziendaEmail") & ">" & Session("AziendaEmail") & "</a></font>" & _
                                "<br><br><font face=arial size=1 color=silver>D.Lgs 196/2003 tutela delle persone di altri soggetti rispetto al trattamento di dati personali. La presente comunicazione è destinata esclusivamente al soggetto indicato più sopra quale destinatario o ad eventuali altri soggetti autorizzati a riceverla. Essa contiene informazioni strettamente confidenziali e riservate, la cui comunicazione o diffusione a terzi è proibita, salvo che non sia espressamente autorizzata. Se avete ricevuto questa comunicazione per errore, o se desiderate non ricevere più comunicazioni su novità e offerte, Vi preghiamo di darne immediata comunicazione al mittente scrivendo a " & Me.Session("AziendaEmail") & ". Si informa che i dati forniti saranno tenuti rigorosamente riservati, saranno utilizzati unicamente da " & Me.Session("AziendaNome") & " per comunicare offerte promozionali o novità sui prodotti/servizi e resteranno a disposizione per eventuali variazioni o per la cancellazione ai sensi dell'art. 7 del citato decreto legislativo.</font>"
        End If

        'Aggiungo la porzione di codice HTML relativa all'indirizzo di spedizione
        oMsg.Body = oMsg.Body & indirizzoSecondario

        oMsg.IsBodyHtml = True

        Dim oSmtp As SmtpClient = New SmtpClient(Session("smtp"))
        oSmtp.DeliveryMethod = SmtpDeliveryMethod.Network

        Dim oCredential As System.Net.NetworkCredential = New System.Net.NetworkCredential(CType(Session.Item("User_smtp"), String), CType(Session.Item("Password_smtp"), String))
        oSmtp.UseDefaultCredentials = True
        oSmtp.Credentials = oCredential

        oSmtp.Send(oMsg)
    End Sub

    Public Sub CaricaDati()
	
        Try
			Dim conn As New MySqlConnection
			Dim cmd As New MySqlCommand
			conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            cmd.Connection = conn
            conn.Open()

            cmd.CommandType = CommandType.Text
            cmd.CommandText = "Select * from vlogin where id=?id"
            cmd.Parameters.AddWithValue("?id", Session("LoginID"))

            'cmd.CommandText = "Select * from vlogin LEFT OUTER JOIN UTENTIINDIRIZZI ON vlogin.UTENTIINDIRIZZIID = UTENTIINDIRIZZI.ID where UTENTIINDIRIZZI.PREDEFINITO = 1 AND vlogin.id=" & Session("LoginID")

            Dim dr As MySqlDataReader = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows Then

                Dim Username As TextBox = Me.tbUsername
                Dim Password As TextBox = Me.tbPassword
                Dim PasswordConferma As TextBox = Me.tbPasswordConferma
                Dim Email As TextBox = Me.tbEmail
                Dim EmailConferma As TextBox = Me.tbEmailConferma
                Dim NomeCognome As TextBox = Me.tbNomeCognome

                Username.Text = dr.Item("username").ToString

                Password.Attributes("value") = dr.Item("password").ToString
                PasswordConferma.Attributes("value") = dr.Item("password").ToString
                Email.Text = dr.Item("email").ToString
                EmailConferma.Text = dr.Item("email").ToString

                NomeCognome.Text = dr.Item("utenticognomenome").ToString

                Dim RagioneSociale As TextBox = Me.tbRagioneSociale
                RagioneSociale.Text = dr.Item("RagioneSociale").ToString

                Dim Indirizzo As TextBox = Me.tbIndirizzo
                Indirizzo.Text = dr.Item("indirizzo").ToString

				Dim Cap As TextBox = Me.tbCap
                Cap.Text = dr.Item("cap").ToString
				
                'Dim Citta As TextBox = Me.tbCitta
                'Citta.Text = dr.Item("citta").ToString
				
				Dim Citta As DropDownList
				try
					riempi_ddl_citta(Cap.Text, ddlCitta, tbProvincia, dr.Item("citta").ToString)
				catch
					riempi_ddl_citta(Cap.Text, ddlCitta, tbProvincia)
				finally
					Citta = Me.ddlCitta
				end try 
				
                Dim Provincia As TextBox = Me.tbProvincia
                'Provincia.Text = dr.Item("provincia").ToString

                Dim CodiceFiscale As TextBox = Me.tbCodiceFiscale
                CodiceFiscale.Text = dr.Item("codicefiscale").ToString

                Dim PartitaIva As TextBox = Me.tbPartitaIva
                PartitaIva.Text = dr.Item("piva").ToString

                Dim Telefono As TextBox = Me.tbTelefono
                Telefono.Text = dr.Item("telefono").ToString 

                Dim Fax As TextBox = Me.tbFax
                Fax.Text = dr.Item("fax").ToString

                Dim Cellulare As TextBox = Me.tbCellulare
                Cellulare.Text = dr.Item("cellulare").ToString

				Dim emailPec As TextBox = Me.tbEmailPec
                emailPec.Text = dr.Item("email_pec").ToString
				
				Dim csdi As TextBox = Me.tbCsdi
                csdi.Text = dr.Item("codice_sdi").ToString
				
                Dim Skype As TextBox = Me.tbSkype
                Skype.Text = dr.Item("Skype").ToString

                If Not IsDBNull(dr.Item("infoNote")) Then
                    Dim Note As TextBox = Me.TextBoxNote
                    Note.Text = dr.Item("infoNote").ToString
                End If

                Dim Sito As TextBox = Me.tbSito
                Sito.Text = dr.Item("url").ToString

                Dim RagioneSocialeA As TextBox = Me.tbRagioneSocialeA
                Me.tbRagioneSocialeA.Text = dr("RagioneSocialeA").ToString

                'PANEL4

                Dim CondizioniVendita As CheckBox = Me.cbCondizioniVendita
                CondizioniVendita.Checked = True

                Dim Privacy As CheckBox = Me.cbPrivacy
                Privacy.Checked = True

                Username.Enabled = False
                Password.Enabled = False
                PasswordConferma.Enabled = False
                NomeCognome.Enabled = False
                RagioneSociale.Enabled = False
                Indirizzo.Enabled = False
                Citta.Enabled = False
                Provincia.Enabled = False
                Cap.Enabled = False
                CodiceFiscale.Enabled = False
                PartitaIva.Enabled = False
                'CondizioniVendita.Enabled = False
                'Privacy.Enabled = False
                'Privacy.Text = "ok"
                Sito.Enabled = False
                Telefono.Enabled = False
                Email.Enabled = False
                EmailConferma.Enabled = False
                Fax.Enabled = False
                Cellulare.Enabled = False
                Skype.Enabled = False
                tbRagioneSocialeA.Enabled = False
				emailPec.Enabled = False
				csdi.Enabled = False


                Dim Condizioni As TextBox = Me.tbCondizioni
                Condizioni.Text = "ok"

                Condizioni.Enabled = False

                If dr.Item("UtentiCognomeNome").ToString = "" Then
					If dr.Item("Privato").ToString = "1" Then
						rTipoAzienda.Checked = True
						rTipoPubblicaAmministrazione.Enabled = False
						Azienda()
					Else
						rTipoPubblicaAmministrazione.Checked = True
						rTipoAzienda.Enabled = False
						PubblicaAmministrazione()
					End If
                    

                    rTipoPrivato.Enabled = False
                Else
                    rTipoPrivato.Checked = True
                    Privato()
					rTipoPubblicaAmministrazione.Enabled = False
                    rTipoAzienda.Enabled = False
                End If

                Me.btRegistrati.Text = "AGGIORNA"

            End If

            dr.Close()
            dr.Dispose()


            cmd.CommandText = "SELECT * FROM utentiindirizzi where utenteid = ?id"
            cmd.Parameters.AddWithValue("?id", Session("UtentIId"))

            Dim dsdata As New DataSet

            Dim sqlAdp As New MySqlDataAdapter(cmd)
            sqlAdp.Fill(dsdata, "utentiindirizzi")


            If dsdata.Tables(0).Rows.Count > 1 Then

                For Each ROW As DataRow In dsdata.Tables(0).Select("PREDEFINITO = 1")

                    Dim RagioneSocialeA As TextBox = Me.tbRagioneSocialeA
                    RagioneSocialeA.Text = ROW("RagioneSocialeA").ToString

                    Dim NomeA As TextBox = Me.tbNomeA
                    NomeA.Text = ROW("NomeA").ToString

                    Dim Indirizzo2 As TextBox = Me.tbIndirizzo2
                    Indirizzo2.Text = ROW.Item("IndirizzoA").ToString

					Dim Cap2 As TextBox = Me.tbCap2
                    Cap2.Text = ROW.Item("CapA").ToString
					
                    riempi_ddl_citta(Cap2.Text, ddlCitta2, tbProvincia2, dr.Item("CittaA").ToString)
					Dim Citta2 As DropDownList = Me.ddlCitta2
					
					Dim Provincia2 As TextBox = Me.tbProvincia

                    'Dim Provincia2 As TextBox = Me.tbProvincia2
                    'Provincia2.Text = ROW.Item("ProvinciaA").ToString

                    Dim Zona As TextBox = Me.tbZona
                    Zona.Text = ROW.Item("Zona").ToString

                    Dim Note As TextBox = Me.tbNote
                    Note.Text = ROW.Item("Note").ToString

                    Dim Telefono2 As TextBox = Me.tbTelefono2
                    Telefono2.Text = ROW.Item("TelefonoA").ToString

                    Dim Fax2 As TextBox = Me.tbFax2
                    Fax2.Text = ROW.Item("FaxA").ToString

                    Dim Cellulare2 As TextBox = Me.tbCellulare2
                    Cellulare2.Text = ROW.Item("CellulareA").ToString

                    'Dim IndirizzoId As TextBox = Me.AccordionPane4.FindControl("tbIndirizzoId")
                    'IndirizzoId.Text = ROW.Item("UtentiIndirizziId").ToString

                    RagioneSocialeA.Enabled = False
                    NomeA.Enabled = False
                    Indirizzo2.Enabled = False
                    Citta2.Enabled = False
                    Provincia2.Enabled = False
                    Cap2.Enabled = False
                    Zona.Enabled = False
                    Note.Enabled = False
                    Telefono2.Enabled = False
                    Fax2.Enabled = False
                    Cellulare2.Enabled = False

                Next

            Else

                For Each ROW As DataRow In dsdata.Tables(0).Rows

                    Dim NomeA As TextBox = Me.tbNomeA
                    NomeA.Text = ROW("NomeA").ToString

                    Dim Indirizzo2 As TextBox = Me.tbIndirizzo2
                    Indirizzo2.Text = ROW.Item("IndirizzoA").ToString

					Dim Cap2 As TextBox = Me.tbCap2
                    Cap2.Text = ROW.Item("CapA").ToString

					riempi_ddl_citta(Cap2.Text, ddlCitta2, tbProvincia2, dr.Item("CittaA").ToString)
					Dim Citta2 As DropDownList = Me.ddlCitta2
					
					Dim Provincia2 As TextBox = Me.tbProvincia

                    'Dim Provincia2 As TextBox = Me.tbProvincia2
                    'Provincia2.Text = ROW.Item("ProvinciaA").ToString
                    
                    Dim Telefono2 As TextBox = Me.tbTelefono2
                    Telefono2.Text = ROW.Item("TelefonoA").ToString

                    Dim Fax2 As TextBox = Me.tbFax2
                    Fax2.Text = ROW.Item("FaxA").ToString

                    Dim Cellulare2 As TextBox = Me.tbCellulare2
                    Cellulare2.Text = ROW.Item("CellulareA").ToString

                    Dim Zona As TextBox = Me.tbZona
                    Zona.Text = ROW.Item("Zona").ToString

                    Dim Note As TextBox = Me.tbNote
                    Note.Text = ROW.Item("Note").ToString

                    'Dim IndirizzoId As TextBox = Me.AccordionPane4.FindControl("tbIndirizzoId")
                    'IndirizzoId.Text = ROW.Item("UtentiIndirizziId").ToString

                    NomeA.Enabled = False
                    Indirizzo2.Enabled = False
                    Citta2.Enabled = False
                    Provincia2.Enabled = False
                    Cap2.Enabled = False
                    Zona.Enabled = False
                    Note.Enabled = False
                    Telefono2.Enabled = False
                    Fax2.Enabled = False
                    Cellulare2.Enabled = False

                Next

            End If

            'Dim drSecondario As MySqlDataReader = cmd.ExecuteReader()
            'drSecondario.Read()


            cmd.Dispose()

            cbCondizioniVendita.Enabled = False
            cbPrivacy.Enabled = False

        Catch ex As Exception
			
        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try

    End Sub

    Public Sub AggiornaDati()

        Try

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.CommandText = "update login set email=?email where ID=?id"
            cmd.Parameters.AddWithValue("?email", Me.tbEmail.Text)
            cmd.Parameters.AddWithValue("?id", Session("LoginID"))
            cmd.ExecuteNonQuery()

            Dim sqlUtenti As String = ""

            sqlUtenti = " update utenti set "
            sqlUtenti &= " telefono=?telefono, "
            sqlUtenti &= " fax=?fax, "
            sqlUtenti &= " cellulare=?cellulare, "
            sqlUtenti &= " Skype=?Skype, "
            sqlUtenti &= " infoNote=?infoNote, "
            sqlUtenti &= " url=?url, "
            sqlUtenti &= " Email=?Email "
            sqlUtenti &= " where ID=?id"

            cmd.CommandText = sqlUtenti
            cmd.Parameters.AddWithValue("?telefono", Me.tbTelefono.Text.ToUpper)
            cmd.Parameters.AddWithValue("?fax", Me.tbFax.Text.ToUpper)
            cmd.Parameters.AddWithValue("?cellulare", Me.tbCellulare.Text.ToUpper)
            cmd.Parameters.AddWithValue("?Skype", Me.tbSkype.Text.ToUpper)
            cmd.Parameters.AddWithValue("?infoNote", Me.TextBoxNote.Text.ToUpper)
            cmd.Parameters.AddWithValue("?url", Me.tbSito.Text.ToUpper)
            cmd.Parameters.AddWithValue("?Email", Me.tbEmail.Text.ToUpper)
            cmd.Parameters.AddWithValue("?id", Session("UtentiID"))
            cmd.ExecuteNonQuery()


            Dim sqlIndirizzi As String = ""

            sqlIndirizzi = "update utentiindirizzi set Ragionesocialea=?Ragionesocialea" &
            ", NomeA=?NomeA, indirizzoa=?indirizzoa, cittaa=?cittaa, provinciaa=?provinciaa, capa=?capa, zona=?zona, note=?note, predefinito=1 where ID=?id"

            cmd.CommandText = sqlIndirizzi
            cmd.Parameters.AddWithValue("?Ragionesocialea", Me.tbRagioneSocialeA.Text.ToUpper.Replace("'", "''"))
            cmd.Parameters.AddWithValue("?NomeA", Me.tbNomeA.Text.ToUpper.Replace("'", "''"))
            cmd.Parameters.AddWithValue("?indirizzoa", Me.tbIndirizzo2.Text.ToUpper.Replace("'", "''"))
            cmd.Parameters.AddWithValue("?cittaa", Me.getDdlCittaValue(ddlCitta2).ToUpper.Replace("'", "''"))
            cmd.Parameters.AddWithValue("?provinciaa", Me.tbProvincia2.Text.ToUpper.Replace("'", "''"))
            cmd.Parameters.AddWithValue("?capa", Me.tbCap2.Text.ToUpper)
            cmd.Parameters.AddWithValue("?zona", Me.tbZona.Text.ToUpper.Replace("'", "''"))
            cmd.Parameters.AddWithValue("?note", Me.tbNote.Text.ToUpper.Replace("'", "''"))
            cmd.Parameters.AddWithValue("?id", Me.tbIndirizzoId.Text.ToUpper)
            cmd.ExecuteNonQuery()
            cmd.Dispose()

            'Me.tRegistrazione.Visible = False
            Me.tConclusa.Visible = False
            Me.tAggiorna.Visible = True

            Email("Profilo aggiornato sul sito ", 2)

        Catch ex As Exception

        End Try

    End Sub

    Protected Sub rTipoPrivato_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles rTipoPrivato.CheckedChanged
        Privato()
    End Sub

    Public Sub Privato()
        Me.lblRagioneSociale.Text = "Cognome / <br>Ragione Sociale *"
        '--------------------------------------------------------------
        Me.lblNomeCognome.Text = "Nome *"
		Me.lblNomeCognome.Visible = True
        Me.tbNomeCognome.Visible = True
        Me.RequiredFieldValidator7.Visible = True
		Me.Panel_Fattura_Elettronica.Visible = True
        '---------------------------------------------------------------
        'Me.tbPartitaIva.Text = ""
        'Me.tbPartitaIva.Enabled = False
        Me.RequiredFieldValidator16.Visible = False
        'Me.tbPartitaIva.Visible = False
        'Me.lblPartitaIva.Visible = False
        'Label1.Visible = False
        '---------------------------------------------------------------
        If tbCodiceFiscale.Text <> "" Then
            'Me.Button_genera_codice_fiscale.Visible = False
            Me.TableAgevolazioni.Visible = False
        Else
            Me.Button_genera_codice_fiscale.Visible = True
            Me.TableAgevolazioni.Visible = True
        End If

        Me.label_codice_fiscale.Text = "Codice Fiscale *"
        RequiredFieldValidator12.Enabled = True
        Me.RegularExpressionValidator6.ValidationExpression = regexCFPrivato
		Me.tbCodiceFiscale.MaxLength = 16
    End Sub

    Public Sub Azienda()
        'tbRagioneSociale.Text = ""
        tbNomeCognome.Text = ""

        Me.lblRagioneSociale.Text = "Ragione Sociale *"
        '--------------------------------------------------------------
        'Me.lblNomeCognome.Text = "Nome e Cognome *"
        'Me.tbNomeCognome.Visible = False
        'Me.tbNomeCognome.Text = " "
        Me.tbNomeCognome.Visible = False
        Me.lblNomeCognome.Visible = False
        Me.RequiredFieldValidator7.Visible = False
        '---------------------------------------------------------------
        'Me.tbPartitaIva.Enabled = True
        Me.tbPartitaIva.Visible = True
        Me.lblPartitaIva.Visible = True
		Me.RequiredFieldValidator16.Visible = True
        Label1.Visible = True
		Me.Panel_Fattura_Elettronica.Visible = True
        '---------------------------------------------------------------
        Me.Panel_Cod_fiscale.Visible = False
        Me.Button_genera_codice_fiscale.Visible = False
		Me.lblPartitaIva.Text = "Partita Iva *"
        Me.label_codice_fiscale.Text = "Codice Fiscale"
        RequiredFieldValidator12.Enabled = False
        Me.RegularExpressionValidator6.ValidationExpression = regexCFAzienda
		Me.tbCodiceFiscale.MaxLength = 16
		Me.tbCsdi.MaxLength = 7
    End Sub
	
	Public Sub PubblicaAmministrazione()
        'tbRagioneSociale.Text = ""
        tbNomeCognome.Text = ""

        Me.lblRagioneSociale.Text = "Ragione Sociale *"
        '--------------------------------------------------------------
        'Me.lblNomeCognome.Text = "Nome e Cognome *"
        'Me.tbNomeCognome.Visible = False
        'Me.tbNomeCognome.Text = " "
        Me.tbNomeCognome.Visible = False
        Me.lblNomeCognome.Visible = False
        Me.RequiredFieldValidator7.Visible = False
        '---------------------------------------------------------------
        'Me.tbPartitaIva.Enabled = True
        Me.tbPartitaIva.Visible = True
        Me.lblPartitaIva.Visible = True
		Me.RequiredFieldValidator16.Visible = False
        Label1.Visible = True
		Me.Panel_Fattura_Elettronica.Visible = True
        '---------------------------------------------------------------
        Me.Panel_Cod_fiscale.Visible = False
        Me.Button_genera_codice_fiscale.Visible = False
		Me.lblPartitaIva.Text = "Partita Iva"
        Me.label_codice_fiscale.Text = "Codice Fiscale *"
        RequiredFieldValidator12.Enabled = True
        Me.RegularExpressionValidator6.ValidationExpression = regexCFAzienda
		Me.tbCodiceFiscale.MaxLength = 16
		Me.tbCsdi.MaxLength = 7
    End Sub

    Protected Sub rTipoAzienda_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles rTipoAzienda.CheckedChanged
        Azienda()
    End Sub
	
	Protected Sub rTipoPubblicaAmministrazione_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles rTipoPubblicaAmministrazione.CheckedChanged
        PubblicaAmministrazione()
    End Sub

    Protected Sub btRegistrati_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btRegistrati.Click
        
		Page.Validate()
		Dim datiFatturaElettronicaValidi As Boolean = true
		if Me.rTipoAzienda.checked then
			if Me.tbEmailPec.Text.trim = "" Then
				if Me.tbCsdi.Text.trim.Length < 7 OrElse Me.tbCsdi.Text.trim = "0000000" Then
					datiFatturaElettronicaValidi = false
					Me.lblPecAndSdi.Text = "La PEC o il codice SDI devono contenere un valore valido"
				End If
			else
				if (Me.tbCsdi.Text.trim.Length > 0 AndAlso Me.tbCsdi.Text.trim.Length < 7) OrElse Me.tbCsdi.Text.trim = "0000000" Then
					datiFatturaElettronicaValidi = false
					Me.lblPecAndSdi.Text = "La PEC o il codice SDI devono contenere un valore valido"
				End if 
			End If
		else if Me.rTipoPubblicaAmministrazione.checked
			if Me.tbCsdi.Text.trim.Length < 7 Then
				datiFatturaElettronicaValidi = false
				Me.lblPecAndSdi.Text = "Il codice SDI deve contenere un valore valido"
			End If
		End if
		
REM for each validator As BaseValidator in Page.Validators
    REM if validator.Enabled And Not validator.IsValid Then
		REM Response.Write("<script language='javascript'> alert('" & validator.ClientID & "'); </script>")
	REM end if
REM next

		if Page.IsValid AndAlso datiFatturaElettronicaValidi Then
		
			Try
				conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
				conn.Open()

				If Not Me.Session("LoginId") Is Nothing Then
					'Caso di Aggiornamento
					AggiornaDati()
					
				Else
				
					'Caso di Registrazione
					Registrazione()
				End If

			Catch ex As Exception

			Finally

				If conn.State = ConnectionState.Open Then
					conn.Close()
					conn.Dispose()
				End If

			End Try
		End If	

    End Sub

    Protected Sub imgModAccesso_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles imgModAccesso.Click

        Try
            Me.tbUsername.Enabled = False

            If imgModAccesso.Text = "MODIFICA" Then

				enable_mod_panel(Panel.Accesso)
				
            ElseIf imgModAccesso.Text = "SALVA" Then
				
				enable_Accesso(False)
				
                Dim sqlDatiAccesso As String = ""
                sqlDatiAccesso = " UPDATE LOGIN SET "
                sqlDatiAccesso &= " username = ?username, "
                sqlDatiAccesso &= " password = ?password, "
                sqlDatiAccesso &= " Email = ?email "
                sqlDatiAccesso &= " WHERE ID=?LoginID"

                conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                cmd.Connection = conn
                conn.Open()

                cmd.CommandType = CommandType.Text
                cmd.Parameters.AddWithValue("?username", tbUsername.Text.Replace("'", "''"))
                cmd.Parameters.AddWithValue("?password", tbPassword.Text)
                cmd.Parameters.AddWithValue("?email", tbEmail.Text.Trim.Replace("'", "''"))
                cmd.Parameters.AddWithValue("?LoginID", Session("LoginID"))
                cmd.CommandText = sqlDatiAccesso

                cmd.ExecuteNonQuery()

                sqlDatiAccesso = " UPDATE Utenti SET "
                sqlDatiAccesso &= " email = ?email "
                sqlDatiAccesso &= " WHERE ID=?utentiid"

                cmd.CommandType = CommandType.Text
                cmd.CommandText = sqlDatiAccesso
                cmd.Parameters.AddWithValue("?email", tbEmail.Text.Trim.Replace("'", "''"))
                cmd.Parameters.AddWithValue("?utentiid", Session("utentiid"))
                cmd.ExecuteNonQuery()

                CaricaDati()

            End If

        Catch ex As Exception

        End Try

    End Sub

	Protected Sub enable_Accesso(ByVal enable As boolean)
        Me.tbPassword.Enabled = enable
        Me.tbPasswordConferma.Enabled = enable
        Me.tbEmail.Enabled = enable
        Me.tbEmailConferma.Enabled = enable
	
		Dim img As Button = Me.imgModAccesso
	
		If enable Then
			img.ValidationGroup = "registrazione_Accesso"
			img.Text = "SALVA"
			img.BackColor=System.Drawing.Color.FromName("green")
		else
			img.ValidationGroup = Nothing
			img.Text = "MODIFICA"
			img.BackColor=System.Drawing.Color.FromName("red")
		End If
	End Sub
	
    Protected Sub imgModDatiAnagrafici_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles imgModDatiAnagrafici.Click
        Try
			Me.rTipoAzienda.Enabled = False
            Me.rTipoPrivato.Enabled = False

            If imgModDatiAnagrafici.Text = "MODIFICA" Then
			
				enable_DatiAnagrafici(True)
				
            ElseIf imgModDatiAnagrafici.Text = "SALVA" Then
			
                enable_DatiAnagrafici(False)
				
                Dim sqlDatiAnagrafici As String = ""
                sqlDatiAnagrafici = " UPDATE UTENTI SET "
                sqlDatiAnagrafici &= " cognomenome = ?cognomenome, "
                sqlDatiAnagrafici &= " ragionesociale = ?RAGIONESOCIALE, "
                sqlDatiAnagrafici &= " codicefiscale = ?codicefiscale, "
                sqlDatiAnagrafici &= " piva = ?piva "
                sqlDatiAnagrafici &= " WHERE ID=?UTENTIID"

                conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                cmd.Connection = conn

                conn.Open()

                cmd.CommandType = CommandType.Text
                cmd.CommandText = sqlDatiAnagrafici
                cmd.Parameters.AddWithValue("?RAGIONESOCIALE", tbRagioneSociale.Text.Replace("'", "''"))
                cmd.Parameters.AddWithValue("?piva", tbPartitaIva.Text.Replace("'", "''"))
                cmd.Parameters.AddWithValue("?codicefiscale", tbCodiceFiscale.Text.Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?cognomenome", tbNomeCognome.Text.Replace("'", "''"))
                cmd.Parameters.AddWithValue("?UTENTIID", Me.Session("UTENTIID"))
                cmd.ExecuteNonQuery()

                sqlDatiAnagrafici = "UPDATE LOGIN SET COGNOMENOME = ?RAGIONESOCIALE"
                sqlDatiAnagrafici &= " WHERE ID=?id"
                cmd.CommandText = sqlDatiAnagrafici
                cmd.Parameters.AddWithValue("?RAGIONESOCIALE", tbRagioneSociale.Text.Replace("'", "''"))
                cmd.Parameters.AddWithValue("?id", Me.Session("LOGINID"))
                cmd.ExecuteNonQuery()

                CaricaDati()

            End If

        Catch ex As Exception

        End Try
    End Sub

	Protected Sub enable_DatiAnagrafici(ByVal enable As boolean)
		Me.tbRagioneSociale.Enabled = enable
        Me.tbCodiceFiscale.Enabled = enable
        Me.tbPartitaIva.Enabled = enable
        Me.tbNomeCognome.Enabled = enable
	
		Dim img As Button = Me.imgModDatiAnagrafici
	
		If enable Then
			img.ValidationGroup = "registrazione_DatiAnagrafici"
			img.Text = "SALVA"
			img.BackColor=System.Drawing.Color.FromName("green")
		else
			img.ValidationGroup = Nothing
			img.Text = "MODIFICA"
			img.BackColor=System.Drawing.Color.FromName("red")
		End If
	End Sub
	
    Protected Sub imgModIndirizzoP_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles imgModIndirizzoP.Click
        Try

            If Me.imgModIndirizzoP.Text = "MODIFICA" Then

				enable_mod_panel(Panel.Fatturazione)
				
            ElseIf Me.imgModIndirizzoP.Text = "SALVA" Then

                enable_indirizzoP(False)
				
                Dim sqlIndirizzoP As String = ""
                sqlIndirizzoP = " UPDATE UTENTI SET "
                sqlIndirizzoP &= " indirizzo = ?indirizzo, "
                sqlIndirizzoP &= " citta = ?citta, "
                sqlIndirizzoP &= " provincia = ?provincia, "
                sqlIndirizzoP &= " cap = ?cap, "
                sqlIndirizzoP &= " telefono = ?telefono, "
                sqlIndirizzoP &= " fax = ?fax, "
                sqlIndirizzoP &= " cellulare = ?cellulare, "
                sqlIndirizzoP &= " Skype = ?Skype, "
                sqlIndirizzoP &= " url = ?url "
                sqlIndirizzoP &= " WHERE ID=?UTENTIID"

                conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                cmd.Connection = conn

                conn.Open()

                cmd.CommandType = CommandType.Text
                cmd.Parameters.AddWithValue("?UTENTIID", Session("UTENTIID"))
                cmd.Parameters.AddWithValue("?indirizzo", tbIndirizzo.Text.Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?citta", getDdlCittaValue(ddlCitta).Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?provincia", tbProvincia.Text.Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?cap", tbCap.Text.Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?telefono", tbTelefono.Text.Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?fax", tbFax.Text.Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?cellulare", tbCellulare.Text.Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?Skype", tbSkype.Text.Replace("'", "''").ToUpper)
                cmd.Parameters.AddWithValue("?url", tbSito.Text.Replace("'", "''").ToUpper)

                cmd.CommandText = sqlIndirizzoP

                cmd.ExecuteNonQuery()

                CaricaDati()

            End If

        Catch ex As Exception

        End Try

    End Sub
	
	Protected Sub enable_indirizzoP(ByVal enable As boolean)
		Me.tbIndirizzo.Enabled = enable
        Me.ddlCitta.Enabled = enable
        Me.tbProvincia.Enabled = enable
        Me.tbCap.Enabled = enable
		Me.tbTelefono.Enabled = enable
        Me.tbFax.Enabled = enable
        Me.tbCellulare.Enabled = enable
        Me.tbSkype.Enabled = enable
        Me.tbSito.Enabled = enable
	
		Dim img As Button = Me.imgModIndirizzoP
	
		If enable Then
			img.ValidationGroup = "registrazione_indirizzoP"
			img.Text = "SALVA"
			img.BackColor=System.Drawing.Color.FromName("green")
		else
			img.ValidationGroup = Nothing
			img.Text = "MODIFICA"
			img.BackColor=System.Drawing.Color.FromName("red")
		End If
	End Sub

	Protected Sub enable_FatturaElettronica(ByVal enable As boolean)
		Me.tbEmailPec.Enabled = enable
		Me.tbCsdi.Enabled = enable
	
		Dim img As Button = Me.imgModFatturaElettronica
	
		If enable Then
			img.ValidationGroup = "registrazione_FatturaElettronica"
			img.Text = "SALVA"
			img.BackColor=System.Drawing.Color.FromName("green")
		else
			img.ValidationGroup = Nothing
			img.Text = "MODIFICA"
			img.BackColor=System.Drawing.Color.FromName("red")
		End If
	End Sub
	
	Protected Sub imgModDestinazione_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles imgModDestinazione.Click
		enable_mod_panel(Panel.Spedizione, "mod")
    End Sub
	
	Protected Sub imgInsDestinazione_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles imgInsDestinazione.Click
		enable_mod_panel(Panel.Spedizione, "ins")
    End Sub
	
	Protected Sub imgModFatturaElettronica_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles imgModFatturaElettronica.Click
        Try

            If Me.imgModFatturaElettronica.Text = "MODIFICA" Then
				enable_mod_panel(Panel.FatturaElettronica)
            ElseIf Me.imgModFatturaElettronica.Text = "SALVA" Then
                enable_FatturaElettronica(False)
				
                Dim sqlFatturaElettronica As String = ""
                sqlFatturaElettronica = " UPDATE UTENTI SET "
                sqlFatturaElettronica &= " email_pec = ?emailPec, "
                sqlFatturaElettronica &= " codice_sdi = ?sdi "
                sqlFatturaElettronica &= " WHERE ID=?UTENTIID"

                conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                cmd.Connection = conn

                conn.Open()

                cmd.CommandType = CommandType.Text
                cmd.Parameters.AddWithValue("?UTENTIID", Session("UTENTIID"))
                cmd.Parameters.AddWithValue("?emailPec", tbEmailPec.Text.ToUpper)
                cmd.Parameters.AddWithValue("?sdi", tbCsdi.Text.ToUpper)
                cmd.CommandText = sqlFatturaElettronica

                cmd.ExecuteNonQuery()

                CaricaDati()

            End If

        Catch ex As Exception

        End Try

    End Sub

	
	
    Protected Sub imgModIndirizzoS_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles imgModIndirizzoS.Click
        Try

            If Me.imgModIndirizzoS.Text = "MODIFICA" Then

                enable_indirizzoS(True)
				
            ElseIf Me.imgModIndirizzoS.Text = "SALVA" Then

                enable_indirizzoS(False)
				
                conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                cmd.Connection = conn

                conn.Open()

                Dim sqlIndirizzoS As String = ""

                ' controllo se l'utente ha già inserito una seconda destinazione
                Dim sqlString As String = ""

                sqlString = " SELECT COUNT(ID) AS TOT "
                sqlString &= " FROM utentiindirizzi "
                sqlString &= " WHERE UTENTEID = ?UTENTIID "

                cmd.CommandType = CommandType.Text
                cmd.CommandText = sqlString
                cmd.Parameters.AddWithValue("?UTENTIID", Session("UTENTIID"))
                Dim tot As Integer = cmd.ExecuteScalar

                If tot >= 1 Then
                    'Aggiorno l'indirizzo secondario predefinito

                    sqlIndirizzoS = " UPDATE utentiindirizzi SET "
                    sqlIndirizzoS &= " RagioneSocialeA = ?RAGIONESOCIALEA, "
                    sqlIndirizzoS &= " NomeA = ?NOMEA, "
                    sqlIndirizzoS &= " IndirizzoA = ?INDIRIZZOA, "
                    sqlIndirizzoS &= " CittaA = ?CITTAA, "
                    sqlIndirizzoS &= " ProvinciaA = ?PROVINCIAA, "
                    sqlIndirizzoS &= " CapA = ?CAPA, "
                    sqlIndirizzoS &= " TelefonoA = ?TELEFONOA, "
                    If tbFax2.Text <> "" Then
                        sqlIndirizzoS &= " FaxA = ?FAX, "
                    End if
					if tbCellulare2.Text <> "" Then
                        sqlIndirizzoS &= " CellulareA = ?CELL, "
                    End If
                    sqlIndirizzoS &= " Zona = ?ZONA, "
                    sqlIndirizzoS &= " Note = ?NOTE "
                    'sqlIndirizzoS &= " UtentiIndirizziId = '" & tbIndirizzoId.Text.Replace("'", "''") & "' "
                    sqlIndirizzoS &= " WHERE PREDEFINITO = 1 AND UTENTEID=?UTENTIID"

                    cmd.Parameters.AddWithValue("?UTENTIID", Session("UTENTIID"))
                    cmd.Parameters.AddWithValue("?RAGIONESOCIALEA", tbRagioneSocialeA.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?NOMEA", tbNomeA.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?INDIRIZZOA", tbIndirizzo2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?CAPA", tbCap2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?CITTAA", getDdlCittaValue(ddlCitta2).Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?PROVINCIAA", tbProvincia2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?NOTE", tbNote.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?ZONA", tbZona.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?TELEFONOA", tbTelefono2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?CELL", tbCellulare2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?FAX", tbFax2.Text.Replace("'", "''").ToUpper)

                Else
                    'Inserisco un nuovo indirizzo secondario predefinito all'utente

                    sqlIndirizzoS = "INSERT INTO utentiindirizzi "
                    sqlIndirizzoS &= "("
                    sqlIndirizzoS &= " RagioneSocialeA, "
                    sqlIndirizzoS &= "NomeA, "
                    sqlIndirizzoS &= "IndirizzoA, "
                    sqlIndirizzoS &= "CittaA, "
                    sqlIndirizzoS &= "ProvinciaA, "
                    sqlIndirizzoS &= "CapA, "
                    sqlIndirizzoS &= "TelefonoA, "
					if tbFax2.Text <> "" then
						sqlIndirizzoS &= "FaxA, "
					end if
					if tbCellulare2.Text <> "" then
						sqlIndirizzoS &= "CellulareA, "
					end if
                    sqlIndirizzoS &= "Zona, "
                    sqlIndirizzoS &= "Note, "
                    sqlIndirizzoS &= "Predefinito, "
                    sqlIndirizzoS &= "UTENTEID "
                    sqlIndirizzoS &= ")"

                    sqlIndirizzoS &= " VALUES "

                    sqlIndirizzoS &= "("
                    sqlIndirizzoS &= " ?RAGIONESOCIALEA, "
                    sqlIndirizzoS &= " ?NOMEA, "
                    sqlIndirizzoS &= " ?INDIRIZZOA, "
                    sqlIndirizzoS &= " ?CITTAA, "
                    sqlIndirizzoS &= " ?PROVINCIAA, "
                    sqlIndirizzoS &= " ?CAPA, "
                    sqlIndirizzoS &= " ?TELEFONOA, "
                    If tbFax2.Text <> "" Then
                        sqlIndirizzoS &= " ?FAX, "
                    End if
					if tbCellulare2.Text <> "" Then
                        sqlIndirizzoS &= " ?CELL, "
                    End If
                    sqlIndirizzoS &= " ?ZONA, "
                    sqlIndirizzoS &= " ?NOTE, "
                    sqlIndirizzoS &= " 1, "
                    sqlIndirizzoS &= "?UTENTIID"
                    sqlIndirizzoS &= ")"
                    cmd.Parameters.AddWithValue("?UTENTIID", Session("UTENTIID"))
                    cmd.Parameters.AddWithValue("?RAGIONESOCIALEA", tbRagioneSocialeA.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?NOMEA", tbNomeA.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?INDIRIZZOA", tbIndirizzo2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?CAPA", tbCap2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?CITTAA", getDdlCittaValue(ddlCitta2).Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?PROVINCIAA", tbProvincia2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?NOTE", tbNote.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?ZONA", tbZona.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?TELEFONOA", tbTelefono2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?CELL", tbCellulare2.Text.Replace("'", "''").ToUpper)
                    cmd.Parameters.AddWithValue("?FAX", tbFax2.Text.Replace("'", "''").ToUpper)
                End If

                cmd.CommandType = CommandType.Text
                cmd.CommandText = sqlIndirizzoS

                cmd.ExecuteNonQuery()

                conn.Close()

                CaricaDati()

            End If

        Catch ex As Exception

        End Try

    End Sub

	Protected Sub enable_indirizzoS(ByVal enable As boolean)
	
		Me.tbRagioneSocialeA.Enabled = enable
        Me.tbNomeA.Enabled = enable
        Me.tbIndirizzo2.Enabled = enable
        Me.ddlCitta2.Enabled = enable
        Me.tbProvincia2.Enabled = enable
        Me.tbCap2.Enabled = enable
        Me.tbZona.Enabled = enable
        Me.tbNote.Enabled = enable
        Me.tbTelefono2.Enabled = enable
        Me.tbFax2.Enabled = enable
        Me.tbCellulare2.Enabled = enable
        Me.tbIndirizzoId.Enabled = enable
		
		Dim img As Button = Me.imgModIndirizzoS
		
		If enable Then
			img.ValidationGroup = "registrazione_indirizzoS"
			img.Text = "SALVA"
			img.BackColor=System.Drawing.Color.FromName("green")
		else
			img.ValidationGroup = Nothing
			img.Text = "MODIFICA"
			img.BackColor=System.Drawing.Color.FromName("red")
		End If
	End Sub
	
    'Protected Sub imgModRegistrazione_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles imgModRegistrazione.Click

    '    Try

    '        Dim CondizioniVendita As CheckBox = Me.AccordionPane5.FindControl("cbCondizioniVendita")
    '        Dim Privacy As CheckBox = Me.AccordionPane5.FindControl("cbPrivacy")

    '        Dim img As ImageButton = Me.AccordionPane5.FindControl("imgModRegistrazione")

    '        If img.ImageUrl = "ico/modify.png" Then

    '            CondizioniVendita.Enabled = True
    '            Privacy.Enabled = True

    '            img.ImageUrl = "ico/save.png"
    '            img.Attributes.Remove("title")
    '            img.Attributes.Add("title", "Salva")
    '            img.AlternateText = "Salva"

    '        ElseIf img.ImageUrl = "ico/save.png" Then

    '            CondizioniVendita.Enabled = False
    '            Privacy.Enabled = False

    '            img.ImageUrl = "ico/modify.png"
    '            img.Attributes.Remove("title")
    '            img.Attributes.Add("title", "Modifica")
    '            img.AlternateText = "Modifica"

    '        End If

    '    Catch ex As Exception

    '    End Try

    'End Sub

    Protected Sub CheckBoxAgevolazione_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles CheckBoxAgevolazione.CheckedChanged
        If Me.CheckBoxAgevolazione.Checked Then
            Me.DropDownListAgevolazione.Enabled = True
            Me.tbEmailIstituzionale.Enabled = True
            Me.RequiredFieldValidator17.Enabled = True
        Else
            Me.DropDownListAgevolazione.Enabled = False
            Me.tbEmailIstituzionale.Enabled = False
            Me.RequiredFieldValidator17.Enabled = False
        End If
    End Sub

	Protected Sub check_vat(ByVal sender As Object, ByVal e As System.EventArgs)
		Me.lblPiva.Text = ""
		riempi_campi_da_piva("IT" , tbPartitaIva.Text)
	End Sub
	
	Protected Sub riempi_campi_da_piva(ByVal countryCode As String, ByVal vat As String)
		try
			Dim test As CheckVat.checkVatPortType = New CheckVat.checkVatPortTypeClient()
			Dim response As CheckVat.checkVatResponse = test.checkVat(New CheckVat.checkVatRequest(countryCode, vat))
			if response.valid Then
				Dim address As String() = response.address.Split(vbLf)
				tbIndirizzo.text = address(0).Trim
				tbCap.text = address(1).Substring(0,5)
				riempi_ddl_citta(tbCap.Text, ddlCitta, tbProvincia, address(1).Substring(6,address(1).Length - 9))
				tbRagioneSociale.text = response.name.Trim
			'Else
			'	tbIndirizzo.text = ""
			'	tbCap.text = ""
			'	riempi_ddl_citta(tbCap.Text, ddlCitta, tbProvincia)
			'	tbRagioneSociale.text = ""
			'	RegularExpressionValidator5.validate
			End If
		Catch ex As Exception
			
		End try
	End Sub
	
    Protected Sub ddlProvinciaNascita_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles ddlProvinciaNascita.TextChanged
        scegliComuniNascita(sender, e)
    End Sub
	
	Protected Sub Province_Bind_Data(ByVal sender As Object, ByVal e As System.EventArgs)
		riempi_text_provincia(getDdlCittaValue(ddlCitta), tbProvincia)
    End Sub
	
	Protected Sub Province_Bind_Data2(ByVal sender As Object, ByVal e As System.EventArgs)
		riempi_text_provincia(getDdlCittaValue(ddlCitta2), tbProvincia2)
    End Sub
	
	Protected Sub Province_Bind_Data3(ByVal sender As Object, ByVal e As System.EventArgs)
		riempi_text_provincia(getDdlCittaValue(ddlCitta2Dest), tbProvincia2Dest)
    End Sub
	
	Protected Sub riempi_text_provincia(ByVal citta As String, ByVal provincia As TextBox)
		If citta <> String.Empty Then
			Dim ds As DataSet = cityRegistry.GetProvinceFromCity(citta)
			provincia.text = ds.Tables(0).Rows(0)("abbreviation").ToString()
		Else
			provincia.text = String.Empty
		End If
    End Sub
	
	Protected Sub City_Bind_Data(ByVal sender As Object, ByVal e As System.EventArgs)
		riempi_ddl_citta(tbCap.Text, ddlCitta, tbProvincia)
    End Sub
	
	Protected Sub City_Bind_Data2(ByVal sender As Object, ByVal e As System.EventArgs)
		riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2)
    End Sub
	
	Protected Sub City_Bind_Data3(ByVal sender As Object, ByVal e As System.EventArgs)
		riempi_ddl_citta(tbCap2Dest.Text, ddlCitta2Dest, tbProvincia2Dest)
    End Sub
	
	Protected Sub riempi_ddl_citta(ByVal cap As String, ByVal cittaddl As DropDownList, ByVal provincia As TextBox, Optional ByVal citta As String = "")
		
		Dim ds As DataSet = cityRegistry.GetCitiesFromPostcodeCode(cap)
		ConvertDataSetColumnToUpper(ds, "name_city")
		cittaddl.DataSource = ds.Tables(0)
		cittaddl.DataTextField = ds.Tables(0).Columns("name_city").ToString().ToUpper()
        cittaddl.DataValueField = ds.Tables(0).Columns("name_city").ToString().ToUpper()
		cittaddl.DataBind()
		If citta <> String.Empty Then
			cittaddl.Items(cittaddl.SelectedIndex).Selected=false
			cittaddl.Items.FindByValue(citta).Selected=true
		End If
		citta = String.Empty
		If cittaddl.Items.Count > 0 Then
			citta = cittaddl.Items(cittaddl.SelectedIndex).Text
		End If
		
		riempi_text_provincia(citta, provincia)
    End Sub
	
	Protected Function ConvertDataSetColumnToUpper(ByRef ds As DataSet, ByVal columnName As String)
		For Each row As DataRow In ds.Tables(0).Rows
			row(columnName) = row(columnName).ToString().ToUpper()
		Next
	End Function	
		
    Protected Sub Button_genera_codice_fiscale_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_genera_codice_fiscale.Click
        If (Me.Panel_Cod_fiscale.Visible = True) Then
            Me.Button_genera_codice_fiscale.Text = "GENERA CODICE FISCALE"
            If (rboNatiEstero.Checked) Then
                tbCodiceFiscale.Text = calcolaCodiceFiscale(tbNomeCognome.Text, tbRagioneSociale.Text, txtDataNascita.Text, rblSesso.SelectedValue, ddlStatoNascita.SelectedItem.Value)
            Else ' nato in Italia
                tbCodiceFiscale.Text = calcolaCodiceFiscale(tbNomeCognome.Text, tbRagioneSociale.Text, txtDataNascita.Text, rblSesso.SelectedValue, ddlComuneNascita.SelectedItem.Value)
            End If
            Me.Panel_Cod_fiscale.Visible = False
            Me.RequiredFieldValidator19.Enabled = True
            Me.RequiredFieldValidator7.Enabled = True
        Else
            Me.Panel_Cod_fiscale.Visible = True
            Me.Button_genera_codice_fiscale.Text = "<<< GENERA E INSERISCI"
            Me.RequiredFieldValidator19.Enabled = False
            Me.RequiredFieldValidator7.Enabled = False
        End If

    End Sub

    Protected Sub RB_IndirizzoSpedizioneDiverso_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles RB_IndirizzoSpedizioneDiverso.CheckedChanged
        If RB_IndirizzoSpedizioneDiverso.Checked = True Then
			clear_indirizzoSecondario()
            Panel_IndirizzoSecondario.Visible = True
            Panel_IndirizzoSecondario.Enabled = True
        Else
            Panel_IndirizzoSecondario.Visible = False
            Panel_IndirizzoSecondario.Enabled = False

            'Reimposto i valori dei campi impostati precedentemente
            tbRagioneSocialeA.Text = tbRagioneSociale.Text
            tbNomeA.Text = tbNomeCognome.Text
            tbIndirizzo2.Text = tbIndirizzo.Text
            'tbCitta2.Text = ddlCitta.Text
            'tbProvincia2.Text = tbProvincia.Text
            tbCap2.Text = tbCap.Text
			Dim selectedCity As String
			try 
				selectedCity = ddlCitta.SelectedItem.Value
			catch
				selectedCity = String.Empty
			End try
			riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2, selectedCity)
            tbTelefono2.Text = tbTelefono.Text
            tbFax2.Text = tbFax.Text
            tbCellulare2.Text = tbCellulare.Text
        End If
    End Sub

    Protected Sub RB_IndirizzoSpedizioneUguale_CheckedChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles RB_IndirizzoSpedizioneUguale.CheckedChanged
        If RB_IndirizzoSpedizioneDiverso.Checked = True Then
			clear_indirizzoSecondario()
            Panel_IndirizzoSecondario.Visible = True
            Panel_IndirizzoSecondario.Enabled = True
        Else
            Panel_IndirizzoSecondario.Visible = False
            Panel_IndirizzoSecondario.Enabled = False

            'Reimposto i valori dei campi impostati precedentemente
            tbRagioneSocialeA.Text = tbRagioneSociale.Text
            tbNomeA.Text = tbNomeCognome.Text
            tbIndirizzo2.Text = tbIndirizzo.Text
            'tbCitta2.Text = ddlCitta.Text
            'tbProvincia2.Text = tbProvincia.Text
            tbCap2.Text = tbCap.Text
			Dim selectedCity As String
			try 
				selectedCity = ddlCitta.SelectedItem.Value
			catch
				selectedCity = String.Empty
			End try
			riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2, selectedCity)
            tbTelefono2.Text = tbTelefono.Text
            tbFax2.Text = tbFax.Text
            tbCellulare2.Text = tbCellulare.Text
        End If
    End Sub
	
	Public Sub BindLstDestinazione()

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet

        Try

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            sqlString = "SELECT ID, CONCAT(RAGIONESOCIALEA, ' - ', NOMEA, ' - ',INDIRIZZOA, ', CAP: ', CAPA, ' - ',CITTAA,' (', PROVINCIAA, ')')AS CAMPO FROM utentiindirizzi where UTENTEID = ?UTENTIID Order by Predefinito Desc"

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("?UTENTIID", Session("UTENTIID"))
            cmd.CommandText = sqlString


            Dim sqlAdp As New MySqlDataAdapter(cmd)
            sqlAdp.Fill(dsData, "utentiindirizzi")

            cmd.Dispose()

            LstDestinazione.Items.Clear()
            LstDestinazione.DataSource = dsData
            LstDestinazione.DataValueField = "ID"
            LstDestinazione.DataTextField = "CAMPO"
            LstDestinazione.DataBind()
			
			enable_mod_destinazione(false, "")

        Catch ex As Exception

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try
		If Not LstDestinazione.SelectedItem is Nothing Then
			compila_campi_destinazione(LstDestinazione.SelectedValue)
		 End If
    End Sub
	
	Protected Sub LstDestinazione_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles LstDestinazione.PreRender
		if LstDestinazione.items.count > 0 Then
			Session("DESTINAZIONEALTERNATIVA") = LstDestinazione.SelectedItem.Value
			btnModDest.enabled = true
			if LstDestinazione.items.count > 1 Then
				btnElimDest.enabled = true
			End If
			'Aggiorno i campi Text sottostanti per dar modo all'utente di modificare o inserire una nuova destinazione in modo facile
			
		else
			'clear_destinazione()
		End If
    End Sub
	
	Protected Sub LstDestinazione_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles LstDestinazione.SelectedIndexChanged
        If LstDestinazione.SelectedItem.Value <> "0" Then
            Session("DESTINAZIONEALTERNATIVA") = LstDestinazione.SelectedItem.Value
			compila_campi_destinazione(LstDestinazione.SelectedValue)
        Else
            Session("DESTINAZIONEALTERNATIVA") = 0
        End If
    End Sub
	
	Protected Sub enable_mod_destinazione(ByVal enable As boolean, ByVal insOrMod As String)
		Me.tbRagioneSocialeADest.Enabled = enable
		Me.tbNomeADest.Enabled = enable
		Me.tbIndirizzo2Dest.Enabled = enable
		Me.tbCap2Dest.Enabled = enable
		Me.ddlCitta2Dest.Enabled = enable
		Me.tbProvincia2Dest.Enabled = enable
		Me.tbNoteDest.Enabled = enable
		Me.tbZonaDest.Enabled = enable
		Me.tbTelefono2Dest.Enabled = enable
		CHKPREDEFINITO.Enabled = enable
		
		Me.imgModDestinazione.Visible = Not(enable)
		Me.imgInsDestinazione.Visible = Not(enable)
		
		If enable Then
			if insOrMod = "mod" then
				Me.imgModDestinazione.ValidationGroup = "registrazione_Destinazione"
				Me.PnlBottoniDestinazioneModifica.visible = "True"
			else if insOrMod = "ins" then
				Me.imgInsDestinazione.ValidationGroup = "registrazione_Destinazione"
				Me.PnlBottoniDestinazioneInserisci.visible = "True"
				clear_destinazione()
			end if
		else
			Me.PnlBottoniDestinazioneModifica.visible = "False"
			Me.PnlBottoniDestinazioneInserisci.visible = "False"
			Me.imgModDestinazione.ValidationGroup = Nothing
			Me.imgInsDestinazione.ValidationGroup = Nothing
		End If
		
	End Sub
	
	Protected Sub clear_destinazione()
		Me.tbRagioneSocialeADest.Text = ""
        Me.tbNomeADest.Text = ""
        Me.tbIndirizzo2Dest.Text = ""
        Me.tbCap2Dest.Text = ""
        riempi_ddl_citta(tbCap2Dest.Text, ddlCitta2Dest, tbProvincia2Dest, "")
        Me.tbProvincia2Dest.Text = ""
        Me.tbNoteDest.Text = ""
        Me.tbZonaDest.Text = ""
		Me.tbTelefono2Dest.Text = ""
		CHKPREDEFINITO.Checked = False
	End Sub
	
	Protected Sub clear_indirizzoSecondario()
		Me.tbRagioneSocialeA.Text = ""
        Me.tbNomeA.Text = ""
        Me.tbIndirizzo2.Text = ""
        Me.tbCap2.Text = ""
        riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2, "")
        Me.tbProvincia2.Text = ""
        Me.tbNote.Text = ""
        Me.tbZona.Text = ""
		Me.tbTelefono2.Text = ""
		CHKPREDEFINITO.Checked = False
	End Sub
	
    Protected Sub btnAnnullaDestMod_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnAnnullaDestMod.Click
		BindLstDestinazione()
    End Sub
	
	Protected Sub btnAnnullaDestIns_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnAnnullaDestIns.Click
		BindLstDestinazione()
    End Sub
	
	Sub compila_campi_destinazione(ByVal idDestinazione As Integer)
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dr As MySqlDataReader
        Dim predefinito As Integer = 0

        Try
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            sqlString = "SELECT * FROM utentiindirizzi WHERE (ID=" & idDestinazione & ")"

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.CommandText = sqlString

            dr = cmd.ExecuteReader

            If dr.Read Then
				tbRagioneSocialeADest.Text = get_DB_Field_value(dr,"RagioneSocialeA")
				tbNomeADest.Text = get_DB_Field_value(dr,"NomeA")
				tbIndirizzo2Dest.Text = get_DB_Field_value(dr,"IndirizzoA")
				tbCap2Dest.Text = get_DB_Field_value(dr,"CapA")
				riempi_ddl_citta(tbCap2Dest.Text, ddlCitta2Dest, tbProvincia2Dest, get_DB_Field_value(dr,"CittaA"))
				'tbProvincia2Dest.Text = get_DB_Field_value(dr,"ProvinciaA")
				tbZonaDest.Text = get_DB_Field_value(dr,"Zona")
				tbTelefono2Dest.Text = get_DB_Field_value(dr,"TelefonoA")
				tbNoteDest.Text = get_DB_Field_value(dr,"Note")
				If get_DB_Field_value(dr,"Predefinito") = "1" Then
					CHKPREDEFINITO.Checked = True
				Else
					CHKPREDEFINITO.Checked = False
				End If
            End If

            dr.Close()
            conn.Close()

        Catch ex As Exception

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try
    End Sub
	
	Function get_DB_Field_value(ByVal dr As MySqlDataReader, ByVal fieldName As String) As String
		if isDBNull(dr.Item(fieldName)) Then
			return ""
		Else
			return dr.Item(fieldName)
		End If
	End Function
	
	Protected Sub btnSalvaDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnSalvaDest.Click

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet
		Dim sqlStringPredefinitoField As String = ""
		Dim sqlStringPredefinitoValue As String = ""
		
        Try

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text

			If CHKPREDEFINITO.Checked Then
                sqlString = "UPDATE utentiindirizzi SET Predefinito=0 WHERE UtenteId=?UTENTIID"
                cmd.CommandText = sqlString
                cmd.Parameters.AddWithValue("?UTENTIID", Session("UTENTIID"))
                cmd.ExecuteNonQuery()
				
				sqlStringPredefinitoField = "    , PREDEFINITO "
				sqlStringPredefinitoValue = ", 1"
			'Else If LstDestinazione.items(0).value = 0 And LstDestinazione.items.count = 1 Then
			Else If LstDestinazione.items.count = 0 Then
				sqlStringPredefinitoField = "    , PREDEFINITO "
				sqlStringPredefinitoValue = ", 1"
			End If

			sqlString = " INSERT INTO utentiindirizzi "
            sqlString &= " ("
            sqlString &= "      UTENTEID, "
            sqlString &= "      RAGIONESOCIALEA, "
            sqlString &= "      NOMEA, "
            sqlString &= "      INDIRIZZOA, "
            sqlString &= "      CAPA, "
            sqlString &= "      CITTAA, "
            sqlString &= "      PROVINCIAA, "
            sqlString &= "      NOTE, "
			sqlString &= "      TELEFONOA, "
            sqlString &= "      ZONA "
            sqlString &= sqlStringPredefinitoField
            sqlString &= " )"
            sqlString &= " VALUES "
            sqlString &= " ("
            sqlString &= "  ?UTENTIID, "
            sqlString &= "  ?RAGIONESOCIALEA, "
            sqlString &= "  ?NOMEA,"
            sqlString &= "  ?INDIRIZZOA, "
            sqlString &= "  ?CAPA, "
            sqlString &= "  ?CITTAA, "
            sqlString &= "  ?PROVINCIAA, "
            sqlString &= "  ?NOTE, "
            sqlString &= "  ?TELEFONOA, "
            sqlString &= "  ?ZONA"
            sqlString &= sqlStringPredefinitoValue
			sqlString &= " )"

            cmd.CommandText = sqlString
            cmd.Parameters.AddWithValue("?UTENTIID", Session("UTENTIID"))
            cmd.Parameters.AddWithValue("?RAGIONESOCIALEA", Me.tbRagioneSocialeADest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?NOMEA", Me.tbNomeADest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?INDIRIZZOA", Me.tbIndirizzo2Dest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?CAPA", Me.tbCap2Dest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?CITTAA", getDdlCittaValue(Me.ddlCitta2Dest).Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?PROVINCIAA", Me.tbProvincia2Dest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?NOTE", Me.tbNoteDest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?ZONA", Me.tbZonaDest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?TELEFONOA", Me.tbTelefono2Dest.Text.Replace("'", "''").ToUpper)
            cmd.ExecuteNonQuery()

            cmd.Dispose()

            BindLstDestinazione()

        Catch ex As Exception
		
        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try

    End Sub
	
	
    Protected Sub btnElimDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnElimDest.Click
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet

		if LstDestinazione.Items.Count>1 Then
			Try
				conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
				conn.Open()

				cmd.Connection = conn
				cmd.CommandType = CommandType.Text

                sqlString = "SELECT * FROM utentiindirizzi WHERE Id=?destinazione"
                cmd.CommandText = sqlString
                cmd.Parameters.AddWithValue("?destinazione", LstDestinazione.SelectedValue)
                Dim dr As MySqlDataReader = cmd.ExecuteReader()
				dr.Read()
				Dim predefinito As Integer = dr.item("predefinito")
				dr.close()

                sqlString = "DELETE FROM utentiindirizzi WHERE Id=?destinazione"
                cmd.CommandText = sqlString
                cmd.Parameters.AddWithValue("?destinazione", LstDestinazione.SelectedValue)
                cmd.ExecuteNonQuery()
				
				if predefinito = 1 Then
                    sqlString = "UPDATE utentiindirizzi SET Predefinito=1 WHERE UtenteId=?UtenteId ORDER BY Id DESC LIMIT 1"
                    cmd.CommandText = sqlString
                    cmd.Parameters.AddWithValue("?UtenteId", Session("UTENTIID"))
                    cmd.ExecuteNonQuery()
				End If
				
				cmd.Dispose()

				BindLstDestinazione()

			Catch ex As Exception

			Finally

				If conn.State = ConnectionState.Open Then
					conn.Close()
					conn.Dispose()
				End If

			End Try
		End If
    End Sub
	
	Protected Sub btnModDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnModDest.Click
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet
		Dim sqlStringPredefinito As String = ""
		
        Try
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text

			If CHKPREDEFINITO.Checked Then
                sqlString = "UPDATE utentiindirizzi SET Predefinito=0 WHERE UtenteId=?UtenteId"
                cmd.CommandText = sqlString
                cmd.Parameters.AddWithValue("?UtenteId", Session("UTENTIID"))
                cmd.ExecuteNonQuery()
				
				sqlStringPredefinito = "    , PREDEFINITO= 1 " 
			Else
				if LstDestinazione.items.count = 0 Then
					sqlStringPredefinito = "    , PREDEFINITO= 1 "
				else
					sqlStringPredefinito = "    , PREDEFINITO= 0 " 
				end if
			End If
			
            sqlString = " UPDATE utentiindirizzi SET "
            sqlString &= "      RAGIONESOCIALEA= ?RAGIONESOCIALEA, "
            sqlString &= "      NOMEA= ?NOMEA, "
            sqlString &= "      INDIRIZZOA= ?INDIRIZZOA, "
            sqlString &= "      CAPA= ?CAPA, "
            sqlString &= "      CITTAA= ?CITTAA, "
            sqlString &= "      PROVINCIAA= ?PROVINCIAA, "
            sqlString &= "      NOTE= ?NOTE, "
            sqlString &= "      ZONA= ?ZONA, "
            sqlString &= "      TELEFONOA= ?TELEFONOA "
            sqlString &= sqlStringPredefinito
            sqlString &= "  WHERE Id=?destinazione"

            cmd.CommandText = sqlString
            cmd.Parameters.AddWithValue("?RAGIONESOCIALEA", Me.tbRagioneSocialeADest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?NOMEA", Me.tbNomeADest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?INDIRIZZOA", Me.tbIndirizzo2Dest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?CAPA", Me.tbCap2Dest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?CITTAA", getDdlCittaValue(Me.ddlCitta2Dest).Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?PROVINCIAA", Me.tbProvincia2Dest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?NOTE", Me.tbNoteDest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?ZONA", Me.tbZonaDest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?TELEFONOA", Me.tbTelefono2Dest.Text.Replace("'", "''").ToUpper)
            cmd.Parameters.AddWithValue("?destinazione", LstDestinazione.SelectedValue)
            cmd.ExecuteNonQuery()

            If CHKPREDEFINITO.Checked = false Then
                sqlString = "UPDATE utentiindirizzi SET Predefinito=1 WHERE UtenteId=?utenteId ORDER BY Id DESC LIMIT 1"
                cmd.CommandText = sqlString
                cmd.Parameters.AddWithValue("?utenteId", Session("UTENTIID"))
                cmd.ExecuteNonQuery()
			End If
			
            cmd.Dispose()

            BindLstDestinazione()

        Catch ex As Exception

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try
    End Sub
	
	Protected Sub enable_mod_panel(ByVal panel As Panel, Optional ByVal insOrMod As String = "")
		CaricaDati()
		enable_IndirizzoP(False)
		enable_Accesso(False)
		enable_FatturaElettronica(False)
		enable_mod_destinazione(False, "")
		Select Case panel
			Case Panel.FatturaElettronica
				BindLstDestinazione()
				enable_FatturaElettronica(True)
			Case Panel.Accesso
				BindLstDestinazione()
				enable_Accesso(True)
            Case Panel.Fatturazione
				BindLstDestinazione()
				enable_IndirizzoP(True)
			Case Panel.Spedizione
				enable_mod_destinazione(True, insOrMod)
			Case Else
				enable_IndirizzoP(False)
				BindLstDestinazione()
		End Select
	End Sub
End Class