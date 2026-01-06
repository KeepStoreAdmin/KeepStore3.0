Option Strict On

' Interfaccia minima per far esporre al MasterPage (Page.master) un payload JSON-LD
' che verrà iniettato nel <head> tramite l'asp:Literal litSeoJsonLd.
Public Interface ISeoMaster
    Property SeoJsonLd As String
End Interface
