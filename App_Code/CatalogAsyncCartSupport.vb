Imports System
Imports System.Collections.Generic
Imports System.Globalization
Imports System.Security.Cryptography
Imports System.Web
Imports System.Web.SessionState

Public NotInheritable Class CatalogAsyncCartExecutionResult
    Public Property IsComplete As Boolean
    Public Property Success As Boolean
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property ProductName As String
End Class

Public NotInheritable Class CatalogAsyncCartSupport
    Private Const CsrfSessionKey As String = "KeepStore:CatalogAsyncCart:Csrf"
    Private Const ProcessedSessionKey As String = "KeepStore:CatalogAsyncCart:Processed"
    Private Const ExecutionContextKey As String = "KeepStore:CatalogAsyncCart:Execution"
    Private Const MaxProcessedRequests As Integer = 64

    Private Sub New()
    End Sub

    Public Shared Function GetOrCreateCsrfToken(ByVal context As HttpContext) As String
        If context Is Nothing OrElse context.Session Is Nothing Then Return String.Empty

        Dim current As String = Convert.ToString(context.Session(CsrfSessionKey))
        If Not String.IsNullOrWhiteSpace(current) Then Return current

        Dim tokenBytes(31) As Byte
        Using generator As RandomNumberGenerator = RandomNumberGenerator.Create()
            generator.GetBytes(tokenBytes)
        End Using

        current = Convert.ToBase64String(tokenBytes)
        context.Session(CsrfSessionKey) = current
        Return current
    End Function

    Public Shared Function ValidateCsrfToken(ByVal context As HttpContext, ByVal suppliedToken As String) As Boolean
        If context Is Nothing OrElse context.Session Is Nothing Then Return False

        Dim expected As String = Convert.ToString(context.Session(CsrfSessionKey))
        Return FixedTimeEquals(expected, Convert.ToString(suppliedToken))
    End Function

    Public Shared Function BuildFingerprint(ByVal articleId As Integer,
                                            ByVal tcId As Integer,
                                            ByVal quantity As Decimal,
                                            ByVal freeProduct As Integer) As String
        Return articleId.ToString(CultureInfo.InvariantCulture) & ":" &
               NormalizeTCId(tcId).ToString(CultureInfo.InvariantCulture) & ":" &
               quantity.ToString("0.####", CultureInfo.InvariantCulture) & ":" &
               freeProduct.ToString(CultureInfo.InvariantCulture)
    End Function

    Public Shared Function TryGetProcessedFingerprint(ByVal session As HttpSessionState,
                                                       ByVal requestId As String,
                                                       ByRef fingerprint As String) As Boolean
        fingerprint = String.Empty
        If session Is Nothing OrElse String.IsNullOrWhiteSpace(requestId) Then Return False

        Dim processed As Dictionary(Of String, String) = GetProcessedRequests(session, False)
        If processed Is Nothing Then Return False

        Dim stored As String = Nothing
        If Not processed.TryGetValue(requestId, stored) OrElse String.IsNullOrEmpty(stored) Then Return False

        Dim separator As Integer = stored.LastIndexOf("|"c)
        fingerprint = If(separator > 0, stored.Substring(0, separator), stored)
        Return True
    End Function

    Public Shared Sub MarkProcessed(ByVal session As HttpSessionState,
                                    ByVal requestId As String,
                                    ByVal fingerprint As String)
        If session Is Nothing OrElse String.IsNullOrWhiteSpace(requestId) OrElse String.IsNullOrWhiteSpace(fingerprint) Then Return

        Dim processed As Dictionary(Of String, String) = GetProcessedRequests(session, True)
        If processed.Count >= MaxProcessedRequests Then
            Dim removeCount As Integer = processed.Count - (MaxProcessedRequests \ 2)
            Dim oldKeys As New List(Of String)(processed.Keys)
            For index As Integer = 0 To Math.Min(removeCount, oldKeys.Count) - 1
                processed.Remove(oldKeys(index))
            Next
        End If

        processed(requestId) = fingerprint & "|" & DateTime.UtcNow.Ticks.ToString(CultureInfo.InvariantCulture)
        session(ProcessedSessionKey) = processed
    End Sub

    Public Shared Sub BeginExecution(ByVal context As HttpContext, ByVal articleId As Integer, ByVal tcId As Integer)
        If context Is Nothing Then Return
        context.Items(ExecutionContextKey) = New CatalogAsyncCartExecutionResult With {
            .ArticleId = articleId,
            .TCId = NormalizeTCId(tcId)
        }
    End Sub

    Public Shared Function IsExecutionActive(ByVal context As HttpContext) As Boolean
        Return context IsNot Nothing AndAlso TypeOf context.Items(ExecutionContextKey) Is CatalogAsyncCartExecutionResult
    End Function

    Public Shared Sub CompleteExecution(ByVal context As HttpContext,
                                        ByVal success As Boolean,
                                        ByVal articleId As Integer,
                                        ByVal tcId As Integer,
                                        ByVal productName As String)
        If context Is Nothing Then Return

        Dim result As CatalogAsyncCartExecutionResult = TryCast(context.Items(ExecutionContextKey), CatalogAsyncCartExecutionResult)
        If result Is Nothing Then Return

        result.IsComplete = True
        result.Success = success
        result.ArticleId = articleId
        result.TCId = NormalizeTCId(tcId)
        result.ProductName = Convert.ToString(productName).Trim()
    End Sub

    Public Shared Function GetExecutionResult(ByVal context As HttpContext) As CatalogAsyncCartExecutionResult
        If context Is Nothing Then Return Nothing
        Return TryCast(context.Items(ExecutionContextKey), CatalogAsyncCartExecutionResult)
    End Function

    Public Shared Sub EndExecution(ByVal context As HttpContext)
        If context IsNot Nothing Then context.Items.Remove(ExecutionContextKey)
    End Sub

    Public Shared Function NormalizeTCId(ByVal tcId As Integer) As Integer
        Return If(tcId > 0, tcId, -1)
    End Function

    Private Shared Function GetProcessedRequests(ByVal session As HttpSessionState,
                                                  ByVal createIfMissing As Boolean) As Dictionary(Of String, String)
        Dim processed As Dictionary(Of String, String) = TryCast(session(ProcessedSessionKey), Dictionary(Of String, String))
        If processed Is Nothing AndAlso createIfMissing Then
            processed = New Dictionary(Of String, String)(StringComparer.Ordinal)
            session(ProcessedSessionKey) = processed
        End If
        Return processed
    End Function

    Private Shared Function FixedTimeEquals(ByVal expected As String, ByVal supplied As String) As Boolean
        If String.IsNullOrEmpty(expected) OrElse String.IsNullOrEmpty(supplied) Then Return False

        Dim difference As Integer = expected.Length Xor supplied.Length
        Dim maxLength As Integer = Math.Max(expected.Length, supplied.Length)
        For index As Integer = 0 To maxLength - 1
            Dim expectedChar As Integer = If(index < expected.Length, AscW(expected(index)), 0)
            Dim suppliedChar As Integer = If(index < supplied.Length, AscW(supplied(index)), 0)
            difference = difference Or (expectedChar Xor suppliedChar)
        Next
        Return difference = 0
    End Function
End Class
