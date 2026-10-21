[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaselineRef='f225d78d6e5ae94588910a60c55a36b8d94fc5f6'
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'SALES_CLAIMS_REQUIRES_PS51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if(!$EvidenceDirectory.StartsWith($tempRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or
   (Test-Path -LiteralPath $EvidenceDirectory) -or $BaselineRef -notmatch '^[a-f0-9]{40}$'){throw 'SALES_CLAIMS_INVALID_OUTPUT_OR_BASE'}
$work=Join-Path $tempRoot ('ks-sales-claims-compile-'+[Guid]::NewGuid().ToString('N'))
$utf8=New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$checks=New-Object 'Collections.Generic.List[object]'
$fixtures=New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$ok){
    $checks.Add([pscustomobject]@{Name=$name;Pass=$ok})
    if(!$ok){throw ('SALES_CLAIMS_ASSERT: '+$name)}
}
function Normalize([string]$s){return $s.Replace([string][char]13,'').TrimEnd([char[]]([string][char]10))}
function Method-Map([string]$source){
    $map=@{}
    foreach($m in [regex]::Matches($source,'(?ms)^    (?:Private|Protected|Public) (?:Shared )?(?:Function|Sub) (\w+)\b.*?^    End (?:Function|Sub)')){
        $name=$m.Groups[1].Value
        if(!$map.ContainsKey($name)){$map[$name]=@()}
        $map[$name]+=$m.Value
    }
    return $map
}
function Table-Xml([Data.DataTable]$table){
    $writer=New-Object IO.StringWriter
    try{$table.WriteXml($writer,[Data.XmlWriteMode]::WriteSchema);return $writer.ToString()}finally{$writer.Dispose()}
}
function Clean-Attributes([string]$html){
    return [regex]::Replace($html,"\sdata-ks-(?:sold|progress)='[^']*'",'')
}
function Stable-Tokens([string]$html){
    $html=[regex]::Replace($html,'(?i)(requestId=|data-ks-request-id='')[a-f0-9]{32}','$1FIXTURE_REQUEST_ID')
    return [regex]::Replace($html,"data-timer='[0-9]+'","data-timer='FIXTURE_SECONDS'")
}
function Without-Old-Claims([string]$html){
    $html=Clean-Attributes $html
    $html=[regex]::Replace($html,"(?s)<div class='product-progress-sale ks-deal-slot ks-deal-slot--progress'>.*?<p class='text-avaiable caption'>Disponibili:.*?</p></div></div>",'')
    $html=$html.Replace("<div class='ks-deal-slot ks-deal-slot--countdown' aria-hidden='true'></div>",'')
    return $html.Replace("<div class='box-infor-detail gap-xl-20 ks-deal-card__footer'></div>",'')
}
try{
    New-Item -ItemType Directory -Path $EvidenceDirectory,$work | Out-Null
    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName Microsoft.VisualBasic
    $source=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx.vb'))
    $baseline=(git -C $RepositoryRoot show ($BaselineRef+':Default.aspx.vb')) -join [Environment]::NewLine
    if($LASTEXITCODE -ne 0){throw 'SALES_CLAIMS_BASE_UNAVAILABLE'}
    $beforeMap=Method-Map $baseline
    $afterMap=Method-Map $source
    $changed=@('RenderDealCard','BuildQuickViewAttributes')
    $beforeRest=$baseline;$afterRest=$source
    foreach($name in $changed){
        Check "$name occurs exactly once" ($beforeMap[$name].Count -eq 1 -and $afterMap[$name].Count -eq 1)
        $beforeRest=$beforeRest.Replace($beforeMap[$name][0],'')
        $afterRest=$afterRest.Replace($afterMap[$name][0],'')
    }
    Check 'entire source outside the two rendering methods is identical' ((Normalize $beforeRest) -ceq (Normalize $afterRest))
    Check 'candidate rendering methods no longer read sales aggregates' (($changed|ForEach-Object{$afterMap[$_]}) -join '' -notmatch 'QtaVenduta|VendutiAnno|AvailabilityPercent')
    $usedJs=@(git -C $RepositoryRoot ls-files -- '*.js')
    foreach($path in $usedJs){
        if([IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)) -match 'data-ks-(?:sold|progress)|dataset\.(?:ksSold|ksProgress)|dataset\[[''"]ks(?:Sold|Progress)'){throw ('SALES_CLAIMS_CONSUMER: '+$path)}
    }
    Check 'no tracked JavaScript consumer of the removed sales attributes' $true
    $names=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $queue=New-Object 'Collections.Generic.Queue[string]'
    @('RenderDealCard','BuildQuickViewAttributes','RenderGridCard','RenderRowCard','RenderBigCard','SortAuthorizedDealRows','TakeDiverseRows','EmptyProductsTable')|ForEach-Object{$queue.Enqueue($_)}
    while($queue.Count){
        $name=$queue.Dequeue()
        if(!$names.Add($name)){continue}
        if(!$beforeMap.ContainsKey($name)){throw ('SALES_CLAIMS_MISSING_METHOD: '+$name)}
        foreach($body in $beforeMap[$name]){
            foreach($call in [regex]::Matches($body,'\b(\w+)\s*\(')){
                $dependency=$call.Groups[1].Value
                if($beforeMap.ContainsKey($dependency) -and !$names.Contains($dependency)){$queue.Enqueue($dependency)}
            }
        }
    }
    $cart=Method-Map ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/CartMutationIdempotencyService.vb')))
    $cartCode="Imports System`nImports System.Globalization`nImports System.Web`nPublic Class CartMutationIdempotencyService`n"+((@('CreateRequestId','BuildNativeActionValue','NormalizeTCId')|ForEach-Object{$cart[$_]}) -join [Environment]::NewLine)+"`nEnd Class"
    $sharedSources=@('StorefrontPriceDisplayContext.vb','UiPriceFormatter.vb','AvailabilityDisplayHelper.vb','ThemeManager.vb','UiData.vb')|ForEach-Object{[IO.File]::ReadAllText((Join-Path $RepositoryRoot ('App_Code/'+$_)))}
    $inventory=Method-Map ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/OrderInventoryAvailabilityService.vb')))
    $sharedSources+=('Imports System'+[Environment]::NewLine+'Public Class OrderInventoryAvailabilityService'+[Environment]::NewLine+$inventory['CalculateNetAvailableQuantity'][0]+[Environment]::NewLine+'End Class')
    $compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
    function Compile-Renderer([hashtable]$map,[string]$className){
        $body=($names|ForEach-Object{$map[$_]}) -join [Environment]::NewLine
        $wrapper=@'
    Private ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
    Private _priceDisplayContext As StorefrontPriceDisplayContext
    Public Sub Configure(company As Integer, listino As Integer, authenticated As Boolean, included As Boolean)
        _priceDisplayContext = New StorefrontPriceDisplayContext(company, listino, authenticated, If(included, StorefrontVatDisplayMode.VatIncluded, StorefrontVatDisplayMode.VatExcluded), Nothing, -1, "", False)
    End Sub
    Public Function FixtureTable() As DataTable
        Return EmptyProductsTable()
    End Function
    Public Function FixtureSort(rows As DataTable) As DataTable
        Return SortAuthorizedDealRows(rows, 8)
    End Function
    Public Function FixtureSelect(rows As DataTable) As DataTable
        Return TakeDiverseRows(6, New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), rows)
    End Function
    Public Function FixtureAttributes(row As DataRow) As String
        Return BuildQuickViewAttributes(row)
    End Function
    Public Function InvalidItem() As String
        Return RenderDealCard(New Object())
    End Function
    Public Function FixtureCard(row As DataRow, kind As String) As String
        Dim view As DataRowView = row.Table.DefaultView(row.Table.Rows.IndexOf(row))
        Select Case kind
            Case "grid" : Return RenderGridCard(view)
            Case "row" : Return RenderRowCard(view)
            Case "big" : Return RenderBigCard(view)
            Case Else : Return RenderDealCard(view)
        End Select
    End Function
