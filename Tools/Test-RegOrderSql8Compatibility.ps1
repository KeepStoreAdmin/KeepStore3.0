[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaselineRef = '8b17b29254df8f71d3e1c08578ca8af9f123d7eb',
    [switch]$RunIsolatedMySql,
    [string]$IsolatedMySqlRunner,
    [string]$ExpectedServerUuid,
    [string]$ExpectedDatabase,
    [switch]$PromoOnly,
    [switch]$CheckoutOnly
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

if ($CheckoutOnly) {
    Add-Type -AssemblyName System.Web
    if ($PromoOnly -or !$RunIsolatedMySql -or !(Test-Path -LiteralPath $IsolatedMySqlRunner)) { throw 'SQL8_CHECKOUT_REQUIRES_ISOLATED_MYSQL' }
    $markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'carrello.aspx'))
    $oldMarkup=Read-Baseline 'carrello.aspx'
    $pattern='(?s)<asp:SqlDataSource ID="sdsPagamento".*?SelectCommand="(?<sql>[^"]*)"'
    $match=[regex]::Match($markup,$pattern)
    $oldMatch=[regex]::Match($oldMarkup,$pattern)
    Check 'payment datasource remains unique' ($match.Success -and $oldMatch.Success -and [regex]::Matches($markup,$pattern).Count -eq 1)
    $query=[Web.HttpUtility]::HtmlDecode($match.Groups['sql'].Value)
    $oldQuery=[Web.HttpUtility]::HtmlDecode($oldMatch.Groups['sql'].Value)
    $masked=$markup.Replace($match.Groups['sql'].Value,'PAYMENT_SQL').Replace("`r`n","`n").TrimEnd("`n")
    $oldMasked=$oldMarkup.Replace($oldMatch.Groups['sql'].Value,'PAYMENT_SQL').Replace("`r`n","`n").TrimEnd("`n")
    Check 'only payment SQL changes in checkout markup' ($masked -ceq $oldMasked)
    Check 'no arbitrary group any value or wildcard' ($query -notmatch '(?i)GROUP\s+BY|ANY_VALUE|SELECT\s+\*')
    Check 'tenant gates payment and bank before choices' ($query -match 'p\.AziendeID=\?AziendaID' -and $query -match 'p\.AziendeID=b\.AziendeId' -and $query -match 'b\.AziendeId=\?AziendaID')
    Check 'client association authorizes without multiplying payment' ($query -match 'EXISTS \(SELECT 1 FROM utentirapporto ur WHERE ur.TipoPagamento=p.id AND ur.UtenteId=\?UtenteID\)')
    Check 'ambiguous bank configuration is not ranked arbitrarily' ($query -match 'COUNT\(1\) OVER' -and $query -match 'b.ConfigCount=1' -and $query -notmatch '(?i)ROW_NUMBER|MIN\(|MAX\(')
    foreach ($path in @('carrello.aspx.vb','App_Code/CheckoutDraftService.vb','App_Code/PayPalCheckoutSafetyPolicy.vb')) {
        $actual=[IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n").TrimEnd("`n")
        $before=(Read-Baseline $path).Replace("`r`n","`n").TrimEnd("`n")
        Check ('authoritative source unchanged '+$path) ($actual -ceq $before)
    }
    $result='FAIL'
    try {
        $identity=@(Rows 'SELECT DATABASE(),@@server_uuid,@@sql_mode;')
        $parts=$identity[0] -split "`t"
        Check 'checkout SQL targets exact strict lab' ($parts[0] -ceq $ExpectedDatabase -and $parts[1] -ceq $ExpectedServerUuid -and $parts[2] -match 'ONLY_FULL_GROUP_BY')
        $mode=$parts[2]
        function Payment-Bound([string]$sql,[int]$company,[int]$user,[decimal]$amount) {
            return $sql.Replace('?AziendaID',$company.ToString()).Replace('?UtenteID',$user.ToString()).Replace('?CostoMassimo',$amount.ToString([Globalization.CultureInfo]::InvariantCulture))
        }
        $old=Sql ((Payment-Bound $oldQuery 1 1 24.4)+';')
        Check 'installed original payment query reproduces 1055' ($old.code -ne 0 -and $old.stderr -match 'ERROR\s+1055')
        # CTEs replace only data sources. Candidate SQL below is extracted from
        # the real datasource; no persistent tables, banking profiles or users.
        $fixture=@'
WITH pagamentitipo(id,AziendeID,Descrizione,Informazioni,Abilitato,Web,Ordinamento,Predefinito,CostoPercentuale,CostoFisso,CostoMassimo,NumeroOrdini,Contrassegno,OnLine,img) AS (
SELECT 101,1,'SYNTHETIC-PUBLIC','',1,1,1,1,2.50,1.25,100,0,0,0,''
UNION ALL SELECT 102,1,'SYNTHETIC-PRIVATE','',1,0,2,0,1.00,3.00,100,0,0,0,''
UNION ALL SELECT 103,1,'SYNTHETIC-DISABLED','',0,1,3,0,0,0,100,0,0,0,''
UNION ALL SELECT 104,2,'SYNTHETIC-TENANT2','',1,1,1,1,0,2.00,100,0,0,0,''
UNION ALL SELECT 105,1,'SYNTHETIC-CAPPED','',1,1,5,0,0,0,20,0,0,0,''
UNION ALL SELECT 106,1,'SYNTHETIC-OTHERCLIENT','',1,0,6,0,0,0,100,0,0,0,''
UNION ALL SELECT 107,1,'SYNTHETIC-DUPBANK','',1,1,7,0,0,0,100,0,0,0,''
UNION ALL SELECT 108,1,'SYNTHETIC-AMBIGUOUS','',1,1,8,0,0,0,100,0,0,0,''
UNION ALL SELECT 109,1,'SYNTHETIC-INCOMPLETEBANK','',1,1,9,0,0,0,100,0,0,0,''
UNION ALL SELECT 110,1,'SYNTHETIC-NULLPERCENT','',1,1,10,0,NULL,0,100,0,0,0,''
UNION ALL SELECT 111,1,'SYNTHETIC-NULLPOLICY','',1,1,11,0,0,0,100,0,0,NULL,''
UNION ALL SELECT 112,1,'SYNTHETIC-NULLFIXED','',1,1,12,0,0,NULL,100,0,0,0,''
UNION ALL SELECT 113,1,'SYNTHETIC-PAYPAL-FLAG','',1,1,13,0,0,0,100,0,0,2,''
), utentirapporto(TipoPagamento,UtenteId) AS (
SELECT 101,11 UNION ALL SELECT 101,22 UNION ALL SELECT 102,11 UNION ALL SELECT 102,11 UNION ALL SELECT 106,22
), vbancasella_azienda(AziendeId,PagamentiTipoId,URL1,URL2,Nome,shopLogin,Attivo) AS (
SELECT 2,101,'','','SYNTHETIC-FOREIGN','SYNTHETIC-FOREIGN',1
UNION ALL SELECT 1,107,'','','SYNTHETIC-OWN','SYNTHETIC-OWN',1
UNION ALL SELECT 1,107,'','','SYNTHETIC-OWN','SYNTHETIC-OWN',1
UNION ALL SELECT 2,107,'','','SYNTHETIC-FOREIGN','SYNTHETIC-FOREIGN',1
UNION ALL SELECT 1,108,'','','SYNTHETIC-A','SYNTHETIC-A',1
UNION ALL SELECT 1,108,'','','SYNTHETIC-B','SYNTHETIC-B',1
UNION ALL SELECT 1,109,'','','SYNTHETIC-MISSING',NULL,1
UNION ALL SELECT 1,101,'','','SYNTHETIC-INACTIVE','SYNTHETIC-INACTIVE',0
),
'@
        function Payment-Rows([int]$company,[int]$user,[decimal]$amount) {
            $sql=Payment-Bound $query $company $user $amount
            if (!$sql.StartsWith('WITH ')) { throw 'CHECKOUT_EXPECTED_CTE' }
            return @(Rows ($fixture+$sql.Substring(5)+';'))
        }
        $one=@(Payment-Rows 1 11 24.4)
        $oneIds=@($one|ForEach-Object {($_ -split "`t")[0]})
        Check 'one exact row per authorized payment in presentation order' (($oneIds -join ',') -ceq '101,102,107,113')
        Check 'payment still projects all twenty legacy fields' (@($one|Where-Object {$_.Split([char]9).Count -ne 20}).Count -eq 0)
        $public=$one[0].Split([char]9)
        Check 'public method keeps tenant identity and default' ($public[1] -eq '1' -and $public[7] -eq '1')
        Check 'percentage fixed cost and cap unchanged' ([decimal]$public[8] -eq 2.5 -and [decimal]$public[9] -eq 1.25 -and [decimal]$public[10] -eq 100)
        Check 'foreign banking configuration does not populate own method' (($public[16..19] -join '') -eq '')
        Check 'client-specific association retains same base payment costs' ([decimal]($one[1] -split "`t")[8] -eq 1 -and [decimal]($one[1] -split "`t")[9] -eq 3)
        $bank=$one[2].Split([char]9)
        Check 'identical own banking rows deduplicate and foreign row excluded' ($bank[19] -ceq 'SYNTHETIC-OWN')
        Check 'ambiguous incomplete and disabled payments are absent' (@($oneIds|Where-Object {$_ -in @('103','106','108','109','110','111','112')}).Count -eq 0)
        Check 'online policy value reaches unchanged safety authority' (($one[3] -split "`t")[13] -eq '2')
        $two=@(Payment-Rows 2 22 24.4)
        Check 'company two sees only its payment and fixed cost' ($two.Count -eq 1 -and ($two[0] -split "`t")[0] -eq '104' -and [decimal]($two[0] -split "`t")[9] -eq 2)
        $other=@(Payment-Rows 1 99 24.4)
        Check 'private payment is not enabled for unrelated customer' (($other|ForEach-Object {($_ -split "`t")[0]}) -join ',' -eq '101,107,113')
        $edge=@(Payment-Rows 1 11 20)
        Check 'amount cap includes exact boundary' (@($edge|Where-Object {($_ -split "`t")[0] -eq '105'}).Count -eq 1)
        $over=@(Payment-Rows 1 11 20.01)
        Check 'amount cap excludes excess before deduplication' (@($over|Where-Object {($_ -split "`t")[0] -eq '105'}).Count -eq 0)
        Check 'all methods unavailable beyond cap' (@(Payment-Rows 1 11 100.01).Count -eq 0)
        Check 'installed source query executes under unchanged strict mode' ((Sql ((Payment-Bound $query 1 1 24.4)+';')).code -eq 0)
        $after=@(Rows 'SELECT @@sql_mode;')
        Check 'SQL mode unchanged after payment tests' ($after[0] -ceq $mode)
        $result='PASS'
    } finally {
        [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'checkout-rev2-results.json'),(@{Result=$result;Checks=$checks.Count;Details=$checks;SqlCalls=$sqlCalls;MySql='REAL_READONLY_CTE';Prior230And38='REUSED_NOT_RERUN';Browser='SEPARATE';GatewayCalls=0;PersistentFixtureWrites=0}|ConvertTo-Json -Depth 6),$utf8)
    }
    Write-Output ('SQL8_CHECKOUT_REV2_PASS checks='+$checks.Count+' sql='+$sqlCalls)
    exit 0
}

