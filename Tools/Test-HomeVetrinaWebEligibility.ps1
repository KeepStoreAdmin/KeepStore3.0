[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$BaselineRef='b466bc61ea35f81a71d6079572790bdf8de732ce'
)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5){throw 'HOME_VETRINA_REQUIRES_PS51'}
if(!$RepositoryRoot){$RepositoryRoot=Split-Path -Parent $PSScriptRoot}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$EvidenceDirectory=[IO.Path]::GetFullPath($EvidenceDirectory).TrimEnd('\')
if(!$EvidenceDirectory.StartsWith($tempRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or
   (Test-Path -LiteralPath $EvidenceDirectory) -or $BaselineRef -notmatch '^[a-f0-9]{40}$'){throw 'HOME_VETRINA_INVALID_OUTPUT_OR_BASE'}
$work=Join-Path $tempRoot ('ks-home-vetrina-compile-'+[Guid]::NewGuid().ToString('N'))
$utf8=New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$checks=New-Object 'Collections.Generic.List[object]'
$fixtures=New-Object 'Collections.Generic.List[object]'
function Check([string]$name,[bool]$ok){
    $checks.Add([pscustomobject]@{Name=$name;Pass=$ok})
    if(!$ok){throw ('HOME_VETRINA_ASSERT: '+$name)}
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
    if(!$table.TableName){$table=$table.Copy();$table.TableName='Products'}
    $writer=New-Object IO.StringWriter
    try{$table.WriteXml($writer,[Data.XmlWriteMode]::WriteSchema);return $writer.ToString()}finally{$writer.Dispose()}
}
function Stable-Tokens([string]$html){
    $html=[regex]::Replace($html,'(?i)(requestId=|data-ks-request-id='')[a-f0-9]{32}','$1FIXTURE_REQUEST_ID')
    return [regex]::Replace($html,"data-timer='[0-9]+'","data-timer='FIXTURE_SECONDS'")
}
try{
    New-Item -ItemType Directory -Path $EvidenceDirectory,$work | Out-Null
    Add-Type -AssemblyName System.Web
    Add-Type -AssemblyName Microsoft.VisualBasic
    $source=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx.vb'))
    $baseline=(git -C $RepositoryRoot show ($BaselineRef+':Default.aspx.vb')) -join [Environment]::NewLine
    if($LASTEXITCODE -ne 0){throw 'HOME_VETRINA_BASE_UNAVAILABLE'}
    $beforeMap=Method-Map $baseline
    $afterMap=Method-Map $source
    $changed=@('TryLoadProducts','BindHome')
    $beforeRest=$baseline;$afterRest=$source
    foreach($name in $changed){
        Check "$name occurs exactly once" ($beforeMap[$name].Count -eq 1 -and $afterMap[$name].Count -eq 1)
        $beforeRest=$beforeRest.Replace($beforeMap[$name][0],'')
        $afterRest=$afterRest.Replace($afterMap[$name][0],'')
    }
    Check 'entire VB source outside loader and BindHome unchanged' ((Normalize $beforeRest) -ceq (Normalize $afterRest))
    $gate='        sql.Append("AND COALESCE(v.Vetrina,0)=1 ")'
    Check 'only change to real SQL loader is common Vetrina predicate' ((Normalize $afterMap.TryLoadProducts[0].Replace($gate+[Environment]::NewLine,'')) -ceq (Normalize $beforeMap.TryLoadProducts[0]))
    Check 'only composition change hides empty recent section' ((Normalize $afterMap.BindHome[0].Replace('HomeRecentlyViewedSection.Visible = Not IsTableEmpty(recentRows)','HomeRecentlyViewedSection.Visible = True')) -ceq (Normalize $beforeMap.BindHome[0]))
    foreach($path in @('articoli.aspx','articoli.aspx.vb','articolo.aspx','articolo.aspx.vb','search_suggest.aspx.vb','Public/assets/keepstore/js/ks-shopping-guide.js')){
        $oldFile=(git -C $RepositoryRoot show ($BaselineRef+':'+$path)) -join [Environment]::NewLine
        Check "$path untouched; excluded HOME items keep existing catalog/PDP routes" ((Normalize $oldFile) -ceq (Normalize ([IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)))))
    }
    $baselineMarkup=(git -C $RepositoryRoot show ($BaselineRef+':Default.aspx')) -join [Environment]::NewLine
    $candidateMarkup=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Default.aspx'))
    $withoutMarker=$candidateMarkup.Replace('             data-ks-authoritative-only="1"'+[Environment]::NewLine,'').Replace('20261022-home-vetrina-1a','20260916-promo-parity-rev1')
    Check 'HOME markup changes only authoritative marker and script version' ((Normalize $withoutMarker) -ceq (Normalize $baselineMarkup))
    $baselineJs=(git -C $RepositoryRoot show ($BaselineRef+':Public/assets/keepstore/js/keepstore-recently-viewed.js')) -join [Environment]::NewLine
    $candidateJs=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'Public/assets/keepstore/js/keepstore-recently-viewed.js'))
    $withoutBranch=[regex]::Replace($candidateJs,'(?ms)^    // La HOME pubblica.*?^    }\r?\n\r?\n','')
    Check 'JS outside marker-scoped authoritative branch identical including history/PDP contract' ((Normalize $withoutBranch) -ceq (Normalize $baselineJs))
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'baseline-recent.js'),$baselineJs,$utf8)
    $names=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $queue=New-Object 'Collections.Generic.Queue[string]'
    $pools=@('GetDealOfferPool','GetFeaturedPool','GetMostViewedPool','GetTopRatedPool','GetNewArrivalsPool','GetBestSellerPool','GetPureTopSellingPool','GetCurrentYearSellingPool','GetCatalogFallbackPool')
    @('RenderDealCard','BuildQuickViewAttributes','RenderGridCard','RenderRowCard','RenderBigCard','SortAuthorizedDealRows','TakeDiverseRows','EmptyProductsTable','GetRecentlyViewedProducts','FilterAuthorizedPromotionRows','IsTableEmpty','AvailabilityWhereClause','ReservedWhereClause')+$pools|ForEach-Object{$queue.Enqueue($_)}
    while($queue.Count){
        $name=$queue.Dequeue()
        if(!$names.Add($name)){continue}
        if(!$beforeMap.ContainsKey($name)){throw ('HOME_VETRINA_MISSING_METHOD: '+$name)}
        if($name -eq 'TryLoadProducts'){continue}
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
    $sharedSources+=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/StorefrontEffectivePriceSqlBuilder.vb'))
    $inventory=Method-Map ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'App_Code/OrderInventoryAvailabilityService.vb')))
    $sharedSources+=('Imports System'+[Environment]::NewLine+'Public Class OrderInventoryAvailabilityService'+[Environment]::NewLine+$inventory['CalculateNetAvailableQuantity'][0]+[Environment]::NewLine+'End Class')
    $compiler=New-Object Microsoft.VisualBasic.VBCodeProvider
    function Compile-Renderer([hashtable]$map,[string]$className){
        # Capture the verbatim SQL construction; replace only the database execution
        # boundary with an explicit synthetic adapter. No connection object exists.
        $loader=$map.TryLoadProducts[0]
        $loader=$loader.Substring(0,$loader.IndexOf('        Try'+[Environment]::NewLine))+"        Return FixtureQuery(sql.ToString(), whereClause, orderClause, limit, requireAuthorizedPromotion)`n    End Function"
        $body=($names|ForEach-Object{if($_ -eq 'TryLoadProducts'){$loader}else{$map[$_]}}) -join [Environment]::NewLine
        $wrapper=@'
    Private ReadOnly ItCulture As CultureInfo = CultureInfo.GetCultureInfo("it-IT")
    Private _priceDisplayContext As StorefrontPriceDisplayContext
    Public FixtureQuery As Func(Of String, String, String, Integer, Boolean, DataTable)
    Public ReadOnly Session As New Dictionary(Of String, Object) From {{"ks_recent_ids", ""}, {"ks_recent_session", ""}}
    Public Request As New HttpRequest("", "https://vetrina.invalid/", "")
    Public Function Pool(name As String, limit As Integer) As DataTable
        Return DirectCast(Me.GetType().GetMethod(name, Reflection.BindingFlags.NonPublic Or Reflection.BindingFlags.Instance).Invoke(Me, New Object() {limit}), DataTable)
    End Function
    Public Function Recent(limit As Integer) As DataTable
        Return GetRecentlyViewedProducts(limit)
    End Function
    Public Function AuthorizedPromos(rows As DataTable) As DataTable
        Return FilterAuthorizedPromotionRows(rows)
    End Function
    Public Function RecentVisible(rows As DataTable) As Boolean
        Return Not IsTableEmpty(rows)
    End Function
    Public Function Featured(rows As DataTable) As DataTable
        Return TakeDiverseRows(8, New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), New HashSet(Of String)(StringComparer.OrdinalIgnoreCase), rows)
    End Function
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
        $composition=@'
    Public Function Composition() As Dictionary(Of String, DataTable)
        Dim usedBusinessKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim usedDisplayKeys As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)
        Dim dealPool As DataTable = GetDealOfferPool(96)
        Dim featuredPool As DataTable = GetFeaturedPool(96)
        Dim newArrivalsPool As DataTable = GetNewArrivalsPool(120)
        Dim topRatedPool As DataTable = GetTopRatedPool(120)
        Dim bestSellerPool As DataTable = GetBestSellerPool(120)
        Dim currentYearSellingPool As DataTable = GetCurrentYearSellingPool(120)
        Dim topSellingPool As DataTable
        If Not IsTableEmpty(bestSellerPool) Then
            topSellingPool = bestSellerPool.Copy()
        Else
            topSellingPool = GetPureTopSellingPool(120)
        End If
        Dim fallbackCatalogPool As DataTable = GetCatalogFallbackPool(160)
        __SELECTIONS__
        Return New Dictionary(Of String, DataTable) From {{"deals", dealRows}, {"featured", featuredRows}, {"neutral", bestRows}, {"recent", recentRows}}
    End Function
