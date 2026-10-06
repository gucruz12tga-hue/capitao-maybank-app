// ============================================================
//  IA AVANÇADA  (módulo extra do CAPITÃO_MAYBANK)
//  Arquivo: lib/ia_avancada.dart
//
//  O que faz:
//   - Modos de pensamento em várias etapas (planejar, resolver, revisar)
//   - Pesquisa na web, debate, código, verificação de fatos, etc.
//   - Modo Agente: a IA propõe ações no celular e só executa com sua confirmação
//   - Histórico, favoritos, modelos prontos, instruções permanentes
//   - Continuar a conversa sobre a resposta, ouvir em voz alta, anexar arquivos
// ============================================================

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'main.dart';

// ------------------------------------------------------------
//  Modelos de dados
// ------------------------------------------------------------

class IaxPasso {
  final String titulo;
  final String modelo;
  final bool web;
  const IaxPasso(this.titulo, this.modelo, {this.web = false});
}

class IaxModo {
  final String id;
  final String emoji;
  final String nome;
  final String desc;
  final String dica;
  final List<IaxPasso> passos;
  const IaxModo(this.id, this.emoji, this.nome, this.desc, this.dica, this.passos);
}

class IaxModelo {
  final String categoria;
  final String titulo;
  final String texto;
  final String modoId;
  const IaxModelo(this.categoria, this.titulo, this.texto, this.modoId);
}

class IaxResultado {
  final int id;
  final String pergunta;
  final String modoId;
  final List<String> titulos;
  final List<String> saidas;
  final String? erro;
  bool favorito;

  IaxResultado({
    required this.id,
    required this.pergunta,
    required this.modoId,
    required this.titulos,
    required this.saidas,
    this.erro,
    this.favorito = false,
  });

  String get finalTexto => saidas.isEmpty ? '' : saidas.last;

  DateTime get quando => DateTime.fromMillisecondsSinceEpoch(id);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'p': pergunta,
      'm': modoId,
      't': titulos,
      's': saidas,
      'f': favorito,
      'e': erro,
    };
  }

  factory IaxResultado.fromJson(Map<String, dynamic> j) {
    return IaxResultado(
      id: (j['id'] as num).toInt(),
      pergunta: j['p'].toString(),
      modoId: j['m'].toString(),
      titulos: List<String>.from(j['t'] as List),
      saidas: List<String>.from(j['s'] as List),
      favorito: j['f'] == true,
      erro: j['e']?.toString(),
    );
  }
}

class IaxAcao {
  final String titulo;
  final String comando;
  final String motivo;
  const IaxAcao(this.titulo, this.comando, this.motivo);
}

class IaxPlano {
  final String resumo;
  final List<IaxAcao> acoes;
  const IaxPlano(this.resumo, this.acoes);
}

// ------------------------------------------------------------
//  Os modos (cada modo é uma sequência de etapas)
//  Marcadores: {{pergunta}} {{ultima}} {{etapas}} {{tamanho}}
// ------------------------------------------------------------

