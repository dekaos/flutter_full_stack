import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

/// One word to learn: what the learner is asked for, in Portuguese, and the
/// English word they hunt for.
@immutable
class WordPair {
  const WordPair(this.pt, this.en);

  /// The prompt, in the learner's own language.
  final String pt;

  /// The answer: the English word on one of the ships.
  final String en;

  @override
  bool operator ==(Object other) =>
      other is WordPair && other.pt == pt && other.en == en;

  @override
  int get hashCode => Object.hash(pt, en);

  @override
  String toString() => '$pt → $en';
}

/// The themes a mission is drawn from, in the order the lobby offers them:
/// the first steps a beginner takes, then everyday life, then further.
///
/// The words were chosen again from scratch rather than carried over from
/// the web version of this game, whose list mixed rare and abstract words
/// ("dishonest", "jealous", "impatient") with basics, repeated one ("happy"
/// twice), offered an insult ("stupid") as vocabulary, and paired words that
/// have several translations - "right" as "direito" when a learner would
/// say "certo", "time" as "tempo" (which is also the weather), "high" as
/// "alto" (which is also "tall" and "loud"). With a word like that on a
/// ship, a learner who knows the language can still be marked wrong.
///
/// So every word here keeps to these rules, and `word_bank_test.dart` holds
/// the ones a machine can check:
///
/// - **Concrete and frequent.** What a beginner meets in the first year (CEFR
///   A1-A2): things that can be pointed at, actions that can be mimed, the
///   phrases said every day.
/// - **One meaning, one answer.** A Portuguese word whose usual translation
///   depends on context is left out, or kept only with every other reading
///   absent from the whole bank: "mulher" is "woman" here, so "wife" is not
///   in it; "dedo" is "finger", so "toe" is not either. No English word is
///   offered twice, and no prompt either, so a ship can never be right for
///   a reason the game does not know about.
/// - **Brazilian usage.** "Tchau", not "adeus"; "ônibus", "celular",
///   "geladeira", "bermuda".
/// - **Something to learn.** No word that is spelled the same in both
///   languages ("animal", "hotel"). Near look-alikes stay, because they are
///   where the learning is: "avó" and "avô", "manhã" and "amanhã",
///   "biblioteca" (library) next to "livraria" (bookstore), "treze" next to
///   "trinta".
/// - **Thematic.** A ship's decoys come from the same theme as the answer,
///   so telling "Tuesday" from "Thursday" is the game - not spotting the one
///   word that is not an animal.
enum WordDeck {
  // ------------------------------------------------------- first steps --
  greetings(1, [
    WordPair('oi', 'hi'),
    WordPair('tchau', 'bye'),
    WordPair('obrigado', 'thank you'),
    WordPair('por favor', 'please'),
    WordPair('desculpa', 'sorry'),
    WordPair('com licença', 'excuse me'),
    WordPair('de nada', "you're welcome"),
    WordPair('bom dia', 'good morning'),
    WordPair('boa tarde', 'good afternoon'),
    WordPair('boa noite', 'good night'),
    WordPair('sim', 'yes'),
    WordPair('não', 'no'),
    WordPair('talvez', 'maybe'),
    WordPair('socorro', 'help'),
    WordPair('parabéns', 'congratulations'),
    WordPair('até logo', 'see you later'),
  ]),
  colors(1, [
    WordPair('vermelho', 'red'),
    WordPair('azul', 'blue'),
    WordPair('verde', 'green'),
    WordPair('amarelo', 'yellow'),
    WordPair('laranja', 'orange'),
    WordPair('roxo', 'purple'),
    WordPair('rosa', 'pink'),
    WordPair('marrom', 'brown'),
    WordPair('preto', 'black'),
    WordPair('branco', 'white'),
    WordPair('cinza', 'gray'),
    WordPair('dourado', 'gold'),
    WordPair('prateado', 'silver'),
    WordPair('azul-claro', 'light blue'),
    WordPair('azul-escuro', 'dark blue'),
  ]),
  numbers(1, [
    WordPair('um', 'one'),
    WordPair('dois', 'two'),
    WordPair('três', 'three'),
    WordPair('quatro', 'four'),
    WordPair('cinco', 'five'),
    WordPair('seis', 'six'),
    WordPair('sete', 'seven'),
    WordPair('oito', 'eight'),
    WordPair('nove', 'nine'),
    WordPair('dez', 'ten'),
    WordPair('onze', 'eleven'),
    WordPair('doze', 'twelve'),
    WordPair('treze', 'thirteen'),
    WordPair('quinze', 'fifteen'),
    WordPair('vinte', 'twenty'),
    WordPair('trinta', 'thirty'),
    WordPair('cem', 'one hundred'),
    WordPair('mil', 'one thousand'),
  ]),
  animals(1, [
    WordPair('cachorro', 'dog'),
    WordPair('gato', 'cat'),
    WordPair('pássaro', 'bird'),
    WordPair('peixe', 'fish'),
    WordPair('cavalo', 'horse'),
    WordPair('vaca', 'cow'),
    WordPair('porco', 'pig'),
    WordPair('galinha', 'chicken'),
    WordPair('ovelha', 'sheep'),
    WordPair('coelho', 'rabbit'),
    WordPair('macaco', 'monkey'),
    WordPair('leão', 'lion'),
    WordPair('urso', 'bear'),
    WordPair('tartaruga', 'turtle'),
    WordPair('abelha', 'bee'),
    WordPair('borboleta', 'butterfly'),
    WordPair('sapo', 'frog'),
    WordPair('pato', 'duck'),
    WordPair('tubarão', 'shark'),
    WordPair('baleia', 'whale'),
    WordPair('cobra', 'snake'),
  ]),
  family(1, [
    WordPair('mãe', 'mother'),
    WordPair('pai', 'father'),
    WordPair('irmão', 'brother'),
    WordPair('irmã', 'sister'),
    WordPair('filho', 'son'),
    WordPair('filha', 'daughter'),
    WordPair('avó', 'grandmother'),
    WordPair('avô', 'grandfather'),
    WordPair('tio', 'uncle'),
    WordPair('tia', 'aunt'),
    WordPair('primo', 'cousin'),
    WordPair('marido', 'husband'),
    WordPair('bebê', 'baby'),
    WordPair('amigo', 'friend'),
    WordPair('vizinho', 'neighbor'),
    WordPair('menino', 'boy'),
    WordPair('menina', 'girl'),
    WordPair('homem', 'man'),
    WordPair('mulher', 'woman'),
  ]),

