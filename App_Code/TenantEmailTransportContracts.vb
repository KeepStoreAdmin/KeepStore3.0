Imports System
Imports System.Collections.Generic
Imports MimeKit

Public Enum TenantEmailTransportProfileState
    SchemaUnavailable = 0
    NotConfigured = 1
    Disabled = 2
    Ambiguous = 3
    CredentialMissing = 4
    NotOperational = 5
    Ready = 6
    TechnicalError = 7
End Enum

Public Enum EmailCredentialState
    Found = 0
    Missing = 1
    Invalid = 2
    Unavailable = 3
End Enum

Public Enum EmailSecurityMode
    StartTls = 0
    ImplicitTls = 1
End Enum

Public Enum EmailAuthenticationMode
    Password = 0
    AppPassword = 1
    OAuth2 = 2
End Enum

Public Enum EmailTransportOperationStatus
    Succeeded = 0
    Rejected = 1
    Failed = 2
End Enum

Public Enum EmailTransportFailureKind
    None = 0
    Resolver = 1
    Credential = 2
    Dns = 3
    Tcp = 4
    Tls = 5
    Certificate = 6
    HostnameMismatch = 7
    Authentication = 8
    Timeout = 9
    Transport = 10
    NotOperational = 11
    InvalidRequest = 12
End Enum

Public NotInheritable Class TenantEmailTransportProfile
    Private ReadOnly _databaseIdentity As String
    Private ReadOnly _emailTransportId As Long
    Private ReadOnly _aziendaId As Integer
    Private ReadOnly _purpose As String
    Private ReadOnly _providerKind As String
    Private ReadOnly _host As String
    Private ReadOnly _port As Integer
    Private ReadOnly _securityMode As EmailSecurityMode
    Private ReadOnly _authenticationMode As EmailAuthenticationMode
    Private ReadOnly _username As String
    Private ReadOnly _credentialReference As String
    Private ReadOnly _fromAddress As String
    Private ReadOnly _fromDisplayName As String
    Private ReadOnly _replyToAddress As String
    Private ReadOnly _envelopeFromAddress As String
    Private ReadOnly _timeoutSeconds As Integer

    Public Sub New(ByVal databaseIdentity As String,
                   ByVal emailTransportId As Long,
                   ByVal aziendaId As Integer,
                   ByVal purpose As String,
                   ByVal providerKind As String,
                   ByVal host As String,
                   ByVal port As Integer,
                   ByVal securityMode As EmailSecurityMode,
                   ByVal authenticationMode As EmailAuthenticationMode,
                   ByVal username As String,
                   ByVal credentialReference As String,
                   ByVal fromAddress As String,
                   ByVal fromDisplayName As String,
                   ByVal replyToAddress As String,
                   ByVal envelopeFromAddress As String,
                   ByVal timeoutSeconds As Integer)
        _databaseIdentity = databaseIdentity
        _emailTransportId = emailTransportId
        _aziendaId = aziendaId
        _purpose = purpose
        _providerKind = providerKind
        _host = host
        _port = port
        _securityMode = securityMode
        _authenticationMode = authenticationMode
        _username = username
        _credentialReference = credentialReference
        _fromAddress = fromAddress
        _fromDisplayName = fromDisplayName
        _replyToAddress = replyToAddress
        _envelopeFromAddress = envelopeFromAddress
        _timeoutSeconds = timeoutSeconds
    End Sub

    Public ReadOnly Property DatabaseIdentity As String
        Get
            Return _databaseIdentity
        End Get
    End Property

    Public ReadOnly Property EmailTransportId As Long
        Get
            Return _emailTransportId
        End Get
    End Property

    Public ReadOnly Property AziendaId As Integer
        Get
            Return _aziendaId
        End Get
    End Property

    Public ReadOnly Property Purpose As String
        Get
            Return _purpose
        End Get
    End Property

    Public ReadOnly Property ProviderKind As String
        Get
            Return _providerKind
        End Get
    End Property

    Public ReadOnly Property Host As String
        Get
            Return _host
        End Get
    End Property

    Public ReadOnly Property Port As Integer
        Get
            Return _port
        End Get
    End Property

    Public ReadOnly Property SecurityMode As EmailSecurityMode
        Get
            Return _securityMode
        End Get
    End Property

    Public ReadOnly Property AuthenticationMode As EmailAuthenticationMode
        Get
            Return _authenticationMode
        End Get
    End Property

    Public ReadOnly Property Username As String
        Get
            Return _username
        End Get
    End Property

    Public ReadOnly Property CredentialReference As String
        Get
            Return _credentialReference
        End Get
    End Property

    Public ReadOnly Property FromAddress As String
        Get
            Return _fromAddress
        End Get
    End Property

    Public ReadOnly Property FromDisplayName As String
        Get
            Return _fromDisplayName
        End Get
    End Property

    Public ReadOnly Property ReplyToAddress As String
        Get
            Return _replyToAddress
        End Get
    End Property

    Public ReadOnly Property EnvelopeFromAddress As String
        Get
            Return _envelopeFromAddress
        End Get
    End Property

    Public ReadOnly Property TimeoutSeconds As Integer
        Get
            Return _timeoutSeconds
        End Get
    End Property
