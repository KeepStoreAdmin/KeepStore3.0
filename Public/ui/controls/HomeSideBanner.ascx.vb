Imports MySql.Data.MySqlClient
Imports System.Configuration
Imports System.Web.UI.WebControls

Partial Class UI_HomeSideBanner
    Inherits System.Web.UI.UserControl

    Private ReadOnly _impressionDedup As New System.Collections.Generic.HashSet(Of Integer)()

    ' Ordinamento banner (1 = primo, 2 = secondo). Default: 1
    Public Property BannerOrder As Integer
        Get
            Dim o As Object = ViewState("BannerOrder")
            If o Is Nothing Then Return 1

            Dim n As Integer = 1
            If Integer.TryParse(Convert.ToString(o), n) Then Return n
            Return 1
        End Get
        Set(ByVal value As Integer)
            ViewState("BannerOrder") = value
        End Set
    End Property

    ' Classi CSS extra per il wrapper (es: "mb-20")
    Public Property ExtraCssClass As String
        Get
            Dim o As Object = ViewState("ExtraCssClass")
            If o Is Nothing Then Return ""
            Return Convert.ToString(o)
        End Get
        Set(ByVal value As String)
            ViewState("ExtraCssClass") = value
        End Set
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ConfigureDataSource()
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        ' Nascondi il blocco se non c'è alcun banner attivo (evita box vuoti nel layout)
        Try
            If RepeaterBanner IsNot Nothing AndAlso RepeaterBanner.Items.Count = 0 Then
                Me.Visible = False
            End If
        Catch
            ' non bloccare la pagina per un problema di binding
        End Try
    End Sub

    Private Sub ConfigureDataSource()
        If SdsBanner Is Nothing Then Exit Sub

        Dim dataOdierna As String = Date.Today.ToString("yyyy-MM-dd")
        Dim aziendaId As Object = Me.Session("AziendaID")
        If aziendaId Is Nothing Then aziendaId = 0

        ' Query allineata alla logica esistente in Default.aspx.vb, ma resa riusabile via BannerOrder
        SdsBanner.SelectCommand =
            "SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato " &
            "FROM pubblicitav2 WHERE (id_posizione_banner=4) AND (ordinamento=@Ordinamento) " &
            "AND ((data_inizio_pubblicazione<=@DataOdierna) AND (data_fine_pubblicazione>=@DataOdierna)) " &
            "AND ((numero_click_attuale<=limite_click) OR (limite_click=-1)) " &
            "AND ((numero_impressioni_attuale<=limite_impressioni) OR (limite_impressioni=-1)) " &
            "AND (abilitato=1) AND (id_Azienda=@AziendaID) ORDER BY id ASC LIMIT 1"

        SdsBanner.SelectParameters.Clear()
        SdsBanner.SelectParameters.Add("@AziendaID", aziendaId)
        SdsBanner.SelectParameters.Add("@DataOdierna", dataOdierna)
        SdsBanner.SelectParameters.Add("@Ordinamento", BannerOrder)
    End Sub

    Protected Sub RepeaterBanner_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e Is Nothing OrElse e.Item Is Nothing Then Exit Sub
        If e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem Then Exit Sub

        Dim idPub As Integer = 0
        Dim objId As Object = DataBinder.Eval(e.Item.DataItem, "id")
        If objId IsNot Nothing Then Integer.TryParse(objId.ToString(), idPub)

        If idPub > 0 Then IncrementPubblicitaImpression(idPub)
    End Sub

    Private Sub IncrementPubblicitaImpression(ByVal idPubblicita As Integer)
        Try
            If idPubblicita <= 0 Then Exit Sub
            If _impressionDedup.Contains(idPubblicita) Then Exit Sub
            _impressionDedup.Add(idPubblicita)

            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Using conn As New MySqlConnection(cs)
                conn.Open()

                Dim sql As String =
                    "UPDATE pubblicitaV2 SET numero_impressioni_attuale = numero_impressioni_attuale + 1 " &
                    "WHERE (id=@id) AND (abilitato=1) " &
                    "AND ((limite_impressioni IS NULL) OR (limite_impressioni=0) OR (numero_impressioni_attuale < limite_impressioni))"

                Using cmd As New MySqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@id", idPubblicita)
                    cmd.ExecuteNonQuery()
                End Using
            End Using

        Catch
            ' Non bloccare la home per tracking impression
        End Try
    End Sub

    ' ===========================
    ' Helpers sicurezza (locali al controllo)
    ' ===========================
    Function SafeAttr(ByVal obj As Object) As String
        Return System.Web.HttpUtility.HtmlAttributeEncode(Convert.ToString(obj))
    End Function

    Function SafeFileNameOnly(ByVal fileObj As Object) As String
        If fileObj Is Nothing OrElse IsDBNull(fileObj) Then Return ""
        Dim s As String = Convert.ToString(fileObj).Trim()
        If s = "" Then Return ""

        s = s.Replace("\\", "/")
        s = s.Replace("\", "/")

        ' blocco path traversal / path assoluti
        If s.Contains("..") OrElse s.Contains(":") Then Return ""

        ' prendo solo l'ultimo segmento
        If s.Contains("/") Then
            s = s.Substring(s.LastIndexOf("/"c) + 1)
        End If

        Return s
    End Function

    Function SafeBannerImageUrl(ByVal fileObj As Object) As String
        Dim raw As String = Convert.ToString(fileObj)
        If raw Is Nothing Then raw = ""
        raw = raw.Trim().Replace("\\", "/").Replace("\", "/")
        Dim low As String = raw.ToLowerInvariant()

        If low = "" Then
            Return ResolveUrl("~/Public/images/nofoto.gif")
        End If

        ' blocca schemi non sicuri
        If low.StartsWith("javascript:") OrElse low.StartsWith("data:") Then
            Return ResolveUrl("~/Public/images/nofoto.gif")
        End If

        ' URL assoluti (http/https)
        If low.StartsWith("http://") OrElse low.StartsWith("https://") Then
            Return raw
        End If

        ' percorsi già assoluti / virtuali
        If low.StartsWith("~/") Then
            Return ResolveUrl(raw)
        End If
        If low.StartsWith("/") Then
            Return raw
        End If

        ' pulizia: mantieni solo il nome file e ricostruisci nel folder banner
        Dim fileName As String = SafeFileNameOnly(raw)
        If fileName = "" Then
            Return ResolveUrl("~/Public/images/nofoto.gif")
        End If
        Return ResolveUrl("~/Public/Banner/" & fileName)
    End Function

End Class