  // ------------------------------------------------------ everyday life --
  food(2, [
    WordPair('maçã', 'apple'),
    WordPair('pão', 'bread'),
    WordPair('queijo', 'cheese'),
    WordPair('ovo', 'egg'),
    WordPair('leite', 'milk'),
    WordPair('água', 'water'),
    WordPair('suco', 'juice'),
    WordPair('café', 'coffee'),
    WordPair('chá', 'tea'),
    WordPair('arroz', 'rice'),
    WordPair('feijão', 'beans'),
    WordPair('carne', 'meat'),
    WordPair('sopa', 'soup'),
    WordPair('bolo', 'cake'),
    WordPair('açúcar', 'sugar'),
    WordPair('sal', 'salt'),
    WordPair('manteiga', 'butter'),
    WordPair('morango', 'strawberry'),
    WordPair('uva', 'grape'),
    WordPair('cenoura', 'carrot'),
    WordPair('batata', 'potato'),
    WordPair('sorvete', 'ice cream'),
    WordPair('cebola', 'onion'),
    WordPair('melancia', 'watermelon'),
    WordPair('abacaxi', 'pineapple'),
  ]),
  home(2, [
    WordPair('casa', 'house'),
    WordPair('quarto', 'bedroom'),
    WordPair('cozinha', 'kitchen'),
    WordPair('banheiro', 'bathroom'),
    WordPair('sala', 'living room'),
    WordPair('porta', 'door'),
    WordPair('janela', 'window'),
    WordPair('cama', 'bed'),
    WordPair('mesa', 'table'),
    WordPair('cadeira', 'chair'),
    WordPair('geladeira', 'fridge'),
    WordPair('fogão', 'stove'),
    WordPair('espelho', 'mirror'),
    WordPair('chave', 'key'),
    WordPair('escada', 'stairs'),
    WordPair('telhado', 'roof'),
    WordPair('jardim', 'garden'),
    WordPair('travesseiro', 'pillow'),
    WordPair('toalha', 'towel'),
    WordPair('chuveiro', 'shower'),
  ]),
  body(2, [
    WordPair('cabeça', 'head'),
    WordPair('olho', 'eye'),
    WordPair('orelha', 'ear'),
    WordPair('nariz', 'nose'),
    WordPair('boca', 'mouth'),
    WordPair('dente', 'tooth'),
    WordPair('cabelo', 'hair'),
    WordPair('mão', 'hand'),
    WordPair('braço', 'arm'),
    WordPair('perna', 'leg'),
    WordPair('pé', 'foot'),
    WordPair('dedo', 'finger'),
    WordPair('joelho', 'knee'),
    WordPair('ombro', 'shoulder'),
    WordPair('costas', 'back'),
    WordPair('barriga', 'belly'),
    WordPair('coração', 'heart'),
    WordPair('rosto', 'face'),
    WordPair('pescoço', 'neck'),
  ]),
  clothes(2, [
    WordPair('camiseta', 'T-shirt'),
    WordPair('camisa', 'shirt'),
    WordPair('calça', 'pants'),
    WordPair('saia', 'skirt'),
    WordPair('vestido', 'dress'),
    WordPair('sapato', 'shoe'),
    WordPair('tênis', 'sneakers'),
    WordPair('meia', 'sock'),
    WordPair('casaco', 'coat'),
    WordPair('jaqueta', 'jacket'),
    WordPair('chapéu', 'hat'),
    WordPair('boné', 'cap'),
    WordPair('óculos', 'glasses'),
    WordPair('bolsa', 'bag'),
    WordPair('cinto', 'belt'),
    WordPair('luva', 'glove'),
    WordPair('relógio', 'watch'),
    WordPair('cachecol', 'scarf'),
    WordPair('bermuda', 'shorts'),
    WordPair('pijama', 'pajamas'),
  ]),
  time(2, [
    WordPair('segunda-feira', 'Monday'),
    WordPair('terça-feira', 'Tuesday'),
    WordPair('quarta-feira', 'Wednesday'),
    WordPair('quinta-feira', 'Thursday'),
    WordPair('sexta-feira', 'Friday'),
    WordPair('sábado', 'Saturday'),
    WordPair('domingo', 'Sunday'),
    WordPair('hoje', 'today'),
    WordPair('amanhã', 'tomorrow'),
    WordPair('ontem', 'yesterday'),
    WordPair('manhã', 'morning'),
    WordPair('tarde', 'afternoon'),
    WordPair('noite', 'night'),
    WordPair('semana', 'week'),
    WordPair('mês', 'month'),
    WordPair('ano', 'year'),
    WordPair('hora', 'hour'),
    WordPair('minuto', 'minute'),
    WordPair('agora', 'now'),
  ]),

