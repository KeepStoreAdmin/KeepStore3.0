Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Text.RegularExpressions
Imports System.Web
Imports MySql.Data.MySqlClient

Partial Class condizioni_vendita
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        If Not IsPostBack Then
            Me.Title = "Condizioni Generali di Vendita"
            LoadTerms()
        End If
    End Sub

    Private Sub LoadTerms()
        Dim companyName As String = GetSessionText("AziendaNome")
        Dim termsContent As String = ""

        Try
            Dim companyId As Integer = GetCurrentCompanyId()
            Dim cs As String = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString

            Using cn As New MySqlConnection(cs)
                cn.Open()

                Using cmd As New MySqlCommand()
                    cmd.Connection = cn

                    If companyId > 0 Then
                        cmd.CommandText = "SELECT Nome, RagioneSociale, Condizioni_vendita FROM aziende WHERE Id=@id LIMIT 1"
                        cmd.Parameters.AddWithValue("@id", companyId)
                    Else
                        cmd.CommandText = "SELECT Nome, RagioneSociale, Condizioni_vendita FROM aziende WHERE (url1 LIKE @host OR url2 LIKE @host) LIMIT 1"
                        cmd.Parameters.AddWithValue("@host", "%" & GetSafeHost() & "%")
                    End If

                    Using dr As MySqlDataReader = cmd.ExecuteReader()
                        If dr.Read() Then
                            companyName = FirstNonEmpty(ReadDbText(dr, "RagioneSociale"), ReadDbText(dr, "Nome"), companyName)
                            termsContent = ReadDbText(dr, "Condizioni_vendita")
                        End If
                    End Using
                End Using
            End Using
        Catch
            termsContent = ""
        End Try

        litCompanyName.Text = HttpUtility.HtmlEncode(companyName)

        If String.IsNullOrWhiteSpace(termsContent) Then
            litTermsContent.Text = "<p class=""text-main-2"">Le Condizioni Generali di Vendita non sono momentaneamente disponibili. Per informazioni usa la pagina Contatti.</p>"
        Else
            litTermsContent.Text = SanitizeLegalHtml(termsContent)
        End If
    End Sub

    Private Function GetCurrentCompanyId() As Integer
        Dim value As Integer
        If Integer.TryParse(GetSessionText("AziendaID"), value) Then
            Return value
        End If

        Return 0
    End Function

    Private Function GetSessionText(ByVal key As String) As String
        Dim value As Object = Session(key)
        If value Is Nothing OrElse value Is DBNull.Value Then Return ""
        Return Convert.ToString(value).Trim()
    End Function

    Private Function GetSafeHost() As String
        Dim host As String = Request.Url.Host
        If String.IsNullOrWhiteSpace(host) Then Return ""

        host = host.Trim()
        If host.Length > 255 Then host = host.Substring(0, 255)

        Return host
    End Function

    Private Shared Function ReadDbText(ByVal dr As MySqlDataReader, ByVal fieldName As String) As String
        Dim ordinal As Integer = dr.GetOrdinal(fieldName)
        If dr.IsDBNull(ordinal) Then Return ""
        Return Convert.ToString(dr.GetValue(ordinal)).Trim()
    End Function

    Private Shared Function FirstNonEmpty(ParamArray ByVal values() As String) As String
        For Each value As String In values
            If Not String.IsNullOrWhiteSpace(value) Then Return value.Trim()
        Next

        Return ""
    End Function

    Private Shared Function SanitizeLegalHtml(ByVal rawValue As String) As String
        If String.IsNullOrWhiteSpace(rawValue) Then Return ""

        Dim value As String = rawValue.Trim()

        value = Regex.Replace(value, "(?is)<(script|style|iframe|object|embed|form|input|meta|link)\b[^>]*>.*?</\1>", "")
        value = Regex.Replace(value, "(?is)<(script|style|iframe|object|embed|form|input|meta|link)\b[^>]*/?>", "")
        value = Regex.Replace(value, "(?i)\s+on[a-z]+\s*=\s*(""[^""]*""|'[^']*'|[^\s>]+)", "")
        value = Regex.Replace(value, "(?i)(href|src)\s*=\s*(""|')\s*(javascript:|data:)[^""']*(""|')", "$1=""#""")
        value = Regex.Replace(value, "(?i)</?(?!p\b|br\b|ul\b|ol\b|li\b|strong\b|b\b|em\b|i\b|u\b|h[1-6]\b|a\b|span\b|div\b)[^>]+>", "")

        Return value
    End Function
End Class
