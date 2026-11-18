# Canali social e di contatto — schermata del gestionale e adeguamento del database (per Germano e per Enzo)

Stato: **PROGETTO PRONTO, NON INSTALLATO** (richiesta del PO del 2026-11-18). Nessuna modifica e stata applicata a database reali: gli script qui sotto sono stati provati soltanto sul LAB locale, su copie ombra delle due tabelle. Disegno della schermata: [KEEPSTORE_SOCIAL_CHANNELS_SCREEN_MOCK.html](KEEPSTORE_SOCIAL_CHANNELS_SCREEN_MOCK.html) (si apre con un doppio clic).

## 1. A che cosa serve

Le tabelle `social_buttons` e `social_buttons_rules` esistono da anni in ogni database KeepStore, ma nessuna schermata del gestionale le gestisce: i valori furono scritti a mano. Dal 2026-11-18 il sito le usa di nuovo (PR 551):

- il **pulsante WhatsApp fisso** in basso su tutte le pagine (non nelle pagine di ordine e pagamento);
- **«Richiedi informazioni»** e **«Chiedi di essere avvisato»** nella scheda articolo, che aprono WhatsApp con l'articolo gia scritto nel messaggio.

Con questo progetto ogni azienda (per esempio azienda 1 e azienda 2) gestisce dal gestionale i propri canali: quali sono attivi, con quale numero o nome utente, in che ordine, e dove compaiono sul sito.

## 2. Guida per chi usa la schermata

Percorso proposto nel gestionale: **Utility → Canali social** (accanto a BannerWeb).

1. **Scegli l'azienda** in alto. Tutto cio che vedi sotto riguarda solo quella azienda.
2. **Riquadro «Pulsante di contatto sul sito»** (una sola riga di impostazioni per azienda):
   - **Attivo**: accende o spegne il pulsante fisso sul sito.
   - **Testo di invito**: la frase che descrive il pulsante (esempio: `Inviaci un messaggio`).
   - **Messaggio iniziale**: il testo gia scritto quando il cliente apre la conversazione (esempio: `Buongiorno, vi scrivo dal sito`). Vuoto = lo scrive il sito.
   - **Orari di risposta**: testo libero mostrato al cliente (esempio: `Lun-Ven 9-13 e 15-19`). Vuoto = non si mostra.
   - **Posizione**: Destra o Sinistra.
   - **Colore**: colore del pulsante (esempio `#128C7E`). Se il colore scelto rende illeggibile l'icona bianca, il sito usa il suo colore predefinito.
   - **Mostra su telefono / Mostra su computer**.
3. **Griglia «Canali»**: una riga per canale. Per ogni riga:
   - **Canale**: il nome (WhatsApp, Telegram, Instagram…).
   - **Valore**: il numero o il nome utente, **senza indirizzo completo** (vedi la tabella del punto 5.6). Per WhatsApp: numero in formato internazionale **senza `+` e senza spazi**, per esempio `393331234567`. Un numero scritto `333 1234567` viene rifiutato: senza prefisso il sito non puo sapere a quale nazione appartiene.
   - **Abilitato**: il canale e attivo.
   - **Ordine**: posizione nell'elenco (numero piu basso = prima).
   - **Pulsante fisso**: compare nel pulsante di contatto.
   - **Piede**: compare nel piede del sito fra i profili («Seguici»).
   - **Scheda articolo**: e offerto in «Richiedi informazioni».
   - **Etichetta**: testo facoltativo mostrato al cliente (esempio: `Assistenza vendite`).
4. **Nuovo / Modifica / Elimina / Salva / Annulla / Esporta**: come nelle altre griglie. Finche non premi **Salva** nulla cambia sul sito. Il sito rilegge i dati entro 10 minuti.
5. **Prova**: apre nel browser il collegamento del canale selezionato, per controllare che il valore sia giusto.

Regola pratica: **un solo canale WhatsApp abilitato per azienda**. Con due righe WhatsApp abilitate il sito non sa quale usare e non mostra il pulsante (la griglia lo impedisce).

## 3. La schermata (schema)

```
+--------------------------------------------------------------------------------------------------------------+
| Canali social                                                                                    _  []  X    |
+--------------------------------------------------------------------------------------------------------------+
| Azienda: [ AZIENDA UNO S.R.L.            v]                                                                  |
+- Pulsante di contatto sul sito ------------------------------------------------------------------------------+
| [x] Attivo   Testo di invito: [Inviaci un messaggio          ]   Posizione: [Destra v]   Colore: [#128C7E][.]|
| Messaggio iniziale: [Buongiorno, vi scrivo dal sito          ]   Orari di risposta: [Lun-Ven 9-13 e 15-19  ] |
| [x] Mostra su telefono   [x] Mostra su computer                                                              |
+--------------------------------------------------------------------------------------------------------------+
| [ ] | Canale     | Codice    | Valore        | Abilitato | Ordine | Pulsante fisso | Piede | Scheda | Etichetta|
|     | USA QUESTA RIGA PER FILTRARE I TUOI DATI                                                               |
| [ ] | WhatsApp   | whatsapp  | 393331234567  |    [x]    |   1    |      [x]       |  [ ]  |  [x]   |          |
| [ ] | Messenger  | facebook  | nomepagina    |    [x]    |   2    |      [x]       |  [x]  |  [ ]   |          |
| [ ] | Telegram   | telegram  |               |    [ ]    |   3    |      [x]       |  [ ]  |  [ ]   |          |
| [ ] | Instagram  | instagram |               |    [ ]    |  11    |      [ ]       |  [x]  |  [ ]   |          |
| ...                                                                                                          |
+--------------------------------------------------------------------------------------------------------------+
| Elemento: |<  <  1 di 18  >  >|                                                                              |
| [Nuovo] [Modifica] [Elimina] [Esporta] [Prova]                                  (in modifica: [Salva][Annulla])|
+--------------------------------------------------------------------------------------------------------------+
```

