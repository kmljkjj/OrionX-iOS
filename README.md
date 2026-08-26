# OrionX-iOS

Navigateur **WebKit** pour iOS inspiré d’[Orion](https://orionbrowser.com/) — livré en **IPA** (sideload).

## Fonctionnalités

| Module | Détail |
|--------|--------|
| **Onglets** | Multi-onglets, aperçu, nouveau / fermer |
| **Extensions** | Userscripts (JS) + styles CSS injectés par site / global |
| **Adblock** | Listes EasyList-style (domaine + mots-clés) |
| **Proxy / IP** | HTTP & SOCKS configurables + presets (disclaimer : pas un VPN système) |
| **Mode desktop** | User-Agent PC forcé |
| **Console** | Logs, erreurs JS, eval JavaScript, source HTML |
| **Inspecteur** | HTML de la page, cookies basiques |
| **Favoris & Historique** | Stockage local |
| **Menus** | Feuilles soignées (•••, paramètres, site) |

## Limites (honnêteté)

- Sur iOS **sans** API privées Apple, on ne peut pas charger de vrais packs Chrome/Firefox comme Orion officiel.
- OrionX utilise un moteur **userscripts + content scripts** (proche de Violentmonkey / Stylus).
- Le **proxy** s’applique via réglages URLSession / page ; ce n’est **pas** un VPN global iOS (impossible sans Network Extension signée).

## Build IPA

1. **Actions** → **Build IPA** → Run workflow  
2. Télécharge l’artifact `OrionX.ipa`  
3. Signe (TrollStore, AltStore, Sideloadly…)

## Structure

```
Sources/
  App.swift
  Models/
  Views/
  Web/
  Services/
project.yml
.github/workflows/build-ipa.yml
```
