Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Configuration
Imports System.Web.UI.HtmlControls
Imports System.Text.RegularExpressions

Partial Class Page
    Inherits System.Web.UI.MasterPage
    Implements ISeoMaster


' ============================================================
' SEO JSON-LD (iniettato dalle pagine contenuto tramite SeoBuilder)
' ============================================================
Private _seoJsonLd As String = String.Empty

    Public Property SeoJsonLd As String Implements ISeoMaster.SeoJsonLd
        Get
            Return If(_seoJsonLd, String.Empty)
        End Get
        Set(value As String)
            _seoJsonLd = If(value, String.Empty)

            ' Aggiorna subito il literal nel <head> (se già disponibile)
            If phSeoJsonLd IsNot Nothing Then
                phSeoJsonLd.Visible = Not String.IsNullOrWhiteSpace(_seoJsonLd)
            End If

            If litSeoJsonLd IsNot Nothing Then
                litSeoJsonLd.Text = _seoJsonLd
            End If
        End Set
    End Property

Private Function HeaderHasMeta(ByVal metaName As String) As Boolean
    If Page Is Nothing OrElse Page.Header Is Nothing Then Return False
    For Each c As Control In Page.Header.Controls
        Dim hm As HtmlMeta = TryCast(c, HtmlMeta)
        If hm IsNot Nothing AndAlso Not String.IsNullOrEmpty(hm.Name) Then
            If String.Equals(hm.Name, metaName, StringComparison.OrdinalIgnoreCase) Then
                Return True
            End If
        End If
    Next
    Return False
End Function

    Dim IvaTipo As Integer
    Dim conn As New MySqlConnection
    Dim conn2 As New MySqlConnection
    Dim cmd As New MySqlCommand
    Public social_buttons As New Dictionary(Of String, String)
    Public social_buttons_rules As New Dictionary(Of String, String)

    Function sostituisci_caratteri_speciali(ByRef stringa As String) As String
        stringa = Server.HtmlDecode(stringa)
        stringa = stringa.Replace("'", "''")
        Return stringa
    End Function

    '==========================================================
    '  SOCIAL BUTTONS (hardening SQL)
    '==========================================================
    Sub Load_social_buttons()
        Dim dr As MySqlDataReader = Nothing

        Dim aziendaId As Integer = 0
        Integer.TryParse(Convert.ToString(Me.Session("AziendaID")), aziendaId)
        If aziendaId <= 0 Then
            Exit Sub
        End If

        Try
            If conn.State <> ConnectionState.Open Then
                conn.Open()
            End If

            cmd.Parameters.Clear()
            cmd.CommandType = CommandType.Text
            cmd.CommandText = "SELECT `key`, `value` " &
                              "FROM social_buttons " &
                              "WHERE company_id = @companyId AND enabled = 1 " &
                              "ORDER BY button_order"
            cmd.Parameters.AddWithValue("@companyId", aziendaId)

            dr = cmd.ExecuteReader()
            social_buttons.Clear()
            While dr.Read()
                social_buttons(dr.Item("key").ToString()) = dr.Item("value").ToString()
            End While
            dr.Close()

            cmd.Parameters.Clear()
            cmd.CommandText = "SELECT enabled, callToAction, buttonColor, position " &
                              "FROM social_buttons_rules " &
                              "WHERE company_id = @companyId"
            cmd.Parameters.AddWithValue("@companyId", aziendaId)

            dr = cmd.ExecuteReader()
            social_buttons_rules.Clear()
            If dr.Read() Then
                social_buttons_rules("enabled") = dr.Item("enabled").ToString()
                social_buttons_rules("callToAction") = dr.Item("callToAction").ToString()
                social_buttons_rules("buttonColor") = dr.Item("buttonColor").ToString()
                social_buttons_rules("position") = dr.Item("position").ToString()
            End If
            dr.Close()

        Catch
            ' Se i social falliscono, non buttiamo giù il sito
        Finally
            If dr IsNot Nothing AndAlso Not dr.IsClosed Then
                dr.Close()
            End If
            If conn.State = ConnectionState.Open Then
                conn.Close()
            End If
        End Try
    End Sub

    Protected Sub rptNavCategorie_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)
        If e.Item.ItemType = ListItemType.Item OrElse e.Item.ItemType = ListItemType.AlternatingItem Then
            Dim c As NavCategoriaItem = TryCast(e.Item.DataItem, NavCategoriaItem)
            If c Is Nothing Then Exit Sub

            Dim rpt As Repeater = TryCast(e.Item.FindControl("rptNavTipologie"), Repeater)
            If rpt IsNot Nothing Then
                rpt.DataSource = c.Tipologie
                rpt.DataBind()
            End If
        End If
    
    End Sub
    '==========================================================
    ' NAVBAR: Settori/Categorie/Tipologie (abilitati)
    '==========================================================
    Private Sub BindNavSettori()
        Try
            If rptNavSettori Is Nothing Then Exit Sub
            Dim data As List(Of NavSettoreItem) = LoadNavSettori()
            rptNavSettori.DataSource = data
            rptNavSettori.DataBind()
        Catch ex As Exception
            'Fail-safe: non bloccare la pagina per un errore menu
        End Try
    End Sub


    '==========================================================
    ' INIT: azienda, catalogo, popup, sfondo, social
    '==========================================================
    Protected Sub Page_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Init
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn2.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn

        LeggiAzienda()
        SettaCatalogo()

        If Me.Session.Item("ListaSettori") Is Nothing Then
            Me.Session.Item("ListaSettori") = Settore.creaListaSettori()
        End If

        Dim aziendaId As Integer = 0
        Integer.TryParse(Convert.ToString(Me.Session("AziendaID")), aziendaId)
        Dim dr As MySqlDataReader

        'MiPiace di Facebook
        Dim facebookLink As String = ""
        If Session("facebookLink") IsNot Nothing Then
            facebookLink = Session("facebookLink").ToString().Trim()
        End If

        If (Request.Cookies("FacebookLike") Is Nothing) AndAlso (facebookLink.Length > 0) Then
            PopUpfacebook.Visible = True
        Else
            PopUpfacebook.Visible = False
        End If

        'Popup 
        Dim DataOdierna As String = Date.Today.Year.ToString & "-" & Date.Today.Month.ToString & "-" & Date.Today.Day.ToString
        If (Me.Session.Item("Popup") = 1) AndAlso aziendaId > 0 Then
            conn = New MySqlConnection()
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            cmd.Connection = conn
            conn.Open()

            cmd.CommandType = CommandType.Text
            cmd.CommandText = "SELECT Azienda, Data_Inizio, Data_Fine, Messaggio, Abilitato " &
                              "FROM popup " &
                              "WHERE (Azienda=@aziendaId) " &
                              "AND ((Data_Inizio<=@dataOdierna) AND (Data_Fine>=@dataOdierna)) " &
                              "AND (Abilitato=1)"

            cmd.Parameters.Clear()
            cmd.Parameters.AddWithValue("@aziendaId", aziendaId)
            cmd.Parameters.AddWithValue("@dataOdierna", DataOdierna)

            Me.SqlData_Popup.SelectCommand = cmd.CommandText

            dr = cmd.ExecuteReader()
            dr.Read()

            If Not dr.HasRows Then
                Me.Session.Item("Popup") = 0
            Else
                Me.Session.Item("Popup") = 1
            End If

            dr.Close()
            conn.Close()
        End If

        'Background
        If aziendaId > 0 Then
            conn.Open()

            cmd.Parameters.Clear()
            cmd.CommandType = CommandType.Text
            cmd.CommandText = "SELECT * FROM sfondi " &
                              "WHERE (aziendaid=@aziendaId) " &
                              "AND ((data_inizio<=@dataOdierna) AND (data_fine>=@dataOdierna)) " &
                              "AND (abilitato=1)"
            cmd.Parameters.AddWithValue("@aziendaId", aziendaId)
            cmd.Parameters.AddWithValue("@dataOdierna", DataOdierna)

            dr = cmd.ExecuteReader()
            dr.Read()

            'Default
            Dim background As String
            If dr.HasRows Then
                background = dr.Item("path").ToString()
            Else
                background = "Default" & Session("AziendaID") & ".png"
            End If

            PageBody.Style.Value = PageBody.Style.Value & "; background-image:url('public/Sfondi/" & background & "')"

            dr.Close()
            conn.Close()
        End If

        ' Carico social con query parametrizzate
        Load_social_buttons()

        cmd.Dispose()
    End Sub

    '==========================================================
    ' LOAD: login automatico, cookie, scadenza password, partners
    '==========================================================
    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not Me.Request.Url.ToString.Contains("accessonegato.aspx") Then
            Session.Item("Pagina_visitata") = Me.Request.Url
        End If

        ' Controlli login sulla master (se esistono)
        Dim tbUser As TextBox = TryCast(Me.FindControl("tbUsername"), TextBox)
        Dim tbPass As TextBox = TryCast(Me.FindControl("tbPassword"), TextBox)

        If tbUser IsNot Nothing AndAlso tbPass IsNot Nothing Then
            ' Dati passati dopo registrazione
            If (Session.Item("Inserimento_User") IsNot Nothing AndAlso Session.Item("Inserimento_User").ToString() <> "") AndAlso
               (Session.Item("Inserimento_Password") IsNot Nothing AndAlso Session.Item("Inserimento_Password").ToString() <> "") Then

                tbUser.Text = Session.Item("Inserimento_User").ToString()
                tbPass.Text = Session.Item("Inserimento_Password").ToString()
                Session.Item("Inserimento_User") = ""
                Session.Item("Inserimento_Password") = ""
            End If

            ' Login automatico se i campi sono compilati
            If tbUser.Text <> "" AndAlso tbUser.Text <> "Username" AndAlso tbPass.Text <> "" Then
                Login(tbUser.Text.Replace("'", ""), tbPass.Text.Replace("'", ""))
            End If

            tbPass.ReadOnly = True

            If Not Me.IsPostBack Then
                If Me.Session("LoginId") Is Nothing Then
                    Dim aziendaNome As Object = Me.Session("AziendaNome")
                    If aziendaNome IsNot Nothing AndAlso Not IsNothing(Me.Request.Cookies(aziendaNome.ToString())) Then
                        tbUser.Text = Me.Request.Cookies(aziendaNome.ToString())("Username")
                        Try
                            tbPass.Text = Me.Request.Cookies("Password")("Password")
                        Catch
                            tbPass.Text = ""
                        End Try
                    End If
                End If
            End If
        End If

        'Scadenza password
        If Not Me.Session("LoginId") Is Nothing AndAlso Not Me.Request.ServerVariables("script_name").Contains("cambiapassword.aspx") Then
            Try
                If System.DateTime.Compare(System.DateTime.Today, CDate(Me.Session("DataPassword")).AddMonths(CInt(Me.Session("ScadenzaPassword")))) = 1 Then
                    Me.Response.Redirect("cambiapassword.aspx")
                End If
            Catch
                ' se DataPassword/ScadenzaPassword non sono coerenti, non butto fuori l'utente
            End Try
        End If

        'aggiorno la query relativa agli ordini effettuati sul sito
        SqlData_TotOrdini.SelectCommand =
            "SELECT COUNT(*) AS Conteggio " &
            "FROM documenti " &
            "WHERE (TipoDocumentiId = 4) " &
            "AND (DataDocumento <= { d '" & Date.Now.Year & "-12-31' }) " &
            "AND (DataDocumento >= { d '" & Date.Now.Year & "-01-01' })"

        'Setto i Partners dell'Azienda
        Dim aziendaIdPartners As Integer = 0
        Integer.TryParse(Convert.ToString(Session("AziendaID")), aziendaIdPartners)
        If aziendaIdPartners > 0 Then
            Sql_Partners.SelectCommand =
                "SELECT partners.*, Ordinamento AS Expr1 " &
                "FROM partners " &
                "WHERE (AziendaId=" & aziendaIdPartners & ") " &
                "ORDER BY Expr1"
        End If
    
        'Navbar settori (abilitati)
        BindNavSettori()
