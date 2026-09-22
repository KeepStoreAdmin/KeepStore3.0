Option Strict On
Option Explicit On

Imports System
Imports System.Web

' Rilasciato solo dopo il commit dell'ordine WEB; non deriva da querystring.
Public NotInheritable Class PayPalWebLaunchContext
    Private Const SessionKey As String = "KeepStore:PayPal:WebLaunch"
    Public Property DocumentId As Integer
    Public Property AziendeId As Integer
    Public Property UtentiId As Long
    Public Property LoginId As Long
    Public Property CheckoutRequestId As String
    Public Property IssuedUtc As DateTime
    Public Property Channel As String
    Public Property ExpectedAmount As Decimal

    Public Shared Sub Issue(ByVal context As HttpContext, ByVal documentId As Integer,
                            ByVal owner As OrderStorefrontIdentity, ByVal checkoutRequestId As String,
                            Optional ByVal channel As String = "PAYPAL", Optional ByVal expectedAmount As Decimal = 0D)
        If context Is Nothing OrElse context.Session Is Nothing OrElse owner Is Nothing OrElse
           Not owner.IsComplete OrElse documentId <= 0 OrElse String.IsNullOrWhiteSpace(checkoutRequestId) Then
            Throw New InvalidOperationException("PayPal web launch context non valido")
        End If
        context.Session(SessionKey) = New PayPalWebLaunchContext With {
            .DocumentId = documentId, .AziendeId = owner.CompanyId,
            .UtentiId = owner.UtentiId, .LoginId = owner.LoginId,
            .CheckoutRequestId = checkoutRequestId, .IssuedUtc = DateTime.UtcNow,
            .Channel = channel, .ExpectedAmount = expectedAmount}
    End Sub

    Public Shared Function Consume(ByVal context As HttpContext, ByVal documentId As Integer,
                                   ByVal owner As OrderStorefrontIdentity,
                                   Optional ByVal channel As String = "PAYPAL",
                                   Optional ByVal suppliedAmount As Decimal = 0D) As Boolean
        If context Is Nothing OrElse context.Session Is Nothing Then Return False
        Dim launch As PayPalWebLaunchContext = TryCast(context.Session(SessionKey), PayPalWebLaunchContext)
        context.Session.Remove(SessionKey)
        Return launch IsNot Nothing AndAlso owner IsNot Nothing AndAlso owner.IsComplete AndAlso
               launch.DocumentId = documentId AndAlso launch.AziendeId = owner.CompanyId AndAlso
               launch.UtentiId = owner.UtentiId AndAlso launch.LoginId = owner.LoginId AndAlso
               String.Equals(launch.Channel, channel, StringComparison.Ordinal) AndAlso
               (launch.ExpectedAmount = 0D OrElse launch.ExpectedAmount = suppliedAmount) AndAlso
               Not String.IsNullOrWhiteSpace(launch.CheckoutRequestId) AndAlso
               launch.IssuedUtc <= DateTime.UtcNow AndAlso launch.IssuedUtc > DateTime.UtcNow.AddMinutes(-5)
    End Function
End Class
