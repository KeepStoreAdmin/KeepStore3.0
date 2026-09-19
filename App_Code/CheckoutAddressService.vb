Option Strict On
Option Explicit On

Imports System
Imports System.Data
Imports MySql.Data.MySqlClient

<Serializable()>
Public NotInheritable Class CheckoutAddressSnapshot
    Public Property AddressId As Integer
    Public Property UtentiId As Long
    Public Property IsMainAddress As Boolean
    Public Property IsDefault As Boolean
    Public Property CompanyName As String
    Public Property ContactName As String
    Public Property AddressLine As String
    Public Property PostalCode As String
    Public Property City As String
    Public Property Province As String
    Public Property Zone As String
    Public Property Phone As String
    Public Property Notes As String

    Public ReadOnly Property IsComplete As Boolean
        Get
            Return UtentiId > 0 AndAlso
                   Not String.IsNullOrWhiteSpace(AddressLine) AndAlso
                   Not String.IsNullOrWhiteSpace(PostalCode) AndAlso
                   Not String.IsNullOrWhiteSpace(City) AndAlso
                   Not String.IsNullOrWhiteSpace(Province)
        End Get
    End Property
End Class

''' <summary>
''' Resolves checkout addresses from the authoritative account row. Every query
''' proves the complete database/company/login/user tuple; an address id alone is
''' never accepted as ownership evidence.
''' </summary>
Public NotInheritable Class CheckoutAddressService
    Private Sub New()
    End Sub

    Public Shared Function LoadAlternativeAddresses(ByVal connection As MySqlConnection,
                                                    ByVal transaction As MySqlTransaction,
                                                    ByVal identity As OrderStorefrontIdentity) As DataTable
        If connection Is Nothing Then Throw New ArgumentNullException("connection")
        If identity Is Nothing OrElse Not identity.IsComplete Then Return New DataTable("utentiindirizzi")

        Const sql As String =
            "SELECT ui.Id, ui.RagioneSocialeA, ui.NomeA, ui.IndirizzoA, ui.CapA, " &
            "ui.CittaA, ui.ProvinciaA, ui.Zona, ui.TelefonoA, ui.CellulareA, " &
            "ui.FaxA, ui.Note, ui.NazioneA, ui.Predefinito " &
            "FROM utentiindirizzi ui " &
            "WHERE ui.UtenteId=?utentiId AND EXISTS (" &
            "SELECT 1 FROM vlogin vl WHERE vl.id=?loginId " &
            "AND vl.AziendeId=?aziendaId AND vl.utentiid=ui.UtenteId) " &
            "ORDER BY ui.Predefinito DESC, ui.Id"
        Using command As New MySqlCommand(sql, connection, transaction)
            AddOwnerParameters(command, identity)
            Using adapter As New MySqlDataAdapter(command)
                Dim table As New DataTable("utentiindirizzi")
                adapter.Fill(table)
                Return table
            End Using
        End Using
    End Function

    Public Shared Function TryResolve(ByVal connection As MySqlConnection,
                                      ByVal transaction As MySqlTransaction,
                                      ByVal identity As OrderStorefrontIdentity,
                                      ByVal addressId As Integer,
                                      ByRef result As CheckoutAddressSnapshot) As Boolean
        result = Nothing
        If connection Is Nothing OrElse identity Is Nothing OrElse Not identity.IsComplete Then Return False
        If addressId < 0 Then Return False

        If addressId = 0 Then
            Return TryResolveMain(connection, transaction, identity, result)
        End If
        Return TryResolveAlternative(connection, transaction, identity, addressId, result)
    End Function

    Private Shared Function TryResolveMain(ByVal connection As MySqlConnection,
                                           ByVal transaction As MySqlTransaction,
                                           ByVal identity As OrderStorefrontIdentity,
                                           ByRef result As CheckoutAddressSnapshot) As Boolean
        Const sql As String =
            "SELECT u.Id, u.RagioneSociale, u.CognomeNome, u.Indirizzo, u.Cap, " &
            "u.Citta, u.Provincia, u.Telefono, u.Cellulare " &
            "FROM utenti u WHERE u.Id=?utentiId AND u.AziendeId=?aziendaId " &
            "AND EXISTS (SELECT 1 FROM vlogin vl WHERE vl.id=?loginId " &
            "AND vl.AziendeId=?aziendaId AND vl.utentiid=u.Id) LIMIT 1"
        Using command As New MySqlCommand(sql, connection, transaction)
            AddOwnerParameters(command, identity)
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() Then Return False
                Dim phone As String = DbText(reader("Cellulare"))
                If phone = String.Empty Then phone = DbText(reader("Telefono"))
                result = New CheckoutAddressSnapshot() With {
                    .AddressId = 0,
                    .UtentiId = identity.UtentiId,
                    .IsMainAddress = True,
                    .IsDefault = False,
                    .CompanyName = DbText(reader("RagioneSociale")),
                    .ContactName = DbText(reader("CognomeNome")),
                    .AddressLine = DbText(reader("Indirizzo")),
                    .PostalCode = DbText(reader("Cap")),
                    .City = DbText(reader("Citta")),
                    .Province = DbText(reader("Provincia")),
                    .Zone = String.Empty,
                    .Phone = phone,
                    .Notes = String.Empty
                }
            End Using
        End Using
        Return result IsNot Nothing AndAlso result.IsComplete
    End Function

    Private Shared Function TryResolveAlternative(ByVal connection As MySqlConnection,
                                                  ByVal transaction As MySqlTransaction,
                                                  ByVal identity As OrderStorefrontIdentity,
                                                  ByVal addressId As Integer,
                                                  ByRef result As CheckoutAddressSnapshot) As Boolean
        Const sql As String =
            "SELECT ui.Id, ui.UtenteId, ui.RagioneSocialeA, ui.NomeA, ui.IndirizzoA, " &
            "ui.CapA, ui.CittaA, ui.ProvinciaA, ui.Zona, ui.TelefonoA, ui.CellulareA, " &
            "ui.Note, ui.Predefinito FROM utentiindirizzi ui " &
            "WHERE ui.Id=?addressId AND ui.UtenteId=?utentiId AND EXISTS (" &
            "SELECT 1 FROM vlogin vl WHERE vl.id=?loginId " &
            "AND vl.AziendeId=?aziendaId AND vl.utentiid=ui.UtenteId) LIMIT 1"
        Using command As New MySqlCommand(sql, connection, transaction)
            AddOwnerParameters(command, identity)
            command.Parameters.Add("?addressId", MySqlDbType.Int32).Value = addressId
            Using reader As MySqlDataReader = command.ExecuteReader()
                If Not reader.Read() Then Return False
                Dim phone As String = DbText(reader("CellulareA"))
                If phone = String.Empty Then phone = DbText(reader("TelefonoA"))
                result = New CheckoutAddressSnapshot() With {
                    .AddressId = Convert.ToInt32(reader("Id")),
                    .UtentiId = Convert.ToInt64(reader("UtenteId")),
                    .IsMainAddress = False,
                    .IsDefault = Convert.ToInt32(reader("Predefinito")) = 1,
                    .CompanyName = DbText(reader("RagioneSocialeA")),
                    .ContactName = DbText(reader("NomeA")),
                    .AddressLine = DbText(reader("IndirizzoA")),
                    .PostalCode = DbText(reader("CapA")),
                    .City = DbText(reader("CittaA")),
                    .Province = DbText(reader("ProvinciaA")),
                    .Zone = DbText(reader("Zona")),
                    .Phone = phone,
                    .Notes = DbText(reader("Note"))
                }
            End Using
        End Using
        Return result IsNot Nothing AndAlso result.IsComplete
    End Function

    Private Shared Sub AddOwnerParameters(ByVal command As MySqlCommand,
                                          ByVal identity As OrderStorefrontIdentity)
        command.Parameters.Add("?loginId", MySqlDbType.Int64).Value = identity.LoginId
        command.Parameters.Add("?aziendaId", MySqlDbType.Int32).Value = identity.CompanyId
        command.Parameters.Add("?utentiId", MySqlDbType.Int64).Value = identity.UtentiId
    End Sub

    Private Shared Function DbText(ByVal value As Object) As String
        If value Is Nothing OrElse value Is DBNull.Value Then Return String.Empty
        Return Convert.ToString(value).Trim()
    End Function
End Class
