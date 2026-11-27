Option Strict On
Option Explicit On

' CSP del sito (GCR-OPTIN-1A). Una sola fonte per il testo della policy stretta, usata da KeepStoreSecurity.AddSecurityHeaders per ogni pagina.
' La versione per l'attivazione di Recensioni dei clienti su Google aggiunge SOLO due direttive, costruite sulle stesse fonti di default-src
' (un script-src o un frame-src espliciti sostituiscono il ripiego su default-src: se non ripetessero self, inline, eval, data e blob
' le pagine perderebbero permessi che hanno oggi). Misurato in un browser vero: bastano apis.google.com per lo script e
' www.google.com per la finestra. Quella allargata si imposta solo sulle pagine che emettono lo snippet.
Public NotInheritable Class KeepStoreContentSecurityPolicy
    Private Sub New()
    End Sub

    Private Const DefaultSources As String = "'self' 'unsafe-inline' 'unsafe-eval' data: blob:"
    Private Const FrameSources As String = "'self' data: blob:"
    Public Const GoogleScriptHost As String = "https://apis.google.com"
    Public Const GoogleFrameHost As String = "https://www.google.com"

    Public Shared Function Strict() As String
        Return "default-src " & DefaultSources & "; " &
               "img-src 'self' data: blob:; " &
               "media-src 'self' data: blob:; " &
               "font-src 'self' data:; " &
               "connect-src 'self' *; " &
               "frame-ancestors 'self';"
    End Function

    Public Shared Function WithGoogleCustomerReviews() As String
        Return Strict() & " script-src " & DefaultSources & " " & GoogleScriptHost & "; frame-src " & FrameSources & " " & GoogleFrameHost & ";"
    End Function
End Class
