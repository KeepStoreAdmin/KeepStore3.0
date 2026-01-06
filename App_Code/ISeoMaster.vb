' Interfaccia minima: il MasterPage espone un payload JSON-LD (script) che verrà iniettato nel <head>.
Option Strict On
Option Explicit On

Public Interface ISeoMaster
    Property SeoJsonLd As String
End Interface
