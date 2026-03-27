Imports MySql.Data.MySqlClient
Imports System.Configuration
Imports System.IO
Imports System.Web
Imports System.Web.Hosting

Partial Class UI_HomeHeroSlider
    Inherits System.Web.UI.UserControl

    Private Const PlaceholderName As String = "defaultPage"

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        ApplySlideshowVisibilityAndTrackImpression()
    End Sub

    ' ==========================================================
    ' Slideshow visibility + impression tracking
    ' (spostato da Default.aspx.vb per evitare riferimenti a controlli non presenti)
    ' ==========================================================
    Private Sub ApplySlideshowVisibilityAndTrackImpression()
        Try
            Dim cs As String = ""
            If ConfigurationManager.ConnectionStrings("EntropicConnectionString") IsNot Nothing Then
                cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
            End If

            If String.IsNullOrEmpty(cs) Then
                HeroWrap.Visible = False
                Return
            End If

            Dim aziendaId As Integer = 1
            Try
                If Context IsNot Nothing AndAlso Context.Session IsNot Nothing AndAlso Context.Session("AziendaID") IsNot Nothing Then
                    Integer.TryParse(Convert.ToString(Context.Session("AziendaID")), aziendaId)
                End If
            Catch
            End Try

            Dim visited As Boolean = False
            Dim visitedList As System.Collections.Generic.List(Of String) = Nothing

            Try
                visitedList = TryCast(Context.Session("slideshows"), System.Collections.Generic.List(Of String))
                If visitedList IsNot Nothing AndAlso visitedList.Contains(PlaceholderName) Then
                    visited = True
                End If
            Catch
            End Try

            Dim slideshowsCount As Integer = 0

            ' Verifica esistenza slideshow abilitato e nel periodo di pubblicazione
            Using conn As New MySqlConnection(cs)
                conn.Open()

                Dim sql As String = "SELECT COUNT(*) FROM slideshows " &
                                    "WHERE placeholder = @placeholder " &
                                    "AND aziendeId = @aziendaId " &
                                    "AND abilitato = 1 " &
                                    "AND dataInizioPubblicazione<=CURDATE() " &
                                    "AND dataFinePubblicazione>CURDATE()"

                ' Mantengo la logica esistente: se NON visitato, applico anche il limite impressioni
                If Not visited Then
                    sql &= " AND numeroImpressioniAttuale < limiteImpressioni"
                End If

                Using cmd As New MySqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@placeholder", PlaceholderName)
                    cmd.Parameters.AddWithValue("@aziendaId", aziendaId)
                    Dim obj As Object = cmd.ExecuteScalar()
                    If obj IsNot Nothing AndAlso Not Convert.IsDBNull(obj) Then
                        Integer.TryParse(Convert.ToString(obj), slideshowsCount)
                    End If
                End Using
            End Using

            If slideshowsCount <= 0 Then
                HeroWrap.Visible = False
                Return
            End If

            HeroWrap.Visible = True

            ' Memorizza visita placeholder in sessione
            If visitedList Is Nothing Then
                visitedList = New System.Collections.Generic.List(Of String)()
            End If

            If Not visitedList.Contains(PlaceholderName) Then
                visitedList.Add(PlaceholderName)
            End If

            Context.Session("slideshows") = visitedList

            ' Incremento impression (fail-safe)
            Try
                Using conn As New MySqlConnection(cs)
                    conn.Open()
                    Dim upd As String = "UPDATE slideshows SET numeroImpressioniAttuale = numeroImpressioniAttuale + 1 " &
                                       "WHERE placeholder = @placeholder AND aziendeId = @aziendaId"
                    Using cmd As New MySqlCommand(upd, conn)
                        cmd.Parameters.AddWithValue("@placeholder", PlaceholderName)
                        cmd.Parameters.AddWithValue("@aziendaId", aziendaId)
                        cmd.ExecuteNonQuery()
                    End Using
                End Using
            Catch
                ' non bloccare il rendering per tracking impression
            End Try

        Catch
            ' non bloccare la home
            HeroWrap.Visible = False
        End Try
    End Sub

    ' ==========================================================
    ' Encoding / URL hardening (usati nel markup del controllo)
    ' ==========================================================

    Protected Function SafeText(ByVal obj As Object) As String
        Return HttpUtility.HtmlEncode(Convert.ToString(obj))
    End Function

    Protected Function SafeAttr(ByVal obj As Object) As String
        Return HttpUtility.HtmlAttributeEncode(Convert.ToString(obj))
    End Function

    ' Consente: URL relativi (/, ~/), o assoluti http/https (solo per HREF)
    Protected Function SafeUrl(ByVal urlObj As Object) As String
        If urlObj Is Nothing OrElse Convert.IsDBNull(urlObj) Then Return ""
        Dim raw As String = Convert.ToString(urlObj).Trim()
        If raw = "" Then Return ""

        Dim lower As String = raw.ToLowerInvariant()
        If lower.StartsWith("javascript:") OrElse lower.StartsWith("data:") OrElse lower.StartsWith("vbscript:") Then
            Return ""
        End If

        If raw.StartsWith("/") OrElse raw.StartsWith("~/") Then
            Return raw
        End If

        Dim uri As Uri = Nothing
        If Uri.TryCreate(raw, UriKind.Absolute, uri) Then
            If uri.Scheme = Uri.UriSchemeHttp OrElse uri.Scheme = Uri.UriSchemeHttps Then
                Return uri.ToString()
            End If
        End If

        Return ""
    End Function

    Protected Function SlideLinkStart(ByVal linkObj As Object) As String
        Dim u As String = SafeUrl(linkObj)
        If u = "" Then Return ""

        If u.StartsWith("~/", StringComparison.Ordinal) Then
            u = ResolveUrl(u)
        End If

        Return "<a href=\"" & SafeAttr(u) & "\">"
    End Function

    Protected Function SlideLinkEnd(ByVal linkObj As Object) As String
        Dim u As String = SafeUrl(linkObj)
        If u = "" Then Return ""
        Return "</a>"
    End Function

    Private Function SafeFileNameOnly(ByVal fileObj As Object) As String
        If fileObj Is Nothing OrElse Convert.IsDBNull(fileObj) Then Return ""
        Dim s As String = Convert.ToString(fileObj).Trim()
        If s = "" Then Return ""

        s = s.Replace("\\", "/").Replace("\", "/")

        ' blocco path traversal / path assoluti
        If s.Contains("..") OrElse s.Contains(":") Then Return ""

        ' prendo solo l'ultimo segmento
        If s.Contains("/") Then
            s = s.Substring(s.LastIndexOf("/"c) + 1)
        End If

        Return s
    End Function

    Protected Function SafeSlideshowImageUrl(ByVal fileObj As Object) As String
        Dim fileName As String = SafeFileNameOnly(fileObj)
        If fileName = "" Then
            Return ResolveUrl("~/Public/images/nofoto.gif")
        End If

        Dim primaryPath As String = "~/Public/assets/images/slideshows/" & fileName
        If VirtualFileExists(primaryPath) Then
            Return ResolveUrl(primaryPath)
        End If

        Dim legacyPath As String = "~/Images/Slide_Show/" & fileName
        If VirtualFileExists(legacyPath) Then
            Return ResolveUrl(legacyPath)
        End If

        Return ResolveUrl(primaryPath)
    End Function

    Private Function VirtualFileExists(ByVal virtualPath As String) As Boolean
        Try
            Dim physicalPath As String = HostingEnvironment.MapPath(virtualPath)
            Return Not String.IsNullOrWhiteSpace(physicalPath) AndAlso File.Exists(physicalPath)
        Catch
            Return False
        End Try
    End Function

End Class
