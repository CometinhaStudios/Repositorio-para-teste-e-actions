# Turnip para Adreno 710

Build experimental do Mesa/Turnip com o identificador Qualcomm Adreno 710 (chip ID `0x07010000`) associado ao perfil base `FD725`.

> **Atenção:** compilar não prova compatibilidade em runtime. O A710 está sendo associado ao perfil FD725 como teste; isso precisa ser validado no aparelho e pode causar falhas gráficas ou travamentos.

## Build
O workflow `.github/workflows/build-turnip-a710.yml` roda automaticamente quando esta pasta ou o workflow muda, e também pode ser iniciado manualmente em **Actions → Build Turnip Adreno 710**.

O artefato `turnip-adreno710` contém o ZIP importável no gerenciador de drivers do emulador, além do relatório de build.

## Parâmetros padrão
- Mesa: `mesa-26.2.6`
- GPU base: `FD725`
- Android API: `33`
- NDK: `27.2.12479018`
- LTO: desativado

Se falhar, envie o trecho final do log do job **Build**.
