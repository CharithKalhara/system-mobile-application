import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';

class CaseEntryScreen extends ConsumerStatefulWidget {
  const CaseEntryScreen({super.key, required this.companyId});
  final int companyId;

  @override
  ConsumerState<CaseEntryScreen> createState() => _CaseEntryScreenState();
}

class _CaseEntryScreenState extends ConsumerState<CaseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    for (final field in _caseFields) field.key: TextEditingController(),
  };
  final List<_Attachment> _attachments = [];
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseDate(String key) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date != null) {
      _controllers[key]!.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<void> _addFromCamera() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() => _attachments.add(_Attachment(image.name, image.path)));
    }
  }

  Future<void> _addFiles() async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (selection.isEmpty || !mounted) return;
    final files = <_Attachment>[];
    var rejected = 0;
    for (final file in selection) {
      final size = await file.length();
      if (file.path != null && size != null && size <= 10 * 1024 * 1024) {
        files.add(_Attachment(file.name, file.path!));
      } else {
        rejected++;
      }
    }
    if (!mounted) return;
    setState(() => _attachments.addAll(files));
    if (rejected > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attachments must be PDF or image files under 10 MB.'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (connectivity.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet is required. The case was not submitted.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final values = <String, dynamic>{'company_id': widget.companyId};
      for (final field in _caseFields) {
        final value = _controllers[field.key]!.text.trim();
        if (value.isNotEmpty) values[field.key] = value;
      }
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post(
            'cases',
            data: values,
            options: Options(
              headers: {
                'Idempotency-Key': DateTime.now().microsecondsSinceEpoch
                    .toString(),
              },
            ),
          );
      final root = response.data;
      final data = root is Map && root['data'] is Map
          ? root['data'] as Map
          : root;
      final recordId = data is Map
          ? (data['id'] ?? data['nadu_ankaya'] ?? 'Saved')
          : 'Saved';
      var uploadProblem = false;
      for (final attachment in _attachments) {
        try {
          final form = FormData.fromMap({
            'case_id': data is Map ? data['id'] : null,
            'file': await MultipartFile.fromFile(
              attachment.path,
              filename: attachment.name,
            ),
          });
          await ref.read(apiClientProvider).dio.post('attachments', data: form);
        } catch (_) {
          uploadProblem = true;
        }
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(
            uploadProblem
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: uploadProblem
                ? Colors.orange.shade800
                : const Color(0xFF286443),
            size: 42,
          ),
          title: Text(
            uploadProblem ? 'Case saved with upload issue' : 'Case submitted',
          ),
          content: Text(
            uploadProblem
                ? 'Record $recordId was saved, but one or more attachments did not upload. Contact your administrator before retrying the case.'
                : 'Record ID: $recordId',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.statusCode == 422
          ? _validationMessage(error.response?.data)
          : error.response?.statusCode == 403
          ? 'You are not authorised to enter cases for this company.'
          : error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout
          ? 'Connection lost. The case was not submitted.'
          : 'Submission failed. Please review the form and try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submission failed. No confirmation was received.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New case entry')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _section('නඩු', [
            _textField(_caseFields[0]),
            _dateField(_caseFields[1]),
            _textField(_caseFields[2]),
          ]),
          _section('ණයකරු 1', _personFields('nayakaru1_')),
          _section('ණයකරු 2', _personFields('nayakaru2_')),
          _section('ඇපකරු 1', _personFields('aepakaru1_')),
          _section('ඇපකරු 2', _personFields('aepakaru2_')),
          _section(
            'මූල්‍ය විස්තර',
            _caseFields
                .skip(23)
                .map(
                  (field) => field.key == 'awasan_mudal_bendima'
                      ? _dateField(field)
                      : _textField(field),
                )
                .toList(),
          ),
          _attachmentsCard(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Submission requires an active connection. Form data is not saved on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit case'),
          ),
        ],
      ),
    ),
  );

  Widget _section(String title, List<Widget> fields) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: field,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _textField(_CaseField field) => TextFormField(
    controller: _controllers[field.key],
    keyboardType: field.numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: field.label,
      prefixIcon: field.numeric ? const Icon(Icons.numbers) : null,
    ),
    validator: (value) {
      if (field.required && (value == null || value.trim().isEmpty)) {
        return 'මෙය අනිවාර්යයි';
      }
      if (field.numeric &&
          value != null &&
          value.trim().isNotEmpty &&
          num.tryParse(value.trim()) == null) {
        return 'Enter a valid number';
      }
      return null;
    },
  );

  Widget _dateField(_CaseField field) => TextFormField(
    controller: _controllers[field.key],
    readOnly: true,
    onTap: () => _chooseDate(field.key),
    decoration: InputDecoration(
      labelText: field.label,
      prefixIcon: const Icon(Icons.calendar_today_outlined),
    ),
  );

  List<Widget> _personFields(String prefix) => _caseFields
      .where((field) => field.key.startsWith(prefix))
      .map(_textField)
      .toList();

  Widget _attachmentsCard() => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documents',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _addFromCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
              OutlinedButton.icon(
                onPressed: _addFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Choose files'),
              ),
            ],
          ),
          for (var index = 0; index < _attachments.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(
                _attachments[index].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _previewAttachment(_attachments[index]),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _attachments.removeAt(index)),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _previewAttachment(_Attachment attachment) async {
    final isImage = RegExp(
      r'\.(png|jpe?g)$',
      caseSensitive: false,
    ).hasMatch(attachment.name);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          attachment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: isImage
            ? Image.file(File(attachment.path), fit: BoxFit.contain)
            : const Text(
                'PDF selected. The document will be uploaded securely when the case is submitted.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Attachment {
  const _Attachment(this.name, this.path);
  final String name;
  final String path;
}

class _CaseField {
  const _CaseField(
    this.key,
    this.label, {
    this.required = false,
    this.numeric = false,
  });
  final String key;
  final String label;
  final bool required;
  final bool numeric;
}

const _caseFields = <_CaseField>[
  _CaseField('nadu_ankaya', 'නඩු අංකය', required: true),
  _CaseField('dun_dinaya', 'දුන් දිනය'),
  _CaseField('kalaya', 'කාලය'),
  _CaseField('nayakaru1_nama', 'නම'),
  _CaseField('nayakaru1_samajika_ankaya', 'සාමාජික අංකය'),
  _CaseField('nayakaru1_lipinaya1', 'ලිපිනය 1'),
  _CaseField('nayakaru1_lipinaya2', 'ලිපිනය 2'),
  _CaseField('nayakaru1_lipinaya3', 'ලිපිනය 3'),
  _CaseField('nayakaru2_nama', 'නම'),
  _CaseField('nayakaru2_samajika_ankaya', 'සාමාජික අංකය'),
  _CaseField('nayakaru2_lipinaya1', 'ලිපිනය 1'),
  _CaseField('nayakaru2_lipinaya2', 'ලිපිනය 2'),
  _CaseField('nayakaru2_lipinaya3', 'ලිපිනය 3'),
  _CaseField('aepakaru1_nama', 'නම'),
  _CaseField('aepakaru1_samajika_ankaya', 'සාමාජික අංකය'),
  _CaseField('aepakaru1_lipinaya1', 'ලිපිනය 1'),
  _CaseField('aepakaru1_lipinaya2', 'ලිපිනය 2'),
  _CaseField('aepakaru1_lipinaya3', 'ලිපිනය 3'),
  _CaseField('aepakaru2_nama', 'නම'),
  _CaseField('aepakaru2_samajika_ankaya', 'සාමාජික අංකය'),
  _CaseField('aepakaru2_lipinaya1', 'ලිපිනය 1'),
  _CaseField('aepakaru2_lipinaya2', 'ලිපිනය 2'),
  _CaseField('aepakaru2_lipinaya3', 'ලිපිනය 3'),
  _CaseField('dun_naya_mudala', 'දුන් ණය මුදල', numeric: true),
  _CaseField('arawul_mudala', 'ආරවුල් මුදල', numeric: true),
  _CaseField('poli_prathishathaya', 'පොලී ප්‍රතිශතය', numeric: true),
  _CaseField('awasan_mudal_bendima', 'අවසන් මුදල් බැඳීම'),
  _CaseField('dina_ganuna', 'දින ගණන', numeric: true),
  _CaseField('apal_pa', 'ඇපැල් පැ', numeric: true),
  _CaseField('apal_vi', 'ඇපැල් වි', numeric: true),
  _CaseField('mul_mudala', 'මුල් මුදල', numeric: true),
  _CaseField('poliya', 'පොලිය', numeric: true),
  _CaseField('nadu_gasthu', 'නඩු ගාස්තු', numeric: true),
  _CaseField('total', 'එකතුව', numeric: true),
];

String _validationMessage(dynamic body) {
  if (body is Map && body['errors'] is Map) {
    final errors = body['errors'] as Map;
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
    }
  }
  return 'Please check the submitted values.';
}
