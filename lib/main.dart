import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MainApp()); 
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});


  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MosquitoGame(),
    );
  }
}

class MosquitoGame extends StatefulWidget {
  const MosquitoGame({Key? key}) : super(key: key);

  @override
  _MosquitoGameState createState() => _MosquitoGameState();
}

class _MosquitoGameState extends State<MosquitoGame> {
  // AR session and object managers
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  final AudioCache _audioCache = AudioCache(prefix: 'assets/sounds/');


  // Game state variables
  Timer? _gameTimer;
  Timer? _spawnTimer;
  int _remainingTime = 30;
  int _score = 0;
  bool _isGameOver = false;

  // List to keep track of mosquitoes in the scene
  final List<ARNode> _mosquitoes = [];

  @override
void initState() {
  super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _removeAllMosquitoes();
    // arObjectManager.dispose();
    arSessionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isGameOver
            ? const Text('Game Over')
            : Text('Time: $_remainingTime   Score: $_score'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
          ),
          if (_isGameOver)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Game Over!\nYour Score: $_score',
                    style: const TextStyle(
                      fontSize: 36,
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _restartGame,
                    child: const Text('Restart Game'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _restartGame() {
    setState(() {
      _remainingTime = 30;
      _score = 0;
      _isGameOver = false;
    });

    // Remove existing mosquitoes
    _removeAllMosquitoes();

    // Restart the game timers
    _startGame();
  }

  void _onARViewCreated(
      ARSessionManager sessionManager, ARObjectManager objectManager, ARAnchorManager anchorManager, ARLocationManager locationManager) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;

    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
    );
    arObjectManager.onInitialize();

    // Start the game
    _startGame();

    // Handle taps on AR objects
    arObjectManager.onNodeTap = _onNodeTap;
  }

  void _startGame() {
    // Start the countdown timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _isGameOver = true;
          timer.cancel();
          _spawnTimer?.cancel();
          _removeAllMosquitoes();
        }
      });
    });

    // Start spawning mosquitoes
    _spawnTimer = Timer.periodic(
        const Duration(milliseconds: 1500), (_) => _spawnMosquito());
  }

  void _spawnMosquito() async {
    if (_isGameOver) return;

    // Generate random position in front of the user
    final random = Vector3(
      Random().nextDouble() * 2 - 1, // X between -1 and 1
      Random().nextDouble() * 2 - 1, // Y between -1 and 1
      -Random().nextDouble() * 2 - 1, // Z between -1 and -3
    );

    // Create AR node for the mosquito
    final mosquitoNode = ARNode(
      type: NodeType.webGLB,
      uri: 'https://github.com/KhronosGroup/glTF-Sample-Models/raw/refs/heads/main/2.0/Duck/glTF-Binary/Duck.glb',
      scale: Vector3.all(0.05), // Adjust scale as needed
      position: random,
    );

    // Add mosquito to the scene
    bool? didAdd = await arObjectManager.addNode(mosquitoNode);
    if (didAdd == true) {
      _mosquitoes.add(mosquitoNode);
    }
  }

  void _onNodeTap(List<String> nodes) {
    for (final nodeName in nodes) {
      final node = _mosquitoes.firstWhere(
        (element) => element.name == nodeName,
        orElse: () => ARNode(type: NodeType.localGLTF2, uri: ''),
      );
      if (node.type != NodeType.localGLTF2) {
        // Remove the mosquito from the scene and update score
        arObjectManager.removeNode(node);
        _mosquitoes.remove(node);
        setState(() {
          _score++;
        });
        // _audioCache.play('squish.mp3');
      }
    }
  }

  void _removeAllMosquitoes() {
    for (final mosquito in _mosquitoes) {
      arObjectManager.removeNode(mosquito);
    }
    _mosquitoes.clear();
  }
}
