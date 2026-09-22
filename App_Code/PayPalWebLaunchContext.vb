Option Strict On
Option Explicit On

Imports System
Imports System.Security.Cryptography
Imports System.Text
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
    Public Property AttemptNo As Integer
    Public Property CreateRequestId As String
    Public Property PayloadFingerprint As String

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
        Dim launch As PayPalWebLaunchContext = Find(context, documentId, owner, channel, suppliedAmount)
        If launch Is Nothing Then Return False
        context.Session.Remove(SessionKey)
        Return True
    End Function

    ' Il checkout PayPal conserva il diritto soltanto per recuperare lo stesso
    ' tentativo tecnico entro cinque minuti; non e un Paga ora permanente.
    Public Shared Function BeginPayPal(ByVal context As HttpContext, ByVal documentId As Integer,
                                       ByVal owner As OrderStorefrontIdentity) As Boolean
        Return Find(context, documentId, owner, "PAYPAL", 0D) IsNot Nothing
    End Function

    Public Shared Function BindPayPalAttempt(ByVal context As HttpContext, ByVal documentId As Integer,
                                             ByVal owner As OrderStorefrontIdentity,
                                             ByVal attemptNo As Integer, ByVal requestId As String,
                                             ByVal exactPayload As String) As Boolean
        Dim launch As PayPalWebLaunchContext = Find(context, documentId, owner, "PAYPAL", 0D)
        If launch Is Nothing OrElse attemptNo <> 1 OrElse String.IsNullOrWhiteSpace(requestId) OrElse
           String.IsNullOrWhiteSpace(exactPayload) Then Return False
        Dim fingerprint As String
        Using sha As SHA256 = SHA256.Create()
            fingerprint = Convert.ToBase64String(sha.ComputeHash(Encoding.UTF8.GetBytes(exactPayload)))
        End Using
        If launch.AttemptNo = 0 Then
            launch.AttemptNo = attemptNo
            launch.CreateRequestId = requestId
            launch.PayloadFingerprint = fingerprint
            Return True
        End If
        Return launch.AttemptNo = attemptNo AndAlso
               String.Equals(launch.CreateRequestId, requestId, StringComparison.Ordinal) AndAlso
               String.Equals(launch.PayloadFingerprint, fingerprint, StringComparison.Ordinal)
    End Function

    Public Shared Sub FinishPayPal(ByVal context As HttpContext, ByVal documentId As Integer,
                                   ByVal owner As OrderStorefrontIdentity)
        If Find(context, documentId, owner, "PAYPAL", 0D) IsNot Nothing Then context.Session.Remove(SessionKey)
    End Sub

    Private Shared Function Find(ByVal context As HttpContext, ByVal documentId As Integer,
                                 ByVal owner As OrderStorefrontIdentity, ByVal channel As String,
                                 ByVal suppliedAmount As Decimal) As PayPalWebLaunchContext
        If context Is Nothing OrElse context.Session Is Nothing Then Return Nothing
        Dim launch As PayPalWebLaunchContext = TryCast(context.Session(SessionKey), PayPalWebLaunchContext)
        If launch Is Nothing Then Return Nothing
        Dim nowUtc As DateTime = DateTime.UtcNow
        If launch.IssuedUtc > nowUtc OrElse launch.IssuedUtc <= nowUtc.AddMinutes(-5) Then
            context.Session.Remove(SessionKey)
            Return Nothing
        End If
        If owner IsNot Nothing AndAlso owner.IsComplete AndAlso
               launch.DocumentId = documentId AndAlso launch.AziendeId = owner.CompanyId AndAlso
               launch.UtentiId = owner.UtentiId AndAlso launch.LoginId = owner.LoginId AndAlso
               String.Equals(launch.Channel, channel, StringComparison.Ordinal) AndAlso
               (launch.ExpectedAmount = 0D OrElse launch.ExpectedAmount = suppliedAmount) AndAlso
               Not String.IsNullOrWhiteSpace(launch.CheckoutRequestId) Then Return launch
        Return Nothing
    End Function
End Class
