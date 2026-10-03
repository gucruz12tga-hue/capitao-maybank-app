import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const CapitaoApp());

// ---------- Tema inspirado em Outer Banks ----------
class OB {
  static const noite = Color(0xFF0B1D2A); // azul-marinho profundo
  static const mar = Color(0xFF123A4F);
  static const turquesa = Color(0xFF2EC4B6);
  static const areia = Color(0xFFF4E4C1);
  static const por_do_sol = Color(0xFFFF9F43);
  static const coral = Color(0xFFFF6B6B);
}

class CapitaoApp extends StatelessWidget {
  const CapitaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CAPITÃO_MAYBANK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: OB.noite,
        colorScheme: const ColorScheme.dark(
          primary: OB.turquesa,
          secondary: OB.por_do_sol,
          surface: OB.mar,
        ),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

class Msg {
  final String texto;
  final bool doUsuario;
  Msg(this.texto, this.doUsuario);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Msg> _msgs = [];
  final List<Map<String, dynamic>> _historico = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  String _apiKey = '';
  String _nome = 'CAPITÃO_MAYBANK';
  String _personalidade =
      'direto, leal e bem-humorado, como um capitão de navio amigo do usuário';
  bool _falar = true;
  bool _ouvindo = false;
  bool _pensando = false;
  double _tom = 0.6; // tom grave = voz masculina

