Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Text
Imports System.Web
Imports System.Web.UI.WebControls
Imports HtmlAgilityPack
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

    Private Class RelatedItem
        Public Property Id As Integer
        Public Property Tcid As Integer
        Public Property Nome As String
        Public Property Img As String
        Public Property Url As String
        Public Property PrezzoHtml As String
        Public Property InOfferta As Boolean
        Public Property Codice As String
        Public Property AvailabilityText As String
    End Class

    Private Class PriceContext
        Public Property CurrentPrice As Nullable(Of Decimal)
        Public Property OldPrice As Nullable(Of Decimal)
        Public Property IsPromo As Boolean
        Public Property IvaLabel As String
    End Class

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        If Not TryParseParams() Then
            Return
        End If

        ' ==========================================================
        ' LISTINO: nel progetto è gestito principalmente tramite Session("Listino")
        ' (default anonimi = 1). Alcune parti legacy usano anche Session("listino").
        ' Se qui leggiamo 0, la query su vsuperarticoli (NListino=@nlistino) non
        ' ritorna righe e si ottiene "Articolo non trovato" con ID valido.
        ' ==========================================================
        _listino = GetCurrentListino()
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
            ' Nel DB Taikun/KeepStore il "non variante" è storicamente TCid = -1.
            ' Il listing (articoli.aspx) costruisce link includendo sempre TCid; se qui
            ' rifiutiamo -1, generiamo redirect e (con listino errato) si arriva al "non trovato".
            If Integer.TryParse(Convert.ToString(Request.QueryString("TCid")), tmp) AndAlso tmp >= -1 Then
                _tcid = tmp
            Else
                ' Parametro non valido -> pulisco URL
                Response.Redirect("articolo.aspx?id=" & _id.ToString(), True)
                Return False
            End If
        Else
            ' Coerenza col progetto: default TCid = -1
            _tcid = -1
        End If

        Return True
    End Function

    Private Sub LoadPage()
        Dim row As DataRow = GetProductRow(_id, _tcid, includeTcidFilter:=(_tcidPresent AndAlso _tcEnabled AndAlso _tcid > 0))

        ' Se TCid presente ma non esiste (vecchio link o variante rimossa), provo a caricare senza TCid e redirigo sulla variante di default
        If row Is Nothing AndAlso _tcEnabled AndAlso _tcidPresent Then
            Dim fallback As DataRow = GetProductRow(_id, -1, includeTcidFilter:=False)
            If fallback IsNot Nothing Then
                Dim defaultTcid As Integer = GetRowInt(fallback, "TCid", -1)
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
        TrackRecentlyViewed(_id)
        ApplySeo(row)
        BindProductRelations(row)
    End Sub

    Private Sub BindProductRelations(row As DataRow)
        BindRelatedProducts(row)
        BindPairRelationSection(phCompatible, rptCompatible, "articoli_compatibili", "ArticoliCompatibiliId", "compatibili", row)
        BindPairRelationSection(phLinked, rptLinked, "articoli_collegati", "ArticoliCollegatiId", "collegati", row)
    End Sub

    Private Sub BindRelatedProducts(row As DataRow)
        ' Correlati "AI-like" basati solo su tabelle esistenti.
        ' Strategia:
        ' 1) stessa categoria (CategorieId)
        ' 2) stesso brand (MarcheId)
        ' Ordinamento: popolarità + disponibilità + offerta.
        Try
            Dim catId As Integer = GetRowInt(row, "CategorieId", 0)
            Dim marcaId As Integer = GetRowInt(row, "MarcheId", 0)

            Dim items As List(Of RelatedItem) = LoadManualRelated(8)
            If items.Count < 8 Then
                AddUniqueRelatedItems(items, LoadRelatedInternal(catId, marcaId, 8), 8)
            End If
            If items Is Nothing OrElse items.Count = 0 Then
                phRelated.Visible = False
                Return
            End If

            phRelated.Visible = True
            rptRelated.DataSource = items
            rptRelated.DataBind()
        Catch ex As Exception
            ' Non blocca la pagina prodotto se fallisce la sezione correlati
            phRelated.Visible = False
            KeepStoreLog.Error("articolo.aspx", "Errore BindRelatedProducts (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try
    End Sub

    Private Sub BindPairRelationSection(holder As PlaceHolder, repeater As Repeater, tableName As String, relationColumn As String, logLabel As String, currentRow As DataRow)
        Try
            Dim items As List(Of RelatedItem) = LoadPairRelation(tableName, relationColumn, 8)
            If (items Is Nothing OrElse items.Count = 0) AndAlso currentRow IsNot Nothing Then
                items = LoadSmartRelationFallback(currentRow, logLabel, 8)
            End If

            If items Is Nothing OrElse items.Count = 0 Then
                holder.Visible = False
                Return
            End If

            holder.Visible = True
            repeater.DataSource = items
            repeater.DataBind()
        Catch ex As Exception
            holder.Visible = False
            KeepStoreLog.Error("articolo.aspx", "Errore BindPairRelationSection " & logLabel & " (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try
    End Sub

    Private Sub AddUniqueRelatedItems(target As List(Of RelatedItem), source As List(Of RelatedItem), maxItems As Integer)
        If target Is Nothing OrElse source Is Nothing Then Exit Sub

        Dim seen As New HashSet(Of Integer)()
        For Each it As RelatedItem In target
            seen.Add(it.Id)
        Next

        For Each it As RelatedItem In source
            If target.Count >= maxItems Then Exit For
            If it Is Nothing OrElse it.Id <= 0 Then Continue For
            If seen.Contains(it.Id) Then Continue For
            target.Add(it)
            seen.Add(it.Id)
        Next
    End Sub

    Private Function LoadManualRelated(maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()
        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()
            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                cmd.CommandText = RelatedSelectSql("articoli_correlati rel JOIN vsuperarticoli v ON v.id = rel.ArticoloFiglioId",
                                                   "WHERE v.NListino=?n AND rel.ArticoloPadreId=?idParent AND rel.ArticoloFiglioId<>?idChild AND rel.ArticoloFiglioId>0 " &
                                                   "ORDER BY rel.id ASC, v.InOfferta DESC, (v.Giacenza-v.Impegnata) DESC, v.visite DESC, v.id DESC " &
                                                   "LIMIT " & SafeLimit(maxItems * 2))
                cmd.Parameters.AddWithValue("?n", _listino)
                cmd.Parameters.AddWithValue("?idParent", _id)
                cmd.Parameters.AddWithValue("?idChild", _id)
                AppendRelated(cmd, results, maxItems)
            End Using
        End Using

        Return results
    End Function

    Private Function LoadPairRelation(tableName As String, relationColumn As String, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()

        If Not ((tableName = "articoli_compatibili" AndAlso relationColumn = "ArticoliCompatibiliId") OrElse
                (tableName = "articoli_collegati" AndAlso relationColumn = "ArticoliCollegatiId")) Then
            Return results
        End If

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()
            Using cmd As New MySqlCommand()
                cmd.Connection = conn
                Dim joinSql As String = tableName & " rel JOIN vsuperarticoli v ON v.id = CASE WHEN rel.ArticoliId=?idJoin THEN rel." & relationColumn & " ELSE rel.ArticoliId END"
                Dim whereSql As String = "WHERE v.NListino=?n AND (rel.ArticoliId=?idA OR rel." & relationColumn & "=?idB) AND v.id<>?idCurrent " &
                                         "ORDER BY rel.id ASC, v.InOfferta DESC, (v.Giacenza-v.Impegnata) DESC, v.visite DESC, v.id DESC " &
                                         "LIMIT " & SafeLimit(maxItems * 2)
                cmd.CommandText = RelatedSelectSql(joinSql, whereSql)
                cmd.Parameters.AddWithValue("?idJoin", _id)
                cmd.Parameters.AddWithValue("?n", _listino)
                cmd.Parameters.AddWithValue("?idA", _id)
                cmd.Parameters.AddWithValue("?idB", _id)
                cmd.Parameters.AddWithValue("?idCurrent", _id)
                AppendRelated(cmd, results, maxItems)
            End Using
        End Using

        Return results
    End Function

    Private Function RelatedSelectSql(fromSql As String, tailSql As String) As String
        Return "SELECT v.id, v.TCid, v.Codice, v.Descrizione1, v.Img1, v.InOfferta, " &
               "v.Prezzo, v.PrezzoIvato, v.PrezzoPromo, v.PrezzoPromoIvato, " &
               "v.Giacenza, v.Impegnata, v.Disponibilita, v.InOrdine " &
               "FROM " & fromSql & " " & tailSql
    End Function

    Private Function SafeLimit(value As Integer) As String
        If value <= 0 Then value = 8
        If value > 24 Then value = 24
        Return value.ToString()
    End Function

    Private Function LoadRelatedInternal(catId As Integer, marcaId As Integer, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()

        Dim connString As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

        Using conn As New MySqlConnection(connString)
            conn.Open()

            ' 1) stessa categoria
            If catId > 0 Then
                Using cmd As New MySqlCommand()
                    cmd.Connection = conn
                    cmd.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                       "WHERE v.NListino=?n AND v.id<>?id AND v.CategorieId=?cat " &
                                                       "ORDER BY v.InOfferta DESC, (v.Giacenza-v.Impegnata) DESC, v.visite DESC, v.id DESC " &
                                                       "LIMIT " & SafeLimit(maxItems))
                    cmd.Parameters.AddWithValue("?n", _listino)
                    cmd.Parameters.AddWithValue("?id", _id)
                    cmd.Parameters.AddWithValue("?cat", catId)
                    AppendRelated(cmd, results, maxItems)
                End Using
            End If

            ' 2) stessa marca (integrazione se non basta)
            If (results.Count < maxItems) AndAlso (marcaId > 0) Then
                Using cmd2 As New MySqlCommand()
                    cmd2.Connection = conn
                    cmd2.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                        "WHERE v.NListino=?n AND v.id<>?id AND v.MarcheId=?mr " &
                                                        "ORDER BY v.InOfferta DESC, (v.Giacenza-v.Impegnata) DESC, v.visite DESC, v.id DESC " &
                                                        "LIMIT " & SafeLimit(maxItems))
                    cmd2.Parameters.AddWithValue("?n", _listino)
                    cmd2.Parameters.AddWithValue("?id", _id)
                    cmd2.Parameters.AddWithValue("?mr", marcaId)
                    AppendRelated(cmd2, results, maxItems)
                End Using
            End If
        End Using

        Return results
    End Function

    Private Function LoadSmartRelationFallback(row As DataRow, relationMode As String, maxItems As Integer) As List(Of RelatedItem)
        Dim results As New List(Of RelatedItem)()
        If row Is Nothing Then Return results

        Dim catId As Integer = GetRowInt(row, "CategorieId", 0)
        Dim tipologiaId As Integer = GetRowInt(row, "TipologieId", 0)
        Dim marcaId As Integer = FirstPositiveInt(GetRowInt(row, "MarcaId", 0), GetRowInt(row, "IdMarca", 0), GetRowInt(row, "MarcheId", 0))

        Try
            Using conn As New MySqlConnection(GetConnectionString())
                conn.Open()

                If relationMode = "compatibili" AndAlso tipologiaId > 0 Then
                    Using cmd As New MySqlCommand()
                        cmd.Connection = conn
                        cmd.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                           "WHERE v.NListino=?n AND v.id<>?id AND v.TipologieId=?tp " &
                                                           "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                           "LIMIT " & SafeLimit(maxItems))
                        cmd.Parameters.AddWithValue("?n", _listino)
                        cmd.Parameters.AddWithValue("?id", _id)
                        cmd.Parameters.AddWithValue("?tp", tipologiaId)
                        AppendRelated(cmd, results, maxItems)
                    End Using
                End If

                If results.Count < maxItems AndAlso relationMode = "collegati" AndAlso marcaId > 0 Then
                    Using cmdBrand As New MySqlCommand()
                        cmdBrand.Connection = conn
                        cmdBrand.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                                "WHERE v.NListino=?n AND v.id<>?id AND v.MarcheId=?mr " &
                                                                "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                                "LIMIT " & SafeLimit(maxItems))
                        cmdBrand.Parameters.AddWithValue("?n", _listino)
                        cmdBrand.Parameters.AddWithValue("?id", _id)
                        cmdBrand.Parameters.AddWithValue("?mr", marcaId)
                        AppendRelated(cmdBrand, results, maxItems)
                    End Using
                End If

                If results.Count < maxItems AndAlso catId > 0 Then
                    Using cmdCat As New MySqlCommand()
                        cmdCat.Connection = conn
                        cmdCat.CommandText = RelatedSelectSql("vsuperarticoli v",
                                                              "WHERE v.NListino=?n AND v.id<>?id AND v.CategorieId=?cat " &
                                                              "ORDER BY ((v.Giacenza-v.Impegnata)>0) DESC, v.InOfferta DESC, v.visite DESC, v.id DESC " &
                                                              "LIMIT " & SafeLimit(maxItems))
                        cmdCat.Parameters.AddWithValue("?n", _listino)
                        cmdCat.Parameters.AddWithValue("?id", _id)
                        cmdCat.Parameters.AddWithValue("?cat", catId)
                        AppendRelated(cmdCat, results, maxItems)
                    End Using
                End If
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore LoadSmartRelationFallback " & relationMode & " (id=" & _id.ToString() & ")", ex, HttpContext.Current)
        End Try

        Return results
    End Function

    Private Sub AppendRelated(cmd As MySqlCommand, results As List(Of RelatedItem), maxItems As Integer)
        Dim seen As New HashSet(Of Integer)()
        For Each it As RelatedItem In results
            seen.Add(it.Id)
        Next

        Using rdr As MySqlDataReader = cmd.ExecuteReader()
            While rdr.Read() AndAlso results.Count < maxItems
                Dim idVal As Integer = SafeInt(rdr("id"), 0)
                If idVal <= 0 Then Continue While
                If seen.Contains(idVal) Then Continue While

                Dim tcidVal As Integer = SafeInt(rdr("TCid"), -1)
                Dim codiceVal As String = Convert.ToString(rdr("Codice"))
                Dim nameVal As String = Convert.ToString(rdr("Descrizione1"))
                Dim imgVal As String = NormalizeImageUrl(Convert.ToString(rdr("Img1")))
                Dim inOfferta As Integer = SafeInt(rdr("InOfferta"), 0)

                Dim price As PriceContext = BuildPriceContext(SafeDec(rdr("Prezzo"), 0D),
                                                               SafeDec(rdr("PrezzoIvato"), 0D),
                                                               SafeDec(rdr("PrezzoPromo"), 0D),
                                                               SafeDec(rdr("PrezzoPromoIvato"), 0D),
                                                               inOfferta)

                Dim item As New RelatedItem()
                item.Id = idVal
                item.Tcid = tcidVal
                item.Nome = nameVal
                item.Img = imgVal
                item.Url = BuildProductUrl(idVal, tcidVal, includeTcid:=(_tcEnabled AndAlso tcidVal <> -1))
                item.PrezzoHtml = BuildPriceHtml(price.CurrentPrice, price.OldPrice, price.IsPromo)
                item.InOfferta = (inOfferta = 1)
                item.Codice = codiceVal
                item.AvailabilityText = BuildRelatedAvailabilityText(SafeInt(rdr("Giacenza"), 0),
                                                                     SafeInt(rdr("Impegnata"), 0),
                                                                     SafeInt(rdr("Disponibilita"), 0),
                                                                     SafeInt(rdr("InOrdine"), 0))

                results.Add(item)
                seen.Add(idVal)
            End While
        End Using
    End Sub

    Private Function BuildRelatedAvailabilityText(giacenza As Integer, impegnata As Integer, disponibilita As Integer, inOrdine As Integer) As String
        If (giacenza - impegnata) > 0 Then Return "Disponibile"
        If disponibilita > 0 Then Return "In arrivo"
        If inOrdine > 0 Then Return "In ordine"
        Return "Verifica disponibilita"
    End Function

    Private Function SafeInt(v As Object, fallback As Integer) As Integer
        If v Is Nothing OrElse v Is DBNull.Value Then Return fallback
        Dim n As Integer
        If Integer.TryParse(Convert.ToString(v), n) Then Return n
        Return fallback
    End Function

    Private Function SafeDec(v As Object, fallback As Decimal) As Decimal
        If v Is Nothing OrElse v Is DBNull.Value Then Return fallback
        Dim d As Decimal
        If Decimal.TryParse(Convert.ToString(v), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, d) Then Return d
        If Decimal.TryParse(Convert.ToString(v), d) Then Return d
        Return fallback
    End Function


    Private Function GetProductRow(id As Integer, tcid As Integer, includeTcidFilter As Boolean) As DataRow
        ' Nota: in alcuni DB TCid "non variante" puo' essere -1 oppure 0.
        ' Per evitare falsi "Articolo non trovato" quando arriva TCid dal listing,
        ' se il filtro TCid non restituisce righe riproviamo senza filtro.
        Try
            Dim row As DataRow = TryGetProductRowInternal(id, tcid, includeTcidFilter)
            If row Is Nothing AndAlso includeTcidFilter Then
                row = TryGetProductRowInternal(id, tcid, False)
            End If
            Return row
        Catch ex As Exception
            KeepStoreLog.Error("articolo.aspx", "Errore GetProductRow (id=" & id.ToString() & ", tcid=" & tcid.ToString() & ", listino=" & _listino.ToString() & ")", ex, HttpContext.Current)
            Return Nothing
        End Try
    End Function

    Private Function TryGetProductRowInternal(id As Integer, tcid As Integer, includeTcidFilter As Boolean) As DataRow
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
    End Function

    Private Function BuildProductSql(includeTcidFilter As Boolean) As String
        Dim sb As New StringBuilder()

        sb.AppendLine("SELECT *")
        sb.AppendLine("FROM vsuperarticoli")
        sb.AppendLine("WHERE ID=@id AND NListino=@nlistino")

        If includeTcidFilter Then
            sb.AppendLine("  AND TCid=@tcid")
        End If

        sb.AppendLine("LIMIT 1")
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

        Dim categoryName As String = FirstNonEmpty(GetRowString(row, "TipologieDescrizione"), GetRowString(row, "CategorieDescrizione"), GetRowString(row, "SettoriDescrizione"))
        If String.IsNullOrEmpty(categoryName) Then
            categoryName = "Catalogo"
        End If
        lnkCategory.Text = Server.HtmlEncode(categoryName)
        lnkCategory.NavigateUrl = BuildCategoryCatalogUrl(row)
        phCategoryFeature.Visible = (Not String.IsNullOrEmpty(categoryName))
        phCategoryInfo.Visible = phCategoryFeature.Visible
        litCategory2.Text = Server.HtmlEncode(categoryName)
        litCategoryInfo.Text = Server.HtmlEncode(categoryName)

        Dim codice As String = FirstNonEmpty(GetRowString(row, "Codice"), GetRowString(row, "SKU"))
        litCodice.Text = Server.HtmlEncode(codice)
        litCodice2.Text = Server.HtmlEncode(codice)
        litCodice3.Text = Server.HtmlEncode(codice)
        litCodice4.Text = Server.HtmlEncode(codice)

        Dim ean As String = FirstNonEmpty(GetRowString(row, "Ean"), GetRowString(row, "EAN"))
        If Not String.IsNullOrEmpty(ean) Then
            phEan.Visible = True
            phEan2.Visible = True
            phEan3.Visible = True
            phEanInfo.Visible = True
            litEan.Text = Server.HtmlEncode(ean)
            litEan2.Text = Server.HtmlEncode(ean)
            litEan3.Text = Server.HtmlEncode(ean)
            litEan4.Text = Server.HtmlEncode(ean)
        Else
            phEan.Visible = False
            phEan2.Visible = False
            phEan3.Visible = False
            phEanInfo.Visible = False
            litEan3.Text = String.Empty
            litEan4.Text = String.Empty
        End If

        ' Marca
        Dim brandName As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
        Dim brandId As Integer = FirstPositiveInt(GetRowInt(row, "MarcaId", 0), GetRowInt(row, "IdMarca", 0), GetRowInt(row, "MarcheId", 0))
        If brandId > 0 AndAlso Not String.IsNullOrEmpty(brandName) Then
            phBrand.Visible = True
            phBrand2.Visible = True
            phBrandFeature.Visible = True
            phBrandInfo.Visible = True

            lnkMarca.Text = Server.HtmlEncode(brandName)
            lnkMarca.NavigateUrl = BuildBrandCatalogUrl(row, brandId)

            litMarca2.Text = Server.HtmlEncode(brandName)
            litMarcaFeature.Text = Server.HtmlEncode(brandName)
            litMarcaInfo.Text = Server.HtmlEncode(brandName)
        Else
            phBrand.Visible = False
            phBrand2.Visible = False
            phBrandFeature.Visible = False
            phBrandInfo.Visible = False
            litMarcaFeature.Text = String.Empty
            litMarcaInfo.Text = String.Empty
        End If

        ' Prezzi
        Dim price As PriceContext = BuildPriceContext(GetRowDecimal(row, "Prezzo"),
                                                      GetRowDecimal(row, "PrezzoIvato"),
                                                      GetRowDecimal(row, "PrezzoPromo"),
                                                      GetRowDecimal(row, "PrezzoPromoIvato"),
                                                      GetRowInt(row, "InOfferta", 0))

        litPriceHtml.Text = BuildPriceHtml(price.CurrentPrice, price.OldPrice, price.IsPromo)
        ' Box prezzo sticky (stesso HTML del prezzo principale)
        litPriceHtml2.Text = litPriceHtml.Text

        Dim isRefurbished As Boolean = (GetRowInt(row, "Ricondizionato", 0) = 1)
        phRefurbished.Visible = isRefurbished
        If isRefurbished Then
            Dim noteRefurbished As String = GetRowString(row, "NoteRicondizionato")
            If Not String.IsNullOrWhiteSpace(noteRefurbished) Then
                litRefurbishedNote.Text = "<span class='body-text-3' style='font-weight:500;'>" & Server.HtmlEncode(noteRefurbished) & "</span>"
            Else
                litRefurbishedNote.Text = String.Empty
            End If
        Else
            litRefurbishedNote.Text = String.Empty
        End If

        ' Descrizione breve
        Dim shortDesc As String = FirstNonEmpty(GetRowString(row, "Descrizione2"), GetRowString(row, "Sottotitolo"))
        If String.IsNullOrEmpty(shortDesc) Then
            litShortDesc.Text = ""
        Else
            litShortDesc.Text = "<li><p class=""body-text-3"">" & Server.HtmlEncode(shortDesc) & "</p></li>"
        End If

        ' Descrizione lunga (preferisco HTML)
        Dim longValue As String = FirstNonEmpty(GetRowString(row, "DescrizioneHTML"), GetRowString(row, "DescrizioneLunga"), GetRowString(row, "Descrizione2"))
        litLongDesc.Text = NormalizeDescriptionHtml(longValue)

        ' Disponibilità (Arrivo)
        Dim availabilityText As String = BuildAvailabilityText(row)
        phAvailability.Visible = Not String.IsNullOrEmpty(availabilityText)
        phAvailabilityInfo.Visible = phAvailability.Visible
        litAvailability.Text = Server.HtmlEncode(availabilityText)
        litBuyBoxAvailability.Text = Server.HtmlEncode(availabilityText)
        litAvailabilityInfo.Text = Server.HtmlEncode(availabilityText)

        ' Varianti (Taglia/Colore)
        Dim currentTcid As Integer = GetRowInt(row, "TCid", _tcid)
        ' Mantengo il TCid effettivo caricato (serve per Aggiungi al carrello anche quando il dropdown non è visibile)
        _tcid = currentTcid
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
                                    "  AND id IN (SELECT id FROM vlistini WHERE idListino=@idlistino AND idArticolo=@idarticolo) " &
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
            imgs.Add(New ImgItem() With {.Url = ThemeManager.PlaceholderProductImageUrl(), .Alt = productName})
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
        ' Miglioramento SEO/AI:
        ' - JSON-LD @graph coerente (Organization + WebSite + WebPage + BreadcrumbList + Product)
        ' - Include GTIN (EAN) se presente
        ' - Offer con currency e (se disponibile) availability
        Try
            Dim js As New System.Web.Script.Serialization.JavaScriptSerializer()

            Dim name As String = FirstNonEmpty(GetRowString(row, "Descrizione1"), GetRowString(row, "Nome"), "Articolo")
            Dim brand As String = FirstNonEmpty(GetRowString(row, "MarcheDescrizione"), GetRowString(row, "Marca"))
            Dim sku As String = FirstNonEmpty(GetRowString(row, "SKU"), GetRowString(row, "Codice"), _id.ToString())
            Dim ean As String = FirstNonEmpty(GetRowString(row, "Ean"), GetRowString(row, "EAN"))

            Dim img As String = NormalizeImageUrl(GetRowString(row, "Img1"))
            If Not String.IsNullOrEmpty(img) Then
                img = MakeAbsoluteUrl(img)
            End If

            Dim price As PriceContext = BuildPriceContext(GetRowDecimal(row, "Prezzo"),
                                                          GetRowDecimal(row, "PrezzoIvato"),
                                                          GetRowDecimal(row, "PrezzoPromo"),
                                                          GetRowDecimal(row, "PrezzoPromoIvato"),
                                                          GetRowInt(row, "InOfferta", 0))

            ' --- Base entity ids
            Dim baseUrl As String = canonical.TrimEnd("/"c)
            Dim orgId As String = baseUrl & "#organization"
            Dim webSiteId As String = baseUrl & "#website"
            Dim webPageId As String = baseUrl & "#webpage"
            Dim productId As String = baseUrl & "#product"

            ' --- Organization (dati best-effort da Session)
            Dim orgName As String = ""
            Try
                orgName = TryCast(Session("AziendaNome"), String)
            Catch
            End Try
            If String.IsNullOrEmpty(orgName) Then orgName = "Taikun"

            Dim organization As New Dictionary(Of String, Object)()
            organization("@type") = "Organization"
            organization("@id") = orgId
            organization("name") = orgName
            organization("url") = Request.Url.GetLeftPart(UriPartial.Authority) & ResolveUrl("~/")

            ' --- WebSite
            Dim webSite As New Dictionary(Of String, Object)()
            webSite("@type") = "WebSite"
            webSite("@id") = webSiteId
            webSite("url") = organization("url")
            webSite("name") = orgName
            webSite("publisher") = New Dictionary(Of String, Object) From {{"@id", orgId}}

            ' --- BreadcrumbList (Home > Catalogo > Prodotto)
            Dim breadcrumbItems As New List(Of Object)()
            breadcrumbItems.Add(New Dictionary(Of String, Object) From {
                {"@type", "ListItem"},
                {"position", 1},
                {"name", "Home"},
                {"item", Request.Url.GetLeftPart(UriPartial.Authority) & ResolveUrl("~/")}
            })
            breadcrumbItems.Add(New Dictionary(Of String, Object) From {
                {"@type", "ListItem"},
                {"position", 2},
                {"name", "Catalogo"},
                {"item", Request.Url.GetLeftPart(UriPartial.Authority) & ResolveUrl("~/articoli.aspx")}
            })
            breadcrumbItems.Add(New Dictionary(Of String, Object) From {
                {"@type", "ListItem"},
                {"position", 3},
                {"name", name},
                {"item", canonical}
            })

            Dim breadcrumb As New Dictionary(Of String, Object)()
            breadcrumb("@type") = "BreadcrumbList"
            breadcrumb("@id") = baseUrl & "#breadcrumb"
            breadcrumb("itemListElement") = breadcrumbItems.ToArray()

            ' --- Product
            Dim product As New Dictionary(Of String, Object)()
            product("@type") = "Product"
            product("@id") = productId
            product("name") = name
            If Not String.IsNullOrEmpty(metaDesc) Then product("description") = metaDesc
            product("sku") = sku
            product("url") = canonical
            If Not String.IsNullOrEmpty(img) Then product("image") = img
            If Not String.IsNullOrEmpty(brand) Then
                product("brand") = New Dictionary(Of String, Object) From {{"@type", "Brand"}, {"name", brand}}
            End If

            ' GTIN: se EAN 13 -> gtin13, se 14 -> gtin14, altrimenti generic gtin
            If Not String.IsNullOrEmpty(ean) Then
                Dim sbDigits As New StringBuilder()
                For Each ch As Char In ean
                    If Char.IsDigit(ch) Then sbDigits.Append(ch)
                Next
                Dim digitsOnly As String = sbDigits.ToString()
                If digitsOnly.Length = 13 Then
                    product("gtin13") = digitsOnly
                ElseIf digitsOnly.Length = 14 Then
                    product("gtin14") = digitsOnly
                ElseIf digitsOnly.Length > 0 Then
                    product("gtin") = digitsOnly
                End If
            End If

            ' Offer
            If price.CurrentPrice.HasValue AndAlso price.CurrentPrice.Value > 0D Then
                Dim offer As New Dictionary(Of String, Object)()
                offer("@type") = "Offer"
                offer("price") = price.CurrentPrice.Value.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)
                offer("priceCurrency") = "EUR"
                offer("url") = canonical

                Dim stockAvailable As Integer = GetRowInt(row, "Giacenza", 0) - GetRowInt(row, "Impegnata", 0)
                If stockAvailable > 0 OrElse GetRowInt(row, "Disponibilita", 0) > 0 OrElse GetRowInt(row, "InOrdine", 0) > 0 Then
                    offer("availability") = "https://schema.org/InStock"
                Else
                    offer("availability") = "https://schema.org/OutOfStock"
                End If

                offer("itemCondition") = "https://schema.org/NewCondition"
                offer("seller") = New Dictionary(Of String, Object) From {{"@id", orgId}}

                product("offers") = offer
            End If

            ' --- WebPage
            Dim webPage As New Dictionary(Of String, Object)()
            webPage("@type") = "WebPage"
            webPage("@id") = webPageId
            webPage("url") = canonical
            webPage("name") = name
            If Not String.IsNullOrEmpty(metaDesc) Then webPage("description") = metaDesc
            webPage("isPartOf") = New Dictionary(Of String, Object) From {{"@id", webSiteId}}
            webPage("about") = New Dictionary(Of String, Object) From {{"@id", orgId}}
            webPage("mainEntity") = New Dictionary(Of String, Object) From {{"@id", productId}}
            If Not String.IsNullOrEmpty(img) Then
                webPage("primaryImageOfPage") = New Dictionary(Of String, Object) From {{"@type", "ImageObject"}, {"url", img}}
            End If

            Dim graph As New List(Of Object)()
            graph.Add(organization)
            graph.Add(webSite)
            graph.Add(webPage)
            graph.Add(breadcrumb)
            graph.Add(product)

            Dim root As New Dictionary(Of String, Object)()
            root("@context") = "https://schema.org"
            root("@graph") = graph

            Dim json As String = js.Serialize(root)
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
            ' Hardening XSS: sanitizzazione allowlist (tag/attributi) + rimozione script/iframe.
            Return SanitizeHtmlAllowBasic(s)
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

    Private Function SanitizeHtmlAllowBasic(html As String) As String
        If String.IsNullOrEmpty(html) Then Return ""

        ' 1) rimuove blocchi <script> (fallback) e poi parse HTML.
        Dim input As String = RemoveScriptBlocks(html)

        Try
            Dim doc As New HtmlDocument()
            doc.OptionFixNestedTags = True
            doc.LoadHtml(input)

            ' tag consentiti (basic eCommerce)
            Dim allowedTags As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
                "p", "br", "strong", "b", "em", "i", "u",
                "ul", "ol", "li",
                "h1", "h2", "h3", "h4", "h5", "h6",
                "div", "span",
                "table", "thead", "tbody", "tr", "th", "td",
                "a", "img"
            }

            ' attributi consentiti
            Dim allowedAttrs As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
                "href", "src", "alt", "title", "class", "id", "name", "target", "rel"
            }

            Dim nodes As HtmlNodeCollection = doc.DocumentNode.SelectNodes("//*")
            If nodes Is Nothing Then Return ""

            Dim i As Integer
            For i = nodes.Count - 1 To 0 Step -1
                Dim n As HtmlNode = nodes(i)
                Dim tag As String = n.Name

                ' rimuove tag pericolosi e quelli non in allowlist (sostituisce con testo)
                If tag.Equals("script", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("iframe", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("object", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("embed", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("link", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("meta", StringComparison.OrdinalIgnoreCase) OrElse
                   tag.Equals("style", StringComparison.OrdinalIgnoreCase) Then
                    n.Remove()
                    Continue For
                End If

                If Not allowedTags.Contains(tag) Then
                    ' conserva testo interno (se presente)
                    Dim text As String = HttpUtility.HtmlEncode(n.InnerText)
                    n.ParentNode.ReplaceChild(HtmlNode.CreateNode(text), n)
                    Continue For
                End If

                ' pulizia attributi
                If n.HasAttributes Then
                    Dim toRemove As New List(Of HtmlAttribute)()
                    For Each a As HtmlAttribute In n.Attributes
                        Dim an As String = a.Name
                        Dim av As String = If(a.Value, "")

                        ' elimina handler on* e attributi non consentiti
                        If an.StartsWith("on", StringComparison.OrdinalIgnoreCase) OrElse Not allowedAttrs.Contains(an) Then
                            toRemove.Add(a)
                            Continue For
                        End If

                        ' elimina javascript: nelle URL
                        If (an.Equals("href", StringComparison.OrdinalIgnoreCase) OrElse an.Equals("src", StringComparison.OrdinalIgnoreCase)) Then
                            Dim v As String = av.Trim()
                            If v.StartsWith("javascript:", StringComparison.OrdinalIgnoreCase) Then
                                toRemove.Add(a)
                                Continue For
                            End If
                        End If

                        ' normalizza target
                        If an.Equals("target", StringComparison.OrdinalIgnoreCase) Then
                            If Not av.Equals("_blank", StringComparison.OrdinalIgnoreCase) Then
                                toRemove.Add(a)
                            Else
                                ' security: rel
                                If n.Name.Equals("a", StringComparison.OrdinalIgnoreCase) Then
                                    If n.Attributes("rel") Is Nothing Then
                                        n.Attributes.Add("rel", "noopener")
                                    End If
                                End If
                            End If
                        End If
                    Next

                    For Each a As HtmlAttribute In toRemove
                        n.Attributes.Remove(a)
                    Next
                End If
            Next

            Return doc.DocumentNode.InnerHtml
        Catch
            ' fallback: encode
            Dim safe As String = HttpUtility.HtmlEncode(input)
            safe = safe.Replace(vbCrLf, "<br />").Replace(vbLf, "<br />")
            Return "<p>" & safe & "</p>"
        End Try
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
        If Not prezzo.HasValue OrElse prezzo.Value <= 0D Then
            Return "<span class=""new-price price-text fw-medium mb-0"">Prezzo su richiesta</span>"
        End If

        Dim priceText As String = prezzo.Value.ToString("C")

        If inOfferta AndAlso prezzoOld.HasValue AndAlso prezzoOld.Value > 0D AndAlso prezzo.HasValue AndAlso prezzoOld.Value > prezzo.Value Then
            Dim oldText As String = prezzoOld.Value.ToString("C")
            Return "<span class=""new-price price-text fw-medium mb-0"">" & Server.HtmlEncode(priceText) & "</span><span class=""old-price body-md-2 text-main-2 fw-normal"">" & Server.HtmlEncode(oldText) & "</span>"
        End If

        Return "<span class=""new-price price-text fw-medium mb-0"">" & Server.HtmlEncode(priceText) & "</span>"
    End Function

    Private Function BuildPriceContext(prezzo As Nullable(Of Decimal),
                                       prezzoIvato As Nullable(Of Decimal),
                                       prezzoPromo As Nullable(Of Decimal),
                                       prezzoPromoIvato As Nullable(Of Decimal),
                                       inOfferta As Integer) As PriceContext
        Dim ctx As New PriceContext()
        Dim ivaTipo As Integer = GetSessionInt("IvaTipo", 2)

        If ivaTipo = 1 Then
            ctx.CurrentPrice = prezzo
            ctx.OldPrice = Nothing
            ctx.IvaLabel = "IVA esclusa"
            If inOfferta = 1 AndAlso prezzoPromo.HasValue AndAlso prezzoPromo.Value > 0D Then
                ctx.CurrentPrice = prezzoPromo
                If prezzo.HasValue AndAlso prezzo.Value > prezzoPromo.Value Then
                    ctx.OldPrice = prezzo
                End If
                ctx.IsPromo = True
            End If
        Else
            ctx.CurrentPrice = prezzoIvato
            ctx.OldPrice = Nothing
            ctx.IvaLabel = "IVA inclusa"
            If inOfferta = 1 AndAlso prezzoPromoIvato.HasValue AndAlso prezzoPromoIvato.Value > 0D Then
                ctx.CurrentPrice = prezzoPromoIvato
                If prezzoIvato.HasValue AndAlso prezzoIvato.Value > prezzoPromoIvato.Value Then
                    ctx.OldPrice = prezzoIvato
                End If
                ctx.IsPromo = True
            End If
        End If

        If Not ctx.CurrentPrice.HasValue OrElse ctx.CurrentPrice.Value <= 0D Then
            ctx.CurrentPrice = FirstPositiveDecimal(prezzoIvato, prezzo, prezzoPromoIvato, prezzoPromo)
        End If

        Return ctx
    End Function

    Private Function FirstPositiveDecimal(ParamArray values() As Nullable(Of Decimal)) As Nullable(Of Decimal)
        If values Is Nothing Then Return Nothing
        For Each v As Nullable(Of Decimal) In values
            If v.HasValue AndAlso v.Value > 0D Then Return v
        Next
        Return Nothing
    End Function

    Private Function BuildAvailabilityText(row As DataRow) As String
        Dim giacenza As Integer = GetRowInt(row, "Giacenza", 0)
        Dim impegnata As Integer = GetRowInt(row, "Impegnata", 0)
        Dim disponibile As Integer = giacenza - impegnata
        Dim disponibilita As Integer = GetRowInt(row, "Disponibilita", 0)
        Dim inOrdine As Integer = GetRowInt(row, "InOrdine", 0)

        If disponibile > 0 Then
            Return "Disponibile"
        End If

        Dim arrivo As String = FirstNonEmpty(GetRowString(row, "Arrivo"), StripHtml(GetRowString(row, "arrivi")))
        If Not String.IsNullOrEmpty(arrivo) Then
            Return "In arrivo: " & ThemeManager.CompactText(arrivo, 90)
        End If

        If disponibilita > 0 Then
            Return "Disponibile su ordinazione"
        End If

        If inOrdine > 0 Then
            Return "In ordine"
        End If

        Return "Verifica disponibilita"
    End Function

    Private Function BuildCategoryCatalogUrl(row As DataRow) As String
        Dim rel As String = "~/articoli.aspx"
        Dim parts As New List(Of String)()

        Dim stId As Integer = GetRowInt(row, "SettoriId", 0)
        Dim ctId As Integer = GetRowInt(row, "CategorieId", 0)
        Dim tpId As Integer = GetRowInt(row, "TipologieId", 0)

        If stId > 0 Then parts.Add("st=" & stId.ToString())
        If ctId > 0 Then parts.Add("ct=" & ctId.ToString())
        If tpId > 0 Then parts.Add("tp=" & tpId.ToString())

        If parts.Count > 0 Then rel &= "?" & String.Join("&", parts.ToArray())
        Return ResolveUrl(rel)
    End Function

    Private Function BuildBrandCatalogUrl(row As DataRow, brandId As Integer) As String
        Dim rel As String = "~/articoli.aspx"
        Dim parts As New List(Of String)()

        Dim stId As Integer = GetRowInt(row, "SettoriId", 0)
        Dim ctId As Integer = GetRowInt(row, "CategorieId", 0)
        Dim tpId As Integer = GetRowInt(row, "TipologieId", 0)

        If stId > 0 Then parts.Add("st=" & stId.ToString())
        If ctId > 0 Then parts.Add("ct=" & ctId.ToString())
        If tpId > 0 Then parts.Add("tp=" & tpId.ToString())
        If brandId > 0 Then parts.Add("mr=" & brandId.ToString())

        If parts.Count > 0 Then rel &= "?" & String.Join("&", parts.ToArray())
        Return ResolveUrl(rel)
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

        s = s.Replace("\", "/")

        If s.StartsWith("/Public/assets/images/articoli/", StringComparison.OrdinalIgnoreCase) Then
            Return "/Public/assets/images/articoli/" & IO.Path.GetFileName(s)
        End If

        If s.StartsWith("/assets/Images/articoli/", StringComparison.OrdinalIgnoreCase) Then
            Return "/Public/assets/images/articoli/" & IO.Path.GetFileName(s)
        End If

        If s.StartsWith("/Public/assets/images/articoli/", StringComparison.OrdinalIgnoreCase) Then
            Return s
        End If

        If s.StartsWith("/", StringComparison.Ordinal) Then
            Dim fileOnly As String = IO.Path.GetFileName(s)
            If Not String.IsNullOrWhiteSpace(fileOnly) Then
                Return "/Public/assets/images/articoli/" & fileOnly
            End If
            Return ""
        End If

        If s.IndexOf("/"c) >= 0 Then
            Dim fileOnly As String = IO.Path.GetFileName(s)
            If Not String.IsNullOrWhiteSpace(fileOnly) Then
                Return ResolveUrl("~/Public/assets/images/articoli/" & fileOnly)
            End If
            Return "/" & s.TrimStart("/"c)
        End If

        Return ResolveUrl("~/Public/assets/images/articoli/" & s)
    End Function

    Protected Sub ddlTc_SelectedIndexChanged(sender As Object, e As EventArgs)
        Dim selected As Integer
        If Not Integer.TryParse(ddlTc.SelectedValue, selected) Then
            selected = 0
        End If

        Response.Redirect(BuildProductUrl(_id, selected, includeTcid:=True), True)
    End Sub

    Protected Sub btnAddToCart_Click(sender As Object, e As EventArgs)
        Dim qty As Integer = NormalizeCartQuantity(txtQty.Text, 1, 9999)
        txtQty.Text = qty.ToString()

        ' Risolve il TCid effettivo prima del redirect legacy verso aggiungi.aspx.
        Dim tcidToUse As Integer = _tcid
        If _tcEnabled Then
            tcidToUse = _tcid

            If pnlVariants.Visible Then
                Dim tmp As Integer
                If Integer.TryParse(ddlTc.SelectedValue, tmp) Then
                    tcidToUse = tmp
                End If
            End If
        End If

        Dim cartRow As DataRow = GetProductRow(_id, tcidToUse, includeTcidFilter:=(_tcEnabled AndAlso tcidToUse > 0))
        If cartRow Is Nothing Then
            cartRow = GetProductRow(_id, -1, includeTcidFilter:=False)
        End If

        If cartRow Is Nothing Then
            litQtyHelp.Text = "Articolo non disponibile per l'aggiunta al carrello."
            Return
        End If

        tcidToUse = GetRowInt(cartRow, "TCid", tcidToUse)

        Session("ProdottoGratis") = GetRowInt(cartRow, "SpeditoGratis", 0)
        Session("Carrello_ArticoloId") = _id.ToString()
        Session("Carrello_TCId") = tcidToUse.ToString()
        Session("Carrello_Quantita") = qty.ToString()
        Session("Carrello_Pagina") = Request.RawUrl
        Session("Carrello_SelezioneMultipla") = Nothing

        Response.Redirect("aggiungi.aspx", False)
        Context.ApplicationInstance.CompleteRequest()
    End Sub

    Private Function NormalizeCartQuantity(ByVal rawValue As String, ByVal fallbackValue As Integer, ByVal maxValue As Integer) As Integer
        Dim qty As Integer = fallbackValue
        If Not Integer.TryParse(Convert.ToString(rawValue), qty) Then
            qty = fallbackValue
        End If

        If qty <= 0 Then qty = fallbackValue
        If qty > maxValue Then qty = maxValue

        Return qty
    End Function

    Private Sub TrackRecentlyViewed(productId As Integer)
        If productId <= 0 Then Exit Sub

        Try
            Dim ids As New List(Of Integer)()
            Dim sessionRaw As String = Convert.ToString(Session("ks_recent_ids"))
            If Not String.IsNullOrWhiteSpace(sessionRaw) Then
                Dim sessionParts As String() = sessionRaw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
                For Each part As String In sessionParts
                    Dim n As Integer
                    If Integer.TryParse(part.Trim(), n) AndAlso n > 0 AndAlso n <> productId Then
                        If Not ids.Contains(n) Then
                            ids.Add(n)
                        End If
                    End If
                Next
            End If

            Dim existing As HttpCookie = Request.Cookies("ks_recent")

            If existing IsNot Nothing AndAlso Not String.IsNullOrWhiteSpace(existing.Value) Then
                Dim raw As String = HttpUtility.UrlDecode(existing.Value)
                If Not String.IsNullOrWhiteSpace(raw) Then
                    Dim parts As String() = raw.Split(New Char() {","c}, StringSplitOptions.RemoveEmptyEntries)
                    For Each part As String In parts
                        Dim n As Integer
                        If Integer.TryParse(part.Trim(), n) AndAlso n > 0 AndAlso n <> productId Then
                            If Not ids.Contains(n) Then
                                ids.Add(n)
                            End If
                        End If
                    Next
                End If
            End If

            ids.Insert(0, productId)
            If ids.Count > 100 Then
                ids.RemoveRange(100, ids.Count - 100)
            End If

            Dim cookie As New HttpCookie("ks_recent")
            cookie.Value = HttpUtility.UrlEncode(String.Join(",", ids.ToArray()))
            cookie.Path = "/"
            cookie.Expires = DateTime.Now.AddDays(30)
            cookie.HttpOnly = False
            Response.Cookies.Add(cookie)

            Dim orderedRecentIds As String = String.Join(",", ids.ToArray())
            Session("ks_recent_ids") = orderedRecentIds
            Session("ks_recent_session") = orderedRecentIds

            Dim sessionCookie As New HttpCookie("ks_recent_session")
            sessionCookie.Value = HttpUtility.UrlEncode(orderedRecentIds)
            sessionCookie.Path = "/"
            sessionCookie.HttpOnly = False
            Response.Cookies.Add(sessionCookie)
        Catch
            ' Best effort: la pagina prodotto non deve rompersi se la scrittura cookie fallisce.
        End Try
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

    ' Listino robusto: usa Session("Listino") come fonte principale, con fallback a Session("listino").
    ' Imposta anche in Session per coerenza con le altre pagine.
    Private Function GetCurrentListino() As Integer
        Dim n As Integer = 0

        n = GetSessionInt("Listino", 0)
        If n <= 0 Then
            n = GetSessionInt("listino", 0)
        End If

        If n <= 0 Then
            n = 1
        End If

        ' Mantengo entrambe le chiavi per compatibilità con codice legacy
        Session("Listino") = n
        Session("listino") = n

        Return n
    End Function



    ' VB2012-safe conversion helper (DBNull/Null -> 0)
    Private Function SafeToInt(ByVal o As Object) As Integer
        Try
            If o Is Nothing OrElse o Is DBNull.Value Then Return 0
            Dim s As String = Convert.ToString(o)
            Dim n As Integer = 0
            If Integer.TryParse(s, n) Then Return n
        Catch
        End Try
        Return 0
    End Function

End Class
