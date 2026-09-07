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
    Public Property OldPriceIvato As Decimal
    Public Property NewPriceIvato As Decimal
    Public Property FreeShippingChanged As Boolean
    Public Property NewFreeShipping As Integer
End Class

Public Class CartPriceRevalidationResult
    Public Sub New()
        Changes = New List(Of CartPriceRevalidationChange)()
    End Sub

    Public Property HasBlockingError As Boolean
    Public Property HasTechnicalError As Boolean
    Public Property HasCommercialRuleError As Boolean
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
    Public Property Quantity As Decimal
    Public Property CurrentPrice As Decimal
    Public Property CurrentPriceIvato As Decimal
    Public Property CurrentOfferDetailId As Integer
    Public Property CurrentFreeShipping As Integer
    Public Property Description As String
End Class

Friend Class CartPriceCandidate
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property Code As String
    Public Property Description As String
    Public Property Price As Decimal
    Public Property PriceIvato As Decimal
    Public Property ReverseChargeVatId As Integer
    Public Property ReverseChargeVatValue As Decimal
    Public Property ReverseChargeDescription As String
End Class

Friend Class CartResolvedPrice
    Public Property IsValid As Boolean
    Public Property HasTechnicalError As Boolean
    Public Property HasCommercialRuleError As Boolean
    Public Property ArticleId As Integer
    Public Property EffectiveTCId As Integer
    Public Property Code As String
    Public Property Description As String
    Public Property Price As Decimal
    Public Property PriceIvato As Decimal
    Public Property OfferDetailId As Integer
    Public Property ReverseChargeVatId As Integer
    Public Property ReverseChargeVatValue As Decimal
    Public Property ReverseChargeDescription As String
    Public Property FreeShipping As Integer
End Class

Friend Class CartPriceRevalidationPlan
    Public Property Row As CartPriceRevalidationRow
    Public Property Resolved As CartResolvedPrice
End Class

