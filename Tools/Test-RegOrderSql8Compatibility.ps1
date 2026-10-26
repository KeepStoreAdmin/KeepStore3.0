[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaselineRef = '8b17b29254df8f71d3e1c08578ca8af9f123d7eb',
    [switch]$RunIsolatedMySql,
    [string]$IsolatedMySqlRunner,
    [string]$ExpectedServerUuid,
    [string]$ExpectedDatabase
)
$ErrorActionPreference='Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'SQL8_TEST_REQUIRES_PS51' }
if (!$RepositoryRoot) { $RepositoryRoot=Split-Path -Parent $PSScriptRoot }
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if ($EvidenceDirectory.StartsWith($RepositoryRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $EvidenceDirectory)) { throw 'SQL8_EVIDENCE_PATH_INVALID' }
New-Item -ItemType Directory -Path $EvidenceDirectory | Out-Null
$checks=New-Object 'Collections.Generic.List[object]'
$sqlCalls=0
$utf8=New-Object Text.UTF8Encoding($false)
function Check([string]$name,[bool]$pass) {
    $checks.Add([pscustomobject]@{Name=$name;Pass=$pass})
    if (!$pass) { throw ('SQL8_ASSERT: '+$name) }
}
function Read-Baseline([string]$path) {
    if ($BaselineRef -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or $path -notmatch '^[A-Za-z0-9_./-]+$') { throw 'SQL8_BASELINE_ARGUMENT_INVALID' }
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=(Get-Command git.exe -ErrorAction Stop).Source
    $info.WorkingDirectory=$RepositoryRoot
    $info.Arguments='show '+$BaselineRef+':'+$path
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=New-Object Text.UTF8Encoding($false,$true)
    $process=[Diagnostics.Process]::Start($info)
    try {
        $value=$process.StandardOutput.ReadToEnd()
        $ignored=$process.StandardError.ReadToEnd();$process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw 'SQL8_BASELINE_UNAVAILABLE' }
        return $value
    } finally { $process.Dispose() }
}
function Candidate-Expression([string]$source) {
    $m=[regex]::Match($source,'(?s)Private Function LoadCandidates\b.*?Dim sql As String = (?<sql>.*?)\s+Using cmd As New MySqlCommand')
    if (!$m.Success) { throw 'SQL8_CANDIDATE_EXPRESSION_MISSING' }
    return $m.Groups['sql'].Value
}
function Literal-Sql([string]$expression) {
    $pattern='"(?:""|[^"])*"'
    if (([regex]::Replace($expression,$pattern,'') -replace '[\s&_]','') -ne '') { throw 'SQL8_EXPECTED_LITERAL_EXPRESSION' }
    return (@([regex]::Matches($expression,$pattern) | ForEach-Object {
        $_.Value.Substring(1,$_.Value.Length-2).Replace('""','"')
    }) -join '')
}
function Source-Method([string]$source,[string]$name) {
    $m=[regex]::Match($source,'(?ms)^    Private Shared Function '+$name+'\b.*?^    End Function')
    if (!$m.Success) { throw ('SQL8_SOURCE_METHOD_MISSING '+$name) }
    return $m.Value.Replace('Private Shared Function','Public Shared Function')
}
function Facet-Expression([string]$source,[string]$name) {
    $m=[regex]::Match($source,'(?ms)^        Me\.sds'+$name+'\.SelectCommand =\s*(?<sql>.*?)^\s*\r?$')
    if (!$m.Success) { throw ('SQL8_FACET_EXPRESSION_MISSING '+$name) }
    return $m.Groups['sql'].Value
}
function Sql([string]$statement) {
    $script:sqlCalls++
    $answer=& $IsolatedMySqlRunner -Sql $statement
    if ($null -eq $answer -or $null -eq $answer.code) { throw 'SQL8_RUNNER_CONTRACT_INVALID' }
    return $answer
}
function Rows([string]$statement) {
    $r=Sql $statement
    if ($r.code -ne 0) {
        $code=[regex]::Match([string]$r.stderr,'ERROR\s+(\d+)').Groups[1].Value
        throw ('SQL8_MYSQL_ERROR_'+$code)
    }
    return @(([string]$r.stdout -split '\r?\n') | Where-Object {$_ -ne ''})
}
function Bound([string]$statement,[int]$listino,[int]$id) {
    return $statement.Replace('?listino',$listino.ToString()).Replace('?NListino',$listino.ToString()).Replace('?id',$id.ToString())
}