if ($PromoOnly) {
    Add-Type -AssemblyName System.Web
    $markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'carrello.aspx'))
    $oldMarkup=Read-Baseline 'carrello.aspx'
    $pattern='(?s)<asp:SqlDataSource ID="sdsPromo".*?SelectCommand="(?<sql>[^"]*)"'
    $matches=[regex]::Matches($markup,$pattern)
    $oldMatches=[regex]::Matches($oldMarkup,$pattern)
    $result='FAIL'
    try {
        Check 'two promo datasources remain present' ($matches.Count -eq 2 -and $oldMatches.Count -eq 2)
        $query=[Web.HttpUtility]::HtmlDecode($matches[0].Groups['sql'].Value)
        Check 'standard and free shipping use identical promo SQL' ($matches[0].Groups['sql'].Value -ceq $matches[1].Groups['sql'].Value)
        Check 'promo selects exact rows without GROUP BY ANY_VALUE or star' ($query -notmatch '(?i)GROUP BY|ANY_VALUE|SELECT\s+(?:\w+\.)?\*' -and $query.Contains('SELECT DISTINCT'))
        Check 'promo binds server cart TC before deduplication' ($query.Contains('COALESCE(TCid,-1)=?TCId') -and [regex]::Matches($markup,'<asp:ControlParameter Name="TCId" ControlID="tbTCID" PropertyName="Text" Type="Int32" DefaultValue="-1" />').Count -eq 2)
        $masked=$markup.Replace($matches[0].Groups['sql'].Value,'PROMO_SQL')
        $masked=[regex]::Replace($masked,'(?m)^\s*<asp:ControlParameter Name="TCId" ControlID="tbTCID"[^\r\n]*/>\r?\n','')
        $oldMasked=$oldMarkup.Replace($oldMatches[0].Groups['sql'].Value,'PROMO_SQL')
        Check 'markup unchanged outside the two SQL expressions and TC parameters' (($masked -replace '\r\n',"`n").TrimEnd() -ceq ($oldMasked -replace '\r\n',"`n").TrimEnd())
        $cartCode=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'carrello.aspx.vb'))
        $helper=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/ProductPromotionDisplayHelper.vb'))
        Check 'cart code behind and promotion display authority unchanged' (($cartCode -replace '\r\n',"`n").TrimEnd() -ceq ((Read-Baseline 'carrello.aspx.vb') -replace '\r\n',"`n").TrimEnd() -and ($helper -replace '\r\n',"`n").TrimEnd() -ceq ((Read-Baseline 'App_Code/ProductPromotionDisplayHelper.vb') -replace '\r\n',"`n").TrimEnd())
        $fields=@('ID','TCid','OfferteID','OfferteDettagliId','NListino','Prezzo','PrezzoIvato','PrezzoPromo','PrezzoPromoIvato','OfferteQntMinima','OfferteMultipli','InOfferta','OfferteDataInizio','OfferteDataFine','IdIvaRC','ValoreIvaRC','DescrizioneIvaRC')
        foreach($field in $fields){Check ('promo projects '+$field) ($query.Contains('promo.'+$field))}
        $priority='CASE WHEN COALESCE(promo.OfferteMultipli,0)=10 THEN 0 WHEN COALESCE(promo.OfferteQntMinima,0)>0 THEN 1 WHEN COALESCE(promo.OfferteMultipli,0)>0 THEN 2 ELSE 3 END, COALESCE(promo.OfferteMultipli,0) ASC, COALESCE(promo.OfferteQntMinima,0) ASC, promo.PrezzoPromo DESC'
        Check 'existing quantity multiple and price precedence preserved' ($query.Contains($priority))
        if (!$RunIsolatedMySql -or !$IsolatedMySqlRunner -or !(Test-Path -LiteralPath $IsolatedMySqlRunner) -or $ExpectedServerUuid -notmatch '^[0-9a-f-]{36}$' -or $ExpectedDatabase -notmatch '^[a-zA-Z0-9_]+$'){throw 'PROMO_EXPLICIT_READONLY_LAB_REQUIRED'}
        $identity=@(Rows 'SELECT DATABASE(),@@server_uuid,@@session.sql_mode;')[0] -split "`t"
        Check 'promo tests target only explicit strict lab' ($identity[0] -ceq $ExpectedDatabase -and $identity[1] -ceq $ExpectedServerUuid -and $identity[2] -match '(^|,)ONLY_FULL_GROUP_BY(,|$)')
        $mode=$identity[2]
        $cte=@'
