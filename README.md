# CW Maintenance Utility (WinMaint)

Ferramenta de manutenção de PCs Windows com **interface gráfica** (WPF, tema escuro
Catppuccin Mocha), inspirada no [WinUtil](https://github.com/ChrisTitusTech/winutil) do
Chris Titus. Pensada para técnicos de IT: diagnóstico, instalação de software, tweaks de
sistema, atualizações e limpeza — tudo numa janela, escolhendo só o que se quer correr.

## Ficheiros

| Ficheiro | Papel |
|----------|-------|
| `WinMaint.ps1` | A aplicação (GUI). Único ficheiro, self-contained. |
| `PCMaintenance.ps1` | Versão **legada** em linha de comandos (corre tudo de seguida, sem GUI). |
| `RunMaintenance.bat` | Lançador do `PCMaintenance.ps1` legado. |
| `*.exe` | Instaladores guardados localmente (fallback manual da versão legada). |

## Requisitos

- Windows 10/11, PowerShell 5.1+
- Privilégios de **Administrador** (o script eleva-se automaticamente via UAC)
- `winget` (App Installer) para Install/Updates
- Ligação à Internet

## Como correr

### Local
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\WinMaint.ps1
```
Pede UAC, abre a janela. Marca o que queres em cada tab e carrega **RUN**.

### Alojado (`irm | iex`) — recomendado
Em qualquer máquina, numa PowerShell:
```powershell
irm tinyurl.com/cwmaint | iex
```
(equivale a `irm https://raw.githubusercontent.com/zzalyf/winmaint/main/WinMaint.ps1 | iex`)

Se não estiver elevado, o script volta a fazer fetch dele próprio numa sessão de
Administrador (UAC). O `tinyurl` aponta para o branch `main`, por isso reflete sempre a
versão mais recente.

## Interface

Há três tipos de controlo (estilo WinUtil):
- **Checkbox** — seleção em lote, aplicada com **RUN** (e **Undo tweaks** reverte os tweaks).
- **Toggle** (switch) — liga/desliga **imediato**, refletindo o estado atual do sistema.
- **Botão** — ação de **1 clique** (corre logo).

Barra inferior: **Selecionar tudo**, **Limpar**, **Undo tweaks**, **RUN**. Todo o output
aparece na **consola do PowerShell** (em inglês, tema Catppuccin) e é gravado em
`C:\WinMaint\WinMaint.log`.

### Tabs

- **Standard Maintenance** — Windows Update, Microsoft Store, Office (Click-to-Run), `winget
  upgrade --all`, a ferramenta OEM da marca da máquina (Lenovo Vantage / HP Support Assistant
  / Dell Command | Update — só aparece a correspondente), Intel DSA, limpeza (temporários +
  Disk Cleanup + Prefetch, **só no disco C:**) e um botão para abrir o **CrystalDiskInfo**.
- **Diagnostics** — System Summary (+ inventário em `C:\WinMaint\Inventory.csv`), Pending
  Reboot Check, Startup Items, Event Log (só eventos críticos/úteis → `C:\WinMaint\EventLog.txt`).
- **Install** — apps via `winget`, por categoria (Browsers, Communications, Development,
  Microsoft Tools, Documents & Office, Multimedia, Diagnostics & Pro Tools, Utilities).
  Instala só o que faltar.
- **Tweaks** — Essential Tweaks e Advanced Tweaks (checkboxes, RUN/Undo) + Preferences
  (toggles imediatos). Baseados em registo/serviços/scripts. O Explorer reinicia para
  aplicar mudanças visuais.
- **Config** — Features (ativar via DISM), Fixes (SFC/DISM, reset Windows Update/rede,
  reparar winget, NTP — botões), Legacy Panels (abrir painéis clássicos, incl. Impressoras —
  botões) e Remote Access (OpenSSH — botão).

## Ficheiros gerados

| Ficheiro | Conteúdo |
|----------|----------|
| `C:\WinMaint\WinMaint.log` | Todo o output (append). |
| `C:\WinMaint\Inventory.csv` | Inventário da máquina (overwrite a cada execução). |
| `C:\WinMaint\EventLog.txt` | Relatório de eventos críticos (overwrite a cada execução). |

## Notas técnicas

- **Não congela**: as tarefas correm num *runspace* em background; a UI mantém-se viva.
- **winget elevado**: resolve o caminho absoluto do `winget.exe` real (em
  `Program Files\WindowsApps\...`), porque o alias por-utilizador não está no PATH do sistema
  numa sessão elevada.
- **Apps OEM/UWP**: lançadas no contexto do utilizador (AUMID via `Get-StartApps` ou tarefa
  agendada) para a janela aparecer mesmo com o script elevado.
- **Tweaks**: valores On/Off (aplicar/reverter) alinhados com a config do WinUtil.

## Avisos

- Executa **ações reais e algumas irreversíveis** (instala software, corre Windows Update,
  apaga temporários/Prefetch, altera registo/serviços).
- Recomenda-se **reiniciar** no fim para aplicar todas as alterações.
- Os tweaks revertem para os valores por defeito do Windows com o **Undo tweaks** — não
  necessariamente para o estado exato anterior, se já tinhas valores personalizados.
