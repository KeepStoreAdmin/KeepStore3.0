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
'   KeepStore.Theme.AssetsBaseUrl -> base url asset
'   KeepStore.Theme.Name          -> nome tema (tagging / switch)
'   KeepStore.Theme.Class.<key>   -> token classi (opzionale)
'
' N.B.:
' - I valori sono URL-path (non file-system path).
' - Le funzioni normalizzano slash e prevengono path traversal.
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

            If String.IsNullOrWhiteSpace(v) Then v = "keepstore"

            v = v.Trim().ToLowerInvariant()
            v = RegexSafeSlug(v)

            If String.IsNullOrWhiteSpace(v) Then v = "keepstore"

            Return v
        End Get
    End Property

    ''' <summary>
    ''' Base URL per gli asset del template corrente.
    '''
    ''' Priorità (web.config / appSettings):
    ''' 1) KeepStore.Theme.AssetsBaseUrl
    ''' 2) KeepStore.Theme.BaseUrl (alias compatibilità)
    ''' 3) /Public/assets/{ThemeName}/ (auto)
    ''' 4) default: /Public/assets/keepstore/
    ''' </summary>
    Public ReadOnly Property AssetsBaseUrl As String
        Get
            Dim v As String = Nothing

            ' 1) AssetsBaseUrl
            Try
                v = ConfigurationManager.AppSettings("KeepStore.Theme.AssetsBaseUrl")
            Catch
                v = Nothing
            End Try

            ' 2) BaseUrl alias (compatibilità)
            If String.IsNullOrWhiteSpace(v) Then
                Try
                    v = ConfigurationManager.AppSettings("KeepStore.Theme.BaseUrl")
                Catch
                    v = Nothing
                End Try
            End If

            ' 3) fallback automatico su ThemeName
            If String.IsNullOrWhiteSpace(v) Then
                Dim tn As String = ThemeName
                If Not String.IsNullOrWhiteSpace(tn) Then
                    v = "/Public/assets/" & tn & "/"
                End If
            End If

            ' 4) fallback finale
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

    ''' <summary>Alias di AssetsBaseUrl (compatibilità semantica).</summary>
    Public ReadOnly Property BaseUrl As String
        Get
            Return AssetsBaseUrl
        End Get
    End Property

    ''' <summary>Costruisce un URL sicuro verso un asset del template.</summary>
    Public Function Asset(ByVal relativePath As String) As String
        If relativePath Is Nothing Then relativePath = String.Empty

        Dim p As String = relativePath.Trim()

        ' Evita absolute URL/paths esterni e traversal
        p = p.Replace("\", "/")
        While p.StartsWith("/", StringComparison.Ordinal)
            p = p.Substring(1)
        End While
        If p.Contains("..") Then p = p.Replace("..", String.Empty)

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

        If String.IsNullOrWhiteSpace(v) Then Return fallbackClasses
        Return v.Trim()
    End Function

    ''' <summary>
    ''' URL immagine prodotto (catalogo/home/dettaglio).
    ''' - Supporta: URL assoluti, path root-relative (/Images/...), path relativo (Images/..), o solo filename.
    ''' - Configurazioni opzionali:
    '''     KeepStore.Products.ImageBaseUrl         (default: /Images/articoli/)
    '''     KeepStore.Products.PlaceholderImageUrl  (fallback: Asset("img/placeholder.png"))
    ''' </summary>
    Public Function ProductImageUrl(ByVal imgValue As Object) As String
        Dim raw As String = ""

        Try
            If imgValue Is Nothing OrElse Convert.IsDBNull(imgValue) Then
                raw = ""
            Else
                raw = Convert.ToString(imgValue)
            End If
        Catch
            raw = ""
        End Try

        raw = If(raw, "").Trim()

        If raw = "" Then
            Dim ph As String = Nothing
            Try
                ph = ConfigurationManager.AppSettings("KeepStore.Products.PlaceholderImageUrl")
            Catch
                ph = Nothing
            End Try

            If String.IsNullOrWhiteSpace(ph) Then
                ph = Asset("img/placeholder.png")
            End If

            Return ph
        End If

        raw = raw.Replace("\", "/")

        ' URL assoluti / data uri
        If raw.StartsWith("http://", StringComparison.OrdinalIgnoreCase) _
            OrElse raw.StartsWith("https://", StringComparison.OrdinalIgnoreCase) _
            OrElse raw.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then
            Return raw
        End If

        ' previeni traversal
        If raw.Contains("..") Then raw = raw.Replace("..", String.Empty)

        ' path già root-relative
        If raw.StartsWith("/", StringComparison.Ordinal) Then
            Try
                Return VirtualPathUtility.ToAbsolute(raw)
            Catch
                Return raw
            End Try
        End If

        ' path relativo (es. "Images/Articoli/x.jpg")
        If raw.IndexOf("/", StringComparison.Ordinal) >= 0 Then
            Dim rp As String = "/" & raw.TrimStart("/"c)
            Try
                Return VirtualPathUtility.ToAbsolute(rp)
            Catch
                Return rp
            End Try
        End If

        ' solo filename: compone usando base configurabile
        Dim baseUrl As String = Nothing
        Try
            baseUrl = ConfigurationManager.AppSettings("KeepStore.Products.ImageBaseUrl")
        Catch
            baseUrl = Nothing
        End Try

        If String.IsNullOrWhiteSpace(baseUrl) Then
            baseUrl = "/Images/articoli/"
        End If

        baseUrl = baseUrl.Trim().Replace("\", "/")
        If Not baseUrl.EndsWith("/", StringComparison.Ordinal) Then baseUrl &= "/"
        If Not baseUrl.StartsWith("/", StringComparison.Ordinal) AndAlso Not baseUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
            baseUrl = "/" & baseUrl
        End If

        Dim fileName As String = EscapePathSegment(raw)

        Dim url As String = baseUrl & fileName
        Try
            Return VirtualPathUtility.ToAbsolute(url)
        Catch
            Return url
        End Try
    End Function



    ''' <summary>
    ''' Compatta un testo a una lunghezza massima (utile per card/prodotti).
    ''' - Ritorna stringa vuota per Nothing/DBNull.
    ''' - Non esegue HtmlEncode (va fatto nel markup dove serve).
    ''' </summary>
    Public Function CompactText(ByVal value As Object, ByVal maxLen As Integer) As String
        Dim s As String = String.Empty

        Try
            If value Is Nothing OrElse Convert.IsDBNull(value) Then
                s = String.Empty
            Else
                s = Convert.ToString(value)
            End If
        Catch
            s = String.Empty
        End Try

        s = If(s, String.Empty).Trim()
        If s.Length = 0 Then Return String.Empty

        If maxLen <= 0 Then Return s
        If s.Length <= maxLen Then Return s

        ' Evita eccezioni con maxLen piccolo
        If maxLen = 1 Then Return s.Substring(0, 1)

        Return s.Substring(0, maxLen - 1) & "..."
    End Function
    Private Function EscapePathSegment(ByVal segment As String) As String
        If String.IsNullOrEmpty(segment) Then Return String.Empty

        ' Non permettere separatori (sicurezza)
        Dim s As String = segment.Replace("/", "_").Replace("\", "_")

        Try
            Return Uri.EscapeDataString(s)
        Catch
            ' Fallback minimo (spazi)
            Return s.Replace(" ", "%20")
        End Try
    End Function

    Private Function RegexSafeSlug(ByVal s As String) As String
        If String.IsNullOrEmpty(s) Then Return String.Empty

        Dim r As New System.Text.StringBuilder(s.Length)
        For Each ch As Char In s
            If (ch >= "a"c AndAlso ch <= "z"c) _
                OrElse (ch >= "0"c AndAlso ch <= "9"c) _
                OrElse ch = "-"c _
                OrElse ch = "_"c Then
                r.Append(ch)
            End If
        Next

        Return r.ToString()
    End Function

End Module
