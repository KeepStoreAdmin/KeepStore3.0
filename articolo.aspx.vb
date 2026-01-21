Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Text
Imports System.Web
Imports System.Web.UI.WebControls
Imports MySql.Data.MySqlClient

Partial Class articolo
    Inherits System.Web.UI.Page

    Private _id As Integer
    Private _tcid As Integer
    Private _tcidPresent As Boolean
    Private _listino As Integer
    Private _tcEnabled As Boolean

    Private Class ImgItem
        Public Property Url As String
        Public Property Alt As String
    End Class

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        If Not TryParseParams() Then
            Return
        End If

        _listino = GetSessionInt("listino", 0)
        _tcEnabled = (GetSessionInt("TC", 0) = 1)

        If Not IsPostBack Then
            LoadPage()
        End If
    End Sub

    Private Function TryParseParams() As Boolean
        Dim idStr As String = Convert.ToString(Request.QueryString("id"))
        If Not Integer.TryParse(idStr, _id) OrElse _id <= 0 Then
            Response.Redirect("default.aspx", True)
            Return False
        End If

        _tcidPresent = (Request.QueryString("TCid") IsNot Nothing)
        If _tcidPresent Then
            Dim tmp As Integer
            If Integer.TryParse(Convert.ToString(Request.QueryString("TCid")), tmp) AndAlso tmp >= 0 Then
                _tcid = tmp
            Else
                ' Parametro non valido -> pulisco URL
                Response.Redirect("articolo.aspx?id=" & _id.ToString(), True)
                Return False
            End If
        Else
            _tcid = 0
        End If

        Return True
    End Function

    Private Sub LoadPage()
        Dim row As DataRow = GetProductRow(_id, _tcid, includeTcidFilter:=(_tcidPresent AndAlso _tcEnabled))

        ' Se TCid presente ma non esiste (vecchio link o variante rimossa), provo a caricare senza TCid e redirigo sulla variante di default
        If row Is Nothing AndAlso _tcEnabled AndAlso _tcidPresent Then
            Dim fallback As DataRow = GetProductRow(_id, 0, includeTcidFilter:=False)
            If fallback IsNot Nothing Then
                Dim defaultTcid As Integer = GetRowInt(fallback, "TCid", 0)
                Dim redirectUrl As String = BuildProductUrl(_id, defaultTcid, includeTcid:=True)
                Response.Redirect(redirectUrl, True)
                Return
            End If
        End If

        If row Is Nothing Then
            ShowNotFound()
            Return
        End If

        BindProduct(row)
        ApplySeo(row)
    End Sub

    Private Function GetProductRow(id As Integer, tcid As Integer, includeTcidFilter As Boolean) As DataRow
        Try
            Dim sql As String = BuildProductSql(includeTcidFilter)

            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()
                Using cmd As New MySqlCommand(sql, cn)
                    cmd.Parameters.AddWithValue("@id", id)
                    cmd.Parameters.AddWithValue("@nlistino", _listino)

                    If includeTcidFilter Then
                        cmd.Parameters.AddWithValue("@tcid", tcid)
                    End If

                    Dim dt As New DataTable()
                    Using da As New MySqlDataAdapter(cmd)
                        da.Fill(dt)
                    End Using

                    If dt.Rows.Count = 0 Then Return Nothing
                    Return dt.Rows(0)
                End Using
            End Using
        Catch
            Return Nothing
        End Try
    End Function

    Private Function BuildProductSql(includeTcidFilter As Boolean) As String
        Dim sb As New StringBuilder()

        sb.AppendLine("SELECT")
        sb.AppendLine("  p.*,")
        sb.AppendLine("  IF(img1.Img IS NULL OR img1.Img='', p.Img1, img1.Img) AS Img1,")
        sb.AppendLine("  IF(img2.Img IS NULL OR img2.Img='', p.Img2, img2.Img) AS Img2,")
        sb.AppendLine("  IF(img3.Img IS NULL OR img3.Img='', p.Img3, img3.Img) AS Img3,")
        sb.AppendLine("  IF(img4.Img IS NULL OR img4.Img='', p.Img4, img4.Img) AS Img4,")
        sb.AppendLine("  IF(img5.Img IS NULL OR img5.Img='', p.Img5, img5.Img) AS Img5,")
        sb.AppendLine("  IF(img6.Img IS NULL OR img6.Img='', p.Img6, img6.Img) AS Img6,")
        sb.AppendLine("  arr.Arrivo AS Arrivo")
        sb.AppendLine("FROM (")
        sb.AppendLine("  SELECT *")
        sb.AppendLine("  FROM vsuperarticoli")
        sb.AppendLine("  WHERE ID=@id AND NListino=@nlistino")

        If includeTcidFilter Then
            sb.AppendLine("    AND TCid=@tcid")
        End If

        sb.AppendLine("  LIMIT 1")
        sb.AppendLine(") AS p")
        sb.AppendLine("LEFT JOIN articoliimmagini AS img1 ON img1.IdArticolo = p.ID AND img1.IdTC = p.TCid AND img1.ordine = 1")
        sb.AppendLine("LEFT JOIN articoliimmagini AS img2 ON img2.IdArticolo = p.ID AND img2.IdTC = p.TCid AND img2.ordine = 2")
        sb.AppendLine("LEFT JOIN articoliimmagini AS img3 ON img3.IdArticolo = p.ID AND img3.IdTC = p.TCid AND img3.ordine = 3")
        sb.AppendLine("LEFT JOIN articoliimmagini AS img4 ON img4.IdArticolo = p.ID AND img4.IdTC = p.TCid AND img4.ordine = 4")
        sb.AppendLine("LEFT JOIN articoliimmagini AS img5 ON img5.IdArticolo = p.ID AND img5.IdTC = p.TCid AND img5.ordine = 5")
        sb.AppendLine("LEFT JOIN articoliimmagini AS img6 ON img6.IdArticolo = p.ID AND img6.IdTC = p.TCid AND img6.ordine = 6")
        sb.AppendLine("LEFT JOIN (")
        sb.AppendLine("  SELECT IdArticolo, TCid, GROUP_CONCAT(DISTINCT Arrivo SEPARATOR ' / ') AS Arrivo")
        sb.AppendLine("  FROM articoli_arrivi")
        sb.AppendLine("  GROUP BY IdArticolo, TCid")
        sb.AppendLine(") AS arr ON arr.IdArticolo = p.ID AND arr.TCid = p.TCid")

        Return sb.ToString()
    End Function

    Private Sub BindProduct(row As DataRow)
        pnlProduct.Visible = True
        phNotFound.Visible = False

        Dim nome As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), GetRowString(row, "Descrizione"))
        If String.IsNullOrEmpty(nome) Then
            nome = "Articolo"
        End If

        litBreadcrumbCurrent.Text = Server.HtmlEncode(nome)
        litNome.Text = Server.HtmlEncode(nome)

        Dim codice As String = FirstNonEmpty(GetRowString(row, "Codice"), GetRowString(row, "SKU"))
        litCodice.Text = Server.HtmlEncode(codice)
        litCodice2.Text = Server.HtmlEncode(codice)

        Dim ean As String = FirstNonEmpty(GetRowString(row, "Ean"), GetRowString(row, "EAN"))
        If Not String.IsNullOrEmpty(ean) Then
            phEan.Visible = True
            phEan2.Visible = True
            litEan.Text = Server.HtmlEncode(ean)
            litEan2.Text = Server.HtmlEncode(ean)
        Else
            phEan.Visible = False
            phEan2.Visible = False
        End If

        ' Marca
        Dim brandName As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
        Dim brandId As Integer = FirstPositiveInt(GetRowInt(row, "MarcaId", 0), GetRowInt(row, "IdMarca", 0), GetRowInt(row, "MarcheId", 0))
        If brandId > 0 AndAlso Not String.IsNullOrEmpty(brandName) Then
            phBrand.Visible = True
            phBrand2.Visible = True

            lnkMarca.Text = Server.HtmlEncode(brandName)
            lnkMarca.NavigateUrl = ResolveUrl("~/articoli.aspx?mr=" & brandId.ToString())

            litMarca2.Text = Server.HtmlEncode(brandName)
        Else
            phBrand.Visible = False
            phBrand2.Visible = False
        End If

        ' Prezzi
        Dim prezzo As Nullable(Of Decimal) = GetRowDecimal(row, "PrezzoIvato")
        Dim prezzoOld As Nullable(Of Decimal) = GetRowDecimal(row, "PrezzoOldIvato")
        Dim inOfferta As Boolean = (GetRowInt(row, "InOfferta", 0) = 1)

        litPriceHtml.Text = BuildPriceHtml(prezzo, prezzoOld, inOfferta)

        ' Descrizione breve
        Dim shortDesc As String = FirstNonEmpty(GetRowString(row, "Descrizione2"), GetRowString(row, "Sottotitolo"))
        If String.IsNullOrEmpty(shortDesc) Then
            litShortDesc.Text = ""
        Else
            litShortDesc.Text = "<p>" & Server.HtmlEncode(shortDesc) & "</p>"
        End If

        ' Descrizione lunga (preferisco HTML)
        Dim longValue As String = FirstNonEmpty(GetRowString(row, "DescrizioneHTML"), GetRowString(row, "DescrizioneLunga"), GetRowString(row, "Descrizione2"))
        litLongDesc.Text = NormalizeDescriptionHtml(longValue)

        ' Disponibilità (Arrivo)
        Dim arrivo As String = GetRowString(row, "Arrivo")
        If Not String.IsNullOrEmpty(arrivo) Then
            phAvailability.Visible = True
            litAvailability.Text = Server.HtmlEncode(arrivo)
        Else
            phAvailability.Visible = False
        End If

        ' Varianti (Taglia/Colore)
        Dim currentTcid As Integer = GetRowInt(row, "TCid", _tcid)
        BindVariantsIfNeeded(_id, currentTcid)

        ' Immagini
        BindImages(row, nome)

        ' Quantità
        txtQty.Text = "1"
        litQtyHelp.Text = ""
    End Sub

    Private Sub BindVariantsIfNeeded(id As Integer, currentTcid As Integer)
        If Not _tcEnabled Then
            pnlVariants.Visible = False
            Return
        End If

        Dim options As List(Of KeyValuePair(Of Integer, String)) = LoadVariantOptions(id, _listino)
        If options Is Nothing OrElse options.Count <= 1 Then
            pnlVariants.Visible = False
            Return
        End If

        pnlVariants.Visible = True
        ddlTc.Items.Clear()

        For Each kv As KeyValuePair(Of Integer, String) In options
            ddlTc.Items.Add(New ListItem(kv.Value, kv.Key.ToString()))
        Next

        Dim sel As ListItem = ddlTc.Items.FindByValue(currentTcid.ToString())
        If sel IsNot Nothing Then
            ddlTc.ClearSelection()
            sel.Selected = True
        End If
    End Sub

    Private Function LoadVariantOptions(id As Integer, listino As Integer) As List(Of KeyValuePair(Of Integer, String))
        Dim results As New List(Of KeyValuePair(Of Integer, String))()

        Try
            Using cn As New MySqlConnection(GetConnectionString())
                cn.Open()

                Dim sql As String = "SELECT tcid, TRIM(CONCAT(nomecolore, ' ', nometaglia, ' ', descrizione)) AS descrizione " &
                                    "FROM varticolitc " &
                                    "WHERE idarticolo=@idarticolo " &
                                    "  AND id IN (SELECT id FROM vlistini WHERE idListino=@idlistino AND idArticolo=@idarticolo AND InOfferta=0) " &
                                    "ORDER BY nomecolore, nometaglia"

                Using cmd As New MySqlCommand(sql, cn)
                    cmd.Parameters.AddWithValue("@idarticolo", id)
                    cmd.Parameters.AddWithValue("@idlistino", listino)

                    Using r As MySqlDataReader = cmd.ExecuteReader()
                        While r.Read()
                            Dim tcid As Integer
                            If Not Integer.TryParse(Convert.ToString(r.GetValue(0)), tcid) Then
                                Continue While
                            End If

                            Dim descr As String = Convert.ToString(r.GetValue(1))
                            If String.IsNullOrEmpty(descr) Then
                                descr = "Variante " & tcid.ToString()
                            End If

                            results.Add(New KeyValuePair(Of Integer, String)(tcid, descr.Trim()))
                        End While
                    End Using
                End Using
            End Using
        Catch
            ' best-effort
        End Try

        Return results
    End Function

    Private Sub BindImages(row As DataRow, productName As String)
        Dim imgs As New List(Of ImgItem)()
        Dim seen As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

        For i As Integer = 1 To 6
            Dim raw As String = GetRowString(row, "Img" & i.ToString())
            Dim url As String = NormalizeImageUrl(raw)

            If String.IsNullOrEmpty(url) Then
                Continue For
            End If

            If seen.Contains(url) Then
                Continue For
            End If

            seen.Add(url)
            imgs.Add(New ImgItem() With {.Url = url, .Alt = productName})
        Next

        If imgs.Count = 0 Then
            ' Placeholder trasparente (evita layout rotto)
            Dim transparentGif As String = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="
            imgs.Add(New ImgItem() With {.Url = transparentGif, .Alt = productName})
        End If

        rptMainImages.DataSource = imgs
        rptMainImages.DataBind()

        rptThumbs.DataSource = imgs
        rptThumbs.DataBind()
    End Sub

    Private Sub ApplySeo(row As DataRow)
        Dim nome As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), "Articolo")
        Dim brand As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))

        Dim title As String
        If Not String.IsNullOrEmpty(brand) Then
            title = nome & " | " & brand
        Else
            title = nome
        End If

        Page.Title = title

        Dim metaDesc As String = BuildMetaDescription(row, nome)
        SeoBuilder.AddOrReplaceNameMeta(Page, "description", metaDesc)
        SeoBuilder.AddOrReplaceNameMeta(Page, "robots", "index,follow")

        Dim canonical As String = BuildCanonicalUrl()
        SeoBuilder.SetCanonical(Page, canonical)

        ' Open Graph
        SeoBuilder.AddOrReplacePropertyMeta(Page, "og:type", "product")
        SeoBuilder.AddOrReplacePropertyMeta(Page, "og:title", title)
        SeoBuilder.AddOrReplacePropertyMeta(Page, "og:description", metaDesc)
        SeoBuilder.AddOrReplacePropertyMeta(Page, "og:url", canonical)

        Dim img As String = NormalizeImageUrl(GetRowString(row, "Img1"))
        If Not String.IsNullOrEmpty(img) Then
            SeoBuilder.AddOrReplacePropertyMeta(Page, "og:image", MakeAbsoluteUrl(img))
        End If

        ' JSON-LD in <head>
        litJsonLdHead.Text = BuildProductJsonLd(row, canonical, metaDesc)
    End Sub

    Private Function BuildCanonicalUrl() As String
        Dim includeTcid As Boolean = (Request.QueryString("TCid") IsNot Nothing) ' come da richiesta: tieni TCid quando presente
        Dim rel As String = "~/articolo.aspx?id=" & _id.ToString()

        If includeTcid Then
            rel &= "&TCid=" & _tcid.ToString()
        End If

        Return MakeAbsoluteUrl(ResolveUrl(rel))
    End Function

    Private Function MakeAbsoluteUrl(relativeOrAbsolute As String) As String
        If String.IsNullOrEmpty(relativeOrAbsolute) Then
            Return GetSiteBaseUrl()
        End If

        If relativeOrAbsolute.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse relativeOrAbsolute.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return relativeOrAbsolute
        End If

        Dim path As String = relativeOrAbsolute
        If Not path.StartsWith("/", StringComparison.Ordinal) Then
            path = "/" & path
        End If

        Return GetSiteBaseUrl() & path
    End Function

    Private Function GetSiteBaseUrl() As String
        Dim uri As Uri = Request.Url
        Return uri.Scheme & "://" & uri.Authority
    End Function

    Private Function BuildProductJsonLd(row As DataRow, canonical As String, metaDesc As String) As String
        Try
            Dim name As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), "Articolo")
            Dim brand As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
            Dim sku As String = FirstNonEmpty(GetRowString(row, "SKU"), GetRowString(row, "Codice"), _id.ToString())
            Dim img As String = MakeAbsoluteUrl(NormalizeImageUrl(GetRowString(row, "Img1")))

            Dim prezzo As Nullable(Of Decimal) = GetRowDecimal(row, "PrezzoIvato")

            Dim parts As New List(Of String)()
            parts.Add("""@context"":""https://schema.org""")
            parts.Add("""@type"":""Product""")
            parts.Add("""name"":" & JsonString(name))
            parts.Add("""description"":" & JsonString(metaDesc))
            parts.Add("""sku"":" & JsonString(sku))
            parts.Add("""url"":" & JsonString(canonical))

            If Not String.IsNullOrEmpty(img) Then
                parts.Add("""image"":" & JsonString(img))
            End If

            If Not String.IsNullOrEmpty(brand) Then
                parts.Add("""brand"":{""@type"":""Brand"",""name"":" & JsonString(brand) & "}")
            End If

            If prezzo.HasValue AndAlso prezzo.Value > 0D Then
                Dim offer As String = "{""@type"":""Offer"",""price"":" & JsonNumber(prezzo.Value) & ",""priceCurrency"":""EUR"",""url"":" & JsonString(canonical) & "}"
                parts.Add("""offers"":" & offer)
            End If

            Dim json As String = "{" & String.Join(",", parts.ToArray()) & "}"
            Return "<script type=""application/ld+json"">" & json & "</script>"
        Catch
            Return ""
        End Try
    End Function

    Private Function JsonString(value As String) As String
        If value Is Nothing Then value = ""
        Return """" & value.Replace("\", "\\").Replace("""", "\""").Replace(vbCr, " ").Replace(vbLf, " ") & """"
    End Function

    Private Function JsonNumber(value As Decimal) As String
        Return value.ToString(System.Globalization.CultureInfo.InvariantCulture)
    End Function

    Private Function BuildMetaDescription(row As DataRow, fallbackName As String) As String
        Dim raw As String = FirstNonEmpty(GetRowString(row, "MetaDescription"), GetRowString(row, "Descrizione2"), GetRowString(row, "DescrizioneLunga"))
        If String.IsNullOrEmpty(raw) Then
            raw = fallbackName
        End If

        Dim plain As String = StripHtml(raw)
        plain = NormalizeWhitespace(plain)

        If plain.Length > 160 Then
            plain = plain.Substring(0, 157).Trim() & "..."
        End If

        Return plain
    End Function

    Private Function NormalizeDescriptionHtml(value As String) As String
        If String.IsNullOrEmpty(value) Then
            Return ""
        End If

        Dim s As String = value.Trim()

        ' Se sembra HTML, lascio passare (rimuovo solo eventuali <script>)
        Dim looksHtml As Boolean = (s.IndexOf("<"c) >= 0 AndAlso s.IndexOf(">"c) >= 0)
        If looksHtml Then
            s = RemoveScriptBlocks(s)
            Return s
        End If

        s = Server.HtmlEncode(s)
        s = s.Replace(vbCrLf, "<br />").Replace(vbLf, "<br />")
        Return "<p>" & s & "</p>"
    End Function

    Private Function RemoveScriptBlocks(html As String) As String
        If String.IsNullOrEmpty(html) Then Return ""

        Try
            Dim lower As String = html.ToLowerInvariant()
            Dim start As Integer = lower.IndexOf("<script")
            While start >= 0
                Dim endTag As Integer = lower.IndexOf("</script>", start)
                If endTag < 0 Then Exit While

                Dim endPos As Integer = endTag + 9
                html = html.Remove(start, endPos - start)

                lower = html.ToLowerInvariant()
                start = lower.IndexOf("<script")
            End While
        Catch
        End Try

        Return html
    End Function

    Private Function StripHtml(html As String) As String
        If String.IsNullOrEmpty(html) Then Return ""

        Dim inside As Boolean = False
        Dim sb As New StringBuilder()

        For Each ch As Char In html
            If ch = "<"c Then
                inside = True
            ElseIf ch = ">"c Then
                inside = False
            ElseIf Not inside Then
                sb.Append(ch)
            End If
        Next

        Return HttpUtility.HtmlDecode(sb.ToString())
    End Function

    Private Function NormalizeWhitespace(s As String) As String
        If String.IsNullOrEmpty(s) Then Return ""

        Dim sb As New StringBuilder()
        Dim prevSpace As Boolean = False

        For Each ch As Char In s
            Dim isSpace As Boolean = Char.IsWhiteSpace(ch)
            If isSpace Then
                If Not prevSpace Then
                    sb.Append(" "c)
                End If
            Else
                sb.Append(ch)
            End If
            prevSpace = isSpace
        Next

        Return sb.ToString().Trim()
    End Function

    Private Function BuildPriceHtml(prezzo As Nullable(Of Decimal), prezzoOld As Nullable(Of Decimal), inOfferta As Boolean) As String
        Dim priceText As String = ""
        If prezzo.HasValue Then
            priceText = prezzo.Value.ToString("C")
        End If

        If inOfferta AndAlso prezzoOld.HasValue AndAlso prezzoOld.Value > 0D AndAlso prezzo.HasValue AndAlso prezzoOld.Value > prezzo.Value Then
            Dim oldText As String = prezzoOld.Value.ToString("C")
            Return "<div class=""price-on-sale""><span class=""sale-price"">" & Server.HtmlEncode(priceText) & "</span><span class=""compare-at-price"">" & Server.HtmlEncode(oldText) & "</span></div>"
        End If

        Return "<div class=""price""><span class=""sale-price"">" & Server.HtmlEncode(priceText) & "</span></div>"
    End Function

    Private Function NormalizeImageUrl(raw As String) As String
        If String.IsNullOrEmpty(raw) Then Return ""

        Dim s As String = raw.Trim()
        If s.Length = 0 Then Return ""

        If s.StartsWith("http://", StringComparison.OrdinalIgnoreCase) OrElse s.StartsWith("https://", StringComparison.OrdinalIgnoreCase) Then
            Return s
        End If

        If s.StartsWith("~", StringComparison.Ordinal) Then
            Return ResolveUrl(s)
        End If

        If s.StartsWith("/", StringComparison.Ordinal) Then
            Return s
        End If

        ' Path relativo (es. Public/foto/xxx.jpg)
        If s.IndexOf("/"c) >= 0 OrElse s.IndexOf("\"c) >= 0 Then
            s = s.Replace("\", "/")
            If Not s.StartsWith("/", StringComparison.Ordinal) Then
                s = "/" & s
            End If
            Return s
        End If

        ' Solo filename
        Return ResolveUrl("~/Public/images/articoli/" & s)
    End Function

    Protected Sub ddlTc_SelectedIndexChanged(sender As Object, e As EventArgs)
        Dim selected As Integer
        If Not Integer.TryParse(ddlTc.SelectedValue, selected) Then
            selected = 0
        End If

        Response.Redirect(BuildProductUrl(_id, selected, includeTcid:=True), True)
    End Sub

    Protected Sub btnAddToCart_Click(sender As Object, e As EventArgs)
        Dim qty As Integer
        If Not Integer.TryParse(txtQty.Text, qty) OrElse qty <= 0 Then
            qty = 1
        End If
        If qty > 9999 Then qty = 9999

        Dim tcidToUse As Integer = 0
        If _tcEnabled Then
            tcidToUse = _tcid

            If pnlVariants.Visible Then
                Dim tmp As Integer
                If Integer.TryParse(ddlTc.SelectedValue, tmp) Then
                    tcidToUse = tmp
                End If
            End If
        End If

        Session("Carrello_ArticoloId") = _id
        Session("Carrello_TCId") = tcidToUse
        Session("Carrello_Quantita") = qty
        Session("Carrello_Pagina") = Request.RawUrl

        Response.Redirect("aggiungi.aspx", True)
    End Sub

    Private Function BuildProductUrl(id As Integer, tcid As Integer, includeTcid As Boolean) As String
        Dim rel As String = "~/articolo.aspx?id=" & id.ToString()
        If includeTcid Then
            rel &= "&TCid=" & tcid.ToString()
        End If
        Return ResolveUrl(rel)
    End Function

    Private Sub ShowNotFound()
        pnlProduct.Visible = False
        phNotFound.Visible = True
        litBreadcrumbCurrent.Text = "Articolo"

        ' SEO: 404 soft (noindex) + canonical verso listing
        SeoBuilder.AddOrReplaceNameMeta(Page, "robots", "noindex,follow")
        SeoBuilder.SetCanonical(Page, MakeAbsoluteUrl(ResolveUrl("~/articoli.aspx")))
    End Sub

    '----- Helpers: safe read + session -----

    Private Function GetRowString(row As DataRow, col As String) As String
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(col) Then
            Return ""
        End If
        If row.IsNull(col) Then Return ""
        Return Convert.ToString(row(col))
    End Function

    Private Function GetRowInt(row As DataRow, col As String, defaultValue As Integer) As Integer
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(col) OrElse row.IsNull(col) Then
            Return defaultValue
        End If
        Dim tmp As Integer
        If Integer.TryParse(Convert.ToString(row(col)), tmp) Then
            Return tmp
        End If
        Return defaultValue
    End Function

    Private Function GetRowDecimal(row As DataRow, col As String) As Nullable(Of Decimal)
        If row Is Nothing OrElse row.Table Is Nothing OrElse Not row.Table.Columns.Contains(col) OrElse row.IsNull(col) Then
            Return Nothing
        End If
        Dim tmp As Decimal
        If Decimal.TryParse(Convert.ToString(row(col)), tmp) Then
            Return tmp
        End If
        Return Nothing
    End Function

    Private Function GetSessionInt(key As String, defaultValue As Integer) As Integer
        Try
            If Session(key) Is Nothing Then Return defaultValue
            Dim tmp As Integer
            If Integer.TryParse(Convert.ToString(Session(key)), tmp) Then
                Return tmp
            End If
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function FirstNonEmpty(ParamArray values() As String) As String
        If values Is Nothing Then Return ""
        For Each v As String In values
            If Not String.IsNullOrEmpty(v) Then
                Dim s As String = v.Trim()
                If s.Length > 0 Then Return s
            End If
        Next
        Return ""
    End Function

    Private Function FirstPositiveInt(ParamArray values() As Integer) As Integer
        If values Is Nothing Then Return 0
        For Each v As Integer In values
            If v > 0 Then Return v
        Next
        Return 0
    End Function

    Private Function GetConnectionString() As String
        Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    End Function

End Class
