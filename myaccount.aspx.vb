Partial Class myaccount
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        SessionDiagnostics.Write("myaccount-load", Me, "phase=start")
        If Me.Session("LoginId") Is Nothing Then
            SessionDiagnostics.Write("myaccount-missing-login-session", Me, "redirect=accessonegato")
            Me.Session("Page") = Me.Request.Url.ToString()
            Me.Response.Redirect("accessonegato.aspx", True)
        End If
        SessionDiagnostics.Write("myaccount-authorized", Me, "phase=authorized")
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.Title = Me.Title & " - Area personale"
    End Sub

    Protected Sub gvRecentOrders_PreRender(ByVal sender As Object, ByVal e As System.EventArgs)
        If gvRecentOrders.Rows.Count > 0 Then
            gvRecentOrders.UseAccessibleHeader = True
            If gvRecentOrders.HeaderRow IsNot Nothing Then
                gvRecentOrders.HeaderRow.TableSection = System.Web.UI.WebControls.TableRowSection.TableHeader
            End If
        End If
    End Sub

    Protected Function GetDashboardGreeting(ByVal ragioneSocialeObj As Object,
                                            ByVal cognomeNomeObj As Object,
                                            ByVal usernameObj As Object) As String
        Dim displayName As String = SafeStatusText(FirstValue(ragioneSocialeObj, cognomeNomeObj, usernameObj))
        If displayName = "" Then Return "Benvenuto nella tua area personale"
        Return "Ciao, " & displayName
    End Function

    Protected Function FirstValue(ParamArray values() As Object) As Object
        If values Is Nothing Then Return Nothing

        For Each value As Object In values
            Dim text As String = SafeStatusText(value)
            If text <> "" Then Return text
        Next

        Return Nothing
    End Function

    Protected Function SafeAccountText(ByVal value As Object, ByVal fallback As String) As String
        Dim text As String = SafeStatusText(value)
        If text = "" Then Return fallback
        Return text
    End Function

    Protected Function FormatCityLine(ByVal capObj As Object,
                                      ByVal cittaObj As Object,
                                      ByVal provinciaObj As Object) As String
        Dim cap As String = SafeStatusText(capObj)
        Dim citta As String = SafeStatusText(cittaObj)
        Dim provincia As String = SafeStatusText(provinciaObj)
        Dim text As String = (cap & " " & citta).Trim()

        If provincia <> "" Then
            text = (text & " (" & provincia & ")").Trim()
        End If

        If text = "" Then Return "Localita non specificata"
        Return text
    End Function

    Protected Function FormatOrderStatus(ByVal stato1Obj As Object, ByVal stato2Obj As Object) As String
        Dim stato1 As String = SafeStatusText(stato1Obj)
        Dim stato2 As String = SafeStatusText(stato2Obj)

        If stato1 = "" Then Return If(stato2 = "", "Non disponibile", stato2)
        If stato2 = "" Then Return stato1
        Return (stato1 & " " & stato2).Trim()
    End Function

    Protected Function GetPaymentStatusLabel(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)

        If pagato = 1 OrElse stato = 2 Then Return "Pagato"

        Select Case stato
            Case 1
                Return "In verifica PayPal"
            Case 3
                Return "Non completato"
            Case 4
                Return "Annullato dall'utente"
            Case 5
                Return "In verifica"
            Case Else
                Return "Non avviato"
        End Select
    End Function

    Protected Function GetPaymentStatusCssClass(ByVal pagatoObj As Object, ByVal statoObj As Object) As String
        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)
        Dim baseClass As String = "ks-status-badge "

        If pagato = 1 OrElse stato = 2 Then Return baseClass & "is-success"

        Select Case stato
            Case 1, 5
                Return baseClass & "is-warning"
            Case 3
                Return baseClass & "is-danger"
            Case 4
                Return baseClass & "is-canceled"
            Case Else
                Return baseClass & "is-muted"
        End Select
    End Function

    Protected Function GetPaymentStatusDescription(ByVal pagatoObj As Object,
                                                   ByVal statoObj As Object,
                                                   ByVal esitoObj As Object,
                                                   ByVal pagamentoObj As Object) As String
        Dim esito As String = SafePaymentMessage(esitoObj)
        If esito <> "" Then Return esito

        Dim pagato As Integer = SafeInt(pagatoObj, 0)
        Dim stato As Integer = SafeInt(statoObj, 0)
        Dim pagamento As String = SafeStatusText(pagamentoObj)

        If pagato = 1 OrElse stato = 2 Then Return "Pagamento confermato."

        Select Case stato
            Case 1
                Return "Pagamento in attesa di conferma dal gateway."
            Case 3
                Return "Pagamento non completato."
            Case 4
                Return "Pagamento annullato dall'utente."
            Case 5
                Return "Pagamento in verifica."
            Case Else
                If pagamento <> "" Then Return "Metodo: " & pagamento
                Return "Pagamento non ancora avviato."
        End Select
    End Function

    Private Function SafePaymentMessage(ByVal value As Object) As String
        Dim text As String = SafeStatusText(value)
        If text = "" Then Return ""

        Dim lower As String = text.ToLowerInvariant()
        If lower.Contains("ec-token") OrElse lower.Contains("token=") OrElse lower.Contains("signature") OrElse lower.Contains("pwd") Then
            Return "Dettaglio pagamento disponibile nel documento."
        End If

        Return TruncateText(text, 90)
    End Function

    Private Function SafeStatusText(ByVal value As Object) As String
        If value Is Nothing OrElse IsDBNull(value) Then Return ""

        Dim text As String = Convert.ToString(value).Trim()
        If text = "" Then Return ""

        text = text.Replace(vbCr, " ").Replace(vbLf, " ").Replace(vbTab, " ")
        Do While text.Contains("  ")
            text = text.Replace("  ", " ")
        Loop

        Return text
    End Function

    Private Function SafeInt(ByVal value As Object, ByVal fallback As Integer) As Integer
        Try
            If value Is Nothing OrElse IsDBNull(value) Then Return fallback
            Dim parsed As Integer = fallback
            If Integer.TryParse(Convert.ToString(value), parsed) Then Return parsed
        Catch
        End Try

        Return fallback
    End Function

    Private Function TruncateText(ByVal value As String, ByVal maxLength As Integer) As String
        If String.IsNullOrEmpty(value) Then Return ""
        If maxLength <= 0 Then Return ""
        If value.Length <= maxLength Then Return value
        Return value.Substring(0, maxLength).TrimEnd() & "..."
    End Function
End Class
