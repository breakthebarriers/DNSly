import 'package:flutter/material.dart';
import '../blocs/dns_scanner/advanced_dns_scan_bloc.dart';
import '../blocs/dns_scanner/advanced_dns_scan_state.dart';
import '../models/advanced_dns_result.dart';

class AdvancedDnsScanResultsWidget extends StatelessWidget {
  const AdvancedDnsScanResultsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdvancedDnsScanBloc, AdvancedDnsScanState>(
      builder: (context, state) {
        if (state is AdvancedDnsScanInitial) {
          return Center(
            child: Text(
              'No scan results yet',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        if (state is AdvancedDnsScanLoading) {
          return Column(
            children: [
              LinearProgressIndicator(value: state.progress / 100),
              const SizedBox(height: 16),
              Text(state.message),
            ],
          );
        }

        if (state is AdvancedDnsScanFailure) {
          return Center(
            child: Text(
              'Scan failed: ${state.message}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
            ),
          );
        }

        if (state is AdvancedDnsScanSuccess) {
          return _buildResults(context, state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildResults(
    BuildContext context,
    AdvancedDnsScanSuccess state,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(context, state),
          const SizedBox(height: 16),
          _buildResultsTable(context, state),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    AdvancedDnsScanSuccess state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  label: 'Average Score',
                  value: '${state.averageScore.toStringAsFixed(1)}/100',
                  icon: Icons.star,
                ),
                _buildStatItem(
                  label: 'Total Resolvers',
                  value: '${state.results.length}',
                  icon: Icons.list,
                ),
                _buildStatItem(
                  label: 'Best Resolver',
                  value: state.topResolverName,
                  icon: Icons.check_circle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildResultsTable(
    BuildContext context,
    AdvancedDnsScanSuccess state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Results',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Resolver')),
                  DataColumn(label: Text('Score')),
                  DataColumn(label: Text('Latency')),
                  DataColumn(label: Text('EDNS')),
                  DataColumn(label: Text('Hijack')),
                  DataColumn(label: Text('Tunnel')),
                  DataColumn(label: Text('Status')),
                ],
                rows: state.results.map((result) {
                  return DataRow(
                    cells: [
                      DataCell(Text(result.resolver)),
                      DataCell(Text('${result.score.toStringAsFixed(1)}')),
                      DataCell(
                        Text('${result.latency.inMilliseconds}ms'),
                      ),
                      DataCell(
                        Text(result.supportsEDNS ? '✓' : '✗'),
                      ),
                      DataCell(
                        Text(result.nxdomainHijacked ? '✗' : '✓'),
                      ),
                      DataCell(
                        Text(result.tunnelOK ? '✓' : '✗'),
                      ),
                      DataCell(
                        Text(
                          result.statusIcon,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailedView(context, state.results.first),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedView(BuildContext context, AdvancedDnsResult result) {
    return ExpansionTile(
      title: Text('${result.resolver} - Details'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Resolver', result.resolver),
              _buildDetailRow('Domain', result.domain),
              _buildDetailRow('Latency', '${result.latency.inMilliseconds}ms'),
              _buildDetailRow('Reachable', result.reachable ? 'Yes' : 'No'),
              _buildDetailRow('EDNS Support', result.supportsEDNS ? 'Yes' : 'No'),
              _buildDetailRow(
                'NXDOMAIN Hijacked',
                result.nxdomainHijacked ? 'Yes ⚠️' : 'No',
              ),
              _buildDetailRow('Tunnel OK', result.tunnelOK ? 'Yes' : 'No'),
              _buildDetailRow(
                'DNS Resolution',
                result.dnsResolutionOK ? 'Yes' : 'No',
              ),
              if (result.throughputBps != null)
                _buildDetailRow(
                  'Throughput',
                  '${(result.throughputBps! / 1000000).toStringAsFixed(2)} Mbps',
                ),
              if (result.packetLoss != null)
                _buildDetailRow(
                  'Packet Loss',
                  '${(result.packetLoss! * 100).toStringAsFixed(2)}%',
                ),
              _buildDetailRow('Prism Verified', result.prismVerified ? 'Yes' : 'No'),
              _buildDetailRow('Country', result.country ?? 'Unknown'),
              _buildDetailRow('Overall Score', '${result.score.toStringAsFixed(1)}/100'),
              _buildDetailRow('Summary', result.summary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
