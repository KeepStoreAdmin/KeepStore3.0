Imports System.Net
Imports System.IO
Imports System.Xml

Partial Class icecat
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim risultato As String
        Dim url_esterno As String = ""
        Dim tmp_XML As String = ""

        Dim ean As String = Request.QueryString("ean")

        url_esterno = "http://data.icecat.biz/xml_s3/xml_server3.cgi?ean_upc=" & ean & ";lang=it;output=productxml"

        Dim uri As New Uri(url_esterno)
        Dim myCredenziali As New CredentialCache()
        myCredenziali.Add(New Uri(url_esterno), "Basic", New NetworkCredential("entropic", "entropic"))

        If (uri.Scheme = uri.UriSchemeHttp) Then
            Dim request As HttpWebRequest = HttpWebRequest.Create(uri)
            request.Credentials = myCredenziali
            request.Method = WebRequestMethods.Http.Get
            Dim risposta As HttpWebResponse = request.GetResponse()
            Dim reader As New StreamReader(risposta.GetResponseStream())
            tmp_XML = reader.ReadToEnd()
            risposta.Close()
        End If

        'Lettura del file XML
        Dim Doc As XmlDocument = New XmlDocument
        Doc.LoadXml(tmp_XML)

        'Stile Css Tabella
        risultato = "<style type=""text/css"">" & _
        "#icecat td { border-style:solid; border-width:1px; border-color:black; }" & _
        "#categoria { text-align:left; vertical-align:top; color:black; font-size:14pt; font-weight:bold; padding:5px; }" & _
        "#caratteristiche td { border-style:none; border-width:0px; background-color:#adadad; color:black; padding:5px; }" & _
        "</style>"
        'risultato = "<style type=""text/css"">" & _
        '        "#icecat td { border-style:solid; border-width:1px; border-color:black; }" & _
        '        "#categoria { text-align:left; vertical-align:top; background-color:#d7130e; color:white; font-size:14pt; font-weight:bold; padding:5px; }" & _
        '        "#caratteristiche td { border-style:none; border-width:0px; background-color:#e2e2e2; padding:5px; }" & _
        '        "</style>"

        If Doc.SelectNodes("/ICECAT-interface/Product/Category").Count > 0 Then

            risultato = risultato & "<div style=""margin:auto;"">"
            risultato = risultato & "<table id=""icecat"" style=""width:660px; margin:auto; font-size:10pt; border-spacing:0px; border-collapse:collapse;"">"
            risultato = risultato & "<tr><td colspan=""2"">"

            Dim lista_categorie As XmlNodeList
            'Foto Grande
            risultato = risultato & "<img src=" & Doc.SelectNodes("/ICECAT-interface/Product").Item(0).Attributes("HighPic").InnerText & " style=""height=120px; border-color:red; border-style:solid; border-width:2px;"" />"
            'Miniature
            Dim tmp_altre_foto_list As XmlNodeList = Doc.SelectNodes("/ICECAT-interface/Product/ProductGallery/ProductPicture")
            Dim tmp_altre_foto As XmlNode
            If tmp_altre_foto_list.Count > 0 Then
                For Each tmp_altre_foto In tmp_altre_foto_list
                    risultato = risultato & "<img src=" & tmp_altre_foto.Attributes("Pic").InnerText & " style=""height=120px;"" />"
                Next
            End If

            risultato = risultato & "</td></tr>"

            risultato = risultato & "<tr><td colspan=""2"" style=""text-align:center;"">"
            'Titolo
            risultato = risultato & "<span style=""font-size:18pt; font-weight:bold;"">" & Doc.SelectNodes("/ICECAT-interface/Product").Item(0).Attributes("Title").InnerText & "</span>"
            risultato = risultato & "</td></tr>"

            risultato = risultato & "<tr><td colspan=""2"">"
            risultato = risultato & "<span>" & "Descrizione Breve -> " & Doc.SelectSingleNode("/ICECAT-interface/Product/SummaryDescription/ShortSummaryDescription").InnerText & "</span>"
            risultato = risultato & "</td></tr>"
            risultato = risultato & "<tr><td colspan=""2"">"
            risultato = risultato & "<span>" & "Descrizione Lunga -> " & Doc.SelectSingleNode("/ICECAT-interface/Product/SummaryDescription/LongSummaryDescription").InnerText & "</span>"
            risultato = risultato & "</td></tr>"

            lista_categorie = Doc.SelectNodes("/ICECAT-interface/Product/CategoryFeatureGroup")

            Dim tmp_categoria As XmlNode
            For Each tmp_categoria In lista_categorie
                Dim id_categoria As Integer = 0
                id_categoria = tmp_categoria.Attributes("ID").InnerText

                Dim lista_caratteristiche As XmlNodeList
                lista_caratteristiche = Doc.SelectNodes("/ICECAT-interface/Product/ProductFeature[@CategoryFeatureGroup_ID='" & id_categoria & "']")

                If lista_caratteristiche.Count > 0 Then 'Controllo se ci sono delle caratteristiche per la categoria selezionata
                    risultato = risultato & "<tr><td id=""categoria"">"
                    risultato = risultato & "<span>" & tmp_categoria.SelectSingleNode("FeatureGroup/Name").Attributes("Value").InnerText & "</span>"
                    risultato = risultato & "</td><td>"
                    risultato = risultato & "<table id=""caratteristiche"">"
                    Dim tmp_caratteristica As XmlNode
                    For Each tmp_caratteristica In lista_caratteristiche
                        risultato = risultato & "<tr><td>"
                        risultato = risultato & tmp_caratteristica.SelectSingleNode("Feature/Name").Attributes("Value").InnerText & "</td><td style=""padding-left:10px; background-color:white;"">"

                        'Inserisco le immaggini No e Yes
                        If (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "S") Or (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "Si") Or (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "Y") Then
                            risultato = risultato & tmp_caratteristica.Attributes("Presentation_Value").InnerText.Replace("Y", "<img alt="""" src=""Images/icecat/yes.png"" />").Replace("Si", " <img alt="""" src=""Images/icecat/yes.png"" /> ").Replace("S", " <img alt="""" src=""Images/icecat/yes.png"" /> ")
                        Else
                            If (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "N") Or (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "No") Or (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "-") Then
                                risultato = risultato & tmp_caratteristica.Attributes("Presentation_Value").InnerText.Replace("N", "<img alt="""" src=""Images/icecat/no.png"" />").Replace("No", " <img alt="""" src=""Images/icecat/no.png"" /> ").Replace("-", " <img alt="""" src=""Images/icecat/no.png"" /> ")
                            Else
                                risultato = risultato & tmp_caratteristica.Attributes("Presentation_Value").InnerText
                            End If
                        End If

                        risultato = risultato & "</td></tr>"
                    Next
                    risultato = risultato & "</table>"
                End If
            Next

            'Fine tabella
            risultato = risultato & "</table>"
            risultato = risultato & "</div>"

            Response.Write(risultato)
        End If
    End Sub
End Class