End Class

Public NotInheritable Class TenantEmailTransportProfileRecord
    Public Property EmailTransportId As Long
    Public Property AziendaId As Integer
    Public Property Purpose As String
    Public Property ProviderKind As String
    Public Property Host As String
    Public Property Port As Integer
    Public Property SecurityMode As String
    Public Property AuthenticationMode As String
    Public Property Username As String
    Public Property CredentialReference As String
    Public Property FromAddress As String
    Public Property FromDisplayName As String
    Public Property ReplyToAddress As String
    Public Property EnvelopeFromAddress As String
    Public Property TimeoutSeconds As Integer
    Public Property Enabled As Boolean
    Public Property VerificationStatus As String
    Public Property LastVerifiedAtUtc As Nullable(Of DateTime)
    Public Property LastVerificationCode As String
End Class

Public NotInheritable Class EmailTransportProfileSourceResult
    Public Property SchemaAvailable As Boolean
    Public Property TechnicalFailure As Boolean
    Public Property Records As IList(Of TenantEmailTransportProfileRecord)

    Public Sub New()
        Records = New List(Of TenantEmailTransportProfileRecord)()
    End Sub
End Class

Public Interface IEmailTransportProfileSource
    Function Load(ByVal connectionString As String,
                  ByVal aziendaId As Integer,
                  ByVal purpose As String) As EmailTransportProfileSourceResult
End Interface

Public Interface IEmailDatabaseIdentityProvider
    Function GetIdentity(ByVal connectionString As String) As String
End Interface

Public NotInheritable Class TenantEmailTransportProfileResolution
    Public Property State As TenantEmailTransportProfileState
    Public Property Code As String
    Public Property Profile As TenantEmailTransportProfile
    Public Property DatabaseIdentity As String

    Public Shared Function Create(ByVal stateValue As TenantEmailTransportProfileState,
                                  ByVal codeValue As String,
                                  ByVal databaseIdentityValue As String,
                                  Optional ByVal profileValue As TenantEmailTransportProfile = Nothing) As TenantEmailTransportProfileResolution
        Return New TenantEmailTransportProfileResolution() With {
            .State = stateValue,
            .Code = codeValue,
            .DatabaseIdentity = databaseIdentityValue,
            .Profile = profileValue
        }
    End Function
End Class

Public Interface ITenantEmailTransportProfileResolver
    Function Resolve(ByVal connectionString As String,
                     ByVal aziendaId As Integer,
                     ByVal purpose As String) As TenantEmailTransportProfileResolution
    Function ResolveForVerification(ByVal connectionString As String,
                                    ByVal aziendaId As Integer,
                                    ByVal purpose As String) As TenantEmailTransportProfileResolution
End Interface

Public NotInheritable Class EmailTransportRequest
    Public Property ConnectionString As String
    Public Property AziendaId As Integer
    Public Property Purpose As String
    Public Property CorrelationId As String
    Public Property Message As MimeMessage
End Class

Public NotInheritable Class EmailDeliveryResult
    Public Property Status As EmailTransportOperationStatus
    Public Property ProfileState As TenantEmailTransportProfileState
    Public Property FailureKind As EmailTransportFailureKind
    Public Property Phase As String
    Public Property Code As String
    Public Property AuthenticationMode As String
    Public Property SecurityMode As String
    Public Property TimestampUtc As DateTime
    Public Property CorrelationId As String
End Class

Public NotInheritable Class EmailConnectionVerificationResult
    Public Property Status As EmailTransportOperationStatus
    Public Property ProfileState As TenantEmailTransportProfileState
    Public Property FailureKind As EmailTransportFailureKind
    Public Property Phase As String
    Public Property Code As String
    Public Property AuthenticationMode As String
    Public Property SecurityMode As String
    Public Property TimestampUtc As DateTime
    Public Property CorrelationId As String
End Class

Public Interface IEmailTransport
    Function Deliver(ByVal request As EmailTransportRequest) As EmailDeliveryResult
    Function VerifyConnection(ByVal connectionString As String,
                              ByVal aziendaId As Integer,
                              ByVal purpose As String,
                              ByVal correlationId As String) As EmailConnectionVerificationResult
End Interface

Public Interface IEmailTransportTelemetrySink
    Sub Record(ByVal line As String)
End Interface