End Sub

    '==========================================================
    ' BANNER / PUBBLICITÀ LEGACY (DISABILITATI)
    '==========================================================
#Region "Pubblicità legacy (disabilitata)"
#If False Then
    ' TUTTO IL CODICE DEI BANNER QUI RESTA COM'ERA (NON VIENE COMPILATO)
#End If
#End Region

    '==========================================================
    ' PRE-RENDER: mini-login, badge ordini, carrello, meta
    '==========================================================
    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        '---------------------------
        ' LINK LISTINO PERSONALIZZATO
        '---------------------------
        Try
            If Not IsNothing(Session("AbilitaListino")) AndAlso
               IsNumeric(Session("AbilitaListino")) AndAlso
               CInt(Session("AbilitaListino")) > 0 Then

                Me.Label4.Visible = True
                Me.HyperLink14.Visible = True
            Else
                Me.Label4.Visible = False
                Me.HyperLink14.Visible = False
            End If
        Catch
            Me.Label4.Visible = False
            Me.HyperLink14.Visible = False
        End Try

        '---------------------------
        ' MINI LOGIN HEADER
        '---------------------------
        If Not Me.Session("LoginId") Is Nothing Then
            ' Utente loggato → mostra view 1 (Ciao, Nome + Esci)
            Me.mvLogin.ActiveViewIndex = 1

            Dim lblUser As Label = TryCast(Me.mvLogin.FindControl("lblUtente"), Label)
            If lblUser IsNot Nothing AndAlso Session("LoginNomeCognome") IsNot Nothing Then
                lblUser.Text = Session("LoginNomeCognome").ToString()
            End If

            ' *** CORRETTO QUI: niente "Is Not Nothing" su Session("LoginUltimoAccesso") ***
            Dim lblAccesso As Label = TryCast(Me.mvLogin.FindControl("lblAccesso"), Label)
            If lblAccesso IsNot Nothing Then
                Dim lastAccess As String = Convert.ToString(Session("LoginUltimoAccesso"))
                If String.IsNullOrEmpty(lastAccess) Then
                    lblAccesso.Text = "Oggi"
                Else
                    lblAccesso.Text = lastAccess
                End If
            End If

            ' Ordini da saldare (badge)
            Dim toPayString As String = get_documents_to_pay()
            If toPayString <> "0" Then
                pay_your_orders.Visible = True
                to_pay.InnerHtml = toPayString
            Else
                pay_your_orders.Visible = False
            End If
        Else
            ' Utente NON loggato → mostra view 0 (Accedi / Registrati)
            Me.mvLogin.ActiveViewIndex = 0
            pay_your_orders.Visible = False
        End If

        'IVA tipo (campo di classe, usato solo legacy)
        Try
            IvaTipo = CInt(Me.Session("IvaTipo"))
        Catch
            IvaTipo = 0
        End Try

        'Carrello (icone in header) → usa totale aggiornato direttamente da DB
        LeggiCarrello()

        'Meta tag SEO
        Meta()
    
        ' SEO JSON-LD (se valorizzato dalla pagina contenuto)
        If litSeoJsonLd IsNot Nothing Then
            litSeoJsonLd.Text = SeoJsonLd
        End If

