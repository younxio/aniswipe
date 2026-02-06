import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

class ThreeJSBackground extends StatefulWidget {
  const ThreeJSBackground({super.key});

  @override
  State<ThreeJSBackground> createState() => _ThreeJSBackgroundState();
}

class _ThreeJSBackgroundState extends State<ThreeJSBackground> {
  WebViewController? _controller;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Only initialize WebView on non-web platforms
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(_loadThreeJSScene());
    }
  }

  @override
  Widget build(BuildContext context) {
    // On web platforms, show a gradient background instead of WebView
    if (kIsWeb || _controller == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: WebViewWidget(
          key: const ValueKey('three_js_background'),
          controller: _controller!,
        ),
      ),
    );
  }

  String _loadThreeJSScene() {
    final html = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            margin: 0;
            overflow: hidden;
            background: linear-gradient(135deg, #0F172A 0%, #1E293B 50%, #0F172A 100%);
        }
        #canvas-container {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: 1;
        }
    </style>
</head>
<body>
    <div id="canvas-container"></div>
    
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
    <script>
        // Scene setup
        const scene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
        
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(window.devicePixelRatio);
        document.getElementById('canvas-container').appendChild(renderer.domElement);
        
        // Create floating particles
        const particlesGeometry = new THREE.BufferGeometry();
        const particlesCount = 200;
        const positions = new Float32Array(particlesCount * 3);
        const colors = new Float32Array(particlesCount * 3);
        
        for (let i = 0; i < particlesCount; i++) {
            positions[i * 3] = (Math.random() - 0.5) * 20;
            positions[i * 3 + 1] = (Math.random() - 0.5) * 20;
            positions[i * 3 + 2] = (Math.random() - 0.5) * 20;
            
            // Gradient colors from #FF6B6B to #4ADE80
            const t = Math.random();
            colors[i * 3] = 1.0 - t * 0.5;     // R
            colors[i * 3 + 1] = 0.42 + t * 0.3;  // G
            colors[i * 3 + 2] = 0.42 + t * 0.3;  // B
        }
        
        particlesGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        particlesGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
        
        const particlesMaterial = new THREE.PointsMaterial({
            size: 0.15,
            vertexColors: true,
            transparent: true,
            opacity: 0.8,
            blending: THREE.AdditiveBlending
        });
        
        const particles = new THREE.Points(particlesGeometry, particlesMaterial);
        scene.add(particles);
        
        // Create floating geometric shapes
        const shapes = [];
        const shapeColors = [0xFF6B6B, 0x4ADE80, 0xFF6B6B, 0x4ADE80];
        
        for (let i = 0; i < 5; i++) {
            const geometry = new THREE.IcosahedronGeometry(0.5 + Math.random() * 0.5, 1, 0);
            const material = new THREE.MeshBasicMaterial({
                color: shapeColors[i % shapeColors.length],
                wireframe: true,
                transparent: true,
                opacity: 0.3
            });
            
            const mesh = new THREE.Mesh(geometry, material);
            mesh.position.set(
                (Math.random() - 0.5) * 15,
                (Math.random() - 0.5) * 15,
                (Math.random() - 0.5) * 10 - 5
            );
            mesh.rotation.set(
                Math.random() * Math.PI,
                Math.random() * Math.PI,
                Math.random() * Math.PI
            );
            
            scene.add(mesh);
            shapes.push({
                mesh: mesh,
                rotationSpeed: {
                    x: (Math.random() - 0.5) * 0.01,
                    y: (Math.random() - 0.5) * 0.01,
                    z: (Math.random() - 0.5) * 0.01
                },
                floatSpeed: Math.random() * 0.005 + 0.002,
                floatOffset: Math.random() * Math.PI * 2
            });
        }
        
        // Camera position
        camera.position.z = 15;
        
        // Animation loop
        let time = 0;
        function animate() {
            requestAnimationFrame(animate);
            time += 0.01;
            
            // Rotate particles
            particles.rotation.y = time * 0.1;
            particles.rotation.x = time * 0.05;
            
            // Animate shapes
            shapes.forEach(shape => {
                shape.mesh.rotation.x += shape.rotationSpeed.x;
                shape.mesh.rotation.y += shape.rotationSpeed.y;
                shape.mesh.rotation.z += shape.rotationSpeed.z;
                
                // Floating motion
                shape.mesh.position.y += Math.sin(time + shape.floatOffset) * shape.floatSpeed;
            });
            
            // Subtle camera movement
            camera.position.x = Math.sin(time * 0.2) * 2;
            camera.position.y = Math.cos(time * 0.15) * 1.5;
            camera.lookAt(scene.position);
            
            renderer.render(scene, camera);
        }
        
        animate();
        
        // Handle resize
        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });
        
        // Notify Flutter that scene is loaded
        window.flutter_inappwebview_ready = true;
    </script>
</body>
</html>
    ''';

    return html;
  }
}
