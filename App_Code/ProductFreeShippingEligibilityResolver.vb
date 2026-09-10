Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

Public Enum ProductFreeShippingEligibilityStatus
    Success = 0
    InvalidRequest = 1
    TechnicalError = 2
End Enum

Public Class ProductFreeShippingEligibilityResult
    Public Sub New()
        Status = ProductFreeShippingEligibilityStatus.Success
    End Sub

    Public Property Status As ProductFreeShippingEligibilityStatus
    Public Property Eligible As Boolean

    Public ReadOnly Property HasTechnicalError As Boolean
        Get
            Return Status = ProductFreeShippingEligibilityStatus.TechnicalError
        End Get
    End Property
End Class

Public Module ProductFreeShippingEligibilityResolver
    Public Function Resolve(ByVal conn As MySqlConnection,
                            ByVal transaction As MySqlTransaction,
                            ByVal articleId As Integer,
                            ByVal companyId As Integer,
                            ByVal listino As Integer,
                            ByVal evaluationDate As Date,
                            ByVal lockCommercialRows As Boolean,
                            Optional ByVal propagateTransactionTransientErrors As Boolean = False) As ProductFreeShippingEligibilityResult
        Dim result As New ProductFreeShippingEligibilityResult()
        If conn Is Nothing OrElse conn.State <> ConnectionState.Open OrElse
           articleId <= 0 OrElse companyId <= 0 OrElse listino <= 0 OrElse
           (lockCommercialRows AndAlso transaction Is Nothing) Then
            result.Status = ProductFreeShippingEligibilityStatus.InvalidRequest
            Return result
        End If

        Try
            Dim sql As String =
                "SELECT COALESCE(Abilitato,0) AS Abilitato, " &
                "COALESCE(SpedizioneGratis_Listini,'') AS SpedizioneGratis_Listini, " &
                "SpedizioneGratis_Data_Inizio, SpedizioneGratis_Data_Fine " &
                "FROM articoli WHERE id=@articleId LIMIT 1"
            If lockCommercialRows Then sql &= " FOR UPDATE"

            Using cmd As New MySqlCommand(sql, conn, transaction)
                cmd.Parameters.Add("@articleId", MySqlDbType.Int32).Value = articleId
                Using reader As MySqlDataReader = cmd.ExecuteReader()
                    If Not reader.Read() Then Return result
                    If ReadInt(reader, "Abilitato", 0) <> 1 Then Return result

                    Dim rawListini As String = Convert.ToString(reader("SpedizioneGratis_Listini")).Trim()
                    If rawListini = String.Empty Then Return result

                    Dim allowedListini As HashSet(Of Integer) = ParseExactListini(rawListini)
                    If Not allowedListini.Contains(listino) Then Return result

                    Dim startsOn As Nullable(Of Date) = ReadNullableDate(reader, "SpedizioneGratis_Data_Inizio")
                    Dim endsOn As Nullable(Of Date) = ReadNullableDate(reader, "SpedizioneGratis_Data_Fine")
                    If Not startsOn.HasValue OrElse Not endsOn.HasValue Then Return result

                    Dim currentDate As Date = evaluationDate.Date
                    result.Eligible = startsOn.Value.Date <= currentDate AndAlso endsOn.Value.Date >= currentDate
                End Using
            End Using
        Catch ex As Exception
            If propagateTransactionTransientErrors AndAlso CartTransactionRetryPolicy.GetMySqlErrorNumber(ex) >= 0 Then Throw
            result.Eligible = False
            result.Status = ProductFreeShippingEligibilityStatus.TechnicalError
            If Not propagateTransactionTransientErrors Then LogFailure(articleId, companyId, listino, ex)
        End Try

        Return result
    End Function

    Private Function ParseExactListini(ByVal rawListini As String) As HashSet(Of Integer)
        Dim values As New HashSet(Of Integer)()
        Dim tokens As String() = rawListini.Split(";"c)
        For index As Integer = 0 To tokens.Length - 1
            Dim token As String = tokens(index).Trim()
            If token = String.Empty Then
                If index = tokens.Length - 1 Then Continue For
                Throw New FormatException("Invalid free-shipping listino separator.")
            End If

            Dim value As Integer
            If Not Integer.TryParse(token, NumberStyles.None, CultureInfo.InvariantCulture, value) OrElse value <= 0 Then
                Throw New FormatException("Invalid free-shipping listino token.")
            End If
            values.Add(value)
        Next

        If values.Count = 0 Then Throw New FormatException("Empty free-shipping listino rule.")
        Return values
    End Function

    Private Function ReadInt(ByVal reader As IDataRecord, ByVal columnName As String, ByVal defaultValue As Integer) As Integer
        Dim ordinal As Integer = reader.GetOrdinal(columnName)
        If reader.IsDBNull(ordinal) Then Return defaultValue
        Dim value As Integer
        If Integer.TryParse(Convert.ToString(reader.GetValue(ordinal), CultureInfo.InvariantCulture), value) Then Return value
        Return defaultValue
    End Function

    Private Function ReadNullableDate(ByVal reader As IDataRecord, ByVal columnName As String) As Nullable(Of Date)
        Dim ordinal As Integer = reader.GetOrdinal(columnName)
        If reader.IsDBNull(ordinal) Then Return Nothing
        Return Convert.ToDateTime(reader.GetValue(ordinal), CultureInfo.InvariantCulture).Date
    End Function

    Private Sub LogFailure(ByVal articleId As Integer,
                           ByVal companyId As Integer,
                           ByVal listino As Integer,
                           ByVal ex As Exception)
        Try
            Dim line As String = DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture) &
                                 " | Free-shipping eligibility failed" &
                                 " | article=" & articleId.ToString(CultureInfo.InvariantCulture) &
                                 " | company=" & companyId.ToString(CultureInfo.InvariantCulture) &
                                 " | listino=" & listino.ToString(CultureInfo.InvariantCulture) &
                                 " | errorType=" & ex.GetType().Name
            Dim ignored As Exception = Nothing
            KeepStoreLog.TryAppendLine("free-shipping-eligibility.log", line, HttpContext.Current, ignored)
        Catch
        End Try
    End Sub
End Module
