Imports System
Imports System.Configuration
Imports System.IO
Imports System.Security.Cryptography
Imports System.Web.Configuration
Imports System.Xml
Imports MySql.Data.MySqlClient

' Tool-only reader. Never log the returned value or propagate configuration exceptions.
Public NotInheritable Class KeepStoreConfigurationReader
    Private Sub New()
    End Sub

    Public Shared Function ValidateConfigurationPath(ByVal configurationPath As String) As String
        Try
            If String.IsNullOrWhiteSpace(configurationPath) OrElse Not Path.IsPathRooted(configurationPath) Then Throw New ArgumentException()
            Dim fullPath As String = Path.GetFullPath(configurationPath)
            If Not File.Exists(fullPath) Then Throw New ArgumentException()
            Dim directory As New DirectoryInfo(Path.GetDirectoryName(fullPath))
            Do While directory IsNot Nothing
                If (directory.Attributes And FileAttributes.ReparsePoint) <> 0 Then Throw New ArgumentException()
                directory = directory.Parent
            Loop
            If (File.GetAttributes(fullPath) And FileAttributes.ReparsePoint) <> 0 Then Throw New ArgumentException()
            Return fullPath
        Catch
            Throw New ArgumentException("DBCFG_PATH_INVALID")
        End Try
    End Function

    Public Shared Function OpenConfiguration(ByVal configurationPath As String) As Configuration
        Try
            Dim target As String = ValidateConfigurationPath(configurationPath)
            Dim map As New WebConfigurationFileMap()
            map.VirtualDirectories.Add("/", New VirtualDirectoryMapping(Path.GetDirectoryName(target), True, Path.GetFileName(target)))
            Dim configuration As Configuration = WebConfigurationManager.OpenMappedWebConfiguration(map, "/")
            If Not String.Equals(Path.GetFullPath(configuration.FilePath), target, StringComparison.OrdinalIgnoreCase) Then Throw New ArgumentException()
            Return configuration
        Catch
            Throw New ArgumentException("DBCFG_CONFIGURATION_INVALID")
        End Try
    End Function

    Public Shared Function ReadConnectionString(ByVal applicationRoot As String, Optional ByVal connectionName As String = "EntropicConnectionString") As String
        Try
            If String.IsNullOrWhiteSpace(applicationRoot) OrElse Not Path.IsPathRooted(applicationRoot) Then Throw New ArgumentException()
            Return ReadConnectionStringFromFile(Path.Combine(applicationRoot, "web.config"), connectionName)
        Catch
            Throw New ArgumentException("DBCFG_CONNECTION_INVALID")
        End Try
    End Function

    Public Shared Function ReadConnectionStringFromFile(ByVal configurationPath As String, Optional ByVal connectionName As String = "EntropicConnectionString") As String
        Try
            If String.IsNullOrWhiteSpace(connectionName) OrElse connectionName <> connectionName.Trim() Then Throw New ArgumentException()
            Dim target As String = ValidateConfigurationPath(configurationPath)
            Dim configuration As Configuration = OpenConfiguration(target)
            ValidateDeclaredSection(target, configuration)
            Dim section As ConnectionStringsSection = TryCast(configuration.GetSection("connectionStrings"), ConnectionStringsSection)
            If section Is Nothing OrElse Not String.IsNullOrEmpty(section.SectionInformation.ConfigSource) Then Throw New ArgumentException()
            Dim selected As ConnectionStringSettings = Nothing
            For Each entry As ConnectionStringSettings In section.ConnectionStrings
                If String.Equals(entry.Name, connectionName, StringComparison.Ordinal) Then
                    If selected IsNot Nothing Then Throw New ArgumentException()
                    selected = entry
                End If
            Next
            If selected Is Nothing OrElse Not String.Equals(selected.ProviderName, "MySql.Data.MySqlClient", StringComparison.Ordinal) Then Throw New ArgumentException()
            Dim origin As String = selected.ElementInformation.Source
            If String.IsNullOrWhiteSpace(origin) OrElse Not String.Equals(Path.GetFullPath(origin), target, StringComparison.OrdinalIgnoreCase) Then Throw New ArgumentException()
            Dim value As String = selected.ConnectionString
            If String.IsNullOrWhiteSpace(value) Then Throw New ArgumentException()
            Dim builder As New MySqlConnectionStringBuilder(value)
            If Not builder.ShouldSerialize("server") OrElse Not builder.ShouldSerialize("database") OrElse String.IsNullOrWhiteSpace(builder.Server) OrElse String.IsNullOrWhiteSpace(builder.Database) Then Throw New ArgumentException()
            Return value
        Catch
            ' Do not retain InnerException: native errors can contain decrypted values/paths.
            Throw New ArgumentException("DBCFG_CONNECTION_INVALID")
        End Try
    End Function

    Private Shared Sub ValidateDeclaredSection(ByVal target As String, ByVal configuration As Configuration)
        ' Inspect only section protection/source metadata. Values are resolved exclusively
        ' by .NET below. Preflight prevents the native RSA provider creating a missing key
        ' during a failed decrypt, and rejects external sections before opening them.
        Dim providerName As String = Nothing
        Dim declarations As Integer = 0
        Dim options As New XmlReaderSettings()
        options.DtdProcessing = DtdProcessing.Prohibit
        options.XmlResolver = Nothing
        Using reader As XmlReader = XmlReader.Create(target, options)
            While reader.Read()
                If reader.NodeType = XmlNodeType.Element AndAlso reader.Depth = 1 AndAlso reader.LocalName = "connectionStrings" Then
                    declarations += 1
                    If Not String.IsNullOrEmpty(reader.GetAttribute("configSource")) Then Throw New ArgumentException()
                    providerName = reader.GetAttribute("configProtectionProvider")
                End If
            End While
        End Using
        If declarations <> 1 Then Throw New ArgumentException()
        If String.IsNullOrEmpty(providerName) Then Return
        Dim providers As ProtectedConfigurationSection = TryCast(configuration.GetSection("configProtectedData"), ProtectedConfigurationSection)
        If providers Is Nothing Then Throw New ArgumentException()
        Dim settings As ProviderSettings = providers.Providers(providerName)
        If settings Is Nothing OrElse Not String.Equals(settings.ElementInformation.Source, target, StringComparison.OrdinalIgnoreCase) Then Throw New ArgumentException()
        If Type.GetType(settings.Type, False) IsNot GetType(RsaProtectedConfigurationProvider) Then Throw New ArgumentException()
        Dim machine As Boolean
        If Not Boolean.TryParse(settings.Parameters("useMachineContainer"), machine) Then Throw New ArgumentException()
        Dim container As String = settings.Parameters("keyContainerName")
        If String.IsNullOrWhiteSpace(container) Then Throw New ArgumentException()
        Dim parameters As New CspParameters()
        parameters.KeyContainerName = container
        parameters.Flags = CspProviderFlags.UseExistingKey
        If machine Then parameters.Flags = parameters.Flags Or CspProviderFlags.UseMachineKeyStore
        Using key As New RSACryptoServiceProvider(parameters)
            If key.PublicOnly Then Throw New ArgumentException()
        End Using
    End Sub
End Class
