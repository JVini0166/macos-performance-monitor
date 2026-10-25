# Performance Monitor

App nativo para macOS em SwiftUI, inspirado na aba Performance do Gerenciador de Tarefas do Windows 11. Requer macOS 14 ou superior e Swift 6.

## Executar e gerar o aplicativo

```sh
swift run
bash scripts/build-app.sh
open "dist/Performance Monitor.app"
```

Também é possível abrir `Package.swift` no Xcode. Execute `swift test` para verificar os cálculos de I/O, os coletores locais e a pausa.

## Painéis

- CPU: utilização geral ou gráficos individuais por processador lógico. Clique direito no gráfico → Alterar gráfico para → Processadores lógicos. O menu também oferece tempos do kernel e cópia do resumo. A preferência do gráfico é persistida.
- Memória: uso físico, disponível, cache, wired, comprimida, apps, memória livre, swap usado/alocado/disponível e entrada/saída do swap. Inclui barra de composição.
- Disco: seleção por dispositivo físico, atividade estimada, leitura e escrita em bytes/s, tempo médio de I/O e IOPS. Dois gráficos mostram atividade e transferência; a linha tracejada representa escrita. Imagens de disco são excluídas.
- GPU: utilização geral, renderização e tiler, com histórico de 60 segundos; memória de sistema em uso e alocada pelo driver; identificação do modelo Metal e seleção entre GPUs. Temperatura máxima dos sensores identificados, quando disponível.
- Rede: transferência agregada das interfaces sem loopback. Túneis podem resultar em contagem duplicada.

Amostragem a cada segundo, com 60 amostras de histórico, inicialmente zeradas. ⌘P pausa os valores e gráficos. Ao retomar, os coletores restabelecem a base dos contadores para evitar picos artificiais.

## Contadores e diferenças entre sistemas

CPU usa `host_statistics` e `host_processor_info`. Os processadores lógicos correspondem aos índices expostos pelo Mach; o menu não altera afinidade nem habilita núcleos. A linha do kernel usa `CPU_STATE_SYSTEM`.

Memória usa `host_statistics64`, tamanho de página do kernel e `sysctl vm.swapusage`. Apps é uma estimativa de `(active + inactive − external − purgeable) × pageSize`, limitada a zero. Uso físico soma apps, wired e páginas do compressor, limitado à RAM instalada. Disponível é RAM menos uso estimado; cache estima páginas externas e purgáveis, limitado ao disponível. Livre vem de `free_count`. São estimativas, sem promessa de equivalência exata ao Activity Monitor. Swap usado e alocado vêm diretamente de `xsw_usage`. O swap alocado cresce dinamicamente e não representa um limite de commit.

Disco usa os contadores cumulativos do `IOBlockStorageDriver` via IOKit. Taxas são diferenças entre amostras divididas pelo intervalo monotônico efetivamente decorrido. Tempo médio de I/O é a diferença dos tempos totais dividida pelas operações concluídas, em milissegundos; sem operações mostra “—”. O percentual de atividade é uma **estimativa**: soma dos tempos de leitura/escrita dividida pelo intervalo, limitada a 100%. Operações paralelas se sobrepõem, portanto esse número pode superestimar o tempo ativo e não equivale ao contador de ociosidade do Windows. Dados ausentes não são apresentados como zero. A capacidade física aparece apenas como informação secundária.

Memória comprometida, paged pool e non-paged pool têm semântica específica do Windows e não são renomeados artificialmente para contadores do Mac. Frequência instantânea de CPU ainda não é coletada. Não há telemetria, privilégios de administrador ou dependências externas.

## Referências