WITH vsuperarticoli(ID,TCid,OfferteID,OfferteDettagliId,NListino,Prezzo,PrezzoIvato,PrezzoPromo,PrezzoPromoIvato,OfferteQntMinima,OfferteMultipli,InOfferta,OfferteDataInizio,OfferteDataFine,IdIvaRC,ValoreIvaRC,DescrizioneIvaRC,Giacenza) AS (
 SELECT 901,5,11,101,1,CAST(10 AS DECIMAL(18,8)),CAST(12.2 AS DECIMAL(18,8)),CAST(8 AS DECIMAL(18,8)),CAST(9.76 AS DECIMAL(18,8)),2,0,1,DATE_SUB(CURDATE(),INTERVAL 1 DAY),DATE_ADD(CURDATE(),INTERVAL 2 DAY),-1,-1,'',100
 UNION ALL SELECT 901,5,11,101,1,10,12.2,8,9.76,2,0,1,DATE_SUB(CURDATE(),INTERVAL 1 DAY),DATE_ADD(CURDATE(),INTERVAL 2 DAY),-1,-1,'',200
 UNION ALL SELECT 901,5,12,102,1,10,12.2,6,7.32,0,10,1,NULL,NULL,-1,-1,'',100
 UNION ALL SELECT 901,5,13,103,1,10,12.2,7,8.54,0,5,1,NULL,NULL,88,0,'SYNTHETIC_RC',100
 UNION ALL SELECT 901,5,17,107,1,10,12.2,7.5,9.15,2,0,1,NULL,NULL,-1,-1,'',100
 UNION ALL SELECT 901,5,40,401,1,10,12.2,1,1.22,3,0,1,NULL,NULL,-1,-1,'',100
 UNION ALL SELECT 901,9,21,201,1,10,12.2,5,6.1,2,0,1,NULL,NULL,-1,-1,'',100
 UNION ALL SELECT 901,5,31,301,10,12,14.64,9,10.98,2,0,1,NULL,NULL,-1,-1,'',100
 UNION ALL SELECT 901,5,14,104,1,10,12.2,1,1.22,1,0,0,NULL,NULL,-1,-1,'',100
 UNION ALL SELECT 901,5,15,105,1,10,12.2,1,1.22,1,0,1,DATE_ADD(CURDATE(),INTERVAL 1 DAY),NULL,-1,-1,'',100
 UNION ALL SELECT 901,5,16,106,1,10,12.2,1,1.22,1,0,1,NULL,DATE_SUB(CURDATE(),INTERVAL 1 DAY),-1,-1,'',100
 UNION ALL SELECT 902,5,99,999,1,10,12.2,1,1.22,1,0,1,NULL,NULL,-1,-1,'',100
 UNION ALL SELECT 903,NULL,50,501,1,10,12.2,8,9.76,2,0,1,NULL,NULL,-1,-1,'',100
 UNION ALL SELECT 903,-1,50,501,1,10,12.2,8,9.76,2,0,1,NULL,NULL,-1,-1,'',200
)
'@
        function Promo-Bound([int]$article,[int]$tc,[int]$list){return $query.Replace('?ID',$article.ToString()).Replace('?TCId',$tc.ToString()).Replace('?NListino',$list.ToString())}
        $oldQuery=[Web.HttpUtility]::HtmlDecode($oldMatches[0].Groups['sql'].Value).Replace('?ID','901').Replace('?NListino','1')
        $bad=Sql ($cte+$oldQuery+';')
        Check 'original promo SQL reproduces MySQL 1055' ($bad.code -ne 0 -and $bad.stderr -match 'ERROR\s+1055\b')
        $selected=@(Rows ($cte+(Promo-Bound 901 5 1)+';'))
        $details=@($selected|ForEach-Object{($_ -split "`t")[3]})
        Check 'exact promo dedup removes only stock join copies' ($selected.Count -eq 5)
        Check 'tier precedence and deterministic detail identity' (($details -join ',') -ceq '102,101,107,401,103')
        Check 'same quantity tier retains distinct authorized detail candidates' ($details -contains '101' -and $details -contains '107')
        Check 'inactive future and expired offers absent' (@($details|Where-Object{$_ -in @('104','105','106')}).Count -eq 0)
        $variant=@(Rows ($cte+(Promo-Bound 901 9 1)+';'))
        Check 'only matching cart variant returned' ($variant.Count -eq 1 -and ($variant[0] -split "`t")[3] -eq '201')
        $list10=@(Rows ($cte+(Promo-Bound 901 5 10)+';'))
        Check 'only matching price list and base gross returned' ($list10.Count -eq 1 -and ($list10[0] -split "`t")[3] -eq '301' -and [decimal]($list10[0] -split "`t")[6] -eq 14.64)
        Check 'no offers produces empty set' (@(Rows ($cte+(Promo-Bound 999 5 1)+';')).Count -eq 0)
        $normal=@(Rows ($cte+(Promo-Bound 903 -1 1)+';'))
        Check 'NULL base TC normalizes like server SafeInt without duplicates' ($normal.Count -eq 1 -and ($normal[0] -split "`t")[1] -eq '-1')
        Check 'unmatched cart variant does not borrow another variant offer' (@(Rows ($cte+(Promo-Bound 901 99 1)+';')).Count -eq 0)
        $rc=@($selected|Where-Object{($_ -split "`t")[3] -eq '103'})[0] -split "`t"
        Check 'net gross and reverse charge fields preserve row identity' ([decimal]$rc[5] -eq 10 -and [decimal]$rc[6] -eq 12.2 -and [decimal]$rc[7] -eq 7 -and [decimal]$rc[8] -eq 8.54 -and $rc[14] -eq '88' -and $rc[15] -eq '0')
        [IO.File]::WriteAllLines((Join-Path $EvidenceDirectory 'promo-rows.tsv'),$selected,$utf8)

        # Reuse the explicit I/O fixtures of the promotion tests; compile the real display helper and item handler.
        $parity=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Tools/Test-StorefrontPromotionParity.ps1'))
        $fixture=[regex]::Match($parity,"(?s)\`$fixtureSource = @'\r?\n(.*?)\r?\n'@").Groups[1].Value
        if (!$fixture) { throw 'PROMO_EXISTING_FIXTURE_MISSING' }
        $fixture=$fixture.Substring(0,$fixture.IndexOf('Public Module PromotionDisplayFixture'))
        $resolver=@'