$cart=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CartPriceRevalidationHelper.vb'))
$catalog=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articoli.aspx.vb'))
$oldCart=Read-Baseline 'App_Code/CartPriceRevalidationHelper.vb'
$oldCatalog=Read-Baseline 'articoli.aspx.vb'
$candidate=Literal-Sql (Candidate-Expression $cart)
$legacy=Literal-Sql (Candidate-Expression $oldCart)
$result='FAIL'
try {
    Check 'cart retains parameters and inner exact DISTINCT projection' ($candidate.Contains('SELECT DISTINCT v.ID, COALESCE(v.TCid,-1) AS TCid') -and $candidate.Contains('v.NListino=?listino AND v.ID=?id) c'))
    Check 'cart orders only after deduplication' ($candidate.Contains('ORDER BY c.ID, CASE WHEN c.TCid IN (-1,0) THEN 0 ELSE 1 END, c.TCid ASC'))
    $cartInvariant=$cart.Replace((Candidate-Expression $cart),'SQL_EXPRESSION') -replace '\r\n',"`n"
    $oldInvariant=$oldCart.Replace((Candidate-Expression $oldCart),'SQL_EXPRESSION') -replace '\r\n',"`n"
    Check 'price resolution fiscal promotion locks and transaction code unchanged' ($cartInvariant.TrimEnd() -ceq $oldInvariant.TrimEnd())
    Check 'catalog no ambiguous GROUP BY id or ANY_VALUE' ($catalog -notmatch '(?i)GROUP BY id"|ANY_VALUE\s*\(')
    Check 'catalog applies filters before rank and sorts after selection' ($catalog.Contains('BuildCatalogListingSql(strSelect, strWhere, sortSql)'))
    $methodPattern='(?ms)^    (?:Private|Protected|Public|Friend) (?:Shared )?(?:Function|Sub) (\w+)\b.*?^    End (?:Function|Sub)'
    foreach ($m in [regex]::Matches($oldCatalog,$methodPattern)) {
        $name=$m.Groups[1].Value
        if ($name -eq 'CaricaArticoli') { continue }
        Check ('unaffected catalog method '+$name) ($catalog.Contains($m.Value.Replace("`n","`r`n")) -or $catalog.Replace("`r`n","`n").Contains($m.Value))
    }
    $methods=@('BuildCatalogRowRankSql','BuildCatalogListingSql','BuildCatalogArrivalsJoinSql') | ForEach-Object {Source-Method $catalog $_}
    $facets=@('Marche','Tipologie','Gruppo','Sottogruppo')
    $facetMethods=foreach ($name in $facets) {
        'Public Shared Function Facet'+$name+'(ByVal strWhere2 As String) As String'+"`r`n Return "+(Facet-Expression $catalog $name)+"`r`nEnd Function"
    }
    $vb="Imports System`r`nImports System.Text.RegularExpressions`r`nPublic Class RegOrderSql8SourceQueries`r`n"+($methods -join "`r`n")+"`r`n"+($facetMethods -join "`r`n")+"`r`nEnd Class"
    Add-Type -TypeDefinition $vb -Language VisualBasic -ReferencedAssemblies @('System.dll')
    Check 'real source SQL methods compile on .NET Framework' $true
    $rank=[RegOrderSql8SourceQueries]::BuildCatalogRowRankSql()
    Check 'catalog reuses positive TC default priority already present in recently viewed' ($rank.Contains('CASE WHEN COALESCE(vsuperarticoli.TCid,0)>0 THEN 0 ELSE 1 END') -and $rank.Contains('COALESCE(vsuperarticoli.ArticoliListiniId,0)'))
    if ($RunIsolatedMySql) {
        if (!$IsolatedMySqlRunner -or !(Test-Path -LiteralPath $IsolatedMySqlRunner -PathType Leaf) -or
            $ExpectedServerUuid -notmatch '^[0-9a-f-]{36}$' -or $ExpectedDatabase -notmatch '^[a-zA-Z0-9_]+$') { throw 'SQL8_EXPLICIT_LAB_ARGUMENTS_REQUIRED' }
        $identity=@(Rows 'SELECT DATABASE(),@@server_uuid,@@port,@@version,@@session.sql_mode;')
        $parts=$identity[0] -split "`t"
        Check 'explicit database and server UUID match before SQL tests' ($parts[0] -ceq $ExpectedDatabase -and $parts[1] -ceq $ExpectedServerUuid)
        Check 'real MySQL 8 strict mode remains active' ($parts[3] -like '8.*' -and $parts[4] -match '(^|,)ONLY_FULL_GROUP_BY(,|$)')
        $sqlMode=$parts[4]
        $cte=@'
WITH vsuperarticoli(ID,TCid,Codice,Descrizione1,Prezzo,PrezzoIvato,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,NListino) AS (
 SELECT 901,NULL,'SYNTHETIC_BASE','SYNTHETIC_PRODUCT',CAST(10 AS DECIMAL(18,8)),CAST(12.2 AS DECIMAL(18,8)),-1,-1,'',1
 UNION ALL SELECT 901,-1,'SYNTHETIC_BASE','SYNTHETIC_PRODUCT',10,12.2,-1,-1,'',1
 UNION ALL SELECT 901,0,'SYNTHETIC_BASE','SYNTHETIC_PRODUCT',10,12.2,-1,-1,'',1
 UNION ALL SELECT 901,9,'SYNTHETIC_TC9','SYNTHETIC_PRODUCT',19,23.18,-1,-1,'',1
 UNION ALL SELECT 901,5,'SYNTHETIC_TC5','SYNTHETIC_PRODUCT',15,18.3,-1,-1,'',1
 UNION ALL SELECT 901,5,'SYNTHETIC_TC5','SYNTHETIC_PRODUCT',15,18.3,-1,-1,'',1
 UNION ALL SELECT 901,7,'SYNTHETIC_RC','SYNTHETIC_PRODUCT',17,20.74,88,0,'SYNTHETIC_RC',1
 UNION ALL SELECT 901,-1,'SYNTHETIC_LIST10','SYNTHETIC_PRODUCT',12,14.64,-1,-1,'',10
 UNION ALL SELECT 902,-1,'SYNTHETIC_OTHER','SYNTHETIC_PRODUCT',99,120.78,-1,-1,'',1
)
'@
        $bad=Sql ($cte+(Bound $legacy 1 901)+';')
        Check 'original exact cart query reproduces MySQL 3065' ($bad.code -ne 0 -and $bad.stderr -match 'ERROR\s+3065\b')
        $rows=@(Rows ($cte+(Bound $candidate 1 901)+';'))
        $ids=@($rows | ForEach-Object {($_ -split "`t")[1]})
        Check 'cart exact dedup preserves normalized base and distinct variants' ($rows.Count -eq 5)
        Check 'cart deterministic base then ascending TC priority' (($ids -join ',') -ceq '-1,0,5,7,9')
        $base=$rows[0] -split "`t";$rc=$rows[3] -split "`t"
        Check 'cart net and gross unchanged' ([decimal]$base[4] -eq 10 -and [decimal]$base[5] -eq 12.2)
        Check 'cart reverse charge identifiers rates text and prices unchanged' ($rc[6] -eq '88' -and $rc[7] -eq '0' -and $rc[8] -eq 'SYNTHETIC_RC' -and [decimal]$rc[4] -eq 17 -and [decimal]$rc[5] -eq 20.74)
        $other=@(Rows ($cte+(Bound $candidate 10 901)+';'))
        Check 'cart listino 10 isolated from listino 1' ($other.Count -eq 1 -and ($other[0] -split "`t")[2] -eq 'SYNTHETIC_LIST10' -and [decimal]($other[0] -split "`t")[5] -eq 14.64)
        Check 'cart missing article returns no fallback row' (@(Rows ($cte+(Bound $candidate 1 999)+';')).Count -eq 0)

        $listingCte=@'
WITH vsuperarticoli(id,TCid,ArticoliListiniId,OfferteDettagliId,NListino,Prezzo,Giacenza,Impegnata,TagliaId) AS (
 SELECT 901,-1,1,0,1,CAST(10 AS DECIMAL(18,8)),100,0,0
 UNION ALL SELECT 901,9,1,0,1,99,9,2,2
 UNION ALL SELECT 901,5,1,0,1,15,5,1,1
 UNION ALL SELECT 902,-1,2,0,1,20,20,0,0
 UNION ALL SELECT 901,-1,3,0,10,12,50,0,0
)
'@
        $select='SELECT vsuperarticoli.id,vsuperarticoli.TCid,vsuperarticoli.Prezzo,vsuperarticoli.Giacenza,vsuperarticoli.Impegnata,'+$rank+' FROM vsuperarticoli'
        $query=[RegOrderSql8SourceQueries]::BuildCatalogListingSql($select,'',' ORDER BY id')
        $listed=@(Rows ($listingCte+(Bound $query 1 0)+';'))
        Check 'listing has one row per article no multiplied variants' ($listed.Count -eq 2)
        $chosen=$listed[0] -split "`t"
        Check 'listing selected TC price and stock belong to the same row' ($chosen[1] -eq '5' -and [decimal]$chosen[2] -eq 15 -and [decimal]$chosen[3] -eq 5 -and [decimal]$chosen[4] -eq 1)
        $filtered=[RegOrderSql8SourceQueries]::BuildCatalogListingSql($select,' AND vsuperarticoli.TagliaId=2',' ORDER BY id')
        $filteredRows=@(Rows ($listingCte+(Bound $filtered 1 0)+';'))
        Check 'variant filter precedes representative selection' ($filteredRows.Count -eq 1 -and ($filteredRows[0] -split "`t")[1] -eq '9')
        $priceFiltered=[RegOrderSql8SourceQueries]::BuildCatalogListingSql($select,' AND vsuperarticoli.Prezzo>90',' ORDER BY id')
        Check 'price predicate precedes representative selection' (@(Rows ($listingCte+(Bound $priceFiltered 1 0)+';')).Count -eq 1)
        $paged=[RegOrderSql8SourceQueries]::BuildCatalogListingSql($select,'',' ORDER BY id DESC LIMIT 1 OFFSET 1')
        $page=@(Rows ($listingCte+(Bound $paged 1 0)+';'))
        Check 'pagination counts articles after variant dedup' ($page.Count -eq 1 -and ($page[0] -split "`t")[0] -eq '901')
        $list10=@(Rows ($listingCte+(Bound $query 10 0)+';'))
        Check 'listing listino remains scoped before rank' ($list10.Count -eq 1 -and [decimal]($list10[0] -split "`t")[2] -eq 12)

        $facetCte=@'
WITH varticolibase(id,MarcheId,TipologieId,GruppiId,SottoGruppiId) AS (SELECT 901,1,1,1,1 UNION ALL SELECT 902,2,2,2,2),
vsuperarticoli(id,NListino) AS (SELECT 901,1 UNION ALL SELECT 901,1 UNION ALL SELECT 902,1 UNION ALL SELECT 902,10),
Marche(id,Descrizione,Ordinamento) AS (SELECT 1,'SYNTHETIC_SHARED',1 UNION ALL SELECT 2,'SYNTHETIC_SHARED',1),
tipologie(id,Descrizione,Ordinamento) AS (SELECT 1,'SYNTHETIC_SHARED',1 UNION ALL SELECT 2,'SYNTHETIC_SHARED',1),
Gruppi(id,Descrizione,Ordinamento) AS (SELECT 1,'SYNTHETIC_SHARED',2 UNION ALL SELECT 2,'SYNTHETIC_SHARED',1),
SottoGruppi(id,Descrizione,Ordinamento) AS (SELECT 1,'SYNTHETIC_SHARED',1 UNION ALL SELECT 2,'SYNTHETIC_SHARED',1)
'@
        $where=' LEFT JOIN vsuperarticoli ON vsuperarticoli.Id=varticolibase.id WHERE vsuperarticoli.NListino=1'
        foreach ($name in $facets) {
            $method=[RegOrderSql8SourceQueries].GetMethod('Facet'+$name)
            $statement=[string]$method.Invoke($null,@($where))
            $data=@(Rows ($facetCte+$statement+';'))
            if ($name -eq 'Gruppo') {
                $fields=$data[0] -split "`t"
                Check 'group facet retains merged IDs and distinct article count' ($data.Count -eq 1 -and (($fields[0] -split '\|' | Sort-Object) -join ',') -eq '1,2' -and $fields[3] -eq '2')
                Check 'group label uses deterministic minimum display order' ($fields[2] -eq '1')
            } else {
                Check ($name+' distinct IDs are not lost for equal labels') ($data.Count -eq 2)
                Check ($name+' counts distinct articles despite variant joins') (@($data | Where-Object {($_ -split "`t")[3] -ne '1'}).Count -eq 0)
            }
        }
        $arrivalCte=@'
WITH vsuperarticoli(id) AS (SELECT 901 UNION ALL SELECT 902),
articoli_arrivi(articoliid,dataArrivo,arrivi) AS (
 SELECT 901,DATE_ADD(CURDATE(),INTERVAL 2 DAY),CAST(2 AS DECIMAL(18,5))
 UNION ALL SELECT 901,DATE_ADD(CURDATE(),INTERVAL 2 DAY),3
 UNION ALL SELECT 902,DATE_ADD(CURDATE(),INTERVAL 2 DAY),7
 UNION ALL SELECT 901,DATE_ADD(CURDATE(),INTERVAL 3 DAY),4
 UNION ALL SELECT 901,DATE_SUB(CURDATE(),INTERVAL 1 DAY),100
)
'@
        $arrival=@(Rows ($arrivalCte+'SELECT vsuperarticoli.id,arrivi.arrivi FROM vsuperarticoli'+[RegOrderSql8SourceQueries]::BuildCatalogArrivalsJoinSql()+' ORDER BY vsuperarticoli.id;'))
        Check 'arrivals aggregate per article and date not across articles' ($arrival.Count -eq 2 -and $arrival[0].Contains('</td><td>5') -and $arrival[1].Contains('</td><td>7'))
        Check 'arrivals retain multiple dates and exclude past quantities' ($arrival[0].Contains('</td><td>4') -and !$arrival[0].Contains('</td><td>100'))
        $finalMode=@(Rows 'SELECT @@session.sql_mode;')
        Check 'SQL mode unchanged after all tests' ($finalMode[0] -ceq $sqlMode)
    }
    $result='PASS'
} finally {
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'source-query-results.json'),(@{Result=$result;Checks=$checks.Count;Details=$checks;MySqlExecuted=[bool]$RunIsolatedMySql;SqlCalls=$sqlCalls;ReadOnlyCteFixtures=$true;RuntimeBrowserSeparate=$true}|ConvertTo-Json -Depth 6),$utf8)
}
Write-Output ('SQL8_'+$result+' checks='+$checks.Count+' mysql='+[bool]$RunIsolatedMySql+' sqlCalls='+$sqlCalls)