Public Module CartPriceRevalidationHelper
    Public Const SessionMessageKey As String = "CartPriceRevalidationMessage"
    Public Const SessionChangedKey As String = "CartPriceRevalidationChanged"
    Public Const GenericChangedMessage As String = "Alcune condizioni commerciali del carrello sono state aggiornate. Ricontrolla il riepilogo e conferma nuovamente l'ordine."
    Public Const GenericTechnicalErrorMessage As String = "Non è stato possibile verificare i prezzi del carrello. Riprova prima di confermare l'ordine."
    Public Const GenericCommercialRuleErrorMessage As String = "Una promozione presenta regole quantità non compatibili. Il carrello non può essere confermato finché l'offerta non viene corretta."
    Private ReadOnly PriceCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Public Function RevalidateCurrentCart(ByVal ctx As HttpContext, Optional ByVal updateCart As Boolean = True) As CartPriceRevalidationResult
        Dim result As CartPriceRevalidationResult = Nothing
        Dim conn As MySqlConnection = Nothing
        Dim transaction As MySqlTransaction = Nothing
        Try
            If ctx Is Nothing OrElse ctx.Session Is Nothing Then Return TechnicalFailureResult()

            Dim loginId As Integer = SessionInt(ctx, "LoginId", SessionInt(ctx, "LoginID", 0))
            Dim sessionId As String = Convert.ToString(ctx.Session.SessionID)
            Dim listino As Integer = SessionInt(ctx, "Listino", SessionInt(ctx, "listino", 1))
            If listino <= 0 Then listino = 1
            If loginId <= 0 AndAlso String.IsNullOrWhiteSpace(sessionId) Then Return TechnicalFailureResult()

            conn = New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
            conn.Open()
            transaction = conn.BeginTransaction(IsolationLevel.ReadCommitted)
            result = RevalidateCurrentCart(ctx, conn, transaction, loginId, sessionId, listino, updateCart, True, Nothing)
            If result Is Nothing OrElse result.HasBlockingError Then
                TryRollback(transaction, ctx, "standalone-revalidation")
            Else
                transaction.Commit()
            End If
            transaction.Dispose()
            transaction = Nothing
        Catch ex As Exception
            TryRollback(transaction, ctx, "standalone-revalidation")
            result = TechnicalFailureResult()
            LogFailure(ctx, "Cart price revalidation failed", ex)
        Finally
            If transaction IsNot Nothing Then transaction.Dispose()
            If conn IsNot Nothing Then conn.Dispose()
        End Try
        Return If(result, TechnicalFailureResult())
    End Function

    Public Function RevalidateCurrentCart(ByVal ctx As HttpContext,
                                          ByVal conn As MySqlConnection,
                                          ByVal transaction As MySqlTransaction,
                                          ByVal loginId As Integer,
                                          ByVal sessionId As String,
                                          ByVal listino As Integer,
                                          ByVal updateCart As Boolean,
                                          ByVal lockRows As Boolean,
                                          ByVal quantityOverrides As IDictionary(Of Integer, Decimal)) As CartPriceRevalidationResult
        Dim result As New CartPriceRevalidationResult()
        Try
            If ctx Is Nothing OrElse conn Is Nothing OrElse conn.State <> ConnectionState.Open OrElse
               transaction Is Nothing OrElse listino <= 0 OrElse
               (loginId <= 0 AndAlso String.IsNullOrWhiteSpace(sessionId)) Then
                Return TechnicalFailureResult()
            End If

            Dim eligibilityContext As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateContext(ctx, listino)
            Dim rows As List(Of CartPriceRevalidationRow) = LoadCartRows(conn, transaction, loginId, sessionId, lockRows)
            If rows.Count = 0 Then
                Return result
            End If
            rows.Sort(Function(left As CartPriceRevalidationRow, right As CartPriceRevalidationRow) As Integer
                          Dim articleCompare As Integer = left.ArticleId.CompareTo(right.ArticleId)
                          If articleCompare <> 0 Then Return articleCompare
                          Dim variantCompare As Integer = left.TCId.CompareTo(right.TCId)
                          If variantCompare <> 0 Then Return variantCompare
                          Return left.CartRowId.CompareTo(right.CartRowId)
                      End Function)

            Dim matchedOverrides As Integer = 0
            Dim plans As New List(Of CartPriceRevalidationPlan)()
            For Each row As CartPriceRevalidationRow In rows
                Dim requestedQuantity As Decimal
                If quantityOverrides IsNot Nothing AndAlso quantityOverrides.TryGetValue(row.CartRowId, requestedQuantity) Then
                    If requestedQuantity <= 0D Then
                        result.HasBlockingError = True
                        result.ErrorMessage = "La quantità richiesta non è valida."
                        Return result
                    End If
                    row.Quantity = requestedQuantity
                    matchedOverrides += 1
                End If

                Dim resolved As CartResolvedPrice = ResolveStandardPrice(ctx, conn, transaction, eligibilityContext, row.ArticleId, row.TCId, row.Quantity, listino, lockRows)
                If resolved.HasTechnicalError Then Return TechnicalFailureResult()
                If resolved.HasCommercialRuleError Then Return CommercialRuleFailureResult()
                If Not resolved.IsValid Then
                    result.HasBlockingError = True
                    result.ErrorMessage = "Prezzo prodotto non disponibile. Ricontrolla il carrello prima di confermare l'ordine."
                    Return result
                End If

                plans.Add(New CartPriceRevalidationPlan() With {.Row = row, .Resolved = resolved})
                If PriceChanged(row.CurrentPrice, resolved.Price) OrElse
                   PriceChanged(row.CurrentPriceIvato, resolved.PriceIvato) OrElse
                   row.CurrentOfferDetailId <> resolved.OfferDetailId OrElse
                   row.CurrentFreeShipping <> resolved.FreeShipping Then
                    result.Changes.Add(New CartPriceRevalidationChange() With {
                        .CartRowId = row.CartRowId,
                        .ArticleId = row.ArticleId,
                        .Description = row.Description,
                        .OldPriceIvato = row.CurrentPriceIvato,
                        .NewPriceIvato = resolved.PriceIvato,
                        .FreeShippingChanged = (row.CurrentFreeShipping <> resolved.FreeShipping),
                        .NewFreeShipping = resolved.FreeShipping
                    })
                End If
            Next

            If quantityOverrides IsNot Nothing AndAlso matchedOverrides <> quantityOverrides.Count Then
                result.HasBlockingError = True
                result.ErrorMessage = "Una riga del carrello non è più disponibile. Ricarica il carrello e riprova."
                Return result
            End If

            If updateCart Then
                For Each plan As CartPriceRevalidationPlan In plans
                    If Not UpdateCartRow(conn, transaction, loginId, sessionId, plan.Row, plan.Resolved, ctx) Then
                        Throw New InvalidOperationException("Owned cart row was not available during price revalidation.")
                    End If
                Next
            End If
        Catch ex As Exception
            LogFailure(ctx, "Transactional cart price revalidation failed", ex)
            Return TechnicalFailureResult()
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
            Dim priceWasChanged As Boolean = PriceChanged(c.OldPriceIvato, c.NewPriceIvato)
            If priceWasChanged Then
                sb.Append(HttpUtility.HtmlEncode(FormatCurrencyIt(c.OldPriceIvato)))
                sb.Append(" -> ")
                sb.Append(HttpUtility.HtmlEncode(FormatCurrencyIt(c.NewPriceIvato)))
            End If
            If c.FreeShippingChanged Then
                If priceWasChanged Then sb.Append("; ")
                sb.Append(HttpUtility.HtmlEncode(If(c.NewFreeShipping <> 0, "spedizione gratuita applicata", "spedizione gratuita rimossa")))
            End If
            sb.Append("</li>")
        Next
        If result.Changes.Count > maxRows Then
            sb.Append("<li>").Append(HttpUtility.HtmlEncode("Altri articoli aggiornati.")).Append("</li>")
        End If
        sb.Append("</ul>")
        Return sb.ToString()
    End Function

    Private Function LoadCartRows(ByVal conn As MySqlConnection,
                                  ByVal transaction As MySqlTransaction,
                                  ByVal loginId As Integer,
                                  ByVal sessionId As String,
                                  ByVal lockRows As Boolean) As List(Of CartPriceRevalidationRow)
        Dim rows As New List(Of CartPriceRevalidationRow)()
        Using cmd As New MySqlCommand()
            cmd.Connection = conn
            cmd.Transaction = transaction
            cmd.CommandType = CommandType.Text
            cmd.CommandText = "SELECT ID, ArticoliId, COALESCE(TCId,-1) AS TCId, COALESCE(Qnt,0) AS Qnt, COALESCE(Prezzo,0) AS Prezzo, COALESCE(PrezzoIvato,0) AS PrezzoIvato, COALESCE(OfferteDettaglioId,0) AS OfferteDettaglioId, COALESCE(Prodotto_Gratis,0) AS Prodotto_Gratis, COALESCE(Descrizione1,'') AS Descrizione1 FROM carrello WHERE " & OwnerWhere(loginId) & " ORDER BY ID"
            If lockRows Then cmd.CommandText &= " FOR UPDATE"
            AddOwnerParameters(cmd, loginId, sessionId)

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                While dr.Read()
                    Dim row As New CartPriceRevalidationRow()
                    row.CartRowId = ReadInt(dr("ID"), 0)
                    row.ArticleId = ReadInt(dr("ArticoliId"), 0)
                    row.TCId = ReadInt(dr("TCId"), -1)
                    row.Quantity = ReadDecimal(dr("Qnt"), 0D)
                    row.CurrentPrice = ReadDecimal(dr("Prezzo"), 0D)
                    row.CurrentPriceIvato = ReadDecimal(dr("PrezzoIvato"), 0D)
                    row.CurrentOfferDetailId = ReadInt(dr("OfferteDettaglioId"), 0)
                    row.CurrentFreeShipping = If(ReadInt(dr("Prodotto_Gratis"), 0) <> 0, 1, 0)
                    row.Description = Convert.ToString(dr("Descrizione1"))
                    If row.CartRowId > 0 AndAlso row.ArticleId > 0 Then rows.Add(row)
                End While
            End Using
        End Using
        Return rows
    End Function

    Private Function LoadCandidates(ByVal conn As MySqlConnection,
                                    ByVal transaction As MySqlTransaction,
                                    ByVal articleId As Integer,
                                    ByVal listino As Integer,
                                    ByVal lockCommercialRows As Boolean) As List(Of CartPriceCandidate)
        Dim candidates As New List(Of CartPriceCandidate)()
        If lockCommercialRows Then LockBaseCommercialRows(conn, transaction, articleId, listino)
        Dim sql As String = "SELECT DISTINCT v.ID, COALESCE(v.TCid,-1) AS TCid, COALESCE(v.Codice,'') AS Codice, COALESCE(v.Descrizione1,'') AS Descrizione1, v.Prezzo, v.PrezzoIvato, v.IdIvaRC, v.ValoreIvaRC, v.DescrizioneIvaRC FROM vsuperarticoli v WHERE v.NListino=?listino AND v.ID=?id ORDER BY v.ID, CASE WHEN COALESCE(v.TCid,-1) IN (-1,0) THEN 0 ELSE 1 END, COALESCE(v.TCid,-1) ASC"
        Using cmd As New MySqlCommand(sql, conn, transaction)
            cmd.Parameters.Add("?listino", MySqlDbType.Int32).Value = listino
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = articleId

            Using dr As MySqlDataReader = cmd.ExecuteReader()
                While dr.Read()
                    Dim item As New CartPriceCandidate()
                    item.ArticleId = ReadInt(dr("ID"), 0)
                    item.TCId = ReadInt(dr("TCid"), -1)
                    item.Code = Convert.ToString(dr("Codice"))
                    item.Description = Convert.ToString(dr("Descrizione1"))
                    item.Price = ReadDecimal(dr("Prezzo"), 0D)
                    item.PriceIvato = ReadDecimal(dr("PrezzoIvato"), 0D)
                    item.ReverseChargeVatId = ReadInt(dr("IdIvaRC"), -1)
                    item.ReverseChargeVatValue = ReadDecimal(dr("ValoreIvaRC"), -1D)
                    item.ReverseChargeDescription = Convert.ToString(dr("DescrizioneIvaRC"))
                    candidates.Add(item)
                End While
            End Using
        End Using
        Return candidates
    End Function

    Private Sub LockBaseCommercialRows(ByVal conn As MySqlConnection,
                                       ByVal transaction As MySqlTransaction,
                                       ByVal articleId As Integer,
                                       ByVal listino As Integer)
        Using cmd As New MySqlCommand(
            "SELECT al.id, a.id AS articleId, COALESCE(i.id,-1) AS reverseChargeVatId FROM articoli a " &
            "INNER JOIN articoli_listini al ON al.ArticoliId=a.id AND al.NListino=?listino " &
            "LEFT JOIN iva i ON i.id=a.IdIvaReverseCharge " &
            "WHERE a.id=?articleId ORDER BY al.id FOR UPDATE",
            conn,
            transaction)
            cmd.Parameters.Add("?listino", MySqlDbType.Int32).Value = listino
            cmd.Parameters.Add("?articleId", MySqlDbType.Int32).Value = articleId
            Using reader As MySqlDataReader = cmd.ExecuteReader()
                If Not reader.Read() Then Throw New InvalidOperationException("Commercial base row is not available.")
            End Using
        End Using
    End Sub

    Friend Function ResolveStandardPrice(ByVal ctx As HttpContext,
                                         ByVal conn As MySqlConnection,
                                         ByVal transaction As MySqlTransaction,
                                         ByVal eligibilityContext As ProductPromotionEligibilityContext,
                                         ByVal articleId As Integer,
                                         ByVal tcId As Integer,
                                         ByVal quantity As Decimal,
                                         ByVal listino As Integer,
                                         ByVal lockCommercialRows As Boolean) As CartResolvedPrice
        Dim resolved As New CartResolvedPrice()
        Dim allCandidates As List(Of CartPriceCandidate) = LoadCandidates(conn, transaction, articleId, listino, lockCommercialRows)
        If allCandidates Is Nothing OrElse allCandidates.Count = 0 Then Return resolved

        Dim candidates As List(Of CartPriceCandidate) = allCandidates.FindAll(Function(x) x.TCId = tcId)
        If candidates.Count = 0 AndAlso tcId <= 0 Then candidates = allCandidates.FindAll(Function(x) x.TCId <= 0)
        If candidates.Count = 0 Then candidates = allCandidates.FindAll(Function(x) x.TCId <= 0)
        If candidates.Count = 0 Then Return resolved

        Dim baseRow As CartPriceCandidate = candidates(0)
        Dim price As Decimal = baseRow.Price
        Dim priceIvato As Decimal = ResolvePriceIvato(ctx, baseRow, price, baseRow.PriceIvato)
        If price <= 0 OrElse priceIvato <= 0 Then Return resolved

        Dim promotion As ProductPromotionEligibilityResult
        If transaction IsNot Nothing Then
            promotion = ProductPromotionEligibilityResolver.Resolve(conn, transaction, eligibilityContext, articleId, tcId, quantity, price, priceIvato)
        Else
            promotion = ProductPromotionEligibilityResolver.Resolve(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString, eligibilityContext, articleId, tcId, quantity, price, priceIvato)
        End If
        If promotion Is Nothing OrElse promotion.HasTechnicalError Then
            resolved.HasTechnicalError = True
            Return resolved
        End If
        If promotion.Status = ProductPromotionEligibilityLoadStatus.AmbiguousCommercialRule Then
            resolved.HasCommercialRuleError = True
            Return resolved
        End If
        If promotion.Status = ProductPromotionEligibilityLoadStatus.InvalidRequest Then Return resolved
        Dim offerId As Integer = 0
        If promotion.HasAppliedOffer Then
            price = promotion.EffectivePriceNet
            priceIvato = promotion.EffectivePriceGross
            offerId = promotion.AppliedOffer.OfferDetailId
        End If

        Dim freeShipping As ProductFreeShippingEligibilityResult = ProductFreeShippingEligibilityResolver.Resolve(
            conn,
            transaction,
            articleId,
            eligibilityContext.CompanyId,
            listino,
            eligibilityContext.EvaluationDate,
            lockCommercialRows)
        If freeShipping Is Nothing OrElse freeShipping.Status <> ProductFreeShippingEligibilityStatus.Success Then
            resolved.HasTechnicalError = True
            Return resolved
        End If

        price = RoundCurrency(price)
        priceIvato = RoundCurrency(priceIvato)

        resolved.IsValid = True
        resolved.ArticleId = articleId
        resolved.EffectiveTCId = If(baseRow.TCId > 0, baseRow.TCId, -1)
        resolved.Code = baseRow.Code
        resolved.Description = baseRow.Description
        resolved.Price = price
        resolved.PriceIvato = priceIvato
        resolved.OfferDetailId = offerId
        resolved.ReverseChargeVatId = If(ReverseChargeEnabled(ctx) AndAlso baseRow.ReverseChargeVatId > -1, baseRow.ReverseChargeVatId, -1)
        resolved.ReverseChargeVatValue = If(resolved.ReverseChargeVatId > -1, baseRow.ReverseChargeVatValue, -1)
        resolved.ReverseChargeDescription = If(resolved.ReverseChargeVatId > -1, baseRow.ReverseChargeDescription, "")
        resolved.FreeShipping = If(freeShipping.Eligible, 1, 0)
        Return resolved
    End Function

    Private Function ResolvePriceIvato(ByVal ctx As HttpContext, ByVal row As CartPriceCandidate, ByVal price As Decimal, ByVal fallbackIvato As Decimal) As Decimal
        If ReverseChargeEnabled(ctx) AndAlso row.ReverseChargeVatId > -1 AndAlso row.ReverseChargeVatValue > -1 Then
            Return price * ((row.ReverseChargeVatValue / 100) + 1)
        End If

        Dim ivaUtente As Decimal = SessionDecimal(ctx, "Iva_Utente", -1D)
        If ivaUtente > -1 Then Return price * ((ivaUtente / 100) + 1)
        Return fallbackIvato
    End Function

    Public Function RoundCurrency(ByVal value As Decimal) As Decimal
        Return Math.Round(value, 2, MidpointRounding.AwayFromZero)
    End Function

    Private Function UpdateCartRow(ByVal conn As MySqlConnection,
                                   ByVal transaction As MySqlTransaction,
                                   ByVal loginId As Integer,
                                   ByVal sessionId As String,
                                   ByVal row As CartPriceRevalidationRow,
                                   ByVal resolved As CartResolvedPrice,
                                   ByVal ctx As HttpContext) As Boolean
        Using cmd As New MySqlCommand()
            cmd.Connection = conn
            cmd.Transaction = transaction
            cmd.CommandType = CommandType.Text
            cmd.CommandText = "UPDATE carrello SET Qnt=?qnt, Prezzo=?prezzo, PrezzoIvato=?prezzoIvato, OfferteDettaglioId=?offertaId, Prodotto_Gratis=?freeShipping, IdIvaRC=?idIvaRC, ValoreIvaRC=?valoreIvaRC, DescrizioneIvaRC=?descrizioneIvaRC, IdEsenzioneIva=?idEsenzioneIva, ValoreEsenzioneIva=?valoreEsenzioneIva, DescrizioneEsenzioneIva=?descrizioneEsenzioneIva WHERE ID=?id AND " & OwnerWhere(loginId)
            AddDecimalParameter(cmd, "?qnt", row.Quantity)
            AddDecimalParameter(cmd, "?prezzo", resolved.Price)
            AddDecimalParameter(cmd, "?prezzoIvato", resolved.PriceIvato)
            cmd.Parameters.Add("?offertaId", MySqlDbType.Int32).Value = resolved.OfferDetailId
            cmd.Parameters.Add("?freeShipping", MySqlDbType.Int32).Value = If(resolved.FreeShipping <> 0, 1, 0)
            cmd.Parameters.Add("?idIvaRC", MySqlDbType.Int32).Value = resolved.ReverseChargeVatId
            AddDecimalParameter(cmd, "?valoreIvaRC", resolved.ReverseChargeVatValue)
            cmd.Parameters.Add("?descrizioneIvaRC", MySqlDbType.VarChar).Value = If(resolved.ReverseChargeDescription, "")
            cmd.Parameters.Add("?idEsenzioneIva", MySqlDbType.Int32).Value = SessionInt(ctx, "IdEsenzioneIva", -1)
            AddDecimalParameter(cmd, "?valoreEsenzioneIva", SessionDecimal(ctx, "Iva_Utente", -1D))
            cmd.Parameters.Add("?descrizioneEsenzioneIva", MySqlDbType.VarChar).Value = SessionText(ctx, "DescrizioneEsenzioneIva", "")
            cmd.Parameters.Add("?id", MySqlDbType.Int32).Value = row.CartRowId
            AddOwnerParameters(cmd, loginId, sessionId)
            cmd.ExecuteNonQuery()
        End Using

        Using verify As New MySqlCommand(
            "SELECT COUNT(*) FROM carrello WHERE ID=?id AND " & OwnerWhere(loginId) &
            " AND ABS(Qnt-?qnt)<0.00000001 AND ABS(Prezzo-?prezzo)<0.00000001 " &
            "AND ABS(PrezzoIvato-?prezzoIvato)<0.00000001 AND COALESCE(OfferteDettaglioId,0)=?offertaId " &
            "AND COALESCE(Prodotto_Gratis,0)=?freeShipping",
            conn,
            transaction)
            verify.Parameters.Add("?id", MySqlDbType.Int32).Value = row.CartRowId
            AddOwnerParameters(verify, loginId, sessionId)
            AddDecimalParameter(verify, "?qnt", row.Quantity)
            AddDecimalParameter(verify, "?prezzo", resolved.Price)
            AddDecimalParameter(verify, "?prezzoIvato", resolved.PriceIvato)
            verify.Parameters.Add("?offertaId", MySqlDbType.Int32).Value = resolved.OfferDetailId
            verify.Parameters.Add("?freeShipping", MySqlDbType.Int32).Value = If(resolved.FreeShipping <> 0, 1, 0)
            Return Convert.ToInt32(verify.ExecuteScalar(), CultureInfo.InvariantCulture) = 1
        End Using
    End Function

    Private Function OwnerWhere(ByVal loginId As Integer) As String
        If loginId > 0 Then Return "LoginId=?ownerLoginId"
        Return "COALESCE(LoginId,0)<=0 AND SessionId=?ownerSessionId"
    End Function

    Private Sub AddOwnerParameters(ByVal cmd As MySqlCommand, ByVal loginId As Integer, ByVal sessionId As String)
        If loginId > 0 Then
            cmd.Parameters.Add("?ownerLoginId", MySqlDbType.Int32).Value = loginId
        Else
            cmd.Parameters.Add("?ownerSessionId", MySqlDbType.VarChar, 50).Value = If(sessionId, "")
        End If
    End Sub

    Private Function ReverseChargeEnabled(ByVal ctx As HttpContext) As Boolean
        Return SessionInt(ctx, "AbilitatoIvaReverseCharge", 0) = 1
    End Function

    Private Function PriceChanged(ByVal oldValue As Decimal, ByVal newValue As Decimal) As Boolean
        Return Math.Abs(oldValue - newValue) >= 0.005D
    End Function

    Private Function FormatCurrencyIt(ByVal value As Decimal) As String
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

    Private Function SessionDecimal(ByVal ctx As HttpContext, ByVal key As String, ByVal defaultValue As Decimal) As Decimal
        Try
            If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing AndAlso ctx.Session(key) IsNot Nothing Then
                Return ReadDecimal(ctx.Session(key), defaultValue)
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

    Private Function ReadDecimal(ByVal value As Object, ByVal defaultValue As Decimal) As Decimal
        Dim output As Decimal = defaultValue
        Try
            If value IsNot Nothing AndAlso value IsNot DBNull.Value Then
                If TypeOf value Is Byte OrElse TypeOf value Is Short OrElse TypeOf value Is Integer OrElse TypeOf value Is Long OrElse
                   TypeOf value Is Single OrElse TypeOf value Is Double OrElse TypeOf value Is Decimal Then
                    Return Convert.ToDecimal(value, CultureInfo.InvariantCulture)
                End If

                Dim text As String = Convert.ToString(value).Trim()
                If text.IndexOf(","c) >= 0 AndAlso text.IndexOf("."c) < 0 Then
                    If Decimal.TryParse(text, NumberStyles.Any, PriceCulture, output) Then Return output
                    If Decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, output) Then Return output
                Else
                    If Decimal.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, output) Then Return output
                    If Decimal.TryParse(text, NumberStyles.Any, PriceCulture, output) Then Return output
                End If
            End If
        Catch
        End Try
        Return defaultValue
    End Function

    Private Sub AddDecimalParameter(ByVal cmd As MySqlCommand, ByVal name As String, ByVal value As Decimal)
        Dim parameter As MySqlParameter = cmd.Parameters.Add(name, MySqlDbType.Decimal)
        parameter.Precision = 15
        parameter.Scale = 8
        parameter.Value = value
    End Sub

    Private Function TechnicalFailureResult() As CartPriceRevalidationResult
        Return New CartPriceRevalidationResult() With {
            .HasBlockingError = True,
            .HasTechnicalError = True,
            .ErrorMessage = GenericTechnicalErrorMessage
        }
    End Function

    Private Function CommercialRuleFailureResult() As CartPriceRevalidationResult
        Return New CartPriceRevalidationResult() With {
            .HasBlockingError = True,
            .HasCommercialRuleError = True,
            .ErrorMessage = GenericCommercialRuleErrorMessage
        }
    End Function

    Private Sub TryRollback(ByVal transaction As MySqlTransaction, ByVal ctx As HttpContext, ByVal operationName As String)
        If transaction Is Nothing Then Return
        Try
            transaction.Rollback()
        Catch rollbackError As Exception
            LogFailure(ctx, "Rollback failed for " & operationName, rollbackError)
        End Try
    End Sub

    Private Sub LogFailure(ByVal ctx As HttpContext, ByVal message As String, ByVal ex As Exception)
        Try
            KeepStoreLog.Error("cart-price-revalidation", message & ". Error type: " & ex.GetType().Name & ".", Nothing, ctx)
        Catch logError As Exception
            System.Diagnostics.Trace.TraceError("cart-price-revalidation logging failed. Error type: " & logError.GetType().Name & ".")
        End Try
    End Sub
End Module
