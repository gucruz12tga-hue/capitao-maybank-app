import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

// ===== tema =====
class Paleta {
  final String nome;
  final Color noite;
  final Color mar;
  final Color destaque;
  final Color claro;
  final Color quente;
  final Color alerta;
  final List<Color> fundo;

  const Paleta(this.nome, this.noite, this.mar, this.destaque, this.claro,
      this.quente, this.alerta, this.fundo);
}

const List<Paleta> paletas = [
  Paleta(
    'Outer Banks',
    Color(0xFF0B1D2A),
    Color(0xFF123A4F),
    Color(0xFF2EC4B6),
    Color(0xFFF4E4C1),
    Color(0xFFFF9F43),
    Color(0xFFFF6B6B),
    [Color(0xFF1B2F4B), Color(0xFF0B1D2A), Color(0xFF05101A)],
  ),
  Paleta(
    'Pôr do sol',
    Color(0xFF1F0F1A),
    Color(0xFF3A1B2E),
    Color(0xFFFF7A59),
    Color(0xFFFFE6D5),
    Color(0xFFFFC857),
    Color(0xFFFF4D6D),
    [Color(0xFF4A1F3D), Color(0xFF1F0F1A), Color(0xFF0F0710)],
  ),
  Paleta(
    'Floresta',
    Color(0xFF0D1F17),
    Color(0xFF16382A),
    Color(0xFF5BD68B),
    Color(0xFFE6F2D8),
    Color(0xFFF2C94C),
    Color(0xFFEB5757),
    [Color(0xFF1D3B2C), Color(0xFF0D1F17), Color(0xFF07110C)],
  ),
  Paleta(
    'Meia-noite',
    Color(0xFF0E0B1F),
    Color(0xFF1E1840),
    Color(0xFF9B8CFF),
    Color(0xFFEDE9FF),
    Color(0xFFFFB86B),
    Color(0xFFFF6B8B),
    [Color(0xFF2A2159), Color(0xFF0E0B1F), Color(0xFF07050F)],
  ),
];

// ===== estado =====
final Cfg cfg = Cfg();
final ValueNotifier<int> sinalLimparChat = ValueNotifier<int>(0);

Paleta get P {
  int i = cfg.tema;
  if (i < 0 || i >= paletas.length) i = 0;
  return paletas[i];
}

// ---------- Configurações e dados salvos no celular ----------
class Cfg extends ChangeNotifier {
  late SharedPreferences p;

  String apiKey = '';
  String nome = 'CAPITÃO_MAYBANK';
  String personalidade =
      'direto, leal e bem-humorado, como um capitão de navio amigo do usuário';
  bool falar = true;
  double tom = 0.6; // tom grave = voz masculina
  double velocidade = 0.5;
  bool continuo = false;
  int tema = 0;
  String skill = 'geral';
  bool permAcoes = true;
  bool permMemoria = true;
  bool permWeb = true;
  String cidade = '';
  bool permLocal = false;
  String localTexto = '';

  Future<void> carregar() async {
    p = await SharedPreferences.getInstance();
    apiKey = p.getString('apiKey') ?? '';
    nome = p.getString('nome') ?? nome;
    personalidade = p.getString('personalidade') ?? personalidade;
    falar = p.getBool('falar') ?? true;
    tom = p.getDouble('tom') ?? 0.6;
    velocidade = p.getDouble('velocidade') ?? 0.5;
    continuo = p.getBool('continuo') ?? false;
    tema = p.getInt('tema') ?? 0;
    skill = p.getString('skill') ?? 'geral';
    permAcoes = p.getBool('permAcoes') ?? true;
    permMemoria = p.getBool('permMemoria') ?? true;
    permWeb = p.getBool('permWeb') ?? true;
    cidade = p.getString('cidade') ?? '';
    permLocal = p.getBool('permLocal') ?? false;
    localTexto = p.getString('localTexto') ?? '';
  }

  void salvar() {
    p.setString('apiKey', apiKey);
    p.setString('nome', nome);
    p.setString('personalidade', personalidade);
    p.setBool('falar', falar);
    p.setDouble('tom', tom);
    p.setDouble('velocidade', velocidade);
    p.setBool('continuo', continuo);
    p.setInt('tema', tema);
    p.setString('skill', skill);
    p.setBool('permAcoes', permAcoes);
    p.setBool('permMemoria', permMemoria);
    p.setBool('permWeb', permWeb);
    p.setString('cidade', cidade);
    p.setBool('permLocal', permLocal);
    p.setString('localTexto', localTexto);
  }

  void mudou() {
    salvar();
    notifyListeners();
  }

  List<String> lista(String chave) {
    return List<String>.from(p.getStringList(chave) ?? <String>[]);
  }

  Future<void> setLista(String chave, List<String> valor) async {
    await p.setStringList(chave, valor);
    notifyListeners();
  }

  List<String> get memoria => lista('memoria');
}

// ---------- Habilidades (modos do assistente) ----------
class Habilidade {
  final String id;
  final String nome;
  final String emoji;
  final String instrucao;
  const Habilidade(this.id, this.nome, this.emoji, this.instrucao);
}

const List<Habilidade> habilidades = [
  Habilidade('geral', 'Assistente geral', '⚓',
      'Ajude com qualquer assunto do dia a dia.'),
  Habilidade('prog', 'Programador', '💻',
      'Ajude com programação: explique, escreva e corrija código completo e funcional, aponte os erros prováveis, use blocos de código e explique em passos simples.'),
  Habilidade('gamer', 'Gamer', '🎮',
      'Ajude com jogos: dicas, estratégias, builds, guias passo a passo, soluções para partes difíceis e recomendações. Diga quando não tiver certeza de detalhes de versões.'),
  Habilidade('estudos', 'Estudos', '📚',
      'Seja um tutor: explique passo a passo com exemplos simples, faça resumos, crie perguntas de prova, flashcards e planos de estudo. Confira se o usuário entendeu.'),
  Habilidade('editor', 'Editor', '🎬',
      'Ajude a editar textos e vídeos: revise e melhore textos, crie roteiros, legendas, títulos, ideias de cortes e de edição.'),
  Habilidade('trabalho', 'Trabalho', '💼',
      'Ajude no trabalho: e-mails profissionais, resumos de reunião, planejamento, fórmulas de Excel e Google Sheets, relatórios e organização de tarefas.'),
  Habilidade('tradutor', 'Tradutor', '🌐',
      'Traduza o que o usuário disser. Se ele não indicar o idioma de destino, traduza para inglês. Mostre a tradução e, quando útil, a pronúncia e uma explicação curta.'),
  Habilidade('golpes', 'Anti-golpe', '🛡️',
      'Analise mensagens, links e ligações em busca de golpes: aponte sinais de alerta, dê um veredito claro (seguro, suspeito ou golpe provável) e diga o que fazer. Nunca peça senhas ou dados bancários.'),
  Habilidade('amigo', 'Conversa', '💬',
      'Converse de forma leve, simpática e natural, como um amigo. Respostas curtas.'),
];

Habilidade habilidadeAtual() {
  return habilidades.firstWhere((h) => h.id == cfg.skill,
      orElse: () => habilidades.first);
}

// ---------- Anexos (foto, PDF, áudio, vídeo, texto) ----------
class Anexo {
  final String nome;
  final String mime;
  final Uint8List bytes;
  Anexo(this.nome, this.mime, this.bytes);
  bool get ehImagem => mime.startsWith('image/');
}

String mimePorNome(String nome) {
  final n = nome.toLowerCase();
  final ponto = n.lastIndexOf('.');
  final ext = ponto >= 0 ? n.substring(ponto + 1) : '';
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'txt':
    case 'md':
    case 'csv':
    case 'json':
    case 'html':
    case 'xml':
    case 'py':
    case 'dart':
    case 'js':
    case 'css':
      return 'text/plain';
    case 'mp3':
      return 'audio/mp3';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
    case 'opus':
      return 'audio/ogg';
    case 'flac':
      return 'audio/flac';
    case 'aac':
      return 'audio/aac';
    case 'm4a':
      return 'audio/mp4';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'webm':
      return 'video/webm';
    case '3gp':
      return 'video/3gpp';
  }
  return 'application/octet-stream';
}

// ---------- Conversa com o Gemini (grátis) ----------
class IaResp {
  final bool ok;
  final String texto;
  IaResp(this.ok, this.texto);
}

class Ia {
  static const List<String> modelos = [
    'gemini-flash-latest',
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3-flash-preview',
    'gemini-2.5-flash',
  ];
  static String? modeloOk;

  static String _sistema(String extra) {
    final h = habilidadeAtual();
    final agora = DateTime.now().toString().substring(0, 16);
    final b = StringBuffer();
    b.writeln(
        'Você é ${cfg.nome}, assistente pessoal de IA no celular do usuário.');
    b.writeln('Personalidade: ${cfg.personalidade}.');
    b.writeln('Habilidade ativa: ${h.nome}. ${h.instrucao}');
    b.writeln(
        'Responda sempre em português do Brasil, de forma clara e natural (a resposta pode ser lida em voz alta), a menos que o usuário peça outro idioma.');
    b.writeln(
        'Responda qualquer assunto com honestidade. Se não souber, diga. Peça confirmação antes de ações importantes. Seja objetivo e só escreva respostas longas quando for necessário.');
    b.writeln('Data e hora atuais no celular do usuário: $agora.');
    if (cfg.permMemoria) {
      final mem = cfg.memoria;
      if (mem.isNotEmpty) {
        b.writeln('Fatos que o usuário autorizou você a lembrar:');
        for (final m in mem) {
          b.writeln('- $m');
        }
      }
    }
    if (cfg.permLocal && cfg.localTexto.isNotEmpty) {
      b.writeln(
          'Última localização conhecida do usuário (autorizada por ele): ${cfg.localTexto}.');
    }
    if (extra.isNotEmpty) b.writeln(extra);
    return b.toString();
  }

  static Future<http.Response> _post(
      String modelo, Map<String, dynamic> corpo) {
    return http
        .post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent'),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': cfg.apiKey,
          },
          body: jsonEncode(corpo),
        )
        .timeout(const Duration(seconds: 90));
  }

  static Future<IaResp> perguntar({
    required String texto,
    Anexo? anexo,
    List<Map<String, dynamic>>? historico,
    String extra = '',
    bool web = false,
  }) async {
    if (cfg.apiKey.isEmpty) {
      return IaResp(false,
          'Falta a chave do Gemini. Vá na aba Config e cole a chave grátis (aistudio.google.com/apikey).');
    }
    final partes = <Map<String, dynamic>>[];
    String textoFinal = texto;
    if (anexo != null) {
      if (anexo.mime == 'text/plain') {
        var conteudo = utf8.decode(anexo.bytes, allowMalformed: true);
        if (conteudo.length > 200000) conteudo = conteudo.substring(0, 200000);
        textoFinal =
            'Conteúdo do arquivo "${anexo.nome}":\n$conteudo\n\n$texto';
      } else {
        partes.add({
          'inline_data': {
            'mime_type': anexo.mime,
            'data': base64Encode(anexo.bytes),
          }
        });
      }
    }
    partes.insert(0, {'text': textoFinal});

    final h = historico ?? <Map<String, dynamic>>[];
    final recente = h.length > 30 ? h.sublist(h.length - 30) : h;
    final corpo = <String, dynamic>{
      'system_instruction': {
        'parts': [
          {'text': _sistema(extra)}
        ]
      },
      'contents': [
        ...recente,
        {'role': 'user', 'parts': partes},
      ],
    };
    if (web) {
      corpo['tools'] = [
        {'google_search': {}}
      ];
    }

    final lista = <String>[
      if (modeloOk != null) modeloOk!,
      ...modelos.where((m) => m != modeloOk),
    ];
    int codigo = 0;
    String erro = '';
    try {
      for (final modelo in lista) {
        var r = await _post(modelo, corpo);
        if (corpo.containsKey('tools') &&
            (r.statusCode == 400 || r.statusCode == 403 || r.statusCode == 429)) {
          corpo.remove('tools');
          r = await _post(modelo, corpo);
        }
        if (r.statusCode == 200) {
          try {
            final j = jsonDecode(utf8.decode(r.bodyBytes));
            final ps = j['candidates'][0]['content']['parts'] as List;
            final buf = StringBuffer();
            for (final parte in ps) {
              final tx = parte['text'];
              if (tx is String) buf.write(tx);
            }
            final resp = buf.toString().trim();
            if (resp.isEmpty) {
              return IaResp(
                  false, 'O Gemini não devolveu texto. Tente reformular.');
            }
            modeloOk = modelo;
            return IaResp(true, resp);
          } catch (_) {
            return IaResp(false,
                'O Gemini não conseguiu responder a isso. Tente reformular.');
          }
        }
        String detalhe = '';
        try {
          detalhe = jsonDecode(utf8.decode(r.bodyBytes))['error']['message']
              .toString();
        } catch (_) {}
        codigo = r.statusCode;
        erro = 'Erro ${r.statusCode} (modelo $modelo): $detalhe';
        if (codigo == 404 || codigo == 429 || codigo == 500 || codigo == 503) {
          continue;
        }
        break;
      }
    } catch (_) {
      return IaResp(false,
          'Sem conexão com a internet no momento. Notas, tarefas e várias ferramentas funcionam offline.');
    }
    if (codigo == 429) {
      return IaResp(false,
          'Muitas perguntas seguidas (limite grátis). Espere um minutinho e tente de novo.');
    }
    if (codigo == 403 ||
        (codigo == 400 && erro.toLowerCase().contains('key'))) {
      return IaResp(
          false, 'Problema com a chave do Gemini. Confira na aba Config.\n$erro');
    }
    return IaResp(false, erro.isEmpty ? 'Erro desconhecido.' : erro);
  }
}

// ===== servicos =====
// ---------- Textos e datas ----------
String dois(int n) => n.toString().padLeft(2, '0');

String semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const para = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final sb = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    sb.write(i >= 0 ? para[i] : c);
  }
  return sb.toString();
}

const List<String> _dias = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];
const List<String> _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String dataExtenso(DateTime d) {
  return '${_dias[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]} de ${d.year}';
}

String horaTexto(DateTime d) => '${dois(d.hour)}:${dois(d.minute)}';

int _n(dynamic v) => v is num ? v.round() : 0;

// ---------- Abrir links e apps ----------
Future<bool> abrirUrl(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

const Map<String, String> appsConhecidos = {
  'whatsapp': 'com.whatsapp',
  'youtube': 'com.google.android.youtube',
  'instagram': 'com.instagram.android',
  'facebook': 'com.facebook.katana',
  'tiktok': 'com.zhiliaoapp.musically',
  'telegram': 'org.telegram.messenger',
  'spotify': 'com.spotify.music',
  'netflix': 'com.netflix.mediaclient',
  'gmail': 'com.google.android.gm',
  'chrome': 'com.android.chrome',
  'mapas': 'com.google.android.apps.maps',
  'maps': 'com.google.android.apps.maps',
  'google maps': 'com.google.android.apps.maps',
  'play store': 'com.android.vending',
  'loja': 'com.android.vending',
  'drive': 'com.google.android.apps.docs',
  'fotos': 'com.google.android.apps.photos',
  'discord': 'com.discord',
  'twitter': 'com.twitter.android',
  'google': 'com.google.android.googlequicksearchbox',
  'planilhas': 'com.google.android.apps.docs.editors.sheets',
  'documentos': 'com.google.android.apps.docs.editors.docs',
  'agenda': 'com.google.android.calendar',
  'relogio': 'com.google.android.deskclock',
  'excel': 'com.microsoft.office.excel',
};

Future<String> abrirApp(String pedido) async {
  final n = semAcento(pedido.toLowerCase().trim());
  try {
    if (n == 'camera') {
      await AndroidIntent(action: 'android.media.action.IMAGE_CAPTURE')
          .launch();
      return 'Abrindo a câmera.';
    }
    if (n == 'configuracoes' || n == 'configuracao' || n == 'ajustes') {
      await AndroidIntent(action: 'android.settings.SETTINGS').launch();
      return 'Abrindo as configurações.';
    }
    if (n == 'wifi' || n == 'wi-fi') {
      await AndroidIntent(action: 'android.settings.WIFI_SETTINGS').launch();
      return 'Abrindo o Wi-Fi.';
    }
    if (n == 'bluetooth') {
      await AndroidIntent(action: 'android.settings.BLUETOOTH_SETTINGS')
          .launch();
      return 'Abrindo o Bluetooth.';
    }
    if (n == 'telefone' || n == 'discador') {
      await AndroidIntent(action: 'android.intent.action.DIAL').launch();
      return 'Abrindo o telefone.';
    }
    final pkg = appsConhecidos[n];
    if (pkg == null) {
      return 'Não conheço o app "$pedido". Posso abrir: ${appsConhecidos.keys.take(12).join(', ')}, câmera, configurações, wi-fi, bluetooth e telefone.';
    }
    await AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: pkg,
    ).launch();
    return 'Abrindo $pedido. (Se nada abrir, o app pode não estar instalado.)';
  } catch (_) {
    return 'Não consegui abrir "$pedido".';
  }
}

