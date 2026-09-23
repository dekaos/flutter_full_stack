# scorer

Toolchain de pronúncia: **fora do device**. Nada aqui roda em produção — isto
valida o score, exporta o modelo que o app carrega e gera o léxico que ele
embarca. O app (`flutter_full_stack_flutter/lib/core/pronunciation/`) é a
implementação de verdade; este pacote é a referência contra a qual ela é
travada.

## Por que GOP e não ASR

Reconhecer o que foi dito não diz se foi **bem** dito. O score de pronúncia sai
do *Goodness of Pronunciation*: alinha-se o áudio à sequência canônica de
fonemas do texto (que é conhecido — o aluno lê um texto dado) e mede-se, fonema
a fonema, o log-posterior do fonema certo e a margem para o melhor concorrente.
A margem é o que vira feedback útil: não "68 pontos", e sim "você disse /t/ onde
era /ð/".

Modelo acústico: wav2vec2 CTC com saída em IPA, um por idioma —
`facebook/wav2vec2-lv-60-espeak-cv-ft` (en) e
`facebook/wav2vec2-xlsr-53-espeak-cv-ft` (es), com o commit fixado em
`UPSTREAM_REVISIONS`. Origem, licenças, hashes dos arquivos publicados e o que
refazer ao trocar um modelo: [docs/pronunciation-models.md](../docs/pronunciation-models.md).

## Uso

```bash
uv sync --group export

# score de um áudio contra um texto
.venv/bin/python -m gop.cli --lang en \
  --text "The weather is beautiful today" --audio audio/en_ok.wav

# modelo para o device: ONNX int8 (355 MB por idioma)
.venv/bin/python tool/export_onnx.py en

# léxico que o app embarca (G2P roda aqui, nunca no device)
.venv/bin/python tool/build_lexicon.py exercises/en.json \
  > ../flutter_full_stack_flutter/assets/lexicons/en.json

# paridade: o int8 não pode mover o score
.venv/bin/python tool/check_int8.py

# fixture que trava o alinhador Dart no resultado do torchaudio
.venv/bin/python tool/make_align_fixture.py
```

## Números medidos

| | fp32 | int8 |
|---|---|---|
| voz nativa (en) | 84.3 | 83.4 |
| voz pt-br lendo em inglês | 13.0 | 12.7 |

Esses dois são com o fallback chutado, para comparar fp32 com int8. Com a
calibração medida os valores são outros — ver **Resultado medido**.
| tamanho do modelo | 1264 MB | 355 MB |

A nota **é** a pronúncia. A fluência é calculada e exibida ao lado, mas fora
da nota: ela só perde ponto por pausa longa ou ritmo fora da faixa, então
fica perto de 100 em quase toda tentativa. Misturada a 25%, transformava uma
leitura de 45 em 57. E os insumos dela são as durações do alinhamento — que é
*forçado*, ou seja, encaixa todo fonema canônico em algum lugar por pior que
tenha saído. O ritmo parece plausível exatamente quando a pronúncia não é.

Os áudios de `audio/` são sintetizados com espeak-ng (voz `en-us` como
pronúncia canônica, voz `pt-br` lendo o texto em inglês como proxy de sotaque).
Servem de smoke test, **não** de calibração.

## Calibração

A curva log-posterior → 0–100 é **dado, não código**: sai de
`calibration/<lang>.json` e viaja dentro do léxico até o app.

```bash
./tool/fetch_corpus.sh en          # LibriSpeech test-clean, 330 MB
.venv/bin/python tool/calibrate.py en \
  --corpus corpus/LibriSpeech/test-clean --limit 700 \
  --substitutions 500 --device mps
```

### Como se calibra sem gravar ninguém

Precisa-se de duas distribuições por fonema, e nenhuma exige coletar aluno:

- **certo**: o GOP do fonema em áudio nativo alinhado contra a transcrição
  verdadeira. Sai de corpus público.
- **errado**: o log-posterior de um fonema que *não foi dito*, medido na
  janela em que outro foi.

A janela vem do alinhamento **correto**, e isso é essencial. A primeira versão
alinhava contra uma transcrição corrompida e não funcionou: o Viterbi
reposiciona as fronteiras e encaixa o fonema trocado onde ele for plausível,
então o "erro" saía com GOP alto e não havia separação alguma.

Qual troca simular importa tanto quanto o método:

| negativo | mediana (en) |
|---|---|
| confusão real de brasileiro (`CONFUSIONS`) | −6,80 |
| fonema sorteado da mesma classe | −12,67 |
| (nativo, para comparação) | −0,06 |

