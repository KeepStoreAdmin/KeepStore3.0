[CmdletBinding()]
param(
 [string]$RepositoryRoot,
 [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
 [string]$BaselineRef='8319bf7022d5092c6c631f912eef22dbf463be14',
 [switch]$QueryOnly,
 [System.Data.Common.DbConnection]$ReadOnlyConnection
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop'){throw 'RANGE_FACET_REQUIRES_POWERSHELL51'}
if(-not $RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot);$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory)
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if(-not $EvidenceDirectory.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $EvidenceDirectory)){throw 'RANGE_FACET_REQUIRES_NEW_TEMP_EVIDENCE'}
if($BaselineRef -cnotmatch '^[a-f0-9]{40}$'){throw 'EXACT_BASELINE_REQUIRED'}
New-Item -ItemType Directory -Path $EvidenceDirectory|Out-Null
$utf=New-Object Text.UTF8Encoding($false)
function Save($name,$value){[IO.File]::WriteAllText((Join-Path $EvidenceDirectory $name),($value|ConvertTo-Json -Depth 16),$utf)}
function MatchSource([string]$text,[string]$pattern){$m=[regex]::Match($text,$pattern);if(-not $m.Success){throw ('SOURCE_BLOCK_MISSING '+$pattern)};return $m.Value}
function Method([string]$text,[string]$name,[string]$kind='Function'){return MatchSource $text ('(?ms)^    (?:Private|Protected|Public) (?:Shared )?'+$kind+' '+[regex]::Escape($name)+'\b.*?^    End '+$kind)}
$candidate=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'articoli.aspx.vb'))
$baseline=@(& git -C $RepositoryRoot show ($BaselineRef+':articoli.aspx.vb')) -join "`r`n";if($LASTEXITCODE){throw 'BASELINE_UNAVAILABLE'}
$template=@'
Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Text.RegularExpressions
Imports System.Web.UI.WebControls
Imports System.Web.Script.Serialization
Public Class ProductPromotionEligibilityContext
 Public CompanyId As Integer
 Public Listino As Integer
 Public CampaignId As Integer
 Public EvaluationDate As Date
 Public IsAuthenticated As Boolean
 Public CurrentUserId As Integer
End Class
@@CLASSES@@
Module RangeFacetHarness
 Sub Main(args As String())
  Dim output As New Dictionary(Of String,Object)
  For Each label As String In New String(){"baseline","candidate"}
   Dim cases As New Dictionary(Of String,Object)
   For Each scenario As String In New String(){"ordinary","pmax","pmin","p_basso","p_alto"}
    If label="baseline" Then
     cases(scenario)=(New BaselineFacetFixture()).Queries(scenario)
    Else
     cases(scenario)=(New CandidateFacetFixture()).Queries(scenario)
    End If
   Next
   output(label)=cases
  Next
  Dim failures As New Dictionary(Of String,Object)
  failures("rangeFacetError")=(New CandidateFacetFixture()).FailureState(True,True,True)
  failures("rangeMainError")=(New CandidateFacetFixture()).FailureState(True,False,True)
  failures("rangeSuccess")=(New CandidateFacetFixture()).FailureState(True,True,False)
  failures("ordinaryError")=(New CandidateFacetFixture()).FailureState(False,True,True)
  output("failureStates")=failures
  System.IO.File.WriteAllText(args(0),(New JavaScriptSerializer()).Serialize(output))
 End Sub
