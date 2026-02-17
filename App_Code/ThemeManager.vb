Imports System
Imports System.Configuration
Imports System.Web

' ============================================================
' ThemeManager (KeepStore 3.0)
' ------------------------------------------------------------
' Centralizza:
' - percorsi asset del tema grafico corrente
' - mapping di "classi chiave" per supportare il cambio tema
'   senza riscrivere la logica VB.
'
' Configurazione (web.config / appSettings):
' - KeepStore.Theme.AssetsBaseUrl   (es. /Public/assets/keepstore/)
' - KeepStore.Theme.Name           (es. default)
' - KeepStore.Theme.Class.<key>    (override puntuale classi)
'
' Esempi (markup):
'   <link rel="stylesheet" href="<%= ThemeManager.Asset("css/main.css") %>" />
'   <div class="<%= ThemeManager.Css("btn.primary") %>">...</div>
'
' N.B.:
' - AssetsBaseUrl e' un URL-path (non file-system path).
' - Asset(...) normalizza slash e previene path traversal.
' ============================================================
Public Module ThemeManager

    Private Const DefaultBaseUrl As String = "/Public/assets/keepstore/"

    Private Const DefaultThemeName As String = "default"

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
    ''' Nome del tema corrente (tag + future switch).
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
            v = v.Trim()

            ' Sanitizza: solo [a-z0-9-_] (fallback a default)
            Dim safe As New System.Text.StringBuilder()
            For Each ch As Char In v
                If (ch >= "a"c AndAlso ch <= "z"c) OrElse (ch >= "A"c AndAlso ch <= "Z"c) OrElse (ch >= "0"c AndAlso ch <= "9"c) OrElse ch = "-"c OrElse ch = "_"c Then
                    safe.Append(ch)
                End If
            Next
            Dim outName As String = safe.ToString()
            If String.IsNullOrWhiteSpace(outName) Then outName = DefaultThemeName
            Return outName
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
    ''' Restituisce una classe CSS "chiave" (con override da web.config).
    ''' Serve per future switch del tema senza toccare tutte le pagine.
    '''
    ''' Lookup:
    ''' 1) appSettings: KeepStore.Theme.Class.<key>
    ''' 2) fallback hardcoded (minimo indispensabile)
    ''' </summary>
    Public Function Css(ByVal key As String) As String
        If key Is Nothing Then key = String.Empty
        Dim k As String = key.Trim()
        If k.Length = 0 Then Return String.Empty

        ' 1) override via config
        Try
            Dim cfg As String = ConfigurationManager.AppSettings("KeepStore.Theme.Class." & k)
            If Not String.IsNullOrWhiteSpace(cfg) Then Return cfg.Trim()
        Catch
            ' ignore
        End Try

        ' 2) fallback minimi
        Select Case k.ToLowerInvariant()
            Case "breadcrumb.wrap" : Return "tf-breadcrumb-wrap"
            Case "breadcrumb.list" : Return "tf-breadcrumb-list"
            Case "btn.primary" : Return "tf-btn btn-fill"
            Case "btn.secondary" : Return "tf-btn btn-line"
            Case "section" : Return "flat-spacing"
            Case Else
                Return String.Empty
        End Select
    End Function

End Module
