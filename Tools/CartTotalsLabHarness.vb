Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Diagnostics
Imports System.Globalization
Imports System.Text
Imports System.Web
Imports MySql.Data.MySqlClient

' KS WEB-TOTALS-CART-READ-1A: prova del servizio App_Code\CartTotalsService.vb contro la routine REALE Carrello_Totali
' del database LAB LOCALE (127.0.0.1:13317, schema sintetico), con il connettore del sito (MySql.Data 8.0.33).
' Ogni caso gira in una transazione annullata (nessun commit): guardia di identita, fixture nel carrello, chiamata
' del servizio, confronto con un oracolo indipendente in aritmetica Decimal (half away from zero, una sola volta).
' La password arriva SOLO dalla variabile di ambiente del processo figlio (KS_LAB_PWD): mai in argv o output.
' Mai su produzione. Compilato e lanciato da Tools\Test-CartTotalsDbRead.ps1 -Lab.

Public Module KeepStoreLog
    Public ReadOnly Lines As New List(Of String)()
    Public Sub [Error](ByVal category As String, ByVal message As String, ByVal ex As Exception, ByVal context As HttpContext)
        Lines.Add(category & ": " & message)
    End Sub
End Module

Public Module CartTotalsLabHarness
    Private Const LabUuid As String = "1167ebae-d0c0-11f1-b348-9c7bef540c10"
    Private Const LabSchema As String = "keepstore_regorder_lab_20261025"
    Private Const LabLogin As Long = 19832
    Private _passed As Integer
    Private _failed As Integer
    Private ReadOnly _durations As New List(Of Double)()

    Private NotInheritable Class FixtureRow
        Public Qnt As Decimal
        Public Net As Decimal
        Public RcId As Integer = -1
        Public RcVal As Decimal = -1D
        Public ExId As Integer = -1
        Public ExVal As Decimal? = -1D
    End Class

    Private NotInheritable Class TotalsCase
        Public Id As String
        Public Title As String
        Public Rows As New List(Of FixtureRow)()
        Public Ins As Decimal
        Public Ship As Decimal
        Public Pay As Decimal
        Public Rounding As Decimal
        Public Rc As Integer
        Public CarrierVat As Decimal = 22D
        Public BTot As Decimal
        Public BVal As Decimal = 22D
        Public ExpectUnavailable As Boolean
    End Class

    Private Function Row(ByVal qnt As Decimal, ByVal net As Decimal) As FixtureRow
        Return New FixtureRow() With {.Qnt = qnt, .Net = net}
    End Function

    Private Function RowExempt(ByVal qnt As Decimal, ByVal net As Decimal, ByVal rate As Decimal?) As FixtureRow
        Return New FixtureRow() With {.Qnt = qnt, .Net = net, .ExId = 702, .ExVal = rate}
    End Function

    Private Function BuildCases() As List(Of TotalsCase)
        Dim cases As New List(Of TotalsCase)()
        cases.Add(New TotalsCase() With {.Id = "C01", .Title = "ordinario 22% q2", .Rows = New List(Of FixtureRow) From {Row(2D, 10D)}})
        cases.Add(New TotalsCase() With {.Id = "C02", .Title = "forma reale 2025: 5,805 netti al 22% (totale 7,08)", .Rows = New List(Of FixtureRow) From {Row(1D, 5.805D)}})
        cases.Add(New TotalsCase() With {.Id = "C03", .Title = "forma reale 2025: 30,73262 netti + spedizione 5,33", .Rows = New List(Of FixtureRow) From {Row(1D, 30.73262D)}, .Ship = 5.33D})
        cases.Add(New TotalsCase() With {.Id = "C04", .Title = "pareggio esatto 0,125 esente: 0,13 e non 0,12", .Rows = New List(Of FixtureRow) From {RowExempt(1D, 0.125D, 0D)}})
        cases.Add(New TotalsCase() With {.Id = "C05", .Title = "aliquote miste 10,25 al 22% e 10,25 al 10% (totale 23,78)", .Rows = New List(Of FixtureRow) From {Row(1D, 10.25D), RowExempt(1D, 10.25D, 10D)}})
        cases.Add(New TotalsCase() With {.Id = "C06", .Title = "buono -3,33 con IVA 22", .Rows = New List(Of FixtureRow) From {Row(1D, 10D)}, .BTot = -3.33D})
        cases.Add(New TotalsCase() With {.Id = "C07", .Title = "assicurazione 2, spedizione 5, pagamento 0,71, arrotondamento -0,02", .Rows = New List(Of FixtureRow) From {Row(2D, 10D)}, .Ins = 2D, .Ship = 5D, .Pay = 0.71D, .Rounding = -0.02D})
        cases.Add(New TotalsCase() With {.Id = "C08", .Title = "precisione: netto 1,00409836 al 22% (totale esatto 1,2249999992 -> 1,22)", .Rows = New List(Of FixtureRow) From {Row(1D, 1.00409836D)}})
        cases.Add(New TotalsCase() With {.Id = "C09", .Title = "reverse charge: IVA di riga 0", .Rows = New List(Of FixtureRow) From {New FixtureRow() With {.Qnt = 2D, .Net = 10D, .RcId = 701, .RcVal = 0D}}, .Rc = 1})
        cases.Add(New TotalsCase() With {.Id = "C10", .Title = "carrello vuoto con spedizione 5 e buono -1 (4,88)", .Ship = 5D, .BTot = -1D})
        cases.Add(New TotalsCase() With {.Id = "C11", .Title = "aliquota di snapshot NULL: la routine da NULL, il servizio NON inventa un valore", .Rows = New List(Of FixtureRow) From {RowExempt(1D, 0D, Nothing)}, .ExpectUnavailable = True})
        cases.Add(New TotalsCase() With {.Id = "C12", .Title = "importo grande 1234567,12345 al 22%", .Rows = New List(Of FixtureRow) From {Row(1D, 1234567.12345D)}})
        cases.Add(New TotalsCase() With {.Id = "C13", .Title = "aliquota vettore 10 su spedizione 4,10 e assicurazione 1,50", .Rows = New List(Of FixtureRow) From {Row(3D, 6.556D)}, .Ship = 4.1D, .Ins = 1.5D, .CarrierVat = 10D})
        Return cases
    End Function

    Private Function Rate(ByVal c As TotalsCase, ByVal r As FixtureRow) As Decimal?
        If c.Rc = 1 AndAlso r.RcId > -1 Then Return r.RcVal
        If r.ExId > -1 Then Return r.ExVal
        Return 22D
    End Function

    ' Oracolo indipendente: somme esatte in Decimal, arrotondamento UNA sola volta (half away from zero).
    Private Function Oracle(ByVal c As TotalsCase, ByRef merce As Decimal, ByRef iva As Decimal, ByRef totale As Decimal) As Boolean
        Dim imp As Decimal = 0D
        Dim ivaRows As Decimal = 0D
        For Each r As FixtureRow In c.Rows
            Dim rt As Decimal? = Rate(c, r)
            Dim line As Decimal = r.Qnt * r.Net
            imp += line
            If Not rt.HasValue Then Return False
            ivaRows += line * rt.Value / 100D
        Next
        Dim ivaExact As Decimal = ivaRows + (c.Ship + c.Ins) * c.CarrierVat / 100D
        Dim couponIva As Decimal = c.BTot * c.BVal / 100D
        Dim totExact As Decimal = imp + ivaExact + couponIva + c.Ship + c.Ins + c.Pay + c.Rounding + c.BTot
        merce = Math.Round(imp, 2, MidpointRounding.AwayFromZero)
        iva = Math.Round(ivaExact + couponIva, 2, MidpointRounding.AwayFromZero)
        totale = Math.Round(totExact, 2, MidpointRounding.AwayFromZero)
        Return True
    End Function

    Private Function Num(ByVal value As Decimal?) As String
        If Not value.HasValue Then Return "NULL"
        Return value.Value.ToString(CultureInfo.InvariantCulture)
    End Function

    Private Sub Check(ByVal ok As Boolean, ByVal name As String, Optional ByVal detail As String = "")
        If ok Then
            _passed += 1
            Console.WriteLine("PASS " & name)
        Else
            _failed += 1
            Console.WriteLine("FAIL " & name & If(detail = "", "", " :: " & detail))
        End If
    End Sub

    Private Function Scalar(ByVal connection As MySqlConnection, ByVal sql As String) As Object
        Using command As New MySqlCommand(sql, connection)
            Return command.ExecuteScalar()
        End Using
    End Function

    Private Sub Execute(ByVal connection As MySqlConnection, ByVal transaction As MySqlTransaction, ByVal sql As String)
        Using command As New MySqlCommand(sql, connection, transaction)
            command.ExecuteNonQuery()
        End Using
    End Sub

    Private Sub RunMode(ByVal baseConnectionString As String, ByVal checkParameters As Boolean)
        Dim modeName As String = "CheckParameters=" & checkParameters.ToString()
        Dim builder As New MySqlConnectionStringBuilder(baseConnectionString)
        builder.CheckParameters = checkParameters
        Using connection As New MySqlConnection(builder.ConnectionString)
            connection.Open()
            Check(Convert.ToString(Scalar(connection, "SELECT @@server_uuid")) = LabUuid AndAlso
                  Convert.ToInt32(Scalar(connection, "SELECT @@port")) = 13317 AndAlso
                  Convert.ToString(Scalar(connection, "SELECT DATABASE()")) = LabSchema,
                  modeName & " guardia: identita del LAB (UUID, porta, schema)")
            Check(Convert.ToInt32(Scalar(connection, "SELECT COUNT(*) FROM carrello")) = 0, modeName & " guardia: carrello vuoto prima")

            For Each c As TotalsCase In BuildCases()
                Dim transaction As MySqlTransaction = connection.BeginTransaction()
                Try
                    Dim index As Integer = 0
                    For Each r As FixtureRow In c.Rows
                        index += 1
                        Dim gross As Decimal = r.Net * 1.22D
                        Execute(connection, transaction,
                            "INSERT INTO carrello(LoginId,ArticoliId,TCId,Codice,Descrizione1,Qnt,NListino,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva) VALUES(" &
                            LabLogin.ToString(CultureInfo.InvariantCulture) & ",1,-1,'KS-LAB-ARTICLE','KS HARNESS " & c.Id & "'," &
                            Num(r.Qnt) & ",1," & Num(r.Net) & "," & Num(gross) & "," & r.RcId.ToString(CultureInfo.InvariantCulture) & "," & Num(r.RcVal) &
                            ",'KS HARNESS RC'," & r.ExId.ToString(CultureInfo.InvariantCulture) & "," & Num(r.ExVal) & ",'KS HARNESS EX')")
                    Next
                    Dim input As CartTotalsInput = CartTotalsInput.ForOrder(LabLogin, c.Ins, c.Ship, c.Pay, c.Rounding, c.Rc, c.CarrierVat, c.BTot, c.BVal, False)
                    Dim result As CartTotalsResult = Nothing
                    Dim watch As Stopwatch = Stopwatch.StartNew()
                    Dim ok As Boolean = CartTotalsService.TryCompute(connection, transaction, input, result, Nothing)
                    watch.Stop()
                    _durations.Add(watch.Elapsed.TotalMilliseconds)
                    If c.ExpectUnavailable Then
                        Check(Not ok AndAlso result Is Nothing, modeName & " " & c.Id & " " & c.Title & ": servizio non disponibile e nessun risultato inventato")
                    Else
                        Dim m As Decimal, i As Decimal, t As Decimal
                        Dim hasOracle As Boolean = Oracle(c, m, i, t)
                        Check(hasOracle AndAlso ok AndAlso result IsNot Nothing, modeName & " " & c.Id & " " & c.Title & ": servizio disponibile")
                        If ok AndAlso result IsNot Nothing AndAlso hasOracle Then
                            Check(result.Merce = m, modeName & " " & c.Id & " merce", "servizio=" & result.Merce.ToString(CultureInfo.InvariantCulture) & " oracolo=" & m.ToString(CultureInfo.InvariantCulture))
                            Check(result.Iva = i, modeName & " " & c.Id & " IVA", "servizio=" & result.Iva.ToString(CultureInfo.InvariantCulture) & " oracolo=" & i.ToString(CultureInfo.InvariantCulture))
                            Check(result.Totale = t, modeName & " " & c.Id & " totale", "servizio=" & result.Totale.ToString(CultureInfo.InvariantCulture) & " oracolo=" & t.ToString(CultureInfo.InvariantCulture))
                        End If
                    End If
                Finally
                    transaction.Rollback()
                    transaction.Dispose()
                End Try
            Next
            Check(Convert.ToInt32(Scalar(connection, "SELECT COUNT(*) FROM carrello")) = 0, modeName & " stato: carrello vuoto dopo (nessun commit)")
        End Using
    End Sub

    Private Sub RunFailureCases(ByVal baseConnectionString As String)
        Dim built As String = CartTotalsService.BuildConnectionString(baseConnectionString)
        Check(built.IndexOf("CheckParameters=False", StringComparison.OrdinalIgnoreCase) >= 0 OrElse built.IndexOf("Check Parameters=False", StringComparison.OrdinalIgnoreCase) >= 0,
              "BuildConnectionString: CheckParameters spento")
        Using connection As New MySqlConnection(built)
            connection.Open()
            Dim good As CartTotalsInput = CartTotalsInput.ForOrder(LabLogin, 0D, 5D, 0D, 0D, 0, 22D, -1D, 22D, False)
            Dim result As CartTotalsResult = Nothing
            Check(Not CartTotalsService.TryCompute(connection, Nothing, CartTotalsInput.ForOrder(0, 0D, 5D, 0D, 0D, 0, 22D, -1D, 22D, False), result, Nothing) AndAlso result Is Nothing,
                  "LoginId 0: nessuna chiamata, nessun risultato")
            Check(Not CartTotalsService.TryCompute(connection, Nothing, Nothing, result, Nothing) AndAlso result Is Nothing, "input Nothing: nessun risultato")
            Dim before As Integer = KeepStoreLog.Lines.Count
            Check(Not CartTotalsService.TryComputeNamed(connection, Nothing, good, "Carrello_Totali_Inesistente", result, Nothing) AndAlso result Is Nothing,
                  "routine inesistente: nessun risultato (nessun ripiego sul web)")
            Check(KeepStoreLog.Lines.Count = before + 1 AndAlso KeepStoreLog.Lines(KeepStoreLog.Lines.Count - 1).StartsWith("cart-totals: Cart totals read failed. Error type: ", StringComparison.Ordinal),
                  "routine inesistente: un solo errore registrato, sanitizzato", String.Join(" | ", KeepStoreLog.Lines))
            Dim logged As String = String.Join(" ", KeepStoreLog.Lines)
            Check(logged.IndexOf("Carrello_Totali_Inesistente", StringComparison.Ordinal) < 0 AndAlso logged.IndexOf("19832", StringComparison.Ordinal) < 0,
                  "errore registrato: niente nome di routine ne valori")
        End Using
        Dim closed As New MySqlConnection(built)
        Dim res2 As CartTotalsResult = Nothing
        Check(Not CartTotalsService.TryCompute(closed, Nothing, CartTotalsInput.ForOrder(LabLogin, 0D, 5D, 0D, 0D, 0, 22D, 0D, 22D, False), res2, Nothing) AndAlso res2 Is Nothing,
              "connessione chiusa: nessun risultato")
        closed.Dispose()
    End Sub

    Private Sub RunNormalizationCases()
        Dim couponOrder As CartTotalsInput = CartTotalsInput.ForOrder(1, 2D, 5D, 0.71D, -0.02D, 1, 22D, -5D, 22D, True)
        Check(couponOrder.InsuranceCost = 0D AndAlso couponOrder.ShippingCost = 0D AndAlso couponOrder.PaymentCost = 0D, "coupon-articolo: assicurazione, spedizione e pagamento azzerati come nell'ordine")
        Check(couponOrder.Rounding = -0.02D AndAlso couponOrder.ReverseCharge = 1 AndAlso couponOrder.CarrierVat = 22D AndAlso couponOrder.CouponTaxable = -5D AndAlso couponOrder.CouponVatValue = 22D,
              "coupon-articolo: arrotondamento, reverse charge, IVA vettore e buono passati invariati")
        Dim normal As CartTotalsInput = CartTotalsInput.ForOrder(1, 2D, 5D, 0.71D, -0.02D, 0, 22D, 0D, 0D, False)
        Check(normal.InsuranceCost = 2D AndAlso normal.ShippingCost = 5D AndAlso normal.PaymentCost = 0.71D, "ordine normale: costi invariati")
    End Sub

    ' MySql.Data 8.0.33 chiede BouncyCastle.Crypto 1.9.0.0; in Bin c'e solo BouncyCastle.Cryptography 2.x (per MailKit).
    ' Solo per questo harness, e solo per il percorso TLS verso il LAB, la richiesta viene girata sull'assembly presente.
    Private Function ResolveBouncyCastle(ByVal sender As Object, ByVal args As ResolveEventArgs) As System.Reflection.Assembly
        If args.Name.StartsWith("BouncyCastle.Crypto,", StringComparison.OrdinalIgnoreCase) Then
            Dim candidate As String = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "BouncyCastle.Cryptography.dll")
            If System.IO.File.Exists(candidate) Then Return System.Reflection.Assembly.LoadFrom(candidate)
        End If
        Return Nothing
    End Function

    Public Function Main() As Integer
        AddHandler AppDomain.CurrentDomain.AssemblyResolve, AddressOf ResolveBouncyCastle
        Try
            Dim password As String = Environment.GetEnvironmentVariable("KS_LAB_PWD")
            Dim user As String = Environment.GetEnvironmentVariable("KS_LAB_USER")
            Dim ca As String = Environment.GetEnvironmentVariable("KS_LAB_CA")
            If String.IsNullOrEmpty(password) OrElse String.IsNullOrEmpty(user) OrElse String.IsNullOrEmpty(ca) Then
                Console.WriteLine("MISSING_ENVIRONMENT (KS_LAB_USER, KS_LAB_PWD, KS_LAB_CA)")
                Return 2
            End If
            Dim csb As New MySqlConnectionStringBuilder()
            csb.Server = "127.0.0.1"
            csb.Port = 13317UI
            csb.Database = LabSchema
            csb.UserID = user
            ' Il segreto entra nel builder solo a runtime, dall'ambiente del processo figlio; nessun valore e scritto nel file.
            csb("Password") = password
            ' Il LAB impone il trasporto cifrato (require_secure_transport). La verifica della CA del connettore (VerifyCA) carica
            ' BouncyCastle.Crypto 1.9.0, assente in Bin (c'e solo BouncyCastle.Cryptography 2.x per MailKit): su questo loopback
            ' locale l'harness usa TLS 1.2 cifrato SENZA verifica della CA. Gli altri strumenti del LAB (mysql.exe) verificano la CA.
            csb.SslMode = MySqlSslMode.Required
            csb.TlsVersion = "Tls12"
            csb.ConnectionTimeout = 8UI
            csb.DefaultCommandTimeout = 30UI
            Dim baseCs As String = csb.ConnectionString

            RunNormalizationCases()
            RunMode(baseCs, False)
            RunMode(baseCs, True)
            RunFailureCases(baseCs)

            If _durations.Count > 0 Then
                Dim sum As Double = 0
                Dim max As Double = 0
                For Each d As Double In _durations
                    sum += d
                    If d > max Then max = d
                Next
                Console.WriteLine("DURATA chiamate (LAB locale, carrelli sintetici di 0-2 righe, solo in-process): n=" & _durations.Count.ToString(CultureInfo.InvariantCulture) &
                                  " media=" & (sum / _durations.Count).ToString("0.0", CultureInfo.InvariantCulture) & " ms max=" & max.ToString("0.0", CultureInfo.InvariantCulture) & " ms")
            End If
            Console.WriteLine("CART_TOTALS_CHECKS=" & (_passed + _failed).ToString(CultureInfo.InvariantCulture) & " PASS=" & _passed.ToString(CultureInfo.InvariantCulture) & " FAIL=" & _failed.ToString(CultureInfo.InvariantCulture))
            Return If(_failed = 0, 0, 1)
        Catch ex As Exception
            Console.WriteLine("HARNESS_ERROR " & ex.GetType().Name & ": " & ex.Message.Replace(Environment.NewLine, " "))
            If Not String.IsNullOrEmpty(ex.StackTrace) Then
                Dim frames As String() = ex.StackTrace.Split(New String() {Environment.NewLine}, StringSplitOptions.RemoveEmptyEntries)
                For index As Integer = 0 To Math.Min(frames.Length, 12) - 1
                    Console.WriteLine("  " & frames(index).Trim())
                Next
            End If
            Return 3
        End Try
    End Function
End Module
