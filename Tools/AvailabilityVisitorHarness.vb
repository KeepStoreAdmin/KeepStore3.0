Option Strict On
Option Explicit On

Imports System
Imports System.IO
Imports System.Web
Imports System.Web.SessionState

' Harness del task KS-A03-PDP-HIERARCHY-1A: compilato con AvailabilityDisplayHelper REALE e i suoi contratti
' (CartStorefrontScopePolicy, StorefrontCommercialIsolationPolicy). Sessioni finte nel contesto HTTP.
Module AvailabilityVisitorHarness
    Private _failures As Integer

    Private Sub Check(ByVal condition As Boolean, ByVal code As String)
        If condition Then
            Console.WriteLine("PASS " & code)
        Else
            _failures += 1
            Console.WriteLine("FAIL " & code)
        End If
    End Sub

    Private Function NewContext(ByVal dispoTipo As Object,
                                ByVal loginId As Object,
                                ByVal companyId As Object,
                                ByVal authenticatedCompanyId As Object) As HttpContext
        Dim context As New HttpContext(New HttpRequest("", "http://localhost/", ""), New HttpResponse(New StringWriter()))
        Dim container As New HttpSessionStateContainer("synthetic", New SessionStateItemCollection(),
            New HttpStaticObjectsCollection(), 20, True, HttpCookieMode.UseCookies, SessionStateMode.InProc, False)
        SessionStateUtility.AddHttpSessionStateToContext(context, container)
        If dispoTipo IsNot Nothing Then context.Session("DispoTipo") = dispoTipo
        If loginId IsNot Nothing Then context.Session("LoginId") = loginId
        If companyId IsNot Nothing Then context.Session("AziendaID") = companyId
        If authenticatedCompanyId IsNot Nothing Then context.Session("AuthenticatedAziendaID") = authenticatedCompanyId
        Return context
    End Function

    Function Main() As Integer
        ' Tenant in modalita numerica (2)
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(2, Nothing, 1, Nothing)) = 1, "01_GUEST_GETS_WORDS_EVEN_IF_TENANT_IS_NUMERIC")
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(2, 7, 1, 1)) = 2, "02_AUTHENTICATED_GETS_NUMBERS")
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(2, 7, 1, 2)) = 1, "03_OTHER_STOREFRONT_LOGIN_IS_GUEST")
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(2, 7, 0, 0)) = 1, "04_ZERO_COMPANIES_IS_GUEST")
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(2, 7, 1, Nothing)) = 1, "05_LOGIN_WITHOUT_AUTHENTICATED_COMPANY_IS_GUEST")
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(2, 0, 1, 1)) = 1, "06_LOGIN_ZERO_IS_GUEST")
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(2, "abc", 1, 1)) = 1, "07_INVALID_LOGIN_VALUE_IS_GUEST")
        ' Tenant in modalita a parole (1 o assente): nessuno vede i numeri
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(1, 7, 1, 1)) = 1, "08_TENANT_WORDS_MODE_STAYS_WORDS_FOR_AUTHENTICATED")
        Check(AvailabilityDisplayHelper.GetDisplayMode(NewContext(Nothing, 7, 1, 1)) = 1, "09_MISSING_TENANT_MODE_STAYS_WORDS")
        ' Nessun contesto o nessuna sessione
        Check(AvailabilityDisplayHelper.GetDisplayMode(Nothing) = 1 AndAlso Not AvailabilityDisplayHelper.IsAuthenticatedVisitor(Nothing), "10_NO_CONTEXT_IS_GUEST")

        ' HTML effettivo con la stessa riga: l'ospite non riceve numeri ne nell'HTML ne nell'aria-label
        Dim row As New System.Data.DataTable()
        row.Columns.Add("Giacenza", GetType(Decimal)) : row.Columns.Add("Impegnata", GetType(Decimal))
        row.Columns.Add("InOrdine", GetType(Decimal)) : row.Columns.Add("Disponibilita", GetType(Decimal))
        row.Columns.Add("ScortaMinima", GetType(Decimal))
        Dim dr As System.Data.DataRow = row.NewRow()
        dr("Giacenza") = 453D : dr("Impegnata") = 7D : dr("InOrdine") = 3D : dr("Disponibilita") = 446D : dr("ScortaMinima") = 0D
        row.Rows.Add(dr)
        Dim guestHtml As String = AvailabilityDisplayHelper.BuildHtml(dr, NewContext(2, Nothing, 1, Nothing))
        Check(guestHtml.IndexOf("Impegnati", StringComparison.Ordinal) < 0 AndAlso guestHtml.IndexOf("446", StringComparison.Ordinal) < 0 AndAlso guestHtml.IndexOf("453", StringComparison.Ordinal) < 0 AndAlso guestHtml.Contains("Disponibile"), "11_GUEST_HTML_HAS_WORD_AND_NO_QUANTITIES")
        Dim authHtml As String = AvailabilityDisplayHelper.BuildHtml(dr, NewContext(2, 7, 1, 1))
        Check(authHtml.Contains("Impegnati") AndAlso authHtml.Contains("446"), "12_AUTHENTICATED_HTML_HAS_NUMBERS")

        Console.WriteLine("FAILURES=" & _failures.ToString())
        Return If(_failures = 0, 0, 1)
    End Function
End Module