const List<IaxModo> iaxModos = [
  IaxModo(
    'rapido',
    '⚡',
    'Rápido',
    'Uma única chamada, direta. Gasta pouco do limite grátis.',
    'Pergunte qualquer coisa...',
    [
      IaxPasso('Respondendo', '{{pergunta}}\n\n{{tamanho}}'),
    ],
  ),
  IaxModo(
    'profundo',
    '🧠',
    'Raciocínio profundo',
    'Planeja, resolve passo a passo e depois revisa a própria resposta procurando erros. Ideal para contas, lógica, problemas difíceis e decisões importantes.',
    'Descreva o problema com o máximo de detalhes...',
    [
      IaxPasso(
        'Entendendo e planejando',
        'Pergunta do usuário:\n{{pergunta}}\n\n'
            'Antes de responder, faça o seguinte:\n'
            '1) Reescreva o problema em uma frase.\n'
            '2) Liste o que já se sabe, o que falta saber e as suposições que você está fazendo.\n'
            '3) Divida em subproblemas.\n'
            '4) Liste 2 ou 3 abordagens possíveis e escolha a melhor, explicando por quê.\n'
            'Ainda NÃO dê a resposta final.',
      ),
      IaxPasso(
        'Resolvendo',
        'Pergunta: {{pergunta}}\n\nPlano:\n{{ultima}}\n\n'
            'Resolva seguindo o plano, passo a passo, mostrando o raciocínio e todas as contas. '
            'Aponte claramente onde há incerteza. Não invente dados.',
      ),
      IaxPasso(
        'Revisando e corrigindo',
        'Revise com olhar crítico a solução abaixo. Procure erros de lógica, contas erradas, '
            'informações duvidosas e casos esquecidos. Liste os problemas que encontrou '
            '(ou diga que não encontrou) e depois escreva a RESPOSTA FINAL corrigida, completa e clara, '
            'sem repetir o plano. {{tamanho}}\n\nPergunta: {{pergunta}}\n\nSolução:\n{{ultima}}',
      ),
    ],
  ),
  IaxModo(
    'pesquisa',
    '🌐',
    'Pesquisa na web',
    'Busca informações atuais na internet (Google, pelo Gemini) e depois monta uma resposta com o que é certo e o que é incerto.',
    'O que você quer pesquisar? (notícias, preços, lançamentos, fatos atuais...)',
    [
      IaxPasso(
        'Pesquisando na web',
        'Pesquise na web informações atuais e confiáveis para: {{pergunta}}\n\n'
            'Liste os fatos encontrados com data e nome da fonte sempre que possível. '
            'Diferencie fato confirmado de opinião. Se as fontes discordarem, mostre as duas versões.',
        web: true,
      ),
      IaxPasso(
        'Montando a resposta',
        'Com base nas informações abaixo, escreva a resposta final para: {{pergunta}}\n\n'
            '{{ultima}}\n\n'
            'Seja claro, diga o que é mais certo e o que é incerto e termine com a lista "Fontes" '
            'apenas com o que realmente apareceu acima. Não invente links. {{tamanho}}',
      ),
    ],
  ),
  IaxModo(
    'debate',
    '⚖️',
    'Debate e decisão justa',
    'Dois advogados defendem lados opostos e um juiz imparcial dá o veredito. Bom para dúvidas do tipo "A ou B?".',
    'Qual é a dúvida? Ex.: comprar ou alugar? estudar X ou Y?',
    [
      IaxPasso(
        'Advogado do SIM',
        'Tema: {{pergunta}}\n\nDefenda o lado A (a primeira opção, ou o "sim") com os argumentos mais fortes, '
            'com exemplos e números quando possível. Seja honesto: não use argumentos falsos.',
      ),
      IaxPasso(
        'Advogado do NÃO',
        'Tema: {{pergunta}}\n\nDefenda o lado B (a segunda opção, ou o "não") com os argumentos mais fortes, '
            'rebatendo o que foi dito antes.\n\nArgumentos do lado A:\n{{ultima}}',
      ),
      IaxPasso(
        'Juiz imparcial',
        'Você é um juiz imparcial. Tema: {{pergunta}}\n\nLeia os dois lados:\n{{etapas}}\n\n'
            'Dê: 1) os melhores pontos de cada lado; 2) o que depende da situação da pessoa; '
            '3) o seu veredito, com recomendação clara; 4) o que ela deve verificar antes de decidir. {{tamanho}}',
      ),
    ],
  ),
  IaxModo(
    'codigo',
    '💻',
    'Código extremo',
    'Especifica, escreve o código completo, e depois revisa bugs, segurança e desempenho e escreve testes. Entrega a versão final.',
    'Descreva o que o código deve fazer, ou cole o erro e o código...',
    [
      IaxPasso(
        'Especificação',
        'Pedido: {{pergunta}}\n\nAntes de programar, escreva: requisitos, entradas e saídas, casos de borda, '
            'a linguagem ou framework mais adequado (se o usuário não disse) e a estrutura de arquivos.',
      ),
      IaxPasso(
        'Implementação',
        'Pedido: {{pergunta}}\n\nEspecificação:\n{{ultima}}\n\n'
            'Escreva o código COMPLETO e funcional, comentado em português, sem trechos como "o resto é igual". '
            'Use blocos de código.',
      ),
      IaxPasso(
        'Revisão e testes',
        'Revise o código abaixo como um engenheiro sênior: procure bugs, falhas de segurança, problemas de '
            'desempenho e partes confusas. Escreva testes. Depois entregue a VERSÃO FINAL COMPLETA do código '
            'com as correções, e explique em poucas linhas como rodar.\n\nPedido: {{pergunta}}\n\nCódigo:\n{{ultima}}',
      ),
    ],
  ),
  IaxModo(
    'fatos',
    '🔎',
    'Verificar fatos',
    'Extrai as afirmações de um texto, confere cada uma na web e dá um veredito com uma versão corrigida. Ótimo contra boatos e correntes.',
    'Cole aqui o texto, a notícia ou a mensagem para verificar...',
    [
      IaxPasso(
        'Extraindo afirmações',
        'Leia o texto abaixo e liste, em lista numerada, todas as afirmações que podem ser verificadas '
            '(datas, números, nomes, acontecimentos, promessas). Ignore opiniões.\n\nTexto:\n{{pergunta}}',
        web: true,
      ),
      IaxPasso(
        'Conferindo cada uma',
        'Para cada afirmação abaixo, pesquise e diga: VERDADEIRA, FALSA, PARCIAL ou SEM EVIDÊNCIA, '
            'com uma explicação curta e a fonte quando houver.\n\n{{ultima}}',
        web: true,
      ),
      IaxPasso(
        'Veredito',
        'Com base na checagem abaixo, escreva: 1) um veredito geral; 2) uma nota de confiabilidade de 0 a 10; '
            '3) os sinais de alerta (ex.: urgência, pedido de dinheiro ou de dados, link estranho); '
            '4) uma versão corrigida do texto original. {{tamanho}}\n\nTexto original:\n{{pergunta}}\n\nChecagem:\n{{ultima}}',
      ),
    ],
  ),
  IaxModo(
    'professor',
    '🎓',
    'Professor',
    'Explica em 3 níveis (criança, estudante, especialista) e depois cria exercícios, flashcards e lista de erros comuns.',
    'Qual tema você quer aprender?',
    [
      IaxPasso(
        'Explicação em 3 níveis',
        'Tema: {{pergunta}}\n\nExplique em três níveis, com analogias do dia a dia:\n'
            '1) Para uma criança de 10 anos\n2) Para um estudante do ensino médio\n3) Para um especialista\n'
            'Inclua um exemplo resolvido ou prático no nível 2.',
      ),
      IaxPasso(
        'Praticar',
        'Com base na explicação abaixo sobre "{{pergunta}}", crie: '
            '5 questões de prova (com gabarito comentado no final), 5 flashcards (frente e verso), '
            'os 3 erros mais comuns dos alunos e um mini plano de revisão de 3 dias.\n\n{{ultima}}',
      ),
    ],
  ),
  IaxModo(
    'decisao',
    '🧭',
    'Decisão e plano',
    'Analisa opções, riscos, custos e depois monta um plano de ação de 7 e 30 dias com plano B.',
    'Descreva a situação ou o objetivo...',
    [
      IaxPasso(
        'Análise',
        'Situação ou objetivo: {{pergunta}}\n\nFaça: opções possíveis, critérios para comparar, '
            'prós e contras de cada uma, riscos, custo e tempo estimados. '
            'Diga o que você não sabe e que informação faria diferença.',
      ),
      IaxPasso(
        'Plano de ação',
        'Com base na análise abaixo, entregue: 1) a recomendação e por quê; 2) um plano para os próximos '
            '7 dias, dia a dia; 3) um plano para 30 dias por semana; 4) como medir se está dando certo; '
            '5) o plano B. {{tamanho}}\n\nObjetivo: {{pergunta}}\n\nAnálise:\n{{ultima}}',
      ),
    ],
  ),
  IaxModo(
    'resumo',
    '📄',
    'Documento e resumo',
    'Anexe um PDF, texto ou imagem (ou cole o texto). Extrai os pontos-chave e entrega resumo executivo, glossário e dúvidas em aberto.',
    'O que fazer com o documento? Ex.: resuma, ou cole o texto aqui...',
    [
      IaxPasso(
        'Pontos-chave',
        'Pedido do usuário: {{pergunta}}\n\nLeia o material fornecido e extraia: tema, argumentos ou fatos principais, '
            'números e datas importantes, nomes citados e conclusões. Não invente nada que não esteja no material.',
      ),
      IaxPasso(
        'Resumo final',
        'Com base nos pontos abaixo, escreva: 1) um resumo executivo curto; 2) os pontos principais em tópicos; '
            '3) um pequeno glossário dos termos difíceis; 4) o que o material NÃO responde ou deixa em dúvida; '
            '5) próximos passos sugeridos. {{tamanho}}\n\nPontos:\n{{ultima}}',
      ),
    ],
  ),
  IaxModo(
    'escrita',
    '✍️',
    'Escritor e revisor',
    'Escreve um rascunho, critica o próprio texto e entrega a versão final polida. Serve para e-mails, redações, roteiros e mensagens.',
    'O que escrever? Diga o objetivo, o tom e para quem é...',
    [
      IaxPasso(
        'Rascunho',
        'Pedido: {{pergunta}}\n\nEscreva um primeiro rascunho completo, no tom pedido (se não foi dito, use um tom natural e educado).',
      ),
      IaxPasso(
        'Crítica',
        'Critique o rascunho abaixo como um editor exigente: clareza, tom, erros, repetições, o que falta e o que sobra. '
            'Liste as melhorias em tópicos.\n\nPedido: {{pergunta}}\n\nRascunho:\n{{ultima}}',
      ),
      IaxPasso(
        'Versão final',
        'Reescreva o texto aplicando as melhorias. Entregue SOMENTE a versão final, pronta para copiar e usar. '
            '{{tamanho}}\n\nPedido: {{pergunta}}\n\nMaterial:\n{{etapas}}',
      ),
    ],
  ),
  IaxModo(
    'ideias',
    '💡',
    'Tempestade de ideias',
    'Gera muitas ideias, agrupa, avalia e entrega as 3 melhores com os primeiros passos.',
    'Sobre o que você quer ideias?',
    [
      IaxPasso(
        'Gerando ideias',
        'Tema: {{pergunta}}\n\nGere 20 ideias bem diferentes entre si, de comuns a ousadas. '
            'Uma linha por ideia, numeradas.',
      ),
      IaxPasso(
        'Escolhendo as melhores',
        'Avalie as ideias abaixo por: originalidade, facilidade de fazer, custo (prefira grátis ou barato) e impacto. '
            'Escolha as 3 melhores e, para cada uma, explique por que e dê os 5 primeiros passos práticos. '
            '{{tamanho}}\n\nTema: {{pergunta}}\n\nIdeias:\n{{ultima}}',
      ),
    ],
  ),
  IaxModo(
    'traducao',
    '🌍',
    'Tradução precisa',
    'Traduz, traduz de volta para conferir se o sentido se manteve e entrega a versão final com notas de tom e cultura.',
    'Cole o texto e diga para qual idioma (padrão: inglês)...',
    [
      IaxPasso(
        'Traduzindo',
        'Traduza o pedido abaixo. Se o idioma de destino não foi dito, traduza para inglês. '
            'Se o texto já estiver em outro idioma, traduza para português.\n\n{{pergunta}}',
      ),
      IaxPasso(
        'Conferindo',
        'Traduza de volta para o idioma original o texto abaixo, sem olhar o original, e compare com este original. '
            'Aponte mudanças de sentido, tom ou formalidade. Depois entregue a TRADUÇÃO FINAL, uma pronúncia aproximada '
            'quando útil e notas curtas de tom e cultura.\n\nOriginal:\n{{pergunta}}\n\nTradução:\n{{ultima}}',
      ),
    ],
  ),
  IaxModo(
    'gamer',
    '🎮',
    'Estrategista de jogos',
    'Pesquisa guias atuais e monta um passo a passo para farm, builds, times e chefes. Avisa quando não tem certeza da versão do jogo.',
    'Qual jogo e qual dúvida? Ex.: farmar dinheiro no Pokémon Reborn...',
    [
      IaxPasso(
        'Procurando guias',
        'Pesquise informações atuais e confiáveis sobre: {{pergunta}}\n\n'
            'Liste o que encontrou com a fonte e diga a versão do jogo quando houver. Se não achar, diga que não achou.',
        web: true,
      ),
      IaxPasso(
        'Guia passo a passo',
        'Monte um guia prático e passo a passo para: {{pergunta}}\n\nUse o que foi encontrado:\n{{ultima}}\n\n'
            'Inclua o caminho mais rápido, o que evitar, itens ou níveis recomendados e dicas finais. '
            'Se algo puder variar conforme a versão do jogo, avise. {{tamanho}}',
      ),
    ],
  ),
  IaxModo(
    'agente',
    '🤖',
    'Agente do celular',
    'Transforma o seu pedido em ações do app (tarefa, nota, rota, clima, alarme, timer, abrir app...). Nada é executado sem você tocar em Executar e confirmar.',
    'Ex.: amanhã 7h me acorde, anote que tenho dentista às 15h e mostre a rota para o centro',
    [
      IaxPasso(
        'Montando ações',
        'Você é o módulo agente do app CAPITÃO_MAYBANK. O usuário pediu:\n{{pergunta}}\n\n'
            'Transforme o pedido em uma lista curta (no máximo 8) de ações para o celular, usando SOMENTE estes '
            'formatos de comando, escritos exatamente assim:\n'
            '- nova tarefa TEXTO\n'
            '- anote que TEXTO\n'
            '- lembre que TEXTO\n'
            '- rota para LUGAR\n'
            '- onde fica LUGAR\n'
            '- clima em CIDADE\n'
            '- pesquisar no google ASSUNTO\n'
            '- alarme às HH:MM\n'
            '- timer de N minutos\n'
            '- ligar para NUMERO\n'
            '- que horas são\n'
            '- onde estou\n'
            '- abrir NOME_DO_APP\n\n'
            'Regras: não invente números de telefone nem dados que o usuário não deu; use "ligar para" somente se ele '
            'informou o número. Se o pedido não puder virar essas ações, devolva a lista vazia e explique no resumo.\n\n'
            'Responda SOMENTE com JSON válido, sem nenhum texto antes ou depois, neste formato:\n'
            '{"resumo": "o que você vai fazer, em uma frase", "acoes": [{"titulo": "nome curto", "comando": "comando exato", "motivo": "por que"}]}',
      ),
    ],
  ),
];

