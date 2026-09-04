Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class CartPriceRevalidationChange
    Public Property CartRowId As Integer
    Public Property ArticleId As Integer
    Public Property Description As String
    Public Property OldPriceIvato As Double
    Public Property NewPriceIvato As Double
End Class

Public Class CartPriceRevalidationResult
    Public Sub New()
        Changes = New List(Of CartPriceRevalidationChange)()
    End Sub

    Public Property HasBlockingError As Boolean
    Public Property ErrorMessage As String
    Public Property Changes As List(Of CartPriceRevalidationChange)

    Public ReadOnly Property HasChanges As Boolean
        Get
            Return Changes IsNot Nothing AndAlso Changes.Count > 0
        End Get
    End Property
End Class

Friend Class CartPriceRevalidationRow
    Public Property CartRowId As Integer
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property Quantity As Double
    Public Property CurrentPrice As Double
    Public Property CurrentPriceIvato As Double
    Public Property CurrentOfferDetailId As Integer
    Public Property Description As String
    Public Property IsComplimentary As Boolean
End Class

Friend Class CartPriceCandidate
    Public Property TCId As Integer
    Public Property Price As Double
    Public Property PriceIvato As Double
    Public Property ReverseChargeVatId As Integer
    Public Property ReverseChargeVatValue As Double
    Public Property ReverseChargeDescription As String
End Class

Friend Class CartResolvedPrice
    Public Property IsValid As Boolean
    Public Property Price As Double
    Public Property PriceIvato As Double
    Public Property OfferDetailId As Integer
    Public Property ReverseChargeVatId As Integer
    Public Property ReverseChargeVatValue As Double
    Public Property ReverseChargeDescription As String
End Class

