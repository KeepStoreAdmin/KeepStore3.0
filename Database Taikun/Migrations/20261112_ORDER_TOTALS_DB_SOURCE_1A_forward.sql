-- ORDER-TOTALS-DB-SOURCE-1A (forward). No USE statement: the operator selects the target.
-- Never execute on production under the current mandate. Never use --force.
-- Carrello_Totali (read-only) is the single source of the document total arithmetic: Carrello_Documento calls it to write TotaleDocumento and TotMerce; the web can read the same numbers before the order exists.
-- Applies on top of ORDER-ROUNDING-HALF-UP-1A: the installed Carrello_Documento body must be the rounding body (hash gate).
-- Creates the read-only procedure Carrello_Totali first, then replaces Carrello_Documento so that it calls it.
-- DBA generates an execution copy replacing __KEEPSTORE_ORIGINAL_DEFINER__ (both procedures)
-- with the exact quoted original DEFINER, after SHOW CREATE SHA-256 comparison.
-- Privileges: Carrello_Documento (its DEFINER) must be able to EXECUTE Carrello_Totali and read vCarrello; the web account is not
-- changed in this phase (it calls Carrello_Documento only); a later phase where the web calls Carrello_Totali needs EXECUTE for it.
-- Contract of Carrello_Totali: OUT values are rounded separately, half away from zero, on exact DECIMAL sums; pTotIva is the rounded VAT
-- (goods, shipping, insurance and voucher), not documentipie.TotIva; an empty cart gives zero goods and the costs and voucher still count;
-- a NULL row amount, rate or cost propagates NULL as in the previous body. Single source: TotaleDocumento and TotMerce (not TotImponibile, TotIva).
-- DROP/CREATE is NOT transactional: on any failure restore the protected exact
-- original CREATE of Carrello_Documento, creation metadata and routine-specific grants before reopening checkout;
-- if Carrello_Documento was restored, Carrello_Totali may stay or be dropped.
-- DROP removes the routine-specific grants when automatic_sp_privileges is ON and CREATE regrants only the creator:
-- record the routine grants before, then re-apply and re-verify them after the CREATE, also on success, before reopening checkout.
-- The execution copy is LF text (hashes are over LF). Only the private byte-exact backup restores the previous body byte for byte.
-- Run with mysql batch mode WITHOUT --force; abort on the first error.
-- Required operator attestations are set only after private backup readback, grants
-- verification and exclusive checkout maintenance. They never replace those checks.
SET SESSION group_concat_max_len=4096;
SET @ks_totals_guard=(
 (@KeepStoreRoutineBackupVerified <=> 1) AND (@KeepStoreCheckoutQuiesced <=> 1)
 AND (@@server_uuid <=> @KeepStoreExpectedServerUuid)
 AND (DATABASE() <=> @KeepStoreExpectedDatabase)
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
      AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'
      AND SHA2(ROUTINE_DEFINITION,256) IN('9dc04290e8cdd4f377d462dca63bb063aa711dce389a547636733dc8441fd6ef')
      AND SECURITY_TYPE='DEFINER' AND DEFINER=@KeepStoreOriginalDefiner
      AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO' AND CHARACTER_SET_CLIENT='utf8mb4'
      AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci'
      AND DATABASE_COLLATION='utf8mb4_unicode_ci'
      AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='CONTAINS SQL' AND ROUTINE_COMMENT='')=1
 AND (SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE()
      AND SPECIFIC_NAME='Carrello_Documento' AND PARAMETER_MODE IN('IN','OUT'))=19
 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256)
      FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento')='953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa'
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Totali')=0
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti'
      AND ((COLUMN_NAME='id' AND COLUMN_KEY='PRI' AND EXTRA LIKE '%auto_increment%') OR COLUMN_NAME='NDocumento'))=2
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documentipie'
      AND COLUMN_NAME IN('TotaleDocumento','TotMerce') AND COLUMN_TYPE='double(15,5)')=2
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='vcarrello'
      AND COLUMN_NAME IN('LoginId','Importo','IdIvaRC','ValoreIvaRC','idEsenzioneIva','ValoreEsenzioneIva','Valoreiva'))=7
 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN('documenti','documentipie') AND ENGINE='InnoDB')=2);