## 4. Che cosa cambia nel database (in breve)

Le due tabelle restano, con gli stessi nomi e le stesse colonne di oggi: si **allargano** alcuni campi e se ne **aggiungono** altri. Il sito gia pubblicato continua a funzionare prima e dopo la modifica (provato: la query del sito gira identica sulla forma nuova). Difetti di oggi che lo script corregge:

| Difetto di oggi | Conseguenza | Correzione |
|---|---|---|
| `company_id` e `tinyint(1)` | il connettore lo legge come vero/falso: l'azienda 2 diventa «1» | `INT` |
| `value` e lungo 32 caratteri | non ci sta un nome utente lungo o un indirizzo | 255 caratteri |
| `key` e lungo 12 caratteri, `social_name` 12 | non ci stanno i codici nuovi | 20 e 40 caratteri |
| `button_order` e `tinyint(1)` | stesso problema del vero/falso | `INT` |
| nessun vincolo su azienda + canale | si possono creare due righe WhatsApp | chiave unica |
| `social_buttons_rules` non ha `id` | la griglia standard (`AggiungiDati`) non la puo salvare | `id` autoincrementale + chiave unica sull'azienda |
| un solo uso possibile (pulsante fisso) | non si puo dire «questo va nel piede» | tre campi vero/falso |

## 5. Note per Enzo

### 5.1 Campi nuovi, dichiarati per esteso

Tabella `social_buttons` (ordine delle colonne dopo la modifica: `id`, `company_id`, `social_name`, `key`, `value`, `enabled`, `button_order`, `show_widget`, `show_footer`, `show_product`, `label_text`):

| Nome | Tipo | Lunghezza | Predefinito | NULL | Significato |
|---|---|---|---|---|---|
| `show_widget` | TINYINT | 1 | 1 | no | 1 = il canale compare nel pulsante di contatto fisso del sito |
| `show_footer` | TINYINT | 1 | 0 | no | 1 = il canale compare nel piede del sito fra i profili |
| `show_product` | TINYINT | 1 | 0 | no | 1 = il canale e offerto in «Richiedi informazioni» nella scheda articolo |
| `label_text` | VARCHAR | 60 | NULL | si | etichetta facoltativa mostrata al cliente |

Tabella `social_buttons_rules` (ordine dopo la modifica: `id`, `company_id`, `enabled`, `callToAction`, `buttonColor`, `position`, `welcomeMessage`, `openingHours`, `showOnMobile`, `showOnDesktop`):

| Nome | Tipo | Lunghezza | Predefinito | NULL | Significato |
|---|---|---|---|---|---|
| `id` | INT | — | autoincrementale | no | chiave primaria (prima la chiave era `company_id`) |
| `welcomeMessage` | VARCHAR | 255 | NULL | si | messaggio gia scritto all'apertura della conversazione |
| `openingHours` | VARCHAR | 120 | NULL | si | orari di risposta mostrati al cliente |
| `showOnMobile` | TINYINT | 1 | 1 | no | 1 = pulsante visibile su telefono |
| `showOnDesktop` | TINYINT | 1 | 1 | no | 1 = pulsante visibile su computer |

Campi esistenti che cambiano solo tipo o lunghezza: `social_buttons.company_id` (INT), `social_name` (40), `key` (20), `value` (255), `button_order` (INT, predefinito 0), `enabled` (predefinito 0); `social_buttons_rules.company_id` (INT), `enabled` (predefinito 0). I nomi seguono lo stile gia presente in ciascuna tabella; nessun commento `COMMENT` e nessun carattere speciale nelle dichiarazioni. I campi vero/falso restano `TINYINT(1)` perche la griglia li mostri come caselle.

Attenzione: `key` e una parola riservata di MySQL e `value`, `position` ed `enabled` sono parole chiave: nelle istruzioni scritte a mano vanno fra accenti gravi (`` `key` ``). Se il generatore delle stored non li mette, usare il testo del punto 5.4.

### 5.2 Script di adeguamento (forward)

Da eseguire **una volta, solo su `taikun`**; gli altri database li aggiorna il programma di allineamento. Nessun nome di database nel testo.

