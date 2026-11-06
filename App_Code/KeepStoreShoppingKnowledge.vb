Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Linq
Imports System.Security.Cryptography
Imports System.Text
Imports System.Text.RegularExpressions
Imports System.Web

' Facts are scoped to an already authorized commercial pool. This module never
' opens a connection, resolves offers, infers a variant, or interprets prose.
Public NotInheritable Class ShoppingAttributeDefinition
    Public Property Id As String
    Public Property Label As String
    Public Property Type As String
    Public Property Unit As String
    Public Property Scope As String
    Public Property Operators As New List(Of String)()
    Public Property Origin As String
    Public Property CanAsk As Boolean
    Public Property CanHardFilter As Boolean
    Public Property Risk As String
    Public Property Coverage As Decimal
    Public Property ObservedValues As New List(Of String)()
End Class

Public NotInheritable Class ShoppingAttributeValue
    Public Property Value As String
    Public Property NumericValue As Nullable(Of Decimal)
    Public Property EvidenceStatus As String
    Public Property SourceField As String
    Public Property EvidenceRef As String
    Public Property ProductKey As String
    Public Property KeyId As Integer
    Public Property TCId As Integer
    Public Property EvidenceText As String
End Class

Public NotInheritable Class ShoppingTextEvidence
    Public Property Text As String
    Public Property SourceField As String
    Public Property EvidenceRef As String
End Class

Public NotInheritable Class ShoppingProductFacts
    Public Property ProductKey As String
    Public Property KeyId As Integer
    Public Property TCId As Integer
    Public Property FamilyId As String
    Public Property Values As New Dictionary(Of String, ShoppingAttributeValue)(StringComparer.Ordinal)
    Public Property FreeTextEvidence As New List(Of ShoppingTextEvidence)()
End Class

Public NotInheritable Class ShoppingKnowledgeCorpus
    Public Property CatalogScope As String
    Public Property PolicyVersion As String
    Public Property Products As New List(Of ShoppingProductFacts)()
    Public Property Attributes As New List(Of ShoppingAttributeDefinition)()
    Public Property ProcessingLimited As Boolean
End Class

