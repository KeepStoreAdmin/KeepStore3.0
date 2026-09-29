-- ESEGUIRE SOLO DOPO ROLLBACK PREFLIGHT OK E AUTORIZZAZIONE CHATGPT.
-- Confermare runtime pre-ksc2, registry vuota, zero righe ksc2 e backup.
-- DDL con commit impliciti: ALTER e DROP non sono una transazione atomica.
-- Non eseguire se il runtime ksc2 ha gia scritto dati, anche se ora sembrano vuoti.

ALTER TABLE `carrello`
  MODIFY COLUMN `SessionId` VARCHAR(50)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  ALGORITHM=COPY,
  LOCK=SHARED;

DROP TABLE `carrello_anonimo_persistenza`;
