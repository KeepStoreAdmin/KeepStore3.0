Option Strict On
Option Explicit On

Imports System
Imports System.Globalization

' KS-QA-BROWSER-1A. Date mostrate al cliente. Con "Allow Zero Datetime" il connettore MySQL restituisce un tipo proprio (non DateTime): il formato "{0:d}"
' non lo capisce e la pagina mostrava la data all'americana con l'ora (11/18/2026 00:00:00). Qui ogni valore diventa una data vera e si scrive giorno/mese/anno.
Public Module KeepStoreDates
    ' True se il valore e una data valida (un "0000-00-00" del database non lo e).
    Public Function TryToDate(ByVal value As Object, ByRef result As DateTime) As Boolean
        result = DateTime.MinValue
        If value Is Nothing OrElse value Is DBNull.Value Then Return False
        If TypeOf value Is DateTime Then
            result = DirectCast(value, DateTime)
            Return result > DateTime.MinValue
        End If
        Dim convertible As IConvertible = TryCast(value, IConvertible)
        If convertible IsNot Nothing AndAlso Not TypeOf value Is String Then
            Try
                result = convertible.ToDateTime(CultureInfo.InvariantCulture)
                Return result > DateTime.MinValue
            Catch
                ' Una data che il connettore non sa convertire (0000-00-00) non e una data: non si prova a leggerne il testo.
                result = DateTime.MinValue
                Return False
            End Try
        End If
        Dim text As String = Convert.ToString(value, CultureInfo.InvariantCulture)
        If String.IsNullOrWhiteSpace(text) Then Return False
        Dim formats As String() = {"yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "MM/dd/yyyy HH:mm:ss", "MM/dd/yyyy", "M/d/yyyy H:mm:ss", "M/d/yyyy h:mm:ss tt", "M/d/yyyy"}
        If DateTime.TryParseExact(text.Trim(), formats, CultureInfo.InvariantCulture, DateTimeStyles.None, result) Then Return result > DateTime.MinValue
        result = DateTime.MinValue
        Return False
    End Function

    ' Testo senza ambiguita fra giorno e mese (2026-11-17 00:00:00), per passare una data come stringa; "" se il valore non e una data.
    Public Function IsoText(ByVal value As Object) As String
        Dim d As DateTime
        If Not TryToDate(value, d) Then Return ""
        Return d.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture)
    End Function

    ' Giorno/mese/anno (17/11/2026); "" se il valore non e una data.
    Public Function ShortDate(ByVal value As Object) As String
        Dim d As DateTime
        If Not TryToDate(value, d) Then Return ""
        Return d.ToString("dd/MM/yyyy", CultureInfo.InvariantCulture)
    End Function
End Module