IaxModo iaxModoPorId(String id) {
  return iaxModos.firstWhere((m) => m.id == id, orElse: () => iaxModos.first);
}

// ------------------------------------------------------------
//  Modelos prontos (textos para editar e usar)
// ------------------------------------------------------------

const List<IaxModelo> iaxModelos = [
  // ---- Estudos ----
  IaxModelo('Estudos', 'Explicar um tema do zero',
      'Explique [tema] do zero, com analogias do dia a dia e um exemplo resolvido.', 'professor'),
  IaxModelo('Estudos', 'Plano de estudos',
      'Monte um plano de estudos de [matéria] para [prazo], com [horas] horas por dia, com revisões e simulados.', 'decisao'),
  IaxModelo('Estudos', 'Resumo para prova',
      'Resuma o texto abaixo em tópicos e destaque o que mais costuma cair em prova:\n\n[cole o texto]', 'resumo'),
  IaxModelo('Estudos', 'Resolver exercício passo a passo',
      'Resolva passo a passo e explique cada passo:\n\n[cole o exercício]', 'profundo'),
  IaxModelo('Estudos', 'Corrigir redação',
      'Corrija minha redação segundo os critérios do ENEM, dê uma nota para cada competência e reescreva os trechos fracos:\n\n[cole a redação]', 'escrita'),
  IaxModelo('Estudos', 'Praticar um idioma',
      'Crie 20 frases em [idioma] sobre [assunto], com tradução e explicação da gramática de cada uma.', 'rapido'),
  IaxModelo('Estudos', 'Mapa de revisão',
      'Faça um mapa de revisão de [matéria] com os tópicos em ordem de importância, o que decorar e o que entender.', 'professor'),

  // ---- Trabalho ----
  IaxModelo('Trabalho', 'E-mail profissional',
      'Escreva um e-mail profissional para [pessoa/cargo] sobre [assunto]. Tom: [formal/amigável]. Objetivo: [o que você quer].', 'escrita'),
  IaxModelo('Trabalho', 'Ata de reunião',
      'Transforme estas anotações em uma ata de reunião com decisões, responsáveis e prazos:\n\n[cole as anotações]', 'resumo'),
  IaxModelo('Trabalho', 'Fórmula de planilha',
      'Preciso de uma fórmula de Excel e Google Sheets que [objetivo]. As colunas são: [descreva]. Explique como funciona e dê um exemplo.', 'rapido'),
  IaxModelo('Trabalho', 'Roteiro de apresentação',
      'Monte o roteiro de uma apresentação de [tempo] minutos sobre [tema] para [público], com slide a slide.', 'escrita'),
  IaxModelo('Trabalho', 'Responder cliente difícil',
      'Escreva uma resposta calma e profissional para este cliente irritado, resolvendo o problema sem aceitar tudo:\n\n[cole a mensagem]', 'escrita'),
  IaxModelo('Trabalho', 'Melhorar currículo',
      'Melhore meu currículo para a vaga de [cargo]. Destaque resultados e use palavras-chave da vaga.\n\nCurrículo:\n[cole]\n\nVaga:\n[cole]', 'escrita'),
  IaxModelo('Trabalho', 'Planejar um projeto',
      'Planeje o projeto [nome] com etapas, responsáveis, prazos, riscos e o que fazer primeiro. Prazo final: [data].', 'decisao'),

  // ---- Programação ----
  IaxModelo('Programação', 'Tela Flutter completa',
      'Escreva uma tela Flutter completa que [função]. Use apenas pacotes que já estão no projeto e Material 3.', 'codigo'),
  IaxModelo('Programação', 'Corrigir um erro',
      'Meu código dá este erro. Explique a causa e dê o código corrigido.\n\nErro:\n[cole o erro]\n\nCódigo:\n[cole o código]', 'codigo'),
  IaxModelo('Programação', 'Explicar um código',
      'Explique este código linha por linha, em linguagem simples, e diga o que pode dar errado:\n\n[cole o código]', 'professor'),
  IaxModelo('Programação', 'Converter de linguagem',
      'Converta este código de [linguagem A] para [linguagem B], mantendo o comportamento:\n\n[cole o código]', 'codigo'),
  IaxModelo('Programação', 'Consulta SQL',
      'Escreva uma consulta SQL que [objetivo]. Tabelas e colunas: [descreva]. Explique a consulta.', 'codigo'),
  IaxModelo('Programação', 'Revisão de segurança',
      'Faça uma revisão de segurança e qualidade deste código e liste os problemas por gravidade:\n\n[cole o código]', 'codigo'),
  IaxModelo('Programação', 'Script de automação',
      'Escreva um script em Python que automatiza [tarefa]. Diga como instalar e rodar no celular ou no computador.', 'codigo'),

  // ---- Vida pessoal ----
  IaxModelo('Vida pessoal', 'A ou B?',
      'Estou em dúvida entre [opção A] e [opção B]. Minha situação: [descreva]. O que pesa mais para mim: [critérios].', 'debate'),
  IaxModelo('Vida pessoal', 'Organizar a rotina semanal',
      'Organize minha rotina semanal. Compromissos fixos: [liste]. Objetivos: [liste]. Horário que acordo e durmo: [horários].', 'decisao'),
  IaxModelo('Vida pessoal', 'Roteiro de viagem',
      'Monte um roteiro de [N] dias em [destino] com orçamento de [valor], com custos estimados e dicas de economia.', 'pesquisa'),
  IaxModelo('Vida pessoal', 'Cardápio barato',
      'Monte um cardápio da semana barato e simples usando principalmente [ingredientes]. Inclua lista de compras.', 'rapido'),
  IaxModelo('Vida pessoal', 'Mensagem difícil',
      'Me ajude a escrever uma mensagem para [pessoa] sobre [situação], com respeito e clareza. Objetivo: [o que quero].', 'escrita'),
  IaxModelo('Vida pessoal', 'Transformar meta em plano',
      'Transforme esta meta em um plano realista com passos pequenos: [meta]. Tempo disponível por dia: [tempo].', 'decisao'),

  // ---- Dinheiro ----
  IaxModelo('Dinheiro', 'Orçamento mensal',
      'Monte um orçamento mensal para renda de [valor] com gastos fixos de [lista]. Sugira onde cortar. (Quero informação geral, não aconselhamento financeiro.)', 'decisao'),
  IaxModelo('Dinheiro', 'Plano para sair das dívidas',
      'Crie um plano para quitar estas dívidas, explicando as estratégias possíveis e seus prós e contras:\n[liste valor, juros e prazo]', 'decisao'),
  IaxModelo('Dinheiro', 'Comparar produtos',
      'Compare [produto A] e [produto B] para o meu uso: [descreva]. Pesquise preços e avaliações atuais.', 'pesquisa'),
  IaxModelo('Dinheiro', 'Isto é golpe?',
      'Veja se isto é golpe e o que devo fazer:\n\n[cole a mensagem, o link ou a proposta]', 'fatos'),

  // ---- Jogos ----
  IaxModelo('Jogos', 'Farm no Pokémon Reborn',
      'No Pokémon Reborn, qual é a melhor forma de farmar [nível / dinheiro / um Pokémon específico]? Quero o passo a passo.', 'gamer'),
  IaxModelo('Jogos', 'Montar um time',
      'Monte um time para [jogo] focado em [objetivo], com função de cada integrante e como jogar com ele.', 'gamer'),
  IaxModelo('Jogos', 'Vencer um chefe',
      'Como vencer [chefe] em [jogo]? Meu time ou build atual é: [descreva].', 'gamer'),
  IaxModelo('Jogos', 'Mestre de RPG de texto',
      'Seja o mestre de um RPG de texto de [tema]. Eu sou [personagem]. Descreva a cena inicial e me dê 3 opções de ação.', 'rapido'),
  IaxModelo('Jogos', 'Ideias de jogo',
      'Me dê ideias de um jogo simples de [gênero] que eu possa criar sozinho, grátis e pelo celular.', 'ideias'),

  // ---- Criatividade ----
  IaxModelo('Criatividade', 'Nomes para projeto',
      'Dê ideias de nomes para [projeto/canal/marca], curtos, fáceis de falar e sem parecer com marcas famosas.', 'ideias'),
  IaxModelo('Criatividade', 'Roteiro de vídeo',
      'Escreva um roteiro de vídeo de [duração] sobre [tema], com gancho nos 5 primeiros segundos, cenas e legenda.', 'escrita'),
  IaxModelo('Criatividade', 'História curta',
      'Escreva uma história curta de [gênero] com [personagem] e um final inesperado. Tamanho: [palavras] palavras.', 'escrita'),
  IaxModelo('Criatividade', 'Ideias de renda grátis',
      'Dê ideias de como ganhar dinheiro com [habilidade], começando de graça e só com o celular, com os primeiros passos.', 'ideias'),
  IaxModelo('Criatividade', 'Legenda e hashtags',
      'Crie 5 legendas e hashtags para um post sobre [assunto], em tom [divertido/profissional].', 'rapido'),

  // ---- Verificar ----
  IaxModelo('Verificar', 'Isto é verdade?',
      'Isto é verdade? Confira nas fontes mais atuais:\n\n[cole a afirmação ou o boato]', 'fatos'),
  IaxModelo('Verificar', 'Checar notícia',
      'Confira esta notícia: o que é fato, o que é opinião e o que não tem evidência:\n\n[cole a notícia]', 'fatos'),
  IaxModelo('Verificar', 'Últimas notícias de um tema',
      'Quais são as notícias mais recentes sobre [tema]? Resuma o que se sabe e o que ainda é incerto.', 'pesquisa'),

  // ---- Celular (agente) ----
  IaxModelo('Celular', 'Organizar minha manhã',
      'Amanhã às 7h me acorde, anote que tenho [compromisso] às [hora] e mostre a rota para [lugar].', 'agente'),
  IaxModelo('Celular', 'Preparar saída',
      'Vou sair agora: veja o clima em [cidade], me avise em 30 minutos e abra a rota para [lugar].', 'agente'),
  IaxModelo('Celular', 'Tarefas do dia',
      'Crie as tarefas de hoje: [tarefa 1], [tarefa 2] e [tarefa 3]. Depois me avise com um timer de 25 minutos para começar.', 'agente'),
];