Future<String> criarAlarme(int h, int m, String msg) async {
  try {
    await AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': h,
        'android.intent.extra.alarm.MINUTES': m,
        'android.intent.extra.alarm.MESSAGE': msg,
        'android.intent.extra.alarm.SKIP_UI': true,
      },
    ).launch();
    return 'Alarme criado para ${dois(h)}:${dois(m)}.';
  } catch (_) {
    return 'Não consegui criar o alarme.';
  }
}

Future<String> criarTimerNativo(int segundos, String msg) async {
  try {
    await AndroidIntent(
      action: 'android.intent.action.SET_TIMER',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.LENGTH': segundos,
        'android.intent.extra.alarm.MESSAGE': msg,
        'android.intent.extra.alarm.SKIP_UI': true,
      },
    ).launch();
    return 'Timer de ${segundos ~/ 60} min ${segundos % 60} s iniciado no relógio do celular.';
  } catch (_) {
    return 'Não consegui criar o timer.';
  }
}

// ---------- Bateria e rede ----------
Future<String> textoBateria() async {
  try {
    final b = Battery();
    final nivel = await b.batteryLevel;
    final estado = await b.batteryState;
    String extra = '';
    if (estado == BatteryState.charging) extra = ' (carregando ⚡)';
    if (estado == BatteryState.full) extra = ' (cheia)';
    return '🔋 Bateria em $nivel%$extra';
  } catch (_) {
    return 'Não consegui ler a bateria.';
  }
}

Future<String> diagnosticoRede() async {
  final sb = StringBuffer();
  int ok = 0;
  int total = 0;
  int soma = 0;
  Future<void> teste(String nome, String url) async {
    total++;
    final t0 = DateTime.now();
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      final ms = DateTime.now().difference(t0).inMilliseconds;
      ok++;
      soma += ms;
      sb.writeln('✅ $nome: $ms ms (HTTP ${r.statusCode})');
    } catch (_) {
      sb.writeln('❌ $nome: sem resposta');
    }
  }

  await teste('Google', 'https://www.google.com/generate_204');
  await teste('Gemini (IA)', 'https://generativelanguage.googleapis.com/');
  await teste('Cloudflare', 'https://cloudflare.com/cdn-cgi/trace');
  String veredito;
  if (ok == 0) {
    veredito = '🔴 Sem internet. Confira o Wi-Fi/dados móveis e o modo avião.';
  } else {
    final media = soma ~/ ok;
    if (media < 400) {
      veredito = '🟢 Conexão boa (média de $media ms).';
    } else if (media < 1000) {
      veredito = '🟡 Conexão razoável (média de $media ms).';
    } else {
      veredito = '🟠 Conexão lenta (média de $media ms).';
    }
    if (ok < total) {
      veredito = '$veredito Alguns sites não responderam.';
    }
  }
  sb.writeln(veredito);
  return sb.toString().trim();
}

// ---------- Clima ----------
String descClima(int c) {
  if (c == 0) return 'céu limpo';
  if (c == 1) return 'predominantemente limpo';
  if (c == 2) return 'parcialmente nublado';
  if (c == 3) return 'nublado';
  if (c == 45 || c == 48) return 'neblina';
  if (c >= 51 && c <= 57) return 'garoa';
  if (c >= 61 && c <= 67) return 'chuva';
  if (c >= 71 && c <= 77) return 'neve';
  if (c >= 80 && c <= 82) return 'pancadas de chuva';
  if (c >= 95) return 'tempestade';
  return 'tempo variável';
}

