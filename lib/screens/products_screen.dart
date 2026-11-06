import 'package:flutter/material.dart';
import '../api.dart';
import 'common.dart';
import 'scan.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final q = TextEditingController();
  List list = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await guard(context, () async {
      final r = await Api.i.get('/api/products?q=${Uri.encodeQueryComponent(q.text)}');
      if (mounted) setState(() => list = r);
    });
    if (mounted) setState(() => loading = false);
  }

  Future<void> _edit([Map? p]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => ProductDialog(p));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('상품 등록')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(controller: q, onChanged: (_) => _load(), decoration: const InputDecoration(hintText: '상품명 / 바코드 / 분류 검색', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true)),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final low = asInt(p['Stock']) <= asInt(p['MinStock']);
                      return ListTile(
                        dense: true,
                        title: Text('${p['Name']}'),
                        subtitle: Text('${p['Barcode']}  ${p['Category']}'),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(won(asInt(p['Price'])), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('재고 ${p['Stock']}', style: TextStyle(color: low ? Colors.red : null)),
                        ]),
                        onTap: () => _edit(p),
                      );
                    },
                  ),
          ),
        ]),
      );
}

class ProductDialog extends StatefulWidget {
  final Map? p;
  const ProductDialog(this.p, {super.key});
  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  late final bc = TextEditingController(text: '${widget.p?['Barcode'] ?? ''}');
  late final nm = TextEditingController(text: '${widget.p?['Name'] ?? ''}');
  late final cat = TextEditingController(text: '${widget.p?['Category'] ?? ''}');
  late final pr = TextEditingController(text: '${widget.p?['Price'] ?? ''}');
  late final co = TextEditingController(text: '${widget.p?['Cost'] ?? ''}');
  late final st = TextEditingController(text: '${widget.p?['Stock'] ?? '0'}');
  late final ms = TextEditingController(text: '${widget.p?['MinStock'] ?? '0'}');
  late final memo = TextEditingController(text: '${widget.p?['Memo'] ?? ''}');

  @override
  Widget build(BuildContext context) {
    final isNew = widget.p == null;
    return AlertDialog(
      title: Text(isNew ? '상품 등록' : '상품 수정'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(children: [
            Row(children: [
              Expanded(child: field(bc, '바코드 (리더로 스캔 가능)')),
              if (isMobile) IconButton(onPressed: () async { final v = await scanBarcode(context); if (v != null) setState(() => bc.text = v); }, icon: const Icon(Icons.camera_alt)),
            ]),
            field(nm, '상품명'),
            field(cat, '분류'),
            Row(children: [Expanded(child: field(pr, '판매가', number: true)), const SizedBox(width: 8), Expanded(child: field(co, '매입가', number: true))]),
            Row(children: [
              if (isNew) Expanded(child: field(st, '현재 재고', number: true)),
              if (isNew) const SizedBox(width: 8),
              Expanded(child: field(ms, '최소 재고(부족 알림)', number: true)),
            ]),
            field(memo, '메모'),
          ]),
        ),
      ),
      actions: [
        if (!isNew)
          TextButton(
            onPressed: () async {
              if (await confirm(context, '이 상품을 삭제(숨김)할까요?')) {
                await guard(context, () async {
                  await Api.i.del('/api/products/${widget.p!['Id']}');
                  if (context.mounted) Navigator.pop(context, true);
                });
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () => guard(context, () async {
            await Api.i.post('/api/products', {
              'id': widget.p?['Id'] ?? 0,
              'barcode': bc.text.trim(),
              'name': nm.text.trim(),
              'category': cat.text.trim(),
              'price': int.tryParse(pr.text) ?? 0,
              'cost': int.tryParse(co.text) ?? 0,
              'stock': int.tryParse(st.text) ?? 0,
              'minStock': int.tryParse(ms.text) ?? 0,
              'vendorId': asInt(widget.p?['VendorId']),
              'memo': memo.text,
            });
            if (context.mounted) Navigator.pop(context, true);
          }),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
