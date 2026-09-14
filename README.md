# Pausa Attiva

App per insegnanti, educatori e genitori: aiuta a **scandire un compito
alternando blocchi di lavoro e pause attive**, con il tempo visibile e un passo
alla volta.

Le pause attive sono brevi momenti di movimento inseriti tra un'attività e
l'altra, una pratica diffusa nella scuola italiana. Oggi chi le usa lavora con
schede stampate e un timer separato: Pausa Attiva le mette dentro il ciclo del
compito.

> **Stato:** in sviluppo. L'MVP funziona su iOS e Android ma non è ancora
> pubblicato sugli store. Le illustrazioni delle pause sono in lavorazione:
> finché mancano, l'app mostra dei segnaposto.

## Come funziona

1. L'adulto prepara un **compito**: da 1 a 5 step, ognuno con un pittogramma
   ARASAAC e una breve etichetta.
2. Sceglie come scorre il tempo:
   - **per blocco**: il tempo scorre a blocchi, lo step avanza quando si tocca
     "Fatto";
   - **per step**: ogni step ha il suo tempo e dopo ogni step c'è una pausa.
3. Tra un blocco e l'altro c'è una **pausa attiva**, proposta a rotazione e
   modificabile.
4. Durante la sessione lo schermo mostra una cosa sola: lo step o il movimento
   corrente, e il tempo come un disco che si svuota.

## Funzioni

- **Sessione:** timer visivo senza cifre, preavviso uguale ogni volta prima di
  ogni cambio, gettoni che si riempiono, schermo sempre acceso.
- **Suoni e voce:** due segnali soli, sempre uguali (uno poco prima del cambio,
  uno a ogni cambio di fase) e annuncio vocale facoltativo di step e pause.
- **Pause attive:** 12 movimenti in tre gruppi (attivazione, scarico, rientro
  calmo) e 2 mini-circuiti, ognuno animato a pose. Ogni pausa dichiara se si fa
  al banco, in piedi al posto o se serve spazio.
- **Controlli per l'adulto in sessione:** "Salta", "Cambia" e "Ferma" si
  attivano con una pressione prolungata, così non scattano per sbaglio.
- **Libreria pause:** si sfoglia per tipo e per spazio richiesto. Le pause
  incluse si possono duplicare e modificare; se ne possono creare di nuove.
- **Stampa:** scheda del compito e schede delle pause con le pose affiancate,
  da stampare o salvare in PDF e plastificare.
- **Prima / Dopo:** due pittogrammi a schermo pieno per le transizioni
  improvvise, senza bisogno di preparare un compito.
- **Profili:** solo un soprannome e un avatar disegnato.
- **Area adulti:** la configurazione è protetta da un PIN o da un calcolo.

## Cosa non fa, per scelta

- Nessun account, nessun server, nessuna sincronizzazione.
- Nessuna raccolta di dati, statistica, pubblicità o tracciamento.
- Nessuno storico delle sessioni: un compito interrotto non viene registrato
  da nessuna parte.
- Nessun punteggio, stellina, classifica o ricompensa.
- Nessun campo per diagnosi o note sul bambino.

La connessione serve solo per cercare pittogrammi nel catalogo pubblico ARASAAC.
I pittogrammi scelti vengono salvati sul dispositivo, così i compiti funzionano
anche senza rete.

## Sviluppo

Flutter 3.41.5 / Dart 3.11.3, la stessa versione fissata in CI.

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # codice generato di drift
flutter analyze
flutter test
flutter run
```

Controlli di policy, eseguiti anche in CI a ogni push:

```sh
./tool/check_denylist.sh   # nessun pacchetto di tracciamento, analytics o pubblicità
./tool/check_claims.sh     # nessuna promessa clinica nei testi dell'app
```

Stack: Riverpod 2, drift (SQLite), flutter_tts, cached_network_image,
wakelock_plus. Riverpod 3 richiede Dart 3.12: non aggiornarlo senza prima
aggiornare Flutter.

### Struttura

```
lib/
  core/           costanti, tema, provider, widget condivisi
  data/
    db/           database drift
    repositories/
    seed/         pause incluse nell'app (id stabili)
    services/     client ARASAAC, voce
  domain/         modelli, motore della sessione, rotazione delle pause
  features/       home, editor, libreria_pause, picker, sessione,
                  prima_dopo, impostazioni
assets/
  pictograms/own/ pose dei movimenti + manifest.json
  avatars/
```

- **Tempi da tarare:** tutte le durate predefinite (blocco, preavviso,
  movimenti) sono in `lib/core/constants.dart`.
- **Ritmo delle animazioni:** la durata di ogni posa è in
  `assets/pictograms/own/manifest.json`.
- **Aggiungere le illustrazioni:** i PNG vanno in `assets/pictograms/own/` con
  il nome indicato nel manifest (per esempio `marcia_sul_posto_1.png`) e
  compaiono senza modificare il codice.

## Licenza

Codice pubblico (*source-available*) con licenza
[PolyForm Noncommercial 1.0.0](LICENSE.md): uso libero per scopi non
commerciali.

Pittogrammi: Sergio Palao / [ARASAAC](https://arasaac.org), Governo di Aragona,
licenza CC BY-NC-SA. Illustrazioni delle pause attive: Davide Bertolino.