```sql
ALTER TABLE social_buttons
  MODIFY COLUMN company_id INT NOT NULL,
  MODIFY COLUMN social_name VARCHAR(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  MODIFY COLUMN `key` VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  MODIFY COLUMN `value` VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  MODIFY COLUMN enabled TINYINT(1) NOT NULL DEFAULT 0,
  MODIFY COLUMN button_order INT NOT NULL DEFAULT 0,
  ADD COLUMN show_widget TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN show_footer TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN show_product TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN label_text VARCHAR(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  ADD UNIQUE KEY uq_social_buttons_company_key (company_id, `key`);

ALTER TABLE social_buttons_rules
  MODIFY COLUMN company_id INT NOT NULL,
  DROP PRIMARY KEY,
  ADD COLUMN id INT NOT NULL AUTO_INCREMENT FIRST,
  ADD PRIMARY KEY (id),
  ADD UNIQUE KEY uq_social_buttons_rules_company (company_id),
  MODIFY COLUMN enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN welcomeMessage VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  ADD COLUMN openingHours VARCHAR(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  ADD COLUMN showOnMobile TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN showOnDesktop TINYINT(1) NOT NULL DEFAULT 1;

UPDATE social_buttons SET show_product = 1 WHERE `key` = 'whatsapp';

INSERT INTO social_buttons (company_id, social_name, `key`, `value`, enabled, button_order, show_widget, show_footer, show_product)
SELECT c.company_id, n.social_name, n.channel_key, NULL, 0, n.button_order, 0, 1, 0
FROM (SELECT DISTINCT company_id FROM social_buttons) c
CROSS JOIN (
  SELECT 'TikTok' AS social_name, 'tiktok' AS channel_key, 20 AS button_order
  UNION ALL SELECT 'YouTube', 'youtube', 21
  UNION ALL SELECT 'LinkedIn', 'linkedin', 22
  UNION ALL SELECT 'X', 'x', 23
  UNION ALL SELECT 'Threads', 'threads', 24
  UNION ALL SELECT 'Pinterest', 'pinterest', 25
) n
WHERE NOT EXISTS (SELECT 1 FROM social_buttons e WHERE e.company_id = c.company_id AND e.`key` = n.channel_key);
```

Prima di eseguirlo (preflight) questa interrogazione deve restituire zero righe, altrimenti la chiave unica fallisce (eliminare prima i doppioni):

```sql
SELECT company_id, `key`, COUNT(*) AS righe FROM social_buttons GROUP BY company_id, `key` HAVING COUNT(*) > 1;
```

### 5.3 Controllo (verify) e ritorno indietro (rollback)

```sql
-- verify: deve restituire 1, 1, 1
SELECT
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'social_buttons'
     AND COLUMN_NAME IN ('show_widget', 'show_footer', 'show_product', 'label_text')) = 4 AS campi_canali,
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'social_buttons_rules'
     AND COLUMN_NAME IN ('id', 'welcomeMessage', 'openingHours', 'showOnMobile', 'showOnDesktop')) = 5 AS campi_regole,
  (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN ('social_buttons', 'social_buttons_rules')
     AND COLUMN_NAME = 'company_id' AND DATA_TYPE = 'int') = 2 AS azienda_intera;
```

```sql
-- rollback: riporta le tabelle alla forma di prima. I canali nuovi vengono eliminati; valori piu lunghi di 32 caratteri vanno accorciati prima.
DELETE FROM social_buttons WHERE `key` IN ('tiktok', 'youtube', 'linkedin', 'x', 'threads', 'pinterest');

ALTER TABLE social_buttons
  DROP INDEX uq_social_buttons_company_key,
  DROP COLUMN show_widget, DROP COLUMN show_footer, DROP COLUMN show_product, DROP COLUMN label_text,
  MODIFY COLUMN company_id TINYINT(1) NOT NULL,
  MODIFY COLUMN social_name VARCHAR(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  MODIFY COLUMN `key` VARCHAR(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  MODIFY COLUMN `value` VARCHAR(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  MODIFY COLUMN enabled TINYINT(1) NOT NULL,
  MODIFY COLUMN button_order TINYINT(1) NOT NULL;

ALTER TABLE social_buttons_rules
  DROP COLUMN welcomeMessage, DROP COLUMN openingHours, DROP COLUMN showOnMobile, DROP COLUMN showOnDesktop,
  DROP INDEX uq_social_buttons_rules_company,
  DROP PRIMARY KEY,
  DROP COLUMN id,
  MODIFY COLUMN company_id TINYINT(1) NOT NULL,
  MODIFY COLUMN enabled TINYINT(1) NOT NULL,
  ADD PRIMARY KEY (company_id);
```

