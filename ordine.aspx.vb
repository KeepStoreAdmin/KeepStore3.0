Imports MySql.Data.MySqlClient
Imports System.Data
Imports System.Globalization
Imports System.Net
Imports System.Net.Mail
Imports BancaSella
Imports System.Security.Authentication
Imports System.Web

Partial Class ordine
    Inherits System.Web.UI.Page

    Const _Tls12 As SslProtocols = DirectCast(&HC00, SslProtocols)
    Const Tls12 As SecurityProtocolType = DirectCast(_Tls12, SecurityProtocolType)

    Dim Contatore_BestShopping As Integer = 0

    Public firstName As String
    Public lastName As String
    Public email As String
    Public phone As String
    Public country As String
    Public province As String
    Public city As String
    Public cap As String

    ' NB: nel markup ora usiamo pair.Key, quindi questa variabile non è più necessaria,
    ' ma la lascio per compatibilità e per evitare effetti collaterali.
    Public facebook_pixel_id As String

    Public utenteId As Integer = -1
    Public idsFbPixelsSku As New Dictionary(Of String, String)
    Public redirect As String = ""

    Private ReadOnly Property Semaforo As Object
        Get
            Dim o As Object = Application("Semaforo")
            If o Is Nothing Then
                Application.Lock()
                Try
                    If Application("Semaforo") Is Nothing Then
                        Application("Semaforo") = New Object()
                    End If
                    o = Application("Semaforo")
                Finally
                    Application.UnLock()
                End Try
            End If
            Return o
        End Get
    End Property

    Private Function GetSessionInt(ByVal key As String, Optional ByVal defaultValue As Integer = 0) As Integer
        Try
            Dim o As Object = Session(key)
            If o Is Nothing Then Return defaultValue
            Dim s As String = o.ToString()
            Dim v As Integer
            If Integer.TryParse(s, v) Then Return v
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function GetSessionLong(ByVal key As String, Optional ByVal defaultValue As Long = 0) As Long
        Try
            Dim o As Object = Session(key)
            If o Is Nothing Then Return defaultValue
            Dim s As String = o.ToString()
            Dim v As Long
            If Long.TryParse(s, v) Then Return v
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function GetSessionDouble(ByVal key As String, Optional ByVal defaultValue As Double = 0) As Double
        Try
            Dim o As Object = Session(key)
            If o Is Nothing Then Return defaultValue
            Dim s As String = o.ToString()
            Dim v As Double
            If Double.TryParse(s, NumberStyles.Any, CultureInfo.CurrentCulture, v) Then Return v
            If Double.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, v) Then Return v
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function DbVal(ByVal o As Object) As Object
        If o Is Nothing Then Return DBNull.Value
        Return o
    End Function

    Private Function NormalizeCsvIds(ByVal csv As String) As String
        If String.IsNullOrWhiteSpace(csv) Then Return ""
        Dim parts As String() = csv.Split(","c)
        Dim outParts As New List(Of String)()
        For Each p As String In parts
            Dim t As String = p.Trim()
            If t = "" Then Continue For
            Dim n As Integer
            If Integer.TryParse(t, n) AndAlso n > 0 Then
                outParts.Add(n.ToString())
            End If
        Next
        Return String.Join(",", outParts)
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load

        If Me.Session("LoginId") Is Nothing Then
            ' Mantengo la tua variabile originale (Page) e aggiungo anche Pagina_visitata (pattern standard)
            Me.Session("Page") = Me.Request.Url.ToString()
            Me.Session("Pagina_visitata") = Me.Request.Url.ToString()
            Me.Response.Redirect("accessonegato.aspx", True)
            Exit Sub
        End If

        SyncLock Semaforo

            Dim LoginId As Long = GetSessionLong("LoginId", 0)
            Dim UtentiId As Long = GetSessionLong("UtentiId", 0)
            Dim TipoDoc As Integer = GetSessionInt("Ordine_TipoDoc", 0)
            Dim Documento As String = If(TryCast(Me.Session("Ordine_Documento"), String), "")
            Dim Pagamento As Integer = GetSessionInt("Ordine_Pagamento", 0)
            Dim Vettore As Integer = GetSessionInt("Ordine_Vettore", 0)
            Dim SpeseSped As Double = GetSessionDouble("Ordine_SpeseSped", 0)
            Dim SpeseAss As Double = GetSessionDouble("Ordine_SpeseAss", 0)
            Dim SpesePag As Double = GetSessionDouble("Ordine_SpesePag", 0)

            Dim documento_memorizzato As Long = 0
            Dim id As Integer = 0
            Dim DataDoc As String = ""
            Dim Note As String = If(TryCast(Me.Session("NoteDocumento"), String), "")

            If TipoDoc <= 0 Then
                Me.Response.Redirect("documenti.aspx", True)
                Exit Sub
            End If

            Dim NumDoc As Long = 0
            Dim numDoc_tracking As String = "1"

            Dim conn As New MySqlConnection()
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Dim trns As MySqlTransaction = Nothing

            Try
                conn.Open()

                ' --- Tracking numero documento (solo lettura, robusto) ---
                Using cmdMax As New MySqlCommand("SELECT COALESCE(MAX(ndocumento),0) + 1 AS nmax FROM documenti WHERE YEAR(datadocumento)=YEAR(CURRENT_TIMESTAMP) AND tipodocumentiid = ?TipoDoc", conn)
                    cmdMax.Parameters.AddWithValue("?TipoDoc", TipoDoc)
                    Try
                        Dim o As Object = cmdMax.ExecuteScalar()
                        If o IsNot Nothing Then numDoc_tracking = o.ToString()
                    Catch
                    End Try
                End Using

                ' --- Carrello: verifica righe + lista articoli per pixel ---
                Dim articoliIdGlobali As String = ""
                Using cmdCart As New MySqlCommand("SELECT ArticoliId FROM carrello WHERE LoginId=?LoginId", conn)
                    cmdCart.Parameters.AddWithValue("?LoginId", LoginId)
                    Using drCart As MySqlDataReader = cmdCart.ExecuteReader()
                        If Not drCart.HasRows Then
                            Me.Response.Redirect("carrello.aspx", True)
                            Exit Sub
                        End If

                        Dim tmp As New List(Of String)()
                        While drCart.Read()
                            Dim aId As Integer = 0
                            If Integer.TryParse(drCart("ArticoliId").ToString(), aId) AndAlso aId > 0 Then
                                tmp.Add(aId.ToString())
                            End If
                        End While
                        articoliIdGlobali = String.Join(",", tmp)
                    End Using
                End Using

                ' Facebook Pixel (solo se ci sono articoli)
                If articoliIdGlobali <> "" Then
                    facebook_pixel(articoliIdGlobali)
                End If

                ' --- Transazione documento ---
                trns = conn.BeginTransaction()

                Using cmd As New MySqlCommand("Carrello_Documento", conn, trns)
                    cmd.CommandType = CommandType.StoredProcedure

                    cmd.Parameters.AddWithValue("?pLoginId", LoginId)
                    cmd.Parameters.AddWithValue("?pTipoDoc", TipoDoc)
                    cmd.Parameters.AddWithValue("?pTipoPagamento", Pagamento)
                    cmd.Parameters.AddWithValue("?pVettore", Vettore)

                    ' Parametri BuonoSconto
                    cmd.Parameters.AddWithValue("?pBuonoScontoDescrizione", DbVal(Session("Ordine_DescrizioneBuonoSconto")))
                    cmd.Parameters.AddWithValue("?pBuonoScontoTotale", DbVal(Session("Ordine_TotaleBuonoScontoImponibile")))
                    cmd.Parameters.AddWithValue("?pBuonoScontoCodice", DbVal(Session("Ordine_CodiceBuonoSconto")))
                    cmd.Parameters.AddWithValue("?pBuonoScontoIdIVA", DbVal(Session("Ordine_BuonoScontoIdIva")))
                    cmd.Parameters.AddWithValue("?pBuonoScontoValoreIVA", DbVal(Session("Ordine_BuonoScontoValoreIva")))

                    If IsNothing(Session("SCEGLIINDIRIZZO")) Then
                        cmd.Parameters.AddWithValue("?pUtentiInirizzoId", 0)
                    Else
                        cmd.Parameters.AddWithValue("?pUtentiInirizzoId", DbVal(Session("SCEGLIINDIRIZZO")))
                    End If

                    ' Se è coupon azzero i costi
                    Dim isCoupon As Boolean = (Not (Session("Coupon_idArticolo") Is Nothing) AndAlso GetSessionInt("Coupon_idArticolo", 0) > 0)

                    cmd.Parameters.AddWithValue("?pCostoAssicurazione", If(isCoupon, 0, SpeseAss))
                    cmd.Parameters.AddWithValue("?pCostoSpedizione", If(isCoupon, 0, SpeseSped))
                    cmd.Parameters.AddWithValue("?pArrotondamento", If(Session("Coupon_Arrotondamento") Is Nothing, 0, DbVal(Session("Coupon_Arrotondamento"))))
                    cmd.Parameters.AddWithValue("?pCostoPagamento", If(isCoupon, 0, SpesePag))
                    cmd.Parameters.AddWithValue("?pNoteSpedizione", Note)
                    cmd.Parameters.AddWithValue("?pUtenteAbilitatoRC", DbVal(Session("AbilitatoIvaReverseCharge")))
                    cmd.Parameters.AddWithValue("?pIvaVettore", DbVal(Session("Iva_Vettori")))
                    cmd.Parameters.AddWithValue("?pStatiId", recupera_stato_default_Documento(TipoDoc))

                    Dim pOut As New MySqlParameter("?DocumentoMemorizzato", MySqlDbType.Int64)
                    pOut.Direction = ParameterDirection.Output
                    pOut.Value = documento_memorizzato
                    cmd.Parameters.Add(pOut)

                    ' Tracking esterni: lasciati come nel tuo file (commentati)
                    Try
                        Dim NAME As String = ""
                        Dim PRICES As String = ""
                        Dim UNITS As String = ""
                        Dim valore As Decimal = 0
                        Dim quantita As Decimal = 0

                        'Track_BestShopping(numDoc_tracking)
                        'track_Kelkoo(numDoc_tracking, valore, quantita, NAME, PRICES, UNITS)
                        'track_Pangora(numDoc_tracking, quantita, valore, NAME, PRICES, UNITS)
                    Catch
                    End Try

                    cmd.ExecuteNonQuery()

                    NumDoc = 0
                    If pOut.Value IsNot Nothing AndAlso pOut.Value IsNot DBNull.Value Then
                        Long.TryParse(pOut.Value.ToString(), NumDoc)
                    End If
                End Using

                ' Recupero ultimo documento inserito (limit 1)
                Using cmdDoc As New MySqlCommand("SELECT id, DataDocumento FROM documenti WHERE UtentiId=?UtentiId AND TipoDocumentiID=?TipoDoc ORDER BY ID DESC LIMIT 1", conn, trns)
                    cmdDoc.Parameters.AddWithValue("?UtentiId", UtentiId)
                    cmdDoc.Parameters.AddWithValue("?TipoDoc", TipoDoc)
                    Using dr As MySqlDataReader = cmdDoc.ExecuteReader()
                        If dr.Read() Then
                            id = Convert.ToInt32(dr("id"))
                            DataDoc = dr("DataDocumento").ToString()
                        End If
                    End Using
                End Using

                Me.Label1.Text = NumDoc.ToString()
                Me.Label2.Text = Documento
                Me.Label3.Text = DataDoc

                trns.Commit()
                trns = Nothing

                ' Email (ordine normale vs coupon)
                If (If(TryCast(Session("Coupon_Codice_Controllo"), String), "")) = "" Then
                    SendEmail(NumDoc, Documento, id, "")
                Else
                    SendEmail(NumDoc, Documento, id, If(TryCast(Session("NoteDocumento"), String), ""))
                End If

                ' Reset session ordine
                Me.Session("Ordine_TipoDoc") = Nothing
                Me.Session("Ordine_Documento") = Nothing
                Me.Session("Ordine_Pagamento") = Nothing
                Me.Session("Ordine_Vettore") = Nothing
                Me.Session("Ordine_SpeseSped") = Nothing
                Me.Session("Ordine_SpeseAss") = Nothing
                Me.Session("Ordine_SpesePag") = Nothing

                ' Imposto i check nel DocumentoPie
                set_check_documento_pie(id)

                ' Porto corriere sempre Franco = 2
                set_porto_spedizione(id, 2)

                ' Coupon flow
                If (If(TryCast(Session("Coupon_Codice_Controllo"), String), "")) <> "" Then
                    Dim codice_controllo As String = If(TryCast(Session("Coupon_Codice_Controllo"), String), "")
                    Dim idCoupon As Integer = GetSessionInt("Coupon_idCoupon", 0)
                    Dim NumeroOpzioneCoupon As Integer = GetSessionInt("Coupon_NumeroOpzione", 0)
                    Dim idTransazione As String = If(TryCast(Session("Coupon_IdTransazione"), String), "")

                    ' Azzero session coupon
                    Session("Coupon_Codice_Controllo") = ""
                    Session("Coupon_idTransazione") = ""
                    Session("Coupon_idCoupon") = 0
                    Session("Coupon_NumeroOpzione") = 0

                    Using conn_coupon As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                        conn_coupon.Open()

                        Using cmd_coupon As New MySqlCommand("UPDATE documenti SET Pagato=1, Coupon_idCoupon=?idCoupon, Coupon_NumeroOpzione=?NumeroOpzioneCoupon, Coupon_CodControllo=?codice_controllo, idTransazione=?idTransazione WHERE id=?id", conn_coupon)
                            cmd_coupon.Parameters.AddWithValue("?idCoupon", idCoupon)
                            cmd_coupon.Parameters.AddWithValue("?NumeroOpzioneCoupon", NumeroOpzioneCoupon)
                            cmd_coupon.Parameters.AddWithValue("?codice_controllo", codice_controllo)
                            cmd_coupon.Parameters.AddWithValue("?idTransazione", idTransazione)
                            cmd_coupon.Parameters.AddWithValue("?id", id)
                            cmd_coupon.ExecuteNonQuery()
                        End Using

                        Using cmd_coupon2 As New MySqlCommand("UPDATE coupon_inserzione SET NumeroAcquisti=NumeroAcquisti+?qnt WHERE idCoupon=?idCoupon", conn_coupon)
                            cmd_coupon2.Parameters.AddWithValue("?idCoupon", idCoupon)
                            cmd_coupon2.Parameters.AddWithValue("?qnt", GetSessionInt("Coupon_Qnt_Coupon", 0))
                            cmd_coupon2.ExecuteNonQuery()
                        End Using
                    End Using

                    Session("Coupon_Qnt_Coupon") = 0
                    redirect = "coupon_esito_acquisto.aspx?id=" & idCoupon & "&cod=" & HttpUtility.UrlEncode(codice_controllo)

                Else
                    ' Ordine normale: banca sella o dettaglio documento
                    If (If(TryCast(Me.Session("Ordine_BancaSellaGestPay_ShopId"), String), "")) <> "" Then
                        ServicePointManager.SecurityProtocol = Tls12

                        Dim totaleDocumento As Double = GetSessionDouble("Ordine_Totale_Documento", 0)
                        Me.Session("Ordine_Totale_Documento") = 0

                        Dim currency As String = "242"

                        Dim totBuono As Double = GetSessionDouble("Ordine_TotaleBuonoSconto", 0)
                        Dim totBuonoImp As Double = GetSessionDouble("Ordine_TotaleBuonoScontoImponibile", 0)
                        Dim ivaBuonoSconto As Double = (totBuono - totBuonoImp)

                        Dim amountVal As Double = totaleDocumento - ivaBuonoSconto
                        Dim amount As String = HttpUtility.UrlEncode(amountVal.ToString("0.00", CultureInfo.InvariantCulture))

                        Dim shopTransactionId As String = HttpUtility.UrlEncode(NumDoc.ToString() & "/" & Date.Now.Year.ToString())
                        Dim idDocumento As String = HttpUtility.UrlEncode(id.ToString())

                        Dim sitoWeb As String = HttpUtility.UrlEncode(If(TryCast(Me.Session("AziendaUrl"), String), ""))
                        Dim buyerName As String = HttpUtility.UrlEncode(If(TryCast(Me.Session("LoginNomeCognome"), String), ""))
                        Dim buyerEmail As String = HttpUtility.UrlEncode(If(TryCast(Me.Session("LoginEmail"), String), ""))

                        redirect = "/bancasella.aspx?currency=" & currency &
                                   "&amount=" & amount &
                                   "&shopTransactionId=" & shopTransactionId &
                                   "&iddocumento=" & idDocumento &
                                   "&sitoweb=" & sitoWeb &
                                   "&buyername=" & buyerName &
                                   "&buyeremail=" & buyerEmail
                    Else
                        redirect = "documentidettaglio.aspx?id=" & id & "&ndoc=" & NumDoc
                    End If
                End If

            Catch ex As Exception
                Try
                    If trns IsNot Nothing Then trns.Rollback()
                Catch
                End Try

                Me.Panel1.Visible = False
                Me.Panel2.Visible = True
                Response.Write("Errore :" & ex.Message)

            Finally
                If conn.State = ConnectionState.Open Then
                    conn.Close()
                    conn.Dispose()
                End If
            End Try

        End SyncLock

    End Sub

    Public Sub facebook_pixel(ByVal articoliId As String)

        ' utenteId serve al markup (advanced matching)
        utenteId = GetSessionInt("utentiid", -1)
        If utenteId <= 0 Then Exit Sub

        Dim idsSanitized As String = NormalizeCsvIds(articoliId)
        If idsSanitized = "" Then Exit Sub

        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            Try
                conn.Open()

                ' Dati utente
                Using cmdU As New MySqlCommand("SELECT IFNULL(CognomeNome,'') as CognomeNome, RagioneSociale, IFNULL(email,'') as email, COALESCE(CASE WHEN IFNULL(cellulare,'') = '' THEN NULL ELSE cellulare END, CASE WHEN IFNULL(telefono,'') = '' THEN NULL ELSE telefono END,'') as telefono, IFNULL(nazione,'') as nazione, IFNULL(provincia,'') as provincia, IFNULL(citta,'') as citta, IFNULL(cap,'') as cap FROM utenti WHERE id = ?utentiid", conn)
                    cmdU.Parameters.AddWithValue("?utentiid", utenteId)
                    Using drU As MySqlDataReader = cmdU.ExecuteReader()
                        If drU.Read() Then
                            firstName = drU("CognomeNome").ToString()
                            lastName = drU("RagioneSociale").ToString()
                            email = drU("email").ToString()
                            phone = drU("telefono").ToString()
                            country = drU("nazione").ToString()
                            province = drU("provincia").ToString()
                            city = drU("citta").ToString()
                            cap = drU("cap").ToString()
                        End If
                    End Using
                End Using

                ' Pixel per prodotto
                Dim aziendaId As Integer = GetSessionInt("AziendaID", 0)

                Dim query As String = "SELECT articoli.codice as sku, ks_fb_pixel.id_pixel " &
                                      "FROM articoli " &
                                      "LEFT JOIN ks_fb_pixel_products ON ks_fb_pixel_products.id_product = articoli.id " &
                                      "LEFT JOIN ks_fb_pixel ON ks_fb_pixel_products.id_fb_pixel = ks_fb_pixel.id " &
                                      "WHERE articoli.id IN (" & idsSanitized & ") " &
                                      "AND ks_fb_pixel.start_date<=CURDATE() AND ks_fb_pixel.stop_date>CURDATE() " &
                                      "AND ks_fb_pixel.id_company = ?AziendaID " &
                                      "ORDER BY ks_fb_pixel_products.id_fb_pixel"

                Using cmdP As New MySqlCommand(query, conn)
                    cmdP.Parameters.AddWithValue("?AziendaID", aziendaId)

                    Using dr As MySqlDataReader = cmdP.ExecuteReader()
                        Dim oldIdFbPixel As String = String.Empty
                        Dim sku As String = String.Empty

                        While dr.Read()
                            Dim newIdFbPixel As String = dr("id_pixel").ToString()

                            If newIdFbPixel <> oldIdFbPixel Then
                                If oldIdFbPixel <> String.Empty Then
                                    If Not idsFbPixelsSku.ContainsKey(oldIdFbPixel) Then
                                        idsFbPixelsSku.Add(oldIdFbPixel, sku)
                                    End If
                                End If
                                oldIdFbPixel = newIdFbPixel
                                sku = String.Empty
                            Else
                                sku &= ","
                            End If

                            sku &= dr("sku").ToString()
                        End While

                        If oldIdFbPixel <> String.Empty Then
                            If Not idsFbPixelsSku.ContainsKey(oldIdFbPixel) Then
                                idsFbPixelsSku.Add(oldIdFbPixel, sku)
                            End If
                        End If
                    End Using
                End Using

            Catch
            End Try
        End Using

    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - Ordine"
    End Sub

    Public Sub SendEmail(ByVal n As Long, ByVal documento As String, ByVal id As Integer, ByVal Descrizione_Coupon As String)
        Dim conn As New MySqlConnection
        Dim connDestAlt As New MySqlConnection
        Try
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            Dim StrCarrello As String = ""
            Dim StrIva As String = ""
            Dim IvaTipo As Integer = GetSessionInt("IvaTipo", 0)

            If IvaTipo = 1 Then
                StrIva = "*Prezzi Iva Esclusa"
            ElseIf IvaTipo = 2 Then
                StrIva = "*Prezzi Iva Inclusa"
            End If

            Dim cmdTestata As New MySqlCommand
            cmdTestata.Connection = conn
            cmdTestata.CommandType = CommandType.Text
            cmdTestata.CommandText = "SELECT * FROM vdocumenticompleta WHERE id=?id"
            cmdTestata.Parameters.AddWithValue("?id", id)

            Dim drTestata As MySqlDataReader = cmdTestata.ExecuteReader()
            drTestata.Read()

            Dim Imponibile As String = ""
            Dim SpeseSped As String = ""
            Dim SpeseAss As String = ""
            Dim SpesePag As String = ""
            Dim Iva As String = ""
            Dim Totale As String = ""

            If drTestata.HasRows Then
                StrCarrello = "<br><br><table cellpadding=3 cellspacing=3  border=0 bordercolor=silver style='font-family:arial;font-size:9pt;'>" &
                        "<tr><td bgcolor=whitesmoke><b>" & documento & ":</td><td colspan=2><b>n° " & drTestata.Item("NDocumento") & " del " & drTestata.Item("DataDocumento") & "</td></tr>" &
                        "<tr><td bgcolor=whitesmoke valign=top>Cliente:</td><td>" & drTestata.Item("RagioneSociale") & "<br>" & drTestata.Item("Indirizzo") & "<br>" & drTestata.Item("citta") & "<br>" & drTestata.Item("Cap") & " " & drTestata.Item("provincia") & "</td><td>" & drTestata.Item("cognomenome") & "<br>Codice: " & drTestata.Item("codice") & "<br>P.Iva: " & drTestata.Item("piva") & "<br>C.F: " & drTestata.Item("codicefiscale") & "</td></tr>" &
                        "<tr><td bgcolor=whitesmoke valign=top>Recapiti:</td><td>Tel: " & drTestata.Item("Telefono") & "<br>Fax: " & drTestata.Item("Fax") & "</td><td>Cell: " & drTestata.Item("Cellulare") & "<br>Email: " & drTestata.Item("Email") & "</td></tr>"

                ' Prelevo la destinazione alternativa
                connDestAlt.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                connDestAlt.Open()

                Dim RagioneSocialeA As String = ""
                Dim NomeA As String = ""
                Dim Indirizzo2 As String = ""
                Dim Citta2 As String = ""
                Dim Provincia2 As String = ""
                Dim Cap2 As String = ""

                Dim SQL As String = "SELECT * FROM utentiindirizzi where utenteid = ?UtentIId"
                Dim cmd As New MySqlCommand()
                cmd.Connection = connDestAlt
                cmd.CommandType = CommandType.Text

                If IsNothing(Session("SCEGLIINDIRIZZO")) Then
                    SQL &= " AND PREDEFINITO = 1"
                Else
                    SQL &= " AND ID = ?id"
                    cmd.Parameters.AddWithValue("?id", DbVal(Session("SCEGLIINDIRIZZO")))
                End If

                cmd.CommandText = SQL
                cmd.Parameters.AddWithValue("?UtentIId", DbVal(Session("UtentIId")))

                Dim dsdata As New DataSet
                Dim sqlAdp As New MySqlDataAdapter(cmd)
                sqlAdp.Fill(dsdata, "utentiindirizzi")

                For Each ROW As DataRow In dsdata.Tables(0).Rows
                    RagioneSocialeA = ROW("RagioneSocialeA").ToString()
                    NomeA = ROW("NomeA").ToString()
                    Indirizzo2 = ROW("IndirizzoA").ToString()
                    Citta2 = ROW("CittaA").ToString()
                    Provincia2 = ROW("ProvinciaA").ToString()
                    Cap2 = ROW("CapA").ToString()
                Next

                If dsdata.Tables(0).Rows.Count > 0 Then
                    StrCarrello &= "<tr><td bgcolor=whitesmoke valign=top>Indirizzo<br/>Alternativo:</td><td style=""vertical-align:top;"">" & RagioneSocialeA & "<br>" & Indirizzo2 & "<br>" & Citta2 & "<br>" & Cap2 & " " & Provincia2 & "</td><td style=""vertical-align:top;"">" & NomeA & "</td></tr>"
                End If

                dsdata.Dispose()
                cmd.Dispose()

                StrCarrello &= "<tr><td bgcolor=whitesmoke>Stato:</td><td colspan=2>" & drTestata.Item("StatiDescrizione1") & " - " & drTestata.Item("StatiDescrizione2") & "</td></tr>" &
                               "<tr><td bgcolor=whitesmoke>Spedizione:</td><td colspan=2>" & drTestata.Item("VettoriDescrizione") & " - " & drTestata.Item("VettoriInformazioni") & " </td></tr>"

                If Descrizione_Coupon <> "" Then
                    StrCarrello &= "<tr><td bgcolor=whitesmoke>Pagamento:</td><td colspan=2>" & drTestata.Item("PagamentiTipoDescrizione") & " - PAGATO </td></tr>"
                    StrCarrello &= "</table><table cellpadding=3 cellspacing=3 border=0 bordercolor=silver width='500' style='font-family:arial;font-size:8pt;'>"
                Else
                    StrCarrello &= "<tr><td bgcolor=whitesmoke>Pagamento:</td><td colspan=2>" & drTestata.Item("PagamentiTipoDescrizione") & " - " & drTestata.Item("PagamentiTipoInformazioni") & "</td></tr>"
                    StrCarrello &= "</table><table cellpadding=3 cellspacing=3 border=0 bordercolor=silver width='500' style='font-family:arial;font-size:8pt;'>"
                End If

                Imponibile = String.Format("{0:c}", drTestata.Item("totimponibile"))
                SpeseSped = String.Format("{0:c}", drTestata.Item("costospedizione"))
                SpeseAss = String.Format("{0:c}", drTestata.Item("costoassicurazione"))
                SpesePag = String.Format("{0:c}", drTestata.Item("costopagamento"))
                Iva = String.Format("{0:c}", drTestata.Item("totiva"))
                Totale = String.Format("{0:c}", drTestata.Item("totaledocumento"))
            End If

            drTestata.Close()
            drTestata.Dispose()
            cmdTestata.Dispose()

            If Descrizione_Coupon <> "" Then
                StrCarrello &= "<tr><td colspan=6 bgcolor=whitesmoke><b>Coupon</b></td></tr>"
                StrCarrello &= "<tr><td colspan=6>" & Descrizione_Coupon & "</td></tr>"
                StrCarrello &= "<tr><td colspan=6><a href=""http://" & Session("AziendaUrl") & "/coupon_stampa.aspx?id=" & Session("Coupon_idCoupon") & "&cod=" & Session("Coupon_Codice_Controllo") & """>Clicca qui</a> per visualizzare il Coupon Acquistato</td></tr>"
                StrCarrello &= "<tr><td colspan=6 bgcolor=whitesmoke height=1></td></tr>"
            Else
                Dim cmdRighe As New MySqlCommand
                cmdRighe.Connection = conn
                cmdRighe.CommandType = CommandType.Text
                cmdRighe.CommandText = "SELECT * FROM vdocumentirighe WHERE DocumentiId=?id"
                cmdRighe.Parameters.AddWithValue("?id", id)

                Dim drRighe As MySqlDataReader = cmdRighe.ExecuteReader()
                While drRighe.Read()
                    If IvaTipo = 1 Then
                        StrCarrello &= "<tr><td>" & drRighe.Item("marchedescrizione") & " " & drRighe.Item("codice") & "</td><td>" & drRighe.Item("descrizione1") & "</td><td align=right>" & drRighe.Item("qnt") & "</td><td nowrap align=right>" & String.Format("{0:c}", drRighe.Item("prezzo")) & "</td><td nowrap align=right><b>" & String.Format("{0:c}", drRighe.Item("importo")) & "</td></tr>"
                    ElseIf IvaTipo = 2 Then
                        StrCarrello &= "<tr><td>" & drRighe.Item("marchedescrizione") & " " & drRighe.Item("codice") & "</td><td>" & drRighe.Item("descrizione1") & "</td><td align=right>" & drRighe.Item("qnt") & "</td><td nowrap align=right>" & String.Format("{0:c}", drRighe.Item("prezzoivato")) & "</td><td nowrap align=right><b>" & String.Format("{0:c}", drRighe.Item("importoivato")) & "</td></tr>"
                        StrCarrello &= "<tr><td></td><td colspan=""2"" bgcolor=whitesmoke align=right style=""font-size:7pt;""><span style=""color:red;"">IVA " & drRighe.Item("ValoreIva") & "%</span> - <i>" & drRighe.Item("DescrizioneIva") & "</i></td><td nowrap align=right></td><td nowrap align=right></td></tr>"
                    End If
                    StrCarrello &= "<tr><td colspan=5 bgcolor=whitesmoke height=1></td></tr>"
                End While

                drRighe.Close()
                drRighe.Dispose()
                cmdRighe.Dispose()
            End If

            StrCarrello &= "<tr><td colspan=2>" & StrIva & "</td><td colspan=2 bgcolor=whitesmoke align=right>Imponibile:</td><td bgcolor=whitesmoke nowrap align=right><b>" & Imponibile & "</td></tr>" &
                           "<tr><td colspan=2></td><td colspan=2 bgcolor=whitesmoke align=right>Spedizione:</td><td bgcolor=whitesmoke nowrap align=right><b>" & SpeseSped & "</td></tr>" &
                           "<tr><td colspan=2></td><td colspan=2 bgcolor=whitesmoke align=right>Assicurazione:</td><td bgcolor=whitesmoke nowrap align=right><b>" & SpeseAss & "</td></tr>" &
                           "<tr><td colspan=2></td><td colspan=2 bgcolor=whitesmoke align=right>Pagamento:</td><td bgcolor=whitesmoke nowrap align=right><b>" & SpesePag & "</td></tr>" &
                           "<tr><td colspan=2></td><td colspan=2 bgcolor=whitesmoke align=right>Iva:</td><td bgcolor=whitesmoke nowrap align=right><b>" & Iva & "</td></tr>" &
                           "<tr><td colspan=2></td><td colspan=2 bgcolor=whitesmoke align=right><b>Totale:</td><td bgcolor=whitesmoke nowrap align=right><b>" & Totale & "</td></tr>" &
                           "</table>"

            Dim oMsg As MailMessage = New MailMessage()
            oMsg.From = New MailAddress(Session("AziendaEmail"), Session("AziendaNome"))
            oMsg.To.Add(New MailAddress(Session("LoginEmail"), Session("LoginNomeCognome")))
            oMsg.Bcc.Add(New MailAddress(Session("AziendaEmail"), Session("AziendaNome")))
            oMsg.Subject = "Conferma " & documento & " dal sito " & Session("AziendaNome")
            oMsg.Body = "<font face=arial size=2 color=black>Gentile " & Session("LoginNomeCognome") & "," &
                        "<br>La ringraziamo per aver preferito " & Session("AziendaNome") & ", abbiamo ricevuto la sua richiesta di " & documento & ",<br>Le riportiamo di seguito l'elenco completo dei prodotti scelti e le condizioni commerciali.</font>" &
                        StrCarrello

            If documento.Contains("Preventivo") = True Then
                oMsg.Body &= "<br/><span style=""font-size:9pt; color:red;"">Le ricordiamo che tale documento non ha nessuna validità di impegno poichè non è un ORDINE ma semplicemente un PREVENTIVO online.<br/>Se vuole può convertirlo in ordine contattandoci, ed indicando il tipo di pagamento che vuole effettuare.<br/>Oppure può rifare l’ordine on-line e alla fine del carrello deve cliccare sul tasto ""CONFERMA ORDINE"" e non ""SALVA PREVENTIVO"".<br/>Dopodichè seguendo le istruzioni, potrà procedere al pagamento.</span>"
            End If

            If (Session.Item("AziendaId") = 2) Then
                oMsg.Body &= "<br/><br/><font face=arial size=2 color=black><b>NOTE: </b><br>" & Me.Session("NoteDocumento") & "</font>" &
                            "<br><font face=arial size=2 color=black><b>" & Session("AziendaNome") & "</b><br>" & Session("AziendaDescrizione") & "<br>Sito Web: <a href=http://" & Session("AziendaUrl") & ">http://" & Session("AziendaUrl") & "</a> - Email: <a href=mailto:" & Session("AziendaEmail") & ">" & Session("AziendaEmail") & "</a></font>" &
                            "<br/><br/><a href=""http://www.facebook.com/pages/Webaffareit/199922450453""><img src=""http://www.webaffare.it/Public/Images/seguici_facebook.jpg""/></a><br>" &
                            "<br/><br/><font face=arial size=1 color=silver>D.Lgs 196/2003 tutela delle persone di altri soggetti rispetto al trattamento di dati personali. La presente comunicazione è destinata esclusivamente al soggetto indicato più sopra quale destinatario o ad eventuali altri soggetti autorizzati a riceverla. Essa contiene informazioni strettamente confidenziali e riservate, la cui comunicazione o diffusione a terzi è proibita, salvo che non sia espressamente autorizzata. Se avete ricevuto questa comunicazione per errore, o se desiderate non ricevere più comunicazioni su novità e offerte, Vi preghiamo di darne immediata comunicazione al mittente scrivendo a " & Me.Session("AziendaEmail") & ". Si informa che i dati forniti saranno tenuti rigorosamente riservati, saranno utilizzati unicamente da " & Me.Session("AziendaNome") & " per comunicare offerte promozionali o novità sui prodotti/servizi e resteranno a disposizione per eventuali variazioni o per la cancellazione ai sensi dell'art. 7 del citato decreto legislativo.</font>"
            Else
                oMsg.Body &= "<br/><br/><font face=arial size=2 color=black><b>NOTE: </b><br>" & Me.Session("NoteDocumento") & "</font>" &
                            "<br/><font face=arial size=2 color=black><b>" & Session("AziendaNome") & "</b><br>" & Session("AziendaDescrizione") & "<br>Sito Web: <a href=http://" & Session("AziendaUrl") & ">http://" & Session("AziendaUrl") & "</a> - Email: <a href=mailto:" & Session("AziendaEmail") & ">" & Session("AziendaEmail") & "</a></font>" &
                            "<br/><br><font face=arial size=1 color=silver>D.Lgs 196/2003 tutela delle persone di altri soggetti rispetto al trattamento di dati personali. La presente comunicazione è destinata esclusivamente al soggetto indicato più sopra quale destinatario o ad eventuali altri soggetti autorizzati a riceverla. Essa contiene informazioni strettamente confidenziali e riservate, la cui comunicazione o diffusione a terzi è proibita, salvo che non sia espressamente autorizzata. Se avete ricevuto questa comunicazione per errore, o se desiderate non ricevere più comunicazioni su novità e offerte, Vi preghiamo di darne immediata comunicazione al mittente scrivendo a " & Me.Session("AziendaEmail") & ". Si informa che i dati forniti saranno tenuti rigorosamente riservati, saranno utilizzati unicamente da " & Me.Session("AziendaNome") & " per comunicare offerte promozionali o novità sui prodotti/servizi e resteranno a disposizione per eventuali variazioni o per la cancellazione ai sensi dell'art. 7 del citato decreto legislativo.</font>"
            End If

            oMsg.IsBodyHtml = True

            Dim oSmtp As SmtpClient = New SmtpClient(Me.Session.Item("smtp"))
            oSmtp.DeliveryMethod = SmtpDeliveryMethod.Network

            Dim oCredential As NetworkCredential = New NetworkCredential(CType(Session.Item("User_smtp"), String), CType(Session.Item("Password_smtp"), String))
            oSmtp.UseDefaultCredentials = False
            oSmtp.Credentials = oCredential

            oSmtp.Send(oMsg)

        Catch
        Finally
            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

            If connDestAlt.State = ConnectionState.Open Then
                connDestAlt.Close()
                connDestAlt.Dispose()
            End If
        End Try
    End Sub

    ' --- Tracking: lasciati, ma con una correzione di base sulla query del carrello (parametrizzata) ---
    Private Sub track_Kelkoo(ByVal orderNumber As String, ByRef orderValue As Decimal, ByRef qta As Decimal, ByRef N As String, ByRef P As String, ByRef U As String)
        Try
            Dim organization As String = ""
            Dim currency As String = "EUR"
            Dim eventId As String = ""
            Dim reportInfo As String = ""

            Dim conn As MySqlConnection = New MySqlConnection
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            Dim cmdD As New MySqlCommand
            cmdD.Connection = conn

            cmdD.CommandText = "SELECT QNT, DESCRIZIONE1, PREZZO, PREZZOIVATO FROM carrello WHERE loginid = ?loginid"
            cmdD.Parameters.AddWithValue("?loginid", GetSessionLong("LoginId", 0))
            Dim drReport As MySqlDataReader = cmdD.ExecuteReader()

            While drReport.Read
                reportInfo &= "f1=" & drReport.Item("QNT") & "&f2=" & drReport.Item("DESCRIZIONE1") & "&f3=" & drReport.Item("PREZZOIVATO").ToString().Replace(",", ".") & "|"
                orderValue += CType(drReport.Item("PREZZOIVATO"), Decimal)
                qta += CType(drReport.Item("QNT"), Decimal)

                If N.Length > 0 Then N &= ","
                N &= drReport.Item("DESCRIZIONE1")

                If P.Length > 0 Then P &= ","
                P &= drReport.Item("PREZZOIVATO").ToString().Replace(",", ".")

                If U.Length > 0 Then U &= ","
                U &= drReport.Item("QNT")
            End While

            drReport.Close()

            If reportInfo.Length > 0 Then
                reportInfo = reportInfo.Substring(0, reportInfo.Length - 1)
            End If
            reportInfo = Server.UrlEncode(reportInfo)

            Dim ReviewStr As String

            cmdD.Parameters.Clear()
            cmdD.CommandType = CommandType.Text

            Dim SQL As String = ""
            SQL = " SELECT UTENTI.RAGIONESOCIALE, UTENTI.COGNOMENOME, UTENTI.EMAIL, UTENTI.AZIENDEID, AZIENDE.ORGANIZATION, AZIENDE.EVENT " &
                  " FROM UTENTI INNER JOIN AZIENDE ON UTENTI.AZIENDEID = AZIENDE.ID " &
                  " WHERE UTENTI.Id = ?utentiId"

            cmdD.CommandText = SQL
            cmdD.Parameters.AddWithValue("?utentiId", GetSessionLong("UTENTIID", 0))
            Dim drD As MySqlDataReader = cmdD.ExecuteReader()

            Dim Nome As String = ""
            Dim mail As String = ""

            If drD.Read Then
                If drD.Item("COGNOMENOME").ToString().Length = 0 Then
                    Nome = drD.Item("RAGIONESOCIALE").ToString()
                Else
                    Nome = drD.Item("COGNOMENOME").ToString() & " " & drD.Item("RAGIONESOCIALE").ToString()
                End If

                mail = drD.Item("EMAIL").ToString()
                organization = drD.Item("ORGANIZATION").ToString()
                eventId = drD.Item("EVENT").ToString()
            End If

            cmdD.Dispose()
            drD.Close()
            conn.Close()

            Dim dataSpedizione As Date = DateAdd(DateInterval.Day, 10, Date.Now)
            Dim DATA As String = CType(Format(dataSpedizione, "yyyy-MM-dd"), String)

            ReviewStr = "name=" & Nome & "&email=" & mail & "&expDeliveryDate=" & DATA
            ReviewStr = Server.UrlEncode(ReviewStr)

            DivImg.InnerHtml = "<img src='http://tbs.tradedoubler.com/report?organization=" & organization & "&event=" & eventId & "&orderNumber=" & orderNumber & "&orderValue=" & CType(orderValue, Decimal).ToString().Replace(",", ".") & "&currency=" & currency & "&reportInfo=" & reportInfo & "&review=" & ReviewStr & "'/>"
        Catch
        End Try
    End Sub

    Private Sub track_Pangora(ByVal orderId As String, ByVal qta As Decimal, ByVal orderValue As Decimal, ByRef N As String, ByRef P As String, ByRef U As String)
        Try
            Me.litScript.Text = "<!-- Pangora Sales Tracking Script V 1.0.0 - All rights reserved -->"
            Me.litScript.Text &= "<script language='JavaScript'>"
            Me.litScript.Text &= "  var pg_pangora_merchant_id='36904';"
            Me.litScript.Text &= "  var pg_order_id='" & orderId & "';"
            Me.litScript.Text &= "  var pg_cart_size='" & CType(qta, Decimal).ToString().Replace(",", ".") & "';"
            Me.litScript.Text &= "  var pg_cart_value='" & CType(orderValue, Decimal).ToString().Replace(",", ".") & "';"
            Me.litScript.Text &= "  var pg_currency='EUR';"
            Me.litScript.Text &= "  var pg_product_name='" & N & "';"
            Me.litScript.Text &= "  var pg_product_price='" & P & "';"
            Me.litScript.Text &= "  var pg_product_units='" & U & "';"
            Me.litScript.Text &= "</script>"
            Me.litScript.Text &= "<script language='JavaScript' src='https://clicks.pangora.com/sales-tracking/salesTracker.js'>"
            Me.litScript.Text &= "</script>"
            Me.litScript.Text &= "<noscript>"
            Me.litScript.Text &= "  <img src='https://clicks.pangora.com/sales-tracking/36904/salesPixel.do'/>"
            Me.litScript.Text &= "</noscript>"
        Catch
        End Try
    End Sub

    Private Sub set_check_documento_pie(ByVal idDocumento As Integer)
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand("UPDATE documentiplus SET Assicurazione=1, Spedizione=1, Pagamento=1 WHERE DocumentiId=?id", conn)
                cmd.Parameters.AddWithValue("?id", idDocumento)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    Private Sub set_porto_spedizione(ByVal idDocumento As Integer, ByVal porto As Integer)
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand("UPDATE documentipie SET CausaliPortoId=?porto WHERE DocumentiId=?id", conn)
                cmd.Parameters.AddWithValue("?porto", porto)
                cmd.Parameters.AddWithValue("?id", idDocumento)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    Private Sub Track_BestShopping(ByVal numero_documento As Long)
        Try
            Dim tr, sc
            Dim cont = 0
            Dim pa(cont, 3)

            Dim conn As MySqlConnection = New MySqlConnection
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            Dim cmdD As New MySqlCommand
            cmdD.Connection = conn
            cmdD.CommandText = "SELECT ArticoliId, Codice, QNT, DESCRIZIONE1, PREZZO, PREZZOIVATO FROM carrello WHERE loginid = ?loginid"
            cmdD.Parameters.AddWithValue("?loginid", GetSessionLong("LoginId", 0))
            Dim drReport As MySqlDataReader = cmdD.ExecuteReader()

            While drReport.Read
                cont += 1
                ReDim pa(cont, 3)
                pa(cont - 1, 0) = drReport.Item("Codice")
                pa(cont - 1, 1) = drReport.Item("PREZZOIVATO").ToString()
                pa(cont - 1, 2) = drReport.Item("QNT").ToString()
            End While

            drReport.Close()

            tr = numero_documento
            sc = GetSessionDouble("Ordine_SpeseSped", 0) * ((GetSessionDouble("Iva_Vettori", 0) / 100) + 1)

            Dim img_bs As Object
            img_bs = New OB_image_bestshopping()
            img_bs_label.Text = img_bs.WriteImage(pa, tr, sc)

            conn.Close()
        Catch
        End Try
    End Sub

    Function recupera_stato_default_Documento(ByVal TipoDocumento As Integer) As Integer
        Dim esito As Integer = 1
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand("SELECT StatiId FROM tipodocumenti WHERE id=?id", conn)
                cmd.Parameters.AddWithValue("?id", TipoDocumento)
                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    If dr.Read() Then
                        Integer.TryParse(dr("StatiId").ToString(), esito)
                    End If
                End Using
            End Using
        End Using
        Return esito
    End Function

End Class