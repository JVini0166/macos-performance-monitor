# Identidade visual

O ícone original está em [`assets/app-icon.png`](../assets/app-icon.png), em PNG com transparência. Foi criado com a ferramenta integrada `image_gen`, em 24 de outubro de 2026. As cores ciano e violeta correspondem aos gráficos de CPU e GPU da interface.

O script de build gera as resoluções do macOS com `sips` e empacota `AppIcon.icns` com `iconutil`, sem dependências adicionais. O PNG é a fonte; as variantes ficam em `.build/` e o ícone final em `dist/Performance Monitor.app/Contents/Resources/`.

## Prompt de geração

> Use case: logo-brand. Asset type: production macOS app icon, square 1024x1024. Create an original premium icon for Performance Monitor, a native macOS system performance monitoring app. One centered dark graphite rounded-square tile, generous transparent margin around the tile, subtle sculpted depth and crisp polished bevel. On the tile: a single beautifully legible cyan performance area graph / oscillating activity trace over a very subtle grid, with one violet accent ridge evoking GPU monitoring. Restrained, precise, technical, elegant. Straight-on orthographic view, no perspective. Strong silhouette and recognizable at 32 pixels. Match a dark UI with cyan CPU and violet GPU charts. No text, no letters, no numbers, no trademark logos, no watermark, no mockup surrounding the icon. True transparent background outside the rounded-square tile.
