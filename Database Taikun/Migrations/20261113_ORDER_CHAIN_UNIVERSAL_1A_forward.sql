-- ORDER-CHAIN-UNIVERSAL-1A (forward). No USE statement: the operator selects the target database in the tool.
-- One standard text for every KeepStore database: it names no database, customer or domain. The only run-time input are the session
-- variables listed below and, in forward and rollback, the DEFINER slot (see DEFINER SLOT).
-- Run only by the Product Owner, one database at a time, after an explicit go for that database. Never use --force. Stop the script on the first error.
-- Text comparisons use a canonical form (CRLF as LF, trailing blanks and empty lines ignored; a lone CR is not): SQLyog removes the empty lines of a script, so the stored text differs from the file while the code is the same. Needs MySQL 8.0.17 or newer (REGEXP_REPLACE returns UTF-8 from 8.0.17), not MariaDB: checked below. The canonical form would equate two different multi-line string literals; no body has one (checked by Tools/Test-OrderChainUniversal.ps1): re-check that when a body changes.
-- Creates Carrello_Totali (read-only single source of the document total arithmetic), then replaces Carrello_Documento so that it calls it and carries the fixes of
-- ORDER-VAT-ID-SEMANTICS-P1 (documentirighe.iva stores the VAT id), ORDER-DOCUMENT-NUMBER-OUT-P0B (the number the database assigns is returned), ORDER-ROUNDING-HALF-UP
-- (half-up on exact DECIMAL sums) and ORDER-TOTALS-DB-SOURCE (TotaleDocumento and TotMerce from Carrello_Totali). The routine signature (19 parameters) does not change.
-- The original DEFINER, character set and collation of the installed Carrello_Documento are kept (read at run time).
-- DROP/CREATE is NOT transactional. If it fails AFTER 'DROP PROCEDURE Carrello_Documento', Carrello_Documento may be missing: do NOT reopen checkout; recreate it from the
-- private SHOW CREATE PROCEDURE backup, or run the rollback (it also starts from a missing Carrello_Documento when Carrello_Totali is the final one).
-- DROP removes routine-specific grants when automatic_sp_privileges is ON and CREATE regrants only the creator: re-apply and re-verify them, also on success.
-- Reopen checkout only after the verify script returns OK on every row AND the routine grants match the record taken before.
-- Run parameters (session variables, set in the SAME tab before this script, only after the private backup readback and with checkout closed):
--   SET @KeepStoreRoutineBackupVerified=1; SET @KeepStoreCheckoutQuiesced=1;
--   SET @KeepStoreExpectedServerUuid='<server uuid shown by the preflight>'; SET @KeepStoreExpectedDatabase='<database name shown by the preflight>';
-- They never replace the checks: they only confirm that the operator did them.
-- SQLyog: enable Halt Execution of Queries on Error before running (otherwise a failed guard does not stop the next statements) and, after any
-- STOP or error, close the connection before running anything else: the session keeps the temporary SQL mode, character set and variables.
-- DEFINER SLOT: MySQL cannot read a DEFINER at run time inside CREATE PROCEDURE (error 1295 with PREPARE), so the routines keep their original
-- DEFINER through ONE token. Before running, use Replace All in the editor: find __KEEPSTORE_ORIGINAL_DEFINER__, replace with the exact quoted
-- definer printed by the preflight (row 03, for example `user`@`host`). The script compares it with the installed routine before it drops
-- anything, checks the new Carrello_Totali against the original definer before the DROP, and checks both new routines against it at the end.
SET @ks_chain_init_gcml=@@SESSION.group_concat_max_len;
SET SESSION group_concat_max_len=4096;
SET @ks_ck_doc_text=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE' AND SHA2(REGEXP_REPLACE(REGEXP_REPLACE(CONVERT(REPLACE(ROUTINE_DEFINITION,CONCAT(CHAR(13),CHAR(10)),CHAR(10)) USING utf8mb4),CONCAT('[ ',CONVERT(CHAR(9) USING utf8mb4),']*',CONVERT(CHAR(10) USING utf8mb4)),CONVERT(CHAR(10) USING utf8mb4)),CONCAT(CONVERT(CHAR(10) USING utf8mb4),'+'),CONVERT(CHAR(10) USING utf8mb4)),256) IN ('9030ec6c06d33db5d0a5ce455ddb953d06ccd77e37ab43775ec4ce997494618a','351380c3c211ed7701747a95bbed0148cf03f995747ce4c18d3120a6c934a055','fdc6cb6f0200113382c4c40a882320eac55bff2c3699e0af5c8ca996dc4182d4'))=1,1,0);
SET @ks_ck_doc_attr=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE' AND SECURITY_TYPE='DEFINER' AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='CONTAINS SQL' AND ROUTINE_COMMENT='' AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO')=1,1,0);
SET @ks_ck_doc_meta=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE' AND ((CHARACTER_SET_CLIENT='utf8mb4' AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci') OR (CHARACTER_SET_CLIENT='utf8mb3' AND COLLATION_CONNECTION='utf8mb3_general_ci')))=1,1,0);
SET @ks_ck_doc_dbcoll=IF((SELECT COUNT(*) FROM information_schema.ROUTINES r JOIN information_schema.SCHEMATA s ON CONVERT(s.SCHEMA_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(r.ROUTINE_SCHEMA USING utf8mb4) COLLATE utf8mb4_bin WHERE r.ROUTINE_SCHEMA=DATABASE() AND r.ROUTINE_NAME='Carrello_Documento' AND r.ROUTINE_TYPE='PROCEDURE' AND CONVERT(r.DATABASE_COLLATION USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin)=1,1,0);
SET @ks_ck_doc_sig=IF((SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento' AND PARAMETER_MODE IN('IN','OUT'))=19 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento')='953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa' AND (SELECT COUNT(*) FROM information_schema.PARAMETERS q JOIN information_schema.SCHEMATA s ON CONVERT(s.SCHEMA_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(q.SPECIFIC_SCHEMA USING utf8mb4) COLLATE utf8mb4_bin WHERE q.SPECIFIC_SCHEMA=DATABASE() AND q.SPECIFIC_NAME='Carrello_Documento' AND q.CHARACTER_SET_NAME IS NOT NULL AND NOT (CONVERT(q.CHARACTER_SET_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_CHARACTER_SET_NAME USING utf8mb4) COLLATE utf8mb4_bin AND CONVERT(q.COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin))=0,1,0);
SET @ks_ck_doc_all=IF(@ks_ck_doc_text=1 AND @ks_ck_doc_attr=1 AND @ks_ck_doc_meta=1 AND @ks_ck_doc_dbcoll=1 AND @ks_ck_doc_sig=1,1,0);
SET @ks_ck_totali_absent=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Totali' AND ROUTINE_TYPE='PROCEDURE')=0,1,0);
SET @ks_ck_probe_absent=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='ks_chain_definer_probe' AND ROUTINE_TYPE='PROCEDURE')=0,1,0);
SET @ks_ck_t_documenti=IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documenti' AND ((COLUMN_NAME='id' AND COLUMN_KEY='PRI' AND EXTRA LIKE '%auto_increment%') OR COLUMN_NAME='NDocumento'))=2,1,0);
SET @ks_ck_t_pie=IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='documentipie' AND COLUMN_NAME IN('TotaleDocumento','TotMerce') AND COLUMN_TYPE='double(15,5)')=2,1,0);
SET @ks_ck_t_vcarrello=IF((SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='vcarrello' AND COLUMN_NAME IN('LoginId','Importo','IdIvaRC','ValoreIvaRC','idEsenzioneIva','ValoreEsenzioneIva','Valoreiva'))=7,1,0);
SET @ks_ck_t_engine=IF((SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN('documenti','documentipie') AND ENGINE='InnoDB')=2,1,0);
SET @ks_chain_ver=SUBSTRING_INDEX(VERSION(),'-',1);
SET @ks_ck_version=IF(VERSION() NOT LIKE '%MariaDB%' AND CAST(SUBSTRING_INDEX(@ks_chain_ver,'.',1) AS UNSIGNED)*10000+CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(@ks_chain_ver,'.',2),'.',-1) AS UNSIGNED)*100+CAST(SUBSTRING_INDEX(@ks_chain_ver,'.',-1) AS UNSIGNED)>=80017,1,0);
SET @ks_ck_attest=IF((@KeepStoreRoutineBackupVerified <=> 1) AND (@KeepStoreCheckoutQuiesced <=> 1) AND (@@server_uuid <=> @KeepStoreExpectedServerUuid) AND (DATABASE() <=> @KeepStoreExpectedDatabase),1,0);
SET @ks_ck_overall=IF(@ks_ck_doc_text=1 AND @ks_ck_doc_attr=1 AND @ks_ck_doc_meta=1 AND @ks_ck_doc_dbcoll=1 AND @ks_ck_doc_sig=1 AND @ks_ck_totali_absent=1 AND @ks_ck_probe_absent=1 AND @ks_ck_t_documenti=1 AND @ks_ck_t_pie=1 AND @ks_ck_t_vcarrello=1 AND @ks_ck_t_engine=1 AND @ks_ck_version=1 AND @ks_ck_attest=1,1,0);
SET @ks_chain_pre_sql=IF(@ks_ck_overall=1,'SELECT ''ORDER_CHAIN_FORWARD_PRECHECK_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_ORDER_CHAIN_PRECONDITION');
PREPARE ks_chain_pre_stmt FROM @ks_chain_pre_sql;
EXECUTE ks_chain_pre_stmt;
DEALLOCATE PREPARE ks_chain_pre_stmt;
SET @ks_chain_init_sql_mode=@@SESSION.sql_mode;
SET @ks_chain_init_cs=@@SESSION.character_set_client;
SET @ks_chain_init_rs=@@SESSION.character_set_results;
SET @ks_chain_init_co=@@SESSION.collation_connection;
SELECT CHARACTER_SET_CLIENT, COLLATION_CONNECTION, DEFINER INTO @ks_chain_cs, @ks_chain_co, @ks_chain_definer FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE';
SET SESSION sql_mode='NO_AUTO_VALUE_ON_ZERO';
SET SESSION character_set_client=@ks_chain_cs;
SET SESSION collation_connection=@ks_chain_co;
DELIMITER $$
CREATE DEFINER=__KEEPSTORE_ORIGINAL_DEFINER__ PROCEDURE `ks_chain_definer_probe`()
    SQL SECURITY DEFINER
