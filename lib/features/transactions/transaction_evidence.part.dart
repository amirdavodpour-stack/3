part of 'transaction_page.dart';

class EvidenceActions extends StatefulWidget {
  const EvidenceActions(
      {super.key,
      required this.repository,
      required this.uploadQueue,
      required this.jobId,
      required this.job,
      required this.onChanged});
  final TransactionRepository repository;
  final UploadQueue uploadQueue;
  final String jobId;
  final Map<String, dynamic> job;
  final VoidCallback onChanged;
  @override
  State<EvidenceActions> createState() => _EvidenceActionsState();
}

class _EvidenceActionsState extends State<EvidenceActions> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final st = '${widget.job['status'] ?? ''}';
    final canSubmitEvidence = st == 'IN_PROGRESS';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(height: 32),
      Text(
        HopeCopy.of(context).copy_work_execution_cb0edb9,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      if (canSubmitEvidence)
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => showDialog(
                    context: context,
                    builder: (_) => EvidenceDialog(
                      repository: widget.repository,
                      uploadQueue: widget.uploadQueue,
                      jobId: widget.jobId,
                      onDone: widget.onChanged,
                    ),
                  ),
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(HopeCopy.of(context).copy_submit_evidence_bf38455),
        ),
      if (!canSubmitEvidence)
        HopeSurface(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  Localizations.localeOf(context).languageCode == 'en'
                      ? 'Evidence upload becomes available while the work is in progress. Financial actions stay in the section above.'
                      : 'ثبت مستندات هنگام انجام کار در دسترس است. عملیات مالی از بخش بالا انجام می‌شود.',
                ),
              ),
            ],
          ),
        ),
    ]);
  }
}

class EvidenceDialog extends StatefulWidget {
  const EvidenceDialog(
      {super.key,
      required this.repository,
      required this.uploadQueue,
      required this.jobId,
      required this.onDone});
  final TransactionRepository repository;
  final UploadQueue uploadQueue;
  final String jobId;
  final VoidCallback onDone;
  @override
  State<EvidenceDialog> createState() => _EvidenceDialogState();
}

class _EvidenceDialogState extends State<EvidenceDialog> {
  final uri = TextEditingController();
  final notes = TextEditingController();
  bool busy = false;
  File? file;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    uri.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final selected = await EvidencePicker().pickFile();
    if (mounted && selected != null) setState(() => file = selected);
  }

  Future<void> send() async {
    setState(() => busy = true);
    try {
      String evidenceUri = uri.text.trim();
      if (file != null) {
        // Retry with backoff via the upload queue instead of a single
        // direct attempt, so a flaky connection doesn't force the user
        // to re-pick the file and resubmit from scratch.
        final uploaded = await widget.uploadQueue
            .uploadNowWithRetry('/storage/upload', file!);
        if (uploaded is Map && uploaded['key'] is String) {
          evidenceUri = 'storage://${uploaded['key']}';
        }
      }
      if (evidenceUri.isEmpty) {
        throw StateError('Evidence file or URI is required');
      }
      await widget.repository.submitEvidence(
        widget.jobId,
        uri: evidenceUri,
        notes: notes.text.trim(),
        type: file != null ? 'FILE' : 'DELIVERY_LINK',
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onDone();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                HopeCopy.of(context).copy_could_not_submit_evidence_9d09019)));
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          title: Row(children: [
            const HopeIconTile(Icons.upload_file_rounded, size: 42),
            const SizedBox(width: 10),
            Expanded(
                child: Text(HopeCopy.of(context).copy_submit_evidence_bf38455))
          ]),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
                onPressed: busy ? null : pick,
                icon: const Icon(Icons.attach_file),
                label: Text(file == null
                    ? HopeCopy.of(context).copy_pick_file
                    : file!.path.split('/').last)),
            TextField(
                controller: uri,
                decoration: InputDecoration(
                    labelText:
                        HopeCopy.of(context).copy_link_uri_optional_1d2307a)),
            TextField(
                controller: notes,
                decoration: InputDecoration(
                    labelText: HopeCopy.of(context).copy_description_24d1e57))
          ])),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: Text(HopeCopy.of(context).copy_cancel_9955c4b)),
            FilledButton(
                onPressed: busy ? null : send,
                child: Text(HopeCopy.of(context).copy_submit_201d121))
          ]);
}
