Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Net
Imports System.Net.Mail
Imports System.Text
Imports System.Web
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports MySql.Data.MySqlClient

Partial Class Contattaci
    Inherits System.Web.UI.Page

    Private Function S(ByVal key As String) As String
        Dim o As Object = Session(key)
        If o Is Nothing Then Return ""
        Return Convert.ToString(o)
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Not IsPostBack Then
            Me.Title = "Contattaci"
            Try
                Dim azi As String = S("AziendaNome")
                If azi <> "" Then Me.Title = "Contattaci - " & azi
            Catch
            End Try

            LoadCompanyInfo()
            ApplySeoBasics()
        End If
    End Sub

    Private Sub ApplySeoBasics()
        Try
            ' Canonical coerente (no stravolgimenti: usiamo URL assoluto)
            Dim host As String = Request.Url.GetLeftPart(UriPartial.Authority)
            Dim canonical As String = host.TrimEnd("/"c) & "/Contattaci.aspx"
            SeoBuilder.SetCanonical(Me, canonical)

            ' Description semplice e stabile
            Dim desc As String = "Contatta " & S("AziendaNome") & " per informazioni, preventivi e assistenza."
            SeoBuilder.AddOrReplaceNameMeta(Me, "description", desc)
        Catch
            ' fail-open
        End Try
    End Sub

    Private Sub LoadCompanyInfo()
        Dim ragione As String = ""
        Dim indirizzo As String = ""
        Dim cap As String = ""
        Dim citta As String = ""
        Dim prov As String = ""
        Dim telefono As String = ""
        Dim email As String = ""

        ' fallback da session (almeno email e nome di solito ci sono)
        ragione = S("AziendaNome")
        email = S("AziendaEmail")

        Try
            Dim idAzienda As Integer = -1
            Integer.TryParse(S("AziendaID"), idAzienda)

            If idAzienda > 0 Then
                Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                Using cn As New MySqlConnection(cs)
                    cn.Open()
                    Using cmd As New MySqlCommand("SELECT RagioneSociale, Indirizzo, Cap, Citta, provincia, Telefono, Email FROM aziende WHERE Id=@id LIMIT 1", cn)
                        cmd.Parameters.AddWithValue("@id", idAzienda)
                        Using dr As MySqlDataReader = cmd.ExecuteReader()
                            If dr.Read() Then
                                ragione = Convert.ToString(dr("RagioneSociale"))
                                indirizzo = Convert.ToString(dr("Indirizzo"))
                                cap = Convert.ToString(dr("Cap"))
                                citta = Convert.ToString(dr("Citta"))
                                prov = Convert.ToString(dr("provincia"))
                                telefono = Convert.ToString(dr("Telefono"))
                                email = Convert.ToString(dr("Email"))
                            End If
                        End Using
                    End Using
                End Using
            End If
        Catch ex As Exception
            KeepStoreLog.Error("contattaci", "Errore caricamento dati azienda", ex, HttpContext.Current)
        End Try

        ' Render UI
        Dim addressText As String = HttpUtility.HtmlEncode(indirizzo)
        If cap <> "" OrElse citta <> "" OrElse prov <> "" Then
            Dim tail As String = (cap & " " & citta).Trim()
            If prov <> "" Then tail &= " (" & prov & ")"
            If addressText <> "" Then
                addressText &= "<br />" & HttpUtility.HtmlEncode(tail)
            Else
                addressText = HttpUtility.HtmlEncode(tail)
            End If
        Else
            addressText = HttpUtility.HtmlEncode(addressText)
        End If

        ' If indirizzo vuoto, mostriamo almeno ragione sociale
        If String.IsNullOrWhiteSpace(addressText) Then
            addressText = HttpUtility.HtmlEncode(ragione)
        End If

        litAddress.Text = addressText

        If telefono = "" Then telefono = "-"
        litPhone.Text = HttpUtility.HtmlEncode(telefono)

        If email = "" Then email = "-"
        litEmail.Text = HttpUtility.HtmlEncode(email)

        ' Links (map / tel / mail)
        Try
            Dim addrForMap As String = (indirizzo & " " & cap & " " & citta & " " & prov).Trim()
            If addrForMap = "" Then addrForMap = ragione

            Dim mapQ As String = HttpUtility.UrlEncode(addrForMap)
            Dim mapUrl As String = "https://www.google.com/maps?q=" & mapQ
            Dim mapEmbed As String = "https://www.google.com/maps?q=" & mapQ & "&output=embed"

            lnkMap.HRef = mapUrl
            iframeMap.Attributes("src") = mapEmbed

            If telefono <> "-" AndAlso telefono.Trim() <> "" Then
                Dim telClean As String = telefono.Trim()
                lnkPhone.HRef = "tel:" & telClean
            Else
                lnkPhone.HRef = mapUrl
            End If

            If email <> "-" AndAlso email.Trim() <> "" Then
                lnkEmail.HRef = "mailto:" & email.Trim()
            Else
                lnkEmail.HRef = mapUrl
            End If
        Catch
            ' fail-open
        End Try
    End Sub

    Protected Sub btnInvia_Click(ByVal sender As Object, ByVal e As EventArgs)
        pnlAlert.Visible = False
        lblAlert.Text = ""

        If Not Page.IsValid Then
            ShowAlert("Verifica i campi evidenziati.", isError:=True)
            Return
        End If

        Dim nome As String = txtNome.Text.Trim()
        Dim fromEmailUser As String = txtEmail.Text.Trim()
        Dim oggetto As String = txtOggetto.Text.Trim()
        Dim messaggio As String = txtMessaggio.Text.Trim()

        If nome = "" OrElse fromEmailUser = "" OrElse oggetto = "" OrElse messaggio = "" Then
            ShowAlert("Compila tutti i campi obbligatori.", isError:=True)
            Return
        End If

        Dim aziendaNome As String = S("AziendaNome")
        Dim aziendaEmail As String = S("AziendaEmail")

        If aziendaEmail = "" Then
            ShowAlert("In questo momento non è possibile inviare il messaggio. Puoi contattarci via email o telefono indicati a destra.", isError:=True)
            Return
        End If

        Try
            Dim oMsg As New MailMessage()

            ' From: azienda (per evitare problemi SPF/DMARC); ReplyTo: utente
            oMsg.From = New MailAddress(aziendaEmail, If(aziendaNome, "KeepStore"))
            oMsg.To.Add(New MailAddress(aziendaEmail, If(aziendaNome, "KeepStore")))
            oMsg.ReplyToList.Add(New MailAddress(fromEmailUser, nome))

            oMsg.Subject = "[Contatto sito] " & oggetto
            oMsg.IsBodyHtml = True

            Dim sb As New StringBuilder()
            sb.Append("<font face='arial' size='2' color='black'>")
            sb.Append("<b>Richiesta da:</b> ").Append(HttpUtility.HtmlEncode(nome)).Append("<br/>")
            sb.Append("<b>Email:</b> ").Append(HttpUtility.HtmlEncode(fromEmailUser)).Append("<br/>")
            sb.Append("<b>Oggetto:</b> ").Append(HttpUtility.HtmlEncode(oggetto)).Append("<br/><br/>")
            sb.Append("<b>Messaggio:</b><br/>")
            sb.Append(HttpUtility.HtmlEncode(messaggio).Replace(vbCrLf, "<br/>"))
            sb.Append("</font>")
            oMsg.Body = sb.ToString()

            Dim smtpHost As String = S("smtp")
            If smtpHost = "" Then Throw New Exception("SMTP host non configurato (Session(smtp) vuota).")

            Dim oSmtp As New SmtpClient(smtpHost)
            oSmtp.DeliveryMethod = SmtpDeliveryMethod.Network

            Dim userSmtp As String = S("User_smtp")
            Dim passSmtp As String = S("Password_smtp")

            If userSmtp <> "" Then
                Dim oCredential As New NetworkCredential(userSmtp, passSmtp)
                oSmtp.UseDefaultCredentials = False
                oSmtp.Credentials = oCredential
            End If

            oSmtp.Send(oMsg)

            txtOggetto.Text = ""
            txtMessaggio.Text = ""
            ShowAlert("Messaggio inviato correttamente. Ti risponderemo il prima possibile.", isError:=False)

        Catch ex As Exception
            KeepStoreLog.Error("contattaci", "Errore invio mail contatto", ex, HttpContext.Current)
            ShowAlert("Errore durante l'invio del messaggio. Riprova più tardi o contattaci via email/telefono.", isError:=True)
        End Try
    End Sub

    Private Sub ShowAlert(ByVal msg As String, ByVal isError As Boolean)
        pnlAlert.Visible = True
        If isError Then
            pnlAlert.CssClass = "alert alert-danger"
        Else
            pnlAlert.CssClass = "alert alert-success"
        End If
        lblAlert.Text = HttpUtility.HtmlEncode(msg)
    End Sub

End Class