End Sub

    '==========================================================
    ' SUPPORTO IVA DI DEFAULT
    '==========================================================
    Function preleva_idiva_default() As Integer
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim risultato As Integer = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn

        conn.Open()

        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT * FROM ivadefault WHERE NOW() BETWEEN Dal AND Al"

        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            risultato = CInt(dr.Item("IdIva"))
        Else
            risultato = -1
        End If

        dr.Close()
        conn.Close()

        Return risultato
    End Function

    Function preleva_valoreiva_default() As Integer
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim risultato As Integer = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn

        conn.Open()

        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT * FROM ivadefault INNER JOIN iva ON iva.`id`=ivadefault.`IvaId` WHERE NOW() BETWEEN Dal AND Al"

        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows Then
            risultato = CInt(dr.Item("Valore"))
        Else
            risultato = -1
        End If

        dr.Close()
        conn.Close()

        Return risultato
    End Function

    '==========================================================
    ' SETUP CATALOGO
    '==========================================================
    Public Sub SettaCatalogo()
        SettoreDefault()

        'Settore
        If IsNumeric(Me.Request.QueryString("st")) Then
            Me.Session("st") = Me.Request.QueryString("st")
            Me.Session("ct") = 30000
            Me.Session("tp") = 0
            Me.Session("gr") = 0
            Me.Session("sg") = 0
            Me.Session("mr") = 0
            Me.Session("pid") = 0
            Me.Session("q") = Nothing
        End If

        'Categoria
        If IsNumeric(Me.Request.QueryString("ct")) Then
            Me.Session("ct") = Me.Request.QueryString("ct")
            Me.Session("tp") = 0
            Me.Session("gr") = 0
            Me.Session("sg") = 0
            Me.Session("pid") = 0
            Me.Session("q") = Nothing
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Tipologia
        If IsNumeric(Me.Request.QueryString("tp")) Then
            Me.Session("tp") = Me.Request.QueryString("tp")
            Me.Session("pid") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Gruppo
        If IsNumeric(Me.Request.QueryString("gr")) Then
            Me.Session("gr") = Me.Request.QueryString("gr")
            Me.Session("pid") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Sottogruppo
        If IsNumeric(Me.Request.QueryString("sg")) Then
            Me.Session("sg") = Me.Request.QueryString("sg")
            Me.Session("pid") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Marca
        If IsNumeric(Me.Request.QueryString("mr")) Then
            Me.Session("mr") = Me.Request.QueryString("mr")
            Me.Session("pid") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Promo
        If IsNumeric(Me.Request.QueryString("pid")) Then
            Me.Session("pid") = Me.Request.QueryString("pid")
            Me.Session("mr") = 0
            Me.Session("ct") = 30000
            Me.Session("tp") = 0
            Me.Session("gr") = 0
            Me.Session("sg") = 0
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If

        'Ricerca
        Me.Session("q") = Nothing
        If Me.Request.QueryString("q") <> "" Then
            Me.Session("q") = Me.Request.QueryString("q").Trim

            If Not IsNothing(Me.Request.UrlReferrer) Then
                If (Me.Request.UrlReferrer.AbsolutePath.ToString().IndexOf("search_complete") < 0) Then
                    Me.Session("ct") = 30000
                End If
            End If
            If Not Me.Page.IsPostBack Then
                Session("Articoli_PageIndex") = Nothing
            End If
        End If
    End Sub

    '==========================================================
    ' LETTURA AZIENDA + TEMPLATE (hardening host query)
    '==========================================================
    Public Sub LeggiAzienda()
        Dim localConn As New MySqlConnection
        Dim localCmd As New MySqlCommand

        If IsNothing(Me.Session("AziendaID")) Then
            Dim sDominio As String = Me.Request.Url.Host

            ' Sanitize host: lunghezza max e niente spazi folli
            If String.IsNullOrWhiteSpace(sDominio) Then
                sDominio = ""
            Else
                sDominio = sDominio.Trim()
                If sDominio.Length > 255 Then
                    sDominio = sDominio.Substring(0, 255)
                End If
            End If

            localConn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            localCmd.Connection = localConn

            localConn.Open()

            localCmd.CommandType = CommandType.Text
            localCmd.CommandText = "SELECT * " &
                                   "FROM aziende " &
                                   "LEFT JOIN pagine ON aziende.Id = Aziendeid " &
                                   "WHERE (url1 LIKE @dominio OR url2 LIKE @dominio) " &
                                   "LIMIT 0, 1"
            localCmd.Parameters.Clear()
            localCmd.Parameters.AddWithValue("@dominio", "%" & sDominio & "%")

            Dim dr As MySqlDataReader = localCmd.ExecuteReader()
            dr.Read()

            If Not dr.HasRows Then
                Response.Write("Nessun sito web configurato per questa applicazione.")
                Response.End()
            Else
                Me.Session("AziendaID") = dr.Item("Id")
                Me.Session("AziendaEmail") = dr.Item("Email")
                Me.Session("AziendaNome") = dr.Item("Nome")
                Me.Session("AziendaDescrizione") = dr.Item("Descrizione")
                Me.Session("AziendaLogo") = "public/images/" & dr.Item("logoWeb")
                Me.Session("AziendaUrl") = dr.Item("url1")
                Me.Session("Credits") = " <b>© " & DateTime.Now.Year.ToString() & " " & dr.Item("RagioneSociale") & "</b> - " & dr.Item("Indirizzo") & " - " & dr.Item("Cap") & " " & dr.Item("Citta") & " (" & dr.Item("provincia") & ") - P.I. " & dr.Item("Piva") & " - Tel. " & dr.Item("Telefono") & " - Fax " & dr.Item("Fax")
                Me.Session("Credits2") = "<br>" & dr.Item("RagioneSociale") & "<br>" & dr.Item("Indirizzo") & "-" & dr.Item("Cap") & "<br>" & dr.Item("Citta") & " (" & dr.Item("provincia") & ")<br>P.Iva " & dr.Item("Piva") & "<br>Tel " & dr.Item("Telefono") & "<br>Fax " & dr.Item("Fax")
                Me.Session("Listino") = dr.Item("ListinoDefault")
                Me.Session("ListinoUser") = dr.Item("ListinoUser")
                Me.Session("IvaTipo") = dr.Item("IvaTipo")
                Me.Session("CanOrder") = dr.Item("CanOrder")
                Me.Session("MagazzinoDefault") = dr.Item("MagazzinoDefault")
                Me.Session("DispoTipo") = dr.Item("DispoTipo")
                Me.Session("DispoMinima") = dr.Item("DispoMinima")
                Me.Session("RigheArticoli") = dr.Item("RigheArticoli")
                Me.Session("Abilita_Groupon") = dr.Item("Groupon")
                Me.Session("Abilita_Coupon") = dr.Item("Coupon")
                Me.Session("UtentiId") = -1
                Me.Session("ScadenzaPassword") = dr.Item("ScadenzaPassword")
                Me.Session("VetrinaArticoliNovita") = dr.Item("VetrinaArticoliNovita")
                Me.Session("VetrinaArticoliUltimiArriviPuntoVendita") = dr.Item("VetrinaArticoliUltimiArriviPuntoVendita")
                Me.Session("VetrinaArticoliImpatto") = dr.Item("VetrinaArticoliImpatto")
                Me.Session("VetrinaArticoliPiuVenduti") = dr.Item("VetrinaArticoliPiuVenduti")
                Me.Session("VetrinaPromoFissi") = dr.Item("VetrinaPromoFissi")
                Me.Session("VetrinaPromoRandom") = dr.Item("VetrinaPromoRandom")
                Me.Session("VetrinaPromoScadenza") = dr.Item("VetrinaPromoScadenza")
                Me.Session("VetrinaPromoInizio") = dr.Item("VetrinaPromoInizio")
                Me.Session("VetrinaDispoMinima") = dr.Item("VetrinaDispoMinima")
                Me.Session("css") = dr.Item("css")
                Me.Session("smtp") = dr.Item("smtp")
                Me.Session("User_smtp") = dr.Item("User_smtp")
                Me.Session("Password_smtp") = dr.Item("Password_smtp")
                Me.Session("AziendaCopyright") = dr.Item("copyright")
                Me.Session("AziendaDescrizioneServizioCoupon") = dr.Item("descrizione_servizio_coupon")
                Me.Session("AziendaLogoVerificSite1") = dr.Item("logo_verific_site1")
                Me.Session("AziendaLogoVerificSite2") = dr.Item("logo_verific_site2")
                Me.Session("AziendaLogoVerificSite3") = dr.Item("logo_verific_site3")
                Me.Session("AziendaLogoVerificSite4") = dr.Item("logo_verific_site4")
                Me.Session("LinkAziendaLogoVerificSite1") = dr.Item("link_logo_verific_site1")
                Me.Session("LinkAziendaLogoVerificSite2") = dr.Item("link_logo_verific_site2")
                Me.Session("LinkAziendaLogoVerificSite3") = dr.Item("link_logo_verific_site3")
                Me.Session("LinkAziendaLogoVerificSite4") = dr.Item("link_logo_verific_site4")
                Me.Session("AziendaLogoFooter") = "Images/Coupon/loghi/" & dr.Item("logo_footer")
                Me.Session("Script_Visite_Azienda") = dr.Item("statistiche_visite")
                Me.Session("facebookLink") = dr.Item("facebookLink")
                Me.Session("IconaWeb") = dr.Item("Icona_web")
                Me.Session("AbilitaBuoniScontiCarrello") = dr.Item("AbilitaBuoniScontiCarrello")
                Me.Session("TC") = dr.Item("TC")

                'Setto l'id del documento che mi indica il Coupon
                Session("IdDocumentoCoupon") = 18

                'Iva da applicare al vettore
                If Session("Iva_Utente") IsNot Nothing AndAlso CInt(Session("Iva_Utente")) > -1 Then
                    Session("Iva_Vettori") = Session("Iva_Utente")
                Else
                    Session("Iva_Vettori") = IvaVettoreDefault(CInt(Session("AziendaID")))
                End If

                'Setto l'abilitazione dell'utente all'IVA Reverse Charge o meno
                If Session("AbilitatoIvaReverseCharge") IsNot Nothing AndAlso CInt(Session("AbilitatoIvaReverseCharge")) = 1 Then
                    Session("AbilitatoIvaReverseCharge") = 1
                Else
                    Session("AbilitatoIvaReverseCharge") = 0
                End If

                Try
                    Me.Session("AccountPaypal") = dr.Item("AccountPaypal")
                Catch ex As Exception
                    Me.Session("AccountPaypal") = "000000"
                End Try

                Try
                    Me.Session("AccountIwBank") = dr.Item("AccountIwBank")
                Catch ex As Exception
                    Me.Session("AccountIwBank") = "000000"
                End Try
            End If

            dr.Close()
            dr.Dispose()

            localConn.Close()
            localConn.Dispose()

            localCmd.Dispose()
        End If

        ImpostaTemplate()
    End Sub

    Public Sub CreaVistaPromo()
        Dim dr As MySqlDataReader
        Dim Data As Date = System.DateTime.Today
        Dim strSelect As String = "SELECT id "
        Dim strSelect2 As String
        Dim strFrom As String = "FROM articoli WHERE Abilitato=1 AND NoPromo=0 "
        Dim strWhere As String
        Dim MarcheID As String
        Dim SettoriId As String
        Dim CategorieId As String
        Dim TipologieId As String
        Dim GruppiId As String
        Dim SottoGruppiId As String
        Dim ArticoliId As String

        conn.Open()

        cmd.CommandType = CommandType.Text

        cmd.CommandText = "Delete from voffertearticoli"
        cmd.ExecuteNonQuery()

        cmd.CommandText = "SELECT DISTINCT Id, MarcheID, SettoriId, CategorieId, TipologieId, GruppiId, SottoGruppiId, ArticoliId, OfferteId" &
                          ", Descrizione, Immagine, DataInizio, DataFine, DaListino, AListino, QntMinima, Multipli, Prezzo, Sconto " &
                          "FROM voffertedettagli " &
                          "WHERE ('" & Format(Date.Today, "yyyyMMdd") & "' between datainizio and datafine) and Abilitato=1 ORDER BY OfferteId, id"

        dr = cmd.ExecuteReader()

        Dim cmd2 As MySqlCommand = New MySqlCommand()
        Dim conn3 As New MySqlConnection
        conn3.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn3.Open()
        cmd2.Connection = conn3
        cmd2.CommandType = CommandType.Text

        While dr.Read()
            MarcheID = dr.Item("MarcheId").ToString()
            SettoriId = dr.Item("SettoriId").ToString()
            CategorieId = dr.Item("CategorieId").ToString()
            TipologieId = dr.Item("TipologieId").ToString()
            GruppiId = dr.Item("GruppiId").ToString()
            SottoGruppiId = dr.Item("SottoGruppiId").ToString()
            ArticoliId = dr.Item("ArticoliId").ToString()

            strSelect2 = ""
            strWhere = ""

            strSelect2 &= ", " & dr.Item("OfferteId") & " as OfferteID "
            strSelect2 &= ", " & dr.Item("Id") & " as OfferteDettagliId "
            strSelect2 &= ", '" & sostituisci_caratteri_speciali(dr.Item("Descrizione")) & "' as OfferteDescrizione "
            strSelect2 &= ", '" & dr.Item("Immagine") & "' as OfferteImmagine "
            strSelect2 &= ", '" & Format(dr.Item("DataInizio"), "yyyyMMdd") & "' as OfferteDataInizio "
            strSelect2 &= ", '" & Format(dr.Item("DataFine"), "yyyyMMdd") & "' as OfferteDataFine "
            strSelect2 &= ", " & dr.Item("DaListino") & " as OfferteDaListino "
            strSelect2 &= ", " & dr.Item("AListino") & " as OfferteAListino "
            strSelect2 &= ", " & dr.Item("QntMinima") & " as OfferteQntMinima "
            strSelect2 &= ", " & dr.Item("Multipli") & " as OfferteMultipli "
            strSelect2 &= ", " & dr.Item("Prezzo").ToString().Replace(",", ".") & " as OffertePrezzo "
            strSelect2 &= ", " & dr.Item("Sconto").ToString().Replace(",", ".") & " as OfferteSconto "

            If MarcheID <> "" AndAlso MarcheID <> "0" Then
                strWhere &= " AND MarcheID=" & MarcheID
            End If
            If SettoriId <> "" AndAlso SettoriId <> "0" Then
                strWhere &= " AND SettoriId=" & SettoriId
            End If
            If CategorieId <> "" AndAlso CategorieId <> "0" Then
                strWhere &= " AND CategorieId=" & CategorieId
            End If
            If TipologieId <> "" AndAlso TipologieId <> "0" Then
                strWhere &= " AND TipologieId=" & TipologieId
            End If
            If GruppiId <> "" AndAlso GruppiId <> "0" Then
                strWhere &= " AND GruppiId=" & GruppiId
            End If
            If SottoGruppiId <> "" AndAlso SottoGruppiId <> "0" Then
                strWhere &= " AND SottoGruppiId=" & SottoGruppiId
            End If
            If ArticoliId <> "" AndAlso ArticoliId <> "0" Then
                strWhere &= " AND Id=" & ArticoliId
            End If

            cmd2.CommandText = "Insert into voffertearticoli (" & strSelect & strSelect2 & strFrom & strWhere & ")"
            cmd2.ExecuteNonQuery()
        End While

        conn3.Close()
        conn3.Dispose()

        dr.Close()
        dr.Dispose()

        cmd.Dispose()
        cmd2.Dispose()

        conn.Close()
        conn.Dispose()
    End Sub

    Public Sub ImpostaTemplate()
        Me.Page.Title = Me.Session("AziendaNome")
        Me.imgLogo.ImageUrl = Me.Session("AziendaLogo")
        Me.imgLogo.AlternateText = Me.Session("AziendaNome") & " - " & Me.Session("AziendaDescrizione")
        Me.imgLogoMobile.ImageUrl = Me.Session("AziendaLogo")
        Me.imgLogoMobile.AlternateText = Me.Session("AziendaNome") & " - " & Me.Session("AziendaDescrizione")
        Me.lblCredits.Text = Me.Session("Credits")

        Dim objcss As New HtmlLink()
        Dim obj3 As New HtmlLink()
        objcss.Href = "~/public/style/" & Session("css")
        objcss.Attributes.Add("rel", "stylesheet")
        objcss.Attributes.Add("type", "text/css")

        obj3.Attributes.Add("rel", "shortcut icon")
        obj3.Href = Session("IconaWeb")

        Me.Page.Header.Controls.Add(objcss)
        Me.Page.Header.Controls.Add(obj3)
    End Sub

    Public Sub SettoreDefault()
        If IsNothing(Me.Session("st")) Then
            conn.Open()

            cmd.CommandType = CommandType.Text
            cmd.CommandText = "Select id from settori where predefinito = 1"

            Dim dr As MySqlDataReader = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows Then
                Me.Session("st") = dr.Item("Id")
            End If

            dr.Close()
            dr.Dispose()

            conn.Close()
            conn.Dispose()

            cmd.Dispose()
        End If
    End Sub

    '==========================================================
    ' LOGIN + AGGIORNAMENTO DATI
    '==========================================================
    Public Sub Login(ByVal user As String, ByVal pass As String)
        conn.Open()

        cmd.CommandType = CommandType.Text
        cmd.CommandText = "Select * from vlogin where AziendeID=?id and UPPER(Username)=?Username limit 0, 1"
        cmd.Parameters.Clear()
        cmd.Parameters.AddWithValue("?id", Session("AziendaID"))
        cmd.Parameters.AddWithValue("?Username", user.ToUpper())
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        dr.Read()

        ' Controlli di interfaccia login (se esistono nella master)
        Dim lblLogin As Label = TryCast(Me.FindControl("lblLogin"), Label)
        Dim tbUser As TextBox = TryCast(Me.FindControl("tbUsername"), TextBox)
        Dim tbPass As TextBox = TryCast(Me.FindControl("tbPassword"), TextBox)

        If dr.HasRows Then
            If dr.Item("Abilitato") <> 1 Then
                If lblLogin IsNot Nothing Then
                    lblLogin.Text = "Login non attivo!"
                    lblLogin.Focus()
                End If
                Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType(), "prova", "<script type='text/javascript'>document.body.onload=function(){alert('Login non attivo!')}</script>")

            ElseIf dr.Item("UtentiAbilitato") <> 1 Then
                If lblLogin IsNot Nothing Then
                    lblLogin.Text = "Utente non attivo!"
                    lblLogin.Focus()
                End If
                Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType(), "prova", "<script type='text/javascript'>document.body.onload=function(){alert('Utente non attivo!')}</script>")

            ElseIf dr.Item("Password").ToString().ToLower() = pass.ToLower() Then
                'Login OK
                Try
                    Me.Session("AbilitaListino") = CType(dr.Item("AbilitaListino"), Integer)
                Catch
                    Me.Session("AbilitaListino") = 0
                End Try
                Me.Session("LoginId") = dr.Item("id")
                Me.Session("LoginEmail") = dr.Item("email")
                Me.Session("LoginNomeCognome") = dr.Item("cognomenome")

                If (dr.Item("ultimoaccesso") Is Nothing) = False Then
                    Me.Session("LoginUltimoAccesso") = dr.Item("ultimoaccesso")
                End If

                Me.Session("UtentiId") = dr.Item("utentiid")
                Me.Session("UtentiTipoId") = dr.Item("utentitipoid")
                Me.Session("genera_html_mail") = dr.Item("genera_html_mail")

                If dr.Item("idEsenzioneIva") <> -1 Then
                    Me.Session("Iva_Utente") = dr.Item("ValoreEsenzioneIva")
                    Session("DescrizioneEsenzioneIva") = dr.Item("DescrizioneEsenzioneIva")
                    Session("IdEsenzioneIva") = dr.Item("IdEsenzioneIva")
                    Session("Iva_Vettori") = Session("Iva_Utente")
                Else
                    Session("IdEsenzioneIva") = -1
                    Session("DescrizioneEsenzioneIva") = ""
                    Me.Session("Iva_Utente") = -1
                End If

                Session("AbilitatoIvaReverseCharge") = dr.Item("AbilitatoIvaReverseCharge")

                Me.Session("Listino") = dr.Item("listino")
                Me.Session("IvaTipo") = dr.Item("IvaTipo")
                Me.Session("DataPassword") = dr.Item("DataPassword")
                Me.Response.Cookies(Me.Session("AziendaNome"))("Username") = user
                Me.Response.Cookies("Password")("Password") = pass
                Me.Response.Cookies(Me.Session("AziendaNome")).Expires = DateTime.Now.AddYears(1)

            Else
                If lblLogin IsNot Nothing Then
                    lblLogin.Text = "Password Errata!"
                End If
                If tbPass IsNot Nothing Then
                    tbPass.Focus()
                End If
                Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType(), "prova", "<script type='text/javascript'>document.body.onload=function(){alert('Password Errata!')}</script>")
            End If
        Else
            If lblLogin IsNot Nothing Then
                lblLogin.Text = "Username Errato!"
            End If
            If tbUser IsNot Nothing Then
                tbUser.Focus()
            End If
            Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType(), "prova", "<script type='text/javascript'>document.body.onload=function(){alert('Username Errato!')}</script>")
        End If

        dr.Close()
        dr.Dispose()

        conn.Close()
        conn.Dispose()

        cmd.Dispose()

        If Not Me.Session("LoginId") Is Nothing Then
            AggiornaDati()
        End If

        If Not Session.Item("Pagina_visitata") Is Nothing Then
            Response.Redirect(Session.Item("Pagina_visitata").AbsoluteUri)
        End If
    End Sub

    Public Sub AggiornaDati()
        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        ' Se per qualche motivo non c'è LoginID, esco
        If Session("LoginID") Is Nothing Then
            Exit Sub
        End If

        Dim loginId As Integer = CInt(Session("LoginID"))

        '==========================================================
        ' 1) Aggiorno ultimo accesso e sistemo il carrello/sessione
        '==========================================================
        Using conn As New MySqlConnection(connString)
            conn.Open()

            Using comm As New MySqlCommand()
                comm.Connection = conn
                comm.CommandType = CommandType.Text

                ' Aggiorno ultimo accesso su login
                comm.CommandText = "UPDATE login SET ultimoaccesso = NOW(), UltimoIp = ?UltimoIp, NumeroAccessi = NumeroAccessi + 1 WHERE id = ?LoginID"
                comm.Parameters.Clear()
                comm.Parameters.AddWithValue("?UltimoIp", Me.Request.UserHostAddress)
                comm.Parameters.AddWithValue("?LoginID", loginId)
                comm.ExecuteNonQuery()

                ' Sposto il carrello della sessione anonima sull'utente loggato
                comm.CommandText = "UPDATE carrello SET LoginID = ?LoginID, SessionId = '' WHERE SessionId = ?SessionId"
                comm.Parameters.Clear()
                comm.Parameters.AddWithValue("?LoginID", loginId)
                comm.Parameters.AddWithValue("?SessionId", Session.SessionID)
                comm.ExecuteNonQuery()

                ' Pulisco SessionId e imposto NListino = 1 su tutte le righe (logica originale)
                comm.CommandText = "UPDATE carrello SET SessionId = '', NListino = 1"
                comm.Parameters.Clear()
                comm.ExecuteNonQuery()
            End Using
        End Using

        '==========================================================
        ' 2) Aggiorno prezzi base del carrello e accorpo duplicati
        '==========================================================
        Using connControllo As New MySqlConnection(connString)
            connControllo.Open()

            Using cmdControllo As New MySqlCommand()
                cmdControllo.Connection = connControllo
                cmdControllo.CommandType = CommandType.Text
                cmdControllo.CommandText = "SELECT * FROM carrello WHERE (LoginID = ?LoginID)"
                cmdControllo.Parameters.AddWithValue("?LoginID", loginId)

                Dim dsdata As New DataSet()
                Using sqlAdp As New MySqlDataAdapter(cmdControllo)
                    sqlAdp.Fill(dsdata, "carrello")
                End Using

                Dim i As Integer = 1
                Dim rows As DataTable = dsdata.Tables(0)

                For Each ROW As DataRow In rows.Rows
                    Dim ArticoloID As Integer = CInt(ROW("ArticoliId"))
                    Dim RigaId As Integer = CInt(ROW("id"))

                    ' Aggiorno il prezzo dell'articolo con il listino attuale
                    cmdControllo.CommandText = "UPDATE carrello SET Prezzo = (SELECT Prezzo FROM articoli_listini WHERE NListino = ?listino AND ArticoliId = " & ArticoloID & "), PrezzoIvato = (SELECT PrezzoIvato FROM articoli_listini WHERE NListino = ?listino AND ArticoliId = " & ArticoloID & ") WHERE id = " & RigaId
                    cmdControllo.Parameters.Clear()
                    cmdControllo.Parameters.AddWithValue("?listino", Session("Listino"))
                    cmdControllo.ExecuteNonQuery()

                    ' Accorpo eventuali righe duplicate per lo stesso articolo
                    Dim j As Integer
                    For j = i To rows.Rows.Count - 1
                        Dim ROW_temp As DataRow = rows.Rows(j)
                        If ROW_temp("ArticoliId").ToString() = ROW("ArticoliId").ToString() Then
                            Dim qntExtra As Integer = CInt(ROW_temp("QNT"))
                            Dim idExtra As Integer = CInt(ROW_temp("id"))

                            cmdControllo.CommandText = "UPDATE carrello SET QNT = QNT + " & qntExtra & " WHERE id = " & RigaId
                            cmdControllo.Parameters.Clear()
                            cmdControllo.ExecuteNonQuery()

                            cmdControllo.CommandText = "DELETE FROM carrello WHERE id = " & idExtra
                            cmdControllo.Parameters.Clear()
                            cmdControllo.ExecuteNonQuery()

                            Exit For
                        End If
                    Next

                    i += 1
                Next

                dsdata.Dispose()
            End Using
        End Using

        '==========================================================
        '3) Applico eventuali offerte/promozioni (vsuperarticoli)
        '==========================================================
        Dim listino As Integer = 1
        If Not IsNothing(Session("listino")) AndAlso IsNumeric(Session("listino")) Then
            listino = CInt(Session("listino"))
        End If

        Dim sb As New System.Text.StringBuilder()

        Using connCarrello As New MySqlConnection(connString)
            connCarrello.Open()

            Using connSuper As New MySqlConnection(connString)
                connSuper.Open()

                ' Leggo il carrello (vista vcarrello)
                Using comm As New MySqlCommand("SELECT * FROM vcarrello WHERE (LoginId = " & loginId & ") ORDER BY id", connCarrello)
                    Using dr As MySqlDataReader = comm.ExecuteReader()
                        While dr.Read()
                            Dim ID As Integer = CInt(dr("ID"))
                            Dim ArtID As Integer = CInt(dr("ArticoliId"))
                            Dim Qta As Integer = CInt(dr("Qnt"))

                            Dim Prezzo As Double = 0
                            Dim PrezzoIvato As Double = 0
                            Dim OfferteDettagliID As Long = 0

                            ' Per ogni articolo verifico eventuali offerte su vsuperarticoli
                            Dim sqlSuper As String = "SELECT * FROM vsuperarticoli WHERE id = " & ArtID & " AND NListino = " & listino & " ORDER BY PrezzoPromo DESC"

                            Using cmdSuper As New MySqlCommand(sqlSuper, connSuper)
                                Using dr2 As MySqlDataReader = cmdSuper.ExecuteReader()
                                    While dr2.Read()
                                        If Prezzo = 0 Then
                                            Prezzo = CDbl(dr2("prezzo"))
                                        End If
                                        If PrezzoIvato = 0 Then
                                            PrezzoIvato = CDbl(dr2("prezzoivato"))
                                        End If

                                        Dim inOfferta As Integer = 0
                                        If Not IsDBNull(dr2("InOfferta")) Then
                                            inOfferta = CInt(dr2("InOfferta"))
                                        End If

                                        If inOfferta = 1 Then
                                            Dim qMin As Integer = 0
                                            Dim multipli As Integer = 0

                                            If Not IsDBNull(dr2("OfferteQntMinima")) Then
                                                qMin = CInt(dr2("OfferteQntMinima"))
                                            End If
                                            If Not IsDBNull(dr2("OfferteMultipli")) Then
                                                multipli = CInt(dr2("OfferteMultipli"))
                                            End If

                                            If qMin > 0 AndAlso Qta >= qMin Then
                                                OfferteDettagliID = CLng(dr2("OfferteDettagliId"))
                                                Prezzo = CDbl(dr2("prezzopromo"))
                                                PrezzoIvato = CDbl(dr2("prezzopromoivato"))
                                            ElseIf multipli > 0 AndAlso (Qta Mod multipli) = 0 Then
                                                OfferteDettagliID = CLng(dr2("OfferteDettagliId"))
                                                Prezzo = CDbl(dr2("prezzopromo"))
                                                PrezzoIvato = CDbl(dr2("prezzopromoivato"))
                                            End If
                                        End If
                                    End While
                                End Using
                            End Using

                            sb.Append("UPDATE carrello SET ")
                            sb.Append("OfferteDettaglioId = " & OfferteDettagliID)
                            sb.Append(", Prezzo = '" & Prezzo.ToString().Replace(",", ".") & "' ")
                            sb.Append(", PrezzoIvato = '" & PrezzoIvato.ToString().Replace(",", ".") & "' ")
                            sb.Append(" WHERE ID = ")
                            sb.Append(ID)
                            sb.Append(" ; ")
                        End While
                    End Using
                End Using

                ' Eseguo gli UPDATE in blocco
                If sb.Length > 0 Then
                    Using cmdUpdate As New MySqlCommand(sb.ToString(), connCarrello)
                        cmdUpdate.CommandType = CommandType.Text
                        cmdUpdate.ExecuteNonQuery()
                    End Using
                End If
            End Using
        End Using
    End Sub

    '================================================================
    '  DOCUMENTI DA SALDARE (badge "Ordini da saldare")
    '================================================================
    Private Function get_documents_to_pay() As String
        ' Se non è loggato, nessun ordine da saldare
        If Session("LoginId") Is Nothing Then
            Return "0"
        End If

        Dim loginId As Integer
        Try
            loginId = CInt(Session("LoginId"))
        Catch
            Return "0"
        End Try

        Dim toPay As Integer = 0

        Try
            Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Using conn As New MySqlConnection(connString)
                conn.Open()

                Using cmd As New MySqlCommand()
                    cmd.Connection = conn
                    cmd.CommandType = CommandType.Text

                    cmd.CommandText =
                        "SELECT COUNT(*) " &
                        "FROM vdocumenti d " &
                        "INNER JOIN login l ON d.UtentiId = l.UtentiId " &
                        "WHERE l.id = ?LoginId " &
                        "AND d.TipoDocumentiId = 4 " &
                        "AND d.StatiId <> 0 " &
                        "AND d.StatiId <> 3 " &
                        "AND d.Pagato = 0 " &
                        "AND d.PagamentiTipoOnline <> 0"

                    cmd.Parameters.AddWithValue("?LoginId", loginId)

                    Dim result As Object = cmd.ExecuteScalar()
                    If result IsNot Nothing AndAlso Not IsDBNull(result) Then
                        toPay = Convert.ToInt32(result)
                    End If
                End Using
            End Using

        Catch
            ' Non faccio cadere il sito per il badge
            toPay = 0
        End Try

        Return toPay.ToString()
    End Function

    '==========================================================
    ' CARRELLO HEADER (quantità + totale) - HARDENED
    '==========================================================
    Public Sub LeggiCarrello()
        ' Reset di default
        If lblCarrelloCount IsNot Nothing Then
            lblCarrelloCount.Text = "0"
        End If
        If lblCarrelloTotale IsNot Nothing Then
            lblCarrelloTotale.Text = "0,00"
        End If

        Session("Carrello_Quantita") = 0
        Session("Carrello_Totale_Merce") = 0D

        Dim LoginId As Integer = 0
        If Not IsNothing(Me.Session("LoginId")) AndAlso IsNumeric(Me.Session("LoginId")) Then
            LoginId = CInt(Me.Session("LoginId"))
        End If

        Dim SessionID As String = Me.Session.SessionID

        ' Tipo IVA: 1 = imponibile, 2 = ivato. Default 2 se non impostato.
        Dim ivaTipoLocal As Integer = 2
        If Not IsNothing(Me.Session("IvaTipo")) AndAlso IsNumeric(Me.Session("IvaTipo")) Then
            ivaTipoLocal = CInt(Me.Session("IvaTipo"))
        End If

        Dim sql As String = ""
        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Try
            Using localConn As New MySqlConnection(connString)
                localConn.Open()

                Using localCmd As New MySqlCommand()
                    localCmd.Connection = localConn
                    localCmd.CommandType = CommandType.Text

                    If LoginId = 0 Then
                        ' Carrello associato alla sessione anonima
                        If ivaTipoLocal = 1 Then
                            sql = "SELECT Sum(Qnt) AS Quantita, Sum(Qnt * Prezzo) AS TotRiga FROM carrello WHERE SessionID = ?sessionId"
                        Else
                            sql = "SELECT Sum(Qnt) AS Quantita, Sum(Qnt * PrezzoIvato) AS TotRiga FROM carrello WHERE SessionID = ?sessionId"
                        End If
                        localCmd.Parameters.AddWithValue("?sessionId", SessionID)
                    Else
                        ' Carrello associato al LoginId
                        If ivaTipoLocal = 1 Then
                            sql = "SELECT Sum(Qnt) AS Quantita, Sum(Qnt * Prezzo) AS TotRiga FROM carrello WHERE LoginId = ?loginId"
                        Else
                            sql = "SELECT Sum(Qnt) AS Quantita, Sum(Qnt * PrezzoIvato) AS TotRiga FROM carrello WHERE LoginId = ?loginId"
                        End If
                        localCmd.Parameters.AddWithValue("?loginId", LoginId)
                    End If

                    localCmd.CommandText = sql

                    Using dr As MySqlDataReader = localCmd.ExecuteReader()
                        If dr.Read() Then
                            ' Quantità articoli
                            If Not dr.IsDBNull(dr.GetOrdinal("Quantita")) Then
                                Dim qVal As Integer = 0
                                Integer.TryParse(dr("Quantita").ToString(), qVal)

                                Session("Carrello_Quantita") = qVal

                                If lblCarrelloCount IsNot Nothing Then
                                    lblCarrelloCount.Text = qVal.ToString()
                                End If
                            End If

                            ' Totale carrello (merce)
                            If Not dr.IsDBNull(dr.GetOrdinal("TotRiga")) Then
                                Dim totDec As Decimal = 0D
                                Try
                                    totDec = Convert.ToDecimal(dr("TotRiga"))
                                Catch
                                    totDec = 0D
                                End Try

                                Session("Carrello_Totale_Merce") = Convert.ToDouble(totDec)

                                If lblCarrelloTotale IsNot Nothing Then
                                    ' Formato italiano: "1.234,56"
                                    lblCarrelloTotale.Text = totDec.ToString("N2")
                                End If
                            End If
                        End If
                    End Using
                End Using
            End Using
        Catch
            ' In caso di errore DB: lascio i valori a 0
            If lblCarrelloCount IsNot Nothing Then
                lblCarrelloCount.Text = "0"
            End If
            If lblCarrelloTotale IsNot Nothing Then
                lblCarrelloTotale.Text = "0,00"
            End If
            Session("Carrello_Quantita") = 0
            Session("Carrello_Totale_Merce") = 0D
        End Try
    End Sub

    ' Metodo pubblico comodo da usare dalle pagine figlie
    Public Sub AggiornaTotaleCarrelloHeader()
        LeggiCarrello()
    End Sub

    '==========================================================
    ' META TAG SEO
    '==========================================================
    Sub Meta()
    ' Meta legacy: mantiene compatibilità, ma NON sovrascrive i meta tag se già presenti nella pagina contenuto.
    Dim description As String = Me.Page.Title
    description = Regex.Replace(description, "<[^>]*>", "")

    If description.Length > 255 Then
        description = description.Substring(0, 255)
    End If

    If Not HeaderHasMeta("description") Then
        Dim metaDescription As New HtmlMeta()
        metaDescription.Name = "description"
        metaDescription.Content = description
        Me.Page.Header.Controls.Add(metaDescription)
    End If

    Dim keywords As String = Me.Page.Title
    keywords = keywords.Replace(" ", ",")

    If Not HeaderHasMeta("keywords") Then
        Dim metaKeywords As New HtmlMeta()
        metaKeywords.Name = "keywords"
        metaKeywords.Content = keywords
        Me.Page.Header.Controls.Add(metaKeywords)
    End If
