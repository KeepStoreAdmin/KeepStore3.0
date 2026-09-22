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
End Module