Public Module ProductPromotionEligibilityResolver
 Public Function CreateContext(ctx As HttpContext,listino As Integer) As ProductPromotionEligibilityContext
  Return New ProductPromotionEligibilityContext With {.Listino=listino}
 End Function
 Public Function Resolve(connectionString As String,ctx As ProductPromotionEligibilityContext,articleId As Integer,tcId As Integer,quantity As Decimal,baseNet As Decimal,baseGross As Decimal) As ProductPromotionEligibilityResult
  Dim result As New ProductPromotionEligibilityResult
  If articleId<>901 OrElse tcId<>5 OrElse ctx.Listino<>1 Then Return result
  result.AuthorizedOffers.Add(New ProductPromotionEligibilityOffer With {.OfferId=11,.OfferDetailId=101,.QntMinima=2,.PriceNet=8,.PriceGross=9.76D})
  result.AuthorizedOffers.Add(New ProductPromotionEligibilityOffer With {.OfferId=12,.OfferDetailId=102,.Multipli=10,.PriceNet=6,.PriceGross=7.32D})
  result.AuthorizedOffers.Add(New ProductPromotionEligibilityOffer With {.OfferId=13,.OfferDetailId=103,.Multipli=5,.PriceNet=7,.PriceGross=8.54D})
  result.AuthorizedOffers.Add(New ProductPromotionEligibilityOffer With {.OfferId=17,.OfferDetailId=107,.QntMinima=2,.PriceNet=7.5D,.PriceGross=9.15D})
  Return result
 End Function
