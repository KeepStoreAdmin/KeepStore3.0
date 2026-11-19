Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

' CATALOG-DEAL-PROGRESS-1B. Lettura dei "venduti negli ultimi 12 mesi" per un elenco di articoli, con la misura commerciale
' definita in StorefrontSoldUnits (una sola definizione per HOME ed elenco). Una chiamata = al massimo una query.
' Nessuna cache: il risultato dipende dall'azienda dell'host e non va condiviso fra richieste.
Public NotInheritable Class StorefrontSoldUnitsReader
    Private Sub New()
    End Sub

    ' Restituisce articolo -> pezzi venduti (solo valori maggiori di zero). Elenco vuoto, azienda assente o qualunque errore:
    ' dizionario vuoto (la pagina resta in piedi e non mostra la barra); nel registro solo il tipo dell'errore.
    Public Shared Function Load(ByVal connectionString As String,
                                ByVal companyId As Integer,
                                ByVal articleIds As IEnumerable(Of Integer),
                                ByVal context As HttpContext) As Dictionary(Of Integer, Decimal)
        Dim result As New Dictionary(Of Integer, Decimal)()
        Dim idList As String = StorefrontSoldUnits.FormatIdList(articleIds)
        If companyId <= 0 OrElse String.IsNullOrEmpty(idList) OrElse String.IsNullOrEmpty(connectionString) Then Return result
        Try
            Using conn As New MySqlConnection(connectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT x.ArticoliId, x.CommercialScore FROM (" & StorefrontSoldUnits.BuildCommercialActivitySql(idList) & ") x", conn)
                    cmd.CommandTimeout = 3
                    cmd.Parameters.Add("@commercialCompany", MySqlDbType.Int32).Value = companyId
                    cmd.Parameters.Add("@commercialStart", MySqlDbType.Date).Value = Date.Today.AddMonths(-12)
                    cmd.Parameters.Add("@commercialEnd", MySqlDbType.Date).Value = Date.Today.AddDays(1)
                    Using reader As MySqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            If reader.IsDBNull(0) OrElse reader.IsDBNull(1) Then Continue While
                            Dim units As Decimal = Convert.ToDecimal(reader.GetValue(1), CultureInfo.InvariantCulture)
                            If units > 0D Then result(Convert.ToInt32(reader.GetValue(0), CultureInfo.InvariantCulture)) = units
                        End While
                    End Using
                End Using
            End Using
        Catch ex As Exception
            KeepStoreLog.Error("storefront-sold-units", "Sold units unavailable. Error type: " & ex.GetType().Name & ".", Nothing, context)
            Return New Dictionary(Of Integer, Decimal)()
        End Try
        Return result
    End Function
End Class
