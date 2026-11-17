<h1 align="center">Headshare</h1>

<p align="center">
  <b>Riproduci l'audio del Mac su più cuffie e casse contemporaneamente.</b><br>
  Gratis, open source, senza abbonamenti, senza limiti.
</p>

<p align="center">
  <a href="../../releases/latest"><b>⬇︎ Scarica per macOS</b></a>
  &nbsp;·&nbsp;
  <a href="README.md">🇬🇧 Read in English</a>
</p>

---

macOS può riprodurre l'audio su una sola cuffia Bluetooth alla volta. L'iPhone ha "Condividi audio", il Mac no. **Headshare risolve il problema**: scegli le uscite dalla barra dei menu, attiva l'interruttore, e tutto ciò che il Mac riproduce esce da tutte, sincronizzato.

Guarda un film con un amico su due paia di AirPods, ascolta musica in cuffia e su una cassa insieme, oppure manda il suono agli altoparlanti del Mac e a una TV via HDMI nello stesso momento.

## Funzioni

- **Tutte le uscite che vuoi**: AirPods, Beats, qualsiasi cuffia o cassa Bluetooth, USB, HDMI, DisplayPort e gli altoparlanti del Mac
- **Volume e ritardo per ogni dispositivo**, per tenere tutte le uscite perfettamente allineate, più un volume generale
- **Riferimento di sincronizzazione** (👑): scegli quale dispositivo tiene il tempo, gli altri lo seguono con la correzione della deriva
- **Connessione con un clic** dei dispositivi Bluetooth associati, direttamente dal menu
- **Condivisione automatica** appena i dispositivi selezionati si connettono
- **Scorciatoia da tastiera globale** per avviare o fermare la condivisione da qualsiasi app
- **Audio sempre in alta qualità**: usa il microfono del Mac, così le cuffie Bluetooth non passano in modalità chiamata
- **Ripristina l'uscita precedente** quando fermi la condivisione o chiudi l'app
- **Design Liquid Glass** su macOS 26, tutorial guidato al primo avvio, finestra Impostazioni completa, apertura al login
- **Disponibile in 34 lingue**, segue la lingua del tuo Mac
- **Niente driver, niente estensioni del kernel, niente password di amministratore**: solo API CoreAudio pubbliche

## Installazione

1. Scarica **`Headshare-x.y.z.dmg`** dalle [Releases](../../releases/latest).
2. Aprilo e trascina **Headshare** nella cartella **Applicazioni**.
3. Apri Headshare da Applicazioni. La prima volta macOS potrebbe dire che non può verificare lo sviluppatore, perché l'app non è ancora notarizzata da Apple:
   - apri **Impostazioni di Sistema › Privacy e sicurezza**, scorri in basso e clicca **Apri comunque**, oppure
   - esegui una volta nel Terminale: `xattr -dr com.apple.quarantine /Applications/Headshare.app`
4. Quando richiesto, consenti l'accesso al Bluetooth, così Headshare può mostrarti i dispositivi associati.

**Requisiti:** macOS 14 Sonoma o successivo, Apple Silicon o Intel.

## Come si usa

1. Clicca l'icona 🎧 nella barra dei menu.
2. Seleziona almeno due uscite cliccando in un punto qualsiasi della riga.
3. Attiva l'interruttore. Fatto.

Usa il pulsante dei cursori su ogni uscita per volume e ritardo, e la corona per scegliere il riferimento di sincronizzazione. Tutto il resto è nelle **Impostazioni** (⌘,).

## Lingue

Inglese, italiano, tedesco, francese (Francia e Canada), spagnolo (Spagna e America Latina), portoghese (Brasile e Portogallo), olandese, svedese, danese, norvegese, finlandese, polacco, ceco, slovacco, ungherese, rumeno, croato, catalano, greco, turco, russo, ucraino, arabo, ebraico, hindi, thailandese, vietnamita, indonesiano, malese, giapponese, coreano, cinese (semplificato, tradizionale, Hong Kong).

Hai trovato una traduzione migliorabile? Apri una issue o una pull request: le traduzioni sono in [`Localization/translations`](Localization/translations).

## Limiti noti di macOS

- Spesso il volume delle AirPods non può essere modificato dalle app: regolalo dalle cuffie.
- I tasti volume della tastiera non controllano un dispositivo multi-uscita: usa il cursore nel menu di Headshare.

## Compilare dal codice sorgente

```bash
git clone https://github.com/numbfede/Headshare.git
cd Headshare
./build.sh install      # compila e installa in /Applicazioni
./make-dmg.sh           # facoltativo: crea il DMG di installazione in ./build
```

Richiede Xcode 26 (interfaccia Liquid Glass e icona di Icon Composer).

Per aggiornare le traduzioni: modifica `Localization/translations/<lingua>.json`, poi esegui `python3 Localization/generate.py`.

## Pubblicare una versione

Aumenta `CFBundleShortVersionString` in `Resources/Info.plist` (per esempio `1.1.0`) e fai push su `main`. GitHub Actions compila l'app universale, crea il DMG e pubblica la release `v1.1.0` con il DMG come download.

## Crediti

Icona dell'app disegnata da numbfede con Icon Composer. Glifo delle cuffie di [Icons8](https://icons8.com).

## Licenza

MIT © numbfede (codice). L'icona dell'app ha una licenza separata e non è coperta dalla licenza MIT.
