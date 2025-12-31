Imports MySql.Data.MySqlClient
Imports System.Data

Partial Class Setup_Listino_Personalizzato
    Inherits System.Web.UI.Page

    Protected Sub Azzera_Selezioni_Listino()
        Dim i As Integer

        For i = 0 To Me.GridView_ListinoCompleto.Rows.Count - 1
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(1).FindControl("CheckBox_Attivo"), CheckBox).Checked = False
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(2).FindControl("TextBox_Ricarico"), TextBox).Text = ""
            CType(Me.GridView_ListinoCompleto.Rows(i).Cells(3).FindControl("CheckBox_Promo"), CheckBox).Checked = False
        Next
    End Sub

    Protected Sub GridView_ListinoCompleto_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles GridView_ListinoCompleto.PreRender
        Dim i As Integer
        Dim temp As Label

        For i = 0 To Me.GridView_ListinoCompleto.Rows.Count - 1
            temp = Me.GridView_ListinoCompleto.Rows(i).FindControl("Label3")

            If ((temp.Text <> "") And (Me.Page.IsPostBack = False)) Then
                temp.Text = "> " & temp.Text
                temp.Font.Bold = True
            Else
                temp = Me.GridView_ListinoCompleto.Rows(i).FindControl("Label2")
                temp.Font.Bold = True
            End If
        Next
    End Sub

    Protected Sub Button_CreaListino_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_CreaListino.Click
        If (Me.TextBox_NomeListino.Text <> "") Then

            'Controllo che il nome_listino non sia già presente nella dropdownlist
            Dim temp As Object
            temp = Me.DropDownList_ListiniUtente.Items.FindByText(Me.TextBox_NomeListino.Text)
            If Not (temp Is Nothing) Then
                Me.Label_Esito.Text = "LISTINO GIA' PRESENTE - Inserire un nome diverso"
                Return
            End If
            '////////////////////////////////////////////////////////////////////////

            Me.SqlData_Listino_Personalizzato.Insert() 'Aggiunge un NUOVO Listino

            'Me.TextBox_NomeListino.Text = ""
            Me.Label_Esito.Visible = True
            Me.Label_Esito.Text = "LISTINO SALVATO CORRETTAMENTE"

            Dim conn As New MySqlConnection
            Dim cmd As New MySqlCommand
            Dim sqlString As String = ""
            Dim dsData As New DataSet
            Dim strCerca As String = Me.Session("q")

            Try

                conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
                conn.Open()

                sqlString = "SELECT ID, ID_Utente, Nome_Listino FROM(listini_personalizzati) WHERE (ID_Utente = ?UtentiID) AND (Nome_Listino = ?listino)"

                cmd.Connection = conn
                cmd.CommandType = CommandType.Text
                cmd.Parameters.AddWithValue("?listino", Me.TextBox_NomeListino.Text)
                cmd.Parameters.AddWithValue("?UtentiID", Session.Item("UtentiId"))
                cmd.CommandText = sqlString

                Dim dr As MySqlDataReader = cmd.ExecuteReader()

                'Prendiamo l'ID del Listino appena creato e lo salviamo in sessione
                dr.Read()
                If dr.HasRows Then
                    Session("ID_Listino_Personalizzato") = dr.Item("ID")
                End If

                cmd.Dispose()

                'Inserimento nel Database delle scelte effettuate sul nuovo listino selezionato

                Dim tmpPromo, tmpAttivo As CheckBox
                Dim tmpIdSettore, tmpIdCategoria, tmpIdTipologia As Label
                Dim tmpRicarico As TextBox

                Dim i, valuePromo As Integer

                Me.SqlData_Dettagli_Listino_Personalizzato.Delete() 'Cancella il listino personalizzato per poi inseire il nuovo e aggiornato

                For i = 0 To Me.GridView_ListinoCompleto.Rows.Count - 1
                    tmpAttivo = Me.GridView_ListinoCompleto.Rows(i).Cells(1).FindControl("CheckBox_Attivo")
                    If (tmpAttivo.Checked) Then
                        'riga del listino da inserire nel db
                        tmpIdSettore = Me.GridView_ListinoCompleto.Rows(i).Cells(0).FindControl("Label_IDSettore")
                        tmpIdCategoria = Me.GridView_ListinoCompleto.Rows(i).Cells(0).FindControl("Label_IDCategoria")
                        tmpIdTipologia = Me.GridView_ListinoCompleto.Rows(i).Cells(0).FindControl("Label_IDTipologia")

                        tmpRicarico = Me.GridView_ListinoCompleto.Rows(i).Cells(2).FindControl("TextBox_Ricarico")
                        tmpPromo = Me.GridView_ListinoCompleto.Rows(i).Cells(3).FindControl("CheckBox_Promo")

                        valuePromo = 0
                        If (tmpPromo.Checked = True) Then
                            valuePromo = 1
                        End If

                        Dim ricarico As Double
                        tmpRicarico.Text = tmpRicarico.Text.Replace(".", ",")

                        ricarico = 0

                        Double.TryParse(tmpRicarico.Text, ricarico) 'Converto in Double il contenuto di tmpRicarico, se c'è testo il valore è zero

                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertCommand = "INSERT INTO dettagli_listino_personalizzato (ID_Listino_Personalizzato, ID_Settore, ID_Categoria, ID_Tipologia, Promo, Ricarico) VALUES ( @listino,@tmpIdSettore,@tmpIdCategoria,@tmpIdTipologia,@valuePromo,@ricarico)"
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.Clear()
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@listino", Session("ID_Listino_Personalizzato"))
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@tmpIdSettore", tmpIdSettore.Text)
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@tmpIdCategoria", tmpIdCategoria.Text)
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@tmpIdTipologia", tmpIdTipologia.Text)
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@valuePromo", valuePromo)
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@ricarico", ricarico.ToString.Replace(",", "."))

                        Me.SqlData_Dettagli_Listino_Personalizzato.Insert()
                    End If
                Next

            Catch ex As Exception

            Finally

                If conn.State = ConnectionState.Open Then
                    conn.Close()
                    conn.Dispose()
                End If

            End Try
        Else
            Me.Label_Esito.Visible = True
            Me.Label_Esito.Text = "INSERIRE UN NOME AL LISTINO"
        End If
    End Sub

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Me.Label_Cambia_Esito.Visible = False
        Me.Label_Esito.Visible = False
    End Sub

    Protected Sub Page_PreLoad(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreLoad
        If Session.Item("UtentiID") > 0 Then
            Me.Panel_Principale.Visible = True
        End If
    End Sub

    Protected Sub Page_PreRender(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRender
        Me.GridView_ListinoSelezionato.Visible = True
        'Genero le select appropriate
        Me.SqlData_ListaListiniUtente.SelectCommand = "SELECT ID, Nome_Listino, ID_Utente FROM listini_personalizzati WHERE (ID_Utente = @utentiId)"
        Me.SqlData_ListaListiniUtente.SelectParameters.Clear()
        Me.SqlData_ListaListiniUtente.SelectParameters.add("@utentiId", Session.Item("UtentiID"))
        Me.SqlDataSource_ListinoSelezionato.SelectCommand = "SELECT ID, ID_Listino_Personalizzato, ID_Settore, ID_Categoria, ID_Tipologia, Promo, Ricarico FROM dettagli_listino_personalizzato WHERE (ID_Listino_Personalizzato = @listino)"
        Me.SqlDataSource_ListinoSelezionato.SelectParameters.Clear()
        Me.SqlDataSource_ListinoSelezionato.SelectParameters.add("@listino", Session("ID_Listino_Personalizzato"))

        'Salvo la selezione del listino sul postback della pagina
        Dim i As Integer
        For i = 0 To Me.DropDownList_ListiniUtente.Items.Count - 1
            If Me.DropDownList_ListiniUtente.Items(i).Value = Session("ID_Listino_Personalizzato") Then
                Me.DropDownList_ListiniUtente.SelectedIndex = i
            End If
        Next
    End Sub

    Protected Sub DropDownList_ListiniUtente_SelectedIndexChanged(ByVal sender As Object, ByVal e As System.EventArgs) Handles DropDownList_ListiniUtente.SelectedIndexChanged
        Session("ID_Listino_Personalizzato") = Me.DropDownList_ListiniUtente.SelectedValue
        Me.Azzera_Selezioni_Listino() 'Azzero le selezioni precedenti
    End Sub

    Protected Sub Button_AggiornaListino_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button_AggiornaListino.Click
        If (Me.TextBox_CambiaNomeListino.Text <> "") Then

            'Controllo che il nome_listino non sia già presente nella dropdownlist
            If (Me.DropDownList_ListiniUtente.SelectedItem.Text) <> Me.TextBox_CambiaNomeListino.Text Then
                Dim temp As Object
                temp = Me.DropDownList_ListiniUtente.Items.FindByText(Me.TextBox_CambiaNomeListino.Text)
                If Not (temp Is Nothing) Then
                    Me.Label_Cambia_Esito.Visible = True
                    Me.Label_Cambia_Esito.Text = "LISTINO GIA' PRESENTE - Inserire un nome diverso"
                    Return
                End If
            End If
            '////////////////////////////////////////////////////////////////////////

            Me.Label_Cambia_Esito.Visible = True

            Me.SqlData_Listino_Personalizzato.Update() 'Aggiorno il nome listino

            Me.Label_Cambia_Esito.Text = "LISTINO SALVATO CORRETTAMENTE"

            Try
                'Inserimento nel Database delle scelte effettuate sul nuovo listino selezionato

                Dim tmpPromo, tmpAttivo As CheckBox
                Dim tmpIdSettore, tmpIdCategoria, tmpIdTipologia As Label
                Dim tmpRicarico As TextBox

                Dim i, valuePromo As Integer

                Me.SqlData_Dettagli_Listino_Personalizzato.Delete() 'Cancella il listino personalizzato per poi inseire il nuovo e aggiornato

                For i = 0 To Me.GridView_ListinoCompleto.Rows.Count - 1
                    tmpAttivo = Me.GridView_ListinoCompleto.Rows(i).Cells(1).FindControl("CheckBox_Attivo")
                    If (tmpAttivo.Checked) Then
                        'riga del listino da inserire nel db
                        tmpIdSettore = Me.GridView_ListinoCompleto.Rows(i).Cells(0).FindControl("Label_IDSettore")
                        tmpIdCategoria = Me.GridView_ListinoCompleto.Rows(i).Cells(0).FindControl("Label_IDCategoria")
                        tmpIdTipologia = Me.GridView_ListinoCompleto.Rows(i).Cells(0).FindControl("Label_IDTipologia")
                        'Assegno 0 ai controlli che non hanno valore
                        If tmpIdSettore.Text = "" Then
                            tmpIdSettore.Text = "0"
                        End If
                        If tmpIdCategoria.Text = "" Then
                            tmpIdCategoria.Text = "0"
                        End If
                        If tmpIdTipologia.Text = "" Then
                            tmpIdTipologia.Text = "0"
                        End If
                        '////////////////////////////////////////////

                        tmpRicarico = Me.GridView_ListinoCompleto.Rows(i).Cells(2).FindControl("TextBox_Ricarico")
                        tmpPromo = Me.GridView_ListinoCompleto.Rows(i).Cells(3).FindControl("CheckBox_Promo")

                        valuePromo = 0
                        If (tmpPromo.Checked = True) Then
                            valuePromo = 1
                        End If

                        Dim ricarico As Double
                        tmpRicarico.Text = tmpRicarico.Text.Replace(".", ",")

                        ricarico = 0

                        Double.TryParse(tmpRicarico.Text, ricarico) 'Converto in Double il contenuto di tmpRicarico, se c'è testo il valore è zero

                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertCommand = "INSERT INTO dettagli_listino_personalizzato (ID_Listino_Personalizzato, ID_Settore, ID_Categoria, ID_Tipologia, Promo, Ricarico) VALUES ( @listino,@tmpIdSettore,@tmpIdCategoria,@tmpIdTipologia,@valuePromo,@ricarico)"
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.Clear()
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@listino", Session("ID_Listino_Personalizzato"))
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@tmpIdSettore", tmpIdSettore.Text)
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@tmpIdCategoria", tmpIdCategoria.Text)
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@tmpIdTipologia", tmpIdTipologia.Text)
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@valuePromo", valuePromo)
                        Me.SqlData_Dettagli_Listino_Personalizzato.InsertParameters.add("@ricarico", ricarico.ToString.Replace(",", "."))
                        Me.SqlData_Dettagli_Listino_Personalizzato.Insert()
                    End If
                Next

            Catch ex As Exception
                Response.Write("<script>alert(" & ex.Message & ");</script>")
            Finally

            End Try
        Else
            Me.Label_Cambia_Esito.Visible = True
            Me.Label_Cambia_Esito.Text = "INSERIRE UN NOME AL LISTINO"
        End If
    End Sub

    Protected Sub Page_PreRenderComplete(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.PreRenderComplete

        'Seleziono, se esiste, il primo valore della lista dei listni personalizzati
        If (Session("ID_Listino_Personalizzato") = 0) And (Me.DropDownList_ListiniUtente.Items.Count > 0) Then
            Session("ID_Listino_Personalizzato") = Me.DropDownList_ListiniUtente.Items(0).Value
            'Genero la Select
            Me.SqlDataSource_ListinoSelezionato.SelectCommand = "SELECT ID, ID_Listino_Personalizzato, ID_Settore, ID_Categoria, ID_Tipologia, Promo, Ricarico FROM dettagli_listino_personalizzato WHERE (ID_Listino_Personalizzato = @listino)"
            Me.SqlDataSource_ListinoSelezionato.SelectParameters.Clear()
            Me.SqlDataSource_ListinoSelezionato.SelectParameters.add("@listino", Session("ID_Listino_Personalizzato"))
        End If

        'Cancello le selezioni precedenti
        If Me.DropDownList_ListiniUtente.Items.Count > 0 Then
            Me.TextBox_CambiaNomeListino.Text = Me.DropDownList_ListiniUtente.SelectedItem.Text
        End If

        'Prelevo le selezioni effettuate precedentemente nel listino
        Dim i As Integer

        For i = 0 To (Me.GridView_ListinoSelezionato.Rows.Count) - 1
            Dim tmpSettore, tmpCategoria, tmpTipologia As String
            Dim trovato As Integer = 0
            Dim cont As Integer = 0
            tmpSettore = Me.GridView_ListinoSelezionato.Rows(i).Cells(2).Text
            tmpCategoria = Me.GridView_ListinoSelezionato.Rows(i).Cells(3).Text
            tmpTipologia = Me.GridView_ListinoSelezionato.Rows(i).Cells(4).Text

            While ((trovato = 0) And (cont < Me.GridView_ListinoCompleto.Rows.Count))
                If ((tmpSettore = CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDSettore"), Label).Text) And (tmpCategoria = CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDCategoria"), Label).Text) And (tmpTipologia = CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(0).FindControl("Label_IDTipologia"), Label).Text)) Then

                    'Coloro la celletta selezionata
                    Me.GridView_ListinoCompleto.Rows(cont).BackColor = Drawing.Color.GreenYellow
                    Me.GridView_ListinoCompleto.Rows(cont).ForeColor = Drawing.Color.Black
                    trovato = 1 'L'oggetto è stato trovato ed esco dal ciclo
                    CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(1).FindControl("CheckBox_Attivo"), CheckBox).Checked = True
                    CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(2).FindControl("TextBox_Ricarico"), TextBox).Text = Me.GridView_ListinoSelezionato.Rows(i).Cells(6).Text
                    If (Me.GridView_ListinoSelezionato.Rows(i).Cells(5).Text = 1) Then
                        CType(Me.GridView_ListinoCompleto.Rows(cont).Cells(3).FindControl("CheckBox_Promo"), CheckBox).Checked = True
                    End If
                End If
                cont = cont + 1
            End While
        Next

        Me.GridView_ListinoSelezionato.Visible = False 'Nascondo la griglia del listino selezionato
    End Sub
End Class