Public NotInheritable Class KeepStoreShoppingKnowledge
    Public Const CurrentPolicyVersion As String = "ks-attributes-1c.1"
    Public Const MaxProducts As Integer = 96
    Public Const MaxTextChars As Integer = 16384
    Public Const MaxAttributes As Integer = 32
    Public Const MaxPairsPerProduct As Integer = 48
    Public Const MaxEvidenceChars As Integer = 180
    Public Const MaxObservedValues As Integer = 16
    Private Const MaxLabelChars As Integer = 64
    Private Const MaxValueChars As Integer = 120
    Private Shared ReadOnly RegexBudget As TimeSpan = TimeSpan.FromMilliseconds(100)

    Private Sub New()
    End Sub

    Private NotInheritable Class Pair
        Public Label As String
        Public Text As String
        Public Field As String
        Public Position As Integer
    End Class

    Public Shared Function Build(ByVal rows As DataTable, ByVal catalogScope As String) As ShoppingKnowledgeCorpus
        Dim result As New ShoppingKnowledgeCorpus With {.CatalogScope = If(catalogScope, String.Empty), .PolicyVersion = CurrentPolicyVersion}
        If rows Is Nothing Then Return result
        Dim definitions As New Dictionary(Of String, ShoppingAttributeDefinition)(StringComparer.Ordinal)
        Dim identities As New HashSet(Of String)(StringComparer.Ordinal)
        result.ProcessingLimited = rows.Rows.Count > MaxProducts
        For Each row As DataRow In rows.Rows.Cast(Of DataRow)().Take(MaxProducts)
            Dim keyId As Integer = IntegerField(row, "id", 0)
            If keyId <= 0 Then Continue For
            Dim tcId As Integer = IntegerField(row, "TCid", Integer.MinValue)
            If tcId = Integer.MinValue Then Throw New ArgumentException("MISSING_KNOWLEDGE_VARIANT_IDENTITY")
            Dim product As New ShoppingProductFacts With {
                .KeyId = keyId, .TCId = tcId,
                .ProductKey = keyId.ToString(CultureInfo.InvariantCulture) & ":" & tcId.ToString(CultureInfo.InvariantCulture),
                .FamilyId = Family(row)}
            If Not identities.Add(product.ProductKey) Then Throw New ArgumentException("DUPLICATE_KNOWLEDGE_IDENTITY")
            result.Products.Add(product)
            Dim pairs As New List(Of Pair)()
            Dim incomplete As Boolean = False
            For Each field As String In {"Descrizione1", "Descrizione2", "DescrizioneLunga", "DescrizioneHTML"}
                Dim source As String = StringField(row, field)
                If source.Length > MaxTextChars Then
                    ' Never parse a prefix: a contradiction may occur after the bound.
                    result.ProcessingLimited = True
                    incomplete = True
                    Continue For
                End If
                If source.Length = 0 Then Continue For
                Try
                    Dim plain As String = PlainText(source)
                    If plain.Length > 0 Then product.FreeTextEvidence.Add(New ShoppingTextEvidence With {
                        .Text = Clip(plain, MaxEvidenceChars), .SourceField = field,
                        .EvidenceRef = EvidenceReference(product, field, source)})
                    For Each extracted As Pair In ExtractPairs(source, field)
                        pairs.Add(extracted)
                    Next
                Catch ex As RegexMatchTimeoutException
                    result.ProcessingLimited = True
                    incomplete = True
                Catch ex As ArgumentException
                    ' Invalid Unicode must not become an inferred replacement fact.
                    result.ProcessingLimited = True
                    incomplete = True
                Catch ex As FormatException
                    result.ProcessingLimited = True
                    incomplete = True
                End Try
            Next
            If incomplete OrElse pairs.Count > MaxPairsPerProduct Then
                ' Dropping only the tail could turn a conflicting pair into a known fact.
                result.ProcessingLimited = True
                pairs.Clear()
            End If
            Dim brand As String = StringField(row, "MarcheDescrizione")
            If brand.Length > 0 AndAlso brand.Length <= MaxValueChars AndAlso Not brand.Contains("<") Then
                pairs.Add(New Pair With {.Label = "Marca", .Text = brand, .Field = "MarcheDescrizione", .Position = 0})
            End If
            For Each grouping In pairs.GroupBy(Function(item) NormalizeLabel(item.Label), StringComparer.Ordinal)
                Dim first As Pair = grouping.First()
                Dim definition As ShoppingAttributeDefinition = CreateDefinition(first, product.FamilyId, result.CatalogScope)
                Dim attributeId As String = definition.Id
                If Not definitions.ContainsKey(attributeId) Then
                    If definitions.Count >= MaxAttributes Then
                        result.ProcessingLimited = True
                        Continue For
                    End If
                    definitions.Add(attributeId, definition)
                    result.Attributes.Add(definition)
                End If
                definition = definitions(attributeId)
                Dim entries As New List(Of ShoppingAttributeValue)()
                For Each item As Pair In grouping
                    entries.Add(ParseValue(item, definition, product))
                Next
                Dim value As ShoppingAttributeValue = entries(0)
                If entries.Count > 1 Then
                    If entries.Any(Function(item) item.EvidenceStatus <> "known") Then
                        value.EvidenceStatus = "ambiguous"
                    ElseIf entries.Select(Function(item) item.Value).Distinct(StringComparer.Ordinal).Count() <> 1 Then
                        value.EvidenceStatus = "conflicting"
                    End If
                    value.SourceField = String.Join(",", grouping.Select(Function(item) item.Field).Distinct(StringComparer.Ordinal))
                    value.EvidenceRef = EvidenceReference(product, value.SourceField, String.Join("|", grouping.Select(Function(item) item.Text)))
                End If
                If value.EvidenceStatus <> "known" Then
                    value.Value = Nothing
                    value.NumericValue = Nothing
                End If
                product.Values(attributeId) = value
            Next
        Next
        For Each definition As ShoppingAttributeDefinition In result.Attributes
            Dim familyProducts = result.Products.Where(Function(product) product.FamilyId = definition.Scope).ToList()
            Dim known As New List(Of String)()
            For Each product As ShoppingProductFacts In familyProducts
                If Not product.Values.ContainsKey(definition.Id) Then
                    product.Values(definition.Id) = New ShoppingAttributeValue With {
                        .EvidenceStatus = "missing", .ProductKey = product.ProductKey, .KeyId = product.KeyId, .TCId = product.TCId,
                        .SourceField = String.Empty, .EvidenceRef = String.Empty, .EvidenceText = String.Empty}
                End If
                Dim value As ShoppingAttributeValue = product.Values(definition.Id)
                If value.EvidenceStatus = "known" Then known.Add(value.Value)
            Next
            definition.Coverage = If(familyProducts.Count = 0, 0D, CDec(known.Count) / familyProducts.Count)
            definition.ObservedValues = known.Distinct(StringComparer.Ordinal).OrderBy(Function(value) value, StringComparer.Ordinal).Take(MaxObservedValues).ToList()
            ' Exact cardinality is not a usefulness score. High-cardinality fields
            ' remain inspectable, but do not create an arbitrary option question.
            If known.Distinct(StringComparer.Ordinal).Count() > MaxObservedValues Then definition.CanAsk = False
        Next
        Return result
    End Function

    Private Shared Function CreateDefinition(ByVal pair As Pair, ByVal family As String, ByVal catalogScope As String) As ShoppingAttributeDefinition
        Dim label As String = NormalizeLabel(pair.Label)
        Dim item As New ShoppingAttributeDefinition With {
            .Label = Clip(pair.Label, MaxLabelChars), .Type = "text", .Unit = String.Empty, .Scope = family,
            .Origin = If(pair.Field = "MarcheDescrizione", "catalog-field", "structured-description"),
            .CanAsk = False, .CanHardFilter = False, .Risk = "unapproved"}
        ' Explicit authored policy, not approval-by-discovery. These exact labels
        ' describe low-risk nominal properties only. No synonym/fuzzy matching,
        ' compatibility, allergen, certification or free-text semantics exist.
        Select Case label
            Case "marca"
                If pair.Field = "MarcheDescrizione" Then Approve(item, "text")
            Case "colore del prodotto", "materiale", "formato", "tecnologia di stampa"
                Approve(item, "text")
            Case "memoria installata", "memoria massima", "peso netto", "peso logistico", "capacita", "capacità", "volume"
                Approve(item, "number")
                item.Unit = NumberUnit(pair.Text)
                If Not AllowedUnit(label, item.Unit) Then
                    item.CanAsk = False : item.CanHardFilter = False : item.Risk = "uninterpretable-unit"
                End If
            Case "fronte/retro automatico"
                Approve(item, "boolean")
        End Select
        If family.StartsWith("0/", StringComparison.Ordinal) Then
            item.CanAsk = False : item.CanHardFilter = False : item.Risk = "unknown-family"
        End If
        item.Operators.Add("eq")
        If item.Type = "number" Then
            item.Operators.Add("gte") : item.Operators.Add("lte")
        End If
        item.Id = "a_" & Hash(CurrentPolicyVersion & "|" & catalogScope & "|" & family & "|" & label & "|" & item.Unit).Substring(0, 24)
        Return item
    End Function

    Private Shared Sub Approve(ByVal item As ShoppingAttributeDefinition, ByVal kind As String)
        item.Type = kind : item.CanAsk = True : item.CanHardFilter = True : item.Risk = "low"
    End Sub

    Private Shared Function AllowedUnit(ByVal label As String, ByVal unit As String) As Boolean
        Select Case label
            Case "memoria installata", "memoria massima"
                Return {"MB", "GB", "TB", "MiB", "GiB", "TiB"}.Contains(unit, StringComparer.Ordinal)
            Case "peso netto", "peso logistico"
                Return {"g", "kg"}.Contains(unit, StringComparer.Ordinal)
            Case "volume", "capacità", "capacita"
                Return {"ml", "l"}.Contains(unit, StringComparer.Ordinal)
        End Select
        Return False
    End Function

    Private Shared Function NumberUnit(ByVal text As String) As String
        Dim match As Match = Rx("^[0-9]+(?:[.,][0-9]+)?\s+([A-Za-z]+)$").Match(text)
        Return If(match.Success, match.Groups(1).Value, String.Empty)
    End Function

    Private Shared Function ParseValue(ByVal pair As Pair, ByVal definition As ShoppingAttributeDefinition, ByVal product As ShoppingProductFacts) As ShoppingAttributeValue
        Dim result As New ShoppingAttributeValue With {
            .Value = pair.Text, .EvidenceStatus = "known", .SourceField = pair.Field,
            .EvidenceRef = EvidenceReference(product, pair.Field & ":" & pair.Position.ToString(CultureInfo.InvariantCulture), pair.Label & "=" & pair.Text),
            .ProductKey = product.ProductKey, .KeyId = product.KeyId, .TCId = product.TCId,
            .EvidenceText = Clip(pair.Label & ": " & pair.Text, MaxEvidenceChars)}
        If definition.Type = "number" Then
            Dim parsed As Decimal
            Dim match As Match = Rx("^([0-9]+(?:[.,][0-9]+)?)\s+([A-Za-z]+)$").Match(pair.Text)
            If Not match.Success OrElse match.Groups(2).Value <> definition.Unit OrElse Not AllowedUnit(NormalizeLabel(pair.Label), definition.Unit) OrElse
                Not Decimal.TryParse(match.Groups(1).Value.Replace(",", "."), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, parsed) OrElse parsed > 1000000000D Then
                result.EvidenceStatus = "ambiguous"
            Else
                result.NumericValue = parsed : result.Value = parsed.ToString("0.############################", CultureInfo.InvariantCulture)
            End If
        ElseIf definition.Type = "boolean" Then
            Select Case NormalizeLabel(pair.Text)
                Case "sì", "si", "true" : result.Value = "true"
                Case "no", "false" : result.Value = "false"
                Case Else : result.EvidenceStatus = "ambiguous"
            End Select
        ElseIf Rx("(?:^|\s)(?:non|no|forse|circa|oppure|o)(?:\s|$)|[|;/]").IsMatch(pair.Text.ToLowerInvariant()) Then
            result.EvidenceStatus = "ambiguous"
        End If
        ' CURRENT descriptions originate on the article, not a proven variant
        ' attribute row. Keeping id:TCId is attribution, not permission to copy a
        ' parent's colour/memory into every positive variant. Brand is invariant.
        If product.TCId > 0 AndAlso pair.Field <> "MarcheDescrizione" Then result.EvidenceStatus = "ambiguous"
        Return result
    End Function

    Private Shared Function ExtractPairs(ByVal source As String, ByVal field As String) As List(Of Pair)
        Dim result As New List(Of Pair)()
        If Rx("<(?:script|style|iframe|object|svg|math|form)\b|<!--").IsMatch(source) Then Return result
        ' Scan balanced outer structures. A nested table/dl invalidates its whole
        ' outer block; inner layout cells can never be rediscovered as facts.
            Dim depth As Integer = 0, start As Integer = 0
            Dim nested As Boolean = False
            Dim outerTag As String = String.Empty
            Dim elements As New Stack(Of String)()
            For Each token As Match In Rx("</?(table|dl)\b[^>]*>").Matches(source)
                If Not token.Value.StartsWith("</", StringComparison.Ordinal) Then
                    If depth = 0 Then
                        start = token.Index + token.Length : nested = False
                        outerTag = token.Groups(1).Value.ToLowerInvariant()
                    Else
                        nested = True
                    End If
                    depth += 1
                    elements.Push(token.Groups(1).Value.ToLowerInvariant())
                Else
                    If depth = 0 OrElse elements.Pop() <> token.Groups(1).Value.ToLowerInvariant() Then Throw New FormatException("UNBALANCED_ATTRIBUTE_STRUCTURE")
                    depth -= 1
                    If depth = 0 AndAlso Not nested AndAlso token.Groups(1).Value.ToLowerInvariant() = outerTag Then
                        Dim body As String = source.Substring(start, token.Index - start)
                        If Rx("<(?:script|style|iframe|object|svg|math|form|input|table|dl)\b").IsMatch(body) Then Continue For
                        Dim parsed As List(Of Pair) = If(outerTag = "table", ParseTable(body, field, start), ParseDefinitionList(body, field, start))
                        result.AddRange(parsed)
                    End If
                End If
            Next
            If depth <> 0 Then Throw New FormatException("UNBALANCED_ATTRIBUTE_STRUCTURE")
        Return result
    End Function

    Private Shared Function ParseTable(ByVal body As String, ByVal field As String, ByVal offset As Integer) As List(Of Pair)
        Dim result As New List(Of Pair)()
        body = Rx("</?(?:tbody|thead|tfoot)\b[^>]*>").Replace(body, String.Empty).Trim()
        Dim rows As MatchCollection = Rx("<tr\b[^>]*>(.*?)</tr\s*>").Matches(body)
        If rows.Count = 0 OrElse Rx("<tr\b[^>]*>.*?</tr\s*>").Replace(body, String.Empty).Trim().Length <> 0 Then Return result
        For Each row As Match In rows
            Dim content As String = row.Groups(1).Value
            Dim cells As MatchCollection = Rx("<(td|th)\b([^>]*)>(.*?)</\1\s*>").Matches(content)
            If cells.Count <> 2 OrElse Rx("<(td|th)\b[^>]*>.*?</\1\s*>").Replace(content, String.Empty).Trim().Length <> 0 Then Return New List(Of Pair)()
            If cells.Cast(Of Match)().Any(Function(cell) Rx("\b(?:colspan|rowspan)\s*=").IsMatch(cell.Groups(2).Value)) Then Return New List(Of Pair)()
            Dim label As String = CellText(cells(0).Groups(3).Value)
            Dim value As String = CellText(cells(1).Groups(3).Value)
            If Not ValidPair(label, value) Then Return New List(Of Pair)()
            result.Add(New Pair With {.Label = label, .Text = value, .Field = field, .Position = offset + row.Index})
        Next
        Return result
    End Function

    Private Shared Function ParseDefinitionList(ByVal body As String, ByVal field As String, ByVal offset As Integer) As List(Of Pair)
        Dim result As New List(Of Pair)()
        Dim pattern As String = "<dt\b[^>]*>(.*?)</dt\s*>\s*<dd\b[^>]*>(.*?)</dd\s*>"
        Dim entries As MatchCollection = Rx(pattern).Matches(body)
        If entries.Count = 0 OrElse Rx(pattern).Replace(body, String.Empty).Trim().Length <> 0 Then Return result
        For Each entry As Match In entries
            Dim label As String = CellText(entry.Groups(1).Value)
            Dim value As String = CellText(entry.Groups(2).Value)
            If Not ValidPair(label, value) Then Return New List(Of Pair)()
            result.Add(New Pair With {.Label = label, .Text = value, .Field = field, .Position = offset + entry.Index})
        Next
        Return result
    End Function

    Private Shared Function ValidPair(ByVal label As String, ByVal value As String) As Boolean
        Return Not String.IsNullOrWhiteSpace(label) AndAlso label.Length <= MaxLabelChars AndAlso
            Not String.IsNullOrWhiteSpace(value) AndAlso value.Length <= MaxValueChars AndAlso
            Not label.Contains(":") AndAlso Not label.Contains("?") AndAlso Not value.Contains("<") AndAlso Not value.Contains(">")
    End Function

    Private Shared Function CellText(ByVal source As String) As String
        For Each tag As Match In Rx("<[^>]*>").Matches(source)
            If Not Rx("^</?(?:b|strong|i|em|span|small|sub|sup|br)\b[^>]*>$").IsMatch(tag.Value) Then Return String.Empty
        Next
        Return PlainText(source)
    End Function

    Private Shared Function PlainText(ByVal value As String) As String
        Dim clean As String = Rx("<!--.*?-->|<(script|style)\b[^>]*>.*?</\1\s*>").Replace(value, " ")
        clean = Rx("<[^>]*>").Replace(clean, " ")
        clean = HttpUtility.HtmlDecode(clean)
        clean = New String(clean.Where(Function(c) Not Char.IsControl(c) OrElse Char.IsWhiteSpace(c)).ToArray())
        Return Rx("\s+").Replace(clean, " ").Trim().Normalize(NormalizationForm.FormC)
    End Function

    Private Shared Function NormalizeLabel(ByVal value As String) As String
        Return Rx("\s+").Replace(If(value, String.Empty), " ").Trim().Normalize(NormalizationForm.FormC).ToLowerInvariant()
    End Function

    Private Shared Function Family(ByVal row As DataRow) As String
        Return String.Join("/", {"SettoriId", "CategorieId", "TipologieId", "GruppiId", "SottoGruppiId"}.Select(Function(field) IntegerField(row, field, 0).ToString(CultureInfo.InvariantCulture)))
    End Function

    Private Shared Function IntegerField(ByVal row As DataRow, ByVal field As String, ByVal fallback As Integer) As Integer
        Dim value As Integer
        If row.Table.Columns.Contains(field) AndAlso Not row.IsNull(field) AndAlso Integer.TryParse(Convert.ToString(row(field), CultureInfo.InvariantCulture), NumberStyles.Integer, CultureInfo.InvariantCulture, value) Then Return value
        Return fallback
    End Function

    Private Shared Function StringField(ByVal row As DataRow, ByVal field As String) As String
        If Not row.Table.Columns.Contains(field) OrElse row.IsNull(field) Then Return String.Empty
        Return Convert.ToString(row(field), CultureInfo.InvariantCulture)
    End Function

    Private Shared Function EvidenceReference(ByVal product As ShoppingProductFacts, ByVal field As String, ByVal value As String) As String
        Return "e_" & Hash(product.ProductKey & "|" & field & "|" & value).Substring(0, 24)
    End Function

    Private Shared Function Hash(ByVal value As String) As String
        Using algorithm As SHA256 = SHA256.Create()
            Return BitConverter.ToString(algorithm.ComputeHash(Encoding.UTF8.GetBytes(value))).Replace("-", String.Empty).ToLowerInvariant()
        End Using
    End Function

    Private Shared Function Clip(ByVal value As String, ByVal length As Integer) As String
        Return If(value.Length <= length, value, value.Substring(0, length))
    End Function

    Private Shared Function Rx(ByVal pattern As String) As Regex
        Return New Regex(pattern, RegexOptions.IgnoreCase Or RegexOptions.Singleline Or RegexOptions.CultureInvariant, RegexBudget)
    End Function
End Class