BEGIN
    END
$$
DELIMITER ;
SET @ks_ck_slot=IF((SELECT COUNT(*) FROM information_schema.ROUTINES p JOIN information_schema.ROUTINES d ON BINARY p.DEFINER=BINARY d.DEFINER WHERE p.ROUTINE_SCHEMA=DATABASE() AND p.ROUTINE_NAME='ks_chain_definer_probe' AND p.ROUTINE_TYPE='PROCEDURE' AND d.ROUTINE_SCHEMA=DATABASE() AND d.ROUTINE_NAME='Carrello_Documento' AND d.ROUTINE_TYPE='PROCEDURE')=1,1,0);
DROP PROCEDURE `ks_chain_definer_probe`;
SET @ks_chain_slot_sql=IF(@ks_ck_slot=1,'SELECT ''ORDER_CHAIN_DEFINER_SLOT_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_ORDER_CHAIN_PRECONDITION');
PREPARE ks_chain_slot_stmt FROM @ks_chain_slot_sql;
EXECUTE ks_chain_slot_stmt;
DEALLOCATE PREPARE ks_chain_slot_stmt;
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
SET @ks_ck_totdef=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME IN ('Carrello_Totali') AND ROUTINE_TYPE='PROCEDURE' AND BINARY DEFINER=BINARY @ks_chain_definer)=1,1,0);
SET @ks_chain_totdef_sql=IF(@ks_ck_totdef=1,'SELECT ''ORDER_CHAIN_TOTALI_DEFINER_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_ORDER_CHAIN_PRECONDITION');
PREPARE ks_chain_totdef_stmt FROM @ks_chain_totdef_sql;
EXECUTE ks_chain_totdef_stmt;
DEALLOCATE PREPARE ks_chain_totdef_stmt;
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
SET SESSION sql_mode=@ks_chain_init_sql_mode;
SET SESSION character_set_client=@ks_chain_init_cs;
SET SESSION character_set_results=@ks_chain_init_rs;
SET SESSION collation_connection=@ks_chain_init_co;
SET SESSION group_concat_max_len=4096;
SET @ks_ck_doc_text=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE' AND SHA2(REGEXP_REPLACE(REGEXP_REPLACE(CONVERT(REPLACE(ROUTINE_DEFINITION,CONCAT(CHAR(13),CHAR(10)),CHAR(10)) USING utf8mb4),CONCAT('[ ',CONVERT(CHAR(9) USING utf8mb4),']*',CONVERT(CHAR(10) USING utf8mb4)),CONVERT(CHAR(10) USING utf8mb4)),CONCAT(CONVERT(CHAR(10) USING utf8mb4),'+'),CONVERT(CHAR(10) USING utf8mb4)),256) IN ('3c588f7d8966e208e9030d6d96c54f7ed865dfa6f6d022713f3d911ac5d87b0a'))=1,1,0);
SET @ks_ck_doc_attr=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE' AND SECURITY_TYPE='DEFINER' AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='CONTAINS SQL' AND ROUTINE_COMMENT='' AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO')=1,1,0);
SET @ks_ck_doc_meta=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Documento' AND ROUTINE_TYPE='PROCEDURE' AND ((CHARACTER_SET_CLIENT='utf8mb4' AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci') OR (CHARACTER_SET_CLIENT='utf8mb3' AND COLLATION_CONNECTION='utf8mb3_general_ci')))=1,1,0);
SET @ks_ck_doc_dbcoll=IF((SELECT COUNT(*) FROM information_schema.ROUTINES r JOIN information_schema.SCHEMATA s ON CONVERT(s.SCHEMA_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(r.ROUTINE_SCHEMA USING utf8mb4) COLLATE utf8mb4_bin WHERE r.ROUTINE_SCHEMA=DATABASE() AND r.ROUTINE_NAME='Carrello_Documento' AND r.ROUTINE_TYPE='PROCEDURE' AND CONVERT(r.DATABASE_COLLATION USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin)=1,1,0);
SET @ks_ck_doc_sig=IF((SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento' AND PARAMETER_MODE IN('IN','OUT'))=19 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Documento')='953b867c730f382dfc87975f3bd74a417e3946b3c977ce2075e8043134c6aaaa' AND (SELECT COUNT(*) FROM information_schema.PARAMETERS q JOIN information_schema.SCHEMATA s ON CONVERT(s.SCHEMA_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(q.SPECIFIC_SCHEMA USING utf8mb4) COLLATE utf8mb4_bin WHERE q.SPECIFIC_SCHEMA=DATABASE() AND q.SPECIFIC_NAME='Carrello_Documento' AND q.CHARACTER_SET_NAME IS NOT NULL AND NOT (CONVERT(q.CHARACTER_SET_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_CHARACTER_SET_NAME USING utf8mb4) COLLATE utf8mb4_bin AND CONVERT(q.COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin))=0,1,0);
SET @ks_ck_doc_all=IF(@ks_ck_doc_text=1 AND @ks_ck_doc_attr=1 AND @ks_ck_doc_meta=1 AND @ks_ck_doc_dbcoll=1 AND @ks_ck_doc_sig=1,1,0);
SET @ks_ck_tot_text=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Totali' AND ROUTINE_TYPE='PROCEDURE' AND SHA2(REGEXP_REPLACE(REGEXP_REPLACE(CONVERT(REPLACE(ROUTINE_DEFINITION,CONCAT(CHAR(13),CHAR(10)),CHAR(10)) USING utf8mb4),CONCAT('[ ',CONVERT(CHAR(9) USING utf8mb4),']*',CONVERT(CHAR(10) USING utf8mb4)),CONVERT(CHAR(10) USING utf8mb4)),CONCAT(CONVERT(CHAR(10) USING utf8mb4),'+'),CONVERT(CHAR(10) USING utf8mb4)),256) IN ('57937c7eb1b0438bf15ddc94601ccc53df630c7b82db68421919c0345fd13da0'))=1,1,0);
SET @ks_ck_tot_attr=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Totali' AND ROUTINE_TYPE='PROCEDURE' AND SECURITY_TYPE='DEFINER' AND IS_DETERMINISTIC='NO' AND SQL_DATA_ACCESS='READS SQL DATA' AND ROUTINE_COMMENT='' AND SQL_MODE='NO_AUTO_VALUE_ON_ZERO')=1,1,0);
SET @ks_ck_tot_meta=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='Carrello_Totali' AND ROUTINE_TYPE='PROCEDURE' AND ((CHARACTER_SET_CLIENT='utf8mb4' AND COLLATION_CONNECTION='utf8mb4_0900_ai_ci') OR (CHARACTER_SET_CLIENT='utf8mb3' AND COLLATION_CONNECTION='utf8mb3_general_ci')))=1,1,0);
SET @ks_ck_tot_dbcoll=IF((SELECT COUNT(*) FROM information_schema.ROUTINES r JOIN information_schema.SCHEMATA s ON CONVERT(s.SCHEMA_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(r.ROUTINE_SCHEMA USING utf8mb4) COLLATE utf8mb4_bin WHERE r.ROUTINE_SCHEMA=DATABASE() AND r.ROUTINE_NAME='Carrello_Totali' AND r.ROUTINE_TYPE='PROCEDURE' AND CONVERT(r.DATABASE_COLLATION USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin)=1,1,0);
SET @ks_ck_tot_sig=IF((SELECT COUNT(*) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Totali' AND PARAMETER_MODE IN('IN','OUT'))=12 AND (SELECT SHA2(GROUP_CONCAT(CONCAT_WS(':',ORDINAL_POSITION,PARAMETER_MODE,PARAMETER_NAME,DATA_TYPE,COALESCE(CHARACTER_MAXIMUM_LENGTH,''),COALESCE(NUMERIC_PRECISION,''),COALESCE(NUMERIC_SCALE,'')) ORDER BY ORDINAL_POSITION SEPARATOR '|'),256) FROM information_schema.PARAMETERS WHERE SPECIFIC_SCHEMA=DATABASE() AND SPECIFIC_NAME='Carrello_Totali')='ef869b823f7d7dc16305ac7862ef324c1dce34df6398c5bc1bdf743781ac1e60' AND (SELECT COUNT(*) FROM information_schema.PARAMETERS q JOIN information_schema.SCHEMATA s ON CONVERT(s.SCHEMA_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(q.SPECIFIC_SCHEMA USING utf8mb4) COLLATE utf8mb4_bin WHERE q.SPECIFIC_SCHEMA=DATABASE() AND q.SPECIFIC_NAME='Carrello_Totali' AND q.CHARACTER_SET_NAME IS NOT NULL AND NOT (CONVERT(q.CHARACTER_SET_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_CHARACTER_SET_NAME USING utf8mb4) COLLATE utf8mb4_bin AND CONVERT(q.COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin=CONVERT(s.DEFAULT_COLLATION_NAME USING utf8mb4) COLLATE utf8mb4_bin))=0,1,0);
SET @ks_ck_tot_all=IF(@ks_ck_tot_text=1 AND @ks_ck_tot_attr=1 AND @ks_ck_tot_meta=1 AND @ks_ck_tot_dbcoll=1 AND @ks_ck_tot_sig=1,1,0);
SET @ks_ck_probe_absent=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME='ks_chain_definer_probe' AND ROUTINE_TYPE='PROCEDURE')=0,1,0);
SET @ks_ck_definer_same=IF((SELECT COUNT(*) FROM information_schema.ROUTINES a JOIN information_schema.ROUTINES b ON BINARY a.DEFINER=BINARY b.DEFINER WHERE a.ROUTINE_SCHEMA=DATABASE() AND a.ROUTINE_NAME='Carrello_Documento' AND a.ROUTINE_TYPE='PROCEDURE' AND b.ROUTINE_SCHEMA=DATABASE() AND b.ROUTINE_NAME='Carrello_Totali' AND b.ROUTINE_TYPE='PROCEDURE')=1,1,0);
SET @ks_ck_meta_same=IF((SELECT COUNT(*) FROM information_schema.ROUTINES a JOIN information_schema.ROUTINES b ON BINARY a.CHARACTER_SET_CLIENT=BINARY b.CHARACTER_SET_CLIENT AND BINARY a.COLLATION_CONNECTION=BINARY b.COLLATION_CONNECTION WHERE a.ROUTINE_SCHEMA=DATABASE() AND a.ROUTINE_NAME='Carrello_Documento' AND a.ROUTINE_TYPE='PROCEDURE' AND b.ROUTINE_SCHEMA=DATABASE() AND b.ROUTINE_NAME='Carrello_Totali' AND b.ROUTINE_TYPE='PROCEDURE')=1,1,0);
SET @ks_ck_definer_orig=IF((SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() AND ROUTINE_NAME IN ('Carrello_Documento','Carrello_Totali') AND ROUTINE_TYPE='PROCEDURE' AND BINARY DEFINER=BINARY @ks_chain_definer)=2,1,0);
SET @ks_ck_final=IF(@ks_ck_doc_all=1 AND @ks_ck_tot_all=1 AND @ks_ck_probe_absent=1 AND @ks_ck_definer_same=1 AND @ks_ck_meta_same=1 AND @ks_ck_definer_orig=1,1,0);
SET @ks_chain_post_sql=IF(@ks_ck_final=1,'SELECT ''ORDER_CHAIN_FORWARD_A''','SELECT * FROM information_schema.KEEPSTORE_STOP_ORDER_CHAIN_PRECONDITION');
PREPARE ks_chain_post_stmt FROM @ks_chain_post_sql;
EXECUTE ks_chain_post_stmt;
DEALLOCATE PREPARE ks_chain_post_stmt;
SET SESSION group_concat_max_len=@ks_chain_init_gcml;