// ------------------------------------------------------------
//  Utilidades de texto
// ------------------------------------------------------------

String iaxTextoTamanho(String t) {
  switch (t) {
    case 'curta':
      return 'Responda de forma curta e direta (até 8 linhas).';
    case 'longa':
      return 'Responda de forma completa e detalhada, com exemplos.';
  }
  return 'Responda com tamanho médio, claro e organizado.';
}

const List<String> iaxTamanhos = ['curta', 'média', 'longa'];

String iaxDataTexto(DateTime d) {
  return '${dois(d.day)}/${dois(d.month)}/${d.year} ${dois(d.hour)}:${dois(d.minute)}';
}

String iaxLimparMarkdown(String t) {
  return t.replaceAll(RegExp(r'[*#`_>]'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

// ------------------------------------------------------------
//  Armazenamento do histórico (no próprio celular)
// ------------------------------------------------------------

class IaxArmazem {
  static const String chave = 'iax_hist';
  static const int maximo = 80;

  static List<IaxResultado> ler() {
    final out = <IaxResultado>[];
    try {
      for (final s in cfg.lista(chave)) {
        try {
          out.add(IaxResultado.fromJson(jsonDecode(s) as Map<String, dynamic>));
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  static Future<void> gravar(List<IaxResultado> lista) async {
    final l = List<IaxResultado>.from(lista);
    while (l.length > maximo) {
      final i = l.lastIndexWhere((r) => !r.favorito);
      if (i < 0) break;
      l.removeAt(i);
    }
    final textos = l.map((r) => jsonEncode(r.toJson())).toList();
    await cfg.setLista(chave, textos);
  }

  static Future<void> adicionar(IaxResultado r) async {
    final l = ler();
    l.insert(0, r);
    await gravar(l);
  }

  static Future<void> atualizar(IaxResultado r) async {
    final l = ler();
    final i = l.indexWhere((x) => x.id == r.id);
    if (i < 0) return;
    l[i] = r;
    await gravar(l);
  }

  static Future<void> apagar(int id) async {
    final l = ler();
    l.removeWhere((x) => x.id == id);
    await gravar(l);
  }

  static Future<void> limparSemFavoritos() async {
    final l = ler();
    l.removeWhere((x) => !x.favorito);
    await gravar(l);
  }
}

// ------------------------------------------------------------
//  Motor: roda as etapas de um modo, uma depois da outra
// ------------------------------------------------------------

class IaxMotor {
  static bool cancelar = false;

  static String instrucoesPermanentes() {
    try {
      return cfg.p.getString('iax_instr') ?? '';
    } catch (_) {
      return '';
    }
  }

  static String extraBase(String tamanho) {
    final b = StringBuffer();
    b.writeln('MODO IA AVANÇADA ativo. Pense com rigor e organize bem a resposta.');
    b.writeln(
        'Seja honesto sobre incertezas. Nunca invente fatos, números, links, fontes ou citações.');
    b.writeln(iaxTextoTamanho(tamanho));
    final instr = instrucoesPermanentes();
    if (instr.isNotEmpty) {
      b.writeln('Instruções permanentes do usuário: $instr');
    }
    return b.toString();
  }

  static String _montar(String modelo, String pergunta, List<String> titulos,
      List<String> saidas, String tamanho) {
    final b = StringBuffer();
    for (var i = 0; i < saidas.length; i++) {
      b.writeln('### ${titulos[i]}');
      b.writeln(saidas[i]);
      b.writeln();
    }
    final etapas = b.toString().trim();
    final ultima = saidas.isEmpty ? '' : saidas.last;
    return modelo
        .replaceAll('{{pergunta}}', pergunta)
        .replaceAll('{{etapas}}', etapas)
        .replaceAll('{{ultima}}', ultima)
        .replaceAll('{{tamanho}}', iaxTextoTamanho(tamanho));
  }

  static Future<IaxResultado> rodar({
    required IaxModo modo,
    required String pergunta,
    required String tamanho,
    required bool web,
    Anexo? anexo,
    void Function(int, int, String)? progresso,
  }) async {
    cancelar = false;
    final titulos = <String>[];
    final saidas = <String>[];
    String? erro;
    final id = DateTime.now().millisecondsSinceEpoch;
    final total = modo.passos.length;

    for (var i = 0; i < total; i++) {
      if (cancelar) {
        erro = 'Cancelado por você.';
        break;
      }
      final passo = modo.passos[i];
      progresso?.call(i + 1, total, passo.titulo);
      final prompt = _montar(passo.modelo, pergunta, titulos, saidas, tamanho);
      final usarWeb = web && passo.web;

      IaResp r = await Ia.perguntar(
        texto: prompt,
        anexo: anexo,
        extra: extraBase(tamanho),
        web: usarWeb,
      );

      if (!r.ok && r.texto.contains('limite')) {
        for (var s = 25; s > 0 && !cancelar; s--) {
          progresso?.call(i + 1, total,
              '${passo.titulo} (limite grátis; tentando de novo em ${s}s)');
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (!cancelar) {
          r = await Ia.perguntar(
            texto: prompt,
            anexo: anexo,
            extra: extraBase(tamanho),
            web: usarWeb,
          );
        }
      }

      if (!r.ok) {
        erro = r.texto;
        break;
      }
      titulos.add(passo.titulo);
      saidas.add(r.texto);
    }

    return IaxResultado(
      id: id,
      pergunta: pergunta,
      modoId: modo.id,
      titulos: titulos,
      saidas: saidas,
      erro: erro,
    );
  }

  // Lê o JSON do modo Agente
  static IaxPlano? lerPlano(String texto) {
    try {
      final i = texto.indexOf('{');
      final f = texto.lastIndexOf('}');
      if (i < 0 || f <= i) return null;
      final j = jsonDecode(texto.substring(i, f + 1));
      if (j is! Map) return null;
      final acoes = <IaxAcao>[];
      final lista = j['acoes'];
      if (lista is List) {
        for (final a in lista) {
          if (a is Map) {
            final c = (a['comando'] ?? '').toString().trim();
            if (c.isEmpty) continue;
            final t = (a['titulo'] ?? c).toString();
            final m = (a['motivo'] ?? '').toString();
            acoes.add(IaxAcao(t, c, m));
          }
        }
      }
      return IaxPlano((j['resumo'] ?? '').toString(), acoes);
    } catch (_) {
      return null;
    }
  }
}

// ------------------------------------------------------------
//  Tela principal: IA Avançada
// ------------------------------------------------------------

class IaAvancadaPage extends StatefulWidget {
  const IaAvancadaPage({super.key});

  @override
  State<IaAvancadaPage> createState() => _IaAvancadaPageState();
}

class _IaAvancadaPageState extends State<IaAvancadaPage> {
  final TextEditingController _perg = TextEditingController();
  final TextEditingController _seg = TextEditingController();
  final ScrollController _rolagem = ScrollController();

  IaxModo _modo = iaxModos.first;
  String _tam = 'média';
  bool _web = true;
  bool _rodando = false;
  int _etapa = 0;
  int _total = 0;
  String _msg = '';
  IaxResultado? _res;
  Anexo? _anexo;

  final List<Map<String, dynamic>> _conversa = <Map<String, dynamic>>[];
  bool _segRodando = false;
  String _erroSeg = '';

  @override
  void initState() {
    super.initState();
    try {
      _modo = iaxModoPorId(cfg.p.getString('iax_modo') ?? 'rapido');
      _tam = cfg.p.getString('iax_tam') ?? 'média';
      if (!iaxTamanhos.contains(_tam)) _tam = 'média';
    } catch (_) {}
  }

  @override
  void dispose() {
    IaxMotor.cancelar = true;
    _perg.dispose();
    _seg.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  // ---------- ações ----------

  Future<void> _anexar() async {
    try {
      const grupo = XTypeGroup(label: 'arquivos', extensions: <String>[
        'pdf',
        'txt',
        'md',
        'csv',
        'json',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'mp3',
        'wav',
        'm4a',
        'mp4',
      ]);
      final f = await openFile(acceptedTypeGroups: <XTypeGroup>[grupo]);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 14 * 1024 * 1024) {
        if (mounted) aviso(context, 'Arquivo grande demais (máximo 14 MB).');
        return;
      }
      final mime = mimePorNome(f.name);
      if (mime == 'application/octet-stream') {
        if (mounted) aviso(context, 'Esse tipo de arquivo não é suportado.');
        return;
      }
      if (!mounted) return;
      setState(() => _anexo = Anexo(f.name, mime, bytes));
    } catch (_) {
      if (mounted) aviso(context, 'Não consegui abrir o arquivo.');
    }
  }

  Future<void> _executar() async {
    final texto = _perg.text.trim();
    if (texto.isEmpty && _anexo == null) {
      aviso(context, 'Escreva a pergunta ou anexe um arquivo.');
      return;
    }
    if (cfg.apiKey.isEmpty) {
      aviso(context, 'Falta a chave do Gemini. Vá na aba Config.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _rodando = true;
      _res = null;
      _conversa.clear();
      _erroSeg = '';
      _etapa = 0;
      _total = _modo.passos.length;
      _msg = 'Começando...';
    });

    final pergunta = texto.isEmpty ? 'Analise o arquivo anexado.' : texto;
    final r = await IaxMotor.rodar(
      modo: _modo,
      pergunta: pergunta,
      tamanho: _tam,
      web: _web && cfg.permWeb,
      anexo: _anexo,
      progresso: (i, n, t) {
        if (!mounted) return;
        setState(() {
          _etapa = i;
          _total = n;
          _msg = t;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _rodando = false;
      _res = r;
    });
    if (r.saidas.isNotEmpty) {
      _conversa.add(<String, dynamic>{
        'role': 'user',
        'parts': <Map<String, String>>[
          {'text': r.pergunta}
        ],
      });
      _conversa.add(<String, dynamic>{
        'role': 'model',
        'parts': <Map<String, String>>[
          {'text': r.finalTexto}
        ],
      });
      await IaxArmazem.adicionar(r);
    }
    _descer();
  }

  void _descer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rolagem.hasClients) return;
      _rolagem.animateTo(
        _rolagem.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _continuar() async {
    final t = _seg.text.trim();
    if (t.isEmpty || _segRodando || _res == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _segRodando = true;
      _erroSeg = '';
    });
    final r = await Ia.perguntar(
      texto: t,
      historico: List<Map<String, dynamic>>.from(_conversa),
      extra: IaxMotor.extraBase(_tam),
      web: _web && cfg.permWeb,
    );
    if (!mounted) return;
    setState(() {
      _segRodando = false;
      if (r.ok) {
        _conversa.add(<String, dynamic>{
          'role': 'user',
          'parts': <Map<String, String>>[
            {'text': t}
          ],
        });
        _conversa.add(<String, dynamic>{
          'role': 'model',
          'parts': <Map<String, String>>[
            {'text': r.texto}
          ],
        });
        _seg.clear();
      } else {
        _erroSeg = r.texto;
      }
    });
    _descer();
  }

  Future<void> _abrirModelos() async {
    final m = await Navigator.of(context).push<IaxModelo>(
      MaterialPageRoute<IaxModelo>(builder: (_) => const IaxModelosPage()),
    );
    if (m == null || !mounted) return;
    setState(() {
      _perg.text = m.texto;
      _perg.selection = TextSelection.collapsed(offset: m.texto.length);
      if (m.modoId.isNotEmpty) {
        _modo = iaxModoPorId(m.modoId);
        cfg.p.setString('iax_modo', _modo.id);
      }
    });
  }

  Future<void> _editarInstrucoes() async {
    final ctrl = TextEditingController(text: IaxMotor.instrucoesPermanentes());
    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: P.mar,
        title: const Text('Instruções permanentes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Valem para todos os modos da IA Avançada. Ex.: "explique sempre com exemplos práticos" ou "trate-me por Capitão".',
                  style: TextStyle(color: P.claro.withOpacity(0.8), fontSize: 13)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                minLines: 3,
                maxLines: 8,
                decoration: campo('Suas instruções...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (salvar == true) {
      await cfg.p.setString('iax_instr', ctrl.text.trim());
      if (mounted) aviso(context, 'Instruções salvas');
    }
  }

  void _ajuda() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: P.mar,
        title: const Text('Como funciona'),
        content: SingleChildScrollView(
          child: Text(
              'Cada modo faz várias perguntas seguidas ao Gemini: uma etapa alimenta a próxima. '
              'Por isso a resposta final costuma ser mais cuidadosa que a do chat comum.\n\n'
              '• Modos com várias etapas gastam mais do limite grátis. Se o limite estourar, o app espera e tenta de novo sozinho.\n'
              '• Você pode ver todas as etapas tocando em "Etapas do raciocínio".\n'
              '• A IA pode errar. Em assuntos importantes (saúde, dinheiro, leis), confira em fontes oficiais.\n'
              '• No modo Agente, nada é executado sem você tocar em Executar e confirmar.\n'
              '• O histórico fica só no seu celular (últimos 80; os favoritos ficam).',
              style: TextStyle(color: P.claro, height: 1.4)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Entendi')),
        ],
      ),
    );
  }

  // ---------- blocos da tela ----------

  Widget _blocoModo() {
    return caixa(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titulo2('Modo de pensamento'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in iaxModos)
              ChoiceChip(
                label: Text('${m.emoji} ${m.nome}'),
                selected: m.id == _modo.id,
                selectedColor: P.destaque,
                backgroundColor: P.noite.withOpacity(0.5),
                labelStyle: TextStyle(
                    color: m.id == _modo.id ? P.noite : P.claro, fontSize: 13),
                onSelected: _rodando
                    ? null
                    : (_) {
                        setState(() => _modo = m);
                        cfg.p.setString('iax_modo', m.id);
                      },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(_modo.desc,
            style: TextStyle(color: P.claro.withOpacity(0.85), height: 1.35)),
        const SizedBox(height: 4),
        Text(
            _modo.passos.length == 1
                ? '1 chamada ao Gemini'
                : '${_modo.passos.length} etapas (${_modo.passos.length} chamadas ao Gemini)',
            style: TextStyle(color: P.destaque, fontSize: 12)),
      ],
    ));
  }

  Widget _blocoPergunta() {
    return caixa(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _perg,
          enabled: !_rodando,
          minLines: 4,
          maxLines: 12,
          decoration: campo(_modo.dica),
        ),
        const SizedBox(height: 8),
        if (_anexo != null)
          Row(
            children: [
              Icon(Icons.attach_file, color: P.destaque, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_anexo!.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: P.claro)),
              ),
              IconButton(
                tooltip: 'Remover anexo',
                icon: Icon(Icons.close, color: P.alerta),
                onPressed: _rodando ? null : () => setState(() => _anexo = null),
              ),
            ],
          ),
        Text('Tamanho da resposta',
            style: TextStyle(color: P.claro.withOpacity(0.7), fontSize: 12)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final t in iaxTamanhos)
              ChoiceChip(
                label: Text(t),
                selected: _tam == t,
                selectedColor: P.destaque,
                backgroundColor: P.noite.withOpacity(0.5),
                labelStyle: TextStyle(color: _tam == t ? P.noite : P.claro),
                onSelected: _rodando
                    ? null
                    : (_) {
                        setState(() => _tam = t);
                        cfg.p.setString('iax_tam', t);
                      },
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
              cfg.permWeb
                  ? 'Usar pesquisa na web quando o modo precisar'
                  : 'Web desligada em Config > Permissões',
              style: TextStyle(color: P.claro, fontSize: 14)),
          value: _web && cfg.permWeb,
          onChanged: (cfg.permWeb && !_rodando)
              ? (v) => setState(() => _web = v)
              : null,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            botao(_rodando ? 'Pensando...' : 'Executar ${_modo.emoji}',
                _rodando ? null : _executar),
            OutlinedButton.icon(
              onPressed: _rodando ? null : _anexar,
              icon: const Icon(Icons.attach_file),
              label: const Text('Anexar'),
            ),
            if (_rodando)
              OutlinedButton.icon(
                onPressed: () {
                  IaxMotor.cancelar = true;
                  setState(() => _msg = 'Cancelando...');
                },
                icon: const Icon(Icons.stop),
                label: const Text('Cancelar'),
              ),
          ],
        ),
      ],
    ));
  }

  Widget _blocoProgresso() {
    return caixa(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Etapa $_etapa de $_total',
            style: TextStyle(
                color: P.claro, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 6),
        Text(_msg, style: TextStyle(color: P.claro.withOpacity(0.85))),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: (_total == 0 || _etapa <= 1) ? null : (_etapa - 1) / _total,
          color: P.destaque,
          backgroundColor: P.noite,
        ),
      ],
    ));
  }

  String _textoDaConversa(int i) {
    try {
      final partes = _conversa[i]['parts'] as List;
      return (partes[0] as Map)['text'].toString();
    } catch (_) {
      return '';
    }
  }

  Widget _blocoSeguimento() {
    final itens = <Widget>[];
    for (var i = 2; i + 1 < _conversa.length; i += 2) {
      itens.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: P.destaque.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_textoDaConversa(i), style: TextStyle(color: P.claro)),
      ));
      itens.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: P.noite.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(_textoDaConversa(i + 1),
            style: TextStyle(color: P.claro, height: 1.4)),
      ));
    }
    return caixa(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titulo2('Continuar a conversa'),
        ...itens,
        TextField(
          controller: _seg,
          minLines: 1,
          maxLines: 5,
          decoration: campo('Pergunte algo sobre essa resposta...'),
        ),
        const SizedBox(height: 8),
        botao(_segRodando ? 'Pensando...' : 'Enviar',
            _segRodando ? null : _continuar),
        if (_erroSeg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_erroSeg, style: TextStyle(color: P.alerta)),
          ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _res;
    return telaPadrao(
      'IA Avançada',
      ListView(
        controller: _rolagem,
        padding: const EdgeInsets.all(12),
        children: [
          _blocoModo(),
          _blocoPergunta(),
          if (_rodando) _blocoProgresso(),
          if (r != null)
            IaxResultadoView(key: ValueKey<int>(r.id), r: r),
          if (r != null && r.saidas.isNotEmpty) _blocoSeguimento(),
          const SizedBox(height: 24),
        ],
      ),
      acoes: [
        IconButton(
          tooltip: 'Modelos prontos',
          icon: const Icon(Icons.lightbulb_outline),
          onPressed: _rodando ? null : _abrirModelos,
        ),
        IconButton(
          tooltip: 'Instruções permanentes',
          icon: const Icon(Icons.tune),
          onPressed: _editarInstrucoes,
        ),
        IconButton(
          tooltip: 'Histórico',
          icon: const Icon(Icons.history),
          onPressed: () => abrirPagina(context, const IaxHistoricoPage()),
        ),
        IconButton(
          tooltip: 'Ajuda',
          icon: const Icon(Icons.help_outline),
          onPressed: _ajuda,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
//  Exibição de um resultado (usada na tela principal e no histórico)
// ------------------------------------------------------------

class IaxResultadoView extends StatefulWidget {
  final IaxResultado r;
  const IaxResultadoView({super.key, required this.r});

  @override
  State<IaxResultadoView> createState() => _IaxResultadoViewState();
}

class _IaxResultadoViewState extends State<IaxResultadoView> {
  final FlutterTts _tts = FlutterTts();
  bool _falando = false;

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _voz() async {
    try {
      if (_falando) {
        await _tts.stop();
        if (mounted) setState(() => _falando = false);
        return;
      }
      await _tts.setLanguage('pt-BR');
      await _tts.setPitch(cfg.tom);
      await _tts.setSpeechRate(cfg.velocidade);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _falando = false);
      });
      if (mounted) setState(() => _falando = true);
      await _tts.speak(iaxLimparMarkdown(widget.r.finalTexto));
    } catch (_) {
      if (mounted) setState(() => _falando = false);
    }
  }

  Future<void> _favoritar() async {
    widget.r.favorito = !widget.r.favorito;
    await IaxArmazem.atualizar(widget.r);
    if (mounted) setState(() {});
  }

  String _tudo() {
    final r = widget.r;
    final b = StringBuffer();
    b.writeln('Pergunta: ${r.pergunta}');
    b.writeln();
    for (var i = 0; i < r.saidas.length; i++) {
      b.writeln('## ${r.titulos[i]}');
      b.writeln(r.saidas[i]);
      b.writeln();
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final modo = iaxModoPorId(r.modoId);
    final plano = r.modoId == 'agente' ? IaxMotor.lerPlano(r.finalTexto) : null;
    final intermediarias = r.saidas.length > 1 ? r.saidas.length - 1 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        caixa(Row(
          children: [
            Text(modo.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(modo.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: P.claro, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            if (r.saidas.isNotEmpty) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copiar resposta',
                icon: Icon(Icons.copy, color: P.destaque),
                onPressed: () => copiarTexto(context, r.finalTexto),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copiar tudo',
                icon: Icon(Icons.copy_all, color: P.destaque),
                onPressed: () => copiarTexto(context, _tudo()),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _falando ? 'Parar' : 'Ouvir',
                icon: Icon(_falando ? Icons.stop_circle_outlined : Icons.volume_up,
                    color: P.destaque),
                onPressed: _voz,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Favoritar',
                icon: Icon(r.favorito ? Icons.star : Icons.star_border,
                    color: P.quente),
                onPressed: _favoritar,
              ),
            ],
          ],
        )),
        if (r.saidas.isNotEmpty)
          (plano != null
              ? IaxAgenteView(plano: plano)
              : resultadoBox(r.finalTexto)),
        if (r.erro != null)
          caixa(Text('⚠️ ${r.erro}', style: TextStyle(color: P.alerta, height: 1.4))),
        if (intermediarias > 0)
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Etapas do raciocínio'),
              for (var i = 0; i < intermediarias; i++)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    iconColor: P.destaque,
                    collapsedIconColor: P.destaque,
                    title: Text('${i + 1}. ${r.titulos[i]}',
                        style: TextStyle(color: P.claro, fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SelectableText(r.saidas[i],
                            style: TextStyle(
                                color: P.claro.withOpacity(0.85), height: 1.4)),
                      ),
                    ],
                  ),
                ),
            ],
          )),
      ],
    );
  }
}

