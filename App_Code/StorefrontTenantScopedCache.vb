Option Strict On
Option Explicit On

Imports System
Imports System.Collections.Generic
Imports System.Data
Imports System.Globalization
Imports System.Web

' Cache breve di dati letti dal database, con chiave SEMPRE delimitata: area + database configurato + azienda (+ chiave facoltativa
' come il listino). Regole (PO: nessuna cache che possa mescolare aziende o listini, nessuno stato tecnico memorizzato come assenza):
' - senza database, azienda o durata positivi non si usa la cache e si legge sempre dal database;
' - un loader che fallisce (eccezione o Nothing) NON viene memorizzato: il chiamante ricade sul comportamento senza dati;
' - un risultato valido ma vuoto (per esempio nessuna promozione) e un risultato e viene memorizzato come oggetto.
Public NotInheritable Class StorefrontTenantScopedCache
    Private Const KeyPrefix As String = "KeepStore.TenantScopedCache."

    Private Sub New()
    End Sub

    Public Shared Function BuildKey(ByVal area As String, ByVal databaseScopeKey As String,
                                    ByVal companyId As Integer, ByVal extraKey As String) As String
        If String.IsNullOrWhiteSpace(area) OrElse String.IsNullOrWhiteSpace(databaseScopeKey) OrElse companyId <= 0 Then Return String.Empty
        Return KeyPrefix & area.Trim() & "." & databaseScopeKey.Trim() & "." &
            companyId.ToString(CultureInfo.InvariantCulture) & "." & Convert.ToString(extraKey).Trim()
    End Function

    Public Shared Function GetOrLoad(Of T As Class)(ByVal area As String, ByVal databaseScopeKey As String,
                                                    ByVal companyId As Integer, ByVal extraKey As String,
                                                    ByVal ttlSeconds As Integer, ByVal loader As Func(Of T)) As T
        If loader Is Nothing Then Return Nothing
        Dim key As String = BuildKey(area, databaseScopeKey, companyId, extraKey)
        If key.Length = 0 OrElse ttlSeconds <= 0 Then Return SafeLoad(loader)

        Dim cached As T = TryCast(HttpRuntime.Cache(key), T)
        If cached IsNot Nothing Then Return cached

        Dim loaded As T = SafeLoad(loader)
        If loaded Is Nothing Then Return Nothing
        HttpRuntime.Cache.Insert(key, loaded, Nothing, DateTime.UtcNow.AddSeconds(ttlSeconds), System.Web.Caching.Cache.NoSlidingExpiration)
        Return loaded
    End Function

    Private Shared Function SafeLoad(Of T As Class)(ByVal loader As Func(Of T)) As T
        Try
            Return loader()
        Catch
            Return Nothing
        End Try
    End Function
End Class

' Promozione "spedizione gratuita da X" per azienda e listino: valida anche quando non c'e nessuna promozione.
Public NotInheritable Class FreeShippingPromoSnapshot
    Public ReadOnly HasPromo As Boolean
    Public ReadOnly MinAmount As Decimal

    Public Sub New(ByVal hasPromo As Boolean, ByVal minAmount As Decimal)
        Me.HasPromo = hasPromo AndAlso minAmount > 0D
        Me.MinAmount = If(Me.HasPromo, minAmount, 0D)
    End Sub
End Class

' Tabella letta una volta e consegnata SEMPRE come copia: l'originale in cache non viene mai modificato dai chiamanti.
Public NotInheritable Class StorefrontCachedTable
    Private ReadOnly _table As DataTable

    Public Sub New(ByVal table As DataTable)
        If table Is Nothing Then Throw New ArgumentNullException("table")
        _table = table.Copy()
    End Sub

    Public Function CopyTable() As DataTable
        Return _table.Copy()
    End Function
End Class