End Module
'@
        $fixture=$fixture.Replace("Public Class ProductPromotionEligibilityContext`r`nEnd Class","Public Class ProductPromotionEligibilityContext`r`n Public Property Listino As Integer`r`nEnd Class").Replace("Public Class ProductPromotionEligibilityContext`nEnd Class","Public Class ProductPromotionEligibilityContext`n Public Property Listino As Integer`nEnd Class")
        $fixture=[regex]::Replace($fixture,'(?s)Public Module ProductPromotionEligibilityResolver.*?End Module',$resolver)
        $handler=[regex]::Match($cartCode,'(?ms)^    Protected Sub rPromo_ItemDataBound\b.*?^    End Sub').Value
        if (!$handler) { throw 'PROMO_REAL_HANDLER_MISSING' }
        $native=@'
Public Class PromoItemHarness
 Inherits System.Web.UI.Page
 Public Listino As Integer=1
 Public NetMode As Boolean=False
 Private Function GetSessionInt(key As String,Optional fallback As Integer=0) As Integer
  If key="Listino" OrElse key="listino" Then Return Listino
  If key="IvaTipo" Then Return If(NetMode,1,0)
  Return fallback
 End Function
 Private Function SafeInt(value As Object,Optional fallback As Integer=0) As Integer
  If value Is Nothing OrElse value Is DBNull.Value Then Return fallback
  Return Convert.ToInt32(value,CultureInfo.InvariantCulture)
 End Function
 Private Function TryReadDatabaseDecimal(value As Object,ByRef result As Decimal) As Boolean
  If Not TypeOf value Is Decimal Then Return False
  result=DirectCast(value,Decimal):Return True
 End Function
 HANDLER_BODY
 Public Function Display(row As DataRow) As String
  Dim item As New RepeaterItem(0,ListItemType.Item)
  item.DataItem=row.Table.DefaultView(row.Table.Rows.IndexOf(row))
  Dim label As New Label With {.ID="lblOfferta"}
  item.Controls.Add(label)
  rPromo_ItemDataBound(Nothing,New RepeaterItemEventArgs(item))
  Return If(label.Visible,label.Text,"")
 End Function
