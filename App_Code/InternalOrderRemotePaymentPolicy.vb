Option Strict On
Option Explicit On

Imports System

' La provenienza appartiene al documento, non alla transazione PayPal.
' UNKNOWN e gli altri canali falliscono chiusi per il pagamento successivo.
Public Module InternalOrderRemotePaymentPolicy
    Public Function CanPayNow(ByVal origin As String,
                              ByVal ownerMatches As Boolean,
                              ByVal tenantMatches As Boolean,
                              ByVal validOrderType As Boolean,
                              ByVal paid As Integer,
                              ByVal documentState As Integer,
                              ByVal paymentState As Integer,
                              ByVal onlineMethod As Integer,
                              ByVal allowLater As Integer,
                              ByVal hasGatewayAuthorization As Boolean,
                              ByVal total As Decimal) As Boolean
        Return String.Equals(If(origin, String.Empty).Trim(), "INTERNO", StringComparison.OrdinalIgnoreCase) AndAlso
               ownerMatches AndAlso tenantMatches AndAlso validOrderType AndAlso paid = 0 AndAlso
               documentState <> 0 AndAlso documentState <> 3 AndAlso total > 0D AndAlso
               (onlineMethod = 2 OrElse onlineMethod = 3) AndAlso allowLater = 1 AndAlso
               (paymentState = 0 OrElse paymentState = 1 OrElse paymentState = 3 OrElse paymentState = 4 OrElse paymentState = 5) AndAlso
               Not hasGatewayAuthorization
    End Function

    ' ORDER-REMOTE-PAYMENT-1A: decisione completa sui FATTI del documento (origine, ordine del sito, data, tentativi PayPal, avvio Sella). I chiamanti usano
    ' questa; la firma sopra resta la regola base dei gate comuni e non decide piu l'origine da sola.
    Public Function CanPayNow(ByVal facts As RemotePaymentFacts,
                              ByVal ownerMatches As Boolean,
                              ByVal tenantMatches As Boolean) As Boolean
        If facts Is Nothing Then Return False
        Dim originClass As String = KeepStoreRemotePayment.OriginClass(facts)
        If originClass.Length = 0 Then Return False
        If Not CanPayNow(originClass, ownerMatches, tenantMatches, facts.ValidOrderType, facts.Paid, facts.DocumentState,
                         facts.PaymentState, facts.OnlineMethod, facts.AllowLater, facts.SellaAuthorized, facts.Total) Then Return False
        ' Mai due gateway insieme: un PayPal aperto o completato su un altro metodo (o con metodo attuale Sella) blocca il pagamento.
        If facts.PayPalOpenOther Then Return False
        If KeepStoreRemotePayment.SellaMayBeInFlight(facts) Then Return False
        Return True
    End Function
End Module