End Sub


    '==========================================================
    ' CERCA Cerca() harden + URL encode
    '==========================================================
    Public Sub Cerca()
    If Not String.IsNullOrWhiteSpace(Me.tbCerca.Text) Then
        Dim q As String = Me.tbCerca.Text.Trim()
        Me.Response.Redirect("articoli.aspx?q=" & System.Web.HttpUtility.UrlEncode(q))
    End If
    End Sub

    Protected Sub btEntra_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        ' Gestito da Login() in Page_Load
    End Sub

    Protected Sub tbCerca_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles tbCerca.TextChanged
        Cerca()
    End Sub

    '==========================================================
    ' IVA VETTORE DEFAULT
    '==========================================================
    Function IvaVettoreDefault(ByVal AziendaId As Integer) As Double
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim temp_iva As Double = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT vettori.*, iva.Valore " &
                          "FROM vettori LEFT JOIN iva ON vettori.iva=iva.id " &
                          "WHERE vettori.Predefinito=1 AND vettori.AziendeID=@aziendaId"
        cmd.Parameters.Clear()
        cmd.Parameters.AddWithValue("@aziendaId", AziendaId)

        dr = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows = True Then
            temp_iva = CDbl(dr.Item("Valore"))
        End If

        dr.Close()
        conn.Close()

        Return temp_iva
    End Function

    '==========================================================
    ' FOOTER DIV (menu informativi)
    '==========================================================
    Protected Sub DataList_DIV1_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList_DIV1.Init
        If IsNothing(Me.Session("AziendaID")) Then
            LeggiAzienda()
        End If

        SqlDataFooterDIV1.SelectCommand = "SELECT id, AziendeId, nome, descrizione, img, link_esterno, target, div_position, ordinamento, abilitato FROM pagine WHERE (Abilitato = 1) AND (AziendeId=?id) AND (div_position=1) AND ((Tipo=1) OR (Tipo=3) OR (Tipo=5) OR (Tipo=7)) ORDER BY ordinamento_footer ASC, Nome ASC"
        SqlDataFooterDIV1.SelectParameters.Add("?id", Session("AziendaID"))
    End Sub

    Protected Sub DataList_DIV2_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList_DIV2.Init
        If IsNothing(Me.Session("AziendaID")) Then
            LeggiAzienda()
        End If

        SqlDataFooterDIV2.SelectCommand = "SELECT id, AziendeId, nome, descrizione, img, link_esterno, target, div_position, ordinamento, abilitato FROM pagine WHERE (Abilitato = 1) AND (AziendeId=?id) AND (div_position=2) AND ((Tipo=1) OR (Tipo=3) OR (Tipo=5) OR (Tipo=7)) ORDER BY ordinamento_footer ASC, Nome ASC"
        SqlDataFooterDIV2.SelectParameters.Add("?id", Session("AziendaID"))
    End Sub

    Protected Sub DataList_DIV3_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList_DIV3.Init
        If IsNothing(Me.Session("AziendaID")) Then
            LeggiAzienda()
        End If

        SqlDataFooterDIV3.SelectCommand = "SELECT id, AziendeId, nome, descrizione, img, link_esterno, target, div_position, ordinamento, abilitato FROM pagine WHERE (Abilitato = 1) AND (AziendeId=?id) AND (div_position=3) AND ((Tipo=1) OR (Tipo=3) OR (Tipo=5) OR (Tipo=7)) ORDER BY ordinamento_footer ASC, Nome ASC"
        SqlDataFooterDIV3.SelectParameters.Add("?id", Session("AziendaID"))
    End Sub

    Protected Sub DataList_DIV4_Init(ByVal sender As Object, ByVal e As System.EventArgs) Handles DataList_DIV4.Init
        If IsNothing(Me.Session("AziendaID")) Then
            LeggiAzienda()
        End If

        SqlDataFooterDIV4.SelectCommand = "SELECT id, AziendeId, nome, descrizione, img, link_esterno, target, div_position, ordinamento, abilitato FROM pagine WHERE (Abilitato = 1) AND (AziendeId=?id) AND (div_position=4) AND ((Tipo=1) OR (Tipo=3) OR (Tipo=5) OR (Tipo=7)) ORDER BY ordinamento_footer ASC, Nome ASC"
        SqlDataFooterDIV4.SelectParameters.Add("?id", Session("AziendaID"))
    End Sub

    '==========================================================
    ' FACEBOOK POPUP COOKIE
    '==========================================================
    Protected Sub LB_CancelFacebook_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles LB_CancelFacebook.Click
        Session("MiPiaceFacebook") = 1

        'Creo un Cookie per nascondere il mi piace per una settimana
        CreateCookiesLikeFacebook()

        Response.Redirect(Request.UrlReferrer.AbsoluteUri)
    End Sub

    Private Sub CreateCookiesLikeFacebook()
        If Request.Cookies("FacebookLike") Is Nothing Then
            Dim aCookie As New HttpCookie("FacebookLike")
            aCookie.Values("Nascondi") = 1
            aCookie.Expires = DateTime.Now.AddDays(7)
            Response.Cookies.Add(aCookie)
        Else
            Dim cookie As HttpCookie = HttpContext.Current.Request.Cookies("FacebookLike")
            cookie.Values("Nascondi") = 1
            cookie.Expires = DateTime.Now.AddDays(-30)
            Response.Cookies.Add(cookie)
        End If
    End Sub



    ' ============================================================
    ' SEARCH (header) - button click
    ' ============================================================
    Protected Sub btnSearch_ServerClick(ByVal sender As Object, ByVal e As System.EventArgs)
        Try
            Cerca()
        Catch ex As Exception
            ' fail-safe: non interrompe la pagina
        End Try
    End Sub



