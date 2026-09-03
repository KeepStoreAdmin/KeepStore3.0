Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.IO
Imports System.Web
Imports MySql.Data.MySqlClient

Public Class ProductShippingRate
    Public Property CarrierId As Integer
    Public Property Description As String
    Public Property SortOrder As Integer
    Public Property MaximumWeightKg As Decimal
    Public Property NetCost As Decimal
    Public Property DisplayCost As String
    Public Property LogoUrl As String
    Public Property LogoAlt As String

    Public ReadOnly Property HasLogo As Boolean
        Get
            Return Not String.IsNullOrWhiteSpace(LogoUrl)
        End Get
    End Property
End Class

Public NotInheritable Class ProductShippingRateResolver
    Private Shared ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")

    Private Sub New()
    End Sub

    Public Shared Function LoadApplicableRates(connectionString As String,
                                               companyId As Integer,
                                               weightKg As Decimal,
                                               ivaTipo As Integer,
                                               ivaVettori As Decimal,
                                               carrierLogoPhysicalRoot As String) As List(Of ProductShippingRate)
        Dim rates As New List(Of ProductShippingRate)()
        If String.IsNullOrWhiteSpace(connectionString) OrElse companyId <= 0 OrElse weightKg <= 0D Then Return rates
        If ivaTipo <> 1 AndAlso ivaVettori < 0D Then Return rates

        Const sql As String =
            "SELECT DISTINCT vc.id, vc.Descrizione, vc.Ordinamento, vc.Img, vc.PesoMax, vc.CostoFisso " &
            "FROM vvettoricosti vc " &
            "INNER JOIN vettoricosti c ON c.Id = vc.vettoricostiId " &
            "WHERE vc.AziendeId = @aziendaId " &
            "AND vc.Abilitato = 1 AND vc.Web = 1 AND vc.Promo = 0 " &
            "AND vc.PesoMax >= @peso AND vc.CostoFisso > 0 " &
            "AND COALESCE(c.Soglia_Minima, 0) <= 0 " &
            "AND NOT EXISTS (" &
            "  SELECT 1 FROM vettoricosti c2 " &
            "  WHERE c2.VettoriId = vc.id " &
            "  AND c2.PesoMax >= @peso " &
            "  AND c2.PesoMax < vc.PesoMax " &
            "  AND COALESCE(c2.Soglia_Minima, 0) <= 0" &
            ") " &
            "ORDER BY vc.Ordinamento, vc.Descrizione, vc.id"

        Using cn As New MySqlConnection(connectionString)
            cn.Open()
            Using cmd As New MySqlCommand(sql, cn)
                cmd.Parameters.Add("@aziendaId", MySqlDbType.Int32).Value = companyId
                cmd.Parameters.Add("@peso", MySqlDbType.Decimal).Value = weightKg

                Using rdr As MySqlDataReader = cmd.ExecuteReader()
                    While rdr.Read()
                        Dim netCost As Decimal = ReaderDecimal(rdr, "CostoFisso", 0D)
                        If netCost <= 0D Then Continue While

                        Dim description As String = ReaderString(rdr, "Descrizione").Trim()
                        If String.IsNullOrWhiteSpace(description) Then Continue While

                        Dim displayCostValue As Decimal = netCost
                        If ivaTipo <> 1 Then
                            displayCostValue = netCost * ((ivaVettori / 100D) + 1D)
                        End If

                        rates.Add(New ProductShippingRate() With {
                            .CarrierId = ReaderInt(rdr, "id", 0),
                            .Description = description,
                            .SortOrder = ReaderInt(rdr, "Ordinamento", 0),
                            .MaximumWeightKg = ReaderDecimal(rdr, "PesoMax", 0D),
                            .NetCost = netCost,
                            .DisplayCost = displayCostValue.ToString("N2", ItCulture) & " " & ChrW(8364),
                            .LogoUrl = ResolveLogoUrl(ReaderString(rdr, "Img"), carrierLogoPhysicalRoot),
                            .LogoAlt = "Logo " & description
                        })
                    End While
                End Using
            End Using
        End Using

        Return rates
    End Function

    Private Shared Function ResolveLogoUrl(rawValue As String, physicalRoot As String) As String
        If String.IsNullOrWhiteSpace(rawValue) OrElse String.IsNullOrWhiteSpace(physicalRoot) Then Return String.Empty

        Dim fileName As String = rawValue.Trim()
        If fileName.IndexOf("/"c) >= 0 OrElse fileName.IndexOf("\"c) >= 0 OrElse fileName.IndexOf(":"c) >= 0 Then Return String.Empty
        If Not String.Equals(Path.GetFileName(fileName), fileName, StringComparison.Ordinal) Then Return String.Empty

        Dim extension As String = Path.GetExtension(fileName)
        If Not String.Equals(extension, ".jpg", StringComparison.OrdinalIgnoreCase) AndAlso
           Not String.Equals(extension, ".jpeg", StringComparison.OrdinalIgnoreCase) AndAlso
           Not String.Equals(extension, ".png", StringComparison.OrdinalIgnoreCase) AndAlso
           Not String.Equals(extension, ".gif", StringComparison.OrdinalIgnoreCase) AndAlso
           Not String.Equals(extension, ".webp", StringComparison.OrdinalIgnoreCase) Then Return String.Empty

        Dim candidate As String = Path.Combine(physicalRoot, fileName)
        If Not File.Exists(candidate) Then Return String.Empty
        Return "/Public/assets/images/vettori/" & HttpUtility.UrlPathEncode(fileName)
    End Function

    Private Shared Function ReaderString(rdr As MySqlDataReader, columnName As String) As String
        Dim ordinal As Integer = rdr.GetOrdinal(columnName)
        If rdr.IsDBNull(ordinal) Then Return String.Empty
        Return Convert.ToString(rdr.GetValue(ordinal), CultureInfo.InvariantCulture)
    End Function

    Private Shared Function ReaderInt(rdr As MySqlDataReader, columnName As String, fallback As Integer) As Integer
        Dim value As Integer
        If Integer.TryParse(ReaderString(rdr, columnName), NumberStyles.Integer, CultureInfo.InvariantCulture, value) Then Return value
        Return fallback
    End Function

    Private Shared Function ReaderDecimal(rdr As MySqlDataReader, columnName As String, fallback As Decimal) As Decimal
        Dim ordinal As Integer = rdr.GetOrdinal(columnName)
        If rdr.IsDBNull(ordinal) Then Return fallback
        Try
            Return Convert.ToDecimal(rdr.GetValue(ordinal), CultureInfo.InvariantCulture)
        Catch
            Return fallback
        End Try
    End Function
End Class
