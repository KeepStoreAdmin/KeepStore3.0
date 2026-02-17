Imports MySql.Data.MySqlClient
Imports System.Configuration
Imports System.Text.RegularExpressions

Partial Class track_your_order
    Inherits System.Web.UI.Page

            Protected Sub btnTrack_Click(sender As Object, e As EventArgs)
                pnlMsg.Visible = False
                pnlResult.Visible = False

                Dim rawN As String = If(txtOrderNumber.Text, "").Trim()
                Dim email As String = If(txtEmail.Text, "").Trim()

                If rawN = "" OrElse email = "" Then
                    ShowMsg("Inserisci sia il numero ordine che l'email.")
                    Return
                End If

                ' Normalizza: rimuovi eventuale #
                rawN = rawN.TrimStart("#"c)

                Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

                Dim sql As String = "
    SELECT vdocumenti.id,
           vdocumenti.NDocumento,
           vdocumenti.DataDocumento,
           vdocumenti.TotaleDocumento,
           vdocumenti.StatiDescrizione1,
           vdocumenti.Tracking,
           vettori.Link_Tracking,
           pagamentitipo.Descrizione AS PagamentiTipoDescrizione
    FROM vdocumenti
    LEFT JOIN utenti ON vdocumenti.UtentiId = utenti.Id
    LEFT JOIN (SELECT id, Link_Tracking FROM vettori) AS vettori ON vdocumenti.VettoriId = vettori.id
    LEFT JOIN pagamentitipo ON vdocumenti.PagamentiTipoId = pagamentitipo.id
    WHERE vdocumenti.TipoDocumentiId = 4
      AND vdocumenti.NDocumento = @n
      AND LOWER(utenti.Email) = LOWER(@email)
    ORDER BY vdocumenti.ID DESC
    LIMIT 1;"

                Try
                    Using c As New MySqlConnection(cs)
                        Using cmd As New MySqlCommand(sql, c)
                            cmd.Parameters.Add("@n", MySqlDbType.VarChar).Value = rawN
                            cmd.Parameters.Add("@email", MySqlDbType.VarChar).Value = email
                            c.Open()

                            Using r As MySqlDataReader = cmd.ExecuteReader()
                                If Not r.Read() Then
                                    ShowMsg("Nessun ordine trovato con questi dati. Verifica numero ordine ed email.")
                                    Return
                                End If

                                Dim id As Integer = Convert.ToInt32(r("id"))
                                Dim nDoc As String = Convert.ToString(r("NDocumento"))
                                Dim dt As String = ""
                                Try
                                    dt = Convert.ToDateTime(r("DataDocumento")).ToString("dd/MM/yyyy")
                                Catch
                                    dt = Convert.ToString(r("DataDocumento"))
                                End Try

                                Dim status As String = Convert.ToString(r("StatiDescrizione1"))
                                Dim total As String = ""
                                Try
                                    total = String.Format(System.Globalization.CultureInfo.GetCultureInfo("it-IT"), "{0:C}", Convert.ToDecimal(r("TotaleDocumento")))
                                Catch
                                    total = Convert.ToString(r("TotaleDocumento"))
                                End Try

                                Dim pay As String = Convert.ToString(r("PagamentiTipoDescrizione"))

                                litOrderId.Text = Server.HtmlEncode("#" & nDoc)
                                litDate.Text = Server.HtmlEncode(dt)
                                litStatus.Text = Server.HtmlEncode(status)
                                litTotal.Text = Server.HtmlEncode(total)
                                litPayment.Text = Server.HtmlEncode(pay)

                                hlDetail.NavigateUrl = "documentidettaglio.aspx?id=" & id.ToString()

                                Dim trackingCode As String = If(r("Tracking") Is DBNull.Value, "", Convert.ToString(r("Tracking")).Trim())
                                Dim trackingTpl As String = If(r("Link_Tracking") Is DBNull.Value, "", Convert.ToString(r("Link_Tracking")).Trim())

                                Dim trackingUrl As String = BuildTrackingUrl(trackingTpl, trackingCode)
                                hlTracking.Visible = Not String.IsNullOrEmpty(trackingUrl)
                                hlTracking.NavigateUrl = trackingUrl

                                pnlResult.Visible = True
                            End Using
                        End Using
                    End Using
                Catch ex As Exception
                    ShowMsg("Errore durante la ricerca dell'ordine. Riprova più tardi.")
                End Try
            End Sub

            Private Sub ShowMsg(msg As String)
                litMsg.Text = Server.HtmlEncode(msg)
                pnlMsg.Visible = True
            End Sub

            Private Function BuildTrackingUrl(templateUrl As String, trackingCode As String) As String
                If String.IsNullOrEmpty(trackingCode) Then Return ""

                ' Se template vuoto ma tracking è già un URL
                If String.IsNullOrEmpty(templateUrl) Then
                    If trackingCode.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse trackingCode.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
                        Return trackingCode
                    End If
                    Return ""
                End If

                Dim url As String = templateUrl

                ' Placeholder comuni
                url = url.Replace("{tracking}", trackingCode).Replace("{TRACKING}", trackingCode)
                url = url.Replace("{0}", trackingCode)
                url = url.Replace("%s", trackingCode)

                ' Se non conteneva placeholder, prova ad appendere come querystring
                If url = templateUrl Then
                    If url.Contains("?") Then
                        url &= "&tracking=" & Server.UrlEncode(trackingCode)
                    Else
                        url &= "?tracking=" & Server.UrlEncode(trackingCode)
                    End If
                End If

                Return url
            End Function
End Class
