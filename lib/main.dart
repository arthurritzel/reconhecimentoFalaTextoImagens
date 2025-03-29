import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:language_detector/language_detector.dart';
import 'package:translator/translator.dart';
import 'dart:io';

void main() {
  runApp(TextRecognitionApp());
}

class TextRecognitionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Leitor de Texto Multilíngue',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TextRecognitionPage(),
    );
  }
}

class TextRecognitionPage extends StatefulWidget {
  @override
  _TextRecognitionPageState createState() => _TextRecognitionPageState();
}

class _TextRecognitionPageState extends State<TextRecognitionPage> {
  File? _imageFile;
  String _recognizedText = 'Nenhum texto reconhecido ainda';
  String _detectedLanguage = 'Não detectado';
  String ttsLanguage = 'pt-BR';
  late TextRecognizer _textRecognizer;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isProcessing = false;
  String _textoTraduzido = '';

  String _targetLanguage = 'none';
  final Map<String, String> _targetLanguages = {
    'none': 'Sem tradução',
    'pt': 'Português 🇧🇷',
    'en': 'Inglês 🇺🇸',
    'es': 'Espanhol 🇪🇸',
    'fr': 'Francês 🇫🇷',
    'de': 'Alemão 🇩🇪',
    'it': 'Italiano 🇮🇹',
    'ru': 'Russo 🇷🇺',
    'ar': 'Árabe 🇸🇦',
    'zh-cn': 'Chinês 🇨🇳',
    'ja': 'Japonês 🇯🇵',
    'ko': 'Coreano 🇰🇷',
  };

  @override
  void initState() {
    super.initState();
    _initRecognizer();
    _initTts();
  }

  void _initRecognizer() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  void _initTts() async {
    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isProcessing = true;
        _recognizedText = 'Processando...';
        _detectedLanguage = 'Detectando...';
      });

      final pickedFile = await ImagePicker().pickImage(source: source);

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        await _processImage(imageFile);
      }
    } catch (e) {
      _showErrorDialog('Erro ao selecionar imagem: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      setState(() {
        _imageFile = imageFile;
        _recognizedText =
            recognizedText.text.isEmpty
                ? 'Nenhum texto encontrado'
                : recognizedText.text;
      });

      // Detectar idioma
      await _detectLanguage(_recognizedText);

      await _configureTextToSpeech(_detectedLanguage, _recognizedText);

      await _speakText(_recognizedText);
    } catch (e) {
      setState(() {
        _recognizedText = 'Erro no reconhecimento: $e';
        _detectedLanguage = 'Erro na detecção';
      });
      _showErrorDialog('Erro no processamento: $e');
    }
  }

  Future<void> _detectLanguage(String text) async {
    try {
      if (text.isEmpty || text == 'Nenhum texto encontrado') {
        setState(() {
          _detectedLanguage = 'Não detectado';
        });
        return;
      }

      final detection = await LanguageDetector.getLanguageCode(content: text);
      setState(() {
        _detectedLanguage = _getLanguageName(detection);
      });
    } catch (e) {
      setState(() {
        _detectedLanguage = 'Erro na detecção';
      });
    }
  }

  String _getLanguageName(String languageCode) {
    final Map<String, String> languageNames = {
      'en': 'Inglês',
      'pt': 'Português',
      'es': 'Espanhol',
      'fr': 'Francês',
      'de': 'Alemão',
      'it': 'Italiano',
      'ru': 'Russo',
      'ar': 'Árabe',
      'zh': 'Chinês',
      'ja': 'Japonês',
      'ko': 'Coreano',
    };

    return languageNames[languageCode] ?? languageCode;
  }

  Future<void> _configureTextToSpeech(
    String language,
    String reconizedText,
  ) async {
    final Map<String, String> languageToTTSMap = {
      'Português': 'pt-BR',
      'Inglês': 'en-US',
      'Espanhol': 'es-ES',
      'Francês': 'fr-FR',
      'Alemão': 'de-DE',
      'Italiano': 'it-IT',
      'Russo': 'ru-RU',
      'Árabe': 'ar-SA',
      'Chinês': 'zh-CN',
      'Japonês': 'ja-JP',
      'Coreano': 'ko-KR',
    };

    ttsLanguage = languageToTTSMap[language] ?? 'pt-BR';

    await _flutterTts.setLanguage(ttsLanguage);
  }

  Future<void> _speakText(String text) async {
    if (text.isNotEmpty && text != 'Nenhum texto encontrado') {
      await _flutterTts.setVolume(1.0);
      text = text.replaceAll('\n', ' ');
      text = text.replaceAll(RegExp(r'\s+'), ' ');

      String fromTranslationLang = ttsLanguage.split('-')[0];

      if (_targetLanguage != "none" && _targetLanguage != fromTranslationLang) {
        final translator = GoogleTranslator();
        var translation = await translator.translate(
          text,
          from: fromTranslationLang,
          to: _targetLanguage,
        );
        text = translation.text;
        await _flutterTts.setLanguage(_targetLanguage);
        setState(() {
          _textoTraduzido = translation.text;
        });
      } else {
        _textoTraduzido = '';
        await _flutterTts.setLanguage(ttsLanguage);
      }

      await _flutterTts.speak(text);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Erro'),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Leitor de Texto Multilíngue', style: TextStyle(fontSize: 18),),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: DropdownButton<String>(
              value: _targetLanguage,
              items:
                  _targetLanguages.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
              style: TextStyle(color: Colors.black),
              onChanged: (String? newValue) {
                setState(() {
                  _targetLanguage = newValue!;
                  _textoTraduzido = '';
                  _speakText(_recognizedText);
                });
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _imageFile != null
                ? Container(
                    constraints: BoxConstraints(
                      maxHeight: 400,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.contain,
                    ),
                  )
                : Text('Nenhuma imagem selecionada'),

              SizedBox(height: 20),
              _imageFile != null
                  ? Text(
                    'Idioma Detectado: $_detectedLanguage',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  )
                  : Container(),

              _imageFile != null
                  ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    elevation: 2,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Texto reconhecido:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: 8),
                          _recognizedText.isEmpty
                              ? Center(child: CircularProgressIndicator())
                              : Text(
                                  _recognizedText,
                                  style: TextStyle(fontSize: 16),
                                ),
                        ],
                      ),
                    ),
                  ),
                )
                  : Container(),

              _textoTraduzido != '' && _imageFile != null
                  ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    elevation: 2,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tradução (${_targetLanguages[_targetLanguage]}):',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: 8),
                          _textoTraduzido.isEmpty
                              ? Center(child: CircularProgressIndicator())
                              : Text(
                                  _textoTraduzido,
                                  style: TextStyle(fontSize: 16),
                                ),
                        ],
                      ),
                    ),
                  ),
                )
                  : Container(),

              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => {_speakText(_recognizedText)},
                label: Text("Falar de novo"),
                icon: Icon(Icons.refresh),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    icon: Icon(Icons.camera_alt, color: Colors.white),
                    label: Text(
                      'Câmera',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed:
                        _isProcessing
                            ? null
                            : () => _pickImage(ImageSource.camera),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    icon: Icon(Icons.photo_library, color: Colors.white),
                    label: Text(
                      'Galeria',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed:
                        _isProcessing
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
              SizedBox(height: 50),

              if (_isProcessing)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _flutterTts.stop();
    super.dispose();
  }
}
