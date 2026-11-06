[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$EvidenceDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'WINDOWS_POWERSHELL_51_REQUIRED'}
$root=Split-Path -Parent $PSScriptRoot
$output=[IO.Path]::GetFullPath($EvidenceDirectory)
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
if(-not $output.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or $output.TrimEnd('\') -eq $tempBase.TrimEnd('\')){throw 'EVIDENCE_MUST_BE_SCOPED_TEMP_DIRECTORY'}
[void][IO.Directory]::CreateDirectory($output)
$work=Join-Path $output ('compiled-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$utf8=New-Object Text.UTF8Encoding($false)
# Reuse the existing, unchanged real endpoint/commercial harness. Only its TEMP
# copy gains these synthetic facts/decision cases; no new permanent VB harness.
$knowledgeCases=@'
    Private Function KnowledgeRows(ParamArray html() As String) As DataTable
        Dim table As New DataTable()
        For Each name As String In {"id", "TCid", "SettoriId", "CategorieId", "TipologieId", "GruppiId", "SottoGruppiId", "Descrizione1", "Descrizione2", "DescrizioneLunga", "DescrizioneHTML", "MarcheDescrizione"}
            table.Columns.Add(name, GetType(Object))
        Next
        For index As Integer = 0 To html.Length - 1
            table.Rows.Add(index + 1, -1, 7, 12, 3, 4, 5, "scelta", "", "", html(index), "")
        Next
        Return table
    End Function

    Private Function PairHtml(label As String, value As String) As String
        Return "<table><tbody><tr><th>" & label & "</th><td>" & value & "</td></tr></tbody></table>"
    End Function

    Private Function KnowledgeDecision(corpus As ShoppingKnowledgeCorpus, ParamArray criteria() As ShoppingCriterion) As ShoppingDecisionResult
        Return KeepStoreShoppingDecisionPolicy.Decide(corpus, criteria, New HashSet(Of String)(StringComparer.Ordinal), False, New HashSet(Of String)(StringComparer.Ordinal))
    End Function

    Private Function Criterion(attribute As ShoppingAttributeDefinition, value As String, Optional priority As String = "hard", Optional operation As String = "eq") As ShoppingCriterion
        Return New ShoppingCriterion With {.AttributeId = attribute.Id, .Operator = operation, .Value = value, .Priority = priority}
    End Function

    Private Sub KnowledgeReject(action As Action, name As String)
        Try
            action()
        Catch ex As ArgumentException
            Assert(True, name) : Return
        End Try
        Throw New Exception("EXPECTED_KNOWLEDGE_REJECTION:" & name)
    End Sub

    Private Sub RunKnowledge(outputDirectory As String)
        Dim initialAssertions As Integer = passed
        Dim timer As System.Diagnostics.Stopwatch = System.Diagnostics.Stopwatch.StartNew()
        Dim process As System.Diagnostics.Process = System.Diagnostics.Process.GetCurrentProcess()
        Dim initialCpu As TimeSpan = process.TotalProcessorTime
        Dim initialMemory As Long = GC.GetTotalMemory(True)
        Dim good As String = PairHtml("Memoria installata", "16 GB")
        Dim corpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(good), "catalog-A")
        Dim memory = corpus.Attributes.Single()
        Dim fact = corpus.Products(0).Values(memory.Id)
        Assert(fact.EvidenceStatus = "known" AndAlso fact.NumericValue.HasValue AndAlso fact.NumericValue.Value = 16D AndAlso memory.Unit = "GB", "AC01 exact HTML technical pair typed")
        Assert(fact.KeyId = 1 AndAlso fact.TCId = -1 AndAlso fact.ProductKey = "1:-1" AndAlso fact.SourceField = "DescrizioneHTML" AndAlso fact.EvidenceRef.StartsWith("e_") AndAlso fact.EvidenceText = "Memoria installata: 16 GB", "AC01 evidence source variant and quote")
        Assert(memory.CanAsk AndAlso memory.CanHardFilter AndAlso memory.Risk = "low" AndAlso memory.Scope = "7/12/3/4/5", "AC01 exact family and authored policy")
        Dim positives As String() = {good, "<dl><dt>Memoria installata</dt><dd>16 GB</dd></dl>", "<table><tr><td><strong>Memoria installata</strong></td><td>16&nbsp;GB</td></tr></table>", PairHtml("Colore del prodotto", "bl" & ChrW(&HF9)), PairHtml("Peso netto", "2,5 kg"), PairHtml("Fronte/retro automatico", "No")}
        Dim truePositive As Integer = 0
        Dim hardTruePositive As Integer = 0
        For Each html As String In positives
            Dim sample = KeepStoreShoppingKnowledge.Build(KnowledgeRows(html), "catalog-A")
            If sample.Products(0).Values.Values.Where(Function(v) v.EvidenceStatus = "known").Count() = 1 Then truePositive += 1
            If KnowledgeDecision(sample, Criterion(sample.Attributes.Single(), sample.Products(0).Values.Values.Single().Value)).Products.Count = 1 Then hardTruePositive += 1
        Next
        Assert(truePositive = positives.Length, "AC01 labelled positive extraction recall")
        Assert(hardTruePositive = positives.Length, "AC01 positively evidenced hard requirements admitted")
        Dim negative As String() = {
            "Memoria installata: 16 GB", "Non ha Memoria installata: 16 GB", PairHtml("Memoria installata", "forse 16 GB"),
            "<table><tr><td>contenitore</td><td>" & good & "</td></tr></table>",
            "<table><tr><td><dl><dt>Memoria installata</dt><dd>16 GB</dd></dl></td></tr></table>",
            "<dl><dt>contenitore</dt><dd>" & good & "</dd></dl>",
            "<table><tr><td colspan='2'>Memoria installata</td><td>16 GB</td></tr></table>",
            "<table><tr><td><div>Memoria installata</div></td><td>16 GB</td></tr></table>",
            "<table><tr><td>Memoria installata</td><td>16 GB</td><td>extra</td></tr></table>",
            "<script>" & good & "</script>", "<!--" & good & "-->", good & PairHtml("Memoria installata", "32 GB"),
            PairHtml("Memoria installata", "16 GiB"), PairHtml("Memoria massima", "16 GB"), PairHtml("Memoria installata", "16 balloons"),
            PairHtml("Memoria installata", "16 GB / 32 GB"), PairHtml("Memoria installata", "-16 GB"),
            good & "<table><tr><td>Memoria installata</td><td>32 GB</td></tr>", good & "</table>",
            good & "<dl><dt>Memoria installata</dt><dd>32 GB</dd></table>",
            "<dl><dt>Memoria installata</dt><dd>16 GB</dd><dd>32 GB</dd></dl>", New String("x"c, 17000) & good,
            PairHtml("Memoria installata", "16&nbsp;&lt;img src=x onerror=alert(1)&gt;GB"),
            PairHtml("Compatibile con", "16 GB"), PairHtml("Allergeni", "assenti"), PairHtml("Colore", "16 GB"), good & ChrW(&HD800)}
        Dim falseHard As Integer = 0
        For index As Integer = 0 To negative.Length - 1
            Dim rows = KnowledgeRows(good, negative(index))
            Dim sample = KeepStoreShoppingKnowledge.Build(rows, "catalog-A")
            Dim attribute = sample.Attributes.First(Function(a) a.Label = "Memoria installata" AndAlso a.Unit = "GB")
            Dim decision = KnowledgeDecision(sample, Criterion(attribute, "16"))
            If decision.Products.Any(Function(p) p.ProductKey = "2:-1") Then falseHard += 1
            Assert(Not decision.Products.Any(Function(p) p.ProductKey = "2:-1"), "AC02 no false hard counterexample " & index)
        Next
        Assert(falseHard = 0, "AC02 zero false hard positives in prepared counterexamples")
        Dim variantRows = KnowledgeRows(good, good)
        variantRows.Rows(1)("TCid") = 42
        Dim variantCorpus = KeepStoreShoppingKnowledge.Build(variantRows, "catalog-A")
        Dim variantAttribute = variantCorpus.Attributes.Single()
        Assert(variantCorpus.Products(1).Values(variantAttribute.Id).EvidenceStatus = "ambiguous" AndAlso variantCorpus.Products(1).ProductKey = "2:42", "AC11 article description cannot certify positive variant attributes")
        Assert(KnowledgeDecision(variantCorpus, Criterion(variantAttribute, "16")).Products.Count = 1, "AC11 positive variant hard unknown excluded without fallback")
        Assert(variantCorpus.Products(1).FreeTextEvidence.Count > 0, "AC11 parent source retained as text evidence only for variant")
        corpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(PairHtml("Fronte/retro automatico", "No"), "", PairHtml("Fronte/retro automatico", "0")), "catalog-A")
        Dim duplex = corpus.Attributes.Single()
        Assert(corpus.Products(0).Values(duplex.Id).Value = "false" AndAlso corpus.Products(0).Values(duplex.Id).EvidenceStatus = "known", "AC03 explicit false remains known false")
        Assert(corpus.Products(1).Values(duplex.Id).EvidenceStatus = "missing" AndAlso corpus.Products(1).Values(duplex.Id).Value Is Nothing AndAlso Not corpus.Products(1).Values(duplex.Id).NumericValue.HasValue, "AC03 missing is neither false nor zero")
        Assert(corpus.Products(2).Values(duplex.Id).EvidenceStatus = "ambiguous", "AC03 opaque boolean unknown")
        corpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(good & PairHtml("Memoria installata", "32 GB")), "catalog-A")
        Assert(corpus.Products(0).Values.Values.Single().EvidenceStatus = "conflicting", "AC13 contradiction explicit conflicting state")
        Dim many As New List(Of String)()
        For index As Integer = 0 To 19
            many.Add(PairHtml("Colore del prodotto", If(index < 10, "blu", "rosso")) & PairHtml("Materiale", If(index = 0, "legno", "metallo")) & PairHtml("Numero seriale", "SERIAL" & index))
        Next
        Dim balancedColor = KeepStoreShoppingKnowledge.Build(KnowledgeRows(many.ToArray()), "catalog-A")
        Dim question = KnowledgeDecision(balancedColor).Question
        Assert(question IsNot Nothing AndAlso CStr(question("attributeId")) = balancedColor.Attributes.First(Function(a) a.Label = "Colore del prodotto").Id, "AC05 twenty candidates prefer balanced useful color partition")
        many.Clear()
        For index As Integer = 0 To 19
            many.Add(PairHtml("Colore del prodotto", If(index = 0, "blu", "rosso")) & PairHtml("Materiale", If(index < 10, "legno", "metallo")) & PairHtml("Numero seriale", "SERIAL" & index))
        Next
        Dim balancedMaterial = KeepStoreShoppingKnowledge.Build(KnowledgeRows(many.ToArray()), "catalog-A")
        question = KnowledgeDecision(balancedMaterial).Question
        Assert(question IsNot Nothing AndAlso CStr(question("attributeId")) = balancedMaterial.Attributes.First(Function(a) a.Label = "Materiale").Id, "AC05 distribution changes useful question")
        Assert(Not balancedMaterial.Attributes.First(Function(a) a.Label = "Numero seriale").CanAsk, "AC06 high cardinality identifier never question")
        Dim changedRows = KnowledgeRows(PairHtml("Peso netto", "1 kg"), PairHtml("Peso netto", "2 kg"))
        For Each row As DataRow In changedRows.Rows
            row("SettoriId") = 8 : row("CategorieId") = 22
        Next
        Dim changed = KeepStoreShoppingKnowledge.Build(changedRows, "catalog-B")
        Assert(Not changed.Attributes.Any(Function(a) balancedMaterial.Attributes.Any(Function(b) a.Id = b.Id)), "AC04 taxonomy and catalog dictionary isolated")
        Assert(CStr(KnowledgeDecision(changed).Question("attributeId")) = changed.Attributes.Single().Id, "AC04 category change has only current populated question")
        Assert(KnowledgeDecision(KeepStoreShoppingKnowledge.Build(KnowledgeRows(good), "A")).Question Is Nothing, "AC07 one candidate no unnecessary question")
        Assert(KnowledgeDecision(KeepStoreShoppingKnowledge.Build(KnowledgeRows(good, good), "A")).Question Is Nothing, "AC07 uniform values no unnecessary question")
        Dim skipId As String = CStr(KnowledgeDecision(balancedMaterial).Question("attributeId"))
        Dim skipped As New HashSet(Of String)(StringComparer.Ordinal) From {skipId}
        Dim afterSkip = KeepStoreShoppingDecisionPolicy.Decide(balancedMaterial, New List(Of ShoppingCriterion), skipped, False, Nothing)
        Assert(afterSkip.Question Is Nothing OrElse CStr(afterSkip.Question("attributeId")) <> skipId, "AC05 skipped question not repeated")
        Dim capacityFacts As String = PairHtml("Memoria installata", "16 GB") & PairHtml("Memoria massima", "64 GB") &
            PairHtml("Peso netto", "1 kg") & PairHtml("Peso logistico", "2 kg") & PairHtml("Volume", "1 l") &
            PairHtml("Materiale", "legno") & PairHtml("Formato", "A4") & PairHtml("Tecnologia di stampa", "laser")
        Dim capacityCorpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(capacityFacts & PairHtml("Colore del prodotto", "blu"), capacityFacts & PairHtml("Colore del prodotto", "rosso")), "capacity")
        Assert(KnowledgeDecision(capacityCorpus).Question IsNot Nothing, "AC05 capacity fixture has otherwise useful unresolved question")
        Dim fullCriteria As List(Of ShoppingCriterion) = capacityCorpus.Attributes.Where(Function(a) a.Label <> "Colore del prodotto").
            Select(Function(a) Criterion(a, capacityCorpus.Products(0).Values(a.Id).Value, "soft")).ToList()
        Assert(fullCriteria.Count = 8 AndAlso KeepStoreShoppingDecisionPolicy.Decide(capacityCorpus, fullCriteria, New HashSet(Of String), False, Nothing).Question Is Nothing, "AC05 eighth criterion suppresses unusable ninth question")
        Dim fullSkipped As New HashSet(Of String)(Enumerable.Range(1, 24).Select(Function(index) "a_" & index.ToString("x24", CultureInfo.InvariantCulture)), StringComparer.Ordinal)
        Assert(KeepStoreShoppingDecisionPolicy.Decide(capacityCorpus, New List(Of ShoppingCriterion), fullSkipped, False, Nothing).Question Is Nothing, "AC05 twenty-four skips suppress question requiring impossible next skip")
        many.Clear()
        For index As Integer = 0 To 19
            many.Add(PairHtml("Memoria installata", If(index = 17, "32 GB", "8 GB")))
        Next
        corpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(many.ToArray()), "catalog-A")
        Dim match = KnowledgeDecision(corpus, Criterion(corpus.Attributes.Single(), "32"))
        Assert(match.Products.Count = 1 AndAlso match.Products(0).ProductKey = "18:-1", "AC08 matching product after first six survives server pool")
        Dim colorRows = KnowledgeRows(PairHtml("Colore del prodotto", "blu") & PairHtml("Materiale", "legno"), PairHtml("Colore del prodotto", "blu") & PairHtml("Materiale", "metallo"), PairHtml("Colore del prodotto", "blu"))
        corpus = KeepStoreShoppingKnowledge.Build(colorRows, "catalog-A")
        Dim color = corpus.Attributes.First(Function(a) a.Label = "Colore del prodotto"), material = corpus.Attributes.First(Function(a) a.Label = "Materiale")
        match = KnowledgeDecision(corpus, Criterion(color, "blu"), Criterion(material, "legno", "soft"))
        Assert(match.Products.Count = 3 AndAlso match.Products(0).Match = "complete" AndAlso match.Products(1).Match = "partial" AndAlso match.Products(2).Match = "partial", "AC10 complete partial distinction")
        Assert(match.Products(1).Evaluations(1).Status = "VIOLATED" AndAlso match.Products(2).Evaluations(1).Status = "UNKNOWN", "AC10 soft violated versus unknown")
        Dim impossible = KnowledgeDecision(corpus, Criterion(material, "legno"), Criterion(color, "blu", "hard", "eq"))
        Assert(impossible.Products.Count = 1, "AC10 hard excludes unknown")
        Dim numericCorpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(good, PairHtml("Memoria installata", "32 GB")), "catalog-A")
        Dim noMatch = KnowledgeDecision(numericCorpus, Criterion(numericCorpus.Attributes.Single(), "64", "hard", "gte"))
        Assert(noMatch.Products.Count = 0 AndAlso noMatch.Actions.Count = 1 AndAlso CBool(noMatch.Actions(0)("requiresConfirmation")), "AC10 minimum relaxation requires confirmation")
        Assert(KnowledgeDecision(numericCorpus).Products.Count = 2, "AC10 only explicit confirmed removal restores candidates")
        Dim ordered = KeepStoreShoppingDecisionPolicy.Decide(corpus, New List(Of ShoppingCriterion) From {Criterion(material, "metallo", "soft")}, New HashSet(Of String), True, Nothing)
        Assert(ordered.Products(0).ProductKey = "1:-1", "AC11 explicit SQL order preserved despite preference score")
        Dim exactFirst = KeepStoreShoppingDecisionPolicy.Decide(corpus, New List(Of ShoppingCriterion) From {Criterion(material, "metallo", "soft")}, New HashSet(Of String), False, New HashSet(Of String) From {"1:-1"})
        Assert(exactFirst.Products(0).ProductKey = "1:-1", "AC11 exact identifier preserved before soft ranking")
        Assert(KnowledgeDecision(corpus, Criterion(material, "metallo", "soft")).Products(0).ProductKey = "2:-1", "AC10 equal soft weight changes rank deterministically")
        KnowledgeReject(Sub() KnowledgeDecision(corpus, New ShoppingCriterion With {.AttributeId = "injected-column", .Operator = "eq", .Value = "1", .Priority = "hard"}), "AC12 unknown attribute rejected")
        KnowledgeReject(Sub() KnowledgeDecision(corpus, Criterion(color, "blu", "hard", "sql")), "AC12 unsupported operator rejected")
        KnowledgeReject(Sub() KnowledgeDecision(corpus, Criterion(material, "999")), "AC12 nonobserved nominal value rejected")
        Dim unsafeCorpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(PairHtml("Allergeni", "assenti")), "catalog-A")
        Assert(Not unsafeCorpus.Attributes(0).CanAsk AndAlso Not unsafeCorpus.Attributes(0).CanHardFilter, "AC12 safety label discovery never approval")
        KnowledgeReject(Sub() KnowledgeDecision(unsafeCorpus, Criterion(unsafeCorpus.Attributes(0), "assenti", "soft")), "AC12 unapproved discovery also rejected for soft ranking")
        Dim serializer As New System.Web.Script.Serialization.JavaScriptSerializer()
        Dim raw As String = serializer.Serialize(New Object() {New Dictionary(Of String, String) From {{"attributeId", color.Id}, {"operator", "eq"}, {"value", "blu"}, {"priority", "hard"}}})
        Assert(KeepStoreShoppingDecisionPolicy.ParseCriteria(raw).Single().AttributeId = color.Id, "AC12 strict typed criterion parser positive")
        KnowledgeReject(Sub() KeepStoreShoppingDecisionPolicy.ParseCriteria(raw.Replace("""value"":", """value"":""rosso"",""value"":")), "AC12 duplicate JSON property rejected")
        KnowledgeReject(Sub() KeepStoreShoppingDecisionPolicy.ParseCriteria(New String("x"c, 4097)), "AC13 enormous criteria bounded")
        KnowledgeReject(Sub() KeepStoreShoppingDecisionPolicy.ParseCriteria(raw.Replace("""hard""", "true")), "AC12 nonstring criterion rejected")
        Dim original = KeepStoreShoppingKnowledge.Build(KnowledgeRows(good), "catalog-A")
        Dim refreshed = KeepStoreShoppingKnowledge.Build(KnowledgeRows(PairHtml("Memoria installata", "8 GB")), "catalog-A")
        Assert(original.Attributes(0).Id = refreshed.Attributes(0).Id AndAlso original.Products(0).Values.Values.Single().EvidenceRef <> refreshed.Products(0).Values.Values.Single().EvidenceRef, "AC15 policy identity stable and changed source evidence refreshed")
        Assert(KnowledgeDecision(original, Criterion(original.Attributes(0), "16")).Products.Count = 1 AndAlso KnowledgeDecision(refreshed, Criterion(refreshed.Attributes(0), "16")).Products.Count = 0, "AC15 source change refreshes decision no cache")
        Dim sameQueryTech = KnowledgeDecision(balancedMaterial)
        Dim sameQueryOther = KnowledgeDecision(changed)
        Assert(CStr(sameQueryTech.Question("attributeId")) <> CStr(sameQueryOther.Question("attributeId")) AndAlso balancedMaterial.Products.Count = 20 AndAlso changed.Products.Count = 2, "AC16 same literal query different merchandise question from facts")
        Dim unitCorpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(PairHtml("Memoria installata", "16 GB"), PairHtml("Memoria installata", "16 GiB"), PairHtml("Memoria massima", "16 GB")), "catalog-A")
        Assert(unitCorpus.Attributes.Count = 3 AndAlso unitCorpus.Attributes.Select(Function(a) a.Id).Distinct().Count() = 3, "AC13 installed maximum GB GiB never merged")
        Dim unicodeCorpus = KeepStoreShoppingKnowledge.Build(KnowledgeRows(PairHtml("Colore del prodotto", "blu" & ChrW(&H300))), "catalog-A")
        Assert(unicodeCorpus.Products(0).Values.Values.Single().Value = "bl" & ChrW(&HF9), "AC13 Unicode NFC deterministic")
        Dim unknownFamily = KnowledgeRows(good) : unknownFamily.Rows(0)("SettoriId") = DBNull.Value
        Assert(Not KeepStoreShoppingKnowledge.Build(unknownFamily, "A").Attributes(0).CanHardFilter, "AC13 missing taxonomy never operative")
        Dim huge As String = good & New String("x"c, 17000)
        Dim bounded = KeepStoreShoppingKnowledge.Build(KnowledgeRows(Enumerable.Repeat(huge, 97).ToArray()), "A")
        Assert(bounded.Products.Count = 96 AndAlso bounded.ProcessingLimited AndAlso bounded.Attributes.Count = 0, "AC13 oversized text and pool fail closed bounded")
        Dim manyPairs As String = String.Concat(Enumerable.Repeat(good, 49))
        bounded = KeepStoreShoppingKnowledge.Build(KnowledgeRows(manyPairs), "A")
        Assert(bounded.ProcessingLimited AndAlso bounded.Attributes.Count = 0, "AC13 too many pairs cannot conceal tail contradiction")
        Dim attackRows = KnowledgeRows(good)
        attackRows.Rows(0)("Descrizione2") = huge
        Assert(KeepStoreShoppingKnowledge.Build(attackRows, "A").Attributes.Count = 0, "AC13 unprocessed field prevents crossfield false hard")
        Dim stress As String = String.Concat(Enumerable.Range(1, 40).Select(Function(index) PairHtml("Campo " & index, "valore")))
        Dim stressTimer = System.Diagnostics.Stopwatch.StartNew()
        bounded = KeepStoreShoppingKnowledge.Build(KnowledgeRows(Enumerable.Repeat(stress, 96).ToArray()), "A")
        stressTimer.Stop()
        Assert(bounded.Attributes.Count <= 32 AndAlso bounded.ProcessingLimited AndAlso stressTimer.ElapsedMilliseconds < 30000, "AC13 bounded dictionary CPU fixture below thirty seconds")
        timer.Stop() : process.Refresh()
        Dim report = New With {.mode = "COMPILED_REAL_VB_SYNTHETIC_ROWS_NO_DATABASE", .knowledgeAssertions = passed - initialAssertions,
            .positiveFixtures = positives.Length, .truePositiveExtraction = truePositive, .negativeFixtures = negative.Length, .falseHardPositive = falseHard,
            .hardTruePositive = hardTruePositive, .hardPrecisionPreparedFixtures = CDbl(hardTruePositive) / (hardTruePositive + falseHard),
            .extractionRecallPreparedFixtures = CDbl(truePositive) / positives.Length, .hardFalsePositiveRatePreparedFixtures = CDbl(falseHard) / negative.Length,
            .wallMilliseconds = timer.ElapsedMilliseconds, .cpuMilliseconds = (process.TotalProcessorTime - initialCpu).TotalMilliseconds,
            .managedMemoryDeltaBytes = GC.GetTotalMemory(False) - initialMemory, .stress96WallMilliseconds = stressTimer.ElapsedMilliseconds,
            .maxAnalyzedProducts = 96, .maxTextCharsPerField = 16384, .maxAttributes = 32, .maxPairsPerProduct = 48,
            .maxEvidenceChars = 180, .queryCountKnowledgeLayer = 0, .limitation = "Prepared synthetic counterexamples only, not universal safety or live catalog evidence"}
        File.WriteAllText(Path.Combine(outputDirectory, "knowledge-quality.json"), serializer.Serialize(report), New System.Text.UTF8Encoding(False))
        Console.WriteLine("KNOWLEDGE_FALSE_HARD_POSITIVES=" & falseHard & "; POSITIVE_RECALL=" & truePositive & "/" & positives.Length & "; COUNTEREXAMPLES=" & negative.Length)
    End Sub
'@
# ENDPOINT_CASES is populated below in this same script; it never loads fixture
# instructions or source code from the evidence directory.
$endpointCases=@'
    Private Function AdvisorTree() As List(Of CatalogMenuSector)
        Dim tree As New List(Of CatalogMenuSector)
        For Each id As Integer In {7, 8}
            Dim sector As New CatalogMenuSector With {.Id = id, .Descrizione = If(id = 7, "Tecnologia sintetica", "Alimentari sintetici")}
            Dim category As New CatalogMenuCategory With {.Id = id * 100 + 1, .SettoriId = id, .Descrizione = "Famiglia sintetica"}
            category.Children.Add(New CatalogMenuNode With {.Id = id * 1000 + 1, .ParentId = category.Id, .Descrizione = "Tipo sintetico"})
            sector.Categories.Add(category) : tree.Add(sector)
        Next
        Return tree
    End Function

    Private Function AdvisorRows(support As SearchSuggestCommercialSupport, sector As Integer, count As Integer) As DataTable
        Dim result As DataTable = ProductRows(support, -1)
        For Each name As String In {"SettoriId", "CategorieId", "TipologieId", "GruppiId", "SottoGruppiId", "MarcheId"}
            result.Columns.Add(name, GetType(Integer))
        Next
        Dim template As Object() = result.Rows(0).ItemArray
        result.Rows.Clear()
        For index As Integer = 0 To count - 1
            Dim row As DataRow = result.NewRow()
            row.ItemArray = DirectCast(template.Clone(), Object())
            row("id") = 120 + index : row("TCid") = -1
            row("Codice") = "SKU" & (120 + index) : row("Ean") = "8000000000" & (120 + index)
            row("Descrizione1") = "Prodotto sintetico " & If(sector = 7, "Tech ", "Food ") & (index + 1)
            row("Descrizione2") = "Esempio anonimo per prove locali, nessun articolo operativo."
            row("MarcheDescrizione") = "Marca fixture"
            row("SettoriDescrizione") = If(sector = 7, "Tecnologia sintetica", "Alimentari sintetici")
            row("CategorieDescrizione") = "Famiglia fixture"
            row("SettoriId") = sector : row("CategorieId") = sector * 100 + 1 : row("TipologieId") = sector * 1000 + 1
            row("GruppiId") = 0 : row("SottoGruppiId") = 0 : row("MarcheId") = 1
            row("RankScore") = 10000 - index : row("ExactMatches") = 0
            If sector = 7 Then
                row("DescrizioneHTML") = "<table><tr><td>Memoria installata</td><td>" & If(index < 6, "8", "16") & " GB</td></tr><tr><td>Colore del prodotto</td><td>" & If(index Mod 2 = 0, "nero", "bianco") & "</td></tr></table>"
                If index = 19 Then row("DescrizioneHTML") = "<dl><dt>Colore del prodotto</dt><dd>nero</dd></dl>"
            Else
                row("DescrizioneHTML") = "<dl><dt>Volume</dt><dd>" & If(index Mod 2 = 0, "500", "1000") & " ml</dd><dt>Formato</dt><dd>" & If(index Mod 4 = 0, "bottiglia", "confezione") & "</dd></dl>"
            End If
            result.Rows.Add(row)
        Next
        Return result
    End Function

    Private Function AdvisorPayload(query As String, sector As Integer, count As Integer,
                                    Optional company As Integer = 1, Optional list As Integer = 1,
                                    Optional authenticated As Boolean = False, Optional variantId As Integer = -1,
                                    Optional multiSource As Boolean = False) As Dictionary(Of String, Object)
        Dim ctx = Context(company, list, authenticated, query)
        ctx.Session("TC") = 1
        If authenticated Then account = AccountRow(company, list + 3)
        Dim support = MakeSupport(ctx)
        products = AdvisorRows(support, sector, count)
        For Each row As DataRow In products.Rows
            row("TCid") = variantId
            If multiSource Then
                row("Descrizione1") = row("DescrizioneHTML")
                row("Descrizione2") = row("DescrizioneHTML")
                row("DescrizioneLunga") = row("DescrizioneHTML")
            End If
        Next
        Dim page = Endpoint(support)
        Dim request = Invoke(page, "ReadGuided2FiltersCore", AdvisorTree())
        Dim result = DirectCast(Invoke(page, "BuildGuided2Result", request), Dictionary(Of String, Object))
        result("ok") = True
        Assert(commands.Where(Function(sql) Not sql.Contains("FROM vlogin")).Count() = 2 AndAlso commands.Last().EndsWith(" LIMIT 97"), "advisor one pool plus existing projection check, bounded97")
        Assert(commands.Last().Contains("v.SettoriId, v.CategorieId, v.TipologieId"), "advisor real taxonomy projection")
        Assert(captures.Last().Any(Function(p) p.Name = "?promoListino" AndAlso CInt(p.Value) = If(authenticated, list + 3, list)), "advisor server list authority")
        Return result
    End Function

    Private Function AdvisorAttribute(payload As Dictionary(Of String, Object), label As String) As String
        Dim meta = DirectCast(payload("guided"), Dictionary(Of String, Object))
        Dim definitions = DirectCast(meta("attributes"), List(Of Dictionary(Of String, Object)))
        Return CStr(definitions.First(Function(item) CStr(item("label")).Equals(label, StringComparison.OrdinalIgnoreCase))("id"))
    End Function

    Private Function AdvisorCriteria(attributeId As String, comparison As String, value As String, priority As String) As String
        Return New System.Web.Script.Serialization.JavaScriptSerializer().Serialize(New Object() {
            New Dictionary(Of String, Object) From {{"attributeId", attributeId}, {"operator", comparison}, {"value", value}, {"priority", priority}}})
    End Function

    Private Sub RunAdvisorEndpoint(outputDirectory As String)
        relationalRows = Nothing : invalidProjection = 0 : offers.Clear()
        batchStatus = ProductPromotionEligibilityLoadStatus.Success
        Dim samples As New List(Of Object)
        Dim baseQuery As String = "mode=guided2&q=scelta&st=7&limit=6"
        Dim initial = AdvisorPayload(baseQuery, 7, 20)
        Dim initialMeta = DirectCast(initial("guided"), Dictionary(Of String, Object))
        Assert(CInt(initialMeta("analyzedCount")) = 20 AndAlso CInt(initial("total")) = 6, "advisor pool larger than six cards")
        Assert(CBool(initialMeta("exhaustive")) AndAlso CStr(initialMeta("selectionScope")) = "bounded-catalog-candidates", "advisor explicit selected query scope")
        Assert(initialMeta("question") IsNot Nothing, "advisor real nonuniform attribute question")
        samples.Add(New With {.name = "tech-initial", .queryString = baseQuery, .response = initial})
        Dim multi = AdvisorPayload(baseQuery, 7, 20, 1, 1, False, -1, True)
        Dim multiFacts = DirectCast(DirectCast(multi("suggestions"), List(Of Dictionary(Of String, Object)))(0)("values"), List(Of Dictionary(Of String, Object)))
        Assert(multiFacts.Any(Function(value) CStr(value("sourceField")) = "Descrizione1,Descrizione2,DescrizioneLunga,DescrizioneHTML" AndAlso CStr(value("evidenceStatus")) = "known"), "AC01 four concordant real source fields retain known evidence")
        samples.Add(New With {.name = "tech-multisource", .queryString = baseQuery, .response = multi})
        Dim benchmarkSerializer As New System.Web.Script.Serialization.JavaScriptSerializer()
        Dim v2Bytes As Integer = System.Text.Encoding.UTF8.GetByteCount(benchmarkSerializer.Serialize(initial))
        Dim v2Queries As Integer = commands.Count
        Dim v1Context = Context(1, 1, False, "mode=guided&q=scelta&st=7&limit=6")
        v1Context.Session("TC") = 1
        Dim v1Support = MakeSupport(v1Context) : products = AdvisorRows(v1Support, 7, 20)
        Dim v1Page = Endpoint(v1Support), v1Filters = Invoke(v1Page, "ReadFilters")
        Dim v1Result = DirectCast(Invoke(v1Page, "BuildSearchResult", "scelta", v1Filters, 6), Dictionary(Of String, Object))
        v1Result("ok") = True
        Dim v1Bytes As Integer = System.Text.Encoding.UTF8.GetByteCount(benchmarkSerializer.Serialize(v1Result))
        Assert(commands.Count = v2Queries AndAlso commands.Last().EndsWith(" LIMIT 6"), "AC14 guided v1 six limit and query count preserved")
        Assert(v2Bytes < 131072, "AC13 actual v2 serialized bytes within payload bound")
        File.WriteAllText(Path.Combine(outputDirectory, "advisor-payload-metrics.json"), benchmarkSerializer.Serialize(New With {
            .mode = "REAL_ENDPOINT_SERIALIZATION_SYNTHETIC_READ_MODEL_NO_MYSQL", .visibleProducts = 6,
            .v1Bytes = v1Bytes, .v2Bytes = v2Bytes, .deltaBytes = v2Bytes - v1Bytes,
            .v1GeneratedPoolLimit = 6, .v2GeneratedPoolLimit = 97, .v2Analyzed = 20,
            .v1ProductQueries = commands.Count, .v2ProductQueries = v2Queries, .queryDelta = v2Queries - commands.Count,
            .limitation = "SQL command capture only; no live latency, execution plan or database measurement"}), New System.Text.UTF8Encoding(False))
        Dim question = DirectCast(initialMeta("question"), Dictionary(Of String, Object))
        Dim optionValue As String = CStr(DirectCast(question("options"), List(Of Dictionary(Of String, Object)))(0)("value"))
        For Each priority As String In {"hard", "soft"}
            Dim answeredQuery As String = baseQuery & "&criteria=" & HttpUtility.UrlEncode(AdvisorCriteria(CStr(question("attributeId")), "eq", optionValue, priority))
            Dim answered = AdvisorPayload(answeredQuery, 7, 20)
            samples.Add(New With {.name = "tech-question-" & priority, .queryString = answeredQuery, .response = answered})
        Next
        Dim skippedQuery As String = baseQuery & "&skipped=" & HttpUtility.UrlEncode(New System.Web.Script.Serialization.JavaScriptSerializer().Serialize(New String() {CStr(question("attributeId"))}))
        Dim skipped = AdvisorPayload(skippedQuery, 7, 20)
        Assert(CStr(DirectCast(DirectCast(skipped("guided"), Dictionary(Of String, Object))("question"), Dictionary(Of String, Object))("attributeId")) <> CStr(question("attributeId")), "advisor skipped question not repeated")
        samples.Add(New With {.name = "tech-skipped", .queryString = skippedQuery, .response = skipped})
        Dim memory As String = AdvisorAttribute(initial, "Memoria installata")
        Dim colour As String = AdvisorAttribute(initial, "Colore del prodotto")
        Dim hardQuery As String = baseQuery & "&criteria=" & HttpUtility.UrlEncode(AdvisorCriteria(memory, "gte", "16", "hard"))
        Dim hard = AdvisorPayload(hardQuery, 7, 20)
        Dim hardItems = DirectCast(hard("suggestions"), List(Of Dictionary(Of String, Object)))
        Assert(hardItems.Count = 6 AndAlso hardItems.All(Function(item) CInt(item("id")) >= 126 AndAlso CInt(item("id")) <> 139), "advisor compliant beyond six, missing excluded")
        Assert(hardItems.All(Function(item) CStr(item("match")) = "complete"), "advisor full verified match")
        samples.Add(New With {.name = "tech-hard", .queryString = hardQuery, .response = hard})
        Dim variantUnknown = AdvisorPayload(hardQuery, 7, 20, 1, 1, False, 42)
        Assert(CInt(variantUnknown("total")) = 0, "AC11 real endpoint cannot certify positive variant from parent description")
        samples.Add(New With {.name = "tech-variant-hard-unknown", .queryString = hardQuery, .response = variantUnknown})
        Dim softQuery As String = baseQuery & "&criteria=" & HttpUtility.UrlEncode(AdvisorCriteria(colour, "eq", "nero", "soft"))
        Dim soft = AdvisorPayload(softQuery, 7, 20)
        Assert(DirectCast(soft("suggestions"), List(Of Dictionary(Of String, Object))).All(Function(item) CInt(item("id")) Mod 2 = 0), "advisor confirmed soft preference affects ranking")
        samples.Add(New With {.name = "tech-soft", .queryString = softQuery, .response = soft})
        Dim explicitQuery As String = softQuery & "&ordinamento=p_basso"
        Dim explicit = AdvisorPayload(explicitQuery, 7, 20)
        Assert(CInt(DirectCast(explicit("suggestions"), List(Of Dictionary(Of String, Object)))(1)("id")) = 121, "advisor explicit order preserved ahead of soft score")
        samples.Add(New With {.name = "tech-explicit-order", .queryString = explicitQuery, .response = explicit})
        Dim emptyQuery As String = baseQuery & "&criteria=" & HttpUtility.UrlEncode(AdvisorCriteria(memory, "gte", "64", "hard"))
        Dim empty = AdvisorPayload(emptyQuery, 7, 20)
        Dim emptyMeta = DirectCast(empty("guided"), Dictionary(Of String, Object))
        Assert(CInt(empty("total")) = 0 AndAlso DirectCast(emptyMeta("actions"), List(Of Dictionary(Of String, Object))).Count = 1, "advisor no conforming product and minimum confirmed relaxation")
        samples.Add(New With {.name = "tech-hard-empty", .queryString = emptyQuery, .response = empty})
        Dim truncated = AdvisorPayload(emptyQuery, 7, 97)
        Dim truncatedMeta = DirectCast(truncated("guided"), Dictionary(Of String, Object))
        Assert(Not CBool(truncatedMeta("exhaustive")) AndAlso CInt(truncatedMeta("analyzedCount")) = 96 AndAlso CStr(truncatedMeta("summary")).Contains("incompleta"), "advisor truncation never global absence")
        samples.Add(New With {.name = "tech-truncated-empty", .queryString = emptyQuery, .response = truncated})
        Dim foodQuery As String = "mode=guided2&q=scelta&st=8&limit=6"
        Dim food = AdvisorPayload(foodQuery, 8, 20)
        Dim foodMeta = DirectCast(food("guided"), Dictionary(Of String, Object))
        Assert(CStr(foodMeta("scope")) <> CStr(initialMeta("scope")), "advisor family scope changes")
        Assert(DirectCast(foodMeta("attributes"), List(Of Dictionary(Of String, Object))).All(Function(a) CStr(a("id")) <> memory AndAlso CStr(a("id")) <> colour), "advisor no old category attributes")
        Assert(CStr(DirectCast(foodMeta("question"), Dictionary(Of String, Object))("attributeId")) = AdvisorAttribute(food, "Volume"), "advisor same query different family question")
        samples.Add(New With {.name = "food-initial", .queryString = foodQuery, .response = food})
        Dim noQuery As String = "mode=guided2&st=7&limit=6"
        Dim taxonomyOnly = AdvisorPayload(noQuery, 7, 20)
        Assert(CStr(taxonomyOnly("query")) = String.Empty AndAlso Not commands.Last().Contains("@qExact"), "advisor empty query only explicit validated taxonomy")
        samples.Add(New With {.name = "taxonomy-only", .queryString = noQuery, .response = taxonomyOnly})
        Dim singleton = AdvisorPayload(baseQuery, 7, 1)
        Assert(DirectCast(singleton("guided"), Dictionary(Of String, Object))("question") Is Nothing, "advisor singleton no useless question")
        samples.Add(New With {.name = "tech-singleton", .queryString = baseQuery, .response = singleton})
        For Each company As Integer In {1, 2}
            For Each authenticated As Boolean In {False, True}
                Dim commercial = AdvisorPayload(baseQuery, 7, 3, company, If(company = 1, 1, 10), authenticated)
                samples.Add(New With {.name = "commercial-" & company & If(authenticated, "-auth", "-anon"), .queryString = baseQuery, .response = commercial})
            Next
        Next
        For Each suffix As String In {"q=a", "q=", "q=scelta&owner=1", "q=scelta&listino=3", "q=scelta&mode=guided", "q=scelta&q=other", "q=scelta&ct=701&st=8", "st=999", "q=scelta&st=2147483648", "q=scelta&limit=7", "q=scelta&criteria=%5B%7B%22attributeId%22%3A%22x%22%2C%22attributeId%22%3A%22y%22%7D%5D"}
            Dim ctx = Context(1, 1, False, "mode=guided2&" & suffix)
            Dim support = MakeSupport(ctx)
            Reject(Sub() Invoke(Endpoint(support), "ReadGuided2FiltersCore", AdvisorTree()), "advisor malformed request rejected " & suffix)
            Assert(commands.Count = 0, "advisor malformed request before product SQL")
        Next
        For Each attack As String In {AdvisorCriteria("a_not_authorized", "eq", "x", "hard"), AdvisorCriteria(memory, "drop", "16", "hard"), AdvisorCriteria(memory, "gte", "16", "owner")}
            Dim ctx = Context(1, 1, False, baseQuery & "&criteria=" & HttpUtility.UrlEncode(attack))
            ctx.Session("TC") = 1
            Dim support = MakeSupport(ctx) : products = AdvisorRows(support, 7, 20)
            Dim page = Endpoint(support)
            Reject(Sub()
                       Dim request = Invoke(page, "ReadGuided2FiltersCore", AdvisorTree())
                       Invoke(page, "BuildGuided2Result", request)
                   End Sub, "advisor forged attribute/operator/priority rejected")
        Next
        Dim output As New System.Web.Script.Serialization.JavaScriptSerializer With {.MaxJsonLength = 4194304}
        File.WriteAllText(Path.Combine(outputDirectory, "server-advisor-payloads.json"), output.Serialize(New With {.fixtures = samples}), New System.Text.UTF8Encoding(False))
    End Sub

'@
$baselineScript=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Test-SearchSuggestCommercialContext.ps1'))
$harness=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'SearchSuggestCommercialContextHarness.vb'))
$caller=[regex]::Match($baselineScript,"(?s)\`$callerScript=@'\r?\n(.*?)\r?\n'@").Groups[1].Value
$masterShell=[regex]::Match($baselineScript,"(?s)\`$masterFixture=@'\r?\n(.*?)\r?\n'@").Groups[1].Value
if(-not $caller -or -not $masterShell){throw 'UNCHANGED_HARNESS_FIXTURES_REQUIRED'}
$masterSource=[IO.File]::ReadAllText((Join-Path $root 'Page.master.vb'))
$masterMethod=[regex]::Match($masterSource,'(?ms)^    Public Sub ApplyAuthenticatedPriceDisplayState\(.*?^    End Sub').Value
if(-not $masterMethod){throw 'MASTER_FISCAL_METHOD_REQUIRED'}
$harness=$harness.Replace('RunGuided(If(args.Length > 1, args(1), String.Empty))','RunGuided(If(args.Length > 1, args(1), String.Empty))'+[Environment]::NewLine+'                RunKnowledge(args(2))'+[Environment]::NewLine+'                RunAdvisorEndpoint(args(2))')
$harness=[regex]::Replace($harness,'(?m)^End Module\s*$',($knowledgeCases+[Environment]::NewLine+$endpointCases+[Environment]::NewLine+'End Module'))
try {
    $harnessPath=Join-Path $work 'AdvisorHarness.vb'
    [IO.File]::WriteAllText($harnessPath,$harness,$utf8)
    $masterPath=Join-Path $work 'MasterFiscalFixture.vb'
    [IO.File]::WriteAllText($masterPath,$masterShell+[Environment]::NewLine+$masterMethod+[Environment]::NewLine+'End Class',$utf8)
    $baselinePath=Join-Path $work 'BaselinePromotionCatalog.vb'
    $baseline=@(& git -C $root show '0363e53e:App_Code/StorefrontPromotionCatalogProvider.vb')
    if($LASTEXITCODE -ne 0){throw 'UNCHANGED_PROMOTION_BASELINE_REQUIRED'}
    [IO.File]::WriteAllText($baselinePath,(($baseline -join [Environment]::NewLine).Replace('Public Module StorefrontPromotionCatalogProvider','Public Module SearchSuggestBaselinePromotionCatalogProvider')),$utf8)
    $callerPath=Join-Path $work 'HeaderCallerFixture.js'
    $callerUrls=Join-Path $work 'HeaderCallerUrls.json'
    [IO.File]::WriteAllText($callerPath,$caller,$utf8)
    & (Get-Command node -CommandType Application -ErrorAction Stop).Source $callerPath (Join-Path $root 'Public/assets/keepstore/js/ks-page-flags.js') $callerUrls
    if($LASTEXITCODE -ne 0){throw 'HEADER_CALLER_FIXTURE_FAILED'}
    $exe=Join-Path $work 'AdvisorHarness.exe'
    $compilerArgs=@('/nologo','/target:exe','/optioninfer+','/main:SearchSuggestCommercialContextHarness',('/out:'+$exe),'/imports:Microsoft.VisualBasic,System,System.Collections,System.Collections.Generic,System.Data,System.Linq,System.Web,System.Configuration')
    foreach($name in @('System.dll','System.Core.dll','System.Data.dll','System.Configuration.dll','System.Web.dll','System.Web.Extensions.dll','System.Xml.dll','System.Xml.Linq.dll','System.Drawing.dll','System.Net.Http.dll','System.Runtime.Serialization.dll','System.ServiceModel.dll')){$compilerArgs+=('/reference:'+(Join-Path $framework $name))}
    foreach($dll in @(Get-ChildItem -LiteralPath (Join-Path $root 'Bin') -Filter '*.dll' -File)){$compilerArgs+=('/reference:'+$dll.FullName)}
    $compilerArgs+=@(Get-ChildItem -LiteralPath (Join-Path $root 'App_Code') -Filter '*.vb' -File | ForEach-Object {$_.FullName})
    $compilerArgs+=@((Join-Path $root 'search_suggest.aspx.vb'),$harnessPath,$masterPath,$baselinePath)
    & (Join-Path $framework 'vbc.exe') @compilerArgs
    if($LASTEXITCODE -ne 0){throw 'ADVISOR_REAL_SOURCE_COMPILE_FAILED'}
    foreach($dll in @(Get-ChildItem -LiteralPath (Join-Path $root 'Bin') -Filter '*.dll' -File)){Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $work $dll.Name)}
    & $exe $callerUrls (Join-Path $output 'server-payloads.json') $output
    if($LASTEXITCODE -ne 0){throw 'ADVISOR_COMPILED_HARNESS_FAILED'}
    $sources=@(foreach($relative in @('App_Code/KeepStoreShoppingKnowledge.vb','App_Code/KeepStoreShoppingDecisionPolicy.vb','search_suggest.aspx.vb','Tools/Test-ShoppingAssistantKnowledgeEvidence.ps1','Tools/SearchSuggestCommercialContextHarness.vb')){
        [pscustomobject]@{path=$relative;sha256=(Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash}
    })
    [IO.File]::WriteAllText((Join-Path $output 'advisor-source-hashes.json'),($sources|ConvertTo-Json -Depth 3),$utf8)
    Write-Output 'SHOPPING_KNOWLEDGE_SUITE=PASS; SQL_EXECUTED_ON_MYSQL=NO; DATABASE_CONNECTIONS=0; HTTP_UPSTREAM=0'
} finally {
    $resolved=[IO.Path]::GetFullPath($work)
    if(-not $resolved.StartsWith($output.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'UNSAFE_OWN_TEMP_CLEANUP'}
    if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
