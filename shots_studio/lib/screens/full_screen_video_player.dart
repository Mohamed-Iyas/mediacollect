import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shots_studio/models/video_model.dart';
import 'package:path_provider/path_provider.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final List<Video> videos;
  final int initialIndex;

  const FullScreenVideoPlayer({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late PageController _pageController;
  late VideoPlayerController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initializeController(_currentIndex);
  }

  void _initializeController(int index) async {
    final video = widget.videos[index];
    if (video.path != null && File(video.path!).existsSync()) {
      _controller = VideoPlayerController.file(File(video.path!))
        ..initialize().then((_) {
          setState(() {});
          _controller.play();
        });
    } else if (video.bytes != null) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${video.title}');
      await tempFile.writeAsBytes(video.bytes!);
      _controller = VideoPlayerController.file(tempFile)
        ..initialize().then((_) {
          setState(() {});
          _controller.play();
        });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    _controller.dispose();
    setState(() {
      _currentIndex = index;
    });
    _initializeController(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.videos[_currentIndex].title ?? 'Video'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          return Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                        _buildControls(),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 20,
      child: IconButton(
        icon: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 50,
        ),
        onPressed: () {
          setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
        },
      ),
    );
  }
}
