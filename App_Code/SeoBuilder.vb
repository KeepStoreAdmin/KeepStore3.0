Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Linq
Imports System.Text
Imports System.Web
Imports System.Web.Script.Serialization
Imports System.Web.UI
Imports System.Web.UI.HtmlControls
Imports System.Web.UI.WebControls

' ============================================================
' SeoBuilder.vb (App_Code)
' Helper SEO / JSON-LD / Meta / Canonical
'
' NOTE IMPORTANTI:
' - Compatibile con ASP.NET WebForms (.NET Framework 4.x / VB 2012)
' - Evita stringhe JSON "a mano": usa JavaScriptSerializer per prevenire
'   errori di quoting e garantire escape corretto.
' - Metodi pensati per essere chiamati da qualsiasi pagina (Me / Me.Page).
' ============================================================
Public NotInheritable Class SeoBuilder

    Private Sub New()
    End Sub

    ' ------------------------------------------------------------
    ' Utility: risolve Page a partire da Page/Control/qualunque ctx
    ' ------------------------------------------------------------
    Private Shared Function ResolvePage(ByVal ctx As Object) As System.Web.UI.Page
        If ctx Is Nothing Then Return Nothing

        Dim p As System.Web.UI.Page = TryCast(ctx, System.Web.UI.Page)
        If p IsNot Nothing Then Return p

        Dim c As Control = TryCast(ctx, Control)
        If c IsNot Nothing Then
            Return c.Page
        End If

        Return Nothing
    End Function

    ' ------------------------------------------------------------
    ' META: aggiunge o sostituisce <meta name="...">
    ' ------------------------------------------------------------
    Public Shared Sub AddOrReplaceMeta(ByVal ctx As Object, ByVal metaName As String, ByVal metaContent As String)
        Dim page As System.Web.UI.Page = ResolvePage(ctx)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(metaName) Then Exit Sub

        Dim existing As HtmlMeta = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim m As HtmlMeta = TryCast(ctrl, HtmlMeta)
            If m IsNot Nothing AndAlso Not String.IsNullOrEmpty(m.Name) Then
                If String.Equals(m.Name, metaName, StringComparison.OrdinalIgnoreCase) Then
                    existing = m
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlMeta()
            existing.Name = metaName
            page.Header.Controls.Add(existing)
        End If

        existing.Content = If(metaContent, String.Empty)
    End Sub

    ' ------------------------------------------------------------
    ' CANONICAL: aggiunge o sostituisce <link rel="canonical" href="...">
    ' ------------------------------------------------------------
    Public Shared Sub SetCanonical(ByVal ctx As Object, ByVal canonicalUrl As String)
        Dim page As System.Web.UI.Page = ResolvePage(ctx)
        If page Is Nothing OrElse page.Header Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(canonicalUrl) Then Exit Sub

        Dim existing As HtmlLink = Nothing
        For Each ctrl As Control In page.Header.Controls
            Dim l As HtmlLink = TryCast(ctrl, HtmlLink)
            If l IsNot Nothing Then
                Dim rel As String = Nothing
                If l.Attributes IsNot Nothing Then rel = l.Attributes("rel")
                If String.Equals(rel, "canonical", StringComparison.OrdinalIgnoreCase) Then
                    existing = l
                    Exit For
                End If
            End If
        Next

        If existing Is Nothing Then
            existing = New HtmlLink()
            existing.Attributes("rel") = "canonical"
            page.Header.Controls.Add(existing)
        End If

        existing.Href = canonicalUrl
    End Sub

    ' ------------------------------------------------------------
    ' JSON escaping (se serve in vecchi punti del codice)
    ' Implementato usando JavaScriptSerializer per affidabilità.
    ' Restituisce la stringa SENZA doppi apici esterni.
    ' ------------------------------------------------------------
    Public Shared Function JsonEscape(ByVal value As String) As String
        If value Is Nothing Then Return String.Empty
        Dim js As New JavaScriptSerializer()
        Dim quoted As String = js.Serialize(value) ' -> "...."
        If String.IsNullOrEmpty(quoted) Then Return String.Empty

        If quoted.Length >= 2 AndAlso quoted(0) = """"c AndAlso quoted(quoted.Length - 1) = """"c Then
            Return quoted.Substring(1, quoted.Length - 2)
        End If

        Return quoted
    End Function

    ' ------------------------------------------------------------
    ' JSON-LD: WebPage semplice (usato da carrello/checkout/contatti/privacy...)
    ' schemaType opzionale (es. "CheckoutPage", "ContactPage", "FAQPage"...)
    ' ------------------------------------------------------------
    Public Shared Function BuildSimplePageJsonLd(ByVal pageTitle As String,
                                                ByVal descr As String,
                                                ByVal canonicalUrl As String,
                                                Optional ByVal schemaType As String = "WebPage") As String

        Dim obj As New Dictionary(Of String, Object)(StringComparer.OrdinalIgnoreCase)
        obj("@context") = "https://schema.org"
        obj("@type") = If(String.IsNullOrWhiteSpace(schemaType), "WebPage", schemaType)
        obj("name") = If(pageTitle, String.Empty)
        obj("url") = If(canonicalUrl, String.Empty)

        If Not String.IsNullOrWhiteSpace(descr) Then
            obj("description") = descr
        End If

        Dim js As New JavaScriptSerializer()
        Return js.Serialize(obj)
    End Function

    ' ------------------------------------------------------------
    ' JSON-LD: inietta nel Master se presente, altrimenti nel <head>
    '
    ' Strategie:
    ' 1) Se MasterPage ha proprietà "SeoJsonLd" (string), la valorizza via reflection.
    ' 2) Se esiste Literal con ID "litSeoJsonLd", scrive lo script lì.
    ' 3) Fallback: aggiunge Literal in page.Header.
    ' ------------------------------------------------------------
    Public Shared Sub ApplyJsonLd(ByVal ctx As Object, ByVal jsonLd As String)
        Dim page As System.Web.UI.Page = ResolvePage(ctx)
        If page Is Nothing Then Exit Sub
        If String.IsNullOrWhiteSpace(jsonLd) Then Exit Sub

        Dim scriptTag As String = "<script type=""application/ld+json"">" & jsonLd & "</script>"

        ' 1) property SeoJsonLd su Master (reflection)
        Try
            If page.Master IsNot Nothing Then
                Dim pi = page.Master.GetType().GetProperty("SeoJsonLd")
                If pi IsNot Nothing AndAlso pi.CanWrite AndAlso pi.PropertyType Is GetType(String) Then
                    pi.SetValue(page.Master, jsonLd, Nothing)
                    Exit Sub
                End If
            End If
        Catch
            ' ignore
        End Try

        ' 2) Literal litSeoJsonLd nel Master
        Dim lit As Literal = Nothing
        Try
            If page.Master IsNot Nothing Then
                lit = TryCast(FindControlRecursive(page.Master, "litSeoJsonLd"), Literal)
            End If
        Catch
            lit = Nothing
        End Try

        If lit IsNot Nothing Then
            lit.Text = scriptTag
            Exit Sub
        End If

        ' 3) Fallback in <head>
        If page.Header IsNot Nothing Then
            page.Header.Controls.Add(New Literal() With {.Text = scriptTag})
        End If
    End Sub

    ' ------------------------------------------------------------
    ' Ricerca controllo ricorsiva (utile per Master / template)
    ' ------------------------------------------------------------
    Public Shared Function FindControlRecursive(ByVal root As Control, ByVal id As String) As Control
        If root Is Nothing OrElse String.IsNullOrEmpty(id) Then Return Nothing

        Dim found As Control = root.FindControl(id)
        If found IsNot Nothing Then Return found

        For Each c As Control In root.Controls
            found = FindControlRecursive(c, id)
            If found IsNot Nothing Then Return found
        Next

        Return Nothing
    End Function

    ' ------------------------------------------------------------
    ' Compatibilità: metodi "storici" che alcune pagine potrebbero chiamare.
    ' (Non fanno danni se non usati.)
    ' ------------------------------------------------------------
    Public Shared Sub ApplyHomeSeo(ByVal ctx As Object)
        ' Stub di compatibilità: mantenuto per evitare errori se qualche pagina legacy lo richiama.
        ' La HOME può gestire SEO/JSON-LD direttamente nel code-behind e poi chiamare ApplyJsonLd.
    End Sub

End Class
