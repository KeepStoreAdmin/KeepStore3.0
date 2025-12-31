Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class Login
    Inherits System.Web.UI.Page

    '================================================================
    ' PAGE_LOAD
    ' - Se l'utente è già loggato, lo mando in home
    ' - Provo a precompilare solo lo USERNAME dai cookie
    '   (nessuna password salvata in chiaro nei cookie, per ovvi motivi)
    '================================================================
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not IsPostBack Then

            ' Se è già loggato, non ha senso stare sulla pagina di login
            If Session("LoginId") IsNot Nothing Then
                Response.Redirect("default.aspx", True)
            End If

            ' Prefill da cookie (solo username, se presente)
            Try
                If Session("AziendaNome") IsNot Nothing Then
                    Dim cookieName As String = Session("AziendaNome").ToString()
                    Dim userCookie As HttpCookie = Request.Cookies(cookieName)

                    If userCookie IsNot Nothing AndAlso userCookie("Username") IsNot Nothing Then
                        tbUsername.Text = userCookie("Username")
                    End If
                End If
            Catch
                ' Se qualcosa va storto coi cookie, pazienza.
            End Try

        End If
    End Sub

    '================================================================
    ' CLICK DEL BOTTONE DI LOGIN
    '================================================================
    Protected Sub btnLogin_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnLogin.Click
        ' Rispetto i RequiredFieldValidator
        If Not Page.IsValid Then
            Exit Sub
        End If

        lblLogin.Text = ""

        Dim user As String = tbUsername.Text.Trim()
        Dim pass As String = tbPassword.Text

        If user = "" OrElse pass = "" Then
            lblLogin.Text = "Inserire username e password."
            Exit Sub
        End If

        ' Eseguo il login "vero"
        Dim ok As Boolean = EseguiLogin(user, pass)

        ' Se il login è andato a buon fine, Session("LoginId") è valorizzata
        If ok AndAlso Session("LoginId") IsNot Nothing Then

            ' Chiamo AggiornaDati della master (aggiorna carrello, prezzi, ecc.)
            Try
                Dim masterObj As Object = Me.Master
                If masterObj IsNot Nothing Then
                    masterObj.AggiornaDati()
                End If
            Catch
                ' Se per qualche motivo fallisce, non blocchiamo il login
            End Try

            ' Decido dove reindirizzare
            Dim targetUrl As String = "default.aspx"

            ' 1) PRIORITÀ: se una pagina protetta ha impostato Session("Page"),
            '    porto l'utente lì dopo il login.
            If Session("Page") IsNot Nothing Then
                Dim pageUrl As String = TryCast(Session("Page"), String)
                If Not String.IsNullOrEmpty(pageUrl) Then
                    targetUrl = pageUrl
                End If
                ' pulisco dopo l'uso
                Session("Page") = Nothing

            ' 2) Altrimenti uso la pagina visitata salvata dal master
            ElseIf Session.Item("Pagina_visitata") IsNot Nothing Then
                Try
                    Dim u As Uri = TryCast(Session.Item("Pagina_visitata"), Uri)
                    If u IsNot Nothing Then
                        Dim path As String = u.AbsolutePath.ToLower()

                        ' Evito di tornare su login.aspx
                        If Not path.EndsWith("/login.aspx") Then
                            targetUrl = u.AbsoluteUri
                        End If
                    End If
                Catch
                    targetUrl = "default.aspx"
                End Try
            End If

            Response.Redirect(targetUrl, True)
        End If

        ' Se EseguiLogin restituisce False, lblLogin contiene già il messaggio
    End Sub

    '================================================================
    ' LOGICA DI LOGIN (DB)
    '================================================================
    Private Function EseguiLogin(ByVal user As String, ByVal pass As String) As Boolean

        lblLogin.Text = ""

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text

                ' Query parametrizzata su vlogin (no concatenazioni stringa)
                cmd.CommandText = "SELECT * FROM vlogin WHERE UPPER(Username) = ?username LIMIT 0, 1"
                cmd.Parameters.AddWithValue("?username", user.ToUpper())

                Using dr As MySqlDataReader = cmd.ExecuteReader()

                    If Not dr.Read() Then
                        lblLogin.Text = "Username Errato!"
                        Return False
                    End If

                    ' Controlli di abilitazione
                    If dr.Item("Abilitato") <> 1 Then
                        lblLogin.Text = "Login non attivo!"
                        Return False
                    End If

                    If dr.Item("UtentiAbilitato") <> 1 Then
                        lblLogin.Text = "Utente non attivo!"
                        Return False
                    End If

                    ' Controllo password (case-insensitive, come in origine)
                    Dim dbPass As String = dr.Item("Password").ToString()
                    If dbPass.ToLower() <> pass.ToLower() Then
                        lblLogin.Text = "Password Errata!"
                        Return False
                    End If

                    '=======================
                    ' LOGIN OK → set Session
                    '=======================
                    Try
                        Session("AbilitaListino") = CInt(dr.Item("AbilitaListino"))
                    Catch
                        Session("AbilitaListino") = 0
                    End Try

                    Session("LoginId") = dr.Item("id")
                    Session("LoginEmail") = dr.Item("email")
                    Session("LoginNomeCognome") = dr.Item("cognomenome")

                    If Not IsDBNull(dr.Item("ultimoaccesso")) Then
                        Session("LoginUltimoAccesso") = dr.Item("ultimoaccesso")
                    End If

                    Session("UtentiId") = dr.Item("utentiid")
                    Session("UtentiTipoId") = dr.Item("utentitipoid")

                    'Indica se l'utente può o meno creare l'html per le promo mailing
                    Session("genera_html_mail") = dr.Item("genera_html_mail")

                    'Iva applicata all'utente Utente - Esenzioni
                    If dr.Item("idEsenzioneIva") <> -1 Then
                        Session("Iva_Utente") = dr.Item("ValoreEsenzioneIva")
                        Session("DescrizioneEsenzioneIva") = dr.Item("DescrizioneEsenzioneIva")
                        Session("IdEsenzioneIva") = dr.Item("IdEsenzioneIva")
                        'Iva da applicare al vettore (da settare nella tabella Aziende)
                        Session("Iva_Vettori") = Session("Iva_Utente")
                    Else
                        Session("IdEsenzioneIva") = -1
                        Session("DescrizioneEsenzioneIva") = ""
                        Session("Iva_Utente") = -1
                    End If

                    'Reverse Charge Utente
                    Session("AbilitatoIvaReverseCharge") = dr.Item("AbilitatoIvaReverseCharge")

                    Session("Listino") = dr.Item("listino")
                    Session("IvaTipo") = dr.Item("IvaTipo")
                    Session("DataPassword") = dr.Item("DataPassword")

                End Using
            End Using
        End Using

        ' Salvo il cookie per lo USERNAME (ma NON la password)
        Try
            If Session("AziendaNome") IsNot Nothing Then
                Dim cookieName As String = Session("AziendaNome").ToString()
                Dim userCookie As HttpCookie = Request.Cookies(cookieName)

                If userCookie Is Nothing Then
                    userCookie = New HttpCookie(cookieName)
                End If

                userCookie("Username") = user
                userCookie.HttpOnly = True
                userCookie.Expires = DateTime.Now.AddYears(1)

                Response.Cookies.Set(userCookie)
            End If
        Catch
            ' Se falliscono i cookie non è la fine del mondo
        End Try

        Return True
    End Function

End Class
