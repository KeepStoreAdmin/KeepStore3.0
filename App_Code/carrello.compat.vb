Option Strict On
Option Explicit On

Imports System
Imports System.Web.UI
Imports System.Web.UI.WebControls
Imports System.Web.UI.HtmlControls

' ============================================================================
' carrello.compat.vb
' ----------------------------------------------------------------------------
' In questo progetto alcune pagine non hanno il file .designer.vb allineato.
' Questo partial class dichiara i controlli referenziati dal code-behind, così
' da evitare errori BC30451/BC30456 in aspnet_compiler.
' ============================================================================
Partial Public Class carrello

    ' Pannelli / wrapper
    Protected WithEvents pnlFatturazione As Panel
    Protected WithEvents PnlSpedizione As Panel

    ' Lista articoli
    Protected WithEvents Repeater1 As Repeater

    ' Checkout / indirizzi
    Protected WithEvents LstScegliIndirizzo As DropDownList

    ' Blocchi UI
    Protected WithEvents canorder As HtmlGenericControl
    Protected WithEvents Checkout_Err As HtmlGenericControl
    Protected WithEvents litCheckoutErr As Literal

    ' Appoggi
    Protected WithEvents tbShopIdGestPay As TextBox
    Protected WithEvents lblBuonoScontoIVA As Label
    Protected WithEvents ddlCitta2 As DropDownList
    Protected WithEvents tbTelefono2 As TextBox
    Protected WithEvents RFTelefono2 As RequiredFieldValidator
    Protected WithEvents open1 As HtmlAnchor
    Protected WithEvents open2 As HtmlAnchor
    Protected WithEvents insOmod As HtmlInputHidden

    ' Label riepilogo destinazione/spedizione
    Protected WithEvents lblTab_RagioneSocialeSpedizione As Label
    Protected WithEvents lblTab_NomeSpedizione As Label
    Protected WithEvents lblTab_IndirizzoSpedizione As Label
    Protected WithEvents lblTab_CittaSpedizione As Label
    Protected WithEvents lblTab_CapSpedizione As Label
    Protected WithEvents lblTab_ProvinciaSpedizione As Label
    Protected WithEvents lblTab_ZonaSpedizione As Label
    Protected WithEvents lblTab_TelSpedizione As Label
    Protected WithEvents lblTab_NotaDestinazione As Label

    ' GridView usate con API legacy (Items/ItemCommand): tipizziamo come GridViewCompat
    Protected WithEvents gvArticoliGratis As GridViewCompat

End Class
