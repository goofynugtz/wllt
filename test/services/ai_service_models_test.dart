import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma/flutter_gemma.dart' hide ModelSpec;
import 'package:wllt/services/ai_service.dart';

void main() {
  test('fileType is derived from the extension, modelType defaults to gemmaIt', () {
    final task = ModelSpec.direct(url: 'https://pub-xyz.r2.dev/gemma3-1b-it-int4.task', displayName: 'A', sizeLabel: '1 MB');
    expect(task.fileType, ModelFileType.task);
    expect(task.modelType, ModelType.gemmaIt);

    final litertlm = ModelSpec.direct(
      url: 'https://pub-xyz.r2.dev/gemma-4-E2B-it.litertlm',
      displayName: 'Gemma 4 E2B',
      sizeLabel: '2.41 GB',
      modelType: ModelType.gemma4,
    );
    expect(litertlm.fileType, ModelFileType.litertlm);
    expect(litertlm.modelType, ModelType.gemma4);
  });

  test('ModelSpec.direct derives id from the url filename', () {
    final spec = ModelSpec.direct(
      url: 'https://pub-xyz.r2.dev/gemma3-1b-it-int4.task',
      displayName: 'Gemma 3 1B',
      sizeLabel: '600.00 MB',
    );
    expect(spec.id, 'gemma3-1b-it-int4.task');
    expect(spec.hfUrl, spec.selfHostedUrl); // .direct() needs no HF-token resolution
  });

  test('two specs with different filenames get different ids', () {
    final a = ModelSpec.direct(url: 'https://pub-xyz.r2.dev/a.task', displayName: 'A', sizeLabel: '1 MB');
    final b = ModelSpec.direct(url: 'https://pub-xyz.r2.dev/b.task', displayName: 'B', sizeLabel: '2 MB');
    expect(a.id, isNot(b.id));
  });
}
