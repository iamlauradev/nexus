import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../theme/rpg_theme.dart';
import '../services/api_service.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  bool _exporting = false;
  bool _importing = false;

  // Manual paste fallback
  final _pasteCtrl = TextEditingController();
  String _pasteFormat = 'own_json';

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final data = await ApiService.exportData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) return;
      setState(() => _exporting = false);
      _showExportDialog(jsonStr);
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) _showError('Error al exportar: $e');
    }
  }

  void _showExportDialog(String jsonStr) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RpgColors.surface,
        title: const Text('Exportar colección', style: TextStyle(
          color: RpgColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 200,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RpgColors.charcoal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    jsonStr.length > 2000 ? '${jsonStr.substring(0, 2000)}…' : jsonStr,
                    style: const TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copiado al portapapeles'), backgroundColor: RpgColors.statusComplete));
                    },
                    icon: const Icon(Icons.copy, size: 16, color: RpgColors.gold),
                    label: const Text('Copiar', style: TextStyle(color: RpgColors.gold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: RpgColors.border)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        final tempDir = Directory.systemTemp;
                        final file = File('${tempDir.path}/nexus_export.json');
                        await file.writeAsString(jsonStr);
                        await Share.shareXFiles([XFile(file.path)], text: 'Nexus — Mi colección');
                      } catch (_) {
                        await Share.share(jsonStr, subject: 'Nexus — Mi colección');
                      }
                    },
                    icon: const Icon(Icons.share_outlined, size: 16, color: RpgColors.obsidian),
                    label: const Text('Compartir', style: TextStyle(color: RpgColors.obsidian, fontSize: 12)),
                  ),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: RpgColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Future<void> _importFile(String format) async {
    setState(() => _importing = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        setState(() => _importing = false);
        _showError('No se pudo leer el archivo');
        return;
      }
      final content = utf8.decode(bytes);
      await _doImport(format, content);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      _showPasteDialog(format);
    }
  }

  Future<void> _doImport(String format, String content) async {
    setState(() => _importing = true);
    try {
      final result = await ApiService.importData(format, content);
      if (!mounted) return;
      setState(() => _importing = false);
      _showImportResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      _showError('Error al importar: $e');
    }
  }

  void _showImportResult(Map<String, dynamic> result) {
    final imported = result['imported'] ?? result['added'] ?? 0;
    final skipped  = result['skipped'] ?? result['duplicates'] ?? 0;
    final errors   = result['errors'] ?? result['failed'] ?? 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RpgColors.surface,
        title: const Text('Importación completada', style: TextStyle(
          color: RpgColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResultRow(Icons.check_circle_outline, 'Importados', '$imported', RpgColors.statusComplete),
            const SizedBox(height: 8),
            _ResultRow(Icons.skip_next_outlined, 'Saltados', '$skipped', RpgColors.statusPlan),
            const SizedBox(height: 8),
            _ResultRow(Icons.error_outline, 'Errores', '$errors', RpgColors.statusDropped),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPasteDialog(String format) {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          backgroundColor: RpgColors.surface,
          title: Text('Importar ${_formatLabel(format)}', style: const TextStyle(
            color: RpgColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pega el contenido del archivo aquí:', style: TextStyle(
                color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _pasteCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Contenido del archivo...',
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(color: RpgColors.textPrimary, fontFamily: 'Crimson', fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(ctx); _pasteCtrl.clear(); },
              child: const Text('Cancelar', style: TextStyle(color: RpgColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final content = _pasteCtrl.text.trim();
                if (content.isEmpty) return;
                Navigator.pop(ctx);
                _pasteCtrl.clear();
                await _doImport(format, content);
              },
              child: const Text('Importar'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLabel(String format) {
    switch (format) {
      case 'own_json': return 'JSON (Backup)';
      case 'mal_xml': return 'MAL (XML)';
      case 'letterboxd_csv': return 'Letterboxd (CSV)';
      default: return format;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: RpgColors.statusDropped));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / Exportar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // EXPORT
            _SectionHeader('EXPORTAR'),
            const SizedBox(height: 4),
            const Text('Descarga tu colección completa en formato JSON.',
              style: TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_outlined),
                label: Text(_exporting ? 'Exportando...' : 'Exportar mi colección (JSON)',
                  style: const TextStyle(fontSize: 13)),
              ),
            ),

            const SizedBox(height: 28),
            const Divider(color: RpgColors.border),
            const SizedBox(height: 16),

            // IMPORT
            _SectionHeader('IMPORTAR'),
            const SizedBox(height: 4),
            const Text('Importa tu historial desde distintas plataformas.',
              style: TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 14)),
            const SizedBox(height: 12),

            _ImportButton(
              icon: Icons.backup_outlined,
              label: 'Importar backup propio (JSON)',
              subtitle: 'Archivo exportado desde Nexus',
              color: RpgColors.gold,
              onTap: _importing ? null : () => _importFile('own_json'),
            ),
            const SizedBox(height: 10),
            _ImportButton(
              icon: Icons.list_alt_outlined,
              label: 'Importar desde MAL (XML)',
              subtitle: 'MyAnimeList export XML',
              color: RpgColors.statusWatching,
              onTap: _importing ? null : () => _importFile('mal_xml'),
            ),
            const SizedBox(height: 10),
            _ImportButton(
              icon: Icons.movie_outlined,
              label: 'Importar desde Letterboxd (CSV)',
              subtitle: 'Letterboxd diary/watched CSV',
              color: RpgColors.emissionAiring,
              onTap: _importing ? null : () => _importFile('letterboxd_csv'),
            ),

            if (_importing) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator(color: RpgColors.gold)),
              const SizedBox(height: 8),
              const Center(child: Text('Importando…', style: TextStyle(color: RpgColors.textMuted, fontFamily: 'Crimson'))),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
    fontSize: 13, color: RpgColors.textPrimary, letterSpacing: 0.5, fontWeight: FontWeight.w700));
}

class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: onTap != null ? RpgColors.charcoal : RpgColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                color: onTap != null ? RpgColors.textPrimary : RpgColors.textMuted,
                fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(
                color: RpgColors.textMuted, fontFamily: 'Crimson', fontSize: 12)),
            ],
          )),
          Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 14),
        ]),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ResultRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: RpgColors.textSecondary, fontFamily: 'Crimson', fontSize: 14)),
      const Spacer(),
      Text(value, style: TextStyle(color: color, fontFamily: 'DMSans', fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }
}