'@
        # Verbatim downstream selection expressions and cross-section exclusions.
        $selections=@('dealRows','featuredRows','bestRows','recentRows')|ForEach-Object{[regex]::Match($map.BindHome[0],"(?m)^        Dim $_ As DataTable = .*$").Value.TrimEnd()}
        $wrapper+=[Environment]::NewLine+$composition.Replace('__SELECTIONS__',($selections -join [Environment]::NewLine))
        $imports="Imports System`nImports System.Data`nImports System.Collections.Generic`nImports System.Globalization`nImports System.Text`nImports System.Text.RegularExpressions`nImports System.Web`n"
        $code=$imports+'Public Class '+$className+[Environment]::NewLine+$body+[Environment]::NewLine+$wrapper+[Environment]::NewLine+'End Class'
        $parameters=New-Object CodeDom.Compiler.CompilerParameters
        $parameters.GenerateInMemory=$true
        $parameters.CompilerOptions='/optionInfer+ /optionExplicit+ /optionStrict- /imports:Microsoft.VisualBasic'
        $parameters.TempFiles=New-Object CodeDom.Compiler.TempFileCollection($work,$false)
        foreach($assembly in @('System.dll','System.Core.dll','System.Data.dll','System.Xml.dll','System.Web.dll','System.Configuration.dll')){[void]$parameters.ReferencedAssemblies.Add($assembly)}
        $compiled=$compiler.CompileAssemblyFromSource($parameters,[string[]](@($code,$cartCode)+$sharedSources))
        if($compiled.Errors.HasErrors){throw ('HOME_VETRINA_COMPILE: '+(($compiled.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{$_.ErrorText}) -join '; '))}
        return [Activator]::CreateInstance($compiled.CompiledAssembly.GetType($className,$true))
    }
    $old=Compile-Renderer $beforeMap 'BaselineHomeVetrina'
    $new=Compile-Renderer $afterMap 'CandidateHomeVetrina'
    # Explicit in-memory adapter for captured SQL. It models only the known
    # HOME fixture predicates/order; it does not certify a MySQL engine/view.
    $adapter=[Func[string,string,string,int,bool,Data.DataTable]]{
        param($sql,$where,$order,$limit,$promos)
        $script:LastSql=$sql
        $filter='id > 0 AND Abilitato = 1 AND Giacenza >= 1 AND NListino = '+$script:Listino+' AND (Prezzo > 0 OR PrezzoIvato > 0 OR PrezzoPromo > 0 OR PrezzoPromoIvato > 0)'
        if($sql.Contains('AND COALESCE(v.Vetrina,0)=1 ')){$filter+=' AND ISNULL(Vetrina,0) = 1'}
        if($where.Contains("COALESCE(NULLIF(v.Img1,''),'')<>''")){$filter+=" AND ISNULL(Img1,'') <> ''"}
        if($where.Contains('COALESCE(s.QtaVenduta,0)>0')){$filter+=' AND ISNULL(QtaVenduta,0)>0'}
        if($where.Contains('COALESCE(sy.VendutiAnno,0)>0')){$filter+=' AND ISNULL(VendutiAnno,0)>0'}
        if($where.Contains('COALESCE(v.Visite,0)>0')){$filter+=' AND ISNULL(Visite,0)>0'}
        if($where.Contains('DATE_SUB')){$filter+=" AND DataCreazione >= #"+[DateTime]::Today.AddDays(-365).ToString('MM/dd/yyyy',[Globalization.CultureInfo]::InvariantCulture)+'#'}
        if($where.Contains('COALESCE(v.InOfferta,0)=1')){$filter+=' AND InOfferta=1 AND (OfferteDaListino IS NULL OR OfferteDaListino <= '+$script:Listino+') AND (OfferteAListino IS NULL OR OfferteAListino >= '+$script:Listino+')'}
        $ids=[regex]::Match($where,'v.id IN \(([0-9,]+)\)')
        if($ids.Success){$filter+=' AND id IN ('+$ids.Groups[1].Value+')'}
        $sort=$order.Replace('COALESCE(v.DataCreazione,CURDATE())','DataCreazione')
        $sort=[regex]::Replace($sort,'COALESCE\((?:v|s|sy)\.(\w+),0\)','$1')
        $sort=[regex]::Replace($sort,'\b(?:v|s|sy)\.','')
        $result=$script:InputRows.Clone()
        if($order.StartsWith('CASE v.id ')){
            foreach($m in [regex]::Matches($order,'WHEN ([0-9]+) THEN [0-9]+')){
                foreach($r in $script:InputRows.Select($filter+' AND id='+$m.Groups[1].Value)){$result.ImportRow($r)}
            }
        }else{foreach($r in $script:InputRows.Select($filter,$sort)){$result.ImportRow($r)}}
        if($limit -gt 0){while($result.Rows.Count -gt $limit){$result.Rows.RemoveAt($result.Rows.Count-1)}}
        if($promos){$result=$new.AuthorizedPromos($result)}
        return ,$result
    }
    $old.FixtureQuery=$adapter;$new.FixtureQuery=$adapter
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
                foreach($column in @('NListino')){if(!$table.Columns.Contains($column)){[void]$table.Columns.Add($column,[int])}}
                for($i=0;$i -lt 40;$i++){
                    $row=$table.NewRow()
                    foreach($column in $table.Columns){
                        if($column.DataType -eq [string]){$row[$column.ColumnName]=''}
                        elseif($column.DataType -eq [datetime]){$row[$column.ColumnName]=[DBNull]::Value}
                        else{$row[$column.ColumnName]=0}
                    }
                    $row.id=300+$i;$row.TCid=@(-1,0,10,20,-1,11,12,15)[$i % 8]
                    if($i -eq 5 -or $i -eq 6){$row.id=300}
                    $row.Codice=$tag+'-'+$i;$row.Ean=$tag+'-'+$i
                    $labels=@('Router','Mouse','Tastiera','Monitor','Cavo','Scheda','Memoria','Notebook')
                    if($tenant -eq 'Food'){$labels=@('Pasta','Riso','Farina','Acqua','Olio','Caffe','Sale','Miele')}
                    $row.Descrizione1=$tenant+' '+$labels[$i % 8]+' Serie'+$i+' sintetico & modello'
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
                    $row.QtaVenduta=50+$i;$row.VendutiAnno=@(0,12,999999,-5,[DBNull]::Value,3.25,15,100)[$i % 8]
                    $row.NListino=$listino;$row.Vetrina=1;$row.Abilitato=1;$row.Attivo=1
                    $row.DataCreazione=[DateTime]::Today.AddDays(-$i);$row.InOfferta=1
                    $row.OfferteDaListino=[DBNull]::Value;$row.OfferteAListino=[DBNull]::Value
                    $row.DisplayPromoSnapshotReady=$true;$row.DisplayPromoTechnicalError=($i -eq 7)
                    $row.DisplayPromoQtyOnePrice=0;$row.DisplayPromoTierPrice=0
                    if($i -ne 3 -and $i -ne 7){if($included){$row.DisplayPromoQtyOnePrice=97.6}else{$row.DisplayPromoQtyOnePrice=80}}
                    if($i -eq 3){if($included){$row.DisplayPromoTierPrice=85.4}else{$row.DisplayPromoTierPrice=70};$row.DisplayPromoTierQntMinima=3}
                    if($i -in @(1,2,5,6)){$row.DisplayPromoDeadline=[DateTime]::Today.AddDays(15+$i)}
                    $table.Rows.Add($row)
                }
                $inputBefore=Table-Xml $table
                $script:Listino=$listino
                foreach($eligibleCount in @(0,1,3,32)){
                    $mixed=$table.Copy()
                    for($i=0;$i -lt $mixed.Rows.Count;$i++){$mixed.Rows[$i].Vetrina=$(if($i -lt $eligibleCount){1}else{@(0,[DBNull]::Value,-1,2)[$i % 4]})}
                    # High-ranked ineligible rows and four commercial failures prove
                    # that selection is constrained before TOP/LIMIT, never afterwards.
                    $mixed.Rows[36].NListino=999;$mixed.Rows[37].Abilitato=0;$mixed.Rows[38].Giacenza=0
                    foreach($i in 36..39){$mixed.Rows[$i].Vetrina=1}
                    foreach($column in @('Prezzo','PrezzoIvato','PrezzoPromo','PrezzoPromoIvato')){$mixed.Rows[39][$column]=0}
                    $eligible=$mixed.Clone();foreach($r in $mixed.Select('ISNULL(Vetrina,0)=1')){$eligible.ImportRow($r)}
                    foreach($pool in $pools){
                        $script:InputRows=$eligible;$expectedRows=$old.Pool($pool,8);$oldSql=$script:LastSql
                        $script:InputRows=$mixed;$actualRows=$new.Pool($pool,8);$newSql=$script:LastSql
                        $outer=$newSql.IndexOf('WHERE v.NListino=@listino')
                        $predicate=$newSql.IndexOf('AND COALESCE(v.Vetrina,0)=1 ',$outer)
                        $orderIndex=$newSql.LastIndexOf('ORDER BY ')
                        Check "$tag/$eligibleCount/$pool gate precedes order and limit" ($outer -ge 0 -and $predicate -gt $outer -and $predicate -lt $orderIndex -and ($newSql.LastIndexOf('LIMIT ') -lt 0 -or $newSql.LastIndexOf('LIMIT ') -gt $orderIndex))
                        Check "$tag/$eligibleCount/$pool SQL otherwise identical" ($newSql.Remove($predicate,'AND COALESCE(v.Vetrina,0)=1 '.Length) -ceq $oldSql)
                        Check "$tag/$eligibleCount/$pool identity/order/commercial parity against eligible baseline" ((Table-Xml $expectedRows) -ceq (Table-Xml $actualRows))
                        Check "$tag/$eligibleCount/$pool all admitted rows Vetrina1 current listino" ($actualRows.Rows.Count -eq 0 -or @($actualRows.Select('ISNULL(Vetrina,0)<>1 OR NListino<>'+ $listino)).Count -eq 0)
                    }
                    $old.Session['ks_recent_ids']='339,300,310,301,302,310,0,-1,not-an-id'
                    $new.Session['ks_recent_ids']=$old.Session['ks_recent_ids']
                    $old.Request.Cookies.Set((New-Object Web.HttpCookie('ks_recent','303%2C304%2C305%2C306%2C307%2C308%2C309')))
                    $new.Request.Cookies.Set((New-Object Web.HttpCookie('ks_recent',$old.Request.Cookies['ks_recent'].Value)))
                    $script:InputRows=$eligible;$oldRecent=$old.Recent(8)
                    $script:InputRows=$mixed;$newRecent=$new.Recent(8)
                    Check "$tag/$eligibleCount mixed session/cookie recents preserve valid order and identity" ((Table-Xml $oldRecent) -ceq (Table-Xml $newRecent))
                    Check "$tag/$eligibleCount recent server wrapper omitted when empty" ($new.RecentVisible($newRecent) -eq ($newRecent.Rows.Count -gt 0))
                    Check "$tag/$eligibleCount fallback keeps only admitted rows" (@($new.Featured($actualRows).Select('ISNULL(Vetrina,0)<>1')).Count -eq 0)
                    $script:InputRows=$eligible;$expectedComposition=$old.Composition()
                    $script:InputRows=$mixed;$actualComposition=$new.Composition()
                    foreach($sectionName in @('deals','featured','neutral','recent')){
                        Check "$tag/$eligibleCount/$sectionName complete composition and fallback parity" ((Table-Xml $expectedComposition[$sectionName]) -ceq (Table-Xml $actualComposition[$sectionName]))
                        Check "$tag/$eligibleCount/$sectionName composition contains no unauthorized products" (@($actualComposition[$sectionName].Select('ISNULL(Vetrina,0)<>1')).Count -eq 0)
                    }
                    if($eligibleCount -eq 0){Check "$tag zero eligible cannot populate any product section" ($actualRows.Rows.Count -eq 0 -and $newRecent.Rows.Count -eq 0)}
                }
                $fallback=$table.Copy()
                for($i=0;$i -lt $fallback.Rows.Count;$i++){
                    $r=$fallback.Rows[$i];$r.Vetrina=$(if($i % 4 -eq 0){0}elseif($i % 4 -eq 1){[DBNull]::Value}else{1})
                    $r.InOfferta=0;$r.QtaVenduta=0;$r.VendutiAnno=0;$r.Visite=0;$r.DataCreazione=[DateTime]::Today.AddDays(-500)
                }
                $fallbackEligible=$fallback.Clone();foreach($r in $fallback.Select('ISNULL(Vetrina,0)=1')){$fallbackEligible.ImportRow($r)}
                $script:InputRows=$fallbackEligible;$oldFallback=$old.Composition()
                $script:InputRows=$fallback;$newFallback=$new.Composition()
                foreach($sectionName in @('deals','featured','neutral','recent')){
                    Check "$tag catalog-only fallback composition $sectionName parity" ((Table-Xml $oldFallback[$sectionName]) -ceq (Table-Xml $newFallback[$sectionName]))
                    Check "$tag catalog-only fallback $sectionName rejects disabled and null" (@($newFallback[$sectionName].Select('ISNULL(Vetrina,0)<>1')).Count -eq 0)
                }
                Check "$tag neutral section really exercises generic catalog fallback without sales/visits/new arrivals" ($newFallback['deals'].Rows.Count -eq 0 -and $newFallback['featured'].Rows.Count -eq 8 -and $newFallback['neutral'].Rows.Count -gt 0)
                $oldSorted=$old.FixtureSort($table);$newSorted=$new.FixtureSort($table)
                Check "$tag real offer sort full-row/order parity" ((Table-Xml $oldSorted) -ceq (Table-Xml $newSorted))
                $oldSelected=$old.FixtureSelect($oldSorted);$newSelected=$new.FixtureSelect($newSorted)
                Check "$tag real selection identity/order/values parity" ((Table-Xml $oldSelected) -ceq (Table-Xml $newSelected))
                Check "$tag six distinct selected products exercised" ($newSelected.Rows.Count -eq 6)
                foreach($kind in @('deal','grid','row','big')){
                    $beforeCards=@();$afterCards=@();$attributesBefore=@();$attributesAfter=@()
                    foreach($row in $table.Rows){
                        $beforeCards+=$old.FixtureCard($row,$kind);$afterCards+=$new.FixtureCard($row,$kind)
                        $attributesBefore+=$old.FixtureAttributes($row);$attributesAfter+=$new.FixtureAttributes($row)
                    }
                    $expected=($beforeCards|ForEach-Object{Stable-Tokens $_}) -join ''
                    $actual=($afterCards|ForEach-Object{Stable-Tokens $_}) -join ''
                    Check "$tag/$kind complete real HTML parity for eligible products" ($expected -ceq $actual)
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
                    $recentSection=[regex]::Match($markup,'(?s)<section id="HomeRecentlyViewedSection".*?</section>').Value
                    if($version -eq 'baseline'){$recentSection=$recentSection.Replace('             data-ks-authoritative-only="1"'+[Environment]::NewLine,'')}
                    $recentTemplate=[regex]::Match($recentSection,'(?s)<ItemTemplate>(.*?)</ItemTemplate>').Groups[1].Value
                    $recentCards=@($table.Rows|Select-Object -First 8|ForEach-Object{$recentTemplate.Replace('<%# RenderGridCard(Container.DataItem) %>',$new.FixtureCard($_,'grid'))}) -join ''
                    $recentSection=[regex]::Replace($recentSection,'(?s)<asp:Repeater\b.*?</asp:Repeater>',[Text.RegularExpressions.MatchEvaluator]{param($m)return $recentCards})
                    $recentSection=$recentSection -replace '\srunat="server"','' -replace '\svisible="false"','' -replace '<%= ThemeManager.PlaceholderProductImageUrl\(\) %>','/Public/assets/images/img/placeholder.svg'
                    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory ($tag+'-recent-'+$version+'.html')),$recentSection,$utf8)
                }
                $fixtures.Add([pscustomobject]@{Name=$tag;Tenant=$tenant;Authenticated=$authenticated;VatIncluded=$included;Rows=$newSelected.Rows.Count;Identities=@($newSelected.Rows|ForEach-Object{[string]$_.id+':'+[string]$_.TCid});BaselineFile=$tag+'-baseline.html';CandidateFile=$tag+'-candidate.html'})
            }
        }
    }
    $report=[ordered]@{Passed=$checks.Count;Failed=0;Checks=$checks;Fixtures=$fixtures;Baseline=$BaselineRef;SourceHash=(Get-FileHash -LiteralPath (Join-Path $RepositoryRoot 'Default.aspx.vb') -Algorithm SHA256).Hash;ExtractedMethods=@($names|Sort-Object);Scope='Verbatim baseline/candidate SQL construction, nine pools, recent session/cookie retrieval, real composition expressions, selectors and renderers. Database execution boundary replaced with explicit DataTable fixture adapter. Real price/availability/image/cart helpers, synthetic snapshots. No MySQL/view/tenant resolution, HTTP, operational config or full Page lifecycle certification.';TokenNormalization='Only random request IDs and elapsed countdown seconds are normalized for differential HTML comparisons.'}
    [IO.File]::WriteAllText((Join-Path $EvidenceDirectory 'test-report.json'),($report|ConvertTo-Json -Depth 10),$utf8)
    Write-Output ('HOME_VETRINA_PASS='+$checks.Count)
    Write-Output ('HOME_VETRINA_FIXTURES='+$fixtures.Count)
}finally{
    if($compiler){$compiler.Dispose()}
    $resolved=[IO.Path]::GetFullPath($work)
    if((Test-Path -LiteralPath $resolved) -and $resolved.StartsWith($tempRoot+'\ks-home-vetrina-compile-',[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
