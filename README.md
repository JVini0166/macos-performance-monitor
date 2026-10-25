<div align="center">
  <img src="https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/assets/app-icon.png" width="144" alt="Ícone do Performance Monitor" />

  <h1>Performance Monitor</h1>
  <p><strong>A performance do seu Mac, em uma interface feita para ele.</strong></p>
  <p>Processos, CPU, memória, disco, rede e GPU em um app nativo feito com SwiftUI.</p>

  <p>
    <img alt="macOS 14 ou superior" src="https://img.shields.io/badge/macOS-14%2B-1d252d?logo=apple&logoColor=white" />
    <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" />
    <img alt="Interface SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-36b8d4" />
    <img alt="Sem dependências externas" src="https://img.shields.io/badge/depend%C3%AAncias-zero-a98adb" />
  </p>
</div>

---

Um monitor de sistema nativo para macOS, com sidebar translúcida, barra de ferramentas do sistema e gráficos em cartões. A interface acompanha os modos claro e escuro e adota **Liquid Glass no macOS 26 ou superior**, com materiais compatíveis nas versões anteriores. As métricas são coletadas localmente a cada segundo, com histórico de 60 segundos.

## Veja o app

### Processos

Tabela nativa com busca, filtros, ordenação e cores proporcionais ao uso de recursos.

![Aba Processos com aplicativos ordenados por memória, indicadores globais e controles nativos do macOS](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/processos.jpg)

### Performance

