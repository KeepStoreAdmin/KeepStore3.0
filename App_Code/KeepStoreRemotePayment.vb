Option Strict On
Option Explicit On

Imports System

' ORDER-REMOTE-PAYMENT-1A. Regole PURE (nessun accesso a database o sessione) con cui il sito decide se un ordine non pagato puo mostrare "Paga adesso":
' ordini creati dal gestionale per un cliente registrato, oppure ordini del sito il cui metodo di pagamento il PO ha cambiato nel gestionale in PayPal o carta Banca Sella.
' I fatti arrivano da KeepStoreRemotePaymentStore (un'unica query per documento, con owner e azienda); qui si decide soltanto.
Public NotInheritable Class RemotePaymentFacts
    ' OrigineOrdine del documento ("" quando la colonna e NULL: ordini del gestionale e ordini del sito precedenti alla colonna).
    Public Property Origin As String = ""
    ' documenti.Ordine_Web: 1 per ogni ordine creato dal sito, anche prima della colonna OrigineOrdine.
    Public Property OrdineWeb As Integer
    ' DateTime.MinValue = data mancante (NULL): mai ammessa.
    Public Property DocumentDate As DateTime = DateTime.MinValue
    ' Data e ora del DATABASE (CURDATE, NOW): un solo orologio, nessun fuso del web.
    Public Property Today As DateTime = DateTime.MinValue
    Public Property DbNow As DateTime = DateTime.MinValue
    Public Property Paid As Integer
    Public Property DocumentState As Integer
    Public Property PaymentState As Integer
    Public Property PaymentStateDate As DateTime = DateTime.MinValue
    ' Ultimo esito scritto sul documento (UltimoEsitoPagamentoWeb): l'avvio di Banca Sella lo imposta a SellaStartedOutcome.
    Public Property LastOutcome As String = ""
    Public Property OnlineMethod As Integer
    Public Property AllowLater As Integer
    Public Property Total As Decimal
    Public Property ValidOrderType As Boolean
    Public Property SellaAuthorized As Boolean
    ' Esiste almeno un tentativo PayPal per il documento.
    Public Property PayPalAny As Boolean
    ' Esiste un tentativo PayPal NON concluso male (aperto o completato) su un metodo diverso dall'attuale, o l'attuale e Sella.
    Public Property PayPalOpenOther As Boolean
    ' L'ordine e legato a Amazon o eBay.
    Public Property Marketplace As Boolean
End Class

Public Module KeepStoreRemotePayment
    ' Gli ordini del gestionale (e quelli del sito) restano pagabili da remoto per questo numero di giorni dalla data documento.
    Public Const WindowDays As Integer = 90
    ' Un pagamento Banca Sella appena avviato non si puo scavalcare con PayPal per questi minuti.
    Public Const SellaStartGuardMinutes As Integer = 60
    ' Testo (solo ASCII) che l'avvio di Banca Sella scrive come ultimo esito del documento, con la data: non cambia lo stato di pagamento.
    Public Const SellaStartedOutcome As String = "Pagamento con carta avviato"

    Public Function InWindow(ByVal facts As RemotePaymentFacts) As Boolean
        If facts Is Nothing OrElse facts.DocumentDate = DateTime.MinValue OrElse facts.Today = DateTime.MinValue Then Return False
        Dim days As Double = (facts.Today.Date - facts.DocumentDate.Date).TotalDays
        Return days >= 0.0 AndAlso days <= CDbl(WindowDays)
    End Function

    ' "INTERNO" = il documento puo seguire le regole del pagamento successivo; "" = chiuso.
    Public Function OriginClass(ByVal facts As RemotePaymentFacts) As String
        If facts Is Nothing Then Return ""
        Dim origin As String = If(facts.Origin, String.Empty).Trim().ToUpperInvariant()
        If origin = "INTERNO" Then Return "INTERNO"
        If origin = String.Empty AndAlso facts.OrdineWeb = 0 Then
            ' Ordine del gestionale: mai Amazon/eBay, data valida e recente.
            If facts.Marketplace OrElse Not InWindow(facts) Then Return ""
            Return "INTERNO"
        End If
        If origin = "WEB" OrElse (origin = String.Empty AndAlso facts.OrdineWeb <> 0) Then
            ' Ordine del sito: solo se un pagamento online non e MAI partito (nessun tentativo PayPal, stato web 0), cioe il PO ha cambiato il metodo.
            If facts.PaymentState <> 0 OrElse facts.PayPalAny OrElse Not InWindow(facts) Then Return ""
            Return "INTERNO"
        End If
        Return ""
    End Function

    ' Un pagamento Banca Sella potrebbe essere in corso: ultimo esito = avvio carta, senza tentativi PayPal, metodo attuale PayPal, avvio recente o data ignota.
    Public Function SellaMayBeInFlight(ByVal facts As RemotePaymentFacts) As Boolean
        If facts Is Nothing Then Return True
        If facts.OnlineMethod <> 2 OrElse facts.PayPalAny Then Return False
        If Not String.Equals(If(facts.LastOutcome, String.Empty).Trim(), SellaStartedOutcome, StringComparison.Ordinal) Then Return False
        If facts.PaymentStateDate = DateTime.MinValue OrElse facts.DbNow = DateTime.MinValue Then Return True
        Dim minutes As Double = (facts.DbNow - facts.PaymentStateDate).TotalMinutes
        Return minutes < CDbl(SellaStartGuardMinutes)
    End Function
End Module
