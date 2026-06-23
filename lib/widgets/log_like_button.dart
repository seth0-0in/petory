import 'package:flutter/material.dart';

// 좋아요 버튼 + 카운트.
//
// 사용 예:
//   LogLikeButton(
//     liked: log.isLikedBy(myUserId),
//     count: log.likeCount,
//     onTap: () => _toggleLike(log),
//     onCountTap: () => _showLikers(log),
//   )
//
// 탭 시 scale 1.0 → 1.3 → 1.0 튀기는 애니메이션.
class LogLikeButton extends StatefulWidget {
  final bool liked;
  final int count;
  final VoidCallback onTap;
  // 카운트 텍스트 탭. null이면 카운트 영역도 onTap으로 동작.
  final VoidCallback? onCountTap;
  final double iconSize;
  final bool dense;

  const LogLikeButton({
    super.key,
    required this.liked,
    required this.count,
    required this.onTap,
    this.onCountTap,
    this.iconSize = 22,
    this.dense = false,
  });

  @override
  State<LogLikeButton> createState() => _LogLikeButtonState();
}

class _LogLikeButtonState extends State<LogLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant LogLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.liked && widget.liked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.liked) {
      _controller.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final liked = widget.liked;
    final heartColor =
        liked ? Colors.red.shade400 : colorScheme.onSurfaceVariant;
    final countColor =
        liked ? Colors.red.shade400 : colorScheme.onSurfaceVariant;
    final hPad = widget.dense ? 6.0 : 10.0;
    final vPad = widget.dense ? 4.0 : 6.0;
    final iconBoxSize = widget.iconSize + 4;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _handleTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: iconBoxSize,
                height: iconBoxSize,
                child: Center(
                  child: ScaleTransition(
                    scale: _scale,
                    child: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: heartColor,
                      size: widget.iconSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onCountTap ?? _handleTap,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: Text(
                    '${widget.count}',
                    key: ValueKey<int>(widget.count),
                    style: TextStyle(
                      color: countColor,
                      fontSize: widget.dense ? 13 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