| CPU por processador lógico | Memória e swap |
| :--: | :--: |
| [![Gráficos de CPU por processador lógico e temperatura](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/cpu.jpg)](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/cpu.jpg) | [![Uso e composição da memória com métricas de swap](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/memoria.jpg)](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/memoria.jpg) |
| **Disco: leitura e escrita** | **GPU e memória compartilhada** |
| [![Painel Disco 0 com atividade, leitura e escrita](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/disco.jpg)](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/disco.jpg) | [![Utilização dos engines da GPU e memória compartilhada em uso](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/gpu.jpg)](https://raw.githubusercontent.com/JVini0166/macos-performance-monitor/master/docs/screenshots/gpu.jpg) |

Capturas reais no macOS, em um Mac com Apple M5. Clique nas imagens da galeria para abrir em tamanho completo. As leituras refletem o momento da captura e dependem do hardware e dos contadores disponíveis.

## Processos e Performance

As abas no topo alternam entre **Processos**, com uma tabela nativa do sistema, e **Performance**, com os gráficos de recursos.

Em Processos, acompanhe nome, estado, CPU, memória, leitura e escrita de disco, threads, usuário e PID. Clique no cabeçalho para ordenar; pesquise por nome, PID ou usuário; filtre todos os processos, aplicativos, segundo plano ou apenas os do seu usuário. As células recebem uma intensidade de cor proporcional ao uso, mantendo a aparência nativa do Mac.

Selecione uma linha para abrir **Informações** ou **Finalizar processo**. O encerramento pede confirmação, oferece encerramento normal ou forçado e só permite processos do usuário atual; o monitor não finaliza a si mesmo. A identidade e o proprietário do processo são conferidos novamente antes do sinal. Encerrar um processo pode perder dados não salvos.

A tabela é atualizada a cada **2 segundos**, apenas enquanto a aba está ativa e a coleta não está pausada. CPU segue a convenção do Monitor de Atividade: **100% equivale a um processador lógico**, então processos com várias threads podem passar de 100%. Os cartões do topo mostram utilização global; suas porcentagens não devem ser comparadas diretamente com a soma das linhas. GPU e rede por processo não estão disponíveis; processos protegidos mostram “—” para as leituras restritas.

## O que você pode acompanhar

| Painel | Em tempo real |
| :-- | :-- |
| **CPU** | Utilização geral ou por processador lógico, tempos do kernel, temperatura e tempo de atividade. |
| **Memória** | RAM em uso, composição, cache, disponível, wired, comprimida e swap usado/alocado com entrada e saída. |
| **Disco** | Leitura e escrita, atividade estimada, tempo médio de I/O e IOPS, com cada dispositivo físico na sidebar como Disco 0, Disco 1 e assim por diante. |
| **Rede** | Taxas de envio e recebimento agregadas das interfaces sem loopback. |
| **GPU** | Utilização geral, renderização, tiler, memória em uso/alocada e temperatura, quando expostos pelo hardware. |

### Um gráfico para cada processador

Clique com o botão direito no gráfico da CPU e escolha **Alterar gráfico para → Processadores lógicos**. No mesmo menu, ative **Mostrar tempos do kernel** para sobrepor uma linha tracejada ou use **Copiar resumo**. A preferência de visualização é salva entre execuções.

### GPU e temperaturas

O painel da GPU mostra os contadores globais do driver, com gráficos de utilização e memória. No Apple Silicon, a interface identifica a memória unificada como **compartilhada com a CPU**. As temperaturas vêm de sensores AppleSMC identificados; o valor exibido é o maior entre os sensores disponíveis de cada componente.

## Começar

**Requisitos:** macOS 14 ou superior e toolchain Swift 6 com SDK do macOS 26 ou superior para compilar as APIs Liquid Glass. Para compilar, use o Xcode ou as Command Line Tools com um SDK compatível.

```sh
git clone https://github.com/JVini0166/macos-performance-monitor.git
cd macos-performance-monitor
swift run
```

Também é possível abrir `Package.swift` no Xcode e executar o target **PerformanceMonitor**.

## Gerar o aplicativo `.app`

```sh
bash scripts/build-app.sh
open "dist/Performance Monitor.app"
```

O script compila em modo Release, inclui o ícone e cria o bundle em `dist/`. A assinatura é local (*ad hoc*); o app não é notarizado para distribuição. Para instalar para seu usuário, copie **Performance Monitor.app** para `~/Applications`.

## Controles

| Ação | Como usar |
| :-- | :-- |
| Selecionar um painel | Clique no recurso na lista lateral. |
| Pausar ou retomar | **⌘P** ou o botão no canto superior direito. |
| Alternar o gráfico da CPU | Clique direito no gráfico ou use o menu de grade. |
| Recolher a navegação | Botão de barra lateral no topo da janela. |
| Trocar de disco | Clique em **Disco 0**, **Disco 1** e assim por diante na sidebar. |
| Trocar de GPU | Seletor no painel da GPU, quando houver mais de uma disponível. |

O histórico começa vazio na GPU e zerado nos demais recursos, sendo preenchido com novas amostras. A pausa congela os valores e os gráficos; ao retomar, os contadores de taxa restabelecem sua base.

## Precisão e compatibilidade

A interface usa os componentes nativos do macOS; os contadores respeitam a arquitetura do sistema.

- **Disco:** leitura e escrita são medidas por diferenças dos contadores de I/O. O tempo ativo é uma estimativa e pode superestimar atividade com operações paralelas.
- **RAM:** apps, cache e disponível são estimativas a partir das páginas do kernel. Swap usado e alocado são lidos diretamente do sistema.
- **GPU:** os contadores variam por driver. Encode/decode e VRAM dedicada não são expostos nesta versão; dados ausentes aparecem como indisponíveis.
- **Temperatura:** há mapas para Apple M5 e sensores convencionais Intel. Outros chips precisam de validação dos sensores. Uma leitura ausente nunca é substituída por uma temperatura inventada.
- **Rede:** interfaces virtuais e túneis podem causar contagem duplicada.

Consulte [contadores, fórmulas e referências](docs/METRICS.md) para os detalhes de cada métrica, diferenças entre sistemas e fontes da Microsoft e da Apple.

## Desenvolvimento

```sh
swift build
swift test
```

Os **10 testes** verificam taxas de I/O, reinício de contadores, dados inválidos de GPU, decodificação térmica, conversão do tempo Mach de CPU, identidade de processos e coleta local com pausa. Os testes de integração esperam um Mac com disco físico e GPU Metal; a verificação térmica adicional se aplica ao Apple M5.

```text
Sources/PerformanceMonitor/
├── App.swift                 # Janela, navegação e gráficos
├── NativeStyle.swift         # Superfícies adaptativas e controles Liquid Glass
├── MonitorRootView.swift     # Abas Processos e Performance
├── ProcessMetrics.swift      # Coleta e identidade dos processos via libproc
├── ProcessesView.swift       # Tabela, filtros e ações de processos
├── Metrics.swift             # Amostragem e históricos
├── DiskMetrics.swift         # I/O dos discos físicos via IOKit
├── GPUMetrics.swift          # Identificação Metal e contadores do driver
├── GPUPerformanceView.swift  # Painel da GPU
└── TemperatureReader.swift   # Leitura dos sensores AppleSMC
```

**Local por padrão:** sem telemetria, serviços externos, bibliotecas de terceiros ou helper privilegiado. A coleta apenas lê os contadores; o app não altera ventoinhas ou configurações do sistema. Sinais de encerramento só são enviados pela ação explícita de finalizar um processo, após confirmação na interface.

---

Projeto independente. Sem vínculo com a Microsoft ou a Apple.
