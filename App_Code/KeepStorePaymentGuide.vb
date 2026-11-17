Option Strict On
Option Explicit On

Imports System

' PAYPAL-FAILED-PAYMENT-GUIDE-1A. Dice quale guida visuale mostrare nel carrello quando il pay-first rimanda il cliente al carrello con un messaggio.
' Il testo arriva dalla sessione scritta dal server; il confronto e ESATTO con le costanti del servizio (nessun testo copiato qui) e non decide mai un pagamento.
' Resubmit e Changed restano fuori di proposito: il loro avviso resta quello di sempre.
Public Enum PaymentGuideKind
    None = 0
    Retry = 1
    Wait = 2
    Contact = 3
End Enum

Public NotInheritable Class KeepStorePaymentGuide
    Private Sub New()
    End Sub

    Public Shared Function Resolve(ByVal message As String) As PaymentGuideKind
        If message Is Nothing Then Return PaymentGuideKind.None
        Dim text As String = message.Trim()
        If text.Length = 0 Then Return PaymentGuideKind.None
        If String.Equals(text, PayPalPayFirstService.MsgNotStarted, StringComparison.Ordinal) Then Return PaymentGuideKind.Retry
        If String.Equals(text, PayPalPayFirstService.MsgCanceled, StringComparison.Ordinal) Then Return PaymentGuideKind.Retry
        If String.Equals(text, PayPalPayFirstService.MsgExpired, StringComparison.Ordinal) Then Return PaymentGuideKind.Retry
        If String.Equals(text, PayPalPayFirstService.MsgBusy, StringComparison.Ordinal) Then Return PaymentGuideKind.Wait
        If String.Equals(text, PayPalPayFirstService.MsgManual, StringComparison.Ordinal) Then Return PaymentGuideKind.Contact
        Return PaymentGuideKind.None
    End Function
End Class
