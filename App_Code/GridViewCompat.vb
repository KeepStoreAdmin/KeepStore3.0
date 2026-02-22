Option Strict On
Option Explicit On

Imports System
Imports System.Web.UI.WebControls

' ============================================================================
' GridViewCompat
' ----------------------------------------------------------------------------
' Alias compatibili per codice legacy:
'   - Items       => Rows
'   - ItemCommand => RowCommand
' Utile per garantire la precompilazione completa (aspnet_compiler).
' ============================================================================
Public Class GridViewCompat
    Inherits GridView

    Public ReadOnly Property Items As GridViewRowCollection
        Get
            Return Me.Rows
        End Get
    End Property

    Public Event ItemCommand As GridViewCommandEventHandler

    Protected Overrides Sub OnRowCommand(ByVal e As GridViewCommandEventArgs)
        RaiseEvent ItemCommand(Me, e)
        MyBase.OnRowCommand(e)
    End Sub
End Class
