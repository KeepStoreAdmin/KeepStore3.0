Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Reflection

' Esegue il metodo runtime reale ResolveWishlistOwnerId (estratto meccanicamente da Page.master.vb)
' con identificativi di sessione sintetici. Nessun database, sessione ASP.NET o rete.
Module WishlistHeaderOwnerKeyHarness
    Private tests As Integer
    Private failures As Integer
    Private resolver As MethodInfo

    Private Sub Check(ByVal name As String, ByVal condition As Boolean)
        tests += 1
        If condition Then Return
        failures += 1
        Console.Error.WriteLine("FAIL " & name)
    End Sub

    Private Function Owner(ByVal loginRaw As Object, ByVal utentiRaw As Object) As Integer
        Return CInt(resolver.Invoke(Nothing, New Object() {loginRaw, utentiRaw}))
    End Function

    ' Modello della colonna wishlist.id_utente: solo chiave -> numero di righe, come "WHERE id_utente=@id".
    Private Function Count(ByVal table As Dictionary(Of Integer, Integer), ByVal key As Integer) As Integer
        Dim value As Integer = 0
        If key > 0 AndAlso table.TryGetValue(key, value) Then Return value
        Return 0
    End Function

    Sub Main()
        resolver = GetType(WishlistOwnerFixture).GetMethod("ResolveWishlistOwnerId", BindingFlags.NonPublic Or BindingFlags.Static)
        Check("resolver extracted and static", resolver IsNot Nothing AndAlso resolver.IsStatic)

        ' Due account con login.id e utenti.id che si incrociano: login 7 -> utenti 42, login 42 -> utenti 7.
        Dim wishlist As New Dictionary(Of Integer, Integer) From {{42, 2}, {7, 5}, {99, 1}}
        Dim accounts As New List(Of Integer()) From {New Integer() {7, 42}, New Integer() {42, 7}, New Integer() {5, 99}}
        Dim expectedCounts As New List(Of Integer) From {2, 5, 1}
        For index As Integer = 0 To accounts.Count - 1
            Dim loginId As Integer = accounts(index)(0)
            Dim utentiId As Integer = accounts(index)(1)
            Dim key As Integer = Owner(loginId, utentiId)
            Check("owner is utenti.id for login " & loginId.ToString(CultureInfo.InvariantCulture), key = utentiId)
            Check("count matches own wishlist for login " & loginId.ToString(CultureInfo.InvariantCulture), Count(wishlist, key) = expectedCounts(index))
        Next
        ' Modello del comportamento precedente (verificato dalla fonte base nello script): la chiave era login.id.
        Check("BASELINE_MODEL login 7 / utenti 42 shows another user's count", Count(wishlist, 7) = 5 AndAlso Count(wishlist, Owner(7, 42)) = 2)

        ' Formati accettati: stesso trattamento di Integer.TryParse gia usato dal master.
        Check("boxed Integer", Owner(7, 42) = 42)
        Check("boxed Long", Owner(7L, 42L) = 42)
        Check("string ids", Owner("7", "42") = 42)
        Check("whitespace ids", Owner(" 7 ", " 42 ") = 42)

        ' Fail-closed: nessun ripiego su LoginId e nessun conteggio senza sessione autenticata.
        Check("anonymous no login", Owner(Nothing, Nothing) = 0)
        Check("login without utenti never falls back", Owner(7, Nothing) = 0)
        Check("utenti without login is anonymous", Owner(Nothing, 42) = 0)
        Check("login zero", Owner(0, 42) = 0)
        Check("utenti zero", Owner(7, 0) = 0)
        Check("login negative", Owner(-7, 42) = 0)
        Check("utenti negative", Owner(7, -42) = 0)
        Check("empty strings", Owner("", "") = 0)
        Check("DBNull ids", Owner(DBNull.Value, DBNull.Value) = 0)
        Check("non numeric login", Owner("abc", 42) = 0)
        Check("non numeric utenti", Owner(7, "abc") = 0)
        Check("decimal text", Owner("7", "42.0") = 0)
        Check("exponent text", Owner("7", "1e2") = 0)
        Check("overflow utenti", Owner(7, "99999999999") = 0)
        Check("overflow login", Owner("99999999999", 42) = 0)
        Check("hostile text", Owner("7; DROP TABLE wishlist", "42 OR 1=1") = 0)
        Check("sql fragment cannot become a key", Owner(7, "42 OR 1=1") = 0)

        ' Nessun conteggio cross-account: ogni chiave non risolta produce 0, mai la riga di un altro utente.
        Check("unresolved key counts nothing", Count(wishlist, Owner(7, Nothing)) = 0 AndAlso Count(wishlist, Owner(Nothing, 7)) = 0)

        Console.WriteLine("WISHLIST_HEADER_OWNER_TESTS=" & tests.ToString(CultureInfo.InvariantCulture))
        Console.WriteLine("WISHLIST_HEADER_OWNER_FAILURES=" & failures.ToString(CultureInfo.InvariantCulture))
        If failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