  // ------------------------------------------------------ going further --
  city(3, [
    WordPair('carro', 'car'),
    WordPair('ônibus', 'bus'),
    WordPair('trem', 'train'),
    WordPair('avião', 'plane'),
    WordPair('bicicleta', 'bicycle'),
    WordPair('barco', 'boat'),
    WordPair('rua', 'street'),
    WordPair('ponte', 'bridge'),
    WordPair('escola', 'school'),
    WordPair('mercado', 'market'),
    WordPair('farmácia', 'pharmacy'),
    WordPair('banco', 'bank'),
    WordPair('igreja', 'church'),
    WordPair('loja', 'store'),
    WordPair('biblioteca', 'library'),
    WordPair('livraria', 'bookstore'),
    WordPair('aeroporto', 'airport'),
    WordPair('estação', 'station'),
    WordPair('semáforo', 'traffic light'),
    WordPair('prédio', 'building'),
    WordPair('praça', 'square'),
  ]),
  nature(3, [
    WordPair('sol', 'sun'),
    WordPair('lua', 'moon'),
    WordPair('estrela', 'star'),
    WordPair('céu', 'sky'),
    WordPair('nuvem', 'cloud'),
    WordPair('chuva', 'rain'),
    WordPair('neve', 'snow'),
    WordPair('vento', 'wind'),
    WordPair('mar', 'sea'),
    WordPair('rio', 'river'),
    WordPair('montanha', 'mountain'),
    WordPair('árvore', 'tree'),
    WordPair('flor', 'flower'),
    WordPair('praia', 'beach'),
    WordPair('floresta', 'forest'),
    WordPair('pedra', 'stone'),
    WordPair('ilha', 'island'),
    WordPair('lago', 'lake'),
    WordPair('fogo', 'fire'),
    WordPair('arco-íris', 'rainbow'),
  ]),
  school(3, [
    WordPair('livro', 'book'),
    WordPair('caderno', 'notebook'),
    WordPair('caneta', 'pen'),
    WordPair('lápis', 'pencil'),
    WordPair('borracha', 'eraser'),
    WordPair('mochila', 'backpack'),
    WordPair('professor', 'teacher'),
    WordPair('aluno', 'student'),
    WordPair('sala de aula', 'classroom'),
    WordPair('prova', 'test'),
    WordPair('lição de casa', 'homework'),
    WordPair('computador', 'computer'),
    WordPair('celular', 'phone'),
    WordPair('reunião', 'meeting'),
    WordPair('escritório', 'office'),
    WordPair('chefe', 'boss'),
    WordPair('trabalho', 'work'),
    WordPair('dinheiro', 'money'),
    WordPair('tesoura', 'scissors'),
    WordPair('régua', 'ruler'),
  ]),
  actions(3, [
    WordPair('comer', 'eat'),
    WordPair('beber', 'drink'),
    WordPair('dormir', 'sleep'),
    WordPair('correr', 'run'),
    WordPair('caminhar', 'walk'),
    WordPair('nadar', 'swim'),
    WordPair('ler', 'read'),
    WordPair('escrever', 'write'),
    WordPair('falar', 'speak'),
    WordPair('ouvir', 'listen'),
    WordPair('cantar', 'sing'),
    WordPair('dançar', 'dance'),
    WordPair('cozinhar', 'cook'),
    WordPair('abrir', 'open'),
    WordPair('fechar', 'close'),
    WordPair('comprar', 'buy'),
    WordPair('vender', 'sell'),
    WordPair('pular', 'jump'),
    WordPair('chorar', 'cry'),
    WordPair('rir', 'laugh'),
    WordPair('jogar', 'play'),
    WordPair('aprender', 'learn'),
    WordPair('ensinar', 'teach'),
  ]),
  feelings(3, [
    WordPair('feliz', 'happy'),
    WordPair('triste', 'sad'),
    WordPair('cansado', 'tired'),
    WordPair('com fome', 'hungry'),
    WordPair('com sede', 'thirsty'),
    WordPair('com medo', 'scared'),
    WordPair('com raiva', 'angry'),
    WordPair('grande', 'big'),
    WordPair('pequeno', 'small'),
    WordPair('quente', 'hot'),
    WordPair('frio', 'cold'),
    WordPair('novo', 'new'),
    WordPair('velho', 'old'),
    WordPair('rápido', 'fast'),
    WordPair('lento', 'slow'),
    WordPair('fácil', 'easy'),
    WordPair('difícil', 'difficult'),
    WordPair('barato', 'cheap'),
    WordPair('caro', 'expensive'),
    WordPair('limpo', 'clean'),
    WordPair('sujo', 'dirty'),
    WordPair('cheio', 'full'),
    WordPair('vazio', 'empty'),
    WordPair('bonito', 'beautiful'),
    WordPair('feio', 'ugly'),
  ]);

