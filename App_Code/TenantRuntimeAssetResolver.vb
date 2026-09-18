Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.IO

Public NotInheritable Class TenantRuntimeAssetResolver
    Private Const StylesRelativeRoot As String = "Public\style"
    Private Const BackgroundsRelativeRoot As String = "Public\Sfondi"
    Private Const StylesPublicRoot As String = "/Public/style/"
    Private Const BackgroundsPublicRoot As String = "/Public/Sfondi/"

    Private Shared ReadOnly StylesheetExtensions As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        ".css"
    }

    Private Shared ReadOnly BackgroundExtensions As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase) From {
        ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"
    }

    Private Sub New()
    End Sub

    Public Shared Function ResolveTenantStylesheet(ByVal configuredValue As String,
                                                   ByVal applicationRoot As String) As String
        Return ResolveConfiguredAsset(configuredValue,
                                      applicationRoot,
                                      StylesRelativeRoot,
                                      StylesPublicRoot,
                                      StylesheetExtensions)
    End Function

    Public Shared Function ResolveTenantBackground(ByVal configuredValue As String,
                                                   ByVal applicationRoot As String) As String
        Return ResolveConfiguredAsset(configuredValue,
                                      applicationRoot,
                                      BackgroundsRelativeRoot,
                                      BackgroundsPublicRoot,
                                      BackgroundExtensions)
    End Function

    Private Shared Function ResolveConfiguredAsset(ByVal configuredValue As String,
                                                   ByVal applicationRoot As String,
                                                   ByVal relativeRoot As String,
                                                   ByVal publicRoot As String,
                                                   ByVal allowedExtensions As ISet(Of String)) As String
        Try
            Dim fileName As String = Convert.ToString(configuredValue).Trim()
            If String.IsNullOrWhiteSpace(fileName) OrElse fileName.Length > 255 Then Return String.Empty
            If ContainsControlCharacter(fileName) OrElse fileName.Contains("..") OrElse
               fileName.Contains("/"c) OrElse fileName.Contains("\"c) OrElse
               fileName.Contains(":"c) OrElse Path.IsPathRooted(fileName) Then Return String.Empty
            If Not String.Equals(Path.GetFileName(fileName), fileName, StringComparison.Ordinal) Then Return String.Empty

            Dim extension As String = Path.GetExtension(fileName)
            If String.IsNullOrWhiteSpace(extension) OrElse allowedExtensions Is Nothing OrElse
               Not allowedExtensions.Contains(extension) Then Return String.Empty
            If String.IsNullOrWhiteSpace(applicationRoot) Then Return String.Empty

            Dim applicationFullPath As String = EnsureTrailingSeparator(Path.GetFullPath(applicationRoot))
            Dim authorizedRoot As String = EnsureTrailingSeparator(Path.GetFullPath(Path.Combine(applicationFullPath, relativeRoot)))
            If Not authorizedRoot.StartsWith(applicationFullPath, StringComparison.OrdinalIgnoreCase) Then Return String.Empty

            Dim candidatePath As String = Path.GetFullPath(Path.Combine(authorizedRoot, fileName))
            If Not candidatePath.StartsWith(authorizedRoot, StringComparison.OrdinalIgnoreCase) OrElse
               Not File.Exists(candidatePath) Then Return String.Empty

            Return publicRoot & Uri.EscapeDataString(fileName)
        Catch
            Return String.Empty
        End Try
    End Function

    Private Shared Function ContainsControlCharacter(ByVal value As String) As Boolean
        For Each character As Char In value
            If Char.IsControl(character) Then Return True
        Next
        Return False
    End Function

    Private Shared Function EnsureTrailingSeparator(ByVal value As String) As String
        Dim normalized As String = Convert.ToString(value).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
        Return normalized & Path.DirectorySeparatorChar
    End Function
End Class
