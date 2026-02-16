<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" Inherits="System.Web.UI.Page" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">Traccia il tuo ordine</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" runat="server">
    <!-- Breadcrumbs (Onsus) -->
    <div class="tf-sp-1 pb-0">
        <div class="container">
            <div class="tf-breadcrumb-wrap">
                <div class="tf-breadcrumb-list">
                    <a href="Default.aspx" class="text">Home</a>
                    <i class="icon icon-arrow-right"></i>
                    <span class="text">Traccia ordine</span>
                </div>
            </div>
        </div>
    </div>

    <section class="flat-spacing">
        <div class="container">
            <div class="tf-section-title mb_30">
                <h2 class="title">Traccia il tuo ordine</h2>
                <p class="text-main-2 mt-2">Inserisci il numero d’ordine e l’email usata in fase di acquisto.</p>
            </div>

            <div class="row justify-content-center">
                <div class="col-lg-7">
                    <div class="tf-form-track">

                        <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="alert alert-warning mb-3">
                            <asp:Literal ID="litMsg" runat="server" />
                        </asp:Panel>

                        <div class="row g-3">
                            <div class="col-md-6">
                                <label class="body-md-2 mb-2" for="<%= txtOrderNumber.ClientID %>">Numero ordine</label>
                                <asp:TextBox ID="txtOrderNumber" runat="server" CssClass="form-control" placeholder="Es. 12345" />
                            </div>
                            <div class="col-md-6">
                                <label class="body-md-2 mb-2" for="<%= txtEmail.ClientID %>">Email</label>
                                <asp:TextBox ID="txtEmail" runat="server" CssClass="form-control" TextMode="Email" placeholder="nome@dominio.it" />
                            </div>
                        </div>

                        <div class="mt-3">
                            <asp:Button ID="btnTrack" runat="server" Text="Traccia" CssClass="tf-btn btn-fill w-100" OnClick="btnTrack_Click" />
                        </div>

                        <asp:Panel ID="pnlResult" runat="server" Visible="false" CssClass="mt-4">
                            <div class="tf-page-title style-2 mb-3">
                                <div class="heading text-center">Risultato</div>
                            </div>

                            <div class="tf-cart-summery">
                                <div class="tf-cart-summery-total mb-2">
                                    <span class="title">Ordine</span>
                                    <span class="total-price"><asp:Literal ID="litOrderId" runat="server" /></span>
                                </div>

                                <ul class="tf-cart-summery-list">
                                    <li>
                                        <span class="text">Data</span>
                                        <span class="text"><asp:Literal ID="litDate" runat="server" /></span>
                                    </li>
                                    <li>
                                        <span class="text">Stato</span>
                                        <span class="text"><asp:Literal ID="litStatus" runat="server" /></span>
                                    </li>
                                    <li>
                                        <span class="text">Totale</span>
                                        <span class="text fw-semibold"><asp:Literal ID="litTotal" runat="server" /></span>
                                    </li>
                                    <li>
                                        <span class="text">Pagamento</span>
                                        <span class="text"><asp:Literal ID="litPayment" runat="server" /></span>
                                    </li>
                                </ul>

                                <div class="d-grid gap-2 mt-3">
                                    <asp:HyperLink ID="hlDetail" runat="server" CssClass="tf-btn btn-line w-100">Vedi dettaglio</asp:HyperLink>
                                    <asp:HyperLink ID="hlTracking" runat="server" CssClass="tf-btn btn-fill w-100" Target="_blank" Visible="false">Apri tracking</asp:HyperLink>
                                </div>
                            </div>

                            <div class="mt-3 text-main-2">
                                Se hai un account, puoi consultare tutti gli ordini nella tua <a class="text-secondary link" href="myaccount.aspx">Area personale</a>.
                            </div>
                        </asp:Panel>

                    </div>
                </div>
            </div>
        </div>
    </section>

    <script runat="server">
        Imports MySql.Data.MySqlClient
        Imports System.Configuration
        Imports System.Text.RegularExpressions

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
                                total = String.Format(Globalization.CultureInfo.GetCultureInfo("it-IT"), "{0:C}", Convert.ToDecimal(r("TotaleDocumento")))
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
    </script>
</asp:Content>
