import 'package:flutter/material.dart';
import '../api.dart';
import 'common.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final q = TextEditingController();
  List list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => guard(context, () async {
        final r = await Api.i.get('/api/customers?q=${Uri.encodeQueryComponent(q.text)}');
        if (mounted) setState(() => list = r);
      });

  Future<void> _edit([Map? c]) async {
    final nm = TextEditingController(text: '${c?['Name'] ?? ''}');
    final ph = TextEditingController(text: '${c?['Phone'] ?? ''}');
    final ad = TextEditingController(text: '${c?['Address'] ?? ''}');
    final me = TextEditingController(text: '${c?['Memo'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c == null ? '고객 등록' : '고객 정보'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(children: [
              field(nm, '이름'),
              field(ph, '전화번호'),
              field(ad, '주소'),
              field(me, '메모'),
              if (c != null && asInt(c['Balance']) != 0) ...[
                Text('외상 잔액 ${won(asInt(c['Balance']))}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                OutlinedButton(
                  onPressed: () async {
                    final a = TextEditingController();
                    final go = await showDialog<bool>(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        title: const Text('외상 수금'),
                        content: field(a, '받은 금액', number: true),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('수금'))],
                      ),
                    );
                    if (go == true && ctx.mounted) {
                      await guard(ctx, () async {
                        await Api.i.post('/api/customers/${c['Id']}/payment', {'amount': int.tryParse(a.text) ?? 0});
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      });
                    }
                  },
                  child: const Text('외상 수금'),
                ),
              ],
            ]),
          ),
        ),
        actions: [
          if (c != null)
            TextButton(
              onPressed: () async {
                if (await confirm(ctx, '삭제(숨김)할까요?')) {
                  await guard(ctx, () async {
                    await Api.i.del('/api/customers/${c['Id']}');
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  });
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () => guard(ctx, () async {
              await Api.i.post('/api/customers', {'id': c?['Id'] ?? 0, 'name': nm.text.trim(), 'phone': ph.text.trim(), 'address': ad.text.trim(), 'memo': me.text});
              if (ctx.mounted) Navigator.pop(ctx, true);
            }),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.person_add), label: const Text('고객 등록')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(8), child: TextField(controller: q, onChanged: (_) => _load(), decoration: const InputDecoration(hintText: '이름 / 전화번호', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true))),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = list[i];
                final bal = asInt(c['Balance']);
                return ListTile(dense: true, title: Text('${c['Name']}'), subtitle: Text('${c['Phone']}'), trailing: bal != 0 ? Text('외상 ${won(bal)}', style: const TextStyle(color: Colors.red)) : null, onTap: () => _edit(c));
              },
            ),
          ),
        ]),
      );
}
