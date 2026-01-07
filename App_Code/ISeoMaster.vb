Option Strict On
Option Explicit On

' Interfaccia minima: il MasterPage espone un payload JSON-LD (iniettato in <head>).
Public Interface ISeoMaster
    Property SeoJsonLd As String
End Interface