Ancorar no sorteado estica a escala e produz curva frouxa: ninguém diz uma
consoante aleatória no lugar de /θ/, diz /t/. A tabela `CONFUSIONS` é a
confusão que o aluno comete de verdade, e é contra ela que a régua se ajusta.

### O que as duas âncoras significam

`TARGET_NATIVE = 0.90` e `TARGET_WRONG = 0.30`: a mediana nativa vira 90, a
mediana do erro típico vira 30. **São decisão pedagógica, não estatística** —
dizem o quanto "cometer o erro clássico de brasileiro" deve custar. Mudar o
segundo para 0.15 e recalibrar é uma linha.

### Resultado medido

| | nativo | sotaque pt-br | curvas próprias |
|---|---|---|---|
| inglês | 88,6 | 36,4 | 53 de 58 fonemas |
| espanhol | 79,3 | 53,7 | 30 de 38 fonemas |

A separação menor em espanhol não é defeito: português e espanhol são
próximos, e um brasileiro lendo espanhol erra muito menos do que lendo inglês.

As curvas por fonema saem com a forma certa. Fonema confusável fica apertado
(`/ʌ/` center −2,8, `/ɪ/` −3,3 em inglês; `/ɾ/` −1,6 e `/β/` −2,1 em espanhol,
que são exatamente os pares que o brasileiro erra) e fonema distintivo ganha
folga (`/ɔɪ/` −10,9, `/ʝ/` −11,7).

## Concordância com avaliador humano

A única medida de acurácia que este projeto tem. Tudo o mais compara o modelo
com ele mesmo; isto compara com professor.

```bash
./tool/fetch_corpus.sh speechocean762      # 521 MB, CC BY 4.0
.venv/bin/python tool/evaluate.py --limit 800 --device mps
```

| | nosso | referência |
|---|---|---|
| fala, Pearson | **0,541** | ~0,72 estado da arte · 0,45–0,60 baselines GOP |
| fala, Spearman | 0,496 | |
| palavra, Pearson | 0,293 | |
| palavra imperfeita, AUC | **0,792** | 0,5 = moeda |

800 falas sorteadas do split de teste, n grande o bastante para um intervalo de
±0,06 no Pearson.

Ler com três ressalvas, todas contra nós: os falantes têm **mandarim** como L1
e a nossa calibração foi ajustada com confusões de **brasileiro**; o modelo
acústico nunca viu falante não nativo; e nada foi treinado neste corpus — é
zero-shot, enquanto os números publicados treinam nele.

No nível de palavra, 90% recebem nota 10 do humano. Correlação sobre variável
quase constante é ruído, e por isso a métrica que importa ali é detecção: o
AUC de 0,792 diz que, sorteando uma palavra imperfeita e uma perfeita, o nosso
score ordena as duas corretamente em 79% das vezes.

**Duas armadilhas de método que custaram uma leitura errada:**

- Tomar as primeiras N falas do arquivo amostra poucos falantes: o corpus vem
  agrupado por falante. As primeiras 40 tinham média humana 8,7 e desvio 0,8
  contra 7,7 e 1,54 do conjunto. Correlação sobre faixa comprimida deu 0,254,
  menos da metade do valor real. A amostra é sorteada com semente.
- Correlação no nível de palavra parece catastrófica (0,13 de Spearman) e não
  é: é o efeito dos 90% em 10.

## Cabeça de regressão

A curva calibrada trata cada fonema isoladamente e depois tira média. Ela não
tem como saber que um /θ/ ruim pesa mais que um /ə/ ruim, que duração curta é
sinal, que importa quem ficou em segundo lugar, ou que o fonema anterior
condiciona o seguinte. Uma cabeça que lê a **sequência** sabe.

```bash
python tool/dump_features.py train --device mps    # ~40 min por split
python tool/dump_features.py test  --device mps
python tool/train_head.py --dropout 0.5 --dim 32 --weight-decay 1e-4
```

Segue a forma do GOPT (ICASSP 2022): 60 features por fonema — log-posterior do
canônico, margem, duração e a razão contra cada um dos 57 fonemas do
inventário — projetadas para 32 dimensões, somadas à embedding do fonema e à
posicional, três camadas de encoder.

| | fala (PCC) | fonema (PCC) |
|---|---|---|
| GOP + curva calibrada | 0,546 | — |
| **GOP + cabeça** | **0,675** | **0,555** |
| GOPT publicado | 0,742 | 0,612 |

**33,6 mil parâmetros, 131 KB.** O sistema que fecha dois terços da distância
para o estado da arte é menor que o léxico dos exercícios. Isso é o ponto: o
custo nunca foi runtime, foi dado rotulado.

