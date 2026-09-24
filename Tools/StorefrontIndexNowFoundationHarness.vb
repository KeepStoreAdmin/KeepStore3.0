Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Collections.Specialized
Imports System.IO
Imports System.Text

Module StorefrontIndexNowFoundationHarness
    Private _checks As Integer
    Private _failures As Integer

    Private Sub Check(ByVal name As String, ByVal condition As Boolean)
        _checks += 1
        If Not condition Then
            _failures += 1
            Console.Error.WriteLine("FAIL " & name)
        End If
    End Sub

    Private Function Candidate(ByVal tenant As StorefrontSeoTenantIdentity,
                               ByVal productId As Integer, ByVal letter As Char) As IndexNowCandidate
        Dim result As IndexNowCandidate = Nothing
        Dim url As String = StorefrontCanonicalHostPolicy.BuildCanonicalUrl(tenant, "/articolo.aspx?id=" & productId.ToString())
        Check("fixture candidate", StorefrontIndexNowFoundation.TryCreateCandidate(tenant, url, New String(letter, 64), True, result))
        Return result
    End Function

    Private Function Read(ByVal store As StorefrontIndexNowFoundation,
                          ByVal tenant As StorefrontSeoTenantIdentity) As IndexNowStateDocument
        Dim value As IndexNowStateDocument = Nothing
        Dim errorCode As String = Nothing
        Check("read state", store.TryReadState(tenant, value, errorCode))
        Return value
    End Function

    Private Sub Reconcile(ByVal store As StorefrontIndexNowFoundation,
                          ByVal tenant As StorefrontSeoTenantIdentity,
                          ByVal ParamArray candidates() As IndexNowCandidate)
        Dim count As Integer = -1
        Dim errorCode As String = Nothing
        Check("reconcile", store.TryReconcile(tenant, candidates, count, errorCode))
    End Sub

    Private Sub Ack(ByVal store As StorefrontIndexNowFoundation,
                    ByVal tenant As StorefrontSeoTenantIdentity,
                    ByVal pending As IndexNowPendingChange)
        Dim didAck As Boolean = False
        Dim errorCode As String = Nothing
        Check("ack", store.TryAcknowledge(tenant, pending.Url, pending.Revision, didAck, errorCode) AndAlso didAck)
    End Sub

    Sub Main()
        Dim root As String = Path.Combine(Path.GetTempPath(), "KeepStore-IndexNow-" & Guid.NewGuid().ToString("N"))
        Dim tenantA As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.CreateTenant(11, "A", "", "https://a.example.test", "", "", 1)
        Dim tenantB As StorefrontSeoTenantIdentity = StorefrontCanonicalHostPolicy.CreateTenant(22, "B", "", "https://b.example.test", "", "", 2)
        Try
            Dim config As New NameValueCollection()
            config("KeepStore.IndexNow.Enabled.a.example.test") = "true"
            config("KeepStore.IndexNow.Key.a.example.test") = "Abcd1234"
            config("KeepStore.IndexNow.KeyLocation.a.example.test") = "https://a.example.test/Abcd1234.txt"
            Dim loadedA As IndexNowHostConfiguration = StorefrontIndexNowFoundation.ResolveConfiguration(tenantA, config)
            Dim loadedB As IndexNowHostConfiguration = StorefrontIndexNowFoundation.ResolveConfiguration(tenantB, config)
            Check("tenant A key ready", loadedA.Status = IndexNowConfigurationStatus.Ready)
            Check("tenant B key invisible", loadedB.Status = IndexNowConfigurationStatus.NotConfigured AndAlso loadedB.Key Is Nothing)
            config("KeepStore.IndexNow.Key.a.example.test") = "invalid key"
            Check("invalid key", StorefrontIndexNowFoundation.ResolveConfiguration(tenantA, config).Status = IndexNowConfigurationStatus.Invalid)
            config("KeepStore.IndexNow.Key.a.example.test") = "Abcd1234"
            config("KeepStore.IndexNow.KeyLocation.a.example.test") = "https://b.example.test/Abcd1234.txt"
            Check("cross-host keyLocation", StorefrontIndexNowFoundation.ResolveConfiguration(tenantA, config).Status = IndexNowConfigurationStatus.Invalid)
            config("KeepStore.IndexNow.KeyLocation.a.example.test") = "http://a.example.test/Abcd1234.txt"
            Check("HTTP keyLocation", StorefrontIndexNowFoundation.ResolveConfiguration(tenantA, config).Status = IndexNowConfigurationStatus.Invalid)

            Dim good As IndexNowCandidate = Candidate(tenantA, 42, "a"c)
            Dim rejected As IndexNowCandidate = Nothing
            Check("cross-host URL", Not StorefrontIndexNowFoundation.TryCreateCandidate(tenantA, "https://b.example.test/articolo.aspx?id=42", good.Fingerprint, True, rejected))
            Check("noindex rejected", Not StorefrontIndexNowFoundation.TryCreateCandidate(tenantA, good.Url, good.Fingerprint, False, rejected))
            Check("cart globally noindex", Not StorefrontIndexNowFoundation.TryCreateCandidate(tenantA, "https://a.example.test/carrello.aspx", good.Fingerprint, True, rejected))

            Dim store As New StorefrontIndexNowFoundation(root)
            Dim other As IndexNowCandidate = Candidate(tenantB, 42, "a"c)
            Reconcile(store, tenantA, good)
            Check("Added", Read(store, tenantA).Pending(good.Url).Operation = "Added")
            Check("baseline not advanced", Read(store, tenantA).Baseline.Count = 0)
            Check("tenant B isolated", Read(store, tenantB).Pending.Count = 0)
            Check("host files separated", Not String.Equals(store.StateFilePath(tenantA), store.StateFilePath(tenantB), StringComparison.Ordinal))
            Check("no host in filename", Not store.StateFilePath(tenantA).Contains(tenantA.CanonicalHost))
            Ack(store, tenantA, Read(store, tenantA).Pending(good.Url))
            Check("Added ack baseline", Read(store, tenantA).Baseline(good.Url) = good.Fingerprint)
            Reconcile(store, tenantA, good)
            Check("Unchanged", Read(store, tenantA).Pending.Count = 0)

            Dim changedB As IndexNowCandidate = Candidate(tenantA, 42, "b"c)
            Reconcile(store, tenantA, changedB)
            Dim oldRevision As String = Read(store, tenantA).Pending(good.Url).Revision
            Check("Updated", Read(store, tenantA).Pending(good.Url).Operation = "Updated")
            Reconcile(store, tenantA, changedB)
            Check("dedup pending", Read(store, tenantA).Pending(good.Url).Revision = oldRevision)
            Dim changedC As IndexNowCandidate = Candidate(tenantA, 42, "c"c)
            Reconcile(store, tenantA, changedC)
            Dim nowState As IndexNowStateDocument = Read(store, tenantA)
            Check("change-before-ack C pending", nowState.Pending(good.Url).TargetFingerprint = changedC.Fingerprint AndAlso nowState.Pending(good.Url).Revision <> oldRevision)
            Dim staleAck As Boolean = True
            Dim errorCode As String = Nothing
            Check("stale ack call", store.TryAcknowledge(tenantA, good.Url, oldRevision, staleAck, errorCode))
            Check("stale ACK retains latest", Not staleAck AndAlso Read(store, tenantA).Pending(good.Url).TargetFingerprint = changedC.Fingerprint)
            Check("stale ACK retains baseline", Read(store, tenantA).Baseline(good.Url) = good.Fingerprint)
            Ack(store, tenantA, Read(store, tenantA).Pending(good.Url))
            Check("latest ack", Read(store, tenantA).Baseline(good.Url) = changedC.Fingerprint)

            Reconcile(store, tenantA)
            Check("Deleted", Read(store, tenantA).Pending(good.Url).Operation = "Deleted")
            Ack(store, tenantA, Read(store, tenantA).Pending(good.Url))
            Check("Deleted ack removes baseline", Read(store, tenantA).Baseline.Count = 0)

            Reconcile(store, tenantA, good)
            Reconcile(store, tenantB, other)
            Check("same product both tenants pending", Read(store, tenantA).Pending.Count = 1 AndAlso Read(store, tenantB).Pending.Count = 1)
            Ack(store, tenantA, Read(store, tenantA).Pending(good.Url))
            Ack(store, tenantB, Read(store, tenantB).Pending(other.Url))
            Reconcile(store, tenantA, changedB)
            Reconcile(store, tenantB, other)
            Check("A-only offer delta", Read(store, tenantA).Pending.Count = 1 AndAlso Read(store, tenantB).Pending.Count = 0)
            Ack(store, tenantA, Read(store, tenantA).Pending(good.Url))
            Dim changedOther As IndexNowCandidate = Candidate(tenantB, 42, "d"c)
            Reconcile(store, tenantA, changedB)
            Reconcile(store, tenantB, changedOther)
            Check("B-only offer delta", Read(store, tenantA).Pending.Count = 0 AndAlso Read(store, tenantB).Pending.Count = 1)

            Dim restarted As New StorefrontIndexNowFoundation(root)
            Check("restart/load", Read(restarted, tenantB).Pending.Count = 1)
            Dim textState As String = File.ReadAllText(store.StateFilePath(tenantA), Encoding.UTF8)
            Check("key not serialized", Not textState.Contains("Abcd1234"))
            File.WriteAllText(store.StateFilePath(tenantA), "{broken", Encoding.UTF8)
            Dim failed As IndexNowStateDocument = Nothing
            errorCode = Nothing
            Check("corrupt fail closed", Not store.TryReadState(tenantA, failed, errorCode) AndAlso errorCode = "INDEXNOW_STATE_CORRUPT")
            Check("corrupt not overwritten", File.ReadAllText(store.StateFilePath(tenantA), Encoding.UTF8) = "{broken")
            File.WriteAllText(store.StateFilePath(tenantA), "{""Version"":999,""Host"":""a.example.test"",""Baseline"":{},""Pending"":{}}", Encoding.UTF8)
            errorCode = Nothing
            Check("unknown version fail closed", Not store.TryReadState(tenantA, failed, errorCode) AndAlso errorCode = "INDEXNOW_STATE_CORRUPT")
            Check("unknown version not overwritten", File.ReadAllText(store.StateFilePath(tenantA), Encoding.UTF8).Contains("999"))
            Check("two sequential same-host operations", Read(store, tenantB).Pending.Count = 1 AndAlso Read(store, tenantB).Baseline.Count = 1)
            Check("independent hosts after A corruption", Read(store, tenantB).Pending.Count = 1)
        Finally
            If Directory.Exists(root) Then Directory.Delete(root, True)
        End Try
        Console.WriteLine("INDEXNOW_FOUNDATION_CHECKS=" & _checks.ToString())
        Console.WriteLine("INDEXNOW_FOUNDATION_FAILURES=" & _failures.ToString())
        If _failures > 0 Then Environment.ExitCode = 1
    End Sub
End Module