SET @ks_totals_guard_sql=IF(@ks_totals_guard,'SELECT ''ORDER_TOTALS_PREFLIGHT_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_TOTALS_MIGRATION_PRECONDITION');
PREPARE ks_totals_guard_stmt FROM @ks_totals_guard_sql;
EXECUTE ks_totals_guard_stmt;
DEALLOCATE PREPARE ks_totals_guard_stmt;
SET @ks_totals_initial_sql_mode=@@SESSION.sql_mode;
SET @ks_totals_initial_charset_client=@@SESSION.character_set_client;
SET @ks_totals_initial_charset_results=@@SESSION.character_set_results;
SET @ks_totals_initial_collation=@@SESSION.collation_connection;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode='NO_AUTO_VALUE_ON_ZERO';
DELIMITER $$
CREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE `Carrello_Totali`(IN pLoginId INT(11),
 IN pCostoAssicurazione DOUBLE(15,5), IN pCostoSpedizione DOUBLE(15,5), IN pArrotondamento DOUBLE(15,5),
 IN pCostoPagamento DOUBLE(15,5), IN pUtenteAbilitatoRC INT(1), IN pIvaVettore DOUBLE(15,5),
 IN pBuonoScontoTotale DOUBLE(15,5), IN pBuonoScontoValoreIva DOUBLE(15,5),
 OUT pTotMerce DECIMAL(15,2), OUT pTotIva DECIMAL(15,2), OUT pTotale DECIMAL(15,2))
    READS SQL DATA
    SQL SECURITY DEFINER
BEGIN
	DECLARE righe INT DEFAULT 0;
	DECLARE righeImporto INT DEFAULT 0;
	DECLARE righeAliquota INT DEFAULT 0;
	DECLARE impExact DECIMAL(40,8);
	DECLARE ivaRighe DECIMAL(48,18);
	DECLARE ivaExact DECIMAL(48,18);
	DECLARE buonoIva DECIMAL(48,18);
	DECLARE totExact DECIMAL(48,18);

	SELECT COUNT(*), COUNT(Importo), COUNT(IF((pUtenteAbilitatoRC=1) AND (IdIvaRC>-1),ValoreIvaRC,IF(idEsenzioneIva>-1,ValoreEsenzioneIva,Valoreiva))),
		SUM(CAST(Importo AS DECIMAL(24,8))),
		SUM(CAST(Importo AS DECIMAL(24,8))*CAST(IF((pUtenteAbilitatoRC=1) AND (IdIvaRC>-1),ValoreIvaRC,IF(idEsenzioneIva>-1,ValoreEsenzioneIva,Valoreiva)) AS DECIMAL(12,8))*0.01)
		INTO righe, righeImporto, righeAliquota, impExact, ivaRighe
		FROM vCarrello
		WHERE LoginId=pLoginId;
	IF righe=0 THEN
		SET impExact=0;
		SET ivaRighe=0;
	ELSEIF righeImporto<righe THEN
		SET impExact=NULL;
		SET ivaRighe=NULL;
	ELSEIF righeAliquota<righe THEN
		SET ivaRighe=NULL;
	END IF;
	SET ivaExact=ivaRighe+(CAST(pCostoSpedizione AS DECIMAL(24,8))+CAST(pCostoAssicurazione AS DECIMAL(24,8)))*CAST(pIvaVettore AS DECIMAL(12,8))*0.01;
	SET buonoIva=CAST(pBuonoScontoTotale AS DECIMAL(24,8))*CAST(pBuonoScontoValoreIva AS DECIMAL(12,8))*0.01;
	SET totExact=impExact+ivaExact+CAST(pCostoSpedizione AS DECIMAL(24,8))+CAST(pCostoAssicurazione AS DECIMAL(24,8))+CAST(pCostoPagamento AS DECIMAL(24,8))+CAST(pArrotondamento AS DECIMAL(24,8))+CAST(pBuonoScontoTotale AS DECIMAL(24,8))+buonoIva;
	SET pTotMerce=ROUND(impExact,2);
	SET pTotIva=ROUND(ivaExact+buonoIva,2);
	SET pTotale=ROUND(totExact,2);
    END