### Método, porque aqui é fácil mentir

- **Split oficial do corpus**, separado por falante. Treino nas 2500 de
  treino, teste nas 2500 de teste.
- **Validação tirada do treino**, nunca do teste. A primeira rodada escolhia a
  época olhando o teste e reportou 0,670; com validação honesta o mesmo
  modelo dá 0,658.
- **Hiperparâmetros escolhidos pela validação**, com o teste medido uma vez no
  ponto escolhido.
- Validação 0,787 contra teste 0,675 não é bug: a validação compartilha
  falantes com o treino e o teste não. Avaliação com voz inédita é mais
  difícil, e é a que conta.

### O que falta para os 0,742

A diferença provável está nas features, não na cabeça: o GOPT parte de um
alinhador Kaldi com 84 dimensões de GOP, e as nossas 60 vêm de um CTC. E 8%
dos rótulos por fonema se perdem no pareamento posicional entre IPA e ARPAbet.

**Nada disto foi integrado ao app ainda.** A cabeça é treinada em falantes de
mandarim; vale como prova de que a arquitetura fecha a distância, não como o
modelo que deve pontuar um brasileiro.

### Dois experimentos que não pagaram

Registrados porque saber onde *não* investir vale tanto quanto o contrário.
`tool/tune.py` trabalha sobre o GOP cru cacheado por `evaluate.py --dump`, sem
reprocessar áudio.

**Agregação.** A hipótese era que a média dos fonemas dilui os poucos ruins,
enquanto o avaliador humano pesa o erro saliente. Falsa:

| agregador | Pearson |
|---|---|
| percentil 25 | 0,549 |
| **média (atual)** | **0,546** |
| média dos 40% piores | 0,545 |
| percentil 10 | 0,529 |
| mínimo | 0,381 |

Tudo que é razoável fica entre 0,51 e 0,55; só os extremos pioram. A
informação não está em como combinar os fonemas.

**Calibração supervisionada.** Reajustar as curvas contra o erro humano real
em vez do erro simulado dá +0,014 (0,546 → 0,560), e +0,021 somando percentil
25. Real, mas pequeno — e não escala: com 800 falas apenas 1 fonema junta
amostra de erro suficiente, com 1500 são 14, e o ganho não se move. O gargalo
não é volume de áudio, é que só 10% das palavras têm erro rotulado.

Duas armadilhas de método aqui também, ambas descobertas depois de um
resultado enganoso:

- Comparar a curva humana usando o fallback **chutado** como base global, em
  vez do global **medido**, fazia a calibração humana parecer pior que a
  simulada (0,521 contra 0,546). Os fonemas sem curva humana caíam num global
  errado e levavam a culpa.
- A nota por fonema é média de cinco avaliadores, então vem fracionada. Tratar
  tudo abaixo de 2 como erro joga 1,8 — que é "a maioria achou certo" — na
  distribuição de erro e borra as duas. A faixa do meio é descartada.

**Nada disso foi aplicado ao app.** As curvas humanas vêm de falantes de
mandarim; usá-las num produto para brasileiro troca um viés conhecido por
outro, em troca de 0,02.

### O que ainda falta
- **Aluno brasileiro real.** As curvas foram ajustadas contra erro *simulado*
  em voz nativa. Erro simulado é limpo; aluno de verdade tem hesitação, ruído
  e prosódia própria. O speechocean762 mede a régua, não o nosso aluno.
- **Onde fica o "bom o suficiente".** Que 70 signifique "pode seguir" é
  pedagogia, e nenhum corpus responde.

## Três armadilhas já resolvidas

- **Quantizar `Conv` quebra no Android.** A quantização dinâmica gera
  `ConvInteger`, cujo kernel do onnxruntime não aceita peso int8: o app morre
  ao abrir a sessão com "Could not find an implementation for ConvInteger".
  Só os `MatMul` são quantizados. Custa 38 MB e *melhora* a paridade (a perda
  cai de 2,6 para 0,7 ponto), porque o extrator de features é a parte mais
  sensível. `tool/export_onnx.py` falha se `ConvInteger` sobrar no grafo.

- **Weight norm.** A conv posicional do wav2vec2 calcula o peso em runtime, e o
  quantizador do onnxruntime só aceita initializers. Sem remover a
  parametrização antes do export, a quantização morre em `Expected
  .../Mul_output_0 to be an initializer`.
- **Separador de fonemas do espeak.** `--ipa=3` não separa nada apesar do nome;
  o que funciona é `--ipa --sep=_`. Sem isso, cada palavra volta como um
  símbolo só e o GOP é calculado sobre a palavra inteira.
