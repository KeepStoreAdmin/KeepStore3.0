Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Linq
Imports System.Text.RegularExpressions
Imports System.Web.Script.Serialization

Public NotInheritable Class ShoppingCriterion
    Public Property AttributeId As String
    Public Property [Operator] As String
    Public Property Value As String
    Public Property Priority As String
End Class

Public NotInheritable Class ShoppingCriterionEvaluation
    Public Property AttributeId As String
    Public Property Priority As String
    Public Property Status As String
    Public Property EvidenceRef As String
End Class

Public NotInheritable Class ShoppingProductDecision
    Public Property ProductKey As String
    Public Property Facts As ShoppingProductFacts
    Public Property Evaluations As New List(Of ShoppingCriterionEvaluation)
    Public Property SoftScore As Integer
    Public Property Match As String
    Public Property SourceOrder As Integer
End Class

Public NotInheritable Class ShoppingDecisionResult
    Public Property Products As New List(Of ShoppingProductDecision)
    Public Property Question As Dictionary(Of String, Object)
    Public Property Actions As New List(Of Dictionary(Of String, Object))
End Class

' Pure, request-local decision layer. It never queries or constructs an offer.
Public NotInheritable Class KeepStoreShoppingDecisionPolicy
    Public Const PolicyVersion As String = "advisor-decision-1c.1"
    Public Const MaxCriteria As Integer = 8
    Public Const MaxSkipped As Integer = 24
    Public Const MaxCriteriaJsonChars As Integer = 4096
    Private Sub New()
    End Sub

    Public Shared Function ParseCriteria(raw As String) As List(Of ShoppingCriterion)
        Dim reader As New BoundedJson(If(raw, "[]"), MaxCriteriaJsonChars)
        Dim entries As List(Of Dictionary(Of String, String)) = reader.ReadObjects(MaxCriteria)
        Dim result As New List(Of ShoppingCriterion)
        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)
        For Each entry As Dictionary(Of String, String) In entries
            If entry.Count <> 4 OrElse Not entry.ContainsKey("attributeId") OrElse Not entry.ContainsKey("operator") OrElse
                Not entry.ContainsKey("value") OrElse Not entry.ContainsKey("priority") Then Invalid()
            Dim criterion As New ShoppingCriterion With {.AttributeId = entry("attributeId"), .Operator = entry("operator"), .Value = entry("value"), .Priority = entry("priority")}
            If Not ValidId(criterion.AttributeId) OrElse Not seen.Add(criterion.AttributeId) OrElse
                Not {"eq", "gte", "lte"}.Contains(criterion.Operator, StringComparer.Ordinal) OrElse
                Not {"hard", "soft"}.Contains(criterion.Priority, StringComparer.Ordinal) OrElse
                criterion.Value.Length = 0 OrElse criterion.Value.Length > 120 OrElse criterion.Value.Any(Function(c) Char.IsControl(c)) Then Invalid()
            result.Add(criterion)
        Next
        Return result
    End Function

    Public Shared Function ParseSkipped(raw As String) As HashSet(Of String)
        Dim reader As New BoundedJson(If(raw, "[]"), 2048)
        Dim values As List(Of String) = reader.ReadStrings(MaxSkipped)
        Dim result As New HashSet(Of String)(StringComparer.Ordinal)
        For Each value As String In values
            If Not ValidId(value) OrElse Not result.Add(value) Then Invalid()
        Next
        Return result
    End Function

    Private Shared Function ValidId(value As String) As Boolean
        Return value IsNot Nothing AndAlso Regex.IsMatch(value, "^a_[a-f0-9]{24}$", RegexOptions.CultureInvariant)
    End Function

    Private Shared Sub Invalid()
        Throw New ArgumentException("invalid_criteria")
    End Sub

    Public Shared Function Decide(corpus As ShoppingKnowledgeCorpus, criteria As IList(Of ShoppingCriterion),
                                  skipped As ISet(Of String), explicitSort As Boolean,
                                  exactProductKeys As ISet(Of String)) As ShoppingDecisionResult
        If corpus Is Nothing OrElse criteria Is Nothing OrElse criteria.Count > MaxCriteria OrElse corpus.Products.Count > 96 Then Invalid()
        Dim definitions As New Dictionary(Of String, ShoppingAttributeDefinition)(StringComparer.Ordinal)
        For Each definition As ShoppingAttributeDefinition In corpus.Attributes
            definitions.Add(definition.Id, definition)
        Next
        Dim seen As New HashSet(Of String)(StringComparer.Ordinal)
        For Each criterion As ShoppingCriterion In criteria
            Dim definition As ShoppingAttributeDefinition = Nothing
            If criterion Is Nothing OrElse Not seen.Add(criterion.AttributeId) OrElse Not definitions.TryGetValue(criterion.AttributeId, definition) Then Invalid()
            ValidateCriterion(criterion, definition)
        Next
        ' A valid skipped ID from a preceding pool may disappear after a filter.
        ' It grants no fact/filter authority and must not make recovery impossible.
        If skipped Is Nothing Then skipped = New HashSet(Of String)(StringComparer.Ordinal)
        If skipped.Count > MaxSkipped Then Invalid()
        For Each value As String In skipped
            If Not ValidId(value) Then Invalid()
        Next

        Dim result As New ShoppingDecisionResult()
        Dim rejected As New List(Of ShoppingProductDecision)
        For index As Integer = 0 To corpus.Products.Count - 1
            Dim facts As ShoppingProductFacts = corpus.Products(index)
            Dim candidate As New ShoppingProductDecision With {.ProductKey = facts.ProductKey, .Facts = facts, .SourceOrder = index}
            Dim admissible As Boolean = True
            Dim complete As Boolean = True
            For Each criterion As ShoppingCriterion In criteria
                Dim value As ShoppingAttributeValue = Nothing
                facts.Values.TryGetValue(criterion.AttributeId, value)
                Dim status As String = Evaluate(definitions(criterion.AttributeId), value, criterion)
                candidate.Evaluations.Add(New ShoppingCriterionEvaluation With {
                    .AttributeId = criterion.AttributeId, .Priority = criterion.Priority, .Status = status,
                    .EvidenceRef = If(value Is Nothing OrElse value.EvidenceStatus <> "known", String.Empty, value.EvidenceRef)})
                If status <> "SATISFIED" Then complete = False
                If criterion.Priority = "hard" AndAlso status <> "SATISFIED" Then admissible = False
                ' Equal user-confirmed soft weights; UNKNOWN receives no credit.
                If criterion.Priority = "soft" AndAlso status = "SATISFIED" Then candidate.SoftScore += 100
            Next
            candidate.Match = If(criteria.Count = 0, "unconstrained", If(complete, "complete", "partial"))
            If admissible Then
                result.Products.Add(candidate)
            Else
                rejected.Add(candidate)
            End If
        Next
        ' Explicit order remains authoritative; otherwise exact code/EAN first,
        ' equal soft weights second, original SQL relevance/order as final tie.
        If Not explicitSort Then
            result.Products = result.Products.OrderByDescending(Function(p) exactProductKeys IsNot Nothing AndAlso exactProductKeys.Contains(p.ProductKey)).
                ThenByDescending(Function(p) p.SoftScore).ThenBy(Function(p) p.SourceOrder).ToList()
        End If
        If criteria.Count < MaxCriteria AndAlso skipped.Count < MaxSkipped Then result.Question = SelectQuestion(corpus, result.Products, seen, skipped)
        If result.Products.Count = 0 Then result.Actions = Relaxations(rejected, definitions)
        Return result
    End Function

    Private Shared Sub ValidateCriterion(criterion As ShoppingCriterion, definition As ShoppingAttributeDefinition)
        If definition.Risk <> "low" OrElse (Not definition.CanAsk AndAlso Not definition.CanHardFilter) Then Invalid()
        If criterion.Priority <> "hard" AndAlso criterion.Priority <> "soft" Then Invalid()
        If criterion.Value Is Nothing OrElse criterion.Value.Length = 0 OrElse criterion.Value.Length > 120 OrElse
            Not definition.Operators.Contains(criterion.Operator, StringComparer.Ordinal) Then Invalid()
        If criterion.Priority = "hard" AndAlso Not definition.CanHardFilter Then Invalid()
        If definition.Type = "number" Then
            Dim number As Decimal
            If Not Regex.IsMatch(criterion.Value, "^[0-9]+(?:\.[0-9]+)?$", RegexOptions.CultureInvariant) OrElse
                Not Decimal.TryParse(criterion.Value, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, number) Then Invalid()
        ElseIf definition.Type = "boolean" Then
            If criterion.Value <> "true" AndAlso criterion.Value <> "false" Then Invalid()
        ElseIf definition.Type = "text" Then
            If Not definition.ObservedValues.Contains(criterion.Value, StringComparer.Ordinal) Then Invalid()
        Else
            Invalid()
        End If
    End Sub

    Public Shared Function Evaluate(definition As ShoppingAttributeDefinition, value As ShoppingAttributeValue, criterion As ShoppingCriterion) As String
        If value Is Nothing OrElse value.EvidenceStatus <> "known" Then Return "UNKNOWN"
        Dim satisfied As Boolean
        If definition.Type = "number" Then
            If Not value.NumericValue.HasValue Then Return "UNKNOWN"
            Dim expected As Decimal
            If Not Decimal.TryParse(criterion.Value, NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, expected) Then Return "UNKNOWN"
            Select Case criterion.Operator
                Case "eq" : satisfied = value.NumericValue.Value = expected
                Case "gte" : satisfied = value.NumericValue.Value >= expected
                Case "lte" : satisfied = value.NumericValue.Value <= expected
                Case Else : Return "UNKNOWN"
            End Select
        Else
            If criterion.Operator <> "eq" Then Return "UNKNOWN"
            satisfied = String.Equals(value.Value, criterion.Value, StringComparison.Ordinal)
        End If
        Return If(satisfied, "SATISFIED", "VIOLATED")
    End Function

    Private Shared Function SelectQuestion(corpus As ShoppingKnowledgeCorpus, candidates As IList(Of ShoppingProductDecision),
                                           answered As ISet(Of String), skipped As ISet(Of String)) As Dictionary(Of String, Object)
        If candidates.Count < 2 Then Return Nothing
        Dim best As ShoppingAttributeDefinition = Nothing
        Dim bestScore As Double = -1
        Dim bestCounts As SortedDictionary(Of String, Integer) = Nothing
        For Each definition As ShoppingAttributeDefinition In corpus.Attributes.OrderBy(Function(a) a.Id, StringComparer.Ordinal)
            If Not definition.CanAsk OrElse definition.Risk <> "low" OrElse answered.Contains(definition.Id) OrElse skipped.Contains(definition.Id) Then Continue For
            Dim counts As New SortedDictionary(Of String, Integer)(StringComparer.Ordinal)
            Dim known As Integer = 0
            For Each candidate As ShoppingProductDecision In candidates
                Dim value As ShoppingAttributeValue = Nothing
                If Not candidate.Facts.Values.TryGetValue(definition.Id, value) OrElse value.EvidenceStatus <> "known" Then Continue For
                known += 1
                If Not counts.ContainsKey(value.Value) Then counts.Add(value.Value, 0)
                counts(value.Value) += 1
            Next
            ' Exact equality partitions are mutually exclusive, including numbers.
            ' No arbitrary numeric buckets or automatically selected thresholds.
            If counts.Count < 2 OrElse counts.Count > 6 OrElse known < 2 Then Continue For
            Dim coverage As Double = CDbl(known) / candidates.Count
            If coverage < 0.5R Then Continue For
            Dim discrimination As Double = 1.0R - counts.Values.Sum(Function(n) Math.Pow(CDbl(n) / known, 2))
            ' Coverage and confidence stay separate from D. A per-option reading
            ' cost suppresses high-cardinality bias; identifiers are never canAsk.
            Dim score As Double = coverage * discrimination / (1.0R + 0.25R * (counts.Count - 2))
            If score > bestScore Then
                best = definition : bestScore = score : bestCounts = counts
            End If
        Next
        If best Is Nothing Then Return Nothing
        Dim options As New List(Of Dictionary(Of String, Object))
        For Each value As String In bestCounts.Keys
            Dim label As String = If(best.Type = "boolean", If(value = "true", "Sì", "No"), value & If(String.IsNullOrEmpty(best.Unit), String.Empty, " " & best.Unit))
            options.Add(New Dictionary(Of String, Object) From {{"value", value}, {"label", label}})
        Next
        Return New Dictionary(Of String, Object) From {
            {"id", "q_" & best.Id}, {"attributeId", best.Id}, {"label", "Hai una preferenza per " & best.Label & "?"},
            {"operator", "eq"}, {"options", options}, {"allowSkip", True}, {"allowIndifferent", True}, {"allowUnknown", True},
            {"reason", "Valori documentati e differenti nella selezione; la risposta è facoltativa."}}
    End Function

    Private Shared Function Relaxations(rejected As IList(Of ShoppingProductDecision), definitions As IDictionary(Of String, ShoppingAttributeDefinition)) As List(Of Dictionary(Of String, Object))
        Dim sets As New SortedDictionary(Of String, List(Of String))(StringComparer.Ordinal)
        Dim minimum As Integer = MaxCriteria + 1
        For Each candidate As ShoppingProductDecision In rejected
            Dim failed As List(Of String) = candidate.Evaluations.Where(Function(e) e.Priority = "hard" AndAlso e.Status <> "SATISFIED").
                Select(Function(e) e.AttributeId).OrderBy(Function(id) id, StringComparer.Ordinal).ToList()
            If failed.Count = 0 OrElse failed.Count > minimum OrElse failed.Any(Function(id) definitions(id).Risk <> "low") Then Continue For
            If failed.Count < minimum Then sets.Clear() : minimum = failed.Count
            Dim key As String = String.Join("|", failed.ToArray())
            If Not sets.ContainsKey(key) Then sets.Add(key, failed)
        Next
        Dim result As New List(Of Dictionary(Of String, Object))
        For Each entry As KeyValuePair(Of String, List(Of String)) In sets.Take(3)
            result.Add(New Dictionary(Of String, Object) From {
                {"id", "relax_" & (result.Count + 1).ToString(CultureInfo.InvariantCulture)}, {"kind", "relax"},
                {"label", "Rimuovi il requisito: " & String.Join(", ", entry.Value.Select(Function(id) definitions(id).Label).ToArray())},
                {"attributeIds", entry.Value}, {"requiresConfirmation", True},
                {"reason", "Minimo numero di requisiti modificabili da rimuovere nella selezione analizzata; richiede conferma."}})
        Next
        Return result
    End Function

    ' Narrow JSON reader: arrays and flat objects of strings only. It rejects
    ' duplicate properties rather than accepting the serializer's last value.
    Private NotInheritable Class BoundedJson
        Private ReadOnly _text As String
        Private _position As Integer
        Public Sub New(raw As String, maximum As Integer)
            If raw.Length > maximum Then Invalid()
            _text = raw
        End Sub
        Public Function ReadObjects(maximum As Integer) As List(Of Dictionary(Of String, String))
            Dim result As New List(Of Dictionary(Of String, String))
            Expect("["c)
            If Not Take("]"c) Then
                Do
                    If result.Count >= maximum Then Invalid()
                    Expect("{"c)
                    Dim entry As New Dictionary(Of String, String)(StringComparer.Ordinal)
                    If Not Take("}"c) Then
                        Do
                            Dim key As String = ReadString()
                            Expect(":"c)
                            Dim value As String = ReadString()
                            If entry.Count >= 4 OrElse entry.ContainsKey(key) Then Invalid()
                            entry.Add(key, value)
                            If Take("}"c) Then Exit Do
                            Expect(","c)
                        Loop
                    End If
                    result.Add(entry)
                    If Take("]"c) Then Exit Do
                    Expect(","c)
                Loop
            End If
            Finish()
            Return result
        End Function
        Public Function ReadStrings(maximum As Integer) As List(Of String)
            Dim result As New List(Of String)
            Expect("["c)
            If Not Take("]"c) Then
                Do
                    If result.Count >= maximum Then Invalid()
                    result.Add(ReadString())
                    If Take("]"c) Then Exit Do
                    Expect(","c)
                Loop
            End If
            Finish()
            Return result
        End Function
        Private Function ReadString() As String
            SkipWhite()
            Dim start As Integer = _position
            Expect(""""c)
            Do While _position < _text.Length
                Dim c As Char = _text(_position)
                _position += 1
                If c = "\"c Then
                    _position += 1
                ElseIf c = """"c Then
                    Try
                        Return New JavaScriptSerializer().Deserialize(Of String)(_text.Substring(start, _position - start))
                    Catch ex As ArgumentException
                        Invalid()
                    End Try
                ElseIf Char.IsControl(c) Then
                    Invalid()
                End If
            Loop
            Invalid()
            Return Nothing
        End Function
        Private Sub SkipWhite()
            Do While _position < _text.Length AndAlso (_text(_position) = " "c OrElse _text(_position) = ChrW(9) OrElse _text(_position) = ChrW(10) OrElse _text(_position) = ChrW(13))
                _position += 1
            Loop
        End Sub
        Private Function Take(c As Char) As Boolean
            SkipWhite()
            If _position < _text.Length AndAlso _text(_position) = c Then
                _position += 1 : Return True
            End If
            Return False
        End Function
        Private Sub Expect(c As Char)
            If Not Take(c) Then Invalid()
        End Sub
        Private Sub Finish()
            SkipWhite()
            If _position <> _text.Length Then Invalid()
        End Sub
    End Class
End Class
