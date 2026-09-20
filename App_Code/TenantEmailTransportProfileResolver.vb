Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Net
Imports System.Security.Cryptography
Imports System.Text
Imports System.Text.RegularExpressions
Imports MySql.Data.MySqlClient
Imports MimeKit

Public NotInheritable Class EmailDatabaseIdentityProvider
    Implements IEmailDatabaseIdentityProvider

    Public Function GetIdentity(ByVal connectionString As String) As String Implements IEmailDatabaseIdentityProvider.GetIdentity
        If String.IsNullOrWhiteSpace(connectionString) Then Return String.Empty

        Try
            Dim builder As New MySqlConnectionStringBuilder(connectionString)
            Dim server As String = Convert.ToString(builder.Server).Trim().ToLowerInvariant()
            Dim databaseName As String = Convert.ToString(builder.Database).Trim().ToLowerInvariant()
            If server = String.Empty OrElse databaseName = String.Empty Then Return String.Empty

            Dim material As String = server & "|" & builder.Port.ToString(CultureInfo.InvariantCulture) & "|" & databaseName
            Using digest As SHA256 = SHA256.Create()
                Dim hash As Byte() = digest.ComputeHash(Encoding.UTF8.GetBytes(material))
                Dim encoded As New StringBuilder(hash.Length * 2)
                For Each value As Byte In hash
                    encoded.Append(value.ToString("x2", CultureInfo.InvariantCulture))
                Next
                Return encoded.ToString()
            End Using
        Catch
            Return String.Empty
        End Try
    End Function
End Class

Public NotInheritable Class MySqlEmailTransportProfileSource
    Implements IEmailTransportProfileSource

    Public Function Load(ByVal connectionString As String,
                         ByVal aziendaId As Integer,
                         ByVal purpose As String) As EmailTransportProfileSourceResult Implements IEmailTransportProfileSource.Load
        Dim result As New EmailTransportProfileSourceResult()
        Try
            Using connection As New MySqlConnection(connectionString)
                connection.Open()

                Using schemaCommand As New MySqlCommand("SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='aziende_email_transport'", connection)
                    result.SchemaAvailable = Convert.ToInt32(schemaCommand.ExecuteScalar(), CultureInfo.InvariantCulture) = 1
                End Using

                If Not result.SchemaAvailable Then Return result

                Const sql As String = "SELECT EmailTransportId,AziendeId,Purpose,ProviderKind,Host,Port,SecurityMode,AuthenticationMode,Username,CredentialReference,FromAddress,FromDisplayName,ReplyToAddress,EnvelopeFromAddress,TimeoutSeconds,Enabled,VerificationStatus,LastVerifiedAtUtc,LastVerificationCode FROM aziende_email_transport WHERE AziendeId=@aziendaId AND Purpose=@purpose ORDER BY EmailTransportId LIMIT 3"
                Using command As New MySqlCommand(sql, connection)
                    command.Parameters.Add("@aziendaId", MySqlDbType.Int32).Value = aziendaId
                    command.Parameters.Add("@purpose", MySqlDbType.VarChar, 24).Value = purpose
                    Using reader As MySqlDataReader = command.ExecuteReader()
                        While reader.Read()
                            result.Records.Add(ReadRecord(reader))
                        End While
                    End Using
                End Using
            End Using
        Catch ex As MySqlException
            If ex.Number = 1146 Then
                result.SchemaAvailable = False
                result.TechnicalFailure = False
            Else
                result.TechnicalFailure = True
            End If
        Catch
            result.TechnicalFailure = True
        End Try
        Return result
    End Function

    Private Shared Function ReadRecord(ByVal reader As IDataRecord) As TenantEmailTransportProfileRecord
        Dim record As New TenantEmailTransportProfileRecord()
        record.EmailTransportId = Convert.ToInt64(reader("EmailTransportId"), CultureInfo.InvariantCulture)
        record.AziendaId = Convert.ToInt32(reader("AziendeId"), CultureInfo.InvariantCulture)
        record.Purpose = ReadText(reader, "Purpose")
        record.ProviderKind = ReadText(reader, "ProviderKind")
        record.Host = ReadText(reader, "Host")
        record.Port = Convert.ToInt32(reader("Port"), CultureInfo.InvariantCulture)
        record.SecurityMode = ReadText(reader, "SecurityMode")
        record.AuthenticationMode = ReadText(reader, "AuthenticationMode")
        record.Username = ReadText(reader, "Username")
        record.CredentialReference = ReadText(reader, "CredentialReference")
        record.FromAddress = ReadText(reader, "FromAddress")
        record.FromDisplayName = ReadText(reader, "FromDisplayName")
        record.ReplyToAddress = ReadText(reader, "ReplyToAddress")
        record.EnvelopeFromAddress = ReadText(reader, "EnvelopeFromAddress")
        record.TimeoutSeconds = Convert.ToInt32(reader("TimeoutSeconds"), CultureInfo.InvariantCulture)
        record.Enabled = Convert.ToInt32(reader("Enabled"), CultureInfo.InvariantCulture) = 1
        record.VerificationStatus = ReadText(reader, "VerificationStatus")
        If Not Convert.IsDBNull(reader("LastVerifiedAtUtc")) Then
            record.LastVerifiedAtUtc = Convert.ToDateTime(reader("LastVerifiedAtUtc"), CultureInfo.InvariantCulture)
        End If
        record.LastVerificationCode = ReadText(reader, "LastVerificationCode")
        Return record
    End Function

    Private Shared Function ReadText(ByVal reader As IDataRecord, ByVal name As String) As String
        Dim value As Object = reader(name)
        If value Is Nothing OrElse Convert.IsDBNull(value) Then Return String.Empty
        Return Convert.ToString(value, CultureInfo.InvariantCulture).Trim()
    End Function
