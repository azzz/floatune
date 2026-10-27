[English](../README.md) | [Русский](README.ru.md) | [Українська](README.uk.md) | [Српски](README.sr.md) | Hrvatski | [Română](README.ro.md)

# Floatune

Mali prozor za upravljanje Spotifyjem na macOS-u. Stoji iznad svih prozora, pojavljuje se i skriva prečacem s tipkovnice, a kad ga ne dirate, postaje poluproziran.

U prozoru su omot, naziv pjesme i izvođač, gumbi „prethodna”, „pauza” i „sljedeća”, glasnoća u Spotifyju i traka napretka koju možete povući za premotavanje.

## Zahtjevi

- macOS 14 ili noviji
- Desktop aplikacija Spotify. Premium nije potreban.

## Instalacija

Preuzmite `Floatune-*.zip` iz [najnovijeg izdanja](https://github.com/azzz/floatune/releases/latest), raspakirajte ga i premjestite `Floatune.app` u „Aplikacije”.

Aplikacija ima ad-hoc potpis, a ne Developer ID, pa macOS blokira prvo pokretanje. Uklonite oznaku karantene:

```
xattr -dr com.apple.quarantine /Applications/Floatune.app
```

Ili pokušajte otvoriti aplikaciju, a zatim kliknite „Svejedno otvori” u Postavkama sustava → Privatnost i sigurnost.

Pri prvom pokretanju macOS pita smije li Floatune upravljati Spotifyjem. Dopustite. Nakon ažuriranja macOS može ponovno pitati jer svaka verzija ima svoj ad-hoc potpis.

## Korištenje

| Radnja | Kako |
|---|---|
| Prikaži ili sakrij prozor | ⌃⌥⌘S |
| Vrati zatamnjenom prozoru punu neprozirnost | Prijeđite mišem preko njega ili pritisnite prečac |
| Pomakni prozor | Povucite ga za bilo koje mjesto. Položaj se pamti |
| Postavke i zatvaranje | Desni klik na prozor |

U postavkama se mijenjaju prečac, odgoda prije zatamnjenja (1–15 s), neprozirnost zatamnjenog prozora (10–90%), pokretanje pri prijavi i jezik sučelja. Promjene vrijede odmah, osim jezika, koji traži ponovno pokretanje.

Klik na prozor ne oduzima fokus aplikaciji u kojoj radite.

## Kako radi

Floatune komunicira s desktop Spotifyjem preko Apple Eventsa, istim naredbama koje koristi AppleScript. Spotify sam javlja promjenu pjesme sistemskom obavijesti `com.spotify.client.PlaybackStateChanged`, pa ništa ne provjerava stanje u pozadini. Floatune ne koristi Spotify Web API i ide na internet samo po omote.

Ograničenja:

- Nema reda sljedećih pjesama. Daje ga samo Web API, a on traži OAuth i račun programera.
- Klizač mijenja glasnoću samog Spotifyja, a ne sistemsku.
- Spotify ne šalje obavijest pri premotavanju. Dok je prozor vidljiv i pjesma svira, Floatune ponovno čita poziciju svakih 5 sekundi.
- Ako je Spotify zatvoren, Floatune ga ne pokreće i nudi gumb da ga otvorite.

## Jezici

Floatune je preveden na engleski, ruski, ukrajinski, srpski (ćirilica), hrvatski i rumunjski i prati jezik sustava. Za drugi jezik desnom tipkom kliknite na prozor → „Postavke…” → „Jezik”, a zatim kliknite „Ponovno pokreni”.

### Dodavanje jezika

1. Kopirajte `Resources/en.lproj` u `Resources/<kod>.lproj`, gdje je `<kod>` kod jezika: `de`, `pl`, `pt-BR`.
2. Prevedite vrijednosti u `Localizable.strings` i `InfoPlist.strings`. Ključeve na lijevoj strani ne mijenjajte i zadržite svaki `%@`.
3. Pokrenite `python3 scripts/check_strings.py`. Skripta pada ako neki ključ nedostaje ili je višak, ili ako prijevod promijeni `%@`.
4. Izgradite aplikaciju. Novi jezik sam se pojavljuje u „Postavkama” → „Jezik”; odaberite ga i provjerite svaki zaslon.

## Izgradnja iz izvornog koda

Dovoljni su Command Line Tools, Xcode nije potreban.

```
./scripts/build.sh
open build/Floatune.app
```

Skripta čita ove varijable okruženja:

| Varijabla | Što postavlja | Zadano |
|---|---|---|
| `ARCHS` | Arhitekture odvojene razmakom, npr. `"arm64 x86_64"` | Arhitektura vašeg Maca |
| `VERSION` | `CFBundleShortVersionString` | Vrijednost iz `Resources/Info.plist` |
| `BUILD_NUMBER` | `CFBundleVersion` | Vrijednost iz `Resources/Info.plist` |
| `SIGN_ID` | Certifikat za potpisivanje | Ad-hoc potpis |

Gatekeeper ne provjerava aplikaciju koju ste izgradili lokalno: macOS stavlja oznaku karantene samo na preuzete datoteke.

## Izdanja

CI provjerava prijevode i gradi universal aplikaciju pri svakom pushu u `main` i za svaki pull request. Da objavite izdanje, pushajte tag:

```
git tag v0.2.0
git push origin v0.2.0
```

Workflow gradi aplikaciju s verzijom iz taga i objavljuje GitHub Release sa zip arhivom.

---

Floatune nije povezan sa Spotify AB. Spotify je zaštitni znak tvrtke Spotify AB.