End Module
'@
$fixture=@'
Public Class @@CLASS@@
 Private WithEvents sdsArticoli As New SqlDataSource()
 Private WithEvents sdsMarche As New SqlDataSource()
 Private WithEvents sdsTipologie As New SqlDataSource()
 Private WithEvents sdsGruppo As New SqlDataSource()
 Private WithEvents sdsSottogruppo As New SqlDataSource()
 Private lvProdotti As New ListView()
 Private ksMultiFooter As New Panel()
 Private DataList1 As New DataList(),DataList2 As New DataList(),DataList3 As New DataList(),DataList4 As New DataList()
 Private filtritagliaecolore As New Panel()
 Private catalogQuantityOnePriceFailed As Boolean,catalogQuantityOnePriceRequired As Boolean,catalogPromotionActive As Boolean,catalogPromotionTechnicalError As Boolean
 Private countText As Integer=-1,message As String=""
 Private _priceDisplayContext As New StorefrontPriceDisplayContext(1,1,False,StorefrontVatDisplayMode.VatIncluded,Nothing,-1,"",False)
 Private Sub SetCatalogCountText(n As Integer)
  countText=n
 End Sub
 Private Sub ShowPromotionCatalogMessage(text As String)
  message=text
 End Sub
 Public Function Queries(scenario As String) As Dictionary(Of String,String)
  Dim hasPmin As Boolean=scenario="pmin",hasPmax As Boolean=scenario="pmax",hasPriceRange As Boolean=hasPmin OrElse hasPmax
  Dim promotionTcSelect As String="",promotionMainJoin As String="",promotionFacetJoin As String="",searchScoreSql As String="0 AS SearchScore"
  Dim effectiveBaseGrossSql As String=StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression("vsuperarticoli.Prezzo","vsuperarticoli.PrezzoIvato","vsuperarticoli.IdIvaRC","vsuperarticoli.ValoreIvaRC","?ksRcEnabled","?ksHasVatOverride","?ksVatOverride")
  Dim effectivePromoGrossSql As String=StorefrontEffectivePriceSqlBuilder.BuildEffectiveGrossExpression("vsuperarticoli.PrezzoPromo","vsuperarticoli.PrezzoPromoIvato","vsuperarticoli.IdIvaRC","vsuperarticoli.ValoreIvaRC","?ksRcEnabled","?ksHasVatOverride","?ksVatOverride")
@@MAINSELECT@@
  Dim strWhere As String="",strWhere2 As String="WHERE 1=1 ",quantityOneFacetJoin As String=""
  Dim quantityOneJoin As String=StorefrontPromotionCatalogProvider.BuildQuantityOnePriceJoin()
  Dim rawDisplayPriceSql As String=BuildCatalogQuantityOneDisplayPriceSql(effectiveBaseGrossSql)
  Dim displayPriceSql As String="ROUND(CAST(" & rawDisplayPriceSql & " AS DECIMAL(38,16)),2)"
  If hasPriceRange OrElse scenario="p_basso" OrElse scenario="p_alto" Then
@@PROJECTION@@
  End If
@@RANGE@@
  Dim sortSql As String=""
  If scenario="p_basso" Then
@@SORTASC@@
  ElseIf scenario="p_alto" Then
@@SORTDESC@@
  Else
   sortSql=" ORDER BY id ASC"
  End If
  Me.sdsArticoli.SelectCommand=BuildCatalogListingSql(strSelect,strWhere,sortSql)
@@FACETS@@
  Dim result As New Dictionary(Of String,String)
  result("main")=sdsArticoli.SelectCommand
  result("marche")=sdsMarche.SelectCommand
  result("tipologie")=sdsTipologie.SelectCommand
  result("gruppi")=sdsGruppo.SelectCommand
  result("sottogruppi")=sdsSottogruppo.SelectCommand
  result("rawFacetRows")="SELECT COUNT(*) AS n FROM varticolibase " & strWhere2
  If hasPriceRange Then result("resolvedFacetRows")="SELECT vsuperarticoli.id,COALESCE(NULLIF(vsuperarticoli.TCid,0),atc_default.DefaultTCid,-1) AS TCid FROM varticolibase " & strWhere2 & " ORDER BY vsuperarticoli.id"
  Return result
 End Function
 Public Function FailureState(rangeActive As Boolean,facet As Boolean,technicalError As Boolean) As Dictionary(Of String,Object)
  catalogQuantityOnePriceRequired=rangeActive
  Dim e As New SqlDataSourceStatusEventArgs(New System.Data.SqlClient.SqlCommand(),0,If(technicalError,New InvalidOperationException("SYNTHETIC_FACET_TECHNICAL_FAILURE"),Nothing))
  If facet Then
   sdsPromotionFacet_Selected(sdsMarche,e)
  Else
   sdsArticoli_Selected(sdsArticoli,e)
  End If
  Dim r As New Dictionary(Of String,Object)
  r("handled")=e.ExceptionHandled:r("failed")=catalogQuantityOnePriceFailed:r("count")=countText:r("message")=message
  r("productsVisible")=lvProdotti.Visible:r("filtersVisible")=DataList2.Visible OrElse DataList3.Visible OrElse DataList1.Visible OrElse DataList4.Visible OrElse filtritagliaecolore.Visible
  Return r
 End Function