End Class
Public Module PromoRev1Native
 Public Sub Main(args As String())
  Dim names=System.IO.File.ReadAllLines(args(0))
  Dim table As New DataTable
  For Each name In names(0).Split(ChrW(9))
   Dim kind As Type=GetType(Integer)
   If name.StartsWith("Prezzo") OrElse name="ValoreIvaRC" OrElse name="OfferteQntMinima" OrElse name="OfferteMultipli" Then kind=GetType(Decimal)
   If name.StartsWith("OfferteData") Then kind=GetType(Date)
   If name="DescrizioneIvaRC" Then kind=GetType(String)
   table.Columns.Add(name,kind)
  Next
  For index As Integer=1 To names.Length-1
   Dim row=table.NewRow(),parts=names(index).Split(ChrW(9))
   For col As Integer=0 To parts.Length-1
    row(col)=If(parts(col)="NULL",DirectCast(DBNull.Value,Object),Convert.ChangeType(parts(col),table.Columns(col).DataType,CultureInfo.InvariantCulture))
   Next
   table.Rows.Add(row)
  Next
  Dim harness As New PromoItemHarness
  Dim shown As Integer=0
  For Each row As DataRow In table.Rows
   Dim detail=CInt(row("OfferteDettagliId")),text=harness.Display(row)
   If detail=401 Then
    If text<>"" Then Throw New Exception("UNAUTHORIZED_DETAIL_VISIBLE")
   Else
    If text="" Then Throw New Exception("AUTHORIZED_DETAIL_LOST")
    shown+=1
    If detail=101 AndAlso Not text.Contains("9,76") Then Throw New Exception("GROSS_PRICE_MISMATCH")
    If detail=102 AndAlso Not text.Contains("MULTIPLI 10") Then Throw New Exception("MULTIPLE_TIER_CHANGED")
   End If
  Next
  If shown<>4 Then Throw New Exception("VISIBLE_DETAIL_COUNT")
  Dim reference=table.Select("OfferteDettagliId=101")(0)
  harness.NetMode=True
  If Not harness.Display(reference).Contains("8,00") Then Throw New Exception("NET_PRICE_MISMATCH")
  harness.Listino=10
  If harness.Display(reference)<>"" Then Throw New Exception("CROSS_LIST_OFFER_VISIBLE")
  harness.Listino=1:reference("TCid")=9
  If harness.Display(reference)<>"" Then Throw New Exception("CROSS_VARIANT_OFFER_VISIBLE")
  Console.WriteLine("PROMO_REAL_HANDLER_HELPER_PASS authorized=4 denied=3 netGross=PASS")
 End Sub
