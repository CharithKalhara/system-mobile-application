import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'case_entry_screen.dart';

class CaseListScreen extends ConsumerStatefulWidget {
  const CaseListScreen({super.key, required this.companyId});

  final int companyId;

  @override
  ConsumerState<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends ConsumerState<CaseListScreen> {
  final List<Map<String, dynamic>> _cases = [];
  final TextEditingController _searchController = TextEditingController();
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _loadedSearch = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  Future<void> _loadPage({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final requestedPage = reset ? 1 : _page + 1;
    final search = _searchController.text.trim();
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get(
            'cases',
            queryParameters: {
              'company_id': widget.companyId,
              'per_page': 25,
              'page': requestedPage,
              if (search.isNotEmpty) 'search': search,
            },
          );
      final root = response.data;
      final rows = root is Map ? root['data'] : null;
      final meta = root is Map && root['meta'] is Map
          ? Map<String, dynamic>.from(root['meta'] as Map)
          : <String, dynamic>{};
      if (rows is! List) {
        throw const FormatException('Unexpected case list response.');
      }
      if (!mounted) return;
      setState(() {
        if (reset) _cases.clear();
        _cases.addAll(
          rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)),
        );
        _page = requestedPage;
        _total = int.tryParse(meta['total']?.toString() ?? '') ?? _cases.length;
        _loadedSearch = search;
        _error = null;
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.response?.statusCode == 404
              ? 'This company is not available for mobile entry.'
              : 'Could not load cases. Check the connection and retry.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _editCase(Map<String, dynamic> record) async {
    final caseId = int.tryParse(record['id']?.toString() ?? '');
    if (caseId == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CaseEntryScreen(
          companyId: widget.companyId,
          caseId: caseId,
          initialData: record,
        ),
      ),
    );
    if (mounted) _loadPage(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cases')),
    body: RefreshIndicator(
      onRefresh: () => _loadPage(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _loadPage(reset: true),
            decoration: InputDecoration(
              labelText: 'Search cases',
              hintText: 'Case number or party name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: _searchController.text.isEmpty
                    ? 'Search'
                    : 'Clear search',
                onPressed: _searchController.text.isEmpty
                    ? () => _loadPage(reset: true)
                    : () {
                        _searchController.clear();
                        _loadPage(reset: true);
                      },
                icon: Icon(
                  _searchController.text.isEmpty ? Icons.search : Icons.clear,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              child: ListTile(
                title: Text(_error!),
                trailing: IconButton(
                  tooltip: 'Retry',
                  onPressed: () => _loadPage(reset: true),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
          if (!_loading && _error == null && _cases.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No cases found for this company.'),
            ),
          for (final record in _cases)
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(record['nadu_ankaya']?.toString() ?? 'Case record'),
                subtitle: Text(record['created_at']?.toString() ?? ''),
                onTap: () => _editCase(record),
                trailing: IconButton(
                  tooltip: 'Edit case',
                  onPressed: () => _editCase(record),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
          if (_loadedSearch == _searchController.text.trim() &&
              _cases.length < _total)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _loadPage(reset: false),
                icon: _loadingMore
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? 'Loading…' : 'Load more'),
              ),
            ),
        ],
      ),
    ),
  );
}