' ===========================================================
'  NAV MODELS (Settori -> Categorie -> Tipologie)
'  Fix: aggiunge Tipologie/SettoriId/DefaultUrl e definisce NavTipologiaItem
' ===========================================================

Public Class NavTipologiaItem
    Public Property Id As Integer
    Public Property CategorieId As Integer
    Public Property Descrizione As String

    ' URL completo del tipo:
    '   articoli.aspx?ct=<cat>&st=<settore>&tp=<tipologia>
    Public Property DefaultUrl As String
End Class

Public Class NavCategoriaItem
    Public Property Id As Integer
    Public Property Descrizione As String

    ' Settore padre (serve per costruire URL e per debug)
    Public Property SettoriId As Integer

    ' URL “di default” della categoria, tipicamente punta alla prima tipologia abilitata
    Public Property DefaultUrl As String

    ' Tipologie figlie
    Public Property Tipologie As List(Of NavTipologiaItem)

    ' Compatibilità legacy (se in qualche punto vecchio usavi .Url)
    Public Property Url As String
        Get
            Return DefaultUrl
        End Get
        Set(value As String)
            DefaultUrl = value
        End Set
    End Property
End Class

Public Class NavSettoreItem
    Public Property Id As Integer
    Public Property Descrizione As String

    ' URL “di default” del settore, tipicamente punta a prima categoria -> prima tipologia
    Public Property DefaultUrl As String

    Public Property Categorie As List(Of NavCategoriaItem)
