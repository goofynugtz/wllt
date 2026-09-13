import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_provider.dart';
import '../services/ai_service.dart';
import '../services/model_manifest_service.dart';

/// Dev-mode only: lists every model in the R2 manifest and lets you
/// download, delete, and switch the active one for testing. Release builds
/// never route here — see `_buildLabsCard` in settings_screen.dart, which
/// auto-picks by RAM instead.
class ModelLabScreen extends StatefulWidget {
  const ModelLabScreen({super.key});

  @override
  State<ModelLabScreen> createState() => _ModelLabScreenState();
}

class _ModelLabScreenState extends State<ModelLabScreen> {
  late Future<List<ModelSpec>> _manifest;
  Map<String, bool> _downloaded = {};

  @override
  void initState() {
    super.initState();
    _manifest = ModelManifestService.fetch();
    _manifest.then((models) => _refreshDownloaded(models));
  }

  Future<void> _refreshDownloaded(List<ModelSpec> models) async {
    final ai = context.read<AiProvider>();
    final entries = await Future.wait(
      models.map((s) async => MapEntry(s.id, await ai.isModelDownloaded(s.id))),
    );
    if (!mounted) return;
    setState(() => _downloaded = Map.fromEntries(entries));
  }

  Future<void> _download(ModelSpec spec, List<ModelSpec> models) async {
    final ai = context.read<AiProvider>();
    try {
      await ai.downloadModel(spec);
      await _refreshDownloaded(models);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> _delete(ModelSpec spec, List<ModelSpec> models) async {
    final ai = context.read<AiProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete downloaded model?'),
        content: Text('${spec.sizeLabel} will be freed from your device.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ai.deleteDownloadedModel(spec);
    await _refreshDownloaded(models);
  }

  Future<void> _setActive(ModelSpec spec) async {
    final ai = context.read<AiProvider>();
    await ai.selectActiveModel(spec);
    if (!mounted) return;
    if (ai.state == AiModelState.error) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load model')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Model Lab')),
      body: FutureBuilder<List<ModelSpec>>(
        future: _manifest,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Failed to load model list: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() => _manifest = ModelManifestService.fetch()
                      ..then((models) => _refreshDownloaded(models))),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final models = snapshot.data!;
          final ai = context.watch<AiProvider>();
          return ListView.separated(
            itemCount: models.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final spec = models[i];
              return _ModelRow(
                spec: spec,
                isDownloading: ai.downloadingId == spec.id,
                downloadProgress: ai.downloadProgress,
                isDownloaded: _downloaded[spec.id] ?? false,
                isActive: (_downloaded[spec.id] ?? false) && ai.activeModelId == spec.id,
                onDownload: () => _download(spec, models),
                onCancel: ai.cancelDownload,
                onSetActive: () => _setActive(spec),
                onDelete: () => _delete(spec, models),
              );
            },
          );
        },
      ),
    );
  }
}

/// One fixed-height row — layout never changes shape between not-downloaded,
/// downloading, downloaded, and active, only the trailing action swaps.
class _ModelRow extends StatelessWidget {
  final ModelSpec spec;
  final bool isDownloading;
  final double downloadProgress;
  final bool isDownloaded;
  final bool isActive;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;

  const _ModelRow({
    required this.spec,
    required this.isDownloading,
    required this.downloadProgress,
    required this.isDownloaded,
    required this.isActive,
    required this.onDownload,
    required this.onCancel,
    required this.onSetActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 4),
                Checkbox(
                  value: isActive,
                  onChanged: (!isDownloaded || isActive) ? null : (_) => onSetActive(),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        spec.sizeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 72, child: Center(child: _trailing(context))),
                const SizedBox(width: 4),
              ],
            ),
          ),
          SizedBox(
            height: 3,
            child: isDownloading
                ? LinearProgressIndicator(value: downloadProgress)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context) {
    if (isDownloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Cancel',
            onPressed: onCancel,
          ),
        ],
      );
    }
    if (!isDownloaded) {
      return IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Download',
        onPressed: onDownload,
      );
    }
    return IconButton(
      icon: const Icon(Icons.delete_outline),
      tooltip: 'Delete',
      color: Theme.of(context).colorScheme.error,
      onPressed: onDelete,
    );
  }
}
