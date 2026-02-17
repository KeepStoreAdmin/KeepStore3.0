Imports System
Imports System.Configuration
Imports System.Web

' ============================================================
' ThemeManager (KeepStore 3.0)
' ------------------------------------------------------------
' Obiettivo: rendere il front-end "switchabile" in futuro senza
' riscrivere la logica VB.
'
' 1) Asset() centralizza i percorsi degli asset (CSS/JS/IMG)
'    tramite appSettings: KeepStore.Theme.AssetsBaseUrl
'
' 2) Css(key) permette di mappare classi chiave via web.config:
'    KeepStore.Theme.Class.<key> = "..."
'
' NOTE:
' - AssetsBaseUrl e' un URL-path (non file-system path).
' - Asset() normalizza slash e previene path traversal.
' ============================================================
Public Module ThemeManager

    Private Const DefaultBaseUrl As String = "/Public/assets/keepstore/"
    Private Const DefaultThemeName As String = "keepstore"

    ''' <summary>
    ''' Nome del tema corrente (per tagging e diagnostica).
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

            If String.IsNullOrWhiteSpace(v) Then v = DefaultThemeName

            v = v.Trim().ToLowerInvariant()
            v = v.Replace(" ", "-")
            v = v.Replace("/", "-")
            v = v.Replace("\\", "-")
            If v.Length = 0 Then v = DefaultThemeName

            Return v
        End Get
    End Property

    ''' <summary>
    ''' Base URL per gli asset del tema corrente.
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

            If String.IsNullOrWhiteSpace(v) Then v = DefaultBaseUrl
            v = v.Trim()

            ' Normalizza
            If Not v.StartsWith("/", StringComparison.Ordinal) Then v = "/" & v
            If Not v.EndsWith("/", StringComparison.Ordinal) Then v &= "/"

            Return v
        End Get
    End Property

    ''' <summary>
    ''' Restituisce una classe CSS "chiave" configurabile via web.config.
    ''' Chiave: KeepStore.Theme.Class.&lt;key&gt;
    ''' </summary>
    Public Function Css(ByVal key As String, Optional ByVal fallback As String = "") As String
        Dim k As String = If(key, String.Empty).Trim()
        If k.Length = 0 Then Return fallback

        Dim v As String = Nothing
        Try
            v = ConfigurationManager.AppSettings("KeepStore.Theme.Class." & k)
        Catch
            v = Nothing
        End Try

        If String.IsNullOrWhiteSpace(v) Then Return fallback
        Return v.Trim()
    End Function

    ''' <summary>
    ''' Costruisce un URL sicuro verso un asset del tema.
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

End Module
