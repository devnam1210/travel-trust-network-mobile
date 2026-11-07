import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../controllers/auth_controller.dart';
import '../../models/place_model.dart';
import '../../models/visit_model.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/place_service.dart';
import '../../services/visit_service.dart';
import '../auth/widgets/error_notice.dart';
import 'visit_history_screen.dart';
import 'visit_summary.dart';

// Fetch the target independently of a detail page that may have cached it.
final visitPlaceProvider = FutureProvider.autoDispose
    .family<PlaceDetailModel, String>((ref, placeId) {
      return ref.watch(placeServiceProvider).getPlaceDetail(placeId);
    });

class VisitScreen extends ConsumerStatefulWidget {
  const VisitScreen({
    super.key,
    required this.placeId,
    this.visitId,
    this.initialVisit,
  });

  final String placeId;
  final String? visitId;
  final VisitModel? initialVisit;

  @override
  ConsumerState<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends ConsumerState<VisitScreen> {
  VisitModel? _visit;
  Position? _position;
  bool _busy = false;
  bool _needsConfirmation = false;
  String? _error;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    _visit = widget.initialVisit;
    if (widget.visitId != null || _visit != null) {
      _needsConfirmation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reloadVisit();
      });
    }
  }

  Future<void> _checkIn() async {
    if (_busy || _visit != null || _needsConfirmation) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorCode = null;
    });
    var sent = false;
    try {
      ref.invalidate(visitPlaceProvider(widget.placeId));
      await ref.read(visitPlaceProvider(widget.placeId).future);
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
      if (!mounted ||
          ref.read(authControllerProvider).status != AuthStatus.authenticated) {
        return;
      }
      setState(() => _position = position);
      sent = true;
      final visit = await ref
          .read(visitServiceProvider)
          .checkIn(
            placeId: widget.placeId,
            userLat: position.latitude,
            userLng: position.longitude,
            gpsAccuracy: position.hasAccuracy ? position.accuracy : null,
            isMocked: position.isMocked,
          );
      if (!mounted) return;
      setState(() => _visit = visit);
      ref.invalidate(visitHistoryProvider);
    } catch (error) {
      if (!mounted) return;
      _showError(error, mutationSent: sent);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _measurePosition() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorCode = null;
      _position = null;
    });
    try {
      ref.invalidate(visitPlaceProvider(widget.placeId));
      await ref.read(visitPlaceProvider(widget.placeId).future);
      final position = await ref
          .read(locationServiceProvider)
          .getCurrentPosition();
      if (mounted) setState(() => _position = position);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Không thể kiểm tra vị trí. Vui lòng thử lại.';
        _errorCode = error is ApiException ? error.code : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _positionDetails() {
    final placeAsync = ref.watch(visitPlaceProvider(widget.placeId));
    final position = _position;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kiểm tra vị trí check-in'),
            const SizedBox(height: 8),
            placeAsync.when(
              loading: () => const Text('Đang tải vị trí địa điểm…'),
              error: (_, _) => const Text('Chưa tải được vị trí địa điểm.'),
              data: (place) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name),
                  SelectableText(
                    'Tọa độ địa điểm: ${place.latitude.toStringAsFixed(6)}, ${place.longitude.toStringAsFixed(6)}',
                  ),
                  Text(
                    'Bán kính check-in: ${place.allowedRadiusM.toStringAsFixed(0)} m',
                  ),
                  if (position != null)
                    Text(
                      'Khoảng cách ước tính: ${Geolocator.distanceBetween(position.latitude, position.longitude, place.latitude, place.longitude).toStringAsFixed(1)} m',
                    ),
                ],
              ),
            ),
            if (position != null) ...[
              const Divider(),
              SelectableText(
                'GPS điện thoại: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
              ),
              Text(
                position.hasAccuracy
                    ? 'Sai số ước tính: ±${position.accuracy.toStringAsFixed(1)} m'
                    : 'Điện thoại chưa cung cấp sai số vị trí.',
              ),
              Text('Thời điểm đo: ${position.timestamp.toLocal()}'),
              if (!position.hasAccuracy || position.accuracy > 50)
                const Text(
                  'Vị trí chưa ổn định. Hãy bật Vị trí chính xác và thử đo lại ở nơi thoáng.',
                ),
            ],
            if (_visit == null && !_needsConfirmation)
              OutlinedButton.icon(
                onPressed: _busy ? null : _measurePosition,
                icon: const Icon(Icons.my_location),
                label: const Text('Kiểm tra GPS / Đo lại'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkOut() async {
    if (_busy || _visit?.isOpen != true || _needsConfirmation) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorCode = null;
    });
    try {
      final visit = await ref.read(visitServiceProvider).checkOut(_visit!.id);
      if (!mounted) return;
      setState(() => _visit = visit);
      ref.invalidate(visitHistoryProvider);
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } catch (error) {
      if (!mounted) return;
      _showError(error, mutationSent: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error, {bool mutationSent = false}) {
    final apiError = error is ApiException ? error : null;
    final uncertain =
        mutationSent && (apiError == null || apiError.isUncertain);
    setState(() {
      _errorCode = apiError?.code;
      _needsConfirmation =
          uncertain ||
          _errorCode == 'ALREADY_CHECKED_OUT' ||
          _errorCode == 'SINGLE_OPEN_VISIT';
      _error = uncertain
          ? 'Chưa xác nhận được kết quả; backend có thể đã xử lý. Hãy tải lại trạng thái hoặc mở lịch sử trước khi thử lại.'
          : apiError?.message ??
                'Không thể hoàn tất thao tác. Vui lòng thử lại.';
    });
  }

  Future<void> _reloadVisit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorCode = null;
    });
    try {
      final visits = await ref.read(visitServiceProvider).getMyHistory();
      if (!mounted) return;
      final id = _visit?.id ?? widget.visitId;
      VisitModel? found;
      for (final visit in visits) {
        if (id != null ? visit.id == id : visit.isOpen) {
          found = visit;
          break;
        }
      }
      final previousVisit = _visit;
      setState(() {
        _visit = found;
        _needsConfirmation = id != null && found == null;
        if (_needsConfirmation) {
          _error = 'Không tìm thấy chuyến đi trong lịch sử của bạn.';
        }
      });
      if (previousVisit?.id != found?.id ||
          previousVisit?.status != found?.status) {
        ref.invalidate(visitHistoryProvider);
      }
      if (found?.status == 'VERIFIED') {
        await ref.read(authControllerProvider.notifier).refreshProfile();
      }
    } catch (error) {
      if (mounted) {
        // Keep confirmation required when a reconciliation request also fails.
        final needsConfirmation = _needsConfirmation;
        _showError(error);
        setState(() => _needsConfirmation = needsConfirmation);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const VisitHistoryScreen()));
    if (mounted) await _reloadVisit();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('GPS Check-in / Check-out')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 16),
        if (_visit != null)
          VisitSummary(visit: _visit!)
        else
          Text('Địa điểm: ${widget.placeId}'),
        if (_visit == null) _positionDetails(),
        const SizedBox(height: 16),
        if (_error != null) ...[
          ErrorNotice(message: _error!),
          const SizedBox(height: 12),
        ],
        if (_errorCode == 'GPS_DISABLED')
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await Geolocator.openLocationSettings();
                  },
            child: const Text('Mở cài đặt GPS'),
          ),
        if (_errorCode == 'LOCATION_DENIED_FOREVER' ||
            _errorCode == 'LOCATION_REDUCED_ACCURACY')
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await Geolocator.openAppSettings();
                  },
            child: const Text('Mở cài đặt ứng dụng'),
          ),
        if (_visit == null &&
            widget.visitId == null &&
            !_needsConfirmation) ...[
          const Text(
            'Check-in sẽ lấy vị trí hiện tại. Cờ vị trí giả do thiết bị báo có giới hạn và không chứng minh vị trí là thật.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _checkIn,
            child: const Text('Check-in'),
          ),
        ],
        if (_visit?.isOpen == true && !_needsConfirmation)
          FilledButton(
            onPressed: _busy ? null : _checkOut,
            child: const Text('Check-out'),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _reloadVisit,
          child: const Text('Tải lại trạng thái từ lịch sử'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : _openHistory,
          child: const Text('Lịch sử chuyến đi'),
        ),
      ],
    ),
  );
}