  static const _modelos = [
    'gemini-flash-latest',
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3-flash-preview',
    'gemini-2.5-flash',
  ];
  String? _modeloOk;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = p.getString('apiKey') ?? '';
      _nome = p.getString('nome') ?? _nome;
      _personalidade = p.getString('personalidade') ?? _personalidade;
      _falar = p.getBool('falar') ?? true;
      _tom = p.getDouble('tom') ?? 0.6;
    });
    await _configurarVoz();
    await _stt.initialize();
    _msgs.add(Msg(
        'Fala, comandante! Eu sou o $_nome. Pode digitar ou tocar no microfone.',
        false));
    if (_apiKey.isEmpty) {
      _msgs.add(Msg(
          'Antes de começar, toque na engrenagem ⚙️ e cole sua chave grátis do Gemini (aistudio.google.com/apikey).',
          false));
    }
    setState(() {});
  }

  Future<void> _configurarVoz() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setPitch(_tom);
    await _tts.setSpeechRate(0.5);
    try {
      final vozes = await _tts.getVoices as List?;
      if (vozes != null) {
        final masc = vozes.cast<Map>().where((v) {
          final n = (v['name'] ?? '').toString().toLowerCase();
          final l = (v['locale'] ?? '').toString().toLowerCase();
          return l.startsWith('pt') && (n.contains('male') || n.contains('ptd') || n.contains('pte'));
        }).toList();
        if (masc.isNotEmpty) {
          await _tts.setVoice({
            'name': masc.first['name'].toString(),
            'locale': masc.first['locale'].toString(),
          });
        }
      }
    } catch (_) {}
  }

  void _rolar() {
    Timer(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  // ---------- Comandos do celular ----------
  Future<String?> _comandoLocal(String t) async {
    final s = t.toLowerCase().trim();

    Future<String> abrir(String url, String ok) async {
      try {
        final deu = await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
        return deu ? ok : 'Não consegui abrir isso, comandante.';
      } catch (_) {
        return 'Não consegui abrir isso, comandante.';
      }
    }

    if (s.startsWith('ligar para ') || s.startsWith('ligar ')) {
      final num = s.replaceAll(RegExp(r'[^0-9+]'), '');
      if (num.length >= 8) {
        return abrir('tel:$num', 'Abrindo a discagem para $num. Confirme a ligação.');
      }
    }
    if (s.contains('abrir whatsapp') || s.contains('abre o whatsapp')) {
      return abrir('whatsapp://send', 'Abrindo o WhatsApp.');
    }
    if (s.contains('abrir youtube') || s.contains('abre o youtube')) {
      return abrir('https://www.youtube.com', 'Abrindo o YouTube.');
    }
    if (s.contains('abrir instagram') || s.contains('abre o instagram')) {
      return abrir('https://www.instagram.com', 'Abrindo o Instagram.');
    }
    if (s.contains('abrir câmera') || s.contains('abrir camera')) {
      return abrir('intent:#Intent;action=android.media.action.IMAGE_CAPTURE;end', 'Abrindo a câmera.');
    }
    if (s.startsWith('pesquisar ') || s.startsWith('pesquise ')) {
      final q = t.substring(t.indexOf(' ') + 1);
      return abrir('https://www.google.com/search?q=${Uri.encodeComponent(q)}',
          'Pesquisando: $q');
    }
    if (s.startsWith('rota para ') || s.startsWith('como chegar em ')) {
      final q = t.substring(s.startsWith('rota para ') ? 10 : 15);
      return abrir(
          'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(q)}',
          'Traçando a rota para $q. Você precisa autorizar a localização no mapa.');
    }
    if (s.startsWith('alarme ') || s.contains('definir alarme')) {
      return abrir('intent:#Intent;action=android.intent.action.SHOW_ALARMS;end',
          'Abrindo os alarmes.');
    }
    return null;
  }

  // ---------- Gemini ----------
  Future<String> _perguntarGemini(String texto) async {
    if (_apiKey.isEmpty) {
      return 'Falta a chave do Gemini. Toque na engrenagem ⚙️ e cole a chave grátis.';
    }
    _historico.add({
      'role': 'user',
      'parts': [
        {'text': texto}
      ]
    });
    final corpo = {
      'system_instruction': {
        'parts': [
          {
            'text':
                'Você é $_nome, assistente pessoal de IA no celular do usuário. Personalidade: $_personalidade. '
                    'Responda sempre em português do Brasil, de forma curta e natural (é falado em voz alta), '
                    'e responda qualquer assunto. Se o usuário disser algo curto como "opa", responda de forma simpática. '
                    'Nunca peça dados sensíveis e sempre peça confirmação antes de ações importantes.'
          }
        ]
      },
      'contents': _historico.length > 30
          ? _historico.sublist(_historico.length - 30)
          : _historico,
    };
    final lista = [
      if (_modeloOk != null) _modeloOk!,
      ..._modelos.where((m) => m != _modeloOk),
    ];
    int ultimoCodigo = 0;
    String ultimoErro = '';
    try {
      for (final modelo in lista) {
        final r = await http
            .post(
              Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/models/$modelo:generateContent'),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _apiKey,
              },
              body: jsonEncode(corpo),
            )
            .timeout(const Duration(seconds: 40));
        if (r.statusCode == 200) {
          try {
            final j = jsonDecode(utf8.decode(r.bodyBytes));
            final resp =
                j['candidates'][0]['content']['parts'][0]['text'] as String;
            _modeloOk = modelo;
            _historico.add({
              'role': 'model',
              'parts': [
                {'text': resp}
              ]
            });
            return resp.trim();
          } catch (_) {
            _historico.removeLast();
            return 'O Gemini não conseguiu responder a isso. Tente falar de outro jeito.';
          }
        }
        String detalhe = '';
        try {
          detalhe = jsonDecode(utf8.decode(r.bodyBytes))['error']['message']
              .toString();
        } catch (_) {}
        ultimoCodigo = r.statusCode;
        ultimoErro = 'Erro ${r.statusCode} (modelo $modelo): $detalhe';
        if (r.statusCode == 404 ||
            r.statusCode == 429 ||
            r.statusCode == 500 ||
            r.statusCode == 503) {
          continue; // tenta o próximo modelo
        }
        break;
      }
      _historico.removeLast();
      if (ultimoCodigo == 429) {
        return 'Muitas perguntas seguidas (limite grátis). Espere um minutinho e tente de novo.';
      }
      if (ultimoCodigo == 403 ||
          (ultimoCodigo == 400 && ultimoErro.toLowerCase().contains('key'))) {
        return 'Problema com a chave do Gemini. Confira na engrenagem ⚙️.\n$ultimoErro';
      }
      return ultimoErro;
    } catch (e) {
      if (_historico.isNotEmpty && _historico.last['role'] == 'user') {
        _historico.removeLast();
      }
      return 'Sem conexão com a internet no momento. (Modo offline chega na versão 2.)';
    }
  }

  Future<void> _enviar(String texto) async {
    final t = texto.trim();
    if (t.isEmpty || _pensando) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(Msg(t, true));
      _pensando = true;
    });
    _rolar();

    String resposta;
    final local = await _comandoLocal(t);
    resposta = local ?? await _perguntarGemini(t);

    setState(() {
      _msgs.add(Msg(resposta, false));
      _pensando = false;
    });
    _rolar();
    if (_falar) {
      await _tts.stop();
      await _tts.speak(resposta.replaceAll(RegExp(r'[*#_`]'), ''));
    }
  }

  Future<void> _microfone() async {
    if (_ouvindo) {
      await _stt.stop();
      setState(() => _ouvindo = false);
      return;
    }
    await _tts.stop();
    final ok = await _stt.initialize();
    if (!ok) {
      setState(() => _msgs.add(Msg(
          'Não consegui acessar o microfone. Autorize nas permissões do app.',
          false)));
      return;
    }
    setState(() => _ouvindo = true);
    await _stt.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      onResult: (res) {
        if (res.finalResult) {
          setState(() => _ouvindo = false);
          _enviar(res.recognizedWords);
        } else {
          _ctrl.text = res.recognizedWords;
        }
      },
    );
  }

  // ---------- Configurações ----------
  Future<void> _abrirConfig() async {
    final cKey = TextEditingController(text: _apiKey);
    final cNome = TextEditingController(text: _nome);
    final cPers = TextEditingController(text: _personalidade);
    double tom = _tom;
    bool falar = _falar;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OB.mar,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚙️ Personalização',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: OB.areia)),
                const SizedBox(height: 16),
                TextField(
                  controller: cKey,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Chave grátis do Gemini (aistudio.google.com/apikey)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cNome,
                  decoration: const InputDecoration(
                      labelText: 'Nome do assistente',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cPers,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Personalidade',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: falar,
                  onChanged: (v) => setM(() => falar = v),
                  title: const Text('Responder por voz'),
                  activeColor: OB.turquesa,
                ),
                Text('Tom da voz (mais grave ← → mais agudo)'),
                Slider(
                  value: tom,
                  min: 0.3,
                  max: 1.2,
                  activeColor: OB.por_do_sol,
                  onChanged: (v) => setM(() => tom = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: OB.turquesa,
                        foregroundColor: OB.noite),
                    onPressed: () async {
                      final p = await SharedPreferences.getInstance();
                      await p.setString('apiKey', cKey.text.trim());
                      await p.setString('nome', cNome.text.trim());
                      await p.setString('personalidade', cPers.text.trim());
                      await p.setBool('falar', falar);
                      await p.setDouble('tom', tom);
                      setState(() {
                        _apiKey = cKey.text.trim();
                        _nome = cNome.text.trim().isEmpty
                            ? 'CAPITÃO_MAYBANK'
                            : cNome.text.trim();
                        _personalidade = cPers.text.trim();
                        _falar = falar;
                        _tom = tom;
                      });
                      await _configurarVoz();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2F4B), OB.noite, Color(0xFF05101A)],
          ),
        ),
        child: SafeArea(
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
              _rodape(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topo() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: OB.turquesa.withOpacity(0.25))),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: OB.por_do_sol,
              child: Text('⚓', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nome,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: OB.areia)),
                  Text(_ouvindo ? 'ouvindo...' : 'a bordo e às ordens',
                      style: const TextStyle(
                          fontSize: 12, color: OB.turquesa)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(_falar ? Icons.volume_up : Icons.volume_off,
                  color: OB.areia),
              onPressed: () async {
                setState(() => _falar = !_falar);
                if (!_falar) await _tts.stop();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: OB.areia),
              onPressed: _abrirConfig,
            ),
          ],
        ),
      );

  Widget _balao(Msg m) => Align(
        alignment: m.doUsuario ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: m.doUsuario ? OB.por_do_sol : OB.mar,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(m.doUsuario ? 18 : 4),
              bottomRight: Radius.circular(m.doUsuario ? 4 : 18),
            ),
            border: m.doUsuario
                ? null
                : Border.all(color: OB.turquesa.withOpacity(0.3)),
          ),
          child: SelectableText(
            m.texto,
            style: TextStyle(
                fontSize: 15.5,
                color: m.doUsuario ? OB.noite : OB.areia,
                height: 1.35),
          ),
        ),
      );

  Widget _rodape() => Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                onSubmitted: _enviar,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'Dê uma ordem, comandante...',
                  filled: true,
                  fillColor: OB.mar,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: _ouvindo ? OB.coral : OB.turquesa,
              child: IconButton(
                icon: Icon(_ouvindo ? Icons.stop : Icons.mic,
                    color: OB.noite),
                onPressed: _microfone,
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 24,
              backgroundColor: OB.por_do_sol,
              child: IconButton(
                icon: const Icon(Icons.send, color: OB.noite),
                onPressed: () => _enviar(_ctrl.text),
              ),
            ),
          ],
        ),
      );
}
