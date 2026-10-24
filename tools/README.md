# Research tools / Ferramentas de pesquisa

Scripts used while mapping the game. They are **not needed** to use Spiral Compass.
Scripts usados para mapear o jogo. **Não são necessários** para usar o Spiral Compass.

**How to run / Como rodar:** with the game running and the mod installed, copy a script to
`ue4ss\Mods\SpiralCompass\probe.lua`. The mod runs it once, inside the game thread, deletes it and writes
the result to `probe_out.txt`.
Com o jogo aberto e o mod instalado, copie um script para `ue4ss\Mods\SpiralCompass\probe.lua`. O mod executa
uma vez, dentro do jogo, apaga o arquivo e grava o resultado em `probe_out.txt`.

| Script | What it does / O que faz |
|---|---|
| `dump_data.lua` | Exports every `/Game/DataTable/*` table and the localized `StringTable` to `data/` |
| `dump_strings.lua` | Exports only the `StringTable` (pt-BR or the game's current language) |
| `test_nav.lua` | Tests inventory reading (`CheckItemNumber`) and navigation paths |
| `dump_all_levels.lua` | Loads the other chapters' map packages as data and lists their actors. ⚠ **May crash the game.** |

⚠ The `data/` folder holds the game's own text and data. Do not publish it.
⚠ A pasta `data/` contém textos e dados do próprio jogo. Não publique.
