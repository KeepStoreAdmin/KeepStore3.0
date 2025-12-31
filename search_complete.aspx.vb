Partial Class search_complete
    Inherits System.Web.UI.Page

    Protected Sub Button_Abilita_Marche_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_Abilita_Marche.Click
        If (Me.DropDownList_Marche.Enabled = False) Then
            Me.DropDownList_Marche.Enabled = True
            Me.Button_Abilita_Marche.Text = "Disabilita"
        Else
            Me.DropDownList_Marche.Enabled = False
            Me.Button_Abilita_Marche.Text = "Abilita"
        End If
    End Sub

    Protected Sub Button_Abilita_Tipologie_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_Abilita_Tipologie.Click
        If (Me.DropDownList_Tipologie.Enabled = False) Then
            Me.DropDownList_Tipologie.Enabled = True
            Me.Button_Abilita_Tipologie.Text = "Disabilita"
        Else
            Me.DropDownList_Tipologie.Enabled = False
            Me.Button_Abilita_Tipologie.Text = "Abilita"
        End If
    End Sub

    Protected Sub Button_Abilita_Gruppi_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_Abilita_Gruppi.Click
        If (Me.DropDownList_Gruppi.Enabled = False) Then
            Me.DropDownList_Gruppi.Enabled = True
            Me.Button_Abilita_Gruppi.Text = "Disabilita"
        Else
            Me.DropDownList_Gruppi.Enabled = False
            Me.Button_Abilita_Gruppi.Text = "Abilita"
        End If
    End Sub

    Protected Sub Button_Abilita_Sottogruppi_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_Abilita_Sottogruppi.Click
        If (Me.DropDownList_Sottogruppi.Enabled = False) Then
            Me.DropDownList_Sottogruppi.Enabled = True
            Me.Button_Abilita_Sottogruppi.Text = "Disabilita"
        Else
            Me.DropDownList_Sottogruppi.Enabled = False
            Me.Button_Abilita_Sottogruppi.Text = "Abilita"
        End If
    End Sub

    Protected Sub Page_LoadComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.LoadComplete
        If Not Me.Page.IsPostBack Then
            Me.DropDownList_Gruppi.Enabled = False
            Me.DropDownList_Marche.Enabled = False
            Me.DropDownList_Sottogruppi.Enabled = False
            Me.DropDownList_Tipologie.Enabled = False
        End If

        Session.Item("Sto_usando_search_complete") = 1
    End Sub

    Protected Sub Button_Effettua_Ricerca_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_Effettua_Ricerca.Click
        Dim Link As String = "articoli.aspx?st=0"

        ' Categoria
        If Me.DropDownList_Categorie.Enabled = False Then
            Link &= "&ct=30000"
        Else
            Link &= "&ct=" & Me.DropDownList_Categorie.SelectedValue
        End If

        ' Tipologia
        If Me.DropDownList_Tipologie.Enabled = False Then
            Link &= "&tp=0"
        Else
            Link &= "&tp=" & Me.DropDownList_Tipologie.SelectedValue
        End If

        ' Gruppo
        If Me.DropDownList_Gruppi.Enabled = False Then
            Link &= "&gr=0"
        Else
            Link &= "&gr=" & Me.DropDownList_Gruppi.SelectedValue
        End If

        ' Sottogruppo
        If Me.DropDownList_Sottogruppi.Enabled = False Then
            Link &= "&sg=0"
        Else
            Link &= "&sg=" & Me.DropDownList_Sottogruppi.SelectedValue
        End If

        ' Marca
        If Me.DropDownList_Marche.Enabled = False Then
            Link &= "&mr=0"
        Else
            Link &= "&mr=" & Me.DropDownList_Marche.SelectedValue
        End If

        ' Testo descrizione (query "q"), URL-encoded
        If Me.Text_Descrizione.Text <> "" Then
            Dim testoRicerca As String = Me.Text_Descrizione.Text.Trim()
            Link &= "&q=" & Server.UrlEncode(testoRicerca)
        End If

        ' Flag promozione
        If Me.CheckBox_InPromo.Checked = True Then
            Link &= "&inpromo=1"
        Else
            Link &= "&inpromo=0"
        End If

        ' Prezzi min / max -> salvati in Session, usati in articoli.aspx
        If Val(Me.TextBox_PrezzoMin.Text) > 0 Then
            Session.Item("Prezzo_MIN") = Me.TextBox_PrezzoMin.Text
        Else
            Session.Item("Prezzo_MIN") = ""
        End If

        If Val(Me.TextBox_PrezzoMax.Text) > 0 Then
            Session.Item("Prezzo_MAX") = Me.TextBox_PrezzoMax.Text
        Else
            Session.Item("Prezzo_MAX") = ""
        End If

        ' Nel caso in cui l'utente ha inserito un prezzo min > max
        If (Val(Me.TextBox_PrezzoMin.Text) > Val(Me.TextBox_PrezzoMax.Text)) Then
            Session.Item("Prezzo_MIN") = Me.TextBox_PrezzoMin.Text
            Session.Item("Prezzo_MAX") = ""
        End If

        ' Solo disponibili
        If Me.CheckBox_Disponibile.Checked = True Then
            Session.Item("Disp") = 1
            Link &= "&dispo=1"
        Else
            Session.Item("Disp") = 0
        End If

        ' Prodotti con spedizione gratis
        If Me.CheckBox_SpedizioneGratis.Checked = True Then
            Session.Item("SpedGratis") = 1
            Link &= "&spedgratis=1"
        Else
            Session.Item("SpedGratis") = 0
        End If

        Response.Redirect(Link)
    End Sub

    Protected Sub Button_Abilita_Categorie_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_Abilita_Categorie.Click
        If Me.DropDownList_Categorie.Enabled = True Then
            ' Disabilito filtro categorie => tutte le categorie
            Me.DropDownList_Categorie.Enabled = False

            Me.Sql_Marche.SelectCommand =
                "SELECT DISTINCT marche.id, marche.Descrizione " &
                "FROM marche INNER JOIN vsuperarticoli ON marche.id = vsuperarticoli.MarcheId " &
                "ORDER BY marche.Descrizione"
            Me.Sql_Marche.SelectParameters.Clear()

            ' Disabilito combo dipendenti
            Me.DropDownList_Gruppi.Enabled = False
            Me.DropDownList_Sottogruppi.Enabled = False
            Me.DropDownList_Tipologie.Enabled = False

            ' Disabilito bottoni relativi
            Me.Button_Abilita_Sottogruppi.Enabled = False
            Me.Button_Abilita_Sottogruppi.Text = "Abilita"
            Me.Button_Abilita_Tipologie.Enabled = False
            Me.Button_Abilita_Tipologie.Text = "Abilita"
            Me.Button_Abilita_Gruppi.Enabled = False
            Me.Button_Abilita_Gruppi.Text = "Abilita"

            Me.Button_Abilita_Categorie.Text = "Filtra Categorie"
        Else
            ' Riabilito filtro categorie
            Me.DropDownList_Categorie.Enabled = True

            Me.Sql_Marche.SelectCommand =
                "SELECT DISTINCT marche.id, marche.Descrizione, vsuperarticoli.CategorieId " &
                "FROM marche INNER JOIN vsuperarticoli ON marche.id = vsuperarticoli.MarcheId " &
                "WHERE (vsuperarticoli.CategorieId = @Param) " &
                "ORDER BY marche.Descrizione"

            Me.Sql_Marche.SelectParameters.Clear()
            Me.Sql_Marche.SelectParameters.Add("Param", Me.DropDownList_Categorie.SelectedValue)

            Me.Button_Abilita_Categorie.Text = "Tutte le Categorie"

            ' Riabilito bottoni relativi
            Me.Button_Abilita_Sottogruppi.Enabled = True
            Me.Button_Abilita_Sottogruppi.Text = "Disabilita"
            Me.Button_Abilita_Tipologie.Enabled = True
            Me.Button_Abilita_Tipologie.Text = "Disabilita"
            Me.Button_Abilita_Gruppi.Enabled = True
            Me.Button_Abilita_Gruppi.Text = "Disabilita"
        End If
    End Sub

End Class
