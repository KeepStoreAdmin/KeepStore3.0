Imports System
Imports System.Security.Cryptography
Imports System.Web

Public NotInheritable Class CatalogAsyncCartExecutionResult
    Public Property IsComplete As Boolean
    Public Property Success As Boolean
    Public Property ArticleId As Integer
    Public Property TCId As Integer
    Public Property ProductName As String
End Class

Public NotInheritable Class CatalogAsyncCartSupport
    Private Const CsrfSessionKey As String = "KeepStore:CatalogAsyncCart:Csrf"
    Private Const ExecutionContextKey As String = "KeepStore:CatalogAsyncCart:Execution"

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
