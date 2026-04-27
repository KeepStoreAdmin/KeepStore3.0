Imports System
Imports System.Configuration
Imports System.Data
Imports System.Globalization
Imports MySql.Data.MySqlClient
Imports System.Web.UI.WebControls

Partial Class MiniCart
    Inherits System.Web.UI.UserControl

    ' 1 = prezzi + IVA (netto), 2 = prezzi IVA inclusa (ivato)
    Private _ivaTipo As Integer = 2

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As EventArgs) Handles Me.PreRender
        BindMiniCartSafe()
    End Sub

    Protected Sub rptMiniCart_ItemCommand(ByVal sender As Object, ByVal e As RepeaterCommandEventArgs)
        If String.Equals(e.CommandName, "Remove", StringComparison.OrdinalIgnoreCase) Then
            Dim id As Integer = 0
            Integer.TryParse(Convert.ToString(e.CommandArgument), id)
            If id > 0 Then
                DeleteCartRow(id)
            End If
        End If
    End Sub

    Protected Sub lbClearCart_Click(ByVal sender As Object, ByVal e As EventArgs)
        ClearCart()
    End Sub

    Private Sub BindMiniCartSafe()
        Try
            BindMiniCart()
        Catch
            ' Fail-safe: non bloccare mai il rendering dell'header
            Try
                lblCarrelloCount.Text = "0"
                lblCarrelloTotale.Text = "0,00"
                lblMiniCartTotale.Text = "0,00"
                phMiniCartEmpty.Visible = True
                phMiniCartList.Visible = False
            Catch
            End Try
        End Try
    End Sub

    Private Sub BindMiniCart()
        Dim loginId As Integer = GetLoginIdSafe()
        Dim sessionId As String = GetSessionIdSafe()
        _ivaTipo = GetIvaTipoSafe()

        Dim dt As DataTable = LoadItems(loginId, sessionId)

        Dim qty As Integer = 0
        Dim total As Decimal = 0D

        If dt IsNot Nothing AndAlso dt.Rows.Count > 0 Then
            For Each r As DataRow In dt.Rows
                qty += SafeInt(r("Qnt"), 0)
                total += SafeDec(If(_ivaTipo = 1, r("Importo"), r("ImportoIvato")), 0D)
            Next
        End If

        lblCarrelloCount.Text = qty.ToString()
        lblCarrelloTotale.Text = total.ToString("N2")
        lblMiniCartTotale.Text = total.ToString("N2")

        If qty <= 0 OrElse dt Is Nothing OrElse dt.Rows.Count = 0 Then
            phMiniCartEmpty.Visible = True
            phMiniCartList.Visible = False
            Return
        End If

        phMiniCartEmpty.Visible = False
        phMiniCartList.Visible = True

        rptMiniCart.DataSource = dt
        rptMiniCart.DataBind()
    End Sub

    Private Function LoadItems(ByVal loginId As Integer, ByVal sessionId As String) As DataTable
        Dim dt As New DataTable()
        Dim connStr As String = GetConnectionString()
        If String.IsNullOrEmpty(connStr) Then Return dt

        Try
            Using cn As New MySqlConnection(connStr)
                cn.Open()

                Dim sql As String = "SELECT id, ArticoliId, TCId, Descrizione1, Qnt, Img1, Prezzo, PrezzoIvato, Importo, ImportoIvato " &
                                    "FROM vcarrello WHERE "

                Using cmd As New MySqlCommand()
                    cmd.Connection = cn

                    If loginId > 0 Then
                        sql &= "LoginId=@loginId "
                        cmd.Parameters.AddWithValue("@loginId", loginId)
                    Else
                        sql &= "SessionId=@sessionId "
                        cmd.Parameters.AddWithValue("@sessionId", sessionId)
                    End If

                    sql &= "ORDER BY id DESC LIMIT 10"
                    cmd.CommandText = sql

                    Using adp As New MySqlDataAdapter(cmd)
                        adp.Fill(dt)
                    End Using
                End Using
            End Using
        Catch
            ' best-effort
        End Try

        Return dt
    End Function

    Private Sub DeleteCartRow(ByVal id As Integer)
        Dim connStr As String = GetConnectionString()
        If String.IsNullOrEmpty(connStr) Then Exit Sub

        Dim loginId As Integer = GetLoginIdSafe()
        Dim sessionId As String = GetSessionIdSafe()

        Try
            Using cn As New MySqlConnection(connStr)
                cn.Open()

                Dim sql As String
                Using cmd As New MySqlCommand()
                    cmd.Connection = cn

                    If loginId > 0 Then
                        sql = "DELETE FROM carrello WHERE id=@id AND LoginId=@loginId"
                        cmd.Parameters.AddWithValue("@loginId", loginId)
                    Else
                        sql = "DELETE FROM carrello WHERE id=@id AND SessionId=@sessionId"
                        cmd.Parameters.AddWithValue("@sessionId", sessionId)
                    End If

                    cmd.Parameters.AddWithValue("@id", id)
                    cmd.CommandText = sql
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch
            ' best-effort
        End Try
    End Sub

    Private Sub ClearCart()
        Dim connStr As String = GetConnectionString()
        If String.IsNullOrEmpty(connStr) Then Exit Sub

        Dim loginId As Integer = GetLoginIdSafe()
        Dim sessionId As String = GetSessionIdSafe()

        Try
            Using cn As New MySqlConnection(connStr)
                cn.Open()

                Dim sql As String
                Using cmd As New MySqlCommand()
                    cmd.Connection = cn

                    If loginId > 0 Then
                        sql = "DELETE FROM carrello WHERE LoginId=@loginId"
                        cmd.Parameters.AddWithValue("@loginId", loginId)
                    Else
                        sql = "DELETE FROM carrello WHERE SessionId=@sessionId"
                        cmd.Parameters.AddWithValue("@sessionId", sessionId)
                    End If

                    cmd.CommandText = sql
                    cmd.ExecuteNonQuery()
                End Using
            End Using
        Catch
            ' best-effort
        End Try
    End Sub

    ' ------------------------------------------------------------
    ' Binding helpers (usati nel markup)
    ' ------------------------------------------------------------
    Public Function GetProductUrl(ByVal articoliIdObj As Object, ByVal tcIdObj As Object) As String
        Dim id As Integer = SafeInt(articoliIdObj, 0)
        Dim tc As Integer = SafeInt(tcIdObj, -1)

        If id <= 0 Then
            Return ResolveUrl("~/articoli.aspx")
        End If

        Dim url As String = "~/articolo.aspx?id=" & id.ToString()
        If tc >= 0 Then
            url &= "&TCid=" & tc.ToString()
        End If

        Return ResolveUrl(url)
    End Function

    Public Function GetProductImg(ByVal imgObj As Object) As String
        Dim s As String = If(imgObj Is Nothing OrElse imgObj Is DBNull.Value, "", Convert.ToString(imgObj))
        s = If(s, "").Trim()

        If Not String.IsNullOrEmpty(s) Then
            s = s.Replace("\", "/")
            Dim fileName As String = IO.Path.GetFileName(s)
            If Not String.IsNullOrWhiteSpace(fileName) Then
                Return ResolveUrl("~/Public/assets/images/articoli/" & fileName)
            End If
        End If

        Return ThemeManager.PlaceholderProductImageUrl()
    End Function

    Public Function GetLineTotalText(ByVal importoObj As Object, ByVal importoIvatoObj As Object) As String
        Dim v As Decimal = If(_ivaTipo = 1, SafeDec(importoObj, 0D), SafeDec(importoIvatoObj, 0D))
        Return FormatCurrency(v)
    End Function

    Private Function FormatCurrency(ByVal amount As Decimal) As String
        Try
            Return String.Format(CultureInfo.GetCultureInfo("it-IT"), "{0:C}", amount)
        Catch
            Return amount.ToString("N2")
        End Try
    End Function

    ' ------------------------------------------------------------
    ' Safe helpers
    ' ------------------------------------------------------------
    Private Function GetConnectionString() As String
        Try
            Dim cs = ConfigurationManager.ConnectionStrings("EntropicConnectionString")
            If cs IsNot Nothing Then
                Return cs.ConnectionString
            End If
        Catch
        End Try
        Return String.Empty
    End Function

    Private Function GetLoginIdSafe() As Integer
        Dim loginIdVal As Integer = 0

        Try
            Dim o As Object = Session("LoginId")
            If o IsNot Nothing AndAlso Integer.TryParse(o.ToString(), loginIdVal) AndAlso loginIdVal > 0 Then
                Return loginIdVal
            End If
        Catch
        End Try

        Try
            Dim o As Object = Session("LoginID")
            If o IsNot Nothing AndAlso Integer.TryParse(o.ToString(), loginIdVal) AndAlso loginIdVal > 0 Then
                Return loginIdVal
            End If
        Catch
        End Try

        Return 0
    End Function

    Private Function GetSessionIdSafe() As String
        Try
            If Context IsNot Nothing AndAlso Context.Session IsNot Nothing Then
                Return Context.Session.SessionID
            End If
        Catch
        End Try

        Return String.Empty
    End Function

    Private Function GetIvaTipoSafe() As Integer
        Dim iva As Integer = 2
        Try
            Dim o As Object = Session("IvaTipo")
            If o IsNot Nothing AndAlso Integer.TryParse(o.ToString(), iva) Then
                If iva = 1 OrElse iva = 2 Then Return iva
            End If
        Catch
        End Try
        Return 2
    End Function

    Private Function SafeInt(ByVal o As Object, Optional ByVal defaultValue As Integer = 0) As Integer
        If o Is Nothing OrElse o Is DBNull.Value Then Return defaultValue
        Dim v As Integer
        If Integer.TryParse(o.ToString(), v) Then Return v
        Return defaultValue
    End Function

    Private Function SafeDec(ByVal o As Object, Optional ByVal defaultValue As Decimal = 0D) As Decimal
        If o Is Nothing OrElse o Is DBNull.Value Then Return defaultValue

        Dim d As Decimal
        If Decimal.TryParse(o.ToString(), NumberStyles.Any, CultureInfo.InvariantCulture, d) Then
            Return d
        End If

        If Decimal.TryParse(o.ToString(), NumberStyles.Any, CultureInfo.GetCultureInfo("it-IT"), d) Then
            Return d
        End If

        Return defaultValue
    End Function

End Class
