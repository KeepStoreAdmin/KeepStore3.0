[CmdletBinding()]
param([string]$RepositoryRoot, [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
      [string]$BaselineRef='3566479c0cdce06bdd0139b941cf339648d654b6')
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) { throw 'HOME_CLAIM_REQUIRES_POWERSHELL_51' }
if (!$RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$EvidenceDirectory = [IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if (!$EvidenceDirectory.StartsWith($temp+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory) -or $BaselineRef -notmatch '^[a-f0-9]{40}$') { throw 'HOME_CLAIM_INVALID_EVIDENCE_OR_BASE' }
$work = Join-Path $temp ('ks-home-claim-compile-' + [Guid]::NewGuid().ToString('N'))
$utf8 = New-Object Text.UTF8Encoding($false)
$checks = New-Object 'Collections.Generic.List[object]'
$fixtures = New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$ok) { $checks.Add([pscustomobject]@{Name=$name;Pass=$ok}); if(!$ok){throw ('HOME_CLAIM_ASSERT: '+$name)} }
function Normalize([string]$s) { return $s.Replace("`r`n","`n").TrimEnd([char[]]"`r`n") }
function Source-Method([string]$s,[string]$name) {
    $m=[regex]::Match($s,'(?ms)^    (?:Private|Protected) (?:Shared )?(?:Function|Sub) '+$name+'\b.*?^    End (?:Function|Sub)')
    if(!$m.Success){throw ('HOME_CLAIM_METHOD_MISSING: '+$name)}
    return $m.Value
}
function Table-Xml([Data.DataTable]$t) { $w=New-Object IO.StringWriter;try{$t.WriteXml($w,[Data.XmlWriteMode]::WriteSchema);return $w.ToString()}finally{$w.Dispose()} }
try {
    New-Item -ItemType Directory -Path $EvidenceDirectory,$work | Out-Null
    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName Microsoft.VisualBasic
    $vb=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx.vb'))
    $aspx=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
    $oldVb=(git -C $RepositoryRoot show ($BaselineRef+':Default.aspx.vb')) -join "`n"
    if($LASTEXITCODE -ne 0){throw 'HOME_CLAIM_BASE_VB_UNAVAILABLE'}
    $oldAsp=(git -C $RepositoryRoot show ($BaselineRef+':Default.aspx')) -join "`n"
    if($LASTEXITCODE -ne 0){throw 'HOME_CLAIM_BASE_ASPX_UNAVAILABLE'}
    Check 'entire VB identical after removing full-line comments' ((Normalize ([regex]::Replace($vb,'(?m)^[ \t]*''[^\r\n]*\r?\n',''))) -ceq (Normalize ([regex]::Replace($oldVb,'(?m)^[ \t]*''[^\r\n]*\r?\n',''))))
    $literalMatch=[regex]::Match($aspx,'<asp:Literal\s+ID="litHomeBestSellerTitle"[^>]*/>')
    Check 'only ASPX change is the section title' ($literalMatch.Success -and (Normalize $aspx.Replace($literalMatch.Value,'Best Seller')) -ceq (Normalize $oldAsp))
    $xml=New-Object Xml.XmlDocument
    $xml.LoadXml('<root xmlns:asp="urn:fixture">'+$literalMatch.Value+'</root>')
    $node=$xml.DocumentElement.FirstChild
    $literal=New-Object Web.UI.WebControls.Literal
    $literal.Mode=[Enum]::Parse([Web.UI.WebControls.LiteralMode],$node.GetAttribute('Mode'))
    $literal.Text=$node.GetAttribute('Text')
    function Render-Title { $w=New-Object IO.StringWriter;try{$literal.RenderControl((New-Object Web.UI.HtmlTextWriter($w)));return $w.ToString()}finally{$w.Dispose()} }
    $title=Render-Title
    Check 'neutral constant encoded WebForms Literal' ($literal.Mode -eq [Web.UI.WebControls.LiteralMode]::Encode -and $literal.Text -ceq 'Altri prodotti da scoprire')
    $literal.Text='<img src=x onerror=alert(1)> & "Tech/Food"'
    $encoded=Render-Title
    Check 'Literal encodes markup and attribute characters' (!$encoded.Contains('<img') -and $encoded.Contains('&lt;img') -and $encoded.Contains('&amp;') -and $encoded.Contains('&quot;'))
    $literal.Text=$node.GetAttribute('Text')
    $methodNames=@('TakeDiverseRows','CollectDistinctRows','AddDistinctRows','CloneFirstTable','EmptyProductsTable','GetBusinessKey','GetDisplayKey','GetDisplayCategoryCaption','BuildDisplayStem','IsDisplayVariantToken','NormalizeBusinessIdentifier','NormalizeBusinessText','NormalizeDisplayText','SafeInt','IsTableEmpty')
    $compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
    function Compile-Fixture([string]$source,[string]$name) {
        $body=@($methodNames|ForEach-Object{Source-Method $source $_}) -join "`n"
        $wrapper=@'
 Public Function SelectFixtureRows(ByVal business As HashSet(Of String), ByVal display As HashSet(Of String), ByVal sources() As DataTable) As DataTable
  Return TakeDiverseRows(8, business, display, sources)
 End Function
 Public Function NewFixtureTable() As DataTable
  Return EmptyProductsTable()
 End Function
 Public Function FixtureVisible(ByVal rows As DataTable) As Boolean
  Return Not IsTableEmpty(rows)
 End Function
'@
        $code="Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`nPublic Class "+$name+"`n"+$body+"`n"+$wrapper+"`nEnd Class"
        $p=New-Object CodeDom.Compiler.CompilerParameters
        $p.GenerateInMemory=$true;$p.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict-'
        $p.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($work,$false)
        foreach($a in @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll')){[void]$p.ReferencedAssemblies.Add($a)}
        $r=$compiler.CompileAssemblyFromSource($p,$code)
        if($r.Errors.HasErrors){throw ('HOME_CLAIM_COMPILE: '+(($r.Errors|ForEach-Object{$_.ErrorText}) -join '; '))}
        return [Activator]::CreateInstance($r.CompiledAssembly.GetType($name,$true))
    }
    $baseline=Compile-Fixture $oldVb 'BaselineHomeClaimFixture'
    $candidate=Compile-Fixture $vb 'CandidateHomeClaimFixture'
    function Pool([string]$tenant,[int]$company) {
        $t=$candidate.NewFixtureTable();$t.TableName='Products'
        [void]$t.Columns.Add('TCId',[int]);[void]$t.Columns.Add('FixtureCompanyId',[int])
        return ,$t
    }
    function Row([Data.DataTable]$t,[string]$tenant,[int]$company,[int]$id,[int]$tcid,[string]$word,$sold) {
        $r=$t.NewRow();$r.id=$id;$r.TCId=$tcid;$r.FixtureCompanyId=$company
        $r.Ean='FIXTURE-'+$word;$r.Codice='CODE-'+$word;$r.Descrizione1=$tenant+' '+$word+' prodotto';$r.MarcheDescrizione='Marca sintetica';$r.CategorieDescrizione='Reparto sintetico'
        $r.Prezzo=17.43D+$id;$r.PrezzoIvato=21.2646D+$id;$r.PrezzoPromo=15.2D;$r.PrezzoPromoIvato=18.544D;$r.ValoreIvaRC=22D;$r.InOfferta=1;$r.Giacenza=6D;$r.Disponibilita=4D;$r.Impegnata=2D;$r.InOrdine=1D
        $r.DisplayPromoSnapshotReady=$true;$r.DisplayPromoQtyOnePrice=18.544D;$r.OfferteQntMinima=3;$r.OfferteMultipli=1
        $r.QtaVenduta=if($null -eq $sold){[DBNull]::Value}else{$sold};$r.VendutiAnno=$r.QtaVenduta
        $t.Rows.Add($r)
    }
    $section=[regex]::Match($aspx,'(?s)<section id="HomeLegacyBestSection".*?</section>').Value
    Check 'visibility follows the existing real IsTableEmpty predicate' ($vb.Contains('HomeLegacyBestSection.Visible = Not IsTableEmpty(bestRows)') -and $section.Contains('visible="false"'))
    $scenarioNames=@('empty','verified-sales-only','sales-and-generic','generic','zero-null-unverified','editorial-duplicates','same-id-different-TCId','distinct-variant-keys','other-tenant-metrics')
    foreach($tenant in @('Tech','Food')) {
        $company=if($tenant -eq 'Tech'){101}else{202}
        foreach($scenario in $scenarioNames) {
            $sales=Pool $tenant $company;$fallback=Pool $tenant $company
            $words=@('Alpha','Bravo','Charlie','Delta','Echo','Foxtrot','Hotel','India','Juliet','Kilo')
            switch($scenario) {
                'empty' {}
                'verified-sales-only' { for($i=0;$i -lt 4;$i++){Row $sales $tenant $company ($i+1) ($i+10) $words[$i] 20} }
                'sales-and-generic' { Row $sales $tenant $company 1 10 'Alpha' 1;for($i=1;$i -lt 10;$i++){Row $fallback $tenant $company ($i+1) ($i+10) $words[$i] 0} }
                'generic' { for($i=0;$i -lt 10;$i++){Row $fallback $tenant $company ($i+1) ($i+10) $words[$i] 0} }
                'zero-null-unverified' { Row $sales $tenant $company 1 10 'Alpha' 0;Row $sales $tenant $company 2 11 'Bravo' $null;Row $sales $tenant $company 3 12 'Charlie' 200 }
                'editorial-duplicates' { Row $sales $tenant $company 1 10 'Alpha' 10;Row $fallback $tenant $company 2 20 'Alpha' 0;Row $fallback $tenant $company 3 30 'Bravo' 0 }
                'same-id-different-TCId' { Row $sales $tenant $company 1 10 'Alpha' 10;Row $fallback $tenant $company 1 20 'Alpha' 0;Row $fallback $tenant $company 2 30 'Bravo' 0 }
                'distinct-variant-keys' { Row $sales $tenant $company 1 10 'Alpha' 10;Row $fallback $tenant $company 1 20 'Bravo' 0 }
                'other-tenant-metrics' { Row $sales $tenant (303-$company) 1 10 'Alpha' 500 }
            }
            $sources=[Data.DataTable[]]@($sales,$fallback)
            $inputBefore=(Table-Xml $sales)+(Table-Xml $fallback)
            $b1=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            $d1=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            $b2=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            $d2=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
            $before=$baseline.SelectFixtureRows($b1,$d1,$sources);$after=$candidate.SelectFixtureRows($b2,$d2,$sources)
            Check "$tenant/$scenario full row values/order/count parity" ((Table-Xml $before) -ceq (Table-Xml $after))
            Check "$tenant/$scenario source rows not changed" ($inputBefore -ceq ((Table-Xml $sales)+(Table-Xml $fallback)))
            Check "$tenant/$scenario reservations unchanged" ((@($b1|Sort-Object)-join '|') -ceq (@($b2|Sort-Object)-join '|') -and (@($d1|Sort-Object)-join '|') -ceq (@($d2|Sort-Object)-join '|'))
            $visible=$candidate.FixtureVisible($after)
            Check "$tenant/$scenario no empty section" ($visible -eq ($after.Rows.Count -gt 0) -and $visible -eq $baseline.FixtureVisible($before))
            Check "$tenant/$scenario no unsupported or cross-tenant title" ((Render-Title) -ceq $title -and $title -notmatch 'Best Seller|Tech|Food|personalizz|valutat')
            if($scenario -in @('generic','sales-and-generic')){Check "$tenant/$scenario still eight selected" ($after.Rows.Count -eq 8)}
            if($scenario -eq 'same-id-different-TCId'){Check "$tenant editorial key does not attest variants" ($after.Rows.Count -eq 2 -and [int]$after.Rows[0].TCId -eq 10)}
            if($scenario -eq 'distinct-variant-keys'){Check "$tenant distinct variant identities preserved" ($after.Rows.Count -eq 2 -and [int]$after.Rows[0].id -eq [int]$after.Rows[1].id -and [int]$after.Rows[0].TCId -ne [int]$after.Rows[1].TCId)}
            $cards=foreach($r in $after.Rows){'<article class="ks-claim-fixture-card" data-id="'+$r.id+'" data-tcid="'+$r.TCId+'"><p>'+[Web.HttpUtility]::HtmlEncode([string]$r.Descrizione1)+'</p><p>Prezzo sintetico '+[Web.HttpUtility]::HtmlEncode([string]$r.PrezzoIvato)+'</p></article>'}
            $fragment=''
            if($visible) {
                $fragment=$section.Replace($literalMatch.Value,$title)
                $template=[regex]::Match($section,'(?s)<ItemTemplate>(.*?)</ItemTemplate>').Groups[1].Value
                $rendered=foreach($card in $cards){$template.Replace('<%# RenderGridCard(Container.DataItem) %>',$card)}
                $fragment=[regex]::Replace($fragment,'(?s)<asp:Repeater\b.*?</asp:Repeater>',[Text.RegularExpressions.MatchEvaluator]{param($m) return ($rendered -join '')})
                $fragment=$fragment -replace '\srunat="server"','' -replace '\svisible="false"',''
            }
            $file=$tenant+'-'+$scenario+'.html';[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $file),$fragment,$utf8)
            $fixtures.Add([pscustomobject]@{Tenant=$tenant;Scenario=$scenario;Rows=$after.Rows.Count;File=$file;Identities=@($after.Rows|ForEach-Object{[string]$_.id+':'+[string]$_.TCId})})
        }
    }
    # Synthetic verified-only provenance belongs to the fixture oracle, not a new runtime contract.
    # The current pools do not carry an authoritative company+id+TCId sales attestation.
    Check 'title does not consult data/session/DB' ($literalMatch.Value -notmatch '<%|Eval|Bind|Connection|Session' -and $vb -notmatch '(?im)^\s*[^''\r\n].*litHomeBestSellerTitle\s*\.')
    $report=[pscustomobject]@{Passed=$checks.Count;Failed=0;Checks=$checks;Fixtures=$fixtures;Title=$literal.Text;Baseline=$BaselineRef;Scope='Differential execution of verbatim baseline/candidate VB selectors with synthetic DataTables; real encoded Literal. No SQL, full Page lifecycle or real commercial certification. Browser cards are explicit stand-ins; actual card renderer is source-identical.';VerifiedOnlyFixturePolicy='Neutral also for synthetic verified-only rows: no authoritative production sales-provenance contract is available, so no positive bestseller branch is invented.';SourceHashes=@{VB=(Get-FileHash (Join-Path $RepositoryRoot 'Default.aspx.vb') -Algorithm SHA256).Hash;ASPX=(Get-FileHash (Join-Path $RepositoryRoot 'Default.aspx') -Algorithm SHA256).Hash}}
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'test-report.json'),($report|ConvertTo-Json -Depth 10),$utf8)
    Write-Output ('HOME_CLAIM_PASS='+$checks.Count)
    Write-Output ('HOME_CLAIM_FIXTURES='+$fixtures.Count)
} finally {
    if($compiler){$compiler.Dispose()}
    if((Test-Path -LiteralPath $work) -and [IO.Path]::GetFullPath($work).StartsWith($temp+'\ks-home-claim-compile-',[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $work -Recurse -Force}
}