// ------------------------------------------------------------
//  Modo Agente: cartões de ação com confirmação
// ------------------------------------------------------------

class IaxAgenteView extends StatelessWidget {
  final IaxPlano plano;
  const IaxAgenteView({super.key, required this.plano});

  Future<void> _um(BuildContext c, IaxAcao a) async {
    final ok = await confirmarDialogo(
        c, 'Executar este comando agora?\n\n${a.comando}');
    if (!c.mounted) return;
    if (ok) chatComando(c, enviar: a.comando);
  }

  Future<void> _todas(BuildContext c) async {
    final b = StringBuffer('Executar estes comandos, um depois do outro?\n');
    for (final a in plano.acoes) {
      b.writeln('\n• ${a.comando}');
    }
    final ok = await confirmarDialogo(c, b.toString());
    if (!c.mounted) return;
    if (ok) {
      chatComando(c, varios: plano.acoes.map((a) => a.comando).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plano.resumo.isNotEmpty) resultadoBox(plano.resumo),
        if (plano.acoes.isEmpty)
          caixa(Text('Nenhuma ação automática possível para esse pedido.',
              style: TextStyle(color: P.claro))),
        for (final a in plano.acoes)
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.titulo,
                  style: TextStyle(
                      color: P.claro, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text(a.comando,
                  style: TextStyle(
                      color: P.destaque, fontFamily: 'monospace', fontSize: 13)),
              if (a.motivo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(a.motivo,
                      style: TextStyle(color: P.claro.withOpacity(0.75))),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: botao('Executar', () => _um(context, a)),
              ),
            ],
          )),
        if (plano.acoes.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: botao('Executar todas (${plano.acoes.length})',
                () => _todas(context)),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------
//  Tela: modelos prontos
// ------------------------------------------------------------

class IaxModelosPage extends StatefulWidget {
  const IaxModelosPage({super.key});

  @override
  State<IaxModelosPage> createState() => _IaxModelosPageState();
}

class _IaxModelosPageState extends State<IaxModelosPage> {
  final TextEditingController _busca = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  bool _combina(IaxModelo m) {
    if (_filtro.isEmpty) return true;
    final alvo = semAcento('${m.categoria} ${m.titulo} ${m.texto}'.toLowerCase());
    return alvo.contains(semAcento(_filtro.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final categorias = <String>[];
    for (final m in iaxModelos) {
      if (!categorias.contains(m.categoria)) categorias.add(m.categoria);
    }
    final blocos = <Widget>[
      TextField(
        controller: _busca,
        onChanged: (v) => setState(() => _filtro = v.trim()),
        decoration: campo('Buscar modelo...'),
      ),
      const SizedBox(height: 8),
      Text('Toque em um modelo para levar o texto para a IA Avançada. Troque o que está entre [colchetes].',
          style: TextStyle(color: P.claro.withOpacity(0.7), fontSize: 12)),
      const SizedBox(height: 6),
    ];
    var achou = false;
    for (final cat in categorias) {
      final lista = iaxModelos.where((m) => m.categoria == cat && _combina(m)).toList();
      if (lista.isEmpty) continue;
      achou = true;
      blocos.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(cat,
            style: TextStyle(
                color: P.destaque, fontWeight: FontWeight.w800, fontSize: 15)),
      ));
      for (final m in lista) {
        final modo = iaxModoPorId(m.modoId);
        blocos.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: P.mar,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            title: Text(m.titulo,
                style: TextStyle(color: P.claro, fontWeight: FontWeight.w600)),
            subtitle: Text(m.texto,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: P.claro.withOpacity(0.65), fontSize: 12)),
            trailing: Text(modo.emoji, style: const TextStyle(fontSize: 20)),
            onTap: () => Navigator.of(context).pop(m),
          ),
        ));
      }
    }
    if (!achou) {
      blocos.add(Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('Nenhum modelo encontrado.',
              style: TextStyle(color: P.claro.withOpacity(0.7))),
        ),
      ));
    }
    return telaPadrao(
      'Modelos prontos (${iaxModelos.length})',
      ListView(padding: const EdgeInsets.all(12), children: blocos),
    );
  }
}