@@METHODS@@
End Class
'@
$classes=@()
foreach($label in @('Baseline','Candidate')){
 $source=if($label -eq 'Baseline'){$baseline}else{$candidate};$code=$fixture.Replace('@@CLASS@@',($label+'FacetFixture'))
 $parts=@{
 MAINSELECT=(MatchSource $source '(?ms)^        Dim strSelect As String =\r?\n.*?^            BuildCatalogArrivalsJoinSql\(\)')
 PROJECTION=(MatchSource $source '(?m)^    strSelect = "SELECT " & displayPriceSql.*$')
 RANGE=(MatchSource $source '(?ms)^    If hasPriceRange Then\r?\n.*?^    End If')
 SORTASC=(MatchSource $source '(?m)^                sortSql &= " ORDER BY CASE WHEN CatalogDisplayPrice>0 THEN 0 ELSE 1 END ASC, CatalogDisplayPrice ASC.*$')
 SORTDESC=(MatchSource $source '(?m)^                sortSql &= " ORDER BY CASE WHEN CatalogDisplayPrice>0 THEN 0 ELSE 1 END ASC, CatalogDisplayPrice DESC.*$')
 FACETS=(MatchSource $source '(?ms)^        strWhere2 = " LEFT JOIN vsuperarticoli.*?(?=^        '' Ensure all filter datasources)')
 METHODS=((@('BuildCatalogRowRankSql','BuildCatalogListingSql','BuildCatalogArrivalsJoinSql','BuildCatalogQuantityOneDisplayPriceSql')|ForEach-Object {Method $source $_})+(@('sdsArticoli_Selected','sdsPromotionFacet_Selected','FailCatalogQuantityOnePrices')|ForEach-Object {Method $source $_ 'Sub'})) -join "`r`n"
 }
 foreach($key in $parts.Keys){$code=$code.Replace('@@'+$key+'@@',$parts[$key])};$classes+=$code
}
$vb=$template.Replace('@@CLASSES@@',($classes -join "`r`n"));if($vb -match '@@[A-Z]+@@'){throw 'UNRESOLVED_SOURCE_MARKER'}
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'Harness.vb'),$vb,$utf)
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319';$exe=Join-Path $EvidenceDirectory 'Harness.exe'
$args=@('/nologo','/target:exe','/optioninfer+','/main:RangeFacetHarness',('/out:'+$exe))
foreach($r in @('System.dll','System.Core.dll','System.Data.dll','System.Web.dll','System.Web.Extensions.dll')){$args+=('/reference:'+(Join-Path $framework $r))}
$args+=@((Join-Path $RepositoryRoot 'App_Code\StorefrontPromotionCatalogProvider.vb'),(Join-Path $RepositoryRoot 'App_Code\StorefrontEffectivePriceSqlBuilder.vb'),(Join-Path $RepositoryRoot 'App_Code\StorefrontPriceDisplayContext.vb'),(Join-Path $EvidenceDirectory 'Harness.vb'))
$compile=@(& (Join-Path $framework 'vbc.exe') @args 2>&1);$compile|Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'compile.log') -Encoding UTF8;if($LASTEXITCODE){throw ('RANGE_FACET_COMPILE_FAILED '+($compile -join "`n"))}
& $exe (Join-Path $EvidenceDirectory 'queries.json');if($LASTEXITCODE){throw 'RANGE_FACET_HARNESS_FAILED'}
if($QueryOnly){[pscustomobject]@{result='QUERIES_GENERATED';source='actual CaricaArticoli range/facet blocks and handlers';path=$EvidenceDirectory}|ConvertTo-Json;return}
$packet=Get-Content -LiteralPath (Join-Path $EvidenceDirectory 'queries.json') -Raw|ConvertFrom-Json
$checks=New-Object 'Collections.Generic.List[object]';$sqlResults=New-Object 'Collections.Generic.List[object]'
function Assert([bool]$ok,[string]$label){$checks.Add([pscustomobject]@{name=$label;pass=$ok});if(-not $ok){Save 'checks.json' $checks.ToArray();throw ('RANGE_FACET_ASSERTION '+$label)}}
foreach($scenario in @('ordinary','pmax','pmin','p_basso','p_alto')){
 Assert ($packet.baseline.$scenario.main -ceq $packet.candidate.$scenario.main) ('main SQL unchanged '+$scenario)
 foreach($facet in @('marche','tipologie','gruppi','sottogruppi')){
  $sql=$packet.candidate.$scenario.$facet
  if($scenario -in @('pmax','pmin')){
   Assert ([regex]::Matches($sql,'\) atc_default ON atc_default.ArticoliId=vsuperarticoli.id').Count -eq 1) ($scenario+' single default join '+$facet)
   Assert ($sql.IndexOf(') atc_default ON') -lt $sql.IndexOf(') ks_qty1_price')) ($scenario+' default alias declared before qty1 correlation '+$facet)
  }else{Assert ($packet.baseline.$scenario.$facet -ceq $sql) ('non-range facet unchanged '+$scenario+'/'+$facet)}
 }
}
$mainDefaultJoin=MatchSource $candidate '(?m)^            " LEFT OUTER JOIN \(SELECT ArticoliId, MIN\(id\) AS DefaultTCid.*$'
Assert ($packet.candidate.pmax.marche.Contains($mainDefaultJoin.Trim().TrimEnd('&').Trim().Trim('"'))) 'facet uses exact main default-variant aggregate'
foreach($name in @('rangeFacetError','rangeMainError')){$s=$packet.failureStates.$name;Assert ($s.handled -and $s.failed -and $s.count -eq 0 -and -not $s.productsVisible -and -not $s.filtersVisible -and $s.message -eq 'I prezzi non sono temporaneamente disponibili. Riprova tra poco.') ('real Selected handler remains fail closed '+$name)}
foreach($name in @('rangeSuccess','ordinaryError')){$s=$packet.failureStates.$name;Assert (-not $s.handled -and -not $s.failed -and $s.productsVisible -and $s.filtersVisible) ('handler does not suppress valid/ordinary path '+$name)}
foreach($name in @('sdsArticoli_Selected','sdsPromotionFacet_Selected','FailCatalogQuantityOnePrices')){Assert ((Method $baseline $name 'Sub').Replace("`r`n","`n") -ceq (Method $candidate $name 'Sub').Replace("`r`n","`n")) ('failure handler source unchanged '+$name)}

