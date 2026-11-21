# Turnip Perf + One UI (8 Gen 2)

Kit de build independente para Mesa Turnip, com correção UBWC para Adreno 740 e ajustes opcionais de desempenho.

O workflow está em .github/workflows/turnip_build_perf_oneui.yml. O build roda automaticamente em push na main e também pode ser iniciado manualmente em Actions.

Artifact esperado: turnip-perf-oneui-8g2, contendo o ZIP do driver e o relatório balemuni_perf_report.txt.

ATENÇÃO: destinado ao Snapdragon 8 Gen 2 / Adreno 740 em firmware Samsung One UI compatível. O binário precisa ser testado no aparelho antes de qualquer conclusão sobre estabilidade ou FPS.
