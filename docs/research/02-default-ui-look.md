# Research 02 — What the WoW Forever UI looks like

## The default UI

- **Modern art, optional classic placement.** First login asks for a *Classic* or *Enhanced*
  (client label: *Modern*) preset. It only sets starting options: screen layout, one-bag vs
  separate bags, quest markers, transmog. Edit Mode's *Classic (Preset)* layout moves frames to
  their old positions but **keeps the modern art**. There is no built-in classic skin.
- **Edit Mode** (Game Menu) moves and resizes default frames; layouts are saved per input type
  (mouse/keyboard vs gamepad). Addon windows are expected to be movable and to remember their
  position; they do not get Edit Mode handles for free.
- **Built in, so addons need not duplicate:** damage meter, Cooldown Manager (off by default),
  aggro display, click casting, raid frames, scrolling combat text options, AH equip-level column,
  gamepad support (beta).
- **Options window:** the modern Settings panel — dark grey, two-column, category list on the
  left, checkbox + slider + dropdown rows on the right, sliders with stepper arrows and the value
  printed on the right. Addons appear under *AddOns* via `Settings.Register*Category`.
- **Addon compartment:** the minimap has a dropdown that lists addons declaring
  `## AddonCompartmentFunc`. This is the sanctioned replacement for a minimap button; many players
  still expect a minimap button, so offer both and make the button optional.
- Players who want the 2004 look install reskin addons (ClassicUI Forever, Forevermore Classic UI).
  So both tastes exist in the player base: **modern-dark and vanilla-gold are both "native".**

## The visual vocabularies in play

| Vocabulary | Where it is seen | Tokens |
|---|---|---|
| **Vanilla** | Reskin addons, older addons, dialogs, tooltips | Gold `UI-DialogBox-Border` (32px edge), dark mottled `UI-DialogBox-Background`, title plaque `UI-DialogBox-Header`, yellow `GameFontNormal` (1, 0.82, 0) headings, white body text, red `UIPanelButton` with gold text, round gold checkboxes with yellow tick, grooved slider with a diamond thumb |
| **Modern Blizzard** | Default Settings panel, Edit Mode, collections | Charcoal panels, thin metal NineSlice border, blue-highlight list rows, flat sliders with stepper arrows, value text to the right |
| **Pixel / flat dark** | ElvUI and its descendants (Bartender, Plater options, most "UI packs") | 1px black border, flat `#1a1a1a`–`#2b2b2b` fills, one accent colour (often class colour), no gradients, small crisp font with outline, everything aligned to the pixel grid |
| **Glass** | Details!, Baganator (dark skin), many trackers | Semi-transparent black (50–80% alpha), no border or a hairline, compact rows, statusbar textures as row fills, icons flush left |
| **Parchment** | Quest log, Questie journal, dungeon journals | Tan parchment background, dark brown text, red-brown headings, used for reading-heavy content |

The framework ships these as themes: `vanilla`, `pixel`, `glass`, `parchment`. (Modern Blizzard
is what the Settings panel gives for free when options are embedded there.)

## Look-and-feel rules the client imposes

- UI scale: users run 0.64–1.0 (**local** config: `uiScale 0.66`). Windows must stay usable at
  0.64 on 1080p and not exceed ~900×650 UI units by default.
- Standard fonts: Friz Quadrata (`GameFontNormal`, headings/UI), Arial Narrow (`ChatFontNormal`,
  numbers and chat), Morpheus (quest titles), Skurri (damage). Use font objects, never hard-coded
  font files, so locale fonts (koKR, zhCN, ruRU) keep working.
- Standard colours: gold `1, 0.82, 0`; white `1,1,1`; disabled grey `0.5,0.5,0.5`; red error
  `1, 0.1, 0.1`; green `0.1, 1, 0.1`; item quality colours via `ITEM_QUALITY_COLORS`; class
  colours via `RAID_CLASS_COLORS`.
- Standard sounds on interaction: `SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON/OFF`,
  `IG_CHARACTER_INFO_TAB`, `IG_MAINMENU_OPEN/CLOSE`, `GS_TITLE_OPTION_OK` (button click
  `856`/`IG_MAINMENU_OPTION`).
- Escape closes windows (`UISpecialFrames`), strata `MEDIUM` for windows, `DIALOG` for modal
  dialogs, `TOOLTIP` for tooltips, `FULLSCREEN_DIALOG` for dropdown lists over dialogs.

## Sources

- https://guided.news/en/guides/wow-forever-classicui-forever-interface-setup/
- https://forevermastery.com/en/guides/forever-interface-settings
- https://wowforeveraddons.com/articles/wow-forever-ui-setup
- https://classicwowforever.com/guides/make-wow-forever-look-like-classic/
- https://mmonster.co/wow-forever/guides/addons/built-in-features
- https://timesaver.gg/blog/wow-forever-addons-save-beta-ui-before-launch
- Local install: `WTF/Config.wtf`, GoalNotes UI code.
