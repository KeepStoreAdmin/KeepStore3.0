Imports System
Imports System.Configuration
Imports System.Data
Imports System.IO
Imports System.Web
Imports System.Web.Hosting
Imports MySql.Data.MySqlClient

Partial Class SiteFooter
    Inherits System.Web.UI.UserControl

    Private Const FooterCompanyId As Integer = 1
    Private Const DefaultLogoVirtual As String = "~/Public/assets/images/logo/logo.svg"

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        BindFooterLogo()
    End Sub

    Private Sub BindFooterLogo()
        If imgFooterLogo Is Nothing Then
            Return
        End If

        Dim companyName As String = String.Empty
        Dim logoUrl As String = BuildLogoAssetUrlFromFileName(LoadFooterLogoFileName(companyName))
        If String.IsNullOrWhiteSpace(logoUrl) Then
            logoUrl = ResolveUrl(DefaultLogoVirtual)
        End If

        If Not LogoUrlExists(logoUrl) Then
            If LogoUrlExists(ResolveUrl(DefaultLogoVirtual)) Then
                logoUrl = ResolveUrl(DefaultLogoVirtual)
            Else
                imgFooterLogo.Visible = False
                Return
            End If
        End If

        imgFooterLogo.ImageUrl = logoUrl
        imgFooterLogo.AlternateText = If(String.IsNullOrWhiteSpace(companyName), "KeepStore", companyName.Trim())
        imgFooterLogo.Attributes("decoding") = "async"
    End Sub

    Private Function LoadFooterLogoFileName(ByRef companyName As String) As String
        Try
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                Using cmd As New MySqlCommand("SELECT Logo, nome AS CompanyName FROM aziende WHERE id=@companyId LIMIT 1", conn)
                    cmd.Parameters.AddWithValue("@companyId", ResolveFooterCompanyId(conn))
                    Using reader As MySqlDataReader = cmd.ExecuteReader()
                        If reader.Read() Then
                            companyName = SafeString(reader, "CompanyName")
                            Return SafeString(reader, "Logo")
                        End If
                    End Using
                End Using
            End Using
        Catch
        End Try

        If String.IsNullOrWhiteSpace(companyName) AndAlso Session IsNot Nothing Then
            companyName = Convert.ToString(Session("AziendaNome"))
        End If

        Return String.Empty
    End Function

    Private Function ResolveFooterCompanyId(ByVal conn As MySqlConnection) As Integer
        Dim companyId As Integer = 0

        If Session IsNot Nothing Then
            Integer.TryParse(Convert.ToString(Session("AziendaID")), companyId)
            If companyId > 0 Then
                Return companyId
            End If
        End If

        Try
            Dim host As String = If(Request Is Nothing OrElse Request.Url Is Nothing, String.Empty, Request.Url.Host)
            If Not String.IsNullOrWhiteSpace(host) Then
                Using cmd As New MySqlCommand("SELECT aziende.Id FROM aziende LEFT JOIN pagine ON aziende.Id=Aziendeid WHERE (url1 LIKE @dominio OR url2 LIKE @dominio) LIMIT 1", conn)
                    cmd.Parameters.AddWithValue("@dominio", "%" & host.Trim() & "%")
                    Dim raw As Object = cmd.ExecuteScalar()
                    If raw IsNot Nothing AndAlso raw IsNot DBNull.Value AndAlso Integer.TryParse(Convert.ToString(raw), companyId) AndAlso companyId > 0 Then
                        Return companyId
                    End If
                End Using
            End If
        Catch
        End Try

        Return FooterCompanyId
    End Function

    Private Function BuildLogoAssetUrlFromFileName(ByVal rawFileName As String) As String
        Dim fileName As String = SafeLogoFileName(rawFileName)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return String.Empty
        End If

        Return "/Public/assets/images/logo/" & fileName
    End Function

    Private Function SafeLogoFileName(ByVal rawFileName As String) As String
        Dim value As String = If(rawFileName, String.Empty).Trim()
        If String.IsNullOrWhiteSpace(value) Then
            Return String.Empty
        End If

        value = value.Replace("\"c, "/"c)
        Dim fileName As String = Path.GetFileName(value)
        If String.IsNullOrWhiteSpace(fileName) Then
            Return String.Empty
        End If
        If fileName.Contains("..") OrElse fileName.Contains("/") OrElse fileName.Contains("\") Then
            Return String.Empty
        End If

        Return fileName
    End Function

    Private Function LogoUrlExists(ByVal url As String) As Boolean
        If String.IsNullOrWhiteSpace(url) OrElse url.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then
            Return True
        End If

        Try
            Dim pathOnly As String = url
            Dim queryIndex As Integer = pathOnly.IndexOf("?"c)
            If queryIndex >= 0 Then
                pathOnly = pathOnly.Substring(0, queryIndex)
            End If
            If pathOnly.StartsWith("~", StringComparison.OrdinalIgnoreCase) Then
                pathOnly = ResolveUrl(pathOnly)
            End If

            Dim physical As String = HostingEnvironment.MapPath(pathOnly)
            Return Not String.IsNullOrWhiteSpace(physical) AndAlso File.Exists(physical)
        Catch
            Return False
        End Try
    End Function

    Private Function SafeString(ByVal reader As IDataRecord, ByVal fieldName As String) As String
        Try
            Dim ordinal As Integer = reader.GetOrdinal(fieldName)
            If reader.IsDBNull(ordinal) Then Return String.Empty
            Return Convert.ToString(reader.GetValue(ordinal))
        Catch
            Return String.Empty
        End Try
    End Function
End Class
