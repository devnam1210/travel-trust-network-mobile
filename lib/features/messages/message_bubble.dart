import 'package:flutter/material.dart';

import '../locket/private_locket_image.dart';
import 'message_model.dart';

class PhotoQuotePreview extends StatelessWidget {
  const PhotoQuotePreview({super.key, required this.quote, this.onRemove});
  final PhotoQuote quote;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PrivateLocketImage(mediaId: quote.mediaId),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ảnh của ${quote.senderName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (quote.caption?.isNotEmpty == true)
                Text(
                  quote.caption!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (onRemove != null)
          IconButton(
            tooltip: 'Bỏ trích dẫn',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
      ],
    ),
  );
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = message.sentAt?.toLocal();
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .82,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.quote != null) ...[
              PhotoQuotePreview(quote: message.quote!),
              const SizedBox(height: 8),
            ],
            Text(message.body),
            if (time != null)
              Text(
                MaterialLocalizations.of(context)
                    .formatTimeOfDay(TimeOfDay.fromDateTime(time)),
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ),
    );
  }
}
