Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

' ORDER-REMOTE-PAYMENT-1A. Legge i FATTI di un documento per KeepStoreRemotePayment: UNA sola query, filtrata per documento, utente e azienda gia verificati dal chiamante.
' Ogni errore (tabella o colonna mancante, connessione) restituisce Nothing: la decisione chiude. La query e una sola per tutte le pagine (lista, dettaglio, PayPal, Banca Sella).
Public Module KeepStoreRemotePaymentStore
    Public Const FactsSql As String =
        "SELECT d.id,COALESCE(d.OrigineOrdine,'') RpOrigin,COALESCE(d.Ordine_Web,0) RpOrdineWeb,d.DataDocumento RpDocDate,CURDATE() RpToday,NOW() RpNow," &
        "COALESCE(d.Pagato,0) RpPagato,COALESCE(d.StatiId,0) RpStatiId,COALESCE(d.StatoPagamentoWeb,0) RpStato,d.DataStatoPagamentoWeb RpStatoData,COALESCE(d.UltimoEsitoPagamentoWeb,'') RpEsito," &
        "COALESCE(p.OnLine,0) RpOnLine,COALESCE(p.PermettiPagamentoSuccessivo,0) RpPermetti,COALESCE(pie.TotaleDocumento,0) RpTotale," &
        "CASE WHEN td.Web=1 AND td.Abilitato=1 AND td.ImpegnaQnt=1 THEN 1 ELSE 0 END RpValidType," &
        "CASE WHEN EXISTS (SELECT 1 FROM bancasella_ordini_pagati rb WHERE rb.DocumentiId=d.id AND COALESCE(rb.codiceAutorizzazione,'')<>'') THEN 1 ELSE 0 END RpSella," &
        "CASE WHEN EXISTS (SELECT 1 FROM paypal_checkout_transazioni rt WHERE rt.DocumentiId=d.id) THEN 1 ELSE 0 END RpPayPalAny," &
        "CASE WHEN EXISTS (SELECT 1 FROM paypal_checkout_transazioni ro WHERE ro.DocumentiId=d.id AND ro.Stato NOT IN ('CANCELED','FAILED','DENIED','DECLINED','VOIDED','SUPERSEDED') AND (ro.PagamentiTipoId<>d.PagamentiTipoId OR COALESCE(p.OnLine,0)<>2)) THEN 1 ELSE 0 END RpPayPalOther " &
        "FROM documenti d LEFT JOIN pagamentitipo p ON p.id=d.PagamentiTipoId LEFT JOIN tipodocumenti td ON td.id=d.TipoDocumentiId " &
        "LEFT JOIN documentipie pie ON pie.DocumentiId=d.id WHERE d.id=@id AND d.UtentiId=@uid AND d.AziendeId=@azienda LIMIT 1"

    ' Avvio Banca Sella: nessuna tabella dei tentativi, quindi si scrivono la data e l'ultimo esito "Pagamento con carta avviato" (lo stato di pagamento NON cambia: le etichette restano vere
    ' per ogni gateway; solo da 0, 3, 4, 5 e non pagato): serve a non scavalcare con PayPal un pagamento carta appena avviato.
    Public Const SellaStartSql As String =
        "UPDATE documenti SET DataStatoPagamentoWeb=CURRENT_TIMESTAMP,UltimoEsitoPagamentoWeb=@outcome WHERE id=@id AND UtentiId=@uid AND AziendeId=@azienda " &
        "AND COALESCE(Pagato,0)=0 AND COALESCE(StatoPagamentoWeb,0) IN (0,3,4,5)"

    Private Function ConnectionText() As String
        Return ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
    End Function

    Private Function AsInt(ByVal value As Object) As Integer
        If value Is Nothing OrElse IsDBNull(value) Then Return 0
        Dim parsed As Integer = 0
        Integer.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, parsed)
        Return parsed
    End Function

    Private Function AsDate(ByVal value As Object) As DateTime
        If value Is Nothing OrElse IsDBNull(value) Then Return DateTime.MinValue
        Return Convert.ToDateTime(value, CultureInfo.InvariantCulture)
    End Function

    Public Function LoadFacts(ByVal documentId As Integer, ByVal utentiId As Long, ByVal aziendaId As Integer) As RemotePaymentFacts
        If documentId <= 0 OrElse utentiId <= 0 OrElse aziendaId <= 0 Then Return Nothing
        Try
            Using conn As New MySqlConnection(ConnectionText())
                conn.Open()
                Dim facts As New RemotePaymentFacts()
                Using cmd As New MySqlCommand(FactsSql, conn)
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    cmd.Parameters.Add("@uid", MySqlDbType.Int64).Value = utentiId
                    cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = aziendaId
                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If Not dr.Read() Then Return Nothing
                        facts.Origin = Convert.ToString(dr("RpOrigin")).Trim()
                        facts.OrdineWeb = AsInt(dr("RpOrdineWeb"))
                        facts.DocumentDate = AsDate(dr("RpDocDate"))
                        facts.Today = AsDate(dr("RpToday"))
                        facts.DbNow = AsDate(dr("RpNow"))
                        facts.Paid = AsInt(dr("RpPagato"))
                        facts.DocumentState = AsInt(dr("RpStatiId"))
                        facts.PaymentState = AsInt(dr("RpStato"))
                        facts.PaymentStateDate = AsDate(dr("RpStatoData"))
                        facts.LastOutcome = Convert.ToString(dr("RpEsito")).Trim()
                        facts.OnlineMethod = AsInt(dr("RpOnLine"))
                        facts.AllowLater = AsInt(dr("RpPermetti"))
                        facts.Total = Convert.ToDecimal(dr("RpTotale"), CultureInfo.InvariantCulture)
                        facts.ValidOrderType = AsInt(dr("RpValidType")) = 1
                        facts.SellaAuthorized = AsInt(dr("RpSella")) = 1
                        facts.PayPalAny = AsInt(dr("RpPayPalAny")) = 1
                        facts.PayPalOpenOther = AsInt(dr("RpPayPalOther")) = 1
                    End Using
                End Using
                ' Il legame con Amazon o eBay si cerca solo per gli ordini senza origine e non del sito; una tabella assente non e un legame.
                If facts.Origin.Length = 0 AndAlso facts.OrdineWeb = 0 Then
                    facts.Marketplace = HasMarketplaceLink(conn, "ks_amazon_orders", documentId) OrElse HasMarketplaceLink(conn, "ks_ebay_orders", documentId)
                End If
                Return facts
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("remote-payment", "LoadFacts documentId=" & documentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
            Return Nothing
        End Try
    End Function

    Private Function HasMarketplaceLink(ByVal conn As MySqlConnection, ByVal tableName As String, ByVal documentId As Integer) As Boolean
        Try
            Using cmd As New MySqlCommand("SELECT COUNT(*) FROM " & tableName & " WHERE document_id=@id", conn)
                cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                Return Convert.ToInt32(cmd.ExecuteScalar(), CultureInfo.InvariantCulture) > 0
            End Using
        Catch
            Return False
        End Try
    End Function

    ' Un'unica chiamata per le pagine: fatti + decisione.
    Public Function CanPayNow(ByVal documentId As Integer, ByVal utentiId As Long, ByVal aziendaId As Integer) As Boolean
        Return InternalOrderRemotePaymentPolicy.CanPayNow(LoadFacts(documentId, utentiId, aziendaId), True, True)
    End Function

    Public Sub MarkSellaStarted(ByVal documentId As Integer, ByVal utentiId As Long, ByVal aziendaId As Integer)
        If documentId <= 0 OrElse utentiId <= 0 OrElse aziendaId <= 0 Then Return
        Try
            Using conn As New MySqlConnection(ConnectionText())
                conn.Open()
                Using cmd As New MySqlCommand(SellaStartSql, conn)
                    cmd.Parameters.Add("@outcome", MySqlDbType.VarChar, 255).Value = KeepStoreRemotePayment.SellaStartedOutcome
                    cmd.Parameters.Add("@id", MySqlDbType.Int32).Value = documentId
                    cmd.Parameters.Add("@uid", MySqlDbType.Int64).Value = utentiId
                    cmd.Parameters.Add("@azienda", MySqlDbType.Int32).Value = aziendaId
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("remote-payment", "MarkSellaStarted documentId=" & documentId.ToString(CultureInfo.InvariantCulture), ex, HttpContext.Current)
        End Try
    End Sub
End Module
