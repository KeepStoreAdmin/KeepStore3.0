Imports System
Imports System.Web

Public Enum CheckoutTerminalOutcome
    CartReview = 0
    StockFailure = 1
    LoginRequired = 2
    PriceChanged = 3
    AddressError = 4
    NotesError = 5
    OrderConfirmation = 6
    CheckoutFailure = 7
End Enum

''' <summary>
''' Owns the final HTTP destination for checkout outcomes. The first outcome
''' wins for the request; later callers cannot replace its Location header.
''' Every caller must return immediately after dispatching.
''' </summary>
Public NotInheritable Class CheckoutTerminalOutcomeDispatcher
    Private Const OutcomeItemKey As String = "KeepStore:CheckoutTerminalOutcome"

    Private Sub New()
    End Sub

    Public Shared Function Dispatch(ByVal context As HttpContext,
                                    ByVal outcome As CheckoutTerminalOutcome,
                                    Optional ByVal opaqueConfirmationToken As String = "") As Boolean
        If context Is Nothing OrElse context.Response Is Nothing Then Return False
        If context.Items(OutcomeItemKey) IsNot Nothing Then Return False

        Dim target As String = ResolveTarget(outcome, opaqueConfirmationToken)
        context.Items(OutcomeItemKey) = outcome.ToString()

        Dim response As HttpResponse = context.Response
        response.Clear()
        response.StatusCode = 303
        response.StatusDescription = "See Other"
        response.TrySkipIisCustomErrors = True
        response.RedirectLocation = target
        response.Headers("Location") = target
        response.SuppressContent = True
        context.ApplicationInstance.CompleteRequest()
        Return True
    End Function

    Public Shared Function HasDispatched(ByVal context As HttpContext) As Boolean
        Return context IsNot Nothing AndAlso context.Items(OutcomeItemKey) IsNot Nothing
    End Function

    Private Shared Function ResolveTarget(ByVal outcome As CheckoutTerminalOutcome,
                                          ByVal opaqueConfirmationToken As String) As String
        Select Case outcome
            Case CheckoutTerminalOutcome.StockFailure
                Return "carrello.aspx?stockerror=1#ksCartStockError"
            Case CheckoutTerminalOutcome.LoginRequired
                Return "carrello.aspx?loginrequired=1#ksCartLoginRequired"
            Case CheckoutTerminalOutcome.PriceChanged
                Return "carrello.aspx?pricechanged=1"
            Case CheckoutTerminalOutcome.AddressError
                Return "carrello.aspx?addresserror=1"
            Case CheckoutTerminalOutcome.NotesError
                Return "carrello.aspx?noteerror=1"
            Case CheckoutTerminalOutcome.OrderConfirmation
                If String.IsNullOrWhiteSpace(opaqueConfirmationToken) Then
                    Throw New ArgumentException("Confirmation token is required.", "opaqueConfirmationToken")
                End If
                Return "ordine.aspx?c=" & HttpUtility.UrlEncode(opaqueConfirmationToken)
            Case CheckoutTerminalOutcome.CheckoutFailure
                Return "carrello.aspx?checkoutfailed=1#pnlCheckoutSubmitError"
            Case Else
                Return "carrello.aspx"
        End Select
    End Function
End Class