$$
DELIMITER ;
DROP PROCEDURE Carrello_Documento;
DELIMITER $$
CREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE `Carrello_Documento`(IN pLoginId INT(11),
IN pTipoDoc INT(11), IN pTipoPagamento INT(11), IN pVettore INT(11), IN pUtentiInirizzoId INT(11),
 IN pCostoAssicurazione DOUBLE(15,5), IN pCostoSpedizione DOUBLE(15,5), IN pArrotondamento DOUBLE(15,5),
 IN pCostoPagamento DOUBLE(15,5), IN pNoteSpedizione VARCHAR(255), IN pUtenteAbilitatoRC INT(1), IN pIvaVettore DOUBLE(15,5), IN pStatiId INT(11),
 IN pBuonoScontoDescrizione VARCHAR(255), IN pBuonoScontoCodice VARCHAR(20), IN pBuonoScontoTotale DOUBLE(15,5), IN pBuonoScontoIdIVA INT(11),
 IN pBuonoScontoValoreIva DOUBLE(15,5), OUT DocumentoMemorizzato INT(11))
BEGIN
	DECLARE finito INT DEFAULT 0;
	DECLARE ndoc INT(11) DEFAULT 0;
	DECLARE datadoc DATE;
	DECLARE IdUtente INT(11);
	DECLARE	Azienda INT(11);
	DECLARE pRagioneSociale VARCHAR(200);
	DECLARE pCognomeNome VARCHAR(150);
	DECLARE pPiva VARCHAR(20);
	DECLARE pCodiceFiscale VARCHAR(20);
	DECLARE pIndirizzo VARCHAR(200);
	DECLARE pCitta VARCHAR(150);
	DECLARE pCap VARCHAR(6);
	DECLARE pProvincia VARCHAR(20);
	DECLARE pTelefono VARCHAR(50);
	DECLARE pFax VARCHAR(50);
	DECLARE pRagioneSocialeA VARCHAR(200);
	DECLARE pNomeA VARCHAR(200);
	DECLARE pIndirizzoA VARCHAR(200);
	DECLARE pCittaA VARCHAR(150);
	DECLARE pCapA VARCHAR(6);
	DECLARE pZonaA VARCHAR(200);
	DECLARE pNoteA VARCHAR(200);
	DECLARE pTelefonoA VARCHAR(50);
	DECLARE pFaxA VARCHAR(50);
	DECLARE pProvinciaA VARCHAR(20);
	DECLARE sede1 VARCHAR(255);
	DECLARE sede2 VARCHAR(255);
	DECLARE pArticoliId INT(11);
	DECLARE pTCId INT(11);
	DECLARE pEan VARCHAR(50);
	DECLARE pCodice VARCHAR(50);
	DECLARE pDescrizione1 VARCHAR(255);
	DECLARE pDescrizione2 VARCHAR(255);
	DECLARE pProdottoGratis INT(1);
	DECLARE pPeso DOUBLE(15,3);
	DECLARE pUmId INT(11);
	DECLARE pQnt DECIMAL(15,8);
	DECLARE pInventoryQnt DECIMAL(15,8);
	DECLARE pnListino INT(11);
	DECLARE pPrezzo DOUBLE(15,3);
	DECLARE parIva DOUBLE(15,3);
	DECLARE parValoreIva DOUBLE(15,3);
	DECLARE pImporto DOUBLE(15,3);
	DECLARE pImportoIvato DOUBLE(15,3);
	DECLARE IdDocumento INT(11);
	DECLARE pFido DOUBLE(15,3) DEFAULT 0;
	DECLARE impegna INT(11) DEFAULT 0;
	DECLARE imponibile DOUBLE(15,3) DEFAULT 0;
	DECLARE totpeso DOUBLE(15,3) DEFAULT 0;
	DECLARE totsconto DOUBLE(15,3) DEFAULT 0;
	DECLARE totdoc DOUBLE(15,3) DEFAULT 0;
	DECLARE	totiva DOUBLE(15,3) DEFAULT 0;
	DECLARE impTot DECIMAL(15,2);
	DECLARE ivaTot DECIMAL(15,2);
	DECLARE docTot DECIMAL(15,2);
	DECLARE trovato BOOLEAN DEFAULT FALSE;
	DECLARE DocTrovato INT(11);
	DECLARE pAgente INT(11) DEFAULT 0;
	DECLARE pSubAgente INT(11) DEFAULT 0;
	DECLARE pProvv1 DOUBLE(15,3) DEFAULT 0;
	DECLARE pProvv2 DOUBLE(15,3) DEFAULT 0;
	DECLARE idRiga INT(11);
	DECLARE Conto INT(11);
	DECLARE pDescrizioneIvaRC VARCHAR(100);
	DECLARE pIdIvaRC INT(11) DEFAULT -1;
	DECLARE pValoreIvaRC DOUBLE(15,3) DEFAULT -1;
	DECLARE pidEsenzioneIva INT(11) DEFAULT -1;
	DECLARE pValoreEsenzioneIva DOUBLE(15,3) DEFAULT -1;
	DECLARE pDescrizioneEsenzioneIva VARCHAR(100);
	DECLARE causaletrasportoid INT(11) DEFAULT -1;
	DECLARE causaleportoid INT(11) DEFAULT -1;
	DECLARE causaleaspettoid INT(11) DEFAULT -1;

	DECLARE invFound INT DEFAULT 0;

	DECLARE dtInventory CURSOR FOR
	SELECT ArticoliId, TCId, SUM(CAST(Qnt AS DECIMAL(15,8)))
		FROM carrello
		WHERE LoginId=pLoginId
		GROUP BY ArticoliId, TCId
		ORDER BY ArticoliId, TCId;

	DECLARE dtRighe CURSOR FOR
	SELECT id
		FROM documentirighe
		WHERE DocumentiId=IdDocumento;

	DECLARE dtConto CURSOR FOR
	SELECT ContoSpedizione
		FROM pagamentitipo
		WHERE id=pTipoPagamento;

	DECLARE dtCarrello CURSOR FOR
	SELECT articoliid,TCId,ean,codice,descrizione1,descrizione2,peso,umid,qnt,nListino,prezzo,iva,Valoreiva,Importo,ImportoIvato,Prodotto_Gratis,DescrizioneIvaRC,IdIvaRC,ValoreIvaRC,idEsenzioneIva,ValoreEsenzioneIva,DescrizioneEsenzioneIva
		FROM vCarrello
		WHERE loginId=pLoginId;
	DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET finito = 1;

	SET impegna=COALESCE((SELECT MAX(ImpegnaQnt) FROM tipodocumenti WHERE id=pTipoDoc AND Web=1),-1);
	IF impegna<>1 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ORDER_INVENTORY_INVALID';
	END IF;
	IF EXISTS (SELECT 1 FROM carrello WHERE LoginId=pLoginId AND (Qnt IS NULL OR Qnt<>ROUND(Qnt,5))) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ORDER_INVENTORY_INVALID';
	END IF;
	IF EXISTS (SELECT 1 FROM carrello c WHERE c.LoginId=pLoginId
		AND NOT EXISTS (SELECT 1 FROM vCarrello v WHERE v.id=c.id AND v.LoginId=pLoginId)) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ORDER_INVENTORY_INVALID';
	END IF;	SET finito=0;
	OPEN dtInventory;
	InventoryLoop: LOOP
		FETCH dtInventory INTO pArticoliId,pTCId,pInventoryQnt;
		IF finito=1 THEN LEAVE InventoryLoop; END IF;
		SET invFound=1;
		IF pArticoliId IS NULL OR pArticoliId<=0 OR pTCId IS NULL OR pInventoryQnt IS NULL OR pInventoryQnt<=0 THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ORDER_INVENTORY_INVALID';
		END IF;
		UPDATE articoli_giacenze
		SET Impegnata=COALESCE(Impegnata,0)+pInventoryQnt
		WHERE MagazziniId=1
		  AND ArticoliId=pArticoliId
		  AND TCId=pTCId
		  AND COALESCE(Giacenza,0)-COALESCE(Impegnata,0)>=pInventoryQnt;
		IF ROW_COUNT()<>1 THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ORDER_INVENTORY_UNAVAILABLE';
		END IF;
	END LOOP;
	CLOSE dtInventory;
	IF invFound=0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ORDER_INVENTORY_EMPTY_CART';
	END IF;

	OPEN dtCarrello;
	FETCH dtCarrello INTO pArticoliId,pTCId,pEan,pCodice,pDescrizione1,pdescrizione2,pPeso,pUmId,pQnt,pnListino,pPrezzo,parIva,parValoreIva,pImporto,pImportoIvato,pProdottoGratis,pDescrizioneIvaRC,pIdIvaRC,pValoreIvaRC,pidEsenzioneIva,pValoreEsenzioneIva,pDescrizioneEsenzioneIva;

	OPEN dtConto;
	FETCH dtConto INTO Conto;

	SELECT MAX(ndocumento) AS nmax
		INTO ndoc
		FROM documenti WHERE YEAR(datadocumento)=YEAR(CURRENT_TIMESTAMP) AND tipodocumentiid=pTipoDoc;
		IF ndoc IS NULL THEN
			SET ndoc=1;
		ELSE
			SET ndoc=ndoc+1;
		END IF;
		SET datadoc=CURRENT_TIMESTAMP;


	SELECT UtentiId,AziendeId INTO IdUtente,Azienda FROM vlogin WHERE id=pLoginId LIMIT 1;

	SELECT AgenteId,Provvigione1,SubAgenteId,Provvigione2 INTO pAgente,pProvv1,pSubAgente,pProvv2 FROM utentiagenti WHERE UtentiId=idUtente;

	SELECT RagioneSociale,CognomeNome,piva,codicefiscale,indirizzo,citta,cap,provincia,telefono,IFNULL(fax,'')
		INTO pRagioneSociale,pCognomeNome,pPiva,pCodiceFiscale,pIndirizzo,pCitta,pCap,pProvincia,pTelefono,pFax
		FROM utenti
		WHERE id=idUtente;
		SET sede1=CONCAT(pIndirizzo,CHAR(13),CHAR(10),pCap," ", pCitta," ",  pProvincia,CHAR(13),CHAR(10),"Tel. ",pTelefono,CHAR(13),CHAR(10),"Fax. ",pFax);

	IF pUtentiInirizzoId<>0 THEN
		SELECT IFNULL(RagioneSocialeA,''), NomeA, IndirizzoA,CittaA,CapA,ProvinciaA,Zona,Note,telefonoA,IFNULL(faxA,'')
			INTO pRagioneSocialeA, pNomeA, pIndirizzoA,pCittaA,pCapA,pProvinciaA,pZonaA,pNoteA,pTelefonoA,pFaxA
			FROM utentiindirizzi WHERE id=pUtentiInirizzoId LIMIT 1;
		SET sede2=CONCAT(pRagioneSocialeA," ", pNomeA,CHAR(13),CHAR(10), pIndirizzoA,CHAR(13),CHAR(10),pCapA," ", pCittaA," ",  pProvinciaA,CHAR(13),CHAR(10),pZonaA,CHAR(13),CHAR(10),"Tel. ",pTelefonoA,CHAR(13),CHAR(10),"Fax. ",pFaxA,CHAR(13),CHAR(10),pNoteA);

	ELSE
		SELECT IFNULL(RagioneSocialeA,''), NomeA, IndirizzoA, CittaA, CapA, ProvinciaA,telefonoA,IFNULL(faxA,'')
			INTO pRagioneSocialeA,pNomeA, pIndirizzoA, pCittaA, pCapA, pProvinciaA,pTelefonoA,pFaxA
			FROM utentiindirizzi WHERE utenteid=idUtente AND predefinito=1 LIMIT 1;
		SET sede2=CONCAT(pRagioneSocialeA," ", pNomeA,CHAR(13),CHAR(10),pIndirizzoA,CHAR(13),CHAR(10),pCapA," ", pCittaA," ",  pProvinciaA,CHAR(13),CHAR(10),"Tel. ",pTelefonoA,CHAR(13),CHAR(10),"Fax. ",pFaxA);
	END IF;


	WHILE NOT trovato DO
		SELECT ndocumento INTO DocTrovato
		FROM documenti
		WHERE YEAR(datadocumento) = YEAR(CURRENT_TIMESTAMP)
			AND tipodocumentiid=pTipoDoc
			AND ndocumento=ndoc;
		IF DocTrovato=ndoc THEN
			SET ndoc=ndoc+1;
		ELSE
			SET trovato=TRUE;
		END IF;
	END WHILE;

	IF ISNULL(pCognomeNome) THEN
		SET pCognomeNome='';
	END IF;
