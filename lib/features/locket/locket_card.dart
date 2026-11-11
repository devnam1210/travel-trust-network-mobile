import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../shared/motion/app_motion.dart';
import '../../shared/widgets/motion_feedback.dart';
import '../auth/auth_controller.dart';
import '../friends/friend_profile_screen.dart';
import '../messages/chat_screen.dart';
import '../messages/message_model.dart';
import 'locket_model.dart';
import 'locket_image_screen.dart';
import 'locket_service.dart';
import 'private_locket_image.dart';

class LocketCard extends ConsumerStatefulWidget {
  const LocketCard({
    super.key,
    required this.signal,
    this.showProfileLink = true,
  });
  final LocketSignal signal;
  final bool showProfileLink;
  @override
  ConsumerState<LocketCard> createState() => _LocketCardState();
}

class _LocketCardState extends ConsumerState<LocketCard> {
  late LocketSignal _signal = widget.signal;
  bool _busy = false;
  String? _error;
  bool _reactionPulse = false;

  @override
  void didUpdateWidget(covariant LocketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signal != widget.signal) _signal = widget.signal;
  }

  Future<void> _react(String value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(locketServiceProvider)
          .react(_signal.id, value == 'remove' ? null : value);
      if (mounted) {
        setState(() {
          _signal = updated;
          _reactionPulse = !AppMotion.reduced(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Không thể cập nhật reaction.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider.select((a) => a.user?.id));
    if (me == null) return const SizedBox.shrink();
    final ownReactions = _signal.reactions.where((r) => r.userId == me);
    final own = ownReactions.isEmpty ? null : ownReactions.first.emoji;
    final avatar = _signal.senderAvatarUrl;
    final time = _signal.sentAt?.toLocal();
    final timeLabel = time == null
        ? ''
        : '${time.day}/${time.month}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            onTap: widget.showProfileLink && _signal.senderId != null
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FriendProfileScreen(userId: _signal.senderId!),
                    ),
                  )
                : null,
            leading: CircleAvatar(
              child: avatar == null || avatar.isEmpty
                  ? const Icon(Icons.person_outline)
                  : ClipOval(
                      child: Image.network(
                        avatar,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        cacheWidth: AppMotion.imageWidth(context, 40),
                        frameBuilder: AppMotion.imageFrame,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person_outline),
                      ),
                    ),
            ),
            title: Text(_signal.senderName),
            subtitle: Text(timeLabel),
            trailing: _signal.is360Image ? const Text('360°') : null,
          ),
          GestureDetector(
            onTap: _signal.mediaId == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LocketImageScreen(
                        mediaId: _signal.mediaId!,
                        is360: _signal.is360Image,
                        title: _signal.placeName ?? _signal.senderName,
                      ),
                    ),
                  ),
            child: AspectRatio(
              aspectRatio: 1,
              child: RepaintBoundary(
                child: _signal.mediaId == null
                    ? const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.lock_outline),
                      )
                    : PrivateLocketImage(mediaId: _signal.mediaId!),
              ),
            ),
          ),
          if (_signal.caption?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_signal.caption!),
            ),
          if (_signal.placeName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('📍 ${_signal.placeName}'),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final r in _signal.reactions)
                  Tooltip(
                    message: r.userName,
                    child: Chip(label: Text('${r.emoji} ${r.userName}')),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              if (_signal.senderId != null &&
                  _signal.senderId != me &&
                  _signal.mediaId != null)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        peerId: _signal.senderId,
                        quote: PhotoQuote(
                          signalId: _signal.id,
                          mediaId: _signal.mediaId!,
                          senderName: _signal.senderName,
                          caption: _signal.caption,
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.reply_rounded),
                  label: const Text('Trả lời'),
                ),
              PopupMenuButton<String>(
                tooltip: 'Reaction',
                enabled: !_busy,
                onSelected: _react,
                itemBuilder: (_) => [
                  for (final emoji in LocketService.emojis)
                    PopupMenuItem(value: emoji, child: Text(emoji)),
                  if (own != null)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Xóa reaction'),
                    ),
                ],
                child: AnimatedScale(
                  scale: _reactionPulse ? 1.06 : 1,
                  duration: AppMotion.duration(context, AppMotion.feedback),
                  curve: AppMotion.curve,
                  onEnd: () {
                    if (_reactionPulse && mounted) {
                      setState(() => _reactionPulse = false);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: MotionSwitcher(
                      child: Text(
                        _busy ? 'Đang lưu…' : '${own ?? '♡'} Reaction',
                        key: ValueKey((_busy, own)),
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
