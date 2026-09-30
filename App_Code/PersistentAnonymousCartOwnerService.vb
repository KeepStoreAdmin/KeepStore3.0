Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

Public Enum PersistentAnonymousCartOwnerState
    NO_COOKIE
    MALFORMED_COOKIE
    NOT_FOUND
    EXPIRED
    CONSUMED
    REVOKED
    ACTIVE
    TECHNICAL_ERROR
End Enum

Public NotInheritable Class PersistentAnonymousCartOwnerResolution
    Private ReadOnly _state As PersistentAnonymousCartOwnerState
    Private ReadOnly _ownerToken As String

    Public ReadOnly Property State As PersistentAnonymousCartOwnerState
        Get
            Return _state
        End Get
    End Property

    Public ReadOnly Property OwnerToken As String
        Get
            Return _ownerToken
        End Get
    End Property

    Public Sub New(ByVal state As PersistentAnonymousCartOwnerState,
                   Optional ByVal ownerToken As String = Nothing)
        _state = state
        _ownerToken = If(state = PersistentAnonymousCartOwnerState.ACTIVE, ownerToken, Nothing)
    End Sub
End Class

Public NotInheritable Class PersistentAnonymousCartOwnerService
    Public Const CookieName As String = "__Host-KeepStoreCart"
    Private Const CookiePrefix As String = "v2."
    Private Const OwnerPrefix As String = "ksc2_"
    Private Const DomainTag As String = "KeepStoreCartOwner/v2"

    Private Sub New()
    End Sub

    Public Shared Function Resolve(ByVal context As HttpContext,
                                   ByVal databaseScope As String,
                                   ByVal companyId As Integer) As PersistentAnonymousCartOwnerResolution
        If context Is Nothing OrElse context.Request Is Nothing Then
            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.TECHNICAL_ERROR)
        End If
        Dim cookie As HttpCookie = context.Request.Cookies(CookieName)
        If cookie Is Nothing Then
            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.NO_COOKIE)
        End If
        Dim value As String = If(cookie.Value, String.Empty)
        Dim parsedSecret As Byte() = Nothing
        If Not TryDecodeCookie(value, parsedSecret) Then
            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.MALFORMED_COOKIE)
        End If
        Array.Clear(parsedSecret, 0, parsedSecret.Length)
        Try
            Dim setting As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            Dim connectionString As String = If(setting Is Nothing, Nothing, setting.ConnectionString)
            Return ResolveCookieValue(value, databaseScope, companyId, connectionString)
        Catch
            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.TECHNICAL_ERROR)
        End Try
    End Function

    ' Exposed for synthetic scratch-DB tests; never pass this value to logging or Session.
    Public Shared Function ResolveCookieValue(ByVal cookieValue As String,
                                              ByVal databaseScope As String,
                                              ByVal companyId As Integer,
                                              ByVal connectionString As String) As PersistentAnonymousCartOwnerResolution
        If cookieValue Is Nothing Then
            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.NO_COOKIE)
        End If

        Dim secret As Byte() = Nothing
        If Not TryDecodeCookie(cookieValue, secret) Then
            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.MALFORMED_COOKIE)
        End If

        Try
            If String.IsNullOrWhiteSpace(databaseScope) OrElse companyId <= 0 OrElse
               String.IsNullOrWhiteSpace(connectionString) Then
                Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.TECHNICAL_ERROR)
            End If

            Dim ownerToken As String = DeriveOwnerToken(databaseScope, companyId, secret)
            Return LookupRegistry(connectionString, companyId, ownerToken)
        Catch
            ' Never expose database, connection, cookie or owner details to the caller.
            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.TECHNICAL_ERROR)
        Finally
            If secret IsNot Nothing Then Array.Clear(secret, 0, secret.Length)
        End Try
    End Function

    Public Shared Function DeriveOwnerToken(ByVal databaseScope As String,
                                            ByVal companyId As Integer,
                                            ByVal rawSecret As Byte()) As String
        If String.IsNullOrWhiteSpace(databaseScope) OrElse companyId <= 0 OrElse
           rawSecret Is Nothing OrElse rawSecret.Length <> 32 Then
            Throw New ArgumentException("Invalid persistent cart owner input")
        End If

        ' Stable, unambiguous v2 serialization (all lengths/integers UInt32 big-endian):
        ' UTF8("KeepStoreCartOwner/v2") | 0x00 | len(databaseScope UTF8) |
        ' UTF8(databaseScope.Trim().ToLowerInvariant()) | companyId | len(secret)=32 | secret.
        Dim scopeBytes As Byte() = Encoding.UTF8.GetBytes(databaseScope.Trim().ToLowerInvariant())
        Dim tagBytes As Byte() = Encoding.UTF8.GetBytes(DomainTag)
        Dim serialized(tagBytes.Length + 1 + 4 + scopeBytes.Length + 4 + 4 + rawSecret.Length - 1) As Byte
        Dim offset As Integer = 0
        Buffer.BlockCopy(tagBytes, 0, serialized, offset, tagBytes.Length)
        offset += tagBytes.Length + 1
        WriteUInt32(serialized, offset, CUInt(scopeBytes.Length))
        offset += 4
        Buffer.BlockCopy(scopeBytes, 0, serialized, offset, scopeBytes.Length)
        offset += scopeBytes.Length
        WriteUInt32(serialized, offset, CUInt(companyId))
        offset += 4
        WriteUInt32(serialized, offset, CUInt(rawSecret.Length))
        offset += 4
        Buffer.BlockCopy(rawSecret, 0, serialized, offset, rawSecret.Length)

        Try
            Using hash As SHA256 = SHA256.Create()
                Return OwnerPrefix & ToBase64Url(hash.ComputeHash(serialized))
            End Using
        Finally
            Array.Clear(serialized, 0, serialized.Length)
        End Try
    End Function

    Private Shared Function LookupRegistry(ByVal connectionString As String,
                                           ByVal companyId As Integer,
                                           ByVal ownerToken As String) As PersistentAnonymousCartOwnerResolution
        ' OwnerToken uses the canonical utf8mb4_0900_bin column collation, so equality
        ' remains case-sensitive. The unique (AziendeId, OwnerToken) index scopes lookup.
        Const sql As String = "SELECT `Status`, `ConsumedUtc`, `RevokedUtc`, " &
                              "(`ExpiresUtc` > UTC_TIMESTAMP(6)) AS `NotExpired` " &
                              "FROM `carrello_anonimo_persistenza` " &
                              "WHERE `AziendeId` = @companyId AND `OwnerToken` = @ownerToken LIMIT 2"
        Using connection As New MySqlConnection(connectionString)
            connection.Open()
            Using command As New MySqlCommand(sql, connection)
                command.Parameters.Add("@companyId", MySqlDbType.Int32).Value = companyId
                command.Parameters.Add("@ownerToken", MySqlDbType.VarChar, 50).Value = ownerToken
                Using reader As MySqlDataReader = command.ExecuteReader()
                    If Not reader.Read() Then
                        Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.NOT_FOUND)
                    End If
                    Dim status As String = reader.GetString(0)
                    Dim consumed As Boolean = Not reader.IsDBNull(1)
                    Dim revoked As Boolean = Not reader.IsDBNull(2)
                    Dim notExpired As Boolean = Not reader.IsDBNull(3) AndAlso reader.GetBoolean(3)
                    If reader.Read() Then
                        Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.TECHNICAL_ERROR)
                    End If
                    Select Case status
                        Case "ACTIVE"
                            If consumed OrElse revoked Then
                                Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.TECHNICAL_ERROR)
                            End If
                            If Not notExpired Then
                                Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.EXPIRED)
                            End If
                            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.ACTIVE, ownerToken)
                        Case "CONSUMED"
                            Return New PersistentAnonymousCartOwnerResolution(If(consumed AndAlso Not revoked,
                                PersistentAnonymousCartOwnerState.CONSUMED, PersistentAnonymousCartOwnerState.TECHNICAL_ERROR))
                        Case "REVOKED"
                            Return New PersistentAnonymousCartOwnerResolution(If(revoked AndAlso Not consumed,
                                PersistentAnonymousCartOwnerState.REVOKED, PersistentAnonymousCartOwnerState.TECHNICAL_ERROR))
                        Case Else
                            Return New PersistentAnonymousCartOwnerResolution(PersistentAnonymousCartOwnerState.TECHNICAL_ERROR)
                    End Select
                End Using
            End Using
        End Using
    End Function

    Friend Shared Function TryDecodeCookie(ByVal value As String, ByRef secret As Byte()) As Boolean
        If value Is Nothing OrElse value.Length <> 46 OrElse
           Not value.StartsWith(CookiePrefix, StringComparison.Ordinal) Then Return False
        Dim payload As String = value.Substring(CookiePrefix.Length)
        For Each character As Char In payload
            If Not ((character >= "A"c AndAlso character <= "Z"c) OrElse
                    (character >= "a"c AndAlso character <= "z"c) OrElse
                    (character >= "0"c AndAlso character <= "9"c) OrElse
                    character = "-"c OrElse character = "_"c) Then Return False
        Next
        Try
            Dim decoded As Byte() = Convert.FromBase64String(payload.Replace("-", "+").Replace("_", "/") & "=")
            If decoded.Length <> 32 OrElse Not String.Equals(ToBase64Url(decoded), payload, StringComparison.Ordinal) Then
                Array.Clear(decoded, 0, decoded.Length)
                Return False
            End If
            secret = decoded
            Return True
        Catch
            Return False
        End Try
    End Function

    Private Shared Function ToBase64Url(ByVal value As Byte()) As String
        Return Convert.ToBase64String(value).TrimEnd("="c).Replace("+", "-").Replace("/", "_")
    End Function

    Private Shared Sub WriteUInt32(ByVal destination As Byte(), ByVal offset As Integer, ByVal value As UInteger)
        destination(offset) = CByte((value >> 24) And &HFFUI)
        destination(offset + 1) = CByte((value >> 16) And &HFFUI)
        destination(offset + 2) = CByte((value >> 8) And &HFFUI)
        destination(offset + 3) = CByte(value And &HFFUI)
    End Sub
End Class
