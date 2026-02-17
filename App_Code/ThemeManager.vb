Imports System
Imports System.Configuration
Imports System.Web

' ============================================================
' ThemeManager (KeepStore)
' ------------------------------------------------------------
' Centralizza i percorsi degli asset del tema grafico e i token
' (classi chiave) per supportare futuri cambi di template senza
' riscrivere la logica VB.
'
' Base asset (default):
'   /Public/assets/keepstore/
'
' Configurazione (web.config / appSettings):
'   KeepStore.Theme.AssetsBaseUrl  -> base url asset
'   KeepStore.Theme.Name           -> nome tema (tagging / switch)
'   KeepStore.Theme.Class.<key>    -> token classi (opzionale)
'
' Esempi (markup):
'   <link rel="stylesheet" href="<%= ThemeManager.Asset("css/styles.css") %>" />
'   <body class="<%= ThemeManager.Css("body", "preload-wrapper") %>">
'
' N.B.:
' - I valori sono URL-path (non file-system path).
' - La funzione normalizza slash e previene path traversal.
' ============================================================
Public Module ThemeManager

    Private Const DefaultBaseUrl As String = "/Public/assets/keepstore/"

    ''' <summary>
    ''' Nome logico del tema attivo (per tagging e future switch).
    ''' Configurabile via appSettings: KeepStore.Theme.Name
    ''' </summary>
    Public ReadOnly Property ThemeName As String
        Get
            Dim v As String = Nothing
            Try
                v = ConfigurationManager.AppSettings("KeepStore.Theme.Name")
            Catch
                v = Nothing
            End Try

            If String.IsNullOrWhiteSpace(v) Then
                v = "keepstore"
            End If

            v = v.Trim().ToLowerInvariant()
            v = RegexSafeSlug(v)
            If String.IsNullOrWhiteSpace(v) Then v = "keepstore"
            Return v
        End Get
    End Property

    ''' <summary>
    ''' Base URL per gli asset del template corrente.
    ''' Configurabile via appSettings: KeepStore.Theme.AssetsBaseUrl
    ''' </summary>
    Public ReadOnly Property AssetsBaseUrl As String
        Get
            Dim v As String = Nothing
            Try
                v = ConfigurationManager.AppSettings("KeepStore.Theme.AssetsBaseUrl")
            Catch
                v = Nothing
            End Try

            If String.IsNullOrWhiteSpace(v) Then
                v = DefaultBaseUrl
            End If

            v = v.Trim()

            ' Normalizza
            If Not v.StartsWith("/", StringComparison.Ordinal) Then v = "/" & v
            If Not v.EndsWith("/", StringComparison.Ordinal) Then v &= "/"

            Return v
        End Get
    End Property

    ''' <summary>
    ''' Costruisce un URL sicuro verso un asset del template.
    ''' </summary>
    Public Function Asset(ByVal relativePath As String) As String
        If relativePath Is Nothing Then relativePath = String.Empty

        Dim p As String = relativePath.Trim()

        ' Evita absolute URL/paths esterni e traversal
        p = p.Replace("\\", "/")
        While p.StartsWith("/", StringComparison.Ordinal)
            p = p.Substring(1)
        End While
        If p.Contains("..") Then
            p = p.Replace("..", String.Empty)
        End If

        Dim url As String = AssetsBaseUrl & p

        ' ResolveUrl per supporto virtual directories
        Try
            Return VirtualPathUtility.ToAbsolute(url)
        Catch
            Return url
        End Try
    End Function

    ''' <summary>
    ''' Token CSS: ritorna classi per una chiave configurabile in web.config.
    ''' Esempio: KeepStore.Theme.Class.body = "preload-wrapper popup-loader color-primary"
    ''' </summary>
    Public Function Css(ByVal key As String, Optional ByVal fallbackClasses As String = "") As String
        Dim k As String = If(key, String.Empty).Trim()
        If k = "" Then Return fallbackClasses

        Dim cfgKey As String = "KeepStore.Theme.Class." & k
        Dim v As String = Nothing
        Try
            v = ConfigurationManager.AppSettings(cfgKey)
        Catch
            v = Nothing
        End Try

        If String.IsNullOrWhiteSpace(v) Then
            Return fallbackClasses
        End If
        Return v.Trim()
    End Function

    Private Function RegexSafeSlug(ByVal s As String) As String
        If String.IsNullOrEmpty(s) Then Return String.Empty
        Dim r As New System.Text.StringBuilder(s.Length)
        For Each ch As Char In s
            If (ch >= "a"c AndAlso ch <= "z"c) OrElse (ch >= "0"c AndAlso ch <= "9"c) OrElse ch = "-"c OrElse ch = "_"c Then
                r.Append(ch)
            End If
        Next
        Return r.ToString()
    End Function

End Module
