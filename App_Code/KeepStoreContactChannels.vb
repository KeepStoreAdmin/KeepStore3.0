Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Configuration
Imports System.Data
Imports MySql.Data.MySqlClient

' PDP-TOOLS-1A. Canale WhatsApp dell'azienda, letto dai pulsanti social gia presenti nel database (nessun campo nuovo).
' - L'azienda la sceglie il chiamante dall'identita dell'host; qui arriva solo il suo id.
' - Cache breve per database E azienda (StorefrontTenantScopedCache): mai una voce condivisa fra aziende.
' - Sola lettura. La regola del pulsante fisso e tinyint(1): il connettore la leggerebbe come Boolean, quindi si converte con CAST.
' - Tabella assente (database non ancora allineato) = «nessun canale», esito valido che si memorizza; ogni altro errore non si memorizza.
Public NotInheritable Class KeepStoreContactChannels
    Private Const CacheArea As String = "ContactChannel"
    Private Const CacheSeconds As Integer = 600

    Public Const ChannelSql As String =
        "SELECT b.`value` AS Number, CAST(COALESCE(r.enabled,0) AS SIGNED) AS WidgetEnabled, COALESCE(r.callToAction,'') AS CallToAction, " &
        "COALESCE(r.position,'') AS Position FROM social_buttons b LEFT JOIN social_buttons_rules r ON r.company_id=b.company_id " &
        "WHERE b.company_id=@companyId AND b.`key`='whatsapp' AND b.enabled=1"

    Private Sub New()
    End Sub

    ' Mai Nothing: senza azienda, senza dati o con un errore il risultato e ContactChannel.None.
    Public Shared Function ForCompany(ByVal companyId As Integer) As ContactChannel
        If companyId <= 0 Then Return ContactChannel.None
        Dim channel As ContactChannel = StorefrontTenantScopedCache.GetOrLoad(Of ContactChannel)(CacheArea, StorefrontSeoTenantContext.ConfiguredDatabaseScopeKey(), companyId, String.Empty, CacheSeconds,
            Function() LoadChannel(companyId))
        If channel Is Nothing Then Return ContactChannel.None
        Return channel
    End Function

    Private Shared Function LoadChannel(ByVal companyId As Integer) As ContactChannel
        Dim settings As ConnectionStringSettings = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then Return Nothing
        Using connection As New MySqlConnection(settings.ConnectionString)
            connection.Open()
            Return ReadChannel(connection, companyId)
        End Using
    End Function

    ' Lettura su una connessione gia aperta (usata anche dalla prova sul LAB).
    Public Shared Function ReadChannel(ByVal connection As MySqlConnection, ByVal companyId As Integer) As ContactChannel
        Dim rows As New List(Of ContactChannelRow)()
        Try
            Using command As New MySqlCommand(ChannelSql, connection)
                command.CommandType = CommandType.Text
                command.CommandTimeout = 3
                command.Parameters.Add("@companyId", MySqlDbType.Int32).Value = companyId
                Using reader As MySqlDataReader = command.ExecuteReader()
                    While reader.Read()
                        rows.Add(New ContactChannelRow(TextOf(reader, "Number"), Convert.ToInt32(reader("WidgetEnabled"), Globalization.CultureInfo.InvariantCulture),
                                                       TextOf(reader, "CallToAction"), TextOf(reader, "Position")))
                    End While
                End Using
            End Using
        Catch ex As MySqlException
            If ex.Number = 1146 Then Return ContactChannel.None
            Throw
        End Try
        Return ContactChannelPolicy.SelectChannel(rows)
    End Function

    Private Shared Function TextOf(ByVal reader As IDataRecord, ByVal name As String) As String
        Dim ordinal As Integer = reader.GetOrdinal(name)
        If reader.IsDBNull(ordinal) Then Return String.Empty
        Return Convert.ToString(reader.GetValue(ordinal), Globalization.CultureInfo.InvariantCulture)
    End Function
End Class