End Class

' ===========================================================
'  FINE NAV MODELS
' ===========================================================

    '==========================================================
    ' MENU NAV (Settori → Categorie → Tipologie) - gerarchia legacy
    '   - Mostra SOLO elementi Abilitato=1
    '   - Link coerenti come webaffare: articoli.aspx?ct=...&st=...&tp=...
    '==========================================================
    Private Function LoadNavSettori() As List(Of NavSettoreItem)

        Dim result As New List(Of NavSettoreItem)()

        Dim connStr As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Dim settoriById As New Dictionary(Of Integer, NavSettoreItem)()
        Dim categorieById As New Dictionary(Of Integer, NavCategoriaItem)()

        Using conn As New MySqlConnection(connStr)
            conn.Open()

            ' 1) Settori (abilitati)
            Using cmdS As New MySqlCommand("SELECT id, Descrizione FROM settori WHERE Abilitato=1 ORDER BY Predefinito DESC, Ordinamento, Descrizione, id", conn)
                Using rdr As MySqlDataReader = cmdS.ExecuteReader()
                    While rdr.Read()
                        Dim settoreId As Integer = Convert.ToInt32(rdr("id"))
                        Dim descr As String = Convert.ToString(rdr("Descrizione"))

                        Dim s As New NavSettoreItem()
                        s.Id = settoreId
                        s.Descrizione = descr
                        s.Categorie = New List(Of NavCategoriaItem)()
                        s.DefaultUrl = ResolveUrl("~/articoli.aspx?st=" & settoreId.ToString())

                        settoriById(settoreId) = s
                        result.Add(s)
                    End While
                End Using
            End Using

            ' 2) Categorie (abilitate) collegate a Settori abilitati
            Dim sqlC As String =
                "SELECT c.id, c.Descrizione, c.SettoriId " &
                "FROM categorie c " &
                "INNER JOIN settori s ON s.id=c.SettoriId AND s.Abilitato=1 " &
                "WHERE c.Abilitato=1 " &
                "ORDER BY c.SettoriId, c.Ordinamento, c.Descrizione, c.id"

            Using cmdC As New MySqlCommand(sqlC, conn)
                Using rdr As MySqlDataReader = cmdC.ExecuteReader()
                    While rdr.Read()
                        Dim catId As Integer = Convert.ToInt32(rdr("id"))
                        Dim catDesc As String = Convert.ToString(rdr("Descrizione"))
                        Dim settoreId As Integer = Convert.ToInt32(rdr("SettoriId"))

                        If settoriById.ContainsKey(settoreId) Then
                            Dim c As New NavCategoriaItem()
                            c.Id = catId
                            c.Descrizione = catDesc
                            c.SettoriId = settoreId
                            c.Tipologie = New List(Of NavTipologiaItem)()
                            c.DefaultUrl = ResolveUrl("~/articoli.aspx?ct=" & catId.ToString() & "&st=" & settoreId.ToString())

                            categorieById(catId) = c
                            settoriById(settoreId).Categorie.Add(c)
                        End If
                    End While
                End Using
            End Using

            ' 3) Tipologie (abilitate) collegate a Categorie/Settori abilitati
            Dim sqlT As String =
                "SELECT t.id, t.Descrizione, t.CategorieId, c.SettoriId " &
                "FROM tipologie t " &
                "INNER JOIN categorie c ON c.id=t.CategorieId AND c.Abilitato=1 " &
                "INNER JOIN settori s ON s.id=c.SettoriId AND s.Abilitato=1 " &
                "WHERE t.Abilitato=1 " &
                "ORDER BY c.SettoriId, c.Ordinamento, c.Descrizione, c.id, t.Ordinamento, t.Descrizione, t.id"

            Using cmdT As New MySqlCommand(sqlT, conn)
                Using rdr As MySqlDataReader = cmdT.ExecuteReader()
                    While rdr.Read()
                        Dim tpId As Integer = Convert.ToInt32(rdr("id"))
                        Dim tpDesc As String = Convert.ToString(rdr("Descrizione"))
                        Dim catId As Integer = Convert.ToInt32(rdr("CategorieId"))
                        Dim settoreId As Integer = Convert.ToInt32(rdr("SettoriId"))

                        If categorieById.ContainsKey(catId) Then
                            Dim t As New NavTipologiaItem()
                            t.Id = tpId
                            t.Descrizione = tpDesc
                            t.CategorieId = catId
                            t.DefaultUrl = ResolveUrl("~/articoli.aspx?ct=" & catId.ToString() & "&st=" & settoreId.ToString() & "&tp=" & tpId.ToString())

                            categorieById(catId).Tipologie.Add(t)
                        End If
                    End While
                End Using
            End Using

        End Using

        ' 4) DefaultUrl coerenti (settore → prima categoria → prima tipologia)
        For Each s As NavSettoreItem In result

            For Each c As NavCategoriaItem In s.Categorie
                If c.Tipologie IsNot Nothing AndAlso c.Tipologie.Count > 0 Then
                    ' categoria punta alla prima tipologia abilitata (come legacy)
                    c.DefaultUrl = c.Tipologie(0).DefaultUrl
                Else
                    c.DefaultUrl = ResolveUrl("~/articoli.aspx?ct=" & c.Id.ToString() & "&st=" & s.Id.ToString())
                End If
            Next

            If s.Categorie IsNot Nothing AndAlso s.Categorie.Count > 0 Then
                s.DefaultUrl = s.Categorie(0).DefaultUrl
            Else
                s.DefaultUrl = ResolveUrl("~/articoli.aspx?st=" & s.Id.ToString())
            End If

        Next

        Return result

    End Function

Protected Sub rptNavSettori_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs) Handles rptNavSettori.ItemDataBound
    If e.Item.ItemType = ListItemType.Item OrElse e.Item.ItemType = ListItemType.AlternatingItem Then
        Dim s As NavSettoreItem = TryCast(e.Item.DataItem, NavSettoreItem)
        If s Is Nothing Then Exit Sub

        Dim rpt As Repeater = TryCast(e.Item.FindControl("rptNavCategorie"), Repeater)
        If rpt IsNot Nothing Then
            rpt.DataSource = s.Categorie
            rpt.DataBind()
        End If
    End If
End Sub



    '------------------------------------------------------------
    ' Utility: HTML encode per binding in markup (prevenzione XSS)
    '------------------------------------------------------------
    Public Function SafeText(ByVal value As Object) As String
        Dim s As String = Convert.ToString(value)
        If s Is Nothing Then s = String.Empty
        Return System.Web.HttpUtility.HtmlEncode(s)
    End Function

End Class