Future<String> climaPorCoordenadas(double lat, double lon, String local) async {
  try {
    final w = await http
        .get(Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=3'))
        .timeout(const Duration(seconds: 15));
    final wj = jsonDecode(utf8.decode(w.bodyBytes));
    final cur = wj['current'];
    final d = wj['daily'];
    final sb = StringBuffer();
    sb.writeln('🌤️ $local');
    sb.writeln(
        'Agora: ${_n(cur['temperature_2m'])}°C, ${descClima(_n(cur['weather_code']))}');
    sb.writeln(
        'Sensação: ${_n(cur['apparent_temperature'])}°C · Umidade: ${_n(cur['relative_humidity_2m'])}% · Vento: ${_n(cur['wind_speed_10m'])} km/h');
    final nomes = ['Hoje', 'Amanhã', 'Depois de amanhã'];
    final qtd = (d['time'] as List).length;
    for (int i = 0; i < qtd && i < 3; i++) {
      sb.writeln(
          '${nomes[i]}: ${_n(d['temperature_2m_min'][i])}° a ${_n(d['temperature_2m_max'][i])}°, chuva ${_n(d['precipitation_probability_max'][i])}%');
    }
    return sb.toString().trim();
  } catch (_) {
    return 'Não consegui buscar o clima agora. Verifique a internet.';
  }
}

Future<String> buscarClima(String cidade) async {
  final busca = cidade.trim();
  if (busca.isEmpty) return 'Diga a cidade. Exemplo: clima em Cuiabá.';
  try {
    final g = await http
        .get(Uri.parse(
            'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(busca)}&count=1&language=pt&format=json'))
        .timeout(const Duration(seconds: 15));
    final gj = jsonDecode(utf8.decode(g.bodyBytes));
    final res = gj['results'];
    if (res == null || (res as List).isEmpty) {
      return 'Não encontrei a cidade "$busca".';
    }
    final c = res[0];
    final nomeC = c['name'].toString();
    final adm = c['admin1'];
    final local = adm == null ? nomeC : '$nomeC - $adm';
    final lat = (c['latitude'] as num).toDouble();
    final lon = (c['longitude'] as num).toDouble();
    return climaPorCoordenadas(lat, lon, local);
  } catch (_) {
    return 'Não consegui buscar o clima agora. Verifique a internet.';
  }
}

// ---------- Cotações ----------
Future<String> buscarCotacoes() async {
  try {
    final r = await http
        .get(Uri.parse(
            'https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL,BTC-BRL'))
        .timeout(const Duration(seconds: 15));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final sb = StringBuffer();
    sb.writeln('💱 Cotações');
    void linha(String chave, String nome, int casas) {
      final x = j[chave];
      if (x == null) return;
      final bid = double.tryParse(x['bid'].toString()) ?? 0;
      final v = double.tryParse(x['pctChange'].toString()) ?? 0;
      final sinal = v >= 0 ? '+' : '';
      sb.writeln('$nome: R\$ ${bid.toStringAsFixed(casas)} ($sinal$v%)');
    }

    linha('USDBRL', 'Dólar', 2);
    linha('EURBRL', 'Euro', 2);
    linha('BTCBRL', 'Bitcoin', 0);
    return sb.toString().trim();
  } catch (_) {
    return 'Não consegui buscar as cotações agora. Verifique a internet.';
  }
}

// ---------- Localização ----------
class ErroLocal implements Exception {
  final String msg;
  ErroLocal(this.msg);
  @override
  String toString() => msg;
}

class LocalInfo {
  final double lat;
  final double lon;
  final double precisao;
  final String endereco;
  final String cidade;
  LocalInfo(this.lat, this.lon, this.precisao, this.endereco, this.cidade);

  String get link => 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
  String get coords => '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
}

Future<Position> pegarPosicao() async {
  if (!cfg.permLocal) {
    throw ErroLocal(
        'O modo de localização está desligado. Ative em Ferramentas > Localização (ou Config > Permissões).');
  }
  final ativo = await Geolocator.isLocationServiceEnabled();
  if (!ativo) {
    throw ErroLocal('O GPS está desligado. Ligue a localização do celular.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    throw ErroLocal(
        'Permissão de localização negada. Libere nas configurações do app.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  ).timeout(const Duration(seconds: 25));
}

Future<LocalInfo> obterLocal() async {
  final pos = await pegarPosicao();
  String endereco = '';
  String cidade = '';
  try {
    final r = await http.get(
      Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=pt-BR'),
      headers: {'User-Agent': 'CapitaoMaybank/2.0'},
    ).timeout(const Duration(seconds: 15));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final a = j['address'];
    if (a != null) {
      final partes = <String>[];
      final rua = a['road'];
      final bairro = a['suburb'] ?? a['neighbourhood'];
      final cid = a['city'] ?? a['town'] ?? a['village'] ?? a['municipality'];
      final est = a['state'];
      if (rua != null) partes.add(rua.toString());
      if (bairro != null) partes.add(bairro.toString());
      if (cid != null) {
        partes.add(cid.toString());
        cidade = cid.toString();
      }
      if (est != null) partes.add(est.toString());
      endereco = partes.join(', ');
    }
    if (endereco.isEmpty && j['display_name'] != null) {
      endereco = j['display_name'].toString();
    }
  } catch (_) {}
  final info =
      LocalInfo(pos.latitude, pos.longitude, pos.accuracy, endereco, cidade);
  cfg.localTexto = endereco.isEmpty ? info.coords : endereco;
  cfg.salvar();
  return info;
}

String textoLocal(LocalInfo l) {
  final sb = StringBuffer();
  sb.writeln('📍 Você está aqui:');
  if (l.endereco.isNotEmpty) sb.writeln(l.endereco);
  sb.writeln('Coordenadas: ${l.coords}');
  sb.writeln('Precisão: cerca de ${l.precisao.round()} m');
  sb.writeln(l.link);
  return sb.toString().trim();
}

Future<String> climaAqui() async {
  try {
    final l = await obterLocal();
    final nome = l.cidade.isNotEmpty ? l.cidade : l.coords;
    return climaPorCoordenadas(l.lat, l.lon, nome);
  } on ErroLocal catch (e) {
    return e.msg;
  } catch (_) {
    return 'Não consegui pegar sua localização agora.';
  }
}

Future<String> procurarPerto(String o) async {
  try {
    final l = await obterLocal();
    final url =
        'https://www.google.com/maps/search/${Uri.encodeComponent(o)}/@${l.lat},${l.lon},15z';
    final ok = await abrirUrl(url);
    return ok
        ? 'Procurando "$o" perto de você no Google Maps.'
        : 'Não consegui abrir o Google Maps.';
  } on ErroLocal catch (e) {
    return e.msg;
  } catch (_) {
    return 'Não consegui pegar sua localização agora.';
  }
}

// ---------- Rotinas ----------
List<Map<String, dynamic>> lerRotinas() {
  final out = <Map<String, dynamic>>[];
  for (final s in cfg.lista('rotinas')) {
    try {
      out.add(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {}
  }
  return out;
}

Future<void> salvarRotinas(List<Map<String, dynamic>> r) {
  return cfg.setLista('rotinas', r.map((e) => jsonEncode(e)).toList());
}

void garantirRotinasPadrao() {
  if (cfg.p.containsKey('rotinas')) return;
  cfg.p.setStringList('rotinas', [
    jsonEncode({
      'n': 'Bom dia',
      'c': ['que dia é hoje', 'clima', 'cotação do dólar', 'bateria']
    }),
    jsonEncode({
      'n': 'Resumo do celular',
      'c': ['bateria', 'teste de conexão']
    }),
  ]);
}

// ---------- Anti-golpe (análise local, funciona offline) ----------
String analiseGolpeLocal(String texto) {
  final t = semAcento(texto.toLowerCase());
  final sinais = <String>[];
  if (RegExp(r'(bit\.ly|tinyurl|cutt\.ly|is\.gd|rb\.gy|t\.co/|goo\.gl|shorturl)')
      .hasMatch(t)) {
    sinais.add('Link encurtado (esconde o destino real).');
  }
  if (RegExp(r'https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(t)) {
    sinais.add('Link com número de IP em vez de um site normal.');
  }
  if (RegExp(r'\.(xyz|top|click|icu|shop|work|buzz|rest|cfd|sbs)(/|\s|$)')
      .hasMatch(t)) {
    sinais.add('Link com final de domínio suspeito.');
  }
  const urgencia = [
    'urgente',
    'imediatamente',
    'ultimo aviso',
    'conta sera bloqueada',
    'conta bloqueada',
    'conta suspensa',
    'ultimas horas',
    'expira hoje',
    'regularize',
    'pendencia',
  ];
  if (urgencia.any((x) => t.contains(x))) {
    sinais.add('Pressão de urgência ou ameaça de bloqueio.');
  }
  const premios = ['voce ganhou', 'premio', 'sorteado', 'heranca', 'brinde gratis'];
  if (premios.any((x) => t.contains(x))) {
    sinais.add('Promessa de prêmio ou dinheiro fácil.');
  }
  const dados = [
    'senha',
    'codigo de verificacao',
    'codigo enviado',
    'token',
    'cvv',
    'dados do cartao',
    'confirme seus dados',
    'atualize seus dados',
    'clique no link',
  ];
  if (dados.any((x) => t.contains(x))) {
    sinais.add('Pede dados, senha, código ou que você clique em link.');
  }
  if (t.contains('pix') &&
      (t.contains('transfer') || t.contains('deposit') || t.contains('urgente'))) {
    sinais.add('Pedido de Pix ou transferência.');
  }
  if (t.contains('novo numero') || t.contains('mudei de numero')) {
    sinais.add('Clássico golpe do "mudei de número".');
  }
  if (t.contains('correios') && t.contains('taxa')) {
    sinais.add('Golpe da taxa dos Correios.');
  }
  String nivel;
  if (sinais.length >= 3) {
    nivel = '🚨 Golpe provável';
  } else if (sinais.isNotEmpty) {
    nivel = '⚠️ Suspeito';
  } else {
    nivel = '✅ Nenhum sinal óbvio (mas continue desconfiado)';
  }
  final sb = StringBuffer();
  sb.writeln('Análise rápida (no celular): $nivel');
  for (final s in sinais) {
    sb.writeln('• $s');
  }
  return sb.toString().trim();
}

// ---------- Senhas ----------
String gerarSenha(int n, bool simbolos) {
  const letras = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const sims = '!@#\$%&*?-_+=';
  final chars = simbolos ? letras + sims : letras;
  final r = Random.secure();
  return List<String>.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
}

// ---------- Calculadora ----------
class Calc {
  final String s;
  int i = 0;
  Calc(this.s);

  static double avaliar(String entrada) {
    final c = Calc(entrada
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .replaceAll('×', '*')
        .replaceAll('÷', '/'));
    final v = c.soma();
    if (c.i != c.s.length) throw const FormatException('expressão inválida');
    return v;
  }

  double soma() {
    var v = produto();
    while (i < s.length && (s[i] == '+' || s[i] == '-')) {
      final op = s[i];
      i++;
      final r = produto();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  double produto() {
    var v = potencia();
    while (i < s.length && (s[i] == '*' || s[i] == '/' || s[i] == '%')) {
      final op = s[i];
      i++;
      final r = potencia();
      if (op == '*') {
        v = v * r;
      } else if (op == '/') {
        v = v / r;
      } else {
        v = v % r;
      }
    }
    return v;
  }

  double potencia() {
    final b = unario();
    if (i < s.length && s[i] == '^') {
      i++;
      final e = potencia();
      return pow(b, e).toDouble();
    }
    return b;
  }

  double unario() {
    if (i < s.length && s[i] == '-') {
      i++;
      return -unario();
    }
    if (i < s.length && s[i] == '+') {
      i++;
      return unario();
    }
    return atomo();
  }

  bool _digito(int c) => c >= 48 && c <= 57;

  double atomo() {
    if (i < s.length && s[i] == '(') {
      i++;
      final v = soma();
      if (i >= s.length || s[i] != ')') {
        throw const FormatException('falta fechar parênteses');
      }
      i++;
      return v;
    }
    final ini = i;
    while (i < s.length && (_digito(s.codeUnitAt(i)) || s[i] == '.')) {
      i++;
    }
    if (ini == i) throw const FormatException('número esperado');
    return double.parse(s.substring(ini, i));
  }
}

String formatarNumero(double r) {
  if (r.isNaN || r.isInfinite) return 'erro';
  if (r == r.roundToDouble() && r.abs() < 1e12) return r.toInt().toString();
  return double.parse(r.toStringAsFixed(8)).toString();
}

// ===== chat =====
// Chave global do chat e aba atual (usadas pelas outras telas)
final GlobalKey<ChatPageState> chatKey = GlobalKey<ChatPageState>();
final ValueNotifier<int> abaAtual = ValueNotifier<int>(0);

void chatComando(BuildContext c,
    {String? enviar, List<String>? varios, String? preencher}) {
  Navigator.of(c).popUntil((r) => r.isFirst);
  abaAtual.value = 0;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final st = chatKey.currentState;
    if (st == null) return;
    if (preencher != null) st.preencher(preencher);
    if (enviar != null) st.enviar(enviar);
    if (varios != null) st.executarVarios(varios);
  });
}

class Msg {
  final String texto;
  final bool doUsuario;
  final bool erro;
  final Uint8List? miniatura;
  bool local;
  Msg(this.texto, this.doUsuario,
      {this.erro = false, this.local = false, this.miniatura});
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final List<Msg> _msgs = [];
  final List<Map<String, dynamic>> _historico = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  final ImagePicker _picker = ImagePicker();

  bool _ouvindo = false;
  bool _pensando = false;
  bool _vozEscolhida = false;
  Anexo? _anexo;

  @override
  void initState() {
    super.initState();
    cfg.addListener(_aplicarVoz);
    sinalLimparChat.addListener(_limpar);
    _iniciar();
  }

  @override
  void dispose() {
    cfg.removeListener(_aplicarVoz);
    sinalLimparChat.removeListener(_limpar);
    _ctrl.dispose();
    _scroll.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _iniciar() async {
    await _aplicarVozAsync();
    try {
      await _stt.initialize();
    } catch (_) {}
    _carregarChat();
    if (_msgs.isEmpty) {
      _msgs.add(Msg(
          'Fala, comandante! Eu sou o ${cfg.nome}. Pode digitar, falar no microfone ou mandar foto, PDF, áudio e vídeo pelo botão +. Veja as abas Ferramentas, Biblioteca e Config.',
          false,
          local: true));
    }
    if (cfg.apiKey.isEmpty) {
      _msgs.add(Msg(
          'Antes de conversar, vá na aba Config e cole sua chave grátis do Gemini (aistudio.google.com/apikey).',
          false,
          local: true));
    }
    if (mounted) setState(() {});
  }

  void _aplicarVoz() {
    _aplicarVozAsync();
  }

  Future<void> _aplicarVozAsync() async {
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setPitch(cfg.tom);
      await _tts.setSpeechRate(cfg.velocidade);
      await _tts.awaitSpeakCompletion(true);
      if (!_vozEscolhida) {
        _vozEscolhida = true;
        final vozes = await _tts.getVoices as List?;
        if (vozes != null) {
          final masc = vozes.cast<Map>().where((v) {
            final n = (v['name'] ?? '').toString().toLowerCase();
            final l = (v['locale'] ?? '').toString().toLowerCase();
            return l.startsWith('pt') &&
                (n.contains('male') || n.contains('ptd') || n.contains('pte'));
          }).toList();
          if (masc.isNotEmpty) {
            await _tts.setVoice({
              'name': masc.first['name'].toString(),
              'locale': masc.first['locale'].toString(),
            });
          }
        }
      }
    } catch (_) {}
  }

  // ---------- Usado por outras telas ----------
  void preencher(String t) {
    _ctrl.text = t;
    _ctrl.selection = TextSelection.collapsed(offset: t.length);
    if (mounted) setState(() {});
  }

  Future<void> testarVoz() async {
    try {
      await _tts.stop();
      await _tts.speak(
          'Comandante, aqui é o ${cfg.nome}. Minha voz está funcionando.');
    } catch (_) {}
  }

  // ---------- Histórico salvo ----------
  void _carregarChat() {
    try {
      final s = cfg.p.getString('chat');
      if (s == null) return;
      final lista = jsonDecode(s) as List;
      for (final e in lista) {
        _msgs.add(Msg(e['t'].toString(), e['u'] == true, local: e['l'] == true));
      }
      String? ultimoPapel;
      for (final m in _msgs) {
        if (m.local) continue;
        final papel = m.doUsuario ? 'user' : 'model';
        if (_historico.isEmpty && papel != 'user') continue;
        if (ultimoPapel == papel) {
          final partes = _historico.last['parts'] as List;
          partes[0]['text'] = '${partes[0]['text']}\n${m.texto}';
        } else {
          _historico.add({
            'role': papel,
            'parts': [
              {'text': m.texto}
            ]
          });
          ultimoPapel = papel;
        }
      }
      if (_historico.isNotEmpty && _historico.last['role'] == 'user') {
        _historico.removeLast();
      }
    } catch (_) {}
  }

  void _salvarChat() {
    try {
      final itens = _msgs.where((m) => !m.erro).toList();
      final ult = itens.length > 60 ? itens.sublist(itens.length - 60) : itens;
      final dados = ult
          .map((m) => {'t': m.texto, 'u': m.doUsuario, 'l': m.local})
          .toList();
      cfg.p.setString('chat', jsonEncode(dados));
    } catch (_) {}
  }

  void _add(Msg m) {
    if (!mounted) return;
    setState(() => _msgs.add(m));
    _salvarChat();
    _rolar();
  }

  void _limpar() {
    _msgs.clear();
    _historico.clear();
    cfg.p.remove('chat');
    if (mounted) setState(() {});
  }

  void _rolar() {
    Timer(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  // ---------- Voz ----------
  Future<void> _falar(String texto) async {
    if (!cfg.falar) return;
    var t = texto.replaceAll(RegExp(r'```[\s\S]*?```'), ' (trecho de código na tela) ');
    t = t.replaceAll(RegExp(r'[*#_`>]'), '');
    t = t.replaceAll(RegExp(r'https?://\S+'), ' link ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > 900) t = '${t.substring(0, 900)}... o resto está na tela.';
    if (t.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(t);
    } catch (_) {}
  }

  void _depoisDeFalar(bool porVoz) {
    if (porVoz && cfg.continuo && mounted && !_ouvindo) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _microfone();
      });
    }
  }

  Future<void> _microfone() async {
    if (_ouvindo) {
      await _stt.stop();
      if (mounted) setState(() => _ouvindo = false);
      return;
    }
    try {
      await _tts.stop();
    } catch (_) {}
    bool ok = false;
    try {
      ok = await _stt.initialize();
    } catch (_) {}
    if (!ok) {
      _add(Msg(
          'Não consegui acessar o microfone. Autorize nas permissões do app.',
          false,
          erro: true));
      return;
    }
    setState(() => _ouvindo = true);
    await _stt.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 3),
      onResult: (res) {
        if (res.finalResult) {
          if (mounted) setState(() => _ouvindo = false);
          enviar(res.recognizedWords, porVoz: true);
        } else {
          _ctrl.text = res.recognizedWords;
        }
      },
    );
  }

  // ---------- Anexos ----------
  Future<void> _anexarImagem(ImageSource origem) async {
    try {
      final img = await _picker.pickImage(
          source: origem, maxWidth: 1600, imageQuality: 85);
      if (img == null) return;
      final bytes = await img.readAsBytes();
      var nome = img.name;
      if (nome.isEmpty) nome = 'foto.jpg';
      var mime = mimePorNome(nome);
      if (!mime.startsWith('image/')) mime = 'image/jpeg';
      if (!mounted) return;
      setState(() => _anexo = Anexo(nome, mime, bytes));
    } catch (_) {
      _add(Msg('Não consegui abrir a câmera ou a galeria. Autorize nas permissões do app.',
          false,
          erro: true));
    }
  }

  Future<void> _anexarArquivo() async {
    try {
      const grupo = XTypeGroup(label: 'arquivos', extensions: <String>[
        'pdf',
        'txt',
        'md',
        'csv',
        'json',
        'html',
        'xml',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'mp3',
        'wav',
        'ogg',
        'opus',
        'flac',
        'aac',
        'm4a',
        'mp4',
        'mov',
        'webm',
        '3gp',
      ]);
      final f = await openFile(acceptedTypeGroups: <XTypeGroup>[grupo]);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 14 * 1024 * 1024) {
        _add(Msg('Arquivo grande demais (máximo 14 MB no plano grátis).', false,
            erro: true));
        return;
      }
      final mime = mimePorNome(f.name);
      if (mime == 'application/octet-stream') {
        _add(Msg('Esse tipo de arquivo não é suportado.', false, erro: true));
        return;
      }
      if (!mounted) return;
      setState(() => _anexo = Anexo(f.name, mime, bytes));
    } catch (_) {
      _add(Msg('Não consegui abrir o arquivo.', false, erro: true));
    }
  }

  // ---------- Envio ----------
  Future<void> executarVarios(List<String> cmds) async {
    for (final c in cmds) {
      final t = c.trim();
      if (t.isEmpty) continue;
      while (_pensando) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await enviar(t);
    }
  }

  Future<void> enviar(String texto, {bool porVoz = false}) async {
    final t = texto.trim();
    if ((t.isEmpty && _anexo == null) || _pensando) return;
    _ctrl.clear();
    final anexo = _anexo;
    final nomeAnexo = anexo == null ? '' : anexo.nome;
    final um = Msg(
      t.isEmpty ? '(anexo: $nomeAnexo)' : t,
      true,
      miniatura: (anexo != null && anexo.ehImagem) ? anexo.bytes : null,
    );
    setState(() => _anexo = null);
    _add(um);

    if (anexo == null) {
      final local = await _comandoLocal(t);
      if (local != null) {
        um.local = true;
        _add(Msg(local, false, local: true));
        await _falar(local);
        _depoisDeFalar(porVoz);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _pensando = true);
    _rolar();
    final prompt = t.isEmpty
        ? 'Explique em detalhes o conteúdo deste anexo ($nomeAnexo). Se for áudio ou vídeo, transcreva e resuma.'
        : t;
    final r = await Ia.perguntar(
      texto: prompt,
      anexo: anexo,
      historico: _historico,
      web: cfg.permWeb && anexo == null,
    );
    if (!mounted) return;
    setState(() => _pensando = false);
    if (r.ok) {
      final registro =
          anexo == null ? prompt : '$prompt [anexo enviado: $nomeAnexo]';
      _historico.add({
        'role': 'user',
        'parts': [
          {'text': registro}
        ]
      });
      _historico.add({
        'role': 'model',
        'parts': [
          {'text': r.texto}
        ]
      });
      if (_historico.length > 40) {
        _historico.removeRange(0, _historico.length - 40);
      }
    }
    _add(Msg(r.texto, false, erro: !r.ok));
    if (r.ok) {
      await _falar(r.texto);
      _depoisDeFalar(porVoz);
    }
  }

  Future<bool> _confirmar(String msg) async {
    if (!mounted) return false;
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: P.mar,
        title: const Text('Confirmar'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    return r == true;
  }

  String _trecho(String o, RegExpMatch m, int g) {
    // O Dart não informa onde um grupo começa, então achamos o texto do grupo
    // dentro da frase (sem acento e minúscula, mesmo tamanho do original)
    // e pegamos o mesmo trecho da frase original, mantendo maiúsculas e acentos.
    final fallback = m.group(g) ?? '';
    if (fallback.isEmpty) return fallback;
    final s = m.input;
    final ini = s.endsWith(fallback)
        ? s.length - fallback.length
        : s.indexOf(fallback);
    final fim = ini + fallback.length;
    if (ini < 0 || fim > o.length || s.length != o.length) return fallback;
    return o.substring(ini, fim);
  }

  // ---------- Comandos do celular (funcionam sem gastar a IA) ----------
  Future<String?> _comandoLocal(String original) async {
    final o = original.trim();
    if (o.isEmpty) return null;
    final s = semAcento(o.toLowerCase());
    const semPerm =
        'As ações no celular estão desligadas. Ative em Config > Permissões.';
    RegExpMatch? m;

    if (s == 'limpar conversa' || s == 'apagar conversa') {
      _limpar();
      return 'Conversa limpa.';
    }

    if (RegExp(r'\bque horas\b|\bhora certa\b').hasMatch(s)) {
      return 'Agora são ${horaTexto(DateTime.now())}.';
    }
    if (RegExp(r'que dia (e )?hoje|data de hoje|dia da semana').hasMatch(s)) {
      return 'Hoje é ${dataExtenso(DateTime.now())}.';
    }

    // Memória
    m = RegExp(
            r'^(?:lembre-se que|lembre que|guarde na memoria que|guarde que|memorize que|memorize)\s+(.+)$')
        .firstMatch(s);
    if (m != null) {
      if (!cfg.permMemoria) {
        return 'A memória está desligada. Ative em Config > Permissões.';
      }
      final fato = _trecho(o, m, 1);
      final l = cfg.memoria;
      l.add(fato);
      await cfg.setLista('memoria', l);
      return 'Guardado na memória: "$fato"';
    }
    if (s == 'apagar memoria' || s == 'limpar memoria' || s == 'esqueca tudo') {
      final ok = await _confirmar('Apagar toda a memória do assistente?');
      if (!ok) return 'Cancelado.';
      await cfg.setLista('memoria', <String>[]);
      return 'Memória apagada.';
    }

    // Notas e tarefas
    m = RegExp(r'^(?:nova tarefa|adicionar tarefa|adicione tarefa|tarefa:)\s*(.+)$')
        .firstMatch(s);
    if (m != null) {
      final tx = _trecho(o, m, 1);
      final l = cfg.lista('tarefas');
      l.insert(0, '0|$tx');
      await cfg.setLista('tarefas', l);
      return 'Tarefa adicionada: "$tx"';
    }
    m = RegExp(r'^(?:anote que|anote|anotar|nova nota|nota:)\s*(.+)$')
        .firstMatch(s);
    if (m != null) {
      final tx = _trecho(o, m, 1);
      final l = cfg.lista('notas');
      l.insert(0, tx);
      await cfg.setLista('notas', l);
      return 'Anotado: "$tx"';
    }

    // Habilidades
    m = RegExp(
            r'^(?:ativar modo|ativar habilidade|trocar para modo|modo|habilidade)\s+(.+)$')
        .firstMatch(s);
    if (m != null) {
      final g = m.group(1)!.trim();
      if (g.length >= 3) {
        for (final h in habilidades) {
          final nomeH = semAcento(h.nome.toLowerCase());
          if (h.id == g || nomeH == g || nomeH.contains(g)) {
            cfg.skill = h.id;
            cfg.mudou();
            return 'Habilidade ativa: ${h.emoji} ${h.nome}';
          }
        }
      }
    }

    // Rotinas
    m = RegExp(r'^(?:executar rotina|rodar rotina|iniciar rotina|rotina)\s+(.+)$')
        .firstMatch(s);
    if (m != null) {
      final g = m.group(1)!.trim();
      for (final r in lerRotinas()) {
        final nomeR = semAcento((r['n'] ?? '').toString().toLowerCase());
        if (nomeR == g || nomeR.contains(g)) {
          final linhas = (r['c'] as List)
              .map((e) => e.toString())
              .where((e) => !semAcento(e.toLowerCase()).startsWith('rotina'))
              .toList();
          Future<void>.delayed(const Duration(milliseconds: 600), () {
            if (mounted) executarVarios(linhas);
          });
          return 'Executando a rotina "${r['n']}" (${linhas.length} passos)...';
        }
      }
      if (!s.startsWith('rotina')) {
        return 'Não achei essa rotina. Veja em Ferramentas > Rotinas.';
      }
    }

    // Utilidades
    if (s.length < 40 && s.contains('bateria')) return textoBateria();
    if (s.contains('teste de conexao') ||
        s.contains('teste de internet') ||
        s.contains('teste de rede') ||
        s.contains('diagnostico de rede')) {
      return diagnosticoRede();
    }
    if (RegExp(r'(jogar|rolar|role|jogue) (um )?dado').hasMatch(s)) {
      return '🎲 Deu ${Random().nextInt(6) + 1}!';
    }
    if (s.contains('cara ou coroa')) {
      final lado = Random().nextBool() ? 'cara' : 'coroa';
      return '🪙 Deu $lado!';
    }
    m = RegExp(r'^sort(?:ear|eie)\D*(\d+)\D+(\d+)$').firstMatch(s);
    if (m != null) {
      var a = int.parse(m.group(1)!);
      var b = int.parse(m.group(2)!);
      if (a > b) {
        final tmp = a;
        a = b;
        b = tmp;
      }
      return '🎯 Sorteado: ${a + Random().nextInt(b - a + 1)}';
    }
    if (s.length < 50 &&
        (s.contains('cotacao') ||
            s.contains('dolar hoje') ||
            s.contains('preco do dolar'))) {
      return buscarCotacoes();
    }

    // Localização
    if (RegExp(
            r'^(onde eu estou|onde estou|minha localizacao|qual (e )?minha localizacao|me localize)')
        .hasMatch(s)) {
      try {
        final l = await obterLocal();
        return textoLocal(l);
      } on ErroLocal catch (e) {
        return e.msg;
      } catch (_) {
        return 'Não consegui pegar sua localização agora.';
      }
    }
    if (RegExp(r'(clima|tempo|previsao) aqui|como esta o tempo aqui').hasMatch(s)) {
      return climaAqui();
    }
    m = RegExp(
            r'^(?:onde tem |onde fica |tem |procure |buscar |busque )?(.+?)\s+(?:perto de mim|aqui perto|por aqui|proximo de mim|proxima de mim|mais proximo|mais proxima)$')
        .firstMatch(s);
    if (m != null) {
      if (!cfg.permAcoes) return semPerm;
      return procurarPerto(_trecho(o, m, 1));
    }
    if (RegExp(r'^(compartilhar|mandar|enviar) (a )?(minha )?localizacao')
        .hasMatch(s)) {
      try {
        final l = await obterLocal();
        final msg = 'Estou aqui: ${l.link}';
        final ok = await abrirUrl('https://wa.me/?text=${Uri.encodeComponent(msg)}');
        return ok
            ? 'Escolha o contato no WhatsApp para enviar sua localização.'
            : textoLocal(l);
      } on ErroLocal catch (e) {
        return e.msg;
      } catch (_) {
        return 'Não consegui pegar sua localização agora.';
      }
    }

    // Clima por cidade
    m = RegExp(
            r'^(?:clima|tempo|previsao do tempo|previsao)\s+(?:em|de|para|na|no)\s+(.+)$')
        .firstMatch(s);
    if (m != null) return buscarClima(_trecho(o, m, 1));
    if (s == 'clima' || s == 'previsao do tempo' || s == 'como esta o tempo') {
      if (cfg.cidade.isEmpty) {
        return 'Diga a cidade. Exemplo: clima em Cuiabá. (Ou salve uma cidade padrão em Ferramentas > Clima.)';
      }
      return buscarClima(cfg.cidade);
    }

    // Ações no celular
    m = RegExp(r'^(?:ligar para|ligar|telefonar para)\s+(.+)$').firstMatch(s);
    if (m != null) {
      final digitos = m.group(1)!.replaceAll(RegExp(r'[^0-9+]'), '');
      if (digitos.length >= 8) {
        if (!cfg.permAcoes) return semPerm;
        final ok = await _confirmar('Abrir o discador para $digitos?');
        if (!ok) return 'Cancelado.';
        await abrirUrl('tel:$digitos');
        return 'Abrindo o discador para $digitos. Toque em ligar para confirmar.';
      }
      if (s.startsWith('ligar para')) {
        return 'Para ligar, diga o número. Exemplo: ligar para 65 99999-9999. (Ligar pelo nome da agenda ainda não está disponível.)';
      }
    }

    m = RegExp(
            r'^(whatsapp|zap|sms|mandar mensagem|enviar mensagem|mandar whatsapp|enviar whatsapp|mandar sms|enviar sms)\s+(?:para\s+|pra\s+)?([\d\s\-\(\)\+]{8,})\s*(?:dizendo que|dizendo|falando que|falando|:)?\s*(.*)$')
        .firstMatch(s);
    if (m != null) {
      if (!cfg.permAcoes) return semPerm;
      var numero = m.group(2)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (numero.length == 10 || numero.length == 11) numero = '55$numero';
      final msg = _trecho(o, m, 3);
      final ehSms = m.group(1)!.contains('sms');
      final url = ehSms
          ? 'sms:$numero?body=${Uri.encodeComponent(msg)}'
          : 'https://wa.me/$numero?text=${Uri.encodeComponent(msg)}';
      final ok = await abrirUrl(url);
      final canal = ehSms ? 'o SMS' : 'o WhatsApp';
      return ok
          ? 'Abri $canal com a mensagem pronta. Toque em enviar para confirmar.'
          : 'Não consegui abrir $canal.';
    }

    m = RegExp(
            r'^(?:abrir|abra|abre|iniciar|inicie)\s+(?:o\s+|a\s+|os\s+|as\s+)?(?:app\s+|aplicativo\s+)?(.+)$')
        .firstMatch(s);
    if (m != null && m.group(1)!.length <= 25) {
      if (!cfg.permAcoes) return semPerm;
      return abrirApp(m.group(1)!);
    }

    m = RegExp(r'^(?:pesquisar no google|buscar no google|procure no google|google)\s+(.+)$')
        .firstMatch(s);
    if (m != null) {
      if (!cfg.permAcoes) return semPerm;
      final q = _trecho(o, m, 1);
      final ok = await abrirUrl(
          'https://www.google.com/search?q=${Uri.encodeComponent(q)}');
      return ok ? 'Pesquisando no Google: $q' : 'Não consegui abrir o navegador.';
    }

    m = RegExp(
            r'^(?:rota para|rota ate|como chegar (?:em|ate|na|no|a)|navegar para|navegar ate|me leve para|me leve ate)\s+(.+)$')
        .firstMatch(s);
    if (m != null) {
      if (!cfg.permAcoes) return semPerm;
      final q = _trecho(o, m, 1);
      final ok = await abrirUrl(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(q)}');
      return ok
          ? 'Traçando a rota para $q no Google Maps.'
          : 'Não consegui abrir o Google Maps.';
    }
    m = RegExp(r'^(?:onde fica|mapa de|mostrar no mapa)\s+(.+)$').firstMatch(s);
    if (m != null) {
      if (!cfg.permAcoes) return semPerm;
      final q = _trecho(o, m, 1);
      final ok = await abrirUrl(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
      return ok ? 'Mostrando $q no mapa.' : 'Não consegui abrir o Google Maps.';
    }

    if ((s.contains('alarme') || s.startsWith('me acorde') || s.startsWith('acorde')) &&
        !s.contains('minuto') &&
        !s.contains('segundo')) {
      final hm = RegExp(r'(\d{1,2})\s*(?::|h|horas?)?\s*(\d{2})?').firstMatch(s);
      if (hm != null) {
        final h = int.parse(hm.group(1)!);
        final mi = hm.group(2) != null ? int.parse(hm.group(2)!) : 0;
        if (h <= 23 && mi <= 59) {
          if (!cfg.permAcoes) return semPerm;
          return criarAlarme(h, mi, cfg.nome);
        }
      }
    }

    m = RegExp(
            r'^(?:timer|temporizador|cronometro|me avise em|avise em)(?: de| para)?\s*(\d+)\s*(segundos?|seg|minutos?|min|horas?|h)\b')
        .firstMatch(s);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      final u = m.group(2)!;
      final mult = u.startsWith('s') ? 1 : (u.startsWith('m') ? 60 : 3600);
      if (!cfg.permAcoes) return semPerm;
      return criarTimerNativo(n * mult, cfg.nome);
    }

    return null;
  }

  // ---------- Interface ----------
  void _escolherHabilidade() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: P.mar,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final h in habilidades)
              ListTile(
                leading: Text(h.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(h.nome),
                subtitle: Text(h.instrucao,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                selected: cfg.skill == h.id,
                onTap: () {
                  cfg.skill = h.id;
                  cfg.mudou();
                  Navigator.pop(c);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _copiar(String t) {
    Clipboard.setData(ClipboardData(text: t));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copiado')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cfg,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: P.fundo,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _topo(),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: _msgs.length + (_pensando ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _msgs.length) {
                      return _balao(Msg('⚓ pensando...', false));
                    }
                    return _balao(_msgs[i]);
                  },
                ),
              ),
              _anexoChip(),
              _rodape(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topo() {
    final h = habilidadeAtual();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: P.destaque.withOpacity(0.25))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: P.quente,
            child: const Text('⚓', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: P.claro)),
                GestureDetector(
                  onTap: _escolherHabilidade,
                  child: Text(
                      _ouvindo
                          ? 'ouvindo...'
                          : '${h.emoji} ${h.nome}  ▾',
                      style: TextStyle(fontSize: 13, color: P.destaque)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(cfg.falar ? Icons.volume_up : Icons.volume_off,
                color: P.claro),
            onPressed: () async {
              cfg.falar = !cfg.falar;
              cfg.mudou();
              if (!cfg.falar) await _tts.stop();
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: P.claro),
            color: P.mar,
            onSelected: (v) {
              if (v == 'limpar') _limpar();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                  value: 'limpar', child: Text('Limpar conversa')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balao(Msg m) {
    final user = m.doUsuario;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: user ? P.quente : P.mar,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 4),
            bottomRight: Radius.circular(user ? 4 : 18),
          ),
          border: user
              ? null
              : Border.all(
                  color: (m.erro ? P.alerta : P.destaque).withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.miniatura != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(m.miniatura!,
                      height: 150, fit: BoxFit.cover),
                ),
              ),
            SelectableText(
              m.texto,
              style: TextStyle(
                  fontSize: 15.5,
                  color: user ? P.noite : (m.erro ? P.alerta : P.claro),
                  height: 1.35),
            ),
            if (!user && !m.erro)
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => _copiar(m.texto),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.copy,
                        size: 15, color: P.claro.withOpacity(0.5)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _anexoChip() {
    final a = _anexo;
    if (a == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: P.mar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.destaque.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Text(a.ehImagem ? '🖼️' : '📎'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(a.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _anexo = null),
          ),
        ],
      ),
    );
  }

  Widget _rodape() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
      child: Row(
        children: [
          PopupMenuButton<String>(
            icon: Icon(Icons.add_circle_outline, color: P.claro),
            color: P.mar,
            onSelected: (v) {
              if (v == 'camera') {
                _anexarImagem(ImageSource.camera);
              } else if (v == 'galeria') {
                _anexarImagem(ImageSource.gallery);
              } else {
                _anexarArquivo();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'camera', child: Text('📷 Tirar foto')),
              PopupMenuItem<String>(
                  value: 'galeria', child: Text('🖼️ Escolher imagem')),
              PopupMenuItem<String>(
                  value: 'arquivo', child: Text('📎 PDF, texto, áudio ou vídeo')),
            ],
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onSubmitted: (v) => enviar(v),
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Dê uma ordem, comandante...',
                filled: true,
                fillColor: P.mar,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: _ouvindo ? P.alerta : P.destaque,
            child: IconButton(
              icon: Icon(_ouvindo ? Icons.stop : Icons.mic, color: P.noite),
              onPressed: _microfone,
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 22,
            backgroundColor: P.quente,
            child: IconButton(
              icon: Icon(Icons.send, color: P.noite),
              onPressed: () => enviar(_ctrl.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== biblioteca =====
// Comandos prontos. Ao tocar, o texto vai para a caixa do chat para você completar e enviar.
const Map<String, List<String>> catalogo = {
  '📚 Estudos': [
    'Explique de forma simples, como se eu tivesse 12 anos:',
    'Faça um resumo em tópicos do seguinte texto:',
    'Crie 10 perguntas de prova com gabarito sobre:',
    'Monte um plano de estudos de 4 semanas para:',
    'Crie flashcards (pergunta e resposta) sobre:',
    'Explique a diferença entre estes dois conceitos:',
    'Me ensine passo a passo e depois faça perguntas para testar se entendi:',
    'Corrija minha redação e dê uma nota de 0 a 10 com justificativa:',
    'Faça um mapa mental em tópicos sobre:',
    'Dê 5 exemplos do dia a dia que ilustram:',
    'Crie um cronograma de revisão para a prova de:',
    'Resuma o capítulo do livro (diga o nome do livro e o capítulo):',
  ],
  '💻 Programação': [
    'Escreva um programa completo em Python que:',
    'Explique este código linha por linha:',
    'Encontre o erro neste código e corrija:',
    'Converta este código de Python para JavaScript:',
    'Crie uma função em Dart que:',
    'Explique o que é uma API e dê um exemplo simples',
    'Crie um site simples em HTML e CSS com:',
    'Escreva uma consulta SQL para:',
    'Explique a diferença entre estas duas tecnologias:',
    'Revise este código e sugira melhorias de desempenho e legibilidade:',
    'Crie testes automatizados para esta função:',
    'Me ensine Git do zero com os comandos mais usados',
    'Explique este erro e como resolver:',
    'Crie um bot simples para Telegram que:',
    'Monte um roteiro de estudos para virar programador em 6 meses',
  ],
  '🎮 Games e RPG': [
    'Monte uma build forte para meu personagem no jogo:',
    'Me dê dicas para vencer este chefe difícil (jogo e nome do chefe):',
    'Crie um RPG de texto: você é o mestre do jogo e eu sou o jogador. Comece:',
    'Sugira 10 jogos parecidos com:',
    'Explique as mecânicas básicas deste jogo para iniciantes:',
    'Monte um time Pokémon equilibrado para o jogo/região:',
    'Crie uma aventura de RPG de mesa curta para 4 jogadores no tema:',
    'Crie um personagem de RPG com história, atributos e fraquezas:',
    'Quais são as melhores dicas de velocidade neste jogo?',
    'Crie uma sidequest original para um jogo de fantasia',
    'Explique a história deste jogo sem spoilers:',
    'Crie nomes para um clã ou guilda gamer:',
    'Como melhorar minha mira e meu reflexo em jogos de tiro?',
  ],
  '💼 Trabalho': [
    'Escreva um e-mail profissional pedindo:',
    'Resuma esta reunião em decisões e próximos passos:',
    'Crie uma ata de reunião a partir destas anotações:',
    'Monte um plano de projeto com etapas, prazos e responsáveis para:',
    'Escreva uma resposta educada recusando:',
    'Crie uma apresentação de 10 slides (títulos e tópicos) sobre:',
    'Prepare-me para uma negociação de:',
    'Crie um relatório semanal a partir destes dados:',
    'Escreva uma mensagem de cobrança gentil para:',
    'Liste riscos e como reduzi-los neste projeto:',
    'Crie um checklist de tarefas para:',
    'Dê feedback construtivo sobre este texto do meu colega:',
  ],
  '✍️ Escrita': [
    'Reescreva este texto de forma mais clara e curta:',
    'Crie 10 títulos chamativos para:',
    'Escreva um poema sobre:',
    'Crie uma história curta de mistério com:',
    'Faça uma carta de agradecimento para:',
    'Escreva um discurso de 2 minutos para:',
    'Corrija os erros de português deste texto:',
    'Transforme estas ideias soltas em um texto organizado:',
    'Escreva uma legenda criativa para uma foto de:',
    'Crie um roteiro de vídeo de 1 minuto sobre:',
    'Escreva uma mensagem de aniversário para:',
    'Continue esta história:',
  ],
  '🌐 Idiomas': [
    'Traduza para o inglês:',
    'Traduza para o espanhol:',
    'Traduza para o japonês e mostre a pronúncia:',
    'Corrija minha frase em inglês e explique o erro:',
    'Crie um diálogo em inglês para uma entrevista de emprego',
    'Me ensine 20 palavras úteis de viagem neste idioma:',
    'Seja meu parceiro de conversação em inglês e corrija meus erros',
    'Explique a diferença entre estas duas palavras em inglês:',
    'Crie um plano de 30 dias para aprender o idioma:',
    'Faça um quiz de vocabulário de nível iniciante',
    'Explique este verbo em todos os tempos:',
  ],
  '🧮 Matemática': [
    'Resolva passo a passo:',
    'Explique o que é derivada com exemplos simples',
    'Calcule juros compostos de:',
    'Crie 10 exercícios de equação do 1º grau com gabarito',
    'Explique porcentagem com exemplos do dia a dia',
    'Como calcular média, mediana e moda de:',
    'Explique probabilidade com dados e moedas',
    'Ensine regra de três com 3 exemplos',
    'Explique área e perímetro das principais figuras geométricas',
    'Resolva este problema de lógica:',
    'Explique fatoração e produtos notáveis com exemplos',
  ],
  '🔬 Ciência e curiosidades': [
    'Explique como funciona:',
    'Por que o céu é azul? Explique de forma simples',
    'Conte 10 curiosidades sobre o espaço',
    'Explique a diferença entre vírus e bactéria',
    'Como funciona a internet? Explique do zero',
    'Explique o que é inteligência artificial para um leigo',
    'Conte a história de:',
    'Explique como funciona um motor de carro',
    'Quais foram as maiores invenções da humanidade e por quê?',
    'Explique a teoria da relatividade de forma simples',
    'Fale sobre animais curiosos do Brasil',
    'Explique o que são buracos negros',
  ],
  '🍳 Receitas e cozinha': [
    'Me dê uma receita fácil com estes ingredientes:',
    'Monte um cardápio semanal barato para uma pessoa',
    'Me ensine uma receita de bolo simples sem batedeira',
    'Como substituir este ingrediente em uma receita:',
    'Sugira um jantar rápido de 15 minutos',
    'Quantas porções rendem estes ingredientes?',
    'Como conservar alimentos por mais tempo?',
    'Faça uma lista de compras para o mês',
    'Receita de lanche saudável para levar ao trabalho',
    'Como fazer um churrasco para 10 pessoas (quantidades)?',
    'O que fazer com estas sobras de comida:',
  ],
  '💪 Treino e hábitos': [
    'Monte um treino em casa de 20 minutos sem equipamento',
    'Crie uma rotina de alongamento para quem trabalha sentado',
    'Plano para criar o hábito de beber mais água',
    'Sugira um treino de corrida para iniciantes de 8 semanas',
    'Como melhorar minha postura no dia a dia?',
    'Monte uma rotina de sono para dormir melhor',
    'Sugira exercícios para fazer no escritório',
    'Como criar e manter hábitos novos? Dê um método',
    'Explique a diferença entre treino de força e aeróbico',
    'Crie um desafio de 30 dias de atividade física leve',
  ],
  '💰 Finanças pessoais': [
    'Monte um orçamento mensal com esta renda e estas despesas:',
    'Explique como funcionam o Pix, o cartão de crédito e o boleto',
    'Como sair das dívidas? Monte um plano passo a passo',
    'Explique o que é CDB, Tesouro Direto e poupança',
    'Como montar uma reserva de emergência?',
    'Calcule quanto preciso guardar por mês para chegar em:',
    'Explique juros, inflação e Selic de forma simples',
    'Dicas para economizar no mercado',
    'Compare comprar à vista e parcelar:',
    'O que é score de crédito e como melhorar?',
    'Crie uma planilha de controle de gastos (colunas e fórmulas)',
  ],
  '🧠 Produtividade': [
    'Organize meu dia com estas tarefas e horários:',
    'Explique o método Pomodoro e monte um ciclo para mim',
    'Use a matriz de Eisenhower para priorizar:',
    'Crie uma rotina matinal produtiva',
    'Como parar de procrastinar? Dê passos práticos',
    'Monte metas SMART para:',
    'Faça uma revisão da minha semana com estas anotações:',
    'Crie um sistema simples para organizar arquivos e fotos',
    'Como organizar meus estudos e meu trabalho juntos?',
    'Divida este objetivo grande em pequenas tarefas:',
    'Crie um checklist de mudança de casa',
  ],
  '🛡️ Segurança digital': [
    'Isto é golpe? Analise esta mensagem:',
    'Como criar senhas fortes e lembrar delas?',
    'Explique autenticação em dois fatores e como ativar',
    'Como saber se meu celular foi invadido?',
    'O que fazer se clonaram meu WhatsApp?',
    'Como identificar um site falso de compras?',
    'Dicas para usar Wi-Fi público com segurança',
    'Como proteger crianças na internet?',
    'O que fazer após um vazamento de dados?',
    'Como configurar a privacidade no Instagram e no WhatsApp?',
    'Explique o que é phishing, com exemplos',
  ],
  '✈️ Viagens': [
    'Monte um roteiro de 3 dias em:',
    'O que levar na mala para uma viagem de praia ou de frio:',
    'Dicas para viajar barato para:',
    'Quais documentos preciso para viajar para:',
    'Sugira 5 destinos nacionais para o feriado',
    'Frases úteis para viajar neste idioma:',
    'Compare duas cidades para morar ou visitar:',
    'Monte um checklist antes de viajar',
    'O que fazer em um dia de chuva em:',
    'Como montar um roteiro de viagem de carro?',
  ],
  '🎬 Filmes, séries e música': [
    'Sugira 10 filmes parecidos com:',
    'Recomende séries de suspense curtas',
    'Crie uma playlist para treinar com 15 sugestões de músicas',
    'Monte uma maratona de fim de semana com o tema:',
    'Quais são os melhores animes para iniciantes?',
    'Conte a história da banda ou do artista:',
    'Sugira documentários interessantes sobre:',
    'Resuma o enredo deste livro ou série sem spoilers:',
    'Sugira 5 livros para quem gostou de:',
    'Crie um quiz de cinema com 10 perguntas',
  ],
  '📱 Tecnologia e celular': [
    'Como liberar espaço no meu celular Android?',
    'Como fazer a bateria do celular durar mais?',
    'Meu celular está lento. Faça um passo a passo de diagnóstico',
    'Como fazer backup das fotos e do WhatsApp?',
    'Compare estes dois celulares:',
    'Explique o que são 5G, Wi-Fi 6 e Bluetooth',
    'Como fazer captura e gravação de tela no Android?',
    'Quais apps gratuitos são úteis para produtividade?',
    'Como configurar o controle parental no celular?',
    'Como transferir dados de um celular para outro?',
    'Explique as permissões de apps e quais negar',
  ],
  '🏠 Casa e dia a dia': [
    'Crie uma rotina de limpeza semanal da casa',
    'Como tirar mancha de:',
    'Dicas para economizar energia e água em casa',
    'Como organizar um guarda-roupa pequeno?',
    'Monte uma lista de compras para casa nova',
    'Como cuidar de plantas em apartamento?',
    'Faça um cronograma de tarefas domésticas para dividir entre moradores',
    'Como consertar uma torneira que goteja? Passo a passo',
    'Como escolher um bom colchão?',
    'Ideias de decoração barata para:',
    'Como lavar roupa sem estragar:',
  ],
  '🎓 Carreira e currículo': [
    'Monte meu currículo com estas informações:',
    'Escreva uma carta de apresentação para a vaga de:',
    'Simule uma entrevista de emprego para a vaga de:',
    'Quais habilidades preciso para trabalhar com:',
    'Como pedir aumento? Prepare meus argumentos',
    'Crie um perfil profissional para o LinkedIn:',
    'Como me preparar para um concurso público?',
    'Perguntas difíceis de entrevista e boas respostas',
    'Como mudar de carreira aos 30 anos?',
    'Monte um plano de carreira de 5 anos em:',
    'Como lidar com um chefe difícil?',
  ],
  '📊 Planilhas (Excel e Sheets)': [
    'Crie uma fórmula de Excel que:',
    'Explique PROCV, XLOOKUP e ÍNDICE+CORRESP com exemplos',
    'Monte uma planilha de controle financeiro (colunas e fórmulas)',
    'Como fazer tabela dinâmica passo a passo?',
    'Que gráfico é o melhor para estes dados:',
    'Como remover duplicados e limpar dados?',
    'Escreva um script do Google Sheets que:',
    'Explique a fórmula SE com várias condições',
    'Crie uma planilha de estoque com alerta de estoque mínimo',
    'Como somar valores por critério (SOMASE e SOMASES)?',
    'Crie uma macro VBA que:',
    'Como usar formatação condicional para destacar valores acima da média?',
  ],
  '🎨 Criatividade e ideias': [
    'Dê 20 ideias de nome para:',
    'Crie um slogan para:',
    'Ideias de presente para esta pessoa e este orçamento:',
    'Sugira ideias de negócio com pouco dinheiro',
    'Dê ideias de conteúdo para redes sociais sobre:',
    'Crie um personagem original para uma história:',
    'Sugira temas para uma festa de aniversário',
    'Brainstorm: ideias para resolver este problema:',
    'Descreva 3 conceitos de identidade visual (cores e estilo) para a marca:',
    'Ideias de hobbies novos para aprender em casa',
    'Crie um enigma ou charada com resposta',
  ],
  '🗣️ Conversa e diversão': [
    'Conte uma piada boa',
    'Me faça um quiz de conhecimentos gerais com 10 perguntas',
    'Vamos jogar 20 perguntas: eu penso em algo e você adivinha',
    'Crie uma charada para eu resolver',
    'Me dê um desafio de lógica',
    'Conte uma curiosidade aleatória',
    'Vamos jogar forca',
    'Me faça perguntas para nos conhecermos melhor',
    'Vamos conversar sobre um assunto aleatório',
    'Crie um trava-língua novo',
    'Jogue comigo: adivinhe o filme pelas minhas dicas',
  ],
  '📸 Fotos, PDF e arquivos': [
    '(Anexe uma foto) O que é isto? Descreva em detalhes',
    '(Anexe um PDF) Resuma este documento em 10 tópicos',
    '(Anexe uma foto de texto) Transcreva o texto desta imagem',
    '(Anexe uma foto de exercício) Resolva e explique',
    '(Anexe um PDF) Quais são os pontos mais importantes e os prazos?',
    '(Anexe um áudio) Transcreva e resuma este áudio',
    '(Anexe um vídeo) Descreva o que acontece neste vídeo',
    '(Anexe uma foto de planta ou inseto) Que espécie é esta?',
    '(Anexe um cardápio) Qual prato você recomenda?',
    '(Anexe uma foto de tabela) Converta para texto organizado',
    '(Anexe um contrato) Explique em linguagem simples as cláusulas principais',
  ],
  '🧘 Bem-estar': [
    'Guie uma respiração para acalmar em 3 minutos',
    'Sugira uma meditação curta para antes de dormir',
    'Crie uma rotina de autocuidado para a semana',
    'Como lidar com estresse no trabalho?',
    'Vamos fazer um diário de gratidão juntos',
    'Como organizar a mente quando estou sobrecarregado?',
    'Ideias para relaxar sem usar o celular',
    'Como melhorar minha concentração?',
    'Me ajude a pensar sobre uma decisão difícil:',
    'Sugira atividades para um dia de folga',
  ],
  '📈 Marketing e redes sociais': [
    'Crie um calendário de posts de 7 dias para:',
    'Escreva uma legenda e hashtags para:',
    'Monte uma estratégia para crescer no Instagram ou TikTok com o tema:',
    'Crie um roteiro de Reels de 30 segundos sobre:',
    'Escreva um texto de venda para o produto:',
    'Crie uma bio de perfil profissional para:',
    'Ideias de promoção para pequeno negócio',
    'Como responder uma avaliação negativa de cliente?',
    'Monte um funil simples de vendas pelo WhatsApp',
    'Sugira nomes e identidade visual para a marca:',
  ],
  '🧾 Burocracia e documentos': [
    'Como tirar segunda via deste documento? Passo a passo:',
    'Explique meus direitos como consumidor neste caso:',
    'Escreva um modelo de carta de reclamação para:',
    'Escreva um modelo de declaração simples para:',
    'Como funciona o MEI? Explique do zero',
    'Quais documentos preciso para abrir conta ou alugar um imóvel?',
    'Explique em linguagem simples este termo jurídico:',
    'Como contestar uma multa de trânsito?',
    'Como funciona a aposentadoria pelo INSS? Explique o básico',
    'Escreva um modelo de recibo de pagamento',
  ],
  '🚗 Carros e motos': [
    'O que significa esta luz no painel do carro?',
    'Checklist de manutenção preventiva do carro',
    'Como economizar combustível?',
    'Como trocar um pneu furado passo a passo?',
    'Compare estes dois carros para uso na cidade:',
    'Como funciona o financiamento de veículo?',
    'Dicas para passar na prova prática de direção',
    'Barulho estranho no carro: possíveis causas:',
    'Como cuidar da bateria do carro?',
    'Quando trocar o óleo e o filtro?',
  ],
  '🌱 Pets e jardim': [
    'Como adestrar um cachorro filhote?',
    'Quais alimentos são proibidos para cães e gatos?',
    'Rotina de cuidados para gato em apartamento',
    'Como montar uma horta em casa?',
    'Quais plantas são fáceis de cuidar?',
    'Como fazer compostagem em casa?',
    'Como cuidar de um aquário para iniciantes?',
    'Dicas para o cachorro parar de latir',
    'Como escolher uma raça de cachorro para meu estilo de vida?',
    'Que cuidados devo ter com a saúde do meu pet (e o que perguntar ao veterinário)?',
  ],
  '⚽ Esportes': [
    'Explique as regras de:',
    'Monte uma escalação 4-3-3 para meu time ideal',
    'Resuma a história da Copa do Mundo',
    'Dicas para melhorar no futebol, vôlei ou basquete:',
    'Explique impedimento com exemplos',
    'Crie uma tabela de campeonato entre amigos',
    'Quais esportes são bons para iniciantes?',
    'Crie um quiz de esportes com 10 perguntas',
    'Explique a diferença entre estas modalidades:',
  ],
  '🧑‍🏫 Para pais e filhos': [
    'Crie atividades educativas para uma criança de (idade):',
    'Explique de forma divertida para crianças:',
    'Conte uma história para dormir sobre:',
    'Ideias de brincadeiras sem tela',
    'Ajude com a lição de casa: explique como ensinar:',
    'Como conversar com adolescentes sobre:',
    'Crie uma tabela de tarefas e recompensas para crianças',
    'Sugira festas de aniversário infantis baratas',
  ],
  '🧪 Testes e quizzes': [
    'Crie um quiz de 10 perguntas sobre:',
    'Faça um simulado de prova de múltipla escolha sobre:',
    'Teste meu conhecimento de inglês (nível básico)',
    'Crie um teste de personalidade divertido',
    'Faça perguntas de lógica de nível médio',
    'Crie palavras cruzadas simples sobre:',
    'Jogo de verdadeiro ou falso sobre:',
    'Quiz de geografia do Brasil',
    'Quiz de história geral',
    'Quiz de tecnologia',
  ],
};

int totalCatalogo() {
  var n = 0;
  for (final l in catalogo.values) {
    n += l.length;
  }
  return n;
}

class BibliotecaPage extends StatefulWidget {
  const BibliotecaPage({super.key});

  @override
  State<BibliotecaPage> createState() => _BibliotecaPageState();
}

class _BibliotecaPageState extends State<BibliotecaPage> {
  final TextEditingController _busca = TextEditingController();
  String _cat = 'Todas';

  List<MapEntry<String, String>> _filtrados() {
    final q = semAcento(_busca.text.toLowerCase().trim());
    final out = <MapEntry<String, String>>[];
    catalogo.forEach((cat, lista) {
      if (_cat != 'Todas' && _cat != cat) return;
      for (final it in lista) {
        if (q.isEmpty ||
            semAcento(it.toLowerCase()).contains(q) ||
            semAcento(cat.toLowerCase()).contains(q)) {
          out.add(MapEntry<String, String>(cat, it));
        }
      }
    });
    return out;
  }

  String _tema() {
    final b = _busca.text.trim();
    if (b.isNotEmpty) return b;
    if (_cat != 'Todas') return _cat;
    return 'qualquer assunto do dia a dia';
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cfg,
      builder: (context, _) {
        final itens = _filtrados();
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: P.fundo,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text('Biblioteca',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: P.claro)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Text(
                      '${totalCatalogo()} comandos prontos · toque para usar no chat',
                      style: TextStyle(color: P.destaque)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _busca,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar (ex.: excel, receita, viagem)...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: P.mar,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    children: [
                      for (final c in <String>['Todas', ...catalogo.keys])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _cat == c,
                            onSelected: (_) => setState(() => _cat = c),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: itens.isEmpty
                              ? null
                              : () {
                                  final e = itens[Random().nextInt(itens.length)];
                                  chatComando(context, preencher: e.value);
                                },
                          child: const Text('🎲 Surpreenda-me'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: P.destaque,
                              foregroundColor: P.noite),
                          onPressed: () => chatComando(context,
                              enviar:
                                  'Crie uma lista numerada de 25 pedidos diferentes e úteis que eu posso fazer a você sobre "${_tema()}". Cada item deve ser uma frase curta, pronta para copiar e usar.'),
                          child: const Text('✨ Gerar mais com a IA'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: itens.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                'Nada encontrado. Toque em "Gerar mais com a IA" para criar ideias sobre "${_tema()}".',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: P.claro.withOpacity(0.7))),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          itemCount: itens.length,
                          itemBuilder: (_, i) {
                            final e = itens[i];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: P.mar,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text(e.value,
                                    style: TextStyle(color: P.claro)),
                                subtitle: _cat == 'Todas'
                                    ? Text(e.key,
                                        style: TextStyle(
                                            fontSize: 11, color: P.destaque))
                                    : null,
                                trailing: IconButton(
                                  icon: Icon(Icons.copy,
                                      size: 18, color: P.claro.withOpacity(0.6)),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: e.value));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Copiado')));
                                  },
                                ),
                                onTap: () =>
                                    chatComando(context, preencher: e.value),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===== ferramentas =====
// ---------- Peças visuais reutilizáveis ----------
Widget telaPadrao(String titulo, Widget corpo, {List<Widget>? acoes}) {
  return ListenableBuilder(
    listenable: cfg,
    builder: (context, _) => Scaffold(
      backgroundColor: P.noite,
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: P.mar,
        foregroundColor: P.claro,
        actions: acoes,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: P.fundo,
          ),
        ),
        child: SafeArea(child: corpo),
      ),
    ),
  );
}

Widget caixa(Widget filho) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: P.mar,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: P.destaque.withOpacity(0.25)),
    ),
    child: filho,
  );
}

InputDecoration campo(String dica) {
  return InputDecoration(
    hintText: dica,
    filled: true,
    fillColor: P.noite.withOpacity(0.6),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

Widget botao(String texto, VoidCallback? aoTocar) {
  return FilledButton(
    style: FilledButton.styleFrom(
        backgroundColor: P.destaque, foregroundColor: P.noite),
    onPressed: aoTocar,
    child: Text(texto),
  );
}

Widget titulo2(String t) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t,
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: P.claro)),
  );
}

Widget resultadoBox(String t) {
  if (t.isEmpty) return const SizedBox.shrink();
  return caixa(SelectableText(t,
      style: TextStyle(color: P.claro, height: 1.4, fontSize: 15)));
}

void aviso(BuildContext c, String t) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));
}

void copiarTexto(BuildContext c, String t) {
  Clipboard.setData(ClipboardData(text: t));
  aviso(c, 'Copiado');
}

void abrirPagina(BuildContext c, Widget w) {
  Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w));
}

