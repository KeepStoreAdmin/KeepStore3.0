Imports Microsoft.VisualBasic
Imports System.Collections.Generic
Imports MySql.Data.MySqlClient
Imports System.Data

Public Class Settore
    Public id As String
    Public nome As String
    Public imgPath As String
	Public categorie As List(Of Categoria)
	Shared listaTipiSottoLivelli() As String = {"Tipologia"}

    Public Shared Function creaListaSettori() As List(Of Settore)
        Dim settori As New List(Of Settore)

        Dim conn As New MySqlConnection
        Dim cmd As New MySqlCommand
        conn.ConnectionString = ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString
        cmd.Connection = conn
        conn.Open()
        cmd.CommandType = CommandType.Text
        cmd.CommandText = "SELECT settori.Descrizione AS settore, settori.Img AS imgSettore, settori.id AS idSettore, categorie.Descrizione AS categoria, categorie.id AS idCategoria , tipologieAbilitate.Descrizione AS tipologia, tipologieAbilitate.id AS idTipologia FROM settori LEFT OUTER JOIN categorie ON settori.id = categorie.SettoriId LEFT OUTER JOIN (SELECT * FROM tipologie INNER JOIN (SELECT tipologieid, COUNT(id) numero FROM varticolibase GROUP BY varticolibase.TipologieId) articoli ON articoli.tipologieid = tipologie.id WHERE abilitato = 1) tipologieAbilitate ON categorie.id = tipologieAbilitate.categorieId WHERE (settori.Abilitato > 0) AND (categorie.Abilitato > 0) ORDER BY settori.Ordinamento, categorie.Ordinamento , tipologieAbilitate.Ordinamento"
        Dim dr As MySqlDataReader = cmd.ExecuteReader()
        
        If dr.HasRows Then
			dr.Read()
			creaDaSettore(dr, settori)
			
            While dr.Read()
				Dim settore As Settore = settori(settori.Count-1)
                If settore.nome = dr.Item("settore") Then
					Dim categoria As Categoria = settore.categorie(settore.categorie.Count-1)
					if categoria.nome = dr.Item("categoria") Then
						controllaSottoLivelli(dr, CType(categoria, SottoLivello), 0)
					Else
						creaDaCategoria(dr, settore)
					End If
                Else
                    creaDaSettore(dr, settori)
                End If
            End While

            dr.Close()
            conn.Close()
        End If
        Return settori
    End Function

	Shared Sub controllaSottoLivelli(ByRef dr As MySqlDataReader, ByRef sottoLivelloSuperiore As SottoLivello, ByVal indiceSottoLivello As Integer)
		Dim sottoLivello As SottoLivello = sottoLivelloSuperiore.sottoLivelli(sottoLivelloSuperiore.sottoLivelli.Count-1)
		Dim tipoSottoLivello As String = listaTipiSottoLivelli(indiceSottoLivello)
		if sottoLivello.nome = dr.Item(tipoSottoLivello) Then
			indiceSottoLivello+=1
			controllaSottoLivelli(dr, sottoLivello, indiceSottoLivello)
		Else
			creaDaSottoLivello(dr, sottoLivelloSuperiore, indiceSottoLivello)
		End If
	End Sub

	Shared Sub creaDaSettore(ByRef dr As MySqlDataReader, ByRef settori As List(Of Settore))
        Dim settore As New Settore
        settore.nome = dr.Item("settore")
        settore.id = dr.Item("idSettore")
        If dr.Item("imgSettore") Is System.DBNull.Value Then
            settore.imgPath = "settore_standard.jpg"
        Else
            settore.imgPath = dr.Item("imgSettore")
        End If
		settore.categorie = New List(Of Categoria)
        settori.Add(settore)
		creaDaCategoria(dr, settore)
	End Sub
	
	Shared Sub creaDaCategoria(ByRef dr As MySqlDataReader, ByRef settore As Settore)
		Dim categoria As New Categoria
        categoria.nome = dr.Item("categoria")
        categoria.id = dr.Item("idCategoria")
		categoria.sottoLivelli = New List(Of SottoLivello)
        settore.categorie.Add(categoria)
		creaDaSottoLivello(dr, CType(categoria, SottoLivello) , 0)
	End Sub

	Shared Sub creaDaSottoLivello(ByRef dr As MySqlDataReader, ByRef sottoLivelloSuperiore As SottoLivello, ByVal indiceSottoLivello As Integer)
		For i = indiceSottoLivello to listaTipiSottoLivelli.length - 1 
			Dim tipoSottoLivello As String = listaTipiSottoLivelli(i)
			'throw New System.Exception(sottoLivelloValido(dr, "tipologia"))
			if sottoLivelloValido(dr, tipoSottoLivello) Then
				Dim sottoLivello As SottoLivello = creaSottoLivello(dr, tipoSottoLivello, "id" & tipoSottoLivello)
				sottoLivello.sottoLivelli = New List(Of SottoLivello)
				sottoLivelloSuperiore.sottoLivelli.Add(sottoLivello)
				sottoLivelloSuperiore = sottoLivello
			Else
				Exit For
			End If
		Next
	End Sub

	Shared Function creaSottoLivello(ByRef dr As MySqlDataReader, ByVal tipoSottoLivello As String, ByVal id As String) As SottoLivello
		Dim sottoLivello As SottoLivello = New SottoLivello
        sottoLivello.nome = dr.Item(tipoSottoLivello)
        sottoLivello.id = dr.Item(id)
		sottoLivello.sottoLivelli = New List(Of SottoLivello)
		return sottoLivello
	End Function

	Shared Function sottoLivelloValido(ByRef dr As MySqlDataReader, ByVal tipoSottoLivello As String) As Boolean
		return dr.Item(tipoSottoLivello) IsNot System.DBNull.Value
	End Function

End Class
