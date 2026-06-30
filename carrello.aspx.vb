Imports System
Imports System.Data
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Text
Imports MySql.Data.MySqlClient
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.UI.HtmlControls
Imports System.Security.Cryptography
Imports System.Web


Public Partial Class carrello
    Inherits System.Web.UI.Page

Private Shared ReadOnly CartCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
Private _cartHasItems As Boolean = True

Protected Overrides Sub InitializeCulture()
    System.Threading.Thread.CurrentThread.CurrentCulture = CartCulture
    System.Threading.Thread.CurrentThread.CurrentUICulture = CartCulture
    MyBase.InitializeCulture()
End Sub

Private Shared Function FormatCurrencyIt(ByVal value As Double) As String
    Return value.ToString("N2", CartCulture) & " " & ChrW(8364)
End Function

Private Shared Function FormatPromoDateOnly(ByVal value As Object) As String
    If value Is Nothing OrElse value Is DBNull.Value Then Return ""

    Dim parsed As Date
    If TypeOf value Is Date Then
        parsed = DirectCast(value, Date)
    ElseIf Not Date.TryParse(Convert.ToString(value).Trim(), CartCulture, DateTimeStyles.None, parsed) AndAlso
           Not Date.TryParse(Convert.ToString(value).Trim(), CultureInfo.InvariantCulture, DateTimeStyles.None, parsed) Then
        Return ""
    End If

    Return parsed.ToString("dd/MM/yyyy", CartCulture)
End Function

Private Shared Function ParseDecimalForDb(ByVal value As Object, Optional ByVal def As Decimal = 0D) As Decimal
    If value Is Nothing OrElse value Is DBNull.Value Then Return def

    Dim s As String = value.ToString().Trim()
    If s = "" Then Return def

    Dim d As Decimal
    Dim t As String = NormalizeDecimalForDb(s)
    If Decimal.TryParse(t, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d
    If Decimal.TryParse(s, NumberStyles.Any, CartCulture, d) Then Return d
    If Decimal.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, d) Then Return d

    Return def
End Function

Private Shared Function NormalizeMoneyText(ByVal value As String) As String
    If value Is Nothing Then Return ""
    Return value.Replace(ChrW(8364), "").Replace(ChrW(226) & ChrW(8218) & ChrW(172), "").Replace("&euro;", "").Replace("&#8364;", "").Replace(ChrW(8722), "-").Trim()
End Function

Private Shared Function NormalizeDecimalForDb(ByVal value As String) As String
    Dim s As String = NormalizeMoneyText(value)
    If s = "" Then Return ""

    s = s.Replace("EUR", "").Replace("eur", "").Replace("Euro", "").Replace("euro", "")
    s = s.Replace(ChrW(160), "").Replace(ChrW(8239), "").Replace(" ", "").Replace("'", "")

    Dim comma As Integer = s.LastIndexOf(","c)
    Dim dot As Integer = s.LastIndexOf("."c)

    If comma >= 0 AndAlso dot >= 0 Then
        If comma > dot Then
            s = s.Replace(".", "").Replace(","c, "."c)
        Else
            s = s.Replace(",", "")
        End If
    ElseIf dot >= 0 Then
        s = NormalizeSingleDecimalSeparator(s, "."c)
    ElseIf comma >= 0 Then
        s = NormalizeSingleDecimalSeparator(s, ","c)
    End If

    Return s
End Function

Private Shared Function NormalizeSingleDecimalSeparator(ByVal value As String, ByVal separator As Char) As String
    Dim parts() As String = value.Split(separator)
    If parts.Length <= 1 Then Return value

    Dim last As String = parts(parts.Length - 1)

    If parts.Length > 2 Then
        If last.Length > 0 AndAlso last.Length <= 2 Then
            Return JoinAllButLast(parts) & "." & last
        End If

        Return String.Join("", parts)
    End If

    If last.Length = 3 Then
        Return parts(0) & last
    End If

    If separator = ","c Then
        Return parts(0) & "." & last
    End If

    Return value
End Function

Private Shared Function JoinAllButLast(ByVal parts() As String) As String
    Dim output As String = ""
    For i As Integer = 0 To parts.Length - 2
        output &= parts(i)
    Next
    Return output
End Function

Protected Function IsCheckoutStepVisible() As Boolean
    Return tOrdine IsNot Nothing AndAlso tOrdine.Visible
End Function

Protected Function IsCartEmptyState() As Boolean
    Return Not _cartHasItems
End Function

Protected Function IsCheckoutConfirmStep() As Boolean
    Return IsCheckoutStepVisible() AndAlso String.Equals(Convert.ToString(Session(SessCheckoutStep)), "confirm", StringComparison.Ordinal)
End Function

Private Sub SetCheckoutStep(ByVal stepName As String)
    If String.Equals(stepName, "confirm", StringComparison.OrdinalIgnoreCase) Then
        Session(SessCheckoutStep) = "confirm"
    ElseIf String.Equals(stepName, "checkout", StringComparison.OrdinalIgnoreCase) Then
        Session(SessCheckoutStep) = "checkout"
    Else
        Session(SessCheckoutStep) = "cart"
    End If
End Sub

Protected Function CheckoutStatusBarClass() As String
    If IsCheckoutConfirmStep() Then Return "end"
    Return If(IsCheckoutStepVisible(), "next", "first")
End Function

Protected Function CheckoutStepTextClass(ByVal stepNumber As Integer) As String
    If IsCheckoutConfirmStep() Then
        Return If(stepNumber = 3, "text-secondary link body-text-3", "link body-text-3")
    End If
    If IsCheckoutStepVisible() Then
        Return If(stepNumber = 2, "text-secondary link body-text-3", "link body-text-3")
    End If
    Return If(stepNumber = 1, "text-secondary body-text-3", "link-secondary body-text-3")
End Function

Protected Function CheckoutStepAria(ByVal stepNumber As Integer) As String
    If (Not IsCheckoutStepVisible() AndAlso stepNumber = 1) _
        OrElse (IsCheckoutStepVisible() AndAlso Not IsCheckoutConfirmStep() AndAlso stepNumber = 2) _
        OrElse (IsCheckoutConfirmStep() AndAlso stepNumber = 3) Then
        Return "aria-current=""step"""
    End If
    Return ""
End Function


' === HARDENING HELPERS (VB2012 safe) ===
Private Const CHECKOUT_TOKEN_SESSION_KEY As String = "CheckoutToken"
Private Const CHECKOUT_TOKEN_TIME_SESSION_KEY As String = "CheckoutTokenIssuedUtc"
Private Const SessCheckoutStep As String = "CartCheckoutStep"
Private Const CartEditorLockMessage As String = "Completa o annulla la modifica dell'indirizzo prima di continuare con il checkout."
Private Const OrderNotesMaxLength As Integer = 255
Private Const OrderNotesLimitMessage As String = "Le note dell'ordine superano il limite massimo di 255 caratteri. Riduci il testo e riprova."

Private Class CityRegistryAddressOption
    Public Property Cap As String
    Public Property Citta As String
    Public Property Provincia As String
End Class

Private Function GenerateCheckoutToken() As String
    ' 32 bytes random -> Base64Url (no +,/ or =)
    Dim bytes(31) As Byte
    Try
        Using rng As New RNGCryptoServiceProvider()
            rng.GetBytes(bytes)
        End Using
    Catch
        ' Fallback (should never happen)
        Dim g As Guid = Guid.NewGuid()
        bytes = g.ToByteArray()
    End Try

    Dim b64 As String = Convert.ToBase64String(bytes)
    b64 = b64.Replace("+"c, "-"c).Replace("/"c, "_"c).TrimEnd("="c)
    Return b64
End Function

Private Sub RedirectToOrdine()
    ' Issue one-time token (anti-replay / direct access hardening)
    Dim token As String = GenerateCheckoutToken()
    Session(CHECKOUT_TOKEN_SESSION_KEY) = token
    Session(CHECKOUT_TOKEN_TIME_SESSION_KEY) = DateTime.UtcNow
    Session("Ordine_FromCheckout") = 1

    Dim url As String = "ordine.aspx?t=" & HttpUtility.UrlEncode(token)
    Response.Redirect(url, True)
End Sub

Private Sub RedirectToOrdineWithQuery(ByVal extraQuery As String)
    Dim token As String = GenerateCheckoutToken()
    Session(CHECKOUT_TOKEN_SESSION_KEY) = token
    Session(CHECKOUT_TOKEN_TIME_SESSION_KEY) = DateTime.UtcNow
    Session("Ordine_FromCheckout") = 1

    Dim url As String = "ordine.aspx?t=" & HttpUtility.UrlEncode(token)
    If Not String.IsNullOrEmpty(extraQuery) Then
        If extraQuery.StartsWith("&") Then extraQuery = extraQuery.Substring(1)
        If extraQuery.StartsWith("?") Then extraQuery = extraQuery.Substring(1)
        url &= "&" & extraQuery
    End If
    Response.Redirect(url, True)
End Sub


Private Sub SafeRedirectLocal(ByVal url As String)
    If String.IsNullOrEmpty(url) Then
        Response.Redirect("default.aspx", True)
        Return
    End If

    If Not UrlIsLocal(url) Then
        Response.Redirect("default.aspx", True)
        Return
    End If

    Response.Redirect(url, True)
End Sub