Future<bool> confirmarDialogo(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      backgroundColor: P.mar,
      title: const Text('Confirmar'),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar')),
      ],
    ),
  );
  return r == true;
}

// Ajuda para páginas que rodam algo e mostram o resultado
mixin ResultadoMixin<T extends StatefulWidget> on State<T> {
  String res = '';
  bool carregando = false;

  Future<void> rodar(Future<String> Function() f) async {
    setState(() {
      carregando = true;
      res = '';
    });
    String r;
    try {
      r = await f();
    } catch (_) {
      r = 'Algo deu errado. Tente de novo.';
    }
    if (!mounted) return;
    setState(() {
      carregando = false;
      res = r;
    });
  }

  Widget areaResultado() {
    if (carregando) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return resultadoBox(res);
  }
}

Future<String> comLocal(Future<String> Function(LocalInfo l) f) async {
  try {
    final l = await obterLocal();
    return await f(l);
  } on ErroLocal catch (e) {
    return e.msg;
  } catch (_) {
    return 'Não consegui pegar sua localização agora.';
  }
}

// ---------- Lista de ferramentas ----------
class Ferr {
  final String emoji;
  final String nome;
  final String desc;
  final Widget Function() pagina;
  Ferr(this.emoji, this.nome, this.desc, this.pagina);
}