End Module
'@
        $native=$native.Replace('HANDLER_BODY',$handler)
        $fixture=[regex]::Replace($fixture,'(?m)^Imports[^\r\n]*\r?\n','')
        $imports="Imports System`r`nImports System.Collections.Generic`r`nImports System.Data`r`nImports System.Globalization`r`nImports System.Configuration`r`nImports System.Web`r`nImports System.Web.UI`r`nImports System.Web.UI.WebControls`r`n"
        $nativePath=Join-Path $EvidenceDirectory 'PromoNative.vb'
        [IO.File]::WriteAllText($nativePath,$imports+$fixture+$native,$utf8)
        $exe=Join-Path $EvidenceDirectory 'PromoNative.exe'
        $compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/vbc.exe'
        $output=@(& $compiler /nologo /target:exe ("/out:"+$exe) /r:System.dll,System.Core.dll,System.Web.dll,System.Data.dll,System.Configuration.dll $nativePath (Join-Path $RepositoryRoot 'App_Code/ProductPromotionDisplayHelper.vb') (Join-Path $RepositoryRoot 'App_Code/UiPriceFormatter.vb') (Join-Path $RepositoryRoot 'App_Code/StorefrontPriceDisplayContext.vb'))
        if ($LASTEXITCODE -ne 0) { throw ('PROMO_NATIVE_COMPILE_FAILED '+($output -join ' ')) }
        [IO.File]::WriteAllText(($exe+'.config'),'<configuration><connectionStrings><add name="EntropicConnectionString" connectionString="KS-DBCFG-FIXTURE-promo-handler" /></connectionStrings></configuration>',$utf8)
        $rowFile=Join-Path $EvidenceDirectory 'native-rows.tsv'
        [IO.File]::WriteAllLines($rowFile,@(($fields -join "`t"))+$selected,$utf8)
        $nativeOutput=@(& $exe $rowFile)
        Check 'real rPromo handler and display helper preserve identity authorization and net gross' ($LASTEXITCODE -eq 0 -and ($nativeOutput -join '') -match 'PROMO_REAL_HANDLER_HELPER_PASS')
        $after=@(Rows 'SELECT @@session.sql_mode;')[0]
        Check 'strict SQL mode unchanged after REV1 tests' ($after -ceq $mode)
        $result='PASS'
    } finally {
        [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'promo-rev1-results.json'),(@{Result=$result;Checks=$checks.Count;Details=$checks;SqlCalls=$sqlCalls;MySql='REAL_READONLY_CTE';ItemHandlerAndDisplay='REAL_SOURCE';AuthorizationIo='EXPLICIT_FIXTURE_STUB_NOT_RUNTIME_CERTIFICATION';Previous230Tests='REUSED_NOT_RERUN'}|ConvertTo-Json -Depth 6),$utf8)
    }
    Write-Output ('PROMO_SQL8_'+$result+' checks='+$checks.Count+' sqlCalls='+$sqlCalls+' previous230=NOT_RERUN')
    exit 0
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