// ------------------------------------------------------------
//  Tela: histórico
// ------------------------------------------------------------

class IaxHistoricoPage extends StatefulWidget {
  const IaxHistoricoPage({super.key});

  @override
  State<IaxHistoricoPage> createState() => _IaxHistoricoPageState();
}

class _IaxHistoricoPageState extends State<IaxHistoricoPage> {
  final TextEditingController _busca = TextEditingController();
  String _filtro = '';
  bool _soFavoritos = false;
  List<IaxResultado> _lista = <IaxResultado>[];

  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  void _recarregar() {
    setState(() => _lista = IaxArmazem.ler());
  }

  Future<void> _limpar() async {
    final ok = await confirmarDialogo(
        context, 'Apagar todo o histórico? Os favoritos ficam.');
    if (!ok) return;
    await IaxArmazem.limparSemFavoritos();
    if (mounted) _recarregar();
  }

  Future<void> _apagarUm(IaxResultado r) async {
    final ok = await confirmarDialogo(context, 'Apagar esta resposta salva?');
    if (!ok) return;
    await IaxArmazem.apagar(r.id);
    if (mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final f = semAcento(_filtro.toLowerCase());
    final visiveis = _lista.where((r) {
      if (_soFavoritos && !r.favorito) return false;
      if (f.isEmpty) return true;
      final alvo = semAcento('${r.pergunta} ${r.finalTexto}'.toLowerCase());
      return alvo.contains(f);
    }).toList();
    final favs = _lista.where((r) => r.favorito).length;

    return telaPadrao(
      'Histórico',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _busca,
            onChanged: (v) => setState(() => _filtro = v.trim()),
            decoration: campo('Buscar no histórico...'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Só favoritos',
                style: TextStyle(color: P.claro, fontSize: 14)),
            value: _soFavoritos,
            onChanged: (v) => setState(() => _soFavoritos = v),
          ),
          Text('${_lista.length} salvas · $favs favoritas · toque e segure para apagar',
              style: TextStyle(color: P.claro.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 8),
          if (visiveis.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Nada por aqui ainda.',
                    style: TextStyle(color: P.claro.withOpacity(0.7))),
              ),
            ),
          for (final r in visiveis)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: P.mar,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: Text(iaxModoPorId(r.modoId).emoji,
                    style: const TextStyle(fontSize: 24)),
                title: Text(r.pergunta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: P.claro, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${iaxModoPorId(r.modoId).nome} · ${iaxDataTexto(r.quando)}',
                    style: TextStyle(color: P.claro.withOpacity(0.65), fontSize: 12)),
                trailing: Icon(r.favorito ? Icons.star : Icons.star_border,
                    color: P.quente),
                onTap: () async {
                  await Navigator.of(context).push<void>(MaterialPageRoute<void>(
                      builder: (_) => IaxDetalhePage(r: r)));
                  if (mounted) _recarregar();
                },
                onLongPress: () => _apagarUm(r),
              ),
            ),
        ],
      ),
      acoes: [
        IconButton(
          tooltip: 'Limpar histórico',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: _limpar,
        ),
      ],
    );
  }
}

class IaxDetalhePage extends StatelessWidget {
  final IaxResultado r;
  const IaxDetalhePage({super.key, required this.r});

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Resposta salva',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(iaxDataTexto(r.quando),
                  style: TextStyle(color: P.destaque, fontSize: 12)),
              const SizedBox(height: 6),
              SelectableText(r.pergunta,
                  style: TextStyle(
                      color: P.claro, fontWeight: FontWeight.w600, height: 1.35)),
            ],
          )),
          IaxResultadoView(r: r),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