class FerramentasPage extends StatelessWidget {
  const FerramentasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final itens = <Ferr>[
      Ferr('📍', 'Localização', 'Onde estou e o que tem perto', () => const LocalPage()),
      Ferr('🌤️', 'Clima', 'Previsão de qualquer cidade', () => const ClimaPage()),
      Ferr('💱', 'Cotações', 'Dólar, euro e bitcoin', () => const CotacoesPage()),
      Ferr('📝', 'Notas', 'Anotações rápidas', () => const ListaPage('notas')),
      Ferr('✅', 'Tarefas', 'Lista de afazeres', () => const ListaPage('tarefas')),
      Ferr('🧠', 'Memória', 'O que o assistente lembra', () => const ListaPage('memoria')),
      Ferr('⚡', 'Rotinas', 'Vários comandos de uma vez', () => const RotinasPage()),
      Ferr('⏰', 'Alarme e timer', 'Despertador e contagem', () => const AlarmePage()),
      Ferr('🧮', 'Calculadora', 'Contas e porcentagens', () => const CalcPage()),
      Ferr('🔄', 'Conversor', 'Unidades e temperatura', () => const ConversorPage()),
      Ferr('📅', 'Datas', 'Dias entre datas e idade', () => const DatasPage()),
      Ferr('🎲', 'Sorteios', 'Dado, moeda e times', () => const SorteioPage()),
      Ferr('🔐', 'Senhas', 'Gerar senhas fortes', () => const SenhaPage()),
      Ferr('🛡️', 'Anti-golpe', 'Analisar mensagens', () => const GolpePage()),
      Ferr('🔋', 'Celular', 'Bateria e internet', () => const DiagPage()),
      Ferr('📱', 'Apps', 'Abrir apps rápido', () => const AppsPage()),
    ];
    return ListenableBuilder(
      listenable: cfg,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: P.fundo,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text('Ferramentas',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: P.claro)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Text('Tudo grátis. Várias funcionam sem internet.',
                    style: TextStyle(color: P.destaque)),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: itens.length,
                  itemBuilder: (_, i) {
                    final f = itens[i];
                    return Material(
                      color: P.mar,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => abrirPagina(context, f.pagina()),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(f.emoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(height: 6),
                              Text(f.nome,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: P.claro)),
                              Text(f.desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: P.claro.withOpacity(0.65))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Notas, Tarefas e Memória ----------
class ListaPage extends StatefulWidget {
  final String modo; // notas, tarefas ou memoria
  const ListaPage(this.modo, {super.key});

  @override
  State<ListaPage> createState() => _ListaPageState();
}

class _ListaPageState extends State<ListaPage> {
  final TextEditingController _ctrl = TextEditingController();
  List<String> _itens = <String>[];

  String get _titulo {
    if (widget.modo == 'notas') return 'Notas';
    if (widget.modo == 'tarefas') return 'Tarefas';
    return 'Memória';
  }

  @override
  void initState() {
    super.initState();
    _itens = cfg.lista(widget.modo);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    await cfg.setLista(widget.modo, _itens);
    if (mounted) setState(() {});
  }

  void _adicionar() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    if (widget.modo == 'tarefas') {
      _itens.insert(0, '0|$t');
    } else if (widget.modo == 'notas') {
      _itens.insert(0, t);
    } else {
      _itens.add(t);
    }
    _salvar();
  }

  bool _feita(String s) => s.startsWith('1|');

  String _texto(String s) {
    if (widget.modo == 'tarefas' && s.length >= 2 && s[1] == '|') {
      return s.substring(2);
    }
    return s;
  }

  void _alternar(int i) {
    final s = _itens[i];
    _itens[i] = _feita(s) ? '0|${_texto(s)}' : '1|${_texto(s)}';
    _salvar();
  }

  void _remover(int i) {
    _itens.removeAt(i);
    _salvar();
  }

  @override
  Widget build(BuildContext context) {
    final tarefas = widget.modo == 'tarefas';
    final dica = tarefas
        ? 'Nova tarefa...'
        : (widget.modo == 'notas'
            ? 'Nova nota...'
            : 'Algo para o assistente lembrar...');
    return telaPadrao(
      _titulo,
      Column(
        children: [
          if (widget.modo == 'memoria')
            SwitchListTile(
              value: cfg.permMemoria,
              activeColor: P.destaque,
              onChanged: (v) {
                cfg.permMemoria = v;
                cfg.mudou();
                setState(() {});
              },
              title: const Text('Usar a memória nas respostas'),
              subtitle: const Text('Você também pode dizer: lembre-se que ...'),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: campo(dica),
                    onSubmitted: (_) => _adicionar(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _adicionar,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: _itens.isEmpty
                ? Center(
                    child: Text('Nada por aqui ainda.',
                        style: TextStyle(color: P.claro.withOpacity(0.6))),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _itens.length,
                    itemBuilder: (_, i) {
                      final s = _itens[i];
                      final feita = tarefas && _feita(s);
                      final t = _texto(s);
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: P.mar,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            if (tarefas)
                              Checkbox(
                                value: feita,
                                activeColor: P.destaque,
                                onChanged: (_) => _alternar(i),
                              ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 6),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    color: P.claro.withOpacity(feita ? 0.5 : 1),
                                    decoration: feita
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.modo == 'notas')
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Pedir à IA',
                                icon: Icon(Icons.auto_awesome,
                                    size: 20, color: P.quente),
                                onPressed: () => chatComando(context,
                                    enviar: 'Organize e resuma esta nota:\n$t'),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.copy,
                                  size: 19, color: P.claro.withOpacity(0.6)),
                              onPressed: () => copiarTexto(context, t),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.delete_outline,
                                  size: 21, color: P.alerta),
                              onPressed: () => _remover(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------- Rotinas ----------
class RotinasPage extends StatefulWidget {
  const RotinasPage({super.key});

  @override
  State<RotinasPage> createState() => _RotinasPageState();
}

class _RotinasPageState extends State<RotinasPage> {
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _cmds = TextEditingController();
  List<Map<String, dynamic>> _rotinas = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _rotinas = lerRotinas();
  }

  @override
  void dispose() {
    _nome.dispose();
    _cmds.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    await salvarRotinas(_rotinas);
    if (mounted) setState(() {});
  }

  void _criar() {
    final n = _nome.text.trim();
    final c = _cmds.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (n.isEmpty || c.isEmpty) {
      aviso(context, 'Dê um nome e pelo menos um comando.');
      return;
    }
    _rotinas.add(<String, dynamic>{'n': n, 'c': c});
    _nome.clear();
    _cmds.clear();
    _salvar();
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Rotinas',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
              'Uma rotina executa vários comandos em sequência no chat. Para rodar por voz, diga: rotina bom dia.',
              style: TextStyle(color: P.claro.withOpacity(0.8))),
          for (int i = 0; i < _rotinas.length; i++)
            caixa(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚡ ${_rotinas[i]['n']}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: P.claro)),
                const SizedBox(height: 4),
                Text((_rotinas[i]['c'] as List).map((e) => '• $e').join('\n'),
                    style: TextStyle(color: P.claro.withOpacity(0.8))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    botao('▶ Executar', () {
                      final cmds = (_rotinas[i]['c'] as List)
                          .map((e) => e.toString())
                          .toList();
                      chatComando(context, varios: cmds);
                    }),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        _rotinas.removeAt(i);
                        _salvar();
                      },
                      child: Text('Excluir', style: TextStyle(color: P.alerta)),
                    ),
                  ],
                ),
              ],
            )),
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Nova rotina'),
              TextField(controller: _nome, decoration: campo('Nome (ex.: Boa noite)')),
              const SizedBox(height: 8),
              TextField(
                controller: _cmds,
                minLines: 3,
                maxLines: 6,
                decoration: campo(
                    'Um comando por linha. Ex.:\nque horas são\nclima\nbateria'),
              ),
              const SizedBox(height: 8),
              botao('Salvar rotina', _criar),
            ],
          )),
        ],
      ),
    );
  }
}