Prova fatta il 2026-11-18 sul LAB (MySQL 8.0.46, copia di `taikun` del 2026-11-17), su copie ombra delle due tabelle: forward riuscito (18 canali per azienda, WhatsApp con `show_product = 1`, regole con `id` 1 e 2), la query del sito pubblicato restituisce lo stesso risultato sulla forma nuova, rollback riuscito (colonne identiche all'originale, 24 righe). Le tabelle vere del LAB non sono state toccate.

### 5.4 Stored procedure per la griglia standard

`AggiungiDati(NomeStore, riga)` passa i valori delle colonne dalla seconda all'ultima, nell'ordine della tabella, e per ultimo l'`id`: le stored seguono quell'ordine (come `Newvettoricosti` e `Modvettoricosti`). Testo di riferimento (il `DEFINER` lo imposta l'allineamento), piu le righe corrispondenti in `sysparametristored` come per le altre stored.

```sql
CREATE PROCEDURE Newsocial_buttons(
  IN parcompany_id INT, IN parsocial_name VARCHAR(40), IN parkey VARCHAR(20), IN parvalue VARCHAR(255), IN parenabled TINYINT,
  IN parbutton_order INT, IN parshow_widget TINYINT, IN parshow_footer TINYINT, IN parshow_product TINYINT, IN parlabel_text VARCHAR(60),
  OUT parRetVal INT)
BEGIN
  INSERT INTO social_buttons SET
    company_id = parcompany_id, social_name = parsocial_name, `key` = parkey, `value` = parvalue, enabled = parenabled,
    button_order = parbutton_order, show_widget = parshow_widget, show_footer = parshow_footer, show_product = parshow_product,
    label_text = parlabel_text;
  SELECT MAX(id) INTO parRetVal FROM social_buttons;
END

CREATE PROCEDURE Modsocial_buttons(
  IN parcompany_id INT, IN parsocial_name VARCHAR(40), IN parkey VARCHAR(20), IN parvalue VARCHAR(255), IN parenabled TINYINT,
  IN parbutton_order INT, IN parshow_widget TINYINT, IN parshow_footer TINYINT, IN parshow_product TINYINT, IN parlabel_text VARCHAR(60),
  IN parId INT, OUT parRetVal INT)
BEGIN
  UPDATE social_buttons SET
    company_id = parcompany_id, social_name = parsocial_name, `key` = parkey, `value` = parvalue, enabled = parenabled,
    button_order = parbutton_order, show_widget = parshow_widget, show_footer = parshow_footer, show_product = parshow_product,
    label_text = parlabel_text
  WHERE id = parId;
  SET parRetVal = parId;
END

CREATE PROCEDURE Newsocial_buttons_rules(
  IN parcompany_id INT, IN parenabled TINYINT, IN parcallToAction VARCHAR(256), IN parbuttonColor VARCHAR(7), IN parposition VARCHAR(5),
  IN parwelcomeMessage VARCHAR(255), IN paropeningHours VARCHAR(120), IN parshowOnMobile TINYINT, IN parshowOnDesktop TINYINT,
  OUT parRetVal INT)
BEGIN
  INSERT INTO social_buttons_rules SET
    company_id = parcompany_id, enabled = parenabled, callToAction = parcallToAction, buttonColor = parbuttonColor, `position` = parposition,
    welcomeMessage = parwelcomeMessage, openingHours = paropeningHours, showOnMobile = parshowOnMobile, showOnDesktop = parshowOnDesktop;
  SELECT MAX(id) INTO parRetVal FROM social_buttons_rules;
END

CREATE PROCEDURE Modsocial_buttons_rules(
  IN parcompany_id INT, IN parenabled TINYINT, IN parcallToAction VARCHAR(256), IN parbuttonColor VARCHAR(7), IN parposition VARCHAR(5),
  IN parwelcomeMessage VARCHAR(255), IN paropeningHours VARCHAR(120), IN parshowOnMobile TINYINT, IN parshowOnDesktop TINYINT,
  IN parId INT, OUT parRetVal INT)
BEGIN
  UPDATE social_buttons_rules SET
    company_id = parcompany_id, enabled = parenabled, callToAction = parcallToAction, buttonColor = parbuttonColor, `position` = parposition,
    welcomeMessage = parwelcomeMessage, openingHours = paropeningHours, showOnMobile = parshowOnMobile, showOnDesktop = parshowOnDesktop
  WHERE id = parId;
  SET parRetVal = parId;
END
```

### 5.5 Maschera `frmCanaliSocial` (modello: `frmVettoriCosti`)

Controlli da disegnare (stesso `stdForm`, stessa barra `myRibbon`):

| Nome | Tipo | Dove |
|---|---|---|
| `grpAzienda` | `Janus.Windows.EditControls.UIGroupBox`, `Dock = Top`, altezza 46, testo `Azienda` | in alto |
| `cmbAzienda` | `Janus.Windows.EditControls.UIComboBox`, `ComboStyle = DropDownList` | dentro `grpAzienda` |
| `grpRegole` | `UIGroupBox`, `Dock = Top`, altezza 112, testo `Pulsante di contatto sul sito` | sotto `grpAzienda` |
| `chkAttivo`, `chkTelefono`, `chkComputer` | `Janus.Windows.EditControls.UICheckBox` | dentro `grpRegole` |
| `txtInvito` (max 256), `txtMessaggio` (max 255), `txtOrari` (max 120), `txtColore` (max 7) | `Janus.Windows.GridEX.EditControls.EditBox` | dentro `grpRegole` |
| `cmbPosizione` | `UIComboBox`, `DropDownList` | dentro `grpRegole` |
| `btnColore` | `Janus.Windows.EditControls.UIButton`, testo `...` | accanto a `txtColore` |
| `jDati` | `Janus.Windows.GridEX.GridEX`, `Dock = Fill`, `GroupByBoxVisible = False`, `FilterMode = Automatic` | centro |
| `jpExport` | `Janus.Windows.GridEX.Export.GridEXExporter` (`GridEX = jDati`, `SheetName = "Canali social"`) | componente |
| `dlgColore` | `System.Windows.Forms.ColorDialog` | componente |

Il pulsante **Prova** usa `btnVisualizza` della barra standard (testo `Prova`).

```vb
Imports System.Text.RegularExpressions
Imports Janus.Windows.GridEX

Public Class frmCanaliSocial
    Inherits stdForm

#Region "Variabili Locali"
    Private modificati As Boolean = False
    Private caricamento As Boolean = False
    Private dtRegole As DataTable = Nothing
    ' Codici dei canali che il sito riconosce. Altri codici restano salvati ma il sito li ignora.
    Private ReadOnly Codici() As String = {"whatsapp", "telegram", "facebook", "instagram", "call", "sms", "email", "link",
                                           "tiktok", "youtube", "linkedin", "x", "threads", "pinterest"}
#End Region

#Region "Form"
    Private Sub frmCanaliSocial_FormClosing(ByVal sender As Object, ByVal e As FormClosingEventArgs) Handles Me.FormClosing
        If modificati Then
            Select Case MyMsg("I dati sono stati modificati!" & vbNewLine & "Prima di uscire vuoi salvare?", frmInformation.TipoMessaggio.Domanda, , True, True, True)
                Case Windows.Forms.DialogResult.Yes
                    If Not SalvaDati() Then e.Cancel = True
                Case Windows.Forms.DialogResult.Cancel
                    e.Cancel = True
            End Select
        End If
    End Sub

    Private Sub frmCanaliSocial_Load(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Load
        jDati.VisualStyleManager = myVisualStyle
        grpAzienda.VisualStyleManager = myVisualStyle
        grpRegole.VisualStyleManager = myVisualStyle
    End Sub

    Private Sub frmCanaliSocial_Shown(ByVal sender As Object, ByVal e As EventArgs) Handles Me.Shown
        caricamento = True
        ' La chiave di aziende e (id, IvaTipo): una riga per id.
        CaricaCombo2(cmbAzienda, "Select id, min(RagioneSociale) as RagioneSociale from aziende group by id order by id", "RagioneSociale", "id", MyConnection, False)
        cmbPosizione.Items.Clear()
        cmbPosizione.Items.Add(New Janus.Windows.EditControls.UIComboBoxItem("Destra", "right"))
        cmbPosizione.Items.Add(New Janus.Windows.EditControls.UIComboBoxItem("Sinistra", "left"))
        If cmbAzienda.Items.Count > 0 Then cmbAzienda.SelectedIndex = 0
        caricamento = False
        Caricadati()
    End Sub

    Private Sub cmbAzienda_SelectedValueChanged(ByVal sender As Object, ByVal e As EventArgs) Handles cmbAzienda.SelectedValueChanged
        If caricamento Then Exit Sub
        If modificati AndAlso MyMsg("Ci sono modifiche non salvate: cambiare azienda le perde. Continuare?", frmInformation.TipoMessaggio.Domanda, , True, True) <> Windows.Forms.DialogResult.Yes Then Exit Sub
        Caricadati()
    End Sub
#End Region

#Region "Routine Locali"
    Private Function AziendaScelta() As Integer
        If Not TestVal(cmbAzienda.SelectedValue) Then Return 0
        Return CInt(cmbAzienda.SelectedValue)
    End Function

    Private Sub Caricadati()
        Dim azienda As Integer = AziendaScelta()
        If azienda <= 0 Then Exit Sub
        MyConnection.MostraMessaggio()
        CaricaGrigliaJanus4(jDati, String.Format("select * from social_buttons where company_id={0} order by button_order, id", azienda), True, True, "ListaCanaliSocial", True, 0, , , MyConnection)
        jDati.AllowEdit = InheritableBoolean.False
        jDati.AllowAddNew = InheritableBoolean.False
        With jDati.RootTable
            .Columns("company_id").Visible = False
            .Columns("social_name").Caption = "Canale"
            .Columns("key").Caption = "Codice"
            .Columns("value").Caption = "Valore"
            .Columns("value").Width = 220
            .Columns("enabled").Caption = "Abilitato"
            .Columns("button_order").Caption = "Ordine"
            .Columns("show_widget").Caption = "Pulsante fisso"
            .Columns("show_footer").Caption = "Piede"
            .Columns("show_product").Caption = "Scheda articolo"
            .Columns("label_text").Caption = "Etichetta"
            ' Il codice si sceglie da un elenco: niente codici scritti a mano con errori.
            .Columns("key").EditType = EditType.DropDownList
            .Columns("key").HasValueList = True
            .Columns("key").ValueList.Clear()
            For Each codice As String In Codici
                .Columns("key").ValueList.Add(codice, codice)
            Next
        End With
        CaricaRegole(azienda)
        MostraButton(True, True, True, False, False, False, False, False, True, True, False, False)
        btnVisualizza.Text = "Prova"
        modificati = False
        MyConnection.NascondiMessaggio()
    End Sub

    Private Sub CaricaRegole(ByVal azienda As Integer)
        caricamento = True
        dtRegole = MyConnection.GetDatatable(String.Format("select * from social_buttons_rules where company_id={0}", azienda))
        If dtRegole.Rows.Count = 0 Then
            ' Azienda senza impostazioni: riga nuova con i valori predefiniti (si salva con Newsocial_buttons_rules).
            Dim nuova As DataRow = dtRegole.NewRow
            nuova("company_id") = azienda
            nuova("enabled") = False
            nuova("callToAction") = "Inviaci un messaggio"
            nuova("buttonColor") = "#128C7E"
            nuova("position") = "right"
            nuova("showOnMobile") = True
            nuova("showOnDesktop") = True
            dtRegole.Rows.Add(nuova)
        End If
        Dim rw As DataRow = dtRegole.Rows(0)
        chkAttivo.Checked = TestVal(rw("enabled")) AndAlso CBool(rw("enabled"))
        txtInvito.Text = rw("callToAction").ToString
        txtMessaggio.Text = rw("welcomeMessage").ToString
        txtOrari.Text = rw("openingHours").ToString
        txtColore.Text = rw("buttonColor").ToString
        cmbPosizione.SelectedValue = If(rw("position").ToString.ToLower = "left", "left", "right")
        chkTelefono.Checked = Not TestVal(rw("showOnMobile")) OrElse CBool(rw("showOnMobile"))
        chkComputer.Checked = Not TestVal(rw("showOnDesktop")) OrElse CBool(rw("showOnDesktop"))
        AbilitaRegole(False)
        caricamento = False
    End Sub

    Private Sub AbilitaRegole(ByVal abilita As Boolean)
        For Each c As Control In grpRegole.Controls
            If Not TypeOf c Is Label Then c.Enabled = abilita
        Next
    End Sub

    ' Formato del valore per ogni codice: restituisce "" se va bene, altrimenti il messaggio da mostrare.
    Private Function ControllaValore(ByVal codice As String, ByVal valore As String) As String
        valore = valore.Trim
        Select Case codice
            Case "whatsapp", "sms"
                If Not Regex.IsMatch(valore, "^[1-9][0-9]{10,14}$") Then Return "Numero in formato internazionale senza + e senza spazi, da 11 a 15 cifre (esempio 393331234567)."
            Case "call"
                If Not Regex.IsMatch(valore, "^\+?[0-9]{6,15}$") Then Return "Numero di telefono di sole cifre, con o senza + iniziale."
            Case "email"
                If Not Regex.IsMatch(valore, "^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$") Then Return "Indirizzo e-mail non valido."
            Case "link"
                If Not Regex.IsMatch(valore, "^https://[^\s]+$") OrElse valore.Length > 255 Then Return "Indirizzo completo che inizia con https://."
            Case "linkedin"
                If Not Regex.IsMatch(valore, "^[A-Za-z0-9-]{2,100}$") Then Return "Solo il nome della pagina aziendale (esempio nome-azienda), senza indirizzo."
            Case "facebook"
                If Not Regex.IsMatch(valore, "^[A-Za-z0-9.]{3,80}$") Then Return "Nome utente o numero della pagina Facebook, senza indirizzo."
            Case Else
                If Not Regex.IsMatch(valore, "^[A-Za-z0-9._-]{2,60}$") Then Return "Solo il nome utente, senza @ e senza indirizzo."
        End Select
        Return String.Empty
    End Function

    Private Function ControllaRiga() As Boolean
        Dim codice As String = jDati.GetValue("key").ToString.Trim.ToLower
        If codice = String.Empty OrElse Array.IndexOf(Codici, codice) < 0 Then
            MyMsg("Scegliere il codice del canale dall'elenco!", frmInformation.TipoMessaggio.Attenzione, True, , , , 2500)
            Return False
        End If
        If jDati.GetValue("social_name").ToString.Trim = String.Empty Then
            MyMsg("Il nome del canale e obbligatorio!", frmInformation.TipoMessaggio.Attenzione, True, , , , 2500)
            Return False
        End If
        Dim abilitato As Boolean = TestVal(jDati.GetValue("enabled")) AndAlso CBool(jDati.GetValue("enabled"))
        Dim valore As String = jDati.GetValue("value").ToString
        If abilitato OrElse valore.Trim <> String.Empty Then
            Dim errore As String = ControllaValore(codice, valore)
            If errore <> String.Empty Then
                MyMsg(errore, frmInformation.TipoMessaggio.Attenzione, True, , , , 4000)
                Return False
            End If
        End If
        ' Un solo canale per codice e per azienda (la chiave unica del database lo impone comunque).
        Dim idCorrente As String = jDati.GetValue("id").ToString
        For Each rw As DataRow In CType(jDati.DataSource, DataTable).Rows
            If rw.RowState = DataRowState.Deleted Then Continue For
            If rw("key").ToString.ToLower = codice AndAlso rw("id").ToString <> idCorrente Then
                MyMsg("Questo canale esiste gia per l'azienda scelta!", frmInformation.TipoMessaggio.Attenzione, True, , , , 2500)
                Return False
            End If
        Next
        Return True
    End Function

    Private Function ControllaRegole() As Boolean
        If txtColore.Text.Trim <> String.Empty AndAlso Not Regex.IsMatch(txtColore.Text.Trim, "^#[0-9A-Fa-f]{6}$") Then
            MyMsg("Il colore va scritto come # seguito da sei cifre o lettere da A a F (esempio #128C7E).", frmInformation.TipoMessaggio.Attenzione, True, , , , 3000)
            Return False
        End If
        Return True
    End Function

    Private Function SalvaDati() As Boolean
        If Not ControllaRegole() Then Return False
        jDati.UpdateData()
        Dim dt As DataTable = jDati.DataSource
        Dim rg As DataRow = dtRegole.Rows(0)
        rg("enabled") = chkAttivo.Checked
        rg("callToAction") = txtInvito.Text.Trim
        rg("buttonColor") = txtColore.Text.Trim
        rg("position") = cmbPosizione.SelectedValue.ToString
        rg("welcomeMessage") = txtMessaggio.Text.Trim
        rg("openingHours") = txtOrari.Text.Trim
        rg("showOnMobile") = chkTelefono.Checked
        rg("showOnDesktop") = chkComputer.Checked

        MyConnection.OpenTransaction()
        For Each rw As DataRow In dt.Rows
            If rw.RowState = DataRowState.Deleted Then Continue For
            If Not AggiungiDati(If(rw("id").ToString = String.Empty, "Newsocial_buttons", "Modsocial_buttons"), rw, True) Then
                MyConnection.RollBackTrns()
                Return False
            End If
        Next
        If Not AggiungiDati(If(rg("id").ToString = String.Empty, "Newsocial_buttons_rules", "Modsocial_buttons_rules"), rg, True) Then
            MyConnection.RollBackTrns()
            Return False
        End If
        MyConnection.CommitTrns()
        modificati = False
        Return True
    End Function

    ' Stesso collegamento che costruisce il sito: serve a provare il valore.
    Private Function Collegamento(ByVal codice As String, ByVal valore As String) As String
        valore = valore.Trim
        Select Case codice
            Case "whatsapp" : Return "https://wa.me/" & valore
            Case "telegram" : Return "https://t.me/" & valore
            Case "facebook" : Return "https://m.me/" & valore
            Case "instagram" : Return "https://www.instagram.com/" & valore
            Case "tiktok" : Return "https://www.tiktok.com/@" & valore
            Case "youtube" : Return "https://www.youtube.com/@" & valore
            Case "linkedin" : Return "https://www.linkedin.com/company/" & valore
            Case "x" : Return "https://x.com/" & valore
            Case "threads" : Return "https://www.threads.net/@" & valore
            Case "pinterest" : Return "https://www.pinterest.com/" & valore
            Case "call" : Return "tel:" & valore
            Case "sms" : Return "sms:+" & valore
            Case "email" : Return "mailto:" & valore
            Case "link" : Return valore
        End Select
        Return String.Empty
    End Function
#End Region

#Region "Std Forms Events"
    Private Sub btnNuovo_Click(ByVal sender As Object, ByVal e As Janus.Windows.Ribbon.CommandEventArgs) Handles btnNuovo.Click
        Try
            jDati.AllowAddNew = InheritableBoolean.True
            jDati.AllowEdit = InheritableBoolean.True
            jDati.Row = -1
            AbilitaRegole(True)
            modificati = True
            MostraButton(False, False, False, False, True, True, False, False, False, False, False, False)
        Catch ex As Exception
            MyMsg("Errore :" & ex.Message, frmInformation.TipoMessaggio.Errore, , , , , 2500)
        End Try
    End Sub

    Private Sub btnModifica_Click(ByVal sender As Object, ByVal e As Janus.Windows.Ribbon.CommandEventArgs) Handles btnModifica.Click
        Try
            jDati.AllowEdit = InheritableBoolean.True
            AbilitaRegole(True)
            modificati = True
            MostraButton(False, False, False, False, True, True, False, False, False, False, False, False)
        Catch ex As Exception
            MyMsg("Errore :" & ex.Message, frmInformation.TipoMessaggio.Errore, , , , , 2500)
        End Try
    End Sub

    Private Sub btnElimina_Click(ByVal sender As Object, ByVal e As Janus.Windows.Ribbon.CommandEventArgs) Handles btnElimina.Click
        Try
            If MyMsg("Vuoi eliminare i canali selezionati?", frmInformation.TipoMessaggio.Domanda, , True, True) = Windows.Forms.DialogResult.Yes Then
                For Each rw As GridEXRow In jDati.GetCheckedRows
                    EliminaDato("social_buttons", "id=" & rw.Cells("id").Value, MyConnection, False)
                Next
                Caricadati()
            End If
        Catch ex As Exception
            MyMsg("Errore :" & ex.Message, frmInformation.TipoMessaggio.Errore, , , , , 2500)
        End Try
    End Sub

    Private Sub btnSalva_Click(ByVal sender As Object, ByVal e As Janus.Windows.Ribbon.CommandEventArgs) Handles btnSalva.Click
        Try
            If SalvaDati() Then
                MyMsg("Salvataggio completato! Il sito mostra le modifiche entro 10 minuti.", frmInformation.TipoMessaggio.Info, True, , , , 2500)
                Caricadati()
            Else
                MyMsg("Salvataggio fallito!", frmInformation.TipoMessaggio.Errore, True, , , , 1500)
            End If
        Catch ex As Exception
            MyMsg("Errore :" & ex.Message, frmInformation.TipoMessaggio.Errore, , , , , 2500)
        End Try
    End Sub

    Private Sub btnAnnulla_Click(ByVal sender As Object, ByVal e As Janus.Windows.Ribbon.CommandEventArgs) Handles btnAnnulla.Click
        Try
            Caricadati()
        Catch ex As Exception
            MyMsg("Errore :" & ex.Message, frmInformation.TipoMessaggio.Errore, , , , , 2500)
        End Try
    End Sub

    Private Sub btnEsporta_Click(ByVal sender As Object, ByVal e As Janus.Windows.Ribbon.CommandEventArgs) Handles btnEsporta.Click
        Try
            EsportGriglia(jpExport)
        Catch ex As Exception
            MyMsg("Errore :" & ex.Message, frmInformation.TipoMessaggio.Errore, , , , , 2500)
        End Try
    End Sub

    ' "Prova": apre il collegamento del canale selezionato.
    Private Sub btnVisualizza_Click(ByVal sender As Object, ByVal e As Janus.Windows.Ribbon.CommandEventArgs) Handles btnVisualizza.Click
        Try
            If jDati.RowCount = 0 OrElse jDati.GetRow Is Nothing Then Exit Sub
            Dim codice As String = jDati.GetValue("key").ToString.ToLower
            Dim valore As String = jDati.GetValue("value").ToString
            If ControllaValore(codice, valore) <> String.Empty Then
                MyMsg("Il valore di questo canale non e valido: correggerlo prima di provarlo.", frmInformation.TipoMessaggio.Attenzione, True, , , , 2500)
                Exit Sub
            End If
            Dim indirizzo As String = Collegamento(codice, valore)
            If indirizzo <> String.Empty Then Process.Start(indirizzo)
        Catch ex As Exception
            MyMsg("Errore :" & ex.Message, frmInformation.TipoMessaggio.Errore, , , , , 2500)
        End Try
    End Sub

    Private Sub btnColore_Click(ByVal sender As Object, ByVal e As EventArgs) Handles btnColore.Click
        If dlgColore.ShowDialog() = Windows.Forms.DialogResult.OK Then
            txtColore.Text = String.Format("#{0:X2}{1:X2}{2:X2}", dlgColore.Color.R, dlgColore.Color.G, dlgColore.Color.B)
        End If
    End Sub
#End Region

#Region "Eventi Janus"
    Private Sub jDati_AddingRecord(ByVal sender As Object, ByVal e As System.ComponentModel.CancelEventArgs) Handles jDati.AddingRecord
        jDati.SetValue("company_id", AziendaScelta())
        If Not TestVal(jDati.GetValue("enabled")) Then jDati.SetValue("enabled", False)
        If Not TestVal(jDati.GetValue("button_order")) Then jDati.SetValue("button_order", 0)
        If Not TestVal(jDati.GetValue("show_widget")) Then jDati.SetValue("show_widget", True)
        If Not TestVal(jDati.GetValue("show_footer")) Then jDati.SetValue("show_footer", False)
        If Not TestVal(jDati.GetValue("show_product")) Then jDati.SetValue("show_product", False)
        If Not ControllaRiga() Then e.Cancel = True
    End Sub

    Private Sub jDati_UpdatingRecord(ByVal sender As Object, ByVal e As System.ComponentModel.CancelEventArgs) Handles jDati.UpdatingRecord
        If Not ControllaRiga() Then e.Cancel = True
    End Sub
#End Region

End Class
```

Punti da adattare alla versione reale del gestionale (gli unici che non ho potuto provare, perche il gestionale non si compila su questa macchina): il costruttore di `UIComboBoxItem` e `ValueList.Add` di Janus (se la firma e diversa, usare `PopulateValueList` con una `DataTable` di codici, come in `frmSettori2`), e la voce di menu che apre la maschera.

### 5.6 Codici dei canali, formato del valore e collegamento costruito dal sito

| Codice (`key`) | Canale | Valore da scrivere | Esempio | Collegamento |
|---|---|---|---|---|
| `whatsapp` | WhatsApp | numero internazionale senza `+`, 11-15 cifre | `393331234567` | `https://wa.me/393331234567` |
| `telegram` | Telegram | nome utente | `nomeazienda` | `https://t.me/nomeazienda` |
| `facebook` | Messenger / pagina Facebook | nome o numero della pagina | `nomepagina` | chat `https://m.me/nomepagina`, profilo `https://www.facebook.com/nomepagina` |
| `instagram` | Instagram | nome utente | `nomeazienda` | `https://www.instagram.com/nomeazienda` |
| `call` | Telefonata | numero | `+39081123456` | `tel:+39081123456` |
| `sms` | SMS | numero internazionale senza `+` | `393331234567` | `sms:+393331234567` |
| `email` | E-mail | indirizzo | `info@esempio.it` | `mailto:info@esempio.it` |
| `link` | Collegamento libero | indirizzo completo `https://` | `https://esempio.it/pagina` | lo stesso indirizzo |
| `tiktok` | TikTok | nome utente | `nomeazienda` | `https://www.tiktok.com/@nomeazienda` |
| `youtube` | YouTube | nome del canale | `nomeazienda` | `https://www.youtube.com/@nomeazienda` |
| `linkedin` | LinkedIn | nome della pagina aziendale | `nome-azienda` | `https://www.linkedin.com/company/nome-azienda` |
| `x` | X | nome utente | `nomeazienda` | `https://x.com/nomeazienda` |
| `threads` | Threads | nome utente | `nomeazienda` | `https://www.threads.net/@nomeazienda` |
| `pinterest` | Pinterest | nome utente | `nomeazienda` | `https://www.pinterest.com/nomeazienda` |

I vecchi codici `viber`, `snapchat`, `line`, `vkontakte` restano nelle tabelle ma il sito non li usa: si possono lasciare spenti o eliminare.

### 5.7 Ordine di rilascio

1. Germano esegue lo script forward su `taikun` (preflight, forward, verify) e lancia l'allineamento.
2. Enzo aggiunge le quattro stored (con le righe di `sysparametristored`) e la maschera `frmCanaliSocial`.
3. Il sito pubblicato continua a funzionare in ogni momento: legge solo colonne che esistono sia prima sia dopo.
4. Il sito usera i campi nuovi (piu canali nel pulsante, profili nel piede, scelta del canale nella scheda articolo, orari e messaggio iniziale) con il task `SOCIAL-CHANNELS-2A`, **NON AVVIATO**: fino ad allora i campi nuovi si possono compilare ma non cambiano il sito.

## 6. Che cosa fara il sito con i campi nuovi (task `SOCIAL-CHANNELS-2A`, NON AVVIATO)

- **Pulsante di contatto**: con un solo canale resta il pulsante di oggi; con piu canali `show_widget` diventa un piccolo menu (WhatsApp, Telegram, Messenger, telefonata, e-mail) con testo di invito, orari di risposta e messaggio iniziale dell'azienda; rispetto di «Mostra su telefono / computer».
- **Piede del sito**: riga «Seguici» con i profili `show_footer`.
- **Scheda articolo**: «Richiedi informazioni» sui canali `show_product` (oggi solo WhatsApp).
- Sempre: azienda dall'indirizzo del sito, mai script di terzi, numeri e nomi validati prima di diventare un collegamento, nessun pulsante nelle pagine di ordine e pagamento.
