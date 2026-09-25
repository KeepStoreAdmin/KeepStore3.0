-- SOLO su autorizzazione separata del Product Owner, dopo backup e analisi.
-- Elimina esclusivamente la tabella nuova; NON tocca aziende, Product o Offer.
-- Il rollback perde le configurazioni inserite nella tabella dopo il forward.
DROP TABLE `aziende_seo`;
