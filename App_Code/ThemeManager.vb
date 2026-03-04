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
				ph = PlaceholderProductImageUrl()
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

		Dim fileName As String = EscapePathSegment(raw)
		Dim baseUrl As String = ResolveProductImageBaseUrl(fileName)

		Dim url As String = baseUrl & fileName
        Try
            Return VirtualPathUtility.ToAbsolute(url)
        Catch
            Return url
        End Try
    End Function

    ''' <summary>
    ''' Placeholder standard per immagini prodotto mancanti.
    ''' </summary>
    Public Function PlaceholderProductImageUrl() As String
        ' SVG leggero, stabile, senza dipendenze.
        Return Asset("img/placeholder.svg")
    End Function

    ''' <summary>
    ''' Risolve la base URL per le immagini prodotto.
    ''' Evita 404 quando il deploy usa cartelle diverse (es. /Images/articoli/, /Public/images/articoli/...).
    '''
    ''' NOTE:
    ''' - cache per-request in HttpContext.Items
    ''' - se non riesce a verificare l'esistenza fisica, usa config o default
    ''' </summary>
    Private Function ResolveProductImageBaseUrl(ByVal fileName As String) As String
        Dim configured As String = Nothing
        Try
            configured = ConfigurationManager.AppSettings("KeepStore.Products.ImageBaseUrl")
        Catch
            configured = Nothing
        End Try

        Dim fallback As String = If(String.IsNullOrWhiteSpace(configured), "/Images/articoli/", configured)

        Dim NormalizeBase As Func(Of String, String) = Function(b As String) As String
                                                           If String.IsNullOrWhiteSpace(b) Then Return ""
                                                           Dim s As String = b.Trim().Replace("\", "/")
                                                           If Not s.EndsWith("/", StringComparison.Ordinal) Then s &= "/"
                                                           If Not s.StartsWith("/", StringComparison.Ordinal) AndAlso Not s.StartsWith("http", StringComparison.OrdinalIgnoreCase) Then
                                                               s = "/" & s
                                                           End If
                                                           Return s
                                                       End Function

        configured = NormalizeBase(configured)
        fallback = NormalizeBase(fallback)

        Dim ctx As HttpContext = HttpContext.Current
        If ctx Is Nothing OrElse ctx.Server Is Nothing Then
            Return If(String.IsNullOrWhiteSpace(fallback), "/Images/articoli/", fallback)
        End If

        Dim cacheKey As String = "ks_product_img_base"
        Dim cached As String = TryCast(ctx.Items(cacheKey), String)
        If Not String.IsNullOrWhiteSpace(cached) Then
            Return cached
        End If

        Dim candidates As New List(Of String)()
        If Not String.IsNullOrWhiteSpace(configured) Then candidates.Add(configured)

        candidates.Add("/Images/articoli/")
        candidates.Add("/images/articoli/")
        candidates.Add("/Public/Images/articoli/")
        candidates.Add("/Public/images/articoli/")
        candidates.Add("/Public/img/articoli/")
        candidates.Add("/img/articoli/")

        For Each b As String In candidates
            Dim baseUrl As String = NormalizeBase(b)
            If String.IsNullOrWhiteSpace(baseUrl) Then Continue For

            ' se non è un virtual-path locale non possiamo MapPath
            If Not baseUrl.StartsWith("/", StringComparison.Ordinal) OrElse baseUrl.StartsWith("//") Then
                Continue For
            End If

            Try
                Dim virtualPath As String = baseUrl & fileName
                Dim physical As String = ctx.Server.MapPath(virtualPath)
                If Not String.IsNullOrEmpty(physical) AndAlso System.IO.File.Exists(physical) Then
                    ctx.Items(cacheKey) = baseUrl
                    Return baseUrl
                End If
            Catch
                ' ignora e prova il prossimo
            End Try
        Next

        Dim chosen As String = If(String.IsNullOrWhiteSpace(fallback), "/Images/articoli/", fallback)
        ctx.Items(cacheKey) = chosen
        Return chosen
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