'@
        $imports="Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Text`nImports System.Text.RegularExpressions`nImports System.Web`n"
        $code=$imports+'Public Class '+$className+[Environment]::NewLine+$body+[Environment]::NewLine+$wrapper+[Environment]::NewLine+'End Class'
        $parameters=New-Object CodeDom.Compiler.CompilerParameters
        $parameters.GenerateInMemory=$true
        $parameters.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
        $parameters.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($work,$false)
        foreach($assembly in @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll','System.Configuration.dll')){[void]$parameters.ReferencedAssemblies.Add($assembly)}
        $compiled=$compiler.CompileAssemblyFromSource($parameters,[string[]](@($code,$cartCode)+$sharedSources))
        if($compiled.Errors.HasErrors){throw ('SALES_CLAIMS_COMPILE: '+(($compiled.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{$_.ErrorText}) -join '; '))}
        return [Activator]::CreateInstance($compiled.CompiledAssembly.GetType($className,$true))
    }
    $old=Compile-Renderer $beforeMap 'BaselineSalesClaims'
    $new=Compile-Renderer $afterMap 'CandidateSalesClaims'
    Check 'invalid repeater item stays empty' ($old.InvalidItem() -ceq '' -and $new.InvalidItem() -ceq '')
    Check 'null Quick View row stays empty' ($old.FixtureAttributes($null) -ceq '' -and $new.FixtureAttributes($null) -ceq '')
    $markup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
    $section=[regex]::Match($markup,'(?s)<section id="HomeOffersSection".*?</section>').Value
    Check 'real offers section template found' ($section -match 'RenderDealCard\(Container.DataItem\)')
    foreach($tenant in @('Tech','Food')){
        $company=101;if($tenant -eq 'Food'){$company=202}
        $listino=1;if($tenant -eq 'Food'){$listino=10}
        foreach($authenticated in @($false,$true)){
            foreach($included in @($false,$true)){
                $tag=$tenant+'-'+[int]$authenticated+'-'+[int]$included
                $old.Configure($company,$listino,$authenticated,$included);$new.Configure($company,$listino,$authenticated,$included)
                $table=$new.FixtureTable();$table.TableName='Products'
                if(!$table.Columns.Contains('TCid')){[void]$table.Columns.Add('TCid',[int])}
                foreach($column in @('DisplayPromoSnapshotReady','DisplayPromoTechnicalError')){if(!$table.Columns.Contains($column)){[void]$table.Columns.Add($column,[bool])}}
                foreach($column in @('DisplayPromoQtyOnePrice','DisplayPromoTierPrice','DisplayPromoTierQntMinima','DisplayPromoTierMultipli')){if(!$table.Columns.Contains($column)){[void]$table.Columns.Add($column,[decimal])}}
                if(!$table.Columns.Contains('DisplayPromoDeadline')){[void]$table.Columns.Add('DisplayPromoDeadline',[datetime])}
                for($i=0;$i -lt 8;$i++){
                    $row=$table.NewRow()
                    foreach($column in $table.Columns){
                        if($column.DataType -eq [string]){$row[$column.ColumnName]=''}
                        elseif($column.DataType -eq [datetime]){$row[$column.ColumnName]=[DBNull]::Value}
                        else{$row[$column.ColumnName]=0}
                    }
                    $row.id=300+$i;$row.TCid=@(-1,0,10,20,-1,11,12,15)[$i]
                    if($i -eq 5 -or $i -eq 6){$row.id=300}
                    $row.Codice=$tag+'-'+$i;$row.Ean=$tag+'-'+$i
                    $labels=@('Router','Mouse','Tastiera','Monitor','Cavo','Scheda','Memoria','Notebook')
                    if($tenant -eq 'Food'){$labels=@('Pasta','Riso','Farina','Acqua','Olio','Caffe','Sale','Miele')}
                    $row.Descrizione1=$tenant+' '+$labels[$i]+' sintetico & modello'
                    $row.Descrizione2='Descrizione sintetica';$row.DescrizioneLunga='Dettagli del prodotto sintetico.'
                    $row.MarcheDescrizione=$tenant+' marca';$row.CategorieDescrizione='Categoria '+$tenant
                    $row.TipologieDescrizione='Tipo '+$i;$row.SettoriDescrizione=$tenant
                    $row.Img1='https://claims-'+$tenant.ToLowerInvariant()+'.invalid/images/item-'+$i+'.svg'
                    $row.Img2=$row.Img1.Replace('.svg','-2.svg')
                    if($i -eq 7){$row.Img1='';$row.Img2=''}
                    $row.Prezzo=100+$i;$row.PrezzoIvato=122+$i
                    $row.PrezzoPromo=80;$row.PrezzoPromoIvato=97.6
                    $row.IdIvaRC=-1;$row.ValoreIvaRC=22
                    $row.Giacenza=12+$i;$row.Disponibilita=10+$i;$row.Impegnata=2;$row.InOrdine=$i
                    $row.Ricondizionato=[int]($i -eq 4);$row.Visite=20-$i
                    $row.QtaVenduta=50+$i;$row.VendutiAnno=@(0,12,999999,-5,[DBNull]::Value,3.25,15,100)[$i]
                    $row.DisplayPromoSnapshotReady=$true;$row.DisplayPromoTechnicalError=($i -eq 7)
                    $row.DisplayPromoQtyOnePrice=0;$row.DisplayPromoTierPrice=0
                    if($i -eq 1 -or $i -eq 2){if($included){$row.DisplayPromoQtyOnePrice=97.6}else{$row.DisplayPromoQtyOnePrice=80}}
                    if($i -eq 3){if($included){$row.DisplayPromoTierPrice=85.4}else{$row.DisplayPromoTierPrice=70};$row.DisplayPromoTierQntMinima=3}
                    if($i -in @(1,2,5,6)){$row.DisplayPromoDeadline=[DateTime]::Today.AddDays(15+$i)}
                    $table.Rows.Add($row)
                }
                $inputBefore=Table-Xml $table
                $oldSorted=$old.FixtureSort($table);$newSorted=$new.FixtureSort($table)
                Check "$tag real offer sort full-row/order parity" ((Table-Xml $oldSorted) -ceq (Table-Xml $newSorted))
                $oldSelected=$old.FixtureSelect($oldSorted);$newSelected=$new.FixtureSelect($newSorted)
                Check "$tag real selection identity/order/values parity" ((Table-Xml $oldSelected) -ceq (Table-Xml $newSelected))
                Check "$tag six distinct selected products exercised" ($newSelected.Rows.Count -eq 6)
                foreach($kind in @('deal','grid','row','big')){
                    $beforeCards=@();$afterCards=@();$attributesBefore=@();$attributesAfter=@()
                    foreach($row in $table.Rows){
                        $beforeCards+=$old.FixtureCard($row,$kind);$afterCards+=$new.FixtureCard($row,$kind)
                        $attributesBefore+=Clean-Attributes ($old.FixtureAttributes($row));$attributesAfter+=$new.FixtureAttributes($row)
                    }
                    $expected=($beforeCards|ForEach-Object{Stable-Tokens (Without-Old-Claims $_)}) -join ''
                    $actual=($afterCards|ForEach-Object{Stable-Tokens $_}) -join ''
                    Check "$tag/$kind complete real HTML parity except removed sales block/metadata and empty footer" ($expected -ceq $actual)
                    Check "$tag/$kind remaining Quick View attributes identical" (($attributesBefore -join '') -ceq ($attributesAfter -join ''))
                    Check "$tag/$kind no public sales claims or sales ARIA" ($actual -notmatch 'Venduti:|Vendite annuali|product-progress-sale|ks-home-progress|role=''progressbar''|aria-valuenow|aria-valuetext|data-ks-sold|data-ks-progress')
                }
                $renderedOld=@($oldSelected.Rows|ForEach-Object{$old.FixtureCard($_,'deal')})
                $renderedNew=@($newSelected.Rows|ForEach-Object{$new.FixtureCard($_,'deal')})
                Check "$tag no residual empty countdown/footer" (($renderedNew -join '') -notmatch "ks-deal-card__footer'>\s*</div>|ks-deal-slot--countdown'[^>]*>\s*</div>")
                Check "$tag countdown present and absent cases covered" ((@($renderedNew|Where-Object{$_ -match 'js-countdown'}).Count -gt 0) -and (@($renderedNew|Where-Object{$_ -notmatch 'ks-deal-card__footer'}).Count -gt 0))
                Check "$tag inputs and all commercial facts untouched" ($inputBefore -ceq (Table-Xml $table))
                foreach($version in @('baseline','candidate')){
                    $cards=$renderedOld;if($version -eq 'candidate'){$cards=$renderedNew}
                    $template=[regex]::Match($section,'(?s)<ItemTemplate>(.*?)</ItemTemplate>').Groups[1].Value
                    $items=@($cards|ForEach-Object{$template.Replace('<%# RenderDealCard(Container.DataItem) %>',$_)}) -join ''
                    $fragment=[regex]::Replace($section,'(?s)<asp:Repeater\b.*?</asp:Repeater>',[Text.RegularExpressions.MatchEvaluator]{param($m) return $items})
                    $fragment=$fragment -replace '<asp:Panel\s+ID="([^"]+)"\s+runat="server"\s+CssClass="([^"]+)">','<div id="$1" class="$2">' -replace '</asp:Panel>','</div>'
                    $fragment=$fragment -replace '\srunat="server"','' -replace '\svisible="false"',''
                    Check "$tag/$version real WebForms wrappers materialized" ($fragment -notmatch '<asp:' -and $fragment -match 'id="HomeOffersSliderWrap" class="box-btn-slide-2 sw-nav-effect"')
                    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($tag+'-'+$version+'.html')),$fragment,$utf8)
                }
                $fixtures.Add([pscustomobject]@{Name=$tag;Tenant=$tenant;Authenticated=$authenticated;VatIncluded=$included;Rows=$newSelected.Rows.Count;Identities=@($newSelected.Rows|ForEach-Object{[string]$_.id+':'+[string]$_.TCid});BaselineFile=$tag+'-baseline.html';CandidateFile=$tag+'-candidate.html'})
            }
        }
    }
    $report=[ordered]@{Passed=$checks.Count;Failed=0;Checks=$checks;Fixtures=$fixtures;Baseline=$BaselineRef;SourceHash=(Get-FileHash -LiteralPath (Join-Path $RepositoryRoot 'Default.aspx.vb') -Algorithm SHA256).Hash;ExtractedMethods=@($names|Sort-Object);Scope='Verbatim baseline/candidate renderers, offer sorting and selection compiled with real availability, price formatting, context and image helpers. Cart action helpers extracted verbatim. Synthetic rows/snapshots; no DB, HTTP, operational configuration or full Page lifecycle.';TokenNormalization='Only random request IDs and elapsed countdown seconds are normalized for differential HTML comparisons.'}
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'test-report.json'),($report|ConvertTo-Json -Depth 10),$utf8)
    Write-Output ('HOME_SALES_CLAIMS_PASS='+$checks.Count)
    Write-Output ('HOME_SALES_CLAIMS_FIXTURES='+$fixtures.Count)
}finally{
    if($compiler){$compiler.Dispose()}
    $resolved=[IO.Path]::GetFullPath($work)
    if((Test-Path -LiteralPath $resolved) -and $resolved.StartsWith($tempRoot+'\ks-sales-claims-compile-',[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
