<%@ Page Language="VB" MasterPageFile="~/Page.master" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>

<asp:Content ID="TitleContent" ContentPlaceHolderID="TitleContent" runat="server">
    Home
</asp:Content>

<asp:Content ID="HeadContent" ContentPlaceHolderID="HeadContent" runat="server">
</asp:Content>

<asp:Content ID="MainContent" ContentPlaceHolderID="MainContent" Runat="Server">

    <!-- Slide Show -->
    <div id="Slide_Show" style="max-width:600px; margin:auto; overflow:hidden;">
        <asp:SqlDataSource ID="slideShow" runat="server"
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT * FROM slideshows_parts WHERE slideshowId = (SELECT MAX(id) FROM slideshows WHERE placeholder = 'defaultPage' AND aziendeId = 1 ORDER BY Priorita) AND startDate<=CURDATE() AND stopDate>CURDATE() ORDER BY orderPosition">
        </asp:SqlDataSource>

        <div id="Slide_Show_Container" class="slideshow-container" runat="server">
            <asp:Repeater ID="slideshowItems" runat="server" DataSourceID="slideShow">
                <ItemTemplate>
                    <%incrementa_slides()%>
                    <div class="mySlides fade">
                        <%# IIf(IsDBNull(Eval("link")) OrElse Eval("link") = "", "", "<a href='" & Eval("link") & "'>") %>
                        <img src="/Public/Slideshows/<%#Eval("image")%>" style="width:100%" />
                        <%# IIf(IsDBNull(Eval("link")) OrElse Eval("link") = "", "", "</a>") %>
                        <div class="text"><%#Eval("caption")%></div>
                    </div>
                </ItemTemplate>
            </asp:Repeater>

            <a class="prev" onclick="plusSlides(-1)">&#10094;</a>
            <a class="next" onclick="plusSlides(1)">&#10095;</a>
        </div>

        <br />

        <div style="text-align:center">
            <% For i = 1 To slides %>
                <span class="dot" onclick="currentSlide(<%=i%>)"></span>
            <% Next i %>
        </div>

        <script type="text/javascript">
            var slideIndex = 1;
            showSlides(slideIndex);

            function plusSlides(n) {
                showSlides(slideIndex += n);
            }

            function currentSlide(n) {
                showSlides(slideIndex = n);
            }

            function showSlides(n) {
                var i;
                var slides = document.getElementsByClassName("mySlides");
                var dots = document.getElementsByClassName("dot");
                if (n > slides.length) { slideIndex = 1 }
                if (n < 1) { slideIndex = slides.length }
                for (i = 0; i < slides.length; i++) {
                    slides[i].style.display = "none";
                }
                for (i = 0; i < dots.length; i++) {
                    dots[i].className = dots[i].className.replace(" active", "");
                }
                slides[slideIndex - 1].style.display = "block";
                dots[slideIndex - 1].className += " active";
            }
        </script>
    </div>

    <script runat="server">
        ' --- Helper generali / slideshow / prezzi ---

        Dim slides As Integer = 0

        Function ottieni_data_oggi() As String
            Return DateTime.Now.ToString("yyyy-MM-dd")
        End Function

        Function confronta_due_date(ByVal d1 As DateTime, ByVal d2 As DateTime) As Boolean
            Return DateTime.Compare(d1, d2)
        End Function

        Sub incrementa_slides()
            slides += 1
        End Sub

        Function controlla_promo(ByVal inpromo As Integer) As String
            If inpromo = 1 Then
                Return ""
            Else
                Return "none"
            End If
        End Function

        Function controlla_prezzo_di_listino(ByVal prezzo_listino As Double) As String
            If prezzo_listino > 0 Then
                Return ""
            Else
                Return "none"
            End If
        End Function

        Function calcola_risparmio(ByVal prezzo_listino As Double, ByVal prezzo1 As Object, ByVal prezzo2 As Object) As Double
            Dim risparmio As Double
            Dim prezzo As Double

            If IsDBNull(prezzo2) OrElse prezzo2 Is Nothing OrElse CDbl(prezzo2) = 0 Then
                If IsDBNull(prezzo1) OrElse prezzo1 Is Nothing Then
                    Return 0
                End If
                prezzo = Convert.ToDouble(prezzo1)
            Else
                prezzo = Convert.ToDouble(prezzo2)
            End If

            risparmio = Math.Round(prezzo_listino - prezzo, 2)
            Return risparmio
        End Function

        Function controlla_risparmio(ByVal prezzo_listino As Double, ByVal prezzo1 As Object, ByVal prezzo2 As Object) As String
            If prezzo_listino = 0 Then
                Return "none"
            ElseIf calcola_risparmio(prezzo_listino, prezzo1, prezzo2) < 0.01 Then
                Return "none"
            Else
                Return ""
            End If
        End Function

        Function controlla_prezzo(ByVal prezzo As Double,
                                  ByVal prezzo_ivato As Double,
                                  ByVal prezzo_promo As Double,
                                  ByVal prezzo_promo_ivato As Double,
                                  ByVal iva_tipo As Integer) As String

            If prezzo_promo > 0 Then
                If iva_tipo = 1 Then
                    Return String.Format("{0:c}", prezzo_promo)
                Else
                    Return String.Format("{0:c}", prezzo_promo_ivato)
                End If
            Else
                If iva_tipo = 1 Then
                    Return String.Format("{0:c}", prezzo)
                Else
                    Return String.Format("{0:c}", prezzo_ivato)
                End If
            End If
        End Function

        ' --- Helper per vetrina / testi / sconti ---

        Function spedire_gratis(ByVal val As Integer) As String
            If val = 1 Then
                Return "block"
            Else
                Return "none"
            End If
        End Function

        Function compatta_testo(ByVal testo As String, ByVal lunghezza As Integer) As String
            If String.IsNullOrEmpty(testo) Then
                Return ""
            End If

            Dim testoFinale As String = Left(testo, lunghezza)
            If testo.Length > lunghezza Then
                testoFinale &= "..."
            End If
            Return testoFinale
        End Function

        Function sconto(ByVal listino_ufficiale As Double,
                        ByVal prezzo_promo As Double,
                        ByVal prezzo_promo_ivato As Double,
                        ByVal iva_articolo As Double) As String

            Dim percentuale As String = ""

            If (prezzo_promo > 0 AndAlso prezzo_promo_ivato > 0 AndAlso listino_ufficiale > 0) Then
                If Session("IvaTipo") = 1 Then
                    percentuale = String.Format("{0:0}", ((listino_ufficiale - prezzo_promo) * 100) / listino_ufficiale)
                Else
                    Dim listino_ivato As Double = listino_ufficiale * ((iva_articolo / 100) + 1)
                    percentuale = String.Format("{0:0}", ((listino_ivato - prezzo_promo_ivato) * 100) / listino_ivato)
                End If
            End If

            Return "- " & percentuale & "%"
        End Function

        Function prezzo_formattato(ByVal prezzo As String) As String
            If Not String.IsNullOrEmpty(prezzo) Then
                Dim temp As String() = prezzo.Split(","c)
                If temp.Length = 2 Then
                    Return "<span style=""font-size:27px;"">" & temp(0) & ",</span><span style=""font-size:20px;"">" & temp(1) & "</span>"
                End If
            End If
            Return prezzo
        End Function

        Function adatta_testo(ByVal stringa As String, ByVal lunghezza As Integer) As String
            If String.IsNullOrEmpty(stringa) Then
                Return ""
            End If

            If stringa.Length > lunghezza Then
                Return Left(stringa, lunghezza) & " ..."
            Else
                Return stringa
            End If
        End Function

        ' Controllo immagine e path standard per immagini articoli
        Function controllo_img(ByVal temp As Object) As String
            If IsDBNull(temp) OrElse temp Is Nothing Then
                Return "false"
            Else
                Return "true"
            End If
        End Function

        Function checkImg(ByVal imgname As Object) As String
            ' Gestione nulla / DBNull
            If imgname Is Nothing OrElse Convert.IsDBNull(imgname) Then
                Return "~/Public/images/nofoto.gif"
            End If

            Dim fileName As String = imgname.ToString().Trim()

            If String.IsNullOrEmpty(fileName) Then
                Return "~/Public/images/nofoto.gif"
            End If

            ' Se è già un path (relativo o assoluto), lo lascio in pace
            If fileName.StartsWith("~") OrElse fileName.StartsWith("/") Then
                Return fileName
            End If

            ' Nome file semplice: lo metto nella cartella articoli
            Return "~/Public/images/articoli/" & fileName
        End Function
    </script>

    <% If Data_UltimiArrivi.Items.Count > 0 Then %>

        <!-- Articoli in vetrina - "Scelti per te" -->
        <div class="container-fluid scelti-per-te bg-white home-box-position mt-3 bg-shadow">
            <h1 style="padding:0px;">
                <img src="Public/Images/scelti_per_te.png" width="100%" style="max-height: 50px;" />
            </h1>
            <div class="row pt-3 text-center">

                <asp:Repeater ID="Data_UltimiArrivi" runat="server" DataSourceID="SdsArticoliInVetrina">
                    <ItemTemplate>
                        <div class="col-12 col-sm-6 col-md-4 mb-4">
                            <div class="card" style="padding-bottom: 10px;min-height: 430px;">

                                <!-- Spedizione Gratis -->
                                <div style="height:40px; float:left; width:100px; margin:0px;  padding-top: 0px; padding-left: 0px;">
                                    <img src="Public/Images/promoSpGratis.png"
                                         alt="Questo articolo verrà spedito GRATIS !!!"
                                         style='display:<%# spedire_gratis(Eval("SpeditoGratis")) %>;' />
                                </div>

                                <!-- Percentuale di Sconto -->
                                <div style="height:40px; margin:0px; background-image:url('Public/Images/angolo_x.png'); background-repeat:repeat-x; font-style:italic; color:White; text-align:center; width:30%; min-width: 40pt; position:absolute; display:<%# controlla_promo(Eval("inOfferta")) %>;">
                                    <span style="font-weight:bold;">sconto</span><br />
                                    <span style="font-weight:bold;">
                                        <%# sconto(
                                                Eval("ListinoUfficiale"),
                                                If(IsDBNull(Eval("PrezzoPromo")), 0, Eval("PrezzoPromo")),
                                                If(IsDBNull(Eval("PrezzoPromoIvato")), 0, Eval("PrezzoPromoIvato")),
                                                Eval("iva")
                                            ) %>
                                    </span>
                                </div>

                                <div style="height: 130px;">
                                    <a href="articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>">
                                        <img class="card-img-top" src='<%# checkImg(Eval("img1")) %>' alt="" />
                                    </a>
                                </div>

                                <div class="card-body">
                                    <h5 class="card-title" style="min-height: 57px;">
                                        <%# compatta_testo(Eval("Descrizione1"), 30) %>
                                    </h5>
                                    <p class="card-text">
                                        <%# compatta_testo(
                                                If(Eval("taglia").Equals(DBNull.Value), "", Eval("taglia")) &
                                                If(Eval("taglia").Equals(DBNull.Value) Or Eval("colore").Equals(DBNull.Value), "", ", ") &
                                                If(Eval("colore").Equals(DBNull.Value), "", Eval("colore")),
                                                22
                                            ) %>
                                    </p>

                                    <div>
                                        <div>
                                            <span style="background-image:url('Images/back_menu.png'); background-position:center; background-color:gray; background-repeat:repeat-x; display:block; color:white; font-weight:bold; padding:5px; text-align: center;">
                                                IL TUO PREZZO
                                            </span>
                                            <span id="infobar" style="background-image:url('Images/back_menu.png'); background-position:center; background-repeat:repeat-x; display:block; color:white; font-size:11pt; padding:5px;">
                                                <% If Session("IvaTipo") = 1 Then %>
                                                    <div style="width:100%; height:31px; overflow:hidden; text-align:center; font-weight:bold;">
                                                        <%# prezzo_formattato(
                                                                If(Eval("InOfferta") = 0,
                                                                   Eval("Prezzo", "{0:C}"),
                                                                   Eval("prezzoPromo", "{0:C}")
                                                                )
                                                            ) %>
                                                    </div>
                                                <% Else %>
                                                    <div style="width:100%; height:31px; overflow:hidden; text-align:center; font-weight:bold;">
                                                        <%# prezzo_formattato(
                                                                If(Eval("InOfferta") = 0,
                                                                   Eval("PrezzoIvato", "{0:C}"),
                                                                   Eval("prezzoPromoIvato", "{0:C}")
                                                                )
                                                            ) %>
                                                    </div>
                                                <% End If %>
                                            </span>
                                        </div>

                                        <div class="mt-2" style="font-size: 0.7rem;min-height: 64px;">
                                            <%# compatta_testo(Eval("Descrizione2"), 100) %>
                                        </div>
                                    </div>

                                    <div style="margin-top: 10px">
                                        Codice: <%#Eval("Codice")%>
                                    </div>

                                    <!-- Listino Ufficiale -->
                                    <div style="height: 35px">
                                        <% If Session("IvaTipo") = 1 Then %>
                                            <div style='width:100%; overflow:hidden; text-align:center; font-weight:bold; font-size:9pt; display:<%# controlla_risparmio(Eval("ListinoUfficiale"), Eval("Prezzo"), Eval("prezzoPromo")) %>;'>
                                                prezzo di listino
                                                <span style="text-decoration:line-through; color:Red;">
                                                    <%# Eval("ListinoUfficiale", "{0:C}") %>
                                                </span>
                                            </div>
                                            <div style='width:100%; overflow:hidden; text-align:center; font-weight:bold; font-size:11pt; display:<%# controlla_risparmio(Eval("ListinoUfficiale"), Eval("Prezzo"), Eval("prezzoPromo")) %>;'>
                                                risparmi
                                                <span style="color:Red; font-size:9pt;">
                                                    <%# String.Format("{0:C}", calcola_risparmio(Eval("ListinoUfficiale"), Eval("Prezzo"), Eval("prezzoPromo"))) %>
                                                </span>
                                            </div>
                                        <% Else %>
                                            <div style='width:100%; overflow:hidden; text-align:center; font-weight:bold; font-size:9pt; display:<%# controlla_risparmio(Eval("ListinoUfficiale") * ((Eval("iva") / 100000) + 1), Eval("PrezzoIvato"), Eval("prezzoPromoIvato")) %>;'>
                                                prezzo di listino
                                                <span style="text-decoration:line-through; color:Red;">
                                                    <%# String.Format("{0:C}", (Eval("ListinoUfficiale") * ((Eval("iva") / 100000) + 1))) %>
                                                </span>
                                            </div>
                                            <div style='width:100%; overflow:hidden; text-align:center; font-weight:bold; font-size:11pt; display:<%# controlla_risparmio(Eval("ListinoUfficiale") * ((Eval("iva") / 100000) + 1), Eval("PrezzoIvato"), Eval("prezzoPromoIvato")) %>;'>
                                                risparmi
                                                <span style="color:Red; font-size:9pt;">
                                                    <%# String.Format("{0:C}", calcola_risparmio(Eval("ListinoUfficiale") * ((Eval("iva") / 100000) + 1), Eval("PrezzoIvato"), Eval("prezzoPromoIvato"))) %>
                                                </span>
                                            </div>
                                        <% End If %>
                                    </div>
                                </div>

                            </div>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>

            </div>
        </div>

        <asp:SqlDataSource ID="SdsArticoliInVetrina" runat="server"
            ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
            ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
            SelectCommand="SELECT * FROM documenti JOIN documentirighe ON documenti.id=documentirighe.`DocumentiId` WHERE documentirighe.`ArticoliId`>0 AND documenti.`TipoDocumentiId`=11 GROUP BY documentirighe.`ArticoliId` ORDER BY documenti.id DESC LIMIT 1">
        </asp:SqlDataSource>

    <% End If %>

    <!-- BANNER PUBBLICITARIO (id_posizione_banner=4)(ordinamento=1) -->
    <asp:SqlDataSource ID="SqlDataSource_Pubblicita_id4_pos1" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato from pubblicitaV2"
        UpdateCommand="update pubblicitaV2 SET numero_impressioni = numero_impressioni + 1 WHERE (id = 1)">
    </asp:SqlDataSource>

    <asp:Repeater ID="RepeaterPubblicita_id4_pos1" runat="server" DataSourceID="SqlDataSource_Pubblicita_id4_pos1" EnableViewState="False">
        <ItemTemplate>
            <br />
            <div style="max-width:100%" class="img-max-100">
                <asp:HyperLink ID="hlBanner" runat="server"
                    NavigateUrl='<%# "click.aspx?id=" & Eval("id") & "&link=" & Server.UrlEncode(Eval("link")) %>'
                    EnableViewState="false"
                    ToolTip='<%# Eval("Descrizione") %>'
                    ImageUrl='<%# "Public/Banner/" & Eval("img_path") %>'
                    Target="_blank"></asp:HyperLink>
            </div>
        </ItemTemplate>
    </asp:Repeater>

    <!-- BANNER PUBBLICITARIO (id_posizione_banner=4)(ordinamento=2) -->
    <asp:SqlDataSource ID="SqlDataSource_Pubblicita_id4_pos2" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT id, id_Azienda, data_inizio_pubblicazione, data_fine_pubblicazione, limite_click, limite_impressioni, id_posizione_banner, numero_click_attuale, numero_impressioni_attuale, link, img_path, titolo, descrizione, abilitato from pubblicitaV2"
        UpdateCommand="update pubblicitaV2 SET numero_impressioni = numero_impressioni + 1 WHERE (id = 1)">
    </asp:SqlDataSource>

    <asp:Repeater ID="RepeaterPubblicita_id4_pos2" runat="server" DataSourceID="SqlDataSource_Pubblicita_id4_pos2" EnableViewState="False">
        <ItemTemplate>
            <br />
            <div style="max-width:100%" class="img-max-100">
                <asp:HyperLink ID="hlBanner" runat="server"
                    NavigateUrl='<%# "click.aspx?id=" & Eval("id") & "&link=" & Server.UrlEncode(Eval("link")) %>'
                    EnableViewState="false"
                    ToolTip='<%# Eval("Descrizione") %>'
                    ImageUrl='<%# "Public/Banner/" & Eval("img_path") %>'
                    Target="_blank"></asp:HyperLink>
            </div>
        </ItemTemplate>
    </asp:Repeater>

    <asp:SqlDataSource ID="SdsNewArticoli" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM articoli LIMIT 1">
    </asp:SqlDataSource>

    <!-- Visualizza i nuovi prodotti inseriti -->
    <br />
    <% cont = 0 %>
    <div class="container-fluid bg-white pb-4 mt-3 home-box-position bg-shadow">
        <h1 style="padding:0px;">
            <img src="Public/Images/novita.png" width="100%" style="max-height: 50px;" />
        </h1>

        <asp:Repeater ID="Repeat_Lista_Nuovi_Arrivi" DataSourceID="SdsNewArticoli" runat="server">
            <ItemTemplate>

                <%
                    cont = cont + 1
                    If (cont = 1) Then
                %>
                <div class="row pt-4">
                    <div class="col text-center">
                        <div style="padding: 1.5rem">

                            <div style="text-align:center;">
                                <div style="width:255px; min-height: 160px;margin:auto; overflow:hidden; position:relative;">
                                    <a href="articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>">
                                        <img border="0" style="max-width: 180px; max-height: 120px;" src='<%# checkImg(Eval("img1")) %>' alt="" />
                                    </a>
                                    <div style="position:absolute; top:0px; left:44px; z-index:999; width:180px; height:50px; overflow:hidden;">
                                        <!-- Immagine Spedizione Gratis -->
                                        <div style="height:50px; float:left; width:50px; margin:0px;  padding-top: 0px; padding-left: 0px;">
                                            <img src="Public/Images/bollinoSpedizioneVetrina.png"
                                                 alt="Questo articolo verrà spedito GRATIS !!!"
                                                 style='display:<%# spedire_gratis(Eval("SpeditoGratis")) %>;' />
                                        </div>
                                        <!-- Immagine in offerta -->
                                        <div style=" width:50px; height:50px; margin:0px 0px; float:right;">
                                            <img src="Public/Images/bollinoPromoVetrina.png"
                                                 alt="Articolo in PROMO !!!"
                                                 style='display:<%# controlla_promo(Eval("inOfferta"))%>;' />
                                        </div>
                                    </div>
                                    <div style="text-align:center;">
                                        <a href="articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>">
                                            <img border="0" width="80px" src='<%# "Public/Marche/" & Eval("Marche_img") %>' alt="" />
                                        </a>
                                    </div>
                                </div>
                            </div>

                            <div style="padding-left:25px; max-width:255px; margin:auto; position:relative; text-align:justify; font-size:8pt; font-weight:bold; margin-top: 10px;">
                                <div>
                                    <a href="articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>">
                                        <%# adatta_testo(Eval("Descrizione1"), 80) %><br />
                                        <%# compatta_testo(
                                                If(Eval("taglia").Equals(DBNull.Value), "", Eval("taglia")) &
                                                If(Eval("taglia").Equals(DBNull.Value) Or Eval("colore").Equals(DBNull.Value), "", ", ") &
                                                If(Eval("colore").Equals(DBNull.Value), "", Eval("colore")),
                                                22
                                            ) %>
                                    </a>
                                </div>

                                <span style="background-image:url('Images/back_menu.png'); background-position:center; background-color:gray; background-repeat:repeat-x; display:block; color:white; font-weight:bold; padding:5px; text-align:center; font-size:9pt;">
                                    IL TUO PREZZO
                                </span>

                                <span id="infobar" style="background-image:url('Images/back_menu.png'); background-position:center; background-repeat:repeat-x; display:block; color:white; font-size:11pt; padding:5px; text-align:center;">
                                    <%# controlla_prezzo(
                                            If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                            If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                            If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                            If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                            Session("IvaTipo")
                                        ) %>
                                </span>
                            </div>

                        </div>
                    </div>
                    <div class="col d-none d-sm-block" style="align-self: center;">
                        <%
                    Else
                        ' Stampa degli altri
                        If (cont = 4) Then
                            cont = 0
                        End If
                        %>

                        <div style="width:300px; height:93.5px; margin: 0 auto; padding-bottom:5px; text-align:left; background-image:url('Images/back_right.png'); background-repeat:no-repeat; background-position: bottom right;">
                            <div style="width:80px; height:90px; float:left; overflow:hidden; position:relative;">
                                <div style="position:absolute; top:0px; left:0px; z-index:999; width:80px; height:50px; overflow:hidden;">
                                    <!-- Immagine Spedizione Gratis -->
                                    <div style="height:40px; float:left; width:40px; margin:0px;  padding-top: 0px; padding-left: 0px;">
                                        <img src="Public/Images/bollinoSpedizioneVetrina.png"
                                             alt="Questo articolo verrà spedito GRATIS !!!"
                                             style='display:<%# spedire_gratis(Eval("SpeditoGratis")) %>; width:40px;' />
                                    </div>
                                    <!-- Immagine in offerta -->
                                    <div style=" width:40px; height:40px; margin:0px 0px; float:right;">
                                        <img src="Public/Images/bollinoPromoVetrina.png"
                                             alt="Articolo in PROMO !!!"
                                             style='display:<%# controlla_promo(Eval("inOfferta"))%>; width:40px;' />
                                    </div>
                                </div>
                                <a href="articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>">
                                    <img border="0" width="85px" src='<%# checkImg(Eval("img1")) %>' alt="" />
                                </a>
                            </div>
                            <div style="width:215px; height:90px; float:right; position:relative; font-size:7pt; padding-left:5px; text-align:justify;">
                                <a href="articolo.aspx?id=<%# Eval("ArticoliId") %>&amp;TCId=<%# Eval("TCId") %>">
                                    <%# adatta_testo(Eval("Descrizione1"), 100) %><br />
                                    <%# compatta_testo(
                                            If(Eval("taglia").Equals(DBNull.Value), "", Eval("taglia")) &
                                            If(Eval("taglia").Equals(DBNull.Value) Or Eval("colore").Equals(DBNull.Value), "", ", ") &
                                            If(Eval("colore").Equals(DBNull.Value), "", Eval("colore")),
                                            22
                                        ) %>
                                </a>
                                <div style="position:absolute; bottom:3px; left:5px; height:25px; text-align:left; font-size:6pt;">
                                    <%# "<b>COD.</b><br>" & Eval("Codice") %>
                                </div>
                                <div style="position:absolute; bottom:-8px; right:3px; width:100px; height:30px; text-align:right; font-weight:bold; font-size:12pt; color:white;">
                                    <%# controlla_prezzo(
                                            If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                            If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                            If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                            If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                            Session("IvaTipo")
                                        ) %>
                                </div>
                            </div>
                        </div>

                        <% End If
                        If ((cont Mod 4) = 0) Then
                        %>
                    </div>
                </div>
                <% End If %>

            </ItemTemplate>
        </asp:Repeater>

        <% If ((cont Mod 4) <> 0) Then %>
            </div>
        </div>
        <% End If %>
    </div>

    <!-- I più venduti -->
    <br />
    <div style="clear:both;"></div>
    <div class="border-radius" style="margin:auto; border-style:none;">

        <div class="container-fluid bg-white home-box-position mt-3 bg-shadow">
            <h1 style="padding:0px;">
                <img src="Public/Images/piu_venduti.png" alt="" width="100%" style="max-height: 50px;" />
            </h1>
            <div class="row mx-1">

                <asp:Repeater ID="DataList1" runat="server" DataSourceID="sdsPiuAcquistati">
                    <ItemTemplate>
                        <div class="col-venduti my-3">
                            <div class="card" style="width:125px; overflow:hidden;">
                                <div style=" position:relative; width:100%; height:100%;">

                                    <a href='<%# "articolo.aspx?id=" & Eval("ArticoliId") & "&TCId=" & Eval("TCId") %>' style="border-style:none; margin:auto;">
                                        <div style="position:absolute; top:0px; left:0px; z-index:999; width:100%; height:50px; overflow:hidden;">
                                            <!-- Immagine Spedizione Gratis -->
                                            <div style="height:50px; float:left; width:50px; margin:0px;  padding-top: 0px; padding-left: 0px;">
                                                <img src="Public/Images/bollinoSpedizioneVetrina.png"
                                                     alt="Questo articolo verrà spedito GRATIS !!!"
                                                     style='display:<%# spedire_gratis(Eval("SpeditoGratis")) %>;' />
                                            </div>
                                            <!-- Immagine in offerta -->
                                            <div style=" width:50px; height:50px; margin:0px 0px; float:right;">
                                                <img src="Public/Images/bollinoPromoVetrina.png"
                                                     alt="Articolo in PROMO !!!"
                                                     style='display:<%# controlla_promo(Eval("inOfferta"))%>;' />
                                            </div>
                                        </div>
                                    </a>

                                    <div style="overflow:hidden; text-align:center;">
                                        <table style=" width:100%; height:100%; vertical-align:middle;">
                                            <tr>
                                                <td style="width:150px; height:100px; overflow:hidden; vertical-align:middle;">
                                                    <a href='<%# "articolo.aspx?id=" & Eval("ArticoliId") & "&TCId=" & Eval("TCId") %>' style="margin:auto; border-style:none;">
                                                        <img src="<%# checkImg(Eval("img1")) %>" style=" width:100px; border-style:none;" alt="" />
                                                    </a>
                                                </td>
                                            </tr>
                                            <tr>
                                                <td>
                                                    <div style="color:black; font-weight:bold; font-size:6pt; text-align:left; margin: 5px; min-height: 36px;">
                                                        <%# compatta_testo(Eval("Descrizione1"), 22) %><br />
                                                        <%# compatta_testo(
                                                                If(Eval("taglia").Equals(DBNull.Value), "", Eval("taglia")) &
                                                                If(Eval("taglia").Equals(DBNull.Value) Or Eval("colore").Equals(DBNull.Value), "", ", ") &
                                                                If(Eval("colore").Equals(DBNull.Value), "", Eval("colore")),
                                                                22
                                                            ) %>
                                                    </div>
                                                    <div style="text-align:center; background-color:#ebebeb;">
                                                        <span style="background-image:url('Images/back_menu.png'); background-position:center; background-color:gray; background-repeat:repeat-x; display:block; color:white; font-weight:bold; padding-top:2px; padding-bottom:2px; font-size:8pt;">
                                                            IL TUO PREZZO
                                                        </span>
                                                        <span id="infobar" style="background-image:url('Images/back_menu.png'); background-position:center; background-repeat:repeat-x; display:block; color:white; font-size:11pt; font-weight:bold;">
                                                            <%# controlla_prezzo(
                                                                    If(IsDBNull(Eval("prezzo")), 0, Eval("prezzo")),
                                                                    If(IsDBNull(Eval("prezzoIvato")), 0, Eval("prezzoIvato")),
                                                                    If(Eval("InOfferta") = 0, 0, Eval("prezzoPromo")),
                                                                    If(Eval("InOfferta") = 0, 0, Eval("PrezzoPromoIvato")),
                                                                    Session("IvaTipo")
                                                                ) %>
                                                        </span>
                                                    </div>
                                                </td>
                                            </tr>
                                        </table>
                                    </div>

                                </div>
                            </div>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>

            </div>
        </div>

        <!-- Marche Random -->
        <br />
        <div id="boxpromo">
            <div class="container-fluid mb-3 partners mt-3 bg-shadow home-box-position">
                <div class="row">
                    <h2 style="font-size: 1.7rem;">
                        Rivenditori Ufficiali - I nostri brand  <i class="fa fa-handshake"></i>
                    </h2>
                </div>
                <div class="row">
                    <asp:Repeater ID="MarcheRandom" runat="server" DataSourceID="sdsMarcheRandom">
                        <ItemTemplate>
                            <div class="col-3 col-md-2 align-self-center py-2">
                                <a href='<%# "articoli.aspx?ct=30000&mr=" & Eval("id") %>'>
                                    <img src="<%# "Public/Marche/" & Eval("img") %>"
                                         style="width:100%; max-width:150px;"
                                         alt="<%# Eval("Descrizione") %>"
                                         title="<%# Eval("Descrizione")%>" />
                                </a>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </div>

            <asp:SqlDataSource ID="sdsMarcheRandom" runat="server"
                ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
                ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
                SelectCommand="SELECT * FROM marche WHERE (Abilitato=1) AND (img is not NULL) ORDER BY RAND() LIMIT 6">
            </asp:SqlDataSource>
        </div>

    </div>

    <asp:SqlDataSource ID="sdsPiuAcquistati" runat="server"
        ConnectionString="<%$ ConnectionStrings:EntropicConnectionString %>"
        ProviderName="<%$ ConnectionStrings:EntropicConnectionString.ProviderName %>"
        SelectCommand="SELECT * FROM documenti LIMIT 1">
    </asp:SqlDataSource>

    <br />
    <asp:Label ID="lblPrezzi" runat="server" Text="*Prezzi" Font-Size="7pt" Font-Names="arial"></asp:Label><br />

</asp:Content>