INSERT INTO documenti SET
		TipoDocumentiId=pTipoDoc,
		AziendeId=Azienda,
		NDocumento=ndoc,
		DataDocumento=datadoc,
		UtentiId=idUtente,
		Utente=CONCAT(pRagioneSociale,' ',pCognomeNome),
		SedeLegale=sede1,
		DestinazioneMerci=sede2,
		Piva=pPiva,
		CodiceFiscale=pCodiceFiscale,
		ScontoExtra=0,
		Fido=pFido,
		PagamentiTipoId=pTipoPagamento,
		Listino=pnlistino,
		AgentiId=pAgente,
		Provvigione=pProvv1,
		SubAgentiId=pSubAgente,
		Provvigione2=pProvv2,
		StatiId=pStatiId,
		NoteEsterne=pNoteSpedizione,
		Arrotondamento=pArrotondamento,
		CodiceBuonoSconto=pBuonoScontoCodice,
		ValoreBuonoSconto=0,
		Ordine_Web=1,
		utentiIndirizziId=pUtentiInirizzoId;
		SELECT last_insert_id() INTO IdDocumento;
		SELECT NDocumento INTO ndoc FROM documenti WHERE id=IdDocumento;


	Ciclo: REPEAT
		INSERT INTO documentirighe SET
			DocumentiId=IdDocumento,
			ArticoliId=pArticoliId,
			TCId=pTCId,
			Ean=pEan,
			Codice=pCodice,
			Descrizione1=pDescrizione1,
			um=pUmId,
			peso=pPeso,
			prezzo=pPrezzo,
			Qnt=CAST(pQnt AS DECIMAL(15,5)),
			sc1=0,
			sc2=0,
			sc3=0,
			importo=pImporto,
			iva=IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pIdIvaRC,IF(pidEsenzioneIva>-1,pidEsenzioneIva,parIva)),
			omaggio=0,
			movimento=0,
			movimentato=0,
			SpGratis=pProdottoGratis,
			MagazziniID=1,
			QntEvadibile=CAST(pQnt AS DECIMAL(15,5)),
			QntEvasa=0,
			IdConto=Conto,
			tiporiga='A';
			SET imponibile=imponibile+pImporto;
                        IF NOT ISNULL(pPeso) THEN
				SET totpeso=totpeso+(pPeso*pQnt);
			END IF;
			SET totsconto=0;
			SET totiva=totiva+IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pImporto*pValoreIvaRC/100,IF(pidEsenzioneIva>-1,pImporto*pValoreEsenzioneIva/100,pImporto*parValoreIva/100));
		SET finito=0;
		FETCH dtCarrello INTO pArticoliId,pTCId,pEan,pCodice,pDescrizione1,pdescrizione2,pPeso,pUmId,pQnt,pnListino,pPrezzo,parIva,parValoreIva,pImporto,pImportoIvato,pProdottoGratis,pDescrizioneIvaRC,pIdIvaRC,pValoreIvaRC,pidEsenzioneIva,pValoreEsenzioneIva,pDescrizioneEsenzioneIva;
        UNTIL finito=1
	END REPEAT Ciclo;


	SET finito=0;
	OPEN dtRighe;
	FETCH dtRighe INTO idRiga;
	Ciclo_2:REPEAT
		INSERT INTO documentiagenti SET
			DocumentiId=IdDocumento,
			documentirigheId=idRiga,
			AgenteId=pAgente,
			Provvigione1=pProvv1,
			SubAgenteId=pSubAgente,
			Provvigione2=pProvv2;
	SET finito=0;
	FETCH dtRighe INTO idRiga;
	UNTIL finito=1
	END REPEAT Ciclo_2;

	SET totiva=totiva+(pCostoSpedizione*pIvaVettore/100)+(pCostoAssicurazione*pIvaVettore/100);
	SET totdoc=ROUND(imponibile,2)+ROUND(totiva,2);
	CALL Carrello_Totali(pLoginId,pCostoAssicurazione,pCostoSpedizione,pArrotondamento,pCostoPagamento,pUtenteAbilitatoRC,pIvaVettore,pBuonoScontoTotale,pBuonoScontoValoreIva,impTot,ivaTot,docTot);


	SELECT CausaliAspettoId,CausaliPortoId,CausaliTrasportoId INTO causaleaspettoid,causaleportoid,causaletrasportoid FROM tipodocumenti WHERE tipodocumenti.`id` = pTipoDoc;

	INSERT INTO documentipie SET
		DocumentiId=idDocumento,
		costoassicurazione=pCostoAssicurazione,
		costospedizione=pCostoSpedizione,
		costopagamento=pCostoPagamento,
		VettoriId=pVettore,
		Peso=totpeso,
		CausaliTrasportoId=causaletrasportoid,
		CausaliPortoId=causaleportoid,
		CausaliAspettoId=causaleaspettoid,
		TotImponibile=Imponibile+pCostoSpedizione,
		TotSconto=totsconto,
		TotIva=totiva,
		TotaleDocumento=docTot,
		TotMerce=impTot,
		TotServizi=0,
		ScontoMerce=0,
		ScontoServizi=0,
		NettoMerce=TotMerce-totsconto,
		NettoServizi=0;
	DELETE FROM documentiplus WHERE documentiid=idDocumento;

	INSERT INTO documentiplus SET
		DocumentiId=idDocumento,
		Assicurazione=0,
		CalcolaAssicurazione=IF(pCostoAssicurazione>0,1,0),
		Pagamento=0,
		Spedizione=0;

	DELETE FROM carrello WHERE loginid=pLoginId;
	SET DocumentoMemorizzato=ndoc;

	INSERT INTO controllaArrotondamento SET
		DocumentiId=idDocumento;

	IF (pBuonoScontoTotale<0) THEN
		INSERT INTO documentirighe SET
		DocumentiId=IdDocumento,
		Codice='BUONOSCONTO',
		prezzo=pBuonoScontoTotale,
		qnt=1,
		um=-1,
		idConto=442,
		iva=pBuonoScontoIdIVA,
		importo=prezzo,
		Descrizione1=pBuonoScontoDescrizione,
		tiporiga='D';


	END IF;
    END
