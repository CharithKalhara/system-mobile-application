import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/session_controller.dart';
import '../cases/case_entry_screen.dart';
import '../cases/case_list_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _recentCases = [];
  String? _recentError;
  String? _error;
  int? _companyId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).dio.get('companies');
      final root = response.data;
      final rows = root is Map ? (root['data'] ?? root['companies']) : root;
      if (rows is! List) {
        throw const FormatException(
          'The server returned an unexpected company list.',
        );
      }
      if (!mounted) return;
      setState(() {
        _companies = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _companyId = _companies.isEmpty
            ? null
            : int.tryParse(_companies.first['id'].toString());
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.response?.statusCode == 404
              ? 'The mobile API is not available on this server yet.'
              : 'Could not load your permitted companies. Check the connection and retry.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _loadRecentCases();
  }

  Future<void> _loadRecentCases() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get(
            'cases',
            queryParameters: {'company_id': _companyId, 'per_page': 5},
          );
      final root = response.data;
      final rows = root is Map ? (root['data'] ?? root['cases']) : root;
      final list = rows is List
          ? rows
          : (rows is Map && rows['data'] is List
                ? rows['data'] as List
                : const []);
      if (mounted) {
        setState(() {
          _recentCases = list
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          _recentError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recentError = 'Recent submissions are unavailable.');
      }
    }
  }

  Future<void> _editCase(Map<String, dynamic> record) async {
    final caseId = int.tryParse(record['id']?.toString() ?? '');
    final companyId = _companyId;
    if (caseId == null || companyId == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CaseEntryScreen(
          companyId: companyId,
          caseId: caseId,
          initialData: record,
        ),
      ),
    );
    if (mounted) _loadRecentCases();
  }

  Future<void> _openAllCases() async {
    final companyId = _companyId;
    if (companyId == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CaseListScreen(companyId: companyId),
      ),
    );
    if (mounted) _loadRecentCases();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final canEnter = _companyId != null && !_loading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nadu Mobile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCompanies,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Ayubowan, ${session.name ?? 'Typing staff'}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (session.email != null) ...[
              const SizedBox(height: 4),
              Text(
                session.email!,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 24),
            const _ConnectivityCard(),
            const SizedBox(height: 24),
            Text(
              'Select company',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              _InfoCard(
                message: _error!,
                action: TextButton(
                  onPressed: _loadCompanies,
                  child: const Text('Retry'),
                ),
              ),
            if (!_loading && _error == null && _companies.isEmpty)
              const _InfoCard(
                message:
                    'No companies are currently available to this account.',
              ),
            if (_companies.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: _companyId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
                items: _companies
                    .map((company) {
                      final id = int.tryParse(company['id'].toString());
                      return DropdownMenuItem(
                        value: id,
                        child: Text(
                          company['company_name']?.toString() ?? 'Company',
                        ),
                      );
                    })
                    .where((item) => item.value != null)
                    .toList(),
                onChanged: (value) {
                  setState(() => _companyId = value);
                  _loadRecentCases();
                },
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: canEnter
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CaseEntryScreen(companyId: _companyId!),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('New case entry'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recent submissions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _companyId == null ? null : _openAllCases,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentError != null)
              Text(
                _recentError!,
                style: const TextStyle(color: Colors.black54),
              ),
            if (_recentError == null && _recentCases.isEmpty)
              const Text(
                'No recent submissions to show.',
                style: TextStyle(color: Colors.black54),
              ),
            for (final record in _recentCases)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    record['nadu_ankaya']?.toString() ?? 'Case record',
                  ),
                  subtitle: Text(record['created_at']?.toString() ?? ''),
                  onTap: () => _editCase(record),
                  trailing: IconButton(
                    tooltip: 'Edit case',
                    onPressed: () => _editCase(record),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Company access is provided by Nadu System. The app does not choose or send database table names.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityCard extends StatelessWidget {
  const _ConnectivityCard();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ConnectivityResult>>(
    stream: Connectivity().onConnectivityChanged,
    builder: (context, snapshot) {
      final connected =
          snapshot.hasData && !snapshot.data!.contains(ConnectivityResult.none);
      final checking = !snapshot.hasData;
      return Card(
        color: checking
            ? const Color(0xFFEAF0F2)
            : connected
            ? const Color(0xFFEAF4EE)
            : const Color(0xFFFFE8E6),
        child: ListTile(
          leading: Icon(
            checking
                ? Icons.cloud_queue_outlined
                : connected
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            color: checking
                ? Colors.blueGrey
                : connected
                ? const Color(0xFF286443)
                : Colors.red.shade800,
          ),
          title: Text(
            checking
                ? 'Checking connection…'
                : connected
                ? 'Online'
                : 'No internet connection',
          ),
          subtitle: Text(
            connected
                ? 'Submissions require a live server connection.'
                : 'Reconnect before submitting a case.',
          ),
        ),
      );
    },
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          ?action,
        ],
      ),
    ),
  );
}
