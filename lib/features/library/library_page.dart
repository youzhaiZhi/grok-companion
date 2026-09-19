import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../engine/character.dart';
import '../../engine/tables.dart';
import '../../services/expression_store.dart';
import '../../services/settings_store.dart';
import '../creator/creator_page.dart';
import 'preview_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<RegisteredExpression> _customs = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<ExpressionStore> _store() async =>
      ExpressionStore(await getApplicationDocumentsDirectory());

  Future<void> _reload() async {
    final list = await (await _store()).loadAll();
    if (mounted) {
      setState(() {
        _customs = list;
        _loaded = true;
      });
    }
  }

  Future<void> _openCreator([RegisteredExpression? edit]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorPage(
          settingsStore: widget.settingsStore,
          edit: edit,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _delete(RegisteredExpression c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除「${c.cnName}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await (await _store()).delete(c.id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('表情库')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreator(),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _groupLabel(context, '预设表情 · 23'),
          _grid(
            context,
            [
              for (final id in Tables.presetStates)
                _Item(id: id, cnName: Tables.cnNames[id]!),
            ],
          ),
          _groupLabel(context, '我的自定义 · ${_customs.length}'),
          if (_customs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '还没有自定义表情，点右下角新建',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          _grid(
            context,
            [
              for (final c in _customs)
                _Item(
                  id: c.id,
                  cnName: c.cnName,
                  custom: c,
                  onEdit: () => _openCreator(c),
                  onDelete: () => _delete(c),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _grid(BuildContext context, List<_Item> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [for (final i in items) _card(context, i)],
    );
  }

  Widget _card(BuildContext context, _Item i) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 104,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PreviewPage(
              settingsStore: widget.settingsStore,
              id: i.id,
              cnName: i.cnName,
              custom: i.custom,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(Icons.circle_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(i.cnName,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (i.custom != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (i.onEdit != null)
                      _miniIcon(Icons.edit_outlined, i.onEdit!),
                    if (i.onDelete != null)
                      _miniIcon(
                          Icons.delete_outline_rounded, i.onDelete!),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniIcon(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14),
        ),
      );
}

class _Item {
  _Item({
    required this.id,
    required this.cnName,
    this.custom,
    this.onEdit,
    this.onDelete,
  });

  final String id;
  final String cnName;
  final RegisteredExpression? custom;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
}