Public Module CartPriceRevalidationHelper
    Public Const SessionMessageKey As String = "CartPriceRevalidationMessage"
    Public Const SessionChangedKey As String = "CartPriceRevalidationChanged"
    Public Const GenericChangedMessage As String = "Alcuni prezzi del carrello sono stati aggiornati. Ricontrolla il riepilogo e conferma nuovamente l'ordine."
    Private ReadOnly PriceCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Public Function RevalidateCurrentCart(ByVal ctx As HttpContext, Optional ByVal updateCart As Boolean = True) As CartPriceRevalidationResult
        Dim result As New CartPriceRevalidationResult()
        If ctx Is Nothing OrElse ctx.Session Is Nothing Then
            result.HasBlockingError = True
            result.ErrorMessage = GenericChangedMessage
            Return result
        End If

        Dim loginId As Integer = SessionInt(ctx, "LoginId", 0)
        Dim sessionId As String = ""
        Try
            sessionId = ctx.Session.SessionID
        Catch
            sessionId = ""
        End Try

        If loginId <= 0 AndAlso String.IsNullOrEmpty(sessionId) Then
            result.HasBlockingError = True
            result.ErrorMessage = GenericChangedMessage
            Return result
        End If

        Dim listino As Integer = SessionInt(ctx, "Listino", SessionInt(ctx, "listino", 1))
        If listino <= 0 Then listino = 1
        Dim eligibilityContext As ProductPromotionEligibilityContext =
            ProductPromotionEligibilityResolver.CreateContext(ctx, listino)

        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()

                Dim rows As List(Of CartPriceRevalidationRow) = LoadCartRows(conn, loginId, sessionId)
                For Each row As CartPriceRevalidationRow In rows
                    Dim candidates As List(Of CartPriceCandidate) = LoadCandidates(conn, row.ArticleId, listino)
                    Dim resolved As CartResolvedPrice = ResolvePrice(ctx, row, candidates, eligibilityContext)
                    If Not resolved.IsValid Then
                        result.HasBlockingError = True
                        result.ErrorMessage = "Prezzo prodotto non disponibile. Ricontrolla il carrello prima di confermare l'ordine."
                        Continue For
                    End If

                    If PriceChanged(row.CurrentPrice, resolved.Price) OrElse
                       PriceChanged(row.CurrentPriceIvato, resolved.PriceIvato) OrElse
                       row.CurrentOfferDetailId <> resolved.OfferDetailId Then
                        Dim change As New CartPriceRevalidationChange()
                        change.CartRowId = row.CartRowId
                        change.ArticleId = row.ArticleId
                        change.Description = row.Description
                        change.OldPriceIvato = row.CurrentPriceIvato
                        change.NewPriceIvato = resolved.PriceIvato
                        result.Changes.Add(change)

                        If updateCart Then
                            UpdateCartRow(conn, loginId, sessionId, row.CartRowId, resolved, ctx)
                        End If
                    End If
                Next
            End Using
        Catch
            result.HasBlockingError = True
            result.ErrorMessage = GenericChangedMessage
        End Try

        Return result
    End Function

    Public Sub StoreResultInSession(ByVal ctx As HttpContext, ByVal result As CartPriceRevalidationResult)
        If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return

        ctx.Session(SessionChangedKey) = If(result IsNot Nothing AndAlso (result.HasChanges OrElse result.HasBlockingError), 1, 0)
        If result Is Nothing Then
            ctx.Session(SessionMessageKey) = GenericChangedMessage
        ElseIf result.HasBlockingError AndAlso Not String.IsNullOrEmpty(result.ErrorMessage) Then
            ctx.Session(SessionMessageKey) = HttpUtility.HtmlEncode(result.ErrorMessage)
        Else
            ctx.Session(SessionMessageKey) = BuildMessageHtml(result)
        End If
    End Sub

    Public Function BuildMessageHtml(ByVal result As CartPriceRevalidationResult) As String
        If result Is Nothing OrElse Not result.HasChanges Then
            Return HttpUtility.HtmlEncode(GenericChangedMessage)
        End If

        Dim sb As New StringBuilder()
        sb.Append("<strong>").Append(HttpUtility.HtmlEncode(GenericChangedMessage)).Append("</strong>")
        sb.Append("<ul class=""ks-price-revalidation-list"">")
        Dim maxRows As Integer = Math.Min(result.Changes.Count, 5)
        For i As Integer = 0 To maxRows - 1
            Dim c As CartPriceRevalidationChange = result.Changes(i)
            Dim name As String = If(String.IsNullOrWhiteSpace(c.Description), "Articolo " & c.ArticleId.ToString(CultureInfo.InvariantCulture), c.Description)
            sb.Append("<li>")
            sb.Append(HttpUtility.HtmlEncode(name))
            sb.Append(": ")
            sb.Append(HttpUtility.HtmlEncode(FormatCurrencyIt(c.OldPriceIvato)))
            sb.Append(" -> ")
            sb.Append(HttpUtility.HtmlEncode(FormatCurrencyIt(c.NewPriceIvato)))
            sb.Append("</li>")
        Next
        If result.Changes.Count > maxRows Then
            sb.Append("<li>").Append(HttpUtility.HtmlEncode("Altri articoli aggiornati.")).Append("</li>")
        End If
        sb.Append("</ul>")
        Return sb.ToString()
    End Function

    Private Function LoadCartRows(ByVal conn As MySqlConnection, ByVal loginId As Integer, ByVal sessionId As String) As List(Of CartPriceRevalidationRow)
        Dim rows As New List(Of CartPriceRevalidationRow)()
        Using cmd As New MySqlCommand()
            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.CommandText = "SELECT ID, ArticoliId, COALESCE(TCId,-1) AS TCId, COALESCE(Qnt,0) AS Qnt, COALESCE(Prezzo,0) AS Prezzo, COALESCE(PrezzoIvato,0) AS PrezzoIvato, COALESCE(OfferteDettaglioId,0) AS OfferteDettaglioId, COALESCE(Descrizione1,'') AS Descrizione1, COALESCE(Prodotto_Gratis,0) AS Prodotto_Gratis FROM carrello WHERE " & OwnerWhere(loginId)
            AddOwnerParameters(cmd, loginId, sessionId)

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                While dr.Read()
                    Dim row As New CartPriceRevalidationRow()
                    row.CartRowId = ReadInt(dr("ID"), 0)
                    row.ArticleId = ReadInt(dr("ArticoliId"), 0)
                    row.TCId = ReadInt(dr("TCId"), -1)
                    row.Quantity = ReadDouble(dr("Qnt"), 0)
                    row.CurrentPrice = ReadDouble(dr("Prezzo"), 0)
                    row.CurrentPriceIvato = ReadDouble(dr("PrezzoIvato"), 0)
                    row.CurrentOfferDetailId = ReadInt(dr("OfferteDettaglioId"), 0)
                    row.Description = Convert.ToString(dr("Descrizione1"))
                    row.IsComplimentary = (ReadInt(dr("Prodotto_Gratis"), 0) <> 0)
                    If row.IsComplimentary Then Continue While
                    If row.CartRowId > 0 AndAlso row.ArticleId > 0 Then rows.Add(row)
                End While
            End Using
        End Using
        Return rows
    End Function

    Private Function LoadCandidates(ByVal conn As MySqlConnection, ByVal articleId As Integer, ByVal listino As Integer) As List(Of CartPriceCandidate)
        Dim candidates As New List(Of CartPriceCandidate)()
        Using cmd As New MySqlCommand("SELECT DISTINCT v.ID, COALESCE(v.TCid,-1) AS TCid, v.Prezzo, v.PrezzoIvato, v.IdIvaRC, v.ValoreIvaRC, v.DescrizioneIvaRC FROM vsuperarticoli v WHERE v.NListino=?listino AND v.ID=?id ORDER BY v.ID, CASE WHEN COALESCE(v.TCid,-1) IN (-1,0) THEN 0 ELSE 1 END, COALESCE(v.TCid,-1) ASC", conn)
            cmd.Parameters.Add("?listino", MySqlDbType.Int32).Value = listino
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = articleId

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                While dr.Read()
                    Dim item As New CartPriceCandidate()
                    item.TCId = ReadInt(dr("TCid"), -1)
                    item.Price = ReadDouble(dr("Prezzo"), 0)
                    item.PriceIvato = ReadDouble(dr("PrezzoIvato"), 0)
                    item.ReverseChargeVatId = ReadInt(dr("IdIvaRC"), -1)
                    item.ReverseChargeVatValue = ReadDouble(dr("ValoreIvaRC"), -1)
                    item.ReverseChargeDescription = Convert.ToString(dr("DescrizioneIvaRC"))
                    candidates.Add(item)
                End While
            End Using
        End Using
        Return candidates
    End Function

    Private Function ResolvePrice(ByVal ctx As HttpContext,
                                  ByVal row As CartPriceRevalidationRow,
                                  ByVal allCandidates As List(Of CartPriceCandidate),
                                  ByVal eligibilityContext As ProductPromotionEligibilityContext) As CartResolvedPrice
        Dim resolved As New CartResolvedPrice()
        If allCandidates Is Nothing OrElse allCandidates.Count = 0 Then Return resolved

        Dim candidates As List(Of CartPriceCandidate) = allCandidates.FindAll(Function(x) x.TCId = row.TCId)
        If candidates.Count = 0 AndAlso row.TCId <= 0 Then candidates = allCandidates.FindAll(Function(x) x.TCId <= 0)
        If candidates.Count = 0 Then candidates = allCandidates.FindAll(Function(x) x.TCId <= 0)
        If candidates.Count = 0 Then Return resolved

        Dim baseRow As CartPriceCandidate = candidates(0)
        Dim price As Double = baseRow.Price
        Dim priceIvato As Double = ResolvePriceIvato(ctx, baseRow, price, baseRow.PriceIvato)
        If price <= 0 OrElse priceIvato <= 0 Then Return resolved

        Dim promotion As ProductPromotionEligibilityResult = ProductPromotionEligibilityResolver.Resolve(
            ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString,
            eligibilityContext,
            row.ArticleId,
            row.TCId,
            Convert.ToDecimal(row.Quantity, CultureInfo.InvariantCulture),
            Convert.ToDecimal(price, CultureInfo.InvariantCulture),
            Convert.ToDecimal(priceIvato, CultureInfo.InvariantCulture))
        Dim offerId As Integer = 0
        If promotion.HasAppliedOffer Then
            price = Convert.ToDouble(promotion.EffectivePriceNet, CultureInfo.InvariantCulture)
            priceIvato = Convert.ToDouble(promotion.EffectivePriceGross, CultureInfo.InvariantCulture)
            offerId = promotion.AppliedOffer.OfferDetailId
        End If

        resolved.IsValid = True
        resolved.Price = price
        resolved.PriceIvato = priceIvato
        resolved.OfferDetailId = offerId
        resolved.ReverseChargeVatId = If(ReverseChargeEnabled(ctx) AndAlso baseRow.ReverseChargeVatId > -1, baseRow.ReverseChargeVatId, -1)
        resolved.ReverseChargeVatValue = If(resolved.ReverseChargeVatId > -1, baseRow.ReverseChargeVatValue, -1)
        resolved.ReverseChargeDescription = If(resolved.ReverseChargeVatId > -1, baseRow.ReverseChargeDescription, "")
        Return resolved
    End Function

    Private Function ResolvePriceIvato(ByVal ctx As HttpContext, ByVal row As CartPriceCandidate, ByVal price As Double, ByVal fallbackIvato As Double) As Double
        If ReverseChargeEnabled(ctx) AndAlso row.ReverseChargeVatId > -1 AndAlso row.ReverseChargeVatValue > -1 Then
            Return price * ((row.ReverseChargeVatValue / 100) + 1)
        End If

        Dim ivaUtente As Double = SessionDouble(ctx, "Iva_Utente", -1)
        If ivaUtente > -1 Then Return price * ((ivaUtente / 100) + 1)
        Return fallbackIvato
    End Function

    Private Sub UpdateCartRow(ByVal conn As MySqlConnection, ByVal loginId As Integer, ByVal sessionId As String, ByVal cartRowId As Integer, ByVal resolved As CartResolvedPrice, ByVal ctx As HttpContext)
        Using cmd As New MySqlCommand()
            cmd.Connection = conn
            cmd.CommandType = CommandType.Text
            cmd.CommandText = "UPDATE carrello SET Prezzo=?prezzo, PrezzoIvato=?prezzoIvato, OfferteDettaglioId=?offertaId, IdIvaRC=?idIvaRC, ValoreIvaRC=?valoreIvaRC, DescrizioneIvaRC=?descrizioneIvaRC, IdEsenzioneIva=?idEsenzioneIva, ValoreEsenzioneIva=?valoreEsenzioneIva, DescrizioneEsenzioneIva=?descrizioneEsenzioneIva WHERE ID=?id AND " & OwnerWhere(loginId)
            cmd.Parameters.Add("?prezzo", MySqlDbType.Double).Value = resolved.Price
            cmd.Parameters.Add("?prezzoIvato", MySqlDbType.Double).Value = resolved.PriceIvato
            cmd.Parameters.Add("?offertaId", MySqlDbType.Int32).Value = resolved.OfferDetailId
            cmd.Parameters.Add("?idIvaRC", MySqlDbType.Int32).Value = resolved.ReverseChargeVatId
            cmd.Parameters.Add("?valoreIvaRC", MySqlDbType.Double).Value = resolved.ReverseChargeVatValue
            cmd.Parameters.Add("?descrizioneIvaRC", MySqlDbType.VarChar).Value = If(resolved.ReverseChargeDescription, "")
            cmd.Parameters.Add("?idEsenzioneIva", MySqlDbType.Int32).Value = SessionInt(ctx, "IdEsenzioneIva", -1)
            cmd.Parameters.Add("?valoreEsenzioneIva", MySqlDbType.Double).Value = SessionDouble(ctx, "Iva_Utente", -1)
            cmd.Parameters.Add("?descrizioneEsenzioneIva", MySqlDbType.VarChar).Value = SessionText(ctx, "DescrizioneEsenzioneIva", "")
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = cartRowId
            AddOwnerParameters(cmd, loginId, sessionId)
            cmd.ExecuteNonQuery()
        End Using
    End Sub

    Private Function OwnerWhere(ByVal loginId As Integer) As String
        If loginId > 0 Then Return "LoginId=?ownerLoginId"
        Return "SessionId=?ownerSessionId"
    End Function

    Private Sub AddOwnerParameters(ByVal cmd As MySqlCommand, ByVal loginId As Integer, ByVal sessionId As String)
        If loginId > 0 Then
            cmd.Parameters.Add("?ownerLoginId", MySqlDbType.Int32).Value = loginId
        Else
            cmd.Parameters.Add("?ownerSessionId", MySqlDbType.VarChar).Value = If(sessionId, "")
        End If
    End Sub

    Private Function ReverseChargeEnabled(ByVal ctx As HttpContext) As Boolean
        Return SessionInt(ctx, "AbilitatoIvaReverseCharge", 0) = 1
    End Function

    Private Function PriceChanged(ByVal oldValue As Double, ByVal newValue As Double) As Boolean
        Return Math.Abs(oldValue - newValue) >= 0.005
    End Function

    Private Function FormatCurrencyIt(ByVal value As Double) As String
        Return value.ToString("N2", PriceCulture) & " " & ChrW(8364)
    End Function

    Private Function SessionText(ByVal ctx As HttpContext, ByVal key As String, ByVal defaultValue As String) As String
        Try
            If ctx Is Nothing OrElse ctx.Session Is Nothing OrElse ctx.Session(key) Is Nothing Then Return defaultValue
            Return Convert.ToString(ctx.Session(key))
        Catch
            Return defaultValue
        End Try
    End Function

    Private Function SessionInt(ByVal ctx As HttpContext, ByVal key As String, ByVal defaultValue As Integer) As Integer
        Dim output As Integer = defaultValue
        Try
            If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing AndAlso ctx.Session(key) IsNot Nothing Then
                If Integer.TryParse(Convert.ToString(ctx.Session(key)), output) Then Return output
            End If
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function SessionDouble(ByVal ctx As HttpContext, ByVal key As String, ByVal defaultValue As Double) As Double
        Try
            If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing AndAlso ctx.Session(key) IsNot Nothing Then
                Return ParseDoubleValue(ctx.Session(key), defaultValue)
            End If
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function ReadInt(ByVal value As Object, ByVal defaultValue As Integer) As Integer
        Dim output As Integer = defaultValue
        Try
            If value IsNot Nothing AndAlso value IsNot DBNull.Value AndAlso Integer.TryParse(Convert.ToString(value), output) Then Return output
        Catch
        End Try
        Return defaultValue
    End Function

    Private Function ReadDouble(ByVal value As Object, ByVal defaultValue As Double) As Double
        Return ParseDoubleValue(value, defaultValue)
    End Function

    Private Function ParseDoubleValue(ByVal value As Object, ByVal defaultValue As Double) As Double
        Dim output As Double = defaultValue
        Try
            If value IsNot Nothing AndAlso value IsNot DBNull.Value Then
                If TypeOf value Is Byte OrElse TypeOf value Is Short OrElse TypeOf value Is Integer OrElse TypeOf value Is Long OrElse
                   TypeOf value Is Single OrElse TypeOf value Is Double OrElse TypeOf value Is Decimal Then
                    Return Convert.ToDouble(value, CultureInfo.InvariantCulture)
                End If

                Dim text As String = Convert.ToString(value).Trim()
                If text.IndexOf(","c) >= 0 AndAlso text.IndexOf("."c) < 0 Then
                    If Double.TryParse(text, NumberStyles.Any, PriceCulture, output) Then Return output
                    If Double.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, output) Then Return output
                Else
                    If Double.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, output) Then Return output
                    If Double.TryParse(text, NumberStyles.Any, PriceCulture, output) Then Return output
                End If
            End If
        Catch
        End Try
        Return defaultValue
    End Function
End Module