End Class

Public NotInheritable Class TenantEmailTransportProfileResolver
    Implements ITenantEmailTransportProfileResolver

    Private Shared ReadOnly AllowedProviders As New HashSet(Of String)(StringComparer.Ordinal) From {
        "CUSTOM_SMTP", "ARUBA", "GOOGLE", "MICROSOFT", "LIBERO", "VIRGILIO"
    }

    Private ReadOnly _source As IEmailTransportProfileSource
    Private ReadOnly _identityProvider As IEmailDatabaseIdentityProvider

    Public Sub New()
        Me.New(New MySqlEmailTransportProfileSource(), New EmailDatabaseIdentityProvider())
    End Sub

    Public Sub New(ByVal source As IEmailTransportProfileSource,
                   ByVal identityProvider As IEmailDatabaseIdentityProvider)
        If source Is Nothing Then Throw New ArgumentNullException("source")
        If identityProvider Is Nothing Then Throw New ArgumentNullException("identityProvider")
        _source = source
        _identityProvider = identityProvider
    End Sub

    Public Function Resolve(ByVal connectionString As String,
                            ByVal aziendaId As Integer,
                            ByVal purpose As String) As TenantEmailTransportProfileResolution Implements ITenantEmailTransportProfileResolver.Resolve
        Return ResolveInternal(connectionString, aziendaId, purpose, False)
    End Function

    Public Function ResolveForVerification(ByVal connectionString As String,
                                            ByVal aziendaId As Integer,
                                            ByVal purpose As String) As TenantEmailTransportProfileResolution Implements ITenantEmailTransportProfileResolver.ResolveForVerification
        Return ResolveInternal(connectionString, aziendaId, purpose, True)
    End Function

    Private Function ResolveInternal(ByVal connectionString As String,
                                     ByVal aziendaId As Integer,
                                     ByVal purpose As String,
                                     ByVal verificationOnly As Boolean) As TenantEmailTransportProfileResolution
        Dim databaseIdentity As String = _identityProvider.GetIdentity(connectionString)
        Dim normalizedPurpose As String = NormalizePurpose(purpose)
        If databaseIdentity = String.Empty OrElse aziendaId <= 0 OrElse normalizedPurpose = String.Empty Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.TechnicalError, "PROFILE_SCOPE_INVALID", databaseIdentity)
        End If

        Dim sourceResult As EmailTransportProfileSourceResult = _source.Load(connectionString, aziendaId, normalizedPurpose)
        If sourceResult Is Nothing OrElse sourceResult.TechnicalFailure Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.TechnicalError, "PROFILE_SOURCE_FAILURE", databaseIdentity)
        End If
        If Not sourceResult.SchemaAvailable Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.SchemaUnavailable, "PROFILE_SCHEMA_UNAVAILABLE", databaseIdentity)
        End If

        Dim records As IList(Of TenantEmailTransportProfileRecord) = sourceResult.Records
        If records Is Nothing OrElse records.Count = 0 Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.NotConfigured, "PROFILE_NOT_CONFIGURED", databaseIdentity)
        End If
        If records.Count <> 1 Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.Ambiguous, "PROFILE_AMBIGUOUS", databaseIdentity)
        End If

        Dim record As TenantEmailTransportProfileRecord = records(0)
        If record Is Nothing OrElse record.AziendaId <> aziendaId OrElse Not String.Equals(record.Purpose, normalizedPurpose, StringComparison.Ordinal) Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.TechnicalError, "PROFILE_SCOPE_MISMATCH", databaseIdentity)
        End If
        If Not verificationOnly AndAlso Not record.Enabled Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.Disabled, "PROFILE_DISABLED", databaseIdentity)
        End If
        If Not IsCredentialReferenceForScope(record.CredentialReference, databaseIdentity, aziendaId, normalizedPurpose) Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.CredentialMissing, "PROFILE_CREDENTIAL_MISSING", databaseIdentity)
        End If

        Dim securityMode As EmailSecurityMode
        If Not TrySecurityMode(record.SecurityMode, securityMode) Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.NotOperational, "PROFILE_SECURITY_NOT_OPERATIONAL", databaseIdentity)
        End If

        Dim authenticationMode As EmailAuthenticationMode
        If Not TryAuthenticationMode(record.AuthenticationMode, authenticationMode) Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.NotOperational, "PROFILE_AUTH_NOT_OPERATIONAL", databaseIdentity)
        End If
        If authenticationMode = EmailAuthenticationMode.OAuth2 Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.NotOperational, "PROFILE_OAUTH2_NOT_OPERATIONAL", databaseIdentity)
        End If

        If Not ValidateRecord(record) Then
            Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.TechnicalError, "PROFILE_VALIDATION_FAILED", databaseIdentity)
        End If
        If verificationOnly Then
            If Not String.Equals(record.VerificationStatus, "NOT_VERIFIED", StringComparison.Ordinal) AndAlso
               Not String.Equals(record.VerificationStatus, "VERIFIED", StringComparison.Ordinal) Then
                Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.NotOperational, "PROFILE_VERIFICATION_STATE_NOT_ALLOWED", databaseIdentity)
            End If
        Else
            If Not String.Equals(record.VerificationStatus, "VERIFIED", StringComparison.Ordinal) OrElse
               Not record.LastVerifiedAtUtc.HasValue OrElse String.IsNullOrWhiteSpace(record.LastVerificationCode) Then
                Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.NotOperational, "PROFILE_NOT_VERIFIED", databaseIdentity)
            End If
        End If

        Dim profile As New TenantEmailTransportProfile(databaseIdentity,
                                                        record.EmailTransportId,
                                                        record.AziendaId,
                                                        record.Purpose,
                                                        record.ProviderKind,
                                                        record.Host,
                                                        record.Port,
                                                        securityMode,
                                                        authenticationMode,
                                                        record.Username,
                                                        record.CredentialReference,
                                                        record.FromAddress,
                                                        record.FromDisplayName,
                                                        record.ReplyToAddress,
                                                        record.EnvelopeFromAddress,
                                                        record.TimeoutSeconds)
        Return TenantEmailTransportProfileResolution.Create(TenantEmailTransportProfileState.Ready, "PROFILE_READY", databaseIdentity, profile)
    End Function

    Private Shared Function IsCredentialReferenceForScope(ByVal value As String,
                                                           ByVal databaseIdentity As String,
                                                           ByVal aziendaId As Integer,
                                                           ByVal purpose As String) As Boolean
        Dim parts As EmailCredentialReferenceParts = Nothing
        If Not DpapiEmailCredentialStore.TryParseReference(value, parts) OrElse parts Is Nothing Then Return False
        Return String.Equals(parts.DatabaseIdentity, databaseIdentity, StringComparison.Ordinal) AndAlso
               parts.AziendaId = aziendaId AndAlso
               String.Equals(parts.Purpose, purpose, StringComparison.Ordinal)
    End Function

    Private Shared Function NormalizePurpose(ByVal value As String) As String
        Dim normalized As String = Convert.ToString(value).Trim().ToUpperInvariant()
        If normalized <> "TRANSACTIONAL" AndAlso normalized <> "MARKETING" Then Return String.Empty
        Return normalized
    End Function

    Private Shared Function ValidateRecord(ByVal record As TenantEmailTransportProfileRecord) As Boolean
        If record.EmailTransportId <= 0 OrElse record.AziendaId <= 0 Then Return False
        If Not AllowedProviders.Contains(Convert.ToString(record.ProviderKind).Trim()) Then Return False
        If Uri.CheckHostName(Convert.ToString(record.Host).Trim()) <> UriHostNameType.Dns Then Return False
        If record.Port < 1 OrElse record.Port > 65535 Then Return False
        If record.TimeoutSeconds < 5 OrElse record.TimeoutSeconds > 300 Then Return False
        If String.IsNullOrWhiteSpace(record.Username) OrElse record.Username.Length > 254 Then Return False
        If String.IsNullOrWhiteSpace(record.FromDisplayName) OrElse record.FromDisplayName.Length > 255 Then Return False
        If String.IsNullOrWhiteSpace(record.CredentialReference) OrElse record.CredentialReference.Length > 512 Then Return False
        If Not IsEmailAddress(record.FromAddress) Then Return False
        If Not String.IsNullOrWhiteSpace(record.ReplyToAddress) AndAlso Not IsEmailAddress(record.ReplyToAddress) Then Return False
        If Not String.IsNullOrWhiteSpace(record.EnvelopeFromAddress) AndAlso Not IsEmailAddress(record.EnvelopeFromAddress) Then Return False
        Return True
    End Function

    Private Shared Function IsEmailAddress(ByVal value As String) As Boolean
        Try
            Dim parsed As MailboxAddress = Nothing
            If Not MailboxAddress.TryParse(Convert.ToString(value).Trim(), parsed) OrElse parsed Is Nothing Then Return False
            Return String.Equals(parsed.Address, Convert.ToString(value).Trim(), StringComparison.OrdinalIgnoreCase)
        Catch
            Return False
        End Try
    End Function

    Private Shared Function TrySecurityMode(ByVal value As String, ByRef mode As EmailSecurityMode) As Boolean
        Select Case Convert.ToString(value).Trim()
            Case "STARTTLS"
                mode = EmailSecurityMode.StartTls
                Return True
            Case "IMPLICIT_TLS"
                mode = EmailSecurityMode.ImplicitTls
                Return True
            Case Else
                Return False
        End Select
    End Function

    Private Shared Function TryAuthenticationMode(ByVal value As String, ByRef mode As EmailAuthenticationMode) As Boolean
        Select Case Convert.ToString(value).Trim()
            Case "PASSWORD"
                mode = EmailAuthenticationMode.Password
                Return True
            Case "APP_PASSWORD"
                mode = EmailAuthenticationMode.AppPassword
                Return True
            Case "OAUTH2"
                mode = EmailAuthenticationMode.OAuth2
                Return True
            Case Else
                Return False
        End Select
    End Function
End Class
