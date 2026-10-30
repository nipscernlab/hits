# Teste do HITS com o SAPHO na DE2-115

Este roteiro é para o aluno que tem a placa DE2-115 e para o assistente de IA
(Claude ou outro) que o ajuda. Ele vai do computador sem nada instalado até o
teste terminado e o relatório. Siga na ordem e não pule as conferências: cada uma
diz se o passo anterior deu certo.

**Este projeto nunca rodou numa placa.** Tudo nele foi conferido em simulação e
pelo compilador do Quartus, não em hardware. Você é o primeiro. Quando algo não
bater com este roteiro, isso é um resultado, não um erro seu: anote o que viu,
tire uma foto e relate (seção 11), em vez de contornar.

## 0. Para o assistente que ajuda o aluno

- Os fatos sobre o HITS, o SAPHO, o YANC e a AURORA estão nos repositórios deles,
  não em conhecimento geral: nenhum deles existe fora do grupo NIPS-CERN. Leia o
  arquivo antes de responder. Os principais: este roteiro, o
  [README desta pasta](README.md) (em inglês), `software/hits_menu.cpp` e o mapa
  de registradores em [docs/guide/configuring.md](../../docs/guide/configuring.md).
- Quando deduzir algo em vez de ler, diga que deduziu.
- Não edite os arquivos gerados (`hits_menu.v`, os `.mif`, `pc_hits_menu_mem.txt`,
  `sapho/`), os pinos de `hits_de2_115.qsf` nem `signaltap/stp1.stp`. Se algum
  parecer errado, relate.
- Se um passo falhar, pare ali e ajude o aluno a descrever o que aconteceu
  (seção 11). Não mude o projeto para o teste passar.
- Nenhuma senha, token ou chave entra num arquivo, num commit ou num relatório.

## 1. O que você vai testar

```
          cristal de 50 MHz
               |
              PLL ------------------- 25 MHz ------------------+
               | 40 MHz                                        |
   +-----------+------------------+                +-----------+-----------+
   | SAPHO (processador, 16 bits) | <-- link 0 --- | myKeyPS2   <- teclado PS/2
   | roda software/hits_menu.cpp  | --- link 1 --> | myVGAText  -> monitor VGA
   +-----------+------------------+                +-----------------------+
               | barramento de configuração (hits_sapho.v)
   +-----------+------------------+
   | hits: o simulador da cadeia  | --> Signal Tap (formas de onda pelo JTAG)
   | de leitura do TileCal        | --> hex_debug -> displays de 7 segmentos
   +------------------------------+
```

O SAPHO é um processador soft-core cujo hardware é gerado para o programa que ele
roda. O programa, `software/hits_menu.cpp`, mostra um menu no monitor, lê números
do teclado e os escreve nos registradores do `hits`: a ocupação (com que
frequência acontece um hit), o pedestal (a linha de base do ADC), o modo, o
tamanho da órbita, e rodar ou parar. Os displays de 7 segmentos mostram o que
chegou ao `hits`, e o Signal Tap mostra as formas de onda que o `hits` produz.

## 2. O que você precisa

Hardware:

- a Terasic DE2-115, a fonte de 12 V dela e o cabo USB (porta *USB Blaster*);
- um monitor VGA que aceite 640 x 480 a 60 Hz, e um cabo VGA;
- um teclado PS/2. Um teclado USB num adaptador passivo para PS/2 só funciona se o
  próprio teclado ainda falar PS/2, e muitos não falam: use um teclado PS/2 de
  verdade se puder. O layout pode ser ABNT2 ou US; o menu só usa os dígitos, `-`,
  Enter e Backspace, que ficam no mesmo lugar nos dois.

Software, no Windows 10 ou 11:

