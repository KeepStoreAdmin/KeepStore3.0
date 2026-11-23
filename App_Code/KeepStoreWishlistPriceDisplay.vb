Option Strict On
Option Explicit On

Imports System
Imports System.Configuration
Imports System.Globalization
Imports System.Web
Imports MySql.Data.MySqlClient

' Prezzo mostrato nella pagina Preferiti (WISHLIST-PRICE-DISPLAY-1A).
' Un solo punto, nessun calcolo nuovo: il prezzo e quello che il carrello applichera a UN pezzo aggiunto dai Preferiti,
' cioe la stessa routine di prezzo del carrello (IVA dell'utente, override anche a zero, reverse charge, promo a livello
' articolo, date e proprietario dell'offerta) chiamata in sola lettura, senza transazione e senza blocchi, con la variante -1
' come fa l'acquisto dai Preferiti. Il contesto prezzi viene dal fornitore comune; se il contesto non e valido, se il listino
' della sessione non coincide, se il prezzo non e risolvibile o se qualsiasi cosa va storta, la scheda mostra "Prezzo su richiesta"
' e mai un numero. Le promozioni non producono barrato ne stato sconto: si mostra l'unico prezzo pagabile.
Public NotInheritable Class WishlistPriceDisplay

    Private Sub New()
    End Sub

    Public Shared Function PriceHtml(ByVal articleId As Integer) As String
        Try
            Dim ctx As HttpContext = HttpContext.Current
            If ctx Is Nothing OrElse articleId <= 0 Then Return UiPriceFormatter.PriceOnRequestHtml()

            Dim context As StorefrontPriceDisplayContext = StorefrontPriceDisplayContextProvider.GetCurrent(ctx)
            If context Is Nothing OrElse context.CompanyId <= 0 OrElse context.PriceListId <= 0 Then Return UiPriceFormatter.PriceOnRequestHtml()

            Dim listino As Integer = 0
            If ctx.Session IsNot Nothing AndAlso ctx.Session("listino") IsNot Nothing Then
                Integer.TryParse(Convert.ToString(ctx.Session("listino"), CultureInfo.InvariantCulture), listino)
            End If
            If listino <= 0 OrElse listino <> context.PriceListId Then Return UiPriceFormatter.PriceOnRequestHtml()

            Dim eligibility As ProductPromotionEligibilityContext = ProductPromotionEligibilityResolver.CreateContext(ctx, listino)
            If eligibility Is Nothing OrElse eligibility.CompanyId <> context.CompanyId Then Return UiPriceFormatter.PriceOnRequestHtml()

            Dim resolved As CartResolvedPrice
            Using conn As New MySqlConnection(ConfigurationManager.ConnectionStrings("EntropicConnectionString").ConnectionString)
                conn.Open()
                resolved = CartPriceRevalidationHelper.ResolveStandardPrice(ctx, conn, Nothing, eligibility, articleId, -1, 1D, listino, False)
            End Using
            If resolved Is Nothing OrElse Not resolved.IsValid OrElse resolved.HasTechnicalError OrElse resolved.HasCommercialRuleError Then
                Return UiPriceFormatter.PriceOnRequestHtml()
            End If

            Return UiPriceFormatter.RenderContextPriceHtml(resolved.Price, resolved.PriceIvato, Nothing, Nothing, 0, context)
        Catch ex As Exception
            Try
                KeepStoreLog.Error("wishlist-price", "Prezzo Preferiti non risolto: " & ex.GetType().Name, Nothing, HttpContext.Current)
            Catch
            End Try
            Return UiPriceFormatter.PriceOnRequestHtml()
        End Try
    End Function

End Class
