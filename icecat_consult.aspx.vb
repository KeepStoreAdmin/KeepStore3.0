Imports System.Net
Imports System.IO
Imports System.Xml

Partial Class icecat_consult
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Dim url_esterno As String = ""
        Dim tmp_XML As String = ""

        Dim ean As String = Request.QueryString("ean")

        If ean <> "" Then
            url_esterno = "http://data.icecat.biz/xml_s3/xml_server3.cgi?ean_upc=" & ean & ";lang=it;output=productxml"
        Else
            If Request.QueryString("xml") <> "" Then
                url_esterno = Request.QueryString("xml")
            Else
                url_esterno = "http://data.icecat.biz/xml_s3/xml_server3.cgi?prod_id=" & Request.QueryString("cod_prodotto") & ";vendor=" & Request.QueryString("marca") & ";lang=it;output=productxml"
            End If
        End If

        Dim uri As New Uri(url_esterno)
        Dim myCredenziali As New CredentialCache()
        myCredenziali.Add(New Uri(url_esterno), "Basic", New NetworkCredential("entropic", "entropic2011"))
        'myCredenziali.Add(New Uri(url_esterno), "Basic", New NetworkCredential("EUROPRICE", "Rxe95jbz"))

        If (uri.Scheme = uri.UriSchemeHttp) Then
            Dim request As HttpWebRequest = HttpWebRequest.Create(uri)
            request.Credentials = myCredenziali
            request.Method = WebRequestMethods.Http.Get
            Dim risposta As HttpWebResponse = request.GetResponse()
            Dim reader As New StreamReader(risposta.GetResponseStream())
            tmp_XML = reader.ReadToEnd()
            risposta.Close()
        End If

        'Potrei leggere da qui l'errore relativo all'accesso la Catalogo COMPLETO di ICECAT
        If tmp_XML.Contains("You are not allowed to have Full ICEcat access") Then
            Response.Write("Prodotto non compreso nel catalogo FREE di ICEcat. Per info sul Catalogo Completo, visitare il sito <a href=""http://www.icecat.it/it/menu/services/index.htm"">www.icecat.it</a>")
        Else
            'Lettura del file XML
            Dim Doc As XmlDocument = New XmlDocument
            Doc.LoadXml(tmp_XML)

            Response.Write("<ARTICOLO>")
            If Doc.SelectNodes("/ICECAT-interface/Product/Category").Count > 0 Then
                Dim lista_categorie As XmlNodeList
                'Ean
                Try
                    Response.Write("<ean>" & Doc.SelectNodes("/ICECAT-interface/Product/EANCode").Item(0).Attributes("EAN").InnerText & "</ean>")
                Catch ex As Exception
                    Response.Write("<ean></ean>")
                End Try
                'Codice_Articolo
                Response.Write("<codice_articolo>" & Doc.SelectNodes("/ICECAT-interface/Product").Item(0).Attributes("Prod_id").InnerText & "</codice_articolo>")
                'Titolo
                Response.Write("<titolo><![CDATA[" & Doc.SelectNodes("/ICECAT-interface/Product").Item(0).Attributes("Title").InnerText & "]]></titolo>")
                'Marca
                Response.Write("<marca>" & Doc.SelectNodes("/ICECAT-interface/Product/Supplier").Item(0).Attributes("Name").InnerText & "</marca>")
                'Foto Grande
                Response.Write("<foto_grande>" & Doc.SelectNodes("/ICECAT-interface/Product").Item(0).Attributes("HighPic").InnerText & "</foto_grande>")
                'Miniature
                Dim tmp_altre_foto_list As XmlNodeList = Doc.SelectNodes("/ICECAT-interface/Product/ProductGallery/ProductPicture")
                Dim tmp_altre_foto As XmlNode
                If tmp_altre_foto_list.Count > 0 Then
                    Dim i As Integer = 0
                    For Each tmp_altre_foto In tmp_altre_foto_list
                        'Foto Collegamento + Link
                        i = i + 1
                        Response.Write("<foto_" & i & ">" & tmp_altre_foto.Attributes("Pic").InnerText & "</foto_" & i & ">")
                    Next
                End If
                'Descrizione Breve (Descrizione 1)
                If Not Doc.SelectSingleNode("/ICECAT-interface/Product/SummaryDescription/ShortSummaryDescription") Is Nothing Then
                    Response.Write("<descrizione1><![CDATA[" & Doc.SelectSingleNode("/ICECAT-interface/Product/SummaryDescription/ShortSummaryDescription").InnerText & "]]></descrizione1>")
                End If
                'Descrizione Lunga (Descrizione 2)
                If Not Doc.SelectSingleNode("/ICECAT-interface/Product/SummaryDescription/LongSummaryDescription") Is Nothing Then
                    Response.Write("<descrizione2><![CDATA[" & Doc.SelectSingleNode("/ICECAT-interface/Product/SummaryDescription/LongSummaryDescription").InnerText & "]]></descrizione2>")
                End If

                'Controllo che ci sia o meno la descrizione lunga
                Dim tmp_descrizione_lunga As XmlNodeList = Doc.SelectNodes("/ICECAT-interface/Product/ProductDescription")
                If tmp_descrizione_lunga.Count > 0 Then
                    'Descrizione Prodotto (Descrizione Lunga)
                    If Not Doc.SelectNodes("/ICECAT-interface/Product/ProductDescription").Item(0).Attributes("LongDesc") Is Nothing Then
                        Response.Write("<descrizione_lunga><![CDATA[" & Doc.SelectNodes("/ICECAT-interface/Product/ProductDescription").Item(0).Attributes("LongDesc").InnerText & "]]></descrizione_lunga>")
                    End If
                    'Garanzia
                    If Not Doc.SelectNodes("/ICECAT-interface/Product/ProductDescription").Item(0).Attributes("WarrantyInfo") Is Nothing Then
                        Response.Write("<garanzia>" & Doc.SelectNodes("/ICECAT-interface/Product/ProductDescription").Item(0).Attributes("WarrantyInfo").InnerText & "</garanzia>")
                    End If
                    'PDF URL
                    If Not Doc.SelectNodes("/ICECAT-interface/Product/ProductDescription").Item(0).Attributes("PDFURL") Is Nothing Then
                        Response.Write("<pdf_url>" & Doc.SelectNodes("/ICECAT-interface/Product/ProductDescription").Item(0).Attributes("PDFURL").InnerText & "</pdf_url>")
                    End If
                End If

                'Rimuovo da file xml tutte le Categorie senza caratteristiche 
                Dim tot_righe_stampa As Integer
                lista_categorie = Doc.SelectNodes("/ICECAT-interface/Product/CategoryFeatureGroup")
                Dim list_caratteristiche As XmlNodeList
                Dim temp_categoria As XmlNode
                For Each temp_categoria In lista_categorie
                    list_caratteristiche = Doc.SelectNodes("/ICECAT-interface/Product/ProductFeature[@CategoryFeatureGroup_ID='" & temp_categoria.Attributes("ID").InnerText & "']")
                    If list_caratteristiche.Count = 0 Then
                        temp_categoria.ParentNode.RemoveChild(temp_categoria)
                    Else
                        'aumento il numero di pagine da stampare
                        tot_righe_stampa = tot_righe_stampa + list_caratteristiche.Count
                    End If
                Next
                lista_categorie = Doc.SelectNodes("/ICECAT-interface/Product/CategoryFeatureGroup")
                '--------------------------------------------------------------------------------------

                Dim risultato As String = ""
                Dim tmp_categoria As XmlNode

                'Stile Css Tabella
                risultato = risultato & "<style type=""text/css""> " & _
                "#titolo { font-size:18pt; font-weight:bold; background-color:red; color:white; }" & _
                "#icecat td { border-style:none; border-width:0px; border-color:#DDD; font-size:9pt; font-family: Arial, Helvetica, sans-serif; border-collapse:collapse; border-width:0px; border-style:none;}" & _
                "#categoria { background-color:#AFAFAF; text-align:left; vertical-align:top; font-size:9pt; font-weight:bold; padding:5px; color:white; }" & _
                "#caratteristiche td { border-style:none; border-width:0px; background-color:#F3F3F3; color:black; padding:5px; border-collapse:collapse; }" & _
                "</style>" & _
                "<div style=""margin:auto; width:650px;"">" & _
                "<table id=""icecat"" cellspacing=""0px"" cellpadding=""5px"">" & _
                "<tr><td colspan=""2"" style=""border-style:solid; border-width:1px; border-color:#DDD; font-weight:bold; padding:10px; text-align:center;"">SCHEDA TECNICA</td></tr>" & _
                "<tr>" & _
                "<td style=""vertical-align:top; width:50%;"">"

                'Usato per il conteggio e la stampa in 2 colonne
                Dim cont_riga_da_stampare As Integer = 0
                Dim apri_seconda_colonna As Integer = 1

                For Each tmp_categoria In lista_categorie
                    cont_riga_da_stampare = cont_riga_da_stampare + 1

                    If (cont_riga_da_stampare > ((tot_righe_stampa / 2) + 5)) And (apri_seconda_colonna = 1) Then
                        apri_seconda_colonna = 0
                        risultato = risultato & "</td>"
                        risultato = risultato & "<td style=""vertical-align:top; width:50%;"">"
                    End If


                    risultato = risultato & "<div style=""width:100%; margin-top:0px;"">"
                    risultato = risultato & "<table style=""width:100%; border-collapse:collapse;"">"

                    Dim id_categoria As Integer = 0
                    id_categoria = tmp_categoria.Attributes("ID").InnerText

                    Dim lista_caratteristiche As XmlNodeList
                    lista_caratteristiche = Doc.SelectNodes("/ICECAT-interface/Product/ProductFeature[@CategoryFeatureGroup_ID='" & id_categoria & "']")

                    If lista_caratteristiche.Count > 0 Then 'Controllo se ci sono delle caratteristiche per la categoria selezionata
                        risultato = risultato & "<tr>"
                        risultato = risultato & "<td id=""categoria"" >"
                        If Not tmp_categoria.SelectSingleNode("FeatureGroup/Name") Is Nothing Then
                            risultato = risultato & "<span>" & tmp_categoria.SelectSingleNode("FeatureGroup/Name").Attributes("Value").InnerText & "</span>"
                        End If

                        risultato = risultato & "</td>"
                        risultato = risultato & "</tr>"

                        risultato = risultato & "<tr>"
                        risultato = risultato & "<td>"
                        risultato = risultato & "<table cellspacing=""0px"" cellpadding=""5px"" id=""caratteristiche"" style=""border-collapse:collapse; border-style:none; border-width:0px; width:100%;"">"
                        Dim tmp_caratteristica As XmlNode
                        For Each tmp_caratteristica In lista_caratteristiche
                            If (tmp_caratteristica.SelectSingleNode("Feature/Name").Attributes("Value").InnerText <> "Source data-sheet") Then
                                cont_riga_da_stampare = cont_riga_da_stampare + 1

                                risultato = risultato & "<tr style=""width:100%;""><td width=""200px"">"
                                risultato = risultato & tmp_caratteristica.SelectSingleNode("Feature/Name").Attributes("Value").InnerText & "</td><td style=""padding-left:10px; background-color:white; border-style:solid; border-width:1px; border-color:#DDD;"">"

                                'Inserisco le immaggini No e Yes
                                Try
                                    If (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "S") Or (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "Si") Or (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "Y") Then
                                        risultato = risultato & tmp_caratteristica.Attributes("Presentation_Value").InnerText.Replace("Y", "<img alt="""" src=""https://www.taikun.it/Images/icecat/yes.png"" />").Replace("Si", " <img alt="""" src=""https://www.taikun.it/Images/icecat/yes.png"" /> ").Replace("S", " <img alt="""" src=""https://www.taikun.it/Images/icecat/yes.png"" /> ")
                                    Else
                                        If (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "N") Or (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "No") Or (tmp_caratteristica.Attributes("Presentation_Value").InnerText = "-") Then
                                            risultato = risultato & tmp_caratteristica.Attributes("Presentation_Value").InnerText.Replace("No", " <img alt="""" src=""https://www.taikun.it/Images/icecat/no.png"" /> ").Replace("NO", " <img alt="""" src=""https://www.taikun.it/Images/icecat/no.png"" /> ").Replace("N", "<img alt="""" src=""https://www.taikun.it/Images/icecat/no.png"" />").Replace("-", " <img alt="""" src=""https://www.taikun.it/Images/icecat/no.png"" /> ")
                                        Else
                                            risultato = risultato & tmp_caratteristica.Attributes("Presentation_Value").InnerText
                                        End If
                                    End If
                                Catch
                                End Try
                                risultato = risultato & "</td></tr>"
                            End If
                        Next
                        risultato = risultato & "</table>"
                        risultato = risultato & "</td></tr>"
                    End If

                    risultato = risultato & "</table>"
                    risultato = risultato & "</div>"
                Next

                risultato = risultato & "</td>"
                risultato = risultato & "</tr>"

                'Fine tabella
                risultato = risultato & "</table>"
                risultato = risultato & "</div>"

                Response.Write("<descrizione_html><![CDATA[" & Server.HtmlEncode(risultato) & "]]></descrizione_html></ARTICOLO>")
            End If
        End If
    End Sub
End Class