| O quê | Versão | Para |
|---|---|---|
| Quartus Prime Lite, com o suporte ao Cyclone IV e o Signal Tap | **24.1std.0** | programar a placa, Signal Tap; compilar (caminho B) |
| O driver do USB Blaster | vem com o Quartus, em `<pasta do quartus>\drivers` | programar a placa |
| Git for Windows (traz o Git Bash) | qualquer recente | tudo |
| MSYS2, com `gcc`, `make`, `bison`, `flex` | qualquer recente | caminho B: compilar o YANC |
| Node.js e a instalação da AURORA | o que o `setup.bat` instala | caminho B: AURORA |

Há dois caminhos neste roteiro:

- **Caminho A, o bitstream pronto:** você baixa o projeto já compilado e testa.
  É rápido e basta para o teste. Seção 3, depois seções 5 a 11.
- **Caminho B, pelos fontes:** você compila o YANC, roda a AURORA pelos fontes com
  a versão mais nova do YANC, gera o processador, simula e compila tudo você
  mesmo. Faça depois do caminho A, ou quando o grupo pedir. Seção 4, depois
  seções 5 a 11.

## 3. Caminho A: o bitstream pronto

1. Baixe o repositório no commit do bitstream (no Git Bash; use um caminho curto,
   sem espaços e fora do OneDrive):

       mkdir -p /c/Dev && cd /c/Dev
       git clone https://github.com/nipscernlab/hits.git
       cd hits
       git checkout de2-115-bitstream-v2

   O Git avisa que você está em "detached HEAD": é o esperado, você está no commit
   exato de onde o bitstream foi compilado. Esse commit é anterior a este roteiro,
   então o roteiro não está nessa pasta: deixe-o aberto no GitHub
   (`projects/de2_115_sapho/TESTE_NA_PLACA.md` no ramo `main`). Os arquivos do
   projeto são os mesmos.