$$
DELIMITER ;
SET SESSION sql_mode=@ks_totals_initial_sql_mode;
SET SESSION character_set_client=@ks_totals_initial_charset_client;
SET SESSION character_set_results=@ks_totals_initial_charset_results;
SET SESSION collation_connection=@ks_totals_initial_collation;
SET SESSION group_concat_max_len=4096;
SET @ks_totals_guard=(
 (@KeepStoreRoutineBackupVerified <=> 1) AND (@KeepStoreCheckoutQuiesced <=> 1)
 AND (@@server_uuid <=> @KeepStoreExpectedServerUuid)
 AND (DATABASE() <=> @KeepStoreExpectedDatabase)
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
      AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE'
      AND SHA2(ROUTINE_DEFINITION,256) IN('7095b84d5a4f7cf9287d6e581f46d09626fa6e0874fd924f5efe927b52880bad')
      AND SECURITY_TYPE='DEFINER' AND DEFINER=@KeepStoreOriginalDefiner
      AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO' AND CHARACTER_SET_CLIENT='utf8mb4'
      AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci'
      AND DATABASE_COLLATION='utf8mb4_unicode_ci'
      AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='CONTAINS SQL' AND ROUTINE_COMMENT='')=1
 AND (SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE()
      AND SPECIFIC_NAME='Carrello_Documento' AND PARAMETER_MODE IN('IN','OUT'))=19
 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256)
      FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento')='953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa'
 AND (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE()
      AND ROUTINE_NAME='Carrello_Totali' AND ROUTINE_TYPE='PROCEDURE'
      AND SHA2(ROUTINE_DEFINITION,256) IN('68bec9adc80468dc35c73f14ec829e1b958cbc67a1240ceb4752e28cd29e5abc')
      AND SECURITY_TYPE='DEFINER' AND DEFINER=@KeepStoreOriginalDefiner
      AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO' AND CHARACTER_SET_CLIENT='utf8mb4'
      AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci'
      AND DATABASE_COLLATION='utf8mb4_unicode_ci'
      AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='READS SQL DATA' AND ROUTINE_COMMENT='')=1
 AND (SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE()
      AND SPECIFIC_NAME='Carrello_Totali' AND PARAMETER_MODE IN('IN','OUT'))=12
 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256)
      FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Totali')='ef869b823f7d7dc16305ac7862ef324c1dce34df6398c5bc1bdf743781ac1e60'
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti'
      AND ((COLUMN_NAME='id' AND COLUMN_KEY='PRI' AND EXTRA LIKE '%auto_increment%') OR COLUMN_NAME='NDocumento'))=2
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documentipie'
      AND COLUMN_NAME IN('TotaleDocumento','TotMerce') AND COLUMN_TYPE='double(15,5)')=2
 AND (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='vcarrello'
      AND COLUMN_NAME IN('LoginId','Importo','IdIvaRC','ValoreIvaRC','idEsenzioneIva','ValoreEsenzioneIva','Valoreiva'))=7
 AND (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN('documenti','documentipie') AND ENGINE='InnoDB')=2);
SET @ks_totals_guard_sql=IF(@ks_totals_guard,'SELECT ''ORDER_TOTALS_VERIFY_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_TOTALS_MIGRATION_PRECONDITION');
PREPARE ks_totals_guard_stmt FROM @ks_totals_guard_sql;
EXECUTE ks_totals_guard_stmt;
DEALLOCATE PREPARE ks_totals_guard_stmt;