// ---------- Clima ----------
class ClimaPage extends StatefulWidget {
  const ClimaPage({super.key});

  @override
  State<ClimaPage> createState() => _ClimaPageState();
}

class _ClimaPageState extends State<ClimaPage> with ResultadoMixin<ClimaPage> {
  late final TextEditingController _ctrl =
      TextEditingController(text: cfg.cidade);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Clima',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ctrl,
                decoration: campo('Cidade (ex.: Campo Grande)'),
                onSubmitted: (_) => rodar(() => buscarClima(_ctrl.text)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  botao('Ver clima', () => rodar(() => buscarClima(_ctrl.text))),
                  botao('📍 Minha localização', () => rodar(climaAqui)),
                  OutlinedButton(
                    onPressed: () {
                      cfg.cidade = _ctrl.text.trim();
                      cfg.mudou();
                      aviso(context, 'Cidade padrão salva.');
                    },
                    child: const Text('Salvar como padrão'),
                  ),
                ],
              ),
            ],
          )),
          areaResultado(),
        ],
      ),
    );
  }
}

// ---------- Cotações ----------
class CotacoesPage extends StatefulWidget {
  const CotacoesPage({super.key});

  @override
  State<CotacoesPage> createState() => _CotacoesPageState();
}

class _CotacoesPageState extends State<CotacoesPage>
    with ResultadoMixin<CotacoesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) rodar(buscarCotacoes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Cotações',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          areaResultado(),
          Align(
            alignment: Alignment.centerLeft,
            child: botao('🔄 Atualizar', () => rodar(buscarCotacoes)),
          ),
        ],
      ),
    );
  }
}

