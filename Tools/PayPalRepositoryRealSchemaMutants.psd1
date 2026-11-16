@{
    # Mutazioni del meccanismo "lettura dei flag tinyint(1) indipendente dal tipo" (PAYPAL-TINYINT-FLAGS-1A).
    # Ogni voce altera UNA copia temporanea di un file di App_Code (mai il repository): File, Find (testo esatto), Replace, Occurrence (1 = prima, 2 = seconda).
    # Ognuna deve far fallire almeno un controllo in almeno una variante del connettore (TreatTinyAsBoolean true/false); altrimenti il test e troppo debole.
    # Le mutazioni "equivalenti" (non osservabili con dati validi) non sono elencate: il CHECK del DB ammette per CurrentSlot solo NULL o 1.
    Mutants = @(
        @{ Name = 'M01-safeint-no-boolean-branch'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'If TypeOf value Is Boolean Then Return If(CBool(value), 1, 0)'; Replace = "' mutated: Boolean branch removed" }
        @{ Name = 'M02-safeint-boolean-inverted'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'Return If(CBool(value), 1, 0)'; Replace = 'Return If(CBool(value), 0, 1)' }
        @{ Name = 'M03-account-flag-raw-document-query'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = '(a.Attivo=1) AccountActive'; Replace = 'a.Attivo AccountActive' }
        @{ Name = 'M04-account-flag-raw-company-query'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 2
           Find = '(a.Attivo=1) AccountActive'; Replace = 'a.Attivo AccountActive' }
        @{ Name = 'M05-mapping-flag-raw-document-query'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = '(c.Attivo=1) CompanyActive'; Replace = 'c.Attivo CompanyActive' }
        @{ Name = 'M06-mapping-flag-raw-company-query'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 2
           Find = '(c.Attivo=1) CompanyActive'; Replace = 'c.Attivo CompanyActive' }
        @{ Name = 'M07-account-flag-nonzero-document-query'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = '(a.Attivo=1) AccountActive'; Replace = '(a.Attivo<>0) AccountActive' }
        @{ Name = 'M08-mapping-flag-nonzero-company-query'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 2
           Find = '(c.Attivo=1) CompanyActive'; Replace = '(c.Attivo<>0) CompanyActive' }
        @{ Name = 'M09-account-active-always-true'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = '.AccountActive = SafeInt(dr("AccountActive")) = 1'; Replace = '.AccountActive = True' }
        @{ Name = 'M10-mapping-active-always-true'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = '.CompanyActive = SafeInt(dr("CompanyActive")) = 1'; Replace = '.CompanyActive = True' }
        @{ Name = 'M11-configured-ignores-account-flag'; File = 'PayPalCheckoutConfig.vb'; Occurrence = 1
           Find = 'AccountActive AndAlso CompanyActive AndAlso'; Replace = 'CompanyActive AndAlso' }
        @{ Name = 'M12-configured-ignores-mapping-flag'; File = 'PayPalCheckoutConfig.vb'; Occurrence = 1
           Find = 'AccountActive AndAlso CompanyActive AndAlso'; Replace = 'AccountActive AndAlso' }
        @{ Name = 'M13-iscurrent-always-false'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'info.IsCurrent = Not dr.IsDBNull(dr.GetOrdinal("CurrentSlot")) AndAlso SafeInt(dr("CurrentSlot")) = 1'; Replace = 'info.IsCurrent = False' }
        @{ Name = 'M14-iscurrent-always-true'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'info.IsCurrent = Not dr.IsDBNull(dr.GetOrdinal("CurrentSlot")) AndAlso SafeInt(dr("CurrentSlot")) = 1'; Replace = 'info.IsCurrent = True' }
        @{ Name = 'M15-apply-current-slot-never'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'currentSlot = Not reader.IsDBNull(0) AndAlso Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) = 1'; Replace = 'currentSlot = Not reader.IsDBNull(0) AndAlso Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) = -1' }
        @{ Name = 'M17-apply-current-slot-always'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'currentSlot = Not reader.IsDBNull(0) AndAlso Convert.ToInt32(reader(0), CultureInfo.InvariantCulture) = 1'; Replace = 'currentSlot = True' }
        @{ Name = 'M16-company-config-ignores-company'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'WHERE c.AziendeId=@azienda AND c.PagamentiTipoId=@pagamento LIMIT 1'; Replace = 'WHERE c.PagamentiTipoId=@pagamento LIMIT 1' }
        @{ Name = 'M18-apply-total-not-rounded'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'Math.Round(Convert.ToDecimal(reader(1), CultureInfo.InvariantCulture), 2, MidpointRounding.AwayFromZero) = tx.Importo'; Replace = 'Convert.ToDecimal(reader(1), CultureInfo.InvariantCulture) = tx.Importo' }
        @{ Name = 'M19-apply-total-rounded-to-even'; File = 'PayPalCheckoutRepository.vb'; Occurrence = 1
           Find = 'Math.Round(Convert.ToDecimal(reader(1), CultureInfo.InvariantCulture), 2, MidpointRounding.AwayFromZero) = tx.Importo'; Replace = 'Math.Round(Convert.ToDecimal(reader(1), CultureInfo.InvariantCulture), 2, MidpointRounding.ToEven) = tx.Importo' }
        @{ Name = 'M20-state-safeint-no-boolean-branch'; File = 'PayPalPaymentState.vb'; Occurrence = 1
           Find = 'If TypeOf value Is Boolean Then Return If(CBool(value), 1, 0)'; Replace = "' mutated: Boolean branch removed" }
        @{ Name = 'M21-state-safeint-boolean-inverted'; File = 'PayPalPaymentState.vb'; Occurrence = 1
           Find = 'Return If(CBool(value), 1, 0)'; Replace = 'Return If(CBool(value), 0, 1)' }
    )
}
