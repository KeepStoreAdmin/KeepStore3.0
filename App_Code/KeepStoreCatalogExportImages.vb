Option Strict On
Option Explicit On

Imports System
Imports System.Drawing
Imports System.Drawing.Drawing2D
Imports System.Drawing.Imaging
Imports System.Globalization
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Web
Imports System.Web.Hosting

' Foto del listino (CATALOG-DOWNLOAD-1A): solo FILE LOCALI JPEG/PNG nella cartella delle foto articolo, mai indirizzi esterni, data URI ne SVG.
' Si usa la miniatura "_nome" se esiste; altrimenti l'originale ridotto a 180 px (JPEG) con una copia su disco in App_Data, cosi la seconda
' generazione non ridimensiona di nuovo. Ogni errore (file mancante, corrotto, troppo grande) restituisce Nothing: il listino lascia la casella vuota.
Public NotInheritable Class CatalogExportImages
    Private Sub New()
    End Sub

    Private Const BaseUrl As String = "/Public/assets/images/articoli/"
    Private Const LogoUrl As String = "/Public/assets/images/logo/"
    Private Const MaxSourceBytes As Long = 8L * 1024L * 1024L
    Private Const ThumbSide As Integer = 180
    Private Const ReadyThumbMaxBytes As Long = 48L * 1024L

    ' Restituisce i byte JPEG/PNG pronti da incorporare, oppure Nothing.
    Public Shared Function LoadThumbnail(ByVal rawName As String) As Byte()
        Return LoadThumbnail(rawName, True)
    End Function

    ' allowResize = False: si usano solo miniature gia pronte o in cache (il tempo di generazione e esaurito).
    Public Shared Function LoadThumbnail(ByVal rawName As String, ByVal allowResize As Boolean) As Byte()
        Try
            Dim name As String = SafeFileName(rawName)
            If String.IsNullOrEmpty(name) Then Return Nothing
            Dim baseDir As String = BaseDirectory()
            If String.IsNullOrEmpty(baseDir) Then Return Nothing

            Dim thumbName As String = If(name.StartsWith("_", StringComparison.Ordinal), name, "_" & name)
            Dim thumbPath As String = Contained(baseDir, thumbName)
            If thumbPath IsNot Nothing AndAlso File.Exists(thumbPath) Then
                Dim ready As Byte() = ReadSmall(thumbPath)
                If ready IsNot Nothing Then Return ready
            End If

            Dim originalPath As String = Contained(baseDir, name)
            If originalPath Is Nothing OrElse Not File.Exists(originalPath) Then Return Nothing
            Dim info As New FileInfo(originalPath)
            If info.Length <= 0L OrElse info.Length > MaxSourceBytes Then Return Nothing

            Dim cachePath As String = CacheFile(info)
            If cachePath IsNot Nothing AndAlso File.Exists(cachePath) Then
                Return File.ReadAllBytes(cachePath)
            End If

            If Not allowResize Then Return Nothing
            Dim jpeg As Byte() = Shrink(originalPath, ThumbSide, 72L)
            If jpeg Is Nothing Then Return Nothing
            If cachePath IsNot Nothing Then
                Try
                    Dim temp As String = cachePath & "." & Guid.NewGuid().ToString("N") & ".tmp"
                    File.WriteAllBytes(temp, jpeg)
                    If File.Exists(cachePath) Then
                        File.Delete(temp)
                    Else
                        File.Move(temp, cachePath)
                    End If
                Catch
                End Try
            End If
            Return jpeg
        Catch
            Return Nothing
        End Try
    End Function

    ' Logo aziendale (solo file PNG/JPG nella cartella dei loghi del sito, ridotto a 420 px): Nothing se non disponibile (SVG/WebP non si incorporano).
    Public Shared Function LoadLogo(ByVal rawName As String) As Byte()
        Try
            Dim name As String = SafeFileName(rawName)
            If String.IsNullOrEmpty(name) Then Return Nothing
            Dim physical As String = HostingEnvironment.MapPath("~" & LogoUrl)
            If String.IsNullOrWhiteSpace(physical) Then Return Nothing
            Dim baseDir As String = Path.GetFullPath(physical)
            If Not baseDir.EndsWith(Path.DirectorySeparatorChar.ToString(), StringComparison.Ordinal) Then baseDir &= Path.DirectorySeparatorChar
            Dim full As String = Contained(baseDir, name)
            If full Is Nothing OrElse Not File.Exists(full) Then Return Nothing
            Dim info As New FileInfo(full)
            If info.Length <= 0L OrElse info.Length > 4L * 1024L * 1024L Then Return Nothing
            Return Shrink(full, 420, 85L)
        Catch
            Return Nothing
        End Try
    End Function

    ' Nome file semplice: nessun percorso, nessun "..", solo jpg/jpeg/png e caratteri comuni.
    Friend Shared Function SafeFileName(ByVal raw As String) As String
        If String.IsNullOrWhiteSpace(raw) Then Return ""
        Dim decoded As String = raw.Trim()
        Try
            decoded = Uri.UnescapeDataString(decoded)
        Catch
            Return ""
        End Try
        If decoded.IndexOf("://", StringComparison.Ordinal) >= 0 OrElse decoded.StartsWith("data:", StringComparison.OrdinalIgnoreCase) Then Return ""
        decoded = decoded.Replace("\"c, "/"c)
        If decoded.IndexOf("..", StringComparison.Ordinal) >= 0 Then Return ""
        Dim name As String = Path.GetFileName(decoded)
        If String.IsNullOrWhiteSpace(name) OrElse name.IndexOf("/"c) >= 0 OrElse name.Length > 150 Then Return ""
        Dim ext As String = Path.GetExtension(name).ToLowerInvariant()
        If ext <> ".jpg" AndAlso ext <> ".jpeg" AndAlso ext <> ".png" Then Return ""
        For Each ch As Char In name
            If Not (Char.IsLetterOrDigit(ch) OrElse ch = "."c OrElse ch = "_"c OrElse ch = "-"c OrElse ch = " "c OrElse ch = "("c OrElse ch = ")"c) Then Return ""
        Next
        Return name
    End Function

    Private Shared Function BaseDirectory() As String
        Dim physical As String = HostingEnvironment.MapPath("~" & BaseUrl)
        If String.IsNullOrWhiteSpace(physical) Then Return ""
        Dim full As String = Path.GetFullPath(physical)
        If Not full.EndsWith(Path.DirectorySeparatorChar.ToString(), StringComparison.Ordinal) Then full &= Path.DirectorySeparatorChar
        Return full
    End Function

    Private Shared Function Contained(ByVal baseDir As String, ByVal name As String) As String
        Dim candidate As String = Path.GetFullPath(Path.Combine(baseDir, name))
        If Not candidate.StartsWith(baseDir, StringComparison.OrdinalIgnoreCase) Then Return Nothing
        Return candidate
    End Function

    ' Miniatura gia pronta: la si incorpora cosi com'e solo se e piccola e decodificabile.
    Private Shared Function ReadSmall(ByVal path As String) As Byte()
        Dim info As New FileInfo(path)
        If info.Length <= 0L OrElse info.Length > ReadyThumbMaxBytes Then Return Nothing
        Dim bytes As Byte() = File.ReadAllBytes(path)
        Try
            Using ms As New MemoryStream(bytes)
                Using img As Image = Image.FromStream(ms, False, True)
                    If img.Width <= 0 OrElse img.Height <= 0 OrElse img.Width > 600 OrElse img.Height > 600 Then Return Nothing
                End Using
            End Using
        Catch
            Return Nothing
        End Try
        Return bytes
    End Function

    Private Shared Function CacheFile(ByVal info As FileInfo) As String
        Try
            Dim dir As String = HostingEnvironment.MapPath("~/App_Data/CatalogExportThumbs")
            If String.IsNullOrWhiteSpace(dir) Then Return Nothing
            Directory.CreateDirectory(dir)
            Dim key As String = info.Name.ToLowerInvariant() & "|" & info.Length.ToString(CultureInfo.InvariantCulture) & "|" &
                info.LastWriteTimeUtc.Ticks.ToString(CultureInfo.InvariantCulture) & "|" & ThumbSide.ToString(CultureInfo.InvariantCulture)
            Using sha As SHA1 = SHA1.Create()
                Dim hash As Byte() = sha.ComputeHash(Encoding.UTF8.GetBytes(key))
                Return Path.Combine(dir, BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant() & ".jpg")
            End Using
        Catch
            Return Nothing
        End Try
    End Function

    ' Riduzione con GDI+: stesso rapporto, fondo bianco (PNG trasparenti), JPEG qualita 72.
    Private Shared Function Shrink(ByVal path As String, ByVal side As Integer, ByVal quality As Long) As Byte()
        Try
            Dim bytes As Byte() = File.ReadAllBytes(path)
            Using source As New MemoryStream(bytes)
                Using original As Image = Image.FromStream(source, False, True)
                    If original.Width <= 0 OrElse original.Height <= 0 OrElse original.Width > 12000 OrElse original.Height > 12000 Then Return Nothing
                    Dim scale As Double = Math.Min(1.0R, CDbl(side) / CDbl(Math.Max(original.Width, original.Height)))
                    Dim w As Integer = Math.Max(1, CInt(Math.Round(original.Width * scale)))
                    Dim h As Integer = Math.Max(1, CInt(Math.Round(original.Height * scale)))
                    Using target As New Bitmap(w, h, PixelFormat.Format24bppRgb)
                        Using g As Graphics = Graphics.FromImage(target)
                            g.Clear(Color.White)
                            g.InterpolationMode = InterpolationMode.HighQualityBicubic
                            g.SmoothingMode = SmoothingMode.HighQuality
                            g.PixelOffsetMode = PixelOffsetMode.HighQuality
                            g.DrawImage(original, 0, 0, w, h)
                        End Using
                        Dim codec As ImageCodecInfo = Nothing
                        For Each c As ImageCodecInfo In ImageCodecInfo.GetImageEncoders()
                            If c.MimeType = "image/jpeg" Then codec = c : Exit For
                        Next
                        If codec Is Nothing Then Return Nothing
                        Using parameters As New EncoderParameters(1)
                            parameters.Param(0) = New EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality)
                            Using output As New MemoryStream()
                                target.Save(output, codec, parameters)
                                Return output.ToArray()
                            End Using
                        End Using
                    End Using
                End Using
            End Using
        Catch
            Return Nothing
        End Try
    End Function
End Class
