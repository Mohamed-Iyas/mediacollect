import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shots_studio/models/screenshot_model.dart';
import 'package:shots_studio/models/video_model.dart';
import 'package:animations/animations.dart';
import 'package:video_player/video_player.dart';

class MediaCard extends StatelessWidget {
  final dynamic media;
  final VoidCallback? onTap;
  final Widget Function(BuildContext)? destinationBuilder;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onCorruptionDetected;

  const MediaCard({
    super.key,
    required this.media,
    this.onTap,
    this.destinationBuilder,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onSelectionToggle,
    this.onCorruptionDetected,
  });

  @override
  Widget build(BuildContext context) {
    if (media is Screenshot) {
      return _buildScreenshotCard(context);
    } else if (media is Video) {
      return _buildVideoCard(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildScreenshotCard(BuildContext context) {
    final screenshot = media as Screenshot;
    const double borderRadius = 12.0;

    Widget imageWidget;
    if (screenshot.path != null) {
      final file = File(screenshot.path!);
      if (file.existsSync()) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(
            borderRadius - 3.0,
          ), // Adjust for border width
          child: Image.file(
            file,
            key: ValueKey(
              'card_${screenshot.id}',
            ), // Stable key for better caching
            fit: BoxFit.cover,
            cacheWidth: 300,
            filterQuality:
                FilterQuality
                    .medium, // Balance quality and animation performance
            gaplessPlayback: true, // Prevent flickering during transitions
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200), // Faster fade-in
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
        );
      } else {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 3.0),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'File not found',
                    style: TextStyle(
                      fontSize: 8,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } else if (screenshot.bytes != null) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(
          borderRadius - 3.0,
        ), // Adjust for border width
        child: Image.memory(
          screenshot.bytes!,
          key: ValueKey(
            'card_memory_${screenshot.id}',
          ), // Stable key for better caching
          fit: BoxFit.cover,
          cacheWidth: 300,
          filterQuality:
              FilterQuality.medium, // Balance quality and animation performance
          gaplessPlayback: true, // Prevent flickering during transitions
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 200), // Faster fade-in
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 24,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      );
    } else {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 3.0),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return _buildCard(context, imageWidget);
  }

  Widget _buildCard(BuildContext context, Widget child) {
    const double borderRadius = 12.0;
    Widget cardContent = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryContainer,
            width: isSelected ? 4.0 : 3.0,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Stack(
          children: [
            // Using a plain container instead of Card to avoid double clipping
            RepaintBoundary(
              child: Container(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    borderRadius - (isSelected ? 4.0 : 3.0),
                  ),
                  color: Theme.of(context).cardColor,
                ),
                child: SizedBox.expand(child: child),
              ),
            ),

            // Selection overlay
            if (isSelectionMode)
              RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      borderRadius - (isSelected ? 4.0 : 3.0),
                    ),
                    color:
                        isSelected
                            ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.1),
                  ),
                ),
              ),

            // Selection indicator
            if (isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.8),
                    border: Border.all(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                      width: 2,
                    ),
                  ),
                  child:
                      isSelected
                          ? Icon(
                            Icons.check,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary,
                          )
                          : null,
                ),
              ),
          ],
        ),
      ),
    );

    // If a destination builder is provided and not in selection mode, use OpenContainer for transitions
    return RepaintBoundary(
      child:
          destinationBuilder != null && !isSelectionMode
              ? OpenContainer(
                transitionType: ContainerTransitionType.fade,
                transitionDuration: const Duration(
                  milliseconds: 250,
                ), // Faster, snappier animation
                closedElevation: 0,
                openElevation: 0,
                closedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                closedColor: Colors.transparent,
                openColor: Theme.of(context).colorScheme.surface,
                useRootNavigator:
                    false, // Better performance for nested navigation
                clipBehavior: Clip.antiAlias, // Smooth clipping
                closedBuilder:
                    (context, action) => RepaintBoundary(
                      child: _buildGestureDetector(cardContent),
                    ),
                openBuilder: (context, action) => destinationBuilder!(context),
              )
              : _buildGestureDetector(cardContent),
    );
  }

  Widget _buildGestureDetector(Widget child) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: isSelectionMode ? null : onLongPress,
      child: child,
    );
  }

  Widget _buildVideoCard(BuildContext context) {
    final video = media as Video;
    Widget thumbnailWidget;
    if (video.thumbnailPath != null && File(video.thumbnailPath!).existsSync()) {
      thumbnailWidget = Image.file(File(video.thumbnailPath!));
    } else {
      thumbnailWidget = Container(color: Colors.black);
    }

    return _buildCard(
      context,
      Stack(
        alignment: Alignment.center,
        children: [
          thumbnailWidget,
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
        ],
      ),
    );
  }
}
