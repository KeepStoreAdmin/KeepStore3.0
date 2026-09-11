USE `taikun`;
SELECT DATABASE() AS DatabaseSelezionato,
       CASE WHEN DATABASE()='taikun' THEN 'OK' ELSE 'STOP' END AS EsitoDatabase;

-- Pre-check read-only. Review these result sets and stop if any contract check fails.
SELECT ROUTINE_NAME, ROUTINE_TYPE,
       SHA2(ROUTINE_DEFINITION,256) AS definition_sha256,
       CASE WHEN SHA2(ROUTINE_DEFINITION,256)='a3e831a40e998c139b58b739a9392d5878da827af3648b0011b9ae84f6995004'
            THEN 1 ELSE 0 END AS historical_fingerprint_matches,
       DTD_IDENTIFIER AS signature_marker
FROM information_schema.routines
WHERE ROUTINE_SCHEMA='taikun' AND ROUTINE_NAME='Carrello_Documento';

SELECT ROUTINE_NAME AS UnexpectedAlternativeProcedure
FROM information_schema.routines
WHERE ROUTINE_SCHEMA='taikun'
  AND ROUTINE_NAME IN ('Carrello_Documento_WebV1','Carrello_Documento_InventoryV1');

-- Operator gate: do not continue unless the preceding checks are compliant.
-- DROP/CREATE is not transactional; no checkout may run during deployment.
DROP PROCEDURE `taikun`.`Carrello_Documento`;

DELIMITER $$
CREATE PROCEDURE `taikun`.`Carrello_Documento`(IN pLoginId INT(11), 
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
	DECLARE pQnt DOUBLE(15,3);
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
	SELECT ArticoliId, TCId, SUM(Qnt)
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

	SET finito=0;
	OPEN dtInventory;
	InventoryLoop: LOOP
		FETCH dtInventory INTO pArticoliId,pTCId,pQnt;
		IF finito=1 THEN LEAVE InventoryLoop; END IF;
		SET invFound=1;
		IF pArticoliId IS NULL OR pArticoliId<=0 OR pTCId IS NULL OR pQnt IS NULL OR pQnt<=0 THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ORDER_INVENTORY_INVALID';
		END IF;
		UPDATE articoli_giacenze
		SET Impegnata=COALESCE(Impegnata,0)+pQnt
		WHERE MagazziniId=1
		  AND ArticoliId=pArticoliId
		  AND TCId=pTCId
		  AND COALESCE(Giacenza,0)-COALESCE(Impegnata,0)>=pQnt;
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
	
	SELECT ImpegnaQnt 
		INTO impegna 
		FROM tipodocumenti 
		WHERE id=pTipoDoc;
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
		ValoreBuonoSconto=0,/*(pBuonoScontoTotale)*-1,*/
		Ordine_Web=1,
		utentiIndirizziId=pUtentiInirizzoId;
		SELECT last_insert_id() INTO IdDocumento;
/*	
	SELECT id
		INTO IdDocumento 
		FROM documenti 
		WHERE tipodocumentiId=pTipoDoc AND Ndocumento=ndoc AND DataDocumento=datadoc AND utentiid=idUtente;
*/		
	
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
			Qnt=pQnt,
			sc1=0,
			sc2=0,
			sc3=0,
			importo=pImporto,
			iva=IF((pUtenteAbilitatoRC=1) AND (pIdIvaRC>-1),pValoreIvaRC,IF(pidEsenzioneIva>-1,pValoreEsenzioneIva,parIva)),
			omaggio=0,
			movimento=0,
			movimentato=0,
			SpGratis=pProdottoGratis,
			MagazziniID=1,
			QntEvadibile=pQnt,
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
	
	/*Prelevo dal database le impostazioni per Causale_Trasporto, Causale_Porto, Causale_Aspetto*/
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
		TotaleDocumento=totdoc+pCostoSpedizione+pCostoAssicurazione+pCostoPagamento+pArrotondamento+pBuonoScontoTotale+((pBuonoScontoTotale/100)*pBuonoScontoValoreIva),
		TotMerce=ROUND(imponibile,2),
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
		
		/*INSERT INTO documentipie SET
		DocumentiId=idDocumento,
		TotSconto=pBuonoScontoTotale;*/
	END IF;
    END$$
DELIMITER ;
