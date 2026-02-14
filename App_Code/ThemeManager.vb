Imports System
Imports System.Configuration
Imports System.Web

' ============================================================
' ThemeManager (KeepStore 3.0)
' ------------------------------------------------------------
' Centralizza i percorsi degli asset del template.
'
' Oggi: Onsus (ThemeForest)
'   /Public/assets/keepstore/
' Domani: qualunque template
'   basta cambiare KeepStore.Theme.AssetsBaseUrl in web.config
'
' Esempi (markup):
'   <link rel="stylesheet" href="<%= ThemeManager.Asset("css/styles.css") %>" />
'   <script src="<%= ThemeManager.Asset("js/main.js") %>"></script>
'
' N.B.:
' - Il valore e' un URL-path (non file-system path).
' - La funzione normalizza slash e previene path traversal.
' ============================================================
Public Module ThemeManager

    Private Const DefaultBaseUrl As String = "/Public/assets/keepstore/"

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

End Module