// ---------- Localização ----------
class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> with ResultadoMixin<LocalPage> {
  static const List<String> _lugares = [
    'Farmácia',
    'Mercado',
    'Posto de gasolina',
    'Restaurante',
    'Padaria',
    'Hospital',
    'Pronto-socorro',
    'Banco',
    'Caixa eletrônico',
    'Estacionamento',
    'Pet shop',
    'Academia',
    'Hotel',
    'Lanchonete',
    'Borracharia',
    'Lava-jato',
    'Delegacia',
    'Shopping',
  ];

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Localização',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: cfg.permLocal,
                activeColor: P.destaque,
                title: const Text('Modo de localização'),
                subtitle: const Text(
                    'Só usa o GPS quando você pedir. Nada é enviado sem você mandar.'),
                onChanged: (v) async {
                  cfg.permLocal = v;
                  cfg.mudou();
                  setState(() {});
                  if (v) {
                    try {
                      final p = await Geolocator.checkPermission();
                      if (p == LocationPermission.denied) {
                        await Geolocator.requestPermission();
                      }
                    } catch (_) {}
                  }
                },
              ),
              if (cfg.localTexto.isNotEmpty)
                Text('Último local: ${cfg.localTexto}',
                    style: TextStyle(color: P.claro.withOpacity(0.7), fontSize: 13)),
            ],
          )),
          caixa(Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              botao('📍 Onde estou?',
                  () => rodar(() => comLocal((l) async => textoLocal(l)))),
              botao('🌤️ Clima aqui', () => rodar(climaAqui)),
              botao(
                  '🗺️ Abrir no mapa',
                  () => rodar(() => comLocal((l) async {
                        final ok = await abrirUrl(l.link);
                        return ok
                            ? 'Abrindo o mapa na sua posição.'
                            : 'Não consegui abrir o mapa.';
                      }))),
              botao(
                  '💬 Enviar no WhatsApp',
                  () => rodar(() => comLocal((l) async {
                        final msg = 'Estou aqui: ${l.link}';
                        final ok = await abrirUrl(
                            'https://wa.me/?text=${Uri.encodeComponent(msg)}');
                        return ok
                            ? 'Escolha o contato no WhatsApp para enviar.'
                            : textoLocal(l);
                      }))),
              botao(
                  '📋 Copiar link',
                  () => rodar(() => comLocal((l) async {
                        await Clipboard.setData(ClipboardData(text: l.link));
                        return 'Link copiado:\n${l.link}';
                      }))),
            ],
          )),
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Perto de mim (abre no Google Maps)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final x in _lugares)
                    ActionChip(
                      label: Text(x),
                      onPressed: () => rodar(() => procurarPerto(x)),
                    ),
                ],
              ),
            ],
          )),
          areaResultado(),
        ],
      ),
    );
  }
}

// ---------- Calculadora ----------
class CalcPage extends StatefulWidget {
  const CalcPage({super.key});

  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  static const List<String> _teclas = [
    '7', '8', '9', '÷',
    '4', '5', '6', '×',
    '1', '2', '3', '-',
    '0', ',', '(', ')',
    '+', '^', '%', '⌫',
  ];

  final TextEditingController _ctrl = TextEditingController();
  String _res = '';
  final List<String> _hist = <String>[];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _prep(String e) {
    return e.replaceAllMapped(
      RegExp(r'(\d+(?:[.,]\d+)?)\s*%\s*de\s*(\d+(?:[.,]\d+)?)'),
      (m) => '(${m.group(1)}/100*${m.group(2)})',
    );
  }

  void _calcular() {
    final e = _ctrl.text.trim();
    if (e.isEmpty) return;
    try {
      final v = Calc.avaliar(_prep(e));
      final t = formatarNumero(v);
      setState(() {
        _res = t;
        _hist.insert(0, '$e = $t');
        if (_hist.length > 15) _hist.removeLast();
      });
    } catch (_) {
      setState(() => _res = 'Expressão inválida');
    }
  }

  void _toque(String t) {
    if (t == 'C') {
      _ctrl.clear();
      _res = '';
    } else if (t == '⌫') {
      if (_ctrl.text.isNotEmpty) {
        _ctrl.text = _ctrl.text.substring(0, _ctrl.text.length - 1);
      }
    } else {
      _ctrl.text = _ctrl.text + t;
    }
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    setState(() {});
  }

  Widget _tecla(String t) {
    return Material(
      color: P.mar,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toque(t),
        child: Center(
          child: Text(t, style: TextStyle(fontSize: 22, color: P.claro)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Calculadora',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _ctrl,
            decoration: campo('Ex.: 12*(3+4)  ou  20% de 350'),
            style: const TextStyle(fontSize: 20),
            onSubmitted: (_) => _calcular(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(_res.isEmpty ? ' ' : '= $_res',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: P.destaque)),
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.7,
            children: [for (final t in _teclas) _tecla(t)],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: () => _toque('C'), child: const Text('Limpar')),
              ),
              const SizedBox(width: 8),
              Expanded(child: botao('=  Calcular', _calcular)),
            ],
          ),
          if (_hist.isNotEmpty)
            caixa(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titulo2('Histórico'),
                for (final h in _hist)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(h, style: TextStyle(color: P.claro.withOpacity(0.8))),
                  ),
              ],
            )),
        ],
      ),
    );
  }
}

// ---------- Conversor de unidades ----------
const Map<String, Map<String, double>> _fatores = {
  'Comprimento': {
    'mm': 0.001,
    'cm': 0.01,
    'm': 1,
    'km': 1000,
    'polegada': 0.0254,
    'pé': 0.3048,
    'jarda': 0.9144,
    'milha': 1609.344,
  },
  'Massa': {
    'mg': 0.000001,
    'g': 0.001,
    'kg': 1,
    'tonelada': 1000,
    'onça': 0.028349523,
    'libra': 0.45359237,
  },
  'Volume': {
    'ml': 0.001,
    'l': 1,
    'm³': 1000,
    'xícara (240 ml)': 0.24,
    'colher de sopa (15 ml)': 0.015,
    'galão (EUA)': 3.785411784,
  },
  'Velocidade': {
    'm/s': 1,
    'km/h': 0.2777777778,
    'mph': 0.44704,
    'nó': 0.5144444444,
  },
  'Dados': {
    'B': 1,
    'KB': 1024,
    'MB': 1048576,
    'GB': 1073741824,
    'TB': 1099511627776,
  },
  'Tempo': {
    'segundo': 1,
    'minuto': 60,
    'hora': 3600,
    'dia': 86400,
    'semana': 604800,
  },
  'Área': {
    'm²': 1,
    'km²': 1000000,
    'hectare': 10000,
    'acre': 4046.8564224,
    'pé²': 0.09290304,
  },
  'Temperatura': {
    '°C': 1,
    '°F': 1,
    'K': 1,
  },
};

double converterUnidade(String cat, String de, String para, double v) {
  if (cat == 'Temperatura') {
    double c;
    if (de == '°C') {
      c = v;
    } else if (de == '°F') {
      c = (v - 32) * 5 / 9;
    } else {
      c = v - 273.15;
    }
    if (para == '°C') return c;
    if (para == '°F') return c * 9 / 5 + 32;
    return c + 273.15;
  }
  final f = _fatores[cat]!;
  return v * f[de]! / f[para]!;
}

class ConversorPage extends StatefulWidget {
  const ConversorPage({super.key});

  @override
  State<ConversorPage> createState() => _ConversorPageState();
}

class _ConversorPageState extends State<ConversorPage> {
  String _cat = 'Comprimento';
  String _de = 'm';
  String _para = 'km';
  final TextEditingController _ctrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<String> get _unid => _fatores[_cat]!.keys.toList();

  void _trocarCat(String c) {
    setState(() {
      _cat = c;
      final u = _fatores[c]!.keys.toList();
      _de = u[0];
      _para = u.length > 1 ? u[1] : u[0];
    });
  }

  String _resultado() {
    final v = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    if (v == null) return '';
    final r = converterUnidade(_cat, _de, _para, v);
    return '${formatarNumero(v)} $_de = ${formatarNumero(r)} $_para';
  }

  Widget _drop(String valor, void Function(String) mudou) {
    return DropdownButton<String>(
      value: valor,
      isExpanded: true,
      dropdownColor: P.mar,
      items: [
        for (final u in _unid)
          DropdownMenuItem<String>(value: u, child: Text(u)),
      ],
      onChanged: (v) {
        if (v != null) mudou(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Conversor',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in _fatores.keys)
                ChoiceChip(
                  label: Text(c),
                  selected: _cat == c,
                  onSelected: (_) => _trocarCat(c),
                ),
            ],
          ),
          const SizedBox(height: 10),
          caixa(Column(
            children: [
              TextField(
                controller: _ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: campo('Valor'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _drop(_de, (v) => setState(() => _de = v))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward),
                  ),
                  Expanded(child: _drop(_para, (v) => setState(() => _para = v))),
                ],
              ),
            ],
          )),
          resultadoBox(_resultado()),
        ],
      ),
    );
  }
}

// ---------- Datas ----------
class DatasPage extends StatefulWidget {
  const DatasPage({super.key});

  @override
  State<DatasPage> createState() => _DatasPageState();
}

class _DatasPageState extends State<DatasPage> {
  DateTime _a = DateTime.now();
  DateTime _b = DateTime.now().add(const Duration(days: 30));
  DateTime _nasc = DateTime(2000, 1, 1);

  String _fmt(DateTime d) => '${dois(d.day)}/${dois(d.month)}/${d.year}';

  Future<DateTime?> _escolher(DateTime inicial) {
    return showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
  }

  String _entreDatas() {
    final dias = _b.difference(_a).inDays;
    final abs = dias.abs();
    final sem = abs ~/ 7;
    final resto = abs % 7;
    final sentido = dias >= 0 ? 'depois' : 'antes';
    return '$abs dias ($sem semanas e $resto dias)\nA segunda data é $sentido da primeira.';
  }

  String _idade() {
    final h = DateTime.now();
    int anos = h.year - _nasc.year;
    int meses = h.month - _nasc.month;
    int dias = h.day - _nasc.day;
    if (dias < 0) {
      meses -= 1;
      dias += DateTime(h.year, h.month, 0).day;
    }
    if (meses < 0) {
      anos -= 1;
      meses += 12;
    }
    final total = h.difference(_nasc).inDays;
    final hoje = DateTime(h.year, h.month, h.day);
    var prox = DateTime(h.year, _nasc.month, _nasc.day);
    if (prox.isBefore(hoje)) prox = DateTime(h.year + 1, _nasc.month, _nasc.day);
    final faltam = prox.difference(hoje).inDays;
    return '$anos anos, $meses meses e $dias dias\n($total dias de vida)\nPróximo aniversário em $faltam dias.';
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Datas',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Dias entre duas datas'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final d = await _escolher(_a);
                      if (d != null) setState(() => _a = d);
                    },
                    child: Text('De: ${_fmt(_a)}'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final d = await _escolher(_b);
                      if (d != null) setState(() => _b = d);
                    },
                    child: Text('Até: ${_fmt(_b)}'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(_entreDatas(), style: TextStyle(color: P.claro, height: 1.4)),
            ],
          )),
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Idade'),
              OutlinedButton(
                onPressed: () async {
                  final d = await _escolher(_nasc);
                  if (d != null) setState(() => _nasc = d);
                },
                child: Text('Nascimento: ${_fmt(_nasc)}'),
              ),
              const SizedBox(height: 10),
              Text(_idade(), style: TextStyle(color: P.claro, height: 1.4)),
            ],
          )),
        ],
      ),
    );
  }
}

// ---------- Sorteios ----------
class SorteioPage extends StatefulWidget {
  const SorteioPage({super.key});

  @override
  State<SorteioPage> createState() => _SorteioPageState();
}

class _SorteioPageState extends State<SorteioPage> {
  final Random _r = Random();
  String _res = '';
  int _faces = 6;
  final TextEditingController _min = TextEditingController(text: '1');
  final TextEditingController _max = TextEditingController(text: '100');
  final TextEditingController _lista = TextEditingController();
  final TextEditingController _times = TextEditingController(text: '2');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _lista.dispose();
    _times.dispose();
    super.dispose();
  }

  List<String> get _linhas => _lista.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _dado() => setState(() => _res = '🎲 d$_faces: ${_r.nextInt(_faces) + 1}');

  void _moeda() =>
      setState(() => _res = '🪙 Deu ${_r.nextBool() ? 'cara' : 'coroa'}!');

  void _numero() {
    var a = int.tryParse(_min.text.trim()) ?? 1;
    var b = int.tryParse(_max.text.trim()) ?? 100;
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }
    setState(() => _res = '🎯 Sorteado: ${a + _r.nextInt(b - a + 1)}');
  }

  void _sortearItem() {
    final l = _linhas;
    if (l.isEmpty) {
      setState(() => _res = 'Escreva uma lista (um item por linha).');
      return;
    }
    setState(() => _res = '🏆 Sorteado: ${l[_r.nextInt(l.length)]}');
  }

  void _formarTimes() {
    final l = _linhas;
    l.shuffle(_r);
    final n = (int.tryParse(_times.text.trim()) ?? 2).clamp(2, 20).toInt();
    if (l.length < n) {
      setState(() => _res = 'Coloque pelo menos $n nomes na lista.');
      return;
    }
    final grupos = List<List<String>>.generate(n, (_) => <String>[]);
    for (var i = 0; i < l.length; i++) {
      grupos[i % n].add(l[i]);
    }
    final sb = StringBuffer();
    for (var i = 0; i < n; i++) {
      sb.writeln('Time ${i + 1}: ${grupos[i].join(', ')}');
    }
    setState(() => _res = sb.toString().trim());
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Sorteios',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          resultadoBox(_res),
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Dado e moeda'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final f in <int>[4, 6, 8, 10, 12, 20, 100])
                    ChoiceChip(
                      label: Text('d$f'),
                      selected: _faces == f,
                      onSelected: (_) => setState(() => _faces = f),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  botao('Rolar d$_faces', _dado),
                  botao('Cara ou coroa', _moeda),
                ],
              ),
            ],
          )),
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Número entre'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: campo('Mínimo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: campo('Máximo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  botao('Sortear', _numero),
                ],
              ),
            ],
          )),
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Lista de nomes ou itens'),
              TextField(
                controller: _lista,
                minLines: 4,
                maxLines: 8,
                decoration: campo('Um por linha'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  botao('Sortear um', _sortearItem),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _times,
                      keyboardType: TextInputType.number,
                      decoration: campo('Times'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  botao('Formar times', _formarTimes),
                ],
              ),
            ],
          )),
        ],
      ),
    );
  }
}

// ---------- Senhas ----------
class SenhaPage extends StatefulWidget {
  const SenhaPage({super.key});

  @override
  State<SenhaPage> createState() => _SenhaPageState();
}

class _SenhaPageState extends State<SenhaPage> {
  double _n = 14;
  bool _simb = true;
  String _senha = '';

  @override
  void initState() {
    super.initState();
    _senha = gerarSenha(_n.round(), _simb);
  }

  String _forca() {
    final n = _n.round();
    if (n < 10) return 'Fraca';
    if (n < 14) return 'Boa';
    if (n < 20) return 'Forte';
    return 'Muito forte';
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Senhas',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                _senha,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: P.destaque),
              ),
              const SizedBox(height: 6),
              Text('Força: ${_forca()} · ${_n.round()} caracteres',
                  style: TextStyle(color: P.claro.withOpacity(0.8))),
            ],
          )),
          caixa(Column(
            children: [
              Slider(
                value: _n,
                min: 8,
                max: 32,
                divisions: 24,
                label: '${_n.round()}',
                activeColor: P.destaque,
                onChanged: (v) {
                  setState(() {
                    _n = v;
                    _senha = gerarSenha(_n.round(), _simb);
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _simb,
                activeColor: P.destaque,
                title: const Text('Incluir símbolos'),
                onChanged: (v) {
                  setState(() {
                    _simb = v;
                    _senha = gerarSenha(_n.round(), _simb);
                  });
                },
              ),
              Row(
                children: [
                  botao('🔁 Gerar outra',
                      () => setState(() => _senha = gerarSenha(_n.round(), _simb))),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => copiarTexto(context, _senha),
                    child: const Text('Copiar'),
                  ),
                ],
              ),
            ],
          )),
          Text(
              'Dica: use uma senha diferente para cada site e guarde em um gerenciador de senhas. A senha é criada no seu celular e não vai para a internet.',
              style: TextStyle(color: P.claro.withOpacity(0.7), height: 1.4)),
        ],
      ),
    );
  }
}

