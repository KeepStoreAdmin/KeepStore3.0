Imports Microsoft.VisualBasic
Imports MySql.Data.MySqlClient
Imports System
Imports System.Collections
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports System.Web

Public Class CartAddResult
    Public Success As Boolean
    Public Message As String
    Public ArticleIds As String
    Public RowsAffected As Integer
End Class

Public Module CartAddService
    Private ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Public Function AddProduct(ByVal ctx As HttpContext,
                               ByVal articleId As Integer,
                               ByVal tcId As Integer,
                               ByVal qty As Double,
                               ByVal prodottoGratis As Integer,
                               ByVal source As String) As CartAddResult
        Dim result As New CartAddResult()
        result.Success = False
        result.ArticleIds = String.Empty
        result.RowsAffected = 0

        If ctx Is Nothing OrElse ctx.Session Is Nothing Then
            result.Message = "Sessione non disponibile."
            Return result
        End If

        If articleId <= 0 Then
            result.Message = "Articolo non valido."
            Return result
        End If

        If qty <= 0 Then qty = 1
        If qty > 9999 Then qty = 9999
        If tcId <= 0 Then tcId = -1

        Dim loginId As Integer = GetLoginId(ctx)
        Dim sessionId As String = ctx.Session.SessionID
        Dim listino As Integer = GetSessionInt(ctx, "Listino", 1)
        If listino <= 0 Then listino = 1

        Dim cs As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If cs Is Nothing OrElse String.IsNullOrEmpty(cs.ConnectionString) Then
            result.Message = "Connection string non configurata."
            Return result
        End If

        Try
            Using conn As New MySqlConnection(cs.ConnectionString)
                conn.Open()
                Using tx As MySqlTransaction = conn.BeginTransaction()
                    Dim product As Dictionary(Of String, Object) = LoadProductRow(conn, tx, articleId, tcId, listino)
                    If product Is Nothing Then
                        tx.Rollback()
                        result.Message = "Articolo non trovato nel listino corrente."
                        Return result
                    End If

                    Dim resolvedTcId As Integer = SafeInt(GetValue(product, "TCid"), tcId)
                    If resolvedTcId <= 0 Then resolvedTcId = -1

                    Dim codice As String = SafeString(GetValue(product, "Codice"))
                    Dim descrizione As String = SafeString(GetValue(product, "Descrizione1"))
                    Dim prezzo As Double = SafeDouble(GetValue(product, "Prezzo"))
                    Dim prezzoIvato As Double = SafeDouble(GetValue(product, "PrezzoIvato"))
                    Dim offerteDettaglioId As Integer = 0

                    ApplyPromo(product, qty, prezzo, prezzoIvato, offerteDettaglioId)

                    Dim existingId As Integer = 0
                    Dim existingQty As Double = 0
                    LoadExistingCartRow(conn, tx, loginId, sessionId, articleId, resolvedTcId, existingId, existingQty)

                    Dim finalQty As Double = qty
                    If existingId > 0 Then finalQty += existingQty

                    If existingId > 0 Then
                        result.RowsAffected = UpdateCartRow(conn, tx, existingId, finalQty, listino, prezzo, prezzoIvato, offerteDettaglioId, prodottoGratis)
                    Else
                        result.RowsAffected = InsertCartRow(conn, tx, loginId, sessionId, articleId, resolvedTcId, codice, descrizione, finalQty, listino, prezzo, prezzoIvato, offerteDettaglioId, prodottoGratis)
                    End If

                    tx.Commit()
                    result.Success = (result.RowsAffected > 0)
                    result.ArticleIds = articleId.ToString(CultureInfo.InvariantCulture)
                    If result.Success Then
                        result.Message = "Articolo aggiunto al carrello."
                    Else
                        result.Message = "Nessuna riga carrello aggiornata."
                    End If
                End Using
            End Using
        Catch ex As Exception
            result.Success = False
            result.Message = ex.Message
            Try
                KeepStoreLog.Error("CartAddService", "Errore AddProduct source=" & Convert.ToString(source) & " id=" & articleId.ToString(CultureInfo.InvariantCulture) & " tcid=" & tcId.ToString(CultureInfo.InvariantCulture), ex, ctx)
            Catch
            End Try
        End Try

        Return result
    End Function

    Private Function LoadProductRow(ByVal conn As MySqlConnection,
                                    ByVal tx As MySqlTransaction,
                                    ByVal articleId As Integer,
                                    ByVal tcId As Integer,
                                    ByVal listino As Integer) As Dictionary(Of String, Object)
        Dim row As Dictionary(Of String, Object) = Nothing

        If tcId > 0 Then
            row = QuerySingle(conn, tx,
                              "SELECT * FROM vsuperarticoli WHERE id=@id AND TCId=@tcid AND NListino=@listino ORDER BY PrezzoPromo DESC LIMIT 1",
                              New Object(,) {{"@id", articleId}, {"@tcid", tcId}, {"@listino", listino}})
            If row IsNot Nothing Then Return row
        End If

        row = QuerySingle(conn, tx,
                          "SELECT * FROM vsuperarticoli WHERE id=@id AND NListino=@listino ORDER BY CASE WHEN COALESCE(TCid,-1) IN (-1,0) THEN 0 ELSE 1 END, PrezzoPromo DESC LIMIT 1",
                          New Object(,) {{"@id", articleId}, {"@listino", listino}})
        If row IsNot Nothing Then Return row

        Return QuerySingle(conn, tx,
                           "SELECT id, -1 AS TCid, Codice, Descrizione1, 0 AS Prezzo, 0 AS PrezzoIvato, 0 AS InOfferta, 0 AS PrezzoPromo, 0 AS PrezzoPromoIvato, 0 AS OfferteQntMinima, 0 AS OfferteMultipli, 0 AS OfferteDettagliId FROM articoli WHERE id=@id AND Abilitato=1 LIMIT 1",
                           New Object(,) {{"@id", articleId}})
    End Function

    Private Sub LoadExistingCartRow(ByVal conn As MySqlConnection,
                                    ByVal tx As MySqlTransaction,
                                    ByVal loginId As Integer,
                                    ByVal sessionId As String,
                                    ByVal articleId As Integer,
                                    ByVal tcId As Integer,
                                    ByRef existingId As Integer,
                                    ByRef existingQty As Double)
        Dim sql As String
        Dim pars As Object(,)

        If loginId > 0 Then
            sql = "SELECT id, Qnt FROM carrello WHERE LoginId=@loginId AND ArticoliId=@id AND TCId=@tcid ORDER BY id DESC LIMIT 1"
            pars = New Object(,) {{"@loginId", loginId}, {"@id", articleId}, {"@tcid", tcId}}
        Else
            sql = "SELECT id, Qnt FROM carrello WHERE SessionId=@sessionId AND ArticoliId=@id AND TCId=@tcid ORDER BY id DESC LIMIT 1"
            pars = New Object(,) {{"@sessionId", sessionId}, {"@id", articleId}, {"@tcid", tcId}}
        End If

        Dim row As Dictionary(Of String, Object) = QuerySingle(conn, tx, sql, pars)
        If row Is Nothing Then Return

        existingId = SafeInt(GetValue(row, "id"), 0)
        existingQty = SafeDouble(GetValue(row, "Qnt"))
    End Sub

    Private Function InsertCartRow(ByVal conn As MySqlConnection,
                                   ByVal tx As MySqlTransaction,
                                   ByVal loginId As Integer,
                                   ByVal sessionId As String,
                                   ByVal articleId As Integer,
                                   ByVal tcId As Integer,
                                   ByVal codice As String,
                                   ByVal descrizione As String,
                                   ByVal qty As Double,
                                   ByVal listino As Integer,
                                   ByVal prezzo As Double,
                                   ByVal prezzoIvato As Double,
                                   ByVal offerteDettaglioId As Integer,
                                   ByVal prodottoGratis As Integer) As Integer
        Dim sql As String = "INSERT INTO carrello " &
                            "(LoginId, SessionId, ArticoliId, TCId, Codice, Descrizione1, Qnt, NListino, Prezzo, PrezzoIvato, OfferteDettaglioId, Prodotto_Gratis) " &
                            "VALUES (@loginId, @sessionId, @articleId, @tcId, @codice, @descrizione, @qty, @listino, @prezzo, @prezzoIvato, @offertaId, @prodottoGratis)"

        Using cmd As New MySqlCommand(sql, conn, tx)
            AddCartParameters(cmd, loginId, sessionId, articleId, tcId, codice, descrizione, qty, listino, prezzo, prezzoIvato, offerteDettaglioId, prodottoGratis)
            Return cmd.ExecuteNonQuery()
        End Using
    End Function

    Private Function UpdateCartRow(ByVal conn As MySqlConnection,
                                   ByVal tx As MySqlTransaction,
                                   ByVal existingId As Integer,
                                   ByVal qty As Double,
                                   ByVal listino As Integer,
                                   ByVal prezzo As Double,
                                   ByVal prezzoIvato As Double,
                                   ByVal offerteDettaglioId As Integer,
                                   ByVal prodottoGratis As Integer) As Integer
        Dim sql As String = "UPDATE carrello SET Qnt=@qty, NListino=@listino, Prezzo=@prezzo, PrezzoIvato=@prezzoIvato, OfferteDettaglioId=@offertaId, Prodotto_Gratis=@prodottoGratis WHERE id=@id"

        Using cmd As New MySqlCommand(sql, conn, tx)
            cmd.Parameters.Add("@qty", MySqlDbType.Double).Value = qty
            cmd.Parameters.Add("@listino", MySqlDbType.Int32).Value = listino
            cmd.Parameters.Add("@prezzo", MySqlDbType.Double).Value = prezzo
            cmd.Parameters.Add("@prezzoIvato", MySqlDbType.Double).Value = prezzoIvato
            cmd.Parameters.Add("@offertaId", MySqlDbType.Int32).Value = offerteDettaglioId
            cmd.Parameters.Add("@prodottoGratis", MySqlDbType.Int32).Value = prodottoGratis
            cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = existingId
            Return cmd.ExecuteNonQuery()
        End Using
    End Function

    Private Sub AddCartParameters(ByVal cmd As MySqlCommand,
                                  ByVal loginId As Integer,
                                  ByVal sessionId As String,
                                  ByVal articleId As Integer,
                                  ByVal tcId As Integer,
                                  ByVal codice As String,
                                  ByVal descrizione As String,
                                  ByVal qty As Double,
                                  ByVal listino As Integer,
                                  ByVal prezzo As Double,
                                  ByVal prezzoIvato As Double,
                                  ByVal offerteDettaglioId As Integer,
                                  ByVal prodottoGratis As Integer)
        cmd.Parameters.Add("@loginId", MySqlDbType.Int32).Value = loginId
        cmd.Parameters.Add("@sessionId", MySqlDbType.VarChar).Value = If(sessionId, String.Empty)
        cmd.Parameters.Add("@articleId", MySqlDbType.Int32).Value = articleId
        cmd.Parameters.Add("@tcId", MySqlDbType.Int32).Value = tcId
        cmd.Parameters.Add("@codice", MySqlDbType.VarChar).Value = If(codice, String.Empty)
        cmd.Parameters.Add("@descrizione", MySqlDbType.VarChar).Value = If(descrizione, String.Empty)
        cmd.Parameters.Add("@qty", MySqlDbType.Double).Value = qty
        cmd.Parameters.Add("@listino", MySqlDbType.Int32).Value = listino
        cmd.Parameters.Add("@prezzo", MySqlDbType.Double).Value = prezzo
        cmd.Parameters.Add("@prezzoIvato", MySqlDbType.Double).Value = prezzoIvato
        cmd.Parameters.Add("@offertaId", MySqlDbType.Int32).Value = offerteDettaglioId
        cmd.Parameters.Add("@prodottoGratis", MySqlDbType.Int32).Value = prodottoGratis
    End Sub

    Private Function QuerySingle(ByVal conn As MySqlConnection, ByVal tx As MySqlTransaction, ByVal sql As String, ByVal pars As Object(,)) As Dictionary(Of String, Object)
        Using cmd As New MySqlCommand(sql, conn, tx)
            AddParameters(cmd, pars)
            Using rdr As MySqlDataReader = cmd.ExecuteReader()
                If Not rdr.Read() Then Return Nothing
                Dim row As New Dictionary(Of String, Object)(StringComparer.OrdinalIgnoreCase)
                For i As Integer = 0 To rdr.FieldCount - 1
                    row(rdr.GetName(i)) = rdr.GetValue(i)
                Next
                Return row
            End Using
        End Using
    End Function

    Private Sub AddParameters(ByVal cmd As MySqlCommand, ByVal pars As Object(,))
        If pars Is Nothing Then Exit Sub
        For i As Integer = 0 To pars.GetLength(0) - 1
            cmd.Parameters.AddWithValue(Convert.ToString(pars(i, 0)), pars(i, 1))
        Next
    End Sub

    Private Sub ApplyPromo(ByVal row As Dictionary(Of String, Object), ByVal qty As Double, ByRef prezzo As Double, ByRef prezzoIvato As Double, ByRef offerteDettaglioId As Integer)
        If SafeInt(GetValue(row, "InOfferta"), 0) <> 1 Then Exit Sub

        Dim qMin As Double = SafeDouble(GetValue(row, "OfferteQntMinima"))
        Dim multipli As Double = SafeDouble(GetValue(row, "OfferteMultipli"))
        Dim promoOk As Boolean = False

        If qMin > 0 AndAlso qty >= qMin Then promoOk = True
        If Not promoOk AndAlso multipli > 0 Then
            Dim ratio As Double = qty / multipli
            promoOk = (Math.Abs(ratio - Math.Round(ratio)) < 0.0001)
        End If

        If Not promoOk Then Exit Sub

        offerteDettaglioId = SafeInt(GetValue(row, "OfferteDettagliId"), 0)
        Dim promo As Double = SafeDouble(GetValue(row, "PrezzoPromo"))
        Dim promoIvato As Double = SafeDouble(GetValue(row, "PrezzoPromoIvato"))
        If promo > 0 Then prezzo = promo
        If promoIvato > 0 Then prezzoIvato = promoIvato
    End Sub

    Private Function GetLoginId(ByVal ctx As HttpContext) As Integer
        Dim id As Integer = GetSessionInt(ctx, "LoginId", 0)
        If id <= 0 Then id = GetSessionInt(ctx, "LoginID", 0)
        Return id
    End Function

    Private Function GetSessionInt(ByVal ctx As HttpContext, ByVal key As String, ByVal fallback As Integer) As Integer
        Try
            If ctx IsNot Nothing AndAlso ctx.Session IsNot Nothing AndAlso ctx.Session(key) IsNot Nothing Then
                Dim value As Integer = fallback
                If Integer.TryParse(Convert.ToString(ctx.Session(key)), value) Then Return value
            End If
        Catch
        End Try
        Return fallback
    End Function

    Private Function GetValue(ByVal row As Dictionary(Of String, Object), ByVal key As String) As Object
        If row Is Nothing OrElse key Is Nothing Then Return Nothing
        If row.ContainsKey(key) Then Return row(key)
        Return Nothing
    End Function

    Private Function SafeString(ByVal raw As Object) As String
        If raw Is Nothing OrElse raw Is DBNull.Value Then Return String.Empty
        Return Convert.ToString(raw)
    End Function

    Private Function SafeInt(ByVal raw As Object, ByVal fallback As Integer) As Integer
        Dim value As Integer = fallback
        If raw IsNot Nothing AndAlso raw IsNot DBNull.Value Then Integer.TryParse(Convert.ToString(raw), value)
        Return value
    End Function

    Private Function SafeDouble(ByVal raw As Object) As Double
        Dim value As Double = 0
        If raw Is Nothing OrElse raw Is DBNull.Value Then Return value
        Dim text As String = Convert.ToString(raw)
        If Double.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, value) Then Return value
        If Double.TryParse(text, NumberStyles.Any, ItCulture, value) Then Return value
        Return 0
    End Function
End Module
