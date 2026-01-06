' BESTSHOPPING CHECKOUT TRACKER GENERIC MERCHANT CLIENT SIDE ASP CODE
' @author Pointer srl <info@pointer.it>
' @copyright Copyright (c) 2007-2011, Pointer S.r.l.
' @version v1.2.1 - 20/02/2008

'******************* CODICE CHECKOUT TRACKER NON MODIFICARE ********************

Public Class OB_image_bestshopping
    Inherits System.Web.UI.Page

    Public Const IMAGE_URL As String = "http://tracker.bestshopping.com/save_checkout.php"
    Public Const MAX_URL_LENGTH As Integer = 2048
    Public Const DATA_KEY As String = "b1bf957bd1e598fa860d9a634f15eeac"

    Private crc32Table(255)

    Public Sub New()

    End Sub

    Public Function WriteImage(ByRef prod, ByVal order_num, ByVal shipping) As String
        Dim i, tid_bs, id_articolo, prezzo, num_pezzi, loop_end, url_img
        Dim items()

        WriteImage = ""
        If Not HttpContext.Current.Request.Cookies("tid_bs") Is Nothing Then
            tid_bs = HttpContext.Current.Server.HtmlEncode(HttpContext.Current.Request.Cookies("tid_bs").Value)
        Else
            Exit Function
        End If

        shipping = Replace(shipping, ",", ".")

        ReDim items(UBound(prod))
        For i = 0 To UBound(prod) - 1
            id_articolo = prod(i, 0)
            prezzo = prod(i, 1)
            num_pezzi = prod(i, 2)

            items(i) = "&id[" & i & "]=" & Encrypt(id_articolo) & "&pr[" & i & "]=" & Encrypt(Replace(prezzo, ",", ".")) & "&qt[" & i & "]=" & Encrypt(num_pezzi)
        Next

        ' writing url image, if url > MAX_URL_LENGTH then write multiple url images
        '  each not exceding the MAX_URL_LENGTH
        loop_end = False
        i = 0
        Do
            url_img = IMAGE_URL & "?tid_bs=" & tid_bs & "&tr=" & Encrypt(order_num) & "&sc=" & Encrypt(shipping)
            Do While Not loop_end
                If (i < UBound(items)) Then
                    If (MAX_URL_LENGTH - Len(url_img) >= Len(items(i))) Then
                        url_img = url_img & items(i)
                        i = i + 1
                    Else
                        Exit Do
                    End If
                Else
                    loop_end = True
                End If
            Loop
            WriteImage = WriteImage & "<img src=""" & url_img & """ width=""1"" height=""1"" border=""0"">"
        Loop While Not loop_end
    End Function

    Private Function Encrypt(ByVal str As String) As String
        Dim key, i
        Dim s()
        Dim k()
        Dim c()

        ' apending the crc32 to the string prior to encrypting
        str = crc32(str) & str

        key = DATA_KEY
        ReDim s(Len(str))
        ReDim k(Len(str))
        ReDim c(Len(str))
        Do While (Len(str) > Len(key))
            key = key & key
        Loop
        key = Mid(key, 1, Len(str))
        For i = 0 To Len(str) - 1
            s(i) = Mid(str, i + 1, 1)
            k(i) = Mid(key, i + 1, 1)
        Next
        Encrypt = ""
        For i = 0 To UBound(s) - 1
            c(i) = Asc(s(i)) Xor Asc(k(i))
            Encrypt = Encrypt & Right(New String("0", 2) & Hex(c(i)), 2)
        Next
        Encrypt = LCase(Encrypt)
    End Function

    Public Function crc32(ByVal str As String) As String
        Dim lCRC32
        ' turn on error trapping but do nothing
        On Error Resume Next
        lCRC32 = InitCRC32()
        ' computing crc32 and padding to 8 digit hex number
        crc32 = LCase(Right(New String("0", 8) & Hex(CalcCRC32(str, lCRC32)), 8))
    End Function

    Public Function InitCRC32() As Integer
        Dim iBytes, iBits, lCRC32, lTempCRC32, Seed
        Seed = &HEDB88320
        ' turn on error trapping but do nothing
        On Error Resume Next

        For iBytes = 0 To 255
            ' initiate lCRC32 to counter variable
            lCRC32 = iBytes

            ' now iterate through each bit in counter byte
            For iBits = 0 To 7
                ' right shift unsigned long 1 bit
                lTempCRC32 = lCRC32 And &HFFFFFFFE
                lTempCRC32 = lTempCRC32 \ &H2
                lTempCRC32 = lTempCRC32 And &H7FFFFFFF

                ' now check if temporary is less than zero and then
                '  mix crc32 checksum with Seed value
                If (lCRC32 And &H1) <> 0 Then
                    lCRC32 = lTempCRC32 Xor Seed
                Else
                    lCRC32 = lTempCRC32
                End If
            Next

            ' put crc32 checksum value in the holding array
            crc32Table(iBytes) = lCRC32
        Next

        InitCRC32 = &HFFFFFFFF
    End Function

    Public Function CalcCRC32(ByVal str As String, ByVal crc32 As Integer) As Integer
        Dim bCharValue, lIndex, i
        Dim lAccValue, lTableValue
        ' turn on error trapping but do nothing
        On Error Resume Next

        ' iterate through the string that is to be checksum-computed
        For i = 1 To Len(str)

            ' get ASCII value for the current char
            bCharValue = Asc(Mid(str, i, 1))

            ' right shift an unsigned long 8 bits
            lAccValue = crc32 And &HFFFFFF00
            lAccValue = lAccValue \ &H100
            lAccValue = lAccValue And &HFFFFFF

            ' now select the right adding value from the holding table
            lIndex = crc32 And &HFF
            lIndex = lIndex Xor bCharValue
            lTableValue = crc32Table(lIndex)

            ' then mix new crc32 value with previous accumulated crc32 value
            crc32 = lAccValue Xor lTableValue
        Next

        ' Set function to the new crc32 value
        CalcCRC32 = crc32 Xor &HFFFFFFFF
    End Function

End Class
'******************* CODICE CHECKOUT TRACKER NON MODIFICARE ********************