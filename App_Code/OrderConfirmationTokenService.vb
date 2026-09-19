Imports System
Imports System.Globalization
Imports System.Text
Imports System.Web.Security

Public NotInheritable Class OrderConfirmationTokenService
    Private Const TokenPurpose As String = "KeepStore.OrderConfirmation.Receipt.V1"
    Private Shared ReadOnly MaxTokenAge As TimeSpan = TimeSpan.FromDays(7)

    Private Sub New()
    End Sub

    Public Shared Function CreateToken(ByVal requestId As String,
                                       ByVal identity As OrderStorefrontIdentity) As String
        Dim normalizedRequestId As String = String.Empty
        Dim databaseScope As String = String.Empty
        If identity Is Nothing OrElse Not identity.IsComplete OrElse
           Not OrderDurableIdempotencyService.TryNormalizePayloadFingerprint(identity.DatabaseScopeKey, databaseScope) OrElse
           Not OrderDurableIdempotencyService.TryNormalizeRequestId(requestId, normalizedRequestId) Then
            Throw New InvalidOperationException("Completed order identity is not valid.")
        End If

        Dim clearBytes() As Byte = Nothing
        Dim protectedBytes() As Byte = Nothing
        Try
            Dim payload As String = "v2|" & normalizedRequestId & "|" & databaseScope & "|" &
                identity.CompanyId.ToString(CultureInfo.InvariantCulture) & "|" &
                identity.LoginId.ToString(CultureInfo.InvariantCulture) & "|" &
                DateTime.UtcNow.Ticks.ToString(CultureInfo.InvariantCulture)
            clearBytes = Encoding.UTF8.GetBytes(payload)
            protectedBytes = MachineKey.Protect(clearBytes, TokenPurpose)
            If protectedBytes Is Nothing OrElse protectedBytes.Length = 0 Then
                Throw New InvalidOperationException("Order confirmation token protection failed.")
            End If

            Dim b64 As String = Convert.ToBase64String(protectedBytes)
            Return b64.Replace("+"c, "-"c).Replace("/"c, "_"c).TrimEnd("="c)
        Finally
            If clearBytes IsNot Nothing Then Array.Clear(clearBytes, 0, clearBytes.Length)
            If protectedBytes IsNot Nothing Then Array.Clear(protectedBytes, 0, protectedBytes.Length)
        End Try
    End Function

    Public Shared Function TryValidate(ByVal token As String,
                                       ByVal identity As OrderStorefrontIdentity,
                                       ByRef requestId As String) As Boolean
        requestId = String.Empty
        If identity Is Nothing OrElse Not identity.IsComplete OrElse
           String.IsNullOrWhiteSpace(token) OrElse token.Length > 1024 Then Return False

        Dim protectedBytes() As Byte = Nothing
        Dim clearBytes() As Byte = Nothing
        Try
            Dim encoded As String = token.Trim().Replace("-"c, "+"c).Replace("_"c, "/"c)
            Select Case encoded.Length Mod 4
                Case 0
                Case 2
                    encoded &= "=="
                Case 3
                    encoded &= "="
                Case Else
                    Return False
            End Select

            protectedBytes = Convert.FromBase64String(encoded)
            clearBytes = MachineKey.Unprotect(protectedBytes, TokenPurpose)
            If clearBytes Is Nothing OrElse clearBytes.Length = 0 Then Return False

            Dim parts() As String = Encoding.UTF8.GetString(clearBytes).Split("|"c)
            If parts.Length <> 6 OrElse Not String.Equals(parts(0), "v2", StringComparison.Ordinal) Then Return False

            Dim normalized As String = String.Empty
            If Not OrderDurableIdempotencyService.TryNormalizeRequestId(parts(1), normalized) Then Return False

            Dim databaseScope As String = String.Empty
            If Not OrderDurableIdempotencyService.TryNormalizePayloadFingerprint(parts(2), databaseScope) OrElse
               Not String.Equals(databaseScope, identity.DatabaseScopeKey, StringComparison.Ordinal) Then Return False

            Dim tokenCompanyId As Integer = 0
            If Not Integer.TryParse(parts(3), NumberStyles.None, CultureInfo.InvariantCulture, tokenCompanyId) OrElse
               tokenCompanyId <> identity.CompanyId Then Return False

            Dim tokenLoginId As Long = 0
            If Not Long.TryParse(parts(4), NumberStyles.None, CultureInfo.InvariantCulture, tokenLoginId) OrElse
               tokenLoginId <> identity.LoginId Then Return False

            Dim issuedTicks As Long = 0
            If Not Long.TryParse(parts(5), NumberStyles.None, CultureInfo.InvariantCulture, issuedTicks) Then Return False
            Dim issuedUtc As New DateTime(issuedTicks, DateTimeKind.Utc)
            Dim age As TimeSpan = DateTime.UtcNow.Subtract(issuedUtc)
            If age < TimeSpan.FromMinutes(-1) OrElse age > MaxTokenAge Then Return False

            requestId = normalized
            Return True
        Catch
            Return False
        Finally
            If protectedBytes IsNot Nothing Then Array.Clear(protectedBytes, 0, protectedBytes.Length)
            If clearBytes IsNot Nothing Then Array.Clear(clearBytes, 0, clearBytes.Length)
        End Try
    End Function
End Class