// ---------- Anti-golpe ----------
class GolpePage extends StatefulWidget {
  const GolpePage({super.key});

  @override
  State<GolpePage> createState() => _GolpePageState();
}

class _GolpePageState extends State<GolpePage> {
  final TextEditingController _ctrl = TextEditingController();
  String _res = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Anti-golpe',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ctrl,
                minLines: 4,
                maxLines: 10,
                decoration: campo('Cole aqui a mensagem, o link ou o texto da ligação'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  botao('Analisar aqui (sem internet)', () {
                    final t = _ctrl.text.trim();
                    if (t.isEmpty) return;
                    setState(() => _res = analiseGolpeLocal(t));
                  }),
                  OutlinedButton(
                    onPressed: () {
                      final t = _ctrl.text.trim();
                      if (t.isEmpty) return;
                      chatComando(context,
                          enviar:
                              'Analise se esta mensagem, link ou ligação é golpe. Dê um veredito claro, os sinais de alerta e o que devo fazer:\n$t');
                    },
                    child: const Text('Perguntar à IA'),
                  ),
                ],
              ),
            ],
          )),
          resultadoBox(_res),
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Regras de ouro'),
              Text(
                  '• Banco e empresas nunca pedem senha, código ou token por mensagem ou ligação.\n'
                  '• Desconfie de urgência, ameaça de bloqueio e prêmios que você não esperava.\n'
                  '• Não clique em links recebidos: abra o app ou o site oficial digitando você mesmo.\n'
                  '• Pix só para quem você confirmou por outro canal (ligue para a pessoa).\n'
                  '• Ative a verificação em duas etapas no WhatsApp e nos bancos.\n'
                  '• Na dúvida, não responda: pergunte aqui.',
                  style: TextStyle(color: P.claro.withOpacity(0.85), height: 1.45)),
            ],
          )),
        ],
      ),
    );
  }
}

// ---------- Alarme e timer ----------
class AlarmePage extends StatefulWidget {
  const AlarmePage({super.key});

  @override
  State<AlarmePage> createState() => _AlarmePageState();
}

class _AlarmePageState extends State<AlarmePage> with ResultadoMixin<AlarmePage> {
  TimeOfDay _hora = const TimeOfDay(hour: 7, minute: 0);
  final TextEditingController _min = TextEditingController(text: '10');

  @override
  void dispose() {
    _min.dispose();
    super.dispose();
  }

  Future<void> _escolher() async {
    final t = await showTimePicker(context: context, initialTime: _hora);
    if (t != null && mounted) setState(() => _hora = t);
  }

  bool _liberado() {
    if (cfg.permAcoes) return true;
    setState(() => res =
        'As ações no celular estão desligadas. Ative em Config > Permissões.');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Alarme e timer',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Alarme'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _escolher,
                    child: Text('⏰ ${dois(_hora.hour)}:${dois(_hora.minute)}'),
                  ),
                  botao('Criar alarme', () {
                    if (_liberado()) {
                      rodar(() => criarAlarme(_hora.hour, _hora.minute, cfg.nome));
                    }
                  }),
                ],
              ),
            ],
          )),
          caixa(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo2('Timer'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in <int>[1, 5, 10, 15, 20, 30, 45, 60])
                    ActionChip(
                      label: Text('$m min'),
                      onPressed: () {
                        if (_liberado()) {
                          rodar(() => criarTimerNativo(m * 60, cfg.nome));
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: campo('Minutos'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  botao('Iniciar timer', () {
                    final m = int.tryParse(_min.text.trim()) ?? 0;
                    if (m <= 0) {
                      setState(() => res = 'Digite os minutos.');
                      return;
                    }
                    if (_liberado()) {
                      rodar(() => criarTimerNativo(m * 60, cfg.nome));
                    }
                  }),
                ],
              ),
            ],
          )),
          areaResultado(),
        ],
      ),
    );
  }
}

// ---------- Celular: bateria e internet ----------
class DiagPage extends StatefulWidget {
  const DiagPage({super.key});

  @override
  State<DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<DiagPage> with ResultadoMixin<DiagPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) rodar(textoBateria);
    });
  }

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Celular',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          caixa(Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              botao('🔋 Bateria', () => rodar(textoBateria)),
              botao('📶 Testar internet', () => rodar(diagnosticoRede)),
              botao(
                  '📋 Tudo',
                  () => rodar(() async {
                        final b = await textoBateria();
                        final d = await diagnosticoRede();
                        final agora = DateTime.now();
                        return '$b\n\n$d\n\n🕒 ${horaTexto(agora)} · ${dataExtenso(agora)}';
                      })),
            ],
          )),
          areaResultado(),
        ],
      ),
    );
  }
}

// ---------- Apps ----------
const List<List<String>> _atalhos = [
  ['📷', 'Câmera', 'camera'],
  ['⚙️', 'Configurações', 'configuracoes'],
  ['📶', 'Wi-Fi', 'wifi'],
  ['🔵', 'Bluetooth', 'bluetooth'],
  ['📞', 'Telefone', 'telefone'],
  ['💬', 'WhatsApp', 'whatsapp'],
  ['▶️', 'YouTube', 'youtube'],
  ['📸', 'Instagram', 'instagram'],
  ['👤', 'Facebook', 'facebook'],
  ['🎵', 'TikTok', 'tiktok'],
  ['✈️', 'Telegram', 'telegram'],
  ['🎧', 'Spotify', 'spotify'],
  ['🎬', 'Netflix', 'netflix'],
  ['✉️', 'Gmail', 'gmail'],
  ['🌐', 'Chrome', 'chrome'],
  ['🗺️', 'Mapas', 'mapas'],
  ['🛍️', 'Play Store', 'play store'],
  ['☁️', 'Drive', 'drive'],
  ['🖼️', 'Fotos', 'fotos'],
  ['🎮', 'Discord', 'discord'],
  ['🐦', 'X (Twitter)', 'twitter'],
  ['📊', 'Planilhas', 'planilhas'],
  ['📄', 'Documentos', 'documentos'],
  ['📆', 'Agenda', 'agenda'],
  ['⏰', 'Relógio', 'relogio'],
];

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return telaPadrao(
      'Apps',
      ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
              'Toque para abrir. Você também pode dizer no chat: abrir WhatsApp.',
              style: TextStyle(color: P.claro.withOpacity(0.8))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _atalhos)
                ActionChip(
                  label: Text('${a[0]} ${a[1]}'),
                  onPressed: () async {
                    if (!cfg.permAcoes) {
                      aviso(context,
                          'As ações no celular estão desligadas. Ative em Config > Permissões.');
                      return;
                    }
                    final r = await abrirApp(a[2]);
                    if (context.mounted) aviso(context, r);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== config =====
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late final TextEditingController _key = TextEditingController(text: cfg.apiKey);
  late final TextEditingController _nome = TextEditingController(text: cfg.nome);
  late final TextEditingController _pers =
      TextEditingController(text: cfg.personalidade);
  late final TextEditingController _cidade =
      TextEditingController(text: cfg.cidade);
  bool _ver = false;
  bool _testando = false;
  String _teste = '';

  @override
  void dispose() {
    _key.dispose();
    _nome.dispose();
    _pers.dispose();
    _cidade.dispose();
    super.dispose();
  }

  void _salvarTextos() {
    cfg.apiKey = _key.text.trim();
    final n = _nome.text.trim();
    cfg.nome = n.isEmpty ? 'CAPITÃO_MAYBANK' : n;
    final p = _pers.text.trim();
    cfg.personalidade = p.isEmpty
        ? 'direto, leal e bem-humorado, como um capitão de navio amigo do usuário'
        : p;
    cfg.cidade = _cidade.text.trim();
    cfg.mudou();
  }

  Future<void> _testar() async {
    _salvarTextos();
    setState(() {
      _testando = true;
      _teste = '';
    });
    final r = await Ia.perguntar(
      texto: 'Responda apenas com a palavra: ok',
      historico: <Map<String, dynamic>>[],
      web: false,
    );
    if (!mounted) return;
    setState(() {
      _testando = false;
      _teste = r.ok
          ? '✅ Funcionando! Modelo: ${Ia.modeloOk ?? '-'}'
          : '❌ ${r.texto}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cfg,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: P.fundo,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text('Configurações',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: P.claro)),
              ),
              caixa(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titulo2('🔑 Chave grátis do Gemini'),
                  TextField(
                    controller: _key,
                    obscureText: !_ver,
                    decoration: campo('Cole a chave aqui').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _ver = !_ver),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Pegue de graça em aistudio.google.com/apikey',
                      style: TextStyle(color: P.claro.withOpacity(0.7), fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      botao('Salvar', () {
                        _salvarTextos();
                        aviso(context, 'Salvo.');
                      }),
                      OutlinedButton(
                        onPressed: _testando ? null : _testar,
                        child: Text(_testando ? 'Testando...' : 'Testar conexão'),
                      ),
                      OutlinedButton(
                        onPressed: () => abrirUrl('https://aistudio.google.com/apikey'),
                        child: const Text('Abrir site da chave'),
                      ),
                    ],
                  ),
                  if (_teste.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SelectableText(_teste,
                          style: TextStyle(color: P.claro, height: 1.4)),
                    ),
                ],
              )),
              caixa(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titulo2('⚓ Assistente'),
                  TextField(controller: _nome, decoration: campo('Nome')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pers,
                    minLines: 2,
                    maxLines: 4,
                    decoration: campo('Personalidade'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cidade,
                    decoration: campo('Cidade padrão do clima'),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: botao('Salvar', () {
                      _salvarTextos();
                      aviso(context, 'Salvo.');
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text('Habilidade ativa',
                      style: TextStyle(color: P.claro.withOpacity(0.8))),
                  DropdownButton<String>(
                    value: cfg.skill,
                    isExpanded: true,
                    dropdownColor: P.mar,
                    items: [
                      for (final h in habilidades)
                        DropdownMenuItem<String>(
                            value: h.id, child: Text('${h.emoji} ${h.nome}')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        cfg.skill = v;
                        cfg.mudou();
                      }
                    },
                  ),
                ],
              )),
              caixa(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titulo2('🔊 Voz'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cfg.falar,
                    activeColor: P.destaque,
                    title: const Text('Responder por voz'),
                    onChanged: (v) {
                      cfg.falar = v;
                      cfg.mudou();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cfg.continuo,
                    activeColor: P.destaque,
                    title: const Text('Modo conversa por voz'),
                    subtitle: const Text(
                        'Depois que ele responde, o microfone abre de novo (quando você falou por voz).'),
                    onChanged: (v) {
                      cfg.continuo = v;
                      cfg.mudou();
                    },
                  ),
                  Text('Tom da voz (mais grave ← → mais agudo)',
                      style: TextStyle(color: P.claro.withOpacity(0.8))),
                  Slider(
                    value: cfg.tom.clamp(0.5, 1.5).toDouble(),
                    min: 0.5,
                    max: 1.5,
                    activeColor: P.quente,
                    onChanged: (v) => setState(() => cfg.tom = v),
                    onChangeEnd: (_) => cfg.mudou(),
                  ),
                  Text('Velocidade da fala',
                      style: TextStyle(color: P.claro.withOpacity(0.8))),
                  Slider(
                    value: cfg.velocidade.clamp(0.2, 1.0).toDouble(),
                    min: 0.2,
                    max: 1.0,
                    activeColor: P.quente,
                    onChanged: (v) => setState(() => cfg.velocidade = v),
                    onChangeEnd: (_) => cfg.mudou(),
                  ),
                  OutlinedButton(
                    onPressed: () => chatKey.currentState?.testarVoz(),
                    child: const Text('🔈 Testar voz'),
                  ),
                ],
              )),
              caixa(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titulo2('🎨 Aparência'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (int i = 0; i < paletas.length; i++)
                        ChoiceChip(
                          label: Text(paletas[i].nome),
                          selected: cfg.tema == i,
                          onSelected: (_) {
                            cfg.tema = i;
                            cfg.mudou();
                          },
                        ),
                    ],
                  ),
                ],
              )),
              caixa(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titulo2('🔒 Permissões'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cfg.permAcoes,
                    activeColor: P.destaque,
                    title: const Text('Ações no celular'),
                    subtitle: const Text(
                        'Abrir apps, mapas, alarmes, WhatsApp e discador. Ligações sempre pedem confirmação.'),
                    onChanged: (v) {
                      cfg.permAcoes = v;
                      cfg.mudou();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cfg.permMemoria,
                    activeColor: P.destaque,
                    title: const Text('Memória'),
                    subtitle: const Text('Lembrar o que você pedir (lembre-se que ...).'),
                    onChanged: (v) {
                      cfg.permMemoria = v;
                      cfg.mudou();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cfg.permWeb,
                    activeColor: P.destaque,
                    title: const Text('Pesquisar na internet'),
                    subtitle: const Text(
                        'Usa a busca do Google nas respostas quando precisar de informação atual.'),
                    onChanged: (v) {
                      cfg.permWeb = v;
                      cfg.mudou();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cfg.permLocal,
                    activeColor: P.destaque,
                    title: const Text('Localização'),
                    subtitle: const Text(
                        'Só é usada quando você pedir (onde estou, perto de mim, clima aqui).'),
                    onChanged: (v) async {
                      cfg.permLocal = v;
                      cfg.mudou();
                      if (v) {
                        try {
                          final p = await Geolocator.checkPermission();
                          if (p == LocationPermission.denied) {
                            await Geolocator.requestPermission();
                          }
                        } catch (_) {}
                      }
                    },
                  ),
                ],
              )),
              caixa(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titulo2('🧹 Dados'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await confirmarDialogo(
                              context, 'Limpar toda a conversa?');
                          if (ok) {
                            sinalLimparChat.value++;
                            if (context.mounted) aviso(context, 'Conversa limpa.');
                          }
                        },
                        child: const Text('Limpar conversa'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await confirmarDialogo(
                              context, 'Apagar tudo o que o assistente lembra?');
                          if (ok) {
                            await cfg.setLista('memoria', <String>[]);
                            if (context.mounted) aviso(context, 'Memória apagada.');
                          }
                        },
                        child: const Text('Apagar memória'),
                      ),
                    ],
                  ),
                ],
              )),
              caixa(Text(
                  '⚓ ${cfg.nome} · versão 2\n'
                  '${totalCatalogo()} comandos prontos na Biblioteca · 16 ferramentas · tudo grátis.\n'
                  'O modo offline (conversar sem internet) ainda não existe: fica para uma próxima versão.',
                  style: TextStyle(color: P.claro.withOpacity(0.8), height: 1.45))),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== entrada =====
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await cfg.carregar();
  garantirRotinasPadrao();
  runApp(const CapitaoApp());
}

class CapitaoApp extends StatelessWidget {
  const CapitaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cfg,
      builder: (context, _) {
        final p = P;
        return MaterialApp(
          title: 'CAPITÃO_MAYBANK',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: p.noite,
            colorScheme: ColorScheme.dark(
              primary: p.destaque,
              secondary: p.quente,
              surface: p.mar,
            ),
            useMaterial3: true,
          ),
          home: const Raiz(),
        );
      },
    );
  }
}

class Raiz extends StatelessWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[cfg, abaAtual]),
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: abaAtual.value,
          children: [
            ChatPage(key: chatKey),
            const FerramentasPage(),
            const BibliotecaPage(),
            const ConfigPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: abaAtual.value,
          backgroundColor: P.mar,
          onDestinationSelected: (i) => abaAtual.value = i,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps),
              label: 'Ferramentas',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Biblioteca',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Config',
            ),
          ],
        ),
      ),
    );
  }
}
