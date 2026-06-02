# Z-Logs

Sistema web academico em Haskell + Yesod para processamento concorrente e armazenamento centralizado de logs.

## Escopo atual

Esta versao implementa o planejamento funcional das telas, ainda sem camada visual definitiva:

- Home / upload de logs em `/`;
- Historico de lotes em `/lotes`;
- Detalhes, filtro por categoria e exclusao em `/lotes/#LogBatchId`;
- Simulacao de carga concorrente em `/simulacao`;
- Benchmark sequencial vs paralelo em `/benchmark`;
- Dashboard estatistico em `/dashboard`.

## Banco de dados

O projeto usa PostgreSQL via Persistent. Para subir um banco local:

```bash
docker compose up -d
```

String de conexao padrao:

```text
host=localhost port=5432 user=zlogs password=zlogs dbname=zlogs
```

Tambem e possivel sobrescrever com `DATABASE_URL`.

## Executando

Com GHC/Cabal instalados:

```bash
cabal update
cabal run zlogs
```

A porta padrao e `3000`, configuravel por `PORT`.

## Observacao

O front-end final foi deixado de fora de proposito. Os templates Hamlet atuais existem apenas para validar navegacao, formularios e fluxos server-side; a estilizacao pode ser substituida depois, por exemplo com Tailwind.