Private Function UrlIsLocal(ByVal url As String) As Boolean
    ' Minimal local-url check compatible with .NET 4.0
    If String.IsNullOrEmpty(url) Then Return False
    If url.StartsWith("/") Then
        If url.StartsWith("//") OrElse url.StartsWith("/\") Then Return False
        Return True
    End If
    If url.StartsWith("~/") Then Return True
    Return False
End Function


Protected differenzaTrasportoGratis As Double = 0

' === MARKUP HELPERS (migrated from inline <script runat="server"> blocks) ===
Protected Function stampa_iva_applicata(ByVal DescrizioneEsenzioneIva As String, ByVal DescrizioneIvaRC As String) As String
    If Not String.IsNullOrEmpty(DescrizioneIvaRC) Then
        Return DescrizioneIvaRC
    End If
    Return If(DescrizioneEsenzioneIva, "")
End Function

Protected Function controllaLunghezzaTesto(ByVal testo As Object, ByVal lunghezza As Integer) As String
    Dim s As String = If(testo Is Nothing OrElse testo Is DBNull.Value, "", testo.ToString())
    If lunghezza <= 0 Then Return s
    If s.Length > lunghezza Then
        Return Left(s, lunghezza) & "..."
    End If
    Return s
End Function

Protected Function mancano_ancora(ByVal soglia As Double, ByVal imponibileLocal As Double, ByVal imponibileGratisLocal As Double) As String
    Dim ivaVettori As Double = 0
    Try
        Dim o As Object = Session("Iva_Vettori")
        If o IsNot Nothing AndAlso o IsNot DBNull.Value Then Double.TryParse(o.ToString(), ivaVettori)
    Catch
    End Try

    Dim diff As Double = soglia - (imponibileLocal - imponibileGratisLocal)
    If diff < 0 Then
        Return "** SOGLIA SUPERATA **"
    End If

    Dim diffIvato As Double = diff * ((ivaVettori / 100) + 1)
    Return "Per usufruire della PROMO mancano ancora " & FormatCurrencyIt(diffIvato) & " - Non vengono conteggiati gli articoli con SPEDIZIONE GRATIS"
End Function

Protected Function mancano_ancora_number(ByVal soglia As Double, ByVal imponibileLocal As Double, ByVal imponibileGratisLocal As Double) As Integer
    Dim ivaVettori As Double = 0
    Try
        Dim o As Object = Session("Iva_Vettori")
        If o IsNot Nothing AndAlso o IsNot DBNull.Value Then Double.TryParse(o.ToString(), ivaVettori)
    Catch
    End Try

    Dim diff As Double = soglia - (imponibileLocal - imponibileGratisLocal)
    If diff > 0 Then
        differenzaTrasportoGratis = diff * ((ivaVettori / 100) + 1)
        Return 1
    End If

    differenzaTrasportoGratis = 0
    Return 0
End Function

Protected Function controllo_img(ByVal temp As Object) As String
    If temp Is Nothing OrElse temp Is DBNull.Value Then
        Return "false"
    End If
    Return "true"
End Function

Protected Function checkImg(ByVal imgname As Object) As String
    Dim s As String = If(imgname Is Nothing OrElse imgname Is DBNull.Value, "", imgname.ToString())
    If Not String.IsNullOrEmpty(s) Then
        Return "public/foto/_" & s
    End If
    Return "Public/Foto/img_non_disponibile.png"
End Function

Private Function CartRecommendationTitle(ByVal row As DataRow) As String
    If row Is Nothing Then Return ""

    Dim title As String = Convert.ToString(row("Descrizione1")).Trim()
    If String.IsNullOrWhiteSpace(title) Then title = Convert.ToString(row("Descrizione2")).Trim()
    If String.IsNullOrWhiteSpace(title) Then title = "Articolo " & SafeInt(row("id"), 0).ToString(CultureInfo.InvariantCulture)
    Return title
End Function

Private Function CartRecommendationMeta(ByVal row As DataRow) As String
    If row Is Nothing Then Return ""

    Dim brand As String = Convert.ToString(row("MarcheDescrizione")).Trim()
    If Not String.IsNullOrWhiteSpace(brand) Then Return brand

    Dim category As String = Convert.ToString(row("CategorieDescrizione")).Trim()
    If Not String.IsNullOrWhiteSpace(category) Then Return category

    Return Convert.ToString(row("Codice")).Trim()
End Function

Private Function CartRecommendationImage(ByVal row As DataRow) As String
    If row Is Nothing Then Return ""

    Dim raw As String = Convert.ToString(row("Img1")).Trim()
    If String.IsNullOrWhiteSpace(raw) Then Return ""
    If raw.Contains("..") OrElse raw.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then Return ""

    Dim imageUrl As String = ThemeManager.ProductImageUrl(raw)
    If String.IsNullOrWhiteSpace(imageUrl) Then Return ""
    If imageUrl.IndexOf("placeholder.svg", StringComparison.OrdinalIgnoreCase) >= 0 Then Return ""

    Return imageUrl
End Function

Private Function CartRecommendationUrl(ByVal row As DataRow) As String
    If row Is Nothing Then Return "articoli.aspx"

    Dim id As Integer = SafeInt(row("id"), 0)
    Dim tcid As Integer = SafeInt(row("TCid"), -1)
    Dim url As String = "articolo.aspx?id=" & id.ToString(CultureInfo.InvariantCulture)
    If tcid > 0 Then url &= "&TCid=" & tcid.ToString(CultureInfo.InvariantCulture)
    Return url
End Function

Private Function CartRecommendationPrice(ByVal row As DataRow) As String
    If row Is Nothing Then Return ""

    Dim useNetPrice As Boolean = (GetSessionInt("IvaTipo", 0) = 1)
    Dim basePrice As Double = If(useNetPrice, SafeDbl(row("Prezzo"), 0), SafeDbl(row("PrezzoIvato"), 0))
    Dim promoPrice As Double = If(useNetPrice, SafeDbl(row("PrezzoPromo"), 0), SafeDbl(row("PrezzoPromoIvato"), 0))
    Dim inOffer As Boolean = SafeInt(row("InOfferta"), 0) = 1
    Dim displayPrice As Double = If(inOffer AndAlso promoPrice > 0 AndAlso promoPrice < basePrice, promoPrice, basePrice)

    If displayPrice <= 0 Then Return ""
    Return FormatCurrencyIt(displayPrice)
End Function

Private Function CartRecommendationKey(ByVal row As DataRow, ByVal mode As String) As String
    If row Is Nothing Then Return ""

    Dim value As String = ""
    Select Case mode
        Case "id"
            Dim id As Integer = SafeInt(row("id"), 0)
            If id > 0 Then value = id.ToString(CultureInfo.InvariantCulture)
        Case "code"
            value = Convert.ToString(row("Codice"))
        Case "url"
            value = CartRecommendationUrl(row)
        Case "nameprice"
            value = CartRecommendationTitle(row) & "|" & CartRecommendationPrice(row)
    End Select

    If String.IsNullOrWhiteSpace(value) Then Return ""
    value = value.Trim().ToUpperInvariant()

    Dim chars As New StringBuilder(value.Length)
    For Each ch As Char In value
        If Char.IsLetterOrDigit(ch) Then chars.Append(ch)
    Next
    Return chars.ToString()
End Function

Private Function CartRecommendationIsDuplicate(ByVal row As DataRow, ByVal seenIds As HashSet(Of String), ByVal seenCodes As HashSet(Of String), ByVal seenUrls As HashSet(Of String), ByVal seenNames As HashSet(Of String)) As Boolean
    Dim idKey As String = CartRecommendationKey(row, "id")
    Dim codeKey As String = CartRecommendationKey(row, "code")
    Dim urlKey As String = CartRecommendationKey(row, "url")
    Dim nameKey As String = CartRecommendationKey(row, "nameprice")

    If idKey <> "" AndAlso seenIds.Contains(idKey) Then Return True
    If codeKey <> "" AndAlso seenCodes.Contains(codeKey) Then Return True
    If urlKey <> "" AndAlso seenUrls.Contains(urlKey) Then Return True
    If nameKey <> "" AndAlso seenNames.Contains(nameKey) Then Return True

    If idKey <> "" Then seenIds.Add(idKey)
    If codeKey <> "" Then seenCodes.Add(codeKey)
    If urlKey <> "" Then seenUrls.Add(urlKey)
    If nameKey <> "" Then seenNames.Add(nameKey)
    Return False
End Function

'

' --- HELPERS (in classe carrello) ---
Private Function RbGetChecked(ByVal ctrl As Control) As Boolean
    Try
        If ctrl Is Nothing Then Return False
        Dim p = ctrl.GetType().GetProperty("Checked")
        If p Is Nothing Then Return False
        Dim v As Object = p.GetValue(ctrl, Nothing)
        If TypeOf v Is Boolean Then Return CBool(v)
        Return False
    Catch
        Return False
    End Try
End Function

Private Sub RbSetChecked(ByVal ctrl As Control, ByVal value As Boolean)
    Try
        If ctrl Is Nothing Then Exit Sub
        Dim p = ctrl.GetType().GetProperty("Checked")
        If p Is Nothing OrElse Not p.CanWrite Then Exit Sub
        p.SetValue(ctrl, value, Nothing)
    Catch
        ' NOP
    End Try
End Sub

Private Function RbGetEnabled(ByVal ctrl As Control) As Boolean
    Try
        If ctrl Is Nothing Then Return False
        Dim p = ctrl.GetType().GetProperty("Enabled")
        If p Is Nothing Then Return False
        Dim v As Object = p.GetValue(ctrl, Nothing)
        If TypeOf v Is Boolean Then Return CBool(v)
        Return False
    Catch
        Return False
    End Try
End Function

Private Sub RbSetEnabled(ByVal ctrl As Control, ByVal value As Boolean)
    Try
        If ctrl Is Nothing Then Exit Sub
        Dim p = ctrl.GetType().GetProperty("Enabled")
        If p Is Nothing OrElse Not p.CanWrite Then Exit Sub
        p.SetValue(ctrl, value, Nothing)
    Catch
        ' NOP
    End Try
End Sub

    'dichiarazioni campi pagina
Private IvaTipo As Integer = 0
Private DispoTipo As Integer = 0
Private DispoMinima As Double = 0

Private qta As Integer = 0
Private TotaleMerce As Double = 0
Protected imponibile As Double = 0
Protected imponibile_gratis As Double = 0
Private calcolo_iva As Double = 0
Private totale As Double = 0
Private pesoTotale As Double = 0

Private indice_riga_da_selezionare As Integer = -1
Private cont_indice_riga As Integer = 0
Private costo_promo_minimo As Double = 0
Private Selezionato_Vettore_Promo As Integer = 0

Private Cookie As String = ""
Private RitiroSede As Boolean = False

'Enum Lst
Private Enum Lst
    indirizzoSpedizione = 1
    destinazioneAlternativa = 2
End Enum

'ExecuteInsert
    'ExecuteInsert (INSERT vero)
Protected Function ExecuteInsert(ByVal table As String, ByVal fields As String, ByVal valuesPart As String, Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
    Dim sqlString As String = "INSERT INTO " & table & " (" & fields & ") VALUES (" & valuesPart & ")"
    ExecuteNonQuery(False, sqlString, params)
    Return Nothing
    End Function

    'ExecuteInsert_Legacy (NON Ã¨ un overload: serve solo se nel progetto esistono vecchie chiamate â€œstraneâ€)
    'ATTENZIONE: non fa niente. Se qualche punto del codice la usa davvero, va corretto quel punto.
Protected Function ExecuteInsert_Legacy(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
    Return Nothing
    End Function


' serve perchÃ© nel tuo Catch fai LogEx(..., sqlString) fuori scope
Private lastSqlString As String = ""

    ' Evita doppi aggiornamenti nella stessa request (es. click evento + altra chiamata indiretta)
    Private _carrelloAggiornatoThisRequest As Boolean = False

    Private Structure CartRowInfo
    Public Id As Integer
    Public ArtId As Integer
    Public TCId As Integer
    Public Qnt As Long
    End Structure

    Private Class VsuperInfo
    Public TCId As Integer
    Public Prezzo As Double
    Public PrezzoIvato As Double
    Public InOfferta As Integer
    Public OfferteDataInizio As Nullable(Of Date)
    Public OfferteDataFine As Nullable(Of Date)
    Public OfferteQntMinima As Long
    Public OfferteMultipli As Long
    Public OfferteDettagliId As Long
    Public PrezzoPromo As Double
    Public PrezzoPromoIvato As Double
    Public IdIvaRC As Integer
    Public ValoreIvaRC As Double
    Public DescrizioneIvaRC As String
    End Class

' =========================
' PATCH STEP 4 - HELPERS
' =========================

Private Const SessUtentiId_A As String = "UTENTIID"
Private Const SessUtentiId_B As String = "UtentiId"
Private Const SessUtentiId_C As String = "UtentiID"

Private Const SessListino_A As String = "Listino"
Private Const SessListino_B As String = "listino"

Private Const SessLoginId_A As String = "LoginId"
Private Const SessLoginId_B As String = "LOGINID"
Private Const SessCartShippingAddress As String = "SCEGLIINDIRIZZO"
Private Const SessCartShippingAddressManual As String = "CART_SELECTED_ADDRESS_IS_MANUAL"
Private Const SessCartAddressEditorOpen As String = "CART_ADDRESS_EDITOR_OPEN"
Private Const SessCartAddressEditorMode As String = "CART_ADDRESS_EDITOR_MODE"
Private Const SessCartAddressEditorId As String = "CART_ADDRESS_EDITOR_ID"
Private Const CartSessionExpiredLoginUrl As String = "login.aspx?ReturnUrl=carrello.aspx&sessionExpired=1"
Private Const InvalidShippingAddressMessage As String = "L'indirizzo di spedizione selezionato non è più valido. Seleziona nuovamente l'indirizzo e conferma l'ordine."
Private _cartSessionExpiredRedirectIssued As Boolean = False
Private _cartLoginRequiredFastPathActive As Boolean = False

    Private Function GetSessionInt(ByVal key As String, Optional ByVal def As Integer = 0) As Integer
    Try
        Dim o As Object = Session(key)
        If o Is Nothing OrElse o Is DBNull.Value Then Return def

        Dim n As Integer
        If Integer.TryParse(o.ToString(), n) Then Return n

        Return def
    Catch
        Return def
    End Try
    End Function

    Private Function HasExistingAspNetSessionCookie() As Boolean
        Try
            Dim cookieHeader As String = Convert.ToString(Request.Headers("Cookie"))
            If cookieHeader = "" Then Return False
            Return cookieHeader.IndexOf("ASP.NET_SessionId", StringComparison.OrdinalIgnoreCase) >= 0
        Catch
            Return False
        End Try
    End Function

    Private Function IsLikelyExpiredCartSession() As Boolean
        Try
            If Session Is Nothing OrElse Request Is Nothing Then Return False
            If GetSessionInt(SessLoginId_A, 0) > 0 OrElse GetSessionInt(SessLoginId_B, 0) > 0 Then Return False
            Return Session.IsNewSession AndAlso HasExistingAspNetSessionCookie()
        Catch
            Return False
        End Try
    End Function

    Private Sub RedirectToCartSessionExpiredLogin()
        _cartSessionExpiredRedirectIssued = True
        Try
            Session("StavonelCarrello") = 1
        Catch
        End Try
        Response.Redirect(CartSessionExpiredLoginUrl, False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Function GuardCartSessionForSensitiveAction() As Boolean
        If _cartSessionExpiredRedirectIssued OrElse IsLikelyExpiredCartSession() Then
            RedirectToCartSessionExpiredLogin()
            Return False
        End If
        Return True
    End Function

    Private Function IsLoginRequiredAnonymousFastPath(ByVal loginId As Integer) As Boolean
        Return loginId <= 0 AndAlso IsLoginRequiredCartRequest()
    End Function

    Private Function IsLoginRequiredCartRequest() As Boolean
        Return String.Equals(Request.QueryString("loginrequired"), "1", StringComparison.OrdinalIgnoreCase)
    End Function

    Private Sub ApplyLoginRequiredAnonymousFastPath()
        _cartLoginRequiredFastPathActive = True

        If pnlLoginRequired IsNot Nothing Then pnlLoginRequired.Visible = True
        If CartItemsWrap IsNot Nothing Then CartItemsWrap.Visible = False
        If CartEmptyPanel IsNot Nothing Then CartEmptyPanel.Visible = False
        If CartActionsWrap IsNot Nothing Then CartActionsWrap.Visible = False
        If CartSummaryColumn IsNot Nothing Then CartSummaryColumn.Visible = False
        If Panel_Unico IsNot Nothing Then Panel_Unico.Visible = False
        If tOrdine IsNot Nothing Then tOrdine.Visible = False
        If pnlCheckoutConfirm IsNot Nothing Then pnlCheckoutConfirm.Visible = False

        If pnlFatturazione IsNot Nothing Then pnlFatturazione.Visible = False
        If PnlSpedizione IsNot Nothing Then PnlSpedizione.Visible = False
        If PnlDestinazione IsNot Nothing Then PnlDestinazione.Visible = False
        If Panel_Note IsNot Nothing Then Panel_Note.Visible = False
        If pSpedizione IsNot Nothing Then pSpedizione.Visible = False
        If pAssicurazione IsNot Nothing Then pAssicurazione.Visible = False
        If pPagamento IsNot Nothing Then pPagamento.Visible = False

        If Repeater1 IsNot Nothing Then Repeater1.DataSourceID = ""
        If gvArticoliGratis IsNot Nothing Then gvArticoliGratis.DataSourceID = ""
        If rpCheckoutSummaryStandard IsNot Nothing Then rpCheckoutSummaryStandard.DataSourceID = ""
        If rpCheckoutSummaryGratis IsNot Nothing Then rpCheckoutSummaryGratis.DataSourceID = ""
    End Sub

    Private Function GetUtentiIdSafe(Optional ByVal defaultVal As Integer = 0) As Integer
    Dim id As Integer = GetSessionInt(SessUtentiId_A, 0)
    If id = 0 Then id = GetSessionInt(SessUtentiId_B, 0)
    If id = 0 Then id = GetSessionInt(SessUtentiId_C, 0)

    If id > 0 Then
        Session(SessUtentiId_A) = id
    End If

    Return If(id > 0, id, defaultVal)
    End Function

    Private Function GetCartShippingAddressIsManual() As Boolean
        Return GetSessionInt(SessCartShippingAddressManual, 0) = 1
    End Function

    Private Sub SetCartShippingAddressIsManual(ByVal isManual As Boolean)
        Session(SessCartShippingAddressManual) = If(isManual, 1, 0)
    End Sub

    Private Function GetCartShippingAddressId() As Integer
        Return GetSessionInt(SessCartShippingAddress, 0)
    End Function

    Private Sub SetCartShippingAddressId(ByVal addressId As Integer)
        If addressId > 0 Then
            Session(SessCartShippingAddress) = addressId
        Else
            Session(SessCartShippingAddress) = Nothing
        End If
    End Sub

    Private Function DbText(ByVal value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return ""
        Return value.ToString()
    End Function

    Private Sub SetAddressSelectionMessage(ByVal message As String, Optional ByVal isError As Boolean = False)
        If lblAddressSelectionMessage IsNot Nothing Then
            lblAddressSelectionMessage.Text = message
            lblAddressSelectionMessage.CssClass = If(isError, "ks-alert ks-alert-danger d-block mt-2", "body-text-3 text-main-2 d-block mt-2")
        End If
    End Sub

    Private Sub ShowCartPriceRevalidationMessage()
        If pnlCartPriceRevalidation Is Nothing OrElse litCartPriceRevalidation Is Nothing Then Return

        Dim msg As String = ""
        If Session(CartPriceRevalidationHelper.SessionMessageKey) IsNot Nothing Then
            msg = Convert.ToString(Session(CartPriceRevalidationHelper.SessionMessageKey))
        End If

        pnlCartPriceRevalidation.Visible = Not String.IsNullOrWhiteSpace(msg)
        litCartPriceRevalidation.Text = msg
        Session(CartPriceRevalidationHelper.SessionMessageKey) = Nothing
        Session(CartPriceRevalidationHelper.SessionChangedKey) = Nothing
    End Sub

    Private Function RevalidateCartPricesBeforeOrder() As Boolean
        Dim result As CartPriceRevalidationResult = CartPriceRevalidationHelper.RevalidateCurrentCart(HttpContext.Current, True)
        If result Is Nothing OrElse Not (result.HasChanges OrElse result.HasBlockingError) Then Return True

        CartPriceRevalidationHelper.StoreResultInSession(HttpContext.Current, result)
        SetCheckoutStep("confirm")
        SafeRedirectLocal("carrello.aspx?pricechanged=1")
        Return False
    End Function

    Private Function GetOrderNotesText() As String
        If txtNoteSpedizione Is Nothing OrElse txtNoteSpedizione.Text Is Nothing Then Return ""
        Return txtNoteSpedizione.Text
    End Function

    Private Function ValidateOrderNotesLength() As Boolean
        Dim note As String = GetOrderNotesText()
        If note.Length <= OrderNotesMaxLength Then Return True

        SetAddressSelectionMessage(OrderNotesLimitMessage)
        SetCheckoutStep("checkout")
        If tOrdine IsNot Nothing Then tOrdine.Visible = True
        ApplyCheckoutStepUi()
        Return False
    End Function

    Private Function TermsConsentAccepted() As Boolean
        Return chkTermsConsent IsNot Nothing AndAlso chkTermsConsent.Checked
    End Function

    Private Sub SetTermsConsentError(ByVal message As String)
        If lblTermsConsentError Is Nothing Then Return

        lblTermsConsentError.Text = If(message, "")
        lblTermsConsentError.Visible = Not String.IsNullOrWhiteSpace(lblTermsConsentError.Text)
    End Sub

    Private Sub SetShippingAddressUxState(ByVal badgeText As String, ByVal hintText As String)
        If lblAddressSelectionBadge IsNot Nothing Then lblAddressSelectionBadge.Text = badgeText
        If lblAddressSelectionHint IsNot Nothing Then lblAddressSelectionHint.Text = hintText
        If lblAddressSelectionInlineStatus IsNot Nothing Then lblAddressSelectionInlineStatus.Text = badgeText & " - " & hintText
        UpdateShippingAddressQualityHint()
    End Sub

    Private Function CleanCartAddressInput(ByVal value As String) As String
        If value Is Nothing Then Return ""
        Return value.Trim()
    End Function

    Private Function NormalizeCartCap(ByVal value As String) As String
        Dim cap As String = CleanCartAddressInput(value)
        If cap.Length > 5 Then cap = cap.Substring(0, 5)
        Return cap
    End Function

    Private Function GetCartCityOptionKey(ByVal city As String, ByVal province As String) As String
        Return CleanCartAddressInput(city) & "|" & CleanCartAddressInput(province)
    End Function

    Private Function LoadCityRegistryOptionsByCap(ByVal cap As String) As List(Of CityRegistryAddressOption)
        Dim options As New List(Of CityRegistryAddressOption)
        cap = NormalizeCartCap(cap)
        If cap = "" Then Return options

        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand(
                "SELECT DISTINCT pc.code AS Cap, pc.name_city AS Citta, c.abbreviation_province AS Provincia " &
                "FROM city_registry.postcode_codes pc " &
                "LEFT JOIN city_registry.cities c ON c.name = pc.name_city " &
                "LEFT JOIN city_registry.provinces pr ON pr.abbreviation = c.abbreviation_province " &
                "WHERE pc.code = @Cap " &
                "ORDER BY pc.name_city, c.abbreviation_province", conn)
                cmd.Parameters.AddWithValue("@Cap", cap)
                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    While dr.Read()
                        Dim citta As String = If(IsDBNull(dr("Citta")), "", dr("Citta").ToString().Trim())
                        Dim provincia As String = If(IsDBNull(dr("Provincia")), "", dr("Provincia").ToString().Trim())
                        If citta <> "" Then
                            options.Add(New CityRegistryAddressOption With {
                                .Cap = cap,
                                .Citta = citta,
                                .Provincia = provincia
                            })
                        End If
                    End While
                End Using
            End Using
        End Using

        Return options
    End Function

    Private Sub ClearCartCityResolution()
        If ddlCartCittaA IsNot Nothing Then
            ddlCartCittaA.Items.Clear()
            ddlCartCittaA.Visible = False
        End If
        If hfCartResolvedCap IsNot Nothing Then hfCartResolvedCap.Value = ""
        If hfCartResolvedCity IsNot Nothing Then hfCartResolvedCity.Value = ""
        If hfCartResolvedProvince IsNot Nothing Then hfCartResolvedProvince.Value = ""
        If tbCartCittaA IsNot Nothing Then tbCartCittaA.Text = ""
        If tbCartProvinciaA IsNot Nothing Then tbCartProvinciaA.Text = ""
    End Sub

    Private Sub SetCartCityResolution(ByVal cap As String, ByVal city As String, ByVal province As String)
        cap = NormalizeCartCap(cap)
        city = CleanCartAddressInput(city)
        province = CleanCartAddressInput(province)
        If hfCartResolvedCap IsNot Nothing Then hfCartResolvedCap.Value = cap
        If hfCartResolvedCity IsNot Nothing Then hfCartResolvedCity.Value = city
        If hfCartResolvedProvince IsNot Nothing Then hfCartResolvedProvince.Value = province
        If tbCartCittaA IsNot Nothing Then tbCartCittaA.Text = city
        If tbCartProvinciaA IsNot Nothing Then tbCartProvinciaA.Text = province
        If tbCartNazioneA IsNot Nothing AndAlso CleanCartAddressInput(tbCartNazioneA.Text) = "" Then tbCartNazioneA.Text = "IT"
    End Sub

    Private Sub BindCartCityOptions(ByVal options As List(Of CityRegistryAddressOption), Optional ByVal selectedKey As String = "")
        If ddlCartCittaA Is Nothing Then Return

        ddlCartCittaA.Items.Clear()
        ddlCartCittaA.Items.Add(New ListItem("Seleziona citta", ""))
        For Each item As CityRegistryAddressOption In options
            Dim text As String = item.Citta
            If item.Provincia <> "" Then text &= " (" & item.Provincia & ")"
            ddlCartCittaA.Items.Add(New ListItem(text, GetCartCityOptionKey(item.Citta, item.Provincia)))
        Next
        ddlCartCittaA.Visible = True

        If selectedKey <> "" AndAlso ddlCartCittaA.Items.FindByValue(selectedKey) IsNot Nothing Then
            ddlCartCittaA.SelectedValue = selectedKey
        End If
    End Sub

    Private Sub ResolveCartAddressCap(Optional ByVal selectedKey As String = "")
        Dim cap As String = NormalizeCartCap(If(tbCartCapA IsNot Nothing, tbCartCapA.Text, ""))

        ClearCartCityResolution()
        If tbCartCapA IsNot Nothing Then tbCartCapA.Text = cap

        If cap = "" Then
            SetCartAddressEditorMessage("Inserisci il CAP per rilevare citta e provincia.", True)
            Return
        End If

        Try
            Dim options As List(Of CityRegistryAddressOption) = LoadCityRegistryOptionsByCap(cap)
            If options.Count = 0 Then
                SetCartAddressEditorMessage("CAP non riconosciuto. Verifica il CAP prima di salvare l'indirizzo.", True)
                Return
            End If

            If options.Count = 1 Then
                Dim one As CityRegistryAddressOption = options(0)
                SetCartCityResolution(cap, one.Citta, one.Provincia)
                SetCartAddressEditorMessage("Citta e provincia rilevate dal CAP.", False)
                Return
            End If

            BindCartCityOptions(options, selectedKey)
            If selectedKey <> "" Then
                Dim parts() As String = selectedKey.Split("|"c)
                If parts.Length >= 2 Then
                    SetCartCityResolution(cap, parts(0), parts(1))
                    SetCartAddressEditorMessage("Citta e provincia rilevate dal CAP.", False)
                    Return
                End If
            End If

            SetCartAddressEditorMessage("Sono disponibili piu citta per questo CAP. Seleziona quella corretta.", True)
        Catch ex As Exception
            LogEx(ex, "ResolveCartAddressCap")
            SetCartAddressEditorMessage("Non e stato possibile verificare il CAP. Riprova tra qualche minuto.", True)
        End Try
    End Sub

    Private Function GetCartAddressEditorOpen() As Boolean
        Return String.Equals(Convert.ToString(Session(SessCartAddressEditorOpen)), "1", StringComparison.Ordinal)
    End Function

    Private Function IsAddressEditModeActive() As Boolean
        Return GetCartAddressEditorOpen()
    End Function

    Private Sub SetCartAddressEditorState(ByVal isOpen As Boolean, ByVal mode As String, ByVal addressId As Integer)
        Session(SessCartAddressEditorOpen) = If(isOpen, "1", "0")
        Session(SessCartAddressEditorMode) = If(String.Equals(mode, "edit", StringComparison.OrdinalIgnoreCase), "edit", "add")
        Session(SessCartAddressEditorId) = Math.Max(0, addressId).ToString(CultureInfo.InvariantCulture)
    End Sub

    Private Function GetCartAddressEditorMode() As String
        Dim mode As String = Convert.ToString(Session(SessCartAddressEditorMode))
        If String.Equals(mode, "edit", StringComparison.OrdinalIgnoreCase) Then Return "edit"
        Return "add"
    End Function

    Private Function GetCartAddressEditorId() As Integer
        Dim id As Integer = 0
        Integer.TryParse(Convert.ToString(Session(SessCartAddressEditorId)), id)
        Return Math.Max(0, id)
    End Function

    Private Sub SetCartAddressEditorMessage(ByVal message As String, Optional ByVal isError As Boolean = False)
        If lblCartAddressEditorMessage Is Nothing Then Return
        lblCartAddressEditorMessage.Text = message
        If String.IsNullOrWhiteSpace(message) Then
            lblCartAddressEditorMessage.CssClass = "ks-address-form-message"
        Else
            lblCartAddressEditorMessage.CssClass = If(isError, "ks-address-form-message is-error", "ks-address-form-message is-ok")
        End If
    End Sub

    Private Sub ClearCartAddressEditorFields()
        If hfCartAddressMode IsNot Nothing Then hfCartAddressMode.Value = "add"
        If hfCartAddressId IsNot Nothing Then hfCartAddressId.Value = "0"
        If tbCartRagioneSocialeA IsNot Nothing Then tbCartRagioneSocialeA.Text = ""
        If tbCartNomeA IsNot Nothing Then tbCartNomeA.Text = ""
        If tbCartIndirizzoA IsNot Nothing Then tbCartIndirizzoA.Text = ""
        If tbCartCapA IsNot Nothing Then tbCartCapA.Text = ""
        If tbCartCittaA IsNot Nothing Then tbCartCittaA.Text = ""
        If tbCartProvinciaA IsNot Nothing Then tbCartProvinciaA.Text = ""
        If ddlCartCittaA IsNot Nothing Then
            ddlCartCittaA.Items.Clear()
            ddlCartCittaA.Visible = False
        End If
        If hfCartResolvedCap IsNot Nothing Then hfCartResolvedCap.Value = ""
        If hfCartResolvedCity IsNot Nothing Then hfCartResolvedCity.Value = ""
        If hfCartResolvedProvince IsNot Nothing Then hfCartResolvedProvince.Value = ""
        If tbCartZona IsNot Nothing Then tbCartZona.Text = ""
        If tbCartTelefonoA IsNot Nothing Then tbCartTelefonoA.Text = ""
        If tbCartCellulareA IsNot Nothing Then tbCartCellulareA.Text = ""
        If tbCartFaxA IsNot Nothing Then tbCartFaxA.Text = ""
        If tbCartNote IsNot Nothing Then tbCartNote.Text = ""
        If tbCartNazioneA IsNot Nothing Then tbCartNazioneA.Text = "IT"
        If chkCartAddressUseForOrder IsNot Nothing Then chkCartAddressUseForOrder.Checked = True
        If chkCartAddressSetDefault IsNot Nothing Then chkCartAddressSetDefault.Checked = False
        SetCartAddressEditorMessage("")
    End Sub

    Private Function ValidateCartAddressEditor() As List(Of String)
        Dim errors As New List(Of String)

        If String.IsNullOrWhiteSpace(tbCartIndirizzoA.Text) Then errors.Add("Inserire l'indirizzo.")
        Dim cap As String = NormalizeCartCap(tbCartCapA.Text)
        If cap = "" OrElse cap.Length <> 5 Then errors.Add("Inserire un CAP valido di 5 caratteri.")
        If String.IsNullOrWhiteSpace(tbCartCittaA.Text) Then errors.Add("Selezionare una citta valida per il CAP.")
        If String.IsNullOrWhiteSpace(tbCartProvinciaA.Text) Then errors.Add("La provincia deve essere rilevata dal CAP.")
        If CleanCartAddressInput(tbCartRagioneSocialeA.Text).Length > 100 Then errors.Add("La ragione sociale/cognome e troppo lunga.")
        If CleanCartAddressInput(tbCartNomeA.Text).Length > 50 Then errors.Add("Il nome e troppo lungo.")
        If CleanCartAddressInput(tbCartIndirizzoA.Text).Length > 100 Then errors.Add("L'indirizzo e troppo lungo.")
        If CleanCartAddressInput(tbCartCapA.Text).Length > 10 Then errors.Add("Il CAP e troppo lungo.")
        If CleanCartAddressInput(tbCartCittaA.Text).Length > 80 Then errors.Add("La citta e troppo lunga.")
        If CleanCartAddressInput(tbCartProvinciaA.Text).Length > 10 Then errors.Add("La provincia e troppo lunga.")
        If CleanCartAddressInput(tbCartZona.Text).Length > 100 Then errors.Add("La zona e troppo lunga.")
        If CleanCartAddressInput(tbCartTelefonoA.Text).Length > 30 Then errors.Add("Il telefono e troppo lungo.")
        If CleanCartAddressInput(tbCartCellulareA.Text).Length > 30 Then errors.Add("Il cellulare e troppo lungo.")
        If CleanCartAddressInput(tbCartFaxA.Text).Length > 30 Then errors.Add("Il fax e troppo lungo.")
        If CleanCartAddressInput(tbCartNote.Text).Length > 255 Then errors.Add("Le note sono troppo lunghe.")
        If CleanCartAddressInput(tbCartNazioneA.Text).Length > 50 Then errors.Add("La nazione e troppo lunga.")

        If errors.Count = 0 Then
            Dim resolvedCap As String = If(hfCartResolvedCap IsNot Nothing, hfCartResolvedCap.Value, "")
            Dim resolvedCity As String = If(hfCartResolvedCity IsNot Nothing, hfCartResolvedCity.Value, "")
            Dim resolvedProvince As String = If(hfCartResolvedProvince IsNot Nothing, hfCartResolvedProvince.Value, "")
            If Not String.Equals(cap, resolvedCap, StringComparison.Ordinal) _
                OrElse Not String.Equals(CleanCartAddressInput(tbCartCittaA.Text), resolvedCity, StringComparison.Ordinal) _
                OrElse Not String.Equals(CleanCartAddressInput(tbCartProvinciaA.Text), resolvedProvince, StringComparison.Ordinal) Then
                errors.Add("Verificare il CAP e selezionare la citta proposta prima di salvare.")
            End If
        End If

        Return errors
    End Function

    Private Sub UpdateCartAddressEditorHint()
        If lblCartAddressEditorHint Is Nothing Then Return

        Dim hints As New List(Of String)
        Dim cap As String = CleanCartAddressInput(tbCartCapA.Text)
        If cap = "" OrElse cap.Length < 5 Then hints.Add("CAP da controllare")
        If CleanCartAddressInput(tbCartProvinciaA.Text) = "" Then hints.Add("citta e provincia da rilevare")
        If CleanCartAddressInput(tbCartTelefonoA.Text) = "" AndAlso CleanCartAddressInput(tbCartCellulareA.Text) = "" Then hints.Add("telefono utile per il corriere")

        If hints.Count = 0 Then
            lblCartAddressEditorHint.Text = "Controllo rapido: indirizzo pronto per il checkout."
        Else
            lblCartAddressEditorHint.Text = "Controllo rapido: " & String.Join(", ", hints.ToArray()) & "."
        End If
    End Sub

    Private Sub ConfigureCartAddressEditor()
        If pnlCartAddressEditor Is Nothing Then Return

        Dim isOpen As Boolean = GetCartAddressEditorOpen()
        Dim mode As String = GetCartAddressEditorMode()
        Dim addressId As Integer = GetCartAddressEditorId()

        pnlCartAddressEditor.Visible = isOpen
        If Not isOpen Then Return

        If hfCartAddressMode IsNot Nothing Then hfCartAddressMode.Value = mode
        If hfCartAddressId IsNot Nothing Then hfCartAddressId.Value = addressId.ToString(CultureInfo.InvariantCulture)
        If litCartAddressEditorTitle IsNot Nothing Then
            litCartAddressEditorTitle.Text = If(mode = "edit", "<h6 class=""fw-semibold"">Modifica indirizzo selezionato</h6>", "<h6 class=""fw-semibold"">Aggiungi nuovo indirizzo</h6>")
        End If
        If btnCartAddressSave IsNot Nothing Then btnCartAddressSave.Text = If(mode = "edit", "Salva modifiche", "Salva nuovo indirizzo")
        If tbCartCittaA IsNot Nothing Then tbCartCittaA.ReadOnly = True
        If tbCartProvinciaA IsNot Nothing Then tbCartProvinciaA.ReadOnly = True
        If lblCartAddressEditorMessage IsNot Nothing AndAlso String.IsNullOrWhiteSpace(lblCartAddressEditorMessage.Text) Then
            SetCartAddressEditorMessage(CartEditorLockMessage, False)
        End If
        UpdateCartAddressEditorHint()
    End Sub

    Private Sub SetControlEnabled(ByVal control As WebControl, ByVal enabled As Boolean)
        If control Is Nothing Then Return
        control.Enabled = enabled
        Dim css As String = If(control.CssClass, "")
        css = css.Replace(" ks-action-disabled", "")
        If Not enabled Then css &= " ks-action-disabled"
        control.CssClass = css.Trim()
        control.Attributes("aria-disabled") = If(enabled, "false", "true")
    End Sub

    Private Function IsCouponApplied() As Boolean
        Return GetSessionInt("BuonoSconto_id", 0) > 0
    End Function

    Private Sub SyncCouponUiState()
        Dim couponApplied As Boolean = IsCouponApplied()
        Dim unlocked As Boolean = Not IsAddressEditModeActive()

        If couponApplied Then
            If TB_BuonoSconto IsNot Nothing AndAlso String.IsNullOrWhiteSpace(TB_BuonoSconto.Text) Then
                TB_BuonoSconto.Text = getBuonoScontoCodice(GetSessionInt("BuonoSconto_id", 0))
            End If

            SetControlEnabled(TB_BuonoSconto, False)
            SetControlEnabled(BT_ApplicaBuonoSconto, False)

            If LB_CancelBuonoSconto IsNot Nothing Then
                LB_CancelBuonoSconto.Visible = True
                SetControlEnabled(LB_CancelBuonoSconto, unlocked)
            End If
        Else
            SetControlEnabled(TB_BuonoSconto, unlocked)
            SetControlEnabled(BT_ApplicaBuonoSconto, unlocked)
            If LB_CancelBuonoSconto IsNot Nothing Then SetControlEnabled(LB_CancelBuonoSconto, unlocked)
        End If
    End Sub

    Private Function GetCartRecentlyViewedIds(ByVal maxCount As Integer) As List(Of Integer)
        Dim result As New List(Of Integer)()
        MergeCartRecentIds(result, Convert.ToString(Session("ks_recent_ids")), maxCount)
        MergeCartRecentIds(result, Convert.ToString(Session("ks_recent_session")), maxCount)

        Dim recentCookie As HttpCookie = Request.Cookies("ks_recent")
        If recentCookie IsNot Nothing Then
            MergeCartRecentIds(result, HttpUtility.UrlDecode(recentCookie.Value), maxCount)
        End If

        Dim sessionCookie As HttpCookie = Request.Cookies("ks_recent_session")
        If sessionCookie IsNot Nothing Then
            MergeCartRecentIds(result, HttpUtility.UrlDecode(sessionCookie.Value), maxCount)
        End If

        Return result
    End Function

    Private Sub MergeCartRecentIds(ByVal target As List(Of Integer), ByVal raw As String, ByVal maxCount As Integer)
        If target Is Nothing OrElse String.IsNullOrWhiteSpace(raw) Then Return

        Dim parts As String() = raw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
        For Each part As String In parts
            If target.Count >= maxCount Then Exit For

            Dim id As Integer = SafeInt(part.Trim(), 0)
            If id > 0 AndAlso Not target.Contains(id) Then target.Add(id)
        Next
    End Sub

    Private Function GetCartArticleIds() As HashSet(Of Integer)
        Dim result As New HashSet(Of Integer)()
        AddCartArticleIdsFromRepeater(result, Repeater1)
        AddCartArticleIdsFromRepeater(result, gvArticoliGratis)
        Return result
    End Function

    Private Sub AddCartArticleIdsFromRepeater(ByVal target As HashSet(Of Integer), ByVal repeater As Repeater)
        If target Is Nothing OrElse repeater Is Nothing OrElse repeater.Items Is Nothing Then Return

        For Each item As RepeaterItem In repeater.Items
            If item.ItemType <> ListItemType.Item AndAlso item.ItemType <> ListItemType.AlternatingItem Then Continue For

            Dim tbArtID As TextBox = TryCast(item.FindControl("tbArtID"), TextBox)
            Dim id As Integer = SafeInt(If(tbArtID IsNot Nothing, tbArtID.Text, Nothing), 0)
            If id > 0 Then target.Add(id)
        Next
    End Sub

    Private Function CartRecommendationSelectFields() As String
        Return "v.id, COALESCE(v.TCid,-1) AS TCid, v.Codice, v.Descrizione1, v.Descrizione2, " & _
               "IFNULL(v.MarcheDescrizione,'') AS MarcheDescrizione, IFNULL(v.CategorieDescrizione,'') AS CategorieDescrizione, " & _
               "v.Img1, COALESCE(v.Prezzo,0) AS Prezzo, COALESCE(v.PrezzoIvato,0) AS PrezzoIvato, " & _
               "COALESCE(v.PrezzoPromo,0) AS PrezzoPromo, COALESCE(v.PrezzoPromoIvato,0) AS PrezzoPromoIvato, COALESCE(v.InOfferta,0) AS InOfferta "
    End Function

    Private Function CartRecommendationStockWhere() As String
        Return "(COALESCE(v.Disponibilita,0)>0 OR (COALESCE(v.Giacenza,0)-COALESCE(v.Impegnata,0))>0)"
    End Function

    Private Function LoadCartRecentlyViewedProducts(ByVal maxItems As Integer, ByVal cartIds As HashSet(Of Integer)) As DataTable
        Dim recentIds As List(Of Integer) = GetCartRecentlyViewedIds(40)
        If recentIds.Count = 0 Then Return Nothing

        Dim safeIds As New List(Of Integer)()
        For Each id As Integer In recentIds
            If id > 0 AndAlso Not cartIds.Contains(id) AndAlso Not safeIds.Contains(id) Then safeIds.Add(id)
            If safeIds.Count >= 40 Then Exit For
        Next
        If safeIds.Count = 0 Then Return Nothing

        Dim orderParts As New List(Of String)()
        For i As Integer = 0 To safeIds.Count - 1
            orderParts.Add("WHEN " & safeIds(i).ToString(CultureInfo.InvariantCulture) & " THEN " & i.ToString(CultureInfo.InvariantCulture))
        Next

        Dim sql As String = _
            "SELECT " & CartRecommendationSelectFields() & _
            "FROM vsuperarticoli v INNER JOIN articoli aBase ON aBase.id=v.id " & _
            "WHERE COALESCE(v.NListino,1)=@listino AND COALESCE(aBase.Abilitato,1)=1 " & _
            "AND COALESCE(v.id,0) IN (" & String.Join(",", safeIds.ToArray()) & ") " & _
            "AND COALESCE(NULLIF(v.Img1,''),'')<>'' " & _
            "AND " & CartRecommendationStockWhere() & " " & _
            "ORDER BY CASE v.id " & String.Join(" ", orderParts.ToArray()) & " ELSE 9999 END " & _
            "LIMIT " & Math.Max(1, maxItems).ToString(CultureInfo.InvariantCulture)

        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@listino", GetListinoSafe(1))
                Using da As New MySqlDataAdapter(cmd)
                    Dim dt As New DataTable()
                    conn.Open()
                    da.Fill(dt)
                    Return dt
                End Using
            End Using
        End Using
    End Function

    Private Function LoadCartFallbackRecommendations(ByVal maxItems As Integer, ByVal cartIds As HashSet(Of Integer)) As DataTable
        If cartIds Is Nothing OrElse cartIds.Count = 0 Then Return Nothing

        Dim ids As New List(Of Integer)()
        For Each id As Integer In cartIds
            If id > 0 AndAlso Not ids.Contains(id) Then ids.Add(id)
            If ids.Count >= 40 Then Exit For
        Next
        If ids.Count = 0 Then Return Nothing

        Dim idsCsv As String = String.Join(",", ids.ToArray())
        Dim seedWhere As String = "COALESCE(seed.NListino,1)=@listino AND COALESCE(seed.id,0) IN (" & idsCsv & ")"
        Dim categoryMatch As String = "COALESCE(v.CategorieId,0)>0 AND v.CategorieId IN (SELECT DISTINCT seed.CategorieId FROM vsuperarticoli seed WHERE " & seedWhere & " AND COALESCE(seed.CategorieId,0)>0)"
        Dim typeMatch As String = "COALESCE(v.TipologieId,0)>0 AND v.TipologieId IN (SELECT DISTINCT seed.TipologieId FROM vsuperarticoli seed WHERE " & seedWhere & " AND COALESCE(seed.TipologieId,0)>0)"
        Dim brandMatch As String = "COALESCE(v.MarcheId,0)>0 AND v.MarcheId IN (SELECT DISTINCT seed.MarcheId FROM vsuperarticoli seed WHERE " & seedWhere & " AND COALESCE(seed.MarcheId,0)>0)"
        Dim sectorMatch As String = "COALESCE(v.SettoriId,0)>0 AND v.SettoriId IN (SELECT DISTINCT seed.SettoriId FROM vsuperarticoli seed WHERE " & seedWhere & " AND COALESCE(seed.SettoriId,0)>0)"
        Dim relevance As String = _
            "(CASE WHEN " & categoryMatch & " THEN 8 ELSE 0 END + " & _
            "CASE WHEN " & typeMatch & " THEN 4 ELSE 0 END + " & _
            "CASE WHEN " & brandMatch & " THEN 3 ELSE 0 END + " & _
            "CASE WHEN " & sectorMatch & " THEN 1 ELSE 0 END)"

        Dim sql As String = _
            "SELECT " & CartRecommendationSelectFields() & _
            "FROM vsuperarticoli v INNER JOIN articoli aBase ON aBase.id=v.id " & _
            "WHERE COALESCE(v.NListino,1)=@listino AND COALESCE(aBase.Abilitato,1)=1 " & _
            "AND COALESCE(v.id,0) NOT IN (" & idsCsv & ") " & _
            "AND COALESCE(NULLIF(v.Img1,''),'')<>'' " & _
            "AND " & CartRecommendationStockWhere() & " " & _
            "AND ((" & categoryMatch & ") OR (" & typeMatch & ") OR (" & brandMatch & ") OR (" & sectorMatch & ")) " & _
            "ORDER BY " & relevance & " DESC, COALESCE(v.InOfferta,0) DESC, (COALESCE(v.Giacenza,0)-COALESCE(v.Impegnata,0)) DESC, COALESCE(v.visite,0) DESC, v.id DESC " & _
            "LIMIT " & Math.Max(1, maxItems).ToString(CultureInfo.InvariantCulture)

        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@listino", GetListinoSafe(1))
                Using da As New MySqlDataAdapter(cmd)
                    Dim dt As New DataTable()
                    conn.Open()
                    da.Fill(dt)
                    Return dt
                End Using
            End Using
        End Using
    End Function

    Private Function LoadCatalogFallbackRecommendations(ByVal maxItems As Integer, ByVal cartIds As HashSet(Of Integer)) As DataTable
        Dim excludedIds As New List(Of Integer)()
        If cartIds IsNot Nothing Then
            For Each id As Integer In cartIds
                If id > 0 AndAlso Not excludedIds.Contains(id) Then excludedIds.Add(id)
                If excludedIds.Count >= 80 Then Exit For
            Next
        End If

        Dim exclusion As String = ""
        If excludedIds.Count > 0 Then exclusion = "AND COALESCE(v.id,0) NOT IN (" & String.Join(",", excludedIds.ToArray()) & ") "

        Dim sql As String = _
            "SELECT " & CartRecommendationSelectFields() & _
            "FROM vsuperarticoli v INNER JOIN articoli aBase ON aBase.id=v.id " & _
            "WHERE COALESCE(v.NListino,1)=@listino AND COALESCE(aBase.Abilitato,1)=1 " & _
            exclusion & _
            "AND COALESCE(NULLIF(v.Img1,''),'')<>'' " & _
            "AND " & CartRecommendationStockWhere() & " " & _
            "ORDER BY COALESCE(v.InOfferta,0) DESC, (COALESCE(v.Giacenza,0)-COALESCE(v.Impegnata,0)) DESC, COALESCE(v.visite,0) DESC, v.id DESC " & _
            "LIMIT " & Math.Max(1, maxItems).ToString(CultureInfo.InvariantCulture)

        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            Using cmd As New MySqlCommand(sql, conn)
                cmd.Parameters.AddWithValue("@listino", GetListinoSafe(1))
                Using da As New MySqlDataAdapter(cmd)
                    Dim dt As New DataTable()
                    conn.Open()
                    da.Fill(dt)
                    Return dt
                End Using
            End Using
        End Using
    End Function

    Private Function LoadCartRecommendations(ByVal maxItems As Integer, ByRef title As String) As DataTable
        title = "Visti di recente"
        Dim cartIds As HashSet(Of Integer) = GetCartArticleIds()

        Dim recentItems As DataTable = LoadCartRecentlyViewedProducts(maxItems, cartIds)
        If recentItems IsNot Nothing AndAlso recentItems.Rows.Count > 0 Then Return recentItems

        title = "Potrebbe interessarti anche"
        Dim relatedItems As DataTable = LoadCartFallbackRecommendations(maxItems, cartIds)
        If relatedItems IsNot Nothing AndAlso relatedItems.Rows.Count > 0 Then Return relatedItems

        Return LoadCatalogFallbackRecommendations(maxItems, cartIds)
    End Function

    Private Function RenderCartRecommendationCard(ByVal row As DataRow) As String
        If row Is Nothing Then Return ""

        Dim title As String = CartRecommendationTitle(row)
        Dim url As String = CartRecommendationUrl(row)
        Dim imageUrl As String = CartRecommendationImage(row)
        Dim meta As String = CartRecommendationMeta(row)
        Dim price As String = CartRecommendationPrice(row)

        If String.IsNullOrWhiteSpace(title) OrElse String.IsNullOrWhiteSpace(url) OrElse String.IsNullOrWhiteSpace(imageUrl) Then Return ""

        Dim sb As New StringBuilder()
        sb.Append("<article class=""ks-rv-card"">")
        sb.Append("<a class=""ks-rv-image-link"" href=""").Append(HttpUtility.HtmlAttributeEncode(url)).Append(""">")
        sb.Append("<span class=""ks-rv-image-box"" data-placeholder=""Immagine non disponibile"">")
        sb.Append("<img src=""").Append(HttpUtility.HtmlAttributeEncode(imageUrl)).Append(""" alt=""").Append(HttpUtility.HtmlAttributeEncode(title)).Append(""" loading=""lazy"" width=""180"" height=""180"" onerror=""this.style.display='none';this.parentNode.className=this.parentNode.className+' is-missing';"" />")
        sb.Append("</span></a>")
        sb.Append("<div class=""ks-rv-body"">")
        If Not String.IsNullOrWhiteSpace(meta) Then
            sb.Append("<p class=""ks-rv-code"">").Append(HttpUtility.HtmlEncode(meta)).Append("</p>")
        End If
        sb.Append("<h3 class=""ks-rv-name""><a href=""").Append(HttpUtility.HtmlAttributeEncode(url)).Append(""">")
        sb.Append(HttpUtility.HtmlEncode(ThemeManager.CompactText(title, 72))).Append("</a></h3>")
        If Not String.IsNullOrWhiteSpace(price) Then
            sb.Append("<div class=""ks-rv-price"">").Append(HttpUtility.HtmlEncode(price)).Append("</div>")
        End If
        sb.Append("<a class=""ks-rv-link"" href=""").Append(HttpUtility.HtmlAttributeEncode(url)).Append(""">Vedi prodotto</a>")
        sb.Append("</div></article>")
        Return sb.ToString()
    End Function

    Private Function RenderCartRecommendationsSection(ByVal items As DataTable, ByVal title As String, ByVal maxCards As Integer) As String
        If items Is Nothing OrElse items.Rows.Count = 0 Then Return ""

        Dim cards As New StringBuilder()
        Dim seenIds As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim seenCodes As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim seenUrls As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim seenNames As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim renderedCount As Integer = 0

        For Each row As DataRow In items.Rows
            If CartRecommendationIsDuplicate(row, seenIds, seenCodes, seenUrls, seenNames) Then Continue For
            Dim card As String = RenderCartRecommendationCard(row)
            If Not String.IsNullOrWhiteSpace(card) Then
                cards.Append(card)
                renderedCount += 1
                If renderedCount >= Math.Max(1, maxCards) Then Exit For
            End If
        Next
        If cards.Length = 0 Then Return ""

        Dim subtitle As String = If(String.Equals(title, "Potrebbe interessarti anche", StringComparison.OrdinalIgnoreCase), _
                                    "Suggerimenti selezionati dal catalogo KeepStore.", _
                                    "Prodotti che hai consultato di recente.")

        Dim sb As New StringBuilder()
        sb.Append("<section class=""ks-rv-section"" aria-labelledby=""ks-rv-title"">")
        sb.Append("<div class=""ks-rv-container"">")
        sb.Append("<div class=""ks-rv-head""><div>")
        sb.Append("<p class=""ks-rv-eyebrow"">Suggerimenti per te</p>")
        sb.Append("<h2 id=""ks-rv-title"">").Append(HttpUtility.HtmlEncode(title)).Append("</h2>")
        sb.Append("<p class=""ks-rv-subtitle"">").Append(HttpUtility.HtmlEncode(subtitle)).Append("</p>")
        sb.Append("</div></div>")
        sb.Append("<div class=""ks-rv-grid"">").Append(cards.ToString()).Append("</div>")
        sb.Append("</div></section>")
        Return sb.ToString()
    End Function

    Private Sub BindCartRecentlyViewed()
        Try
            If RecommendedProductsPanel Is Nothing OrElse RecommendedProductsHtml Is Nothing Then Return

            RecommendedProductsPanel.Visible = False
            RecommendedProductsHtml.Text = ""
            If IsCheckoutConfirmStep() OrElse IsCartEmptyState() Then Return

            Dim recommendationTitle As String = "Visti di recente"
            Dim items As DataTable = LoadCartRecommendations(16, recommendationTitle)
            Dim html As String = RenderCartRecommendationsSection(items, recommendationTitle, 8)
            If String.IsNullOrWhiteSpace(html) Then Return

            RecommendedProductsHtml.Text = html
            RecommendedProductsPanel.Visible = True
        Catch ex As Exception
            If RecommendedProductsPanel IsNot Nothing Then RecommendedProductsPanel.Visible = False
            If RecommendedProductsHtml IsNot Nothing Then RecommendedProductsHtml.Text = ""
            Try
                KeepStoreLog.Error("carrello.aspx", "Errore BindCartRecentlyViewed", ex, HttpContext.Current)
            Catch
            End Try
        End Try
    End Sub

    Private Sub ApplyCartAddressEditorLock()
        Dim unlocked As Boolean = Not IsAddressEditModeActive()

        SetControlEnabled(btContinua, unlocked)
        SetControlEnabled(btAggiorna, unlocked)
        SetControlEnabled(btSvuota, unlocked)
        SetControlEnabled(btCompleta, unlocked)
        SetControlEnabled(TB_BuonoSconto, unlocked)
        SetControlEnabled(BT_ApplicaBuonoSconto, unlocked)
        SetControlEnabled(LB_CancelBuonoSconto, unlocked)
        SetControlEnabled(LstScegliIndirizzo, unlocked)
        SetControlEnabled(btnCartAddressAdd, unlocked)
        SetControlEnabled(btnCartAddressEdit, unlocked)
        SetControlEnabled(gvVettoriPromo, unlocked)
        SetControlEnabled(gvVettori, unlocked)
        SetControlEnabled(cbAssicurazione, unlocked)
        SetControlEnabled(gvPagamento, unlocked)
        SetControlEnabled(btnVaiConfermaOrdine, unlocked)
        SetControlEnabled(btInviaOrdine, unlocked)
        SetControlEnabled(btSalvaPreventivo, unlocked)
        If open1 IsNot Nothing Then
            open1.Visible = unlocked
            open1.Attributes("aria-disabled") = If(unlocked, "false", "true")
        End If
        ApplyCartLineItemLock(unlocked)
        ApplyCheckoutStepperNavigation()
        SyncCouponUiState()
    End Sub

    Private Function IsAddressEditorActionAllowed(ByVal sender As Object) As Boolean
        If Not GuardCartSessionForSensitiveAction() Then Return False
        If Not IsAddressEditModeActive() Then Return True
        If sender Is btnCartAddressSave OrElse sender Is btnCartAddressCancel OrElse sender Is tbCartCapA OrElse sender Is ddlCartCittaA Then Return True

        SetCartAddressEditorMessage(CartEditorLockMessage, True)
        ConfigureCartAddressEditor()
        ApplyCheckoutStepperNavigation()
        Return False
    End Function

    Private Sub ApplyCartLineItemLock(ByVal unlocked As Boolean)
        ApplyRepeaterItemLock(Repeater1, unlocked)
        ApplyRepeaterItemLock(gvArticoliGratis, unlocked)
    End Sub

    Private Sub ApplyRepeaterItemLock(ByVal repeater As Repeater, ByVal unlocked As Boolean)
        If repeater Is Nothing Then Return
        For Each item As RepeaterItem In repeater.Items
            If item.ItemType <> ListItemType.Item AndAlso item.ItemType <> ListItemType.AlternatingItem Then Continue For
            SetQuantityWrapLocked(TryCast(item.FindControl("qtyWrap"), HtmlGenericControl), Not unlocked)
            SetControlEnabled(TryCast(item.FindControl("tbQta"), WebControl), unlocked)
            SetControlEnabled(TryCast(item.FindControl("LB_Aggiorna"), WebControl), unlocked)
            SetControlEnabled(TryCast(item.FindControl("LB_Delete"), WebControl), unlocked)
        Next
    End Sub

    Private Sub SetQuantityWrapLocked(ByVal wrap As HtmlGenericControl, ByVal locked As Boolean)
        If wrap Is Nothing Then Return

        Dim css As String = If(wrap.Attributes("class"), "")
        css = css.Replace(" ks-qty-locked", "")
        If locked Then css &= " ks-qty-locked"
        wrap.Attributes("class") = css.Trim()
        wrap.Attributes("aria-disabled") = If(locked, "true", "false")
        wrap.Attributes("data-ks-qty-locked") = If(locked, "true", "false")
    End Sub

    Private Sub SetCartMainWrapHidden(ByVal hidden As Boolean)
        If CartItemsWrap Is Nothing Then Return

        Dim css As String = If(CartItemsWrap.Attributes("class"), "")
        css = css.Replace(" d-none", "")
        If hidden Then css &= " d-none"
        CartItemsWrap.Attributes("class") = css.Trim()
    End Sub

    Private Function CheckoutStepIsConfirm() As Boolean
        Return String.Equals(Convert.ToString(Session(SessCheckoutStep)), "confirm", StringComparison.Ordinal)
    End Function

    Private Sub ApplyCheckoutStepUi()
        If IsCartEmptyState() Then
            SetCheckoutStep("cart")
            If tOrdine IsNot Nothing Then tOrdine.Visible = False
            SetCartMainWrapHidden(True)
            If CartSummaryColumn IsNot Nothing Then CartSummaryColumn.Visible = False
            If pnlCheckoutConfirm IsNot Nothing Then pnlCheckoutConfirm.Visible = False
            ApplyCheckoutStepperNavigation()
            Return
        End If

        If tOrdine Is Nothing OrElse Not tOrdine.Visible Then
            SetCheckoutStep("cart")
            SetCartMainWrapHidden(False)
            If CartSummaryColumn IsNot Nothing Then CartSummaryColumn.Visible = True
            If pnlCheckoutConfirm IsNot Nothing Then pnlCheckoutConfirm.Visible = False
            ApplyCheckoutStepperNavigation()
            Return
        End If

        Dim isConfirm As Boolean = CheckoutStepIsConfirm()
        SetCartMainWrapHidden(True)
        If CartSummaryColumn IsNot Nothing Then CartSummaryColumn.Visible = False
        If pnlCheckoutConfirm IsNot Nothing Then pnlCheckoutConfirm.Visible = isConfirm
        If pSpedizione IsNot Nothing Then pSpedizione.Visible = Not isConfirm
        If pAssicurazione IsNot Nothing Then pAssicurazione.Visible = Not isConfirm
        If pPagamento IsNot Nothing Then pPagamento.Visible = Not isConfirm
        If PnlFatturazione IsNot Nothing Then PnlFatturazione.Visible = Not isConfirm
        If PnlSpedizione IsNot Nothing Then PnlSpedizione.Visible = Not isConfirm
        If Panel_Note IsNot Nothing Then Panel_Note.Visible = Not isConfirm
        If btnVaiConfermaOrdine IsNot Nothing Then btnVaiConfermaOrdine.Visible = Not isConfirm
        If btInviaOrdine IsNot Nothing Then btInviaOrdine.Visible = isConfirm
        If btSalvaPreventivo IsNot Nothing Then btSalvaPreventivo.Visible = False

        If isConfirm Then BindCheckoutConfirmSummary()
        ApplyCheckoutStepperNavigation()
    End Sub

    Private Sub ApplyCheckoutStepperNavigation()
        Dim checkoutVisible As Boolean = tOrdine IsNot Nothing AndAlso tOrdine.Visible
        Dim isConfirm As Boolean = checkoutVisible AndAlso CheckoutStepIsConfirm()
        Dim editorUnlocked As Boolean = Not IsAddressEditModeActive()

        ConfigureCheckoutStepLink(lnkCheckoutStep1, 1, Not checkoutVisible, checkoutVisible AndAlso editorUnlocked)
        ConfigureCheckoutStepLink(lnkCheckoutStep2, 2, checkoutVisible AndAlso Not isConfirm, checkoutVisible AndAlso isConfirm AndAlso editorUnlocked)
        ConfigureCheckoutStepLink(lnkCheckoutStep3, 3, isConfirm, checkoutVisible AndAlso Not isConfirm AndAlso editorUnlocked)
    End Sub

    Private Sub ConfigureCheckoutStepLink(ByVal link As LinkButton, ByVal stepNumber As Integer, ByVal isCurrent As Boolean, ByVal isInteractive As Boolean)
        If link Is Nothing Then Return

        Dim css As String = CheckoutStepTextClass(stepNumber) & " ks-checkout-step-link"
        If Not isInteractive Then css &= " ks-checkout-step-disabled"

        link.CssClass = css.Trim()
        link.Enabled = isInteractive
        link.Attributes("aria-disabled") = If(isInteractive, "false", "true")
        link.Attributes.Remove("aria-current")
        If isCurrent Then link.Attributes("aria-current") = "step"
    End Sub

    Private Function LabelText(ByVal label As Label) As String
        If label Is Nothing Then Return ""
        Return label.Text.Trim()
    End Function

    Private Function GetSelectedGridDescription(ByVal grid As GridView) As String
        If grid Is Nothing Then Return ""
        For Each row As GridViewRow In grid.Rows
            If row.RowType <> DataControlRowType.DataRow Then Continue For
            For Each cell As TableCell In row.Cells
                Dim text As String = cell.Text.Replace("&nbsp;", "").Trim()
                If text <> "" AndAlso Not text.StartsWith("<", StringComparison.Ordinal) Then Return text
            Next
        Next
        Return ""
    End Function

    Private Sub BindCheckoutConfirmSummary()
        If lblConfirmBillingName IsNot Nothing Then lblConfirmBillingName.Text = LabelText(lblTab_RagioneSociale) & " " & LabelText(lblTab_Nome)
        If lblConfirmBillingAddress IsNot Nothing Then lblConfirmBillingAddress.Text = (LabelText(lblTab_Indirizzo) & " - " & LabelText(lblTab_Cap) & " " & LabelText(lblTab_Citta) & " " & LabelText(lblTab_Provincia)).Trim()
        If lblConfirmShippingName IsNot Nothing Then lblConfirmShippingName.Text = LabelText(lblTab_RagioneSocialeSpedizione) & " " & LabelText(lblTab_NomeSpedizione)
        If lblConfirmShippingAddress IsNot Nothing Then lblConfirmShippingAddress.Text = (LabelText(lblTab_IndirizzoSpedizione) & " - " & LabelText(lblTab_CapSpedizione) & " " & LabelText(lblTab_CittaSpedizione) & " " & LabelText(lblTab_ProvinciaSpedizione)).Trim()
        If lblConfirmShippingMethod IsNot Nothing Then lblConfirmShippingMethod.Text = If(tbVettoriId IsNot Nothing AndAlso CleanCartAddressInput(tbVettoriId.Text) <> "", "Metodo selezionato", "Da selezionare")
        If lblConfirmPaymentMethod IsNot Nothing Then lblConfirmPaymentMethod.Text = If(tbPagamenti IsNot Nothing AndAlso CleanCartAddressInput(tbPagamenti.Text) <> "", "Pagamento selezionato", "Da selezionare")
        If lblConfirmNotes IsNot Nothing Then lblConfirmNotes.Text = If(txtNoteSpedizione IsNot Nothing AndAlso CleanCartAddressInput(txtNoteSpedizione.Text) <> "", Server.HtmlEncode(CleanCartAddressInput(txtNoteSpedizione.Text)), "Nessuna nota")
        If lblConfirmTotal IsNot Nothing Then lblConfirmTotal.Text = If(lblTotale IsNot Nothing, lblTotale.Text, "")
    End Sub

    Private Function ValidateCheckoutBeforeConfirm() As Boolean
        If GetLoginIdSafe(0) <= 0 Then
            Session.Item("StavonelCarrello") = 1
            SafeRedirectLocal("/carrello.aspx?loginrequired=1#ksCartLoginRequired")
            Return False
        End If

        If GetCartAddressEditorOpen() Then
            SetCartAddressEditorMessage(CartEditorLockMessage, True)
            Return False
        End If

        ApplyCurrentShippingAddress()
        If IsBlankLabel(lblTab_CapSpedizione) OrElse IsBlankLabel(lblTab_CittaSpedizione) OrElse IsBlankLabel(lblTab_ProvinciaSpedizione) Then
            SetAddressSelectionMessage("Completa un indirizzo di spedizione valido prima di rivedere l'ordine.")
            Return False
        End If

        If tbVettoriId IsNot Nothing AndAlso CleanCartAddressInput(tbVettoriId.Text) = "" Then
            SetAddressSelectionMessage("Seleziona un metodo di spedizione prima di rivedere l'ordine.")
            Return False
        End If

        If tbPagamenti IsNot Nothing AndAlso CleanCartAddressInput(tbPagamenti.Text) = "" Then
            SetAddressSelectionMessage("Seleziona un metodo di pagamento prima di rivedere l'ordine.")
            Return False
        End If

        If Not ValidateOrderNotesLength() Then Return False

        Return True
    End Function

    Private Function LoadAlternativeAddressRow(ByVal utentiId As Integer, ByVal addressId As Integer) As DataRow
        If utentiId <= 0 OrElse addressId <= 0 Then Return Nothing

        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand("SELECT Id, RagioneSocialeA, NomeA, IndirizzoA, CapA, CittaA, ProvinciaA, Zona, TelefonoA, CellulareA, FaxA, Note, NazioneA, Predefinito FROM utentiindirizzi WHERE Id=@Id AND UtenteId=@UtentiId LIMIT 1", conn)
                cmd.Parameters.AddWithValue("@Id", addressId)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                Using adp As New MySqlDataAdapter(cmd)
                    Dim dt As New DataTable()
                    adp.Fill(dt)
                    If dt.Rows.Count = 0 Then Return Nothing
                    Return dt.Rows(0)
                End Using
            End Using
        End Using
    End Function

    Private Sub FillCartAddressEditor(ByVal row As DataRow)
        If row Is Nothing Then Return
        tbCartRagioneSocialeA.Text = DbText(row("RagioneSocialeA"))
        tbCartNomeA.Text = DbText(row("NomeA"))
        tbCartIndirizzoA.Text = DbText(row("IndirizzoA"))
        tbCartCapA.Text = DbText(row("CapA"))
        tbCartCittaA.Text = ""
        tbCartProvinciaA.Text = ""
        tbCartZona.Text = DbText(row("Zona"))
        tbCartTelefonoA.Text = DbText(row("TelefonoA"))
        tbCartCellulareA.Text = DbText(row("CellulareA"))
        tbCartFaxA.Text = DbText(row("FaxA"))
        tbCartNote.Text = DbText(row("Note"))
        tbCartNazioneA.Text = If(DbText(row("NazioneA")) = "", "IT", DbText(row("NazioneA")))
        chkCartAddressUseForOrder.Checked = True
        Dim pref As Integer = 0
        Integer.TryParse(DbText(row("Predefinito")), pref)
        chkCartAddressSetDefault.Checked = (pref = 1)
        ResolveCartAddressCap(GetCartCityOptionKey(DbText(row("CittaA")), DbText(row("ProvinciaA"))))
    End Sub

    Private Sub AddCartAddressParameters(ByVal cmd As MySqlCommand, ByVal utentiId As Integer, ByVal includeDefault As Boolean, ByVal setDefault As Boolean)
        cmd.Parameters.AddWithValue("@UtentiId", utentiId)
        cmd.Parameters.AddWithValue("@RagioneSocialeA", CleanCartAddressInput(tbCartRagioneSocialeA.Text))
        cmd.Parameters.AddWithValue("@NomeA", CleanCartAddressInput(tbCartNomeA.Text))
        cmd.Parameters.AddWithValue("@IndirizzoA", CleanCartAddressInput(tbCartIndirizzoA.Text))
        cmd.Parameters.AddWithValue("@CapA", CleanCartAddressInput(tbCartCapA.Text))
        cmd.Parameters.AddWithValue("@CittaA", CleanCartAddressInput(tbCartCittaA.Text))
        cmd.Parameters.AddWithValue("@ProvinciaA", CleanCartAddressInput(tbCartProvinciaA.Text))
        cmd.Parameters.AddWithValue("@Zona", CleanCartAddressInput(tbCartZona.Text))
        cmd.Parameters.AddWithValue("@TelefonoA", CleanCartAddressInput(tbCartTelefonoA.Text))
        cmd.Parameters.AddWithValue("@CellulareA", CleanCartAddressInput(tbCartCellulareA.Text))
        cmd.Parameters.AddWithValue("@FaxA", CleanCartAddressInput(tbCartFaxA.Text))
        cmd.Parameters.AddWithValue("@Note", CleanCartAddressInput(tbCartNote.Text))
        cmd.Parameters.AddWithValue("@NazioneA", CleanCartAddressInput(tbCartNazioneA.Text))
        If includeDefault Then cmd.Parameters.AddWithValue("@Predefinito", If(setDefault, 1, 0))
    End Sub

    Private Function SaveCartAddressInline(ByVal utentiId As Integer, ByVal mode As String, ByVal addressId As Integer, ByVal setDefault As Boolean) As Integer
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            Using tr As MySqlTransaction = conn.BeginTransaction()
                Try
                    If mode = "edit" AndAlso Not ShippingAddressBelongsToCurrentUser(addressId) Then
                        tr.Rollback()
                        Return 0
                    End If

                    If setDefault Then
                        Using resetCmd As New MySqlCommand("UPDATE utentiindirizzi SET Predefinito=0 WHERE UtenteId=@UtentiId", conn, tr)
                            resetCmd.Parameters.AddWithValue("@UtentiId", utentiId)
                            resetCmd.ExecuteNonQuery()
                        End Using
                    End If

                    If mode = "edit" Then
                        Dim sql As String =
                            "UPDATE utentiindirizzi SET " &
                            "RagioneSocialeA=@RagioneSocialeA, NomeA=@NomeA, IndirizzoA=@IndirizzoA, CapA=@CapA, CittaA=@CittaA, ProvinciaA=@ProvinciaA, " &
                            "Zona=@Zona, TelefonoA=@TelefonoA, CellulareA=@CellulareA, FaxA=@FaxA, Note=@Note, NazioneA=@NazioneA"
                        If setDefault Then sql &= ", Predefinito=@Predefinito"
                        sql &= " WHERE Id=@Id AND UtenteId=@UtentiId"

                        Using cmd As New MySqlCommand(sql, conn, tr)
                            AddCartAddressParameters(cmd, utentiId, setDefault, setDefault)
                            cmd.Parameters.AddWithValue("@Id", addressId)
                            If cmd.ExecuteNonQuery() <> 1 Then
                                tr.Rollback()
                                Return 0
                            End If
                        End Using
                        tr.Commit()
                        Return addressId
                    End If

                    Using cmd As New MySqlCommand("INSERT INTO utentiindirizzi (UtenteId, RagioneSocialeA, NomeA, IndirizzoA, CapA, CittaA, ProvinciaA, Zona, TelefonoA, CellulareA, FaxA, Note, NazioneA, Predefinito) VALUES (@UtentiId, @RagioneSocialeA, @NomeA, @IndirizzoA, @CapA, @CittaA, @ProvinciaA, @Zona, @TelefonoA, @CellulareA, @FaxA, @Note, @NazioneA, @Predefinito); SELECT LAST_INSERT_ID();", conn, tr)
                        AddCartAddressParameters(cmd, utentiId, True, setDefault)
                        Dim newId As Integer = Convert.ToInt32(cmd.ExecuteScalar())
                        tr.Commit()
                        Return newId
                    End Using
                Catch
                    Try
                        tr.Rollback()
                    Catch
                    End Try
                    Throw
                End Try
            End Using
        End Using
    End Function

    Private Function IsBlankLabel(ByVal label As Label) As Boolean
        If label Is Nothing Then Return True
        Return label.Text.Trim() = ""
    End Function

    Private Sub UpdateShippingAddressQualityHint()
        If lblAddressQualityHint Is Nothing Then Return

        Dim missing As New List(Of String)
        If IsBlankLabel(lblTab_CapSpedizione) Then missing.Add("CAP")
        If IsBlankLabel(lblTab_CittaSpedizione) Then missing.Add("citta")
        If IsBlankLabel(lblTab_ProvinciaSpedizione) Then missing.Add("provincia")

        If missing.Count > 0 Then
            lblAddressQualityHint.Text = "Suggerimento: completa " & String.Join(", ", missing.ToArray()) & " prima di confermare l'ordine."
        ElseIf IsBlankLabel(lblTab_TelSpedizione) Then
            lblAddressQualityHint.Text = "Indirizzo quasi pronto: aggiungere un telefono o cellulare aiuta il corriere in caso di consegna."
        Else
            lblAddressQualityHint.Text = "Pronto per il checkout: i dati principali dell'indirizzo sono presenti."
        End If
    End Sub

    Private Function GetLoginIdSafe(Optional ByVal defaultVal As Integer = 0) As Integer
    Dim id As Integer = GetSessionInt(SessLoginId_A, 0)
    If id = 0 Then id = GetSessionInt(SessLoginId_B, 0)

    Session(SessLoginId_A) = id
    Return If(id > 0, id, defaultVal)
    End Function

    Private Function GetListinoSafe(Optional ByVal defaultVal As Integer = 0) As Integer
    Dim l As Integer = GetSessionInt(SessListino_A, 0)
    If l = 0 Then l = GetSessionInt(SessListino_B, 0)

    If l > 0 Then
        Session(SessListino_A) = l
    End If

    Return If(l > 0, l, defaultVal)
    End Function

    Private Function GetListinoSafeString(Optional ByVal defaultVal As String = "") As String
    Dim o As Object = Session(SessListino_A)
    If o Is Nothing OrElse o.ToString().Trim() = "" Then o = Session(SessListino_B)

    Dim s As String = If(o, "").ToString().Trim()
    If s <> "" Then Session(SessListino_A) = s

    If s = "" Then s = defaultVal
    Return s
    End Function

    Private Class PaymentPolicyInfo
        Public OnLine As Integer
        Public ConfermaOrdinePrimaPagamento As Integer
        Public PermettiPagamentoSuccessivo As Integer
        Public InviaEmailOrdinePrimaPagamento As Integer

        Public Sub New()
            OnLine = 0
            ConfermaOrdinePrimaPagamento = 1
            PermettiPagamentoSuccessivo = 1
            InviaEmailOrdinePrimaPagamento = 1
        End Sub
    End Class

    Private Function DefaultPaymentPolicyInfo() As PaymentPolicyInfo
        Return New PaymentPolicyInfo()
    End Function

    Private Function ReadPaymentPolicyInfo(ByVal pagamentoId As Integer) As PaymentPolicyInfo
        Dim info As PaymentPolicyInfo = DefaultPaymentPolicyInfo()
        If pagamentoId <= 0 Then Return info

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT COALESCE(OnLine,0) AS OnLine, COALESCE(ConfermaOrdinePrimaPagamento,1) AS ConfermaOrdinePrimaPagamento, COALESCE(PermettiPagamentoSuccessivo,1) AS PermettiPagamentoSuccessivo, COALESCE(InviaEmailOrdinePrimaPagamento,1) AS InviaEmailOrdinePrimaPagamento FROM pagamentitipo WHERE id=@id LIMIT 1", conn)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = pagamentoId

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            info.OnLine = SafeIntFromDb(dr("OnLine"), 0)
                            info.ConfermaOrdinePrimaPagamento = SafeIntFromDb(dr("ConfermaOrdinePrimaPagamento"), 1)
                            info.PermettiPagamentoSuccessivo = SafeIntFromDb(dr("PermettiPagamentoSuccessivo"), 1)
                            info.InviaEmailOrdinePrimaPagamento = SafeIntFromDb(dr("InviaEmailOrdinePrimaPagamento"), 1)
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            LogEx(ex, "ReadPaymentPolicyInfo")
        End Try

        Return info
    End Function

    Private Function SafeIntFromDb(ByVal value As Object, ByVal defaultValue As Integer) As Integer
        Try
            If value Is Nothing OrElse value Is DBNull.Value Then Return defaultValue
            Dim result As Integer
            If Integer.TryParse(value.ToString(), result) Then Return result
        Catch
        End Try
        Return defaultValue
    End Function

    Private Sub StorePaymentPolicySession(ByVal pagamentoId As Integer)
        Dim info As PaymentPolicyInfo = ReadPaymentPolicyInfo(pagamentoId)
        Session("Ordine_Pagamento_OnLine") = info.OnLine
        Session("Ordine_ConfermaOrdinePrimaPagamento") = info.ConfermaOrdinePrimaPagamento
        Session("Ordine_PermettiPagamentoSuccessivo") = info.PermettiPagamentoSuccessivo
        Session("Ordine_InviaEmailOrdinePrimaPagamento") = info.InviaEmailOrdinePrimaPagamento
    End Sub

    Private Sub LogEx(ByVal ex As Exception, Optional ByVal context As String = "", Optional ByVal sql As String = "")
    Try
        Dim msg As String = "carrello.aspx.vb"
        If context <> "" Then msg &= " [" & context & "]"
        If sql <> "" Then msg &= " SQL=" & sql
        System.Diagnostics.Trace.TraceError(msg & " - " & ex.ToString())
    Catch
    End Try
    End Sub


    Private Function ReadCartRowFromItem(ByVal item As RepeaterItem) As CartRowInfo
    Dim r As New CartRowInfo

    Dim tbQta As TextBox = TryCast(item.FindControl("tbQta"), TextBox)
    Dim tbID As TextBox = TryCast(item.FindControl("tbID"), TextBox)
    Dim tbArtID As TextBox = TryCast(item.FindControl("tbArtID"), TextBox)
    Dim tbTCID As TextBox = TryCast(item.FindControl("tbTCID"), TextBox)

    r.Id = SafeInt(If(tbID IsNot Nothing, tbID.Text, 0), 0)
    r.ArtId = SafeInt(If(tbArtID IsNot Nothing, tbArtID.Text, 0), 0)
    r.TCId = SafeInt(If(tbTCID IsNot Nothing, tbTCID.Text, -1), -1)

    Dim q As Integer = SafeInt(If(tbQta IsNot Nothing, tbQta.Text, 0), 0)
    If q < 0 Then q = 0
    r.Qnt = CLng(q)

    Return r
    End Function

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If IsLoginRequiredCartRequest() Then
            ApplyLoginRequiredAnonymousFastPath()
            Return
        End If

        ' Standard carrello: 30 minuti, allineato a web.config.
        Session.Timeout = 30
        If IsLikelyExpiredCartSession() Then
            RedirectToCartSessionExpiredLogin()
            Return
        End If
        If Session("DESTINAZIONEALTERNATIVA") Is Nothing Then
            Session("DESTINAZIONEALTERNATIVA") = 0
        End If

    Me.MaintainScrollPositionOnPostBack = True

    IvaTipo = GetSessionInt("IvaTipo", 0)
    DispoTipo = GetSessionInt("DispoTipo", 0)
    DispoMinima = GetSessionInt("DispoMinima", 0)

    Dim loginId As Integer = GetSessionInt("LoginId", 0)

    ' Nascondo i pannelli dei dati anagrafici quando non sono loggato
    Dim isLogged As Boolean = (loginId > 0)
    If pnlLoginRequired IsNot Nothing Then
        pnlLoginRequired.Visible = (Not isLogged AndAlso String.Equals(Request.QueryString("loginrequired"), "1", StringComparison.OrdinalIgnoreCase))
    End If

    If txtNoteSpedizione IsNot Nothing Then
        txtNoteSpedizione.MaxLength = OrderNotesMaxLength
    End If

    Me.pnlFatturazione.Visible = isLogged
    Me.PnlSpedizione.Visible = isLogged
    Me.PnlDestinazione.Visible = False
    Me.Panel_Note.Visible = isLogged

    If IsLoginRequiredAnonymousFastPath(loginId) Then
        ApplyLoginRequiredAnonymousFastPath()
        Return
    End If

    If Not Page.IsPostBack Then
        Aggiorna_Prezzi_Carrello()
    End If

    ' Il carrello deve essere bindato anche per utenti anonimi.
    ConfigureCartDataSources()

    ' I dati anagrafici restano invece riservati all'utente loggato.
    If isLogged Then
        Dim utentiId As Integer = GetUtentiIdSafe(0)
        If utentiId > 0 Then
            FillTableInfo()
        End If
    End If
    If String.Equals(Request.QueryString("addresserror"), "1", StringComparison.OrdinalIgnoreCase) Then
        SetCheckoutStep("checkout")
        If tOrdine IsNot Nothing Then tOrdine.Visible = True
        SetAddressSelectionMessage(InvalidShippingAddressMessage, True)
        ApplyCheckoutStepUi()
    ElseIf String.Equals(Request.QueryString("noteerror"), "1", StringComparison.OrdinalIgnoreCase) Then
        SetCheckoutStep("checkout")
        If tOrdine IsNot Nothing Then tOrdine.Visible = True
        SetAddressSelectionMessage(OrderNotesLimitMessage)
        ApplyCheckoutStepUi()
    ElseIf String.Equals(Request.QueryString("pricechanged"), "1", StringComparison.OrdinalIgnoreCase) Then
        SetCheckoutStep("confirm")
        If tOrdine IsNot Nothing Then tOrdine.Visible = True
        ApplyCheckoutStepUi()
    End If
    ShowCartPriceRevalidationMessage()
    StabilizeCartAddressEditUi()
    End Sub

    Private Sub ConfigureCartDataSources()
        Dim LoginId As Integer = GetSessionInt("LoginId", 0)
        Dim SessionID As String = If(Me.Session IsNot Nothing, Me.Session.SessionID, "")
        Dim WhereUserId As String

        Dim Sqlstring As String = "SELECT vcarrello.*, articoli.SpedizioneGratis_Listini, articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine, taglie.descrizione as taglia, colori.descrizione as colore FROM vcarrello"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN articoli ON vcarrello.ArticoliId = articoli.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN articoli_tagliecolori ON vcarrello.TCid = articoli_tagliecolori.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id"
        Sqlstring = Sqlstring + " LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"

        If LoginId = 0 Then
            WhereUserId = "(SessionId=@SessionId)"
        Else
            WhereUserId = "(LoginId=@LoginId)"
        End If

        Me.sdsArticoli.SelectCommand = Sqlstring & " WHERE (" & WhereUserId & " ) ORDER BY id"
        sdsArticoli.SelectParameters.Clear()
        sdsArticoli.SelectParameters.Add("@SessionId", SessionID)
        sdsArticoli.SelectParameters.Add("@LoginId", LoginId.ToString())

        Me.sdsArticoli_Spedizione_Gratis.SelectCommand = Sqlstring & " WHERE " & WhereUserId & " AND (articoli.SpedizioneGratis_Listini != '') AND (SpedizioneGratis_Listini LIKE CONCAT('%', @listino, ';%')) AND ((SpedizioneGratis_Data_Inizio <= CURDATE()) AND (SpedizioneGratis_Data_Fine >= CURDATE() OR SpedizioneGratis_Data_Fine Is NULL)) ORDER BY id"
        sdsArticoli_Spedizione_Gratis.SelectParameters.Clear()
        sdsArticoli_Spedizione_Gratis.SelectParameters.Add("@SessionId", SessionID)
        sdsArticoli_Spedizione_Gratis.SelectParameters.Add("@LoginId", LoginId.ToString())
        sdsArticoli_Spedizione_Gratis.SelectParameters.Add("@listino", GetListinoSafeString())

        IvaTipo = GetSessionInt("IvaTipo", 0)
        If IvaTipo = 1 Then
            Me.lblPrezzi.Text = "*Prezzi Iva Esclusa"
        ElseIf IvaTipo = 2 Then
            If SafeDbl(Session("Iva_Utente"), -1) > -1 Then
                Me.lblPrezzi.Text = "*Prezzi Iva Inclusa - (IVA Utente al " & Convert.ToString(Session("Iva_Utente")) & "%)"
            Else
                Me.lblPrezzi.Text = "*Prezzi Iva Inclusa"
            End If
        End If
    End Sub

    ' forgotten code?

    ' preleva_prezzi_articoli() hardening Session/parametri
    Sub preleva_prezzi_articoli()

    Dim LoginId As Integer = GetSessionInt("LoginId", 0)

    Dim ivaUtente As Double = SafeDbl(Session("Iva_Utente"), -1)
    Dim ivaRCUtente As Double = SafeDbl(Session("IvaReverseCharge_Utente"), -1)

    Dim listino As Integer = GetSessionInt("Listino", 0)

    Dim params As New Dictionary(Of String, String)
    params.Add("@IvaUtente", ivaUtente.ToString(CultureInfo.InvariantCulture))
    params.Add("@IvaRCUtente", ivaRCUtente.ToString(CultureInfo.InvariantCulture))
    params.Add("@listino", listino.ToString())

    Dim loginOrSessionId As String = ""
    If LoginId = 0 Then
        loginOrSessionId = "SessionID=@SessionId"
        params.Add("@SessionId", If(Me.Session IsNot Nothing, Me.Session.SessionID, ""))
    Else
        loginOrSessionId = "LoginId=@LoginId"
        params.Add("@LoginId", LoginId.ToString())
    End If

    Dim innerJoin As String =
        " INNER JOIN (" &
        "   SELECT carrello.id AS idCarrello, carrello.ArticoliId, vsuperarticoli.id, vsuperarticoli.Nlistino, vsuperarticoli.InOfferta, vsuperarticoli.DescrizioneIvaRC, " &
        "   IF((InOfferta=1) AND ((OfferteDataInizio<=CURDATE()) AND (OfferteDataFine>=CURDATE())),vsuperarticoli.PrezzoPromo,vsuperarticoli.Prezzo) AS new_Prezzo, " & _
        "   IF((InOfferta=1) AND ((OfferteDataInizio<=CURDATE()) AND (OfferteDataFine>=CURDATE())),IF(@IvaUtente>-1,((vsuperarticoli.PrezzoPromo)*((@IvaUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato),IF(@IvaUtente>-1,((vsuperarticoli.Prezzo)*((@IvaUtente/100)+1)),vsuperarticoli.PrezzoIvato)) AS new_PrezzoIvato, " & _
        "   IF((InOfferta=1) AND ((OfferteDataInizio<=CURDATE()) AND (OfferteDataFine>=CURDATE())),IF(@IvaRCUtente>-1,((vsuperarticoli.PrezzoPromo)*((@IvaRCUtente/100)+1)),vsuperarticoli.PrezzoPromoIvato),IF(@IvaRCUtente>-1,((vsuperarticoli.Prezzo)*((@IvaRCUtente/100)+1)),-1)) AS new_PrezzoRC " & _
        "   FROM carrello INNER JOIN vsuperarticoli ON (carrello.ArticoliId=vsuperarticoli.id) " &
        "   WHERE (vsuperarticoli.Nlistino=@listino) AND " & loginOrSessionId &
        " ) AS t1 ON t1.idCarrello=carrello.id "

    ExecuteUpdate("carrello " & innerJoin,
                  "carrello.Prezzo=new_Prezzo, carrello.PrezzoIvato=new_PrezzoIvato, carrello.ValoreIvaRC=new_PrezzoRC, carrello.DescrizioneIvaRC=DescrizioneIvaRC",
                  "",
                  params)

    End Sub

	
    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        If _cartSessionExpiredRedirectIssued Then Return
        Me.Title = Me.Title & " - Il tuo Carrello"

        If _cartLoginRequiredFastPathActive Then
            ApplyLoginRequiredAnonymousFastPath()
            Return
        End If
		
        Dim LoginId As Integer = GetSessionInt("LoginId", 0)

		'cancella_campi_destinazione_alternativa_o_indirizzo_spedizione()
        ConfigureCartDataSources()

        'Nascondo i pannelli dei dati anagrafici quando non sono loggato
        If LoginId > 0 Then
            Me.pnlFatturazione.Visible = True
			Me.PnlSpedizione.Visible = True
			Me.PnlDestinazione.Visible = False
            Me.Panel_Note.Visible = True
        Else
            Me.pnlFatturazione.Visible = False
			Me.PnlSpedizione.Visible = False
            Me.PnlDestinazione.Visible = False
            Me.Panel_Note.Visible = False
        End If
        StabilizeCartAddressEditUi()
		
		
		REM Me.Page.ClientScript.RegisterClientScriptBlock(Me.GetType, "prova", "<script type='text/javascript'>document.body.onload=function(){alert('" & Me.sdsArticoli.SelectCommand.Replace("'", """").ToUpper & "')}</script>")
    End Sub

    Protected Sub Repeater1_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Repeater1.PreRender
        If _cartLoginRequiredFastPathActive Then Return

        Dim i As Integer

        'Carrello Normale
        For i = 0 To Repeater1.items.Count - 1
            Dim img As Image
            Dim dispo As Label
            Dim arrivo As Label
            Dim importo As Label
            Dim importoIvato As Label
            Dim peso As Label
            Dim tbQta As TextBox

            tbQta = Repeater1.items(i).FindControl("tbQta")
            img = Repeater1.items(i).FindControl("imgDispo")
            dispo = Repeater1.items(i).FindControl("lblDispo")
            arrivo = Repeater1.items(i).FindControl("lblArrivo")
            importo = Repeater1.items(i).FindControl("lblImporto")
            importoIvato = Repeater1.items(i).FindControl("lblImportoIvato")
            peso = Repeater1.items(i).FindControl("lblPeso")

        Dim qtaRiga As Integer = SafeIntFromText(tbQta.Text, 0)
        qta = qta + qtaRiga

    If qtaRiga > 0 Then

    If IvaTipo = 1 Then
        importo.Visible = True
        importoIvato.Visible = False
        Repeater1.items(i).FindControl("lblprezzo").Visible = True
        Repeater1.items(i).FindControl("lblprezzoivato").Visible = False

        TotaleMerce += SafeDblFromText(importo.Text, 0)
    Else
        importo.Visible = False
        importoIvato.Visible = True
        Repeater1.items(i).FindControl("lblprezzo").Visible = False
        Repeater1.items(i).FindControl("lblprezzoivato").Visible = True

        TotaleMerce += SafeDblFromText(importoIvato.Text, 0)
    End If

    Session("TotaleMerce") = TotaleMerce

    imponibile = imponibile + SafeDblFromText(importo.Text, 0)
    calcolo_iva = calcolo_iva + (SafeDblFromText(importoIvato.Text, 0) - SafeDblFromText(importo.Text, 0))
    totale = totale + SafeDblFromText(importoIvato.Text, 0)

    If peso IsNot Nothing AndAlso peso.Text <> "" Then
        pesoTotale = pesoTotale + SafeDblFromText(peso.Text, 0)
    End If

    If DispoTipo = 1 Then
        Dim dispoDouble As Double = 0
        Dim dispoTxt As String = If(dispo.Text, "").Replace("âˆ’", "-").Replace(">", "").Trim()
        Double.TryParse(dispoTxt.Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, dispoDouble)

        If dispoDouble > DispoMinima Then
            img.ImageUrl = "~/images/verde.gif"
            img.AlternateText = "Disponibile"
        ElseIf dispoDouble > 0 Then
            img.ImageUrl = "~/images/giallo.gif"
            img.AlternateText = "DisponibilitÃ  Scarsa"
        Else
            Dim arrivoDouble As Double = 0
            Double.TryParse(If(arrivo.Text, "0").Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, arrivoDouble)

            If arrivoDouble > 0 Then
                img.ImageUrl = "~/images/azzurro.gif"
                img.AlternateText = "In Arrivo"
            Else
                img.ImageUrl = "~/images/rosso.gif"
                img.AlternateText = "Non Disponibile"
            End If
        End If

    ElseIf DispoTipo = 2 Then
        img.Visible = False
        dispo.Visible = True
    End If
    End If
        Next

        ' ------------------------ CONTEGGIO DEI TOTALI DA PAGARE -----------------------
        'Salvataggio per l'SQLData relativo ai vettori in PROMO
        Session.Item("Imponibile") = imponibile - imponibile_gratis

        Me.lblImponibile.Text = FormatCurrencyIt(imponibile)
        Me.lblCartSubtotalOnly.Text = FormatCurrencyIt(TotaleMerce)
        'Session("Calcolo_Iva") = calcolo_iva
        Me.tbPeso.Text = pesoTotale

        Me.tbTotale.Text = totale
        ' --------------------------------------------------------------------------------

        'ABILITA E DISABILITA I PULSANTI
        ArticoliCarrello(qta)
        ApplyRepeaterItemLock(Repeater1, Not IsAddressEditModeActive())

        'Me.gvVettori.DataBind()
    End Sub

    Public Sub ArticoliCarrello(ByVal numero As Integer)
        Me.lblArticoli.Text = numero
        Dim hasItems As Boolean = (numero > 0)
        _cartHasItems = hasItems
        If lblArticoli IsNot Nothing Then lblArticoli.Visible = hasItems
        If lblPresenti IsNot Nothing Then lblPresenti.Visible = hasItems
        If lblPrezzi IsNot Nothing Then lblPrezzi.Visible = hasItems
        If CartItemsWrap IsNot Nothing Then CartItemsWrap.Visible = hasItems
        If CartEmptyPanel IsNot Nothing Then CartEmptyPanel.Visible = Not hasItems
        If CartActionsWrap IsNot Nothing Then CartActionsWrap.Visible = hasItems
        If CartSummaryColumn IsNot Nothing AndAlso Not hasItems Then CartSummaryColumn.Visible = False
        If Not hasItems Then
            SetCheckoutStep("cart")
            If tOrdine IsNot Nothing Then tOrdine.Visible = False
            If pnlCheckoutConfirm IsNot Nothing Then pnlCheckoutConfirm.Visible = False
        End If
        If pnlLoginRequired IsNot Nothing AndAlso Not hasItems Then pnlLoginRequired.Visible = False
        If numero = 0 Then
            Me.lblPresenti.Text = "articoli nel carrello"
            Me.btSvuota.Visible = False
            Me.btCompleta.Visible = False
            Me.btAggiorna.Visible = True
        ElseIf numero = 1 Then
            Me.lblPresenti.Text = "articolo nel carrello"
            Me.btSvuota.Visible = True
            If (Me.gvVettoriPromo.Visible = True) Then
                Me.btCompleta.Visible = False
            Else
                Me.btCompleta.Visible = True
            End If
            Me.btAggiorna.Visible = True
        Else
            Me.lblPresenti.Text = "articoli nel carrello"
            Me.btSvuota.Visible = True
            If (Me.gvVettoriPromo.Visible = True) Then
                Me.btCompleta.Visible = False
            Else
                Me.btCompleta.Visible = True
            End If
            Me.btAggiorna.Visible = True
        End If
		if Me.Session("CanOrder") = 0 Then
			Me.btCompleta.Visible = False
			Me.canorder.Visible = True
		else
			Me.canorder.Visible = False
		End If
    End Sub

    Private Sub SendOrder()

        Try
            If Not ValidateOrderNotesLength() Then Return

            Me.Session("Ordine_TipoDoc") = 4
            Me.Session("Ordine_Documento") = "Ordine"
            Me.Session("Ordine_Pagamento") = Me.tbPagamenti.Text
            StorePaymentPolicySession(SafeIntFromDb(Me.tbPagamenti.Text, 0))
            Me.Session("Ordine_BancaSellaGestPay_ShopId") = Me.tbShopIdGestPay.Text
            Me.Session("Ordine_Vettore") = Me.tbVettoriId.Text
            Me.Session("Ordine_SpeseSped") = SafeDbl(Me.lblSpeseSped.Text, 0)
            Me.Session("Ordine_SpeseAss") = SafeDbl(Me.lblSpeseAss.Text, 0)
            Me.Session("Ordine_SpesePag") = SafeDbl(Me.lblPagamento.Text, 0)
            Me.Session("Ordine_Totale_Documento") = SafeDbl(Me.lblTotale.Text, 0)


            '// INIZIO BLOCCO BUONO SCONTO - FIX COMPILAZIONE (SendOrder)
Dim buonoImp As Double = SafeMoney(lblBuonoSconto.Text, 0)
Dim buonoIva As Double = SafeMoney(lblBuonoScontoIVA.Text, 0)
Dim buonoTot As Double = buonoImp + buonoIva

' Se buono applicato: nel markup il GridView GV_BuoniSconti esiste e contiene le descrizioni nel primo record
If buonoTot > 0 Then

    Dim desc1 As String = ""
    Dim desc2 As String = ""

    If GV_BuoniSconti IsNot Nothing AndAlso GV_BuoniSconti.Rows.Count > 0 Then
        Dim r As GridViewRow = GV_BuoniSconti.Rows(0)
        Dim l1 As Label = TryCast(r.FindControl("lbl_Descrizione1_BuonoSconto"), Label)
        Dim l2 As Label = TryCast(r.FindControl("lbl_Descrizione2_BuonoSconto"), Label)
        If l1 IsNot Nothing Then desc1 = l1.Text
        If l2 IsNot Nothing Then desc2 = l2.Text
    End If

    Me.Session("Ordine_DescrizioneBuonoSconto") =
        (desc1 & " " & desc2).Trim() &
        " per un valore di " & FormatCurrencyIt(buonoTot) &
        " Codice Applicato: " & TB_BuonoSconto.Text

            Me.Session("Ordine_TotaleBuonoSconto") = buonoTot
            Me.Session("Ordine_TotaleBuonoScontoImponibile") = buonoImp
            Me.Session("Ordine_BuonoScontoIdIva") = preleva_IdIva(GetSessionInt("Iva_Utente", -1))
            Me.Session("Ordine_BuonoScontoValoreIva") = preleva_ValoreIva(GetSessionInt("Iva_Utente", -1))
            Me.Session("Ordine_CodiceBuonoSconto") = TB_BuonoSconto.Text

            Else
            Me.Session("Ordine_DescrizioneBuonoSconto") = ""
            Me.Session("Ordine_TotaleBuonoSconto") = 0
            Me.Session("Ordine_TotaleBuonoScontoImponibile") = 0
            Me.Session("Ordine_BuonoScontoIdIva") = -1
            Me.Session("Ordine_BuonoScontoValoreIva") = 0
            Me.Session("Ordine_CodiceBuonoSconto") = ""
            End If
            Me.Session("NoteDocumento") = Me.txtNoteSpedizione.Text

            RedirectToOrdineWithQuery("C=" & HttpUtility.UrlEncode(Cookie.ToUpper()))

            'Test di controllo, relativo al buono sconto del carrello
            'Dim test As Integer = 0
            'Dim test2 As Integer = 0

            'test = test2 + Session("Ordine_DescrizioneBuonoSconto")

        Catch ex As Exception
        LogEx(ex, "SendOrder")

        End Try

    End Sub

    Protected Sub gvVettori_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles gvVettori.PreRender
        LeggiVettori()
    End Sub

    Public Sub LeggiVettori()

    Dim i As Integer
    Dim rb As Control
    Dim AsssicurazionePercentuale As Double
    Dim AssicurazioneMinimo As Double
    Dim TotAssicurazione As Double
    Dim lbl As Label
    Dim lblContrPerc As Label
    Dim lblContrFisso As Label
    Dim lblContrMinimo As Label
    Dim lblCosto As Label
    Dim sel As Boolean = False

    ' Resetto il prezzo relativo al metodo di pagamento
    lblPagamento.Text = FormatCurrencyIt(0D)

    ' Base imponibile (la Label contiene spesso il simbolo euro, quindi la leggo in modo safe)
    Dim imponibileBase As Double = SafeMoney(Me.lblImponibile.Text, 0)

    'Controllo se Esiste ed Ã¨ abilitato un Vettore PROMO
    Dim Vettore_Promo_Abilitato As Integer = 0
    For i = 0 To (Me.gvVettoriPromo.Rows.Count - 1)
        rb = TryCast(gvVettoriPromo.Rows(i).FindControl("rbSpedizione"), Control)
        If rb IsNot Nothing AndAlso RbGetEnabled(rb) = True Then
            Vettore_Promo_Abilitato = 1
            Exit For
        End If
    Next

    'Controllo se Ã¨ selezionato un vettore NORMALE
    Dim Vettore_NoNPromo_Selezionato As Integer = 0
    For i = 0 To (Me.gvVettori.Rows.Count - 1)
        rb = TryCast(gvVettori.Rows(i).FindControl("rbSpedizione"), Control)
        If rb IsNot Nothing AndAlso RbGetChecked(rb) = True Then
            Vettore_NoNPromo_Selezionato = 1
            Exit For
        End If
    Next

    If (Vettore_Promo_Abilitato = 0) Or ((Vettore_Promo_Abilitato = 1) And (Vettore_NoNPromo_Selezionato = 1)) Then

        For i = 0 To gvVettori.Rows.Count - 1

            rb = TryCast(gvVettori.Rows(i).FindControl("rbSpedizione"), Control)
            If rb IsNot Nothing AndAlso RbGetChecked(rb) Then

                sel = True

                'Spedizione
                lblCosto = TryCast(gvVettori.Rows(i).FindControl("lblCosto"), Label)
                Dim costoSped As Double = SafeMoney(If(lblCosto IsNot Nothing, lblCosto.Text, "0"), 0)
                Me.lblSpeseSped.Text = FormatCurrencyIt(costoSped)

                lbl = TryCast(gvVettori.Rows(i).FindControl("lblId"), Label)
                If lbl IsNot Nothing Then Me.tbVettoriId.Text = lbl.Text

                'Assicurazione
                lbl = TryCast(gvVettori.Rows(i).FindControl("lblAssPerc"), Label)
                AsssicurazionePercentuale = SafeDblFromText(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

                lbl = TryCast(gvVettori.Rows(i).FindControl("lblAssicurazioneMinimo"), Label)
                AssicurazioneMinimo = SafeMoney(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

                Dim imponibileValTmp As Double = SafeMoney(Me.lblImponibile.Text, 0)
                TotAssicurazione = (AsssicurazionePercentuale * imponibileValTmp) / 100

                If TotAssicurazione < AssicurazioneMinimo Then
                    TotAssicurazione = AssicurazioneMinimo
                End If
                Me.lblAssicurazione.Text = FormatCurrencyIt(TotAssicurazione)

                'Contrassegno
                lblContrPerc = TryCast(gvVettori.Rows(i).FindControl("lblContrPerc"), Label)
                lblContrFisso = TryCast(gvVettori.Rows(i).FindControl("lblContrFisso"), Label)
                lblContrMinimo = TryCast(gvVettori.Rows(i).FindControl("lblContrMinimo"), Label)

                Me.tbContrFisso.Text = If(lblContrFisso IsNot Nothing, lblContrFisso.Text, "")
                Me.tbContrPerc.Text = If(lblContrPerc IsNot Nothing, lblContrPerc.Text, "")
                Me.tbContrMinimo.Text = If(lblContrMinimo IsNot Nothing, lblContrMinimo.Text, "")

                AggiornaSpeseAssicurazione()

                If AsssicurazionePercentuale = 0 Then
                    Me.cbAssicurazione.Checked = False
                    Me.cbAssicurazione.Enabled = False
                Else
                    Me.cbAssicurazione.Enabled = True
                End If

                If SafeDblFromText(Me.tbContrPerc.Text, 0) = 0 Then
                    RitiroSede = True
                Else
                    RitiroSede = False
                End If

            End If
        Next

        If sel = False Then
            If (gvVettori.Rows.Count > 0) And (Selezionato_Vettore_Promo = 0) Then
                rb = TryCast(gvVettori.Rows(0).FindControl("rbSpedizione"), Control)
                If rb IsNot Nothing Then
                    RbSetChecked(rb, True)
                    LeggiVettori()
                    Exit Sub
                End If
            End If
        End If

    Else

        For i = 0 To Me.gvVettoriPromo.Rows.Count - 1

            rb = TryCast(gvVettoriPromo.Rows(i).FindControl("rbSpedizione"), Control)

            If rb IsNot Nothing AndAlso RbGetEnabled(rb) = True Then
                RbSetChecked(rb, True)
            End If

            If rb IsNot Nothing AndAlso RbGetChecked(rb) Then

                sel = True

                'Spedizione
                lblCosto = TryCast(gvVettoriPromo.Rows(i).FindControl("lblCosto"), Label)
                Dim costoSped As Double = SafeMoney(If(lblCosto IsNot Nothing, lblCosto.Text, "0"), 0)
                Me.lblSpeseSped.Text = FormatCurrencyIt(costoSped)

                lbl = TryCast(gvVettoriPromo.Rows(i).FindControl("lblId"), Label)
                If lbl IsNot Nothing Then Me.tbVettoriId.Text = lbl.Text

                'Assicurazione
                lbl = TryCast(gvVettoriPromo.Rows(i).FindControl("lblAssPerc"), Label)
                AsssicurazionePercentuale = SafeDblFromText(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

                lbl = TryCast(gvVettoriPromo.Rows(i).FindControl("lblAssicurazioneMinimo"), Label)
                AssicurazioneMinimo = SafeMoney(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

                Dim imponibileValTmp As Double = SafeMoney(Me.lblImponibile.Text, 0)
                TotAssicurazione = (AsssicurazionePercentuale * imponibileValTmp) / 100
                If TotAssicurazione < AssicurazioneMinimo Then
                    TotAssicurazione = AssicurazioneMinimo
                End If

                Me.lblAssicurazione.Text = FormatCurrencyIt(TotAssicurazione)

                'Contrassegno
                lblContrPerc = TryCast(gvVettoriPromo.Rows(i).FindControl("lblContrPerc"), Label)
                lblContrFisso = TryCast(gvVettoriPromo.Rows(i).FindControl("lblContrFisso"), Label)
                lblContrMinimo = TryCast(gvVettoriPromo.Rows(i).FindControl("lblContrMinimo"), Label)

                Me.tbContrFisso.Text = If(lblContrFisso IsNot Nothing, lblContrFisso.Text, "")
                Me.tbContrPerc.Text = If(lblContrPerc IsNot Nothing, lblContrPerc.Text, "")
                Me.tbContrMinimo.Text = If(lblContrMinimo IsNot Nothing, lblContrMinimo.Text, "")

                AggiornaSpeseAssicurazione()

                If AsssicurazionePercentuale = 0 Then
                    Me.cbAssicurazione.Checked = False
                    Me.cbAssicurazione.Enabled = False
                Else
                    Me.cbAssicurazione.Enabled = True
                End If

                If SafeDblFromText(Me.tbContrPerc.Text, 0) = 0 Then
                    RitiroSede = True
                Else
                    RitiroSede = False
                End If

            End If
        Next

    End If

    'Setto l'iva relativa al vettore selezionato
    If tbVettoriId.Text <> "" Then
        Session("Iva_Vettori") = IvaVettore(SafeIntFromText(tbVettoriId.Text, 0))
    End If

End Sub

    Public Sub AggiornaSpeseAssicurazione()
        If Me.cbAssicurazione.Checked Then
            Me.lblSpeseAss.Text = Me.lblAssicurazione.Text
        Else
            Me.lblSpeseAss.Text = ChrW(8364) & " 0,00"
        End If
    End Sub

    Protected Sub gvPagamento_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles gvPagamento.PreRender
        LeggiPagamenti()
    End Sub

    Public Sub LeggiPagamenti()

    Dim i As Integer
    Dim rb As Control
    Dim Percentuale As Double
    Dim Fisso As Double
    Dim Minimo As Double
    Dim totPagamento As Double
    Dim lbl As Label
    Dim lblContrassegno As Label
    Dim sel As Boolean = False
    Dim firstSelectableIndex As Integer = -1

    ' Leggo importi in modo safe (le Label contengono spesso il simbolo euro)
    Dim impD As Double = SafeMoney(Me.lblImponibile.Text, 0)
    Dim spedD As Double = SafeMoney(Me.lblSpeseSped.Text, 0)
    Dim assD As Double = SafeMoney(Me.lblSpeseAss.Text, 0)
    Dim buonoD As Double = SafeMoney(Me.lblBuonoSconto.Text, 0)

    Dim ivaVett As Integer = GetSessionInt("Iva_Vettori", 0)

    Dim ivaUtentePerc As Double = SafeDblFromText(If(Session("Iva_Utente"), "-1").ToString(), -1)
    Dim ivaAssPerc As Double = If(ivaUtentePerc > -1, ivaUtentePerc, preleva_ValoreIva(-1))

    Dim ivaCalcolata As Double = calcola_iva(spedD, ivaVett) + assD * (ivaAssPerc / 100)

    Me.lblIva.Text = FormatCurrencyIt(ivaCalcolata)

    Dim totBase As Double = impD + spedD + assD + ivaCalcolata

    For i = 0 To gvPagamento.Rows.Count - 1

        rb = TryCast(gvPagamento.Rows(i).FindControl("rbPagamento"), Control)

        If firstSelectableIndex = -1 AndAlso rb IsNot Nothing AndAlso RbGetEnabled(rb) Then
            firstSelectableIndex = i
        End If

        lblContrassegno = TryCast(gvPagamento.Rows(i).FindControl("lblContrassegno"), Label)

        If lblContrassegno IsNot Nothing AndAlso Val(lblContrassegno.Text) = 1 Then

            Percentuale = SafeDblFromText(Me.tbContrPerc.Text, 0)
            Fisso = SafeMoney(Me.tbContrFisso.Text, 0)
            Minimo = SafeMoney(Me.tbContrMinimo.Text, 0)

            If RitiroSede = True Then
                If rb IsNot Nothing Then
                    RbSetChecked(rb, False)
                    RbSetEnabled(rb, False)
                End If
            Else
                If rb IsNot Nothing Then RbSetEnabled(rb, True)
            End If

        Else

            lbl = TryCast(gvPagamento.Rows(i).FindControl("lblCostoP"), Label)
            Percentuale = SafeDblFromText(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

            lbl = TryCast(gvPagamento.Rows(i).FindControl("lblCostoF"), Label)
            Fisso = SafeMoney(If(lbl IsNot Nothing, lbl.Text, "0"), 0)

            Minimo = 0

        End If

        totPagamento = (totBase * (Percentuale / 100)) + Fisso
        If totPagamento < Minimo Then
            totPagamento = Minimo
        End If

        lbl = TryCast(gvPagamento.Rows(i).FindControl("lblCosto"), Label)
        Try
            If lbl IsNot Nothing Then lbl.Text = FormatCurrencyIt(totPagamento)
        Catch
            If lbl IsNot Nothing Then lbl.Text = ChrW(8364) & " 0,00"
        End Try

        If rb IsNot Nothing AndAlso RbGetChecked(rb) = True AndAlso RbGetEnabled(rb) = True Then
            sel = True

            lbl = TryCast(gvPagamento.Rows(i).FindControl("lblId"), Label)
            If lbl IsNot Nothing Then Me.tbPagamenti.Text = lbl.Text

            lbl = TryCast(gvPagamento.Rows(i).FindControl("lblShopLogin"), Label)
            If lbl IsNot Nothing Then Me.tbShopIdGestPay.Text = lbl.Text

            Me.lblPagamento.Text = FormatCurrencyIt(totPagamento)
        End If

    Next

    If sel = False AndAlso firstSelectableIndex > -1 Then

        rb = TryCast(gvPagamento.Rows(firstSelectableIndex).FindControl("rbPagamento"), Control)
        If rb IsNot Nothing Then RbSetChecked(rb, True)

        lbl = TryCast(gvPagamento.Rows(firstSelectableIndex).FindControl("lblId"), Label)
        If lbl IsNot Nothing Then Me.tbPagamenti.Text = lbl.Text

        lbl = TryCast(gvPagamento.Rows(firstSelectableIndex).FindControl("lblShopLogin"), Label)
        If lbl IsNot Nothing Then Me.tbShopIdGestPay.Text = lbl.Text

        lbl = TryCast(gvPagamento.Rows(firstSelectableIndex).FindControl("lblCosto"), Label)
        If lbl IsNot Nothing Then
            Me.lblPagamento.Text = lbl.Text
        Else
            Me.lblPagamento.Text = FormatCurrencyIt(0D)
        End If

    End If

    Dim pagD As Double = SafeMoney(Me.lblPagamento.Text, 0)
    Me.lblTotale.Text = FormatCurrencyIt(impD + ivaCalcolata + assD + spedD + pagD + buonoD)

End Sub

    Protected Sub gvVettoriPromo_RowDataBound(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewRowEventArgs) Handles gvVettoriPromo.RowDataBound

    Dim Soglia As Label
    Dim Peso As Label
    Dim Costo As Label
    Dim Percentuale As Label
    Dim Selezione As Control

    cont_indice_riga += 1

    If e.Row.RowType = DataControlRowType.DataRow Then

        Selezione = TryCast(e.Row.FindControl("rbSpedizione"), Control)
        Soglia = TryCast(e.Row.FindControl("lblSogliaMinima"), Label)
        Peso = TryCast(e.Row.FindControl("lblPeso"), Label)
        Costo = TryCast(e.Row.FindControl("lblCosto"), Label)
        Percentuale = TryCast(e.Row.FindControl("lblPercentuale"), Label)

        Dim sogliaVal As Double = SafeDblFromText(If(Soglia IsNot Nothing, Soglia.Text, "0"), 0)
        Dim pesoVal As Double = SafeDblFromText(If(Peso IsNot Nothing, Peso.Text, "0"), 0)

        If (sogliaVal <= (imponibile - imponibile_gratis)) AndAlso (pesoVal >= pesoTotale) Then

            If Selezione IsNot Nothing Then
                RbSetEnabled(Selezione, False)
                RbSetChecked(Selezione, False)
            End If

            Try
                Dim percVal As Double = SafeDblFromText(If(Percentuale IsNot Nothing, Percentuale.Text, "0"), 0)
                If percVal > 0 AndAlso Costo IsNot Nothing Then
                    Costo.Text = FormatCurrencyIt(((imponibile - imponibile_gratis) / 100) * percVal)
                End If
            Catch
                If Percentuale IsNot Nothing Then Percentuale.Text = "0"
            End Try

            Dim costoVal As Double = SafeMoney(If(Costo IsNot Nothing, Costo.Text, "0"), 0)
            If costoVal < costo_promo_minimo Then
                costo_promo_minimo = costoVal
                indice_riga_da_selezionare = cont_indice_riga
            End If

        Else
            If Selezione IsNot Nothing Then
                RbSetEnabled(Selezione, False)
            End If
        End If

    End If

End Sub


    Public Sub BindLstDestinazioneLstScegliIndirizzo

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet

        Try

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
			cmd.Parameters.AddWithValue("@id", GetUtentiIdSafe(0))
            cmd.CommandText = "SELECT ID, CONCAT(RAGIONESOCIALEA, ' - ', NOMEA, ' - ',INDIRIZZOA, ', CAP: ', CAPA, ' - ',CITTAA,' (', PROVINCIAA, ')') AS CAMPO FROM utentiindirizzi where UTENTEID = @id Order by Predefinito Desc"


            Dim sqlAdp As New MySqlDataAdapter(cmd)
            sqlAdp.Fill(dsData, "utentiindirizzi")

            cmd.Dispose()

            LstDestinazione.Items.Clear()
            LstDestinazione.DataSource = dsData
            LstDestinazione.DataValueField = "ID"
            LstDestinazione.DataTextField = "CAMPO"
            LstDestinazione.DataBind()
			LstDestinazione.Items.Insert(0, New ListItem("(Seleziona)", "0"))
			
			LstScegliIndirizzo.Items.Clear()
            LstScegliIndirizzo.DataSource = dsData
            LstScegliIndirizzo.DataValueField = "ID"
            LstScegliIndirizzo.DataTextField = "CAMPO"
            LstScegliIndirizzo.DataBind()
            LstScegliIndirizzo.Items.Insert(0, New ListItem("Indirizzo principale", "0"))
            ApplyCurrentShippingAddress()

        Catch ex As Exception
        LogEx(ex, "SendOrder")

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try

    End Sub

    Public Function getIndirizzoPrincipale() As String

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dsData As New DataSet

        Try
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
			cmd.Parameters.AddWithValue("@id", GetUtentiIdSafe(0))
            cmd.CommandText = "SELECT CONCAT(RAGIONESOCIALE, ' - ', COGNOMENOME, ' - ',INDIRIZZO, ', CAP: ', CAP, ' - ',CITTA,' (', PROVINCIA, ')')AS CAMPO FROM utenti where ID = @id"

            Dim obj = cmd.ExecuteScalar()
            If obj IsNot Nothing AndAlso obj IsNot DBNull.Value Then
            Return obj.ToString()
            End If
            Return ""


            cmd.Dispose()

        Catch ex As Exception
        LogEx(ex, "SendOrder")

            Return "ERRORE"

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try

    End Function

    Private Function ShippingAddressBelongsToCurrentUser(ByVal addressId As Integer) As Boolean
        Dim utentiId As Integer = GetUtentiIdSafe(0)
        If addressId <= 0 OrElse utentiId <= 0 Then Return False

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT COUNT(*) FROM utentiindirizzi WHERE Id=@Id AND UtenteId=@UtentiId", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.AddWithValue("@Id", addressId)
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    Dim countValue As Object = cmd.ExecuteScalar()
                    Return Convert.ToInt32(countValue) > 0
                End Using
            End Using
        Catch ex As Exception
            LogEx(ex, "ShippingAddressBelongsToCurrentUser")
            Return False
        End Try
    End Function

    Private Sub SelectShippingAddressListValue(ByVal addressId As Integer)
        If LstScegliIndirizzo Is Nothing OrElse LstScegliIndirizzo.Items.Count = 0 Then Return

        Dim value As String = addressId.ToString()
        If LstScegliIndirizzo.Items.FindByValue(value) IsNot Nothing Then
            LstScegliIndirizzo.ClearSelection()
            LstScegliIndirizzo.SelectedValue = value
        End If
    End Sub

    Private Sub ClearShippingAddressSummary()
        lblTab_RagioneSocialeSpedizione.Text = ""
        lblTab_NomeSpedizione.Text = ""
        lblTab_IndirizzoSpedizione.Text = ""
        lblTab_CittaSpedizione.Text = ""
        lblTab_CapSpedizione.Text = ""
        lblTab_ProvinciaSpedizione.Text = ""
        lblTab_ZonaSpedizione.Text = ""
        lblTab_TelSpedizione.Text = ""
        lblTab_NotaDestinazione.Text = ""
    End Sub

    Private Sub FillMainShippingAddressSummary()
        Dim utentiId As Integer = GetUtentiIdSafe(0)
        If utentiId <= 0 Then
            ClearShippingAddressSummary()
            Return
        End If

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT RagioneSociale, CognomeNome, Indirizzo, Cap, Citta, Provincia, Telefono, Cellulare FROM utenti WHERE Id=@Id", conn)
                    cmd.CommandType = CommandType.Text
                    cmd.Parameters.AddWithValue("@Id", utentiId)
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            Dim telefono As String = DbText(dr("Cellulare"))
                            If telefono = "" Then telefono = DbText(dr("Telefono"))

                            lblTab_RagioneSocialeSpedizione.Text = DbText(dr("RagioneSociale"))
                            lblTab_NomeSpedizione.Text = DbText(dr("CognomeNome"))
                            lblTab_IndirizzoSpedizione.Text = DbText(dr("Indirizzo"))
                            lblTab_CapSpedizione.Text = DbText(dr("Cap"))
                            lblTab_CittaSpedizione.Text = DbText(dr("Citta"))
                            lblTab_ProvinciaSpedizione.Text = DbText(dr("Provincia"))
                            lblTab_ZonaSpedizione.Text = ""
                            lblTab_TelSpedizione.Text = telefono
                            lblTab_NotaDestinazione.Text = ""
                        Else
                            ClearShippingAddressSummary()
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            LogEx(ex, "FillMainShippingAddressSummary")
            ClearShippingAddressSummary()
        End Try
    End Sub

    Private Sub ApplyAlternativeShippingAddress(ByVal addressId As Integer, ByVal isManual As Boolean)
        If Not ShippingAddressBelongsToCurrentUser(addressId) Then
            ApplyDefaultShippingAddress()
            Return
        End If

        SetCartShippingAddressId(addressId)
        SetCartShippingAddressIsManual(isManual)
        SelectShippingAddressListValue(addressId)
        compila_campi_destinazione_alternativa_o_indirizzo_spedizione(addressId, Lst.indirizzoSpedizione)
        If isManual Then
            SetShippingAddressUxState("Selezionato per questo ordine", "Stai usando un indirizzo scelto manualmente per il checkout corrente.")
        Else
            SetShippingAddressUxState("Predefinito", "Indirizzo consigliato: predefinito salvato nella tua area account.")
        End If
    End Sub

    Private Sub ApplyMainShippingAddress(ByVal isManual As Boolean)
        SetCartShippingAddressId(0)
        SetCartShippingAddressIsManual(isManual)
        SelectShippingAddressListValue(0)
        FillMainShippingAddressSummary()
        If isManual Then
            SetShippingAddressUxState("Selezionato per questo ordine", "Stai usando l'indirizzo principale per il checkout corrente.")
        Else
            SetShippingAddressUxState("Indirizzo principale", "Non risulta una sede alternativa predefinita: useremo l'indirizzo principale.")
        End If
    End Sub

    Private Sub ApplyDefaultShippingAddress()
        Dim prefId As Integer = calcola_indirizzo_spedizione_predefinito()
        If prefId > 0 AndAlso ShippingAddressBelongsToCurrentUser(prefId) Then
            ApplyAlternativeShippingAddress(prefId, False)
        Else
            ApplyMainShippingAddress(False)
        End If
    End Sub

    Private Sub ApplyCurrentShippingAddress()
        If GetCartShippingAddressIsManual() Then
            Dim selectedId As Integer = GetCartShippingAddressId()
            If selectedId > 0 Then
                If ShippingAddressBelongsToCurrentUser(selectedId) Then
                    ApplyAlternativeShippingAddress(selectedId, True)
                Else
                    SetCartShippingAddressIsManual(False)
                    ApplyDefaultShippingAddress()
                    SetAddressSelectionMessage("Indirizzo selezionato non disponibile. Abbiamo ripristinato l'indirizzo predefinito.")
                End If
            Else
                ApplyMainShippingAddress(True)
            End If
        Else
            ApplyDefaultShippingAddress()
        End If
    End Sub

    Private Sub StabilizeCartAddressEditUi()
        If open1 IsNot Nothing Then open1.Style.Item("display") = ""
        If panel IsNot Nothing Then
            panel.Style.Item("display") = "none"
            panel.Visible = False
        End If
        If PnlDestinazione IsNot Nothing Then PnlDestinazione.Visible = False
        If CHKPREDEFINITO IsNot Nothing Then CHKPREDEFINITO.Visible = False
        ConfigureCartAddressEditor()
        ApplyCartAddressEditorLock()
        ApplyCheckoutStepUi()
        Session("cityBinding") = 0
    End Sub

    Public Sub FillTableInfo()

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim sqlString As String = ""
        Dim dr As MySqlDataReader

        Try

            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.Parameters.AddWithValue("@id", GetUtentiIdSafe(0))
            cmd.CommandText = "SELECT * FROM utenti WHERE ID=@id"
            dr = cmd.ExecuteReader

            If dr.Read Then
                Me.lblTab_Cap.Text = dr.Item("CAP")
                If Not IsDBNull(dr.Item("CELLULARE")) Then Me.lblTab_Cell.Text = dr.Item("CELLULARE")
                Me.lblTab_CF.Text = dr.Item("CODICEFISCALE")
                Me.lblTab_Citta.Text = dr.Item("CITTA")
                If Not IsDBNull(dr.Item("FAX")) Then Me.lblTab_Fax.Text = dr.Item("FAX")
                Me.lblTab_Indirizzo.Text = dr.Item("INDIRIZZO")
                Me.lblTab_mail.Text = dr.Item("EMAIL")
                Me.lblTab_Nome.Text = dr.Item("COGNOMENOME")
                Me.lblTab_pIva.Text = dr.Item("PIVA")
                Me.lblTab_Provincia.Text = dr.Item("PROVINCIA")
                Me.lblTab_RagioneSociale.Text = dr.Item("RAGIONESOCIALE")
                Me.lblTab_Tel.Text = dr.Item("TELEFONO")
            End If

            dr.Close()
            cmd.Dispose()

        Catch ex As Exception
        LogEx(ex, "SendOrder")

        Finally

            If conn.State = ConnectionState.Open Then
                conn.Close()
                conn.Dispose()
            End If

        End Try

    End Sub

    Protected Sub ImgBtnDestinazioneSi_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImgBtnDestinazioneSi.Click
        If Not GuardCartSessionForSensitiveAction() Then Return
        AggiornaDestinazionePredefinita(True)
    End Sub

    Protected Sub ImgBtnDestinazioneNo_Click(ByVal sender As Object, ByVal e As System.Web.UI.ImageClickEventArgs) Handles ImgBtnDestinazioneNo.Click
        If Not GuardCartSessionForSensitiveAction() Then Return
        AggiornaDestinazionePredefinita(False)
    End Sub

    Private Sub AggiornaDestinazionePredefinita(ByVal Aggiorna As Boolean)

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Exit Sub

    Dim predefinito As Integer = 0

    ' Se richiesto, azzero tutti i predefiniti
    If Aggiorna = True Then
        Dim paramsUpd As New Dictionary(Of String, String)
        paramsUpd.Add("@UtenteId", utentiId.ToString())
        ExecuteUpdate("utentiindirizzi", "PREDEFINITO = 0", "UTENTEID=@UtenteId", paramsUpd)
        predefinito = 1
    End If

    ' Inserimento nuovo indirizzo
    Dim paramsIns As New Dictionary(Of String, String)
    paramsIns.Add("@UtenteId", utentiId.ToString())
    paramsIns.Add("@RAGIONESOCIALEA", Me.tbRagioneSocialeA.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@NOMEA", Me.tbNomeA.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@INDIRIZZOA", Me.tbIndirizzo2.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@CAPA", Me.tbCap2.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@CITTAA", getDdlCittaValue(Me.ddlCitta2).Replace("'", "''").ToUpper)
    paramsIns.Add("@PROVINCIAA", Me.tbProvincia2.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@NOTE", Me.tbNote.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@TELEFONOA", Me.tbTelefono2.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@ZONA", Me.tbZona.Text.Replace("'", "''").ToUpper)
    paramsIns.Add("@PREDEFINITO", predefinito.ToString())

    ExecuteInsert("utentiindirizzi",
                  "UTENTEID, RAGIONESOCIALEA, NOMEA, INDIRIZZOA, CAPA, CITTAA, PROVINCIAA, NOTE, TELEFONOA, ZONA, PREDEFINITO",
                  "@UtenteId, @RAGIONESOCIALEA, @NOMEA, @INDIRIZZOA, @CAPA, @CITTAA, @PROVINCIAA, @NOTE, @TELEFONOA, @ZONA, @PREDEFINITO",
                  paramsIns)

    BindLstDestinazioneLstScegliIndirizzo()
    Me.tblDestAlter.Visible = False

    Me.tbRagioneSocialeA.Text = ""
    Me.tbNomeA.Text = ""
    Me.tbIndirizzo2.Text = ""
    Me.tbCap2.Text = ""
    riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2, "")
    Me.tbProvincia2.Text = ""
    Me.tbNote.Text = ""
    Me.tbZona.Text = ""
    Me.tbTelefono2.Text = ""

    Me.RFRagioneSocialeA.Enabled = False
    Me.RFIndirizzo2.Enabled = False
    Me.RFCitta2.Enabled = False
    Me.RFProvincia2.Enabled = False
    Me.RFCap2.Enabled = False
    Me.RFTelefono2.Enabled = False

    End Sub


	Protected Sub clear_destinazione_alternativa()
		BindLstDestinazioneLstScegliIndirizzo
		Me.tbRagioneSocialeA.Text = ""
        Me.tbNomeA.Text = ""
        Me.tbIndirizzo2.Text = ""
        Me.tbCap2.Text = ""
        riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2, "")
        Me.tbProvincia2.Text = ""
        Me.tbNote.Text = ""
        Me.tbZona.Text = ""
		Me.tbTelefono2.Text = ""
	End Sub
	
    Protected Sub btnAnnullaDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnAnnullaDest.Click
        If Not GuardCartSessionForSensitiveAction() Then Return
        'btInviaOrdine.Enabled = True
		clear_destinazione_alternativa
		Session("cityBinding") = 0
    End Sub

    Protected Sub LstScegliIndirizzo_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles LstScegliIndirizzo.PreRender

    If LstScegliIndirizzo IsNot Nothing AndAlso LstScegliIndirizzo.Items.Count > 0 Then
        ApplyCurrentShippingAddress()
    Else
        ApplyMainShippingAddress(False)
    End If

    StabilizeCartAddressEditUi()

    End Sub

    Protected Sub LstScegliIndirizzo_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        If Not IsAddressEditorActionAllowed(sender) Then Return
        Dim selectedId As Integer = 0
        Integer.TryParse(If(LstScegliIndirizzo IsNot Nothing, LstScegliIndirizzo.SelectedValue, "0"), selectedId)

        If selectedId > 0 Then
            If ShippingAddressBelongsToCurrentUser(selectedId) Then
                ApplyAlternativeShippingAddress(selectedId, True)
                SetAddressSelectionMessage("Indirizzo di spedizione aggiornato.")
            Else
                SetCartShippingAddressIsManual(False)
                ApplyDefaultShippingAddress()
                SetAddressSelectionMessage("Indirizzo selezionato non disponibile. Abbiamo ripristinato l'indirizzo predefinito.")
            End If
        Else
            ApplyMainShippingAddress(True)
            SetAddressSelectionMessage("Indirizzo di spedizione aggiornato.")
        End If

        StabilizeCartAddressEditUi()
    End Sub

    Protected Sub btnCartAddressAdd_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        If Not GuardCartSessionForSensitiveAction() Then Return
        If GetUtentiIdSafe(0) <= 0 Then
            SetAddressSelectionMessage("Accedi per aggiungere un indirizzo di spedizione.")
            Return
        End If

        ClearCartAddressEditorFields()
        SetCheckoutStep("checkout")
        SetCartAddressEditorState(True, "add", 0)
        SetAddressSelectionMessage("Aggiungi un nuovo indirizzo senza uscire dal carrello.")
        ConfigureCartAddressEditor()
        ApplyCartAddressEditorLock()
    End Sub

    Protected Sub btnCartAddressEdit_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        If Not GuardCartSessionForSensitiveAction() Then Return
        Dim utentiId As Integer = GetUtentiIdSafe(0)
        If utentiId <= 0 Then
            SetAddressSelectionMessage("Accedi per modificare un indirizzo di spedizione.")
            Return
        End If

        Dim selectedId As Integer = GetCartShippingAddressId()
        If LstScegliIndirizzo IsNot Nothing Then
            Integer.TryParse(If(LstScegliIndirizzo.SelectedValue, "0"), selectedId)
        End If

        If selectedId <= 0 Then
            SetCartAddressEditorState(False, "add", 0)
            SetAddressSelectionMessage("L'indirizzo principale si modifica dai dettagli account. Puoi aggiungere una nuova sede alternativa da qui.")
            Return
        End If

        Dim row As DataRow = LoadAlternativeAddressRow(utentiId, selectedId)
        If row Is Nothing Then
            SetCartAddressEditorState(False, "add", 0)
            SetAddressSelectionMessage("Indirizzo selezionato non disponibile. Abbiamo ripristinato il controllo del carrello.")
            ApplyCurrentShippingAddress()
            Return
        End If

        FillCartAddressEditor(row)
        SetCheckoutStep("checkout")
        SetCartAddressEditorState(True, "edit", selectedId)
        SetAddressSelectionMessage("Modifica l'indirizzo selezionato senza uscire dal carrello.")
        ConfigureCartAddressEditor()
        ApplyCartAddressEditorLock()
    End Sub

    Protected Sub btnCartAddressCancel_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        If Not GuardCartSessionForSensitiveAction() Then Return
        SetCartAddressEditorState(False, "add", 0)
        ClearCartAddressEditorFields()
        SetAddressSelectionMessage("Modifica indirizzo annullata.")
        ApplyCurrentShippingAddress()
        StabilizeCartAddressEditUi()
    End Sub

    Protected Sub tbCartCapA_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        If Not GuardCartSessionForSensitiveAction() Then Return
        SetCartAddressEditorState(True, GetCartAddressEditorMode(), GetCartAddressEditorId())
        ResolveCartAddressCap()
        ConfigureCartAddressEditor()
    End Sub

    Protected Sub ddlCartCittaA_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs)
        If Not GuardCartSessionForSensitiveAction() Then Return
        SetCartAddressEditorState(True, GetCartAddressEditorMode(), GetCartAddressEditorId())
        ResolveCartAddressCap(If(ddlCartCittaA IsNot Nothing, ddlCartCittaA.SelectedValue, ""))
        ConfigureCartAddressEditor()
    End Sub

    Protected Sub btnCartAddressSave_Click(ByVal sender As Object, ByVal e As System.EventArgs)
        If Not GuardCartSessionForSensitiveAction() Then Return
        Dim utentiId As Integer = GetUtentiIdSafe(0)
        If utentiId <= 0 Then
            SetCartAddressEditorMessage("Accedi per salvare un indirizzo.", True)
            Return
        End If

        ResolveCartAddressCap(If(ddlCartCittaA IsNot Nothing AndAlso ddlCartCittaA.Visible, ddlCartCittaA.SelectedValue, ""))

        Dim errors As List(Of String) = ValidateCartAddressEditor()
        If errors.Count > 0 Then
            SetCartAddressEditorState(True, GetCartAddressEditorMode(), GetCartAddressEditorId())
            SetCartAddressEditorMessage(String.Join(" ", errors.ToArray()), True)
            ConfigureCartAddressEditor()
            Return
        End If

        Try
            Dim mode As String = GetCartAddressEditorMode()
            Dim addressId As Integer = GetCartAddressEditorId()
            Dim savedId As Integer = SaveCartAddressInline(utentiId, mode, addressId, chkCartAddressSetDefault.Checked)

            If savedId <= 0 Then
                SetCartAddressEditorState(True, mode, addressId)
                SetCartAddressEditorMessage("Non e stato possibile salvare l'indirizzo selezionato.", True)
                ConfigureCartAddressEditor()
                Return
            End If

            BindLstDestinazioneLstScegliIndirizzo()
            If chkCartAddressUseForOrder Is Nothing OrElse chkCartAddressUseForOrder.Checked Then
                ApplyAlternativeShippingAddress(savedId, True)
                SetAddressSelectionMessage("Indirizzo salvato e selezionato per questo ordine.")
            Else
                ApplyCurrentShippingAddress()
                SetAddressSelectionMessage("Indirizzo salvato. La scelta di spedizione corrente resta invariata.")
            End If

            SetCartAddressEditorState(False, "add", 0)
            ClearCartAddressEditorFields()
            StabilizeCartAddressEditUi()
        Catch ex As Exception
            LogEx(ex, "btnCartAddressSave_Click")
            SetCartAddressEditorState(True, GetCartAddressEditorMode(), GetCartAddressEditorId())
            SetCartAddressEditorMessage("Non e stato possibile salvare l'indirizzo. Riprova tra qualche minuto.", True)
            ConfigureCartAddressEditor()
        End Try
    End Sub
	
    Protected Sub LstDestinazione_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles LstDestinazione.PreRender
        'If LstDestinazione.SelectedValue <= 0 Then
        '    LstDestinazione.SelectedValue = calcola_predefinito_destinazione_alternativa()
        'End If
		
        REM Session("DESTINAZIONEALTERNATIVA") = LstDestinazione.SelectedItem.Value

		REM btnElimDest.enabled = false
		REM btnModDest.enabled = false
		REM if LstDestinazione.Items(0).value = 0 then
			REM if Session("DESTINAZIONEALTERNATIVA") > 0 then
				REM LstDestinazione.Items.RemoveAt(0)
				REM btnModDest.enabled = true
				REM if LstDestinazione.items.count > 1 Then
					REM btnElimDest.enabled = true
				REM End If
			REM End If
		REM Else
			REM if LstDestinazione.items.count > 1 Then
				REM btnElimDest.enabled = true
				REM btnModDest.enabled = true
			REM End If
		REM End If

        REM 'Aggiorno i campi Text sottostanti per dar modo all'utente di modificare o inserire una nuova destinazione in modo facile
        REM if Session("VECCHIADESTINAZIONEALTERNATIVA") <> Session("DESTINAZIONEALTERNATIVA") Then
			REM compila_campi_destinazione_alternativa_o_indirizzo_spedizione(LstDestinazione.SelectedValue,Lst.destinazioneAlternativa)
			REM Session("VECCHIADESTINAZIONEALTERNATIVA") = Session("DESTINAZIONEALTERNATIVA")
		REM End if
    End Sub

    Protected Sub LstDestinazione_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles LstDestinazione.SelectedIndexChanged
        If Not IsAddressEditorActionAllowed(sender) Then Return
		Session("VECCHIADESTINAZIONEALTERNATIVA") = Session("DESTINAZIONEALTERNATIVA")
        'If LstDestinazione.SelectedItem.Value <> "0" Then
        '    Session("DESTINAZIONEALTERNATIVA") = LstDestinazione.SelectedItem.Value
        'Else
        '    Session("DESTINAZIONEALTERNATIVA") = 0
        'End If
		
    End Sub

    Function calcola_indirizzo_spedizione_predefinito() As Integer
        Dim predefinito As Integer = 0
        Dim params As New Dictionary(Of String, String)
        params.add("@UtenteId", GetUtentiIdSafe(0).ToString())
        Dim dr = ExecuteQueryGetDataReader("id", "utentiindirizzi", "(UtenteId=@UtenteId) AND (Predefinito=1)", params)
        dr.Read()

        If dr.HasRows = True Then
            predefinito = dr.Item("id")
        End If

        dr.Close()

        Return predefinito
    End Function

    Private Function compila_campi_destinazione_alternativa_o_indirizzo_spedizione(ByVal idDestinazione As Integer, ByVal tipolst As Lst) As Integer

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Return 0
    If idDestinazione <= 0 Then Return 0

    Try
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()

            Using cmd As New MySqlCommand("SELECT * FROM utentiindirizzi WHERE ID=@id AND UtenteId=@UtentiId LIMIT 1", conn)
                cmd.CommandType = CommandType.Text
                cmd.Parameters.AddWithValue("@id", idDestinazione)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)

                Using dr As MySqlDataReader = cmd.ExecuteReader()
                    If dr.Read() Then

                        If tipolst = Lst.destinazioneAlternativa Then

                            tbRagioneSocialeA.Text = If(IsDBNull(dr("RagioneSocialeA")), "", dr("RagioneSocialeA").ToString())
                            tbNomeA.Text = If(IsDBNull(dr("NomeA")), "", dr("NomeA").ToString())
                            tbIndirizzo2.Text = If(IsDBNull(dr("IndirizzoA")), "", dr("IndirizzoA").ToString())

                            Dim capA As String = If(IsDBNull(dr("CapA")), "", dr("CapA").ToString())
                            Dim cittaA As String = If(IsDBNull(dr("CittaA")), "", dr("CittaA").ToString())

                            riempi_ddl_citta(capA, ddlCitta2, tbProvincia2, cittaA)

                            tbCap2.Text = capA
                            tbProvincia2.Text = If(IsDBNull(dr("ProvinciaA")), "", dr("ProvinciaA").ToString())
                            tbZona.Text = If(IsDBNull(dr("Zona")), "", dr("Zona").ToString())
                            tbTelefono2.Text = If(IsDBNull(dr("TelefonoA")), "", dr("TelefonoA").ToString())
                            tbNote.Text = If(IsDBNull(dr("Note")), "", dr("Note").ToString())

                            Dim pref As Integer = 0
                            If Not IsDBNull(dr("Predefinito")) Then Integer.TryParse(dr("Predefinito").ToString(), pref)
                            CHKPREDEFINITO.Checked = (pref = 1)

                        Else
                            lblTab_RagioneSocialeSpedizione.Text = If(IsDBNull(dr("RagioneSocialeA")), "", dr("RagioneSocialeA").ToString())
                            lblTab_NomeSpedizione.Text = If(IsDBNull(dr("NomeA")), "", dr("NomeA").ToString())
                            lblTab_IndirizzoSpedizione.Text = If(IsDBNull(dr("IndirizzoA")), "", dr("IndirizzoA").ToString())
                            lblTab_CittaSpedizione.Text = If(IsDBNull(dr("CittaA")), "", dr("CittaA").ToString())
                            lblTab_CapSpedizione.Text = If(IsDBNull(dr("CapA")), "", dr("CapA").ToString())
                            lblTab_ProvinciaSpedizione.Text = If(IsDBNull(dr("ProvinciaA")), "", dr("ProvinciaA").ToString())
                            lblTab_ZonaSpedizione.Text = If(IsDBNull(dr("Zona")), "", dr("Zona").ToString())
                            lblTab_TelSpedizione.Text = If(IsDBNull(dr("TelefonoA")), "", dr("TelefonoA").ToString())
                            lblTab_NotaDestinazione.Text = If(IsDBNull(dr("Note")), "", dr("Note").ToString())
                        End If

                    End If
                End Using
            End Using
        End Using

    Catch ex As Exception
        LogEx(ex, "compila_campi_destinazione_alternativa_o_indirizzo_spedizione")
    End Try

    Return 0
End Function

    Protected Sub gvArticoliGratis_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles gvArticoliGratis.PreRender
    If _cartLoginRequiredFastPathActive Then Return

    Dim i As Integer

    For i = 0 To gvArticoliGratis.Items.Count - 1

        Dim img As Image = TryCast(gvArticoliGratis.Items(i).FindControl("imgDispo"), Image)
        Dim dispo As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblDispo"), Label)
        Dim arrivo As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblArrivo"), Label)
        Dim importo As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblImporto"), Label)
        Dim importoIvato As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblImportoIvato"), Label)
        Dim peso As Label = TryCast(gvArticoliGratis.Items(i).FindControl("lblPeso"), Label)
        Dim tbQta As TextBox = TryCast(gvArticoliGratis.Items(i).FindControl("tbQta"), TextBox)

        Dim qtaRiga As Integer = SafeIntFromText(If(tbQta IsNot Nothing, tbQta.Text, "0"), 0)
        qta += qtaRiga

        If qtaRiga <= 0 Then
            Continue For
        End If

        ' visibilitÃ  prezzi e totale merce
        If IvaTipo = 1 Then
            If importo IsNot Nothing Then importo.Visible = True
            If importoIvato IsNot Nothing Then importoIvato.Visible = False
            Dim lblPrezzo As Control = gvArticoliGratis.Items(i).FindControl("lblprezzo")
            Dim lblPrezzoIvato As Control = gvArticoliGratis.Items(i).FindControl("lblprezzoivato")
            If lblPrezzo IsNot Nothing Then lblPrezzo.Visible = True
            If lblPrezzoIvato IsNot Nothing Then lblPrezzoIvato.Visible = False

            TotaleMerce += SafeDblFromText(If(importo IsNot Nothing, importo.Text, "0"), 0)

        Else
            If importo IsNot Nothing Then importo.Visible = False
            If importoIvato IsNot Nothing Then importoIvato.Visible = True
            Dim lblPrezzo As Control = gvArticoliGratis.Items(i).FindControl("lblprezzo")
            Dim lblPrezzoIvato As Control = gvArticoliGratis.Items(i).FindControl("lblprezzoivato")
            If lblPrezzo IsNot Nothing Then lblPrezzo.Visible = False
            If lblPrezzoIvato IsNot Nothing Then lblPrezzoIvato.Visible = True

            TotaleMerce += SafeDblFromText(If(importoIvato IsNot Nothing, importoIvato.Text, "0"), 0)
        End If

        Session("TotaleMerce") = TotaleMerce
        Me.lblCartSubtotalOnly.Text = FormatCurrencyIt(TotaleMerce)

        Dim impNetto As Double = SafeDblFromText(If(importo IsNot Nothing, importo.Text, "0"), 0)
        Dim impIvato As Double = SafeDblFromText(If(importoIvato IsNot Nothing, importoIvato.Text, "0"), 0)

        imponibile += impNetto
        calcolo_iva += (impIvato - impNetto)

        imponibile_gratis += impNetto
        totale += impIvato

        Dim pesoVal As Double = SafeDblFromText(If(peso IsNot Nothing, peso.Text, "0"), 0)
        If pesoVal <> 0 Then
            pesoTotale += pesoVal
        End If

        ' disponibilitÃ 
        If DispoTipo = 1 Then
            Dim dispoDouble As Double = 0
            Dim dispoTxt As String = If(If(dispo IsNot Nothing, dispo.Text, ""), "").Replace("âˆ’", "-").Replace(">", "").Trim()
            Double.TryParse(dispoTxt.Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, dispoDouble)

            If dispoDouble > DispoMinima Then
                If img IsNot Nothing Then
                    img.ImageUrl = "~/images/verde.gif"
                    img.AlternateText = "Disponibile"
                End If
            ElseIf dispoDouble > 0 Then
                If img IsNot Nothing Then
                    img.ImageUrl = "~/images/giallo.gif"
                    img.AlternateText = "DisponibilitÃ  Scarsa"
                End If
            Else
                Dim arrivoDouble As Double = 0
                Dim arrTxt As String = If(arrivo IsNot Nothing, arrivo.Text, "0")
                Double.TryParse(arrTxt.Replace(",", "."), NumberStyles.Any, CultureInfo.InvariantCulture, arrivoDouble)

                If arrivoDouble > 0 Then
                    If img IsNot Nothing Then
                        img.ImageUrl = "~/images/azzurro.gif"
                        img.AlternateText = "In Arrivo"
                    End If
                Else
                    If img IsNot Nothing Then
                        img.ImageUrl = "~/images/rosso.gif"
                        img.AlternateText = "Non Disponibile"
                    End If
                End If
            End If
        ElseIf DispoTipo = 2 Then
            If img IsNot Nothing Then img.Visible = False
            If dispo IsNot Nothing Then dispo.Visible = True
        End If

    Next
    ApplyRepeaterItemLock(gvArticoliGratis, Not IsAddressEditModeActive())
    End Sub

    Protected Sub gvVettoriPromo_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles gvVettoriPromo.PreRender

    Dim Selezione_Vettore As Control

    If indice_riga_da_selezionare > -1 Then
        ' (indice_riga_da_selezionare - 2) e non (indice_riga_da_selezionare - 1) perchÃ¨ il DataRowBound viene fatto una volta in piÃ¹
        Selezione_Vettore = TryCast(Me.gvVettoriPromo.Rows(indice_riga_da_selezionare - 2).FindControl("rbSpedizione"), Control)
        If Selezione_Vettore IsNot Nothing Then
            RbSetEnabled(Selezione_Vettore, True)
            RbSetChecked(Selezione_Vettore, True)
        End If

        Selezionato_Vettore_Promo = 1
    End If

    ' Nel caso ci sia nel carrello SOLO prodotti GRATIS
    If (imponibile - imponibile_gratis = 0) Then
        Me.Panel_SpedizioneGratis.Visible = True
    Else
        Me.Panel_SpedizioneGratis.Visible = False
    End If

End Sub

    Protected Sub rbSpedizioneGratis_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles rbSpedizioneGratis.PreRender
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand

        Dim AsssicurazionePercentuale As Double
        Dim AssicurazioneMinimo As Double
        Dim TotAssicurazione As Double

        If Me.rbSpedizioneGratis.Checked = True Then
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            cmd.Connection = conn

            conn.Open()

            cmd.CommandType = CommandType.Text
            If Session("AziendaID") = 1 Then
                cmd.CommandText = "SELECT * FROM vettori WHERE id=-1"
            Else
                cmd.CommandText = "SELECT * FROM vettori WHERE id=-2"
            End If

            Dim dr As MySqlDataReader = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows Then
                'Spedizione
                Me.lblSpeseSped.Text = FormatCurrencyIt(0D)

                If Session("AziendaID") = 1 Then
                    Me.tbVettoriId.Text = "-1"
                Else
                    Me.tbVettoriId.Text = "-2"
                End If

                'Assicurazione
                AsssicurazionePercentuale = dr.Item("AssicurazionePercentuale")
                AssicurazioneMinimo = dr.Item("AssicurazioneMinimo")

                Dim imponibileBase As Double = SafeMoney(Me.lblImponibile.Text, 0)
                TotAssicurazione = (AsssicurazionePercentuale * imponibileBase) / 100
                If TotAssicurazione < AssicurazioneMinimo Then
                    TotAssicurazione = AssicurazioneMinimo
                End If

                Me.lblAssicurazione.Text = FormatCurrencyIt(TotAssicurazione)

                'Contrassegno
                Me.tbContrFisso.Text = dr.Item("ContrassegnoFisso")
                Me.tbContrPerc.Text = dr.Item("ContrassegnoPercentuale")
                Me.tbContrMinimo.Text = dr.Item("ContrassegnoMinimo")

                AggiornaSpeseAssicurazione()

                If AsssicurazionePercentuale = 0 Then
                    Me.cbAssicurazione.Checked = False
                    Me.cbAssicurazione.Enabled = False
                Else
                    Me.cbAssicurazione.Enabled = True
                End If

                If dr.Item("ContrassegnoPercentuale") = 0 Then
                    RitiroSede = True
                Else
                    RitiroSede = False
                End If
            End If
        End If
    End Sub

    Protected Sub Page_PreRenderComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRenderComplete
        If _cartSessionExpiredRedirectIssued Then Return
        Dim imponibileVal As Double = SafeDbl(lblImponibile.Text, 0)
        Dim speseAssVal As Double = SafeDbl(lblSpeseAss.Text, 0)
        Dim speseSpedVal As Double = SafeDbl(lblSpeseSped.Text, 0)
        Dim pagamentoVal As Double = SafeDbl(lblPagamento.Text, 0)
        Dim buonoVal As Double = SafeDbl(lblBuonoSconto.Text, 0)
        Dim ivaVettoreVal As Double = SafeDbl(Session("Iva_Vettori"), 0)
        ' IVA utente: nel carrello Ã¨ trattata come PERCENTUALE (es. 22) quando > -1
        Dim ivaUtentePerc As Double = SafeDblFromText(If(Session("Iva_Utente"), "-1").ToString(), -1)
        ' Per l'assicurazione: se l'utente non ha IVA propria, uso la default (preleva_ValoreIva(-1))
        Dim ivaAssPerc As Double = If(ivaUtentePerc > -1, ivaUtentePerc, preleva_ValoreIva(-1))

        
        'Nascondo i Pannelli quando non ci sono articoli nel carrello
        If (Me.gvArticoliGratis.Items.Count = 0) And (Me.Repeater1.items.Count = 0) Then
            Me.Panel_Unico.Visible = False
            Me.btContinua.Enabled = True
        Else
            Me.Panel_Unico.Visible = True
        End If

        If (controlla_articoli_quantita_zero() = 0) Then
            Qnt_Errata.Visible = True
        End If

        'Aggiorno una sola volta i prezzi degli articoli nel carrello
        'If (Request.QueryString("update") = Nothing) And (controlla_articoli_quantita_zero() = 1) Then
        'Aggiorna_Prezzi_Carrello()
        'Response.Redirect("carrello.aspx?update=1")
        'End If

        'Buono Sconto
        If (Val(Session("BuonoSconto_id")) > 0) Then
            TB_BuonoSconto.Text = getBuonoScontoCodice(Val(Session("BuonoSconto_id")))
            TB_BuonoSconto.Enabled = False
        Else
            TB_BuonoSconto.Enabled = True

            checkOKBuonoSconto.Visible = False
            lblBuonoSconto.Text = FormatCurrencyIt(0D)
            lblBuonoScontoIVA.Text = FormatCurrencyIt(0D)
        End If

        If ((gvArticoliGratis.Items.Count > 0) Or (Repeater1.items.Count > 0)) AndAlso Not IsAddressEditModeActive() Then
            TB_BuonoSconto_TextChanged(TB_BuonoSconto, New System.EventArgs)
            GV_BuoniSconti.DataBind()
        Else
            GV_BuoniSconti.Visible = False
            Session("BuonoSconto_id") = 0
        End If

        'Aggiorno i Pagamenti ed i relativi costi
        'LeggiPagamenti()

        'Conteggi dell'iva
        Dim ivaNuova As Double = calcola_iva(speseSpedVal, ivaVettoreVal) + (speseAssVal * (ivaAssPerc / 100))
        lblIva.Text = FormatCurrencyIt(ivaNuova)

        Dim totaleDoc As Double = imponibileVal + ivaNuova + speseAssVal + speseSpedVal + pagamentoVal + buonoVal
        lblTotale.Text = FormatCurrencyIt(totaleDoc)


        'Aggiorno il valore del Buono Sconto
        If GV_BuoniSconti.Rows.Count > 0 Then
            Dim scontoPercentuale As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_Percentuale_BuonoSconto")
            Dim scontoFisso As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_scontoFisso_BuonoSconto")
            Dim scontoVettore As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_scontoVettore")
            Dim valoreBuonoSconto As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_valore_BuonoSconto")
            Dim totSconto As Label = GV_BuoniSconti.Rows(0).Cells(0).FindControl("lbl_TotSconto")

            'Controllo che lo sconto da applicare non sia uno sconto vettore
    If Val(scontoVettore.Text) = 1 Then

    Dim spedTmp As Double = SafeMoney(lblSpeseSped.Text, 0)
    Dim ivaVettTmp As Double = SafeDblFromText(If(Session("Iva_Vettori"), "0").ToString(), 0)

    Dim scontoSped As Double = -(spedTmp + (spedTmp * (ivaVettTmp / 100)))
    lblBuonoSconto.Text = FormatCurrencyIt(scontoSped)

    Else

    Dim perc As Double = SafeDblFromText(scontoPercentuale.Text, 0)
    Dim valore As Double = SafeDblFromText(valoreBuonoSconto.Text, 0)

    Dim scontoCalc As Double
    If perc > 0 Then
        scontoCalc = (SafeDbl(TotaleMerce, 0) / 100) * valore
    Else
        scontoCalc = valore
    End If

    lblBuonoSconto.Text = FormatCurrencyIt(-scontoCalc)

    End If

    ' --- SEO hardening: carrello/checkout noindex + canonical + JSON-LD ---
Dim canonical As String = Request.Url.GetLeftPart(UriPartial.Path)

AddOrReplaceMeta(Me.Page, "robots", "noindex, nofollow")
SetCanonical(Me.Page, canonical)

Dim jsonLd As String = SeoBuilder.BuildSimplePageJsonLd(Me.Title,
                                                        "Checkout e riepilogo carrello su Taikun.",
                                                        canonical,
                                                        "CheckoutPage")
SeoBuilder.SetJsonLdOnMaster(Me, jsonLd)


            ' IVA per scorporare il buono: se l'utente ha IVA propria uso quella (percentuale), altrimenti default
            Dim ivaBuonoPerc As Double = If(ivaUtentePerc > -1, ivaUtentePerc, preleva_ValoreIva(-1))


            Dim buonoTot As Double = SafeMoney(lblBuonoSconto.Text, 0) ' totale sconto (negativo)
            Dim buonoImp As Double = Math.Round(buonoTot / (1 + (ivaBuonoPerc / 100)), 2, MidpointRounding.AwayFromZero)
            Dim buonoIva As Double = Math.Round(buonoTot - buonoImp, 2, MidpointRounding.AwayFromZero)

            lblBuonoScontoIVA.Text = FormatCurrencyIt(buonoIva)
            lblBuonoSconto.Text = FormatCurrencyIt(buonoImp)

            lblIva.Text = FormatCurrencyIt(SafeMoney(lblIva.Text, 0) + buonoIva)

            Dim totBuono As Double = SafeMoney(lblBuonoSconto.Text, 0) + SafeMoney(lblBuonoScontoIVA.Text, 0)
            totSconto.Text =
            IIf(SafeDblFromText(scontoPercentuale.Text, 0) > 0,
        "Sconto in percentuale " & SafeDblFromText(valoreBuonoSconto.Text, 0) & "%",
        IIf(Val(scontoVettore.Text) > 0, "SPEDIZIONE OMAGGIO", "Sconto fisso euro " & SafeDblFromText(valoreBuonoSconto.Text, 0))) &
        "<br/>" & FormatCurrencyIt(totBuono)
        End If

		Dim totaleTemp As Double =
            SafeMoney(lblImponibile.Text, 0) +
            SafeMoney(lblIva.Text, 0) +
            SafeMoney(lblSpeseAss.Text, 0) +
            SafeMoney(lblSpeseSped.Text, 0) +
            SafeMoney(lblPagamento.Text, 0) +
            SafeMoney(lblBuonoSconto.Text, 0)


            totaleTemp = Math.Round(totaleTemp, 2, MidpointRounding.AwayFromZero)
            lblTotale.Text = FormatCurrencyIt(totaleTemp)
 

        Session("Calcolo_Iva") = lblIva.Text

        'Simulo il Click del tasto btCompleta
        'If Page.IsPostBack = False Then
        '    btCompleta_Click(sender, e)
        '    LeggiPagamenti()
        '    LeggiVettori()
        'End If

        ' Mostra l'input buono sconto solo nello step Spedizione e checkout.
        ' Lo step carrello resta focalizzato su articoli e subtotale prodotti.
        Dim showDiscountInput As Boolean = _
            (GetSessionInt("AbilitaBuoniScontiCarrello", 0) = 1) AndAlso _
            (qta > 0) AndAlso _
            IsCheckoutStepVisible() AndAlso _
            (Not IsCheckoutConfirmStep())

        Panel_BuoniSconto.Visible = showDiscountInput
        ApplyCartAddressEditorLock()
        BindCartRecentlyViewed()
    End Sub

    'Restituisce 1, se il controllo Ã¨ andato a buon fine, altrimenti 0
    Function controlla_articoli_quantita_zero() As Integer
        Dim row As RepeaterItem

        'Controllo che non ci siano articoli con quantitÃ  zero
        If Repeater1.items.Count > 0 Then
            For Each row In Repeater1.items
                Dim Qta As TextBox = row.FindControl("tbQta")
                If (SafeInt(Qta.Text, 0) <= 0) Then
                    Return 0
                End If
            Next
        End If

        'Controllo che non ci siano articoli con quantitÃ  zero
        If Me.gvArticoliGratis.items.Count > 0 Then
            For Each row In gvArticoliGratis.items
                Dim Qta As TextBox = row.FindControl("tbQta")
                If (SafeInt(Qta.Text, 0) <= 0) Then
                    Return 0
                End If
            Next
        End If

        Return 1
    End Function

    Sub Aggiorna_Prezzi_Carrello()

    If _carrelloAggiornatoThisRequest Then Exit Sub
    _carrelloAggiornatoThisRequest = True

    If (controlla_articoli_quantita_zero() = 0) Then
        Qnt_Errata.Visible = True
        ' continuo comunque: salvo Qnt=0 come da logica originale
    End If

    ' 1) Raccolgo righe dal Repeater (normali + gratis) UNA volta
    Dim rows As New List(Of CartRowInfo)

    If Repeater1 IsNot Nothing AndAlso Repeater1.Items IsNot Nothing AndAlso Repeater1.Items.Count > 0 Then
        For Each it As RepeaterItem In Repeater1.Items
            Dim r As CartRowInfo = ReadCartRowFromItem(it)
            If r.Id > 0 AndAlso r.ArtId > 0 Then rows.Add(r)
        Next
    End If

    If gvArticoliGratis IsNot Nothing AndAlso gvArticoliGratis.Items IsNot Nothing AndAlso gvArticoliGratis.Items.Count > 0 Then
        For Each it As RepeaterItem In gvArticoliGratis.Items
            Dim r As CartRowInfo = ReadCartRowFromItem(it)
            If r.Id > 0 AndAlso r.ArtId > 0 Then rows.Add(r)
        Next
    End If

    If rows.Count = 0 Then Exit Sub

    ' 2) Lista ArtId univoci
    Dim artIds As New List(Of Integer)
    Dim seen As New HashSet(Of Integer)
    For Each r As CartRowInfo In rows
        If Not seen.Contains(r.ArtId) Then
            seen.Add(r.ArtId)
            artIds.Add(r.ArtId)
        End If
    Next

    Dim listino As Integer = SafeInt(GetListinoSafe(0), 0)
    Dim ivaUtentePct As Double = SafeDbl(Session("Iva_Utente"), -1) ' qui Ã¨ â€œ%â€ (o id=valore, come nel tuo impianto)
    Dim abRC As Boolean = (SafeInt(Session("AbilitatoIvaReverseCharge"), 0) = 1)

    Dim idEsenzioneIva As Integer = SafeInt(Session("IdEsenzioneIva"), -1)
    Dim valoreEsenzioneIva As Double = SafeDbl(Session("Iva_Utente"), -1)
    Dim descrEsenzioneIva As String = If(TryCast(Session("DescrizioneEsenzioneIva"), String), "")

    Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
        conn.Open()

        ' 3) Carico vsuperarticoli per tutti gli ArtId con UNA query
        Dim vsup As New Dictionary(Of Integer, List(Of VsuperInfo))

        Using cmdV As New MySqlCommand()
            cmdV.Connection = conn
            cmdV.CommandType = CommandType.Text

            Dim inNames As New List(Of String)
            For i As Integer = 0 To artIds.Count - 1
                Dim pName As String = "@a" & i.ToString()
                inNames.Add(pName)
                cmdV.Parameters.AddWithValue(pName, artIds(i))
            Next

            cmdV.Parameters.AddWithValue("@listino", listino)

            cmdV.CommandText =
                "SELECT ID, TCid, prezzo, prezzoIvato, InOfferta, OfferteDataInizio, OfferteDataFine, " &
                "OfferteQntMinima, OfferteMultipli, OfferteDettagliId, prezzopromo, prezzopromoIvato, " &
                "IdIvaRC, ValoreIvaRC, DescrizioneIvaRC " &
                "FROM vsuperarticoli " &
                "WHERE NListino=@listino AND ID IN (" & String.Join(",", inNames) & ") " &
                "ORDER BY ID, CASE WHEN COALESCE(TCid,-1) IN (-1,0) THEN 0 ELSE 1 END, PrezzoPromo DESC"

            Using dr As MySqlDataReader = cmdV.ExecuteReader()
                While dr.Read()
                    Dim id As Integer = SafeInt(dr("ID"), 0)
                    If id <= 0 Then Continue While

                    Dim info As New VsuperInfo()
                    info.TCId = SafeInt(dr("TCid"), -1)
                    info.Prezzo = SafeDbl(dr("prezzo"), 0)
                    info.PrezzoIvato = SafeDbl(dr("prezzoIvato"), 0)
                    info.InOfferta = SafeInt(dr("InOfferta"), 0)

                    If Not IsDBNull(dr("OfferteDataInizio")) Then info.OfferteDataInizio = CDate(dr("OfferteDataInizio"))
                    If Not IsDBNull(dr("OfferteDataFine")) Then info.OfferteDataFine = CDate(dr("OfferteDataFine"))

                    info.OfferteQntMinima = CLng(SafeInt(dr("OfferteQntMinima"), 0))
                    info.OfferteMultipli = CLng(SafeInt(dr("OfferteMultipli"), 0))
                    info.OfferteDettagliId = CLng(SafeDbl(dr("OfferteDettagliId"), 0))

                    info.PrezzoPromo = SafeDbl(dr("prezzopromo"), 0)
                    info.PrezzoPromoIvato = SafeDbl(dr("prezzopromoIvato"), 0)

                    info.IdIvaRC = SafeInt(dr("IdIvaRC"), -1)
                    info.ValoreIvaRC = SafeDbl(dr("ValoreIvaRC"), -1)
                    info.DescrizioneIvaRC = If(TryCast(dr("DescrizioneIvaRC"), String), "")

                    If Not vsup.ContainsKey(id) Then
                        vsup(id) = New List(Of VsuperInfo)
                    End If
                    vsup(id).Add(info)
                End While
            End Using
        End Using

        ' 4) Preparo UPDATE UNA volta (N esecuzioni, stessa connessione)
        Using cmdU As New MySqlCommand()
            cmdU.Connection = conn
            cmdU.CommandType = CommandType.Text
            cmdU.CommandText =
                "UPDATE carrello SET " &
                "Qnt=@Qnt, " &
                "IdIvaRC=@IdIvaRC, ValoreIvaRC=@ValoreIvaRC, DescrizioneIvaRC=@DescrizioneIvaRC, " &
                "IdEsenzioneIva=@IdEsenzioneIva, ValoreEsenzioneIva=@ValoreEsenzioneIva, DescrizioneEsenzioneIva=@DescrizioneEsenzioneIva " &
                "WHERE ID=@id"

            cmdU.Parameters.Add("@Qnt", MySqlDbType.Int64)
            cmdU.Parameters.Add("@IdIvaRC", MySqlDbType.Int32)
            cmdU.Parameters.Add("@ValoreIvaRC", MySqlDbType.Double)
            cmdU.Parameters.Add("@DescrizioneIvaRC", MySqlDbType.VarChar)
            cmdU.Parameters.Add("@IdEsenzioneIva", MySqlDbType.Int32)
            cmdU.Parameters.Add("@ValoreEsenzioneIva", MySqlDbType.Double)
            cmdU.Parameters.Add("@DescrizioneEsenzioneIva", MySqlDbType.VarChar)
            cmdU.Parameters.Add("@id", MySqlDbType.Int32)

            Dim cmdQtyOnly As New MySqlCommand("UPDATE carrello SET Qnt=@Qnt WHERE ID=@id", conn)
            cmdQtyOnly.CommandType = CommandType.Text
            cmdQtyOnly.Parameters.Add("@Qnt", MySqlDbType.Int64)
            cmdQtyOnly.Parameters.Add("@id", MySqlDbType.Int32)

            Dim today As Date = Date.Today

            For Each r As CartRowInfo In rows

                If Not vsup.ContainsKey(r.ArtId) OrElse vsup(r.ArtId).Count = 0 Then
                    ' Se il listino non torna righe, non azzero i prezzi giÃ  validi: salvo solo la quantitÃ .
                    cmdQtyOnly.Parameters("@Qnt").Value = r.Qnt
                    cmdQtyOnly.Parameters("@id").Value = r.Id
                    cmdQtyOnly.ExecuteNonQuery()
                    Continue For
                End If

                Dim lst As List(Of VsuperInfo) = vsup(r.ArtId)
                Dim exactRows As List(Of VsuperInfo) = lst.FindAll(Function(x) x.TCId = r.TCId)
                If exactRows.Count = 0 AndAlso r.TCId <= 0 Then
                    exactRows = lst.FindAll(Function(x) x.TCId <= 0)
                End If
                If exactRows.Count > 0 Then lst = exactRows

                Dim baseRow As VsuperInfo = lst(0)

                Dim prezzo As Double = baseRow.Prezzo
                Dim prezzoIvato As Double = 0
                Dim offId As Long = 0
                Dim promoApplied As Boolean = False
                Dim chosenPromoRow As VsuperInfo = Nothing

                ' Replica logica originale: scorro tutte le righe (ordinate per PrezzoPromo DESC)
                ' e tengo lâ€™ULTIMA promo valida che matcha (quindi, di fatto, il prezzo promo piÃ¹ basso)
                For Each info As VsuperInfo In lst
                    If info.InOfferta = 1 AndAlso info.OfferteDataInizio.HasValue AndAlso info.OfferteDataFine.HasValue Then
                        If info.OfferteDataInizio.Value.Date <= today AndAlso info.OfferteDataFine.Value.Date >= today Then

                            Dim match As Boolean = False
                            If info.OfferteQntMinima > 0 AndAlso r.Qnt >= info.OfferteQntMinima Then match = True
                            If (Not match) AndAlso info.OfferteMultipli > 0 AndAlso (r.Qnt Mod info.OfferteMultipli = 0) Then match = True

                            If match AndAlso info.PrezzoPromo > 0 AndAlso info.Prezzo > 0 AndAlso info.PrezzoPromo < info.Prezzo Then
                                promoApplied = True
                                offId = info.OfferteDettagliId
                                prezzo = info.PrezzoPromo
                                chosenPromoRow = info
                            End If

                        End If
                    End If
                Next

                If promoApplied AndAlso chosenPromoRow IsNot Nothing Then
                    ' prezzoIvato su promo
                    If abRC AndAlso chosenPromoRow.IdIvaRC > -1 Then
                        prezzoIvato = prezzo * ((chosenPromoRow.ValoreIvaRC / 100) + 1)
                    ElseIf ivaUtentePct > -1 Then
                        prezzoIvato = prezzo * ((ivaUtentePct / 100) + 1)
                    Else
                        prezzoIvato = chosenPromoRow.PrezzoPromoIvato
                    End If
                Else
                    ' prezzoIvato su base
                    If abRC AndAlso baseRow.IdIvaRC > -1 Then
                        prezzoIvato = prezzo * ((baseRow.ValoreIvaRC / 100) + 1)
                    ElseIf ivaUtentePct > -1 Then
                        prezzoIvato = prezzo * ((ivaUtentePct / 100) + 1)
                    Else
                        prezzoIvato = baseRow.PrezzoIvato
                    End If
                End If

                If prezzo <= 0 OrElse prezzoIvato <= 0 Then
                    ' Protezione anti-azzeramento: se il lookup non restituisce un
                    ' prezzo valido, salvo solo la quantitÃ  e mantengo i prezzi DB.
                    cmdQtyOnly.Parameters("@Qnt").Value = r.Qnt
                    cmdQtyOnly.Parameters("@id").Value = r.Id
                    cmdQtyOnly.ExecuteNonQuery()
                    Continue For
                End If

                ' Reverse charge: replico logica â€œabilitato + idIvaRC validoâ€
                Dim idIvaRC As Integer = -1
                Dim valoreIvaRC As Double = -1
                Dim descIvaRC As String = ""

                If abRC AndAlso baseRow.IdIvaRC > -1 Then
                    idIvaRC = baseRow.IdIvaRC
                    valoreIvaRC = baseRow.ValoreIvaRC
                    descIvaRC = baseRow.DescrizioneIvaRC
                End If

                cmdU.Parameters("@Qnt").Value = r.Qnt
                ' CART-2: cambiare quantita' dal carrello non deve sostituire
                ' il prezzo unitario salvato al momento dell'add-to-cart.
                cmdU.Parameters("@IdIvaRC").Value = idIvaRC
                cmdU.Parameters("@ValoreIvaRC").Value = valoreIvaRC
                cmdU.Parameters("@DescrizioneIvaRC").Value = descIvaRC
                cmdU.Parameters("@IdEsenzioneIva").Value = idEsenzioneIva
                cmdU.Parameters("@ValoreEsenzioneIva").Value = valoreEsenzioneIva
                cmdU.Parameters("@DescrizioneEsenzioneIva").Value = descrEsenzioneIva
                cmdU.Parameters("@id").Value = r.Id

                cmdU.ExecuteNonQuery()
            Next

        End Using
    End Using

    End Sub


    Protected Sub btSvuota_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btSvuota.Click
        If Not IsAddressEditorActionAllowed(sender) Then Return
        Dim LoginId As Integer = GetLoginIdSafe(0)
        Dim SessionID As String = Me.Session.SessionID
        Me.sdsArticoli.DeleteParameters.Clear()
        If LoginId = 0 Then
            Me.sdsArticoli.DeleteParameters.Add("@SessionID", SessionID)
            Me.sdsArticoli.DeleteCommand = "delete from carrello where (SessionID=@SessionID)"
        Else
            Me.sdsArticoli.DeleteParameters.Add("@LoginId", LoginId)
            Me.sdsArticoli.DeleteCommand = "delete from carrello where (LoginId=@LoginId)"
        End If

        Me.sdsArticoli.Delete()
    End Sub

    Protected Sub btCompleta_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btCompleta.Click
        If Not IsAddressEditorActionAllowed(sender) Then Return
        If GetLoginIdSafe(0) <= 0 Then
            Session.Item("StavonelCarrello") = 1
            SafeRedirectLocal("/carrello.aspx?loginrequired=1#ksCartLoginRequired")
            Return
        End If

        'Aggiorno i prodotti e il prezzo
        Aggiorna_Prezzi_Carrello()

        'Disabilito il completa ordine, quando giÃ  cliccato
        Me.btCompleta.Visible = False

        If Me.tOrdine.Visible = True Then
            Me.tOrdine.Visible = False
            SetCheckoutStep("cart")
            Me.TableConteggi.Visible = False
            Me.btAggiorna.Enabled = True
            Me.btContinua.Enabled = True
            Me.btSvuota.Enabled = True
            'Me.Repeater1.DataBind()
            Me.lblPagamento.Text = FormatCurrencyIt(0D)
            Me.lblSpeseSped.Text = FormatCurrencyIt(0D)
            Me.lblSpeseAss.Text = FormatCurrencyIt(0D)
            Me.lblPagamento.Text = FormatCurrencyIt(0D)
        Else
            Me.TableConteggi.Visible = True
            Me.tOrdine.Visible = True
            SetCheckoutStep("checkout")
            Me.btAggiorna.Enabled = True
            Me.btContinua.Enabled = True
            Me.btSvuota.Enabled = True
        End If


        FillTableInfo()

        BindLstDestinazioneLstScegliIndirizzo
        ApplyCurrentShippingAddress()
        ApplyCheckoutStepUi()

        'Me.LblDescrDest.Text = "Destinazione predefinita: " & vbCrLf & Me.getIndirizzoPrincipale

    End Sub

Protected Sub btnVaiConfermaOrdine_Click(ByVal sender As Object, ByVal e As System.EventArgs)
    If Not IsAddressEditorActionAllowed(sender) Then Return
    MoveToCheckoutConfirmStep()
End Sub

Protected Sub lnkCheckoutStep1_Click(ByVal sender As Object, ByVal e As System.EventArgs)
    If Not IsAddressEditorActionAllowed(sender) Then Return
    SetCheckoutStep("cart")
    If tOrdine IsNot Nothing Then tOrdine.Visible = False
    If TableConteggi IsNot Nothing Then TableConteggi.Visible = False
    ApplyCheckoutStepUi()
End Sub

Protected Sub lnkCheckoutStep2_Click(ByVal sender As Object, ByVal e As System.EventArgs)
    If Not IsAddressEditorActionAllowed(sender) Then Return
    SetCheckoutStep("checkout")
    ApplyCheckoutStepUi()
End Sub

Protected Sub lnkCheckoutStep3_Click(ByVal sender As Object, ByVal e As System.EventArgs)
    If Not IsAddressEditorActionAllowed(sender) Then Return
    MoveToCheckoutConfirmStep()
End Sub

Private Sub MoveToCheckoutConfirmStep()
    Aggiorna_Prezzi_Carrello()
    LeggiVettori()
    LeggiPagamenti()
    If Not ValidateCheckoutBeforeConfirm() Then
        SetCheckoutStep("checkout")
        ApplyCheckoutStepUi()
        Return
    End If
    SetCheckoutStep("confirm")
    ApplyCheckoutStepUi()
End Sub

Protected Sub btnModificaCheckout_Click(ByVal sender As Object, ByVal e As System.EventArgs)
    If Not IsAddressEditorActionAllowed(sender) Then Return
    SetCheckoutStep("checkout")
    ApplyCheckoutStepUi()
End Sub

   Protected Sub btnModDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnModDest.Click
    If Not IsAddressEditorActionAllowed(sender) Then Return

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Exit Sub

    Dim idSel As Integer = 0
    Integer.TryParse(If(LstScegliIndirizzo IsNot Nothing, LstScegliIndirizzo.SelectedValue, "0"), idSel)
    If idSel <= 0 Then Exit Sub

    Try
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text

                ' Se predefinito, resetto gli altri
                If CHKPREDEFINITO.Checked Then
                    cmd.CommandText = "UPDATE utentiindirizzi SET Predefinito=0 WHERE UtenteId=@UtentiId"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    cmd.ExecuteNonQuery()
                End If

                ' UPDATE parametrico corretto
                cmd.CommandText =
                    "UPDATE utentiindirizzi SET " &
                    "RAGIONESOCIALEA=@ragioneSocialeA, " &
                    "NOMEA=@nomeA, " &
                    "INDIRIZZOA=@indirizzo2, " &
                    "CAPA=@cap2, " &
                    "CITTAA=@citta, " &
                    "PROVINCIAA=@provincia, " &
                    "NOTE=@note, " &
                    "ZONA=@zona, " &
                    "TELEFONOA=@telefono2, " &
                    "PREDEFINITO=@predefinito " &
                    "WHERE Id=@Id AND UtenteId=@UtentiId"

                cmd.Parameters.Clear()
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                cmd.Parameters.AddWithValue("@Id", idSel)

                ' NOTA: niente Replace("'", "''") con query parametrizzate
                cmd.Parameters.AddWithValue("@ragioneSocialeA", (If(tbRagioneSocialeA.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@nomeA", (If(tbNomeA.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@indirizzo2", (If(tbIndirizzo2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@cap2", (If(tbCap2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@citta", (If(getDdlCittaValue(Me.ddlCitta2), "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@provincia", (If(tbProvincia2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@note", (If(tbNote.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@telefono2", (If(tbTelefono2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@zona", (If(tbZona.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@predefinito", If(CHKPREDEFINITO.Checked, 1, 0))

                cmd.ExecuteNonQuery()

                ' Se non Ã¨ predefinito, garantisco che esista almeno 1 predefinito
                If Not CHKPREDEFINITO.Checked Then
                    cmd.CommandText = "UPDATE utentiindirizzi SET Predefinito=1 WHERE UtenteId=@UtentiId ORDER BY Id DESC LIMIT 1"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    cmd.ExecuteNonQuery()
                End If

            End Using
        End Using

        clear_destinazione_alternativa()

        Me.RFRagioneSocialeA.Enabled = False
        Me.RFIndirizzo2.Enabled = False
        Me.RFCitta2.Enabled = False
        Me.RFProvincia2.Enabled = False
        Me.RFCap2.Enabled = False
        Me.RFTelefono2.Enabled = False

    Catch ex As Exception
        LogEx(ex, "btnModDest_Click")
    End Try

End Sub
	
    Protected Sub btnSalvaDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnSalvaDest.Click
    If Not IsAddressEditorActionAllowed(sender) Then Return

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Exit Sub

    Try
        ' (coerente con Page_Load: se loggato aggiorno tab)
        FillTableInfo()

        Dim setAsPredef As Boolean = False
        If CHKPREDEFINITO.Checked Then
            setAsPredef = True
        ElseIf LstScegliIndirizzo Is Nothing OrElse LstScegliIndirizzo.Items.Count = 0 Then
            setAsPredef = True
        End If

        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text
                cmd.Parameters.Clear()

                If setAsPredef Then
                    cmd.CommandText = "UPDATE utentiindirizzi SET Predefinito=0 WHERE UtenteId=@UtentiId"
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    cmd.ExecuteNonQuery()
                    cmd.Parameters.Clear()
                End If

                cmd.CommandText =
                    "INSERT INTO utentiindirizzi " &
                    "(UTENTEID, RAGIONESOCIALEA, NOMEA, INDIRIZZOA, CAPA, CITTAA, PROVINCIAA, NOTE, TELEFONOA, ZONA, PREDEFINITO) " &
                    "VALUES " &
                    "(@utentiId, @ragioneSocialeA, @nomeA, @indirizzo2, @cap2, @citta, @provincia, @note, @telefono2, @zona, @predefinito)"

                cmd.Parameters.AddWithValue("@utentiId", utentiId)

                ' NOTA: niente Replace("'", "''") con query parametrizzate
                cmd.Parameters.AddWithValue("@ragioneSocialeA", (If(tbRagioneSocialeA.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@nomeA", (If(tbNomeA.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@indirizzo2", (If(tbIndirizzo2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@cap2", (If(tbCap2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@citta", (If(getDdlCittaValue(Me.ddlCitta2), "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@provincia", (If(tbProvincia2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@note", (If(tbNote.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@telefono2", (If(tbTelefono2.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@zona", (If(tbZona.Text, "")).ToUpperInvariant())
                cmd.Parameters.AddWithValue("@predefinito", If(setAsPredef, 1, 0))

                cmd.ExecuteNonQuery()

            End Using
        End Using

        clear_destinazione_alternativa()

        Me.RFRagioneSocialeA.Enabled = False
        Me.RFIndirizzo2.Enabled = False
        Me.RFCitta2.Enabled = False
        Me.RFProvincia2.Enabled = False
        Me.RFCap2.Enabled = False
        Me.RFTelefono2.Enabled = False

    Catch ex As Exception
        LogEx(ex, "btnSalvaDest_Click")
    End Try

End Sub

    Protected Sub btnElimDest_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnElimDest.Click
    If Not IsAddressEditorActionAllowed(sender) Then Return

    If LstScegliIndirizzo Is Nothing OrElse LstScegliIndirizzo.Items.Count <= 1 Then Exit Sub

    Dim idSel As Integer = 0
    Integer.TryParse(LstScegliIndirizzo.SelectedValue, idSel)
    If idSel <= 0 Then Exit Sub

    Dim utentiId As Integer = GetUtentiIdSafe(0)
    If utentiId <= 0 Then Exit Sub

    Try
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandType = CommandType.Text

                ' 1) Leggo se l'indirizzo Ã¨ predefinito
                cmd.CommandText = "SELECT Predefinito FROM utentiindirizzi WHERE Id=@id AND UtenteId=@UtentiId LIMIT 1"
                cmd.Parameters.Clear()
                cmd.Parameters.AddWithValue("@id", idSel)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)

                Dim predefinito As Integer = 0
                Dim obj As Object = cmd.ExecuteScalar()
                If obj IsNot Nothing AndAlso obj IsNot DBNull.Value Then
                    Integer.TryParse(obj.ToString(), predefinito)
                End If

                ' 2) Cancello
                cmd.CommandText = "DELETE FROM utentiindirizzi WHERE Id=@id AND UtenteId=@UtentiId"
                cmd.Parameters.Clear()
                cmd.Parameters.AddWithValue("@id", idSel)
                cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                cmd.ExecuteNonQuery()

                ' 3) Se ho cancellato il predefinito, imposto predefinito l'ultimo rimasto
                If predefinito = 1 Then
                    cmd.CommandText = "UPDATE utentiindirizzi SET Predefinito=1 WHERE UtenteId=@UtentiId ORDER BY Id DESC LIMIT 1"
                    cmd.Parameters.Clear()
                    cmd.Parameters.AddWithValue("@UtentiId", utentiId)
                    cmd.ExecuteNonQuery()
                End If

            End Using
        End Using

        clear_destinazione_alternativa()

        Me.RFRagioneSocialeA.Enabled = False
        Me.RFIndirizzo2.Enabled = False
        Me.RFCitta2.Enabled = False
        Me.RFProvincia2.Enabled = False
        Me.RFCap2.Enabled = False
        Me.RFTelefono2.Enabled = False

    Catch ex As Exception
        LogEx(ex, "btnElimDest_Click")
    End Try

End Sub

    'Mi permette di leggere dal vettore l'IVA impostata per il Vettori
    Function IvaVettore(ByVal idVettore As Integer) As Double
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim temp_iva As Double = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT vettori.*, iva.Valore FROM vettori LEFT JOIN iva ON vettori.iva=iva.id WHERE vettori.id= @IdVettore"
		cmd.Parameters.AddWithValue("@IdVettore",idVettore)
        dr = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows = True Then
            temp_iva = dr.Item("Valore")
        End If

        dr.Close()
        conn.Close()

        Return temp_iva
    End Function

    Function preleva_ValoreIva(ByVal idIva As Integer) As Double
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim temp_iva As Double = 0

        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        conn.Open()

        cmd.Connection = conn
        cmd.CommandType = CommandType.Text

        If idIva = -1 Then
            cmd.CommandText = "SELECT iva.Valore FROM ivadefault INNER JOIN iva ON ivadefault.IvaVId=iva.id WHERE CURDATE() BETWEEN dal AND al"
        Else
			cmd.Parameters.AddWithValue("@idIva",idIva)
            cmd.CommandText = "SELECT iva.Valore FROM iva WHERE iva.id=@idIva"
        End If


        dr = cmd.ExecuteReader()
        dr.Read()

        If dr.HasRows = True Then
            temp_iva = dr.Item("Valore")
        End If

        dr.Close()
        conn.Close()

        Return temp_iva
    End Function

    Function preleva_IdIva(ByVal idIva As Integer) As Integer
        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        Dim dr As MySqlDataReader
        Dim risultato As Integer = 0

        If idIva = -1 Then
            conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            conn.Open()

            cmd.Connection = conn
            cmd.CommandType = CommandType.Text

            cmd.CommandText = "SELECT IvaVid FROM ivadefault INNER JOIN iva ON ivadefault.IvaVId=iva.id WHERE CURDATE() BETWEEN dal AND al"

            dr = cmd.ExecuteReader()
            dr.Read()

            If dr.HasRows = True Then
                risultato = dr.Item("IvaVid")
            End If

            dr.Close()
            conn.Close()
        Else
            risultato = idIva
        End If

        Return risultato
    End Function

    Function calcola_iva(ByVal Spese_Spedizione As Double, ByVal ValoreIvaVettore As Integer) As Double

    Dim tot_iva As Double = 0

    ' Iva utente: qui Ã¨ trattata come PERCENTUALE (es. 22) quando > -1
    Dim ivaUtentePerc As Double = -1
    If Session("Iva_Utente") IsNot Nothing Then
        ivaUtentePerc = SafeDblFromText(Session("Iva_Utente").ToString(), -1)
    End If

    Dim rcEnabled As Boolean = (GetSessionInt("AbilitatoIvaReverseCharge", 0) = 1)

    ' -------------------- ARTICOLI NORMALI (Repeater1) --------------------
    If Repeater1.Items.Count > 0 Then
        For Each row As RepeaterItem In Repeater1.Items

            Dim lblValoreIva As Label = CType(row.FindControl("lblValoreIva"), Label)
            Dim lblIdIvaRC As Label = CType(row.FindControl("lblidIvaRC"), Label)
            Dim lblPrezzo As Label = CType(row.FindControl("lblPrezzo"), Label)
            Dim tbQta As TextBox = CType(row.FindControl("tbQta"), TextBox)

            Dim qnt As Integer = SafeIntFromText(If(tbQta IsNot Nothing, tbQta.Text, "0"), 0)
            If qnt <= 0 Then Continue For

            Dim prezzoNetto As Double = SafeMoney(If(lblPrezzo IsNot Nothing, lblPrezzo.Text, "0"), 0)

            Dim ivaPerc As Double = 0

            ' Caso esenzione / IVA utente personalizzata (percentuale)
            If ivaUtentePerc > -1 Then

                ivaPerc = ivaUtentePerc

            Else
                ' Caso Reverse Charge: qui prendo il valore IVA dalla tabella IVA (id in lblIdIvaRC)
                Dim idRc As Integer = SafeIntFromText(If(lblIdIvaRC IsNot Nothing, lblIdIvaRC.Text, "-1"), -1)

                If rcEnabled AndAlso idRc <> -1 Then
                    ivaPerc = preleva_ValoreIva(idRc)
                Else
                    ivaPerc = SafeDblFromText(If(lblValoreIva IsNot Nothing, lblValoreIva.Text, "0"), 0)
                End If
            End If

            tot_iva += (prezzoNetto * qnt) * (ivaPerc / 100)

        Next
    End If

    ' -------------------- ARTICOLI GRATIS (gvArticoliGratis) --------------------
    If gvArticoliGratis.Items.Count > 0 Then
        For Each row As RepeaterItem In gvArticoliGratis.Items

            Dim lblValoreIva As Label = CType(row.FindControl("lblValoreIva"), Label)
            Dim lblIdIvaRC As Label = CType(row.FindControl("lblidIvaRC"), Label)
            Dim lblPrezzo As Label = CType(row.FindControl("lblPrezzo"), Label)
            Dim tbQta As TextBox = CType(row.FindControl("tbQta"), TextBox)

            Dim qnt As Integer = SafeIntFromText(If(tbQta IsNot Nothing, tbQta.Text, "0"), 0)
            If qnt <= 0 Then Continue For

            Dim prezzoNetto As Double = SafeMoney(If(lblPrezzo IsNot Nothing, lblPrezzo.Text, "0"), 0)

            Dim ivaPerc As Double = 0

            If ivaUtentePerc > -1 Then
                ivaPerc = ivaUtentePerc
            Else
                Dim idRc As Integer = SafeIntFromText(If(lblIdIvaRC IsNot Nothing, lblIdIvaRC.Text, "-1"), -1)

                If rcEnabled AndAlso idRc <> -1 Then
                    ivaPerc = preleva_ValoreIva(idRc)
                Else
                    ivaPerc = SafeDblFromText(If(lblValoreIva IsNot Nothing, lblValoreIva.Text, "0"), 0)
                End If
            End If

            tot_iva += (prezzoNetto * qnt) * (ivaPerc / 100)

        Next
    End If

    ' IVA sulle spese di spedizione
    tot_iva += Spese_Spedizione * (ValoreIvaVettore / 100)

    Return Math.Round(tot_iva, 2, MidpointRounding.AwayFromZero)

    End Function

	
    Protected Sub Repeater1_ItemCommand(ByVal sender As Object, ByVal e As RepeaterCommandEventArgs) Handles Repeater1.ItemCommand
        If Not IsAddressEditorActionAllowed(sender) Then Return
		If e.CommandName = "Aggiorna" Then
            btAggiorna_Click(sender, e)
        End If

        If e.CommandName = "Elimina" Then
            eliminaRigaCarrello(e.CommandArgument)
            RedirectToCartPage()
        End If
    End Sub

    Protected Sub gvArticoliGratis_ItemCommand(ByVal sender As Object, ByVal e As RepeaterCommandEventArgs) Handles gvArticoliGratis.ItemCommand
        If Not IsAddressEditorActionAllowed(sender) Then Return
        If e.CommandName = "Aggiorna" Then
            btAggiorna_Click(sender, e)
        End If

        If e.CommandName = "Elimina" Then
            eliminaRigaCarrello(e.CommandArgument)
            RedirectToCartPage()
        End If
    End Sub

    Private Sub RedirectToCartPage()
        Response.Redirect("carrello.aspx", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Public Sub eliminaRigaCarrello(ByVal id As Object)
    Dim rowId As Integer = SafeInt(id, 0)
    If rowId <= 0 Then Exit Sub

    Dim conn As New MySqlConnection
    Dim cmd As New MySqlCommand

    Try
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn
        conn.Open()

        Dim loginId As Integer = GetLoginIdSafe(0)
        If loginId > 0 Then
            cmd.CommandText = "DELETE FROM carrello WHERE Id=@Id AND LoginId=@LoginId"
            cmd.Parameters.Clear()
            cmd.Parameters.Add("@Id", MySqlDbType.Int32).Value = rowId
            cmd.Parameters.Add("@LoginId", MySqlDbType.Int32).Value = loginId
        Else
            cmd.CommandText = "DELETE FROM carrello WHERE Id=@Id AND SessionId=@SessionId"
            cmd.Parameters.Clear()
            cmd.Parameters.Add("@Id", MySqlDbType.Int32).Value = rowId
            cmd.Parameters.Add("@SessionId", MySqlDbType.VarChar, 50).Value = If(Me.Session IsNot Nothing, Me.Session.SessionID, "")
        End If

        Dim affected As Integer = cmd.ExecuteNonQuery()
        If affected <= 0 Then
            Try
                KeepStoreLog.Info("carrello.aspx", "Rimozione articolo non applicata id=" & rowId.ToString(CultureInfo.InvariantCulture) & " loginId=" & loginId.ToString(CultureInfo.InvariantCulture), HttpContext.Current)
            Catch
            End Try
        End If
    Catch ex As Exception
        Try
            KeepStoreLog.Error("carrello.aspx", "Errore rimozione articolo carrello id=" & rowId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        Catch
        End Try
    Finally
        Try : conn.Close() : Catch : End Try
    End Try
    End Sub

    Protected Sub TB_BuonoSconto_TextChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles TB_BuonoSconto.TextChanged
    If Not IsAddressEditorActionAllowed(sender) Then Return

    Dim codice As String = If(TB_BuonoSconto.Text, "").Trim()
    If codice.Length <= 0 Then Exit Sub

    ' Recupero valori Session in modo sicuro (mantengo le stesse chiavi che usi nel codice attuale)
    Dim aziendaId As Integer = 0
    If Session("AziendaID") IsNot Nothing Then Integer.TryParse(Session("AziendaID").ToString(), aziendaId)

    Dim utenteId As Integer = GetUtentiIdSafe(0)
    If Session("UtentiId") IsNot Nothing Then Integer.TryParse(Session("UtentiId").ToString(), utenteId)

    Dim listino As String = GetListinoSafeString("")

    Dim totaleMerce As Double = 0
    If Session("TotaleMerce") IsNot Nothing Then
        Double.TryParse(Session("TotaleMerce").ToString(), NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), totaleMerce)
    End If

    ' Verifica applicabilitÃ 
    Dim ok As Integer = VerificaBuonoSconto(listaArticoliInCarrello(), codice, aziendaId, listino, utenteId, totaleMerce)

    If ok <> 0 Then

        Dim idBuono As Integer = 0

        ' FIX: connessione/command in Using, niente DataReader per un singolo ID
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString),
              cmd As New MySqlCommand("SELECT id FROM buoni_sconti WHERE buonoSconto=@CodiceBuonoSconto LIMIT 1", conn)

            cmd.Parameters.AddWithValue("@CodiceBuonoSconto", codice)

            conn.Open()
            Dim obj As Object = cmd.ExecuteScalar()

            If obj IsNot Nothing AndAlso obj IsNot DBNull.Value Then
                Integer.TryParse(obj.ToString(), idBuono)
            End If
        End Using

        If idBuono > 0 Then
            Session("BuonoSconto_id") = idBuono

            TB_BuonoSconto.Enabled = False

            checkOKBuonoSconto.Visible = True
            checkNOBuonoSconto.Visible = False

            'Descrizione convalida Codice Sconto
            lblBuonoScontoConvalida.Text = "Buono Sconto Applicato"
            lblBuonoScontoConvalida.ForeColor = Drawing.Color.Green
            lblBuonoScontoConvalida.Font.Size = 8

            'Nascondo il pulsante Applica Codice Sconto
            BT_ApplicaBuonoSconto.Enabled = False

            'Visualizzo pulsante di cancellazione BuonoSconto
            LB_CancelBuonoSconto.Visible = True
        Else
            ' Caso raro: Verifica ok ma record non trovato => tratto come non valido
            Session("BuonoSconto_id") = Nothing

            TB_BuonoSconto.Enabled = True
            lblBuonoSconto.Text = FormatCurrencyIt(0D)
            lblBuonoScontoIVA.Text = FormatCurrencyIt(0D)

            checkOKBuonoSconto.Visible = False
            checkNOBuonoSconto.Visible = True

            lblBuonoScontoConvalida.Text = "Buono Sconto non valido"
            lblBuonoScontoConvalida.ForeColor = Drawing.Color.Red
            lblBuonoScontoConvalida.Font.Size = 8

            BT_ApplicaBuonoSconto.Enabled = True
            LB_CancelBuonoSconto.Visible = False
        End If

    Else
        Session("BuonoSconto_id") = Nothing

        TB_BuonoSconto.Enabled = True
        lblBuonoSconto.Text = FormatCurrencyIt(0D)
        lblBuonoScontoIVA.Text = FormatCurrencyIt(0D)

        checkOKBuonoSconto.Visible = False
        checkNOBuonoSconto.Visible = True

        lblBuonoScontoConvalida.Text = "Buono Sconto non valido"
        lblBuonoScontoConvalida.ForeColor = Drawing.Color.Red
        lblBuonoScontoConvalida.Font.Size = 8

        BT_ApplicaBuonoSconto.Enabled = True
        LB_CancelBuonoSconto.Visible = False
    End If

    SyncCouponUiState()

    End Sub


    Public Function listaArticoliInCarrello() As String
    Dim stringa As String = ""

    Dim LoginId As Integer = 0
    If Session("LoginId") IsNot Nothing Then
        Integer.TryParse(Session("LoginId").ToString(), LoginId)
    End If

    Dim SessionID As String = ""
    If Session IsNot Nothing AndAlso Session.SessionID IsNot Nothing Then
        SessionID = Session.SessionID
    End If

    Dim listino As String = GetListinoSafeString()

    Dim whereUserId As String = ""

    Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString),
          cmd As New MySqlCommand()

        cmd.Connection = conn

        Dim Sqlstring As String = "SELECT vcarrello.*, articoli.SpedizioneGratis_Listini, articoli.SpedizioneGratis_Data_Inizio, articoli.SpedizioneGratis_Data_Fine, taglie.descrizione as taglia, colori.descrizione as colore FROM vcarrello"
        Sqlstring &= " LEFT OUTER JOIN articoli ON vcarrello.ArticoliId = articoli.id"
        Sqlstring &= " LEFT OUTER JOIN articoli_tagliecolori ON vcarrello.TCid = articoli_tagliecolori.id"
        Sqlstring &= " LEFT OUTER JOIN taglie ON articoli_tagliecolori.tagliaid = taglie.id"
        Sqlstring &= " LEFT OUTER JOIN colori ON articoli_tagliecolori.coloreid = colori.id"

        If LoginId = 0 Then
            cmd.Parameters.AddWithValue("@SessionId", SessionID)
            whereUserId = "(SessionId=@SessionId)"
        Else
            cmd.Parameters.AddWithValue("@LoginId", LoginId)
            whereUserId = "(LoginId=@LoginId)"
        End If

        cmd.Parameters.AddWithValue("@Listino", listino)

        Dim query As String =
            Sqlstring & " WHERE " & whereUserId &
            " AND (articoli.SpedizioneGratis_Listini = '' " &
            " OR (articoli.SpedizioneGratis_Listini <> '' AND (" &
            "     SpedizioneGratis_Listini NOT LIKE CONCAT('%', @Listino, ';%') " &
            "     OR SpedizioneGratis_Data_Fine < CURDATE() " &
            "     OR (SpedizioneGratis_Listini LIKE CONCAT('%', @Listino, ';%') AND SpedizioneGratis_Data_Inizio <= CURDATE() AND (SpedizioneGratis_Data_Fine >= CURDATE() OR SpedizioneGratis_Data_Fine IS NULL))" &
            " ))) ORDER BY vcarrello.id"

        cmd.CommandText = query

        conn.Open()

        Using dr As MySqlDataReader = cmd.ExecuteReader()
            While dr.Read()
                Dim artId As String = ""
                If Not IsDBNull(dr("articoliid")) Then
                    artId = dr("articoliid").ToString()
                End If

                If artId <> "" Then
                    If stringa.Trim().Length = 0 Then
                        stringa = artId
                    Else
                        stringa &= "," & artId
                    End If
                End If
            End While
        End Using

    End Using

    Return stringa
End Function


Public Function VerificaBuonoSconto(ByVal articoli As String, ByVal buonosconto As String, ByVal azienda As Integer, ByVal listino As String, ByVal utenteid As Integer, ByVal totaleMerceCarrello As Double) As Integer
    Dim retval As Integer = 0

    Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString),
          cmd As New MySqlCommand()

        cmd.Connection = conn
        conn.Open()

        ' 1) Verifica utilizzo giÃ  avvenuto (documenti)
        cmd.Parameters.Clear()
        cmd.CommandText = "SELECT id FROM documenti WHERE codicebuonosconto=@buonoSconto AND utentiid=@utenteid LIMIT 1"
        cmd.Parameters.AddWithValue("@buonoSconto", buonosconto)
        cmd.Parameters.AddWithValue("@utenteid", utenteid)

        Dim objUso As Object = cmd.ExecuteScalar()
        Dim verificaUtilizzoBuonoSconto As Integer = 0
        If objUso IsNot Nothing AndAlso objUso IsNot DBNull.Value Then
            Integer.TryParse(objUso.ToString(), verificaUtilizzoBuonoSconto)
        End If

        If verificaUtilizzoBuonoSconto <> 0 AndAlso getUtilizzoBuonoSconto(buonosconto, azienda) = 1 Then
            Return 0
        End If

        ' 2) Recupero sSql da buoni_sconti (ATTENZIONE: Ã¨ SQL salvato nel DB; lo uso come da logica esistente)
        cmd.Parameters.Clear()
        cmd.CommandText =
            "SELECT sSql FROM Buoni_Sconti " &
            "WHERE buonosconto=@buonoSconto AND idAzienda=@azienda " &
            "AND ListaListini LIKE CONCAT('%,', @listino, ',%') " &
            "AND (listautentiid=',' OR listautentiid LIKE CONCAT('%,', @utenteid, ',%')) " &
            "AND sogliaprezzo<=@totaleMerceCarrello " &
            "AND CURDATE() BETWEEN datainizio AND datafine " &
            "LIMIT 1"

        cmd.Parameters.AddWithValue("@buonoSconto", buonosconto)
        cmd.Parameters.AddWithValue("@azienda", azienda)
        cmd.Parameters.AddWithValue("@listino", listino)
        cmd.Parameters.AddWithValue("@utenteid", utenteid)
        cmd.Parameters.AddWithValue("@totaleMerceCarrello", CDec(totaleMerceCarrello))

        Dim tQueryObj As Object = cmd.ExecuteScalar()
        Dim tQuery As String = ""
        If tQueryObj IsNot Nothing AndAlso tQueryObj IsNot DBNull.Value Then
            tQuery = tQueryObj.ToString()
        End If

        If tQuery.Trim() <> "" Then
            ' Creo IN(...) parametrico a partire da "articoli" (lista ID)
            Dim ids As New List(Of Integer)
            If articoli IsNot Nothing Then
                For Each part As String In articoli.Split(","c)
                    Dim n As Integer
                    If Integer.TryParse(part.Trim(), n) Then
                        ids.Add(n)
                    End If
                Next
            End If

            If ids.Count = 0 Then
                Return 0
            End If

            Dim inParts As New List(Of String)
            cmd.Parameters.Clear()

            For i As Integer = 0 To ids.Count - 1
                Dim pName As String = "@id" & i.ToString()
                inParts.Add(pName)
                cmd.Parameters.AddWithValue(pName, ids(i))
            Next

            ' tQuery Ã¨ una subquery SQL salvata nel DB (logica originale)
            cmd.CommandText =
                "SELECT CASE WHEN COUNT(articoli.id)>0 THEN 1 ELSE 0 END AS Trovato " &
                "FROM articoli INNER JOIN (" & tQuery & ") AS Test ON articoli.id=Test.id " &
                "WHERE Test.id IN (" & String.Join(",", inParts) & ")"

            Dim foundObj As Object = cmd.ExecuteScalar()
            If foundObj IsNot Nothing AndAlso foundObj IsNot DBNull.Value Then
                Dim n As Integer = 0
                Integer.TryParse(foundObj.ToString(), n)
                retval = n
            Else
                retval = 0
            End If
        End If

    End Using

    Return retval
End Function


Public Function controllaValiditaBuonoSconto(ByVal codiceBuono As String, Optional ByVal idAzienda As Integer = 0, Optional ByVal idArticolo As Integer = -1, Optional ByVal idUtente As Integer = -1, Optional ByVal idTipoUtente As Integer = -1, Optional ByVal idListinoUtente As Integer = -1) As Integer
    Dim operatoreLogico As String = ""
    Dim tipoOperatoreLogico As Integer = 0

    ' Inizializzo a -1 per rispettare la logica dei controlli " > -1 "
    Dim idMarca As Integer = -1
    Dim idSettore As Integer = -1
    Dim idCategoria As Integer = -1
    Dim idTipologia As Integer = -1
    Dim idGruppo As Integer = -1
    Dim idSottoGruppo As Integer = -1

    Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString),
          cmd As New MySqlCommand()

        cmd.Connection = conn
        conn.Open()

        If idArticolo > -1 Then
            cmd.Parameters.Clear()
            cmd.CommandText = "SELECT * FROM articoli WHERE id=@idArticolo"
            cmd.Parameters.AddWithValue("@idArticolo", idArticolo)

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                If dr.HasRows Then
                    dr.Read()
                    If Not IsDBNull(dr("MarcheId")) Then idMarca = Convert.ToInt32(dr("MarcheId"))
                    If Not IsDBNull(dr("SettoriId")) Then idSettore = Convert.ToInt32(dr("SettoriId"))
                    If Not IsDBNull(dr("CategorieId")) Then idCategoria = Convert.ToInt32(dr("CategorieId"))
                    If Not IsDBNull(dr("TipologieId")) Then idTipologia = Convert.ToInt32(dr("TipologieId"))
                    If Not IsDBNull(dr("GruppiId")) Then idGruppo = Convert.ToInt32(dr("GruppiId"))
                    If Not IsDBNull(dr("SottogruppiId")) Then idSottoGruppo = Convert.ToInt32(dr("SottogruppiId"))
                End If
            End Using
        End If

        ' Operatore logico
        cmd.Parameters.Clear()
        cmd.CommandText = "SELECT operatoreLogico FROM buoni_sconti WHERE (buonoSconto=@buonoSconto) AND (idAzienda=@idAzienda) LIMIT 1"
        cmd.Parameters.AddWithValue("@buonoSconto", codiceBuono)
        cmd.Parameters.AddWithValue("@idAzienda", idAzienda)

        Dim opObj As Object = cmd.ExecuteScalar()
        If opObj IsNot Nothing AndAlso opObj IsNot DBNull.Value Then
            Integer.TryParse(opObj.ToString(), tipoOperatoreLogico)
        End If

        If tipoOperatoreLogico = 1 Then
            operatoreLogico = " OR "
        Else
            operatoreLogico = " AND "
        End If

        ' Creo il filtro
        Dim where As String = " WHERE ("
        Dim hasAny As Boolean = False

        cmd.Parameters.Clear()
        cmd.Parameters.AddWithValue("@codiceBuono", "")
        cmd.Parameters.AddWithValue("@id", "")

        If idMarca > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidMarca(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idMarca
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idSettore > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidSettore(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idSettore
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idCategoria > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidCategoria(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idCategoria
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idTipologia > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidTipologia(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idTipologia
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idGruppo > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidGruppo(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idGruppo
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idSottoGruppo > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidSottogruppo(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idSottoGruppo
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idArticolo > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidArticolo(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idArticolo
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idUtente > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidUtente(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idUtente
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idTipoUtente > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidTipoUtente(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idTipoUtente
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If idListinoUtente > -1 Then
            cmd.CommandText = "SELECT buoniscontiperidListinoUtente(@codiceBuono,@id)"
            cmd.Parameters("@codiceBuono").Value = codiceBuono
            cmd.Parameters("@id").Value = idListinoUtente
            If hasAny Then where &= operatoreLogico
            where &= cmd.ExecuteScalar().ToString()
            hasAny = True
        End If

        If Not hasAny Then
            where &= "1=1"
        End If

        where &= ")"

        ' Utilizzo
        cmd.CommandText = "SELECT BuoniScontiPerUtilizzo(@codiceBuono,@idUtente,@idAzienda)"
        cmd.Parameters("@codiceBuono").Value = codiceBuono

        Dim utId As Integer = GetUtentiIdSafe(0)

        If cmd.Parameters.Contains("@idUtente") Then
        cmd.Parameters("@idUtente").Value = utId
        Else
        cmd.Parameters.AddWithValue("@idUtente", utId)
        End If

        where &= " AND " & cmd.ExecuteScalar().ToString()

        ' Soglia prezzo
        cmd.CommandText = "SELECT BuoniScontiPerSogliaPrezzo(@codiceBuono,@totaleCarrello)"
        cmd.Parameters("@codiceBuono").Value = codiceBuono

        Dim totaleCarrelloVal As Double = SafeMoney(lblTotale.Text, 0)

        If cmd.Parameters.Contains("@totaleCarrello") Then
        cmd.Parameters("@totaleCarrello").Value = totaleCarrelloVal
        Else
        cmd.Parameters.AddWithValue("@totaleCarrello", totaleCarrelloVal)
        End If

        where &= " AND " & cmd.ExecuteScalar().ToString()

        ' Query finale
        cmd.CommandText = "SELECT COUNT(*) FROM buoni_sconti" & where & " AND ((buonoSconto=@codiceBuono) AND (idAzienda=@idAzienda))"
        Dim risultato As Integer = 0

        Dim resObj As Object = cmd.ExecuteScalar()
        If resObj IsNot Nothing AndAlso resObj IsNot DBNull.Value Then
            Integer.TryParse(resObj.ToString(), risultato)
        End If

        If risultato > 0 Then
            Return 1
        Else
            Return 0
        End If

    End Using
End Function


Protected Sub GV_BuoniSconti_RowCommand(ByVal sender As Object, ByVal e As System.Web.UI.WebControls.GridViewCommandEventArgs) Handles GV_BuoniSconti.RowCommand
    If Not GuardCartSessionForSensitiveAction() Then Return
    If Not IsAddressEditorActionAllowed(sender) Then Return
    If e.CommandName = "CancellaBuonoSconto" Then
        Session("BuonoSconto_id") = Nothing
        TB_BuonoSconto.Text = ""
        lblBuonoScontoConvalida.Text = ""
        BT_ApplicaBuonoSconto.Enabled = True
        SyncCouponUiState()
    End If
End Sub


'Funzione che restituisce 1 se il buono puÃ² essere utilizzato solo una volta, 0 nel caso il buono possa essere utilizzato piÃ¹ volte
Function getUtilizzoBuonoSconto(ByVal codiceBuonoSconto As String, ByVal idAzienda As Integer) As Integer
    Dim UtilizzaSoloUnaVolta As Integer = 0
    Dim paramsSelect As New Dictionary(Of String, String)
    paramsSelect.Add("codiceBuono", codiceBuonoSconto)
    paramsSelect.Add("idAzienda", idAzienda)

    Dim dr As MySqlDataReader = ExecuteQueryGetDataReader("UtilizzaSoloUnaVolta", "buoni_sconti", "(buonoSconto=@codiceBuono) AND (idAzienda=@idAzienda)", paramsSelect)

    If dr IsNot Nothing Then
        If dr.HasRows Then
            dr.Read()
            If Not IsDBNull(dr("UtilizzaSoloUnaVolta")) Then
                UtilizzaSoloUnaVolta = Convert.ToInt32(dr("UtilizzaSoloUnaVolta"))
            End If
        End If
        dr.Close()
    End If

    Return UtilizzaSoloUnaVolta
End Function


Function getBuonoScontoCodice(ByVal idBuonoSconto As Integer) As String
    Dim codiceBuonoSconto As String = ""
    Dim paramsSelect As New Dictionary(Of String, String)
    paramsSelect.Add("@IdBuonoScorto", idBuonoSconto)

    Dim dr As MySqlDataReader = ExecuteQueryGetDataReader("buonoSconto", "buoni_sconti", "id=@IdBuonoScorto", paramsSelect)

    If dr IsNot Nothing Then
        If dr.HasRows Then
            dr.Read()
            If Not IsDBNull(dr("buonoSconto")) Then
                codiceBuonoSconto = dr("buonoSconto").ToString()
            End If
        End If
        dr.Close()
    End If

    Return codiceBuonoSconto
End Function


Protected Sub btContinua_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btContinua.Click
    If Not IsAddressEditorActionAllowed(sender) Then Return
    If Session.Item("Pagina_visitata_Articoli") Is Nothing Then
        Response.Redirect("default.aspx")
    Else
        If Session.Item("Pagina_visitata_Articoli").ToString = String.Empty Then
            Response.Redirect("default.aspx")
        Else
            SafeRedirectLocal(Session.Item("Pagina_visitata_Articoli").ToString())
        End If
    End If
End Sub


Protected Sub btAggiorna_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btAggiorna.Click
    If Not IsAddressEditorActionAllowed(sender) Then Return
    Aggiorna_Prezzi_Carrello()

    ' Session("Click_AggiornaCarrello") = 1 
    Response.Redirect("carrello.aspx")
End Sub


Protected Sub LB_CancelBuonoSconto_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles LB_CancelBuonoSconto.Click
    If Not IsAddressEditorActionAllowed(sender) Then Return
    Session("BuonoSconto_id") = Nothing
    TB_BuonoSconto.Text = ""
    lblBuonoScontoConvalida.Text = ""
    BT_ApplicaBuonoSconto.Enabled = True
    LB_CancelBuonoSconto.Visible = False
    SyncCouponUiState()
End Sub


Protected Sub btSalvaPreventivo_click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btSalvaPreventivo.Click
    If Not IsAddressEditorActionAllowed(sender) Then Return
    If Not ValidateOrderNotesLength() Then Return
    Me.PnlDestinazione.Visible = False

    Me.Session("Ordine_TipoDoc") = 2
    Me.Session("Ordine_Documento") = "Preventivo"
    Me.Session("Ordine_Pagamento") = Me.tbPagamenti.Text
    Me.Session("Ordine_Vettore") = Me.tbVettoriId.Text

    Me.Session("Ordine_SpeseSped") = SafeMoney(Me.lblSpeseSped.Text, 0)
    Me.Session("Ordine_SpeseAss") = SafeMoney(Me.lblSpeseAss.Text, 0)
    Me.Session("Ordine_SpesePag") = SafeMoney(Me.lblPagamento.Text, 0)
    Me.Session("Ordine_Totale_Documento") = SafeMoney(Me.lblTotale.Text, 0)

    Session("Ordine_DescrizioneBuonoSconto") = ""
    Session("Ordine_TotaleBuonoSconto") = 0
    Session("Ordine_CodiceBuonoSconto") = ""

    Me.Session("NoteDocumento") = Me.txtNoteSpedizione.Text

    RedirectToOrdine()
End Sub


Protected Sub btInviaOrdine_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btInviaOrdine.Click
    If Not IsAddressEditorActionAllowed(sender) Then Return
    If Not IsCheckoutConfirmStep() Then
        SetCheckoutStep("checkout")
        SetAddressSelectionMessage("Rivedi il riepilogo finale prima di confermare l'ordine.")
        ApplyCheckoutStepUi()
        Return
    End If
    If Not TermsConsentAccepted() Then
        SetTermsConsentError("Per proseguire devi accettare le Condizioni Generali di Vendita.")
        SetCheckoutStep("confirm")
        ApplyCheckoutStepUi()
        Return
    End If
    SetTermsConsentError("")
    Me.PnlDestinazione.Visible = False
    If Not ValidateOrderNotesLength() Then Return
    If Not RevalidateCartPricesBeforeOrder() Then Return

    Try
        LeggiVettori()
        Aggiorna_Prezzi_Carrello()
        ApplyCurrentShippingAddress()

        If (controlla_articoli_quantita_zero() = 1) Then

            LeggiPagamenti()

            Dim paramsSelect As New Dictionary(Of String, String)
            paramsSelect.Add("@IdUtenti", GetUtentiIdSafe(0).ToString())

            Dim dr As MySqlDataReader = ExecuteQueryGetDataReader(
                "UTENTI.AZIENDEID, AZIENDE.RAGIONESOCIALE",
                "UTENTI",
                "INNER JOIN AZIENDE ON UTENTI.AZIENDEID = AZIENDE.ID WHERE UTENTI.Id=@IdUtenti",
                paramsSelect)

            If dr IsNot Nothing Then
                Try
                    If dr.HasRows Then
                        dr.Read()
                        lblIntestDestinazione.Text = dr.Item("RAGIONESOCIALE").ToString()
                    End If
                Finally
                    dr.Close()
                End Try
            End If

        Else
            Qnt_Errata.Visible = True
        End If

    Catch ex As Exception
        LogEx(ex, "btInviaOrdine_Click")
        ' (mantengo logica originale: nessun messaggio utente)
    Finally
        If (controlla_articoli_quantita_zero() = 1) Then
            If (GetLoginIdSafe(0) > 0) Then
                Cookie = "N"
                SendOrder()
            Else
                Session.Item("StavonelCarrello") = 1
                Response.Redirect("accessonegato.aspx")
            End If
        End If
    End Try
    End Sub

' =========================
' CITY REGISTRY - BLOCCO COMPLETO (Copia-Incolla)
' =========================

Protected Sub City_Bind_Data2(ByVal sender As Object, ByVal e As System.EventArgs)
    If Not GuardCartSessionForSensitiveAction() Then Return
    riempi_ddl_citta(tbCap2.Text, ddlCitta2, tbProvincia2)
    Session("cityBinding") = 1
End Sub

Protected Sub riempi_ddl_citta(ByVal cap As String, ByVal cittaddl As DropDownList, ByVal provincia As TextBox, Optional ByVal citta As String = "")
    ' CHIAMATA SAFE (evita errore compile se il metodo non esiste nella reference)
    Dim ds As DataSet = GetCitiesFromPostcodeCodeSafe(cap)

    ConvertDataSetColumnToUpper(ds, "name_city")

    If ds IsNot Nothing AndAlso ds.Tables.Count > 0 Then
        cittaddl.DataSource = ds.Tables(0)
        cittaddl.DataTextField = ds.Tables(0).Columns("name_city").ToString().ToUpper()
        cittaddl.DataValueField = ds.Tables(0).Columns("name_city").ToString().ToUpper()
        cittaddl.DataBind()
    Else
        cittaddl.Items.Clear()
    End If

    If citta <> String.Empty Then
        Try
            If cittaddl.Items.Count > 0 Then
                cittaddl.Items(cittaddl.SelectedIndex).Selected = False
                Dim it As ListItem = cittaddl.Items.FindByValue(citta)
                If it IsNot Nothing Then it.Selected = True
            End If
        Catch
        End Try
    End If

    citta = String.Empty
    If cittaddl.Items.Count > 0 Then
        citta = cittaddl.Items(cittaddl.SelectedIndex).Text
    End If

    riempi_text_provincia(citta, provincia)
End Sub

Protected Sub ConvertDataSetColumnToUpper(ByRef ds As DataSet, ByVal columnName As String)
    If ds Is Nothing OrElse ds.Tables.Count = 0 Then Exit Sub
    If ds.Tables(0) Is Nothing Then Exit Sub
    If Not ds.Tables(0).Columns.Contains(columnName) Then Exit Sub

    For Each row As DataRow In ds.Tables(0).Rows
        If row IsNot Nothing AndAlso Not IsDBNull(row(columnName)) Then
            row(columnName) = row(columnName).ToString().ToUpperInvariant()
        End If
    Next
End Sub

Protected Sub riempi_text_provincia(ByVal citta As String, ByVal provincia As TextBox)
    If citta <> String.Empty Then
        ' CHIAMATA SAFE (evita errore compile se il metodo non esiste nella reference)
        Dim ds As DataSet = GetProvinceFromCitySafe(citta)

        Try
            If ds IsNot Nothing AndAlso ds.Tables.Count > 0 AndAlso ds.Tables(0).Rows.Count > 0 Then
                provincia.Text = ds.Tables(0).Rows(0)("abbreviation").ToString()
            Else
                provincia.Text = String.Empty
            End If
        Catch
            provincia.Text = String.Empty
        End Try
    Else
        provincia.Text = String.Empty
    End If
End Sub

Protected Sub Province_Bind_Data2(ByVal sender As Object, ByVal e As System.EventArgs)
    If Not GuardCartSessionForSensitiveAction() Then Return
    riempi_text_provincia(getDdlCittaValue(ddlCitta2), tbProvincia2)
    Session("cityBinding") = 1
End Sub

Protected Function getDdlCittaValue(ByVal ddlCitta As DropDownList) As String
    Dim value As String
    Try
        value = ddlCitta.Items(ddlCitta.SelectedIndex).Text
    Catch ex As Exception
        LogEx(ex, "SendOrder")
        value = ""
    End Try
    Return value
End Function

' =========================
' CITY REGISTRY - WRAPPER SAFE (USA cityRegistry ESISTENTE)
' Fix BC30112: evita conflitto con namespace CityRegistry
' =========================

Private Function GetCitiesFromPostcodeCodeSafe(ByVal cap As String) As DataSet
    Dim ds As New DataSet()
    Dim dt As New DataTable()
    dt.Columns.Add("name_city", GetType(String))
    ds.Tables.Add(dt)
    Try
        For Each item As CityRegistryAddressOption In LoadCityRegistryOptionsByCap(cap)
            dt.Rows.Add(item.Citta)
        Next
        Return ds
    Catch ex As Exception
        LogEx(ex, "GetCitiesFromPostcodeCodeSafe")
        Return ds
    End Try
End Function

Private Function GetProvinceFromCitySafe(ByVal citta As String) As DataSet
    Dim ds As New DataSet()
    Dim dt As New DataTable()
    dt.Columns.Add("abbreviation", GetType(String))
    ds.Tables.Add(dt)
    Try
        Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            Using cmd As New MySqlCommand("SELECT abbreviation_province FROM city_registry.cities WHERE name=@Citta ORDER BY abbreviation_province LIMIT 1", conn)
                cmd.Parameters.AddWithValue("@Citta", CleanCartAddressInput(citta))
                Dim value As Object = cmd.ExecuteScalar()
                If value IsNot Nothing AndAlso value IsNot DBNull.Value Then dt.Rows.Add(value.ToString())
            End Using
        End Using
        Return ds
    Catch ex As Exception
        LogEx(ex, "GetProvinceFromCitySafe")
        Return ds
    End Try
End Function

' =========================
' ExecuteQueryGetDataReader (normalizza nomi parametri)
' =========================
Protected Function ExecuteQueryGetDataReader(ByVal fields As String, ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As MySqlDataReader

    Dim sqlString As String = "SELECT " & fields & " FROM " & table & NormalizeWherePart(wherePart)
    lastSqlString = sqlString

    Dim conn As New MySqlConnection

    Try
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        If String.IsNullOrEmpty(connectionString) Then Return Nothing

        conn.ConnectionString = connectionString
        conn.Open()

        Dim cmd As New MySqlCommand With {
            .Connection = conn,
            .CommandType = CommandType.Text,
            .CommandText = sqlString
        }

        If params IsNot Nothing Then
            For Each paramName As String In params.Keys
                Dim p As String = paramName
                If Not p.StartsWith("@") AndAlso Not p.StartsWith("?") Then
                    p = "@" & p
                End If
                cmd.Parameters.AddWithValue(p, params(paramName))
            Next
        End If

        ' IMPORTANT: chiude automaticamente la connessione quando chiudi il reader
        Return cmd.ExecuteReader(CommandBehavior.CloseConnection)

    Catch ex As Exception
        LogEx(ex, "ExecuteQueryGetDataReader", sqlString)
        Try
            If conn IsNot Nothing AndAlso conn.State = ConnectionState.Open Then conn.Close()
        Catch
        End Try
        Return Nothing
    End Try

End Function

' =========================
' NormalizeWherePart
' =========================
Private Function NormalizeWherePart(ByVal wherePart As String) As String
    Dim wp As String = If(wherePart, "").Trim()
    If wp = "" Then Return ""

    Dim up As String = wp.ToUpperInvariant()

    If up.StartsWith("WHERE ") _
        OrElse up.StartsWith("INNER ") _
        OrElse up.StartsWith("LEFT ") _
        OrElse up.StartsWith("RIGHT ") _
        OrElse up.StartsWith("JOIN ") _
        OrElse up.StartsWith("ORDER ") _
        OrElse up.StartsWith("GROUP ") _
        OrElse up.StartsWith("LIMIT ") Then

        Return " " & wp
    End If

    If up.StartsWith("AND ") OrElse up.StartsWith("OR ") Then
        Return " WHERE 1=1 " & wp
    End If

    Return " WHERE " & wp
End Function

' =========================
' ExecuteDelete (UNA SOLA DEFINIZIONE)
' =========================
Protected Function ExecuteDelete(ByVal table As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
    Dim sqlString As String = "DELETE FROM " & table & NormalizeWherePart(wherePart)
    ExecuteNonQuery(False, sqlString, params)
    Return Nothing
End Function

' =========================
' ExecuteUpdate (UNA SOLA DEFINIZIONE)
' =========================
Protected Function ExecuteUpdate(ByVal table As String, ByVal fieldAndValues As String, Optional ByVal wherePart As String = "", Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object
    Dim sqlString As String = "UPDATE " & table & " set " & fieldAndValues & NormalizeWherePart(wherePart)
    ExecuteNonQuery(False, sqlString, params)
    Return Nothing
End Function

' =========================
' ExecuteNonQuery (Using: no Finally, no End Try sbilanciati)
' =========================
Protected Function ExecuteNonQuery(ByVal isStoredProcedure As Boolean, ByVal sqlString As String, Optional ByVal params As Dictionary(Of String, String) = Nothing) As Object

    lastSqlString = sqlString

    Dim connectionString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    If String.IsNullOrEmpty(connectionString) Then Return Nothing

    Try
        Using conn As New MySqlConnection(connectionString)
            conn.Open()

            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandText = sqlString

                If params IsNot Nothing Then
                    For Each paramName As String In params.Keys

                        Dim p As String = paramName
                        If Not p.StartsWith("@") AndAlso Not p.StartsWith("?") Then
                            p = "@" & p
                        End If

                        If p = "?parPrezzo" OrElse p = "?parPrezzoIvato" OrElse p = "@parPrezzo" OrElse p = "@parPrezzoIvato" Then
                            cmd.Parameters.Add(p, MySqlDbType.Decimal).Value = ParseDecimalForDb(params(paramName), 0D)
                        Else
                            cmd.Parameters.AddWithValue(p, params(paramName))
                        End If
                    Next
                End If

                If isStoredProcedure Then
                    cmd.CommandType = CommandType.StoredProcedure
                    cmd.Parameters.AddWithValue("?parRetVal", "0")
                    cmd.Parameters("?parRetVal").Direction = ParameterDirection.Output
                Else
                    cmd.CommandType = CommandType.Text
                End If

                cmd.ExecuteNonQuery()
            End Using
        End Using

    Catch ex As Exception
        LogEx(ex, "ExecuteNonQuery", sqlString)
    End Try

    Return Nothing
End Function

' =========================
' SAFE PARSING HELPERS
' =========================

Private Function SafeIntFromText(ByVal value As Object, Optional ByVal def As Integer = 0) As Integer
    Try
        If value Is Nothing OrElse value Is DBNull.Value Then Return def

        Dim s As String = value.ToString().Trim()
        If s = "" Then Return def

        s = s.Replace(ChrW(8364), "").Replace("%", "").Trim()
        s = s.Replace("âˆ’", "-")

        ' rimuovo separatori comuni
        s = s.Replace(".", "").Replace(",", "").Replace(" ", "")

        Dim n As Integer
        If Integer.TryParse(s, n) Then Return n

        Return def
    Catch
        Return def
    End Try
End Function

Private Function SafeDblFromText(ByVal value As Object, Optional ByVal def As Double = 0) As Double
    Try
        Return Convert.ToDouble(ParseDecimalForDb(value, CDec(def)), CultureInfo.InvariantCulture)
    Catch
        Return def
    End Try
End Function
Private Function SafeInt(ByVal value As Object, Optional ByVal def As Integer = 0) As Integer
    Return SafeIntFromText(value, def)
End Function

Private Function SafeDbl(ByVal value As Object, Optional ByVal def As Double = 0) As Double
    Return SafeDblFromText(value, def)
End Function

' SafeMoney: per importi in euro (Label spesso tipo "€ 1.234,56")
Private Function SafeMoney(ByVal value As Object, Optional ByVal def As Double = 0) As Double
    Try
        Return Convert.ToDouble(ParseDecimalForDb(value, CDec(def)), CultureInfo.InvariantCulture)
    Catch
        Return def
    End Try
End Function
    ' Gestisce OnItemDataBound="rPromo_ItemDataBound" dei repeater rPromo nei template
    Protected Sub rPromo_ItemDataBound(ByVal sender As Object, ByVal e As RepeaterItemEventArgs)

    If e Is Nothing OrElse e.Item Is Nothing Then Exit Sub

    If e.Item.ItemType <> ListItemType.Item AndAlso e.Item.ItemType <> ListItemType.AlternatingItem Then
        Exit Sub
    End If

    Dim lblInOfferta As Label = TryCast(e.Item.FindControl("lblInOfferta"), Label)
    Dim lblQtaMin As Label = TryCast(e.Item.FindControl("lblQtaMin"), Label)
    Dim lblMultipli As Label = TryCast(e.Item.FindControl("lblMultipli"), Label)
    Dim lblPrezzoPromo As Label = TryCast(e.Item.FindControl("lblPrezzoPromo"), Label)
    Dim lblPrezzoPromoIvato As Label = TryCast(e.Item.FindControl("lblPrezzoPromoIvato"), Label)
    Dim lblPrezzoBase As Label = TryCast(e.Item.FindControl("lblPrezzoBase"), Label)
    Dim lblPrezzoBaseIvato As Label = TryCast(e.Item.FindControl("lblPrezzoBaseIvato"), Label)
    Dim lblDataInizio As Label = TryCast(e.Item.FindControl("lblDataInizio"), Label)
    Dim lblDataFine As Label = TryCast(e.Item.FindControl("lblDataFine"), Label)
    Dim lblOfferta As Label = TryCast(e.Item.FindControl("lblOfferta"), Label)

    If lblInOfferta Is Nothing OrElse lblOfferta Is Nothing Then Exit Sub

    Dim inOfferta As Integer = 0
    Integer.TryParse((If(lblInOfferta.Text, "")).Trim(), inOfferta)

    If inOfferta = 1 Then
        lblOfferta.Visible = True

        Dim useNetPrice As Boolean = (GetSessionInt("IvaTipo", 0) = 1)
        Dim promoPrice As String = If(useNetPrice, If(lblPrezzoPromo Is Nothing, "", lblPrezzoPromo.Text), If(lblPrezzoPromoIvato Is Nothing, "", lblPrezzoPromoIvato.Text))
        Dim basePrice As String = If(useNetPrice, If(lblPrezzoBase Is Nothing, "", lblPrezzoBase.Text), If(lblPrezzoBaseIvato Is Nothing, "", lblPrezzoBaseIvato.Text))
        Dim offerText As String = ProductPromotionDisplayHelper.BuildLegacyOfferText(
            If(lblQtaMin Is Nothing, "", lblQtaMin.Text),
            If(lblMultipli Is Nothing, "", lblMultipli.Text),
            promoPrice,
            basePrice,
            If(lblDataInizio Is Nothing, "", lblDataInizio.Text),
            If(lblDataFine Is Nothing, "", lblDataFine.Text))

        lblOfferta.Text = If(String.IsNullOrWhiteSpace(offerText), "PROMO", offerText)
    Else
        lblOfferta.Visible = False
    End If

    End Sub

    ' =========================
' RADIOBUTTON COMPAT (ASP.NET + ConwayControls)
' =========================
Private Function GetControlBool(ByVal c As Control, ByVal propName As String, Optional ByVal def As Boolean = False) As Boolean
    If c Is Nothing Then Return def
    Try
        Dim pi = c.GetType().GetProperty(propName)
        If pi Is Nothing Then Return def
        Dim v As Object = pi.GetValue(c, Nothing)
        If v Is Nothing OrElse v Is DBNull.Value Then Return def
        Return Convert.ToBoolean(v)
    Catch
        Return def
    End Try
End Function

Private Sub SetControlBool(ByVal c As Control, ByVal propName As String, ByVal value As Boolean)
    If c Is Nothing Then Exit Sub
    Try
        Dim pi = c.GetType().GetProperty(propName)
        If pi Is Nothing OrElse Not pi.CanWrite Then Exit Sub
        pi.SetValue(c, value, Nothing)
    Catch
        ' NOP
    End Try
End Sub

Private Function RbEnabled(ByVal rb As Control) As Boolean
    Return GetControlBool(rb, "Enabled", False)
End Function



    ' ============================================================
    ' SEO helpers locali (compatibilitÃ : SeoBuilder non disponibile)
    ' ============================================================

    Private Shared Sub AddOrReplaceMeta(ByVal page As System.Web.UI.Page, ByVal metaName As String, ByVal metaContent As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub

        Dim found As System.Web.UI.HtmlControls.HtmlMeta = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim m As System.Web.UI.HtmlControls.HtmlMeta = TryCast(ctrl, System.Web.UI.HtmlControls.HtmlMeta)
            If m IsNot Nothing AndAlso String.Equals(m.Name, metaName, StringComparison.OrdinalIgnoreCase) Then
                found = m
                Exit For
            End If
        Next

        If found Is Nothing Then
            If String.Equals(metaName, "description", StringComparison.OrdinalIgnoreCase) Then
                page.MetaDescription = metaContent
            ElseIf String.Equals(metaName, "keywords", StringComparison.OrdinalIgnoreCase) Then
                page.MetaKeywords = metaContent
            End If
            Exit Sub
        End If

        found.Content = metaContent
    End Sub

    Private Shared Sub SetCanonical(ByVal page As System.Web.UI.Page, ByVal canonicalUrl As String)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(canonicalUrl) Then Exit Sub

        Dim found As System.Web.UI.HtmlControls.HtmlLink = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim l As System.Web.UI.HtmlControls.HtmlLink = TryCast(ctrl, System.Web.UI.HtmlControls.HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = Convert.ToString(l.Attributes("rel"))
                If String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    found = l
                    Exit For
                End If
            End If
        Next

        If found Is Nothing Then Exit Sub

        found.Href = canonicalUrl
    End Sub
    Private Shared Function BuildSimplePageJsonLd(ByVal pageTitle As String, ByVal descr As String, ByVal canonicalUrl As String) As String
        Dim sb As New StringBuilder()
        sb.Append("{""@context"":""https://schema.org"",""@type"":""WebPage""")
        sb.Append(",""name"":""").Append(JsonEscape(pageTitle)).Append("""")
        sb.Append(",""url"":""").Append(JsonEscape(canonicalUrl)).Append("""")
        If Not String.IsNullOrEmpty(descr) Then
            sb.Append(",""description"":""").Append(JsonEscape(descr)).Append("""")
        End If
        sb.Append("}")
        Return sb.ToString()
    End Function
    Private Shared Sub SetJsonLdOnMaster(ByVal page As System.Web.UI.Page, ByVal jsonLd As String)
        Try
            Dim m As Object = page.Master
            If m IsNot Nothing Then
                Dim prop = m.GetType().GetProperty("SeoJsonLd")
                If prop IsNot Nothing AndAlso prop.CanWrite Then
                    prop.SetValue(m, jsonLd, Nothing)
                    Return
                End If
            End If
        Catch
            ' NOP
        End Try

        Try
            Dim ph As Control = page.Header.FindControl("HeadContent")
            If ph Is Nothing Then
                ' fallback: inject directly in <head>
                ph = page.Header
            End If

            Dim lit As New Literal()
            lit.ID = "litJsonLd"
            lit.Text = "<script type=""application/ld+json"">" & jsonLd & "</script>"
            ph.Controls.Add(lit)
        Catch
            ' NOP
        End Try
    End Sub

    Private Shared Function JsonEscape(ByVal s As String) As String
        If s Is Nothing Then Return ""
        Dim sb As New StringBuilder(s.Length + 16)

        For Each ch As Char In s
            Select Case ch
                Case """"c
                    ' JSON: \"
                    sb.Append("\\")
                    sb.Append(ChrW(34))
                Case "\"c
                    ' JSON: \\
                    sb.Append("\\\\")
                Case ControlChars.Cr
                    sb.Append("\\r")
                Case ControlChars.Lf
                    sb.Append("\\n")
                Case ControlChars.Tab
                    sb.Append("\\t")
                Case Else
                    Dim code As Integer = AscW(ch)
                    If code < 32 Then
                        sb.Append("\\u").Append(code.ToString("x4"))
                    Else
                        sb.Append(ch)
                    End If
            End Select
        Next

        Return sb.ToString()
    End Function
End Class

