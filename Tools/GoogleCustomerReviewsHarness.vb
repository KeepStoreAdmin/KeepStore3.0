Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Threading

' GCR-OPTIN-1A. Prova unitaria dello snippet di attivazione di Recensioni dei clienti su Google, della CSP e del marcatore di sessione
' (App_Code\KeepStoreContentSecurityPolicy.vb e App_Code\KeepStoreGoogleCustomerReviews.vb, compilati con questo file da Tools\Test-GoogleCustomerReviewsOptIn.ps1).
' Gli attesi sono scritti a mano, non derivati dal codice. Stampa "ok <nome>" o "FAIL <nome>"; esce con 1 se un caso fallisce.
Public Module GoogleCustomerReviewsHarness
    Private failures As Integer = 0

    Private Sub Check(ByVal ok As Boolean, ByVal name As String)
        If ok Then
            Console.WriteLine("ok " & name)
        Else
            failures += 1
            Console.WriteLine("FAIL " & name)
        End If
    End Sub

    Private Function CountOf(ByVal text As String, ByVal part As String) As Integer
        Dim n As Integer = 0
        Dim i As Integer = text.IndexOf(part, StringComparison.Ordinal)
        While i >= 0
            n += 1
            i = text.IndexOf(part, i + part.Length, StringComparison.Ordinal)
        End While
        Return n
    End Function

    Private Function Directives(ByVal policy As String) As List(Of String)
        Dim result As New List(Of String)()
        For Each part As String In policy.Split(";"c)
            Dim d As String = part.Trim()
            If d.Length > 0 Then result.Add(d)
        Next
        Return result
    End Function

    Private Function SourcesOf(ByVal policy As String, ByVal name As String) As List(Of String)
        Dim result As New List(Of String)()
        For Each d As String In Directives(policy)
            If d.StartsWith(name & " ", StringComparison.Ordinal) Then
                For Each s As String In d.Substring(name.Length + 1).Split(" "c)
                    If s.Length > 0 Then result.Add(s)
                Next
            End If
        Next
        Return result
    End Function

    Public Function Main() As Integer
        ' --- CSP ---
        Dim strictWanted As String = "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; img-src 'self' data: blob:; media-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' *; frame-ancestors 'self';"
        Dim relaxedWanted As String = strictWanted & " script-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: https://apis.google.com; frame-src 'self' data: blob: https://www.google.com;"
        Check(KeepStoreContentSecurityPolicy.Strict() = strictWanted, "csp stretta: identica byte per byte a quella in uso")
        Check(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews() = relaxedWanted, "csp per l'attivazione: testo esatto")
        Dim strictDirs As List(Of String) = Directives(strictWanted)
        Dim relaxedDirs As List(Of String) = Directives(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews())
        Dim others As New List(Of String)()
        For Each d As String In relaxedDirs
            If Not d.StartsWith("script-src ", StringComparison.Ordinal) AndAlso Not d.StartsWith("frame-src ", StringComparison.Ordinal) Then others.Add(d)
        Next
        Dim sameOthers As Boolean = (others.Count = strictDirs.Count)
        If sameOthers Then
            For i As Integer = 0 To others.Count - 1
                If others(i) <> strictDirs(i) Then sameOthers = False
            Next
        End If
        Check(sameOthers, "csp per l'attivazione: le altre direttive sono identiche")
        Dim defaults As List(Of String) = SourcesOf(strictWanted, "default-src")
        Dim scripts As List(Of String) = SourcesOf(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews(), "script-src")
        Dim frames As List(Of String) = SourcesOf(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews(), "frame-src")
        Dim scriptsKeep As Boolean = True
        For Each s As String In defaults
            If Not scripts.Contains(s) Then scriptsKeep = False
        Next
        Check(scriptsKeep, "csp: script-src conserva tutte le fonti di default-src (self, inline, eval, data, blob)")
        Check(frames.Contains("'self'") AndAlso frames.Contains("data:") AndAlso frames.Contains("blob:"), "csp: frame-src conserva self, data e blob")
        Check(scripts.Count = defaults.Count + 1 AndAlso scripts.Contains("https://apis.google.com"), "csp: a script-src si aggiunge SOLO apis.google.com")
        Check(frames.Count = 4 AndAlso frames.Contains("https://www.google.com"), "csp: a frame-src si aggiunge SOLO www.google.com")
        Check(CountOf(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews(), "script-src ") = 1 AndAlso CountOf(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews(), "frame-src ") = 1 AndAlso
              CountOf(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews(), "frame-ancestors 'self'") = 1, "csp: una sola direttiva script-src, frame-src e frame-ancestors")
        Check(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews().IndexOf("https:", StringComparison.Ordinal) = KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews().IndexOf("https://apis.google.com", StringComparison.Ordinal) AndAlso
              CountOf(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews(), "https:") = 2 AndAlso CountOf(KeepStoreContentSecurityPolicy.WithGoogleCustomerReviews(), "*") = 1, "csp: nessun jolly nuovo")

        ' --- snippet ---
        Dim qd As String = ChrW(34)
        Dim day As New DateTime(2026, 12, 5)
        Dim okScript As String = KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "o'brien@example.it", "IT", day)
        Check(okScript.Length > 0, "snippet: valori validi (ID Merchant a 10 cifre oltre Int32)")
        Check(okScript.Contains("<script src=" & qd & "https://apis.google.com/js/platform.js?onload=renderOptIn" & qd & " async defer></script>"), "snippet: script ufficiale di Google")
        Check(okScript.Contains(qd & "merchant_id" & qd & ": " & qd & "5522591374" & qd), "snippet: merchant_id come stringa intera")
        Check(okScript.Contains(qd & "order_id" & qd & ": " & qd & "123" & qd), "snippet: order_id")
        Check(okScript.Contains(qd & "delivery_country" & qd & ": " & qd & "IT" & qd) AndAlso okScript.Contains(qd & "estimated_delivery_date" & qd & ": " & qd & "2026-12-05" & qd), "snippet: paese e data")
        Check(okScript.Contains("o" & ChrW(92) & "u0027brien@example.it") AndAlso Not okScript.Contains("o'brien"),"snippet: l'apostrofo dell'e-mail e codificato per JavaScript")
        Check(CountOf(okScript, "<script") = 2 AndAlso CountOf(okScript, "</script>") = 2, "snippet: due soli script, nessuna chiusura anticipata")
        Check(KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a</script><script>x()</script>@b.it", "IT", day) = "", "snippet: e-mail con tag rifiutata")
        Check(KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a" & qd & "b@example.it", "IT", day) = "", "snippet: e-mail con virgolette rifiutata")
        Check(KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a b@example.it", "IT", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b", "IT", day) = "" AndAlso
              KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "", "IT", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, Nothing, "IT", day) = "", "snippet: e-mail non valide o vuote")
        Check(KeepStoreGoogleCustomerReviews.BuildOptInScript("abc", 123, "a@b.it", "IT", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("", 123, "a@b.it", "IT", day) = "" AndAlso
              KeepStoreGoogleCustomerReviews.BuildOptInScript("12 3", 123, "a@b.it", "IT", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("123456789012345678901", 123, "a@b.it", "IT", day) = "" AndAlso
              KeepStoreGoogleCustomerReviews.BuildOptInScript(Nothing, 123, "a@b.it", "IT", day) = "", "snippet: ID Merchant non numerico, vuoto o oltre 20 cifre rifiutato")
        Check(KeepStoreGoogleCustomerReviews.BuildOptInScript("123" & vbLf, 123, "a@b.it", "IT", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it", "IT" & vbLf, day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it" & vbLf, "IT", day) = "", "snippet: un a-capo finale non passa i controlli")
        Check(KeepStoreGoogleCustomerReviews.BuildOptInScript("1", 123, "a@b.it", "IT", day).Length > 0 AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("12345678901234567890", 123, "a@b.it", "IT", day).Length > 0, "snippet: ID da 1 a 20 cifre accettato")
        Check(KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it", "ZZ", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it", "it", day) = "" AndAlso
              KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it", "ITA", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it", "", day) = "" AndAlso
              KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it", "I1", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it", Nothing, day) = "", "snippet: paese ZZ, minuscolo, a 3 lettere, con cifre o assente rifiutato")
        Check(KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 0, "a@b.it", "IT", day) = "" AndAlso KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", -5, "a@b.it", "IT", day) = "", "snippet: documento senza numero rifiutato")
        Dim savedCulture As CultureInfo = Thread.CurrentThread.CurrentCulture
        Try
            Thread.CurrentThread.CurrentCulture = New CultureInfo("ar-SA")
            Dim arScript As String = KeepStoreGoogleCustomerReviews.BuildOptInScript("5522591374", 123, "a@b.it", "IT", day)
            Check(arScript.Contains(qd & "estimated_delivery_date" & qd & ": " & qd & "2026-12-05" & qd) AndAlso arScript.Contains(qd & "order_id" & qd & ": " & qd & "123" & qd), "snippet: data e numeri indipendenti dalla cultura del server")
        Finally
            Thread.CurrentThread.CurrentCulture = savedCulture
        End Try
        Check(KeepStoreGoogleCustomerReviews.EstimatedDeliveryDate(New DateTime(2026, 12, 28)) = New DateTime(2027, 1, 2), "consegna stimata: documento piu 5 giorni (cambio d'anno)")

        ' --- marcatore ---
        Check(KeepStoreGoogleCustomerReviews.PendingKey(1, 77, 123) = "1:77:123", "marcatore: chiave azienda:utente:documento")
        Check(KeepStoreGoogleCustomerReviews.PendingKey(0, 77, 123) = "" AndAlso KeepStoreGoogleCustomerReviews.PendingKey(1, 0, 123) = "" AndAlso KeepStoreGoogleCustomerReviews.PendingKey(1, 77, 0) = "", "marcatore: chiave vuota se manca un pezzo")
        Dim p As String = KeepStoreGoogleCustomerReviews.PendingAdd("", "1:77:10")
        p = KeepStoreGoogleCustomerReviews.PendingAdd(p, "1:77:20")
        Check(KeepStoreGoogleCustomerReviews.PendingContains(p, "1:77:10") AndAlso KeepStoreGoogleCustomerReviews.PendingContains(p, "1:77:20"), "marcatore: due documenti insieme")
        Check(Not KeepStoreGoogleCustomerReviews.PendingContains(p, "1:77:1") AndAlso Not KeepStoreGoogleCustomerReviews.PendingContains(p, "2:77:10") AndAlso Not KeepStoreGoogleCustomerReviews.PendingContains(p, "1:78:10"), "marcatore: nessuna corrispondenza parziale ne di altra azienda o utente")
        p = KeepStoreGoogleCustomerReviews.PendingRemove(p, "1:77:10")
        Check(Not KeepStoreGoogleCustomerReviews.PendingContains(p, "1:77:10") AndAlso KeepStoreGoogleCustomerReviews.PendingContains(p, "1:77:20"), "marcatore: si toglie solo quel documento (A, B, poi A di nuovo)")
        p = KeepStoreGoogleCustomerReviews.PendingAdd(p, "1:77:20")
        Check(p = "1:77:20", "marcatore: lo stesso documento non si duplica")
        Dim big As String = ""
        For i As Integer = 1 To 25
            big = KeepStoreGoogleCustomerReviews.PendingAdd(big, "1:7:" & i.ToString(CultureInfo.InvariantCulture))
        Next
        Check(big.Split(","c).Length = 20 AndAlso Not KeepStoreGoogleCustomerReviews.PendingContains(big, "1:7:5") AndAlso KeepStoreGoogleCustomerReviews.PendingContains(big, "1:7:6") AndAlso KeepStoreGoogleCustomerReviews.PendingContains(big, "1:7:25"), "marcatore: al massimo 20, si perdono i piu vecchi")
        Check(KeepStoreGoogleCustomerReviews.PendingAdd("1:7:1", "") = "1:7:1" AndAlso KeepStoreGoogleCustomerReviews.PendingRemove("", "1:7:1") = "" AndAlso Not KeepStoreGoogleCustomerReviews.PendingContains(Nothing, "1:7:1") AndAlso Not KeepStoreGoogleCustomerReviews.PendingContains("1:7:1", ""), "marcatore: valori vuoti non fanno danni")

        Console.WriteLine("failures=" & failures.ToString(CultureInfo.InvariantCulture))
        Return If(failures = 0, 0, 1)
    End Function
End Module
