Imports System
Imports System.Collections.Generic
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
    Private Const ProductImageBaseUrl As String = "/Public/assets/images/articoli/"
    Private Const ProductPlaceholderUrl As String = "/Public/assets/images/img/placeholder.svg"
    Private Const ProductPlaceholderFallbackDataUri As String = "data:image/svg+xml,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%20viewBox='0%200%20320%20320'%20role='img'%20aria-label='Immagine%20prodotto%20non%20disponibile'%3E%3Crect%20width='320'%20height='320'%20fill='%23f3f5f7'/%3E%3Crect%20x='52'%20y='58'%20width='216'%20height='150'%20rx='12'%20fill='%23fff'%20stroke='%23aeb7c1'%20stroke-width='5'/%3E%3Ccircle%20cx='218'%20cy='102'%20r='17'%20fill='%23d5dbe1'/%3E%3Cpath%20d='M70%20190l58-62%2043%2044%2032-30%2047%2048z'%20fill='%23c7ced6'/%3E%3Ctext%20x='160'%20y='258'%20text-anchor='middle'%20font-family='Arial,sans-serif'%20font-size='18'%20font-weight='700'%20fill='%23343a40'%3EImmagine%20non%20disponibile%3C/text%3E%3C/svg%3E"

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
    ''' URL canonico di un'immagine prodotto locale esistente.
    ''' URL HTTP/HTTPS e data URI vengono preservati; i file locali mancanti usano il placeholder.
    ''' </summary>
    Public Function ProductImageUrl(ByVal imgValue As Object) As String
        Dim raw As String = ProductImageRawValue(imgValue)
        If IsExternalProductImageUrl(raw) Then Return raw

        Dim fileName As String = NormalizeProductFileName(raw)
        If String.IsNullOrWhiteSpace(fileName) OrElse Not ProductImageFileExists(fileName) Then
            Return PlaceholderProductImageUrl()
        End If

        Return BuildProductImageUrl(fileName)
    End Function

    ''' <summary>
    ''' Preferisce la miniatura locale _filename quando esiste, altrimenti usa l'immagine piena.
    ''' </summary>
    Public Function ProductThumbnailImageUrl(ByVal imgValue As Object) As String
        Dim raw As String = ProductImageRawValue(imgValue)
        If IsExternalProductImageUrl(raw) Then Return raw

        Dim fileName As String = NormalizeProductFileName(raw)
        If String.IsNullOrWhiteSpace(fileName) Then Return PlaceholderProductImageUrl()

        If fileName.StartsWith("_", StringComparison.Ordinal) Then
            If ProductImageFileExists(fileName) Then Return BuildProductImageUrl(fileName)

            Dim fullFileName As String = fileName.Substring(1)
            If String.IsNullOrWhiteSpace(fullFileName) Then Return PlaceholderProductImageUrl()
            Return ProductImageUrl(fullFileName)
        End If

        Dim thumbnailFileName As String = "_" & fileName
        If ProductImageFileExists(thumbnailFileName) Then
            Return BuildProductImageUrl(thumbnailFileName)
        End If

        Return ProductImageUrl(fileName)
    End Function

    ''' <summary>
    ''' Placeholder standard per immagini prodotto mancanti.
    ''' </summary>
    Public Function PlaceholderProductImageUrl() As String
        If Not ProductPlaceholderFileExists() Then Return ProductPlaceholderFallbackDataUri

        Try
            Return VirtualPathUtility.ToAbsolute(ProductPlaceholderUrl)
        Catch
            Return ProductPlaceholderFallbackDataUri
        End Try
    End Function

    Private Function ProductPlaceholderFileExists() As Boolean
        Const cacheKey As String = "ks_product_placeholder_exists"
        Dim context As HttpContext = HttpContext.Current

        If context IsNot Nothing AndAlso context.Items(cacheKey) IsNot Nothing Then
            Return Convert.ToBoolean(context.Items(cacheKey))
        End If

        Dim exists As Boolean = False
        Try
            Dim physicalPath As String = System.Web.Hosting.HostingEnvironment.MapPath("~" & ProductPlaceholderUrl)
            If String.IsNullOrWhiteSpace(physicalPath) AndAlso context IsNot Nothing Then
                physicalPath = context.Server.MapPath(ProductPlaceholderUrl)
            End If
            exists = Not String.IsNullOrWhiteSpace(physicalPath) AndAlso System.IO.File.Exists(physicalPath)
        Catch
            exists = False
        End Try

        If context IsNot Nothing Then context.Items(cacheKey) = exists
        Return exists
    End Function

    Private Function ProductImageRawValue(ByVal imgValue As Object) As String
        Try
            If imgValue Is Nothing OrElse Convert.IsDBNull(imgValue) Then Return String.Empty
            Return If(Convert.ToString(imgValue), String.Empty).Trim()
        Catch
            Return String.Empty
        End Try
    End Function

    Private Function IsExternalProductImageUrl(ByVal raw As String) As Boolean
        If String.IsNullOrWhiteSpace(raw) Then Return False
        Return raw.StartsWith("http://", StringComparison.OrdinalIgnoreCase) _
            OrElse raw.StartsWith("https://", StringComparison.OrdinalIgnoreCase) _
            OrElse raw.StartsWith("data:", StringComparison.OrdinalIgnoreCase)
    End Function

    Private Function NormalizeProductFileName(ByVal raw As String) As String
        If String.IsNullOrWhiteSpace(raw) Then Return String.Empty

        Dim decoded As String = raw.Trim()
        Try
            decoded = Uri.UnescapeDataString(decoded)
        Catch
            Return String.Empty
        End Try

        decoded = decoded.Replace("\", "/")
        If decoded.IndexOf("..", StringComparison.Ordinal) >= 0 Then Return String.Empty

        Dim fileName As String = String.Empty
        Try
            fileName = System.IO.Path.GetFileName(decoded)
        Catch
            Return String.Empty
        End Try

        If String.IsNullOrWhiteSpace(fileName) _
            OrElse fileName.IndexOf("/"c) >= 0 _
            OrElse fileName.IndexOf("\"c) >= 0 _
            OrElse fileName.IndexOf("..", StringComparison.Ordinal) >= 0 Then
            Return String.Empty
        End If

        Return fileName.Trim()
    End Function

    Private Function ProductImageFileExists(ByVal fileName As String) As Boolean
        Dim safeFileName As String = NormalizeProductFileName(fileName)
        If String.IsNullOrWhiteSpace(safeFileName) Then Return False

        Try
            Dim basePhysicalPath As String = System.Web.Hosting.HostingEnvironment.MapPath("~" & ProductImageBaseUrl)
            If String.IsNullOrWhiteSpace(basePhysicalPath) AndAlso HttpContext.Current IsNot Nothing Then
                basePhysicalPath = HttpContext.Current.Server.MapPath(ProductImageBaseUrl)
            End If
            If String.IsNullOrWhiteSpace(basePhysicalPath) Then Return False

            Dim normalizedBase As String = System.IO.Path.GetFullPath(basePhysicalPath)
            If Not normalizedBase.EndsWith(System.IO.Path.DirectorySeparatorChar.ToString(), StringComparison.Ordinal) Then
                normalizedBase &= System.IO.Path.DirectorySeparatorChar
            End If

            Dim candidate As String = System.IO.Path.GetFullPath(System.IO.Path.Combine(normalizedBase, safeFileName))
            If Not candidate.StartsWith(normalizedBase, StringComparison.OrdinalIgnoreCase) Then Return False

            Return System.IO.File.Exists(candidate)
        Catch
            Return False
        End Try
    End Function

    Private Function BuildProductImageUrl(ByVal fileName As String) As String
        Dim url As String = ProductImageBaseUrl & EscapePathSegment(fileName)
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



    ' ============================================================
    ' Catalogo / Shop: helper URL per filtri (senza dipendere da campi "url" nel datasource)
    ' ============================================================

    
    Public Function CatalogFilterId(ByVal key As String, ByVal dataItem As Object) As String
        Dim n As Integer = ExtractCatalogFilterId(key, dataItem)
        If n <= 0 Then Return String.Empty
        Return n.ToString()
    End Function

    Public Function CatalogFilterSelected(ByVal key As String, ByVal dataItem As Object) As Boolean
        Dim idStr As String = CatalogFilterId(key, dataItem)
        If String.IsNullOrEmpty(idStr) Then Return False

        Dim ctx As HttpContext = HttpContext.Current
        If ctx Is Nothing OrElse ctx.Request Is Nothing Then Return False

        Dim current As String = Convert.ToString(ctx.Request.QueryString(key))
        If String.IsNullOrEmpty(current) Then Return False

        For Each p As String In current.Split("|"c)
            If String.Equals(CleanIdPart(p), idStr, StringComparison.Ordinal) Then Return True
        Next

        Return False
    End Function

    Public Function CatalogFilterUrl(ByVal key As String, ByVal dataItem As Object) As String
        Dim idStr As String = CatalogFilterId(key, dataItem)
        If String.IsNullOrEmpty(idStr) Then
            Return HtmlAttr(SafeCurrentPathAndQuery())
        End If
        Return CatalogFilterUrlById(key, idStr)
    End Function

    Public Function CatalogFilterUrlById(ByVal key As String, ByVal idStr As String) As String
        Dim ctx As HttpContext = HttpContext.Current
        If ctx Is Nothing OrElse ctx.Request Is Nothing Then Return "#"

        Dim path As String = ctx.Request.Url.AbsolutePath

        Dim qs As System.Collections.Specialized.NameValueCollection
        Try
            qs = HttpUtility.ParseQueryString(ctx.Request.QueryString.ToString())
        Catch
            qs = New System.Collections.Specialized.NameValueCollection()
        End Try

        Dim cleanKey As String = CleanFilterKey(key)
        If String.IsNullOrEmpty(cleanKey) Then Return HtmlAttr(SafeCurrentPathAndQuery())

        Dim cleanId As String = CleanIdPart(idStr)
        If String.IsNullOrEmpty(cleanId) Then Return HtmlAttr(SafeCurrentPathAndQuery())

        Dim list As New System.Collections.Generic.List(Of String)()

        Dim current As String = Convert.ToString(qs(cleanKey))
        If Not String.IsNullOrEmpty(current) Then
            For Each p As String In current.Split("|"c)
                Dim cp As String = CleanIdPart(p)
                If cp <> "" AndAlso Not list.Contains(cp) Then list.Add(cp)
            Next
        End If

        If list.Contains(cleanId) Then
            list.Remove(cleanId)
        Else
            list.Add(cleanId)
        End If

        If list.Count = 0 Then
            qs.Remove(cleanKey)
        Else
            qs(cleanKey) = String.Join("|", list.ToArray())
        End If

        ' reset paging + transient params when filters change
        qs.Remove("page") : qs.Remove("pg") : qs.Remove("p")
        qs.Remove("rimuovi")

        Dim newQuery As String = qs.ToString()
        Dim url As String = If(String.IsNullOrEmpty(newQuery), path, path & "?" & newQuery)
        Return HtmlAttr(url)
    End Function

    Private Function SafeCurrentPathAndQuery() As String
        Dim ctx As HttpContext = HttpContext.Current
        If ctx Is Nothing OrElse ctx.Request Is Nothing Then Return "#"

        Dim u As String = ctx.Request.RawUrl
        If String.IsNullOrEmpty(u) Then u = ctx.Request.Url.AbsolutePath
        Return u
    End Function

    Private Function HtmlAttr(ByVal s As String) As String
        If s Is Nothing Then s = String.Empty
        Try
            Return HttpUtility.HtmlAttributeEncode(s)
        Catch
            Return s
        End Try
    End Function

    Private Function CleanFilterKey(ByVal key As String) As String
        If String.IsNullOrEmpty(key) Then Return String.Empty
        key = key.Trim()

        Dim sb As New System.Text.StringBuilder(key.Length)
        For Each ch As Char In key
            If Char.IsLetterOrDigit(ch) OrElse ch = "_"c Then
                sb.Append(Char.ToLowerInvariant(ch))
            End If
        Next

        Return sb.ToString()
    End Function

    Private Function CleanIdPart(ByVal s As String) As String
        If String.IsNullOrEmpty(s) Then Return String.Empty

        Dim n As Integer = 0
        Try
            n = CInt(Val(s))
        Catch
            n = 0
        End Try

        If n <= 0 Then Return String.Empty
        Return n.ToString()
    End Function

    Private Function ExtractCatalogFilterId(ByVal key As String, ByVal dataItem As Object) As Integer
        Try
            Dim drv As System.Data.DataRowView = TryCast(dataItem, System.Data.DataRowView)
            If drv Is Nothing Then Return 0

            For Each colName As String In GetCandidateIdColumns(key)
                Dim v As String = TryGetDrvValue(drv, colName)
                Dim n As Integer = 0
                Try : n = CInt(Val(v)) : Catch : n = 0 : End Try
                If n > 0 Then Return n
            Next

            ' Fallback: primo campo che contiene "id"
            For Each c As System.Data.DataColumn In drv.Row.Table.Columns
                Dim cn As String = Convert.ToString(c.ColumnName)
                If String.IsNullOrEmpty(cn) Then Continue For
                If cn.ToLowerInvariant().Contains("id") Then
                    Dim v As String = TryGetDrvValue(drv, cn)
                    Dim n As Integer = 0
                    Try : n = CInt(Val(v)) : Catch : n = 0 : End Try
                    If n > 0 Then Return n
                End If
            Next

            ' Fallback 2: prima colonna numerica valida
            For Each c As System.Data.DataColumn In drv.Row.Table.Columns
                Dim v As String = TryGetDrvValue(drv, c.ColumnName)
                Dim n As Integer = 0
                Try : n = CInt(Val(v)) : Catch : n = 0 : End Try
                If n > 0 Then Return n
            Next

        Catch
            ' swallow
        End Try

        Return 0
    End Function

    Private Function GetCandidateIdColumns(ByVal key As String) As String()
        If key Is Nothing Then key = ""
        key = key.Trim().ToLowerInvariant()

        Select Case key
            Case "gr"
                Return New String() {"id", "GruppiId", "GruppoId", "IDGruppo", "idgruppo"}
            Case "sg"
                Return New String() {"id", "SottogruppiId", "SottogruppoId", "IDSottogruppo", "idsottogruppo"}
            Case "mr"
                Return New String() {"id", "MarcheId", "MarcaId", "marcheid", "idmarca"}
            Case "tp"
                Return New String() {"id", "TipologieId", "TipologiaId", "tipologieid"}
            Case Else
                Return New String() {"id"}
        End Select
    End Function

    Private Function TryGetDrvValue(ByVal drv As System.Data.DataRowView, ByVal colName As String) As String
        If drv Is Nothing OrElse String.IsNullOrEmpty(colName) Then Return String.Empty
        Try
            Dim o As Object = drv(colName)
            If o Is Nothing OrElse Convert.IsDBNull(o) Then Return String.Empty
            Return Convert.ToString(o)
        Catch
            Return String.Empty
        End Try
    End Function


End Module