  WordDeck(this.level, this.words);

  /// `1` first steps, `2` everyday life, `3` going further.
  final int level;

  final List<WordPair> words;

  /// The deck a route names, or `null` for a name that is not one.
  static WordDeck? named(String? name) {
    for (final deck in values) {
      if (deck.name == name) return deck;
    }
    return null;
  }
}

/// How a mission is made up from its deck.
abstract final class MissionPlan {
  /// Words asked for in one mission. Short enough to finish in a couple of
  /// minutes, which is what makes "one more" an easy yes.
  static const words = 10;

  /// How many ships fly in round [number], `1` to [words]: four to start
  /// with, five from the fourth word, six from the eighth - one answer
  /// among more decoys as the learner warms up.
  static int shipsIn(int number) => number < 4
      ? 4
      : number < 8
      ? 5
      : 6;

  /// The words [deck]'s mission asks for, in the order it asks: [count] of
  /// them, never the same one twice.
  ///
  /// (The web version drew each word at random from the whole list, so the
  /// same one could come straight back, and a word could be asked for again
  /// before others had been asked at all.)
  static List<WordPair> targets(
    WordDeck deck,
    math.Random random, {
    int count = words,
  }) => ([...deck.words]..shuffle(random)).take(count).toList();

  /// What flies in a round asking for [target]: it and [decoys] other words
  /// of [deck], in a random order.
  static List<WordPair> choices(
    WordDeck deck,
    WordPair target,
    int decoys,
    math.Random random,
  ) {
    final others = [
      for (final word in deck.words)
        if (word != target) word,
    ]..shuffle(random);
    return [target, ...others.take(decoys)]..shuffle(random);
  }
}
