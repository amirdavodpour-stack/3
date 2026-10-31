part of 'jobs_page.dart';

extension _JobsSavedSearchActions on _JobsPageState {
  String _savedSearchName() {
    final parts = <String>[];
    if (_query.trim().isNotEmpty) parts.add(_query.trim());
    if (_kind != 'ALL') parts.add(opportunityKindLabel(context, _kind));
    if (_visibility != 'ALL') {
      parts.add(opportunityVisibilityLabel(context, _visibility));
    }
    if (_category != 'ALL') parts.add(_categoryLabel(context));
    if (_city != 'AUTO') {
      parts.add(
        _city == 'همه' ? HopeCopy.of(context).copy_all_cities : _city,
      );
    }
    return parts.isEmpty
        ? HopeCopy.of(context).copy_all_opportunities
        : parts.join(' • ');
  }

  void _setQuery(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) this._reloadForCurrentFilters();
    });
  }

  Future<void> _reloadForCurrentFilters() async {
    if (!mounted) return;
    final next = _loadOpportunities();
    setState(() { _future = next; });
    await next.catchError((_) => const <HopeJob>[]);
  }

  Future<void> _saveCurrentSearch() async {
    if (_savedSearchMutationBusy) return;
    setState(() => _savedSearchMutationBusy = true);
    var suggestedName = this._savedSearchName();
    try {
      final name = await showDialog<String>(
        context: context,
      builder: (context) => AlertDialog(
        title: Text(HopeCopy.of(context).copy_save_search),
        content: TextFormField(
          initialValue: suggestedName,
          onChanged: (value) => suggestedName = value,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(hintText: HopeCopy.of(context).copy_search_name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(HopeCopy.of(context).copy_cancel_9955c4b),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, suggestedName.trim()),
            child: Text(HopeCopy.of(context).copy_save_search),
          ),
        ],
      ),
      );
      if (!mounted || name == null || name.isEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      final saved = HopeSavedSearch(
        id: 'search-${now.hashCode.abs()}',
        name: name,
        query: _query,
        kind: _kind,
        visibility: _visibility,
        city: _city,
        category: _category,
        updatedAt: now,
      );
      await _applicationRegistry(context).savedSearches.upsert(saved);
      await _loadSavedSearches();
    } catch (error) {
      if (mounted) {
        HopeFeedback.show(
          context,
          apiErrorMessage(
            error,
            fallback: HopeCopy.of(context).copy_could_not_save_search,
          ),
          tone: HopeFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _savedSearchMutationBusy = false);
    }
  }

  Future<void> _openSavedSearches() async {
    if (_savedSearches.isEmpty) return;
    final selected = await showModalBottomSheet<HopeSavedSearch>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        String? deleteBusyId;
        return StatefulBuilder(
          builder: (context, setSheetState) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            shrinkWrap: true,
            itemCount: _savedSearches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _savedSearches[index];
              final deleting = deleteBusyId == item.id;
              return ListTile(
                title: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    item.query,
                    item.kind == 'ALL' ? '' : opportunityKindLabel(context, item.kind),
                    item.visibility == 'ALL'
                        ? ''
                        : opportunityVisibilityLabel(context, item.visibility),
                  ].where((value) => value.isNotEmpty).join(' • '),
                ),
                onTap: deleting ? null : () => Navigator.pop(context, item),
                trailing: IconButton(
                  tooltip: HopeCopy.of(context).copy_delete_b17eb9d,
                  onPressed: deleting
                      ? null
                      : () async {
                          setSheetState(() => deleteBusyId = item.id);
                          try {
                            await _applicationRegistry(context)
                                .savedSearches
                                .delete(item.id);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _loadSavedSearches();
                          } catch (error) {
                            if (!context.mounted) return;
                            setSheetState(() => deleteBusyId = null);
                            HopeFeedback.show(
                              context,
                              apiErrorMessage(
                                error,
                                fallback:
                                    HopeCopy.of(context)
                                        .copy_could_not_delete_saved_search,
                              ),
                              tone: HopeFeedbackTone.error,
                            );
                          }
                        },
                  icon: deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                     : HopeIcon(HopeV2Icons.close, size: 19, color: Theme.of(context).colorScheme.error),
                ),
              );
            },
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      _query = selected.query;
      _kind = selected.kind;
      _visibility = selected.visibility;
      _city = selected.city;
      _category = selected.category;
      _future = _loadOpportunities();
    });
  }
}