# These rows exist only inside each read-only statement. They shadow views/tables,
# never INSERT data, and cover two listini, positive/default/standard identities.
$cte=@'
WITH price_seed AS (
 SELECT 101 AS id,1 AS NListino,11 AS TCid,1001 AS ArticoliListiniId,CAST(20 AS DECIMAL(18,4)) AS Prezzo,CAST(24.40 AS DECIMAL(18,4)) AS PrezzoIvato
 UNION ALL SELECT 101,10,11,1011,30,36.60
 UNION ALL SELECT 102,1,0,1002,10,12.20
 UNION ALL SELECT 102,10,0,1012,12,14.64
 UNION ALL SELECT 103,1,-1,1003,15,18.30
 UNION ALL SELECT 103,10,-1,1013,18,21.96
),vsuperarticoli AS (
 SELECT p.*,CONCAT('SYNTHETIC_RANGE_',p.id) AS Codice,NULL AS Ean,'SYNTHETIC_RANGE' AS Descrizione1,'' AS Descrizione2,'' AS DescrizioneLunga,
 -1 AS IdIvaRC,0 AS ValoreIvaRC,NULL AS Img1,NULL AS Img2,NULL AS Img3,NULL AS Img4,
 'SYNTHETIC_RANGE' AS MarcheDescrizione,1 AS Disponibilita,15 AS Giacenza,0 AS InOrdine,0 AS Impegnata,0 AS InOfferta,
 'SYNTHETIC_RANGE' AS SettoriDescrizione,'SYNTHETIC_RANGE' AS CategorieDescrizione,'SYNTHETIC_RANGE' AS TipologieDescrizione,'SYNTHETIC_RANGE' AS GruppiDescrizione,'SYNTHETIC_RANGE' AS SottogruppiDescrizione,
 NULL AS Marche_img,CAST(NULL AS DECIMAL(18,4)) AS PrezzoPromo,CAST(NULL AS DECIMAL(18,4)) AS PrezzoPromoIvato,
 501 AS MarcheId,501 AS CategorieId,501 AS TipologieId,501 AS GruppiId,501 AS SottoGruppiId,0 AS OfferteDettagliId,0 AS Ricondizionato,0 AS visite,1 AS Vetrina
 FROM price_seed p
),varticolilistini AS (SELECT * FROM vsuperarticoli),
varticolibase AS (SELECT 101 AS id,501 AS MarcheId,501 AS TipologieId,501 AS GruppiId,501 AS SottoGruppiId UNION ALL SELECT 102,501,501,501,501 UNION ALL SELECT 103,501,501,501,501),
articoli AS (SELECT 101 AS id,1 AS Abilitato,0 AS NoPromo,NULL AS Img5,NULL AS Img6 UNION ALL SELECT 102,1,0,NULL,NULL UNION ALL SELECT 103,1,0,NULL,NULL),
articoli_tagliecolori AS (SELECT 11 AS id,101 AS ArticoliId,1 AS TagliaId,1 AS ColoreId UNION ALL SELECT 12,101,2,1 UNION ALL SELECT 13,102,1,1 UNION ALL SELECT 14,102,2,1),
articoli_listini AS (SELECT 101 AS ArticoliId,1 AS NListino,11 AS TCId UNION ALL SELECT 101,10,11 UNION ALL SELECT 102,1,13 UNION ALL SELECT 102,10,13),
offerte AS (SELECT 201 AS id,1 AS AziendeId,1 AS DaListino,1 AS AListino,0 AS UtentiId,CAST(NULL AS DATETIME) AS DataInizio,CAST(NULL AS DATETIME) AS DataFine,1 AS QntMinima,0 AS Multipli,8 AS Prezzo,0 AS Sconto,1 AS Abilitato
 UNION ALL SELECT 202,2,10,10,0,NULL,NULL,1,0,10,0,1),