- [Microsoft: gráficos por processador lógico](https://learn.microsoft.com/en-us/troubleshoot/windows-server/support-tools/support-tools-task-manager)
- [Microsoft: contadores de desempenho de disco](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntdddisk/ns-ntdddisk-_disk_performance)
- [Microsoft: memória e desempenho](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-performance-problems-in-windows)
- [Microsoft: visão de Performance e seus gráficos](https://blogs.windows.com/windowsexperience/2013/06/06/windows-8-task-manager-in-depth/)
- [Apple: métricas de memória do Activity Monitor](https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac)
- [Apple: contadores IOBlockStorageDriver e suas unidades](https://github.com/apple-oss-distributions/IOStorageFamily/blob/main/IOBlockStorageDriver.h)

## GPU e temperatura

A GPU é identificada pelo Metal e vinculada ao registro IOKit pelo `registryID`, evitando misturar placas distintas. `PerformanceStatistics` fornece `Device Utilization %`, `Renderer Utilization %`, `Tiler Utilization %`, `In use system memory` e `Alloc system memory`. Os valores refletem os contadores globais do driver. Utilização geral é o contador do driver, e não uma soma dos engines. Esses campos não constituem um contrato público estável da Apple; se ausentes ou inválidos, a interface apresenta indisponibilidade e lacunas no histórico. Encode/decode não são inventados a partir da utilização de renderização.

O gráfico de memória usa o contador **In use system memory**; **Alloc system memory** é mostrado separadamente. Não são somados. Em Apple Silicon, a memória é unificada com a CPU, não VRAM dedicada adicional. A RAM física é apenas a escala do gráfico, não um orçamento reservado. `recommendedMaxWorkingSetSize` é uma recomendação do Metal, não um limite rígido. `currentAllocatedSize` não é usado: ele representa recursos alocados pelo próprio processo, não o uso global da GPU. Em GPUs com memória separada, o painel identifica que a VRAM dedicada está indisponível, em vez de apresentar memória de sistema como VRAM.

Temperaturas vêm exclusivamente de leituras AppleSMC, sem comandos de escrita, controles de ventoinha, sudo ou helper. A interface exibe a máxima dos sensores identificados, com as chaves na seção de detalhes. Há mapeamento para Apple M5 e sensores convencionais Intel; outros modelos apresentam indisponibilidade até que seu mapa seja validado. A temperatura da GPU via SMC só é associada à GPU Apple unificada correspondente ao processador. Não se atribui a temperatura do SoC a uma GPU externa. O acesso AppleSMC e os tipos `sp78`/`flt ` não são APIs públicas estáveis; falhas deixam os valores indisponíveis, sem reutilizar leituras antigas. Temperatura, GPU e histórico respeitam a pausa global.

Referências adicionais:

- [Microsoft: engines e memória de GPU no Task Manager](https://devblogs.microsoft.com/directx/gpus-in-the-task-manager/)
- [Apple: memória unificada](https://developer.apple.com/documentation/metal/mtldevice/hasunifiedmemory)
- [Apple: working set recomendado](https://developer.apple.com/documentation/metal/mtldevice/recommendedmaxworkingsetsize)
- [Apple: memória Metal alocada pelo processo](https://developer.apple.com/documentation/metal/mtldevice/currentallocatedsize)
- [Stats: catálogo de identificadores de sensores por modelo](https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift)
- [SMCKit: referência do protocolo AppleSMC](https://github.com/beltex/SMCKit/blob/master/SMCKit/SMC.swift)

## Processos

A lista é obtida com `proc_listallpids` e `proc_pidinfo`. Identidade combina PID e horário de início (`pbi_start_tvsec`/`pbi_start_tvusec`), evitando misturar contadores de PIDs reutilizados. `proc_pid_rusage` com `RUSAGE_INFO_V2` fornece CPU acumulada (usuário + sistema, em ticks Mach convertidos para nanossegundos por `mach_timebase_info`), physical footprint e bytes de I/O. CPU e taxas de disco são deltas divididos pelo tempo monotônico entre as leituras; não se usa a idade total do processo. CPU não é dividida pela quantidade de processadores lógicos: 100% corresponde a um processador, como no Monitor de Atividade. RAM usa physical footprint quando disponível, com fallback para memória residente via `PROC_PIDTASKINFO`.

Aplicativos são os processos registrados no NSWorkspace com `activationPolicy == regular`; seus helpers continuam na categoria segundo plano. Ícones e nomes amigáveis vêm do NSWorkspace. Não há soma de filhos nem inferência de GPU/rede por processo. O estado é a classificação BSD da última amostra. Leituras sem permissão permanecem indisponíveis. Amostragem ocorre em tarefa de utilidade a cada dois segundos, apenas na aba Processos; a pausa limpa a base antes de retomar. Ações de encerrar conferem novamente a identidade e UID, recusam PID 1 e o próprio monitor e enviam SIGTERM ou SIGKILL somente após confirmação na UI.

- [Apple: tabelas SwiftUI](https://developer.apple.com/documentation/swiftui/table)
- [Apple: implementação libproc](https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/wrappers/libproc/libproc.c)
- [Apple: preenchimento dos contadores de processos](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/bsd_kern.c)
