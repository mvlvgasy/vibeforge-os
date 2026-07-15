---
name: lab-factory
description: Fabrique un lab standalone COMPILÉ depuis le métier du client — scan brownfield avant toute question, interview LAB_BRIEF, gate de complétude machine-vérifiée (check-brief.ps1), génération modulaire, puis compilation des agents/skills métier depuis les capacités justifiées. Remplace le duo "générer générique puis customiser après".
when_to_use: |
  Quand on crée un lab pour un CLIENT ou un domaine précis et qu'on veut des agents métier
  sur mesure dès la génération (pas seulement le socle). Pour un lab générique sans couche
  métier : /new-lab-standalone directement suffit.
  Exemples : /lab-factory name=acme-commercial client=acme,
             /lab-factory name=geo-prospection context=./transcripts/call-cadrage.txt
allowed-tools: Read, Grep, Glob, Bash, Write, Task, Skill
argument-hint: "name=<nom-kebab> [client=<nom>] [context=<path>] [modules=<liste>]"
---

# /lab-factory

Pipeline : **scan → brief → gate → génération modulaire → compilation métier → vérification**.
La logique lourde de conception d'agents vit dans l'agent `lab-architect` — ce skill orchestre.

## 1. Scan brownfield (AVANT toute question)

Règle : **on ne demande jamais ce que le contexte dit déjà.** Si `context=` est fourni (dossier,
doc, transcript d'appel de cadrage), le lire/greper D'ABORD et pré-remplir le brief avec.
Chaque info extraite cite sa source ; seuls les trous restent marqués `[À CLARIFIER]`.

## 2. Interview → LAB_BRIEF.md

Copier `templates/LAB_BRIEF.md.tpl` en `LAB_BRIEF-<nom>.md` (cwd). Poser UNIQUEMENT les questions
des marqueurs restants, par section, en une passe groupée (pas de ping-pong). La section 4 est le
cœur : chaque capacité = verbe + objet + **justification métier tirée du brief** — une capacité
sans justification ne sera PAS compilée (anti-inflation de skills).

## 3. Gate de complétude (BLOQUANTE, axiome 1)

```powershell
powershell.exe -ExecutionPolicy Bypass -File <socle>/scripts/check-brief.ps1 -BriefPath LAB_BRIEF-<nom>.md
```

`STATUS: BLOCKED` → retour à l'interview avec la liste exacte (marqueurs + lignes). On ne
"passe pas quand même". `STATUS: READY` → continuer. Jamais plus de 3 allers-retours : au 3ᵉ,
escalade (le cadrage a un problème plus profond qu'un formulaire).

## 4. Génération modulaire du socle

```powershell
powershell.exe -ExecutionPolicy Bypass -File <socle>/scripts/new-lab-standalone.ps1 -Name <nom> -Modules "<section 8 du brief>" [-GitInit]
```

## 5. Compilation métier (le cœur de la factory)

Dispatcher **`lab-architect`** (Task) avec : le LAB_BRIEF complet + le path du lab généré.
Contrat de mission :
- **1 ligne de capacité = 1 agent OU 1 skill** (colonne "Compilée en"), écrit dans
  `.claude/agents/` / `.claude/skills/` du lab. Pas d'étage d'orchestration en plus (le lead du
  socle route déjà) — anti-pattern wrapper documenté.
- Conformité **R012** (frontmatter noms simples), **R015** (bootstrap ≤ 5 items, Edit pour les
  producteurs), **R016** (pas de MEMORY pré-remplie obèse). Prompts AUTOPORTANTS : zéro référence
  au repo privé ou à cette session (le lab doit vivre seul — anti-pattern "fuite de jargon").
- SOUL.md et contexte-domaine.md du lab réécrits depuis le brief (sections 1-3, 6, 7).
- Reporter la colonne "Compilée en" du brief avec les noms réels créés, copier le brief final
  dans `<lab>/LAB_BRIEF.md` (traçabilité : le brief EST la spec du lab).

## 6. Vérification (preuve, pas déclaration — axiome 2)

1. `tools/rebuild-catalog.ps1` dans le lab → le CATALOG liste les agents/skills compilés.
2. `check-drift.ps1 -LabPath <lab>` → `STATUS: OK` (les customs sont hors manifeste = couche
   custom par construction ; le socle est intact).
3. `check-brief.ps1` sur le brief copié → toujours READY.
4. Annoncer : modules posés, capacités compilées (table Cn → fichier créé), et le rappel L41
   (les skills du lab ne sont invocables qu'à la première session ouverte DANS le lab).

## Jamais

- Générer avec un brief BLOCKED ("on complétera après" = jamais).
- Compiler une capacité sans justification, ou "en bonus" hors tableau.
- Toucher au socle vendori (`_method/`, agents/skills du socle) pendant la compilation — les
  customs s'AJOUTENT, ils ne modifient pas (sinon check-drift le verra).