2. Baixe os três arquivos da pre-release
   [de2-115-bitstream-v2](https://github.com/nipscernlab/hits/releases/tag/de2-115-bitstream-v2):
   `hits_de2_115.sof`, `stp1.stp` e `SHA256SUMS`.

3. Confira se o download veio inteiro. No PowerShell, na pasta do download:

       Get-FileHash hits_de2_115.sof

   O hash tem de ser o que o `SHA256SUMS` lista para ele (começa com `B04B0296`).
   Se for diferente, baixe de novo.

4. Ponha o `.sof` onde o projeto espera:
   `C:\Dev\hits\projects\de2_115_sapho\output_files\hits_de2_115.sof` (crie a pasta
   `output_files` se não existir). O `stp1.stp` da release é o mesmo arquivo que
   `projects\de2_115_sapho\signaltap\stp1.stp` do repositório nesse commit, então
   não precisa copiá-lo.

Vá para a seção 5.

## 4. Caminho B: pelos fontes

### 4.1 As pastas

O YANC e a AURORA têm de ficar lado a lado na mesma pasta, porque o script que
passa o YANC mais novo para a AURORA procura `..\Aurora` ao lado de `yanc`. Use
um caminho local curto, nunca OneDrive, Dropbox ou unidade de rede (a AURORA
recusa):

```
C:\Dev\
   hits\     o simulador e este projeto
   yanc\     o compilador do SAPHO
   aurora\   a IDE do SAPHO
```

No Git Bash:

    mkdir -p /c/Dev && cd /c/Dev
    git clone https://github.com/nipscernlab/hits.git
    git clone https://github.com/nipscernlab/yanc.git
    git clone https://github.com/nipscernlab/aurora.git

### 4.2 Compilar o YANC

O YANC é compilado com o MSYS2. Instale-o de <https://www.msys2.org/>, abra o
terminal *MSYS2 MINGW64* e instale as ferramentas:

    pacman -S mingw-w64-x86_64-gcc make bison flex

Depois compile, no mesmo terminal:

    cd /c/Dev/yanc
    make

O `make` deixa os compiladores em `yanc/bin/` (`cppcomp.exe`, `asmcomp.exe` e os
outros). Os detalhes estão em `yanc/docs/develop/building.md`. Depois de todo
`git pull` do YANC, rode `make` de novo: os compiladores têm de vir do mesmo
commit que o resto do YANC.

### 4.3 A AURORA pelos fontes, com o YANC mais novo

A AURORA normalmente baixa um YANC de release (a versão é fixa, e a release ainda
não tem a correção do teclado e da tela de 30/10/2026, yanc#64). Para ela usar o
YANC que você acabou de clonar:

1. Instale a AURORA pelos fontes, no PowerShell:

       cd C:\Dev\aurora
       .\setup.bat

   Ele instala o Git, o Node.js e as dependências, baixa as ferramentas (Icarus
   Verilog, GTKWave e o YANC de release) e oferece abrir a AURORA. Deixe terminar
   e feche a AURORA. Os detalhes estão no README da `aurora`, "Building from
   source".

2. Passe o YANC mais novo para a AURORA. Num prompt de comando do Windows (`cmd`),
   com o MSYS2 no `PATH` (troque `C:\msys64` se o MSYS2 estiver em outro lugar):

       set PATH=C:\msys64\mingw64\bin;C:\msys64\usr\bin;%PATH%
       cd C:\Dev\aurora
       ..\yanc\Scripts\aurora.bat

   O script compila o YANC com a mesma receita de uma release e troca juntas as
   pastas `components\bin`, `SAPHO`, `Macros` e `Header` da AURORA. Nada do que
   ele escreve é rastreado pelo git. Para voltar um dia ao YANC de release:
   `node components/Scripts/download-yanc.cts --force` em `C:\Dev\aurora`.

3. Abra a AURORA pelos fontes: `npm start` em `C:\Dev\aurora`. O próximo
   `npm start` mantém o YANC do passo 2.

### 4.4 O programa

O programa é `projects/de2_115_sapho/software/hits_menu.cpp`, em C++. O SAPHO o
roda direto; não há sistema operacional. Leia-o inteiro: é curto. As partes que
importam:

```cpp
#pragma yanc nuioou 9          // 9 portas de saída: a porta p é o registrador p do hits
#pragma yanc nuioin 3          // 3 portas de entrada: ID, CAPS, STATUS
#pragma yanc nubits 16         // um processador de 16 bits, a largura do barramento
#define YANC_LINK_SYNC 0       // teclado e tela em outro clock (25 MHz)
#include <iostream>
```

- `out(p, x)` escreve o registrador `p` do `hits`; `in(p)` o lê. Só `ID` (0),
  `CAPS` (1) e `STATUS` (2) podem ser lidos, então o programa guarda uma cópia de
  cada valor que escreveu, e `write_all()` escreve todos quando começa.
- `cout <<` escreve na tela VGA e `cin >>` lê uma linha do teclado, com eco e
  Backspace.
- `show()` desenha o menu; `main()` repete: mostra, lê uma opção, pede o valor com
  `read_int` ou `read_uint`, escreve.
- O tamanho da órbita (registrador 6) só pode ser escrito com a simulação parada,
  então a opção 4 para, escreve e volta a rodar.

### 4.5 Gerar o processador (o `.v` do SAPHO)

O YANC transforma o programa no Verilog de um processador feito para ele. No Git
Bash:

    cd /c/Dev/hits/projects/de2_115_sapho
    YANC=/c/Dev/yanc sh software/build.sh

Ele imprime `stack depths from the program: SDEPTH 8, NDSTAC 8` e
`built: hits_menu.v, its memories and sapho/, with yanc <commit>`, e escreve:

| Arquivo | O quê |
|---|---|
| `hits_menu.v` | o processador, o módulo de topo `hits_menu` |
| `hits_menu_inst.mif`, `hits_menu_data.mif` | as memórias de instruções e de dados |
| `pc_hits_menu_mem.txt` | o mapa de instrução para linha do fonte, para a simulação |
| `sapho/*.v` | os blocos do SAPHO, copiados do YANC (núcleo do processador, ULA, teclado, tela) |
| `hits_menu.yanc` | o commit do YANC que gerou tudo |

Depois, `git status`. Se você não mudou o programa e o seu YANC está no commit que
`hits_menu.yanc` cita, nada muda: os arquivos do repositório são exatamente o que
o YANC gera. Se o YANC for mais novo, `hits_menu.yanc` e talvez `sapho/` mudam:
anote para o relatório.

O `build.sh` recusa um YANC com mudanças não commitadas, e para quando o YANC não
dimensionou as pilhas pelo programa.

**Na AURORA (opcional, para olhar):** o mesmo programa pode ser aberto na AURORA.
Crie um projeto (*Novo Projeto*), abra o *Hub de Processadores*, crie um
processador chamado `hits_menu` com a linguagem C++, troque o fonte dele pelo
conteúdo de `hits_menu.cpp` e compile. O terminal TCMM mostra a compilação do
C++, o TASM a geração do Verilog, e a pasta de saída do processador,
`hits_menu/hits_menu/`, recebe o `hits_menu.v` e as memórias. O manual da AURORA
(capítulos 4, 6 e 12) tem os detalhes. Os arquivos que a placa usa são os que o
`build.sh` escreve; a AURORA serve para ler, compilar e simular o programa
sozinho. Não foi conferido se o `hits_menu.v` da AURORA é idêntico ao do
repositório.

### 4.6 Simular o sistema inteiro

A simulação roda juntos o processador, o `hits`, o teclado, a tela e os displays,
com um teclado simulado que digita as opções. Ela precisa do Icarus Verilog no
`PATH` (a AURORA traz um em
`C:\Dev\aurora\components\Packages\msys\mingw64\bin`). No Git Bash:

    cd /c/Dev/hits/projects/de2_115_sapho
    sh sim/run.sh +screen

Leva cerca de um minuto e tem de terminar com `hits_menu: ok`. O `+screen`
imprime a tela no fim; é a tela que você vai ver no monitor (seção 6).

### 4.7 Compilar no Quartus

Abra `C:\Dev\hits\projects\de2_115_sapho\hits_de2_115.qpf` no Quartus 24.1 e rode
*Processing > Start Compilation*, ou num terminal nessa pasta:

    quartus_sh --flow compile hits_de2_115

Leva alguns minutos. Confira no *Compilation Report*: nenhum erro, nenhum aviso
crítico, e no *Timing Analyzer* todos os slacks positivos. O *Fitter > Summary*
deve dar cerca de 7656 elementos lógicos (7%). O bitstream é
`output_files\hits_de2_115.sof`.

## 5. Preparar a placa

1. Com a placa desligada: o cabo VGA no monitor, o teclado PS/2 na porta PS/2, o
   cabo USB na porta *USB Blaster* e no computador, a fonte de 12 V.
2. A chave SW19 (RUN/PROG) em **RUN** (manual da DE2-115, seção 4.1).
3. Todas as chaves deslizantes, SW0 a SW17, para baixo.
4. Ligue a placa no botão de energia. A demonstração de fábrica da placa pode
   começar: tudo bem, o próximo passo a substitui.
5. Programe a FPGA: no Quartus, *Tools > Programmer*. *Hardware Setup* =
   *USB-Blaster*, *Mode* = *JTAG*, *Add File* = o `.sof` da seção 3 ou 4.7, marque
   *Program/Configure*, *Start*. A barra tem de chegar a 100% (Successful). Se o
   *Hardware Setup* não mostrar o USB-Blaster, instale o driver de
   `<pasta do quartus>\drivers\usb-blaster` pelo Gerenciador de Dispositivos do
   Windows.

A programação pelo JTAG não sobrevive a desligar a placa: depois de desligar,
programe de novo.

## 6. O que tem de aparecer

**Os LEDs (verdes, LEDG0 a LEDG3):** o LEDG0 pisca cerca de uma vez por segundo
(o clock de 40 MHz está rodando), o LEDG1 fica aceso (o PLL travou), o LEDG3 fica
apagado (sem reset). O LEDG2 pode piscar ou ficar aceso ou apagado: ele só impede
que um sinal seja eliminado pela otimização.

**O monitor:** tela preta com texto branco. Depois de um instante (a tela é limpa
primeiro), exatamente isto:

```
HITS on SAPHO  ID 4854  CAPS 1000  running
 1 occupancy  65530 / 65536
 2 pedestal   146 ADC
 3 mode       2 (bit 0: a hit on every crossing, bit 1: the mask)
 4 orbit      3564 crossings
 7 run / stop
option?
```

com um cursor sublinhado piscando depois de `option?`. As opções 5 e 6 faltam de
propósito: elas só existem num build com jitter, e `CAPS 1000` diz que este build
não tem.

**Os displays (HEX7 a HEX0):** com todas as chaves para baixo, `0` no HEX7 e
traços do HEX4 ao HEX0 (o valor 0 nas chaves não é um registrador: veja a
seção 8).

Se algo disso for diferente, pare e relate (seção 11).

## 7. Usar o menu

Digite o número de uma opção e aperte Enter; depois digite o valor e aperte
Enter. O que você digita aparece na tela, e o Backspace apaga. Depois de cada
mudança, o menu é desenhado de novo com o valor novo.

| Opção | Pede | Faixa | O que faz no `hits` |
|---|---|---|---|
| 1 occupancy | a probabilidade de hit, em 1/65536 | 0 a 65535 | por cruzamento cheio |
| 2 pedestal | a linha de base do ADC, em contagens | -4096 a 4095 | desloca todas as amostras |
| 3 mode | bit 0: um hit em todo cruzamento (sem sorteio); bit 1: a máscara dos trens | 0 a 3 | |
| 4 orbit | cruzamentos por órbita | 1 a 3564 | para, escreve, volta a rodar |
| 7 run / stop | nada | | alterna o RUN; parado, o `hits` fica em reset |

Um valor fora da faixa dá `out of range` e pergunta de novo. Uma letra onde vai um
valor conta como fora da faixa; uma letra onde vai uma opção dá `options 1 to 7`.
Dois limites conhecidos da palavra de 16 bits: um número acima de 65535 dá a volta
(70000 vira 4464), e um número negativo na ocupação também (-5 vira 65531).

O KEY0 (botão KEY[0]) reinicia tudo: o menu volta com os valores da seção 6.

## 8. Os displays

Os registradores do `hits` não podem ser lidos de volta, então os displays
mostram o último valor que chegou ao `hits` em cada um, em decimal, lido no
próprio barramento.

| SW17 | SW3 a SW0 (binário) | HEX7 | HEX5 | HEX4 a HEX0 |
|---|---|---|---|---|
| para baixo | 2 a 8 | o número do registrador | `-` se negativo | o valor |
| para baixo | qualquer outro | o número | | traços |
| para cima | qualquer | os hits por segundo, nos oito dígitos, atualizados a cada segundo | | |

SW3 a SW0 é binário: 2 = SW1 para cima; 3 = SW1 e SW0; 4 = SW2; 5 = SW2 e SW0;
6 = SW2 e SW1; 7 = SW2, SW1 e SW0; 8 = SW3. Os registradores: 2 RUN (1 rodando,
0 parado), 3 ocupação, 4 pedestal, 5 modo, 6 órbita, 7 phase0, 8 sigma.

## 9. O teste

Anote o que você vê em cada passo, com foto da tela e dos displays onde o passo
pedir.

As taxas de hit esperadas vêm da máscara dos trens: 2340 cruzamentos cheios nos
3564 de uma órbita (2016 nos primeiros 3000). Um segundo tem 11 223 órbitas e um
terço, então a taxa varia até cerca de mil de um segundo para o outro, e alguns
milhares quando há sorteio.

| Modo | Ocupação | Órbita | Hits por segundo |
|---|---|---|---|
| 2 (máscara) | 65530 | 3564 | cerca de 26 260 000 |
| 2 (máscara) | 20000 | 3564 | cerca de 8 015 000 |
| 1 (todo cruzamento, sem máscara) | qualquer | qualquer | exatamente 40 000 000 |
| 3 (todo cruzamento cheio) | qualquer | 3564 | cerca de 26 263 000 |
| 0 (sorteio, sem máscara) | 20000 | qualquer | cerca de 12 207 000 |
| 2 (máscara) | 655 | 3000 | cerca de 269 000 |
| parado, ou ocupação 0 | | | 0 |

1. **Início.** Programe a placa (seção 5). Confira os LEDs e a tela da seção 6.
   *Foto da tela.*
2. **Os registradores.** SW17 para baixo. SW3 a SW0 = 3, 4, 5, 6 e 2, um de cada
   vez: os displays mostram `3  65530`, `4    146`, `5      2`, `6   3564`,
   `2      1`. *Foto de um deles.*
3. **A taxa.** SW17 para cima: cerca de 26 260 000. *Foto.*
4. **Ocupação.** Opção 1, valor 20000. O menu mostra
   `1 occupancy  20000 / 65536`. SW17 para baixo com SW = 3: `3  20000`. SW17 para
   cima: cerca de 8 015 000.
5. **Modo.** Opção 3 com 1: exatamente 40 000 000. Depois opção 3 com 3: cerca de
   26 263 000. Depois opção 3 com 0: cerca de 12 207 000. Depois opção 3 com 2 de
   novo.
6. **Pedestal negativo.** Opção 2, valor -5. O menu mostra
   `2 pedestal   -5 ADC`; SW17 para baixo, SW = 4: `4 -    5`.
7. **Fora da faixa.** Opção 4, valor 9999: `out of range`, e pergunta de novo;
   SW = 6 continua mostrando 3564. Depois 3000: o menu mostra
   `4 orbit      3000 crossings`, SW = 6 mostra `6   3000`, e a tela continua
   dizendo `running`.
8. **Parar e rodar.** Opção 7: `stopped` na primeira linha, SW = 2 mostra
   `2      0`, SW17 para cima mostra 0. Opção 7 de novo: `running`, SW = 2
   mostra 1.
9. **Signal Tap.** Opção 2 com 146 e opção 1 com 655, depois a seção 10. Com SW17
   para cima, cerca de 269 000.
10. **O pedestal na forma de onda.** Opção 2 com 500 e capture de novo (seção 10):
    a curva inteira do ADC sobe 354.
11. **Reset.** Aperte o KEY0: a tela limpa e mostra de novo o menu da seção 6, e
    SW = 3, 4, 6 mostram 65530, 146, 3564.

## 10. Signal Tap: as formas de onda

O Signal Tap é um analisador lógico dentro da FPGA: ele grava sinais do projeto
enquanto roda e os manda para o Quartus pelo mesmo cabo USB. Este projeto grava as
saídas do `hits` no clock de 40 MHz, 8192 amostras (cerca de 200 us, mais de duas
órbitas), começando um pouco antes do primeiro hit depois que você manda rodar.

| Sinal | O que é | Aparece como |
|---|---|---|
| `hits_out` | 1 num cruzamento com hit (o gatilho) | um fio |
| `bt_mask_out` | 1 num cruzamento cheio da máscara dos trens | um fio |
| `energy_out[12..0]` | a energia sorteada para o hit | gráfico de linha, sem sinal |
| `shaper_clip[11..0]` | **as amostras do ADC**: pedestal + pulso + ruído, de 0 a 4095 | gráfico de linha, sem sinal |
| `noise_out[16..0]` | o ruído somado | gráfico de linha, com sinal |
| `shaper_out[29..0]` | o pulso formatado antes do ADC | gráfico de linha, com sinal |

1. Com a placa programada (seção 5) e o projeto aberto no Quartus
   (`hits_de2_115.qpf` em `C:\Dev\hits\projects\de2_115_sapho`), *Tools > Signal
   Tap Logic Analyzer*. Ele abre o `signaltap/stp1.stp` do projeto.
2. No painel *JTAG Chain Configuration* (canto superior direito): *Hardware* =
   *USB-Blaster*, *Device* = o EP4CE115. No *SOF Manager*, botão `...`: escolha o
   `.sof` que você programou. O estado tem de dizer que a instância está pronta,
   não que o projeto é diferente. **Não** programe de novo daqui, a não ser que o
   estado peça.
3. *Processing > Run Analysis* (a captura única, não o *Autorun*). Como o menu está
   rodando, um hit vem na hora e a captura enche: o estado passa de *Waiting for
   trigger* para *Acquiring* e termina numa fração de segundo.
4. A aba *Data* mostra as formas de onda. Clique na área das ondas para aproximar e
   use o botão direito para afastar; para ver as 8192 amostras, afaste até caberem.
   Se um barramento aparecer como números em vez de curva, clique com o botão
   direito no nome dele, *Bus Display Format*, *Unsigned Line Chart* (ou *Signed
   Line Chart* para `noise_out` e `shaper_out`).
5. O que procurar com pedestal 146 e ocupação 655:
   - `shaper_clip` fica perto de 146 com um ruído pequeno (algumas contagens) e,
     depois de cada hit, um pulso que sobe e volta ao pedestal;
   - `hits_out` só pulsa onde `bt_mask_out` é 1 (os buracos da máscara não têm
     hits);
   - `energy_out` muda a cada hit.
   *Captura de tela da aquisição inteira e de um pulso aproximado.*
6. Salve a captura: *File > Export*, formato `.csv`, com o nome
   `capture_ped146_occ655.csv`. Para o passo 10 da seção 9, o mesmo com
   `capture_ped500_occ655.csv`.

Se o estado disser que o projeto não confere, o `.sof` do *SOF Manager* não é o
que foi programado, ou o repositório não está no commit do `.sof` (seção 3,
passo 1).

## 11. O relatório

Mande para quem pediu o teste e publique na issue
[#14](https://github.com/nipscernlab/hits/issues/14) do `hits`:

1. o caminho (A ou B), o commit (`git log -1 --oneline` em `C:\Dev\hits`), a
   versão do Quartus e, no caminho B, o commit do YANC (`hits_menu.yanc`) e a
   saída do `git status` depois do `build.sh`;
2. para cada passo da seção 9: o que você viu e se bateu; as fotos que os passos
   pedem;
3. as capturas de tela e os dois `.csv` da seção 10;
4. tudo o que não bateu, com o que você fez logo antes.

## 12. Quando algo dá errado

- **O monitor diz "sem sinal" ou "fora da faixa":** confira o cabo VGA e se o
  monitor aceita 640 x 480 a 60 Hz. O LEDG0 tem de estar piscando; se não estiver,
  a FPGA não está programada (seção 5).
- **A tela mostra o menu, mas digitar não faz nada:** o teclado pode não falar
  PS/2 (um teclado USB num adaptador); tente outro. Tirar e pôr um teclado PS/2
  com a placa ligada pode confundi-lo: conecte e aperte o KEY0.
- **Caracteres errados na tela, ou uma tecla repetida ou perdida:** é exatamente
  disso que trata a correção yanc#64. Relate com foto e com o commit do YANC em
  `hits_menu.yanc`.
- **Os displays mostram traços:** SW3 a SW0 não está entre 2 e 8 (seção 8).
- **A taxa é 0:** a simulação está parada (`stopped` na tela, opção 7), ou a
  ocupação é 0.
- **Programmer: "No hardware":** o driver do USB Blaster (seção 5, passo 5), ou o
  cabo na porta USB errada da placa (tem de ser a marcada *USB Blaster*).
- **O `build.sh` diz "no compilers":** rode `make` na pasta do YANC (seção 4.2).
- **O `build.sh` diz que o YANC "has uncommitted changes":** algo mudou no seu
  clone do YANC; rode `git status` lá. Não faça commit nem reset de nada nele sem
  perguntar ao grupo.
- **O `sim/run.sh` diz `iverilog: command not found`:** ponha o Icarus no `PATH`
  (seção 4.6).
