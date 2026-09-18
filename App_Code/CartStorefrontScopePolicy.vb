Option Strict On
Option Explicit On

Imports System
Imports System.Globalization
Imports System.Security.Cryptography
Imports System.Text

Public NotInheritable Class CartStorefrontScopePolicy
    Public Const AnonymousOwnerPrefix As String = "ksc1_"
    Public Const AnonymousOwnerMaxLength As Integer = 50

    Private Sub New()
    End Sub

    Public Shared Function BuildAnonymousOwnerToken(ByVal databaseScopeKey As String,
                                                    ByVal companyId As Integer,
                                                    ByVal sessionId As String) As String
        Dim databaseScope As String = Convert.ToString(databaseScopeKey).Trim().ToLowerInvariant()
        Dim rawSessionId As String = Convert.ToString(sessionId).Trim()
        If String.IsNullOrEmpty(databaseScope) OrElse companyId <= 0 OrElse String.IsNullOrEmpty(rawSessionId) Then
            Return String.Empty
        End If

        Dim canonical As String = databaseScope & "|company:" &
                                  companyId.ToString(CultureInfo.InvariantCulture) & "|session:" & rawSessionId
        Using digest As SHA256 = SHA256.Create()
            Dim encoded As String = Convert.ToBase64String(digest.ComputeHash(Encoding.UTF8.GetBytes(canonical)))
            encoded = encoded.TrimEnd("="c).Replace("+", "-").Replace("/", "_")
            Dim token As String = AnonymousOwnerPrefix & encoded
            If token.Length > AnonymousOwnerMaxLength Then Return String.Empty
            Return token
        End Using
    End Function

    Public Shared Function BuildOwnerScopeKey(ByVal databaseScopeKey As String,
                                              ByVal companyId As Integer,
                                              ByVal loginId As Integer,
                                              ByVal anonymousOwnerToken As String) As String
        Dim databaseScope As String = Convert.ToString(databaseScopeKey).Trim().ToLowerInvariant()
        If String.IsNullOrEmpty(databaseScope) OrElse companyId <= 0 Then Return String.Empty

        Dim owner As String
        If loginId > 0 Then
            owner = "login:" & loginId.ToString(CultureInfo.InvariantCulture)
        Else
            Dim token As String = Convert.ToString(anonymousOwnerToken).Trim()
            If Not IsAnonymousOwnerToken(token) Then Return String.Empty
            owner = "anonymous:" & token
        End If
        Return databaseScope & "|company:" & companyId.ToString(CultureInfo.InvariantCulture) & "|" & owner
    End Function

    Public Shared Function IsAuthenticatedScopeValid(ByVal companyId As Integer,
                                                     ByVal authenticatedCompanyId As Integer,
                                                     ByVal loginId As Integer) As Boolean
        Return companyId > 0 AndAlso loginId > 0 AndAlso authenticatedCompanyId = companyId
    End Function

    Public Shared Function IsAnonymousOwnerToken(ByVal value As String) As Boolean
        Dim token As String = Convert.ToString(value)
        If token.Length <> AnonymousOwnerPrefix.Length + 43 OrElse
           Not token.StartsWith(AnonymousOwnerPrefix, StringComparison.Ordinal) Then Return False

        For index As Integer = AnonymousOwnerPrefix.Length To token.Length - 1
            Dim character As Char = token(index)
            If Not ((character >= "A"c AndAlso character <= "Z"c) OrElse
                    (character >= "a"c AndAlso character <= "z"c) OrElse
                    (character >= "0"c AndAlso character <= "9"c) OrElse
                    character = "-"c OrElse character = "_"c) Then Return False
        Next
        Return True
    End Function
End Class
