import 'package:flutter/material.dart';
import '../blocs/dns_scanner/advanced_dns_scan_bloc.dart';
import '../blocs/dns_scanner/advanced_dns_scan_event.dart';
import '../blocs/dns_scanner/advanced_dns_scan_state.dart';
import '../models/advanced_dns_result.dart';
import '../models/profile.dart';

class AdvancedDnsScannerWidget extends StatefulWidget {
  final Profile profile;

  const AdvancedDnsScannerWidget({
    Key? key,
    required this.profile,
  }) : super(key: key);

  @override
  State<AdvancedDnsScannerWidget> createState() =>
      _AdvancedDnsScannerWidgetState();
}

class _AdvancedDnsScannerWidgetState extends State<AdvancedDnsScannerWidget> {
  late bool _testEDNS;
  late bool _testNXDOMAIN;
  late bool _testE2E;
  late bool _testPrism;
  late int _concurrency;
  late String? _filterCountry;
  late TextEditingController _prismKeyController;

  @override
  void initState() {
    super.initState();
    _testEDNS = true;
    _testNXDOMAIN = true;
    _testE2E = false;
    _testPrism = false;
    _concurrency = 5;
    _filterCountry = null;
    _prismKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _prismKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildOptionsCard(),
        const SizedBox(height: 16),
        _buildScanButton(),
      ],
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced DNS Testing Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildCheckboxOption(
              label: 'EDNS Support Detection',
              value: _testEDNS,
              onChanged: (v) => setState(() => _testEDNS = v ?? false),
              description: 'Detect EDNS0 support and capabilities',
            ),
            _buildCheckboxOption(
              label: 'NXDOMAIN Hijacking Detection',
              value: _testNXDOMAIN,
              onChanged: (v) => setState(() => _testNXDOMAIN = v ?? false),
              description: 'Detect if resolver hijacks non-existent domains',
            ),
            _buildCheckboxOption(
              label: 'End-to-End Tunnel Test',
              value: _testE2E,
              onChanged: (v) => setState(() => _testE2E = v ?? false),
              description: 'Test actual tunnel connectivity through resolver',
            ),
            _buildCheckboxOption(
              label: 'Prism Mode (HMAC Verification)',
              value: _testPrism,
              onChanged: (v) => setState(() => _testPrism = v ?? false),
              description: 'Verify resolver with HMAC-signed challenges',
            ),
            if (_testPrism) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _prismKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Prism Shared Secret Key',
                  hintText: 'Enter HMAC-SHA256 key',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildConcurrencySlider(),
            const SizedBox(height: 16),
            _buildCountryFilter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxOption({
    required String label,
    required bool value,
    required Function(bool?) onChanged,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConcurrencySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Concurrency Level: $_concurrency',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Slider(
          value: _concurrency.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          label: _concurrency.toString(),
          onChanged: (value) => setState(() => _concurrency = value.toInt()),
        ),
        Text(
          'Number of parallel resolver tests',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildCountryFilter() {
    final countries = ['US', 'GB', 'DE', 'NL', 'JP', 'AU', 'IN', 'All'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Country',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: countries.map((country) {
            return FilterChip(
              label: Text(country),
              selected: _filterCountry == (country == 'All' ? null : country),
              onSelected: (selected) {
                setState(
                  () => _filterCountry = selected
                      ? (country == 'All' ? null : country)
                      : null,
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.search),
        label: const Text('Start Advanced Scan'),
        onPressed: () {
          // TODO: Get list of resolvers from profile
          final resolvers = ['8.8.8.8', '1.1.1.1', '8.8.4.4'];

          BlocProvider.of<AdvancedDnsScanBloc>(context).add(
            AdvancedDnsScanStarted(
              resolvers: resolvers,
              testDomain: widget.profile.domain,
              testEDNS: _testEDNS,
              testNXDOMAIN: _testNXDOMAIN,
              testE2E: _testE2E,
              testPrism: _testPrism,
              prismSecret: _testPrism ? _prismKeyController.text : null,
              concurrency: _concurrency,
              filterCountry: _filterCountry,
            ),
          );
        },
      ),
    );
  }
}
