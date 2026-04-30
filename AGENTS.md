# KeepStore – Istruzioni permanenti per Codex AI

## Contesto repository

Questo progetto usa tre repository principali.

### 1. Vecchio sito funzionante / riferimento storico

Repository:

https://github.com/KeepStoreAdmin/Entropic/tree/main

Sito online:

https://www.webaffare.it/

Questo repository e il sito online sono il riferimento della logica originale funzionante.

Quando una pagina ASPX/VB, una query, una funzione o un comportamento non sono chiari nel progetto attuale, confrontare sempre con Entropic e, se utile, con il comportamento visibile su webaffare.it.

### 2. Sito attuale da modificare

Repository:

https://github.com/KeepStoreAdmin/KeepStore3.0/tree/main

Questo è il repository principale su cui applicare le modifiche.

### 3. Repository materiali, template, SQL e risorse

Repository:

https://github.com/KeepStoreAdmin/KeepStore_web/tree/main

Da qui recuperare template, ZIP, SQL, liste tabelle, asset, immagini, documentazione, file di supporto e materiali utili.

---

## Regola generale

Non riscrivere KeepStore da zero.

L’obiettivo è correggere, integrare e ottimizzare il progetto mantenendo la logica applicativa esistente.

Quando si lavora su pagine ASPX/VB:

1. leggere prima il codice attuale in KeepStore3.0;
2. capire il flusso esistente;
3. confrontare con Entropic se qualcosa non è chiaro;
4. usare webaffare.it come riferimento del comportamento originale funzionante;
5. usare KeepStore_web per template, SQL, asset e materiali;
6. modificare solo ciò che serve;
7. non rompere logiche già funzionanti.

---

## Priorità

La priorità assoluta è preservare la logica KeepStore.

Se bisogna scegliere tra:

- grafica perfettamente aderente al template;
- funzione KeepStore che continua a funzionare;

scegliere sempre la funzione KeepStore.

La grafica va adattata senza rompere il comportamento.

---

## Regole tecniche

- Non eliminare funzioni esistenti senza sostituirle correttamente.
- Non inventare nuove logiche se esiste già una logica funzionante in Entropic.
- Non cambiare la struttura del database salvo richiesta esplicita.
- Non modificare parametri URL usati da altre pagine.
- Non cambiare il comportamento di carrello, login, sessioni, listini clienti e permessi.
- Non introdurre framework nuovi senza richiesta esplicita.
- Non lasciare contenuti demo nei file finali.
- Non creare CSS globale aggressivo.
- Usare override CSS scoped.
- Non duplicare asset JS/CSS già caricati.
- Non rompere master page, user control, header, menu, footer, ricerca o carrello.
- Verificare sempre eventuali binding WebForms.
- Prestare attenzione a ViewState, PostBack, eventi server-side e ID dei controlli ASP.NET.

---

## Template grafici

Quando si integra un template grafico, il template deve fornire:

- markup;
- classi CSS;
- struttura visuale;
- layout responsive;
- componenti UI;
- font;
- spaziature;
- bottoni;
- card;
- tab;
- gallery;
- hook JavaScript.

KeepStore deve fornire:

- dati reali;
- query;
- binding;
- logica server-side;
- logica client-side già esistente;
- URL;
- SEO;
- carrello;
- filtri;
- sessioni;
- listini;
- disponibilità;
- immagini prodotto;
- categorie;
- varianti.

Non trasformare KeepStore in un sito statico.
Trasformare il template in un tema dinamico per KeepStore.

---

## Metodo di lavoro

Per ogni modifica:

1. leggere i file interessati;
2. identificare dipendenze, include, user control, master page, JS e CSS collegati;
3. confrontare con Entropic se necessario;
4. individuare il comportamento corretto atteso;
5. applicare modifiche minime e coerenti;
6. mantenere la logica esistente;
7. rimuovere solo codice realmente duplicato, rotto o in conflitto;
8. testare mentalmente il flusso ASP.NET/WebForms;
9. verificare possibili errori JavaScript;
10. preparare output finale chiaro.

---

## Output obbligatorio dopo ogni intervento

Ogni intervento deve restituire:

A. File letti  
B. File modificati  
C. Modifiche effettuate  
D. Logica KeepStore mantenuta  
E. Eventuali riferimenti usati da Entropic/webaffare.it  
F. Query o binding dati cambiati  
G. Test eseguiti o da eseguire  
H. Rischi residui  
I. Istruzioni precise su dove copiare i file  
J. ZIP finale pronto per copia/incolla/upload  

---

## Regola ZIP

Ogni modifica deve essere consegnata anche come ZIP finale.

Lo ZIP deve:

- contenere solo file modificati o aggiunti;
- mantenere la struttura cartelle corretta;
- essere pronto per copia/incolla o upload;
- non contenere file inutili;
- non contenere backup temporanei;
- non contenere cartelle `.vs`, `bin`, `obj`, `node_modules`, cache o file generati non necessari.