offertedettaglio AS (SELECT 301 AS id,201 AS OfferteId,11 AS TCId UNION ALL SELECT 302,201,13 UNION ALL SELECT 303,202,11 UNION ALL SELECT 304,202,13),
voffertearticoli AS (SELECT 101 AS id,201 AS OfferteID,301 AS OfferteDettagliId UNION ALL SELECT 102,201,302 UNION ALL SELECT 101,202,303 UNION ALL SELECT 102,202,304),
Marche AS (SELECT 501 AS id,'SYNTHETIC_RANGE' AS Descrizione,1 AS Ordinamento),
tipologie AS (SELECT * FROM Marche),Gruppi AS (SELECT * FROM Marche),SottoGruppi AS (SELECT * FROM Marche),
taglie AS (SELECT 1 AS id,'SYNTHETIC_RANGE_A' AS descrizione UNION ALL SELECT 2,'SYNTHETIC_RANGE_B'),
colori AS (SELECT 1 AS id,'SYNTHETIC_RANGE_COLOR' AS descrizione),
articoli_arrivi AS (SELECT 0 AS articoliid,CAST(NULL AS DATETIME) AS dataArrivo,0 AS arrivi WHERE 1=0)
'@
[IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'read-only-cte.sql'),$cte,$utf)
function SelectRows([string]$sql,[hashtable]$parameters){
 if($sql -notmatch '^\s*(SELECT|WITH|SHOW)\b' -or $sql -match '(?im)^\s*(INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|SET|CALL|GRANT|TRUNCATE)\b|(?i)\bINTO\s+(OUTFILE|DUMPFILE)\b|\bFOR\s+UPDATE\b'){throw 'ONLY_READ_ONLY_SELECT_ALLOWED'}
 $cmd=$ReadOnlyConnection.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=20;$reader=$null
 foreach($key in $parameters.Keys){$p=$cmd.CreateParameter();$p.ParameterName='?'+$key;$p.Value=$parameters[$key];[void]$cmd.Parameters.Add($p)}
 try{$reader=$cmd.ExecuteReader();$rows=New-Object 'Collections.Generic.List[object]';while($reader.Read()){$r=[ordered]@{};for($i=0;$i -lt $reader.FieldCount;$i++){$r[$reader.GetName($i)]=if($reader.IsDBNull($i)){$null}else{$reader.GetValue($i)}};$rows.Add([pscustomobject]$r)};return $rows.ToArray()}
 finally{if($reader){$reader.Dispose()};$cmd.Dispose()}
}
if($ReadOnlyConnection){
 $identity=@(SelectRows 'SELECT @@server_uuid AS uuid,@@port AS port,DATABASE() AS db,@@datadir AS datadir,CURRENT_USER() AS account,@@require_secure_transport AS secure,@@session.sql_mode AS sqlMode' @{})[0]
 Assert ($identity.uuid -ceq '1167ebae-d0c0-11f1-b348-9c7bef540c10' -and $identity.port -eq 13317 -and $identity.db -ceq 'keepstore_regorder_lab_20261025' -and $identity.account -ceq 'keepstore_lab_audit@127.0.0.1' -and $identity.datadir.Replace('\','/').TrimEnd('/') -ieq 'C:/Temp/KeepStoreRegOrderLab-20261025/mysql/data' -and $identity.secure -eq 1 -and $identity.sqlMode -match 'ONLY_FULL_GROUP_BY') 'read-only audit LAB identity and strict SQL mode'
 $tls=@(SelectRows "SHOW SESSION STATUS LIKE 'Ssl_version'" @{})[0];Assert ($tls.Value -match '^TLSv1\.(2|3)$') 'authenticated TLS'
 foreach($list in @(1,10)){
  $company=if($list -eq 1){1}else{2};$cut=if($list -eq 1){11}else{13};$price=if($list -eq 1){9.76D}else{12.20D}
  $params=@{NListino=$list;promoListino=$list;promoCompanyId=$company;promoEvaluationDate=[datetime]::UtcNow.Date;promoIsAuthenticated=0;promoCurrentUserId=0;promoCampaignId=0;ksRcEnabled=0;ksHasVatOverride=0;ksVatOverride=0;Pmin=$cut;Pmax=$cut}
  foreach($facet in @('marche','tipologie','gruppi','sottogruppi')){
   $e=$null;try{$unused=@(SelectRows $packet.baseline.pmax.$facet $params)}catch{$e=$_.Exception.GetBaseException()}
   Assert ($null -ne $e -and $e.PSObject.Properties.Name -contains 'Number' -and $e.Number -eq 1054 -and $e.Message -match 'atc_default.DefaultTCid') ('installed baseline 1054 list'+$list+'/'+$facet)
   $sqlResults.Add([pscustomobject]@{scope='installed LAB';source='baseline';list=$list;query=$facet;mysql=1054})
   $r=@(SelectRows $packet.candidate.pmax.$facet $params);$sqlResults.Add([pscustomobject]@{scope='installed LAB';source='candidate';list=$list;query=$facet;mysql=0;rows=$r.Count})
   Assert ($true) ('installed candidate executes list'+$list+'/'+$facet)
  }
  foreach($scenario in @('pmax','pmin')){
   $expected=if($scenario -eq 'pmax'){'101,102'}else{'103'};$count=if($scenario -eq 'pmax'){2}else{1}
   foreach($facet in @('marche','tipologie','gruppi','sottogruppi')){
    $r=@(SelectRows ($cte+"`n"+$packet.candidate.$scenario.$facet) $params)
    Assert ($r.Count -eq 1 -and $r[0].Numero -eq $count) ('CTE '+$scenario+' distinct facet count list'+$list+'/'+$facet)
    $sqlResults.Add([pscustomobject]@{scope='read-only CTE';list=$list;scenario=$scenario;query=$facet;count=$r[0].Numero})
   }
   $r=@(SelectRows ($cte+"`n"+$packet.candidate.$scenario.main) $params)
   Assert ((@($r|ForEach-Object {$_.id}) -join ',') -ceq $expected) ('CTE '+$scenario+' main article membership list'+$list)
   if($scenario -eq 'pmax'){
    Assert ($r[0].TCid -eq 11 -and $r[1].TCid -eq 13 -and $r[0].CatalogDisplayPrice -eq $price -and $r[1].CatalogDisplayPrice -eq $price) ('CTE positive/default variant and tenant promo prices list'+$list)
   }else{Assert ($r[0].TCid -eq -1) ('CTE standard identity preserved list'+$list)}
   $raw=@(SelectRows ($cte+"`n"+$packet.candidate.$scenario.rawFacetRows) $params)
   Assert ($raw[0].n -eq $count) ('CTE aggregate default join does not multiply rows list'+$list+'/'+$scenario)
   $resolved=@(SelectRows ($cte+"`n"+$packet.candidate.$scenario.resolvedFacetRows) $params)
   Assert ((@($resolved|ForEach-Object {$_.id}) -join ',') -ceq $expected) ('CTE facet membership matches main list'+$list+'/'+$scenario)
   $sqlResults.Add([pscustomobject]@{scope='read-only CTE';list=$list;scenario=$scenario;query='main/default/raw-facet';ids=@($r|ForEach-Object {$_.id});tc=@($r|ForEach-Object {$_.TCid});rawCount=$raw[0].n})
  }
  foreach($scenario in @('ordinary','p_basso','p_alto')){
   $r=@(SelectRows ($cte+"`n"+$packet.candidate.$scenario.main) $params);$expected=if($scenario -eq 'p_alto'){'103,101,102'}else{'101,102,103'}
   Assert ((@($r|ForEach-Object {$_.id}) -join ',') -ceq $expected) ('CTE ordinary/sort unchanged list'+$list+'/'+$scenario)
  }
 }
}
Save 'checks.json' $checks.ToArray();Save 'mysql-results.json' $sqlResults.ToArray()
$report=[ordered]@{result='A';checks=$checks.Count;passed=@($checks|Where-Object pass).Count;mysql=if($ReadOnlyConnection){'REAL MYSQL8 READ-ONLY; installed facets plus statement-local CTEs'}else{'NOT EXECUTED'};newFixtureRows=0;dml=0;ddl=0;http=0;baseline=$BaselineRef;limitations='No IIS/browser or operational data/performance certification; context inputs and Selected-event exceptions synthetic in generated harness.'}
Save 'result.json' $report;$report|ConvertTo-Json
