Option Strict On
Option Explicit On

' Minimal interface exposed by the MasterPage (Page.master) to receive JSON-LD payloads
' (injected in <head> through an <asp:Literal ID="litSeoJsonLd">).
Public Interface ISeoMaster
    Property SeoJsonLd As String
End Interface
