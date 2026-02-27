Imports System.Web

Partial Class UI_HomeDepartmentsMenu
    Inherits System.Web.UI.UserControl

    '==========================================================
    ' HOME - Settori (Dipartimenti): URL compatibile legacy (st/ct/tp)
    '==========================================================
    Protected Function BuildSettoreUrl(ByVal settoreIdObj As Object, ByVal defaultCtObj As Object, ByVal defaultTpObj As Object) As String
        Dim settoreId As Integer = 0
        Integer.TryParse(Convert.ToString(settoreIdObj), settoreId)

        Dim ct As Integer = 0
        Integer.TryParse(Convert.ToString(defaultCtObj), ct)

        Dim tp As Integer = 0
        Integer.TryParse(Convert.ToString(defaultTpObj), tp)

        If settoreId <= 0 Then
            Return ResolveUrl("~/articoli.aspx")
        End If

        Dim url As String = ResolveUrl("~/articoli.aspx") & "?st=" & settoreId.ToString()

        If ct > 0 Then
            url &= "&ct=" & ct.ToString()
        End If

        If tp > 0 Then
            url &= "&tp=" & tp.ToString()
        End If

        Return url
    End Function

    ' HARDENING OUTPUT (XSS)
    Protected Function SafeText(ByVal obj As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(obj))
    End Function

    ' ============================================================
' Prezzo: helper locale per databinding (fix compilazione)
' NON cambia la logica: replica la funzione storica.
' ============================================================
Protected Function controlla_prezzo(ByVal prezzo As Double,
                                   ByVal prezzo_ivato As Double,
                                   ByVal prezzo_promo As Double,
                                   ByVal prezzo_promo_ivato As Double,
                                   ByVal iva_tipo As Integer) As String

    If prezzo_promo > 0 Then
        If iva_tipo = 1 Then
            Return String.Format("{0:c}", prezzo_promo)
        Else
            Return String.Format("{0:c}", prezzo_promo_ivato)
        End If
    Else
        If iva_tipo = 1 Then
            Return String.Format("{0:c}", prezzo)
        Else
            Return String.Format("{0:c}", prezzo_ivato)
        End If
    End If

    End Function

End Class
